// Copies of values that never change are read as the values (src/passes/stable.js), and what that makes possible: a decoder reached
// through such copies is found and evaluated; code fetched from the network is listed as what is left but is not scored as a disguise.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { analyze } from '../src/core/scope.js';
import { propagateStable } from '../src/passes/stable.js';
import { recover } from '../src/recover/pipeline.js';
import { AdaptiveEngine } from '../src/adaptive/engine.js';
import * as oracle from './helpers/lua-oracle.mjs';

after(() => oracle.stopOracle());
const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';

const run = (src) => { const ast = parse(src); const r = propagateStable(ast); return { ...r, text: print(ast), ast }; };
const globalsOf = (ast) => [...analyze(ast).globals.keys()].sort();

test('a copy of a local that never changes is read as the local, and the copy goes', () => {
  const r = run('local a = 1 + x\nlocal b = a\nprint(b, b)');
  assert.ok(r.changed >= 2);
  assert.doesNotMatch(r.text, /local b/);
  assert.match(r.text, /print\(a, a\)/);
});

test('a copy of a variable that is assigned later is left alone', () => {
  const r = run('local a = f()\nlocal b = a\na = g()\nprint(b)');
  assert.equal(r.changed, 0);
  assert.match(r.text, /local b = a/);
});

test('a copy that is itself assigned is left alone', () => {
  const r = run('local a = f()\nlocal b = a\nb = b + 1\nprint(b)');
  assert.equal(r.changed, 0);
});

test('a chain of copies is followed to its end in one call, and nothing is left dangling', () => {
  const r = run('local a = f()\nlocal b = a\nlocal c = b\nlocal d = c\nprint(d, c, b)');
  assert.match(r.text, /print\(a, a, a\)/);
  assert.doesNotMatch(r.text, /local [bcd]\b/);
  assert.deepEqual(globalsOf(r.ast), ['f', 'print']);
});

test('copies made inside a nested function of something captured from outside are read through', () => {
  const r = run('local function dec(s) return s end\nlocal t = {}\nlocal function use()\n  local d, c = dec, t\n  return c[d("k")]\nend\nprint(use())');
  assert.match(r.text, /t\[dec\("k"\)\]/);
  assert.deepEqual(globalsOf(r.ast), ['print']);
});

test('a string that is data is put where it is read; a long one read twice stays a variable; readable constants keep their names', () => {
  const data = (n) => '\\200\\201\\202\\203'.repeat(n);
  const short = run(`local s = "${data(2)}"\nprint(s, s)`);
  assert.match(short.text, /print\("[^"]*", "[^"]*"\)/);
  assert.doesNotMatch(short.text, /local s/);
  const long = run(`local s = "${data(30)}"\nprint(s, s)`);
  assert.equal(long.changed, 0);
  const once = run(`local s = "${data(30)}"\nprint(s)`);
  assert.doesNotMatch(once.text, /local s/);
  const readable = run('local url = "https://example.com/key"\nlocal maxWeight = 40\nprint(url, maxWeight)');
  assert.equal(readable.changed, 0);
  assert.match(readable.text, /local maxWeight = 40/);
});

test('a literal in front of a method call keeps its parentheses', () => {
  const r = run('local s = "\\200\\201"\nprint(s:rep(2))');
  assert.match(r.text, /\("[^"]*"\):rep\(2\)/);
  assert.doesNotThrow(() => parse(r.text));
});

test('a name the copy would be captured by is not substituted', () => {
  // `x` is a copy of the outer `y`; between the copy and its read a different `y` is declared, so `x` must not become `y`
  const r = run('local y = f()\nlocal function g()\n  local x = y\n  do\n    local y = h()\n    print(x, y)\n  end\nend\ng()');
  assert.match(r.text, /local x = y/);
  assert.match(r.text, /print\(x, y\)/);
  assert.deepEqual(globalsOf(r.ast), ['f', 'h', 'print']);
});

test('once the name that stood in the way is gone the copy is followed in the next round', () => {
  // the inner `y` is a literal, which is read as itself and removed, and then the outer `y` is no longer hidden
  const r = run('local y = f()\nlocal function g()\n  local x = y\n  do\n    local y = "\\200\\201"\n    print(x, y)\n  end\nend\ng()');
  assert.match(r.text, /print\(y, "/);
  assert.doesNotMatch(r.text, /local x|local y = "/);
  assert.deepEqual(globalsOf(r.ast), ['f', 'print']);
});

test('a loop variable is a stable source inside the iteration', () => {
  const r = run('for i = 1, 3 do\n  local j = i\n  print(function() return j end)\nend');
  assert.match(r.text, /return i/);
});

test('behaviour is unchanged on real Lua', { skip }, async () => {
  const programs = [
    'local a = 7\nlocal b = a\nlocal c = b * 2\nlocal t = {}\nlocal f = function(x) return x + c end\nlocal g = f\nfor i = 1, 3 do local k = i; t[#t + 1] = function() return g(k) + b end end\nfor _, h in ipairs(t) do print(h()) end',
    'local s = "\\200\\201"\nlocal n = s\nprint(n:rep(3):byte(1, -1))',
    'local x = 10\nlocal function p()\n  local y = x\n  do local x = 3; print(y, x) end\nend\np()',
  ];
  for (const src of programs) {
    const want = await oracle.runLua(src, 'lua51');
    const r = run(src);
    const got = await oracle.runLua(r.text, 'lua51');
    assert.ok(want.ok && got.ok, `${want.error || ''} ${got.error || ''}`);
    assert.equal(got.stdout, want.stdout, r.text);
  }
});

// ---- a decoder behind copies --------------------------------------------------------------------------------------------------

const encode = (text, k) => Array.from(text, (ch, i) => ((ch.charCodeAt(0) - k - (i + 1)) % 256 + 256) % 256);
const lit = (bytes) => `"${bytes.map((b) => `\\${String(b).padStart(3, '0')}`).join('')}"`;
const DECODER = `
local Q = {}
local function g(s, k)
  local out = {}
  for i = 1, #s do out[i] = string.char((s:byte(i) + k + i) % 256) end
  Q[k] = table.concat(out)
  return k
end`;

test('strings behind a decoder that is reached through local copies are all decoded', () => {
  const words = ['alpha', 'bravo', 'charlie', 'delta', 'echo', 'foxtrot'];
  const call = (w, i) => `g(${lit(encode(w, 1000 + i))}, ${1000 + i})`;
  const direct = words.slice(0, 4).map((w, i) => `print(Q[${call(w, i)}])`).join('\n');
  // the last two are read inside a function that copied the decoder and the cache first, as a rebuilt virtual machine does
  const copied = `local function late()\n  local d, c = g, Q\n  print(c[d(${lit(encode(words[4], 1004))}, 1004)])\n  print(c[d(${lit(encode(words[5], 1005))}, 1005)])\nend\nlate()`;
  const src = `${DECODER}\n${direct}\n${copied}`;
  const r = recover(src, { sandbox: { enabled: true } });
  assert.equal(r.ok, true);
  for (const w of words) assert.match(r.output, new RegExp(`"${w}"`), `"${w}" is in the open\n${r.output}`);
  assert.doesNotMatch(r.output, /\bg\(/);
});

// ---- code fetched at run time -------------------------------------------------------------------------------------------------

test('loadstring of a network fetch is listed as what is left and does not count as a disguise', () => {
  const engine = new AdaptiveEngine();
  const ast = parse('loadstring(game:HttpGet("https://example.com/a.lua"))()\nlocal ok, r = pcall(function() return loadstring(game:HttpGet("https://example.com/b.lua" .. "?x=1"))() end)');
  const seen = engine.observe(ast);
  assert.equal(seen.score, 0, JSON.stringify(seen.parts));
  assert.equal(seen.findings.filter((f) => f.kind === 'remote-loader').length, 2);
  assert.match(seen.findings.find((f) => f.kind === 'remote-loader').label, /example\.com\/a\.lua/);
  const report = engine.run(ast);
  assert.equal(report.residual.filter((x) => x.kind === 'remote-loader').length, 2);
  assert.match(report.residual[0].reason, /not in this file/);
});

test('loadstring of a string built in the script is still a layer', () => {
  const engine = new AdaptiveEngine();
  const seen = engine.observe(parse('local s = "pri" .. "nt(1)"\nloadstring(s)()'));
  assert.ok(seen.findings.some((f) => f.kind === 'dynamic-code'));
  assert.ok(seen.score > 0);
});
