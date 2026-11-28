// The one Deobfuscate pipeline (Prompt XXVIII). Whatever the user submits — a .lua / .luau file, pasted source, a loadstring, a GitHub file,
// raw, API or gist link, a repository, or another supported link — goes through the same fourteen stages, and the result is the
// reconstructed program the input leads to, with a report of every stage. The VM lifters, the loader analysis and the GitHub retrieval are
// internal parts of this pipeline, not separate tools.
//
//   1 recognise        what was submitted                                       (src/loader/github.js recognizeInput)
//   2 loader           whether the program is in the input or fetched at run time (src/loader/analyze.js, through deps.analyze)
//   3 address          where each address points, and whether an authorised route reaches it
//   4 retrieve         GitHub through /api/github, other public hosts through /api/fetch (through deps.github / deps.fetchLink)
//   5 payload          what came back: Lua, compiled code, a model, or not code at all (src/loader/payload.js, through deps.decode)
//                      and what role it plays: obfuscated program, secondary loader (followed), dependency, configuration, plain source
//   6 detect           which protection and version                              (src/detect, through deps.detect)
//   7–12               the reconstruction itself (src/api.js recoverSource, through deps.recover): its steps are reported as
//                      transformation analysis, strings and constants, VM / bytecode, control and data flow, functions and expressions,
//                      and source generation
//  13 validate         syntax, residual protection, unresolved instructions, empty bodies, placeholder names; behaviour when compared
//  14 deliver          the reconstructed payload — never the loader in its place, never a file presented as more than it is
//
// The module does no I/O of its own: the page passes functions that call the engine worker and the site's server functions, the tests pass
// direct ones and mocks. Nothing is retrieved without an authorised route, nothing retrieved is run, and a retrieval that returned only the
// loader is reported as such.

import { recognizeInput, parseGitHubRef, isGitHubLink, OUTCOMES as GH_OUTCOMES } from '../loader/github.js';
import { processPayload } from '../loader/intel.js';
import { selectAdapter } from './engines.js';
import { classifyOutcome, OUTCOMES as RESULT_LABELS } from '../validate/outcome.js';
import { parse } from '../core/parser.js';
import { walk } from '../core/walk.js';

export const STAGES = Object.freeze([
  ['recognize', 'Input recognition'],
  ['loader', 'Loader identification'],
  ['address', 'URL & source analysis'],
  ['retrieve', 'Authorised retrieval'],
  ['payload', 'Payload identification'],
  ['detect', 'Obfuscator & version detection'],
  ['transform', 'Transformation analysis'],
  ['strings', 'String & constant recovery'],
  ['vm', 'VM & bytecode reconstruction'],
  ['flow', 'Control & data-flow reconstruction'],
  ['functions', 'Function & expression reconstruction'],
  ['generate', 'Source generation'],
  ['validate', 'Syntax & semantic validation'],
  ['deliver', 'Delivery'],
]);

/** Where the program came from, and what became of the attempt to obtain it. */
export const SOURCE = Object.freeze({
  input: 'Supplied directly (no retrieval needed)',
  'public-source': 'Public source retrieved',
  'protected-payload': 'Public loader; its payload is protected',
  'auth-required': 'Authorisation required',
  'private-or-missing': 'Private or deleted (GitHub answers the same way for both)',
  missing: 'Missing or deleted',
  unavailable: 'Unavailable',
  'not-code': 'Retrieved, but the content is not Lua',
  'retrieved-unreconstructable': 'Retrieved, but not reconstructed',
  'needs-choice': 'A file has to be chosen',
  invalid: 'Not a valid address',
});

/** What a retrieved (or supplied) program is, once read. */
export const ROLES = Object.freeze({
  obfuscated: 'obfuscated program',
  'secondary-loader': 'secondary loader (followed)',
  dependency: 'dependency (a module other code loads)',
  config: 'configuration (data only)',
  plain: 'plain source (not obfuscated)',
  invalid: 'invalid (not a complete program)',
});

// what the reconstruction's own steps (src/recover/pipeline.js step ids) did, grouped into the stages the user sees
const STEP_GROUPS = [
  ['vm', /(?:^|\.)(?:vm\d*|bvm|vmify|self|program|engine)$|^ironbrew2$|^luaq\.layers$|^decompile\.bytecode$/],
  ['strings', /constants|strtable|charlist|^layers$|webs|^fold|mba|metaarith|unbox|cells|joiner|xfuscator|^moonveil\.join$/],
  ['flow', /cff|dataflow|evaluate|simplify|loops|whileonce|whiles|regions|unwrap|guard|antitamper|sanity|env|orphans|stable|adaptive|coinguard|proxify/],
  ['functions', /idioms|uninline|rename|tidy|varargs/],
];
const groupOf = (id) => (STEP_GROUPS.find(([, re]) => re.test(id)) || ['flow'])[0];

const GH_SOURCE = {
  'private-or-missing': 'private-or-missing', 'not-found-with-token': 'private-or-missing',
  'owner-not-found': 'missing', 'file-missing': 'missing', 'ref-missing': 'missing', 'repo-empty': 'missing',
  'token-rejected': 'auth-required', licence: 'auth-required',
  'rate-limited': 'unavailable', unavailable: 'unavailable', 'legal-block': 'unavailable', 'too-large': 'unavailable', 'is-directory': 'unavailable',
  'not-lua': 'not-code', 'invalid-url': 'invalid',
};
// the evidence classifyOutcome reads for each source class
const RETRIEVAL_STATUS = { 'auth-required': 'unauthorized', 'private-or-missing': 'not-found', missing: 'not-found', unavailable: 'failed', 'not-code': 'not-code', 'protected-payload': 'no-route', invalid: 'no-route' };

const hex12 = (s) => (s ? `${String(s).slice(0, 12)}…` : '');
const plural = (n, w, p = `${w}s`) => `${n} ${n === 1 ? w : p}`;
const lines = (t) => (t ? String(t).split('\n').length : 0);

/**
 * @param {{text: string, name?: string, bytes?: Uint8Array}} input text is a binary string (one char per byte); bytes, when given, are the
 *   file exactly as opened
 * @param {object} deps
 * @param {(src: string, opts?: object) => any} deps.analyze                    analyzeLoader
 * @param {(bytes: Uint8Array, meta?: object) => any} deps.decode              decodePayload
 * @param {(text: string) => any} deps.detect                                  detect() → { families, traits }
 * @param {(text: string) => any} deps.recover                                 recoverSource(text, {nexus: true})
 * @param {(url: string, o: {mode: string}) => Promise<object>} [deps.github]  /api/github (the server's JSON; file.bytes decoded)
 * @param {(url: string) => Promise<{ok: boolean, status?: number, bytes?: Uint8Array, contentType?: string, error?: string, name?: string}>} [deps.fetchLink]  /api/fetch
 * @param {(listing: object) => Promise<string|null>} [deps.choose]            pick a file (or a repository) from a listing; null = none
 * @param {(text: string, recovered: string, options?: object) => Promise<object>} [deps.verify] behaviour comparison (only when the user
 *   allowed the sandbox); options are what the format's adapter says about its runtime (src/pipeline/engines.js)
 * @param {(adapter: object, text: string) => Promise<{ok: boolean, bytecode?: string, licence?: string, isolation?: string, ms?: number,
 *   outcome?: string, message?: string}>} [deps.serverEngine]  /api/engine for a format whose adapter runs on the server (bytecode is a
 *   binary string); absent, or declined by the person, means QuickSilver's own passes
 * @param {(bytecode: string, options: object) => Promise<object>} [deps.fromBytecode]  recoverFromBytecode (src/api.js), in the worker
 * @param {(source: string, options: object) => Promise<object>} [deps.fromSource]  recoverFromSource (src/api.js), in the worker
 * @param {(snapshot: object) => void} [deps.onProgress]
 * @param {{maxDepth?: number, maxRetrievals?: number, maxDependencies?: number, routes?: string[]}} [opts]
 */
export async function deobfuscate(input, deps, opts = {}) {
  const t0 = Date.now();
  const maxDepth = opts.maxDepth ?? 4;
  const maxRetrievals = opts.maxRetrievals ?? 10;
  const maxDependencies = opts.maxDependencies ?? 4;
  const routes = new Set(opts.routes || ['link-fetcher']);
  const stages = STAGES.map(([id, label], i) => ({ n: i + 1, id, label, status: 'pending', detail: '', ms: 0 }));
  const byId = Object.fromEntries(stages.map((s) => [s.id, s]));
  const startedAt = {};
  const R = {
    stages, chain: [], requests: [], retrievals: 0,
    source: null,            // { class, label, message, address, retryAfter? }
    final: null,             // { name, output, outcome, isPayload, node }
    verdict: null,           // classifyOutcome() of what is delivered
    notes: [],
    ms: 0,
  };
  const emit = () => { if (deps.onProgress) try { deps.onProgress({ stages: stages.map((s) => ({ ...s })), chain: R.chain.length }); } catch { /* the view's problem */ } };
  const set = (id, status, detail) => {
    const s = byId[id];
    if (status === 'running') startedAt[id] = Date.now();
    else if (startedAt[id]) s.ms += Date.now() - startedAt[id], delete startedAt[id];
    s.status = status;
    if (detail != null) s.detail = detail;
    emit();
  };
  const note = (kind, text) => R.notes.push({ kind, text });
  // address and retrieval details accumulate over a chain (a repository listing, then a loader in it, then its payload)
  const acc = { address: [], retrieve: [] };
  const push = (id, status, text) => { if (text) acc[id].push(text); set(id, status, acc[id].join(' ')); };
  const seen = new Set();
  const verifyMemo = new Map();
  const loaderNotes = [];
  const finish = () => {
    R.ms = Date.now() - t0;
    for (const s of stages) if (s.status === 'pending' || s.status === 'running') { s.status = 'skipped'; if (!s.detail) s.detail = 'Not reached.'; }
    emit();
    return R;
  };
  const stop = (cls, message, extra = {}) => {
    R.source = { class: cls, label: SOURCE[cls], message, ...extra };
    R.verdict = classifyOutcome(cls === 'invalid' ? { input: { kind: 'text', error: message } } : { retrieval: { status: RETRIEVAL_STATUS[cls] || 'failed', reason: message } });
    set('deliver', 'failed', `Nothing was delivered: ${message}`);
    return finish();
  };

  // ---- 1 recognise ----------------------------------------------------------------------------------------------------------------------------
  set('recognize', 'running');
  const text = String(input.text ?? '');
  const rec = recognizeInput(text);
  const recLabel = {
    empty: 'Nothing was submitted.', bytecode: 'A compiled Lua chunk.', 'github-link': 'A GitHub link.', link: 'A link.',
    loader: 'A loader: a script that downloads its program and runs it (loadstring / HttpGet).', script: 'Lua or Luau source.',
  }[rec.kind];
  if (rec.kind === 'empty') {
    set('recognize', 'failed', recLabel);
    R.source = { class: 'input', label: SOURCE.input };
    R.verdict = classifyOutcome({ input: { kind: 'empty' } });
    set('deliver', 'failed', 'Nothing to deobfuscate: paste a script, a loadstring or a link, or open a file.');
    return finish();
  }
  set('recognize', 'done', `${recLabel}${rec.kind === 'script' || rec.kind === 'loader' ? ` ${plural(lines(text), 'line')}, ${text.length.toLocaleString('en')} bytes.` : ''}`);

  // ---- a link: the file it names is the program ------------------------------------------------------------------------------------------------
  if (rec.kind === 'github-link' || rec.kind === 'link') {
    const url = text.trim();
    set('loader', 'skipped', 'The input is a link: the file it points at is retrieved and examined.');
    set('address', 'running');
    let got;
    if (rec.kind === 'github-link') {
      if (rec.error || !rec.ref) { set('address', 'failed', rec.error || 'Not a GitHub address this tool reads.'); return stop('invalid', rec.error || 'Not a GitHub address this tool reads.', { address: url }); }
      push('address', 'done', describeRef(rec.ref));
      got = await retrieveGitHubTarget(url, rec.ref);
    } else {
      let host = '';
      try { host = new URL(/^https?:/i.test(url) ? url : `https://${url}`).hostname; } catch { /* reported below */ }
      if (!host) { set('address', 'failed', 'The link could not be read.'); return stop('invalid', 'The link could not be read.', { address: url }); }
      push('address', 'done', `A link to ${host}. It is fetched by this site’s server only if ${host} is one of the public hosts it reads from.`);
      got = await retrieveLink(url);
    }
    if (!got.ok) return stop(got.cls, got.message, { address: url, retryAfter: got.retryAfter });
    push('retrieve', 'done', got.detail);
    const node = await processBody(got.bytes, { name: got.repoPath || got.name, address: url, depth: 0, via: got.via, sha256: got.sha256, role: 'payload' });
    if (got.listing && node) { node.repoPath = got.repoPath; await followDependencies(node, got.listing, got.ref); }
    return deliver();
  }

  // ---- source (a script, a loader, or a compiled chunk) ------------------------------------------------------------------------------------
  set('address', rec.kind === 'loader' ? 'running' : 'skipped', rec.kind === 'loader' ? null : 'No address to resolve: the program is the input.');
  const bytes = input.bytes || binaryToBytes(text);
  await processBody(bytes, { name: input.name || 'input.lua', address: null, depth: 0, via: 'input', role: 'input' });
  return deliver();

  // ---- the pieces ----------------------------------------------------------------------------------------------------------------------------

  /**
   * Reconstruction of one program. Detection picks the engine (src/pipeline/engines.js): a format with a measured adapter goes to it, the
   * rest to QuickSilver's own passes. An adapter's engine that is not offered here, is declined, fails, or answers with something that
   * cannot be used hands the program to QuickSilver's own passes, and a note says why; nothing is reported as the engine's result unless
   * the engine produced it. An adapter marked `when: 'own-result-keeps-vm'` is asked only after QuickSilver's own result still holds the
   * VM, and one marked `verify.required` is used only when the behaviour comparison with the script itself agrees.
   */
  async function reconstruct(t, node) {
    const adapter = node.detection ? selectAdapter(node.detection) : null;
    const usable = adapter && adapter.where === 'server' && deps.serverEngine && (adapter.output === 'lua-source' ? deps.fromSource : deps.fromBytecode);
    if (!usable) return deps.recover(t);
    let own = null;
    if (adapter.when === 'own-result-keeps-vm') {
      own = await deps.recover(t);
      if (!(await stillHolds(own, adapter))) return own;
      if (adapter.verify && adapter.verify.required && !deps.verify) {
        note('engine', `${adapter.familyLabel}: QuickSilver's own passes left the virtual machine in place. A server engine can lift it, but its result is used only after a behaviour comparison, and the behaviour check is off for this run (tick Check behaviour to allow it).`);
        return own;
      }
    }
    const fallback = async (why) => { note('engine', `${adapter.familyLabel}: ${why}; QuickSilver's own passes were used instead.`); return own || deps.recover(t); };
    set('vm', 'running', `${adapter.familyLabel}: the server engine (${adapter.id}) is rebuilding the program…`);
    let eng;
    try { eng = await deps.serverEngine(adapter, t); } catch (e) { eng = { ok: false, outcome: 'engine-error', message: String((e && e.message) || e) }; }
    const payload = eng && eng.ok ? (adapter.output === 'lua-source' ? eng.source : eng.bytecode) : null;
    if (typeof payload !== 'string' || !payload.length) return fallback(`the server engine was not used (${String((eng && (eng.message || eng.outcome)) || 'no answer').slice(0, 200)})`);
    let r = null;
    const opts = { original: t, engine: adapter.id, label: adapter.label, family: adapter.family, familyLabel: adapter.familyLabel, licence: eng.licence || adapter.licence, dialect: adapter.dialect };
    try { r = await (adapter.output === 'lua-source' ? deps.fromSource(payload, opts) : deps.fromBytecode(payload, opts)); } catch (e) { r = { ok: false, error: { message: String((e && e.message) || e) } }; }
    if (!r || !r.ok || r.output == null) return fallback(`the server engine answered, but its ${adapter.output === 'lua-source' ? 'program' : 'bytecode'} could not be ${adapter.output === 'lua-source' ? 'read' : 'decompiled'} (${String((r && r.error && r.error.message) || 'no result').slice(0, 160)})`);
    r.engine = { id: adapter.id, isolation: eng.isolation || null, ms: eng.ms || null, licence: eng.licence || adapter.licence, verify: adapter.verify || null };
    const what = `${adapter.familyLabel}: the program was rebuilt by the server engine ${adapter.id} (${String(eng.licence || adapter.licence).split(':')[0]}${eng.isolation ? `, isolation: ${eng.isolation}` : ''})`;
    if (adapter.verify && adapter.verify.required) {
      // the gate: the engine's program is the result only if it behaves like the script, over enough of the program to mean something
      let v = null;
      try { v = await verifyOnce(t, r.output, adapter.verify); } catch (e) { v = { verdict: 'inconclusive', notes: [String((e && e.message) || e)] }; }
      const cov = v && v.coverage ? v.coverage.ratio : null;
      const min = adapter.verify.minCoverage ?? 0.5;
      if (!(v && v.verdict === 'identical' && cov != null && cov >= min)) {
        return fallback(`the server engine's program was not used, because the behaviour comparison with the script did not confirm it (${v ? v.verdict : 'no result'}${cov != null ? `, ${Math.round(cov * 100)}% of its lines reached` : ''}${v && v.difference ? `: ${String(v.difference.original).slice(0, 80)} / ${String(v.difference.recovered).slice(0, 80)}` : ''})`);
      }
      r.engine.gate = { verdict: v.verdict, coverage: cov };
      note('engine', `${what}, and used because it behaved like the script in the sandbox (${Math.round(cov * 100)}% of its lines reached).`);
      return r;
    }
    note('engine', `${what} and decompiled by QuickSilver.`);
    return r;
  }

  /** Does a recovery still carry the protection the adapter is for (QuickSilver's own detection, on the recovered text)? */
  async function stillHolds(r, adapter) {
    if (!r || r.output == null) return true;
    const text = String(r.output).includes('-- (end of report)\n') ? String(r.output).split('-- (end of report)\n')[1] : String(r.output);
    try { return ((await deps.detect(text)).families || []).some((f) => f.id === adapter.family && f.confidence >= adapter.minConfidence); } catch { return false; }
  }

  // one behaviour comparison per (script, program, options): the gate's run is the one the delivery step reports (verifyMemo is declared
  // with the other run state at the top: the pipeline runs before this part of the function is reached)
  function verifyOnce(t, recovered, o) {
    const key = `${t.length}:${recovered.length}:${JSON.stringify(o || null)}:${t}\u0000${recovered}`;
    if (!verifyMemo.has(key)) verifyMemo.set(key, Promise.resolve(deps.verify(t, recovered, o)));
    return verifyMemo.get(key);
  }

  /** One body (the input, or a retrieved file) through payload identification → detection → reconstruction; loaders are followed. */
  async function processBody(body, ctx) {
    set('payload', 'running');
    const st = { depth: ctx.depth, address: ctx.address, via: ctx.via };
    const node = { depth: ctx.depth, name: ctx.name, address: ctx.address, via: ctx.via, sha256: ctx.sha256 || null, bytes: body.length, role: null, st, children: [], parentRole: ctx.role, text: latin1(body, 2_000_000) };
    R.chain.push(node);
    let nested = null;
    await processPayload(st, body, {
      name: ctx.name, depth: ctx.depth, maxDepth, supplied: ctx.depth === 0 && ctx.via === 'input', opts: { keepText: true },
      deps: {
        decode: deps.decode,
        detect: async (t) => { set('detect', 'running'); const d = await deps.detect(t); node.detection = d; return d; },
        analyze: async (t, o) => { set('loader', 'running'); const a = await deps.analyze(t, o); node.analysis = a; return a; },
        recover: async (t) => { for (const id of ['transform', 'strings', 'vm', 'flow', 'functions', 'generate']) if (byId[id].status === 'pending') set(id, 'running'); const r = await reconstruct(t, node); node.recovery = r; return r; },
        verify: deps.verify ? (t, recovered) => verifyOnce(t, recovered, (node.recovery && node.recovery.engine && node.recovery.engine.verify) || undefined) : undefined,
      },
      onNested: async (analysis) => { nested = analysis; },
    });
    node.payloadKind = st.payload ? st.payload.kind : null;
    const prog = (st.programs || [])[0] || null;
    node.program = prog;
    node.role = roleOf(st, prog, node.analysis);
    set('payload', st.programs ? 'done' : 'failed', payloadDetail(node));
    if (node.detection) set('detect', 'done', detectDetail(node.detection));
    else if (!st.programs) set('detect', 'skipped', 'Nothing to examine.');
    if (nested) {
      describeLoader(node, nested);
      await followLoader(node, nested);
      return node;
    }
    // an obfuscated program can be a loader underneath: what its reconstruction requests is read the same way
    let a = node.analysis;
    if (prog && prog.output != null && prog.obfuscated) {
      try {
        const a2 = await deps.analyze(prog.output, { depth: ctx.depth, origin: `${ctx.name} (reconstructed)` });
        if (a2 && a2.isLoader) { a = a2; node.loaderAfterReconstruction = true; }
      } catch { /* the reconstruction is still delivered; only its requests are not read */ }
    }
    describeLoader(node, a);
    if (a && a.isLoader && !(a.payload && a.payload.ownProgram)) {
      node.role = 'secondary-loader';
      await followLoader(node, a);
    } else if (a && a.isLoader) {
      // the requests of a program that has its own body (libraries, further modules) are its dependencies
      await followLoader(node, a, { dependencies: true });
    }
    return node;
  }

  /** The addresses a loader names: route, retrieval, and the next body. */
  async function followLoader(node, analysis, { dependencies = false } = {}) {
    const reqs = analysis.requests || [];
    if (byId.address.status !== 'done') set('address', 'running');
    let tried = 0;
    let fetched = 0;
    for (const req of reqs) {
      const address = req.url || req.template;
      const entry = { depth: node.depth, from: node.name, api: req.api, line: req.line, address, route: req.retrieval, family: req.familyName || null, dependency: dependencies };
      R.requests.push(entry);
      if (seen.has(keyOf(address))) { entry.outcome = 'already-followed'; continue; }
      seen.add(keyOf(address));
      if (dependencies && fetched >= maxDependencies) { entry.outcome = 'not-followed'; entry.reason = `Only the first ${maxDependencies} dependencies are retrieved.`; continue; }
      if (node.depth + 1 > maxDepth) { entry.outcome = 'not-followed'; entry.reason = `Stages deeper than ${maxDepth} are not followed.`; continue; }
      if (!req.retrieval || !req.retrieval.possible || !routes.has(req.retrieval.route)) {
        entry.outcome = routeClass(req);
        entry.reason = req.retrieval ? req.retrieval.reason : 'No route.';
        continue;
      }
      if (R.retrievals >= maxRetrievals) { entry.outcome = 'not-followed'; entry.reason = `At most ${maxRetrievals} retrievals per run.`; continue; }
      tried++;
      set('retrieve', 'running');
      const got = isGitHubLink(req.url) ? await retrieveGitHubTarget(req.url, safeRef(req.url), { fileOnly: true }) : await retrieveLink(req.url);
      if (!got.ok) { entry.outcome = got.cls; entry.reason = got.message; entry.retryAfter = got.retryAfter; continue; }
      fetched++;
      entry.outcome = 'retrieved';
      entry.bytes = got.bytes.length;
      entry.sha256 = got.sha256;
      const child = await processBody(got.bytes, { name: got.name || baseOf(req.url), address: req.url, depth: node.depth + 1, via: got.via, sha256: got.sha256, role: dependencies ? 'dependency' : 'payload' });
      if (dependencies && child && child.role !== 'secondary-loader') child.role = child.role === 'invalid' ? 'invalid' : 'dependency';
      node.children.push(child);
    }
    const mine = R.requests.filter((r) => r.from === node.name && r.depth === node.depth);
    const who = node.depth === 0 && node.via === 'input' ? 'the input' : node.name;
    push('address', 'done', `${plural(mine.length, 'address', 'addresses')} named by ${who}${dependencies ? ' (its dependencies)' : ''}: ${summarizeRoutes(mine)}.`);
    const failedOnes = mine.filter((r) => r.outcome !== 'retrieved' && r.outcome !== 'already-followed');
    if (!tried && !dependencies) push('retrieve', 'failed', `Nothing retrievable from ${who}: ${failedOnes.map((r) => `${r.address} — ${r.reason}`).join(' ')}`);
    else if (tried) push('retrieve', fetched ? 'done' : 'failed', `${who === 'the input' ? 'From the input' : `From ${who}`}: ${fetched} of ${plural(tried, 'retrieval')} succeeded${mine.filter((r) => r.outcome === 'retrieved').length ? ` (${mine.filter((r) => r.outcome === 'retrieved').map((r) => `${r.address}, ${(r.bytes || 0).toLocaleString('en')} bytes, SHA-256 ${hex12(r.sha256)}`).join('; ')})` : ''}${failedOnes.length ? `; ${failedOnes.map((r) => `${r.address}: ${r.reason}`).join(' ')}` : ''}.`);
    else if (dependencies && byId.retrieve.status !== 'done') set('retrieve', byId.retrieve.status === 'running' ? 'done' : byId.retrieve.status);
  }

  /** A repository or folder: the referenced repository's own files that the retrieved entry point names (by path or module name). */
  async function followDependencies(entry, listing, ref) {
    if (!listing || !listing.files) return;
    const textOf = [entry.text || '', (entry.program && entry.program.output) || ''].join('\n');
    const strings = new Set([...textOf.matchAll(/(["'])((?:(?!\1)[^\\\n]|\\.){1,200})\1/g)].map((m) => m[2]));
    const picked = [];
    for (const f of listing.files) {
      if (f.path === entry.repoPath || picked.length >= maxDependencies || seen.has(keyOf(`https://github.com/${listing.owner}/${listing.repo}/blob/${ref || listing.ref || 'HEAD'}/${f.path}`))) continue;
      const base = f.path.split('/').pop();
      const stem = base.replace(/\.(?:lua|luau|txt)$/i, '');
      if (strings.has(f.path) || strings.has(base) || strings.has(stem) || [...strings].some((s) => s.endsWith(`/${f.path}`) || s.endsWith(`/${base}`))) picked.push(f);
    }
    if (!picked.length) { note('info', `No other file of ${listing.owner}/${listing.repo} is named by the entry point (beyond what it loads itself), so no further dependency was retrieved (${plural(listing.files.length, 'Lua file')} listed).`); return; }
    for (const f of picked) {
      if (R.retrievals >= maxRetrievals) break;
      const url = `https://github.com/${listing.owner}/${listing.repo}/blob/${ref || listing.ref || 'HEAD'}/${f.path.split('/').map(encodeURIComponent).join('/')}`;
      if (seen.has(keyOf(url))) continue;
      seen.add(keyOf(url));
      const req = { depth: 0, from: entry.name, api: 'repository file', address: url, route: { possible: true, route: 'github', reason: 'A file of the repository the link names, referenced by the entry point.' }, dependency: true };
      R.requests.push(req);
      set('retrieve', 'running');
      const got = await retrieveGitHubTarget(url, safeRef(url), { fileOnly: true });
      if (!got.ok) { req.outcome = got.cls; req.reason = got.message; continue; }
      req.outcome = 'retrieved'; req.bytes = got.bytes.length; req.sha256 = got.sha256;
      const child = await processBody(got.bytes, { name: f.path, address: url, depth: 1, via: 'github', sha256: got.sha256, role: 'dependency' });
      if (child && child.role !== 'secondary-loader' && child.role !== 'invalid') child.role = 'dependency';
      entry.children.push(child);
    }
    push('retrieve', 'done', `Dependencies of ${entry.name} in ${listing.owner}/${listing.repo}: ${picked.map((f) => f.path).join(', ')}.`);
  }

  /** GitHub: a file is read; a repository, folder or profile is listed and the entry point chosen (automatically when it is clear). */
  async function retrieveGitHubTarget(url, ref, { fileOnly = false } = {}) {
    if (!deps.github) return { ok: false, cls: 'unavailable', message: 'GitHub retrieval is not available here (it needs the site’s /api/github function).' };
    if (!ref) return { ok: false, cls: 'invalid', message: 'Not a GitHub address this tool reads.' };
    set('retrieve', 'running');
    R.retrievals++;
    let listing = null;
    let entryPath = null;
    let r;
    if (!fileOnly && (ref.kind === 'repo' || ref.kind === 'tree' || ref.kind === 'profile')) {
      r = await deps.github(url, { mode: 'listing' });
      if (!r || !r.ok) return ghFailure(r);
      listing = r.listing;
      if (listing && listing.kind === 'profile') {
        const repos = listing.repositories || [];
        const chosen = repos.length === 1 ? `https://github.com/${listing.owner}/${repos[0].name}` : deps.choose ? await deps.choose(listing) : null;
        if (!chosen) { push('retrieve', 'failed', `${plural(repos.length, 'public repository', 'public repositories')} of ${listing.owner}: one has to be chosen.`); return { ok: false, cls: 'needs-choice', message: `The profile ${listing.owner} has ${plural(repos.length, 'public repository', 'public repositories')}; choose one (or paste a link to the file).` }; }
        R.retrievals++;
        r = await deps.github(chosen, { mode: 'listing' });
        if (!r || !r.ok) return ghFailure(r);
        listing = r.listing;
      }
      const files = (listing && listing.files) || [];
      if (!files.length) return { ok: false, cls: 'missing', message: `No .lua, .luau or .txt file was found in ${listing ? `${listing.owner}/${listing.repo}` : 'the repository'}.` };
      entryPath = pickEntry(files);
      if (!entryPath && deps.choose) entryPath = await deps.choose(listing);
      if (!entryPath) return { ok: false, cls: 'needs-choice', message: `${listing.owner}/${listing.repo} has ${plural(files.length, 'Lua file')} and no single entry point; choose the file to deobfuscate.` };
      const fileUrl = `https://github.com/${listing.owner}/${listing.repo}/blob/${listing.ref || 'HEAD'}/${entryPath.split('/').map(encodeURIComponent).join('/')}`;
      R.retrievals++;
      r = await deps.github(fileUrl, { mode: 'file' });
    } else {
      r = await deps.github(url, { mode: 'file' });
    }
    if (!r || !r.ok || !r.file) return ghFailure(r);
    const f = r.file;
    const where = r.target ? `${r.target.owner}/${r.target.repo || r.target.gist || ''}${r.target.path ? `/${r.target.path}` : entryPath ? `/${entryPath}` : ''}` : f.name;
    const detail = `Retrieved ${where} from GitHub: ${f.bytes.length.toLocaleString('en')} bytes, SHA-256 ${hex12(f.sha256)}${f.contentReason ? `. ${f.contentReason}` : ''}${listing ? ` (entry point chosen from ${plural((listing.files || []).length, 'Lua file')} of ${listing.owner}/${listing.repo})` : ''}`;
    return { ok: true, bytes: f.bytes, name: f.name || entryPath || baseOf(url), sha256: f.sha256 || null, via: 'github', detail, listing, ref: listing && listing.ref, repoPath: entryPath };
  }
  function ghFailure(r) {
    if (!r) return { ok: false, cls: 'unavailable', message: 'GitHub did not answer.' };
    const cls = GH_SOURCE[r.outcome] || 'unavailable';
    const label = r.label || (GH_OUTCOMES[r.outcome] ? GH_OUTCOMES[r.outcome].label : r.outcome);
    push('retrieve', 'failed', `${label}. ${r.message || ''}`.trim());
    return { ok: false, cls, message: `${label}. ${r.message || ''}`.trim(), retryAfter: r.retryAfter };
  }

  async function retrieveLink(url) {
    if (!deps.fetchLink) return { ok: false, cls: 'unavailable', message: 'Fetching links is not available here (it needs the site’s /api/fetch function).' };
    R.retrievals++;
    set('retrieve', 'running');
    let res;
    try { res = await deps.fetchLink(url); } catch (e) { res = { ok: false, error: String(e.message || e) }; }
    if (!res || !res.ok || !res.bytes) {
      const s = res && res.status;
      const cls = s === 401 || s === 403 ? 'auth-required' : s === 404 || s === 410 ? 'missing' : 'unavailable';
      const message = `${res && res.error ? res.error : `HTTP ${s || '—'}`}`;
      push('retrieve', 'failed', message);
      return { ok: false, cls, message };
    }
    return { ok: true, bytes: res.bytes, name: res.name || baseOf(url), sha256: res.sha256 || null, via: 'link', detail: `Fetched ${url}: ${res.bytes.length.toLocaleString('en')} bytes${res.contentType ? ` (${res.contentType})` : ''}.` };
  }

  function describeLoader(node, a) {
    const who = node.depth === 0 && node.via === 'input' ? 'The input' : node.name;
    if (!a || !a.isLoader) {
      if (node.depth === 0) loaderNotes.push(`${who} is not a loader: the program is in ${node.via === 'input' ? 'the input' : 'the file'} itself.`);
      set('loader', 'done', loaderNotes.join(' → ') || 'Not a loader.');
      return;
    }
    const svc = (a.families || []).map((f) => f.name).filter(Boolean);
    const own = a.payload && a.payload.ownProgram;
    loaderNotes.push(`${who} is ${own ? 'a program that also loads code' : node.loaderAfterReconstruction ? 'an obfuscated loader (read from its reconstruction)' : 'a loader'}: ${plural((a.requests || []).length, 'request')} (${[...new Set((a.requests || []).map((r) => r.api))].slice(0, 3).join(', ')})${svc.length ? `; service: ${svc.join(', ')}` : ''}.${own ? ' Its own program is reconstructed; what it loads is retrieved as dependencies where a route allows.' : ''}`);
    set('loader', 'done', loaderNotes.join(' → '));
  }

  // ---- delivery --------------------------------------------------------------------------------------------------------------------------------
  function deliver() {
    const root = R.chain[0];
    if (byId.address.status === 'pending' || byId.address.status === 'running') set('address', 'skipped', 'No address to resolve: the program is in the input.');
    if (byId.retrieve.status === 'pending' || byId.retrieve.status === 'running') set('retrieve', 'skipped', R.requests.length ? 'Nothing was retrieved.' : 'Nothing to retrieve: the program is in the input.');
    // the payload: follow the loader chain from the input to the first program that is not itself a loader (dependencies are delivered as extras)
    let node = root;
    while (node && node.role === 'secondary-loader') node = node.children.find((c) => c && c.parentRole !== 'dependency') || null;
    const payloadReached = node && node !== root ? true : root && root.role !== 'secondary-loader';
    const viaRetrieval = root && root.via !== 'input';
    // where the program came from
    if (!viaRetrieval && root && root.role !== 'secondary-loader') R.source = R.source || { class: 'input', label: SOURCE.input };
    if (!payloadReached) {
      // a loader whose payload could not be obtained: the reason is the best one its requests give
      const reqs = R.requests.filter((r) => !r.dependency);
      const order = ['auth-required', 'private-or-missing', 'protected-payload', 'missing', 'not-code', 'unavailable', 'not-followed'];
      const cls = order.find((c) => reqs.some((r) => r.outcome === c)) || 'unavailable';
      const why = reqs.filter((r) => r.outcome === cls).map((r) => `${r.address}: ${r.reason}`)[0] || 'The loader names no address this tool can follow.';
      R.source = { class: cls === 'not-followed' ? 'unavailable' : cls, label: SOURCE[cls === 'not-followed' ? 'unavailable' : cls], message: why, address: (reqs[0] || {}).address, retryAfter: (reqs.find((r) => r.retryAfter) || {}).retryAfter };
      R.verdict = classifyOutcome({ retrieval: { status: RETRIEVAL_STATUS[R.source.class] || 'failed', reason: why } });
      for (const id of ['transform', 'strings', 'vm', 'flow', 'functions', 'generate', 'validate']) if (byId[id].status === 'pending' || byId[id].status === 'running') set(id, 'skipped', 'No payload reached this stage.');
      // the loader's own code is offered only as what it is (obfuscated loaders are reconstructed so their requests can be read)
      const loaderOut = root && root.program && root.program.output;
      R.final = loaderOut ? { name: outName(root.name, 'loader'), output: loaderOut, outcome: root.program.result || null, isPayload: false, node: root } : null;
      set('deliver', 'failed', `The payload was not obtained (${R.source.label.toLowerCase()}). ${loaderOut ? 'Only the loader’s own code is shown, labelled as the loader — it is not the payload.' : 'Nothing is delivered in its place.'}`);
      return finish();
    }
    const prog = node.program;
    if (viaRetrieval || node !== root) {
      const ok = prog && prog.result && ['validated', 'syntax-valid-unverified'].includes(prog.result.outcome);
      // Lua that does not parse (cut off, damaged) was retrieved but cannot be reconstructed; only content that is not Lua at all is "not code"
      const luaLike = node.st && (node.st.outcome === 'invalid-payload' || (node.st.payload && ['lua', 'luac', 'luajit', 'corrupt'].includes(node.st.payload.kind)));
      R.source = { class: !prog ? (luaLike ? 'retrieved-unreconstructable' : 'not-code') : ok || node.role === 'plain' || node.role === 'config' || node.role === 'dependency' ? 'public-source' : 'retrieved-unreconstructable', address: node.address, message: '' };
      R.source.label = SOURCE[R.source.class];
      if (R.source.class === 'retrieved-unreconstructable') R.source.message = prog ? 'The payload was retrieved, but the reconstruction did not reach a usable result (see validation).' : 'The payload was retrieved and is Lua, but it is incomplete or damaged: it does not parse, so there is nothing sound to reconstruct.';
    }
    if (!prog) {
      R.verdict = node.st.result || classifyOutcome({ input: { kind: 'text', error: 'The content is not Lua.' } });
      for (const id of ['detect', 'transform', 'strings', 'vm', 'flow', 'functions', 'generate', 'validate']) if (byId[id].status === 'pending' || byId[id].status === 'running') set(id, 'skipped', 'The content is not a program.');
      set('deliver', 'failed', `Nothing was delivered: ${R.verdict.reasons.join(' ') || R.verdict.label}`);
      return finish();
    }
    reconstructionStages(prog, node);
    R.verdict = prog.result;
    validateStage(prog, node);
    // everything else the chain reconstructed (dependencies, further payloads of the same loader) is delivered with it, each labelled
    const dependencies = R.chain.filter((n) => n !== node && n.role !== 'secondary-loader' && n.program && n.program.output != null).map((n) => ({ name: outName(n.name), output: n.program.output, outcome: n.program.result, address: n.address, role: n.role }));
    // the loaders on the way (except the one the user pasted) are kept as what they are, so the whole chain can be read
    for (const n of R.chain) if (n.role === 'secondary-loader' && !(n.depth === 0 && n.via === 'input')) dependencies.push({ name: outName(n.name, 'loader'), output: (n.program && n.program.output) || n.text, outcome: null, address: n.address, role: 'secondary-loader' });
    if (prog.output != null) {
      R.final = { name: outName(node.name), output: prog.output, outcome: prog.result, isPayload: true, node, dependencies };
      const what = node === root ? (node.role === 'plain' ? 'The input, cleaned up' : 'The reconstructed program') : `The reconstructed payload of ${node.address}`;
      set('deliver', R.verdict.outcome === 'validated' || R.verdict.outcome === 'syntax-valid-unverified' ? 'done' : 'warn', `${what}: ${R.final.name}, ${plural(lines(prog.output), 'line')} — ${R.verdict.label.toLowerCase()}.${dependencies.length ? ` Also delivered: ${dependencies.map((d) => `${d.name} (${ROLES[d.role] || d.role})`).join(', ')}.` : ''}`);
    } else {
      R.final = null;
      set('deliver', 'failed', `No reconstruction was produced: ${R.verdict.reasons.join(' ') || R.verdict.label}`);
    }
    return finish();
  }

  function reconstructionStages(prog, node) {
    const r = node.recovery || {};
    const steps = r.steps || [];
    const det = node.detection || {};
    const traits = (det.traits || []).map((t) => t.label || t.id).filter(Boolean);
    const applied = steps.filter((s) => s.status === 'applied');
    set('transform', 'done', `${applied.length ? `${plural(applied.length, 'transformation')} undone` : 'No transformation had to be undone'}${traits.length ? `; protections seen: ${traits.slice(0, 6).join(', ')}` : ''}.`);
    for (const g of ['strings', 'vm', 'flow', 'functions']) {
      const mine = steps.filter((s) => groupOf(s.id) === g);
      const did = mine.filter((s) => s.status === 'applied');
      const changed = did.reduce((a, s) => a + (s.changed || 0), 0);
      let detail = did.length ? `${did.map((s) => s.label || s.id).slice(0, 4).join('; ')}${did.length > 4 ? ` (+${did.length - 4} more)` : ''} — ${plural(changed, 'change')}.` : mine.length ? 'Checked; nothing of this kind to undo.' : 'Not needed for this input.';
      let status = did.length ? 'done' : mine.length ? 'done' : 'skipped';
      const ev = (r.outcome && r.outcome.evidence) || {};
      const rv = ev.recovery || {};
      if (g === 'vm') {
        const vm = r.vm;
        if (vm && vm.kind) detail = `${vm.lifted ? `${vm.kind} VM lifted` : `${vm.kind} VM recognised, not lifted`}${vm.stats && vm.stats.functions ? `: ${plural(vm.stats.functions, 'function')}, ${plural(vm.stats.instructions || 0, 'instruction')}` : ''}. ${detail}`;
        if (vm && vm.kind && !vm.lifted) status = 'failed';
        if (rv.unresolved) { status = 'warn'; detail += ` ${plural(rv.unresolved, 'place')} left unresolved.`; }
      }
      if (g === 'strings' && rv.bodies && rv.bodies.missingConstants) { status = 'warn'; detail += ` ${plural(rv.bodies.missingConstants, 'constant')} missing.`; }
      if (g === 'functions' && rv.bodies && rv.bodies.empty) { status = 'warn'; detail += ` ${plural(rv.bodies.empty, 'function body', 'function bodies')} empty in the output.`; }
      if (g === 'functions' && rv.naming && rv.naming.placeholderParams) { status = status === 'done' ? 'warn' : status; detail += ` ${plural(rv.naming.placeholderParams, 'parameter')} still ha${rv.naming.placeholderParams === 1 ? 's' : 've'} a placeholder name (no evidence for a better one).`; }
      set(g, status, detail);
    }
    set('generate', prog.output != null ? 'done' : 'failed', prog.output != null ? `${plural(lines(prog.output), 'line')} of Lua written${r.validation && r.validation.syntax ? '; it parses and prints back identically' : ''}.` : 'No source was produced.');
  }

  function validateStage(prog, node) {
    const v = prog.result;
    const ev = (node.recovery && node.recovery.outcome && node.recovery.outcome.evidence) || {};
    const rv = ev.recovery || {};
    const parts = [];
    if (rv.parses === true || (node.recovery && node.recovery.validation && node.recovery.validation.syntax)) parts.push('the output parses');
    if (rv.residual && rv.residual.length) parts.push(`protection left in it: ${rv.residual.slice(0, 3).join(', ')}`);
    if (rv.naming && rv.naming.locals) parts.push(`${rv.naming.placeholders} of ${plural(rv.naming.locals, 'local name')} are placeholders`);
    parts.push(prog.behaviour ? `behaviour vs the input: ${prog.behaviour.verdict}` : 'behaviour not compared (that needs the sandbox, which is off unless you allow it)');
    set('validate', v.outcome === 'validated' || v.outcome === 'syntax-valid-unverified' ? 'done' : v.outcome === 'partial' ? 'warn' : 'failed', `${v.label}: ${parts.join('; ')}.`);
  }
}

// ---- helpers ----------------------------------------------------------------------------------------------------------------------------------

/** The program's role, from the payload, the detection and the loader analysis. */
function roleOf(st, prog, analysis) {
  if (!prog) return st.programs ? 'secondary-loader' : 'invalid';
  if (prog.nestedLoader) return 'secondary-loader';
  if (prog.obfuscated) return 'obfuscated';
  return programRole(prog.source || '');
}

/** A plain program's role: configuration (a returned table of data), a module (returns a table of functions), or plain source. */
export function programRole(text) {
  let ast;
  try { ast = parse(text); } catch { return 'invalid'; }
  const body = ast.body || [];
  const last = body[body.length - 1];
  const dataOnly = (n) => { let ok = true; walk(n, (x) => { if (x.type === 'Func' || x.type === 'Call' || x.type === 'MethodCall' || x.type === 'Vararg') ok = false; return ok; }); return ok; };
  if (last && last.type === 'Return' && last.values.length === 1 && last.values[0].type === 'Table' && dataOnly(body)) return 'config';
  if (last && last.type === 'Return' && last.values.length === 1 && last.values[0].type === 'Name') {
    const name = last.values[0].name;
    let fns = 0;
    walk(body, (x) => {
      if (x.type === 'Function' && x.target && x.target.type === 'Index' && x.target.obj && x.target.obj.name === name) fns++;
      if (x.type === 'Assign') x.targets.forEach((t, i) => { if (t.type === 'Index' && t.obj && t.obj.name === name && x.values[i] && x.values[i].type === 'Func') fns++; });
    });
    if (fns) return 'dependency';
  }
  if (last && last.type === 'Return' && last.values.length === 1 && last.values[0].type === 'Table') {
    let fns = 0;
    walk(last.values[0], (x) => { if (x.type === 'Func') fns++; });
    if (fns) return 'dependency';
  }
  return 'plain';
}

/** The file to deobfuscate in a listing, when it is unambiguous: the only file, or the only one named like an entry point. */
export function pickEntry(files) {
  const lua = files.filter((f) => /\.(?:lua|luau)$/i.test(f.path));
  const pool = lua.length ? lua : files;
  if (pool.length === 1) return pool[0].path;
  const top = pool.filter((f) => !f.path.includes('/'));
  for (const re of [/^(?:main|init|loader|source|script)\.(?:lua|luau)$/i, /^(?:main|init|loader)/i]) {
    const m = (top.length ? top : pool).filter((f) => re.test(f.path.split('/').pop()));
    if (m.length === 1) return m[0].path;
  }
  return null;
}

function describeRef(ref) {
  const repo = `${ref.owner}/${ref.repo || ''}`;
  switch (ref.kind) {
    case 'file': return `A file in the GitHub repository ${repo}${ref.ref ? ` (branch or tag ${ref.ref})` : ''}: ${ref.path}.`;
    case 'tree': return `A folder of ${repo}${ref.ref ? ` at ${ref.ref}` : ''}${ref.path ? `: ${ref.path}` : ''}. Its Lua files are listed and the entry point is retrieved.`;
    case 'repo': return `The repository ${repo}. Its Lua files are listed and the entry point is retrieved.`;
    case 'profile': return `The GitHub account ${ref.owner}. Its public repositories are listed; only the one you choose is read.`;
    case 'gist': return `A gist of ${ref.owner}.`;
    default: return `${ref.kind} ${repo}`;
  }
}

function routeClass(req) {
  const rt = req.retrieval || {};
  if (rt.route === 'owner' || (rt.possible && /^provider:/.test(rt.route))) return 'auth-required';
  if (req.familyName || (rt.reason && /protect|key holder|whitelist/i.test(rt.reason))) return 'protected-payload';
  return 'unavailable';
}

function summarizeRoutes(reqs) {
  const c = {};
  for (const r of reqs) { const k = r.outcome === 'retrieved' ? 'retrieved' : r.outcome || 'pending'; c[k] = (c[k] || 0) + 1; }
  const word = { retrieved: 'retrieved', 'auth-required': 'need the owner’s authorisation', 'protected-payload': 'protected by a service', 'private-or-missing': 'private or deleted', missing: 'missing', unavailable: 'not reachable through an authorised route', 'not-code': 'not code', 'not-followed': 'not followed', 'already-followed': 'already followed', invalid: 'invalid', 'needs-choice': 'need a choice' };
  return Object.entries(c).map(([k, n]) => `${n} ${word[k] || k}`).join(', ') || 'none';
}

function payloadDetail(node) {
  const st = node.st;
  const p = st.payload || {};
  const prog = node.program;
  const fams = prog && prog.families && prog.families.length ? ` (${prog.families.join(', ')})` : '';
  const role = node.role ? `${ROLES[node.role]}${node.role === 'obfuscated' ? fams : ''}` : '';
  if (!st.programs) return `${node.depth === 0 && node.via === 'input' ? 'The input' : node.name} is ${p.label || 'not code'}: ${(st.result && st.result.reasons.join(' ')) || 'it is not passed to the reconstruction.'}`;
  return `${node.depth === 0 && node.via === 'input' ? 'The input' : node.name} is ${p.label || 'Lua source'}${p.layers && p.layers.length ? ` (layers: ${p.layers.map((l) => l.kind).join(' → ')})` : ''} — ${role}.`;
}

function detectDetail(d) {
  const fams = (d.families || []).filter((f) => f.confidence >= 0.5);
  const dialect = d.dialect && d.dialect.label ? ` Dialect: ${d.dialect.label}.` : '';
  if (!fams.length) return `No known obfuscator recognised${(d.traits || []).length ? `; generic protections: ${(d.traits || []).map((t) => t.label || t.id).slice(0, 4).join(', ')}` : ''}.${dialect}`;
  return `${fams.map((f) => `${f.name}${f.version ? ` ${f.version}` : ''} (${Math.round(f.confidence * 100)}%)`).join(', ')}.${dialect}`;
}

/** One key per file, however it is spelled (github.com/…/blob/…, raw.githubusercontent.com/…, the API). */
function keyOf(url) {
  try { const r = parseGitHubRef(url); if (r.kind === 'file') return `gh:${r.owner}/${r.repo}@${r.ref || 'HEAD'}:${r.path}`.toLowerCase(); } catch { /* not GitHub */ }
  return String(url);
}
function latin1(bytes, max) { let s = ''; const n = Math.min(bytes.length, max); for (let i = 0; i < n; i += 8192) s += String.fromCharCode.apply(null, bytes.subarray(i, Math.min(n, i + 8192))); return s; }
const baseOf = (url) => { try { return decodeURIComponent(new URL(url).pathname.split('/').filter(Boolean).pop() || 'download.lua'); } catch { return 'download.lua'; } };
const safeRef = (url) => { try { return parseGitHubRef(url); } catch { return null; } };
function outName(name, suffix = 'deobf') {
  const b = String(name || 'script.lua').split('/').pop().replace(/\.(?:lua|luau|txt)$/i, '') || 'script';
  return `${b}.${suffix}.lua`;
}
function binaryToBytes(s) { const u = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) u[i] = s.charCodeAt(i) & 255; return u; }

/** A Markdown report of one run (exported with the result). */
export function unifiedMarkdown(R, { name = 'input' } = {}) {
  const L = [`# QuickSilver v1.8 — deobfuscation report: ${name}`, ''];
  L.push(`**Result:** ${R.verdict ? R.verdict.label : '—'}`, '');
  if (R.source) L.push(`**Source:** ${R.source.label}${R.source.address ? ` — \`${R.source.address}\`` : ''}${R.source.message ? `. ${R.source.message}` : ''}`, '');
  if (R.final) L.push(`**Delivered:** \`${R.final.name}\`${R.final.isPayload ? '' : ' — the loader’s own code, not the payload'}`, '');
  if (R.verdict && R.verdict.reasons && R.verdict.reasons.length) L.push(`**Why not higher:** ${R.verdict.reasons.join(' ')}`, '');
  L.push('| # | Stage | Status | Detail |', '|---|---|---|---|');
  for (const s of R.stages) L.push(`| ${s.n} | ${s.label} | ${s.status} | ${String(s.detail || '').replace(/\|/g, '\\|').replace(/\n/g, ' ')} |`);
  L.push('');
  if (R.chain.length > 1 || R.requests.length) {
    L.push('## Chain', '');
    for (const n of R.chain) L.push(`- depth ${n.depth}: \`${n.name}\`${n.address ? ` from ${n.address}` : ''} — ${ROLES[n.role] || n.role}${n.program && n.program.result ? `; ${n.program.result.label}` : ''}${n.sha256 ? `; SHA-256 ${n.sha256}` : ''}`);
    for (const r of R.requests) L.push(`- request \`${r.api}\` → \`${r.address}\`: ${r.outcome || '—'}${r.reason ? ` (${r.reason})` : ''}`);
    L.push('');
  }
  for (const n of R.notes) L.push(`> ${n.text}`);
  return L.join('\n');
}

export { RESULT_LABELS };
