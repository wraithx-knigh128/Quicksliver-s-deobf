// The living research and compatibility database: data/research/format-db.json.
//
//   node tools/formats/build-db.mjs            write it
//   node tools/formats/build-db.mjs --check    exit 1 when the committed file is not what the inputs give
//
// One record per project and version: where it came from (sources, the revision that was run), which fixtures exist, what was measured on them (fidelity, behaviour on a real
// runtime, confidence, how often the tool itself failed), which failure patterns remain, which improvements were made because of them and where they live, and what is assumed
// and not shown. Measured numbers are read from tests/results/scorecard.json and the fixture manifests; the hand-written part is data/research/format-notes.json, and nothing
// in it is a number. A configuration is only `verified` when its fidelity is at least 85% and the recovered script behaved like the original on every run that could be checked;
// a measured improvement short of that is `partial`; everything else is `unsupported`. A project with no recovery measurement is `identification-only`, and nothing is claimed for
// output nobody ran (those assumptions are listed per project).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { familyRegistry, ENGINE_VERSION } from '../../src/api.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const readJson = (p) => JSON.parse(fs.readFileSync(path.join(root, p), 'utf8'));
const mean = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
const round = (x, d = 3) => (x === null || x === undefined ? null : Math.round(x * 10 ** d) / 10 ** d);

function pearson(pairs) {
  const n = pairs.length;
  if (n < 3) return null;
  const mx = mean(pairs.map((p) => p[0]));
  const my = mean(pairs.map((p) => p[1]));
  let sxy = 0; let sxx = 0; let syy = 0;
  for (const [x, y] of pairs) { sxy += (x - mx) * (y - my); sxx += (x - mx) ** 2; syy += (y - my) ** 2; }
  return sxx && syy ? sxy / Math.sqrt(sxx * syy) : null;
}

/** The status of one configuration, from what was measured (the same bar as tools/build-compat.mjs). */
function level(agg) {
  if (agg.fidelityAfter === null) return 'identification-only';
  if (agg.fidelityAfter >= 0.85 && agg.behaviourChecked > 0 && agg.behaviourSame === agg.behaviourChecked) return 'verified';
  if (agg.fidelityAfter >= 0.85) return 'partial';
  if (agg.fidelityAfter - (agg.fidelityBefore ?? 0) >= 0.1 && agg.fidelityAfter >= 0.3) return 'partial';
  return 'unsupported';
}

/** Every fixture folder: tests/corpus/obfuscated[-local]/<dir>, with its manifest. */
function manifests() {
  const out = [];
  for (const base of ['obfuscated', 'obfuscated-local']) {
    const dir = path.join(root, 'tests/corpus', base);
    if (!fs.existsSync(dir)) continue;
    for (const d of fs.readdirSync(dir).sort()) {
      const mp = path.join(dir, d, 'manifest.json');
      if (!fs.existsSync(mp)) continue;
      out.push({ dir: `tests/corpus/${base}/${d}`, base, name: d, committed: base === 'obfuscated', manifest: JSON.parse(fs.readFileSync(mp, 'utf8')) });
    }
  }
  return out;
}

const norm = (s) => String(s || '').toLowerCase().replace(/[^a-z0-9]/g, '');

export function buildDb() {
  const scorecard = readJson('tests/results/scorecard.json');
  const notes = readJson('data/research/format-notes.json');
  const research = readJson('data/research/format-research.json');
  const corpus = fs.existsSync(path.join(root, 'data/research/corpus-eval.json')) ? readJson('data/research/corpus-eval.json') : null;
  const fams = new Map(familyRegistry().map((f) => [f.id, f]));
  const folders = manifests();
  const tools = [...new Set(scorecard.results.map((r) => r.tool))].sort();
  const projects = [];

  for (const tool of tools) {
    const fam = fams.get(tool) || null;
    const n = notes.projects[tool] || {};
    const rows = scorecard.results.filter((r) => r.tool === tool);
    const versions = [...new Set(rows.map((r) => r.version || 'current'))];
    const vlist = [];
    for (const version of versions) {
      const rs = rows.filter((r) => (r.version || 'current') === version);
      // the folder this version's fixtures live in
      const folder = folders.find((f) => (f.manifest.tool && norm(f.manifest.tool) === norm(tool) || norm(f.name.split('-')[0]) === norm(tool)) && (version === 'current' ? !/-\d/.test(f.name) || f.name === tool : f.name.endsWith(`-${version}`)))
        || folders.find((f) => norm(f.name) === norm(tool));
      const meta = folder ? folder.manifest : {};
      const configs = [];
      for (const config of [...new Set(rs.map((r) => r.config))]) {
        const cs = rs.filter((r) => r.config === config);
        const u = cs.filter((r) => r.fidelityAfter != null);
        const ck = cs.filter((r) => r.behaviorOriginal != null);
        const agg = {
          config,
          samples: cs.length,
          detected: cs.filter((r) => r.detected && r.detected.some((d) => d.startsWith(`${tool}:`))).length,
          fidelityBefore: round(mean(u.map((r) => r.fidelityBefore ?? 0))),
          fidelityAfter: round(mean(u.map((r) => r.fidelityAfter))),
          confidence: round(mean(cs.map((r) => r.confidence ?? 0))),
          behaviourChecked: ck.length,
          behaviourSame: ck.filter((r) => r.behaviorOriginal === 'same').length,
          unparsed: cs.length - u.length,
        };
        agg.status = level(agg);
        configs.push(agg);
      }
      const entries = (meta.entries || []);
      const count = (st) => entries.filter((e) => e.status === st).length;
      vlist.push({
        version,
        revision: meta.sourceRevision || null,
        revisionDate: meta.revisionDate || null,
        note: meta.note || null,
        fixtureDir: folder ? folder.dir : null,
        committed: folder ? folder.committed : null,
        licence: meta.licence || (n.licence || null),
        fixtures: { measured: rs.length, written: count('ok'), toolErrors: count('tool-error'), omittedLarge: count('omitted-large'), toolOutputEquivalent: entries.filter((e) => e.behavior === 'equivalent').length, toolOutputErrored: entries.filter((e) => e.behavior === 'errored').length, toolOutputDiverged: entries.filter((e) => e.behavior === 'diverged').length },
        fidelityBefore: round(mean(rs.filter((r) => r.fidelityAfter != null).map((r) => r.fidelityBefore ?? 0))),
        fidelityAfter: round(mean(rs.filter((r) => r.fidelityAfter != null).map((r) => r.fidelityAfter))),
        configs,
        summary: { verified: configs.filter((c) => c.status === 'verified').length, partial: configs.filter((c) => c.status === 'partial').length, unsupported: configs.filter((c) => c.status === 'unsupported').length },
      });
    }
    const findings = research.findings.filter((f) => f.family === tool || f.id === tool);
    projects.push({
      id: tool,
      name: fam ? fam.name : tool,
      kind: fam ? fam.kind : null,
      sources: fam ? fam.sources : [],
      researchedFrom: [...(n.research || []), ...findings.map((f) => `${f.finding.slice(0, 160)} [${f.source}; ${f.reliability}]`)],
      versions: vlist,
      improvements: n.improvements || [],
      failurePatterns: n.failurePatterns || [],
      assumptions: n.assumptions || [],
      support: vlist.some((v) => v.summary.verified) ? (vlist.every((v) => v.summary.unsupported === 0 && v.summary.partial === 0) ? 'verified' : 'mixed') : vlist.some((v) => v.summary.partial) ? 'experimental' : 'unsupported',
    });
  }

  // tools that have a notes entry or a family but no fixtures: identification only, listed so nothing disappears
  for (const [id, n] of Object.entries(notes.projects)) {
    if (projects.some((p) => p.id === id)) continue;
    const fam = fams.get(id);
    projects.push({ id, name: fam ? fam.name : id, kind: fam ? fam.kind : null, sources: fam ? fam.sources : [], researchedFrom: n.research || [], versions: [], improvements: n.improvements || [], failurePatterns: n.failurePatterns || [], assumptions: n.assumptions || [], support: 'identification-only' });
  }

  // confidence against what was measured, over every recovery that has both
  const pairs = scorecard.results.filter((r) => r.confidence != null && r.fidelityAfter != null).map((r) => [r.confidence, r.fidelityAfter]);
  const collection = corpus ? {
    source: corpus.source, commit: corpus.commit, files: corpus.files,
    folders: Object.entries(corpus.summary).map(([label, s]) => ({ label, files: s.files, parsed: s.parsed, expected: s.expected, identified: s.identified, unidentified: s.unidentified, classOfUnidentified: s.classOfUnidentified || null })),
  } : null;

  return {
    schema: 'format-db/1',
    engine: ENGINE_VERSION,
    inputs: { scorecard: scorecard.generatedAt, scorecardFixtures: scorecard.results.length, notes: notes.schema },
    calibration: { pairs: pairs.length, pearson: round(pearson(pairs)) },
    projects,
    collection,
    backlog: notes.backlog || [],
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const db = buildDb();
  const target = path.join(root, 'data/research/format-db.json');
  const text = `${JSON.stringify(db, null, 1)}\n`;
  if (process.argv.includes('--check')) {
    const same = fs.existsSync(target) && fs.readFileSync(target, 'utf8') === text;
    console.log(same ? 'data/research/format-db.json is what the inputs give' : 'data/research/format-db.json is stale: run node tools/formats/build-db.mjs');
    process.exit(same ? 0 : 1);
  }
  fs.writeFileSync(target, text);
  const by = (s) => db.projects.filter((p) => p.support === s).length;
  console.log(`format-db.json: ${db.projects.length} projects (verified ${by('verified')}, mixed ${by('mixed')}, experimental ${by('experimental')}, unsupported ${by('unsupported')}, identification-only ${by('identification-only')}); confidence vs fidelity r=${db.calibration.pearson} over ${db.calibration.pairs}`);
}
