// Closed-region evaluation (src/passes/regions.js): text that a loop builds out of constants is replaced by the text,
// and nothing else is. Every case runs on a real Lua 5.1 before and after.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { regionPass } from '../src/passes/regions.js';
import * as oracle from './helpers/lua-oracle.mjs';

const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';
after(() => oracle.stopOracle());

async function check(src) {
  const ast = parse(src);
  const t0 = Date.now();
  const stats = regionPass(ast);
  const text = print(ast);
  const a = await oracle.runLua(src, 'lua51');
  const b = await oracle.runLua(text, 'lua51');
  assert.ok(a.ok, a.error);
  assert.ok(b.ok, `${b.error}\n${text}`);
  assert.equal(b.stdout, a.stdout, `behaviour changed:\n${text}`);
  return { text, stats, ms: Date.now() - t0 };
}

const escape = (bytes) => bytes.map((b) => `\\${b}`).join('');

test('a Caesar-style decryptor written out in place becomes the text it computes', { skip }, async () => {
  const plain = 'attack at dawn';
  const key = 'k3y';
  const enc = [...plain].map((c, i) => (c.charCodeAt(0) + key.charCodeAt(i % key.length)) % 256);
  const r = await check(`
local out = ""
local key = "${key}"
local enc = "${escape(enc)}"
for i = 1, #enc do
  local k = key:byte((i - 1) % #key + 1)
  out = out .. string.char((enc:byte(i) + 256 - k) % 256)
end
print(out)`);
  assert.equal(r.stats.regions, 1);
  assert.match(r.text, /local out = "attack at dawn"/);
  assert.doesNotMatch(r.text, /for /);
  assert.match(r.text, /print\(out\)/);
});

test('a lookup-table xor decryptor with a table that dies inside the run', { skip }, async () => {
  const plain = 'Hello, QuickSilver!';
  const keyBytes = [17, 200, 3, 99, 150];
  const enc = [...plain].map((c, i) => c.charCodeAt(0) ^ keyBytes[i % keyBytes.length]);
  const r = await check(`
local function noop() end
local lut = {}
for j = 0, 255 do lut[string.char(j)] = j end
local key = "${escape(keyBytes)}"
local enc = "${escape(enc)}"
local out = ""
for i = 1, #enc do
  local a, b = lut[enc:sub(i, i)], lut[key:sub((i - 1) % #key + 1, (i - 1) % #key + 1)]
  local x, bit = 0, 1
  while a > 0 or b > 0 do
    if a % 2 ~= b % 2 then x = x + bit end
    a, b, bit = (a - a % 2) / 2, (b - b % 2) / 2, bit * 2
  end
  out = out .. string.char(x)
end
print(out)`);
  assert.equal(r.stats.regions, 1);
  assert.match(r.text, /local out = "Hello, QuickSilver!"/);
  assert.doesNotMatch(r.text, /lut/);
});

test('constants set earlier are known to a later run', { skip }, async () => {
  const r = await check(`
local unit = "ab"
print("start")
local s = ""
for i = 1, 3 do s = s .. unit end
print(s)`);
  assert.equal(r.stats.regions, 1);
  assert.match(r.text, /local s = "ababab"/);
});

test('arithmetic the program does on purpose is left alone', { skip }, async () => {
  const r = await check(`
local total = 0
for i = 1, 10 do total = total + i end
print(total)`);
  assert.equal(r.stats.regions, 0);
  assert.match(r.text, /for i = 1, 10 do/);
});

test('a run never includes a call to anything but the pure standard functions', { skip }, async () => {
  for (const body of [
    'for i = 1, 3 do s = s .. i print(i) end',                      // print
    'for i = 1, 3 do s = s .. math.random(9) end',                  // not deterministic
    'for i = 1, 3 do s = s .. tostring(os.time() > 0) end',         // os
    'for i = 1, 3 do s = s .. type(loadstring) end',                // a global value
    'local f = function() return "x" end for i = 1, 3 do s = s .. f() end',   // a closure
  ]) {
    const r = await check(`local s = ""\n${body}\nprint(#s > 0)`);
    assert.equal(r.stats.regions, 0, body);
  }
});

test('a run that leaves a table behind is cut before the table', { skip }, async () => {
  const r = await check(`
local t = {}
for i = 1, 3 do t[i] = "a" .. i end
local s = table.concat(t, ",")
print(s, t[2])`);
  assert.equal(r.stats.regions, 0);
});

test('a run that does not finish is abandoned within its budget', { skip }, async () => {
  const src = 'local s = ""\nwhile true do s = s .. "a" end\nprint(s)';
  const ast = parse(src);
  const t0 = Date.now();
  const stats = regionPass(ast);
  assert.equal(stats.regions, 0);
  assert.ok(Date.now() - t0 < 5000, 'took too long');
  assert.match(print(ast), /while true do/);
});

test('variables a closure captured are not part of a run', { skip }, async () => {
  const r = await check(`
local s = ""
local function add(x) s = s .. x end
for i = 1, 3 do add("q") end
print(s)`);
  assert.equal(r.stats.regions, 0);
});

test('a declaration the run made stays declared when later code still names it', { skip }, async () => {
  const r = await check(`
local s = ""
for i = 1, 3 do s = s .. "z" end
local scratch = "tmp"
for i = 1, 2 do scratch = scratch .. "!" end
print(s)
scratch = "again"
print(scratch)`);
  assert.ok(r.stats.regions >= 1);
});

test('a captured variable is private until the first closure that mentions it exists', { skip }, async () => {
  // the loop runs before the closure is created: nothing else can see `s`
  const early = await check(`
local s = ""
for i = 1, 3 do s = s .. "ab" end
print(s)
s = "q"
local f = function() return s end
print(f())`);
  assert.equal(early.stats.regions, 1);
  assert.match(early.text, /s = "ababab"/);

  // the closure exists first and may change `s` whenever it is called: the value is not a constant
  const late = await check(`
local s = "a"
local function set() s = "zz" end
set()
for i = 1, 2 do s = s .. "b" end
print(s)`);
  assert.equal(late.stats.regions, 0);

  const read = await check(`
local s = "x"
local function get() return s end
for i = 1, 3 do s = s .. "ab" end
print(get())`);
  assert.equal(read.stats.regions, 0);
});
