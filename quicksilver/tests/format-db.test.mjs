// The living research database (data/research/format-db.json) is derived, not typed: it must be exactly what tools/formats/build-db.mjs gives from the measured results, the fixture
// manifests and the notes; nothing it says may be a claim the measurements do not back; and every improvement it lists must point at files and tests that exist.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDb } from '../tools/formats/build-db.mjs';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const committed = JSON.parse(fs.readFileSync(path.join(root, 'data/research/format-db.json'), 'utf8'));
const notes = JSON.parse(fs.readFileSync(path.join(root, 'data/research/format-notes.json'), 'utf8'));
const scorecard = JSON.parse(fs.readFileSync(path.join(root, 'tests/results/scorecard.json'), 'utf8'));

test('format-db: the committed file is exactly what the inputs give (no hand-edited number, no stale result)', () => {
  assert.deepEqual(committed, JSON.parse(JSON.stringify(buildDb())));
});

test('format-db: a configuration is `verified` only when fidelity is at least 85% and the recovered script behaved like the original on every run that could be checked', () => {
  for (const p of committed.projects) {
    for (const v of p.versions) {
      for (const c of v.configs) {
        if (c.status === 'verified') {
          assert.ok(c.fidelityAfter >= 0.85, `${p.id} ${v.version} ${c.config}: fidelity ${c.fidelityAfter}`);
          assert.ok(c.behaviourChecked > 0 && c.behaviourSame === c.behaviourChecked, `${p.id} ${v.version} ${c.config}: behaviour ${c.behaviourSame}/${c.behaviourChecked}`);
        }
        if (c.fidelityAfter !== null && c.fidelityAfter < 0.3) assert.equal(c.status, 'unsupported', `${p.id} ${v.version} ${c.config} is below 30% and cannot be called anything but unsupported`);
      }
    }
  }
});

test('format-db: a project with no recovery measurement is identification-only, and one with only VM builds claims nothing', () => {
  for (const p of committed.projects) {
    if (!p.versions.length) assert.equal(p.support, 'identification-only', p.id);
    if (p.support === 'verified') assert.ok(p.versions.every((v) => v.configs.every((c) => c.status === 'verified')), `${p.id}: verified means every configuration`);
  }
  // the per-build VM families of this phase are never called verified
  for (const id of ['zartha', 'fusgato']) {
    const p = committed.projects.find((x) => x.id === id);
    if (p) assert.notEqual(p.support, 'verified', id);
  }
});

test('format-db: every improvement names files and tests that exist; every failure pattern has a status and a summary', () => {
  for (const [id, n] of Object.entries(notes.projects)) {
    for (const imp of n.improvements || []) {
      assert.ok(imp.id && imp.summary, `${id}: improvement needs an id and a summary`);
      for (const f of imp.files || []) assert.ok(fs.existsSync(path.join(root, f)), `${id}/${imp.id}: file ${f} does not exist`);
      assert.ok((imp.tests || []).length > 0, `${id}/${imp.id}: names no test`);
      for (const t of imp.tests || []) assert.ok(fs.existsSync(path.join(root, t.split(':')[0].trim())), `${id}/${imp.id}: test file ${t} does not exist`);
    }
    for (const fp of n.failurePatterns || []) assert.ok(fp.id && fp.status && fp.summary, `${id}: failure pattern needs id, status and summary`);
  }
});

test('format-db: the tools of this phase are all in it, with the revision that was run and where the fixtures are kept', () => {
  for (const id of ['obscura', 'xfuscator', 'luaxen', 'zartha', 'fusgato', 'realobfuscator', 'zynaa']) {
    const p = committed.projects.find((x) => x.id === id);
    assert.ok(p, `${id} is in the database`);
    assert.ok(p.versions.length > 0, `${id} has measured versions`);
    for (const v of p.versions) {
      assert.ok(v.revision, `${id} ${v.version}: the revision that was run is recorded`);
      assert.ok(v.fixtureDir, `${id} ${v.version}: fixture folder recorded`);
      assert.equal(v.committed, v.fixtureDir.includes('/obfuscated/'), `${id} ${v.version}: committed matches the folder`);
    }
  }
  // fixtures that the licence does not allow in the repository are not in it
  for (const id of ['xfuscator', 'realobfuscator', 'zynaa']) assert.ok(committed.projects.find((x) => x.id === id).versions.every((v) => v.committed === false), id);
});

test('format-db: the backlog the prompt named is still there and says what became of each item', () => {
  const ids = committed.backlog.map((b) => b.id);
  for (const id of ['ix-unknown-collection', 'ix-numeric-array-loader', 'ix-nested-flattened', 'ix-luraph-no-banner', 'ix-vm-families']) assert.ok(ids.includes(id), id);
  for (const b of committed.backlog) assert.ok(b.state && b.detail, b.id);
});

test('format-db: the public-collection block counts every file and shows a class for what no rule recognised', () => {
  const c = committed.collection;
  assert.ok(c && c.files > 700);
  for (const f of c.folders) {
    if (f.unidentified) {
      const classified = Object.values(f.classOfUnidentified || {}).reduce((a, b) => a + b, 0);
      assert.equal(classified, f.unidentified, `${f.label}: every unidentified file has a class`);
      assert.ok(!('unclassified' in (f.classOfUnidentified || {})) || f.label === 'Prometheus', `${f.label}: no file is left unclassified`);
    }
  }
  assert.ok(scorecard.results.length > 1000);
});
