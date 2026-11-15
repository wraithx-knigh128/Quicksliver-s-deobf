// MoonVeil 2.1.0: the program rebuilt from its instructions, by reading what each handler does with them.
//
// The program data is read to the last byte by schema21.js. What 2.1.0 does not give away is what an opcode means: the interpreter is one loop that
// calls `H[ins[opSlot]](...)`, and H is filled by a builder from a table of factories through two shuffled tables. Every build shuffles everything a
// reader could anchor on: the opcode numbers, which handlers are fused with which (GETGLOBAL+NEWTABLE, CALL+MOVE, CALL+RETURN, ...), the instruction
// slots each operand sits in and a constant added to every operand, the order of the handler's arguments and of the values it returns, and the slots
// of the frame a function runs with. So nothing here is a table of handler shapes. What is read, per build:
//
//   the builder      `H[T[P[i]]] = F[i]` in a counted loop: T, P and F are filled by constant assignments before it -> opcode -> factory site
//   the dispatcher   which argument of a handler is the instruction, the registers, the frame, the open upvalues, the top and the program counter, and
//                    which returned value is the result count, the "done" flag, the next pc, the first result and the new top
//   the closure      the function that builds a frame for a prototype: which frame slot holds which library function (unpack, pack, move,
//   builder          create), the environment, the upvalues, and which prototype field
//   the cells        the library function in each cell a factory is given (`{ [vs] = string.byte }`)
//
// and then each instruction is partially evaluated: its handler is run on the instruction's fields, which are known, with everything that belongs to the
// running program (registers, upvalues, globals, the top of the stack) left symbolic. Tests on the fields are decided, loops over the fields are unrolled,
// library calls on known values are computed (a handler that decrypts a later instruction's string constant does so here, and the instruction it
// rewrites itself into is read in its place). A test on a value of the running program (the generic `for` exit) forks the evaluation; both ways must do
// the same thing apart from where they go next. What is left of a handler is a few register operations, which are written as Lua 5.1 instructions and
// handed to the decompiler.
//
// Three things are read by their shape rather than evaluated, because they walk run-time state: closing upvalues (a loop over the open-upvalue table),
// the capture list of a closure (get-or-create a cell for a register), and Luau's generalised iteration in front of a generic `for` (`__iter`, or a table
// iterated directly). The last is lifted as a Lua 5.1 generic `for`, which is the same when the loop is given an iterator function; the result says so.
//
// Functions MoonVeil compiled to plain Lua instead of VM code ("natives", looked up by name when the function is read) are written as a call of a
// placeholder global and replaced by their source afterwards (see `nativeSources`).

import { walk } from '../../core/walk.js';
import { print } from '../../core/printer.js';
import { dumpChunk51, parseChunk } from '../../sandbox/bytecode.js';
import { decompile } from '../../decompile/decompile.js';
import { membersOf, joinMoonVeil } from '../moonveil-join.js';
import { findContainerCall } from './container21.js';
import { encode, maxStack } from '../ironbrew.js';

export class Lift21Error extends Error {}
const fail = (m) => { throw new Lift21Error(m); };
const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const text = (n) => print({ type: 'Chunk', body: Array.isArray(n) ? n : [n], endComments: [], features: new Set() });
const exprText = (e) => text({ type: 'Return', values: [e] }).replace(/^return /, '').trim();
const isName = (e, n) => { e = strip(e); return e && (e.type === 'Name' || e.type === 'Id') && (n === undefined || e.name === n); };
const idName = (t) => t.name;

// ---- what the machine looks like -------------------------------------------------------------------------------------------------------------------

/** A library function or table, by its path: '' is the environment, 'string.byte' is string.byte. */
class Lib { constructor(path) { this.path = path; } }
/** A factory instantiated at a site: `ctx:NAME{ cells }`. */
class Site { constructor(name, args) { this.name = name; this.args = args; } }

/** Evaluate the straight-line part of the builder: constant tables, cells that hold library functions, sites. */
function builderEnv(fn, stop) {
  const env = new Map();
  const ctxName = fn.params[0] && fn.params[0].name;
  const val = (e) => {
    e = strip(e);
    if (!e) return undefined;
    if (e.type === 'Number') return e.value;
    if (e.type === 'String') return e.value;
    if (e.type === 'Unary' && e.op === '-' && strip(e.arg).type === 'Number') return -strip(e.arg).value;
    if (e.type === 'Name') return env.get(e.name);
    if (e.type === 'Table') {
      const m = new Map();
      let i = 1;
      for (const f of e.fields) {
        if (f.kind === 'item') m.set(i++, val(f.value));
        else if (f.kind === 'keyed') m.set(val(f.key), val(f.value));
        else if (f.kind === 'named') m.set(f.key, val(f.value));
      }
      return m;
    }
    if (e.type === 'MethodCall' && isName(e.obj, ctxName)) {
      const a = e.args[0] && strip(e.args[0]);
      return new Site(e.name, a && a.type === 'Table' ? a.fields.map((f) => val(f.value)) : []);
    }
    if (e.type === 'Index') {
      if (isName(e.obj, ctxName) && strip(e.key).type === 'String' && strip(e.key).value === '_') return new Lib('');
      const o = val(e.obj);
      const k = val(e.key);
      if (o instanceof Lib && typeof k === 'string') return new Lib(o.path ? `${o.path}.${k}` : k);
      if (o instanceof Map) return o.get(k);
      return undefined;
    }
    return undefined;
  };
  const assign = (targets, values) => {
    const vs = values.map(val);
    targets.forEach((t, i) => {
      if (t.type === 'Name' || t.type === 'Id') env.set(t.name, vs[i]);
      else if (t.type === 'Index') { const o = val(t.obj); if (o instanceof Map) o.set(val(t.key), vs[i]); }
    });
  };
  const visit = (stmts) => {
    for (const s of stmts) {
      if (s === stop) return true;
      if (s.type === 'Local') assign(s.ids, s.values || []);
      else if (s.type === 'Assign') assign(s.targets, s.values);
      else if (s.type === 'If') { for (const c of s.clauses) if (visit(c.body)) return true; }
    }
    return false;
  };
  visit(fn.body);
  return env;
}

/** `x, y = E1, E2; H[c][x|y] = the other`: one of E1/E2 is T[P[i]] (an opcode), the other F[i] (a handler). */
function installLoop(s) {
  if (s.type !== 'Repeat' || s.body.length < 3) return null;
  const [a, b] = s.body;
  if (a.type !== 'Assign' || a.targets.length !== 2 || b.type !== 'Assign' || b.targets.length !== 1) return null;
  const t = b.targets[0];
  const v = strip(b.values[0]);
  if (t.type !== 'Index' || strip(t.obj).type !== 'Index' || !isName(t.key) || !isName(v)) return null;
  const names = a.targets.map(idName);
  const ki = names.indexOf(strip(t.key).name);
  const vi = names.indexOf(v.name);
  if (ki < 0 || vi < 0 || ki === vi) return null;
  const op = strip(a.values[ki]);
  const fn = strip(a.values[vi]);
  if (op.type !== 'Index' || strip(op.key).type !== 'Index' || fn.type !== 'Index') return null;
  const i = strip(fn.key);
  const inner = strip(op.key);
  if (!isName(i) || !isName(inner.key, i.name) || !isName(op.obj) || !isName(inner.obj) || !isName(fn.obj)) return null;
  return { T: strip(op.obj).name, P: strip(inner.obj).name, F: strip(fn.obj).name, table: strip(strip(t.obj).obj) };
}

/** The dispatcher: `H[ins[opSlot]](args...)` in a `while true` loop, with the results tested and assigned back. */
function readDispatcher(ast, opSlot) {
  let found = null;
  walk(ast, (n) => {
    if (found || n.type !== 'Func' || n.params.length < 3) return undefined;
    const loop = n.body.find((s) => s.type === 'While' && strip(s.cond).type === 'True');
    if (!loop) return undefined;
    const call = loop.body.find((s) => s.type === 'Local' && s.values.length === 1 && strip(s.values[0]).type === 'Call' && strip(strip(s.values[0]).fn).type === 'Index'
      && strip(strip(strip(s.values[0]).fn).key).type === 'Index' && strip(strip(strip(strip(s.values[0]).fn).key).key).type === 'Number' && strip(strip(strip(strip(s.values[0]).fn).key).key).value === opSlot);
    if (!call) return undefined;
    found = { fn: n, loop, call };
    return false;
  });
  if (!found) fail('the dispatcher (`H[ins[op]](...)` in a loop) was not found');
  const { fn, loop, call } = found;
  const c = strip(call.values[0]);
  const insVar = strip(strip(c.fn).key).obj.name;
  // the fetch: `local ins = code[pc]` with code = frame[codeSlot]
  const fetch = loop.body.find((s) => s.type === 'Local' && s.ids[0].name === insVar);
  if (!fetch) fail('the instruction fetch was not found');
  const codeVar = strip(strip(fetch.values[0]).obj).name;
  const pcVar = strip(strip(fetch.values[0]).key).name;
  const codeDecl = fn.body.find((s) => s.type === 'Local' && s.ids.length === 1 && s.ids[0].name === codeVar);
  if (!codeDecl || strip(codeDecl.values[0]).type !== 'Index') fail('the code list of the frame was not found');
  const frameName = strip(strip(codeDecl.values[0]).obj).name;
  const codeSlot = strip(strip(codeDecl.values[0]).key).value;
  // pc and top: `local pc, top = 1, -1`
  const counters = fn.body.find((s) => s.type === 'Local' && s.ids.some((x) => x.name === pcVar));
  const topVar = counters && counters.ids.find((x) => x.name !== pcVar) && counters.ids.find((x) => x.name !== pcVar).name;
  // returns: `if done then return unpack(regs, start, start + count - 1) end` and `pc, top = newpc, newtop`
  const results = call.ids.map(idName);
  const test = loop.body.find((s) => s.type === 'If' && isName(s.clauses[0].cond) && results.includes(strip(s.clauses[0].cond).name));
  if (!test) fail('the dispatcher does not test a result for the end of the function');
  const ret = test.clauses[0].body.find((s) => s.type === 'Return');
  const rc = ret && strip(ret.values[0]);
  if (!rc || rc.type !== 'Call' || rc.args.length !== 3) fail('the dispatcher does not return a range of registers');
  const regsName = strip(rc.args[0]).name;
  const startVar = strip(rc.args[1]).name;
  let countVar = null;
  walk(rc.args[2], (x) => { if (x.type === 'Name' && x.name !== startVar && results.includes(x.name)) countVar = x.name; });
  const back = loop.body.find((s) => s.type === 'Assign' && s.targets.length === 2 && s.targets.some((t) => isName(t, pcVar)));
  if (!back) fail('the dispatcher does not move to the next pc');
  const newpcVar = strip(back.values[back.targets.findIndex((t) => isName(t, pcVar))]).name;
  const newtopVar = strip(back.values[back.targets.findIndex((t) => isName(t, topVar))]).name;
  const roleOfResult = { [countVar]: 'count', [strip(test.clauses[0].cond).name]: 'done', [newpcVar]: 'pc', [startVar]: 'start', [newtopVar]: 'top' };
  const returns = results.map((r) => roleOfResult[r] || null);
  if (returns.filter(Boolean).length !== 5) fail(`the dispatcher's results could not all be told apart (${returns.join(', ')})`);
  // arguments: the instruction, pc, top by name; the parameters of the dispatcher by what the dispatcher does with them
  const params = fn.params.map(idName);
  const args = c.args.map((a) => {
    a = strip(a);
    if (!isName(a)) return null;
    if (a.name === insVar) return 'ins';
    if (a.name === pcVar) return 'pc';
    if (a.name === topVar) return 'top';
    if (a.name === regsName) return 'regs';
    if (a.name === frameName) return 'frame';
    if (params.includes(a.name)) return `p:${a.name}`;
    return null;
  });
  if (args.some((a) => a === null)) fail('an argument of the handlers is not one of the dispatcher’s own values');
  return { args, returns, codeSlot, other: args.filter((a) => a && a.startsWith('p:')) };
}

/** The function that makes the frame a prototype runs in: `local F = {}; F[k] = proto[k'] / cells[j][vs] / upvalues`, in whatever spelling. */
function readFrameBuilder(members, vs) {
  for (const [key, f] of members) {
    if (!f || f.type !== 'Func' || f.body.length !== 1 || f.body[0].type !== 'Return') continue;
    const inner = strip(f.body[0].values[0]);
    if (!inner || inner.type !== 'Func' || inner.params.length !== 2) continue;
    const [P, U] = inner.params.map(idName);
    const cells = f.params[1] && f.params[1].name;
    // what each name holds: the prototype, the upvalues, a cell's library function, a cell made from the prototype, or a table being filled
    const env = new Map([[P, { kind: 'P' }], [U, { kind: 'upvals' }]]);
    const tables = [];
    const val = (e) => {
      e = strip(e);
      if (!e) return null;
      if (isName(e)) return env.get(e.name) || null;
      if (e.type === 'Table') {
        const t = { kind: 'table', fields: new Map() };
        for (const x of e.fields) if (x.kind === 'keyed' && strip(x.key).type === 'Number') t.fields.set(strip(x.key).value, val(x.value));
        if (t.fields.get(vs) && t.fields.get(vs).kind === 'P') return { kind: 'Pcell' };
        tables.push(t);
        return t;
      }
      if (e.type === 'Index' && strip(e.key).type === 'Number') {
        const k = strip(e.key).value;
        const o = strip(e.obj);
        if (o.type === 'Index' && isName(o.obj, cells) && strip(o.key).type === 'Number' && k === vs) return { kind: 'cell', cell: strip(o.key).value };
        const ov = val(o);
        if (ov && ov.kind === 'P') return { kind: 'proto', slot: k };
        if (ov && ov.kind === 'Pcell' && k === vs) return { kind: 'P' };
      }
      return null;
    };
    const assign = (targets, values) => {
      const vals = values.map(val);
      targets.forEach((t, i) => {
        const v = i < vals.length ? vals[i] : null;
        if (t.type === 'Id' || t.type === 'Name') { env.set(t.name, v); return; }
        if (t.type === 'Index' && strip(t.key).type === 'Number') {
          const o = val(t.obj);
          if (o && o.kind === 'table') o.fields.set(strip(t.key).value, v);
        }
      });
    };
    for (const s of inner.body) {
      if (s.type === 'Local') assign(s.ids, s.values || []);
      else if (s.type === 'Assign') assign(s.targets, s.values);
    }
    const L = tables.find((t) => [...t.fields.values()].some((v) => v && v.kind === 'upvals') && t.fields.size >= 6);
    if (L) {
      const fields = new Map();
      for (const [k, v] of L.fields) if (v && (v.kind === 'upvals' || v.kind === 'proto' || v.kind === 'cell')) fields.set(k, v);
      return { key, fields };
    }
  }
  return fail('the function that builds a frame for a prototype was not found');
}

/** What a member of the context is, from what it does. */
function ctxKind(f) {
  if (!f) return null;
  const t = text({ type: 'Return', values: [f] });
  if (/select\("#", \.\.\.\)/.test(t) && /\{ \.\.\. \}/.test(t)) return 'pack';
  if (/__iter/.test(t) && /pairs\(/.test(t)) return 'iter';
  if (/return \w+\[\w+\], \w+\(\w+, \w+ \+ 1, \w+\)/.test(t)) return 'unpack';
  return null;
}

/**
 * Everything the lifter needs to know about this build's interpreter.
 * @param {object} ast the script after MoonVeil's flattening has been undone (the shape the schema is read from)
 * @param {Map<string, object>} members the table's factories by name (moonveil-join.js: membersOf)
 */
export function readMachine21(ast, members, { opSlot, valueSlot }) {
  if (!members) fail('the names of the table\u2019s positions could not be read');
  let builder = null;
  let loop = null;
  let roles = null;
  for (const [, f] of members) {
    if (!f || f.type !== 'Func') continue;
    walk(f.body, (s) => { if (!loop && (roles = installLoop(s))) loop = s; return loop ? false : undefined; });
    if (loop) { builder = f; break; }
  }
  if (!builder) fail('the loop that fills the handler table was not found');
  const env = builderEnv(builder, findEnclosing(builder.body, loop));
  const T = env.get(roles.T);
  const P = env.get(roles.P);
  const F = env.get(roles.F);
  if (!(T instanceof Map) || !(P instanceof Map) || !(F instanceof Map)) fail('the tables the handler table is filled from are not constant');
  const handlers = new Map();
  for (const [i, site] of F) {
    const op = T.get(P.get(i));
    if (typeof op !== 'number' || !(site instanceof Site)) fail(`handler ${i} does not resolve to an opcode and a factory`);
    if (handlers.has(op)) fail(`opcode ${op} is given two handlers`);
    const fact = members.get(site.name);
    if (!fact || fact.type !== 'Func') fail(`the factory ${site.name} is not a function`);
    const ret = fact.body[fact.body.length - 1];
    const inner = ret && ret.type === 'Return' && strip(ret.values[0]);
    if (!inner || inner.type !== 'Func') fail(`the factory ${site.name} does not return its handler`);
    handlers.set(op, { name: site.name, factory: fact, fn: inner, cells: site.args.map((c) => cellValue(c, valueSlot)) });
  }
  const dispatcher = readDispatcher(ast, opSlot);
  const frame = readFrameBuilder(members, valueSlot);
  const ctx = new Map();
  for (const [k, f] of members) { const kind = ctxKind(f); if (kind) ctx.set(k, kind); }
  // the cells the frame builder is given at its site in the builder: the library function behind each frame slot
  let frameSite = null;
  for (const v of env.values()) {
    const s = v instanceof Map ? v.get(valueSlot) : v;
    if (s instanceof Site && s.name === frame.key) frameSite = s;
  }
  if (!frameSite) fail('the frame builder’s site was not found in the builder');
  const slots = new Map();
  for (const [k, d] of frame.fields) {
    if (d.kind === 'cell') {
      const c = cellValue(frameSite.args[d.cell - 1], valueSlot);
      slots.set(k, c instanceof Lib ? { kind: 'lib', path: c.path } : { kind: 'other' });
    } else slots.set(k, d);
  }
  return { handlers, dispatcher, slots, ctx, frameKey: frame.key, members, valueSlot };
}

function findEnclosing(body, loop) {
  // the statement of the builder's body that contains the loop (the loop sits in `if not (1 > n) then ... end`)
  for (const s of body) { let hit = false; walk(s, (n) => { if (n === loop) hit = true; return hit ? false : undefined; }); if (hit) return s; }
  return null;
}
const cellValue = (c, vs) => (c instanceof Map ? (c.has(vs) ? c.get(vs) : null) : c);

// ---- partial evaluation of one handler on one instruction ---------------------------------------------------------------------------------------

// values: number | string | boolean | null (nil) are known; everything else is one of these
const V = (t, x = {}) => ({ t, ...x });
const isKnown = (v) => v === null || typeof v === 'number' || typeof v === 'string' || typeof v === 'boolean';
const rv = (e) => V('rv', { e });              // a value of the running program, written as an IR expression

const LIBS = {
  'string.byte': (s, i = 1, j = i) => { if (typeof s !== 'string') return undefined; const out = []; for (let k = i; k <= j; k++) { const c = s.charCodeAt(k - 1); if (Number.isNaN(c)) break; out.push(c); } return out; },
  'string.char': (...xs) => (xs.every((x) => typeof x === 'number') ? [String.fromCharCode(...xs)] : undefined),
  'string.sub': (s, i = 1, j = -1) => { if (typeof s !== 'string') return undefined; const n = s.length; if (i < 0) i = Math.max(n + i + 1, 1); if (j < 0) j = n + j + 1; return [s.slice(Math.max(i, 1) - 1, Math.min(j, n))]; },
  'string.len': (s) => (typeof s === 'string' ? [s.length] : undefined),
  'bit32.bxor': (...xs) => (xs.every((x) => typeof x === 'number') ? [xs.reduce((a, b) => (a ^ b) >>> 0, 0)] : undefined),
  'bit32.band': (...xs) => (xs.every((x) => typeof x === 'number') ? [xs.reduce((a, b) => (a & b) >>> 0, 0xffffffff)] : undefined),
  'bit32.bor': (...xs) => (xs.every((x) => typeof x === 'number') ? [xs.reduce((a, b) => (a | b) >>> 0, 0)] : undefined),
  'bit32.lshift': (a, n) => (typeof a === 'number' && typeof n === 'number' ? [n >= 32 ? 0 : (a << n) >>> 0] : undefined),
  'bit32.rshift': (a, n) => (typeof a === 'number' && typeof n === 'number' ? [n >= 32 ? 0 : a >>> n] : undefined),
};

const BIN = { '+': 'ADD', '-': 'SUB', '*': 'MUL', '/': 'DIV', '%': 'MOD', '^': 'POW', '..': 'CONCAT' };
const CMP = { '==': 1, '~=': 1, '<': 1, '<=': 1, '>': 1, '>=': 1 };
const topOf = (v) => v && v.t === 'top';

function arith(op, a, b) {
  if (typeof a === 'number' && typeof b === 'number') {
    switch (op) {
      case '+': return a + b; case '-': return a - b; case '*': return a * b; case '/': return a / b;
      case '%': return a - Math.floor(a / b) * b; case '^': return a ** b;
      default: break;
    }
  }
  if (op === '..' && (typeof a === 'string' || typeof a === 'number') && (typeof b === 'string' || typeof b === 'number')) return String(a) + String(b);
  // the top of the stack: top + n, n + top, top - n; and the count of results of a call left open
  if ((op === '+' || op === '-') && topOf(a) && typeof b === 'number') return V('top', { off: a.off + (op === '+' ? b : -b), base: a.base });
  if (op === '+' && typeof a === 'number' && topOf(b)) return V('top', { off: b.off + a, base: b.base });
  if (op === '-' && topOf(a) && topOf(b) && a.base === b.base) return a.off - b.off;
  if (op === '+' && typeof a === 'number' && b && b.t === 'nres') return V('top', { off: a, base: b.call });
  return undefined;
}

class Path {
  constructor(env, effects, frames) { this.env = env; this.effects = effects; this.frames = frames; this.conds = []; }
  fork() { const p = new Path(new Map(this.env), [...this.effects], this.frames.map((f) => ({ ...f }))); p.conds = [...this.conds]; return p; }
}

/**
 * Run `handler` on instruction `pc` (0-based) of function `f`. Returns the paths it can take: {effects, ret, conds}.
 * `model` is the program as it stands (instructions a handler rewrote are read as rewritten).
 */
function evaluate(machine, h, f, pc, model) {
  const { dispatcher, slots, ctx, valueSlot } = machine;
  const ctxName = h.factory.params[0] && h.factory.params[0].name;
  const cellsName = h.factory.params[1] && h.factory.params[1].name;
  const env = new Map();
  // the factory's names first: the handler's own parameters may reuse them (`function(param) return function(param, ...)`)
  if (ctxName) env.set(ctxName, V('ctx'));
  if (cellsName) env.set(cellsName, V('cells'));
  h.fn.params.forEach((p, i) => {
    const role = dispatcher.args[i];
    if (role === 'ins') env.set(p.name, V('ins', { pc }));
    else if (role === 'pc') env.set(p.name, pc + 2);              // 1-based, already moved past this instruction
    else if (role === 'top') env.set(p.name, V('top', { off: 0, base: 'in' }));
    else if (role === 'regs') env.set(p.name, V('regs'));
    else if (role === 'frame') env.set(p.name, V('frame'));
    else env.set(p.name, V('param', { role }));
  });
  const paths = [];
  let steps = 0;
  const call = { n: 0 };

  const field = (ins, k) => { const row = model.code(f, ins.pc); return row && Object.prototype.hasOwnProperty.call(row, k) ? row[k] : 0; };

  function index(o, k, path) {
    if (o === undefined || k === undefined) return undefined;
    switch (o.t) {
      case 'ins': if (typeof k === 'number') return field(o, k); return undefined;
      case 'code': if (typeof k === 'number') return V('ins', { pc: k - 1 }); return undefined;
      case 'regs': if (typeof k === 'number') return rv({ reg: k }); return undefined;
      case 'frame': {
        if (k === dispatcher.codeSlot) return V('code');
        const d = slots.get(k);
        if (!d) return undefined;
        if (d.kind === 'lib') return d.path === '' ? V('env') : V('lib', { path: d.path });
        if (d.kind === 'upvals') return V('upvals');
        if (d.kind === 'proto') return V('plist', { slot: d.slot });
        return undefined;
      }
      case 'env': if (typeof k === 'string') return rv({ global: k }); return undefined;
      case 'upvals': if (typeof k === 'number') return V('upcell', { i: k }); return undefined;
      // a captured variable is a cell { [index slot] = n, [3] = box }: its value is box[n] (the registers while open, the cell itself once closed)
      case 'upcell': if (k === 3) return V('ucbox', { i: o.i }); if (k === 3 - valueSlot) return V('ucidx', { i: o.i }); return undefined;
      case 'ucbox': if (k && k.t === 'ucidx' && k.i === o.i) return rv({ upval: o.i }); return undefined;
      case 'plist': if (typeof k === 'number') return V('pentry', { slot: o.slot, i: k }); return undefined;
      case 'ctx': {
        const kind = ctx.get(k);
        if (kind) return V('ctxfn', { kind });
        if (k === '_') return V('env');
        return undefined;
      }
      case 'cells': if (typeof k === 'number') return V('cell', { c: h.cells[k - 1] }); return undefined;
      case 'cell': if (k === valueSlot) { const c = o.c; if (c instanceof Lib) return c.path === '' ? V('env') : V('lib', { path: c.path }); if (c instanceof Site) return V('site', { name: c.name }); } return undefined;
      case 'tbl': return o.m.has(k) ? o.m.get(k) : null;
      case 'param': if (typeof k === 'number') return V('opencell', { reg: k }); return undefined;
      case 'pack': if (k === 'n') return o.n; return undefined;
      case 'rv': return rv({ index: [o.e, toIR(k)] });
      default: return undefined;
    }
  }

  function store(o, k, v, path) {
    if (o && o.t === 'regs' && typeof k === 'number') { path.effects.push({ set: k, v }); return true; }
    if (o && o.t === 'ins' && typeof k === 'number') { model.write(f, o.pc, k, v); path.effects.push({ rewrote: o.pc }); return true; }
    if (o && o.t === 'code' && typeof k === 'number' && v && v.t === 'tbl') { model.replace(f, k - 1, Object.fromEntries(v.m)); path.effects.push({ rewrote: k - 1 }); return true; }
    if (o && o.t === 'tbl') { o.m.set(k, v); return true; }
    if (o && o.t === 'rv') { path.effects.push({ store: [o.e, toIR(k), toIR(v)] }); return true; }
    if (o && o.t === 'ucbox' && k && k.t === 'ucidx' && k.i === o.i) { path.effects.push({ setupval: o.i, v }); return true; }
    if (o && o.t === 'param' && typeof k === 'number' && v && (v.t === 'tbl')) return true;     // a cell created for a register being captured
    return false;
  }

  function callValue(fn, args, node, path) {
    const flat = flatArgs(args);
    if (fn && fn.t === 'lib' && LIBS[fn.path] && flat && flat.every(isKnown)) return LIBS[fn.path](...flat);
    if (fn && fn.t === 'lib') {
      if (fn.path === 'table.unpack' || fn.path === 'unpack') {
        if (args[0] && args[0].t === 'regs' && typeof args[1] === 'number') return [V('range', { from: args[1], to: args[2] })];
        if (args[0] && args[0].t === 'pack') return args[0].items;
      }
      if (fn.path === 'table.pack') return [V('pack', { items: args, n: countOf(args) })];
      if (fn.path === 'table.create' && typeof args[0] === 'number') return [V('tbl', { m: new Map(), list: true })];
      // SETLIST: registers moved into a table held in a register
      if (fn.path === 'table.move' && args[0] && args[0].t === 'regs' && typeof args[1] === 'number' && args[4] && args[4].t === 'rv' && args[4].e.reg !== undefined && typeof args[3] === 'number') {
        path.effects.push({ setlist: args[4].e.reg, from: args[1], to: args[2], at: args[3] });
        return [];
      }
      if (fn.path === 'table.move' && args[0] && args[0].t === 'pack' && args[1] === 1 && args[4] && args[4].t === 'regs' && typeof args[3] === 'number') {
        path.effects.push({ move: args[0], n: args[2], to: args[3] });
        return [];
      }
    }
    if (fn && fn.t === 'ctxfn') {
      if (fn.kind === 'pack') return [V('pack', { items: args, n: countOf(args) })];
      if (fn.kind === 'unpack' && args[0] && args[0].t === 'pack') return args[0].items;
      if (fn.kind === 'iter' && args[0] && args[0].t === 'param') return [V('openiter'), null, null];
    }
    if (fn && fn.t === 'openiter') return [V('openkey'), V('openval')];
    if (fn && fn.t === 'site' && args.length === 2 && args[0] && args[0].t === 'pentry' && args[1] && args[1].t === 'tbl') return [rv({ closure: { slot: args[0].slot, i: args[0].i, caps: args[1] } })];
    if (fn && fn.t === 'pentry' && args.length === 2 && args[1] && args[1].t === 'tbl') return [rv({ native: { slot: fn.slot, i: fn.i, caps: args[1] } })];
    if (fn && fn.t === 'rv') {
      const id = ++call.n;
      path.effects.push({ call: id, fn: fn.e, args: args.map((a) => (a && a.t === 'range' ? a : toIR(a))) });
      return [V('callres', { id })];
    }
    return undefined;
  }

  function countOf(args) {
    const last = args[args.length - 1];
    if (last && last.t === 'callres') return V('nres', { call: last.id, fixed: args.length - 1 });
    if (last && last.t === 'range') { if (typeof last.to === 'number') return args.length - 1 + (last.to - last.from + 1); return undefined; }
    return args.length;
  }
  function flatArgs(args) { return args.every((a) => isKnown(a)) ? args : null; }

  function evalExpr(e, path, multi = false) {
    e = strip(e);
    if (!e) return multi ? [] : undefined;
    switch (e.type) {
      case 'Number': return one(e.value, multi);
      case 'String': return one(e.value, multi);
      case 'Nil': return one(null, multi);
      case 'True': return one(true, multi);
      case 'False': return one(false, multi);
      case 'Name': return one(path.env.has(e.name) ? path.env.get(e.name) : undefined, multi);
      case 'Index': {
        const o = evalExpr(e.obj, path);
        const k = evalExpr(e.key, path);
        return one(index(o, k, path), multi);
      }
      case 'Table': {
        const m = new Map();
        let i = 1;
        for (const fld of e.fields) {
          if (fld.kind === 'item') m.set(i++, evalExpr(fld.value, path));
          else if (fld.kind === 'keyed') m.set(evalExpr(fld.key, path), evalExpr(fld.value, path));
          else m.set(fld.key, evalExpr(fld.value, path));
        }
        return one(V('tbl', { m }), multi);
      }
      case 'Unary': {
        const a = evalExpr(e.arg, path);
        if (e.op === '-' && typeof a === 'number') return one(-a, multi);
        if (e.op === '#' && typeof a === 'string') return one(a.length, multi);
        if (e.op === '#' && a && a.t === 'rv') return one(rv({ len: a.e }), multi);
        if (e.op === 'not' && isKnown(a)) return one(a === null || a === false, multi);
        if (e.op === 'not' && a && a.t === 'rv') return one(rv({ not: a.e }), multi);
        if (e.op === '-' && a && a.t === 'rv') return one(rv({ unm: a.e }), multi);
        return one(undefined, multi);
      }
      case 'Binary': {
        if (e.op === 'and' || e.op === 'or') {
          const a = evalExpr(e.left, path);
          if (!isKnown(a)) return one(undefined, multi);
          const truthy = a !== null && a !== false;
          if (e.op === 'and') return truthy ? evalExpr(e.right, path, multi) : one(a, multi);
          return truthy ? one(a, multi) : evalExpr(e.right, path, multi);
        }
        const a = evalExpr(e.left, path);
        const b = evalExpr(e.right, path);
        if (CMP[e.op]) {
          if (isKnown(a) && isKnown(b)) {
            switch (e.op) {
              case '==': return one(a === b, multi); case '~=': return one(a !== b, multi);
              case '<': return one(a < b, multi); case '<=': return one(a <= b, multi); case '>': return one(a > b, multi); case '>=': return one(a >= b, multi);
              default: break;
            }
          }
          if ((a && a.t === 'rv') || (b && b.t === 'rv')) {
            if ((a && a.t !== 'rv' && !isKnown(a)) || (b && b.t !== 'rv' && !isKnown(b))) return one(undefined, multi);
            return one(rv({ cmp: e.op, a: toIR(a), b: toIR(b) }), multi);
          }
          if (a && a.t === 'openkey' && b === null) return one(V('opentest'), multi);
          if (a && a.t === 'opencell' && b === null) return one(V('opencell'), multi);
          return one(undefined, multi);
        }
        const k = arith(e.op, a, b);
        if (k !== undefined) return one(k, multi);
        if (BIN[e.op] && ((a && a.t === 'rv') || (b && b.t === 'rv')) && (a && (a.t === 'rv' || isKnown(a))) && (b && (b.t === 'rv' || isKnown(b)))) return one(rv({ bin: e.op, a: toIR(a), b: toIR(b) }), multi);
        return one(undefined, multi);
      }
      case 'Call': case 'MethodCall': {
        let fn;
        let args;
        if (e.type === 'MethodCall') return one(undefined, multi);
        fn = evalExpr(e.fn, path);
        args = [];
        e.args.forEach((a, i) => { if (i === e.args.length - 1) args.push(...evalExpr(a, path, true)); else args.push(evalExpr(a, path)); });
        const r = callValue(fn, args, e, path);
        if (r === undefined) return one(undefined, multi);
        return multi ? r : (r.length ? r[0] : null);
      }
      case 'Vararg': return multi ? [] : null;
      default: return one(undefined, multi);
    }
  }
  const one = (v, multi) => (multi ? [v] : v);

  /** results of a call spread over names: the first n of a multi value, a call's results by position */
  function spread(values, n, path) {
    const out = [];
    values.forEach((v, i) => {
      if (i < values.length - 1 || !v || v.t !== 'callres') { out.push(v); return; }
      for (let k = 1; out.length < n; k++) out.push(rv({ res: [v.id, k] }));
    });
    while (out.length < n) out.push(null);
    return out.slice(0, n);
  }

  function evalList(exprs, n, path) {
    const vals = [];
    exprs.forEach((x, i) => { if (i === exprs.length - 1) vals.push(...evalExpr(x, path, true)); else vals.push(evalExpr(x, path)); });
    return spread(vals, n, path);
  }

  function assign(targets, exprs, path) {
    // the targets' objects and keys are evaluated first, as Lua does
    const places = targets.map((t) => (t.type === 'Index' ? { o: evalExpr(t.obj, path), k: evalExpr(t.key, path) } : null));
    const vals = evalList(exprs, targets.length, path);
    targets.forEach((t, i) => {
      if (t.type === 'Name' || t.type === 'Id') { path.env.set(t.name, vals[i]); return; }
      if (t.type === 'Index') { if (!store(places[i].o, places[i].k, vals[i], path)) fail(`${h.name}: a store this reader cannot follow: ${exprText(t)}`); return; }
      fail(`${h.name}: an assignment to ${t.type}`);
    });
  }

  // ---- the statements -------------------------------------------------------------------------------------------------------------------------
  const start = new Path(env, [], [{ stmts: h.fn.body, i: 0 }]);
  // Luau's generalised iteration in front of a generic `for`: the handler first turns R[a], R[a+1], R[a+2] into an iterator triple (`__iter`, a table
  // iterated directly, or left alone when R[a] is a function) and writes the three back. With an iterator function it changes nothing, which is what a Lua 5.1
  // generic `for` assumes; the code up to the first test (the operands) runs, and the evaluation resumes after the three stores
  if (/__iter/.test(text(h.fn.body))) {
    const body = h.fn.body;
    const regsName = h.fn.params[dispatcher.args.indexOf('regs')] && h.fn.params[dispatcher.args.indexOf('regs')].name;
    let k = 0;
    for (; k < body.length; k++) {
      const st = body[k];
      if (st.type === 'If' || st.type === 'Goto' || st.type === 'Return') break;
      if (st.type === 'Local' && st.values && st.values.length) { try { assign(st.ids, st.values, start); } catch (e) { if (!(e instanceof Lift21Error)) throw e; } }
      else if (st.type === 'Local') st.ids.forEach((x) => start.env.set(x.name, null));
      else if (st.type === 'Assign') { try { assign(st.targets, st.values, start); } catch (e) { if (!(e instanceof Lift21Error)) throw e; } }
    }
    const isStore = (st) => st && st.type === 'Assign' && st.targets.length === 1 && st.targets[0].type === 'Index' && isName(st.targets[0].obj, regsName) && isName(st.values[0]);
    let at = -1;
    for (let j = k; j + 2 < body.length && at < 0; j++) {
      if (![0, 1, 2].every((d) => isStore(body[j + d]))) continue;
      const keys = [0, 1, 2].map((d) => evalExpr(body[j + d].targets[0].key, start));
      if (typeof keys[0] === 'number' && keys[1] === keys[0] + 1 && keys[2] === keys[0] + 2) at = j;
    }
    if (at < 0) fail(`${h.name}: the iterator triple written back after the generalised-iteration prep was not found`);
    [0, 1, 2].forEach((d) => start.env.set(strip(body[at + d].values[0]).name, rv({ reg: evalExpr(body[at + d].targets[0].key, start) })));
    start.frames[0].i = at + 3;
    (machine.iterPrep || (machine.iterPrep = new Set())).add(h.name);
  }
  const queue = [start];
  while (queue.length) {
    const path = queue.pop();
    let done = false;
    while (!done) {
      if (++steps > 200000) fail(`${h.name}: the handler does not finish on instruction ${pc + 1}`);
      const fr = path.frames[path.frames.length - 1];
      if (!fr) fail(`${h.name}: the handler ends without returning`);
      if (fr.i >= fr.stmts.length) {
        path.frames.pop();
        if (fr.loop) {
          // the end of a `repeat` body: the test decides whether it runs again
          const c = evalExpr(fr.loop.cond, path);
          if (!isKnown(c)) fail(`${h.name}: a loop whose end is not known on instruction ${pc + 1}`);
          if (c === null || c === false) path.frames.push({ stmts: fr.loop.body, i: 0, loop: fr.loop });
        } else if (fr.whileLoop) {
          path.frames.push({ stmts: [fr.whileLoop], i: 0 });
        }
        continue;
      }
      const s = fr.stmts[fr.i++];
      switch (s.type) {
        case 'Local': if (s.values && s.values.length) assign(s.ids, s.values, path); else s.ids.forEach((x) => path.env.set(x.name, null)); break;
        case 'Assign': assign(s.targets, s.values, path); break;
        case 'CallStmt': case 'ExprStmt': {
          const r = evalExpr(s.call || s.expr, path, true);
          if (r.length === 1 && r[0] === undefined) fail(`${h.name}: a call this reader cannot follow: ${exprText(s.call || s.expr)}`);
          break;
        }
        case 'Do': path.frames.push({ stmts: s.body, i: 0 }); break;
        case 'Label': break;
        case 'Goto': {
          let found = false;
          for (let d = path.frames.length - 1; d >= 0 && !found; d--) {
            const at = path.frames[d].stmts.findIndex((x) => x.type === 'Label' && x.name === s.label);
            if (at >= 0) { path.frames.length = d + 1; path.frames[d].i = at + 1; found = true; }
          }
          if (!found) fail(`${h.name}: goto ${s.label} leaves the handler`);
          break;
        }
        case 'Return': {
          path.ret = evalList(s.values, 5, path);
          paths.push(path);
          done = true;
          break;
        }
        case 'Repeat': path.frames.push({ stmts: s.body, i: 0, loop: s }); break;
        case 'While': {
          const c = evalExpr(s.cond, path);
          if (!isKnown(c)) fail(`${h.name}: a while loop whose test is not known`);
          if (c !== null && c !== false) path.frames.push({ stmts: s.body, i: 0, whileLoop: s });
          break;
        }
        case 'If': {
          let chosen = null;
          let forked = false;
          for (let ci = 0; ci < s.clauses.length; ci++) {
            const cl = s.clauses[ci];
            const c = evalExpr(cl.cond, path);
            if (c && c.t === 'opentest') {
              // closing upvalues: a loop over the open-upvalue table that closes every cell at or above a register
              let threshold;
              walk(cl.body, (n) => {
                if (threshold === undefined && n.type === 'Binary' && n.op === '>=') { const r = evalExpr(n.right, path); if (typeof r === 'number') threshold = r; }
              });
              if (threshold === undefined) fail(`${h.name}: a loop over the open upvalues without a register to close from`);
              path.effects.push({ close: threshold });
              chosen = [];
              break;
            }
            if (c && c.t === 'opencell') { chosen = []; break; }          // `if cell == nil then make one`: the capture is read from the cell itself
            if (c && c.t === 'rv' && c.e.cmp === '==' && c.e.b && c.e.b.k === null && c.e.a.opencell !== undefined) { chosen = []; break; }
            if (c && c.t === 'rv') {
              // a test on the running program: both ways are followed
              const other = path.fork();
              other.conds.push({ e: c.e, value: false });
              path.conds.push({ e: c.e, value: true });
              const rest = s.clauses.slice(ci + 1);
              const elseBody = rest.length ? [{ ...s, clauses: rest }] : (s.orelse || []);
              other.frames.push({ stmts: elseBody, i: 0 });
              queue.push(other);
              chosen = cl.body;
              forked = true;
              break;
            }
            if (!isKnown(c)) fail(`${h.name}: a test this reader cannot decide: ${exprText(cl.cond)}`);
            if (c !== null && c !== false) { chosen = cl.body; break; }
          }
          if (chosen === null) chosen = s.orelse || [];
          path.frames.push({ stmts: chosen, i: 0 });
          if (forked && paths.length + queue.length > 8) fail(`${h.name}: too many ways through the handler`);
          break;
        }
        default: fail(`${h.name}: a ${s.type} statement`);
      }
    }
  }
  return paths;
}

/** A value as an IR operand: a register, a constant, or a runtime value's own expression. */
function toIR(v) {
  if (isKnown(v)) return { k: v };
  if (v && v.t === 'rv') return v.e;
  if (v && v.t === 'opencell') return { opencell: v.reg };
  if (v === undefined) return { unknown: true };
  return { other: v.t };
}


// ---- one instruction: the paths of its handler, as register operations ----------------------------------------------------------------------------

const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

/**
 * What instruction `pc` of `f` does: { ops: [...], next } where an op is one of
 *   {set: r, v}  {store: [t, k, v]}  {call, fn, args, results}  {close: r}  {setupval: i, v}  {ret: {from, to}}  {jump: pc}  {branch: {cond, t, f}}
 * and `consumed` the instructions after it that it reads as its own (a closure's capture list).
 */
function readInstruction(machine, f, pc, model) {
  const row = model.code(f, pc);
  const h = machine.handlers.get(row.op);
  if (!h) fail(`opcode ${row.op} (instruction ${pc + 1}) has no handler in this build`);
  const paths = evaluate(machine, h, f, pc, model);
  const R = machine.dispatcher.returns;
  const read = (p) => {
    const r = Object.fromEntries(R.map((role, i) => [role, p.ret[i]]));
    return r;
  };
  if (paths.length === 1) {
    const p = paths[0];
    const r = read(p);
    return { effects: p.effects, r, handler: h.name };
  }
  if (paths.length === 2) {
    const [a, b] = paths;
    if (!same(a.effects, b.effects)) fail(`${h.name}: the two ways through the handler do different things (instruction ${pc + 1})`);
    const ra = read(a);
    const rb = read(b);
    if (ra.done || rb.done) fail(`${h.name}: a handler that returns on one way only`);
    const cond = a.conds[a.conds.length - 1];
    return { effects: a.effects, r: ra, branch: { cond: cond.e, whenTrue: cond.value ? ra.pc : rb.pc, whenFalse: cond.value ? rb.pc : ra.pc }, handler: h.name };
  }
  return fail(`${h.name}: ${paths.length} ways through the handler`);
}

// ---- Lua 5.1 -----------------------------------------------------------------------------------------------------------------------------------------

class FnBuilder {
  constructor(base) { this.code = []; this.k = []; this.kmap = new Map(); this.base = base; this.pending = []; this.protos = []; }
  emit(ins) { this.code.push(ins); return this.code.length - 1; }
  r(n) { const x = n - this.base; if (x < 0 || x > 249) fail(`register ${n} is outside the frame`); return x; }
  kindex(v) {
    const key = typeof v === 'number' ? `n:${Object.is(v, -0) ? '-0' : v}` : `${typeof v}:${v}`;
    if (!this.kmap.has(key)) { this.kmap.set(key, this.k.length); this.k.push(v); }
    return this.kmap.get(key);
  }
  jump(target) { this.pending.push({ at: this.emit({ op: 'Jmp', a: 0, b: 0, c: 0 }), target }); }
}

const regOf = (e) => (e && e.reg !== undefined ? e.reg : null);

/** Where control goes after an instruction that was read: its successors, the loop body first for a `for` step. */
function successors(I, pc) {
  if (I.headOf !== undefined) return [I.headOf];
  if (I.tfor) return [I.tfor.body, I.tfor.exit];
  if (I.r.done === true) return [];
  return typeof I.r.pc === 'number' ? [I.r.pc - 1] : [];
}

/**
 * The order the instructions are written in. MoonVeil places a function's blocks out of source order (a loop's tail after the code that follows the loop);
 * the decompiler reads the layout a Lua compiler writes. So the instructions are laid out again: depth first from the entry, a generic `for` as the jump
 * into it, its body (only the instructions of the loop), its step, then what follows it. Instructions nothing reaches are left out.
 */
function layout(read) {
  const pcs = [...read.keys()];
  const succ = new Map(pcs.map((pc) => [pc, successors(read.get(pc), pc).filter((t) => read.has(t))]));
  const pred = new Map(pcs.map((pc) => [pc, []]));
  for (const [pc, ss] of succ) for (const t of ss) pred.get(t).push(pc);
  // the loops: a step that a head jumps to; its body is what the step reaches from its body entry and what reaches the step again
  const loops = new Map();
  for (const pc of pcs) {
    const I = read.get(pc);
    if (I.headOf === undefined) continue;
    const T = I.headOf;
    const J = read.get(T);
    const fwd = new Set();
    const stack = [J.tfor.body];
    while (stack.length) { const n = stack.pop(); if (n === T || fwd.has(n) || !read.has(n)) continue; fwd.add(n); stack.push(...succ.get(n)); }
    const body = new Set();
    const back = [...pred.get(T)].filter((p) => fwd.has(p));
    while (back.length) { const n = back.pop(); if (body.has(n) || !fwd.has(n)) continue; body.add(n); back.push(...pred.get(n)); }
    if (fwd.has(J.tfor.body)) body.add(J.tfor.body);
    loops.set(T, { body, entry: J.tfor.body, exit: J.tfor.exit });
  }
  const order = [];
  const placed = new Set();
  const open = new Set();
  function visit(n, within) {
    if (placed.has(n) || open.has(n) || !read.has(n)) return;
    if (within && !within.has(n)) { deferred.push(n); return; }
    if (loops.has(n)) {
      const L = loops.get(n);
      open.add(n);
      visit(L.entry, L.body);
      open.delete(n);
      placed.add(n);
      order.push(n);
      visit(L.exit, within);
      return;
    }
    placed.add(n);
    order.push(n);
    for (const s of succ.get(n)) visit(s, within);
  }
  let deferred = [];
  visit(pcs[0], null);
  while (deferred.length) { const d = deferred; deferred = []; for (const n of d) visit(n, null); }
  return order;
}

/** One prototype of the program as a Lua 5.1 function. */
function buildFunction(machine, f, model, ctx, depth = 0) {
  if (depth > 100) fail('functions nested too deeply');
  const B = new FnBuilder(ctx.base);
  const startOf = new Map();
  const consumed = new Set();
  let opened = null;                      // a call whose results run to the top (the next instruction takes them all)
  const stats = ctx.stats;
  const loadValue = (r, v) => {
    if (v === null) { B.emit({ op: 'LoadNil', a: B.r(r), b: B.r(r), c: 0 }); return; }
    if (typeof v === 'boolean') { B.emit({ op: 'LoadBool', a: B.r(r), b: v ? 1 : 0, c: 0 }); return; }
    B.emit({ op: 'LoadConst', a: B.r(r), b: B.kindex(v), c: 0 });
  };
  const rk = (e) => {
    if (e.k !== undefined) { if (e.k === null || typeof e.k === 'boolean') return null; const i = B.kindex(e.k); return i < 256 ? 256 + i : null; }
    if (e.reg !== undefined) return B.r(e.reg);
    return null;
  };
  // first every instruction is read (in order: a handler may rewrite a later instruction), then written
  const read = new Map();
  for (let pc = 0; pc < f.code.length; pc++) {
    if (consumed.has(pc)) continue;
    const I = readInstruction(machine, f, pc, model);
    read.set(pc, I);
    // a closure's capture list is read by the closure's own handler
    for (const e of I.effects) if (e.set !== undefined && e.v && e.v.t === 'rv' && e.v.e.closure) { const n = e.v.e.closure.caps.m.size; for (let k = 1; k <= n; k++) consumed.add(pc + k); }
    // a generic `for` step: one call of R[a](R[a+1], R[a+2]) whose results go to R[a+2..], and a test of the first on nil
    if (I.branch) {
      const calls = I.effects.filter((e) => e.call !== undefined);
      const sets = I.effects.filter((e) => e.set !== undefined);
      if (calls.length === 1 && I.effects.length === calls.length + sets.length && sets.every((e) => e.v && e.v.t === 'rv' && e.v.e.res && e.v.e.res[0] === calls[0].call)) {
        I.tfor = { base: regOf(calls[0].fn), n: sets.filter((e) => e.set >= regOf(calls[0].fn) + 3).length, body: I.branch.whenFalse - 1, exit: I.branch.whenTrue - 1 };
      }
    }
  }
  // MoonVeil steps a generic `for` at its head (with Luau's iteration prep) and again at its tail; Lua 5.1 jumps from the head to the one step at the tail.
  // A head is a step whose body starts right after it, with a step further down that has the same registers, body and exit
  for (const [pc, I] of read) {
    if (!I.tfor) continue;
    for (const [t, J] of read) {
      if (t <= pc || !J.tfor || J.tfor.base !== I.tfor.base || J.tfor.n !== I.tfor.n || J.tfor.body !== I.tfor.body || J.tfor.exit !== I.tfor.exit) continue;
      I.headOf = t;
      break;
    }
  }
  const order = layout(read);
  stats.unreachable += read.size - order.length;
  for (let oi = 0; oi < order.length; oi++) {
    const pc = order[oi];
    const after = oi + 1 < order.length ? order[oi + 1] : -1;
    startOf.set(pc, B.code.length);
    const I = read.get(pc);
    stats.handlers.add(I.handler);
    if (I.headOf !== undefined) {
      if (I.headOf !== after) B.jump(I.headOf);
      stats.loopHeads++;
      if (machine.iterPrep && machine.iterPrep.has(I.handler)) stats.generalisedIteration++;
      continue;
    }
    const calls = new Map();
    const resultsOf = new Map();
    // the register operations, in order
    for (let ei = 0; ei < I.effects.length; ei++) {
      const e = I.effects[ei];
      if (e.rewrote !== undefined) continue;
      if (e.call !== undefined) { calls.set(e.call, e); continue; }
      if (e.move) {
        // a call's results moved into registers: `R[to .. to+n-1] = fn(args)`
        const items = e.move.items;
        const last = items[items.length - 1];
        if (!last || last.t !== 'callres' || items.length !== 1) fail(`${I.handler}: results moved that are not a call's`);
        const c = calls.get(last.id);
        emitCall(c, e.to, e.n);
        calls.delete(last.id);
        continue;
      }
      if (e.close !== undefined) { B.emit({ op: 'Close', a: B.r(e.close), b: 0, c: 0 }); continue; }
      if (e.setlist !== undefined) {
        if (e.from !== e.setlist + 1) fail(`${I.handler}: a list stored from registers that do not follow the table`);
        if ((e.at - 1) % 50) fail(`${I.handler}: a list stored from index ${e.at}, which Lua 5.1 cannot write`);
        let b;
        if (typeof e.to === 'number') b = e.to - e.from + 1;
        else if (e.to && e.to.t === 'top' && e.to.off === 0) b = 0;
        else fail(`${I.handler}: a list stored up to a register that is not known`);
        B.emit({ op: 'SetList', a: B.r(e.setlist), b, c: (e.at - 1) / 50 + 1 });
        continue;
      }
      if (e.setupval !== undefined) {
        const v = toIR(e.v);
        if (regOf(v) === null) fail(`${I.handler}: an upvalue set from something that is not a register`);
        B.emit({ op: 'SetUpval', a: B.r(v.reg), b: e.setupval - 1, c: 0 });
        continue;
      }
      if (e.store) {
        const [t, k, v] = e.store;
        if (regOf(t) === null) fail(`${I.handler}: a table store on something that is not a register`);
        const kk = rk(k);
        const vv = rk(v);
        if (kk === null || vv === null) fail(`${I.handler}: a table store with an operand this reader cannot write`);
        B.emit({ op: 'SetTable', a: B.r(t.reg), b: kk, c: vv });
        continue;
      }
      if (e.set !== undefined) {
        const v = e.v;
        // the results of a call given out to registers one by one: a generic `for` step, read below as a whole
        if (v && v.t === 'rv' && v.e.res) { (resultsOf.get(v.e.res[0]) || resultsOf.set(v.e.res[0], []).get(v.e.res[0])).push({ r: e.set, k: v.e.res[1] }); continue; }
        emitSet(e.set, v, I);
        continue;
      }
      fail(`${I.handler}: an operation this reader does not write (${JSON.stringify(e).slice(0, 80)})`);
    }
    // a call whose results were given out one by one, with a test of the first on nil: Lua's generic `for` step
    for (const [id, c] of calls) {
      const outs = resultsOf.get(id) || [];
      if (!I.branch) {
        if (outs.length) fail(`${I.handler}: a call whose results go to registers one by one, without a loop test`);
        emitCall(c, null, 0);
        continue;
      }
      const base = regOf(c.fn);
      const ok = base !== null && c.args.length === 2 && regOf(c.args[0]) === base + 1 && regOf(c.args[1]) === base + 2
        && I.branch.cond.cmp === '==' && I.branch.cond.a.res && I.branch.cond.a.res[0] === id && I.branch.cond.a.res[1] === 1 && I.branch.cond.b.k === null;
      if (!ok) fail(`${I.handler}: a conditional call that is not a generic for step`);
      const vars = outs.filter((o) => o.r >= base + 3).sort((x, y) => x.r - y.r);
      if (!vars.every((o, i) => o.r === base + 3 + i && o.k === i + 1)) fail(`${I.handler}: the loop variables are not the call's results in order`);
      if (!outs.some((o) => o.r === base + 2 && o.k === 1)) fail(`${I.handler}: the loop's control variable is not its first result`);
      B.emit({ op: 'TForLoop', a: B.r(base), b: 0, c: vars.length });
      B.jump(I.branch.whenFalse - 1);
      if (I.branch.whenTrue - 1 !== after) B.jump(I.branch.whenTrue - 1);
      stats.forLoops++;
      if (I.handler && machine.iterPrep && machine.iterPrep.has(I.handler)) stats.generalisedIteration++;
      I.branch = null;
      I.stepped = true;
    }
    if (I.stepped) continue;
    if (I.branch) fail(`${I.handler}: a branch on something this reader does not know`);
    // the end of the instruction: return, jump or fall through
    const r = I.r;
    if (r.done === true) {
      const from = r.start;
      const n = r.count;
      if (typeof from !== 'number') fail(`${I.handler}: a return whose first register is not known`);
      if (typeof n === 'number') B.emit({ op: 'Return', a: B.r(from), b: n + 1, c: 0 });
      else if (n && n.t === 'top' && arith('+', from, n) && arith('-', arith('+', from, n), 1) && arith('-', arith('+', from, n), 1).off === 0) B.emit({ op: 'Return', a: B.r(from), b: 0, c: 0 });
      else fail(`${I.handler}: a return of a count this reader cannot write`);
      continue;
    }
    if (r.done !== null && r.done !== false && r.done !== undefined) fail(`${I.handler}: the end-of-function flag is not known`);
    if (typeof r.pc !== 'number') fail(`${I.handler}: the next instruction is not known`);
    const target = r.pc - 1;
    if (target !== after) B.jump(target);
  }
  startOf.set(f.code.length, B.code.length);
  const last = B.code[B.code.length - 1];
  if (!last || last.op !== 'Return') B.emit({ op: 'Return', a: 0, b: 1, c: 0 });
  for (const p of B.pending) {
    if (!startOf.has(p.target)) fail(`a jump to instruction ${p.target + 1}, which does not exist`);
    B.code[p.at].b = startOf.get(p.target) - (p.at + 1);
  }
  const takesOpen = (i) => i && ((i.op === 'Call' || i.op === 'TailCall' || i.op === 'Return' || i.op === 'SetList') && i.b === 0);
  B.code.forEach((ins, i) => { if (ins.op === 'Call' && ins.c === 0 && !takesOpen(B.code[i + 1])) ins.c = 1; });
  const nups = f.meta.nups;
  return {
    source: null, line: 0, lastLine: 0, nups, numParams: f.meta.params, isVararg: f.meta.vararg ? 2 : 0,
    maxStack: Math.min(250, Math.max(maxStack(B.code), (f.ints[0] || 0) + 2)),
    code: Uint32Array.from(B.code.map(encode)), k: B.k, protos: B.protos, lines: [], locals: [], upNames: [],
  };

  function emitCall(c, to, n) {
    const base = regOf(c.fn);
    if (base === null) fail('a call of something that is not in a register');
    if (to !== null && to !== base) fail('a call whose results do not go to its own register');
    let b;
    const args = c.args;
    if (args.length === 1 && args[0].t === 'range') {
      const { from, to: end } = args[0];
      if (from !== base + 1) fail('a call whose arguments do not follow it');
      if (typeof end === 'number') b = end - from + 2;
      else if (end && end.t === 'top' && end.off === 0) b = 0;
      else fail('a call whose last argument is not known');
    } else {
      args.forEach((a, i) => { if (regOf(a) !== base + 1 + i) fail('a call whose arguments do not follow it'); });
      b = args.length + 1;
    }
    let cc;
    if (typeof n === 'number') cc = n + 1;
    else if (n && n.t === 'nres') cc = 0;
    else fail('a call whose number of results is not known');
    B.emit({ op: 'Call', a: B.r(base), b, c: cc });
  }

  function emitSet(r, v, I) {
    if (isKnown(v)) { loadValue(r, v); return; }
    if (v && v.t === 'tbl' && v.m.size === 0) { B.emit({ op: 'NewTable', a: B.r(r), b: 0, c: 0 }); return; }
    if (!v || v.t !== 'rv') fail(`${I.handler}: a register set to ${v === undefined ? 'something unknown' : v.t}`);
    const e = v.e;
    const a = B.r(r);
    if (e.reg !== undefined) { if (e.reg !== r) B.emit({ op: 'Move', a, b: B.r(e.reg), c: 0 }); return; }
    if (e.global !== undefined) { B.emit({ op: 'GetGlobal', a, b: B.kindex(e.global), c: 0 }); return; }
    if (e.upval !== undefined) { B.emit({ op: 'GetUpval', a, b: e.upval - 1, c: 0 }); return; }
    if (e.len !== undefined && regOf(e.len) !== null) { B.emit({ op: 'Len', a, b: B.r(e.len.reg), c: 0 }); return; }
    if (e.not !== undefined && regOf(e.not) !== null) { B.emit({ op: 'Not', a, b: B.r(e.not.reg), c: 0 }); return; }
    if (e.unm !== undefined && regOf(e.unm) !== null) { B.emit({ op: 'Unm', a, b: B.r(e.unm.reg), c: 0 }); return; }
    if (e.index) { const [t, k] = e.index; const kk = rk(k); if (regOf(t) === null || kk === null) fail(`${I.handler}: an index this reader cannot write`); B.emit({ op: 'GetTable', a, b: B.r(t.reg), c: kk }); return; }
    if (e.bin) {
      const OPN = { '+': 'Add', '-': 'Sub', '*': 'Mul', '/': 'Div', '%': 'Mod', '^': 'Pow' };
      if (OPN[e.bin]) { const b = rk(e.a); const c = rk(e.b); if (b === null || c === null) fail(`${I.handler}: arithmetic on an operand this reader cannot write`); B.emit({ op: OPN[e.bin], a, b, c }); return; }
      if (e.bin === '..' && regOf(e.a) !== null && regOf(e.b) === regOf(e.a) + 1) { B.emit({ op: 'Concat', a, b: B.r(e.a.reg), c: B.r(e.b.reg) }); return; }
      fail(`${I.handler}: ${e.bin} on operands this reader cannot write`);
    }
    if (e.cmp) {
      // R[a] = (x op y): a test that skips the next instruction, and two loads
      const flip = { '>': '<', '>=': '<=' };
      let op = e.cmp;
      let x = e.a;
      let y = e.b;
      if (flip[op]) { op = flip[op]; [x, y] = [y, x]; }
      const name = { '==': 'Eq', '~=': 'Eq', '<': 'Lt', '<=': 'Le' }[op];
      const want = op === '~=' ? 0 : 1;
      const b = rk(x);
      const c = rk(y);
      if (b === null || c === null) fail(`${I.handler}: a comparison of an operand this reader cannot write`);
      B.emit({ op: name, a: want, b, c });
      B.emit({ op: 'Jmp', a: 0, b: 1, c: 0 });
      B.emit({ op: 'LoadBool', a, b: 0, c: 1 });
      B.emit({ op: 'LoadBool', a, b: 1, c: 0 });
      return;
    }
    if (e.closure) {
      const { i, caps } = e.closure;
      const child = f.protos[i - 1];
      if (!child || child.native) fail(`${I.handler}: a closure of prototype ${i}, which is not a function of the program`);
      const list = [...caps.m.entries()].sort((x, y) => x[0] - y[0]).map(([, c]) => c);
      ctx.fixHeader(child, list.length);
      const fn = buildFunction(machine, child, model, ctx, depth + 1);
      B.protos.push(fn);
      B.emit({ op: 'Closure', a, b: B.protos.length - 1, c: 0 });
      for (const c of list) {
        if (c && c.t === 'opencell') B.emit({ op: 'Move', a: 0, b: B.r(c.reg), c: 0 });
        else if (c && c.t === 'upcell') B.emit({ op: 'GetUpval', a: 0, b: c.i - 1, c: 0 });
        else fail(`${I.handler}: a capture this reader does not know`);
      }
      I.skip = list.length;
      stats.closures++;
      return;
    }
    if (e.native) {
      const { i, caps } = e.native;
      const name = f.strings[i - 1];
      if (name === undefined) fail(`${I.handler}: native ${i} is not named in the function`);
      if (caps.m.size) fail(`${I.handler}: the native ${name} captures variables of the VM function; natives with upvalues are not rebuilt`);
      ctx.natives.add(name);
      B.emit({ op: 'GetGlobal', a, b: B.kindex(`${NATIVE}${name}`), c: 0 });
      return;
    }
    fail(`${I.handler}: a register set to an expression this reader does not write (${JSON.stringify(e).slice(0, 80)})`);
  }
}

export const NATIVE = '__moonveil_native_';

/** The program as it stands: instructions, with the rewrites handlers make (string constants decrypted in place) applied. */
function programModel() {
  const rows = new Map();
  const rowsOf = (f) => { if (!rows.has(f)) rows.set(f, f.code.map((x) => ({ ...x }))); return rows.get(f); };
  return {
    code: (f, pc) => rowsOf(f)[pc],
    write: (f, pc, k, v) => { const r = rowsOf(f)[pc]; if (!r) fail(`a handler writes instruction ${pc + 1}, which does not exist`); if (!isKnown(v)) fail('a handler writes something unknown into an instruction'); r[k] = v; },
    replace: (f, pc, row) => {
      const list = rowsOf(f);
      if (!list[pc]) fail(`a handler replaces instruction ${pc + 1}, which does not exist`);
      const op = row[machineOpSlot.slot];
      list[pc] = { ...Object.fromEntries(Object.entries(row).filter(([k]) => /^\d+$/.test(k)).map(([k, v]) => [k, v])), op };
    },
  };
}
const machineOpSlot = { slot: null };

/**
 * The program rebuilt as a Lua 5.1 chunk.
 * @param {object} prog readProgram21's result
 * @param {object} machine readMachine21's result
 * @param {object} schema deriveSchema21's result (the opcode slot and the constant slots the reader resolves)
 */
export function lift21(prog, machine, schema) {
  const ins = schema.steps.find((s) => s.kind === 'instructions');
  const resolve = schema.steps.find((s) => s.kind === 'resolve');
  machineOpSlot.slot = ins.opcodeSlot;
  // the instructions as the interpreter sees them: the opcode under its slot, the resolved constant slots holding the constant itself
  const prep = (f) => {
    if (f.native) return;
    f.code = f.code.map((x) => {
      const row = { ...x };
      row[ins.opcodeSlot] = x.op;
      for (const s of (resolve ? resolve.slots : [])) {
        const v = row[s] || 0;
        if (v === 0) { row[s] = 0; continue; }
        const c = f.k[v - 1];
        if (c === undefined) fail(`an instruction names constant ${v} of ${f.k.length}`);
        row[s] = c && typeof c === 'object' && c.string ? prog.strings[c.string - 1] : c;
      }
      return row;
    });
    f.protos.forEach(prep);
  };
  prep(prog.main);
  const model = programModel();
  // what each prototype's two header bytes are: the closure that makes it says how many upvalues it has; the other is its parameter count
  const meta = (f, nups) => {
    const [b0, b1] = f.bytes;
    let params = 0;
    if (nups !== undefined) params = b0 === nups && b1 !== nups ? b1 : b1 === nups && b0 !== nups ? b0 : Math.min(b0, b1);
    f.meta = { nups: nups || 0, params, vararg: nups === undefined };
  };
  const all = [];
  const visit = (f) => { if (f.native) return; all.push(f); meta(f, undefined); f.protos.forEach(visit); };
  visit(prog.main);
  prog.main.meta.params = 0;
  // registers: 1-based in the VM; a function's parameters are its first registers
  const ctx = { base: 1, natives: new Set(), stats: { handlers: new Set(), closures: 0, forLoops: 0, generalisedIteration: 0, loopHeads: 0, unreachable: 0 } };
  // headers are fixed once the closure that makes a function is read; the parameter count needs the upvalue count first
  const fixHeader = (child, nups) => meta(child, nups);
  const main = buildFunctionWithHeaders(machine, prog.main, model, ctx, fixHeader);
  main.isVararg = 2;
  const bytes = dumpChunk51({ main, header: { little: true, intSize: 4, sizeT: 8, numSize: 8 } }, { strip: true });
  let functions = 0;
  let instructions = 0;
  const count = (fn) => { functions++; instructions += fn.code.length; fn.protos.forEach(count); };
  count(main);
  return { bytes, natives: [...ctx.natives], stats: { functions, instructions, handlers: ctx.stats.handlers.size, closures: ctx.stats.closures, forLoops: ctx.stats.forLoops, generalisedIteration: ctx.stats.generalisedIteration, loopHeads: ctx.stats.loopHeads } };
}

function buildFunctionWithHeaders(machine, f, model, ctx, fixHeader) {
  ctx.fixHeader = fixHeader;
  return buildFunction(machine, f, model, ctx);
}

// ---- the whole program ----------------------------------------------------------------------------------------------------------------------------

/** The slot a cell keeps its value in: cells are `{ [i] = v, [v] = value }`, the number under i naming the value's slot. */
export function cellValueSlot(ast) {
  const votes = new Map();
  walk(ast, (n) => {
    if (n.type !== 'Table' || n.fields.length !== 2 || !n.fields.every((f) => f.kind === 'keyed' && strip(f.key).type === 'Number')) return undefined;
    const [a, b] = n.fields;
    for (const [x, y] of [[a, b], [b, a]]) {
      const v = strip(x.value);
      if (v.type === 'Number' && v.value === strip(y.key).value && strip(y.key).value !== strip(x.key).value) votes.set(v.value, (votes.get(v.value) || 0) + 1);
    }
    return undefined;
  });
  const best = [...votes].sort((p, q) => q[1] - p[1])[0];
  return best ? best[0] : null;
}

/**
 * MoonVeil 2.1.0's program rebuilt: the VM's functions lifted (lift21) and decompiled, put in place of the factory that runs the VM's container, and the
 * table of factories joined around it (the code MoonVeil left as plain Lua: the glue that calls the VM's function, and the natives).
 * The chunk is rewritten in place. Throws Lift21Error (or the join's JoinError) when any part cannot be read; nothing is changed then.
 * @returns {object} what was done
 */
export function rebuildProgram21(chunk, { snapshot, prog, schema }) {
  const members = membersOf(chunk, snapshot);
  const ins = schema.steps.find((x) => x.kind === 'instructions');
  const valueSlot = cellValueSlot(chunk);
  if (valueSlot === null) fail('the slot cells keep their value in was not found');
  const machine = readMachine21(chunk, members, { opSlot: ins.opcodeSlot, valueSlot });
  const lifted = lift21(prog, machine, schema);
  const out = decompile(parseChunk(lifted.bytes));
  if (out.failures.length) fail(`the decompiler could not structure ${out.failures.length} function(s) of the VM: ${out.failures[0]}`);
  // the factory that runs the container: `return ctx.RUN(ctx.UNPACK(ctx.TEXT "..."), ...)`
  let runner = null;
  for (const [k, f] of members) {
    if (!f || f.type !== 'Func' || k === snapshot.entry) continue;
    if (findContainerCall({ type: 'Chunk', body: f.body }, walk)) { if (runner) fail('two factories run a VM container'); runner = k; }
  }
  if (!runner) fail('the factory that runs the VM\u2019s container was not found');
  // the replacement: a factory that returns the VM's main function; natives the VM makes are sites of their factories
  const ctxName = '__mv_ctx';
  const body = out.ast.body;
  const transformNatives = (n) => {
    if (!n || typeof n !== 'object') return n;
    if (Array.isArray(n)) return n.map(transformNatives);
    if (n.type === 'Name' && n.name.startsWith(NATIVE)) return { type: 'MethodCall', obj: { type: 'Name', name: ctxName }, name: n.name.slice(NATIVE.length), args: [] };
    for (const key of Object.keys(n)) if (key !== 'line' && n[key] && typeof n[key] === 'object') n[key] = transformNatives(n[key]);
    return n;
  };
  transformNatives(body);
  for (const name of lifted.natives) if (!members.has(name)) fail(`the native ${name} is not a factory of the table`);
  const factory = { type: 'Func', params: [{ type: 'Id', name: ctxName }], vararg: false, body: [{ type: 'Return', values: [{ type: 'Func', params: [], vararg: true, body }] }] };
  const joined = joinMoonVeil(chunk, snapshot, { replace: new Map([[runner, factory]]) });
  return { ...lifted.stats, natives: lifted.natives.length, runner, sites: joined.sites };
}
