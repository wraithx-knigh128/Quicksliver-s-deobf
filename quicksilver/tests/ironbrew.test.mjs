// IronBrew 2 recovery, tested against output of the real tool (built from its source, see
// tests/corpus/tools/gen_ironbrew2.py) and against the sample output its repository ships.
//
// The strongest check available is behavioural: the Lua 5.1 chunk rebuilt from an obfuscated script has to run on a
// real Lua 5.1 and print what the original program prints, and so does the source the full pipeline writes.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from '../src/core/parser.js';
import { recover } from '../src/recover/pipeline.js';
import { recoverIronBrew, IronBrewError } from '../src/recover/ironbrew.js';
import { parseChunk, dumpChunk51 } from '../src/sandbox/bytecode.js';
import { detect } from '../src/detect/detect.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const dir = path.join(corpus, 'obfuscated/ironbrew2');
const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';
after(() => oracle.stopOracle());

const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));
const read = (p) => fs.readFileSync(p).toString('latin1');
const originals = new Map();
const original = (name) => {
  if (!originals.has(name)) originals.set(name, read(path.join(corpus, 'originals', name)));
  return originals.get(name);
};

test('the sample output IronBrew 2 ships is recognised and rebuilt', { skip }, async () => {
  const src = read(path.join(corpus, 'obfuscated/ironbrew2-upstream/out.lua'));
  const det = detect(src);
  const fam = det.families.find((f) => f.id === 'ironbrew2');
  assert.ok(fam && fam.confidence >= 0.95, 'detected with high confidence');
  assert.equal(fam.version, '2.7.0');
  const rebuilt = recoverIronBrew(parse(src));
  const expected = await oracle.runLua(read(path.join(corpus, 'obfuscated/ironbrew2-upstream/test.lua')), 'lua51');
  const got = await oracle.runLua(rebuilt.bytes, 'lua51');
  assert.ok(got.ok, got.error);
  assert.equal(got.stdout, expected.stdout);
  const r = recover(src, {});
  assert.equal(r.steps.find((s) => s.id === 'ironbrew2').status, 'applied');
  assert.match(r.output, /for \w+, \w+ in next, \{ "g", "h", "i" \} do/);
  assert.equal((await oracle.runLua(r.output, 'lua51')).stdout, expected.stdout);
});

const entries = manifest.entries.filter((e) => e.status === 'ok');
for (const e of entries) {
  test(`${e.file}: the rebuilt chunk and the recovered source behave like the original program`, { skip }, async () => {
    const src = read(path.join(dir, e.file));
    const expected = await oracle.runLua(original(e.sample), 'lua51');
    assert.ok(expected.ok, expected.error);

    const rebuilt = recoverIronBrew(parse(src));
    const chunk = await oracle.runLua(rebuilt.bytes, 'lua51');
    assert.ok(chunk.ok, `rebuilt chunk failed: ${chunk.error}`);
    assert.equal(chunk.stdout, expected.stdout, 'the rebuilt Lua 5.1 chunk prints something else');

    const r = recover(src, {});
    const step = r.steps.find((s) => s.id === 'ironbrew2');
    assert.equal(step && step.status, 'applied', step && (step.error || step.detail));
    assert.equal(r.ok, true);
    assert.doesNotThrow(() => parse(r.output), 'recovered source does not parse');
    const out = await oracle.runLua(r.output, 'lua51');
    assert.ok(out.ok, `recovered source failed (${out.error}):\n${r.output.slice(0, 600)}`);
    assert.equal(out.stdout, expected.stdout, 'the recovered source prints something else');
    assert.ok(r.confidence.score >= 0.8, `confidence ${r.confidence.score}`);
  });
}

test('the chunk writer reproduces what luac wrote, apart from debug information', { skip }, async () => {
  const code = 'local function f(a, ...) local t = { ... } return a, #t end print(f(1, 2, 3))';
  const dumped = await oracle.runLua(`local d = string.dump(loadstring(${JSON.stringify(code)})) print((d:gsub('.', function(c) return string.format('%02x', c:byte()) end)))`, 'lua51');
  const bin = dumped.stdout.trim().replace(/../g, (h) => String.fromCharCode(parseInt(h, 16)));
  const again = dumpChunk51(parseChunk(bin));
  assert.deepEqual(parseChunk(again).main.code, parseChunk(bin).main.code);
  const stripped = dumpChunk51(parseChunk(bin), { strip: true });
  assert.ok(stripped.length < bin.length);
  const run = await oracle.runLua(stripped, 'lua51');
  assert.ok(run.ok, run.error);
  assert.equal(run.stdout, '1\t2\n');
});

test('a script that is not IronBrew 2 output is refused with a reason, not guessed at', () => {
  assert.throws(() => recoverIronBrew(parse('print("hello")')), IronBrewError);
  const prom = read(path.join(corpus, 'obfuscated/prometheus/s06_combined__step-ProxifyLocals.lua'));
  assert.throws(() => recoverIronBrew(parse(prom)), IronBrewError);
});

test('IronBrew 2 is not reported for unrelated scripts', () => {
  const det = detect(original('s06_combined.lua'));
  assert.equal(det.families.find((f) => f.id === 'ironbrew2'), undefined);
});
