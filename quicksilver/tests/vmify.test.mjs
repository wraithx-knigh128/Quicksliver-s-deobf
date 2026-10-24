// Prometheus Vmify, tested against output of the real tool (tests/corpus/tools/gen_prometheus.py).
//
// The strongest check available is behavioural: the program the pipeline writes has to print on a real Lua 5.1 what the
// obfuscated script printed. On top of that the dispatcher has to be gone (a second run of the unflattener finds nothing to
// do), and the strings that the original program contains have to be back in the text.
//
// Two of the checks call for a note. The obfuscated script, not the original, is the reference: Prometheus itself drops the
// parentheses of `print((s:gsub(...)))` (s03), so the original and its obfuscation already disagree there. And the strong
// preset applies Vmify twice and encrypts the strings in between, so those scripts exercise the second layer as well.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from '../src/core/parser.js';
import { recover } from '../src/recover/pipeline.js';
import { unflattenVmify } from '../src/recover/vmify.js';
import { placeDeclarations } from '../src/recover/decls.js';
import { print } from '../src/core/printer.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';
after(() => oracle.stopOracle());

const read = (p) => fs.readFileSync(p).toString('latin1');
const original = (name) => read(path.join(corpus, 'originals', name));

const jobs = [];
for (const dir of ['prometheus', 'prometheus-seeds']) {
  const manifest = JSON.parse(fs.readFileSync(path.join(corpus, 'obfuscated', dir, 'manifest.json'), 'utf8'));
  for (const e of manifest.entries) {
    if (e.status === 'ok' && ['step-Vmify', 'Medium', 'Strong'].includes(e.config)) jobs.push({ dir, ...e });
  }
}

/** The string literals of a program that are long enough to be recognisable. */
const literals = (src) => [...src.matchAll(/"((?:[^"\\\n]|\\.){6,})"/g)].map((m) => m[1]).filter((s) => /[A-Za-z]{4}/.test(s));

for (const job of jobs) {
  test(`${job.dir}/${job.file}: unflattened, readable and still the same program`, { skip }, async () => {
    const src = read(path.join(corpus, 'obfuscated', job.dir, job.file));
    const expected = await oracle.runLua(src, 'lua51');
    assert.ok(expected.ok, `the obfuscated script does not run: ${expected.error}`);

    const r = recover(src, { sandbox: { enabled: true } });
    assert.equal(r.ok, true, JSON.stringify(r.warnings));
    const step = r.steps.find((s) => s.id === 'prometheus.vmify');
    assert.equal(step && step.status, 'applied', step && (step.error || step.detail));
    assert.doesNotThrow(() => parse(r.output), 'recovered source does not parse');

    const got = await oracle.runLua(r.output, 'lua51');
    assert.ok(got.ok, `recovered source failed (${got.error}):\n${r.output.slice(0, 500)}`);
    assert.equal(got.stdout, expected.stdout, 'the recovered source prints something else');

    // nothing of the machine is left: another pass over the result finds no Vmify script
    const again = unflattenVmify(parse(r.output));
    assert.ok(again.skipped, 'the recovered source still contains a flattened script');
    assert.ok(!/Tamper Detected/.test(r.output), 'the anti-tamper check is still in the output');

    // and the program is back: its own text shows through
    const want = literals(original(job.sample));
    const present = want.filter((s) => r.output.includes(s));
    assert.ok(want.length === 0 || present.length / want.length >= 0.6, `only ${present.length} of ${want.length} string literals of the original are back`);
  });
}

// ---- the pieces -----------------------------------------------------------------------------------------------------

test('declarations go where a variable first appears, and inside a branch when only that branch uses it', () => {
  const ast = parse('a = 1\nif c then\n  b = a + 1\n  d = b\nend\nprint(a)');
  placeDeclarations(ast.body, ['a', 'b', 'd']);
  assert.equal(print(ast).trim(), 'local a = 1\n\nif c then\n  local b = a + 1\n  local d = b\nend\n\nprint(a)');
});

test('a loop body only gets a declaration for a variable it writes before it reads', () => {
  const carried = parse('while go do\n  n = (n or 0) + 1\nend');
  placeDeclarations(carried.body, ['n']);
  assert.match(print(carried), /^local n\n/, 'a counter that survives from one pass to the next stays outside the loop');
  const fresh = parse('while go do\n  t = f()\n  g(t)\nend');
  placeDeclarations(fresh.body, ['t']);
  assert.match(print(fresh), /while go do\n  local t = f\(\)/, 'a temporary written first is declared inside');
});
