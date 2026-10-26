// A prototype's instructions, lifted. For each instruction the interpreter's graph is partially evaluated with the instruction's row as the
// known input; what remains is what that instruction does, as a few statements and the program counters it can leave to. The pieces are joined
// into one graph, tidied, and handed to the structurer.

import { prepare, Table } from '../block-pe.js';
import { optimizeCfg, liveness } from '../cfg-opt.js';
import { sha256, chacha } from '../moonveil-crypto.js';
import { openRuns, inlineTemps, copyPropagate, typeHashTests, forwardSubstitute, methodSugar, shortCircuit, unpackPack, foldTableInit, setList } from '../moonveil-idioms.js';
import { makeModel, initialEnv } from './model.js';
import { canonicalForPrep } from './forprep.js';

const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };

export function createLifter(profile, ops, { registers = 700, onStep } = {}) {
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
  /** One instruction, lifted, as a graph with an exit per way out. */
  function instance(code, pc, ins) {
    let r = P.evaluate('S', initialEnv(profile, code, pc));
    if (forPrepOp.get(ins.op) !== false) {
      const c = canonicalForPrep(r);
      // whether an op starts a generic `for` is a property of its handler, so it is decided once per op
      forPrepOp.set(ins.op, c !== undefined);
      if (c) r = c;
    }
    return r;
  }

  /** The whole prototype as one graph; every instruction's blocks are tidied on their own first (a few dozen blocks, where the whole is tens of thousands). */
  function liftGraph(proto) {
    const code = codeTable(proto);
    const n = proto.code.length;
    const blocks = new Map();
    const entryOf = new Map();
    const queue = [1];
    const seen = new Set([1]);
    const pending = [];
    let lifted = 0;
    while (queue.length) {
      const pc = queue.shift();
      if (onStep && (++lifted & 255) === 0) onStep(lifted);
      if (pc < 1 || pc > n) throw new Error(`the program counter leaves the function (${pc})`);
      let r = instance(code, pc, proto.code[pc - 1]);
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
          if (!seen.has(o)) { seen.add(o); queue.push(o); }
        }
        blocks.set(`${pc}:${id}`, nb);
      }
    }
    for (const [nb, o] of pending) nb.term = { kind: 'goto', to: entryOf.get(o) };
    return { blocks, entry: entryOf.get(1) };
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

  return { liftGraph, cleanGraph };
}
