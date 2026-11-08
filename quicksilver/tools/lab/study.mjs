// Lab: study of transformation systems the engine has no rule for.
//
//   node tools/lab/study.mjs [--out data/research] [--train 16] [--heldout 16]
//
// For every single-stage transformation in the catalogue (the lab's own custom systems and the independent mutators), learn a signature from samples made
// from programs 1..N, and measure it on samples made from different programs (101..). A signature becomes a registered family only if it passes the
// thresholds in src/research/study.js on those held-out samples and the system is one of the lab's custom ones; every attempt, accepted or
// not, is written to study.json with its numbers. Stacked transformations are not used for learning: they are reported, because whether a signature
// still fires when another system wraps the first is itself a result.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { generateProgram } from './generate.mjs';
import { TRANSFORMS } from './transforms.mjs';
import { extractFeatures } from '../../src/research/features.js';
import { learnSignature, evaluate, measure, THRESHOLDS } from '../../src/research/study.js';
import { satisfies } from '../../src/research/families.js';

const here = path.dirname(fileURLToPath(import.meta.url));

export function sampleSets({ first, count }) {
  const clean = [];
  const by = new Map();
  for (const t of TRANSFORMS) by.set(t.id, []);
  for (let s = first; s < first + count; s++) {
    const p = generateProgram(s);
    clean.push(extractFeatures(p.source).features);
    for (const t of TRANSFORMS) {
      const text = t.apply(p.source, s);
      if (text !== p.source) by.get(t.id).push(extractFeatures(text).features);   // a transformation that did not apply is not a sample of it
    }
  }
  return { clean, by };
}

export function runStudy({ train = 16, heldout = 16 } = {}) {
  const tr = sampleSets({ first: 1, count: train });
  const ho = sampleSets({ first: 101, count: heldout });
  const singles = TRANSFORMS.filter((t) => t.kind !== 'stacked');
  const stacks = TRANSFORMS.filter((t) => t.kind === 'stacked');
  const attempts = [];
  const families = [];
  for (const target of singles) {
    const split = (sets) => ({ positives: sets.by.get(target.id), negatives: [...sets.clean, ...singles.filter((o) => o.id !== target.id).flatMap((o) => sets.by.get(o.id))] });
    const learned = learnSignature(split(tr));
    if (!learned) { attempts.push({ transform: target.id, kind: target.kind, outcome: 'no-signature', reason: 'nothing in the samples separates this system from the others' }); continue; }
    const check = evaluate(learned.signature, split(ho));
    const onStacks = stacks.map((st) => ({ stack: st.id, fires: measure(learned.signature, ho.by.get(st.id), []).recall }));
    attempts.push({
      transform: target.id, kind: target.kind, outcome: check.accepted ? 'accepted' : 'rejected', signature: learned.signature,
      train: learned.train, heldout: check.measure, reasons: check.reasons, onStacks,
    });
    if (check.accepted && target.kind === 'custom') {
      families.push({
        id: `lab-${target.id}`, name: `Lab custom system: ${target.label.replace(/^lab custom: /, '')}`, origin: 'lab-learned', kind: 'custom',
        summary: 'Signature learned from controlled samples of a protector written for this laboratory; not a third-party tool.',
        versions: [{ id: 'lab-1', label: 'lab generator 1' }], signature: learned.signature,
        learned: { trainPrograms: train, heldoutPrograms: heldout, heldout: check.measure, thresholds: THRESHOLDS },
      });
    }
  }
  return { attempts, families };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const argv = process.argv.slice(2);
  const out = argv.includes('--out') ? path.resolve(argv[argv.indexOf('--out') + 1]) : path.join(here, '..', '..', 'data', 'research');
  const n = (flag, d) => (argv.includes(flag) ? Number(argv[argv.indexOf(flag) + 1]) : d);
  const { attempts, families } = runStudy({ train: n('--train', 16), heldout: n('--heldout', 16) });
  fs.mkdirSync(out, { recursive: true });
  fs.writeFileSync(path.join(out, 'study.json'), JSON.stringify({ schema: 1, thresholds: THRESHOLDS, attempts }, null, 1) + '\n');
  fs.writeFileSync(path.join(out, 'custom-families.json'), JSON.stringify({ schema: 1, families }, null, 1) + '\n');
  for (const a of attempts) console.log(a.transform.padEnd(18), a.outcome.padEnd(12), a.signature ? `${a.signature.all.join(' & ')}${a.signature.none.length ? ` & not(${a.signature.none.join(', ')})` : ''}` : '-', a.heldout ? `P=${a.heldout.precision.toFixed(2)} R=${a.heldout.recall.toFixed(2)}` : '', (a.reasons || []).join('; '));
  console.log(`${families.length} custom families registered -> ${out}`);
}
