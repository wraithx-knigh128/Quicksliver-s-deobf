// NEXUS · Confidence and Verification Engine.
//
// The older confidence score is derived from what is still visible in the output. It does not say which statements about the result were
// *checked* and which were *concluded*. This ledger does: every claim NEXUS makes goes in with one of three states.
//
//   verified    a check ran and passed (the claim is as strong as the check, and the check is named)
//   inferred    a rule reached it from evidence; it may be wrong (the evidence is listed)
//   unresolved  something the engine could see and did not or could not settle (the reason is listed)
//
// plus `inconsistent` for a check that ran and failed. Nothing is ever promoted: a name chosen by a rule stays "inferred" however many
// rules agree, and only a check can make a claim "verified". The level reported at the end can never be higher than the existing score allows,
// and an inconsistency or an unresolved dependency lowers it.

import { analyze } from '../core/scope.js';
import { parse } from '../core/parser.js';
import { structuralKey, clone } from '../core/walk.js';

export class Ledger {
  constructor() { this.claims = []; }

  add(state, id, statement, evidence = [], extra = {}) {
    this.claims.push({ state, id, statement, evidence: [].concat(evidence), ...extra });
    return this;
  }
  verified(id, statement, check, evidence = []) { return this.add('verified', id, statement, evidence, { check }); }
  inferred(id, statement, evidence = [], confidence = null) { return this.add('inferred', id, statement, evidence, confidence == null ? {} : { confidence }); }
  unresolved(id, statement, evidence = []) { return this.add('unresolved', id, statement, evidence); }
  inconsistent(id, statement, evidence = []) { return this.add('inconsistent', id, statement, evidence); }

  count(state) { return this.claims.filter((c) => c.state === state).length; }
  get(state) { return this.claims.filter((c) => c.state === state); }

  summary() {
    return { verified: this.count('verified'), inferred: this.count('inferred'), unresolved: this.count('unresolved'), inconsistent: this.count('inconsistent') };
  }

  /**
   * The level NEXUS stands behind: the older score's level, lowered by what the ledger holds.
   * @param {{score: number, level: string}} base the score from recover/confidence.js
   */
  level(base) {
    const order = ['none', 'minimal', 'low', 'medium', 'high'];
    let i = Math.max(0, order.indexOf(base.level));
    const reasons = [];
    if (this.count('inconsistent')) { i = Math.min(i, 1); reasons.push('a check failed'); }
    else if (this.count('unresolved') && i === 4) { i = 3; reasons.push('something it saw is not settled'); }
    return { level: order[i], score: Math.min(base.score, [0, 0.25, 0.6, 0.84, 1][i]), lowered: reasons };
  }
}

// ---- checks ---------------------------------------------------------------------------------------------------------------------------
/** Free names a program reads or writes (globals), as a set. */
export function freeNames(source) {
  try { return new Set(analyze(parse(source)).globals.keys()); } catch { return null; }
}

/** Do two texts hold the same program (same syntax tree once layout and comments are ignored)? */
export function sameTree(a, b) {
  try { return structuralKey(parse(a)) === structuralKey(parse(b)); } catch { return false; }
}

/** Names the output reads or writes as globals that the input did not use. Empty means the recovery made up no external dependency. */
export function newGlobals(input, output) {
  const a = freeNames(input);
  const b = freeNames(output);
  if (!a || !b) return null;
  return [...b].filter((n) => !a.has(n)).sort();
}

/** Globals the input used that the output no longer mentions (expected when a decoder is spent; reported so a person can see them). */
export function droppedGlobals(input, output) {
  const a = freeNames(input);
  const b = freeNames(output);
  if (!a || !b) return null;
  return [...a].filter((n) => !b.has(n)).sort();
}

/**
 * The program with every local variable's name replaced by the number of its declaration. Two programs with the same key differ at most
 * in the names of their locals: every use is bound to the declaration at the same place. That is what renaming is allowed to change, and
 * it is the check that catches a renamed variable capturing or shadowing another.
 */
export function bindingKey(chunk) {
  const copy = clone(chunk);
  const info = analyze(copy);
  info.vars.forEach((v, i) => {
    const tag = `\u0000L${i}`;
    if (v.decl) v.decl.name = tag;
    for (const r of v.reads) r.name = tag;
    for (const w of v.writes) w.name = tag;
  });
  return structuralKey(copy);
}

/** Do two trees differ at most in the names of their local variables? */
export function sameBindings(a, b) {
  try { return bindingKey(a) === bindingKey(b); } catch { return false; }
}
