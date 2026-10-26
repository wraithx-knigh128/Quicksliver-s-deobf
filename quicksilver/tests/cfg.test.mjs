// The control-flow structurer on hand-made graphs: diamonds, loops with exits in the middle, early returns, and the
// shapes it has to refuse.

import test from 'node:test';
import assert from 'node:assert/strict';
import { structure, CfgError } from '../src/decompile/cfg.js';

// A tiny printer over marker statements: { type: 'Mark', name }
const S = (name) => ({ type: 'Mark', name });
const render = (stmts, depth = 0) => {
  const pad = '  '.repeat(depth);
  return stmts.map((s) => {
    switch (s.type) {
      case 'Mark': return `${pad}${s.name}`;
      case 'Break': return `${pad}break`;
      case 'Return': return `${pad}return${s.values ? ' ' + s.values.join(',') : ''}`;
      case 'While': return `${pad}while ${s.cond.type === 'True' ? 'true' : s.cond.name} do\n${render(s.body, depth + 1)}\n${pad}end`;
      case 'If': {
        const c = s.clauses[0];
        let t = `${pad}if ${c.cond.name} then\n${render(c.body, depth + 1)}`;
        if (s.orelse) t += `\n${pad}else\n${render(s.orelse, depth + 1)}`;
        return `${t}\n${pad}end`;
      }
      default: throw new Error(s.type);
    }
  }).join('\n');
};
const helpers = {
  negate: (c) => ({ type: 'Not', name: c.name.startsWith('not ') ? c.name.slice(4) : `not ${c.name}` }),
  makeReturn: (values) => ({ type: 'Return', values: values && values.map((v) => v.name) }),
};
const c = (name) => ({ type: 'Cond', name });
const blk = (name, term) => ({ stmts: name ? [S(name)] : [], term });
const run = (blocks, entry) => render(structure(new Map(Object.entries(blocks)), entry, helpers));

test('a straight line', () => {
  assert.equal(run({ a: blk('A', { kind: 'goto', to: 'b' }), b: blk('B', { kind: 'goto', to: 'c' }), c: blk('C', { kind: 'exit' }) }, 'a'), 'A\nB\nC');
});

test('a diamond joins where the arms meet', () => {
  const out = run({
    a: blk('A', { kind: 'branch', cond: c('x'), t: 'b', f: 'c' }),
    b: blk('B', { kind: 'goto', to: 'd' }),
    c: blk('C', { kind: 'goto', to: 'd' }),
    d: blk('D', { kind: 'exit' }),
  }, 'a');
  assert.equal(out, 'A\nif x then\n  B\nelse\n  C\nend\nD');
});

test('an if without else, and one whose then-arm is empty', () => {
  assert.equal(run({
    a: blk('A', { kind: 'branch', cond: c('x'), t: 'b', f: 'd' }),
    b: blk('B', { kind: 'goto', to: 'd' }),
    d: blk('D', { kind: 'exit' }),
  }, 'a'), 'A\nif x then\n  B\nend\nD');
  assert.equal(run({
    a: blk('A', { kind: 'branch', cond: c('x'), t: 'd', f: 'b' }),
    b: blk('B', { kind: 'goto', to: 'd' }),
    d: blk('D', { kind: 'exit' }),
  }, 'a'), 'A\nif not x then\n  B\nend\nD');
});

test('an early return lets the rest follow the if', () => {
  const out = run({
    a: blk('A', { kind: 'branch', cond: c('x'), t: 'r', f: 'b' }),
    r: blk('R', { kind: 'return', values: null }),
    b: blk('B', { kind: 'exit' }),
  }, 'a');
  assert.equal(out, 'A\nif x then\n  R\n  return\nend\nB');
});

test('a while loop: the test sits in the header, the exit is a break', () => {
  const out = run({
    pre: blk('P', { kind: 'goto', to: 'h' }),
    h: blk('H', { kind: 'branch', cond: c('x'), t: 'body', f: 'after' }),
    body: blk('Body', { kind: 'goto', to: 'h' }),
    after: blk('After', { kind: 'exit' }),
  }, 'pre');
  assert.equal(out, 'P\nwhile true do\n  H\n  if not x then\n    break\n  end\n  Body\nend\nAfter');
});

test('a repeat loop: the test is at the bottom', () => {
  const out = run({
    pre: blk('P', { kind: 'goto', to: 'body' }),
    body: blk('Body', { kind: 'goto', to: 'test' }),
    test: blk('T', { kind: 'branch', cond: c('done'), t: 'after', f: 'body' }),
    after: blk('After', { kind: 'exit' }),
  }, 'pre');
  assert.equal(out, 'P\nwhile true do\n  Body\n  T\n  if done then\n    break\n  end\nend\nAfter');
});

test('a break from inside an if inside the loop, with cleanup before it', () => {
  const out = run({
    pre: blk('P', { kind: 'goto', to: 'h' }),
    h: blk('H', { kind: 'branch', cond: c('go'), t: 'body', f: 'after' }),
    body: blk('Body', { kind: 'branch', cond: c('stop'), t: 'brk', f: 'rest' }),
    brk: blk('Clean', { kind: 'goto', to: 'after' }),
    rest: blk('Rest', { kind: 'goto', to: 'h' }),
    after: blk('After', { kind: 'exit' }),
  }, 'pre');
  assert.equal(out, 'P\nwhile true do\n  H\n  if not go then\n    break\n  end\n  Body\n  if stop then\n    Clean\n    break\n  end\n  Rest\nend\nAfter');
});

test('nested loops and an if after an inner loop', () => {
  const out = run({
    a: blk('A', { kind: 'goto', to: 'h1' }),
    h1: blk('H1', { kind: 'branch', cond: c('c1'), t: 'b1', f: 'end' }),
    b1: blk('B1', { kind: 'goto', to: 'h2' }),
    h2: blk('H2', { kind: 'branch', cond: c('c2'), t: 'b2', f: 'tail' }),
    b2: blk('B2', { kind: 'goto', to: 'h2' }),
    tail: blk('Tail', { kind: 'goto', to: 'h1' }),
    end: blk('End', { kind: 'exit' }),
  }, 'a');
  assert.equal(out, [
    'A', 'while true do', '  H1', '  if not c1 then', '    break', '  end', '  B1',
    '  while true do', '    H2', '    if not c2 then', '      break', '    end', '    B2', '  end',
    '  Tail', 'end', 'End'].join('\n'));
});

test('a jump into the middle of a loop is refused', () => {
  assert.throws(() => run({
    a: blk('A', { kind: 'branch', cond: c('x'), t: 'h', f: 'm' }),
    h: blk('H', { kind: 'goto', to: 'm' }),
    m: blk('M', { kind: 'branch', cond: c('y'), t: 'h', f: 'z' }),
    z: blk('Z', { kind: 'exit' }),
  }, 'a'), CfgError);
});

test('a search loop with an early return, a continue and a short return block shared with the code after it', () => {
  const out = run({
    pre: blk('PRE', { kind: 'branch', cond: c('empty'), t: 'after', f: 'head' }),
    head: blk('', { kind: 'branch', cond: c('isTool'), t: 'body', f: 'step' }),
    body: blk('BODY', { kind: 'branch', cond: c('found'), t: 'hit', f: 'step' }),
    step: blk('STEP', { kind: 'branch', cond: c('done'), t: 'after', f: 'head' }),
    hit: { stmts: [], term: { kind: 'return', values: [{ name: 'yes' }] } },
    after: blk('AFTER', { kind: 'return', values: null }),
  }, 'pre');
  // the early return leaves the loop and returns after it; the `continue` is the join before STEP; the short return block is written where it is reached
  assert.equal(out, 'PRE\nif not empty then\n  while true do\n    if isTool then\n      BODY\n      if found then\n        break\n      end\n    end\n    STEP\n    if done then\n      AFTER\n      return\n    end\n  end\n  return yes\nend\nAFTER\nreturn');
});

test('early returns that share one short return block each write it out', () => {
  assert.equal(run({
    a: blk('A', { kind: 'branch', cond: c('x'), t: 'r', f: 'b' }),
    b: blk('B', { kind: 'branch', cond: c('y'), t: 'r', f: 'c' }),
    c: blk('C', { kind: 'return', values: null }),
    r: { stmts: [], term: { kind: 'return', values: [{ name: 'no' }] } },
  }, 'a'), 'A\nif not x then\n  B\n  if not y then\n    C\n    return\n  end\nend\nreturn no');
});

test('a loop inside another: its break and its normal exit are told apart although both lead back into the outer loop', () => {
  // outer: O tests, H..D is the inner loop, whose exits are `X1 -> E1` (a break that does a little first) and E1; J closes the outer loop
  const out = run({
    o: blk('O', { kind: 'branch', cond: c('cO'), t: 'h', f: 'end' }),
    h: blk('H', { kind: 'branch', cond: c('cH'), t: 'b', f: 'e1' }),
    b: blk('B', { kind: 'branch', cond: c('cB'), t: 'x1', f: 'd' }),
    d: blk('D', { kind: 'goto', to: 'h' }),
    x1: blk('X1', { kind: 'goto', to: 'e1' }),
    e1: blk('', { kind: 'goto', to: 'j' }),
    j: blk('J', { kind: 'goto', to: 'o' }),
    end: blk('END', { kind: 'exit' }),
  }, 'o');
  assert.equal(out.split('X1').length - 1, 1, out);
  assert.equal(out.split('J').length - 1, 1, out);
  assert.match(out, /break/);
});
