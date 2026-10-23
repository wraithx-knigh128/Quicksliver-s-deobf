// How well does the behavioural trace reproduce what a script does, even when the code is unreadable?
//
//   node tests/trace-scorecard.mjs [--write]
//
// For every real-tool fixture, the trace of the obfuscated script is compared with the trace of the original
// program it was made from. "Identical" means the same ordered list of API calls, property writes and prints.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { traceScript } from '../src/trace/trace.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const write = process.argv.includes('--write');
const read = (p) => bytesToBinary(fs.readFileSync(p));
// chunks loaded on the way are how a wrapper starts the program, not something the program does
const key = (r) => r.events.filter((e) => e.kind !== 'load').map((e) => `${e.kind}:${e.text}`).join('\n');

const baseline = new Map();
for (const f of fs.readdirSync(path.join(corpus, 'originals')).filter((x) => x.endsWith('.lua'))) {
  baseline.set(f, traceScript(read(path.join(corpus, 'originals', f)), {}));
}

const results = [];
for (const tool of ['prometheus', 'hercules']) {
  const manifest = JSON.parse(fs.readFileSync(path.join(corpus, 'obfuscated', tool, 'manifest.json'), 'utf8'));
  for (const e of manifest.entries) {
    if (e.status !== 'ok') continue;
    const base = baseline.get(e.sample);
    const t0 = Date.now();
    let r;
    try { r = traceScript(read(path.join(corpus, 'obfuscated', tool, e.file)), {}); } catch (err) { results.push({ tool, config: e.config, sample: e.sample, outcome: 'crash', error: String(err.message).slice(0, 120) }); continue; }
    const same = key(r) === key(base);
    results.push({
      tool, config: e.config, sample: e.sample.replace(/\.lua$/, ''), toolBehavior: e.behavior,
      outcome: same ? 'identical' : r.status === 'completed' ? 'differs' : r.status,
      events: r.stats.events, expected: base.stats.events, ms: Date.now() - t0,
      detail: same ? null : (r.error || r.ended || '').slice(0, 140),
    });
  }
}

const groups = new Map();
for (const r of results) { const k = `${r.tool}/${r.config}`; if (!groups.has(k)) groups.set(k, []); groups.get(k).push(r); }
console.log('config'.padEnd(40), 'identical  (tool-broken excluded)');
let total = 0; let same = 0;
for (const [k, rs] of groups) {
  const usable = rs.filter((r) => r.toolBehavior === 'equivalent');
  const ok = usable.filter((r) => r.outcome === 'identical').length;
  total += usable.length; same += ok;
  console.log(k.padEnd(40), `${ok}/${usable.length}`, rs.length !== usable.length ? `  (${rs.length - usable.length} tool-broken)` : '');
}
console.log(`\ntotal: ${same}/${total} identical traces on fixtures where the obfuscator's own output is equivalent`);
for (const r of results.filter((x) => x.toolBehavior === 'equivalent' && x.outcome !== 'identical').slice(0, 12)) console.log(' ', r.tool, r.config, r.sample, r.outcome, r.detail || '');

if (write) {
  fs.mkdirSync(path.join(here, 'results'), { recursive: true });
  fs.writeFileSync(path.join(here, 'results', 'trace.json'), JSON.stringify({ generatedAt: new Date().toISOString(), results }, null, 1));
  console.log('\nwrote tests/results/trace.json');
}
