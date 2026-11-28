// Prompt XXXI: KNOWN-ISSUES #118 — the decoder evaluation (src/passes/evaluate.js) and the guard after a verified VM lift
// (src/recover/pipeline.js), each tested on its own. Behaviour is compared on reference Lua 5.1 (skipped without QS_LUA_PYTHON).
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { evaluatePass } from '../src/passes/evaluate.js';
import { recover, Run } from '../src/recover/pipeline.js';
import * as oracle from './helpers/lua-oracle.mjs';
import { rng } from './helpers/decompile-props.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
after(() => oracle.stopOracle());
const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';
const read = (p) => fs.readFileSync(p, 'latin1');

async function evaluateAndRun(src) {
  const ast = parse(src);
  const r = evaluatePass(ast, { sandbox: { enabled: true } });
  const out = print(ast, {});
  const [a, b] = [await oracle.runLua(src, 'lua51'), await oracle.runLua(out, 'lua51')];
  return { r, out, want: a, got: b };
}

const DECODER = `local K = {}
local C = {}
local function d(s, k)
  if K[k] then return K[k] end
  K[k] = ""
  local o = ""
  for i = 1, #s do o = o .. C[(s:byte(i) - k) % 256 + 1] end
  K[k] = o
  return o
end
`;

test('#118 reduced: a memoising decoder whose first call fails in the sandbox leaves its placeholder; nothing is replaced by it', { skip }, async () => {
  const { r, out, want, got } = await evaluateAndRun(read(path.join(corpus, 'regress/xxxi-memo-decoder.lua')));
  assert.equal(got.stdout, want.stdout, out);
  assert.doesNotMatch(out, /print\([^)]*""/, 'no decoder call was replaced by the placeholder');
  assert.ok(r.afterFailure > 0, 'the results after the failed call were recognised as untrustworthy');
});

test('#118, two decoders over one cache: a failure in one makes the other\'s later results untrustworthy too', { skip }, async () => {
  const { r, out, want, got } = await evaluateAndRun(read(path.join(corpus, 'regress/xxxi-shared-cache.lua')));
  assert.equal(r.decoders.length, 2, JSON.stringify(r.decoders));
  assert.equal(got.stdout, want.stdout, out);
  assert.doesNotMatch(out, /print\([^)]*""/);
});

test('#118 rerun: a site that fails (and is never run by the program) does not cost the sites after it their values', { skip }, async () => {
  // d(5, 1) fails on #s after storing the placeholder for key 1; the program never runs it. Without it the run is clean, and
  // d("tubsu", 1) decodes to "start" (Prompt XXX accepted "" for it: both orders returned the placeholder).
  const src = `${DECODER}for i = 1, 256 do C[i] = string.char(i - 1) end
local mode = 0
if mode == 99 then print(d(5, 1)) end
print(d("tubsu", 1), d("tubsu", 1))
print(d("ceegrv", 2), d("vhhq", 3), d("vhhq", 3))
`;
  const { r, out, want, got } = await evaluateAndRun(src);
  assert.equal(got.stdout, want.stdout, out);
  assert.equal(r.reruns, 1);
  assert.equal(r.evaluated, 5, out);
  assert.match(out, /print\("start", "start"\)/);
  assert.match(out, /print\(d\(5, 1\)\)/, 'the failing call is left as it was');
});

test('#118 control: when the sandbox can set the decoder up, its calls are still evaluated', { skip }, async () => {
  const src = `${DECODER}for i = 1, 256 do C[i] = string.char(i - 1) end
print(d("tubsu", 1), d("tubsu", 1))
print(d("ceegrv", 2), d("vhhq", 3), d("vhhq", 3))
`;
  const { r, out, want, got } = await evaluateAndRun(src);
  assert.equal(got.stdout, want.stdout);
  assert.equal(r.evaluated, 5, out);
  assert.match(out, /print\("start", "start"\)/);
  assert.match(out, /print\("accept", "seen", "seen"\)/);
});

test('#118 control: a decoder with hidden state (a call counter) is still refused', { skip }, async () => {
  const src = `local n = 0
local function _q(s) n = n + 1 return s .. n end
print(_q("a"), _q("b"), _q("c"), _q("d"), _q("e"))
`;
  const { r, want, got } = await evaluateAndRun(src);
  assert.equal(got.stdout, want.stdout);
  assert.equal(r.evaluated, 0);
});

test('#118 property: random memoising-decoder programs behave the same after the decoder evaluation', { skip, timeout: 600_000 }, async () => {
  // rng is a power-of-two LCG, whose low bits repeat with a short period: draw from the high bits so the choices are independent
  const lcg = rng(31);
  const rnd = (k) => Math.floor((lcg(2 ** 30) / 2 ** 30) * k);
  const words = ['start', 'accept', 'seen', 'idle', 'run'];
  const enc = (w, k) => [...w].map((c) => String.fromCharCode(c.charCodeAt(0) + k)).join('');
  // one decoder; two over one cache; two over one cache under two names (an alias)
  const second = ['', DECODER.replace('local K = {}\nlocal C = {}\n', '').replace('function d(', 'function e('),
    DECODER.replace('local K = {}\nlocal C = {}\n', 'local K2 = K\n').replace('function d(', 'function e(').replace(/K\[/g, 'K2[')];
  let replaced = 0;
  const shapes = new Set();
  for (let n = 0; n < 36; n++) {
    // the set-up runs where the sandbox can see it, or inside a statement that also calls the decoder (where it cannot)
    const hidden = rnd(2) === 1;
    const sharing = rnd(3);
    const names = sharing ? ['d', 'e'] : ['d'];
    const calls = Array.from({ length: 5 + rnd(6) }, () => { const w = words[rnd(words.length)]; const k = 1 + words.indexOf(w); return `${names[rnd(names.length)]}(${JSON.stringify(enc(w, k))}, ${k})`; });
    const lines = calls.map((c, i) => (rnd(3) === 0 ? `local function f${i}() return ${c} end print(f${i}())` : `print(${c})`));
    // sometimes a call the program never makes, which fails in the sandbox after storing its placeholder
    if (rnd(3) === 0) lines.splice(rnd(lines.length), 0, `if C[0] then print(${names[rnd(names.length)]}(5, ${1 + rnd(words.length)})) end`);
    const decoders = DECODER + second[sharing];
    const src = hidden
      ? `${decoders}local st = 1\nwhile st do\n  if st == 1 then\n    for i = 1, 256 do C[i] = string.char(i - 1) end\n    st = 2\n  else\n    ${lines.join('\n    ')}\n    st = nil\n  end\nend\n`
      : `${decoders}for i = 1, 256 do C[i] = string.char(i - 1) end\n${lines.join('\n')}\n`;
    const { r, out, want, got } = await evaluateAndRun(src);
    assert.equal(got.stdout, want.stdout, `case ${n}:\n${src}\n--- after:\n${out}`);
    replaced += r.evaluated;
    shapes.add(`${sharing}/${hidden}/${r.decoders.length}`);
  }
  assert.ok(replaced > 0, 'the property is not vacuous: some calls were evaluated');
  if (process.env.QS_SHOW) console.log('replaced', replaced, [...shapes]);
  assert.ok([...shapes].some((x) => /^[12]\/.*\/2$/.test(x)), `two decoders were recognised in some case: ${[...shapes]}`);
});

test('#118 AzureVM: the lifted program stays right through the clean-up passes with the guard switched off', { skip }, async () => {
  const src = read(path.join(corpus, 'obfuscated/azurevm/s04_control_flow__AzureGodUltra.lua'));
  const r = recover(src, { sandbox: { enabled: true }, vmGuard: false });
  assert.equal(r.steps.find((x) => x.id === 'azurevm.vm').status, 'applied');
  const [want, got] = [await oracle.runLua(read(path.join(corpus, 'originals/s04_control_flow.lua')), 'lua51'), await oracle.runLua(r.output, 'lua51')];
  assert.equal(got.stdout, want.stdout);
  // and with the guard on, it has nothing to undo
  const guarded = recover(src, { sandbox: { enabled: true } });
  assert.ok(!guarded.steps.some((x) => x.undone), JSON.stringify(guarded.steps.filter((x) => x.undone).map((x) => [x.id, x.undoneWhy])));
});

test('guard (kept independent of the fix): a step that changes what the program does is undone and recorded', () => {
  const run = new Run(parse('print("a")'), {});
  run.guard = (ast) => (print(ast, {}).includes('"b"') ? 'prints something else' : null);
  const bad = run.step('breaks', 'A step that changes a constant', (a) => { a.body[0].call.args[0] = { type: 'String', value: 'b', raw: '"b"' }; return { changed: 1 }; });
  assert.equal(bad, 0);
  assert.match(print(run.ast, {}), /print\("a"\)/);
  const rec = run.steps.get('breaks');
  assert.equal(rec.status, 'failed');
  assert.match(rec.error, /^undone: prints something else/);
  assert.equal(rec.undone, 1);
  const good = run.step('renames', 'A step that keeps it', (a) => { a.body[0].call.args[0] = { type: 'String', value: 'a', raw: '"a"' }; return { changed: 1 }; });
  assert.equal(good, 1);
});
