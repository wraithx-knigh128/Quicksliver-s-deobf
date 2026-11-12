// One stage of a layered (mixed) obfuscation chain, for tests/corpus/tools/gen_mixed.py:  node stage.mjs <loader|lab> <id> [seed] < in > out
//   loader <technique>   one of the packers of tests/corpus/tools/gen_loaders.mjs (written for this project)
//   lab <id> [seed]      one of the transformations of tools/lab/transforms.mjs (the laboratory's catalogue of known and custom patterns)
import fs from 'node:fs';
import { PACKERS } from '../../tests/corpus/tools/gen_loaders.mjs';
import { transformById } from '../lab/transforms.mjs';

const [kind, id, seed = '1'] = process.argv.slice(2);
const input = fs.readFileSync(0).toString('latin1');
let out;
if (kind === 'loader') {
  if (!PACKERS[id]) throw new Error(`no loader ${id}`);
  out = PACKERS[id].pack(input);
} else if (kind === 'lab') {
  const t = transformById(id);
  if (!t) throw new Error(`no transformation ${id}`);
  out = t.apply(input, Number(seed));
} else throw new Error(`unknown stage kind ${kind}`);
process.stdout.write(Buffer.from(out, 'latin1'));
