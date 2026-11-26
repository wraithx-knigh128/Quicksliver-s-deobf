// Property tests of the bytecode decompiler against reference Lua 5.1 (Prompt XXX). Random programs (tests/helpers/decompile-props.mjs)
// are compiled, stripped, decompiled and run next to the original on the same inputs. The invariant that must never break: a function
// the decompiler reconstructs behaves exactly like the original. The share it can reconstruct at all is recorded as a floor, measured
// when these tests were written, so that a change that loses coverage is seen; raising coverage is welcome, lowering it is a regression.
// Needs the reference runtime (QS_LUA_PYTHON); skipped otherwise, like tests/decompile.test.mjs.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { quoteString, print } from '../src/core/printer.js';
import { parse } from '../src/core/parser.js';
import { parseChunk, dumpChunk51 } from '../src/sandbox/bytecode.js';
import { decompile } from '../src/decompile/decompile.js';
import * as oracle from './helpers/lua-oracle.mjs';
import { rng, expressionCase, expressionHarness, statementCase, statementHarness } from './helpers/decompile-props.mjs';

after(() => oracle.stopOracle());
const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';

async function compileStripped(src) {
  const r = await oracle.runLua(`local f = assert(loadstring(${quoteString(src)}))\nlocal d = string.dump(f)\nprint((d:gsub('.', function(c) return string.format('%02x', c:byte()) end)))`, 'lua51');
  assert.ok(r.ok, `reference Lua could not compile a generated case: ${r.error}\n${src}`);
  return dumpChunk51(parseChunk(r.stdout.trim().replace(/../g, (h) => String.fromCharCode(parseInt(h, 16)))), { strip: true });
}

async function run(kind, seed, count) {
  const rnd = rng(seed);
  const tally = { same: 0, different: [], undecompiled: [] };
  for (let n = 0; n < count; n++) {
    const src = kind === 'expression' ? expressionCase(rnd) : statementCase(rnd);
    const d = decompile(parseChunk(await compileStripped(src)));
    const text = print(d.ast);
    if (d.failures.length) { tally.undecompiled.push({ src, why: d.failures[0] }); continue; }
    assert.doesNotThrow(() => parse(text), `decompiled output does not parse:\n${text}`);
    const harness = kind === 'expression' ? expressionHarness : statementHarness;
    const [a, b] = [await oracle.runLua(harness(quoteString(src)), 'lua51'), await oracle.runLua(harness(quoteString(text)), 'lua51')];
    if (a.ok && b.ok && a.stdout === b.stdout) tally.same++;
    else tally.different.push({ src, text, expected: a.stdout || a.error, got: b.stdout || b.error });
  }
  return tally;
}

// [kind, seed, cases, most cases left undecompiled]: the floors are what Prompt XXX's decompiler measured. Before it (Prompt XXIX), the
// same cases gave: expression 11 — 187 identical, 1 DIFFERENT, 12 undecompiled; expression 7 — 189 / 0 / 11; statement 5 — 113 / 0 / 7;
// statement 23 — 109 / 0 / 11; statement 41 — 115 / 0 / 5.
const CASES = [
  ['expression', 11, 200, 5],
  ['expression', 7, 200, 2],
  ['statement', 5, 120, 0],
  ['statement', 23, 120, 0],
  ['statement', 41, 120, 0],
];

for (const [kind, seed, count, maxUndecompiled] of CASES) {
  test(`decompiler property: ${count} random ${kind} programs (seed ${seed}) behave like the original`, { skip, timeout: 600000 }, async () => {
    const t = await run(kind, seed, count);
    assert.equal(t.different.length, 0, `decompiled programs that behave differently:\n${JSON.stringify(t.different.slice(0, 3), null, 1)}`);
    assert.ok(t.undecompiled.length <= maxUndecompiled, `${t.undecompiled.length} of ${count} cases were not decompiled (floor ${maxUndecompiled}):\n${JSON.stringify(t.undecompiled.slice(0, 5), null, 1)}`);
  });
}
