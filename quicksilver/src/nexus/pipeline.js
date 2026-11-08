// NEXUS · the unified source-analysis pipeline.
//
//   1 inspect      the bytes: size, encoding, a report an earlier run left in front of the text
//   2 identify     language and environment: dialect, executor APIs, obfuscator families
//   3 structure    parse; counts of functions, variables, nodes
//   4 semantic     the relation mapper (roles, dependencies, call graph) and the trivia reader
//   5 classify     what kinds of change separate this text from the program it holds
//   6 flow         control-flow shapes, complexity, and the shapes this engine does not rebuild
//   7 dependencies what the script fetches, which executor APIs it needs, which globals it writes
//   8 reconstruct  one or more passes of the recovery pipeline; a further pass runs only while the profile shows something left
//                  while the last pass changed the text (up to a limit), because one stage's discovery can enable another's
//   9 verify       the ledger: checks that ran (verified), rules that concluded (inferred), things not settled (unresolved)
//  10 generate     the code, with a report in front of it when anything is not settled
//
// The recovery pipeline (src/recover/) and the structure reader (src/adaptive/) are used as they are; NEXUS decides what to feed them,
// what to ask of them next, and what may be claimed about the result. Nothing is executed unless `runtime` is switched on, and then only in
// QuickSilver's own interpreter (src/sandbox/). If any stage throws, the plain recovery result is returned with the failure recorded.

import { parse } from '../core/parser.js';
import { print } from '../core/printer.js';
import { analyze } from '../core/scope.js';
import { detect } from '../detect/detect.js';
import { recover, tryParse, validateOutput, DEFAULT_OPTIONS } from '../recover/pipeline.js';
import { buildReport, stripReport } from '../recover/annotate.js';
import { assessConfidence } from '../recover/confidence.js';
import { verifyRecovery } from '../adaptive/verify.js';
import { analyzeTrivia, stripComments, sameProgram } from './trivia.js';
import { mapRelations } from './roles.js';
import { classify, controlFlow } from './profile.js';
import { Ledger, newGlobals, sameBindings } from './ledger.js';
import { clone } from '../core/walk.js';

export const NEXUS_VERSION = '1.0.0';
export const NEXUS_DEFAULTS = Object.freeze({
  passes: 3,            // upper bound on reconstruction passes; a pass runs only while there is something left to do
  runtime: false,       // run the original and the result in the sandbox and compare (the page asks first)
  maxBytes: 2_000_000,  // above this one pass is run and the relation mapper is skipped
  recover: {},          // options handed to recover()
});

const now = () => (typeof performance !== 'undefined' ? performance.now() : Date.now());
const WIDTH = 108;
const wrap = (text, first, rest) => {
  const out = [];
  let cur = first;
  for (const w of String(text).replace(/\s+/g, ' ').trim().split(' ')) {
    if (cur.length + w.length + 1 > WIDTH && cur.trim().length > first.trim().length) { out.push(cur); cur = rest; }
    cur += (cur.endsWith(' ') ? '' : ' ') + w;
  }
  out.push(cur);
  return out;
};

/** Which categories of transformation a further pass of the recovery pipeline might still reduce. */
const REDUCIBLE = new Set(['control-flow', 'data', 'naming', 'indirection', 'virtualization', 'tool']);
const residualOf = (transformations) => transformations.filter((t) => REDUCIBLE.has(t.category) && t.id !== 'remote-code').reduce((a, t) => a + t.confidence, 0);

class Roles extends Map {
  constructor(src) { super(src); this.used = new Set(); }
  get(k) { const v = super.get(k); if (v) this.used.add(v); return v; }
}

/**
 * @param {string} source binary string
 * @param {object} [userOptions] see NEXUS_DEFAULTS; `recover` is passed to recover()
 */
export function nexusRecover(source, userOptions = {}) {
  // an option given as undefined means "not given": it never overrides a default
  const given = Object.fromEntries(Object.entries(userOptions).filter(([, v]) => v !== undefined));
  const options = { ...NEXUS_DEFAULTS, ...given, recover: { ...DEFAULT_OPTIONS, ...(given.recover || {}) } };
  if (!(options.passes >= 1)) options.passes = NEXUS_DEFAULTS.passes;
  const t0 = now();
  const stages = [];
  const ledger = new Ledger();
  const needs = [];
  const limits = [];
  const state = { failed: null };

  const stage = (id, title, fn) => {
    const s = { id, title, status: 'done', ms: 0, notes: [], requests: [] };
    const t = now();
    try { fn(s); } catch (e) {
      s.status = 'failed';
      s.error = String(e && e.message ? e.message : e);
      state.failed = state.failed || { stage: id, error: s.error };
    }
    s.ms = now() - t;
    stages.push(s);
    return s;
  };
  const fallback = (why) => {
    const plain = recover(source, options.recover);
    plain.nexus = { version: NEXUS_VERSION, fallback: true, reason: why, stages, ledger: { claims: ledger.claims, summary: ledger.summary() } };
    return plain;
  };

  // 1 ---- inspect -------------------------------------------------------------------------------------------------------------------
  const facts = {};
  stage('inspect', 'Inspect the input', (s) => {
    source = stripReport(source);
    facts.bytes = source.length;
    facts.lines = source.split('\n').length;
    facts.bom = source.startsWith('\xEF\xBB\xBF');
    facts.shebang = source.startsWith('#!');
    facts.largest = source.split('\n').reduce((a, l) => Math.max(a, l.length), 0);
    if (facts.bom) s.notes.push('Starts with a UTF-8 byte-order mark.');
    if (source.length > options.maxBytes) { limits.push(`The input is ${source.length} bytes, above the ${options.maxBytes} byte limit for multi-pass analysis: one pass was run.`); options.passes = 1; }
  });
  if (!source.trim()) return { ok: false, stage: 'parse', error: { message: 'The input is empty.' }, output: null, steps: [], warnings: [], nexus: { version: NEXUS_VERSION, stages, ledger: { claims: [], summary: ledger.summary() } } };

  // 2, 3 ---- identify and structure -----------------------------------------------------------------------------------------------
  let ast = null;
  let detection = null;
  const parsed = tryParse(source);
  if (!parsed.ok) return { ok: false, stage: 'parse', error: parsed.error, output: null, steps: [], detection: detect(source), warnings: [], nexus: { version: NEXUS_VERSION, stages, ledger: { claims: [], summary: ledger.summary() } } };
  ast = parsed.ast;
  const environment = { kind: 'standalone', apis: [] };
  stage('identify', 'Identify the language and the environment', (s) => {
    detection = detect(source, ast);
    const info = analyze(ast);
    const g = new Set(info.globals.keys());
    const roblox = ['game', 'workspace', 'Instance', 'task', 'Enum', 'script'].filter((x) => g.has(x));
    environment.apis = roblox;
    environment.kind = roblox.length ? 'roblox' : 'standalone';
    s.notes.push(`Dialect: ${detection.dialect.label} (${Math.round(detection.dialect.confidence * 100)}%).`);
    s.notes.push(environment.kind === 'roblox' ? `Roblox environment: ${roblox.join(', ')}.` : 'No Roblox globals are used.');
    if (detection.families.length) s.notes.push(`Obfuscator families recognised: ${detection.families.map((f) => f.name).join(', ')}.`);
  });
  const structure = {};
  stage('structure', 'Map the structure', (s) => {
    const info = analyze(ast);
    structure.variables = info.vars.length;
    structure.functions = info.funcs.length;
    structure.nodes = detection ? detection.metrics.nodes : 0;
    s.notes.push(`${structure.functions} functions, ${structure.variables} local variables, ${structure.nodes} syntax nodes.`);
  });

  // 4 ---- semantic ------------------------------------------------------------------------------------------------------------------
  let trivia = null;
  let relations = null;
  stage('semantic', 'Read the comments and map the relations', (s) => {
    trivia = analyzeTrivia(source);
    s.notes.push(trivia.verdict === 'none' ? 'No comments.' : trivia.verdict === 'documentation' ? `${trivia.comments} comments, read as documentation and kept.` : `${trivia.comments} comments read as fragments of a repeated sentence.`);
    if (source.length <= options.maxBytes) {
      relations = mapRelations(ast);
      s.notes.push(`${relations.suggestions.size} names suggested from relations, ${relations.dependencies.length} fetch(es), ${relations.functions.length} named functions, ${relations.calls.length} call edges.`);
    } else s.requests.push({ need: 'relations', why: 'skipped: input too large' });
  });

  // 5, 6, 7 ---- classify, flow, dependencies -----------------------------------------------------------------------------------------
  let transformations = [];
  stage('classify', 'Classify the transformations', (s) => {
    transformations = classify({ source, detection, trivia, relations });
    s.notes.push(transformations.length ? transformations.map((t) => `${t.label} (${Math.round(t.confidence * 100)}%)`).join('; ') : 'No transformation recognised.');
  });
  let flow = null;
  let flowAfter = null;
  stage('flow', 'Analyse the control flow', (s) => {
    flow = controlFlow(ast);
    s.notes.push(`${flow.totals.functions} functions, ${flow.totals.loops} loops, total complexity ${flow.totals.complexity}, deepest nesting ${flow.totals.maxDepth}.`);
    // what the input shows. Whether a shape is a problem is decided on the result (stage 9): the recovery may have rebuilt it
    for (const sh of flow.shapes) s.notes.push(`${sh.kind} at line ${sh.line}: ${sh.supported ? 'a shape the structure reader rebuilds' : 'a shape this engine does not rebuild'}.`);
  });
  stage('dependencies', 'Investigate the dependencies', (s) => {
    if (!relations) return;
    const urls = [...new Set(relations.dependencies.map((d) => d.url).filter(Boolean))];
    if (urls.length) s.notes.push(`Fetches: ${urls.join(', ')}.`);
    if (relations.executorApis.length) s.notes.push(`Executor APIs: ${relations.executorApis.join(', ')}.`);
    if (relations.globalsWritten.size) s.notes.push(`Writes to the shared environment: ${[...relations.globalsWritten.keys()].join(', ')}.`);
    const code = relations.dependencies.filter((d) => d.loadsCode);
    if (code.length) {
      ledger.unresolved('dependency.remote-code', `${new Set(code.map((d) => d.url || d.expr)).size} piece(s) of code are fetched and run when the script runs; they are not part of this file and were not analysed.`, urls);
      needs.push({ need: 'dependency', why: 'Fetched code is not in this file. Analyse each fetched file on its own.', items: urls });
    }
  });

  // 8 ---- reconstruct ---------------------------------------------------------------------------------------------------------------
  let working = source;
  let inner = null;
  const passes = [];
  const mergedSteps = new Map();
  const roles = new Roles();
  const alpha = [];
  let adaptiveWork = null;
  let strippedComments = 0;
  const rec = stage('reconstruct', 'Reconstruct', (s) => {
    // comments: only when they were read as fragments, and only after the program is shown to be the same with and without them
    if (trivia && trivia.verdict === 'fragmented-message') {
      const a2 = parse(source);
      stripComments(a2, trivia.noise);                 // the ones the parser attached to statements; the others never reach the tree and are not printed
      const cleaned = print(a2);
      if (sameProgram(source, cleaned)) {
        working = cleaned;
        strippedComments = trivia.noise.size;
        ledger.verified('trivia.equivalent', `The ${strippedComments} comments that held a split sentence were removed; the program is the same with and without them.`, 'the syntax trees of the text before and after are identical once layout and comments are ignored');
        s.notes.push(`Removed ${strippedComments} fragment comments (syntax trees identical).`);
      } else {
        ledger.inconsistent('trivia.equivalent', 'Removing the comments changed the syntax tree, so they were kept.');
        strippedComments = 0;
      }
    }
    for (let n = 1; n <= options.passes; n++) {
      // the hints are made from the tree the renamer is looking at, at the moment it renames, so the nodes they are keyed on are the right ones
      const held = { map: null, before: null };
      const r = recover(working, { ...options.recover, annotate: false, roleHints: relations ? (a) => { held.before = clone(a); held.map = new Roles(mapRelations(a).suggestions); return held.map; } : null });
      if (!r.ok) { s.notes.push(`Pass ${n}: ${r.stage || 'recovery'} failed${r.error ? ` (${r.error.message})` : ''}.`); if (!inner) throw new Error(r.error ? r.error.message : 'recovery failed'); break; }
      for (const st of r.steps) {
        const m = mergedSteps.get(st.id);
        if (!m) mergedSteps.set(st.id, { ...st }); else { m.changed += st.changed || 0; m.rounds = (m.rounds || 0) + (st.rounds || 0); if (st.status === 'applied') m.status = 'applied'; if (st.status === 'failed') { m.status = 'failed'; m.error = st.error; } }
      }
      if (held.map) for (const v of held.map.used) roles.used.add(v);
      // renaming may change names and nothing else: the tree before the renamer ran and the printed result must bind every use to the same declaration
      if (held.before && held.map && held.map.used.size) {
        // both sides go through the same print and parse, so that how the printer writes a literal (`-1` is read back as a negation) is not mistaken for a difference
        let after = null;
        let before = null;
        try {
          const fmt = { ...(options.recover.format || {}), strings: options.recover.stringStyle || 'normalize', numbers: options.recover.stringStyle || 'normalize' };
          before = parse(print(held.before, fmt));
          after = parse(r.output);
        } catch { /* counted as not confirmed */ }
        alpha.push(!!(before && after) && sameBindings(before, after));
      }
      const changed = r.output !== working;
      const profile = classify({ source: r.output, detection: r.detection, trivia: null, relations: null });
      const residual = residualOf(profile);
      passes.push({ n, changed, residual: Math.round(residual * 100) / 100, steps: r.steps.filter((x) => x.status === 'applied' && x.changed).length, ms: Math.round(r.ms) });
      inner = r;
      if (!adaptiveWork && r.adaptive && r.adaptive.ran && r.adaptive.hypotheses.length) adaptiveWork = r.adaptive;
      // a pass can make the next one possible (renaming removes the name clash that kept a block from being unwrapped), so go on until a pass changes nothing
      const stop = !changed || n >= options.passes;
      s.notes.push(`Pass ${n}: ${changed ? 'changed the text' : 'no change'}, residual transformation weight ${residual.toFixed(2)}${stop ? (changed ? ' (pass limit)' : ' (fixed point)') : ' (another pass)'}.`);
      working = r.output;
      if (stop) break;
    }
  });
  if (!inner) return fallback(rec.error || 'no reconstruction pass succeeded');

  // what the structure reader saw and did is in the pass that did it; what is left is in the last one
  const adaptive = adaptiveWork && inner.adaptive
    ? { ...adaptiveWork, residual: inner.adaptive.residual, blocked: inner.adaptive.blocked, score: { ...adaptiveWork.score, after: inner.adaptive.score.after, partsAfter: inner.adaptive.score.partsAfter }, ms: adaptiveWork.ms + inner.adaptive.ms }
    : inner.adaptive;

  // 9 ---- verify --------------------------------------------------------------------------------------------------------------------
  let code = working;
  let validation = null;
  stage('verify', 'Verify', (s) => {
    validation = validateOutput(code, null);
    if (validation.ok) ledger.verified('output.parses', 'The result parses, and printing it again gives the same text.', 'parse and print round trip');
    else ledger.inconsistent('output.parses', validation.message);

    // control flow that is still here in the result and that this engine does not rebuild
    try {
      flowAfter = controlFlow(parse(code));
      for (const sh of flowAfter.shapes.filter((x) => !x.supported)) {
        ledger.unresolved(`flow.${sh.kind}`, `A ${sh.kind} at line ${sh.line} of the result is not rebuilt: ${sh.note}.`, sh.evidence);
        s.requests.push({ need: 'manual', why: `${sh.kind} at line ${sh.line}: ${sh.note}` });
      }
    } catch { /* the validation above already says so */ }

    const extra = newGlobals(source, code);
    if (extra && extra.length) ledger.inconsistent('output.new-globals', `The result uses global names the input did not: ${extra.join(', ')}.`, extra);
    else if (extra) ledger.verified('output.no-new-globals', 'The result reads and writes no global name that the input did not.', 'free names of both programs compared');

    // names: a rule reached them, so they stay "inferred", whatever the evidence
    let applied = 0;
    for (const sug of roles.used) {
      applied++;
      ledger.inferred(`name:${sug.original}->${sug.name}`, `A variable that was called "${sug.original}" is named ${sug.name}.`, [`rule ${sug.rule}`, ...sug.evidence], sug.confidence);
    }
    s.notes.push(`${applied} names were chosen from relations (inferred, not original).`);
    if (alpha.length) {
      if (alpha.every(Boolean)) ledger.verified('names.alpha-renaming', 'Naming changed only the names of local variables: with every local replaced by the number of its declaration, the program before naming and the result are identical, so no name captures or shadows another.', 'binding structure compared before and after the renamer');
      else ledger.unresolved('names.alpha-renaming', 'Could not confirm that naming changed only variable names: a later step rewrote declarations after the renamer ran.');
    }

    if (options.runtime) {
      let v = verifyRecovery(source, code, options.runtimeLimits || {});
      // an error message names the variable it was about (`local 'a'`), and naming changed the variable: the same error, said with another name, is not a difference
      const bare = (t) => String(t).replace(/\((?:local|global|upvalue|field|method|constant) '[^']*'\)/g, '').replace(/\btrace:\d+:\s*/g, '').trim();
      const d = v.verdict === 'different' && v.difference;
      if (d && d.index === -1 && /^error:/.test(d.original) && /^error:/.test(d.recovered) && bare(d.original) === bare(d.recovered)) {
        v = { ...v, verdict: 'identical', summary: 'Both programs stopped with the same error (the variable it names is called something else after renaming).' };
      }
      s.notes.push(`Behaviour check: ${v.verdict}.`);
      const early = (x) => x && x.status !== 'completed';
      if (v.verdict === 'identical' && (early(v.original) || v.original.events < 3)) {
        ledger.unresolved('behaviour.shallow', `Both programs behaved the same in the sandbox, but the run was shallow (the original ended with status "${v.original.status}" after ${v.original.events} recorded event(s)), so it says little about the rest of the program.`, v.notes);
      } else if (v.verdict === 'identical') ledger.verified('behaviour.identical', v.summary, 'both programs ran in the sandbox against the stand-in environment and did the same thing (one run each; evidence, not proof)');
      else if (v.verdict === 'different') ledger.inconsistent('behaviour.different', v.summary, v.difference ? [`${v.difference.original} / ${v.difference.recovered}`] : []);
      else ledger.unresolved('behaviour.inconclusive', v.summary, v.notes);
    } else {
      s.requests.push({ need: 'runtime', why: 'Run the original and the result in the sandbox and compare (asks first).' });
    }
  });

  // 10 ---- generate ------------------------------------------------------------------------------------------------------------------
  const steps = [...mergedSteps.values()];
  let confidence = null;
  let report = null;
  let output = code;
  stage('generate', 'Generate the result', (s) => {
    let finalAst = null;
    try { finalAst = parse(code); } catch { /* the validation above already says so */ }
    const base = assessConfidence(detection, code, { steps, validation, ast: finalAst, adaptive });
    const lowered = ledger.level(base);
    confidence = { ...base, level: lowered.level, score: Math.round(lowered.score * 100) / 100, base: { score: base.score, level: base.level }, loweredBy: lowered.lowered };
    report = buildReport({ detection, steps, confidence, adaptive });

    const extra = [];
    if (strippedComments) {
      extra.push(...wrap(`NEXUS: ${strippedComments} comments between the tokens held a sentence cut into pieces${trivia.metrics.repeats > 1 ? `, repeated ${trivia.metrics.repeats} times` : ''}. They were removed after checking that the program is the same with and without them.`, '-- ', '--   '));
    }
    if (trivia && trivia.directives.length) {
      extra.push(...wrap(`NEXUS: ${trivia.directives.length} sentence(s) in the comments addressed AI tools. They are text inside the file, not a request from the person using it, and were not followed. They are listed in the NEXUS panel and left out of this output.`, '-- ', '--   '));
    }
    if (roles.used.size) extra.push(...wrap(`NEXUS: ${roles.used.size} variable names were chosen from how the code uses them. They are inferred, not the original names.`, '-- ', '--   '));
    if (relations) {
      const urls = [...new Set(relations.dependencies.map((d) => d.url).filter(Boolean))];
      if (urls.length) extra.push(...wrap(`NEXUS: depends on ${urls.length} fetched URL(s): ${urls.slice(0, 4).join(', ')}${urls.length > 4 ? ', ...' : ''}.`, '-- ', '--   '));
    }
    for (const c of ledger.get('unresolved').filter((x) => !/^dependency\./.test(x.id)).slice(0, 4)) extra.push(...wrap(`NEXUS, not settled: ${c.statement}`, '-- ', '--   '));
    for (const c of ledger.get('inconsistent').slice(0, 3)) extra.push(...wrap(`NEXUS, check failed: ${c.statement}`, '-- ', '--   '));

    const show = (options.recover.annotate !== false) && (report.show || extra.length > 0);
    if (show) {
      const lines = report.lines.slice();
      const end = lines.pop();                      // the closing marker
      output = `${[...lines, ...extra, end].join('\n')}\n\n${code}`;
    }
    s.notes.push(`${ledger.summary().verified} verified, ${ledger.summary().inferred} inferred, ${ledger.summary().unresolved} unresolved, ${ledger.summary().inconsistent} failed.`);
  });

  for (const h of (confidence && confidence.hints) || []) needs.push({ need: h, why: h === 'sandbox' ? 'Switch the sandbox on so decoders can be evaluated.' : 'Trace the script in the sandbox to see what one run does.' });
  for (const st of stages) for (const r of st.requests) if (!needs.some((x) => x.need === r.need && x.why === r.why)) needs.push(r);

  return {
    ok: !!validation && validation.ok,
    output,
    steps,
    detection,
    validation,
    confidence,
    adaptive,
    report,
    warnings: inner.warnings.concat(state.failed ? [`NEXUS stage "${state.failed.stage}" failed: ${state.failed.error}`] : []),
    ms: now() - t0,
    nexus: {
      version: NEXUS_VERSION,
      facts, environment, structure, stages, passes,
      transformations,
      trivia: trivia ? { verdict: trivia.verdict, comments: trivia.comments, removed: strippedComments, message: trivia.message, directives: trivia.directives, metrics: trivia.metrics } : null,
      relations: relations ? {
        dependencies: relations.dependencies, executorApis: relations.executorApis, globalsWritten: [...relations.globalsWritten.keys()], freeGlobals: relations.freeGlobals,
        functions: relations.functions.map((f) => ({ id: f.id, line: f.line, params: f.params })), calls: relations.calls,
      } : null,
      roles: { suggested: relations ? relations.suggestions.size : 0, applied: [...roles.used].map((r) => ({ from: r.original, to: r.name, rule: r.rule, confidence: r.confidence, evidence: r.evidence })) },
      controlFlow: flowAfter || flow,
      controlFlowInput: flow,
      ledger: { claims: ledger.claims, summary: ledger.summary() },
      needs, limits,
    },
  };
}
