// every function of every MoonSec V3 program, decompiled on its own: which fail, why, and the smallest example of each reason
const [Q, dir, outFile] = process.argv.slice(2);
const fs = await import('node:fs');
const { parseChunk, disassemble } = await import(Q + '/src/sandbox/bytecode.js');
const { decompileFunction, Unstructured } = await import(Q + '/src/decompile/decompile.js');
const res = [];
const walk = (p, f, path) => {
  try { decompileFunction(p, { depth: 0, upNames: [], envUps: [], version: 0x51, noNested: true }); }
  catch (e) { res.push({ f, path, n: p.code.length, reason: String(e.message), kind: e.constructor.name }); }
  (p.protos || p.p || []).forEach((q, i) => walk(q, f, `${path}/${i}`));
};
for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.luac'))) {
  let ch; try { ch = parseChunk(fs.readFileSync(`${dir}/${f}`, 'latin1')); } catch { continue; }
  walk(ch.main, f, 'main');
}
fs.writeFileSync(outFile, JSON.stringify(res));
const by = {};
for (const r of res) { const k = r.reason.replace(/\d+/g, 'N'); (by[k] = by[k] || []).push(r); }
for (const [k, v] of Object.entries(by)) { v.sort((a, b) => a.n - b.n); console.log(v.length, k, '| smallest:', v[0].f, v[0].path, v[0].n); }
