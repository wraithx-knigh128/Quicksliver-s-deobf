// The clean-up passes for decompiled code (src/passes/idioms.js, src/passes/dataflow.js, the declaration sinking in
// simplify.js). Each program is run on a real Lua 5.1 before and after the pass and must print the same thing; the
// negative cases are the ones where the rewrite would change behaviour, and the pass has to leave them alone.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { booleanResults, orientComparisons, shortCircuits, tableConstructors, bareNils, functionForms } from '../src/passes/idioms.js';
import { dataflowPass } from '../src/passes/dataflow.js';
import { simplifyPass } from '../src/passes/simplify.js';
import * as oracle from './helpers/lua-oracle.mjs';

const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';
after(() => oracle.stopOracle());

/** Apply `pass` and return { text, changed }. */
function apply(src, pass) {
  const ast = parse(src);
  const r = pass(ast);
  return { text: print(ast), changed: r.changed !== undefined ? r.changed : r };
}

async function behaves(src, pass) {
  const { text, changed } = apply(src, pass);
  const a = await oracle.runLua(src, 'lua51');
  const b = await oracle.runLua(text, 'lua51');
  assert.ok(a.ok, a.error);
  assert.ok(b.ok, `${b.error}\n${text}`);
  assert.equal(b.stdout, a.stdout, `behaviour changed:\n${text}`);
  return { text, changed };
}

test('booleanResults: comparisons become the returned value, other conditions are left alone', { skip }, async () => {
  const yes = await behaves(`
local function lt(a, b)
  local v
  if a < b then v = true else v = false end
  return v
end
local function ge(a, b)
  local v
  if a < b then v = false else v = true end
  return v
end
print(lt(1, 2), lt(2, 1), ge(1, 2), ge(2, 1))`, booleanResults);
  assert.equal(yes.changed, 2);
  assert.match(yes.text, /return a < b/);
  assert.match(yes.text, /return not \(a < b\)|return a >= b/);

  // `if x then v = true else v = false end` is `not not x`, not `x`: a table is not `true`
  const no = await behaves(`
local function f(x)
  local v
  if x then v = true else v = false end
  return v
end
print(f({}), f(nil), f(0))`, booleanResults);
  assert.equal(no.changed, 0);
});

test('shortCircuits: `v = a; if not v then v = b end` is `a or b` unless b reads v', { skip }, async () => {
  const yes = await behaves(`
local t = { x = 3 }
local v = t.x
if not v then v = 10 end
local w = t.y
if not w then w = 10 end
local u = t.x
if u then u = "set" end
print(v, w, u)`, shortCircuits);
  assert.equal(yes.changed, 3);
  assert.match(yes.text, /local w = t\.y or 10/);
  assert.match(yes.text, /local u = t\.x and "set"/);

  const no = await behaves(`
local t = {}
local v = t.x
if not v then v = tostring(v) end
print(v)`, shortCircuits);
  assert.equal(no.changed, 0);
});

test('orientComparisons: a literal moves to the right of the operator', { skip }, async () => {
  const r = await behaves(`
local n = 5
print(0 < n, 10 <= n, "a" < "b", n < 0)`, orientComparisons);
  assert.equal(r.changed, 2);
  assert.match(r.text, /n > 0/);
  assert.match(r.text, /n >= 10/);
});

test('tableConstructors: field stores fold into the constructor only when nothing can observe the difference', { skip }, async () => {
  const yes = await behaves(`
local t = {}
t.a = 1
t.b = "two"
t.c = function() return 7 end
print(t.a, t.b, t.c())`, tableConstructors);
  assert.equal(yes.changed, 3);
  assert.match(yes.text, /local t = \{\s+a = 1,\s+b = "two",\s+c = function/);

  // inside the constructor the name `t` is not yet the local, so a closure that reads it must stay outside
  const closure = await behaves(`
t = { a = 9 }
local t = {}
t.c = function() return t.a end
print(t.c())`, tableConstructors);
  assert.equal(closure.changed, 0);

  // the value reads the table being filled
  const self = await behaves(`
local t = {}
t.a = 1
t.b = t.a + 1
print(t.a, t.b)`, tableConstructors);
  assert.match(self.text, /local t = \{ a = 1 \}\nt\.b = t\.a \+ 1/);

  // a captured table whose next value is a call: the call may look at the variable
  const call = await behaves(`
local t = {}
local function peek() return t.a end
t.a = 1
t.b = peek()
print(t.a, t.b)`, tableConstructors);
  assert.equal(call.changed, 0);

  // a repeated key keeps the later value
  const dup = await behaves(`
local t = { a = 1 }
t.a = 2
print(t.a)`, tableConstructors);
  assert.equal(dup.changed, 0);
});

test('bareNils: `local x = nil` is `local x`', { skip }, async () => {
  const r = await behaves('local x = nil\nprint(x)', bareNils);
  assert.equal(r.changed, 1);
  assert.match(r.text, /^local x\n/);
});

test('functionForms: declarations, methods and self capture', { skip }, async () => {
  const r = await behaves(`
local T = {}
T.__index = T
T.new = function(n) return setmetatable({ n = n }, T) end
T.get = function(self_, d) return (self_.n or 0) + d end
local helper = function(x) return x * 2 end
local obj = T.new(4)
print(obj:get(3), helper(5))`, functionForms);
  assert.match(r.text, /function T\.new\(n\)/);
  assert.match(r.text, /function T:get\(d\)/);
  assert.match(r.text, /return \(self\.n or 0\) \+ d/);
  assert.match(r.text, /local function helper\(x\)/);

  // a body that already uses `self` is not turned into a method, even if it is called as one
  const keep = await behaves(`
local T = {}
local self = { k = 7 }
T.f = function(a, b) return b + self.k end
print(T:f(1))`, functionForms);
  assert.match(keep.text, /function T\.f\(a, b\)/);

  // never called with a colon: stays a plain function
  const plain = await behaves(`
local T = {}
T.f = function(a) return a + 1 end
print(T.f(1))`, functionForms);
  assert.match(plain.text, /function T\.f\(a\)/);

  // a recursive local function is not rewritten: `local f = function` does not see itself
  const rec = await behaves(`
f = function() return "global" end
local f = function() return f() end
print(f())`, functionForms);
  assert.match(rec.text, /local f = function/);
});

// ---- data flow -----------------------------------------------------------------------------------------------------

const flow = (src) => behaves(src, dataflowPass);

test('dataflow: the register-machine shape collapses to the statement a person wrote', { skip }, async () => {
  const r = await flow(`
local num, a, b, c, d = 0
for i = 1, 5 do
  a = i
  b = num
  c = b + a
  d = a
  num = c
end
print(num)`);
  assert.ok(r.changed > 0);
  assert.match(r.text, /num = num \+ i/);
});

test('dataflow: evaluation order of calls is kept', { skip }, async () => {
  // t = f() must still run before g() in `x = g() + t`
  const r = await flow(`
local log = {}
local function f() log[#log + 1] = "f" return 1 end
local function g() log[#log + 1] = "g" return 2 end
local t, x
t = f()
x = g() + t
print(x, table.concat(log))`);
  assert.match(r.text, /f\(\)/);
  const out = await oracle.runLua(r.text, 'lua51');
  assert.match(out.stdout, /fg/);
});

test('dataflow: values carried around a loop are not treated as dead', { skip }, async () => {
  await flow(`
local prev, cur, tmp = 0, 1
for i = 1, 8 do
  tmp = cur
  cur = prev + cur
  prev = tmp
end
print(cur, prev)`);
  await flow(`
local acc = 0
local last
for i = 1, 4 do
  if i % 2 == 0 then last = i end
  acc = acc + (last or 0)
end
print(acc, last)`);
  await flow(`
local n, out = 10, {}
local x = 0
while n > 0 do
  x = n
  n = n - 3
  out[#out + 1] = x
end
print(table.concat(out, ","), x)`);
  await flow(`
local i, s = 0, 0
repeat
  local sq = i * i
  s = s + sq
  i = i + 1
until sq > 20
print(i, s)`);
});

test('dataflow: swaps, shadowing and break', { skip }, async () => {
  await flow(`
local a, b = 1, 2
a, b = b, a
print(a, b)
local t = a
a = b
b = t
print(a, b)`);
  await flow(`
local x = 1
local y = x
do
  local x = 2
  print(y, x)
end
x = 5
print(x, y)`);
  await flow(`
local found
for i = 1, 10 do
  local v = i * 3
  if v > 10 then found = v break end
end
print(found)`);
});

test('dataflow: stores the program can still observe are kept', { skip }, async () => {
  // captured by a closure, written by a method call target, and read through a global
  const r = await flow(`
local n = 0
local function bump() n = n + 1 end
n = 5
bump()
print(n)
local t = {}
local k = "x"
t[k] = 1
k = "y"
t[k] = 2
print(t.x, t.y)`);
  assert.match(r.text, /n = 5/);
});

test('dataflow: a function with goto is not touched', () => {
  const src = 'local a = 1\na = 2\nfor i = 1, 2 do\n  if i == 1 then goto skip end\n  print(i)\n  ::skip::\nend\nprint(a)';
  assert.equal(apply(src, dataflowPass).changed, 0);
});

test('simplify: a declaration sinks into the loop body only when no value can reach the next pass', { skip }, async () => {
  const yes = await behaves(`
local v
for i = 1, 3 do
  v = i * 2
  print(v)
end`, simplifyPass);
  assert.match(yes.text, /for i = 1, 3 do\n\s+local v = i \* 2/);

  // v is read before it is written in the next pass: it carries a value
  const carry = await behaves(`
local v
for i = 1, 3 do
  print(v)
  v = i * 2
end`, simplifyPass);
  assert.match(carry.text, /^local v\n+for/m);

  // read after the loop
  const later = await behaves(`
local v
for i = 1, 3 do
  v = i * 2
end
print(v)`, simplifyPass);
  assert.match(later.text, /^local v\n+for/m);

  // captured by a closure created in the loop: a new local per pass would be a different upvalue
  const captured = await behaves(`
local v
local fns = {}
for i = 1, 3 do
  v = i
  fns[i] = function() return v end
end
print(fns[1](), fns[3]())`, simplifyPass);
  assert.match(captured.text, /^local v$/m);
});
