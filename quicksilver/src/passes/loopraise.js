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

// The lowering Prometheus' Vmify produces (the iterator triple kept in a table, the control value doubling as the first loop variable):
//
//   local L = { ipairs(t) }                                  for v, w in ipairs(t) do
//   local c = L[3]   local s = L[2]   local f = L[1]          <body>
//   local w                                                 end
//   while true do
//     c, w = f(s, c)
//     if not c then break end          (or `c == nil`)
//     <body>
//   end
//
// `if not c` also stops on `false`, where a for loop would not; it is accepted only for iterators whose first value is never false
// (ipairs, gmatch). Any other iterator needs the exact `c == nil` test.
const NEVER_FALSE = /(^|\.|:)(ipairs|gmatch)$/;
function calleeText(e, stmts, before) {
  if (!e) return '';
  if (e.type === 'Name') {
    // a local alias such as `local gmatch = str.gmatch`
    for (let k = before - 1; k >= 0; k--) {
      const s = stmts[k];
      if (s.type === 'Local' && s.ids.length === 1 && s.ids[0].name === e.name && s.values.length === 1) {
        const v = s.values[0];
        if (v.type === 'Index' && v.key && v.key.type === 'String') return `${calleeText(v.obj, stmts, k)}.${v.key.value}`;
        return e.name;
      }
    }
    return e.name;
  }
  if (e.type === 'Index' && e.key && e.key.type === 'String') return `${calleeText(e.obj, stmts, before)}.${e.key.value}`;
  return '';
}
function genericTable(stmts, i) {
  const a = stmts[i];
  if (!a || a.type !== 'Local' || a.ids.length !== 1 || a.values.length !== 1) return null;
  const tbl = a.values[0];
  if (tbl.type !== 'Table' || tbl.fields.length !== 1 || tbl.fields[0].kind !== 'item' || !['Call', 'MethodCall'].includes(tbl.fields[0].value.type)) return null;
  const L = a.ids[0].name;
  const slot = {};
  let j = i + 1;
  for (; j < stmts.length && j <= i + 3; j++) {
    const s = stmts[j];
    if (s.type !== 'Local' || s.ids.length !== 1 || s.values.length !== 1) break;
    const v = s.values[0];
    if (v.type !== 'Index' || nameOf(v.obj) !== L || !isNum(v.key) || ![1, 2, 3].includes(v.key.value) || slot[v.key.value]) break;
    slot[v.key.value] = s.ids[0].name;
  }
  if (!slot[1] || !slot[2] || !slot[3]) return null;
  const extra = [];
  for (; j < stmts.length; j++) {
    const s = stmts[j];
    if (s.type === 'Local' && s.values.length === 0) { for (const id of s.ids) extra.push(id.name); continue; }
    break;
  }
  const w = stmts[j];
  if (!w || w.type !== 'While' || w.cond.type !== 'True' || w.body.length < 2) return null;
  const [it, st, ct] = [slot[1], slot[2], slot[3]];
  const first = w.body[0];
  if (first.type !== 'Assign' || first.values.length !== 1 || first.values[0].type !== 'Call' || first.targets.some((t) => t.type !== 'Name')) return null;
  const call = first.values[0];
  if (nameOf(call.fn) !== it || call.args.length !== 2 || nameOf(call.args[0]) !== st || nameOf(call.args[1]) !== ct) return null;
  const vars = first.targets.map((t) => t.name);
  if (vars[0] !== ct || vars.slice(1).some((v) => !extra.includes(v)) || new Set(vars).size !== vars.length) return null;
  const test = w.body[1];
  if (test.type !== 'If' || test.clauses.length !== 1 || test.orelse) return null;
  const c = test.clauses[0];
  if (c.body.length !== 1 || c.body[0].type !== 'Break') return null;
  const isNil = c.cond.type === 'Binary' && c.cond.op === '==' && nameOf(c.cond.left) === ct && c.cond.right.type === 'Nil';
  const isNot = c.cond.type === 'Unary' && c.cond.op === 'not' && nameOf(c.cond.arg) === ct;
  if (!isNil && !isNot) return null;
  const iter = tbl.fields[0].value;
  if (isNot && !NEVER_FALSE.test(iter.type === 'MethodCall' ? `:${iter.name}` : calleeText(iter.fn, stmts, i))) return null;
  const body = w.body.slice(2);
  if (mentions(body, new Set([L, it, st]))) return null;
  if (assigns(body, new Set(vars))) return null;
  const after = stmts.slice(j + 1);
  if (mentions(after, new Set([L, it, st, ct, ...extra]))) return null;
  // an extra declared but not a loop variable would lose its declaration
  if (extra.some((x) => !vars.includes(x))) return null;
  return { at: i, count: j - i + 1, node: { type: 'GenFor', ids: vars.map(idNode), exprs: [iter], body } };
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
        const m = generic(work, i) || genericTable(work, i) || numeric(work, i);
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
