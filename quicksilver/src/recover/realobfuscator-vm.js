// RealObfuscator (github.com/linkoro57/RealObfuscator, GPL-3.0; read as text, nothing of it is copied here): the function VM lifted back to source.
//
// What the generator does (src/function_vm.rs at 9ec569f, as read): a function body it can compile becomes
//
//     return RUNNER(BANK[id], { externals }, { parameters }, ...)
//
// BANK[id] holds the function's instructions: five 32-bit words each (op, a, b, c, the position of the next instruction) in a byte order shuffled per
// function, a checksum, optionally run-length packed, and every record encoded with a 32-bit xorshift stream keyed by a per-function seed, salt and
// step and the record's position. Every opcode has two to four random aliases; the runtime dispatches on them through a tree of `op < N` tests whose
// leaves are fixed handler templates. The instructions form a linked list in shuffled order (each names the next one; jumps name their target).
//
// The instruction set is a small register machine with a few habits of its own:
//   - every source local is a one-slot cell (`r[a] = { r[b] }`, read `r[b][1]`, written `r[a][1] = v`), so that closures can share it;
//   - argument and result lists are tables with a count (`{ n = 0 }`, pushed onto, unpacked at the call);
//   - names that are not locals of the function are reached through accessor closures (`function(v, w) if w then x = v else return x end end`);
//   - closures, method calls and generic `for` loops are written as plain Lua in a factory closure (an "external") that reaches the function's cells
//     as `P[register][1]`; a generic `for` calls back into the VM for its body, which ends in a signal (0: next iteration, 1: break).
//
// The lifter reads the runtime (the slots of the bank record, the handler of every alias, matched by what it does), decodes every record with the
// checksum verified, follows the linked list into basic blocks and writes each block as statements: temporaries used once are folded into the
// expression that uses them (only in evaluation order), argument lists become argument lists, cells become locals, factories become the closure,
// method call or `for` loop they stand for. The graph is then structured (src/decompile/cfg.js). Call sites are lifted innermost first, so a
// closure's own body is already source when the function that makes it is lifted.

import { walk, clone } from '../core/walk.js';
import { print } from '../core/printer.js';
import { structure, CfgError } from '../decompile/cfg.js';

export class RealObfuscatorVmError extends Error {}
const fail = (m) => { throw new RealObfuscatorVmError(m); };
const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const text = (n) => print({ type: 'Chunk', body: Array.isArray(n) ? n : [n], endComments: [], features: new Set() });
const flat = (n) => text(n).replace(/\s+/g, ' ').trim();
const name = (n) => ({ type: 'Name', name: n });
const num = (v) => (v < 0 ? { type: 'Unary', op: '-', arg: { type: 'Number', value: -v, raw: null } } : { type: 'Number', value: v, raw: null });
const str = (v) => ({ type: 'String', value: v, raw: null });
const idx = (o, k) => ({ type: 'Index', obj: o, key: k });
const call = (fn, args) => ({ type: 'Call', fn, args });
const isName = (e, n) => { e = strip(e); return !!e && (e.type === 'Name' || e.type === 'Id') && (n === undefined || e.name === n); };
const u32 = (x) => x >>> 0;

// ---- the runtime ------------------------------------------------------------------------------------------------------------------------------------

/** The runtime function: three parameters and `...`, decoding records with a 32-bit xorshift. */
function findRunner(ast) {
  let found = null;
  walk(ast, (n) => {
    if (found) return false;
    const f = n.type === 'LocalFunction' ? n.func : null;
    if (!f || f.params.length !== 3 || !f.vararg) return undefined;
    const t = text(f.body);
    if (/% 4294967296/.test(t) && /, 13\)/.test(t) && /, 17\)/.test(t) && /2147483647|== 24|~= 24/.test(t)) found = { decl: n, fn: f, name: n.id.name };
    return undefined;
  });
  return found;
}

/** Where each field of a bank record is, read off the runtime's own uses of them. */
function readSchema(runner) {
  const f = runner.fn;
  const P = f.params[0].name;
  const t = text(f.body);
  const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const p = esc(P);
  const one = (re, what) => { const m = re.exec(t); if (!m) fail(`the runtime does not read the ${what} where this reader expects it`); return m; };
  const keys = one(new RegExp(`bxor\\(${p}\\[(\\d+)\\], ${p}\\[(\\d+)\\], \\w+\\)`), 'seed and salt');
  const step = one(new RegExp(`\\+ ${p}\\[(\\d+)\\] \\+ \\w+ \\+ \\w+ - \\w+ \\+ 1\\) % 4294967296`), 'step');
  const count = one(new RegExp(`> ${p}\\[(\\d+)\\] or`), 'record count');
  const consts = one(new RegExp(`${p}\\[(\\d+)\\]\\[\\w+\\]\\(\\)`), 'constants');
  // locals taken from the record: `local X = P[n]`, told apart by how they are used
  const locals = new Map();
  for (const s of f.body) if (s.type === 'Local' && s.ids.length === 1 && s.values.length === 1 && strip(s.values[0]).type === 'Index' && isName(strip(s.values[0]).obj, P) && strip(strip(s.values[0]).key).type === 'Number') locals.set(s.ids[0].name, strip(strip(s.values[0]).key).value);
  let payload = null; let offsets = null; let layout = null;
  for (const [v, slot] of locals) {
    const e = esc(v);
    if (new RegExp(`\\w+\\(${e}\\[1\\]\\), \\w+\\(${e}\\[2\\]\\)`).test(t)) layout = slot;
    else if (new RegExp(`\\(${e}, \\w+\\)|${e}\\[\\w+\\]\\[\\w+\\]`).test(t)) payload = slot;
    else if (new RegExp(`${e}\\[\\w+ \\+ 1\\] - 1`).test(t)) offsets = slot;
  }
  if (payload === null || layout === null) fail('the payload or the byte layout of the records was not found in the runtime');
  // the entry: the last call of a local function with a field of the record
  let entry = null;
  for (const s of f.body) walk(s, (n) => { if (n.type === 'Call' && n.args.length === 1 && strip(n.args[0]).type === 'Index' && isName(strip(n.args[0]).obj, P) && strip(strip(n.args[0]).key).type === 'Number') entry = strip(strip(n.args[0]).key).value; });
  if (entry === null) fail('the entry instruction of a function was not found in the runtime');
  return { seed: +keys[1], salt: +keys[2], step: +step[1], count: +count[1], constants: +consts[1], payload, offsets, layout, entry };
}

/** The library functions the runtime keeps in locals: `local a, b = string.byte, bit32.bxor`. */
function libraryAliases(ast) {
  const map = new Map();
  for (const s of ast.body) {
    if (s.type !== 'Local' || !s.values || s.values.length !== s.ids.length) continue;
    s.ids.forEach((id, i) => {
      const v = strip(s.values[i]);
      if (v.type === 'Index' && isName(v.obj) && strip(v.key).type === 'String') map.set(id.name, `${v.obj.name}.${strip(v.key).value}`);
      else if (isName(v) && ['error', 'next', 'pairs', 'select', 'type'].includes(v.name)) map.set(id.name, v.name);
    });
  }
  return map;
}

/** The dispatch loop: names of op, a, b, c and pc, and every leaf of the range tree. */
function readDispatch(runner) {
  let loop = null;
  let names = null;
  let exec = null;
  walk(runner.fn, (n) => {
    if (names) return false;
    if (n.type === 'LocalFunction' && n.func.params.length === 1) {
      walk(n.func.body, (m) => {
        if (names || m.type !== 'While') return undefined;
        const d = m.body.find((s) => s.type === 'Local' && s.ids.length === 4 && s.values.length === 4 && s.values.every((v, i) => strip(v).type === 'Index' && strip(strip(v).key).type === 'Number' && strip(strip(v).key).value === i + 1));
        if (d) { names = d.ids.map((x) => x.name); loop = m; exec = n; }
        return undefined;
      });
    }
    return undefined;
  });
  if (!names) fail('the dispatch loop of the runtime was not found');
  const pc = exec.func.params[0].name;
  const tree = loop.body.find((s) => s.type === 'If' && strip(s.clauses[0].cond).type === 'Binary' && ['<', '=='].includes(strip(s.clauses[0].cond).op) && isName(strip(s.clauses[0].cond).left, names[0]));
  if (!tree) fail('the dispatch tree was not found');
  const leaves = new Map();
  const elseOf = (s) => (s.clauses.length > 1 ? [{ ...s, clauses: s.clauses.slice(1) }] : (s.orelse || []));
  const visit = (s, depth) => {
    if (!s || s.type !== 'If' || depth > 64) return;
    const c = strip(s.clauses[0].cond);
    if (c.type === 'Binary' && c.op === '<') { visit(s.clauses[0].body[0], depth + 1); visit(elseOf(s)[0], depth + 1); return; }
    if (c.type === 'Binary' && c.op === '==' && strip(c.right).type === 'Number') { leaves.set(strip(c.right).value, s.clauses[0].body); visit(elseOf(s)[0], depth + 1); }
  };
  visit(tree, 0);
  if (leaves.size < 8) fail(`the dispatch tree has ${leaves.size} handler(s)`);
  return { names, pc, exec: exec.id.name, leaves };
}

// ---- what a handler does ----------------------------------------------------------------------------------------------------------------------------

const BIN = new Set(['+', '-', '*', '/', '//', '%', '^', '..', '==', '~=', '<', '<=', '>', '>=']);
const FLIP = { '<': '>', '>': '<', '<=': '>=', '>=': '<=', '==': '==', '~=': '~=' };

/**
 * The operation a handler performs, from its text with the runtime's names put back as R (registers), A, B, C, PC, K(i) (the constant reader),
 * X (the externals), VA (the varargs) and the library functions by their own names.
 */
export function classifyHandler(canon) {
  const t = canon;
  const simple = {
    'R[A] = K(B)': 'Constant', 'R[A] = R[B]': 'Move', 'R[A] = X[B]()': 'Read', 'X[A](R[B], true)': 'Write',
    'R[A] = R[B][R[C]]': 'Index', 'R[A][R[B]] = R[C]': 'SetIndex', 'R[A] = table.create(B)': 'Table', 'R[A] = { n = 0 }': 'List',
    'R[A] = R[B][C]': 'Item', 'R[A] = R[B](table.unpack(R[C], 1, R[C].n))': 'Call', 'R[A] = table.pack(R[B](table.unpack(R[C], 1, R[C].n)))': 'CallMany',
    'R[A] = VA[1]': 'Vararg', 'R[A] = VA': 'VarargMany', 'return 2, R[A]': 'Return', 'PC = A': 'Jump', 'if not R[A] then PC = B end': 'JumpFalse',
    'if R[A] then PC = B end': 'JumpTrue', 'R[A][1] += R[A][3]': 'ForNext', 'R[A][1] = R[A][1] + R[A][3]': 'ForNext',
    'R[A] = string.format(table.unpack(R[B], 1, R[B].n))': 'Format', 'return A, nil': 'Signal', 'R[A] = { R[B] }': 'Bind', 'R[A] = R[B][1]': 'CellGet', 'R[A][1] = R[B]': 'CellSet',
  };
  if (simple[t]) return { op: simple[t] };
  if (/^local (\w+) = R\[A\] \1\.n \+= 1 \1\[\1\.n\] = R\[B\]$/.test(t) || /^local (\w+) = R\[A\] \1\.n = \1\.n \+ 1 \1\[\1\.n\] = R\[B\]$/.test(t)) return { op: 'Push' };
  if (/^local (\w+) = R\[A\] local (\w+) = R\[B\] for (\w+) = 1, \2\.n do \1\[\1\.n \+ \3\] = \2\[\3\] end \1\.n (\+= \2\.n|= \1\.n \+ \2\.n)$/.test(t)) return { op: 'Extend' };
  if (/^local (\w+) = R\[B\] R\[A\] = \1\[3\] > 0 and \1\[1\] <= \1\[2\] or \1\[3\] <= 0 and \1\[1\] >= \1\[2\]$/.test(t)) return { op: 'ForCheck' };
  if (/table\.create\(C - 1 \+ \w+\.n\)/.test(t) && /\bnext\b/.test(t) && /R\[A\] = \w+$/.test(t)) return { op: 'TableExtend' };
  if (/^if C == 0 then R\[A\] = X\[B\]\(R, /.test(t)) return { op: 'Native' };
  if (/X\[B\]\(R, function\(\)/.test(t) && /PC = C$/.test(t)) return { op: 'GenericFor' };
  if (/#R\[C\]/.test(t) && /R\[A\] = X\[B\]\(\w+\)$/.test(t)) return { op: 'Closure' };
  let m = /^R\[A\] = R\[B\] (\S+) R\[C\]$/.exec(t);
  if (m && BIN.has(m[1])) return { op: 'Binary', operator: m[1] };
  m = /^R\[A\] = R\[C\] (\S+) R\[B\]$/.exec(t);
  if (m && FLIP[m[1]]) return { op: 'Binary', operator: FLIP[m[1]] };
  m = /^R\[A\] = R\[B\] (\S+) K\(C\)$/.exec(t);
  if (m && BIN.has(m[1])) return { op: 'BinaryConstant', operator: m[1] };
  m = /^R\[A\] = K\(C\) (\S+) R\[B\]$/.exec(t);
  if (m && FLIP[m[1]]) return { op: 'BinaryConstant', operator: FLIP[m[1]] };
  m = /^R\[A\] = (-|not |#)\(?R\[B\]\)?$/.exec(t);
  if (m) return { op: 'Unary', operator: m[1].trim() };
  return null;
}

function canonical(body, ctx) {
  const declared = new Set();
  walk(body, (n) => {
    if (n.type === 'Local') n.ids.forEach((x) => declared.add(x.name));
    if (n.type === 'NumFor') declared.add(n.id.name);
    if (n.type === 'GenFor') n.ids.forEach((x) => declared.add(x.name));
    if (n.type === 'LocalFunction') declared.add(n.id.name);
    return undefined;
  });
  const copy = clone(body);
  const rename = (n) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(rename); return; }
    if (n.type === 'Name' && !declared.has(n.name)) {
      if (ctx.roles.has(n.name)) n.name = ctx.roles.get(n.name);
      else if (ctx.aliases.has(n.name)) n.name = ctx.aliases.get(n.name);
    }
    for (const k of Object.keys(n)) if (k !== 'line' && n[k] && typeof n[k] === 'object') rename(n[k]);
  };
  rename(copy);
  // K(i): calls of the constant reader
  return flat(copy).replace(/\bK\((\w+)\)/g, 'K($1)');
}

// ---- the records ------------------------------------------------------------------------------------------------------------------------------------

function numberOf(e) {
  e = strip(e);
  if (e && e.type === 'Number') return e.value;
  if (e && e.type === 'Unary' && e.op === '-' && strip(e.arg).type === 'Number') return -strip(e.arg).value;
  return null;
}
function fieldsOf(t) {
  const m = new Map();
  let i = 1;
  for (const f of t.fields) {
    if (f.kind === 'item') m.set(i++, f.value);
    else if (f.kind === 'keyed' && numberOf(f.key) !== null) m.set(numberOf(f.key), f.value);
  }
  return m;
}
const listOf = (e) => (strip(e) && strip(e).type === 'Table' ? [...fieldsOf(strip(e)).entries()].sort((a, b) => a[0] - b[0]).map(([, v]) => v) : null);

/** Decode one function's records: [{op, a, b, c, next}] by physical position (1-based). */
export function decodeRecords(rec, schema) {
  const seed = numberOf(rec.get(schema.seed));
  const salt = numberOf(rec.get(schema.salt));
  const step = numberOf(rec.get(schema.step));
  const count = numberOf(rec.get(schema.count));
  const layout = (listOf(rec.get(schema.layout)) || []).map(numberOf);
  const payloadNode = strip(rec.get(schema.payload));
  if ([seed, salt, step, count].some((x) => x === null) || layout.length !== 5 || layout.some((x) => x === null)) fail('a function record is missing its keys or byte layout');
  let payload = null;
  let records = null;
  if (payloadNode && payloadNode.type === 'String') payload = payloadNode.value;
  else if (payloadNode && payloadNode.type === 'Table') records = listOf(payloadNode).map((r) => (listOf(r) || []).map(numberOf));
  else fail('the payload of a function record is neither a string nor a list of records');
  const offsets = payload !== null ? (listOf(rec.get(schema.offsets)) || []).map(numberOf) : null;
  const out = [null];
  for (let index = 1; index <= count; index++) {
    const cipher = payload !== null ? Array.from(payload.slice(offsets[index - 1] - 1, offsets[index] - 1), (c) => c.charCodeAt(0)) : records[index - 1];
    if (!cipher || cipher.some((x) => x === null)) fail(`record ${index} could not be read`);
    let key = u32(seed ^ salt ^ index);
    const raw = [];
    cipher.forEach((c, i) => {
      key = u32(key ^ (key << 13));
      key = u32(key ^ (key >>> 17));
      key = u32(key ^ (key << 5));
      raw.push((c ^ key) & 255);
      key = (key + step + c + i + 1) % 4294967296;
    });
    let bytes;
    if (raw[0] === 0) bytes = raw.slice(1);
    else if (raw[0] === 1) {
      bytes = [];
      for (let i = 1; i < raw.length;) {
        if (raw[i] === 255) { for (let k = 0; k < raw[i + 1]; k++) bytes.push(raw[i + 2]); i += 3; } else { bytes.push(raw[i]); i++; }
      }
    } else fail(`record ${index} has an unknown packing (${raw[0]})`);
    if (bytes.length !== 24) fail(`record ${index} decodes to ${bytes.length} bytes, not 24`);
    const word = (o) => bytes[o - 1] + bytes[o] * 256 + bytes[o + 1] * 65536 + bytes[o + 2] * 16777216;
    let hash = index;
    for (let i = 0; i < 20; i++) hash = (hash * 257 + bytes[i]) % 2147483647;
    if (hash !== word(21)) fail(`record ${index} fails its checksum: the keys were not read right`);
    const w = layout.map(word);
    out.push({ op: w[0], a: w[1], b: w[2], c: w[3], next: w[4] });
  }
  return out;
}

// ---- lifting one function ---------------------------------------------------------------------------------------------------------------------------

const READS = {
  Constant: [], Move: ['b'], Read: [], Write: ['b'], Index: ['b', 'c'], SetIndex: ['a', 'b', 'c'], Table: [], TableExtend: ['a', 'b'], List: [], Push: ['a', 'b'],
  Extend: ['a', 'b'], Item: ['b'], Call: ['b', 'c'], CallMany: ['b', 'c'], Vararg: [], VarargMany: [], Return: ['a'], Jump: [], JumpFalse: ['a'], JumpTrue: ['a'],
  Binary: ['b', 'c'], BinaryConstant: ['b'], Unary: ['b'], ForCheck: ['b'], ForNext: ['a'], Format: ['b'], Native: [], GenericFor: [], Signal: [], Bind: ['b'],
  CellGet: ['b'], CellSet: ['a', 'b'], Closure: ['c'],
};
const DEFINES = new Set(['Constant', 'Move', 'Read', 'Index', 'Table', 'List', 'Item', 'Call', 'CallMany', 'Vararg', 'VarargMany', 'Binary', 'BinaryConstant', 'Unary', 'ForCheck', 'Format', 'Native', 'Closure', 'CellGet']);

class FunctionLifter {
  constructor(ctx, code, constants, externals, params, vararg) {
    this.ctx = ctx; this.code = code; this.K = constants; this.X = externals; this.params = params; this.vararg = vararg;
    this.cells = new Map();          // register -> local name
    this.temps = new Set();          // registers that need a function-level local
    this.ops = new Map();
    for (let i = 1; i < code.length; i++) {
      const h = ctx.handlers.get(code[i].op);
      if (!h) fail(`opcode ${code[i].op} has no handler in the runtime`);
      this.ops.set(i, h);
    }
    // how often each register is written and read
    this.defs = new Map(); this.uses = new Map();
    const bump = (m, r) => m.set(r, (m.get(r) || 0) + 1);
    const tables = new Set();
    for (const [i, h] of this.ops) if (h.op === 'Table') tables.add(code[i].a);
    for (const [i, h] of this.ops) {
      const ins = code[i];
      for (const f of READS[h.op] || []) {
        // building a list or a table is not reading it: only what finally takes it counts
        if (f === 'a' && (h.op === 'Push' || h.op === 'Extend' || h.op === 'TableExtend' || (h.op === 'SetIndex' && tables.has(ins.a)))) continue;
        bump(this.uses, ins[f]);
      }
      if (DEFINES.has(h.op) || h.op === 'Bind') bump(this.defs, ins.a);
    }
    // lists that are only read item by item (a multiple assignment, a numeric for's start, limit and step) become one local per item
    const readers = new Map();
    const lists = new Set();
    for (const [i, h] of this.ops) {
      const ins = code[i];
      if (h.op === 'List') lists.add(ins.a);
      if (h.op === 'Extend') lists.delete(ins.a);
      for (const f of READS[h.op] || []) {
        if (f === 'a' && h.op === 'Push') continue;
        const r = ins[f];
        if (!readers.has(r)) readers.set(r, new Set());
        readers.get(r).add(h.op);
      }
    }
    this.itemized = new Map();
    this.itemOnly = new Set([...lists].filter((r) => this.defs.get(r) === 1 && readers.has(r) && [...readers.get(r)].every((k) => k === 'Item' || k === 'ForCheck' || k === 'ForNext') && this.uses.get(r) > 1));
    params.forEach((p, i) => this.cells.set(i + 1, p));
    this.n = 0;
  }

  cellName(r) {
    // cells are named per function: a closure's own locals must not shadow the cells of the function around it that it reaches
    if (!this.cells.has(r)) this.cells.set(r, `v${this.id}_${r}`);
    return this.cells.get(r);
  }
  constant(i) {
    const f = this.K[i - 1];
    if (!f) fail(`constant ${i} does not exist`);
    const fn = strip(f);
    if (fn.type !== 'Func' || fn.body.length !== 1 || fn.body[0].type !== 'Return' || fn.body[0].values.length !== 1) fail(`constant ${i} is not \`function() return value end\``);
    return clone(fn.body[0].values[0]);
  }
  external(i) {
    const e = this.X[i - 1];
    if (!e) fail(`external ${i} does not exist`);
    return strip(e);
  }
  /** `function(v, w) if w then x = v else return x end end` -> x (an expression that can be read and assigned) */
  accessor(i) {
    const f = this.external(i);
    if (f.type !== 'Func' || f.params.length !== 2) fail(`external ${i} is not an accessor`);
    let target = null;
    walk(f.body, (n) => { if (!target && n.type === 'Return' && n.values.length === 1) target = n.values[0]; });
    if (!target) fail(`external ${i} is not an accessor`);
    return clone(this.substituteCells(target, null));
  }
  /** `P[reg][1]` (a cell of this function reached from a factory) -> the cell's local */
  substituteCells(node, P) {
    const self = this;
    const sub = (n) => {
      if (!n || typeof n !== 'object') return n;
      if (Array.isArray(n)) return n.map(sub);
      if (n.type === 'Index' && numberOf(n.key) === 1 && strip(n.obj).type === 'Index' && (P ? isName(strip(n.obj).obj, P) : false) && numberOf(strip(n.obj).key) !== null) return name(self.cellName(numberOf(strip(n.obj).key)));
      const c = { ...n };
      for (const k of Object.keys(c)) if (k !== 'line' && c[k] && typeof c[k] === 'object') c[k] = sub(c[k]);
      return c;
    };
    return sub(node);
  }

  lift() {
    const entry = this.entry;
    // blocks: leaders are the entry, jump targets and the instruction after a branch
    const succ = (i) => {
      const ins = this.code[i];
      const h = this.ops.get(i);
      if (h.op === 'Jump') return [ins.a];
      if (h.op === 'JumpFalse' || h.op === 'JumpTrue') return [ins.next, ins.b];
      if (h.op === 'Return' || h.op === 'Signal') return [];
      if (h.op === 'GenericFor') return [ins.c];
      return [ins.next];
    };
    return this.region(entry, succ, null);
  }

  /** The statements of the code reachable from `start` (a function body, or a `for` body that ends in signals). */
  region(start, succ, loopBody) {
    const reach = new Set();
    const order = [];
    const stack = [start];
    while (stack.length) {
      const i = stack.pop();
      if (i === 0 || reach.has(i)) continue;
      if (!this.ops.has(i)) fail(`an instruction names ${i}, which does not exist`);
      reach.add(i); order.push(i);
      for (const s of succ(i)) stack.push(s);
    }
    const preds = new Map([...reach].map((i) => [i, 0]));
    for (const i of reach) for (const s of succ(i)) if (preds.has(s)) preds.set(s, preds.get(s) + 1);
    // a block starts where control can come from more than one place, and wherever an instruction ends its block by naming where to go
    const ENDS = new Set(['Jump', 'JumpFalse', 'JumpTrue', 'GenericFor', 'Return', 'Signal']);
    const targets = new Set();
    for (const p of reach) if (ENDS.has(this.ops.get(p).op)) for (const t of succ(p)) targets.add(t);
    const leader = (i) => i === start || preds.get(i) !== 1 || targets.has(i);
    const blocks = new Map();
    const EXIT = 'exit';
    blocks.set(EXIT, { stmts: [], term: { kind: 'exit' } });
    for (const i of order) {
      if (!leader(i)) continue;
      const b = { stmts: [], term: null };
      const em = new Emitter(this, b.stmts);
      let cur = i;
      for (;;) {
        const h = this.ops.get(cur);
        const ins = this.code[cur];
        const t = em.step(h, ins, cur);
        if (t) {
          em.flush();
          if (t.kind === 'signal') {
            if (!loopBody) fail('a loop signal outside a generic for body');
            if (ins.a === 1) b.stmts.push({ type: 'Break' });
            else if (ins.a !== 0) fail(`signal ${ins.a}`);
            b.term = { kind: 'goto', to: EXIT };
            if (ins.a === 1) b.breaks = true;
          } else if (t.kind === 'return') b.term = { kind: 'return', values: t.values };
          else if (t.kind === 'branch') b.term = { kind: 'branch', cond: t.cond, t: t.t || EXIT, f: t.f || EXIT };
          else if (t.kind === 'goto') b.term = { kind: 'goto', to: t.to || EXIT };
          break;
        }
        const nx = ins.next;
        if (nx === 0) { em.flush(); b.term = { kind: 'goto', to: EXIT }; break; }
        if (leader(nx)) { em.flush(); b.term = { kind: 'goto', to: nx }; break; }
        cur = nx;
      }
      blocks.set(i, b);
    }
    // a `break` inside a loop of the region would leave the wrong loop
    if (loopBody) for (const [id, b] of blocks) if (b.breaks && this.inCycle(id, blocks)) fail('a break from a loop nested inside a generic for body');
    try {
      return structure(blocks, start, { negate: (c) => ({ type: 'Unary', op: 'not', arg: c.type === 'Binary' ? { type: 'Paren', expr: c } : c }), makeReturn: (v) => ({ type: 'Return', values: v || [] }) });
    } catch (e) {
      if (e instanceof CfgError) fail(`the control flow could not be structured: ${e.message}`);
      throw e;
    }
  }
  inCycle(id, blocks) {
    const next = (b) => { const t = blocks.get(b) && blocks.get(b).term; if (!t) return []; return t.kind === 'goto' ? [t.to] : t.kind === 'branch' ? [t.t, t.f] : []; };
    const seen = new Set();
    const stack = next(id);
    while (stack.length) { const n = stack.pop(); if (n === id) return true; if (seen.has(n)) continue; seen.add(n); stack.push(...next(n)); }
    return false;
  }
}

/** Statements of one block, with single-use temporaries folded into their use in evaluation order. */
class Emitter {
  constructor(L, out) { this.L = L; this.out = out; this.pending = []; this.values = new Map(); }

  reg(r) { return `r${r}`; }
  /** Use register r as an operand: its folded expression when it is pending, else its local. */
  take(r, used) {
    const p = this.pending.findIndex((x) => x.r === r);
    if (p >= 0) { used.push(p); return this.pending[p]; }
    if (this.values.has(r)) return this.values.get(r);
    this.L.temps.add(r);
    return { expr: name(this.reg(r)) };
  }
  /** Operands are only folded when they are the newest pending values, taken in the order they were made (Lua evaluates left to right) */
  commit(used) {
    const n = this.pending.length;
    const ok = used.every((p, i) => p === n - used.length + i);
    if (!ok) return false;
    this.pending.splice(n - used.length, used.length);
    return true;
  }
  /** Evaluate operands; when they cannot all be folded, write everything pending out first and read them as locals */
  operands(regs) {
    let used = [];
    let vals = regs.map((r) => this.take(r, used));
    if (!this.commit(used)) {
      this.flush();
      used = [];
      vals = regs.map((r) => this.take(r, used));
    }
    return vals;
  }
  define(r, v) {
    const L = this.L;
    if ((L.defs.get(r) === 1 && L.uses.get(r) === 1) || (v.list && L.itemOnly.has(r))) { this.pending.push({ r, ...v }); return; }
    if (L.defs.get(r) === 1 && !L.uses.get(r)) {
      // a value nothing reads: only a call is kept, as a statement
      this.flush();
      if (v.expr && (strip(v.expr).type === 'Call' || strip(v.expr).type === 'MethodCall')) this.out.push({ type: 'CallStmt', call: v.expr });
      else if (v.list) this.materialise({ r, ...v });
      return;
    }
    this.flush();
    this.materialise({ r, ...v });
  }
  materialise(p) {
    const L = this.L;
    L.temps.add(p.r);
    const target = name(this.reg(p.r));
    if (p.list && L.itemOnly.has(p.r) && !p.list.tail) {
      const ids = p.list.items.map((_, i) => ({ type: 'Id', name: `${this.reg(p.r)}_${i + 1}` }));
      L.temps.delete(p.r);
      L.itemized.set(p.r, ids.length);
      if (ids.length) this.out.push({ type: 'Local', ids, values: p.list.items });
      return;
    }
    if (p.list) {
      // a list that is read in more than one place: a table with its count, like the runtime's
      const items = [...p.list.items, ...(p.list.tail ? [p.list.tail] : [])];
      this.out.push({ type: 'Assign', targets: [target], values: [call(idx(name('table'), str('pack')), items)] });
      return;
    }
    if (p.table) { this.out.push({ type: 'Assign', targets: [target], values: [p.table] }); return; }
    if (p.multi) { this.out.push({ type: 'Assign', targets: [target], values: [call(idx(name('table'), str('pack')), [p.multi])] }); return; }
    this.out.push({ type: 'Assign', targets: [target], values: [p.expr] });
  }
  flush() { const ps = this.pending; this.pending = []; for (const p of ps) this.materialise(p); }
  stmt(s) { this.out.push(s); }

  /** Items of a list operand: folded lists give their items, a materialised one is unpacked */
  items(v) {
    if (v.list) return [...v.list.items, ...(v.list.tail ? [v.list.tail] : [])];
    return [call(idx(name('table'), str('unpack')), [v.expr, num(1), idx(v.expr, str('n'))])];
  }
  exprOf(v) {
    if (v.expr) return v.expr;
    if (v.list) return call(idx(name('table'), str('pack')), this.items(v));
    if (v.table) return v.table;
    if (v.multi) return call(idx(name('table'), str('pack')), [v.multi]);
    return fail('an operand without a value');
  }

  step(h, ins, pc) {
    const L = this.L;
    const { a, b, c } = ins;
    switch (h.op) {
      case 'Constant': this.define(a, { expr: L.constant(b) }); return null;
      case 'Move': { const [v] = this.operands([b]); this.define(a, { expr: this.exprOf(v) }); return null; }
      case 'Read': this.define(a, { expr: L.accessor(b) }); return null;
      case 'Write': { const [v] = this.operands([b]); this.flush(); this.stmt({ type: 'Assign', targets: [L.accessor(a)], values: [this.exprOf(v)] }); return null; }
      case 'Index': { const [o, k] = this.operands([b, c]); this.define(a, { expr: idx(this.exprOf(o), this.exprOf(k)) }); return null; }
      case 'SetIndex': {
        // a table being built: its fields go into the constructor
        const p = this.pending.length && this.pending[this.pending.length - 1];
        const [t, k, v] = this.operands([a, b, c]);
        if (t.table && t.r === a && strip(t.table).type === 'Table') {
          strip(t.table).fields.push({ kind: 'keyed', key: this.exprOf(k), value: this.exprOf(v) });
          this.pending.push(t);
          void p;
          return null;
        }
        this.flush();
        this.stmt({ type: 'Assign', targets: [idx(this.exprOf(t), this.exprOf(k))], values: [this.exprOf(v)] });
        return null;
      }
      case 'Table': this.define(a, { table: { type: 'Table', fields: [] } }); return null;
      case 'TableExtend': {
        const [t, vs] = this.operands([a, b]);
        if (t.table && t.r === a && strip(t.table).type === 'Table' && strip(t.table).fields.length === c - 1 && vs.multi) {
          strip(t.table).fields.push({ kind: 'item', value: vs.multi });
          this.pending.push(t);
          return null;
        }
        return fail('a table constructor extended in a way this reader does not write');
      }
      case 'List': this.define(a, { list: { items: [], tail: null } }); return null;
      case 'Push': case 'Extend': {
        const [l, v] = this.operands([a, b]);
        if (l.list && l.r === a && !l.list.tail) {
          if (h.op === 'Push') l.list.items.push(this.exprOf(v));
          else if (v.multi) l.list.tail = v.multi;
          else l.list.tail = call(idx(name('table'), str('unpack')), [this.exprOf(v), num(1), idx(this.exprOf(v), str('n'))]);
          this.pending.push(l);
          return null;
        }
        // a list that lives in a local: the runtime's own push
        this.flush();
        const t = this.exprOf(l);
        if (h.op === 'Push') {
          this.stmt({ type: 'Assign', targets: [idx(t, str('n'))], values: [{ type: 'Binary', op: '+', left: idx(t, str('n')), right: num(1) }] });
          this.stmt({ type: 'Assign', targets: [idx(t, idx(t, str('n')))], values: [this.exprOf(v)] });
        } else {
          const items = v.multi ? call(idx(name('table'), str('pack')), [v.multi]) : this.exprOf(v);
          this.stmt({ type: 'CallStmt', call: call(name('__qs_extend'), [t, items]) });
          L.ctx.needsExtend = true;
        }
        return null;
      }
      case 'Item': {
        if (L.itemOnly.has(b) && this.pending.some((p) => p.r === b)) this.flush();
        if (L.itemized.has(b)) { this.define(a, { expr: c <= L.itemized.get(b) ? name(`r${b}_${c}`) : { type: 'Nil' } }); return null; }
        const [l] = this.operands([b]);
        if (l.list && !l.list.tail && L.uses.get(b) === 1) { this.define(a, { expr: l.list.items[c - 1] || { type: 'Nil' } }); return null; }
        if (l.list && L.uses.get(b) === 1) { const items = this.items(l); this.define(a, { expr: c === 1 && items.length === 1 ? { type: 'Paren', expr: items[0] } : idx(call(idx(name('table'), str('pack')), items), num(c)) }); return null; }
        this.define(a, { expr: idx(this.exprOf(l), num(c)) });
        return null;
      }
      case 'Call': case 'CallMany': {
        const [f, args] = this.operands([b, c]);
        const e = call(this.exprOf(f), this.items(args));
        if (h.op === 'Call') this.define(a, { expr: e }); else this.define(a, { multi: e });
        return null;
      }
      case 'Vararg': if (!L.vararg) fail('`...` in a function that has none'); this.define(a, { expr: { type: 'Paren', expr: { type: 'Vararg' } } }); return null;
      case 'VarargMany': this.define(a, { multi: { type: 'Vararg' } }); return null;
      case 'Format': { const [l] = this.operands([b]); this.define(a, { expr: call(idx(name('string'), str('format')), this.items(l)) }); return null; }
      case 'Binary': { const [x, y] = this.operands([b, c]); this.define(a, { expr: { type: 'Binary', op: h.operator, left: this.exprOf(x), right: this.exprOf(y) } }); return null; }
      case 'BinaryConstant': { const [x] = this.operands([b]); this.define(a, { expr: { type: 'Binary', op: h.operator, left: this.exprOf(x), right: L.constant(c) } }); return null; }
      case 'Unary': { const [x] = this.operands([b]); this.define(a, { expr: { type: 'Unary', op: h.operator, arg: this.exprOf(x) } }); return null; }
      case 'Bind': {
        if (a === b && L.cells.has(a) && a <= L.params.length) return null;          // a parameter: it is its own cell
        const [v] = this.operands([b]);
        this.flush();
        this.stmt({ type: 'Local', ids: [{ type: 'Id', name: L.cellName(a) }], values: [this.exprOf(v)] });
        return null;
      }
      case 'CellGet': this.define(a, { expr: name(L.cellName(b)) }); return null;
      case 'CellSet': { const [v] = this.operands([b]); this.flush(); this.stmt({ type: 'Assign', targets: [name(L.cellName(a))], values: [this.exprOf(v)] }); return null; }
      case 'ForCheck': {
        let f;
        if (L.itemOnly.has(b) && this.pending.some((p) => p.r === b)) this.flush();
        if (L.itemized.has(b)) f = (i) => name(`r${b}_${i}`);
        else { const [s] = this.operands([b]); const st = this.exprOf(s); f = (i) => idx(st, num(i)); }
        const gt0 = { type: 'Binary', op: '>', left: f(3), right: num(0) };
        const le0 = { type: 'Binary', op: '<=', left: f(3), right: num(0) };
        this.define(a, { expr: { type: 'Binary', op: 'or', left: { type: 'Binary', op: 'and', left: gt0, right: { type: 'Binary', op: '<=', left: f(1), right: f(2) } }, right: { type: 'Binary', op: 'and', left: le0, right: { type: 'Binary', op: '>=', left: f(1), right: f(2) } } } });
        return null;
      }
      case 'ForNext': {
        if (L.itemOnly.has(a) && this.pending.some((p) => p.r === a)) this.flush();
        if (L.itemized.has(a)) { this.flush(); this.stmt({ type: 'Assign', targets: [name(`r${a}_1`)], values: [{ type: 'Binary', op: '+', left: name(`r${a}_1`), right: name(`r${a}_3`) }] }); return null; }
        const [s] = this.operands([a]); this.flush(); const st = this.exprOf(s); this.stmt({ type: 'Assign', targets: [idx(st, num(1))], values: [{ type: 'Binary', op: '+', left: idx(st, num(1)), right: idx(st, num(3)) }] }); return null; }
      case 'Closure': {
        this.operands([c]);                       // the list of cells it captures: the factory names them itself
        const f = L.external(b);
        if (f.type !== 'Func' || f.params.length !== 1) fail(`external ${b} is not a closure factory`);
        const P = f.params[0].name;
        const ret = f.body[f.body.length - 1];
        if (!ret || ret.type !== 'Return' || ret.values.length !== 1 || f.body.length !== 1) fail(`the closure factory ${b} does more than return its closure`);
        this.define(a, { expr: L.substituteCells(ret.values[0], P) });
        L.ctx.stats.closures++;
        return null;
      }
      case 'Native': {
        const f = L.external(b);
        if (f.type !== 'Func' || !f.params.length) fail(`external ${b} is not a native bridge`);
        let P = f.params[0].name;
        let body = f.body;
        // the bridge that keeps the cells of this invocation: `local P = { [k] = CB[k], ... }`
        if (body.length === 2 && body[0].type === 'Local' && body[0].ids.length === 1 && strip(body[0].values[0]).type === 'Table') { P = body[0].ids[0].name; body = body.slice(1); }
        if (body.length !== 1 || body[0].type !== 'Return' || body[0].values.length !== 1) fail(`the native bridge ${b} is not a single call`);
        const e = L.substituteCells(body[0].values[0], P);
        this.flush();
        if (c === 0) this.define(a, { expr: e }); else this.define(a, { multi: e });
        L.ctx.stats.methodCalls++;
        return null;
      }
      case 'GenericFor': {
        this.flush();
        const f = L.external(b);
        if (f.type !== 'Func' || f.params.length < 2) fail(`external ${b} is not a generic for bridge`);
        const P = f.params[0].name;
        const loop = f.body.find((s) => s.type === 'GenFor');
        if (!loop) fail(`the generic for bridge ${b} has no loop`);
        const vars = loop.ids.map((x) => x.name);
        // `P[reg] = { var }`: the cells the body reads its loop variables from
        const binds = [];
        for (const s of loop.body) {
          if (s.type === 'Assign' && s.targets.length === 1 && s.targets[0].type === 'Index' && isName(s.targets[0].obj, P) && numberOf(s.targets[0].key) !== null) {
            const v = strip(s.values[0]);
            if (v.type === 'Table' && v.fields.length === 1 && isName(v.fields[0].value)) binds.push([numberOf(s.targets[0].key), v.fields[0].value.name]);
          }
        }
        const iter = loop.exprs.map((e) => L.substituteCells(e, P));
        const fresh = vars.map((v) => `${v}_${++L.n}`);
        const pre = binds.map(([reg, v]) => ({ type: 'Local', ids: [{ type: 'Id', name: L.cellName(reg) }], values: [name(fresh[vars.indexOf(v)])] }));
        const succ = (i) => {
          const x = this.L.code[i];
          const hh = this.L.ops.get(i);
          if (hh.op === 'Jump') return [x.a];
          if (hh.op === 'JumpFalse' || hh.op === 'JumpTrue') return [x.next, x.b];
          if (hh.op === 'Return' || hh.op === 'Signal') return [];
          if (hh.op === 'GenericFor') return [x.c];
          return [x.next];
        };
        const body = L.region(a, succ, true);
        const stmt = { ...clone(loop), body: [...pre, ...body] };
        stmt.ids = fresh.map((n) => ({ type: 'Id', name: n }));
        stmt.exprs = iter;
        this.stmt(stmt);
        L.ctx.stats.forLoops++;
        return { kind: 'goto', to: c };
      }
      case 'Jump': return { kind: 'goto', to: a };
      case 'JumpFalse': case 'JumpTrue': {
        const [v] = this.operands([a]);
        this.flush();
        const cond = this.exprOf(v);
        return h.op === 'JumpFalse' ? { kind: 'branch', cond, t: ins.next, f: b } : { kind: 'branch', cond, t: b, f: ins.next };
      }
      case 'Return': { const [l] = this.operands([a]); this.flush(); return { kind: 'return', values: this.items(l) }; }
      case 'Signal': return { kind: 'signal' };
      default: return fail(`an operation this reader does not write: ${h.op}`);
    }
  }
}

// ---- the program ------------------------------------------------------------------------------------------------------------------------------------

/** Is this RealObfuscator's function VM? */
export function looksLikeRealObfuscatorVm(ast) {
  return !!findRunner(ast);
}

/**
 * Lift every VM function of the script in place. Throws RealObfuscatorVmError when any part is not read; the script is only changed when
 * every call site was lifted.
 */
export function liftRealObfuscatorVm(chunk) {
  const work = clone(chunk);
  const runner = findRunner(work);
  if (!runner) fail('the RealObfuscator runtime was not found');
  const schema = readSchema(runner);
  const dispatch = readDispatch(runner);
  const aliases = libraryAliases(work);
  // the runtime's names, by role
  const f = runner.fn;
  const roles = new Map([[f.params[1].name, 'X'], [f.params[2].name, 'R'], [dispatch.names[0], 'OP'], [dispatch.names[1], 'A'], [dispatch.names[2], 'B'], [dispatch.names[3], 'C'], [dispatch.pc, 'PC']]);
  walk(f.body, (n) => {
    if (n.type === 'LocalFunction' && n.func.params.length === 1 && new RegExp(`\\[${schema.constants}\\]\\[\\w+\\]\\(\\)`).test(text(n.func.body))) roles.set(n.id.name, 'K');
    if (n.type === 'Local' && n.ids.length === 1 && n.values.length === 1 && strip(n.values[0]).type === 'Call' && /pack$/.test(aliases.get(strip(strip(n.values[0]).fn).name) || strip(strip(n.values[0]).fn).name || '') && strip(n.values[0]).args.length === 1 && strip(strip(n.values[0]).args[0]).type === 'Vararg') roles.set(n.ids[0].name, 'VA');
    return undefined;
  });
  const handlers = new Map();
  const unknown = [];
  for (const [id, body] of dispatch.leaves) {
    const h = classifyHandler(canonical(body, { roles, aliases }));
    if (h) handlers.set(id, h); else unknown.push(id);
  }
  const ctx = { functionIds: 0, handlers, stats: { functions: 0, instructions: 0, closures: 0, methodCalls: 0, forLoops: 0 }, needsExtend: false };
  // the bank: a table of records that each carry a five-entry byte layout and a payload where the schema says
  let bank = null;
  let bankDecl = null;
  let bankName = null;
  walk(work, (x) => {
    if (bank || x.type !== 'Local' || x.ids.length !== 1 || x.values.length !== 1 || strip(x.values[0]).type !== 'Table') return undefined;
    const t = fieldsOf(strip(x.values[0]));
    if (!t.size) return undefined;
    const isRecord = (v) => { v = strip(v); if (!v || v.type !== 'Table') return false; const f = fieldsOf(v); const l = listOf(f.get(schema.layout)); return !!l && l.length === 5 && f.has(schema.payload); };
    if ([...t.values()].every(isRecord)) { bank = t; bankDecl = x; bankName = x.ids[0].name; }
    return undefined;
  });
  if (!bank) fail('the bank of function records was not found');
  // call sites: `return RUNNER(BANK[id], { externals }, { parameters }, ...)` as the whole body of a function, innermost first
  const sites = [];
  const visitFn = (fnNode) => {
    walk(fnNode.body, (x) => { if (x.type === 'Func' && x !== fnNode) { visitFn(x); return false; } return undefined; });
    const b = fnNode.body;
    if (b.length === 1 && b[0].type === 'Return' && b[0].values.length === 1) {
      const c = strip(b[0].values[0]);
      if (c.type === 'Call' && isName(c.fn, runner.name) && c.args.length >= 3 && strip(c.args[0]).type === 'Index' && isName(strip(c.args[0]).obj, bankName)) sites.push({ fn: fnNode, call: c });
    }
  };
  walk(work, (x) => { if (x.type === 'Func') { visitFn(x); return false; } return undefined; });
  // the chunk itself may be a call site
  if (work.body.length && work.body[work.body.length - 1].type === 'Return') {
    const c = strip(work.body[work.body.length - 1].values[0]);
    if (c && c.type === 'Call' && isName(c.fn, runner.name) && c.args.length >= 3 && strip(c.args[0]).type === 'Index' && isName(strip(c.args[0]).obj, bankName)) sites.push({ fn: work, call: c, chunk: true });
  }
  if (!sites.length) fail('no function body is a call of the runtime');
  if (unknown.length) {
    // an alias no program uses may stay unread; one that is used stops the lift below
    ctx.unknownAliases = unknown.length;
  }
  for (const site of sites) {
    const c = site.call;
    const id = numberOf(strip(c.args[0]).key);
    const rec = bank.get(id);
    if (!rec || strip(rec).type !== 'Table') fail(`the bank has no record ${id}`);
    const fields = fieldsOf(strip(rec));
    const code = decodeRecords(fields, schema);
    const constants = listOf(fields.get(schema.constants)) || [];
    const externals = listOf(c.args[1]) || fail('the externals of a call site are not a table');
    const params = (listOf(c.args[2]) || fail('the parameters of a call site are not a table')).map((p) => { if (!isName(p)) fail('a parameter of a call site is not a name'); return strip(p).name; });
    const vararg = c.args.length > 3;
    const L = new FunctionLifter(ctx, code, constants, externals, params, vararg);
    L.id = ++ctx.functionIds;
    L.entry = numberOf(fields.get(schema.entry));
    let body = L.lift();
    const temps = [...L.temps].sort((x, y) => x - y).map((r) => ({ type: 'Id', name: `r${r}` }));
    if (temps.length) body = [{ type: 'Local', ids: temps, values: [] }, ...body];
    if (site.chunk) work.body.splice(work.body.length - 1, 1, ...body); else site.fn.body = body;
    ctx.stats.functions++;
    ctx.stats.instructions += code.length - 1;
  }
  // the runtime and the bank go once nothing calls them
  const drop = new Set([runner.decl, bankDecl]);
  work.body = work.body.filter((s) => !drop.has(s));
  let left = false;
  walk(work, (x) => { if (x.type === 'Call' && x.args.length >= 3 && strip(x.args[0]).type === 'Index' && isName(strip(x.args[0]).obj, bankName)) left = true; return undefined; });
  if (left) fail('a call of the runtime is left that is not a function body');
  if (ctx.needsExtend) work.body.unshift(...EXTEND());
  chunk.body = work.body;
  return { changed: ctx.stats.instructions, ...ctx.stats, handlers: handlers.size, unreadAliases: unknown.length };
}

function EXTEND() {
  // a list kept in a local that is extended with another: what the runtime's Extend does
  return [{ type: 'LocalFunction', id: { type: 'Id', name: '__qs_extend' }, func: { type: 'Func', params: [{ type: 'Id', name: 'list' }, { type: 'Id', name: 'values' }], vararg: false, body: [
    { type: 'NumFor', id: { type: 'Id', name: 'i' }, start: num(1), stop: idx(name('values'), str('n')), step: null, body: [{ type: 'Assign', targets: [idx(name('list'), { type: 'Binary', op: '+', left: idx(name('list'), str('n')), right: name('i') })], values: [idx(name('values'), name('i'))] }] },
    { type: 'Assign', targets: [idx(name('list'), str('n'))], values: [{ type: 'Binary', op: '+', left: idx(name('list'), str('n')), right: idx(name('values'), str('n')) }] },
  ] } }];
}
