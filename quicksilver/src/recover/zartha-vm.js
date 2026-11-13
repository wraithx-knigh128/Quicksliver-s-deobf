// Zartha's virtual machine, lifted back to source (https://github.com/TimOdemchuk/Zartha-Obfuscator, MIT).
//
// Zartha compiles the program with luac (Lua 5.1) and writes the bytecode back out as Lua: every function becomes `Stack[A] = function(...) ... end` whose body is
//
//     while true do
//       if pointer == 1 then <the code of instruction 1> elseif pointer == 2 then <instruction 2> ... end
//       pointer = pointer + 1
//     end
//
// with the registers in `Stack`, scratch values in `Temp`, upvalues behind a metatable that forwards to the parent's registers, and the constants of the function in a shuffled table
// (padded with junk entries, every entry encrypted with its own key, numbers/booleans/nil carried by a tag byte). Each instruction is a short piece of Lua written from a template, so
// what is left to read is not data but code, and this reader reads it the way a person would:
//
//   1. each function's dispatch is evaluated for every value of `pointer` (the control-flow-flattening build wraps the leaves in arithmetic predicates and a binary search of
//      them; with `pointer` known they are plain arithmetic and fold away), which leaves the code of instruction p;
//   2. the scratch indirection (`Temp[3] = 7 Stack[Temp[3]] = ...`) is resolved, so the code reads `Stack[7] = ...`;
//   3. the text of that code, with every name replaced by its role, is recognised: `Stack[A] = Stack[B] + Constants[C]` is ADD A B K(C), whatever the build called its variables;
//   4. every instruction becomes the Lua 5.1 instruction of the same meaning (closures carry their upvalue map back as the MOVE / GETUPVAL words that follow them), the constants are
//      decoded with the script's own decryptor and shift, and the chunk goes to the decompiler that already reads IronBrew 2, Obscura and Hercules.
//
// An instruction no template recognises makes the function that uses it fail with its text, rather than be guessed at. Where the generator's template differs from the Lua 5.1
// instruction it was made from (its SETGLOBAL stores the name instead of the value, its LOADBOOL reads a scratch cell it never wrote) the instruction is recovered as the one the
// generator meant, which is what the program was, and the report says the build does not run the way the program did.

import { print } from '../core/printer.js';
import { dumpChunk51 } from '../sandbox/bytecode.js';
import { encode, maxStack } from './ironbrew.js';
import { unparen } from './vmprofile.js';

export class ZarthaVmError extends Error {}
const fail = (m) => { throw new ZarthaVmError(m); };

const clone = (x) => JSON.parse(JSON.stringify(x));
const text = (stmts) => print({ type: 'Chunk', body: stmts, endComments: [], features: new Set() }).replace(/\s*\n\s*/g, ' ').replace(/([(\[{]) /g, '$1').replace(/ ([)\]}])/g, '$1').trim();

const find = (n, f, out = []) => {
  if (!n || typeof n !== 'object') return out;
  if (Array.isArray(n)) { n.forEach((x) => find(x, f, out)); return out; }
  if (f(n)) out.push(n);
  for (const k of Object.keys(n)) if (k !== 'line') find(n[k], f, out);
  return out;
};

// ---- scopes --------------------------------------------------------------------------------------------------------------------

/** The outermost `while true do` that dispatches on a counter, and the local declaration of the machine's registers that comes before it. */
function isDispatchLoop(n) {
  if (!n || n.type !== 'While' || unparen(n.cond).type !== 'True') return false;
  return n.body.some((s) => s.type === 'If' && s.clauses.length >= 1) && n.body.length >= 2;
}

const isEmptyTable = (e) => e && e.type === 'Table' && e.fields.length === 0;
const isNum = (e, v) => e && e.type === 'Number' && (v === undefined || e.value === v);

/** `local Stack, Temp, Upvalues, Constants, ProtosConstants, vmEnv, pointer, top = {}, {}, {}, {}, {}, {}, 1, 0` */
function mainNames(decl) {
  const [S, T, U, K, PK, VE, P, TOP] = decl.ids.map((i) => i.name);
  return { S, T, U, K, PK, VE, P, TOP };
}
/** `local Varargs, Stack, Temp, Upvalues, pointer, top, Map = {}, {}, {}, {}, 1, 0, {}` */
function protoNames(decl) {
  const [VA, S, T, U, P, TOP, MAP] = decl.ids.map((i) => i.name);
  return { VA, S, T, U, P, TOP, MAP };
}
const mainDecl = (s) => s.type === 'Local' && s.ids.length === 8 && s.values.length === 8 && s.values.slice(0, 6).every(isEmptyTable) && isNum(s.values[6], 1) && isNum(s.values[7], 0);
const protoDecl = (s) => s.type === 'Local' && s.ids.length === 7 && s.values.length === 7 && s.values.slice(0, 4).every(isEmptyTable) && isNum(s.values[4], 1) && isNum(s.values[5], 0) && s.values[6].type === 'Table';

// ---- evaluation of the dispatch ----------------------------------------------------------------------------------------------

/** The value of an expression made of numbers and the counter only, or undefined. */
function evalExpr(e, P, p) {
  if (!e) return undefined;
  switch (e.type) {
    case 'Number': return e.value;
    case 'True': return true;
    case 'False': return false;
    case 'Name': return e.name === P ? p : undefined;
    case 'Paren': return evalExpr(e.expr, P, p);
    case 'Unary': {
      const a = evalExpr(e.arg, P, p);
      if (a === undefined) return undefined;
      if (e.op === '-' && typeof a === 'number') return -a;
      if (e.op === 'not') return !a;
      return undefined;
    }
    case 'Binary': {
      const a = evalExpr(e.left, P, p);
      if (e.op === 'and') { if (a === undefined) return undefined; if (a === false) return false; return evalExpr(e.right, P, p); }
      if (e.op === 'or') { if (a === undefined) return undefined; if (a !== false) return a; return evalExpr(e.right, P, p); }
      const b = evalExpr(e.right, P, p);
      if (a === undefined || b === undefined || typeof a !== 'number' || typeof b !== 'number') return undefined;
      switch (e.op) {
        case '+': return a + b; case '-': return a - b; case '*': return a * b; case '/': return a / b; case '%': return a - Math.floor(a / b) * b; case '^': return a ** b;
        case '==': return a === b; case '~=': return a !== b; case '<': return a < b; case '<=': return a <= b; case '>': return a > b; case '>=': return a >= b;
        default: return undefined;
      }
    }
    default: return undefined;
  }
}

/** What runs when `pointer` is p: tests that depend on nothing but p are decided, the rest of the code is kept. */
function partial(stmts, P, p) {
  const out = [];
  for (const s of stmts) {
    if (s.type === 'Do') { out.push(...partial(s.body, P, p)); continue; }
    if (s.type !== 'If') { out.push(s); continue; }
    const kept = [];
    let orelse = s.orelse ? () => partial(s.orelse, P, p) : null;
    for (const c of s.clauses) {
      const v = evalExpr(c.cond, P, p);
      if (v === undefined) { kept.push({ cond: c.cond, body: partial(c.body, P, p) }); continue; }
      if (v === false || v === null) continue;
      orelse = () => partial(c.body, P, p);                // taken: nothing after it can run
      break;
    }
    if (!kept.length) { if (orelse) out.push(...orelse()); continue; }
    out.push({ ...s, clauses: kept, orelse: orelse ? orelse() : null });
  }
  return out;
}


function headerNames(ast) {
  const head = find(ast, (n) => n.type === 'Local' && n.ids.length >= 20 && n.values.length >= 20)[0];
  if (!head) fail('the header that names the standard library was not found');
  return { unpack: head.ids[5].name, head };
}
// ---- names -------------------------------------------------------------------------------------------------------------------

/** Names introduced inside a leaf (loop variables, locals) are given numbered names of their own so that no role can be mistaken for them. */
function alphaRename(stmts) {
  let n = 0;
  const fresh = () => `$${++n}`;
  const expr = (e, sc) => {
    if (!e || typeof e !== 'object') return e;
    if (Array.isArray(e)) return e.map((x) => expr(x, sc));
    if (e.type === 'Func') return e;
    if (e.type === 'Name') return sc.has(e.name) ? { ...e, name: sc.get(e.name) } : e;
    const o = {};
    for (const k of Object.keys(e)) if (k !== 'comments') o[k] = expr(e[k], sc);
    return o;
  };
  const block = (list, sc0) => { const sc = new Map(sc0); return list.map((s) => stmt(s, sc)); };
  const stmt = (s, sc) => {
    switch (s.type) {
      case 'Local': {
        const values = s.values.map((v) => expr(v, sc));
        const ids = s.ids.map((id) => { const nn = fresh(); sc.set(id.name, nn); return { ...id, name: nn }; });
        const o = { ...s, ids, values }; delete o.comments; return o;
      }
      case 'NumFor': {
        const inner = new Map(sc); const nn = fresh(); const start = expr(s.start, sc); const stop = expr(s.stop, sc); const step = expr(s.step, sc);
        inner.set(s.id.name, nn);
        const o = { ...s, id: { ...s.id, name: nn }, start, stop, step, body: block(s.body, inner) }; delete o.comments; return o;
      }
      case 'GenFor': {
        const exprs = s.exprs.map((x) => expr(x, sc)); const inner = new Map(sc);
        const ids = s.ids.map((id) => { const nn = fresh(); inner.set(id.name, nn); return { ...id, name: nn }; });
        const o = { ...s, ids, exprs, body: block(s.body, inner) }; delete o.comments; return o;
      }
      case 'If': { const o = { ...s, clauses: s.clauses.map((c) => ({ cond: expr(c.cond, sc), body: block(c.body, sc) })), orelse: s.orelse ? block(s.orelse, sc) : s.orelse }; delete o.comments; return o; }
      case 'While': { const o = { ...s, cond: expr(s.cond, sc), body: block(s.body, sc) }; delete o.comments; return o; }
      case 'Do': { const o = { ...s, body: block(s.body, sc) }; delete o.comments; return o; }
      default: return expr(s, sc);
    }
  };
  return block(stmts, new Map());
}

/** Machine names (`Stack`, `Temp`, whatever the build called them) replaced by their roles. Functions are left as they are: they are other machines. */
function applyRoles(node, roles) {
  if (!node || typeof node !== 'object') return node;
  if (Array.isArray(node)) return node.map((x) => applyRoles(x, roles));
  if (node.type === 'Func') return node;
  if (node.type === 'Name') { const r = roles.get(node.name); return r ? { ...node, name: r } : node; }
  const o = {};
  for (const k of Object.keys(node)) o[k] = applyRoles(node[k], roles);
  return o;
}

const isTempCell = (t, k) => t && t.type === 'Index' && t.obj.type === 'Name' && t.obj.name === 'T' && t.key.type === 'Number' && (k === undefined || t.key.value === k);

const bindable = (v) => v.type === 'Number'
  || (v.type === 'Name' && (v.name === 'K' || v.name === 'VE'))
  || (v.type === 'Index' && v.obj.type === 'Name' && v.obj.name === 'K' && v.key.type === 'Number')
  || (v.type === 'Binary' && (v.op === '==' || v.op === '~=') && unparen(v.left).type === 'Name' && unparen(v.right).type === 'Name')
  || (v.type === 'Paren' && bindable(v.expr));

/** The scratch cells that hold a number or a name of the machine are replaced by what they hold. Returns the statements left and the values that nothing read. */
function resolveSlice(stmts) {
  const bound = new Map();
  const used = new Set();
  const subst = (e) => {
    if (!e || typeof e !== 'object') return e;
    if (Array.isArray(e)) return e.map(subst);
    if (e.type === 'Func') return e;
    const o = {};
    for (const k of Object.keys(e)) o[k] = subst(e[k]);
    if (isTempCell(o) && bound.has(o.key.value)) { used.add(o.key.value); return bound.get(o.key.value); }
    return o;
  };
  const assignedLater = (i, k) => stmts.slice(i + 1).some((s) => find(s, (n) => n.type === 'Assign' && n.targets.some((t) => isTempCell(t, k))).length);
  const out = [];
  let leading = true;
  stmts.forEach((s, i) => {
    let t;
    if (s.type === 'Assign' && s.targets.length === 1 && isTempCell(s.targets[0])) t = { ...s, targets: [s.targets[0]], values: subst(s.values) };
    else t = subst(s);
    if (leading && t.type === 'Assign' && t.values.length === 1 && isTempCell(t.targets[0]) && bindable(t.values[0]) && !assignedLater(i, t.targets[0].key.value)) {
      bound.set(t.targets[0].key.value, t.values[0]);
      return;
    }
    leading = false;
    out.push(t);
  });
  const dead = [];
  for (const [k, v] of bound) if (!used.has(k)) dead.push(v);
  return { stmts: out, dead };
}

/** Canonical text: locals numbered by first appearance. */
function canon(stmts) {
  const seen = new Map();
  return text(stmts).replace(/\$\d+/g, (m) => { if (!seen.has(m)) seen.set(m, `v${seen.size + 1}`); return seen.get(m); });
}

// ---- the instructions --------------------------------------------------------------------------------------------------------

const ins = (op, a = 0, b = 0, c = 0) => ({ op, a, b, c });
const RKX = '([KS])\\[(\\d+)\\]';
const NUM = '(\\d+)';
const rk = (kind, n) => (kind === 'K' ? 256 + (+n - 1) : +n);
const regsOf = (t) => [...t.matchAll(/S\[(\d+)\]/g)].map((m) => +m[1]);
const consecutive = (xs, from) => xs.every((x, i) => x === from + i);
const argsText = (a, n) => Array.from({ length: n }, (_, i) => `S[${a + 1 + i}]`).join(', ');
const ARITH = { '+': 'Add', '-': 'Sub', '*': 'Mul', '/': 'Div', '%': 'Mod', '^': 'Pow' };

const callTail = (a, c, v) => (c < 1
  ? ` T[3] = #T[2] if T[3] == 0 then S[${a}] = nil TOP = ${a} else TOP = ${a} + T[3] - 1 for ${v} = 1, T[3] do S[${a} + ${v} - 1] = T[2][${v}] end end`
  : ` for ${v} = 1, ${c - 1} do S[${a} + ${v} - 1] = T[2][${v}] end`);

/** The instruction one slice of leaf code is, or null. `dead` are the scratch values nothing read; `marker` says the leaf ends in the step that skips the next word. */
function recognise(t, dead, tail) {
  let m;
  const simple = [
    [/^S\[(\d+)\] = S\[(\d+)\]$/, (x) => ins('Move', +x[1], +x[2])],
    [/^S\[(\d+)\] = K\[(\d+)\]$/, (x) => ins('LoadConst', +x[1], +x[2] - 1)],
    [/^S\[(\d+)\] = U\[(\d+)\]$/, (x) => ins('GetUpval', +x[1], +x[2])],
    [/^U\[(\d+)\] = S\[(\d+)\]$/, (x) => ins('SetUpval', +x[2], +x[1])],
    [/^S\[(\d+)\] = \{\}$/, (x) => ins('NewTable', +x[1])],
    [/^S\[(\d+)\] = #S\[(\d+)\]$/, (x) => ins('Len', +x[1], +x[2])],
    [/^S\[(\d+)\] = not S\[(\d+)\]$/, (x) => ins('Not', +x[1], +x[2])],
    [/^S\[(\d+)\] = -S\[(\d+)\]$/, (x) => ins('Unm', +x[1], +x[2])],
    [new RegExp(`^S\\[${NUM}\\] = ${RKX} ([-+*/%^]) ${RKX}$`), (x) => ins(ARITH[x[4]], +x[1], rk(x[2], x[3]), rk(x[5], x[6]))],
    [/^S\[(\d+)\] = VE\[K\[(\d+)\]\] or ENV\[K\[(\d+)\]\]$/, (x) => (x[2] === x[3] ? ins('GetGlobal', +x[1], +x[2] - 1) : null)],
    [new RegExp(`^S\\[${NUM}\\] = S\\[${NUM}\\]\\[${RKX}\\]$`), (x) => ins('GetTable', +x[1], +x[2], rk(x[3], x[4]))],
    [new RegExp(`^S\\[${NUM}\\]\\[${RKX}\\] = ${RKX}$`), (x) => ins('SetTable', +x[1], rk(x[2], x[3]), rk(x[4], x[5]))],
    [new RegExp(`^S\\[${NUM}\\] = S\\[${NUM}\\] if S\\[${NUM}\\] then S\\[${NUM}\\] = S\\[${NUM}\\]\\[${RKX}\\] end$`), (x) => (+x[1] === +x[4] + 1 && x[2] === x[5] && x[1] === x[3] ? ins('Self', +x[4], +x[2], rk(x[6], x[7])) : null)],
    [new RegExp('^T\\[1\\] = "" for (v1) = ' + NUM + ', ' + NUM + ' do T\\[1\\] = T\\[1\\] \\.\\. S\\[v1\\] end S\\[' + NUM + '\\] = T\\[1\\]$'), (x) => ins('Concat', +x[4], +x[2], +x[3])],
    [/^P = P \+ (-?\d+)$/, (x) => ins('Jmp', 0, +x[1])],
    [new RegExp(`^if ${RKX} (==|~=|<|>|<=|>=) ${RKX} then P = P \\+ 1 end$`), (x) => {
      const o = { '==': ['Eq', 0], '~=': ['Eq', 1], '<': ['Lt', 0], '>': ['Lt', 1], '<=': ['Le', 0], '>=': ['Le', 1] }[x[3]];
      return ins(o[0], o[1], rk(x[1], x[2]), rk(x[4], x[5]));
    }],
    [/^if (not )?S\[(\d+)\] then P = P \+ 1 end$/, (x) => ins('Test', +x[2], 0, x[1] ? 1 : 0)],
    [/^if \(?(not )?S\[(\d+)\]\)? then P = P \+ 1 else S\[(\d+)\] = S\[\2\] end$/, (x) => ins('TestSet', +x[3], +x[2], x[1] ? 1 : 0)],
    [/^S\[(\d+)\] = S\[\1\] - S\[(\d+)\] P = P \+ (-?\d+)$/, (x) => (+x[2] === +x[1] + 2 ? ins('ForPrep', +x[1], +x[3]) : null)],
    [/^S\[(\d+)\] = S\[\1\] \+ S\[(\d+)\] if \(S\[\2\] > 0 and S\[\1\] <= S\[(\d+)\]\) or \(S\[\2\] <= 0 and S\[\1\] >= S\[\3\]\) then P = P \+ (-?\d+) S\[(\d+)\] = S\[\1\] end$/, (x) => (+x[2] === +x[1] + 2 && +x[3] === +x[1] + 1 && +x[5] === +x[1] + 3 ? ins('ForLoop', +x[1], +x[4]) : null)],
    [/^for v1 = (\d+), #S do S\[v1\] = nil end$/, (x) => ins('Close', +x[1])],
  ];
  for (const [re, build] of simple) { m = re.exec(t); if (m) { const r = build(m); if (r) return r; } }

  // booleans: the generator stores a scratch cell it never wrote; the value is the test that was written next to it
  if ((m = /^S\[(\d+)\] = T\[\d+\]$/.exec(t))) {
    const d = dead.find((x) => unparen(x).type === 'Binary');
    if (d) return ins('LoadBool', +m[1], unparen(d).op === '~=' ? 1 : 0, 0);
  }
  // the value of a global that is set is not stored either; the register is the one number nothing read
  if ((m = /^VE\[K\[(\d+)\]\] = K\[\1\]$/.exec(t))) {
    const d = dead.filter((x) => unparen(x).type === 'Number');
    if (d.length === 1) return ins('SetGlobal', unparen(d[0]).value, +m[1] - 1);
  }
  // LOADNIL
  if (/^S\[\d+\](, S\[\d+\])* = nil$/.test(t)) {
    const rs = regsOf(t);
    if (rs.length === 1) return ins('LoadNil', rs[0], rs[0]);
    if (consecutive(rs, rs[0])) { const k = rs.length - 1; return ins('LoadNil', rs[0], Math.max(rs[0], k)); }
  }
  // CALL
  if (/^T\[1\] = \{\} for v1 = (\d+) \+ 1, TOP do/.test(t) || /S\[\d+\]\(/.test(t)) {
    const open = /^T\[1\] = \{\} for v1 = (\d+) \+ 1, TOP do T\[1\]\[v1 - \1\] = S\[v1\] end /.exec(t);
    const callA = open ? +open[1] : (/S\[(\d+)\]\(/.exec(t) || [])[1];
    if (callA !== undefined) {
      const a = +callA;
      const want = [];
      if (open) {
        const base = `T[1] = {} for v1 = ${a} + 1, TOP do T[1][v1 - ${a}] = S[v1] end T[2] = {S[${a}](unpack(T[1], 1, TOP - ${a}))}`;
        for (let c = 0; c < 40; c++) want.push([base + callTail(a, c, 'v2'), ins('Call', a, 0, c)]);
        want.push([`T[1] = {} for v1 = ${a} + 1, TOP do T[1][v1 - ${a}] = S[v1] end return S[${a}](unpack(T[1], 1, TOP - ${a}))`, ins('TailCall', a, 0, 0)]);
      } else {
        const argl = new RegExp(`S\\[${a}\\]\\(((?:S\\[\\d+\\](?:, )?)*)\\)`).exec(t);
        if (argl) {
          const n = argl[1] ? argl[1].split(', ').length : 0;
          const args = argsText(a, n);
          const call = `S[${a}](${args})`;
          want.push([call, ins('Call', a, n + 1, 1)]);
          want.push([`S[${a}] = ${call}`, ins('Call', a, n + 1, 2)]);
          for (let c = 3; c < 40; c++) want.push([`${Array.from({ length: c - 1 }, (_, i) => `S[${a + i}]`).join(', ')} = ${call}`, ins('Call', a, n + 1, c)]);
          want.push([`T[2] = {${call}}` + callTail(a, 0, 'v1'), ins('Call', a, n + 1, 0)]);
          want.push([`return ${call}`, ins('TailCall', a, n + 1, 0)]);
        }
      }
      const hit = want.find(([s]) => s === t);
      if (hit) return hit[1];
    }
  }
  // the macro the anti-tamper template calls: the call of a global that jumps the counter out of the program
  if (/^P = P \+ 40 ?\^ ?10$/.test(t)) return ins('Crash');
  // RETURN
  if (t === 'return') return ins('Return', 0, 1);
  if ((m = /^return S\[(\d+)\]((?:, S\[\d+\])*)$/.exec(t))) {
    const rs = regsOf(t);
    if (consecutive(rs, rs[0])) return ins('Return', rs[0], rs.length + 1);
  }
  if ((m = /^T\[1\] = \{\} T\[2\] = 0 for v1 = (\d+), TOP do T\[2\] = T\[2\] \+ 1 T\[1\]\[T\[2\]\] = S\[v1\] end return unpack\(T\[1\], 1, T\[2\]\)$/.exec(t))) return ins('Return', +m[1], 0);
  // SETLIST
  if ((m = /^for v1 = 1, (\d+) do S\[(\d+)\]\[\((\d+) - 1\) \* 50 \+ v1\] = S\[\2 \+ v1\] end$/.exec(t))) return ins('SetList', +m[2], +m[1], +m[3]);
  if ((m = /^local v1 = TOP - (\d+) for v2 = 1, v1 do S\[\1\]\[\((\d+) - 1\) \* 50 \+ v2\] = S\[\1 \+ v2\] end$/.exec(t))) return ins('SetList', +m[1], 0, +m[2]);
  // VARARG
  if ((m = /^for v1 = 1, (\d+) do S\[(\d+) \+ v1 - 1\] = VA\[v1\] end$/.exec(t))) return ins('VarArg', +m[2], +m[1] + 1);
  if ((m = /^TOP = (\d+) \+ #VA - 1 for v1 = 1, #VA do S\[\1 \+ v1 - 1\] = VA\[v1\] end$/.exec(t))) return ins('VarArg', +m[1], 0);
  // TFORLOOP
  if ((m = /^local ((?:v\d+(?:, )?)+) = S\[(\d+)\]\(S\[(\d+)\], S\[(\d+)\]\)((?: S\[\d+\] = v\d+)*) if S\[(\d+)\] ~= nil then S\[(\d+)\] = S\[\6\] else P = P \+ 1 end$/.exec(t))) {
    const a = +m[2]; const c = m[1].split(', ').length;
    const exp = `local ${Array.from({ length: c }, (_, i) => `v${i + 1}`).join(', ')} = S[${a}](S[${a + 1}], S[${a + 2}])${Array.from({ length: c }, (_, i) => ` S[${a + 3 + i}] = v${i + 1}`).join('')} if S[${a + 3}] ~= nil then S[${a + 2}] = S[${a + 3}] else P = P + 1 end`;
    if (exp === t) return ins('TForLoop', a, 0, c);
  }
  return null;
}

function analyseLeaf(stmts) {
  const rolesDone = stmts;
  const try1 = (list) => {
    const { stmts: s, dead } = resolveSlice(list);
    return { ins: recognise(canon(s), dead), text: canon(s) };
  };
  const whole = try1(rolesDone);
  if (whole.ins) return { ops: [whole.ins], text: whole.text };
  // LOADBOOL that skips the next word, or two instructions the generator merged: the leaf ends with the step over the second
  const last = rolesDone[rolesDone.length - 1];
  const isStep = (s) => s && s.type === 'Assign' && canon([s]) === 'P = P + 1';
  if (isStep(last)) {
    const body = rolesDone.slice(0, -1);
    const lb = try1(body);
    if (lb.ins && lb.ins.op === 'LoadBool') { lb.ins.c = 1; return { ops: [lb.ins], text: lb.text }; }
    for (let j = 1; j < body.length; j++) {
      const a = try1(body.slice(0, j));
      if (!a.ins || !['LoadConst', 'GetGlobal', 'GetTable'].includes(a.ins.op)) continue;
      const b = try1(body.slice(j));
      if (b.ins && ['Call', 'GetTable'].includes(b.ins.op)) return { ops: [a.ins, b.ins], text: `${a.text} ; ${b.text}` };
    }
  }
  return { ops: null, text: whole.text };
}

// ---- constants ---------------------------------------------------------------------------------------------------------------

const xorWith = (str, key) => {
  let out = '';
  for (let i = 0; i < str.length; i++) out += String.fromCharCode((str.charCodeAt(i) ^ key.charCodeAt(i % key.length)) & 255);
  return out;
};

/** `return char(byte(bb) + 9)`: the shift every byte but the tag bytes had taken off. */
function readShift(ast) {
  const r = find(ast, (n) => n.type === 'Return' && n.values.length === 1 && n.values[0].type === 'Call' && n.values[0].args.length === 1
    && n.values[0].args[0].type === 'Binary' && n.values[0].args[0].op === '+' && n.values[0].args[0].right.type === 'Number' && n.values[0].args[0].left.type === 'Call')[0];
  if (!r) fail('the shift the constants were hidden with was not found');
  return r.values[0].args[0].right.value;
}

const TAGS = new Set([11, 4, 7, 6]);

/** What one entry of the constants table holds: the decryptor's text with its key, then the shift and the tag byte the machine itself undoes. */
function decodeEntry(expr, shift) {
  const e = unparen(expr);
  let raw;
  if (e.type === 'String') raw = e.value;
  else if (e.type === 'Call' && e.args.length === 2 && e.args.every((a) => unparen(a).type === 'String')) raw = xorWith(unparen(e.args[0]).value, unparen(e.args[1]).value);
  else fail(`a constant is neither a string nor a decrypted string (${text([{ type: 'Return', values: [e] }]).slice(0, 60)})`);
  let v = '';
  for (let i = 0; i < raw.length; i++) { const b = raw.charCodeAt(i); v += TAGS.has(b) ? raw[i] : String.fromCharCode((b + shift) & 255); }
  const last = v.length ? v.charCodeAt(v.length - 1) : null;
  if (last === 11) { const n = Number(v.slice(0, -1)); if (Number.isNaN(n)) fail('a numeric constant did not read as a number'); return n; }
  if (last === 4) return v.slice(0, -1);
  if (last === 7) return v.charCodeAt(0) === 116;
  if (last === 6) return undefined;
  return v;
}

const decodeTable = (table, shift) => table.fields.map((f) => decodeEntry(f.value, shift));

const findShallow = (n, f, out = []) => {
  if (!n || typeof n !== 'object') return out;
  if (Array.isArray(n)) { n.forEach((x) => findShallow(x, f, out)); return out; }
  if (n.type === 'Func') return out;
  if (f(n)) out.push(n);
  for (const k of Object.keys(n)) if (k !== 'comments') findShallow(n[k], f, out);
  return out;
};

// ---- functions ----------------------------------------------------------------------------------------------------------------

const READS = {
  Move: (i) => [i.b], Len: (i) => [i.b], Not: (i) => [i.b], Unm: (i) => [i.b], SetGlobal: (i) => [i.a], SetUpval: (i) => [i.a], Test: (i) => [i.a], TestSet: (i) => [i.b],
  GetTable: (i) => [i.b, ...(i.c < 256 ? [i.c] : [])], SetTable: (i) => [i.a, ...(i.b < 256 ? [i.b] : []), ...(i.c < 256 ? [i.c] : [])],
  Self: (i) => [i.b, ...(i.c < 256 ? [i.c] : [])], Concat: (i) => Array.from({ length: i.c - i.b + 1 }, (_, k) => i.b + k),
  Call: (i) => Array.from({ length: Math.max(1, i.b) }, (_, k) => i.a + k), TailCall: (i) => Array.from({ length: Math.max(1, i.b) }, (_, k) => i.a + k),
  Return: (i) => (i.b >= 2 ? Array.from({ length: i.b - 1 }, (_, k) => i.a + k) : i.b === 0 ? [i.a] : []),
  ForPrep: (i) => [i.a, i.a + 1, i.a + 2], ForLoop: (i) => [i.a, i.a + 1, i.a + 2], TForLoop: (i) => [i.a, i.a + 1, i.a + 2],
  SetList: (i) => [i.a, ...Array.from({ length: i.b }, (_, k) => i.a + 1 + k)],
  Eq: (i) => [...(i.b < 256 ? [i.b] : []), ...(i.c < 256 ? [i.c] : [])], Lt: (i) => [...(i.b < 256 ? [i.b] : []), ...(i.c < 256 ? [i.c] : [])], Le: (i) => [...(i.b < 256 ? [i.b] : []), ...(i.c < 256 ? [i.c] : [])],
};
for (const o of Object.values(ARITH)) READS[o] = (i) => [...(i.b < 256 ? [i.b] : []), ...(i.c < 256 ? [i.c] : [])];
const WRITES = {
  LoadNil: (i) => Array.from({ length: i.b - i.a + 1 }, (_, k) => i.a + k), Call: (i) => (i.c >= 2 ? Array.from({ length: i.c - 1 }, (_, k) => i.a + k) : [i.a]),
  TForLoop: (i) => Array.from({ length: i.c }, (_, k) => i.a + 3 + k), ForPrep: (i) => [i.a, i.a + 1, i.a + 2, i.a + 3], ForLoop: (i) => [i.a, i.a + 1, i.a + 2, i.a + 3],
  Self: (i) => [i.a, i.a + 1], VarArg: (i) => (i.b >= 2 ? Array.from({ length: i.b - 1 }, (_, k) => i.a + k) : [i.a]),
};
const NO_WRITE = new Set(['SetGlobal', 'SetUpval', 'SetTable', 'Jmp', 'Eq', 'Lt', 'Le', 'Test', 'Return', 'TailCall', 'SetList', 'Close']);

/** The function takes whatever it is passed, so how many parameters it has is read from what the code does: the registers it reads before anything writes them. */
function inferParams(code) {
  const written = new Set();
  code.forEach((i) => { if (i.op === 'TForLoop') for (let k = 0; k < i.c; k++) written.add(i.a + 3 + k); if (i.op === 'ForLoop' || i.op === 'ForPrep') written.add(i.a + 3); });
  let n = 0;
  for (const i of code) {
    for (const r of (READS[i.op] ? READS[i.op](i) : [])) if (!written.has(r)) n = Math.max(n, r + 1);
    if (i.pseudo || NO_WRITE.has(i.op)) continue;
    for (const r of (WRITES[i.op] ? WRITES[i.op](i) : [i.a])) written.add(r);
  }
  return n;
}

const rolesOf = (inherited, own) => { const r = new Map(inherited); for (const [k, v] of Object.entries(own)) if (k && v) r.set(v, k); return r; };

function mapOf(table) {
  const out = [];
  for (const f of table.fields) {
    const v = f.value && unparen(f.value);
    if (f.kind !== 'keyed' || unparen(f.key).type !== 'Number' || !v || v.type !== 'Table' || v.fields.length !== 2) fail('an upvalue map is not in the shape this reader knows');
    out[unparen(f.key).value] = { type: unparen(v.fields[0].value).value, idx: unparen(v.fields[1].value).value };
  }
  for (let i = 0; i < out.length; i++) if (!out[i]) fail('an upvalue map has a gap');
  return out;
}

function liftBody({ loop, names, roles, constants, map, shift, label, acc }) {
  const body = loop.body.slice(0, -1);
  const tail = loop.body[loop.body.length - 1];
  if (!(tail.type === 'Assign' && tail.targets[0].type === 'Name' && tail.targets[0].name === names.P)) fail(`${label}: the loop does not end with the counter being advanced`);
  const leaves = [];
  for (let p = 1, empty = 0; p < 100000 && empty < 400; p++) {
    const raw = partial(body, names.P, p);
    if (!raw.length) { empty++; continue; }
    empty = 0;
    leaves.push({ p, raw });
  }
  if (!leaves.length) fail(`${label}: no instruction was found`);
  const byP = new Map(leaves.map((l) => [l.p, l]));
  const maxP = leaves[leaves.length - 1].p;
  const code = []; const protos = [];
  for (let p = 1; p <= maxP;) {
    const leaf = byP.get(p);
    if (!leaf) {
      // the generator turns `_CRASH()` into one instruction and blanks the load of the global that came before it
      const next = byP.get(p + 1);
      if (next && canon(alphaRename(next.raw).map((x) => applyRoles(x, roles))) === 'P = P + 40 ^ 10') { code.push({ ...ins('GetGlobal'), crash: true }); p++; continue; }
      fail(`${label}: nothing is written for instruction ${p} (written: ${leaves.slice(0, 12).map((l) => l.p).join(' ')})`);
    }
    const closure = leaf.raw.find((s) => s.type === 'Assign' && s.values.length === 1 && s.values[0].type === 'Func');
    if (closure) {
      const target = closure.targets[0];
      if (!(target.type === 'Index' && target.obj.type === 'Name' && target.obj.name === names.S && target.key.type === 'Number')) fail(`${label}: closure ${p} is not stored in a register`);
      const fnNode = closure.values[0];
      const decl = fnNode.body.find(protoDecl);
      if (!decl) fail(`${label}: the prototype made at instruction ${p} does not start the way a prototype does`);
      const pn = protoNames(decl);
      const kLocal = fnNode.body.find((s) => s.type === 'Local' && s.ids.length === 1 && s.values.length === 1 && s.values[0].type === 'Name' && s.values[0] !== undefined && s.ids[0].name !== undefined && !protoDecl(s));
      const enc = findShallow(leaf.raw, (n) => n.type === 'Local' && n.ids.length === 1 && n.values.length === 1 && n.values[0].type === 'Table')[0];
      if (!enc || !kLocal) fail(`${label}: the constants of the prototype made at instruction ${p} were not found`);
      const childLoop = fnNode.body.find(isDispatchLoop);
      if (!childLoop) fail(`${label}: the prototype made at instruction ${p} has no dispatch loop`);
      const inherited = [...roles].filter(([, r]) => r === 'ENV' || r === 'VE' || r === 'unpack');
      const childRoles = rolesOf(inherited, { S: pn.S, T: pn.T, U: pn.U, P: pn.P, TOP: pn.TOP, VA: pn.VA, K: kLocal.ids[0].name });
      const child = liftBody({ loop: childLoop, names: { P: pn.P, S: pn.S }, roles: childRoles, constants: decodeTable(enc.values[0], shift), map: mapOf(decl.values[6]), shift, label: `${label} > closure ${p}`, acc });
      protos.push(child.fn);
      code.push(ins('Closure', target.key.value, protos.length - 1));
      p++;
      for (const link of child.map) {
        if (byP.has(p)) fail(`${label}: instruction ${p} follows a closure but is not one of its upvalue links`);
        code.push({ ...(link.type === 0 ? ins('Move', 0, link.idx) : ins('GetUpval', 0, link.idx)), pseudo: true });
        p++;
      }
      continue;
    }
    const r = analyseLeaf(alphaRename(leaf.raw).map((s) => applyRoles(s, roles)));
    if (!r.ops) fail(`${label}: instruction ${p} is not one this reader recognises: ${r.text.slice(0, 160)}`);
    for (const o of r.ops) { code.push(o); p++; }
  }
  const last = code[code.length - 1];
  if (!last || last.op !== 'Return') code.push(ins('Return', 0, 1));
  constants = constants.slice();
  if (code.some((i) => i.op === 'Crash')) {
    const free = maxStack(code.filter((i) => i.op !== 'Crash' && !i.crash));
    constants.push('_CRASH');
    code.forEach((i, k) => {
      if (i.crash) { i.a = free; i.b = constants.length - 1; }
      if (i.op === 'Crash') { i.op = 'Call'; i.a = free; i.b = 1; i.c = 1; }
    });
  }
  const takesOpen = (i) => i && ((i.op === 'Call' || i.op === 'TailCall' || i.op === 'Return' || i.op === 'SetList') && i.b === 0);
  code.forEach((i, k) => { if (i.op === 'Call' && i.c === 0 && !takesOpen(code[k + 1])) i.c = 1; });
  // masked strings: a name a global or a method is called by is an identifier in any program that was written; a string with control characters in it is not text
  const maskedAt = new Set();
  constants.forEach((c, k) => { if (typeof c === 'string' && /[\x00-\x08\x0e-\x1f\x7f]/.test(c)) maskedAt.add(k); });
  for (const i of code) {
    const k = i.op === 'GetGlobal' || i.op === 'SetGlobal' ? i.b : i.op === 'Self' && i.c >= 256 ? i.c - 256 : -1;
    if (k >= 0 && typeof constants[k] === 'string' && !/^[A-Za-z_][A-Za-z0-9_]*$/.test(constants[k])) maskedAt.add(k);
  }
  acc.masked += maskedAt.size;
  for (const i of code) {
    for (const f of ['b', 'c']) if (i.op !== 'Jmp' && i.op !== 'ForLoop' && i.op !== 'ForPrep' && i[f] >= 256 && !['Call', 'TailCall', 'Return', 'VarArg', 'SetList', 'TForLoop', 'Closure', 'LoadBool'].includes(i.op)) {
      if (i[f] - 256 >= constants.length) fail(`${label}: constant ${i[f] - 255} does not exist`);
    }
  }
  if (globalThis.__zdump) globalThis.__zdump.push({ label, code, constants });
  const fn = {
    source: null, line: 0, lastLine: 0, nups: map ? map.length : 0, numParams: map ? inferParams(code) : 0, isVararg: !map || code.some((i) => i.op === 'VarArg'),
    maxStack: maxStack(code), code: Uint32Array.from(code.map(encode)), k: constants, protos, lines: [], locals: [], upNames: [],
  };
  return { fn, map: map || [], instructions: code.length };
}

/**
 * @param {object} ast the parsed script
 * @returns {{bytes: string, stats: object}} a Lua 5.1 binary chunk for the decompiler
 */
export function liftZarthaVm(ast) {
  const header = headerNames(ast);
  const decl = find(ast, mainDecl)[0];
  if (!decl) fail('the declaration of the machine registers was not found');
  const names = mainNames(decl);
  const loops = find(ast, isDispatchLoop);
  const contained = new Set();
  for (const l of loops) for (const m of find(l.body, isDispatchLoop)) contained.add(m);
  const outer = loops.find((l) => !contained.has(l));
  if (!outer) fail('no dispatch loop was found');
  const shift = readShift(ast);
  const table = header.head.values[13];
  if (!table || table.type !== 'Table') fail('the encrypted constants of the program were not found');
  const envFn = find(ast, (n) => n.type === 'Func' && n.body.includes(header.head))[0];
  const roles = rolesOf([], { unpack: header.unpack, ENV: envFn && envFn.params[0] && (envFn.params[0].name || envFn.params[0]), VE: names.VE, S: names.S, T: names.T, U: names.U, P: names.P, TOP: names.TOP, K: names.K });
  const acc = { masked: 0 };
  const r = liftBody({ loop: outer, names, roles, constants: decodeTable(table, shift), map: null, shift, label: 'the program', acc });
  r.fn.isVararg = true;
  const bin = dumpChunk51({ main: r.fn, header: { little: true, intSize: 4, sizeT: 8, numSize: 8 } }, { strip: true });
  let functions = 0; let instructions = 0;
  const count = (f) => { functions++; instructions += f.code.length; f.protos.forEach(count); };
  count(r.fn);
  return { bytes: bin, stats: { functions, instructions, constants: r.fn.k.length, masked: acc.masked } };
}

/** Is this the shape of a Zartha build: the header that names the standard library, the register declaration of the machine and a dispatch loop. */
export function looksLikeZartha(ast) {
  try {
    const head = find(ast, (n) => n.type === 'Local' && n.ids.length >= 20 && n.values.length >= 20)[0];
    return Boolean(head && find(ast, mainDecl).length && find(ast, isDispatchLoop).length);
  } catch { return false; }
}

// ---- what the generator adds to the program ----------------------------------------------------------------------------------

const hasCall = (n, name) => find(n, (m) => m.type === 'Call' && m.fn.type === 'Name' && m.fn.name === name).length > 0;
const isString = (e, v) => e && e.type === 'String' && e.value === v;

/**
 * The generator marks the program it is given with `_OBFUSCATED = true`, and its anti-tamper option compiles a block in front of it: a function that calls the macro `_CRASH()`, a
 * bait object that crashes when printed, and a test that calls it again if the program was tampered with or is longer than the template says. Once the program is source again
 * the block is recognised by that shape, not by names, and taken away.
 */
export function removeZarthaGuards(chunk) {
  const body = chunk.body;
  let changed = 0;
  const marker = body.findIndex((s) => s.type === 'Assign' && s.targets.length === 1 && s.targets[0].type === 'Name' && s.targets[0].name === '_OBFUSCATED' && s.values[0].type === 'True');
  const crash = body.findIndex((s) => s.type === 'Assign' && s.values.length === 1 && s.values[0].type === 'Func' && hasCall(s.values[0], '_CRASH'));
  let drop = new Set();
  if (crash >= 0) {
    const test = body.findIndex((s, i) => i > crash && s.type === 'If' && find(s, (n) => n.type === 'Return' && n.values.length === 1 && n.values[0].type === 'Call' && n.values[0].args.some((a) => isString(a, 'Tamper detected'))).length > 0);
    if (test > crash) {
      // the flag the function sets is declared just before it
      const flag = body[crash].values[0].body.find((s) => s.type === 'Assign' && s.targets[0].type === 'Name' && s.values[0].type === 'True');
      let start = crash;
      const before = body[crash - 1];
      if (flag && before && before.type === 'Assign' && before.targets[0].type === 'Name' && before.targets[0].name === flag.targets[0].name && before.values[0].type === 'False') start = crash - 1;
      for (let i = start; i <= test; i++) drop.add(i);
      changed += 1;
    }
  }
  if (marker >= 0) { drop.add(marker); changed += 1; }
  if (drop.size) chunk.body = body.filter((_, i) => !drop.has(i));
  return { changed };
}

/**
 * The generator's LOADBOOL template writes `\n\t` inside a `[=[ ]=]` string where it means a line break, so a build that loads a boolean and skips the next instruction (every
 * `return a < b`) is not valid Lua as shipped. The text is `Temp[n]` followed by that escape and the step over the next instruction, which nothing else produces; only that is mended.
 */
export function repairZarthaSource(src) {
  let count = 0;
  const fixed = src.replace(/(Stack\[Temp\[\d+\]\] = Temp\[\d+\])\\n\\t(pointer = pointer \+ 1)/g, (_, a, b) => { count++; return `${a}\n\t${b}`; });
  return { source: fixed, count };
}
