// What a particular MoonVeil script calls things.
//
// The protector's VM is the same machine in every script it makes, but each script has its own names and its own numbers: the field ids of an
// instruction (op = row[985]), the ids of the opcode map, which cell of the interpreter's list is `string.byte`, which letter is the unpacking
// helper. This module reads those off the script's own code instead of knowing them. If the code is not in the shape this generation of the
// protector produces, it says so (VmUnsupported) rather than guessing.
//
// Input: the factories of the script, by name, twice: as they were written (control flow still flattened: the interpreter's graph is read from
// that) and with the flattening taken out (the wiring, the deserializer and the helper functions are read from that).

import { walk } from '../../core/walk.js';
import { flattenedGraph } from '../moonveil-cff.js';
import { liveness } from '../cfg-opt.js';

export class VmUnsupported extends Error {}
const unsupported = (why) => { throw new VmUnsupported(why); };

const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const count = (node) => { let n = 0; walk(node, () => { n++; }); return n; };
const isFunc = (e) => !!e && e.type === 'Func';

// ---- which factory is which -----------------------------------------------------------------------------------------------------

/** The outer function of a factory entry: `function(vm, cells) return function(registers, varargs) ... end end`. */
const outerOf = (e) => (isFunc(e) ? e : null);
const innerOf = (outer) => {
  const ret = outer.body.find((s) => s.type === 'Return' && s.values.length === 1 && isFunc(strip(s.values[0])));
  return ret ? strip(ret.values[0]) : null;
};

const methodNames = (fn) => { const s = new Set(); walk(fn, (n) => { if (n.type === 'MethodCall') s.add(n.name); }); return s; };

// ---- decision trees -----------------------------------------------------------------------------------------------------------------

const CMP = new Set(['<', '<=', '>', '>=', '==', '~=']);
const FLIP = { '<': '>', '<=': '>=', '>': '<', '>=': '<=', '==': '==', '~=': '~=' };
/** `V op number` (either way round) as [op, number], or null. */
function test(cond, V) {
  const c = strip(cond);
  if (!c || c.type !== 'Binary' || !CMP.has(c.op)) return null;
  const l = strip(c.left);
  const r = strip(c.right);
  if (l.type === 'Name' && (V === undefined || l.name === V) && r.type === 'Number') return [c.op, r.value, l.name];
  if (r.type === 'Name' && (V === undefined || r.name === V) && l.type === 'Number') return [FLIP[c.op], l.value, r.name];
  return null;
}
const holds = (op, a, b) => ({ '<': a < b, '<=': a <= b, '>': a > b, '>=': a >= b, '==': a === b, '~=': a !== b })[op];

/** The body a decision tree reaches for the value `v`. */
function pick(node, V, v) {
  for (;;) {
    let body = null;
    for (const c of node.clauses) {
      const t = test(c.cond, V);
      if (!t) return null;
      if (holds(t[0], v, t[1])) { body = c.body; break; }
    }
    if (!body) body = node.orelse;
    if (!body) return null;
    if (body.length === 1 && body[0].type === 'If' && test(body[0].clauses[0].cond, V)) { node = body[0]; continue; }
    return body;
  }
}

/** Decision trees: an `if` chain whose every test compares the same name with a number, and whose bodies are leaves or more such chains. */
function decisionTrees(fn) {
  const out = [];
  const leaves = (node, V) => {
    let n = 0;
    for (const c of node.clauses) {
      if (c.body.length === 1 && c.body[0].type === 'If' && c.body[0].clauses.every((k) => test(k.cond, V))) n += leaves(c.body[0], V); else n++;
    }
    if (node.orelse) { if (node.orelse.length === 1 && node.orelse[0].type === 'If' && node.orelse[0].clauses.every((k) => test(k.cond, V))) n += leaves(node.orelse[0], V); else n++; }
    return n;
  };
  walk(fn, (n) => {
    if (n.type !== 'If') return undefined;
    const first = test(n.clauses[0].cond);
    if (!first) return undefined;
    const V = first[2];
    if (!n.clauses.every((c) => test(c.cond, V))) return undefined;
    out.push({ node: n, V, leaves: leaves(n, V) });
    return undefined;
  });
  return out.sort((a, b) => b.leaves - a.leaves);
}

// ---- following the lists the factories hand each other ---------------------------------------------------------------------

const isCellCtor = (e) => { e = strip(e); return !!e && e.type === 'Table' && e.fields.length >= 1 && e.fields[0].kind === 'keyed' && e.fields[0].key.type === 'Number' && e.fields[0].key.value === 1 && strip(e.fields[0].value).type === 'Number' && strip(e.fields[0].value).value === 3; };
const cellContent = (e) => { const f = strip(e).fields.find((x) => x.kind === 'keyed' && x.key.type === 'Number' && x.key.value === 3); return f ? f.value : { type: 'Nil' }; };

/**
 * A description (a string) of what an expression is, given what the names in scope are and the list the function was handed.
 * The descriptions are the only thing the cell roles are read from, so they are written to be compared, not to be nice.
 */
function describe(e, env, list, who) {
  e = strip(e);
  switch (e.type) {
    case 'Name': return env.has(e.name) ? env.get(e.name) : `global:${e.name}`;
    case 'Nil': return 'nil';
    case 'Number': return `num:${e.value}`;
    case 'String': return `str:${e.value}`;
    case 'Index': {
      const o = strip(e.obj);
      if (o.type === 'Name' && o.name === who.listName && e.key.type === 'Number') return list[e.key.value - 1];
      if (o.type === 'Index' && strip(o.obj).type === 'Name' && strip(o.obj).name === who.listName && e.key.type === 'Number' && e.key.value === 3) return `value(${list[o.key.value - 1]})`;
      const base = describe(e.obj, env, list, who);
      return e.key.type === 'String' ? `${base}.${e.key.value}` : `${base}[?]`;
    }
    case 'Call': return `${describe(e.fn, env, list, who)}(${e.args.map((a) => describe(a, env, list, who)).join(',')})`;
    case 'MethodCall': {
      const o = strip(e.obj);
      if (o.type === 'Name' && o.name === who.selfName) {
        const arg = e.args.length && strip(e.args[0]).type === 'Table' ? strip(e.args[0]).fields.map((f) => describe(f.value, env, list, who)).join(' | ') : '';
        return `factory:${e.name}[${arg}]`;
      }
      return `${describe(e.obj, env, list, who)}:${e.name}()`;
    }
    case 'Table': return isCellCtor(e) ? `cell(${describe(cellContent(e), env, list, who)})` : (e.fields.length ? 'table{...}' : 'table{}');
    default: return `?${e.type}`;
  }
}

/** Runs a factory's statements for what they bind, and returns the list handed to `next` (a factory name from `nexts`). */
function hop(fn, listIn, nexts, firstHop) {
  const params = fn.params.map((p) => p.name);
  let who;
  let body;
  let env = new Map();
  if (firstHop) {
    who = { selfName: params[0], listName: '\0' };
    body = fn.body;
    env.set(params[0], 'VM');
  } else {
    who = { selfName: params[0], listName: params[1] };
    const inner = innerOf(fn);
    if (!inner) unsupported('a factory in the chain returns no function');
    body = inner.body;
    inner.params.forEach((p, i) => env.set(p.name, `arg${i + 1}@${fn.__name}`));
  }
  let out = null;
  const find = (v) => {
    const mc = strip(v);
    if (mc && mc.type === 'MethodCall' && strip(mc.obj).type === 'Name' && strip(mc.obj).name === who.selfName && nexts.includes(mc.name) && mc.args.length === 1 && strip(mc.args[0]).type === 'Table') {
      out = { next: mc.name, list: strip(mc.args[0]).fields.map((x) => describe(x.value, env, listIn, who)) };
    }
  };
  for (const s of body) {
    if (s.type === 'Local') s.ids.forEach((id, i) => { if (s.values[i]) { env.set(id.name, describe(s.values[i], env, listIn, who)); find(s.values[i]); } else env.set(id.name, 'nil'); });
    else if (s.type === 'Assign') {
      s.targets.forEach((t, i) => {
        const v = s.values[i];
        if (!v) return;
        if (t.type === 'Name') env.set(t.name, describe(v, env, listIn, who));
        else if (t.type === 'Index' && strip(t.obj).type === 'Name' && t.key.type === 'Number' && t.key.value === 3) env.set(strip(t.obj).name, `cell(${describe(v, env, listIn, who)})`);
        find(v);
      });
    }
  }
  return out;
}

/** The names a cell description stands for in the interpreter's source, by what the description says. */
const BUILTINS = {
  'bit32.lshift': 'lshift', 'bit32.rshift': 'rshift', 'bit32.band': 'band', 'bit32.bor': 'bor', 'bit32.bxor': 'bxor', 'bit32.btest': 'btest', 'bit32.bnot': 'bnot',
  'table.insert': 'table_insert', 'table.create': 'table_create', 'table.move': 'table_move', 'table.pack': 'table_pack', 'table.unpack': 'table_unpack',
  'string.unpack': 'string_unpack', 'string.gmatch': 'gmatch', 'string.byte': 'byte', 'string.char': 'char', 'string.sub': 'string_sub', 'string.rep': 'string_rep',
  setmetatable: 'setmetatable', getmetatable: 'getmetatable', type: 'type', pairs: 'pairs', ipairs: 'ipairs', tonumber: 'tonumber', select: 'select', pcall: 'pcall', error: 'error',
};
function roleOf(desc) {
  let m = /^cell\(global:(.+)\)$/.exec(desc);
  if (m && BUILTINS[m[1]]) return BUILTINS[m[1]];
  if (desc === 'cell(VM)') return 'VM';
  if (desc === 'cell(table{})') return 'WEAKMETA';
  if (/^cell\(arg1@/.test(desc)) return 'PROTO';
  if (/^cell\(arg2@/.test(desc)) return 'UPVALS';
  if (/^cell\(value\(cell\(global:getfenv\)\)\(\)\)$/.test(desc)) return 'ENV';
  if (/^cell\(factory:[^[]+\[cell\(global:select\)\]\)$/.test(desc)) return 'PACKN';
  if (/^cell\(factory:[^[]+\[cell\(nil\)\]\)$/.test(desc)) return 'RANGE';
  if (/^cell\(factory:[^[]+\[cell\(global:string\.byte\) \|/.test(desc)) return 'CLOSURE';
  return null;
}

// ---- reading the deserializer -----------------------------------------------------------------------------------------------

/** Every body a decision tree can end in. */
function leavesOf(node, V) {
  const out = [];
  const isTree = (body) => body.length === 1 && body[0].type === 'If' && body[0].clauses.every((k) => test(k.cond, V));
  const visit = (n) => {
    for (const c of n.clauses) { if (isTree(c.body)) visit(c.body[0]); else out.push(c.body); }
    if (n.orelse) { if (isTree(n.orelse)) visit(n.orelse[0]); else out.push(n.orelse); }
  };
  visit(node);
  return out;
}

const FORMAT = /^(B|<I2|<i2|<i4|<I4)$/;
const readsField = (body) => has({ type: 'Do', body }, (n) => n.type === 'Call' && n.args.length >= 1 && strip(n.args[0]).type === 'String' && FORMAT.test(strip(n.args[0]).value));
const numberAssign = (s) => s.type === 'Assign' && s.targets.length === 1 && s.targets[0].type === 'Name' && strip(s.values[0]).type === 'Number';
const singleNumber = (body) => body.length === 1 && numberAssign(body[0]);

/** opcode id -> class, and class -> layout, from the two decision trees in the deserializer. */
function readOpcodeTables(deser) {
  const trees = decisionTrees(deser).map((t) => ({ ...t, bodies: leavesOf(t.node, t.V) }));
  const mapTree = trees.find((t) => t.bodies.length >= 50 && t.bodies.filter((b) => singleNumber(b) || (b.length >= 1 && b.every(singleNumber))).length >= 0.9 * t.bodies.length);
  if (!mapTree) unsupported('no opcode map in the deserializer');
  const classTree = trees.find((t) => t !== mapTree && t.bodies.length >= 5 && t.bodies.filter(readsField).length >= 5);
  if (!classTree) unsupported('no instruction layouts in the deserializer');
  const opMap = [];
  for (let id = 0; id <= 65535; id++) {
    const leaf = pick(mapTree.node, mapTree.V, id);
    const a = leaf && leaf.find(numberAssign);
    opMap.push(a ? strip(a.values[0]).value : null);
  }
  const classes = [...new Set(opMap.filter((x) => x !== null))].sort((a, b) => a - b);
  // a layout: the fields stored in a leaf from `read("<format>")` calls on the cell that reads bytes
  const cell = (e) => { e = strip(e); return e.type === 'Index' && strip(e.obj).type === 'Index' && strip(strip(e.obj).obj).type === 'Name' && e.key.type === 'Number' && e.key.value === 3 && strip(e.obj).key.type === 'Number' ? strip(e.obj).key.value : null; };
  const layouts = {};
  for (const c of classes) {
    const leaf = pick(classTree.node, classTree.V, c);
    if (!leaf) unsupported(`no layout for instruction class ${c}`);
    const env = new Map();
    const fields = [];
    const ev = (e) => {
      e = strip(e);
      if (e.type === 'Name') return env.get(e.name) || null;
      const k = cell(e);
      if (k !== null) return { cell: k };
      if (e.type === 'Call') {
        const f = ev(e.fn);
        if (f && f.cell !== undefined && e.args[0] && strip(e.args[0]).type === 'String' && FORMAT.test(strip(e.args[0]).value)) return { read: strip(e.args[0]).value };
        return null;
      }
      return null;
    };
    for (const s of leaf) {
      if (s.type !== 'Assign') continue;
      const vals = s.values.map(ev);
      s.targets.forEach((t, i) => {
        if (t.type === 'Name') { if (vals[i]) env.set(t.name, vals[i]); else env.delete(t.name); } else if (t.type === 'Index' && t.key.type === 'Number' && vals[i] && vals[i].read) fields.push([t.key.value, vals[i].read]);
      });
    }
    layouts[c] = fields;
  }
  return { opMap, layouts };
}

/**
 * Fields whose stored value is an index into the constants: the deserializer reads `row[F]` and uses it as the key of a table lookup
 * (`row[F] = row[F] ~= 0 and consts[row[F]] or 0`, which once the control flow is rebuilt reads `k = row[F]; v = consts[k]`).
 */
function readConstFields(deser, fieldIds) {
  const out = new Set();
  const fieldRead = (e) => { e = strip(e); return e && e.type === 'Index' && strip(e.obj).type === 'Name' && e.key.type === 'Number' && fieldIds.has(e.key.value) ? e.key.value : null; };
  walk(deser, (n) => {
    // consts[row[F]]
    if (n.type === 'Index' && n.key.type === 'Index') { const f = fieldRead(n.key); if (f !== null) out.add(f); }
    // k = row[F] ... v = consts[k]
    const list = Array.isArray(n.body) ? n.body : null;
    if (!list) return;
    list.forEach((s, i) => {
      if (s.type !== 'Assign' || s.targets.length !== 1 || s.targets[0].type !== 'Name' || s.values.length !== 1) return;
      const f = fieldRead(s.values[0]);
      if (f === null) return;
      const key = s.targets[0].name;
      for (const later of list.slice(i + 1, i + 5)) {
        walk(later, (m) => { if (m.type === 'Index' && strip(m.key).type === 'Name' && strip(m.key).name === key && strip(m.obj).type === 'Name') out.add(f); });
        if (later.type === 'Assign' && later.targets.some((t) => t.type === 'Name' && t.name === key)) break;
      }
    });
  });
  return [...out];
}

/** The first byte of a prototype is checked against its magic number: anything else is a stub. */
function readMagic(deser) {
  const inner = innerOf(deser);
  const body = (inner || deser).body;
  for (const s of body.slice(0, 16)) {
    if (s.type !== 'If') continue;
    const c = strip(s.clauses[0].cond);
    if (c.type === 'Binary' && c.op === '~=' && strip(c.right).type === 'Number') return strip(c.right).value;
  }
  return null;
}

// ---- the interpreter ------------------------------------------------------------------------------------------------------------------

/** The fetch at the head of the dispatch loop: `row = code[pc]; op = row[F]; pc = pc + 1`. */
function findHead(graph) {
  for (const [id, b] of graph.blocks) {
    for (let i = 0; i + 2 < b.stmts.length; i++) {
      const [a, o, p] = [b.stmts[i], b.stmts[i + 1], b.stmts[i + 2]];
      if (a.type !== 'Assign' || a.targets.length !== 1 || a.targets[0].type !== 'Name' || a.values.length !== 1) continue;
      const fa = strip(a.values[0]);
      if (fa.type !== 'Index' || strip(fa.obj).type !== 'Name' || strip(fa.key).type !== 'Name') continue;
      if (o.type !== 'Assign' || o.targets.length !== 1 || o.targets[0].type !== 'Name' || o.values.length !== 1) continue;
      const fo = strip(o.values[0]);
      if (fo.type !== 'Index' || strip(fo.obj).type !== 'Name' || strip(fo.obj).name !== a.targets[0].name || fo.key.type !== 'Number') continue;
      if (p.type !== 'Assign' || p.targets.length !== 1 || p.targets[0].type !== 'Name' || p.targets[0].name !== strip(fa.key).name) continue;
      return { block: id, index: i, rowVar: a.targets[0].name, codeVar: strip(fa.obj).name, pcVar: strip(fa.key).name, opVar: o.targets[0].name, opField: fo.key.value };
    }
  }
  return null;
}

/**
 * What the interpreter's first block sets up, by following its assignments: the number the program counter starts at, the "top of results"
 * marker (-1), the cache of open upvalues (a `setmetatable` result) and which variables hold fields of the prototype it is running.
 */
function findEntryRoles(graph, head, cells, cellsVar) {
  const env = new Map();
  const cellOf = (e) => {
    e = strip(e);
    if (e && e.type === 'Index' && e.key.type === 'Number' && e.key.value === 3) {
      const o = strip(e.obj);
      if (o.type === 'Index' && strip(o.obj).type === 'Name' && strip(o.obj).name === cellsVar && o.key.type === 'Number') return o.key.value;
    }
    return null;
  };
  const describeValue = (e) => {
    e = strip(e);
    if (!e) return null;
    if (e.type === 'Number') return { num: e.value };
    if (e.type === 'Unary' && e.op === '-' && strip(e.arg).type === 'Number') return { num: -strip(e.arg).value };
    if (e.type === 'Table' && !e.fields.length) return { table: true };
    if (e.type === 'Name') return env.get(e.name) || null;
    const c = cellOf(e);
    if (c !== null) return { cell: c };
    if (e.type === 'Index' && e.key.type === 'Number') {
      const o = describeValue(e.obj);
      if (o && o.cell !== undefined && cells.get(o.cell) === 'PROTO') return { field: e.key.value };
    }
    if (e.type === 'Call') {
      const f = describeValue(e.fn);
      if (f && f.cell !== undefined && cells.get(f.cell) === 'setmetatable') return { cache: true };
    }
    return null;
  };
  // the straight-line blocks from the entry up to the loop head
  const chain = [];
  for (let id = graph.entry, i = 0; i < 8; i++) {
    chain.push(graph.blocks.get(id));
    if (id === head.block) break;
    const t = graph.blocks.get(id).term;
    if (t.kind !== 'goto') break;
    id = t.to;
  }
  for (const b of chain) {
    for (const s of b.stmts) {
      if (s.type !== 'Assign') continue;
      const vals = s.values.map(describeValue);
      s.targets.forEach((t, i) => { if (t.type === 'Name') { if (vals[i]) env.set(t.name, vals[i]); else env.delete(t.name); } });
    }
  }
  const find = (pred) => { for (const [name, d] of env) if (pred(d)) return name; return null; };
  const fields = new Map();
  for (const [name, d] of env) if (d.field !== undefined) fields.set(name, d.field);
  return { top: find((d) => d.num === -1), upvalueCache: find((d) => d.cache), pc: find((d) => d.num === 1), fields };
}

/**
 * How the interpreter uses the lists read from its prototype: an item that is called later (through any chain of copies) comes from the list of
 * native functions, an item handed to the closure maker (the cell that makes functions) comes from the list of child prototypes.
 */
function listUses(graph, lists, cells, cellsVar) {
  const out = new Map(lists.map((n) => [n, { called: false, closed: false }]));
  const cellOf = (e) => {
    e = strip(e);
    if (e && e.type === 'Index' && e.key.type === 'Number' && e.key.value === 3) { const o = strip(e.obj); if (o.type === 'Index' && strip(o.obj).type === 'Name' && strip(o.obj).name === cellsVar && o.key.type === 'Number') return o.key.value; }
    return null;
  };
  for (const b of graph.blocks.values()) {
    const origin = new Map(); // name -> {list} | {cell}
    const of = (e) => {
      e = strip(e);
      if (!e) return null;
      if (e.type === 'Name') return origin.get(e.name) || null;
      if (e.type === 'Index' && strip(e.obj).type === 'Name' && lists.includes(strip(e.obj).name) && !(e.key.type === 'Number' && e.key.value === 3)) return { list: strip(e.obj).name };
      const c = cellOf(e);
      return c !== null ? { cell: c } : null;
    };
    const visit = (node) => walk(node, (n) => {
      if (n.type !== 'Call') return;
      const f = of(n.fn);
      if (f && f.list) out.get(f.list).called = true;
      if (f && f.cell !== undefined && cells.get(f.cell) === 'CLOSURE' && n.args.length) { const a = of(n.args[0]); if (a && a.list) out.get(a.list).closed = true; }
    });
    for (const s of b.stmts) {
      visit(s);
      if (s.type === 'Assign') {
        const vals = s.values.map(of);
        s.targets.forEach((t, i) => { if (t.type === 'Name') { if (vals[i]) origin.set(t.name, vals[i]); else origin.delete(t.name); } });
      } else if (s.type === 'Local') s.ids.forEach((id) => origin.delete(id.name));
    }
    if (b.term.kind === 'branch') visit(b.term.cond);
    else if (b.term.kind === 'return' && b.term.values) visit(b.term.values);
  }
  return out;
}

/**
 * The two fields of the table a function with `...` hands its interpreter, read off the factory that makes such functions: one starts as an
 * empty table (the extra arguments), the other as the number 0 (how many there are).
 */
function findVarargFields(wrapper) {
  if (!wrapper) return null;
  const empty = new Set();
  walk(wrapper, (n) => {
    if (n.type === 'Assign') n.targets.forEach((t, i) => { const v = n.values[i] && strip(n.values[i]); if (t.type === 'Name' && v && v.type === 'Table' && !v.fields.length) empty.add(t.name); });
    else if (n.type === 'Local') n.ids.forEach((id, i) => { const v = n.values[i] && strip(n.values[i]); if (v && v.type === 'Table' && !v.fields.length) empty.add(id.name); });
  });
  // copies of those tables under other names
  const copies = [];
  walk(wrapper, (n) => {
    if (n.type === 'Assign') n.targets.forEach((t, i) => { const v = n.values[i] && strip(n.values[i]); if (t.type === 'Name' && v && v.type === 'Name') copies.push([t.name, v.name]); });
  });
  for (let changed = true; changed;) {
    changed = false;
    for (const [to, from] of copies) if (empty.has(from) && !empty.has(to)) { empty.add(to); changed = true; }
  }
  let list = null;
  let count = null;
  walk(wrapper, (n) => {
    if (n.type !== 'Assign') return;
    n.targets.forEach((t, i) => {
      const v = n.values[i] && strip(n.values[i]);
      if (t.type !== 'Index' || t.key.type !== 'Number' || !v) return;
      if (v.type === 'Number' && v.value === 0) count = count ?? t.key.value;
      else if (v.type === 'Name' && empty.has(v.name)) list = list ?? t.key.value;
    });
  });
  return list !== null && count !== null ? { list, count } : null;
}

// ---- the VM object's helpers ----------------------------------------------------------------------------------------------------

const has = (node, pred) => { let hit = false; walk(node, (n) => { if (pred(n)) hit = true; }); return hit; };
/** pack / unpack / iter / fill, by what their code does. */
function classifyHelper(node) {
  if (!node) return null;
  if (has(node, (n) => (n.type === 'Index' && n.key.type === 'String' && n.key.value === '__iter') || (n.type === 'String' && n.value === '__iter'))) return 'iter';
  if (has(node, (n) => n.type === 'Call' && strip(n.fn).type === 'Name' && strip(n.fn).name === 'select' && n.args.length && strip(n.args[0]).type === 'String' && strip(n.args[0]).value === '#')
    && has(node, (n) => n.type === 'Table' && n.fields.some((f) => strip(f.value).type === 'Vararg'))) {
    // pack returns the list and the count; fill stores a list from a position
    return has(node, (n) => n.type === 'NumFor') ? 'fill' : 'pack';
  }
  if (has(node, (n) => n.type === 'Index' && n.key.type === 'Number' && n.key.value === 2) && has(node, (n) => n.type === 'Index' && n.key.type === 'Number' && n.key.value === 1) && has(node, (n) => n.type === 'Func')) return 'unpack';
  return null;
}

/** sha256 / chacha by the constants in their code, through the factories they call. */
function cryptoMethods(map, wanted) {
  const reach = (name, seen = new Set()) => {
    if (seen.has(name) || !map.has(name)) return seen;
    seen.add(name);
    for (const m of methodNames(map.get(name))) reach(m, seen);
    return seen;
  };
  const found = {};
  for (const name of wanted) {
    const nodes = [...reach(name)].map((n) => map.get(n));
    if (nodes.some((n) => has(n, (x) => x.type === 'Number' && x.value === 1116352408))) { found.sha256 = name; continue; }
    // chacha: four stores of numbers into positions 1..4 of one table (the state's constants)
    for (const n of nodes) {
      let constants = null;
      walk(n, (x) => {
        if (constants || !Array.isArray(x.body)) return;
        const s = x.body;
        for (let i = 0; i + 3 < s.length; i++) {
          const ok = [0, 1, 2, 3].every((k) => s[i + k].type === 'Assign' && s[i + k].targets.length === 1 && s[i + k].targets[0].type === 'Index' && s[i + k].targets[0].key.type === 'Number' && s[i + k].targets[0].key.value === k + 1 && strip(s[i + k].values[0]).type === 'Number');
          if (ok) { constants = [0, 1, 2, 3].map((k) => strip(s[i + k].values[0]).value); return; }
        }
      });
      if (constants && has(n, (y) => y.type === 'String' && /^<I4/.test(y.value))) { found.chacha = name; found.chachaConstants = constants; }
    }
  }
  return found;
}

// ---- putting it together ------------------------------------------------------------------------------------------------------------

/**
 * @param {{map: Map<string, object>}} pre   the factories as written (flattened)
 * @param {{map: Map<string, object>}} post  the same factories after the control flow was rebuilt
 */
export function deriveProfile(pre, post) {
  // the interpreter is the largest factory; the deserializer the one that holds the opcode tables
  const sizes = [...post.map].filter(([, v]) => isFunc(v)).map(([k, v]) => [k, count(v)]).sort((a, b) => b[1] - a[1]);
  if (sizes.length < 6) unsupported('too few factories');
  const ueName = sizes[0][0];
  const ue = outerOf(post.map.get(ueName));
  const ueInner = innerOf(ue);
  if (!ueInner || ue.params.length !== 2 || ueInner.params.length < 2) unsupported('the interpreter does not have the expected shape');
  const deserName = sizes.slice(1).map(([k]) => k).find((k) => { try { return decisionTrees(post.map.get(k)).filter((t) => t.leaves >= 50).length >= 2; } catch { return false; } });
  if (!deserName) unsupported('no deserializer');
  const deser = outerOf(post.map.get(deserName));

  // the wiring: the factory that builds the first list is the one with a long list in a method call and no list parameter
  const bigCalls = [];
  for (const [name, fn] of post.map) {
    if (!isFunc(fn)) continue;
    walk(fn, (n) => { if (n.type === 'MethodCall' && n.args.length === 1 && strip(n.args[0]).type === 'Table' && strip(n.args[0]).fields.length >= 20) bigCalls.push([name, n.name]); });
  }
  const called = new Set(bigCalls.map(([, c]) => c));
  const startName = [...new Set(bigCalls.map(([n]) => n))].find((n) => !called.has(n));
  if (!startName) unsupported('no starting point for the interpreter’s wiring');
  const nameOf = (fn) => [...post.map].find(([, v]) => v === fn)?.[0];
  const withName = (name) => { const f = outerOf(post.map.get(name)); if (!f) unsupported(`${name} is not a function`); f.__name = name; return f; };
  let cur = hop(withName(startName), [], bigCalls.filter(([n]) => n === startName).map(([, c]) => c), true);
  if (!cur) unsupported('the first factory hands no list on');
  let guard = 0;
  let maker = startName;
  while (cur.next !== ueName) {
    if (++guard > 6) unsupported('the wiring is longer than expected');
    maker = cur.next;
    const nextFn = withName(cur.next);
    const nexts = [...new Set(bigCalls.filter(([n]) => n === cur.next).map(([, c]) => c).concat(methodNames(nextFn).has(ueName) ? [ueName] : []))];
    const nx = hop(nextFn, cur.list, nexts, false);
    if (!nx) unsupported(`${cur.next} hands no list on`);
    cur = nx;
  }
  if (cur.list.length < 20) unsupported('the interpreter gets too few cells');
  const cells = new Map();
  cur.list.forEach((d, i) => {
    const role = roleOf(d);
    if (!role) unsupported(`cell ${i + 1} of the interpreter is not one this reader knows (${d.slice(0, 80)})`);
    cells.set(i + 1, role);
  });

  // the deserializer's tables
  const { opMap, layouts } = readOpcodeTables(deser);
  const protoMagic = readMagic(deser);
  // every field of an instruction that is stored, and the op field the interpreter reads
  const fieldIds = new Set();
  for (const f of Object.values(layouts)) for (const [k] of f) fieldIds.add(k);
  const constFields = readConstFields(deser, fieldIds);
  if (protoMagic === null) unsupported('no magic number in the deserializer');

  // the interpreter's graph, from the flattened original
  const preUe = outerOf(pre.map.get(ueName));
  const preInner = innerOf(preUe);
  if (!preInner) unsupported('the interpreter as written has no inner function');
  const graph = flattenedGraph(preInner);
  const head = findHead(graph);
  if (!head) unsupported('no instruction fetch at the head of the interpreter');
  const roles = {
    vm: ue.params[0].name, cells: ue.params[1].name,
    regs: preInner.params[0].name, varargs: preInner.params[1].name,
    code: head.codeVar, pc: head.pcVar, row: head.rowVar, op: head.opVar,
  };
  const entry = findEntryRoles(graph, head, cells, roles.cells);
  if (!entry.top) unsupported('no top-of-results variable');
  if (!entry.upvalueCache) unsupported('no cache of open upvalues');
  roles.top = entry.top;
  roles.upvalueCache = entry.upvalueCache;
  // the prototype's other two lists: the one whose items are called is the list of native functions, the one whose items go to the closure maker the children
  const listVars = [...entry.fields.keys()].filter((n) => n !== roles.code);
  const use = listUses(graph, listVars, cells, roles.cells);
  const natives = listVars.filter((n) => use.get(n).called && !use.get(n).closed);
  const children = listVars.filter((n) => use.get(n).closed && !use.get(n).called);
  if (listVars.length !== 2 || natives.length !== 1 || children.length !== 1) unsupported('the prototype fields the interpreter reads are not the ones expected');
  roles.natives = natives[0];
  roles.children = children[0];
  // the function a script's own functions are made of is built next to the interpreter, by the factory that builds the interpreter
  let va = null;
  for (const name of methodNames(outerOf(post.map.get(maker)))) {
    if (name === ueName || !post.map.has(name) || !outerOf(post.map.get(name))) continue;
    va = findVarargFields(innerOf(outerOf(post.map.get(name))));
    if (va) break;
  }
  if (!va) unsupported('no argument fields');

  // the helpers the interpreter reaches through its VM object
  const vmMembers = new Set();
  walk(preInner, (n) => { if (n.type === 'Index' && strip(n.obj).type === 'Name' && strip(n.obj).name === roles.vm && n.key.type === 'String') vmMembers.add(n.key.value); });
  const helpers = new Map();
  for (const m of vmMembers) {
    const kind = classifyHelper(post.map.get(m));
    if (kind) helpers.set(m, kind);
  }
  const crypto = cryptoMethods(post.map, [...vmMembers].filter((m) => !helpers.has(m)));


  return {
    names: { interpreter: ueName, deserializer: deserName },
    roles, cells, helpers, crypto, members: [...vmMembers],
    head: { block: head.block, index: head.index, opField: head.opField },
    graph, entry: graph.entry,
    opMap, layouts, constFields, protoMagic,
    fieldIds: [head.opField, ...fieldIds],
    varargs: va,
  };
}

/** Names live at the loop head: what carries from one instruction to the next. */
export function loopCarried(profile) {
  return new Set(liveness(profile.graph.blocks, null).get(profile.head.block));
}
