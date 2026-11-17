// LuaQ (closed, commercial): the outer layer decoded (src/recover/luaq.js, src/core/inflate.js), and the result honest about what is not in the file.
//
// The sample was supplied by the user and is not stored in the repository (local/luaq, git-ignored); the tests that need it skip without it.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';
import { inflateRaw, adler32, InflateError } from '../src/core/inflate.js';
import { decodeBase93, openLQZ1, decodeLuaq, looksLikeLuaq, LuaqError } from '../src/recover/luaq.js';
import { recover } from '../src/recover/pipeline.js';
import { parse } from '../src/core/parser.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const sample = path.join(here, '..', 'local', 'luaq', 'v2.7_sample.lua');
const skip = !fs.existsSync(sample) && 'the LuaQ sample is not in the repository';

test('inflate: raw DEFLATE streams of every block type come back byte for byte, and a damaged stream is refused', () => {
  const text = Buffer.from('local x = 1\n'.repeat(500) + Array.from({ length: 3000 }, (_, i) => String.fromCharCode((i * 7919) % 251)).join(''), 'latin1');
  for (const level of [0, 1, 9]) {
    const raw = zlib.deflateRawSync(text, { level });
    assert.deepEqual(Buffer.from(inflateRaw(raw)), text, `level ${level}`);
  }
  const fixed = zlib.deflateRawSync(Buffer.from('abcabcabcabc'), { strategy: zlib.constants.Z_FIXED });
  assert.equal(Buffer.from(inflateRaw(fixed)).toString(), 'abcabcabcabc');
  assert.equal(adler32(Buffer.from('Wikipedia')), 0x11e60398);
  assert.throws(() => inflateRaw(Uint8Array.from([0xff, 0xff, 0xff])), InflateError);
});

test('luaq containers: an LQZ1 header is checked against the inflated size and its Adler-32', () => {
  const body = Buffer.from('return 1', 'latin1');
  const make = (size, sum) => { const h = Buffer.alloc(12); h.write('LQZ1', 0, 'latin1'); h.writeUInt32LE(size, 4); h.writeUInt32LE(sum, 8); return Uint8Array.from(Buffer.concat([h, zlib.deflateRawSync(body)])); };
  assert.equal(Buffer.from(openLQZ1(make(body.length, adler32(body)))).toString(), 'return 1');
  assert.throws(() => openLQZ1(make(body.length, adler32(body) ^ 1)), LuaqError);
  assert.throws(() => openLQZ1(make(body.length + 1, adler32(body))), LuaqError);
});

test('luaq base 93: pairs of characters carry 13 or 14 bits, low bits first', () => {
  const alphabet = Array.from({ length: 93 }, (_, i) => String.fromCharCode(33 + i)).join('');
  // encode by the rule the decoder undoes: take 13 bits when their value is above the threshold, else 14
  const encode = (bytes, threshold) => {
    let acc = 0n; let n = 0; let out = '';
    for (const b of bytes) { acc |= BigInt(b) << BigInt(n); n += 8; while (n >= 14) { let v = Number(acc & 8191n); let w = 13; if (v <= threshold) { v = Number(acc & 16383n); w = 14; } out += alphabet[v % 93] + alphabet[Math.floor(v / 93)]; acc >>= BigInt(w); n -= w; } }
    if (n > 0) { const v = Number(acc); if (n > 7 || v > 92) out += alphabet[v % 93] + alphabet[Math.floor(v / 93)]; else out += alphabet[v]; }
    return out;
  };
  const bytes = Uint8Array.from({ length: 200 }, (_, i) => (i * 37 + 11) % 256);
  const decoded = decodeBase93(encode(bytes, 456), alphabet, 456);
  assert.deepEqual([...decoded.subarray(0, bytes.length)], [...bytes]);
});

test('luaq v2.7 sample: the outer layer is decoded to the VM runtime, and the result says the program is not in the file', { skip }, () => {
  const src = fs.readFileSync(sample, 'latin1');
  assert.ok(looksLikeLuaq(src));
  const d = decodeLuaq(src);
  assert.equal(d.version, '2.7');
  assert.equal(d.stage2Bytes, 606561);
  assert.equal(d.buildId, 'c642dea5-964f-4805-82ef-26e4598dd783');
  assert.doesNotThrow(() => parse(d.stage2));
  const r = recover(src, { sandbox: { enabled: false } });
  assert.equal(r.detection.families[0].id, 'luaq');
  const st = r.steps.find((x) => x.id === 'luaq.layers');
  assert.equal(st.status, 'applied');
  assert.equal(st.detail.programInFile, false);
  assert.equal(r.confidence.level, 'minimal', 'a runtime without its program is not a recovery');
  assert.match(r.output.split('(end of report)')[0], /not in the file/);
});
