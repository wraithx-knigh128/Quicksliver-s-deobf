// /api/engine — server-side engines the one Deobfuscate pipeline calls when the format needs one (Prompt XXIX).
//
// Two engines: moonsec-v3, the vendored MoonSec V3 deobfuscator (api/_engine/moonsec, GPL-3.0), which rebuilds the program the MoonSec
// V3 VM carries as Lua 5.1 bytecode that the page decompiles with QuickSilver's own decompiler; and prometheus-vm (api/_engine/prometheus,
// MIT), which lifts a Prometheus VM build to Lua source that the page accepts only after a behaviour comparison with the script. The engine only reads the script — it never runs it — but it is third-party code working on untrusted input, so it runs
// in a separate process through api/_lib/isolate.js, and only on input this server first recognises as MoonSec V3.
//
//   GET                                  → which engines this deployment offers, and how they are isolated
//   POST {engine, source (base64), attest: true}
//        → 200 {ok: true, engine, output ('lua51-bytecode' | 'lua-source'), bytecode | source (base64), bytes, ms, isolation, licence}
//        → 4xx/5xx {ok: false, outcome, message}
// Premium (checkEntitlement 'engine'), an attestation that the person may analyse the script, a size limit, a per-instance rate limit and
// a concurrency limit, as for the Luraph engine (api/reconstruct.py). Environment: QS_ENGINE_MODE (open | off), QS_ENGINE_MAX_BYTES,
// QS_ENGINE_RPM, QS_ENGINE_CONCURRENCY, QS_ENGINE_TIMEOUT_S.

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { checkEntitlement } from './_lib/entitlement.js';
import { runEngine, isolationMode } from './_lib/isolate.js';
import { detect } from '../src/detect/detect.js';
import { parse } from '../src/core/parser.js';

const here = path.dirname(fileURLToPath(import.meta.url));

export const ENGINES = Object.freeze({
  'moonsec-v3': {
    label: 'MoonSec V3 deobfuscator',
    dir: path.join(here, '_engine', 'moonsec'),
    driver: 'qs-driver.js',
    modules: ['fengari', 'luaparse', 'readline-sync', 'sprintf-js', 'tmp'],
    family: 'moonsec_v3',
    licence: 'GPL-3.0: moonsec-deobfuscator-js, a JavaScript port of tupsutumppu/MoonsecDeobfuscator (modified; see api/_engine/moonsec/NOTICE.md)',
    output: 'lua51-bytecode',
  },
  // Prompt XXIX: Prometheus VM builds (Vmify; the Weak, Medium and Strong presets). Its answer is Lua source, and the page uses it only
  // after a behaviour comparison with the script itself (src/pipeline/engines.js: verify.required)
  'prometheus-vm': {
    label: 'Prometheus deobfuscator',
    dir: path.join(here, '_engine', 'prometheus'),
    driver: 'qs-driver.js',
    modules: [],
    family: 'prometheus',
    rules: ['vmify-wrapper'],
    licence: 'MIT: Prometheus Deobfuscator by LeakD (modified; see api/_engine/prometheus/NOTICE.md)',
    output: 'lua-source',
  },
});

const json = (res, status, body, headers = {}) => {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  for (const [k, v] of Object.entries(headers)) res.setHeader(k, v);
  res.end(JSON.stringify(body));
};

/** Is this text the format the engine reads? Decided by QuickSilver's own detection, never by the engine. */
export function accepts(engine, text) {
  const d = detect(text);
  const f = (d.families || []).find((x) => x.id === engine.family);
  // an engine for one part of a format (the Prometheus VM) needs the rule that marks that part, not only the family
  const fits = f && f.confidence >= 0.5 && (!engine.rules || (f.evidence || []).some((e) => engine.rules.includes(e.rule)));
  return fits ? { ok: true, confidence: f.confidence } : { ok: false, families: (d.families || []).filter((x) => x.confidence >= 0.5).map((x) => x.id) };
}

const isLua51Chunk = (b) => b.length > 12 && b[0] === 0x1b && b[1] === 0x4c && b[2] === 0x75 && b[3] === 0x61 && b[4] === 0x51;
const parsesAsLua = (b) => { try { parse(b.toString('latin1')); return true; } catch { return false; } };

export function createHandler({ env = process.env, now = () => Date.now(), run = runEngine } = {}) {
  const hits = [];
  let active = 0;
  return async function handler(req, res) {
    if ((env.QS_ENGINE_MODE || 'open') === 'off') return json(res, 503, { ok: false, outcome: 'disabled', message: 'Server engines are switched off on this deployment (QS_ENGINE_MODE=off).' });
    if (req.method === 'GET') return json(res, 200, { ok: true, service: 'engine', isolation: isolationMode(), engines: Object.entries(ENGINES).map(([id, e]) => ({ id, label: e.label, family: e.family, output: e.output, licence: e.licence })) });
    if (req.method !== 'POST') return json(res, 405, { ok: false, outcome: 'invalid-request', message: 'POST {engine, source, attest}.' }, { Allow: 'GET, POST' });
    const site = req.headers && req.headers['sec-fetch-site'];
    if (site && !['same-origin', 'none'].includes(site)) return json(res, 403, { ok: false, outcome: 'forbidden', message: 'This endpoint is for the QuickSilver page only.' });
    const ent = await checkEntitlement(req, 'engine', { env });
    if (!ent.ok) return json(res, ent.status, { ok: false, outcome: ent.code, message: ent.message, licensing: ent.licensing });
    const maxBytes = Number(env.QS_ENGINE_MAX_BYTES) || 4 * 1024 * 1024;
    let body;
    try {
      if (req.body && typeof req.body === 'object') body = req.body;
      else {
        const chunks = []; let n = 0;
        for await (const c of req) { n += c.length; if (n > Math.ceil(maxBytes * 1.4) + 4096) throw new Error('large'); chunks.push(c); }
        body = JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
      }
    } catch { return json(res, 413, { ok: false, outcome: 'too-large', message: `The request is not valid JSON, or the script is larger than ${maxBytes} bytes.` }); }
    const engine = ENGINES[body && body.engine];
    if (!engine) return json(res, 400, { ok: false, outcome: 'unknown-engine', message: `No engine "${String(body && body.engine).slice(0, 40)}" on this deployment.` });
    if (body.attest !== true) return json(res, 400, { ok: false, outcome: 'attestation_required', message: 'Confirm that you own this script or are authorised to analyse it (attest: true).' });
    const input = typeof body.source === 'string' ? Buffer.from(body.source, 'base64') : null;
    if (!input || !input.length) return json(res, 400, { ok: false, outcome: 'invalid-input', message: 'No script was sent.' });
    if (input.length > maxBytes) return json(res, 413, { ok: false, outcome: 'too-large', message: `The script is larger than ${maxBytes} bytes.` });
    const ok = accepts(engine, input.toString('latin1'));
    if (!ok.ok) return json(res, 422, { ok: false, outcome: 'not-this-format', message: `This script is not recognised as ${engine.label.replace(/ deobfuscator$/, '')}${ok.families && ok.families.length ? ` (it looks like ${ok.families.join(', ')})` : ''}; the engine was not started.` });
    const rpm = Number(env.QS_ENGINE_RPM) || 12;
    const t0 = now();
    while (hits.length && t0 - hits[0] > 60_000) hits.shift();
    if (hits.length >= rpm) return json(res, 429, { ok: false, outcome: 'rate-limited', message: `More than ${rpm} engine runs a minute on this server.` }, { 'Retry-After': '30' });
    if (active >= (Number(env.QS_ENGINE_CONCURRENCY) || 2)) return json(res, 429, { ok: false, outcome: 'busy', message: 'The engine is busy; try again in a moment.' }, { 'Retry-After': '10' });
    hits.push(t0);
    active++;
    try {
      const r = await run({ engineDir: engine.dir, driver: engine.driver, modules: engine.modules, input, timeoutS: Number(env.QS_ENGINE_TIMEOUT_S) || 60 });
      if (r.timedOut) return json(res, 504, { ok: false, outcome: 'timeout', message: 'The engine did not finish in time.', isolation: r.isolation });
      if (!r.output) return json(res, 422, { ok: false, outcome: 'engine-failed', message: `The engine could not rebuild this script: ${(r.stderr.match(/moonsec: (.*)/) || [])[1] || 'no result'}`.slice(0, 400), isolation: r.isolation });
      if (engine.output === 'lua51-bytecode' && !isLua51Chunk(r.output)) return json(res, 502, { ok: false, outcome: 'engine-failed', message: 'The engine answered with something that is not a Lua 5.1 chunk.', isolation: r.isolation });
      if (engine.output === 'lua-source' && !parsesAsLua(r.output)) return json(res, 502, { ok: false, outcome: 'engine-failed', message: 'The engine answered with Lua that does not parse.', isolation: r.isolation });
      const payload = engine.output === 'lua-source' ? { source: r.output.toString('base64') } : { bytecode: r.output.toString('base64') };
      return json(res, 200, { ok: true, engine: body.engine, output: engine.output, ...payload, bytes: r.output.length, ms: r.ms, isolation: r.isolation, licence: engine.licence, licensing: ent.licensing });
    } finally { active--; }
  };
}

export default createHandler();
