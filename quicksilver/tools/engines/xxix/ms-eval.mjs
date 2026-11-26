const [Q, f, out, st, ms, errf] = process.argv.slice(2);
const fs = await import('node:fs');
const r = { file: f, status: Number(st), ms: Number(ms) };
if (Number(st) !== 0 || !fs.existsSync(out)) { r.stage = 'tool'; r.error = fs.existsSync(errf) ? fs.readFileSync(errf, 'utf8').trim().split('\n').slice(-1)[0].slice(0, 160) : ''; console.log(JSON.stringify(r)); process.exit(0); }
try {
  const { parseChunk } = await import(Q + '/src/sandbox/bytecode.js');
  const { decompile } = await import(Q + '/src/decompile/decompile.js');
  const { print } = await import(Q + '/src/core/printer.js');
  const { parse } = await import(Q + '/src/core/parser.js');
  const bin = fs.readFileSync(out, 'latin1');
  r.bytes = bin.length;
  const chunk = parseChunk(bin);
  const d = decompile(chunk);
  const text = print(d.ast);
  r.failures = d.failures.length;
  r.lines = text.split('\n').length;
  try { parse(text); r.parses = true; } catch (e) { r.parses = false; r.parseError = e.message.slice(0, 120); }
  r.stage = 'done';
} catch (e) { r.stage = 'decompile'; r.error = String(e.message || e).slice(0, 160); }
console.log(JSON.stringify(r));
