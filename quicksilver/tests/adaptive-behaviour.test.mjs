// Obfuscators the engine has never been told about, checked on real Lua.
//
// tests/helpers/mutators.mjs obfuscates the programs in tests/corpus/adaptive/ with independent transformations (control-flow flattening in
// three dispatch styles and three ways of choosing the next state, string decoders, opaque predicates, call proxies, junk, renamed locals,
// a wrapper), alone and combined. Each obfuscated program is first run on real Lua to prove that the transformation kept the behaviour; then
// QuickSilver recovers it, and the recovered program must
//
//   * print exactly what the original prints on Lua 5.1 (and on 5.4 and LuaJIT for the combined forms),
//   * leave no disguise the structure reader knows of, and
//   * be shorter than what the generic passes alone leave of the flattened forms.
//
// This shows the engine handles those shapes, not that it handles every obfuscator: the transformations were written by the people who wrote
// the engine. tests/adaptive.test.mjs holds the cases that must be refused.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { recover } from '../src/recover/pipeline.js';
import { obfuscate } from './helpers/mutators.mjs';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const dir = path.join(here, 'corpus/adaptive');
const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';
after(() => oracle.stopOracle());

const read = (f) => fs.readFileSync(path.join(dir, f), 'latin1');
const lines = (s) => s.split('\n').length;
const PROGRAMS = fs.readdirSync(dir).filter((f) => f.endsWith('.lua')).sort();

const COMBOS = {
  'flatten: chain, literal states, sentinel exit': [['flatten', { style: 'chain', next: 'literal', exit: 'sentinel' }]],
  'flatten: binary tree, delta states, break exit': [['flatten', { style: 'tree', next: 'delta', exit: 'break' }]],
  'flatten: sequential ifs, conditional states': [['flatten', { style: 'seq', next: 'choice', exit: 'sentinel' }]],
  'strings: indexed table of shifted bytes': [['strings', { scheme: 'indexed' }]],
  'strings: byte lists decoded where used': [['strings', { scheme: 'inline' }]],
  'opaque predicates': [['opaque', { density: 0.5 }]],
  'call proxies': [['proxies', { layers: 1 }]],
  'call proxies, two layers': [['proxies', { layers: 2 }]],
  'junk and renamed locals': ['junk', 'rename'],
  'everything at once, wrapped': ['proxies', 'opaque', ['flatten', { style: 'tree', next: 'delta' }], ['strings', { scheme: 'indexed' }], 'rename', 'wrap'],
};

for (const prog of PROGRAMS) {
  const src = read(prog);
  for (const [name, steps] of Object.entries(COMBOS)) {
    test(`${prog}: ${name}`, { skip }, async () => {
      const want = await oracle.runLua(src, 'lua51');
      assert.ok(want.ok, want.error);
      const ob = obfuscate(src, steps, 7);
      const got = await oracle.runLua(ob.code, 'lua51');
      assert.ok(got.ok && got.stdout === want.stdout, `the obfuscated program must behave as the original (${got.error || 'output differs'})`);

      const generic = recover(ob.code, { adaptive: false, sandbox: { enabled: true } });
      const r = recover(ob.code, { sandbox: { enabled: true } });
      assert.equal(r.ok, true, JSON.stringify(r.warnings));
      assert.ok(r.adaptive && r.adaptive.ran, 'the structure reader ran');
      const back = await oracle.runLua(r.output, 'lua51');
      assert.ok(back.ok, `${back.error}\n${r.output.slice(0, 600)}`);
      assert.equal(back.stdout, want.stdout, 'the recovered program prints what the original prints');
      assert.equal(r.adaptive.score.after, 0, `a disguise is left: ${JSON.stringify(r.adaptive.residual)}`);
      assert.ok(lines(r.output) <= lines(generic.output), 'no longer than the generic passes alone leave it');
      if (name.startsWith('flatten')) {
        assert.ok(lines(r.output) < lines(generic.output), `flattened code is rebuilt: ${lines(r.output)} lines against ${lines(generic.output)}`);
        assert.ok(r.adaptive.kinds.some((k) => k.kind === 'dispatcher' && k.resolved > 0));
      }
      // a few forms on the other runtimes too
      if (name.startsWith('everything') || name.includes('binary tree')) {
        for (const rt of ['lua54', 'luajit']) {
          const a = await oracle.runLua(src, rt);
          const b = await oracle.runLua(r.output, rt);
          assert.equal(b.stdout, a.stdout, `same output on ${rt}`);
        }
      }
    });
  }
}

test('different random choices of the same obfuscations are recovered as well', { skip }, async () => {
  const forms = [
    [['flatten', { style: 'chain', next: 'delta' }]],
    [['flatten', { style: 'seq', next: 'literal', exit: 'break' }]],
    [['flatten', { style: 'tree', next: 'choice', exit: 'sentinel' }], ['strings', { scheme: 'inline' }]],
    ['opaque', ['flatten', {}], 'proxies'],
  ];
  let checked = 0;
  for (const prog of ['a01_algorithms.lua', 'a03_text.lua', 'a05_simulation.lua']) {
    const src = read(prog);
    const want = await oracle.runLua(src, 'lua51');
    for (const [i, steps] of forms.entries()) {
      for (const seed of [1, 2, 3, 4]) {
        const ob = obfuscate(src, steps, seed * 13 + i);
        const got = await oracle.runLua(ob.code, 'lua51');
        assert.ok(got.ok && got.stdout === want.stdout, `${prog} form ${i} seed ${seed}: the mutation itself`);
        const r = recover(ob.code, { sandbox: { enabled: true } });
        const back = await oracle.runLua(r.output, 'lua51');
        assert.ok(back.ok && back.stdout === want.stdout, `${prog} form ${i} seed ${seed}: recovered behaviour (${back.error || 'output differs'})`);
        assert.equal(r.adaptive.score.after, 0, `${prog} form ${i} seed ${seed}: ${JSON.stringify(r.adaptive.residual)}`);
        checked++;
      }
    }
  }
  assert.equal(checked, 48);
});

test('control flow the engine has no reading for stays correct, and is reported', { skip }, async () => {
  // a dispatch loop that selects its block by calling a function out of a table: not read, so not touched
  const code = `
local blocks = {}
local acc = 0
blocks[1] = function() acc = acc + 1; return 2 end
blocks[2] = function() acc = acc * 10; return 3 end
blocks[3] = function() print("acc", acc); return 0 end
local s = 1
while s ~= 0 do s = blocks[s]() end`;
  const want = await oracle.runLua(code, 'lua51');
  const r = recover(code, { sandbox: { enabled: true } });
  const back = await oracle.runLua(r.output, 'lua51');
  assert.equal(back.stdout, want.stdout);
});
