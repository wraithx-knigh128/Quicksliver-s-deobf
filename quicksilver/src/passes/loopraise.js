// Write loops that a dispatcher or a decompiler lowered to `while` as the `for` loops they were.
//
// Two lowerings are read, both of them what Lua's own `for` means written out by hand (a control-flow flattener that turns `for` into states, or a compiler
// that emits the loop's three hidden values as locals):
//
//   generic   it, st, ct = ipairs(t)                         for v, w in ipairs(t) do
//             while true do                                    <body>
//               v, w = it(st, ct)               ==>          end
//               if v == nil then break end
//               ct = v
//               <body>
//             end
//
//   numeric   i, lim, stp = a, b, c                          for i = a, b, c do
//             while stp > 0 and i <= lim or stp <= 0 and i >= lim do        <body>
//               <body>                          ==>        end
//               i = i + stp
//             end
//
// Nothing is guessed: the shape must match exactly, the hidden values must not be read or written by the body or anywhere after the loop, and the control
// variable must not be assigned in the body (a `for` variable is a fresh local each turn; assigning it would not change the count there, and the
// lowered loop would). A loop that fails any of these stays as it is.

import { walk, transform } from '../core/walk.js';

const nameOf = (e) => (e && e.type === 'Name' ? e.name : null);
const isNum = (e, v) => e && e.type === 'Number' && (v === undefined || e.value === v);
const idNode = (name) => ({ type: 'Id', name });

function mentions(nodes, names) {
  let hit = false;
  for (const n of nodes) walk(n, (x) => { if (hit) return false; if ((x.type === 'Name' || x.type === 'Id') && names.has(x.name)) hit = true; return undefined; });
  return hit;
}
function assigns(nodes, names) {
  let hit = false;
  for (const n of nodes) walk(n, (x) => { if (hit) return false; if (x.type === 'Assign' && x.targets.some((t) => t.type === 'Name' && names.has(t.name))) hit = true; if (x.type === 'CompoundAssign' && x.target.type === 'Name' && names.has(x.target.name)) hit = true; return undefined; });
  return hit;
}
const decl = (s) => (s.type === 'Assign' && s.targets.every((t) => t.type === 'Name') ? s.targets.map((t) => t.name) : s.type === 'Local' ? s.ids.map((i) => i.name) : null);
const declValues = (s) => s.values;

function generic(stmts, i) {
  const a = stmts[i];
  const w = stmts[i + 1];
  if (!w || w.type !== 'While' || w.cond.type !== 'True' || w.body.length < 3) return null;
  const hidden = decl(a);
  if (!hidden || hidden.length !== 3 || new Set(hidden).size !== 3) return null;
  const [it, st, ct] = hidden;
  const first = w.body[0];
  if (first.type !== 'Assign' || first.values.length !== 1 || first.values[0].type !== 'Call' || first.targets.some((t) => t.type !== 'Name')) return null;
  const call = first.values[0];
  if (nameOf(call.fn) !== it || call.args.length !== 2 || nameOf(call.args[0]) !== st || nameOf(call.args[1]) !== ct) return null;
  const vars = first.targets.map((t) => t.name);
  const test = w.body[1];
  if (test.type !== 'If' || test.clauses.length !== 1 || test.orelse) return null;
  const c = test.clauses[0];
  if (!(c.cond.type === 'Binary' && c.cond.op === '==' && nameOf(c.cond.left) === vars[0] && c.cond.right.type === 'Nil') || c.body.length !== 1 || c.body[0].type !== 'Break') return null;
  const step = w.body[2];
  if (!(step.type === 'Assign' && step.targets.length === 1 && nameOf(step.targets[0]) === ct && step.values.length === 1 && nameOf(step.values[0]) === vars[0])) return null;
  const body = w.body.slice(3);
  const hiddenSet = new Set(hidden);
  if (mentions(body, hiddenSet)) return null;
  if (assigns(body, new Set(vars))) return null;
  // what follows the loop must not read the hidden values or the loop variables (a for loop's variables end with it)
  const after = stmts.slice(i + 2);
  if (mentions(after, new Set([...hidden, ...vars]))) return null;
  const exprs = declValues(a);
  if (!exprs.length) return null;
  return { at: i, count: 2, node: { type: 'GenFor', ids: vars.map(idNode), exprs, body } };
}

function numeric(stmts, i) {
  const a = stmts[i];
  const w = stmts[i + 1];
  if (!w || w.type !== 'While' || w.body.length < 2) return null;
  const hidden = decl(a);
  if (!hidden || hidden.length !== 3 || new Set(hidden).size !== 3 || a.values.length !== 3) return null;
  const [ctr, lim, stp] = hidden;
  const cond = w.cond;
  // stp > 0 and ctr <= lim or stp <= 0 and ctr >= lim
  const bin = (e, op, l, r) => e && e.type === 'Binary' && e.op === op && nameOf(e.left) === l && (typeof r === 'string' ? nameOf(e.right) === r : isNum(e.right, r));
  const paren = (e) => (e && e.type === 'Paren' ? e.expr : e);
  const ok = cond.type === 'Binary' && cond.op === 'or'
    && paren(cond.left).type === 'Binary' && paren(cond.left).op === 'and' && bin(paren(paren(cond.left).left), '>', stp, 0) && bin(paren(paren(cond.left).right), '<=', ctr, lim)
    && paren(cond.right).type === 'Binary' && paren(cond.right).op === 'and' && bin(paren(paren(cond.right).left), '<=', stp, 0) && bin(paren(paren(cond.right).right), '>=', ctr, lim);
  if (!ok) return null;
  const last = w.body[w.body.length - 1];
  const inc = last.type === 'Assign' && last.targets.length === 1 && nameOf(last.targets[0]) === ctr && last.values.length === 1 && last.values[0].type === 'Binary' && last.values[0].op === '+'
    && nameOf(last.values[0].left) === ctr && nameOf(last.values[0].right) === stp;
  if (!inc) return null;
  const body = w.body.slice(0, -1);
  const hiddenSet = new Set(hidden);
  if (assigns(body, hiddenSet)) return null;
  if (mentions(body, new Set([lim, stp]))) return null;
  if (mentions(stmts.slice(i + 2), hiddenSet)) return null;
  const [start, stop, step] = a.values;
  const node = { type: 'NumFor', id: idNode(ctr), start, stop, step: isNum(step, 1) ? null : step, body };
  return { at: i, count: 2, node };
}

/** @returns {{changed: number, generic: number, numeric: number}} */
export function raiseLoops(chunk) {
  let g = 0;
  let n = 0;
  transform(chunk, {
    block(stmts) {
      let out = null;
      let work = stmts;
      for (let i = 0; i < work.length - 1; i++) {
        const m = generic(work, i) || numeric(work, i);
        if (!m) continue;
        if (!out) { out = work.slice(); work = out; }
        out.splice(m.at, m.count, m.node);
        if (m.node.type === 'GenFor') g++; else n++;
      }
      return out || undefined;
    },
  });
  return { changed: g + n, generic: g, numeric: n };
}
