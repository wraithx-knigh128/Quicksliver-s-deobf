// Is the 3fed8cb5 difference only the tracer's wait budget? Trace the original with one more wait than the rebuilt program gets.
const [Q, S, name] = process.argv.slice(2);
const fs = await import('node:fs');
const { parseChunk } = await import(Q + '/src/sandbox/bytecode.js');
const { decompile } = await import(Q + '/src/decompile/decompile.js');
const { print } = await import(Q + '/src/core/printer.js');
const { traceScript } = await import(Q + '/src/trace/trace.js');
const f = `local/terrorlua/MoonSec/V3/${name}`;
const text = print(decompile(parseChunk(fs.readFileSync(`${S}/ms-bc/${f.replace(/\//g, '_')}.luac`, 'latin1'))).ast);
const ev = (t) => t.events.filter((e) => e.kind !== 'load').map((e) => e.text.replace(/\btrace:\d+:\s*/g, ''));
const cmp = (a, b) => { if (a[0] === 'wait()' && b[0] !== 'wait()') a = a.slice(1); let i = 0; while (i < Math.max(a.length, b.length) && a[i] === b[i]) i++; return { lenA: a.length, lenB: b.length, firstDiff: i === Math.max(a.length, b.length) ? 'none' : i }; };
const orig = fs.readFileSync(Q + '/' + f, 'latin1');
for (const [wa, wb] of [[400, 400], [401, 400], [200, 199], [50, 49]]) {
  const ta = traceScript(orig, { fuel: 40e6, timeMs: 20000, maxWaits: wa });
  const tb = traceScript(text, { fuel: 40e6, timeMs: 20000, maxWaits: wb });
  console.log(`original maxWaits ${wa} (used ${ta.stats.waits}), rebuilt ${wb} (used ${tb.stats.waits}):`, JSON.stringify(cmp(ev(ta), ev(tb))), ta.ended, '|', tb.ended);
}
