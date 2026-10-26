// The recovery pipeline.
//
//   parse -> detect -> [ structural passes -> family passes -> fold -> simplify -> evaluate ]* -> clean-up -> rename
//
// Every pass runs against a snapshot of the AST: if it throws, the snapshot is restored and the step
// is reported as failed, so one broken pass can never corrupt the result. Passes that need to execute
// code (decoder evaluation) run only when the caller explicitly enabled sandboxing.

import { parse, LuaSyntaxError } from '../core/parser.js';
import { print } from '../core/printer.js';
import { clone, structuralKey } from '../core/walk.js';
import { detect } from '../detect/detect.js';
import { foldPass } from '../passes/fold.js';
import { simplifyPass, snapshotUnused } from '../passes/simplify.js';
import { evaluatePass } from '../passes/evaluate.js';
import { renamePass } from '../passes/rename.js';
import { unwrapWrapper, removeUnusedVararg, tidyIfs } from '../passes/structure.js';
import { unwrapLayers } from '../passes/layers.js';
import { dataflowPass } from '../passes/dataflow.js';
import { regionPass } from '../passes/regions.js';
import { booleanResults, orientComparisons, shortCircuits, tableConstructors, methodCalls, bareNils, functionForms, multiResults, numericLoops, loopForms, unsetLocals } from '../passes/idioms.js';
import { removeAntiTamper, undoProxifyLocals } from './prometheus.js';
import { propagateStable } from '../passes/stable.js';
import { buildReport, annotate, stripReport } from './annotate.js';
import { removeHerculesAntiTamper } from './hercules.js';
import { removeColisseumGuard } from './colisseum.js';
import { decodePageStrings } from './simple_html.js';
import { unflattenMoonVeil } from './moonveil-cff.js';
import { liftMoonVeilVm, VmUnsupported } from './moonveil-vm/index.js';
import { decodeMoonVeilConstants, simplifyCells, moonveilShape } from './moonveil.js';
import { assessConfidence } from './confidence.js';
import { AdaptiveEngine } from '../adaptive/engine.js';
import { recoverIronBrew, IronBrewError } from './ironbrew.js';
import { unflattenVmify, envToGlobals, VmifyError } from './vmify.js';
import { parseChunk } from '../sandbox/bytecode.js';
import { decompile } from '../decompile/decompile.js';

export const DEFAULT_OPTIONS = Object.freeze({
  sandbox: { enabled: false, fuel: 60_000_000, timeMs: 10_000, dialect: 'luau' },
  rename: 'smart',            // 'smart' | 'all' | 'off'
  foldCalls: 'obfuscation',   // 'obfuscation' | 'all'
  maxRounds: 8,
  adaptive: true,             // after the family steps and the generic rounds: read the structure of what is left and recover what can be recovered (src/adaptive/)
  adaptiveBudgetMs: 12000,
  // put a short report in front of the output when the recovery is not complete (what was done, what is left); off keeps the code alone
  annotate: true,
  moonveilVm: true,           // read a MoonVeil VM program back out of its data (static; falls back to the general passes when the script does not fit)
  reuseInstructions: true,    // lift an instruction once per kind and reuse it (false lifts every one: slower, same result)
  onProgress: null,           // called with { phase, done?, total? } while long steps run
  stringStyle: 'normalize',
  format: { indent: '  ', width: 100 },
});

const now = () => (typeof performance !== 'undefined' ? performance.now() : Date.now());

class Run {
  constructor(ast, options) {
    this.ast = ast;
    this.options = options;
    this.steps = new Map();
    this.warnings = [];
    this.vmifyLayers = 0;
  }

  /** Run one pass under a snapshot. `fn(ast)` returns { changed, ...detail }. */
  step(id, label, fn, { quiet = false } = {}) {
    const snapshot = clone(this.ast);
    const t0 = now();
    let r;
    try {
      r = fn(this.ast) || { changed: 0 };
    } catch (e) {
      this.ast = snapshot;
      this.record(id, label, { status: 'failed', changed: 0, error: String(e && e.message ? e.message : e), ms: now() - t0 });
      return 0;
    }
    const changed = r.changed || 0;
    if (r.skipped) this.record(id, label, { status: 'skipped', changed: 0, detail: r.skipped, ms: now() - t0 });
    else if (changed || !quiet) this.record(id, label, { status: changed ? 'applied' : 'no-op', changed, detail: r, ms: now() - t0 });
    return changed;
  }

  record(id, label, data) {
    const prev = this.steps.get(id);
    if (!prev) { this.steps.set(id, { id, label, rounds: 1, ...data }); return; }
    prev.rounds++;
    prev.changed += data.changed || 0;
    prev.ms += data.ms || 0;
    if (data.status === 'applied') prev.status = 'applied';
    if (data.status === 'failed') { prev.status = 'failed'; prev.error = data.error; }
    if (data.detail && data.status !== 'skipped') prev.detail = data.detail;
    if (data.status === 'skipped' && prev.status !== 'applied') { prev.status = 'skipped'; prev.detail = data.detail; }
  }
}

/**
 * Prometheus Vmify: the script is a dispatcher over block ids. Rebuild the functions it flattened. Strong applies the
 * pass twice, so go on while another layer turns up.
 */
function rebuildVmify(ast, run) {
  let layers = 0;
  let functions = 0;
  for (; layers < 4; layers++) {
    let r;
    try { r = unflattenVmify(ast, { layer: ++run.vmifyLayers }); } catch (e) {
      if (e instanceof VmifyError) {
        if (layers) break;
        return { skipped: e.message };
      }
      throw e;
    }
    if (!r.changed) break;
    functions += r.functions;
  }
  return layers ? { changed: functions, layers, functions } : { skipped: 'not a Vmify script' };
}

/**
 * IronBrew 2: read the program back out of the VM's own data and decompile it. The AST is replaced in place so that
 * the ordinary passes (folding, clean-up, renaming) go on to work on the recovered program.
 */
function rebuildIronBrew(ast) {
  let r;
  try { r = recoverIronBrew(ast); } catch (e) {
    if (e instanceof IronBrewError) return { skipped: e.message };
    throw e;
  }
  const out = decompile(parseChunk(r.bytes));
  if (out.failures.length) throw new Error(`the decompiler could not structure ${out.failures.length} function(s): ${out.failures[0]}`);
  ast.body = out.ast.body;
  ast.features = out.ast.features || ast.features;
  return { changed: r.stats.instructions, ...r.stats };
}

/** Parse, or return a structured error. */
export function tryParse(source) {
  try {
    return { ok: true, ast: parse(source) };
  } catch (e) {
    if (e instanceof LuaSyntaxError) return { ok: false, error: { message: e.message, line: e.line, col: e.col } };
    throw e;
  }
}

/**
 * @param {string} source binary string
 * @param {object} [userOptions] see DEFAULT_OPTIONS
 */
export function recover(source, userOptions = {}) {
  const options = { ...DEFAULT_OPTIONS, ...userOptions, sandbox: { ...DEFAULT_OPTIONS.sandbox, ...(userOptions.sandbox || {}) }, format: { ...DEFAULT_OPTIONS.format, ...(userOptions.format || {}) } };
  const t0 = now();
  source = stripReport(source);      // a result of ours that is recovered again: its report is replaced, not repeated
  const parsed = tryParse(source);
  if (!parsed.ok) {
    return { ok: false, stage: 'parse', error: parsed.error, output: null, steps: [], detection: detect(source), warnings: [] };
  }
  let detection = detect(source, parsed.ast);
  const run = new Run(parsed.ast, options);
  // after a layer is unwrapped: add what the payload shows to what the wrapper showed
  const refreshDetection = () => {
    const inner = detect(print(run.ast), run.ast);
    const merged = new Map(detection.families.map((f) => [f.id, f]));
    for (const f of inner.families) if (!merged.has(f.id) || merged.get(f.id).confidence < f.confidence) merged.set(f.id, f);
    const traits = new Map([...detection.traits, ...inner.traits].map((t) => [t.id, t]));
    detection = { ...inner, families: [...merged.values()].sort((a, b) => b.confidence - a.confidence), traits: [...traits.values()], layers: (detection.layers || 0) + 1, wrapper: detection.wrapper || { families: detection.families.map((f) => f.id), traits: detection.traits.map((t) => t.id) } };
  };
  let unusedAtStart = snapshotUnused(parsed.ast);

  let decompiled = false;
  let vmified = false;
  let vmTried = false;
  let vmLifted = false;
  if (detection.families.some((f) => f.id === 'ironbrew2' && f.confidence >= 0.5)) {
    // a rebuilt program has no author-written dead code to preserve
    if (run.step('ironbrew2', 'Rebuild the program from the IronBrew 2 VM data', rebuildIronBrew)) { unusedAtStart = new WeakSet(); decompiled = true; }
  }

  const maybeVmify = detection.families.some((f) => f.id === 'prometheus' && f.confidence >= 0.5);

  const generic = () => {
    let total = 0;
    total += run.step('unwrap', 'Unwrap outer wrapper function', (a) => unwrapWrapper(a), { quiet: true });
    total += run.step('prometheus.antitamper', 'Remove Prometheus anti-tamper block', (a) => removeAntiTamper(a), { quiet: true });
    total += run.step('hercules.antitamper', 'Remove Hercules anti-tamper block', (a) => removeHerculesAntiTamper(a), { quiet: true });
    total += run.step('colisseum.guard', 'Remove the Colisseum tamper guard', (a) => removeColisseumGuard(a), { quiet: true });
    if (maybeVmify) {
      // a rebuilt program has no author-written dead code to preserve; Strong applies the pass twice, so this runs each round
      const n = run.step('prometheus.vmify', 'Rebuild the functions Vmify flattened into a dispatcher', (a) => rebuildVmify(a, run), { quiet: true });
      if (n) { total += n; unusedAtStart = new WeakSet(); decompiled = true; vmified = true; }
    }
    if (decompiled) {
      total += run.step('idioms.results', 'Drop the unpack({ f() }) wrappers around calls', (a) => multiResults(a), { quiet: true });
      total += run.step('idioms.bool', 'Write boolean results as expressions', (a) => booleanResults(a), { quiet: true });
      total += run.step('idioms.shortcircuit', 'Write defaults as `a or b`', (a) => shortCircuits(a), { quiet: true });
      total += run.step('idioms.table', 'Fold field assignments into table constructors', (a) => tableConstructors(a), { quiet: true });
      total += run.step('idioms.method', 'Write o.m(o, ...) as o:m(...)', (a) => methodCalls(a), { quiet: true });
      total += run.step('idioms.unset', 'Read temporaries that were never assigned as nil', (a) => unsetLocals(a), { quiet: true });
      total += run.step('idioms.nil', 'Declare locals without an explicit nil', (a) => bareNils(a), { quiet: true });
      total += run.step('idioms.compare', 'Orient comparisons', (a) => orientComparisons(a), { quiet: true });
    }
    total += run.step('fold', 'Fold constant expressions', (a) => foldPass(a, { foldCalls: options.foldCalls }));
    // the text it produces may make `"a" .. "b"` and similar foldable
    const pageStrings = run.step('simple_html.strings', 'Read the _D string calls of the single-page obfuscator', (a) => decodePageStrings(a), { quiet: true });
    if (pageStrings) total += pageStrings + run.step('fold.after', 'Fold constant expressions', (a) => foldPass(a, { foldCalls: options.foldCalls }), { quiet: true });
    // the loaded text of `loadstring(...)()` becomes the program; compiled Lua in it is decompiled, so the rebuilt-program clean-ups apply
    let layers = null;
    const nLayers = run.step('layers', 'Unwrap loadstring layers', (a) => { layers = unwrapLayers(a, { sandbox: options.sandbox }); return layers; }, { quiet: true });
    if (nLayers) {
      total += nLayers;
      if (layers.bytecode) { unusedAtStart = new WeakSet(); decompiled = true; }
    }
    // a payload that came out of a layer may be a different obfuscator's output: look again, so that the report names it
    if (nLayers) refreshDetection();
    total += run.step('moonveil.constants', 'Decode MoonVeil strings and numbers', (a) => decodeMoonVeilConstants(a), { quiet: true });
    total += run.step('moonveil.cells', 'Read MoonVeil cell variables as fields', (a) => simplifyCells(a), { quiet: true });
    // a script whose program is data for MoonVeil's interpreter is read back from that data: the result replaces the interpreter and needs no
    // further clean-up (the generic passes would only spend their time on the interpreter that is being thrown away)
    if (options.moonveilVm && !vmTried && moonveilShape(run.ast)) {
      vmTried = true;
      const lifted = run.step('moonveil.vm', 'Read the program out of MoonVeil\u2019s VM data and rebuild it', (a) => {
        try { return liftMoonVeilVm(a, { onProgress: options.onProgress || undefined, stubLimit: options.stubLimit, reuseInstructions: options.reuseInstructions }); } catch (e) { if (e instanceof VmUnsupported) return { skipped: e.message }; throw e; }
      }, { quiet: true });
      if (lifted) { vmLifted = true; return total + lifted; }
    }
    // a rebuilt function has no author-written dead code to preserve, and the clean-ups for rebuilt programs apply to it
    const nCff = run.step('moonveil.cff', 'Take MoonVeil\u2019s control-flow flattening apart', (a) => unflattenMoonVeil(a, { gotoFallback: true }), { quiet: true });
    if (nCff) { total += nCff; unusedAtStart = new WeakSet(); decompiled = true; }
    total += run.step('simplify', 'Simplify control flow and remove dead code', (a) => simplifyPass(a, { unusedAtStart }));
    if (vmified) total += run.step('prometheus.env', 'Read globals from the environment table again', (a) => envToGlobals(a), { quiet: true });
    if (decompiled) total += run.step('regions', 'Evaluate closed constant computations', (a) => regionPass(a), { quiet: true });
    if (decompiled) total += run.step('dataflow', 'Remove dead stores, copies and temporaries', (a) => dataflowPass(a), { quiet: true });
    if (decompiled) total += run.step('idioms.loops', 'Write counting loops as for loops', (a) => numericLoops(a), { quiet: true });
    if (decompiled) total += run.step('idioms.whiles', 'Move loop exit tests into the loop header', (a) => loopForms(a), { quiet: true });
    total += run.step('tidy', 'Tidy flipped tests', (a) => tidyIfs(a), { quiet: true });
    total += run.step('prometheus.proxify', 'Undo Prometheus ProxifyLocals', (a) => undoProxifyLocals(a), { quiet: true });
    // a rebuilt machine reaches its decoder through copies made at the top of each function; the decoder is only seen once they are gone
    total += run.step('stable', 'Read copies of values that never change as the values', (a) => propagateStable(a), { quiet: true });
    if (options.sandbox.enabled) {
      total += run.step('evaluate', 'Evaluate string decoders (sandbox)', (a) => evaluatePass(a, { sandbox: options.sandbox }));
    } else {
      run.record('evaluate', 'Evaluate string decoders (sandbox)', { status: 'skipped', changed: 0, detail: 'sandboxed evaluation is not enabled', ms: 0 });
    }
    return total;
  };

  for (let round = 1; round <= options.maxRounds; round++) {
    if (!generic() || vmLifted) break;
  }
  if (vmLifted) decompiled = true;
  // whatever the steps above did not know about: structure-driven strategies that choose themselves from what the code is made of
  let adaptive = null;
  if (options.adaptive) {
    run.step('adaptive', 'Read the structure of the code and recover what can be recovered', (a) => {
      adaptive = new AdaptiveEngine().run(a, {
        sandbox: options.sandbox,
        budgetMs: options.adaptiveBudgetMs,
        foldCalls: options.foldCalls,
        unusedAtStart: decompiled ? new WeakSet() : unusedAtStart,
        rebuilt: decompiled,
        observeOnly: vmLifted,
        onProgress: options.onProgress || undefined,
      });
      return { changed: adaptive.changed, scoreBefore: adaptive.score.before, scoreAfter: adaptive.score.after, left: adaptive.residual.length };
    });
    if (adaptive && adaptive.rebuilt) decompiled = true;
  }
  if (vmified) run.step('prometheus.environment', 'Declare the environment the script still reads', (a) => envToGlobals(a, true), { quiet: true });
  if (!vmLifted) run.step('varargs', 'Remove unused vararg parameters', (a) => removeUnusedVararg(a), { quiet: true });
  // the rebuilt program is already named and laid out; the later passes would only rename what was named on purpose
  if (options.rename !== 'off' && !vmLifted) run.step('rename', 'Give obfuscated locals readable names', (a) => renamePass(a, { mode: options.rename }), { quiet: true });
  if (decompiled && !vmLifted) run.step('idioms.functions', 'Use function and method declarations', (a) => functionForms(a), { quiet: true });

  // ---- output and validation --------------------------------------------------------------------------------
  let output;
  try {
    output = print(run.ast, printOptions(options));
  } catch (e) {
    return { ok: false, stage: 'print', error: { message: String(e.message || e) }, output: null, steps: [...run.steps.values()], detection, warnings: run.warnings };
  }
  const validation = validateOutput(output, run.ast, options);
  if (!validation.ok) run.warnings.push(validation.message);
  const steps = [...run.steps.values()];
  const confidence = assessConfidence(detection, output, { steps, validation, ast: run.ast, adaptive });
  const report = buildReport({ detection, steps, confidence, adaptive });

  return {
    adaptive,
    report,
    ok: validation.ok,
    output: options.annotate ? annotate(output, report) : output,
    steps,
    detection,
    validation,
    confidence,
    warnings: run.warnings,
    ms: now() - t0,
  };
}

/**
 * Re-parse the printed output and check that printing is stable: print(parse(print(ast))) must equal
 * print(ast). Comparing trees directly would flag harmless canonicalisation (a negative literal printed as
 * `-5` reads back as a unary minus), while a text fixpoint catches every case where the printed program is
 * not the one we meant to print.
 */
const printOptions = (o) => ({ ...(o.format || {}), strings: o.stringStyle || 'normalize', numbers: o.stringStyle || 'normalize' });

export function validateOutput(output, ast, options = {}) {
  const re = tryParse(output);
  if (!re.ok) return { ok: false, syntax: false, roundTrip: false, message: `The recovered code does not parse: ${re.error.message}` };
  let again;
  try { again = print(re.ast, printOptions(options)); } catch { again = null; }
  const same = again === output;
  return { ok: same, syntax: true, roundTrip: same, message: same ? 'Recovered code parses and prints back identically.' : 'Recovered code parses, but printing it again gives different text.' };
}
