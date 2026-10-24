// Idioms of decompiled code.
//
// A compiler spreads some everyday constructs over several instructions, and the decompiler gives them back as
// the statements those instructions are. These passes write them the way a person would. Each one is exact: the
// rewritten program does the same thing, so none of them needs a sandbox or a guess.
//
//   booleanResults      `if a < b then v = true else v = false end return v`  ->  `return a < b`
//   shortCircuits       `v = a  if not v then v = b end`  ->  `v = a or b`   (and `if v then v = b end` -> `v = a and b`)
//   tableConstructors   `local t = {}  t.a = 1  t.b = 2`  ->  `local t = { a = 1, b = 2 }`
//   bareNils            `local x = nil`  ->  `local x`
//   orientComparisons   `0 < n`  ->  `n > 0`   (the compiler swaps the operands of `>` and `>=`)
//   functionForms       `T.f = function(...)`  ->  `function T.f(...)`,  `T.f = function(p, ...)`  ->  `function T:f(...)`
//                       when the script calls `:f(`,  `local f = function` -> `local function f`
//
// They run on the output of the bytecode decompiler only. A script somebody wrote by hand keeps its own style.

import { transform, walk } from '../core/walk.js';
import { analyze } from '../core/scope.js';
import { isIdentifier } from '../core/printer.js';
import { negateCondition } from './structure.js';

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
        for (; j < stmts.length; j++) {
          const a = stmts[j];
          if (a.type !== 'Assign' || a.targets.length !== 1 || a.values.length !== 1 || a.comments?.length) break;
          const t = a.targets[0];
          if (t.type !== 'Index' || t.obj.type !== 'Name' || t.obj.name !== name || t.key.type !== 'String' || !isIdentifier(t.key.value)) break;
          if (seen.has(t.key.value) || mentions(a.values[0], name) || (captured && !isInert(a.values[0]))) break;
          seen.add(t.key.value);
          fields.push({ kind: 'named', key: t.key.value, value: a.values[0] });
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
          const negated = cond.type === 'Unary' && cond.op === 'not' && cond.arg.type === 'Name' && cond.arg.name === name;
          const plain = cond.type === 'Name' && cond.name === name;
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
