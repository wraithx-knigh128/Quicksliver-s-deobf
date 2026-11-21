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
import { probe } from '../custom/probes.js';

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
  const REBUILT_BY = { azurevm: ['azurevm.vm'], ironbrew2: ['ironbrew2'], hercules: ['layers', 'hercules.vm'], moonveil: ['moonveil.vm', 'moonveil.vm21'], realobfuscator: ['realobfuscator.vm'], obscura: ['obscura.vm'], zartha: ['zartha.vm'], fusgato: ['fusgato.vm'], luaxen: ['ironbrikked.vm'] };
  for (const f of before.families) {
    const hard = f.confidence >= 0.5 && f.evidence.find((e) => e.unrecoverable);
    if (!hard) continue;
    if (after.families.some((a) => a.id === f.id && a.evidence.some((e) => e.unrecoverable))) continue; // counted above
    if ((REBUILT_BY[f.id] || []).some((id) => steps.some((x) => x.id === id && x.status === 'applied'))) continue;
    note(-0.55, `${hard.text}: nothing rebuilt it.`);
    if (!hints.includes('trace')) hints.push('trace');
  }
  // An interpreter no rule knows by name, still in the output: the structure probe of the custom-format analysis sees it by its shape (a dispatch over handlers that
  // cover the operations of a register machine, or a table of handler functions read with a computed key). Unless a step rebuilt a VM, the program is still data.
  const VM_STEPS = ['hercules.vm', 'zartha.vm', 'fusgato.vm', 'ironbrikked.vm', 'obscura.vm', 'moonveil.vm', 'prometheus.vmify', 'prometheus.bvm', 'vault.vm', 'azurevm.vm', 'moonveil.vm21', 'realobfuscator.vm', 'ironbrew2', 'layers'];
  if (output.length < 600000 && !steps.some((x) => VM_STEPS.includes(x.id) && x.status === 'applied')) {
    let left = null;
    try { left = probe(output).transformations.find((t) => t.id === 'bytecode-vm' && t.confidence >= 0.8 && t.shape !== 'staged-container'); } catch { left = null; }
    // counted once: a VM that a rule already named as left in place (or not rebuilt) is not penalised again
    const named = reasons.some((r) => /nothing rebuilt it|still present in the output|dispatcher loop .*still present|virtual-machine wrapper is still present/.test(r.text));
    if (left && !named) {
      note(-0.55, `A generated interpreter is still in the output (${left.shape === 'handler-table' ? `a table of ${left.handlers} handler functions dispatched by a computed key` : `a dispatch over ${left.handlers} handlers`}, line ${left.line || '?'}): the program is its data and was not rebuilt.`);
      if (!hints.includes('trace')) hints.push('trace');
    }
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
  if (ctx.ast && before.families.some((f) => f.id === 'moonveil' && f.confidence >= 0.5) && !steps.some((x) => (x.id === 'moonveil.vm' || x.id === 'moonveil.vm21') && x.status === 'applied')) {
    let root = null;
    try { root = findRoot(ctx.ast); } catch { root = null; }
    if (root) note(-0.3, 'The program is still MoonVeil\u2019s table of lifted functions: the functions are decoded and readable, but they are not joined into the script\u2019s own flow of control.');
  }
  for (const s of steps) if (s.status === 'applied' && s.detail && s.detail.lost) note(-0.3, `Not in the file: ${s.detail.lost}. The original values are unknown, so this part of the program cannot match the original.`);
  for (const s of steps) if (s.status === 'applied' && s.detail && s.detail.experimental) note(-0.35, `Experimental reader: ${s.detail.experimental}.`);
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
  const joined = steps.find((s) => s.id === 'moonveil.join' && s.status === 'applied');
  if (joined) note(-0.2, `The program was put together from MoonVeil's table of ${joined.detail && joined.detail.factories ? `${joined.detail.factories} ` : ''}factories by following the places they build each other, without running anything. It has not been compared with a run of the original, and cells that closures share between loop iterations stay as cells.`);
  const ikl = steps.find((s) => s.id === 'ironbrikked.vm' && s.status === 'applied');
  if (ikl) note(-0.5, 'The VM program was read as the generator compiled it, and that is not the original program. LuaXen\u2019s compiler puts temporaries over registers that still hold live values (parameters, call results kept in a local or stored into a table), and it compiles every assignment to a global or an upvalue as a move into register 0 (it has no SETGLOBAL or SETUPVAL). The faults that are only encodings are read back: the parameter count it never stores, the upvalue links after a closure, return counts written as registers, a loop body that reads the loop\u2019s own counter. A program inside what the compiler handles correctly is recovered exactly (tests/corpus/controlled/luaxen-subset); these fixtures are not inside it, so the result follows the compiled instructions and cannot run like the original.');
  const vl = steps.find((s) => s.id === 'vault.vm' && s.status === 'applied');
  if (vl && vl.detail && vl.detail.upvalueOrderRepaired) reasons.push({ effect: 0, text: `Vault's generator shuffles each closure's upvalue list without renumbering the instructions that read it, so its own build reads the wrong variables; in ${vl.detail.upvalueOrderRepaired} closure(s) the order was restored because what the closure does with each value (calls it, indexes it, computes with it) fits exactly one order of what the parent captured.` });
  if (vl && vl.detail && vl.detail.upvalueOrderUnresolved) note(-0.45, `${vl.detail.upvalueOrderUnresolved} closure(s) capture two or more variables whose order Vault's generator scrambled (it shuffles the upvalue list and never renumbers the reads) and the evidence does not single out one order: they are written as the build runs them, which may not be what the original program did.`);
  const zl = steps.find((s) => s.id === 'zartha.vm' && s.status === 'applied');
  const ks = zl && zl.detail && zl.detail.keysearch;
  if (ks && ks.decided) reasons.push({ effect: 0, text: `${ks.decided} of ${ks.strings} string constant(s) were masked with a key per constant that the generator never stores (its constant-protection option is unfinished and its own output does not run). They were read back by key search: each has only 29 possible readings, ${ks.byName} were decided by being the one reading that is a name the runtime defines (a global, a library function, a service or an API member), the rest by being far more word-like than every other reading. The key is not in the file, so these are judgements from evidence, not decryptions (on the 15 constant-protected test builds: 390 decided, none wrong, 79 left undecided).` });
  if (zl && zl.detail && zl.detail.masked > 0) note(-0.5, ks ? `${zl.detail.masked} masked string constant(s) could not be decided by key search (two or more readings are about as plausible, or none reads as text); they are left as the file holds them, so those strings are not recovered.` : `${zl.detail.masked} string constant(s) of the VM program are masked with a key per constant that the generator never stores (the constant-protection option of this generator is unfinished and its own output does not run), so they cannot be read back: the structure of the program is rebuilt, those strings are not.`);
  const lifted = steps.find((s) => s.id === 'moonveil.vm' && s.status === 'applied');
  if (lifted) reasons.push({ effect: 0, text: `The program was rebuilt from the VM's own data without running anything: ${lifted.detail && lifted.detail.protos ? `${lifted.detail.protos} functions, ${lifted.detail.instructions} instructions` : 'every instruction'} read through the interpreter's handlers. It has not been compared with a run of the original.` });
  if (lifted && lifted.detail && lifted.detail.validation) {
    const v = lifted.detail.validation;
    reasons.push({ effect: 0, text: `Checked without running it: ${v.constants.readable - v.constants.missing} of ${v.constants.readable} readable constants the instructions use are in the text, ${v.undeclared.length} register(s) read without being assigned, ${v.functions - v.unstructured} of ${v.functions} functions structured.` });
    if (v.constants.missing) note(-0.1, `${v.constants.missing} readable constant(s) of the VM program do not appear in the output (for example ${JSON.stringify(v.constants.sample[0])}).`);
    if (v.undeclared.length) note(-0.1, `Names that look like registers are read without being assigned: ${v.undeclared.slice(0, 4).join(', ')}.`);
    if (v.unstructured) note(-0.05, `${v.unstructured} function(s) could not be structured and are written with labels and jumps.`);
  }
  const lq = steps.find((s) => s.id === 'luaq.layers' && s.status === 'applied');
  if (lq) {
    const v = (lq.detail && lq.detail.vm) || {};
    note(-0.6, `LuaQ${lq.detail && lq.detail.version ? ` v${lq.detail.version}` : ''}: the outer layer was decoded (base 93, LQZ1 with its Adler-32 checked, DEFLATE) to the VM runtime it loads, which is the output here${v.handlers ? ` — a register VM with ${v.handlers} fused handlers dispatched through a balanced search tree on a masked opcode, instructions decrypted from a feedback keystream and memoised per index` : ''}. The program itself is not in the file: it is delivered to the script at run time from outside it, so nothing of it was recovered.`);
  }
  const ro = steps.find((s) => s.id === 'realobfuscator.vm' && s.status === 'applied');
  if (ro) {
    const d = ro.detail || {};
    reasons.push({ effect: 0, text: `RealObfuscator's function VM: ${d.functions || 'every'} compiled function(s) (${d.instructions || 0} instructions) were decoded with the keys their records carry (every record's checksum verified), read through the handler of each opcode alias, and written back as Lua; closures, method calls and generic for loops were rebuilt from the plain-Lua factories the VM keeps for them. Nothing of the program was run to read it.` });
    if (d.selfCheck === 'same') reasons.push({ effect: 0, text: 'The rebuilt script and the original were both run in the sandbox: same success, same output, same number of results.' });
    else note(-0.25, 'The rebuilt script was not run against the original (the sandbox is off or the run hit a limit), so nothing confirms that it behaves the same.');
  }
  const mv21 = steps.find((s) => s.id === 'moonveil.vm21' && s.status === 'applied');
  if (mv21) {
    const d = mv21.detail || {};
    reasons.push({ effect: 0, text: `MoonVeil 2.1.0: each of the ${d.instructions || 'VM\u2019s'} instruction(s) was read through the handler its opcode selects, evaluated with the instruction's fields known (${d.handlers || 'its'} distinct handlers), written as Lua 5.1 and decompiled; the ${d.sites || 0} place(s) where MoonVeil left plain Lua (the code around the VM and ${d.natives || 0} native function(s)) were joined around it. Nothing of the program was run to read it.` });
    if (d.selfCheck === 'same') reasons.push({ effect: 0, text: 'The rebuilt script and the original were both run in the sandbox: same success, same output, same number of results.' });
    else note(-0.25, 'The rebuilt script was not run against the original (the sandbox is off or the run hit a limit), so nothing confirms that it behaves the same.');
    if (d.generalisedIteration) note(-0.05, `${d.generalisedIteration} generic for loop(s) start with Luau's generalised iteration (a table iterated directly, or __iter); they are written as plain generic for loops, which Luau runs the same way.`);
  }
  if (!hadObfuscation) reasons.push({ effect: 0, text: 'No obfuscation was detected; the result is a cleaned and reformatted copy.' });

  // Static analysis alone never reaches certainty, hence the ceiling.
  let score = clamp((hadObfuscation ? 0.9 : 0.95) - penalty, 0, 1);
  // Prompt XXIV: a virtual machine that no step rebuilt holds the program as its data; whatever else was cleaned up around it, the protection
  // is essentially all still present. Before this cap, a Boronide or Luraph VM came out "low" (or higher, when the VM evidence was missed)
  // and was reported as partially reconstructed.
  if (reasons.some((r) => /nothing rebuilt it|still present in the output|generated interpreter is still in the output/.test(r.text))) score = Math.min(score, 0.25);
  const level = score >= 0.85 ? 'high' : score >= 0.6 ? 'medium' : score > 0.25 ? 'low' : 'minimal';
  return { score: Math.round(score * 100) / 100, level, reasons, hints };
}
