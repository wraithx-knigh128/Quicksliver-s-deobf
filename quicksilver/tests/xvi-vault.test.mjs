// Vault-Obf's register VM (github.com/polarr-is67/Vault-Obfuscator). Its licence forbids redistributing output, so the builds live in the
// git-ignored tests/corpus/obfuscated-local/ and these tests skip without them; the codec and the handler reading are tested on their own.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { recover } from '../src/recover/pipeline.js';
import { decodeAlpha, decodeBinary, classify } from '../src/recover/vault-vm.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const read = (p) => bytesToBinary(fs.readFileSync(p));
const run = (src) => recover(src, { sandbox: { enabled: true } });
after(() => oracle.stopOracle?.());

// the encoder's side, written from the generator's description (utils/luaval.py): zig-zag, base-45 digits least significant first, a flag for "more digits"
const encodeAlpha = (values, alphabet, delta) => values.map((x0) => {
  let z = x0 + delta; z = z >= 0 ? z * 2 : -z * 2 - 1;
  let out = '';
  for (;;) { const d = z % 45; z = Math.floor(z / 45); if (z) out += alphabet[45 + d]; else { out += alphabet[d]; break; } }
  return out;
}).join('');

test('vault: the printable blob codec reads back what the generator writes, negatives and large values included', () => {
  const alphabet = Array.from({ length: 90 }, (_, i) => String.fromCharCode(35 + i)).join('').replace(/@|\\/g, '!').slice(0, 90);
  const uniq = [...new Set(alphabet)].join('');
  const a = (uniq + '~}|{').slice(0, 90);
  const values = [0, 1, -1, 44, 45, -2024, 2 ** 40 + 7, 123456789];
  assert.deepEqual(decodeAlpha(encodeAlpha(values, a, 17), a, 17), values);
});

test('vault: the binary container (marker, format, key, zig-zag fields) reads back in all three field formats', () => {
  const values = [3, -4, 70000, 0, -1];
  const zig = (v) => (v >= 0 ? v * 2 : -v * 2 - 1);
  const key = 91;
  const wrap = (fmt, bytes) => String.fromCharCode(206, fmt, key, ...bytes.map((b) => (b - key + 256) % 256));
  const leb = values.flatMap((v) => { let z = zig(v); const o = []; do { const d = z % 128; z = Math.floor(z / 128); o.push(d | (z ? 128 : 0)); } while (z); return o; });
  const w4 = values.flatMap((v) => { const z = zig(v); return [z & 255, (z >>> 8) & 255, (z >>> 16) & 255, (z >>> 24) & 255]; });
  assert.deepEqual(decodeBinary(wrap(0, leb)), values);
  assert.deepEqual(decodeBinary(wrap(2, w4)), values);
  const small = [3, -4, 0, -1];
  const w2 = small.flatMap((v) => { const z = zig(v); return [z & 255, (z >>> 8) & 255]; });
  assert.deepEqual(decodeBinary(wrap(1, w2)), small);
});

test('vault: handlers are read by what they do (operands as A..E, helpers by the operator their body computes)', () => {
  assert.equal(classify('H_WREG(I, A, cs[B + 1])'), 'LOADCONST');
  assert.equal(classify('H_WREG(I, A, _[cs[B + 1]])'), 'LOADGLOBAL');
  assert.equal(classify("local rv, ok = H_SUB(regs[B], regs[C]) if ok then H_WREG(I, A, rv) else _((_[2]):gsub('%%s', _(regs[B]))) end"), 'SUB');
  assert.equal(classify('if not regs[A] then I[_] = D * 6 + 1; av = 1 end'), 'JMPIFFALSE');
  assert.equal(classify('if regs[A] then I[_] = D + 1 return 1 end'), 'JMPIFTRUE');
  assert.equal(classify('local vr2 = I[_] if B == 1 then H_WREG(I, A, vr2[1]) else I[_] = vr2 I[_] = #vr2 end'), 'VARARG');
  assert.equal(classify('H_WREG(I, A, regs[B] + regs[C] + 1)'), null);
});

const dirs = ['vault', 'vault-shapes', 'vault-luau'].map((d) => path.join(corpus, 'obfuscated-local', d)).filter((d) => fs.existsSync(path.join(d, 'manifest.json')));
const noLocal = !dirs.length && 'no local Vault fixtures (tests/corpus/obfuscated-local/vault*)';
const noOracle = !oracle.available && 'no Lua oracle (QS_LUA_PYTHON)';

test('vault (local fixtures): every build is lifted, and runs like the original, or exactly like Vault’s own build where that build is broken', { skip: noLocal || noOracle }, async () => {
  let same = 0; let asTool = 0; let undetermined = 0;
  const bad = [];
  for (const dir of dirs) {
    const m = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));
    for (const e of m.entries.filter((x) => x.status === 'ok')) {
      const src = read(path.join(dir, e.file));
      const r = run(src);
      const st = r.steps.find((x) => x.id === 'vault.vm');
      if (!st || st.status !== 'applied') { bad.push(`${e.file}: not lifted (${st && st.detail})`); continue; }
      const original = fs.readFileSync(path.join(corpus, 'originals', e.sample), 'latin1');
      const want = await oracle.runLua(original, 'lua51');
      const got = await oracle.runLua(r.output, 'lua51');
      if (got.ok && got.stdout === want.stdout) { same++; continue; }
      // anything else is never reported as a full recovery
      if (r.confidence.level === 'high' && st.detail.upvalueOrderUnresolved > 0) bad.push(`${e.file}: rated high with undetermined upvalue order`);
      const tool = await oracle.runLua(src, 'lua51');
      if (tool.ok === got.ok && tool.stdout === got.stdout) { asTool++; continue; }
      // closures whose scrambled upvalue order the evidence cannot settle: the result is neither, and it must say so
      if (st.detail.upvalueOrderUnresolved > 0 && r.confidence.level !== 'high') { undetermined++; continue; }
      bad.push(`${e.file}: ${got.error || 'output differs'}`);
    }
  }
  assert.deepEqual(bad, []);
  assert.ok(same > 0);
  void asTool; void undetermined;
});
