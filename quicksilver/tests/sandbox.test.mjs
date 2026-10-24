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
