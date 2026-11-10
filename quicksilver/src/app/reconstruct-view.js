// The Reconstruct tab: send a protected script to the reconstruction service and read what comes back.
//
// Everything on this page is either something the person typed or chose, an event the service streamed, or the result it returned. Status badges come from
// the recorded runs in data/research/luraph-compat.json (src/reconstruct/status.js); the page never states support it cannot point to. Text that came from
// a script (the reconstruction, the log, diagnostics evidence) is only ever inserted as text.

import { h, replace, fmtBytes, pct } from './dom.js';
import { section, kv, note } from './views.js';
import { download } from './files.js';
import { ENGINES, VERSIONS, parseBanner, versionFor, plan as planFor, hasIronbrewHeader } from '../reconstruct/engines.js';
import { versionStatus, engineStatus, GATES } from '../reconstruct/status.js';
import { buildReconstructionReport } from '../reconstruct/report.js';
import { buildCaseFile } from '../reconstruct/casefile.js';

const STAGES = [
  ['identify', 'Identify the input'], ['select', 'Choose the engine'], ['run', 'Run in the instrumented environment'], ['lift', 'Lift the virtual machine'],
  ['structure', 'Rebuild control flow and names'], ['check', 'Check the output'], ['verify', 'Compare with the original'], ['report', 'Write the report'],
];
const STATUS_BADGE = { 'fully-tested': 'ok', 'partially-tested': 'info', experimental: 'warn', unsupported: 'bad' };
const STATUS_TEXT = { 'fully-tested': 'Fully tested', 'partially-tested': 'Partially tested', experimental: 'Experimental', unsupported: 'Unsupported' };
const KIND = {
  devirtualized: ['ok', 'Lifted from the virtual machine'], 'trace-assisted': ['warn', 'Built from a behaviour trace'], trace: ['warn', 'Behaviour trace only'], none: ['bad', 'No output'],
};
const VERIFY = { identical: ['ok', 'Identical to the original'], different: ['bad', 'Differs from the original'], inconclusive: ['warn', 'Not comparable'], 'not-run': ['', 'Not verified'] };
const SEV = { error: 'bad', warning: 'warn', info: 'info' };

function toBase64(bytes) {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  return btoa(s);
}
/** A cheap fingerprint of the input (FNV-1a over the bytes plus the length): enough to notice that the editor changed since a result was produced. */
const keyOf = (bytes) => { let h = 0x811c9dc5; for (let i = 0; i < bytes.length; i++) { h ^= bytes[i]; h = Math.imul(h, 0x01000193) >>> 0; } return `${bytes.length}:${h}`; };
const asLatin1 = (bytes) => { let s = ''; for (let i = 0; i < Math.min(bytes.length, 8192); i++) s += String.fromCharCode(bytes[i]); return s; };

export async function loadRegistry() {
  try {
    const res = await fetch('data/research/luraph-compat.json', { cache: 'no-cache' });
    return res.ok ? await res.json() : null;
  } catch { return null; }
}

/**
 * @param {{getEditorBytes: () => Uint8Array, getEditorName: () => string, toast: (m: string) => void, fetchImpl?: typeof fetch}} ctx
 */
export function createReconstructView(ctx) {
  const root = h('div.view.recon', { id: 'view-reconstruct' });
  const S = { bytes: null, name: 'script.lua', fromEditor: true, original: null, originalName: null, engine: 'auto', fallback: true, timeout: 90, attest: false,
    running: false, controller: null, stages: {}, attempts: [], fallbacks: [], log: [], ident: null, plan: null, result: null, error: null, tab: 'output', registry: null, started: 0, assistant: null, resultKey: null };
  const doFetch = ctx.fetchImpl || ((...a) => fetch(...a));

  const input = () => (S.fromEditor ? ctx.getEditorBytes() : S.bytes) || new Uint8Array(0);
  const inputName = () => (S.fromEditor ? ctx.getEditorName() : S.name) || 'script.lua';

  function localIdentity() {
    const bytes = input();
    const text = asLatin1(bytes);
    const banner = parseBanner(text);
    return { banner, text, size: bytes.length };
  }

  // ---- left: controls
  function controls() {
    const id = localIdentity();
    const row = versionFor(id.banner, id.text);
    const rowStatus = row && S.registry ? versionStatus(row, S.registry) : null;
    const steps = id.size ? planFor({ banner: id.banner, candidates: [], text: id.text }, S.engine, S.fallback) : [];

    const fileIn = h('input', { type: 'file', id: 'recon-file', accept: '.lua,.luau,.txt', onchange: async (e) => {
      const f = e.target.files[0];
      if (!f) return;
      S.bytes = new Uint8Array(await f.arrayBuffer()); S.name = f.name; S.fromEditor = false; S.result = null; S.error = null; resetRun(); render();
    } });
    const origIn = h('input', { type: 'file', id: 'recon-original', accept: '.lua,.luau,.txt', onchange: async (e) => {
      const f = e.target.files[0];
      S.original = f ? new Uint8Array(await f.arrayBuffer()) : null; S.originalName = f ? f.name : null; render();
    } });
    const engineSel = h('select', { id: 'recon-engine', onchange: (e) => { S.engine = e.target.value; render(); } },
      h('option', { value: 'auto', selected: S.engine === 'auto' }, 'Automatic (recommended)'),
      ...Object.values(ENGINES).filter((e) => e.id !== 'generic').map((e) => {
        const st = S.registry ? engineStatus((S.registry.records || []).filter((r) => r.engine === e.id)).status : null;
        return h('option', { value: e.id, selected: S.engine === e.id }, `${e.label}${st ? ` — ${STATUS_TEXT[st]}` : ''}`);
      }),
      h('option', { value: 'generic', selected: S.engine === 'generic' }, 'Behaviour trace only'));
    const timeoutSel = h('select', { id: 'recon-timeout', onchange: (e) => { S.timeout = Number(e.target.value); } },
      ...[60, 90, 180, 240].map((n) => h('option', { value: n, selected: S.timeout === n }, `${n} s`)));

    return h('div.recon-controls', [
      section('Input', [
        h('div.recon-input', [
          h('div', [h('b', inputName()), ' ', h('span.faint', id.size ? fmtBytes(id.size) : 'empty'), ' ', h('span.badge', S.fromEditor ? 'from the editor' : 'uploaded')]),
          h('div.recon-buttons', [
            h('label.btn.small', { for: 'recon-file' }, 'Upload a file'), fileIn,
            S.fromEditor ? null : h('button.btn.small', { type: 'button', id: 'recon-use-editor', onclick: () => { S.fromEditor = true; S.result = null; resetRun(); render(); } }, 'Use the editor instead'),
          ]),
        ]),
        id.size ? kv([
          ['Banner', id.banner ? h('span', [id.banner.text, h('div.faint', 'a comment: it says what the file claims, not what produced it')]) : hasIronbrewHeader(id.text) ? 'IronBrew 1 header' : 'none'],
          ['Version row', row ? row.label : 'not one this project tracks'],
          ['Compatibility', rowStatus ? h('span', [h('span.badge.' + STATUS_BADGE[rowStatus.status], STATUS_TEXT[rowStatus.status]), ' ', h('span.faint', rowStatus.reasons[0] || '')]) : '—'],
        ]) : note('', 'Paste a script in the Deobfuscator tab, or upload a file here.'),
      ]),
      section('Engine', [
        h('label.field', [h('span', 'Engine'), engineSel]),
        steps.length ? h('ol.recon-plan', steps.map((s) => h('li', [h('b', ENGINES[s.engine].label), s.mode === 'trace' ? h('span.badge.warn', 'trace') : null, s.nearest ? h('span.badge.warn', 'nearest engine') : null, h('div.faint', s.why)]))) : null,
        h('label.check', [h('input', { type: 'checkbox', id: 'recon-fallback', checked: S.fallback, onchange: (e) => { S.fallback = e.target.checked; render(); } }), ' Allow fallbacks (other engines of the same family, then a behaviour trace)']),
        h('label.field', [h('span', 'Time limit'), timeoutSel]),
      ]),
      section('Verify (optional)', [
        note('', 'If you have the unprotected original, add it. The service runs both on a real Luau runtime and compares what they print and return. Without it the result is readable but not verified.'),
        h('div', [h('label.btn.small', { for: 'recon-original' }, S.original ? 'Change original' : 'Add the original'), origIn, S.original ? h('span.faint', ` ${S.originalName} (${fmtBytes(S.original.length)})`) : null]),
      ]),
      section('Run', [
        h('label.check', [h('input', { type: 'checkbox', id: 'recon-attest', checked: S.attest, onchange: (e) => { S.attest = e.target.checked; render(); } }),
          ' I own this script or am authorised to analyse it. I understand the engine runs it in an isolated, emulated environment on the service.']),
        h('div.recon-buttons', [
          h('button.btn.primary', { type: 'button', id: 'recon-run', disabled: S.running || !id.size || !S.attest, onclick: run }, S.running ? 'Running…' : 'Reconstruct'),
          S.running ? h('button.btn', { type: 'button', id: 'recon-cancel', onclick: cancel }, 'Cancel') : null,
        ]),
        !S.attest ? h('div.faint', 'The attestation is required: the service executes the script.') : null,
      ]),
    ]);
  }

  // ---- right: stages, result
  function stagesBox() {
    const rows = STAGES.map(([sid, label]) => {
      const st = S.stages[sid];
      const state = st ? st.state : 'pending';
      return h('li', { class: `st-${state}`, dataset: { stage: sid, state } }, [
        h('span.dot'), h('span.name', (st && st.label) || label), st && st.detail ? h('span.faint.detail', String(st.detail).slice(0, 140)) : null,
      ]);
    });
    const attempts = S.attempts.length ? h('ul.recon-attempts', S.attempts.map((a) => h('li', [
      h('b', a.label), ' ', h('span.badge', a.mode), a.outcome ? h('span.badge.' + (a.outcome === 'output' ? 'ok' : 'bad'), a.outcome) : h('span.badge.info', 'running'), h('div.faint', a.why)]))) : null;
    return section('Progress', [h('ol.recon-stages', rows), attempts, S.error ? note('bad', S.error) : null]);
  }

  function resultBox() {
    const r = S.result;
    if (!r) return section('Result', note('', S.running ? 'Waiting for the service…' : 'The reconstruction appears here.'));
    if (!r.ok) {
      return section('Result', [note('bad', (r.error && r.error.message) || 'The reconstruction failed.'), diagnosticsList(r.diagnostics || []), logBox()]);
    }
    const k = KIND[r.kind] || ['', r.kind];
    const v = VERIFY[(r.verification && r.verification.status) || 'not-run'];
    const tabs = ['output', 'report', 'diagnostics', 'log', 'compatibility'];
    const tabLabel = { output: 'Reconstruction', report: 'Report', diagnostics: `Diagnostics${(r.diagnostics || []).length ? ` (${r.diagnostics.length})` : ''}`, log: 'Engine log', compatibility: 'Compatibility' };
    return section('Result', [
      h('div.recon-badges', [
        h('span.badge.' + k[0], { id: 'recon-kind', title: r.kind }, k[1]),
        h('span.badge', `${r.engine.label}${r.engine.mode === 'trace' ? ' (trace)' : ''}`),
        r.engine.nearest ? h('span.badge.warn', 'nearest engine, experimental') : null,
        h('span.badge.' + v[0], { id: 'recon-verify' }, v[1]),
        r.quality ? h('span.badge.' + (r.quality.grade === 'clean' ? 'ok' : 'warn'), `${r.quality.unresolvedTotal} unresolved`) : null,
        r.checks && r.checks.syntax ? h('span.badge.' + (r.checks.syntax.ok ? 'ok' : 'bad'), r.checks.syntax.ok ? 'valid Luau' : 'invalid syntax') : null,
      ]),
      r.kind !== 'devirtualized' ? note('warn', r.kind === 'trace' ? 'This is a behaviour trace: what the script did in one run, in order. It is not the program, and branches that did not run are absent.' : 'This was built from a behaviour trace after the lift was refused. Treat it as what one run did.') : null,
      r.verification && r.verification.status === 'not-run' ? note('', r.verification.reason) : null,
      r.verification && r.verification.status === 'inconclusive' ? note('warn', r.verification.reason) : null,
      r.verification && r.verification.status === 'different' ? note('bad', `${r.verification.reason}. Original: ${r.verification.original} / Reconstruction: ${r.verification.reconstruction}`) : null,
      r.verification && r.verification.status === 'identical' ? note('ok', `${r.verification.reason}. This holds for the run compared (${r.verification.runtime}); it is not a proof of equivalence.`) : null,
      h('div.recon-tabs', { role: 'tablist' }, tabs.map((t) => h('button.btn.small', { type: 'button', role: 'tab', 'aria-selected': String(S.tab === t), dataset: { tab: t }, onclick: () => { S.tab = t; render(); } }, tabLabel[t]))),
      S.tab === 'output' ? viewer(r) : S.tab === 'report' ? reportBox(r) : S.tab === 'diagnostics' ? h('div', [diagnosticsList(r.diagnostics || []), assistantBox(r)]) : S.tab === 'log' ? logBox() : compatBox(r),
    ]);
  }

  function viewer(r) {
    const code = r.output || '';
    const lines = code.split('\n');
    const base = (inputName().replace(/\.[^.]*$/, '') || 'script').replace(/[^\w.-]+/g, '_');
    return h('div', [
      h('div.recon-buttons', [
        h('button.btn.small', { type: 'button', id: 'recon-copy', onclick: async () => { try { await navigator.clipboard.writeText(code); ctx.toast('Copied.'); } catch { ctx.toast('Copy failed: your browser blocked the clipboard.'); } } }, 'Copy'),
        h('button.btn.small', { type: 'button', id: 'recon-download', onclick: () => download(`${base}.reconstructed.lua`, code, 'text/plain') }, 'Download .lua'),
        h('button.btn.small', { type: 'button', id: 'recon-download-report', onclick: () => download(`${base}.reconstruction.md`, report(), 'text/markdown') }, 'Download report (.md)'),
        h('button.btn.small', { type: 'button', onclick: () => download(`${base}.reconstruction.json`, JSON.stringify({ ...r, log: undefined }, null, 2), 'application/json') }, 'Download JSON'),
        h('span.faint', `${lines.length} lines`),
      ]),
      h('div.recon-code', { id: 'recon-code' }, [
        h('pre.gutter', lines.map((_, i) => i + 1).join('\n')),
        h('pre.code', code),
      ]),
    ]);
  }

  const report = () => buildReconstructionReport({ name: inputName(), result: S.result, registry: S.registry });
  const reportBox = () => h('pre.recon-report', report());

  function diagnosticsList(diags) {
    if (!diags.length) return note('ok', 'The engine reported nothing unusual.');
    return h('ul.list.recon-diags', diags.map((d) => h('li', [
      h('span.badge.' + (SEV[d.severity] || ''), d.severity), ' ', h('b', d.code), h('div', d.message), d.hint ? h('div.faint', d.hint) : null, d.evidence ? h('div.faint.mono', d.evidence) : null,
    ])));
  }
  function assistantBox(r) {
    const a = S.assistant;
    const kids = [h('h4', 'Research assistant'),
      note('', 'The rules above run on every result. The assistant is an optional model that reads a case file (what was identified, which engines ran and how, the engine log, the compatibility table; never your script) and PROPOSES hypotheses and experiments. Nothing it says is a finding until an experiment is run and recorded.'),
      h('div.recon-buttons', [
        h('button.btn.small', { type: 'button', id: 'recon-assist', disabled: !!(a && a.loading), onclick: () => askAssistant(r) }, a && a.loading ? 'Asking…' : 'Ask the research assistant'),
        h('button.btn.small', { type: 'button', id: 'recon-casefile', onclick: () => download('reconstruction.casefile.json', JSON.stringify(buildCaseFile(r, S.registry), null, 2), 'application/json') }, 'Download the case file')])];
    if (a && a.error) kids.push(note(a.unconfigured ? '' : 'bad', a.error));
    if (a && a.answer) {
      const x = a.answer;
      kids.push(h('div.recon-assistant', { id: 'recon-assistant-answer' }, [
        h('span.badge.warn', 'hypotheses, not findings'), ' ', h('span.faint', `model: ${x.model}`), h('p', x.summary),
        x.hypotheses.length ? h('div', [h('b', 'Hypotheses'), h('ul.list', x.hypotheses.map((q) => h('li', [q.claim, ' ', h('span.badge', q.confidence), q.evidence.map((e) => h('div.faint.mono', `“${e}”`))])))]) : null,
        x.experiments.length ? h('div', [h('b', 'Experiments that would test them'), h('ul.list', x.experiments.map((q) => h('li', [h('b', q.title), h('ol', q.steps.map((t) => h('li', t))), h('div.faint', `if true: ${q.ifTrue}`), h('div.faint', `if false: ${q.ifFalse}`)])))]) : null,
        x.engineChanges.length ? h('div', [h('b', 'Possible engine changes'), h('ul.list', x.engineChanges.map((q) => h('li', [q.target, ': ', q.change, h('div.faint', `risk: ${q.risk}`)])))]) : null,
        x.comparisons.length ? h('div', [h('b', 'Compared with other versions'), h('ul.list', x.comparisons.map((q) => h('li', [h('b', q.between), ': ', q.observation])))]) : null,
        x.dropped && x.dropped.length ? h('div.faint', `${x.dropped.length} suggestion(s) were discarded because the evidence they quoted is not in the case file.`) : null,
      ]));
    }
    return h('div.recon-assist', kids);
  }

  async function askAssistant(r) {
    S.assistant = { loading: true };
    renderLive();
    try {
      const check = await (await doFetch('api/assistant')).json().catch(() => null);
      if (!check || !check.configured) { S.assistant = { unconfigured: true, error: `The research assistant is not configured on this deployment${check && check.reason ? ` (${check.reason})` : ''}. You can download the case file and use any assistant you trust; the deterministic diagnostics above work without one.` }; return; }
      const res = await doFetch('api/assistant', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ case: buildCaseFile(r, S.registry) }) });
      const body = await res.json();
      S.assistant = body.ok ? { answer: body } : { error: (body.error && body.error.message) || `The assistant answered ${res.status}.` };
    } catch (e) { S.assistant = { error: String(e.message || e) }; } finally { renderLive(); }
  }

  const logBox = () => h('pre.recon-log', S.log.join('\n') || '(no engine output)');

  function compatBox(r) {
    if (!S.registry) return note('warn', 'The compatibility registry could not be loaded.');
    const ident = r.identification && r.identification.banner ? versionFor(parseBanner(r.identification.banner.text)) : null;
    return h('div', [
      note('', `Statuses are derived from ${S.registry.records.length} recorded run(s) on ${S.registry.skipped && S.registry.skipped.length ? 'the fixtures present' : 'every fixture'}; see data/research/luraph-compat.json. "Fully tested" needs at least ${GATES.full.minPairs} lifted runs compared identical with their originals on a real Luau runtime, none different.`),
      h('table.steps', h('thead', h('tr', ['Version', 'Engine', 'Status', 'Evidence'].map((x) => h('th', x)))), h('tbody', VERSIONS.map((v) => {
        const s = versionStatus(v, S.registry);
        return h('tr', { class: ident && ident.id === v.id ? 'me' : '' }, [h('td', v.label), h('td', v.engine ? ENGINES[v.engine].label : (v.nearest ? `none (${ENGINES[v.nearest].label} tried)` : 'none')),
          h('td', h('span.badge.' + STATUS_BADGE[s.status], STATUS_TEXT[s.status])), h('td.faint', s.reasons.join('; '))]);
      }))),
    ]);
  }

  // ---- running
  function resetRun() { S.stages = {}; S.attempts = []; S.fallbacks = []; S.log = []; S.ident = null; S.plan = null; S.result = null; S.error = null; S.tab = 'output'; }

  function onEvent(e) {
    if (e.t === 'stage') S.stages[e.id] = { ...(S.stages[e.id] || {}), ...e };
    else if (e.t === 'attempt') S.attempts.push({ label: e.label, mode: e.mode, why: e.why, outcome: null, engine: e.engine });
    else if (e.t === 'fallback') { const a = S.attempts[S.attempts.length - 1]; if (a) a.outcome = e.outcome; }
    else if (e.t === 'log') { if (S.log.length < 600) S.log.push(e.line); }
    else if (e.t === 'identification') S.ident = e;
    else if (e.t === 'plan') S.plan = e.steps;
    else if (e.t === 'result') {
      S.result = e;
      if (e.engine && e.engine.attempts) e.engine.attempts.forEach((a, i) => { if (S.attempts[i]) S.attempts[i].outcome = a.outcome; });
      if (e.log && e.log.length > S.log.length) S.log = e.log;
    }
  }

  async function run() {
    if (S.running) return;
    const bytes = input();
    resetRun();
    S.resultKey = keyOf(bytes);
    S.running = true; S.started = performance.now(); S.controller = new AbortController();
    render();
    try {
      const res = await doFetch('api/reconstruct', {
        method: 'POST', headers: { 'content-type': 'application/json' }, signal: S.controller.signal,
        body: JSON.stringify({ source_b64: toBase64(bytes), original_b64: S.original ? toBase64(S.original) : undefined, engine: S.engine, timeout_s: S.timeout, fallback: S.fallback, attest: S.attest }),
      });
      const type = res.headers.get('content-type') || '';
      if (!res.ok || !type.includes('ndjson')) {
        let msg = res.ok ? `The server answered ${res.status} with ${type || 'no content type'}, which is not the reconstruction service's stream (is /api/reconstruct routed to the Python function?).` : `The service answered ${res.status}.`;
        try { const j = await res.json(); if (j && j.error) msg = j.error.message; } catch { /* keep the status text */ }
        if (res.status === 404) msg = 'The reconstruction service is not available on this deployment (no /api/reconstruct).';
        throw new Error(msg);
      }
      const reader = res.body.getReader();
      const dec = new TextDecoder();
      let buf = '';
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        buf += dec.decode(value, { stream: true });
        let i;
        while ((i = buf.indexOf('\n')) >= 0) {
          const line = buf.slice(0, i); buf = buf.slice(i + 1);
          if (line.trim()) { try { onEvent(JSON.parse(line)); } catch { /* a partial or foreign line is ignored */ } }
        }
        renderLive();
      }
      if (buf.trim()) { try { onEvent(JSON.parse(buf)); } catch { /* ignore */ } }
      if (!S.result) S.error = 'The service ended without a result (it may have been stopped at its time limit).';
    } catch (e) {
      S.error = e.name === 'AbortError' ? 'Cancelled.' : String(e.message || e);
    } finally {
      S.running = false; S.controller = null; render();
    }
  }
  function cancel() { if (S.controller) S.controller.abort(); }

  // ---- drawing
  const left = h('div.recon-left');
  const right = h('div.recon-right');
  const progress = h('div'); const resultEl = h('div');
  right.append(progress, resultEl);
  root.append(h('div.recon-head', [h('h2', 'Reconstruct'), h('span.faint', 'Identify, lift and check a protected Luraph or IronBrew script. The engine runs the script in an isolated, emulated Roblox environment.')]), h('div.recon-grid', [left, right]));

  function renderLive() { replace(progress, stagesBox()); replace(resultEl, resultBox()); }
  function render() { replace(left, controls()); renderLive(); }

  return {
    root,
    async show() {
      if (!S.registry) S.registry = await loadRegistry();
      // a result belongs to the input it was made from: if the editor changed since, it is not shown as the result for the new text
      if (S.fromEditor && !S.running && (S.result || S.error) && S.resultKey !== keyOf(input())) resetRun();
      render();
    },
    // for tests and the page's other tabs
    state: S,
    setBytes(bytes, name) { S.bytes = bytes; S.name = name || 'script.lua'; S.fromEditor = false; resetRun(); render(); },
  };
}

void pct;
