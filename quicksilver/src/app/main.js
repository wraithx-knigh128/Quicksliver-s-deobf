// QuickSilver workbench: wires the engine (in a worker) to the interface.
//
// Rules this file keeps:
//   * the loaded file's bytes are never altered; edits in the editor replace them explicitly;
//   * nothing is executed unless the user switched the sandbox on and confirmed it;
//   * every operation is cancellable and time-limited;
//   * every string that came from a script is shown as text.

import { $, h, icon, clear, replace, toast, modal, fmtBytes, fmtMs, pct } from './dom.js';
import { Engine, EngineError } from './engine-client.js';
import { Viewer, LH } from './viewer.js';
import { DiffView } from './diffview.js';
import { TreeView } from './tree.js';
import { loadSettings, saveSettings, recoverOptions, indentString, DEFAULTS } from './settings.js';
import { LicenseState, showLicenseDialog } from './license-ui.js';
import { loadCompat, CompatDashboard } from './compat.js';
import { detectionView, analysisView, recoverySummary, detectionSummary, statusBadge, STATUS_LABEL } from './views.js';
import { makeZip } from './zip.js';
import { readFileBytes, download, baseName, FileRejected, ACCEPTED } from './files.js';
import { bytesToBinary, binaryToBytes, binaryToText, textToBinary } from '../core/bytes.js';

window.__qsReady = true;

const ENGINE_VERSION = '1.0.0';
const engine = new Engine();
const lic = new LicenseState();
let settings = loadSettings();
let compat = null;
let dashboard = null;
let compatById = new Map();

// ---- state ------------------------------------------------------------------------------------------------------------------------

const S = {
  name: 'untitled.lua',
  input: '',          // binary string; valid only while !dirty
  raw: null,          // Uint8Array of the opened file, while the editor still shows exactly it
  loadedText: '',
  dirty: false,
  version: 0,         // bumped whenever the input changes; results carry the version they belong to
  inspected: null,    // { version, result }
  detection: null,
  analysis: null,
  luast: null,
  trace: null,
  traceConsent: false,
  beautified: null,
  recovered: null,
  output: null,       // { text, label, kind }
  diff: null,
  tab: 'source',
  busy: null,
  lastError: null,
  notes: [],          // transient inspector notes
};

const TABS = [
  { id: 'source', label: 'Source' },
  { id: 'output', label: 'Output' },
  { id: 'compare', label: 'Compare' },
  { id: 'detection', label: 'Detection' },
  { id: 'analysis', label: 'Analysis' },
  { id: 'luast', label: 'Luast' },
  { id: 'compat', label: 'Compatibility' },
];

// ---- elements ------------------------------------------------------------------------------------------------------------------------

const el = {
  shell: $('#shell'), workspace: $('#workspace'), tabs: $('#tabs'), views: $('#views'), inspector: $('#inspector'),
  docname: $('#docname'), ver: $('#ver'), stState: $('#st-state'), stPos: $('#st-pos'), stSize: $('#st-size'), stSandbox: $('#st-sandbox'), stLicense: $('#st-license'),
  file: $('#file-input'), toollist: $('#toollist'), sideFilters: $('#side-filters'), sideCount: $('#side-count'), licenseLabel: $('#license-label'),
  btn: Object.fromEntries(['open', 'samples', 'detect', 'beautify', 'analyze', 'recover', 'trace', 'compare', 'export', 'cancel', 'clear'].map((k) => [k, $(`#act-${k}`)])),
};
el.ver.textContent = `v${ENGINE_VERSION}`;

// ---- views ---------------------------------------------------------------------------------------------------------------------------------

const views = {};

function emptyState(title, text, action) {
  return h('div.empty', h('b', title), h('span', text), action ? h('div', h('button.btn', { type: 'button', onclick: action.run }, action.label)) : null);
}

// Source: a plain textarea with a line-number gutter that follows its scroll
const editor = h('textarea.editor', {
  spellcheck: 'false', autocapitalize: 'off', autocomplete: 'off', wrap: 'off',
  'aria-label': 'Script source',
  placeholder: 'Paste Lua or Luau here, drop a .lua / .luau / .txt file, or press Open File.\n\nNothing you paste leaves this page, and nothing is executed.',
});
const gutterNums = h('div.nums');
const gutter = h('div.gutter', gutterNums);
const srcFind = h('input', { type: 'search', placeholder: 'Find', 'aria-label': 'Find in source' });
views.source = h('div.view', { id: 'view-source' },
  h('div.codebar', h('span', { id: 'src-info' }), h('span.grow'), srcFind),
  h('div.code-wrap', gutter, editor));
const srcInfo = views.source.querySelector('#src-info');

function lineCountOf(text) {
  let n = 1;
  for (let i = text.indexOf('\n'); i !== -1; i = text.indexOf('\n', i + 1)) n++;
  return n;
}
let sourceLines = 1;
function paintGutter() {
  const first = Math.floor(editor.scrollTop / LH);
  const count = Math.ceil(editor.clientHeight / LH) + 2;
  const last = Math.min(sourceLines, first + count);
  const nums = [];
  for (let i = first + 1; i <= last; i++) nums.push(i);
  gutterNums.textContent = nums.join('\n');
  gutterNums.style.transform = `translateY(${-(editor.scrollTop % LH)}px)`;
  gutterNums.style.lineHeight = `${LH}px`;
}
editor.addEventListener('scroll', paintGutter);
new ResizeObserver(paintGutter).observe(editor);

function caretPosition() {
  const pos = editor.selectionStart;
  const before = editor.value.slice(0, pos);
  const line = lineCountOf(before);
  const col = pos - (before.lastIndexOf('\n') + 1) + 1;
  return { line, col };
}
let caretRaf = 0;
function updateCaret() {
  if (caretRaf) return;
  caretRaf = requestAnimationFrame(() => {
    caretRaf = 0;
    if (S.tab !== 'source') { el.stPos.textContent = ''; return; }
    const { line, col } = caretPosition();
    el.stPos.textContent = `Ln ${line}, Col ${col}`;
  });
}
for (const ev of ['keyup', 'click', 'select', 'input', 'focus']) editor.addEventListener(ev, updateCaret);

editor.addEventListener('input', () => {
  S.dirty = true;
  sourceLines = lineCountOf(editor.value);
  paintGutter();
  invalidate();
});

function selectLine(line, col = 1) {
  const text = editor.value;
  let start = 0;
  for (let i = 1; i < line; i++) { const nl = text.indexOf('\n', start); if (nl < 0) break; start = nl + 1; }
  let end = text.indexOf('\n', start);
  if (end < 0) end = text.length;
  switchTab('source');
  editor.focus();
  editor.setSelectionRange(Math.min(start + Math.max(0, col - 1), end), end);
  editor.scrollTop = Math.max(0, (line - 1) * LH - editor.clientHeight / 3);
  paintGutter();
  updateCaret();
}

let srcFindFrom = 0;
srcFind.addEventListener('keydown', (e) => {
  if (e.key !== 'Enter') return;
  e.preventDefault();
  const q = srcFind.value.toLowerCase();
  if (!q) return;
  const text = editor.value.toLowerCase();
  let at = text.indexOf(q, e.shiftKey ? 0 : srcFindFrom);
  if (e.shiftKey) { let last = -1; for (let i = text.indexOf(q); i !== -1 && i < editor.selectionStart - 1; i = text.indexOf(q, i + 1)) last = i; at = last; }
  if (at < 0) at = text.indexOf(q);
  if (at < 0) { toast('No match'); return; }
  srcFindFrom = at + 1;
  editor.focus();
  editor.setSelectionRange(at, at + q.length);
  const line = lineCountOf(editor.value.slice(0, at));
  editor.scrollTop = Math.max(0, (line - 1) * LH - editor.clientHeight / 3);
  paintGutter();
});

// Output
const outViewer = new Viewer();
const outFind = h('input', { type: 'search', placeholder: 'Find', 'aria-label': 'Find in output' });
const outCount = h('span.faint.mono');
const outTitle = h('span');
views.output = h('div.view', { id: 'view-output' },
  h('div.codebar', outTitle, h('span.grow'), outCount, outFind,
    h('button.btn.small.icon', { type: 'button', title: 'Previous match', onclick: () => findOut(-1) }, icon('up')),
    h('button.btn.small.icon', { type: 'button', title: 'Next match', onclick: () => findOut(1) }, icon('down')),
    h('button.btn.small', { type: 'button', title: 'Copy the output to the clipboard', onclick: copyOutput }, icon('copy'), h('span.lbl', 'Copy'))),
  h('div#out-body.view', outViewer.root),
  h('div#out-empty.view', emptyState('No output yet', 'Beautify reformats the input. Recover runs the full pipeline.')));
function findOut(step) {
  const q = outFind.value;
  if (!q) { outCount.textContent = ''; return; }
  const r = outViewer.find(q, step);
  outCount.textContent = r.count ? `${r.index + 1} / ${r.count}` : 'no match';
}
outFind.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); findOut(e.shiftKey ? -1 : 1); } });
outFind.addEventListener('input', () => { outViewer.query = ''; findOut(1); });
async function copyOutput() {
  if (!S.output) return;
  try { await navigator.clipboard.writeText(binaryToText(S.output.text)); toast('Copied'); } catch { toast('The browser blocked clipboard access. Select the text and copy it manually.'); }
}

// Compare
const diffView = new DiffView();
const diffStats = h('div.diff-stats');
const foldBox = h('input', { type: 'checkbox', checked: true, id: 'fold-box' });
views.compare = h('div.view', { id: 'view-compare' },
  h('div.codebar', diffStats, h('span.grow'),
    h('label', { style: { display: 'inline-flex', gap: '6px', alignItems: 'center' } }, foldBox, 'Fold unchanged'),
    h('button.btn.small.icon', { type: 'button', title: 'Previous change', onclick: () => diffView.jump(-1) }, icon('up')),
    h('button.btn.small.icon', { type: 'button', title: 'Next change', onclick: () => diffView.jump(1) }, icon('down'))),
  h('div#cmp-heads.diff-row', { style: { height: '24px', borderBottom: '1px solid var(--line)', background: 'var(--bg)', color: 'var(--text-dim)' } },
    h('div.c', { style: { padding: '0 10px', alignItems: 'center' } }, h('span#cmp-left', 'Input')),
    h('div.c', { style: { padding: '0 10px', alignItems: 'center', borderRight: '0' } }, h('span', 'Recovered'))),
  h('div#cmp-body.view', diffView.root),
  h('div#cmp-empty.view', emptyState('Nothing to compare yet', 'Compare puts the input and the recovered code side by side. If nothing has been recovered it runs Recover first.')));
foldBox.addEventListener('change', () => diffView.setFold(foldBox.checked));

// Detection / Analysis / Luast / Compatibility
views.detection = h('div.view', { id: 'view-detection' });
views.analysis = h('div.view', { id: 'view-analysis' });
const tree = new TreeView();
const treeInfo = h('span');
views.luast = h('div.view', { id: 'view-luast' },
  h('div.codebar', treeInfo, h('span.grow'),
    h('button.btn.small', { type: 'button', onclick: () => tree.expandAll(5) }, 'Expand'),
    h('button.btn.small', { type: 'button', onclick: () => tree.collapseAll() }, 'Collapse')),
  h('div#luast-body.view', tree.root), h('div#luast-empty.view'));
views.compat = h('div.view', { id: 'view-compat' }, emptyState('Loading', 'Reading data/compat.json'));

for (const t of TABS) el.views.append(views[t.id]);

// ---- tabs ------------------------------------------------------------------------------------------------------------------------------------

const tabButtons = {};
for (const t of TABS) {
  const count = h('span.count');
  const b = h('button.tab', { type: 'button', role: 'tab', id: `tab-${t.id}`, 'aria-selected': 'false', 'aria-controls': `view-${t.id}`, onclick: () => switchTab(t.id) }, h('span', t.label), count);
  b._count = count;
  tabButtons[t.id] = b;
  el.tabs.append(b);
}
el.tabs.addEventListener('keydown', (e) => {
  if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
  const i = TABS.findIndex((t) => t.id === S.tab);
  switchTab(TABS[(i + (e.key === 'ArrowRight' ? 1 : TABS.length - 1)) % TABS.length].id);
  tabButtons[S.tab].focus();
});

function switchTab(id) {
  S.tab = id;
  for (const t of TABS) {
    const on = t.id === id;
    tabButtons[t.id].setAttribute('aria-selected', String(on));
    tabButtons[t.id].tabIndex = on ? 0 : -1;
    views[t.id].hidden = !on;
  }
  if (id === 'source') { paintGutter(); updateCaret(); } else el.stPos.textContent = '';
  if (id === 'output') outViewer.render();
  if (id === 'compare') diffView.render();
  if (id === 'luast') ensureLuast();
  if (id === 'detection' && !S.detection && inputPresent()) runDetect({ quiet: true });
  if (id === 'analysis' && !S.analysis && inputPresent()) runAnalyze({ quiet: true });
}

function setCount(id, text) { tabButtons[id]._count.textContent = text || ''; }

// ---- menus -----------------------------------------------------------------------------------------------------------------------------------

let openMenu = null;
function closeMenu() { if (openMenu) { openMenu.remove(); openMenu = null; } }
function showMenu(anchor, items) {
  closeMenu();
  const rect = anchor.getBoundingClientRect();
  const menu = h('div.menu', { role: 'menu' }, items.map((it) => it === '-'
    ? h('hr', { style: { border: 0, borderTop: '1px solid var(--line)', margin: '3px 0' } })
    : h('button', { type: 'button', role: 'menuitem', disabled: !!it.disabled, onclick: () => { closeMenu(); it.run(); } }, h('span', it.label), it.sub ? h('span.sub', it.sub) : null)));
  document.body.append(menu);
  const left = Math.min(rect.left, window.innerWidth - menu.offsetWidth - 8);
  menu.style.left = `${Math.max(8, left)}px`;
  menu.style.top = `${rect.bottom + 2}px`;
  openMenu = menu;
  const first = menu.querySelector('button:not(:disabled)');
  if (first) first.focus();
  menu.addEventListener('keydown', (e) => {
    const bs = [...menu.querySelectorAll('button:not(:disabled)')];
    const i = bs.indexOf(document.activeElement);
    if (e.key === 'ArrowDown') { e.preventDefault(); bs[(i + 1) % bs.length].focus(); }
    if (e.key === 'ArrowUp') { e.preventDefault(); bs[(i - 1 + bs.length) % bs.length].focus(); }
    if (e.key === 'Escape') { closeMenu(); anchor.focus(); }
  });
}
document.addEventListener('mousedown', (e) => { if (openMenu && !openMenu.contains(e.target) && !e.target.closest('[aria-haspopup]')) closeMenu(); });

// ---- input handling ----------------------------------------------------------------------------------------------------------------------

const inputPresent = () => editor.value.length > 0;

/** Exact bytes of the current input. Re-encodes the editor text only if it was edited. */
function getInput() {
  if (S.dirty) {
    if (S.raw && editor.value === S.loadedText) { S.input = bytesToBinary(S.raw); } else { S.input = textToBinary(editor.value); S.raw = null; }
    S.dirty = false;
  }
  return S.input;
}
function getInputBytes() {
  getInput();
  return S.raw || binaryToBytes(S.input);
}

function invalidate() {
  S.version++;
  S.inspected = null;
  S.detection = null; S.analysis = null; S.luast = null; S.trace = null; S.traceConsent = false; S.beautified = null; S.recovered = null; S.output = null; S.diff = null;
  S.notes = [];
  renderAll();
}

function loadBytes(name, bytes) {
  S.name = name;
  S.input = bytesToBinary(bytes);
  S.raw = bytes;
  editor.value = binaryToText(S.input);
  S.loadedText = editor.value;
  S.dirty = false;
  sourceLines = lineCountOf(editor.value);
  S.version++;
  S.inspected = null;
  S.detection = null; S.analysis = null; S.luast = null; S.trace = null; S.traceConsent = false; S.beautified = null; S.recovered = null; S.output = null; S.diff = null;
  S.notes = [];
  let lossy = false;
  try { new TextDecoder('utf-8', { fatal: true }).decode(bytes); } catch { lossy = true; }
  if (lossy) S.notes.push({ kind: 'info', text: 'This file contains bytes that are not valid UTF-8. The editor shows them as �, but every operation uses the file’s exact bytes until you edit the text.' });
  editor.scrollTop = 0;
  switchTab('source');
  renderAll();
  paintGutter();
}

async function openFile(file) {
  try {
    const bytes = await readFileBytes(file);
    if (lic.ent.maxBytes && bytes.length > lic.ent.maxBytes) {
      S.notes = [{ kind: 'warn', text: `Evaluation access is limited to ${fmtBytes(lic.ent.maxBytes)} of input; this file is ${fmtBytes(bytes.length)}.` }];
    }
    loadBytes(file.name, bytes);
    toast(`Opened ${file.name} (${fmtBytes(bytes.length)})`);
  } catch (e) {
    if (e instanceof FileRejected) toast(e.message, 6000); else toast(`Could not read the file: ${e.message}`, 6000);
  }
}

el.btn.open.addEventListener('click', () => el.file.click());
el.file.addEventListener('change', () => { const f = el.file.files[0]; el.file.value = ''; if (f) openFile(f); });

let dragDepth = 0;
window.addEventListener('dragenter', (e) => { if (e.dataTransfer && [...e.dataTransfer.types].includes('Files')) { dragDepth++; el.shell.classList.add('dropzone-active'); } });
window.addEventListener('dragleave', () => { dragDepth = Math.max(0, dragDepth - 1); if (!dragDepth) el.shell.classList.remove('dropzone-active'); });
window.addEventListener('dragover', (e) => { if (e.dataTransfer && [...e.dataTransfer.types].includes('Files')) e.preventDefault(); });
window.addEventListener('drop', (e) => {
  e.preventDefault();
  dragDepth = 0;
  el.shell.classList.remove('dropzone-active');
  const files = [...(e.dataTransfer?.files || [])];
  if (files.length > 1) toast('Only one file at a time; opening the first.');
  if (files[0]) openFile(files[0]);
});

el.btn.clear.addEventListener('click', () => {
  editor.value = '';
  S.name = 'untitled.lua'; S.raw = null; S.loadedText = ''; S.dirty = true; sourceLines = 1;
  invalidate();
  paintGutter();
  switchTab('source');
  editor.focus();
});

// ---- running operations ------------------------------------------------------------------------------------------------------------------

let ticker = 0;
function setBusy(label) {
  S.busy = label;
  for (const [k, b] of Object.entries(el.btn)) if (k !== 'cancel' && k !== 'clear') b.disabled = !!label;
  el.btn.cancel.hidden = !label;
  clearInterval(ticker);
  if (label) {
    const t0 = performance.now();
    const tick = () => { el.stState.textContent = `${label}… ${((performance.now() - t0) / 1000).toFixed(1)} s`; };
    el.stState.className = 'state-busy';
    tick();
    ticker = setInterval(tick, 200);
  }
}
el.btn.cancel.addEventListener('click', () => engine.cancel());

function setStatus(text, kind = '') { el.stState.textContent = text; el.stState.className = kind ? `state-${kind}` : ''; }

/**
 * Run one engine operation on the current input. Returns the result, or null when it did not run
 * (empty input, over the licence limit, cancelled, failed). Failures are reported, not thrown.
 */
async function run(op, options, label, { needsText = true, limits, source } = {}) {
  if (S.busy) return null;
  if (!inputPresent()) { toast('Nothing to process. Paste code or open a file first.'); switchTab('source'); editor.focus(); return null; }
  const input = source ?? getInput();
  if (lic.ent.maxBytes && input.length > lic.ent.maxBytes) {
    toast(`Evaluation access is limited to ${fmtBytes(lic.ent.maxBytes)} of input.`, 5000);
    return null;
  }
  setBusy(label);
  try {
    if (needsText) {
      if (!S.inspected || S.inspected.version !== S.version) S.inspected = { version: S.version, result: await engine.run('inspect', input, {}, { timeoutMs: 10_000 }) };
      const kind = S.inspected.result.kind;
      if (kind !== 'text') {
        S.notes = [{ kind: 'bad', text: S.inspected.result.message + (kind === 'bytecode' ? ' Detect can still describe the chunk header.' : '') }];
        setBusy(null); setStatus('Not source text', 'error'); renderInspector();
        return null;
      }
    }
    const result = await engine.run(op, input, options, limits);
    setBusy(null);
    setStatus(`${label} done in ${fmtMs(result.ms ?? 0)}`);
    return result;
  } catch (e) {
    setBusy(null);
    if (e instanceof EngineError && e.kind === 'cancelled') { setStatus('Cancelled'); return null; }
    setStatus(e instanceof EngineError && e.kind === 'timeout' ? 'Timed out' : 'Engine error', 'error');
    S.lastError = String(e.message || e);
    S.notes = [{ kind: 'bad', text: S.lastError.split('\n')[0] }];
    renderInspector();
    return null;
  }
}

// ---- actions ---------------------------------------------------------------------------------------------------------------------------------------

async function runDetect({ quiet = false } = {}) {
  const version = S.version;
  const r = await run('detect', {}, 'Detecting', { needsText: false });
  if (!r || version !== S.version) return null;
  S.detection = r.detection;
  renderAll();
  if (!quiet) switchTab('detection');
  return r;
}

async function runBeautify() {
  const version = S.version;
  const r = await run('beautify', { indent: indentString(settings), width: settings.width }, 'Beautifying');
  if (!r || version !== S.version) return null;
  if (!r.ok) {
    S.notes = [{ kind: 'bad', text: `Cannot beautify: ${r.error.line}:${r.error.col} ${r.error.message}.` }];
    renderAll();
    return r;
  }
  S.beautified = r;
  S.output = { text: r.output, label: r.mode === 'ast' ? 'Beautified' : 'Beautified (layout only)', kind: 'beautify' };
  S.notes = r.warnings.map((w) => ({ kind: 'warn', text: w, line: r.parseError ? r.parseError.line : null, col: r.parseError ? r.parseError.col : null }));
  renderAll();
  switchTab('output');
  return r;
}

async function runAnalyze({ quiet = false } = {}) {
  const version = S.version;
  const r = await run('analyze', {}, 'Analysing', { needsText: false });
  if (!r || version !== S.version) return null;
  S.analysis = r;
  if (r.detection) S.detection = r.detection;
  renderAll();
  if (!quiet) switchTab('analysis');
  return r;
}

async function runRecover({ quiet = false } = {}) {
  if (!lic.allow('recover')) { toast('Recovery is not part of this licence.'); return null; }
  const version = S.version;
  const allowSandbox = lic.allow('sandbox');
  const r = await run('recover', { ...recoverOptions(settings, { allowSandbox }), format: { indent: indentString(settings), width: settings.width } }, 'Recovering', { limits: { timeoutMs: 180_000 } });
  if (!r || version !== S.version) return null;
  S.recovered = r;
  S.detection = r.detection || S.detection;
  S.notes = [];
  if (r.output != null) {
    S.output = { text: r.output, label: 'Recovered', kind: 'recover' };
    S.beautified = S.beautified || null;
  } else {
    S.output = null;
    if (r.error) S.notes = [{ kind: 'bad', text: `Recovery stopped: ${r.error.message}`, line: r.error.line, col: r.error.col }];
  }
  renderAll();
  if (!quiet) switchTab(r.output != null ? 'output' : 'source');
  return r;
}

async function confirmTrace() {
  if (!lic.allow('sandbox')) { toast('The sandbox is not part of this licence.'); return false; }
  if (S.traceConsent) return true;
  const r = await modal({
    title: 'Run this script in the sandbox?',
    body: [
      h('p', { style: { margin: 0 } }, 'Trace runs the whole script, the way the Roblox client would, and writes down what it does: the services it asks for, the objects it creates, the properties it sets, the URLs it tries to fetch, the code it loads.'),
      h('ul', [
        h('li', 'It runs in QuickSilver’s own Lua interpreter inside a web worker, not in the browser’s JavaScript engine. The only things it can reach are stand-in Roblox objects made for the trace.'),
        h('li', 'Nothing is fetched, saved or sent. Network calls are recorded and answered with an empty chunk.'),
        h('li', 'Instruction, time, output and event limits apply, and Cancel stops it at any moment.'),
      ]),
      h('p.note.warn', 'The result is a description of one run, not the original source. Only run scripts you own or are authorised to analyse.'),
    ],
    buttons: [{ id: 'cancel', label: 'Cancel' }, { id: 'ok', label: 'Run in sandbox', primary: true }],
  });
  if (r === 'ok') S.traceConsent = true;
  return r === 'ok';
}

async function runTrace() {
  if (!inputPresent()) { toast('Nothing to trace. Paste code or open a file first.'); switchTab('source'); editor.focus(); return null; }
  if (!(await confirmTrace())) return null;
  const version = S.version;
  const r = await run('trace', { dialect: 'luau' }, 'Tracing', { limits: { timeoutMs: 60_000 } });
  if (!r || version !== S.version) return null;
  S.trace = r;
  S.notes = [];
  if (r.status === 'syntax-error') S.notes.push({ kind: 'bad', text: `The script does not parse, so it cannot run: ${r.error}` });
  S.output = { text: r.script, label: 'Behavioural trace', kind: 'trace' };
  renderAll();
  switchTab('output');
  return r;
}

async function runCompare() {
  if (!lic.allow('compare')) { toast('Compare is not part of this licence.'); return; }
  if (!inputPresent()) { toast('Nothing to compare. Paste code or open a file first.'); return; }
  if (!S.recovered) { const r = await runRecover({ quiet: true }); if (!r) return; }
  if (!S.recovered || S.recovered.output == null) { toast('Recovery produced no output, so there is nothing to compare.'); return; }
  let left = getInput();
  let leftLabel = 'Input (as opened)';
  if (settings.compareAgainst === 'formatted') {
    if (!S.beautified) {
      const version = S.version;
      const b = await run('beautify', { indent: indentString(settings), width: settings.width }, 'Formatting input');
      if (!b || version !== S.version) return;
      if (b.ok) S.beautified = b;
    }
    if (S.beautified && S.beautified.ok) { left = S.beautified.output; leftLabel = 'Input (re-formatted, nothing decoded)'; }
  }
  const version = S.version;
  const d = await run('diff', { other: S.recovered.output }, 'Comparing', { needsText: false, source: left });
  if (!d || version !== S.version) return;
  const split = (t) => binaryToText(t).split(/\r?\n/);
  S.diff = { ...d, leftLabel };
  diffView.setData(split(left), split(S.recovered.output), d.rows);
  renderAll();
  switchTab('compare');
}

async function ensureLuast() {
  const body = $('#luast-body', views.luast);
  const empty = $('#luast-empty', views.luast);
  if (!inputPresent()) { body.hidden = true; empty.hidden = false; replace(empty, emptyState('No script', 'Open or paste a script to see its syntax tree.')); return; }
  if (!S.luast) {
    const version = S.version;
    const r = await run('luast', { maxNodes: 40000 }, 'Building tree', { needsText: true });
    if (!r || version !== S.version) return;
    S.luast = r;
  }
  const r = S.luast;
  if (!r.ok) { body.hidden = true; empty.hidden = false; replace(empty, emptyState('No syntax tree', `The script does not parse: ${r.error.line}:${r.error.col} ${r.error.message}`)); treeInfo.textContent = ''; return; }
  body.hidden = false; empty.hidden = true;
  tree.setTree(r.tree, 2);
  treeInfo.textContent = `${r.nodes.toLocaleString()} nodes${r.truncated ? ' (truncated at 40,000)' : ''}`;
  setCount('luast', r.truncated ? '40k+' : String(r.nodes));
}

// ---- export -----------------------------------------------------------------------------------------------------------------------------------------

async function sha256Hex(bytes) {
  try {
    if (!crypto.subtle) return null;
    const d = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
    return [...d].map((b) => b.toString(16).padStart(2, '0')).join('');
  } catch { return null; }
}

async function buildReport() {
  const bytes = getInputBytes();
  return {
    tool: 'QuickSilver Deobfuscator',
    engine: ENGINE_VERSION,
    generatedAt: new Date().toISOString(),
    input: { name: S.name, bytes: bytes.length, sha256: await sha256Hex(bytes) },
    detection: S.detection,
    analysis: S.analysis && S.analysis.ok ? { summary: S.analysis.summary, indicators: S.analysis.indicators, urls: S.analysis.urls, webhooks: S.analysis.webhooks, apiUse: S.analysis.apiUse } : null,
    recovery: S.recovered ? {
      ok: S.recovered.ok,
      confidence: S.recovered.confidence || null,
      validation: S.recovered.validation || null,
      steps: (S.recovered.steps || []).map((s) => ({ id: s.id, label: s.label, status: s.status, changed: s.changed, rounds: s.rounds })),
      warnings: S.recovered.warnings || [],
      sandbox: !!(settings.sandbox && lic.allow('sandbox')),
    } : null,
  };
}

const ensureExport = () => {
  if (lic.allow('export')) return true;
  toast('Export is not included in evaluation access. Open Licence to add a key.', 5000);
  return false;
};

function exportItems() {
  const base = baseName(S.name);
  const rec = S.recovered && S.recovered.output != null ? S.recovered.output : null;
  const cur = S.output ? S.output.text : null;
  const save = (name, bin) => { if (ensureExport()) download(name, binaryToBytes(bin), 'text/plain'); };
  return [
    { label: 'Recovered code (.lua)', sub: `${base}.recovered.lua`, disabled: rec == null, run: () => save(`${base}.recovered.lua`, rec) },
    { label: 'Recovered code (.txt)', sub: `${base}.recovered.txt`, disabled: rec == null, run: () => save(`${base}.recovered.txt`, rec) },
    { label: 'Current output (.txt)', sub: S.output ? S.output.label : 'nothing shown', disabled: cur == null, run: () => save(`${base}.${S.output.kind}.txt`, cur) },
    { label: 'Trace listing (.lua)', sub: `${base}.trace.lua`, disabled: !S.trace, run: () => save(`${base}.trace.lua`, S.trace.script) },
    '-',
    { label: 'Report (.json)', sub: 'detection, confidence, passes', disabled: !S.detection && !S.recovered, run: async () => { if (ensureExport()) download(`${base}.report.json`, JSON.stringify(await buildReport(), null, 2), 'application/json'); } },
    { label: 'Bundle (.zip)', sub: 'original + recovered + report', disabled: !inputPresent(), run: exportBundle },
  ];
}

async function exportBundle() {
  if (!ensureExport()) return;
  const base = baseName(S.name);
  const orig = getInputBytes();
  const report = await buildReport();
  const enc = new TextEncoder();
  const entries = [{ name: `original/${S.name.replace(/[\\/]/g, '_')}`, data: orig }];
  if (S.recovered && S.recovered.output != null) entries.push({ name: `recovered/${base}.recovered.lua`, data: binaryToBytes(S.recovered.output) });
  if (S.trace) entries.push({ name: `recovered/${base}.trace.lua`, data: binaryToBytes(S.trace.script) });
  if (S.output && S.output.kind === 'beautify') entries.push({ name: `recovered/${base}.beautified.lua`, data: binaryToBytes(S.output.text) });
  entries.push({ name: 'report.json', data: enc.encode(JSON.stringify(report, null, 2)) });
  entries.push({ name: 'manifest.json', data: enc.encode(JSON.stringify({ tool: 'QuickSilver Deobfuscator', engine: ENGINE_VERSION, created: report.generatedAt, original: { path: entries[0].name, bytes: orig.length, sha256: report.input.sha256 }, files: entries.map((e) => ({ path: e.name, bytes: e.data.length })) }, null, 2)) });
  download(`${base}.quicksilver.zip`, makeZip(entries), 'application/zip');
}

el.btn.export.addEventListener('click', () => showMenu(el.btn.export, exportItems()));

// ---- samples --------------------------------------------------------------------------------------------------------------------------------------

let samples = null;
async function loadSamples() {
  if (samples) return samples;
  try {
    const res = await fetch('data/samples/index.json', { cache: 'no-cache' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    samples = await res.json();
  } catch (e) {
    samples = { groups: [] };
    toast(`Samples could not be loaded: ${e.message}`);
  }
  return samples;
}
el.btn.samples.addEventListener('click', async () => {
  const idx = await loadSamples();
  const items = [];
  for (const g of idx.groups) {
    if (items.length) items.push('-');
    items.push({ label: g.label, sub: g.note || '', disabled: true, run() {} });
    for (const s of g.items) items.push({
      label: `  ${s.label}`, sub: s.sub || '',
      async run() {
        try {
          const res = await fetch(`data/samples/${s.file}`);
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          loadBytes(s.file, new Uint8Array(await res.arrayBuffer()));
          if (s.note) { S.notes.push({ kind: 'info', text: s.note }); renderInspector(); }
        } catch (e) { toast(`Could not load the sample: ${e.message}`); }
      },
    });
  }
  showMenu(el.btn.samples, items);
});

// ---- inspector --------------------------------------------------------------------------------------------------------------------------------------

function noteEl(n) {
  const b = h('p.note' + (n.kind ? `.${n.kind}` : ''), n.text);
  if (n.line) b.append(' ', h('a', { href: '#', onclick: (e) => { e.preventDefault(); selectLine(n.line, n.col); } }, `go to ${n.line}:${n.col || 1}`));
  return b;
}

function renderInspector() {
  const parts = [];
  if (S.notes.length) parts.push(h('section.section', h('div.body', { style: { paddingTop: '10px' } }, S.notes.map(noteEl))));
  if (!inputPresent()) {
    parts.push(h('section.section', h('h3', h('span', 'Start')), h('div.body', [
      h('ol', { style: { margin: 0, paddingLeft: '18px' } }, [
        h('li', 'Open a .lua, .luau or .txt file, drop one on the window, or paste code into Source.'),
        h('li', 'Detect names the obfuscator and language dialect.'),
        h('li', 'Recover runs the pipeline; Compare shows what changed.'),
      ]),
      h('p.note.info', 'Scripts are parsed and rewritten as text. They are never run, unless you switch on the sandbox in Settings.'),
    ])));
  } else {
    const bytes = S.dirty ? editor.value.length : S.input.length;
    parts.push(h('section.section', h('h3', h('span', 'Document')), h('div.body', h('dl.kv', [
      h('dt', 'Name'), h('dd', S.name),
      h('dt', 'Size'), h('dd', `${fmtBytes(bytes)}${S.dirty ? '' : ''}, ${sourceLines} line${sourceLines === 1 ? '' : 's'}`),
      h('dt', 'Original'), h('dd', S.raw && !S.dirty ? 'exact bytes kept' : S.raw ? 'edited' : 'typed or pasted'),
    ]))));
  }
  if (S.detection) parts.push(...detectionSummary(S.detection, compatById));
  if (S.recovered) {
    parts.push(...recoverySummary(S.recovered));
    const hints = (S.recovered.confidence && S.recovered.confidence.hints) || [];
    if (hints.includes('trace') && lic.allow('sandbox')) {
      parts.push(h('section.section', h('h3', h('span', 'Code is still protected')), h('div.body', [
        h('p.note.warn', 'A virtual machine or embedded bytecode is still in the output, so the original control flow was not recovered. Trace can still list what the script does when it runs (services, objects, properties, requests).'),
        h('p', h('button.btn.primary', { type: 'button', onclick: () => runTrace() }, 'Trace in sandbox…')),
      ])));
    }
    if (hints.includes('sandbox') && lic.allow('sandbox')) {
      parts.push(h('section.section', h('h3', h('span', 'Encoded strings remain')), h('div.body', [
        h('p.note.warn', 'This script keeps its strings behind decoder functions. Evaluating them means running those functions, which QuickSilver only does inside its own interpreter sandbox and only if you allow it.'),
        h('p', h('button.btn.primary', { type: 'button', onclick: recoverWithSandbox }, 'Recover with sandbox…')),
      ])));
    }
  }
  if (S.trace) parts.push(traceSection());
  replace(el.inspector, parts);
}

function traceSection() {
  const t = S.trace;
  const kv = (rows) => h('dl.kv', rows.flatMap(([k, v]) => [h('dt', k), h('dd', v)]));
  const body = [
    kv([
      ['Ended', t.ended],
      ['Events', `${t.stats.events}${t.stats.truncated ? ' (truncated)' : ''}`],
      ['Calls / sets', `${t.stats.calls} / ${t.stats.sets}`],
      ['Handlers run', String(t.stats.handlers)],
      ['Chunks loaded', String(t.stats.loads)],
      ['Instructions', t.stats.fuelUsed.toLocaleString()],
    ]),
    h('p.note.warn', 'A trace describes this one run. It is not the original source, and code paths that did not run are absent.'),
  ];
  if (t.requests.length) body.push(h('div', [h('div.dim', `Requests recorded, not performed (${t.requests.length})`), h('ul.list.mono', t.requests.map((u) => h('li', { style: { overflowWrap: 'anywhere' } }, u)))]));
  if (t.layers.length) {
    body.push(h('div', [h('div.dim', 'Chunks the script loaded'), h('ul.list', t.layers.map((l) => h('li', [
      h('span.mono', `#${l.index}`), ` ${fmtBytes(l.source.length)} `,
      h('button.btn.small', { type: 'button', onclick: () => useLayer(l) }, 'Use as input'),
    ])))]));
  }
  if (t.undefinedGlobals.length) body.push(h('div', [h('div.dim', 'Globals it looked for and did not find'), h('p.mono', { style: { overflowWrap: 'anywhere', margin: '2px 0' } }, t.undefinedGlobals.join(', '))]));
  return h('section.section', h('h3', h('span', 'Trace')), h('div.body', body));
}

function useLayer(layer) {
  const bytes = binaryToBytes(layer.source);
  loadBytes(`${baseName(S.name)}.chunk${layer.index}.lua`, bytes);
  S.notes.push({ kind: 'info', text: `Chunk ${layer.index}, captured while tracing the previous script. It is now the input, so Detect, Recover and the rest apply to it.` });
  renderInspector();
}

async function recoverWithSandbox() {
  if (!settings.sandbox) { const ok = await confirmSandbox(); if (!ok) return; settings = { ...settings, sandbox: true }; saveSettings(settings); renderStatus(); }
  await runRecover();
}

async function confirmSandbox() {
  if (!lic.allow('sandbox')) { toast('The sandbox is not part of this licence.'); return false; }
  const r = await modal({
    title: 'Allow sandboxed evaluation?',
    body: [
      h('p', { style: { margin: 0 } }, 'Some obfuscators hide strings behind small decoder functions. To read them, QuickSilver can run just those functions.'),
      h('ul', [
        h('li', 'They run in QuickSilver’s own Lua interpreter inside a web worker. The script is not handed to the browser’s JavaScript engine and has no access to the page, the network, files, or any host function.'),
        h('li', 'Only the code needed by the decoder calls is run, under instruction, time and recursion limits. Anything that cannot be evaluated safely is left as it is.'),
        h('li', 'Results are accepted only if they come out identical when evaluated twice in different orders.'),
      ]),
      h('p.note.warn', 'You should still only analyse scripts you own or are authorised to analyse. This setting stays on until you turn it off in Settings.'),
    ],
    buttons: [{ id: 'cancel', label: 'Not now' }, { id: 'ok', label: 'Allow', primary: true }],
  });
  return r === 'ok';
}

// ---- settings dialog --------------------------------------------------------------------------------------------------------------------------------

async function showSettings() {
  const draft = { ...settings };
  const select = (key, options) => {
    const s = h('select', { 'aria-label': key }, options.map(([v, l]) => h('option', { value: String(v), selected: String(draft[key]) === String(v) }, l)));
    s.addEventListener('change', () => { draft[key] = typeof DEFAULTS[key] === 'number' ? Number(s.value) : s.value; });
    return s;
  };
  const number = (key, min, max, step = 1) => {
    const n = h('input', { type: 'number', min, max, step, value: draft[key], style: { width: '96px' } });
    n.addEventListener('change', () => { draft[key] = Number(n.value); });
    return n;
  };
  const sandboxBox = h('input', { type: 'checkbox', checked: draft.sandbox });
  const sandboxSwitch = h('label.switch', sandboxBox, h('i'));
  sandboxBox.addEventListener('change', async () => {
    if (sandboxBox.checked && !draft.sandbox) {
      const ok = await confirmSandbox();
      if (!ok) { sandboxBox.checked = false; return; }
    }
    draft.sandbox = sandboxBox.checked;
  });
  const field = (label, control, hint) => h('div.field', h('span', label), control, hint ? h('span.hint', hint) : null);
  const r = await modal({
    title: 'Settings',
    body: [
      h('div', [
        h('h4.dim', { style: { margin: '0 0 2px', font: '600 10.5px var(--ui)', letterSpacing: '.08em', textTransform: 'uppercase' } }, 'Formatting'),
        field('Indent', select('indent', [['2', '2 spaces'], ['4', '4 spaces'], ['tab', 'Tab']])),
        field('Line width', number('width', 40, 240, 10), 'Tables and call arguments wrap beyond this.'),
      ]),
      h('div', [
        h('h4.dim', { style: { margin: '0 0 2px', font: '600 10.5px var(--ui)', letterSpacing: '.08em', textTransform: 'uppercase' } }, 'Recovery'),
        field('Rename variables', select('rename', [['smart', 'Obfuscated names only'], ['all', 'All locals'], ['off', 'Off']]), 'Names are guesses from usage; the original names are not recoverable.'),
        field('Constant folding', select('foldCalls', [['obfuscation', 'Obfuscator-typical calls'], ['all', 'All pure library calls']])),
        field('Literal style', select('stringStyle', [['normalize', 'Normalise strings and numbers'], ['preserve', 'Keep as written']])),
        field('Maximum rounds', number('maxRounds', 1, 20)),
        field('Compare against', select('compareAgainst', [['formatted', 'Re-formatted input'], ['raw', 'Input as opened']]), 'A re-formatted input lines up with the output even when the original is minified.'),
      ]),
      h('div', [
        h('h4.dim', { style: { margin: '0 0 2px', font: '600 10.5px var(--ui)', letterSpacing: '.08em', textTransform: 'uppercase' } }, 'Sandbox'),
        field('Evaluate string decoders', sandboxSwitch, 'Off by default. Runs decoder functions in QuickSilver’s own interpreter, never in the browser.'),
        field('Instruction budget', number('sandboxFuel', 100000, 500000000, 1000000)),
        field('Time limit (ms)', number('sandboxTimeMs', 500, 60000, 500)),
      ]),
    ],
    buttons: [{ id: 'reset', label: 'Reset' }, { id: 'cancel', label: 'Cancel' }, { id: 'save', label: 'Save', primary: true }],
  });
  if (r === 'save') settings = { ...settings, ...draft };
  else if (r === 'reset') settings = { ...DEFAULTS, sidebar: settings.sidebar, inspector: settings.inspector };
  else return;
  saveSettings(settings);
  S.beautified = null; S.diff = null;
  renderStatus();
  toast('Settings saved');
}
$('#btn-settings').addEventListener('click', showSettings);
$('#btn-license').addEventListener('click', async () => { await showLicenseDialog(lic); renderStatus(); renderInspector(); });

// ---- layout toggles ---------------------------------------------------------------------------------------------------------------------------------

function applyLayout() {
  el.workspace.classList.toggle('no-side', !settings.sidebar);
  el.workspace.classList.toggle('no-inspector', !settings.inspector);
  $('#btn-side').setAttribute('aria-pressed', String(settings.sidebar));
  $('#btn-inspector').setAttribute('aria-pressed', String(settings.inspector));
  $('#btn-side').classList.toggle('active', settings.sidebar);
  $('#btn-inspector').classList.toggle('active', settings.inspector);
}
$('#btn-side').addEventListener('click', () => { settings = { ...settings, sidebar: !settings.sidebar }; saveSettings(settings); applyLayout(); });
$('#btn-inspector').addEventListener('click', () => { settings = { ...settings, inspector: !settings.inspector }; saveSettings(settings); applyLayout(); });

// ---- sidebar: obfuscator list ---------------------------------------------------------------------------------------------------------------

let sideFilter = 'all';
function renderSidebar() {
  if (!compat) return;
  const fams = compat.families.filter((f) => sideFilter === 'all' || f.status === sideFilter)
    .sort((a, b) => ['supported', 'partial', 'experimental', 'unsupported'].indexOf(a.status) - ['supported', 'partial', 'experimental', 'unsupported'].indexOf(b.status) || a.name.localeCompare(b.name));
  const detected = new Set(((S.detection && S.detection.families) || []).filter((f) => f.confidence >= 0.5).map((f) => f.id));
  replace(el.toollist, fams.map((f) => h('li', {
    class: detected.has(f.id) ? 'sel' : '', tabindex: '0', title: `${f.name}: ${STATUS_LABEL[f.status]}`,
    onclick: () => { switchTab('compat'); dashboard.select(f.id); },
    onkeydown: (e) => { if (e.key === 'Enter') { switchTab('compat'); dashboard.select(f.id); } },
  }, h('span.st.' + f.status), h('span.name', f.name), detected.has(f.id) ? h('span.tag', 'detected') : null)));
  el.sideCount.textContent = String(fams.length);
  replace(el.sideFilters, ['all', 'supported', 'partial', 'experimental', 'unsupported'].map((s) => h('button.chip', { type: 'button', 'aria-pressed': String(sideFilter === s), onclick: () => { sideFilter = s; renderSidebar(); } }, s)));
}

// ---- rendering ----------------------------------------------------------------------------------------------------------------------------------------

function renderOutput() {
  const has = !!S.output;
  $('#out-body', views.output).hidden = !has;
  $('#out-empty', views.output).hidden = has;
  if (has) {
    const bytes = S.output.text.length;
    outTitle.textContent = `${S.output.label} · ${fmtBytes(bytes)}`;
    if (outViewer._for !== S.output) { outViewer._for = S.output; outViewer.setText(binaryToText(S.output.text)); outCount.textContent = ''; }
  } else { outTitle.textContent = 'Output'; outViewer._for = null; }
  setCount('output', has ? S.output.kind === 'recover' ? (S.recovered.confidence ? pct(S.recovered.confidence.score) : '') : '' : '');
}

function renderCompare() {
  const has = !!S.diff;
  $('#cmp-body', views.compare).hidden = !has;
  $('#cmp-empty', views.compare).hidden = has;
  $('#cmp-heads', views.compare).hidden = !has;
  if (has) {
    const st = S.diff.stats;
    replace(diffStats, h('span.a', `+${st.added + st.changed}`), h('span.d', `−${st.removed + st.changed}`), h('span', `${st.same.toLocaleString()} unchanged`), h('span.faint', `${S.diff.aLines.toLocaleString()} → ${S.diff.bLines.toLocaleString()} lines`));
    $('#cmp-left', views.compare).textContent = S.diff.leftLabel;
    setCount('compare', `${st.added + st.removed + st.changed}`);
  } else { replace(diffStats); setCount('compare', ''); }
}

function renderDetection() {
  const v = views.detection;
  if (!S.detection) { replace(v, emptyState('Not run yet', 'Detect names the obfuscator, the language dialect and the structural traits of the script.', inputPresent() ? { label: 'Detect now', run: () => runDetect() } : null)); setCount('detection', ''); return; }
  replace(v, detectionView(S.detection, compatById));
  const top = S.detection.families.find((f) => f.confidence >= 0.5);
  setCount('detection', top ? top.name : S.detection.dialect.label);
}

function renderAnalysis() {
  const v = views.analysis;
  if (!S.analysis) { replace(v, emptyState('Not run yet', 'Analyze reports APIs, URLs, structure and indicators from the syntax tree, without running anything.', inputPresent() ? { label: 'Analyze now', run: () => runAnalyze() } : null)); setCount('analysis', ''); return; }
  replace(v, analysisView(S.analysis));
  setCount('analysis', S.analysis.ok ? String(S.analysis.indicators.length || '') : 'error');
}

function renderStatus() {
  const bytes = !inputPresent() ? 0 : S.dirty ? editor.value.length : S.input.length;
  el.docname.replaceChildren(h('b', S.name), inputPresent() ? `  ·  ${fmtBytes(bytes)}` : '');
  el.stSize.textContent = inputPresent() ? `${fmtBytes(bytes)} · ${sourceLines} lines${S.detection ? ` · ${S.detection.dialect.label}` : ''}` : '';
  const sandboxOn = settings.sandbox && lic.allow('sandbox');
  el.stSandbox.textContent = sandboxOn ? 'sandbox: on' : 'sandbox: off';
  el.stSandbox.className = sandboxOn ? 'state-busy' : 'faint';
  el.stLicense.textContent = lic.label();
  el.licenseLabel.textContent = lic.label();
  srcInfo.textContent = inputPresent() ? `${S.name}${S.raw && !S.dirty ? ' · bytes preserved' : ''}` : 'Source';
}

function renderAll() {
  renderStatus();
  renderOutput();
  renderCompare();
  renderDetection();
  renderAnalysis();
  renderInspector();
  renderSidebar();
  if (S.tab === 'luast') ensureLuast();
}

// ---- wiring -----------------------------------------------------------------------------------------------------------------------------------------------

el.btn.detect.addEventListener('click', () => runDetect());
el.btn.beautify.addEventListener('click', () => runBeautify());
el.btn.analyze.addEventListener('click', () => runAnalyze());
el.btn.recover.addEventListener('click', () => runRecover());
el.btn.trace.addEventListener('click', () => runTrace());
el.btn.compare.addEventListener('click', () => runCompare());

document.addEventListener('keydown', (e) => {
  if (e.defaultPrevented) return;
  const key = e.key.toLowerCase();
  if ((e.ctrlKey || e.metaKey) && key === 'o') { e.preventDefault(); el.file.click(); }
  else if ((e.ctrlKey || e.metaKey) && key === 'enter') { e.preventDefault(); if (!S.busy) runRecover(); }
  else if (e.altKey && !e.ctrlKey && !e.metaKey) {
    const map = { KeyD: runDetect, KeyB: runBeautify, KeyA: runAnalyze, KeyR: runRecover, KeyT: runTrace, KeyC: runCompare, KeyE: () => showMenu(el.btn.export, exportItems()) };
    if (map[e.code]) { e.preventDefault(); if (!S.busy) map[e.code](); }
  } else if (key === 'f' && (e.ctrlKey || e.metaKey) && (S.tab === 'output' || S.tab === 'source')) {
    e.preventDefault();
    (S.tab === 'output' ? outFind : srcFind).focus();
  }
});

lic.onchange = () => { renderStatus(); renderInspector(); };

async function start() {
  applyLayout();
  switchTab('source');
  renderAll();
  paintGutter();
  lic.refresh().catch(() => {});
  try {
    compat = await loadCompat();
    compatById = new Map(compat.families.map((f) => [f.id, f]));
    dashboard = new CompatDashboard(compat);
    replace(views.compat, dashboard.root);
    setCount('compat', String(compat.families.length));
    renderSidebar();
    renderInspector();
  } catch (e) {
    replace(views.compat, emptyState('Compatibility data unavailable', String(e.message || e)));
  }
  // `?sample=<file>` opens a bundled sample (handy for links in bug reports)
  const q = new URLSearchParams(location.search).get('sample');
  if (q && /^[\w.-]+$/.test(q)) {
    try {
      const res = await fetch(`data/samples/${q}`);
      if (res.ok) loadBytes(q, new Uint8Array(await res.arrayBuffer()));
    } catch { /* ignore */ }
  }
}
start();
