import test from 'node:test';
import assert from 'node:assert/strict';
import { makeZip, crc32 } from '../src/app/zip.js';

test('crc32 matches the reference value', () => {
  assert.equal(crc32(new TextEncoder().encode('123456789')), 0xcbf43926);
  assert.equal(crc32(new Uint8Array(0)), 0);
});

// Read the archive back through its central directory, the way an unzip tool does.
function readZip(bytes) {
  const dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const eocd = bytes.length - 22;
  assert.equal(dv.getUint32(eocd, true), 0x06054b50);
  const count = dv.getUint16(eocd + 10, true);
  let p = dv.getUint32(eocd + 16, true);
  const out = {};
  for (let i = 0; i < count; i++) {
    assert.equal(dv.getUint32(p, true), 0x02014b50);
    const crc = dv.getUint32(p + 16, true);
    const size = dv.getUint32(p + 24, true);
    const nameLen = dv.getUint16(p + 28, true);
    const extraLen = dv.getUint16(p + 30, true);
    const commentLen = dv.getUint16(p + 32, true);
    const lho = dv.getUint32(p + 42, true);
    const name = new TextDecoder().decode(bytes.subarray(p + 46, p + 46 + nameLen));
    assert.equal(dv.getUint32(lho, true), 0x04034b50);
    const lname = dv.getUint16(lho + 26, true);
    const lextra = dv.getUint16(lho + 28, true);
    const data = bytes.subarray(lho + 30 + lname + lextra, lho + 30 + lname + lextra + size);
    assert.equal(crc32(data), crc, `crc of ${name}`);
    out[name] = data;
    p += 46 + nameLen + extraLen + commentLen;
  }
  return out;
}

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
