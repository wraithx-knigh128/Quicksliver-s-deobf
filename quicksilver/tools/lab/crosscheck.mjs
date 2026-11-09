// Lab: how well does QuickSilver's own interpreter agree with the reference runtimes?
//
//   node tools/lab/crosscheck.mjs [--seeds 64] [--first 1] [--out data/research]
//
// Every generated program and every transformation of it is run on the sandbox and on each reference runtime. Where the 5.1-family runtimes (PUC 5.1,
// LuaJIT) and the sandbox disagree, one of them is wrong about the program, or the program depends on something the language leaves undefined. Each
// disagreement is written down with the program, the transformation and the runtimes. Lua 5.2-5.4 are compared too, but their differences from
// 5.1 (integer and float printing, `unpack`, `loadstring`) are expected and are reported as a separate column, not as disagreements.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { generateProgram } from './generate.mjs';
import { TRANSFORMS } from './transforms.mjs';
import { sandboxRun } from './behaviour.mjs';
import { oracle, stopOracle } from '../runtime/oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));

export async function crosscheck({ seeds = 64, first = 1 } = {}) {
  const o = oracle();
  const found = (await o.detect()).filter((r) => r.available && r.id !== 'luau');
  const family51 = found.filter((r) => r.family === 'lua5.1').map((r) => r.id);
  const other = found.filter((r) => r.family !== 'lua5.1').map((r) => r.id);
  const rows = [];
  const disagreements = [];
  const diverge = Object.fromEntries(other.map((id) => [id, 0]));
  let runs = 0;
  for (let s = first; s < first + seeds; s++) {
    const p = generateProgram(s);
    const texts = [['original', p.source], ...TRANSFORMS.map((t) => [t.id, t.apply(p.source, s)])];
    for (const [what, text] of texts) {
      const sb = sandboxRun(text);
      const ref = {};
      for (const id of [...family51, ...other]) { const r = await o.run(id, text, { timeoutMs: 20_000 }); ref[id] = { ok: r.ok, output: r.stdout, error: r.error }; }
      runs++;
      const base = ref[family51[0]];
      const differing = [];
      if (sb.ok !== base.ok || sb.output !== base.output) differing.push('sandbox');
      for (const id of family51.slice(1)) if (ref[id].ok !== base.ok || ref[id].output !== base.output) differing.push(id);
      for (const id of other) if (ref[id].ok !== base.ok || ref[id].output !== base.output) diverge[id]++;
      if (differing.length) disagreements.push({ program: s, text: what, reference: family51[0], differing, expected: base.output.slice(0, 120), error: base.error });
    }
  }
  rows.push({ runtimes: found.map((r) => ({ id: r.id, version: r.version })), family51, other });
  return { schema: 1, programs: seeds, first, runs, ...rows[0], disagreements5_1Family: disagreements, differFrom51: diverge,
    note: 'disagreements5_1Family lists runs where the sandbox or another 5.1-family runtime printed something other than PUC Lua 5.1 did. differFrom51 counts runs where a newer Lua differed from 5.1, which is expected (number formatting, removed functions) and says nothing about the sandbox.' };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const argv = process.argv.slice(2);
  const n = (f, d) => (argv.includes(f) ? Number(argv[argv.indexOf(f) + 1]) : d);
  const out = argv.includes('--out') ? path.resolve(argv[argv.indexOf('--out') + 1]) : path.join(here, '..', '..', 'data', 'research');
  const result = await crosscheck({ seeds: n('--seeds', 64), first: n('--first', 1) });
  stopOracle();
  fs.mkdirSync(out, { recursive: true });
  fs.writeFileSync(path.join(out, 'crosscheck.json'), JSON.stringify(result, null, 1) + '\n');
  console.log(`${result.runs} runs on ${result.runtimes.map((r) => r.id).join(', ')} + sandbox`);
  console.log(`disagreements inside the 5.1 family: ${result.disagreements5_1Family.length}`);
  for (const d of result.disagreements5_1Family.slice(0, 8)) console.log(' ', d.program, d.text, d.differing.join(','));
  console.log('newer Lua differs from 5.1 in:', result.differFrom51);
}
