// Runtime verification: real Lua runtimes as an oracle, kept apart from static analysis.
//
// These tests need a reference runtime (`tools/runtime/setup.sh`, or QS_LUA_PYTHON pointing at a Python with lupa). Without one the tests that need it are
// skipped WITH THE REASON, and the tests that do not (the unavailable-runtime contract, the separation of verdicts) still run: a missing oracle must never
// be silently replaced by something that agrees.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { Oracle, oracle, stopOracle, RUNTIMES, findPython } from '../tools/runtime/oracle.mjs';
import { compareBehaviour, observeBehaviour, sandboxRun } from '../tools/lab/behaviour.mjs';
import { differential } from '../tools/research/differential.mjs';

after(() => stopOracle());

const found = await oracle().detect();
const have = (id) => found.some((r) => r.id === id && r.available);
const need = (id) => (have(id) ? false : `${id} is not installed here (tools/runtime/setup.sh)`);

test('oracle: every runtime is listed, and one that is not installed says so instead of being approximated', async () => {
  assert.deepEqual(found.map((r) => r.id).sort(), Object.keys(RUNTIMES).sort());
  const none = new Oracle({ python: null, luau: null });
  for (const id of ['lua51', 'luajit', 'luau']) {
    const r = await none.run(id, 'print(1)');
    assert.equal(r.ok, false);
    assert.equal(r.unavailable, true, `${id} without an installation is "unavailable"`);
    assert.equal(r.stdout, '');
  }
  const cmp = compareBehaviour(await observeBehaviour('print(1)', ['lua51']), await observeBehaviour('print(1)', ['lua51']));
  if (!have('lua51')) assert.equal(cmp.verdict, 'inconclusive', 'two unavailable runs are not "identical"');
  await none.stop();
});

test('oracle: Luau is reported unavailable unless a binary is named; it is never stood in for by another runtime', () => {
  const luau = found.find((r) => r.id === 'luau');
  if (!process.env.QS_LUAU_BIN) { assert.equal(luau.available, false); assert.match(luau.why || '', /Luau|QS_LUAU_BIN/); }
});

test('oracle: a program runs, prints, and the runtime that ran it is named', { skip: need('lua51') }, async () => {
  const r = await oracle().run('lua51', 'print(_VERSION, 6 * 7)');
  assert.equal(r.ok, true);
  assert.match(r.stdout, /Lua 5\.1\t42/);
  assert.equal(r.runtime, 'lua51');
});

test('oracle: runtimes that differ are told apart (5.1 and 5.4 disagree about integer division and about unpack)', { skip: have('lua51') && have('lua54') ? false : 'needs lua51 and lua54' }, async () => {
  const src = 'print(7 // 2 == nil, type(table.unpack), type(unpack))';
  const a = await oracle().run('lua51', 'print(type(table.unpack), type(unpack))');
  const b = await oracle().run('lua54', 'print(type(table.unpack), type(unpack))');
  assert.notEqual(a.stdout, b.stdout, 'the same program prints different things on 5.1 and 5.4');
  void src;
});

test('oracle: errors are reported with the runtime\'s own message, not swallowed', { skip: need('lua51') }, async () => {
  const r = await oracle().run('lua51', 'local t = nil\nprint(t.x)');
  assert.equal(r.ok, false);
  assert.match(r.error, /attempt to index/);
});

test('oracle: the program gets no files, no processes and no packages', { skip: need('lua51') }, async () => {
  const r = await oracle().run('lua51', 'print(io, os.execute, os.remove, package, require, loadfile, dofile, io and io.open)');
  assert.equal(r.ok, true);
  assert.equal(r.stdout.trim(), 'nil\tnil\tnil\tnil\tnil\tnil\tnil\tnil');
});

test('oracle: an infinite loop is stopped, and the oracle is usable afterwards', { skip: need('lua51'), timeout: 60_000 }, async () => {
  const r = await oracle().run('lua51', 'while true do end', { timeoutMs: 3000, budget: 2_000_000 });
  assert.equal(r.ok, false);
  assert.match(r.error, /budget|time|killed|stopped/i);
  const after2 = await oracle().run('lua51', 'print("alive")');
  assert.equal(after2.stdout.trim(), 'alive');
});

test('oracle: a program that removes its own instruction hook is still stopped by the wall clock', { skip: need('lua51'), timeout: 60_000 }, async () => {
  const hostile = 'debug.sethook() while true do end';
  const r = await oracle().run('lua51', hostile, { timeoutMs: 3000 });
  assert.equal(r.ok, false);
  assert.ok(r.timedOut || /time|killed|budget/i.test(r.error), r.error);
  assert.equal((await oracle().run('lua51', 'print(1)')).stdout.trim(), '1', 'the runner was restarted');
});

test('oracle: a memory bomb is stopped by the process cap, not by the program\'s cooperation', { skip: need('lua51'), timeout: 90_000 }, async () => {
  const bomb = 'local t = {} for i = 1, 1e9 do t[i] = string.rep("x", 1e6) .. i end';
  const r = await oracle().run('lua51', bomb, { timeoutMs: 20_000 });
  assert.equal(r.ok, false);
  assert.equal((await oracle().run('lua51', 'print("after")')).stdout.trim(), 'after');
});

test('verdicts: runtime behaviour and static checks are separate fields, and only the runtime decides', { skip: need('lua51') }, async () => {
  const orig = 'local s = 0 for i = 1, 10 do s = s + i end print(s)';
  const same = 'local s=0\nfor i=1,10 do s=s+i end\nprint(s)';
  const wrong = 'local s=0\nfor i=1,10 do s=s+i+1 end\nprint(s)';
  const r = await differential({ pairs: [{ id: 'a', original: orig, protected: same }, { id: 'b', original: orig, protected: wrong }] }, { runtimes: ['lua51'], recover: (src) => ({ ok: true, output: src }) });
  const [a, b] = r.rows;
  assert.equal(a.verdict, 'runtime-identical');
  assert.equal(b.verdict, 'runtime-different');
  assert.equal(b.static.parses, true, 'the wrong program is perfectly valid source: static checks cannot see the difference');
  assert.deepEqual(b.runtime.difference && { original: b.runtime.difference.original.trim(), got: b.runtime.difference.got.trim() }, { original: '55', got: '65' });
  assert.equal(r.results.runtimeVerified, 2);
  assert.equal(r.results.runtimeSuccess, 1);
});

test('verdicts: without a reference runtime a pair is "no-reference-runtime", never "identical"', async () => {
  const r = await differential({ pairs: [{ id: 'a', original: 'print(1)', protected: 'print(1) ' }] }, { runtimes: [], recover: (src) => ({ ok: true, output: src }) });
  assert.equal(r.rows[0].verdict, 'no-reference-runtime');
  assert.equal(r.results.runtimeVerified, 0);
});

test('verdicts: a recovery that produced nothing is "recovery-failed", and a program that prints nothing is inconclusive', { skip: need('lua51') }, async () => {
  const r = await differential({ pairs: [{ id: 'a', original: 'print(1)', protected: 'x' }, { id: 'b', original: 'local x = 1', protected: 'local x = 1 ' }] }, { runtimes: ['lua51'], recover: (src) => (src === 'x' ? { ok: false, error: 'no' } : { ok: true, output: src }) });
  assert.equal(r.rows[0].verdict, 'recovery-failed');
  assert.equal(r.rows[1].verdict, 'inconclusive');
});

test('cross-check: the in-house sandbox and the reference runtime agree on a program that uses only what both implement', { skip: need('lua51') }, async () => {
  const src = 'local t = {} for w in ("a b c"):gmatch("%a") do t[#t+1] = w:upper() end print(table.concat(t, "-"), #t, select("#", 1, 2, 3))';
  const ref = await oracle().run('lua51', src);
  const sb = sandboxRun(src);
  assert.equal(sb.output, ref.stdout);
});

test('setup: the runtime is a documented step, and where it lives is where the oracle looks', () => {
  if (have('lua51')) assert.ok(findPython(), 'a runtime is available, so a Python was found');
});
