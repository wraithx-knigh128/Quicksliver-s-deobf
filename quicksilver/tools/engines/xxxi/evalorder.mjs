// The #114 property (tests/xxxi-evaluation-order.test.mjs) through a given decompiler, counted rather than asserted: per seed, how many
// programs read and call exactly what the original does, in its order; how many differ; how many share a subtree; how many are left undecompiled.
const [Q, D] = process.argv.slice(2); // Q: this checkout (oracle, harness); D: the source tree whose decompiler is measured
const oracle = await import(Q + '/tests/helpers/lua-oracle.mjs');
const { parseChunk, dumpChunk51 } = await import(Q + '/src/sandbox/bytecode.js');
const { decompile } = await import(D + '/src/decompile/decompile.js');
const { print, quoteString } = await import(Q + '/src/core/printer.js');
const { rng, evaluationCase, evaluationHarness, sharedSubtrees } = await import(Q + '/tests/helpers/decompile-props.mjs');
for (const [seed, strip] of [[3, true], [3, false], [17, true], [17, false]]) {
  const lcg = rng(seed); const rnd = (k) => Math.floor((lcg(2 ** 30) / 2 ** 30) * k);
  const t = { same: 0, different: 0, shared: 0, undecompiled: 0 };
  for (let n = 0; n < 120; n++) {
    const src = evaluationCase(rnd);
    const r = await oracle.runLua(`local f = assert(loadstring(${quoteString(src)}))\nlocal d = string.dump(f)\nprint((d:gsub('.', function(c) return string.format('%02x', c:byte()) end)))`, 'lua51');
    const bc = r.stdout.trim().replace(/../g, (h) => String.fromCharCode(parseInt(h, 16)));
    const d = decompile(parseChunk(strip ? dumpChunk51(parseChunk(bc), { strip: true }) : bc));
    if (sharedSubtrees(d.ast)) t.shared++;
    if (d.failures.length) { t.undecompiled++; continue; }
    const text = print(d.ast);
    const [a, b] = [await oracle.runLua(evaluationHarness(quoteString(src)), 'lua51'), await oracle.runLua(evaluationHarness(quoteString(text)), 'lua51')];
    if (a.ok && b.ok && a.stdout === b.stdout) t.same++; else t.different++;
  }
  console.log(`seed ${seed} ${strip ? 'stripped' : 'debug'}: ${JSON.stringify(t)}`);
}
oracle.stopOracle();
