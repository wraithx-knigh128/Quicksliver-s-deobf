// Data-flow clean-up for decompiled code.
//
// A register machine reuses a handful of registers for everything, so decompiled code is full of copies and
// short-lived temporaries:
//
//     value = fn; value1 = i; value2 = num; value = value2 + value1; num = value
//
// Three exact transformations turn that back into what a person wrote (`num = num + i`):
//
//   dead stores      a store nobody reads before the next store (backward liveness over the structured tree)
//   copy propagation `v = w` ... `use(v)`  ->  `use(w)` while neither has changed (also for small constants)
//   temp forwarding  `t = e` directly followed by the only use of `t`  ->  the use evaluates `e`
//
// Only plain locals that no nested function touches are considered. A function with `goto` is left as it is.
// Everything is justified by the scope analysis of core/scope.js and by the evaluation order of Lua; nothing
// here depends on guessing what the program does.

import { analyze } from '../core/scope.js';
import { walk, clone } from '../core/walk.js';
import { isPure } from './simplify.js';
import { numericVars } from './numeric.js';
import { isMachineName } from './rename.js';

const LONG_STRING = 24;

export class Unsupported extends Error {}

/** The tracked variable a Name/Id node refers to, or null. */
export function tracker(info) {
  return (node) => {
    const v = info.varOf.get(node);
    return v && !v.isGlobal && !v.captured && !(node.attrib) ? v : null;
  };
}

/** Like `tracker`, but a local that a closure captured counts too (see `captureExposure` for what that requires). */
export function trackerWithCaptured(info) {
  return (node) => {
    const v = info.varOf.get(node);
    return v && !v.isGlobal && !(node.attrib) ? v : null;
  };
}

/** The expressions a statement evaluates itself (not those of the statements nested in it). */
function ownExpressions(s) {
  switch (s.type) {
    case 'Local': return s.values;
    case 'Assign': return [...s.targets, ...s.values];
    case 'CompoundAssign': return [s.target, s.value];
    case 'CallStmt': return [s.call];
    case 'Return': return s.values;
    case 'If': return s.clauses.map((c) => c.cond);
    case 'While': case 'Repeat': return [s.cond];
    case 'NumFor': return [s.start, s.stop, ...(s.step ? [s.step] : [])];
    case 'GenFor': return s.exprs;
    case 'Function': return [s.target, s.func];
    case 'LocalFunction': return [s.func];
    default: return [];
  }
}

/**
 * Which captured variables can a closure read or write after a given point of one function body?
 *
 * A closure can only see a variable once it has been created, so before the first closure that mentions a variable the
 * variable is as private as any other local. Afterwards it may be read at any time (the closure can be called from
 * anywhere), and inside a loop that creates such a closure the next pass is "afterwards" too. Statements are numbered in
 * source order; a variable is exposed after statement S if a closure mentioning it was created in or before S, or in a
 * loop that contains S.
 *
 * @returns {{after(s): Set<Var>, before(s): Set<Var>}}
 */
export function captureExposure(body, info, params = []) {
  const declared = new Set();
  const note = (id) => { const x = info.varOf.get(id); if (x) declared.add(x); };
  params.forEach(note);
  const first = new Map();        // Var -> ordinal of the first statement creating a closure that mentions it
  const loopsOfVar = new Map();   // Var -> loops containing such a creation
  const ord = new Map();
  const last = new Map();
  const loopsOf = new Map();
  let counter = 0;
  const loopStack = [];

  const mentions = (func) => {
    const out = new Set();
    walk(func, (n) => { if (n.type === 'Name') { const x = info.varOf.get(n); if (x && !x.isGlobal) out.add(x); } return undefined; });
    return out;
  };

  const visit = (stmts) => {
    for (const s of stmts) {
      ord.set(s, counter++);
      loopsOf.set(s, loopStack.slice());
      if (s.type === 'Local') s.ids.forEach(note);
      else if (s.type === 'LocalFunction') note(s.id);
      else if (s.type === 'NumFor') note(s.id);
      else if (s.type === 'GenFor') s.ids.forEach(note);
      // closures created by this statement's own expressions
      for (const e of ownExpressions(s)) {
        walk(e, (n) => {
          if (n.type !== 'Func') return undefined;
          for (const x of mentions(n)) {
            if (!first.has(x) || first.get(x) > ord.get(s)) first.set(x, ord.get(s));
            if (!loopsOfVar.has(x)) loopsOfVar.set(x, new Set());
            for (const l of loopStack) loopsOfVar.get(x).add(l);
          }
          return false;
        });
      }
      const isLoop = s.type === 'While' || s.type === 'Repeat' || s.type === 'NumFor' || s.type === 'GenFor';
      if (isLoop) loopStack.push(s);
      for (const b of childBlocks(s)) visit(b);
      if (isLoop) loopStack.pop();
      last.set(s, counter - 1);
    }
  };
  visit(body);

  const exposed = (s, n) => {
    const out = new Set();
    for (const [x, at] of first) {
      if (!declared.has(x)) continue;
      if (n(at)) { out.add(x); continue; }
      const loops = loopsOfVar.get(x);
      if (loops && loopsOf.get(s)?.some((l) => loops.has(l))) out.add(x);
    }
    return out;
  };
  return {
    after: (s) => (ord.has(s) ? exposed(s, (at) => last.get(s) >= at) : new Set()),
    before: (s) => (ord.has(s) ? exposed(s, (at) => ord.get(s) > at) : new Set()),
  };
}

/** Statement lists directly inside a statement. */
export function childBlocks(s) {
  switch (s.type) {
    case 'Do': case 'While': case 'Repeat': case 'NumFor': case 'GenFor': return [s.body];
    case 'If': return [...s.clauses.map((c) => c.body), ...(s.orelse ? [s.orelse] : [])];
    default: return [];
  }
}

/** Tracked variables written anywhere inside `node` (not inside nested functions). */
export function writtenIn(node, v) {
  const out = new Set();
  const add = (id) => { const x = v(id); if (x) out.add(x); };
  walk(node, (n) => {
    if (n.type === 'Func') return false;
    switch (n.type) {
      case 'Assign': for (const t of n.targets) if (t.type === 'Name') add(t); break;
      case 'CompoundAssign': if (n.target.type === 'Name') add(n.target); break;
      case 'Local': n.ids.forEach(add); break;
      case 'LocalFunction': add(n.id); break;
      case 'Function': if (n.target.type === 'Name') add(n.target); break;
      case 'NumFor': add(n.id); break;
      case 'GenFor': n.ids.forEach(add); break;
      default: break;
    }
    return undefined;
  });
  return out;
}

const union = (a, b) => { const s = new Set(a); for (const x of b) s.add(x); return s; };
const same = (a, b) => a.size === b.size && [...a].every((x) => b.has(x));
const minus = (a, b) => { const s = new Set(a); for (const x of b) s.delete(x); return s; };

// ---- liveness -------------------------------------------------------------------------------------------------

export class Liveness {
  constructor(info, v, { edit = false, record = null, exposure = null } = {}) {
    this.info = info;
    this.v = v;
    this.exposure = exposure;   // captured variables a closure may still read after a statement (see captureExposure)
    this.edit = edit;
    this.record = record;   // Map: statement -> variables live after it
    this.breaks = [];
    this.changed = 0;
  }

  reads(node, into = new Set()) {
    walk(node, (n) => {
      if (n.type === 'Func') return false;
      if (n.type === 'Name') { const x = this.v(n); if (x) into.add(x); }
      return undefined;
    });
    return into;
  }

  /** Live variables before the block, given those live after it; in edit mode dead stores are removed in place. */
  block(stmts, out) {
    let live = out;
    const result = [];
    for (let i = stmts.length - 1; i >= 0; i--) {
      const s = stmts[i];
      if (this.exposure) { const e = this.exposure.after(s); if (e.size) live = union(live, e); }
      if (this.record) this.record.set(s, live);
      const r = this.stmt(s, live);
      live = r.live;
      if (r.replace === undefined) result.push(s);
      else if (r.replace !== null) result.push(...(Array.isArray(r.replace) ? [...r.replace].reverse() : [r.replace]));
      if (r.replace !== undefined) this.changed++;
    }
    if (this.edit && this.changed) {
      result.reverse();
      const end = stmts.endComments;
      stmts.length = 0;
      stmts.push(...result);
      if (end) stmts.endComments = end;
    }
    return live;
  }

  loop(out, header, bodyOf) {
    // live at the loop head = what the header needs, what follows, and what another pass of the body needs
    let head = union(header, out);
    for (let guard = 0; guard < 16; guard++) {
      const saved = this.changed;
      const wasEdit = this.edit;
      this.edit = false;
      this.breaks.push(out);
      const inBody = bodyOf(head);
      this.breaks.pop();
      this.edit = wasEdit;
      this.changed = saved;
      const next = union(head, inBody);
      if (same(next, head)) break;
      head = next;
    }
    this.breaks.push(out);
    const inBody = bodyOf(head);
    this.breaks.pop();
    return { head, inBody };
  }

  stmt(s, out) {
    const { v } = this;
    switch (s.type) {
      case 'Local': {
        const ids = s.ids.map((id) => v(id));
        const rd = new Set();
        s.values.forEach((e) => this.reads(e, rd));
        const defs = new Set(ids.filter(Boolean));
        let replace;
        if (this.edit && s.ids.length === 1 && s.values.length === 1 && ids[0] && !out.has(ids[0]) && !s.ids[0].attrib) {
          if (isPure(s.values[0], this.info)) replace = { ...s, values: [] };
          else if (s.values[0].type === 'Call' || s.values[0].type === 'MethodCall') replace = [{ ...s, values: [] }, { type: 'CallStmt', call: s.values[0] }];
        }
        const live = replace !== undefined && !Array.isArray(replace) ? minus(out, defs) : union(minus(out, defs), rd);
        return { live, replace };
      }
      case 'Assign': {
        const defs = new Set();
        const rd = new Set();
        s.values.forEach((e) => this.reads(e, rd));
        for (const t of s.targets) {
          if (t.type === 'Name') { const x = v(t); if (x) defs.add(x); } else this.reads(t, rd);
        }
        let replace;
        const allDead = s.targets.every((t) => t.type === 'Name' && v(t) && !out.has(v(t)));
        if (this.edit && allDead) {
          if (s.values.every((e) => isPure(e, this.info))) replace = null;
          else if (s.targets.length === 1 && s.values.length === 1 && (s.values[0].type === 'Call' || s.values[0].type === 'MethodCall')) replace = { type: 'CallStmt', call: s.values[0], comments: s.comments };
        }
        const live = replace === null ? out : union(minus(out, defs), rd);
        return { live, replace };
      }
      case 'CompoundAssign': {
        const rd = this.reads(s.value);
        if (s.target.type === 'Name') { const x = v(s.target); if (x) rd.add(x); } else this.reads(s.target, rd);
        return { live: union(out, rd) };
      }
      case 'CallStmt': return { live: union(out, this.reads(s.call)) };
      case 'Return': return { live: this.reads(s.values) };
      case 'Break': return { live: this.breaks.length ? this.breaks[this.breaks.length - 1] : out };
      case 'Do': return { live: this.block(s.body, out) };
      case 'If': {
        let next = s.orelse ? this.block(s.orelse, out) : out;
        for (let i = s.clauses.length - 1; i >= 0; i--) {
          const c = s.clauses[i];
          next = union(this.reads(c.cond), union(this.block(c.body, out), next));
        }
        return { live: next };
      }
      case 'While': {
        const cond = this.reads(s.cond);
        const { head } = this.loop(out, cond, (h) => this.block(s.body, h));
        return { live: head };
      }
      case 'Repeat': {
        const cond = this.reads(s.cond);
        const { inBody } = this.loop(out, new Set(), (h) => this.block(s.body, union(cond, h)));
        // `until` runs after the body: whatever the body needs on entry, plus nothing else is live before it
        return { live: inBody };
      }
      case 'NumFor': {
        const header = this.reads(s.start);
        this.reads(s.stop, header);
        if (s.step) this.reads(s.step, header);
        const lv = v(s.id);
        const { head } = this.loop(out, new Set(), (h) => minus(this.block(s.body, h), new Set(lv ? [lv] : [])));
        return { live: union(header, head) };
      }
      case 'GenFor': {
        const header = new Set();
        s.exprs.forEach((e) => this.reads(e, header));
        const lvs = new Set(s.ids.map((id) => v(id)).filter(Boolean));
        const { head } = this.loop(out, new Set(), (h) => minus(this.block(s.body, h), lvs));
        return { live: union(header, head) };
      }
      case 'LocalFunction': { const x = v(s.id); return { live: x ? minus(out, new Set([x])) : out }; }
      case 'Function': {
        const rd = new Set();
        let live = out;
        if (s.target.type === 'Name') { const x = v(s.target); if (x) live = minus(out, new Set([x])); } else this.reads(s.target, rd);
        return { live: union(live, rd) };
      }
      case 'Label': case 'Goto': case 'Continue': throw new Unsupported();
      default: return { live: out };
    }
  }
}

// ---- copy propagation -----------------------------------------------------------------------------------------

const isSmallLiteral = (e) => e.type === 'Number' || e.type === 'True' || e.type === 'False' || e.type === 'Nil'
  || (e.type === 'String' && e.value.length <= LONG_STRING) || (e.type === 'Unary' && e.op === '-' && e.arg.type === 'Number');

class Copies {
  constructor(info, v) { this.info = info; this.v = v; this.changed = 0; }

  /** Replace reads inside `e` by the value they are known to copy. */
  subst(e, env) {
    if (!env.size) return e;
    const go = (n) => {
      switch (n.type) {
        case 'Name': {
          const x = this.v(n);
          const atom = x && env.get(x);
          if (!atom || atom.long) return n;
          this.changed++;
          const copy = clone(atom.node);
          if (atom.var) this.info.varOf.set(copy, atom.var);
          return copy;
        }
        case 'Func': return n;
        case 'Index': n.obj = go(n.obj); if (!(n.key.type === 'String' && n.dot)) n.key = go(n.key); return n;
        case 'Call': n.fn = go(n.fn); n.args = n.args.map(go); return n;
        case 'MethodCall': n.obj = go(n.obj); n.args = n.args.map(go); return n;
        case 'Table': for (const f of n.fields) { if (f.kind === 'keyed') f.key = go(f.key); f.value = go(f.value); } return n;
        case 'Binary': n.left = go(n.left); n.right = go(n.right); return n;
        case 'Unary': n.arg = go(n.arg); return n;
        case 'Paren': n.expr = go(n.expr); return n;
        case 'IfExpr': n.cond = go(n.cond); n.then = go(n.then); n.orelse = go(n.orelse); return n;
        case 'TypeAssert': n.expr = go(n.expr); return n;
        default: return n;
      }
    };
    return go(e);
  }

  kill(env, x) {
    env.delete(x);
    for (const [k, a] of env) if (a.var === x) env.delete(k);
  }

  /** A declaration that reuses the name of a variable a copy points to would capture the substituted name. */
  shadow(env, ids) {
    const declared = new Map();
    for (const id of ids) { const x = this.v(id); declared.set(id.name, x); }
    for (const [k, a] of env) if (a.var && declared.has(a.var.name) && declared.get(a.var.name) !== a.var) env.delete(k);
  }

  /** Is the variable a reused register rather than a single-assignment local the author named? */
  reused(x) { return x.writes.length + (x.hasInit ? 1 : 0) >= 2; }

  block(stmts, env) {
    for (const s of stmts) this.stmt(s, env);
  }

  /** The value a store makes the variable a copy of, if it is a plain variable or a small constant. A constant is only
   *  propagated into a register that is reused (see `reused`); a single-assignment local keeps the name it was given. */
  atomOf(e, target, env) {
    if (e.type === 'Name') {
      const x = this.v(e);
      return x && x !== target ? { var: x, node: e } : null;
    }
    if (e.type === 'String' && e.value.length > LONG_STRING) {
      // the same long text held by another variable that has not changed since: an alias of it
      for (const [y, a] of env) if (y !== target && a.long === e.value) return { var: y, node: { type: 'Name', name: y.name } };
      return { var: null, node: e, long: e.value };
    }
    return isSmallLiteral(e) ? { var: null, node: e } : null;
  }

  stmt(s, env) {
    const { v } = this;
    switch (s.type) {
      case 'Local': {
        s.values = s.values.map((e) => this.subst(e, env));
        this.shadow(env, s.ids);
        s.ids.forEach((id, i) => {
          const x = v(id);
          if (!x) return;
          this.kill(env, x);
          if (s.ids.length === s.values.length && !id.attrib) {
            const atom = this.atomOf(s.values[i], x, env);
            if (atom && (atom.var || atom.long || s.computed || this.reused(x))) env.set(x, atom);
          }
        });
        break;
      }
      case 'Assign': {
        s.values = s.values.map((e) => this.subst(e, env));
        s.targets = s.targets.map((t) => (t.type === 'Name' ? t : this.subst(t, env)));
        const targets = s.targets.map((t) => (t.type === 'Name' ? v(t) : null));
        for (const x of targets) if (x) this.kill(env, x);
        if (s.targets.length === 1 && s.values.length === 1 && targets[0]) {
          const atom = this.atomOf(s.values[0], targets[0], env);
          if (atom && (atom.var || atom.long || s.computed || this.reused(targets[0]))) env.set(targets[0], atom);
        }
        break;
      }
      case 'CompoundAssign': {
        s.value = this.subst(s.value, env);
        if (s.target.type === 'Name') { const x = v(s.target); if (x) this.kill(env, x); } else s.target = this.subst(s.target, env);
        break;
      }
      case 'CallStmt': s.call = this.subst(s.call, env); break;
      case 'Return': s.values = s.values.map((e) => this.subst(e, env)); break;
      case 'Do': { const inner = new Map(env); this.block(s.body, inner); this.afterCompound(s, env); break; }
      case 'If': {
        for (const c of s.clauses) c.cond = this.subst(c.cond, env);
        for (const b of childBlocks(s)) this.block(b, new Map(env));
        this.afterCompound(s, env);
        break;
      }
      case 'While': {
        this.afterCompound(s, env);        // what the body assigns is not known on entry to the condition
        s.cond = this.subst(s.cond, env);
        this.block(s.body, new Map(env));
        break;
      }
      case 'Repeat': {
        this.afterCompound(s, env);
        const inner = new Map(env);
        this.block(s.body, inner);
        s.cond = this.subst(s.cond, inner);
        break;
      }
      case 'NumFor': {
        s.start = this.subst(s.start, env); s.stop = this.subst(s.stop, env);
        if (s.step) s.step = this.subst(s.step, env);
        this.afterCompound(s, env);
        const inner = new Map(env);
        this.shadow(inner, [s.id]);
        this.block(s.body, inner);
        break;
      }
      case 'GenFor': {
        s.exprs = s.exprs.map((e) => this.subst(e, env));
        this.afterCompound(s, env);
        const inner = new Map(env);
        this.shadow(inner, s.ids);
        this.block(s.body, inner);
        break;
      }
      case 'LocalFunction': { this.shadow(env, [s.id]); const x = v(s.id); if (x) this.kill(env, x); break; }
      case 'Function': {
        if (s.target.type === 'Name') { const x = v(s.target); if (x) this.kill(env, x); } else s.target = this.subst(s.target, env);
        break;
      }
      default: break;
    }
  }

  /** After a compound statement nothing it assigns can be assumed. */
  afterCompound(s, env) {
    for (const x of writtenIn(s, this.v)) this.kill(env, x);
  }
}

// ---- temporary forwarding -------------------------------------------------------------------------------------

/**
 * The expressions of `s` in the order Lua evaluates them, as a flat list of leaves with the facts that decide whether
 * a value may be computed later than where it was assigned.
 */
function evaluationOrder(s) {
  const events = [];
  const visit = (e, conditional) => {
    switch (e.type) {
      case 'Name': events.push({ node: e, conditional, effect: false }); break;
      case 'Func': events.push({ node: e, conditional, effect: false }); break;
      case 'Index': visit(e.obj, conditional); if (!(e.key.type === 'String' && e.dot)) visit(e.key, conditional); break;
      case 'Call': visit(e.fn, conditional); e.args.forEach((a) => visit(a, conditional)); events.push({ node: e, conditional, effect: true }); break;
      case 'MethodCall': visit(e.obj, conditional); e.args.forEach((a) => visit(a, conditional)); events.push({ node: e, conditional, effect: true }); break;
      case 'Table': for (const f of e.fields) { if (f.kind === 'keyed') visit(f.key, conditional); visit(f.value, conditional); } break;
      case 'Binary':
        visit(e.left, conditional);
        visit(e.right, conditional || e.op === 'and' || e.op === 'or');
        break;
      case 'Unary': visit(e.arg, conditional); break;
      case 'Paren': visit(e.expr, conditional); break;
      case 'IfExpr': visit(e.cond, conditional); visit(e.then, true); visit(e.orelse, true); break;
      case 'TypeAssert': visit(e.expr, conditional); break;
      default: events.push({ node: e, conditional, effect: false });
    }
  };
  switch (s.type) {
    case 'Assign':
      for (const t of s.targets) if (t.type !== 'Name') visit(t, false);
      s.values.forEach((e) => visit(e, false));
      break;
    case 'Local': s.values.forEach((e) => visit(e, false)); break;
    case 'CallStmt': visit(s.call, false); break;
    case 'Return': s.values.forEach((e) => visit(e, false)); break;
    case 'If': visit(s.clauses[0].cond, false); break;
    case 'GenFor': s.exprs.forEach((e) => visit(e, false)); break;
    case 'NumFor': visit(s.start, false); visit(s.stop, false); if (s.step) visit(s.step, false); break;
    default: return null;
  }
  return events;
}

const isTrivialValue = (e, v) => e.type === 'Number' || e.type === 'String' || e.type === 'True' || e.type === 'False' || e.type === 'Nil' || e.type === 'Func' || (e.type === 'Name' && v(e));
const multiValued = (e) => e.type === 'Call' || e.type === 'MethodCall' || e.type === 'Vararg';

/**
 * Replace the one Name node `target` inside statement `s` by `value`. A call or `...` put in the last position of an argument,
 * table or value list would start to yield all its results instead of one, so that is refused (`blocked`).
 */
function replaceNode(s, target, value) {
  let done = false;
  let blocked = false;
  const go = (n, multi = false) => {
    if (n === target) {
      if (multi && multiValued(value)) { blocked = true; return n; }
      done = true;
      return value;
    }
    switch (n.type) {
      case 'Func': return n;
      case 'Index': n.obj = go(n.obj); if (!(n.key.type === 'String' && n.dot)) n.key = go(n.key); return n;
      case 'Call': n.fn = go(n.fn); n.args = n.args.map((a, i) => go(a, i === n.args.length - 1)); return n;
      case 'MethodCall': n.obj = go(n.obj); n.args = n.args.map((a, i) => go(a, i === n.args.length - 1)); return n;
      case 'Table': n.fields.forEach((f, i) => { if (f.kind === 'keyed') f.key = go(f.key); f.value = go(f.value, f.kind === 'item' && i === n.fields.length - 1); }); return n;
      case 'Binary': n.left = go(n.left); n.right = go(n.right); return n;
      case 'Unary': n.arg = go(n.arg); return n;
      case 'Paren': n.expr = go(n.expr); return n;
      case 'IfExpr': n.cond = go(n.cond); n.then = go(n.then); n.orelse = go(n.orelse); return n;
      case 'TypeAssert': n.expr = go(n.expr); return n;
      default: return n;
    }
  };
  const list = (values) => values.map((e, i) => go(e, i === values.length - 1));
  switch (s.type) {
    case 'Assign': s.targets = s.targets.map((t) => (t.type === 'Name' ? t : go(t))); s.values = list(s.values); break;
    case 'Local': s.values = list(s.values); break;
    case 'CallStmt': s.call = go(s.call); break;
    case 'Return': s.values = list(s.values); break;
    case 'If': s.clauses[0].cond = go(s.clauses[0].cond); break;
    case 'GenFor': s.exprs = list(s.exprs); break;
    case 'NumFor': s.start = go(s.start); s.stop = go(s.stop); if (s.step) s.step = go(s.step); break;
    default: break;
  }
  return done && !blocked;
}

function forwardTemps(stmts, ctx) {
  const { info, v, after } = ctx;
  let changed = 0;
  for (let i = 0; i + 1 < stmts.length; i++) {
    const a = stmts[i];
    let x = null;
    let value = null;
    let isLocal = false;
    if (a.type === 'Assign' && a.targets.length === 1 && a.values.length === 1 && a.targets[0].type === 'Name') { x = v(a.targets[0]); value = a.values[0]; }
    else if (a.type === 'Local' && a.ids.length === 1 && a.values.length === 1 && !a.ids[0].attrib) { x = v(a.ids[0]); value = a.values[0]; isLocal = true; }
    if (!x) continue;
    const next = stmts[i + 1];
    // `local t = e` immediately stored somewhere else (`y = t`) is a temporary of the register machine, not a name the
    // author chose; a small closure is written in place the same way
    const copyOut = isLocal && x.writes.length === 0 && x.reads.length === 1 && next.type === 'Assign' && next.targets.length === 1
      && next.values.length === 1 && next.values[0].type === 'Name' && v(next.values[0]) === x;
    if (isLocal && !copyOut && !isMachineName(x.name)) continue;
    if (value.type === 'Func' && !(copyOut && value.body.length <= 1)) continue;
    const b = stmts[i + 1];
    const events = evaluationOrder(b);
    if (!events) continue;
    const uses = events.filter((ev) => ev.node.type === 'Name' && v(ev.node) === x);
    const readsInB = x.reads.filter((r) => { let hit = false; walk(b, (n) => { if (n === r) hit = true; return !hit; }); return hit; });
    if (uses.length !== 1 || readsInB.length !== 1) continue;
    const live = after.get(b);
    const redefined = b.type === 'Assign' && b.targets.some((t) => t.type === 'Name' && v(t) === x);
    if (!live || (live.has(x) && !redefined)) continue;
    // E must not run later than other effects it could observe or cause
    const use = uses[0];
    const at = events.indexOf(use);
    const before = events.slice(0, at);
    const effectBefore = before.some((ev) => ev.effect);
    if (use.conditional && !isTrivialValue(value, v)) continue;
    if (effectBefore && !isTrivialValue(value, v)) continue;
    if (replaceNode(b, use.node, value)) {
      info.varOf.delete?.(use.node);
      stmts.splice(i, 1);
      changed++;
      i = Math.max(-1, i - 2);
    }
  }
  return changed;
}

// ---- driver ---------------------------------------------------------------------------------------------------

export function functionBodies(chunk, info) {
  const out = [chunk.body];
  for (const f of info.funcs) out.push(f.body);
  return out;
}

/** Every function of the chunk with the parameters that belong to it. */
export function functionUnits(chunk, info) {
  return [{ body: chunk.body, params: [] }, ...info.funcs.map((f) => ({ body: f.body, params: f.params }))];
}

export function hasJumps(body) {
  let found = false;
  walk(body, (n) => { if (n.type === 'Func') return false; if (n.type === 'Goto' || n.type === 'Label' || n.type === 'Continue') found = true; return undefined; });
  return found;
}

export function dataflowPass(chunk) {
  let changed = 0;
  for (let round = 0; round < 6; round++) {
    const info = analyze(chunk);
    numericVars(chunk, info);
    const v = tracker(info);
    let roundChanged = 0;
    for (const body of functionBodies(chunk, info)) {
      if (hasJumps(body)) continue;
      try {
        // 1. copies
        const copies = new Copies(info, v);
        copies.block(body, new Map());
        roundChanged += copies.changed;
        // 2. dead stores
        const dse = new Liveness(info, v, { edit: true });
        dse.block(body, new Set());
        roundChanged += dse.changed;
      } catch (e) {
        if (!(e instanceof Unsupported)) throw e;
      }
    }
    // 3. temporaries (needs liveness after the edits above, so the tree is analysed again)
    const info2 = analyze(chunk);
    numericVars(chunk, info2);
    const v2 = tracker(info2);
    for (const body of functionBodies(chunk, info2)) {
      if (hasJumps(body)) continue;
      const after = new Map();
      try { new Liveness(info2, v2, { record: after }).block(body, new Set()); } catch (e) { if (e instanceof Unsupported) continue; throw e; }
      const visit = (stmts) => {
        roundChanged += forwardTemps(stmts, { info: info2, v: v2, after });
        for (const s of stmts) for (const b of childBlocks(s)) visit(b);
      };
      visit(body);
    }
    changed += roundChanged;
    if (!roundChanged) break;
  }
  return { changed };
}
