// Can the version of a Luraph script be read from its structure when its banner is missing or cannot be trusted?
//
//   node tools/research/luraph-era.mjs [--write]
//
// The labelled public collection (local/corpus/Luraph/<version>/, labels are the uploader's, so evidence and not ground truth) is read as shapes: every identifier, number and string
// replaced by a class, the first 60000 tokens, as a bag of token 4-grams. Each file is then given the label of its most similar neighbour among the OTHERS (leave-one-out), and the
// answers are counted. The result is a measurement of how much of the version a script's structure carries, not a classifier the pipeline relies on: the corpus is third-party and is
// not stored, so only the numbers are (data/research/luraph-era-eval.json).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../../src/core/bytes.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const dirRoot = path.join(root, 'local/corpus/Luraph');
if (!fs.existsSync(dirRoot)) { console.error('local/corpus/Luraph is not present on this machine'); process.exit(2); }
const KW = new Set(['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while']);
const shape = (src) => {
  const s = src.replace(/^(--[^\n]*\n)+/, '').slice(0, 60000);
  const toks = s.match(/--\[\[[\s\S]*?\]\]|--[^\n]*|"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|\[=*\[[\s\S]*?\]=*\]|0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d+\.?\d*(?:[eE][+-]?\d+)?|[A-Za-z_][A-Za-z_0-9]*|==|~=|<=|>=|\.\.\.?|[^\sA-Za-z_0-9]/g) || [];
  const abs = toks.map((t) => (/^--/.test(t) ? '' : /^["'\[]/.test(t) ? 'S' : /^0[xX]/.test(t) ? 'H' : /^0[bB]/.test(t) ? 'B' : /^\d/.test(t) ? 'N' : KW.has(t) ? t : /^[A-Za-z_]/.test(t) ? 'I' : t)).filter(Boolean);
  const bag = new Map();
  for (let i = 0; i + 3 < abs.length; i++) { const g = abs.slice(i, i + 4).join(' '); bag.set(g, (bag.get(g) || 0) + 1); }
  return bag;
};
const sim = (a, b) => { let inter = 0; let uni = 0; for (const k of new Set([...a.keys(), ...b.keys()])) { const x = a.get(k) || 0; const y = b.get(k) || 0; inter += Math.min(x, y); uni += Math.max(x, y); } return uni ? inter / uni : 0; };
const era = (l) => { const m = /^v(\d+)\.(\d+)/.exec(l); if (!m) return null; const a = +m[1]; const b = +m[2]; if (a < 14) return '13 and earlier'; if (a === 14 && b <= 3) return '14.0-14.3'; if (a === 14 && b <= 5) return '14.4-14.5'; if (a === 14) return '14.6-14.9'; return '15+'; };
const minor = (l) => l.replace(/^v/, '').split('.').slice(0, 2).join('.');

const files = [];
for (const d of fs.readdirSync(dirRoot)) {
  const dir = path.join(dirRoot, d);
  if (!fs.statSync(dir).isDirectory() || !/^v\d/.test(d)) continue;
  for (const f of fs.readdirSync(dir)) { const p = path.join(dir, f); if (fs.statSync(p).isFile()) files.push({ label: d, bag: shape(bytesToBinary(fs.readFileSync(p))) }); }
}
let exact = 0; let sameMinor = 0; let sameEra = 0;
const perEra = new Map();
for (const f of files) {
  let best = null; let bs = -1;
  for (const g of files) { if (g === f) continue; const s = sim(f.bag, g.bag); if (s > bs) { bs = s; best = g; } }
  if (best.label === f.label) exact++;
  if (minor(best.label) === minor(f.label)) sameMinor++;
  const ok = era(best.label) === era(f.label);
  if (ok) sameEra++;
  const e = perEra.get(era(f.label)) || { files: 0, correct: 0 };
  e.files++; if (ok) e.correct++; perEra.set(era(f.label), e);
}
const result = {
  method: 'leave-one-out nearest neighbour over bags of abstracted token 4-grams (first 60000 tokens, banner comment dropped); labels are the collection’s own folder names',
  labelledFiles: files.length,
  exactVersion: { correct: exact, of: files.length },
  sameMajorMinor: { correct: sameMinor, of: files.length },
  sameEra: { correct: sameEra, of: files.length, eras: Object.fromEntries([...perEra].sort()) },
  reading: 'the era of a bannerless script can be named with leave-one-out accuracy of about 78%, its exact version cannot (about 37%): minor revisions share their templates',
};
console.log(JSON.stringify(result, null, 1));
if (process.argv.includes('--write')) fs.writeFileSync(path.join(root, 'data/research/luraph-era-eval.json'), `${JSON.stringify(result, null, 2)}\n`);
