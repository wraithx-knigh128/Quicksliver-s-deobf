// Prompt XXXI: the decompiler shapes behind the last six MoonSec V3 functions it left undecompiled (docs/REPORT-XXXI.md §2), each
// reduced to a program written for the purpose (tests/corpus/regress/xxxi-*.lua) and checked on reference Lua. Skipped without QS_LUA_PYTHON.
//   * an inner loop's exit threaded through the outer loop's `break`, for numeric and generic for loops (08010afe);
//   * a jump to the function's final `return` of nothing from inside a split condition (ce3faecf, 6aaee086);
//   * a `while` whose condition leaves for a second, identical `return` (424517eb);
//   * Luau `continue`: a jump to a loop's continue point from inside a nested block (ddc9c42c, c2f0c41b). Lua 5.4 writes the same
//     jump as `goto continue`, so a Lua 5.4 program compiled by reference Lua is decompiled as Luau, each `continue` is written back as
//     a goto to a label at the end of its loop, and that program is run on reference Lua 5.4 next to the original.
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as oracle from './helpers/lua-oracle.mjs';
import { parseChunk, dumpChunk51 } from '../src/sandbox/bytecode.js';
import { decompile } from '../src/decompile/decompile.js';
import { print, quoteString } from '../src/core/printer.js';
import { parse } from '../src/core/parser.js';
import { rng } from './helpers/decompile-props.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const regress = path.join(here, 'corpus', 'regress');
after(() => oracle.stopOracle());
const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';

async function compile(src, runtime, strip) {
  const loader = runtime === 'lua51' ? 'loadstring' : 'load';
  const r = await oracle.runLua(`local f = assert(${loader}(${quoteString(src)}))\nlocal d = string.dump(f${strip && runtime !== 'lua51' ? ', true' : ''})\nprint((d:gsub('.', function(c) return string.format('%02x', c:byte()) end)))`, runtime);
  assert.ok(r.ok, `reference Lua could not compile the case: ${r.error}`);
  const bin = r.stdout.trim().replace(/../g, (h) => String.fromCharCode(parseInt(h, 16)));
  return strip && runtime === 'lua51' ? dumpChunk51(parseChunk(bin), { strip: true }) : bin;
}

const LOOPS = new Set(['While', 'Repeat', 'NumFor', 'GenFor']);
/** Every `continue` becomes `goto` to a label at the end of its own loop (the body is wrapped in `do … end` so no local is in scope). */
function continuesToGoto(ast) {
  let k = 0;
  const visit = (n, label) => {
    if (!n || typeof n !== 'object') return n;
    if (Array.isArray(n)) return n.map((x) => visit(x, label));
    if (n.type === 'Continue') { assert.ok(label, 'a continue outside a loop'); return { type: 'Goto', label }; }
    if (n.type === 'Func') return { ...n, body: visit(n.body, null) };
    if (LOOPS.has(n.type)) {
      const own = `__continue${++k}`;
      return { ...n, body: [{ type: 'Do', body: visit(n.body, own) }, { type: 'Label', name: own }] };
    }
    const out = {};
    for (const [key, v] of Object.entries(n)) out[key] = v && typeof v === 'object' && key !== 'features' ? visit(v, label) : v;
    return out;
  };
  return visit(ast, null);
}

for (const name of ['xxxi-for-break.lua', 'xxxi-or-commands.lua']) {
  test(`${name}: decompiled on Lua 5.1 and 5.4, stripped and with debug information, and the same output`, { skip }, async () => {
    const src = fs.readFileSync(path.join(regress, name), 'latin1');
    for (const runtime of ['lua51', 'lua54']) for (const strip of [true, false]) {
      const d = decompile(parseChunk(await compile(src, runtime, strip)));
      assert.deepEqual(d.failures, [], `${runtime} ${strip ? 'stripped' : 'debug'}`);
      const text = print(d.ast);
      assert.doesNotMatch(text, /\bcontinue\b/, 'Lua output never contains continue');
      const [a, b] = [await oracle.runLua(src, runtime), await oracle.runLua(text, runtime)];
      assert.ok(a.ok && b.ok, b.error || a.error);
      assert.equal(b.stdout, a.stdout, `${runtime} ${strip ? 'stripped' : 'debug'}`);
    }
  });
}

test('a while loop whose condition leaves for a second, identical return: decompiled as `while cond do`, same output', { skip }, async () => {
  const src = 'local out = {}\nlocal function run(n)\n  local i = 0\n  while i < n do\n    i = i + 1\n    if i == 5 then break end\n    out[#out + 1] = i\n  end\n  return\nend\nrun(3) run(0) run(7)\nprint(table.concat(out, ","))\n';
  const ch = parseChunk(await compile(src, 'lua51', false));
  const fn = ch.main.protos[0];
  const code = Array.from(fn.code);
  const op = (w) => w & 0x3f;
  const sbx = (w) => (w >>> 14) - 131071;
  const rets = code.map((w, i) => (op(w) === 30 ? i : -1)).filter((i) => i >= 0);
  assert.equal(rets[1], rets[0] + 1, 'the explicit return and the final one are adjacent');
  // the loop condition's jump (the first jump to the explicit return; the break's comes later) is moved to the identical final return
  const cond = code.findIndex((w, i) => op(w) === 22 && i + 1 + sbx(w) === rets[0]);
  assert.ok(cond >= 0);
  fn.code[cond] += 1 << 14;
  const bin = dumpChunk51(ch, { strip: true });
  const d = decompile(parseChunk(bin));
  assert.deepEqual(d.failures, []);
  const text = print(d.ast);
  assert.match(text, /while _r1_1 < a1_1 do/);
  const [a, b] = [await oracle.runLua(`local f = assert(loadstring(${quoteString(bin)}))\nf()`, 'lua51'), await oracle.runLua(text, 'lua51')];
  assert.equal(a.stdout, '1,2,3,1,2,3,4\n');
  assert.equal(b.stdout, a.stdout);
});

test('xxxi-continue.lua (Lua 5.4 `goto continue`): written with `continue` as Luau and the same output; refused as Lua', { skip }, async () => {
  const src = fs.readFileSync(path.join(regress, 'xxxi-continue.lua'), 'latin1');
  const want = await oracle.runLua(src, 'lua54');
  assert.ok(want.ok, want.error);
  for (const strip of [true, false]) {
    const bin = await compile(src, 'lua54', strip);
    const luau = decompile(parseChunk(bin), { dialect: 'luau' });
    assert.deepEqual(luau.failures, []);
    const text = print(luau.ast);
    assert.ok((text.match(/\bcontinue\b/g) || []).length >= 2, text);
    assert.doesNotThrow(() => parse(text));
    const got = await oracle.runLua(print(continuesToGoto(luau.ast)), 'lua54');
    assert.equal(got.stdout, want.stdout, got.error || '');
    const lua = decompile(parseChunk(bin));
    assert.doesNotMatch(print(lua.ast), /\bcontinue\b/);
    assert.ok(lua.failures.length > 0, 'without continue the shape still needs a duplication the decompiler refuses');
  }
});

/** Lua 5.4 loops whose bodies leave for the next iteration with `goto` from nested ifs, some before a long tail. */
function continueCase(rnd) {
  let n = 0;
  const cond = () => ['i % 2 == 0', 'i > 3', 'i == 2', 'seen[i % 3]', 'not seen[i]', 'i ~= 4 and i % 3 == 1'][rnd(6)];
  const block = (d, label) => {
    const out = [];
    const count = 1 + rnd(3);
    for (let s = 0; s < count; s++) {
      const r = rnd(d > 2 ? 3 : 7);
      if (r === 0) out.push(`emit("${++n}", i)`);
      else if (r === 1) out.push(`if ${cond()} then goto ${label} end`);
      else if (r === 2) out.push(`seen[i % 3] = true emit("${++n}")`);
      else if (r < 5) out.push(`if ${cond()} then ${block(d + 1, label)} ${rnd(2) ? `else ${block(d + 1, label)} ` : ''}end`);
      else if (r === 5) out.push(Array.from({ length: 6 + rnd(30) }, (_, j) => `emit("t${j}", i % ${j + 2})`).join(' '));
      else out.push(loop(d + 1));
    }
    return out.join('\n');
  };
  const loop = (d) => {
    const label = `continue${++n}`;
    const kind = rnd(3);
    const head = kind === 0 ? `local w${n} = 0\nwhile w${n} < 5 do\nw${n} = w${n} + 1\nlocal i = w${n}` : kind === 1 ? 'for i = 1, 5 do' : 'for _, i in ipairs({ 1, 2, 3, 4, 5 }) do';
    return `${head}\n${block(d, label)}\n::${label}::\nend`;
  };
  return `local out, seen = {}, {}\nlocal function emit(...) out[#out + 1] = table.concat({ ... }, ":") end\n${loop(0)}\n${loop(0)}\nprint(table.concat(out, " "))\n`;
}

test('Luau continue, property: 60 random Lua 5.4 `goto continue` programs, stripped, behave the same decompiled as Luau; as Lua they never get a continue', { skip, timeout: 600_000 }, async () => {
  const lcg = rng(53);
  const rnd = (k) => Math.floor((lcg(2 ** 30) / 2 ** 30) * k);
  let continues = 0;
  let luauUndecompiled = 0;
  let luaDecompiled = 0;
  for (let c = 0; c < 60; c++) {
    const src = continueCase(rnd);
    const want = await oracle.runLua(src, 'lua54');
    assert.ok(want.ok, `${want.error}\n${src}`);
    const bin = await compile(src, 'lua54', true);
    const luau = decompile(parseChunk(bin), { dialect: 'luau' });
    if (luau.failures.length) { luauUndecompiled++; if (process.env.QS_SHOW) console.log('UNDECOMPILED', luau.failures[0], '\n' + src); continue; }
    const text = print(luau.ast);
    continues += (text.match(/\bcontinue\b/g) || []).length;
    const got = await oracle.runLua(print(continuesToGoto(luau.ast)), 'lua54');
    assert.equal(got.stdout, want.stdout, `case ${c}:\n${src}\n--- decompiled:\n${text}\n${got.error || ''}`);
    const lua = decompile(parseChunk(bin));
    const plain = print(lua.ast);
    assert.doesNotMatch(plain, /\bcontinue\b/);
    if (!lua.failures.length) {
      luaDecompiled++;
      const b = await oracle.runLua(plain, 'lua54');
      assert.equal(b.stdout, want.stdout, `case ${c} as Lua:\n${src}\n--- decompiled:\n${plain}`);
    }
  }
  assert.ok(continues > 0, 'the property is not vacuous: some programs needed continue');
  assert.ok(luauUndecompiled <= 3, `${luauUndecompiled} of 60 were not decompiled as Luau`);
  assert.ok(luaDecompiled > 0);
});
