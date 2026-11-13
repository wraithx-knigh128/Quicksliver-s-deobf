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
import { findRoot } from './moonveil.js';

const clamp = (x, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, x));

/**
 * @param {object} before detection of the input
 * @param {string} output recovered source (binary string)
 * @param {object} ctx { steps, validation, ast }
 */
export function assessConfidence(before, output, ctx) {
  const reasons = [];
  const hints = []; // machine-readable follow-ups for the interface
  const { steps, validation } = ctx;
  if (!validation.syntax) return { score: 0, level: 'none', reasons: [{ effect: -1, text: 'The recovered code does not parse.' }], hints };
  if (!validation.roundTrip) reasons.push({ effect: -0.2, text: 'Re-parsing the printed code gave a different tree.' });

  const after = detect(output, ctx.ast);
  const hadObfuscation = before.families.some((f) => f.confidence >= 0.5)
    || before.traits.some((t) => ['state-machine', 'loadstring-layer', 'bytecode-blob', 'junk-code', 'opaque-predicates', 'string-table', 'escape-encoded-strings'].includes(t.id))
    || (before.metrics.mangledRatio || 0) > 0.6;

  let penalty = 0;
  const note = (effect, text) => { penalty += -effect; reasons.push({ effect, text }); };

  const hardLeft = after.traits.some((t) => t.id === 'state-machine' || t.id === 'bytecode-blob');
  if (hardLeft || after.families.some((f) => f.evidence.some((e) => e.unrecoverable))) hints.push('trace');
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
  // A VM the input showed and no pass rebuilt. Clean-up can rewrite the signature away (an inlined alias is gone) while the program is still
  // inside the VM, so the verdict cannot depend on the signature surviving.
  const REBUILT_BY = { ironbrew2: ['ironbrew2'], hercules: ['layers', 'hercules.vm'], moonveil: ['moonveil.vm'] };
  for (const f of before.families) {
    const hard = f.confidence >= 0.5 && f.evidence.find((e) => e.unrecoverable);
    if (!hard) continue;
    if (after.families.some((a) => a.id === f.id && a.evidence.some((e) => e.unrecoverable))) continue; // counted above
    if ((REBUILT_BY[f.id] || []).some((id) => steps.some((x) => x.id === id && x.status === 'applied'))) continue;
    note(-0.55, `${hard.text}: nothing rebuilt it.`);
    if (!hints.includes('trace')) hints.push('trace');
  }
  // A vendor banner comment is not obfuscation; only structural evidence counts as "still obfuscated".
  for (const f of after.families) {
    if (f.confidence < 0.5 || f === vm) continue;
    const structural = f.evidence.filter((e) => e.kind !== 'banner' && !e.unrecoverable);
    if (structural.length) note(-0.15, `Output still shows ${f.name} structure: ${structural[0].text}.`);
  }
  if ((after.metrics.mangledRatio || 0) > 0.6 && (before.metrics.mangledRatio || 0) > 0.6) note(-0.08, 'Most identifiers are still machine generated (renaming is off or found no better names).');

  // A script that only downloads and runs code has no program in it: whatever was done to the file, what it runs is somewhere else.
  if ((before.classes || []).some((c) => c.id === 'remote-loader' || c.id === 'cached-remote-loader')) note(-0.55, 'The program this script runs is downloaded when it runs; it is not in this file, so nothing of it was recovered.');
  // What the passes themselves reported as left: each is a place where the control flow or a value is still the obfuscator's.
  const residual = ctx.adaptive && ctx.adaptive.residual ? ctx.adaptive.residual.length : 0;
  if (residual) note(-Math.min(0.5, 0.05 * residual), `${residual} place(s) were found and could not be resolved (listed in the report).`);
  // MoonVeil keeps the program as a table of lifted functions; unless the VM reader or the cell/constant passes joined it into one program, that table is still the script.
  if (ctx.ast && before.families.some((f) => f.id === 'moonveil' && f.confidence >= 0.5) && !steps.some((x) => x.id === 'moonveil.vm' && x.status === 'applied')) {
    let root = null;
    try { root = findRoot(ctx.ast); } catch { root = null; }
    if (root) note(-0.3, 'The program is still MoonVeil\u2019s table of lifted functions: the functions are decoded and readable, but they are not joined into the script\u2019s own flow of control.');
  }
  for (const s of steps) if (s.status === 'applied' && s.detail && s.detail.inferred) note(-0.15, `Inferred, not read: ${s.detail.inferred}.`);
  for (const s of steps.filter((x) => x.status === 'failed')) note(-0.1, `Pass "${s.label}" failed and was skipped: ${s.error}`);
  const evalStep = steps.find((s) => s.id === 'evaluate');
  // The evaluator counts the calls it rejected while it ran; a statement holding one can be dropped afterwards (dead code, a spent decoder). When the structure reader ran on the final
  // tree and finds no string decoder in it, there is nothing "left as it is": the note would describe a state the output is no longer in.
  const decoderRemains = ctx.adaptive && ctx.adaptive.ran ? (ctx.adaptive.residual || []).some((x) => x.kind === 'string-decoder') : true;
  const leftBehind = evalStep && evalStep.detail && decoderRemains ? evalStep.detail.rejected : 0;
  if (leftBehind > 0) note(-Math.min(0.2, 0.04 * leftBehind), `${leftBehind} decoder call(s) could not be evaluated safely and were left as they are.`);
  // a virtual machine whose constants stayed unread because the sandbox is off: the report says so, and the page offers the sandbox the same way it does for a string decoder
  if (ctx.vm && !ctx.vm.constants && /sandbox/.test(String(ctx.vm.note || ''))) hints.push('sandbox');
  const needsDecoder = before.families.some((f) => f.evidence.some((e) => ['encrypt-strings', 'constant-array', 'caesar-decoder', 'split-strings'].includes(e.rule)))
    || before.traits.some((t) => t.id === 'string-table');
  if (evalStep && evalStep.status === 'skipped' && /not enabled/.test(String(evalStep.detail)) && needsDecoder) {
    note(-0.2, 'Sandboxed evaluation is off, so strings that need their decoder to run were not resolved.');
    hints.push('sandbox');
  }
  // A script that is only a loader: the text it computes is the program, and when the sandbox is off nothing read it.
  const loaderSkipped = steps.find((s) => s.id === 'layers' && s.status === 'skipped' && /sandboxed evaluation/.test(String(s.detail)));
  if (loaderSkipped) { note(-0.55, 'The script is a loader whose text is computed: that text is the program, and it was not read (sandboxed evaluation is off).'); if (!hints.includes('sandbox')) hints.push('sandbox'); }
  const lifted = steps.find((s) => s.id === 'moonveil.vm' && s.status === 'applied');
  if (lifted) reasons.push({ effect: 0, text: `The program was rebuilt from the VM's own data without running anything: ${lifted.detail && lifted.detail.protos ? `${lifted.detail.protos} functions, ${lifted.detail.instructions} instructions` : 'every instruction'} read through the interpreter's handlers. It has not been compared with a run of the original.` });
  if (lifted && lifted.detail && lifted.detail.validation) {
    const v = lifted.detail.validation;
    reasons.push({ effect: 0, text: `Checked without running it: ${v.constants.readable - v.constants.missing} of ${v.constants.readable} readable constants the instructions use are in the text, ${v.undeclared.length} register(s) read without being assigned, ${v.functions - v.unstructured} of ${v.functions} functions structured.` });
    if (v.constants.missing) note(-0.1, `${v.constants.missing} readable constant(s) of the VM program do not appear in the output (for example ${JSON.stringify(v.constants.sample[0])}).`);
    if (v.undeclared.length) note(-0.1, `Names that look like registers are read without being assigned: ${v.undeclared.slice(0, 4).join(', ')}.`);
    if (v.unstructured) note(-0.05, `${v.unstructured} function(s) could not be structured and are written with labels and jumps.`);
  }
  if (!hadObfuscation) reasons.push({ effect: 0, text: 'No obfuscation was detected; the result is a cleaned and reformatted copy.' });

  // Static analysis alone never reaches certainty, hence the ceiling.
  let score = clamp((hadObfuscation ? 0.9 : 0.95) - penalty, 0, 1);
  const level = score >= 0.85 ? 'high' : score >= 0.6 ? 'medium' : score > 0.25 ? 'low' : 'minimal';
  return { score: Math.round(score * 100) / 100, level, reasons, hints };
}
