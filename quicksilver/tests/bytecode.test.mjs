// Lua 5.1 bytecode: the chunks are produced by the real Lua 5.1 (string.dump) and must behave identically
// in the sandbox's bytecode executor. Needs the reference runtime (QS_LUA_PYTHON); skipped otherwise.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { quoteString } from '../src/core/printer.js';
import { parseChunk, disassemble, isBytecode, BytecodeError } from '../src/sandbox/bytecode.js';
import { runSource } from '../src/sandbox/sandbox.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const originals = path.join(here, 'corpus/originals');
after(() => oracle.stopOracle());
const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';

const hexToBin = (hex) => hex.replace(/../g, (h) => String.fromCharCode(parseInt(h, 16)));

async function dump51(src) {
  const code = `local f = assert(loadstring(${quoteString(src)}))\nlocal d = string.dump(f)\nprint((d:gsub('.', function(c) return string.format('%02x', c:byte()) end)))`;
  const r = await oracle.runLua(code, 'lua51');
  assert.ok(r.ok, r.error);
  return hexToBin(r.stdout.trim());
}

test('chunk header is recognised and parsed', { skip }, async () => {
  const bin = await dump51('local a = 1 print(a + 2, "x")');
  assert.ok(isBytecode(bin));
  const c = parseChunk(bin);
  assert.equal(c.main.k.includes('x'), true);
  assert.match(disassemble(c), /GETGLOBAL.*print/);
});

test('every original sample behaves identically as a compiled chunk', { skip }, async () => {
  for (const f of fs.readdirSync(originals).filter((x) => x.endsWith('.lua'))) {
    const src = bytesToBinary(fs.readFileSync(path.join(originals, f)));
    const bin = await dump51(src);
    const expected = await oracle.runLua(src, 'lua51');
    const loader = `local f = assert(loadstring(${quoteString(bin)})) f()`;
    // the Roblox-style sample needs the mock environment the oracle installs; run both on the oracle first
    const viaOracle = await oracle.runLua(loader, 'lua51');
    assert.equal(viaOracle.stdout, expected.stdout, `${f}: real Lua running its own dump`);
    if (/game|Instance|workspace/.test(src)) continue; // the sandbox has no Roblox environment
    const r = runSource(loader, { dialect: 'lua51', fuel: 50_000_000 });
    assert.ok(r.ok, `${f}: ${r.error}`);
    assert.equal(r.output, expected.stdout, `${f}: sandbox bytecode executor`);
  }
});

test('closures, upvalues, varargs, metatables and goto-free control flow', { skip }, async () => {
  const src = `
    local function counter() local n = 0 return function() n = n + 1 return n end end
    local c1, c2 = counter(), counter()
    print(c1(), c1(), c2())
    local function va(...) local t = {...} return select('#', ...), #t, ... end
    print(va(1, nil, 3))
    local mt = setmetatable({}, { __index = function(_, k) return k .. '!' end, __call = function(_, a) return a * 2 end })
    print(mt.hello, mt(21))
    local s = 0 for i = 10, 1, -3 do s = s + i end print(s)
    for k, v in ipairs({ 'a', 'b', 'c' }) do io = nil print(k, v) end
    local t = {} for i = 1, 120 do t[i] = i end print(#t, t[120])
    print(('x'):rep(3), 2 ^ 10, 7 % 3, -7 % 3, 'a' .. 1 .. 2)
    local ok, err = pcall(function() local x = nil return x.y end) print(ok, type(err))
    local fns = {} for i = 1, 3 do fns[i] = function() return i end end print(fns[1](), fns[2](), fns[3]())
    while true do s = s + 1 if s > 20 then break end end print(s)
    repeat local z = s s = s - 5 until z < 10 print(s)
  `;
  const bin = await dump51(src);
  const expected = await oracle.runLua(`local f = assert(loadstring(${quoteString(bin)})) f()`, 'lua51');
  assert.ok(expected.ok, expected.error);
  const r = runSource(`local f = assert(loadstring(${quoteString(bin)})) f()`, { dialect: 'lua51' });
  assert.ok(r.ok, r.error);
  assert.equal(r.output, expected.stdout);
});

test('foreign and damaged chunks are rejected with a reason, never executed', () => {
  assert.throws(() => parseChunk('\x1bLua\x54\x00'), BytecodeError);          // Lua 5.4 header
  assert.throws(() => parseChunk('\x1bLJ\x02'), BytecodeError);               // LuaJIT
  assert.throws(() => parseChunk('\x1bLua\x51\x00\x01\x04\x08\x04\x08\x00'), BytecodeError); // truncated
  const r = runSource(`local f, err = load("\\27Lua\\84") print(f, err)`, { dialect: 'lua51' });
  assert.ok(r.ok);
  assert.match(r.output, /^nil\tbad binary chunk/);
});
