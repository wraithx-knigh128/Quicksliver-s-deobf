// The compatibility matrix of the five primary targets (MoonVeil, Hercules, Luraph, Prometheus, IronBrew), one row per version and configuration, from data the measurements wrote.
//
//   node tools/formats/build-matrix.mjs        writes data/research/primary-matrix.json and docs/MATRIX.md
//
// Every number is read, none is typed: data/research/format-db.json (scorecard of the committed fixtures), format-records.json (the MoonVeil scripts that were read),
// luraph-compat.json (the Luraph engine registry), luraph-era-eval.json and data/compat.json (the corpus counts). A row says what the engine did on the fixtures of that row, and
// the status is the one the database computed; nothing is promoted here. A cell that cannot be measured says why instead of showing a number.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const load = (f) => JSON.parse(fs.readFileSync(path.join(root, f), 'utf8'));
const db = load('data/research/format-db.json');
const records = load('data/research/format-records.json');
const luraph = load('data/research/luraph-compat.json');
const era = load('data/research/luraph-era-eval.json');
const compat = load('data/compat.json');
const pct = (x) => (x == null ? null : Math.round(x * 100));

const IMPLEMENTATION = {
  hercules: { default: ['src/recover/hercules.js', 'src/recover/hercules-vm.js'], vm: ['src/recover/hercules-vm.js', 'src/decompile/decompile.js'] },
  prometheus: { default: ['src/recover/prometheus.js', 'src/passes/evaluate.js'], vmify: ['src/recover/vmify.js'] },
  ironbrew2: { default: ['src/recover/ironbrew.js', 'src/recover/ib2-templates.js'] },
  ironbrikked: { default: ['src/recover/ironbrikked-vm.js'] },
};

// what stops each MoonVeil version, from KNOWN-ISSUES (#18, #19, #46, #47)
const MOONVEIL_PATTERNS = {
  '1.4.5': ['three dispatcher loops (8, 135 and 259 blocks) and a 28888-character blob remain (KNOWN-ISSUES 19)'],
  '2.0.26': ['joined from a table of factories, not recovered: names are lost, register-style temporaries remain (KNOWN-ISSUES 47)'],
  '2.1.0': ['a bytecode VM again: the VM reader written for 2.0.25 stops at its first shape check (KNOWN-ISSUES 46)'],
};

const rows = [];
const fromProject = (target, projectId, { include = () => true, label = (c) => c, impl } = {}) => {
  const p = db.projects.find((x) => x.id === projectId);
  if (!p) return;
  for (const v of p.versions) {
    for (const c of v.configs) {
      if (!include(c, v)) continue;
      const cat = c.categories || {};
      const patterns = (p.failurePatterns || []).filter((f) => !f.configs || f.configs.some((x) => x === c.config || (typeof x === 'string' && x.includes(c.config)))).map((f) => `${f.status}: ${f.summary}`.slice(0, 260));
      rows.push({
        target, version: v.version, config: label(c.config),
        fixtures: { dir: v.fixtureDir, count: c.samples, id: `${v.fixtureDir.replace('tests/corpus/obfuscated/', '')}/${c.config}` },
        identification: cat.identification ? { detected: cat.identification.detected, of: cat.identification.of } : null,
        structure: cat.structure ? { before: pct(cat.structure.before), after: pct(cat.structure.after) } : null,
        semantic: cat.semantic ? { before: pct(cat.semantic.before), after: pct(cat.semantic.after) } : null,
        runtime: cat.runtime ? { same: cat.runtime.same, judged: cat.runtime.judged, notJudged: cat.runtime.notJudged } : null,
        completeness: cat.completeness ? { complete: cat.completeness.complete, of: cat.completeness.of } : null,
        failurePatterns: patterns,
        status: c.status,
        implementation: impl || [],
      });
    }
  }
};

fromProject('Hercules', 'hercules', { impl: IMPLEMENTATION.hercules.default });
fromProject('Prometheus', 'prometheus', { impl: IMPLEMENTATION.prometheus.default });
fromProject('IronBrew', 'ironbrew2', { impl: IMPLEMENTATION.ironbrew2.default, label: (c) => c });
fromProject('IronBrew', 'luaxen', { include: (c) => /ironbrikked|both/.test(c.config), impl: IMPLEMENTATION.ironbrikked.default, label: (c) => `IronBrikked (LuaXen): ${c}` });

// MoonVeil: the scripts that were read (the tool is closed and hosted, nothing can be generated), measured against a reference only where a hand-made one exists
for (const r of records.records.filter((x) => x.family === 'moonveil')) {
  rows.push({
    target: 'MoonVeil', version: r.version, config: `script ${r.id.replace(/^moonveil-/, '')}`,
    fixtures: { dir: 'public third-party scripts, not stored (sha256 in data/research/format-records.json)', count: 1, id: r.id },
    identification: { detected: r.detected && r.versionMatches ? 1 : 0, of: 1 },
    structure: r.reference ? { note: 'against the hand-made reconstruction of that script', after: null } : { note: 'no original program exists to compare with' },
    semantic: r.reference ? { before: null, after: pct(r.reference.fidelity) } : { note: 'no original program exists to compare with' },
    runtime: { note: 'not checkable: the program needs Roblox objects and its original is not available' },
    completeness: { unresolved: r.unresolved },
    failurePatterns: MOONVEIL_PATTERNS[r.version] || [],
    status: 'partial',
    confidence: r.confidence,
    implementation: ['src/recover/moonveil-join.js', 'src/recover/moonveil-vm/', 'src/recover/moonveil-cff.js', 'src/recover/moonveil.js'],
  });
}

// Luraph: the engine registry rows, per version
for (const [version, row] of Object.entries(luraph.summary.versions)) {
  const ev = row.evidence;
  rows.push({
    target: 'Luraph', version: version.replace(/^luraph-/, ''), config: 'VM',
    fixtures: { dir: 'public collection of labelled scripts; engine runs on the supplied reference samples', count: ev.runs, id: version },
    identification: { note: 'by banner; without a banner the era is named correctly 78% of the time and the exact version 37% (leave-one-out, tools/research/luraph-era.mjs)' },
    structure: { note: 'no original program exists for these scripts' },
    semantic: { note: 'no original program exists for these scripts' },
    runtime: { same: ev.identical, judged: ev.pairs, notJudged: ev.runs - ev.pairs },
    completeness: { lifted: ev.lifted, runs: ev.runs, traceOnly: ev.traceOnly },
    failurePatterns: row.reasons.slice(0, 2),
    status: row.status,
    implementation: ['src/reconstruct/', 'api/reconstruct.py'],
  });
}

const luraphFam = compat.families.find((f) => f.id === 'luraph');
const corpus = luraphFam && luraphFam.corpus;
const out = {
  schema: 'quicksilver/primary-matrix@1',
  generated: new Date().toISOString().slice(0, 10),
  note: 'One row per version and configuration. Status words: verified, partial, experimental, unsupported (format-db) and, for Luraph, the engine registry’s own (partially-tested ...). A cell with a note is one that cannot be measured for that row.',
  sources: ['data/research/format-db.json', 'data/research/format-records.json', 'data/research/luraph-compat.json', 'data/research/luraph-era-eval.json', 'data/compat.json'],
  luraphCollection: corpus ? { files: corpus.files, identified: corpus.identified, unidentified: corpus.unidentified, versionFiles: corpus.versionFiles, versionRight: corpus.versionRight } : null,
  luraphEra: { labelled: era.labelledFiles, exactVersion: era.exactVersion, majorMinor: era.sameMajorMinor, era: era.sameEra },
  rows,
};
fs.writeFileSync(path.join(root, 'data/research/primary-matrix.json'), `${JSON.stringify(out, null, 1)}\n`);

// ---- docs/MATRIX.md ---------------------------------------------------------------------------------------------------------------------------------
const cell = (c, kind) => {
  if (!c) return '—';
  if (c.note) return `n/a (${c.note})`;
  if (kind === 'id') return `${c.detected}/${c.of}`;
  if (kind === 'sa') return `${c.before == null ? '' : `${c.before}%→`}${c.after == null ? '—' : `${c.after}%`}`;
  if (kind === 'rt') return `${c.same}/${c.judged}${c.notJudged ? ` (${c.notJudged})` : ''}`;
  if (kind === 'cmp') return c.complete != null ? `${c.complete}/${c.of}` : c.lifted != null ? `${c.lifted}/${c.runs} lifted` : `${c.unresolved} unresolved`;
  return String(c);
};
const lines = [];
lines.push('# Compatibility matrix: the five primary targets', '', '_Generated by `node tools/formats/build-matrix.mjs` from the measurement data. Do not edit by hand._', '');
lines.push(out.note, '');
lines.push(`Luraph's public collection: ${out.luraphCollection ? `${out.luraphCollection.files} files, ${out.luraphCollection.identified} identified` : 'n/a'}; without a banner the era is named correctly ${pct(out.luraphEra.era)}% of the time, the exact version ${pct(out.luraphEra.exactVersion)}% (${out.luraphEra.labelled} labelled files, leave-one-out).`, '');
lines.push('Columns: identification (detected/of), structure and semantic (before→after recovery), runtime (same/judged, in brackets the fixtures whose own tool output does not run like the original and are therefore not judged), completeness (nothing of the obfuscator left and nothing unresolved), known failure patterns, fixture identifier, status.', '');
for (const target of ['MoonVeil', 'Hercules', 'Luraph', 'Prometheus', 'IronBrew']) {
  const rs = rows.filter((r) => r.target === target);
  lines.push(`## ${target}`, '');
  lines.push('| Version | Configuration | Fixtures (id) | Ident. | Structure | Semantic | Runtime | Complete | Status | Failure patterns | Implementation |', '|---|---|---|---|---|---|---|---|---|---|---|');
  for (const r of rs) {
    lines.push(`| ${r.version} | ${r.config} | ${r.fixtures.count} (${r.fixtures.id}) | ${cell(r.identification, 'id')} | ${cell(r.structure, 'sa')} | ${cell(r.semantic, 'sa')} | ${cell(r.runtime, 'rt')} | ${cell(r.completeness, 'cmp')} | ${r.status} | ${r.failurePatterns.length ? r.failurePatterns.map((x) => x.replace(/\|/g, '/')).join(' ; ').slice(0, 240) : '—'} | ${r.implementation.map((x) => `\`${x}\``).join(', ')} |`);
  }
  const by = {};
  rs.forEach((r) => { by[r.status] = (by[r.status] || 0) + 1; });
  lines.push('', `Rows by status: ${Object.entries(by).map(([k, v]) => `${k} ${v}`).join(', ')}.`, '');
}
fs.writeFileSync(path.join(root, 'docs/MATRIX.md'), `${lines.join('\n')}\n`);
console.log(`${rows.length} rows`, Object.fromEntries(['MoonVeil', 'Hercules', 'Luraph', 'Prometheus', 'IronBrew'].map((t) => [t, rows.filter((r) => r.target === t).length])));
