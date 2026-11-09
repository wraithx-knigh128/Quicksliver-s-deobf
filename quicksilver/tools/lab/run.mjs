// Lab: the experiment runner.
//
//   node tools/lab/run.mjs [--seeds 16] [--first 1] [--transforms id,id] [--plans id,id] [--out data/research] [--quick]
//
// For every (original program, transformation, reconstruction plan) it:
//   1. generates the original and runs it in the sandbox: that run is the reference;
//   2. applies the transformation and runs the result: if it does not behave like the original the transformation is broken, and the cell says so;
//   3. observes the transformed text the way the page would (signature.js), without using what it knows about the transformation;
//   4. runs the plan, and compares the reconstruction with the original by behaviour (same output, same ending) and by fidelity (how close
//      its tokens are to the original's, against how close the transformed input was);
//   5. asks the judge (src/research/judge.js) for the verdict, and appends a record.
//
// Nothing here claims a result. The verdict is the judge's, and the numbers are in the record.

import fs from 'node:fs';
import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { generateProgram } from './generate.mjs';
import { TRANSFORMS } from './transforms.mjs';
import { experimentId, hash, readExperiments, writeExperiments } from './store.mjs';
import { sandboxRun, observeBehaviour, compareBehaviour, referenceRuntimes } from './behaviour.mjs';
import { stopOracle } from '../runtime/oracle.mjs';
import { fidelity } from '../../src/core/fidelity.js';
import { parse, LuaSyntaxError } from '../../src/core/parser.js';
import { PLANS, runPlan } from '../../src/research/plans.js';
import { judge } from '../../src/research/judge.js';
import { observe, opacity } from '../../src/research/signature.js';
import { registryFromData } from '../../src/research/families.js';
import { ENGINE_VERSION } from '../../src/api.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..', '..');
function sourceHash() {
  const files = [];
  const walkDir = (d) => { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const f = path.join(d, e.name); if (e.isDirectory()) walkDir(f); else if (/\.m?js$/.test(e.name)) files.push(f); } };
  walkDir(path.join(root, 'src'));
  files.sort();
  return hash(files.map((f) => `${path.relative(root, f)}\n${fs.readFileSync(f, 'utf8')}`).join('\n'), 8);
}
/** The code under test: the commit, and when src/ differs from it, a hash of src/ so that two states of the working tree never share a tag. */
function revision() {
  try {
    const sha = execSync('git rev-parse --short HEAD', { cwd: root, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
    const dirty = execSync('git status --porcelain -- src', { cwd: root, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim().length > 0;
    return dirty ? `${sha}+${sourceHash()}` : sha;
  } catch { return `src-${sourceHash()}`; }
}
const REV = process.env.QS_LAB_REV || revision();

/** Sandbox-only behaviour of a program (kept for callers that have no reference runtime). */
export function behave(source) {
  const r = sandboxRun(source);
  return { ok: r.ok, kind: null, error: r.error, output: r.output, limited: r.limited };
}

/** Run one experiment. `registry` supplies learned families to the observation. */
export async function runExperiment({ program, reference, transform, transformSeed, transformed, tvalid, plan, registry, runtimes = [] }) {
  const rec = {
    id: experimentId({ programSeed: program.seed, transformId: transform.id, transformSeed, planId: plan.id, engine: `${ENGINE_VERSION}@${REV}` }),
    schema: 1,
    program: { seed: program.seed, hash: hash(program.source), blocks: program.blocks, bytes: program.source.length },
    transform: { id: transform.id, kind: transform.kind, seed: transformSeed, hash: hash(transformed), bytes: transformed.length },
    plan: { id: plan.id },
    env: { engine: ENGINE_VERSION, rev: REV, node: process.version, interpreter: runtimes.length ? `${runtimes.join('+')} (reference, decides); quicksilver-sandbox (cross-check)` : 'quicksilver-sandbox (no reference runtime was available)', lab: 2 },
    transformValid: tvalid,
  };
  if (!tvalid) { rec.verdict = judge(rec); return rec; }
  const t0 = performance.now();
  try {
    rec.observed = observe(transformed, { registry }).tokens;
    rec.opacityBefore = opacity(rec.observed);
    const out = runPlan(plan, transformed);
    rec.ms = Math.round(performance.now() - t0);
    rec.parsed = false;
    if (out.ok && typeof out.code === 'string') {
      try { parse(out.code); rec.parsed = true; } catch (e) { if (!(e instanceof LuaSyntaxError)) throw e; }
    }
    if (rec.parsed) {
      // static and runtime verification are separate records: that it parses is static; what it does is a run
      const got = await observeBehaviour(out.code, runtimes);
      const cmp = compareBehaviour(reference, got);
      rec.behaviour = cmp.verdict;
      rec.behaviourSource = cmp.source;
      rec.runtimeChecks = cmp.per;
      if (cmp.disagreement) rec.disagreement = true;
      if (cmp.difference) rec.difference = cmp.difference;
      rec.verification = { static: { parsed: true }, runtime: { source: cmp.source, runtimes: cmp.source === 'reference' ? runtimes : ['quicksilver-sandbox'] } };
      rec.fidelityBefore = round(fidelity(program.source, transformed).score);
      rec.fidelityAfter = round(fidelity(program.source, out.code).score);
      rec.opacityAfter = opacity(observe(out.code, { registry }).tokens);
      rec.bytesOut = out.code.length;
      rec.confidence = out.confidence ? { level: out.confidence.level, score: out.confidence.score } : null;
    }
  } catch (e) {
    rec.error = String((e && e.message) || e).slice(0, 300);
    rec.ms = Math.round(performance.now() - t0);
  }
  rec.verdict = judge(rec);
  return rec;
}
const round = (x) => Math.round(x * 1000) / 1000;

function parseArgs(argv) {
  const a = { oracle: 'auto', seeds: 16, first: 1, transforms: null, plans: null, out: path.join(root, 'data', 'research'), quick: false, families: null };
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (k === '--quick') a.quick = true;
    else if (k === '--seeds') a.seeds = Number(argv[++i]);
    else if (k === '--first') a.first = Number(argv[++i]);
    else if (k === '--transforms') a.transforms = argv[++i].split(',');
    else if (k === '--plans') a.plans = argv[++i].split(',');
    else if (k === '--out') a.out = path.resolve(argv[++i]);
    else if (k === '--families') a.families = path.resolve(argv[++i]);
    else if (k === '--oracle') a.oracle = argv[++i];
  }
  if (a.quick) a.seeds = Math.min(a.seeds, 3);
  return a;
}

export async function runLab(args) {
  const plans = PLANS.filter((p) => !args.plans || args.plans.includes(p.id));
  const transforms = TRANSFORMS.filter((t) => !args.transforms || args.transforms.includes(t.id));
  const familiesFile = args.families || path.join(args.out, 'custom-families.json');
  const registry = fs.existsSync(familiesFile) ? registryFromData(JSON.parse(fs.readFileSync(familiesFile, 'utf8'))) : null;
  // the reference runtimes that decide behaviour: --oracle none | auto (the installed 5.1-family ones) | lua51,luajit,lua54 ...
  const runtimes = args.oracle === 'none' ? [] : args.oracle === 'auto' || !args.oracle ? await referenceRuntimes() : await referenceRuntimes(args.oracle.split(','));
  const records = [];
  let skipped = 0;
  const t0 = Date.now();
  for (let s = args.first; s < args.first + args.seeds; s++) {
    const program = generateProgram(s);
    const reference = await observeBehaviour(program.source, runtimes);
    for (const [id, r] of [['sandbox', reference.sandbox], ...Object.entries(reference.reference)]) if (!r.ok) throw new Error(`the original program for seed ${s} does not run on ${id}: ${r.error}`);
    for (const transform of transforms) {
      const transformSeed = s;
      let transformed;
      let tvalid = true;
      try { transformed = transform.apply(program.source, transformSeed); } catch (e) { transformed = ''; tvalid = false; void e; }
      if (tvalid) tvalid = compareBehaviour(reference, await observeBehaviour(transformed, runtimes)).verdict === 'identical';
      // a transformation that did not apply to this program (nothing in it to transform) leaves the text as it was: it is not an experiment
      if (tvalid && transformed === program.source) { skipped++; continue; }
      for (const plan of plans) records.push(await runExperiment({ program, reference, transform, transformSeed, transformed, tvalid, plan, registry, runtimes }));
    }
    process.stderr.write(`seed ${s}: ${records.length} experiments, ${Math.round((Date.now() - t0) / 1000)} s\n`);
  }
  records.skipped = skipped;
  records.runtimes = runtimes;
  return records;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = parseArgs(process.argv.slice(2));
  const records = await runLab(args);
  stopOracle();
  const file = path.join(args.out, 'experiments.jsonl');
  // a rerun replaces the cells it covers and keeps the rest
  const keep = readExperiments(file).filter((r) => !records.some((n) => n.id === r.id));
  writeExperiments(file, [...keep, ...records].sort((a, b) => a.id.localeCompare(b.id)));
  const by = {};
  for (const r of records) by[r.verdict] = (by[r.verdict] || 0) + 1;
  console.log(`${records.length} experiments -> ${file} (${records.skipped} transformation/program pairs skipped: the transformation did not apply)`);
  console.log(by);
  console.log(`behaviour decided by: ${records.runtimes.length ? records.runtimes.join(' + ') : 'the sandbox only (no reference runtime)'}; disagreements between sandbox and reference: ${records.filter((r) => r.disagreement).length}`);
}
