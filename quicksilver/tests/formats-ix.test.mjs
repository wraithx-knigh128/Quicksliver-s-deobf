// Prompt IX: the formats read this session (Obscura, XFuscator, LuaXen, Zartha, FusGato, RealObfuscator, zynaa/LuaObfuscator, Luarmor bootstraps) and what they led to.
//
// Each pass has a test on a synthetic input (a failure points at the pass); the committed MIT fixtures (Obscura, Zartha, FusGato, LuaXen) carry floors taken from
// what was measured; output of tools whose licence does not allow committing it (XFuscator, zynaa, RealObfuscator) is tested through inputs built in the test, and
// through the local fixture folder when it is present on this machine.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { bytesToBinary } from '../src/core/bytes.js';
import { fidelity } from '../src/core/fidelity.js';
import { recover } from '../src/recover/pipeline.js';
import { detect } from '../src/detect/detect.js';
import { foldPass } from '../src/passes/fold.js';
import { simplifyPass } from '../src/passes/simplify.js';
import { whileToIf } from '../src/passes/structure.js';
import { foldMetaArithmetic } from '../src/passes/metaarith.js';
import { seedDecoderCalls, inlineStringTable } from '../src/passes/strtable.js';
import { evaluatePass } from '../src/passes/evaluate.js';
import { removeObscuraGuards } from '../src/recover/obscura.js';
import { unwrapXFuscator } from '../src/recover/xfuscator.js';
import { unwrapLayers } from '../src/passes/layers.js';
import { recoverDispatchers } from '../src/adaptive/strategies/dispatch.js';
import { runSource } from '../src/sandbox/sandbox.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const read = (p) => bytesToBinary(fs.readFileSync(p));
after(() => oracle.stopOracle?.());

const chunkOf = (src) => parse(src);
const through = (src, ...passes) => { const ast = chunkOf(src); for (const p of passes) p(ast); return print(ast); };
const run = (src) => recover(src, { sandbox: { enabled: true } });

// ---- the passes --------------------------------------------------------------------------------------------------------------------------

test('fold: math.floor / math.ceil of an integer is the integer, of a fraction it is left alone; table.concat of literals is the text', () => {
  assert.equal(through('local a = math.floor(15) + math.ceil(-3) + math.floor(2.5)', (a) => foldPass(a)), 'local a = 15 + -3 + math.floor(2.5)\n'.replace('15 + -3', '12 + 0').replace(/12 \+ 0/, '12').replace('+ math.floor(2.5)', '+ math.floor(2.5)'));
  assert.equal(through('local s = table.concat{ "ab", "c", 7 }', (a) => foldPass(a)).trim(), 'local s = "abc7"');
  assert.equal(through('local s = table.concat({ "a", "b" }, "-")', (a) => foldPass(a)).trim(), 'local s = "a-b"');
  assert.match(through('local t = {} local s = table.concat({ t, "b" })', (a) => foldPass(a)), /table\.concat/);
});

test('fold: (bit32.op(...) + k) - k is the bit32 result, and nothing else is rewritten that way', () => {
  assert.match(through('local x = (bit32.bxor(a, b) + 15889) - 15889', (a) => foldPass(a)), /^local x = bit32\.bxor\(a, b\)/);
  assert.match(through('local x = (n + 15889) - 15889', (a) => foldPass(a)), /n \+ 15889 - 15889/);
});

test('simplify: a closure called on the spot that only computes a constant from constants is that constant (opaque predicates)', () => {
  const out = through('if (function() local n = 22 return n * n < 0 end)() then error("unreachable") end print(1)', (a) => foldPass(a), (a) => simplifyPass(a), (a) => foldPass(a), (a) => simplifyPass(a));
  assert.doesNotMatch(out, /unreachable|function\(\)/);
  const kept = through('local k = 0 local v = (function() k = k + 1 return k end)() print(v)', (a) => simplifyPass(a));
  assert.match(kept, /function\(\)/, 'a closure that reads or writes anything outside itself is not folded');
});

test('simplify: a table of builtins read only by constant keys is indirection and is inlined; a statement computing a number nobody keeps goes', () => {
  const out = through('local T = {[1]=print,[2]=type,[3]=math} T[1](T[2](nil)) T[3].cos(12)', (a) => simplifyPass(a));
  assert.match(out, /print\(type\(nil\)\)/);
  assert.doesNotMatch(out, /cos/);
  const kept = through('local T = {print, type} for i = 1, 2 do T[i](nil) end', (a) => simplifyPass(a));
  assert.match(kept, /T\[i\]/, 'computed keys keep the table');
});

test('simplify: `local G = _G` (or _G itself) read only as G.name / G["name"] is the global; writes through _G, an alias that is used otherwise, and a used local of the same name keep it', () => {
  assert.doesNotMatch(through('local G = _G local a = G.print local b = G["tostring"](1) a(b)', (x) => simplifyPass(x)), /\bG\b|_G/);
  assert.equal(through('_G.print(_G.tostring(1))', (x) => simplifyPass(x)).trim(), 'print(tostring(1))');
  assert.match(through('_G.x = 1 print(_G.y)', (x) => simplifyPass(x)), /_G\.y/, 'the script writes through _G: the table is part of its logic');
  assert.match(through('local t = _G for k in pairs(t) do print(k) end', (x) => simplifyPass(x)), /_G/, 'passed on: left alone');
  assert.match(through('local print = 5 local G = _G G.print(print)', (x) => simplifyPass(x)), /_G\.print|G\.print/, 'a local called print that is used would capture the global');
});

test('structure: a while whose last statement leaves it is an if; one with another way round stays a loop', () => {
  assert.match(through('while x < 3 do print(1) return false end', whileToIf), /^if x < 3 then/);
  assert.match(through('while x < 3 do print(1) break end', whileToIf), /^if x < 3 then/);
  assert.match(through('while x < 3 do if y then break end return end', whileToIf), /^while/);
  assert.match(through('while x < 3 do for i = 1, 2 do break end return end', whileToIf), /^if x < 3 then/, 'a break of an inner loop is not this loop’s');
});

test('metaarith: numbers hidden behind a metamethod are evaluated; strings built by a looping metamethod are evaluated in the sandbox only', () => {
  const num = 'local n = setmetatable({}, {["__div"]=function(_,a) local x,y,z=a[1],a[2],a[3] return x*x-y*y+z end}) / {21792,57683,2852437225}';
  assert.equal(through(num, (a) => foldMetaArithmetic(a)).trim(), `local n = ${21792 * 21792 - 57683 * 57683 + 2852437225}`);
  const str = 'local s = setmetatable({}, {__mod = function(_, a) local out = "" local i = 1 while a[i] do local x, y, z = a[i][1], a[i][2], a[i][3] out = out .. string.char(x * x - y * y + z) i = i + 1 end return out end}) % {{5, 5, 72}, {5, 5, 105}}';
  assert.match(through(str, (a) => foldMetaArithmetic(a)), /setmetatable/, 'without the sandbox it is left as it is');
  const ast = chunkOf(str);
  assert.equal(foldMetaArithmetic(ast, { sandbox: { enabled: true } }).ran, 1);
  assert.equal(print(ast).trim(), 'local s = "Hi"');
  const escape = 'local s = setmetatable({}, {__mod = function(_, a) return os.execute("x") end}) % {1}';
  const e = chunkOf(escape);
  assert.equal(foldMetaArithmetic(e, { sandbox: { enabled: true } }).changed, 0, 'a function that reaches outside the standard libraries is never run');
});

test('strtable: a table that decrypts itself in place is read through the decoder and its reads become the strings', () => {
  const src = [
    'local T = {[1] = "\\4", [2] = "\\6"}',
    'do local D = function(s, k) return string.char(string.byte(s, 1) + k) end',
    'T[1] = D(T[1], 65) T[2] = D(T[2], 66) end',
    'local a = T[1] local b = T[2] T = nil',
    'print(a .. b)'].join('\n');
  const ast = chunkOf(src);
  assert.equal(seedDecoderCalls(ast).changed, 2);
  const seeded = print(ast);
  assert.match(seeded, /T\[1\] = D\("\\4", 65\)/);
  // stand in for the evaluator: the calls hold their results
  const done = chunkOf(seeded.replace('D("\\4", 65)', '"E"').replace('D("\\6", 66)', '"H"'));
  inlineStringTable(done);
  assert.match(print(done), /print\("E" \.\. "H"\)/);
  assert.doesNotMatch(print(done), /T\[/);
  const escaped = chunkOf('local T = {"x"} local function f(t) return t end f(T) T[1] = g(T[1])');
  assert.equal(seedDecoderCalls(escaped).changed, 0, 'a table that is passed on is left alone');
});

test('evaluate: a byte decoder (string.char(d(n))) is evaluated, and a function that wraps bit32 in `bit or bit32 or require` counts as closed', () => {
  const src = 'local d = function(n) local b = bit or bit32 or require"bit" return b.bxor(79, n) end local s = table.concat{ string.char(d(39)), string.char(d(38)), string.char(d(61)), string.char(d(46)), string.char(d(43)) } print(s)';
  const ast = chunkOf(src);
  const r = evaluatePass(ast, { sandbox: { enabled: true } });
  assert.ok(r.evaluated >= 5, JSON.stringify(r));
  foldPass(ast); foldPass(ast);
  assert.match(print(ast), /local s = "hi!"/.source.replace('hi!', String.fromCharCode(39 ^ 79, 38 ^ 79, 61 ^ 79, 46 ^ 79, 43 ^ 79)).replace(/^/, '') ? new RegExp(`local s = "${String.fromCharCode(39 ^ 79, 38 ^ 79, 61 ^ 79, 46 ^ 79, 43 ^ 79)}"`) : /x/);
});

test('sandbox: Luau’s generalized iteration walks a table without pairs', () => {
  const r = runSource('local t = {10, 20, x = 5} local n = 0 for k, v in t do n = n + v end print(n)', { dialect: 'luau' });
  assert.equal(r.output.trim(), '35');
  const lua51 = runSource('local t = {10} for k, v in t do end', { dialect: 'lua51' });
  assert.equal(lua51.ok, false, 'in Lua 5.1 the same loop is an error and stays one');
});

test('dispatch: a loop of two blocks that cannot end on its own is unflattened, and an `error("invalid state")` else does not stop a machine being read', () => {
  const two = 'local function f(v) local state = 11 while 0.5 do if state == 11 then state = 22 if v > 1 then return 1 end else if state == 22 then state = 33 return 2 end end end end print(f(5))';
  const a1 = chunkOf(two);
  assert.equal(recoverDispatchers(a1).loops.length, 1);
  assert.doesNotMatch(print(a1), /state/);
  const withError = 'local function g(n) local s = 5 while true do if s == 5 then n = n + 1 s = 6 elseif s == 6 then s = 7 n = n * 2 elseif s == 7 then return n else error("CFF Error: Invalid state") end end end print(g(1))';
  const a2 = chunkOf(withError);
  assert.equal(recoverDispatchers(a2).loops.length, 1);
  assert.doesNotMatch(print(a2), /CFF Error|\bs\b/);
});

test('layers: a program stored as numbers, decoded and run through a local alias of loadstring, is replaced by what it loads', () => {
  const payload = 'print("payload")';
  const nums = [...payload].map((c) => c.charCodeAt(0) * 97 + 53);
  const src = [`local _X = {${nums.join(',')}}`,
    'local function _d(t) local s = {} for i = 1, #t do s[#s + 1] = string.char(math.floor((t[i] - 53) / 97 + 0.0000001)) end return table.concat(s) end',
    'local _L = (loadstring or load)', 'local f = _L(_d(_X))', "if type(f) == 'function' then local P = setmetatable({}, {__call = function(_, ...) return f(...) end}) P() end"].join('\n');
  const ast = chunkOf(src);
  const r = unwrapLayers(ast, { sandbox: { enabled: true } });
  assert.equal(r.replaced, 1, JSON.stringify(r));
  assert.equal(print(ast).trim(), payload);
});

// ---- Obscura ------------------------------------------------------------------------------------------------------------------------------

test('obscura guards: a run of executor-detection ifs at the top is taken off; ordinary checks and a single guard are not', () => {
  const guards = 'if typeof == nil or game == nil then error("") end\nlocal v = type\nif v(getgenv) ~= v(nil) then error("") end\nif v(hookfunction) ~= v(nil) then error("") end\nprint("program")';
  const ast = chunkOf(guards);
  assert.equal(removeObscuraGuards(ast).changed, 3);
  assert.doesNotMatch(print(ast), /getgenv|hookfunction/);
  const own = chunkOf('if game == nil then error("") end\nif workspace == nil then error("") end\nprint(1)');
  assert.equal(removeObscuraGuards(own).changed, 0, 'two checks of the script’s own, no executor probe: kept');
  const one = chunkOf('if type(getgenv) ~= "nil" then error("x") end print(1)');
  assert.equal(removeObscuraGuards(one).changed, 0);
  const old = chunkOf('do local _ = 1 end if type(getgenv) ~= "nil" then error("Security violation") end if type(hookfunction) ~= "nil" then error("Security violation") end print(1)');
  assert.equal(removeObscuraGuards(old).changed, 0, 'the run must start at the top');
});

const OBSCURA_DIR = path.join(corpus, 'obfuscated/obscura-1.1.0');
const obscuraOk = fs.existsSync(OBSCURA_DIR);
for (const [config, floor, samples] of [['level-1', 0.95, ['s01_minify_basic', 's05_nested_functions']], ['level-2', 0.95, ['s01_minify_basic', 's04_control_flow']], ['level-3', 0.95, ['s01_minify_basic', 's02_renamed_vars', 's07_roblox_style']],
  ['native', 0.95, ['s01_minify_basic', 's04_control_flow']], ['lightweight', 0.95, ['s01_minify_basic', 's05_nested_functions', 's07_roblox_style']]]) {
  for (const sample of samples) {
    test(`obscura 1.1.0 ${config} / ${sample}: recovered at fidelity >= ${floor}, identified, and behaves like the original on Luau when a Luau is available`, { skip: !obscuraOk && 'no Obscura fixtures' }, async () => {
      const input = read(path.join(OBSCURA_DIR, `${sample}__${config}.lua`));
      const original = read(path.join(corpus, 'originals', `${sample}.lua`));
      const r = run(input);
      assert.ok(r.detection.families.some((f) => f.id === 'obscura' && f.confidence >= 0.9), 'identified');
      const f = fidelity(original, r.output).score;
      assert.ok(f >= floor, `fidelity ${f.toFixed(2)} < ${floor}`);
      if (oracle.available) {
        const a = await oracle.runLua(original, 'luau');
        const b = await oracle.runLua(r.output, 'luau');
        if (a.ok) assert.equal(b.stdout, a.stdout, 'same output on Luau');
      }
    });
  }
}

test('obscura VM builds: the plain build is lifted back to source (Prompt XI); the hardened builds are identified and reported as not recovered, and the report says so', { skip: !obscuraOk && 'no Obscura fixtures' }, () => {
  const plainBuild = run(read(path.join(OBSCURA_DIR, 's01_minify_basic__vm.lua')));
  assert.ok(plainBuild.detection.families.some((f) => f.id === 'obscura'));
  assert.equal(plainBuild.vm.lifted, true);
  assert.equal(plainBuild.confidence.level, 'high');
  const hardened = run(read(path.join(OBSCURA_DIR, 's01_minify_basic__vm-max.lua')));
  assert.ok(hardened.detection.families.some((f) => f.id === 'obscura'));
  assert.notEqual(hardened.confidence.level, 'high');
  assert.match(hardened.output, /QuickSilver recovery report/);
});

// ---- XFuscator ----------------------------------------------------------------------------------------------------------------------------

function xfuscatorStep2(program, scale) {
  const codes = [...program].map((c) => `_(${c.charCodeAt(0) * scale})`).join(', ');
  return [` math.randomseed(0.5) local ____ = { function(...) local t = { ...} return ____[8](t) end, print, game, math.frexp, math.random(1, 1100), string.dump, string.sub, table.concat, wait, tick, loadstring }`,
    `local ___ = ____[5] local _ = function(x) return string.char(x / ___) end local __ = { ${codes} }`,
    `return ____[11]((____[8](__)), ____[#____])()`].join(' ');
}

test('xfuscator step 2: the character array is read whatever the scale, and the wrapper around it goes', () => {
  const program = 'local a = 1\nlocal b = 2\nprint(a + b)\nprint("done")\n';
  for (const scale of [925, 7, 1100]) {
    const ast = chunkOf(xfuscatorStep2(program, scale));
    const r = unwrapXFuscator(ast);
    assert.equal(r.changed, 1);
    assert.equal(r.scale, scale);
    assert.equal(print(ast).trim(), 'local a = 1\nlocal b = 2\nprint(a + b)\nprint("done")');
  }
  const notIt = chunkOf('local _ = function(x) return string.char(x / 3) end local t = {_(1), _(2)} print(t)');
  assert.equal(unwrapXFuscator(notIt).changed, 0, 'fewer than eight entries, and nothing runs the array');
});

test('xfuscator: identified by its step-2 array and its tamper string; a plain decimal-escape loadstring is only weak evidence', () => {
  const d = detect(xfuscatorStep2('print(1)\nprint(2)\nprint(3)\nprint(4)\n', 925));
  assert.ok(d.families.some((f) => f.id === 'xfuscator' && f.confidence >= 0.85));
  const escapes = 'return loadstring(\'' + [...'print("hello world, this is a long enough program text to count as escapes")'].map((c) => `\\${c.charCodeAt(0)}`).join('') + '\')()';
  const w = detect(escapes);
  assert.ok(w.families.some((f) => f.id === 'xfuscator' && f.confidence < 0.5));
});

const XF_DIR = path.join(corpus, 'obfuscated-local/xfuscator');
test('xfuscator local fixtures (when present): default and encrypt configurations are recovered', { skip: !fs.existsSync(XF_DIR) && 'no local XFuscator fixtures (tests/corpus/tools/gen_external.py --tool xfuscator)' }, () => {
  for (const config of ['default', 'encrypt', 'uglify']) {
    const input = read(path.join(XF_DIR, `s01_minify_basic__${config}.lua`));
    const r = run(input);
    const f = fidelity(read(path.join(corpus, 'originals/s01_minify_basic.lua')), r.output).score;
    assert.ok(f >= 0.9, `${config}: ${f.toFixed(2)}`);
  }
});

// ---- LuaXen, Zartha, FusGato ----------------------------------------------------------------------------------------------------------------

const LUAXEN_DIR = path.join(corpus, 'obfuscated/luaxen');
const luaxenOk = fs.existsSync(LUAXEN_DIR);
for (const sample of ['s01_minify_basic', 's02_renamed_vars', 's03_encoded_strings', 's06_combined', 's07_roblox_style']) {
  test(`luaxen ast stage / ${sample}: the metamethod numbers and strings are evaluated and the state loops are unflattened (fidelity >= 0.85)`, { skip: !luaxenOk && 'no LuaXen fixtures' }, async () => {
    const input = read(path.join(LUAXEN_DIR, `${sample}__ast.lua`));
    const r = run(input);
    assert.ok(r.detection.families.some((f) => f.id === 'luaxen'));
    const f = fidelity(read(path.join(corpus, 'originals', `${sample}.lua`)), r.output).score;
    assert.ok(f >= 0.85, `fidelity ${f.toFixed(2)}`);
    assert.doesNotMatch(r.output, /__(?:div|mul|add|sub|mod|pow|concat)\s*=\s*function\(_, a\)/, 'no metamethod arithmetic left');
  });
}

test('luaxen IronBrikked and fusgato: identified (and never called recovered); zartha is identified and, since Prompt XII, lifted (tests/zartha-vm.test.mjs); their fixtures are the tools’ real output', { skip: !luaxenOk && 'no fixtures' }, () => {
  for (const [dir, file, family] of [['luaxen', 's01_minify_basic__ironbrikked.lua', 'luaxen'], ['zartha', 's01_minify_basic__default.lua', 'zartha'], ['fusgato', 's03_encoded_strings__default.lua', 'fusgato']]) {
    const p = path.join(corpus, 'obfuscated', dir, file);
    if (!fs.existsSync(p)) continue;
    const r = run(read(p));
    assert.ok(r.detection.families.some((f) => f.id === family && f.confidence >= 0.85), `${dir} identified`);
    if (dir === 'zartha') assert.equal(r.steps.find((s) => s.id === 'zartha.vm').status, 'applied', 'zartha is lifted, not only identified');
    else assert.notEqual(r.confidence.level, 'high', `${dir} is a VM: not high confidence`);
  }
  const fusgato = path.join(corpus, 'obfuscated/fusgato/s03_encoded_strings__default.lua');
  if (fs.existsSync(fusgato)) {
    const d = detect(read(fusgato));
    assert.ok(!d.families.some((f) => f.id === 'ironbrew2' && f.confidence >= 0.5), 'the copied IronBrew watermark does not make it IronBrew 2');
  }
});

// ---- the other tools: identification from what each writes ------------------------------------------------------------------------------------

test('detection: RealObfuscator, zynaa/LuaObfuscator and Luarmor bootstraps are identified from their own marks', () => {
  const ro = detect('--!nocheck\n--!nolint\n-- RealObfuscator [development] | https://github.com/linkoro57/RealObfuscator\nlocal a=bit32.bxor print(1)');
  assert.ok(ro.families.some((f) => f.id === 'realobfuscator' && f.confidence >= 0.95));
  const inv = '‪'.repeat(7);
  const zy = detect(`local ${'‪'} = _G local ${'‪‪'} = ${'‪'}['\\115\\116\\114'] local ${inv} = 1 print(${inv})`);
  assert.ok(zy.families.some((f) => f.id === 'zynaa' && f.confidence >= 0.85));
  const lr = detect('-- Do not save this file\n-- Always use the loadstring \n  _bsdata0={1,2,3};\nlocal f,a="static" pcall(function() a=readfile(f) end) if not a then a=game:HttpGet("https://cdn.luarmor.net/v4_init_x.lua") writefile(f, a) end return loadstring(a)()');
  assert.ok(lr.families.some((f) => f.id === 'luarmor' && f.confidence >= 0.9));
  const classes = lr.classes.map((c) => c.id);
  assert.ok(classes.includes('cached-remote-loader'), JSON.stringify(classes));
  const unknownBootstrap = detect('local f,a="x" pcall(function() a=readfile(f) end) if not a then a=game:HttpGet("https://example.org/init.lua") writefile(f, a) end return loadstring(a)()');
  assert.deepEqual(unknownBootstrap.families.filter((x) => x.confidence >= 0.5), []);
  assert.ok(unknownBootstrap.classes.some((c) => c.id === 'cached-remote-loader'), 'an unknown service gets the same class');
});

// ---- classification of what no rule knows -----------------------------------------------------------------------------------------------------

test('classes: every parsed script gets one, and the classes say what is and is not in the file', () => {
  const cls = (src) => detect(src).classes.map((c) => c.id);
  assert.deepEqual(cls('loadstring(game:HttpGet("https://example.org/raw/abc"))()'), ['remote-loader']);
  assert.deepEqual(cls('getgenv().Key = "x"\nlocal L = loadstring(game:HttpGet("https://example.org/lib.lua"))()'), ['remote-loader']);
  assert.ok(cls('local Lib = loadstring(game:HttpGet("https://example.org/lib.lua"))()\nlocal w = Lib:Window("x")\nfor i = 1, 3 do print(i) end').includes('remote-library-script'));
  assert.deepEqual(cls('local players = game:GetService("Players")\nprint(players.LocalPlayer.Name)'), ['plain-script']);
  const minified = 'local a=game:GetService("Players").LocalPlayer;local b=Instance.new("ScreenGui");b.Name="x";b.Parent=a:WaitForChild("PlayerGui");local c,d,e,f,g,h,i,j=1,2,3,4,5,6,7,8;local function k(l,m,n)return l+m+n end;print(k(c,d,e))';
  assert.ok(['minified-script', 'plain-script'].includes(cls(minified)[0]));
  assert.deepEqual(cls('this is not lua ((('), ['not-lua']);
  const urls = detect('loadstring(game:HttpGet("https://example.org/raw/abc"))()').classes[0];
  assert.ok(urls.evidence.some((e) => /example\.org\/raw\/abc/.test(e)));
  assert.equal(urls.recovery, 'none');
});
