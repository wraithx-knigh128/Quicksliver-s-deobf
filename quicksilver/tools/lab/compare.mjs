// Lab: evaluate a technique by comparing two runs of the same experiments on two revisions of the engine.
//
//   node tools/lab/compare.mjs base.jsonl current.jsonl --label functions.lift --note "..." [--out data/research/evaluations]
//
// Experiments are matched on (program, transformation, plan). The report counts, per cell, the verified successes before and after, lists every experiment
// whose verdict got worse (a regression is as much a result as an improvement), and records both revisions so that the numbers can be reproduced.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readExperiments } from './store.mjs';
import { isSuccess } from '../../src/research/judge.js';

const key = (r) => `${r.program.seed}|${r.transform.id}|${r.plan.id}`;
const rank = { 'verified-recovery': 3, 'verified-partial': 2, 'behaviour-kept-no-gain': 1, 'behaviour-kept-worse': 0, inconclusive: 0, 'failed-behaviour': -1, 'failed-parse': -1, error: -1, 'tool-broken': -2 };

export function compare(base, current, { label, note = '' }) {
  const before = new Map(base.map((r) => [key(r), r]));
  const cells = new Map();
  const regressions = [];
  let improved = 0;
  let regressed = 0;
  let matched = 0;
  for (const r of current) {
    const b = before.get(key(r));
    if (!b || b.verdict === 'tool-broken' || r.verdict === 'tool-broken') continue;
    matched++;
    const id = `${r.transform.id}|${r.plan.id}`;
    const c = cells.get(id) || { transform: r.transform.id, plan: r.plan.id, n: 0, baseSuccess: 0, currentSuccess: 0, baseRecovery: 0, currentRecovery: 0, baseWorse: 0, currentWorse: 0 };
    c.n++;
    if (isSuccess(b.verdict)) c.baseSuccess++;
    if (b.verdict === 'verified-recovery') c.baseRecovery++;
    if (r.verdict === 'verified-recovery') c.currentRecovery++;
    if (isSuccess(r.verdict)) c.currentSuccess++;
    if (b.verdict === 'behaviour-kept-worse') c.baseWorse++;
    if (r.verdict === 'behaviour-kept-worse') c.currentWorse++;
    cells.set(id, c);
    if (rank[r.verdict] > rank[b.verdict]) improved++;
    if (rank[r.verdict] < rank[b.verdict]) { regressed++; regressions.push({ id: r.id, program: r.program.seed, transform: r.transform.id, plan: r.plan.id, from: b.verdict, to: r.verdict }); }
  }
  const list = [...cells.values()].sort((a, b) => a.transform.localeCompare(b.transform) || a.plan.localeCompare(b.plan));
  return {
    schema: 1, label, note, matched,
    base: { rev: base[0] && base[0].env.rev, experiments: base.length },
    current: { rev: current[0] && current[0].env.rev, experiments: current.length },
    improvedExperiments: improved, regressedExperiments: regressed,
    cellsImproved: list.filter((c) => c.currentSuccess > c.baseSuccess || c.currentRecovery > c.baseRecovery), cellsRegressed: list.filter((c) => c.currentSuccess < c.baseSuccess || c.currentWorse > c.baseWorse),
    regressions: regressions.slice(0, 40),
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const argv = process.argv.slice(2);
  const flag = (f, d) => (argv.includes(f) ? argv[argv.indexOf(f) + 1] : d);
  const [basePath, curPath] = argv.filter((a) => a.endsWith('.jsonl'));
  const label = flag('--label', 'unnamed');
  const out = path.resolve(flag('--out', path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'data', 'research', 'evaluations')));
  const report = compare(readExperiments(basePath), readExperiments(curPath), { label, note: flag('--note', '') });
  fs.mkdirSync(out, { recursive: true });
  fs.writeFileSync(path.join(out, `${label}.json`), JSON.stringify(report, null, 1) + '\n');
  console.log(`${label}: ${report.matched} matched; improved ${report.improvedExperiments}, regressed ${report.regressedExperiments}`);
  for (const c of report.cellsImproved) console.log('  +', c.transform.padEnd(36), c.plan.padEnd(17), `success ${c.baseSuccess}/${c.n} -> ${c.currentSuccess}/${c.n}, near-original ${c.baseRecovery} -> ${c.currentRecovery}`);
  for (const c of report.cellsRegressed) console.log('  -', c.transform.padEnd(36), c.plan.padEnd(17), `${c.baseSuccess}/${c.n} -> ${c.currentSuccess}/${c.n} (worse ${c.baseWorse} -> ${c.currentWorse})`);
}
