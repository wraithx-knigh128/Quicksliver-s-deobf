// Which local variables can only ever hold a number?
//
// A variable that is written with number literals and arithmetic over other such variables stays a number whatever the
// rest of the program does, because numbers carry no metatable. Comparing or adding two of them cannot call anything or
// fail, so a dead store of the result may go. Recovered loop counters are the usual case: the compiler of a flattened VM
// computes both directions of the loop test on every pass and keeps whichever one applies.

import { walk } from '../core/walk.js';

const ARITH = new Set(['+', '-', '*', '/', '^']);
const COMPARE = new Set(['<', '<=', '>', '>=']);

export const isArithmetic = (op) => ARITH.has(op);
export const isComparison = (op) => COMPARE.has(op);

/** Is the expression a number, given the variables known to be? */
export function numericExpr(e, info) {
  switch (e.type) {
    case 'Number': return true;
    case 'Paren': return numericExpr(e.expr, info);
    case 'Name': { const v = info.varOf.get(e); return !!v && !!info.numeric && info.numeric.has(v); }
    case 'Unary': return e.op === '-' && numericExpr(e.arg, info);
    case 'Binary':
      if (ARITH.has(e.op)) return numericExpr(e.left, info) && numericExpr(e.right, info);
      if ((e.op === '%' || e.op === '//') && e.right.type === 'Number' && e.right.value !== 0) return numericExpr(e.left, info);
      return false;
    default: return false;
  }
}

/** The set of variables whose every assignment is a number. */
export function numericVars(chunk, info) {
  const writes = new Map();          // Var -> expressions assigned, or null when something else is
  const note = (id, e) => {
    const v = info.varOf.get(id);
    if (!v || v.isGlobal) return;
    const list = writes.get(v);
    if (list === null) return;
    if (e === null) { writes.set(v, null); return; }
    if (list) list.push(e); else writes.set(v, [e]);
  };
  const spreads = (values) => { const last = values[values.length - 1]; return !!last && (last.type === 'Call' || last.type === 'MethodCall' || last.type === 'Vararg'); };

  walk(chunk, (n) => {
    switch (n.type) {
      case 'Local': {
        const many = spreads(n.values);
        n.ids.forEach((id, i) => note(id, i < n.values.length && !(many && i >= n.values.length - 1) ? n.values[i] : null));
        break;
      }
      case 'Assign': {
        const many = spreads(n.values);
        n.targets.forEach((t, i) => { if (t.type === 'Name') note(t, i < n.values.length && !(many && i >= n.values.length - 1) ? n.values[i] : null); });
        break;
      }
      case 'CompoundAssign': if (n.target.type === 'Name') note(n.target, null); break;
      case 'NumFor': info.varOf.get(n.id) && writes.set(info.varOf.get(n.id), [{ type: 'Number', value: 0 }]); break;
      case 'GenFor': n.ids.forEach((id) => note(id, null)); break;
      case 'LocalFunction': note(n.id, null); break;
      case 'Function': if (n.target.type === 'Name') note(n.target, null); break;
      case 'Func': n.params.forEach((p) => note(p, null)); break;
      default: break;
    }
    return undefined;
  });

  const set = new Set();
  for (const [v, list] of writes) if (list) set.add(v);
  info.numeric = set;
  for (let again = true; again;) {
    again = false;
    for (const v of [...set]) if (!writes.get(v).every((e) => numericExpr(e, info))) { set.delete(v); again = true; }
  }
  return set;
}
