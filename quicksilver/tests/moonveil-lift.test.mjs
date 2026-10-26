// The parts of the MoonVeil VM lifter that are general: the primitives its runtime carries, and the clean-ups that turn instruction-by-instruction
// output back into expressions and loops. Everything here runs on short programs written for the test; no script from outside the repository is read.

import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { sha256, chacha, lz, addLE } from '../src/recover/moonveil-crypto.js';
import { optimizeCfg, liveness } from '../src/recover/cfg-opt.js';
import { openRuns, inlineTemps, forwardSubstitute, methodSugar, shortCircuit, typeHashTests, copyPropagate, unpackPack } from '../src/recover/moonveil-idioms.js';
import { forIn, declareLocals, dotKeys } from '../src/recover/moonveil-polish.js';

const bin = (buf) => Buffer.from(buf).toString('latin1');
const text = (stmts) => print({ type: 'Chunk', body: stmts, endComments: [], features: new Set() }).trim();
const stmts = (src) => parse(src).body;
const blk = (src, term = { kind: 'exit' }) => ({ stmts: stmts(src), term });
const show = (blocks, id) => text(blocks.get(id).stmts);

// ---- primitives ---------------------------------------------------------------------------------------------------------------

test('sha256 agrees with the platform over the padding boundaries', () => {
  for (const n of [0, 1, 3, 55, 56, 57, 63, 64, 65, 119, 120, 1000]) {
    const s = bin(crypto.randomBytes(n));
    assert.equal(sha256(s), bin(crypto.createHash('sha256').update(Buffer.from(s, 'latin1')).digest()), `length ${n}`);
  }
});

test('chacha is ChaCha20 with the constants it is given: the standard ones reproduce the platform cipher, the counter starting at 0', () => {
  const key = crypto.randomBytes(32);
  const nonce = crypto.randomBytes(12);
  const data = crypto.randomBytes(200);
  const standard = [0x61707865, 0x3320646e, 0x79622d32, 0x6b206574];
  const ours = chacha(bin(data), bin(nonce), bin(key), standard);
  const c = crypto.createCipheriv('chacha20', key, Buffer.concat([Buffer.alloc(4), nonce]));
  const theirs = bin(Buffer.concat([c.update(data), c.final()]));
  assert.equal(ours, theirs);
});

test('chacha with the runtime’s own constants is its own inverse and refuses a key or nonce of the wrong size', () => {
  const key = bin(crypto.randomBytes(32));
  const nonce = bin(crypto.randomBytes(12));
  const data = bin(crypto.randomBytes(130));
  const once = chacha(data, nonce, key);
  assert.notEqual(once, data);
  assert.equal(chacha(once, nonce, key), data);
  assert.equal(chacha(data, nonce.slice(1), key), null);
  assert.equal(chacha(data, nonce, key.slice(1)), null);
});

test('lz: literals, and a reference that reads the window as it stood before the item', () => {
  // control 0b0111: three literals, then one reference (offset 2, length 3) which gives back the three
  assert.equal(lz('\x07abc\x00\x40'), 'abcabc');
  // a reference longer than what lies behind it is cut short, not repeated
  assert.equal(lz('\x01a\x00\x20').length, 2);
});

test('addLE adds a number to a byte string, least significant byte first, and stops at the end', () => {
  assert.equal(addLE('\xff\x00\x00', 1), '\x00\x01\x00');
  assert.equal(addLE('\xff\xff', 1), '\x00\x00');
  assert.equal(addLE('\x01', 300), '\x2d');
});

// ---- the optimiser --------------------------------------------------------------------------------------------------------------

test('a call that fills several targets keeps them: the ones the call supplies are not nil', () => {
  const blocks = new Map([['a', blk('a, b = f()\nx = b', { kind: 'return', values: stmts('return x')[0].values })]]);
  optimizeCfg(blocks, 'a', { exitLive: new Set() });
  assert.equal(show(blocks, 'a'), 'a, b = f()\nx = b');
});

test('pureCalls: a call over constants is evaluated, one over unknowns is left', () => {
  const blocks = new Map([['a', { stmts: stmts('k = "ab"\ny = h(k)\nz = h(w)'), term: { kind: 'return', values: stmts('return y, z')[0].values } }]]);
  optimizeCfg(blocks, 'a', { pureCalls: new Map([['h', (s) => s.toUpperCase()]]) });
  assert.equal(show(blocks, 'a'), 'z = h(w)');
  assert.equal(text([{ type: 'Return', values: blocks.get('a').term.values }]), 'return "AB", z');
});

test('effectFree: a dead call to such a function goes, a dead call to any other stays', () => {
  const blocks = new Map([['a', blk('p = upref(1)\nq = other(1)')]]);
  optimizeCfg(blocks, 'a', { exitLive: new Set(), effectFree: new Set(['upref']) });
  assert.equal(show(blocks, 'a'), 'q = other(1)');
});

test('an assignment of a name to itself is dropped', () => {
  const blocks = new Map([['a', blk('r3 = r3\nr4, r5 = r4, r5\nx = 1', { kind: 'return', values: stmts('return x')[0].values })]]);
  optimizeCfg(blocks, 'a', { exitLive: new Set() });
  assert.equal(show(blocks, 'a'), '');
});

test('a test on a value whose kind is known is decided: arithmetic is a number, and a number is true', () => {
  const blocks = new Map([
    ['a', { stmts: [], term: { kind: 'branch', cond: stmts('x = zb - 3')[0].values[0], t: 'y', f: 'n' } }],
    ['y', { stmts: stmts('r = 1'), term: { kind: 'return', values: stmts('return r')[0].values } }],
    ['n', { stmts: stmts('r = 2'), term: { kind: 'return', values: stmts('return r')[0].values } }],
  ]);
  const { entry } = optimizeCfg(blocks, 'a', { exitLive: new Set() });
  assert.ok(!blocks.has('n'));
  assert.equal(String(entry), 'y');
  assert.equal(String(blocks.get('y').term.values[0].value ?? ''), '1');
});

// ---- idioms -----------------------------------------------------------------------------------------------------------------------

test('a call whose results run into the next instruction is written as nested calls', () => {
  // t = pack(g(x)); La = t; t = La.n; zb = t + 3; move into registers 4..; then the next instruction reads registers 4 to the top
  const blocks = new Map([['a', blk([
    't = table.pack(g(x))', 'La = t', 't = La.n', 'zb = t + 3', 'table_move(La, 1, t, 4, M)',
    'r3 = f(RANGE(M, 4, zb))',
  ].join('\n'), { kind: 'return', values: stmts('return r3')[0].values })]]);
  assert.equal(openRuns(blocks), 1);
  for (let round = 0; round < 3; round++) {
    copyPropagate(blocks);
    optimizeCfg(blocks, 'a', { exitLive: new Set() });
    inlineTemps(blocks, liveness(blocks, new Set()));
    optimizeCfg(blocks, 'a', { exitLive: new Set() });
  }
  assert.equal(show(blocks, 'a'), 'r3 = f(g(x))');
});

test('an open argument list that starts before the run keeps the fixed registers in front', () => {
  const blocks = new Map([['a', blk(['t = table.pack(tostring(id))', 'La = t', 't = La.n', 'zb = t + 4', 'table_move(La, 1, t, 5, M)', 'r3 = fmt(RANGE(M, 4, zb))'].join('\n'), { kind: 'return', values: stmts('return r3')[0].values })]]);
  assert.equal(openRuns(blocks), 1);
  const out = show(blocks, 'a');
  assert.match(out, /r3 = fmt\(r4, table\.unpack\(La\)\)/);
  assert.doesNotMatch(out, /table_move/);
});

test('a pack that is never read is the call it was made from, and one that is read twice is left alone', () => {
  const a = new Map([['a', blk('t = table.pack(g(x))\ny = 1')]]);
  assert.equal(inlineTemps(a, new Map()), 1);
  assert.equal(show(a, 'a'), 'g(x)\ny = 1');
  const b = new Map([['a', { stmts: stmts('t = table.pack(g(x))\nu = table.unpack(t)\nw = table.unpack(t)'), term: { kind: 'return', values: stmts('return u, w')[0].values } }]]);
  assert.equal(inlineTemps(b, new Map()), 0);
});

test('table.unpack(table.pack(a, b)) is a, b where several values are wanted', () => {
  const blocks = new Map([['a', blk('r = f(table.unpack(table.pack(a, g(b))))\ns = table.unpack(table.pack(a, b))')]]);
  assert.equal(unpackPack(blocks), 2);
  assert.equal(show(blocks, 'a'), 'r = f(a, g(b))\ns = a');
});

test('a register read once folds into the expression that reads it; a call goes in only when nothing in between can interfere', () => {
  const blocks = new Map([['a', { stmts: stmts('r4 = r2["GetChildren"]\nr3 = r4(r2)\nuse(r3)'), term: { kind: 'exit' } }]]);
  assert.ok(forwardSubstitute(blocks, new Map()) >= 1);
  methodSugar(blocks);
  assert.equal(show(blocks, 'a'), 'use((r2:GetChildren()))');
  // a call between the definition and the use may change what the definition read
  const unsafe = new Map([['a', { stmts: stmts('r4 = t.x\nother()\nr3 = r4 + 1'), term: { kind: 'return', values: stmts('return r3')[0].values } }]]);
  forwardSubstitute(unsafe, new Map());
  assert.equal(show(unsafe, 'a'), 'r4 = t.x\nother()');
  assert.equal(text([{ type: 'Return', values: unsafe.get('a').term.values }]), 'return r4 + 1');
});

test('a call substituted where several values would be taken keeps its parentheses unless it gives one value', () => {
  const blocks = new Map([['a', { stmts: stmts('r4 = g(x)\nr5 = h(1, r4)\nr6 = o:FindFirstChild("n")\nr7 = h(1, r6)\nuse(r5, r7)'), term: { kind: 'exit' } }]]);
  forwardSubstitute(blocks, new Map());
  // the earlier call is not moved past the later one (both do something); a call that gives one value needs no parentheses
  assert.equal(show(blocks, 'a'), 'r5 = h(1, (g(x)))\nuse(r5, (h(1, o:FindFirstChild("n"))))');
  const one = new Map([['a', { stmts: stmts('r6 = o:FindFirstChild("n")\nuse(1, r6)'), term: { kind: 'exit' } }]]);
  forwardSubstitute(one, new Map());
  assert.equal(show(one, 'a'), 'use(1, o:FindFirstChild("n"))');
});

test('a variable a closure captures is not folded away', () => {
  const blocks = new Map([['a', { stmts: stmts('r4 = g(x)\nr5 = CLOSURE(C, { ref(r4) })\nuse(r5)'), term: { kind: 'exit' } }]]);
  forwardSubstitute(blocks, new Map());
  assert.match(show(blocks, 'a'), /^r4 = g\(x\)\n/);
});

test('X = A; if X then X = B end is A and B; with not it is A or B', () => {
  const g = (cond, assignAtTrue) => new Map([
    ['a', { stmts: stmts('x = f()'), term: { kind: 'branch', cond: stmts(`z = ${cond}`)[0].values[0], t: assignAtTrue ? 'b' : 'j', f: assignAtTrue ? 'j' : 'b' } }],
    ['b', { stmts: stmts('x = g()'), term: { kind: 'goto', to: 'j' } }],
    ['j', { stmts: [], term: { kind: 'return', values: stmts('return x')[0].values } }],
  ]);
  const and = g('x', true);
  assert.equal(shortCircuit(and), 1);
  assert.equal(show(and, 'a'), 'x = f() and g()');
  const or = g('x', false);
  assert.equal(shortCircuit(or), 1);
  assert.equal(show(or, 'a'), 'x = f() or g()');
});

test('the hashed type test becomes a comparison with the name', () => {
  const seed = 102239;
  const mul = 19;
  let h = 0;
  [...'table'].forEach((ch, i) => { h = i === 0 ? (seed + ch.charCodeAt(0)) >>> 0 : (Math.imul(h, mul) + ch.charCodeAt(0)) >>> 0; });
  const blocks = new Map([
    ['A', { stmts: stmts('ib = type(r3)\nCb = gmatch(ib, ".")\nCb = iter(Cb, nil, nil)\nR = Cb(nil, nil)'), term: { kind: 'branch', cond: stmts('z = R == nil')[0].values[0], t: 'other', f: 'B' } }],
    ['B', { stmts: stmts(`ja = byte(R)\nvb = band(${seed} + ja, 4294967295)\nd = vb\nR = Cb(nil, R)`), term: { kind: 'branch', cond: stmts('z = R == nil')[0].values[0], t: 'D', f: 'C' } }],
    ['C', { stmts: stmts(`ja = byte(R)\nvb = band(d * ${mul} + ja, 4294967295)\nd = vb\nR = Cb(nil, R)`), term: { kind: 'branch', cond: stmts('z = R ~= nil')[0].values[0], t: 'C', f: 'D' } }],
    ['D', { stmts: [], term: { kind: 'branch', cond: stmts(`z = not (vb ~= ${h})`)[0].values[0], t: 'same', f: 'other' } }],
    ['same', { stmts: stmts('hit = 1'), term: { kind: 'exit' } }],
    ['other', { stmts: stmts('hit = 0'), term: { kind: 'exit' } }],
  ]);
  assert.equal(typeHashTests(blocks), 1);
  const a = blocks.get('A');
  assert.equal(text(a.stmts), 'ib = type(r3)');
  assert.equal(a.term.t, 'same');
  assert.equal(a.term.f, 'other');
  assert.equal(text([{ type: 'CallStmt', call: { type: 'Call', fn: { type: 'Name', name: 'c' }, args: [a.term.cond], sugar: null } }]), 'c(ib == "table")');
});

// ---- loops and declarations -----------------------------------------------------------------------------------------------------

test('the lifted generic-for becomes for ... in, with the call that produced the iterator folded in', () => {
  const loop = text(forIn(stmts([
    'r3, r4, r5 = ipairs(list)', 'r3, r4, r5 = forgprep(r3, r4, r5)', 'r6, r7 = r3(r4, r5)',
    'while true do', '  r5 = r6', '  if r6 == nil then break end', '  use(r7)', '  r6, r7 = r3(r4, r5)', 'end',
  ].join('\n'))));
  assert.equal(loop, 'for r6, r7 in ipairs(list) do\n  use(r7)\nend');
});

test('the same loop with its first test in front is recognised too', () => {
  const loop = text(forIn(stmts([
    'r3, r4, r5 = pairs(t)', 'r3, r4, r5 = forgprep(r3, r4, r5)', 'r6, r7 = r3(r4, r5)', 'r5 = r6',
    'if not (r6 == nil) then', '  while true do', '    use(r7)', '    r6, r7 = r3(r4, r5)', '    r5 = r6', '    if r6 == nil then break end', '  end', 'end',
  ].join('\n'))));
  assert.equal(loop, 'for r6, r7 in pairs(t) do\n  use(r7)\nend');
});

test('a loop that ends in a return, with a break that returns too, is a for loop followed by that return', () => {
  const out = text(forIn(stmts([
    'r9, r10, r11 = ipairs(list)', 'r9, r10, r11 = forgprep(r9, r10, r11)', 'r12, r13 = r9(r10, r11)', 'r11 = r12',
    'if not (r12 == nil) then', '  while true do', '    if r13.n == k then break end', '    r12, r13 = r9(r10, r11)', '    r11 = r12', '    if r12 == nil then return false end', '  end', '  return true', 'end', 'return false',
  ].join('\n'))));
  assert.equal(out, 'for r12, r13 in ipairs(list) do\n  if r13.n == k then\n    return true\n  end\nend\n\nreturn false');
});

test('the returning loop inside an if is recognised when the return it matches follows the if', () => {
  const out = text(forIn(stmts([
    'if ok then', '  r9, r10, r11 = ipairs(list)', '  r9, r10, r11 = forgprep(r9, r10, r11)', '  r12, r13 = r9(r10, r11)', '  r11 = r12',
    '  if not (r12 == nil) then', '    while true do', '      if r13.n == k then break end', '      r12, r13 = r9(r10, r11)', '      r11 = r12', '      if r12 == nil then return false end', '    end', '    return true', '  end', 'end', 'return false',
  ].join('\n'))));
  assert.equal(out, 'if ok then\n  for r12, r13 in ipairs(list) do\n    if r13.n == k then\n      return true\n    end\n  end\nend\n\nreturn false');
  // a different return after the if is not the one the loop's exit leads to
  const kept = text(forIn(stmts([
    'if ok then', '  r9, r10, r11 = ipairs(list)', '  r9, r10, r11 = forgprep(r9, r10, r11)', '  r12, r13 = r9(r10, r11)', '  r11 = r12',
    '  if not (r12 == nil) then', '    while true do', '      if r13.n == k then break end', '      r12, r13 = r9(r10, r11)', '      r11 = r12', '      if r12 == nil then return false end', '    end', '    return true', '  end', 'end', 'return 1',
  ].join('\n'))));
  assert.match(kept, /forgprep/);
});

test('a loop whose body touches the iterator registers stays as it is', () => {
  const src = ['r3, r4, r5 = ipairs(list)', 'r3, r4, r5 = forgprep(r3, r4, r5)', 'r6, r7 = r3(r4, r5)', 'while true do', '  r5 = r6', '  if r6 == nil then break end', '  r3 = nil', '  r6, r7 = r3(r4, r5)', 'end'].join('\n');
  assert.match(text(forIn(stmts(src))), /forgprep/);
});

test('variables are declared where they first appear, and a list of the ones that first appear inside a block', () => {
  const out = text(declareLocals(stmts('r2 = 1\nif r2 then\n  r3 = 2\nend\nr4 = r3'), 'r', ['r1']));
  assert.equal(out, 'local r3\nlocal r2 = 1\n\nif r2 then\n  r3 = 2\nend\n\nlocal r4 = r3');
});

test('a string key that is a name is written with a dot', () => {
  assert.equal(text(dotKeys(stmts('x = t["insert"]\ny = t["not a name"]\nz = t["end"]'))), 'x = t.insert\ny = t["not a name"]\nz = t["end"]');
});
