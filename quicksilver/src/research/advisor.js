// The advisor: which reconstruction plan to try on this input, and why.
//
// It does not guess and it does not learn from anything but verified experiments. It looks at what the input shows from the outside (signature.js),
// finds the experiments whose transformed text showed the same (or, failing that, a similar) signature, and ranks the plans by how well they did there:
// the lower bound of the 95% interval of the verified-success rate, less a penalty for results that kept behaviour but lost structure. With too few
// matching trials it says so and falls back to the default plan; it never invents a preference.
//
// It runs in the page: data/research/summary.json is its whole memory. Running the laboratory again changes that file, and the advice changes with it.

import { PLANS, planById } from './plans.js';
import { signatureKey } from './kb.js';
import { wilson } from './judge.js';
import { isIndicator } from './signature.js';

export const DEFAULT_PLAN = 'nexus';
export const MIN_ADVICE_TRIALS = 8;

const jaccard = (a, b) => {
  const A = new Set(a);
  const B = new Set(b);
  const inter = [...A].filter((x) => B.has(x)).length;
  const union = new Set([...A, ...B]).size;
  return union ? inter / union : 1;
};

function pool(entries) {
  const total = {};
  for (const { plans } of entries) {
    for (const [p, c] of Object.entries(plans)) {
      const t = total[p] || (total[p] = { n: 0, success: 0, recovery: 0, partial: 0, worse: 0, failed: 0, fidelityAfter: 0, scored: 0 });
      t.n += c.n; t.success += c.success; t.recovery += c.recovery; t.partial += c.partial; t.worse += c.worse; t.failed += c.failed;
      if (c.fidelityAfter != null) { t.fidelityAfter += c.fidelityAfter * c.n; t.scored += c.n; }
    }
  }
  return total;
}

/**
 * @param {string[]} observed tokens from signature.observe()
 * @param {object} summary data/research/summary.json
 * @param {{allowSandbox?: boolean, nexus?: boolean|null}} [options] `nexus: true` ranks only the plans that run inside NEXUS (the page does, so the claims ledger is always produced); a plan that needs the sandbox is only chosen when the person has allowed it; otherwise it is recommended, not applied
 */
export function advise(observed, summary, { allowSandbox = false, nexus = null } = {}) {
  const candidates = PLANS.filter((p) => nexus === null || p.nexus === nexus);
  const sig = observed.filter(isIndicator).sort();
  const key = signatureKey(observed);
  const table = (summary && summary.bySignaturePlan) || {};
  let basis = 'none';
  let used = [];
  if (table[key] && Math.max(0, ...Object.values(table[key].plans).map((c) => c.n)) >= MIN_ADVICE_TRIALS) { basis = 'exact'; used = [{ key, ...table[key] }]; }
  else {
    const near = Object.entries(table).filter(([k, v]) => k !== 'clean' && jaccard(v.tokens, sig) >= 0.5).map(([k, v]) => ({ key: k, ...v, similarity: jaccard(v.tokens, sig) }));
    if (near.length && Math.max(0, ...Object.values(pool(near)).map((c) => c.n)) >= MIN_ADVICE_TRIALS) { basis = 'similar'; used = near; }
  }
  if (basis === 'none') {
    return { signature: sig, basis, plan: planById(nexus === false ? 'adaptive' : DEFAULT_PLAN), applied: planById(nexus === false ? 'adaptive' : DEFAULT_PLAN), recommendSandbox: false, alternatives: [], trials: 0, reason: 'No verified experiment matches what this input shows, so the default plan is used. Nothing here is a measured preference.' };
  }
  const totals = pool(used);
  const ranked = candidates.map((plan) => {
    const t = totals[plan.id] || { n: 0, success: 0, worse: 0, failed: 0, fidelityAfter: 0, scored: 0, recovery: 0, partial: 0 };
    const w = wilson(t.success, t.n);
    const harm = t.n ? (t.worse + t.failed) / t.n : 0;
    return {
      plan: plan.id, label: plan.label, needsConsent: plan.needsConsent, n: t.n, success: t.success, recovery: t.recovery, partial: t.partial, worse: t.worse, failed: t.failed,
      lo: Math.round(w.lo * 1000) / 1000, hi: Math.round(w.hi * 1000) / 1000, fidelityAfter: t.scored ? Math.round((t.fidelityAfter / t.scored) * 1000) / 1000 : null,
      utility: Math.round((w.lo - 0.5 * harm) * 1000) / 1000,
    };
  }).filter((r) => r.n >= MIN_ADVICE_TRIALS).sort((a, b) => b.utility - a.utility || (b.fidelityAfter ?? 0) - (a.fidelityAfter ?? 0) || a.plan.localeCompare(b.plan));
  const best = ranked[0];
  const bestFree = ranked.find((r) => !r.needsConsent);
  const chosen = allowSandbox || !best.needsConsent ? best : bestFree || best;
  const recommendSandbox = !!best.needsConsent && !allowSandbox && (!bestFree || best.utility - bestFree.utility >= 0.15);
  const trials = Math.max(...ranked.map((r) => r.n));
  return {
    signature: sig, basis, plan: planById(best.plan), applied: planById(chosen.plan), recommendSandbox, alternatives: ranked, trials,
    similarTo: basis === 'similar' ? used.map((u) => ({ key: u.key, similarity: Math.round(u.similarity * 100) / 100 })) : null,
    reason: `${basis === 'exact' ? 'Experiments on inputs that show the same signs' : 'Experiments on inputs that show similar signs'} put ${best.label} first: ${best.success} of ${best.n} verified (${Math.round(best.lo * 100)}–${Math.round(best.hi * 100)}% at 95%).${recommendSandbox ? ` It needs the sandbox, which is off; the best plan without it verified ${bestFree ? `${bestFree.success} of ${bestFree.n}` : 'none'}.` : ''}`,
  };
}
