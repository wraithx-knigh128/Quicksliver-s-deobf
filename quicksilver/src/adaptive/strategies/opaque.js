// Opaque predicates: branches whose outcome arithmetic fixes, whatever the program does (see absval.js for what counts as proof).
//
// Each decided condition in an `if`, `elseif`, `while`, `repeat ... until` or `a and b or c` position is replaced by `true` / `false`;
// the clean-up that follows (the `simplify` strategy) then drops the branch that cannot run and unwraps the one that always does.

import { walk } from '../../core/walk.js';
import { opaqueContext, constantCondition } from '../absval.js';
import { lineOf } from '../util.js';

const isLiteralBool = (e) => e.type === 'True' || e.type === 'False' || e.type === 'Nil';

/** Conditions of the chunk that a proof decides, in source order. */
function decided(ast, an) {
  const oc = opaqueContext(ast, an);
  const found = [];
  const test = (owner, key, cond) => {
    if (!cond || isLiteralBool(cond) || cond.type === 'Number' || cond.type === 'String') return;
    const r = constantCondition(cond, oc);
    if (!r) return;
    // a condition that is only constant because of a readable name (a debug flag, say) is the author's switch, not a disguise
    if (r.why === 'constant' && r.names && [...r.names].some((nm) => !an.machine(nm))) return;
    found.push({ owner, key, cond, value: r.value, why: r.why, line: lineOf(cond) || lineOf(owner) });
  };
  walk(ast, (n) => {
    if (n.type === 'If') n.clauses.forEach((c) => test(c, 'cond', c.cond));
    else if (n.type === 'While' || n.type === 'Repeat') test(n, 'cond', n.cond);
    else if (n.type === 'IfExpr') test(n, 'cond', n.cond);
    return undefined;
  });
  return found;
}

export const opaque = {
  id: 'opaque.resolve',
  title: 'Decide opaque predicates by proof',
  order: 30,

  observe(ast, an) {
    return decided(ast, an).map((d) => ({
      kind: 'opaque-predicate',
      line: d.line,
      label: `a condition that is always ${d.value ? 'true' : 'false'}`,
      evidence: [`proved by ${d.why === 'constant' ? 'evaluating constants' : d.why === 'identity' ? 'comparing an expression with itself' : d.why === 'interval' ? 'the ranges of its operands' : 'checking every residue of its operands'}`],
      confidence: d.why === 'constant' ? 0.99 : 0.95,
      weight: 1,
    }));
  },

  run(ast, ctx) {
    let changed = 0;
    const an = ctx.analyse();
    const list = decided(ast, an);
    const notes = [];
    for (const d of list) {
      d.owner[d.key] = { type: d.value ? 'True' : 'False' };
      changed++;
      notes.push({ line: d.line, text: `${d.value} (${d.why})` });
    }
    return { changed, decided: notes };
  },
};
