// Structural clean-ups that are independent of any one obfuscator.
//
//   unwrapWrapper       `[preamble] return (function(...) BODY end)(...)` -> `[preamble] BODY`
//   removeUnusedVararg  `function(a, ...)` where `...` is never read -> `function(a)`
//   tidyIfs             `if c then else B end` -> `if not c then B end` (left behind when a test was flipped)
//   whileToIf           `while c do ... return end` -> `if c then ... end` (a loop whose body always leaves it runs at most once)

import { transform, walk } from '../core/walk.js';

/**
 * Obfuscators wrap the whole script in an immediately-invoked function. Peeling it off puts the
 * script's real definitions at the top level where the other passes can see them.
 */
export function unwrapWrapper(chunk) {
  let unwrapped = 0;
  for (let guard = 0; guard < 4; guard++) {
    // The wrapper is the last statement. A `return` wrapper may follow a preamble of statements that declare nothing (a watermark call, an assignment to a global): the body then runs
    // after those statements, in the same scope, which is where it was called from. A wrapper called as a statement must be alone, since its own `return` would end the chunk early.
    if (!chunk.body.length) break;
    const s = chunk.body[chunk.body.length - 1];
    if (chunk.body.length !== 1 && s.type !== 'Return') break;
    if (unwrapNamedWrapper(chunk)) { unwrapped++; continue; }
    // a preamble that declares a local would capture names the wrapper body reads as globals once the body is spliced in beside it: it is only passed over when it declares none
    if (chunk.body.slice(0, -1).some((p) => p.type === 'Local' || p.type === 'LocalFunction' || p.type === 'Label')) break;
    let call = null;
    if (s.type === 'Return' && s.values.length === 1 && s.values[0].type === 'Call') call = s.values[0];
    else if (s.type === 'CallStmt' && s.call.type === 'Call') call = s.call;
    if (!call) break;
    const fn = call.fn.type === 'Paren' ? call.fn.expr : call.fn;
    if (fn.type !== 'Func' || fn.params.length !== 0 || !fn.vararg) break;
    // The wrapper is called with `...` (or nothing); either way the body can run at chunk level.
    const argsOk = call.args.length === 0 || (call.args.length === 1 && call.args[0].type === 'Vararg');
    if (!argsOk) break;
    const comments = [...(s.comments || [])];
    const preamble = chunk.body.slice(0, -1);
    chunk.body = [...preamble, ...fn.body];
    if (comments.length && fn.body[0]) fn.body[0].comments = [...comments, ...(fn.body[0].comments || [])];
    unwrapped++;
  }
  return { changed: unwrapped };
}

/**
 * `local L = { ... }; local F = function(...) BODY end; return F(unpack(L))`: what a lifted flattener leaves of the script's own
 * wrapper (the arguments packed, the body a local function called once with them). BODY runs at chunk level instead when F and L
 * are used nowhere else and no name BODY reads from outside is one of the preamble's locals.
 */
function unwrapNamedWrapper(chunk) {
  const body = chunk.body;
  const s = body[body.length - 1];
  if (s.type !== 'Return' || s.values.length !== 1 || s.values[0].type !== 'Call') return false;
  const call = s.values[0];
  if (call.fn.type !== 'Name' || call.args.length !== 1) return false;
  const fi = body.findIndex((x) => x.type === 'Local' && x.ids.length === 1 && x.ids[0].name === call.fn.name && x.values.length === 1 && x.values[0].type === 'Func');
  if (fi < 0) return false;
  const fn = body[fi].values[0];
  if (fn.params.length || !fn.vararg) return false;
  const a = call.args[0];
  let li = -1;
  const unpackOfVarargs = (x) => x.type === 'Call' && x.fn.type === 'Name' && x.fn.name === 'unpack' && x.args.length === 1 && x.args[0].type === 'Table'
    && x.args[0].fields.length === 1 && x.args[0].fields[0].kind === 'item' && x.args[0].fields[0].value.type === 'Vararg';
  if (a.type === 'Vararg' || unpackOfVarargs(a)) li = -2;
  else if (a.type === 'Call' && a.fn.type === 'Name' && a.fn.name === 'unpack' && a.args.length === 1 && a.args[0].type === 'Name') {
    li = body.findIndex((x) => x.type === 'Local' && x.ids.length === 1 && x.ids[0].name === a.args[0].name && x.values.length === 1
      && x.values[0].type === 'Table' && x.values[0].fields.length === 1 && x.values[0].fields[0].kind === 'item' && x.values[0].fields[0].value.type === 'Vararg');
    if (li < 0) return false;
  } else return false;
  const preamble = body.filter((x, i) => i !== fi && i !== li && i !== body.length - 1);
  // the preamble must not rebind `unpack` or the names; anything it declares must not be read by BODY as a free name
  const declared = new Set();
  for (const x of preamble) {
    if (x.type === 'Local') x.ids.forEach((id) => declared.add(id.name));
    else if (x.type === 'LocalFunction') declared.add(x.id.name);
    else return false;
  }
  declared.add(call.fn.name);
  if (li >= 0) declared.add(body[li].ids[0].name);
  const free = freeNames(fn.body);
  if ([...declared].some((n) => free.has(n))) return false;
  // what the preamble's locals were set to must not be needed: values without calls only
  const pure = (e) => { let ok = true; const v = (n) => { if (!ok || !n || typeof n !== 'object') return; if (Array.isArray(n)) { n.forEach(v); return; } if (n.type === 'Call' || n.type === 'Func') { ok = n.type !== 'Call' || (n.fn.type === 'Name' && n.fn.name === 'getfenv' && n.args.length === 0); if (!ok) return; } eachChild(n, v); }; v(e); return ok; };
  if (!preamble.every((x) => x.values.every(pure))) return false;
  chunk.body = [...fn.body];
  return true;
}

const eachChild = (n, fn) => { for (const k of Object.keys(n)) { if (k === 'comments' || k === 'endComments') continue; const c = n[k]; if (c && typeof c === 'object') fn(c); } };

/** Names a block reads or writes that it does not declare itself (scopes are tracked roughly: a name declared anywhere inside counts as declared from there on). */
function freeNames(stmts) {
  const free = new Set();
  const visit = (n, scope) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach((x) => visit(x, scope)); return; }
    switch (n.type) {
      case 'Name': if (!scope.has(n.name)) free.add(n.name); return;
      case 'Local': n.values.forEach((v) => visit(v, scope)); n.ids.forEach((id) => scope.add(id.name)); return;
      case 'LocalFunction': scope.add(n.id.name); visit(n.func, scope); return;
      case 'Func': { const inner = new Set(scope); n.params.forEach((p) => inner.add(p.name)); visit(n.body, inner); return; }
      case 'NumFor': { visit(n.start, scope); visit(n.stop, scope); visit(n.step, scope); const inner = new Set(scope); inner.add(n.id.name); visit(n.body, inner); return; }
      case 'GenFor': { n.exprs.forEach((v) => visit(v, scope)); const inner = new Set(scope); n.ids.forEach((v) => inner.add(v.name)); visit(n.body, inner); return; }
      default: eachChild(n, (c) => visit(c, scope));
    }
  };
  visit(stmts, new Set());
  return free;
}

/** Drop `...` from functions that never use it (Prometheus' AddVararg adds one to every function). */
export function removeUnusedVararg(chunk) {
  let changed = 0;
  const usesVararg = (body) => {
    let used = false;
    const visit = (n) => {
      if (used || !n || typeof n !== 'object') return;
      if (Array.isArray(n)) { n.forEach(visit); return; }
      if (n.type === 'Vararg') { used = true; return; }
      if (n.type === 'Func') return; // `...` inside a nested function belongs to that function
      walkChildren(n, visit);
    };
    visit(body);
    return used;
  };
  const walkChildren = (n, fn) => {
    walk(n, (m, parent) => { if (m !== n && parent === n) { fn(m); return false; } return undefined; });
  };
  transform(chunk, {
    expr(e) {
      if (e.type === 'Func' && e.vararg && !usesVararg(e.body)) { e.vararg = false; changed++; }
      return undefined;
    },
  });
  return { changed };
}

/** The condition that holds exactly when `cond` does not, written as simply as is exact. */
export function negateCondition(cond) {
  if (cond.type === 'Paren') return negateCondition(cond.expr);
  if (cond.type === 'Unary' && cond.op === 'not') return cond.arg;   // only truthiness matters inside `if`
  if (cond.type === 'Binary' && (cond.op === '==' || cond.op === '~=')) return { ...cond, op: cond.op === '==' ? '~=' : '==' };
  if (cond.type === 'True') return { type: 'False' };
  if (cond.type === 'False' || cond.type === 'Nil') return { type: 'True' };
  // not (a < b) is not a >= b when a value is NaN, so ordering tests keep the explicit `not`
  const inner = cond.type === 'Binary' || cond.type === 'Call' || cond.type === 'Index' || cond.type === 'Name' ? cond : { type: 'Paren', expr: cond };
  return { type: 'Unary', op: 'not', arg: inner.type === 'Binary' ? { type: 'Paren', expr: inner } : inner };
}

/** Compilers emit `if c then <nothing> else B end` for a flipped test; say it the way a person would. */
export function tidyIfs(chunk) {
  let changed = 0;
  transform(chunk, {
    stmt(s) {
      if (s.type !== 'If' || s.clauses.length !== 1 || s.clauses[0].body.length || !s.orelse || !s.orelse.length) return undefined;
      changed++;
      return { ...s, clauses: [{ cond: negateCondition(s.clauses[0].cond), body: s.orelse }], orelse: null };
    },
  });
  return { changed };
}

/** Break and continue statements and gotos that belong to this loop level (not to loops or functions nested inside it). */
function loopExits(body) {
  const found = { breaks: 0, other: false };
  const visit = (n) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(visit); return; }
    if (n.type === 'Func' || n.type === 'While' || n.type === 'Repeat' || n.type === 'NumFor' || n.type === 'GenFor') {
      // a nested loop owns its own breaks, but a goto or label still reaches out
      walk(n, (m) => { if (m.type === 'Goto' || m.type === 'Label') found.other = true; return undefined; });
      return;
    }
    if (n.type === 'Break') found.breaks++;
    else if (n.type === 'Continue' || n.type === 'Goto' || n.type === 'Label') found.other = true;
    for (const k of Object.keys(n)) if (k !== 'line' && k !== 'comments' && k !== 'trailing' && n[k] && typeof n[k] === 'object') visit(n[k]);
  };
  body.forEach(visit);
  return found;
}

/**
 * A `while` whose last statement is a `return` (or `break`) and which has no other way round to the top runs its body at most once: it is an `if`.
 * Flatteners write their conditionals this way. Nothing else at this loop level may break or continue, and no goto or label may be inside.
 */
export function whileToIf(chunk) {
  let changed = 0;
  transform(chunk, {
    stmt(s) {
      if (s.type !== 'While' || !s.body.length) return undefined;
      const last = s.body[s.body.length - 1];
      if (last.type !== 'Return' && last.type !== 'Break') return undefined;
      const exits = loopExits(s.body);
      if (exits.other || exits.breaks !== (last.type === 'Break' ? 1 : 0)) return undefined;
      changed++;
      const body = last.type === 'Break' ? s.body.slice(0, -1) : s.body;
      return { type: 'If', clauses: [{ cond: s.cond, body }], orelse: null, comments: s.comments, line: s.line, endLine: s.endLine };
    },
  });
  return { changed };
}
