// Lab: the result store. One JSON line per experiment, appended, never edited. The id is a hash of everything that determines the experiment, so
// running it again produces the same id, and two records with one id can be compared as a reproducibility check.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

export const hash = (s, n = 12) => crypto.createHash('sha256').update(s).digest('hex').slice(0, n);

export function experimentId({ programSeed, transformId, transformSeed, planId, engine }) {
  return `exp_${hash(JSON.stringify([programSeed, transformId, transformSeed, planId, engine]), 14)}`;
}

export function readExperiments(file) {
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l));
}

export function writeExperiments(file, records) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, records.map((r) => JSON.stringify(r)).join('\n') + '\n');
}
