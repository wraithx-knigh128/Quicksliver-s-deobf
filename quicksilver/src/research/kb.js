// The knowledge base: what the experiments established, derived by rules, never written by hand.
//
// `aggregate` turns experiment records into counts per (transformation, plan) and per (observed signature, plan). `deriveDiscoveries` turns those counts into
// statements, each carrying the rule that produced it and the numbers behind it:
//
//   works     plan P verified-recovers or verified-partially-recovers transformation T in at least 70% of trials, 95% interval lower bound included
//   fails     the upper bound of that rate is at most 25%
//   harms     P left the result further from the original than the input was in at least half the trials (lower bound above 30%)
//   needs-sandbox   a plan with the sandbox off fails and the same plan with it on works
//   improves  one plan beats another on the same input by non-overlapping intervals
//
// A statement needs at least MIN_TRIALS trials. With fewer it is not made at all, so a small experiment cannot produce a "finding". Statements
// from outside sources (sources.json) are kept apart, graded, and never promoted to discoveries: only an experiment can do that.

import { wilson, isSuccess, VERDICTS } from './judge.js';
import { isIndicator } from './signature.js';

export const MIN_TRIALS = 12;

export const signatureKey = (tokens) => tokens.filter(isIndicator).sort().join(' ') || 'clean';

function cell() { return { n: 0, verdicts: Object.fromEntries(VERDICTS.map((v) => [v, 0])), fidelityBefore: 0, fidelityAfter: 0, scored: 0 }; }
function add(c, r) {
  c.n++;
  c.verdicts[r.verdict]++;
  if (typeof r.fidelityAfter === 'number') { c.scored++; c.fidelityBefore += r.fidelityBefore; c.fidelityAfter += r.fidelityAfter; }
}
function finish(c) {
  const success = c.verdicts['verified-recovery'] + c.verdicts['verified-partial'];
  const w = wilson(success, c.n);
  const round = (x) => Math.round(x * 1000) / 1000;
  return {
    n: c.n, success, recovery: c.verdicts['verified-recovery'], partial: c.verdicts['verified-partial'], worse: c.verdicts['behaviour-kept-worse'],
    noGain: c.verdicts['behaviour-kept-no-gain'], failed: c.verdicts['failed-behaviour'] + c.verdicts['failed-parse'] + c.verdicts.error, inconclusive: c.verdicts.inconclusive,
    rate: round(w.p), lo: round(w.lo), hi: round(w.hi),
    fidelityBefore: c.scored ? round(c.fidelityBefore / c.scored) : null, fidelityAfter: c.scored ? round(c.fidelityAfter / c.scored) : null,
  };
}

/** @param {object[]} experiments records from tools/lab/run.mjs */
export function aggregate(experiments) {
  const valid = experiments.filter((r) => r.verdict !== 'tool-broken');
  const byTP = new Map();
  const bySP = new Map();
  const sigTokens = new Map();
  const defects = [];
  for (const r of valid) {
    const t = byTP.get(r.transform.id) || byTP.set(r.transform.id, new Map()).get(r.transform.id);
    add(t.get(r.plan.id) || t.set(r.plan.id, cell()).get(r.plan.id), r);
    const key = signatureKey(r.observed || []);
    sigTokens.set(key, key === 'clean' ? [] : key.split(' '));
    const s = bySP.get(key) || bySP.set(key, new Map()).get(key);
    add(s.get(r.plan.id) || s.set(r.plan.id, cell()).get(r.plan.id), r);
    if (['failed-behaviour', 'failed-parse', 'error'].includes(r.verdict)) defects.push({ id: r.id, verdict: r.verdict, transform: r.transform.id, plan: r.plan.id, programSeed: r.program.seed, difference: r.difference || null, error: r.error || null });
  }
  const out = (m) => Object.fromEntries([...m].map(([k, v]) => [k, Object.fromEntries([...v].map(([p, c]) => [p, finish(c)]))]));
  return {
    counts: { experiments: experiments.length, valid: valid.length, toolBroken: experiments.length - valid.length, transforms: byTP.size, signatures: bySP.size },
    byTransformPlan: out(byTP),
    bySignaturePlan: Object.fromEntries([...bySP].map(([k, v]) => [k, { tokens: sigTokens.get(k), plans: Object.fromEntries([...v].map(([p, c]) => [p, finish(c)])) }])),
    defects,
  };
}

const pct = (x) => `${Math.round(x * 100)}%`;
const frac = (c) => `${c.success}/${c.n}`;

/** Statements the experiments support, each with its rule and numbers. */
export function deriveDiscoveries(agg, { labels = {} } = {}) {
  const out = [];
  const name = (t) => labels[t] || t;
  for (const [t, plans] of Object.entries(agg.byTransformPlan)) {
    for (const [p, c] of Object.entries(plans)) {
      if (c.n < MIN_TRIALS) continue;
      const base = { transform: t, plan: p, trials: c.n, evidence: { success: c.success, recovery: c.recovery, partial: c.partial, worse: c.worse, interval: [c.lo, c.hi] } };
      if (c.success / c.n >= 0.7 && c.lo >= 0.6) out.push({ id: `works:${t}:${p}`, kind: 'works', rule: 'success rate at least 70% with interval lower bound at least 60%', statement: `${p} recovers "${name(t)}": ${frac(c)} verified (${c.recovery} to near-original), ${pct(c.lo)}–${pct(c.hi)} at 95%.`, ...base });
      else if (c.hi <= 0.25) out.push({ id: `fails:${t}:${p}`, kind: 'fails', rule: 'interval upper bound at most 25%', statement: `${p} does not recover "${name(t)}": ${frac(c)} verified.`, ...base });
      if (c.worse / c.n >= 0.5 && wilson(c.worse, c.n).lo >= 0.3) out.push({ id: `harms:${t}:${p}`, kind: 'harms', rule: 'result further from the original than the input in at least half the trials', statement: `${p} makes "${name(t)}" input worse in ${c.worse}/${c.n} trials: behaviour is kept, structure is lost.`, ...base });
    }
    for (const base of ['generic', 'adaptive', 'nexus']) {
      const on = plans[`${base}+sandbox`] || (base === 'adaptive' || base === 'nexus' ? plans[`${base}+sandbox`] : null);
      const off = plans[base];
      if (!on || !off || on.n < MIN_TRIALS || off.n < MIN_TRIALS) continue;
      if (off.hi <= 0.25 && on.lo >= 0.6) out.push({ id: `needs-sandbox:${t}:${base}`, kind: 'needs-sandbox', transform: t, plan: base, trials: off.n, rule: 'plan fails with the sandbox off and works with it on', statement: `"${name(t)}" needs the sandbox: ${base} ${frac(off)} without it, ${frac(on)} with it.`, evidence: { off: frac(off), on: frac(on) } });
    }
    const list = Object.entries(plans).filter(([, c]) => c.n >= MIN_TRIALS);
    for (const [a, ca] of list) for (const [b, cb] of list) {
      if (a >= b || (ca.lo <= cb.hi && cb.lo <= ca.hi)) continue;
      const [win, lose, cw, cl] = ca.lo > cb.hi ? [a, b, ca, cb] : [b, a, cb, ca];
      if (win.includes('+sandbox') !== lose.includes('+sandbox')) continue;      // sandbox differences have their own statement
      out.push({ id: `improves:${t}:${win}>${lose}`, kind: 'improves', transform: t, plan: win, trials: Math.min(ca.n, cb.n), rule: 'non-overlapping 95% intervals', statement: `On "${name(t)}", ${win} (${frac(cw)}) beats ${lose} (${frac(cl)}).`, evidence: { winner: frac(cw), loser: frac(cl) } });
    }
  }
  return out;
}

/** Transformations no plan handles: where the next technique is needed. */
export function gaps(agg) {
  const out = [];
  for (const [t, plans] of Object.entries(agg.byTransformPlan)) {
    const cells = Object.values(plans).filter((c) => c.n >= MIN_TRIALS);
    if (cells.length && cells.every((c) => c.hi <= 0.5)) out.push({ transform: t, best: Math.max(...cells.map((c) => c.rate)), plans: Object.keys(plans) });
  }
  return out;
}
