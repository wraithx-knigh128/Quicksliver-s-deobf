// The engine's public surface. Every function takes a binary string (see core/bytes.js) and returns
// plain, structured-clone-safe data, so the same calls work on the main thread, in the web worker and
// from Node (tests, tooling).

import { parse, LuaSyntaxError } from './core/parser.js';
import { print } from './core/printer.js';
import { formatTokens } from './core/format-tokens.js';
import { detect } from './detect/detect.js';
import { FAMILIES } from './detect/families.js';
import { analyzeScript } from './analyze/report.js';
import { toLuast } from './analyze/luast.js';
import { recover } from './recover/pipeline.js';
import { nexusRecover } from './nexus/pipeline.js';
import { observe } from './research/signature.js';
import { advise } from './research/advisor.js';
import { identify } from './research/identify.js';
import { registryFromData } from './research/families.js';
import { diffLines, toRows } from './core/diff.js';
import { traceScript } from './trace/trace.js';
import { renamePass } from './passes/rename.js';
import { originAnalysis } from './origin/index.js';
import { verifyRecovery } from './adaptive/verify.js';
import { analyzeCustom } from './custom/analyze.js';
import { analyzeLoader, classifyStage } from './loader/analyze.js';
import { decodePayload } from './loader/payload.js';
import { analyzeLuarmor } from './loader/luarmor.js';
import { binaryToBytes } from './core/bytes.js';
import { recoveryOutcome } from './validate/evidence.js';
import { parseChunk } from './sandbox/bytecode.js';
import { decompile } from './decompile/decompile.js';
import { buildReport, annotate } from './recover/annotate.js';
import { classifyOutcome } from './validate/outcome.js';

export const ENGINE_VERSION = '1.0.0';

const now = () => (typeof performance !== 'undefined' ? performance.now() : Date.now());
const timed = (fn) => { const t = now(); const r = fn(); r.ms = Math.round(now() - t); return r; };

/** Classify raw input before doing anything with it. */
export function inspectInput(source) {
  if (source.charCodeAt(0) === 27) {
    const d = detect(source);
    return { kind: 'bytecode', detail: d.bytecode, message: 'This is a compiled Lua chunk, not source text.' };
  }
  let ctrl = 0;
  const n = Math.min(source.length, 4096);
  for (let i = 0; i < n; i++) { const c = source.charCodeAt(i); if (c < 9 || (c > 13 && c < 32)) ctrl++; }
  if (n && ctrl / n > 0.05) return { kind: 'binary', message: 'The input contains many control characters and does not look like Lua source.' };
  return { kind: 'text' };
}

export function detectScript(source) {
  return timed(() => ({ ok: true, detection: detect(source) }));
}

/**
 * Format only: nothing is decoded or removed. Parseable code goes through the AST printer; code that does
 * not parse is re-flowed token by token, and the result says which of the two happened.
 * @param {{indent?: string, width?: number, blankLines?: string}} [options]
 */
export function beautifyScript(source, options = {}) {
  return timed(() => {
    const printOptions = {
      indent: options.indent ?? '  ',
      width: options.width ?? 100,
      blankLines: options.blankLines ?? 'smart',
      strings: 'preserve',
      numbers: 'preserve',
    };
    try {
      const ast = parse(source);
      return { ok: true, mode: 'ast', output: print(ast, printOptions), warnings: [] };
    } catch (e) {
      if (!(e instanceof LuaSyntaxError)) throw e;
      const text = formatTokens(source, { indent: printOptions.indent });
      if (text === null) return { ok: false, mode: 'none', error: { message: e.message, line: e.line, col: e.col }, output: null, warnings: [] };
      return {
        ok: true,
        mode: 'tokens',
        output: text,
        parseError: { message: e.message, line: e.line, col: e.col },
        warnings: [`The code does not parse (${e.message}), so only its layout was repaired token by token.`],
      };
    }
  });
}

export function analyzeSource(source) {
  return timed(() => analyzeScript(source));
}

/**
 * Recover readable source. With `options.nexus` the recovery runs inside the NEXUS pipeline (src/nexus/): the same recovery steps, preceded by
 * trivia and relation analysis and followed by a verification ledger; everything else in `options` is handed to recover() unchanged.
 */
export function recoverSource(source, options = {}) {
  const { nexus, nexusPasses, nexusRuntime, ...rest } = options;
  const onStage = typeof rest.onProgress === 'function' ? (st) => rest.onProgress({ phase: 'nexus', label: st.title, done: st.index, total: st.total }) : undefined;
  return timed(() => withOutcome(source, nexus ? nexusRecover(source, { passes: nexusPasses || undefined, runtime: !!nexusRuntime, onStage, recover: rest }) : recover(source, rest)));
}

/**
 * Every recovery carries its outcome class (src/validate/outcome.js) next to the engine's confidence estimate. Before a behaviour
 * comparison the best class a recovery can reach is "syntax-valid but behaviourally unverified": the confidence alone never makes a
 * result "validated".
 */
function withOutcome(source, r) {
  try { r.outcome = recoveryOutcome(source, r); } catch (e) { r.outcome = { outcome: 'not-deobfuscated', label: 'Received but not successfully deobfuscated', success: false, reasons: [`The result could not be classified: ${e.message || e}`], met: [] }; }
  return r;
}

/**
 * The outcome after a behaviour comparison: `options.evidence` is the outcome.evidence of the recovery, `options.behaviour` the comparison
 * ({ verdict, against, note }). Pure; nothing is run here.
 */
export function outcomeWithBehaviour(_source, options = {}) {
  return timed(() => ({ ok: true, ...classifyOutcome({ ...(options.evidence || {}), behaviour: options.behaviour || null }) }));
}

/**
 * What this input shows from the outside, and which reconstruction plan the laboratory's verified experiments support for it.
 * `options.summary` is data/research/summary.json and `options.families` is data/research/custom-families.json (both fetched by the page).
 * Nothing is run: the script is parsed and measured, not executed.
 */
export function adviseSource(source, options = {}) {
  return timed(() => {
    const registry = options.families ? registryFromData(options.families) : null;
    const seen = observe(source, { registry });
    return { ok: true, observed: seen, advice: advise(seen.tokens, options.summary || null, { allowSandbox: !!options.allowSandbox, nexus: options.nexus ?? null }) };
  });
}

/**
 * Which system (and, where the evidence supports it, which version) this input shows, and what the engine may claim about it.
 * `options.profiles` is data/research/profiles.json and `options.capabilities` the `capabilities` array of data/research/capabilities.json.
 * Nothing is run: the script is read, not executed.
 */
export function identifySource(source, options = {}) {
  return timed(() => {
    if (!options.profiles) return { ok: false, error: 'The compatibility profiles were not loaded.' };
    const detection = options.detection || detect(source);
    return { ok: true, ...identify(source, { detection, profiles: options.profiles, capabilities: options.capabilities || null }) };
  });
}

/** Custom-format analysis: what the script was made into, the plan, the recovery and what is left (see src/custom/analyze.js). */
export function customAnalyzeSource(source, options = {}) {
  return timed(() => analyzeCustom(source, options));
}

/** The NEXUS pipeline on its own, with its own options (see src/nexus/pipeline.js). */
export function nexusSource(source, options = {}) {
  return timed(() => nexusRecover(source, options));
}

export function luast(source, options = {}) {
  return timed(() => {
    try {
      return { ok: true, ...toLuast(parse(source), options) };
    } catch (e) {
      if (!(e instanceof LuaSyntaxError)) throw e;
      return { ok: false, error: { message: e.message, line: e.line, col: e.col } };
    }
  });
}

/**
 * Run the script in the instrumented sandbox and report what it did (see trace/trace.js). This is the only
 * operation that executes anything; the interface asks the user first.
 */
export function traceSource(source, options = {}) {
  return timed(() => traceScript(source, options));
}

/**
 * Give machine-made local names readable ones, and change nothing else (the layout is the printer's).
 * @param {{indent?: string, width?: number, mode?: 'smart'|'all'}} [options]
 */
export function renameScript(source, options = {}) {
  return timed(() => {
    let ast;
    try { ast = parse(source); } catch (e) {
      if (!(e instanceof LuaSyntaxError)) throw e;
      return { ok: false, error: { message: e.message, line: e.line, col: e.col }, output: null, renamed: 0 };
    }
    const r = renamePass(ast, { mode: options.mode || 'smart' });
    const output = print(ast, { indent: options.indent ?? '  ', width: options.width ?? 100, blankLines: 'smart', strings: 'preserve', numbers: 'preserve' });
    return { ok: true, output, renamed: r.renamed || 0 };
  });
}

/**
 * The text a script builds before it runs it. Runs the script in the sandbox (the interface asks first), keeps every chunk
 * handed to load/loadstring and every long `table.concat` result, and says which one looks like the real payload: the last
 * chunk that parses as Lua, or else the longest text. Like trace, this is a description of one run.
 */
export function dumpSource(source, options = {}) {
  return timed(() => {
    const t = traceScript(source, { fuel: 150_000_000, timeMs: 45_000, captureConcat: true, callHandlers: false, ...options });
    const candidates = [
      ...t.layers.map((l) => ({ kind: 'chunk', n: l.index, source: l.source })),
      ...t.concats.map((c) => ({ kind: 'concat', n: c.index, source: c.source })),
    ].map((c, id) => {
      let parses = false;
      try { parse(c.source); parses = true; } catch { /* not Lua */ }
      return { id, kind: c.kind, label: c.kind === 'chunk' ? `loaded chunk ${c.n}` : `table.concat result ${c.n}`, bytes: c.source.length, parses, source: c.source };
    });
    const parsing = candidates.filter((c) => c.parses && c.kind === 'chunk');
    const best = parsing.length ? parsing[parsing.length - 1]
      : candidates.filter((c) => c.parses).sort((a, b) => b.bytes - a.bytes)[0] || candidates.sort((a, b) => b.bytes - a.bytes)[0] || null;
    return { ok: t.ok, status: t.status, ended: t.ended, error: t.error, candidates, best: best ? best.id : null, requests: t.requests, stats: t.stats, output: t.output };
  });
}

/**
 * Run the original and the recovered program in the sandbox (the interface asks first) and compare what each one did. `options.recovered`
 * is the recovered text.
 */
/**
 * Prompt XXIX: a server engine's result (api/engine.js) turned into a QuickSilver result. `source` is the Lua 5.1 bytecode the engine rebuilt
 * (a binary string); `options.original` is the protected script it came from. The bytecode is decompiled by QuickSilver's own decompiler
 * (src/decompile), cleaned by the ordinary passes, and classified against the original exactly as a lift by one of QuickSilver's own VM readers
 * is: functions the decompiler could not structure are listed as unresolved, and the engine's part is recorded as a step of its own.
 * @param {string} source binary string: a Lua 5.1 chunk
 * @param {{original: string, engine: string, label: string, family: string, licence?: string, recover?: object}} options
 */
export function recoverFromBytecode(source, options = {}) {
  return timed(() => {
    const original = options.original ?? '';
    let chunk;
    try { chunk = parseChunk(source); } catch (e) { return { ok: false, error: { message: `The engine's bytecode could not be read: ${e.message || e}` }, output: null, steps: [], detection: detect(original), warnings: [] }; }
    const count = (f, acc = { functions: 0, instructions: 0, constants: 0 }) => {
      acc.functions++; acc.instructions += (f.code || []).length; acc.constants += (f.constants || f.k || []).length;
      for (const p of f.protos || f.p || []) count(p, acc);
      return acc;
    };
    const stats = count(chunk.main);
    const d = decompile(chunk);
    const decompiled = print(d.ast);
    // the ordinary passes clean the decompiled program (names from evidence, idioms); nothing of the original's VM is left for them to undo
    const inner = recover(decompiled, { ...(options.recover || {}), annotate: false, sandbox: { enabled: false } });
    const steps = [
      { id: `${options.engine}.engine`, label: options.label || 'Rebuild the program with a server engine', status: 'applied', changed: stats.instructions, detail: { engine: options.engine, licence: options.licence || null, ...stats } },
      { id: 'decompile.bytecode', label: 'Decompile the rebuilt Lua 5.1 bytecode (QuickSilver decompiler)', status: d.failures.length ? 'partial' : 'applied', changed: stats.functions - d.failures.length, detail: { functions: stats.functions, failures: d.failures.length } },
      ...(inner.steps || []),
    ];
    const detection = detect(original);
    // the engine found the VM in the script and read a well-formed Lua 5.1 program out of it: that is the format's structure, checked
    const fam = (detection.families || []).find((f) => f.id === options.family);
    if (fam) {
      fam.evidence = [...(fam.evidence || []), { rule: 'engine', kind: 'structure', text: `the server engine ${options.engine} found its virtual machine and read a well-formed Lua 5.1 program (${stats.functions} functions) out of it`, weight: 0.9 }];
      fam.evidenceLevel = 'structure';
    }
    // The inner passes saw an ordinary program (the decompiler's output), so their confidence knows nothing of where it came from: the
    // "no obfuscation was detected" line is dropped, and what the engine did and did not establish is said, with its cost to the score.
    // A rebuilt program whose behaviour was not compared with the original tops out at medium; a later behaviour comparison
    // (unified.js) is what can confirm it.
    const base = inner.confidence || { level: 'medium', score: 0.6, reasons: [] };
    const reasons = (base.reasons || []).filter((x) => !/^No obfuscation was detected/.test(x.text));
    // a statement of what was established, not a place left unresolved (the outcome class says "unverified"); its cost is in the score below
    reasons.unshift({ effect: 0, text: `The program was rebuilt from the VM's own data by a third-party server engine (${options.engine}${options.licence ? `, ${String(options.licence).split(':')[0]}` : ''}) without running it, and its Lua 5.1 bytecode was decompiled by QuickSilver. This is not a comparison with a run of the original: until one is made, its behaviour is unverified.` });
    if (d.failures.length) reasons.push({ effect: -0.1 * Math.min(d.failures.length, 4), text: `${d.failures.length} of ${stats.functions} function(s) could not be decompiled; they are marked in the output with their instruction count.` });
    const score = Math.round(Math.max(0.05, Math.min(base.score ?? 0.6, 0.95) - 0.15 - 0.1 * Math.min(d.failures.length, 4)) * 100) / 100;
    const confidence = { ...base, score, level: score >= 0.85 ? 'high' : score >= 0.6 ? 'medium' : score > 0.25 ? 'low' : 'minimal', reasons };
    const vm = { kind: options.family || options.engine, label: options.familyLabel || null, licence: options.licence || null, lifted: true, engine: options.engine, stats: { functions: stats.functions, instructions: stats.instructions, constants: stats.constants, undecompiled: d.failures.length } };
    const report = buildReport({ detection, steps, confidence, adaptive: inner.adaptive || null, vm });
    for (const f of d.failures) report.unresolved.push({ source: 'decompile', text: f });
    const clean = inner.output != null ? inner.output : decompiled;
    const r = { ok: true, output: annotate(clean, report), steps, detection, confidence, adaptive: inner.adaptive || null, vm, report, warnings: inner.warnings || [], engine: options.engine };
    r.outcome = recoveryOutcome(original, r);
    return r;
  });
}

/**
 * Prompt XXIX: the page's half of a server engine that answers with Lua source (the Prometheus VM engine). The source is cleaned by the
 * ordinary passes and reported with what produced it; it is never classified above "unverified" here — unified.js uses it only after a
 * behaviour comparison with the script (src/pipeline/engines.js, verify.required).
 * @param {string} engineSource the engine's Lua source (binary string)
 * @param {{original: string, engine: string, label?: string, family?: string, familyLabel?: string, licence?: string, recover?: object}} options
 */
export function recoverFromSource(engineSource, options = {}) {
  return timed(() => {
    const original = options.original ?? '';
    try { parse(engineSource); } catch (e) { return { ok: false, error: { message: `The engine's Lua does not parse: ${e.message || e}` }, output: null, steps: [], detection: detect(original), warnings: [] }; }
    const inner = recover(engineSource, { ...(options.recover || {}), annotate: false, sandbox: { enabled: false } });
    const steps = [
      { id: `${options.engine}.engine`, label: options.label || 'Rebuild the program with a server engine', status: 'applied', changed: engineSource.split('\n').length, detail: { engine: options.engine, licence: options.licence || null, bytes: engineSource.length } },
      ...(inner.steps || []),
    ];
    const detection = detect(original);
    const fam = (detection.families || []).find((f) => f.id === options.family);
    if (fam) {
      fam.evidence = [...(fam.evidence || []), { rule: 'engine', kind: 'structure', text: `the server engine ${options.engine} found its virtual machine and lifted it to Lua that parses`, weight: 0.9 }];
      fam.evidenceLevel = 'structure';
    }
    const base = inner.confidence || { level: 'medium', score: 0.6, reasons: [] };
    const reasons = (base.reasons || []).filter((x) => !/^No obfuscation was detected/.test(x.text));
    reasons.unshift({ effect: 0, text: `The program was lifted from the VM by a third-party server engine (${options.engine}${options.licence ? `, ${String(options.licence).split(':')[0]}` : ''}), which reads the VM's own data and folds expressions in its own small interpreter; nothing of the script reaches the host. The engine is wrong on some builds (docs/REPORT-XXIX.md), so its program is used only when a behaviour comparison with the script itself agrees.` });
    const score = Math.round(Math.max(0.05, Math.min(base.score ?? 0.6, 0.95) - 0.15) * 100) / 100;
    const confidence = { ...base, score, level: score >= 0.85 ? 'high' : score >= 0.6 ? 'medium' : score > 0.25 ? 'low' : 'minimal', reasons };
    const vm = { kind: options.family || options.engine, label: options.familyLabel || null, licence: options.licence || null, lifted: true, engine: options.engine, output: 'lua-source', stats: { bytes: engineSource.length } };
    const report = buildReport({ detection, steps, confidence, adaptive: inner.adaptive || null, vm });
    const clean = inner.output != null ? inner.output : engineSource;
    const r = { ok: true, output: annotate(clean, report), steps, detection, confidence, adaptive: inner.adaptive || null, vm, report, warnings: inner.warnings || [], engine: options.engine };
    r.outcome = recoveryOutcome(original, r);
    return r;
  });
}

export function verifySource(source, options = {}) {
  if (typeof options.recovered !== 'string') return timed(() => ({ ok: false, error: 'There is no recovered program to compare with; recover the script first.' }));
  return timed(() => verifyRecovery(source, options.recovered, options));
}

/**
 * Loader Analysis (src/loader/analyze.js): what the script fetches, from where, and whether that payload can be obtained through an authorised
 * route. Static only: nothing is run or fetched here. `options.recovered` (the recovered text, when the input was obfuscated) is analysed too,
 * because an obfuscated loader often shows its requests only after the obfuscation is removed.
 */
export function loaderSource(source, options = {}) {
  return timed(() => {
    const input = analyzeLoader(source, { origin: options.origin || 'input', depth: options.depth || 0, providers: options.providers || [] });
    const recovered = typeof options.recovered === 'string' && options.recovered !== source ? analyzeLoader(options.recovered, { origin: 'recovered', depth: options.depth || 0, providers: options.providers || [] }) : null;
    const resolved = (a) => (a ? a.requests.filter((r) => r.urlKind === 'literal' || r.urlKind === 'encoded').length * 10 + a.requests.length : -1);
    const best = recovered && resolved(recovered) > resolved(input) ? 'recovered' : 'input';
    // Luarmor: a dedicated reading of the loader's local structure (src/loader/luarmor.js), on the text where it is visible
    let luarmor = null;
    try { luarmor = analyzeLuarmor(best === 'recovered' ? options.recovered : source) || (best === 'recovered' ? analyzeLuarmor(source) : null); } catch { luarmor = null; }
    return { ok: true, input, recovered, best, luarmor };
  });
}

/** Loader analysis of one text, without the recovered-text variant (Loader Intelligence calls this per stage). */
export function loaderAnalyze(source, options = {}) {
  return analyzeLoader(source, options);
}

/** Peel the transport layers off a retrieved body (src/loader/payload.js); `source` is the body as a binary string. */
export function payloadDecode(source, options = {}) {
  return timed(() => ({ ok: true, ...decodePayload(binaryToBytes(source), options) }));
}

/** What a downloaded stage is (compiled chunk, web page, another loader, a script) before it is handed to the pipeline. */
export function loaderStage(source) {
  return timed(() => ({ ok: true, ...classifyStage(source) }));
}

/** Local half of the origin check: style signals, hints of other authors, and the lines worth searching for online. */
export function originCheck(source) {
  return timed(() => ({ ok: true, ...originAnalysis(source) }));
}

/** Line diff of two texts, as side-by-side rows (see core/diff.js). */
export function diffSources(a, b) {
  return timed(() => {
    const A = a.split(/\r?\n/);
    const B = b.split(/\r?\n/);
    return { ok: true, ...toRows(diffLines(A, B)), aLines: A.length, bLines: B.length };
  });
}

/** Static description of every known family, for the compatibility dashboard. */
export function familyRegistry() {
  return Object.entries(FAMILIES).map(([id, f]) => ({ id, ...f }));
}
