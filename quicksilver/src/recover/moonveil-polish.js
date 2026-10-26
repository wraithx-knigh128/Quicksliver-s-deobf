// What is left to do to a structured, lifted MoonVeil function before it reads as source: loops written the way Lua writes them, variables
// declared, a function's own functions where they are defined.
//
// Everything here works on statement lists (the output of decompile/cfg.js) and returns new lists; nothing is evaluated.

import { walk } from '../core/walk.js';

const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const isName = (e, n) => { e = strip(e); return !!e && e.type === 'Name' && (n === undefined || e.name === n); };
const countName = (node, name) => { let n = 0; walk(node, (x) => { if (x.type === 'Name' && x.name === name) n++; }); return n; };
const same = (a, b) => JSON.stringify(clean(a)) === JSON.stringify(clean(b));
const clean = (e) => (Array.isArray(e) ? e.map(clean) : e && typeof e === 'object' ? Object.fromEntries(Object.entries(e).filter(([k]) => !['line', 'pos', 'endPos', 'endLine', 'raw', 'dot', 'sugar'].includes(k)).map(([k, v]) => [k, clean(v)])) : e);

/**
 * Applies `fn(list, after)` to every statement list in the tree, innermost lists first (not into function bodies unless `deep`). `after` is the
 * statement that runs when control leaves the list at its end (the statement following the `if` or `do` that holds it), or null when control
 * goes back to a loop, or leaves the function, or is not known.
 */
export function mapLists(stmts, fn, deep = false, after = null) {
  const inner = (list, next) => mapLists(list, fn, deep, next);
  const exprs = (n) => (deep ? mapExprFuncs(n, fn) : n);
  const out = stmts.map((s, i) => {
    const next = i + 1 < stmts.length ? stmts[i + 1] : after;
    switch (s.type) {
      case 'If': return { ...s, clauses: s.clauses.map((c) => ({ ...c, cond: exprs(c.cond), body: inner(c.body, next) })), orelse: s.orelse ? inner(s.orelse, next) : s.orelse };
      case 'Do': return { ...s, body: inner(s.body, next) };
      case 'While': case 'Repeat': case 'NumFor': case 'GenFor': return { ...s, body: inner(s.body, null) };
      case 'Assign': return deep ? { ...s, values: s.values.map(exprs), targets: s.targets.map(exprs) } : s;
      case 'Local': return deep ? { ...s, values: s.values.map(exprs) } : s;
      case 'CallStmt': return deep ? { ...s, call: exprs(s.call) } : s;
      case 'Return': return deep && s.values ? { ...s, values: s.values.map(exprs) } : s;
      default: return s;
    }
  });
  return fn(out, after);
}
function mapExprFuncs(node, fn) {
  if (!node || typeof node !== 'object') return node;
  if (Array.isArray(node)) return node.map((x) => mapExprFuncs(x, fn));
  if (node.type === 'Func') return { ...node, body: mapLists(node.body, fn, true) };
  const c = { ...node };
  for (const k of Object.keys(c)) if (k !== 'line' && c[k] && typeof c[k] === 'object') c[k] = mapExprFuncs(c[k], fn);
  return c;
}

// ---- generic for ------------------------------------------------------------------------------------------------------------

/**
 * The shape the lifted iteration instructions leave:
 *
 *     a, b, c = forgprep(a, b, c)        (after, possibly, `a, b, c = explist`)
 *     v1, v2 = a(b, c)
 *     while true do
 *       c = v1
 *       if v1 == nil then break end
 *       ...body...
 *       v1, v2 = a(b, c)
 *     end
 *
 * becomes `for v1, v2 in explist do ...body... end`, provided the body leaves a, b, c alone.
 */
export function forIn(stmts) {
  return mapLists(stmts, (list, outer) => {
    const out = [];
    for (let i = 0; i < list.length; i++) {
      const prep = list[i];
      const first = list[i + 1];
      const loop = list[i + 2];
      let m = matchForIn(prep, first, loop);
      let used = 2;
      if (!m) { m = matchForInGuarded(prep, first, list[i + 2], list[i + 3]); used = 3; }
      if (!m) { m = matchForInReturning(prep, first, list[i + 2], list[i + 3], i + 4 < list.length ? list[i + 4] : outer); used = 3; }
      if (!m) { out.push(prep); continue; }
      let exprs = m.regs.map((n) => ({ type: 'Name', name: n }));
      // the call that produced the three registers, right before
      const before = out[out.length - 1];
      if (before && before.type === 'Assign' && before.targets.length === 3 && before.values.length === 1 && before.targets.every((t, k) => t.type === 'Name' && t.name === m.regs[k]) && ['Call', 'MethodCall'].includes(strip(before.values[0]).type)) {
        exprs = [before.values[0]];
        out.pop();
      }
      out.push({ type: 'GenFor', ids: m.vars.map((n) => ({ type: 'Id', name: n })), exprs, body: m.body });
      i += used;
    }
    return out;
  });
}

/**
 * The same loop when the first test has been pulled out in front:
 *     a, b, c = forgprep(a, b, c); v1, v2 = a(b, c); c = v1
 *     if v1 ~= nil then while true do ...body... v1, v2 = a(b, c); c = v1; if v1 == nil then break end end end
 */
function matchForInGuarded(prep, first, setCtl, guard) {
  if (!prep || !first || !setCtl || !guard) return null;
  if (prep.type !== 'Assign' || prep.targets.length !== 3 || prep.values.length !== 1 || !prep.targets.every((t) => t.type === 'Name')) return null;
  const call = strip(prep.values[0]);
  if (call.type !== 'Call' || !isName(call.fn, 'forgprep')) return null;
  const regs = prep.targets.map((t) => t.name);
  const callsIter = (e) => { e = strip(e); return e.type === 'Call' && isName(e.fn, regs[0]) && e.args.length === 2 && isName(e.args[0], regs[1]) && isName(e.args[1], regs[2]); };
  if (first.type !== 'Assign' || first.values.length !== 1 || !callsIter(first.values[0]) || !first.targets.every((t) => t.type === 'Name')) return null;
  const vars = first.targets.map((t) => t.name);
  if (setCtl.type !== 'Assign' || setCtl.targets.length !== 1 || !isName(setCtl.targets[0], regs[2]) || !isName(setCtl.values[0], vars[0])) return null;
  if (guard.type !== 'If' || guard.clauses.length !== 1 || guard.orelse || guard.clauses[0].body.length !== 1) return null;
  const c = strip(guard.clauses[0].cond);
  const notNil = (c.type === 'Unary' && c.op === 'not' && (() => { const q = strip(c.arg); return q.type === 'Binary' && q.op === '==' && isName(q.left, vars[0]) && strip(q.right).type === 'Nil'; })()) || (c.type === 'Binary' && c.op === '~=' && isName(c.left, vars[0]) && strip(c.right).type === 'Nil');
  if (!notNil) return null;
  const loop = guard.clauses[0].body[0];
  if (loop.type !== 'While' || strip(loop.cond).type !== 'True' || loop.body.length < 4) return null;
  const b = loop.body;
  const n = b.length;
  const tail = b[n - 3];
  const ctl = b[n - 2];
  const brk = b[n - 1];
  if (tail.type !== 'Assign' || tail.targets.length !== vars.length || !tail.targets.every((t, k) => isName(t, vars[k])) || tail.values.length !== 1 || !callsIter(tail.values[0])) return null;
  if (ctl.type !== 'Assign' || ctl.targets.length !== 1 || !isName(ctl.targets[0], regs[2]) || !isName(ctl.values[0], vars[0])) return null;
  if (brk.type !== 'If' || brk.clauses.length !== 1 || brk.orelse || brk.clauses[0].body.length !== 1 || brk.clauses[0].body[0].type !== 'Break') return null;
  const bc = strip(brk.clauses[0].cond);
  if (!(bc.type === 'Binary' && bc.op === '==' && isName(bc.left, vars[0]) && strip(bc.right).type === 'Nil')) return null;
  const body = b.slice(0, n - 3);
  for (const r of regs) if (countName(body, r)) return null;
  return { regs, vars, body };
}

/**
 * The loop whose end is a `return`: when the iterator runs out the function returns X (the same return follows the whole statement), and a `break`
 * inside leads to the statements after the `while`. It is `for ... do ... end` followed by that return, the breaks written out as what follows them.
 */
function matchForInReturning(prep, first, setCtl, guard, after) {
  if (!prep || !first || !setCtl || !guard || !after || after.type !== 'Return') return null;
  const m = matchForInGuardedShape(prep, first, setCtl, guard);
  if (!m) return null;
  const { regs, vars, loop, rest, body, endTest } = m;
  // the test at the end of the loop returns what the code after the statement returns
  if (endTest.clauses[0].body.length !== 1 || endTest.clauses[0].body[0].type !== 'Return') return null;
  if (!same(endTest.clauses[0].body[0], after)) return null;
  // what a `break` leads to: the statements after the while, which must end the function
  if (!rest.length || rest[rest.length - 1].type !== 'Return') return null;
  const unbreak = (list) => list.flatMap((st) => {
    if (st.type === 'Break') return rest;
    if (st.type === 'If') return [{ ...st, clauses: st.clauses.map((c) => ({ ...c, body: unbreak(c.body) })), orelse: st.orelse ? unbreak(st.orelse) : st.orelse }];
    if (st.type === 'Do') return [{ ...st, body: unbreak(st.body) }];
    return [st];
  });
  for (const r of regs) if (countName(body, r)) return null;
  return { regs, vars, body: unbreak(body), keepAfter: true };
}

/** The shape shared by the guarded forms: returns the pieces, or null. */
function matchForInGuardedShape(prep, first, setCtl, guard) {
  if (prep.type !== 'Assign' || prep.targets.length !== 3 || prep.values.length !== 1 || !prep.targets.every((t) => t.type === 'Name')) return null;
  const call = strip(prep.values[0]);
  if (call.type !== 'Call' || !isName(call.fn, 'forgprep')) return null;
  const regs = prep.targets.map((t) => t.name);
  const callsIter = (e) => { e = strip(e); return e.type === 'Call' && isName(e.fn, regs[0]) && e.args.length === 2 && isName(e.args[0], regs[1]) && isName(e.args[1], regs[2]); };
  if (first.type !== 'Assign' || first.values.length !== 1 || !callsIter(first.values[0]) || !first.targets.every((t) => t.type === 'Name')) return null;
  const vars = first.targets.map((t) => t.name);
  if (setCtl.type !== 'Assign' || setCtl.targets.length !== 1 || !isName(setCtl.targets[0], regs[2]) || !isName(setCtl.values[0], vars[0])) return null;
  if (guard.type !== 'If' || guard.clauses.length !== 1 || guard.orelse || guard.clauses[0].body.length < 1) return null;
  const c = strip(guard.clauses[0].cond);
  const notNil = (c.type === 'Unary' && c.op === 'not' && (() => { const q = strip(c.arg); return q.type === 'Binary' && q.op === '==' && isName(q.left, vars[0]) && strip(q.right).type === 'Nil'; })()) || (c.type === 'Binary' && c.op === '~=' && isName(c.left, vars[0]) && strip(c.right).type === 'Nil');
  if (!notNil) return null;
  const loop = guard.clauses[0].body[0];
  if (loop.type !== 'While' || strip(loop.cond).type !== 'True' || loop.body.length < 4) return null;
  const b = loop.body;
  const n = b.length;
  const tail = b[n - 3];
  const ctl = b[n - 2];
  const endTest = b[n - 1];
  if (tail.type !== 'Assign' || tail.targets.length !== vars.length || !tail.targets.every((t, k) => isName(t, vars[k])) || tail.values.length !== 1 || !callsIter(tail.values[0])) return null;
  if (ctl.type !== 'Assign' || ctl.targets.length !== 1 || !isName(ctl.targets[0], regs[2]) || !isName(ctl.values[0], vars[0])) return null;
  if (endTest.type !== 'If' || endTest.clauses.length !== 1 || endTest.orelse) return null;
  const bc = strip(endTest.clauses[0].cond);
  if (!(bc.type === 'Binary' && bc.op === '==' && isName(bc.left, vars[0]) && strip(bc.right).type === 'Nil')) return null;
  return { regs, vars, loop, rest: guard.clauses[0].body.slice(1), body: b.slice(0, n - 3), endTest };
}

function matchForIn(prep, first, loop) {
  if (!prep || !first || !loop) return null;
  if (prep.type !== 'Assign' || prep.targets.length !== 3 || prep.values.length !== 1 || !prep.targets.every((t) => t.type === 'Name')) return null;
  const call = strip(prep.values[0]);
  if (call.type !== 'Call' || !isName(call.fn, 'forgprep')) return null;
  const regs = prep.targets.map((t) => t.name);
  if (!call.args.every((a, k) => isName(a, regs[k]))) return null;
  const callsIter = (e) => { e = strip(e); return e.type === 'Call' && isName(e.fn, regs[0]) && e.args.length === 2 && isName(e.args[0], regs[1]) && isName(e.args[1], regs[2]); };
  if (first.type !== 'Assign' || first.values.length !== 1 || !callsIter(first.values[0]) || !first.targets.every((t) => t.type === 'Name')) return null;
  const vars = first.targets.map((t) => t.name);
  if (loop.type !== 'While' || strip(loop.cond).type !== 'True') return null;
  const b = loop.body;
  if (b.length < 3) return null;
  const setCtl = b[0];
  if (setCtl.type !== 'Assign' || setCtl.targets.length !== 1 || !isName(setCtl.targets[0], regs[2]) || !isName(setCtl.values[0], vars[0])) return null;
  const test = b[1];
  if (test.type !== 'If' || test.clauses.length !== 1 || test.orelse) return null;
  const c = strip(test.clauses[0].cond);
  if (!(c.type === 'Binary' && c.op === '==' && isName(c.left, vars[0]) && strip(c.right).type === 'Nil')) return null;
  if (test.clauses[0].body.length !== 1 || test.clauses[0].body[0].type !== 'Break') return null;
  const tail = b[b.length - 1];
  if (tail.type !== 'Assign' || tail.targets.length !== vars.length || !tail.targets.every((t, k) => isName(t, vars[k])) || tail.values.length !== 1 || !callsIter(tail.values[0])) return null;
  const body = b.slice(2, -1);
  for (const r of regs) if (countName(body, r)) return null;
  return { regs, vars, body };
}

// ---- names ------------------------------------------------------------------------------------------------------------------------

/** `t["insert"]` is `t.insert` when the key is a name. */
export function dotKeys(node) {
  if (!node || typeof node !== 'object') return node;
  if (Array.isArray(node)) return node.map(dotKeys);
  const c = { ...node };
  for (const k of Object.keys(c)) if (k !== 'line' && c[k] && typeof c[k] === 'object') c[k] = dotKeys(c[k]);
  if (c.type === 'Index' && c.key && c.key.type === 'String' && /^[A-Za-z_][A-Za-z0-9_]*$/.test(c.key.value) && !KEYWORDS.has(c.key.value)) c.dot = true;
  return c;
}
const KEYWORDS = new Set(['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while']);

/** Renames `r<k>` to `<prefix><k>` everywhere, including in nested functions. */
export function renameRegisters(node, prefix) {
  if (!node || typeof node !== 'object') return node;
  if (Array.isArray(node)) return node.map((x) => renameRegisters(x, prefix));
  const c = { ...node };
  for (const k of Object.keys(c)) if (k !== 'line' && c[k] && typeof c[k] === 'object') c[k] = renameRegisters(c[k], prefix);
  if ((c.type === 'Name' || c.type === 'Id') && /^r\d+$/.test(c.name)) c.name = prefix + c.name.slice(1);
  else if ((c.type === 'Name' || c.type === 'Id') && /^tmp\d+$/.test(c.name)) c.name = `${prefix}v${c.name.slice(3)}`;
  return c;
}

/**
 * Names the lifter used for its own working variables (the interpreter's locals that survived) become `tmp<n>`, so that they are declared like the
 * registers. A name written as a global by the program itself is marked and left alone.
 */
export function renameScratch(stmts) {
  const map = new Map();
  const isRegister = (n) => /^(r\d+|up\d+|va_list|va_n|tmp\d+)$/.test(n);
  const collect = (node) => walk(node, (x) => {
    if (x.type === 'Func') return false;
    if (x.type === 'Assign') for (const t of x.targets) if (t.type === 'Name' && !t.global && !isRegister(t.name) && !map.has(t.name)) map.set(t.name, `tmp${map.size + 1}`);
    return undefined;
  });
  collect(stmts);
  if (!map.size) return stmts;
  const sub = (n) => {
    if (!n || typeof n !== 'object') return n;
    if (Array.isArray(n)) return n.map(sub);
    if (n.type === 'Func') return n;
    const c = { ...n };
    for (const k of Object.keys(c)) if (k !== 'line' && c[k] && typeof c[k] === 'object') c[k] = sub(c[k]);
    if ((c.type === 'Name' || c.type === 'Id') && map.has(c.name) && !c.global) c.name = map.get(c.name);
    return c;
  };
  return sub(stmts);
}

/** `up<k>` becomes the expression the closure was given for its k-th captured variable. */
export function substituteUpvalues(node, map) {
  if (!node || typeof node !== 'object') return node;
  if (Array.isArray(node)) return node.map((x) => substituteUpvalues(x, map));
  if (node.type === 'Name' && /^up\d+$/.test(node.name)) { const e = map.get(Number(node.name.slice(2))); return e ? { ...e } : node; }
  const c = { ...node };
  for (const k of Object.keys(c)) if (k !== 'line' && c[k] && typeof c[k] === 'object') c[k] = substituteUpvalues(c[k], map);
  return c;
}

// ---- declarations -------------------------------------------------------------------------------------------------------------

/**
 * Declares the variables of a function body. A variable whose first appearance is a plain assignment at the top level of the body is declared
 * there (`local x = ...`); the others, which first appear inside a block, are listed in one `local` before everything.
 * @param {object[]} stmts
 * @param {string} prefix the register prefix of this function's own variables
 * @param {string[]} params
 */
export function declareLocals(stmts, prefix, params) {
  const re = new RegExp(`^${prefix}v?\\d+$`);
  const order = [];
  const seen = new Set(params);
  const note = (n) => { if (re.test(n) && !seen.has(n)) { seen.add(n); order.push(n); } };
  const walkNames = (node) => walk(node, (x) => { if (x.type === 'Name') note(x.name); });
  // first appearance, in the order a reader meets them
  const topFirst = new Map(); // name -> index of the top-level statement that is its first appearance as a plain assignment target
  stmts.forEach((s, i) => {
    const before = seen.size;
    void before;
    if (s.type === 'Assign' && s.targets.length === 1 && s.targets[0].type === 'Name' && re.test(s.targets[0].name) && !seen.has(s.targets[0].name) && countName(s.values, s.targets[0].name) === 0) {
      topFirst.set(s.targets[0].name, i);
      seen.add(s.targets[0].name);
      walkNames(s.values);
      return;
    }
    walkNames(s);
  });
  const hoisted = order;
  const body = stmts.map((s, i) => {
    for (const [n, at] of topFirst) if (at === i) return { type: 'Local', ids: [{ type: 'Id', name: n }], values: s.values, line: s.line };
    return s;
  });
  const head = hoisted.length ? [{ type: 'Local', ids: hoisted.map((n) => ({ type: 'Id', name: n })), values: [] }] : [];
  return [...head, ...body];
}
