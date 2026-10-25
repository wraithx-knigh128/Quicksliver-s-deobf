// Behaviour of the sandbox interpreter's Luau additions and the fast paths of its operators.
// Expected values come from the Luau documentation (buffer, vector, bit32) and the Lua 5.1 manual (operators).

import test from 'node:test';
import assert from 'node:assert/strict';
import { runSource } from '../src/sandbox/sandbox.js';

function run(src, options = {}) {
  const r = runSource(src, { fuel: 5_000_000, timeMs: 10_000, dialect: 'luau', ...options });
  return r;
}
const value = (src) => {
  const r = run(src);
  assert.equal(r.ok, true, r.error);
  return r.returned[0];
};
const failure = (src) => {
  const r = run(src);
  assert.equal(r.ok, false, 'expected the script to fail');
  return r.error;
};

test('buffer: little-endian integer round trip and bounds', () => {
  assert.equal(value('local b = buffer.create(8) buffer.writeu32(b, 0, 0xdeadbeef) return buffer.readu8(b, 0)'), 0xef);
  assert.equal(value('local b = buffer.create(8) buffer.writeu32(b, 0, 0xdeadbeef) return buffer.readu8(b, 3)'), 0xde);
  assert.equal(value('local b = buffer.create(8) buffer.writeu32(b, 0, 0xdeadbeef) return buffer.readi32(b, 0)'), -559038737);
  assert.equal(value('local b = buffer.create(4) buffer.writei16(b, 0, -2) return buffer.readu16(b, 0)'), 65534);
  assert.equal(value('local b = buffer.create(4) buffer.writeu8(b, 1, 300) return buffer.readu8(b, 1)'), 44);
  assert.equal(value('local b = buffer.create(8) buffer.writef64(b, 0, 1.5) return buffer.readf64(b, 0)'), 1.5);
  assert.equal(value('local b = buffer.create(4) buffer.writef32(b, 0, 0.5) return buffer.readf32(b, 0)'), 0.5);
  assert.match(failure('local b = buffer.create(4) return buffer.readu32(b, 1)'), /buffer access out of bounds/);
  assert.match(failure('local b = buffer.create(4) buffer.writeu8(b, 4, 1)'), /buffer access out of bounds/);
});

test('buffer: strings, copy, fill, type', () => {
  assert.equal(value('local b = buffer.fromstring("hello") return buffer.tostring(b)'), 'hello');
  assert.equal(value('local b = buffer.fromstring("hello") return buffer.len(b)'), 5);
  assert.equal(value('local b = buffer.create(5) buffer.writestring(b, 1, "abc") return buffer.readstring(b, 1, 3)'), 'abc');
  assert.equal(value('local a = buffer.fromstring("abcdef") local b = buffer.create(6) buffer.copy(b, 2, a, 1, 3) return buffer.readstring(b, 2, 3)'), 'bcd');
  assert.equal(value('local b = buffer.create(4) buffer.fill(b, 1, 7, 2) return buffer.readu8(b, 0) * 100 + buffer.readu8(b, 1) * 10 + buffer.readu8(b, 2)'), 77);
  assert.equal(value('return type(buffer.create(1))'), 'buffer');
  assert.equal(value('return typeof(buffer.create(1))'), 'buffer');
  assert.equal(value('local b = buffer.create(2) buffer.writebits(b, 3, 5, 21) return buffer.readbits(b, 3, 5)'), 21);
  // bytes above 127 survive both directions unchanged
  assert.equal(value('local b = buffer.fromstring("\\255\\128") return buffer.readu8(b, 0) + buffer.readu8(b, 1)'), 383);
});

test('buffer: a size beyond the sandbox cap is a limit, not a crash', () => {
  const r = run('return buffer.create(1e12)');
  assert.equal(r.ok, false);
  assert.equal(r.kind, 'limit');
});

test('vector: construction, fields, arithmetic, tostring', () => {
  assert.equal(value('return type(vector.create(1, 2, 3))'), 'vector');
  assert.equal(value('local v = vector.create(1, 2, 3) return v.x + v.Y * 10 + v.z * 100'), 321);
  assert.equal(value('local v = vector.create(1, 2, 3) + vector.create(1, 1, 1) return v.z'), 4);
  assert.equal(value('local v = vector.create(1, 2, 3) * 2 return v.y'), 4);
  assert.equal(value('return tostring(vector.create(1, 2, 3))'), '1, 2, 3');
  assert.equal(value('return vector.create(1, 2, 3) == vector.create(1, 2, 3)'), true);
  assert.equal(value('return vector.dot(vector.create(1, 2, 3), vector.create(4, 5, 6))'), 32);
  assert.equal(value('return vector.magnitude(vector.create(3, 4, 0))'), 5);
});

test('bit32: counting, swapping and field functions', () => {
  assert.equal(value('return bit32.countlz(1)'), 31);
  assert.equal(value('return bit32.countlz(0)'), 32);
  assert.equal(value('return bit32.countrz(8)'), 3);
  assert.equal(value('return bit32.countrz(0)'), 32);
  assert.equal(value('return bit32.byteswap(0x11223344)'), 0x44332211);
  assert.equal(value('return bit32.lrotate(0x80000001, 1)'), 3);
  assert.equal(value('return bit32.rrotate(1, 1)'), 0x80000000);
  assert.equal(value('return bit32.extract(0xf0, 4, 4)'), 15);
  assert.equal(value('return bit32.replace(0, 5, 4, 4)'), 80);
  assert.equal(value('return bit32.bxor(0xffffffff, 1)'), 0xfffffffe);
  assert.equal(value('return bit32.band(-1, 0xff)'), 255);
  assert.equal(value('return bit32.bor(2 ^ 32 + 1, 2)'), 3);
});

test('operators keep their metamethod and error behaviour behind the numeric fast paths', () => {
  assert.equal(value('return -5 % 3'), 1);
  assert.equal(value('return 5 % -3'), -1);
  assert.equal(value('return 5.5 % 2'), 1.5);
  assert.equal(value('local x = 5 % 0 return x ~= x'), true);
  assert.equal(value('return 7 // 2'), 3);
  assert.equal(value('return 2 ^ 10'), 1024);
  assert.equal(value('return "10" + 1'), 11);
  assert.equal(value('return "a" < "b"'), true);
  assert.equal(value('local t = setmetatable({}, { __lt = function() return true end }) return t < 1'), true);
  assert.equal(value('local a = setmetatable({}, { __eq = function() return true end }) local b = setmetatable({}, getmetatable(a)) return a == b'), true);
  assert.equal(value('return {} == {}'), false);
  assert.equal(value('local nan = 0 / 0 return nan == nan'), false);
  assert.equal(value('return 1 == "1"'), false);
  assert.equal(value('local t = setmetatable({}, { __div = function() return 42 end }) return t / 2'), 42);
  assert.match(failure('return 1 < "2"'), /attempt to compare number with string/);
  assert.match(failure('return {} < {}'), /attempt to compare two table values/);
  assert.match(failure('return nil + 1'), /attempt to perform arithmetic on a nil value/);
});

test('table stores keep the rules of nil and NaN keys and read-only tables', () => {
  assert.match(failure('local t = {} t[nil] = 1'), /index is nil/);
  assert.match(failure('local t = {} t[0/0] = 1'), /index is NaN/);
  assert.match(failure('local t = table.freeze({}) t.x = 1'), /readonly/);
  assert.equal(value('local t = setmetatable({}, { __newindex = function(t, k, v) rawset(t, k, v * 2) end }) t.a = 4 return t.a'), 8);
  assert.equal(value('local t = {} t[1] = "a" t[2] = "b" return #t'), 2);
});

// ---- Lua 5.4 additions: bitwise operators, goto, string.pack / unpack, _ENV, integer arithmetic ----------------------------------------
// The programs print integers and strings only, so the same text can be compared with a real Lua 5.4 when the oracle is configured.

import { after } from 'node:test';
import * as oracle from './helpers/lua-oracle.mjs';
after(() => oracle.stopOracle());
const skip54 = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';
const printed = (src, options = {}) => { const r = run(src, options); assert.equal(r.ok, true, r.error); return r.output; };

const LUA54_PROGRAMS = {
  'bitwise operators on 64-bit integers': 'print(5 & 3, 5 | 3, 5 ~ 3, ~5, 1 << 4, 256 >> 4, -1 >> 60, 1 << 63, 1 << 64, 3.0 & 1)\nprint(0xFFFFFFFF & 0xFF, (1 << 62) + (1 << 62), ~0, -1 << 1)',
  'goto continue and a backward goto': 'for i = 1, 5 do\n  if i % 2 == 0 then goto continue end\n  print("i", i)\n  ::continue::\nend\nlocal n = 0\n::top::\nn = n + 1\nif n < 5 then goto top end\nprint("n", n)',
  'goto out of nested loops': 'local k = 0\nwhile true do\n  k = k + 1\n  for j = 1, 3 do\n    if k == 3 then goto out end\n  end\nend\n::out::\nprint("out", k)',
  'string.pack and string.unpack': 'local s = string.pack("<I2 >I3 z s1 c4 b", 513, 66051, "hi", "abc", "xy", -2)\nprint(#s, string.packsize("<I2 >I3 c4 b"))\nprint(string.unpack("<I2 >I3 z s1 c4 b", s))\nprint(string.unpack("<I8", "\\255\\255\\255\\255\\255\\255\\255\\127"))\nprint(string.unpack("<i4", "\\255\\255\\255\\255"))\nprint((pcall(string.unpack, "<I4", "ab")))',
  'integer multiplication keeps 64 bits': 'local s = 112478026\nlocal r = (s * 1103515245 + 12345) % 2147483648\nprint(r)\nlocal x = 1\nfor i = 1, 70 do x = x * 3 end\nprint(x)\nprint(math.maxinteger + 1 == math.mininteger)',
  '_ENV is the global table': 'x = 7\nprint(_ENV.x, _ENV == _G)',
};

for (const [name, program] of Object.entries(LUA54_PROGRAMS)) {
  test(`Lua 5.4: ${name} prints what Lua 5.4 prints`, { skip: skip54 }, async () => {
    const want = await oracle.runLua(program, 'lua54');
    assert.ok(want.ok, want.error);
    const got = run(program, { fuel: 5_000_000 });
    // the sandbox keeps doubles unless asked for integers; the integer program needs the 5.4 mode
    const r54 = runSource(program, { fuel: 5_000_000, timeMs: 10_000, dialect: 'luau', numMode: 'int64' });
    assert.equal(r54.ok, true, r54.error);
    assert.equal(r54.output, want.stdout);
    if (!/\* 1103515245|x \* 3|maxinteger/.test(program)) assert.equal(got.output, want.stdout, 'doubles agree with Lua 5.4 where no integer exceeds 2^53');
  });
}

test('Lua 5.4: bitwise operators, goto and pack/unpack give the documented values without the oracle', () => {
  assert.equal(printed('print(5 & 3, 5 | 3, 5 ~ 3, ~5, 1 << 4, 256 >> 4)'), '1\t7\t6\t-6\t16\t16\n');
  assert.equal(printed('print(-1 >> 60, 1 << 63, 1 << 64)'), '15\t-9223372036854775808\t0\n');
  assert.equal(printed('for i = 1, 4 do if i == 2 then goto continue end print(i) ::continue:: end'), '1\n3\n4\n');
  assert.equal(printed('print(string.unpack("<I2", "\\1\\2"))'), '513\t3\n');
  assert.equal(printed('print(string.pack(">I3", 66051) == "\\1\\2\\3", string.packsize("<i4 d"))'), 'true\t12\n');
  assert.match(failure('return 1.5 & 1'), /no integer representation/);
  assert.match(failure('return {} | 1'), /bitwise operation on a table value/);
  assert.match(failure('return "7" | 0'), /bitwise operation on a string value/, 'Lua 5.4 does not coerce strings in bitwise operators');
  assert.match(failure('return string.pack("!4 i4", 1)'), /alignment/);
});

test('numeric modes: doubles lose bits past 2^53 and the watch counts it; int64 keeps them', () => {
  const src = 'local s = 112478026\nreturn (s * 1103515245 + 12345) % 2147483648';
  const watched = runSource(src, { dialect: 'luau', numMode: 'watch' });
  assert.equal(watched.ok, true);
  assert.equal(watched.returned[0], 901191360, 'doubles');
  assert.ok(watched.machine.precisionLoss > 0, 'the loss is counted');
  const exact = runSource(src, { dialect: 'luau', numMode: 'int64' });
  assert.equal(exact.returned[0], 901191355, 'Lua 5.4 integers');
  const plain = runSource('return 3 * 4 + 5', { dialect: 'luau', numMode: 'watch' });
  assert.equal(plain.returned[0], 17);
  assert.equal(plain.machine.precisionLoss, 0, 'nothing counted when every result is exact');
});
