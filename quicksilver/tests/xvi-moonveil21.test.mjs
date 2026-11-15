// MoonVeil 2.1.0: the program rebuilt from what its handlers do with each instruction (src/recover/moonveil-vm/lift21.js).
//
// The two samples are third-party scripts that are not stored in the repository (local/moonveil, git-ignored); the tests that need them skip without
// them. What they check: the program is rebuilt (no interpreter, no container left), the rebuilt script runs in the sandbox like the original, and
// the checks the program makes are really in the rebuilt code (changing the value they compare against makes it fail, as it makes the original's
// logic fail). The independent reconstruction of these two samples (github.com/Nonition/MoonveilDeobfuscator, MIT, made by hand) has the same
// structure: two functions that collect a closure per `ipairs` index and sum their results with `pairs`, each checked against 15.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { parse } from '../src/core/parser.js';
import { recover } from '../src/recover/pipeline.js';
import { runSource } from '../src/sandbox/sandbox.js';
import { cellValueSlot } from '../src/recover/moonveil-vm/lift21.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const sample = (n) => path.join(here, '..', 'local', 'moonveil', `v2.1.0_sample${n}.lua`);
const run = (src) => runSource(`local __r = {(function(...)\n${src}\nend)()}\nprint("returned", #__r)`, { dialect: 'luau', fuel: 20_000_000, timeMs: 8000 });

for (const [n, functions, handlers] of [[6, 3, 24], [7, 2, 21]]) {
  test(`moonveil 2.1.0 sample ${n}: rebuilt from its handlers, joined with the code around the VM, and it runs like the original`, { skip: !fs.existsSync(sample(n)) && 'local MoonVeil samples are not in the repository' }, () => {
    const src = bytesToBinary(fs.readFileSync(sample(n)));
    const r = recover(src, { sandbox: { enabled: true } });
    const st = r.steps.find((x) => x.id === 'moonveil.vm21');
    assert.equal(st && st.status, 'applied', st && JSON.stringify(st.detail));
    assert.equal(st.detail.functions, functions);
    assert.equal(st.detail.handlers, handlers);
    assert.equal(st.detail.selfCheck, 'same');
    // no interpreter and no container are left
    const code = r.output.replace(/^--.*\n/gm, '');
    assert.doesNotMatch(code, /"[!-~]{150,}"/, 'the base-85 container is gone');
    assert.doesNotMatch(code, /while true do/, 'the dispatch loop is gone');
    assert.doesNotThrow(() => parse(code));
    // the rebuilt program: closures over each `ipairs` index, summed with `pairs`, checked against 15 (twice)
    assert.match(code, /for \w+ in ipairs\(\{ 1, 2, 3, 4, 5 \}\) do/);
    assert.equal((code.match(/== 15|~= 15/g) || []).length, 2);
    const a = run(src);
    const b = run(code);
    assert.equal(b.ok, a.ok, b.error && String(b.error.message || b.error));
    assert.equal(b.output, a.output);
    // the checks are real: compared against another value, the rebuilt program fails
    const changed = run(code.replace(/([=~]= )15\b/g, '$116'));
    assert.equal(changed.ok, false);
    assert.equal(r.confidence.level, 'high');
  });
}

test('moonveil 2.1.0: without the sandbox the rebuilt program is not compared with the original, and it is not rated high', { skip: !fs.existsSync(sample(6)) && 'local MoonVeil samples are not in the repository' }, () => {
  const r = recover(bytesToBinary(fs.readFileSync(sample(6))), { sandbox: { enabled: false } });
  const st = r.steps.find((x) => x.id === 'moonveil.vm21');
  assert.equal(st && st.status, 'applied');
  assert.equal(st.detail.selfCheck, 'sandbox off');
  assert.notEqual(r.confidence.level, 'high');
});

test('moonveil 2.1.0: the slot a cell keeps its value in is read from the cells themselves (it differs between builds)', () => {
  assert.equal(cellValueSlot(parse('local a = { [1] = 2, [2] = print }\nlocal b = { [1] = 2, [2] = pairs }\nlocal c = { [3] = 1 }')), 2);
  assert.equal(cellValueSlot(parse('local a = { [2] = 1, [1] = print }\nlocal b = { [2] = 1, [1] = pairs }')), 1);
  assert.equal(cellValueSlot(parse('local a = { 1, 2 }')), null);
});
