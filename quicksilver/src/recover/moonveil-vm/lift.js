// A prototype's instructions, lifted. For each instruction the interpreter's graph is partially evaluated with the instruction's row as the
// known input; what remains is what that instruction does, as a few statements and the program counters it can leave to. The pieces are joined
// into one graph, tidied, and handed to the structurer.

import { prepare, Table } from '../block-pe.js';
import { optimizeCfg, liveness } from '../cfg-opt.js';
import { sha256, chacha } from '../moonveil-crypto.js';
import { openRuns, inlineTemps, copyPropagate, typeHashTests, forwardSubstitute, methodSugar, shortCircuit, unpackPack, foldTableInit, setList } from '../moonveil-idioms.js';
import { makeModel, initialEnv } from './model.js';
import { canonicalForPrep } from './forprep.js';
import { walk } from '../../core/walk.js';

const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };

export function createLifter(profile, ops, { registers = 700, onStep, reuse = true } = {}) {
  const { graph, head, roles } = profile;
  const B0 = head.block;
  // the interpreter's graph with the loop head split: the entry is a copy of the head, every edge back to the head leaves the graph
  const base = new Map([...graph.blocks].map(([k, b]) => [k, { stmts: [...b.stmts], term: { ...b.term } }]));
  base.set('S', { stmts: [...base.get(B0).stmts], term: { ...base.get(B0).term } });
  base.set('EXIT', { stmts: [], term: { kind: 'exit' } });
  for (const [k, b] of base) {
    if (k === 'S') continue;
    const t = b.term;
    if (t.kind === 'goto' && t.to === B0) b.term = { kind: 'goto', to: 'EXIT' };
    else if (t.kind === 'branch') b.term = { ...t, t: t.t === B0 ? 'EXIT' : t.t, f: t.f === B0 ? 'EXIT' : t.f };
  }
  const P = prepare(base, { exitLive: ops.exitLive, model: makeModel(profile) });

  const constants = profile.crypto.chachaConstants;
  const pure = () => new Map([
    ['vm_sha256', (s) => (typeof s === 'string' ? sha256(s) : undefined)],
    ['vm_chacha20', (d, n, k) => (typeof d === 'string' && typeof n === 'string' && typeof k === 'string' ? chacha(d, n, k, constants) ?? undefined : undefined)],
  ]);
  const instanceOpts = {
    exitLive: new Set([...ops.exitLive, roles.top, ...Array.from({ length: registers }, (_, i) => `r${i}`), ...Array.from({ length: 64 }, (_, i) => `up${i}`)]),
    effectFree: new Set(['upref', 'ref']),
    pureCalls: pure(),
  };
  const cleanOpts = () => ({ exitLive: new Set(), effectFree: new Set(['upref', 'ref']), pureCalls: pure() });

  const fields = profile.fieldIds.filter((f) => f !== head.opField);
  function codeTable(proto) {
    const code = new Table();
    proto.code.forEach((ins, i) => {
      const t = new Table();
      t.set(head.opField, ins.op);
      // the deserializer starts every row with every field 0
      for (const f of fields) t.set(f, 0);
      for (const [k, v] of Object.entries(ins)) if (/^\d+$/.test(k)) t.set(Number(k), v && typeof v === 'object' ? v.v : v);
      code.set(i + 1, t);
    });
    return code;
  }

  const forPrepOp = new Map();
  // loops of the interpreter that a handler cannot be unrolled through are given up on once per op, not once for everything lifted so far
  const widenedByOp = new Map();
  const widenedFor = (op) => { if (!widenedByOp.has(op)) widenedByOp.set(op, new Set()); return widenedByOp.get(op); };
  /** One instruction, lifted, as a graph with an exit per way out. */
  function instance(code, pc, ins) {
    let r = P.evaluate('S', initialEnv(profile, code, pc), widenedFor(ins.op));
    if (forPrepOp.get(ins.op) !== false) {
      const c = canonicalForPrep(r);
      // whether an op starts a generic `for` is a property of its handler, so it is decided once per op
      forPrepOp.set(ins.op, c !== undefined);
      if (c) r = c;
    }
    return r;
  }

  // ---- one instruction, once per kind ------------------------------------------------------------------------------------------------
  // What an instruction does depends on its op and its fields and, for the program counters it can leave to, on where it is. Most programs repeat
  // the same instruction many times (loading the same constant, moving the same register), so an instruction is lifted once at a program counter
  // no function has, and every other one like it is that result with the counters moved. This holds when the handler does not read the code array
  // (no instruction takes a word from the one after it) and when no program counter shows up in what is left except as a place to go.
  const stats = { why: {}, fallback: 0, templates: 0, peMs: 0, optMs: 0, peBlocks: 0, optBlocks: 0 };
  const BASE = 10_000_000;
  const templates = new Map();
  const rowOf = (ins) => {
    const t = new Table();
    t.set(head.opField, ins.op);
    // the deserializer starts every row with every field 0
    for (const f of fields) t.set(f, 0);
    for (const [k, v] of Object.entries(ins)) if (/^\d+$/.test(k)) t.set(Number(k), v && typeof v === 'object' ? v.v : v);
    return t;
  };
  const keyOf = (ins) => {
    let key = String(ins.op);
    for (const k of Object.keys(ins)) if (/^\d+$/.test(k)) { const v = ins[k]; key += `|${k}=${v && typeof v === 'object' ? JSON.stringify(v.v) : v}`; }
    return key;
  };
  /** The lifted instruction as graph, tidied, with the places it can go to as offsets from its own position; or null when it cannot be reused. */
  // a handler that takes a word from the instruction after it sees that one too, and is reusable only for that same pair
  class Spy extends Table {
    constructor() { super(); this.reads = new Set(); }
    get(k) { this.reads.add(k); return super.get(k); }
  }
  const no = (why) => { stats.why[why] = (stats.why[why] || 0) + 1; return null; };
  function templateFor(ins, following) {
    const use = ops.codeUse(ins.op);
    if (use.writes) return no('writes');
    const code = new Spy();
    code.set(BASE, rowOf(ins));
    following.forEach((x, i) => { if (x) code.set(BASE + 1 + i, rowOf(x)); });
    code.reads.clear();
    const t0 = performance.now();
    let r = P.evaluate('S', initialEnv(profile, code, BASE), new Set());
    stats.peMs += performance.now() - t0;
    stats.peBlocks += r.blocks.size;
    if (forPrepOp.get(ins.op) !== false) {
      const c = canonicalForPrep(r);
      forPrepOp.set(ins.op, c !== undefined);
      if (c) r = c;
    }
    for (const [id, b] of r.blocks) if (b.term.kind === 'exit') b.term = { kind: 'exit', o: r.exits.get(id).get('o') };
    const t1 = performance.now();
    const entry = optimizeCfg(r.blocks, r.entry, instanceOpts).entry;
    stats.optMs += performance.now() - t1;
    stats.templates++;
    stats.optBlocks += r.blocks.size;
    const blocks = new Map();
    for (const [id, b] of r.blocks) {
      const t = b.term;
      if (t.kind === 'exit') {
        const o = t.o;
        if (typeof o !== 'number') return no('exit-not-number');
        if (Math.abs(o - BASE) < 1e6) blocks.set(id, { stmts: b.stmts, term: { kind: 'exit', rel: o - BASE } });
        else if (Number.isInteger(o) && o >= 1 && o < 1e6) blocks.set(id, { stmts: b.stmts, term: { kind: 'exit', abs: o } });
        else return no('exit-odd');
      } else blocks.set(id, { stmts: b.stmts, term: t });
    }
    // how far into the code the handler looked: the instruction itself, and the words it takes from the ones after it
    let far = 0;
    for (const k of code.reads) far = Math.max(far, k - BASE);
    if (far > following.length) return far <= 64 ? { more: far } : no('reads-far');
    // the interpreter keeps its program counter in a variable and the handler's last act is to set it; where the instruction goes is in the exit, so
    // those assignments say nothing (and are the one place the position of the instruction would otherwise show)
    const isPc = (t) => t.type === 'Name' && t.name === roles.pc;
    for (const b of blocks.values()) {
      b.stmts = b.stmts.flatMap((st) => {
        if (st.type !== 'Assign' || !st.targets.some(isPc)) return [st];
        if (st.targets.length === 1) return [];
        if (st.targets.length !== st.values.length) return [st];
        const keep = st.targets.map((t, i) => i).filter((i) => !isPc(st.targets[i]));
        return [{ ...st, targets: keep.map((i) => st.targets[i]), values: keep.map((i) => st.values[i]) }];
      });
    }
    // the program counter must not have been put into the code as a value
    let leaked = false;
    const near = (n) => { if (n.type === 'Number' && Math.abs(n.value - BASE) < 1e6) leaked = true; };
    for (const b of blocks.values()) { for (const st of b.stmts) walk(st, near); if (b.term.kind === 'branch') walk(b.term.cond, near); else if (b.term.kind === 'return' && b.term.values) walk(b.term.values, near); }
    return leaked ? no('leaked') : { entry, blocks };
  }
  // how many of the instructions after one a handler has been seen to read, by op and fields
  const reach = new Map();
  /** The template for an instruction, made when no instruction like it (and like the ones it reads after it) was seen. */
  function templateOf(proto, pc, ins) {
    const base = keyOf(ins);
    if (!ops.codeUse(ins.op).reads) {
      if (!templates.has(base)) templates.set(base, templateFor(ins, []));
      return templates.get(base);
    }
    for (;;) {
      const n = reach.get(base) ?? 1;
      const following = [];
      let key = base;
      for (let i = 0; i < n; i++) { const x = proto.code[pc + i]; following.push(x); key += `>${x ? keyOf(x) : 'end'}`; }
      if (templates.has(key)) return templates.get(key);
      const made = templateFor(ins, following);
      if (made && made.more) { reach.set(base, made.more); continue; }
      templates.set(key, made);
      return made;
    }
  }
  /** a template that does nothing but go on to another instruction: the instruction is not a block at all */
  function skipsTo(tmpl, pc) {
    if (tmpl.blocks.size !== 1) return null;
    const b = tmpl.blocks.get(tmpl.entry);
    if (!b || b.stmts.length || b.term.kind !== 'exit') return null;
    return b.term.rel !== undefined ? pc + b.term.rel : b.term.abs;
  }

  /** The whole prototype as one graph; every instruction's blocks are tidied on their own first (a few dozen blocks, where the whole is tens of thousands). */
  function liftGraph(proto) {
    const code = codeTable(proto);
    const n = proto.code.length;
    const blocks = new Map();
    const entryOf = new Map();
    const jumpsTo = new Map();
    const queue = [1];
    const seen = new Set([1]);
    const pending = [];
    const reach = (o) => { if (!seen.has(o)) { seen.add(o); queue.push(o); } };
    let lifted = 0;
    while (queue.length) {
      const pc = queue.shift();
      if (onStep && (++lifted & 255) === 0) onStep(lifted);
      if (pc < 1 || pc > n) throw new Error(`the program counter leaves the function (${pc})`);
      const ins = proto.code[pc - 1];
      const tmpl = reuse ? templateOf(proto, pc, ins) : null;
      if (tmpl) {
        const target = skipsTo(tmpl, pc);
        if (target !== null) {
          if (typeof target !== 'number' || target < 1 || target > n) throw new Error(`the instruction at ${pc} leaves with an unknown program counter`);
          jumpsTo.set(pc, target);
          reach(target);
          continue;
        }
        entryOf.set(pc, `${pc}:${tmpl.entry}`);
        for (const [id, b] of tmpl.blocks) {
          const t = b.term;
          const nb = { stmts: b.stmts.slice(), term: { ...t } };
          if (t.kind === 'goto') nb.term.to = `${pc}:${t.to}`;
          else if (t.kind === 'branch') { nb.term.t = `${pc}:${t.t}`; nb.term.f = `${pc}:${t.f}`; }
          else if (t.kind === 'exit') { const o = t.rel !== undefined ? pc + t.rel : t.abs; pending.push([nb, o]); reach(o); }
          blocks.set(`${pc}:${id}`, nb);
        }
        continue;
      }
      stats.fallback++;
      let r = instance(code, pc, ins);
      for (const [id, b] of r.blocks) if (b.term.kind === 'exit') b.term = { kind: 'exit', o: r.exits.get(id).get('o') };
      r = { blocks: r.blocks, entry: optimizeCfg(r.blocks, r.entry, instanceOpts).entry };
      entryOf.set(pc, `${pc}:${r.entry}`);
      for (const [id, b] of r.blocks) {
        const t = b.term;
        const nb = { stmts: b.stmts, term: { ...t } };
        if (t.kind === 'goto') nb.term.to = `${pc}:${t.to}`;
        else if (t.kind === 'branch') { nb.term.t = `${pc}:${t.t}`; nb.term.f = `${pc}:${t.f}`; }
        else if (t.kind === 'exit') {
          const o = t.o;
          if (typeof o !== 'number') throw new Error(`the instruction at ${pc} leaves with an unknown program counter`);
          pending.push([nb, o]);
          reach(o);
        }
        blocks.set(`${pc}:${id}`, nb);
      }
    }
    // an instruction that only goes on is the place it goes on to; a ring of them is one empty block that jumps to itself
    const resolve = (pc) => {
      const trail = [];
      let at = pc;
      while (jumpsTo.has(at) && !entryOf.has(at)) {
        if (trail.includes(at)) {
          const id = `${at}:loop`;
          blocks.set(id, { stmts: [], term: { kind: 'goto', to: id } });
          for (const q of trail) entryOf.set(q, id);
          return id;
        }
        trail.push(at);
        at = jumpsTo.get(at);
      }
      return entryOf.get(at);
    };
    for (const [nb, o] of pending) nb.term = { kind: 'goto', to: resolve(o) };
    return { blocks, entry: resolve(1) };
  }

  /** The joined graph, cleaned until nothing more can be said about it. */
  function cleanGraph(blocks, entry) {
    setList(blocks);
    let e = optimizeCfg(blocks, entry, cleanOpts()).entry;
    if (typeHashTests(blocks)) e = optimizeCfg(blocks, e, cleanOpts()).entry;
    for (let round = 0; round < 6; round++) {
      const a = openRuns(blocks) + unpackPack(blocks);
      const c = copyPropagate(blocks);
      e = optimizeCfg(blocks, e, cleanOpts()).entry;
      const b = inlineTemps(blocks, liveness(blocks, new Set()));
      if (!a && !b && !c) break;
      e = optimizeCfg(blocks, e, cleanOpts()).entry;
    }
    for (let round = 0; round < 10; round++) {
      const sc = shortCircuit(blocks);
      if (sc) e = optimizeCfg(blocks, e, cleanOpts()).entry;
      const f = forwardSubstitute(blocks, liveness(blocks, new Set()));
      const u = unpackPack(blocks);
      const m = methodSugar(blocks);
      const ti = foldTableInit(blocks);
      if (f || u || m || ti) e = optimizeCfg(blocks, e, cleanOpts()).entry;
      if (!f && !sc && !u && !m && !ti) break;
    }
    return { entry: e };
  }

  return { liftGraph, cleanGraph, stats };
}
