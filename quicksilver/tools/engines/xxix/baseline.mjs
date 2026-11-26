// QuickSilver alone vs QuickSilver + gated engine, scored the same way: reference = the original, or the protected script where the
// protected build itself behaves differently from the original in the sandbox (Prometheus' own miscompile)
const [Q, S] = process.argv.slice(2);
const fs = await import('node:fs');
const { recoverSource } = await import(Q + '/src/api.js');
const { verifyRecovery } = await import(Q + '/src/adaptive/verify.js');
const { detect } = await import(Q + '/src/detect/detect.js');
const limits = { fuel: 200e6, timeMs: 30000 };
const body = (t) => (t.includes('-- (end of report)\n') ? t.split('-- (end of report)\n')[1] : t);
const pairs = new Map(fs.readFileSync(`${S}/pm-pairs.tsv`, 'utf8').trim().split('\n').map((l) => { const [o, r] = l.split('\t'); return [o, r]; }));
const score = (ref, out) => { if (out == null) return 'no output'; const v = verifyRecovery(ref, out, limits); const left = (detect(out).families || []).some((f) => f.confidence >= 0.5); return v.verdict === 'identical' ? (left ? 'right, protection left' : 'right, nothing left') : v.verdict === 'different' ? 'WRONG' : 'inconclusive'; };
for (const line of fs.readFileSync(`${S}/integ.jsonl`, 'utf8').trim().split('\n')) {
  const r = JSON.parse(line);
  const input = fs.readFileSync(`${Q}/${r.f}`, 'latin1');
  const original = fs.readFileSync(`${Q}/${pairs.get(r.f)}`, 'latin1');
  const diverges = verifyRecovery(original, input, limits).verdict !== 'identical';
  const ref = diverges ? input : original;
  const own = recoverSource(input, { nexus: true });
  const ownClass = score(ref, own.output != null ? body(own.output) : null);
  // the integrated result: re-score only when the reference changed
  let integ = r.truth ? (r.truth.verdict === 'identical' ? (r.truth.left.length ? 'right, protection left' : 'right, nothing left') : r.truth.verdict === 'different' ? 'WRONG' : 'inconclusive') : 'no output';
  if (diverges !== r.diverged) integ = null;
  console.log(JSON.stringify({ f: r.f, cfg: r.cfg, diverges, own: ownClass, ownOutcome: own.outcome && own.outcome.outcome, integ, integOutcome: r.outcome, engine: !!r.engine }));
}
