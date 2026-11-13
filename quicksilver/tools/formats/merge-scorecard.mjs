// Replace the rows of one tool in a scorecard with the rows of a filtered run, without re-running everything else.
//
//   node tests/tools-scorecard.mjs --filter zartha/ --write --out part.json           (rows of that tool only, fresh)
//   node tools/formats/merge-scorecard.mjs scorecard.json part.json zartha
//
// Every row is measured on its own fixture, so a row from a filtered run is the row a full run would give; this only saves the time of the others. The merged file keeps the
// full run's `generatedAt` and records which tools were replaced and when.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'tests/results');
const [target, part, tool] = process.argv.slice(2);
if (!target || !part || !tool) { console.error('usage: merge-scorecard.mjs <scorecard> <part> <tool>'); process.exit(2); }
const t = JSON.parse(fs.readFileSync(path.join(dir, target), 'utf8'));
const p = JSON.parse(fs.readFileSync(path.join(dir, part), 'utf8'));
const fresh = p.results.filter((r) => r.tool === tool);
if (!fresh.length) { console.error(`no rows of ${tool} in ${part}`); process.exit(1); }
const kept = t.results.filter((r) => r.tool !== tool);
t.results = [...kept, ...fresh];
t.replaced = { ...(t.replaced || {}), [tool]: p.generatedAt };
fs.writeFileSync(path.join(dir, target), JSON.stringify(t, null, 1));
console.log(`${target}: ${fresh.length} rows of ${tool} replaced (${t.results.length} in all)`);
