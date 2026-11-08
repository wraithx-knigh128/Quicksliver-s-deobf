// The study framework: learning what is characteristic of a transformation system nobody has described to the engine.
//
// Given samples of a system's output and samples of everything else, `learnSignature` looks for the features (features.js) that nearly every sample of the
// system has and few of the others do, and combines them into the smallest signature that separates the two. `evaluate` then measures the signature
// on samples that played no part in learning it. A signature is accepted as a family only if it meets the thresholds on those held-out samples;
// otherwise the attempt is kept as a failed approach, with its numbers.
//
// What a signature can say is limited by the surface: when one system's output is wrapped by another (a loader around a cipher), the inner one is not
// on the surface, and a signature for it will not fire. That is a finding about nested transformations, and the lab reports it instead of hiding it.

import { satisfies } from './families.js';

export const THRESHOLDS = Object.freeze({ minSupport: 0.9, maxNegativeRate: 0.05, precision: 0.95, recall: 0.9, minPositives: 8, minNegatives: 16 });

const rate = (sets, pred) => (sets.length ? sets.filter(pred).length / sets.length : 0);

/**
 * @param {{positives: Set<string>[], negatives: Set<string>[]}} train feature sets
 * @returns {{signature: {all: string[], none: string[]}, train: object}|null} null when nothing in the samples separates the system
 */
export function learnSignature({ positives, negatives }, t = THRESHOLDS) {
  if (positives.length < t.minPositives || negatives.length < t.minNegatives) return null;
  const universe = new Set([...positives, ...negatives].flatMap((s) => [...s]));
  const support = (f) => rate(positives, (s) => s.has(f));
  const negRate = (f) => rate(negatives, (s) => s.has(f));
  const required = [...universe].filter((f) => support(f) >= t.minSupport).sort((a, b) => negRate(a) - negRate(b) || support(b) - support(a) || a.localeCompare(b));
  const forbidden = [...universe].filter((f) => rate(positives, (s) => s.has(f)) === 0 && negRate(f) > 0).sort((a, b) => negRate(b) - negRate(a) || a.localeCompare(b));

  const chosen = [];
  const excluded = [];
  const leakage = () => rate(negatives, (s) => satisfies({ all: chosen, none: excluded }, s));
  for (const f of required) {
    if (chosen.length && leakage() <= t.maxNegativeRate) break;
    chosen.push(f);
  }
  for (const f of forbidden) {
    if (!chosen.length || leakage() <= t.maxNegativeRate) break;
    if (rate(negatives, (s) => satisfies({ all: chosen, none: [...excluded, f] }, s)) < leakage()) excluded.push(f);
  }
  if (!chosen.length) return null;
  const signature = { all: chosen, none: excluded };
  return { signature, train: measure(signature, positives, negatives) };
}

/** Precision and recall of a signature on labelled feature sets. */
export function measure(signature, positives, negatives) {
  const tp = positives.filter((s) => satisfies(signature, s)).length;
  const fp = negatives.filter((s) => satisfies(signature, s)).length;
  return { tp, fp, fn: positives.length - tp, tn: negatives.length - fp, precision: tp + fp ? tp / (tp + fp) : 0, recall: positives.length ? tp / positives.length : 0, positives: positives.length, negatives: negatives.length };
}

/** Accept or reject a learned signature by its numbers on held-out samples. */
export function evaluate(signature, heldOut, t = THRESHOLDS) {
  const m = measure(signature, heldOut.positives, heldOut.negatives);
  const accepted = m.precision >= t.precision && m.recall >= t.recall && heldOut.positives.length >= t.minPositives && heldOut.negatives.length >= t.minNegatives;
  const reasons = [];
  if (m.precision < t.precision) reasons.push(`precision ${m.precision.toFixed(2)} is below ${t.precision}`);
  if (m.recall < t.recall) reasons.push(`recall ${m.recall.toFixed(2)} is below ${t.recall}`);
  if (heldOut.positives.length < t.minPositives || heldOut.negatives.length < t.minNegatives) reasons.push('too few held-out samples to decide');
  return { accepted, measure: m, reasons };
}
