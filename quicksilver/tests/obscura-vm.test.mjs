// Prompt XI: Obscura's virtual machine lifted back to source. The handlers the script carries say what each opcode of the build does; nothing is a table of opcode numbers.
//
// The committed MIT fixtures are the evidence (tests/corpus/obfuscated/obscura-1.0.1 and -1.1.0, `vm` mode). Where the tool's own output does not behave like the original program
// (four of the six 1.0.1 programs; the manifests say which) the lifted program is not expected to either, and those are not judged.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from '../src/core/parser.js';
import { bytesToBinary } from '../src/core/bytes.js';
import { fidelity } from '../src/core/fidelity.js';
import { structureScore, residualIndicators } from '../src/core/metrics.js';
import { recover } from '../src/recover/pipeline.js';
import { bodyOf } from '../src/recover/vmprofile.js';
import { findInterpreter, readFetch, readHandlers, splitHandler, canonical } from '../src/recover/obscura-vm.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const read = (p) => bytesToBinary(fs.readFileSync(p));
after(() => oracle.stopOracle?.());
const SANDBOX = { sandbox: { enabled: true } };
const dir = (v) => path.join(corpus, 'obfuscated', `obscura-${v}`);
const plain = (v) => fs.readdirSync(dir(v)).filter((f) => /__vm\.lua$/.test(f)).sort();
const original = (f) => read(path.join(corpus, 'originals', `${f.split('__')[0]}.lua`));
const toolOk = (v) => new Set(JSON.parse(fs.readFileSync(path.join(dir(v), 'manifest.json'), 'utf8')).entries.filter((e) => e.config === 'vm' && e.behavior === 'equivalent').map((e) => e.file));

test('handlers: every handler of every plain VM build is recognised, in both revisions', () => {
  let builds = 0;
  for (const v of ['1.1.0', '1.0.1']) {
    for (const f of plain(v)) {
      const body = bodyOf(parse(read(path.join(dir(v), f))));
      const it = findInterpreter(body);
      const fetch = readFetch(it.loop);
      assert.ok(fetch, `${v}/${f}: opcode fetch`);
      const { table, unknown } = readHandlers(it, fetch);
      assert.deepEqual(unknown.filter((u) => !/bad opcode/.test(u.text)), [], `${v}/${f}`);
      assert.ok(table.size >= 20, `${v}/${f}: ${table.size} opcodes`);
      builds++;
    }
  }
  assert.equal(builds, 13);
});

test('handlers: a build that stores its operands in another order writes the same canonical text, and the order is kept', () => {
  const stmts = (first, second) => parse(`
    local ${first} = d(bc[pc], K[(pc - 1) % n + 1]) + d(bc[pc + 1], K[(pc + 1 - 1) % n + 1]) * 256 pc = pc + 2
    local ${second} = d(bc[pc], K[(pc - 1) % n + 1]) + d(bc[pc + 1], K[(pc + 1 - 1) % n + 1]) * 256 pc = pc + 2
    R[a] = R[b]`).body;
  const fetch = { decoder: 'd', bytes: 'bc', pc: 'pc' };
  const one = splitHandler(stmts('a', 'b'), fetch);
  const two = splitHandler(stmts('b', 'a'), fetch);
  assert.equal(one.reads.length, 2);
  const c1 = canonical(one.rest, one.reads);
  const c2 = canonical(two.rest, two.reads);
  assert.equal(c1.text, c2.text);
  assert.deepEqual(c1.order, [0, 1]);       // a is stored first, then b
  assert.deepEqual(c2.order, [1, 0]);       // b is stored first: the first operand USED is the second stored
});

test('handlers: a body no template matches is reported with its text, and a program that uses it is not guessed at', () => {
  const file = path.join(dir('1.1.0'), 's01_minify_basic__vm.lua');
  const src = read(file);
  // MOVE writes one more thing: not a handler this reader knows
  const broken = src.replace('_0xa2881a[_mwlvnray]=_0xa2881a[_0xcce0] elseif', '_0xa2881a[_mwlvnray]=_0xa2881a[_0xcce0] print(1) elseif');
  assert.notEqual(broken, src);
  const r = recover(broken, SANDBOX);
  const step = r.steps.find((s) => s.id === 'obscura.vm');
  assert.equal(step.status, 'skipped');
  assert.match(step.detail, /no handler this reader recognises/);
  assert.ok(r.vm && !r.vm.lifted, 'the profile is still reported, as not lifted');
});

for (const v of ['1.1.0', '1.0.1']) {
  test(`obscura ${v}: plain VM builds are lifted back to source; where the tool's own output is right, the program behaves like the original`, async (t) => {
    const good = toolOk(v);
    let judged = 0;
    for (const f of plain(v)) {
      const src = read(path.join(dir(v), f));
      const r = recover(src, SANDBOX);
      const step = r.steps.find((s) => s.id === 'obscura.vm');
      assert.equal(step.status, 'applied', `${f}: ${step.detail}`);
      assert.ok(r.vm.lifted, f);
      assert.deepEqual(residualIndicators(r.output), [], `${f}: nothing of the VM is left`);
      assert.equal(r.report.unresolved.length, 0, f);
      assert.equal(r.confidence.level, 'high', f);
      const orig = original(f);
      assert.ok(structureScore(orig, r.output) >= 0.9, `${f}: structure ${structureScore(orig, r.output)}`);
      assert.ok(fidelity(orig, r.output).score >= 0.7, `${f}: fidelity ${fidelity(orig, r.output).score}`);
      if (!good.has(f) || !oracle.available) continue;
      const want = await oracle.runLua(orig, 'luau');
      const got = await oracle.runLua(r.output, 'luau');
      assert.equal(got.ok, want.ok, `${f}: ${got.error}`);
      assert.equal(got.stdout, want.stdout, f);
      judged++;
    }
    if (oracle.available) assert.ok(judged >= (v === '1.1.0' ? 7 : 2), `${judged} judged`);
  });
}

test('obscura: the hardened builds (keyed constants, shuffled operand layouts, a tree of range tests) are still profiled and not lifted, and the report says so', () => {
  const r = recover(read(path.join(dir('1.1.0'), 's01_minify_basic__vm-max.lua')), SANDBOX);
  const step = r.steps.find((s) => s.id === 'obscura.vm');
  assert.ok(!step || step.status !== 'applied');
  assert.ok(r.vm && !r.vm.lifted);
  assert.match(r.output, /NOT lifted back to source/);
});

test('obscura: the report of a lifted program says what was done, and a second recovery of it is unchanged in kind', () => {
  const r = recover(read(path.join(dir('1.1.0'), 's05_nested_functions__vm.lua')), SANDBOX);
  assert.match(r.output.replace(/\n--\s+/g, ' '), /lifted back to source from its bytecode \(16 functions/);
  const again = recover(r.output, SANDBOX);
  assert.equal(again.vm, null);
  assert.ok(again.ok);
});
