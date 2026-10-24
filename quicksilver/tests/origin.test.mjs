// The origin check: every signal fires on what it is meant to and stays quiet otherwise. The fixtures in
// tests/corpus/origin are constructed examples (see the README there); these tests check the mechanism and say nothing
// about accuracy on real authors' code, which has not been measured.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { originAnalysis, mergeOnline } from '../src/origin/index.js';
import { significantLines, pickFingerprints, queryFor, hashLine, normalizeLine, coverage } from '../src/origin/lines.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (rel) => fs.readFileSync(path.join(here, rel)).toString('latin1');
const fixture = (name) => read(`corpus/origin/${name}`);
const signal = (a, id) => a.ai.signals.find((s) => s.id === id);

test('an assistant-style module fires the assistant signals and scores high', () => {
  const a = originAnalysis(fixture('assistant_inventory.lua'));
  assert.equal(a.assessable, true);
  for (const id of ['comment-density', 'doc-annotations', 'header-block', 'descriptive-names', 'defensive-code', 'module-template', 'emoji', 'tidy-english', 'example-usage', 'prefixed-logging']) {
    const s = signal(a, id);
    assert.ok(s, `${id} was not measured`);
    assert.ok(s.strength > 0, `${id} should point towards AI-written`);
  }
  assert.ok(a.ai.score >= 0.8, `score ${a.ai.score}`);
  assert.match(a.ai.label, /AI/);
});

test('scrappy hand-written scripts score low and show the signs of editing by hand', () => {
  for (const f of ['scrappy_esp.lua', 'scrappy_autofarm.lua']) {
    const a = originAnalysis(fixture(f));
    assert.equal(a.assessable, true, f);
    assert.ok(a.ai.score <= 0.4, `${f}: ${a.ai.score}`);
  }
  const esp = originAnalysis(fixture('scrappy_esp.lua'));
  const noise = signal(esp, 'human-noise');
  assert.ok(noise && noise.strength < 0);
  assert.match(noise.value, /commented-out/);
  assert.match(noise.value, /debug print/);
});

test('credits, invites, libraries and a change of style are hints of other authors', () => {
  const a = originAnalysis(fixture('patchwork_credited.lua'));
  const ids = a.skid.signals.map((s) => s.id);
  assert.ok(ids.includes('provenance'));
  assert.ok(ids.includes('libraries'));
  assert.ok(ids.includes('patchwork'));
  assert.deepEqual(a.skid.libraries, ['Rayfield']);
  assert.ok(a.skid.markers.some((m) => m.kind === 'invite' && /abcd1234/.test(m.text)));
  assert.ok(a.skid.markers.some((m) => m.kind === 'credit'));
  assert.ok(a.skid.hint > 0.3);
  // none of it is about AI
  assert.ok(a.ai.score < 0.4);
  // a plain script has none of these hints
  assert.equal(originAnalysis(fixture('scrappy_autofarm.lua')).skid.signals.length, 0);
});

test('obfuscated or minified text is not assessed', () => {
  for (const f of ['obfuscated/prometheus/s06_combined__Minify.lua', 'obfuscated/prometheus/s06_combined__Weak.lua']) {
    const a = originAnalysis(read(`corpus/${f}`));
    assert.equal(a.assessable, false, f);
    assert.equal(a.ai, null);
    assert.match(a.reason, /minified|obfuscated|machine/);
  }
  assert.equal(originAnalysis('').assessable, false);
});

test('short scripts are flagged as low confidence and never reach the extremes', () => {
  const a = originAnalysis('local x = 1\nprint(x)\n');
  assert.equal(a.confidence, 'low');
  if (a.assessable) assert.ok(a.ai.score > 0.1 && a.ai.score < 0.9);
});

test('the score never leaves its band', () => {
  for (const f of fs.readdirSync(path.join(here, 'corpus/originals'))) {
    const a = originAnalysis(read(`corpus/originals/${f}`));
    if (a.assessable) assert.ok(a.ai.score >= 0.04 && a.ai.score <= 0.92, f);
  }
});

// ---- lines ------------------------------------------------------------------------------------------------------------------

test('significant lines leave out the boilerplate every script has', () => {
  const src = [
    'local Players = game:GetService("Players")',
    'local RunService = game:GetService("RunService")',
    'if not game:IsLoaded() then game.Loaded:Wait() end',
    'local config = {}',
    'end',
    'local damageMultiplier = baseDamage * criticalHitModifier + bonus',
    '-- compute the final damage after armour and resistances are applied',
    'return result',
  ].join('\n');
  const lines = significantLines(src).map((l) => l.text);
  assert.deepEqual(lines, ['local damageMultiplier = baseDamage * criticalHitModifier + bonus', '-- compute the final damage after armour and resistances are applied']);
});

test('fingerprints are spread over the file and prefer strings and comments', () => {
  const rows = [];
  for (let i = 0; i < 80; i++) rows.push(i % 10 === 0 ? `local message${i} = "this is a distinctive message number ${i}"` : `local value${i} = ${i} + offset${i}`);
  const lines = significantLines(rows.join('\n'));
  const picks = pickFingerprints(lines, 8);
  assert.equal(picks.length, 8);
  const positions = picks.map((p) => p.line);
  assert.ok(positions[positions.length - 1] - positions[0] > 50, 'spread over the file');
  assert.ok(picks.filter((p) => p.text.includes('distinctive message')).length >= 5);
  assert.equal(queryFor('local x = "hello there, this is a message" .. y'), 'hello there, this is a message');
  assert.equal(queryFor('-- compute the final damage after armour'), 'compute the final damage after armour');
  assert.ok(queryFor('local a = "' + 'x'.repeat(300) + '"').length <= 140);
});

test('coverage counts the share of significant lines a candidate file also has', () => {
  const mine = significantLines(['local firstDistinctiveLine = computeSomethingUseful(argumentOne)', 'local secondDistinctiveLine = computeSomethingElse(argumentTwo)', 'local thirdDistinctiveLine = andOneMoreThing(argumentThree)'].join('\n'));
  const theirs = ['  local firstDistinctiveLine   =   computeSomethingUseful(argumentOne)', 'local thirdDistinctiveLine = andOneMoreThing(argumentThree)', 'unrelated'].map((l) => hashLine(normalizeLine(l)));
  const c = coverage(mine, theirs);
  assert.equal(c.matched, 2);
  assert.equal(c.total, 3);
  assert.ok(Math.abs(c.share - 2 / 3) < 1e-9);
});

test('merging an online result gives the verdict from the best file', () => {
  const src = ['local firstDistinctiveLine = computeSomethingUseful(argumentOne)', 'local secondDistinctiveLine = computeSomethingElse(argumentTwo)', 'local thirdDistinctiveLine = andOneMoreThing(argumentThree)', 'local fourthDistinctiveLine = lastThingToCompute(argumentFour)'].join('\n');
  const analysis = originAnalysis(src);
  const hashes = significantLines(src).slice(0, 3).map((l) => hashLine(l.text));
  const m = mergeOnline(analysis, src, { configured: true, provider: 'GitHub code search', queried: 4, matches: [
    { repo: 'a/b', path: 'x.lua', url: 'https://github.com/a/b/blob/main/x.lua', hits: [0], lineHashes: hashes.slice(0, 1) },
    { repo: 'c/d', path: 'y.lua', url: 'https://github.com/c/d/blob/main/y.lua', hits: [0, 1, 2], lineHashes: hashes },
  ] });
  assert.equal(m.searched, true);
  assert.equal(m.matches[0].repo, 'c/d');
  assert.equal(m.share, 0.75);
  assert.equal(m.label, 'Almost certainly copied from a public file');
  assert.equal(mergeOnline(analysis, src, { configured: false, note: 'off' }).searched, false);
  assert.equal(mergeOnline(analysis, src, { configured: true, queried: 4, matches: [] }).label, 'No match found');
});
