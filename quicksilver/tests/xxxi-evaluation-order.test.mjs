// Prompt XXXI (KNOWN-ISSUES #114): the decompiler keeps how often and in which order a program evaluates what its conditions test.
// Random statements (tests/helpers/decompile-props.mjs evaluationCase) are compiled by reference Lua 5.1, with and without debug
// information, decompiled, and run next to the original through proxies that log every field read and call. Skipped without
// QS_LUA_PYTHON.
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import * as oracle from './helpers/lua-oracle.mjs';
import { parseChunk, dumpChunk51 } from '../src/sandbox/bytecode.js';
import { decompile } from '../src/decompile/decompile.js';
import { print } from '../src/core/printer.js';
import { parse } from '../src/core/parser.js';
import { quoteString } from '../src/core/printer.js';
import { rng, evaluationCase, evaluationHarness, sharedSubtrees } from './helpers/decompile-props.mjs';

after(() => oracle.stopOracle());
const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';

async function compile(src, strip) {
  const r = await oracle.runLua(`local f = assert(loadstring(${quoteString(src)}))\nlocal d = string.dump(f)\nprint((d:gsub('.', function(c) return string.format('%02x', c:byte()) end)))`, 'lua51');
  assert.ok(r.ok, `reference Lua could not compile a generated case: ${r.error}\n${src}`);
  const bc = r.stdout.trim().replace(/../g, (h) => String.fromCharCode(parseInt(h, 16)));
  return strip ? dumpChunk51(parseChunk(bc), { strip: true }) : bc;
}

async function decompiledLog(src, strip) {
  const d = decompile(parseChunk(await compile(src, strip)));
  const text = print(d.ast);
  return { d, text };
}

test('#114 reduced: `x = t.a or x` reads t.a once', { skip }, async () => {
  const src = 'local t, u, k, x, n, c = ...\nx = t.a or x\nreturn x, n';
  for (const strip of [true, false]) {
    const { d, text } = await decompiledLog(src, strip);
    assert.equal(d.failures.length, 0);
    assert.equal((text.match(/\.a\b/g) || []).length, 1, text);
    const [a, b] = [await oracle.runLua(evaluationHarness(quoteString(src)), 'lua51'), await oracle.runLua(evaluationHarness(quoteString(text)), 'lua51')];
    assert.equal(b.stdout, a.stdout);
  }
});

for (const [seed, strip] of [[3, true], [3, false], [17, true], [17, false]]) {
  test(`#114 property: 120 random value-condition statements (seed ${seed}, ${strip ? 'stripped' : 'with debug information'}) read and call exactly what the original does, in its order`, { skip, timeout: 600_000 }, async () => {
    const lcg = rng(seed);
    const rnd = (k) => Math.floor((lcg(2 ** 30) / 2 ** 30) * k);
    const different = [];
    let undecompiled = 0;
    for (let n = 0; n < 120; n++) {
      const src = evaluationCase(rnd);
      const { d, text } = await decompiledLog(src, strip);
      assert.equal(sharedSubtrees(d.ast), 0, `the decompiled tree shares subtrees (so writes an expression twice):\n${src}\n---\n${text}`);
      if (d.failures.length) { undecompiled++; continue; }
      assert.doesNotThrow(() => parse(text), text);
      const [a, b] = [await oracle.runLua(evaluationHarness(quoteString(src)), 'lua51'), await oracle.runLua(evaluationHarness(quoteString(text)), 'lua51')];
      if (!(a.ok && b.ok && a.stdout === b.stdout)) different.push({ src, text, expected: (a.stdout || a.error).slice(0, 400), got: (b.stdout || b.error).slice(0, 400) });
    }
    assert.equal(different.length, 0, JSON.stringify(different.slice(0, 2), null, 1));
    assert.ok(undecompiled <= 6, `${undecompiled} of 120 were not decompiled`);
  });
}
