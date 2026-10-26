// Dispatch loops: control flow flattened into a loop that selects its next block by a state variable.
//
//     local s = 7
//     while true do
//       if s == 7 then  <block A>  s = 3
//       elseif s == 3 then  <block B>  if cond then s = 9 else s = 12 end
//       elseif s == 9 then  <block C>  break
//       ...
//
// Nothing here knows who wrote the loop. The state is whichever variable the selection tests, the selection is read by evaluating its
// conditions for a concrete state, and the successor of a block is read by evaluating what the block writes to the state. Starting at the
// initial state and following only what can happen gives the blocks that exist (blocks no state ever reaches are junk and simply do not
// come out); the graph is then structured back into if / while by src/decompile/cfg.js. What is understood is rebuilt, what is not is left
// exactly as it was and the reason is listed:
//
//   * the selection tests the state against constants only (equality, ranges, any arithmetic: it is evaluated, not pattern-matched);
//   * a block writes the state with an expression that can be evaluated for the current state, possibly as a choice (`c and A or B`,
//     `if c then s = A else s = B end`) whose condition is the program's own;
//   * the state is not read by anything else, before or after.
//
// Sequential selections (`if s == 1 then ... s = 2 end  if s == 2 then ...`) fall out of the same walk, because the state is followed
// through the body as it is executed. A state that is computed from the program's data is refused: it cannot be read without running it.

import { walk, clone } from '../../core/walk.js';
import { structure, CfgError } from '../../decompile/cfg.js';
import { analyse } from '../analysis.js';
import { NOT_CONST } from '../concrete.js';
import { strip, num, str, writesName, lineOf, sizeOf } from '../util.js';

class Bail extends Error {}
const bail = (why) => { throw new Bail(why); };

const MAX_STATES = 4000;
const MAX_NODES = 80000;
const LOOPS = new Set(['While', 'Repeat', 'NumFor', 'GenFor']);

const keyOf = (v) => `${typeof v}:${String(v)}`;
const valueNode = (v) => (typeof v === 'number' ? (v < 0 || Object.is(v, -0) ? { type: 'Unary', op: '-', arg: num(-v) } : num(v)) : typeof v === 'string' ? str(v) : v === true ? { type: 'True' } : v === false ? { type: 'False' } : { type: 'Nil' });
const truthy = (v) => v !== undefined && v !== false;

const hasCall = (node) => { let hit = false; walk(node, (n) => { if (n.type === 'Call' || n.type === 'MethodCall') hit = true; return hit ? false : undefined; }); return hit; };
const declares = (body) => body.some((x) => x.type === 'Local' || x.type === 'LocalFunction');

/** Is there a `break` or `continue` of this loop below `node`, not inside a loop or function of its own? */
function jumpsOut(node) {
  let hit = false;
  const visit = (n) => {
    if (hit || !n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(visit); return; }
    if (n.type === 'Func') return;
    if (n.type === 'Break' || n.type === 'Continue') { hit = true; return; }
    if (LOOPS.has(n.type)) return;
    if (n.type === 'If') { n.clauses.forEach((c) => visit(c.body)); if (n.orelse) visit(n.orelse); return; }
    if (n.type === 'Do') visit(n.body);
  };
  visit(node);
  return hit;
}

/** Does the statement list end its path (the last statement leaves for good)? */
const ends = (body) => { const last = body[body.length - 1]; return !!last && (last.type === 'Return' || last.type === 'Break' || last.type === 'Continue'); };

// ---- what depends on the state ----------------------------------------------------------------------------------------------

class Model {
  constructor(ctx, state) { this.ctx = ctx; this.state = state; }

  varOf(n) { return this.ctx.info.varOf.get(n); }

  /** Does `node` mention the state (reads or writes, closures included)? */
  mentions(node) {
    let hit = false;
    walk(node, (n) => { if (n.type === 'Name' && this.varOf(n) === this.state) hit = true; return hit ? false : undefined; });
    return hit;
  }

  /** Does `node` assign the state? */
  writes(node) {
    let hit = false;
    walk(node, (n) => {
      if (n.type === 'Assign') { if (n.targets.some((t) => t.type === 'Name' && this.varOf(t) === this.state)) hit = true; }
      else if (n.type === 'CompoundAssign') { if (n.target.type === 'Name' && this.varOf(n.target) === this.state) hit = true; }
      return hit ? false : undefined;
    });
    return hit;
  }

  /** Does the expression depend on nothing but the state and constants (and does it mention the state)? */
  stateOnly(e) {
    let ok = true;
    let saw = false;
    walk(e, (n) => {
      if (!ok) return false;
      if (n.type === 'Name') {
        const v = this.varOf(n);
        if (v === this.state) saw = true;
        else if (!v || this.ctx.constant(v) === NOT_CONST) ok = false;
      } else if (n.type === 'Call' || n.type === 'MethodCall' || n.type === 'Func' || n.type === 'Vararg') ok = false;
      return ok ? undefined : false;
    });
    return ok && saw;
  }

  /** Does the expression depend on constants only (no state, no program data)? */
  fixed(e) {
    let ok = true;
    walk(e, (n) => {
      if (!ok) return false;
      if (n.type === 'Name') { const v = this.varOf(n); if (!v || v === this.state || this.ctx.constant(v) === NOT_CONST) ok = false; }
      else if (n.type === 'Call' || n.type === 'MethodCall' || n.type === 'Func' || n.type === 'Vararg') ok = false;
      return ok ? undefined : false;
    });
    return ok;
  }

  /** The value of a state-only or fixed expression for the state `s`, or NOT_CONST. */
  value(e, s) {
    const v = this.ctx.evalExpr(e, new Map([[this.state, s]]));
    return v !== null && typeof v === 'object' ? NOT_CONST : v;
  }

  /** A copy of the node with every read of the state replaced by the constant it holds. */
  substitute(node, s) {
    const value = valueNode(s);
    const sub = (n) => {
      if (!n || typeof n !== 'object') return n;
      if (Array.isArray(n)) return n.map(sub);
      if (n.type === 'Name' && this.varOf(n) === this.state) return { ...value };
      const copy = { ...n };
      for (const k of Object.keys(copy)) if (k !== 'line' && k !== 'pos' && k !== 'comments' && k !== 'trailing' && copy[k] && typeof copy[k] === 'object') copy[k] = sub(copy[k]);
      return copy;
    };
    return sub(node);
  }
}

/** The variable a selection If tests: the one non-constant name of its first condition, when that condition depends on nothing else. */
function selectorOf(ifs, ctx) {
  const first = ifs.clauses[0].cond;
  const vars = new Set();
  let ok = true;
  walk(first, (n) => {
    if (n.type === 'Name') {
      const v = ctx.info.varOf.get(n);
      if (!v) ok = false; else if (ctx.constant(v) === NOT_CONST) vars.add(v);
    } else if (n.type === 'Call' || n.type === 'MethodCall' || n.type === 'Func' || n.type === 'Index') ok = false;
  });
  if (!ok || vars.size !== 1) return null;
  const [state] = [...vars];
  return new Model(ctx, state).stateOnly(first) ? state : null;
}

/**
 * The state of a loop: the variable its top-level `if` statements select on. Several statements on one variable are a sequential
 * selection; their branches are the leaves, and most of them must hand control on by writing the state for this to count as a dispatcher.
 */
function findState(loop, ctx) {
  const groups = new Map();
  // the loop is driven by the state alone: it never ends, or it ends by a test of the state. A loop that walks through data (a `for`, a
  // `while i <= n`) with a state machine inside is a program that consumes input, not a flattened one
  const driven = (state) => {
    const c = strip(loop.cond);
    if (loop.type === 'While') return c.type === 'True' || c.type === 'Number' || new Model(ctx, state).stateOnly(c);
    return c.type === 'False' || new Model(ctx, state).stateOnly(c);
  };
  for (const st of loop.body) {
    if (st.type !== 'If') continue;
    const v = selectorOf(st, ctx);
    if (v) { if (!groups.has(v)) groups.set(v, []); groups.get(v).push(st); }
  }
  let best = null;
  for (const [state, ifs] of groups) {
    const m = new Model(ctx, state);
    const leaves = [];
    const collect = (node, depth) => {
      if (depth > 16) return;
      for (const body of [...node.clauses.map((c) => c.body), node.orelse || []]) {
        const nested = body.length === 1 && body[0].type === 'If' && m.stateOnly(body[0].clauses[0].cond);
        if (nested) collect(body[0], depth + 1); else leaves.push(body);
      }
    };
    ifs.forEach((x) => collect(x, 0));
    const real = leaves.filter((b) => b.length);
    if (real.length < 3) continue;
    const writing = real.filter((b) => b.some((x) => m.writes(x))).length;
    if (writing < Math.ceil(real.length * 0.6)) continue;
    if (!driven(state)) continue;
    // nothing besides the selection may steer the loop: a statement that can leave it, or that reads the state, makes the state part of the
    // program's own logic (a machine that consumes input) and not a disguise for its control flow
    const selections = new Set(ifs);
    if (loop.body.some((st) => !selections.has(st) && (jumpsOut(st) || m.mentions(st)))) continue;
    if (!best || real.length > best.leaves) best = { state, leaves: real.length, writing };
  }
  return best;
}

/** Describe a dispatch loop without changing anything (for the observer). */
export function describeDispatch(loop, ctx) {
  if (loop.type !== 'While' && loop.type !== 'Repeat') return null;
  const f = findState(loop, ctx);
  return f ? { name: f.state.name, leaves: f.leaves, writing: f.writing, line: lineOf(loop) } : null;
}

// ---- following a body for a concrete state ----------------------------------------------------------------------------------

/**
 * End of a path through the body:
 *   { k: 'to', value }          the loop goes round with this state
 *   { k: 'exit' }               the loop is left
 *   { k: 'ret', stmt }          the function returns
 *   { k: 'if', cond, t, f }     the program's own condition decides; t and f are Seq
 * Seq = { stmts, end }
 */
class Walker {
  constructor(ctx, model) { this.ctx = ctx; this.m = model; this.nodes = 0; }

  seq(stmts, s) {
    const out = [];
    const list = stmts.slice();
    for (let i = 0; i < list.length; i++) {
      if ((this.nodes += 1) > MAX_NODES) bail('the body expands past the size limit');
      const st = list[i];
      const rest = () => list.slice(i + 1);
      if (st.type === 'Break') return { stmts: out, end: { k: 'exit' } };
      if (st.type === 'Continue') return { stmts: out, end: { k: 'to', value: s, head: true } };
      if (st.type === 'Return') {
        if (this.m.mentions(st)) bail('a return reads the state');
        return { stmts: out, end: { k: 'ret', stmt: st } };
      }
      if ((st.type === 'Assign' || st.type === 'CompoundAssign') && this.m.writes(st)) {
        const w = this.write(st, s, out, rest());
        if (w.done) return w.done;
        s = w.s;
        continue;
      }
      if (st.type === 'If') {
        if (this.m.stateOnly(st.clauses[0].cond)) {
          let chosen = null;
          for (const c of st.clauses) {
            if (!this.m.stateOnly(c.cond)) bail('a clause of the selection tests something besides the state');
            const v = this.m.value(c.cond, s);
            if (v === NOT_CONST) bail('a clause of the selection cannot be evaluated for a concrete state');
            if (truthy(v)) { chosen = c.body; break; }
          }
          list.splice(i, 1, ...(chosen || st.orelse || []));
          i--;
          continue;
        }
        if (this.m.writes(st) || jumpsOut(st)) { const r = this.fork(st, s, out, rest()); return r; }
        out.push(this.plain(st, s));
        continue;
      }
      if (st.type === 'Do' && (this.m.writes(st) || jumpsOut(st))) {
        if (declares(st.body)) bail('a block that writes the state declares locals');
        list.splice(i, 1, ...st.body);
        i--;
        continue;
      }
      out.push(this.plain(st, s));
    }
    return { stmts: out, end: { k: 'to', value: s } };
  }

  /** A statement that does not write the state: its reads of the state become the constant it holds. */
  plain(st, s) {
    if (!this.m.mentions(st)) return st;
    let closure = false;
    walk(st, (n) => { if (n.type === 'Func' && this.m.mentions(n)) closure = true; return closure ? false : undefined; });
    if (closure) bail('a closure reads the state');
    return this.m.substitute(st, s);
  }

  /** `S = e` (or `S op= e`). @returns {{s}} the state afterwards, or {done} a finished Seq when the write is a choice. */
  write(st, s, out, rest) {
    let valueExpr;
    let others = null;
    if (st.type === 'CompoundAssign') {
      if (st.target.type !== 'Name') bail('a compound assignment writes the state through a field');
      valueExpr = { type: 'Binary', op: st.op, left: st.target, right: st.value };
    } else {
      const k = st.targets.findIndex((t) => t.type === 'Name' && this.m.varOf(t) === this.m.state);
      if (k < 0) bail('the state is written through an unusual target');
      if (k >= st.values.length) bail('the state is written from a multiple-result call');
      if (st.values.length > st.targets.length) bail('an assignment to the state carries more values than targets');
      const last = st.values[st.values.length - 1];
      const openTail = st.values.length < st.targets.length && ['Call', 'MethodCall', 'Vararg'].includes(last.type);
      valueExpr = st.values[k];
      const keepT = [];
      const keepV = [];
      st.targets.forEach((t, j) => {
        if (j === k) return;
        keepT.push(t);
        if (j < st.values.length) keepV.push(st.values[j]);
        else if (!openTail) keepV.push({ type: 'Nil' });
      });
      others = keepT.length ? { ...st, targets: keepT, values: keepV } : null;
    }
    const t = this.transition(valueExpr, s);
    // the next state is read out of constants; a call may sit in the condition that picks between them, but not beside it in the same statement
    if (others && hasCall(others) && t.k === 'c' && hasCall(valueExpr)) bail('a statement evaluates calls on both sides of a conditional write of the state');
    if (others) {
      if (this.m.mentions(others)) bail('a statement assigns the state and reads it at once');
      out.push(others);
    }
    if (t.k === 'v') return { s: t.v };
    // a choice: the program's own condition decides what the state becomes
    if (!rest.length) return { done: { stmts: out, end: this.choice(t) } };
    if (rest.some((x) => this.m.mentions(x))) {
      // what follows reads the state (the next of several sequential selections): follow it for each value the state can take
      const follow = (c) => (c.k === 'v' ? this.seq(rest, c.v) : { stmts: [], end: { k: 'if', cond: c.cond, t: follow(c.t), f: follow(c.f) } });
      const tree = follow(t);
      return { done: { stmts: [...out, ...tree.stmts], end: tree.end } };
    }
    // what follows does not depend on the state: it runs first and the decision is taken at the end, on a copy of the condition if the
    // code in between could change what the condition reads
    const after = this.seq(rest, null);
    if (after.end.k !== 'to') bail('a path both chooses the next state and leaves');
    const names = new Set();
    walk(t.cond, (n) => { if (n.type === 'Name') names.add(n.name); });
    const hazard = rest.some((x) => hasCall(x) || [...names].some((nm) => writesName(x, nm)));
    const pre = [];
    let cond = t.cond;
    if (hazard) {
      const tmp = this.ctx.fresh('cond');
      pre.push({ type: 'Local', ids: [{ type: 'Id', name: tmp }], values: [t.cond] });
      cond = { type: 'Name', name: tmp };
    }
    return { done: { stmts: [...out, ...pre, ...after.stmts], end: this.choice({ ...t, cond }) } };
  }

  choice(t) { return { k: 'if', cond: t.cond, t: this.arm(t.t), f: this.arm(t.f) }; }
  arm(t) { return t.k === 'v' ? { stmts: [], end: { k: 'to', value: t.v } } : { stmts: [], end: this.choice(t) }; }

  /** What an expression assigned to the state is: a value for the current state, or a choice between two such. */
  transition(e, s) {
    const x = strip(e);
    if (this.m.stateOnly(x) || this.m.fixed(x)) {
      const v = this.m.value(x, s);
      if (v !== NOT_CONST) return { k: 'v', v };
      bail('the next state cannot be evaluated');
    }
    if (x.type === 'Binary' && x.op === 'or') {
      const l = strip(x.left);
      if (l.type === 'Binary' && l.op === 'and') return this.pick(l.left, () => this.transition(l.right, s), () => this.transition(x.right, s), s);
    }
    if (x.type === 'IfExpr') return this.pick(x.cond, () => this.transition(x.then, s), () => this.transition(x.orelse, s), s);
    return bail('the next state is computed from the program’s data');
  }

  pick(cond, yes, no, s) {
    if (this.m.stateOnly(cond) || this.m.fixed(cond)) {
      const v = this.m.value(cond, s);
      if (v !== NOT_CONST) return truthy(v) ? yes() : no();
    }
    const expr = this.m.mentions(cond) ? this.m.substitute(cond, s) : cond;
    return { k: 'c', cond: expr, t: yes(), f: no() };
  }

  /** A statement that sometimes writes the state and sometimes leaves the loop: every path through it is followed. */
  fork(st, s, out, rest) {
    for (const c of st.clauses) if (this.m.mentions(c.cond)) bail('a conditional write tests the state and program data together');
    const bodies = [...st.clauses.map((c) => c.body), st.orelse || []];
    const open = bodies.filter((b) => !ends(b)).length;
    if (rest.length && declares(bodies.flat())) bail('a branch declares locals ahead of code that follows it');
    if (rest.length && open > 1 && sizeOf(rest) > 80 && !rest.some((x) => this.m.mentions(x))) bail('a conditional write of the state is followed by a long run of code');
    const arm = (body) => this.seq(ends(body) ? body : [...body, ...rest], s);
    let tail = arm(st.orelse || []);
    for (let i = st.clauses.length - 1; i >= 0; i--) tail = { stmts: [], end: { k: 'if', cond: st.clauses[i].cond, t: arm(st.clauses[i].body), f: tail } };
    return { stmts: [...out, ...tail.stmts], end: tail.end };
  }
}

// ---- the graph ---------------------------------------------------------------------------------------------------------------

/**
 * The blocks of the loop. A block is named by the state and by the place in the body where control picks up: with several selections one
 * after the other, the leaf of a state is reached at its own place in the body whichever way control got there, so each leaf is one block
 * and a loop made of them is one loop (naming blocks by the state at the top of an iteration would copy a leaf for every way into it).
 */
function buildGraph(loop, state, init, ctx) {
  const model = new Model(ctx, state);
  const walker = new Walker(ctx, model);
  const body = loop.body;
  const n = body.length;
  const blocks = new Map();
  const queue = [];
  const EXIT = 'exit';
  blocks.set(EXIT, { stmts: [], term: { kind: 'exit' } });
  let sub = 0;

  if (body.some((x) => x.type === 'Local' || x.type === 'LocalFunction')) bail('the loop body declares locals of its own');

  const isSelection = (st) => st.type === 'If' && model.stateOnly(st.clauses[0].cond);
  /** the body of the clause a selection takes for the state, or null */
  const pick = (st, s) => {
    for (const c of st.clauses) {
      if (!model.stateOnly(c.cond)) bail('a clause of the selection tests something besides the state');
      const v = model.value(c.cond, s);
      if (v === NOT_CONST) bail('a clause of the selection cannot be evaluated for a concrete state');
      if (truthy(v)) return c.body;
    }
    return st.orelse || null;
  };
  const fires = (st, s) => { const b = pick(st, s); return !!b && b.length > 0; };
  const normalise = (pos, s) => { while (pos < n && isSelection(body[pos]) && !fires(body[pos], s)) pos++; return pos; };

  const loopCond = strip(loop.cond);
  const holds = (s) => {
    // `while cond`: goes on while it holds; `repeat ... until cond`: goes on until it does
    if (loop.type === 'While' && loopCond.type === 'True') return true;
    if (loop.type === 'Repeat' && (loopCond.type === 'False' || loopCond.type === 'Nil')) return true;
    if (!model.stateOnly(loopCond) && !model.fixed(loopCond)) bail('the loop condition depends on more than the state');
    const v = model.value(loopCond, s);
    if (v === NOT_CONST) bail('the loop condition cannot be evaluated for a concrete state');
    return loop.type === 'While' ? truthy(v) : !truthy(v);
  };

  /** the block that runs the body from `pos` with the state `s` */
  const target = (s, pos) => {
    pos = normalise(pos, s);
    if (pos >= n) {
      // the end of the body: the loop goes round, or is left
      if (!holds(s)) return EXIT;
      pos = normalise(0, s);
      if (pos >= n) bail('no block of the loop is selected by one of its states');
    }
    const id = `s${keyOf(s)}@${pos}`;
    if (!blocks.has(id)) {
      if (blocks.size > MAX_STATES) bail('more states than the limit');
      blocks.set(id, { stmts: [], term: null });
      queue.push([id, s, pos]);
    }
    return id;
  };

  const place = (block, res, next) => {
    block.stmts.push(...res.stmts);
    const end = res.end;
    switch (end.k) {
      case 'to': block.term = { kind: 'goto', to: target(end.value, end.head ? n : next) }; break;
      case 'exit': block.term = { kind: 'goto', to: EXIT }; break;
      case 'ret': block.term = { kind: 'return', values: end.stmt.values && end.stmt.values.length ? end.stmt.values : null }; break;
      case 'if': {
        const tid = `c${sub++}`;
        const fid = `c${sub++}`;
        const tb = { stmts: [], term: null };
        const fb = { stmts: [], term: null };
        blocks.set(tid, tb);
        blocks.set(fid, fb);
        block.term = { kind: 'branch', cond: end.cond, t: tid, f: fid };
        place(tb, end.t, next);
        place(fb, end.f, next);
        break;
      }
      default: bail('internal: unknown end of a path');
    }
  };

  /** Run the body from `pos` until the first selection that takes a clause; that clause's path ends the block. */
  const fill = (id, s, pos) => {
    const block = blocks.get(id);
    const out = [];
    for (let i = pos; i < n; i++) {
      const st = body[i];
      if (isSelection(st)) {
        const chosen = pick(st, s);
        if (!chosen || !chosen.length) continue;
        const r = walker.seq(chosen, s);
        place(block, { stmts: [...out, ...r.stmts], end: r.end }, i + 1);
        return;
      }
      const r = walker.seq([st], s);
      out.push(...r.stmts);
      if (r.end.k === 'to' && !r.end.head) { s = r.end.value; continue; }
      place(block, { stmts: out, end: r.end }, i + 1);
      return;
    }
    place(block, { stmts: out, end: { k: 'to', value: s } }, n);
  };

  // a `while` whose condition fails at the start does not run at all; a `repeat` always runs once
  if (loop.type === 'While' && !holds(init)) bail('the loop does not run for its initial state');
  const first = normalise(0, init);
  if (first >= n) bail('no block of the loop is selected by its initial state');
  const entry = `s${keyOf(init)}@${first}`;
  blocks.set(entry, { stmts: [], term: null });
  queue.push([entry, init, first]);
  while (queue.length) {
    const [id, s, pos] = queue.shift();
    fill(id, s, pos);
  }
  return { blocks, entry };
}

// ---- cleaning the graph ------------------------------------------------------------------------------------------------------

const successors = (b) => (b.term.kind === 'goto' ? [b.term.to] : b.term.kind === 'branch' ? [b.term.t, b.term.f] : []);

function cleanGraph(blocks, entry) {
  const retarget = (b, from, to) => {
    if (b.term.kind === 'goto' && b.term.to === from) b.term = { kind: 'goto', to };
    else if (b.term.kind === 'branch') b.term = { ...b.term, t: b.term.t === from ? to : b.term.t, f: b.term.f === from ? to : b.term.f };
  };
  for (let changed = true; changed;) {
    changed = false;
    for (const b of blocks.values()) if (b.term.kind === 'branch' && b.term.t === b.term.f) { b.term = { kind: 'goto', to: b.term.t }; changed = true; }
    // jumps through empty blocks go straight on
    for (const [id, b] of blocks) {
      if (b.stmts.length || b.term.kind !== 'goto' || b.term.to === id) continue;
      for (const [, o] of blocks) if (o !== b && successors(o).includes(id)) { retarget(o, id, b.term.to); changed = true; }
      if (id === entry) { entry = b.term.to; changed = true; }
    }
    const seen = new Set([entry]);
    const stack = [entry];
    while (stack.length) { const n = stack.pop(); for (const m of successors(blocks.get(n))) if (!seen.has(m)) { seen.add(m); stack.push(m); } }
    for (const id of [...blocks.keys()]) if (!seen.has(id)) { blocks.delete(id); changed = true; }
    // a block that only one block jumps to, by a plain jump, joins that block
    const preds = new Map([...blocks.keys()].map((k) => [k, 0]));
    for (const b of blocks.values()) for (const m of successors(b)) preds.set(m, preds.get(m) + 1);
    for (const [id, b] of blocks) {
      if (b.term.kind !== 'goto') continue;
      const to = b.term.to;
      if (to === id || to === entry || preds.get(to) !== 1) continue;
      const next = blocks.get(to);
      if (next.term.kind === 'exit' && !next.stmts.length) continue;
      b.stmts.push(...next.stmts);
      b.term = next.term;
      blocks.delete(to);
      changed = true;
      break;
    }
  }
  return entry;
}

const negate = (c) => (c.type === 'Unary' && c.op === 'not' ? c.arg : { type: 'Unary', op: 'not', arg: c.type === 'Binary' ? { type: 'Paren', expr: c } : c });

// ---- locals declared inside blocks -------------------------------------------------------------------------------------------

/**
 * A local that a block declares is visible in that block only. Once the blocks are written one after the other a same-named variable of
 * the surrounding code could be shadowed by it, so a local whose name is used for something else too is renamed first (and put back if
 * the loop turns out not to be understood).
 */
function separateLocals(loop, model, ctx, undo) {
  const { info } = ctx;
  const counts = new Map();
  for (const v of info.vars) counts.set(v.name, (counts.get(v.name) || 0) + 1);
  const rename = (v) => {
    if ((counts.get(v.name) || 0) <= 1) return;
    const nm = ctx.fresh(v.name);
    for (const n of [v.decl, ...v.reads, ...v.writes]) if (n) { undo.push([n, n.name]); n.name = nm; }
  };
  const visit = (list) => {
    for (const st of list) {
      if (st.type === 'Local') st.ids.forEach((id) => { const v = info.varOf.get(id); if (v) rename(v); });
      else if (st.type === 'LocalFunction') { const v = info.varOf.get(st.id); if (v) rename(v); }
      else if (st.type === 'If' && model.stateOnly(st.clauses[0].cond)) {
        st.clauses.forEach((c) => visit(c.body));
        if (st.orelse) visit(st.orelse);
      }
    }
  };
  visit(loop.body);
}

// ---- one loop ----------------------------------------------------------------------------------------------------------------

/** The initial state: the last statement before the loop that sets the state variable, which must set it to a constant. */
function initialState(parent, index, model) {
  for (let i = index - 1; i >= 0; i--) {
    const st = parent[i];
    if (st.type === 'Local') {
      const k = st.ids.findIndex((id) => model.varOf(id) === model.state);
      if (k >= 0) {
        if (k >= st.values.length) continue;
        const v = model.ctx.evalExpr(st.values[k]);
        return v === NOT_CONST ? null : { at: i, k, value: v };
      }
    } else if (st.type === 'Assign') {
      const k = st.targets.findIndex((t) => t.type === 'Name' && model.varOf(t) === model.state);
      if (k >= 0) {
        if (k >= st.values.length) return null;
        const v = model.ctx.evalExpr(st.values[k]);
        return v === NOT_CONST ? null : { at: i, k, value: v };
      }
    }
    if (model.mentions(st)) return null;
  }
  return null;
}

function recoverLoop(parent, index, ctx) {
  const loop = parent[index];
  const found = findState(loop, ctx);
  if (!found) return null;
  const { state } = found;
  if (state.isGlobal) bail('the state is a global variable');
  const model = new Model(ctx, state);
  const init = initialState(parent, index, model);
  if (!init) bail('the initial state is not a constant set just before the loop');
  // the state must not live anywhere but the loop and its set-up
  const allowed = new Set();
  walk(loop, (n) => { if (n.type === 'Name') allowed.add(n); });
  walk(parent[init.at], (n) => { if (n.type === 'Name') allowed.add(n); });
  for (const n of [...state.reads, ...state.writes]) if (!allowed.has(n)) bail('the state is used outside the loop');

  const undo = [];
  separateLocals(loop, model, ctx, undo);
  try {
    const { blocks, entry: first } = buildGraph(loop, state, init.value, ctx);
    const states = [...blocks.keys()].filter((k) => /^s.*@/.test(k)).length;
    const entry = cleanGraph(blocks, first);
    let body;
    try {
      body = structure(blocks, entry, { negate, makeReturn: (values) => ({ type: 'Return', values: values || [] }) });
    } catch (e) {
      if (!(e instanceof CfgError)) throw e;
      bail(`the blocks cannot be put back into structured code (${e.message})`);
    }
    return { body: clone(body), init, states, leaves: found.leaves, line: lineOf(loop) };
  } catch (e) {
    for (const [n, old] of undo) n.name = old;
    throw e;
  }
}

/** Remove the state from its set-up statement; returns true when nothing of the statement is left. */
function dropInit(parent, init) {
  const st = parent[init.at];
  if (st.type === 'Local') {
    const ids = st.ids.filter((_, k) => k !== init.k);
    const values = st.values.filter((_, k) => k !== init.k);
    if (!ids.length) return true;
    parent[init.at] = { ...st, ids, values };
    return false;
  }
  const targets = st.targets.filter((_, k) => k !== init.k);
  const values = st.values.filter((_, k) => k !== init.k);
  if (!targets.length) return true;
  parent[init.at] = { ...st, targets, values };
  return false;
}

const lists = (chunk) => {
  const out = [];
  walk(chunk, (n) => {
    if (n.type === 'Chunk' || n.type === 'Func' || n.type === 'Do' || n.type === 'While' || n.type === 'Repeat' || n.type === 'NumFor' || n.type === 'GenFor') out.push(n.body);
    else if (n.type === 'If') { n.clauses.forEach((c) => out.push(c.body)); if (n.orelse) out.push(n.orelse); }
  });
  return out;
};

/**
 * Recover every dispatch loop of the chunk that can be read. A loop that cannot is left as it is and listed in `refused`.
 * @returns {{changed: number, loops: {line: number, states: number}[], refused: {line: number, why: string}[]}}
 */
export function recoverDispatchers(chunk) {
  const loops = [];
  const refused = [];
  let changed = 0;
  for (let pass = 0; pass < 8; pass++) {
    const base = analyse(chunk);
    const used = new Set(base.names);
    const ctx = { ...base, fresh: (stem) => { let k = 1; let nm = `${stem}_${k}`; while (used.has(nm)) nm = `${stem}_${++k}`; used.add(nm); return nm; } };
    let progress = 0;
    for (const parent of lists(chunk)) {
      for (let i = 0; i < parent.length; i++) {
        const st = parent[i];
        if (st.type !== 'While' && st.type !== 'Repeat') continue;
        let res;
        try { res = recoverLoop(parent, i, ctx); } catch (e) {
          if (e instanceof Bail) { refused.push({ line: lineOf(st), why: e.message }); continue; }
          throw e;
        }
        if (!res) continue;
        parent.splice(i, 1, ...res.body);
        let at = i + res.body.length - 1;
        if (dropInit(parent, res.init)) { parent.splice(res.init.at, 1); at--; }
        i = at;
        loops.push({ line: res.line, states: res.states, leaves: res.leaves });
        changed += res.states;
        progress++;
      }
    }
    if (!progress) break;
  }
  const seen = new Set();
  return { changed, loops, refused: refused.filter((r) => { const k = `${r.line}:${r.why}`; if (seen.has(k)) return false; seen.add(k); return true; }) };
}

export const dispatch = {
  id: 'dispatch.recover',
  title: 'Rebuild flattened control flow',
  order: 50,
  rebuilds: true,

  observe(ast, an) {
    const out = [];
    walk(ast, (n) => {
      const d = describeDispatch(n, an);
      if (!d) return;
      out.push({
        kind: 'dispatcher',
        line: d.line,
        label: `a loop selects among ${d.leaves} blocks by the value of \`${d.name}\``,
        evidence: [`the loop tests \`${d.name}\` against constants to choose what runs next`, `${d.writing} of ${d.leaves} blocks end by setting \`${d.name}\``],
        confidence: 0.9,
        weight: 8 + 0.1 * d.leaves,
      });
    });
    return out;
  },

  run(ast) {
    const r = recoverDispatchers(ast);
    return { changed: r.changed, loops: r.loops, notes: r.refused.map((x) => ({ line: x.line, text: x.why })) };
  },
};
