// A small evaluator for residual handler code: assignments, arithmetic, strings, tables, loops through block graphs, whitelisted builtins.
// It only ever touches values handed to it (a model of the prototype's code array and its constants).
export class Unknown extends Error {}
/**
 * A table of the evaluator's model. `log`, when given, is a list the table adds itself to the first time it is changed, so that a caller can find
 * what a piece of code changed without looking at every table; `changes` (a Set) collects the keys that were set.
 */
export class LTable {
  constructor(log = null) { this.h = new Map(); this.dirty = false; this.log = log; }
  get(k) { return this.h.has(k) ? this.h.get(k) : null; }
  set(k, v) {
    if (!this.dirty) { this.dirty = true; if (this.log) this.log.push(this); }
    if (this.changes) this.changes.add(k);
    if (v === null) this.h.delete(k); else this.h.set(k, v);
  }
  len() { let n = 0; while (this.h.has(n + 1)) n++; return n; }
}
const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const truthy = (v) => v !== null && v !== false && v !== undefined;
const toNum = (v) => { if (typeof v === 'number') return v; throw new Unknown('arith on ' + typeof v); };
export function makeEval({ resolveIndex, call }) {
  function ev(e, env) {
    e = strip(e);
    switch (e.type) {
      case 'Number': return e.value;
      case 'String': return e.value;
      case 'True': return true;
      case 'False': return false;
      case 'Nil': return null;
      case 'Name': if (!env.has(e.name)) throw new Unknown('unset ' + e.name); return env.get(e.name);
      case 'Table': { if (e.fields.length) throw new Unknown('table constructor with fields'); return new LTable(); }
      case 'Unary': {
        const v = ev(e.arg, env);
        if (e.op === 'not') return !truthy(v);
        if (e.op === '-') return -toNum(v);
        if (e.op === '#') { if (typeof v === 'string') return v.length; if (v instanceof LTable) return v.len(); throw new Unknown('# of ' + typeof v); }
        throw new Unknown('unary ' + e.op);
      }
      case 'Binary': {
        if (e.op === 'and') { const l = ev(e.left, env); return truthy(l) ? ev(e.right, env) : l; }
        if (e.op === 'or') { const l = ev(e.left, env); return truthy(l) ? l : ev(e.right, env); }
        const a = ev(e.left, env), b = ev(e.right, env);
        switch (e.op) {
          case '+': return toNum(a) + toNum(b);
          case '-': return toNum(a) - toNum(b);
          case '*': return toNum(a) * toNum(b);
          case '/': return toNum(a) / toNum(b);
          case '%': { const x = toNum(a), y = toNum(b); return x - Math.floor(x / y) * y; }
          case '..': return String(a) + String(b);
          case '==': return a === b;
          case '~=': return a !== b;
          case '<': return a < b;
          case '<=': return a <= b;
          case '>': return a > b;
          case '>=': return a >= b;
          default: throw new Unknown('binary ' + e.op);
        }
      }
      case 'Index': {
        const k = ev(e.key, env);
        const r = resolveIndex(e, env, k, ev);
        if (r !== undefined) return r;
        const o = ev(e.obj, env);
        if (o instanceof LTable) return o.get(k);
        throw new Unknown('index of ' + typeof o);
      }
      case 'Call': return multi(e, env)[0] ?? null;
      default: throw new Unknown('expression ' + e.type);
    }
  }
  function multi(e, env) {
    e = strip(e);
    if (e.type !== 'Call') return [ev(e, env)];
    const f = ev(e.fn, env);
    const args = [];
    e.args.forEach((a, i) => { if (i === e.args.length - 1 && strip(a).type === 'Call') args.push(...multi(a, env)); else args.push(ev(a, env)); });
    return call(f, args, e);
  }
  function exec(blocks, entry, env, limit = 200000) {
    let cur = entry;
    let steps = 0;
    for (;;) {
      if (++steps > limit) throw new Unknown('step limit');
      const b = blocks.get(cur);
      for (const st of b.stmts) {
        if (st.type === 'Assign') {
          const vals = [];
          st.values.forEach((v, i) => { if (i === st.values.length - 1 && strip(v).type === 'Call') vals.push(...multi(v, env)); else vals.push(ev(v, env)); });
          st.targets.forEach((t, i) => {
            const v = i < vals.length ? vals[i] : null;
            if (t.type === 'Name') env.set(t.name, v);
            else if (t.type === 'Index') { const o = ev(t.obj, env); if (!(o instanceof LTable)) throw new Unknown('store into ' + typeof o); o.set(ev(t.key, env), v); }
            else throw new Unknown('target ' + t.type);
          });
        } else if (st.type === 'CallStmt') multi(st.call, env);
        else throw new Unknown('statement ' + st.type);
      }
      const t = b.term;
      if (t.kind === 'goto') cur = t.to;
      else if (t.kind === 'branch') cur = truthy(ev(t.cond, env)) ? t.t : t.f;
      else return { kind: t.kind, block: cur, values: t.kind === 'return' ? (t.values || []).map((v) => ev(v, env)) : [] };
    }
  }
  return { ev, multi, exec };
}
