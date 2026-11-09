// Capabilities: what the engine can do for a named system, each with a verifier that was run and whose result is stored.
//
//   node tools/research/capabilities.mjs        writes data/research/capabilities.json
//
// A capability is `enabled` only if its verifier passed in this run. identify.js reads the file and uses nothing that is not enabled, so a capability
// cannot be switched on by editing a list: it has to pass its checks, and the checks are in this file where a reviewer can read them.
// What a verifier proves is stated in `proves`, and what it does not in `doesNotProve`; the second matters more than the first.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { identify } from '../../src/research/identify.js';
import { validateProfile, supportClaim } from '../../src/research/profiles.js';
import { differential } from './differential.mjs';
import { oracle, stopOracle } from '../runtime/oracle.mjs';
import { recover } from '../../src/recover/pipeline.js';
import { bytesToBinary } from '../../src/core/bytes.js';
import { detect } from '../../src/detect/detect.js';
import { recoverSource } from '../../src/api.js';
import { observe } from '../../src/research/signature.js';
import { registryFromData } from '../../src/research/families.js';
import { TRANSFORMS } from '../lab/transforms.mjs';
import { generateProgram } from '../lab/generate.mjs';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const profilesFile = path.join(root, 'data', 'research', 'profiles.json');

const sha = (s) => crypto.createHash('sha256').update(s).digest('hex');
const banner = (v) => `-- This file was protected using Luraph Obfuscator v${v} [https://lura.ph/]\nreturn 1`;

function luraphProfile(profiles) { return profiles.profiles.find((p) => p.id === 'luraph'); }
const check = (name, ok, detail) => ({ name, ok: !!ok, ...(detail === undefined ? {} : { detail }) });

const VERIFIERS = [
  {
    id: 'luraph.banner-version', system: 'luraph', level: 'format-tested',
    claim: 'Reads the version a Luraph banner comment names and maps it to a profiled generation.',
    proves: 'The banner text is parsed as written, versions are mapped to the generation whose period they fall in, versions outside the profile are not mapped, and the result is capped at 0.7 confidence with a caveat.',
    doesNotProve: 'That the banner is true. A banner is a comment: anyone can add, edit or remove one. Nothing is claimed about reconstruction.',
    async run({ profiles }) {
      const cases = [['13.6.0', 'v13-era'], ['14.3', 'v14'], ['14.4.1', 'v14'], ['15.0', 'v15'], ['15.1.2', 'v15.1'], ['16.0', null], ['12.9', null]];
      const out = cases.map(([v, gen]) => {
        const r = identify(banner(v), { profiles });
        const s = r.systems.find((x) => x.id === 'luraph');
        return check(`banner v${v} -> ${gen || 'no generation'}`, s && s.version && s.version.generation === gen && s.version.confidence <= 0.7 && s.version.caveats.length > 0);
      });
      out.push(check('no banner -> no Luraph claim', !identify('print(1)', { profiles }).systems.some((x) => x.id === 'luraph')));
      out.push(check('a forged banner is reported as claimed, not as established', identify(banner('15.1.0') + '\nprint("not luraph")', { profiles }).systems.find((x) => x.id === 'luraph').version.basis === 'banner'));
      return { checks: out, inputsHash: sha(cases.join('|')) };
    },
  },
  {
    id: 'luraph.macro-generation', system: 'luraph', level: 'vendor-data-tested',
    claim: 'Narrows the Luraph generation a source script was written for from the macros it uses.',
    proves: 'For every generation, the macros the vendor SDK defines for it give a candidate set that includes it; macros introduced later narrow the set; a macro no generation defines gives none.',
    doesNotProve: 'That a script using those macros has been, or will be, protected by that generation, or that the service rejects macros the SDK omits. It applies to unprotected source scripts only: protected output no longer contains macros. Nothing is claimed about reconstruction.',
    async run({ profiles }) {
      const lu = luraphProfile(profiles);
      const out = [];
      for (const v of lu.versions) {
        const src = v.macros.all.map((m) => `local _ = ${m}`).join('\n');
        const r = identify(src, { profiles }).systems.find((x) => x.id === 'luraph-source');
        out.push(check(`${v.id}: its own ${v.macros.all.length} macros include ${v.id} among the candidates`, r && r.version.candidates.includes(v.id)));
      }
      const v151 = lu.versions.find((v) => v.id === 'v15.1');
      const v15 = lu.versions.find((v) => v.id === 'v15');
      const only151 = v151.macros.all.filter((m) => !v15.macros.all.includes(m));
      out.push(check(`macros first seen in v15.1 (${only151.join(', ')}) narrow to v15.1 alone`, only151.length > 0 && identify(`local _ = ${only151[0]}`, { profiles }).systems.find((x) => x.id === 'luraph-source').version.generation === 'v15.1'));
      const unknown = identify('local _ = LPH_NOT_A_REAL_MACRO', { profiles }).systems.find((x) => x.id === 'luraph-source');
      out.push(check('a macro no generation defines gives no candidate and low confidence', unknown.version.candidates.length === 0 && unknown.version.confidence === 0));
      out.push(check('a script with no macros is not said to be Luraph', !identify('local x = 1', { profiles }).systems.some((x) => x.id === 'luraph-source')));
      return { checks: out, inputsHash: sha(JSON.stringify(lu.versions.map((v) => v.macros.all))) };
    },
  },
  {
    id: 'profiles.claim-gates', system: null, level: 'internally-tested',
    claim: 'No profile can say "supported" without real or authorised evidence.',
    proves: 'Every shipped profile validates, no commercial profile is above identification-only, and hand-made profiles that over-claim are rejected by the validator.',
    doesNotProve: 'That the evidence the gates ask for is good: it proves the gates are enforced.',
    async run({ profiles }) {
      const out = [];
      for (const p of profiles.profiles) out.push(check(`${p.id} validates`, validateProfile(p).ok, validateProfile(p).problems.slice(0, 2)));
      for (const p of profiles.profiles.filter((x) => x.kind === 'commercial')) for (const v of p.versions) out.push(check(`${p.id}@${v.id} is not "supported"`, supportClaim(p, v.id).claim !== 'supported'));
      const lu = JSON.parse(JSON.stringify(luraphProfile(profiles)));
      lu.versions[0].verification.status = 'real-output-verified';
      out.push(check('a commercial version cannot be marked real-output-verified', !validateProfile(lu).ok));
      const lu2 = JSON.parse(JSON.stringify(luraphProfile(profiles)));
      lu2.versions[0].verification.status = 'authorized-sample-verified';
      out.push(check('authorised-sample status without pairs is rejected', !validateProfile(lu2).ok));
      return { checks: out, inputsHash: sha(JSON.stringify(profiles.gates)) };
    },
  },
  {
    id: 'verify.runtime-differential', system: null, level: 'internally-tested',
    claim: 'Decides whether a reconstruction behaves like its original by running both on a reference Lua runtime.',
    proves: 'Equal programs are reported identical, a changed program is reported different (a check that cannot fail would prove nothing), and a program that prints nothing is reported inconclusive.',
    doesNotProve: 'Behaviour on inputs the program was not run with, or on Luau (not installed here).',
    async run() {
      const detected = await oracle().detect();
      const refs = detected.filter((r) => r.available && (r.id === 'lua51' || r.id === 'luajit')).map((r) => r.id);
      if (!refs.length) return { skipped: 'no reference runtime installed (run tools/runtime/setup.sh)', checks: [], inputsHash: null };
      const prog = 'local t = {} for i = 1, 5 do t[#t + 1] = i * i end print(table.concat(t, ","))';
      const keep = (s) => ({ ok: true, output: s });
      const r = await differential({ pairs: [
        { id: 'same', original: prog, protected: prog + ' ' },
        { id: 'changed', original: prog, protected: prog.replace('i * i', 'i + i') },
        { id: 'silent', original: 'local x = 1', protected: 'local x = 1 ' },
      ] }, { runtimes: refs, recover: (src) => keep(src) });
      const by = Object.fromEntries(r.rows.map((x) => [x.id, x.verdict]));
      return { checks: [
        check('identical program -> runtime-identical', by.same === 'runtime-identical'),
        check('changed program -> runtime-different', by.changed === 'runtime-different'),
        check('program that prints nothing -> inconclusive', by.silent === 'inconclusive'),
      ], inputsHash: sha(prog), runtimes: refs };
    },
  },
];

// Open-source tools: fixtures made by running the real tool (tests/corpus). Each verifier re-runs a spread sample of them through the engine and
// decides behaviour on the reference runtimes, so a capability here is a fresh measurement on this machine, not a copy of an earlier one.
const FIXTURE_DIRS = { prometheus: 'obfuscated/prometheus', hercules: 'obfuscated/hercules', ironbrew2: 'obfuscated/ironbrew2', zenfus: 'obfuscated/zenfus', azurevm: 'obfuscated/azurevm', simple_html: 'obfuscated/simple_html', clyde: 'obfuscated/clyde', colisseum: 'obfuscated-local/colisseum', simple_lua: 'obfuscated-local/simple_lua' };
const SAMPLE = 6;

function fixturePairs(id) {
  const dir = path.join(root, 'tests', 'corpus', FIXTURE_DIRS[id]);
  const mf = path.join(dir, 'manifest.json');
  if (!fs.existsSync(mf)) return null;
  const entries = JSON.parse(fs.readFileSync(mf, 'utf8')).entries.filter((e) => e.status === 'ok' && e.behavior === 'equivalent');
  const step = Math.max(1, Math.floor(entries.length / SAMPLE));
  return entries.filter((_, i) => i % step === 0).slice(0, SAMPLE).map((e) => ({
    id: e.file,
    original: bytesToBinary(fs.readFileSync(path.join(root, 'tests', 'corpus', 'originals', e.sample))),
    protected: bytesToBinary(fs.readFileSync(path.join(dir, e.file))),
    // the runtimes the fixture was checked on when it was made: the tool's own target, not necessarily Lua 5.1
    runtimes: Object.entries(e.behaviors || {}).filter(([, v]) => v === 'equivalent').map(([k]) => k).filter((k) => ['lua51', 'lua52', 'lua53', 'lua54', 'luajit'].includes(k)),
  }));
}

function openSourceVerifiers(profiles) {
  const out = [];
  for (const p of profiles.profiles.filter((x) => x.kind === 'open-source' && FIXTURE_DIRS[x.id])) {
    out.push({
      id: `${p.id}.identify`, system: p.id, level: 'real-output-tested',
      claim: `Recognises output of ${p.name} (signature).`,
      proves: `On a spread sample of ${SAMPLE} fixtures made by the real tool, the detector names ${p.id} with confidence of at least 0.5 on at least 80%.`,
      doesNotProve: 'Recognition on output made with other settings, other versions, or after further processing.',
      async run() {
        const pairs = fixturePairs(p.id);
        if (!pairs) return { skipped: `fixtures not present in this checkout (${FIXTURE_DIRS[p.id]})`, checks: [] };
        const hit = pairs.filter((x) => detect(x.protected).families.some((f) => f.id === p.id && f.confidence >= 0.5));
        return { checks: [check(`${hit.length}/${pairs.length} fixtures recognised`, hit.length / pairs.length >= 0.8)], inputsHash: sha(pairs.map((x) => x.id).join('|')) };
      },
    });
    out.push({
      id: `${p.id}.reconstruct`, system: p.id, level: 'real-output-tested',
      claim: `Reconstructs output of ${p.name} so that it behaves like the protected script.`,
      proves: `On a spread sample of ${SAMPLE} real-tool fixtures, at least 4 are decided on a reference runtime and at least 70% of those behave identically to the original program.`,
      doesNotProve: 'Coverage of every setting or program. The full result and its interval are in the profile; this is a re-measurement of a sample.',
      async run() {
        const pairs = fixturePairs(p.id);
        if (!pairs) return { skipped: `fixtures not present in this checkout (${FIXTURE_DIRS[p.id]})`, checks: [] };
        const avail = (await oracle().detect()).filter((r) => r.available).map((r) => r.id);
        const refs = [...new Set(pairs.flatMap((x) => x.runtimes))].filter((id) => avail.includes(id));
        if (!refs.length) return { skipped: 'no reference runtime installed', checks: [] };
        for (const x of pairs) x.runtimes = x.runtimes.filter((id) => avail.includes(id));
        const r = await differential({ pairs }, { runtimes: refs, recover: (src) => recover(src, { sandbox: { enabled: true } }) });
        const { runtimeVerified: n, runtimeSuccess: ok } = r.results;
        return { checks: [check(`${n} of ${pairs.length} decided on ${refs.join('+')}`, n >= 4), check(`${ok}/${n} identical`, n > 0 && ok / n >= 0.7, r.rows.filter((x) => x.verdict !== 'runtime-identical').map((x) => `${x.id}: ${x.verdict}`))], inputsHash: sha(pairs.map((x) => x.id).join('|')), runtimes: refs };
      },
    });
  }
  return out;
}

// The laboratory's own systems (profiles of kind "lab-made"). Programs 301-306 are not among those the signatures were learned from (1-16) or
// measured on (101-116), so these are fresh trials.
function labVerifiers(profiles, families) {
  const out = [];
  const FIRST = 301;
  const N = 6;
  for (const p of profiles.profiles.filter((x) => x.kind === 'lab-made')) {
    const tid = p.id.replace(/^lab-/, '');
    const trial = () => {
      const t = TRANSFORMS.find((x) => x.id === tid);
      return Array.from({ length: N }, (_, i) => { const prog = generateProgram(FIRST + i); return { id: `${tid}#${FIRST + i}`, original: prog.source, protected: t.apply(prog.source, FIRST + i) }; });
    };
    out.push({
      id: `${p.id}.identify`, system: p.id, level: 'real-output-tested',
      claim: `Recognises output of the laboratory's ${tid} system by its learned signature.`,
      proves: `The registered signature fires on ${N} of ${N} fresh transformed programs and on none of the same programs untransformed.`,
      doesNotProve: 'Anything about third-party tools: this system was written for the laboratory.',
      async run() {
        const reg = registryFromData(families);
        const pairs = trial();
        const hit = pairs.filter((x) => observe(x.protected, { registry: reg }).tokens.includes(`custom:${p.id}`));
        const fp = pairs.filter((x) => observe(x.original, { registry: reg }).tokens.includes(`custom:${p.id}`));
        return { checks: [check(`${hit.length}/${N} transformed programs recognised`, hit.length === N), check(`${fp.length}/${N} untransformed programs recognised`, fp.length === 0)], inputsHash: sha(pairs.map((x) => x.id).join('|')) };
      },
    });
    out.push({
      id: `${p.id}.reconstruct`, system: p.id, level: 'real-output-tested',
      claim: `Reconstructs the laboratory's ${tid} system with NEXUS and the sandbox.`,
      proves: `On ${N} fresh programs, at least 5 are decided on a reference runtime and every decided one behaves identically to its original.`,
      doesNotProve: 'Anything about third-party tools, or about programs unlike the generated ones.',
      async run() {
        const refs = (await oracle().detect()).filter((r) => r.available && (r.id === 'lua51' || r.id === 'luajit')).map((r) => r.id);
        if (!refs.length) return { skipped: 'no reference runtime installed', checks: [] };
        const pairs = trial();
        const r = await differential({ pairs }, { runtimes: refs, recover: (src) => recoverSource(src, { nexus: true, sandbox: { enabled: true } }) });
        return { checks: [check(`${r.results.runtimeVerified} of ${N} decided on ${refs.join('+')}`, r.results.runtimeVerified >= 5), check(`${r.results.runtimeSuccess}/${r.results.runtimeVerified} identical`, r.results.runtimeVerified > 0 && r.results.runtimeSuccess === r.results.runtimeVerified, r.rows.filter((x) => x.verdict !== 'runtime-identical').map((x) => `${x.id}: ${x.verdict}`))], inputsHash: sha(pairs.map((x) => x.id).join('|')), runtimes: refs };
      },
    });
  }
  return out;
}

export async function buildCapabilities() {
  const profiles = JSON.parse(fs.readFileSync(profilesFile, 'utf8'));
  const caps = [];
  VERIFIERS.push(...openSourceVerifiers(profiles), ...labVerifiers(profiles, JSON.parse(fs.readFileSync(path.join(root, 'data', 'research', 'custom-families.json'), 'utf8'))));
  for (const v of VERIFIERS) {
    let res;
    try { res = await v.run({ profiles }); } catch (e) { res = { checks: [check('verifier ran without error', false, String(e.message || e))] }; }
    const passed = !res.skipped && res.checks.length > 0 && res.checks.every((c) => c.ok);
    caps.push({
      id: v.id, system: v.system, level: v.level, claim: v.claim, proves: v.proves, doesNotProve: v.doesNotProve,
      enabled: passed,
      verifier: { ran: !res.skipped, passed, skipped: res.skipped || null, inputsHash: res.inputsHash || null, runtimes: res.runtimes || null, checks: res.checks },
    });
  }
  return { schema: 1, generatedAt: new Date().toISOString(), capabilities: caps };
}

async function main() {
  const out = await buildCapabilities();
  fs.writeFileSync(path.join(root, 'data', 'research', 'capabilities.json'), JSON.stringify(out, null, 2) + '\n');
  for (const c of out.capabilities) console.log(`${c.enabled ? 'enabled ' : 'DISABLED'} ${c.id.padEnd(30)} ${c.level}  ${c.verifier.checks.filter((x) => x.ok).length}/${c.verifier.checks.length} checks${c.verifier.skipped ? ' (' + c.verifier.skipped + ')' : ''}`);
  await stopOracle();
  if (out.capabilities.some((c) => !c.enabled && !c.verifier.skipped)) process.exitCode = 1;
}
if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) main();
