// The adaptive engine: what it finds from the shape of the code, what it undoes, what it refuses, and that it leaves ordinary code alone.
//
// Behaviour is compared with QuickSilver's own interpreter here (fast, always available); tests/adaptive-behaviour.test.mjs repeats the
// comparison on real Lua for programs obfuscated by independent transformations.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { runSource } from '../src/sandbox/sandbox.js';
import { AdaptiveEngine } from '../src/adaptive/engine.js';
import { analyse } from '../src/adaptive/analysis.js';
import { opaqueContext, constantCondition } from '../src/adaptive/absval.js';
import { recoverDispatchers } from '../src/adaptive/strategies/dispatch.js';
import { walk } from '../src/core/walk.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const run = (src, options) => { const ast = parse(src); const r = new AdaptiveEngine().run(ast, options); return { ast, r, text: print(ast) }; };
const output = (src) => { const r = runSource(src, { fuel: 5_000_000, timeMs: 4000 }); assert.ok(r.ok, `${r.error}\n${src.slice(0, 300)}`); return r.output; };
const same = (src, options) => { const o = run(src, options); assert.equal(output(o.text), output(src), `behaviour changed:\n${o.text}`); return o; };
const decisions = (r, outcome) => r.decisions.filter((d) => d.outcome === outcome && !d.strategy.startsWith('cleanup.'));

// ---- dispatch loops -----------------------------------------------------------------------------------------------------------

test('an if/elseif chain on a state variable is read back into loops and branches', () => {
  const src = `
local function f(n)
  local acc, i = 0, 1
  local s = 5
  while true do
    if s == 5 then acc = 0; i = 1; s = 9
    elseif s == 9 then if i <= n then s = 2 else s = 7 end
    elseif s == 2 then acc = acc + i; i = i + 1; s = 9
    elseif s == 7 then return acc
    elseif s == 11 then print("never"); s = 5 end
  end
end
print(f(10), f(0), f(3))`;
  const o = same(src);
  assert.equal(o.r.score.after, 0);
  assert.ok(!/\bs\b/.test(o.text), `the state variable is gone:\n${o.text}`);
  assert.ok(!/never/.test(o.text), 'a block no state reaches is dropped');
});

test('a binary-search tree of comparisons is read the same way', () => {
  const src = `
local x, state = 3, 40
while true do
  if state > 30 then
    if state > 50 then print("late", x) break
    else x = x * 2; state = state + 25 end
  elseif state > 10 then print("mid"); state = state - 20
  else print("low"); state = 99 end
end
print("after", x)`;
  const o = same(src);
  assert.equal(o.r.score.after, 0);
});

test('sequential selections (several ifs one after the other) become one block each', () => {
  const o = same(`
local s, out = 1, {}
repeat
  if s == 1 then out[#out + 1] = "a"; s = 2 end
  if s == 2 then out[#out + 1] = "b"; s = 3 end
  if s == 3 then out[#out + 1] = "c"; s = 0 end
until s == 0
print(table.concat(out))`);
  assert.equal(o.r.score.after, 0);
});

test('the next state may be a delta, a choice, a bit operation or a table lookup', () => {
  const o = same(`
local NEXT = { 4, 5, 6 }
local s, n, log = 10, 0, {}
while s ~= 0 do
  if s == 10 then log[#log + 1] = "start"; s = s + 5
  elseif s == 15 then n = n + 1; s = (n < 3) and 10 or 20
  elseif s == 20 then log[#log + 1] = "x"; s = bit32.bxor(20, 19)
  elseif s == 7 then log[#log + 1] = "end"; s = NEXT[1] - 4 end
end
print(table.concat(log, ","), n)`);
  assert.equal(o.r.score.after, 0);
});

test('states may be strings or booleans, and a leaf may break, return or continue', () => {
  const o = same(`
local function find(list, want)
  local i, state = 0, "next"
  while true do
    if state == "next" then
      i = i + 1
      if i > #list then return nil end
      state = "test"
    elseif state == "test" then
      if list[i] == want then state = "found" else state = "next" end
    elseif state == "found" then
      return i
    end
  end
end
print(find({ "a", "b", "c" }, "c"), find({ "a" }, "z"))`);
  assert.equal(o.r.score.after, 0);
});

test('locals a block declares do not capture a variable of the same name elsewhere', () => {
  const src = `
local x = 10
local s = 1
while true do
  if s == 1 then local x = 5; print(x); s = 2
  elseif s == 2 then print(x); s = 3
  elseif s == 3 then break end
end`;
  const o = same(src);
  assert.equal(o.r.score.after, 0);
  assert.equal(output(o.text), '5\n10\n');
});

test('a loop that walks data with a state machine inside is the program’s own logic and is left alone', () => {
  const src = `
local state, trace = "start", {}
for _, ch in ipairs({ "a", "b", "c" }) do
  if state == "start" then if ch == "a" then state = "seen" end
  elseif state == "seen" then if ch == "b" then state = "pair" else state = "start" end
  elseif state == "pair" then state = "done" end
  trace[#trace + 1] = state
end
print(state, table.concat(trace, ">"))`;
  const o = run(src);
  assert.equal(o.r.score.before, 0);
  assert.equal(decisions(o.r, 'accepted').length, 0);
  assert.equal(output(o.text), output(src));
});

test('a counting loop is not mistaken for a dispatcher', () => {
  const o = run('local i = 0\nwhile i < 5 do\n  if i == 1 then print("one") end\n  i = i + 1\nend');
  assert.equal(o.r.hypotheses.filter((h) => h.kind === 'dispatcher').length, 0);
});

test('what cannot be read is left exactly as it was, with the reason', () => {
  const cases = [
    ['the state is used outside the loop', 'local s = 1\nwhile true do\n  if s == 1 then s = 2\n  elseif s == 2 then s = 3\n  elseif s == 3 then break end\nend\nprint(s)'],
    ['computed from the program', 'local n = tonumber(io and "1" or "1")\nlocal s = 1\nwhile true do\n  if s == 1 then s = s + n\n  elseif s == 2 then s = s + n + n\n  elseif s == 4 then break\n  elseif s == 3 then s = 4 end\nend'],
    ['reads the state', 'local s, fns = 1, {}\nwhile true do\n  if s == 1 then fns[1] = function() return s end; s = 2\n  elseif s == 2 then s = 3\n  elseif s == 3 then break end\nend'],
  ];
  for (const [why, src] of cases) {
    const before = print(parse(src));
    const o = run(src);
    assert.equal(o.text, before, `${why}: the program must not change`);
    assert.ok(o.r.residual.some((x) => x.kind === 'dispatcher'), `${why}: reported as left`);
  }
});

test('recoverDispatchers lists why a loop was refused', () => {
  const ast = parse('local s = 1\nwhile true do\n  if s == 1 then s = 2\n  elseif s == 2 then s = 3\n  elseif s == 3 then break end\nend\nprint(s)');
  const r = recoverDispatchers(ast);
  assert.equal(r.changed, 0);
  assert.match(r.refused[0].why, /state is used outside/);
});

// ---- opaque predicates ---------------------------------------------------------------------------------------------------------

test('opaque predicates are decided by proof, and only what is proved', () => {
  const ast = parse(`
local x, y, n = 7, 3, #arg
local p = param()
for i = 1, 10 do
  if i * i >= 0 then end
  if (i * i + i) % 2 == 0 then end
  if (7 * i + 1) % 7 == 1 then end
  if (i * i) % 4 == 2 then end
  if i > 20 then end
end
if n * n >= 0 then end
if (n * (n + 1)) % 2 ~= 0 then end
if p * p >= 0 then end
if p == p then end
if x == x then end`);
  const oc = opaqueContext(ast, analyse(ast));
  const found = [];
  walk(ast, (n) => { if (n.type === 'If') { const r = constantCondition(n.clauses[0].cond, oc); found.push(r ? `${r.value}:${r.why}` : '-'); } });
  assert.deepEqual(found, ['true:interval', 'true:modular', 'true:modular', 'false:modular', 'false:interval', 'true:interval', 'false:modular', '-', '-', 'true:constant']);
});

test('a flag the author named is not an opaque predicate', () => {
  const o = run('local verbose = false\nif verbose then print("debug") end\nprint("done")');
  assert.equal(o.r.hypotheses.filter((h) => h.kind === 'opaque-predicate').length, 0);
});

test('opaque branches collapse to the code that runs', () => {
  const o = same(`
local a, b = 12, 5
if (a * a + a) % 2 == 0 then print("real") else print("junk") end
if (b * b) % 4 == 2 then print("junk2") end
while (7 * b + 1) % 7 ~= 1 do print("junk3") end
print("end")`);
  assert.equal(o.r.score.after, 0);
  assert.ok(!/junk/.test(o.text));
});

// ---- call proxies ---------------------------------------------------------------------------------------------------------------

test('proxies named like machine output are replaced by what they do', () => {
  const o = same(`
local function P__1(a, b) return a + b end
local function P__2(a, b) return a * b end
local function K__3() return 42 end
print(P__1(2, 3), P__2(P__1(1, 1), 4), K__3())`);
  assert.ok(!/P__|K__/.test(o.text), o.text);
});

test('a helper the author wrote and named is kept', () => {
  const src = 'local function double(x) return x * 2 end\nprint(double(21))';
  const o = run(src);
  assert.match(o.text, /double/);
});

test('arguments are never reordered past a call that could see the difference', () => {
  const src = `
local log = {}
local function P__1(a, b) return b - a end
local function g(v) log[#log + 1] = v; return v end
print(P__1(g(10), g(3)), table.concat(log, ","))`;
  const o = same(src);
  assert.match(o.text, /P__1/, 'the swapped-operand proxy stays when its arguments have effects');
});

test('several tiny wrappers around operators are a disguise whatever they are called', () => {
  const o = same(`
local function plus(a, b) return a + b end
local function minus(a, b) return a - b end
local function times(a, b) return a * b end
local function join(a, b) return a .. b end
print(plus(1, 2), plus(3, 4), plus(5, 6), minus(9, 1), minus(8, 2), minus(7, 3), times(2, 3), times(4, 5), times(6, 7), join("a", "b"), join("c", "d"), join("e", "f"))`);
  assert.ok(!/function plus/.test(o.text), o.text);
});

// ---- constant tables ---------------------------------------------------------------------------------------------------------------

test('a table of constants read by computed keys is replaced by the values', () => {
  const o = same(`
local T__1 = { "alpha", "beta", "gamma", "delta" }
local k = 2
print(T__1[1], T__1[k + 1], T__1[#T__1], T__1[k * 2 - 3])`);
  assert.ok(!/T__1/.test(o.text), o.text);
});

test('a settings table, or a table anything writes to, is not touched', () => {
  const a = run('local cfg = { speed = 24, jump = 50, label = "x" }\nprint(cfg.speed, cfg["jump"], cfg.label)');
  assert.match(a.text, /cfg/);
  const b = run('local T__1 = { "a", "b", "c", "d" }\nT__1[2] = "z"\nprint(T__1[1], T__1[2], T__1[3], T__1[4])');
  assert.match(b.text, /T__1/);
  const c = run('local T__1 = { "a", "b", "c", "d" }\nlocal function use(t) t[1] = 0 end\nuse(T__1)\nprint(T__1[1], T__1[2], T__1[3], T__1[4])');
  assert.match(c.text, /T__1/);
});

// ---- decoders, and the sandbox gate ------------------------------------------------------------------------------------------

const DECODER = `
local function D__1(t, k)
  local r = {}
  for i = 1, #t do r[i] = string.char((t[i] - k - i) % 256) end
  return table.concat(r)
end
local K = 21
print(D__1({ 137, 134, 142, 142, 144 }, K), D__1({ 140, 137, 148, 148, 151 }, K))`;

test('a decoder is found by what it does, and waits for the sandbox when it is off', () => {
  const off = run(DECODER);
  assert.ok(off.r.hypotheses.some((h) => h.kind === 'string-decoder'));
  assert.ok(off.r.blocked.some((b) => b.why === 'sandbox'));
  assert.match(off.r.residual.find((x) => x.kind === 'string-decoder').reason, /sandbox/);
  assert.match(off.text, /D__1/);
});

test('with the sandbox on the decoder’s calls become the text, and the decoder goes', () => {
  const src = DECODER.replace('K = 21', 'K = 21');
  const before = output(src);
  const on = run(src, { sandbox: { enabled: true } });
  assert.equal(on.r.score.after, 0);
  assert.ok(!/D__1/.test(on.text), on.text);
  assert.equal(output(on.text), before);
});

// ---- the engine itself ----------------------------------------------------------------------------------------------------------

test('a change that makes things worse is undone, and so is one that breaks the program', () => {
  const src = 'print("a")\nprint("b")';
  const engine = new AdaptiveEngine([]);
  engine.register({
    id: 'test.worse', title: 'a strategy that disguises', order: 1, always: true,
    observe: (ast) => { let n = 0; walk(ast, (x) => { if (x.type === 'While') n++; }); return Array.from({ length: n }, () => ({ kind: 'dispatcher', line: 1, label: 'loop', evidence: [], confidence: 1, weight: 5 })); },
    run: (ast) => { ast.body.push({ type: 'While', cond: { type: 'False' }, body: [] }); return { changed: 1 }; },
  });
  engine.register({
    id: 'test.break', title: 'a strategy that corrupts', order: 2, always: true,
    observe: () => [{ kind: 'x', line: 1, label: 'x', evidence: [], confidence: 1, weight: 1 }],
    run: (ast) => { ast.body.push({ type: 'Local', ids: [{ type: 'Id', name: 'end' }], values: [] }); return { changed: 1 }; },
  });
  engine.register({
    id: 'test.global', title: 'a strategy that leaks a name', order: 3, always: true,
    observe: () => [{ kind: 'y', line: 1, label: 'y', evidence: [], confidence: 1, weight: 1 }],
    run: (ast) => { ast.body.push({ type: 'Assign', targets: [{ type: 'Name', name: 'leaked' }], values: [{ type: 'Number', value: 1, raw: null }] }); return { changed: 1 }; },
  });
  engine.register({
    id: 'test.throw', title: 'a strategy that fails', order: 4, always: true,
    observe: () => [{ kind: 'z', line: 1, label: 'z', evidence: [], confidence: 1, weight: 1 }],
    run: () => { throw new Error('boom'); },
  });
  const ast = parse(src);
  const r = engine.run(ast);
  assert.equal(print(ast), print(parse(src)), 'the program is exactly what it was');
  const by = (id) => r.decisions.find((d) => d.strategy === id);
  assert.equal(by('test.worse').outcome, 'rejected');
  assert.match(by('test.worse').note, /did not reduce/);
  assert.equal(by('test.break').outcome, 'rejected');
  assert.match(by('test.break').note, /does not parse/);
  assert.equal(by('test.global').outcome, 'rejected');
  assert.match(by('test.global').note, /leaked/);
  assert.equal(by('test.throw').outcome, 'failed');
});

test('a strategy added with register is used like any other', () => {
  const engine = new AdaptiveEngine([]);
  engine.register({
    id: 'test.print', title: 'turn shout() into print()', order: 10,
    observe: (ast) => { const out = []; walk(ast, (n) => { if (n.type === 'Call' && n.fn.type === 'Name' && n.fn.name === 'shout') out.push({ kind: 'dynamic-code', line: n.line || 1, label: 'shout call', evidence: ['named shout'], confidence: 1, weight: 1 }); }); return out; },
    run: (ast) => { let changed = 0; walk(ast, (n) => { if (n.type === 'Call' && n.fn.type === 'Name' && n.fn.name === 'shout') { n.fn = { type: 'Name', name: 'print' }; changed++; } }); return { changed }; },
  });
  const ast = parse('shout("a")\nshout("b")\nprint("c")');
  const r = engine.run(ast);
  assert.equal(print(ast).split('\n').filter(Boolean).join('\n'), 'print("a")\nprint("b")\nprint("c")');
  assert.equal(r.score.before, 2);
  assert.equal(r.score.after, 0);
});

test('the findings are read without changing anything', () => {
  const ast = parse('local function P__1(a, b) return a + b end\nprint(P__1(1, 2), P__1(2, 3), P__1(3, 4))');
  const before = print(ast);
  const seen = new AdaptiveEngine().observe(ast);
  assert.equal(print(ast), before);
  assert.ok(seen.findings.some((f) => f.kind === 'call-proxy'));
  assert.ok(seen.score > 0);
});

test('an interpreter inside the script is reported, not attempted', () => {
  const src = `
local code = { {1, 5}, {1, 7}, {2}, {9} }
local pc, stack = 1, {}
while true do
  local ins = code[pc]
  local op = ins[1]
  if op == 1 then stack[#stack + 1] = ins[2]
  elseif op == 2 then local b = table.remove(stack); local a = table.remove(stack); stack[#stack + 1] = a + b
  elseif op == 3 then stack[#stack] = stack[#stack] * 2
  elseif op == 4 then stack[#stack] = stack[#stack] - 1
  elseif op == 5 then stack[#stack] = -stack[#stack]
  elseif op == 6 then stack[#stack + 1] = 0
  elseif op == 9 then print(stack[#stack]) break end
  pc = pc + 1
end`;
  const o = run(src);
  assert.ok(o.r.residual.some((x) => x.kind === 'interpreter'), JSON.stringify(o.r.residual));
  assert.match(o.r.residual.find((x) => x.kind === 'interpreter').reason, /interpreter/);
});

// ---- no harm ----------------------------------------------------------------------------------------------------------------------

test('ordinary programs are left as they are', () => {
  const dirs = ['corpus/originals', 'corpus/adaptive'];
  let programs = 0;
  for (const dir of dirs) {
    for (const f of fs.readdirSync(path.join(here, dir)).filter((x) => x.endsWith('.lua'))) {
      const src = fs.readFileSync(path.join(here, dir, f), 'latin1');
      const ast = parse(src);
      const r = new AdaptiveEngine().run(ast, { sandbox: { enabled: true } });
      assert.equal(r.score.before, 0, `${f}: nothing to find (${JSON.stringify(r.hypotheses.map((h) => h.label))})`);
      assert.equal(decisions(r, 'accepted').length, 0, `${f}: no strategy acted`);
      programs++;
    }
  }
  assert.ok(programs >= 14);
});
