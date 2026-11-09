// Research collector: read permitted public sources and keep a persistent, checkable record of each.
//
//   NODE_USE_ENV_PROXY=1 node tools/research/collect.mjs [--plan data/research/plan.json] [--ai] [url ...]
//
// For every URL: fetch it under the policy (api/_lib/research-fetch.js), classify the source and score its credibility, extract findings by rule
// (every finding carries the exact text it came from), scan the text for passages that try to instruct a reader, and write
//
//   data/research/records/<id>.json   the record: url, when, status, hash, size, credibility, findings, digest, history of earlier fetches
//   data/research/cache/<sha256>.txt  the text itself (git-ignored: third-party text is not redistributed; the hash lets anyone check a record)
//
// A source that cannot be read is recorded with the reason (`unreachable`, `not_found`, `host_not_permitted`, ...). Failures are results.
// With --ai (and ANTHROPIC_API_KEY set) the document also goes through the grounded model extraction; without a key that step is recorded as skipped.
// Nothing fetched is ever executed, and repositories that claim to defeat a protection are read as text only.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { fetchText, ResearchFetchError, normalizeResearchUrl } from '../../api/_lib/research-fetch.js';
import { classifySource, extractFindings, injectionScan, digest } from '../../api/_lib/research-extract.js';
import { extractWithModel, ResearchAIError, configFromEnv } from '../../api/_lib/research-ai.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.join(here, '..', '..', 'data', 'research');

// Node's built-in fetch ignores HTTPS_PROXY unless asked to; in a sandbox with an egress proxy that would make every host look unreachable.
if ((process.env.HTTPS_PROXY || process.env.https_proxy) && !process.env.NODE_USE_ENV_PROXY && !process.env.QS_PROXY_REEXEC) {
  const r = spawnSync(process.execPath, process.argv.slice(1), { stdio: 'inherit', env: { ...process.env, NODE_USE_ENV_PROXY: '1', QS_PROXY_REEXEC: '1' } });
  process.exit(r.status ?? 1);
}

export const recordId = (url) => crypto.createHash('sha256').update(url).digest('hex').slice(0, 12);

/** Collect one URL. @returns the record (also written under `dir`). */
export async function collectOne({ url, subject = null, why = '' }, { dir = dataDir, fetchImpl = fetch, ai = false, aiConfig = null, now = () => new Date() } = {}) {
  const fetchedAt = now().toISOString();
  let canonical = url;
  try { canonical = normalizeResearchUrl(url).toString(); } catch { /* recorded below as a refusal */ }
  const id = recordId(canonical);
  const file = path.join(dir, 'records', `${id}.json`);
  const previous = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : null;
  const record = { id, url: canonical, requestedUrl: url, subject, why, fetchedAt, history: previous ? [...(previous.history || []), { fetchedAt: previous.fetchedAt, sha256: previous.sha256 || null, ok: previous.ok }] : [] };
  try {
    const got = await fetchText(url, { fetchImpl, minGapMs: Number(process.env.QS_RESEARCH_GAP_MS ?? 1000) });
    const sha = crypto.createHash('sha256').update(got.text).digest('hex');
    const findings = extractFindings(got.text);
    Object.assign(record, {
      ok: true, status: got.status, finalUrl: got.finalUrl, contentType: got.contentType, bytes: got.bytes, truncated: got.truncated, sha256: sha,
      credibility: classifySource(got.finalUrl, subject), findings, injection: injectionScan(got.text), digest: digest(got.text, findings),
      excerpt: got.text.slice(0, 400).replace(/\s+/g, ' ').trim(),
    });
    fs.mkdirSync(path.join(dir, 'cache'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'cache', `${sha}.txt`), got.text);
    if (ai) {
      const cfg = aiConfig || configFromEnv();
      if (!cfg.apiKey && !cfg.client) record.model = { skipped: 'no_credentials' };
      else {
        try {
          const m = await extractWithModel({ text: got.text, url: got.finalUrl, subject, retrievedAt: fetchedAt, sourceClass: record.credibility.class }, cfg);
          record.model = { model: m.model, summary: m.summary, findings: m.findings, rejected: m.rejected.length, rejectedDetail: m.rejected.slice(0, 20), suspectedInjection: m.suspectedInjection, usage: m.usage, requestId: m.requestId };
        } catch (e) {
          if (!(e instanceof ResearchAIError)) throw e;
          record.model = { failed: e.code, message: e.message };
        }
      }
    }
  } catch (e) {
    if (!(e instanceof ResearchFetchError)) throw e;
    Object.assign(record, { ok: false, error: { code: e.code, message: e.message }, credibility: (() => { try { return classifySource(canonical, subject); } catch { return null; } })() });
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(record, null, 1) + '\n');
  return record;
}

/** Each item may list `fallbacks` (e.g. the same file on another branch): they are tried, in order, only when the first URL is not found. */
export async function collectAll(items, opts = {}) {
  const out = [];
  for (const raw of items) {
    const item = typeof raw === 'string' ? { url: raw } : raw;
    const { fallbacks = [], ...rest } = item;
    let record = await collectOne(rest, opts);
    for (const alt of fallbacks) {
      if (record.ok || !record.error || record.error.code !== 'not_found') break;
      record = await collectOne({ ...rest, url: alt }, opts);
    }
    out.push(record);
  }
  return out;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const argv = process.argv.slice(2);
  const flag = (f) => (argv.includes(f) ? argv[argv.indexOf(f) + 1] : null);
  const planFile = flag('--plan');
  const urls = argv.filter((a, i) => /^https?:/.test(a) && argv[i - 1] !== '--plan');
  const items = [...(planFile ? JSON.parse(fs.readFileSync(planFile, 'utf8')).sources : []), ...urls];
  if (!items.length) { console.error('usage: collect.mjs [--plan plan.json] [--ai] [url ...]'); process.exit(2); }
  const records = await collectAll(items, { ai: argv.includes('--ai') });
  for (const r of records) console.log(`${r.ok ? 'ok     ' : (r.error.code + ' ').padEnd(7)} ${String(r.credibility ? r.credibility.score : '-').padEnd(5)} ${(r.credibility ? r.credibility.class : '').padEnd(26)} ${r.findings ? r.findings.length : 0} findings  ${r.url}`);
  console.log(`${records.filter((r) => r.ok).length} read, ${records.filter((r) => !r.ok).length} not read -> ${path.join(dataDir, 'records')}`);
}
