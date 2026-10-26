// verifyRecovery: both programs run in the sandbox and what each one did is compared.

import test from 'node:test';
import assert from 'node:assert/strict';
import { verifyRecovery } from '../src/adaptive/verify.js';
import { verifySource } from '../src/api.js';
import { recover } from '../src/recover/pipeline.js';

const PROGRAM = `
local Players = game:GetService("Players")
local function greet(name) print("hello " .. name) end
for i = 1, 3 do greet("p" .. i) end
workspace.Gravity = 100
local part = Instance.new("Part")
part.Name = "Marker"
part.Parent = workspace`;

test('the same program twice behaves the same', () => {
  const v = verifyRecovery(PROGRAM, PROGRAM);
  assert.equal(v.verdict, 'identical');
  assert.ok(v.original.events > 5);
});

test('a program rewritten into another form that does the same is identical', () => {
  const other = `
local Players = game:GetService("Players")
print("hello p1") print("hello p2") print("hello p3")
workspace.Gravity = 100
local part = Instance.new("Part")
part.Name = "Marker"
part.Parent = workspace`;
  const v = verifyRecovery(PROGRAM, other);
  assert.equal(v.verdict, 'identical', JSON.stringify(v.difference));
});

test('a program that does something else is reported with the first difference', () => {
  const other = PROGRAM.replace('Gravity = 100', 'Gravity = 50');
  const v = verifyRecovery(PROGRAM, other);
  assert.equal(v.verdict, 'different');
  assert.ok(v.difference && v.difference.original !== v.difference.recovered);
  assert.match(v.difference.original + v.difference.recovered, /Gravity/);
});

test('a program that stops early or goes on is different', () => {
  assert.equal(verifyRecovery(PROGRAM, PROGRAM.replace('part.Parent = workspace', '')).verdict, 'different');
  assert.equal(verifyRecovery(PROGRAM, `${PROGRAM}\nprint("more")`).verdict, 'different');
});

test('printed output counts', () => {
  assert.equal(verifyRecovery('print("a")', 'print("b")').verdict, 'different');
  assert.equal(verifyRecovery('print("a")', 'print("a")').verdict, 'identical');
});

test('a run cut short by a limit is not called identical', () => {
  const spin = 'local n = 0\nwhile true do n = n + 1 end';
  const v = verifyRecovery(spin, spin, { fuel: 200_000, timeMs: 1500 });
  assert.equal(v.verdict, 'inconclusive');
  assert.ok(v.notes.some((n) => /limit/.test(n)));
});

test('a program with nothing to observe is a weak check and says so', () => {
  const v = verifyRecovery('local x = 1 + 1', 'local x = 2');
  assert.equal(v.verdict, 'inconclusive');
  assert.ok(v.notes.some((n) => /weak check/.test(n)));
});

test('a recovered flattened program is verified against the one it came from', () => {
  const original = `
local s, n = 1, 0
local out = {}
while true do
  if s == 1 then game:GetService("Players").LocalPlayer.Name = "x"; s = 2
  elseif s == 2 then n = n + 1; s = n < 3 and 2 or 3
  elseif s == 3 then workspace.Gravity = n * 10; break end
end
print("done", n)`;
  const r = recover(original, {});
  assert.equal(r.adaptive.score.after, 0);
  const v = verifyRecovery(original, r.output);
  assert.equal(v.verdict, 'identical', JSON.stringify(v));
});

test('the api operation takes the recovered text as an option', () => {
  const r = verifySource('print(1)', { recovered: 'print(1)' });
  assert.equal(r.ok, true);
  assert.equal(r.verdict, 'identical');
  assert.ok(typeof r.ms === 'number');
});
