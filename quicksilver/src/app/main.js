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
import { HighlightLayer } from './hl-layer.js';
import { ExamplesBoard } from './examples.js';
import { DiffView } from './diffview.js';
import { TreeView } from './tree.js';
import { loadSettings, saveSettings, recoverOptions, indentString, DEFAULTS } from './settings.js';
import { LicenseState, showLicenseDialog } from './license-ui.js';
import { loadCompat, CompatDashboard } from './compat.js';
import { detectionView, analysisView, recoverySummary, detectionSummary, statusBadge, STATUS_LABEL } from './views.js';
import { makeZip } from './zip.js';
import { showHelp } from './help.js';
import { originView } from './origin-view.js';
import { mergeOnline, originAnalysis } from '../origin/index.js';
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
  dump: null,
  origin: null,       // { subject, analysis }
  originOnline: null,
  originBusy: false,
  originSubject: 'auto',
  beautified: null,
  recovered: null,
  outputs: {},        // kind -> { text, label, kind }; the right-hand pane shows outputs[show]
  show: null,
  output: null,       // = outputs[show]
  diff: null,
  tab: 'work',
  busy: null,
  lastError: null,
  notes: [],          // transient inspector notes
};

const TABS = [
  { id: 'work', label: 'Deobfuscator' },
  { id: 'compare', label: 'Compare' },
  { id: 'detection', label: 'Detection' },
  { id: 'analysis', label: 'Analysis' },
  { id: 'origin', label: 'AI check' },
  { id: 'luast', label: 'Luast' },
  { id: 'examples', label: 'Examples' },
  { id: 'compat', label: 'Obfuscators' },
];

// ---- elements ------------------------------------------------------------------------------------------------------------------------

const el = {
  shell: $('#shell'), workspace: $('#workspace'), tabs: $('#tabs'), views: $('#views'), inspector: $('#inspector'),
  docname: $('#docname'), ver: $('#ver'), stState: $('#st-state'), stPos: $('#st-pos'), stSize: $('#st-size'), stSandbox: $('#st-sandbox'), stLicense: $('#st-license'),
  file: $('#file-input'), toollist: $('#toollist'), sideFilters: $('#side-filters'), sideCount: $('#side-count'),
  btn: {
    ...Object.fromEntries(['open', 'link', 'samples', 'detect', 'beautify', 'rename', 'dump', 'origin', 'help', 'analyze', 'recover', 'trace', 'compare', 'export', 'cancel', 'clear'].map((k) => [k, $(`#act-${k}`)])),
    ...Object.fromEntries(['luraph', 'ironbrew', 'moonveil'].map((k) => [k, $(`#tool-${k}`)])),
  },
};
el.ver.textContent = `v${ENGINE_VERSION}`;

// ---- views ---------------------------------------------------------------------------------------------------------------------------------

const views = {};

function emptyState(title, text, action) {
  return h('div.empty', h('b', title), h('span', text), action ? h('div', h('button.btn', { type: 'button', onclick: action.run }, action.label)) : null);
}

// Workbench: obfuscated source on the left (editable), deobfuscated source on the right (read-only).
const editor = h('textarea.editor', {
  spellcheck: 'false', autocapitalize: 'off', autocomplete: 'off', wrap: 'off',
  'aria-label': 'Obfuscated source',
});
const gutterNums = h('div.nums');
const gutter = h('div.gutter', gutterNums);
const srcFind = h('input', { type: 'search', placeholder: 'Find', 'aria-label': 'Find in the obfuscated source' });
const srcMeta = h('span.meta');
const wrapBtn = h('button.btn.small', { type: 'button', 'aria-pressed': 'false', title: 'Wrap long lines (minified scripts are one very long line)', onclick: () => setWrap(!settings.wrap) }, 'Wrap');
const hl = new HighlightLayer(editor);
// What the top editor says while it is empty: what this page is for, and the two ways to start
const hero = h('div.hero',
  h('h2', 'Paste obfuscated Lua.', h('span', 'Get readable code back.')),
  h('div.hero-actions',
    h('button.btn.primary.big', { type: 'button', onclick: () => el.file.click() }, 'Open file'),
    h('button.drop', { type: 'button', onclick: () => el.btn.samples.click() }, 'Load an example script')),
  h('p.fine', 'Runs in your browser. Nothing is uploaded and nothing is executed.'));
const codeWrap = h('div.code-wrap', gutter, h('div.edit-stack', hl.root, editor, hero));
const maxButtons = {};
function maxButton(which) {
  const b = h('button.btn.small.icon', { type: 'button', 'aria-pressed': 'false', title: 'Give this editor the whole height (double-click its title bar too)', 'aria-label': 'Maximise this editor', onclick: () => toggleMax(which) }, icon('max'));
  maxButtons[which] = b;
  return b;
}
const leftCol = h('section.col', { 'aria-label': 'Obfuscated source' },
  h('header.col-head', { ondblclick: (e) => { if (e.target.closest('input,button')) return; toggleMax('top'); } },
    h('h2', 'Obfuscated source'), srcMeta, h('span.grow'), srcFind, wrapBtn, maxButton('top')),
  codeWrap);
function setWrap(on) {
  settings = { ...settings, wrap: on };
  saveSettings(settings);
  editor.wrap = on ? 'soft' : 'off';
  codeWrap.classList.toggle('wrapped', on);
  hl.setEnabled(!on);
  wrapBtn.setAttribute('aria-pressed', String(on));
}

function lineCountOf(text) {
  let n = 1;
  for (let i = text.indexOf('\n'); i !== -1; i = text.indexOf('\n', i + 1)) n++;
  return n;
}
let sourceLines = 1;
let gutterFirst = -1;
let gutterLast = -1;
function paintGutter(force = false) {
  if (settings.wrap) return; // wrapped lines no longer map one to one onto numbers
  const first = Math.floor(editor.scrollTop / LH);
  // the sub-line offset moves on every scroll event; the numbers themselves only change when a new line enters
  gutterNums.style.transform = `translate3d(0, ${-(editor.scrollTop % LH)}px, 0)`;
  const count = Math.ceil(editor.clientHeight / LH) + 2;
  const last = Math.min(sourceLines, first + count);
  if (!force && first === gutterFirst && last === gutterLast) return;
  gutterFirst = first; gutterLast = last;
  const nums = [];
  for (let i = first + 1; i <= last; i++) nums.push(i);
  gutterNums.textContent = nums.join('\n');
  gutterNums.style.lineHeight = `${LH}px`;
}
editor.addEventListener('scroll', () => paintGutter(), { passive: true });
new ResizeObserver(() => paintGutter(true)).observe(editor);

function caretPosition() {
  const pos = editor.selectionStart;
  const before = editor.value.slice(0, pos);
  const line = lineCountOf(before);
  const col = pos - (before.lastIndexOf('\n') + 1) + 1;
  return { line, col };
}
let caretTimer = 0;
function updateCaret() {
  if (caretTimer) return;
  // a long file makes the line/column count a measurable cost, so it is done at most a few times a second
  caretTimer = setTimeout(() => {
    caretTimer = 0;
    if (S.tab !== 'work') { el.stPos.textContent = ''; return; }
    const { line, col } = caretPosition();
    el.stPos.textContent = `Ln ${line}, Col ${col}`;
    hl.setCaretLine(inputPresent() ? line : 0);
  }, editor.value.length > 400_000 ? 250 : 30);
}
for (const ev of ['keyup', 'click', 'select', 'input', 'focus']) editor.addEventListener(ev, updateCaret);

editor.addEventListener('input', () => {
  S.dirty = true;
  sourceLines = lineCountOf(editor.value);
  hl.invalidate();
  paintGutter(true);
  invalidate();
  scheduleAutoDetect(900);
});

function selectLine(line, col = 1) {
  const text = editor.value;
  let start = 0;
  for (let i = 1; i < line; i++) { const nl = text.indexOf('\n', start); if (nl < 0) break; start = nl + 1; }
  let end = text.indexOf('\n', start);
  if (end < 0) end = text.length;
  switchTab('work');
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

// Right-hand side: whichever result is selected (recovered, beautified, trace)
const outViewer = new Viewer();
const outFind = h('input', { type: 'search', placeholder: 'Find', 'aria-label': 'Find in the deobfuscated source' });
const outCount = h('span.count');
const outMeta = h('span.meta');
const outSwitch = h('div.seg', { role: 'group', 'aria-label': 'Which result to show' });
const rightCol = h('section.col', { 'aria-label': 'Deobfuscated source' },
  h('header.col-head', { ondblclick: (e) => { if (e.target.closest('input,button')) return; toggleMax('bottom'); } },
    h('h2', 'Deobfuscated source'), outSwitch, outMeta, h('span.grow'), outCount, outFind,
    h('button.btn.small.icon', { type: 'button', title: 'Previous match', 'aria-label': 'Previous match', onclick: () => findOut(-1) }, icon('up')),
    h('button.btn.small.icon', { type: 'button', title: 'Next match', 'aria-label': 'Next match', onclick: () => findOut(1) }, icon('down')),
    h('button.btn.small', { type: 'button', title: 'Copy the result to the clipboard', onclick: copyOutput }, icon('copy'), h('span.lbl', 'Copy')),
    maxButton('bottom')),
  h('div#out-body.view', outViewer.root),
  h('div#out-empty.view', emptyState('Nothing recovered yet', 'Paste or open an obfuscated script, then press Deobfuscate. Beautify only re-indents; it decodes nothing.')));
function findOut(step) {
  const q = outFind.value;
  if (!q) { outCount.textContent = ''; return; }
  const r = outViewer.find(q, step);
  outCount.textContent = r.count ? `${r.index + 1} / ${r.count}` : 'no match';
}
outFind.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); findOut(e.shiftKey ? -1 : 1); } });
outFind.addEventListener('input', () => { outViewer.query = ''; findOut(1); });
async function copyOutput() {
  if (!S.output) { toast('Nothing to copy yet.'); return; }
  try { await navigator.clipboard.writeText(binaryToText(S.output.text)); toast('Copied'); } catch { toast('The browser blocked clipboard access. Select the text and copy it manually.'); }
}

const splitter = h('div.splitter', { role: 'separator', 'aria-orientation': 'horizontal', 'aria-label': 'Resize the two sources', tabindex: '0', title: 'Drag to resize, double-click to reset' });
const panes = h('div.panes', leftCol, splitter, rightCol);
const noteBox = h('div.notes', { id: 'notes', role: 'status' });
const resultFacts = h('div.facts');
const resultActs = h('div.acts');
const resultBar = h('div.resultbar', { id: 'resultbar' }, resultFacts, resultActs);
// AI check: always in view under the editors, so nobody has to know there is a tab for it
const originBar = h('div.originbar', { id: 'originbar', role: 'status', 'aria-label': 'AI check' });
views.work = h('div.view.work', { id: 'view-work' }, noteBox, panes, originBar, resultBar);

/** One editor can take the whole height (the other keeps its text and comes back with the same button). */
function toggleMax(which) {
  const on = panes.dataset.max !== which;
  panes.dataset.max = on ? which : '';
  for (const [k, b] of Object.entries(maxButtons)) {
    const mine = on && k === which;
    b.setAttribute('aria-pressed', String(mine));
    b.replaceChildren(icon(mine ? 'restore' : 'max'));
    b.title = mine ? 'Show both editors again' : 'Give this editor the whole height (double-click its title bar too)';
    b.setAttribute('aria-label', mine ? 'Show both editors again' : 'Maximise this editor');
  }
  requestAnimationFrame(() => { paintGutter(true); outViewer.render(); hl.invalidate(); });
}

const SASH = 5;
function setSplit(top) {
  const r = Math.min(0.85, Math.max(0.15, top));
  panes.style.setProperty('--th', `${(r / (1 - r)).toFixed(4)}fr`);
  return r;
}
{
  const saved = settings.split;
  if (saved && saved !== 1) setSplit(saved / (1 + saved));
  const reset = () => { settings = { ...settings, split: DEFAULTS.split }; saveSettings(settings); setSplit(DEFAULTS.split / (1 + DEFAULTS.split)); };
  let drag = false;
  const move = (e) => {
    const box = panes.getBoundingClientRect();
    setSplit((e.clientY - box.top - SASH / 2) / (box.height - SASH));
  };
  splitter.addEventListener('pointerdown', (e) => { drag = true; splitter.setPointerCapture(e.pointerId); splitter.classList.add('drag'); e.preventDefault(); });
  splitter.addEventListener('pointermove', (e) => { if (drag) move(e); });
  const end = () => {
    if (!drag) return;
    drag = false; splitter.classList.remove('drag');
    const th = parseFloat(panes.style.getPropertyValue('--th')) || 1;
    settings = { ...settings, split: Number(th.toFixed(3)) }; saveSettings(settings);
  };
  splitter.addEventListener('pointerup', end);
  splitter.addEventListener('pointercancel', end);
  splitter.addEventListener('dblclick', reset);
  splitter.addEventListener('keydown', (e) => {
    if (e.key !== 'ArrowUp' && e.key !== 'ArrowDown') return;
    e.preventDefault();
    const cur = parseFloat(panes.style.getPropertyValue('--th')) || 1;
    const r = cur / (1 + cur) + (e.key === 'ArrowDown' ? 0.04 : -0.04);
    const top = setSplit(r);
    settings = { ...settings, split: Number((top / (1 - top)).toFixed(3)) }; saveSettings(settings);
  });
}

// Compare
const diffView = new DiffView();
const diffStats = h('div.diff-stats');
const foldBox = h('input', { type: 'checkbox', checked: true, id: 'fold-box' });
views.compare = h('div.view', { id: 'view-compare' },
  h('div.codebar', diffStats, h('span.grow'),
    h('label', foldBox, 'Fold unchanged'),
    h('button.btn.small.icon', { type: 'button', title: 'Previous change', 'aria-label': 'Previous change', onclick: () => diffView.jump(-1) }, icon('up')),
    h('button.btn.small.icon', { type: 'button', title: 'Next change', 'aria-label': 'Next change', onclick: () => diffView.jump(1) }, icon('down'))),
  h('div#cmp-heads.diff-row.diff-heads',
    h('div.c', h('span#cmp-left', 'Input')),
    h('div.c', h('span', 'Recovered'))),
  h('div#cmp-body.view', diffView.root),
  h('div#cmp-empty.view', emptyState('Nothing to compare yet', 'Compare puts the input and the recovered code side by side. If nothing has been recovered it runs Recover first.')));
foldBox.addEventListener('change', () => diffView.setFold(foldBox.checked));

// Detection / Analysis / Luast / Compatibility
views.detection = h('div.view', { id: 'view-detection' });
views.analysis = h('div.view', { id: 'view-analysis' });
views.origin = h('div.view', { id: 'view-origin' });
const tree = new TreeView();
const treeInfo = h('span');
views.luast = h('div.view', { id: 'view-luast' },
  h('div.codebar', treeInfo, h('span.grow'),
    h('button.btn.small', { type: 'button', onclick: () => tree.expandAll(5) }, 'Expand'),
    h('button.btn.small', { type: 'button', onclick: () => tree.collapseAll() }, 'Collapse')),
  h('div#luast-body.view', tree.root), h('div#luast-empty.view'));
views.compat = h('div.view', { id: 'view-compat' }, emptyState('Loading', 'Reading data/compat.json'));
// Examples: every bundled script with an offline check and a timer (wired to the engine further down, once the helpers exist)
const board = new ExamplesBoard({
  samples: () => loadSamples(),
  open: (item, recover) => openSample(item, recover),
  bench: (item) => benchSample(item),
  begin: (label) => { if (S.busy) { toast('Another operation is running.'); return false; } setBusy(label); return true; },
  end: () => { setBusy(null); setStatus('Timing finished'); },
  sandbox: () => !!(settings.sandbox && lic.allow('sandbox')),
  toggleSandbox: async () => {
    if (settings.sandbox) settings = { ...settings, sandbox: false };
    else { if (!(await confirmSandbox())) return; settings = { ...settings, sandbox: true }; }
    saveSettings(settings);
    renderStatus();
  },
});
board.root.id = 'view-examples';
views.examples = board.root;

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
  if (id === 'source' || id === 'output') id = 'work';
  S.tab = id;
  for (const t of TABS) {
    const on = t.id === id;
    tabButtons[t.id].setAttribute('aria-selected', String(on));
    tabButtons[t.id].tabIndex = on ? 0 : -1;
    views[t.id].hidden = !on;
  }
  if (id === 'work') { paintGutter(true); updateCaret(); outViewer.render(); hl.invalidate(); } else el.stPos.textContent = '';
  if (id === 'compare') diffView.render();
  if (id === 'luast') ensureLuast();
  if (id === 'examples') board.show();
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
    ? h('hr')
    : h('button' + (it.indent ? '.indent' : ''), { type: 'button', role: 'menuitem', disabled: !!it.disabled, onclick: () => { closeMenu(); it.run(); } }, h('span', it.label), it.sub ? h('span.sub', it.sub) : null)));
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

function clearResults() {
  S.version++;
  S.inspected = null;
  S.detection = null; S.analysis = null; S.luast = null; S.trace = null; S.traceConsent = false; S.beautified = null; S.recovered = null; S.diff = null;
  S.dump = null; S.origin = null; S.originOnline = null; S.originSubject = 'auto';
  S.outputs = {}; S.show = null; S.output = null;
  S.notes = [];
}

let statusRaf = 0;
function invalidate() {
  const had = !!(S.inspected || S.detection || S.analysis || S.luast || S.trace || S.beautified || S.recovered || S.output || S.diff || S.dump || S.origin || S.notes.length);
  clearResults();
  if (had) { renderAll(); return; }
  // typing into an untouched editor: only the counters change, and once per frame at most
  if (statusRaf) return;
  statusRaf = requestAnimationFrame(() => { statusRaf = 0; renderStatus(); renderResultBar(); });
}

let autoTimer = 0;
const AUTO_DETECT_MAX = 1_500_000;
/** Names the obfuscator shortly after the input changes. Static only, never blocks a button for long. */
function scheduleAutoDetect(delay = 700) {
  clearTimeout(autoTimer);
  autoTimer = setTimeout(async () => {
    if (!inputPresent() || S.detection || editor.value.length > AUTO_DETECT_MAX || editor.value.length < 12) return;
    if (S.busy) { scheduleAutoDetect(400); return; }
    await runDetect({ quiet: true });
  }, delay);
}

function loadBytes(name, bytes) {
  S.name = name;
  S.input = bytesToBinary(bytes);
  S.raw = bytes;
  editor.value = binaryToText(S.input);
  hl.invalidate();
  S.loadedText = editor.value;
  S.dirty = false;
  sourceLines = lineCountOf(editor.value);
  clearResults();
  let lossy = false;
  try { new TextDecoder('utf-8', { fatal: true }).decode(bytes); } catch { lossy = true; }
  if (lossy) S.notes.push({ kind: 'info', text: 'This file contains bytes that are not valid UTF-8. The editor shows them as �, but every operation uses the file’s exact bytes until you edit the text.' });
  editor.scrollTop = 0;
  switchTab('work');
  renderAll();
  paintGutter(true);
  scheduleAutoDetect(60);
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
  hl.invalidate();
  S.name = 'untitled.lua'; S.raw = null; S.loadedText = ''; S.dirty = true; sourceLines = 1;
  invalidate();
  paintGutter(true);
  switchTab('work');
  editor.focus();
});

// ---- running operations ------------------------------------------------------------------------------------------------------------------

// The timer in the title bar: counts while an operation runs, then keeps the time it took. The tooltip lists the last few.
const timerBox = $('#timer');
const timerText = $('#timer-text');
const timerOp = $('#timer-op');
const timings = [];
const fmtClock = (ms) => (ms < 60_000 ? `${(ms / 1000).toFixed(2)} s` : `${Math.floor(ms / 60_000)}:${String(Math.floor(ms / 1000) % 60).padStart(2, '0')}.${Math.floor((ms % 1000) / 100)}`);

let ticker = 0;
let runStart = 0;
let runLabel = '';
function setBusy(label) {
  S.busy = label;
  for (const [k, b] of Object.entries(el.btn)) if (k !== 'cancel' && k !== 'clear' && k !== 'help') b.disabled = !!label;
  el.btn.cancel.hidden = !label;
  clearInterval(ticker);
  if (label) {
    runStart = performance.now();
    runLabel = label;
    timerBox.classList.add('running');
    timerBox.classList.remove('done');
    timerOp.textContent = label;
    const tick = () => { timerText.textContent = fmtClock(performance.now() - runStart); };
    el.stState.textContent = `${label}…`;
    el.stState.className = 'state-busy';
    tick();
    ticker = setInterval(tick, 80);
  } else if (runStart) {
    const took = performance.now() - runStart;
    runStart = 0;
    timings.unshift({ label: runLabel, ms: took });
    timings.length = Math.min(timings.length, 8);
    timerBox.classList.remove('running');
    timerBox.classList.add('done');
    timerText.textContent = fmtClock(took);
    timerOp.textContent = runLabel;
    timerBox.title = `Time taken by the last operations (newest first):\n${timings.map((t) => `${fmtClock(t.ms).padStart(8)}  ${t.label}`).join('\n')}`;
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
  clearTimeout(autoTimer); // an action the user asked for supersedes the automatic detection that is still waiting to start
  if (!inputPresent()) { toast('Nothing to process. Paste code or open a file first.'); switchTab('work'); editor.focus(); return null; }
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
  autoOrigin();
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
  setOutput('beautify', { text: r.output, label: r.mode === 'ast' ? 'Beautified' : 'Beautified (layout only)', kind: 'beautify' });
  S.notes = r.warnings.map((w) => ({ kind: 'warn', text: w, line: r.parseError ? r.parseError.line : null, col: r.parseError ? r.parseError.col : null }));
  renderAll();
  switchTab('work');
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
    setOutput('recover', { text: r.output, label: 'Recovered', kind: 'recover' });
  } else {
    delete S.outputs.recover;
    if (S.show === 'recover') { S.show = Object.keys(S.outputs)[0] || null; S.output = S.show ? S.outputs[S.show] : null; }
    if (r.error) S.notes = [{ kind: 'bad', text: `Recovery stopped: ${r.error.message}`, line: r.error.line, col: r.error.col }];
  }
  autoOrigin();
  renderAll();
  if (!quiet) switchTab('work');
  return r;
}

function setOutput(kind, out) {
  S.outputs[kind] = out;
  S.show = kind;
  S.output = out;
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
  if (!inputPresent()) { toast('Nothing to trace. Paste code or open a file first.'); switchTab('work'); editor.focus(); return null; }
  if (!(await confirmTrace())) return null;
  const version = S.version;
  const r = await run('trace', { dialect: 'luau' }, 'Tracing', { limits: { timeoutMs: 60_000 } });
  if (!r || version !== S.version) return null;
  S.trace = r;
  S.notes = [];
  if (r.status === 'syntax-error') S.notes.push({ kind: 'bad', text: `The script does not parse, so it cannot run: ${r.error}` });
  setOutput('trace', { text: r.script, label: 'Behavioural trace', kind: 'trace' });
  renderAll();
  switchTab('work');
  return r;
}


// ---- more tools: rename, dump, the obfuscator buttons, link, origin ----------------------------------------------------------------

async function runRename() {
  const version = S.version;
  const r = await run('rename', { indent: indentString(settings), width: settings.width }, 'Renaming');
  if (!r || version !== S.version) return null;
  if (!r.ok) {
    S.notes = [{ kind: 'bad', text: `Cannot rename: ${r.error.line}:${r.error.col} ${r.error.message}. The script has to parse first; Beautify can still repair its layout.` }];
    renderAll();
    return r;
  }
  setOutput('rename', { text: r.output, label: 'Renamed', kind: 'rename' });
  S.notes = [{ kind: r.renamed ? 'ok' : 'info', text: r.renamed ? `${r.renamed} variable${r.renamed === 1 ? '' : 's'} renamed.` : 'Nothing to rename: the variable names already look like names a person chose.' }];
  renderAll();
  switchTab('work');
  return r;
}

async function confirmDump(name) {
  if (!lic.allow('sandbox')) { toast('The sandbox is not part of this licence.'); return false; }
  if (S.traceConsent) return true;
  const r = await modal({
    title: name ? `${name}: run it in the sandbox?` : 'Run this script in the sandbox?',
    body: [
      h('p', { style: { margin: 0 } }, 'Dump runs the script in QuickSilver’s own Lua interpreter and keeps the text it hands to loadstring and the long strings it joins with table.concat. That text is often the real script.'),
      h('ul', [
        h('li', 'It runs inside a web worker in an interpreter written for this tool, not in the browser’s JavaScript engine. It can only reach stand-in Roblox objects.'),
        h('li', 'Nothing is fetched, saved or sent. Network calls are recorded and answered with an empty chunk.'),
        h('li', 'Instruction and time limits apply, and Cancel stops it at any moment.'),
      ]),
      h('p.note.warn', 'Only run scripts you own or are authorised to analyse.'),
    ],
    buttons: [{ id: 'cancel', label: 'Cancel' }, { id: 'ok', label: 'Run in sandbox', primary: true }],
  });
  if (r === 'ok') S.traceConsent = true;
  return r === 'ok';
}

async function runDump({ name = '', consented = false } = {}) {
  if (!inputPresent()) { toast('Nothing to dump. Paste code or open a file first.'); switchTab('work'); editor.focus(); return null; }
  if (!consented && !(await confirmDump(name))) return null;
  S.traceConsent = true;
  const version = S.version;
  const r = await run('dump', { dialect: 'luau' }, 'Dumping', { limits: { timeoutMs: 120_000 } });
  if (!r || version !== S.version) return null;
  S.dump = r;
  S.notes = [];
  const best = r.candidates.find((c) => c.id === r.best);
  if (best) {
    setOutput('dump', { text: best.source, label: `Dump: ${best.label}`, kind: 'dump' });
    S.notes.push({ kind: best.parses ? 'ok' : 'info', text: `Captured ${r.candidates.length} piece${r.candidates.length === 1 ? '' : 's'} of text. Showing the ${best.label} (${fmtBytes(best.bytes)})${best.parses ? ', which parses as Lua' : ', which does not parse as Lua'}. Use “Use as input” in Details to work on another one.` });
  } else {
    S.notes.push({ kind: 'warn', text: 'The script did not load or join any text while it ran, so there is nothing to dump. Trace lists what it does instead.' });
  }
  if (r.status === 'limit') S.notes.push({ kind: 'warn', text: `The run stopped at the sandbox limit (${r.ended}). What was captured up to that point is shown; a heavy virtual machine may need more than this tool allows.` });
  else if (r.status === 'error') S.notes.push({ kind: 'warn', text: `The script stopped with an error inside the sandbox: ${r.error}` });
  else if (r.status === 'syntax-error') S.notes.push({ kind: 'bad', text: `The script does not parse, so it cannot run: ${r.error}` });
  renderAll();
  switchTab('work');
  return r;
}

/** Luraph and MoonVeil: say plainly what is possible, then dump (and trace if the dump found nothing). */
async function runVmTool(id, name) {
  if (!inputPresent()) { toast(`Nothing to process. Paste a ${name} script or open a file first.`); switchTab('work'); editor.focus(); return; }
  const d = await runDetect({ quiet: true });
  if (!d) return;
  const fam = d.detection.families.find((f) => f.id === id && f.confidence >= 0.5);
  const other = d.detection.families.find((f) => f.id !== id && f.confidence >= 0.5);
  const seen = fam ? `Detected: ${fam.name}${fam.version ? ` ${fam.version}` : ''} (${pct(fam.confidence)}).`
    : other ? `This does not look like ${name}: it matched ${other.name} (${pct(other.confidence)}). Use Deobfuscate for that.`
      : `No ${name} banner was found. ${id === 'luraph' ? 'Luraph v15 scripts carry no banner, so that proves nothing either way.' : ''}`;
  const r = await modal({
    title: `${name}`,
    body: [
      h('p', { style: { margin: 0 } }, seen),
      h('p', id === 'luraph'
        ? 'Luraph v14 / v15 turns a script into a private virtual machine whose instructions are different in every script. QuickSilver cannot turn that back into the original source, and no tool can promise to.'
        : 'MoonVeil compiles a script into a configurable virtual machine. QuickSilver can recognise it but cannot turn it back into the original source.'),
      h('p', 'What it can do is run the script in its sandbox and show you what comes out: the text the script builds and loads, and what it does (services, objects, URLs). Heavy scripts can run past the sandbox budget; then you get what was captured up to that point.'),
      h('p.note.warn', 'The script runs in QuickSilver’s own interpreter, never in the browser. Only run scripts you own or are authorised to analyse.'),
    ],
    buttons: [{ id: 'cancel', label: 'Cancel' }, { id: 'ok', label: 'Run in sandbox', primary: true }],
  });
  if (r !== 'ok') return;
  S.traceConsent = true;
  const dump = await runDump({ name, consented: true });
  if (dump && !dump.candidates.length && dump.status !== 'syntax-error') await runTrace();
}

async function runIronBrewTool() {
  if (!inputPresent()) { toast('Nothing to process. Paste an IronBrew script or open a file first.'); switchTab('work'); editor.focus(); return; }
  const d = await runDetect({ quiet: true });
  if (!d) return;
  const ib = d.detection.families.find((f) => f.id === 'ironbrew2' && f.confidence >= 0.5);
  let warning = null;
  if (!ib) {
    const other = d.detection.families.find((f) => f.confidence >= 0.5);
    warning = { kind: 'warn', text: `IronBrew 2 was not recognised${other ? ` (this looks like ${other.name})` : ''}. IronBrew 1 is not supported. The general deobfuscator ran instead.` };
  }
  const version = S.version;
  const r = await runRecover();
  if (warning && r && version === S.version) { S.notes.unshift(warning); renderAll(); }
}

async function openLinkDialog() {
  const input = h('input', { type: 'url', placeholder: 'https://raw.githubusercontent.com/user/repo/main/script.lua', 'aria-label': 'Link to the script', style: { width: '100%' } });
  const msg = h('p.note.info', { style: { margin: '8px 0 0' } }, 'Raw GitHub, gist, Pastebin, rentry, paste.ee and Discord attachment links work. A normal GitHub or Pastebin page link is turned into its raw link.');
  const r = await modal({
    title: 'Get a script from a link',
    body: [h('p', { style: { margin: '0 0 8px' } }, 'The link is fetched by this site’s server (your browser cannot fetch other sites directly) and the file is put in the editor. It is only read, never run.'), input, msg],
    buttons: [{ id: 'cancel', label: 'Cancel' }, { id: 'ok', label: 'Get file', primary: true }],
  });
  const url = input.value.trim();
  if (r !== 'ok' || !url) return;
  setBusy('Fetching');
  try {
    const res = await fetch(`/api/fetch?url=${encodeURIComponent(url)}`, { credentials: 'omit', referrerPolicy: 'no-referrer' });
    if (!res.ok) {
      let why = `The server answered ${res.status}.`;
      try { why = (await res.json()).error || why; } catch { if (res.status === 404) why = 'Fetching links needs the deployed site (its /api/fetch function). It is not available on this server.'; }
      toast(why, 7000);
      return;
    }
    const bytes = new Uint8Array(await res.arrayBuffer());
    const name = res.headers.get('x-qs-name') || 'download.lua';
    loadBytes(name, bytes);
    toast(`Fetched ${name} (${fmtBytes(bytes.length)})`);
  } catch (e) {
    toast(`Could not fetch the link: ${e.message}`, 7000);
  } finally { setBusy(null); }
}

/**
 * What the origin check looks at: the result on the right if there is one, otherwise the input. Code QuickSilver rebuilt
 * from an obfuscator (names, comments and layout are its own) says nothing about its author's style.
 */
function originSubject() {
  if (S.originSubject !== 'input' && S.output && S.output.kind !== 'trace') {
    const top = S.detection && S.detection.families.find((f) => f.confidence >= 0.5);
    const derived = S.output.kind === 'recover' && !!top;
    return { label: `the result in the right box (${S.output.label})`, text: S.output.text, derived, derivedFrom: top ? top.name : null };
  }
  return { label: 'the input', text: getInput(), derived: false };
}

async function runOrigin() {
  if (!inputPresent()) { toast('Nothing to check. Paste code or open a file first.'); switchTab('work'); editor.focus(); return null; }
  const subject = originSubject();
  const r = await run('origin', {}, 'Reading the style', { needsText: false, source: subject.text });
  if (!r) return null;
  setOrigin(subject, r);
  switchTab('origin');
  return r;
}

function setOrigin(subject, analysis) {
  S.origin = { subject: subject.label, text: subject.text, derived: subject.derived, derivedFrom: subject.derivedFrom, analysis };
  S.originOnline = null;
  renderOrigin();
}

/**
 * The AI reading happens by itself: it is local, a few milliseconds of text statistics, so it runs on the page (not in the worker, which a button
 * the person pressed may be using) as soon as the script is known. Large inputs wait for the button.
 */
const AUTO_ORIGIN_MAX = 400_000;
function autoOrigin() {
  if (!inputPresent() || S.dirty && editor.value.length > AUTO_ORIGIN_MAX) return;
  const subject = originSubject();
  if (subject.text.length > AUTO_ORIGIN_MAX) return;
  try { setOrigin(subject, originAnalysis(subject.text)); } catch { /* the reading is a hint; a failure leaves the bar empty */ }
}

async function searchOnline() {
  const o = S.origin;
  if (!o || !o.analysis.assessable) return;
  const lines = o.analysis.fingerprints;
  const ok = await modal({
    title: 'Search GitHub for these lines?',
    body: [
      h('p', { style: { margin: 0 } }, `These ${lines.length} line${lines.length === 1 ? '' : 's'} (shortened) will be sent to this site's server, which searches GitHub's public code for them. The rest of the script is not sent.`),
      h('ul.list.mono', { style: { maxHeight: '220px', overflow: 'auto', fontSize: '12px' } }, lines.map((l) => h('li', { style: { overflowWrap: 'anywhere' } }, l.query))),
      h('p.note', 'If you do not want any of this text to leave your browser, cancel.'),
    ],
    buttons: [{ id: 'cancel', label: 'Cancel' }, { id: 'ok', label: 'Search', primary: true }],
  });
  if (ok !== 'ok') return;
  S.originBusy = true;
  renderOrigin();
  let online;
  try {
    const res = await fetch('/api/origin', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ fingerprints: lines.map((l) => ({ query: l.query })) }), credentials: 'omit', referrerPolicy: 'no-referrer' });
    if (res.status === 404 || res.status === 405) online = { configured: false, error: 'The online search runs as a function of the deployed site (/api/origin). It is not available on this server.' };
    else {
      const body = await res.json().catch(() => ({}));
      online = res.ok ? body : { configured: true, error: body.error || `The server answered ${res.status}.` };
    }
  } catch (e) { online = { configured: false, error: `The search could not be reached: ${e.message}` }; }
  S.originBusy = false;
  if (S.origin !== o) return;
  S.originOnline = mergeOnline(o.analysis, o.text, online);
  renderOrigin();
}

function renderOrigin() {
  const o = S.origin;
  replace(views.origin, originView(
    { subject: o ? o.subject : '', analysis: o ? o.analysis : null, online: S.originOnline, busy: S.originBusy, derived: !!(o && o.derived), derivedFrom: o && o.derivedFrom },
    { search: searchOnline, deobfuscate: async () => { await runRecover(); await runOrigin(); }, useInput: () => { S.originSubject = 'input'; runOrigin(); } },
  ));
  setCount('origin', o && o.analysis.assessable && !o.derived ? pct(o.analysis.ai.score) : '');
  renderOriginBar();
}

/** One line under the editors: how AI-written it reads, how copied it looks, and what to press next. */
function renderOriginBar() {
  const o = S.origin;
  const a = o && o.analysis;
  const item = (title, value, label, extra) => h('span.ob-item', h('span.ob-title', title), ' ', h('b.ob-value', value), ' ', h('span.ob-label', label), extra || null);
  const parts = [h('span.ob-name', 'AI check'), ' '];
  const acts = [];
  if (!inputPresent()) {
    parts.push(' ', h('span.faint', 'Paste code to see how likely it is to be AI-written, vibe-coded or copied from someone else.'));
  } else if (!a) {
    parts.push(h('span.faint', 'Reading the style…'));
  } else if (!a.assessable) {
    parts.push(h('span.ob-label', 'Obfuscated code has no readable style, so there is nothing to measure yet.'));
    acts.push(h('button.btn.small', { type: 'button', onclick: async () => { await runRecover(); await runOrigin(); } }, 'Deobfuscate, then check'));
  } else {
    const online = S.originOnline;
    const hints = a.skid.signals.length;
    const share = online && online.searched && online.share !== null ? online.share : null;
    if (o.derived) {
      parts.push(item('Written by AI', '—', `not readable: rebuilt from ${o.derivedFrom || 'an obfuscator'}`));
    } else {
      const lvl = a.ai.score >= 0.6 ? 'ai-high' : a.ai.score >= 0.4 ? 'ai-mid' : 'ai-low';
      parts.push(h('span.ob-item.' + lvl, h('span.ob-title', 'Written by AI'), ' ', h('b.ob-value', a.ai.measured < 2 ? '—' : pct(a.ai.score)), ' ', h('span.ob-label', a.ai.label)));
    }
    if (share !== null) {
      parts.push(item('Copied (skidded)', pct(share), online.label));
    } else if (online && online.searched) {
      parts.push(item('Copied (skidded)', '0%', online.label));
    } else {
      parts.push(item('Copied (skidded)', hints ? pct(a.skid.hint) : '—', hints ? `possible, ${hints} clue${hints === 1 ? '' : 's'} in the text` : 'not searched yet'));
      if (a.fingerprints.length) acts.push(h('button.btn.small', { type: 'button', disabled: S.originBusy, title: 'Search GitHub’s public code for distinctive lines of this script (asks first)', onclick: searchOnline }, S.originBusy ? 'Searching…' : 'Search GitHub'));
    }
    if (a.confidence === 'low') parts.push(h('span.faint', 'short script: treat as a guess'));
  }
  acts.push(h('button.btn.small', { type: 'button', title: 'The signals behind these numbers', onclick: () => switchTab('origin') }, 'AI details'));
  replace(originBar, h('div.ob-main', parts), h('div.ob-acts', acts));
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
  if (S.outputs.beautify) entries.push({ name: `recovered/${base}.beautified.lua`, data: binaryToBytes(S.outputs.beautify.text) });
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
/** Put a bundled example in the editor, and press Deobfuscate when asked to. */
async function openSample(s, recover = false) {
  if (S.busy) { toast('Another operation is running.'); return; }
  try {
    const res = await fetch(`data/samples/${s.file}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    loadBytes(s.file, new Uint8Array(await res.arrayBuffer()));
    if (s.note) { S.notes.push({ kind: 'info', text: s.note }); renderInspector(); renderNotes(); }
  } catch (e) { toast(`Could not load the sample: ${e.message}`); return; }
  if (recover === 'ai') { await runDetect({ quiet: true }); await runOrigin(); return; }
  if (recover) await runRecover();
}

/** Recover one example in the background (no editor, no tab switch) and report how long it took. */
async function benchSample(s) {
  const res = await fetch(`data/samples/${s.file}`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const input = bytesToBinary(new Uint8Array(await res.arrayBuffer()));
  const allowSandbox = lic.allow('sandbox');
  const t0 = performance.now();
  const r = await engine.run('recover', input, { ...recoverOptions(settings, { allowSandbox }), format: { indent: indentString(settings), width: settings.width } }, { timeoutMs: 180_000 });
  return { wall: performance.now() - t0, r };
}

el.btn.samples.addEventListener('click', async () => {
  const idx = await loadSamples();
  const items = [];
  for (const g of idx.groups) {
    if (items.length) items.push('-');
    items.push({ label: g.label, sub: g.note || '', disabled: true, run() {} });
    for (const s of g.items) items.push({ label: s.label, sub: s.sub || '', indent: true, run: () => openSample(s) });
  }
  items.push('-');
  items.push({ label: 'Time every example…', sub: 'Examples tab', run: () => { switchTab('examples'); } });
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
  if (!inputPresent()) {
    parts.push(h('section.section', h('h3', h('span', 'How it works')), h('div.body', [
      h('ol', { class: 'steps-list' }, [
        h('li', 'Paste the obfuscated script on the left, or open a .lua, .luau or .txt file.'),
        h('li', 'QuickSilver names the obfuscator on its own. Recover writes the readable version on the right.'),
        h('li', 'Compare shows exactly what changed. Export saves the result.'),
      ]),
      h('p.note.info', 'Scripts are parsed and rewritten as text. They are never run, unless you use Trace or switch on the sandbox in Settings.'),
    ])));
  } else {
    const bytes = S.dirty ? editor.value.length : S.input.length;
    parts.push(h('section.section', h('h3', h('span', 'Document')), h('div.body', h('dl.kv', [
      h('dt', 'Name'), h('dd', S.name),
      h('dt', 'Size'), h('dd', `${fmtBytes(bytes)}, ${sourceLines} line${sourceLines === 1 ? '' : 's'}`),
      h('dt', 'Original'), h('dd', S.raw && !S.dirty ? 'exact bytes kept' : S.raw ? 'edited' : 'typed or pasted'),
    ]))));
  }
  if (S.detection) parts.push(...detectionSummary(S.detection, compatById));
  if (S.recovered) parts.push(...recoverySummary(S.recovered));
  if (S.trace) parts.push(traceSection());
  if (S.dump) parts.push(dumpSection());
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

function dumpSection() {
  const d = S.dump;
  const kv = (rows) => h('dl.kv', rows.flatMap(([k, v]) => [h('dt', k), h('dd', v)]));
  const body = [
    kv([['Ended', d.ended], ['Captured', `${d.candidates.length} piece${d.candidates.length === 1 ? '' : 's'} of text`], ['Instructions', d.stats.fuelUsed.toLocaleString()]]),
    h('p.note.warn', 'A dump is what the script built during this one run. It is not guaranteed to be the whole original script.'),
  ];
  if (d.candidates.length) {
    body.push(h('ul.list', d.candidates.map((c) => h('li', [
      h('span', c.label), ` ${fmtBytes(c.bytes)} `, h('span.badge' + (c.parses ? '.ok' : ''), c.parses ? 'Lua' : 'not Lua'), ' ',
      h('button.btn.small', { type: 'button', onclick: () => { setOutput('dump', { text: c.source, label: `Dump: ${c.label}`, kind: 'dump' }); renderAll(); } }, 'Show'), ' ',
      h('button.btn.small', { type: 'button', onclick: () => useChunk(c.label, c.source) }, 'Use as input'),
    ]))));
  }
  if (d.requests && d.requests.length) body.push(h('div', [h('div.dim', `Requests recorded, not performed (${d.requests.length})`), h('ul.list.mono', d.requests.map((u) => h('li', { style: { overflowWrap: 'anywhere' } }, u)))]));
  return h('section.section', h('h3', h('span', 'Dump')), h('div.body', body));
}

function useChunk(label, source) {
  loadBytes(`${baseName(S.name)}.dump.lua`, binaryToBytes(source));
  S.notes.push({ kind: 'info', text: `The ${label} captured while dumping the previous script is now the input, so Detect, Deobfuscate and the rest apply to it.` });
  renderInspector();
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
    const n = h('input.num-w', { type: 'number', min, max, step, value: draft[key] });
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
        h('h4.set-title', 'Formatting'),
        field('Indent', select('indent', [['2', '2 spaces'], ['4', '4 spaces'], ['tab', 'Tab']])),
        field('Line width', number('width', 40, 240, 10), 'Tables and call arguments wrap beyond this.'),
      ]),
      h('div', [
        h('h4.set-title', 'Recovery'),
        field('Rename variables', select('rename', [['smart', 'Obfuscated names only'], ['all', 'All locals'], ['off', 'Off']]), 'Names are guesses from usage; the original names are not recoverable.'),
        field('Constant folding', select('foldCalls', [['obfuscation', 'Obfuscator-typical calls'], ['all', 'All pure library calls']])),
        field('Literal style', select('stringStyle', [['normalize', 'Normalise strings and numbers'], ['preserve', 'Keep as written']])),
        field('Maximum rounds', number('maxRounds', 1, 20)),
        field('Compare against', select('compareAgainst', [['formatted', 'Re-formatted input'], ['raw', 'Input as opened']]), 'A re-formatted input lines up with the output even when the original is minified.'),
      ]),
      h('div', [
        h('h4.set-title', 'Sandbox'),
        field('Evaluate string decoders', sandboxSwitch, 'Off by default. Runs decoder functions in QuickSilver’s own interpreter, never in the browser.'),
        field('Instruction budget', number('sandboxFuel', 100000, 500000000, 1000000)),
        field('Time limit (ms)', number('sandboxTimeMs', 500, 60000, 500)),
      ]),
    ],
    buttons: [{ id: 'reset', label: 'Reset' }, { id: 'cancel', label: 'Cancel' }, { id: 'save', label: 'Save', primary: true }],
  });
  if (r === 'save') settings = { ...settings, ...draft };
  else if (r === 'reset') settings = { ...DEFAULTS, sidebar: settings.sidebar, inspector: settings.inspector, split: settings.split };
  else return;
  saveSettings(settings);
  S.beautified = null; S.diff = null;
  renderStatus();
  toast('Settings saved');
}
async function showAbout() {
  const credit = (name, line, licence) => h('li', [h('b', name), ` ${line} `, h('span.faint', licence)]);
  await modal({
    title: 'About QuickSilver',
    body: [
      h('p', { style: { margin: 0 } }, `QuickSilver Deobfuscator v${ENGINE_VERSION}. Recovers readable Lua and Luau from obfuscated scripts. Everything runs in this page; nothing is uploaded, and scripts are not executed unless you use Trace or allow sandboxed evaluation.`),
      h('p.note.info', 'Based on Prometheus by Elias Oelschner, https://github.com/prometheus-lua/Prometheus'),
      h('p', { style: { margin: 0 } }, 'QuickSilver contains no third-party code. Its recovery modules and test corpus were built by studying the following tools and their output:'),
      h('ul', [
        credit('Prometheus', 'by Elias Oelschner (https://github.com/prometheus-lua/Prometheus): sample scripts in the test corpus are its output.', 'Prometheus licence, attribution required'),
        credit('Hercules', 'by zeusssz (https://github.com/zeusssz/hercules-obfuscator): sample scripts are its output.', 'Apache-2.0'),
        credit('IronBrew 2', 'by DefCon42 (https://github.com/Trollicus/ironbrew-2): its published format was read to write the IronBrew 2 module.', 'MIT'),
      ]),
      h('p.faint', { style: { margin: 0 } }, 'Names, trademarks and products belong to their owners. Use QuickSilver only on scripts you own or are authorised to analyse. Research notes, licensing and third-party notices are in the docs folder of the source repository.'),
    ],
  });
}
$('#btn-about').addEventListener('click', showAbout);
$('#btn-theme').addEventListener('click', () => {
  const next = document.documentElement.getAttribute('data-theme') === 'light' ? 'dark' : 'light';
  document.documentElement.setAttribute('data-theme', next);
  try { localStorage.setItem('qs.theme', next); } catch { /* storage blocked: the choice lasts until reload */ }
});
$('#btn-settings').addEventListener('click', showSettings);
$('#btn-license').addEventListener('click', async () => { await showLicenseDialog(lic); renderStatus(); renderInspector(); renderResultBar(); });

// ---- layout toggles ---------------------------------------------------------------------------------------------------------------------------------

function applyLayout() {
  el.workspace.classList.toggle('with-side', settings.sidebar);
  el.workspace.classList.toggle('with-inspector', settings.inspector);
  $('#btn-side').setAttribute('aria-pressed', String(settings.sidebar));
  $('#btn-inspector').setAttribute('aria-pressed', String(settings.inspector));
  renderResultBar();
}
const toggleSide = () => { settings = { ...settings, sidebar: !settings.sidebar }; saveSettings(settings); applyLayout(); };
const toggleInspector = () => { settings = { ...settings, inspector: !settings.inspector }; saveSettings(settings); applyLayout(); };
$('#btn-side').addEventListener('click', toggleSide);
$('#btn-inspector').addEventListener('click', toggleInspector);

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

const OUT_ORDER = [['recover', 'Recovered'], ['beautify', 'Beautified'], ['rename', 'Renamed'], ['dump', 'Dump'], ['trace', 'Trace']];
function renderOutput() {
  const has = !!S.output;
  $('#out-body', rightCol).hidden = !has;
  $('#out-empty', rightCol).hidden = has;
  const kinds = OUT_ORDER.filter(([k]) => S.outputs[k]);
  outSwitch.hidden = kinds.length < 2;
  replace(outSwitch, kinds.map(([k, label]) => h('button', {
    type: 'button', 'aria-pressed': String(S.show === k),
    onclick: () => { S.show = k; S.output = S.outputs[k]; renderOutput(); },
  }, label)));
  if (has) {
    const conf = S.output.kind === 'recover' && S.recovered && S.recovered.confidence ? ` · confidence ${pct(S.recovered.confidence.score)}` : '';
    outMeta.textContent = `${kinds.length < 2 ? `${S.output.label} · ` : ''}${fmtBytes(S.output.text.length)}${conf}`;
    if (outViewer._for !== S.output) { outViewer._for = S.output; outViewer.setText(binaryToText(S.output.text)); outCount.textContent = ''; if (outFind.value) findOut(1); }
  } else { outMeta.textContent = ''; outViewer._for = null; }
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
  hero.hidden = inputPresent();
  el.docname.textContent = inputPresent() ? S.name : '';
  el.docname.title = S.name;
  el.stSize.textContent = inputPresent() ? `${fmtBytes(bytes)} · ${sourceLines} lines${S.detection ? ` · ${S.detection.dialect.label}` : ''}` : '';
  const sandboxOn = settings.sandbox && lic.allow('sandbox');
  el.stSandbox.textContent = sandboxOn ? 'sandbox: on' : 'sandbox: off';
  el.stSandbox.className = sandboxOn ? 'state-busy' : 'faint';
  el.stLicense.textContent = lic.label();
  srcMeta.textContent = inputPresent() ? `${S.name} · ${fmtBytes(bytes)}${S.raw && !S.dirty ? ' · bytes preserved' : ''}` : '';
}

function renderNotes() {
  replace(noteBox, S.notes.slice(0, 3).map(noteEl));
  noteBox.hidden = !S.notes.length;
}

/** The strip under the two sources: what was detected, what the last run achieved, and the next sensible step. */
function renderResultBar() {
  const facts = [];
  const acts = [];
  const fact = (...c) => h('span.fact', ...c);
  if (!inputPresent()) {
    facts.push(fact('Paste an obfuscated script above, or use Open File. Load example has a script from each supported obfuscator; the Examples tab times them.'));
  } else {
    const det = S.detection;
    if (det) {
      const top = det.families.find((f) => f.confidence >= 0.5);
      facts.push(fact(top ? [h('b', top.name), top.version ? ` ${top.version}` : '', ` · ${pct(top.confidence)}`] : [h('b', 'No known obfuscator'), ' matched']));
      facts.push(fact(det.dialect.label));
    } else facts.push(fact('Not analysed yet'));
    const r = S.recovered;
    if (r && r.confidence) {
      facts.push(fact(['Confidence ', h('b', pct(r.confidence.score)), ` (${r.confidence.level})`]));
      const applied = (r.steps || []).filter((x) => x.status === 'applied').length;
      if (applied) facts.push(fact(`${applied} pass${applied === 1 ? '' : 'es'} applied`));
      if (r.ms) facts.push(fact(`took ${fmtMs(r.ms)}`));
      if (r.validation) facts.push(fact(r.validation.ok ? 'output parses' : 'output does not parse'));
    } else if (r && r.error) facts.push(fact('Recovery stopped'));
    const hints = (r && r.confidence && r.confidence.hints) || [];
    if (hints.includes('sandbox') && lic.allow('sandbox')) {
      facts.push(fact(h('span.badge.warn', 'Encoded strings remain')));
      acts.push(h('button.btn.small.outline', { type: 'button', onclick: recoverWithSandbox }, 'Recover with sandbox…'));
    }
    if (hints.includes('trace') && lic.allow('sandbox')) {
      facts.push(fact(h('span.badge.warn', 'Still protected by a virtual machine')));
      acts.push(h('button.btn.small.outline', { type: 'button', onclick: () => runTrace() }, 'Trace in sandbox…'));
    }
  }
  acts.push(h('button.btn.small', { type: 'button', 'aria-pressed': String(settings.inspector), title: 'Passes, confidence reasons and warnings of the last run', onclick: toggleInspector }, 'Details'));
  replace(resultFacts, facts);
  replace(resultActs, acts);
}

function renderAll() {
  renderStatus();
  renderNotes();
  renderResultBar();
  renderOutput();
  renderCompare();
  renderDetection();
  renderAnalysis();
  renderOrigin();
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
el.btn.rename.addEventListener('click', () => runRename());
el.btn.dump.addEventListener('click', () => runDump());
el.btn.origin.addEventListener('click', () => runOrigin());
el.btn.link.addEventListener('click', () => openLinkDialog());
el.btn.help.addEventListener('click', () => showHelp());
el.btn.luraph.addEventListener('click', () => runVmTool('luraph', 'Luraph'));
el.btn.moonveil.addEventListener('click', () => runVmTool('moonveil', 'MoonVeil'));
el.btn.ironbrew.addEventListener('click', () => runIronBrewTool());

document.addEventListener('keydown', (e) => {
  if (e.defaultPrevented) return;
  const key = e.key.toLowerCase();
  if ((e.ctrlKey || e.metaKey) && key === 'o') { e.preventDefault(); el.file.click(); }
  else if ((e.ctrlKey || e.metaKey) && key === 'enter') { e.preventDefault(); if (!S.busy) runRecover(); }
  else if (e.altKey && !e.ctrlKey && !e.metaKey) {
    const map = { KeyD: runDetect, KeyB: runBeautify, KeyA: runAnalyze, KeyR: runRecover, KeyT: runTrace, KeyC: runCompare, KeyE: () => showMenu(el.btn.export, exportItems()) };
    if (map[e.code]) { e.preventDefault(); if (!S.busy) map[e.code](); }
  } else if (key === 'f' && (e.ctrlKey || e.metaKey) && S.tab === 'work') {
    e.preventDefault();
    (document.activeElement === editor || document.activeElement === srcFind ? srcFind : outFind).focus();
  }
});

lic.onchange = () => { renderStatus(); renderInspector(); renderResultBar(); };

async function start() {
  setWrap(settings.wrap);
  applyLayout();
  switchTab('work');
  renderAll();
  paintGutter(true);
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
