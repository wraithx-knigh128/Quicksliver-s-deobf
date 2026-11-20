// LuaObfuscator.com's virtual machine ("VM" preset), lifted back to source. Prompt XXIV.
//
// Evidence: 4473 scripts filed under LuaObfuscator/VM in a public sample collection (github.com/terrorlua/obfuscator-samples; no licence is
// stated, so they stay outside the repository). Read as text; the deserialiser below is run in this project's sandbox, the program never.
//
// What an output is (read on the scripts):
//
//   local v0=tonumber;local v1=string.byte;...;local v13=unpack or table.unpack;local v14=tonumber;
//   local function v15(v16,v17,...)        the entry: v16 is the program as text, v17 the environment
//     v16 = hex pairs, "nQ" marks a run of n copies of the next pair     (decoded with gsub)
//     v20..v25                             bit field / u8 / u16 / u32 / double / string readers
//     v27 = function(...) return {...}, select("#", ...) end
//     v28 = the deserialiser: constants (type-coded), the parameter count, the instructions, the nested functions -- in an order and with
//           type codes and field layouts that differ in every build (462 different deserialisers in 506 scripts)
//     v29 = function(proto, upvalues, env) ... return function(...) <the interpreter> end end
//     return v29(v28(), {}, v17)(...)
//   end
//   return v15("LOL!<hex>", v9(), ...)
//
// Instructions are tables {opcode, A, B, C}; the deserialiser has already put the constant in place of an operand its mode bits mark, so an
// operand is a register number or the constant itself. The interpreter is `while true do I = code[pc]; op = I[1]; <binary tree over op>;
// pc = pc + 1 end`; a handler is IronBrew-style code over the stack (`S[I[2]] = S[I[3]]`), and some handlers fuse several instructions
// (`...; pc = pc + 1; I = code[pc]; ...`).
//
// The deserialiser is not re-implemented: the script's own is run in the sandbox (it only reads the text it is given), and its result is read
// back. Each instruction is then told by the text of its handler with its operands filled in.

import { parse } from '../core/parser.js';
import { createMachine } from '../sandbox/sandbox.js';
import { compileAst, callValue } from '../sandbox/interp.js';
import { LuaTable } from '../sandbox/value.js';
import { find, text } from './zartha-vm.js';
import { unparen } from './vmprofile.js';
import { foldPass } from '../passes/fold.js';
import { simplifyPass } from '../passes/simplify.js';
import { unflattenMoonVeil } from './moonveil-cff.js';

export class LuaObfVmError extends Error {}
const fail = (m) => { throw new LuaObfVmError(m); };

const isName = (e, n) => e && e.type === 'Name' && (n === undefined || e.name === n);

// ---- the entry --------------------------------------------------------------------------------------------------------------------

/** The entry function, the deserialiser and the interpreter builder, by the shape of `return F("...", env(), ...)` and F's last return. */
export function locate(ast) {
  const last = ast.body[ast.body.length - 1];
  const call = last && last.type === 'Return' && last.values.length === 1 ? unparen(last.values[0]) : null;
  if (!call || call.type !== 'Call' || !isName(call.fn) || !call.args[0] || call.args[0].type !== 'String') return null;
  const entry = ast.body.find((s) => s.type === 'LocalFunction' && s.id.name === call.fn.name);
  if (!entry) return null;
  const body = entry.func.body;
  const ret = body[body.length - 1];
  const outer = ret && ret.type === 'Return' && ret.values.length === 1 ? unparen(ret.values[0]) : null;
  // return VM(DESER(), {}, ENV)(...)
  const inner = outer && outer.type === 'Call' && outer.args.length === 1 && outer.args[0].type === 'Vararg' ? unparen(outer.fn) : null;
  if (!inner || inner.type !== 'Call' || !isName(inner.fn) || inner.args.length !== 3) return null;
  const [d, up, env] = inner.args;
  if (!d || d.type !== 'Call' || !isName(d.fn) || d.args.length || !up || up.type !== 'Table' || !isName(env)) return null;
  const vmDecl = find(body, (n) => n.type === 'LocalFunction' && n.id.name === inner.fn.name)[0];
  if (!vmDecl) return null;
  return { entry, entryCall: call, payload: call.args[0].value, vm: vmDecl, vmName: inner.fn.name, deserName: d.fn.name };
}

export const looksLikeLuaObfVm = (ast) => { try { return Boolean(locate(ast)); } catch { return false; } };

// ---- the program, as the script's own deserialiser reads it ----------------------------------------------------------------------

/** Which field of the proto table holds the code, the nested functions and the parameter count (read from the interpreter builder). */
function protoFields(vm) {
  const [P] = vm.func.params.map((p) => p.name);
  const fields = new Map();      // local name -> index into P
  for (const s of vm.func.body) {
    if (s.type !== 'Local') continue;
    s.ids.forEach((id, i) => { const v = s.values[i] && unparen(s.values[i]); if (v && v.type === 'Index' && isName(v.obj, P) && v.key.type === 'Number') fields.set(id.name, v.key.value); });
  }
  const closure = vm.func.body.find((s) => s.type === 'Return' && s.values[0] && s.values[0].type === 'Func');
  if (!closure) fail('the interpreter builder does not return the interpreter');
  const fn = closure.values[0];
  const alias = new Map();       // closure local -> P index
  for (const s of fn.body) {
    if (s.type !== 'Local') continue;
    s.ids.forEach((id, i) => { const v = s.values[i]; if (isName(v) && fields.has(v.name)) alias.set(id.name, fields.get(v.name)); });
  }
  return { fn, alias };
}

function luaToJs(v, depth = 0) {
  if (depth > 400) fail('the program is nested too deeply');
  if (v instanceof LuaTable) {
    const o = { arr: v.arr.map((x) => luaToJs(x, depth + 1)), hash: new Map() };
    if (v.hash) for (const [k, x] of v.hash) o.hash.set(k, luaToJs(x, depth + 1));
    return o;
  }
  return v;
}
const tget = (t, k) => (t && typeof k === 'number' && Number.isInteger(k) && k >= 1 && k <= t.arr.length ? t.arr[k - 1] : t && t.hash.get(k));

/** Run the script with its entry returning the deserialiser's result instead of starting the interpreter. */
export function deserialize(source, loc, { fuel = 400_000_000, timeMs = 60_000 } = {}) {
  const ast = parse(source);
  const l2 = locate(ast);
  if (!l2) fail('the entry was not found in the copy');
  const ret = l2.entry.func.body[l2.entry.func.body.length - 1];
  ret.values = [{ type: 'Call', fn: { type: 'Name', name: l2.deserName }, args: [], sugar: null }];
  const m = createMachine({ fuel, timeMs, dialect: 'luau' });
  let out;
  try { out = callValue(m, compileAst(m, ast, 'luaobf', m.globals), [], '')[0]; } catch (e) { fail(`the deserialiser did not run in the sandbox: ${String(e.message || e).slice(0, 160)}`); }
  if (!(out instanceof LuaTable)) fail('the deserialiser did not return a table');
  return luaToJs(out);
}

// ---- roles in the interpreter -----------------------------------------------------------------------------------------------------

// `I = CODE[PC]; OP = I[1]` -- as assignments to the loop's outer locals, or as locals of the loop body once cleaned
const asgn = (s) => (s && s.type === 'Assign' && s.targets.length === 1 && s.values.length === 1 ? { name: s.targets[0].name, value: s.values[0] }
  : s && s.type === 'Local' && s.ids.length === 1 && s.values.length === 1 ? { name: s.ids[0].name, value: s.values[0] } : null);

/**
 * The fetch (`I = CODE[PC]; OP = I[1]`, as assignments or locals) and the tree of tests on OP, wherever the generator put them: in a plain
 * `while true` loop, or split over the states of a small state machine (`if s == 0 then I = CODE[PC]; OP = I[1]; s = 1 end`, `if s == 1
 * then <dispatch> end`) as some builds do. Returned in the shape the readers use: `{ body: [fetchI, fetchOP, dispatchIf] }`.
 */
function dispatchLoop(fn) {
  // every `X = A[B]; Y = X[1]` pair is a candidate (handlers contain look-alikes); the real one's Y is tested by the largest tree
  const cands = [];
  find(fn.body, (n) => {
    const list = Array.isArray(n.body) ? n.body : null;
    if (!list) return false;
    for (let i = 0; i + 1 < list.length; i++) {
      const a = asgn(list[i]); const b = asgn(list[i + 1]);
      const av = a && unparen(a.value); const bv = b && unparen(b.value);
      if (av && av.type === 'Index' && isName(av.obj) && isName(av.key) && bv && bv.type === 'Index' && isName(bv.obj, a.name) && bv.key.type === 'Number' && bv.key.value === 1) cands.push([list[i], list[i + 1], b.name]);
    }
    return false;
  });
  let best = null;
  for (const [fi, fo, op] of cands) {
    const tree = find(fn.body, (n) => n.type === 'If' && n.clauses.length && (() => { const c = unparen(n.clauses[0].cond); return c.type === 'Binary' && isName(unparen(c.left), op) && unparen(c.right).type === 'Number'; })());
    if (!tree.length) continue;
    const inner = new Set();
    for (const t of tree) for (const u of find(t.clauses.map((c) => c.body).concat(t.orelse ? [t.orelse] : []), (n) => tree.includes(n))) inner.add(u);
    const root = tree.find((t) => !inner.has(t));
    if (root && (!best || tree.length > best.size)) best = { size: tree.length, body: [fi, fo, root] };
  }
  return best ? { body: best.body } : null;
}

/** The names the interpreter uses for its stack, instruction, counter, and the rest; and the names the prelude gives library functions. */
export function roles(ast, loc) {
  const { fn, alias } = protoFields(loc.vm);
  const loop = dispatchLoop(fn);
  if (!loop) fail('no dispatch loop was found in the interpreter');
  const [ia, oa] = loop.body.map(asgn);
  const I = ia.name;
  const codeRead = unparen(ia.value);
  if (codeRead.type !== 'Index' || !isName(codeRead.obj) || !isName(codeRead.key)) fail('the instruction fetch is not `I = code[pc]`');
  const OP = oa.name;
  const r = new Map([[I, 'I'], [OP, 'OP'], [codeRead.obj.name, 'CODE'], [codeRead.key.name, 'PC']]);
  const fields = { code: alias.get(codeRead.obj.name) };
  const [P, UP, ENV] = loc.vm.func.params.map((p) => p.name);
  r.set(UP, 'UP'); r.set(ENV, 'ENV');
  // the prologue: `for i = 0, n do if i >= NP then VA[i - NP] = ARGS[i + 1] else S[i] = ARGS[i + 1] end end`
  const pro = fn.body.find((s) => s.type === 'NumFor' && s.body.length === 1 && s.body[0].type === 'If' && s.body[0].orelse);
  if (!pro) fail('the argument prologue was not found');
  const iff = pro.body[0];
  const cond = unparen(iff.clauses[0].cond);
  if (cond.type !== 'Binary' || !isName(cond.right)) fail('the argument prologue does not compare with the parameter count');
  r.set(cond.right.name, 'NP');
  fields.params = alias.get(cond.right.name);
  const tgt = (st) => (st && st.type === 'Assign' && st.targets[0].type === 'Index' && isName(st.targets[0].obj) ? st.targets[0].obj.name : null);
  r.set(tgt(iff.clauses[0].body[0]), 'VA');
  r.set(tgt(iff.orelse[0]), 'S');
  for (const [name, idx] of alias) if (idx !== fields.code && idx !== fields.params) { r.set(name, 'PROTOS'); fields.protos = idx; }
  for (const s of fn.body) {
    if (s.type !== 'Local' || s.ids.length !== 1 || !s.values[0]) continue;
    const v = unparen(s.values[0]); const nm = s.ids[0].name;
    if (v.type === 'Unary' && v.op === '-' && v.arg.type === 'Number' && v.arg.value === 1) r.set(nm, 'TOP');
    else if (v.type === 'Binary' && v.op === '+' && unparen(v.left).type === 'Binary' && r.get(unparen(v.right).name) === undefined && /NP/.test(String(r.get((unparen(v.left).right || {}).name)))) r.set(nm, 'NVA');
    else if (isName(v) && !r.has(v.name) && v.name !== nm) r.set(nm, `@${v.name}`);   // alias of an outer helper, resolved below
  }
  // helpers: names the entry function and the prelude declare
  const helpers = new Map();
  const prelude = ast.body.filter((s) => s.type === 'Local');
  for (const s of prelude) s.ids.forEach((id, i) => {
    const v = s.values[i] && unparen(s.values[i]);
    if (!v) return;
    const t = text([{ type: 'Return', values: [v] }]).replace(/^return /, '');
    const known = { 'unpack or table.unpack': 'UNPACK', 'table.unpack or unpack': 'UNPACK', select: 'SELECT', setmetatable: 'SETMT', tonumber: 'TONUMBER', 'table.insert': 'TINSERT', 'table.concat': 'TCONCAT', 'string.sub': 'SSUB', 'string.char': 'SCHAR', 'string.byte': 'SBYTE', pcall: 'PCALL', getmetatable: 'GETMT', type: 'TYPE' }[t];
    if (known) helpers.set(id.name, known);
  });
  for (const s of loc.entry.func.body) {
    if (s.type === 'LocalFunction') {
      const b = s.func.body;
      // function(...) return {...}, select("#", ...) end
      if (b.length === 1 && b[0].type === 'Return' && b[0].values.length === 2 && b[0].values[0].type === 'Table') helpers.set(s.id.name, 'PACK');
      if (s.id.name === loc.vmName) helpers.set(s.id.name, 'WRAP');
    } else if (s.type === 'Local') {
      s.ids.forEach((id, i) => { const v = s.values[i] && unparen(s.values[i]); if (isName(v) && helpers.has(v.name)) helpers.set(id.name, helpers.get(v.name)); });
    }
  }
  for (const [k, v] of r) if (v.startsWith('@')) { const h = helpers.get(v.slice(1)); if (h) r.set(k, h); else r.delete(k); }
  for (const [k, v] of helpers) if (!r.has(k)) r.set(k, v);
  for (const [g, v] of [['unpack', 'UNPACK'], ['select', 'SELECT'], ['setmetatable', 'SETMT']]) if (!r.has(g)) r.set(g, v);
  return { roles: r, loop, fields };
}

// ---- handlers ---------------------------------------------------------------------------------------------------------------------

/** Each leaf of the dispatch tree with the interval of opcodes that reach it. */
export function leaves(ifNode, opName) {
  const out = [];
  const visit = (stmts, lo, hi) => {
    const s = stmts.length === 1 ? stmts[0] : null;
    if (s && s.type === 'If') {
      const conds = s.clauses.map((c) => unparen(c.cond));
      const isOp = (c) => c.type === 'Binary' && isName(unparen(c.left), opName) && unparen(c.right).type === 'Number' && /^(<=|>|==|<|>=)$/.test(c.op);
      if (isOp(conds[0])) {
        let l = lo; let h = hi;
        for (let i = 0; i < s.clauses.length; i++) {
          const c = conds[i];
          if (!isOp(c)) {
            // the generator writes a handler that is itself an `if` as the rest of the chain: `elseif <its test> then ... else ... end`
            out.push({ lo: l, hi: h, body: [{ type: 'If', clauses: s.clauses.slice(i), orelse: s.orelse }] });
            return;
          }
          const n = unparen(c.right).value;
          const range = c.op === '<=' ? [l, Math.min(h, n)] : c.op === '<' ? [l, Math.min(h, n - 1)] : c.op === '>' ? [Math.max(l, n + 1), h] : c.op === '>=' ? [Math.max(l, n), h] : [n, n];
          visit(s.clauses[i].body, range[0], range[1]);
          // the rest of the interval for the next clause
          if (c.op === '<=') l = Math.max(l, n + 1); else if (c.op === '<') l = Math.max(l, n); else if (c.op === '>') h = Math.min(h, n); else if (c.op === '>=') h = Math.min(h, n - 1);
          else { /* == : the rest is everything else in [l, h] but n; kept as the interval */ }
        }
        if (s.orelse) visit(s.orelse, l, h);
        return;
      }
    }
    out.push({ lo, hi, body: stmts });
  };
  visit([ifNode], -Infinity, Infinity);
  return out;
}

export function handlerFor(leafList, op) {
  const hit = leafList.filter((x) => op >= x.lo && op <= x.hi);
  // `==` clauses leave the else-interval wide: the most specific leaf wins
  hit.sort((a, b) => (a.hi - a.lo) - (b.hi - b.lo));
  return hit[0] || null;
}

/** Split a handler at `PC = PC + 1; I = CODE[PC]` into the slices of the instructions it fuses. */
export function slices(stmts, R) {
  const isStep = (s) => s.type === 'Assign' && s.targets.length === 1 && isName(s.targets[0]) && R.get(s.targets[0].name) === 'PC'
    && (() => {
      let v = unparen(s.values[0]);
      // `PC + 1 + 0`: the generator pads the step
      if (v.type === 'Binary' && v.op === '+' && unparen(v.right).type === 'Number' && unparen(v.right).value === 0) v = unparen(v.left);
      return v.type === 'Binary' && v.op === '+' && isName(unparen(v.left)) && R.get(unparen(v.left).name) === 'PC' && unparen(v.right).type === 'Number' && unparen(v.right).value === 1;
    })();
  const isFetch = (s) => s.type === 'Assign' && s.targets.length === 1 && isName(s.targets[0]) && R.get(s.targets[0].name) === 'I';
  const out = [[]];
  for (let i = 0; i < stmts.length; i++) {
    if (isStep(stmts[i]) && stmts[i + 1] && isFetch(stmts[i + 1])) { out.push([]); i++; continue; }
    out[out.length - 1].push(stmts[i]);
  }
  return out;
}

// ---- filling in an instruction --------------------------------------------------------------------------------------------------

const lit = (v) => (v === undefined || v === null ? { type: 'Nil' } : typeof v === 'boolean' ? { type: v ? 'True' : 'False' }
  : typeof v === 'number' ? { type: 'Number', value: v, raw: String(v) } : { type: 'String', value: String(v) });

const clone = (n) => (Array.isArray(n) ? n.map(clone) : n && typeof n === 'object' ? Object.fromEntries(Object.entries(n).map(([k, v]) => [k, k === 'line' ? v : clone(v)])) : n);

/** The slice with I[k] replaced by the instruction's fields, local constants propagated, number arithmetic folded and role names applied. */
export function fill(stmts, ins, R) {
  const F = { 2: ins.a, 3: ins.b, 4: ins.c };
  const consts = new Map();
  const expr = (e) => {
    if (!e || typeof e !== 'object') return e;
    if (Array.isArray(e)) return e.map(expr);
    if (e.type === 'Func') return e;
    if (e.type === 'Index' && isName(e.obj) && R.get(e.obj.name) === 'I' && e.key.type === 'Number' && e.key.value in F) return lit(F[e.key.value]);
    if (e.type === 'Name' && consts.has(e.name)) return consts.get(e.name);
    const o = {};
    for (const k of Object.keys(e)) o[k] = expr(e[k]);
    if (o.type === 'Name' && R.has(o.name)) return { ...o, name: R.get(o.name) };
    if (o.type === 'Paren' && ['Number', 'String', 'Name', 'Nil', 'True', 'False', 'Index'].includes(o.expr.type)) return o.expr;
    if (o.type === 'Binary' && o.left.type === 'Number' && o.right.type === 'Number' && ['+', '-', '*'].includes(o.op)) {
      const v = o.op === '+' ? o.left.value + o.right.value : o.op === '-' ? o.left.value - o.right.value : o.left.value * o.right.value;
      return lit(v);
    }
    // (x + n) - m and x + n with x a role name: keep as is, numbers on the right
    return o;
  };
  const assigned = new Set(find(stmts, (n) => n.type === 'Assign').flatMap((a) => a.targets.filter((t) => t.type === 'Name').map((t) => t.name)));
  const out = [];
  for (const s0 of stmts) {
    const s = expr(clone(s0));
    // `local t = <literal>` never reassigned: substituted, and the declaration dropped
    if (s.type === 'Local' && s.ids.length === 1 && s.values.length === 1 && ['Number', 'String', 'True', 'False', 'Nil'].includes(s.values[0].type) && !assigned.has(s.ids[0].name)) {
      consts.set(s.ids[0].name, s.values[0]); continue;
    }
    if (s.type === 'Local' && s.values.length === 0 && s.ids.length === 1) continue;   // a bare `local t` declared for a fused handler
    out.push(s);
  }
  return straighten(out);
}

/**
 * Straight-line state machines the generator wraps some handlers in, once the state numbers are known:
 *   `local s = 0 while true do if s == 0 then A s = 1 end if s == 1 then B break end end`  ->  A B
 *   `while true do if 0 == 0 then A break end end`                                          ->  A
 * Only when every state block ends by setting the next state to a constant or by `break`, and the states are visited once each.
 */
export function straighten(stmts) {
  const out = [];
  for (let i = 0; i < stmts.length; i++) {
    const s = stmts[i];
    const loc = s.type === 'Local' && s.ids.length === 1 && s.values.length === 1 && s.values[0].type === 'Number' ? s : null;
    const w = loc ? stmts[i + 1] : s;
    if (!w || w.type !== 'While' || w.cond.type !== 'True') { out.push(s); continue; }
    const state = loc ? loc.ids[0].name : null;
    let cur = loc ? loc.values[0].value : null;
    const blocks = w.body.filter((b) => b.type === 'If');
    if (blocks.length !== w.body.length || !blocks.every((b) => b.clauses.length === 1 && !b.orelse)) { out.push(s); continue; }
    const testOf = (b) => {
      const c = unparen(b.clauses[0].cond);
      if (c.type === 'Binary' && c.op === '==') {
        const [l, r] = [unparen(c.left), unparen(c.right)];
        if (l.type === 'Number' && r.type === 'Number') return l.value === r.value ? 'always' : 'never';
        if (state && isName(l, state) && r.type === 'Number') return r.value;
        if (state && isName(r, state) && l.type === 'Number') return l.value;
      }
      return undefined;
    };
    const seq = []; const seen = new Set(); let ok = true; let done = false;
    for (let guard = 0; guard < 64 && ok && !done; guard++) {
      const b = blocks.find((x) => testOf(x) === 'always' || (cur !== null && testOf(x) === cur));
      if (!b || seen.has(b)) { ok = false; break; }
      seen.add(b);
      const body = b.clauses[0].body.slice();
      const last = body[body.length - 1];
      if (last && last.type === 'Break') { body.pop(); seq.push(...body); done = true; break; }
      const set = last && last.type === 'Assign' && last.targets.length === 1 && state && isName(last.targets[0], state) && last.values[0].type === 'Number' ? last : null;
      if (!set) { ok = false; break; }
      body.pop(); seq.push(...body); cur = set.values[0].value;
    }
    if (!ok || !done) { out.push(s); continue; }
    out.push(...straighten(seq));
    if (loc) i++;
  }
  return out;
}

/** A readable listing of the program: every instruction with its handler slice filled in (for research and the report). */
/**
 * The interpreter as the generator wrote it hides its handlers behind opaque predicates in the dispatch tests (`(OP <= 5) or (2 < 1)`) and
 * flattens some handlers into small state machines. The project's own passes take both apart; the lifter reads the cleaned copy.
 */
export function cleaned(source) {
  const ast = parse(source);
  foldPass(ast, {});
  try { unflattenMoonVeil(ast, { gotoFallback: false }); } catch { /* left as is: the reader says which handler it cannot read */ }
  simplifyPass(ast, {});
  foldPass(ast, {});
  return ast;
}

export function listing(source) {
  const ast = cleaned(source);
  const loc = locate(ast);
  if (!loc) fail('not a LuaObfuscator VM script');
  const { roles: R, loop, fields } = roles(ast, loc);
  const proto = deserialize(source, loc);
  const lv = leaves(loop.body[2], asgn(loop.body[1]).name);
  const lines = [];
  const walk = (p, path) => {
    const code = tget(p, fields.code);
    const protos = tget(p, fields.protos);
    const n = code ? code.arr.length : 0;
    lines.push(`-- function ${path}: ${n} instructions, ${tget(p, fields.params)} parameters`);
    for (let pc = 1; pc <= n; pc++) {
      const I = code.arr[pc - 1];
      const ins = { op: tget(I, 1), a: tget(I, 2), b: tget(I, 3), c: tget(I, 4) };
      const h = handlerFor(lv, ins.op);
      const t = h ? slices(straighten(h.body), R).map((sl, k) => (k === 0 ? text(fill(sl, ins, R)) : null)).filter(Boolean)[0] : '(no handler)';
      lines.push(`${String(pc).padStart(4)} [${ins.op}] ${t}`);
    }
    if (protos) for (const [k, q] of [...protos.hash].concat(protos.arr.map((x, i) => [i + 1, x]))) walk(q, `${path}.${k}`);
  };
  walk(proto, 'main');
  return { lines, roles: Object.fromEntries(R), fields };
}

/**
 * What can be read with certainty without lifting: the program's functions, instruction counts and constants, as the script's own
 * deserialiser produced them (Prompt XXV). The instructions are not rebuilt into source here: across builds the opcode-to-handler mapping is
 * not yet proven for every handler form (about 1% of the forms in a census of 120 builds read an operand the instruction does not have), so
 * a lift could be readable and wrong. The constants are exact.
 */
export function readProgram(source) {
  const ast = parse(source);
  const loc = locate(ast);
  if (!loc) throw new LuaObfVmError('not a LuaObfuscator VM script');
  const { fields } = roles(cleaned(source), locate(cleaned(source)) || loc);
  const proto = deserialize(source, loc);
  const strings = new Map();
  let functions = 0; let instructions = 0;
  const walk = (p, depth) => {
    if (!p || depth > 200) return;
    functions++;
    const code = tget(p, fields.code);
    if (code) for (const I of code.arr) {
      instructions++;
      for (const k of [2, 3, 4]) { const v = tget(I, k); if (typeof v === 'string') strings.set(v, (strings.get(v) || 0) + 1); }
    }
    const protos = tget(p, fields.protos);
    if (protos) for (const q of [...protos.hash.values(), ...protos.arr]) walk(q, depth + 1);
  };
  walk(proto, 0);
  const list = [...strings.keys()];
  return { functions, instructions, strings: list.length, sample: list.filter((x) => /^[\x20-\x7e]{1,200}$/.test(x)).slice(0, 80) };
}
