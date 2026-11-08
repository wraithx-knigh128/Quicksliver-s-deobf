// The judge: the one place that decides what an experiment's outcome is called.
//
// "Success" is never a state a technique can claim for itself. It is the verdict of this function on a record whose behaviour check ran.
//
//   tool-broken             the transformed program does not behave like the original, so the experiment says nothing about reconstruction
//   error                   the technique threw
//   failed-parse            the reconstruction is not valid source
//   failed-behaviour        the reconstruction behaves differently from the original (a defect to look into)
//   inconclusive            the comparison could not settle it (the original printed nothing, or a limit stopped a run)
//   behaviour-kept-worse    behaves the same, but is further from the original than the input was (structure was lost)
//   behaviour-kept-no-gain  behaves the same, nothing measurable was gained
//   verified-partial        behaves the same AND measurably better: closer to the original, or fewer signs of obfuscation without losing closeness
//   verified-recovery       as verified-partial, and the reconstruction is close to the original outright (fidelity at least 0.9)
//
// Two independent measures, neither of which uses what is known about how the input was made:
//   fidelity  how close the token sequence is to the original's (core/fidelity.js)
//   opacity   how many obfuscation indicators the text shows (signature.js), counted the same way before and after
// Behaviour is compared in QuickSilver's own interpreter. Equal behaviour there is evidence, not proof.

export const GAIN = 0.05;      // fidelity must rise by at least this much over the transformed input
// A change in fidelity smaller than GAIN, in either direction, is noise (the engine's own constant folding moves it by a few hundredths), so the same
// band decides "stayed close enough while the indicators fell" and "further from the original". It was 0.03 in the first version, which classed a drop of
// 0.04 as a failure to clean although 0.04 is not "worse"; the change and its effect on the verdicts are recorded in docs/RESEARCH-LAB.md.
export const SLACK = GAIN;
export const FULL = 0.9;       // "recovery" means fidelity at least this

/**
 * @param {{transformValid: boolean, error?: string, parsed?: boolean, behaviour?: string, fidelityBefore?: number, fidelityAfter?: number, opacityBefore?: number, opacityAfter?: number}} r
 * @returns {string}
 */
export function judge(r) {
  if (!r.transformValid) return 'tool-broken';
  if (r.error) return 'error';
  if (!r.parsed) return 'failed-parse';
  if (r.behaviour === 'different') return 'failed-behaviour';
  if (r.behaviour !== 'identical') return 'inconclusive';
  const fb = r.fidelityBefore ?? 0;
  const fa = r.fidelityAfter ?? 0;
  const gained = fa - fb >= GAIN;
  const cleaner = (r.opacityAfter ?? 0) < (r.opacityBefore ?? 0) && fa >= fb - SLACK;
  if (gained || cleaner) return fa >= FULL ? 'verified-recovery' : 'verified-partial';
  return fa < fb - GAIN ? 'behaviour-kept-worse' : 'behaviour-kept-no-gain';
}

export const VERDICTS = ['verified-recovery', 'verified-partial', 'behaviour-kept-no-gain', 'behaviour-kept-worse', 'failed-behaviour', 'failed-parse', 'inconclusive', 'error', 'tool-broken'];
export const isSuccess = (v) => v === 'verified-recovery' || v === 'verified-partial';

/** Wilson score interval for k successes in n trials (z = 1.96: 95%). Honest about small samples: n = 0 gives [0, 1]. */
export function wilson(k, n, z = 1.96) {
  if (n === 0) return { p: 0, lo: 0, hi: 1 };
  const p = k / n;
  const d = 1 + (z * z) / n;
  const centre = (p + (z * z) / (2 * n)) / d;
  const half = (z * Math.sqrt((p * (1 - p)) / n + (z * z) / (4 * n * n))) / d;
  return { p, lo: Math.max(0, centre - half), hi: Math.min(1, centre + half) };
}
