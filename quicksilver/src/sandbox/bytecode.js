// Lua 5.1 bytecode: reader, disassembler and an executor for the sandbox.
//
// Some obfuscators ship the program as a compiled chunk (`load("\27Lua...")`). Two things are useful with
// such a chunk: reading it (constants, functions, instructions) and, for behaviour analysis, running it
// under the same limits as any other sandboxed code. Both are done here for the PUC-Rio Lua 5.1 format
// (little or big endian, 4 or 8 byte size_t). Luau and LuaJIT bytecode are different formats and are
// reported as unsupported rather than guessed at.

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
  if (version !== 0x51) throw new BytecodeError(`unsupported bytecode version 0x${version.toString(16)} (only Lua 5.1 chunks can be read)`);
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
  return { header, main, bytes: r.p };
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
  const rt = {
    name: parsed.source || '?',
    line: parsed.line,
    nparams: parsed.numParams,
    hasVararg: !!parsed.isVararg,
    call(m, fn, args) { return execute(m, parsed, fn, args); },
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
  return new LuaFunction(runtimeProto(chunk.main), [], env || m.globals);
}

void typeName;
