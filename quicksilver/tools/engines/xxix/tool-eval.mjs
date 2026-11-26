// score one tool's outputs on the Prometheus pairs: parses? obfuscation left? behaviour next to the original (QuickSilver's sandbox)
const [Q, S, runsName, outDir] = process.argv.slice(2);
const fs = await import('node:fs');
const { parse } = await import(Q + '/src/core/parser.js');
const { detect } = await import(Q + '/src/detect/detect.js');
const { verifyRecovery } = await import(Q + '/src/adaptive/verify.js');
const runs = new Map(fs.readFileSync(`${S}/${runsName}`, 'utf8').trim().split('\n').map((l) => { const [f, st, ms] = l.split('\t'); return [f, { st: Number(st), ms: Number(ms) }]; }));
const parses = (t) => { try { parse(t); return true; } catch { return false; } };
const left = (t) => { try { const d = detect(t); return (d.families || []).filter((f) => f.confidence >= 0.5).map((f) => f.id).concat((d.traits || []).filter((x) => ['vm', 'state-machine', 'string-table'].includes(x.id)).map((x) => 'trait:' + x.id)); } catch { return ['detect-error']; } };
const judge = (orig, out) => { try { const v = verifyRecovery(orig, out, { fuel: 40e6, timeMs: 15000 }); return { verdict: v.verdict, coverage: v.coverage ? Math.round(v.coverage.ratio * 1000) / 1000 : null, events: [v.original.events, v.recovered.events], diff: v.difference ? [String(v.difference.original).slice(0, 80), String(v.difference.recovered).slice(0, 80)] : null }; } catch (e) { return { verdict: 'error', error: String(e.message).slice(0, 100) }; } };
for (const line of fs.readFileSync(`${S}/pm-pairs.tsv`, 'utf8').trim().split('\n')) {
  const [obf, orig, set, cfg] = line.split('\t');
  const original = fs.readFileSync(`${Q}/${orig}`, 'latin1');
  const run = runs.get(obf) || {};
  const base = `${S}/${outDir}/${obf.replace(/\//g, '_')}`;
  const r = { f: obf, set, cfg, tool: { status: run.st, ms: run.ms } };
  if (run.st === 0 && fs.existsSync(base + '.out') && fs.statSync(base + '.out').size > 0) {
    const t = fs.readFileSync(base + '.out', 'latin1');
    r.tool.bytes = t.length; r.tool.parses = parses(t); r.tool.left = left(t);
    if (r.tool.parses) r.tool.behaviour = judge(original, t);
  } else r.tool.error = (fs.existsSync(base + '.err') ? fs.readFileSync(base + '.err', 'utf8') : '').trim().split('\n').slice(-1)[0].slice(0, 160);
  console.log(JSON.stringify(r));
}
