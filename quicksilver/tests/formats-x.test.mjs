// Prompt X: the measurement categories, the virtual-machine profile, and the generic fixes the measurements led to.
//
// Each test is on an input built in the test (a failure points at the piece), except the profile tests, which read the committed Obscura fixtures: the sample is the evidence there.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { bytesToBinary } from '../src/core/bytes.js';
import { recover } from '../src/recover/pipeline.js';
import { simplifyPass } from '../src/passes/simplify.js';
import { evaluatePass } from '../src/passes/evaluate.js';
import { profileVm } from '../src/recover/vmprofile.js';
import { unwrapWrapper } from '../src/passes/structure.js';
import { removeAntiTamper, removeGuardFlag, undoProxifyLocals } from '../src/recover/prometheus.js';
import { fidelity } from '../src/core/fidelity.js';
import { buildReport } from '../src/recover/annotate.js';
import { treeEdges, structureScore, residualIndicators, stringLiterals, vmConstantsRecall, METHODS } from '../src/core/metrics.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const read = (p) => bytesToBinary(fs.readFileSync(p));
const through = (src, ...passes) => { const ast = parse(src); for (const p of passes) p(ast); return print(ast); };
const SANDBOX = { sandbox: { enabled: true } };
const obs = (v, name) => path.join(corpus, 'obfuscated', `obscura-${v}`, name);

// ---- the categories ----------------------------------------------------------------------------------------------------------------

test('structureScore: names, values, comments and parentheses do not matter; shape does', () => {
  const a = 'local function area(w, h) if w > 0 then return w * h end return 0 end print(area(2, 3))';
  const renamed = '-- note\nlocal function q(x, y) if (x > 5) then return (x * y) end return 1 end print(q(7, 8))';
  assert.equal(structureScore(a, renamed), 1);
  const other = 'for i = 1, 10 do print(i) end';
  assert.ok(structureScore(a, other) < 0.5, 'different programs score low');
  assert.equal(structureScore(a, a), 1);
  assert.ok(treeEdges(parse(a)).size > 5);
});

test('structureScore: a program with an extra loop around the same body is not the same shape', () => {
  const a = 'local x = 1 print(x)';
  const b = 'while true do local x = 1 print(x) end';
  const s = structureScore(a, b);
  assert.ok(s > 0 && s < 1);
});

test('residualIndicators: empty for a plain program, and it names what an obfuscated one still shows', () => {
  assert.deepEqual(residualIndicators('local t = {} for i = 1, 3 do t[#t + 1] = i * 2 end print(table.concat(t, ","))'), []);
  const escaped = 'local a = "\\72\\101\\108\\108\\111\\32\\119\\111\\114\\108\\100" local b = "\\112\\114\\105\\110\\116\\32\\104\\105" print(a, b)';
  assert.ok(residualIndicators(escaped).includes('trait:escape-encoded-strings'));
  const vm = read(obs('1.1.0', 's01_minify_basic__vm-max.lua'));
  assert.ok(residualIndicators(vm).includes('family:obscura'), 'a script that still holds the VM is not complete');
});

test('stringLiterals and vmConstantsRecall: counted on strings of two characters or more', () => {
  const src = 'print("hello", "x", "gcd = ", 5)';
  assert.deepEqual([...stringLiterals(src)].sort(), ['gcd = ', 'hello', 'print' === 'print' ? 'x' : ''].sort());
  assert.equal(vmConstantsRecall(src, ['hello', 'gcd = ', 7]), 1);
  assert.equal(vmConstantsRecall(src, ['hello']), 0.5);
  assert.equal(vmConstantsRecall('print(1, "a")', ['a']), null, 'nothing worth counting: not a score');
});

test('METHODS: every category has one definition, and the VM metric says it is a profile', () => {
  for (const k of ['identification', 'structure', 'semantic', 'runtime', 'completeness', 'stability', 'vmConstants']) assert.ok(METHODS[k] && METHODS[k].length > 40, k);
  assert.match(METHODS.vmConstants, /not a reconstruction/);
});

// ---- generic fixes -----------------------------------------------------------------------------------------------------------------

test('simplify: statements after a break or return of the same block are dropped (flatteners leave `d break break`)', () => {
  // the parser rejects such a block, so the tree is built the way a pass leaves it: statements pushed behind a `break` and a `return`
  const ast = parse('local function f(x) for i = 1, x do if i == 2 then print(i) break end end return 1 end print(f(3))');
  const fn = ast.body[0].func;
  const loopBody = fn.body[0].body;
  loopBody[0].clauses[0].body.push({ type: 'Break' }, parse('print("after the break")').body[0]);
  fn.body.push(parse('print("never")').body[0]);
  const out = print(simplifyPass(ast) && ast);
  assert.doesNotMatch(out, /never|after the break/);
  parse(out);
});

test('simplify: a block with a label keeps what follows a jump (a goto can reach it)', () => {
  const src = '::top:: local n = 0 n = n + 1 if n < 3 then goto top end print(n)';
  const ast = parse(src);
  ast.body.push(parse('print("after")').body[0]);
  ast.body.splice(3, 0, { type: 'Return', values: [] });      // a jump away, with a label in the block: what follows it can be reached by the goto
  const out = print((simplifyPass(ast), ast));
  assert.match(out, /print\(n\)/);
});

test('evaluate: a read of the host environment is never treated as a closed expression', () => {
  // `_G["game"]` is the host's value; the statement that holds it must not be run in the sandbox as if it were a constant
  const src = 'local g = _G local s = g["game"] local function d(i) return ("abc"):sub(i, i) end print(d(1), s)';
  const r = recover(src, SANDBOX);
  assert.ok(r.ok);
  assert.match(r.output, /game/);
});

test('evaluate: a decoded key still resolves when the lookup around it cannot be replaced', () => {
  const src = [
    'local function d(s) local o = {} for i = 1, #s do o[i] = string.char(s:byte(i) - 1) end return table.concat(o) end',
    'local t = { alpha = 1 }',
    'print(t[d("bmqib")])',
  ].join('\n');
  const out = recover(src, SANDBOX).output;
  assert.match(out, /alpha/);
});

test('simplify: the global table under a local name is read through, and an assignment through it is left alone', () => {
  const out = through('local g = _G g.value = 5 print(g.print == print, value)', simplifyPass);
  assert.match(out, /value/);
  parse(out);
});

test('recover: o.m(o, ...) is written o:m(...) once decoded names are plain', () => {
  const out = recover('local o = { m = function(self, a) return a end } print(o.m(o, 4))', SANDBOX).output;
  assert.match(out, /o:m\(4\)|\w+:m\(4\)/);
});

// ---- the virtual-machine profile ---------------------------------------------------------------------------------------------------

const profileOf = (file) => profileVm(parse(read(file)), SANDBOX);

test('vm profile: the three Obscura revisions, plain VM build: functions, instruction bytes and constants are read', () => {
  for (const [v, file, min] of [['1.0.1', 's01_minify_basic__vm.lua', 20], ['1.1.0', 's01_minify_basic__vm.lua', 20], ['1.0.0', 's01_minify_basic__vm.lua', 20]]) {
    const p = profileOf(obs(v, file));
    assert.ok(p, `${v}: a profile`);
    assert.equal(p.kind, 'obscura');
    assert.ok(p.constants && p.constants.length >= min, `${v}: constants read (${p.constants && p.constants.length})`);
    assert.ok(p.strings.includes('floor') && p.strings.includes('concat'), `${v}: the names the program reads`);
    if (v !== '1.0.0') assert.ok(p.functions.length >= 4 && p.instructionBytes > 100, `${v}: functions`);
  }
});

test('vm profile: the hardened 1.1.0 builds keep their constants in keyed records; they are opened one record at a time', () => {
  for (const f of ['s01_minify_basic__vm-max.lua', 's01_minify_basic__vm-cached.lua']) {
    const p = profileOf(obs('1.1.0', f));
    assert.ok(p && p.hardened, `${f}: hardened`);
    assert.ok(p.constants && p.constants.length >= 30, `${f}: constants (${p.constants && p.constants.length})`);
    assert.ok(p.strings.includes('primes: ') && p.strings.includes('gcd(84, 36) = '), `${f}: strings the program prints`);
    assert.equal(p.note, null);
  }
});

test('vm profile: it recovers most strings of the original program', () => {
  const original = read(path.join(corpus, 'originals', 's01_minify_basic.lua'));
  for (const [v, f] of [['1.1.0', 's01_minify_basic__vm-max.lua'], ['1.0.1', 's01_minify_basic__vm.lua'], ['1.0.0', 's01_minify_basic__vm.lua']]) {
    const p = profileOf(obs(v, f));
    const recall = vmConstantsRecall(original, p.constants);
    assert.ok(recall >= 0.8, `${v} ${f}: ${recall}`);
  }
});

test('vm profile: without the sandbox the data is described and the constants are said to be unread', () => {
  const p = profileVm(parse(read(obs('1.1.0', 's01_minify_basic__vm-max.lua'))), { sandbox: { enabled: false } });
  assert.ok(p && p.functions.length >= 4);
  assert.equal(p.constants, null);
  assert.match(p.note, /sandbox/);
});

test('vm profile: nothing else in the corpus is taken for a VM (no list of strings, no loop over opcodes)', () => {
  const dirs = ['hercules', 'ironbrew2', 'prometheus', 'zartha', 'fusgato', 'luaxen', 'loaders', 'simple_html', 'obscura-1.1.0'];
  let seen = 0;
  for (const d of dirs) {
    const dir = path.join(corpus, 'obfuscated', d);
    if (!fs.existsSync(dir)) continue;
    for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.lua') && !/__vm/.test(x)).slice(0, 12)) {
      let ast; try { ast = parse(read(path.join(dir, f))); } catch { continue; }
      assert.equal(profileVm(ast, { sandbox: { enabled: false } }), null, `${d}/${f}`);
      seen++;
    }
  }
  assert.ok(seen > 20);
});

test('recover: a VM build carries the profile in its result and in the report, saying it was not lifted', () => {
  const r = recover(read(obs('1.1.0', 's01_minify_basic__vm-max.lua')), SANDBOX);
  assert.ok(r.vm && r.vm.constants.length >= 30);
  assert.match(r.output, /Virtual machine, NOT lifted back to source/);
  assert.match(r.output, /"primes: "/);
  assert.match(r.output.replace(/\n--\s+/g, ' '), /Control flow, locals and expressions are not recovered/);
  const again = recover(r.output, SANDBOX);               // the report is replaced, not repeated
  assert.equal(again.output.match(/QuickSilver recovery report/g).length, 1);
});

test('buildReport: a profile makes the report show even when the confidence would not', () => {
  const rep = buildReport({ detection: { families: [], classes: [] }, steps: [], confidence: { level: 'high', score: 0.9, reasons: [] }, adaptive: null, vm: { functions: [{}], instructionBytes: 10, constants: ['abc'], strings: ['abc'], hardened: false, note: null } });
  assert.equal(rep.show, true);
  assert.ok(rep.lines.some((l) => /NOT lifted/.test(l)));
  const none = buildReport({ detection: { families: [], classes: [] }, steps: [], confidence: { level: 'high', score: 0.9, reasons: [] }, adaptive: null });
  assert.equal(none.show, false);
});

test('a plain script has no profile and no VM line', () => {
  const r = recover('local function f(x) return x * 2 end print(f(21))', SANDBOX);
  assert.equal(r.vm, null);
  assert.doesNotMatch(r.output, /Virtual machine/);
});

// ---- what an unfamiliar derivative of a known tool taught (a Prometheus fork with its own watermark and anti-tamper) -------------------

test('unwrap: a `return (function(...) ... end)(...)` wrapper after a preamble is unwrapped, and the preamble stays in front', () => {
  const out = through('greeting = "hi" ("mark"):gsub(".+", function(m) mark = m end) return (function(...) print(greeting, mark) end)(...)', (a) => unwrapWrapper(a));
  assert.match(out, /greeting = "hi"[\s\S]*print\(greeting, mark\)/);
  assert.doesNotMatch(out, /function\(\.\.\.\)/);
  // a local in the preamble could capture a name the body reads as a global: the wrapper stays (the `layers` pass relies on the same rule)
  const shadow = through('local counter = 5 return (function(...) print(counter) end)(...)', (a) => unwrapWrapper(a));
  assert.match(shadow, /function\(\.\.\.\)/);
  // a wrapper called as a statement is left alone when other statements precede it: its own `return` would end the chunk early
  const kept = through('local a = 1 (function(...) return 2 end)(...) print(a)', (x) => unwrapWrapper(x));
  assert.match(kept, /function\(\.\.\.\)/);
});

test('anti-tamper: a guard block written differently from the original tool is recognised by what it does', () => {
  const guard = 'do local ok = true local function die() error("Tamper Detected!") end local r = pcall(function() end) ok = ok and r if not ok then while true do l1, l2 = l2, l1 die() end end end print("hi")';
  const ast = parse(guard);
  assert.equal(removeAntiTamper(ast).changed, 1);
  assert.equal(print(ast).trim(), 'print("hi")');
});

test('anti-tamper: a block that reads the program\u2019s own state is not a guard, whatever it says', () => {
  const src = 'local secret = 1 do local function die() error("Tamper Detected!") end if secret == 2 then die() end local x = 1 local y = 2 end print(secret)';
  const ast = parse(src);
  assert.equal(removeAntiTamper(ast).changed, 0);
  assert.match(print(ast), /secret == 2/);
});

test('guard flag: a compiled guard (the program under `if flag then ... return end`, the failure path after it) is taken apart', () => {
  const src = [
    'local flag = true',
    'local function die() error("Tamper Detected!") end',
    'local n = pcall(function() end)',
    'flag = flag and n',
    'if flag then print("program") return end',
    'local function loop() while true do die() end end',
    'return loop()',
  ].join('\n');
  const ast = parse(src);
  const r = removeGuardFlag(ast);
  assert.ok(r.changed > 0);
  assert.equal(print(ast).trim(), 'print("program")');
});

test('guard flag: no marker, a flag written some other way, or locals the program uses: nothing is removed', () => {
  const noMarker = 'local flag = true local n = pcall(function() end) flag = flag and n if flag then print("a") return end local function f() while true do end end return f()';
  assert.equal(removeGuardFlag(parse(noMarker)).changed, 0);
  const forced = 'local flag = true local function die() error("Tamper Detected!") end flag = false if flag then print("a") return end local function f() while true do die() end end return f()';
  assert.equal(removeGuardFlag(parse(forced)).changed, 0);
  const used = 'local flag = true local function die() error("Tamper Detected!") end local n = 5 flag = flag and (n > 1) if flag then print(n) return end local function f() while true do die() end end return f()';
  assert.equal(removeGuardFlag(parse(used)).changed, 0, 'the program reads n, which the guard declared');
});

test('proxify: the accessors and the data table may be declared apart, and the field may be written as a string', () => {
  const src = 'local function get(r, q) return r["k"] end local function set(r, q) r["k"] = q end local tbl = { ["k"] = 5 } local p = setmetatable(tbl, { __sub = get, __add = set }) print(p - "x")';
  const ast = parse(src);
  const r = undoProxifyLocals(ast);
  assert.ok(r.proxies >= 1 && r.reads >= 1, JSON.stringify(r));
  assert.match(print(ast), /print\(p\)/);
  assert.match(print(ast), /local p = 5/);
});

test('proxify: a proxy whose variable is copied or passed on is left alone (the copy would read a table whose declaration is gone)', () => {
  const copied = 'local function get(r, q) return r["k"] end local function set(r, q) r["k"] = q end local tbl = { ["k"] = 5 } local p = setmetatable(tbl, { __sub = get, __add = set }) local copy = p print(copy - "x")';
  const ast = parse(copied);
  assert.equal(undoProxifyLocals(ast).changed, 0);
  assert.match(print(ast), /setmetatable/);
  const passed = 'local function get(r, q) return r["k"] end local function set(r, q) r["k"] = q end local tbl = { ["k"] = 5 } local p = setmetatable(tbl, { __sub = get, __add = set }) show(p) print(p - "x")';
  assert.equal(undoProxifyLocals(parse(passed)).changed, 0);
});

const lenny = path.join(corpus, 'obfuscated-local', 'prometheus-lennyobf');
test('a Prometheus fork (local fixtures, AGPL: generated on this machine only): found by structure, and recovered where the passes now generalise', { skip: !fs.existsSync(path.join(lenny, 'manifest.json')) && 'no local lennyobf fixtures (python tests/corpus/tools/gen_prometheus.py --src <fork>/src --out tests/corpus/obfuscated-local/prometheus-lennyobf)' }, () => {
  const entries = JSON.parse(fs.readFileSync(path.join(lenny, 'manifest.json'), 'utf8')).entries.filter((e) => e.status === 'ok' && /^s0[1-4]/.test(e.sample));
  const mean = (cfg) => { const rs = entries.filter((e) => e.config === cfg).map((e) => { const r = recover(read(path.join(lenny, e.file)), SANDBOX); return fidelity(read(path.join(corpus, 'originals', e.sample)), r.output).score; }); return rs.reduce((a, b) => a + b, 0) / rs.length; };
  assert.ok(mean('step-AntiTamper') >= 0.9, 'the fork writes its anti-tamper block its own way');
  assert.ok(mean('Weak') >= 0.4, 'ProxifyLocals with the accessors declared apart, behind a watermark statement');
});
