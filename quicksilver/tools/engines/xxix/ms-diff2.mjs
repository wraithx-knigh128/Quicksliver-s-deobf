const [Q, list] = process.argv.slice(2);
const fs = await import('node:fs');
const { parseChunk } = await import(Q + '/src/sandbox/bytecode.js');
const { decompile } = await import(Q + '/src/decompile/decompile.js');
const { print } = await import(Q + '/src/core/printer.js');
const { verifyRecovery } = await import(Q + '/src/adaptive/verify.js');
const norm = (e) => String(e || '').replace(/\btrace:\d+:\s*/g, '').replace(/\s*\((?:local|global|field|upvalue|method|constant) '[^']*'\)/g, '');
for (const f of fs.readFileSync(list, 'utf8').trim().split('\n')) {
  const id = f.replace(/\//g, '_');
  const text = print(decompile(parseChunk(fs.readFileSync(`${process.env.S}/ms-bc/${id}.luac`, 'latin1'))).ast);
  const v = verifyRecovery(fs.readFileSync(Q + '/' + f, 'latin1'), text, { fuel: 40e6, timeMs: 15000, originalPrelude: ['wait()'], needsMainReference: true });
  let cat = v.verdict;
  if (v.verdict === 'different') {
    const d = v.difference;
    if (d.index === -1 && /^error: /.test(d.original) && /^error: /.test(d.recovered)) cat = norm(d.original) === norm(d.recovered) ? 'same-error-other-name' : 'other-error';
    else if (d.index === -1) cat = 'end-state:' + d.original.split(':')[0];
    else cat = 'event';
  }
  console.log(JSON.stringify({ f: f.slice(-21), cat, cov: v.coverage && v.coverage.ratio, ev: [v.original.events, v.recovered.events], d: v.difference && [v.difference.original.slice(0, 100), v.difference.recovered.slice(0, 100)] }));
}
