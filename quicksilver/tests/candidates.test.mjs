// Compatibility with eight more open-source candidates: Colisseum, Zenfus, Simple-Lua-Obfuscator, AztupBrew, and the four repositories that
// turned out to hold no obfuscator code (Joker, Zero Lua, Strong FiveM, NeuroForge / Lua-Polymorph-VM-Forge).
//
// What is tested, and on what:
//   * Zenfus (MIT): its real output is committed (tests/corpus/obfuscated/zenfus); detection, the statement that a VM is not recovered
//     statically, and the behavioural trace are checked against it.
//   * Colisseum (AGPL-3.0), Simple-Lua-Obfuscator and the AztupBrew sample (no licence file): their output is generated or copied into
//     tests/corpus/obfuscated-local/ (git-ignored; see tests/corpus/tools/gen_external.py). Those tests are skipped, with a reason, when the
//     files are absent, so a fresh checkout stays green and honest about what it did not check.
//   * Everything else uses scripts written for these tests.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { recover } from '../src/recover/pipeline.js';
import { detect } from '../src/detect/detect.js';
import { parse } from '../src/core/parser.js';
import { evaluatePass } from '../src/passes/evaluate.js';
import { traceScript } from '../src/trace/trace.js';
import { removeColisseumGuard, isColisseumGuard } from '../src/recover/colisseum.js';
import { fidelity } from '../src/core/fidelity.js';
import { print } from '../src/core/printer.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const read = (p) => fs.readFileSync(p).toString('latin1');
const skipOracle = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';
after(() => oracle.stopOracle());

const localDir = (name) => path.join(corpus, 'obfuscated-local', name);
const localManifest = (name) => { const p = path.join(localDir(name), 'manifest.json'); return fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, 'utf8')) : null; };
const skipLocal = (name) => (fs.existsSync(path.join(localDir(name), name === 'aztupbrew' ? 'example.lua' : 'manifest.json')) ? false : `tests/corpus/obfuscated-local/${name} is not present (generate it with tests/corpus/tools/gen_external.py; its licence does not allow committing it)`);
const original = (name) => read(path.join(corpus, 'originals', name));
const family = (d, id) => d.families.find((f) => f.id === id);
const traceKey = (r) => r.events.filter((e) => e.kind !== 'load').map((e) => `${e.kind}:${e.text}`).join('\n');
const NEW_FAMILIES = ['colisseum', 'zenfus', 'simple_lua', 'aztupbrew', 'joker', 'zerolua', 'fivem_strong', 'neuroforge'];

// ---- Zenfus (committed, MIT) -----------------------------------------------------------------------------------------------------------

const zenfus = JSON.parse(fs.readFileSync(path.join(corpus, 'obfuscated/zenfus/manifest.json'), 'utf8'));

test('Zenfus: the fixtures are real tool output and say which of them the tool itself got wrong', () => {
  assert.equal(zenfus.licence, 'MIT');
  assert.equal(zenfus.entries.length, 8);
  assert.ok(zenfus.entries.some((e) => e.behavior === 'equivalent'), 'at least one fixture behaves like its original');
  assert.ok(zenfus.entries.some((e) => e.behavior !== 'equivalent'), 'the tool-broken ones are labelled, not hidden');
});

for (const e of zenfus.entries.filter((x) => x.status === 'ok')) {
  test(`zenfus/${e.file}: detected as Zenfus and reported as a VM that is not recovered statically`, () => {
    const src = read(path.join(corpus, 'obfuscated/zenfus', e.file));
    const det = detect(src);
    const fam = family(det, 'zenfus');
    assert.ok(fam && fam.confidence >= 0.95, `confidence ${fam && fam.confidence}`);
    assert.equal(det.families.filter((f) => f.confidence >= 0.5).length, 1, 'no other family is reported');
    assert.ok(fam.evidence.some((x) => x.rule === 'vm' && x.unrecoverable));
    const r = recover(src, {});
    assert.equal(r.ok, true);
    assert.ok(r.confidence.score <= 0.4, `a VM is still there, so confidence must be low (${r.confidence.score})`);
    assert.ok(r.confidence.hints.includes('trace'), 'the trace is offered');
    assert.ok(/lua_wrap_state/.test(r.output), 'nothing pretends to have rebuilt the program');
  });
}

for (const e of zenfus.entries.filter((x) => x.status === 'ok' && x.behavior === 'equivalent')) {
  test(`zenfus/${e.file}: the trace reproduces what the original program does`, () => {
    const t = traceScript(read(path.join(corpus, 'obfuscated/zenfus', e.file)), {});
    const base = traceScript(original(e.sample), {});
    assert.equal(t.status, 'completed', t.error || t.ended);
    assert.equal(traceKey(t), traceKey(base));
    assert.equal(t.output, base.output);
  });
}

// ---- Colisseum (local only) ---------------------------------------------------------------------------------------------------------------

const colisseum = localManifest('colisseum');
for (const e of colisseum ? colisseum.entries.filter((x) => x.status === 'ok') : []) {
  const vm = e.config === 'total' || e.config === 'fortress';
  test(`colisseum/${e.file}: detected${vm ? ', and flagged as a VM that is not recovered statically' : ''}`, { skip: skipLocal('colisseum') }, () => {
    const det = detect(read(path.join(localDir('colisseum'), e.file)));
    const fam = family(det, 'colisseum');
    assert.ok(fam && fam.confidence >= 0.95, `confidence ${fam && fam.confidence}`);
    assert.equal(det.families.filter((f) => f.confidence >= 0.5).length, 1);
    if (['medium', 'hard', 'full'].includes(e.config)) assert.ok(fam.evidence.some((x) => x.rule === 'tamper-guard'));
    assert.equal(fam.evidence.some((x) => x.rule === 'vm' && x.unrecoverable), vm);
  });
}

for (const e of colisseum ? colisseum.entries.filter((x) => x.status === 'ok' && ['easy', 'medium', 'hard', 'full'].includes(x.config)) : []) {
  test(`colisseum/${e.file}: recovered with the sandbox, readable, and it prints what the original program prints`, { skip: skipLocal('colisseum') || skipOracle }, async () => {
    const src = read(path.join(localDir('colisseum'), e.file));
    const r = recover(src, { sandbox: { enabled: true } });
    assert.equal(r.ok, true, JSON.stringify(r.warnings));
    assert.ok(!/Oh Noes|__COLISSEUM_TAMPER__|coli_/.test(r.output), 'the guard, its brand or the machine names are left');
    assert.ok(!/\(\{\s*\d+(,\s*\d+)*\s*\},\s*\d{6,}\)/.test(r.output), 'an encrypted string is left');
    const want = await oracle.runLua(original(e.sample), 'lua54');
    const got = await oracle.runLua(r.output, 'lua54');
    assert.ok(got.ok, `${got.error}\n${r.output.slice(0, 400)}`);
    assert.equal(got.stdout, want.stdout);
    assert.ok(r.confidence.score >= 0.85, `confidence ${r.confidence.score}`);
    // s05 keeps closures the decompiler-free pipeline cannot rename back; every other program comes back almost verbatim
    if (e.sample !== 's05_nested_functions.lua') assert.ok(fidelity(original(e.sample), r.output).score >= 0.9, 'fidelity to the original');
  });
}

for (const e of colisseum ? colisseum.entries.filter((x) => x.status === 'ok' && ['total', 'fortress'].includes(x.config)).slice(0, 4) : []) {
  test(`colisseum/${e.file}: a VM output is reported honestly, not as recovered`, { skip: skipLocal('colisseum') }, () => {
    const r = recover(read(path.join(localDir('colisseum'), e.file)), {});
    assert.equal(r.ok, true);
    assert.ok(r.confidence.score <= 0.4, `confidence ${r.confidence.score}`);
    assert.ok(r.confidence.hints.includes('trace'));
  });
}

test('colisseum: the trace is stopped by the tamper guard because its stand-in environment looks like an executor (documented limit)', { skip: skipLocal('colisseum') }, () => {
  const e = colisseum.entries.find((x) => x.config === 'medium' && x.sample === 's01_minify_basic.lua');
  const t = traceScript(read(path.join(localDir('colisseum'), e.file)), {});
  assert.equal(t.status, 'error');
  assert.match(t.error, /Oh Noes!, An error ocurred: 0x6B0C/, 'the executor-signature check fired');
  // with the guard removed, the same trace reproduces the program
  const r = recover(read(path.join(localDir('colisseum'), e.file)), { sandbox: { enabled: true } });
  const again = traceScript(r.output, {});
  assert.equal(again.status, 'completed');
  assert.equal(again.output, traceScript(original(e.sample), {}).output);
});

// ---- Simple-Lua-Obfuscator (local only) ----------------------------------------------------------------------------------------------------

const simple = localManifest('simple_lua');
for (const e of simple ? simple.entries.filter((x) => x.status === 'ok') : []) {
  test(`simple_lua/${e.file}: detected, both layers unwrapped statically-plus-sandbox, and the program is unchanged`, { skip: skipLocal('simple_lua') || skipOracle }, async () => {
    const src = read(path.join(localDir('simple_lua'), e.file));
    const fam = family(detect(src), 'simple_lua');
    assert.ok(fam && fam.confidence >= 0.9);
    const r = recover(src, { sandbox: { enabled: true } });
    assert.equal(r.ok, true);
    assert.ok(!/\bload\(/.test(r.output), 'a load() is left');
    const want = await oracle.runLua(original(e.sample), 'lua51');
    const got = await oracle.runLua(r.output, 'lua51');
    assert.ok(got.ok, got.error);
    assert.equal(got.stdout, want.stdout);
    assert.ok(fidelity(original(e.sample), r.output).score >= 0.9);
  });
}

// ---- AztupBrew -------------------------------------------------------------------------------------------------------------------------------

test('AztupBrew: the banner alone is enough to name it, and the IronBrew 2 rebuild is not attempted on it', () => {
  const src = '--[[\nAztupBrew(Fork of IronBrew2): obfuscation; Version 2.7.2\n]]\nprint(1)\n';
  const det = detect(src);
  const fam = family(det, 'aztupbrew');
  assert.ok(fam && fam.confidence >= 0.9, `confidence ${fam && fam.confidence}`);
  assert.equal(fam.version, '2.7.2');
  const ib = family(det, 'ironbrew2');
  assert.ok(!ib || ib.confidence < 0.5, 'the "Fork of IronBrew2" wording is a mention, not the IronBrew 2 watermark');
  const r = recover(src, {});
  assert.ok(!r.steps.some((s) => s.id === 'ironbrew2'), 'no IronBrew 2 step ran');
});

test('AztupBrew: the eight-local prelude of its VM is recognised as structure, and as a VM that is not recovered', () => {
  const src = 'return (function(g, a, a)\n  local j = string.char\n  local e = string.sub\n  local o = table.concat\n  local n = math.ldexp\n  local m = getfenv or function() return _ENV end\n  local l = select\n  local a = unpack or table.unpack\n  local k = tonumber\n  return g\nend)(1)\n';
  const fam = family(detect(src), 'aztupbrew');
  assert.ok(fam, 'detected');
  assert.ok(fam.evidence.some((x) => x.rule === 'prelude' && x.unrecoverable));
  assert.ok(!family(detect('return (function(g)\n  local j = string.char\n  local e = string.sub\n  return g\nend)(1)\n'), 'aztupbrew'), 'two library locals are not a prelude');
});

test('AztupBrew: the published sample is detected and its behaviour is described by the trace', { skip: skipLocal('aztupbrew') }, () => {
  const src = read(path.join(localDir('aztupbrew'), 'example.lua'));
  const fam = family(detect(src), 'aztupbrew');
  assert.ok(fam && fam.confidence >= 0.9 && fam.version === '2.7.2');
  const t = traceScript(src, {});
  assert.equal(t.status, 'completed', t.error || t.ended);
  assert.equal(t.output, '1\n', 'the sample was made from print("1")');
  const r = recover(src, {});
  assert.ok(r.confidence.hints.includes('trace'));
});

// ---- the four repositories without code -----------------------------------------------------------------------------------------------------

test('Joker, Zero Lua, Strong FiveM and NeuroForge are named when mentioned, and never claimed with more than registry confidence', () => {
  const cases = {
    joker: '-- Protected by Joker Obfuscator v2.0.0 https://jokerobfuscator.com/\nprint(1)',
    zerolua: '-- zerolua.pages.dev\nprint(1)',
    fivem_strong: '-- dsc.gg/revuex\nprint(1)',
    neuroforge: '-- NeuroForge VM build 12\nprint(1)',
  };
  for (const [id, src] of Object.entries(cases)) {
    const fam = family(detect(src), id);
    assert.ok(fam, `${id} is detected from its name`);
    assert.ok(fam.confidence <= 0.3, `${id}: no sample output exists, so confidence stays low (${fam.confidence})`);
  }
});

test('none of the new signatures fires on any original program or on output of the tools already supported', () => {
  const dirs = ['originals', 'obfuscated/prometheus', 'obfuscated/hercules', 'obfuscated/ironbrew2', 'obfuscated/loaders'];
  let files = 0;
  for (const d of dirs) {
    for (const f of fs.readdirSync(path.join(corpus, d)).filter((x) => x.endsWith('.lua'))) {
      files++;
      const hit = detect(read(path.join(corpus, d, f))).families.find((x) => NEW_FAMILIES.includes(x.id) && x.confidence >= 0.3);
      assert.ok(!hit, `${d}/${f} was reported as ${hit && hit.id}`);
    }
  }
  assert.ok(files > 100, `only ${files} files were checked`);
});

// ---- generic pieces the candidates needed ---------------------------------------------------------------------------------------------------

test('Colisseum guard: a top-level block with the brand, the hook name and the first check key goes; one with only some of them stays', () => {
  const guard = 'local credit = "x"\ndo\n  local brand = "ABC Oh Noes!, An error ocurred: 0x"\n  local hook = rawget(_G, "__COLISSEUM_TAMPER__")\n  local codes = { ["debug-hook"] = "3E19" }\n  if hook then error(brand .. codes["debug-hook"], 0) end\nend\nprint("kept")\n';
  const ast = parse(guard);
  assert.equal(isColisseumGuard(ast.body[1]), true);
  assert.equal(removeColisseumGuard(ast).changed, 1);
  const out = recover(guard, {}).output;
  assert.match(out, /print\("kept"\)/);
  assert.doesNotMatch(out, /Oh Noes/);
  const partial = 'do\n  local brand = "Oh Noes!, An error ocurred: 0x"\n  error(brand, 0)\nend\nprint("kept")\n';
  assert.equal(isColisseumGuard(parse(partial).body[0]), false);
  assert.match(recover(partial, {}).output, /Oh Noes/);
});

test('an empty branch whose test is arithmetic over number-only locals is dropped; one that could call a metamethod is not', () => {
  const junk = recover('local n = 2541\nif n * 0 ~= 0 then end\nlocal a, b = 788, 1278\nif a > b then end\nprint(n)\n', {}).output;
  assert.doesNotMatch(junk, /\bif\b/);
  assert.match(junk, /print\(/);
  const kept = recover('local n = tonumber(arg)\nif n * 0 ~= 0 then end\nprint(n)\n', {}).output;
  assert.match(kept, /\bif\b/, 'n may be anything, and n * 0 may call __mul');
});

// a decoder built on a linear congruential generator: the multiplication passes 2^53, where doubles and Lua 5.4 integers part ways
const lcgEncode = (text, seed, exact) => {
  const out = [];
  if (exact) {
    let s = BigInt(seed);
    for (const ch of text) { s = (s * 1103515245n + 12345n) % 2147483648n; out.push((ch.charCodeAt(0) + Number((s / 65536n) % 256n)) % 256); }
  } else {
    let s = seed;
    for (const ch of text) { s = (s * 1103515245 + 12345) % 2147483648; out.push((ch.charCodeAt(0) + (Math.floor(s / 65536) % 256)) % 256); }
  }
  return out;
};
const lcgScript = (strings, exact) => {
  const decoder = 'local _0xd = function(t, s)\n  local o = {}\n  for i = 1, #t do\n    s = (s * 1103515245 + 12345) % 2147483648\n    o[i] = string.char((t[i] - math.floor(s / 65536) % 256) % 256)\n  end\n  return table.concat(o)\nend\n';
  const calls = strings.map((text, i) => `print(_0xd({ ${lcgEncode(text, 1000 + i * 7919, exact).join(', ')} }, ${1000 + i * 7919}))`);
  return decoder + calls.join('\n') + '\n';
};
const WORDS = ['primes: 2,3,5,7,11', 'gcd(84, 36) = 12', 'clamp: 10 0 7', 'Hello, QuickSilver!', 'the quick brown fox'];

test('evaluate: a decoder written for Lua 5.4 integers is decoded with integers, because only that reading gives text', () => {
  const r = evaluatePass(parse(lcgScript(WORDS, true)), { sandbox: { enabled: true } });
  assert.equal(r.evaluated, WORDS.length);
  assert.equal(r.arithmetic.use, 'Lua 5.4 integers');
  assert.ok(r.arithmetic.differing >= 1);
  const out = recover(lcgScript(WORDS, true), { sandbox: { enabled: true } }).output;
  for (const w of WORDS) assert.ok(out.includes(JSON.stringify(w)), `missing ${w}`);
});

test('evaluate: a decoder written for doubles (Lua 5.1 / Luau) is decoded with doubles', () => {
  const r = evaluatePass(parse(lcgScript(WORDS, false)), { sandbox: { enabled: true } });
  assert.equal(r.evaluated, WORDS.length);
  assert.equal(r.arithmetic.use, 'doubles');
  const out = recover(lcgScript(WORDS, false), { sandbox: { enabled: true } }).output;
  for (const w of WORDS) assert.ok(out.includes(JSON.stringify(w)), `missing ${w}`);
});

test('evaluate: when neither reading gives text, the sites are left as they are rather than guessed', () => {
  // random numbers instead of an encoding: both readings produce noise
  const noise = 'local _0xd = function(t, s)\n  local o = {}\n  for i = 1, #t do\n    s = (s * 1103515245 + 12345) % 2147483648\n    o[i] = string.char((t[i] + math.floor(s / 65536)) % 256)\n  end\n  return table.concat(o)\nend\n'
    + Array.from({ length: 5 }, (_, i) => `print(_0xd({ ${[17 + i, 201, 9, 77, 140, 3, 250, 88, 61, 2, 199, 34].join(', ')} }, ${555 + i}))`).join('\n') + '\n';
  const r = evaluatePass(parse(noise), { sandbox: { enabled: true } });
  assert.equal(r.evaluated, 0);
  assert.equal(r.arithmetic.use, null);
  assert.ok(r.rejected >= 5);
});

test('trace: arithmetic past 2^53 is run both ways and the readable result is the one shown, with a note', () => {
  const t = traceScript(lcgScript(WORDS, true), {});
  assert.equal(t.status, 'completed');
  assert.equal(t.output, WORDS.map((w) => `${w}\n`).join(''));
  assert.match(t.arithmetic, /Lua 5\.4 integers/);
  assert.match(t.script, /^-- Arithmetic: /m);
  const doubles = traceScript(lcgScript(WORDS, false), {});
  assert.equal(doubles.output, WORDS.map((w) => `${w}\n`).join(''));
  assert.match(doubles.arithmetic, /^doubles/);
  const plain = traceScript('print(2 * 3)', {});
  assert.equal(plain.arithmetic, undefined, 'no note when nothing went past 2^53');
});

// a loader in the shape Simple-Lua-Obfuscator writes (base64 of a string of decimal escapes, cut into pieces, handed to load), with names of my own
const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
const toBase64 = (s) => {
  let out = '';
  for (let i = 0; i < s.length; i += 3) {
    const n = (s.charCodeAt(i) << 16) | ((s.charCodeAt(i + 1) || 0) << 8) | (s.charCodeAt(i + 2) || 0);
    out += B64[(n >> 18) & 63] + B64[(n >> 12) & 63] + (i + 1 < s.length ? B64[(n >> 6) & 63] : '=') + (i + 2 < s.length ? B64[n & 63] : '=');
  }
  return out;
};
const packedLoader = (program) => {
  const escapes = [...program].map((c) => `\\${c.charCodeAt(0)}`).join('');
  const b64 = toBase64(escapes);
  const pieces = b64.match(/.{1,5}/g).map((p) => JSON.stringify(p)).join(',');
  return `do local alphabet = '${B64}'\nlocal pieces = {${pieces}}\nlocal function unb64(data)\n  data = string.gsub(data, '[^' .. alphabet .. '=]', '')\n  return (data:gsub('.', function(x)\n    if x == '=' then return '' end\n    local bits, f = '', alphabet:find(x) - 1\n    for i = 6, 1, -1 do bits = bits .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end\n    return bits\n  end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)\n    if #x ~= 8 then return '' end\n    local c = 0\n    for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end\n    return string.char(c)\n  end))\nend\ndo local joined = '' for _, v in pairs(pieces) do joined = joined .. v end\nlocal code = unb64(joined)\ncode = 'load("' .. code .. '")()'\nload(code)() end end`;
};

test('layers: base64 pieces holding a string of decimal escapes handed to load are unwrapped when the sandbox is on', () => {
  const program = 'local function double(x)\n  return x * 2\nend\nprint(double(21))\n';
  const packed = packedLoader(program);
  const off = recover(packed, {});
  assert.match(off.output, /\bload\b/, 'without the sandbox the payload is not computed');
  const on = recover(packed, { sandbox: { enabled: true } });
  assert.equal(on.ok, true);
  assert.doesNotMatch(on.output, /\bload\b/);
  assert.match(on.output, /local function double\(x\)/);
  assert.match(on.output, /print\(double\(21\)\)/);
});

test('layers: a helper function the loader defines and uses is allowed, a global it merely sets is not', () => {
  const helper = 'function unhex(s) return (s:gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end)) end\nloadstring(unhex("7072696e7428312b3129"))()\n';
  assert.match(recover(helper, { sandbox: { enabled: true } }).output, /^print\(2\)$/m);
  const body = 'local parts = {}\nfor _, c in ipairs({ "p", "r", "i", "n", "t", "(", "2", ")" }) do parts[#parts + 1] = c end\nloadstring(table.concat(parts))()\n';
  assert.match(recover(body, { sandbox: { enabled: true } }).output, /^print\(2\)$/m, 'the computed payload is read in the sandbox');
  assert.match(recover('counter = 1\n' + body, { sandbox: { enabled: true } }).output, /loadstring/, 'a global that nothing reads makes the script more than a loader');
});

test('printer: a label keeps its name (Lua 5.4 outputs use goto continue)', () => {
  const src = 'for i = 1, 3 do\n  if i == 2 then\n    goto continue\n  end\n  print(i)\n  ::continue::\nend\n';
  const out = print(parse(src));
  assert.match(out, /::continue::/);
  assert.doesNotMatch(out, /undefined/);
  assert.equal(print(parse(out)), out, 'printing is stable');
});
