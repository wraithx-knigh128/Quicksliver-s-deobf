// Builds data/compat.json, the file behind the compatibility dashboard.
//
//   node tools/build-compat.mjs
//
// Inputs: the family registry (src/detect/families.js), the measured results (tests/results/scorecard.json,
// written by tests/tools-scorecard.mjs) and the hand-written notes (tools/compat-notes.mjs).
// Nothing on the dashboard is typed in by hand except what compat-notes.mjs says is a judgement.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { familyRegistry, ENGINE_VERSION } from '../src/api.js';
import { NOTES, OVERRIDES } from './compat-notes.mjs';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const scorecard = JSON.parse(fs.readFileSync(path.join(root, 'tests/results/scorecard.json'), 'utf8'));
// the same fixtures with sandboxed evaluation off: what recovery achieves without running any decoder
const staticCard = JSON.parse(fs.readFileSync(path.join(root, 'tests/results/scorecard.static.json'), 'utf8'));
// the behavioural trace compared with the trace of the original program (tests/trace-scorecard.mjs)
const traceCard = JSON.parse(fs.readFileSync(path.join(root, 'tests/results/trace.json'), 'utf8'));

const mean = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
const round = (x, d = 3) => (x === null ? null : Math.round(x * 10 ** d) / 10 ** d);

/** A technique is "supported" when the recovered code is close to the original and behaves like it. */
function derive(agg) {
  if (agg.fidelityAfter >= 0.85 && agg.behaviourSame === agg.behaviourChecked) return 'supported';
  if (agg.fidelityAfter >= 0.85) return 'partial';
  if (agg.fidelityAfter - agg.fidelityBefore >= 0.1 && agg.fidelityAfter >= 0.3) return 'partial';
  return 'unsupported';
}

/** derive() for rows where behaviour may not be checkable (a tool's own output that does not run, a layer that needs a newer Lua): without a single behaviour check nothing is "supported". */
const deriveChecked = (agg) => { const st = derive(agg); return st === 'supported' && agg.behaviourChecked < 1 ? 'partial' : st; };

const norm = (s) => s.toLowerCase().replace(/^(step-|mod-)/, '').replace(/[^a-z0-9]/g, '');

const corpusPath = path.join(root, 'data/research/corpus-eval.json');
const corpusEval = fs.existsSync(corpusPath) ? JSON.parse(fs.readFileSync(corpusPath, 'utf8')) : null;
const families = familyRegistry().map((f) => {
  const note = NOTES[f.id] || { status: 'unsupported', basis: 'signature', detect: '', limits: [] };
  const rows = scorecard.results.filter((r) => r.tool === f.id && !r.version);
  let measured = null;
  const techniques = [];
  if (rows.length) {
    const configs = [...new Set(rows.map((r) => r.config))];
    for (const config of configs) {
      const rs = rows.filter((r) => r.config === config);
      const usable = rs.filter((r) => r.fidelityAfter != null);
      const tr = traceCard.results.filter((r) => r.tool === f.id && r.config === config && r.toolBehavior === 'equivalent');
      const st = staticCard.results.filter((r) => r.tool === f.id && r.config === config && r.fidelityAfter != null);
      // behaviour is judged against the original program the fixture was made from
      const checked = rs.filter((r) => r.behaviorOriginal != null);
      const agg = {
        config,
        samples: rs.length,
        fidelityBefore: round(mean(usable.map((r) => r.fidelityBefore ?? 0))),
        fidelityAfter: round(mean(usable.map((r) => r.fidelityAfter))),
        fidelityStatic: round(mean(st.map((r) => r.fidelityAfter))),
        confidence: round(mean(rs.map((r) => r.confidence ?? 0))),
        behaviourChecked: checked.length,
        behaviourSame: checked.filter((r) => r.behaviorOriginal === 'same').length,
        traceIdentical: tr.filter((r) => r.outcome === 'identical').length,
        traceChecked: tr.length,
        toolBroken: rs.filter((r) => r.toolBehavior !== 'equivalent').length,
        ms: Math.round(mean(rs.map((r) => r.ms || 0))),
      };
      const ov = (OVERRIDES[f.id] || {})[config];
      agg.status = ov ? ov.status : derive(agg);
      agg.needsSandbox = agg.fidelityStatic != null && agg.fidelityAfter - agg.fidelityStatic >= 0.1;
      if (ov) agg.note = ov.note;
      agg.kind = /^step-/.test(config) ? 'step' : /^mod-/.test(config) ? 'module' : 'preset';
      agg.label = config.replace(/^(step|mod)-/, '').replace(/_/g, ' ');
      techniques.push(agg);
    }
    const all = rows.filter((r) => r.fidelityAfter != null);
    const trAll = traceCard.results.filter((r) => r.tool === f.id && r.toolBehavior === 'equivalent');
    measured = {
      traceIdentical: trAll.filter((r) => r.outcome === 'identical').length,
      traceChecked: trAll.length,
      fixtures: rows.length,
      fidelityBefore: round(mean(all.map((r) => r.fidelityBefore ?? 0))),
      fidelityAfter: round(mean(all.map((r) => r.fidelityAfter))),
    };
  }
  // older revisions of the same tool, each measured on its own fixtures (tests/corpus/tools/gen_hercules_versions.py): never averaged into the headline numbers
  const versions = [];
  const vrows = scorecard.results.filter((r) => r.tool === f.id && r.version);
  for (const version of [...new Set(vrows.map((r) => r.version))]) {
    const rs = vrows.filter((r) => r.version === version);
    const metaPath = ['obfuscated', 'obfuscated-local'].map((d) => path.join(root, `tests/corpus/${d}/${f.id}-${version}/manifest.json`)).find((p) => fs.existsSync(p));
    const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
    const usable = rs.filter((r) => r.fidelityAfter != null);
    const checked = rs.filter((r) => r.behaviorOriginal != null);
    const configs = [...new Set(rs.map((r) => r.config))].map((config) => {
      const cs = rs.filter((r) => r.config === config);
      const u = cs.filter((r) => r.fidelityAfter != null);
      const ck = cs.filter((r) => r.behaviorOriginal != null);
      const agg = { config, samples: cs.length, fidelityBefore: round(mean(u.map((r) => r.fidelityBefore ?? 0))), fidelityAfter: round(mean(u.map((r) => r.fidelityAfter))), behaviourChecked: ck.length, behaviourSame: ck.filter((r) => r.behaviorOriginal === 'same').length, toolBroken: cs.filter((r) => r.toolBehavior !== 'equivalent').length, unparsed: cs.length - u.length };
      agg.status = u.length ? deriveChecked(agg) : 'unsupported';
      return agg;
    });
    versions.push({ version, revision: meta.sourceRevision, revisionDate: meta.revisionDate, note: meta.note, modules: meta.modules, fixtures: rs.length, fidelityBefore: round(mean(usable.map((r) => r.fidelityBefore ?? 0))), fidelityAfter: round(mean(usable.map((r) => r.fidelityAfter))),
      behaviourChecked: checked.length, behaviourSame: checked.filter((r) => r.behaviorOriginal === 'same').length, configs,
      supported: configs.filter((c) => c.status === 'supported').length, partial: configs.filter((c) => c.status === 'partial').length, unsupported: configs.filter((c) => c.status === 'unsupported').length });
  }
  const covered = new Set(techniques.map((t) => norm(t.config)));
  const declared = new Set((note.covers || []).map(norm));
  const untested = f.techniques.filter((t) => !declared.has(norm(t)) && ![...covered].some((c) => norm(t).startsWith(c) || c.startsWith(norm(t))));
  // detection measured on the labelled public collection (tools/formats/corpus-eval.mjs): per family, how many of its files were identified as it
  let corpus = null;
  if (corpusEval) {
    const labels = Object.entries(corpusEval.summary).filter(([, v]) => v.expected === f.id);
    if (labels.length) {
      const sum = (k) => labels.reduce((a, [, v]) => a + v[k], 0);
      corpus = { labels: labels.map(([k]) => k), files: sum('files'), identified: sum('identified'), unidentified: sum('unidentified'), versionFiles: sum('versionFiles'), versionRight: sum('versionRight'), commit: corpusEval.commit, source: corpusEval.source };
    }
  }
  return {
    id: f.id,
    corpus,
    name: f.name,
    kind: f.kind,
    status: note.status,
    basis: note.basis,
    summary: f.summary,
    detect: note.detect,
    detectEvidence: f.evidence,
    documentedTechniques: f.techniques,
    untestedTechniques: measured ? untested : f.techniques,
    techniques,
    versions,
    measured,
    limits: note.limits,
    sources: f.sources,
  };
});

// layered (mixed) chains: real tools stacked with packers and the laboratory's transformations (tests/corpus/tools/gen_mixed.py)
const layered = [];
if (fs.existsSync(path.join(root, 'tests/corpus/obfuscated/mixed/manifest.json'))) {
  const meta = JSON.parse(fs.readFileSync(path.join(root, 'tests/corpus/obfuscated/mixed/manifest.json'), 'utf8'));
  const mrows = scorecard.results.filter((r) => r.tool === 'mixed');
  for (const [id, stages] of Object.entries(meta.chains)) {
    const rs = mrows.filter((r) => r.config === id);
    const usable = rs.filter((r) => r.fidelityAfter != null);
    const checked = rs.filter((r) => r.behaviorOriginal != null && r.toolBehavior === 'equivalent');
    const agg = { id, stages: stages.map((st) => (st[0] === 'hercules' ? `hercules ${st[1]} [${st[2]}]` : `${st[0]} ${st[1]}`)), layers: stages.length, samples: rs.length, detected: rs.filter((r) => r.detected && r.detected.length).length,
      fidelityBefore: round(mean(usable.map((r) => r.fidelityBefore ?? 0))), fidelityAfter: round(mean(usable.map((r) => r.fidelityAfter))), confidence: round(mean(rs.map((r) => r.confidence ?? 0))),
      behaviourChecked: checked.length, behaviourSame: checked.filter((r) => r.behaviorOriginal === 'same').length, unparsed: rs.length - usable.length };
    agg.status = usable.length ? deriveChecked(agg) : 'unsupported';
    layered.push(agg);
  }
}

const out = {
  generatedAt: new Date().toISOString(),
  engineVersion: ENGINE_VERSION,
  trace: { generatedAt: traceCard.generatedAt },
  scorecard: { generatedAt: scorecard.generatedAt, fixtures: scorecard.results.length, sandbox: scorecard.sandbox, behaviourOracle: 'PUC Lua 5.1 / LuaJIT / Lua 5.4 via lupa' },
  families,
  layered,
};
fs.mkdirSync(path.join(root, 'data'), { recursive: true });
fs.writeFileSync(path.join(root, 'data/compat.json'), `${JSON.stringify(out, null, 1)}\n`);

// ---- docs/COMPATIBILITY.md: the same data as a readable page, so the numbers in the docs cannot drift from the dashboard ----------------
const pc = (x) => (x == null ? '–' : `${Math.round(x * 100)}%`);
const md = [];
md.push('# Compatibility', '', `Generated by \`tools/build-compat.mjs\` from \`tests/results/*.json\` (${scorecard.results.length} fixtures, engine ${ENGINE_VERSION}). Do not edit by hand.`, '',
  'Fidelity is the overlap between the recovered code and the original program the fixture was made from (identifier names ignored). Behaviour compares what the recovered script prints with what the',
  'obfuscated one printed, on a real Lua (PUC 5.1 / LuaJIT / 5.4 through `lupa`). A technique is **supported** when fidelity is at least 85% and behaviour matches; **partial** when it is better than before',
  'but short of that; **unsupported** otherwise. Families without fixtures are signatures only (**experimental** or **unsupported**): nothing was run and nothing is claimed.', '');
md.push('| Family | Status | Basis | Fixtures | Fidelity before → after | Trace identical |', '|---|---|---|---|---|---|');
for (const f of families) {
  const m = f.measured;
  md.push(`| ${f.name} | ${f.status} | ${f.basis} | ${m ? m.fixtures : '–'} | ${m ? `${pc(m.fidelityBefore)} → ${pc(m.fidelityAfter)}` : '–'} | ${m && m.traceChecked ? `${m.traceIdentical} / ${m.traceChecked}` : '–'} |`);
}
for (const f of families) {
  md.push('', `## ${f.name}`, '', `${f.summary || ''}`, '', `**Status:** ${f.status} (${f.basis}). ${f.detect || ''}`);
  if (f.techniques.length) {
    md.push('', '| Configuration | Status | Fidelity before → after | Same behaviour | Mean time |', '|---|---|---|---|---|');
    for (const t of f.techniques) {
      md.push(`| ${t.label} (${t.kind}) | ${t.status}${t.note ? ` – ${t.note}` : ''} | ${pc(t.fidelityBefore)} → ${pc(t.fidelityAfter)}${t.needsSandbox ? ' (needs sandbox)' : ''} | ${t.behaviourSame} / ${t.behaviourChecked}${t.toolBroken ? ` (${t.toolBroken} tool output broken)` : ''} | ${t.ms} ms |`);
    }
  }
  if (f.corpus) md.push('', `**Detection on real scripts:** ${f.corpus.identified} of ${f.corpus.files} files filed under ${f.corpus.labels.join(', ')} in the public collection (${f.corpus.source}, commit \`${String(f.corpus.commit).slice(0, 10)}\`) were identified as ${f.name}${f.corpus.versionFiles ? `; the version read from the script matched the collection's version directory in ${f.corpus.versionRight} of ${f.corpus.versionFiles}` : ''}. The collection's labels are its uploaders' and are noisy; a file our rules call something else was looked at before being counted as a miss.`);
  if (f.versions && f.versions.length) {
    md.push('', '### Versions', '', 'Each revision of the tool that can still be run, measured on its own fixtures (a version is what the watermark its source writes says; the tool has no release tags). Rows are never averaged with the current revision.', '',
      '| Version | Revision | Fixtures | Fidelity before → after | Same behaviour | Configurations (supported / partial / unsupported) |', '|---|---|---|---|---|---|');
    for (const v of f.versions) md.push(`| ${v.version} | \`${String(v.revision).slice(0, 7)}\` ${v.revisionDate || ''} | ${v.fixtures} | ${pc(v.fidelityBefore)} → ${pc(v.fidelityAfter)} | ${v.behaviourSame} / ${v.behaviourChecked} | ${v.supported} / ${v.partial} / ${v.unsupported} |`);
    for (const v of f.versions) {
      const weak = v.configs.filter((c) => c.status !== 'supported');
      if (weak.length) md.push('', `* **${v.version}** not supported: ${weak.map((c) => `${c.config} (${c.status}, ${pc(c.fidelityAfter)}${c.unparsed ? `, ${c.unparsed} output(s) the tool wrote that do not parse` : ''})`).join('; ')}`);
    }
  }
  if (f.limits && f.limits.length) md.push('', '**Limits**', '', ...f.limits.map((l) => `* ${l}`));
  if (f.untestedTechniques && f.untestedTechniques.length) md.push('', `**Documented techniques with no fixture:** ${f.untestedTechniques.join(', ')}`);
}
if (layered.length) {
  md.push('', '## Layered (mixed) obfuscation', '', 'Real tools stacked with packers and with the laboratory\u2019s transformations, in both orders (`tests/corpus/tools/gen_mixed.py`). The outermost layer is what an analyst sees first; the original program is what the chain protects. Behaviour counts only fixtures whose own output behaves like the original.', '',
    '| Chain | Layers | Detected | Fidelity before → after | Same behaviour | Confidence | Status |', '|---|---|---|---|---|---|---|');
  for (const l of layered) md.push(`| ${l.id} (${l.stages.join(' → ')}) | ${l.layers} | ${l.detected} / ${l.samples} | ${pc(l.fidelityBefore)} → ${pc(l.fidelityAfter)} | ${l.behaviourSame} / ${l.behaviourChecked} | ${pc(l.confidence)} | ${l.status} |`);
}
fs.mkdirSync(path.join(root, 'docs'), { recursive: true });
fs.writeFileSync(path.join(root, 'docs/COMPATIBILITY.md'), `${md.join('\n')}\n`);

const count = (s) => families.filter((f) => f.status === s).length;
console.log(`data/compat.json: ${families.length} families (supported ${count('supported')}, partial ${count('partial')}, experimental ${count('experimental')}, unsupported ${count('unsupported')}), ${scorecard.results.length} measured fixtures`);
