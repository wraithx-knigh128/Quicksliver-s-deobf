// `if E then x = E` in the decompiled MoonSec V3 programs: the condition and the assigned value are one node (KNOWN-ISSUES #114). Counts the
// sites and what E is (a field read runs __index twice; a local can be read twice without effect). DIALECT=luau decompiles as the
// MoonSec adapter now asks (src/pipeline/engines.js).
const [D, dir] = process.argv.slice(2);
const fs = await import('node:fs');
const { parseChunk } = await import(D + '/src/sandbox/bytecode.js');
const { decompile } = await import(D + '/src/decompile/decompile.js');
const { walk } = await import(D + '/src/core/walk.js');
let files = 0, hits = 0;
const kinds = {};
for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.luac'))) {
  let d;
  try { d = decompile(parseChunk(fs.readFileSync(`${dir}/${f}`, 'latin1')), process.env.DIALECT ? { dialect: process.env.DIALECT } : {}); } catch { continue; }
  let here = 0;
  walk(d.ast, (n) => {
    if (n.type !== 'If' || n.clauses.length !== 1) return;
    const c = n.clauses[0];
    const st = c.body[0];
    if (!st || st.type !== 'Assign' || st.values.length !== 1) return;
    const v = st.values[0];
    if (!(c.cond === v || (c.cond.type === 'Unary' && c.cond.op === 'not' && c.cond.arg === v))) return;
    here++;
    kinds[v.type] = (kinds[v.type] || 0) + 1;
  });
  if (here) { files++; hits += here; }
}
console.log(JSON.stringify({ files, sites: hits, kinds }));
