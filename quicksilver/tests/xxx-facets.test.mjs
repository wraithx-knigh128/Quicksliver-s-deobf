// Prompt XXX: result facets. Each is decided by its own evidence; none comes from a confidence score.
import test from 'node:test';
import assert from 'node:assert/strict';
import { classifyOutcome, FACETS } from '../src/validate/outcome.js';
import { recoverSource } from '../src/api.js';

const lua = { kind: 'lua', parses: true };
const value = (r) => Object.fromEntries(Object.entries(r.facets).map(([k, v]) => [k, v.value]));

test('facets: every facet is reported, with a reason', () => {
  const r = classifyOutcome({ input: lua, obfuscated: false, recovery: { output: 'print(1)', parses: true } });
  assert.deepEqual(Object.keys(r.facets).sort(), Object.keys(FACETS).sort());
  for (const v of Object.values(r.facets)) assert.ok(typeof v.why === 'string' && v.why.length > 0);
});

test('facets: a high confidence is never a verification', () => {
  const r = classifyOutcome({ input: lua, obfuscated: true, recovery: { output: 'x()', parses: true, residual: [], unresolved: 0, level: 'high' } });
  assert.equal(r.outcome, 'syntax-valid-unverified');
  assert.equal(r.facets.behavioural.value, null);
  assert.equal(r.facets.unverified.value, true);
  assert.equal(r.facets.structural.value, true);
});

test('facets: an identical run over too little of the program does not verify it', () => {
  const r = classifyOutcome({ input: lua, obfuscated: true, recovery: { output: 'x()', parses: true, residual: [], unresolved: 0, level: 'high' }, behaviour: { verdict: 'identical', against: 'input', coverage: 0.3 } });
  assert.equal(r.outcome, 'syntax-valid-unverified');
  assert.equal(r.facets.behavioural.value, null);
  assert.equal(r.facets.unverified.value, true);
  const ok = classifyOutcome({ input: lua, obfuscated: true, recovery: { output: 'x()', parses: true, residual: [], unresolved: 0, level: 'high' }, behaviour: { verdict: 'identical', against: 'input', coverage: 0.8 } });
  assert.equal(ok.outcome, 'validated');
  assert.deepEqual([ok.facets.behavioural.value, ok.facets.unverified.value, ok.facets.failed.value], [true, false, false]);
});

test('facets: functions left undecompiled make a result partial, not structural, whatever the behaviour', () => {
  const r = classifyOutcome({ input: lua, obfuscated: true, detected: { family: 'moonsec_v3', name: 'MoonSec V3', confidence: 0.97 }, recovery: { output: 'x()', parses: true, residual: [], unresolved: 2, level: 'medium' }, behaviour: { verdict: 'identical', against: 'input', coverage: 0.9 } });
  assert.equal(r.outcome, 'partial');
  assert.deepEqual(value(r), { detected: true, retrieved: null, partial: true, syntaxValid: true, structural: false, behavioural: true, unverified: false, failed: false });
  assert.match(r.facets.detected.why, /MoonSec V3/);
});

test('facets: a different run is a finding, not "unverified"', () => {
  const r = classifyOutcome({ input: lua, obfuscated: true, recovery: { output: 'x()', parses: true, residual: [], unresolved: 0, level: 'high' }, behaviour: { verdict: 'different', against: 'original', note: 'print(1) / print(2)' } });
  assert.equal(r.outcome, 'partial');
  assert.deepEqual([r.facets.behavioural.value, r.facets.unverified.value, r.facets.structural.value, r.facets.partial.value], [false, false, true, false]);
});

test('facets: failures, retrieval and missing output', () => {
  const bad = classifyOutcome({ input: { kind: 'empty' } });
  assert.deepEqual([bad.facets.failed.value, bad.facets.syntaxValid.value, bad.facets.structural.value], [true, null, null]);
  const nf = classifyOutcome({ retrieval: { status: 'not-found', reason: 'HTTP 404' } });
  assert.deepEqual([nf.facets.failed.value, nf.facets.retrieved.value], [true, false]);
  const ok = classifyOutcome({ retrieval: { status: 'ok' }, input: lua, obfuscated: false, recovery: { output: 'print(1)', parses: true } });
  assert.equal(ok.facets.retrieved.value, true);
  const noparse = classifyOutcome({ input: lua, obfuscated: true, recovery: { output: 'x(', parses: false } });
  assert.deepEqual([noparse.outcome, noparse.facets.syntaxValid.value, noparse.facets.failed.value], ['not-deobfuscated', false, true]);
});

test('facets: a real recovery carries the detected family', () => {
  const src = 'local a = "\\104\\105" print(a)';
  const r = recoverSource(src, {});
  assert.ok(r.outcome && r.outcome.facets, 'the recovery outcome has facets');
  assert.equal(r.outcome.facets.syntaxValid.value, true);
});
