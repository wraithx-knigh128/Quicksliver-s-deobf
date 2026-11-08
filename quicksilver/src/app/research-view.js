// The Research tab: what the laboratory measured, what that implies for the current input, and where the numbers come from.
//
// Every number here is read from data/research/ (summary.json, knowledge.json), which tools/lab/ writes from experiment records. Nothing is typed in.
// Text that came from a script (the observed signature of the current input) is only inserted as text.

import { h, pct, fmtMs } from './dom.js';
import { section, kv, note, meter } from './views.js';

export async function loadResearch() {
  const get = async (f) => {
    const res = await fetch(`data/research/${f}`, { cache: 'no-cache' });
    if (!res.ok) throw new Error(`data/research/${f}: HTTP ${res.status}`);
    return res.json();
  };
  const [summary, knowledge, families] = await Promise.all([get('summary.json'), get('knowledge.json'), get('custom-families.json')]);
  return { summary, knowledge, families };
}

const VERDICT_TEXT = {
  'verified-recovery': 'near the original, behaviour identical',
  'verified-partial': 'better than the input, behaviour identical',
  'behaviour-kept-no-gain': 'same behaviour, nothing gained',
  'behaviour-kept-worse': 'same behaviour, further from the original',
};
const cellClass = (c) => (c.n === 0 ? 'm-none' : c.rate >= 0.9 ? 'm-high' : c.rate >= 0.5 ? 'm-mid' : c.rate > 0 ? 'm-low' : 'm-zero');
const KIND_TEXT = { works: 'Works', fails: 'Does not work', harms: 'Makes it worse', 'needs-sandbox': 'Needs the sandbox', improves: 'Better than another plan' };
const GRADE_BADGE = { source: 'ok', 'third-party': 'warn', 'search-snippet': 'warn', unreachable: 'bad' };

function adviceSection(advice, observed) {
  if (!advice) return section('This input', note('', 'Press Deobfuscate (or open a file) and the advice for it appears here: what it shows, which plan the experiments support, and how many trials stand behind that.'));
  const rows = advice.alternatives || [];
  return section('This input', [
    kv([
      ['What it shows', observed && observed.tokens.length ? observed.tokens.filter((t) => !t.startsWith('f:strings:none') ).join(', ') : 'no sign of obfuscation the laboratory knows'],
      ['Matched on', advice.basis === 'exact' ? 'experiments with the same signs' : advice.basis === 'similar' ? 'experiments with similar signs' : 'nothing (no verified experiment matches)'],
      ['Plan', h('span', [h('b', advice.plan.label), advice.applied && advice.applied.id !== advice.plan.id ? ` (applied: ${advice.applied.label}, the sandbox is off)` : ''])],
      ['Trials behind it', String(advice.trials || 0)],
    ]),
    note(advice.basis === 'none' ? 'warn' : '', advice.reason),
    advice.recommendSandbox ? note('info', 'The experiments say this input is recovered much better with the sandbox on. Switch it on in Settings (it asks first) and recover again.') : null,
    rows.length ? h('table.steps', h('thead', h('tr', ['Plan', 'Trials', 'Verified', '95% interval', 'Closeness', 'Worse'].map((x) => h('th', x)))), h('tbody', rows.map((r) => h('tr', [
      h('td', [r.label, r.needsConsent ? h('span.faint', ' (sandbox)') : null]),
      h('td', String(r.n)), h('td', `${r.success}/${r.n}`), h('td', `${pct(r.lo)}–${pct(r.hi)}`), h('td', r.fidelityAfter == null ? '—' : r.fidelityAfter.toFixed(2)), h('td', String(r.worse + r.failed)),
    ])))) : null,
  ]);
}

function matrixSection(summary) {
  const plans = summary.plans;
  const rows = ['known', 'custom', 'stacked'].flatMap((kind) => summary.transforms.filter((t) => t.kind === kind));
  const kindLabel = { known: 'Existing independent transformations', custom: 'Systems written for the laboratory (unfamiliar to the engine)', stacked: 'Several in a row (nested)' };
  const body = [];
  let last = null;
  for (const t of rows) {
    if (t.kind !== last) { body.push(h('tr.group', h('td', { colspan: plans.length + 1 }, kindLabel[t.kind]))); last = t.kind; }
    const cells = summary.byTransformPlan[t.id] || {};
    body.push(h('tr', [h('td', t.label), ...plans.map((p) => {
      const c = cells[p.id];
      if (!c) return h('td.m-none', '—');
      return h('td', { class: cellClass(c), title: `${c.n} trials: ${c.recovery} near the original, ${c.partial} better than the input, ${c.noGain} no gain, ${c.worse} worse, ${c.failed} failed. 95% interval ${pct(c.lo)}–${pct(c.hi)}. Closeness to the original ${c.fidelityBefore} → ${c.fidelityAfter}.` }, `${c.success}/${c.n}`);
    })]));
  }
  return section('What the laboratory measured', [
    note('', `Each cell is verified successes over trials: the reconstruction behaves exactly like the original program and is measurably closer to it, or shows fewer signs of obfuscation. ${summary.counts.experiments} experiments on ${summary.counts.programs} generated programs. Behaviour is compared in this project's own Lua interpreter, not a reference Lua. Hover a cell for the breakdown.`),
    h('div.matrix-wrap', h('table.matrix', h('thead', h('tr', [h('th', 'Transformation'), ...plans.map((p) => h('th', { title: p.text }, p.label))])), h('tbody', body))),
  ]);
}

function statementsSection(kb) {
  const by = {};
  for (const d of kb.discoveries) (by[d.kind] || (by[d.kind] = [])).push(d);
  return section('Statements the experiments support', [
    note('', `Each is derived by a stated rule from at least ${kb.minTrials} trials; a smaller experiment produces no statement. They are not opinions.`),
    ...Object.keys(KIND_TEXT).filter((k) => by[k]).map((k) => h('details', [
      h('summary', `${KIND_TEXT[k]} (${by[k].length})`),
      h('ul.list', by[k].map((d) => h('li', [d.statement, h('div.faint', `rule: ${d.rule}`)]))),
    ])),
  ]);
}

function evaluationSection(kb) {
  if (!kb.evaluations.length) return null;
  return section('Techniques evaluated', [
    note('', 'Each compares the same experiments on two revisions of the engine. A change that made some results worse is listed with them.'),
    ...kb.evaluations.map((e) => h('details', { open: true }, [
      h('summary', `${e.label}: ${e.improvedExperiments} improved, ${e.regressedExperiments} regressed of ${e.matched}`),
      h('p.note', e.note),
      e.cellsImproved.length ? h('table.steps', h('tbody', e.cellsImproved.map((c) => h('tr', [h('td', `${c.transform} · ${c.plan}`), h('td', `verified ${c.baseSuccess}/${c.n} → ${c.currentSuccess}/${c.n}; near the original ${c.baseRecovery} → ${c.currentRecovery}`)])))) : null,
      e.cellsRegressed.length ? h('div', [h('b', 'Got worse:'), h('table.steps', h('tbody', e.cellsRegressed.map((c) => h('tr', [h('td', `${c.transform} · ${c.plan}`), h('td', `verified ${c.baseSuccess}/${c.n} → ${c.currentSuccess}/${c.n}; worse ${c.baseWorse} → ${c.currentWorse}`)]))))]) : null,
    ])),
  ]);
}

function studySection(kb) {
  const rows = kb.study;
  if (!rows.length) return null;
  return section('Unfamiliar systems studied', [
    note('', 'For each system, a signature was learned from samples and measured on programs that played no part in learning it. Only signatures that passed were registered as families; the others are kept here with their numbers.'),
    h('table.steps', h('thead', h('tr', ['System', 'Outcome', 'Signature', 'Precision', 'Recall'].map((x) => h('th', x)))), h('tbody', rows.map((a) => h('tr', [
      h('td', [a.transform, h('div.faint', a.kind)]),
      h('td', h('span.badge.' + (a.outcome === 'accepted' ? 'ok' : a.outcome === 'rejected' ? 'warn' : 'bad'), a.outcome)),
      h('td.mono', a.signature ? [...a.signature.all, ...a.signature.none.map((n) => `not ${n}`)].join(' & ') : '—'),
      h('td', a.heldout ? a.heldout.precision.toFixed(2) : '—'),
      h('td', a.heldout ? a.heldout.recall.toFixed(2) : '—'),
    ])))),
  ]);
}

function sourcesSection(kb) {
  return section('Outside research', [
    note('', 'Notes from outside the laboratory, with how each is known. None is a discovery: only an experiment can make one.'),
    h('ul.list', kb.sources.map((s) => h('li', [
      h('div', [h('b', s.title), ' ', h('span.badge.' + (GRADE_BADGE[s.grade] || ''), s.grade), ' ', h('span.badge', `lab: ${s.labStatus}`)]),
      h('ul', { style: { margin: '4px 0', paddingLeft: '16px' } }, s.claims.map((c) => h('li', { style: { border: 0, padding: '1px 0' } }, c))),
      h('div.faint', s.labReason),
      h('div.faint.mono', `${s.url} · retrieved ${s.retrieved}`),
    ]))),
  ]);
}

/** @param {{summary: object, knowledge: object}} data @param {{advice?: object, observed?: object}} [now] */
export function researchView(data, now = {}) {
  const { summary, knowledge } = data;
  const root = h('div.view.research');
  root.append(
    section('Research laboratory', [
      kv([
        ['Experiments', `${summary.counts.experiments} (${summary.counts.toolBroken} excluded: the transformation itself changed behaviour)`],
        ['Generated programs', String(summary.counts.programs)],
        ['Revisions measured', summary.revisions.join(', ')],
        ['Behaviour checked in', summary.interpreter],
        ['Defects found', knowledge.defects.length ? `${knowledge.defects.length} (listed below)` : 'none: no reconstruction behaved differently from its original'],
      ]),
      knowledge.gaps.length ? note('warn', `No plan handles: ${knowledge.gaps.map((g) => g.label).join(', ')}.`) : note('ok', 'Every transformation in the catalogue is handled by at least one plan.'),
    ], h('span.faint.mono', 'data/research')),
    adviceSection(now.advice, now.observed),
    matrixSection(summary),
    evaluationSection(knowledge),
    statementsSection(knowledge),
    studySection(knowledge),
    sourcesSection(knowledge),
  );
  if (knowledge.defects.length) root.append(section('Defects', h('ul.list', knowledge.defects.map((d) => h('li', `${d.verdict}: ${d.transform} · ${d.plan} · program ${d.programSeed}${d.difference ? ` (expected ${JSON.stringify(d.difference.reference)}, got ${JSON.stringify(d.difference.got)})` : ''}`)))));
  void fmtMs; void meter;
  return root;
}
