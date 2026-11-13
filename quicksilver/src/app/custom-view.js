// The Custom format tab: what an unfamiliar script was made into, the plan, what each capability said, what was recovered and what is left and why.
//
// Everything shown comes from src/custom/analyze.js. Text that came from a script (evidence lines quote its structure) is only ever inserted as text.

import { h, pct, fmtBytes } from './dom.js';
import { section, kv, note, meter, levelBadge } from './views.js';
import { download } from './files.js';

const STATUS_TEXT = { resolved: 'resolved', reduced: 'reduced', unresolved: 'not resolved' };
const STATUS_CLASS = { resolved: 'ok', reduced: 'warn', unresolved: 'bad' };

export async function loadExamples() {
  const res = await fetch('data/research/custom-examples.json', { cache: 'no-cache' });
  if (!res.ok) throw new Error(`data/research/custom-examples.json: HTTP ${res.status}`);
  return res.json();
}

export function customView(state, { onAnalyze, onCopy }) {
  const { result, examples, busy } = state;
  const head = h('div.codebar',
    h('button.btn.primary', { type: 'button', disabled: busy, onclick: onAnalyze }, busy ? 'Analysing…' : 'Analyse this script'),
    h('span.meta', 'Reads the structure, plans, runs the recovery and says what is left and why. Uses the script in the Deobfuscator tab.'));
  if (!result) return h('div.pad', head, note('', 'Paste or open a script, then press Analyse. This is not a lookup of tool names: the transformations are measured on the syntax tree and each comes with the evidence it was read from.'), evaluationNote(examples));
  if (!result.ok) return h('div.pad', head, section('The script could not be analysed', note('bad', `${result.error ? result.error.message : 'unknown error'}${result.error && result.error.line ? ` (line ${result.error.line})` : ''}`)));
  const r = result.result;
  const s = result.summary;
  return h('div.pad', head,
    section('Summary', [
      kv([
        ['Transformations found', String(s.transformations)],
        ['Resolved / reduced / not resolved', `${s.resolved} / ${s.reduced} / ${s.unresolved}`],
        ['Recovery', r.ok ? [levelBadge(r.level), ` score ${r.score == null ? '—' : r.score.toFixed(2)} · ${fmtBytes(r.bytes)} out · ${result.ms} ms`] : `no parsable output (${r.error})`],
      ]),
      r.ok && (r.level === 'low' || r.level === 'minimal' || r.level === 'none') ? note('warn', 'The transformations below may read as resolved while the engine’s own confidence in the result is low: the report in the Deobfuscator tab says why.') : null,
    ], r.ok && r.output ? h('button.btn.small', { type: 'button', onclick: () => onCopy(r.output) }, 'Copy recovered source') : null),
    section('What it shows', result.input.transformations.map((t) => h('div.row-item', h('div', h('b', t.id), ` — ${t.description}`, ' ', meter(t.confidence), h('span.meta', ` ${pct(t.confidence)}`)), h('ul', t.evidence.map((e) => h('li', e)))))),
    section('Explanation', result.explanation.length ? result.explanation.map((e) => h('div.row-item',
      h('div', h('b', e.transformation), ' ', h('span.badge.' + STATUS_CLASS[e.status], STATUS_TEXT[e.status])),
      h('ul', e.notes.map((n) => h('li', n))),
      e.status !== 'resolved' && e.remaining.length ? h('p.meta', `Still visible: ${e.remaining.join('; ')}`) : null)) : note('', 'No transformation reached the reporting threshold: the script looks plain, or its transformations are not ones the probes measure.')),
    result.introduced.length ? section('Introduced by the recovery', result.introduced.map((t) => h('div.row-item', h('b', t.transformation), h('ul', t.evidence.map((e) => h('li', e)))))) : null,
    section('Plan', result.plan.length ? result.plan.map((p) => h('div.row-item', h('div', h('b', p.transformation)), p.capabilities.length ? h('ul', p.capabilities.map((c) => h('li', `${c.step}: ${c.what}`))) : note('', 'no capability of the engine addresses it'))) : note('', 'nothing to plan')),
    result.readers.length ? section('Readers of virtual-machine formats, tried on this script', h('table.table', h('thead', h('tr', h('th', 'Reader'), h('th', 'Result'))), h('tbody', result.readers.map((x) => h('tr', h('td', x.reader), h('td', x.ok ? 'read the program' : x.reason)))))) : null,
    section('What the pipeline did', [
      r.applied.length ? h('p', 'Applied: ', r.applied.map((a) => `${a.id} ×${a.changed}`).join(', ')) : note('', 'No step changed the script.'),
      r.skipped.length ? h('ul', r.skipped.map((x) => h('li', `${x.id} (${x.status}): ${x.reason || 'did not apply'}`))) : null,
    ]),
    result.neighbors.length ? section('Closest validated examples', [
      h('table.table', h('thead', h('tr', h('th', 'Example'), h('th', 'Similarity'), h('th', 'Transformations'), h('th', 'What happened'))),
        h('tbody', result.neighbors.map((n) => h('tr', h('td', n.id), h('td', pct(n.similarity)), h('td', n.transformations.join(', ') || 'none'), h('td', `${n.outcome.level}${n.outcome.runtimeSame === true ? ', behaviour checked' : n.outcome.runtimeSame === false ? ', behaviour differs' : ''}`))))),
      evaluationNote(examples),
    ]) : evaluationNote(examples),
    h('p', h('button.btn.small', { type: 'button', onclick: () => download('analysis.json', JSON.stringify({ ...result, result: { ...r, output: undefined } }, null, 2), 'application/json') }, 'Download this analysis (JSON)')));
}

function evaluationNote(examples) {
  if (!examples || !examples.evaluation) return null;
  const e = examples.evaluation;
  return note('', `The examples are ${examples.counts.examples} scripts from ${examples.counts.tools} tools. How well the nearest one predicts a high or medium confidence result: ${pct(e.leaveOneOut.accuracy)} when other scripts of the same tool are available, ${pct(e.leaveOneToolOut.accuracy)} when none are (an unfamiliar format); always saying "yes" would be right ${pct(e.baseRate)} of the time.`);
}
