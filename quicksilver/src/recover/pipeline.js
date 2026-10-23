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
import { unwrapWrapper, removeUnusedVararg } from '../passes/structure.js';
import { removeAntiTamper, undoProxifyLocals } from './prometheus.js';
import { removeHerculesAntiTamper } from './hercules.js';
import { assessConfidence } from './confidence.js';

export const DEFAULT_OPTIONS = Object.freeze({
  sandbox: { enabled: false, fuel: 60_000_000, timeMs: 10_000, dialect: 'luau' },
  rename: 'smart',            // 'smart' | 'all' | 'off'
  foldCalls: 'obfuscation',   // 'obfuscation' | 'all'
  maxRounds: 8,
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
  const parsed = tryParse(source);
  if (!parsed.ok) {
    return { ok: false, stage: 'parse', error: parsed.error, output: null, steps: [], detection: detect(source), warnings: [] };
  }
  const detection = detect(source, parsed.ast);
  const run = new Run(parsed.ast, options);
  const unusedAtStart = snapshotUnused(parsed.ast);

  const generic = () => {
    let total = 0;
    total += run.step('unwrap', 'Unwrap outer wrapper function', (a) => unwrapWrapper(a), { quiet: true });
    total += run.step('prometheus.antitamper', 'Remove Prometheus anti-tamper block', (a) => removeAntiTamper(a), { quiet: true });
    total += run.step('hercules.antitamper', 'Remove Hercules anti-tamper block', (a) => removeHerculesAntiTamper(a), { quiet: true });
    total += run.step('fold', 'Fold constant expressions', (a) => foldPass(a, { foldCalls: options.foldCalls }));
    total += run.step('simplify', 'Simplify control flow and remove dead code', (a) => simplifyPass(a, { unusedAtStart }));
    total += run.step('prometheus.proxify', 'Undo Prometheus ProxifyLocals', (a) => undoProxifyLocals(a), { quiet: true });
    if (options.sandbox.enabled) {
      total += run.step('evaluate', 'Evaluate string decoders (sandbox)', (a) => evaluatePass(a, { sandbox: options.sandbox }));
    } else {
      run.record('evaluate', 'Evaluate string decoders (sandbox)', { status: 'skipped', changed: 0, detail: 'sandboxed evaluation is not enabled', ms: 0 });
    }
    return total;
  };

  for (let round = 1; round <= options.maxRounds; round++) {
    if (!generic()) break;
  }
  run.step('varargs', 'Remove unused vararg parameters', (a) => removeUnusedVararg(a), { quiet: true });
  if (options.rename !== 'off') run.step('rename', 'Give obfuscated locals readable names', (a) => renamePass(a, { mode: options.rename }), { quiet: true });

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
  const confidence = assessConfidence(detection, output, { steps, validation, ast: run.ast });

  return {
    ok: validation.ok,
    output,
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
