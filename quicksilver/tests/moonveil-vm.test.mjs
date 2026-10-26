// The general machinery of the MoonVeil VM lifter: the liveness solver the clean-up leans on, and the search that opens an encrypted stub.
// The tests build their own small inputs. The test that runs the whole pipeline on a protected script reads one from tests/corpus/user-local
// (private, never committed) and is skipped when that folder has none.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { liveness } from '../src/recover/cfg-opt.js';
import { sha256, chacha, addLE } from '../src/recover/moonveil-crypto.js';
import { searchStubKey, combinations } from '../src/recover/moonveil-vm/stub.js';
import { readBlob } from '../src/recover/moonveil-vm/blob.js';
import { recover } from '../src/recover/pipeline.js';
import { inSmallStack } from './helpers/small-stack.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const name = (n) => ({ type: 'Name', name: n });
const assign = (targets, values) => ({ type: 'Assign', targets: targets.map(name), values: values.map(name) });

// ---- liveness ---------------------------------------------------------------------------------------------------------------------------

/** Names live on entry to each block, by iterating sets to a fixed point (the obvious way, to check the bit-set solver against). */
function reference(blocks, exitLive) {
  const succs = (t) => (t.kind === 'goto' ? [t.to] : t.kind === 'branch' ? [t.t, t.f] : []);
  const liveIn = new Map([...blocks.keys()].map((k) => [k, new Set()]));
  for (let changed = true; changed;) {
    changed = false;
    for (const [k, b] of blocks) {
      const cur = new Set();
      for (const m of succs(b.term)) for (const x of liveIn.get(m)) cur.add(x);
      if (b.term.kind === 'branch') cur.add(b.term.cond.name);
      if (b.term.kind === 'exit') for (const x of exitLive) cur.add(x);
      for (let i = b.stmts.length - 1; i >= 0; i--) {
        const st = b.stmts[i];
        for (const t of st.targets) cur.delete(t.name);
        for (const v of st.values) cur.add(v.name);
      }
      const old = liveIn.get(k);
      if (cur.size !== old.size || [...cur].some((x) => !old.has(x))) { liveIn.set(k, cur); changed = true; }
    }
  }
  return liveIn;
}

test('liveness agrees with a plain set-based solution on random graphs, names past the first machine word included', () => {
  let seed = 12345;
  const rnd = (n) => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed % n; };
  const pool = Array.from({ length: 75 }, (_, i) => `v${i}`);
  for (let round = 0; round < 40; round++) {
    const n = 3 + rnd(12);
    const blocks = new Map();
    for (let k = 0; k < n; k++) {
      const stmts = [];
      for (let s = rnd(5); s > 0; s--) stmts.push(assign(Array.from({ length: 1 + rnd(2) }, () => pool[rnd(75)]), Array.from({ length: 1 + rnd(2) }, () => pool[rnd(75)])));
      const kind = k === n - 1 ? 'exit' : ['goto', 'branch', 'goto'][rnd(3)];
      const term = kind === 'exit' ? { kind } : kind === 'goto' ? { kind, to: rnd(n) } : { kind, cond: name(pool[rnd(75)]), t: rnd(n), f: rnd(n) };
      blocks.set(k, { stmts, term });
    }
    const exitLive = new Set(Array.from({ length: rnd(40) }, () => pool[rnd(75)]));
    const got = liveness(blocks, exitLive);
    const want = reference(blocks, exitLive);
    for (const k of blocks.keys()) assert.deepEqual([...got.get(k)].sort(), [...want.get(k)].sort(), `round ${round}, block ${k}`);
  }
});

// ---- opening a stub -------------------------------------------------------------------------------------------------------------------

const CONSTANTS = [2846445141, 1400178223, 2515970237, 3225862554];
const profile = { opMap: [null, 0], layouts: { 0: [] }, constFields: [], protoMagic: 129 };
const bin = (bytes) => Buffer.from(bytes).toString('latin1');

/** A program of one function with no constants, one instruction and a long name, so that its compressed form is more than one block long. */
function sampleProgram() {
  const bytes = [129, 0, 1, 1, 0, 1, 80, ...Array.from({ length: 80 }, (_, i) => 97 + (i % 26)), 0, 0, 1, 0];
  const read = readBlob(Uint8Array.from(bytes), profile);
  assert.equal(read.end, read.length);
  return Uint8Array.from(bytes);
}
/** The compression the runtime uses, with literals only: a control byte of ones before each run of eight bytes. */
function store(bytes) {
  const out = [];
  for (let i = 0; i < bytes.length; i += 8) { out.push(255); out.push(...bytes.slice(i, i + 8)); }
  return Uint8Array.from(out);
}
function makeStub(base, offset) {
  const nonce = Uint8Array.from({ length: 12 }, (_, i) => 7 * i + 3);
  const key = sha256(addLE(bin(base), offset));
  const payload = Uint8Array.from(Buffer.from(chacha(bin(store(sampleProgram())), bin(nonce), key, CONSTANTS), 'latin1'));
  return { payload, nonce };
}

test('the key of a stub is found from the constants it is built from and a small number', () => {
  const base = Uint8Array.from({ length: 32 }, (_, i) => (i * 37 + 11) & 255);
  const stub = makeStub(base, 4321);
  const found = searchStubKey(stub, [{ bytes: base, mask: 1, size: 1, of: 1 }], { constants: CONSTANTS, profile, limit: 20000 });
  assert.ok(found, 'the key was found');
  assert.equal(found.offset, 4321);
  assert.equal(found.root.code.length, 1);
});

test('the search follows the carry when the number pushes the sum past the first four bytes', () => {
  const base = Uint8Array.from({ length: 32 }, (_, i) => (i < 4 ? 250 : (i * 5) & 255));
  base[3] = 255;
  const stub = makeStub(base, 3000); // 0xfffffffa-ish + 3000 overflows into byte 4
  const found = searchStubKey(stub, [{ bytes: base, mask: 1, size: 1, of: 1 }], { constants: CONSTANTS, profile, limit: 10000 });
  assert.ok(found);
  assert.equal(found.offset, 3000);
});

test('no key among the candidates: nothing is returned, and the search stops when asked', () => {
  const base = Uint8Array.from({ length: 32 }, (_, i) => i);
  const other = Uint8Array.from({ length: 32 }, (_, i) => i ^ 0x55);
  const stub = makeStub(base, 100);
  assert.equal(searchStubKey(stub, [{ bytes: other, mask: 1, size: 1, of: 1 }], { constants: CONSTANTS, profile, limit: 3000 }), null);
  // asked to stop (it is asked every few thousand numbers), it gives up before reaching a key that lies further on
  const far = makeStub(base, 40000);
  let calls = 0;
  assert.equal(searchStubKey(far, [{ bytes: base, mask: 1, size: 1, of: 1 }], { constants: CONSTANTS, profile, limit: 1 << 20, shouldStop: () => ++calls > 1 }), null);
  assert.ok(searchStubKey(far, [{ bytes: base, mask: 1, size: 1, of: 1 }], { constants: CONSTANTS, profile, limit: 1 << 20 }));
});

test('a best guess that is wrong costs time, not the key: the other combinations are searched after it', () => {
  const right = Uint8Array.from({ length: 32 }, (_, i) => (i * 13 + 5) & 255);
  const wrong = Uint8Array.from({ length: 32 }, (_, i) => (i * 7 + 1) & 255);
  const stub = makeStub(right, 700);
  const bases = [
    { bytes: wrong, mask: 1, size: 1, of: 2, score: 2, likely: true, best: true },
    { bytes: right, mask: 2, size: 1, of: 2, score: 1, likely: true, best: false },
  ];
  const found = searchStubKey(stub, bases, { constants: CONSTANTS, profile, limit: 5000 });
  assert.ok(found);
  assert.equal(found.mask, 2);
  assert.equal(found.offset, 700);
});

test('evidence about how the constants are used puts the likeliest combination first', () => {
  const constants = ['a', 'b', 'c', 'd'].map((c) => c.repeat(32));
  const roles = new Map([[constants[0], 'operand'], [constants[1], 'operand'], [constants[2], 'operand'], [constants[3], 'other']]);
  const ordered = combinations(constants, 10, roles);
  assert.equal(ordered[0].mask, 0b0111);
  assert.equal(ordered[0].best, true);
  assert.equal(ordered.filter((c) => c.likely).length, 5);
});

test('combinations list the ways to combine the constants, those that use most of them first', () => {
  const constants = ['a', 'b', 'c', 'd'].map((c) => c.repeat(32));
  const all = combinations(constants);
  assert.equal(all.length, 15);
  assert.equal(all[0].size, 4);
  assert.deepEqual(all.slice(1, 5).map((c) => c.size), [3, 3, 3, 3]);
  assert.equal(all[all.length - 1].size, 1);
  // xor of 'a' and 'b' (0x61 ^ 0x62 = 3)
  const ab = all.find((c) => c.mask === 0b0011);
  assert.ok(ab.bytes.every((b) => b === 3));
});

// ---- the page runs the engine in a worker, whose stack is smaller than the main thread's ------------------------------------------------

test('the base-85 text of a hundred thousand characters is decoded on a small stack', async () => {
  const Z85 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~';
  const text = Array.from({ length: 120000 }, (_, i) => Z85[(i * 7 + (i >> 3)) % 85]).join('');
  assert.equal(await inSmallStack('z85', { text }, 0.5), 96000);
});

// ---- the whole thing, on a protected script kept outside the repository ----------------------------------------------------

const privateDir = path.join(here, 'corpus', 'user-local');
const privateScripts = fs.existsSync(privateDir) ? fs.readdirSync(privateDir).filter((f) => /\.(lua|txt)$/i.test(f)) : [];

test('a MoonVeil VM program is read back from its data (runs only when a protected script is present in tests/corpus/user-local)', { skip: privateScripts.length ? false : 'no private script in tests/corpus/user-local' }, () => {
  let lifted = 0;
  for (const file of privateScripts) {
    const events = [];
    const r = recover(fs.readFileSync(path.join(privateDir, file)).toString('latin1'), { sandbox: { enabled: false }, onProgress: (e) => events.push(e) });
    const step = r.steps.find((s) => s.id === 'moonveil.vm');
    if (!step || step.status !== 'applied') continue; // another protector, or one this reader does not know
    lifted++;
    // progress: the phases come in order, and the counts of the last one only go up and end at the total
    const phases = [...new Set(events.map((e) => e.phase))];
    assert.deepEqual(phases.filter((p) => ['profile', 'data', 'stub', 'lift'].includes(p)), ['profile', 'data', 'stub', 'lift']);
    const counted = events.filter((e) => e.phase === 'lift' && e.done !== undefined);
    const counts = counted.map((e) => e.done);
    assert.ok(counts.every((n, i) => i === 0 || n >= counts[i - 1]), 'the count never goes back');
    assert.equal(counts[counts.length - 1], counted[0].total);
    assert.equal(r.ok, true, `${file}: the output parses and prints back identically`);
    assert.ok(step.detail.protos > 1);
    assert.equal(step.detail.notStructured, 0, `${file}: every function was structured`);
    assert.ok(step.detail.validation.ok, `${file}: ${JSON.stringify(step.detail.validation)}`);
    assert.equal(step.detail.validation.constants.missing, 0);
    assert.ok(step.detail.validation.constants.readable > 100);
    assert.ok(!/\bCHILDREN\b|\bVARARGS\b|\bPACKN\b|\bvm_[a-z0-9_]+\(/.test(r.output), `${file}: no interpreter symbol is left in the output`);
  }
  assert.ok(lifted > 0 || privateScripts.length > 0);
});

test('lifting each instruction once per kind gives the same program as lifting every one (runs only when a protected script is present)', { skip: privateScripts.length ? false : 'no private script in tests/corpus/user-local' }, () => {
  for (const file of privateScripts) {
    const source = fs.readFileSync(path.join(privateDir, file)).toString('latin1');
    const fast = recover(source, { sandbox: { enabled: false } });
    const step = fast.steps.find((s) => s.id === 'moonveil.vm');
    if (!step || step.status !== 'applied') continue;
    const slow = recover(source, { sandbox: { enabled: false }, reuseInstructions: false });
    assert.equal(slow.output, fast.output, `${file}: reusing a lifted instruction changed the result`);
  }
});

test('the same protected script is rebuilt on the stack of a page worker (runs only when a protected script is present)', { skip: privateScripts.length ? false : 'no private script in tests/corpus/user-local' }, async () => {
  for (const file of privateScripts) {
    const source = fs.readFileSync(path.join(privateDir, file)).toString('latin1');
    const here = recover(source, { sandbox: { enabled: false }, moonveilVm: true });
    const lifted = here.steps.find((s) => s.id === 'moonveil.vm');
    if (!lifted || lifted.status !== 'applied') continue;
    const there = await inSmallStack('recover', { source }, 1);
    assert.deepEqual(there.steps.find((s) => s[0] === 'moonveil.vm'), ['moonveil.vm', 'applied'], `${file}: the VM reader also runs in a worker`);
    assert.equal(there.length, here.output.length);
  }
});
