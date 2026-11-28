// Prompt XXXI re-measurement of the MoonSec V3 tables (the same rebuilt chunks in $S/ms-bc, engine output unchanged since XXIX) with the
// decompiler as the product now calls it for this adapter (dialect from src/pipeline/engines.js: Luau, so `continue` may be written).
// JSON lines: {kind:'batch', file, failures, shared, continues, parses} and {kind:'behaviour', f, cat, ...}.
const [Q, S, which] = process.argv.slice(2);
const fs = await import('node:fs');
const { parseChunk } = await import(Q + '/src/sandbox/bytecode.js');
const { decompile } = await import(Q + '/src/decompile/decompile.js');
const { print } = await import(Q + '/src/core/printer.js');
const { parse } = await import(Q + '/src/core/parser.js');
const { verifyRecovery } = await import(Q + '/src/adaptive/verify.js');
const { ADAPTERS } = await import(Q + '/src/pipeline/engines.js');
const { sharedSubtrees } = await import(Q + '/tests/helpers/decompile-props.mjs');
const VOPTS = ADAPTERS.find((a) => a.id === 'moonsec-v3').verify;
const data = JSON.parse(fs.readFileSync(Q + '/data/research/xxix-engines.json', 'utf8')).moonsec_v3;
const norm = (e) => String(e || '').replace(/\btrace:\d+:\s*/g, '').replace(/\s*\((?:local|global|field|upvalue|method|constant) '[^']*'\)/g, '');
const DIALECT = ADAPTERS.find((a) => a.id === 'moonsec-v3').dialect;
const dec = (f) => { const d = decompile(parseChunk(fs.readFileSync(`${S}/ms-bc/${f.replace(/\//g, '_')}.luac`, 'latin1')), { dialect: DIALECT }); return { d, text: print(d.ast) }; };
if (which === 'batch') {
  for (const b of data.batch) {
    if (b.stage !== 'done') { console.log(JSON.stringify({ kind: 'batch', file: b.file, stage: b.stage })); continue; }
    try {
      const { d, text } = dec(b.file);
      let parses = true; try { parse(text); } catch { parses = false; }
      console.log(JSON.stringify({ kind: 'batch', file: b.file, stage: 'done', failures: d.failures.length, shared: sharedSubtrees(d.ast), continues: (text.match(/\bcontinue\b/g) || []).length, parses, before: { failures: b.failures, parses: b.parses } }));
    } catch (e) { console.log(JSON.stringify({ kind: 'batch', file: b.file, stage: 'decompile', error: String(e.message).slice(0, 120) })); }
  }
} else {
  const before = new Map(data.differences.map((x) => [x.f, x.cat]));
  for (const bh of data.behaviour) {
    const f = bh.f;
    try {
      const { d, text } = dec(f);
      const v = verifyRecovery(fs.readFileSync(Q + '/' + f, 'latin1'), text, { fuel: 40e6, timeMs: 15000, ...VOPTS });
      let cat = v.verdict === 'inconclusive' && v.reference === 'none' ? 'no-reference' : v.verdict;
      if (v.verdict === 'different') {
        const df = v.difference;
        if (df.index === -1 && /^error: /.test(df.original) && /^error: /.test(df.recovered)) cat = norm(df.original) === norm(df.recovered) ? 'same-error-other-name' : 'other-error';
        else if (df.index === -1) cat = 'end-state:' + df.original.split(':')[0];
        else cat = 'event';
      }
      console.log(JSON.stringify({ kind: 'behaviour', f, cat, notes: v.notes, before: before.get(f.slice(-21)) || bh.verdict, failures: d.failures.length, cov: v.coverage && v.coverage.ratio, ev: [v.original.events, v.recovered.events], d: v.difference && [v.difference.original.slice(0, 90), v.difference.recovered.slice(0, 90)] }));
    } catch (e) { console.log(JSON.stringify({ kind: 'behaviour', f, cat: 'error', error: String(e.message).slice(0, 120) })); }
  }
}
