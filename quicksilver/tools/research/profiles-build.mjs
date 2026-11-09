// Build the compatibility profiles from what is on disk. Nothing in a profile is typed in here except the *interpretation* of Luraph's SDK history
// (which commit starts which generation, and why); every other field is read from a record, a measurement or the detector.
//
//   node tools/research/profiles-build.mjs
//
// Inputs:  src/detect/families.js (what the detector knows), data/compat.json (measured on real tool output), data/research/records (sources read),
//          data/research/histories (vendor repository history), data/research/sources.json (notes with grades), data/research/reproduction.
// Output:  data/research/profiles.json, validated by src/research/profiles.js before it is written.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { FAMILIES } from '../../src/detect/families.js';
import { validateProfile, supportClaim, GATES } from '../../src/research/profiles.js';
import { generationForVersion } from '../../src/research/identify.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..', '..');
const data = path.join(root, 'data');
const read = (f, d) => (fs.existsSync(f) ? JSON.parse(fs.readFileSync(f, 'utf8')) : d);

/** Luraph's generations, each defined by the vendor SDK commit whose subject says it updates the SDK for that version. */
export const LURAPH_GENERATIONS = [
  { id: 'v13-era', label: 'Luraph before v14', from: '5da2d670be', to: '5da2d670be', basis: 'the SDK as first uploaded (2024-02-02), the last state before the commit that updates it for v14' },
  { id: 'v14', label: 'Luraph v14.x', from: 'c475541ba5', to: 'c475541ba5', basis: 'commit "update sdk for luraph v14" (2024-04-23)' },
  { id: 'v15', label: 'Luraph v15', from: 'cbb78f0c18', to: '572b3cda92', basis: 'commit "update sdk for luraph v15" (2026-08-10) through its last fix before v15.1' },
  { id: 'v15.1', label: 'Luraph v15.1', from: '52f49951cc', to: '8d9ff65c66', basis: 'commit "update sdk for luraph v15.1" (2026-10-03) and the commit after it' },
];

function luraphProfile(records, history, sources) {
  const byCommit = new Map(history.commits.map((c) => [c.commit, c]));
  const rec = (re) => records.find((r) => re.test(r.url));
  const sdkRec = rec(/macrosdk\/main\/luraphsdk\.lua/);
  const sdkReadme = rec(/macrosdk\/main\/README/);
  const sdkSrc = sdkRec ? [sdkRec.id] : [];
  const unreachable = records.filter((r) => !r.ok && /lura\.ph/.test(r.url));
  const thirdParty = records.filter((r) => r.ok && r.credibility && r.credibility.class === 'unvetted-tool-repo');
  const generations = LURAPH_GENERATIONS.map((g, i) => {
    const end = byCommit.get(g.to);
    const start = byCommit.get(g.from);
    const prev = i ? byCommit.get(LURAPH_GENERATIONS[i - 1].to) : null;
    const macros = end ? end.names : [];
    const added = prev ? macros.filter((m) => !prev.names.includes(m)) : macros;
    const removed = prev ? prev.names.filter((m) => !macros.includes(m)) : [];
    return { ...g, macros, added, removed, since: start.date, until: i + 1 < LURAPH_GENERATIONS.length ? byCommit.get(LURAPH_GENERATIONS[i + 1].from).date : null, subject: start.subject };
  });
  const histSource = `histories/luraph-macrosdk.json`;
  const noSamples = { authorizedPairs: 0, realOutput: 0, publicObserved: 0, notes: 'No output of this version has been obtained from a source the lab may use. Public pastes of protected scripts exist but belong to other people and have no originals to compare with, so none were collected.' };
  const versions = generations.map((g) => {
    const chars = [
      { text: `The vendor's SDK for this generation defines ${g.macros.length} macros: ${g.macros.join(', ')}.`, knownAs: 'documented', sources: [...sdkSrc, histSource], note: `from commit ${g.from} (${g.since})` },
    ];
    if (g.added.length && g.id !== 'v13-era') chars.push({ text: `Macros added relative to the previous generation: ${g.added.join(', ')}.`, knownAs: 'documented', sources: [histSource] });
    if (g.removed.length) chars.push({ text: `Macros no longer in the SDK relative to the previous generation: ${g.removed.join(', ')}.`, knownAs: 'documented', sources: [histSource] });
    if (g.id === 'v14') chars.push({ text: 'VM compression returned in v14, with four settings added (Optimization Level, Enable FFI Library, Hardcode Globals, Static Environment) and an enforceSettings API option.', knownAs: 'reported', sources: ['luraph-v14-docs-snippet'], note: 'from a search-result summary of the vendor\'s v14 page; the page itself could not be read from the research environment' });
    if (g.id === 'v15') chars.push({ text: 'The function-level virtualisation macros of earlier generations (ENCFUNC, NO_VIRTUALIZE, JIT, JIT_MAX, NO_UPVALUES) are gone from the SDK and a macro for pre-checking, one for rewriting, one for stack allocation and an attributes macro appear.', knownAs: 'inferred', basis: 'the SDK stubs changed this way at the v15 update; why is not stated in what was read, and the removed macros may still be accepted by the service' });
    if (g.id === 'v15') chars.push({ text: 'Third-party descriptions say v15 compiles Luau to an interpreted VM with flattened dispatch loops, encrypted memory buffers and crash traps.', knownAs: 'reported', sources: thirdParty.map((r) => r.id).slice(0, 3), note: 'low-credibility sources; only the existence of the CRASH, ENCBUF and ENCSTR macros is corroborated by the vendor SDK' });
    if (g.id === 'v15.1') chars.push({ text: 'An UNSAFE_ENVIRONMENT attribute was added to the SDK three days after the v15.1 update (2026-10-06).', knownAs: 'documented', sources: [histSource] });
    return {
      id: g.id,
      label: g.label,
      period: { since: g.since, until: g.until, basis: g.basis },
      identification: {
        methods: [
          { kind: 'banner', confidence: 0.7, note: 'a banner comment names the version, but anyone can write or remove one; it says what the file claims' },
          { kind: 'macro-set', confidence: 0.8, note: 'in an UNPROTECTED source script that uses Luraph macros, the set of macros narrows the generation it was written for; it does not apply to protected output, which no longer contains them' },
        ],
        confidence: 0.7,
      },
      macros: { all: g.macros, added: g.added, removed: g.removed },
      characteristics: chars,
      samples: noSamples,
      capabilities: {
        identify: { available: true, verified: 'format-tested', note: 'banner comment and macro-set estimates, tested against synthetic inputs built from the vendor data; never against real Luraph output' },
        versionEstimate: { available: true, verified: 'vendor-data-tested', note: 'from the banner version and from the macro set of an unprotected script' },
        trace: { available: true, verified: 'unverified', note: 'the sandbox can run a script against stand-in objects; it has not been run on Luraph output' },
        recover: { available: false, verified: 'none', note: 'a per-script VM cannot be reconstructed without samples to study, and none are available' },
      },
      results: { fixtures: 0, behaviourChecked: 0, runtime: null },
      limitations: [
        'No output of this generation has been obtained, so the engine has never been run on any; nothing is claimed about reconstruction.',
        'Version estimates from a banner depend on the file being what it says it is.',
        'The SDK lists the macros the vendor documents; the service may accept more.',
        g.id !== 'v13-era' ? null : 'The start of this generation is not dated by a vendor statement: it is the state of the SDK before the v14 update.',
      ].filter(Boolean),
      verification: { status: 'identified', basis: 'banner and macro-set identification only; no reconstruction was attempted on any sample' },
    };
  });
  return {
    id: 'luraph',
    name: 'Luraph',
    kind: 'commercial',
    summary: FAMILIES.luraph.summary,
    vendor: { site: 'https://lura.ph/', readable: !unreachable.length ? 'yes' : 'no: the site could not be reached from the research environment' },
    versions,
    research: {
      sources: records.map((r) => ({ id: r.id, url: r.url, ok: r.ok, class: r.credibility && r.credibility.class, score: r.credibility && r.credibility.score })),
      unreachable: unreachable.map((r) => r.url),
      history: histSource,
      sdkReadmeRead: !!sdkReadme,
    },
  };
}

function familyProfile(id, fam, compat, rerun) {
  const c = compat.families.find((x) => x.id === id);
  const tech = (c && c.techniques) || [];
  const sum = (f) => tech.reduce((a, t) => a + (t[f] || 0), 0);
  const fixtures = sum('samples');
  const kind = fam.kind === 'open-source' ? 'open-source' : fam.kind === 'commercial' ? 'commercial' : 'unknown';
  const real = c && c.basis === 'real-output';
  const behaviourChecked = sum('behaviourChecked');
  const results = {
    fixtures: real ? fixtures : 0, syntheticFixtures: real ? 0 : fixtures, behaviourChecked: real ? behaviourChecked : 0, behaviourSame: real ? sum('behaviourSame') : 0,
    traceChecked: sum('traceChecked'), traceIdentical: sum('traceIdentical'), toolBroken: sum('toolBroken'),
    fidelityAfter: tech.length ? Math.round((tech.reduce((a, t) => a + (t.fidelityAfter || 0) * (t.samples || 0), 0) / Math.max(1, fixtures)) * 1000) / 1000 : null,
    runtime: real || fixtures ? { source: 'reference', runtimes: compat.scorecard.behaviourOracle, measuredAt: compat.scorecard.generatedAt } : null,
    reproduction: real && rerun ? { rerunAt: rerun.rerun.generatedAt, note: 'fixtures re-measured on a fresh machine; verdict changes: ' + (rerun.verdictChanges.behavior.count) } : null,
  };
  const gateOk = kind === 'open-source' && real && results.fixtures >= GATES.real.minFixtures && results.behaviourChecked >= GATES.real.minBehaviourChecked;
  const recoverAvailable = !!c && (c.status === 'supported' || c.status === 'partial') ;
  const status = gateOk ? 'real-output-verified' : recoverAvailable ? 'internally-tested' : 'identified';
  const idMethod = fam.evidence === 'banner' ? { kind: 'banner', confidence: Math.min(0.7, fam.maxConfidence), note: 'banner comment' } : { kind: 'signature', confidence: Math.min(0.8, fam.maxConfidence), note: fam.evidence === 'source' ? 'structure matched against the tool\'s own source and its real output' : 'heuristic' };
  const hasSources = (fam.sources || []).length > 0;
  return {
    id, name: fam.name, kind, summary: fam.summary, versions: [{
      id: 'unversioned', label: 'as measured (no version split)',
      identification: { methods: [idMethod], confidence: idMethod.confidence },
      characteristics: (fam.techniques || []).map((t) => (hasSources ? { text: t, knownAs: 'documented', sources: fam.sources } : { text: t, knownAs: 'inferred', basis: 'listed by the detector without a cited source' })),
      samples: { authorizedPairs: 0, realOutput: real ? fixtures : 0, publicObserved: 0, notes: real ? 'Fixtures were made by running the real tool on programs written for this project.' : 'No real output of this tool was available.' },
      capabilities: {
        identify: { available: true, verified: real ? 'real-output-tested' : c && c.basis === 'synthetic' ? 'internally-tested' : 'format-tested' },
        trace: { available: true, verified: results.traceChecked > 0 && real ? 'real-output-tested' : 'unverified' },
        recover: recoverAvailable ? { available: true, verified: real ? 'real-output-tested' : 'internally-tested' } : { available: false, verified: 'none' },
      },
      results,
      limitations: c && c.limits && c.limits.length ? c.limits : ['No limits were recorded for this tool.'],
      verification: { status, basis: gateOk ? 'fixtures made by the real tool, behaviour decided on reference runtimes' : recoverAvailable ? 'recovery measured on examples that are not real tool output' : 'recognised from signatures; no reconstruction measured' },
    }],
  };
}

/**
 * The laboratory's own custom systems (tools/lab/transforms.mjs), as profiles of kind "lab-made". They are real output of a real tool (one we wrote), and
 * the lab runs them, so they can reach `real-output-verified`: but "supported" here counts only VERIFIED SUCCESSES (behaviour identical and the
 * reconstruction better than the input), which is stricter than "behaviour kept". They say nothing about any third-party tool.
 */
function labProfiles(summary, families) {
  if (!summary || !families) return [];
  const best = 'nexus+sandbox';
  const reference = /reference/.test(summary.interpreter || '');
  return families.families.filter((f) => f.origin === 'lab-learned').map((f) => {
    const tid = f.id.replace(/^lab-/, '');
    const t = summary.transforms.find((x) => x.id === tid);
    const c = t && summary.byTransformPlan[tid] && summary.byTransformPlan[tid][best];
    if (!c) return null;
    const conclusive = c.n - c.inconclusive;
    const results = {
      fixtures: c.n, syntheticFixtures: 0, behaviourChecked: conclusive, behaviourSame: c.success, toolBroken: 0,
      fidelityBefore: c.fidelityBefore, fidelityAfter: c.fidelityAfter,
      runtime: { source: reference ? 'reference' : 'sandbox', runtimes: summary.interpreter, measuredAt: summary.generatedAt },
      plan: best, note: 'behaviourSame counts verified successes: identical behaviour AND a reconstruction better than the input',
    };
    const gateOk = reference && results.fixtures >= GATES.real.minFixtures && results.behaviourChecked >= GATES.real.minBehaviourChecked;
    return {
      id: f.id, name: f.name, kind: 'lab-made', summary: f.summary,
      versions: [{
        id: f.versions[0].id, label: f.versions[0].label,
        identification: { methods: [{ kind: 'signature', confidence: Math.min(0.8, f.learned.heldout.precision), note: `learned from ${f.learned.trainPrograms} programs, measured on ${f.learned.heldoutPrograms} held-out programs: precision ${f.learned.heldout.precision}, recall ${f.learned.heldout.recall}` }], confidence: Math.min(0.8, f.learned.heldout.precision) },
        characteristics: [{ text: `signature: ${[...f.signature.all, ...f.signature.none.map((n) => 'not ' + n)].join(' & ')}`, knownAs: 'observed', sources: ['data/research/study.json'] }],
        samples: { authorizedPairs: 0, realOutput: c.n, publicObserved: 0, notes: 'Output of a protector written for the laboratory, applied to generated programs.' },
        capabilities: { identify: { available: true, verified: 'real-output-tested' }, trace: { available: false, verified: 'none' }, recover: { available: true, verified: 'real-output-tested' } },
        results,
        limitations: ['A system written for this laboratory: what it shows is how the engine handles that KIND of transformation, not how it handles any third-party tool.', 'Measured on generated programs only.'],
        verification: { status: gateOk ? 'real-output-verified' : 'internally-tested', basis: gateOk ? 'output of the lab\'s own tool, behaviour decided on reference runtimes' : 'the reference runtime was not used for these experiments' },
      }],
    };
  }).filter(Boolean);
}

/**
 * Differential-test records (tools/research/differential.mjs) for authorised samples. A record is accepted only if its counts agree with its rows, every
 * decided row was decided on a reference runtime, and the supplier's attestation is present. It lifts a version to authorized-sample-verified only past
 * the gates in src/research/profiles.js; below them it is recorded as an experiment on the version and changes no status.
 */
function applyDifferential(profiles, dir, warn = console.warn) {
  const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.json')) : [];
  for (const f of files) {
    const rec = read(path.join(dir, f), null);
    const bad = (m) => warn(`differential/${f}: ignored: ${m}`);
    if (!rec || rec.schema !== 1 || !Array.isArray(rec.rows)) { bad('not a differential record'); continue; }
    if (!rec.attestation) { bad('no attestation from the supplier'); continue; }
    const decided = rec.rows.filter((r) => r.verdict === 'runtime-identical' || r.verdict === 'runtime-different');
    const ok = decided.filter((r) => r.verdict === 'runtime-identical').length;
    if (rec.results.runtimeVerified !== decided.length || rec.results.runtimeSuccess !== ok || rec.results.pairs !== rec.rows.length) { bad('the counts do not match the rows'); continue; }
    if (decided.some((r) => !r.runtime || r.runtime.source !== 'reference')) { bad('a decided row was not decided on a reference runtime'); continue; }
    const p = profiles.find((x) => x.id === String(rec.system).toLowerCase());
    if (!p) { bad(`no profile named ${rec.system}`); continue; }
    let vid = null;
    if (p.id === 'luraph') { const m = /^v?(\d+)\.(\d+)/.exec(rec.claimedVersion || ''); vid = m ? generationForVersion(Number(m[1]), Number(m[2])) : null; }
    else vid = p.versions.find((v) => v.id === rec.claimedVersion || (!rec.claimedVersion && v.id === 'unversioned')) ? (rec.claimedVersion || 'unversioned') : null;
    const v = vid && p.versions.find((x) => x.id === vid);
    if (!v) { bad(`version ${rec.claimedVersion} does not map to a version of ${p.id}`); continue; }
    v.experiments = [...(v.experiments || []), { file: f, at: rec.at, supplier: rec.supplier, pairs: rec.results.pairs, runtimeVerified: rec.results.runtimeVerified, runtimeSuccess: ok, runtimes: rec.runtimes }];
    v.samples = { ...v.samples, authorizedPairs: (v.samples.authorizedPairs || 0) + rec.results.pairs };
    const runtimeVerified = (v.results.runtimeVerified || 0) + decided.length;
    const runtimeSuccess = (v.results.runtimeSuccess || 0) + ok;
    v.results = { ...v.results, pairs: (v.results.pairs || 0) + rec.results.pairs, runtimeVerified, runtimeSuccess, runtime: { source: 'reference', runtimes: rec.runtimes.join('+'), measuredAt: rec.at } };
    if (v.samples.authorizedPairs >= GATES.authorized.minPairs && runtimeVerified >= GATES.authorized.minRuntimeVerified) {
      v.verification = { status: 'authorized-sample-verified', basis: `${v.samples.authorizedPairs} authorised pairs, ${runtimeVerified} decided on a reference runtime` };
      v.capabilities.recover = { available: true, verified: 'authorized-sample-tested' };
      v.limitations = v.limitations.filter((l) => !/never been run|nothing is claimed about reconstruction/.test(l));
      v.limitations.push('Verified on the authorised samples supplied, which are not a random sample of everything the system can produce.');
    }
  }
}

// The reconstruction registry (tools/luraph/verify.mjs) is attached to the generation each of its version rows belongs to. A generation whose engine lifted a run that
// compared identical with its original gets `reconstruction.liftedIdentical`, the status `internally-tested` and an available `recover` capability; no more than that:
// the gates for "supported" (8 authorised pairs) are unchanged.
const GENERATION_ROWS = { 'v13-era': ['luraph-13'], v14: ['luraph-14-early', 'luraph-14.7', 'luraph-14.8', 'luraph-14.9', 'luraph-14-late'], v15: ['luraph-15.0'], 'v15.1': ['luraph-15.1'] };

function applyReconstruction(profiles, registry) {
  const lu = profiles.find((p) => p.id === 'luraph');
  if (!lu || !registry) return;
  for (const v of lu.versions) {
    const rows = GENERATION_ROWS[v.id] || [];
    const recs = (registry.records || []).filter((r) => rows.includes(r.versionRow));
    const summary = rows.map((id) => ({ id, status: registry.summary.versions[id] ? registry.summary.versions[id].status : 'unsupported', reasons: registry.summary.versions[id] ? registry.summary.versions[id].reasons : [] }));
    const identical = recs.filter((r) => r.kind === 'devirtualized' && r.verification && r.verification.status === 'identical').length;
    v.reconstruction = { registry: 'luraph-compat.json', rows: summary, runs: recs.length, lifted: recs.filter((r) => r.kind === 'devirtualized').length, liftedIdentical: identical, traceOnly: recs.filter((r) => r.kind !== 'devirtualized').length };
    if (!recs.length) continue;
    v.limitations = v.limitations.filter((l) => !/never been run|nothing is claimed about reconstruction/.test(l));
    v.limitations.push(`Reconstruction is measured on ${recs.length} fixture${recs.length === 1 ? '' : 's'} (${v.reconstruction.lifted} lifted, ${v.reconstruction.traceOnly} ended as behaviour traces); see data/research/luraph-compat.json.`);
    if (identical >= 1) {
      v.verification = { status: 'internally-tested', basis: `${identical} lifted run${identical === 1 ? '' : 's'} compared identical with the original on a Luau runtime; below the ${GATES.authorized.minPairs} authorised pairs the gates ask for` };
      v.capabilities.recover = { available: true, verified: 'internally-tested', note: 'the supplied engine, integrated in the Reconstruct tab' };
    } else {
      v.capabilities.trace = { available: true, verified: 'internally-tested', note: 'behaviour traces from the supplied engine; no lifted run' };
    }
  }
}

export function buildProfiles({ dir = data } = {}) {
  const research = path.join(dir, 'research');
  const records = fs.existsSync(path.join(research, 'records')) ? fs.readdirSync(path.join(research, 'records')).map((f) => read(path.join(research, 'records', f))) : [];
  const history = read(path.join(research, 'histories', 'luraph-macrosdk.json'), null);
  const sources = read(path.join(research, 'sources.json'), { sources: [] });
  const compat = read(path.join(dir, 'compat.json'), { families: [], scorecard: {} });
  const rerun = read(path.join(research, 'reproduction', 'scorecard-rerun.json'), null);
  const profiles = [];
  if (history) profiles.push(luraphProfile(records.filter((r) => /luraph|lura\.ph|Luraph/i.test(r.url) || r.subject === 'Luraph'), history, sources));
  for (const [id, fam] of Object.entries(FAMILIES)) {
    if (id === 'luraph') continue;
    profiles.push(familyProfile(id, fam, compat, rerun));
  }
  profiles.push(...labProfiles(read(path.join(research, 'summary.json'), null), read(path.join(research, 'custom-families.json'), null)));
  applyReconstruction(profiles, read(path.join(research, 'luraph-compat.json'), null));
  applyDifferential(profiles, path.join(research, 'differential'));
  const problems = profiles.flatMap((p) => validateProfile(p).problems);
  if (problems.length) throw new Error(`profiles failed validation:\n${problems.join('\n')}`);
  return { schema: 1, generatedAt: new Date().toISOString(), gates: GATES, profiles: profiles.map((p) => ({ ...p, claims: Object.fromEntries(p.versions.map((v) => [v.id, supportClaim(p, v.id)])) })) };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const out = buildProfiles();
  fs.writeFileSync(path.join(data, 'research', 'profiles.json'), JSON.stringify(out, null, 1) + '\n');
  const by = {};
  for (const p of out.profiles) for (const v of p.versions) { const k = `${v.verification.status} / ${p.claims[v.id].claim}`; by[k] = (by[k] || 0) + 1; }
  console.log(`${out.profiles.length} profiles written`, by);
  const lu = out.profiles.find((p) => p.id === 'luraph');
  for (const v of lu.versions) console.log(` luraph ${v.id.padEnd(8)} ${v.period.since}  macros ${v.macros.all.length}  status ${v.verification.status}  claim ${lu.claims[v.id].claim}`);
}
