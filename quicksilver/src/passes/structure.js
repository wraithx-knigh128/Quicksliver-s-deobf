// Structural clean-ups that are independent of any one obfuscator.
//
//   unwrapWrapper       `return (function(...) BODY end)(...)` -> BODY
//   removeUnusedVararg  `function(a, ...)` where `...` is never read -> `function(a)`
//   tidyIfs             `if c then else B end` -> `if not c then B end` (left behind when a test was flipped)

import { transform, walk } from '../core/walk.js';

/**
 * Obfuscators wrap the whole script in an immediately-invoked function. Peeling it off puts the
 * script's real definitions at the top level where the other passes can see them.
 */
export function unwrapWrapper(chunk) {
  let unwrapped = 0;
  for (let guard = 0; guard < 4; guard++) {
    // allow a leading comment-only prefix; the wrapper must be the only statement
    if (chunk.body.length !== 1) break;
    const s = chunk.body[0];
    let call = null;
    if (s.type === 'Return' && s.values.length === 1 && s.values[0].type === 'Call') call = s.values[0];
    else if (s.type === 'CallStmt' && s.call.type === 'Call') call = s.call;
    if (!call) break;
    const fn = call.fn.type === 'Paren' ? call.fn.expr : call.fn;
    if (fn.type !== 'Func' || fn.params.length !== 0 || !fn.vararg) break;
    // The wrapper is called with `...` (or nothing); either way the body can run at chunk level.
    const argsOk = call.args.length === 0 || (call.args.length === 1 && call.args[0].type === 'Vararg');
    if (!argsOk) break;
    const comments = [...(s.comments || []), ...(chunk.body[0].trailing ? [] : [])];
    chunk.body = fn.body;
    if (comments.length && chunk.body[0]) chunk.body[0].comments = [...comments, ...(chunk.body[0].comments || [])];
    unwrapped++;
  }
  return { changed: unwrapped };
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
