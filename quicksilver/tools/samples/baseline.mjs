#!/usr/bin/env node
// Prompt XXIV: what the website's recovery pipeline does with a sample collection (github.com/terrorlua/obfuscator-samples, linked from
// the git-ignored local/terrorlua). A stratified sample: up to --per files from every folder (obfuscator / version or preset), chosen by
// name — the names are content hashes, so this is an unbiased pick — every file of a smaller folder. Each file goes through
// recoverSource (the call the page and /api make) with sandboxed evaluation on, in a worker that is replaced when it runs too long.
// Recorded per file: the outcome class (src/validate/outcome.js), confidence, the steps that applied, what the detector named, whether the
// output parses, the residual obfuscation, and the time. No file content is stored.
//
//   node tools/samples/baseline.mjs [--per 6] [--workers 3] [--timeout 120000] [--only Luraph/v15] [--out local/terrorlua-baseline.jsonl]
//                                   [--files list.txt]   (one collection-relative path per line, instead of the stratified pick)

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { Worker, isMainThread, parentPort } from 'node:worker_threads';
import { fileURLToPath } from 'node:url';
import { walkCollection } from './collection.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.join(here, '..', '..');

async function measure(job, api) {
  const buf = fs.readFileSync(job.file);
  const s = buf.toString('latin1');
  const t = Date.now();
  const rec = { path: job.label.rel, label: job.label.family, sub: job.label.sub, bytes: buf.length };
  try {
    const r = api.recoverSource(s, { sandbox: { enabled: true } });
    const d = r.detection || {};
    rec.family = d.families && d.families[0] ? [d.families[0].id, +(+d.families[0].confidence).toFixed(3), d.families[0].version || null] : null;
    rec.outcome = r.outcome ? r.outcome.outcome : null;
    rec.reasons = r.outcome ? (r.outcome.reasons || []).slice(0, 3).map((x) => String(x).slice(0, 160)) : [];
    rec.level = r.confidence ? r.confidence.level : null;
    rec.score = r.confidence ? +(+r.confidence.score || 0).toFixed(3) : null;
    rec.steps = (r.steps || []).filter((x) => x.status === 'applied').map((x) => x.id);
    rec.failedSteps = (r.steps || []).filter((x) => x.status === 'failed' || x.status === 'error').map((x) => `${x.id}: ${String(x.error || x.detail && x.detail.error || '').slice(0, 80)}`);
    const ev = r.outcome && r.outcome.evidence ? r.outcome.evidence.recovery : null;
    rec.parses = ev ? ev.parses : null;
    rec.residual = ev && Array.isArray(ev.residual) ? ev.residual.map((x) => x.kind || x.id || String(x)).slice(0, 8) : null;
    rec.unresolved = ev ? ev.unresolved : null;
    rec.outBytes = r.output != null ? Buffer.byteLength(r.output, 'latin1') : null;
    rec.changed = r.output != null && r.output !== s;
  } catch (e) {
    rec.crash = String(e && e.stack || e).split('\n').slice(0, 3).join(' | ').slice(0, 300);
  }
  rec.ms = Date.now() - t;
  return rec;
}

if (!isMainThread) {
  const api = await import(path.join(repo, 'src', 'api.js'));
  parentPort.on('message', async (job) => {
    if (!job) process.exit(0);
    try { parentPort.postMessage({ ok: true, rec: await measure(job, api) }); } catch (e) { parentPort.postMessage({ ok: false, path: job.label.rel, error: String(e.message || e) }); }
  });
}

/** Up to `per` files of every folder, by name (content hashes: an unbiased pick). */
export function stratified(all, per) {
  const groups = new Map();
  for (const j of all) {
    const k = `${j.label.family}/${j.label.sub || ''}`;
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k).push(j);
  }
  const out = [];
  for (const list of groups.values()) out.push(...list.slice(0, per));
  return out;
}

async function main() {
  const args = process.argv.slice(2);
  const opt = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
  const root = path.resolve(opt('--root', path.join(repo, 'local', 'terrorlua')));
  const out = path.resolve(opt('--out', path.join(repo, 'local', 'terrorlua-baseline.jsonl')));
  const workers = Math.max(1, Math.min(+opt('--workers', 3), os.cpus().length));
  const timeout = +opt('--timeout', 120000);
  const only = opt('--only', null);
  const listFile = opt('--files', null);
  const all = walkCollection(root);
  let jobs;
  if (listFile) {
    const want = new Set(fs.readFileSync(listFile, 'utf8').split('\n').map((x) => x.trim()).filter(Boolean));
    jobs = all.filter((j) => want.has(j.label.rel));
  } else {
    jobs = stratified(all.filter((j) => !only || j.label.rel.startsWith(only)), +opt('--per', 6));
  }
  const done = new Set();
  if (fs.existsSync(out)) for (const l of fs.readFileSync(out, 'utf8').split('\n')) { if (l) { try { done.add(JSON.parse(l).path); } catch { /* partial line */ } } }
  jobs = jobs.filter((j) => !done.has(j.label.rel));
  console.error(`${jobs.length} files to recover (${done.size} already in ${path.relative(repo, out)}), ${workers} workers`);
  const sink = fs.createWriteStream(out, { flags: 'a' });
  let next = 0;
  let finished = 0;
  const started = Date.now();
  const self = fileURLToPath(import.meta.url);
  const spawn = () => new Promise((resolve) => {
    let w = null;
    let cur = null;
    let timer = null;
    const fresh = () => { w = new Worker(self, { resourceLimits: { maxOldGenerationSizeMb: 3072 } }); attach(); };
    const give = () => {
      if (next >= jobs.length) { w.postMessage(null); resolve(); return; }
      cur = jobs[next++];
      timer = setTimeout(() => {
        sink.write(JSON.stringify({ path: cur.label.rel, label: cur.label.family, sub: cur.label.sub, bytes: fs.statSync(cur.file).size, timeout: true, ms: timeout }) + '\n');
        finished++;
        w.removeAllListeners(); w.on('error', () => {}); w.terminate();
        fresh(); give();
      }, timeout);
      w.postMessage(cur);
    };
    const attach = () => {
      w.on('message', (m) => {
        clearTimeout(timer);
        sink.write(JSON.stringify(m.ok ? m.rec : { path: m.path, error: m.error }) + '\n');
        if (++finished % 25 === 0) console.error(`${finished}/${jobs.length} (${Math.round((Date.now() - started) / 1000)} s)`);
        give();
      });
      w.on('error', (e) => { clearTimeout(timer); sink.write(JSON.stringify({ path: cur && cur.label.rel, label: cur && cur.label.family, sub: cur && cur.label.sub, crash: `worker: ${String(e.message || e).slice(0, 160)}` }) + '\n'); finished++; fresh(); give(); });
    };
    fresh();
    give();
  });
  await Promise.all(Array.from({ length: workers }, spawn));
  await new Promise((r) => sink.end(r));
  console.error(`done: ${finished} files in ${Math.round((Date.now() - started) / 1000)} s`);
}

if (isMainThread && process.argv[1] === fileURLToPath(import.meta.url)) await main();
