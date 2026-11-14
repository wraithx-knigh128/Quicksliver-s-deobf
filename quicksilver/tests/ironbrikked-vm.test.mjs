// Prompt XII/XIII/XIV: LuaXen's IronBrikked VM is read back to source. The container (compressed bytes, then constants / instructions / nested functions) and the interpreter's
// handlers (an opcode tree evaluated per opcode) are read from the script. What is NOT claimed: runtime equivalence, and Prompt XIV found why it cannot be had from the file.
// LuaXen's compiler (InstructionGenerator.lua) allocates temporaries over registers that still hold live values (parameters are kept in `takenRegisters`, the allocator
// looks at `registers`), so the compiled program is not the source program; it stores the parameter count under a misspelt key (`numParmas`), so every function is
// written with 0 parameters and the template's CLOSURE takes that 0 as its upvalue count; and it writes RETURN's B as an absolute register. The last two are read back
// here; the first is a different program. Controlled programs without parameters fail the same way. The audit status is partial: structure and semantic gains are measured.

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
    assert.ok(r.report.unresolved.some((u) => /generator compiled it/.test(u.text) && /temporaries over registers/.test(u.text)), f);
  }
});

test('ironbrikked: RETURN counts are read as LuaXen\'s compiler writes them (first register + count + 1), so `return value` gives one value, not the registers after it', () => {
  // the compiler: RETURN expressionRegisters[1], (expressionRegisters[1] + #expressionRegisters) + 1; Lua's B is count + 1
  const r = recover(read(path.join(dir, 's01_minify_basic__ironbrikked.lua')), { sandbox: { enabled: true } });
  const body = r.output.split('(end of report)').pop();
  const clamp = body.slice(0, body.indexOf('\nend\n') + 5);
  assert.match(clamp, /return param1\n/);
  assert.doesNotMatch(clamp, /return \w+, \w+/, 'no register after the returned one is returned with it');
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
