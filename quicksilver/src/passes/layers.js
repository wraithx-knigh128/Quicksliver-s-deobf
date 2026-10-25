// Loader layers.
//
// Many obfuscators, and plain packers, end in `loadstring(<text>)()`: the real program is the text. Three cases, from safest to
// most work:
//
//   1. The text is a string literal (after folding). It is parsed and put in place of the call, inside a `do ... end`, wherever
//      the call is. Nothing is run.
//   2. The script is nothing but a loader: a decoder (hex digits and an offset, base64, a XOR loop) feeding load/loadstring, and a
//      last statement that calls what was loaded. The sandbox, when the person switched it on, runs the script until the first
//      chunk is handed to load and keeps that text; the whole script is then replaced by the chunk. "Nothing but a loader" is
//      checked on the syntax tree first: the other statements may only reach standard libraries and local variables.
//   3. The text is compiled Lua (Lua 5.1 or 5.4, as in Hercules' bytecode encoding): it is decompiled instead of parsed.
//
// A script that does anything else around the loader is never replaced wholesale; the loaded text is still shown by Dump.

import { walk, transform } from '../core/walk.js';
import { analyze } from '../core/scope.js';
import { parse } from '../core/parser.js';
import { print } from '../core/printer.js';
import { isBytecode, parseChunk } from '../sandbox/bytecode.js';
import { decompile } from '../decompile/decompile.js';
import { traceScript } from '../trace/trace.js';

const LOADERS = new Set(['load', 'loadstring']);
/** Globals a decoder may use. Anything else (game, print, getfenv, HttpGet, ...) means the script does more than load. */
const DECODER_GLOBALS = new Set([
  'string', 'table', 'math', 'bit32', 'bit', 'utf8', 'tonumber', 'tostring', 'type', 'select', 'pairs', 'ipairs', 'next', 'unpack',
  'assert', 'error', 'pcall', 'rawget', 'rawset', 'rawequal', 'rawlen', 'setmetatable', 'getmetatable', 'load', 'loadstring',
]);

const unparen = (e) => (e && e.type === 'Paren' ? unparen(e.expr) : e);

/** Does `body` read the `...` of its own chunk? (A nested function's `...` is its own.) */
function usesVararg(body) {
  let found = false;
  walk(body, (n) => {
    if (n.type === 'Func') return false;
    if (n.type === 'Vararg') found = true;
    return undefined;
  });
  return found;
}

/** The statements of a payload as they would be inlined (a bare trailing `return` dropped), or null when they cannot be. */
function inlinable(body) {
  const stmts = body.slice();
  const last = stmts[stmts.length - 1];
  if (last && last.type === 'Return') {
    if (last.values.length) return null;
    stmts.pop();
  }
  if (usesVararg(stmts)) return null;
  return stmts;
}

/** Turn a loaded text into a syntax tree: compiled Lua is decompiled, anything else parsed. */
function payloadAst(text) {
  if (isBytecode(text)) {
    const out = decompile(parseChunk(text));
    if (out.failures && out.failures.length) throw new Error(`the compiled chunk could not be structured: ${out.failures[0]}`);
    return { ast: out.ast, bytecode: true };
  }
  return { ast: parse(text), bytecode: false };
}

/**
 * Run `source` in the sandbox until the first chunk is handed to load/loadstring; returns that text or null.
 * @param {string} source
 * @param {{fuel?: number, timeMs?: number, dialect?: string}} opts
 */
export function captureFirstLoad(source, opts = {}) {
  const t = traceScript(source, { fuel: opts.fuel ?? 60_000_000, timeMs: opts.timeMs ?? 10_000, dialect: opts.dialect || 'luau', callHandlers: false, stopAfterLoads: 1 });
  return t.layers.length ? t.layers[0].source : null;
}

export function unwrapLayers(chunk, ctx = {}) {
  const result = { changed: 0, layers: 0, inlined: 0, replaced: 0, bytecode: 0, skipped: null, notes: [] };
  const info = analyze(chunk);
  const isGlobal = (n) => n && n.type === 'Name' && !!(info.varOf.get(n) && info.varOf.get(n).isGlobal);

  /** `load`, `loadstring`, or `loadstring or load`. */
  const loaderRef = (fn) => {
    const f = unparen(fn);
    if (!f) return false;
    if (f.type === 'Name') return isGlobal(f) && LOADERS.has(f.name);
    if (f.type === 'Binary' && f.op === 'or') return loaderRef(f.left) && loaderRef(f.right);
    return false;
  };
  /** The load call inside `load(x)`, `assert(load(x))` or parentheses around either. */
  const loadCall = (e) => {
    const x = unparen(e);
    if (!x || x.type !== 'Call') return null;
    if (isGlobal(x.fn) && x.fn.name === 'assert' && x.args.length >= 1) return loadCall(x.args[0]);
    return loaderRef(x.fn) && x.args.length >= 1 ? x : null;
  };

  // ---- 1. a literal payload, in place -------------------------------------------------------------------------------------
  transform(chunk, {
    block(stmts) {
      let touched = false;
      const out = [];
      for (const s of stmts) {
        const L = s.type === 'CallStmt' && s.call.type === 'Call' && !s.call.args.length ? loadCall(s.call.fn) : null;
        const text = L && L.args[0].type === 'String' ? L.args[0].value : null;
        if (text == null) { out.push(s); continue; }
        let p;
        try { p = payloadAst(text); } catch (e) { result.notes.push(`a literal payload was not usable: ${String(e.message || e).split('\n')[0]}`); out.push(s); continue; }
        const body = inlinable(p.ast.body);
        if (!body) { result.notes.push('a literal payload returns values or reads `...`, so it was left in place'); out.push(s); continue; }
        out.push({ type: 'Do', body });
        result.inlined++; result.layers++; if (p.bytecode) result.bytecode++;
        touched = true;
      }
      return touched ? out : undefined;
    },
  });

  // ---- 2. a script that is nothing but a loader ---------------------------------------------------------------------------
  const plan = loaderPlan(chunk, info, loadCall, isGlobal);
  if (plan && !result.inlined) {
    const setup = chunk.body.filter((s, i) => i !== plan.finalIndex);
    const why = notJustALoader(setup, info);
    if (why) {
      result.skipped = `the script loads text but also ${why}; use Dump to see what it loads`;
    } else if (!ctx.sandbox || !ctx.sandbox.enabled) {
      result.skipped = 'the script is a loader whose text is computed; switch on sandboxed evaluation to read it';
    } else {
      let text = null;
      try { text = (ctx.capture || captureFirstLoad)(print(chunk), ctx.sandbox); } catch (e) { result.skipped = `sandbox: ${String(e.message || e).split('\n')[0]}`; }
      if (text == null && !result.skipped) result.skipped = 'the sandbox ran the script and it never handed any text to load';
      if (text != null) {
        try {
          const p = payloadAst(text);
          chunk.body = p.ast.body;
          chunk.features = new Set([...(chunk.features || []), ...(p.ast.features || [])]);
          result.replaced = 1; result.layers++; if (p.bytecode) result.bytecode++;
        } catch (e) { result.skipped = `the loaded text is not usable: ${String(e.message || e).split('\n')[0]}`; }
      }
    }
  }
  result.changed = result.inlined + result.replaced;
  if (!result.changed && !result.skipped && result.notes.length) result.skipped = result.notes[0];
  return result;
}

/**
 * The shape `... ; local f = load(x) ; f()`, `... ; load(x)()` or `... ; return assert(load(x))(...)`: the index of the last statement
 * and what it loads. `pcall(f)` counts as calling f.
 */
function loaderPlan(chunk, info, loadCall, isGlobal) {
  const body = chunk.body;
  if (!body.length) return null;
  const finalIndex = body.length - 1;
  const last = body[finalIndex];
  let call = last.type === 'CallStmt' ? last.call : last.type === 'Return' && last.values.length === 1 ? last.values[0] : null;
  call = unparen(call);
  if (!call || call.type !== 'Call') return null;
  if (isGlobal(call.fn) && call.fn.name === 'pcall' && call.args.length >= 1) call = { type: 'Call', fn: call.args[0], args: call.args.slice(1) };
  const direct = loadCall(call.fn);
  if (direct) return { finalIndex, load: direct };
  const target = unparen(call.fn);
  if (target && target.type === 'Name') {
    const v = info.varOf.get(target);
    if (!v || v.isGlobal) return null;
    for (const s of body) {
      if (s.type !== 'Local' || s.ids.length !== 1 || s.values.length !== 1) continue;
      if (info.varOf.get(s.ids[0]) !== v) continue;
      const L = loadCall(s.values[0]);
      if (L) return { finalIndex, load: L };
    }
  }
  return null;
}

/**
 * Why the statements around a loader are more than a decoder, or null when they are only that: they may compute with standard
 * libraries and write local variables and tables, nothing else.
 */
function notJustALoader(stmts, info) {
  let why = null;
  const bad = (m) => { if (!why) why = m; };
  for (const s of stmts) {
    walk(s, (n) => {
      if (why) return false;
      if (n.type === 'Name') {
        const v = info.varOf.get(n);
        if (v && v.isGlobal && !DECODER_GLOBALS.has(n.name)) bad(`uses the global '${n.name}'`);
      } else if (n.type === 'Assign' || n.type === 'CompoundAssign') {
        for (const t of n.targets || [n.target]) {
          let root = t;
          while (root && root.type === 'Index') root = root.obj;
          const v = root && root.type === 'Name' ? info.varOf.get(root) : null;
          if (!v || v.isGlobal) bad('writes to a global or to something that is not a local variable');
        }
      } else if (n.type === 'Function') {
        let root = n.target;
        while (root && root.type === 'Index') root = root.obj;
        const v = root && root.type === 'Name' ? info.varOf.get(root) : null;
        if (!v || v.isGlobal) bad('defines a global function');
      }
      return undefined;
    });
    if (why) break;
  }
  return why;
}
