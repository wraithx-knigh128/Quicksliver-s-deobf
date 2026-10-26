// An online partial evaluator for block graphs (the shape src/decompile/cfg.js takes).
//
// Given what is known at the entry (constants, tables of constants, and whatever the caller's model of the program knows about its own
// runtime), it walks the graph, carries the known values along, folds every expression and test it can, and writes out what it could
// not decide. A block is written once for every distinct set of known values it is entered with, so a loop whose trip count is known
// comes out unrolled and a dispatcher whose selector is known comes out as the one case that applies. Nothing in the graph is run: a value
// is only ever computed from literals, from tables the caller handed in and from the caller's own model, by operators whose result does
// not depend on anything else.
//
// A loop whose test is not known would unroll for ever; when a block has been written too many times, the names that loop assigns are
// forgotten on the way in and the whole graph is evaluated again, which keeps the loop as a loop.
//
// The model (optional) says what the caller knows about names and calls that are not plain data:
//   toExpr(val)                        residual expression for a known value that is not a literal, or null
//   index(obj, key, node, ctx)         result of obj[key] where obj or key is such a value, or null
//   call(fn, args, node, ctx)          result of calling a known function, or null; args end with the items of a multi-value last argument
//   store(obj, key, value, node, ctx)  true when the model has dealt with `obj[key] = value` itself
//   keyOf(val)                         a string that tells two such values apart
//   alive(name)                        names the model wants kept across blocks even when nothing reads them any more
// A result is { expr, val, multi?, skip? }: the residual expression, the known value (or UNKNOWN), a Multi when the expression stands for a
// run of values, and skip when a call needed no statement. ctx is { env, emit(stmt) }.
//
//   known values: number, string, boolean, null (nil), a Table (a table whose contents are known and never change while this runs),
//   or whatever objects the model makes up.

import { liveness } from './cfg-opt.js';
import { walk, structuralKey } from '../core/walk.js';

export class Table {
  constructor() { this.h = new Map(); }
  get(k) { return this.h.has(k) ? this.h.get(k) : null; }
  set(k, v) { if (v === null) this.h.delete(k); else this.h.set(k, v); }
}
/** A name that stands for an expression computed earlier (`t = r15` and later `t()`), so that what is written out does not depend on `t` staying put. */
class Alias { constructor(expr) { this.expr = expr; } }
const mentions = (expr, name) => { let hit = false; walk(expr, (n) => { if (n.type === 'Name' && n.name === name) hit = true; }); return hit; };
const pure = (e) => { let ok = true; walk(e, (n) => { if (n.type === 'Call' || n.type === 'MethodCall' || n.type === 'Func' || n.type === 'Vararg') ok = false; }); return ok; };
/** `name` is about to change: forget every alias that was computed from it. */
function invalidate(env, name) {
  for (const [k, v] of env) if (v instanceof Alias && mentions(v.expr, name)) env.delete(k);
}

/** A run of values: items are residual expressions; `open` when the last one is a call or `...` that may give any number. */
export class Multi { constructor(items, open = false) { this.items = items; this.open = open; } }

export const UNKNOWN = Symbol('unknown');
export const isScalar = (v) => v === null || typeof v === 'boolean' || typeof v === 'string' || (typeof v === 'number' && Number.isFinite(v) && !Object.is(v, -0));

const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const truthy = (v) => v !== null && v !== false;
export const lit = (v) => (v === null ? { type: 'Nil' } : v === true ? { type: 'True' } : v === false ? { type: 'False' } : typeof v === 'string' ? { type: 'String', value: v, raw: null } : v < 0 ? { type: 'Unary', op: '-', arg: { type: 'Number', value: -v, raw: null } } : { type: 'Number', value: v, raw: null });

function known(v, node, ...parts) {
  if (typeof v === 'number' && !Number.isFinite(v)) return { expr: rebuild(node, parts), val: UNKNOWN };
  return { expr: isScalar(v) ? lit(v) : node, val: v };
}
function rebuild(node, parts) {
  if (node.type === 'Unary') return { ...node, arg: parts[0].expr };
  return { ...node, left: parts[0].expr, right: parts[1].expr };
}
function fold(op, a, b) {
  const num = typeof a === 'number' && typeof b === 'number';
  const str = typeof a === 'string' && typeof b === 'string';
  switch (op) {
    case '+': return num ? a + b : UNKNOWN;
    case '-': return num ? a - b : UNKNOWN;
    case '*': return num ? a * b : UNKNOWN;
    case '/': return num ? a / b : UNKNOWN;
    case '%': return num && b !== 0 ? a - Math.floor(a / b) * b : UNKNOWN;
    case '^': return num ? a ** b : UNKNOWN;
    case '..': return (typeof a === 'string' || typeof a === 'number') && (typeof b === 'string' || typeof b === 'number') ? String(a) + String(b) : UNKNOWN;
    // a known object is never nil and never equal to a literal; two objects are equal when they are the same one
    case '==': return isScalar(a) && isScalar(b) ? a === b : isScalar(a) !== isScalar(b) ? false : a === b ? true : UNKNOWN;
    case '~=': return isScalar(a) && isScalar(b) ? a !== b : isScalar(a) !== isScalar(b) ? true : a === b ? false : UNKNOWN;
    case '<': return num || str ? a < b : UNKNOWN;
    case '<=': return num || str ? a <= b : UNKNOWN;
    case '>': return num || str ? a > b : UNKNOWN;
    case '>=': return num || str ? a >= b : UNKNOWN;
    default: return UNKNOWN;
  }
}

/** Evaluates `e` under ctx.env. Returns { expr, val, multi? }. */
// `4 + t - 1` is `t + 3`, and `3 + (zb - 3)` is `zb`: sums and differences are collected, their constants added, equal terms of opposite sign dropped.
function linear(e, sign, acc) {
  e = strip(e);
  if (e.type === 'Number') { acc.c += sign * e.value; acc.consts++; return; }
  if (e.type === 'Binary' && (e.op === '+' || e.op === '-')) { linear(e.left, sign, acc); linear(e.right, e.op === '+' ? sign : -sign, acc); return; }
  acc.terms.push({ sign, e });
}
function reassociate(node) {
  if (node.type !== 'Binary' || (node.op !== '+' && node.op !== '-')) return node;
  const acc = { terms: [], c: 0, consts: 0 };
  linear(node, 1, acc);
  // cancel a term against an equal one of the other sign
  for (let i = 0; i < acc.terms.length; i++) for (let j = i + 1; j < acc.terms.length; j++) {
    if (acc.terms[i] && acc.terms[j] && acc.terms[i].sign !== acc.terms[j].sign && structuralKey(acc.terms[i].e) === structuralKey(acc.terms[j].e)) { acc.terms[i] = null; acc.terms[j] = null; acc.cancelled = true; }
  }
  const terms = acc.terms.filter(Boolean);
  if (acc.consts < 2 && !acc.cancelled) return node;
  if (!terms.length) return lit(acc.c);
  const firstPos = terms.findIndex((t) => t.sign > 0);
  if (firstPos < 0) return node;
  const [first] = terms.splice(firstPos, 1);
  let out = first.e;
  for (const t of terms) out = { type: 'Binary', op: t.sign > 0 ? '+' : '-', left: out, right: t.e, line: node.line };
  if (acc.c > 0) out = { type: 'Binary', op: '+', left: out, right: { type: 'Number', value: acc.c, raw: null }, line: node.line };
  else if (acc.c < 0) out = { type: 'Binary', op: '-', left: out, right: { type: 'Number', value: -acc.c, raw: null }, line: node.line };
  return out;
}

function peval(e, ctx, model) {
  const env = ctx.env;
  const raw = e;
  e = strip(e);
  const pe = (x) => peval(x, ctx, model);
  const exprOf = (val, fallback) => (isScalar(val) ? lit(val) : (model.toExpr && model.toExpr(val)) || fallback);
  switch (e.type) {
    case 'Number': return { expr: raw, val: e.value };
    case 'String': return { expr: raw, val: e.value };
    case 'True': return { expr: raw, val: true };
    case 'False': return { expr: raw, val: false };
    case 'Nil': return { expr: raw, val: null };
    case 'Vararg': return { expr: e, val: UNKNOWN, multi: new Multi([e], true) };
    case 'Name': {
      if (!env.has(e.name)) return { expr: e, val: UNKNOWN };
      const v = env.get(e.name);
      if (v instanceof Alias) return { expr: v.expr, val: UNKNOWN };
      return { expr: exprOf(v, e), val: v };
    }
    case 'Unary': {
      const a = pe(e.arg);
      if (a.val !== UNKNOWN && isScalar(a.val)) {
        const v = a.val;
        if (e.op === 'not') return known(!truthy(v), e, a);
        if (e.op === '-' && typeof v === 'number') return known(-v, e, a);
        if (e.op === '#' && typeof v === 'string') return known(v.length, e, a);
      }
      return { expr: { ...e, arg: a.expr }, val: UNKNOWN };
    }
    case 'Binary': {
      if (e.op === 'and' || e.op === 'or') {
        const l = pe(e.left);
        if (l.val !== UNKNOWN && isScalar(l.val)) {
          if (e.op === 'and') return truthy(l.val) ? pe(e.right) : l;
          return truthy(l.val) ? l : pe(e.right);
        }
        const r = pe(e.right);
        return { expr: { ...e, left: l.expr, right: r.expr }, val: UNKNOWN };
      }
      const a = pe(e.left);
      const b = pe(e.right);
      if (a.val !== UNKNOWN && b.val !== UNKNOWN) {
        const r = fold(e.op, a.val, b.val);
        if (r !== UNKNOWN) return known(r, e, a, b);
      }
      const l = strip(a.expr);
      const rr = strip(b.expr);
      // an identical name on both sides of ~= or ==: no number differs from itself (MoonVeil's opaque tests use this)
      if (l.type === 'Name' && rr.type === 'Name' && l.name === rr.name && (e.op === '~=' || e.op === '==') && a.val === UNKNOWN) return { expr: lit(e.op === '=='), val: e.op === '==' };
      return { expr: reassociate({ ...e, left: a.expr, right: b.expr }), val: UNKNOWN };
    }
    case 'Index': {
      const o = pe(e.obj);
      const k = pe(e.key);
      const m = model.index && model.index(o, k, e, ctx);
      if (m) return m;
      if (o.val instanceof Table && k.val !== UNKNOWN) {
        const v = o.val.get(k.val);
        return { expr: exprOf(v, { ...e, obj: o.expr, key: k.expr }), val: v };
      }
      return { expr: { ...e, obj: o.expr, key: k.expr }, val: UNKNOWN };
    }
    case 'Call': {
      const f = pe(e.fn);
      const rs = e.args.map(pe);
      const args = [];
      rs.forEach((r, i) => {
        if (i === rs.length - 1 && r.multi) for (const it of r.multi.items) args.push({ expr: it, val: UNKNOWN, spliced: true, open: r.multi.open && it === r.multi.items[r.multi.items.length - 1] });
        else args.push(r);
      });
      const m = model.call && model.call(f, args, e, ctx);
      if (m) return m;
      const call = { ...e, fn: f.expr, args: args.map((a) => a.expr) };
      return { expr: call, val: UNKNOWN, multi: new Multi([call], true) };
    }
    case 'MethodCall': {
      const o = pe(e.obj);
      const rs = e.args.map(pe);
      const args = rs.flatMap((r, i) => (i === rs.length - 1 && r.multi ? r.multi.items : [r.expr]));
      const call = { ...e, obj: o.expr, args };
      return { expr: call, val: UNKNOWN, multi: new Multi([call], true) };
    }
    case 'Table': {
      return { expr: { ...e, fields: e.fields.map((f) => ({ ...f, key: f.key && typeof f.key === 'object' ? pe(f.key).expr : f.key, value: pe(f.value).expr })) }, val: UNKNOWN };
    }
    default: return { expr: e, val: UNKNOWN };
  }
}

// ---- the graph ------------------------------------------------------------------------------------------------------------------

const succs = (t) => (t.kind === 'goto' ? [t.to] : t.kind === 'branch' ? [t.t, t.f] : []);

/** Strongly connected components of size > 1 (and self-loops): block -> { id, assigned: Set of names assigned inside }. */
function loops(blocks) {
  const index = new Map();
  const low = new Map();
  const on = new Set();
  const stack = [];
  let n = 0;
  const comps = [];
  const visit = (v0) => {
    const work = [[v0, 0]];
    index.set(v0, n); low.set(v0, n); n++; stack.push(v0); on.add(v0);
    while (work.length) {
      const top = work[work.length - 1];
      const [v, i] = top;
      const next = succs(blocks.get(v).term);
      if (i < next.length) {
        top[1]++;
        const w = next[i];
        if (!blocks.has(w)) continue;
        if (!index.has(w)) { index.set(w, n); low.set(w, n); n++; stack.push(w); on.add(w); work.push([w, 0]); } else if (on.has(w)) low.set(v, Math.min(low.get(v), index.get(w)));
      } else {
        work.pop();
        if (work.length) { const p = work[work.length - 1][0]; low.set(p, Math.min(low.get(p), low.get(v))); }
        if (low.get(v) === index.get(v)) {
          const comp = [];
          let w;
          do { w = stack.pop(); on.delete(w); comp.push(w); } while (w !== v);
          comps.push(comp);
        }
      }
    }
  };
  for (const k of blocks.keys()) if (!index.has(k)) visit(k);
  const out = new Map();
  comps.forEach((comp, id) => {
    if (comp.length === 1 && !succs(blocks.get(comp[0]).term).includes(comp[0])) return;
    const assigned = new Set();
    for (const b of comp) for (const st of blocks.get(b).stmts) if (st.type === 'Assign') for (const t of st.targets) if (t.type === 'Name') assigned.add(t.name);
    for (const b of comp) out.set(b, { id, assigned });
  });
  return out;
}

const ids = new WeakMap();
let nextId = 1;
const objectId = (t) => { if (!ids.has(t)) ids.set(t, nextId++); return ids.get(t); };

/** Do the graph-wide work (what each block needs, where the loops are) once, for many evaluations of the same graph. */
export function prepare(blocks, options = {}) {
  const limit = options.limit ?? 40;
  const maxBlocks = options.maxBlocks ?? 20000;
  const model = options.model || {};
  const live = liveness(blocks, options.exitLive || new Set());
  const loopOf = loops(blocks);
  const widened = new Set();
  return {
    /** `wide`: the loops already given up on; the caller may keep one set for evaluations that have something in common (the default is shared by all). */
    evaluate(entry, initial, wide = widened) {
      for (let attempt = 0; attempt < 8; attempt++) {
        const r = run(blocks, entry, initial, { live, loopOf, widened: wide, limit, maxBlocks, model });
        if (!r.overflow) return r;
        wide.add(r.overflow);
      }
      throw new Error('partial evaluation did not settle');
    },
  };
}

export function partialEvaluate(blocks, entry, initial, options = {}) {
  return prepare(blocks, options).evaluate(entry, initial);
}

function run(blocks, entry, initial, { live, loopOf, widened, limit, maxBlocks, model }) {
  const out = new Map();
  const exits = new Map();
  const variants = new Map();      // original block -> Map(key -> residual id)
  const queue = [];
  const keyOfValue = (v) => (v instanceof Alias ? `L:${structuralKey(v.expr)}` : v instanceof Table ? `#${objectId(v)}` : typeof v === 'string' ? JSON.stringify(v) : isScalar(v) ? String(v) : (model.keyOf && model.keyOf(v)) || `@${objectId(v)}`);
  const keep = (n, liveNames) => liveNames.has(n) || (model.alive && model.alive(n));
  const enter = (b, env) => {
    const loop = loopOf.get(b);
    let e = env;
    if (loop && widened.has(loop.id)) { e = new Map(env); for (const n of loop.assigned) e.delete(n); }
    const liveNames = live.get(b) || new Set();
    const kept = new Map();
    for (const [n, v] of e) if (keep(n, liveNames)) kept.set(n, v);
    const key = [...kept.keys()].sort().map((n) => `${n}=${keyOfValue(kept.get(n))}`).join(',');
    if (!variants.has(b)) variants.set(b, new Map());
    const vs = variants.get(b);
    if (vs.has(key)) return vs.get(key);
    if (loop && vs.size >= limit && !widened.has(loop.id)) throw { overflow: loop.id };
    const id = `${String(b)}@${vs.size}`;
    vs.set(key, id);
    queue.push([b, kept, id]);
    return id;
  };
  let entryId;
  try {
    entryId = enter(entry, new Map(initial));
    while (queue.length) {
      if (out.size > maxBlocks) throw new Error('partial evaluation produced too many blocks');
      const [b, env0, id] = queue.shift();
      const env = new Map(env0);
      const src = blocks.get(b);
      const stmts = [];
      const ctx = { env, emit: (s) => stmts.push(s), invalidate: (n) => invalidate(env, n) };
      for (const st of src.stmts) {
        if (st.type === 'Assign') {
          const rs = [];
          st.values.forEach((v, i) => {
            const r = peval(v, ctx, model);
            // a run of values on the right of a longer list of targets: spread what is known
            if (i === st.values.length - 1 && st.targets.length > st.values.length && r.multi && !r.multi.open) r.multi.items.forEach((it, j) => rs.push({ expr: it, val: r.multi.vals ? r.multi.vals[j] : UNKNOWN }));
            else rs.push(r);
          });
          const hasMore = st.targets.length > rs.length;
          const lastOpen = hasMore && st.values.length && ['Call', 'MethodCall', 'Vararg'].includes(strip(st.values[st.values.length - 1]).type);
          // targets: names are tracked; stores into a known table are refused unless the model takes them
          const values = rs.map((r) => r.expr);
          const targets = [];
          const effects = [];
          st.targets.forEach((t, k) => {
            if (t.type === 'Index') {
              const o = peval(t.obj, ctx, model);
              const key = peval(t.key, ctx, model);
              const r = k < rs.length ? rs[k] : { expr: { type: 'Nil' }, val: null };
              effects.push({ o, key, r, t });
              targets.push({ ...t, obj: o.expr, key: key.expr });
            } else targets.push(t);
          });
          // the model may take a store (a register, an upvalue, a global, a list under construction) and write its own statement
          let handled = false;
          if (effects.length && model.store && st.targets.length === 1) {
            const { o, key, r, t } = effects[0];
            if (model.store(o, key, r, t, ctx)) handled = true;
          }
          if (!handled) {
            for (const { o } of effects) if (o.val instanceof Table) throw new Error('write into a known table');
            // a store the model leaves alone still has to be written; and a name target is updated
            // the model may stand in a marker for "how many values the list above holds": that is read from the list once it is assigned
            const after = [];
            for (let j = values.length - 1; j >= 1; j--) {
              if (values[j] && values[j].type === 'PackCount' && targets[j - 1] && targets[j - 1].type === 'Name' && targets[j]) {
                after.push({ type: 'Assign', targets: [targets[j]], values: [{ type: 'Index', obj: targets[j - 1], key: lit('n'), dot: true }] });
                targets.splice(j, 1);
                values.splice(j, 1);
              }
            }
            const stmt = { ...st, targets, values: values.length ? values : st.values };
            stmts.push(stmt, ...after);
          }
          st.targets.forEach((t, k) => {
            if (t.type !== 'Name') return;
            const r = k < rs.length ? rs[k] : lastOpen ? null : { val: null };
            invalidate(env, t.name);
            if (r && r.val !== UNKNOWN) env.set(t.name, r.val);
            else if (r && r.expr && r.expr.type !== 'PackCount' && pure(r.expr) && !r.multi) env.set(t.name, new Alias(r.expr));
            else env.delete(t.name);
          });
        } else if (st.type === 'CallStmt') {
          const r = peval(st.call, ctx, model);
          if (!r.skip) stmts.push({ ...st, call: r.expr });
        } else stmts.push(st);
      }
      const t = src.term;
      let term;
      if (t.kind === 'goto') term = { kind: 'goto', to: enter(t.to, env) };
      else if (t.kind === 'branch') {
        const c = peval(t.cond, ctx, model);
        if (c.val !== UNKNOWN && isScalar(c.val)) term = { kind: 'goto', to: enter(truthy(c.val) ? t.t : t.f, env) };
        else term = { kind: 'branch', cond: c.expr, t: enter(t.t, env), f: enter(t.f, env) };
      } else if (t.kind === 'return') {
        let values = null;
        if (t.values) {
          const rs = t.values.map((v) => peval(v, ctx, model));
          values = [];
          rs.forEach((r, i) => { if (i === rs.length - 1 && r.multi) values.push(...r.multi.items); else values.push(r.expr); });
        }
        term = { kind: 'return', values };
      } else { term = { ...t }; exits.set(id, new Map(env)); }
      out.set(id, { stmts, term });
    }
  } catch (err) {
    if (err && err.overflow !== undefined) return { overflow: err.overflow };
    throw err;
  }
  return { blocks: out, entry: entryId, exits };
}
