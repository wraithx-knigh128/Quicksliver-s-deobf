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

export const OUTCOMES = {
  'not-retrievable': 'not retrievable through an authorised route',
  'transport-failed': 'the request failed',
  'not-code': 'retrieved, but the response is not code',
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
      if (!req.retrieval.possible || !routes.has(req.retrieval.route)) { st.outcome = 'not-retrievable'; continue; }
      // transport
      const t = Date.now();
      let res;
      try { res = await deps.fetchStage(req); } catch (e) { res = { ok: false, error: String(e.message || e) }; }
      st.transport = { ok: !!res.ok, status: res.status ?? null, error: res.ok ? null : res.error || `HTTP ${res.status}`, bytes: res.bytes ? res.bytes.length : 0, ms: res.ms ?? Date.now() - t };
      if (!res.ok || !res.bytes) { st.outcome = 'transport-failed'; continue; }
      st.transport.sha256 = await sha256(res.bytes);
      // payload
      const p = await deps.decode(res.bytes, { contentType: res.contentType });
      st.payload = { kind: p.kind, label: p.label, layers: p.layers, parses: p.parses ?? null, notes: p.notes, scripts: p.scripts ? p.scripts.map((s) => ({ path: s.path, className: s.className, bytes: s.source.length })) : undefined };
      const texts = p.kind === 'lua' || p.kind === 'luac' || p.kind === 'luajit' ? [{ name: req.url, text: p.text }]
        : p.kind === 'model' ? p.scripts.map((s) => ({ name: s.path, text: unicodeToBinary(s.source) })) : [];
      if (!texts.length) { st.outcome = 'not-code'; continue; }
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
          await visit(next, depth + 1, prog.name);
          continue;
        }
        let r = null;
        try { r = await deps.recover(prog.text); } catch (e) { r = null; entry.error = String(e.message || e); }
        entry.reconstruction = r ? { ok: r.output != null, level: r.confidence ? r.confidence.level : r.level || null, score: r.confidence ? r.confidence.score : null, bytes: r.output ? r.output.length : 0 } : { ok: false, level: null };
        entry.output = r && r.output != null ? r.output : null;
        if (opts.keepText) entry.source = prog.text;
        st.programs.push(entry);
      }
      st.outcome = st.programs.every((x) => x.nestedLoader) ? 'nested-loader'
        : st.programs.some((x) => x.reconstruction && x.obfuscated && ['high', 'medium'].includes(x.reconstruction.level)) ? 'retrieved-reconstructed'
        : st.programs.some((x) => x.reconstruction && !x.obfuscated && x.reconstruction.ok) ? 'retrieved-plain'
        : 'retrieved-unrecoverable';
    }
  }
  await visit(loader, 0, 'input');

  const count = (o) => stages.filter((s) => s.outcome === o).length;
  const summary = {
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
  for (const [k, v] of [['requests found', s.requests], ['retrievable through an authorised route', s.retrievable], ['transport succeeded', s.transportOk], ['payload is code', s.payloadCode], ['reconstructed (high/medium confidence)', s.reconstructed], ['plain (not obfuscated)', s.plain], ['retrieved but not reconstructed', s.unrecoverable], ['not code', s.notCode], ['transport failed', s.transportFailed], ['not retrievable', s.notRetrievable], ['another loader', s.nested]]) L.push(`| ${k} | ${v} |`);
  L.push('');
  report.stages.forEach((st, i) => {
    L.push(`## Stage ${i + 1} (depth ${st.depth}): ${OUTCOMES[st.outcome] || st.outcome}`, '');
    L.push(`- Request: \`${st.request.api}\` → \`${st.request.address}\` (${st.request.urlKind}${st.request.family ? `, ${st.request.family}` : ''})`);
    L.push(`- Route: ${st.route.route} — ${st.route.reason}`);
    if (st.transport) L.push(`- Transport: ${st.transport.ok ? `HTTP ${st.transport.status ?? 200}, ${st.transport.bytes} bytes, SHA-256 ${st.transport.sha256}` : `failed: ${st.transport.error}`}`);
    if (st.payload) L.push(`- Payload: ${st.payload.label}${st.payload.layers.length ? ` (layers: ${st.payload.layers.map((l) => l.kind).join(' → ')})` : ''}`);
    for (const p of st.programs || []) {
      L.push(`- Program \`${p.name}\`: ${p.bytes} bytes; ${p.families.length ? `obfuscator: ${p.families.join(', ')}` : p.obfuscated ? 'obfuscated (no known tool)' : 'not obfuscated'}${p.nestedLoader ? `; another loader (case ${p.nestedLoader.case})` : ''}${p.reconstruction ? `; reconstruction: ${p.reconstruction.ok ? `confidence ${p.reconstruction.level}` : 'no output'}` : ''}`);
    }
    L.push('');
  });
  return L.join('\n');
}

export { binaryToText };
