// The Prompt XX evidence collection (tools/custom/collection.mjs → data/research/collection-results.json, docs/COLLECTION.md):
// invariants on the committed results, and a live re-measurement of samples that are cheap to run.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { analyzeCustom } from '../src/custom/analyze.js';
import { detect } from '../src/detect/detect.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const results = JSON.parse(fs.readFileSync(path.join(root, 'data', 'research', 'collection-results.json'), 'utf8'));

test('every category Prompt XX asks for is in the collection', () => {
  const cats = new Set(results.rows.map((r) => r.category));
  for (const c of ['previously supported', 'unknown custom (no signature)', 'multi-layer', 'VM-based', 'locally encoded loader', 'loader with remote reference', 'incomplete / malformed', 'unsupported / partial']) assert.ok(cats.has(c), c);
});

test('no sample is reported as reconstructed on looks alone: behaviour is claimed only where it was run, and low confidence stays low', () => {
  for (const r of results.rows) {
    if (r.behaviour && r.behaviour.vsOriginal === 'same') assert.ok(r.behaviour.runtime, `${r.label}: a behaviour claim names the runtime it was checked on`);
    if (r.label === 'ZenFus VM') { assert.equal(r.confidence, 'minimal', 'the VM is kept: same behaviour does not make it a reconstruction'); assert.ok(r.limitations.length); }
  }
  assert.equal(results.summary.falseClaims, 0, 'no unfamiliar sample was given a wrong tool name');
});

test('live: a signature-less packer is not given a tool name, and its decoder hypothesis is confirmed', () => {
  const src = fs.readFileSync(path.join(root, 'tests', 'corpus', 'obfuscated', 'loaders', 's01_minify_basic__charcodes.lua'), 'latin1');
  assert.deepEqual(detect(src).families.filter((f) => f.confidence >= 0.5), []);
  const r = analyzeCustom(src, { sandbox: { enabled: true } });
  assert.equal(r.result.level, 'high');
  assert.ok(r.anatomy.ok);
});

test('live: a tool hidden under an outer layer is named once the layer is peeled', () => {
  const src = fs.readFileSync(path.join(root, 'tests', 'corpus', 'obfuscated', 'mixed', 's01_minify_basic__hercules-balanced+xor.lua'), 'latin1');
  assert.ok(!detect(src).families.some((f) => f.id === 'hercules' && f.confidence >= 0.5), 'not visible at first');
  assert.ok(analyzeCustom(src, { sandbox: { enabled: true } }).identifiedAfterPeeling.includes('hercules'));
});

test('malformed input is reported, not crashed on', () => {
  const r = analyzeCustom('loadstring(game:HttpGet("https://x.example/a")\n', { sandbox: { enabled: true } });
  assert.equal(r.ok, false);
  assert.equal(r.stage, 'probe');
});
