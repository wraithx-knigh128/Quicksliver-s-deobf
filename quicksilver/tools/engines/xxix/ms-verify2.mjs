// behaviour of the MoonSec adapter's output vs the protected original, in QuickSilver's sandbox; one leading wait() of the original
// (MoonSec V3's own runtime) is not counted. Prints one JSON line per file.
const [Q, listFile] = process.argv.slice(2);
const fs = await import('node:fs');
const { parseChunk } = await import(Q + '/src/sandbox/bytecode.js');
const { decompile } = await import(Q + '/src/decompile/decompile.js');
const { print } = await import(Q + '/src/core/printer.js');
const { traceScript } = await import(Q + '/src/trace/trace.js');
const ev = (t) => t.events.filter((e) => e.kind !== 'load').map((e) => e.text.replace(/\btrace:\d+:\s*/g, ''));
for (const f of fs.readFileSync(listFile, 'utf8').trim().split('\n')) {
  const id = f.replace(/\//g, '_');
  const t0 = Date.now();
  try {
    const text = print(decompile(parseChunk(fs.readFileSync(`${process.env.S}/ms-bc/${id}.luac`, 'latin1'))).ast);
    const a = traceScript(fs.readFileSync(Q + '/' + f, 'latin1'), { fuel: 40e6, timeMs: 15000 });
    const b = traceScript(text, { fuel: 40e6, timeMs: 15000, coverage: true });
    let ea = ev(a); const eb = ev(b);
    const prelude = ea[0] === 'wait()' && eb[0] !== 'wait()';
    if (prelude) ea = ea.slice(1);
    const cut = (x) => x.status === 'limit' || /^stopped/.test(x.ended || '');
    const n = cut(a) || cut(b) ? Math.min(ea.length, eb.length) : Math.max(ea.length, eb.length);
    let diff = -1;
    for (let i = 0; i < n; i++) if (ea[i] !== eb[i]) { diff = i; break; }
    if (diff < 0 && !(cut(a) || cut(b)) && (a.output !== b.output || a.error !== b.error)) diff = -2;
    const noRef = ea.length > 0 && /^arg\d\(/.test(ea[0]);
    const verdict = noRef ? 'no-reference' : diff !== -1 ? 'different' : (cut(a) || cut(b)) ? 'inconclusive' : 'identical';
    console.log(JSON.stringify({ f, verdict, prelude, events: [ea.length, eb.length], coverage: b.coverage ? b.coverage.ratio : null, at: diff >= 0 ? [ea[diff], eb[diff]].map((x) => String(x).slice(0, 90)) : diff, ms: Date.now() - t0 }));
  } catch (e) { console.log(JSON.stringify({ f, verdict: 'error', error: String(e.message).slice(0, 120) })); }
}
