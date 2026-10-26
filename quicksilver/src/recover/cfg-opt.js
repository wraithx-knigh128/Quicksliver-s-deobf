// Clean-up on a block graph (the shape src/decompile/cfg.js takes): constants, dead stores, dead edges.
//
// An unflattened function still carries what the flattener put around the real code: tests whose outcome is fixed (`step > 0` when
// `step` was set to 1 three blocks earlier), loads and stores into variables that nothing reads, blocks that can no longer be reached.
// Those make the graph look irreducible, so they go first:
//
//   1. constant propagation over the graph, following only the edges a known test can take (so a branch that is never taken does
//      not spoil what a join would otherwise know);
//   2. branches whose test is now known become jumps, unreachable blocks are dropped, a block that only one block jumps to is merged
//      into it;
//   3. assignments to names nobody reads afterwards are removed when the value cannot do anything but be computed (no call).
//
// Only plain local names are tracked. A name that appears inside a nested function may be read or written from there at any time, so
// it is never treated as a constant and never as dead.

import { walk, structuralKey } from '../core/walk.js';

const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const LIT = new Set(['Number', 'String', 'True', 'False', 'Nil']);
const isLit = (e) => !!e && LIT.has(e.type);
const lit = (e) => (e.type === 'Number' ? { type: 'Number', value: e.value, raw: null } : e.type === 'String' ? { type: 'String', value: e.value, raw: null } : { type: e.type });
const truthy = (e) => e.type !== 'False' && e.type !== 'Nil';
const ARITH = new Set(['+', '-', '*', '/', '%', '^', '..']);
/** Truthiness of a test whose value is unknown but whose kind is not: a number, a string or a table is true whatever it holds. */
function alwaysTruthy(e) {
  e = strip(e);
  if (!e) return false;
  if (e.type === 'Binary') return ARITH.has(e.op);
  if (e.type === 'Unary') return e.op === '-' || e.op === '#';
  return e.type === 'Table' || e.type === 'Func' || e.type === 'Number' || e.type === 'String' || e.type === 'True';
}
/** true, false, or null when the test is not decided by what is known. */
function knownTruth(cond, env) {
  const c = evalConst(cond, env);
  if (c) return truthy(c);
  return alwaysTruthy(cond) ? true : null;
}
const bool = (b) => ({ type: b ? 'True' : 'False' });
const sameLit = (a, b) => a.type === b.type && (a.type === 'Number' || a.type === 'String' ? a.value === b.value : true);

// Calls of functions that depend on nothing but their arguments (a decryptor the runtime carries, say) are evaluated when every argument is a
// known constant. The caller names them with `options.pureCalls`: a Map from the name used in the graph to a function over plain values.
let pureCalls = null;
let effectFree = null;
const toValue = (e) => (e.type === 'Nil' ? null : e.type === 'True' ? true : e.type === 'False' ? false : e.value);
const fromValue = (v) => (v === null || v === undefined ? { type: 'Nil' } : v === true ? { type: 'True' } : v === false ? { type: 'False' } : typeof v === 'string' ? { type: 'String', value: v, raw: null } : typeof v === 'number' && Number.isFinite(v) && !Object.is(v, -0) ? { type: 'Number', value: v, raw: null } : null);

/** The literal an expression evaluates to under the known constants, or null. */
export function evalConst(e, env) {
  e = strip(e);
  if (!e) return null;
  if (isLit(e)) return e;
  switch (e.type) {
    case 'Call': {
      const f = pureCalls && strip(e.fn).type === 'Name' ? pureCalls.get(strip(e.fn).name) : null;
      if (!f) return null;
      const args = [];
      for (const a of e.args) { const v = evalConst(a, env); if (!v) return null; args.push(toValue(v)); }
      let r;
      try { r = f(...args); } catch { return null; }
      return r === undefined ? null : fromValue(r);
    }
    case 'Name': return env.has(e.name) ? env.get(e.name) : null;
    case 'Unary': {
      const v = evalConst(e.arg, env);
      if (!v) return null;
      if (e.op === 'not') return bool(!truthy(v));
      if (e.op === '-' && v.type === 'Number') return { type: 'Number', value: -v.value, raw: null };
      if (e.op === '#' && v.type === 'String') return { type: 'Number', value: v.value.length, raw: null };
      return null;
    }
    case 'Binary': {
      if (e.op === 'and' || e.op === 'or') {
        const l = evalConst(e.left, env);
        if (!l) return null;
        if (e.op === 'and') return truthy(l) ? evalConst(e.right, env) : l;
        return truthy(l) ? l : evalConst(e.right, env);
      }
      const a = evalConst(e.left, env);
      const b = evalConst(e.right, env);
      if (!a || !b) return null;
      if (e.op === '==' || e.op === '~=') {
        const same = a.type === b.type ? sameLit(a, b) : false;
        return bool(e.op === '==' ? same : !same);
      }
      if (a.type === 'Number' && b.type === 'Number') {
        const x = a.value;
        const y = b.value;
        // a result that is not a finite number (0/0, 1/0) stays an expression: there is no literal for it
        const n = (v) => (Number.isFinite(v) && !Object.is(v, -0) ? { type: 'Number', value: v, raw: null } : null);
        switch (e.op) {
          case '+': return n(x + y);
          case '-': return n(x - y);
          case '*': return n(x * y);
          case '/': return n(x / y);
          case '%': return y === 0 ? null : n(x - Math.floor(x / y) * y);
          case '^': return n(x ** y);
          case '<': return bool(x < y);
          case '<=': return bool(x <= y);
          case '>': return bool(x > y);
          case '>=': return bool(x >= y);
          default: return null;
        }
      }
      if (a.type === 'String' && b.type === 'String') {
        switch (e.op) {
          case '..': return { type: 'String', value: a.value + b.value, raw: null };
          case '<': return bool(a.value < b.value);
          case '<=': return bool(a.value <= b.value);
          case '>': return bool(a.value > b.value);
          case '>=': return bool(a.value >= b.value);
          default: return null;
        }
      }
      return null;
    }
    default: return null;
  }
}

// ---- helpers over statements ------------------------------------------------------------------------------------------

// Statements are not changed once built (a pass makes a new one), so what a node reads is worked out once. The sets handed out are not to be changed.
const readsCache = new WeakMap();
const namesIn = (node) => {
  if (node && typeof node === 'object') {
    const hit = readsCache.get(node);
    if (hit) return hit;
    const fresh = namesInUncached(node);
    readsCache.set(node, fresh);
    return fresh;
  }
  return namesInUncached(node);
};
const namesInUncached = (node) => {
  const out = new Set();
  walk(node, (n) => {
    if (n.type === 'Name') out.add(n.name);
    // RANGE(M, k, top) reads every register from k up: the program's registers are r<number>, and there are never more than a few dozen
    else if (n.type === 'Call' && n.fn.type === 'Name' && n.fn.name === 'RANGE' && n.args.length === 3 && n.args[1].type === 'Number') for (let i = n.args[1].value; i < n.args[1].value + 64; i++) out.add(`r${i}`);
    // table_move(M, a, b, ...) copies registers a..b
    else if (n.type === 'Call' && n.fn.type === 'Name' && n.fn.name === 'table_move' && n.args.length === 5 && n.args[0].type === 'Name' && n.args[0].name === 'M' && n.args[1].type === 'Number' && n.args[2].type === 'Number') for (let i = n.args[1].value; i <= n.args[2].value; i++) out.add(`r${i}`);
  });
  return out;
};

/** Names an expression or statement list refers to from inside nested functions. */
function escapingNames(blocks) {
  const out = new Set();
  const scan = (node) => walk(node, (n) => {
    if (n.type === 'Func') { for (const x of namesIn(n.body)) out.add(x); return false; }
    // a variable a closure is made over (`ref(r)` in the lifter's output) can be changed from inside it at any time
    if (n.type === 'Call' && n.fn.type === 'Name' && (n.fn.name === 'ref' || n.fn.name === 'upref')) for (const a of n.args) if (a.type === 'Name') out.add(a.name);
    return undefined;
  });
  for (const b of blocks.values()) {
    scan(b.stmts);
    if (b.term.kind === 'branch') scan(b.term.cond);
    if (b.term.kind === 'return' && b.term.values) scan(b.term.values);
  }
  return out;
}

/** A call or `...` as the last value of an assignment supplies every target the earlier values leave over. */
const isMulti = (e) => { e = strip(e); return !!e && (e.type === 'Call' || e.type === 'MethodCall' || e.type === 'Vararg'); };
// Whether computing an expression can do anything but produce its value: any call, except to the functions the caller vouched for (`pureCalls`,
// `effectFree`), counts as doing something, and so does creating a function.
const hasCall = (e) => {
  let found = false;
  walk(e, (n) => {
    if (n.type === 'Call' && strip(n.fn).type === 'Name' && ((pureCalls && pureCalls.has(strip(n.fn).name)) || (effectFree && effectFree.has(strip(n.fn).name)))) return undefined;
    if (n.type === 'Call' || n.type === 'MethodCall' || n.type === 'Func') found = true;
    return !found;
  });
  return found;
};

/** Replace names that hold known literals by those literals, in reads only. */
function substituteReads(node, env, escaping) {
  const sub = (n, isTarget = false) => {
    if (!n || typeof n !== 'object') return n;
    if (Array.isArray(n)) return n.map((x) => sub(x));
    if (n.type === 'Func') return n;
    if (n.type === 'Name') return !isTarget && env.has(n.name) && !escaping.has(n.name) ? lit(env.get(n.name)) : n;
    const copy = { ...n };
    for (const k of Object.keys(copy)) {
      const v = copy[k];
      if (!v || typeof v !== 'object' || k === 'line' || k === 'pos') continue;
      copy[k] = sub(v);
    }
    return copy;
  };
  return sub(node);
}

function applyStatement(st, env, escaping) {
  if (st.type === 'Assign') {
    const vals = st.values.map((v) => evalConst(v, env));
    const open = st.values.length > 0 && isMulti(st.values[st.values.length - 1]);
    st.targets.forEach((t, k) => {
      if (t.type !== 'Name') return;
      const v = k < vals.length ? vals[k] : open ? null : { type: 'Nil' };
      if (v && !escaping.has(t.name)) env.set(t.name, v); else env.delete(t.name);
    });
  }
}

const meetInto = (into, other) => {
  let changed = false;
  for (const [k, v] of [...into]) {
    const o = other.get(k);
    if (!o || o.type !== v.type || !sameLit(o, v)) { into.delete(k); changed = true; }
  }
  return changed;
};

// ---- the three steps ---------------------------------------------------------------------------------------------------------

function propagate(blocks, entry, escaping) {
  const inEnv = new Map();      // block -> Map of known constants on entry
  inEnv.set(entry, new Map());
  const work = [entry];
  const queued = new Set([entry]);
  while (work.length) {
    const n = work.shift();
    queued.delete(n);
    const b = blocks.get(n);
    const env = new Map(inEnv.get(n));
    for (const st of b.stmts) applyStatement(st, env, escaping);
    const outs = [];
    const t = b.term;
    if (t.kind === 'goto') outs.push(t.to);
    else if (t.kind === 'branch') {
      const c = knownTruth(t.cond, env);
      if (c !== null) outs.push(c ? t.t : t.f);
      else outs.push(t.t, t.f);
    }
    for (const m of outs) {
      let changed = false;
      if (!inEnv.has(m)) { inEnv.set(m, new Map(env)); changed = true; } else changed = meetInto(inEnv.get(m), env);
      if (changed && !queued.has(m)) { queued.add(m); work.push(m); }
    }
  }
  return inEnv;
}

/** Fold what is known; make known branches jumps; drop what is unreachable. */
function fold(blocks, entry, inEnv, escaping) {
  for (const [n, b] of [...blocks]) {
    if (!inEnv.has(n)) { blocks.delete(n); continue; }
    const env = new Map(inEnv.get(n));
    const stmts = [];
    for (const st of b.stmts) {
      let s = st;
      if (st.type === 'Assign') {
        s = { ...st, values: st.values.map((v) => { const sv = substituteReads(v, env, escaping); const c = evalConst(sv, env); return c ? lit(c) : sv; }) };
        s.targets = st.targets.map((t) => (t.type === 'Index' ? substituteReads(t, env, escaping) : t));
      } else if (st.type === 'CallStmt') s = substituteReads(st, env, escaping);
      applyStatement(st, env, escaping);
      stmts.push(s);
    }
    b.stmts = stmts;
    const t = b.term;
    if (t.kind === 'branch') {
      const c = knownTruth(t.cond, env);
      if (c !== null) b.term = { kind: 'goto', to: c ? t.t : t.f };
      else { b.term = { ...t, cond: substituteReads(t.cond, env, escaping) }; if (b.term.t === b.term.f) b.term = { kind: 'goto', to: b.term.t }; }
    } else if (t.kind === 'return' && t.values) b.term = { kind: 'return', values: t.values.map((v) => substituteReads(v, env, escaping)) };
  }
}

function predecessors(blocks) {
  const pred = new Map([...blocks.keys()].map((k) => [k, []]));
  for (const [n, b] of blocks) {
    const t = b.term;
    for (const m of t.kind === 'goto' ? [t.to] : t.kind === 'branch' ? [t.t, t.f] : []) if (pred.has(m)) pred.get(m).push(n);
  }
  return pred;
}

/** A block that exactly one block jumps to, by a plain goto, becomes part of that block. */
function merge(blocks, entry) {
  const successors = (t) => (t.kind === 'goto' ? [t.to] : t.kind === 'branch' ? [t.t, t.f] : []);
  // predecessors are counted once and kept up to date as blocks are absorbed: a merge hands the absorbed block's successors to the block that took it
  const pred = predecessors(blocks);
  for (const n of [...blocks.keys()]) {
    const b = blocks.get(n);
    if (!b) continue;
    while (b.term.kind === 'goto') {
      const m = b.term.to;
      if (m === n || m === entry || !blocks.has(m)) break;
      if (pred.get(m).length !== 1) break;
      const next = blocks.get(m);
      for (const st of next.stmts) b.stmts.push(st);
      b.term = next.term;
      blocks.delete(m);
      for (const s of successors(next.term)) {
        const arr = pred.get(s);
        if (arr) for (let i = 0; i < arr.length; i++) if (arr[i] === m) arr[i] = n;
      }
    }
  }
}

const termKey = (t) => (t.kind === 'goto' ? `g:${String(t.to)}` : t.kind === 'branch' ? `b:${String(t.t)}:${String(t.f)}:${structuralKey(t.cond)}` : t.kind === 'return' ? `r:${t.values ? t.values.map(structuralKey).join(',') : ''}` : null);

/**
 * Blocks that end the same way and whose last statements are the same: the shared statements move into one block they both jump to. The
 * paths of a test that were copied apart (once per value a variable could have) come back together there.
 */
function mergeTails(blocks, entry) {
  let changed = false;
  for (let again = true; again;) {
    again = false;
    const groups = new Map();
    for (const [n, b] of blocks) {
      const k = termKey(b.term);
      if (k === null) continue;
      if (!groups.has(k)) groups.set(k, []);
      groups.get(k).push(n);
    }
    for (const names of groups.values()) {
      if (names.length < 2) continue;
      for (let i = 0; i < names.length && !again; i++) for (let j = i + 1; j < names.length && !again; j++) {
        const a = blocks.get(names[i]);
        const c = blocks.get(names[j]);
        if (!a || !c) continue;
        let k = 0;
        while (k < a.stmts.length && k < c.stmts.length && structuralKey(a.stmts[a.stmts.length - 1 - k]) === structuralKey(c.stmts[c.stmts.length - 1 - k])) k++;
        // the whole of a block can be shared only when the other is exactly it; otherwise leave something behind to tell the paths apart
        if (k === 0 || (k === a.stmts.length && k === c.stmts.length)) continue;
        const id = `${String(names[i])}~${String(names[j])}`;
        if (blocks.has(id)) continue;
        blocks.set(id, { stmts: a.stmts.slice(a.stmts.length - k), term: a.term });
        a.stmts = a.stmts.slice(0, a.stmts.length - k);
        c.stmts = c.stmts.slice(0, c.stmts.length - k);
        a.term = { kind: 'goto', to: id };
        c.term = { kind: 'goto', to: id };
        again = true;
        changed = true;
      }
    }
  }
  return changed;
}

/** A branch or jump to a block that has nothing in it and only jumps on goes straight to the end of that chain. */
function skipEmpty(blocks, entry) {
  const resolve = (n) => {
    const seen = new Set();
    for (;;) {
      const b = blocks.get(n);
      if (!b || b.stmts.length || b.term.kind !== 'goto' || seen.has(n)) return n;
      seen.add(n);
      n = b.term.to;
    }
  };
  for (const b of blocks.values()) {
    const t = b.term;
    if (t.kind === 'goto') t.to = resolve(t.to);
    else if (t.kind === 'branch') { t.t = resolve(t.t); t.f = resolve(t.f); }
  }
  const e = resolve(entry);
  const pred = predecessors(blocks);
  for (const [n, b] of [...blocks]) if (n !== e && n !== entry && !pred.get(n).length) blocks.delete(n);
  return e;
}

const NO_NAMES = new Set();
/** The names a statement reads. An assignment reads its values and whatever its indexed targets are made of; its plain targets are not reads. */
function forEachUse(st, fn) {
  if (st.type === 'Assign') {
    for (const v of st.values) for (const n of namesIn(v)) fn(n);
    for (const t of st.targets) if (t.type === 'Index') for (const n of namesIn(t)) fn(n);
  } else for (const n of namesIn(st)) fn(n);
}
const termNames = (t, exitLive) => (t.kind === 'branch' ? namesIn(t.cond) : t.kind === 'return' && t.values ? namesIn(t.values) : t.kind === 'exit' && exitLive ? exitLive : NO_NAMES);
const successorsOf = (t) => (t.kind === 'goto' ? [t.to] : t.kind === 'branch' ? [t.t, t.f] : []);

/**
 * Backward liveness with the names as bit positions: what each block needs from before it. A block's own effect is summarised once (what it reads
 * before writing, what it writes), then the sets are propagated from the blocks that follow until nothing changes.
 */
function solveLiveness(blocks, exitLive) {
  const ids = new Map();
  const idOf = (n) => { let i = ids.get(n); if (i === undefined) { i = ids.size; ids.set(n, i); } return i; };
  const summary = new Map();
  for (const [k, b] of blocks) {
    const gen = new Set();
    const kill = new Set();
    for (const n of termNames(b.term, exitLive)) gen.add(idOf(n));
    for (let i = b.stmts.length - 1; i >= 0; i--) {
      const st = b.stmts[i];
      if (st.type === 'Assign') for (const t of st.targets) if (t.type === 'Name') { const id = idOf(t.name); gen.delete(id); kill.add(id); }
      forEachUse(st, (n) => gen.add(idOf(n)));
    }
    summary.set(k, { gen, kill });
  }
  const words = Math.max(1, (ids.size + 31) >>> 5);
  const bits = (set) => { const out = new Uint32Array(words); for (const i of set) out[i >>> 5] |= 1 << (i & 31); return out; };
  const gen = new Map();
  const kill = new Map();
  const liveIn = new Map();
  for (const [k, { gen: g, kill: x }] of summary) { gen.set(k, bits(g)); kill.set(k, bits(x)); liveIn.set(k, new Uint32Array(words)); }
  const pred = predecessors(blocks);
  const queue = [...blocks.keys()].reverse();
  const queued = new Set(queue);
  const out = new Uint32Array(words);
  while (queue.length) {
    const k = queue.pop();
    queued.delete(k);
    const b = blocks.get(k);
    out.fill(0);
    for (const m of successorsOf(b.term)) { const li = liveIn.get(m); if (li) for (let w = 0; w < words; w++) out[w] |= li[w]; }
    const g = gen.get(k);
    const x = kill.get(k);
    const cur = liveIn.get(k);
    let changed = false;
    for (let w = 0; w < words; w++) {
      const next = (g[w] | (out[w] & ~x[w])) >>> 0;
      if (next !== cur[w]) { cur[w] = next; changed = true; }
    }
    if (changed) for (const q of pred.get(k)) if (!queued.has(q)) { queued.add(q); queue.push(q); }
  }
  return { ids, words, liveIn, gen };
}

const bitHas = (bits, id) => (bits[id >>> 5] >>> (id & 31)) & 1;

function eliminateDead(blocks, entry, escaping, exitLive) {
  const { ids, words, liveIn } = solveLiveness(blocks, exitLive);
  let removed = 0;
  for (const [n, b] of blocks) {
    // what is needed after the block, then walked backwards through it
    const cur = new Uint32Array(words);
    for (const m of successorsOf(b.term)) { const li = liveIn.get(m); if (li) for (let w = 0; w < words; w++) cur[w] |= li[w]; }
    const live = (name) => { const id = ids.get(name); return id !== undefined && bitHas(cur, id) === 1; };
    const add = (name) => { const id = ids.get(name); if (id !== undefined) cur[id >>> 5] |= 1 << (id & 31); };
    const drop = (name) => { const id = ids.get(name); if (id !== undefined) cur[id >>> 5] &= ~(1 << (id & 31)); };
    for (const x of termNames(b.term, exitLive)) add(x);
    const kept = [];
    for (let i = b.stmts.length - 1; i >= 0; i--) {
      const st = b.stmts[i];
      let s = st;
      if (st.type === 'Assign') {
        // `r3 = r3` does nothing
        if (st.targets.length === st.values.length && st.targets.every((t, k) => t.type === 'Name' && strip(st.values[k]).type === 'Name' && strip(st.values[k]).name === t.name)) { removed++; continue; }
        const keepT = [];
        const keepV = [];
        const open = st.values.length > 0 && st.values.length < st.targets.length && isMulti(st.values[st.values.length - 1]);
        // targets fed by the results of a trailing call keep their place: only a dead tail of them can go
        let lastLive = st.targets.length - 1;
        if (open) while (lastLive >= st.values.length && (st.targets[lastLive].type === 'Name' && !live(st.targets[lastLive].name) && !escaping.has(st.targets[lastLive].name))) lastLive--;
        st.targets.forEach((t, k) => {
          if (open && k >= st.values.length - 1) {
            if (k <= lastLive) { keepT.push(t); if (k < st.values.length) keepV.push(st.values[k]); } else removed++;
            return;
          }
          const v = k < st.values.length ? st.values[k] : { type: 'Nil' };
          const dead = t.type === 'Name' && !live(t.name) && !escaping.has(t.name) && !hasCall(v);
          if (dead) removed++; else { keepT.push(t); keepV.push(v); }
        });
        if (!keepT.length) continue;
        s = keepT.length === st.targets.length ? st : { ...st, targets: keepT, values: keepV };
        for (const t of keepT) if (t.type === 'Name') drop(t.name);
      }
      forEachUse(s, add);
      kept.push(s);
    }
    b.stmts = kept.reverse();
  }
  return removed;
}

/**
 * @param {Map<any, {stmts: object[], term: object}>} blocks  changed in place
 * @param {any} entry
 * @param {{exitLive?: Set<string>, pureCalls?: Map<string, Function>, effectFree?: Set<string>}} [options]  exitLive: names that a block of kind
 *   'exit' still needs (a slice of a larger function); pureCalls: functions that may be evaluated when all their arguments are known constants;
 *   effectFree: functions whose calls do nothing but return, so a call whose result nobody reads can go
 * @returns {{entry: any, removed: number}} the entry may have moved to the end of a chain of empty blocks
 */
export function optimizeCfg(blocks, entry, options = {}) {
  const previous = [pureCalls, effectFree];
  pureCalls = options.pureCalls || null;
  effectFree = options.effectFree || null;
  try { return optimizeRounds(blocks, entry, options); } finally { [pureCalls, effectFree] = previous; }
}

function optimizeRounds(blocks, entry, options = {}) {
  const escaping = escapingNames(blocks);
  let removed = 0;
  for (let round = 0; round < 6; round++) {
    const before = blocks.size;
    const env = propagate(blocks, entry, escaping);
    fold(blocks, entry, env, escaping);
    entry = skipEmpty(blocks, entry);
    merge(blocks, entry);
    if (options.mergeTails === true && mergeTails(blocks, entry)) { entry = skipEmpty(blocks, entry); merge(blocks, entry); }
    const r = eliminateDead(blocks, entry, escaping, options.exitLive);
    removed += r;
    if (!r && blocks.size === before) break;
  }
  return { entry, removed };
}

/** Names live on entry to every block (for a graph whose `exit` blocks need nothing). */
export function liveness(blocks, exitLive) {
  const { ids, liveIn } = solveLiveness(blocks, exitLive);
  const names = [...ids.keys()];
  const out = new Map();
  for (const [k, bits] of liveIn) {
    const set = new Set();
    for (let w = 0; w < bits.length; w++) {
      let x = bits[w];
      while (x) { const low = x & -x; set.add(names[(w << 5) + (31 - Math.clz32(low))]); x ^= low; }
    }
    out.set(k, set);
  }
  return out;
}

/** For every block that ends the graph (`exit`), the constants known at its end. Reaches only blocks a known test can reach. */
export function exitEnvs(blocks, entry) {
  const escaping = escapingNames(blocks);
  const inEnv = propagate(blocks, entry, escaping);
  const out = new Map();
  for (const [n, b] of blocks) {
    if (b.term.kind !== 'exit' || !inEnv.has(n)) continue;
    const env = new Map(inEnv.get(n));
    for (const st of b.stmts) applyStatement(st, env, escaping);
    out.set(n, env);
  }
  return out;
}
