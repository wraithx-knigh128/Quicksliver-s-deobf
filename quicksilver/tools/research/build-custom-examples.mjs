// Builds the collection of validated examples the custom-format analysis reads (data/research/custom-examples.json), and measures how well it predicts.
//
// An example is one script from the committed corpus (a generated fixture or an original) with the transformations the probes found in it and what the pipeline then did:
// the confidence level, whether the output parses, whether the program's behaviour was checked against the original on the reference runtime. The label of the tool that made
// it is stored for reporting and is NEVER used by the analysis.
//
// The prediction is evaluated two ways, and both are written to the file: leave-one-out (the nearest OTHER example) and leave-one-tool-out (nothing from the same tool is
// available, which is the situation of an unfamiliar format). The numbers are what they are; the analysis shows them next to every prediction.
//
//   node tools/research/build-custom-examples.mjs [--no-behaviour]

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../../src/core/bytes.js';
import { recover } from '../../src/recover/pipeline.js';
import { probe } from '../../src/custom/probes.js';
import { IDS, neighbours } from '../../src/custom/analyze.js';
import * as oracle from '../../tests/helpers/lua-oracle.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const corpus = path.join(root, 'tests/corpus');
const behaviour = !process.argv.includes('--no-behaviour') && oracle.available;
const read = (p) => bytesToBinary(fs.readFileSync(p));

const dirs = fs.readdirSync(path.join(corpus, 'obfuscated')).filter((d) => fs.existsSync(path.join(corpus, 'obfuscated', d, 'manifest.json')));
const chosen = [];
for (const d of dirs) {
  const m = JSON.parse(fs.readFileSync(path.join(corpus, 'obfuscated', d, 'manifest.json'), 'utf8'));
  const seen = new Map();
  for (const e of m.entries || []) {
    if (e.status !== 'ok' || !/^s0[1-8]_/.test(e.file)) continue;
    const key = `${e.config}`;
    const n = seen.get(key) || 0;
    if (n >= 2) continue;                       // two samples per configuration
    seen.set(key, n + 1);
    chosen.push({ dir: d, file: e.file, sample: e.sample, config: e.config, toolOutputBehaves: e.behavior === 'equivalent' });
  }
}
const examples = [];
for (const c of chosen) {
  const p = path.join(corpus, 'obfuscated', c.dir, c.file);
  if (!fs.existsSync(p)) continue;
  const src = read(p);
  const pr = probe(src);
  if (!pr.ok) continue;
  const r = recover(src, { sandbox: { enabled: false } });
  const outcome = { ok: !!r.ok, level: r.confidence ? r.confidence.level : 'none', unresolved: r.report ? r.report.unresolved.length : null, applied: (r.steps || []).filter((s) => s.status === 'applied').length };
  if (behaviour && r.ok && r.output) {
    try {
      const original = read(path.join(corpus, 'originals', c.sample));
      const want = await oracle.runLua(original, 'lua51');
      const got = await oracle.runLua(r.output, 'lua51');
      outcome.runtimeSame = want.ok && got.ok ? want.stdout === got.stdout : null;
    } catch { outcome.runtimeSame = null; }
  }
  const vector = IDS.map((id) => { const t = pr.transformations.find((x) => x.id === id); return t ? +t.confidence.toFixed(2) : 0; });
  examples.push({ id: `${c.dir}/${c.file}`, tool: c.dir, config: c.config, transformations: pr.transformations.filter((t) => t.confidence >= 0.5).map((t) => t.id), vector, outcome });
}
oracle.stopOracle?.();

// the originals, as examples of "nothing was done"
for (const f of fs.readdirSync(path.join(corpus, 'originals')).filter((x) => x.endsWith('.lua'))) {
  const src = read(path.join(corpus, 'originals', f));
  const pr = probe(src);
  const r = recover(src, { sandbox: { enabled: false } });
  examples.push({ id: `originals/${f}`, tool: 'originals', config: 'plain', transformations: pr.transformations.filter((t) => t.confidence >= 0.5).map((t) => t.id), vector: IDS.map((id) => { const t = pr.transformations.find((x) => x.id === id); return t ? +t.confidence.toFixed(2) : 0; }), outcome: { ok: !!r.ok, level: r.confidence ? r.confidence.level : 'none', unresolved: r.report ? r.report.unresolved.length : null, applied: (r.steps || []).filter((s) => s.status === 'applied').length } });
}

// ---- how well the nearest example predicts what happens ----------------------------------------------------------------------------------------------------------
const good = (o) => o.ok && (o.level === 'high' || o.level === 'medium');
const evaluate = (exclude) => {
  let n = 0; let right = 0; let positives = 0; let truePositives = 0; let predictedPositives = 0;
  for (const e of examples) {
    const pool = { examples: examples.filter((x) => exclude(e, x)) };
    const nn = neighbours(e.transformations.map((id, i) => ({ id, confidence: e.vector[IDS.indexOf(id)] })), pool, 1, e.id)[0];
    if (!nn) continue;
    const predicted = good(nn.outcome);
    const actual = good(e.outcome);
    n++; if (predicted === actual) right++;
    if (actual) positives++;
    if (predicted) predictedPositives++;
    if (predicted && actual) truePositives++;
  }
  return { n, accuracy: +(right / n).toFixed(3), precision: +(truePositives / Math.max(1, predictedPositives)).toFixed(3), recall: +(truePositives / Math.max(1, positives)).toFixed(3) };
};
const baseRate = +(examples.filter((e) => good(e.outcome)).length / examples.length).toFixed(3);
const out = {
  schema: 'quicksilver/custom-examples@1',
  note: 'One to two scripts per configuration of each tool in the committed corpus, plus the original programs. The tool label is for reporting; the analysis never reads it. Outcomes are from the static pipeline (no sandbox).',
  built: new Date().toISOString().slice(0, 10),
  ids: IDS,
  counts: { examples: examples.length, tools: new Set(examples.map((e) => e.tool)).size, behaviourChecked: examples.filter((e) => e.outcome.runtimeSame !== undefined).length },
  evaluation: {
    question: 'does the nearest example predict whether the pipeline reaches a high or medium confidence result?',
    baseRate,
    leaveOneOut: evaluate((e, x) => x.id !== e.id),
    leaveOneToolOut: evaluate((e, x) => x.tool !== e.tool),
  },
  examples,
};
fs.writeFileSync(path.join(root, 'data/research/custom-examples.json'), `${JSON.stringify(out)}\n`);
console.log(JSON.stringify(out.counts), JSON.stringify(out.evaluation));
