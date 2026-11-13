// Prompt XIII: improvements on the five primary targets, as regression tests on the committed fixtures.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { residualIndicators } from '../src/core/metrics.js';
import { recover } from '../src/recover/pipeline.js';
import { decodeText } from '../src/recover/hercules-vm.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const read = (p) => bytesToBinary(fs.readFileSync(p));
after(() => oracle.stopOracle?.());

// ---- Hercules 1.6: the VM data is written with another separator and without the backslash after every byte; control-flow junk with jumps of its own ------------------------------

test('hercules 1.6: the text of the VM data is read with the separator its alphabet leaves free, and as plain bytes when no backslash follows each', () => {
  const alphabet = 'abcdefghij';                      // a number is written in these ten digits, pieces separated by `x`
  const piece = (n) => [...String(n)].map((d) => alphabet[+d]).join('');
  assert.deepEqual([...decodeText([1, 2, 255].map(piece).join('x'), alphabet)], [1, 2, 255]);
  // 1.6.2: pieces separated by `_`, every byte followed by a backslash (92); the alphabet holds `_` in no digit
  const a2 = 'abcdefghijk';
  const piece2 = (n) => { let s = ''; let v = n; do { s = a2[v % 11] + s; v = Math.floor(v / 11); } while (v); return s; };
  assert.deepEqual([...decodeText([7, 92, 9, 92].map(piece2).join('_'), a2)], [7, 9]);
});

test('hercules 1.6 default and VirtualMachine: every fixture the generator wrote valid Lua for is lifted, and the program behaves like the original', async () => {
  const dir = path.join(corpus, 'obfuscated', 'hercules-1.6');
  const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));
  const entries = manifest.entries.filter((e) => e.status === 'ok' && /^(default|mod-VirtualMachine)$/.test(e.config));
  let lifted = 0;
  for (const e of entries) {
    const r = recover(read(path.join(dir, e.file)), { sandbox: { enabled: true } });
    const step = r.steps.find((s) => s.id === 'hercules.vm');
    // the generator's own output is invalid Lua for four default builds and leaves constants out for s06: those are not lifted, and the report says why
    if (!r.ok || !step || step.status !== 'applied') continue;
    lifted++;
    assert.deepEqual(residualIndicators(r.output), [], e.file);
    if (!oracle.available) continue;
    const original = read(path.join(corpus, 'originals', e.sample));
    const want = await oracle.runLua(original, 'lua54');
    const got = await oracle.runLua(r.output, 'lua54');
    assert.ok(want.ok && got.ok, `${e.file}: ${got.error}`);
    assert.equal(got.stdout, want.stdout, e.file);
  }
  assert.ok(lifted >= 9, `${lifted} lifted`);
});

test('decompiler: junk after a jump, with jumps of its own, is removed before the structure is read', async () => {
  const r = recover(read(path.join(corpus, 'obfuscated', 'hercules-1.6', 's03_encoded_strings__default.lua')), { sandbox: { enabled: true } });
  const step = r.steps.find((s) => s.id === 'hercules.vm');
  assert.equal(step.status, 'applied', String(step.error || step.detail));
});

// ---- Prometheus EncryptStrings: the machinery nothing reads any more ---------------------------------------------------------------------------------------------------------------

import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { removeOrphanDecoders } from '../src/recover/prometheus.js';

test('prometheus: once every string is read as text, the decryptor, its generator and the shuffle go; a program is never mistaken for them', () => {
  const machine = `local t, s = {}, 0
local function rng() s = (s * 7 + 3) % 97 return s end
local function dec(a, seed) for i = 1, #a do t[seed] = (t[seed] or "") .. string.char((string.byte(a, i) + rng()) % 256) end return seed end
dec("abc", 5)
print("hello")`;
  const ast = parse(machine);
  const r = removeOrphanDecoders(ast);
  assert.ok(r.changed > 0);
  assert.doesNotMatch(print(ast), /rng|dec\(/);
  assert.match(print(ast), /print\("hello"\)/);
  // a function that is only called as a statement but does the program's work (prints, calls through an alias, writes what other code reads) stays
  for (const keep of [
    'local function main() print("x") end main()',
    'local ins = table.insert local list = {} local function main() ins(list, 1) end main() print(#list)',
    'local out = {} local function main(f) f(out) end main(print)',
    'local n = 0 local function bump() n = n + 1 end bump() print(n)',
    'local io = {} local w = io.write local function main() w("x") end main()',
  ]) {
    const k = parse(keep);
    assert.equal(removeOrphanDecoders(k).changed, 0, keep);
  }
});

test('prometheus Strong/Medium: with the sandbox, the program behaves like the original and no encryption machinery is left, for the builds the generator got right', async () => {
  const dir = path.join(corpus, 'obfuscated', 'prometheus');
  let clean = 0;
  for (const f of ['s02_renamed_vars__Strong.lua', 's04_control_flow__Strong.lua', 's02_renamed_vars__Medium.lua', 's04_control_flow__Medium.lua']) {
    const r = recover(read(path.join(dir, f)), { sandbox: { enabled: true } });
    assert.doesNotMatch(r.output, /35184372088832|2\s*\^\s*45/, `${f}: PRNG constants are gone`);
    assert.equal(r.report.unresolved.length, 0, f);
    if (oracle.available) {
      const original = read(path.join(corpus, 'originals', `${f.split('__')[0]}.lua`));
      const want = await oracle.runLua(original, 'lua51');
      const got = await oracle.runLua(r.output, 'lua51');
      assert.equal(got.stdout, want.stdout, f);
    }
    clean++;
  }
  assert.equal(clean, 4);
});
