// Prompt XII: the general capabilities that the Zartha and XFuscator work needed, tested on their own.
//
//   * constants.inline: a table of constants that is only read with constant keys is those constants (XFuscator keeps every constant of the program in one);
//   * the decompiler: a global or a method whose name is not an identifier, an open call chain inside a condition, and the results of a call nothing has named (a stripped chunk has no
//     local names to say `local _, e = pcall(f)`).

import test from 'node:test';
import assert from 'node:assert/strict';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { inlineConstantTable } from '../src/passes/strtable.js';
import { dumpChunk51, parseChunk } from '../src/sandbox/bytecode.js';
import { encode } from '../src/recover/ironbrew.js';
import { decompile } from '../src/decompile/decompile.js';

const run = (src) => { const ast = parse(src); const r = inlineConstantTable(ast); return { out: print(ast), changed: r.changed }; };

test('constants.inline: a machine-named or key-by-key table of constants that is only read is the constants', () => {
  const a = run('local zJSS = { [1] = nil, [2] = 2, [3] = "x", [4] = false, [5] = 0 } print(zJSS[3], zJSS[1], zJSS[2] + zJSS[5])');
  assert.ok(a.changed > 0);
  assert.doesNotMatch(a.out, /zJSS/);
  assert.match(a.out, /print\("x", nil, 2 \+ 0\)/);
});

test('constants.inline: a table that is written, indexed by a computed key, passed on, or written the way people write lists is left alone', () => {
  for (const src of [
    'local zJSS = { [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5 } zJSS[2] = 9 print(zJSS[2])',
    'local zJSS = { [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5 } for i = 1, 3 do print(zJSS[i]) end',
    'local zJSS = { [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5 } print(zJSS, zJSS[1])',
    'local names = { "a", "b", "c", "d", "e" } print(names[2])',
    'local config = { 1, 2, 3 } print(config[1])',
  ]) assert.equal(run(src).changed, 0, src);
});

const fn = (code, k, extra = {}) => ({ source: null, line: 0, lastLine: 0, nups: 0, numParams: 0, isVararg: false, maxStack: 6, code: Uint32Array.from(code.map(encode)), k, protos: [], lines: [], locals: [], upNames: [], ...extra });
const decompileFn = (f) => print(decompile(parseChunk(dumpChunk51({ main: f, header: { little: true, intSize: 4, sizeT: 8, numSize: 8 } }, { strip: true }))).ast);

test('decompiler: a global whose name is not an identifier is a field of _G, and a method whose name is not an identifier is a call with the object first', () => {
  const g = decompileFn(fn([{ op: 'GetGlobal', a: 0, b: 0, c: 0 }, { op: 'Call', a: 0, b: 1, c: 1 }, { op: 'Return', a: 0, b: 1, c: 0 }], ['a b']));
  assert.match(g, /_G\["a b"\]\(\)/);
  const m = decompileFn(fn([{ op: 'Self', a: 1, b: 0, c: 256 }, { op: 'Call', a: 1, b: 2, c: 1 }, { op: 'Return', a: 0, b: 1, c: 0 }], ['x y'], { numParams: 1 }));
  assert.match(m, /a1\["x y"\]\(a1\)/);
});

test('decompiler: the results of a call that nothing named are written out before a condition that follows, and an open call chain inside the condition is part of it', () => {
  // local _, e = pcall(f); if e or tonumber(g()) > 4 then return 1 end   (no debug names: neither `_` nor `e` has a local)
  const code = [
    { op: 'GetGlobal', a: 0, b: 0, c: 0 }, { op: 'Call', a: 0, b: 1, c: 3 },
    { op: 'Test', a: 1, b: 0, c: 0 }, { op: 'Jmp', a: 0, b: 6, c: 0 },
    { op: 'GetGlobal', a: 2, b: 1, c: 0 }, { op: 'GetGlobal', a: 3, b: 2, c: 0 }, { op: 'Call', a: 3, b: 1, c: 0 }, { op: 'Call', a: 2, b: 0, c: 2 },
    { op: 'Lt', a: 0, b: 257, c: 2 }, { op: 'Jmp', a: 0, b: 1, c: 0 },
    { op: 'LoadConst', a: 2, b: 3, c: 0 }, { op: 'Return', a: 2, b: 2, c: 0 }, { op: 'Return', a: 0, b: 1, c: 0 },
  ];
  const out = decompileFn(fn(code, ['pcall', 'tonumber', 'g', 1]));
  assert.doesNotMatch(out, /could not be decompiled/);
  assert.match(out, /pcall\(\)/);
  assert.match(out, /tonumber\(g\(\)\)/);
});
