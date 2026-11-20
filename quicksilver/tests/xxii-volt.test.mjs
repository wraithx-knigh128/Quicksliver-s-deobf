// Prompt XXII — Voltfuscator 8.1 (src/recover/volt.js). The vendor's own paired sample (example.source.lua and its Normal and Ultra
// outputs, github.com/usernamethisorthat/Voltils-Voltfuscator) is kept git-ignored in local/volt/; the tests that need it skip without it.
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { voltHeader, looksLikeVolt, decodeVoltConstants, voltTable } from '../src/recover/volt.js';
import { detectScript, recoverSource } from '../src/api.js';
import { parse } from '../src/core/parser.js';
import * as oracle from './helpers/lua-oracle.mjs';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const local = path.join(root, 'local', 'volt');
const have = fs.existsSync(path.join(local, 'example-Normal.lua'));
const skipLocal = !have && 'the vendor sample is kept locally only (local/volt/)';
const read = (f) => fs.readFileSync(path.join(local, f), 'latin1');
const prelude = fs.readFileSync(path.join(root, 'tools', 'volt', 'executor-prelude.lua'), 'latin1');

test('header: version, preset, runtime and source name are read from the first lines; other files are not Volt', () => {
  const head = '-- Presets: Ultra\n-- Source: x.lua\n-- Runtime: Luau/Executor\n\n([[File protected by Voltfuscator v8.1]]):gsub(".+",function(v)__voltfuscator_AbCd=v end);return({})\n';
  assert.deepEqual(voltHeader(head), { version: '8.1', preset: 'Ultra', runtime: 'Luau/Executor', sourceName: 'x.lua' });
  assert.equal(looksLikeVolt('print("File protected by Volt")'), false);
  assert.equal(looksLikeVolt('local x = 1'), false);
  const d = detectScript(head).detection;
  assert.equal(d.families[0].id, 'volt');
  assert.equal(d.families[0].version, '8.1');
});

for (const [file, preset, minChanged] of [['example-Normal.lua', 'Normal', 500], ['example-Ultra.lua', 'Ultra', 400]]) {
  test(`${preset}: every constant decodes through the file’s own checksum, under the right Fq, with the sandbox only`, { skip: skipLocal }, () => {
    const src = read(file);
    const ast = parse(src);
    assert.ok(voltTable(ast), 'the method table is found');
    assert.match(decodeVoltConstants(parse(src), { sandbox: { enabled: false } }).skipped, /sandboxed evaluation/);
    const r = decodeVoltConstants(ast, { sandbox: { enabled: true } });
    assert.equal(r.decoded, r.keys, `${r.decoded} of ${r.keys}`);
    assert.ok(r.changed >= minChanged, String(r.changed));
    // two key states: before the environment check (0) and after it
    assert.equal(Object.keys(r.fq).length, 2);
    assert.ok(r.fq[0] > 0);
  });
}

test('a tampered data field is refused by the file’s own checksum: fewer constants decode, none is invented', { skip: skipLocal }, () => {
  const src = read('example-Normal.lua');
  const good = decodeVoltConstants(parse(src), { sandbox: { enabled: true } });
  // flip one character inside the Ei data string (the field that holds the constants)
  const i = src.indexOf('Ei=[=[') + 40;
  const bad = src.slice(0, i) + (src[i] === 'A' ? 'B' : 'A') + src.slice(i + 1);
  const r = decodeVoltConstants(parse(bad), { sandbox: { enabled: true } });
  assert.ok(r.decoded < good.decoded, `${r.decoded} < ${good.decoded}`);
});

test('the decoding step keeps behaviour: on real Luau with the executor stand-in, input and recovered output print the same', { skip: skipLocal || (!oracle.available && 'QS_LUA_PYTHON is not set'), timeout: 600_000 }, async () => {
  const wrap = (code) => `${prelude}\nlocal __r = { pcall(function(...)\n${code}\nend) }\nif not __r[1] then print("ERROR", tostring(__r[2])) end\n`;
  for (const file of ['example-Normal.lua', 'example-Ultra.lua']) {
    const src = read(file);
    const r = recoverSource(src, { sandbox: { enabled: true } });
    assert.ok(r.steps.some((s) => s.id === 'volt.constants' && s.status === 'applied'));
    const [a, b] = [await oracle.runLua(wrap(src), 'luau'), await oracle.runLua(wrap(r.output), 'luau')];
    assert.equal(a.stdout, 'Voltfuscator example passed\n', file);
    assert.equal(b.stdout, a.stdout, `${file}: recovered output behaves like the protected input`);
    // the VM and its enciphered program are still there: never reported as reconstructed
    assert.notEqual(r.outcome.outcome, 'validated');
    assert.equal(r.outcome.outcome, 'not-deobfuscated');
  }
});

test('the original program runs the same on real Luau with and without the executor stand-in (the stand-in changes nothing it uses)', { skip: skipLocal || (!oracle.available && 'QS_LUA_PYTHON is not set'), timeout: 120_000 }, async () => {
  const src = read('example.source.lua');
  const a = await oracle.runLua(src, 'luau');
  const b = await oracle.runLua(`${prelude}\n${src}`, 'luau');
  assert.equal(a.stdout, b.stdout);
  // the protected build omits the preview line: VLT_OBFUSCATED is set when Voltfuscator compiles the file
  assert.match(a.stdout, /^Running the source preview\nVoltfuscator example passed\n$/);
});

after(() => oracle.stopOracle?.());
