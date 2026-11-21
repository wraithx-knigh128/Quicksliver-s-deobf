// Prompt XXVIII: one Deobfuscate. Every kind of input goes through src/pipeline/unified.js, and the result is the reconstructed program the
// input leads to — a retrieved payload reaches the same engine as a pasted script, and a run that obtained only the loader never reports more.
// The engine parts are the real ones (loader analysis, payload decoding, detection, recovery); only the network is a mock, so every
// retrieval outcome is tested without GitHub. The live check against GitHub is in docs/REPORT-XXVIII.md.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { deobfuscate, STAGES, pickEntry, programRole, unifiedMarkdown } from '../src/pipeline/unified.js';
import { analyzeLoader } from '../src/loader/analyze.js';
import { decodePayload } from '../src/loader/payload.js';
import { detect } from '../src/detect/detect.js';
import { recoverSource } from '../src/api.js';
import { parse } from '../src/core/parser.js';
import { renamePass, kindFromMembers } from '../src/passes/rename.js';
import { print } from '../src/core/printer.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const ZARTHA = fs.readFileSync(path.join(here, 'corpus/obfuscated/zartha/s07_roblox_style__constants.lua'), 'utf8');
const enc = (s) => Uint8Array.from([...s].map((c) => c.charCodeAt(0) & 255));
const RAW = 'https://raw.githubusercontent.com/alice/hub/main/';

/** A GitHub that answers like api/github.js does, from a table of files; it records every request. */
function mockGitHub(files, { listing = null, failures = {} } = {}) {
  const calls = [];
  const fn = async (url, { mode }) => {
    calls.push({ url, mode });
    for (const [needle, r] of Object.entries(failures)) if (url.includes(needle)) return { ok: false, ...r };
    if (mode === 'listing') return listing ? { ok: true, outcome: 'listing', listing } : { ok: false, outcome: 'unavailable', message: 'no listing' };
    const raw = url.replace('https://github.com/', RAW.replace('alice/hub/main/', '')).replace(/\/blob\//, '/')
      .replace(/^https:\/\/api\.github\.com\/repos\/([^/]+)\/([^/]+)\/contents\/([^?]+)\?ref=(.+)$/, 'https://raw.githubusercontent.com/$1/$2/$4/$3');
    const body = files[raw];
    if (body == null) return { ok: false, outcome: 'file-missing', message: 'The repository exists, but that file is not in it.' };
    return { ok: true, outcome: 'retrieved', target: { owner: 'alice', repo: 'hub', path: raw.split('/main/')[1] }, file: { name: raw.split('/').pop(), bytes: enc(body), sha256: 'a'.repeat(64), contentReason: 'Lua / Luau source that parses.' } };
  };
  fn.calls = calls;
  return fn;
}

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
const stage = (R, id) => R.stages.find((s) => s.id === id);

// ---- 1, 2: a file and pasted source ---------------------------------------------------------------------------------------------------------

test('unified: a file is deobfuscated from its exact bytes; pasted source the same way — fourteen stages, one result', async () => {
  const d = deps();
  const R = await deobfuscate({ text: ZARTHA, name: 'protected.lua', bytes: enc(ZARTHA) }, d);
  assert.equal(R.stages.length, 14);
  assert.deepEqual(R.stages.map((s) => s.id), STAGES.map(([id]) => id));
  assert.equal(R.source.class, 'input');
  assert.equal(R.final.isPayload, true);
  assert.equal(R.final.name, 'protected.deobf.lua');
  assert.match(R.final.output, /local Players = game:GetService\("Players"\)/);
  assert.equal(R.verdict.outcome, 'syntax-valid-unverified');
  assert.equal(stage(R, 'retrieve').status, 'skipped');
  assert.equal(stage(R, 'deliver').status, 'done');
  assert.equal(d.recovered.length, 1);
  assert.equal(d.recovered[0], ZARTHA, 'the engine received the file itself');
  const pasted = await deobfuscate({ text: ZARTHA }, deps());
  assert.equal(pasted.final.output, R.final.output, 'pasted text gives the same result as the file');
});

// ---- 3, 4, 5: a GitHub loadstring, a raw link, an API link ---------------------------------------------------------------------------------

test('unified: a GitHub loadstring — the payload is retrieved, reaches the same engine, and the reconstructed payload is the result', async () => {
  const gh = mockGitHub({ [`${RAW}payload.lua`]: ZARTHA });
  const d = deps({ github: gh });
  const R = await deobfuscate({ text: `loadstring(game:HttpGet("${RAW}payload.lua"))()` }, d);
  assert.deepEqual(gh.calls, [{ url: `${RAW}payload.lua`, mode: 'file' }]);
  assert.equal(d.recovered.length, 1, 'only the payload is reconstructed (the one-line loader has nothing of its own)');
  assert.equal(d.recovered[0], ZARTHA, 'the retrieved payload itself went to the engine');
  assert.equal(R.final.isPayload, true);
  assert.equal(R.final.name, 'payload.deobf.lua');
  assert.match(R.final.output, /RunService\.Heartbeat:Connect/);
  assert.equal(R.source.class, 'public-source');
  assert.equal(stage(R, 'loader').status, 'done');
  assert.match(stage(R, 'retrieve').detail, /1 of 1 retrieval succeeded/);
  assert.match(stage(R, 'vm').detail, /zartha VM lifted/);
  assert.deepEqual(R.chain.map((n) => n.role), ['secondary-loader', 'obfuscated']);
});

test('unified: a raw link and an API contents link are retrieved and reconstructed directly', async () => {
  for (const url of [`${RAW}payload.lua`, 'https://api.github.com/repos/alice/hub/contents/payload.lua?ref=main', 'https://github.com/alice/hub/blob/main/payload.lua']) {
    const gh = mockGitHub({ [`${RAW}payload.lua`]: ZARTHA });
    const R = await deobfuscate({ text: url }, deps({ github: gh }));
    assert.equal(gh.calls[0].mode, 'file', url);
    assert.equal(R.final && R.final.isPayload, true, url);
    assert.match(R.final.output, /local Players = game:GetService/, url);
    assert.equal(stage(R, 'loader').status, 'done', 'the retrieved file is examined for being a loader');
    assert.match(stage(R, 'address').detail, /alice\/hub/);
  }
});

// ---- 6, 7: a repository — the entry point, and the files it names ------------------------------------------------------------------------

test('unified: a repository link lists the repository, retrieves its entry point, and the dependencies it names', async () => {
  const listing = { kind: 'repo', owner: 'alice', repo: 'hub', ref: 'main', files: [{ path: 'main.lua', likelyLoader: true }, { path: 'lib/util.lua' }, { path: 'unrelated.lua' }] };
  const files = {
    [`${RAW}main.lua`]: 'local util = require("lib/util.lua")\nlocal Players = game:GetService("Players")\nprint(util.greet(Players.LocalPlayer.Name))',
    [`${RAW}lib/util.lua`]: 'local M = {}\nfunction M.greet(name) return "hi " .. name end\nreturn M',
    [`${RAW}unrelated.lua`]: 'print("never read")',
  };
  const gh = mockGitHub(files, { listing });
  const R = await deobfuscate({ text: 'https://github.com/alice/hub' }, deps({ github: gh }));
  assert.equal(gh.calls[0].mode, 'listing');
  assert.ok(gh.calls.some((c) => /main\.lua$/.test(c.url)), 'the entry point is retrieved');
  assert.ok(gh.calls.some((c) => /lib\/util\.lua$/.test(c.url)), 'the file it names is retrieved');
  assert.ok(!gh.calls.some((c) => /unrelated/.test(c.url)), 'a file nothing names is not retrieved (no indiscriminate harvesting)');
  assert.equal(R.final.name, 'main.deobf.lua');
  assert.equal(R.final.dependencies.length, 1);
  assert.equal(R.final.dependencies[0].role, 'dependency');
  assert.match(R.final.dependencies[0].output, /function M\.greet\(name\)/, 'the module keeps its author’s names');
});

test('unified: a repository without a clear entry point asks for a choice, and without one stops honestly', async () => {
  const listing = { kind: 'repo', owner: 'alice', repo: 'hub', ref: 'main', files: [{ path: 'a.lua' }, { path: 'b.lua' }] };
  const gh = mockGitHub({ [`${RAW}b.lua`]: 'print("b")' }, { listing });
  let asked = null;
  const R = await deobfuscate({ text: 'https://github.com/alice/hub' }, deps({ github: gh, choose: async (l) => { asked = l; return 'b.lua'; } }));
  assert.equal(asked.repo, 'hub');
  assert.equal(R.final.name, 'b.deobf.lua');
  const none = await deobfuscate({ text: 'https://github.com/alice/hub' }, deps({ github: mockGitHub({}, { listing }) }));
  assert.equal(none.source.class, 'needs-choice');
  assert.equal(none.final, null);
  assert.equal(pickEntry([{ path: 'src/x.lua' }, { path: 'main.lua' }]), 'main.lua');
  assert.equal(pickEntry([{ path: 'a.lua' }, { path: 'b.lua' }]), null);
});

// ---- 8: a secondary loader ------------------------------------------------------------------------------------------------------------------

test('unified: a loader that fetches another loader is followed to the payload; the loaders are kept as what they are', async () => {
  const gh = mockGitHub({ [`${RAW}stage2.lua`]: `loadstring(game:HttpGet("${RAW}payload.lua"))()`, [`${RAW}payload.lua`]: ZARTHA });
  const R = await deobfuscate({ text: `loadstring(game:HttpGet("${RAW}stage2.lua"))()` }, deps({ github: gh }));
  assert.deepEqual(R.chain.map((n) => [n.depth, n.role]), [[0, 'secondary-loader'], [1, 'secondary-loader'], [2, 'obfuscated']]);
  assert.equal(R.final.name, 'payload.deobf.lua');
  assert.ok(R.final.dependencies.some((x) => x.role === 'secondary-loader' && x.name === 'stage2.loader.lua'), 'the intermediate loader is delivered as a loader');
  // a loop of loaders ends
  const loop = mockGitHub({ [`${RAW}a.lua`]: `loadstring(game:HttpGet("${RAW}b.lua"))()`, [`${RAW}b.lua`]: `loadstring(game:HttpGet("${RAW}a.lua"))()` });
  const L = await deobfuscate({ text: `loadstring(game:HttpGet("${RAW}a.lua"))()` }, deps({ github: loop }));
  assert.equal(loop.calls.length, 2, 'each address is retrieved once');
  assert.equal(L.final === null || L.final.isPayload === false, true);
  assert.notEqual(L.verdict.outcome, 'syntax-valid-unverified');
});

// ---- 9, 10, 16: missing, private, authorisation, licence --------------------------------------------------------------------------------

test('unified: missing, deleted, private and unauthorised sources are each said as such, and nothing is delivered in their place', async () => {
  const cases = [
    [{ outcome: 'file-missing', message: 'gone' }, 'missing', 'payload-unavailable'],
    [{ outcome: 'owner-not-found', message: 'no such account' }, 'missing', 'payload-unavailable'],
    [{ outcome: 'private-or-missing', message: 'private or deleted' }, 'private-or-missing', 'payload-unavailable'],
    [{ outcome: 'token-rejected', message: 'bad token' }, 'auth-required', 'authorization-unavailable'],
    [{ outcome: 'licence', message: 'A Premium licence is required for GitHub retrieval.' }, 'auth-required', 'authorization-unavailable'],
    [{ outcome: 'rate-limited', message: 'later', retryAfter: 120 }, 'unavailable', 'payload-unavailable'],
    [{ outcome: 'not-lua', message: 'an HTML page' }, 'not-code', 'payload-unavailable'],
  ];
  for (const [failure, cls, verdict] of cases) {
    const R = await deobfuscate({ text: 'https://github.com/alice/hub/blob/main/x.lua' }, deps({ github: mockGitHub({}, { failures: { 'x.lua': failure } }) }));
    assert.equal(R.source.class, cls, failure.outcome);
    assert.equal(R.verdict.outcome, verdict, failure.outcome);
    assert.equal(R.final, null, `${failure.outcome}: nothing delivered`);
    assert.equal(stage(R, 'retrieve').status, 'failed');
    assert.equal(stage(R, 'deliver').status, 'failed');
    if (failure.retryAfter) assert.equal(R.source.retryAfter, 120);
  }
});

test('unified: a loader whose payload is missing is never reported as a successful fetch, and its own code is labelled as the loader', async () => {
  const gh = mockGitHub({ [`${RAW}loader.lua`]: `loadstring(game:HttpGet("${RAW}gone.lua"))()` });
  const R = await deobfuscate({ text: `${RAW}loader.lua` }, deps({ github: gh }));
  assert.equal(R.verdict.outcome, 'payload-unavailable');
  assert.equal(R.source.class, 'missing');
  assert.ok(!R.final || R.final.isPayload === false);
  assert.match(stage(R, 'deliver').detail, /payload was not obtained/);
  for (const id of ['vm', 'generate', 'validate']) assert.equal(stage(R, id).status, 'skipped');
});

test('unified: a protected service (Luarmor) is reported as protected and is never requested', async () => {
  const gh = mockGitHub({});
  const fetchLink = async () => { throw new Error('must not be called'); };
  const R = await deobfuscate({ text: 'loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/abcdef.lua"))()' }, deps({ github: gh, fetchLink }));
  assert.equal(gh.calls.length, 0);
  assert.equal(R.source.class, 'protected-payload');
  assert.equal(R.verdict.outcome, 'payload-unavailable');
  assert.equal(R.final, null);
});

// ---- 11–15: VM reconstruction, placeholder parameters, incomplete functions, syntax, behaviour ------------------------------------------

test('unified: VM reconstruction is reported from the engine’s own evidence', async () => {
  const R = await deobfuscate({ text: ZARTHA }, deps());
  assert.equal(stage(R, 'vm').status, 'done');
  assert.match(stage(R, 'vm').detail, /zartha VM lifted: 3 functions, 83 instructions/);
  assert.match(stage(R, 'strings').detail, /change/);
  assert.match(stage(R, 'detect').detail, /Zartha/);
});

test('unified: placeholder parameters, empty bodies, missing constants and unresolved instructions are warnings, never hidden', async () => {
  const fake = (evidence) => async (t) => ({ ...recoverSource(t, {}), outcome: { outcome: 'partial', label: 'Partially reconstructed', reasons: ['3 places left unresolved.'], met: [], evidence }, vm: { kind: 'test', lifted: true, stats: { functions: 2, instructions: 10 } } });
  const ev = { input: { kind: 'lua', parses: true }, obfuscated: true, recovery: { parses: true, unresolved: 3, residual: ['vm-dispatch'], bodies: { total: 4, empty: 2, missingConstants: 1 }, naming: { locals: 6, placeholders: 4, params: 3, placeholderParams: 2 } } };
  const R = await deobfuscate({ text: 'local x = 1 print(x)' }, deps({ recover: fake(ev), detect: () => ({ families: [{ id: 'x', name: 'TestVM', confidence: 0.9 }], traits: [] }) }));
  assert.equal(stage(R, 'vm').status, 'warn');
  assert.match(stage(R, 'vm').detail, /3 places left unresolved/);
  assert.equal(stage(R, 'functions').status, 'warn');
  assert.match(stage(R, 'functions').detail, /2 function bodies empty/);
  assert.match(stage(R, 'functions').detail, /2 parameters still have a placeholder name/);
  assert.equal(stage(R, 'strings').status, 'warn');
  assert.match(stage(R, 'strings').detail, /1 constant missing/);
  assert.match(stage(R, 'validate').detail, /protection left in it: vm-dispatch/);
});

test('unified: an input that does not parse is invalid input; nothing is generated for it', async () => {
  const R = await deobfuscate({ text: 'local x = = 1' }, deps());
  assert.equal(R.verdict.outcome, 'invalid-input');
  assert.equal(R.final, null);
  const empty = await deobfuscate({ text: '  \n ' }, deps());
  assert.equal(empty.verdict.outcome, 'invalid-input');
  assert.equal(stage(empty, 'recognize').status, 'failed');
});

test('unified: behaviour is compared only when asked, and a comparison decides the class', async () => {
  const plain = 'local t = {}\nfor i = 1, 3 do t[#t + 1] = i * 2 end\nprint(table.concat(t, ","))';
  const without = await deobfuscate({ text: plain }, deps());
  assert.match(stage(without, 'validate').detail, /behaviour not compared/);
  let called = 0;
  const verify = async () => { called++; return { verdict: 'identical', coverage: { ratio: 1 } }; };
  const withCheck = await deobfuscate({ text: plain }, deps({ verify }));
  assert.equal(called, 1);
  assert.match(stage(withCheck, 'validate').detail, /behaviour vs the input: identical/);
  const differs = await deobfuscate({ text: plain }, deps({ verify: async () => ({ verdict: 'different', difference: { original: 'a', recovered: 'b' } }) }));
  assert.notEqual(differs.verdict.outcome, 'validated');
});

// ---- content roles and the report ----------------------------------------------------------------------------------------------------------

test('unified: retrieved content is classed as configuration, dependency or plain source by its shape', () => {
  assert.equal(programRole('return { speed = 16, name = "x", list = { 1, 2 } }'), 'config');
  assert.equal(programRole('local M = {}\nfunction M.add(a, b) return a + b end\nreturn M'), 'dependency');
  assert.equal(programRole('return { run = function() print(1) end }'), 'dependency');
  assert.equal(programRole('print("hello")'), 'plain');
  assert.equal(programRole('local = ='), 'invalid');
});

test('unified: the Markdown report states the result, the source and every stage', async () => {
  const R = await deobfuscate({ text: ZARTHA, name: 'x.lua' }, deps());
  const md = unifiedMarkdown(R, { name: 'x.lua' });
  assert.match(md, /\*\*Result:\*\* Syntax-valid but behaviourally unverified/);
  assert.match(md, /\| 9 \| VM & bytecode reconstruction \| done \|/);
  assert.equal((md.match(/^\| \d+ \|/gm) || []).length, 14);
});

// ---- reconstruction repairs found while building the pipeline (Prompt XXVIII) -----------------------------------------------------------

test('names: plain source keeps its author’s names — short names alone are not a minifier’s', () => {
  const out = (code) => { const ast = parse(code); renamePass(ast, {}); return print(ast); };
  assert.match(out('local M = {}\nfunction M.add(a, b) return a + b end\nreturn M'), /local M = \{\}\n\nfunction M\.add\(a, b\)/);
  // a minified program (many one-letter names) is still renamed wholesale
  const mini = Array.from({ length: 14 }, (_, i) => `local ${String.fromCharCode(97 + i)}=${i}`).join(' ') + ' print(a+b+c+d+e+f+g+h+i+j+k+l+m+n)';
  assert.doesNotMatch(out(mini), /^local a = 0/m);
});

test('names: three GetService results are named after the services, not service, service1, service2 (site pipeline)', () => {
  const r = recoverSource(ZARTHA, { nexus: true });
  assert.match(r.output, /local Players = game:GetService\("Players"\)/);
  assert.match(r.output, /local RunService = game:GetService\("RunService"\)/);
  assert.match(r.output, /local ReplicatedStorage = game:GetService\("ReplicatedStorage"\)/);
  assert.match(r.output, /local localPlayer = Players\.LocalPlayer/);
  const code = r.output.split('\n').filter((l) => !l.startsWith('--')).join('\n');
  assert.doesNotMatch(code, /\bservice\d*\b/);
});

test('unified: a retrieved file that is Lua but does not parse is "retrieved, not reconstructed" — not "not code", and nothing is generated', async () => {
  const gh = mockGitHub({ [`${RAW}broken.lua`]: 'local function f()\n  print("x")\nend\nend\nlocal t = { 1, 2' });
  const R = await deobfuscate({ text: `${RAW}broken.lua` }, deps({ github: gh }));
  assert.equal(R.source.class, 'retrieved-unreconstructable');
  assert.equal(R.verdict.outcome, 'invalid-input');
  assert.equal(R.final, null);
  assert.equal(stage(R, 'retrieve').status, 'done', 'the retrieval itself succeeded');
  assert.equal(stage(R, 'payload').status, 'failed');
});

test('names: what the program uses a value for names it — one kind of object only, one value only, never the Enum table', () => {
  const out = (code) => { const ast = parse(code); renamePass(ast, { mode: 'all' }); return print(ast); };
  const a = out('local function f(a1, a2) if a1.UserId > 0 then a1:Kick("x") end a2.WalkSpeed = 16 end\nlocal function g(a1) a1.Name = "x" end\nlocal function k(a1) print(a1.KeyCode, a1.Character) end');
  assert.match(a, /function fn\(player, humanoid\)/, 'UserId and Kick belong to a Player; WalkSpeed to a Humanoid');
  assert.doesNotMatch(a, /function fn1\((player|part|input)\)/, 'Name is shared by every object: no name');
  assert.doesNotMatch(a, /function fn2\((player|input)\)/, 'members of two kinds on one value: no name');
  const e = out('local a3 = Enum\nprint(a3.KeyCode.E)\nlocal function k(a4) return a4.KeyCode == Enum.KeyCode.E end');
  assert.match(e, /local value = Enum/, 'the Enum table read as x.KeyCode.E is not an input');
  assert.match(e, /function fn\(input\)/);
  const reused = out('local r1\nr1 = ipairs\nr1 = workspace.Remote\nr1:FireServer(1)');
  assert.doesNotMatch(reused, /\bremote\b/, 'a register that holds several values is not named after one of them');
  assert.equal(kindFromMembers(['FireServer', 'OnClientEvent']), 'remote');
  assert.equal(kindFromMembers(['Name', 'Parent']), null);
});
