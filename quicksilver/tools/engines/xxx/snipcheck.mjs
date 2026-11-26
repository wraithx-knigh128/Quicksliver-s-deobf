// run the named snippets through a given src tree (old or new) and report per runtime/strip: decompiled? same behaviour?
const [Q, DQ, ...names] = process.argv.slice(2);
const oracle = await import(Q + '/tests/helpers/lua-oracle.mjs');
const { quoteString, print } = await import(DQ + '/src/core/printer.js');
const { parseChunk, dumpChunk51 } = await import(DQ + '/src/sandbox/bytecode.js');
const { decompile } = await import(DQ + '/src/decompile/decompile.js');
const { SNIPPETS, SNIPPETS_51 } = await import(Q + "/tests/corpus/decompile/snippets.mjs"); Object.assign(SNIPPETS, SNIPPETS_51);
const hex = (h) => h.replace(/../g, (x) => String.fromCharCode(parseInt(x, 16)));
for (const name of names) {
  const src = SNIPPETS[name] || (await import("node:fs")).readFileSync(name, "latin1");
  for (const runtime of ['lua51', 'lua54']) for (const strip of [false, true]) {
    const loader = runtime === 'lua51' ? 'loadstring' : 'load';
    const r = await oracle.runLua(`local f = assert(${loader}(${quoteString(src)}))\nlocal d = string.dump(f${strip && runtime !== 'lua51' ? ', true' : ''})\nprint((d:gsub('.', function(c) return string.format('%02x', c:byte()) end)))`, runtime);
    let bin = hex(r.stdout.trim());
    if (strip && runtime === 'lua51') bin = dumpChunk51(parseChunk(bin), { strip: true });
    let d; try { d = decompile(parseChunk(bin)); } catch (e) { console.log(name, runtime, strip, 'THROW', e.message); continue; }
    const text = print(d.ast, {});
    const [a, b] = [await oracle.runLua(src, runtime), await oracle.runLua(text, runtime)];
    console.log(name.padEnd(20), runtime, strip ? 'strip' : 'debug', d.failures.length ? 'UNDECOMPILED ' + d.failures[0] : (a.stdout === b.stdout ? 'same' : 'DIFFERENT'));
  }
}
oracle.stopOracle();
