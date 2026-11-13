// Prompt XII/XIII: LuaXen's IronBrikked VM is read back to source. The container (compressed bytes, then constants / instructions / nested functions) and the interpreter's
// handlers (an opcode tree evaluated per opcode) are read from the script. What is NOT claimed: runtime equivalence. The generator's own output errors on every program tried
// (14 of 14 fixtures), and its compiler writes operand counts the program did not have (results of calls, values of returns, method calls without their object), so the lifted
// program follows the encoded instructions and does not run like the original. The audit status is partial: the structure and semantic gains are measured, the runtime is not judged.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { residualIndicators } from '../src/core/metrics.js';
import { recover } from '../src/recover/pipeline.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const dir = path.join(here, 'corpus', 'obfuscated', 'luaxen');
const read = (p) => bytesToBinary(fs.readFileSync(p));
const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));
const files = manifest.entries.filter((e) => /^(ironbrikked|both)$/.test(e.config) && e.status === 'ok').map((e) => e.file);

test('ironbrikked: every fixture (the VM alone and under the syntax layer) is lifted and structured, and is never called high confidence', () => {
  assert.equal(files.length, 14);
  for (const f of files) {
    const r = recover(read(path.join(dir, f)), { sandbox: { enabled: true } });
    const step = r.steps.find((s) => s.id === 'ironbrikked.vm');
    assert.ok(step && step.status === 'applied', `${f}: ${step && step.detail}`);
    assert.deepEqual(residualIndicators(r.output), [], f);
    assert.notEqual(r.confidence.level, 'high', f);
    assert.ok(r.report.unresolved.some((u) => /generator encoded it/.test(u.text)), f);
  }
});

test('ironbrikked: the tool\'s own output of these programs does not run (the evidence behind the experimental status)', () => {
  const m = manifest.entries.filter((e) => /^(ironbrikked|both)$/.test(e.config));
  assert.ok(m.every((e) => e.behavior === 'errored' || e.behavior === 'skipped'));
});

test('ironbrikked: an opcode no rule recognises is reported with its text', () => {
  const src = read(path.join(dir, 's08_ironbrew_macros__ironbrikked.lua'));
  const broken = src.replace(/v\[y\[2\]\]=\{\}/, 'v[y[2]]={}print(1)');
  assert.notEqual(broken, src);
  const step = recover(broken, {}).steps.find((s) => s.id === 'ironbrikked.vm');
  assert.equal(step.status, 'skipped');
  assert.match(step.detail, /not one this reader recognises/);
});
