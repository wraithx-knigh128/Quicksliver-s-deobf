// Conditions whose outcome does not depend on the program: opaque predicates.
//
// An obfuscator that wants a branch the analyst cannot discard writes a condition that is always true (or false) for a reason arithmetic
// knows: `x * x >= 0`, `(n * n + n) % 2 == 0`, `(7 * k + 1) % 7 == 1`, `a == a`. Each reason is proven here, not guessed:
//
//   * constant   every name in the condition is a constant, so the condition is evaluated;
//   * identity   both sides of a comparison are the same expression over finite numbers (no NaN to make `x ~= x` true);
//   * interval   the possible values of each side, from the ranges of the variables, are on one side of each other;
//   * modular    both sides are sums and products of whole numbers reduced by `% m`: such a value depends only on the variables mod m,
//                so the condition is checked for every residue, which settles it for every whole number.
//
// "Whole number" and "finite number" come from the variables: a local that is only ever written with whole-number expressions (literals,
// sums and products of such, `#t`, loop counters over whole-number bounds) cannot hold anything else. A parameter or a value that comes
// out of a call is unknown, and a condition that needs it to be a number is left alone.

import { walk, structuralKey } from '../core/walk.js';
import { evaluate, NOT_CONST } from './concrete.js';
import { strip } from './util.js';

const RING = new Set(['+', '-', '*']);
const MAX_CASES = 300000;

// ---- which locals hold whole / finite numbers --------------------------------------------------------------------------------

/** Vars whose every write is a whole number (`ints`) or a finite number (`fin`); the second set contains the first. */
export function numberVars(chunk, info) {
  const writes = new Map();
  const note = (id, e) => {
    const v = info.varOf.get(id);
    if (!v || v.isGlobal) return;
    const cur = writes.get(v);
    if (cur === null) return;
    if (e === null) { writes.set(v, null); return; }
    if (cur) cur.push(e); else writes.set(v, [e]);
  };
  const spreads = (values) => { const l = values[values.length - 1]; return !!l && (l.type === 'Call' || l.type === 'MethodCall' || l.type === 'Vararg'); };
  walk(chunk, (n) => {
    switch (n.type) {
      case 'Local': { const many = spreads(n.values); n.ids.forEach((id, i) => note(id, i < n.values.length && !(many && i >= n.values.length - 1) ? n.values[i] : { type: 'Nil' })); break; }
      case 'Assign': { const many = spreads(n.values); n.targets.forEach((t, i) => { if (t.type === 'Name') note(t, i < n.values.length && !(many && i >= n.values.length - 1) ? n.values[i] : null); }); break; }
      case 'CompoundAssign': if (n.target.type === 'Name') note(n.target, { type: 'Binary', op: n.op, left: n.target, right: n.value }); break;
      case 'NumFor': { const v = info.varOf.get(n.id); if (v) writes.set(v, [{ type: 'ForIndex', start: n.start, step: n.step }]); break; }
      case 'GenFor': n.ids.forEach((id) => note(id, null)); break;
      case 'LocalFunction': note(n.id, null); break;
      case 'Function': if (n.target.type === 'Name') note(n.target, null); break;
      case 'Func': n.params.forEach((p) => note(p, null)); break;
      default: break;
    }
  });
  const fin = new Set();
  const ints = new Set();
  for (const [v, list] of writes) if (list && !v.isGlobal) { fin.add(v); ints.add(v); }
  const isFin = (e) => {
    e = strip(e);
    switch (e.type) {
      case 'Number': return Number.isFinite(e.value);
      case 'Name': { const v = info.varOf.get(e); return !!v && fin.has(v); }
      case 'Unary': return (e.op === '-' && isFin(e.arg)) || e.op === '#';
      case 'Binary':
        if (RING.has(e.op)) return isFin(e.left) && isFin(e.right);
        if (e.op === '%') return isFin(e.left) && strip(e.right).type === 'Number' && strip(e.right).value !== 0 && Number.isFinite(strip(e.right).value);
        return false;
      case 'ForIndex': return isFin(e.start) && (!e.step || isFin(e.step));
      default: return false;
    }
  };
  const isInt = (e) => {
    e = strip(e);
    switch (e.type) {
      case 'Number': return Number.isInteger(e.value);
      case 'Name': { const v = info.varOf.get(e); return !!v && ints.has(v); }
      case 'Unary': return (e.op === '-' && isInt(e.arg)) || e.op === '#';
      case 'Binary':
        if (RING.has(e.op)) return isInt(e.left) && isInt(e.right);
        if (e.op === '%') return isInt(e.left) && strip(e.right).type === 'Number' && Number.isInteger(strip(e.right).value) && strip(e.right).value !== 0;
        return false;
      case 'ForIndex': return isInt(e.start) && (!e.step || isInt(e.step));
      default: return false;
    }
  };
  for (let again = true; again;) {
    again = false;
    for (const v of [...fin]) if (!writes.get(v).every(isFin)) { fin.delete(v); ints.delete(v); again = true; }
    for (const v of [...ints]) if (!writes.get(v).every(isInt)) { ints.delete(v); again = true; }
  }
  return { fin, ints, isInt };
}

// ---- intervals --------------------------------------------------------------------------------------------------------------

const TOP = [-Infinity, Infinity];

function interval(e, oc) {
  e = strip(e);
  switch (e.type) {
    case 'Number': return [e.value, e.value];
    case 'Name': return oc.range(e);
    case 'Unary': {
      if (e.op === '-') { const a = interval(e.arg, oc); return a && [-a[1], -a[0]]; }
      if (e.op === '#') return [0, Infinity];
      return null;
    }
    case 'Binary': {
      if (e.op === '*' && structuralKey(strip(e.left)) === structuralKey(strip(e.right))) {
        const a = interval(e.left, oc);
        if (!a) return null;
        const hi = Math.max(a[0] * a[0], a[1] * a[1]);
        return [a[0] <= 0 && a[1] >= 0 ? 0 : Math.min(a[0] * a[0], a[1] * a[1]), hi];
      }
      const a = interval(e.left, oc);
      const b = interval(e.right, oc);
      if (!a || !b) return null;
      if (e.op === '+') return [a[0] + b[0], a[1] + b[1]];
      if (e.op === '-') return [a[0] - b[1], a[1] - b[0]];
      if (e.op === '*') {
        const p = [a[0] * b[0], a[0] * b[1], a[1] * b[0], a[1] * b[1]].map((x) => (Number.isNaN(x) ? 0 : x));
        return [Math.min(...p), Math.max(...p)];
      }
      if (e.op === '%' && strip(e.right).type === 'Number' && strip(e.right).value > 0 && oc.isInt(e.left)) {
        const m = strip(e.right).value;
        return a[0] >= 0 && a[1] < m ? a : [0, m - 1];
      }
      return null;
    }
    default: return null;
  }
}

function compareIntervals(op, a, b) {
  switch (op) {
    case '<': return a[1] < b[0] ? true : a[0] >= b[1] ? false : null;
    case '<=': return a[1] <= b[0] ? true : a[0] > b[1] ? false : null;
    case '>': return a[0] > b[1] ? true : a[1] <= b[0] ? false : null;
    case '>=': return a[0] >= b[1] ? true : a[1] < b[0] ? false : null;
    case '==': return a[1] < b[0] || a[0] > b[1] ? false : a[0] === a[1] && b[0] === b[1] && a[0] === b[0] ? true : null;
    case '~=': return a[1] < b[0] || a[0] > b[1] ? true : a[0] === a[1] && b[0] === b[1] && a[0] === b[0] ? false : null;
    default: return null;
  }
}

// ---- residues ---------------------------------------------------------------------------------------------------------------

/** Collect the moduli of the `%` operators; false when anything besides ring operations on whole numbers and `% constant` appears. */
function collectModuli(e, out) {
  e = strip(e);
  switch (e.type) {
    case 'Number': return Number.isInteger(e.value);
    case 'Name': return true;
    case 'Unary': return e.op === '-' && collectModuli(e.arg, out);
    case 'Binary':
      if (RING.has(e.op)) return collectModuli(e.left, out) && collectModuli(e.right, out);
      if (e.op === '%') {
        const m = strip(e.right);
        if (m.type !== 'Number' || !Number.isInteger(m.value) || m.value < 1 || m.value > 4096) return false;
        out.add(m.value);
        return collectModuli(e.left, out);
      }
      return false;
    default: return false;
  }
}

const gcd = (a, b) => (b ? gcd(b, a % b) : a);
const mod = (a, m) => ((a % m) + m) % m;

/** The value of the expression for variables given by their residues mod M (a multiple of every modulus in it). */
function atResidues(e, env, M) {
  e = strip(e);
  switch (e.type) {
    case 'Number': return mod(e.value, M);
    case 'Name': return env.get(e.name);
    case 'Unary': return mod(-atResidues(e.arg, env, M), M);
    case 'Binary': {
      if (e.op === '%') return mod(atResidues(e.left, env, M), strip(e.right).value);
      const a = atResidues(e.left, env, M);
      const b = atResidues(e.right, env, M);
      return mod(e.op === '+' ? a + b : e.op === '-' ? a - b : a * b, M);
    }
    default: return NaN;
  }
}

/** `L == R` / `L ~= R` where each side is a whole-number ring expression reduced by `% m` (or a constant): decided over all residues. */
function modular(c, info, ints) {
  if (c.op !== '==' && c.op !== '~=') return null;
  const sides = [strip(c.left), strip(c.right)];
  if (!sides.every((s) => s.type === 'Number' || (s.type === 'Binary' && s.op === '%'))) return null;
  if (sides.every((s) => s.type === 'Number')) return null;
  const ms = new Set();
  if (!sides.every((s) => collectModuli(s, ms))) return null;
  const names = new Map();
  let ok = true;
  for (const s of sides) {
    walk(s, (n) => {
      if (n.type !== 'Name') return;
      const v = info.varOf.get(n);
      if (!v || !ints.has(v)) ok = false; else names.set(n.name, v);
    });
  }
  if (!ok || !names.size) return null;
  let M = 1;
  for (const m of ms) { M = (M / gcd(M, m)) * m; if (M > 4096) return null; }
  if (M ** names.size > MAX_CASES) return null;
  const keys = [...names.keys()];
  const env = new Map(keys.map((k) => [k, 0]));
  const value = (s) => (s.type === 'Number' ? s.value : atResidues(s, env, M));
  let verdict = null;
  for (;;) {
    const holds = value(sides[0]) === value(sides[1]);
    if (verdict === null) verdict = holds; else if (verdict !== holds) return null;
    let k = 0;
    while (k < keys.length) {
      env.set(keys[k], env.get(keys[k]) + 1);
      if (env.get(keys[k]) < M) break;
      env.set(keys[k], 0);
      k++;
    }
    if (k === keys.length) break;
  }
  return c.op === '==' ? verdict : !verdict;
}

// ---- the decision -----------------------------------------------------------------------------------------------------------

/** Prepare what a decision needs. @param {object} analysis result of analysis.js analyse() */
export function opaqueContext(chunk, analysis) {
  const { fin, ints, isInt } = numberVars(chunk, analysis.info);
  const ranges = new Map();
  walk(chunk, (n) => {
    if (n.type !== 'NumFor') return;
    const v = analysis.info.varOf.get(n.id);
    const lo = strip(n.start);
    const hi = strip(n.stop);
    const step = n.step ? strip(n.step) : { type: 'Number', value: 1 };
    // the counter may also be assigned in the body; then its range is not the loop's
    if (v && lo.type === 'Number' && hi.type === 'Number' && step.type === 'Number' && step.value !== 0 && v.writes.length === 0) {
      ranges.set(v, step.value > 0 ? [lo.value, Math.max(lo.value, hi.value)] : [Math.min(lo.value, hi.value), lo.value]);
    }
  });
  const range = (nameNode) => {
    const v = analysis.info.varOf.get(nameNode);
    if (!v) return null;
    if (ranges.has(v)) return ranges.get(v);
    const c = analysis.constant(v);
    if (typeof c === 'number') return [c, c];
    return fin.has(v) ? TOP : null;
  };
  return { analysis, fin, ints, range, info: analysis.info, isInt: (e) => isInt(e) };
}

/**
 * Does the condition have the same truth value whatever the program does?
 * @returns {{value: boolean, why: string} | null}
 */
export function constantCondition(cond, oc) {
  const c = strip(cond);
  const { info, analysis } = oc;
  let allConst = true;
  const env = new Map();
  walk(c, (n) => {
    if (n.type === 'Name') {
      const v = info.varOf.get(n);
      const k = v ? analysis.constant(v) : NOT_CONST;
      if (k === NOT_CONST) allConst = false; else env.set(n.name, k);
    } else if (n.type === 'Call' || n.type === 'MethodCall' || n.type === 'Func' || n.type === 'Vararg') allConst = false;
    return allConst ? undefined : false;
  });
  if (allConst) {
    const v = evaluate(c, (nm) => (env.has(nm) ? env.get(nm) : NOT_CONST), { shadowed: analysis.shadowed });
    if (v !== NOT_CONST) return { value: v !== undefined && v !== false, why: 'constant', names: new Set(env.keys()) };
  }
  if (c.type === 'Unary' && c.op === 'not') {
    const r = constantCondition(c.arg, oc);
    return r && { value: !r.value, why: r.why };
  }
  if (c.type === 'Binary' && (c.op === 'and' || c.op === 'or')) {
    const a = constantCondition(c.left, oc);
    const b = constantCondition(c.right, oc);
    if (c.op === 'and') {
      if (a && !a.value) return a;
      if (b && !b.value && !hasEffects(c.left)) return b;
      if (a && b && a.value && b.value) return a;
    } else {
      if (a && a.value) return a;
      if (b && b.value && !hasEffects(c.left)) return b;
      if (a && b && !a.value && !b.value) return a;
    }
    return null;
  }
  if (c.type !== 'Binary' || !['==', '~=', '<', '<=', '>', '>='].includes(c.op)) return null;
  const l = strip(c.left);
  const r = strip(c.right);
  if (structuralKey(l) === structuralKey(r)) {
    let plain = true;
    let names = 0;
    walk(l, (n) => {
      if (n.type === 'Binary' && (n.op === '/' || n.op === '^' || n.op === '//')) plain = false;
      if (n.type === 'Call' || n.type === 'MethodCall' || n.type === 'Func') plain = false;
      if (n.type === 'Name') { names++; const v = info.varOf.get(n); if (!v || !oc.fin.has(v)) plain = false; }
    });
    if (plain && names > 0) return { value: c.op === '==' || c.op === '<=' || c.op === '>=', why: 'identity' };
  }
  const m = modular(c, info, oc.ints);
  if (m !== null) return { value: m, why: 'modular' };
  const a = interval(l, oc);
  const b = interval(r, oc);
  if (a && b) {
    const v = compareIntervals(c.op, a, b);
    if (v !== null) return { value: v, why: 'interval' };
  }
  return null;
}

/** The decided side of `a and b` / `a or b` may only stand for the whole when the other side has nothing to do. */
function hasEffects(e) {
  let hit = false;
  walk(e, (n) => { if (n.type === 'Call' || n.type === 'MethodCall') hit = true; return hit ? false : undefined; });
  return hit;
}
