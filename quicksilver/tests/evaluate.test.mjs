// The decoder-evaluation pass on Prometheus' ConstantArray step: strings live in an encoded array that a loop decodes
// in place, and an accessor function `list[n + 52430]` reads them. Some of its calls sit in `class[decode('__index')] = class`,
// where the lookup has no value yet but the key is still a constant.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { recover } from '../src/recover/pipeline.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const dir = path.join(here, 'corpus/obfuscated/prometheus');
const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';
after(() => oracle.stopOracle());

const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));
const jobs = manifest.entries.filter((e) => e.status === 'ok' && e.config === 'step-ConstantArray');

for (const job of jobs) {
  test(`${job.file}: the constant array is decoded, the decoder removed and the program unchanged`, { skip }, async () => {
    const src = fs.readFileSync(path.join(dir, job.file)).toString('latin1');
    const expected = await oracle.runLua(src, 'lua51');
    assert.ok(expected.ok, expected.error);
    const r = recover(src, { sandbox: { enabled: true } });
    assert.equal(r.ok, true);
    const step = r.steps.find((s) => s.id === 'evaluate');
    assert.ok(step && step.status === 'applied', 'the evaluate step ran');
    assert.ok(!/\w+\[\w+ [+-] \d{4,}\]/.test(r.output), 'the array accessor is left in the output');
    assert.ok(!/\w+\(-\d{4,}\)/.test(r.output), `a decoder call with a constant argument is left:\n${(r.output.match(/.*\w+\(-\d{4,}\).*/) || [''])[0]}`);
    assert.ok(!/\^[!-~]{3,}/.test(r.output), 'an encoded array element is left in the output');
    assert.ok(!/string\.char\(.*math\.floor\(.*65536/.test(r.output), 'the in-place decoder loop is left in the output');
    const got = await oracle.runLua(r.output, 'lua51');
    assert.ok(got.ok, `${got.error}\n${r.output.slice(0, 400)}`);
    assert.equal(got.stdout, expected.stdout);
  });
}

test('a lookup that cannot be evaluated as a whole still gets its constant key', () => {
  const lines = [
    'local t = {"ab", "cd", "ef", "gh", "ij"}',
    'local function d(n) return t[n + 100] end',
    'local C = {}',
    'C[d(-99)] = 1',
    'C[d(-98)] = 2',
    'C[d(-97)] = 3',
    'C[d(-96)] = 4',
    'print(C.ab, C.cd, C.ef, C.gh)',
  ];
  const r = recover(lines.join('\n'), { sandbox: { enabled: true } });
  assert.match(r.output, /\.ab = 1/);
  assert.match(r.output, /\.gh = 4/);
  assert.doesNotMatch(r.output, /d\(-9/);
});
