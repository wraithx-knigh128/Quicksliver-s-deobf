// Control-flow structuring: a graph of basic blocks back into if / while / break.
//
// The input is what a flattening transformation leaves behind once its dispatcher has been taken apart: blocks of
// ordinary statements, each ending in a jump, a two-way branch or a return. This module knows nothing about where the
// blocks came from. It finds the loops (natural loops of the dominator tree) and the places where branches meet again
// (immediate post-dominators), and writes
//
//     block A; if c then block B else block C end; block D            for a diamond
//     while true do ...; if c then break end; ... end                  for a loop with an exit test
//
// Loops are emitted as `while true do ... end` with explicit `break`s; folding the exit test into the loop header or
// the loop into a `repeat` is left to the clean-up passes. Anything that does not fit (a jump into the middle of a loop, a
// `continue` that is not at the end of the body, an irreducible graph) throws CfgError instead of guessing.
//
// Block: { stmts: Stmt[], term }   with term one of
//     { kind: 'goto',   to }
//     { kind: 'branch', cond, t, f }          control goes to `t` when `cond` is truthy
//     { kind: 'return', values }               values: Expr[] | null
//     { kind: 'exit' }                         the function simply ends

export class CfgError extends Error {}

const BREAK = { type: 'Break' };

/**
 * @param {Map<any, {stmts: object[], term: object}>} blocks
 * @param {any} entry
 * @param {{negate(cond): object}} helpers
 * @returns {object[]} statements
 */
export function structure(blocks, entry, helpers) {
  const g = new Graph(blocks, entry);
  return new Emitter(g, blocks, helpers).run();
}

// ---- graph -------------------------------------------------------------------------------------------------------

const successors = (term) => (term.kind === 'goto' ? [term.to] : term.kind === 'branch' ? [term.t, term.f] : []);

class Graph {
  constructor(blocks, entry) {
    this.entry = entry;
    this.succ = new Map();
    this.pred = new Map();
    const order = [];
    const seen = new Set();
    // iterative DFS for reverse post-order
    const stack = [[entry, 0]];
    seen.add(entry);
    while (stack.length) {
      const top = stack[stack.length - 1];
      const [n, i] = top;
      if (!blocks.has(n)) throw new CfgError(`jump to unknown block ${n}`);
      const s = successors(blocks.get(n).term);
      if (i === 0) this.succ.set(n, s);
      if (i < s.length) {
        top[1]++;
        if (!seen.has(s[i])) { seen.add(s[i]); stack.push([s[i], 0]); }
      } else { order.push(n); stack.pop(); }
    }
    this.rpo = order.reverse();
    this.index = new Map(this.rpo.map((n, i) => [n, i]));
    for (const n of this.rpo) this.pred.set(n, []);
    for (const n of this.rpo) for (const s of this.succ.get(n)) this.pred.get(s).push(n);
    this.idom = this.dominators();
    this.ipdom = this.postDominators();
    this.loops = this.findLoops();
  }

  /** Cooper-Harvey-Kennedy on the reverse post-order. */
  dominators() {
    const idom = new Map([[this.entry, this.entry]]);
    const intersect = (a, b) => {
      while (a !== b) {
        while (this.index.get(a) > this.index.get(b)) a = idom.get(a);
        while (this.index.get(b) > this.index.get(a)) b = idom.get(b);
      }
      return a;
    };
    for (let changed = true; changed;) {
      changed = false;
      for (const n of this.rpo) {
        if (n === this.entry) continue;
        let d = null;
        for (const p of this.pred.get(n)) {
          if (!idom.has(p)) continue;
          d = d === null ? p : intersect(p, d);
        }
        if (idom.get(n) !== d) { idom.set(n, d); changed = true; }
      }
    }
    return idom;
  }

  dominates(a, b) {
    for (let n = b; ; n = this.idom.get(n)) {
      if (n === a) return true;
      if (n === this.entry) return false;
    }
  }

  /** Post-dominators on the reverse graph with one virtual exit that every returning block (and every block that cannot reach one) feeds. */
  postDominators() {
    const X = Symbol('exit');
    this.X = X;
    const rsucc = new Map();     // successors in the reversed graph = predecessors here
    const rpred = new Map();
    for (const n of this.rpo) { rsucc.set(n, []); rpred.set(n, []); }
    rsucc.set(X, []); rpred.set(X, []);
    const link = (from, to) => { rsucc.get(from).push(to); rpred.get(to).push(from); };
    // reversed edges: for an edge a -> b we get b -> a; exits connect X -> n
    const exits = this.rpo.filter((n) => this.succ.get(n).length === 0);
    for (const n of this.rpo) for (const s of this.succ.get(n)) link(s, n);
    for (const n of exits) link(X, n);
    // blocks that cannot reach an exit (an endless loop) are attached to X as well
    const reach = new Set();
    const queue = [...exits];
    exits.forEach((n) => reach.add(n));
    while (queue.length) {
      const n = queue.pop();
      for (const p of this.pred.get(n)) if (!reach.has(p)) { reach.add(p); queue.push(p); }
    }
    for (const n of this.rpo) if (!reach.has(n)) link(X, n);

    // reverse post-order of the reversed graph from X
    const order = [];
    const seen = new Set([X]);
    const stack = [[X, 0]];
    while (stack.length) {
      const top = stack[stack.length - 1];
      const [n, i] = top;
      const s = rsucc.get(n);
      if (i < s.length) { top[1]++; if (!seen.has(s[i])) { seen.add(s[i]); stack.push([s[i], 0]); } } else { order.push(n); stack.pop(); }
    }
    order.reverse();
    const index = new Map(order.map((n, i) => [n, i]));
    const ipdom = new Map([[X, X]]);
    const intersect = (a, b) => {
      while (a !== b) {
        while (index.get(a) > index.get(b)) a = ipdom.get(a);
        while (index.get(b) > index.get(a)) b = ipdom.get(b);
      }
      return a;
    };
    for (let changed = true; changed;) {
      changed = false;
      for (const n of order) {
        if (n === X) continue;
        let d = null;
        for (const p of rpred.get(n)) {
          if (!ipdom.has(p)) continue;
          d = d === null ? p : intersect(p, d);
        }
        if (ipdom.get(n) !== d) { ipdom.set(n, d); changed = true; }
      }
    }
    return ipdom;
  }

  /** Natural loops by header: { header, nodes, latches, targets } */
  findLoops() {
    const loops = new Map();
    for (const n of this.rpo) {
      for (const s of this.succ.get(n)) {
        if (this.index.get(s) > this.index.get(n)) continue;       // a forward edge
        if (!this.dominates(s, n)) throw new CfgError('irreducible control flow');
        // back edge n -> s
        const loop = loops.get(s) || { header: s, nodes: new Set([s]), latches: [] };
        loop.latches.push(n);
        const stack = [n];
        while (stack.length) {
          const m = stack.pop();
          if (loop.nodes.has(m)) continue;
          loop.nodes.add(m);
          for (const p of this.pred.get(m)) stack.push(p);
        }
        loops.set(s, loop);
      }
    }
    for (const loop of loops.values()) {
      const outside = new Set();
      for (const n of loop.nodes) for (const s of this.succ.get(n)) if (!loop.nodes.has(s)) outside.add(s);
      loop.targets = [...outside];
    }
    return loops;
  }
}

// ---- emission ----------------------------------------------------------------------------------------------------

const terminates = (stmts) => {
  const last = stmts[stmts.length - 1];
  return !!last && (last.type === 'Return' || last.type === 'Break');
};

class Emitter {
  constructor(graph, blocks, helpers) {
    this.g = graph;
    this.blocks = blocks;
    this.h = helpers;
    this.emitted = new Set();
  }

  run() {
    const out = this.seq(this.g.entry, new Set(), null, true);
    return out;
  }

  /**
   * Statements from `cur` until control reaches a node of `stop`, leaves the loop or ends the function.
   * `loop` is { header, nodes, exit } for the innermost enclosing loop. `first` lets the very first block be the loop header itself.
   */
  seq(cur, stop, loop, first = false) {
    const out = [];
    for (;;) {
      if (stop.has(cur)) return out;
      if (loop && !first) {
        if (cur === loop.exit) { out.push({ ...BREAK }); return out; }
        if (cur === loop.header) return out;                     // back to the top: the end of the body
        if (!loop.nodes.has(cur) && !loop.breakNodes.has(cur) && !stop.has(cur)) throw new CfgError('jump out of a loop to somewhere other than its exit');
      }
      const header = this.g.loops.get(cur);
      if (header && !(first && loop && loop.header === cur)) {
        const { stmt, exit } = this.loopAt(header, loop);
        out.push(stmt);
        if (exit === null) return out;
        cur = exit;
        first = false;
        continue;
      }
      first = false;
      if (this.emitted.has(cur)) throw new CfgError(`block ${String(cur)} would be emitted twice`);
      this.emitted.add(cur);
      const blk = this.blocks.get(cur);
      out.push(...blk.stmts);
      const t = blk.term;
      if (t.kind === 'goto') { cur = t.to; continue; }
      if (t.kind === 'return') { out.push(this.h.makeReturn(t.values)); return out; }
      if (t.kind === 'exit') return out;
      // two-way branch
      const done = this.branch(cur, t, stop, loop, out);
      if (done === null) return out;
      cur = done;
    }
  }

  /** Emit the if for a branch; returns the node where the flow continues, or null when both arms end the sequence. */
  branch(cur, t, stop, loop, out) {
    // a branch that leaves the loop is an `if ... then break end` and the sequence goes on with the other arm
    if (loop) {
      if (t.t === loop.exit) { out.push({ type: 'If', clauses: [{ cond: t.cond, body: [{ ...BREAK }] }], orelse: null }); return t.f; }
      if (t.f === loop.exit) { out.push({ type: 'If', clauses: [{ cond: this.h.negate(t.cond), body: [{ ...BREAK }] }], orelse: null }); return t.t; }
    }
    let j = this.g.ipdom.get(cur);
    if (j === this.g.X || (loop && !loop.nodes.has(j))) j = null;
    const inner = j === null ? stop : new Set([...stop, j]);
    const mk = (cond, body, orelse) => ({ type: 'If', clauses: [{ cond, body }], orelse });
    if (j !== null && t.t === j) {
      out.push(mk(this.h.negate(t.cond), this.seq(t.f, inner, loop), null));
      return j;
    }
    if (j !== null && t.f === j) {
      out.push(mk(t.cond, this.seq(t.t, inner, loop), null));
      return j;
    }
    const thenArm = this.seq(t.t, inner, loop);
    const elseArm = this.seq(t.f, inner, loop);
    if (j === null) {
      // both arms run to the end of the sequence: an arm that ends the function lets the other follow the `if`
      if (terminates(thenArm) && elseArm.length) { out.push(mk(t.cond, thenArm, null), ...elseArm); return null; }
      if (terminates(elseArm) && thenArm.length) { out.push(mk(this.h.negate(t.cond), elseArm, null), ...thenArm); return null; }
    }
    if (!thenArm.length && elseArm.length) out.push(mk(this.h.negate(t.cond), elseArm, null));
    else out.push(mk(t.cond, thenArm, elseArm.length ? elseArm : null));
    return j;
  }

  /** Can control get from `a` to `b`? */
  reaches(a, b) {
    const seen = new Set([a]);
    const stack = [a];
    while (stack.length) {
      const n = stack.pop();
      if (n === b) return true;
      for (const m of this.g.succ.get(n)) if (!seen.has(m)) { seen.add(m); stack.push(m); }
    }
    return false;
  }

  /** `while true do ... end` for the natural loop with this header. */
  loopAt(info, outer) {
    const { targets } = info;
    let exit = null;
    const breakNodes = new Set();
    if (targets.length === 1) exit = targets[0];
    else if (targets.length > 1) {
      // The ways out are the normal exit and `break`s that run some clean-up first: the clean-up blocks all lead on to
      // the exit. It is the one target the others can reach.
      const candidates = targets.filter((t) => targets.every((o) => o === t || this.reaches(o, t)));
      if (candidates.length !== 1) throw new CfgError(`a loop with ${targets.length} unrelated exits`);
      exit = candidates[0];
      const stack = targets.filter((t) => t !== exit);
      while (stack.length) {
        const n = stack.pop();
        if (breakNodes.has(n) || n === exit) continue;
        breakNodes.add(n);
        for (const m of this.g.succ.get(n)) stack.push(m);
      }
    }
    const loop = { header: info.header, nodes: info.nodes, breakNodes, exit };
    const body = this.seq(info.header, new Set(), loop, true);
    return { stmt: { type: 'While', cond: { type: 'True' }, body }, exit };
  }
}
