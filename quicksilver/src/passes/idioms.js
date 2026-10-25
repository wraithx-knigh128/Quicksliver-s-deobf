// Idioms of decompiled code.
//
// A compiler spreads some everyday constructs over several instructions, and the decompiler gives them back as
// the statements those instructions are. These passes write them the way a person would. Each one is exact: the
// rewritten program does the same thing, so none of them needs a sandbox or a guess.
//
//   booleanResults      `if a < b then v = true else v = false end return v`  ->  `return a < b`
//   shortCircuits       `v = a  if not v then v = b end`  ->  `v = a or b`   (and `if v then v = b end` -> `v = a and b`)
//   tableConstructors   `local t = {}  t.a = 1  t.b = 2`  ->  `local t = { a = 1, b = 2 }`
//   methodCalls         `f = o.m  f(o, a)`  ->  `o:m(a)`   (once the temporary is gone: `o.m(o, a)`)
//   bareNils            `local x = nil`  ->  `local x`
//   unsetLocals         a temporary declared without a value and never assigned is `nil` where it is read
//   orientComparisons   `0 < n`  ->  `n > 0`   (the compiler swaps the operands of `>` and `>=`)
//   numericLoops        `local i = 0  while true do i = i + 1  if not (i <= n) then break end  ...  end`  ->  `for i = 1, n do ... end`
//   loopForms           `while true do if c then break end ... end`  ->  `while not c do ... end`,  a break test at the end -> `repeat ... until c`
//   functionForms       `T.f = function(...)`  ->  `function T.f(...)`,  `T.f = function(p, ...)`  ->  `function T:f(...)`
//                       when the script calls `:f(`,  `local f = function` -> `local function f`
//
// They run on the output of the bytecode decompiler only. A script somebody wrote by hand keeps its own style.

import { transform, walk } from '../core/walk.js';
import { analyze } from '../core/scope.js';
import { isIdentifier } from '../core/printer.js';
import { negateCondition } from './structure.js';
import { isMachineName } from './rename.js';

const COMPARISON = new Set(['==', '~=', '<', '<=', '>', '>=']);

/** Can the expression only evaluate to true or false? (`if e then v = true else v = false end` is then `v = e`.) */
function isBoolean(e) {
  switch (e.type) {
    case 'True': case 'False': return true;
    case 'Paren': return isBoolean(e.expr);
    case 'Unary': return e.op === 'not';
    case 'Binary':
      if (COMPARISON.has(e.op)) return true;
      return (e.op === 'and' || e.op === 'or') && isBoolean(e.left) && isBoolean(e.right);
    default: return false;
  }
}

const boolValue = (e) => (e.type === 'True' ? true : e.type === 'False' ? false : null);

/** `if C then v = true else v = false end` (either way round): the variable name and whether C is negated. */
function booleanAssignment(s) {
  if (s.type !== 'If' || s.clauses.length !== 1 || !s.orelse || s.clauses[0].body.length !== 1 || s.orelse.length !== 1) return null;
  const [a, b] = [s.clauses[0].body[0], s.orelse[0]];
  for (const x of [a, b]) if (x.type !== 'Assign' || x.targets.length !== 1 || x.values.length !== 1 || x.targets[0].type !== 'Name') return null;
  if (a.targets[0].name !== b.targets[0].name) return null;
  const [va, vb] = [boolValue(a.values[0]), boolValue(b.values[0])];
  if (va === null || vb === null || va === vb) return null;
  if (!isBoolean(s.clauses[0].cond)) return null;
  return { target: a.targets[0], negate: va === false, cond: s.clauses[0].cond };
}

export function booleanResults(chunk) {
  let changed = 0;
  transform(chunk, {
    block(stmts) {
      const out = [];
      for (let i = 0; i < stmts.length; i++) {
        const s = stmts[i];
        const m = booleanAssignment(s);
        if (!m) { out.push(s); continue; }
        const value = m.negate ? negateCondition(m.cond) : m.cond;
        const next = stmts[i + 1];
        changed++;
        if (next && next.type === 'Return' && next.values.length === 1 && next.values[0].type === 'Name' && next.values[0].name === m.target.name) {
          out.push({ ...next, values: [value] });
          i++;
        } else {
          out.push({ type: 'Assign', targets: [m.target], values: [value], comments: s.comments });
        }
      }
      return changed ? out : undefined;
    },
  });
  return { changed };
}

/** An expression whose evaluation cannot run the program's own code: constants, other variables, closures not yet called. */
function isInert(e) {
  switch (e.type) {
    case 'Number': case 'String': case 'True': case 'False': case 'Nil': case 'Name': case 'Func': return true;
    case 'Table': return e.fields.every((f) => (f.kind !== 'keyed' || isInert(f.key)) && isInert(f.value));
    case 'Unary': return e.op === '-' && e.arg.type === 'Number';
    default: return false;
  }
}

export function tableConstructors(chunk) {
  const info = analyze(chunk);
  let changed = 0;
  transform(chunk, {
    block(stmts) {
      const out = [];
      for (let i = 0; i < stmts.length; i++) {
        const s = stmts[i];
        let name = null;
        let table = null;
        let captured = true;
        if (s.type === 'Local' && s.ids.length === 1 && s.values.length === 1 && s.values[0].type === 'Table' && !s.ids[0].attrib) {
          name = s.ids[0].name; table = s.values[0];
          const v = info.varOf.get(s.ids[0]);
          captured = !v || v.captured;
        } else if (s.type === 'Assign' && s.targets.length === 1 && s.targets[0].type === 'Name' && s.values.length === 1 && s.values[0].type === 'Table') {
          name = s.targets[0].name; table = s.values[0];
        }
        if (!table) { out.push(s); continue; }
        const fields = table.fields.slice();
        const seen = new Set(fields.filter((f) => f.kind === 'named').map((f) => f.key));
        let j = i + 1;
        let positional = fields.filter((f) => f.kind === 'item').length;
        for (; j < stmts.length; j++) {
          const a = stmts[j];
          if (a.type !== 'Assign' || a.targets.length !== 1 || a.values.length !== 1 || a.comments?.length) break;
          const t = a.targets[0];
          if (t.type !== 'Index' || t.obj.type !== 'Name' || t.obj.name !== name) break;
          if (mentions(a.values[0], name) || (captured && !isInert(a.values[0]))) break;
          if (t.key.type === 'String' && isIdentifier(t.key.value)) {
            if (seen.has(t.key.value)) break;
            seen.add(t.key.value);
            fields.push({ kind: 'named', key: t.key.value, value: a.values[0] });
          } else if (t.key.type === 'Number' && Number.isInteger(t.key.value) && t.key.value === positional + 1
            && a.values[0].type !== 'Call' && a.values[0].type !== 'MethodCall' && a.values[0].type !== 'Vararg'
            && !fields.some((f) => f.kind === 'keyed')) {
            // `t[1] = a; t[2] = b` is `{ a, b }`; a call is left out because as the last item it would spread its results
            positional++;
            fields.push({ kind: 'item', value: a.values[0] });
          } else break;
        }
        if (j === i + 1) { out.push(s); continue; }
        changed += j - i - 1;
        const merged = { ...table, fields };
        out.push(s.type === 'Local' ? { ...s, values: [merged] } : { ...s, values: [merged] });
        i = j - 1;
      }
      return changed ? out : undefined;
    },
  });
  return { changed };
}

export function methodCalls(chunk) {
  let changed = 0;
  transform(chunk, {
    expr(e) {
      if (e.type !== 'Call' || e.fn.type !== 'Index' || e.fn.key.type !== 'String' || !isIdentifier(e.fn.key.value)) return undefined;
      const obj = e.fn.obj;
      const first = e.args[0];
      if (obj.type !== 'Name' || !first || first.type !== 'Name' || first.name !== obj.name) return undefined;
      changed++;
      return { type: 'MethodCall', obj, name: e.fn.key.value, args: e.args.slice(1), sugar: null };
    },
  });
  return { changed };
}

export function bareNils(chunk) {
  let changed = 0;
  transform(chunk, {
    stmt(s) {
      if (s.type === 'Local' && s.values.length === 1 && s.values[0].type === 'Nil' && s.ids.length === 1 && !s.ids[0].attrib) { changed++; return { ...s, values: [] }; }
      return undefined;
    },
  });
  return { changed };
}

/** A machine-named local declared without a value and never assigned is nil wherever it is read. */
export function unsetLocals(chunk) {
  const info = analyze(chunk);
  let changed = 0;
  transform(chunk, {
    expr(e) {
      if (e.type !== 'Name') return undefined;
      const v = info.varOf.get(e);
      if (!v || v.isGlobal || v.kind !== 'local' || v.hasInit || v.writes.length || !v.init || v.init.type !== 'Nil' || !isMachineName(v.name)) return undefined;
      changed++;
      return { type: 'Nil' };
    },
  });
  return { changed };
}

const isLiteral = (e) => e.type === 'Number' || e.type === 'String' || (e.type === 'Unary' && e.op === '-' && e.arg.type === 'Number');

export function orientComparisons(chunk) {
  let changed = 0;
  transform(chunk, {
    expr(e) {
      if (e.type === 'Binary' && (e.op === '<' || e.op === '<=') && isLiteral(e.left) && !isLiteral(e.right)) {
        changed++;
        return { ...e, op: e.op === '<' ? '>' : '>=', left: e.right, right: e.left };
      }
      return undefined;
    },
  });
  return { changed };
}

/** The dotted path `a.b.c` as a list of names, or null if the expression is anything else. */
function dottedPath(e) {
  const parts = [];
  for (let n = e; ; n = n.obj) {
    if (n.type === 'Name') { parts.push(n.name); return parts.reverse(); }
    if (n.type !== 'Index' || n.key.type !== 'String' || !isIdentifier(n.key.value)) return null;
    parts.push(n.key.value);
  }
}

const mentions = (node, name) => {
  let found = false;
  walk(node, (n) => {
    if (found) return false;
    if ((n.type === 'Name' || n.type === 'Id') && n.name === name) found = true;
    return undefined;
  });
  return found;
};

/** `v = a` followed by `if not v then v = b end` is `v = a or b`; the test reads the variable that was just set. */
export function shortCircuits(chunk) {
  let changed = 0;
  transform(chunk, {
    block(stmts) {
      const out = [];
      for (let i = 0; i < stmts.length; i++) {
        const s = stmts[i];
        const next = stmts[i + 1];
        let name = null;
        let value = null;
        if (s.type === 'Assign' && s.targets.length === 1 && s.values.length === 1 && s.targets[0].type === 'Name') { name = s.targets[0].name; value = s.values[0]; }
        else if (s.type === 'Local' && s.ids.length === 1 && s.values.length === 1 && !s.ids[0].attrib) { name = s.ids[0].name; value = s.values[0]; }
        if (name && next && next.type === 'If' && next.clauses.length === 1 && !next.orelse && next.clauses[0].body.length === 1) {
          const { cond, body } = next.clauses[0];
          const set = body[0];
          // the test reads the variable that was set, or the variable it was set from (`v = c  if c then v = e end`)
          const copiedFrom = value.type === 'Name' ? value.name : null;
          const testsIt = (n) => n && n.type === 'Name' && (n.name === name || (copiedFrom !== null && n.name === copiedFrom));
          const negated = cond.type === 'Unary' && cond.op === 'not' && testsIt(cond.arg);
          const plain = testsIt(cond);
          if ((negated || plain) && set.type === 'Assign' && set.targets.length === 1 && set.values.length === 1
            && set.targets[0].type === 'Name' && set.targets[0].name === name && !mentions(set.values[0], name)
            && !(set.values[0].type === 'Vararg')) {
            const joined = { type: 'Binary', op: negated ? 'or' : 'and', left: value.type === 'Binary' && (value.op === 'and' || value.op === 'or') ? { type: 'Paren', expr: value } : value, right: set.values[0] };
            const merged = s.type === 'Assign' ? { ...s, values: [joined] } : { ...s, values: [joined] };
            out.push(merged);
            i++;
            changed++;
            continue;
          }
        }
        out.push(s);
      }
      return changed ? out : undefined;
    },
  });
  return { changed };
}


// ---- loops ---------------------------------------------------------------------------------------------------------

const isBreakGuard = (s) => s && s.type === 'If' && s.clauses.length === 1 && !s.orelse && s.clauses[0].body.length === 1 && s.clauses[0].body[0].type === 'Break';
const unparen = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const num = (value) => ({ type: 'Number', value, raw: null });

function hasJump(body) {
  let found = false;
  walk(body, (n) => { if (n.type === 'Func') return false; if (n.type === 'Continue' || n.type === 'Goto' || n.type === 'Label') found = true; return undefined; });
  return found;
}

/** `while true do if c then break end ... end` is `while not c do ... end`; a break test as the last statement makes it `repeat ... until c`. */
export function loopForms(chunk) {
  let changed = 0;
  const info = analyze(chunk);
  // `local done = e  until done`: the flag is only there to carry the test
  const inlineFlag = (body, cond) => {
    const c = unparen(cond);
    const prev = body[body.length - 1];
    if (c.type === 'Name' && prev && prev.type === 'Local' && prev.ids.length === 1 && prev.values.length === 1) {
      const fv = info.varOf.get(prev.ids[0]);
      if (fv && fv === info.varOf.get(c) && fv.reads.length === 1 && fv.writes.length === 0) return { body: body.slice(0, -1), cond: prev.values[0] };
    }
    return { body, cond };
  };
  transform(chunk, {
    stmt(s) {
      if (s.type === 'Repeat') {
        const r = inlineFlag(s.body, s.cond);
        if (r.cond === s.cond) return undefined;
        changed++;
        return { ...s, body: r.body, cond: r.cond };
      }
      if (s.type !== 'While' || unparen(s.cond).type !== 'True') return undefined;
      const first = s.body[0];
      if (isBreakGuard(first)) {
        changed++;
        return { ...s, cond: negateCondition(first.clauses[0].cond), body: s.body.slice(1) };
      }
      const last = s.body[s.body.length - 1];
      if (isBreakGuard(last) && s.body.length > 1 && !hasJump(s.body)) {
        changed++;
        const r = inlineFlag(s.body.slice(0, -1), last.clauses[0].cond);
        return { type: 'Repeat', body: r.body, cond: r.cond, comments: s.comments, line: s.line, blankBefore: s.blankBefore };
      }
      return undefined;
    },
  });
  return { changed };
}

/**
 * A `for` loop through a register machine: the counter is stepped, compared with the limit and the loop left when it is past.
 * Read back into `for i = a, b, k do`, as long as nothing outside the loop looks at the counter and the limit stays put.
 */
export function numericLoops(chunk) {
  let changed = 0;
  for (let round = 0; round < 64; round++) {
    const info = analyze(chunk);
    let done = false;
    transform(chunk, {
      block(stmts) {
        if (done) return undefined;
        for (let i = 0; i < stmts.length; i++) {
          const rewritten = tryNumericLoop(stmts, i, info);
          if (rewritten) { done = true; changed++; return rewritten; }
        }
        return undefined;
      },
    });
    if (!done) break;
  }
  return { changed };
}

/** The statement list with the loop at `at` written as a `for`, or null. */
function tryNumericLoop(stmts, at, info) {
  const loop = stmts[at];
  if (loop.type !== 'While' || unparen(loop.cond).type !== 'True' || loop.body.length < 3 || hasJump(loop.body)) return null;
  const v = (n) => (n && n.type === 'Name' ? info.varOf.get(n) : null);
  const loopNodes = new Set();
  walk(loop, (n) => { loopNodes.add(n); });

  // 1. the step: `c = c + k`, or `local n = c + k  c = n` (n is then the loop variable)
  const stepOf = (e, c) => {
    const x = unparen(e);
    if (x.type !== 'Binary' || (x.op !== '+' && x.op !== '-')) return null;
    const l = unparen(x.left);
    const r = unparen(x.right);
    if (v(l) === c && r.type === 'Number' && r.value !== 0) return x.op === '+' ? r.value : -r.value;
    if (x.op === '+' && v(r) === c && l.type === 'Number' && l.value !== 0) return l.value;
    return null;
  };
  const first = loop.body[0];
  let counter = null;
  let loopVar = null;
  let k = null;
  let used = 0;
  if (first.type === 'Assign' && first.targets.length === 1 && first.values.length === 1 && first.targets[0].type === 'Name') {
    counter = v(first.targets[0]);
    k = counter ? stepOf(first.values[0], counter) : null;
    loopVar = counter;
    used = 1;
  } else if (first.type === 'Local' && first.ids.length === 1 && first.values.length === 1) {
    const second = loop.body[1];
    if (!second || second.type !== 'Assign' || second.targets.length !== 1 || second.values.length !== 1 || second.targets[0].type !== 'Name') return null;
    counter = v(second.targets[0]);
    loopVar = info.varOf.get(first.ids[0]);
    if (!counter || !loopVar || v(unparen(second.values[0])) !== loopVar || loopVar.writes.length) return null;
    k = stepOf(first.values[0], counter);
    used = 2;
  } else return null;
  if (!counter || counter.isGlobal || !loopVar || !k || !Number.isFinite(k)) return null;

  // 2. the comparison locals, then `if not (i <= limit) then break end`
  const flags = new Map();                       // Var -> its comparison
  let j = used;
  for (; j < loop.body.length; j++) {
    const st = loop.body[j];
    if (st.type !== 'Local' || st.ids.length !== 1 || st.values.length !== 1) break;
    const cmp = unparen(st.values[0]);
    if (cmp.type !== 'Binary' || !COMPARISON.has(cmp.op)) break;
    flags.set(info.varOf.get(st.ids[0]), cmp);
  }
  const guard = loop.body[j];
  if (!isBreakGuard(guard)) return null;
  let cond = unparen(guard.clauses[0].cond);
  if (cond.type !== 'Unary' || cond.op !== 'not') return null;
  cond = unparen(cond.arg);
  if (cond.type === 'Name' && flags.has(v(cond))) cond = flags.get(v(cond));
  if (cond.type !== 'Binary') return null;
  // the test, read as `loopVar <= limit` when counting up and `loopVar >= limit` when counting down
  const left = unparen(cond.left);
  const right = unparen(cond.right);
  let limit = null;
  let op = null;
  if (v(left) === loopVar) { limit = right; op = cond.op; }
  else if (v(right) === loopVar) { limit = left; op = { '<=': '>=', '>=': '<=', '<': '>', '>': '<' }[cond.op]; }
  if (!limit || !((k > 0 && op === '<=') || (k < 0 && op === '>='))) return null;
  const body = loop.body.slice(j + 1);

  // 3. nothing else may look at the flags or the counter, and the limit has to stay where it is
  for (const [fv] of flags) if (fv.reads.some((r) => !loopNodes.has(r) || body.some((st) => { let hit = false; walk(st, (n) => { if (n === r) hit = true; }); return hit; }))) return null;
  const limitVar = limit.type === 'Name' ? v(limit) : null;
  if (!(limit.type === 'Number' || (limitVar && !limitVar.isGlobal && limitVar.writes.every((w) => !loopNodes.has(w))))) return null;
  let initIndex = -1;
  for (let q = at - 1; q >= Math.max(0, at - 3) && initIndex < 0; q--) {
    const st = stmts[q];
    const set = st.type === 'Local' ? [st.ids[0] && info.varOf.get(st.ids[0]), st.values[0]] : st.type === 'Assign' && st.targets[0].type === 'Name' ? [info.varOf.get(st.targets[0]), st.values[0]] : null;
    if (set && set[0] === counter && (st.values || []).length === 1 && unparen(set[1]).type === 'Number' && (st.type === 'Assign' ? st.targets.length === 1 : st.ids.length === 1)) initIndex = q;
  }
  if (initIndex < 0) return null;
  const init = stmts[initIndex];
  const outsideWrites = counter.writes.filter((w) => !loopNodes.has(w)).length;
  if (outsideWrites !== (init.type === 'Assign' ? 1 : 0)) return null;
  if (counter.writes.filter((w) => loopNodes.has(w)).length !== 1) return null;
  if (counter.reads.some((r) => !loopNodes.has(r))) return null;
  if (loopVar !== counter && counter.reads.length !== 1) return null;

  // 4. a limit held in a register that nothing else reads is the limit expression itself
  let stopExpr = limit;
  let dropIndex = -1;
  if (limitVar && limitVar.hasInit && limitVar.writes.length === 0 && limitVar.reads.length === 1) {
    for (let q = initIndex - 1; q >= Math.max(0, initIndex - 2); q--) {
      const st = stmts[q];
      if (st.type === 'Local' && st.ids.length === 1 && st.values.length === 1 && info.varOf.get(st.ids[0]) === limitVar && stmts.slice(q + 1, at).every((x) => x === init)) { stopExpr = st.values[0]; dropIndex = q; break; }
    }
  }

  const header = {
    type: 'NumFor',
    id: { type: 'Id', name: loopVar.name },
    start: num(unparen(init.values[0]).value + k),
    stop: stopExpr,
    step: k === 1 ? null : num(k),
    body,
    comments: loop.comments, line: loop.line, blankBefore: loop.blankBefore,
  };
  return stmts.flatMap((st, q) => (q === initIndex || q === dropIndex ? [] : [q === at ? header : st]));
}

/**
 * A call that yields several values is wrapped by a register machine as `unpack({ f(x) })`, which says what `f(x)` says. The
 * wrapper is removed wherever the call stands for all of its results already.
 */
export function multiResults(chunk) {
  const info = analyze(chunk);
  let changed = 0;
  const isUnpack = (fn) => {
    if (fn.type === 'Name') { const v = info.varOf.get(fn); return fn.name === 'unpack' && v && v.isGlobal && v.writes.length === 0; }
    return fn.type === 'Index' && fn.obj.type === 'Name' && fn.obj.name === 'table' && fn.key.type === 'String' && fn.key.value === 'unpack' && !!info.varOf.get(fn.obj) && info.varOf.get(fn.obj).isGlobal;
  };
  transform(chunk, {
    expr(e) {
      if (e.type !== 'Call' || !isUnpack(e.fn) || e.args.length !== 1) return undefined;
      const t = e.args[0];
      if (t.type !== 'Table' || t.fields.length !== 1 || t.fields[0].kind !== 'item') return undefined;
      const inner = t.fields[0].value;
      if (inner.type !== 'Call' && inner.type !== 'MethodCall') return undefined;
      changed++;
      return inner;
    },
  });
  return { changed };
}

export function functionForms(chunk) {
  let changed = 0;
  const info = analyze(chunk);
  const methodNames = new Set();
  walk(chunk, (n) => { if (n.type === 'MethodCall') methodNames.add(n.name); });

  transform(chunk, {
    stmt(s) {
      if (s.type === 'Assign' && s.targets.length === 1 && s.values.length === 1 && s.values[0].type === 'Func' && s.targets[0].type === 'Index') {
        const target = s.targets[0];
        const func = s.values[0];
        if (!dottedPath(target)) return undefined;
        changed++;
        const key = target.key.value;
        const param = func.params[0];
        const asMethod = !func.isMethod && param && methodNames.has(key) && !mentions(func.body, 'self') && !func.params.some((p) => p.name === 'self');
        if (!asMethod) return { type: 'Function', target, method: null, func, comments: s.comments };
        const v = info.varOf.get(param);
        if (v) { for (const r of v.reads) r.name = 'self'; for (const w of v.writes) w.name = 'self'; }
        func.params = func.params.slice(1);
        func.isMethod = true;
        // `param, param1, param2` lost its first entry: close the gap so the numbering starts over
        for (const p of func.params) {
          const m = /^param(\d+)$/.exec(p.name);
          const pv = info.varOf.get(p);
          if (!m || !pv) continue;
          const next = m[1] === '1' ? 'param' : `param${Number(m[1]) - 1}`;
          if (func.params.some((q) => q.name === next) || mentions(func, next)) continue;
          p.name = next;
          for (const r of pv.reads) r.name = next;
          for (const w of pv.writes) w.name = next;
        }
        return { type: 'Function', target: target.obj, method: key, func, comments: s.comments };
      }
      if (s.type === 'Local' && s.ids.length === 1 && s.values.length === 1 && s.values[0].type === 'Func' && !s.ids[0].attrib
        && isIdentifier(s.ids[0].name) && !mentions(s.values[0], s.ids[0].name)) {
        changed++;
        return { type: 'LocalFunction', id: s.ids[0], func: s.values[0], comments: s.comments };
      }
      return undefined;
    },
  });
  return { changed };
}
