// Custom Obfuscator Intelligence (src/custom/anatomy.js, rules.js): roles, regions, stages, VM anatomy, tested hypotheses, learned rules.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { anatomy, testHypotheses } from '../src/custom/anatomy.js';
import { fingerprint, matchRules, similarity } from '../src/custom/rules.js';
import { analyzeCustom, tryReaders } from '../src/custom/analyze.js';
import { evaluatePass } from '../src/passes/evaluate.js';
import { unwrapWrapper } from '../src/passes/structure.js';
import { parse } from '../src/core/parser.js';
import { probe } from '../src/custom/probes.js';

const corpus = path.join(path.dirname(fileURLToPath(import.meta.url)), 'corpus');
const read = (p) => fs.readFileSync(path.join(corpus, p), 'latin1');
const deps = { evaluate: (ast) => { unwrapWrapper(ast); return evaluatePass(ast, { sandbox: { enabled: true } }); }, readers: tryReaders };
const run = (src, extra = {}) => testHypotheses(anatomy(src), src, { ...deps, ...extra });

test('a string decoder is found, and the hypothesis is CONFIRMED by running the evaluator on its slice', () => {
  const a = run(read('obfuscated/prometheus/s03_encoded_strings__step-EncryptStrings.lua'));
  const h = a.hypotheses.find((x) => x.role === 'string-decoder');
  assert.ok(h);
  assert.equal(h.test.status, 'confirmed');
  assert.match(h.test.detail, /\d+ call sites? resolved/);
  assert.equal(a.summary.architecture, 'conventional Lua with decoded constants');
});

test('a function that only looks like a decoder is REFUTED by the same test, and its confidence drops', () => {
  const src = 'local function f(s) local out = {} for i = 1, #s do out[#out + 1] = string.char(string.byte(s, i) + math.random(1, 3)) end return table.concat(out) end\nprint(f("aaaa"), f("bbbb"), f("cccc"), f("dddd"))\n';
  const a = run(src);
  const h = a.hypotheses.find((x) => x.role === 'string-decoder');
  assert.ok(h, 'the shape is that of a decoder');
  assert.equal(h.test.status, 'refuted', 'math.random makes it impure: the evaluator does not resolve it');
  assert.ok(h.confidence < 0.5);
});

test('a VM is described by its anatomy (machine, instruction encoding, handlers) and confirmed when a known reader reads it', () => {
  const a = run(read('obfuscated/ironbrew2/s01_minify_basic__default.lua'));
  assert.equal(a.summary.architecture, 'virtual machine');
  assert.match(a.vm.machine, /register machine/);
  assert.equal(a.vm.instructionEncoding.kind, 'tables');
  assert.ok(a.vm.handlers >= 20);
  const vm = a.hypotheses.find((x) => x.vm);
  assert.equal(vm.test.status, 'confirmed');
  assert.ok(a.hypotheses.filter((x) => x.role === 'interpreter').every((x) => x.test.status === 'confirmed'));
});

test('an unknown VM is still described: not "unsupported", but what is established and what is not', () => {
  const a = run(read('obfuscated/zenfus/s01_minify_basic__default.lua'));
  const interp = a.hypotheses.filter((x) => x.role === 'interpreter');
  assert.equal(interp.length, 1, 'only the function that holds the dispatch is the interpreter, not the wrapper around it');
  assert.equal(interp[0].function, 'run_vm');
  const vm = a.hypotheses.find((x) => x.vm);
  assert.equal(vm.test.status, 'inconclusive');
  assert.match(vm.test.detail, /no known VM reader/);
  const blob = a.regions.find((r) => r.charset === 'hex');
  assert.ok(blob && /hexToString/.test(blob.consumer), 'the encoded program is linked to the function that reads it');
});

test('base-N decoding with an alphabet held outside the decoder; the region it decodes is confirmed by the unwrapped layer', () => {
  const src = read('obfuscated/loaders/s01_minify_basic__base64.lua');
  const a = run(src, { layersApplied: true });
  assert.ok(a.hypotheses.some((x) => x.role === 'base-n-decoder' && x.test.status === 'confirmed'));
  assert.ok(a.hypotheses.some((x) => x.region != null && x.consumer === 'decode' && x.test.status === 'confirmed'));
  const b = run(src, { layersApplied: false });
  assert.ok(!b.hypotheses.some((x) => x.role === 'base-n-decoder' && x.test.status === 'confirmed'), 'without the layer, not confirmed');
});

test('fingerprints ignore names and constants but not shape; near matches are reported, never merged', () => {
  const f = (src) => fingerprint(parse(src).body[0].func);
  const a = f('local function d(s, k) local o = {} for i = 1, #s do o[i] = string.char((string.byte(s, i) + k) % 256) end return table.concat(o) end');
  const b = f('local function zz(q, w) local r = {} for j = 1, #q do r[j] = string.char((string.byte(q, j) + w) % 255) end return table.concat(r) end');
  const c = f('local function d(s, k) local o = {} for i = 1, #s do o[i] = string.char(bit32.bxor(string.byte(s, i), k)) end return table.concat(o) end');
  assert.equal(a.hash, b.hash, 'renamed locals and different constants: same shape');
  assert.notEqual(a.hash, c.hash);
  const rules = { rules: [{ fingerprint: a.hash, role: 'string-decoder', confirmations: 3, seq: a.seq }] };
  assert.equal(matchRules(b, rules).exact.role, 'string-decoder');
  const m = matchRules(c, rules);
  assert.ok(!m || !m.exact, 'a different decoder is never an exact match');
  assert.ok(similarity(a.seq, c.seq) < 1);
});

test('learned rules: built from confirmed tests only, each seen on at least two samples, none ever refuted', () => {
  const r = JSON.parse(fs.readFileSync(path.join(corpus, '..', '..', 'data', 'research', 'learned-rules.json'), 'utf8'));
  assert.ok(r.rules.length >= 5);
  for (const x of r.rules) { assert.ok(x.confirmations >= 2); assert.ok(x.role); }
  // a learned rule is applied to a sample of the same generator (exact) and still tested there
  const src = read('obfuscated/prometheus/s05_nested_functions__step-EncryptStrings.lua');
  const a = testHypotheses(anatomy(src, { rules: r }), src, deps);
  const h = a.hypotheses.find((x) => x.role === 'string-decoder');
  assert.ok(h && h.evidence.some((e) => /matches a learned rule/.test(e)));
  assert.equal(h.test.status, 'confirmed');
});

test('analyzeCustom carries the anatomy; a long string literal is no longer read as minified layout', () => {
  const r = analyzeCustom(read('obfuscated/prometheus/s03_encoded_strings__step-EncryptStrings.lua'), { sandbox: { enabled: true } });
  assert.ok(r.anatomy && r.anatomy.ok);
  assert.ok(r.anatomy.hypotheses.some((h) => h.test.status === 'confirmed'));
  assert.ok(!probe(`local x = "${'a'.repeat(800)}"\nprint(x)\n`).transformations.some((t) => t.id === 'minified-layout'));
});
