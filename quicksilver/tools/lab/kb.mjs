// Lab: build the knowledge base from the experiment records.
//
//   node tools/lab/kb.mjs [--out data/research]
//
// Reads experiments.jsonl, study.json, custom-families.json, sources.json and evaluations/*.json; writes summary.json (what the page's advisor reads) and
// knowledge.json (what the Research tab shows). Everything in them is derived from those files by src/research/kb.js; nothing is typed in here.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readExperiments } from './store.mjs';
import { aggregate, deriveDiscoveries, gaps, MIN_TRIALS } from '../../src/research/kb.js';
import { TRANSFORMS } from './transforms.mjs';
import { PLANS } from '../../src/research/plans.js';
import { ENGINE_VERSION } from '../../src/api.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (f, d) => (fs.existsSync(f) ? JSON.parse(fs.readFileSync(f, 'utf8')) : d);

export function buildKnowledge(dir) {
  const experiments = readExperiments(path.join(dir, 'experiments.jsonl'));
  const agg = aggregate(experiments);
  const labels = Object.fromEntries(TRANSFORMS.map((t) => [t.id, t.label]));
  const study = read(path.join(dir, 'study.json'), { attempts: [] });
  const families = read(path.join(dir, 'custom-families.json'), { families: [] });
  const sources = read(path.join(dir, 'sources.json'), { sources: [] });
  const evalDir = path.join(dir, 'evaluations');
  const evaluations = fs.existsSync(evalDir) ? fs.readdirSync(evalDir).filter((f) => f.endsWith('.json')).sort().map((f) => JSON.parse(fs.readFileSync(path.join(evalDir, f), 'utf8'))) : [];
  const revs = [...new Set(experiments.map((r) => r.env.rev))];
  const programs = new Set(experiments.map((r) => r.program.seed)).size;

  const summary = {
    schema: 1, generatedAt: new Date().toISOString(), engine: ENGINE_VERSION, revisions: revs,
    interpreter: 'quicksilver-sandbox (this project\'s own Lua interpreter; not a reference Lua)',
    counts: { ...agg.counts, programs },
    plans: PLANS.map(({ id, label, needsConsent, text }) => ({ id, label, needsConsent, text })),
    transforms: TRANSFORMS.map(({ id, kind, label }) => ({ id, kind, label })),
    byTransformPlan: agg.byTransformPlan,
    bySignaturePlan: agg.bySignaturePlan,
  };
  const knowledge = {
    schema: 1, generatedAt: summary.generatedAt, engine: ENGINE_VERSION, revisions: revs, minTrials: MIN_TRIALS,
    counts: summary.counts,
    discoveries: deriveDiscoveries(agg, { labels }),
    gaps: gaps(agg).map((g) => ({ ...g, label: labels[g.transform] || g.transform })),
    defects: agg.defects,
    study: study.attempts.map((a) => ({ transform: a.transform, kind: a.kind, outcome: a.outcome, signature: a.signature || null, heldout: a.heldout || null, reasons: a.reasons || [], onStacks: a.onStacks || [] })),
    families: families.families.map((f) => ({ id: f.id, name: f.name, origin: f.origin, versions: f.versions, signature: f.signature, learned: f.learned })),
    evaluations,
    sources: sources.sources,
    sourceGrades: sources.grades,
  };
  return { summary, knowledge, experiments };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const argv = process.argv.slice(2);
  const dir = argv.includes('--out') ? path.resolve(argv[argv.indexOf('--out') + 1]) : path.join(here, '..', '..', 'data', 'research');
  const { summary, knowledge } = buildKnowledge(dir);
  fs.writeFileSync(path.join(dir, 'summary.json'), JSON.stringify(summary) + '\n');
  fs.writeFileSync(path.join(dir, 'knowledge.json'), JSON.stringify(knowledge, null, 1) + '\n');
  const by = {};
  for (const d of knowledge.discoveries) by[d.kind] = (by[d.kind] || 0) + 1;
  console.log(`${summary.counts.experiments} experiments, ${knowledge.discoveries.length} derived statements`, by, `| gaps: ${knowledge.gaps.map((g) => g.transform).join(', ') || 'none'} | defects: ${knowledge.defects.length}`);
}
