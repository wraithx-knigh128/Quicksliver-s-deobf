// The work list: every configuration the scorecard measured, weakest first, with why it is weak.
//
//   node tools/formats/audit.mjs [--below 0.85] [--json]
//
// "Weak" is any row whose recovered fidelity is under the bar, whose output behaves differently from the original, or whose tool output does not parse.
// A row the tool itself broke (its own output does not run) is listed apart: it cannot be recovered and is not counted against the engine.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const card = JSON.parse(fs.readFileSync(path.join(root, 'tests/results/scorecard.json'), 'utf8'));
const bar = Number(process.argv.includes('--below') ? process.argv[process.argv.indexOf('--below') + 1] : 0.85);
const groups = new Map();
for (const r of card.results) {
  const k = `${r.tool}${r.version ? ` ${r.version}` : ''} / ${r.config}`;
  if (!groups.has(k)) groups.set(k, []);
  groups.get(k).push(r);
}
const mean = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
const rows = [];
for (const [k, rs] of groups) {
  const ok = rs.filter((r) => r.fidelityAfter != null);
  const own = rs.filter((r) => r.toolBehavior === 'equivalent' || r.toolBehavior === undefined);
  const diff = own.filter((r) => r.behaviorOriginal && r.behaviorOriginal !== 'same' && !String(r.behaviorOriginal).startsWith('error: sample')).length;
  rows.push({ group: k, n: rs.length, fidelity: mean(ok.map((r) => r.fidelityAfter)), unparsed: rs.length - ok.length, behaviourDiffers: diff, toolBroken: rs.filter((r) => r.toolBehavior && r.toolBehavior !== 'equivalent').length, confidence: mean(rs.map((r) => r.confidence ?? 0)) });
}
const weak = rows.filter((r) => r.fidelity === null || r.fidelity < bar || r.behaviourDiffers).sort((a, b) => (a.fidelity ?? -1) - (b.fidelity ?? -1));
if (process.argv.includes('--json')) { console.log(JSON.stringify(weak, null, 1)); process.exit(0); }
console.log(`${rows.length} configurations measured, ${weak.length} under ${Math.round(bar * 100)}% or behaving differently\n`);
for (const r of weak) console.log(`${(r.fidelity == null ? '  - ' : `${Math.round(r.fidelity * 100)}%`.padStart(4))}  ${r.group.padEnd(52)} n=${r.n}  unparsed=${r.unparsed}  behaviour-differs=${r.behaviourDiffers}  tool-broken=${r.toolBroken}`);
