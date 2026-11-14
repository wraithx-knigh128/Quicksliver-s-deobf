// Prompt XIV: regression tests for the complete-reconstruction work, on the committed fixtures and on small controlled programs.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { recover } from '../src/recover/pipeline.js';
import { evaluatePass } from '../src/passes/evaluate.js';
import { removeUnusedJoiner } from '../src/recover/prometheus.js';
import { repairRenamedKeyword } from '../src/recover/keyword-repair.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const read = (p) => bytesToBinary(fs.readFileSync(p));
const run = (src) => recover(src, { sandbox: { enabled: true } });
const noOracle = !oracle.available && 'no Lua oracle (QS_LUA_PYTHON)';
after(() => oracle.stopOracle?.());

const sameAsOriginal = async (fixture, sample) => {
  const r = run(read(path.join(corpus, 'obfuscated', fixture)));
  const want = await oracle.runLua(read(path.join(corpus, 'originals', sample)), 'lua51');
  const got = await oracle.runLua(r.output, 'lua51');
  return { r, same: got.ok && got.stdout === want.stdout, got };
};

// ---- Prometheus: reads through the decoder's cache proxy -----------------------------------------------------------------------------------

test('evaluate: a lookup through `setmetatable(t, { __index = cache })` where t is an empty table in a local of its own is decoded', () => {
  const src = `
local store = {}
local function dec(s, k) if store[k] then return k end local o = "" for i = 1, #s do o = o .. string.char(string.byte(s, i) - 1) end store[k] = o return k end
local base = {}
local cache = setmetatable(base, { __index = store })
local function f() return cache[dec("ifmmp", 7)] end
print(f())`;
  const ast = parse(src);
  const r = evaluatePass(ast, { sandbox: { enabled: true } });
  assert.ok(r.evaluated >= 1, JSON.stringify(r));
  assert.match(print(ast), /"hello"/);
});

test('evaluate: a decoder call whose result is thrown away does not vote on whether the function returns text', () => {
  // `dec(...)` as a statement fills the cache and returns the key (a number); only the lookup yields text. Two discarded calls used to outvote it.
  const src = `
local store = {}
local function dec(s, k) if store[k] then return k end local o = "" for i = 1, #s do o = o .. string.char(string.byte(s, i) - 1) end store[k] = o return k end
local cache = setmetatable({}, { __index = store })
local function a() dec("bc", 11) return 1 end
local function b() dec("de", 12) return 2 end
local function c() return cache[dec("ifmmp", 13)] end
print(a(), b(), c())`;
  const ast = parse(src);
  evaluatePass(ast, { sandbox: { enabled: true } });
  assert.match(print(ast), /"hello"/);
});

test('evaluate: a cache proxy declared first and assigned later in a `do` block is recognised', () => {
  const src = `
local cache, dec
do
  local store = {}
  cache = setmetatable({}, { __index = store })
  function dec(s, k) if store[k] then return k end local o = "" for i = 1, #s do o = o .. string.char(string.byte(s, i) - 1) end store[k] = o return k end
end
local function f() return cache[dec("xpsme", 3)] end
print(f())`;
  const ast = parse(src);
  evaluatePass(ast, { sandbox: { enabled: true } });
  assert.match(print(ast), /"world"/);
});

test('evaluate: a statement that reads the host and is only handed a decoded value no longer stops every other decoder call', () => {
  // `env[name](x)` reads the environment: its value is the host's. It touches `x` (a decoded string), not the decoder's state.
  const src = `
local env = getfenv and getfenv() or _ENV
local list = { "ifmmp", "xpsme", "gpp", "cbs" }
for i = 1, #list do local s = list[i] local o = "" for j = 1, #s do o = o .. string.char(string.byte(s, j) - 1) end list[i] = o end
local function _0xa1(i) return list[i - 100] end
local x = _0xa1(101)
local name = _0xa1(103)
local y = _0xa1(102)
local z = _0xa1(104)
local p = env[name]
p(x)
print(x, y, z)`;
  const ast = parse(src);
  const r = evaluatePass(ast, { sandbox: { enabled: true } });
  assert.ok(!r.skipped, String(r.skipped));
  const out = print(ast);
  assert.match(out, /"world"/);
  assert.match(out, /"bar"/);
});

test('evaluate: a host read the decoder itself depends on still stops the evaluation', () => {
  const src = `
local env = getfenv and getfenv() or _ENV
local key = env["SECRET"]
local function dec(s) local o = "" for i = 1, #s do o = o .. string.char(string.byte(s, i) - key) end return o end
print(dec("ab"), dec("cd"), dec("ef"), dec("gh"), dec("ij"))`;
  const ast = parse(src);
  const r = evaluatePass(ast, { sandbox: { enabled: true } });
  assert.equal(r.changed, 0);
});

test('prometheus: an unread SplitStrings joiner is removed, a used one is kept', () => {
  const joiner = 'local j = function(t) local L, g = t[#t], "" for i = 1, #L do g = g .. L[t[i]] end return g end';
  const unused = parse(`${joiner}\nprint(1)`);
  assert.equal(removeUnusedJoiner(unused).changed, 1);
  assert.doesNotMatch(print(unused), /local j/);
  const used = parse(`${joiner}\nprint(j({ 2, 1, { "b", "a" } }))`);
  assert.equal(removeUnusedJoiner(used).changed, 0);
  const lookalike = parse('local j = function(t) local L, g = t[1], "" for i = 1, #L do g = g .. L[t[i]] end return g end\nprint(1)');
  assert.equal(removeUnusedJoiner(lookalike).changed, 0, 'only the exact shape');
});

for (const [fixture, sample] of [
  ['prometheus/s05_nested_functions__Strong.lua', 's05_nested_functions.lua'],
  ['prometheus/s07_roblox_style__Strong.lua', 's07_roblox_style.lua'],
  ['prometheus/s05_nested_functions__step-EncryptStrings.lua', 's05_nested_functions.lua'],
  ['prometheus/s01_minify_basic__step-SplitStrings.lua', 's01_minify_basic.lua'],
]) {
  test(`prometheus ${fixture}: every decoded-cache read is resolved, the run matches the original, confidence high`, { skip: noOracle }, async () => {
    const { r, same, got } = await sameAsOriginal(fixture, sample);
    assert.ok(same, got.error || 'stdout differs');
    assert.equal(r.confidence.level, 'high', JSON.stringify(r.confidence.reasons));
    assert.doesNotMatch(r.output, /35184372088832/, 'the EncryptStrings PRNG is gone');
  });
}

test('prometheus s03 Weak: the constant-array decoder is evaluated although a statement reads the environment, and the run matches the obfuscated script', { skip: noOracle }, async () => {
  // the shipped s03 diverges from the original (the tool's own fault), so the obfuscated script is the reference here
  const src = read(path.join(corpus, 'obfuscated/prometheus/s03_encoded_strings__Weak.lua'));
  const r = run(src);
  const ev = r.steps.find((s) => s.id === 'evaluate' && s.status === 'applied');
  assert.ok(ev && ev.detail.evaluated >= 40, JSON.stringify(ev && ev.detail));
  const want = await oracle.runLua(src, 'lua51');
  const got = await oracle.runLua(r.output, 'lua51');
  assert.equal(got.stdout, want.stdout);
});

// ---- Hercules 1.6: the renamer wrote every `if` as a generated name ------------------------------------------------------------------------

test('keyword repair: a name that stands exactly where `if` is missing is written as `if` again; anything less certain is left alone', () => {
  const broken = 'local a = 1\nXq a == 1 then print("one") end\nXq(a > 0)and(a < 2)then print("in") end\nlocal b = 2';
  const r = repairRenamedKeyword(broken);
  assert.equal(r.count, 2);
  assert.equal(r.name, 'Xq');
  assert.doesNotThrow(() => parse(r.source));
  // a valid script is never touched
  assert.equal(repairRenamedKeyword('if a then b() end').count, 0);
  // a candidate that is declared somewhere is an identifier, not a keyword
  assert.equal(repairRenamedKeyword('local Xq = 1\nXq a then print(1) end').count, 0);
  // two names that could be it: nothing is guessed
  assert.equal(repairRenamedKeyword('Xa a then print(1) end\nXb b then print(2) end').count, 0);
});

for (const s of ['s01_minify_basic', 's05_nested_functions']) {
  test(`hercules 1.6 default ${s}: the shipped script does not parse; after the keyword repair it runs as the original`, { skip: noOracle }, async () => {
    const src = read(path.join(corpus, `obfuscated/hercules-1.6/${s}__default.lua`));
    assert.throws(() => parse(src));
    const fixed = repairRenamedKeyword(src);
    assert.ok(fixed.count > 10);
    const want = await oracle.runLua(read(path.join(corpus, 'originals', `${s}.lua`)), 'lua51');
    assert.equal((await oracle.runLua(fixed.source, 'lua51')).stdout, want.stdout);
  });
}

test('hercules 1.6 default s04: the repaired script behaves exactly as the VM-only build of the same version (the VM template is what diverges, not the repair)', { skip: noOracle }, async () => {
  const fixed = repairRenamedKeyword(read(path.join(corpus, 'obfuscated/hercules-1.6/s04_control_flow__default.lua')));
  const vmOnly = read(path.join(corpus, 'obfuscated/hercules-1.6/s04_control_flow__mod-VirtualMachine.lua'));
  assert.equal((await oracle.runLua(fixed.source, 'lua51')).stdout, (await oracle.runLua(vmOnly, 'lua51')).stdout);
});

for (const [s, repaired] of [['s01_minify_basic', true], ['s04_control_flow', true], ['s05_nested_functions', true], ['s07_roblox_style', false]]) {
  test(`hercules 1.6 default ${s}: recovered${repaired ? ' through the repair and' : ' by'} the VM reader, the program runs as the original`, { skip: noOracle }, async () => {
    const { r, same, got } = await sameAsOriginal(`hercules-1.6/${s}__default.lua`, `${s}.lua`);
    assert.equal(r.steps.some((x) => x.id === 'keyword.repair' && x.status === 'applied'), repaired, 'the repair is a visible step, and only when needed');
    assert.ok(r.steps.some((x) => x.id === 'hercules.vm' && x.status === 'applied'));
    assert.ok(same, got.error || 'stdout differs');
  });
}

// ---- MoonVeil 2.1.0: the program container ------------------------------------------------------------------------------------------------

import { base85, lzss, readContainer21, findContainerCall } from '../src/recover/moonveil-vm/container21.js';
import { walk } from '../src/core/walk.js';

const DIGITS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~';
const enc85 = (bytes) => {
  const pad = bytes.length % 4 ? 4 - (bytes.length % 4) : 0;
  const b = [...bytes, ...new Array(pad).fill(0)];
  let s = '';
  for (let i = 0; i < b.length; i += 4) {
    let v = ((b[i] * 256 + b[i + 1]) * 256 + b[i + 2]) * 256 + b[i + 3];
    let g = '';
    for (let j = 0; j < 5; j++) { g = DIGITS[v % 85] + g; v = Math.floor(v / 85); }
    s += g;
  }
  return s.slice(0, s.length - pad);
};

test('moonveil 2.1.0 container: base 85 with RFC 1924 digits, padded with `~` and the padding dropped', () => {
  for (const bytes of [[1, 2, 3, 4], [255, 0, 7], [9], [0, 0, 0, 0, 200]]) assert.deepEqual([...base85(enc85(bytes))], bytes);
  assert.throws(() => base85('ab"cd'), /not a base-85 digit/);
});

test('moonveil 2.1.0 container: LZSS with literal flag bits and 1-based back-references into the window', () => {
  // "abcabcabc": three literals, then a reference to the start (1-based position #window - offset = 1, so offset = 2) of length 6
  const v = (2 << 5) | (6 - 3);
  assert.equal(Buffer.from(lzss(Uint8Array.from([0b0111, 97, 98, 99, v >> 8, v & 255]))).toString('latin1'), 'abcabcabc');
  assert.throws(() => lzss(Uint8Array.from([0, 0, 64])), /before the start/);
});

test('moonveil 2.1.0 container: string table and main-function header are read from a constructed program', () => {
  const program = [2, 3, ...Buffer.from('abc'), 0, 192, 5];
  // wrap it in LZSS with literal flags only: one flag byte per eight bytes
  const packed = [];
  for (let i = 0; i < program.length; i += 8) { const part = program.slice(i, i + 8); packed.push((1 << part.length) - 1, ...part); }
  const c = readContainer21(enc85(packed));
  assert.deepEqual(c.strings, ['abc', '']);
  assert.deepEqual(c.main, { marker: 192, instructions: 5 });
});

const mvSample = path.join(here, '..', 'local', 'moonveil', 'v2.1.0_sample6.lua');
test('moonveil 2.1.0 sample 6: the container call is found by its shape and read; the program is not claimed as rebuilt', { skip: !fs.existsSync(mvSample) && 'local MoonVeil samples are not in the repository' }, () => {
  const call = findContainerCall(parse(read(mvSample)), walk);
  assert.deepEqual([call.run, call.unpack, call.text], ['H', 'v', 's']);
  const c = readContainer21(call.data);
  assert.equal(c.strings.length, 6);
  assert.equal(c.main.instructions, 12);
});
