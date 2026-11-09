// The Research tab: what the laboratory measured, what that implies for the current input, and where the numbers come from.
//
// Every number here is read from data/research/ (summary.json, knowledge.json), which tools/lab/ writes from experiment records. Nothing is typed in.
// Text that came from a script (the observed signature of the current input) is only inserted as text.

import { h, pct, fmtMs } from './dom.js';
import { section, kv, note, meter, identificationSection } from './views.js';
import { supportClaim } from '../research/profiles.js';
import { buildPackage, pairFiles } from '../research/samples.js';
import { download } from './files.js';

export async function loadResearch() {
  const get = async (f) => {
    const res = await fetch(`data/research/${f}`, { cache: 'no-cache' });
    if (!res.ok) throw new Error(`data/research/${f}: HTTP ${res.status}`);
    return res.json();
  };
  const [summary, knowledge, families] = await Promise.all([get('summary.json'), get('knowledge.json'), get('custom-families.json')]);
  // compatibility profiles, the verified capabilities and the pipeline position of each system: optional, the lab results above do not depend on them
  const [profiles, capabilities, pipeline] = await Promise.all(['profiles.json', 'capabilities.json', 'pipeline.json'].map((f) => get(f).catch(() => null)));
  return { summary, knowledge, families, profiles, capabilities: capabilities ? capabilities.capabilities : null, pipeline: pipeline ? pipeline.report : null };
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
    note('', `Each cell is verified successes over trials: the reconstruction behaves exactly like the original program and is measurably closer to it, or shows fewer signs of obfuscation. ${summary.counts.experiments} experiments on ${summary.counts.programs} generated programs. Behaviour was decided as stated under "Behaviour checked in" above (a reference Lua runtime when it says so; this project's own interpreter otherwise). Hover a cell for the breakdown.`),
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

const CLAIM_BADGE = { supported: 'ok', partial: 'warn', 'identification-only': 'info', unknown: '' };
const CLAIM_LABEL = { supported: 'reconstruction verified', partial: 'reconstruction partly verified', 'identification-only': 'recognised only', unknown: 'researched only' };

function systemsSection(data) {
  const { profiles, pipeline } = data;
  if (!profiles) return null;
  const stage = (id, v) => { const r = pipeline && pipeline.find((x) => x.system === id && x.version === v); return r ? (r.reached || 'none') : '—'; };
  const rows = profiles.profiles.flatMap((p) => p.versions.map((v) => ({ p, v })));
  const luraph = profiles.profiles.find((p) => p.id === 'luraph');
  return section('Systems and versions', [
    note('', `What is known about each transformation system, version by version. "Reconstruction verified" needs output of the real tool (open-source tools only) or authorised pairs, behaviour decided on a reference Lua runtime, on at least ${profiles.gates.real.minBehaviourChecked} samples with a 95% lower bound of ${Math.round(profiles.gates.supportedRateLo * 100)}%. Recognising a system's output is a different and weaker claim, and is labelled so.`),
    h('table.steps', h('thead', h('tr', ['System', 'Version', 'Kind', 'Status', 'May be claimed', 'Pipeline', 'Samples'].map((x) => h('th', x)))), h('tbody', rows.map(({ p, v }) => {
      const c = supportClaim(p, v.id);
      return h('tr', { title: c.why }, [
        h('td', p.name), h('td', v.id === 'unversioned' ? '—' : v.label || v.id), h('td', p.kind), h('td', v.verification.status),
        h('td', h('span.badge.' + CLAIM_BADGE[c.claim], CLAIM_LABEL[c.claim])), h('td', stage(p.id, v.id)),
        h('td', v.samples.authorizedPairs ? `${v.samples.authorizedPairs} authorised` : v.samples.realOutput ? `${v.samples.realOutput} real output` : 'none'),
      ]);
    }))),
    luraph ? h('details', [
      h('summary', 'Luraph: what was found, version by version'),
      note('warn', 'No Luraph output could be obtained from a source the laboratory may use, so the engine has never been run on any, and nothing is claimed about reconstructing it. What follows is identification and documentation, each item with how it is known.'),
      ...luraph.versions.map((v) => h('details', [
        h('summary', `${v.label} (${v.period.since}${v.period.until ? ` to ${v.period.until}` : ' on'}): ${v.macros.all.length} macros`),
        h('ul.list', v.characteristics.map((c) => h('li', [c.text, h('div.faint', `${c.knownAs}${c.note ? `: ${c.note}` : c.basis ? `: ${c.basis}` : ''}`)]))),
        h('div', h('b', 'Not known or not done:')),
        h('ul', { style: { margin: '2px 0', paddingLeft: '16px' } }, v.limitations.map((l) => h('li', { style: { border: 0, padding: '1px 0' } }, l))),
      ])),
    ]) : null,
  ]);
}

function samplesSection() {
  const status = h('div');
  const file = h('input', { type: 'file', multiple: true, accept: '.lua,.luau,.txt' });
  const system = h('input', { type: 'text', placeholder: 'system, e.g. Luraph or my-tool' });
  const version = h('input', { type: 'text', placeholder: 'version the files claim, if any' });
  const who = h('input', { type: 'text', placeholder: 'who is supplying them' });
  const attest = h('textarea', { rows: 2, placeholder: 'In your own words: you wrote the originals and produced the protected files yourself, or you have the owner\'s permission to use both for this.' });
  const go = h('button.btn', { type: 'button', onclick: async () => {
    status.replaceChildren();
    try {
      const files = await Promise.all([...file.files].map(async (f) => ({ name: f.name, text: Array.from(new Uint8Array(await f.arrayBuffer()), (b) => String.fromCharCode(b)).join('') })));
      const { pairs, unpaired } = pairFiles(files);
      const built = await buildPackage({ system: system.value.trim(), claimedVersion: version.value.trim() || null, supplier: who.value.trim(), attestation: attest.value.trim(), pairs });
      if (!built.ok) { status.append(note('bad', built.problems.join(' '))); return; }
      download(`samples-${built.package.system.replace(/[^\w.-]+/g, '_')}.package.json`, JSON.stringify(built.package, null, 2), 'application/json');
      status.append(note('ok', `Package of ${pairs.length} pair${pairs.length === 1 ? '' : 's'} saved to your downloads. Nothing was uploaded.${unpaired.length ? ` Not paired and left out: ${unpaired.join(', ')}.` : ''}`));
    } catch (e) { status.append(note('bad', String(e.message || e))); }
  } }, 'Build package');
  return section('Your authorised samples', [
    note('', 'If you own a protected script and its original (or have the owner\'s permission), you can make them evidence. Name the files `<name>.original.lua` and `<name>.protected.lua`. This builds a package (hashes, your statement of permission) in your downloads; nothing leaves your machine. The package is then differential-tested on a real Lua runtime with `node tools/research/differential.mjs <package>`, because a browser cannot run one: a version can only be called verified once at least 8 pairs pass there.'),
    h('div.form-grid', [system, version, who, attest, file, go]),
    status,
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
    now.identification ? identificationSection(now.identification) : null,
    systemsSection(data),
    matrixSection(summary),
    evaluationSection(knowledge),
    statementsSection(knowledge),
    studySection(knowledge),
    sourcesSection(knowledge),
    samplesSection(),
  );
  if (knowledge.defects.length) root.append(section('Defects', h('ul.list', knowledge.defects.map((d) => h('li', `${d.verdict}: ${d.transform} · ${d.plan} · program ${d.programSeed}${d.difference ? ` (expected ${JSON.stringify(d.difference.reference)}, got ${JSON.stringify(d.difference.got)})` : ''}`)))));
  void fmtMs; void meter;
  return root;
}
