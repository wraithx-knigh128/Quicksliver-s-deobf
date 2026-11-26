const [Q, listFile] = process.argv.slice(2);
const fs = await import('node:fs');
const { recoverSource } = await import(Q + '/src/api.js');
for (const f of fs.readFileSync(listFile, 'utf8').trim().split('\n')) {
  const t0 = Date.now();
  try {
    const r = recoverSource(fs.readFileSync(Q + '/' + f, 'latin1'), { nexus: true });
    const ev = (r.outcome && r.outcome.evidence && r.outcome.evidence.recovery) || {};
    console.log(JSON.stringify({ f, outcome: r.outcome && r.outcome.outcome, level: r.confidence && r.confidence.level, vm: r.vm ? `${r.vm.kind}:${r.vm.lifted}` : null, residual: (ev.residual || []).slice(0, 3), unresolved: ev.unresolved, ms: Date.now() - t0 }));
  } catch (e) { console.log(JSON.stringify({ f, error: String(e.message).slice(0, 120) })); }
}
