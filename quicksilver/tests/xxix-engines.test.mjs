// Prompt XXIX: server engines behind the one Deobfuscate.
//   - api/engine.js: who may start an engine, on what input, and what comes back (the engine itself is mocked here)
//   - recoverFromBytecode (src/api.js): the page's half — decompile what an engine returns, recover, classify, report honestly
//   - src/pipeline/unified.js: detection picks the adapter; a missing, declined or failing engine falls back to QuickSilver's own passes
//   - verify.js: what the behaviour comparison must know about MoonSec V3's runtime (its wait() prelude, callback-only originals)
//   - the vendored MoonSec V3 engine: the string-constant rule per kind of build, and its evaluator's isolation from the host
// No third-party sample is needed: the fixtures in tests/corpus/engine were written for these tests. The measurements on the public
// MoonSec V3 collection are in docs/REPORT-XXIX.md; a test at the end repeats a few of them when local/terrorlua is present.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { createHandler, ENGINES, accepts } from '../api/engine.js';
import { runEngine, isolationMode } from '../api/_lib/isolate.js';
import { recoverFromBytecode, recoverFromSource, recoverSource } from '../src/api.js';
import { selectAdapter, ADAPTERS } from '../src/pipeline/engines.js';
import { deobfuscate } from '../src/pipeline/unified.js';
import { analyzeLoader } from '../src/loader/analyze.js';
import { decodePayload } from '../src/loader/payload.js';
import { detect } from '../src/detect/detect.js';
import { verifyRecovery } from '../src/adaptive/verify.js';
import { parse } from '../src/core/parser.js';
import { parseChunk } from '../src/sandbox/bytecode.js';
import { decompile } from '../src/decompile/decompile.js';
import { print } from '../src/core/printer.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const fx = (n) => path.join(here, 'corpus', 'engine', n);
const hexToBin = (hex) => hex.trim().replace(/../g, (h) => String.fromCharCode(parseInt(h, 16)));
const REBUILT = hexToBin(fs.readFileSync(fx('rebuilt-program.luac.hex'), 'utf8'));
const enc = (s) => Uint8Array.from([...s].map((c) => c.charCodeAt(0) & 255));
// the banner is all detection needs for MoonSec V3 (its only rule); a script that only carries the banner is a stand-in for the format
const MOONSEC = "([[This file was protected with MoonSec V3]]):gsub('.+', (function(a) _probe = a; end)); return (function(...) return ... end)(1)";
const chunk = (s) => Buffer.concat([Buffer.from('\x1bLuaQ\x00\x01\x04\x08\x04\x08\x00', 'latin1'), Buffer.from(s, 'latin1')]);

function call(handler, { method = 'POST', body = null, headers = {} } = {}) {
  return new Promise((resolve) => {
    const out = { headers: {} };
    const res = {
      statusCode: 200,
      setHeader(k, v) { out.headers[k.toLowerCase()] = v; },
      end(b) { out.status = this.statusCode; out.body = JSON.parse(b); resolve(out); },
    };
    handler({ method, headers, body }, res);
  });
}
const post = (h, body, headers) => call(h, { body, headers });
const b64 = (s) => Buffer.from(s, 'latin1').toString('base64');

// ---- api/engine.js -------------------------------------------------------------------------------------------------------------------------

test('engine endpoint: GET lists the engines with their licence and the isolation this host gives', async () => {
  const r = await call(createHandler({ env: {} }), { method: 'GET' });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.engines.map((e) => e.id), ['moonsec-v3', 'prometheus-vm']);
  assert.match(r.body.engines[0].licence, /^GPL-3\.0/);
  assert.match(r.body.engines[1].licence, /^MIT/);
  assert.ok(['namespaces', 'process'].includes(r.body.isolation));
  assert.equal(r.headers['cache-control'], 'no-store');
});

test('engine endpoint: nothing starts without an attestation, a known engine, a script, and the format the engine reads', async () => {
  let runs = 0;
  const h = createHandler({ env: {}, run: async () => { runs++; return { status: 0, timedOut: false, output: chunk('x'), stderr: '', ms: 1, isolation: 'process' }; } });
  const noAttest = await post(h, { engine: 'moonsec-v3', source: b64(MOONSEC) });
  assert.equal(noAttest.status, 400); assert.equal(noAttest.body.outcome, 'attestation_required');
  const unknown = await post(h, { engine: 'luraph-15', source: b64(MOONSEC), attest: true });
  assert.equal(unknown.status, 400); assert.equal(unknown.body.outcome, 'unknown-engine');
  const empty = await post(h, { engine: 'moonsec-v3', source: '', attest: true });
  assert.equal(empty.status, 400); assert.equal(empty.body.outcome, 'invalid-input');
  // QuickSilver's own detection decides what the engine is given; a plain script never reaches it
  const plain = await post(h, { engine: 'moonsec-v3', source: b64('print("hello")'), attest: true });
  assert.equal(plain.status, 422); assert.equal(plain.body.outcome, 'not-this-format');
  const cross = await post(h, { engine: 'moonsec-v3', source: b64(fs.readFileSync(path.join(here, 'corpus/obfuscated/zartha/s07_roblox_style__constants.lua'), 'latin1')), attest: true });
  assert.equal(cross.status, 422); assert.match(cross.body.message, /zartha/i);
  assert.equal(runs, 0);
  const off = await post(createHandler({ env: { QS_ENGINE_MODE: 'off' }, run: async () => { runs++; } }), { engine: 'moonsec-v3', source: b64(MOONSEC), attest: true });
  assert.equal(off.status, 503); assert.equal(off.body.outcome, 'disabled');
  const big = await post(createHandler({ env: { QS_ENGINE_MAX_BYTES: '16' }, run: async () => { runs++; } }), { engine: 'moonsec-v3', source: b64(MOONSEC), attest: true });
  assert.equal(big.status, 413);
  const foreign = await post(h, { engine: 'moonsec-v3', source: b64(MOONSEC), attest: true }, { 'sec-fetch-site': 'cross-site' });
  assert.equal(foreign.status, 403);
  assert.equal(runs, 0);
});

test('engine endpoint: the answer is the engine’s Lua 5.1 chunk, or a failure named as one', async () => {
  const answers = [
    { status: 0, timedOut: false, output: Buffer.from(REBUILT, 'latin1'), stderr: '', ms: 12, isolation: 'namespaces' },
    { status: 1, timedOut: false, output: null, stderr: 'moonsec: could not find the bytecode string\n', ms: 3, isolation: 'namespaces' },
    { status: 124, timedOut: true, output: null, stderr: '', ms: 60000, isolation: 'namespaces' },
    { status: 0, timedOut: false, output: Buffer.from('print("not bytecode")'), stderr: '', ms: 2, isolation: 'namespaces' },
  ];
  const seen = [];
  const h = createHandler({ env: {}, run: async (o) => { seen.push(o); return answers.shift(); } });
  const ok = await post(h, { engine: 'moonsec-v3', source: b64(MOONSEC), attest: true });
  assert.equal(ok.status, 200);
  assert.equal(Buffer.from(ok.body.bytecode, 'base64').toString('latin1'), REBUILT);
  assert.equal(ok.body.isolation, 'namespaces');
  assert.match(ok.body.licence, /GPL-3\.0/);
  assert.equal(seen[0].driver, 'qs-driver.js');
  assert.equal(Buffer.from(seen[0].input).toString('latin1'), MOONSEC);
  const failed = await post(h, { engine: 'moonsec-v3', source: b64(MOONSEC), attest: true });
  assert.equal(failed.status, 422); assert.equal(failed.body.outcome, 'engine-failed'); assert.match(failed.body.message, /could not find the bytecode string/);
  const slow = await post(h, { engine: 'moonsec-v3', source: b64(MOONSEC), attest: true });
  assert.equal(slow.status, 504); assert.equal(slow.body.outcome, 'timeout');
  const odd = await post(h, { engine: 'moonsec-v3', source: b64(MOONSEC), attest: true });
  assert.equal(odd.status, 502); assert.match(odd.body.message, /not a Lua 5\.1 chunk/);
});

test('engine endpoint: a per-instance rate limit and a concurrency limit', async () => {
  let t = 0;
  const h = createHandler({ env: { QS_ENGINE_RPM: '2' }, now: () => t, run: async () => ({ status: 0, timedOut: false, output: chunk('x'), stderr: '', ms: 1, isolation: 'process' }) });
  assert.equal((await post(h, { engine: 'moonsec-v3', source: b64(MOONSEC), attest: true })).status, 200);
  assert.equal((await post(h, { engine: 'moonsec-v3', source: b64(MOONSEC), attest: true })).status, 200);
  const limited = await post(h, { engine: 'moonsec-v3', source: b64(MOONSEC), attest: true });
  assert.equal(limited.status, 429); assert.equal(limited.body.outcome, 'rate-limited');
  t = 61_000;
  assert.equal((await post(h, { engine: 'moonsec-v3', source: b64(MOONSEC), attest: true })).status, 200);
  let release;
  const gate = new Promise((r) => { release = r; });
  const busy = createHandler({ env: { QS_ENGINE_CONCURRENCY: '1' }, run: async () => { await gate; return { status: 0, timedOut: false, output: chunk('x'), stderr: '', ms: 1, isolation: 'process' }; } });
  const first = post(busy, { engine: 'moonsec-v3', source: b64(MOONSEC), attest: true });
  const second = await post(busy, { engine: 'moonsec-v3', source: b64(MOONSEC), attest: true });
  assert.equal(second.status, 429); assert.equal(second.body.outcome, 'busy');
  release();
  assert.equal((await first).status, 200);
});

test('engine endpoint: Premium when the deployment enforces licences', async () => {
  const h = createHandler({ env: { QS_REQUIRE_LICENSE: '1' }, run: async () => { throw new Error('must not run'); } });
  const r = await post(h, { engine: 'moonsec-v3', source: b64(MOONSEC), attest: true });
  assert.ok([401, 503].includes(r.status), `status ${r.status}`);
  assert.equal(r.body.ok, false);
});

test('engine endpoint: accepts() is QuickSilver’s detection, not the engine’s', () => {
  assert.equal(accepts(ENGINES['moonsec-v3'], MOONSEC).ok, true);
  assert.equal(accepts(ENGINES['moonsec-v3'], 'local x = 1').ok, false);
});

// ---- recoverFromBytecode ------------------------------------------------------------------------------------------------------------------

test('fromBytecode: the engine’s chunk is decompiled, cleaned, and reported as rebuilt but unverified', () => {
  const r = recoverFromBytecode(REBUILT, { original: MOONSEC, engine: 'moonsec-v3', label: ADAPTERS[0].label, family: 'moonsec_v3', familyLabel: 'MoonSec V3', licence: ADAPTERS[0].licence });
  assert.equal(r.ok, true);
  const body = r.output.split('-- (end of report)\n')[1];
  assert.doesNotThrow(() => parse(body));
  assert.match(body, /game:GetService\("Players"\)/);
  assert.match(body, /for i = 1, #list do/);
  // a control byte in a global's name is written as Lua writes it, not as a JSON escape
  assert.ok(body.includes('_G["odd\\29name"] = 7'), body);
  assert.ok(!/\\u00/.test(body));
  // what was done, by what, under which licence; and that behaviour was not checked
  assert.match(r.output, /rebuilt by a server engine \(moonsec-v3; GPL-3\.0\)/);
  assert.match(r.output, /Recognised from the structure of the code[^\n]*MoonSec V3/);
  assert.match(r.output, /its behaviour is unverified/);
  assert.ok(!/No obfuscation was detected/.test(r.output));
  assert.equal(r.confidence.level, 'medium');
  assert.equal(r.outcome.outcome, 'syntax-valid-unverified');
  assert.equal(r.outcome.success, false);
  assert.deepEqual(r.steps.slice(0, 2).map((s) => [s.id, s.status]), [['moonsec-v3.engine', 'applied'], ['decompile.bytecode', 'applied']]);
  assert.deepEqual(r.vm.stats, { functions: 2, instructions: r.vm.stats.instructions, constants: r.vm.stats.constants, undecompiled: 0 });
});

test('fromBytecode: an answer that is not a chunk is a failure, never an empty success', () => {
  const r = recoverFromBytecode('print(1)', { original: MOONSEC, engine: 'moonsec-v3', family: 'moonsec_v3' });
  assert.equal(r.ok, false);
  assert.equal(r.output, null);
  assert.match(r.error.message, /bytecode could not be read/);
});

test('banner-only recognition is reported as such (Prompt XXIX: the report said "structure" for a banner)', () => {
  const r = recoverSource(MOONSEC, { nexus: true });
  assert.match(r.output, /Recognised from its banner only[^\n]*\n?[^\n]*MoonSec V3/);
  assert.ok(!/Recognised from the structure of the code[^\n]*MoonSec/.test(r.output));
});

test('decompiler: a global whose name holds control bytes is written with Lua escapes', () => {
  const ch = parseChunk(REBUILT);
  const text = print(decompile(ch).ast);
  assert.ok(text.includes('_G["odd\\29name"]'));
  assert.doesNotThrow(() => parse(text));
});

// ---- the one Deobfuscate ------------------------------------------------------------------------------------------------------------------

function deps(extra = {}) {
  const recovered = [];
  return {
    recovered,
    analyze: (s, o) => analyzeLoader(s, o),
    decode: (b, m) => decodePayload(b, m),
    detect: (t) => detect(t),
    recover: (t) => { recovered.push(t); return recoverSource(t, { nexus: true }); },
    fetchLink: async () => ({ ok: false, status: 404, error: 'HTTP 404' }),
    ...extra,
  };
}

test('unified: MoonSec V3 goes to its engine; the person never chooses, and the delivered program is the engine’s', async () => {
  const asked = [];
  const d = deps({
    serverEngine: async (adapter, t) => { asked.push([adapter.id, t]); return { ok: true, bytecode: REBUILT, licence: adapter.licence, isolation: 'namespaces', ms: 40 }; },
    fromBytecode: async (bc, o) => recoverFromBytecode(bc, o),
  });
  const R = await deobfuscate({ text: MOONSEC, name: 'protected.lua', bytes: enc(MOONSEC) }, d);
  assert.deepEqual(asked, [['moonsec-v3', MOONSEC]]);
  assert.equal(d.recovered.length, 0, 'QuickSilver’s own passes were not needed');
  assert.match(R.final.output, /game:GetService\("Players"\)/);
  assert.equal(R.final.node.recovery.engine.id, 'moonsec-v3');
  assert.equal(R.verdict.outcome, 'syntax-valid-unverified');
  assert.ok(R.notes.some((n) => n.kind === 'engine' && /rebuilt by the server engine moonsec-v3 \(GPL-3\.0, isolation: namespaces\)/.test(n.text)));
  const vm = R.stages.find((s) => s.id === 'vm');
  assert.equal(vm.status, 'done');
});

test('unified: no engine on the deployment, a declined attestation, or a failing engine — QuickSilver’s own passes, and a note why', async () => {
  for (const [serverEngine, why] of [
    [async () => ({ ok: false, outcome: 'unavailable', message: 'this deployment does not offer the MoonSec V3 engine' }), /does not offer/],
    [async () => ({ ok: false, outcome: 'declined', message: 'you chose to keep the script in the browser' }), /keep the script in the browser/],
    [async () => ({ ok: false, outcome: 'engine-failed', message: 'The engine could not rebuild this script: no result' }), /could not rebuild/],
    [async () => { throw new Error('socket hang up'); }, /socket hang up/],
    [async () => ({ ok: true, bytecode: 'not a chunk' }), /could not be decompiled/],
  ]) {
    const d = deps({ serverEngine, fromBytecode: async (bc, o) => recoverFromBytecode(bc, o) });
    const R = await deobfuscate({ text: MOONSEC }, d);
    assert.equal(d.recovered.length, 1, String(why));
    assert.ok(R.notes.some((n) => n.kind === 'engine' && why.test(n.text) && /QuickSilver's own passes were used instead/.test(n.text)), JSON.stringify(R.notes));
    assert.ok(!R.final || !R.final.node.recovery.engine);
    assert.notEqual(R.verdict.outcome, 'validated');
  }
});

test('unified: formats without an adapter never reach a server engine', async () => {
  let asked = 0;
  const d = deps({ serverEngine: async () => { asked++; return { ok: false }; }, fromBytecode: async () => null });
  await deobfuscate({ text: fs.readFileSync(path.join(here, 'corpus/obfuscated/zartha/s07_roblox_style__constants.lua'), 'utf8') }, d);
  await deobfuscate({ text: 'local x = 1\nprint(x)' }, d);
  assert.equal(asked, 0);
  assert.equal(selectAdapter(detect('print(1)')), null);
  assert.equal(selectAdapter(detect(MOONSEC)).id, 'moonsec-v3');
});

test('unified: the behaviour comparison is told what the adapter knows about the format’s runtime', async () => {
  const seen = [];
  const d = deps({
    serverEngine: async (adapter) => ({ ok: true, bytecode: REBUILT, licence: adapter.licence }),
    fromBytecode: async (bc, o) => recoverFromBytecode(bc, o),
    verify: async (t, rec, o) => { seen.push(o); return { verdict: 'inconclusive', notes: ['test'] }; },
  });
  await deobfuscate({ text: MOONSEC }, d);
  assert.deepEqual(seen, [{ originalPrelude: ['wait()'], needsMainReference: true }]);
});

// ---- verify.js options ---------------------------------------------------------------------------------------------------------------------

test('verify: a format runtime’s prelude is not counted, and only when the rebuilt program lacks it', () => {
  assert.equal(verifyRecovery('wait() print(1)', 'print(1)').verdict, 'different');
  const v = verifyRecovery('wait() print(1)', 'print(1)', { originalPrelude: ['wait()'] });
  assert.equal(v.verdict, 'identical');
  assert.match(v.notes.join(' '), /obfuscator's own runtime/);
  const both = verifyRecovery('wait() print(1)', 'wait() print(1)', { originalPrelude: ['wait()'] });
  assert.equal(both.verdict, 'identical'); assert.equal(both.notes.length, 0);
  assert.equal(verifyRecovery('wait() print(1)', 'print(2)', { originalPrelude: ['wait()'] }).verdict, 'different');
});

test('verify: an original that only runs as a callback with stand-in arguments is no reference', () => {
  // the shape of the keyed MoonSec V3 builds in the public collection: a global function the sandbox later calls with stand-ins, which
  // calls its argument; the main chunk itself stops with an error
  const original = 'wait()\ncheck = function(cb) cb(165) end\nlocal x = nil\nx()';
  const plain = verifyRecovery(original, 'print(1)', { originalPrelude: ['wait()'] });
  assert.equal(plain.verdict, 'different');
  const v = verifyRecovery(original, 'print(1)', { originalPrelude: ['wait()'], needsMainReference: true });
  assert.equal(v.verdict, 'inconclusive');
  assert.equal(v.reference, 'none');
  assert.match(v.notes.join(' '), /arg1\(165\)/);
});

// ---- the vendored engine ----------------------------------------------------------------------------------------------------------------

const ENGINE_DIR = path.join(here, '..', 'api', '_engine', 'moonsec');
const require = createRequire(import.meta.url);

test('moonsec engine: string constants — verbatim in keyless builds, marker byte and key in keyed builds', () => {
  const { decodeConstant } = require(path.join(ENGINE_DIR, 'src/deobf/utils/string-decoding.js'));
  const bytes = (s) => Uint8Array.from(Buffer.from(s, 'latin1'));
  // keyless: an emoji-led UTF-8 string keeps its first byte (the former rule dropped it)
  const emoji = Buffer.from('\u{1F600} hi', 'utf8').toString('latin1');
  assert.equal(decodeConstant(0, bytes(emoji), false), emoji);
  assert.equal(decodeConstant(0, bytes('Players'), false), 'Players');
  // keyed: a marker byte above 0x7F, then each byte minus the key
  const key = 76;
  const sealed = '\xfe' + [...'tostring'].map((c) => String.fromCharCode((c.charCodeAt(0) - key + 256) % 256)).join('');
  assert.equal(decodeConstant(key, bytes(sealed), true), 'tostring');
  assert.equal(decodeConstant(key, bytes('Players'), true), 'Players');
});

test('moonsec engine: its key-expression evaluator cannot reach the host (run the way the server runs it)', { timeout: 120_000 }, async () => {
  const probe = fs.readFileSync(fx('evaluator-escape-probe.lua'));
  const e = ENGINES['moonsec-v3'];
  const r = await runEngine({ engineDir: e.dir, driver: e.driver, modules: e.modules, input: probe, timeoutS: 60 });
  assert.notEqual(r.status, 0);
  assert.equal(r.output, null);
  assert.match(r.stderr, /nil value|not a number|attempt to/i);
  assert.equal(r.isolation, isolationMode());
});

test('moonsec engine: the licence and the record of what QuickSilver changed travel with it', () => {
  const lic = fs.readFileSync(path.join(ENGINE_DIR, 'LICENSE'), 'utf8');
  assert.match(lic, /GNU GENERAL PUBLIC LICENSE\s+Version 3/);
  const notice = fs.readFileSync(path.join(ENGINE_DIR, 'NOTICE.md'), 'utf8');
  for (const needle of ['tupsutumppu/MoonsecDeobfuscator', 'lua-eval.js', 'string-decoding.js', 'serializer.js', 'decompiler.js', 'os.execute']) assert.ok(notice.includes(needle), needle);
  const pkg = JSON.parse(fs.readFileSync(path.join(ENGINE_DIR, 'package.json'), 'utf8'));
  assert.equal(pkg.license, 'GPL-3.0');
  // no binaries were brought in
  const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((x) => (x.isDirectory() ? walk(path.join(d, x.name)) : [path.join(d, x.name)]));
  assert.deepEqual(walk(ENGINE_DIR).filter((f) => /\.(exe|jar|so|dll)$|\/luadec$/.test(f)), []);
});

// ---- the public collection, when present ---------------------------------------------------------------------------------------------------

const COLLECTION = path.join(here, '..', 'local', 'terrorlua', 'MoonSec', 'V3');
const haveCollection = fs.existsSync(COLLECTION);

test('moonsec engine on the public collection (local/terrorlua, git-ignored): rebuilt, decompiled, parses', { skip: haveCollection ? false : 'local/terrorlua is not present', timeout: 300_000 }, async () => {
  const e = ENGINES['moonsec-v3'];
  // two keyless builds whose originals run in the sandbox and two keyed builds (named in docs/REPORT-XXIX.md)
  for (const name of ['066bd7869b17f56c.lua', '000a52d75667a3ad.lua', '0531b066133fe461.lua', '02d1240e65b1fbd8.lua']) {
    const src = fs.readFileSync(path.join(COLLECTION, name));
    const r = await runEngine({ engineDir: e.dir, driver: e.driver, modules: e.modules, input: src, timeoutS: 60 });
    assert.equal(r.status, 0, `${name}: ${r.stderr}`);
    const rec = recoverFromBytecode(r.output.toString('latin1'), { original: src.toString('latin1'), engine: 'moonsec-v3', family: 'moonsec_v3', familyLabel: 'MoonSec V3', licence: e.licence });
    assert.equal(rec.ok, true, name);
    assert.doesNotThrow(() => parse(rec.output), name);
    assert.ok(['syntax-valid-unverified', 'partial'].includes(rec.outcome.outcome), `${name}: ${rec.outcome.outcome}`);
  }
});

test('verify: the same error under another variable name stays "different", and the note says so', () => {
  const v = verifyRecovery('local j = nil\nprint(1)\nlocal x = j.y', 'print(1)\nlocal _r0 = nil\nlocal x = _r0.y');
  assert.equal(v.verdict, 'different');
  assert.match(v.notes.join(' '), /differ only in the variable they name/);
  const real = verifyRecovery('print(1)\nlocal x = nil + 1', 'print(1)\nlocal _r0 = nil\nlocal x = _r0.y');
  assert.ok(!/differ only in the variable/.test(real.notes.join(' ')));
});

// ---- the Prometheus VM adapter: asked only when QuickSilver's own result keeps the VM, used only when the behaviour check agrees ----------

const PROM = (n) => fs.readFileSync(path.join(here, 'corpus/obfuscated/prometheus', n), 'latin1');
const PROM_WEAK = PROM('s01_minify_basic__Weak.lua');

test('engine endpoint: the Prometheus engine takes only a Prometheus VM build, and its answer must be Lua that parses', async () => {
  const e = ENGINES['prometheus-vm'];
  assert.equal(accepts(e, PROM_WEAK).ok, true);
  assert.equal(accepts(e, PROM('s01_minify_basic__Minify.lua')).ok, false, 'a Minify build has no VM');
  assert.equal(accepts(e, MOONSEC).ok, false);
  const answers = [
    { status: 0, timedOut: false, output: Buffer.from('local x = 1\nprint(x)\n'), stderr: '', ms: 5, isolation: 'process' },
    { status: 0, timedOut: false, output: Buffer.from('local = = 1'), stderr: '', ms: 5, isolation: 'process' },
  ];
  const h = createHandler({ env: {}, run: async () => answers.shift() });
  const ok = await post(h, { engine: 'prometheus-vm', source: b64(PROM_WEAK), attest: true });
  assert.equal(ok.status, 200);
  assert.equal(ok.body.output, 'lua-source');
  assert.equal(Buffer.from(ok.body.source, 'base64').toString(), 'local x = 1\nprint(x)\n');
  assert.equal(ok.body.bytecode, undefined);
  const bad = await post(h, { engine: 'prometheus-vm', source: b64(PROM_WEAK), attest: true });
  assert.equal(bad.status, 502); assert.match(bad.body.message, /does not parse/);
});

test('prometheus engine: a Weak build (which crashed on "BLOCK_TERMINATORS is not defined" before the fix) is lifted, run the way the server runs it', { timeout: 120_000 }, async () => {
  const e = ENGINES['prometheus-vm'];
  const r = await runEngine({ engineDir: e.dir, driver: e.driver, modules: e.modules, input: Buffer.from(PROM_WEAK, 'latin1'), timeoutS: 60 });
  assert.equal(r.status, 0, r.stderr);
  const lifted = r.output.toString('latin1');
  assert.doesNotThrow(() => parse(lifted));
  const original = fs.readFileSync(path.join(here, 'corpus/originals/s01_minify_basic.lua'), 'latin1');
  assert.equal(verifyRecovery(original, lifted).verdict, 'identical');
  assert.equal(verifyRecovery(PROM_WEAK, lifted).verdict, 'identical');
});

function promDeps(extra = {}) {
  const asked = [];
  const d = deps({
    serverEngine: async (adapter, t) => { asked.push(adapter.id); return extra.answer ? extra.answer(adapter, t) : { ok: false, outcome: 'unavailable', message: 'none' }; },
    fromSource: async (src, o) => recoverFromSource(src, o),
    fromBytecode: async (bc, o) => recoverFromBytecode(bc, o),
    verify: extra.verify === null ? undefined : (extra.verify || (async (t, rec, o) => verifyRecovery(t, rec, { ...(o || {}), fuel: 200e6, timeMs: 30000 }))),
  });
  d.asked = asked;
  return d;
}
const LIFT = { cache: null };
async function liftedWeak() {
  if (!LIFT.cache) {
    const e = ENGINES['prometheus-vm'];
    const r = await runEngine({ engineDir: e.dir, driver: e.driver, modules: e.modules, input: Buffer.from(PROM_WEAK, 'latin1'), timeoutS: 60 });
    LIFT.cache = r.output.toString('latin1');
  }
  return LIFT.cache;
}

test('unified: when QuickSilver’s own result keeps the Prometheus VM, the engine is asked, and its program is used because it behaves like the script', { timeout: 180_000 }, async () => {
  const src = await liftedWeak();
  const d = promDeps({ answer: (a) => ({ ok: true, output: 'lua-source', source: src, licence: a.licence, isolation: 'namespaces' }) });
  const R = await deobfuscate({ text: PROM_WEAK, name: 'weak.lua', bytes: enc(PROM_WEAK) }, d);
  assert.deepEqual(d.asked, ['prometheus-vm']);
  assert.equal(d.recovered.length, 1, 'QuickSilver’s own passes ran first');
  assert.equal(R.final.node.recovery.engine.id, 'prometheus-vm');
  assert.deepEqual(R.final.node.recovery.engine.gate, { verdict: 'identical', coverage: 1 });
  assert.equal(R.verdict.outcome, 'validated');
  assert.match(R.final.output, /lifted to Lua by a server engine \(prometheus-vm; MIT\)/);
  assert.ok(R.notes.some((n) => /used because it behaved like the script in the sandbox/.test(n.text)));
});

test('unified: an engine program that behaves differently is not used; QuickSilver’s own result is kept and the note says why', { timeout: 180_000 }, async () => {
  const src = (await liftedWeak()).replace(/print\(/, 'print("tampered", ');
  const d = promDeps({ answer: (a) => ({ ok: true, output: 'lua-source', source: src, licence: a.licence }) });
  const R = await deobfuscate({ text: PROM_WEAK }, d);
  assert.deepEqual(d.asked, ['prometheus-vm']);
  assert.ok(!R.final.node.recovery.engine);
  assert.ok(!/tampered/.test(R.final.output));
  assert.ok(R.notes.some((n) => /was not used, because the behaviour comparison with the script did not confirm it \(different/.test(n.text)), JSON.stringify(R.notes));
  assert.notEqual(R.verdict.outcome, 'validated');
});

test('unified: without the behaviour check the Prometheus engine is never asked; a build QuickSilver finishes on its own never reaches it', async () => {
  const off = promDeps({ verify: null, answer: () => { throw new Error('must not be asked'); } });
  const R = await deobfuscate({ text: PROM_WEAK }, off);
  assert.deepEqual(off.asked, []);
  assert.ok(R.notes.some((n) => /behaviour check is off for this run/.test(n.text)));
  const minify = promDeps({ answer: () => { throw new Error('must not be asked'); } });
  await deobfuscate({ text: PROM('s01_minify_basic__Minify.lua') }, minify);
  assert.deepEqual(minify.asked, []);
});

test('prometheus engine: licence, the record of the fix, and nothing but its own code', () => {
  const dir = path.join(here, '..', 'api', '_engine', 'prometheus');
  assert.match(fs.readFileSync(path.join(dir, 'LICENSE'), 'utf8'), /^MIT License/);
  const notice = fs.readFileSync(path.join(dir, 'NOTICE.md'), 'utf8');
  for (const needle of ['LeakD', 'BLOCK_TERMINATORS', 'behaviour comparison', 'os', 'io']) assert.ok(notice.includes(needle), needle);
  const src = fs.readFileSync(path.join(dir, 'src/lua/parser.js'), 'latin1');
  assert.ok(!/BLOCK_TERMINATORS\.has/.test(src));
  const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((x) => (x.isDirectory() ? walk(path.join(d, x.name)) : [path.join(d, x.name)]));
  const code = walk(dir).filter((f) => f.endsWith('.js')).map((f) => fs.readFileSync(f, 'latin1')).join('\n');
  assert.ok(!/child_process|require\(['"](?:net|http|https|dgram|worker_threads)['"]\)/.test(code));
});
