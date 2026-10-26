// The engine's older passes, offered to the adaptive engine as strategies.
//
// They know nothing about any one protector either: constant folding, scope-based clean-up, dataflow on rebuilt code, loop idioms,
// loadstring layers and the sandboxed evaluation of decoder functions. What the adaptive engine adds is the choice of when each applies,
// and the check that it helped.

import { walk } from '../../core/walk.js';
import { foldPass } from '../../passes/fold.js';
import { simplifyPass } from '../../passes/simplify.js';
import { dataflowPass } from '../../passes/dataflow.js';
import { propagateStable } from '../../passes/stable.js';
import { evaluatePass } from '../../passes/evaluate.js';
import { unwrapLayers } from '../../passes/layers.js';
import { unwrapWrapper, tidyIfs } from '../../passes/structure.js';
import { numericLoops, loopForms, multiResults, booleanResults, shortCircuits, bareNils, unsetLocals } from '../../passes/idioms.js';
import { NOT_CONST, ConstTable } from '../concrete.js';
import { readsAsText } from '../../sandbox/numeric.js';
import { findProxies } from './proxies.js';
import { strip, lineOf, sizeOf } from '../util.js';

// ---- loadstring layers --------------------------------------------------------------------------------------------------------

const FETCH_METHODS = new Set(['HttpGet', 'HttpGetAsync', 'HttpPost', 'HttpPostAsync', 'GetAsync', 'RequestAsync']);
const FETCH_FUNCTIONS = new Set(['request', 'http_request', 'httpget', 'HttpGet']);

/** Is the expression a call that fetches something over the network (`game:HttpGet(url)`, `request({...}).Body`, `http.request(url)`)? */
export function isFetch(e) {
  e = strip(e);
  if (e.type === 'Index') return isFetch(e.obj);
  if (e.type === 'MethodCall') return FETCH_METHODS.has(e.name);
  if (e.type !== 'Call') return false;
  const f = strip(e.fn);
  if (f.type === 'Name') return FETCH_FUNCTIONS.has(f.name);
  return f.type === 'Index' && f.key.type === 'String' && FETCH_FUNCTIONS.has(f.key.value);
}

export const layers = {
  id: 'layers.unwrap',
  title: 'Open loadstring layers',
  order: 5,
  observe(ast, an) {
    const out = [];
    walk(ast, (n) => {
      if (n.type !== 'Call' || n.fn.type !== 'Name' || (n.fn.name !== 'loadstring' && n.fn.name !== 'load')) return;
      const v = an.info.varOf.get(n.fn);
      if (!v || !v.isGlobal || v.writes.length) return;
      if (n.args[0] && isFetch(n.args[0])) return;      // code fetched from the network is not hidden in this file: see remote.loader
      const literal = n.args[0] && strip(n.args[0]).type === 'String';
      out.push({
        kind: 'dynamic-code',
        line: lineOf(n),
        label: literal ? 'code is loaded from a string written in the script' : 'code is built at run time and loaded',
        evidence: [`a call of ${n.fn.name}`],
        confidence: 0.95,
        weight: literal ? 2 : 3,
      });
    });
    return out;
  },
  run(ast, ctx) { return unwrapLayers(ast, { sandbox: ctx.options.sandbox }); },
};

// ---- decoders -----------------------------------------------------------------------------------------------------------------

const PURE_GLOBALS = new Set(['string', 'table', 'math', 'bit32', 'bit', 'tostring', 'tonumber', 'type', 'select', 'unpack', 'ipairs', 'pairs', 'next',
  'rawget', 'rawequal', 'rawlen', 'error', 'assert', 'pcall', 'setmetatable', 'getmetatable', 'utf8']);
const STRING_CALLS = new Set(['table.concat', 'string.char', 'string.sub', 'string.rep', 'string.reverse', 'string.format', 'string.lower', 'string.upper', 'tostring']);
const STRING_METHODS = new Set(['sub', 'rep', 'reverse', 'upper', 'lower', 'format', 'gsub']);

const pathOf = (e) => (e.type === 'Name' ? e.name : e.type === 'Index' && e.obj.type === 'Name' && e.key.type === 'String' ? `${e.obj.name}.${e.key.value}` : null);

/** Do the function's results read as strings? (a concatenation, a library call that builds text, or a local that only ever holds such) */
function returnsString(fn, an) {
  const { info } = an;
  const rets = [];
  const writes = new Map();
  const note = (id, e) => { const v = info.varOf.get(id); if (!v) return; if (!writes.has(v)) writes.set(v, []); writes.get(v).push(e); };
  walk(fn.body, (n) => {
    if (n.type === 'Func') return false;
    if (n.type === 'Return') rets.push(...n.values);
    else if (n.type === 'Local') n.ids.forEach((id, i) => note(id, n.values[i] || { type: 'Nil' }));
    else if (n.type === 'Assign') n.targets.forEach((t, i) => { if (t.type === 'Name') note(t, n.values[i] || { type: 'Nil' }); });
    return undefined;
  });
  if (!rets.length) return false;
  const strVars = new Set();
  const stringy = (e) => {
    e = strip(e);
    switch (e.type) {
      case 'String': return true;
      case 'Binary': return e.op === '..' || ((e.op === 'and' || e.op === 'or') && stringy(e.left) && stringy(e.right));
      case 'Call': { const p = pathOf(e.fn); return !!p && STRING_CALLS.has(p) && !an.shadowed.has(p.split('.')[0]); }
      case 'MethodCall': return STRING_METHODS.has(e.name) && stringy(e.obj);
      case 'Name': { const v = info.varOf.get(e); return !!v && strVars.has(v); }
      default: return false;
    }
  };
  for (const v of writes.keys()) strVars.add(v);
  for (let again = true; again;) {
    again = false;
    for (const v of [...strVars]) if (!writes.get(v).every((e) => stringy(e))) { strVars.delete(v); again = true; }
  }
  return rets.every((e) => stringy(e));
}

/** Names inside the function resolve to its own variables, other locals, or the library functions that only compute. */
function closedFunction(fn, an) {
  let ok = true;
  walk(fn, (n) => {
    if (!ok || n.type !== 'Name') return;
    const v = an.info.varOf.get(n);
    if (!v) ok = false;
    else if (v.isGlobal && (!PURE_GLOBALS.has(n.name) || an.shadowed.has(n.name))) ok = false;
  });
  return ok;
}

/** A loop, or the arithmetic that turns one character code into another. */
function computes(fn) {
  let hit = false;
  walk(fn.body, (n) => {
    if (n.type === 'NumFor' || n.type === 'GenFor' || n.type === 'While' || n.type === 'Repeat') hit = true;
    else if (n.type === 'Binary' && (n.op === '%' || n.op === '~' || n.op === '&' || n.op === '|' || n.op === '<<' || n.op === '>>')) hit = true;
    else if (n.type === 'Call' && ['string.byte', 'bit32.bxor', 'bit.bxor'].includes(pathOf(n.fn))) hit = true;
    return hit ? false : undefined;
  });
  return hit;
}

/** A constant argument that is data for a decoder (an index, a list of character codes, bytes that are not text) and not text itself. */
function opaqueArg(v) {
  if (typeof v === 'number') return true;
  if (typeof v === 'string') return !readsAsText(v);
  if (v instanceof ConstTable) return v.map.size > 0 && [...v.map.values()].every((x) => typeof x === 'number');
  return false;
}

/**
 * Local functions that turn constants into text: they return strings, use nothing but their arguments, their own variables and the pure
 * library, compute (a loop or character arithmetic), and are called with constant arguments that are not themselves text (numbers, lists
 * of numbers, bytes). A function that takes readable text or words and returns text is the program’s own work and is never one.
 */
export function findDecoders(ast, an) {
  const { info } = an;
  const proxyVars = new Set(findProxies(ast, an).map((p) => p.v));
  const candidates = info.vars.filter((v) => (v.kind === 'localfunc' || v.kind === 'local') && v.init && strip(v.init).type === 'Func' && v.writes.length === 0 && !proxyVars.has(v));
  if (!candidates.length) return [];
  const parents = new WeakMap();
  walk(ast, (n, parent) => { if (parent) parents.set(n, parent); });
  const out = [];
  for (const v of candidates) {
    const fn = strip(v.init);
    const size = sizeOf(fn);
    if (size < 12 || !closedFunction(fn, an) || !computes(fn) || !returnsString(fn, an)) continue;
    const sites = v.reads.filter((r) => {
      const p = parents.get(r);
      if (!p || p.type !== 'Call' || p.fn !== r || !p.args.length) return false;
      const values = p.args.map((a) => an.evalExpr(a));
      return values.every((x) => x !== NOT_CONST) && values.some(opaqueArg) && values.every((x) => opaqueArg(x) || typeof x === 'string' || typeof x === 'number');
    });
    // a tool numbers what it makes, and a decoder is called wherever a string was; a function with an ordinary name needs more calls to be believed
    if (sites.length >= (an.machine(v.name) ? 1 : 3)) out.push({ v, fn, size, sites });
  }
  return out;
}

export const decoders = {
  id: 'decoders.evaluate',
  title: 'Evaluate decoder functions in the sandbox',
  order: 40,
  needs: ['sandbox'],
  observe(ast, an) {
    return findDecoders(ast, an).map((d) => ({
      kind: 'string-decoder',
      line: lineOf(d.fn),
      label: `\`${d.v.name}\` builds text from constants and is called ${d.sites.length} time${d.sites.length === 1 ? '' : 's'} with constant arguments`,
      evidence: ['it returns a string made by a loop or by arithmetic on character codes', 'it uses only its arguments and the pure library', 'the calls can be replaced by their results once the function has been run'],
      confidence: 0.85,
      weight: 1 * d.sites.length,
    }));
  },
  run(ast, ctx) {
    const found = findDecoders(ast, ctx.analyse());
    return evaluatePass(ast, { sandbox: ctx.options.sandbox, knownDecoders: new Set(found.map((d) => d.v.name)) });
  },
};

// ---- clean-up -----------------------------------------------------------------------------------------------------------------

const cleanup = (id, title, order, fn, { rebuilt = false } = {}) => ({
  id, title, order, cleanup: true, rebuilt,
  run: (ast, ctx) => fn(ast, ctx) || { changed: 0 },
});

export const cleanups = [
  cleanup('cleanup.wrapper', 'Unwrap an outer wrapper function', 6, (a) => unwrapWrapper(a)),
  cleanup('cleanup.fold', 'Fold constant expressions', 10, (a, ctx) => foldPass(a, { foldCalls: ctx.options.foldCalls || 'obfuscation' })),
  cleanup('cleanup.simplify', 'Remove dead code', 60, (a, ctx) => simplifyPass(a, { unusedAtStart: ctx.rebuilt ? new WeakSet() : ctx.unusedAtStart })),
  cleanup('cleanup.stable', 'Read copies of values that never change as the values', 61, (a) => propagateStable(a)),
  cleanup('cleanup.dataflow', 'Remove dead stores, copies and temporaries', 62, (a) => dataflowPass(a), { rebuilt: true }),
  cleanup('cleanup.idioms', 'Write loops and tests the way they are usually written', 64, (a) => {
    let changed = 0;
    for (const pass of [multiResults, booleanResults, shortCircuits, bareNils, unsetLocals, numericLoops, loopForms]) changed += (pass(a) || {}).changed || 0;
    return { changed };
  }, { rebuilt: true }),
  cleanup('cleanup.tidy', 'Tidy flipped tests', 66, (a) => tidyIfs(a)),
];
