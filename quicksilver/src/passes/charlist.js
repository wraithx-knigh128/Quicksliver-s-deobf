// A program kept as a list of one-character strings, run by a compiler the script carries.
//
//   local data = { '\112', '\40', '\45', ... }
//   local concat = table.concat
//   local run = (function(...) ... a Lua lexer, parser and interpreter written in Lua ... end)(...)
//   run(concat(data, ''))()
//
// Some obfuscators have no `loadstring` to call (a Roblox client does not have one), so they ship their own: the script's text is data, and the
// "loader" is a function the script defines. The text is a plain constant, so it is read without running anything, and it is the program.
//
// What is required, so that this is not taken for something else: the argument of the final call is `concat(T, sep)` (or `table.concat`) of a table
// T of string literals bound once; the function called is defined in the script and its body mentions most of Lua's keywords as strings (it is a
// lexer); and the joined text parses as Lua. A script that fails any of these is left alone.

import { walk } from '../core/walk.js';
import { analyze, STDLIB_GLOBALS } from '../core/scope.js';
import { parse } from '../core/parser.js';

const KEYWORDS = ['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while'];
const unparen = (e) => { let x = e; while (x && x.type === 'Paren') x = x.expr; return x; };

/** Every string a function mentions, as a set (its own nested functions included). */
function stringsOf(node) {
  const out = new Set();
  walk(node, (n) => { if (n.type === 'String') out.add(n.value); });
  return out;
}

/** The single value a local variable was declared with, or null. */
function initOf(info, name) {
  const v = info.varOf.get(name);
  return v && !v.isGlobal && !v.writes.length ? v.init : null;
}

export function findCharListLoader(ast, debug = false) {
  const bail = (why) => { if (debug) console.error('charlist:', why); return null; };
  const last = ast.body[ast.body.length - 1];
  if (!last) return null;
  // cheap shape first (detection calls this for every script): run(f(...))()
  {
    const c = unparen(last.type === 'CallStmt' ? last.call : last.type === 'Return' && last.values.length === 1 ? last.values[0] : null);
    const i = c && c.type === 'Call' && !c.args.length ? unparen(c.fn) : null;
    if (!i || i.type !== 'Call' || !i.args.length || !unparen(i.args[0]) || unparen(i.args[0]).type !== 'Call') return null;
  }
  const info = analyze(ast);
  let call = last.type === 'CallStmt' ? last.call : last.type === 'Return' && last.values.length === 1 ? last.values[0] : null;
  call = unparen(call);
  if (!call || call.type !== 'Call' || call.args.length) return bail('shape of final call');                 // run(text)()
  const inner = unparen(call.fn);
  if (!inner || inner.type !== 'Call' || inner.args.length < 1) return bail('inner call');
  const concat = unparen(inner.args[0]);
  if (!concat || concat.type !== 'Call') return bail('concat call');
  // concat is `table.concat` itself, or a local that holds it
  const isConcat = (f) => {
    const g = unparen(f);
    if (g.type === 'Index' && g.obj.type === 'Name' && g.obj.name === 'table' && g.key.type === 'String' && g.key.value === 'concat') return true;
    if (g.type === 'Name') { const v = initOf(info, g); return !!v && isConcat(v); }
    return false;
  };
  if (!isConcat(concat.fn) || concat.args.length < 1) return bail('isConcat');
  const listRef = unparen(concat.args[0]);
  const list = listRef.type === 'Table' ? listRef : listRef.type === 'Name' ? unparen(initOf(info, listRef) || {}) : null;
  if (!list || list.type !== 'Table' || list.fields.length < 16) return bail('list');
  if (!list.fields.every((f) => f.kind === 'item' && f.value.type === 'String')) return bail('list items');
  let sep = '';
  if (concat.args.length >= 2) {
    const s = unparen(concat.args[1]);
    const val = s.type === 'String' ? s : s.type === 'Name' ? unparen(initOf(info, s) || {}) : null;
    const gv = s.type === 'Name' ? info.varOf.get(s) : null;
    if (val && val.type === 'String') sep = val.value;
    else if (s.type === 'Nil' || (gv && gv.isGlobal && !gv.writes.length && !STDLIB_GLOBALS.has(s.name))) sep = '';    // table.concat(list, nil): the separator is the empty string
    else return bail('sep');
  }
  // the function that runs the text is the script's own, and is a Lua lexer
  const callee = unparen(inner.fn);
  let def = callee;
  if (callee.type === 'Name') def = unparen(initOf(info, callee) || {});
  if (!def || !['Func', 'Call'].includes(def.type)) return bail('def');
  // a lexer names Lua's keywords: as strings of their own, or inside one table-of-tokens string ("TK_AND and\nTK_BREAK break ...")
  const mentioned = stringsOf(def);
  const words = new Set();
  for (const m of mentioned) for (const w of m.match(/[A-Za-z_]+/g) || []) words.add(w);
  const keywords = KEYWORDS.filter((k) => words.has(k)).length;
  if (keywords < 14) return bail('keywords');
  const text = list.fields.map((f) => f.value.value).join(sep);
  return { text, items: list.fields.length, keywords, finalStmt: last };
}

/**
 * Replace the script by the program it carries.
 * @returns {{changed: number, items?: number, bytes?: number, skipped?: string}}
 */
export function unwrapCharList(chunk) {
  const found = findCharListLoader(chunk);
  if (!found) return { changed: 0 };
  let payload;
  try { payload = parse(found.text); } catch (e) { return { changed: 0, skipped: `the text the script carries is not Lua: ${String(e.message || e).split('\n')[0]}` }; }
  if (!payload.body.length) return { changed: 0, skipped: 'the text the script carries is empty' };
  chunk.body = payload.body;
  chunk.features = new Set([...(chunk.features || []), ...(payload.features || [])]);
  return { changed: 1, items: found.items, bytes: found.text.length, compilerKeywords: found.keywords };
}
