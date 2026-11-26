// would a behaviour check against the INPUT (what a real user has) accept Prometheus-Fixed's good outputs and reject its wrong ones?
const [Q, S] = process.argv.slice(2);
const fs = await import('node:fs');
const { verifyRecovery } = await import(Q + '/src/adaptive/verify.js');
const pf = fs.readFileSync(`${S}/pmf-results.jsonl`, 'utf8').trim().split('\n').map((l) => JSON.parse(l));
for (const r of pf) {
  const t = r.tool; if (t.status !== 0 || !t.parses) continue;
  const c = r.cfg || ''; if (!(c.includes('Vmify') || c === 'Medium' || c === 'Strong')) continue;
  const truth = t.behaviour.verdict === 'identical' && !(t.left || []).length ? 'clean' : t.behaviour.verdict === 'different' ? 'WRONG' : 'other';
  const out = fs.readFileSync(`${S}/pmf-out/${r.f.replace(/\//g, '_')}.out`, 'latin1');
  const v = verifyRecovery(fs.readFileSync(`${Q}/${r.f}`, 'latin1'), out, { fuel: 200e6, timeMs: 30000 });
  const cov = v.coverage ? v.coverage.ratio : null;
  const accept = v.verdict === 'identical' && cov != null && cov >= 0.5;
  console.log(JSON.stringify({ f: r.f.split('/').slice(-2).join('/'), truth, gate: v.verdict, cov: cov && Math.round(cov * 100) / 100, accept }));
}
