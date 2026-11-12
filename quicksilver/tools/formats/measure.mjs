// Measure the recovery pipeline on the scripts of closed obfuscators that were read for this project (tools/formats/samples.json) and write
// data/research/format-records.json.
//
//   node tools/formats/measure.mjs [--check]
//
// A record is what recover() did to one script, version by version: what it detected, which passes applied or were skipped (and why), the
// confidence it reported, how many places it left unresolved and, where a hand-made reference exists, how many of the reference's string literals
// are in the output. The scripts are not in the repository; a sample that is not present keeps the numbers of its last measurement and is marked
// `present: false`. With --check nothing is written: it exits 1 when a present sample no longer reproduces its record.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../../src/core/bytes.js';
import { recover } from '../../src/recover/pipeline.js';
import { fidelity } from '../../src/core/fidelity.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const recordsPath = path.join(root, 'data/research/format-records.json');
const samples = JSON.parse(fs.readFileSync(path.join(root, 'tools/formats/samples.json'), 'utf8')).samples;
const check = process.argv.includes('--check');
const previous = fs.existsSync(recordsPath) ? JSON.parse(fs.readFileSync(recordsPath, 'utf8')).records : [];

const literals = (text) => new Set([...text.matchAll(/"((?:[^"\\\n]|\\.){4,})"/g)].map((m) => m[1]));

function measure(s) {
  const file = path.join(root, s.path);
  const bytes = fs.readFileSync(file);
  const src = bytesToBinary(bytes);
  const r = recover(src, { sandbox: { enabled: true } });
  const fam = r.detection.families.find((f) => f.id === s.family);
  const rec = {
    id: s.id, family: s.family, version: s.version, source: s.source, bytes: bytes.length, sha256: crypto.createHash('sha256').update(bytes).digest('hex'), present: true,
    detected: fam ? { confidence: fam.confidence, version: fam.version || null, rules: fam.evidence.map((e) => e.rule) } : null,
    versionMatches: fam ? (fam.version || null) === s.version : false,
    ok: r.ok,
    confidence: r.confidence ? { score: r.confidence.score, level: r.confidence.level } : null,
    steps: r.steps.filter((x) => x.status === 'applied' || x.status === 'skipped' || x.status === 'failed').map((x) => ({ id: x.id, status: x.status, changed: x.changed, ...(x.status === 'skipped' ? { why: String(x.detail).slice(0, 120) } : {}) })),
    unresolved: r.adaptive && r.adaptive.residual ? r.adaptive.residual.length : 0,
    outputBytes: r.output ? r.output.length : 0,
  };
  if (s.reference && fs.existsSync(path.join(root, s.reference))) {
    const ref = bytesToBinary(fs.readFileSync(path.join(root, s.reference)));
    const want = literals(ref);
    const got = literals(r.output || '');
    rec.reference = { literals: want.size, found: [...want].filter((x) => got.has(x)).length, fidelity: Math.round(fidelity(ref, r.output).score * 1000) / 1000 };
  }
  return rec;
}

const out = [];
let drift = 0;
for (const s of samples) {
  const was = previous.find((p) => p.id === s.id);
  if (!fs.existsSync(path.join(root, s.path))) { if (was) out.push({ ...was, present: false }); continue; }
  const rec = measure(s);
  if (was && was.sha256 === rec.sha256) {
    const same = JSON.stringify({ ...was, present: true }) === JSON.stringify(rec);
    if (!same) { drift++; console.error(`${s.id}: the record no longer reproduces`); }
  }
  out.push(rec);
  console.log(`${s.id.padEnd(30)} detected ${rec.detected ? `${rec.detected.confidence} v${rec.detected.version}` : 'no'}  confidence ${rec.confidence && rec.confidence.score}  unresolved ${rec.unresolved}${rec.reference ? `  reference literals ${rec.reference.found}/${rec.reference.literals} fidelity ${rec.reference.fidelity}` : ''}`);
}
if (check) process.exit(drift ? 1 : 0);
fs.writeFileSync(recordsPath, `${JSON.stringify({ generatedAt: new Date().toISOString(), engine: 'src/recover/pipeline.js', records: out }, null, 1)}\n`);
console.log(`wrote ${path.relative(root, recordsPath)}`);
