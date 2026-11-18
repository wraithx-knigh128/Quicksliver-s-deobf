// Prompt XXI — zero false success. The outcome classes (src/validate/outcome.js) and the connected workflow that uses them:
// recovery in the Deobfuscator, Loader Intelligence, and a payload its owner supplies (the authorised route when a service such as Luarmor
// has no retrieval interface).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { classifyOutcome, inputEvidence, OUTCOMES, CRITERIA } from '../src/validate/outcome.js';
import { parse } from '../src/core/parser.js';
import { recoverSource, verifySource, outcomeWithBehaviour, loaderAnalyze } from '../src/api.js';
import { processPayload } from '../src/loader/intel.js';
import { decodePayload } from '../src/loader/payload.js';
import { detect } from '../src/detect/detect.js';
import { verifyRecovery } from '../src/adaptive/verify.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const fixture = (p) => fs.readFileSync(path.join(root, 'tests', 'corpus', p), 'latin1');
const clean = { input: { kind: 'lua', parses: true }, obfuscated: true, recovery: { output: 'print(1)', parses: true, residual: [], unresolved: 0, level: 'high' } };

test('every class has a label and a written criterion', () => {
  assert.deepEqual(Object.keys(OUTCOMES).sort(), Object.keys(CRITERIA).sort());
  assert.equal(Object.keys(OUTCOMES).length, 8);
});

test('none of the things the prompt lists makes a success on its own: HTTP 200, a download, decoded text, a generated output, readable code, a parser accepting it, a high confidence', () => {
  const r = classifyOutcome({ ...clean, retrieval: { status: 'ok' } });
  assert.equal(r.outcome, 'syntax-valid-unverified');
  assert.equal(r.success, false);
  assert.match(r.reasons.join(' '), /not compared/);
});

test('only an identical behaviour comparison validates; "different" is partial however clean the output looks; "inconclusive" stays unverified', () => {
  assert.equal(classifyOutcome({ ...clean, behaviour: { verdict: 'identical', against: 'input' } }).outcome, 'validated');
  assert.equal(classifyOutcome({ ...clean, behaviour: { verdict: 'identical', against: 'original' } }).success, true);
  assert.equal(classifyOutcome({ ...clean, behaviour: { verdict: 'different', against: 'input' } }).outcome, 'partial');
  assert.equal(classifyOutcome({ ...clean, behaviour: { verdict: 'inconclusive', against: 'input' } }).outcome, 'syntax-valid-unverified');
});

test('obfuscation left in the output keeps a result partial even when its behaviour matches', () => {
  const b = { verdict: 'identical', against: 'input' };
  assert.equal(classifyOutcome({ ...clean, recovery: { ...clean.recovery, residual: ['vm:interpreter'] }, behaviour: b }).outcome, 'partial');
  assert.equal(classifyOutcome({ ...clean, recovery: { ...clean.recovery, unresolved: 2 }, behaviour: b }).outcome, 'partial');
  assert.equal(classifyOutcome({ ...clean, recovery: { ...clean.recovery, level: 'low' }, behaviour: b }).outcome, 'partial');
  assert.equal(classifyOutcome({ ...clean, recovery: { ...clean.recovery, level: 'minimal' }, behaviour: b }).outcome, 'not-deobfuscated');
});

test('no output, or an output that does not parse, is not deobfuscated', () => {
  assert.equal(classifyOutcome({ ...clean, recovery: { output: null, error: 'x' } }).outcome, 'not-deobfuscated');
  assert.equal(classifyOutcome({ ...clean, recovery: { ...clean.recovery, parses: false } }).outcome, 'not-deobfuscated');
  assert.equal(classifyOutcome({ ...clean, retrieval: { status: 'ok' }, recovery: { output: null } }).label, OUTCOMES['not-deobfuscated']);
});

test('retrieval answers map to the right class and stop the chain there', () => {
  for (const [status, want] of [['not-configured', 'authorization-unavailable'], ['unauthorized', 'authorization-unavailable'], ['no-route', 'payload-unavailable'], ['not-found', 'payload-unavailable'], ['failed', 'payload-unavailable'], ['empty', 'payload-unavailable'], ['not-code', 'payload-unavailable'], ['something-new', 'payload-unavailable']]) {
    assert.equal(classifyOutcome({ ...clean, retrieval: { status }, behaviour: { verdict: 'identical' } }).outcome, want, status);
  }
});

test('input evidence: a cut-off program is told apart from an ordinary syntax error, binary from text', () => {
  assert.deepEqual([inputEvidence('local function f()\n print(1)\n', parse).truncated, inputEvidence('print("abc', parse).truncated, inputEvidence('local t = {1,2,', parse).truncated], [true, true, true]);
  assert.equal(inputEvidence('f("a")\nend\n', parse).truncated, false, "'<eof>' expected near 'end' is too much text, not too little");
  assert.equal(inputEvidence('x = = 1\nprint(2)\n', parse).truncated, false);
  assert.equal(inputEvidence('', parse).kind, 'empty');
  assert.equal(inputEvidence('\x1bLuaQ\x00\x01', parse).kind, 'luac');
  assert.equal(inputEvidence('\x05\x03\x00\x01\x02\x07\x00\x00\x00\x01\x01\x02\x03\x00\x00', parse).kind, 'luau-bytecode');
  assert.equal(classifyOutcome({ input: inputEvidence('local function f()\n', parse) }).outcome, 'invalid-input');
  assert.equal(classifyOutcome({ input: { kind: 'luau-bytecode' } }).outcome, 'unsupported-format');
});

// ---- the Deobfuscator: every recovery carries its class --------------------------------------------------------------------------------

test('Deobfuscator: a recovery is at best "unverified" until its behaviour is compared; the comparison decides validated or partial', () => {
  const src = fixture('obfuscated/prometheus/s06_combined__Weak.lua');
  const r = recoverSource(src, { sandbox: { enabled: true } });
  assert.equal(r.confidence.level, 'high');
  assert.equal(r.outcome.outcome, 'syntax-valid-unverified', 'a high confidence is not a validation');
  const v = verifySource(src, { recovered: r.output });
  assert.equal(v.verdict, 'identical');
  const after = outcomeWithBehaviour('', { evidence: r.outcome.evidence, behaviour: { verdict: v.verdict, against: 'input' } });
  assert.equal(after.outcome, 'validated');
  const diff = outcomeWithBehaviour('', { evidence: r.outcome.evidence, behaviour: { verdict: 'different', against: 'input' } });
  assert.equal(diff.outcome, 'partial');
});

test('Deobfuscator: a VM that stays in place is "not deobfuscated" even though the output parses and behaves the same', () => {
  const src = fixture('obfuscated/zenfus/s01_minify_basic__default.lua');
  const r = recoverSource(src, { sandbox: { enabled: true } });
  assert.equal(r.outcome.outcome, 'not-deobfuscated');
});

test('Deobfuscator: the Obscura 1.0.1 VM build the engine rates 90% "high" is never reported as validated (its input does nothing observable)', () => {
  const src = fixture('obfuscated/obscura-1.0.1/s04_control_flow__vm.lua');
  const r = recoverSource(src, { sandbox: { enabled: true } });
  assert.equal(r.confidence.level, 'high');
  const v = verifySource(src, { recovered: r.output });
  const after = outcomeWithBehaviour('', { evidence: r.outcome.evidence, behaviour: { verdict: v.verdict, against: 'input' } });
  assert.notEqual(after.outcome, 'validated', `verdict ${v.verdict}`);
});

test('Deobfuscator: invalid input is classified before any pipeline work', () => {
  assert.equal(recoverSource('local function greet(n)\n  print("hi " .. n)\nend\ngreet("wor').outcome.outcome, 'invalid-input');
  assert.equal(recoverSource('   ').outcome.outcome, 'invalid-input');
});

// ---- the owner-supplied payload: the same validated chain as a retrieved one ------------------------------------------------------------

const deps = {
  decode: decodePayload,
  detect: (t) => detect(t),
  analyze: (s, o) => loaderAnalyze(s, o),
  recover: (t) => recoverSource(t, { sandbox: { enabled: true } }),
  verify: (a, b) => verifyRecovery(a, b),
};
const supply = (text) => processPayload({ source: 'owner-supplied' }, new Uint8Array(Buffer.from(text, 'latin1')), { name: 'payload.lua', deps, supplied: true });

test('owner-supplied payload: an obfuscated script goes through validation, detection, deobfuscation, syntax and behaviour, and is validated on evidence', async () => {
  const st = await supply(fixture('obfuscated/ironbrew2/s01_minify_basic__default.lua'));
  assert.equal(st.result.outcome, 'validated');
  const p = st.programs[0];
  assert.ok(p.families.length, 'the obfuscator is named');
  assert.equal(p.behaviour.verdict, 'identical');
  assert.ok(p.output && p.output.length > 0);
  assert.ok(!/retrieved through an authorised route/.test(st.result.met.join(' ')), 'a supplied payload is not described as retrieved');
});

test('owner-supplied payload: cut-off code, a text message, an empty file and Luau bytecode are stopped at payload validation', async () => {
  const cut = await supply(fixture('originals/s01_minify_basic.lua').slice(0, 300));
  assert.equal(cut.result.outcome, 'invalid-input');
  assert.equal(cut.programs, undefined, 'not passed to the pipeline');
  assert.equal((await supply('Key required. Get your key from our Discord.')).result.outcome, 'invalid-input');
  assert.equal((await supply('')).result.outcome, 'invalid-input');
  assert.equal((await supply('\x05\x03\x02\x00\x01\x00\x00\x00\x07\x80\x81\x10\x11\x12\x13\x00\x00\x00\x14\x15\x16\x17\x18\x19\x1a')).result.outcome, 'unsupported-format');
});

test('owner-supplied payload: a program that is itself another loader is reported as such, not reconstructed', async () => {
  const st = await supply('loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/0123456789abcdef0123456789abcdef.lua"))()\n');
  assert.ok(st.programs[0].nestedLoader, 'recognised as a loader');
  assert.equal(st.result, undefined, 'no reconstruction class is claimed for a loader');
});

// ---- D11: a deobfuscator defect found by the behaviour check ------------------------------------------------------------------------------

test('D11 proxify: a stored value with an effect is read from its table, never copied (the call ran twice)', async () => {
  const { undoProxifyLocals } = await import('../src/recover/prometheus.js');
  const { print } = await import('../src/core/printer.js');
  const { traceScript } = await import('../src/trace/trace.js');
  const src = 'local n = 0 local function f() n = n + 1 return n * 10 end local function get(r, q) return r["k"] end local function set(r, q) r["k"] = q end local tbl = { ["k"] = f() } local p = setmetatable(tbl, { __sub = get, __add = set }) print(p - "x", n)';
  const ast = parse(src);
  const r = undoProxifyLocals(ast);
  assert.ok(r.proxies >= 1 && r.reads >= 1, JSON.stringify(r));
  const out = print(ast);
  assert.equal((out.match(/(?<!function )\bf\(\)/g) || []).length, 1, `f() must be called once:\n${out}`);
  // same printed result before and after: 10 and n = 1 (the duplicated call printed 20 and 2)
  const run = (code) => traceScript(code, { fuel: 1_000_000, timeMs: 2000 }).output;
  assert.equal(run(out), run(src));
  assert.match(run(out), /10\s+1/);
});
