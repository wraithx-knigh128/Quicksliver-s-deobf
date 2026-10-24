// Lift Lua 5.1 and Lua 5.4 bytecode to one small register IR.
//
// The two instruction sets differ in encoding, in how conditions skip the following jump, in how loops are
// built and in how globals are reached, but they compute the same things. The decompiler works on this IR
// only, so everything after this file is version independent.
//
// IR operands are registers `{r: n}` or constants `{k: value}` (nil is `{k: undefined}`). Every IR
// instruction records `pc`, the index of the bytecode instruction it came from, which is how debug
// information (local variable names and live ranges) is looked up. Jump targets are IR indices.
//
//   move d s | loadk d v | loadnil from to | getup d u | setup u val | getglobal d name | setglobal name val
//   index d obj key | setindex obj key val | newtable d | self d obj key | bin d op a b | un d op a
//   concat d from to | call base nargs nres tail | ret base n | closure d proto ups | vararg d n
//   setlist base n off | jmp t | cjmp kind a b sense t | testset d s sense t
//   forprep base t | forloop base t | tforprep base t | tforcall base nvars | tforloop base t | close from
//
// `cjmp` jumps to `t` when its predicate is true, otherwise falls through; `sense` says which truth value of
// the predicate makes the jump (the bytecode's A / k flag).

import { decodeInstruction, decodeInstruction54, OPS, OPS54 } from '../sandbox/bytecode.js';

export class LiftError extends Error {}

const R = (n) => ({ r: n });
const Kc = (v, float) => (float ? { k: v, float: true } : { k: v });

const O51 = Object.fromEntries(OPS.map((n, i) => [n, i]));
const O54 = Object.fromEntries(OPS54.map((n, i) => [n, i]));

/**
 * @param {object} f parsed function (sandbox/bytecode.js)
 * @param {{envUps?: boolean[]}} [opts] which upvalues of this function are _ENV (Lua 5.4)
 * @returns {{ir: object[], pcToIr: Int32Array, version: number}}
 */
export function lift(f, opts = {}) {
  return f.version === 0x54 ? lift54(f, opts) : lift51(f);
}

// ---------------------------------------------------------------------------------------------------------------------
// Lua 5.1
// ---------------------------------------------------------------------------------------------------------------------

function lift51(f) {
  const code = f.code;
  const n = code.length;
  const ir = [];
  const pcToIr = new Int32Array(n + 1).fill(-1);
  const rk = (x) => (x >= 256 ? Kc(f.k[x - 256]) : R(x));
  const jumpsFrom = []; // [irIndex, pcTarget] fixed up once every pc has an IR index

  for (let pc = 0; pc < n; pc++) {
    pcToIr[pc] = ir.length;
    const d = decodeInstruction(code[pc]);
    const { A, B, C } = d;
    const push = (o) => { o.pc = pc; ir.push(o); return o; };
    switch (d.op) {
      case O51.MOVE: if (A !== B) push({ op: 'move', d: A, s: B }); break; // a move onto itself does nothing
      case O51.LOADK: push({ op: 'loadk', d: A, v: f.k[d.Bx] }); break;
      case O51.LOADBOOL: {
        push({ op: 'loadk', d: A, v: B !== 0 });
        if (C) { const j = push({ op: 'jmp', t: -1 }); jumpsFrom.push([j, pc + 2]); }
        break;
      }
      case O51.LOADNIL: push({ op: 'loadnil', from: A, to: B }); break;
      case O51.GETUPVAL: push({ op: 'getup', d: A, u: B }); break;
      case O51.GETGLOBAL: push({ op: 'getglobal', d: A, name: f.k[d.Bx] }); break;
      case O51.GETTABLE: push({ op: 'index', d: A, obj: R(B), key: rk(C) }); break;
      case O51.SETGLOBAL: push({ op: 'setglobal', name: f.k[d.Bx], val: R(A) }); break;
      case O51.SETUPVAL: push({ op: 'setup', u: B, val: R(A) }); break;
      case O51.SETTABLE: push({ op: 'setindex', obj: R(A), key: rk(B), val: rk(C) }); break;
      case O51.NEWTABLE: push({ op: 'newtable', d: A }); break;
      case O51.SELF: push({ op: 'self', d: A, obj: R(B), key: rk(C) }); break;
      case O51.ADD: case O51.SUB: case O51.MUL: case O51.DIV: case O51.MOD: case O51.POW: {
        const bop = { [O51.ADD]: '+', [O51.SUB]: '-', [O51.MUL]: '*', [O51.DIV]: '/', [O51.MOD]: '%', [O51.POW]: '^' }[d.op];
        push({ op: 'bin', d: A, bop, a: rk(B), b: rk(C) });
        break;
      }
      case O51.UNM: push({ op: 'un', d: A, uop: '-', a: R(B) }); break;
      case O51.NOT: push({ op: 'un', d: A, uop: 'not', a: R(B) }); break;
      case O51.LEN: push({ op: 'un', d: A, uop: '#', a: R(B) }); break;
      case O51.CONCAT: push({ op: 'concat', d: A, from: B, to: C }); break;
      case O51.JMP: { if (d.sBx === 0) break; /* a jump to the next instruction does nothing */ const j = push({ op: 'jmp', t: -1 }); jumpsFrom.push([j, pc + 1 + d.sBx]); break; }
      case O51.EQ: case O51.LT: case O51.LE: {
        const next = decodeInstruction(code[pc + 1]);
        if (next.op !== O51.JMP) throw new LiftError(`comparison at ${pc} is not followed by a jump`);
        const kind = d.op === O51.EQ ? 'eq' : d.op === O51.LT ? 'lt' : 'le';
        const j = push({ op: 'cjmp', kind, a: rk(B), b: rk(C), sense: A !== 0, t: -1 });
        jumpsFrom.push([j, pc + 2 + next.sBx]);
        pcToIr[pc + 1] = ir.length; // the fused jump has no instruction of its own
        pc++;
        break;
      }
      case O51.TEST: case O51.TESTSET: {
        const next = decodeInstruction(code[pc + 1]);
        if (next.op !== O51.JMP) throw new LiftError(`test at ${pc} is not followed by a jump`);
        const j = d.op === O51.TEST
          ? push({ op: 'cjmp', kind: 'test', a: R(A), b: null, sense: C !== 0, t: -1 })
          : push({ op: 'testset', d: A, s: B, sense: C !== 0, t: -1 });
        jumpsFrom.push([j, pc + 2 + next.sBx]);
        pcToIr[pc + 1] = ir.length;
        pc++;
        break;
      }
      case O51.CALL: push({ op: 'call', base: A, nargs: B === 0 ? -1 : B - 1, nres: C === 0 ? -1 : C - 1, tail: false }); break;
      case O51.TAILCALL: {
        push({ op: 'call', base: A, nargs: B === 0 ? -1 : B - 1, nres: -1, tail: true });
        break;
      }
      case O51.RETURN: push({ op: 'ret', base: A, n: B === 0 ? -1 : B - 1 }); break;
      case O51.FORLOOP: { const j = push({ op: 'forloop', base: A, t: -1 }); jumpsFrom.push([j, pc + 1 + d.sBx]); break; }
      case O51.FORPREP: { const j = push({ op: 'forprep', base: A, t: -1 }); jumpsFrom.push([j, pc + 1 + d.sBx]); break; }
      case O51.TFORLOOP: {
        const next = decodeInstruction(code[pc + 1]);
        if (next.op !== O51.JMP) throw new LiftError(`generic for at ${pc} is not followed by a jump`);
        push({ op: 'tforcall', base: A, nvars: C, varBase: A + 3 });
        const j = push({ op: 'tforloop', base: A, t: -1, varBase: A + 3 });
        jumpsFrom.push([j, pc + 2 + next.sBx]);
        pcToIr[pc + 1] = ir.length;
        pc++;
        break;
      }
      case O51.SETLIST: {
        let c = C;
        if (c === 0) { c = code[pc + 1]; pcToIr[pc + 1] = ir.length + 1; }
        push({ op: 'setlist', base: A, n: B === 0 ? -1 : B, off: (c - 1) * 50 });
        if (C === 0) pc++;
        break;
      }
      case O51.CLOSE: push({ op: 'close', from: A }); break;
      case O51.CLOSURE: {
        const child = f.protos[d.Bx];
        const ups = [];
        for (let i = 0; i < child.nups; i++) {
          const p = decodeInstruction(code[pc + 1 + i]);
          ups.push({ instack: p.op === O51.MOVE, idx: p.B });
          pcToIr[pc + 1 + i] = ir.length + 1;
        }
        push({ op: 'closure', d: A, proto: child, ups });
        pc += child.nups;
        break;
      }
      case O51.VARARG: push({ op: 'vararg', d: A, n: B === 0 ? -1 : B - 1 }); break;
      default: throw new LiftError(`unknown opcode ${d.op} at ${pc}`);
    }
  }
  pcToIr[n] = ir.length;
  // A generic `for` starts with a jump straight to its TFORLOOP; mark it so structuring can find the loop head.
  for (const [op, pcTarget] of jumpsFrom) {
    const t = pcToIr[pcTarget];
    if (t === undefined || t < 0 || t > ir.length) throw new LiftError(`jump at ${op.pc} leaves the function`);
    op.t = t;
  }
  for (const o of ir) {
    if (o.op === 'jmp' && ir[o.t] && ir[o.t].op === 'tforcall') { o.op = 'tforprep'; o.base = ir[o.t].base; }
  }
  return { ir, pcToIr, version: 0x51 };
}

// ---------------------------------------------------------------------------------------------------------------------
// Lua 5.4
// ---------------------------------------------------------------------------------------------------------------------

function lift54(f, opts) {
  const code = f.code;
  const n = code.length;
  const ir = [];
  const pcToIr = new Int32Array(n + 1).fill(-1);
  const jumpsFrom = [];
  const envUps = opts.envUps || [];
  const isEnv = (u) => envUps[u] === true;
  const kc = (idx) => Kc(f.k[idx], f.kFloat && f.kFloat[idx]);
  const RKC = (d) => (d.k ? kc(d.C) : R(d.C));
  const scratch = f.maxStack + 1;

  for (let pc = 0; pc < n; pc++) {
    pcToIr[pc] = ir.length;
    const d = decodeInstruction54(code[pc]);
    const { A, B, C } = d;
    const push = (o) => { o.pc = pc; ir.push(o); return o; };
    const jumpAfter = (cond) => {
      const next = decodeInstruction54(code[pc + 1]);
      if (next.op !== O54.JMP) throw new LiftError(`condition at ${pc} is not followed by a jump`);
      const j = push(cond);
      jumpsFrom.push([j, pc + 2 + next.sJ]);
      pcToIr[pc + 1] = ir.length;
      pc++;
    };
    switch (d.op) {
      case O54.MOVE: if (A !== B) push({ op: 'move', d: A, s: B }); break;
      case O54.LOADI: push({ op: 'loadk', d: A, v: d.sBx }); break;
      case O54.LOADF: push({ op: 'loadk', d: A, v: d.sBx, float: true }); break;
      case O54.LOADK: push({ op: 'loadk', d: A, v: f.k[d.Bx], float: !!(f.kFloat && f.kFloat[d.Bx]) }); break;
      case O54.LOADKX: push({ op: 'loadk', d: A, v: f.k[code[pc + 1] >>> 7] }); pcToIr[pc + 1] = ir.length; pc++; break;
      case O54.LOADFALSE: push({ op: 'loadk', d: A, v: false }); break;
      case O54.LFALSESKIP: { push({ op: 'loadk', d: A, v: false }); const j = push({ op: 'jmp', t: -1 }); jumpsFrom.push([j, pc + 2]); break; }
      case O54.LOADTRUE: push({ op: 'loadk', d: A, v: true }); break;
      case O54.LOADNIL: push({ op: 'loadnil', from: A, to: A + B }); break;
      case O54.GETUPVAL: push({ op: 'getup', d: A, u: B }); break;
      case O54.SETUPVAL: push({ op: 'setup', u: B, val: R(A) }); break;
      case O54.GETTABUP:
        if (isEnv(B)) push({ op: 'getglobal', d: A, name: f.k[C] });
        else { push({ op: 'getup', d: A, u: B, tmp: true }); push({ op: 'index', d: A, obj: R(A), key: kc(C) }); }
        break;
      case O54.GETTABLE: push({ op: 'index', d: A, obj: R(B), key: R(C) }); break;
      case O54.GETI: push({ op: 'index', d: A, obj: R(B), key: Kc(C) }); break;
      case O54.GETFIELD: push({ op: 'index', d: A, obj: R(B), key: Kc(f.k[C]) }); break;
      case O54.SETTABUP:
        if (isEnv(A)) push({ op: 'setglobal', name: f.k[B], val: RKC(d) });
        else { push({ op: 'getup', d: scratch, u: A }); push({ op: 'setindex', obj: R(scratch), key: kc(B), val: RKC(d) }); }
        break;
      case O54.SETTABLE: push({ op: 'setindex', obj: R(A), key: R(B), val: RKC(d) }); break;
      case O54.SETI: push({ op: 'setindex', obj: R(A), key: Kc(B), val: RKC(d) }); break;
      case O54.SETFIELD: push({ op: 'setindex', obj: R(A), key: Kc(f.k[B]), val: RKC(d) }); break;
      case O54.NEWTABLE: push({ op: 'newtable', d: A }); pcToIr[pc + 1] = ir.length; pc++; break;
      case O54.SELF: push({ op: 'self', d: A, obj: R(B), key: RKC(d) }); break;
      case O54.ADDI: push({ op: 'bin', d: A, bop: '+', a: R(B), b: Kc(C - 127) }); pc++; pcToIr[pc] = ir.length; break;
      case O54.ADDK: case O54.SUBK: case O54.MULK: case O54.MODK: case O54.POWK: case O54.DIVK: case O54.IDIVK:
      case O54.BANDK: case O54.BORK: case O54.BXORK: {
        const bop = { ADDK: '+', SUBK: '-', MULK: '*', MODK: '%', POWK: '^', DIVK: '/', IDIVK: '//', BANDK: '&', BORK: '|', BXORK: '~' }[OPS54[d.op]];
        push({ op: 'bin', d: A, bop, a: R(B), b: kc(C) });
        pc++; pcToIr[pc] = ir.length;
        break;
      }
      case O54.SHRI: push({ op: 'bin', d: A, bop: '>>', a: R(B), b: Kc(C - 127) }); pc++; pcToIr[pc] = ir.length; break;
      case O54.SHLI: push({ op: 'bin', d: A, bop: '<<', a: Kc(C - 127), b: R(B) }); pc++; pcToIr[pc] = ir.length; break;
      case O54.ADD: case O54.SUB: case O54.MUL: case O54.MOD: case O54.POW: case O54.DIV: case O54.IDIV:
      case O54.BAND: case O54.BOR: case O54.BXOR: case O54.SHL: case O54.SHR: {
        const bop = { ADD: '+', SUB: '-', MUL: '*', MOD: '%', POW: '^', DIV: '/', IDIV: '//', BAND: '&', BOR: '|', BXOR: '~', SHL: '<<', SHR: '>>' }[OPS54[d.op]];
        push({ op: 'bin', d: A, bop, a: R(B), b: R(C) });
        pc++; pcToIr[pc] = ir.length;
        break;
      }
      case O54.MMBIN: case O54.MMBINI: case O54.MMBINK: break;
      case O54.UNM: push({ op: 'un', d: A, uop: '-', a: R(B) }); break;
      case O54.BNOT: push({ op: 'un', d: A, uop: '~', a: R(B) }); break;
      case O54.NOT: push({ op: 'un', d: A, uop: 'not', a: R(B) }); break;
      case O54.LEN: push({ op: 'un', d: A, uop: '#', a: R(B) }); break;
      case O54.CONCAT: push({ op: 'concat', d: A, from: A, to: A + B - 1 }); break;
      case O54.CLOSE: push({ op: 'close', from: A }); break;
      case O54.TBC: break;
      case O54.JMP: { if (d.sJ === 0) break; const j = push({ op: 'jmp', t: -1 }); jumpsFrom.push([j, pc + 1 + d.sJ]); break; }
      case O54.EQ: jumpAfter({ op: 'cjmp', kind: 'eq', a: R(A), b: R(B), sense: d.k !== 0, t: -1 }); break;
      case O54.LT: jumpAfter({ op: 'cjmp', kind: 'lt', a: R(A), b: R(B), sense: d.k !== 0, t: -1 }); break;
      case O54.LE: jumpAfter({ op: 'cjmp', kind: 'le', a: R(A), b: R(B), sense: d.k !== 0, t: -1 }); break;
      case O54.EQK: jumpAfter({ op: 'cjmp', kind: 'eq', a: R(A), b: kc(B), sense: d.k !== 0, t: -1 }); break;
      case O54.EQI: jumpAfter({ op: 'cjmp', kind: 'eq', a: R(A), b: Kc(d.sB), sense: d.k !== 0, t: -1 }); break;
      case O54.LTI: jumpAfter({ op: 'cjmp', kind: 'lt', a: R(A), b: Kc(d.sB), sense: d.k !== 0, t: -1 }); break;
      case O54.LEI: jumpAfter({ op: 'cjmp', kind: 'le', a: R(A), b: Kc(d.sB), sense: d.k !== 0, t: -1 }); break;
      case O54.GTI: jumpAfter({ op: 'cjmp', kind: 'lt', a: Kc(d.sB), b: R(A), sense: d.k !== 0, t: -1 }); break;
      case O54.GEI: jumpAfter({ op: 'cjmp', kind: 'le', a: Kc(d.sB), b: R(A), sense: d.k !== 0, t: -1 }); break;
      case O54.TEST: jumpAfter({ op: 'cjmp', kind: 'test', a: R(A), b: null, sense: d.k !== 0, t: -1 }); break;
      case O54.TESTSET: jumpAfter({ op: 'testset', d: A, s: B, sense: d.k !== 0, t: -1 }); break;
      case O54.CALL: push({ op: 'call', base: A, nargs: B === 0 ? -1 : B - 1, nres: C === 0 ? -1 : C - 1, tail: false }); break;
      case O54.TAILCALL: push({ op: 'call', base: A, nargs: B === 0 ? -1 : B - 1, nres: -1, tail: true }); break;
      case O54.RETURN: push({ op: 'ret', base: A, n: B === 0 ? -1 : B - 1 }); break;
      case O54.RETURN0: push({ op: 'ret', base: A, n: 0 }); break;
      case O54.RETURN1: push({ op: 'ret', base: A, n: 1 }); break;
      case O54.FORLOOP: { const j = push({ op: 'forloop', base: A, t: -1 }); jumpsFrom.push([j, pc + 1 - d.Bx]); break; }
      case O54.FORPREP: { const j = push({ op: 'forprep', base: A, t: -1 }); jumpsFrom.push([j, pc + 1 + d.Bx]); break; }
      case O54.TFORPREP: { const j = push({ op: 'tforprep', base: A, t: -1 }); jumpsFrom.push([j, pc + 1 + d.Bx]); break; }
      case O54.TFORCALL: push({ op: 'tforcall', base: A, nvars: C, varBase: A + 4 }); break;
      case O54.TFORLOOP: { const j = push({ op: 'tforloop', base: A, t: -1, varBase: A + 4 }); jumpsFrom.push([j, pc + 1 - d.Bx]); break; }
      case O54.SETLIST: {
        let off = C;
        if (d.k) { off += (code[pc + 1] >>> 7) * 256; pcToIr[pc + 1] = ir.length + 1; }
        push({ op: 'setlist', base: A, n: B === 0 ? -1 : B, off });
        if (d.k) pc++;
        break;
      }
      case O54.CLOSURE: {
        const child = f.protos[d.Bx];
        push({ op: 'closure', d: A, proto: child, ups: child.upDescs.map((u) => ({ instack: u.instack !== 0, idx: u.idx })) });
        break;
      }
      case O54.VARARG: push({ op: 'vararg', d: A, n: C === 0 ? -1 : C - 1 }); break;
      case O54.VARARGPREP: break;
      case O54.EXTRAARG: break;
      default: throw new LiftError(`unknown opcode ${d.op} at ${pc}`);
    }
  }
  pcToIr[n] = ir.length;
  for (const [op, pcTarget] of jumpsFrom) {
    const t = pcToIr[pcTarget];
    if (t === undefined || t < 0 || t > ir.length) throw new LiftError(`jump at ${op.pc} leaves the function`);
    op.t = t;
  }
  return { ir, pcToIr, version: 0x54 };
}

export { R as reg, Kc as konst };
