// Reproduction check: does a fresh run of the real-tool scorecard agree with a committed one?
//
//   node tools/research/compare-scorecards.mjs tests/results/scorecard.json tests/results/scorecard-rerun.json [out.json]
//
// Fixtures are matched on (tool, config, sample). Reported separately: fixtures present in only one run (outputs of tools whose licence keeps them out of the
// repository are absent on a machine that did not generate them), verdicts that changed (behaviour of the recovered code, behaviour of the obfuscated
// original), and things that moved because the engine moved (fidelity, output size, step lists).

import fs from 'node:fs';

export function compareScorecards(committed, rerun) {
  const key = (r) => `${r.tool}|${r.config}|${r.sample}`;
  const A = new Map(committed.results.map((r) => [key(r), r]));
  const B = new Map(rerun.results.map((r) => [key(r), r]));
  const onlyCommitted = [...A.keys()].filter((k) => !B.has(k));
  const onlyRerun = [...B.keys()].filter((k) => !A.has(k));
  const both = [...A.keys()].filter((k) => B.has(k));
  const verdicts = { behavior: [], behaviorOriginal: [], toolBehavior: [], ok: [] };
  const moved = { fidelityAfter: [], outputBytes: 0, steps: 0 };
  for (const k of both) {
    const x = A.get(k);
    const y = B.get(k);
    for (const f of Object.keys(verdicts)) if (x[f] !== y[f]) verdicts[f].push({ fixture: k, committed: x[f] ?? null, rerun: y[f] ?? null });
    if (Math.abs((x.fidelityAfter ?? 0) - (y.fidelityAfter ?? 0)) > 0.01) moved.fidelityAfter.push({ fixture: k, committed: round(x.fidelityAfter), rerun: round(y.fidelityAfter) });
    if (x.outputBytes !== y.outputBytes) moved.outputBytes++;
    if (JSON.stringify(x.steps) !== JSON.stringify(y.steps)) moved.steps++;
  }
  const same = (rs) => rs.filter((r) => r.behavior === 'same').length;
  const byTool = {};
  for (const k of onlyCommitted) { const t = k.split('|')[0]; byTool[t] = (byTool[t] || 0) + 1; }
  return {
    schema: 1,
    committed: { generatedAt: committed.generatedAt, fixtures: committed.results.length },
    rerun: { generatedAt: rerun.generatedAt, fixtures: rerun.results.length },
    compared: both.length,
    onlyInCommitted: { count: onlyCommitted.length, byTool, why: 'generated locally from tools whose licence keeps their output out of the repository (tests/corpus/obfuscated-local); not present on the machine that did the rerun' },
    onlyInRerun: onlyRerun.length,
    verdictChanges: Object.fromEntries(Object.entries(verdicts).map(([f, list]) => [f, { count: list.length, items: list.slice(0, 20) }])),
    movedWithTheEngine: { fidelityAfter: { count: moved.fidelityAfter.length, items: moved.fidelityAfter.slice(0, 20) }, outputBytes: moved.outputBytes, steps: moved.steps },
    recoveredBehaviourSame: { committedOnTheseFixtures: same(both.map((k) => A.get(k))), rerunOnTheseFixtures: same(both.map((k) => B.get(k))) },
  };
}
const round = (x) => (typeof x === 'number' ? Math.round(x * 1000) / 1000 : x);

if (process.argv[1] && process.argv[1].endsWith('compare-scorecards.mjs')) {
  const [a, b, out] = process.argv.slice(2);
  const rep = compareScorecards(JSON.parse(fs.readFileSync(a, 'utf8')), JSON.parse(fs.readFileSync(b, 'utf8')));
  if (out) { fs.mkdirSync(new URL(`file://${out}/..`).pathname, { recursive: true }); fs.writeFileSync(out, JSON.stringify(rep, null, 1) + '\n'); }
  console.log(JSON.stringify({ compared: rep.compared, onlyInCommitted: rep.onlyInCommitted.count, byTool: rep.onlyInCommitted.byTool, verdictChanges: Object.fromEntries(Object.entries(rep.verdictChanges).map(([k, v]) => [k, v.count])), moved: { fidelityAfter: rep.movedWithTheEngine.fidelityAfter.count, outputBytes: rep.movedWithTheEngine.outputBytes, steps: rep.movedWithTheEngine.steps }, recoveredBehaviourSame: rep.recoveredBehaviourSame }, null, 1));
  for (const v of rep.verdictChanges.behaviorOriginal.items) console.log('  behaviorOriginal', v.fixture, v.committed, '->', v.rerun);
}
