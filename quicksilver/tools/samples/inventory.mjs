#!/usr/bin/env node
// Prompt XXIV: inventory of a sample collection (github.com/terrorlua/obfuscator-samples, kept outside the repository and linked from the
// git-ignored local/terrorlua). Every file is read as text, never run. Per file: its folder labels, size, structural features, what the
// detector says and how confident it is. Nothing of a file's content is stored, only measurements, so the output can be summarised into
// the repository without redistributing the samples (the collection states no licence).
//
//   node tools/samples/inventory.mjs [root] [--out local/terrorlua-inventory.jsonl] [--workers 3] [--only Luraph/v15.2] [--timeout 30000]
//
// Output: one JSON line per file (resumable: files already in the output are skipped).

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { Worker, isMainThread, parentPort, workerData } from 'node:worker_threads';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.join(here, '..', '..');

// ---- per-file measurement (worker) -----------------------------------------------------------------------------------------------------

/** Vendor text in the first lines: "protected/obfuscated/generated with/by X vN" and similar. Text the file's author controls. */
export function bannerOf(head) {
  const m = /(?:protected|obfuscated|generated|made|encrypted)\s+(?:using|with|by)\s+([^\r\n\]]{2,90})/i.exec(head)
    || /\b(Luraph Obfuscator v[0-9.]+|MoonSec V\d[^\r\n]{0,40}|Hercules v?[0-9.]+|Prometheus[^\r\n]{0,40}|Boronide[^\r\n]{0,60}|PSU[^\r\n]{0,40}|IronBrew[^\r\n]{0,40}|MoonVeil[^\r\n]{0,40}|wYnFuscate[^\r\n]{0,40}|77fuscator[^\r\n]{0,40}|SynapseXen[^\r\n]{0,40}|LuaObfuscator[^\r\n]{0,40})/i.exec(head);
  return m ? m[0].replace(/\s+/g, ' ').trim().slice(0, 120) : null;
}

/** Number of long-bracket strings of 2000 characters or more (a linear scan: openers, then the matching closer). */
function longStrings(s) {
  let n = 0;
  const re = /\[(=*)\[/g;
  let m;
  while ((m = re.exec(s))) {
    const close = s.indexOf(`]${m[1]}]`, m.index + m[0].length);
    if (close < 0) break;
    if (close - m.index >= 2000) n++;
    re.lastIndex = close + m[1].length + 2;
  }
  return n;
}

/** Cheap structural features (no parse): what kind of text this is. */
export function textFeatures(s) {
  const n = s.length || 1;
  const lines = s.split('\n').length;
  let longest = 0;
  for (const l of s.split('\n')) if (l.length > longest) longest = l.length;
  const count = (re) => (s.match(re) || []).length;
  return {
    lines,
    longestLine: longest,
    escapes: +(count(/\\\d{1,3}/g) / n * 1000).toFixed(2),           // decimal escapes per 1000 chars
    hexEscapes: +(count(/\\x[0-9a-fA-F]{2}/g) / n * 1000).toFixed(2),
    longStrings: longStrings(s),
    bytecodeSig: /\x1bLua|\\27Lua|\\x1bLua/.test(s),
    loadstring: count(/\bloadstring\b|\bload\s*\(/g),
    getfenv: count(/\bgetfenv\b|\bsetfenv\b/g),
    bit32: count(/\bbit32\.|\bbit\./g),
    whileTrue: count(/\bwhile\s+true\s+do\b|\bwhile\s+1\s+do\b|\brepeat\b/g),
    stringChar: count(/string\.char|\.char\(/g),
    nonAscii: +(count(/[\x80-\xff]/g) / n * 1000).toFixed(2),
  };
}

async function measure(file, label, detectScript) {
  const buf = fs.readFileSync(file);
  const s = buf.toString('latin1');
  const t = Date.now();
  const rec = { path: label.rel, label: label.family, sub: label.sub, bytes: buf.length, banner: bannerOf(s.slice(0, 3000)), ...textFeatures(s) };
  try {
    const r = detectScript(s);
    const d = r.detection;
    rec.parsed = d.parsed;
    if (!d.parsed && d.parseError) rec.parseError = String(d.parseError.message || d.parseError).slice(0, 120);
    rec.dialect = d.dialect ? d.dialect.id : null;
    rec.families = (d.families || []).slice(0, 3).map((f) => [f.id, +(+f.confidence).toFixed(3), f.version || null]);
    rec.traits = (d.traits || []).map((x) => x.id);
    rec.classes = (d.classes || []).map((x) => x.id);
    rec.mangled = d.metrics ? +(+d.metrics.mangledRatio || 0).toFixed(3) : null;
  } catch (e) {
    rec.error = String(e && e.message || e).slice(0, 160);
  }
  rec.ms = Date.now() - t;
  return rec;
}

if (!isMainThread) {
  const { detectScript } = await import(path.join(repo, 'src', 'api.js'));
  parentPort.on('message', async (job) => {
    if (!job) process.exit(0);
    try { parentPort.postMessage({ ok: true, rec: await measure(job.file, job.label, detectScript) }); } catch (e) { parentPort.postMessage({ ok: false, path: job.label.rel, error: String(e.message || e) }); }
  });
}

// ---- walk + pool (main) ----------------------------------------------------------------------------------------------------------------

export function walkCollection(root) {
  const out = [];
  const visit = (dir) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      if (e.name === '.git') continue;
      const p = path.join(dir, e.name);
      if (e.isDirectory()) visit(p);
      else if (e.isFile() && /\.(lua|luau|txt)$/i.test(e.name)) {
        const rel = path.relative(root, p).split(path.sep).join('/');
        const parts = rel.split('/');
        out.push({ file: p, label: { rel, family: parts.length > 1 ? parts[0] : null, sub: parts.length > 2 ? parts.slice(1, -1).join('/') : null } });
      }
    }
  };
  visit(root);
  return out.sort((a, b) => a.label.rel.localeCompare(b.label.rel));
}

async function main() {
  const args = process.argv.slice(2);
  const opt = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
  const root = path.resolve(args[0] && !args[0].startsWith('--') ? args[0] : path.join(repo, 'local', 'terrorlua'));
  const out = path.resolve(opt('--out', path.join(repo, 'local', 'terrorlua-inventory.jsonl')));
  const workers = Math.max(1, Math.min(+opt('--workers', 3), os.cpus().length));
  const timeout = +opt('--timeout', 30000);
  const only = opt('--only', null);
  const done = new Set();
  if (fs.existsSync(out)) for (const l of fs.readFileSync(out, 'utf8').split('\n')) { if (l) { try { done.add(JSON.parse(l).path); } catch { /* partial line */ } } }
  const jobs = walkCollection(root).filter((j) => !done.has(j.label.rel) && (!only || j.label.rel.startsWith(only)));
  console.error(`${jobs.length} files to measure (${done.size} already in ${path.relative(repo, out)}), ${workers} workers`);
  const sink = fs.createWriteStream(out, { flags: 'a' });
  let next = 0;
  let finished = 0;
  const started = Date.now();
  const spawn = () => new Promise((resolve) => {
    let w = new Worker(fileURLToPath(import.meta.url), { resourceLimits: { maxOldGenerationSizeMb: 3072 } });
    let cur = null;
    let timer = null;
    const give = () => {
      if (next >= jobs.length) { w.postMessage(null); resolve(); return; }
      cur = jobs[next++];
      timer = setTimeout(() => {
        // a file the detector does not finish in time: recorded as such, and the worker is replaced
        sink.write(JSON.stringify({ path: cur.label.rel, label: cur.label.family, sub: cur.label.sub, bytes: fs.statSync(cur.file).size, timeout: true }) + '\n');
        finished++;
        w.removeAllListeners(); w.on('error', () => {}); w.terminate();
        w = new Worker(fileURLToPath(import.meta.url)); attach(); give();
      }, timeout);
      w.postMessage(cur);
    };
    const attach = () => {
      w.on('message', (m) => {
        clearTimeout(timer);
        sink.write(JSON.stringify(m.ok ? m.rec : { path: m.path, error: m.error }) + '\n');
        if (++finished % 500 === 0) console.error(`${finished}/${jobs.length} (${Math.round((Date.now() - started) / 1000)} s)`);
        give();
      });
      w.on('error', (e) => { clearTimeout(timer); sink.write(JSON.stringify({ path: cur && cur.label.rel, error: `worker: ${String(e.message || e).slice(0, 120)}` }) + '\n'); finished++; w = new Worker(fileURLToPath(import.meta.url)); attach(); give(); });
    };
    attach();
    give();
  });
  await Promise.all(Array.from({ length: workers }, spawn));
  await new Promise((r) => sink.end(r));
  console.error(`done: ${finished} files in ${Math.round((Date.now() - started) / 1000)} s`);
}

if (isMainThread && process.argv[1] === fileURLToPath(import.meta.url)) await main();
