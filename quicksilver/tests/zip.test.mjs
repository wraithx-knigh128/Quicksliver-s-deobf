import test from 'node:test';
import assert from 'node:assert/strict';
import { makeZip, crc32 } from '../src/app/zip.js';
import { readZip } from './helpers/zip-read.mjs';

test('crc32 matches the reference value', () => {
  assert.equal(crc32(new TextEncoder().encode('123456789')), 0xcbf43926);
  assert.equal(crc32(new Uint8Array(0)), 0);
});

test('archive round trip keeps every byte, including non-UTF-8 data', () => {
  const raw = Uint8Array.from([0x1b, 0x4c, 0x75, 0x61, 0x51, 0, 0xff, 0xfe, 0x80]);
  const zip = makeZip([
    { name: 'original.lua', data: raw },
    { name: 'recovered/ü.lua', data: new TextEncoder().encode('print("ok")\n') },
    { name: 'empty.txt', data: new Uint8Array(0) },
  ], new Date(2026, 9, 23, 12, 0, 0));
  const files = readZip(zip);
  assert.deepEqual([...files['original.lua']], [...raw]);
  assert.equal(new TextDecoder().decode(files['recovered/ü.lua']), 'print("ok")\n');
  assert.equal(files['empty.txt'].length, 0);
});
