// the one Deobfuscate, as the site runs it, on QuickSilver's Prometheus fixtures — with the server engines (isolated) and the gate
const [Q, S] = process.argv.slice(2);
const fs = await import('node:fs');
const path = await import('node:path');
const { deobfuscate } = await import(Q + '/src/pipeline/unified.js');
const { analyzeLoader } = await import(Q + '/src/loader/analyze.js');
const { decodePayload } = await import(Q + '/src/loader/payload.js');
const { detect } = await import(Q + '/src/detect/detect.js');
const api = await import(Q + '/src/api.js');
const { verifyRecovery } = await import(Q + '/src/adaptive/verify.js');
const { runEngine } = await import(Q + '/api/_lib/isolate.js');
const { ENGINES } = await import(Q + '/api/engine.js');
const enc = (s) => Uint8Array.from([...s].map((c) => c.charCodeAt(0) & 255));
const body = (t) => (t.includes('-- (end of report)\n') ? t.split('-- (end of report)\n')[1] : t);
const behaviourOf = {};
for (const m of [...['prometheus', 'prometheus-2026-11', 'prometheus-seeds'].map((d) => `${Q}/tests/corpus/obfuscated/${d}/manifest.json`), ...fs.readdirSync(`${Q}/tests/corpus/obfuscated/prometheus-nested`).filter((d) => d.startsWith('seed-')).map((d) => `${Q}/tests/corpus/obfuscated/prometheus-nested/${d}/manifest.json`)]) {
  const j = JSON.parse(fs.readFileSync(m, 'utf8')); const dir = path.relative(Q, path.dirname(m));
  for (const e of j.entries) behaviourOf[`${dir}/${e.file}`] = e.behavior || 'equivalent';
}
const limits = { fuel: 200e6, timeMs: 30000 };
const deps = {
  analyze: (s, o) => analyzeLoader(s, o), decode: (b, m) => decodePayload(b, m), detect: (t) => detect(t),
  recover: (t) => api.recoverSource(t, { nexus: true }), fetchLink: async () => ({ ok: false, status: 404, error: 'HTTP 404' }),
  verify: async (t, rec, o) => verifyRecovery(t, rec, { ...(o || {}), ...limits }),
  serverEngine: async (adapter, t) => {
    const e = ENGINES[adapter.id];
    const r = await runEngine({ engineDir: e.dir, driver: e.driver, modules: e.modules, input: Buffer.from(t, 'latin1'), timeoutS: 60 });
    if (!r.output) return { ok: false, outcome: r.timedOut ? 'timeout' : 'engine-failed', message: (r.stderr.match(/(?:prometheus|moonsec): (.*)/) || [])[1] || 'no result' };
    const bin = r.output.toString('latin1');
    return { ok: true, licence: e.licence, isolation: r.isolation, ms: r.ms, ...(e.output === 'lua-source' ? { source: bin } : { bytecode: bin }) };
  },
  fromSource: async (src, o) => api.recoverFromSource(src, o),
  fromBytecode: async (bc, o) => api.recoverFromBytecode(bc, o),
};
for (const line of fs.readFileSync(`${S}/pm-pairs.tsv`, 'utf8').trim().split('\n')) {
  const [obf, orig, set, cfg] = line.split('\t');
  const input = fs.readFileSync(`${Q}/${obf}`, 'latin1');
  const t0 = Date.now();
  const R = await deobfuscate({ text: input, name: path.basename(obf), bytes: enc(input) }, deps);
  const out = R.final && R.final.output != null ? body(R.final.output) : null;
  const diverged = behaviourOf[obf] && behaviourOf[obf] !== 'equivalent';
  const ref = diverged ? input : fs.readFileSync(`${Q}/${orig}`, 'latin1');
  let truth = null;
  if (out != null) { const v = verifyRecovery(ref, out, limits); const d = detect(out); const left = (d.families || []).filter((f) => f.confidence >= 0.5).map((f) => f.id); truth = { verdict: v.verdict, left }; }
  const eng = R.final && R.final.node && R.final.node.recovery && R.final.node.recovery.engine;
  console.log(JSON.stringify({ f: obf, set, cfg, diverged, outcome: R.verdict && R.verdict.outcome, engine: eng ? { id: eng.id, gate: eng.gate || null } : null, notes: R.notes.filter((n) => n.kind === 'engine').map((n) => n.text.slice(0, 140)), truth, ms: Date.now() - t0 }));
}
