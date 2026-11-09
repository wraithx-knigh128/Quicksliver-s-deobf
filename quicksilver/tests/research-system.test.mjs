// Phase V: compatibility profiles, identification, capabilities, the research pipeline's gates, sample packages, grouping of unfamiliar systems, and what
// the page is allowed to say. The common thread: nothing is "supported" because its output was recognised, and nothing is recognised beyond its evidence.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateProfile, supportClaim, GATES, STATUSES, IDENTIFICATION_CAPS } from '../src/research/profiles.js';
import { identify, generationForVersion } from '../src/research/identify.js';
import { stagesFor, pipelineReport, STAGES } from '../src/research/pipeline.js';
import { buildPackage, validatePackage, pairFiles, sha256 } from '../src/research/samples.js';
import { cluster } from '../src/research/cluster.js';
import { identifySource, detectScript } from '../src/api.js';
import { buildMarkdownReport } from '../src/app/report-md.js';
import { TRANSFORMS } from '../tools/lab/transforms.mjs';
import { generateProgram } from '../tools/lab/generate.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.join(here, '..', 'data', 'research');
const readJson = (f) => JSON.parse(fs.readFileSync(path.join(dataDir, f), 'utf8'));
const profiles = readJson('profiles.json');
const capabilities = readJson('capabilities.json').capabilities;
const clone = (x) => JSON.parse(JSON.stringify(x));
const luraph = profiles.profiles.find((p) => p.id === 'luraph');
const banner = (v) => `-- This file was protected using Luraph Obfuscator v${v} [https://lura.ph/]\nreturn 1`;

// ---- profiles and their gates ---------------------------------------------------------------------------------------------------------------
test('profiles: every shipped profile validates, and none of them says more than its evidence', () => {
  assert.ok(profiles.profiles.length >= 20);
  for (const p of profiles.profiles) { const v = validateProfile(p); assert.ok(v.ok, `${p.id}: ${v.problems.join('; ')}`); }
});

test('profiles: a commercial system can never be "real-output-verified", and "supported" needs evidence the gate names', () => {
  for (const p of profiles.profiles.filter((x) => x.kind === 'commercial')) {
    for (const v of p.versions) {
      assert.ok(STATUSES.indexOf(v.verification.status) < STATUSES.indexOf('real-output-verified'), `${p.id}@${v.id}`);
      assert.notEqual(supportClaim(p, v.id).claim, 'supported');
    }
  }
  const forged = clone(luraph);
  forged.versions[0].verification.status = 'real-output-verified';
  forged.versions[0].results = { fixtures: 100, behaviourChecked: 100, behaviourSame: 100, runtime: { source: 'reference' } };
  assert.equal(validateProfile(forged).ok, false, 'numbers cannot turn a commercial system into one the lab ran');
  const forged2 = clone(luraph);
  forged2.versions[0].verification.status = 'authorized-sample-verified';
  forged2.versions[0].results = { runtimeVerified: 50, runtimeSuccess: 50, runtime: { source: 'reference' } };
  assert.equal(validateProfile(forged2).ok, false, 'authorised-sample status needs the authorised pairs themselves');
});

test('profiles: authorised samples can lift a commercial version, but only past every gate, and the claim follows the interval, not the count', () => {
  const p = clone(luraph);
  const v = p.versions[1];
  v.samples = { ...v.samples, authorizedPairs: GATES.authorized.minPairs };
  v.verification = { status: 'authorized-sample-verified', basis: 'test' };
  v.capabilities.recover = { available: true, verified: 'authorized-sample-tested' };
  v.results = { pairs: 8, runtimeVerified: 8, runtimeSuccess: 8, runtime: { source: 'reference' } };
  assert.ok(validateProfile(p).ok, validateProfile(p).problems.join('; '));
  assert.equal(supportClaim(p, v.id).claim, 'partial', 'eight of eight is the minimum to be verified at all, and its 95% lower bound (about 0.68) is still under the 0.7 that "supported" needs');
  v.samples.authorizedPairs = 12;
  v.results = { pairs: 12, runtimeVerified: 12, runtimeSuccess: 12, runtime: { source: 'reference' } };
  assert.equal(supportClaim(p, v.id).claim, 'supported', 'twelve of twelve clears it');
  v.results.runtimeSuccess = 8;
  assert.equal(supportClaim(p, v.id).claim, 'partial', '8 of 12 has a lower bound too low for "supported"');
  v.results.runtimeSuccess = 1;
  assert.equal(supportClaim(p, v.id).claim, 'identification-only');
  v.results = { ...v.results, runtime: { source: 'sandbox' } };
  assert.equal(validateProfile(p).ok, false, 'behaviour decided by the in-house interpreter does not count');
  v.results = { pairs: 7, runtimeVerified: 7, runtimeSuccess: 7, runtime: { source: 'reference' } };
  v.samples.authorizedPairs = 7;
  assert.equal(validateProfile(p).ok, false, 'seven pairs are not enough');
});

test('profiles: identification confidence is capped by the kind of evidence, and unsourced facts are refused', () => {
  const p = clone(luraph);
  p.versions[0].identification.methods[0].confidence = 0.95;
  assert.equal(validateProfile(p).ok, false);
  assert.equal(IDENTIFICATION_CAPS.banner, 0.7);
  const q = clone(luraph);
  q.versions[0].characteristics.push({ text: 'Uses a 12-opcode VM', knownAs: 'documented' });
  assert.equal(validateProfile(q).ok, false, 'a documented fact names its source');
  const r = clone(luraph);
  r.versions[0].limitations = [];
  assert.equal(validateProfile(r).ok, false, 'a profile says what is not known');
});

test('profiles: Luraph has four generations taken from the vendor\'s own SDK history, and none is more than identified', () => {
  assert.deepEqual(luraph.versions.map((v) => v.id), ['v13-era', 'v14', 'v15', 'v15.1']);
  const counts = luraph.versions.map((v) => v.macros.all.length);
  assert.deepEqual(counts, [7, 11, 12, 14]);
  for (const v of luraph.versions) {
    assert.equal(v.verification.status, 'identified');
    assert.equal(v.samples.authorizedPairs, 0);
    assert.equal(v.capabilities.recover && v.capabilities.recover.available, false, 'no reconstruction is offered for Luraph');
    assert.ok(v.limitations.some((l) => /never been run|nothing is claimed/i.test(l)), v.id);
  }
  assert.ok(luraph.versions[2].macros.removed.includes('LPH_NO_VIRTUALIZE'), 'v15 dropped macros the earlier generations had');
});

test('profiles: open-source systems with real tool output say how many fixtures and on which runtime, and a weak result is not called supported', () => {
  const prom = profiles.profiles.find((p) => p.id === 'prometheus');
  assert.equal(prom.versions[0].results.runtime.source, 'reference');
  assert.ok(prom.versions[0].results.behaviourChecked >= GATES.real.minBehaviourChecked);
  assert.equal(supportClaim(prom, 'unversioned').claim, 'supported');
  const zen = profiles.profiles.find((p) => p.id === 'zenfus');
  assert.notEqual(supportClaim(zen, 'unversioned').claim, 'supported', `${zen.versions[0].results.behaviourSame}/${zen.versions[0].results.behaviourChecked} is not support`);
});

// ---- identification ---------------------------------------------------------------------------------------------------------------------------
test('identify: a banner names a version and a generation, at no more than the confidence a comment deserves, with the caveat', () => {
  for (const [v, gen] of [['13.6.0', 'v13-era'], ['14.3', 'v14'], ['14.4.1', 'v14'], ['15.0', 'v15'], ['15.1.2', 'v15.1'], ['16.0', null]]) {
    const s = identify(banner(v), { profiles }).systems.find((x) => x.id === 'luraph');
    assert.equal(s.version.generation, gen, v);
    assert.ok(s.version.confidence <= IDENTIFICATION_CAPS.banner);
    assert.ok(s.version.caveats[0].includes('controls'), 'the caveat says a banner is only a claim');
    assert.equal(s.profile ? s.profile.claim.claim : null, gen ? 'identification-only' : null);
  }
  assert.equal(generationForVersion(12, 0), null);
  assert.equal(identify('print("hello")', { profiles }).systems.some((x) => x.id === 'luraph'), false);
});

test('identify: a forged banner on harmless code is reported as a claim, and the code is not called Luraph output on structure', () => {
  const r = identify(banner('15.1.0') + '\nprint("hi")', { profiles });
  const s = r.systems.find((x) => x.id === 'luraph');
  assert.equal(s.basis, 'banner');
  assert.equal(s.version.basis, 'banner');
  assert.ok(s.confidence <= 0.7);
});

test('identify: the macro set of an unprotected script narrows the generation, and says it is a script prepared for Luraph, not Luraph output', () => {
  const v151only = luraph.versions[3].macros.all.filter((m) => !luraph.versions[2].macros.all.includes(m));
  const r = identify(`local x = ${v151only[0]}(1)`, { profiles }).systems.find((x) => x.id === 'luraph-source');
  assert.equal(r.version.generation, 'v15.1');
  assert.match(r.name, /not protected/);
  assert.ok(r.confidence <= IDENTIFICATION_CAPS['macro-set']);
  const shared = identify('local a = LPH_JIT(1)', { profiles }).systems.find((x) => x.id === 'luraph-source');
  assert.deepEqual(shared.version.candidates, ['v13-era', 'v14']);
  assert.equal(shared.version.generation, null, 'two generations fit, so none is named');
  const unknown = identify('local a = LPH_MADE_UP(1)', { profiles }).systems.find((x) => x.id === 'luraph-source');
  assert.equal(unknown.version.confidence, 0);
});

test('identify: a capability that is not enabled is not used', () => {
  const off = capabilities.map((c) => (c.id === 'luraph.banner-version' ? { ...c, enabled: false } : c));
  assert.equal(identify(banner('14.3'), { profiles, capabilities: off }).systems.some((x) => x.id === 'luraph'), false);
  assert.ok(identify(banner('14.3'), { profiles, capabilities }).systems.some((x) => x.id === 'luraph'));
});

test('identify: the detector\'s families come with what the profile allows to be claimed', () => {
  const c = TRANSFORMS.find((t) => t.id === 'xorpack');
  const src = c.apply(generateProgram(2).source, 2);
  const det = detectScript(src).detection;
  const r = identify(src, { detection: det, profiles, capabilities });
  assert.ok(Array.isArray(r.systems));
  const viaApi = identifySource(src, { profiles, capabilities });
  assert.equal(viaApi.ok, true);
  assert.equal(identifySource(src, {}).ok, false, 'without profiles it says so instead of guessing');
});

// ---- capabilities ----------------------------------------------------------------------------------------------------------------------------
test('capabilities: each enabled capability carries the checks that passed, what it proves and what it does not', () => {
  assert.ok(capabilities.length >= 4);
  for (const c of capabilities) {
    assert.ok(c.proves && c.doesNotProve && c.level, c.id);
    if (c.enabled) {
      assert.equal(c.verifier.ran, true, c.id);
      assert.ok(c.verifier.checks.length > 0 && c.verifier.checks.every((x) => x.ok), `${c.id} is enabled but a check failed`);
    }
  }
  const ids = new Set(capabilities.filter((c) => c.enabled).map((c) => c.id));
  assert.ok(ids.has('luraph.banner-version') && ids.has('luraph.macro-generation'));
  assert.ok(![...ids].some((id) => /^luraph\.(reconstruct|recover)/.test(id)), 'no Luraph reconstruction capability exists');
  for (const c of capabilities.filter((x) => /\.reconstruct$/.test(x.id))) assert.equal(c.level, 'real-output-tested', 'open-source tools only');
});

test('capabilities: one that could not be verified here is disabled with the reason, not enabled by default', () => {
  const skipped = capabilities.filter((c) => c.verifier.skipped);
  for (const c of skipped) { assert.equal(c.enabled, false); assert.match(c.verifier.skipped, /fixtures not present|no reference runtime/); }
});

// ---- the pipeline ----------------------------------------------------------------------------------------------------------------------------
test('pipeline: stages are reached in order, and Luraph stops after classification because nothing was ever run through the engine', () => {
  const r = stagesFor(luraph, 'v14', capabilities);
  assert.deepEqual(r.stages.map((s) => s.stage), STAGES);
  assert.equal(r.reached, 'classification');
  const exp = r.stages.find((s) => s.stage === 'experimental-analysis');
  assert.equal(exp.reached, false);
  assert.match(exp.missing[0], /no output of this version/);
  assert.equal(r.stages.find((s) => s.stage === 'verification').reached, false);
  assert.equal(r.stages.find((s) => s.stage === 'integration').reached, false, 'a later stage is never reached over an unreached one');
  assert.equal(r.integration.identify, true, 'recognition is wired to the page');
  assert.equal(r.integration.reconstruct, false, 'reconstruction is not');
});

test('pipeline: a finding becomes a capability only through the gates (a profile that skips one is refused, a verified one passes)', () => {
  const p = clone(luraph);
  const v = p.versions[1];
  // claims verification without having run anything
  v.verification.status = 'authorized-sample-verified';
  const bad = stagesFor(p, v.id, capabilities);
  assert.equal(bad.stages.find((s) => s.stage === 'compatibility-profile').reached, false);
  assert.equal(bad.stages.find((s) => s.stage === 'verification').reached, false);
  assert.equal(bad.integration.reconstruct, false);
  // with the evidence and an enabled reconstruction capability
  const good = clone(luraph);
  const w = good.versions[1];
  w.samples = { ...w.samples, authorizedPairs: 8 };
  w.verification = { status: 'authorized-sample-verified', basis: 'test' };
  w.capabilities.recover = { available: true, verified: 'authorized-sample-tested' };
  w.results = { pairs: 8, runtimeVerified: 8, runtimeSuccess: 8, runtime: { source: 'reference' } };
  const caps = [...capabilities, { id: 'luraph.reconstruct', system: 'luraph', enabled: true }];
  const ok = stagesFor(good, w.id, caps);
  assert.equal(ok.reached, 'integration');
  assert.equal(ok.integration.reconstruct, true);
  assert.equal(stagesFor(good, w.id, capabilities).integration.reconstruct, false, 'without the capability the claim is not wired');
});

test('pipeline: open-source tools with real output reach verification; the report covers every version and the shipped file matches it', () => {
  const rep = pipelineReport(profiles, capabilities);
  assert.equal(rep.length, profiles.profiles.reduce((n, p) => n + p.versions.length, 0));
  const h = rep.find((r) => r.system === 'hercules');
  assert.ok(['verification', 'compatibility-profile', 'integration'].includes(h.reached), h.reached);
  const shipped = readJson('pipeline.json');
  assert.deepEqual(shipped.report.map((r) => `${r.system}@${r.version}:${r.reached}`), rep.map((r) => `${r.system}@${r.version}:${r.reached}`), 'data/research/pipeline.json is current (node tools/research/pipeline.mjs --write)');
});

// ---- sample packages -------------------------------------------------------------------------------------------------------------------------
test('samples: a package needs an attestation, distinct pairs and files that differ; its hashes catch tampering', async () => {
  const pair = { id: 'a', original: 'print(1)', protected: 'local f=function() print(1) end f()' };
  const base = { system: 'my-tool', supplier: 'me', attestation: 'I wrote the originals and ran the protector myself.', pairs: [pair] };
  const ok = await buildPackage(base);
  assert.equal(ok.ok, true);
  assert.equal((await validatePackage(ok.package)).ok, true);
  for (const bad of [{ ...base, attestation: '' }, { ...base, attestation: 'ok' }, { ...base, system: '' }, { ...base, pairs: [] }, { ...base, pairs: [pair, pair] }, { ...base, pairs: [{ id: 'z', original: 'x', protected: 'x' }] }]) {
    assert.equal((await buildPackage(bad)).ok, false);
  }
  const tampered = clone(ok.package);
  tampered.pairs[0].protected += ' ';
  assert.equal((await validatePackage(tampered)).ok, false);
  assert.equal(await sha256('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
});

test('samples: files are paired by name and anything unpaired is reported', () => {
  const f = (name) => ({ name, text: name });
  const r = pairFiles([f('a.original.lua'), f('a.protected.lua'), f('b.orig.lua'), f('b.obf.lua'), f('c.original.lua'), f('notes.txt')]);
  assert.deepEqual(r.pairs.map((p) => p.id).sort(), ['a', 'b']);
  assert.deepEqual(r.unpaired.sort(), ['c.original.lua', 'notes.txt']);
});

// ---- grouping unfamiliar systems --------------------------------------------------------------------------------------------------------------
function samplesOf(ids, n = 5) {
  const out = [];
  for (const id of ids) {
    const t = TRANSFORMS.find((x) => x.id === id);
    for (let i = 1; i <= n; i++) out.push({ id: `${id}#${i}`, source: t.apply(generateProgram(i).source, i) });
  }
  return out;
}
const family = (m) => m.split('#')[0];

test('cluster: unlabelled output of different systems falls into groups that each hold one system', () => {
  const ids = ['confetti', 'rename', 'xorpack', 'loadwrap', 'tabledispatch', 'strings-indexed'];
  const r = cluster(samplesOf(ids));
  assert.ok(r.groups.length >= ids.length);
  for (const g of r.groups) assert.equal(new Set(g.members.map(family)).size, 1, `mixed group: ${g.members.join(', ')}`);
  const grouped = r.groups.reduce((n, g) => n + g.members.length, 0);
  assert.ok(grouped / (ids.length * 5) >= 0.7, `${grouped} of ${ids.length * 5} grouped`);
  for (const g of r.groups) assert.ok(g.cohesion >= 0.8);
  assert.match(r.notes[0], /does not say which tool/);
});

test('cluster: what the vocabulary cannot tell apart is merged, and the notes say so (the three flattening styles share one surface)', () => {
  const r = cluster(samplesOf(['flatten-chain', 'flatten-tree', 'flatten-seq', 'confetti']));
  const flat = r.groups.filter((g) => g.members.some((m) => family(m).startsWith('flatten')));
  assert.ok(flat.some((g) => new Set(g.members.map(family)).size > 1), 'styles of one technique end up together');
  assert.ok(!r.groups.some((g) => g.members.some((m) => family(m) === 'confetti') && g.members.some((m) => family(m).startsWith('flatten'))), 'but they are not merged with something built differently');
});

// ---- what the page says ----------------------------------------------------------------------------------------------------------------------
test('report: the identification section states the claim, the version basis, the caveats and the limits', () => {
  const ident = identify(banner('14.4.1'), { profiles, capabilities });
  const md = buildMarkdownReport({ name: 'x.lua', identification: ident, engine: '1.0.0' });
  assert.match(md, /## System and version/);
  assert.match(md, /Luraph/);
  assert.match(md, /v14\.4\.1 claimed/);
  assert.match(md, /\*\*identification-only\*\*/);
  assert.match(md, /controls/);
  assert.match(md, /Recognising a system is not reconstructing it/);
  assert.doesNotMatch(md, /\*\*supported\*\*/);
});

// ---- authorised samples flowing into a profile -------------------------------------------------------------------------------------------------
import os from 'node:os';
import { buildProfiles } from '../tools/research/profiles-build.mjs';
import { differential } from '../tools/research/differential.mjs';
import { oracle, stopOracle } from '../tools/runtime/oracle.mjs';

function scratchData() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'qs-prof-'));
  fs.mkdirSync(path.join(dir, 'research'), { recursive: true });
  fs.copyFileSync(path.join(here, '..', 'data', 'compat.json'), path.join(dir, 'compat.json'));
  for (const f of ['records', 'histories', 'reproduction', 'sources.json', 'summary.json', 'custom-families.json']) fs.cpSync(path.join(dataDir, f), path.join(dir, 'research', f), { recursive: true });
  return dir;
}
const rowsOf = (n, ok, source = 'reference') => Array.from({ length: n }, (_, i) => ({ id: `p${i}`, verdict: i < ok ? 'runtime-identical' : 'runtime-different', runtime: { source, runtimes: ['lua51'] } }));
function record(n, ok, extra = {}) {
  const rows = extra.rows || rowsOf(n, ok);
  const decided = rows.length;
  return { schema: 1, system: 'luraph', claimedVersion: '14.3', supplier: 'test', attestation: 'Written and protected by the supplier, for this test.', at: '2026-11-09T00:00:00Z', runtimes: ['lua51'], results: { pairs: rows.length, runtimeVerified: decided, runtimeSuccess: rows.filter((r) => r.verdict === 'runtime-identical').length }, rows, ...extra };
}
function withRecords(records) {
  const dir = scratchData();
  fs.mkdirSync(path.join(dir, 'research', 'differential'));
  records.forEach((r, i) => fs.writeFileSync(path.join(dir, 'research', 'differential', `r${i}.json`), JSON.stringify(r)));
  const warnings = [];
  const orig = console.warn;
  console.warn = (m) => warnings.push(m);
  try { return { out: buildProfiles({ dir }), warnings }; } finally { console.warn = orig; fs.rmSync(dir, { recursive: true, force: true }); }
}
const v14 = (out) => out.profiles.find((p) => p.id === 'luraph').versions.find((v) => v.id === 'v14');

test('build: twelve authorised pairs decided on a reference runtime lift the matching Luraph generation, and only that one', () => {
  const { out, warnings } = withRecords([record(12, 12)]);
  assert.deepEqual(warnings, []);
  const lu = out.profiles.find((p) => p.id === 'luraph');
  assert.equal(v14(out).verification.status, 'authorized-sample-verified');
  assert.equal(lu.claims.v14.claim, 'supported');
  assert.equal(v14(out).capabilities.recover.available, true);
  for (const id of ['v13-era', 'v15', 'v15.1']) assert.equal(lu.versions.find((v) => v.id === id).verification.status, 'identified', id);
  assert.ok(validateProfile(lu).ok);
});

test('build: too few pairs are recorded as an experiment and change no status', () => {
  const { out } = withRecords([record(4, 4)]);
  assert.equal(v14(out).verification.status, 'identified');
  assert.equal(v14(out).experiments[0].pairs, 4);
  assert.equal(out.profiles.find((p) => p.id === 'luraph').claims.v14.claim, 'identification-only');
  assert.equal(v14(out).capabilities.recover.available, false);
});

test('build: a record that fails its checks is ignored with the reason (forged counts, no attestation, rows decided by the sandbox, unknown system or version)', () => {
  const forged = record(12, 12); forged.results.runtimeSuccess = 12; forged.rows[0].verdict = 'runtime-different';
  const noAtt = record(12, 12); delete noAtt.attestation;
  const sandboxed = record(12, 12, { rows: rowsOf(12, 12, 'sandbox') });
  const unknownSystem = record(12, 12, { system: 'nonesuch' });
  const unknownVersion = record(12, 12, { claimedVersion: '99.0' });
  const { out, warnings } = withRecords([forged, noAtt, sandboxed, unknownSystem, unknownVersion]);
  assert.equal(v14(out).verification.status, 'identified');
  assert.equal(warnings.length, 5, warnings.join('\n'));
  assert.match(warnings.join('\n'), /counts do not match/);
  assert.match(warnings.join('\n'), /attestation/);
  assert.match(warnings.join('\n'), /reference runtime/);
});

test('build: a low success rate is verified but not called supported', () => {
  const { out } = withRecords([record(12, 5)]);
  assert.equal(v14(out).verification.status, 'authorized-sample-verified');
  assert.notEqual(out.profiles.find((p) => p.id === 'luraph').claims.v14.claim, 'supported');
});

test('build: a record produced by the differential tool itself is accepted', { skip: (await oracle().detect()).some((r) => r.id === 'lua51' && r.available) ? false : 'needs a reference runtime' }, async () => {
  const pairs = Array.from({ length: 10 }, (_, i) => { const prog = generateProgram(500 + i).source; return { id: `s${i}`, original: prog, protected: prog + '\n-- protected\n' }; });
  const r = await differential({ pairs }, { runtimes: ['lua51'], recover: (src) => ({ ok: true, output: src }) });
  await stopOracle();
  const { out, warnings } = withRecords([{ schema: 1, system: 'luraph', claimedVersion: '14.4.1', supplier: 'test', attestation: 'Generated for this test; stands in for a supplier.', at: new Date().toISOString(), ...r }]);
  assert.deepEqual(warnings, []);
  assert.equal(v14(out).verification.status, 'authorized-sample-verified');
});
