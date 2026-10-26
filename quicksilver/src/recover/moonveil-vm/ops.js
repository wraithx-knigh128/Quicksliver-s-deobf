// The interpreter's handlers, one op at a time.
//
// The interpreter is one loop: fetch the row at the program counter, read its op, run the handler for that op. A handler is a path through the
// interpreter's block graph; fixing the op leaves the paths that can be taken (`opGraph`), and fixing the row's fields as well leaves what that
// instruction does (`specialise`). `staticOps` runs the few handlers that rewrite the program itself (an instruction that turns itself into a
// no-op after leaving the next instruction's constant decrypted), by evaluating their residual code against a model of the code array and
// nothing else, so that what the lifter reads afterwards is the program as it stands when it runs.

import { optimizeCfg, liveness } from '../cfg-opt.js';
import { makeEval, LTable, Unknown } from './static-eval.js';
import { walk } from '../../core/walk.js';

const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const u32 = (x) => x >>> 0;
const num = (v) => ({ type: 'Number', value: v, raw: null });
const litOf = (v) => (typeof v === 'number' ? (v < 0 || Object.is(v, -0) ? { type: 'Unary', op: '-', arg: num(-v) } : num(v)) : typeof v === 'string' ? { type: 'String', value: v, raw: null } : num(0));

/** The values of the numeric fields of an instruction, by field id. */
export function fieldsOf(ins) {
  const f = {};
  for (const [k, v] of Object.entries(ins)) { if (/^\d+$/.test(k)) f[k] = v && typeof v === 'object' ? v.v : v; }
  return f;
}

export function createOps(profile) {
  const { graph, head, roles } = profile;
  const B0 = head.block;
  const fetchIdx = head.index + 1; // `op = row[opField]`
  const exitLive = new Set(liveness(graph.blocks, null).get(B0));
  const cache = new Map();

  /** the per-op graph with the op fixed, before the instruction's fields are known */
  function opGraph(X) {
    if (cache.has(X)) return cache.get(X);
    const blocks = new Map([...graph.blocks].map(([k, b]) => [k, { stmts: [...b.stmts], term: { ...b.term } }]));
    const hd = blocks.get(B0);
    const after = hd.stmts.slice(fetchIdx + 1);
    blocks.set('S', { stmts: [{ type: 'Assign', targets: [{ type: 'Name', name: roles.op }], values: [num(X)] }, ...after], term: { ...hd.term } });
    blocks.set('EXIT', { stmts: [], term: { kind: 'exit' } });
    for (const [k, b] of blocks) {
      if (k === B0) continue;
      const t = b.term;
      if (t.kind === 'goto' && t.to === B0) b.term = { kind: 'goto', to: 'EXIT' };
      else if (t.kind === 'branch') b.term = { ...t, t: t.t === B0 ? 'EXIT' : t.t, f: t.f === B0 ? 'EXIT' : t.f };
    }
    const { entry } = optimizeCfg(blocks, 'S', { exitLive });
    const r = { blocks, entry };
    cache.set(X, r);
    return r;
  }

  function substFields(node, fields) {
    const sub = (n) => {
      if (!n || typeof n !== 'object') return n;
      if (Array.isArray(n)) return n.map(sub);
      if (n.type === 'Index' && strip(n.obj).type === 'Name' && strip(n.obj).name === roles.row && n.key.type === 'Number') {
        const v = fields[n.key.value];
        if (v !== undefined) return litOf(v);
        return n;
      }
      const c = { ...n };
      for (const k of Object.keys(c)) if (k !== 'line' && k !== 'pos' && c[k] && typeof c[k] === 'object') c[k] = sub(c[k]);
      return c;
    };
    return sub(node);
  }

  /** the graph of one instruction: op and fields known, the program counter known at the start, one exit per way out */
  function specialise(X, ins, pc) {
    const og = opGraph(X);
    const fields = fieldsOf(ins);
    const blocks = new Map();
    for (const [k, b] of og.blocks) blocks.set(k, { stmts: b.stmts.map((s) => substFields(s, fields)), term: b.term.kind === 'branch' ? { ...b.term, cond: substFields(b.term.cond, fields) } : b.term.kind === 'return' && b.term.values ? { ...b.term, values: b.term.values.map((v) => substFields(v, fields)) } : { ...b.term } });
    const e = blocks.get(og.entry);
    e.stmts = [{ type: 'Assign', targets: [{ type: 'Name', name: roles.pc }], values: [num(pc)] }, ...e.stmts];
    // every edge to EXIT gets an exit of its own, so the pc each one leaves with stays known
    let n = 0;
    for (const [, b] of [...blocks]) {
      const t = b.term;
      if (t.kind === 'goto' && t.to === 'EXIT') { const id = `X${n++}`; blocks.set(id, { stmts: [], term: { kind: 'exit' } }); b.term = { kind: 'goto', to: id }; }
      else if (t.kind === 'branch') {
        const nt = { ...t };
        if (t.t === 'EXIT') { const id = `X${n++}`; blocks.set(id, { stmts: [], term: { kind: 'exit' } }); nt.t = id; }
        if (t.f === 'EXIT') { const id = `X${n++}`; blocks.set(id, { stmts: [], term: { kind: 'exit' } }); nt.f = id; }
        b.term = nt;
      }
    }
    const { entry } = optimizeCfg(blocks, og.entry, { exitLive });
    return { blocks, entry };
  }

  // ---- handlers that write the program --------------------------------------------------------------------------------------
  const BUILTIN = {
    lshift: (a, b) => [u32(a << (b & 31))], band: (a, b) => [u32(a) & u32(b)], bor: (a, b) => [u32(u32(a) | u32(b))], bxor: (a, b) => [u32(u32(a) ^ u32(b))],
    byte: (s, i, j) => { i = i ?? 1; j = j ?? i; const out = []; for (let k = i; k <= j; k++) { if (k >= 1 && k <= s.length) out.push(s.charCodeAt(k - 1)); } return out; },
    char: (...n) => [String.fromCharCode(...n)],
    PACKN: (...a) => { const t = new LTable(); a.forEach((v, i) => t.set(i + 1, v)); t.n = a.length; return [t, a.length]; },
    RANGE: (t, i, j) => { const out = []; for (let k = i; k <= j; k++) out.push(t.get(k)); return out; },
    table_move: (src, a, b, t, dst) => { for (let k = a; k <= b; k++) dst.set(t + (k - a), src.get(k)); return [dst]; },
  };
  const HELPER = { pack: (...a) => [{ pk: a }], unpack: (p) => p.pk };
  const touches = new Map();
  /** how the handler for an op uses the code array: writes into it, reads from it (properties of the op, not of the instruction) */
  function codeUse(op) {
    if (touches.has(op)) return touches.get(op);
    const use = { writes: false, reads: false };
    const isCode = (n) => n.type === 'Index' && strip(n.obj).type === 'Name' && strip(n.obj).name === roles.code;
    const scan = (node) => walk(node, (n) => { if (isCode(n)) use.reads = true; });
    for (const b of opGraph(op).blocks.values()) {
      for (const st of b.stmts) {
        if (st.type === 'Assign') for (const t of st.targets) { if (isCode(t)) use.writes = true; else scan(t); }
        if (st.type === 'Assign') st.values.forEach(scan); else scan(st);
      }
      if (b.term.kind === 'branch') scan(b.term.cond);
      else if (b.term.kind === 'return' && b.term.values) scan(b.term.values);
    }
    touches.set(op, use);
    return use;
  }
  const writesCode = (op) => codeUse(op).writes;

  const ev = makeEval({
    resolveIndex(e, env, k, evaluate) {
      const obj = strip(e.obj);
      if (obj.type === 'Name' && obj.name === roles.cells) return { cell: k };
      if (obj.type === 'Name' && obj.name === roles.vm && typeof k === 'string') { const f = HELPER[profile.helpers.get(k)]; if (f) return f; throw new Unknown('vm.' + k); }
      const o = evaluate(obj, env);
      if (o && o.cell !== undefined && k === 3) { const f = BUILTIN[profile.cells.get(o.cell)]; if (!f) throw new Unknown('cell ' + o.cell); return f; }
      return undefined;
    },
    call(f, args) { if (typeof f !== 'function') throw new Unknown('call of ' + typeof f); return f(...args); },
  });

  /** Apply the handlers that rewrite the program to a prototype, in place; returns how many ran. */
  function staticOps(proto) {
    const log = [];
    const code = new LTable(log);
    code.changes = new Set();
    const rows = [];
    proto.code.forEach((ins, i) => {
      const t = new LTable(log);
      t.index = i;
      t.set(head.opField, ins.op);
      for (const [k, v] of Object.entries(ins)) if (/^\d+$/.test(k)) t.set(Number(k), v && typeof v === 'object' ? v.v : v);
      code.set(i + 1, t);
      rows.push(t);
    });
    // a handler changes a few rows: those are found from what the tables report, not by looking at every row after every instruction
    const settle = () => { for (const t of log) t.dirty = false; log.length = 0; code.changes.clear(); };
    settle();
    let applied = 0;
    const note = [];
    for (let pc = 1; pc <= proto.code.length; pc++) {
      const ins = proto.code[pc - 1];
      if (!writesCode(ins.op)) continue;
      // the handler runs against the real row and the real code array: no need to fix the instruction's fields into it first
      const og = opGraph(ins.op);
      const env = new Map([[roles.code, code], [roles.pc, pc], [roles.row, rows[pc - 1]]]);
      try { ev.exec(og.blocks, og.entry, env); } catch (e) { if (e instanceof Unknown) { note.push(`pc ${pc} op ${ins.op}: ${e.message}`); settle(); continue; } throw e; }
      applied++;
      const touched = new Set();
      for (const k of code.changes) touched.add(k - 1);
      for (const t of log) if (t.index !== undefined) touched.add(t.index);
      for (const i of touched) {
        const x = proto.code[i];
        if (!x) continue;
        const t = code.get(i + 1);
        // a row the handler replaced as a whole (an instruction that turns itself into a no-op) is a new object
        if (t === rows[i] && !t.dirty) continue;
        if (t !== rows[i]) { t.index = i; t.log = log; rows[i] = t; }
        const op = t.get(head.opField);
        if (op !== x.op) { x.op = op; x.patched = true; }
        for (const k of Object.keys(x)) if (/^\d+$/.test(k)) { const v = t.get(Number(k)); const cur = x[k] && typeof x[k] === 'object' ? x[k].v : x[k]; if (v !== cur) { if (x[k] && typeof x[k] === 'object') x[k] = { ...x[k], v }; else x[k] = v; x.decrypted = true; } }
      }
      settle();
    }
    return { applied, log: note };
  }

  return { opGraph, specialise, staticOps, exitLive, codeUse };
}
