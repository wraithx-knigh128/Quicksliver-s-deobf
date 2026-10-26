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
// Before those, one more literal form is read: Roblox's EncodingService wrapper that some packers put around a script,
// `buffer.tostring(game:GetService("EncodingService"):DecompressBuffer(buffer.fromstring(base64.decode("...")), Enum.CompressionAlgorithm.Zstd))`.
// A base64 literal and a zstd frame are data; the text they hold is computed here (src/core/zstd.js) without running the script.
//
// A script that does anything else around the loader is never replaced wholesale; the loaded text is still shown by Dump.

import { walk, transform } from '../core/walk.js';
import { analyze, STDLIB_GLOBALS } from '../core/scope.js';
import { parse } from '../core/parser.js';
import { print } from '../core/printer.js';
import { isBytecode, parseChunk } from '../sandbox/bytecode.js';
import { decompile } from '../decompile/decompile.js';
import { traceScript } from '../trace/trace.js';
import { zstdDecompress } from '../core/zstd.js';
import { makeConst } from './fold.js';

const LOADERS = new Set(['load', 'loadstring']);
/** Globals a decoder may use. Anything else (game, print, getfenv, HttpGet, ...) means the script does more than load. */
const DECODER_GLOBALS = new Set([
  'string', 'table', 'math', 'bit32', 'bit', 'utf8', 'tonumber', 'tostring', 'type', 'select', 'pairs', 'ipairs', 'next', 'unpack',
  'assert', 'error', 'pcall', 'rawget', 'rawset', 'rawequal', 'rawlen', 'setmetatable', 'getmetatable', 'load', 'loadstring',
]);

/** Globals the Roblox / executor environments define: a loader that overwrites one is doing something, not just loading. */
const ROBLOX_GLOBALS = new Set(['game', 'workspace', 'script', 'shared', 'plugin', 'Instance', 'Enum', 'Vector3', 'CFrame', 'Color3', 'UDim2', 'task', 'wait', 'spawn', 'delay', 'warn', 'tick', 'time', 'typeof', 'getgenv', 'getrenv', 'getfenv', 'setfenv', 'getrawmetatable', 'hookfunction', 'syn', 'http', 'request', 'writefile', 'readfile']);
const unparen = (e) => (e && e.type === 'Paren' ? unparen(e.expr) : e);

/** `a.b(...)` where a and b are plain names. */
const isCallOf = (e, obj, keys) => !!e && e.type === 'Call' && e.fn.type === 'Index' && e.fn.obj.type === 'Name' && e.fn.obj.name === obj && e.fn.key.type === 'String' && keys.includes(e.fn.key.value);
const BASE64_CALLS = [['base64', ['decode', 'Decode']], ['crypt', ['base64decode', 'base64_decode']]];

function base64Bytes(text) {
  const clean = text.replace(/[^A-Za-z0-9+/]/g, '');
  const out = [];
  let acc = 0; let bits = 0;
  for (const ch of clean) {
    acc = (acc << 6) | 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'.indexOf(ch);
    bits += 6;
    if (bits >= 8) { bits -= 8; out.push((acc >> bits) & 255); acc &= (1 << bits) - 1; }
  }
  return Uint8Array.from(out);
}

/**
 * The text inside `buffer.tostring(game:GetService("EncodingService"):DecompressBuffer(buffer.fromstring(<base64 literal>), Enum.CompressionAlgorithm.Zstd))`,
 * or null when the expression has another shape. Throws when it has this shape but the data cannot be read (another algorithm, a damaged frame).
 */
function compressedLiteral(e) {
  const x = unparen(e);
  if (!isCallOf(x, 'buffer', ['tostring']) || x.args.length !== 1) return null;
  const d = unparen(x.args[0]);
  if (!d || d.type !== 'MethodCall' || d.name !== 'DecompressBuffer' || d.args.length < 2) return null;
  const svc = unparen(d.obj);
  if (!svc || svc.type !== 'MethodCall' || svc.name !== 'GetService' || !svc.args[0] || svc.args[0].type !== 'String' || svc.args[0].value !== 'EncodingService') return null;
  const alg = d.args[1];
  if (!alg || alg.type !== 'Index' || alg.key.type !== 'String' || alg.obj.type !== 'Index' || alg.obj.key.value !== 'CompressionAlgorithm') return null;
  const from = unparen(d.args[0]);
  if (!isCallOf(from, 'buffer', ['fromstring']) || from.args.length !== 1) return null;
  const inner = unparen(from.args[0]);
  if (!inner || inner.type !== 'Call' || inner.args.length !== 1 || inner.args[0].type !== 'String') return null;
  const decoder = inner.fn.type === 'Name' ? ['base64decode', 'base64_decode'].includes(inner.fn.name) : BASE64_CALLS.some(([o, k]) => isCallOf(inner, o, k));
  if (!decoder) return null;
  if (alg.key.value !== 'Zstd') throw new Error(`EncodingService payload with Enum.CompressionAlgorithm.${alg.key.value}: only Zstd is read`);
  return latin1(zstdDecompress(base64Bytes(inner.args[0].value)));
}

function latin1(bytes) {
  let out = '';
  for (let i = 0; i < bytes.length; i += 8192) out += String.fromCharCode.apply(null, bytes.subarray(i, i + 8192));
  return out;
}

/** Does the program read a global that has the name of one of these locals? (Spliced into the chunk, those reads would be captured.) */
function hasGlobalNamed(ast, names) {
  if (!names.size) return false;
  const info = analyze(ast);
  for (const g of info.globals.keys()) if (names.has(g)) return true;
  return false;
}

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
  const result = { changed: 0, layers: 0, inlined: 0, replaced: 0, bytecode: 0, compressed: 0, skipped: null, notes: [] };
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

  // ---- 0. a compressed literal (EncodingService) becomes the text it holds ---------------------------------------------------
  transform(chunk, {
    expr(e) {
      let text;
      try { text = compressedLiteral(e); } catch (err) { result.notes.push(String(err.message || err).split('\n')[0]); return undefined; }
      if (text == null) return undefined;
      result.compressed++;
      return makeConst(text);
    },
  });

  // ---- 1. a literal payload, in place -------------------------------------------------------------------------------------
  // `loadstring("...")()` becomes `do ... end`. When the call passes arguments or the payload returns values or reads `...`, the payload becomes the
  // body of a function called with the same arguments: `loadstring("...")(...)` -> `(function(...) ... end)(...)`. As the last statement of the
  // chunk, called with `...`, the payload simply takes the call's place.
  const lastIndex = chunk.body.length - 1;
  const topLocals = new Set();
  for (const st of chunk.body) {
    if (st.type === 'Local') st.ids.forEach((id) => topLocals.add(id.name));
    else if (st.type === 'LocalFunction') topLocals.add(st.id.name);
  }
  const tail = chunk.body[lastIndex];
  transform(chunk, {
    block(stmts) {
      let touched = false;
      const out = [];
      for (const s of stmts) {
        let outer = null; // the call whose callee is the load: loadstring("...")(args)
        if (s.type === 'CallStmt' && s.call.type === 'Call') outer = s.call;
        else if (s.type === 'Return' && s.values.length === 1 && s.values[0].type === 'Call') outer = s.values[0];
        const L = outer ? loadCall(outer.fn) : null;
        const text = L && L.args[0].type === 'String' ? L.args[0].value : null;
        if (text == null) { out.push(s); continue; }
        let p;
        try { p = payloadAst(text); } catch (e) { result.notes.push(`a literal payload was not usable: ${String(e.message || e).split('\n')[0]}`); out.push(s); continue; }
        const plain = s.type === 'CallStmt' && !outer.args.length ? inlinable(p.ast.body) : null;
        if (plain) {
          out.push({ type: 'Do', body: plain });
        } else {
          const passesVarargs = outer.args.length === 1 && outer.args[0].type === 'Vararg';
          const sameScope = s === tail && s.type === 'Return' && passesVarargs && !hasGlobalNamed(p.ast, topLocals);
          if (sameScope) out.push(...p.ast.body);
          else {
            const fn = { type: 'Func', params: [], vararg: true, isMethod: false, body: p.ast.body };
            const call = { type: 'Call', fn: { type: 'Paren', expr: fn }, args: outer.args };
            out.push(s.type === 'Return' ? { ...s, values: [call] } : { ...s, call });
          }
        }
        result.inlined++; result.layers++; if (p.bytecode) result.bytecode++;
        touched = true;
      }
      return touched ? out : undefined;
    },
  });

  // ---- 2. a script that is nothing but a loader ---------------------------------------------------------------------------
  const plan = loaderPlan(chunk, info, loadCall, isGlobal);
  if (plan && !result.inlined) {
    const setup = plan.stmts.filter((s, i) => i !== plan.finalIndex);
    const { why, helpers } = notJustALoader(setup, plan.stmts[plan.finalIndex], info);
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
          // the helpers the loader defined as globals go away with it; the program must not have been written to use them
          let uses = null;
          walk(p.ast.body, (n) => { if (!uses && n.type === 'Name' && helpers.has(n.name)) uses = n.name; });
          if (uses) throw new Error(`the loaded program reads '${uses}', a global the loader defines`);
          chunk.body = p.ast.body;
          chunk.features = new Set([...(chunk.features || []), ...(p.ast.features || [])]);
          result.replaced = 1; result.layers++; if (p.bytecode) result.bytecode++;
        } catch (e) { result.skipped = `the loaded text is not usable: ${String(e.message || e).split('\n')[0]}`; }
      }
    }
  }
  result.changed = result.inlined + result.replaced + result.compressed;
  if (!result.changed && !result.skipped && result.notes.length) result.skipped = result.notes[0];
  return result;
}

/**
 * The shape `... ; local f = load(x) ; f()`, `... ; load(x)()` or `... ; return assert(load(x))(...)`: the index of the last statement
 * and what it loads. `pcall(f)` counts as calling f.
 */
function loaderPlan(chunk, info, loadCall, isGlobal) {
  // everything wrapped in `do ... end` (or the loader in a trailing block) reads the same as the statements spread out
  const opened = (list) => list.flatMap((st, i) => (st.type === 'Do' && i === list.length - 1 ? opened(st.body) : [st]));
  const body = opened(chunk.body);
  if (!body.length) return null;
  const finalIndex = body.length - 1;
  const last = body[finalIndex];
  let call = last.type === 'CallStmt' ? last.call : last.type === 'Return' && last.values.length === 1 ? last.values[0] : null;
  call = unparen(call);
  if (!call || call.type !== 'Call') return null;
  if (isGlobal(call.fn) && call.fn.name === 'pcall' && call.args.length >= 1) call = { type: 'Call', fn: call.args[0], args: call.args.slice(1) };
  const direct = loadCall(call.fn);
  if (direct) return { finalIndex, load: direct, stmts: body };
  const target = unparen(call.fn);
  if (target && target.type === 'Name') {
    const v = info.varOf.get(target);
    if (!v || v.isGlobal) return null;
    for (const s of body) {
      if (s.type !== 'Local' || s.ids.length !== 1 || s.values.length !== 1) continue;
      if (info.varOf.get(s.ids[0]) !== v) continue;
      const L = loadCall(s.values[0]);
      if (L) return { finalIndex, load: L, stmts: body };
    }
  }
  return null;
}

/**
 * Why the statements around a loader are more than a decoder, or null when they are only that: they may compute with standard
 * libraries and write local variables and tables. A global the loader defines for itself (`function _0x93mdw(a) ... end`) is a helper,
 * not a side effect, when it is used and has a name no environment would give it; it is reported so the caller can check the loaded
 * program does not rely on it.
 */
function notJustALoader(stmts, final, info) {
  let why = null;
  const bad = (m) => { if (!why) why = m; };
  const helpers = new Set();
  const written = new Set(); // the Name nodes that are only being assigned to: those are not uses
  const rootOf = (t) => { let r = t; while (r && r.type === 'Index') r = r.obj; return r; };
  const isGlobalName = (n) => { const v = n && n.type === 'Name' ? info.varOf.get(n) : null; return !!(v && v.isGlobal); };
  // pass 1: which globals does the script write, and by what means
  for (const s of stmts) {
    walk(s, (n) => {
      if (n.type === 'Assign' || n.type === 'CompoundAssign') {
        for (const t of n.targets || [n.target]) {
          const r = rootOf(t);
          if (!isGlobalName(r)) continue;
          if (t.type === 'Name') { helpers.add(t.name); written.add(t); } else bad('writes into a global table');
        }
      } else if (n.type === 'Function') {
        const r = rootOf(n.target);
        if (isGlobalName(r)) { if (n.target.type === 'Name') { helpers.add(n.target.name); written.add(n.target); } else bad('defines a field of a global'); }
      }
      return undefined;
    });
  }
  // a helper must be something no environment defines, and must be used by the script itself
  const used = new Set();
  for (const s of [...stmts, final]) walk(s, (n) => { if (n.type === 'Name' && !written.has(n) && isGlobalName(n) && helpers.has(n.name)) used.add(n.name); return undefined; });
  for (const name of helpers) {
    if (DECODER_GLOBALS.has(name) || STDLIB_GLOBALS.has(name) || ROBLOX_GLOBALS.has(name)) bad(`replaces the global '${name}'`);
  }
  // pass 2: every other global it touches must be one a decoder may use
  for (const s of [...stmts, final]) {
    walk(s, (n) => {
      if (why) return false;
      if (n.type === 'Name' && isGlobalName(n) && !DECODER_GLOBALS.has(n.name) && !helpers.has(n.name)) bad(`uses the global '${n.name}'`);
      return undefined;
    });
  }
  // helpers that are written but never read are leftovers of something else (a flag, an export): not just a loader
  for (const name of helpers) if (!why && !used.has(name)) bad(`writes to a global ('${name}') that nothing in the loader reads`);
  return { why, helpers };
}
