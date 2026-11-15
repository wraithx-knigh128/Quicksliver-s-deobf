// RealObfuscator's function VM lifted back to source (src/recover/realobfuscator-vm.js).
//
// The fixtures are the tool's own output (GPL-3.0), so they stay in the git-ignored tests/corpus/obfuscated-local/realobfuscator-2.2.1 and the
// tests that need them skip without them. The record codec and the handler shapes are also tested on data built here.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { parse } from '../src/core/parser.js';
import { recover } from '../src/recover/pipeline.js';
import { decodeRecords, classifyHandler } from '../src/recover/realobfuscator-vm.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const dir = path.join(here, 'corpus', 'obfuscated-local', 'realobfuscator-2.2.1');
const originals = path.join(here, 'corpus', 'originals');
const noOracle = !oracle.available && 'no Lua oracle (QS_LUA_PYTHON)';
after(() => oracle.stopOracle?.());

const manifest = fs.existsSync(path.join(dir, 'manifest.json')) ? JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8')) : { entries: [] };
for (const e of manifest.entries.filter((x) => x.status === 'ok' && /^vm/.test(x.config))) {
  test(`realobfuscator ${e.file}: every VM function is lifted and the script runs like the original`, { skip: noOracle }, async () => {
    const r = recover(bytesToBinary(fs.readFileSync(path.join(dir, e.file))), { sandbox: { enabled: true } });
    const st = r.steps.find((x) => x.id === 'realobfuscator.vm');
    assert.equal(st && st.status, 'applied', st && String(st.detail));
    assert.equal(st.detail.selfCheck, 'same');
    const code = r.output.replace(/^--.*\n/gm, '');
    assert.doesNotThrow(() => parse(code));
    const want = await oracle.runLua(fs.readFileSync(path.join(originals, e.sample), 'latin1'), 'luau');
    const got = await oracle.runLua(r.output, 'luau');
    assert.equal(got.ok, want.ok, got.error);
    assert.equal(got.stdout, want.stdout);
    assert.equal(r.confidence.level, 'high');
  });
}

// the generator's record codec, written for the test from its description: a 32-bit xorshift stream fed back with the ciphertext
function encodeRecord(words, layout, physical, { seed, salt, step }) {
  const bytes = new Array(24).fill(0);
  words.forEach((w, i) => { for (let k = 0; k < 4; k++) bytes[(layout[i] - 1) + k] = (w >>> (8 * k)) & 255; });
  let hash = physical;
  for (let i = 0; i < 20; i++) hash = (hash * 257 + bytes[i]) % 2147483647;
  for (let k = 0; k < 4; k++) bytes[20 + k] = Math.floor(hash / 256 ** k) & 255;
  const plain = [0, ...bytes];
  let key = (seed ^ salt ^ physical) >>> 0;
  return plain.map((b, i) => {
    key = (key ^ (key << 13)) >>> 0; key = (key ^ (key >>> 17)) >>> 0; key = (key ^ (key << 5)) >>> 0;
    const c = (b ^ key) & 255;
    key = (key + step + c + i + 1) % 4294967296;
    return c;
  });
}

test('realobfuscator records: decoded with the keys the record carries, the byte layout undone and the checksum verified', () => {
  const keys = { seed: 836535542, salt: 2697719583, step: 1768728283 };
  const layout = [13, 9, 1, 17, 5];
  const recs = [[40001, 3, 7, 0, 2], [40002, 1, 0, 0, 0]].map((w, i) => encodeRecord(w, layout, i + 1, keys));
  const table = (items) => ({ type: 'Table', fields: items.map((v) => ({ kind: 'item', value: typeof v === 'object' ? v : { type: 'Number', value: v } })) });
  const fields = new Map([[1, table(recs.map(table))], [2, { type: 'Number', value: keys.seed }], [3, { type: 'Number', value: keys.salt }], [4, { type: 'Number', value: keys.step }], [5, { type: 'Number', value: 2 }], [6, table(layout)]]);
  const schema = { payload: 1, seed: 2, salt: 3, step: 4, count: 5, layout: 6, offsets: 7 };
  const out = decodeRecords(fields, schema);
  assert.deepEqual(out.slice(1), [{ op: 40001, a: 3, b: 7, c: 0, next: 2 }, { op: 40002, a: 1, b: 0, c: 0, next: 0 }]);
  // a wrong key fails the checksum instead of giving wrong instructions
  fields.set(4, { type: 'Number', value: keys.step + 1 });
  assert.throws(() => decodeRecords(fields, schema), /checksum|unknown packing|decodes to/);
});

test('realobfuscator handlers: told apart by what they do once the runtime’s names are put back', () => {
  assert.deepEqual(classifyHandler('R[A] = R[B]'), { op: 'Move' });
  assert.deepEqual(classifyHandler('R[A] = R[B] .. R[C]'), { op: 'Binary', operator: '..' });
  assert.deepEqual(classifyHandler('R[A] = R[C] < R[B]'), { op: 'Binary', operator: '>' });
  assert.deepEqual(classifyHandler('R[A] = R[B] + K(C)'), { op: 'BinaryConstant', operator: '+' });
  assert.deepEqual(classifyHandler('local v = R[A] v.n += 1 v[v.n] = R[B]'), { op: 'Push' });
  assert.deepEqual(classifyHandler('if not R[A] then PC = B end'), { op: 'JumpFalse' });
  assert.equal(classifyHandler('R[A] = R[B] + R[C] + 1'), null);
});
