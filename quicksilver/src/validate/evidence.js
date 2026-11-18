// Turning what the engine measured into the evidence src/validate/outcome.js classifies. Kept apart from outcome.js so that the classifier
// stays a pure function the page can import without the detector and parser.

import { parse } from '../core/parser.js';
import { residualIndicators } from '../core/metrics.js';
import { classifyOutcome, inputEvidence } from './outcome.js';

const HARD_TRAITS = ['state-machine', 'loadstring-layer', 'bytecode-blob', 'junk-code', 'opaque-predicates', 'string-table', 'escape-encoded-strings', 'vm'];

/** Was the input obfuscated at all, as the detector read it (the same reading the confidence uses)? */
export function wasObfuscated(detection) {
  if (!detection) return false;
  return (detection.families || []).some((f) => f.confidence >= 0.5)
    || (detection.traits || []).some((t) => HARD_TRAITS.includes(t.id))
    || ((detection.metrics && detection.metrics.mangledRatio) || 0) > 0.6;
}

/** Evidence about one recover() result: does the output parse, what obfuscation is still in it, what the engine left unresolved. */
export function recoveryEvidence(r) {
  if (!r) return null;
  if (r.output == null) return { ok: false, output: null, error: r.error ? r.error.message || String(r.error) : undefined };
  let parses = true;
  try { parse(r.output); } catch { parses = false; }
  let residual = [];
  if (parses) { try { residual = residualIndicators(r.output); } catch { residual = []; } }
  return {
    ok: !!r.ok,
    output: r.output,
    parses,
    residual,
    unresolved: r.report && Array.isArray(r.report.unresolved) ? r.report.unresolved.length : 0,
    level: r.confidence ? r.confidence.level : null,
  };
}

/** The outcome of a direct recovery (no loader, no retrieval), before any behaviour comparison. */
export function recoveryOutcome(source, r, { behaviour = null, retrieval = null } = {}) {
  let input = inputEvidence(source, parse);
  // a generator that ships invalid Lua in a known, documented way (a keyword written as a name, line breaks written as text) is mended by the
  // pipeline before it parses, and the mend is recorded as a step: such an input is not "invalid", it is repaired — and says so
  const mend = r && Array.isArray(r.steps) ? r.steps.find((x) => (x.id === 'keyword.repair' || x.id === 'zartha.repair') && x.status === 'applied') : null;
  if (input.kind === 'lua' && input.parses === false && mend && r.output != null) input = { kind: 'lua', parses: true, repaired: `${mend.label} (${mend.changed} place(s))` };
  const recovery = recoveryEvidence(r);
  const ev = { retrieval, input, obfuscated: wasObfuscated(r && r.detection), recovery, behaviour };
  // the evidence travels with the result (and back for the behaviour step) without the output text itself
  return { evidence: { ...ev, recovery: recovery && { ...recovery, output: undefined, hasOutput: recovery.output != null } }, ...classifyOutcome(ev) };
}
