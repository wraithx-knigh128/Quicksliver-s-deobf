// Prompt XXIV — what the public sample collection (github.com/terrorlua/obfuscator-samples, linked from the git-ignored local/terrorlua)
// taught the engine. The samples carry no licence and stay outside the repository; tests that need them skip without them, the rest use
// synthetic text that has the measured shape.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { parse, MAX_DEPTH } from '../src/core/parser.js';
import { detectScript, recoverSource } from '../src/api.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const samples = path.join(root, 'local', 'terrorlua');
const have = (rel) => fs.existsSync(path.join(samples, rel));
const read = (rel) => fs.readFileSync(path.join(samples, rel), 'latin1');
const engineDir = path.join(root, 'api', '_engine', 'luraph');
const hasPython = spawnSync('python3', ['-V']).status === 0;

test('parser: nesting up to Luau’s own limit (1000) parses; beyond it is refused with the reason', () => {
  assert.equal(MAX_DEPTH, 1000);
  // 650 Boronide scripts nest 201-344 levels deep and are parsed by Luau itself; the old limit of 200 called them invalid
  parse(`return ${'('.repeat(344)}1${')'.repeat(344)}`);
  parse(`${'do '.repeat(400)}local x = 1 ${'end '.repeat(400)}`);
  assert.throws(() => parse(`return ${'('.repeat(1100)}1${')'.repeat(1100)}`), /nesting too deep|too many syntax levels/);
});

const BORONIDE_HEAD = (credit) => `--[[\n\therrtt's obfuscator, v0.2.4\n--]]\n\nlocal a,b,c=nil,nil,nil([[${credit}]]):gsub('(.*)',function(d)local e="Ut8bAssABMm5iNMHhumR4z"local f="NZQ6b"local g=3446;local h=5387;while(g<h)do h=g-10774 end end)\n`;

test('Boronide / herrtt: the template is recognised whatever the credit line says, and the herrtt header gives the version', () => {
  const d = detectScript(BORONIDE_HEAD('herrtts obf, discord.gg/x')).detection;
  const f = d.families.find((x) => x.id === 'boronide');
  assert.ok(f && f.confidence >= 0.9, JSON.stringify(d.families));
  assert.equal(f.version, 'herrtt 0.2.4');
  assert.ok(f.evidence.some((e) => e.rule === 'template' && e.unrecoverable));
  // a plain script with the same first words is not
  assert.equal(detectScript('local a,b,c = nil, nil, nil\nprint(a)').detection.families.some((x) => x.id === 'boronide'), false);
});

test('a VM that nothing rebuilt is "not deobfuscated" (confidence minimal), not "partial"', { skip: !have('Boronide/SuperOps-Only') && 'the sample collection is kept locally only' }, () => {
  const f = fs.readdirSync(path.join(samples, 'Boronide/SuperOps-Only')).sort()[0];
  const r = recoverSource(read(`Boronide/SuperOps-Only/${f}`), { sandbox: { enabled: true } });
  assert.equal(r.detection.families[0].id, 'boronide');
  assert.equal(r.confidence.level, 'minimal');
  assert.equal(r.outcome.outcome, 'not-deobfuscated');
});

test('Luraph: a banner together with the output’s shape is VM evidence, a banner alone is not', () => {
  const big = `-- This file was protected using Luraph Obfuscator v15.2 [https://lura.ph/]\n\nreturn setmetatable({${'a=1,'.repeat(5000)}},{})\n`;
  const d = detectScript(big).detection.families.find((x) => x.id === 'luraph');
  assert.ok(d.evidence.some((e) => e.rule === 'vm-output' && e.unrecoverable));
  const small = '-- This file was protected using Luraph Obfuscator v15.2 [https://lura.ph/]\nprint("hello")\n';
  const s = detectScript(small).detection.families.find((x) => x.id === 'luraph');
  assert.ok(!s.evidence.some((e) => e.rule === 'vm-output'), 'a banner on a small plain script is not taken as a VM');
});

test('Luraph v15.2 (the file with a 759 KB output): the verdict no longer depends on the output’s size', { skip: !have('Luraph/v15.2/776fcb7df2cee0f9.lua') && 'the sample collection is kept locally only', timeout: 300_000 }, () => {
  const r = recoverSource(read('Luraph/v15.2/776fcb7df2cee0f9.lua'), { sandbox: { enabled: true } });
  assert.equal(r.outcome.outcome, 'not-deobfuscated');      // was "partial", medium confidence 0.80
});

test('engine service: a trace that observed only Luraph’s environment probe, or nothing, is not a reconstruction', { skip: !hasPython && 'python3 is not available' }, () => {
  const r = spawnSync('python3', ['-I', '-c', `
import sys, json
sys.path.insert(0, ${JSON.stringify(engineDir)})
import service
probe = '-- run status: aborted: endless loop in the script\\'s own code (no environment access)\\n-- 6 statements recorded in 4.66s\\n\\nInstance.new("Folder")\\nlocal ScreenGui = Instance.new("ScreenGui")\\nlocal Frame = Instance.new("Frame")\\nlocal Path2D = Instance.new("Path2D")\\nFrame.Parent = ScreenGui\\nPath2D.Parent = Frame\\n'
empty = '-- run status: script error: Script:3: invalid argument #1 to \\'readu8\\' (buffer expected, got nil)\\n-- 0 statements recorded in 0.04s\\n'
real = '-- run status: finished\\n-- 3 statements recorded\\nlocal Players = game:GetService("Players")\\nprint(Players.LocalPlayer.Name)\\n'
cut = '-- run status: script error: x\\n-- 3 statements recorded\\nprint("a")\\n'
print(json.dumps([service.trace_facts(t, 'trace-assisted') for t in (probe, empty, real, cut)] + [service.trace_facts('print(1)', 'devirtualized')]))
`], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  const [probe, empty, real, cut, lifted] = JSON.parse(r.stdout);
  assert.equal(probe.probeOnly, true); assert.equal(probe.observedProgram, false);
  assert.equal(empty.statements, 0); assert.equal(empty.observedProgram, false);
  assert.equal(real.observedProgram, true); assert.equal(real.finished, true);
  assert.equal(cut.observedProgram, true); assert.equal(cut.finished, false);
  assert.equal(lifted, null, 'a lifted program is not judged as a trace');
});

test('engine service on Luraph v15.1: "no program observed", never ok', { skip: (!hasPython && 'python3 is not available') || (!have('Luraph/v15.1/390ea6acb88b8f9f.lua') && 'the sample collection is kept locally only'), timeout: 300_000 }, () => {
  const r = spawnSync('python3', ['-I', path.join(engineDir, 'service.py'), path.join(samples, 'Luraph/v15.1/390ea6acb88b8f9f.lua')], { encoding: 'utf8', maxBuffer: 64 << 20, timeout: 280_000 });
  const j = JSON.parse(r.stdout);
  assert.equal(j.ok, false);
  assert.equal(j.error.code, 'no_program_observed');
  assert.equal(j.trace.probeOnly, true);
});

test('engine service (Test 8): the v14 engines write the run status to their log only; a run that failed after Luraph v14’s probe is not a reconstruction', { skip: !hasPython && 'python3 is not available' }, () => {
  const r = spawnSync('python3', ['-I', '-c', `
import sys, json
sys.path.insert(0, ${JSON.stringify(engineDir)})
import service
t = 'local connection = game.AttributeChanged:Connect(function(attribute)\\nend)\\nconnection:Disconnect()\\nlocal HttpService = game:GetService("HttpService")\\nlocal connection5 = HttpService.AttributeChanged:Connect(function(attribute5)\\nend)\\nconnection5:Disconnect()\\n'
log = ['[*] engine: Luraph v14.8', '[*] run status: script error: Script:1: buffer access out of bounds', '[*] static v14 lift resolved to bootstrap/runtime scaffolding']
print(json.dumps([service.trace_facts(t, 'trace-assisted', log), service.trace_facts('local HttpService = game:GetService("HttpService")\\nprint(HttpService:JSONEncode({}))\\n', 'trace-assisted', ['[*] run status: finished'])]))
`], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  const [probe, real] = JSON.parse(r.stdout);
  assert.equal(probe.status, 'script error: Script:1: buffer access out of bounds');
  assert.equal(probe.finished, false);
  assert.equal(probe.probeOnly, true);
  assert.equal(probe.observedProgram, false);
  assert.equal(real.observedProgram, true, 'GetService followed by the program’s own use is a program');
});
