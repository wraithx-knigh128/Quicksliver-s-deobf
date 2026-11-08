// Structural features of a script, measured without knowing which tool made it.
//
// A feature is a yes/no fact that a reader could check by eye: "there is a table of 64 or more small numbers", "the last statement returns a call",
// "functions are stored in a table and there is no `local function`". The study framework (study.js) looks for features that are common in samples of
// one unfamiliar system and rare elsewhere; the advisor (advisor.js) uses the ones that matched as part of what it has observed.
//
// Nothing here executes the script. A script that does not parse has the single feature `syntax:invalid`.

import { tokenize } from '../core/lexer.js';
import { parse, LuaSyntaxError } from '../core/parser.js';
import { analyze } from '../core/scope.js';
import { forEachChild } from '../core/walk.js';
import { isMachineName } from '../passes/rename.js';
import { controlFlow } from '../nexus/profile.js';

export const FEATURES = [
  'comments:dense', 'layout:minified', 'names:machine', 'strings:none', 'strings:escaped',
  'call:loadstring', 'call:string.char', 'data:byte-table', 'data:byte-table-big', 'numbers:dense',
  'shape:vararg-wrapper', 'shape:state-loop', 'shape:decoder-loop', 'shape:stream-arithmetic', 'shape:function-table',
  'shape:tail-call', 'shape:proxy-functions',
];

const unparen = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };

/**
 * @param {string} source binary string
 * @returns {{features: Set<string>, metrics: object}}
 */
export function extractFeatures(source) {
  const f = new Set();
  const metrics = {};
  let lexed;
  let ast;
  try { lexed = tokenize(source); ast = parse(source); } catch (e) {
    if (e instanceof LuaSyntaxError) return { features: new Set(['syntax:invalid']), metrics: { error: e.message } };
    throw e;
  }
  const { tokens, comments } = lexed;
  const lines = source.split('\n');
  metrics.tokens = tokens.length;
  metrics.comments = comments.length;
  metrics.longestLine = lines.reduce((a, l) => Math.max(a, l.length), 0);

  if (comments.length / Math.max(1, tokens.length) >= 0.15 && comments.length >= 8) f.add('comments:dense');
  if (metrics.longestLine > 300 || source.length / Math.max(1, lines.length) > 120) f.add('layout:minified');

  const strTokens = tokens.filter((t) => t.t === 'string');
  if (!strTokens.length) f.add('strings:none');
  else if (strTokens.filter((t) => /\\(?:\d|x[0-9a-fA-F])/.test(t.raw || '')).length / strTokens.length >= 0.5) f.add('strings:escaped');
  const nums = tokens.filter((t) => t.t === 'number').length;
  metrics.numberDensity = nums / Math.max(1, tokens.length);
  if (metrics.numberDensity >= 0.25) f.add('numbers:dense');

  const info = analyze(ast);
  const locals = info.vars.filter((v) => v.decl && v.name !== 'self');
  metrics.locals = locals.length;
  if (locals.length >= 6 && locals.filter((v) => isMachineName(v.name)).length / locals.length >= 0.6) f.add('names:machine');

  let bigTable = 0;
  const fnFields = new Map();
  let localFunctions = 0;
  let tinyProxies = 0;
  let stream = false;
  let charInLoop = false;
  let loadCalls = false;
  let charCalls = false;

  const calleeName = (call) => {
    const fn = unparen(call.fn);
    if (!fn) return '';
    if (fn.type === 'Name') return fn.name;
    if (fn.type === 'Index' && fn.key.type === 'String' && fn.obj.type === 'Name') return `${fn.obj.name}.${fn.key.value}`;
    return '';
  };
  const containsMul = (e) => {
    let hit = false;
    const go = (n) => { if (!n || hit) return; if (n.type === 'Binary' && n.op === '*') hit = true; forEachChild(n, go); };
    go(e);
    return hit;
  };
  const scan = (n, inLoop) => {
    if (n.type === 'Table') {
      const numeric = n.fields.filter((x) => x.kind === 'item' && unparen(x.value).type === 'Number').length;
      if (numeric >= 16) f.add('data:byte-table');
      if (numeric >= 64) f.add('data:byte-table-big');
      if (numeric > bigTable) bigTable = numeric;
    }
    if (n.type === 'Call') {
      const name = calleeName(n);
      if (name === 'loadstring' || name === 'load') loadCalls = true;
      if (name === 'string.char') { charCalls = true; if (inLoop) charInLoop = true; }
    }
    if (n.type === 'Binary' && n.op === '%') {
      const right = unparen(n.right);
      if (right && right.type === 'Number' && right.value >= 1000 && containsMul(n.left)) stream = true;
    }
    if (n.type === 'LocalFunction') {
      localFunctions++;
      const body = n.func.body;
      if (body.length === 1 && body[0].type === 'Return' && body[0].values.length === 1 && ['Binary', 'Call', 'Unary'].includes(unparen(body[0].values[0]).type) && n.func.params.length <= 3) tinyProxies++;
    }
    if (n.type === 'Function' && n.method === null && n.target.type === 'Index' && n.target.key.type === 'String' && n.target.obj.type === 'Name') {
      fnFields.set(n.target.obj.name, (fnFields.get(n.target.obj.name) || 0) + 1);
    }
    if (n.type === 'Assign') {
      n.targets.forEach((t, i) => {
        const val = n.values[i] && unparen(n.values[i]);
        if (t.type === 'Index' && t.key.type === 'String' && t.obj.type === 'Name' && val && val.type === 'Func') fnFields.set(t.obj.name, (fnFields.get(t.obj.name) || 0) + 1);
      });
    }
    const loop = inLoop || ['While', 'Repeat', 'NumFor', 'GenFor'].includes(n.type);
    forEachChild(n, (c) => scan(c, loop));
  };
  scan(ast, false);
  if (loadCalls) f.add('call:loadstring');
  if (charCalls) f.add('call:string.char');
  if (charInLoop) f.add('shape:decoder-loop');
  if (stream) f.add('shape:stream-arithmetic');
  // functions kept in a table with a machine-made name, and not one `local function`: the program's functions live in the table
  if ([...fnFields.keys()].some((nm) => isMachineName(nm)) && localFunctions === 0) f.add('shape:function-table');
  if (tinyProxies >= 4) f.add('shape:proxy-functions');
  metrics.largestTable = bigTable;

  const body = ast.body;
  const last = body[body.length - 1];
  if (last && last.type === 'Return' && last.values.length === 1 && unparen(last.values[0]).type === 'Call') f.add('shape:tail-call');
  if (body.length === 1 && body[0].type === 'Return' && body[0].values.length === 1) {
    const call = unparen(body[0].values[0]);
    if (call.type === 'Call' && unparen(call.fn).type === 'Func' && unparen(call.fn).vararg) f.add('shape:vararg-wrapper');
  }
  try { if (controlFlow(ast).shapes.length) f.add('shape:state-loop'); } catch { /* shapes are optional evidence */ }
  return { features: f, metrics };
}
