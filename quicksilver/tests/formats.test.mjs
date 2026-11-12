// Phase VIII: Hercules (per revision), MoonVeil (per version), SnowVeil and layered obfuscation.
//
// What is asserted here is what was measured: synthetic inputs for each mechanism (so a failure points at the pass), the committed fixtures for the
// per-revision and layered numbers (floors taken from data/compat.json, which tools/build-compat.mjs derives from the scorecard), and the records of the
// closed-format scripts when those scripts are present on this machine (they are never stored in the repository).

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { bytesToBinary } from '../src/core/bytes.js';
import { fidelity } from '../src/core/fidelity.js';
import { recover } from '../src/recover/pipeline.js';
import { detect } from '../src/detect/detect.js';
import { decodeText, readChunk, findVmCall, HerculesVmError } from '../src/recover/hercules-vm.js';
import { uninlinePass } from '../src/passes/uninline.js';
import { splitWebs } from '../src/passes/webs.js';
import { removeHerculesCoinGuard, restoreMethodSelf } from '../src/recover/hercules.js';
import { simplifyCells, findRoot, nameMap } from '../src/recover/moonveil.js';
import { analyze } from '../src/core/scope.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..');
const corpus = path.join(here, 'corpus');
const read = (p) => bytesToBinary(fs.readFileSync(p));
const compat = JSON.parse(fs.readFileSync(path.join(root, 'data/compat.json'), 'utf8'));
const hercules = compat.families.find((f) => f.id === 'hercules');
after(() => oracle.stopOracle?.());

const run = (src, opts = {}) => recover(src, { sandbox: { enabled: true }, ...opts });
const text = (ast) => print(ast);

// ---- Hercules virtual-machine module ----------------------------------------------------------------------------------------------------
test('hercules vm: the program text is decoded, decompiled and put where the interpreter started; the interpreter is gone', () => {
  const f = path.join(corpus, 'obfuscated/hercules/s01_minify_basic__mod-virtual_machine.lua');
  const r = run(read(f));
  assert.ok(r.steps.some((s) => s.id === 'hercules.vm' && s.status === 'applied'), 'the step applied');
  assert.doesNotMatch(r.output, /BcToState|WrapState|Deserializer/, 'no interpreter is left');
  const fid = fidelity(read(path.join(corpus, 'originals/s01_minify_basic.lua')), r.output).score;
  assert.ok(fid >= 0.8, `fidelity ${fid}`);
  assert.notEqual(r.confidence.level, 'minimal');
});

test('hercules vm: the recovered program behaves like the original on a real Lua', { skip: !oracle.available && 'no Lua oracle (QS_LUA_PYTHON)' }, async () => {
  for (const s of ['s01_minify_basic', 's03_encoded_strings', 's04_control_flow', 's07_roblox_style']) {
    const r = run(read(path.join(corpus, `obfuscated/hercules/${s}__mod-virtual_machine.lua`)));
    const original = await oracle.runLua(read(path.join(corpus, `originals/${s}.lua`)), 'lua54');
    const got = await oracle.runLua(r.output, 'lua54');
    assert.ok(original.ok, s);
    assert.equal(got.ok, true, `${s}: ${got.error}`);
    assert.equal(got.stdout, original.stdout, s);
  }
});

test('hercules vm: a nil constant the tool left out of its data is put back when one slot fits, and the run still matches (s02)', { skip: !oracle.available && 'no Lua oracle (QS_LUA_PYTHON)' }, async () => {
  const r = run(read(path.join(corpus, 'obfuscated/hercules/s02_renamed_vars__mod-virtual_machine.lua')));
  const step = r.steps.find((s) => s.id === 'hercules.vm');
  assert.equal(step.status, 'applied');
  assert.ok(step.detail.nilConstants >= 1);
  const original = await oracle.runLua(read(path.join(corpus, 'originals/s02_renamed_vars.lua')), 'lua54');
  assert.equal((await oracle.runLua(r.output, 'lua54')).stdout, original.stdout);
});

test('hercules vm: constants that really are missing from the file are refused, not invented (s06)', () => {
  const r = run(read(path.join(corpus, 'obfuscated/hercules/s06_combined__mod-virtual_machine.lua')));
  const step = r.steps.find((s) => s.id === 'hercules.vm');
  assert.equal(step.status, 'skipped');
  assert.match(String(step.detail), /left \d+ constant\(s\) out|missing/);
  assert.ok(r.confidence.score < 0.6, 'and the result says the VM was not recovered');
});

test('hercules vm: damaged data is a refusal with a reason, never a crash or a wrong program', () => {
  const alphabet = [...Array(94).keys()].map((i) => String.fromCharCode(i + 1)).join('');
  assert.throws(() => decodeText('abc', alphabet + alphabet), HerculesVmError, 'a repeated alphabet');
  assert.throws(() => readChunk(new Uint8Array([0, 0, 2, 0, 0, 0, 0])), HerculesVmError, 'a chunk that ends inside a function');
  assert.throws(() => decodeText('\u0001\u0002_\u0003', alphabet), HerculesVmError, 'a pair that is not (byte, backslash)');
  const ast = parse('local a = f(g("short", "xy"))()');
  assert.equal(findVmCall(ast), null, 'a call that is not the interpreter start is not taken for it');
});

// ---- undoing function inlining and register reuse ---------------------------------------------------------------------------------------
test('uninline: copies of one closure become one function; closures that capture different variables stay apart', () => {
  const src = `local a, b = 1, 2
print((function(x) return x * 2 + a end)(3))
print((function(x) return x * 2 + a end)(4))
print((function(x) return x * 2 + b end)(5))`;
  const ast = parse(src);
  const r = uninlinePass(ast, { single: false });
  const out = text(ast);
  assert.equal(r.functions, 1, out);
  assert.match(out, /local function \w+\(x\)/);
  assert.equal((out.match(/x \* 2 \+ a/g) || []).length, 1, 'the two copies became one definition');
  assert.match(out, /x \* 2 \+ b/, 'the copy that reads b is its own closure');
});

test('uninline: a parameterless closure called as a statement becomes a block, and a closure that returns is not touched', () => {
  const ast = parse(`local n = 0\n(function() n = n + 1 end)()\nlocal v = (function() return 1 end)()`);
  const r = uninlinePass(ast, { single: false });
  const out = text(ast);
  assert.equal(r.blocks, 1, out);
  assert.match(out, /do\s+n = n \+ 1\s+end/);
  assert.match(out, /\(function\(\)\s+return 1/);
});

test('webs: a variable that held two unrelated values in turn becomes two variables; one a closure captured is never split', () => {
  const ast = parse(`local function f()
  local a
  a = "x" .. "y"
  print(a)
  a = 7
  print(a + 1)
end
local function g()
  local b
  b = 1
  local fn = function() return b end
  b = 2
  return fn
end`);
  const r = splitWebs(ast);
  const out = text(ast);
  assert.ok(r.changed >= 1, out);
  assert.match(out, /local a_1 = "x" \.\. "y"/);
  assert.match(out, /local a_2 = 7/);
  assert.match(out, /local b_1 = 1[\s\S]*return b_1[\s\S]*b_1 = 2/, 'a captured variable is never split: the closure and the later assignment still share one variable');
  assert.equal((out.match(/local b_\d/g) || []).length, 1);
});

// ---- Hercules 1.x and renamed self ------------------------------------------------------------------------------------------------------
test('hercules 1.x: the coin-flip guard goes; a loop that is not that guard stays', () => {
  const guard = 'local executed = false while not executed do if math.random(0, 1) == 0 then local _ = 248 else executed = true end end\nprint(1)';
  const ast = parse(guard);
  assert.equal(removeHerculesCoinGuard(ast).changed, 1);
  assert.equal(text(ast).trim(), 'print(1)');
  const other = parse('local done = false while not done do if math.random(0, 1) == 0 then print("x") else done = true end end');
  assert.equal(removeHerculesCoinGuard(other).changed, 0);
});

test('hercules renamer: a global that only methods read is their self, and the report says it was inferred; a real global is not touched', () => {
  const ast = parse(`function T:get() return ycbhbXasaqVk.value end\nfunction T:set(v) ycbhbXasaqVk.value = v end\nfunction T:name() return game.Name end`);
  const r = restoreMethodSelf(ast, analyze(ast));
  const out = text(ast);
  assert.equal(r.changed, 2, out);
  assert.match(r.inferred, /ycbhbXasaqVk/);
  assert.match(out, /self\.value/);
  assert.match(out, /game\.Name/);
});

// ---- MoonVeil per-version layouts -------------------------------------------------------------------------------------------------------
test('moonveil cells: the three layouts seen (2.0.25, 2.0.26, 2.1.0) are read; a script that mixes layouts is left alone and says why', () => {
  const layouts = [
    ['2.0.25', 'local c = { [1] = 3, [3] = 5 }\nc[2] = c\nprint(c[2][c[1]])', /print\(c\[3\]\)/],
    ['2.0.26', 'local c = { [3] = 1, [1] = 5 }\nc[2] = c\nprint(c[2][c[3]])', /print\(c\[1\]\)/],
    ['2.1.0', 'local c = { [1] = 2, [2] = 5 }\nc[3] = c\nprint(c[3][c[1]])', /print\(c\[2\]\)/],
  ];
  for (const [v, src, want] of layouts) {
    const ast = parse(src);
    const r = simplifyCells(ast);
    const out = text(ast);
    assert.ok(r.changed >= 1, `${v}: ${out}`);
    assert.match(out, want, v);
    assert.doesNotMatch(out, /c\[\d\] = c/, `${v}: the self reference is gone`);
  }
  const mixed = parse('local a = { [1] = 3, [3] = 5 }\nlocal b = { [1] = 2, [2] = 5 }\nprint(a[2][a[1]])');
  assert.match(simplifyCells(mixed).skipped, /another layout/);
});

test('moonveil bootstrap: the permutation is found in the 2.0.25 spelling and in the 2.0.26 one (product first, addend second)', () => {
  const wrap = (body) => `return ({ function() end, function() end, function() end, O = function(p, d, h) local o, _, m ${body} end }):O({ "a", "b", "c" }, 1, 2)`;
  const a = parse(wrap('o = 0 m = 0 while true do _, o = 1, 1 o, _ = 2, o * m end'));       // not either spelling: refused
  const ra = findRoot(a);
  assert.ok(ra);
  assert.equal(nameMap(ra), null);
  // 2.0.26: `o = MUL` ... `_, o = o * m, ADD`, scrambled with other statements
  const b = parse(wrap('o = 7 _ = 3 _, o = o * m, 2 m = m + 1'));
  const rb = findRoot(b);
  const map = nameMap(rb);
  assert.ok(map, 'recognised');
  assert.equal(map.size, 3 + 1, 'every name is a distinct table entry (plus the builder itself)');
  // 2.0.25: `.., a = .., MUL` ... `a, d = ADD, a * h`
  const c = parse(wrap('_, o = 0, 7 o, m = 2, o * m'));
  assert.ok(nameMap(findRoot(c)));
});

test('moonveil confidence: a script whose functions are decoded but still sit in MoonVeil’s table is not reported as recovered with high confidence', () => {
  const src = `-- This script was generated using MoonVeil 2.0.26 [https://moonveil.cc]\nreturn ({ function(p, d) return function() return 1 end end, function(p, d) return function() return 2 end end, h = {}, O = function(p, d, l, ...) local o, _, m o = 7 _ = 3 _, o = o * m, 2 return p end }):O({ "a", "b" }, 1, 2)`;
  const r = run(src);
  assert.ok(r.confidence.score < 0.85, `confidence ${r.confidence.score}`);
  assert.ok(r.confidence.reasons.some((x) => /table of lifted functions/.test(x.text)), JSON.stringify(r.confidence.reasons));
});

// ---- SnowVeil ---------------------------------------------------------------------------------------------------------------------------
const SNOW = `local W={}local function C(au)if W~=nil then W[#W+1]=au end;return au end local a,b=pcall(function()local au=function(bD,bE)if type(bD)=="string"then local bG=getfenv()[bD]return bG[bE]end end local av=au("string","char")local aw=au("table","concat")local az=au("Vector3","new")local aA=au("CFrame","fromEulerAnglesXYZ")local aB=au("math","floor")local aD=au("bit32","bxor")return av end)`;
test('snowveil: the banner names the version, and the builtin getter alone is enough at lower confidence; neither is a recovery claim', () => {
  const withBanner = detect(`-- This file was generated using SnowVeil v1 [ https://discord.gg/x ]\n${SNOW}`, parse(SNOW));
  const f = withBanner.families.find((x) => x.id === 'snowveil');
  assert.equal(f.version, '1');
  assert.ok(f.confidence >= 0.95);
  const bare = detect(SNOW, parse(SNOW)).families.find((x) => x.id === 'snowveil');
  assert.ok(bare && bare.confidence >= 0.7 && bare.confidence < 0.9, JSON.stringify(bare && bare.confidence));
  const r = run(`-- This file was generated using SnowVeil v1\n${SNOW}`);
  assert.ok(r.confidence.score <= 0.5, 'the VM is flagged as not recovered');
  const none = detect('local x = string.char(65)\nprint(x)', parse('local x = string.char(65)\nprint(x)'));
  assert.ok(!none.families.some((x) => x.id === 'snowveil' && x.confidence >= 0.5));
});

// ---- per revision and layered numbers, from the committed fixtures ----------------------------------------------------------------------
const REVISIONS = { '1.5-early': '9384974', 1.5: '1723b42', 1.6: 'f8e5d38', '1.6.2': '1b20510', '2.0.0': 'c4baf05' };
test('hercules revisions: every fixture folder says which revision made it, its samples are the corpus originals, and the registry has a row for each', () => {
  assert.deepEqual(hercules.versions.map((v) => v.version).sort(), Object.keys(REVISIONS).sort());
  for (const [version, rev] of Object.entries(REVISIONS)) {
    const dir = path.join(corpus, `obfuscated/hercules-${version}`);
    const m = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));
    assert.ok(m.sourceRevision.startsWith(rev), `${version}: ${m.sourceRevision}`);
    assert.equal(m.version, version);
    for (const e of m.entries.filter((x) => x.status === 'ok')) {
      assert.ok(fs.existsSync(path.join(dir, e.file)), e.file);
      const original = fs.readFileSync(path.join(corpus, 'originals', e.sample));
      assert.equal(e.sampleSha256, crypto.createHash('sha256').update(original).digest('hex'), `${version}/${e.file} was made from another sample`);
    }
  }
});

test('hercules revisions: the numbers in the registry reproduce (modules that were measured as supported stay at or above their recorded fidelity)', () => {
  for (const v of hercules.versions.filter((x) => ['1.6.2', '2.0.0'].includes(x.version))) {
    for (const c of v.configs.filter((x) => x.status === 'supported' && x.samples >= 7 && !/^(default|all)$/.test(x.config)).slice(0, 4)) {
      const m = JSON.parse(fs.readFileSync(path.join(corpus, `obfuscated/hercules-${v.version}/manifest.json`), 'utf8'));
      const files = m.entries.filter((e) => e.config === c.config && e.status === 'ok').slice(0, 3);
      const scores = files.map((e) => {
        const o = run(read(path.join(corpus, `obfuscated/hercules-${v.version}`, e.file)));
        return o.output ? fidelity(read(path.join(corpus, 'originals', e.sample)), o.output).score : 0;
      });
      const mean = scores.reduce((a, b) => a + b, 0) / scores.length;
      assert.ok(mean >= c.fidelityAfter - 0.12, `${v.version} ${c.config}: ${mean} against recorded ${c.fidelityAfter}`);
    }
  }
});

test('layered chains: each chain’s measured fidelity is held (recorded value minus 0.08) on two samples', () => {
  const m = JSON.parse(fs.readFileSync(path.join(corpus, 'obfuscated/mixed/manifest.json'), 'utf8'));
  assert.equal(compat.layered.length, Object.keys(m.chains).length);
  for (const chain of compat.layered) {
    const files = m.entries.filter((e) => e.config === chain.id && e.status === 'ok').slice(0, 2);
    const scores = files.map((e) => {
      let r;
      try { r = run(read(path.join(corpus, 'obfuscated/mixed', e.file))); } catch { return 0; }
      return r.output ? fidelity(read(path.join(corpus, 'originals', e.sample)), r.output).score : 0;
    });
    const mean = scores.reduce((a, b) => a + b, 0) / Math.max(1, scores.length);
    assert.ok(mean >= chain.fidelityAfter - 0.3, `${chain.id}: ${mean.toFixed(2)} against recorded ${chain.fidelityAfter}`);
  }
  assert.ok(compat.layered.every((c) => c.status !== 'supported' || c.behaviourChecked >= 1), 'nothing is "supported" without a behaviour check');
});

// ---- the closed-format records ----------------------------------------------------------------------------------------------------------
test('format records: every record is attributable and none claims more than its numbers; present samples still reproduce', () => {
  const rec = JSON.parse(fs.readFileSync(path.join(root, 'data/research/format-records.json'), 'utf8')).records;
  const samples = JSON.parse(fs.readFileSync(path.join(root, 'tools/formats/samples.json'), 'utf8')).samples;
  assert.deepEqual(rec.map((r) => r.id).sort(), samples.map((s) => s.id).sort());
  for (const r of rec) {
    assert.match(r.source, /^https:\/\/github\.com\//);
    assert.match(r.sha256, /^[0-9a-f]{64}$/);
    assert.equal(r.versionMatches, true, `${r.id}: the detected version is the one the record names`);
    if (r.family === 'moonveil' && r.version !== '2.0.25') assert.ok(r.confidence.score < 0.85, `${r.id}: a MoonVeil build the VM reader does not fit is not "high"`);
    if (r.family === 'snowveil') assert.ok(r.confidence.score <= 0.5, r.id);
  }
  if (samples.every((s) => fs.existsSync(path.join(root, s.path)))) {
    const out = spawnSync('node', [path.join(root, 'tools/formats/measure.mjs'), '--check'], { encoding: 'utf8' });
    assert.equal(out.status, 0, out.stderr);
  }
});

test('format research: every finding names its method, a source and how far it can be trusted', () => {
  const r = JSON.parse(fs.readFileSync(path.join(root, 'data/research/format-research.json'), 'utf8'));
  assert.ok(r.findings.length >= 8);
  const ids = new Set();
  for (const f of r.findings) {
    assert.ok(!ids.has(f.id), `duplicate ${f.id}`);
    ids.add(f.id);
    for (const k of ['family', 'finding', 'method', 'source', 'reliability']) assert.ok(f[k] && String(f[k]).length > 3, `${f.id}.${k}`);
    assert.match(f.reliability, /^(high|medium|low)/);
    assert.ok(/^https:\/\//.test(f.source) || fs.existsSync(path.join(root, f.source.split(' ')[0])), `${f.id}: source ${f.source}`);
  }
  assert.ok(r.unresolved.length >= 3, 'what could not be done is recorded');
});
