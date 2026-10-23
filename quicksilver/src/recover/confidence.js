// How much of the obfuscation is gone, and how sure can we be about the result?
//
// The score is not a probability of "matching the original": nothing can know that. It is built from things
// that can be measured on the recovered code, and every deduction is reported with its reason:
//
//   * the output must parse and survive a print/parse round trip, otherwise there is no result;
//   * obfuscation indicators that are still present in the output are subtracted (a flattened dispatcher,
//     an embedded bytecode chunk, a decoder that could not be evaluated, run-time code generation, ...);
//   * passes that failed, and sandbox work that was skipped although decoders were found, are noted.
//
// tests/ compares this score with the measured fidelity against the original sources.

import { detect } from '../detect/detect.js';

const clamp = (x, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, x));

/**
 * @param {object} before detection of the input
 * @param {string} output recovered source (binary string)
 * @param {object} ctx { steps, validation, ast }
 */
export function assessConfidence(before, output, ctx) {
  const reasons = [];
  const { steps, validation } = ctx;
  if (!validation.syntax) return { score: 0, level: 'none', reasons: [{ effect: -1, text: 'The recovered code does not parse.' }] };
  if (!validation.roundTrip) reasons.push({ effect: -0.2, text: 'Re-parsing the printed code gave a different tree.' });

  const after = detect(output, ctx.ast);
  const hadObfuscation = before.families.some((f) => f.confidence >= 0.5)
    || before.traits.some((t) => ['state-machine', 'loadstring-layer', 'bytecode-blob', 'junk-code', 'opaque-predicates', 'string-table', 'escape-encoded-strings'].includes(t.id))
    || (before.metrics.mangledRatio || 0) > 0.6;

  let penalty = 0;
  const note = (effect, text) => { penalty += -effect; reasons.push({ effect, text }); };

  if (after.traits.some((t) => t.id === 'state-machine')) note(-0.55, 'A flattened dispatcher loop (control-flow flattening or a VM) is still present, so the control flow is not recovered.');
  if (after.traits.some((t) => t.id === 'bytecode-blob')) note(-0.4, 'A compiled Lua chunk is still embedded as data.');
  const vm = after.families.find((f) => f.evidence.some((e) => e.rule === 'vmify-wrapper'));
  if (vm) note(-0.3, 'The virtual-machine wrapper is still present.');
  if (after.traits.some((t) => t.id === 'loadstring-layer') && before.traits.some((t) => t.id === 'loadstring-layer')) {
    note(-0.15, 'The script still builds and runs code at run time; that code is not part of this output.');
  }
  // Evidence of a VM or embedded bytecode that is still in the output means the program was not recovered.
  for (const f of after.families) {
    const hard = f.evidence.find((e) => e.unrecoverable);
    if (hard && f !== vm) note(-0.55, `${hard.text}: still present in the output.`);
  }
  // A vendor banner comment is not obfuscation; only structural evidence counts as "still obfuscated".
  for (const f of after.families) {
    if (f.confidence < 0.5 || f === vm) continue;
    const structural = f.evidence.filter((e) => e.kind !== 'banner' && !e.unrecoverable);
    if (structural.length) note(-0.15, `Output still shows ${f.name} structure: ${structural[0].text}.`);
  }
  if ((after.metrics.mangledRatio || 0) > 0.6 && (before.metrics.mangledRatio || 0) > 0.6) note(-0.08, 'Most identifiers are still machine generated (renaming is off or found no better names).');

  for (const s of steps.filter((x) => x.status === 'failed')) note(-0.1, `Pass "${s.label}" failed and was skipped: ${s.error}`);
  const evalStep = steps.find((s) => s.id === 'evaluate');
  if (evalStep && evalStep.detail && evalStep.detail.rejected > 0) note(-Math.min(0.2, 0.04 * evalStep.detail.rejected), `${evalStep.detail.rejected} decoder call(s) could not be evaluated safely and were left as they are.`);
  const needsDecoder = before.families.some((f) => f.evidence.some((e) => ['encrypt-strings', 'constant-array', 'caesar-decoder', 'split-strings'].includes(e.rule)))
    || before.traits.some((t) => t.id === 'string-table');
  if (evalStep && evalStep.status === 'skipped' && /not enabled/.test(String(evalStep.detail)) && needsDecoder) {
    note(-0.2, 'Sandboxed evaluation is off, so strings that need their decoder to run were not resolved.');
  }
  if (!hadObfuscation) reasons.push({ effect: 0, text: 'No obfuscation was detected; the result is a cleaned and reformatted copy.' });

  // Static analysis alone never reaches certainty, hence the ceiling.
  let score = clamp((hadObfuscation ? 0.9 : 0.95) - penalty, 0, 1);
  const level = score >= 0.85 ? 'high' : score >= 0.6 ? 'medium' : score > 0.25 ? 'low' : 'minimal';
  return { score: Math.round(score * 100) / 100, level, reasons };
}
