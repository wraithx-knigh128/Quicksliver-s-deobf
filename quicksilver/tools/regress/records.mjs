// Per-fixture regression records (Prompt XXX). One record per fixture of the committed corpus (tests/corpus/obfuscated/*/manifest.json):
// what was detected, which engine produced the result, which stages applied / were skipped / failed, how many functions were
// reconstructed and how many places are unresolved, the result facets (src/validate/outcome.js: syntax-valid, structurally or only
// partially reconstructed, behaviourally verified or not), the outcome class and the limitations it states.
//
//   node tools/regress/records.mjs [--sets prometheus,zartha] [--shard k/n] [--check]
//
// The recovery is the site's own path (recoverSource with NEXUS, no server engine); the behaviour comparison runs the output next to the
// fixture's original, or next to the protected script where the manifest records that the protected build itself behaves differently
// (an obfuscator's own miscompile). Fuel-limited, so a record is the same on every machine. Records go to data/regression/records.json;
// with --check nothing is written and the exit status is 1 when any present fixture no longer reproduces its record (the differences are
// printed). With --shard the records of one shard are written to records.<k>.json, and a run without --shard and without --sets merges
// the shard files that exist before measuring what is still missing.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { recoverSource, outcomeWithBehaviour } from '../../src/api.js';
import { verifyRecovery } from '../../src/adaptive/verify.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const corpus = path.join(root, 'tests/corpus');
const outPath = path.join(root, 'data/regression/records.json');
const arg = (k) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : null; };
const check = process.argv.includes('--check');
const sets = arg('--sets') ? arg('--sets').split(',') : null;
const shard = arg('--shard') ? arg('--shard').split('/').map(Number) : null;
const LIMITS = { fuel: 40_000_000, timeMs: 120_000 };

export function fixtures() {
  const list = [];
  const dir = path.join(corpus, 'obfuscated');
  for (const set of fs.readdirSync(dir).sort()) {
    const m = path.join(dir, set, 'manifest.json');
    if (!fs.existsSync(m)) continue;
    for (const e of JSON.parse(fs.readFileSync(m, 'utf8')).entries || []) {
      if (e.status !== 'ok' || !e.file || !fs.existsSync(path.join(dir, set, e.file))) continue;
      list.push({ id: `${set}/${e.file}`, set, file: path.join(dir, set, e.file), sample: e.sample ? path.join(corpus, 'originals', e.sample) : null, diverged: !!e.behavior && e.behavior !== 'equivalent', config: e.config || null });
    }
  }
  return list;
}

export function measure(fx) {
  const input = fs.readFileSync(fx.file, 'latin1');
  const r = recoverSource(input, { nexus: true });
  const fam = r.detection ? (r.detection.families || []).filter((f) => f.confidence >= 0.5).sort((a, b) => b.confidence - a.confidence)[0] : null;
  const steps = r.steps || [];
  const vm = r.vm && r.vm.stats && typeof r.vm.stats.undecompiled === 'number' ? r.vm.stats : null;
  const original = fx.sample && fs.existsSync(fx.sample) ? fs.readFileSync(fx.sample, 'latin1') : null;
  const ref = original && !fx.diverged ? original : input;
  let behaviour = null;
  if (r.output != null) {
    const v = verifyRecovery(ref, r.output, LIMITS);
    behaviour = { verdict: v.verdict, against: ref === input ? 'input' : 'original', coverage: v.coverage ? v.coverage.ratio : null, note: v.difference ? `${v.difference.original} / ${v.difference.recovered}`.slice(0, 160) : undefined };
  }
  const o = r.outcome && r.outcome.evidence ? outcomeWithBehaviour(input, { evidence: r.outcome.evidence, behaviour }) : r.outcome;
  const fv = (k) => (o && o.facets && o.facets[k] ? o.facets[k].value : null);
  return {
    id: fx.id,
    sha256: crypto.createHash('sha256').update(Buffer.from(input, 'latin1')).digest('hex').slice(0, 16),
    config: fx.config,
    detected: fam ? { family: fam.id, version: fam.version || null, confidence: Math.round(fam.confidence * 100) / 100 } : null,
    engine: 'quicksilver',
    stages: { applied: steps.filter((s) => s.status === 'applied').map((s) => s.id), skipped: steps.filter((s) => s.status === 'skipped').length, failed: steps.filter((s) => s.status === 'failed' || s.status === 'partial').map((s) => s.id) },
    functions: vm ? { total: vm.functions, unreconstructed: vm.undecompiled } : null,
    unresolved: r.outcome && r.outcome.evidence && r.outcome.evidence.recovery ? r.outcome.evidence.recovery.unresolved || 0 : null,
    syntaxValid: fv('syntaxValid'),
    structural: fv('structural'),
    partial: fv('partial'),
    behavioural: fv('behavioural'),
    unverified: fv('unverified'),
    against: behaviour ? behaviour.against : null,
    category: o ? o.outcome : null,
    limitations: o && o.reasons ? o.reasons.slice(0, 3).map((x) => String(x).slice(0, 200)) : [],
  };
}

function summary(records) {
  const by = (k) => records.reduce((m, r) => { const v = String(r[k]); m[v] = (m[v] || 0) + 1; return m; }, {});
  return { fixtures: records.length, category: by('category'), structural: by('structural'), behavioural: by('behavioural'), unverified: by('unverified') };
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  let list = fixtures();
  if (sets) list = list.filter((f) => sets.includes(f.set));
  if (shard) list = list.filter((_, i) => i % shard[1] === shard[0]);
  const previous = fs.existsSync(outPath) ? new Map(JSON.parse(fs.readFileSync(outPath, 'utf8')).records.map((r) => [r.id, r])) : new Map();
  const fromShards = new Map();
  if (!shard && !sets && !check) {
    for (const f of fs.readdirSync(path.dirname(outPath))) if (/^records\.\d+\.json$/.test(f)) for (const r of JSON.parse(fs.readFileSync(path.join(path.dirname(outPath), f), 'utf8')).records) fromShards.set(r.id, r);
  }
  const out = [];
  let drift = 0;
  const t0 = Date.now();
  for (const fx of list) {
    const rec = fromShards.get(fx.id) || measure(fx);
    if (check) {
      const was = previous.get(fx.id);
      if (!was) { drift++; console.error(`${fx.id}: no committed record`); continue; }
      if (was.sha256 !== rec.sha256) { console.error(`${fx.id}: the fixture changed; not compared`); continue; }
      const diff = Object.keys(rec).filter((k) => JSON.stringify(rec[k]) !== JSON.stringify(was[k]));
      if (diff.length) { drift++; console.error(`${fx.id}: ${diff.map((k) => `${k} ${JSON.stringify(was[k])} -> ${JSON.stringify(rec[k])}`).join('; ')}`); }
    }
    out.push(rec);
  }
  if (check) { console.log(`${list.length} fixture(s) checked in ${Math.round((Date.now() - t0) / 1000)} s; ${drift} differ from their record`); process.exit(drift ? 1 : 0); }
  const file = shard ? outPath.replace(/\.json$/, `.${shard[0]}.json`) : outPath;
  // a partial run (--sets) keeps the other records as they were
  const merged = sets && !shard ? [...[...previous.values()].filter((r) => !out.some((x) => x.id === r.id)), ...out].sort((a, b) => a.id.localeCompare(b.id)) : out;
  fs.writeFileSync(file, `${JSON.stringify({ generatedBy: 'tools/regress/records.mjs', engine: 'src/api.js recoverSource (NEXUS), src/adaptive/verify.js', limits: LIMITS, summary: summary(merged), records: merged }, null, 1)}\n`);
  console.log(`${out.length} record(s) written to ${path.relative(root, file)} in ${Math.round((Date.now() - t0) / 1000)} s`, JSON.stringify(summary(merged)));
}
