const [Q, DQ] = process.argv.slice(2);
const oracle = await import(Q + '/tests/helpers/lua-oracle.mjs');
const H = await import(Q + '/tests/helpers/decompile-props.mjs');
const { quoteString, print } = await import(DQ + '/src/core/printer.js');
const { parseChunk, dumpChunk51 } = await import(DQ + '/src/sandbox/bytecode.js');
const { decompile } = await import(DQ + '/src/decompile/decompile.js');
for (const [kind, seed, count] of [['expression', 11, 200], ['expression', 7, 200], ['statement', 5, 120], ['statement', 23, 120], ['statement', 41, 120]]) {
  const rnd = H.rng(seed); let same = 0, diff = 0, und = 0;
  for (let n = 0; n < count; n++) {
    const src = kind === 'expression' ? H.expressionCase(rnd) : H.statementCase(rnd);
    const r = await oracle.runLua(`local f = assert(loadstring(${quoteString(src)}))\nlocal d = string.dump(f)\nprint((d:gsub('.', function(c) return string.format('%02x', c:byte()) end)))`, 'lua51');
    const bin = dumpChunk51(parseChunk(r.stdout.trim().replace(/../g, (h) => String.fromCharCode(parseInt(h, 16)))), { strip: true });
    let d; try { d = decompile(parseChunk(bin)); } catch (e) { und++; continue; }
    if (d.failures.length) { und++; continue; }
    const text = print(d.ast); const hz = kind === 'expression' ? H.expressionHarness : H.statementHarness;
    const [a, b] = [await oracle.runLua(hz(quoteString(src)), 'lua51'), await oracle.runLua(hz(quoteString(text)), 'lua51')];
    if (a.ok && b.ok && a.stdout === b.stdout) same++; else diff++;
  }
  console.log(kind, seed, count, JSON.stringify({ same, diff, und }));
}
oracle.stopOracle();
