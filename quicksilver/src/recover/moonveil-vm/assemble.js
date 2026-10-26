// A prototype, written out as a Lua function: its lifted graph structured into statements, its registers named, the closures it makes written
// in place (a child prototype becomes the nested function; a native the VM calls becomes that function with its captured variables filled in).

import { structure } from '../../decompile/cfg.js';
import { gotoBlocks } from '../moonveil-cff.js';
import { forIn, renameScratch, dotKeys, renameRegisters, substituteUpvalues, declareLocals } from '../moonveil-polish.js';

const negate = (c) => (c.type === 'Unary' && c.op === 'not' ? c.arg : { type: 'Unary', op: 'not', arg: c.type === 'Binary' ? { type: 'Paren', expr: c } : c });
const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
/** Register names by nesting depth: r1, s1, t1 ... */
const PREFIX = ['r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'q', 'o'];

export function createAssembler(profile, lifter, natives, { onProto } = {}) {
  const { varargs } = profile;
  const cache = new Map();

  // The arguments of a function with `...` live in two fields of the interpreter's frame; they are read as a pack made at the start
  function prepareVarargs(blocks, entry) {
    let used = false;
    const sub = (n) => {
      if (!n || typeof n !== 'object') return n;
      if (Array.isArray(n)) return n.map(sub);
      if (n.type === 'Index' && strip(n.obj).type === 'Name' && strip(n.obj).name === 'VARARGS' && n.key.type === 'Number' && (n.key.value === varargs.list || n.key.value === varargs.count)) { used = true; return { type: 'Name', name: n.key.value === varargs.list ? 'va_list' : 'va_n' }; }
      const c = { ...n };
      for (const k of Object.keys(c)) if (k !== 'line' && c[k] && typeof c[k] === 'object') c[k] = sub(c[k]);
      return c;
    };
    for (const b of blocks.values()) {
      b.stmts = sub(b.stmts);
      if (b.term.kind === 'branch') {
        let cond = sub(b.term.cond);
        // "are there arguments?" is asked of the count field, which exists for every function that takes `...`
        if (strip(cond).type === 'Name' && strip(cond).name === 'va_n') cond = { type: 'True' };
        b.term = { ...b.term, cond };
      } else if (b.term.kind === 'return' && b.term.values) b.term = { ...b.term, values: sub(b.term.values) };
    }
    if (!used) return entry;
    const pack = { type: 'Call', fn: { type: 'Index', obj: { type: 'Name', name: 'table' }, key: { type: 'String', value: 'pack', raw: null }, dot: true }, args: [{ type: 'Vararg' }], sugar: null };
    blocks.set('VA', { stmts: [
      { type: 'Assign', targets: [{ type: 'Name', name: 'va_list' }], values: [pack] },
      { type: 'Assign', targets: [{ type: 'Name', name: 'va_n' }], values: [{ type: 'Index', obj: { type: 'Name', name: 'va_list' }, key: { type: 'String', value: 'n', raw: null }, dot: true }] },
    ], term: { kind: 'goto', to: entry } });
    return 'VA';
  }

  // `table.unpack(va_list)` is `...`, and the pack and its size go when nothing else reads them
  function finishVarargs(body) {
    const swap = (n) => {
      if (!n || typeof n !== 'object') return n;
      if (Array.isArray(n)) return n.map(swap);
      const c = { ...n };
      for (const k of Object.keys(c)) if (k !== 'line' && c[k] && typeof c[k] === 'object') c[k] = swap(c[k]);
      if (c.type === 'Call' && c.args.length === 1 && strip(c.args[0]).type === 'Name' && strip(c.args[0]).name === 'va_list' && strip(c.fn).type === 'Index' && strip(c.fn).key.value === 'unpack') return { type: 'Vararg' };
      if (c.type === 'Index' && strip(c.obj).type === 'Name' && strip(c.obj).name === 'va_list' && c.key.type === 'String' && c.key.value === 'n') return { type: 'Call', fn: { type: 'Name', name: 'select' }, args: [{ type: 'String', value: '#', raw: null }, { type: 'Vararg' }], sugar: null };
      return c;
    };
    let out = swap(body);
    // remove the definitions when no other statement mentions the names
    const mentions = (name) => { let n = 0; (function w(x) { if (!x || typeof x !== 'object') return; if (Array.isArray(x)) return x.forEach(w); if (x.type === 'Name' && x.name === name) n++; for (const k of Object.keys(x)) if (k !== 'line' && typeof x[k] === 'object') w(x[k]); })(out); return n; };
    const isDef = (st, name) => st.type === 'Assign' && st.targets.length === 1 && st.targets[0].type === 'Name' && st.targets[0].name === name;
    for (const name of ['va_n', 'va_list']) {
      const defs = out.filter((st) => isDef(st, name)).length;
      if (mentions(name) === defs) out = out.filter((st) => !isDef(st, name));
    }
    return out;
  }

  function liftBody(proto) {
    if (cache.has(proto)) return cache.get(proto);
    const lifted = lifter.liftGraph(proto);
    const { blocks } = lifted;
    const entry = prepareVarargs(blocks, lifted.entry);
    const { entry: e2 } = lifter.cleanGraph(blocks, entry);
    let body; let structured = true;
    try { body = structure(blocks, e2, { negate, makeReturn: (v) => ({ type: 'Return', values: v || [] }) }); } catch { structured = false; body = gotoBlocks(blocks, e2); }
    body = forIn(body);
    body = finishVarargs(body);
    body = renameScratch(body);
    const r = { body, structured };
    cache.set(proto, r);
    return r;
  }

  const upName = (v) => ({ type: 'Name', name: `up${strip(v.args[0]).value}` });
  function replaceClosures(node, proto, depth, stats) {
    if (!node || typeof node !== 'object') return node;
    if (Array.isArray(node)) return node.map((x) => replaceClosures(x, proto, depth, stats));
    const c = { ...node };
    for (const k of Object.keys(c)) if (k !== 'line' && c[k] && typeof c[k] === 'object') c[k] = replaceClosures(c[k], proto, depth, stats);
    // a function the VM calls natively: natives[k](VM, { captured variables })
    if (c.type === 'Call' && strip(c.fn).type === 'Index' && strip(strip(c.fn).obj).type === 'Name' && strip(strip(c.fn).obj).name === profile.roles.natives && strip(c.fn).key.type === 'Number' && c.args.length === 2 && strip(c.args[1]).type === 'Table') {
      const caps = strip(c.args[1]).fields.map((f) => {
        const v = strip(f.value);
        if (v.type === 'Call' && strip(v.fn).type === 'Name' && strip(v.fn).name === 'ref') return v.args[0];
        if (v.type === 'Call' && strip(v.fn).type === 'Name' && strip(v.fn).name === 'upref') return upName(v);
        return null;
      });
      if (caps.every(Boolean)) { const fn = natives.instantiate(proto.names[strip(c.fn).key.value - 1], caps); if (fn) { stats.natives = (stats.natives || 0) + 1; return fn; } }
    }
    if (c.type === 'Call' && strip(c.fn).type === 'Name' && strip(c.fn).name === 'CLOSURE' && c.args.length >= 1) {
      const ref = strip(c.args[0]);
      if (ref.type === 'Index' && strip(ref.obj).name === 'CHILDREN' && ref.key.type === 'Number') {
        const child = proto.children[ref.key.value - 1];
        if (child && !child.stub) {
          const caps = c.args[1] ? strip(c.args[1]).fields || [] : [];
          const map = new Map();
          caps.forEach((f, i) => {
            const v = strip(f.value);
            if (v.type === 'Call' && strip(v.fn).type === 'Name' && strip(v.fn).name === 'ref') map.set(i + 1, v.args[0]);
            else if (v.type === 'Call' && strip(v.fn).type === 'Name' && strip(v.fn).name === 'upref') map.set(i + 1, upName(v));
          });
          const fn = assemble(child, depth + 1, stats);
          stats.closures++;
          return { type: 'Func', params: fn.params, vararg: fn.vararg, body: substituteUpvalues(fn.body, map), isMethod: false, generics: null, returnType: null, line: c.line };
        }
      }
    }
    return c;
  }

  function assemble(proto, depth = 0, stats = { closures: 0, goto: 0, protos: 0 }) {
    const prefix = PREFIX[depth] || `d${depth}_`;
    const lifted = liftBody(proto);
    if (onProto) onProto(proto);
    stats.protos++;
    if (!lifted.structured) stats.goto++;
    let body = renameRegisters(lifted.body, prefix);
    body = replaceClosures(body, proto, depth, stats);
    body = dotKeys(body);
    // a trailing `return` with nothing after it says nothing
    while (body.length && body[body.length - 1].type === 'Return' && (!body[body.length - 1].values || !body[body.length - 1].values.length)) body = body.slice(0, -1);
    const params = Array.from({ length: proto.nparams }, (_, i) => `${prefix}${i + 1}`);
    body = declareLocals(body, prefix, params);
    return { params: params.map((n) => ({ type: 'Id', name: n })), vararg: !!proto.flag, body };
  }

  return { assemble, liftBody };
}
