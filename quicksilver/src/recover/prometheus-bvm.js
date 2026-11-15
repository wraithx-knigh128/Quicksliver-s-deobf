// Prometheus' register VM (the `Vmify` step since November 2026, src/prometheus/vm/ upstream).
//
// The compiler turns every function into a prototype of semantic instructions (LOAD, MOVE, CALL ...) and emits:
//
//     local function rebuild(shards, count, root) ... end          -- turns the records back into tables
//     return (function(prototypes, ...) <interpreter> end)(rebuild({ { {t, k, v[, 1]}, ... }, ... }, count, root), ...)
//
// Each record says "table t has value v at key k" (v is the id of another table when the fourth field is 1). The tables are
// the prototypes: seven fields under keys drawn per build (code, constants, captures, params, vararg, maxRegister, children),
// instructions `{ opcode, [slot] = operand ... }` with the opcode numbers shuffled per build and the four operands spread over
// slots 2..5 in a per-build order. None of that is secret: the data is a literal, the field meanings follow from what the
// values are, the operand slots are the interpreter's fetch (`a, b, c, d = I[s1], I[s2], I[s3], I[s4]`) and an opcode's
// meaning is what its handler does. This module reads all of it without running anything and writes each prototype back as
// a Lua function: registers become locals, jumps become blocks for the structurer, the value lists calls pass and return
// (`{ [count] = n, ... }`) become argument lists again where they are used once.
//
// Nothing here is guessed: a prototype field, an operand slot or an opcode that cannot be told refuses the lift, and the
// script stays as it was.

import { analyze } from '../core/scope.js';
import { walk } from '../core/walk.js';
import { print } from '../core/printer.js';
import { structure, CfgError } from '../decompile/cfg.js';

export class BvmError extends Error {}
const fail = (m) => { throw new BvmError(m); };
const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const N = (name) => ({ type: 'Name', name });
const num = (value) => (value < 0 || Object.is(value, -0) ? { type: 'Unary', op: '-', arg: { type: 'Number', value: -value, raw: null } } : { type: 'Number', value, raw: null });
const str = (value) => ({ type: 'String', value, raw: null });
const call = (fn, args) => ({ type: 'Call', fn: typeof fn === 'string' ? N(fn) : fn, args });
const idx = (obj, key) => ({ type: 'Index', obj, key, dot: false });
const assign = (targets, values) => ({ type: 'Assign', targets, values });
const IDENT = /^[A-Za-z_][A-Za-z0-9_]*$/;
const RESERVED = new Set(['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while']);

// ---- constants of the literal --------------------------------------------------------------------------------------

function constOf(e) {
  e = strip(e);
  if (!e) return undefined;
  if (e.type === 'Number') return { t: 'num', v: e.value };
  if (e.type === 'String') return { t: 'str', v: e.value };
  if (e.type === 'True') return { t: 'bool', v: true };
  if (e.type === 'False') return { t: 'bool', v: false };
  if (e.type === 'Unary' && e.op === '-') { const x = constOf(e.arg); return x && x.t === 'num' ? { t: 'num', v: -x.v } : undefined; }
  if (e.type === 'Binary' && e.op === '/') {
    const l = constOf(e.left); const r = constOf(e.right);
    if (l && r && l.t === 'num' && r.t === 'num') return { t: 'num', v: l.v / r.v };
  }
  return undefined;
}

const keyOf = (c) => (c.t === 'num' ? c.v : c.t === 'str' ? `s:${c.v}` : `b:${c.v}`);

/** The `rebuild(shards, count, root)` call: its arguments are all literal. */
function readData(callNode) {
  const [shards, count, root] = callNode.args.map(strip);
  if (!shards || shards.type !== 'Table' || !count || !root) return null;
  const n = constOf(count); const r = constOf(root);
  if (!n || n.t !== 'num' || !r || r.t !== 'num') return null;
  const tables = new Map();
  for (let i = 1; i <= n.v; i++) tables.set(i, new Map());
  let records = 0;
  for (const sf of shards.fields) {
    const shard = sf.kind === 'item' ? strip(sf.value) : null;
    if (!shard || shard.type !== 'Table') return null;
    for (const rf of shard.fields) {
      const rec = rf.kind === 'item' ? strip(rf.value) : null;
      if (!rec || rec.type !== 'Table' || rec.fields.length < 3 || rec.fields.length > 4 || rec.fields.some((f) => f.kind !== 'item')) return null;
      const [t, k, v, ref] = rec.fields.map((f) => constOf(f.value));
      if (!t || t.t !== 'num' || !k || !v) return null;
      const tbl = tables.get(t.v);
      if (!tbl) return null;
      if (rec.fields.length === 4) {
        if (!ref || v.t !== 'num' || !tables.has(v.v)) return null;
        tbl.set(keyOf(k), { t: 'tbl', id: v.v });
      } else tbl.set(keyOf(k), v);
      records++;
    }
  }
  if (!tables.has(r.v) || records < 4) return null;
  return { tables, root: r.v };
}

/** Items 1..n of a table (stops at the first hole). */
const seqOf = (tables, id) => {
  const t = tables.get(id);
  const out = [];
  for (let i = 1; t.has(i); i++) out.push(t.get(i));
  return out;
};

// ---- the prototype fields ------------------------------------------------------------------------------------------

function inferFields(tables, rootList) {
  const rootT = tables.get(rootList);
  // the root list is `{ prototype }`
  const top = rootT && rootT.get(1);
  if (!top || top.t !== 'tbl' || rootT.size !== 1) fail('the root of the data is not a list of one prototype');
  const proto0 = tables.get(top.id);
  const keys = [...proto0.keys()];
  if (keys.length !== 7) fail(`a prototype has ${keys.length} fields, not 7`);
  const kind = (v) => v.t;
  const boolKeys = keys.filter((k) => kind(proto0.get(k)) === 'bool');
  const numKeys = keys.filter((k) => kind(proto0.get(k)) === 'num');
  const tblKeys = keys.filter((k) => kind(proto0.get(k)) === 'tbl');
  if (boolKeys.length !== 1 || numKeys.length !== 1 || tblKeys.length !== 5) fail('the prototype fields are not one flag, one number and five lists');
  const sameKeys = (id) => { const t = tables.get(id); return t && t.size === 7 && keys.every((k) => t.has(k)); };
  // children: lists of prototypes
  let childrenKey = null;
  for (const k of tblKeys) {
    const items = seqOf(tables, proto0.get(k).id);
    if (items.length && items.every((x) => x.t === 'tbl' && sameKeys(x.id))) { childrenKey = k; break; }
  }
  const protos = [];
  const seen = new Set();
  const collect = (id) => {
    if (seen.has(id)) return;
    seen.add(id);
    protos.push(id);
    if (childrenKey === null) return;
    for (const c of seqOf(tables, tables.get(id).get(childrenKey).id)) collect(c.id);
  };
  collect(top.id);
  if (childrenKey === null) {
    // no function has children: which empty list is which does not matter, take any list that is empty everywhere
    childrenKey = tblKeys.find((k) => protos.every((p) => !seqOf(tables, tables.get(p).get(k).id).length));
    if (childrenKey === undefined) fail('cannot tell which prototype field holds the nested functions');
  }
  const rest = tblKeys.filter((k) => k !== childrenKey);
  const lists = (k) => protos.map((p) => seqOf(tables, tables.get(p).get(k).id));
  const isInstr = (x) => x.t === 'tbl' && (() => { const op = tables.get(x.id).get(1); return op && op.t === 'num'; })();
  const fits = {
    code: (k) => lists(k).every((l) => l.length > 0 && l.every(isInstr)),
    constants: (k) => lists(k).every((l) => l.every((x) => x.t !== 'tbl')),
    captures: (k) => lists(k).every((l) => l.every((x) => {
      if (x.t !== 'tbl') return false;
      const t = tables.get(x.id); const a = t.get(1); const b = t.get(2);
      return t.size === 2 && a && a.t === 'num' && (a.v === 0 || a.v === 1) && b && b.t === 'num';
    })),
    params: (k) => lists(k).every((l) => l.every((x) => {
      if (x.t !== 'tbl') return false;
      const t = tables.get(x.id); const a = t.get(1); const b = t.get(2);
      return t.size === 2 && a && a.t === 'num' && b && b.t === 'bool';
    })),
  };
  const roles = ['code', 'constants', 'captures', 'params'];
  const perms = (arr) => (arr.length <= 1 ? [arr] : arr.flatMap((x, i) => perms([...arr.slice(0, i), ...arr.slice(i + 1)]).map((p) => [x, ...p])));
  const ok = perms(rest).filter((p) => roles.every((r, i) => fits[r](p[i])));
  if (!ok.length) fail('the prototype lists do not read as code, constants, captures and parameters');
  // several fits only differ in lists that are empty in every prototype, where the choice changes nothing; the code list never is
  const codeKeys = new Set(ok.map((p) => p[0]));
  if (codeKeys.size !== 1) fail('more than one list could be the code');
  const p = ok[0];
  return { protos, top: top.id, fields: { code: p[0], constants: p[1], captures: p[2], params: p[3], children: childrenKey, vararg: boolKeys[0], maxRegister: numKeys[0] } };
}

// ---- the interpreter -----------------------------------------------------------------------------------------------

/**
 * The function that runs one prototype: `local function loop(P, U, Env, R, V) local code, K = P[c], P[k] ... while true do
 * I = code[pc]; pc = pc + 1; op = I[1]; a, b, c, d = I[s1], I[s2], I[s3], I[s4]; <dispatch> end end`.
 */
function findInterpreter(chunk, info, fields) {
  const keyIs = (e, k) => { const c = constOf(e); return c && keyOf(c) === k; };
  let found = null;
  walk(chunk, (n) => {
    if (found) return false;
    if (n.type !== 'Func' || n.params.length !== 5) return undefined;
    const vars = n.params.map((p) => info.varOf.get(p));
    const [P] = vars;
    // the code and constants lists read off P
    let codeVar = null; let kVar = null;
    walk(n.body, (m) => {
      if (m.type !== 'Local') return undefined;
      m.ids.forEach((id, i) => {
        const v = m.values[i] && strip(m.values[i]);
        if (v && v.type === 'Index' && strip(v.obj).type === 'Name' && info.varOf.get(strip(v.obj)) === P) {
          if (keyIs(v.key, fields.code)) codeVar = info.varOf.get(id);
          if (keyIs(v.key, fields.constants)) kVar = info.varOf.get(id);
        }
      });
      return undefined;
    });
    if (!codeVar) return undefined;
    // the loop and its fetch
    let loop = null;
    walk(n.body, (m) => { if (!loop && m.type === 'While') loop = m; return loop ? false : undefined; });
    if (!loop) return undefined;
    const body = loop.body;
    let instrVar = null; let pcVar = null; let opVar = null;
    const operands = [];
    const defsOf = (st) => {
      if (st.type === 'Local') return st.ids.map((id, i) => [info.varOf.get(id), st.values[i] && strip(st.values[i])]);
      if (st.type === 'Assign') return st.targets.map((t, i) => [t.type === 'Name' ? info.varOf.get(t) : null, st.values[i] && strip(st.values[i])]);
      return [];
    };
    let at = 0;
    for (; at < body.length && at < 12; at++) {
      for (const [v, e] of defsOf(body[at])) {
        if (!v || !e) continue;
        if (e.type === 'Index' && strip(e.obj).type === 'Name' && info.varOf.get(strip(e.obj)) === codeVar && strip(e.key).type === 'Name') { instrVar = v; pcVar = info.varOf.get(strip(e.key)); continue; }
        if (instrVar && e.type === 'Index' && strip(e.obj).type === 'Name' && info.varOf.get(strip(e.obj)) === instrVar) {
          const c = constOf(e.key);
          if (c && c.t === 'num' && c.v === 1) opVar = v;
          else if (c && c.t === 'num' && c.v >= 2 && c.v <= 5) operands.push({ v, slot: c.v });
        }
      }
    }
    if (!instrVar || !opVar || operands.length !== 4 || new Set(operands.map((o) => o.slot)).size !== 4) return undefined;
    found = { fn: n, loop, vars, kVar, pcVar, opVar, operands };
    return false;
  });
  if (!found) fail('the interpreter loop was not found');
  return found;
}

/** `if op == N then BODY ...`: the handler of every opcode. */
function handlers(it, info) {
  const out = new Map();
  const isOp = (e) => strip(e).type === 'Name' && info.varOf.get(strip(e)) === it.opVar;
  walk(it.loop.body, (n) => {
    if (n.type !== 'If') return undefined;
    for (const cl of n.clauses) {
      const c = strip(cl.cond);
      if (c.type !== 'Binary' || c.op !== '==') continue;
      const k = isOp(c.left) ? constOf(c.right) : isOp(c.right) ? constOf(c.left) : null;
      if (k && k.t === 'num' && !out.has(k.v)) out.set(k.v, cl.body);
    }
    return undefined;
  });
  return out;
}

/** The handler written with every variable named by its role, so that two builds of the same handler read the same. */
function canonical(body, it, info) {
  const role = new Map();
  const [P, U, E, R, V] = it.vars;
  role.set(P, 'P'); role.set(U, 'U'); role.set(E, 'E'); role.set(R, 'R'); role.set(V, 'V');
  if (it.kVar) role.set(it.kVar, 'K');
  role.set(it.pcVar, 'pc'); role.set(it.opVar, 'op');
  it.operands.forEach((o, i) => role.set(o.v, 'abcd'[i]));
  const inside = new Set();
  walk(it.fn, (n) => { if (n.type === 'Id') { const v = info.varOf.get(n); if (v) inside.add(v); } return undefined; });
  let t = 0; let x = 0;
  const names = [];
  walk({ type: 'Chunk', body }, (n) => {
    if (n.type !== 'Name' && n.type !== 'Id') return undefined;
    const v = info.varOf.get(n);
    let label;
    if (!v || v.isGlobal) label = n.name;
    else if (role.has(v)) label = role.get(v);
    else { label = (inside.has(v) ? 'T' : 'X') + (inside.has(v) ? ++t : ++x); role.set(v, label); }
    names.push([n, n.name]);
    n.name = label;
    return undefined;
  });
  let text;
  try { text = print({ type: 'Chunk', body, endComments: [], features: new Set() }); } finally { for (const [n, old] of names) n.name = old; }
  return text.replace(/-?\d{4,}(\.\d+)?/g, '#').replace(/\s+/g, ' ').trim();
}

const BIN = { '+': 'ADD', '-': 'SUB', '*': 'MUL', '/': 'DIV', '%': 'MOD', '^': 'POW', '..': 'CONCAT', '<': 'LT', '<=': 'LE', '>': 'GT', '>=': 'GE', '==': 'EQ', '~=': 'NE' };
const OPS = { ADD: '+', SUB: '-', MUL: '*', DIV: '/', MOD: '%', POW: '^', CONCAT: '..', LT: '<', LE: '<=', GT: '>', GE: '>=', EQ: '==', NE: '~=' };

/** What an opcode does, from its handler. */
export function classify(c) {
  const T = '(T\\d+)';
  const exact = {
    'return': 'RETURN0', 'return R[a]': 'RETURN1', 'return R[a], R[b]': 'RETURN2', 'return R[a], R[b], R[c]': 'RETURN3',
    'pc = a': 'JMP', 'R[a] = K[b]': 'LOAD', 'R[a] = nil': 'NIL', 'R[a] = R[b]': 'MOVE', 'R[a] = R[b][1]': 'GETCELL',
    'R[a][1] = R[b]': 'SETCELL', 'R[a] = U[b][1]': 'GETUP', 'U[a][1] = R[b]': 'SETUP', 'R[a] = E[K[b]]': 'GLOBAL',
    'E[K[a]] = R[b]': 'SETGLOBAL', 'R[a] = R[b][R[c]]': 'GETTABLE', 'R[a][R[b]] = R[c]': 'SETTABLE', 'R[a] = {}': 'TABLE',
    'R[a] = R[b][c]': 'TAKE', 'R[a] = V': 'VARARG', 'R[a] = { R[b] }': 'CELL', 'R[a] = not R[b]': 'NOT', 'R[a] = -R[b]': 'NEG', 'R[a] = #R[b]': 'LEN',
  };
  if (exact[c]) return exact[c];
  let m = /^R\[a\] = R\[b\] (\+|-|\*|\/|%|\^|\.\.|<|<=|>|>=|==|~=) R\[c\]$/.exec(c);
  if (m) return BIN[m[1]];
  if (new RegExp(`^(local )?${T} = R\\[a\\] R\\[a\\] = nil if not \\2 then pc = b end$`).test(c)) return 'JFALSE';
  if (new RegExp(`^(local )?${T} = R\\[a\\] R\\[a\\] = nil if \\2 then pc = b end$`).test(c)) return 'JTRUE';
  if (new RegExp(`^(local )?${T} = R\\[b\\] R\\[a\\] = \\{ \\2 \\}$`).test(c)) return 'CELL';
  if (/R\[d\] ~= R\[d\]/.test(c)) return 'FORCHECK';
  if ((c.match(/tonumber\(/g) || []).length === 3 || ((c.match(/\bX\d+\(R\[[abc]\]\)/g) || []).length === 3)) return 'FORPREP';
  if (/R\[a\]\[b \+ /.test(c)) return 'EXPAND';
  if (/\(b\)/.test(c) && /R\[a\] = T\d+$/.test(c)) return 'ARGS';
  // a loop over the list `a` that clears each register it names (also as the lowered loop a flattener leaves)
  if (/#a\b/.test(c) && /R\[a\[\w+\]\] = nil/.test(c) && (c.match(/R\[/g) || []).length === 1) return 'CLEARS';
  if (/P\[#\]\[b\]/.test(c) && /R\[a\] = /.test(c)) return 'CLOSURE';
  m = new RegExp(`^(local )?${T} = R\\[a\\] return \\w+\\(\\2, 1, \\2\\[#\\]\\)$`).exec(c);
  if (m) return 'RETURN';
  const hasD = /d == -1/.test(c);
  if (hasD) {
    if (/R\[b\], R\[c\]/.test(c) || /= R\[b\] (local )?T\d+ = R\[c\]/.test(c)) return 'CALL';
    const n = new Set(c.match(/R\[c\[(\d)\]\]/g) || []).size;
    if (/^(local )?T\d+ = R\[b\]/.test(c) && n <= 3) return `CALL${n}`;
    return null;
  }
  if ((/R\[a\], R\[b\]/.test(c) || /(^| )(local )?T\d+ = R\[b\]( |$)/.test(c)) && /return/.test(c)) return 'TAILCALL';
  if (/^(local )?T\d+ = R\[a\]/.test(c) && /return/.test(c)) {
    const n = new Set(c.match(/R\[b\[(\d)\]\]/g) || []).size;
    if (n <= 3) return `TAILCALL${n}`;
  }
  return null;
}

// ---- per-instruction facts -----------------------------------------------------------------------------------------

const list = (x) => (Array.isArray(x) ? x : []);
/** Registers an instruction reads and writes (register 0 is "none"). */
function useDef(ins) {
  const { op, a, b, c, d } = ins;
  const r = (...xs) => xs.filter((x) => typeof x === 'number' && x > 0);
  switch (op) {
    case 'LOAD': case 'NIL': case 'TABLE': case 'GLOBAL': case 'VARARG': case 'GETUP': return { use: [], def: r(a) };
    case 'MOVE': case 'CELL': case 'GETCELL': case 'NOT': case 'NEG': case 'LEN': case 'TAKE': return { use: r(b), def: r(a) };
    case 'SETCELL': return { use: r(a, b), def: [] };
    case 'SETUP': case 'SETGLOBAL': return { use: r(b), def: [] };
    case 'GETTABLE': return { use: r(b, c), def: r(a) };
    case 'SETTABLE': return { use: r(a, b, c), def: [] };
    case 'EXPAND': return { use: r(a, c), def: [] };
    case 'ARGS': return { use: r(...list(b), c), def: r(a) };
    case 'CALL': return { use: r(b, c), def: d !== 0 ? r(a) : [] };
    case 'CALL0': case 'CALL1': case 'CALL2': case 'CALL3': return { use: r(b, ...list(c)), def: d !== 0 ? r(a) : [] };
    case 'RETURN': case 'RETURN1': return { use: r(a), def: [] };
    case 'RETURN2': return { use: r(a, b), def: [] };
    case 'RETURN3': return { use: r(a, b, c), def: [] };
    case 'TAILCALL': return { use: r(a, b), def: [] };
    case 'TAILCALL0': case 'TAILCALL1': case 'TAILCALL2': case 'TAILCALL3': return { use: r(a, ...list(b)), def: [] };
    case 'CLOSURE': return { use: ins.captureRegs || [], def: r(a) };
    case 'JFALSE': case 'JTRUE': return { use: r(a), def: r(a) };
    case 'FORPREP': return { use: r(a, b, c), def: r(a, b, c) };
    case 'FORCHECK': return { use: r(b, c, d), def: r(a) };
    case 'CLEAR': return { use: [], def: r(a) };
    case 'CLEARS': return { use: [], def: r(...list(a)) };
    default: if (OPS[op]) return { use: r(b, c), def: r(a) }; return { use: [], def: [] };
  }
}
const ENDS = new Set(['JMP', 'RETURN', 'RETURN0', 'RETURN1', 'RETURN2', 'RETURN3', 'TAILCALL', 'TAILCALL0', 'TAILCALL1', 'TAILCALL2', 'TAILCALL3']);
const BRANCH = new Set(['JFALSE', 'JTRUE']);
// instructions that neither run code nor read what code could change: a call can move past them
const QUIET = new Set(['ARGS', 'LOAD', 'NIL', 'CLEAR', 'CLEARS', 'MOVE', 'TABLE', 'VARARG', 'CLOSURE']);

// ---- lifting a prototype -------------------------------------------------------------------------------------------

class Lifter {
  constructor(data, fields, opmap, slots) {
    this.data = data; this.f = fields; this.opmap = opmap; this.slots = slots;
    this.helpers = new Set();
    this.fnCount = 0;
  }

  value(v) {
    if (v.t === 'num') {
      if (Number.isNaN(v.v)) return { type: 'Binary', op: '/', left: num(0), right: num(0) };
      if (!Number.isFinite(v.v)) return { type: 'Binary', op: '/', left: num(v.v > 0 ? 1 : -1), right: num(0) };
      return num(v.v);
    }
    if (v.t === 'str') return str(v.v);
    if (v.t === 'bool') return { type: v.v ? 'True' : 'False' };
    return fail('a constant that is a table');
  }

  operand(v) {
    if (v === undefined) return undefined;
    if (v.t === 'num') return v.v;
    if (v.t === 'tbl') return seqOf(this.data.tables, v.id).map((x) => (x.t === 'num' ? x.v : fail('a register list with something else in it')));
    if (v.t === 'bool') return v.v;
    return fail('an operand that is a string');
  }

  decode(pid) {
    const t = this.data.tables.get(pid);
    const code = seqOf(this.data.tables, t.get(this.f.code).id);
    return code.map((x, i) => {
      const it = this.data.tables.get(x.id);
      const id = it.get(1).v;
      const op = this.opmap.get(id);
      if (!op) fail(`opcode ${id} has no handler that was understood`);
      const [a, b, c, d] = this.slots.map((s) => this.operand(it.get(s)));
      return { pc: i + 1, op, a, b, c, d };
    });
  }

  global(name) {
    if (IDENT.test(name) && !RESERVED.has(name)) return N(name);
    return idx(call('getfenv', []), str(name));
  }

  /** One prototype as a function expression (or, for the main one, the statements of the chunk). */
  proto(pid, upNames) {
    const t = this.data.tables.get(pid);
    const fid = ++this.fnCount;
    const K = seqOf(this.data.tables, t.get(this.f.constants).id);
    const children = seqOf(this.data.tables, t.get(this.f.children).id);
    const params = seqOf(this.data.tables, t.get(this.f.params).id).map((p) => { const pt = this.data.tables.get(p.id); return { reg: pt.get(1).v, captured: pt.get(2).v }; });
    const vararg = t.get(this.f.vararg).v;
    const code = this.decode(pid);
    for (const ins of code) {
      if (ins.op === 'CLOSURE') {
        const child = children[ins.b - 1];
        if (!child) fail('a closure of a function that does not exist');
        const caps = seqOf(this.data.tables, this.data.tables.get(child.id).get(this.f.captures).id).map((cp) => { const ct = this.data.tables.get(cp.id); return { kind: ct.get(1).v, idx: ct.get(2).v }; });
        ins.child = child.id;
        ins.caps = caps;
        ins.captureRegs = caps.filter((x) => x.kind === 0).map((x) => x.idx);
      }
    }
    const reg = (r) => N(`r${fid}_${r}`);
    const upOf = (k) => { const n = upNames[k - 1]; if (!n) fail('an upvalue the closure was not given'); return n; };
    const up = (k) => N(upOf(k).name);
    const used = new Set();
    const R = (r) => { used.add(r); return reg(r); };

    // blocks
    const leaders = new Set([1]);
    code.forEach((ins) => {
      if (ins.op === 'JMP') leaders.add(ins.a);
      if (BRANCH.has(ins.op)) leaders.add(ins.b);
      if (ENDS.has(ins.op) || BRANCH.has(ins.op)) leaders.add(ins.pc + 1);
    });
    const starts = [...leaders].filter((p) => p >= 1 && p <= code.length).sort((x, y) => x - y);
    const blockOf = new Map();
    const blocks = starts.map((s, i) => ({ start: s, end: (starts[i + 1] || code.length + 1) - 1 }));
    blocks.forEach((b) => blockOf.set(b.start, b));
    const succ = (b) => {
      const last = code[b.end - 1];
      if (last.op === 'JMP') return [last.a];
      if (BRANCH.has(last.op)) return [b.end + 1, last.b];
      if (ENDS.has(last.op)) return [];
      return b.end + 1 <= code.length ? [b.end + 1] : [];
    };
    // liveness of registers, by block and then by instruction
    const ud = code.map(useDef);
    const liveIn = new Map(blocks.map((b) => [b.start, new Set()]));
    const liveOutOf = (b) => { const s = new Set(); for (const n of succ(b)) for (const r of (liveIn.get(n) || [])) s.add(r); return s; };
    for (let changed = true; changed;) {
      changed = false;
      for (const b of [...blocks].reverse()) {
        const live = liveOutOf(b);
        for (let p = b.end; p >= b.start; p--) { ud[p - 1].def.forEach((r) => live.delete(r)); ud[p - 1].use.forEach((r) => live.add(r)); }
        const old = liveIn.get(b.start);
        if (live.size !== old.size || [...live].some((r) => !old.has(r))) { liveIn.set(b.start, live); changed = true; }
      }
    }
    const liveAfter = new Map();
    for (const b of blocks) {
      const live = liveOutOf(b);
      for (let p = b.end; p >= b.start; p--) {
        liveAfter.set(p, new Set(live));
        ud[p - 1].def.forEach((r) => live.delete(r));
        ud[p - 1].use.forEach((r) => live.add(r));
      }
    }

    // Captured variables. The VM keeps each in a one-element table (CELL) that closures share. A register boxed exactly once per call of
    // the function (outside every loop), and otherwise only read and written through the box or handed to closures, is an ordinary
    // local that the closures capture: written so, with no box
    const blockOfPc = (q) => blocks.find((x) => x.start <= q && q <= x.end);
    const inLoop = (b) => {
      const seen = new Set();
      const stack = [...succ(b)];
      while (stack.length) {
        const n = stack.pop();
        if (n === b.start) return true;
        if (seen.has(n)) continue;
        seen.add(n);
        const nb = blockOf.get(n);
        if (nb) stack.push(...succ(nb));
      }
      return false;
    };
    const direct = new Set();
    const capturedParams = new Set(params.filter((x) => x.captured).map((x) => x.reg));
    const cellRegs = new Set([...capturedParams, ...code.filter((x) => x.op === 'CELL').map((x) => x.a)]);
    for (const X of cellRegs) {
      let cells = 0;
      let ok = true;
      for (const ins of code) {
        const u = ud[ins.pc - 1];
        if (u.def.includes(X)) {
          if (ins.op === 'CELL' && ins.a === X && ins.b !== X) { cells++; if (inLoop(blockOfPc(ins.pc))) ok = false; }
          else if ((ins.op === 'CLEAR' || ins.op === 'CLEARS' || ins.op === 'NIL') && !liveAfter.get(ins.pc).has(X)) { /* dead */ }
          else ok = false;
        }
        if (u.use.includes(X)) {
          const fine = (ins.op === 'GETCELL' && ins.b === X && ins.a !== X) || (ins.op === 'SETCELL' && ins.a === X && ins.b !== X) || ins.op === 'CLOSURE';
          if (!fine) ok = false;
        }
        if (!ok) break;
      }
      if (ok && (capturedParams.has(X) ? cells === 0 : cells === 1)) direct.add(X);
    }
    const cellName = (X) => `v${fid}_${X}`;
    const cellUsed = new Set();
    const V = (X) => { cellUsed.add(X); return N(cellName(X)); };

    // which value lists can be written where they are used
    const packSlot = (ins, r) => {
      switch (ins.op) {
        case 'CALL': return ins.c === r && ins.b !== r;
        case 'ARGS': return ins.c === r && !list(ins.b).includes(r);
        case 'RETURN': return ins.a === r;
        case 'TAILCALL': return ins.b === r && ins.a !== r;
        case 'EXPAND': return ins.c === r && ins.a !== r;
        default: return false;
      }
    };
    // a register freed (`CLEAR`) between a value list and its use, that the list still reads: the clearing waits until the list is written
    const held = new Set();          // `${pc}:${reg}` of clears that wait
    const inlinable = (i, r, reads, sideEffect) => {
      const b = blocks.find((x) => x.start <= i.pc && i.pc <= x.end);
      let j = null;
      const wait = [];
      for (let p = i.pc + 1; p <= b.end; p++) {
        const u = ud[p - 1];
        if (u.use.includes(r)) { j = p; break; }
        const o = code[p - 1].op;
        for (const x of u.def) {
          if (x === r) return null;
          if (!reads.has(x)) continue;
          if (o !== 'CLEAR' && o !== 'CLEARS' && o !== 'NIL') return null;
          wait.push([p, x]);
        }
        if (sideEffect && !QUIET.has(o)) return null;
      }
      if (j === null) return null;
      const cj = code[j - 1];
      if (!packSlot(cj, r)) return null;
      if (!ud[j - 1].def.includes(r) && liveAfter.get(j).has(r)) return null;
      // a cleared register must not be read again before the list is used, other than through the list
      for (const [p, x] of wait) for (let q = p + 1; q <= j; q++) if (ud[q - 1].use.includes(x)) return null;
      for (const [p, x] of wait) held.add(`${p}:${x}`);
      return j;
    };

    // `local x, y = f()`: the results kept in a list that the next instructions take apart, first, second ... and nothing reads after
    const skip = new Set();
    const dropped = new Set();     // `${pc}:${reg}` clears superseded by an assignment written earlier
    const takeRun = (p, r) => {
      const b = blocks.find((x) => x.start <= p && p <= x.end);
      const targets = [];
      const pcs = [];
      const cleared = new Set();
      let q = p + 1;
      for (; q <= b.end; q++) {
        const t = code[q - 1];
        // registers freed on the way (the call's operands) do not stop the run, as long as they are none of the ones it sets
        if (t.op === 'CLEAR' || t.op === 'CLEARS') { ud[q - 1].def.forEach((x) => cleared.add(`${q}:${x}`)); continue; }
        if (t.op !== 'TAKE' || t.b !== r || t.c !== targets.length + 1) break;
        targets.push(t.a);
        pcs.push(q);
      }
      if (!targets.length) return null;
      const last = pcs[pcs.length - 1];
      if (new Set(targets).size !== targets.length || targets.slice(0, -1).includes(r)) return null;
      // a register freed and then set by the run (`CLEARS r1, r7` before `r1, r7 = ...`): the assignment supersedes the clearing
      const drops = [...cleared].map((k) => k.split(':').map(Number));
      if (drops.some(([, x]) => x === r)) return null;
      if (!targets.includes(r) && liveAfter.get(last).has(r)) return null;
      for (const [q2, x] of drops) if (targets.includes(x)) dropped.add(`${q2}:${x}`);
      return { targets, pcs };
    };
    const out = new Map();
    let condN = 0;
    const condVars = [];
    const pend = new Map();      // register -> { items, tail } waiting for the instruction that uses it
    const readsOf = (items) => { const s = new Set(); for (const e of items) walk({ type: 'Chunk', body: [{ type: 'Return', values: [e] }] }, (m) => { if (m.type === 'Name') { const k = /^r\d+_(\d+)$/.exec(m.name); if (k) s.add(Number(k[1])); } return undefined; }); return s; };
    const listOf = (r) => {
      // the values of a list register, as expressions (the last may be a call or `...` that gives several)
      if (pend.has(r)) { const p = pend.get(r); pend.delete(r); return p.tail ? [...p.items, p.tail] : p.items; }
      this.helpers.add('unpack');
      return [call('__unpack', [R(r)])];
    };
    const packExpr = (items) => { this.helpers.add('pack'); return call('__pack', items); };

    for (const b of blocks) {
      const stmts = [];
      let term = null;
      const waiting = new Set();
      for (let p = b.start; p <= b.end; p++) {
        if (skip.has(p)) continue;
        const ins = code[p - 1];
        const { op, a, c, d } = ins;
        const bb = ins.b;
        const put = (s) => stmts.push(s);
        const set = (r, e) => put(assign([R(r)], [e]));
        const listResult = (r, expr, multi) => {
          // a call whose results are all kept, or `...`: written where the list is used when that can be
          const reads = readsOf([expr]);
          if (inlinable(ins, r, reads, multi)) pend.set(r, { items: [], tail: expr, reads });
          else set(r, packExpr([expr]));
        };
        switch (op) {
          case 'LOAD': set(a, this.value(K[bb - 1] || fail('a constant that does not exist'))); break;
          case 'NIL': case 'CLEAR':
            if (dropped.has(`${p}:${a}`)) break;
            if (held.has(`${p}:${a}`)) waiting.add(a);
            else if (op === 'NIL' || liveAfter.get(p).has(a)) set(a, { type: 'Nil' });
            break;
          case 'MOVE': set(a, bb ? R(bb) : { type: 'Nil' }); break;
          case 'CELL':
            if (direct.has(a)) put(assign([V(a)], [bb ? R(bb) : { type: 'Nil' }]));
            else set(a, { type: 'Table', fields: bb ? [{ kind: 'item', value: R(bb) }] : [] });
            break;
          case 'GETCELL': set(a, direct.has(bb) ? V(bb) : idx(R(bb), num(1))); break;
          case 'SETCELL': put(assign([direct.has(a) ? V(a) : idx(R(a), num(1))], [R(bb)])); break;
          case 'GETUP': set(a, upOf(bb).direct ? up(bb) : idx(up(bb), num(1))); break;
          case 'SETUP': put(assign([upOf(a).direct ? up(a) : idx(up(a), num(1))], [R(bb)])); break;
          case 'GLOBAL': { const k = K[bb - 1]; if (!k || k.t !== 'str') fail('a global whose name is not a string'); set(a, this.global(k.v)); break; }
          case 'SETGLOBAL': { const k = K[a - 1]; if (!k || k.t !== 'str') fail('a global whose name is not a string'); put(assign([this.global(k.v)], [R(bb)])); break; }
          case 'GETTABLE': set(a, idx(R(bb), R(c))); break;
          case 'SETTABLE': put(assign([idx(R(a), R(bb))], [R(c)])); break;
          case 'TABLE': set(a, { type: 'Table', fields: [] }); break;
          case 'TAKE': set(a, idx(R(bb), num(c))); break;
          case 'VARARG': if (!vararg) fail('`...` in a function without it'); listResult(a, { type: 'Vararg' }, false); break;
          case 'ARGS': {
            const items = list(bb).map((x) => R(x));
            const all = c ? [...items, ...listOf(c)] : items;
            const last = all[all.length - 1];
            const sideEffect = !!(last && last.type === 'Call');
            const rd = readsOf(all);
            if (inlinable(ins, a, rd, sideEffect)) pend.set(a, { items: all, tail: null, reads: rd });
            else set(a, packExpr(all));
            break;
          }
          case 'EXPAND': {
            const vals = listOf(c);
            // values that are each one value: `t[b] = v1; t[b + 1] = v2 ...`, which the table idiom folds back into the constructor
            const lastV = vals[vals.length - 1];
            if (!lastV || (lastV.type !== 'Call' && lastV.type !== 'Vararg' && !(lastV.type === 'Call' && lastV.fn.type === 'Name' && lastV.fn.name === '__unpack'))) {
              vals.forEach((v, k) => put(assign([idx(R(a), num(bb + k))], [v])));
              break;
            }
            this.helpers.add('pack');
            const tv = `x${fid}_${p}`;
            put({ type: 'Do', body: [
              { type: 'Local', ids: [{ type: 'Id', name: tv }], values: [packExpr(vals)] },
              { type: 'NumFor', id: { type: 'Id', name: `i${fid}_${p}` }, start: num(1), stop: { type: 'Index', obj: N(tv), key: str('n'), dot: true }, step: null,
                body: [assign([idx(R(a), { type: 'Binary', op: '-', left: { type: 'Binary', op: '+', left: num(bb), right: N(`i${fid}_${p}`) }, right: num(1) })], [idx(N(tv), N(`i${fid}_${p}`))])] },
            ] });
            break;
          }
          case 'CALL': case 'CALL0': case 'CALL1': case 'CALL2': case 'CALL3': {
            const fn = R(bb);
            const args = op === 'CALL' ? listOf(c) : list(c).map((x) => R(x));
            const ce = call(fn, args);
            const takes = d === -1 ? takeRun(p, a) : null;
            if (takes) { put(assign(takes.targets.map((x) => R(x)), [ce])); takes.pcs.forEach((q) => skip.add(q)); }
            else if (d === -1) listResult(a, ce, true);
            else if (d === 1) set(a, ce);
            else put({ type: 'CallStmt', call: ce });
            break;
          }
          case 'RETURN': term = { kind: 'return', values: listOf(a) }; break;
          case 'RETURN0': term = { kind: 'return', values: null }; break;
          case 'RETURN1': term = { kind: 'return', values: [R(a)] }; break;
          case 'RETURN2': term = { kind: 'return', values: [R(a), R(bb)] }; break;
          case 'RETURN3': term = { kind: 'return', values: [R(a), R(bb), R(c)] }; break;
          case 'TAILCALL': term = { kind: 'return', values: [call(R(a), listOf(bb))] }; break;
          case 'TAILCALL0': case 'TAILCALL1': case 'TAILCALL2': case 'TAILCALL3': term = { kind: 'return', values: [call(R(a), list(bb).map((x) => R(x)))] }; break;
          case 'CLOSURE': {
            // a capture of an ordinary local is the local itself; a box is handed over through a factory, so the closure keeps the box
            // the VM gave it even if the register is boxed again later
            const ups = ins.caps.map((cp, k) => {
              if (cp.kind === 0 && direct.has(cp.idx)) { cellUsed.add(cp.idx); return { name: cellName(cp.idx), direct: true }; }
              if (cp.kind === 1 && upOf(cp.idx).direct) return upOf(cp.idx);
              return { name: `u${fid}_${p}_${k + 1}`, direct: false, value: cp.kind === 0 ? R(cp.idx) : up(cp.idx) };
            });
            const fnExpr = this.proto(ins.child, ups);
            const boxed = ups.filter((x) => x.value);
            if (!boxed.length) set(a, fnExpr);
            else set(a, call({ type: 'Paren', expr: { type: 'Func', params: boxed.map((x) => ({ type: 'Id', name: x.name })), vararg: false, body: [{ type: 'Return', values: [fnExpr] }] } }, boxed.map((x) => x.value)));
            break;
          }
          case 'JMP': term = { kind: 'goto', to: a }; break;
          case 'JFALSE': case 'JTRUE': {
            const cv = `c${fid}_${++condN}`;
            condVars.push(cv);
            put(assign([N(cv)], [R(a)]));
            set(a, { type: 'Nil' });
            term = op === 'JTRUE' ? { kind: 'branch', cond: N(cv), t: bb, f: p + 1 } : { kind: 'branch', cond: N(cv), t: p + 1, f: bb };
            break;
          }
          case 'NOT': set(a, { type: 'Unary', op: 'not', arg: R(bb) }); break;
          case 'NEG': set(a, { type: 'Unary', op: '-', arg: R(bb) }); break;
          case 'LEN': set(a, { type: 'Unary', op: '#', arg: R(bb) }); break;
          case 'FORPREP': {
            const msgs = ["'for' initial value must be a number", "'for' limit must be a number", "'for' step must be a number"];
            [a, bb, c].forEach((r, k) => set(r, { type: 'Binary', op: 'or', left: call('tonumber', [R(r)]), right: call('error', [str(msgs[k]), num(0)]) }));
            break;
          }
          case 'FORCHECK': {
            const D = R(d);
            const up2 = { type: 'Binary', op: 'and', left: { type: 'Binary', op: '>', left: D, right: num(0) }, right: { type: 'Binary', op: '<=', left: R(bb), right: R(c) } };
            const down = { type: 'Binary', op: 'and', left: { type: 'Binary', op: '<=', left: R(d), right: num(0) }, right: { type: 'Binary', op: '>=', left: R(bb), right: R(c) } };
            set(a, { type: 'Binary', op: 'and', left: { type: 'Binary', op: '==', left: R(d), right: R(d) }, right: { type: 'Paren', expr: { type: 'Binary', op: 'or', left: up2, right: down } } });
            break;
          }
          case 'CLEARS': {
            // a register cleared and never read again before it is set: the clearing changes nothing
            const rs = list(a).filter((r) => { if (dropped.has(`${p}:${r}`)) return false; if (held.has(`${p}:${r}`)) { waiting.add(r); return false; } return liveAfter.get(p).has(r); });
            if (rs.length) put(assign(rs.map((r) => R(r)), rs.map(() => ({ type: 'Nil' }))));
            break;
          }
          default:
            if (OPS[op]) { set(a, { type: 'Binary', op: OPS[op], left: R(bb), right: R(c) }); break; }
            fail(`an instruction this tool does not know: ${op}`);
        }
        // clears that waited for a list: written once no list still waiting reads the register; one set again since needs none
        if (waiting.size && !['CLEAR', 'CLEARS', 'NIL'].includes(op)) for (const x of ud[p - 1].def) waiting.delete(x);
        if (waiting.size) {
          const stillRead = new Set();
          for (const pe of pend.values()) for (const x of pe.reads) stillRead.add(x);
          const now = [...waiting].filter((x) => !stillRead.has(x));
          if (now.length && !term) { stmts.push(assign(now.map((x) => R(x)), now.map(() => ({ type: 'Nil' })))); }
          now.forEach((x) => waiting.delete(x));
        }
        if (term) break;
      }
      if (pend.size) fail('a value list was left unused at the end of a block');
      if (waiting.size) fail('a register clear was held past the end of a block');
      if (!term) term = b.end + 1 <= code.length ? { kind: 'goto', to: b.end + 1 } : { kind: 'return', values: null };
      out.set(b.start, { stmts, term });
    }
    let body;
    try {
      body = structure(out, 1, {
        negate: (cnd) => (cnd.type === 'Unary' && cnd.op === 'not' ? cnd.arg : { type: 'Unary', op: 'not', arg: cnd.type === 'Binary' ? { type: 'Paren', expr: cnd } : cnd }),
        makeReturn: (values) => ({ type: 'Return', values: values || [] }),
      });
    } catch (e) {
      if (e instanceof CfgError) fail(`function ${fid}: ${e.message}`);
      throw e;
    }
    const last = body[body.length - 1];
    if (last && last.type === 'Return' && !last.values.length) body.pop();
    // parameters: plain ones are the registers themselves, captured ones are put in a cell
    const paramIds = [];
    const prologue = [];
    const paramRegs = new Set();
    for (const pr of params) {
      paramRegs.add(pr.reg);
      if (pr.captured && direct.has(pr.reg)) {
        paramIds.push({ type: 'Id', name: cellName(pr.reg) });
        cellUsed.delete(pr.reg);
      } else if (pr.captured) {
        const pn = `p${fid}_${pr.reg}`;
        paramIds.push({ type: 'Id', name: pn });
        prologue.push(assign([R(pr.reg)], [{ type: 'Table', fields: [{ kind: 'item', value: N(pn) }] }]));
      } else paramIds.push({ type: 'Id', name: `r${fid}_${pr.reg}` });
    }
    const locals = [...used].filter((r) => !paramRegs.has(r) || params.find((x) => x.reg === r).captured).sort((x, y) => x - y).map((r) => `r${fid}_${r}`);
    const cellLocals = [...cellUsed].filter((r) => !capturedParams.has(r)).sort((x, y) => x - y).map(cellName);
    const decl = [...locals, ...cellLocals, ...condVars];
    const head = decl.length ? [{ type: 'Local', ids: decl.map((n) => ({ type: 'Id', name: n })), values: [] }] : [];
    return { type: 'Func', params: paramIds, vararg, body: [...head, ...prologue, ...body] };
  }
}

// ---- the whole script ----------------------------------------------------------------------------------------------

/** The final `return runtime(rebuild(DATA, n, root), ...)`, or the same call anywhere at the top level. */
function findEntry(chunk) {
  for (let i = chunk.body.length - 1; i >= 0; i--) {
    const s = chunk.body[i];
    const e = s.type === 'Return' && s.values.length === 1 ? strip(s.values[0]) : s.type === 'CallStmt' ? s.call : null;
    if (!e || e.type !== 'Call' || !e.args.length) continue;
    const inner = strip(e.args[0]);
    if (inner.type !== 'Call' || inner.args.length !== 3 || strip(inner.args[0]).type !== 'Table') continue;
    return { at: i, stmt: s, outer: e, inner };
  }
  return null;
}

export function looksLikePrometheusBvm(chunk) {
  const e = findEntry(chunk);
  if (!e) return false;
  const shards = strip(e.inner.args[0]);
  return shards.fields.length >= 1 && shards.fields.length <= 8 && shards.fields.every((f) => f.kind === 'item' && strip(f.value).type === 'Table');
}

/**
 * Lift the register VM. Returns { changed, stats } and rewrites the chunk; throws BvmError (the chunk untouched) when the
 * script is not one or something in it is not understood.
 */
export function liftPrometheusBvm(chunk) {
  const entry = findEntry(chunk);
  if (!entry) fail('no `runtime(rebuild(data, n, root), ...)` call');
  const data = readData(entry.inner);
  if (!data) fail('the program data is not a literal of records');
  const { protos, fields } = inferFields(data.tables, data.root);
  const info = analyze(chunk);
  const it = findInterpreter(chunk, info, fields);
  const hs = handlers(it, info);
  const opmap = new Map();
  const unknown = [];
  for (const [id, body] of hs) {
    const name = classify(canonical(body, it, info));
    if (name) opmap.set(id, name); else unknown.push(id);
  }
  // every handler does something different, except that clearing a register and loading nil into it read the same
  const byName = new Map();
  for (const [id, name] of opmap) byName.set(name, [...(byName.get(name) || []), id]);
  for (const [name, ids] of byName) if (ids.length > 1 && name !== 'NIL') fail(`opcodes ${ids.join(', ')} all read as ${name}`);
  const slots = it.operands.map((o) => o.slot);
  const lifter = new Lifter(data, fields, opmap, slots);
  const main = lifter.proto(lifter.data.tables.get(data.root).get(1).id, []);
  // the runtime and the rebuild function are the call's; the statements that declared them go
  const fnNames = new Set([entry.outer.fn, entry.inner.fn].map(strip).filter((x) => x.type === 'Name').map((x) => x.name));
  const keep = chunk.body.slice(0, entry.at).filter((s) => !((s.type === 'Local' && s.ids.length === 1 && fnNames.has(s.ids[0].name)) || (s.type === 'LocalFunction' && fnNames.has(s.id.name))));
  const helpers = [];
  if (lifter.helpers.has('pack')) helpers.push({ type: 'LocalFunction', id: { type: 'Id', name: '__pack' }, func: { type: 'Func', params: [], vararg: true, body: [{ type: 'Return', values: [{ type: 'Table', fields: [{ kind: 'named', key: 'n', value: call('select', [str('#'), { type: 'Vararg' }]) }, { kind: 'item', value: { type: 'Vararg' } }] }] }] } });
  if (lifter.helpers.has('unpack')) helpers.push({ type: 'LocalFunction', id: { type: 'Id', name: '__unpack' }, func: { type: 'Func', params: [{ type: 'Id', name: 't' }], vararg: false, body: [{ type: 'Return', values: [call({ type: 'Paren', expr: { type: 'Binary', op: 'or', left: N('unpack'), right: { type: 'Index', obj: N('table'), key: str('unpack'), dot: true } } }, [N('t'), num(1), { type: 'Index', obj: N('t'), key: str('n'), dot: true }])] }] } });
  // the main function's parameters are the script's `...`
  const body = [...helpers, ...(main.params.length ? [{ type: 'Local', ids: main.params, values: [{ type: 'Vararg' }] }] : []), ...main.body];
  chunk.body = [...keep, ...body, ...chunk.body.slice(entry.at + 1)];
  return { changed: protos.length, stats: { functions: protos.length, opcodes: opmap.size, unknownOpcodes: unknown, slots, fields } };
}
