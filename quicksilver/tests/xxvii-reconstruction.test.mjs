// Prompt XXVII Part I/III: reconstruction intelligence — masked strings read back by evidence, names recovered from the program's own
// expressions (never invented), and placeholder names counted in the evidence of every result.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { rankReadings, textCost, KNOWN_NAMES } from '../src/recover/keysearch.js';
import { liftZarthaVm, repairZarthaSource } from '../src/recover/zartha-vm.js';
import { renamePass, looksObfuscated, SIGNAL_PARAMS } from '../src/passes/rename.js';
import { namingEvidence } from '../src/validate/evidence.js';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { recoverSource } from '../src/api.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const zdir = path.join(here, 'corpus', 'obfuscated', 'zartha');
const read = (p) => fs.readFileSync(p, 'utf8');
const xor = (s, k) => [...s].map((c) => String.fromCharCode(c.charCodeAt(0) ^ k)).join('');
test.after(() => oracle.stopOracle?.());

// ---- key search ------------------------------------------------------------------------------------------------------------------------

test('key search: a name the runtime defines decides a masked global or method on its own', () => {
  for (const [plain, k, role] of [['game', 3, 'global'], ['pcall', 16, 'global'], ['setmetatable', 27, 'global'], ['GetService', 9, 'method'], ['WaitForChild', 21, 'method'], ['Players', 10, 'field']]) {
    const r = rankReadings(xor(plain, k), { role });
    assert.equal(r.decided, true, `${plain}: ${r.why}`);
    assert.equal(r.text, plain);
    assert.equal(r.key, k);
    assert.match(r.why, /name the runtime defines/);
  }
});

test('key search: ordinary text is decided by being far more word-like than every other reading; patterns and formats by their shape', () => {
  for (const [plain, k] of [['Tamper detected', 19], ['configured', 23], ['heartbeat done', 24], ['QuickSilver', 18], ['hello', 7]]) {
    const r = rankReadings(xor(plain, k), { role: 'value' });
    assert.equal(r.text, plain, `${plain}: ${r.why} ${r.ranked.slice(0, 3).map((x) => x.text)}`);
  }
  assert.equal(rankReadings(xor('%d+', 13), { role: 'pattern' }).text, '%d+');
  assert.equal(rankReadings(xor('%5.2f|%-6s|%03d', 14), { role: 'value' }).text, '%5.2f|%-6s|%03d');
  assert.equal(rankReadings(xor('#', 5), { role: 'select' }).text, '#', "select() takes only '#' or a number");
  assert.ok(textCost('the quick brown fox') < textCost('qhb rvdcm atpbf zps'));
});

test('key search: what the evidence cannot settle is left undecided, never guessed', () => {
  assert.equal(rankReadings(xor('ab', 5)).decided, false, 'two letters fit many keys');
  assert.equal(rankReadings(xor('.', 9)).decided, false);
  const twoNames = rankReadings('Y', { role: 'global' });
  assert.equal(twoNames.decided, false, 'several readings are runtime names');
  // a plain string (key 0) competes on the same evidence: an unmasked name stays as it is
  assert.equal(rankReadings('WaitForChild', { role: 'method' }).key, 0);
  assert.ok(KNOWN_NAMES.has('HttpGet') && !KNOWN_NAMES.has('foxtrot'));
});

test('zartha constant protection: every string decided by key search is a string of the original program (or one the generator adds)', () => {
  const generator = new Set(['Tamper detected', '_OBFUSCATED', '%d+', '_CRASH']);
  let decided = 0; let undecided = 0;
  for (const f of fs.readdirSync(zdir).filter((x) => /__(constants|all)\.lua$/.test(x))) {
    const orig = read(path.join(here, 'corpus', 'originals', `${f.split('__')[0]}.lua`));
    let src = read(path.join(zdir, f));
    try { parse(src); } catch { src = repairZarthaSource(src).source; }
    globalThis.__zdump = [];
    const r = liftZarthaVm(parse(src));
    const dump = globalThis.__zdump; delete globalThis.__zdump;
    const half = dump.length / 2;
    const first = dump.slice(0, half); const fin = dump.slice(half);
    fin.forEach((d, i) => d.constants.forEach((c, j) => {
      if (typeof c !== 'string' || c === first[i].constants[j]) return;
      assert.ok(orig.includes(c) || KNOWN_NAMES.has(c) || generator.has(c), `${f}: decided ${JSON.stringify(c)} is in neither the original nor the runtime`);
    }));
    decided += r.stats.keysearch.decided;
    undecided += r.stats.keysearch.ambiguous.length;
  }
  assert.ok(decided >= 380, `decided ${decided}`);
  assert.ok(undecided <= 90, `undecided ${undecided}`);
});

test('zartha constant protection: the Roblox program is recovered whole and runs like the original (reference Lua)', { skip: !oracle.available && 'QS_LUA_PYTHON not set' }, async () => {
  for (const f of ['s07_roblox_style__constants.lua', 's07_roblox_style__all.lua']) {
    const r = recoverSource(read(path.join(zdir, f)), {});
    assert.match(r.output, /game:GetService\("Players"\)/);
    assert.match(r.output, /:WaitForChild\("Humanoid"\)/);
    const want = await oracle.runLua(read(path.join(here, 'corpus', 'originals', 's07_roblox_style.lua')), 'lua51');
    const got = await oracle.runLua(r.output, 'lua51');
    assert.ok(want.ok && got.ok, got.error);
    assert.equal(got.stdout, want.stdout, f);
  }
  assert.equal(recoverSource(read(path.join(zdir, 's07_roblox_style__constants.lua')), {}).outcome.outcome, 'syntax-valid-unverified');
});

// ---- names from evidence ---------------------------------------------------------------------------------------------------------------

const renamed = (code) => { const ast = parse(code); renamePass(ast, { mode: 'all' }); return print(ast); };

test('names: the decompiler\'s register temporaries are machine names and get the name their value states', () => {
  for (const n of ['_r3', '_r1_4', '_r3_c1_1', '_r12_c1_1', 'a1', 'up0', 'L_12']) assert.equal(looksObfuscated(n), true, n);
  const out = renamed('local _r3_c1_1 = game:GetService("Players")\nlocal _r4_c1_1 = _r3_c1_1.LocalPlayer\nprint(_r4_c1_1.Name)');
  assert.match(out, /local Players = game:GetService\("Players"\)/);
  assert.match(out, /local localPlayer = Players\.LocalPlayer/);
});

test('names: a local declared empty is named after its first assignment; a call result after what the function returns', () => {
  const out = renamed(`local value1
value1 = workspace.ChildAdded:Connect(function(p) print(p) end)
local function fn(param)
  local humanoid = param:WaitForChild("Humanoid")
  return humanoid
end
local value = fn(game.Players.LocalPlayer.Character)
print(value.Health)`);
  assert.match(out, /local connection\n/);
  assert.match(out, /connection = workspace\.ChildAdded:Connect\(function\(child\)/, 'the documented parameter of ChildAdded');
  assert.match(out, /local function fn\(character\)/, 'every call passes something named Character');
  assert.match(out, /local humanoid = fn\(/, 'fn returns its local humanoid');
});

test('names: nothing is invented — without evidence a placeholder stays a placeholder, and call sites that disagree name nothing', () => {
  const out = renamed('local function f(a1) return a1 + 1 end\nprint(f(1), f(x.Count))');
  assert.doesNotMatch(out, /function \w+\(count\)/, 'one call site with a name and one without: no name');
  const sig = renamed('game.Players.PlayerAdded:Connect(function(a1) print(a1.Name) end)');
  assert.match(sig, /function\(player\)/);
  assert.deepEqual(SIGNAL_PARAMS.Heartbeat, ['deltaTime']);
});

test('evidence: every result counts its placeholder names, and the outcome says so without changing the class', () => {
  const n = namingEvidence(parse('local _r1 = 1 local a1 = 2 local Players = game:GetService("Players") local value = 3 print(_r1, a1, Players, value)'));
  assert.deepEqual(n, { locals: 4, placeholders: 3, params: 0, placeholderParams: 0 });
  const r = recoverSource(read(path.join(zdir, 's05_nested_functions__default.lua')), {});
  assert.ok(r.outcome.evidence.recovery.naming.locals > 0);
  assert.ok(r.outcome.met.some((m) => /local names are placeholders/.test(m)));
  assert.equal(r.outcome.outcome, 'syntax-valid-unverified', 'names do not change what the program does, so they do not change the class');
});
