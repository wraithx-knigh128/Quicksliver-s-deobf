// MoonVeil's control-flow flattening, taken apart statically.
//
// A flattened function keeps its locals, then one state variable and one loop whose body is a decision tree on that variable:
//
//     local num = 60
//     while true do
//       if num > 176 then
//         if num <= 181 then  <block>  num = v1 > v4 and 176 or 221
//         else                <block>  num = v5 ~= v5 and 388 - num or 58 end
//       elseif ...
//
// Every leaf is a run of plain assignments and calls that ends by writing the next state, either as arithmetic on the current one
// (`num + -48`, `388 - num`, `28084 / num`) or as a choice (`cond and A or B`) whose condition is a real test on the program's own
// variables or an opaque one (`v ~= v`, which no number satisfies). So a state number plus the leaf it selects fully determine the
// successor, and the graph can be walked without running anything: start at the initial state, pick the leaf the tree selects for the
// concrete number, evaluate its write to the state variable, follow every real branch.
//
// The result is a graph of blocks, which is what src/decompile/cfg.js turns back into if / while. Nothing here guesses: a leaf that is
// not a straight run of assignments and calls, a transition that is not arithmetic on literals or `cond and A or B`, a tree that does not
// compare the state with numbers, or an edge into a state the tree has no leaf for, leaves the function exactly as it was.

import { walk } from '../core/walk.js';
import { structure, CfgError } from '../decompile/cfg.js';
import { optimizeCfg } from './cfg-opt.js';

class Bail extends Error {}
const bail = (why) => { throw new Bail(why); };

const num = (value) => ({ type: 'Number', value, raw: null });
const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const isFalse = (e) => e.type === 'False';
const isTrue = (e) => e.type === 'True';
const CMP = new Set(['<', '<=', '>', '>=', '==', '~=']);

// ---- the decision tree ------------------------------------------------------------------------------------------------

/** `state op number` or `number op state`, as [op, number] with the state on the left. */
function stateTest(cond, S) {
  const c = strip(cond);
  if (!c || c.type !== 'Binary' || !CMP.has(c.op)) return null;
  const l = strip(c.left);
  const r = strip(c.right);
  if (l.type === 'Name' && l.name === S && r.type === 'Number') return [c.op, r.value];
  if (r.type === 'Name' && r.name === S && l.type === 'Number') return [{ '<': '>', '<=': '>=', '>': '<', '>=': '<=', '==': '==', '~=': '~=' }[c.op], l.value];
  return null;
}

const holds = (op, a, b) => (op === '<' ? a < b : op === '<=' ? a <= b : op === '>' ? a > b : op === '>=' ? a >= b : op === '==' ? a === b : a !== b);
const isTree = (ifs, S) => ifs.type === 'If' && ifs.clauses.length > 0 && stateTest(ifs.clauses[0].cond, S) !== null;

/** The statements the tree selects for a concrete state. */
function leafFor(tree, S, s) {
  let node = tree;
  for (;;) {
    let body = null;
    for (const clause of node.clauses) {
      const t = stateTest(clause.cond, S);
      if (!t) bail('a branch of the tree does not test the state against a number');
      if (holds(t[0], s, t[1])) { body = clause.body; break; }
    }
    if (!body) body = node.orelse;
    if (!body) bail(`no leaf for state ${s}`);
    if (body.length === 1 && isTree(body[0], S)) { node = body[0]; continue; }
    return body;
  }
}

// ---- what a leaf writes to the state ---------------------------------------------------------------------------------

/** A statically known truth value, or null when the test depends on the program's own data. */
function staticTruth(cond, consts) {
  const c = strip(cond);
  if (isTrue(c)) return true;
  if (isFalse(c) || c.type === 'Nil') return false;
  if (c.type === 'Unary' && c.op === 'not') { const t = staticTruth(c.arg, consts); return t === null ? null : !t; }
  if (c.type === 'Binary' && CMP.has(c.op)) {
    const l = strip(c.left);
    const r = strip(c.right);
    // v ~= v and v == v on a plain name: no number differs from itself (the opaque predicate MoonVeil uses)
    if (l.type === 'Name' && r.type === 'Name' && l.name === r.name) {
      if (c.op === '~=' || c.op === '<' || c.op === '>') return false;
      return true;
    }
    const a = known(l, consts);
    const b = known(r, consts);
    if (a !== undefined && b !== undefined && typeof a === 'number' && typeof b === 'number') return holds(c.op, a, b);
  }
  return null;
}

function known(e, consts) {
  e = strip(e);
  if (e.type === 'Number') return e.value;
  if (e.type === 'Name' && consts.has(e.name)) { const v = consts.get(e.name); return v.type === 'Number' ? v.value : undefined; }
  if (e.type === 'Unary' && e.op === '-') { const v = known(e.arg, consts); return typeof v === 'number' ? -v : undefined; }
  return undefined;
}

/** The expression with the state and the names that hold literals replaced by those literals. */
function substitute(e, S, s, consts) {
  const sub = (n) => {
    if (!n || typeof n !== 'object') return n;
    if (Array.isArray(n)) return n.map(sub);
    if (n.type === 'Name') {
      if (n.name === S) return num(s);
      if (consts.has(n.name)) return { ...consts.get(n.name) };
      return { ...n };
    }
    const copy = { ...n };
    for (const k of Object.keys(copy)) if (k !== 'line' && k !== 'pos' && typeof copy[k] === 'object' && copy[k] !== null) copy[k] = sub(copy[k]);
    return copy;
  };
  return sub(e);
}

/** Trans = { k: 'to', state } | { k: 'branch', cond, t: Trans, f: Trans } */
function transition(e, S, s, consts) {
  e = strip(e);
  const val = (x) => {
    const v = valueOf(x, S, s, consts);
    return v;
  };
  if (e.type === 'Binary' && e.op === 'or') {
    const l = strip(e.left);
    if (l.type === 'Binary' && l.op === 'and') {
      const truth = staticTruth(l.left, consts);
      if (truth === true) return transition(l.right, S, s, consts);
      if (truth === false) return transition(e.right, S, s, consts);
      const t = tryTransition(l.right, S, s, consts);
      const f = tryTransition(e.right, S, s, consts);
      if (!t && !f) bail('neither arm of a state choice is a state');
      if (!t) return f;
      if (!f) return t;
      return { k: 'branch', cond: substitute(l.left, S, s, consts), t, f };
    }
    return transition(e.left, S, s, consts);
  }
  const v = val(e);
  if (v === undefined) bail('a state write is neither arithmetic on literals nor a choice');
  return { k: 'to', state: v };
}

/** Like transition(), but an arm whose number is not a whole number (a division that does not come out) is a dead arm: null. */
function tryTransition(e, S, s, consts) {
  try {
    const t = transition(e, S, s, consts);
    return t;
  } catch (err) {
    if (err instanceof Bail && /not a whole number/.test(err.message)) return null;
    throw err;
  }
}

function valueOf(e, S, s, consts) {
  e = strip(e);
  switch (e.type) {
    case 'Number': return e.value;
    case 'Name': return e.name === S ? s : consts.has(e.name) && consts.get(e.name).type === 'Number' ? consts.get(e.name).value : undefined;
    case 'Unary': { if (e.op !== '-') return undefined; const v = valueOf(e.arg, S, s, consts); return v === undefined ? undefined : -v; }
    case 'Binary': {
      if (!['+', '-', '*', '/', '%'].includes(e.op)) return undefined;
      const a = valueOf(e.left, S, s, consts);
      const b = valueOf(e.right, S, s, consts);
      if (a === undefined || b === undefined) return undefined;
      const r = e.op === '+' ? a + b : e.op === '-' ? a - b : e.op === '*' ? a * b : e.op === '/' ? a / b : a - Math.floor(a / b) * b;
      if (!Number.isInteger(r)) bail(`state ${r} is not a whole number`);
      return r;
    }
    default: return undefined;
  }
}

// ---- reading a leaf -----------------------------------------------------------------------------------------------------

const assignedNames = (stmt) => (stmt.type === 'Assign' ? stmt.targets.filter((t) => t.type === 'Name').map((t) => t.name) : stmt.type === 'Local' ? stmt.ids.map((i) => i.name) : []);

function namesRead(e) {
  const out = new Set();
  walk(e, (n) => { if (n.type === 'Name') out.add(n.name); });
  return out;
}

const literal = (e) => { e = strip(e); return e.type === 'Number' || e.type === 'String' ? e : null; };

/**
 * @returns {{stmts: object[], term: object, temps: string[]}} the leaf without its write to the state, and how it continues.
 */
function readLeaf(stmts, S, s, ctx) {
  const consts = new Map();
  const out = [];
  let trans = null;
  let hoistAt = -1;
  let hazard = new Set();
  let wrote = false;
  let ret = null;

  stmts.forEach((st, idx) => {
    if (st.type === 'Return') { ret = st; return; }
    if (st.type === 'CallStmt') { out.push(st); return; }
    if (st.type !== 'Assign') bail(`a leaf holds a ${st.type}`);
    const keepT = [];
    const keepV = [];
    const sIdx = st.targets.findIndex((t) => t.type === 'Name' && t.name === S);
    if (sIdx >= 0) {
      if (sIdx >= st.values.length) bail('the state is written from a multiple-result call');
      if (wrote) bail('the state is written twice in one leaf');
      wrote = true;
      trans = transition(st.values[sIdx], S, s, consts);
      hoistAt = out.length;
    }
    // a call or `...` last in the list supplies every target the values before it leave over: those targets take no value of their own
    const lastValue = st.values.length ? st.values[st.values.length - 1] : null;
    const openTail = !!lastValue && st.values.length < st.targets.length && ['Call', 'MethodCall', 'Vararg'].includes(lastValue.type);
    st.targets.forEach((t, k) => {
      if (k === sIdx) return;
      keepT.push(t);
      if (k < st.values.length) keepV.push(st.values[k]);
      else if (!openTail) keepV.push({ type: 'Nil' });
    });
    // extra values past the last target are still evaluated by Lua, but the compiler never writes them
    if (sIdx >= 0) {
      for (const t of keepT) if (t.type === 'Name') hazard.add(t.name);
    }
    // constants known after this statement
    keepT.forEach((t, k) => {
      if (t.type !== 'Name') return;
      const lit = k < keepV.length ? literal(keepV[k]) : null;
      if (lit) consts.set(t.name, lit); else consts.delete(t.name);
    });
    if (keepT.length) out.push({ ...st, targets: keepT, values: keepV });
    if (sIdx >= 0) hazard = new Set([...hazard]);
    else for (const n of assignedNames(st)) if (wrote) hazard.add(n);
  });

  if (ret) return { stmts: out, term: { kind: 'return', values: ret.values.length ? ret.values : null }, temps: [] };
  if (!trans) bail('a leaf neither writes the state nor returns');

  // a condition is evaluated where the state is written; if the block changes one of its variables afterwards, keep its value in a temporary
  const temps = [];
  const fix = (t) => {
    if (t.k === 'to') return t;
    const read = namesRead(t.cond);
    let cond = t.cond;
    if ([...read].some((n) => hazard.has(n))) {
      const name = `cond${ctx.nextTemp++}`;
      temps.push(name);
      out.splice(hoistAt, 0, { type: 'Assign', targets: [{ type: 'Name', name }], values: [cond] });
      hoistAt++;
      cond = { type: 'Name', name };
    }
    return { k: 'branch', cond, t: fix(t.t), f: fix(t.f) };
  };
  return { stmts: out, term: fix(trans), temps };
}

// ---- one function ---------------------------------------------------------------------------------------------------------

const isLoop = (s) => (s.type === 'Repeat' && isFalse(s.cond)) || (s.type === 'While' && isTrue(s.cond));
const negate = (c) => (c.type === 'Unary' && c.op === 'not' ? c.arg : { type: 'Unary', op: 'not', arg: c.type === 'Binary' ? { type: 'Paren', expr: c } : c });

function flattenedLoop(f) {
  const body = f.body;
  const li = body.length - 1;
  if (li < 0 || !isLoop(body[li])) return null;
  const loop = body[li];
  if (loop.body.length !== 1 || loop.body[0].type !== 'If') return null;
  const tree = loop.body[0];
  // the state is the name the first test compares with a number
  const c = strip(tree.clauses[0].cond);
  if (!c || c.type !== 'Binary' || !CMP.has(c.op)) return null;
  const l = strip(c.left);
  const r = strip(c.right);
  const S = l.type === 'Name' && r.type === 'Number' ? l.name : r.type === 'Name' && l.type === 'Number' ? r.name : null;
  if (!S || !isTree(tree, S)) return null;
  return { tree, S, li };
}

/** Where the state starts: `local S = number`, either alone or among other names. */
function initialState(body, S, upTo) {
  for (let i = 0; i < upTo; i++) {
    const st = body[i];
    if (st.type === 'Local') {
      const k = st.ids.findIndex((id) => id.name === S);
      if (k < 0) continue;
      const v = k < st.values.length ? strip(st.values[k]) : null;
      // declared bare, the start is the plain assignment that follows (`local j; j = 0x3a`)
      if (!v) continue;
      if (v.type !== 'Number') return null;
      return { index: i, k, state: v.value, kind: 'local' };
    }
    if (st.type === 'Assign') {
      const k = st.targets.findIndex((t) => t.type === 'Name' && t.name === S);
      if (k < 0) continue;
      const v = k < st.values.length ? strip(st.values[k]) : null;
      if (!v || v.type !== 'Number') return null;
      return { index: i, k, state: v.value, kind: 'assign' };
    }
  }
  return null;
}

/**
 * The block graph of a flattened function, cleaned (constants, dead stores, dead edges).
 * @returns {{blocks: Map<any, {stmts: object[], term: object}>, entry: any, head: object[], temps: string[], init: object, li: number} | null}
 */
export function flattenedGraph(f, ctx = { nextTemp: 1, gotoFallback: false, gotoForm: 0 }) {
  const found = flattenedLoop(f);
  if (!found) return null;
  const { tree, S, li } = found;
  const init = initialState(f.body, S, li);
  if (!init) return null;

  const blocks = new Map();
  const queue = [init.state];
  const temps = [];
  let synthetic = 0;
  const target = (t) => {
    if (t.k === 'to') { if (!blocks.has(t.state) && !queue.includes(t.state)) queue.push(t.state); return t.state; }
    const id = `b${synthetic++}`;
    blocks.set(id, { stmts: [], term: { kind: 'branch', cond: t.cond, t: target(t.t), f: target(t.f) } });
    return id;
  };
  let guard = 0;
  while (queue.length) {
    const s = queue.shift();
    if (blocks.has(s)) continue;
    if (++guard > 40000) bail('too many states');
    const leaf = readLeaf(leafFor(tree, S, s), S, s, ctx);
    temps.push(...leaf.temps);
    if (leaf.term.kind === 'return') { blocks.set(s, { stmts: leaf.stmts, term: leaf.term }); continue; }
    const t = leaf.term;
    // reserve the slot first: a block may lead back to itself
    const block = { stmts: leaf.stmts, term: null };
    blocks.set(s, block);
    block.term = t.k === 'to' ? { kind: 'goto', to: target(t) } : { kind: 'branch', cond: t.cond, t: target(t.t), f: target(t.f) };
  }

  // constants, dead stores and dead edges out first: they are what makes a flattened graph look irreducible
  const { entry } = optimizeCfg(blocks, init.state);
  return { blocks, entry, temps, init, li };
}

function unflattenFunction(f, ctx) {
  const g = flattenedGraph(f, ctx);
  if (!g) return 0;
  const { blocks, entry, temps, init, li } = g;
  let body;
  let gotoForm = false;
  try {
    body = structure(blocks, entry, { negate, makeReturn: (values) => ({ type: 'Return', values: values || [] }) });
  } catch (err) {
    if (!(err instanceof CfgError)) throw err;
    // a graph the structurer will not guess at: the blocks in order, joined by labels and gotos (Lua 5.2+ and LuaJIT 2.1 read this form)
    if (!ctx.gotoFallback) bail(`the block graph cannot be structured: ${err.message}`);
    body = gotoBlocks(blocks, entry);
    gotoForm = true;
  }
  if (gotoForm) ctx.gotoForm++;

  // the declarations stay; the state variable and the loop go
  const head = f.body.slice(0, li).map((st, i) => {
    if (i !== init.index) return st;
    if (init.kind === 'assign') {
      const targets = st.targets.filter((_, k) => k !== init.k);
      const values = st.values.filter((_, k) => k !== init.k);
      return targets.length ? { ...st, targets, values } : null;
    }
    const ids = st.ids.filter((_, k) => k !== init.k);
    const values = st.values.filter((_, k) => k !== init.k);
    return ids.length ? { ...st, ids, values } : null;
  }).filter(Boolean);
  if (temps.length) head.push({ type: 'Local', ids: temps.map((name) => ({ type: 'Id', name })), values: [] });
  f.body = [...head, ...body];
  return blocks.size;
}

/** Blocks in reverse post-order, a label on each that is jumped to from anywhere but the block before it. */
export function gotoBlocks(blocks, entry) {
  const order = [];
  const seen = new Set();
  const succ = (b) => (b.term.kind === 'goto' ? [b.term.to] : b.term.kind === 'branch' ? [b.term.t, b.term.f] : []);
  const visit = (n) => {
    const stack = [[n, 0]];
    seen.add(n);
    while (stack.length) {
      const top = stack[stack.length - 1];
      const nexts = succ(blocks.get(top[0]));
      if (top[1] < nexts.length) {
        const m = nexts[top[1]++];
        if (!seen.has(m)) { seen.add(m); stack.push([m, 0]); }
      } else { order.push(top[0]); stack.pop(); }
    }
  };
  visit(entry);
  order.reverse();
  const labelOf = new Map(order.map((n, i) => [n, `L${i}`]));
  const pos = new Map(order.map((n, i) => [n, i]));
  const used = new Set();
  const jump = (n) => { used.add(n); return { type: 'Goto', label: labelOf.get(n) }; };
  const out = [];
  order.forEach((n, i) => {
    const b = blocks.get(n);
    const next = order[i + 1];
    const body = [{ type: 'Label', name: labelOf.get(n), _n: n }, ...b.stmts];
    const t = b.term;
    if (t.kind === 'return') body.push({ type: 'Do', body: [{ type: 'Return', values: t.values || [] }] });
    else if (t.kind === 'goto') { if (t.to !== next) body.push(jump(t.to)); }
    else if (t.kind === 'branch') {
      if (t.f === next) body.push({ type: 'If', clauses: [{ cond: t.cond, body: [jump(t.t)] }], orelse: null });
      else if (t.t === next) body.push({ type: 'If', clauses: [{ cond: negate(t.cond), body: [jump(t.f)] }], orelse: null });
      else body.push({ type: 'If', clauses: [{ cond: t.cond, body: [jump(t.t)] }], orelse: null }, jump(t.f));
    }
    out.push(...body);
  });
  void pos;
  return out.filter((st) => st.type !== 'Label' || used.has(st._n) || st._n === entry).map((st) => (st.type === 'Label' ? { type: 'Label', name: st.name } : st));
}

/**
 * Unflatten every function of the chunk that MoonVeil flattened. A function that is not understood is left alone and listed in `notUnderstood`.
 * @returns {{changed: number, functions: number, notUnderstood: string[], gotoForm: number}}
 */
export function unflattenMoonVeil(chunk, options = {}) {
  const funcs = [];
  walk(chunk, (n) => { if (n.type === 'Func') funcs.push(n); });
  const ctx = { nextTemp: 1, gotoFallback: !!options.gotoFallback, gotoForm: 0 };
  let changed = 0;
  let functions = 0;
  const notUnderstood = [];
  for (const f of funcs) {
    if (options.skip && options.skip(f)) continue;
    const saved = f.body;
    try {
      const n = unflattenFunction(f, ctx);
      if (n) { changed += n; functions++; }
    } catch (err) {
      f.body = saved;
      if (!(err instanceof Bail)) throw err;
      notUnderstood.push(err.message);
    }
  }
  return { changed, functions, notUnderstood, gotoForm: ctx.gotoForm };
}
