// Prometheus as of November 2026 (upstream a98c501): its old Vmify compiler is now the `Cff` step, and `Vmify` is a register
// bytecode VM. Weak = Cff; Medium = Vmify + strings + AntiTamper + Cff around the interpreter; Strong = the same with the
// interpreter itself flattened. Every committed build has to come back as a program that runs like the original.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { recover } from '../src/recover/pipeline.js';
import { classify } from '../src/recover/prometheus-bvm.js';
import { removeSanityCheck } from '../src/recover/prometheus.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const dir = path.join(corpus, 'obfuscated/prometheus-2026-11');
const read = (p) => bytesToBinary(fs.readFileSync(p));
const run = (src) => recover(src, { sandbox: { enabled: true } });
const noOracle = !oracle.available && 'no Lua oracle (QS_LUA_PYTHON)';
after(() => oracle.stopOracle?.());

const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));

for (const e of manifest.entries.filter((x) => x.status === 'ok')) {
  test(`prometheus 2026-11 ${e.file}: recovered without its dispatcher or VM and runs as the original`, { skip: noOracle }, async () => {
    const src = read(path.join(dir, e.file));
    const r = run(src);
    const vmify = r.steps.find((x) => x.id === 'prometheus.vmify');
    assert.equal(vmify && vmify.status, 'applied', 'the Cff layer is lifted');
    if (e.config !== 'Weak') {
      const bvm = r.steps.find((x) => x.id === 'prometheus.bvm');
      assert.equal(bvm && bvm.status, 'applied', 'the register VM is lifted');
      assert.ok(!/__PROTOTYPES__|unknown VM opcode/.test(r.output), 'no interpreter is left');
    }
    const original = fs.readFileSync(path.join(corpus, 'originals', e.sample), 'latin1');
    const want = await oracle.runLua(original, 'lua51');
    const got = await oracle.runLua(r.output, 'lua51');
    assert.ok(got.ok, got.error);
    assert.equal(got.stdout, want.stdout);
  });
}

test('prometheus vm: handlers are told apart by what they do, whatever the build named its variables', () => {
  assert.equal(classify('R[a] = K[b]'), 'LOAD');
  assert.equal(classify('R[a] = { R[b] }'), 'CELL');
  assert.equal(classify('T1 = R[b] R[a] = { T1 }'), 'CELL');
  assert.equal(classify('R[a] = R[b] .. R[c]'), 'CONCAT');
  assert.equal(classify('local T1 = R[a] R[a] = nil if not T1 then pc = b end'), 'JFALSE');
  assert.equal(classify('T1 = R[a] return X1(T1, 1, T1[#])'), 'RETURN');
  assert.equal(classify('T1 = R[a] T2 = R[b] if getfenv and (T1 == getfenv and (T2[#] == 0)) then return E end return T1(X1(T2, 1, T2[#]))'), 'TAILCALL');
  assert.equal(classify('T1 = R[a] if getfenv and T1 == getfenv then return E end return T1()'), 'TAILCALL0');
  // CLEARS as the flattener leaves it: a lowered loop
  assert.equal(classify('local T1 = tonumber(#a) or error("x") local T2 = 0 while true do T2 = 1 + T2 if not (T2 <= T1) then break end R[a[T2]] = nil end'), 'CLEARS');
  // something the VM does not do is not given a meaning
  assert.equal(classify('R[a] = R[b] + R[c] + 1'), null);
});

test('prometheus vm: the sanity loop AntiTamper leaves in front of its guard goes once nothing else reads its variable', () => {
  const ast = parse('local v = "abc"\nfor i = 0, 3 do\n  if i == 0 then\n    if v ~= "abc" then while true do end end\n    v = true\n  elseif i == 2 then\n    v = false\n  end\nend\nprint("ok")\n');
  assert.equal(removeSanityCheck(ast).changed, 2);
  assert.equal(print(ast).trim(), 'print("ok")');
  // the same shape whose variable is used afterwards stays
  const kept = parse('local v = "abc"\nfor i = 0, 3 do\n  if v ~= "abc" then while true do end end\nend\nprint(v)\n');
  assert.equal(removeSanityCheck(kept).changed, 0);
});

test('simplify: `local f ... function f() end` keeps its declaration while f is used, and both go when it is not', () => {
  const used = run('local Q, t\ndo\n  local O = {}\n  function Q(a, b)\n    O[b] = a\n    return b\n  end\nend\nprint(Q(1, 2))\n').output;
  const fn = /^function (\w+)\(/m.exec(used);
  assert.ok(fn, 'the function statement is kept');
  assert.match(used, new RegExp(`^local ${fn[1]}\\s*$`, 'm'), 'and so is the declaration that makes it local');
  const unused = run('local Q, t\ndo\n  local O = {}\n  t = setmetatable({}, { __index = O })\n  function Q(a, b)\n    O[b] = a\n    return b\n  end\nend\nprint("x")\n').output.replace(/^--.*\n/gm, '');
  assert.doesNotMatch(unused, /function/, 'no global function is left behind');
});
