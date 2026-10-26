// Real Prometheus output (levno-710/Prometheus, run unmodified on Lua 5.1 by tests/corpus/tools/gen_prometheus.py) of a program whose functions
// leave nested loops early. Vmify turns each loop into blocks whose ways out lead back into the enclosing loop, which the structurer used to
// refuse ("a loop with 2 unrelated exits", "block ... would be emitted twice") and which then left the VM in place with the tamper check
// still running.
//
// Each configuration is recovered with the sandbox on and the result is run on real Lua: it must print what the original prints.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { recover } from '../src/recover/pipeline.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const dir = path.join(here, 'corpus/obfuscated/prometheus-nested');
const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';
after(() => oracle.stopOracle());

const read = (f) => fs.readFileSync(path.join(dir, f), 'latin1');
const original = read('original.lua');
const lines = (s) => s.split('\n').length;

for (const seed of [1337, 101, 77]) {
  test(`Prometheus Medium, seed ${seed}: the VM is taken apart and the program behaves as before`, { skip }, async () => {
    const want = await oracle.runLua(original, 'lua51');
    assert.ok(want.ok, want.error);
    const tool = read(`seed-${seed}/n01_nested_loops__Medium.lua`);
    const made = await oracle.runLua(tool, 'lua51');
    assert.ok(made.ok && made.stdout === want.stdout, 'the tool itself kept the behaviour');

    const r = recover(tool, { sandbox: { enabled: true } });
    assert.equal(r.ok, true);
    const vm = r.steps.find((s) => s.id === 'prometheus.vmify');
    assert.equal(vm && vm.status, 'applied', vm && String(vm.detail));
    const back = await oracle.runLua(r.output, 'lua51');
    assert.ok(back.ok, `${back.error}\n${r.output.slice(0, 400)}`);
    assert.equal(back.stdout, want.stdout);
    assert.equal(r.confidence.level, 'high', JSON.stringify(r.confidence.reasons));
    assert.equal(r.adaptive.score.after, 0);
    assert.ok(lines(r.output) < 200, `${lines(r.output)} lines for a program of ${lines(original)}`);
    assert.doesNotMatch(r.output, /Tamper Detected/);
    assert.doesNotMatch(r.output, /while true do\s+if \w+ (<|>) \d{5,}/, 'no dispatcher tree is left');
  });
}

test('Prometheus Strong (two VM layers), seed 1337: not fully recovered, but what comes out still behaves as the original', { skip }, async () => {
  const want = await oracle.runLua(original, 'lua51');
  const r = recover(read('seed-1337/n01_nested_loops__Strong.lua'), { sandbox: { enabled: true } });
  assert.equal(r.ok, true);
  const back = await oracle.runLua(r.output, 'lua51');
  assert.ok(back.ok, back.error);
  assert.equal(back.stdout, want.stdout);
  // the second layer is not read: the report must say so instead of claiming a recovery
  assert.notEqual(r.confidence.level, 'high');
});
