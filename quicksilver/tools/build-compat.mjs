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

const norm = (s) => s.toLowerCase().replace(/^(step-|mod-)/, '').replace(/[^a-z0-9]/g, '');

const families = familyRegistry().map((f) => {
  const note = NOTES[f.id] || { status: 'unsupported', basis: 'signature', detect: '', limits: [] };
  const rows = scorecard.results.filter((r) => r.tool === f.id);
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
  const covered = new Set(techniques.map((t) => norm(t.config)));
  const declared = new Set((note.covers || []).map(norm));
  const untested = f.techniques.filter((t) => !declared.has(norm(t)) && ![...covered].some((c) => norm(t).startsWith(c) || c.startsWith(norm(t))));
  return {
    id: f.id,
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
    measured,
    limits: note.limits,
    sources: f.sources,
  };
});

const out = {
  generatedAt: new Date().toISOString(),
  engineVersion: ENGINE_VERSION,
  trace: { generatedAt: traceCard.generatedAt },
  scorecard: { generatedAt: scorecard.generatedAt, fixtures: scorecard.results.length, sandbox: scorecard.sandbox, behaviourOracle: 'PUC Lua 5.1 / LuaJIT / Lua 5.4 via lupa' },
  families,
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
  if (f.limits && f.limits.length) md.push('', '**Limits**', '', ...f.limits.map((l) => `* ${l}`));
  if (f.untestedTechniques && f.untestedTechniques.length) md.push('', `**Documented techniques with no fixture:** ${f.untestedTechniques.join(', ')}`);
}
fs.mkdirSync(path.join(root, 'docs'), { recursive: true });
fs.writeFileSync(path.join(root, 'docs/COMPATIBILITY.md'), `${md.join('\n')}\n`);

const count = (s) => families.filter((f) => f.status === s).length;
console.log(`data/compat.json: ${families.length} families (supported ${count('supported')}, partial ${count('partial')}, experimental ${count('experimental')}, unsupported ${count('unsupported')}), ${scorecard.results.length} measured fixtures`);
