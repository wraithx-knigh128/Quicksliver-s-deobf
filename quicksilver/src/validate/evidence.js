// Turning what the engine measured into the evidence src/validate/outcome.js classifies. Kept apart from outcome.js so that the classifier
// stays a pure function the page can import without the detector and parser.

import { parse } from '../core/parser.js';
import { residualIndicators } from '../core/metrics.js';
import { classifyOutcome, inputEvidence } from './outcome.js';
import { analyze } from '../core/scope.js';

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
  let ast = null;
  try { ast = parse(r.output); } catch { parses = false; }
  let residual = [];
  if (parses) { try { residual = residualIndicators(r.output); } catch { residual = []; } }
  return {
    ok: !!r.ok,
    output: r.output,
    parses,
    residual,
    unresolved: unresolvedCount(r),
    level: r.confidence ? r.confidence.level : null,
    bodies: ast ? functionBodies(ast) : null,
    naming: ast ? namingEvidence(ast) : null,
  };
}

// Names a rebuilder invents when it has no evidence: register temporaries, positional parameters and upvalues, and the renamer's own fallbacks.
const PLACEHOLDER = /^(?:_r\d+(?:_\d+)*(?:_c\d+)?(?:_\d+)?|a\d+|up\d+|value\d*|param\d*|L_?\d+_?|p\d+|v\d+|var\d+|arg\d+|unk\d*)$/;

/**
 * Prompt XXVII: how many of the output's locals and parameters carry a placeholder name. Names never change what a program does, so this does not
 * change the class; it is reported, because a reconstruction full of `param1`/`_r3` names is harder to read than one whose names were recovered
 * from evidence, and the report should not hide that.
 */
export function namingEvidence(ast) {
  let info;
  try { info = analyze(ast); } catch { return null; }
  const vars = info.vars.filter((v) => !v.isGlobal && v.name !== 'self' && v.name !== '_');
  const placeholders = vars.filter((v) => PLACEHOLDER.test(v.name));
  const params = vars.filter((v) => v.kind === 'param');
  return { locals: vars.length, placeholders: placeholders.length, params: params.length, placeholderParams: params.filter((v) => PLACEHOLDER.test(v.name)).length };
}

/**
 * Prompt XXVI: how many of the output's functions have a body. A signature with nothing inside is not a reconstructed function; an output
 * made of them (a list of parameters, stubs, placeholders) is not a reconstruction, however readable.
 */
export function functionBodies(ast) {
  let total = 0; let empty = 0; let missingConstants = 0;
  const visit = (n) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(visit); return; }
    if (n.type === 'Func') { total++; if (!n.body || n.body.length === 0) empty++; }
    // `(nil)[k]`: a devirtualizer that could not read the constant pool writes the missing constant k this way (another tool's output for
    // Test 8 has 401 of them); it is not code, it is a hole
    if (n.type === 'Index') { let o = n.obj; while (o && o.type === 'Paren') o = o.expr; if (o && o.type === 'Nil') missingConstants++; }
    for (const k of Object.keys(n)) if (k !== 'line' && k !== 'comments') { const v = n[k]; if (v && typeof v === 'object') visit(v); }
  };
  visit(ast.body);
  return { total, empty, missingConstants };
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

/** The name of a recognised protector whose VM (or packed program) is still in the output, with nothing rebuilt: its architecture is known, the source is not. */
function unresolvedArchitecture(r) {
  if (!r || !r.detection || !r.confidence || !['none', 'minimal'].includes(r.confidence.level)) return null;
  const f = (r.detection.families || []).find((x) => x.confidence >= 0.5 && (x.evidence || []).some((e) => e.unrecoverable));
  if (!f) return null;
  const left = (r.confidence.reasons || []).some((x) => /nothing rebuilt it|still present in the output|generated interpreter is still in the output/.test(x.text));
  return left ? (f.name || f.id) : null;
}

/** The outcome of a direct recovery (no loader, no retrieval), before any behaviour comparison. */
export function recoveryOutcome(source, r, { behaviour = null, retrieval = null } = {}) {
  let input = inputEvidence(source, parse);
  // a generator that ships invalid Lua in a known, documented way (a keyword written as a name, line breaks written as text) is mended by the
  // pipeline before it parses, and the mend is recorded as a step: such an input is not "invalid", it is repaired — and says so
  const mend = r && Array.isArray(r.steps) ? r.steps.find((x) => (x.id === 'keyword.repair' || x.id === 'zartha.repair') && x.status === 'applied') : null;
  if (input.kind === 'lua' && input.parses === false && mend && r.output != null) input = { kind: 'lua', parses: true, repaired: `${mend.label} (${mend.changed} place(s))` };
  const recovery = recoveryEvidence(r);
  const ev = { retrieval, input, obfuscated: wasObfuscated(r && r.detection), recovery, behaviour, remote: remoteEvidence(r), architecture: unresolvedArchitecture(r) };
  // the evidence travels with the result (and back for the behaviour step) without the output text itself
  return { evidence: { ...ev, recovery: recovery && { ...recovery, output: undefined, hasOutput: recovery.output != null } }, ...classifyOutcome(ev) };
}
