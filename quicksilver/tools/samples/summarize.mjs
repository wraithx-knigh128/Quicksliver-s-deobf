#!/usr/bin/env node
// Prompt XXIV: summarise the sample-collection inventory (and, when present, the recovery baseline) into data/research/samples-terrorlua.json.
// Only measurements and the collection's own file names (content hashes) are written; no sample content.
//
//   node tools/samples/summarize.mjs [--inventory local/terrorlua-inventory.jsonl] [--baseline local/terrorlua-baseline.jsonl]
//                                    [--before local/terrorlua-baseline.before.jsonl] [--out data/research/samples-terrorlua.json]

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

/** Folder label of the collection → the detector's family id (null: the detector has no family of that name). */
export const LABEL_FAMILY = {
  '77fuscator': 'fuscator77', Boronide: 'boronide', Hercules: 'hercules', IronBrew2: 'ironbrew2', Ironbrew1: 'ironbrew1', Ironbrew3: 'ironbrew3',
  LPS: 'lps', LuaObfuscator: 'luaobfuscator', Luraph: 'luraph', MoonSec: null, MoonVeil: 'moonveil', PSU: 'psu', Prometheus: 'prometheus',
  SynapseXen: 'synapse_xen', wYnFuscate: 'wynfuscate',
};
/** Folder label + subfolder → family, where the subfolder decides (MoonSec V2 / V3, Prometheus' WeAreDevs preset). */
export function expectedFamily(label, sub) {
  if (label === 'MoonSec') return sub === 'V2' ? 'moonsec_v2' : sub === 'V3' ? 'moonsec_v3' : null;
  if (label === 'Prometheus' && sub === 'WeAreDevs') return 'wearedevs';
  return LABEL_FAMILY[label] ?? null;
}
// families that are the same tool or a fork the label may legitimately stand for
const SAME = { wearedevs: ['prometheus'], prometheus: ['wearedevs'], ironbrew2: ['ironbrew1'], ironbrew1: ['ironbrew2'] };

const readJsonl = (p) => fs.existsSync(p) ? fs.readFileSync(p, 'utf8').split('\n').filter(Boolean).map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean) : [];
const pct = (a, b) => b ? Math.round(1000 * a / b) / 10 : null;

export function summarizeInventory(rows) {
  const groups = new Map();
  for (const r of rows) {
    const k = `${r.label}/${r.sub || ''}`;
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k).push(r);
  }
  const out = [];
  const suspects = [];
  for (const [k, list] of [...groups].sort((a, b) => a[0].localeCompare(b[0], 'en', { numeric: true }))) {
    const [label, sub] = [list[0].label, list[0].sub];
    const want = expectedFamily(label, sub);
    const top = {};
    const traits = {};
    const bannerVersions = {};
    let agree = 0; let detected = 0; let parsed = 0; let timeouts = 0; let errors = 0;
    const sizes = list.map((r) => r.bytes || 0).sort((a, b) => a - b);
    for (const r of list) {
      if (r.timeout) { timeouts++; continue; }
      if (r.error) { errors++; continue; }
      if (r.parsed) parsed++;
      const f = r.families && r.families[0];
      const id = f && f[1] >= 0.5 ? f[0] : 'none';
      top[id] = (top[id] || 0) + 1;
      if (id !== 'none') detected++;
      const ok = want && (id === want || (SAME[want] || []).includes(id));
      if (ok) agree++;
      for (const t of r.traits || []) traits[t] = (traits[t] || 0) + 1;
      const bv = r.banner && /v?(\d+(?:\.\d+)*[A-Za-z]?)/.exec(r.banner.replace(/^.*?(?:Obfuscator|Fuscate|fuscator|V)\s*/i, ''));
      if (r.banner) bannerVersions[bv ? bv[1] : '?'] = (bannerVersions[bv ? bv[1] : '?'] || 0) + 1;
      // a confident detection of another family is a candidate mislabel (or a layered script); kept with the evidence for review
      if (want && id !== 'none' && !ok && f[1] >= 0.9) suspects.push({ path: r.path, label: k, detected: id, confidence: f[1], version: f[2] });  // no banner text: third-party header text is not recorded
    }
    const n = list.length;
    out.push({
      group: k, label, sub, files: n, expected: want,
      bytes: { min: sizes[0], median: sizes[Math.floor(n / 2)], max: sizes[n - 1] },
      parsed: pct(parsed, n), detected: pct(detected, n), agree: want ? pct(agree, n) : null,
      topFamilies: Object.entries(top).sort((a, b) => b[1] - a[1]).slice(0, 4),
      traits: Object.entries(traits).sort((a, b) => b[1] - a[1]).slice(0, 6).map(([t, c]) => [t, pct(c, n)]),
      bannerVersions: Object.entries(bannerVersions).sort((a, b) => b[1] - a[1]).slice(0, 4),
      timeouts, errors,
    });
  }
  return { groups: out, suspects };
}

export function summarizeBaseline(rows) {
  const by = new Map();
  for (const r of rows) {
    const k = `${r.label}/${r.sub || ''}`;
    if (!by.has(k)) by.set(k, []);
    by.get(k).push(r);
  }
  const groups = [];
  const totals = { files: 0, outcome: {}, crashes: 0, timeouts: 0, parses: 0 };
  for (const [k, list] of [...by].sort((a, b) => a[0].localeCompare(b[0], 'en', { numeric: true }))) {
    const outcome = {};
    let crashes = 0; let timeouts = 0; let parses = 0; let ms = 0;
    for (const r of list) {
      if (r.timeout) { timeouts++; continue; }
      if (r.crash || r.error) { crashes++; continue; }
      outcome[r.outcome] = (outcome[r.outcome] || 0) + 1;
      if (r.parses) parses++;
      ms += r.ms || 0;
    }
    groups.push({ group: k, files: list.length, outcome, crashes, timeouts, parses, meanSeconds: list.length ? Math.round(ms / list.length / 100) / 10 : null });
    totals.files += list.length; totals.crashes += crashes; totals.timeouts += timeouts; totals.parses += parses;
    for (const [o, c] of Object.entries(outcome)) totals.outcome[o] = (totals.outcome[o] || 0) + c;
  }
  return { totals, groups };
}

async function main() {
  const args = process.argv.slice(2);
  const opt = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
  const inv = readJsonl(path.resolve(opt('--inventory', path.join(repo, 'local', 'terrorlua-inventory.jsonl'))));
  const base = readJsonl(path.resolve(opt('--baseline', path.join(repo, 'local', 'terrorlua-baseline.jsonl'))));
  const before = readJsonl(path.resolve(opt('--before', path.join(repo, 'local', 'terrorlua-baseline.before.jsonl'))));
  const out = path.resolve(opt('--out', path.join(repo, 'data', 'research', 'samples-terrorlua.json')));
  const prev = fs.existsSync(out) ? JSON.parse(fs.readFileSync(out, 'utf8')) : {};
  const doc = {
    source: { repository: 'https://github.com/terrorlua/obfuscator-samples', note: 'No licence is stated: the samples are kept outside this repository (local/terrorlua, git-ignored) and only measurements are recorded here. Folder labels are the collection’s claims; the README says wrongly filed scripts exist.' },
    generated: new Date().toISOString().slice(0, 10),
    inventory: inv.length ? { files: inv.length, ...summarizeInventory(inv) } : prev.inventory || null,
    baseline: base.length ? summarizeBaseline(base) : prev.baseline || null,
    before: before.length ? summarizeBaseline(before) : prev.before || null,
  };
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, JSON.stringify(doc, null, 1) + '\n');
  console.log(`${path.relative(repo, out)}: inventory ${doc.inventory ? doc.inventory.files : 0} files, baseline ${doc.baseline ? doc.baseline.totals.files : 0}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();
