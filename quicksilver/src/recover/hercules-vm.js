// Hercules "virtual machine" module (src/modules/VMGenerator.lua, Compiler/Serializer.lua, Compiler/VMStrings.lua of
// https://github.com/zeusssz/hercules-obfuscator): the script is compiled to Lua 5.1 bytecode by a compiler written in Lua, the
// chunk is serialised into Hercules' own byte layout, and the bytes are written as text:
//
//   every byte b becomes the two characters  char(b) "\"                       (Serializer.AddByte)
//   every character c of that text becomes a number in base 94 whose digits are characters 1..94 in a shuffled order,
//   the numbers are joined with "_"                                               (VMGenerator.encodeString)
//   the whole text and the shuffled alphabet are emitted as decimal escapes:      WrapState(BcToState('<text>', '<alphabet>'), env)()
//
// The interpreter (a FiOne derivative) runs standard Lua 5.1 instructions, so nothing about it has to be understood: the data is
// decoded back into function prototypes and given to the Lua 5.1 decompiler. Nothing is executed.
//
// The call is found by its shape, not by the names WrapState / BcToState (later Hercules modules rename them): a call with no
// arguments of a call whose first argument is a call with two string arguments, the second of which is an alphabet (every
// character different) that decodes the first one completely into a well-formed chunk.

import { walk } from '../core/walk.js';

export class HerculesVmError extends Error {}
const fail = (m) => { throw new HerculesVmError(m); };

/** Text -> bytes: split at "_", read each piece as a number in base |alphabet|, keep every first character of each (char, "\") pair. */
export function decodeText(text, alphabet) {
  const base = alphabet.length;
  const digit = new Map();
  for (let i = 0; i < base; i++) {
    if (digit.has(alphabet[i])) fail('the alphabet repeats a character');
    digit.set(alphabet[i], i);
  }
  // the pieces are separated by the one character the alphabet does not hold (`_` in 1.6.2 and later; another in 1.6, whose alphabet has `_` among its digits)
  const outside = [...new Set(text)].filter((c) => !digit.has(c));
  const sep = outside.length === 1 ? outside[0] : '_';
  const chars = [];
  let n = 0;
  let any = false;
  for (let i = 0; i <= text.length; i++) {
    const c = text[i];
    if (i === text.length || c === sep) {
      if (any) { if (n > 255) fail('a decoded character is larger than a byte'); chars.push(n); }
      n = 0; any = false;
      continue;
    }
    const d = digit.get(c);
    if (d === undefined) fail('the text has a character that is not in the alphabet');
    n = n * base + d; any = true;
    if (n > 0xffff) fail('a decoded character is larger than a byte');
  }
  // 1.6.2 and later write every byte followed by a backslash (the text was once the body of a string literal); 1.6 writes the bytes alone
  const paired = chars.length % 2 === 0 && chars.every((c, i) => i % 2 === 0 || c === 92);
  if (!paired) {
    if (sep === '_') fail('the decoded text is not a sequence of (byte, "\\") pairs');
    if (chars.some((c) => c > 255)) fail('a decoded character is larger than a byte');
    return Uint8Array.from(chars);
  }
  const bytes = new Uint8Array(chars.length / 2);
  for (let i = 0; i < chars.length; i += 2) bytes[i / 2] = chars[i];
  return bytes;
}

const VARARG = 37;
const CLOSURE = 36;

/**
 * The pool `k` was read with its nil constant missing from the data (the values that follow it moved one slot down and the last slot is
 * empty). The compiler gives a function at most one nil constant, so exactly one slot has to be opened again. Which one follows from how the
 * instructions use each slot: a global or method name must be a string, an arithmetic operand a number, a loaded constant or a table key
 * anything but nil, and the nil slot itself must be used by something that can take nil (a comparison, a stored value). If that leaves more
 * than one slot, the compiler's habit of numbering constants in the order the code first needs them decides; if even that does not single
 * one out, the function is refused: nothing is guessed.
 */
/** How the instructions use each constant slot: slot -> [[kind, pc]], kinds 'string' | 'number' | 'key' | 'value' | 'any'. */
function poolUses(code) {
  const uses = [];
  const use = (slot, kind, pc) => { (uses[slot] = uses[slot] || []).push([kind, pc]); };
  for (let pc = 0; pc < code.length; pc++) {
    const w = code[pc];
    const op = w & 63, B = (w >>> 23) & 511, C = (w >>> 14) & 511, Bx = w >>> 14;
    const rk = (x, kind) => { if (x >= 256) use(x - 256, kind, pc); };
    if (op === 1) use(Bx, 'value', pc);
    else if (op === 5 || op === 7) use(Bx, 'string', pc);
    else if (op === 6) rk(C, 'key');
    else if (op === 9) { rk(B, 'key'); rk(C, 'any'); }
    else if (op === 11) rk(C, 'string');
    else if (op >= 12 && op <= 17) { rk(B, 'number'); rk(C, 'number'); }
    else if (op === 23) { rk(B, 'any'); rk(C, 'any'); }
    else if (op === 24 || op === 25) { rk(B, 'value'); rk(C, 'value'); }
  }
  for (let i = 0; i < uses.length; i++) uses[i] = uses[i] || [];
  return uses;
}

/**
 * Slots the instructions use but the data does not have. One such slot that only comparisons and stores use is the nil constant at the end
 * of the pool (the serialiser counted the pool with Lua's `#`, which stops before a trailing nil). When `#` stopped at a nil in the middle,
 * the constants after it were never written: their values are not in the file and no reader can produce them. The shipped script reads each
 * of them as nil, and so does the program read here; every such slot, and the instructions that use it, is recorded in `stats.lostConstants`
 * so the report can say exactly which values are missing. A lost slot that has to be a name (a global, a method) cannot be written as nil:
 * then the function is refused.
 */
function checkMissing(code, k, stats) {
  const uses = poolUses(code);
  const beyond = [];
  for (let slot = k.length; slot < uses.length; slot++) if (uses[slot].length) beyond.push(slot);
  if (!beyond.length) return;
  if (beyond.length === 1 && uses[beyond[0]].every(([kind]) => kind === 'any')) return;
  // `#` stopped at the nil: the first slot past the data is that nil and has to be used as one
  const nilSlot = k.length;
  if (uses[nilSlot].length && !uses[nilSlot].every(([kind]) => kind === 'any')) {
    fail(`the tool left ${beyond.length} constant(s) out of its own output (it measures the pool with #, which stops at a nil constant), and the first of them is not used as a nil`);
  }
  const lost = beyond.filter((slot) => slot !== nilSlot);
  const named = lost.find((slot) => uses[slot].some(([kind]) => kind === 'string'));
  if (named !== undefined) fail(`the tool left ${lost.length} constant(s) out of its own output (it measures the pool with #, which stops at a nil constant); one of them names a global or a method, which cannot be read as nil`);
  while (k.length < uses.length) k.push(undefined);
  stats.lostConstants = stats.lostConstants || [];
  for (const slot of lost) stats.lostConstants.push({ slot, uses: uses[slot].map(([kind, pc]) => ({ kind, pc: pc + 1 })) });
}

function placeNil(code, k, ambiguity) {
  const values = k.slice(0, -1);
  const n = k.length;
  const uses = poolUses(code);
  while (uses.length < n) uses.push([]);
  if (uses.length > n) fail('the instructions use more constants than the data has');
  const fits = (v, kind) => kind === 'any' || (v !== undefined && (kind === 'value' || kind === 'key' || typeof v === kind));
  const candidates = [];
  for (let at = 0; at < n; at++) {
    if (!uses[at].length || !uses[at].every(([kind]) => kind === 'any')) continue;
    let ok = true;
    for (let slot = 0; slot < n && ok; slot++) {
      if (slot === at) continue;
      const v = values[slot < at ? slot : slot - 1];
      ok = uses[slot].every(([kind]) => fits(v, kind));
    }
    if (!ok) continue;
    candidates.push({ at });
  }
  if (!candidates.length) fail('a nil constant is missing from the data and no slot can be the one it had');
  // Still more than one: a nil constant exists because the source compared something with nil or stored nil. A slot that a comparison reads
  // is preferred over one that is only ever stored (`{ [0] = nil }` is not something programs write); that is a ranking of readings, not a
  // proof, so the caller is told how many readings there were and the report says so.
  let pick = candidates.length === 1 ? candidates[0] : null;
  if (!pick) {
    // a number as a constant table key (`t[0]`) is legal but unusual next to names; the reading that makes fewer of them is the likelier one
    const odd = (c) => { let x = 0; for (let slot = 0; slot < n; slot++) { if (slot === c.at) continue; const v = values[slot < c.at ? slot : slot - 1]; if (typeof v === 'number' && uses[slot].some(([kind]) => kind === 'key')) x++; } return x; };
    const scored = candidates.map((c) => [odd(c), c]).sort((x, y) => x[0] - y[0]);
    if (scored[0][0] < scored[1][0]) pick = scored[0][1];
  }
  if (!pick) {
    const compared = candidates.filter((c) => uses[c.at].some(([, pc]) => (code[pc] & 63) === 23));
    if (compared.length === 1) pick = compared[0];
  }
  if (!pick) fail(`a nil constant is missing from the data and ${candidates.length} slots could be the one it had`);
  ambiguity.push(candidates.length);
  k.length = 0;
  for (let slot = 0; slot < n; slot++) k.push(slot === pick.at ? undefined : values[slot < pick.at ? slot : slot - 1]);
}

/** Bytes -> the function tree sandbox/bytecode.js parseChunk() returns for a Lua 5.1 chunk (stripped: no names, no lines). */
function readChunkOnce(bytes, forceNil, accepted) {
  let pos = 0;
  const need = (n) => { if (pos + n > bytes.length) fail('the data ends inside a function'); };
  const u8 = () => { need(1); return bytes[pos++]; };
  const u16 = () => { need(2); const v = bytes[pos] | (bytes[pos + 1] << 8); pos += 2; return v; };
  const u32 = () => { need(4); const v = (bytes[pos] | (bytes[pos + 1] << 8) | (bytes[pos + 2] << 16) | (bytes[pos + 3] << 24)) >>> 0; pos += 4; return v; };
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const stats = { functions: 0, instructions: 0, constants: 0 };
  const fn = (depth) => {
    if (depth > 200) fail('functions are nested too deeply');
    const nups = u8();
    const numParams = u8();
    const maxStack = u8();
    const nCode = u32();
    if (nCode === 0 || nCode > 1 << 22) fail('implausible instruction count');
    const code = new Uint32Array(nCode);
    let isVararg = false;
    for (let i = 0; i < nCode; i++) {
      const data = u32();
      const op = u8();
      const type = u8();
      u16(); u8(); u8();                       // A, and the two "operand is a constant" flags: all of it is in the instruction word
      if (type === 1) { u16(); u16(); } else if (type === 2 || type === 3) u32(); else fail('unknown instruction layout');
      if ((data & 63) !== op || op > 37) fail('an instruction word does not carry the opcode stored next to it');
      if (op === VARARG) isVararg = true;
      code[i] = data;
    }
    const nK = u32();
    if (nK > 1 << 22) fail('implausible constant count');
    const k = [];
    for (let i = 0; i < nK; i++) {
      const at = pos;
      const t = forceNil.has(at) ? (pos++, 0) : u8();
      if (t === 1 || t === 3 || t === 4) accepted.push(at);
      if (t === 1) k.push(u8() !== 0);
      else if (t === 3) { need(8); k.push(view.getFloat64(pos, true)); pos += 8; }
      else if (t === 4) {
        const len = u32(); need(len);
        let s = '';
        for (let j = 0; j < len; j++) s += String.fromCharCode(bytes[pos + j]);
        pos += len; k.push(s);
      } else {
        // Serializer.lua writes nothing at all for a nil constant (`x == nil` makes one) but still counts it, and the interpreter then reads
        // the next constant's tag as this one's: such a script does not run. The program is still all there: the slot is nil and
        // the byte belongs to what follows. A wrong guess cannot pass silently: the rest of the chunk would stop lining up.
        pos--; k.push(undefined); stats.nilConstants = (stats.nilConstants || 0) + 1;
        if (i !== nK - 1 || stats.nilConstants > 64) fail('unknown constant type');
        placeNil(code, k, (stats.nilReadings = stats.nilReadings || []));
      }
    }
    checkMissing(code, k, stats);
    const nP = u32();
    if (nP > 1 << 16) fail('implausible function count');
    const protos = [];
    for (let i = 0; i < nP; i++) protos.push(fn(depth + 1));
    stats.functions++; stats.instructions += nCode; stats.constants += nK;
    // the serialiser writes no nil constants: an index past the pool is how the compiler says nil (LOADK never does; GETGLOBAL cannot)
    return { source: null, line: 0, lastLine: 0, nups, numParams, isVararg, maxStack: Math.max(2, maxStack), code, k, protos, lines: [], locals: [], upNames: [] };
  };
  const main = fn(0);
  if (pos !== bytes.length) fail('data is left over after the main function');
  main.isVararg = true;                        // the main chunk of a Lua 5.1 script always is
  // a closure's upvalue count is also what the instructions after CLOSURE say; a mismatch means this is not the layout that was read
  const check = (f) => {
    for (let i = 0; i < f.code.length; i++) {
      if ((f.code[i] & 63) !== CLOSURE) continue;
      const bx = f.code[i] >>> 14;
      if (bx >= f.protos.length) fail('a CLOSURE names a function that is not there');
    }
    f.protos.forEach(check);
  };
  check(main);
  return { main, stats };
}

const isStr = (n) => n && n.type === 'String' && typeof n.value === 'string';

/**
 * Bytes -> function tree. A nil constant leaves no bytes (see readChunkOnce), so the byte after it can look like the tag of a real constant
 * when it is the low byte of the next count; when the straightforward reading does not line up, each accepted tag is tried as that case.
 */
export function readChunk(bytes) {
  const accepted = [];
  try { return readChunkOnce(bytes, new Set(), accepted); } catch (e) {
    if (!(e instanceof HerculesVmError)) throw e;
    for (const at of accepted.slice(-400).reverse()) {
      try { const r = readChunkOnce(bytes, new Set([at]), []); r.stats.nilConstants = (r.stats.nilConstants || 0) + 1; return r; } catch (e2) { if (!(e2 instanceof HerculesVmError)) throw e2; }
    }
    throw e;
  }
}

/**
 * The two calls that start the interpreter: `decode('<text>', '<alphabet>')` and the statement that runs its result, `wrap(<it>, env)()`.
 * Written by the tool as one expression; after a compiled layer has been decompiled the decoded value sits in a variable in between:
 *
 *     WrapState(BcToState('...', '...'), env)()            |   v = decode('...', '...')  ...  wrap(v, env)()
 *
 * @returns {{decode: object, run: object|null, holder: object|null, text: string, alphabet: string}|null}
 */
export function findVmCall(ast) {
  let decode = null;
  walk(ast, (n) => {
    if (decode || n.type !== 'Call' || n.args.length !== 2 || !isStr(n.args[0]) || !isStr(n.args[1])) return;
    const [text, alphabet] = [n.args[0].value, n.args[1].value];
    if (alphabet.length < 2 || alphabet.length > 255 || text.length < 16 || !text.includes('_')) return;
    if (new Set(alphabet).size !== alphabet.length) return;
    decode = n;
  });
  if (!decode) return null;
  // the statement that holds the decoded value, when it is not passed on directly
  let holder = null;
  let held = null;
  walk(ast, (n) => {
    if (holder) return false;
    if (n.type === 'Assign' && n.values.length === 1 && n.values[0] === decode && n.targets.length === 1 && n.targets[0].type === 'Name') { holder = n; held = n.targets[0].name; }
    if (n.type === 'Local' && n.values.length === 1 && n.values[0] === decode && n.ids.length === 1) { holder = n; held = n.ids[0].name; }
    return undefined;
  });
  let run = null;
  walk(ast, (n) => {
    if (run || n.type !== 'Call' || n.args.length !== 0 || !n.fn || n.fn.type !== 'Call' || !n.fn.args.length) return;
    const first = n.fn.args[0];
    if (first === decode || (held && first.type === 'Name' && first.name === held)) run = n;
  });
  return { decode, run, holder, node: run, text: decode.args[0].value, alphabet: decode.args[1].value };
}

/**
 * @param {object} ast parsed script
 * @returns {{main: object, stats: object}|null} the program as a Lua 5.1 function tree, or null when the script has no such call
 * @throws {HerculesVmError} when the call is there but its data is not in the layout this reader knows
 */
export function readHerculesVm(ast) {
  const call = findVmCall(ast);
  if (!call) return null;
  const bytes = decodeText(call.text, call.alphabet);
  const r = readChunk(bytes);
  r.stats.bytes = bytes.length;
  r.stats.alphabet = call.alphabet.length;
  return r;
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Putting the program in place of the interpreter
// ---------------------------------------------------------------------------------------------------------------------------------

const PURE = new Set(['String', 'Number', 'Nil', 'True', 'False', 'Func', 'Name', 'Vararg']);
/** An expression whose evaluation cannot be observed (so a declaration that only holds it can go when nothing reads it). */
function pure(e) {
  if (!e) return true;
  if (PURE.has(e.type)) return true;
  if (e.type === 'Paren') return pure(e.expr);
  if (e.type === 'Unary') return e.op !== '#' && pure(e.arg);                           // # may call __len
  if (e.type === 'Binary') return (e.op === 'and' || e.op === 'or') && pure(e.left) && pure(e.right);
  if (e.type === 'Index') return pure(e.obj) && pure(e.key) && e.obj.type === 'Name' && /^(string|table|math|bit32|bit|os|coroutine|utf8|debug)$/.test(e.obj.name);
  if (e.type === 'Table') return e.fields.every((f) => (f.kind !== 'keyed' || pure(f.key)) && pure(f.value));
  // select('#', ...), getfenv(0), setmetatable({}, {...}): the standard calls the interpreter's prelude makes while it is being set up
  if (e.type === 'Call') return e.fn.type === 'Name' && /^(select|getfenv|setmetatable|rawget|type|tostring|tonumber)$/.test(e.fn.name) && e.args.every(pure);
  return false;
}

/** The names a declaration statement defines, or null when the statement is not a declaration that could be dropped. */
function declares(s) {
  if (s.type === 'Local') return s.values.every(pure) ? s.ids.map((i) => i.name) : null;
  if (s.type === 'LocalFunction') return [s.id.name];
  if (s.type === 'Function') return s.target.type === 'Name' && !s.method ? [s.target.name] : null;
  if (s.type === 'Assign') return s.targets.every((t) => t.type === 'Name') && s.values.every(pure) ? s.targets.map((t) => t.name) : null;
  return null;
}

/**
 * Drop the declarations among `stmts[0 .. upTo)` that nothing which stays refers to. Name based (no scopes), so a name that is
 * used anywhere in what stays keeps its declaration: it can only keep too much.
 */
export function sweepPrelude(stmts, upTo, everything) {
  const cand = new Map();                        // statement -> names it defines
  for (let i = 0; i < upTo; i++) { const d = declares(stmts[i]); if (d) cand.set(stmts[i], d); }
  // `local keep = tostring` + `function tostring(v) return keep(v) end`: a global replaced by a wrapper that only calls the original.
  // The program's own uses of that global must not keep the pair alive, so the wrapper goes and its local is left to the sweep.
  for (let i = 0; i < upTo; i++) {
    const s = stmts[i];
    if (s.type !== 'Function' || s.method || s.target.type !== 'Name' || s.func.vararg || s.func.body.length !== 1) continue;
    const ret = s.func.body[0];
    if (ret.type !== 'Return' || ret.values.length !== 1 || ret.values[0].type !== 'Call' || ret.values[0].fn.type !== 'Name') continue;
    const call = ret.values[0];
    const params = s.func.params.map((q) => q.name);
    if (call.args.length !== params.length || !call.args.every((a, k) => a.type === 'Name' && a.name === params[k])) continue;
    const saved = stmts.slice(0, i).find((d) => d.type === 'Local' && d.ids.length === 1 && d.ids[0].name === call.fn.name && d.values.length === 1 && d.values[0].type === 'Name' && d.values[0].name === s.target.name);
    if (saved) cand.set(s, []);                  // defines nothing anyone needs: never kept
  }
  // a loop that only fills a table one of the candidates declares (`for i = 0, 255 do lookup[string.char(i)] = i end`) lives and dies with it
  const declared = new Set([...cand.values()].flat());
  for (let i = 0; i < upTo; i++) {
    const s = stmts[i];
    if (cand.has(s) || !['NumFor', 'GenFor', 'While', 'Do'].includes(s.type)) continue;
    const fills = new Set();
    let ok = true;
    walk(s, (n) => {
      if (!ok) return false;
      if (n.type === 'Assign') {
        for (const t of n.targets) {
          let b = t; while (b.type === 'Index') b = b.obj;
          if (t.type !== 'Index' || b.type !== 'Name' || !declared.has(b.name)) ok = false; else fills.add(b.name);
        }
        if (!n.values.every(pure)) ok = false;
        return false;
      }
      if (n !== s && ['CallStmt', 'Return', 'Break', 'Goto', 'Function', 'LocalFunction', 'CompoundAssign', 'Local'].includes(n.type)) ok = false;
      return undefined;
    });
    const head = s.type === 'NumFor' ? [s.start, s.stop, s.step] : s.type === 'GenFor' ? [] : s.type === 'While' ? [s.cond] : [];
    if (ok && fills.size && s.type !== 'GenFor' && s.type !== 'While' && head.every(pure)) cand.set(s, [...fills].map((n) => `\u0000fill:${n}`));
  }
  const namesIn = (node) => { const out = new Set(); walk(node, (n) => { if (n.type === 'Name') out.add(n.name); }); return out; };
  const uses = new Map([...cand.keys()].map((s) => [s, namesIn(s.type === 'Local' || s.type === 'Assign' ? s.values : s.func || s)]));
  // roots: every name used outside the candidates
  const live = new Set();
  const skip = new Set(cand.keys());
  walk(everything, (n) => { if (skip.has(n)) return false; if (n.type === 'Name') live.add(n.name); return undefined; });
  const kept = new Set();
  for (let changed = true; changed;) {
    changed = false;
    for (const [s, names] of cand) {
      if (kept.has(s) || !names.some((n) => live.has(n.startsWith('\u0000fill:') ? n.slice(6) : n))) continue;
      kept.add(s); changed = true;
      for (const u of uses.get(s)) live.add(u);
    }
  }
  let removed = 0;
  for (let i = upTo - 1; i >= 0; i--) if (cand.has(stmts[i]) && !kept.has(stmts[i])) { stmts.splice(i, 1); removed++; }
  return removed;
}

/**
 * Replace the statement that runs the interpreter with `body` (the decompiled program) and drop the interpreter's own declarations.
 * @returns {number} statements removed, or -1 when the call is not a statement of its own (then nothing was changed)
 */
export function replaceVmCall(ast, callNode, body, holder = null) {
  let where = null;
  const visit = (stmts) => {
    for (let i = 0; i < stmts.length && !where; i++) {
      const s = stmts[i];
      if ((s.type === 'CallStmt' && s.call === callNode) || (s.type === 'Return' && s.values.length === 1 && s.values[0] === callNode)) { where = { stmts, i }; return; }
      walk(s, (n) => { if (where) return false; if (Array.isArray(n.body) && n !== s) visit(n.body); if (n.type === 'If') { n.clauses.forEach((c) => visit(c.body)); if (n.orelse) visit(n.orelse); } return undefined; });
      if (Array.isArray(s.body)) visit(s.body);
    }
  };
  visit(ast.body);
  if (!where) return -1;
  where.stmts.splice(where.i, 1, ...body);
  let extra = 0;
  if (holder) {
    // `v = decode(text, alphabet)`: its only reader was the statement that has just been replaced
    transformDrop(ast, holder);
    extra = 1;
  }
  const at = where.stmts.indexOf(body[0]);
  return extra + sweepPrelude(where.stmts, at < 0 ? where.i : at, ast);
}

/** Remove one statement node from whichever block holds it. */
function transformDrop(ast, target) {
  const visit = (stmts) => {
    const i = stmts.indexOf(target);
    if (i >= 0) { stmts.splice(i, 1); return true; }
    for (const s of stmts) {
      if (Array.isArray(s.body) && visit(s.body)) return true;
      if (s.type === 'If') { for (const c of s.clauses) if (visit(c.body)) return true; if (s.orelse && visit(s.orelse)) return true; }
      let hit = false;
      walk(s, (n) => { if (hit) return false; if (n.type === 'Func' && visit(n.body)) hit = true; return undefined; });
      if (hit) return true;
    }
    return false;
  };
  return visit(ast.body);
}
