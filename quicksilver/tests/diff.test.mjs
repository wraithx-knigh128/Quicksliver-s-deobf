import test from 'node:test';
import assert from 'node:assert/strict';
import { diffLines, toRows, collapseRows } from '../src/core/diff.js';

const apply = (a, b, ops) => {
  const out = [];
  let ia = 0;
  for (const o of ops) {
    if (o.op === 'eq') { assert.equal(a[o.a], b[o.b]); assert.equal(o.a, ia); ia++; out.push(b[o.b]); }
    else if (o.op === 'del') { assert.equal(o.a, ia); ia++; }
    else out.push(b[o.b]);
  }
  assert.equal(ia, a.length);
  return out;
};

// small deterministic PRNG so failures reproduce
const rng = (seed) => () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 2 ** 32; };

test('edit script reproduces the target for random inputs', () => {
  const r = rng(7);
  for (let t = 0; t < 400; t++) {
    const n = Math.floor(r() * 40);
    const alphabet = 1 + Math.floor(r() * 8);
    const a = Array.from({ length: n }, () => `l${Math.floor(r() * alphabet)}`);
    const b = a.filter(() => r() > 0.25);
    for (let k = Math.floor(r() * 6); k > 0; k--) b.splice(Math.floor(r() * (b.length + 1)), 0, `x${Math.floor(r() * 5)}`);
    assert.deepEqual(apply(a, b, diffLines(a, b)), b);
  }
});

test('identical inputs produce only equal rows', () => {
  const a = ['a', 'b', 'c'];
  const { rows, stats } = toRows(diffLines(a, a));
  assert.equal(rows.length, 3);
  assert.deepEqual(stats, { added: 0, removed: 0, changed: 0, same: 3 });
});

test('empty sides', () => {
  assert.deepEqual(toRows(diffLines([], ['x'])).stats, { added: 1, removed: 0, changed: 0, same: 0 });
  assert.deepEqual(toRows(diffLines(['x'], [])).stats, { added: 0, removed: 1, changed: 0, same: 0 });
  assert.equal(diffLines([], []).length, 0);
});

test('a modified line is paired with its replacement', () => {
  const { rows, stats } = toRows(diffLines(['a', 'b', 'c'], ['a', 'B', 'c']));
  assert.deepEqual(rows.map((r) => r.kind), ['eq', 'chg', 'eq']);
  assert.equal(stats.changed, 1);
});

test('large, almost unrelated inputs stay fast and correct', () => {
  const a = Array.from({ length: 20000 }, (_, i) => `a${i}`);
  const b = Array.from({ length: 20000 }, (_, i) => `b${i}`);
  const t = Date.now();
  const ops = diffLines(a, b);
  assert.ok(Date.now() - t < 3000, 'bounded work');
  assert.deepEqual(apply(a, b, ops), b);
});

test('large inputs with scattered edits keep unchanged lines aligned', () => {
  const a = Array.from({ length: 30000 }, (_, i) => `line ${i}`);
  const b = a.slice();
  for (let i = 100; i < b.length; i += 997) b[i] = `edited ${i}`;
  const { stats } = toRows(diffLines(a, b));
  assert.equal(stats.changed, Math.ceil((30000 - 100) / 997));
  assert.equal(stats.added + stats.removed, 0);
});

test('collapseRows folds long unchanged runs and keeps context', () => {
  const a = Array.from({ length: 50 }, (_, i) => `l${i}`);
  const b = a.slice();
  b[25] = 'changed';
  const rows = collapseRows(toRows(diffLines(a, b)).rows, 3);
  assert.deepEqual(rows.map((r) => r.kind), ['fold', 'eq', 'eq', 'eq', 'chg', 'eq', 'eq', 'eq', 'fold']);
  assert.equal(rows[0].count, 22);
});
