// Phase III: the laboratory, the judge, the knowledge base, the advisor, the family SDK and the study framework.
//
// What these tests are for: that a technique cannot be called successful without a verified behaviour check; that experiments repeat; that the
// knowledge base is derived from experiment records and not typed in; that the advisor's advice follows the evidence and changes when the evidence
// does; that a new family can be registered and tested without touching anything else.
//
// Behaviour is compared in QuickSilver's own interpreter (no reference Lua is needed). The quick laboratory run at the end is a regression test of the
// whole engine: if any plan changes what a program does, it fails.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { generateProgram, BLOCK_NAMES } from '../tools/lab/generate.mjs';
import { TRANSFORMS, transformById } from '../tools/lab/transforms.mjs';
import { runExperiment, runLab, behave } from '../tools/lab/run.mjs';
import { experimentId, readExperiments, writeExperiments } from '../tools/lab/store.mjs';
import { compare } from '../tools/lab/compare.mjs';
import { buildKnowledge } from '../tools/lab/kb.mjs';
import { sampleSets } from '../tools/lab/study.mjs';
import { judge, wilson, isSuccess, VERDICTS, GAIN, SLACK } from '../src/research/judge.js';
import { PLANS, planById, runPlan } from '../src/research/plans.js';
import { aggregate, deriveDiscoveries, gaps, MIN_TRIALS, signatureKey } from '../src/research/kb.js';
import { advise, DEFAULT_PLAN, MIN_ADVICE_TRIALS } from '../src/research/advisor.js';
import { observe, opacity } from '../src/research/signature.js';
import { extractFeatures } from '../src/research/features.js';
import { defineFamily, FamilyRegistry, registryFromData, satisfies } from '../src/research/families.js';
import { learnSignature, evaluate, THRESHOLDS } from '../src/research/study.js';
import { recover } from '../src/recover/pipeline.js';
import { runSource } from '../src/sandbox/sandbox.js';
import { buildMarkdownReport } from '../src/app/report-md.js';
import { nexusRecover } from '../src/nexus/pipeline.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.join(here, '..', 'data', 'research');
const out = (src) => runSource(src, { fuel: 30_000_000, timeMs: 6000 }).output;

// ---- the programs and the transformations ------------------------------------------------------------------------------------------------
test('lab: an original program is a function of its seed, runs, and prints what it computes', () => {
  for (let s = 1; s <= 40; s++) {
    const a = generateProgram(s);
    const b = generateProgram(s);
    assert.equal(a.source, b.source, `seed ${s}`);
    const r = runSource(a.source, { fuel: 30_000_000, timeMs: 6000 });
    assert.equal(r.ok, true, `seed ${s}: ${r.error}`);
    assert.ok(r.output.trim().length > 0, `seed ${s} prints nothing`);
    assert.equal(runSource(a.source, {}).output, r.output, `seed ${s} is not deterministic`);
  }
  assert.notEqual(generateProgram(1).source, generateProgram(2).source);
  assert.ok(BLOCK_NAMES.length >= 10);
});

test('lab: every transformation keeps the program\'s behaviour, and none is a disguised no-op', () => {
  for (const t of TRANSFORMS) {
    let applied = 0;
    for (let s = 1; s <= 8; s++) {
      const p = generateProgram(s);
      const text = t.apply(p.source, s);
      assert.equal(out(text), out(p.source), `${t.id} changed the behaviour of program ${s}`);
      if (text !== p.source) applied++;
    }
    assert.ok(applied >= 6, `${t.id} changed only ${applied} of 8 programs`);
  }
  assert.ok(TRANSFORMS.some((t) => t.kind === 'custom') && TRANSFORMS.some((t) => t.kind === 'stacked') && TRANSFORMS.some((t) => t.kind === 'known'));
});

test('lab: custom systems are not the output of a third-party tool and say so', () => {
  for (const t of TRANSFORMS.filter((x) => x.kind === 'custom')) assert.match(t.label, /^lab custom:/);
});

// ---- the judge ---------------------------------------------------------------------------------------------------------------------------
const base = { transformValid: true, parsed: true, behaviour: 'identical', fidelityBefore: 0.4, fidelityAfter: 0.5, opacityBefore: 3, opacityAfter: 3 };

test('judge: success needs a behaviour check that came out identical', () => {
  assert.equal(judge(base), 'verified-partial');
  assert.equal(judge({ ...base, fidelityAfter: 0.95 }), 'verified-recovery');
  for (const behaviour of ['different', 'inconclusive', undefined]) assert.equal(isSuccess(judge({ ...base, fidelityAfter: 0.99, behaviour })), false, String(behaviour));
  assert.equal(judge({ ...base, behaviour: 'different' }), 'failed-behaviour');
  assert.equal(judge({ ...base, parsed: false }), 'failed-parse');
  assert.equal(judge({ ...base, error: 'boom' }), 'error');
  assert.equal(judge({ ...base, transformValid: false }), 'tool-broken');
});

test('judge: a result that was already close and got no closer is not a success', () => {
  // the flaw found in the first lab run: fidelity 0.99 -> 0.98 was being called success
  assert.equal(judge({ ...base, fidelityBefore: 0.99, fidelityAfter: 0.98, opacityBefore: 1, opacityAfter: 1 }), 'behaviour-kept-no-gain');
  assert.equal(judge({ ...base, fidelityBefore: 1.0, fidelityAfter: 0.71, opacityBefore: 1, opacityAfter: 0 }), 'behaviour-kept-worse', 'fewer signs of obfuscation do not excuse losing structure');
  assert.equal(judge({ ...base, fidelityBefore: 1.0, fidelityAfter: 0.98, opacityBefore: 2, opacityAfter: 0 }), 'verified-recovery', 'but fewer signs without losing closeness does count');
});

test('judge: the noise band is one band: what is too small to be a gain is too small to be a loss, and it cannot be changed quietly', () => {
  assert.equal(SLACK, GAIN);
  assert.equal(GAIN, 0.05);
  // a drop of 0.04 while every sign of obfuscation goes is a clean-up, not a failure; a drop of 0.06 is a loss
  assert.equal(judge({ ...base, fidelityBefore: 1.0, fidelityAfter: 0.96, opacityBefore: 3, opacityAfter: 0 }), 'verified-recovery');
  assert.equal(judge({ ...base, fidelityBefore: 1.0, fidelityAfter: 0.94, opacityBefore: 3, opacityAfter: 0 }), 'behaviour-kept-worse');
});

test('judge: intervals are honest about small samples', () => {
  assert.deepEqual(wilson(0, 0), { p: 0, lo: 0, hi: 1 });
  const w = wilson(8, 8);
  assert.ok(w.p === 1 && w.lo < 0.7 && w.hi === 1, '8 of 8 does not prove 80%');
  assert.ok(wilson(16, 16).lo > 0.8);
  assert.ok(VERDICTS.includes('verified-recovery'));
});

// ---- experiments: classification, reproducibility ------------------------------------------------------------------------------------------
function experiment(plan, transformId = 'junk', seed = 3) {
  const program = generateProgram(seed);
  const reference = behave(program.source);
  const transform = transformById(transformId);
  const transformed = transform.apply(program.source, seed);
  const tvalid = behave(transformed).output === reference.output;
  return runExperiment({ program, reference, transform, transformSeed: seed, transformed, tvalid, plan, registry: null });
}
const fake = (id, run) => ({ id, label: id, run });

test('experiment: a technique that returns the input unchanged gains nothing, a broken one is called broken, none is called a success', () => {
  const src = generateProgram(3).source;
  const same = experiment(fake('identity', (text) => ({ code: text })));
  assert.ok(['behaviour-kept-no-gain', 'behaviour-kept-worse'].includes(same.verdict), same.verdict);
  assert.equal(experiment(fake('empty', () => ({ code: '-- nothing\n' }))).verdict, 'failed-behaviour');
  assert.equal(experiment(fake('wrong', () => ({ code: 'print("something else")\n' }))).verdict, 'failed-behaviour');
  assert.equal(experiment(fake('garbage', () => ({ code: 'local = = = end end' }))).verdict, 'failed-parse');
  assert.equal(experiment(fake('declines', () => ({ code: null }))).verdict, 'failed-parse');
  assert.equal(experiment(fake('throws', () => { throw new Error('boom'); })).verdict, 'error');
  assert.equal(experiment(fake('original', () => ({ code: src }))).verdict, 'verified-recovery', 'only handing back the original behaves like it and is as close as it can be');
});

test('experiment: a transformation that changes behaviour is excluded, not blamed on the technique', () => {
  const program = generateProgram(3);
  const reference = behave(program.source);
  const broken = { id: 'broken', kind: 'known', label: 'broken', apply: () => 'print("x")' };
  const rec = runExperiment({ program, reference, transform: broken, transformSeed: 3, transformed: 'print("x")', tvalid: false, plan: planById('generic'), registry: null });
  assert.equal(rec.verdict, 'tool-broken');
  assert.equal(aggregate([rec]).counts.toolBroken, 1);
});

test('experiment: repeating an experiment gives the same record (reproducibility)', () => {
  const strip = ({ ms, ...r }) => r;
  const a = experiment(planById('adaptive'), 'flatten-chain', 5);
  const b = experiment(planById('adaptive'), 'flatten-chain', 5);
  assert.deepEqual(strip(a), strip(b));
  assert.equal(a.id, experimentId({ programSeed: 5, transformId: 'flatten-chain', transformSeed: 5, planId: 'adaptive', engine: `${a.env.engine}@${a.env.rev}` }));
  assert.match(a.id, /^exp_[0-9a-f]{14}$/);
  assert.ok(a.env.rev && a.env.node && a.env.interpreter);
  assert.notEqual(a.id, experiment(planById('generic'), 'flatten-chain', 5).id);
});

test('experiment: the observed signature does not depend on knowing the transformation', () => {
  const rec = experiment(planById('generic'), 'xorpack', 4);
  const p = generateProgram(4);
  assert.deepEqual(rec.observed, observe(transformById('xorpack').apply(p.source, 4)).tokens);
  assert.ok(rec.opacityBefore > 0 && rec.opacityBefore === opacity(rec.observed));
});

test('store: records are written and read back as they were', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'qs-lab-'));
  const file = path.join(dir, 'e.jsonl');
  const recs = [experiment(planById('generic')), experiment(planById('nexus'))];
  writeExperiments(file, recs);
  assert.deepEqual(readExperiments(file), recs);
  assert.deepEqual(readExperiments(path.join(dir, 'nothing.jsonl')), []);
  fs.rmSync(dir, { recursive: true, force: true });
});

// ---- the knowledge base ------------------------------------------------------------------------------------------------------------------
const rec = (transform, plan, verdict, extra = {}) => ({ id: `${transform}${plan}${Math.random()}`, program: { seed: 1 }, transform: { id: transform }, plan: { id: plan }, observed: ['trait:state-machine'], verdict, fidelityBefore: 0.4, fidelityAfter: 0.6, ...extra });
const many = (n, t, p, verdict) => Array.from({ length: n }, () => rec(t, p, verdict));

test('knowledge: a small experiment produces no statement at all', () => {
  const agg = aggregate(many(MIN_TRIALS - 1, 'T', 'generic', 'verified-partial'));
  assert.deepEqual(deriveDiscoveries(agg), []);
});

test('knowledge: statements follow from the counts by stated rules', () => {
  const exps = [...many(16, 'T', 'generic', 'verified-partial'), ...many(16, 'U', 'generic', 'behaviour-kept-no-gain'), ...many(16, 'W', 'generic', 'behaviour-kept-worse'),
    ...many(16, 'S', 'adaptive', 'behaviour-kept-no-gain'), ...many(16, 'S', 'adaptive+sandbox', 'verified-recovery')];
  const found = deriveDiscoveries(aggregate(exps));
  const kinds = Object.fromEntries(found.map((d) => [d.id, d.kind]));
  assert.equal(kinds['works:T:generic'], 'works');
  assert.equal(kinds['fails:U:generic'], 'fails');
  assert.equal(kinds['harms:W:generic'], 'harms');
  assert.equal(kinds['needs-sandbox:S:adaptive'], 'needs-sandbox');
  for (const d of found) assert.ok(d.rule && d.statement && d.trials >= MIN_TRIALS, d.id);
  assert.equal(gaps(aggregate(many(16, 'U', 'generic', 'behaviour-kept-no-gain')))[0].transform, 'U');
});

test('knowledge: the shipped summary and knowledge files are what the experiment records give, not hand-edited', () => {
  const { summary, knowledge } = buildKnowledge(dataDir);
  const shipped = JSON.parse(fs.readFileSync(path.join(dataDir, 'summary.json'), 'utf8'));
  const strip = ({ generatedAt, ...r }) => r;
  assert.deepEqual(strip(summary), strip(shipped));
  const shippedKb = JSON.parse(fs.readFileSync(path.join(dataDir, 'knowledge.json'), 'utf8'));
  assert.deepEqual(strip(knowledge), strip(shippedKb));
  assert.ok(summary.counts.experiments >= 1600 && summary.counts.programs >= 16);
  assert.equal(knowledge.defects.length, 0, 'no shipped experiment shows a reconstruction that behaves differently');
});

test('knowledge: outside research is graded, kept apart from discoveries, and claims no compatibility it did not test', () => {
  const { knowledge } = buildKnowledge(dataDir);
  const ids = knowledge.discoveries.map((d) => d.id).join(' ');
  for (const s of knowledge.sources) {
    assert.ok(['source', 'third-party', 'search-snippet', 'unreachable'].includes(s.grade), s.id);
    assert.ok(s.retrieved && s.labStatus && s.labReason, s.id);
    assert.ok(!ids.includes(s.id), 'a source is not a discovery');
  }
  const luraph = knowledge.sources.find((s) => s.id === 'luraph');
  assert.equal(luraph.labStatus, 'untested');
  assert.ok(!knowledge.discoveries.some((d) => /luraph/i.test(d.statement)), 'nothing is claimed about Luraph');
});

test('knowledge: every technique evaluation compares the same experiments on two revisions and lists what got worse', () => {
  const { knowledge } = buildKnowledge(dataDir);
  assert.ok(knowledge.evaluations.length >= 3);
  for (const e of knowledge.evaluations) {
    assert.ok(e.base.rev && e.current.rev && e.matched > 0 && Array.isArray(e.cellsRegressed), e.label);
  }
  const lift = knowledge.evaluations.find((e) => e.label === '1-functions-lift');
  assert.ok(lift.regressedExperiments > 0, 'the first version of the technique made some results worse, and the record says so');
  const total = knowledge.evaluations.find((e) => e.label === '3-phase3-total');
  assert.equal(total.regressedExperiments, 0);
  assert.ok(total.improvedExperiments > 100);
});

test('compare: improvements and regressions are both found', () => {
  const mk = (v) => ({ program: { seed: 1 }, transform: { id: 'T' }, plan: { id: 'p' }, verdict: v, env: { rev: 'x' }, id: v });
  const r = compare([mk('verified-partial')], [mk('behaviour-kept-worse')], { label: 'l' });
  assert.equal(r.regressedExperiments, 1);
  assert.equal(r.regressions[0].to, 'behaviour-kept-worse');
  assert.equal(compare([mk('behaviour-kept-no-gain')], [mk('verified-recovery')], { label: 'l' }).improvedExperiments, 1);
});

// ---- the advisor -------------------------------------------------------------------------------------------------------------------------
function summaryOf(exps) {
  const agg = aggregate(exps);
  return { bySignaturePlan: agg.bySignaturePlan };
}
const tokens = ['trait:state-machine'];

test('advisor: with no matching experiment it says so and falls back to the default plan', () => {
  const a = advise(['trait:junk-code'], summaryOf(many(20, 'T', 'generic', 'verified-partial')));
  assert.equal(a.basis, 'none');
  assert.equal(a.plan.id, DEFAULT_PLAN);
  assert.match(a.reason, /No verified experiment matches/);
  assert.equal(advise(tokens, null).basis, 'none');
});

test('advisor: it follows the evidence, and the advice changes when the evidence does', () => {
  const first = summaryOf([...many(16, 'T', 'generic', 'behaviour-kept-no-gain'), ...many(16, 'T', 'adaptive', 'verified-partial')]);
  const a = advise(tokens, first);
  assert.equal(a.plan.id, 'adaptive');
  assert.equal(a.basis, 'exact');
  assert.ok(a.alternatives[0].plan === 'adaptive' && a.trials === 16);
  // more verified experiments arrive in which the generic plan does better
  const later = summaryOf([...many(16, 'T', 'generic', 'verified-recovery'), ...many(16, 'T', 'adaptive', 'behaviour-kept-worse'), ...many(16, 'T', 'generic', 'verified-recovery')]);
  assert.equal(advise(tokens, later).plan.id, 'generic');
});

test('advisor: results that lost structure count against a plan, not for it', () => {
  const s = summaryOf([...many(16, 'T', 'generic', 'verified-partial'), ...many(16, 'T', 'adaptive', 'verified-partial'), ...many(16, 'T', 'nexus', 'verified-partial'), ...many(8, 'T', 'adaptive', 'behaviour-kept-worse')]);
  const a = advise(tokens, s);
  assert.notEqual(a.plan.id, 'adaptive');
});

test('advisor: a plan that needs the sandbox is recommended, and applied only when the sandbox is allowed', () => {
  const s = summaryOf([...many(16, 'T', 'nexus', 'behaviour-kept-no-gain'), ...many(16, 'T', 'nexus+sandbox', 'verified-recovery')]);
  const off = advise(tokens, s, { allowSandbox: false });
  assert.equal(off.plan.id, 'nexus+sandbox');
  assert.equal(off.applied.id, 'nexus');
  assert.equal(off.recommendSandbox, true);
  const on = advise(tokens, s, { allowSandbox: true });
  assert.equal(on.applied.id, 'nexus+sandbox');
  assert.equal(on.recommendSandbox, false);
});

test('advisor: asked for NEXUS plans only, it ranks those and never picks a plain-engine plan', () => {
  const s = summaryOf([...many(16, 'T', 'generic', 'verified-recovery'), ...many(16, 'T', 'nexus-generic', 'verified-partial'), ...many(16, 'T', 'nexus', 'behaviour-kept-no-gain')]);
  assert.equal(advise(tokens, s).plan.id, 'generic');
  const a = advise(tokens, s, { nexus: true });
  assert.equal(a.plan.id, 'nexus-generic');
  assert.ok(a.alternatives.every((r) => planById(r.plan).nexus));
  assert.equal(advise(['trait:junk-code'], s, { nexus: true }).plan.id, DEFAULT_PLAN);
});

test('advisor: too few trials give no preference, and a similar signature is used only if it is labelled so', () => {
  assert.equal(advise(tokens, summaryOf(many(MIN_ADVICE_TRIALS - 1, 'T', 'adaptive', 'verified-recovery'))).basis, 'none');
  const s = summaryOf(many(20, 'T', 'adaptive', 'verified-recovery').map((r) => ({ ...r, observed: ['trait:state-machine', 'trait:junk-code'] })));
  const a = advise(['trait:state-machine'], s);
  assert.equal(a.basis, 'similar');
  assert.ok(a.similarTo.length === 1 && a.similarTo[0].similarity >= 0.5);
});

test('advisor: on the shipped data it prefers the plan the experiments favour for a script that was only renamed', () => {
  const summary = JSON.parse(fs.readFileSync(path.join(dataDir, 'summary.json'), 'utf8'));
  const p = generateProgram(7);
  const renamed = transformById('rename').apply(p.source, 7);
  const a = advise(observe(renamed).tokens, summary);
  assert.notEqual(a.basis, 'none');
  assert.ok(a.alternatives.length >= 3);
  assert.ok(a.alternatives[0].utility >= a.alternatives[a.alternatives.length - 1].utility);
});

// ---- families, features, study --------------------------------------------------------------------------------------------------------------
test('families: a family is validated, registered, and matched without touching anything else', () => {
  const spec = { id: 'demo-family', name: 'Demo', origin: 'registered', signature: { all: ['call:loadstring'], none: ['names:machine'] }, versions: [{ id: 'v1' }, { id: 'v2' }] };
  const f = defineFamily(spec);
  assert.equal(f.versions.length, 2);
  const reg = new FamilyRegistry([spec]);
  assert.deepEqual(reg.match(new Set(['call:loadstring'])).map((m) => m.id), ['demo-family']);
  assert.deepEqual(reg.match(new Set(['call:loadstring', 'names:machine'])), []);
  assert.throws(() => reg.register(spec), /already registered/);
  assert.throws(() => defineFamily({ ...spec, id: 'Bad Id' }), /id must be/);
  assert.throws(() => defineFamily({ ...spec, signature: { all: [] } }), /at least one/);
  assert.throws(() => defineFamily({ ...spec, origin: 'magic' }), /origin/);
  assert.equal(reg.unregister('demo-family'), true);
  assert.equal(satisfies({ all: ['a'], none: [] }, new Set(['a'])), true);
});

test('features: facts about a script are measured without running it, and a clean program shows none of the signs', () => {
  for (let s = 1; s <= 10; s++) {
    const f = extractFeatures(generateProgram(s).source).features;
    assert.equal([...f].filter((x) => ['comments:dense', 'names:machine', 'data:byte-table', 'shape:vararg-wrapper', 'shape:function-table', 'call:loadstring'].includes(x)).length, 0, `program ${s}: ${[...f]}`);
  }
  assert.deepEqual([...extractFeatures('local = = =').features], ['syntax:invalid']);
});

test('study: a learned signature is accepted only on held-out numbers; a system the surface cannot separate is rejected, with its numbers', () => {
  const P = Array.from({ length: 10 }, () => new Set(['a', 'x']));
  const N = Array.from({ length: 20 }, (_, i) => new Set(i % 2 ? ['a'] : ['x']));
  const learned = learnSignature({ positives: P, negatives: N });
  assert.deepEqual(learned.signature.all.sort(), ['a', 'x']);
  assert.equal(evaluate(learned.signature, { positives: P, negatives: N }).accepted, true);
  const hard = evaluate({ all: ['a'], none: [] }, { positives: P, negatives: N });
  assert.equal(hard.accepted, false);
  assert.match(hard.reasons.join(), /precision/);
  assert.equal(learnSignature({ positives: P.slice(0, 3), negatives: N }), null, 'too few positives to learn from');
  assert.ok(THRESHOLDS.precision >= 0.95);
});

test('study: the shipped families were learned from samples and hold on programs they were not learned from', () => {
  const fams = JSON.parse(fs.readFileSync(path.join(dataDir, 'custom-families.json'), 'utf8'));
  const reg = registryFromData(fams);
  assert.deepEqual(reg.list().map((f) => f.id).sort(), ['lab-loadwrap', 'lab-tabledispatch', 'lab-xorpack']);
  const fresh = sampleSets({ first: 301, count: 10 });
  for (const f of reg.list()) {
    assert.equal(f.origin, 'lab-learned');
    assert.ok(f.learned.heldout.precision >= THRESHOLDS.precision && f.learned.heldout.recall >= THRESHOLDS.recall);
    const id = f.id.replace(/^lab-/, '');
    assert.ok(fresh.by.get(id).every((s) => satisfies(f.signature, s)), `${f.id} misses a sample it should match`);
    assert.ok(!fresh.clean.some((s) => satisfies(f.signature, s)), `${f.id} fires on a clean program`);
    assert.equal(fresh.by.get('confetti').some((s) => satisfies(f.signature, s)), false);
  }
  const study = JSON.parse(fs.readFileSync(path.join(dataDir, 'study.json'), 'utf8'));
  const rejected = study.attempts.filter((a) => a.outcome !== 'accepted').map((a) => a.transform);
  assert.ok(rejected.includes('flatten-chain') && rejected.includes('opaque'), 'failed attempts are kept');
});

test('study: a family learned from one layer does not see through another layer (nested systems hide each other)', () => {
  const reg = registryFromData(JSON.parse(fs.readFileSync(path.join(dataDir, 'custom-families.json'), 'utf8')));
  const p = generateProgram(11);
  const nested = transformById('stack-xorpack-loadwrap').apply(p.source, 11);
  const seen = observe(nested, { registry: reg }).custom;
  assert.ok(seen.includes('lab-loadwrap'));
  assert.ok(!seen.includes('lab-xorpack'), 'the cipher is inside the loader, not on the surface');
});

// ---- the techniques added by the laboratory ----------------------------------------------------------------------------------------------
const lifted = (src) => recover(src, { annotate: false });

test('functions.lift: functions kept in a machine-named table become local functions, and behaviour is kept', () => {
  const src = 'local lIl1 = {}\nlIl1.IIa = function(x) return x + 1 end\nfunction lIl1.IIb(y) return lIl1.IIa(y) * 2 end\nprint(lIl1.IIb(3), lIl1.IIa(1))';
  const r = lifted(src);
  assert.doesNotMatch(r.output, /lIl1|tbl\./);
  assert.match(r.output, /local function/);
  assert.equal(out(r.output), out(src));
});

test('functions.lift: a function that calls one defined later gets forward declarations, and still works', () => {
  const src = 'local lIl1 = {}\nfunction lIl1.A(y) return lIl1.B(y) + 1 end\nfunction lIl1.B(y) return y * 2 end\nprint(lIl1.A(3))';
  const r = lifted(src);
  assert.equal(out(r.output), '7\n');
  assert.doesNotMatch(r.output, /lIl1/);
});

test('functions.lift: a module a person wrote, or a table used any other way, is left alone', () => {
  const human = 'local Utils = {}\nfunction Utils.a(x) return x + 1 end\nfunction Utils.b(x) return x * 2 end\nprint(Utils.a(1), Utils.b(2))';
  assert.match(lifted(human).output, /function Utils\.a/);
  const passedOn = 'local lIl1 = {}\nfunction lIl1.a(x) return x + 1 end\nfunction lIl1.b(x) return x * 2 end\nlocal function each(t) for k in pairs(t) do print(k) end end\neach(lIl1)\nprint(lIl1.a(1), lIl1.b(2))';
  assert.match(lifted(passedOn).output, /function tbl\.a/, 'the table stays a table (the renamer only gave it a readable name)');
  const computed = 'local lIl1 = {}\nfunction lIl1.a(x) return x + 1 end\nfunction lIl1.b(x) return x * 2 end\nlocal k = "a"\nprint(lIl1[k](1), lIl1.b(2))';
  assert.match(lifted(computed).output, /tbl\[k\]/);
  const twice = 'local lIl1 = {}\nfunction lIl1.a(x) return x + 1 end\nfunction lIl1.a(x) return x + 2 end\nprint(lIl1.a(1))';
  assert.match(lifted(twice).output, /function tbl\.a/);
  const clash = 'local lIl1 = {}\nfunction lIl1.print2(x) return x + 1 end\nfunction lIl1.b(x) return x * 2 end\nlocal print2 = 5\nprint(lIl1.print2(1), lIl1.b(2), print2)';
  assert.equal(out(lifted(clash).output), out(clash));
});

test('proxies: a function that stands in for one operation is inlined; a short computation the author wrote is not', () => {
  const proxy = 'local function lIl1(a, b) return a + b end\nprint(lIl1(2, 3), lIl1(4, 5))';
  assert.doesNotMatch(lifted(proxy).output, /lIl1/);
  const helper = 'local function lIl1(s) return (s * 1103515245 + 12345) % 2147483648 end\nlocal n = 7\nfor i = 1, 3 do n = lIl1(n) end\nprint(n)';
  const r = lifted(helper);
  assert.match(r.output, /function/);
  assert.equal(out(r.output), out(helper));
});

// ---- the report ---------------------------------------------------------------------------------------------------------------------------
test('report: the Markdown report states the plan, the evidence, what was verified and what was inferred', () => {
  const summary = JSON.parse(fs.readFileSync(path.join(dataDir, 'summary.json'), 'utf8'));
  const src = transformById('rename').apply(generateProgram(8).source, 8);
  const seen = observe(src);
  const advice = advise(seen.tokens, summary);
  const md = buildMarkdownReport({ name: 'a|b.lua', bytes: src.length, recovered: nexusRecover(src, { recover: { sandbox: { enabled: false } } }), advice, observed: seen, engine: '1.0.0' });
  for (const h of ['# Analysis report: a|b.lua', '## Plan chosen and the evidence for it', '## Verification', '## Limits']) assert.ok(md.includes(h), h);
  assert.match(md, /\*\*verified\*\*/);
  assert.match(md, /Trials/);
});

// ---- the whole engine, in the laboratory -------------------------------------------------------------------------------------------------
test('regression: over programs the laboratory has not seen, no plan changes what a program does', { timeout: 600_000 }, () => {
  const records = runLab({ seeds: 3, first: 401, transforms: null, plans: null, out: dataDir, families: path.join(dataDir, 'custom-families.json') });
  assert.equal(records.length, 3 * TRANSFORMS.length * PLANS.length - records.skipped * PLANS.length);
  const bad = records.filter((r) => ['failed-behaviour', 'failed-parse', 'error', 'tool-broken'].includes(r.verdict));
  assert.deepEqual(bad.map((r) => `${r.transform.id}/${r.plan.id}/${r.program.seed}: ${r.verdict}`), []);
  assert.ok(records.filter((r) => isSuccess(r.verdict)).length > records.length * 0.5);
});
