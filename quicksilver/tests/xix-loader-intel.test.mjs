// Loader Intelligence end to end on tests/corpus/remote-loaders (tools/loaders/build-fixtures.mjs): every case reaches the expected outcome
// at every stage, through the real api/fetch.js and api/retrieve.js handlers in front of a mock service.
import test from 'node:test';
import assert from 'node:assert/strict';
import { manifest, runCase } from '../tools/loaders/harness.mjs';
import { intelMarkdown } from '../src/loader/intel.js';

const cases = manifest().cases;

test('the fixture set covers every category Prompt XIX §IX lists', () => {
  const cats = new Set(cases.map((c) => c.category));
  for (const c of ['direct source', 'public endpoint, obfuscated', 'authorised authenticated retrieval', 'multi-stage', 'encoded response', 'invalid endpoint', 'authentication failure', 'unavailable service', 'malformed response', 'retrieved but unrecoverable']) assert.ok(cats.has(c), c);
});

for (const c of cases) {
  test(`loader case ${c.id}: ${c.expect.join(' → ')}`, { timeout: 120_000 }, async () => {
    const { report } = await runCase(c, { sandbox: true });
    assert.deepEqual(report.stages.map((s) => s.outcome), c.expect);
    // stages are measured on their own: a transport success is not a payload, a payload is not a reconstruction
    for (const s of report.stages) {
      if (s.outcome === 'not-code') assert.equal(s.transport.ok, true);
      if (s.outcome === 'retrieved-unrecoverable') assert.ok(s.programs.some((p) => p.reconstruction && !['high', 'medium'].includes(p.reconstruction.level)));
      if (s.outcome === 'not-retrievable') assert.equal(s.transport, undefined, 'nothing is requested without an authorised route');
    }
    const md = intelMarkdown(report, { name: c.id });
    assert.ok(!md.includes('SECRET123') && !md.includes('ABCDEFGHIJ1234567890'), 'no secret in the report');
  });
}
