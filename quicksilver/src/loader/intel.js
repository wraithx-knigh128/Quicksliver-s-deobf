// Loader Intelligence: from a loader to reconstructed payloads, with every stage measured on its own.
//
//   identify     what the loader is, which requests it makes, which access case applies       (src/loader/analyze.js)
//   route        for each request: retrievable through an authorised route, or why not
//   transport    the request itself: HTTP status, bytes, time — a 200 is only a transport success
//   payload      what the body is, layer by layer (src/loader/payload.js) — an HTML page or a JSON error is not a payload
//   classify     which obfuscator (if any) the payload carries                                 (src/detect)
//   reconstruct  the recovery pipeline's result and its own confidence — a retrieved obfuscated payload is not a deobfuscated one
//   recurse      a payload that is itself a loader is analysed the same way (multi-stage), up to a depth limit
//
// The module is independent of where it runs: the page passes functions that call the engine worker and /api/fetch, the tests and the
// harness pass direct ones and a mock service. Nothing here fetches on its own or decides to fetch: `fetchStage` is only called for requests
// whose route is authorised, and the page only calls this after the user confirms.

import { binaryToText } from '../core/bytes.js';
import { parse } from '../core/parser.js';
import { classifyOutcome, inputEvidence, OUTCOMES as RESULT_LABELS } from '../validate/outcome.js';

export { RESULT_LABELS };

export const OUTCOMES = {
  'not-retrievable': 'not retrievable through an authorised route',
  'transport-failed': 'the request failed',
  'not-code': 'retrieved, but the response is not code',
  'invalid-payload': 'retrieved code that is incomplete or does not parse (not passed to the pipeline)',
  'unsupported-payload': 'retrieved content in a form the pipeline does not read',
  'retrieved-unrecoverable': 'retrieved code that the pipeline could not reconstruct (low confidence)',
  'retrieved-reconstructed': 'retrieved and reconstructed',
  'retrieved-plain': 'retrieved code that was not obfuscated',
  'nested-loader': 'retrieved another loader (analysed as the next stage)',
};

const sha256 = async (bytes) => {
  try { const d = await crypto.subtle.digest('SHA-256', bytes); return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join(''); } catch { return null; }
};

/**
 * @param {string} source binary string of the loader
 * @param {object} deps
 * @param {(src:string, opts?:object)=>any} deps.analyze           analyzeLoader
 * @param {(req:object)=>Promise<{ok:boolean,status?:number,bytes?:Uint8Array,contentType?:string,error?:string,ms?:number}>} deps.fetchStage
 * @param {(bytes:Uint8Array, meta:object)=>any} deps.decode       decodePayload
 * @param {(text:string)=>any} deps.detect                        detect() → { families }
 * @param {(text:string)=>any} deps.recover                       recover() → { output, confidence, level }
 * @param {{maxDepth?: number, maxStages?: number, routes?: string[]}} [opts]
 */
export async function loaderIntel(source, deps, opts = {}) {
  const maxDepth = opts.maxDepth ?? 3;
  const maxStages = opts.maxStages ?? 8;
  const routes = new Set(opts.routes || ['link-fetcher']);
  const t0 = Date.now();
  const stages = [];
  const seen = new Set();
  const loader = await deps.analyze(source, { depth: 0, origin: 'input' });

  async function visit(analysis, depth, via) {
    for (const req of analysis.requests) {
      if (stages.length >= maxStages) return;
      const key = req.url || req.template;
      if (seen.has(key)) continue;
      seen.add(key);
      const st = { depth, via, request: { api: req.api, line: req.line, address: req.url || req.template, urlKind: req.urlKind, host: req.host, family: req.familyName, executes: req.executes }, route: req.retrieval };
      stages.push(st);
      if (!req.retrieval.possible || !routes.has(req.retrieval.route)) {
        st.outcome = 'not-retrievable';
        // a route that needs a credential (the owner's key, or a provider this deployment has no key for) is an authorisation question;
        // a protected service, a run-time address or an unlisted host is a payload that is not available here
        const needsCredential = req.retrieval.route === 'owner' || (req.retrieval.possible && /^provider:/.test(req.retrieval.route));
        st.result = classifyOutcome({ retrieval: { status: needsCredential ? 'not-configured' : 'no-route', reason: req.retrieval.reason } });
        continue;
      }
      // transport
      const t = Date.now();
      let res;
      try { res = await deps.fetchStage(req); } catch (e) { res = { ok: false, error: String(e.message || e) }; }
      st.transport = { ok: !!res.ok, status: res.status ?? null, error: res.ok ? null : res.error || `HTTP ${res.status}`, bytes: res.bytes ? res.bytes.length : 0, ms: res.ms ?? Date.now() - t };
      if (!res.ok || !res.bytes) {
        st.outcome = 'transport-failed';
        const status = res.status === 401 || res.status === 403 ? 'unauthorized' : res.status === 501 ? 'not-configured' : res.status === 404 ? 'not-found' : res.status === 422 ? 'empty' : 'failed';
        st.result = classifyOutcome({ retrieval: { status, reason: `The request failed: ${st.transport.error}.` } });
        continue;
      }
      st.transport.sha256 = await sha256(res.bytes);
      await processPayload(st, res.bytes, { contentType: res.contentType, name: req.url, depth, deps, opts, maxDepth, onNested: (next, name) => visit(next, depth + 1, name) });
    }
  }
  await visit(loader, 0, 'input');

  const count = (o) => stages.filter((s) => s.outcome === o).length;
  const classes = {};
  for (const st of stages) if (st.result) classes[st.result.outcome] = (classes[st.result.outcome] || 0) + 1;
  const summary = {
    classes,
    validated: classes.validated || 0,
    requests: stages.length,
    retrievable: stages.filter((s) => s.route && s.route.possible).length,
    transportOk: stages.filter((s) => s.transport && s.transport.ok).length,
    payloadCode: stages.filter((s) => s.programs && s.programs.length).length,
    reconstructed: count('retrieved-reconstructed'),
    plain: count('retrieved-plain'),
    unrecoverable: count('retrieved-unrecoverable'),
    notCode: count('not-code'),
    transportFailed: count('transport-failed'),
    notRetrievable: count('not-retrievable'),
    nested: count('nested-loader'),
    ms: Date.now() - t0,
  };
  return { loader: { case: loader.case, alsoApplies: loader.alsoApplies, families: loader.families, architectures: loader.architectures.map((a) => a.id), isLoader: loader.isLoader }, stages, summary };
}

/**
 * Payload validation → obfuscator detection → deobfuscation → syntax validation → behavioural validation → class, for one body: a retrieved
 * response, or a payload its owner supplied (`supplied`). Fills in `st` (payload, programs, outcome, result) and returns it. A program that is
 * itself a loader is handed to `onNested` instead of being reconstructed.
 */
export async function processPayload(st, bytes, { contentType = '', name = 'payload', depth = 0, deps, opts = {}, maxDepth = 3, onNested = async () => {}, supplied = false }) {
  const got = supplied ? {} : { retrieval: { status: 'ok' } };
  // payload
  const p = await deps.decode(bytes, { contentType });
  st.payload = { kind: p.kind, label: p.label, layers: p.layers, parses: p.parses ?? null, notes: p.notes, scripts: p.scripts ? p.scripts.map((s) => ({ path: s.path, className: s.className, bytes: s.source.length })) : undefined };
  // payload validation: only intact code goes on to the pipeline. A response that is not code (an error page, a JSON message, an empty body,
  // a "key required" text) is not a payload; code that is cut off or does not parse is reported as such and is not "reconstructed".
  if (p.kind === 'lua' && p.parses === false) {
    const ie = inputEvidence(p.text, parse);
    if (!looksLikeLua(p.text)) {
      st.outcome = 'not-code';
      st.result = classifyOutcome(supplied ? { input: { kind: 'text', error: `The content is text, not Lua: “${preview(p.text)}”` } } : { retrieval: { status: 'not-code', reason: `The response is text, not Lua: “${preview(p.text)}”.` } });
    } else {
      st.outcome = 'invalid-payload';
      st.payload.truncated = !!ie.truncated;
      st.result = classifyOutcome({ ...got, input: ie });
    }
    return st;
  }
  if (p.kind === 'corrupt') {
    st.outcome = 'invalid-payload';
    st.payload.truncated = true;
    st.result = classifyOutcome({ ...got, input: { kind: 'lua', truncated: true, error: `${p.label}${p.notes.length ? `: ${p.notes.join('; ')}` : ''}` } });
    return st;
  }
  if (p.kind === 'binary') {
    st.outcome = 'unsupported-payload';
    const v = bytes.length > 4 && bytes[0] >= 3 && bytes[0] <= 6;
    st.result = classifyOutcome({ ...got, input: { kind: v ? 'luau-bytecode' : 'binary', error: `${p.label}${p.notes.length ? ` (${p.notes.join('; ')})` : ''}` } });
    return st;
  }
  const texts = p.kind === 'lua' || p.kind === 'luac' || p.kind === 'luajit' ? [{ name, text: p.text }]
    : p.kind === 'model' ? p.scripts.map((s) => ({ name: s.path, text: unicodeToBinary(s.source) })) : [];
  if (!texts.length) {
    st.outcome = 'not-code';
    st.result = classifyOutcome(supplied ? { input: p.kind === 'empty' ? { kind: 'empty' } : { kind: 'text', error: `The content is ${p.label}` } } : { retrieval: { status: p.kind === 'empty' ? 'empty' : 'not-code', reason: `The response is ${p.label}.` } });
    return st;
  }
  // classify + reconstruct, per program in the payload
  st.programs = [];
  for (const prog of texts) {
    const d = (await deps.detect(prog.text)) || {};
    const fams = (d.families || []).filter((f) => f.confidence >= 0.5).map((f) => f.name);
    const next = await deps.analyze(prog.text, { depth: depth + 1, origin: prog.name });
    const entry = { name: prog.name, bytes: prog.text.length, families: fams, obfuscated: fams.length > 0 || (d.traits || []).some((x) => ['vm', 'state-machine', 'string-table', 'loadstring-layer', 'minified'].includes(x.id)) };
    if (next.isLoader && !next.payload.ownProgram && depth + 1 <= maxDepth) {
      entry.nestedLoader = { case: next.case.n, requests: next.requests.length };
      st.programs.push(entry);
      await onNested(next, prog.name);
      continue;
    }
    let r = null;
    try { r = await deps.recover(prog.text); } catch (e) { r = null; entry.error = String(e.message || e); }
    entry.reconstruction = r ? { ok: r.output != null, level: r.confidence ? r.confidence.level : r.level || null, score: r.confidence ? r.confidence.score : null, bytes: r.output ? r.output.length : 0 } : { ok: false, level: null };
    entry.output = r && r.output != null ? r.output : null;
    // syntax and behavioural validation: the class comes from the evidence (src/validate/outcome.js), never from the confidence alone
    const ev = r && r.outcome && r.outcome.evidence
      ? { ...r.outcome.evidence, obfuscated: entry.obfuscated || r.outcome.evidence.obfuscated }
      : { input: inputEvidence(prog.text, parse), obfuscated: entry.obfuscated, recovery: r ? { output: entry.output, parses: entry.output != null ? parsesOk(entry.output) : undefined, level: entry.reconstruction.level, error: entry.error } : { output: null, error: entry.error } };
    let behaviour = null;
    if (deps.verify && entry.output != null && ev.recovery && ev.recovery.parses !== false) {
      try {
        const v = await deps.verify(prog.text, entry.output);
        if (v && v.verdict) behaviour = { verdict: v.verdict, against: 'input', coverage: v.coverage ? v.coverage.ratio : null, note: v.difference ? `${v.difference.original} / ${v.difference.recovered}` : (v.notes || [])[0] };
      } catch (e) { behaviour = { verdict: 'inconclusive', against: 'input', note: String(e.message || e) }; }
    }
    entry.behaviour = behaviour;
    entry.result = classifyOutcome({ ...ev, ...got, behaviour });
    if (opts.keepText) entry.source = prog.text;
    st.programs.push(entry);
  }
  st.outcome = st.programs.every((x) => x.nestedLoader) ? 'nested-loader'
    : st.programs.some((x) => x.result && x.result.outcome === 'validated' && x.obfuscated) ? 'retrieved-reconstructed'
    : st.programs.some((x) => x.result && !x.obfuscated && ['validated', 'syntax-valid-unverified'].includes(x.result.outcome)) ? 'retrieved-plain'
    : 'retrieved-unrecoverable';
  // the stage's class is the best one among its programs (a model can hold several scripts)
  const ranked = st.programs.filter((x) => x.result).sort((a, b) => RANK.indexOf(a.result.outcome) - RANK.indexOf(b.result.outcome));
  if (ranked.length) st.result = ranked[0].result;
  return st;
}

// the order classes are preferred in when a stage holds several programs (best first)
const RANK = ['validated', 'syntax-valid-unverified', 'partial', 'not-deobfuscated', 'unsupported-format', 'invalid-input', 'authorization-unavailable', 'payload-unavailable'];

const parsesOk = (t) => { try { parse(t); return true; } catch { return false; } };
const preview = (t) => String(t).replace(/\s+/g, ' ').trim().slice(0, 80);

/** Text that is plausibly Lua (with a syntax error) rather than a message: it has Lua's structure, not only words. */
function looksLikeLua(t) {
  const s = String(t).slice(0, 20000);
  const tokens = (s.match(/\b(local|function|end|then|return|do)\b|[=(){}\[\]]/g) || []).length;
  const words = (s.match(/[A-Za-z]+/g) || []).length || 1;
  return tokens >= 3 && tokens / words > 0.15;
}

// model sources are JS strings (UTF-16); the engine works on binary strings (one char per byte)
function unicodeToBinary(s) {
  const bytes = new TextEncoder().encode(s);
  let out = '';
  for (let i = 0; i < bytes.length; i += 0x8000) out += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return out;
}

/** A plain-text report of an intel result, for export. */
export function intelMarkdown(report, { name = 'loader' } = {}) {
  const L = [];
  const s = report.summary;
  L.push(`# Loader Intelligence report: ${name}`, '');
  L.push(`Case ${report.loader.case.n}: ${report.loader.case.label}.${report.loader.families.length ? ` Service: ${report.loader.families.map((f) => f.name).join(', ')}.` : ''}`);
  L.push(`Architectures: ${report.loader.architectures.join(', ') || 'none'}.`, '');
  L.push('| Measure | Count |', '|---|---|');
  for (const [k, v] of [['requests found', s.requests], ['retrievable through an authorised route', s.retrievable], ['transport succeeded', s.transportOk], ['payload is code', s.payloadCode], ['reconstructed and behaviourally validated', s.reconstructed], ['plain (not obfuscated)', s.plain], ['retrieved but not reconstructed and validated', s.unrecoverable], ['not code', s.notCode], ['transport failed', s.transportFailed], ['not retrievable', s.notRetrievable], ['another loader', s.nested]]) L.push(`| ${k} | ${v} |`);
  L.push('');
  if (s.classes && Object.keys(s.classes).length) {
    L.push('| Result | Stages |', '|---|---|');
    for (const [k, v] of Object.entries(s.classes)) L.push(`| ${RESULT_LABELS[k] || k} | ${v} |`);
    L.push('');
  }
  report.stages.forEach((st, i) => {
    L.push(`## Stage ${i + 1} (depth ${st.depth}): ${st.result ? st.result.label : OUTCOMES[st.outcome] || st.outcome}`, '');
    if (st.result && st.result.reasons.length) L.push(`- Why: ${st.result.reasons.join(' ')}`);
    L.push(`- Request: \`${st.request.api}\` → \`${st.request.address}\` (${st.request.urlKind}${st.request.family ? `, ${st.request.family}` : ''})`);
    L.push(`- Route: ${st.route.route} — ${st.route.reason}`);
    if (st.transport) L.push(`- Transport: ${st.transport.ok ? `HTTP ${st.transport.status ?? 200}, ${st.transport.bytes} bytes, SHA-256 ${st.transport.sha256}` : `failed: ${st.transport.error}`}`);
    if (st.payload) L.push(`- Payload: ${st.payload.label}${st.payload.layers.length ? ` (layers: ${st.payload.layers.map((l) => l.kind).join(' → ')})` : ''}`);
    for (const p of st.programs || []) {
      L.push(`- Program \`${p.name}\`: ${p.bytes} bytes; ${p.families.length ? `obfuscator: ${p.families.join(', ')}` : p.obfuscated ? 'obfuscated (no known tool)' : 'not obfuscated'}${p.nestedLoader ? `; another loader (case ${p.nestedLoader.case})` : ''}${p.reconstruction ? `; reconstruction: ${p.reconstruction.ok ? `engine confidence ${p.reconstruction.level}` : 'no output'}` : ''}${p.behaviour ? `; behaviour vs the retrieved program: ${p.behaviour.verdict}` : p.reconstruction && p.reconstruction.ok ? '; behaviour not compared' : ''}${p.result ? `; result: ${p.result.label}` : ''}`);
    }
    L.push('');
  });
  return L.join('\n');
}

export { binaryToText };
