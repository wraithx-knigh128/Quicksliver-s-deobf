// Prompt XXX: the per-fixture regression records (data/regression/records.json, tools/regress/records.mjs). The first fixture of every
// corpus set is measured again and must match its committed record field for field: detection, engine, stages, functions, unresolved
// places, the facets, the class and its limitations. A change that alters any of them must regenerate the records and say why.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { fixtures, measure } from '../tools/regress/records.mjs';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const recordsPath = path.join(root, 'data/regression/records.json');
const committed = fs.existsSync(recordsPath) ? JSON.parse(fs.readFileSync(recordsPath, 'utf8')) : null;

test('records: one record per fixture of the corpus, each with every field', () => {
  assert.ok(committed, 'data/regression/records.json is committed');
  const ids = new Set(committed.records.map((r) => r.id));
  const all = fixtures();
  assert.deepEqual(all.filter((f) => !ids.has(f.id)).map((f) => f.id), [], 'every fixture has a record');
  for (const r of committed.records) {
    for (const k of ['id', 'sha256', 'detected', 'engine', 'stages', 'functions', 'unresolved', 'syntaxValid', 'structural', 'partial', 'behavioural', 'unverified', 'category', 'limitations']) assert.ok(k in r, `${r.id}: ${k}`);
    // no class claims more than its facets: validated needs a behaviour verification and a structural reconstruction
    if (r.category === 'validated') assert.ok(r.behavioural === true && r.structural === true, `${r.id}: validated without its facets`);
    if (r.behavioural === true) assert.equal(r.unverified, false, r.id);
  }
});

test('records: the first fixture of every set still reproduces its record', { timeout: 600_000 }, () => {
  const byId = new Map(committed.records.map((r) => [r.id, r]));
  const seen = new Set();
  const sample = fixtures().filter((f) => (seen.has(f.set) ? false : (seen.add(f.set), true)));
  const drift = [];
  for (const fx of sample) {
    const now = measure(fx);
    const was = byId.get(fx.id);
    if (!was || was.sha256 !== now.sha256) { drift.push(`${fx.id}: no comparable record`); continue; }
    for (const k of Object.keys(now)) if (JSON.stringify(now[k]) !== JSON.stringify(was[k])) drift.push(`${fx.id} ${k}: ${JSON.stringify(was[k])} -> ${JSON.stringify(now[k])}`);
  }
  assert.deepEqual(drift, []);
});
