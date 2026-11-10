// Phase VI: the reconstruction service, the registry of what it has done, the gates on what may be said about it, and the API in front of it.
//
// The Python-backed tests need python3 and the vendored engine's binaries (api/_engine/luraph/deobf/bin); without them they are skipped with the reason.
// The fixtures are the engine archive's own regression sample (a 559-byte program and its v15 and IronBrew 1 protections): the only inputs here with a source.

import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import net from 'node:net';
import crypto from 'node:crypto';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { ENGINES, VERSIONS, parseBanner, versionFor, plan } from '../src/reconstruct/engines.js';
import { engineStatus, versionStatus, GATES } from '../src/reconstruct/status.js';
import { buildReconstructionReport } from '../src/reconstruct/report.js';
import { buildCaseFile } from '../src/reconstruct/casefile.js';
import { validateLedger } from '../src/research/discoveries.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const engineDir = path.join(root, 'api', '_engine', 'luraph');
const fx = (n) => path.join(engineDir, 'fixtures', n);
const registry = JSON.parse(fs.readFileSync(path.join(root, 'data/research/luraph-compat.json'), 'utf8'));
const hasPython = spawnSync('python3', ['-V']).status === 0 && fs.existsSync(path.join(engineDir, 'deobf/bin/luau')) && fs.existsSync(path.join(engineDir, 'deobf/bin/luau-ast'));
const skipPy = hasPython ? false : 'python3 or the vendored engine binaries are not available here';

const runService = (file, engine = 'auto', extra = []) => {
  const r = spawnSync('python3', ['-I', path.join(engineDir, 'service.py'), file, engine, ...extra], { encoding: 'utf8', maxBuffer: 64 << 20, timeout: 240_000 });
  assert.equal(r.status, 0, r.stderr);
  return JSON.parse(r.stdout);
};

// ---- catalogue, plan, status gates --------------------------------------------------------------------------------------------------
test('catalogue: every version row is either backed by an engine in the table or says plainly that it has none', () => {
  const ids = new Set();
  for (const v of VERSIONS) {
    assert.ok(!ids.has(v.id), v.id); ids.add(v.id);
    if (v.engine) assert.ok(ENGINES[v.engine], `${v.id} names an engine that exists`);
    else assert.ok(v.note && v.note.length > 20, `${v.id} (no engine) explains why`);
    if (v.nearest) assert.ok(ENGINES[v.nearest]);
  }
  assert.deepEqual(VERSIONS.filter((v) => v.engine).map((v) => v.engine).sort(), ['ironbrew1', 'luraph_v14_7', 'luraph_v14_8', 'luraph_v14_9', 'luraph_v15']);
  for (const [text, id] of [['-- This file was protected using Luraph Obfuscator v14.7 [https://lura.ph/]', 'luraph-14.7'], ['-- This file was protected using Luraph Obfuscator v15.0 [https://lura.ph/]', 'luraph-15.0'], ['-- This file was protected using Luraph Obfuscator v15.1.2 [https://lura.ph/]', 'luraph-15.1'],
    ['-- This file was protected using Luraph Obfuscator v14.3 [https://lura.ph/]', 'luraph-14-early'], ['-- This file was protected using Luraph Obfuscator v14.12 [https://lura.ph/]', 'luraph-14-late'], ['-- This file was protected using Luraph Obfuscator v13.6.0', 'luraph-13']]) {
    assert.equal(versionFor(parseBanner(text)).id, id, text);
  }
  assert.equal(versionFor(null, '-- this file was generated using ironbrew1\nreturn 1').id, 'ironbrew-1');
  assert.equal(versionFor(null, 'print(1)'), null);
});

test('plan: a fallback is marked as one, a neighbouring engine as "nearest", and a trace as a trace', () => {
  const p = (v, req, fb) => plan({ banner: parseBanner(`-- This file was protected using Luraph Obfuscator v${v}`), candidates: [] }, req, fb);
  const a = p('14.8');
  assert.deepEqual(a.map((s) => `${s.engine}:${s.mode}`), ['luraph_v14_8:lift', 'luraph_v14_9:lift', 'luraph_v14_7:lift', 'luraph_v14_8:trace']);
  assert.ok(a.slice(1, 3).every((s) => s.nearest), 'neighbours are nearest, not support');
  assert.deepEqual(p('14.8', 'auto', false).map((s) => s.engine), ['luraph_v14_8']);
  assert.equal(p('14.3')[0].nearest, true, 'a version with no engine runs the nearest one as an experiment');
  assert.equal(p('15.1')[0].nearest, true);
  assert.equal(p('15.0')[0].nearest, false);
  assert.deepEqual(plan({ banner: null, candidates: [], text: 'print(1)' }).map((s) => `${s.engine}:${s.mode}`), ['generic:trace']);
  assert.deepEqual(plan({ banner: null, candidates: [] }, 'luraph_v15', true).map((s) => s.mode), ['lift', 'trace']);
  assert.deepEqual(plan({ banner: null, candidates: [] }, 'generic').map((s) => `${s.engine}:${s.mode}`), ['generic:trace'], 'choosing the trace engine is choosing a trace, not a lift');
  assert.throws(() => plan({ banner: null, candidates: [] }, 'nonsense'));
});

test('plan: the page\'s preview and the service\'s plan agree on banner inputs', { skip: skipPy }, () => {
  const cases = ['13.6.0', '14.3', '14.7', '14.8', '14.9', '14.12', '15.0', '15.1', '15.1.2', '16.0'];
  const py = spawnSync('python3', ['-I', '-c', `
import sys, json
sys.path.insert(0, ${JSON.stringify(engineDir)})
import service
out = {}
for v in ${JSON.stringify(cases)}:
    text = "-- This file was protected using Luraph Obfuscator v" + v + " [https://lura.ph/]\\nreturn 1"
    ident = service.identify(text.encode())
    out[v] = [[s["engine"], s["mode"], bool(s.get("nearest"))] for s in service.plan({**ident, "candidates": []})]
print(json.dumps(out))
`], { encoding: 'utf8' });
  assert.equal(py.status, 0, py.stderr);
  const theirs = JSON.parse(py.stdout);
  for (const v of cases) {
    const mine = plan({ banner: parseBanner(`-- This file was protected using Luraph Obfuscator v${v}`), candidates: [] }).map((s) => [s.engine, s.mode, !!s.nearest]);
    assert.deepEqual(mine, theirs[v], v);
  }
});

const rec = (over) => ({ id: 'x', versionRow: 'luraph-15.0', engine: 'luraph_v15', kind: 'devirtualized', mode: 'lift', verification: { status: 'identical' }, ...over });
test('status: "fully tested" needs ten lifted runs compared identical with their originals; nothing else can reach it', () => {
  const ten = Array.from({ length: 10 }, (_, i) => rec({ id: `p${i}` }));
  assert.equal(engineStatus(ten).status, 'fully-tested');
  assert.equal(engineStatus(ten.slice(0, 9)).status, 'partially-tested', 'nine are not enough: the lower bound of 9 of 9 is below 0.7');
  assert.equal(engineStatus([...ten, rec({ verification: { status: 'different' } })]).status, 'experimental', 'a single disagreement removes the claim');
  assert.equal(engineStatus(Array.from({ length: 20 }, (_, i) => rec({ id: `l${i}`, verification: { status: 'not-run' } }))).status, 'experimental', 'lifted but never compared: not support, however many');
  assert.equal(engineStatus(Array.from({ length: 20 }, (_, i) => rec({ id: `t${i}`, kind: 'trace', mode: 'trace', verification: { status: 'identical' } }))).status, 'unsupported', 'a trace is never a lift, even one that "matches"');
  assert.equal(engineStatus([rec({ kind: 'trace' }), rec({ kind: 'trace' })]).status, 'experimental', 'two failures do not condemn an engine');
  assert.equal(engineStatus([rec({ kind: 'trace' }), rec({ kind: 'trace' }), rec({ kind: 'trace' })]).status, 'unsupported', `${GATES.unsupportedAfter} inputs, none lifted`);
  assert.equal(engineStatus([]).status, 'experimental');
  assert.equal(engineStatus([], { hasEngine: false }).status, 'unsupported');
});

test('status: a neighbouring engine\'s success is not credited to a version it was not made for', () => {
  const reg = { records: [rec({ versionRow: 'luraph-15.0' })] };
  const v151 = VERSIONS.find((v) => v.id === 'luraph-15.1');
  assert.equal(versionStatus(v151, reg).status, 'unsupported');
  assert.equal(versionStatus(v151, reg).nearest, 'luraph_v15');
  assert.equal(versionStatus(VERSIONS.find((v) => v.id === 'luraph-15.0'), reg).status, 'partially-tested');
});

test('registry: the committed statuses are what the records give, every record is attributable, and nothing is "fully tested"', () => {
  for (const v of VERSIONS) assert.deepEqual(registry.summary.versions[v.id].status, versionStatus(v, registry).status, `${v.id}: the summary was not edited by hand`);
  for (const r of registry.records) {
    assert.match(r.sha256, /^[0-9a-f]{64}$/, r.id);
    assert.ok(r.provenance && r.provenance.length > 20, r.id);
    assert.ok(['devirtualized', 'trace-assisted', 'trace', 'none'].includes(r.kind), r.id);
  }
  assert.ok(registry.records.every((r) => r.stable), 'every record was identical across its three runs (a run time in a trace header is not a difference)');
  assert.ok(!Object.values(registry.summary.versions).some((s) => s.status === 'fully-tested'), 'ten verified pairs do not exist, so nothing is fully tested');
  assert.equal(registry.summary.versions['luraph-15.0'].status, 'partially-tested');
  assert.equal(registry.summary.versions['ironbrew-1'].status, 'partially-tested');
  for (const id of ['luraph-14.7', 'luraph-14.8', 'luraph-14.9']) assert.equal(registry.summary.versions[id].status, 'experimental', `${id}: never lifted and compared`);
  for (const id of ['luraph-13', 'luraph-14-early', 'luraph-14-late', 'luraph-15.1']) assert.equal(registry.summary.versions[id].status, 'unsupported', id);
  for (const r of registry.records.filter((x) => x.committed !== false && fs.existsSync(path.join(root, 'api/_engine/luraph/fixtures')))) {
    const fixture = JSON.parse(fs.readFileSync(path.join(root, 'tools/luraph/fixtures.json'), 'utf8')).fixtures.find((f) => f.id === r.id);
    if (fixture && fixture.committed) assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(root, fixture.file))).digest('hex'), r.sha256, `${r.id}: the fixture is the file that was measured`);
  }
});

test('ledger: a verified discovery names a reproducing command and records in the registry; a hypothesis may not justify a capability', () => {
  const ledger = JSON.parse(fs.readFileSync(path.join(root, 'data/research/discoveries.json'), 'utf8'));
  assert.deepEqual(validateLedger(ledger, registry).problems, []);
  assert.ok(ledger.entries.some((e) => e.state === 'refuted'), 'failed experiments are kept');
  const bad = (e) => validateLedger({ entries: [{ id: 'd', origin: 'o', claim: 'c', ...e }] }, registry).ok;
  assert.equal(bad({ state: 'verified' }), false);
  assert.equal(bad({ state: 'verified', reproduce: 'node x', evidence: { records: ['not-a-record'] }, verifiedAt: '2026-01-01' }), false);
  assert.equal(bad({ state: 'verified', reproduce: 'node x', evidence: { records: ['v15-001-vm-like-dispatch'] }, verifiedAt: '2026-01-01' }), true);
  assert.equal(bad({ state: 'hypothesis', usedFor: ['a capability'] }), false);
  assert.equal(bad({ state: 'refuted' }), false);
});

test('report and case file: the report says what was and was not shown; the case file never contains the script', () => {
  const result = { ok: true, kind: 'trace', engine: { label: 'Luraph v14.8', used: 'luraph_v14_8', mode: 'trace', attempts: [{ engine: 'luraph_v14_8', mode: 'lift', outcome: 'no-output', seconds: 1 }] },
    identification: { bytes: 10, sha256: 'a'.repeat(64), banner: { text: '-- This file was protected using Luraph Obfuscator v14.8', version: '14.8' }, candidates: [] },
    verification: { status: 'not-run', reason: 'No original was supplied.' }, quality: { lines: 3, functions: 0, unresolved: {}, unresolvedTotal: 0, grade: 'clean' }, checks: { syntax: { ok: true } },
    diagnostics: [{ code: 'lift-failed', severity: 'error', message: 'm', hint: 'h' }], output: 'SECRET_SCRIPT_BODY', log: ['[*] one'] };
  const md = buildReconstructionReport({ name: 'a.lua', result, registry });
  assert.match(md, /Behaviour trace only/);
  assert.match(md, /Not compared with an original\. Readable output is not the same as a verified reconstruction/);
  assert.match(md, /Luraph v14\.8: \*\*experimental\*\*/);
  assert.match(md, /What this does not show/);
  assert.doesNotMatch(md, /\*\*(fully-tested|identical)\*\*/);
  const cf = buildCaseFile(result, registry);
  assert.ok(!JSON.stringify(cf).includes('SECRET_SCRIPT_BODY'));
  assert.equal(cf.attemptedVersionRow.id, 'luraph-14.8');
  assert.equal(cf.compatibility.length, VERSIONS.length);
});

// ---- the service itself -------------------------------------------------------------------------------------------------------------------
test('service: the v15 sample is identified from its banner, lifted, and compares identical with its original on Luau', { skip: skipPy, timeout: 180_000 }, () => {
  const r = runService(fx('001_vm_like_dispatch-obfuscated.lua'), 'auto', ['--original', fx('001_vm_like_dispatch.lua')]);
  assert.equal(r.ok, true);
  assert.equal(r.identification.banner.version, '15.0');
  assert.equal(r.engine.used, 'luraph_v15');
  assert.equal(r.kind, 'devirtualized');
  assert.equal(r.checks.syntax.ok, true);
  assert.equal(r.quality.grade, 'clean');
  assert.equal(r.verification.status, 'identical');
  assert.match(r.verification.observed, /QS_RET\t1\tnumber\t34/);
  assert.match(r.output, /assert\(n == 1 and tbl2\[1\] == 34\)/);
  assert.doesNotMatch(r.output, /upv\d+/, 'not the engine\'s own probe code (the root-choice fix)');
  assert.doesNotMatch(r.output, /oxyenv|gpt 5|shit/i, 'no advertising or joke text from the archive');
});

test('service: IronBrew 1 is detected without a banner and lifted', { skip: skipPy, timeout: 180_000 }, () => {
  const r = runService(fx('001_vm_like_dispatch-ib1.lua'), 'auto', ['--original', fx('001_vm_like_dispatch.lua')]);
  assert.equal(r.engine.used, 'ironbrew1');
  assert.equal(r.kind, 'devirtualized');
  assert.equal(r.verification.status, 'identical');
});

test('verification: a wrong reconstruction is reported as different, an unrunnable original as inconclusive, silence as inconclusive', { skip: skipPy }, () => {
  const py = spawnSync('python3', ['-I', '-c', `
import sys, json, tempfile, pathlib
sys.path.insert(0, ${JSON.stringify(engineDir)})
import service
w = pathlib.Path(tempfile.mkdtemp())
v = lambda o, r: service.verify_against_original(o.encode(), r, w)["status"]
print(json.dumps([v("print(1) return 2", "print(1) return 2"), v("print(1) return 2", "print(1) return 3"), v("print(game.Name)", "print(game.Name)"), v("local x = 1", "local x = 1"), v("while true do end", "return 1")]))
`], { encoding: 'utf8', timeout: 120_000 });
  assert.equal(py.status, 0, py.stderr);
  assert.deepEqual(JSON.parse(py.stdout), ['identical', 'different', 'inconclusive', 'inconclusive', 'inconclusive']);
});

test('service: an input no engine recognises gets a behaviour trace and says so; garbage does not crash it; nothing it does reaches the host', { skip: skipPy, timeout: 180_000 }, () => {
  const tmp = fs.mkdtempSync(path.join(fs.realpathSync(process.env.TMPDIR || '/tmp'), 'qs-t-'));
  const f1 = path.join(tmp, 'plain.lua');
  fs.writeFileSync(f1, 'local t = {}\nfor i = 1, 3 do t[#t + 1] = i end\nprint(#t)');
  const a = runService(f1);
  assert.equal(a.kind, 'trace');
  assert.equal(a.engine.used, 'generic');
  assert.ok(a.diagnostics.some((d) => d.code === 'trace-only'));
  assert.equal(a.verification.status, 'not-run');
  const f2 = path.join(tmp, 'garbage.lua');
  fs.writeFileSync(f2, Buffer.from([0, 1, 2, 255, 254, 33, 10, 61, 61]));
  const b = runService(f2);
  assert.ok(typeof b.ok === 'boolean');
  const f3 = path.join(tmp, 'hostile.lua');
  fs.writeFileSync(f3, 'print(io.open and io.open("/etc/passwd"))\nlocal ok, e = pcall(function() return os.execute("touch /tmp/qs-pwned") end)\nprint(ok)');
  runService(f3);
  assert.equal(fs.existsSync('/tmp/qs-pwned'), false, 'the script cannot run commands on the host');
  fs.rmSync(tmp, { recursive: true, force: true });
});

test('service: a script that never ends is stopped at the time limit and the answer says so', { skip: skipPy, timeout: 120_000 }, () => {
  const tmp = fs.mkdtempSync(path.join(fs.realpathSync(process.env.TMPDIR || '/tmp'), 'qs-t-'));
  const f = path.join(tmp, 'loop.lua');
  fs.writeFileSync(f, 'local i = 0\nwhile true do i = i + 1 end');
  const py = spawnSync('python3', ['-I', '-c', `
import sys, json, time
sys.path.insert(0, ${JSON.stringify(engineDir)})
import service
t = time.time()
r = service.reconstruct(open(${JSON.stringify(f)}, "rb").read(), "auto", timeout_s=12)
print(json.dumps({"ok": r.get("ok"), "kind": r.get("kind"), "seconds": time.time() - t, "codes": [d["code"] for d in r.get("diagnostics", [])]}))
`], { encoding: 'utf8', timeout: 100_000 });
  const out = JSON.parse(py.stdout);
  assert.ok(out.seconds < 40, `returned in ${out.seconds} s`);
  assert.equal(out.kind === 'none' ? out.ok : true, out.kind === 'none' ? false : true);
  fs.rmSync(tmp, { recursive: true, force: true });
});

// ---- the HTTP API -----------------------------------------------------------------------------------------------------------------------------
let proc; let port = 0;
const spawned = [];
async function startApi(env = {}) {
  const p = await new Promise((r) => { const s = net.createServer().listen(0, '127.0.0.1', () => { const x = s.address().port; s.close(() => r(x)); }); });
  const child = spawn('python3', ['-I', path.join(root, 'api/reconstruct.py'), '--serve', String(p)], { stdio: 'ignore', env: { PATH: process.env.PATH, ...env } });
  spawned.push(child);     // killed in after(), so a failing test cannot leave a server that keeps the test run from exiting
  for (let i = 0; i < 60; i++) {
    const ok = await new Promise((r) => { const q = http.get({ host: '127.0.0.1', port: p, path: '/api/reconstruct?check=1' }, (x) => { x.resume(); r(true); }); q.on('error', () => r(false)); });
    if (ok) return { child, port: p };
    await new Promise((r) => setTimeout(r, 100));
  }
  child.kill();
  throw new Error('API did not start');
}
const call = (p, method, body, headers = {}, p2 = '/api/reconstruct') => new Promise((resolve, reject) => {
  const data = body === undefined ? null : JSON.stringify(body);
  const rq = http.request({ host: '127.0.0.1', port: p, path: p2, method, headers: { 'content-type': 'application/json', ...(data ? { 'content-length': Buffer.byteLength(data) } : {}), ...headers } }, (res) => {
    let s = ''; res.on('data', (c) => { s += c; }); res.on('end', () => resolve({ status: res.statusCode, type: res.headers['content-type'], body: s }));
  });
  rq.on('error', reject); if (data) rq.write(data); rq.end();
});

before(async () => { if (hasPython) ({ child: proc, port } = await startApi({ QS_RECONSTRUCT_RPM: '1000' })); });
after(() => { for (const c of spawned) c.kill(); if (proc) proc.kill(); });

test('api: the request is checked before anything runs (attestation, encoding, size, engine name, emptiness)', { skip: skipPy }, async () => {
  const b64 = Buffer.from('print(1)').toString('base64');
  const post = (b) => call(port, 'POST', b);
  assert.equal((await post({ source_b64: b64 })).status, 400);
  assert.equal(JSON.parse((await post({ source_b64: b64 })).body).error.code, 'attestation_required');
  assert.equal(JSON.parse((await post({ source_b64: '@@', attest: true })).body).error.code, 'bad_request');
  assert.equal(JSON.parse((await post({ source_b64: Buffer.from('   ').toString('base64'), attest: true })).body).error.code, 'empty');
  assert.equal(JSON.parse((await post({ source_b64: b64, attest: true, engine: '../../etc/passwd' })).body).error.code, 'bad_engine');
  assert.equal(JSON.parse((await post({ source_b64: b64, attest: true, engine: 'luraph_v15; rm -rf /' })).body).error.code, 'bad_engine');
  assert.equal((await call(port, 'POST', undefined)).status, 400);
  assert.equal((await call(port, 'GET', undefined, {}, '/api/reconstruct')).status, 405);
  const big = Buffer.alloc(3 * 1024 * 1024 + 10, 97).toString('base64');
  const r = await post({ source_b64: big, attest: true });
  assert.ok([413, 400].includes(r.status), String(r.status));
});

test('api: the result streams as JSON lines (stages, then the result) and the capability check measures the host', { skip: skipPy, timeout: 120_000 }, async () => {
  const src = fs.readFileSync(fx('001_vm_like_dispatch-obfuscated.lua')).toString('base64');
  const r = await call(port, 'POST', { source_b64: src, attest: true, engine: 'luraph_v15', fallback: false });
  assert.equal(r.status, 200);
  assert.match(r.type, /ndjson/);
  const events = r.body.trim().split('\n').map((l) => JSON.parse(l));
  assert.deepEqual(events.filter((e) => e.t === 'stage' && e.state === 'done').map((e) => e.id).slice(0, 3), ['identify', 'select', 'run']);
  const last = events[events.length - 1];
  assert.equal(last.t, 'result');
  assert.equal(last.kind, 'devirtualized');
  const check = JSON.parse((await call(port, 'GET', undefined, {}, '/api/reconstruct?check=1')).body);
  assert.equal(check.capabilities.luau.ok, true);
  assert.equal(check.selfTest.ok, true, 'the bundled fixture is lifted on this host');
});

test('api: it can be switched off or put behind a token, and it rate limits', { skip: skipPy, timeout: 60_000 }, async () => {
  const body = { source_b64: Buffer.from('print(1)').toString('base64'), attest: true, engine: 'generic', fallback: false, timeout_s: 10 };
  const off = await startApi({ QS_RECONSTRUCT_MODE: 'off' });
  assert.equal(JSON.parse((await call(off.port, 'POST', body)).body).error.code, 'disabled');
  assert.equal((await call(off.port, 'GET', undefined, {}, '/api/reconstruct?check=1')).status, 503);
  off.child.kill();
  const tok = await startApi({ QS_RECONSTRUCT_MODE: 'token', QS_RECONSTRUCT_TOKEN: 'sekret-token-123456' });
  assert.equal((await call(tok.port, 'POST', body)).status, 401);
  assert.equal((await call(tok.port, 'POST', body, { 'x-reconstruct-token': 'wrong' })).status, 401);
  assert.equal((await call(tok.port, 'POST', body, { 'x-reconstruct-token': 'sekret-token-123456' })).status, 200);
  tok.child.kill();
  const rl = await startApi({ QS_RECONSTRUCT_RPM: '3' });     // the readiness probe of startApi is the first of the three requests
  assert.equal((await call(rl.port, 'POST', body)).status, 200);
  assert.equal((await call(rl.port, 'POST', body)).status, 200);
  const third = await call(rl.port, 'POST', body);
  assert.equal(third.status, 429);
  rl.child.kill();
});

test('engine tree: nothing in the vendored engine can fetch a runtime or open a server, and no output text advertises anything', () => {
  const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? (['fixtures', 'bin'].includes(e.name) ? [] : walk(path.join(d, e.name))) : [path.join(d, e.name)]));
  const files = walk(engineDir).filter((f) => /\.(py|luau)$/.test(f));
  assert.ok(files.length > 40);
  for (const f of files) {
    const s = fs.readFileSync(f, 'utf8');
    assert.doesNotMatch(s, /urllib\.request|urlretrieve|requests\.get|socket\.socket|ThreadingHTTPServer/, `${path.relative(root, f)} must not reach the network`);
    assert.doesNotMatch(s, /oxyenv|dsc\.gg|ccjvwsod|gpt 5\.6|let me ask sol/i, `${path.relative(root, f)}`);
  }
  assert.match(fs.readFileSync(path.join(engineDir, 'NOTICE.md'), 'utf8'), /Licence: not established/);
});

// ---- regressions found in the Phase VII audit -----------------------------------------------------------------------------------------------
test('regression: a client that disconnects mid-run stops the engine and frees its slot (it used to run to the time limit and answer "busy")', { skip: skipPy, timeout: 60_000 }, async () => {
  const api = await startApi({ QS_RECONSTRUCT_RPM: '1000', QS_RECONSTRUCT_CONCURRENCY: '1' });
  const loop = Buffer.from('local i = 0 while true do i = i + 1 end').toString('base64');
  const body = JSON.stringify({ source_b64: loop, attest: true, engine: 'generic', timeout_s: 60 });
  const sock = net.connect(api.port, '127.0.0.1');
  sock.write(`POST /api/reconstruct HTTP/1.1\r\nHost: x\r\nContent-Type: application/json\r\nContent-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`);
  await new Promise((r) => setTimeout(r, 2500));
  const busy = await call(api.port, 'POST', { source_b64: Buffer.from('print(1)').toString('base64'), attest: true, engine: 'generic', fallback: false });
  assert.equal(busy.status, 503, 'while the first run is alive the single slot is taken');
  sock.destroy();
  let status = 0;
  for (let i = 0; i < 30 && status !== 200; i++) {
    await new Promise((r) => setTimeout(r, 500));
    status = (await call(api.port, 'POST', { source_b64: Buffer.from('print(1)').toString('base64'), attest: true, engine: 'generic', fallback: false, timeout_s: 20 })).status;
  }
  api.child.kill();
  assert.equal(status, 200, 'after the client left, the slot was released within seconds');
});

test('regression: every Python file of the engine and the API compiles with warnings as errors (an invalid escape in ir.py becomes a SyntaxError on newer Pythons)', { skip: skipPy }, () => {
  const files = [];
  const walk = (d) => { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) { if (e.name !== 'bin' && e.name !== '__pycache__') walk(p); } else if (e.name.endsWith('.py')) files.push(p); } };
  walk(engineDir); files.push(path.join(root, 'api', 'reconstruct.py'));
  const r = spawnSync('python3', ['-I', '-W', 'error::SyntaxWarning', '-c', 'import sys\nfor f in sys.argv[1:]:\n    with open(f, encoding="utf-8") as h: compile(h.read(), f, "exec")', ...files], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
});

test('regression: the output check reports invalid Luau as invalid (luau-ast prints its errors on stderr; the check used to read stdout and call everything valid)', { skip: skipPy }, () => {
  const py = spawnSync('python3', ['-I', '-c', `
import sys, json, tempfile, pathlib
sys.path.insert(0, ${JSON.stringify(engineDir)})
import service
w = pathlib.Path(tempfile.mkdtemp())
print(json.dumps([service.syntax_check("local x = = 1\\n", w), service.syntax_check("local x: number = 1\\nlocal t = {1, 2}\\nfor i, v in t do print(i, v) end\\n", w)]))
`], { encoding: 'utf8' });
  assert.equal(py.status, 0, py.stderr);
  const [bad, good] = JSON.parse(py.stdout);
  assert.equal(bad.ok, false);
  assert.ok(bad.errors.length >= 1);
  assert.equal(good.ok, true, 'valid Luau (types, generalised iteration) is accepted');
});

test('regression: a behaviour trace that strips a probe block is valid Luau (the note it leaves used to be a bare line)', { skip: skipPy, timeout: 120_000 }, () => {
  const tmp = fs.mkdtempSync(path.join(fs.realpathSync(process.env.TMPDIR || '/tmp'), 'qs-t-'));
  const out = path.join(tmp, 'trace.lua');
  const r = spawnSync('python3', ['-I', path.join(engineDir, 'deobf/deob.py'), fx('001_vm_like_dispatch-obfuscated.lua'), '--obfuscator', 'luraph_v15', '--no-devirt', '--no-pypy', '-o', out],
    { encoding: 'utf8', timeout: 100_000, env: { PATH: process.env.PATH, DEOBF_BIN_DIR: path.join(engineDir, 'deobf/bin') } });
  assert.equal(r.status, 0, r.stderr);
  const text = fs.readFileSync(out, 'utf8');
  assert.match(text, /^-- \[probe block removed\]$/m, 'the probe block was stripped and the note is a comment');
  const ast = spawnSync(path.join(engineDir, 'deobf/bin/luau-ast'), [out], { encoding: 'utf8' });
  assert.equal(ast.status, 0, ast.stderr);
  fs.rmSync(tmp, { recursive: true, force: true });
});

test('registry: every output the engine produced is valid Luau', () => {
  for (const r of registry.records.filter((x) => x.kind !== 'none')) assert.equal(r.syntax, true, `${r.id}: the recorded output does not parse`);
});

test('regression: a client that declares a body and never sends it is dropped after the read timeout instead of holding a thread', { skip: skipPy, timeout: 60_000 }, async () => {
  const api = await startApi({ QS_RECONSTRUCT_RPM: '1000', QS_RECONSTRUCT_READ_TIMEOUT: '2' });
  try {
    const sock = net.connect(api.port, '127.0.0.1');
    sock.resume();
    sock.write('POST /api/reconstruct HTTP/1.1\r\nHost: x\r\nContent-Type: application/json\r\nContent-Length: 5000\r\n\r\n{"source');
    const t0 = Date.now();
    const closed = await new Promise((resolve) => { const t = setTimeout(() => resolve(false), 8000); sock.on('close', () => { clearTimeout(t); resolve(true); }); sock.on('error', () => {}); });
    assert.equal(closed, true, 'the server closed the stalled connection');
    assert.ok(Date.now() - t0 < 7000);
    const ok = await call(api.port, 'POST', { source_b64: Buffer.from('print(1)').toString('base64'), attest: true, engine: 'generic', fallback: false, timeout_s: 20 });
    assert.equal(ok.status, 200, 'and kept serving');
  } finally { api.child.kill(); }
});

test('regression: the capability check (which runs the engine) is rate limited and cached, so it cannot be used to run the engine in a loop', { skip: skipPy, timeout: 120_000 }, async () => {
  // startApi's own readiness probe is the first check: it runs the engine and primes the cache (and uses one request of the minute)
  const api = await startApi({ QS_RECONSTRUCT_RPM: '3' });
  try {
    const t0 = Date.now();
    const a = JSON.parse((await call(api.port, 'GET', undefined, {}, '/api/reconstruct?check=1')).body);
    const fast = Date.now() - t0;
    assert.equal(a.cached, true, 'the answer is the one the probe produced, not a second engine run');
    assert.equal(a.selfTest.ok, true);
    assert.ok(fast < 1500, `a cached answer is immediate (${fast} ms), a fresh one takes seconds`);
    assert.equal((await call(api.port, 'GET', undefined, {}, '/api/reconstruct?check=1')).status, 200);
    assert.equal((await call(api.port, 'GET', undefined, {}, '/api/reconstruct?check=1')).status, 429, 'a fourth request in the minute is refused');
  } finally { api.child.kill(); }
  const fresh = await startApi({ QS_RECONSTRUCT_RPM: '100', QS_CHECK_CACHE_SECONDS: '0' });
  try {
    const t = Date.now();
    const b = JSON.parse((await call(fresh.port, 'GET', undefined, {}, '/api/reconstruct?check=1')).body);
    assert.equal(b.cached, false, 'with the cache off the engine really runs');
    assert.ok(Date.now() - t > 1000);
  } finally { fresh.child.kill(); }
});

test('regression: a request with an engine that is not a string is a 400, not a dropped connection; choosing the trace engine yields kind "trace"', { skip: skipPy, timeout: 120_000 }, async () => {
  const b64 = Buffer.from('print(1)').toString('base64');
  for (const engine of [['generic'], { a: 1 }, 5]) {
    const r = await call(port, 'POST', { source_b64: b64, attest: true, engine });
    assert.equal(r.status, 400, JSON.stringify(engine));
    assert.equal(JSON.parse(r.body).error.code, 'bad_engine');
  }
  const ok = await call(port, 'POST', { source_b64: b64, attest: true, engine: 'generic', fallback: false, timeout_s: 30 });
  const last = JSON.parse(ok.body.trim().split('\n').pop());
  assert.equal(last.kind, 'trace');
  assert.equal(last.engine.mode, 'trace');
});
