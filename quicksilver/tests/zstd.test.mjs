// The zstd decoder (src/core/zstd.js) against Node's own: whatever zlib.zstdCompressSync writes, zstdDecompress must give back.
// The inputs are made to reach every part of the format: raw, RLE and compressed blocks, Huffman literals with one and four streams,
// predefined / RLE / FSE-compressed / repeat sequence tables, repeat offsets, matches that overlap, several blocks and several frames.

import test from 'node:test';
import assert from 'node:assert/strict';
import zlib from 'node:zlib';
import { zstdDecompress, ZstdError } from '../src/core/zstd.js';

// a small deterministic generator, so a failure can be reproduced
function rng(seed) { let s = seed >>> 0; return () => { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; return s / 4294967296; }; }
const words = ['local', 'function', 'return', 'end', 'if', 'then', 'else', 'for', 'in', 'pairs', 'game', 'GetService', 'Players', 'LocalPlayer', 'print', 'string', 'format', 'table', 'insert', 'workspace', 'FindFirstChild', 'Humanoid'];
function lua(n, seed) {
  const r = rng(seed); let out = '';
  while (out.length < n) { const w = words[Math.floor(r() * words.length)]; out += (r() < 0.2 ? '\n' : ' ') + w + (r() < 0.3 ? `(${Math.floor(r() * 1000)})` : ''); }
  return Buffer.from(out.slice(0, n), 'latin1');
}
function noise(n, seed) { const r = rng(seed); return Buffer.from(Array.from({ length: n }, () => Math.floor(r() * 256))); }
function skewed(n, seed) { const r = rng(seed); return Buffer.from(Array.from({ length: n }, () => Math.min(255, Math.floor(-Math.log(1 - r() * 0.999) * 12)))); }

const cases = {
  'empty': Buffer.alloc(0),
  'one byte': Buffer.from('a'),
  'a short sentence': Buffer.from('print("Hello, QuickSilver!")'),
  'one repeated byte (RLE block)': Buffer.alloc(100000, 0x61),
  'a repeated phrase (long overlapping matches)': Buffer.from('abcabcabc'.repeat(30000)),
  'incompressible noise (raw blocks)': noise(70000, 1),
  'Lua-like text, 3 KB': lua(3000, 2),
  'Lua-like text, 40 KB (four Huffman streams)': lua(40000, 3),
  'Lua-like text, 600 KB (several blocks)': lua(600000, 4),
  'skewed bytes (Huffman with many weights)': skewed(200000, 5),
  'binary structure, 4-byte records': Buffer.from(Array.from({ length: 160000 }, (_, i) => (i % 4 === 0 ? (i >> 2) & 255 : i % 4 === 1 ? 7 : i % 4 === 2 ? 0 : 255))),
};

for (const [name, data] of Object.entries(cases)) {
  for (const level of [1, 3, 9, 19]) {
    test(`zstd: ${name}, level ${level}`, () => {
      const packed = zlib.zstdCompressSync(data, { params: { [zlib.constants.ZSTD_c_compressionLevel]: level } });
      const got = zstdDecompress(new Uint8Array(packed));
      assert.equal(Buffer.compare(Buffer.from(got), data), 0, `${got.length} bytes back, ${data.length} expected`);
    });
  }
}

test('zstd: several frames in a row are joined', () => {
  const a = lua(5000, 7); const b = noise(300, 8);
  const packed = Buffer.concat([zlib.zstdCompressSync(a), zlib.zstdCompressSync(b)]);
  assert.equal(Buffer.compare(Buffer.from(zstdDecompress(new Uint8Array(packed))), Buffer.concat([a, b])), 0);
});

test('zstd: a content checksum is skipped, not mistaken for data', () => {
  const data = lua(20000, 9);
  const packed = zlib.zstdCompressSync(data, { params: { [zlib.constants.ZSTD_c_checksumFlag]: 1 } });
  assert.equal(Buffer.compare(Buffer.from(zstdDecompress(new Uint8Array(packed))), data), 0);
});

test('zstd: damaged or foreign input is refused with ZstdError, never by hanging or crashing', () => {
  const good = zlib.zstdCompressSync(lua(30000, 10));
  assert.throws(() => zstdDecompress(new Uint8Array([1, 2, 3, 4, 5])), ZstdError);
  assert.throws(() => zstdDecompress(good.subarray(0, 40)), ZstdError, 'a frame cut short');
  const r = rng(11);
  let refused = 0; let decoded = 0;
  for (let i = 0; i < 60; i++) {
    const bad = Uint8Array.from(good);
    bad[10 + Math.floor(r() * (bad.length - 10))] ^= 1 << Math.floor(r() * 8);
    try { zstdDecompress(bad, { maxOutput: 4 * 1024 * 1024 }); decoded++; } catch (e) { assert.ok(e instanceof ZstdError, String(e && e.stack)); refused++; }
  }
  assert.ok(refused > 0, `no flipped bit was noticed (${decoded} decoded)`);
});

test('zstd: the output limit holds', () => {
  const bomb = zlib.zstdCompressSync(Buffer.alloc(10_000_000, 0));
  assert.throws(() => zstdDecompress(new Uint8Array(bomb), { maxOutput: 1_000_000 }), /limit/);
});
