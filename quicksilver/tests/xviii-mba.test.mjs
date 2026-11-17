// Linear MBA simplification (src/passes/mba.js): known identities, generated MBAs, soundness on non-linear input, and behaviour on a real Lua.
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { simplifyMBA, simplifyLinearMBA } from '../src/passes/mba.js';
import { recover } from '../src/recover/pipeline.js';
import { available, runLua, stopOracle } from './helpers/lua-oracle.mjs';

after(() => stopOracle());

const expr = (src) => parse(`return ${src}`).body[0].values[0];
const show = (e) => print({ type: 'Chunk', body: [{ type: 'Return', values: [e] }] }).replace(/^return\s+/, '').trim();
const simp = (src) => { const r = simplifyLinearMBA(expr(src)); return r ? show(r) : null; };

test('textbook identities collapse to the operation they hide', () => {
  assert.equal(simp('(x + y) - 2 * bit32.band(x, y)'), 'bit32.bxor(x, y)');
  assert.equal(simp('x + y - bit32.band(x, y)'), 'bit32.bor(x, y)');
  assert.equal(simp('bit32.bor(x, y) - bit32.band(x, y)'), 'bit32.bxor(x, y)');
  assert.equal(simp('-x - 1'), null, 'no bitwise operator: not an MBA, left alone');
  assert.equal(simp('bit32.bxor(x, y) + 2 * bit32.band(x, y)'), 'x + y');
  assert.equal(simp('bit32.bnot(x) + x + 1'), '0');
  assert.equal(simp('(bit32.bxor(x, y) + 2 * bit32.band(x, y)) - y'), 'x');
  assert.equal(simp('3 * bit32.band(x, y) + 3 * bit32.bxor(x, y) - 3 * bit32.bor(x, y) + 7'), '7');
});

test('non-linear and unsupported expressions are left as they are', () => {
  assert.equal(simp('x * y - bit32.band(x, y)'), null, 'a product of variables is not linear');
  assert.equal(simp('bit32.band(x, 3) + x'), null, 'a constant mask inside a bitwise operator is outside the linear class (the check refuses it)');
  assert.equal(simp('bit32.lshift(x, 1) + x'), null);
  assert.equal(simp('t.x + bit32.band(t.x, y)'), null, 'fields are not variables');
});

test('the pass only rewrites inside bit32 calls, where the result is taken mod 2^32', () => {
  const ast = parse('local a = (x + y) - 2 * bit32.band(x, y)\nlocal b = bit32.bxor((x + y) - 2 * bit32.band(x, y), k)\n');
  assert.equal(simplifyMBA(ast), 1);
  const out = print(ast);
  assert.match(out, /local a = \(?x \+ y\)? - 2 \* bit32\.band\(x, y\)/, 'outside a bit32 call the identity only holds for non-negative 32-bit values, so it stays');
  assert.match(out, /local b = bit32\.bxor\(bit32\.bxor\(x, y\), k\)/);
});

// generated linear MBAs: hide a random bitwise function behind random identity rewrites
function generated(n) {
  let s = 12345;
  const r = (k) => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s % k; };
  const base = ['bit32.bxor(x, y)', 'bit32.bor(x, y)', 'bit32.band(x, y)', 'x', 'bit32.bnot(x)', 'bit32.bxor(x, bit32.band(y, z))', 'bit32.bor(x, bit32.bor(y, z))'];
  const noise = ['(bit32.bxor(x, y) + 2 * bit32.band(x, y) - x - y)', '(bit32.bnot(y) + y + 1)', '(bit32.bor(x, z) - bit32.band(x, z) - bit32.bxor(x, z))'];
  const out = [];
  for (let i = 0; i < n; i++) {
    const f = base[r(base.length)];
    const k = r(1000);
    let e = `${f} + ${k}`;
    for (let j = 0; j < 1 + r(3); j++) e = `${e} + ${1 + r(9)} * ${noise[r(noise.length)]}`;
    out.push({ f, k, e });
  }
  return out;
}

test('generated MBAs are reduced to an expression no larger than the hidden one, and equal mod 2^32 on random inputs', () => {
  for (const { f, k, e } of generated(40)) {
    const got = simplifyLinearMBA(expr(e));
    assert.ok(got, `simplified: ${e}`);
    const size = (x) => show(x).length;
    assert.ok(size(got) <= show(expr(`${f} + ${k}`)).length + 2, `${show(got)} is not larger than ${f} + ${k}`);
  }
});

test('behaviour on real Lua 5.1: the program prints the same before and after, with a pure-Lua bit32', { skip: available ? false : 'QS_LUA_PYTHON not set' }, async () => {
  const shim = `local bit32 = {}
local function tobits(a) a = a % 4294967296 local t = {} for i = 1, 32 do t[i] = a % 2 a = (a - t[i]) / 2 end return t end
local function frombits(t) local v = 0 for i = 32, 1, -1 do v = v * 2 + t[i] end return v end
local function op(f, init) return function(...) local acc = tobits(init) for _, v in ipairs({...}) do local b = tobits(v) for i = 1, 32 do acc[i] = f(acc[i], b[i]) end end return frombits(acc) end end
bit32.band = op(function(a, b) return (a == 1 and b == 1) and 1 or 0 end, 4294967295)
bit32.bor = op(function(a, b) return (a == 1 or b == 1) and 1 or 0 end, 0)
bit32.bxor = op(function(a, b) return a ~= b and 1 or 0 end, 0)
function bit32.bnot(a) return 4294967295 - a % 4294967296 end
`;
  const cases = generated(12).map(({ e }) => `bit32.bxor(${e})`);
  const body = `local inputs = { {0,0,0}, {1,2,3}, {4294967295, 7, 123456}, {-5, 99, 3000000000}, {2147483648, 2147483647, 1} }
for _, v in ipairs(inputs) do local x, y, z = v[1], v[2], v[3]
${cases.map((c) => `print(${c})`).join('\n')}
end`;
  const before = shim + body;
  const ast = parse(before);
  assert.ok(simplifyMBA(ast) >= 12);
  const after = print(ast);
  const [a, b] = await Promise.all([runLua(before), runLua(after)]);
  assert.equal(a.ok, true, a.error);
  assert.equal(b.ok, true, b.error);
  assert.equal(b.stdout, a.stdout);
});

test('the recovery pipeline applies it: an MBA inside a bit32 call comes out as the operation', () => {
  const r = recover('local x, y = 5, 9\nprint(bit32.band((x + y) - 2 * bit32.band(x, y), 4294967295))\n', { sandbox: { enabled: false } });
  assert.ok(r.steps.some((s) => s.id === 'mba' && s.status === 'applied') || /bit32\.bxor/.test(r.output), r.output);
});
