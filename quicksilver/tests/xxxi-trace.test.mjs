// Prompt XXXI (KNOWN-ISSUES #116): the trace writes a concatenation with a stand-in in one form whatever its grouping, so two programs
// that build the same string trace alike (MoonSec V3 a110bb69: `"…php?key=" .. s` against the rebuilt `"…php" .. "?key=" .. s`), and
// programs that build different strings still trace differently.
import test from 'node:test';
import assert from 'node:assert/strict';
import { traceScript } from '../src/trace/trace.js';
import { verifyRecovery } from '../src/adaptive/verify.js';

const events = (src) => traceScript(src, {}).events.filter((e) => e.kind !== 'load').map((e) => e.text);
const pre = 'local n = game.Players.LocalPlayer.Name\n';

test('grouping and split constants do not change the trace of a concatenation', () => {
  assert.deepEqual(events(`${pre}print("a" .. ("b" .. n))`), events(`${pre}print("ab" .. n)`));
  assert.deepEqual(events(`${pre}print((n .. "a") .. "b")`), events(`${pre}print(n .. "ab")`));
  assert.deepEqual(events(`${pre}print("x" .. n .. "y" .. "z")`), events(`${pre}print("x" .. (n .. "yz"))`));
  assert.deepEqual(events(`${pre}print(n .. "ab")`), ['print(game.Players.LocalPlayer.Name .. "ab")']);
});

test('different strings still trace differently; numbers are not joined to text', () => {
  assert.notDeepEqual(events(`${pre}print(n .. "a")`), events(`${pre}print(n .. "b")`));
  assert.notDeepEqual(events(`${pre}print("a" .. n)`), events(`${pre}print(n .. "a")`));
  // (n .. " ") .. 1 keeps the number apart: its text depends on the Lua version
  assert.deepEqual(events(`${pre}print((n .. " ") .. 1)`), ['print(game.Players.LocalPlayer.Name .. " " .. 1)']);
  assert.notDeepEqual(events(`${pre}print((n .. " ") .. 1)`), events(`${pre}print(n .. " 1")`));
});

test('the behaviour comparison: equal strings built in two groupings are identical, different ones are not', () => {
  const a = `${pre}game:HttpGet("http://example.invalid/check.php?key=" .. n .. "&v=1")`;
  const b = `${pre}game:HttpGet("http://example.invalid/check.php" .. "?key=" .. n .. "&v=" .. "1")`;
  const c = `${pre}game:HttpGet("http://example.invalid/check.php?key=" .. n .. "&v=2")`;
  assert.equal(verifyRecovery(a, b).verdict, 'identical');
  assert.equal(verifyRecovery(a, c).verdict, 'different');
});
