// Measure the recovery pipeline against every real-tool fixture.
//
//   QS_LUA_PYTHON=/path/to/python-with-lupa node tests/tools-scorecard.mjs [--filter text] [--no-sandbox] [--write]
//
// For each fixture it records detection, fidelity to the original source before and after recovery,
// and (when the real-Lua oracle is configured) whether the recovered code behaves like the obfuscated input.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { recover } from '../src/recover/pipeline.js';
import { fidelity } from '../src/core/fidelity.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const args = process.argv.slice(2);
const filter = args.includes('--filter') ? args[args.indexOf('--filter') + 1] : '';
const sandbox = !args.includes('--no-sandbox');
const write = args.includes('--write');
const outName = args.includes('--out') ? args[args.indexOf('--out') + 1] : 'scorecard.json';

const tools = [['prometheus', 'obfuscated/prometheus'], ['hercules', 'obfuscated/hercules']];
const results = [];
const read = (p) => bytesToBinary(fs.readFileSync(p));

for (const [tool, dir] of tools) {
  const manifest = JSON.parse(fs.readFileSync(path.join(corpus, dir, 'manifest.json'), 'utf8'));
  for (const e of manifest.entries) {
    if (e.status !== 'ok' || !`${tool}/${e.file}`.includes(filter)) continue;
    const original = read(path.join(corpus, 'originals', e.sample));
    const input = read(path.join(corpus, dir, e.file));
    const entry = { tool, config: e.config, sample: e.sample.replace(/\.lua$/, ''), file: e.file, toolBehavior: e.behavior };
    try { entry.fidelityBefore = fidelity(original, input).score; } catch { entry.fidelityBefore = null; }
    const t0 = Date.now();
    let r;
    try { r = recover(input, { sandbox: { enabled: sandbox } }); } catch (err) { entry.crash = String(err.stack || err).split('\n').slice(0, 3).join(' | '); results.push(entry); continue; }
    entry.ms = Date.now() - t0;
    entry.ok = r.ok;
    entry.confidence = r.confidence ? r.confidence.score : null;
    entry.detected = r.detection.families.filter((f) => f.confidence >= 0.5).map((f) => `${f.id}:${f.confidence.toFixed(2)}`);
    entry.steps = r.steps.filter((s) => s.status === 'applied' || s.status === 'failed').map((s) => `${s.id}${s.status === 'failed' ? '(FAILED: ' + s.error + ')' : '×' + s.changed}`);
    if (r.output) {
      try { entry.fidelityAfter = fidelity(original, r.output).score; } catch { entry.fidelityAfter = null; }
      entry.outputBytes = r.output.length;
      if (oracle.available && e.behavior !== 'errored') {
        const rt = Object.entries(e.behaviors || {}).find(([, v]) => v !== 'errored')?.[0] || 'lua51';
        const before = await oracle.runLua(input, rt);
        const after = await oracle.runLua(r.output, rt);
        entry.behavior = !after.ok ? `error: ${(after.error || '').slice(0, 80)}` : after.stdout === before.stdout ? 'same' : 'differs';
      }
    } else entry.error = r.error;
    results.push(entry);
  }
}
oracle.stopOracle?.();

// ---- report ---------------------------------------------------------------------------------------------------
const groups = new Map();
for (const r of results) {
  const k = `${r.tool}/${r.config}`;
  if (!groups.has(k)) groups.set(k, []);
  groups.get(k).push(r);
}
const avg = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : NaN);
const pct = (x) => (Number.isNaN(x) ? '   - ' : (x * 100).toFixed(0).padStart(3) + '%');
console.log('config'.padEnd(36), 'n  detect  fid-before  fid-after  conf  behaviour(same/diff/err)');
for (const [k, rs] of groups) {
  const det = rs.filter((r) => r.detected && r.detected.length).length;
  const fb = avg(rs.map((r) => r.fidelityBefore).filter((x) => x != null));
  const fa = avg(rs.map((r) => r.fidelityAfter).filter((x) => x != null));
  const same = rs.filter((r) => r.behavior === 'same').length;
  const diff = rs.filter((r) => r.behavior === 'differs').length;
  const err = rs.filter((r) => r.behavior && r.behavior.startsWith('error')).length;
  const crash = rs.filter((r) => r.crash || r.error).length;
  const cf = avg(rs.map((r) => r.confidence).filter((x) => x != null));
  console.log(k.padEnd(36), String(rs.length).padStart(1), `${det}/${rs.length}`.padStart(6), pct(fb).padStart(10), pct(fa).padStart(10), pct(cf).padStart(6), `   ${same}/${diff}/${err}${crash ? '  crashes:' + crash : ''}`);
}
const pairs = results.filter((r) => r.confidence != null && r.fidelityAfter != null);
if (pairs.length > 3) {
  const xs = pairs.map((r) => r.confidence); const ys = pairs.map((r) => r.fidelityAfter);
  const mx = avg(xs); const my = avg(ys);
  const cov = avg(xs.map((x, i) => (x - mx) * (ys[i] - my)));
  const sx = Math.sqrt(avg(xs.map((x) => (x - mx) ** 2))); const sy = Math.sqrt(avg(ys.map((y) => (y - my) ** 2)));
  console.log(`\nconfidence vs measured fidelity: Pearson r = ${(cov / (sx * sy)).toFixed(2)} over ${pairs.length} recoveries`);
}
const bad = results.filter((r) => r.crash || r.error);
if (bad.length) { console.log('\ncrashes / errors:'); bad.slice(0, 10).forEach((r) => console.log(' ', r.file, r.crash || JSON.stringify(r.error))); }
if (write) {
  fs.mkdirSync(path.join(here, 'results'), { recursive: true });
  fs.writeFileSync(path.join(here, 'results', outName), JSON.stringify({ generatedAt: new Date().toISOString(), sandbox, results }, null, 1));
  console.log(`\nwrote tests/results/${outName}`);
}
