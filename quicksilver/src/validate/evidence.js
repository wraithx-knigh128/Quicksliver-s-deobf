// Turning what the engine measured into the evidence src/validate/outcome.js classifies. Kept apart from outcome.js so that the classifier
// stays a pure function the page can import without the detector and parser.

import { parse } from '../core/parser.js';
import { residualIndicators } from '../core/metrics.js';
import { classifyOutcome, inputEvidence } from './outcome.js';

const HARD_TRAITS = ['state-machine', 'loadstring-layer', 'bytecode-blob', 'junk-code', 'opaque-predicates', 'string-table', 'escape-encoded-strings', 'vm'];

const REMOTE_CLASSES = ['remote-loader', 'cached-remote-loader', 'remote-library-script'];
const isRemote = (detection) => (detection && detection.classes || []).some((c) => REMOTE_CLASSES.includes(c.id));

/**
 * Was the input obfuscated at all, as the detector read it (the same reading the confidence uses)? A script whose only "run-time code" is
 * `loadstring(game:HttpGet(url))()` is a loader, not an obfuscated program: the loadstring layer counts as obfuscation only when the code it
 * runs is built in the file, not fetched.
 */
export function wasObfuscated(detection) {
  if (!detection) return false;
  const remote = isRemote(detection);
  return (detection.families || []).some((f) => f.confidence >= 0.5)
    || (detection.traits || []).some((t) => HARD_TRAITS.includes(t.id) && !(remote && t.id === 'loadstring-layer'))
    || ((detection.metrics && detection.metrics.mangledRatio) || 0) > 0.6;
}

/** What the script downloads and runs when it runs: those parts are not in the file, whatever the recovery did. */
export function remoteEvidence(r) {
  // a dedicated reader that established the program is not in the file at all (LuaQ: delivered by the service at run time)
  const elsewhere = r && Array.isArray(r.steps) ? r.steps.find((x) => x.status === 'applied' && x.detail && x.detail.programInFile === false) : null;
  if (elsewhere) return { only: true, places: [], why: `${elsewhere.label}: the file holds the obfuscator\u2019s runtime and loader; the program itself is delivered from outside the file when it runs` };
  const places = r && r.adaptive && Array.isArray(r.adaptive.residual) ? r.adaptive.residual.filter((x) => x.kind === 'remote-loader') : [];
  const classes = (r && r.detection && r.detection.classes || []).map((c) => c.id);
  if (!places.length && !classes.some((c) => REMOTE_CLASSES.includes(c))) return null;
  return {
    // remote-loader / cached-remote-loader: the file's program IS the download; remote-library-script: the file has a program of its own
    only: classes.includes('remote-loader') || classes.includes('cached-remote-loader'),
    places: places.map((x) => ({ line: x.line, what: x.label })),
  };
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
    unresolved: unresolvedCount(r),
    level: r.confidence ? r.confidence.level : null,
  };
}

/**
 * What the engine left unresolved, without the places that are only remote loads: a `loadstring(game:HttpGet(url))()` is reported by the
 * structure reader as a place it could not resolve, and by the confidence as code built at run time — both true, but they say the code is
 * somewhere else, not that obfuscation is left in this file. They are reported as remote parts instead (remoteEvidence).
 */
function unresolvedCount(r) {
  const list = r.report && Array.isArray(r.report.unresolved) ? r.report.unresolved : [];
  const residual = r.adaptive && Array.isArray(r.adaptive.residual) ? r.adaptive.residual : [];
  const remote = residual.filter((x) => x.kind === 'remote-loader').length;
  if (!remote) return list.length;
  const other = residual.length - remote;
  // the confidence's two remote-only notes ("builds and runs code at run time", "N place(s) ... could not be resolved") are replaced by the
  // count of the residual places that are not remote loads; every other unresolved item is kept
  const kept = list.filter((u) => !(u.source === 'confidence' && (/runs code at run time/.test(u.text) || /place\(s\) were found and could not be resolved/.test(u.text))));
  return kept.length + other;
}

/** The outcome of a direct recovery (no loader, no retrieval), before any behaviour comparison. */
export function recoveryOutcome(source, r, { behaviour = null, retrieval = null } = {}) {
  let input = inputEvidence(source, parse);
  // a generator that ships invalid Lua in a known, documented way (a keyword written as a name, line breaks written as text) is mended by the
  // pipeline before it parses, and the mend is recorded as a step: such an input is not "invalid", it is repaired — and says so
  const mend = r && Array.isArray(r.steps) ? r.steps.find((x) => (x.id === 'keyword.repair' || x.id === 'zartha.repair') && x.status === 'applied') : null;
  if (input.kind === 'lua' && input.parses === false && mend && r.output != null) input = { kind: 'lua', parses: true, repaired: `${mend.label} (${mend.changed} place(s))` };
  const recovery = recoveryEvidence(r);
  const ev = { retrieval, input, obfuscated: wasObfuscated(r && r.detection), recovery, behaviour, remote: remoteEvidence(r) };
  // the evidence travels with the result (and back for the behaviour step) without the output text itself
  return { evidence: { ...ev, recovery: recovery && { ...recovery, output: undefined, hasOutput: recovery.output != null } }, ...classifyOutcome(ev) };
}
