// Linear mixed boolean-arithmetic (MBA) simplification for bit32 code.
//
// An MBA hides a simple operation behind an identity that mixes arithmetic and bitwise operators, e.g. `x ~ y` written as
// `(x + y) - 2 * (x & y)`. Linear MBAs (sums of constant multiples of bitwise functions of the variables) are fully determined by their values
// on the 2^t inputs where every variable is 0 or 1. That is the observation behind SiMBA (Reichenwallner & Meerwald-Stadler, "Efficient
// Deobfuscation of Linear Mixed Boolean-Arithmetic Expressions", CheckMATE @ CCS 2022): evaluate the expression on those inputs, read off its
// coefficients in the basis of conjunctions, and pick the simplest equivalent expression.
//
// Scope and soundness:
//   * only expressions that are an argument of a bit32 call are rewritten. bit32 reduces its operands mod 2^32, and linear MBA identities
//     hold mod 2^32 for integer inputs, so the rewrite cannot change what the call returns for integer variables;
//   * only expressions built from variables (≤ 3 distinct names), integer literals, + - * (with a constant factor), unary minus and
//     bit32.band/bor/bxor/bnot are considered; anything else (calls, fields, shifts, division) leaves the expression alone;
//   * a candidate is accepted only if it agrees with the original mod 2^32 on every 0/1 input AND on 96 further inputs (random 32-bit values,
//     negatives and edge values). A non-linear expression that is not equal to its candidate is therefore left as it is. The random check is
//     a guard, not a proof; for expressions inside the linear class the reconstruction is exact.
//   * nothing is executed: the evaluator is a small exact (BigInt) interpreter for the operators above.

import { transform } from '../core/walk.js';

const M = 1n << 32n;
const MASK = M - 1n;
const norm = (v) => ((v % M) + M) % M;
const BIT32 = new Set(['band', 'bor', 'bxor', 'bnot']);
const unparen = (e) => (e && e.type === 'Paren' ? unparen(e.expr) : e);

function bitFn(e) {
  const x = unparen(e);
  if (!x || x.type !== 'Call' || !x.fn || x.fn.type !== 'Index') return null;
  const o = unparen(x.fn.obj);
  if (!o || o.type !== 'Name' || o.name !== 'bit32' || !x.fn.key || x.fn.key.type !== 'String') return null;
  return x.fn.key.value;
}

/** Is `e` inside the supported fragment? Collects variable names and counts nodes / operator kinds. */
function shape(e, info) {
  const x = unparen(e);
  if (!x) return false;
  info.size++;
  switch (x.type) {
    case 'Number': return Number.isInteger(x.value) && Math.abs(x.value) <= Number.MAX_SAFE_INTEGER;
    case 'Name': if (x.name === 'bit32') return false; info.vars.add(x.name); return true;
    case 'Unary': if (x.op !== '-') return false; info.arith++; return shape(x.arg, info);
    case 'Binary':
      if (x.op === '+' || x.op === '-') { info.arith++; return shape(x.left, info) && shape(x.right, info); }
      if (x.op === '*') {
        info.arith++;
        const l = { vars: new Set(), size: 0, arith: 0, bit: 0 };
        const r = { vars: new Set(), size: 0, arith: 0, bit: 0 };
        if (!shape(x.left, l) || !shape(x.right, r)) return false;
        if (l.vars.size && r.vars.size) return false;        // a product of two variable terms is not linear
        for (const v of [...l.vars, ...r.vars]) info.vars.add(v);
        info.size += l.size + r.size; info.arith += l.arith + r.arith; info.bit += l.bit + r.bit;
        return true;
      }
      return false;
    case 'Call': {
      const f = bitFn(x);
      if (!f || !BIT32.has(f) || !x.args.length || (f === 'bnot' && x.args.length !== 1)) return false;
      info.bit++;
      return x.args.every((a) => shape(a, info));
    }
    default: return false;
  }
}

/** Exact value of `e` (BigInt) for variable values `env` (Map name -> BigInt). */
function evaluate(e, env) {
  const x = unparen(e);
  switch (x.type) {
    case 'Number': return BigInt(x.value);
    case 'Name': return env.get(x.name);
    case 'Unary': return -evaluate(x.arg, env);
    case 'Binary': {
      const a = evaluate(x.left, env); const b = evaluate(x.right, env);
      return x.op === '+' ? a + b : x.op === '-' ? a - b : a * b;
    }
    case 'Call': {
      const f = bitFn(x);
      const args = x.args.map((a) => norm(evaluate(a, env)));
      if (f === 'bnot') return MASK - args[0];
      if (f === 'band') return args.reduce((p, q) => p & q, MASK);
      if (f === 'bor') return args.reduce((p, q) => p | q, 0n);
      return args.reduce((p, q) => p ^ q, 0n);
    }
    default: throw new Error(`mba: unexpected ${x.type}`);
  }
}

// ---- building replacement expressions ----------------------------------------------------------------------------------------------------
const num = (v) => {
  // print a mod-2^32 value as the smallest signed integer
  let n = norm(v);
  if (n > M / 2n) n -= M;
  return n < 0n ? { type: 'Unary', op: '-', arg: { type: 'Number', value: Number(-n), raw: String(-n) } } : { type: 'Number', value: Number(n), raw: String(n) };
};
const name = (n) => ({ type: 'Name', name: n });
const call = (f, args) => ({ type: 'Call', fn: { type: 'Index', obj: name('bit32'), key: { type: 'String', value: f }, dot: true }, args });
const size = (e) => { const i = { vars: new Set(), size: 0, arith: 0, bit: 0 }; shape(e, i); return i.size; };

/** The candidate bitwise functions of the given variables, smallest first. */
function candidates(vars) {
  const atoms = vars.map(name);
  const lits = [...atoms, ...atoms.map((a) => call('bnot', [a]))];
  const out = [...lits];
  for (const f of ['band', 'bor', 'bxor']) {
    for (let i = 0; i < lits.length; i++) for (let j = i + 1; j < lits.length; j++) {
      if (lits[i].type === 'Call' && lits[j].type === 'Call') continue;
      out.push(call(f, [lits[i], lits[j]]));
    }
    if (vars.length === 3) out.push(call(f, atoms));
  }
  if (vars.length === 3) {
    for (const f of ['band', 'bor', 'bxor']) for (const g of ['band', 'bor', 'bxor']) for (let i = 0; i < 3; i++) {
      const rest = atoms.filter((_, k) => k !== i);
      out.push(call(f, [atoms[i], call(g, rest)]));
    }
  }
  return out.map((e) => ({ e, size: size(e) })).sort((a, b) => a.size - b.size);
}

function assignments(vars) {
  const out = [];
  for (let b = 0; b < 1 << vars.length; b++) out.push(new Map(vars.map((v, i) => [v, BigInt((b >> i) & 1)])));
  return out;
}

let seed = 0x9e3779b9;
const rnd = () => { seed ^= seed << 13; seed >>>= 0; seed ^= seed >>> 17; seed ^= seed << 5; seed >>>= 0; return seed; };
function randomInputs(vars, n = 96) {
  const edge = [0n, 1n, 2n, MASK, MASK - 1n, -1n, -7n, 1n << 31n, (1n << 31n) - 1n, 123456789n];
  const out = [];
  for (let i = 0; i < n; i++) out.push(new Map(vars.map((v, k) => [v, i < edge.length ? edge[(i + k) % edge.length] : BigInt(rnd()) - (i % 5 === 0 ? (1n << 31n) : 0n)])));
  return out;
}

const agrees = (a, b, inputs) => inputs.every((env) => norm(evaluate(a, env)) === norm(evaluate(b, env)));

/** k + a * f, written without the parts that are 0 or 1. */
function affine(k, a, f) {
  a = norm(a); k = norm(k);
  let term = a === 1n ? f : a === MASK ? { type: 'Unary', op: '-', arg: f } : { type: 'Binary', op: '*', left: num(a), right: f };
  if (k === 0n) return term;
  const kk = num(k);
  if (kk.type === 'Unary') return { type: 'Binary', op: '-', left: term, right: kk.arg };
  return { type: 'Binary', op: '+', left: term, right: kk };
}

/**
 * The simplest expression equal to `expr` mod 2^32, or null if none is simpler or the expression is outside the linear class.
 * Exported for tests.
 */
export function simplifyLinearMBA(expr) {
  const info = { vars: new Set(), size: 0, arith: 0, bit: 0 };
  if (!shape(expr, info) || !info.bit || !info.arith || info.vars.size === 0 || info.vars.size > 3) return null;
  const vars = [...info.vars].sort();
  const corners = assignments(vars);
  const values = corners.map((env) => norm(evaluate(expr, env)));
  const tests = [...corners, ...randomInputs(vars)];
  const original = info.size;
  let best = null;
  const offer = (e) => {
    const s = size(e);
    if (s < original && (!best || s < best.size) && agrees(expr, e, tests)) best = { e, size: s };
  };
  // a constant
  if (values.every((v) => v === values[0])) offer(num(values[0]));
  // k + a * f for one candidate bitwise function f
  for (const { e: f, size: fs } of candidates(vars)) {
    if (best && fs + 1 >= best.size) break;
    const fv = corners.map((env) => norm(evaluate(f, env)));
    const i = fv.findIndex((v) => v !== fv[0]);
    if (i < 0) continue;
    const df = norm(fv[i] - fv[0]);
    if (df !== 1n && df !== MASK) continue;                    // every candidate moves by ±1 between 0/1 inputs
    const a = df === 1n ? norm(values[i] - values[0]) : norm(values[0] - values[i]);
    const k = norm(values[0] - a * fv[0]);
    if (corners.every((_, b) => norm(k + a * fv[b]) === values[b])) offer(affine(k, a, f));
  }
  // otherwise the conjunction basis: E(0) + Σ a_S · band(x_S)   (Möbius inversion of the 0/1 values)
  if (!best) {
    const t = vars.length;
    let sum = null;
    for (let S = 1; S < 1 << t; S++) {
      let a = 0n;
      for (let T = S; ; T = (T - 1) & S) {
        const sign = (popcount(S) - popcount(T)) % 2 ? -1n : 1n;
        a += sign * (values[T] - values[0]);
        if (T === 0) break;
      }
      a = norm(a);
      if (a === 0n) continue;
      const members = vars.filter((_, i) => S & (1 << i)).map(name);
      const conj = members.length === 1 ? members[0] : call('band', members);
      const term = affine(0n, a, conj);
      sum = sum ? { type: 'Binary', op: '+', left: sum, right: term } : term;
    }
    const k = values[0];
    const e = sum ? (k === 0n ? sum : { type: 'Binary', op: '+', left: sum, right: num(k) }) : num(k);
    offer(e);
  }
  return best ? best.e : null;
}

function popcount(n) { let c = 0; while (n) { c += n & 1; n >>= 1; } return c; }

/** Rewrite linear MBAs that are arguments of bit32 calls. Returns the number of rewrites. */
export function simplifyMBA(ast, { budget = 400 } = {}) {
  let changed = 0;
  let tried = 0;   // a VM full of bit32 arithmetic must not turn this into a long search: at most `budget` candidate expressions per run
  transform(ast, {
    expr(e) {
      if (e.type !== 'Call' || !bitFn(e)) return undefined;
      let touched = false;
      const args = e.args.map((a) => {
        if (tried >= budget) return a;
        const info = { vars: new Set(), size: 0, arith: 0, bit: 0 };
        if (!shape(a, info) || !info.bit || !info.arith || !info.vars.size || info.vars.size > 3) return a;
        tried++;
        const s = simplifyLinearMBA(a);
        if (!s) return a;
        touched = true; changed++;
        return s;
      });
      return touched ? { ...e, args } : undefined;
    },
  });
  return changed;
}
