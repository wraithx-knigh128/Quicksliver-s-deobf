// Lua 5.1 and 5.4 bytecode: reader, disassembler and an executor for the sandbox.
//
// Some obfuscators ship the program as a compiled chunk (`load("\27Lua...")`). Two things are useful with
// such a chunk: reading it (constants, functions, instructions) and, for behaviour analysis, running it
// under the same limits as any other sandboxed code. Both are done here for the PUC-Rio formats of Lua 5.1
// (little or big endian, 4 or 8 byte size_t) and Lua 5.4 (64-bit integers). Lua 5.2/5.3, Luau and LuaJIT
// bytecode are different formats and are reported as unsupported rather than guessed at.

import { LuaTable, LuaFunction, LuaError, truthy, toNumber, typeName } from './value.js';
import { index, setIndex, arith, negate, concat, length, equals, lessThan, lessEqual, callValue } from './interp.js';

export class BytecodeError extends Error {}

export const OPS = ['MOVE', 'LOADK', 'LOADBOOL', 'LOADNIL', 'GETUPVAL', 'GETGLOBAL', 'GETTABLE', 'SETGLOBAL', 'SETUPVAL', 'SETTABLE', 'NEWTABLE', 'SELF',
  'ADD', 'SUB', 'MUL', 'DIV', 'MOD', 'POW', 'UNM', 'NOT', 'LEN', 'CONCAT', 'JMP', 'EQ', 'LT', 'LE', 'TEST', 'TESTSET', 'CALL', 'TAILCALL', 'RETURN',
  'FORLOOP', 'FORPREP', 'TFORLOOP', 'SETLIST', 'CLOSE', 'CLOSURE', 'VARARG'];
const [MOVE, LOADK, LOADBOOL, LOADNIL, GETUPVAL, GETGLOBAL, GETTABLE, SETGLOBAL, SETUPVAL, SETTABLE, NEWTABLE, SELF, ADD, SUB, MUL, DIV, MOD, POW, UNM, NOT,
  LEN, CONCAT, JMP, EQ, LT, LE, TEST, TESTSET, CALL, TAILCALL, RETURN, FORLOOP, FORPREP, TFORLOOP, SETLIST, CLOSE, CLOSURE, VARARG] = OPS.map((_, i) => i);
const BX_OPS = new Set([LOADK, GETGLOBAL, SETGLOBAL, CLOSURE]);
const SBX_OPS = new Set([JMP, FORLOOP, FORPREP]);
const FIELDS_PER_FLUSH = 50;

export const isBytecode = (bin) => bin.length >= 4 && bin.charCodeAt(0) === 0x1b && bin.slice(1, 4) === 'Lua';

// ---- reader ----------------------------------------------------------------------------------------------------------------------

class Reader {
  constructor(bin) {
    this.s = bin;
    this.p = 0;
    this.little = true;
    this.intSize = 4;
    this.sizeT = 8;
    this.numSize = 8;
  }

  need(n) { if (this.p + n > this.s.length) throw new BytecodeError('the chunk is truncated'); }

  byte() { this.need(1); return this.s.charCodeAt(this.p++); }

  uint(size) {
    this.need(size);
    let v = 0;
    for (let i = 0; i < size; i++) {
      const b = this.s.charCodeAt(this.p + (this.little ? size - 1 - i : i));
      v = v * 256 + b;
    }
    this.p += size;
    return v;
  }

  int() { return this.uint(this.intSize); }

  size() {
    const v = this.uint(this.sizeT);
    if (v > 0x7fffffff) throw new BytecodeError('implausible string length in chunk');
    return v;
  }

  number() {
    this.need(this.numSize);
    const buf = new DataView(new ArrayBuffer(8));
    for (let i = 0; i < this.numSize; i++) buf.setUint8(i, this.s.charCodeAt(this.p + i));
    this.p += this.numSize;
    return this.numSize === 8 ? buf.getFloat64(0, this.little) : buf.getFloat32(0, this.little);
  }

  string() {
    const n = this.size();
    if (n === 0) return null;
    this.need(n);
    const str = this.s.slice(this.p, this.p + n - 1);
    this.p += n;
    return str;
  }
}

/** Parse a Lua 5.1 chunk into a tree of function prototypes. */
export function parseChunk(bin) {
  if (!isBytecode(bin)) throw new BytecodeError('not a Lua bytecode chunk');
  const r = new Reader(bin);
  r.p = 4;
  const version = r.byte();
  if (version === 0x54) return parseChunk54(r, bin);
  if (version !== 0x51) throw new BytecodeError(`unsupported bytecode version 0x${version.toString(16)} (only Lua 5.1 and 5.4 chunks can be read)`);
  const format = r.byte();
  if (format !== 0) throw new BytecodeError('unsupported bytecode format (not the official one)');
  r.little = r.byte() === 1;
  r.intSize = r.byte();
  r.sizeT = r.byte();
  const instrSize = r.byte();
  r.numSize = r.byte();
  const integral = r.byte();
  if (![4, 8].includes(r.intSize) || ![4, 8].includes(r.sizeT) || instrSize !== 4 || ![4, 8].includes(r.numSize) || integral !== 0) {
    throw new BytecodeError('unsupported bytecode layout (sizes in the header are not those of a standard Lua 5.1 build)');
  }
  const header = { little: r.little, intSize: r.intSize, sizeT: r.sizeT, numSize: r.numSize };

  const readFunction = (parentSource, depth) => {
    if (depth > 200) throw new BytecodeError('function nesting too deep');
    const f = { source: r.string() || parentSource, line: r.int(), lastLine: r.int(), nups: r.byte(), numParams: r.byte(), isVararg: r.byte() & 1, maxStack: r.byte() };
    const ncode = r.int();
    if (ncode > 4_000_000) throw new BytecodeError('implausible instruction count');
    f.code = new Uint32Array(ncode);
    for (let i = 0; i < ncode; i++) f.code[i] = r.uint(4);
    const nk = r.int();
    if (nk > 4_000_000) throw new BytecodeError('implausible constant count');
    f.k = new Array(nk);
    for (let i = 0; i < nk; i++) {
      const t = r.byte();
      if (t === 0) f.k[i] = undefined;
      else if (t === 1) f.k[i] = r.byte() !== 0;
      else if (t === 3) f.k[i] = r.number();
      else if (t === 4) f.k[i] = r.string() ?? '';
      else throw new BytecodeError(`unknown constant type ${t}`);
    }
    const np = r.int();
    if (np > 100_000) throw new BytecodeError('implausible function count');
    f.protos = [];
    for (let i = 0; i < np; i++) f.protos.push(readFunction(f.source, depth + 1));
    const nl = r.int();
    f.lines = new Array(nl);
    for (let i = 0; i < nl; i++) f.lines[i] = r.int();
    const nv = r.int();
    f.locals = [];
    for (let i = 0; i < nv; i++) f.locals.push({ name: r.string(), start: r.int(), end: r.int() });
    const nu = r.int();
    f.upNames = [];
    for (let i = 0; i < nu; i++) f.upNames.push(r.string());
    return f;
  };
  const main = readFunction(null, 0);
  main.version = 0x51;
  return { version: 0x51, header, main, bytes: r.p };
}

// ---- disassembler ---------------------------------------------------------------------------------------------------------------

export function decodeInstruction(word) {
  const op = word & 63;
  const A = (word >>> 6) & 255;
  const C = (word >>> 14) & 511;
  const B = (word >>> 23) & 511;
  const Bx = word >>> 14;
  return { op, A, B, C, Bx, sBx: Bx - 131071 };
}

const kText = (v) => (v === undefined ? 'nil' : typeof v === 'string' ? JSON.stringify(v).slice(0, 60) : String(v));

/** A luac -l style listing of a function and everything nested in it. */
export function disassemble(chunk) {
  const out = [];
  const walk = (f, name, depth) => {
    out.push(`${'  '.repeat(depth)}function <${name}> (${f.code.length} instructions, ${f.numParams} params${f.isVararg ? ', vararg' : ''}, ${f.maxStack} slots, ${f.nups} upvalues, ${f.k.length} constants, ${f.protos.length} functions)`);
    const pad = '  '.repeat(depth + 1);
    for (let pc = 0; pc < f.code.length; pc++) {
      const d = decodeInstruction(f.code[pc]);
      const name2 = OPS[d.op] || `OP${d.op}`;
      const rk = (x) => (x >= 256 ? `K${x - 256}(${kText(f.k[x - 256])})` : `R${x}`);
      let args;
      if (BX_OPS.has(d.op)) args = `${d.A} ${d.Bx}`;
      else if (SBX_OPS.has(d.op)) args = `${d.A} ${d.sBx}  ; to ${pc + 2 + d.sBx}`;
      else args = `${d.A} ${d.B} ${d.C}`;
      let note = '';
      if (d.op === LOADK) note = `; ${kText(f.k[d.Bx])}`;
      else if (d.op === GETGLOBAL || d.op === SETGLOBAL) note = `; ${kText(f.k[d.Bx])}`;
      else if ([GETTABLE, SELF].includes(d.op)) note = `; ${rk(d.C)}`;
      else if ([SETTABLE, ADD, SUB, MUL, DIV, MOD, POW, EQ, LT, LE].includes(d.op)) note = `; ${rk(d.B)} ${rk(d.C)}`;
      const line = f.lines[pc] !== undefined ? `[${f.lines[pc]}]` : '';
      out.push(`${pad}${String(pc + 1).padStart(4)} ${line.padEnd(7)}${name2.padEnd(9)}${args.padEnd(18)}${note}`);
    }
    f.protos.forEach((p, i) => walk(p, `${name}/${i}`, depth + 1));
  };
  walk(chunk.main, 'main', 0);
  return out.join('\n');
}

// ---- executor ---------------------------------------------------------------------------------------------------------------------

class UpCell {
  constructor(regs, i) { this.regs = regs; this.i = i; this.v = undefined; this.open = true; }
  get() { return this.open ? this.regs[this.i] : this.v; }
  set(x) { if (this.open) this.regs[this.i] = x; else this.v = x; }
  close() { if (this.open) { this.v = this.regs[this.i]; this.open = false; } }
}

function runtimeProto(parsed) {
  if (parsed.runtime) return parsed.runtime;
  parsed.version = parsed.version || 0x51;
  const rt = {
    name: parsed.source || '?',
    line: parsed.line,
    nparams: parsed.numParams,
    hasVararg: !!parsed.isVararg,
    call(m, fn, args) { return (parsed.version === 0x54 ? execute54 : execute)(m, parsed, fn, args); },
  };
  parsed.runtime = rt;
  return rt;
}

function execute(m, f, fn, args) {
  m.tick();
  if (++m.depth > m.maxDepth) { m.depth--; throw m.error('stack overflow'); }
  const code = f.code;
  const K = f.k;
  const R = new Array(f.maxStack + 1);
  const upvals = fn.upvals;
  const env = fn.env;
  const np = f.numParams;
  for (let i = 0; i < np; i++) R[i] = args[i];
  const va = f.isVararg && args.length > np ? args.slice(np) : [];
  let open = null;
  let top = 0;
  let pc = 0;
  const rk = (x) => (x >= 256 ? K[x - 256] : R[x]);
  const closeFrom = (a) => {
    if (!open) return;
    for (const [i, cell] of open) if (i >= a) { cell.close(); open.delete(i); }
  };
  try {
    for (;;) {
      if (pc >= code.length) return [];
      const word = code[pc++];
      const op = word & 63;
      const A = (word >>> 6) & 255;
      m.tick();
      if (f.lines.length) m.line = f.lines[pc - 1] || m.line;
      switch (op) {
        case MOVE: R[A] = R[(word >>> 23) & 511]; break;
        case LOADK: R[A] = K[word >>> 14]; break;
        case LOADBOOL: R[A] = ((word >>> 23) & 511) !== 0; if ((word >>> 14) & 511) pc++; break;
        case LOADNIL: for (let i = A, e = (word >>> 23) & 511; i <= e; i++) R[i] = undefined; break;
        case GETUPVAL: R[A] = upvals[(word >>> 23) & 511].get(); break;
        case GETGLOBAL: { const key = K[word >>> 14]; const v = env.getStr(key); R[A] = v !== undefined || env.meta === null ? v : index(m, env, key); break; }
        case GETTABLE: R[A] = index(m, R[(word >>> 23) & 511], rk((word >>> 14) & 511)); break;
        case SETGLOBAL: setIndex(m, env, K[word >>> 14], R[A]); break;
        case SETUPVAL: upvals[(word >>> 23) & 511].set(R[A]); break;
        case SETTABLE: setIndex(m, R[A], rk((word >>> 23) & 511), rk((word >>> 14) & 511)); break;
        case NEWTABLE: R[A] = new LuaTable(); break;
        case SELF: { const obj = R[(word >>> 23) & 511]; R[A + 1] = obj; R[A] = index(m, obj, rk((word >>> 14) & 511)); break; }
        case ADD: R[A] = arith(m, '+', rk((word >>> 23) & 511), rk((word >>> 14) & 511)); break;
        case SUB: R[A] = arith(m, '-', rk((word >>> 23) & 511), rk((word >>> 14) & 511)); break;
        case MUL: R[A] = arith(m, '*', rk((word >>> 23) & 511), rk((word >>> 14) & 511)); break;
        case DIV: R[A] = arith(m, '/', rk((word >>> 23) & 511), rk((word >>> 14) & 511)); break;
        case MOD: R[A] = arith(m, '%', rk((word >>> 23) & 511), rk((word >>> 14) & 511)); break;
        case POW: R[A] = arith(m, '^', rk((word >>> 23) & 511), rk((word >>> 14) & 511)); break;
        case UNM: R[A] = negate(m, R[(word >>> 23) & 511]); break;
        case NOT: R[A] = !truthy(R[(word >>> 23) & 511]); break;
        case LEN: R[A] = length(m, R[(word >>> 23) & 511]); break;
        case CONCAT: {
          const b = (word >>> 23) & 511;
          const c = (word >>> 14) & 511;
          let acc = R[c];
          for (let i = c - 1; i >= b; i--) acc = concat(m, R[i], acc);
          R[A] = acc;
          break;
        }
        case JMP: pc += (word >>> 14) - 131071; break;
        case EQ: if (equals(m, rk((word >>> 23) & 511), rk((word >>> 14) & 511)) !== (A !== 0)) pc++; break;
        case LT: if (lessThan(m, rk((word >>> 23) & 511), rk((word >>> 14) & 511)) !== (A !== 0)) pc++; break;
        case LE: if (lessEqual(m, rk((word >>> 23) & 511), rk((word >>> 14) & 511)) !== (A !== 0)) pc++; break;
        case TEST: if (truthy(R[A]) !== (((word >>> 14) & 511) !== 0)) pc++; break;
        case TESTSET: { const v = R[(word >>> 23) & 511]; if (truthy(v) === (((word >>> 14) & 511) !== 0)) R[A] = v; else pc++; break; }
        case CALL:
        case TAILCALL: {
          const b = (word >>> 23) & 511;
          const c = (word >>> 14) & 511;
          const n = b !== 0 ? b - 1 : top - A - 1;
          const callArgs = new Array(n);
          for (let i = 0; i < n; i++) callArgs[i] = R[A + 1 + i];
          const res = callValue(m, R[A], callArgs, '');
          if (op === TAILCALL) { closeFrom(0); return res; }
          if (c === 0) { for (let i = 0; i < res.length; i++) R[A + i] = res[i]; top = A + res.length; }
          else for (let i = 0; i < c - 1; i++) R[A + i] = res[i];
          break;
        }
        case RETURN: {
          const b = (word >>> 23) & 511;
          const n = b !== 0 ? b - 1 : top - A;
          const out = new Array(n);
          for (let i = 0; i < n; i++) out[i] = R[A + i];
          closeFrom(0);
          return out;
        }
        case FORLOOP: {
          const step = R[A + 2];
          const idx = R[A] + step;
          const limit = R[A + 1];
          if (step > 0 ? idx <= limit : idx >= limit) { pc += (word >>> 14) - 131071; R[A] = idx; R[A + 3] = idx; }
          break;
        }
        case FORPREP: {
          const init = toNumber(R[A]);
          const limit = toNumber(R[A + 1]);
          const step = toNumber(R[A + 2]);
          if (init === undefined) throw m.error("'for' initial value must be a number");
          if (limit === undefined) throw m.error("'for' limit must be a number");
          if (step === undefined) throw m.error("'for' step must be a number");
          R[A] = init - step; R[A + 1] = limit; R[A + 2] = step;
          pc += (word >>> 14) - 131071;
          break;
        }
        case TFORLOOP: {
          const c = (word >>> 14) & 511;
          const res = callValue(m, R[A], [R[A + 1], R[A + 2]], '');
          for (let i = 0; i < c; i++) R[A + 3 + i] = res[i];
          if (R[A + 3] !== undefined) R[A + 2] = R[A + 3]; else pc++;
          break;
        }
        case SETLIST: {
          const b = (word >>> 23) & 511;
          let c = (word >>> 14) & 511;
          const n = b !== 0 ? b : top - A - 1;
          if (c === 0) c = code[pc++];
          const t = R[A];
          const base = (c - 1) * FIELDS_PER_FLUSH;
          for (let i = 1; i <= n; i++) t.listSet(base + i, R[A + i]);
          break;
        }
        case CLOSE: closeFrom(A); break;
        case CLOSURE: {
          const child = f.protos[word >>> 14];
          const cells = new Array(child.nups);
          for (let i = 0; i < child.nups; i++) {
            const pseudo = code[pc++];
            const b = (pseudo >>> 23) & 511;
            if ((pseudo & 63) === MOVE) {
              if (!open) open = new Map();
              let cell = open.get(b);
              if (!cell) { cell = new UpCell(R, b); open.set(b, cell); }
              cells[i] = cell;
            } else cells[i] = upvals[b];
          }
          R[A] = new LuaFunction(runtimeProto(child), cells, env);
          break;
        }
        case VARARG: {
          const b = (word >>> 23) & 511;
          if (b === 0) { for (let i = 0; i < va.length; i++) R[A + i] = va[i]; top = A + va.length; }
          else for (let i = 0; i < b - 1; i++) R[A + i] = va[i];
          break;
        }
        default: throw new LuaError(`bad bytecode: unknown opcode ${op}`);
      }
    }
  } finally {
    closeFrom(0);
    m.depth--;
  }
}

/** Compile a bytecode chunk into a function bound to `env`. */
export function loadBytecode(m, bin, env) {
  const chunk = parseChunk(bin);
  const e = env || m.globals;
  // a 5.4 main function reaches its globals through upvalue 0 (_ENV)
  const ups = chunk.version === 0x54 ? [Object.assign(new UpCell([e], 0), { open: false, v: e })] : [];
  chunk.main.version = chunk.version;
  return new LuaFunction(runtimeProto(chunk.main), ups, e);
}


// =====================================================================================================================
// Lua 5.4
// =====================================================================================================================

export const OPS54 = ['MOVE', 'LOADI', 'LOADF', 'LOADK', 'LOADKX', 'LOADFALSE', 'LFALSESKIP', 'LOADTRUE', 'LOADNIL', 'GETUPVAL', 'SETUPVAL', 'GETTABUP', 'GETTABLE',
  'GETI', 'GETFIELD', 'SETTABUP', 'SETTABLE', 'SETI', 'SETFIELD', 'NEWTABLE', 'SELF', 'ADDI', 'ADDK', 'SUBK', 'MULK', 'MODK', 'POWK', 'DIVK', 'IDIVK', 'BANDK',
  'BORK', 'BXORK', 'SHRI', 'SHLI', 'ADD', 'SUB', 'MUL', 'MOD', 'POW', 'DIV', 'IDIV', 'BAND', 'BOR', 'BXOR', 'SHL', 'SHR', 'MMBIN', 'MMBINI', 'MMBINK', 'UNM',
  'BNOT', 'NOT', 'LEN', 'CONCAT', 'CLOSE', 'TBC', 'JMP', 'EQ', 'LT', 'LE', 'EQK', 'EQI', 'LTI', 'LEI', 'GTI', 'GEI', 'TEST', 'TESTSET', 'CALL', 'TAILCALL',
  'RETURN', 'RETURN0', 'RETURN1', 'FORLOOP', 'FORPREP', 'TFORPREP', 'TFORCALL', 'TFORLOOP', 'SETLIST', 'CLOSURE', 'VARARG', 'VARARGPREP', 'EXTRAARG'];
const O = Object.fromEntries(OPS54.map((n, i) => [n, i]));
const LUAC_DATA = '\x19\x93\r\n\x1a\n';

Reader.prototype.varint = function varint() {
  let x = 0;
  for (;;) {
    const b = this.byte();
    x = x * 128 + (b & 0x7f);
    if (x > 0x7fffffff) throw new BytecodeError('implausible size in chunk');
    if (b & 0x80) return x;
  }
};
Reader.prototype.string54 = function string54() {
  const size = this.varint();
  if (size === 0) return null;
  const n = size - 1;
  this.need(n);
  const str = this.s.slice(this.p, this.p + n);
  this.p += n;
  return str;
};
Reader.prototype.int64 = function int64() {
  this.need(8);
  const dv = new DataView(new ArrayBuffer(8));
  for (let i = 0; i < 8; i++) dv.setUint8(i, this.s.charCodeAt(this.p + i));
  this.p += 8;
  return Number(dv.getBigInt64(0, true));
};
Reader.prototype.double54 = function double54() {
  this.need(8);
  const dv = new DataView(new ArrayBuffer(8));
  for (let i = 0; i < 8; i++) dv.setUint8(i, this.s.charCodeAt(this.p + i));
  this.p += 8;
  return dv.getFloat64(0, true);
};

function parseChunk54(r, bin) {
  const format = r.byte();
  if (format !== 0) throw new BytecodeError('unsupported bytecode format (not the official one)');
  if (bin.slice(r.p, r.p + 6) !== LUAC_DATA) throw new BytecodeError('corrupted chunk header (LUAC_DATA mismatch)');
  r.p += 6;
  const sizes = [r.byte(), r.byte(), r.byte()];
  if (sizes[0] !== 4 || sizes[1] !== 8 || sizes[2] !== 8) throw new BytecodeError('unsupported Lua 5.4 build (instruction/integer/number sizes are not 4/8/8)');
  if (r.int64() !== 0x5678) throw new BytecodeError('unsupported byte order or integer format');
  if (r.double54() !== 370.5) throw new BytecodeError('unsupported floating point format');
  const mainUps = r.byte();

  const readFunction = (parentSource, depth) => {
    if (depth > 200) throw new BytecodeError('function nesting too deep');
    const f = { version: 0x54, source: r.string54() || parentSource, line: r.varint(), lastLine: r.varint(), numParams: r.byte(), isVararg: r.byte() & 1, maxStack: r.byte() };
    const ncode = r.varint();
    if (ncode > 4_000_000) throw new BytecodeError('implausible instruction count');
    r.need(ncode * 4);
    f.code = new Uint32Array(ncode);
    for (let i = 0; i < ncode; i++) { f.code[i] = r.uint(4); }
    const nk = r.varint();
    if (nk > 4_000_000) throw new BytecodeError('implausible constant count');
    f.k = new Array(nk);
    for (let i = 0; i < nk; i++) {
      const t = r.byte();
      if (t === 0) f.k[i] = undefined;
      else if (t === 1) f.k[i] = false;
      else if (t === 17) f.k[i] = true;
      else if (t === 19) f.k[i] = r.double54();
      else if (t === 3) f.k[i] = r.int64();
      else if (t === 4 || t === 20) f.k[i] = r.string54() ?? '';
      else throw new BytecodeError(`unknown constant type ${t}`);
    }
    const nu = r.varint();
    f.upDescs = [];
    for (let i = 0; i < nu; i++) f.upDescs.push({ instack: r.byte(), idx: r.byte(), kind: r.byte() });
    f.nups = nu;
    const np = r.varint();
    if (np > 100_000) throw new BytecodeError('implausible function count');
    f.protos = [];
    for (let i = 0; i < np; i++) f.protos.push(readFunction(f.source, depth + 1));
    // debug information: line deltas, absolute anchors, local names, upvalue names
    const nl = r.varint();
    r.need(nl);
    const deltas = new Array(nl);
    for (let i = 0; i < nl; i++) { const b = r.byte(); deltas[i] = b > 127 ? b - 256 : b; }
    const na = r.varint();
    const abs = new Map();
    for (let i = 0; i < na; i++) { const pc = r.varint(); abs.set(pc, r.varint()); }
    f.lines = new Array(nl);
    let line = f.line;
    for (let pc = 0; pc < nl; pc++) { line = deltas[pc] === -128 ? abs.get(pc) : line + deltas[pc]; f.lines[pc] = line; }
    const nv = r.varint();
    f.locals = [];
    for (let i = 0; i < nv; i++) f.locals.push({ name: r.string54(), start: r.varint(), end: r.varint() });
    const nun = r.varint();
    f.upNames = [];
    for (let i = 0; i < nun; i++) f.upNames.push(r.string54());
    return f;
  };
  const main = readFunction(null, 0);
  return { version: 0x54, header: { mainUpvalues: mainUps }, main, bytes: r.p };
}

const MODE54 = (() => {
  const m = new Array(OPS54.length).fill('ABC');
  for (const n of ['LOADI', 'LOADF']) m[O[n]] = 'AsBx';
  for (const n of ['LOADK', 'CLOSURE', 'FORLOOP', 'FORPREP', 'TFORPREP', 'TFORLOOP']) m[O[n]] = 'ABx';
  m[O.LOADKX] = 'A'; m[O.JMP] = 'sJ'; m[O.EXTRAARG] = 'Ax';
  return m;
})();

export function decodeInstruction54(word) {
  return {
    op: word & 127, A: (word >>> 7) & 255, k: (word >>> 15) & 1, B: (word >>> 16) & 255, C: (word >>> 24) & 255,
    Bx: word >>> 15, sBx: (word >>> 15) - 65535, Ax: word >>> 7, sJ: (word >>> 7) - 16777215, sB: ((word >>> 16) & 255) - 127, sC: ((word >>> 24) & 255) - 127,
  };
}

export function disassemble54(chunk) {
  const out = [];
  const walk = (f, name, depth) => {
    out.push(`${'  '.repeat(depth)}function <${name}> (${f.code.length} instructions, ${f.numParams} params${f.isVararg ? ', vararg' : ''}, ${f.maxStack} slots, ${f.nups} upvalues, ${f.k.length} constants, ${f.protos.length} functions)`);
    const pad = '  '.repeat(depth + 1);
    for (let pc = 0; pc < f.code.length; pc++) {
      const d = decodeInstruction54(f.code[pc]);
      const nm = OPS54[d.op] || `OP${d.op}`;
      const mode = MODE54[d.op] || 'ABC';
      let args;
      if (mode === 'AsBx') args = `${d.A} ${d.sBx}`;
      else if (mode === 'ABx') args = `${d.A} ${d.Bx}`;
      else if (mode === 'sJ') args = `${d.sJ}  ; to ${pc + 2 + d.sJ}`;
      else if (mode === 'Ax') args = `${d.Ax}`;
      else if (mode === 'A') args = `${d.A}`;
      else args = `${d.A} ${d.B} ${d.C}${d.k ? ' k' : ''}`;
      let note = '';
      if (['LOADK', 'GETFIELD', 'GETTABUP', 'SETFIELD', 'SETTABUP', 'ADDK', 'SUBK', 'MULK', 'DIVK', 'EQK'].includes(nm)) {
        const idx = nm === 'LOADK' ? d.Bx : (nm === 'GETFIELD' || nm === 'GETTABUP') ? d.C : (nm === 'SETFIELD' || nm === 'SETTABUP') ? d.B : nm === 'EQK' ? d.B : d.C;
        note = `; ${kText(f.k[idx])}`;
      }
      const line = f.lines[pc] !== undefined ? `[${f.lines[pc]}]` : '';
      out.push(`${pad}${String(pc + 1).padStart(4)} ${line.padEnd(7)}${nm.padEnd(11)}${args.padEnd(18)}${note}`);
    }
    f.protos.forEach((p, i) => walk(p, `${name}/${i}`, depth + 1));
  };
  walk(chunk.main, 'main', 0);
  return out.join('\n');
}

// ---- 5.4 executor ---------------------------------------------------------------------------------------------------------------

const toInt64 = (m, x, what) => {
  const n = toNumber(x);
  if (n === undefined || typeof x === 'boolean') throw m.error(`attempt to perform bitwise operation on a ${typeName(x)} value`);
  if (!Number.isFinite(n) || Math.floor(n) !== n) throw m.error('number has no integer representation');
  void what;
  return BigInt.asIntN(64, BigInt(n));
};
const bitop = (m, op, a, b) => {
  const x = toInt64(m, a);
  const y = toInt64(m, b);
  switch (op) {
    case '&': return Number(BigInt.asIntN(64, x & y));
    case '|': return Number(BigInt.asIntN(64, x | y));
    case '~': return Number(BigInt.asIntN(64, x ^ y));
    default: throw new LuaError(`bad bitwise operator ${op}`);
  }
};
/** Lua's logical shift: positive n shifts left, negative n shifts right, both on 64 bits. */
const shiftl = (m, a, n) => {
  const x = BigInt.asUintN(64, toInt64(m, a));
  const k = toInt64(m, n);
  if (k <= -64n || k >= 64n) return 0;
  return Number(BigInt.asIntN(64, k >= 0n ? x << k : x >> -k));
};

function execute54(m, f, fn, args) {
  m.tick();
  if (++m.depth > m.maxDepth) { m.depth--; throw m.error('stack overflow'); }
  const code = f.code;
  const K = f.k;
  const R = new Array(f.maxStack + 2);
  const upvals = fn.upvals;
  const env = fn.env;
  const np = f.numParams;
  for (let i = 0; i < np; i++) R[i] = args[i];
  const va = f.isVararg && args.length > np ? args.slice(np) : [];
  let open = null;
  let top = 0;
  let pc = 0;
  const closeFrom = (a) => {
    if (!open) return;
    for (const [i, cell] of open) if (i >= a) { cell.close(); open.delete(i); }
  };
  const kbool = (w) => ((w >>> 15) & 1) !== 0;
  try {
    for (;;) {
      if (pc >= code.length) return [];
      const w = code[pc++];
      const op = w & 127;
      const A = (w >>> 7) & 255;
      const B = (w >>> 16) & 255;
      const C = (w >>> 24) & 255;
      m.tick();
      if (f.lines.length) m.line = f.lines[pc - 1] || m.line;
      switch (op) {
        case O.MOVE: R[A] = R[B]; break;
        case O.LOADI: R[A] = (w >>> 15) - 65535; break;
        case O.LOADF: R[A] = (w >>> 15) - 65535; break;
        case O.LOADK: R[A] = K[w >>> 15]; break;
        case O.LOADKX: R[A] = K[code[pc++] >>> 7]; break;
        case O.LOADFALSE: R[A] = false; break;
        case O.LFALSESKIP: R[A] = false; pc++; break;
        case O.LOADTRUE: R[A] = true; break;
        case O.LOADNIL: for (let i = 0; i <= B; i++) R[A + i] = undefined; break;
        case O.GETUPVAL: R[A] = upvals[B].get(); break;
        case O.SETUPVAL: upvals[B].set(R[A]); break;
        case O.GETTABUP: { const t = upvals[B].get(); const key = K[C]; const v = t instanceof LuaTable ? t.getStr(key) : undefined; R[A] = v !== undefined || (t instanceof LuaTable && t.meta === null) ? v : index(m, t, key); break; }
        case O.GETTABLE: R[A] = index(m, R[B], R[C]); break;
        case O.GETI: R[A] = index(m, R[B], C); break;
        case O.GETFIELD: R[A] = index(m, R[B], K[C]); break;
        case O.SETTABUP: setIndex(m, upvals[A].get(), K[B], kbool(w) ? K[C] : R[C]); break;
        case O.SETTABLE: setIndex(m, R[A], R[B], kbool(w) ? K[C] : R[C]); break;
        case O.SETI: setIndex(m, R[A], B, kbool(w) ? K[C] : R[C]); break;
        case O.SETFIELD: setIndex(m, R[A], K[B], kbool(w) ? K[C] : R[C]); break;
        case O.NEWTABLE: R[A] = new LuaTable(); pc++; break;
        case O.SELF: { const obj = R[B]; R[A + 1] = obj; R[A] = index(m, obj, kbool(w) ? K[C] : R[C]); break; }
        case O.ADDI: R[A] = arith(m, '+', R[B], C - 127); pc++; break;
        case O.ADDK: R[A] = arith(m, '+', R[B], K[C]); pc++; break;
        case O.SUBK: R[A] = arith(m, '-', R[B], K[C]); pc++; break;
        case O.MULK: R[A] = arith(m, '*', R[B], K[C]); pc++; break;
        case O.MODK: R[A] = arith(m, '%', R[B], K[C]); pc++; break;
        case O.POWK: R[A] = arith(m, '^', R[B], K[C]); pc++; break;
        case O.DIVK: R[A] = arith(m, '/', R[B], K[C]); pc++; break;
        case O.IDIVK: R[A] = arith(m, '//', R[B], K[C]); pc++; break;
        case O.BANDK: R[A] = bitop(m, '&', R[B], K[C]); pc++; break;
        case O.BORK: R[A] = bitop(m, '|', R[B], K[C]); pc++; break;
        case O.BXORK: R[A] = bitop(m, '~', R[B], K[C]); pc++; break;
        case O.SHRI: R[A] = shiftl(m, R[B], -(C - 127)); pc++; break;
        case O.SHLI: R[A] = shiftl(m, C - 127, R[B]); pc++; break;
        case O.ADD: R[A] = arith(m, '+', R[B], R[C]); pc++; break;
        case O.SUB: R[A] = arith(m, '-', R[B], R[C]); pc++; break;
        case O.MUL: R[A] = arith(m, '*', R[B], R[C]); pc++; break;
        case O.MOD: R[A] = arith(m, '%', R[B], R[C]); pc++; break;
        case O.POW: R[A] = arith(m, '^', R[B], R[C]); pc++; break;
        case O.DIV: R[A] = arith(m, '/', R[B], R[C]); pc++; break;
        case O.IDIV: R[A] = arith(m, '//', R[B], R[C]); pc++; break;
        case O.BAND: R[A] = bitop(m, '&', R[B], R[C]); pc++; break;
        case O.BOR: R[A] = bitop(m, '|', R[B], R[C]); pc++; break;
        case O.BXOR: R[A] = bitop(m, '~', R[B], R[C]); pc++; break;
        case O.SHL: R[A] = shiftl(m, R[B], R[C]); pc++; break;
        case O.SHR: R[A] = shiftl(m, R[B], -toNumber(R[C])); pc++; break;
        case O.MMBIN: case O.MMBINI: case O.MMBINK: break; // metamethod fallbacks are folded into the arithmetic helpers
        case O.UNM: R[A] = negate(m, R[B]); break;
        case O.BNOT: R[A] = Number(BigInt.asIntN(64, ~toInt64(m, R[B]))); break;
        case O.NOT: R[A] = !truthy(R[B]); break;
        case O.LEN: R[A] = length(m, R[B]); break;
        case O.CONCAT: {
          let acc = R[A + B - 1];
          for (let i = A + B - 2; i >= A; i--) acc = concat(m, R[i], acc);
          R[A] = acc;
          break;
        }
        case O.CLOSE: closeFrom(A); break;
        case O.TBC: break;
        case O.JMP: pc += (w >>> 7) - 16777215; break;
        case O.EQ: if (equals(m, R[A], R[B]) !== kbool(w)) pc++; break;
        case O.LT: if (lessThan(m, R[A], R[B]) !== kbool(w)) pc++; break;
        case O.LE: if (lessEqual(m, R[A], R[B]) !== kbool(w)) pc++; break;
        case O.EQK: if (equals(m, R[A], K[B]) !== kbool(w)) pc++; break;
        case O.EQI: if (equals(m, R[A], B - 127) !== kbool(w)) pc++; break;
        case O.LTI: if (lessThan(m, R[A], B - 127) !== kbool(w)) pc++; break;
        case O.LEI: if (lessEqual(m, R[A], B - 127) !== kbool(w)) pc++; break;
        case O.GTI: if (lessThan(m, B - 127, R[A]) !== kbool(w)) pc++; break;
        case O.GEI: if (lessEqual(m, B - 127, R[A]) !== kbool(w)) pc++; break;
        case O.TEST: if (truthy(R[A]) !== kbool(w)) pc++; break;
        case O.TESTSET: { const v = R[B]; if (!truthy(v) === kbool(w)) pc++; else R[A] = v; break; }
        case O.CALL:
        case O.TAILCALL: {
          const n = B !== 0 ? B - 1 : top - A - 1;
          const callArgs = new Array(n);
          for (let i = 0; i < n; i++) callArgs[i] = R[A + 1 + i];
          const res = callValue(m, R[A], callArgs, '');
          if (op === O.TAILCALL) { closeFrom(0); return res; }
          if (C === 0) { for (let i = 0; i < res.length; i++) R[A + i] = res[i]; top = A + res.length; }
          else for (let i = 0; i < C - 1; i++) R[A + i] = res[i];
          break;
        }
        case O.RETURN: {
          const n = B !== 0 ? B - 1 : top - A;
          const out = new Array(n);
          for (let i = 0; i < n; i++) out[i] = R[A + i];
          closeFrom(0);
          return out;
        }
        case O.RETURN0: closeFrom(0); return [];
        case O.RETURN1: closeFrom(0); return [R[A]];
        case O.FORLOOP: {
          const step = R[A + 2];
          const idx = R[A] + step;
          const limit = R[A + 1];
          if (step > 0 ? idx <= limit : limit <= idx) { R[A] = idx; R[A + 3] = idx; pc -= (w >>> 15); }
          break;
        }
        case O.FORPREP: {
          const init = toNumber(R[A]);
          const limit = toNumber(R[A + 1]);
          const step = toNumber(R[A + 2]);
          if (typeof R[A] === 'string' || init === undefined) throw m.error("'for' initial value must be a number");
          if (typeof R[A + 1] === 'string' || limit === undefined) throw m.error("'for' limit must be a number");
          if (typeof R[A + 2] === 'string' || step === undefined) throw m.error("'for' step must be a number");
          if (step === 0) throw m.error("'for' step is zero");
          R[A] = init; R[A + 1] = limit; R[A + 2] = step;
          if (step > 0 ? limit < init : init < limit) pc += (w >>> 15) + 1;
          else R[A + 3] = init;
          break;
        }
        case O.TFORPREP: pc += (w >>> 15); break;
        case O.TFORCALL: {
          const res = callValue(m, R[A], [R[A + 1], R[A + 2]], '');
          for (let i = 0; i < C; i++) R[A + 4 + i] = res[i];
          break;
        }
        case O.TFORLOOP: if (R[A + 4] !== undefined) { R[A + 2] = R[A + 4]; pc -= (w >>> 15); } break;
        case O.SETLIST: {
          const n = B !== 0 ? B : top - A - 1;
          let base = C;
          if (kbool(w)) base += (code[pc++] >>> 7) * 256;
          const t = R[A];
          for (let i = 1; i <= n; i++) t.listSet(base + i, R[A + i]);
          break;
        }
        case O.CLOSURE: {
          const child = f.protos[w >>> 15];
          const cells = new Array(child.nups);
          for (let i = 0; i < child.nups; i++) {
            const d = child.upDescs[i];
            if (d.instack) {
              if (!open) open = new Map();
              let cell = open.get(d.idx);
              if (!cell) { cell = new UpCell(R, d.idx); open.set(d.idx, cell); }
              cells[i] = cell;
            } else cells[i] = upvals[d.idx];
          }
          R[A] = new LuaFunction(runtimeProto(child), cells, env);
          break;
        }
        case O.VARARG: {
          if (C === 0) { for (let i = 0; i < va.length; i++) R[A + i] = va[i]; top = A + va.length; }
          else for (let i = 0; i < C - 1; i++) R[A + i] = va[i];
          break;
        }
        case O.VARARGPREP: break;
        case O.EXTRAARG: break;
        default: throw new LuaError(`bad bytecode: unknown opcode ${op}`);
      }
    }
  } finally {
    closeFrom(0);
    m.depth--;
  }
}

void typeName;
