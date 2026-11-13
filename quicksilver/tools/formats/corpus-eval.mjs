// Measure detection (and, with --recover, recovery) on the sample of the labelled public collection taken by corpus-sample.mjs.
//
//   node tools/formats/corpus-eval.mjs [--recover N] [--write]
//
// The bucket a file was filed under is the collection's own label; it is what the file's uploader believed, so it is evidence, not ground truth: where our verdict
// differs, the file's banner or structure is looked at before anything is called an error. Output: per label, how many files were identified as that family (confidence
// >= 0.5), with the version where the label names one; what the others were taken for; how many files our parser rejects.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../../src/core/bytes.js';
import { parse } from '../../src/core/parser.js';
import { detect } from '../../src/detect/detect.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const index = JSON.parse(fs.readFileSync(path.join(root, 'data/research/corpus-index.json'), 'utf8'));
const write = process.argv.includes('--write');
const FAMILY = { AztupBrew: 'aztupbrew', Boronide: 'boronide', IronBrew1: 'ironbrew1', IronBrew2: 'ironbrew2', LuaObfuscator: 'luaobfuscator', Luraph: 'luraph', MoonSecV2: 'moonsec_v2', MoonSecV3: 'moonsec_v3',
  MoonVeil: 'moonveil', PSU: 'psu', Prometheus: 'prometheus', SynapseXen: 'synapse_xen', wYnFuscate: 'wynfuscate', Base64Payload: 'loaders' };
const rows = [];
const rank = new Map();
const seenSha = new Set();
for (const e of index.index) {
  const r = (rank.get(e.bucket) || 0) + 1; rank.set(e.bucket, r); e.set = r <= 12 ? 'train' : 'holdout';
  const p = path.join(root, 'local/corpus', e.bucket, `${e.sha256.slice(0, 16)}.lua`);
  if (!fs.existsSync(p) || seenSha.has(e.sha256)) continue;      // the collection files some scripts twice (a bucket and its Unknown sub-bucket): once is enough
  seenSha.add(e.sha256);
  const src = bytesToBinary(fs.readFileSync(p));
  const parts = e.bucket.split('/');
  const label = parts[0];
  const ver = parts.find((x, i) => i > 0 && /^v[\d.]/.test(x) && !/^v\d+$/.test(x) || (label !== 'Prometheus' && /^v/.test(x))) || null;
  const row = { sha: e.sha256.slice(0, 12), set: e.set, label, bucket: e.bucket, version: ver ? ver.replace(/^v\.?/, '') : null, bytes: e.bytes };
  let ast = null;
  try { ast = parse(src); row.parsed = true; } catch (err) { row.parsed = false; row.parseError = String(err.message || err).slice(0, 80); }
  try {
    const d = detect(src, ast);
    const top = d.families.filter((f) => f.confidence >= 0.5).sort((a, b) => b.confidence - a.confidence);
    row.top = top.length ? { id: top[0].id, confidence: top[0].confidence, version: top[0].version || null } : null;
    row.all = top.map((f) => `${f.id}:${f.confidence.toFixed(2)}`);
    row.traits = d.traits.map((t) => t.id);
    row.classes = (d.classes || []).map((c) => c.id);
    if (d.vendorBanner) row.vendorBanner = d.vendorBanner;
  } catch (err) { row.detectError = String(err.message || err).slice(0, 80); }
  rows.push(row);
}
if (process.argv.includes('--recover')) {
  const per = Number(process.argv[process.argv.indexOf('--recover') + 1] || 3);
  const { spawnSync } = await import('node:child_process');
  const taken = new Map();
  for (const r of rows) {
    const k = r.label;
    if ((taken.get(k) || 0) >= per || r.bytes > 250000) continue;
    taken.set(k, (taken.get(k) || 0) + 1);
    const file = fs.readdirSync(path.join(root, 'local/corpus', r.bucket)).find((x) => x.startsWith(r.sha));
    const t = spawnSync('node', [path.join(root, 'tools/formats/recover-one.mjs'), path.join(root, 'local/corpus', r.bucket, file)], { encoding: 'utf8', timeout: 90000, maxBuffer: 64 << 20 });
    try { r.recovery = JSON.parse(t.stdout.trim().split('\n').pop()); } catch { r.recovery = { ok: false, crash: t.error ? String(t.error.code || t.error.message) : (t.stderr || 'no output').slice(0, 160) }; }
  }
  const stats = {};
  for (const r of rows.filter((x) => x.recovery)) { const s = (stats[r.label] ||= { n: 0, ok: 0, crash: 0, timeout: 0, conf: [], ms: [] }); s.n++; if (r.recovery.ok) s.ok++; if (r.recovery.crash) { s.crash++; if (/ETIMEDOUT/.test(r.recovery.crash)) s.timeout++; } if (r.recovery.confidence != null) s.conf.push(r.recovery.confidence); s.ms.push(r.recovery.ms || 0); }
  console.log('\nrecovery (sandbox off) per label: n ok crash timeout meanConfidence meanMs');
  for (const [k, s] of Object.entries(stats).sort()) console.log(k.padEnd(16), s.n, s.ok, s.crash, s.timeout, s.conf.length ? (s.conf.reduce((a, b) => a + b, 0) / s.conf.length).toFixed(2) : '-', Math.round(s.ms.reduce((a, b) => a + b, 0) / s.n));
}
const summary = {};
for (const r of rows.filter((x) => (process.argv.includes('--set') ? x.set === process.argv[process.argv.indexOf('--set') + 1] : true))) {
  const s = (summary[r.label] ||= { files: 0, parsed: 0, expected: FAMILY[r.label] === undefined ? 'unlabelled' : FAMILY[r.label], identified: 0, other: {}, versionFiles: 0, versionRight: 0, unidentified: 0, classOfUnidentified: {} });
  s.files++;
  if (r.parsed) s.parsed++;
  if (r.top && s.expected && r.top.id === s.expected) s.identified++;
  else if (r.top) s.other[r.top.id] = (s.other[r.top.id] || 0) + 1;
  else { s.unidentified++; for (const c of (r.classes && r.classes.length ? r.classes.slice(0, 1) : ['unclassified'])) s.classOfUnidentified[c] = (s.classOfUnidentified[c] || 0) + 1; }
  if (r.version && s.expected && r.top && r.top.id === s.expected && r.top.version) { s.versionFiles++; if (String(r.top.version).replace(/^v/, '') === r.version) s.versionRight++; }
}
console.log('label'.padEnd(16), 'files  parsed  expected          identified  unidentified  other families  [version right/checked]');
for (const [k, s] of Object.entries(summary).sort()) console.log(k.padEnd(16), String(s.files).padStart(5), String(s.parsed).padStart(7), String(s.expected).padEnd(17), `${s.identified}`.padStart(10), `${s.unidentified}`.padStart(13), ' ', JSON.stringify(s.other), s.versionFiles ? `[${s.versionRight}/${s.versionFiles}]` : '', s.unidentified ? `unidentified by class: ${JSON.stringify(s.classOfUnidentified)}` : '');
if (process.argv.includes('--check')) {
  const was = JSON.parse(fs.readFileSync(path.join(root, 'data/research/corpus-eval.json'), 'utf8'));
  const same = JSON.stringify(was.summary) === JSON.stringify(summary);
  console.log(same ? 'the committed detection numbers reproduce' : 'the committed detection numbers do NOT reproduce');
  process.exit(same ? 0 : 1);
}
if (write) fs.writeFileSync(path.join(root, 'data/research/corpus-eval.json'), `${JSON.stringify({ generatedAt: new Date().toISOString(), source: index.source, commit: index.commit, files: rows.length, summary, rows }, null, 0)}\n`);
