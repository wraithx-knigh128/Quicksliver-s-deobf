// The one-page Deobfuscate workspace (Prompt XXVIII): one input (paste, drop, upload — source, a loadstring or a link), one Deobfuscate,
// the fourteen stages as they run, and the result — the reconstructed program the input leads to, with its verdict and everything that
// decided it. The work is src/pipeline/unified.js; this file only wires it to the page: an engine worker of its own (the expert workbench
// keeps its own, so neither waits on the other), the site's /api/github and /api/fetch, and the licence.

import { h, replace, toast, modal, fmtBytes, fmtMs } from './dom.js';
import { Engine, EngineError } from './engine-client.js';
import { Viewer } from './viewer.js';
import { download, baseName, readFileBytes, FileRejected } from './files.js';
import { bytesToBinary, binaryToBytes, binaryToText, textToBinary } from '../core/bytes.js';
import { recognizeInput, findGitHubRefs } from '../loader/github.js';
import { deobfuscate, STAGES, SOURCE, ROLES, unifiedMarkdown } from '../pipeline/unified.js';
import { githubRequest, chooseEntry } from './github-ui.js';
import { serverEngineRequest } from './engine-ui.js';

const GOOD = new Set(['validated', 'syntax-valid-unverified']);
const tone = (outcome) => (GOOD.has(outcome) ? 'ok' : outcome === 'partial' ? 'warn' : 'bad');

/**
 * @param {object} ctx
 * @param {object} ctx.lic                      LicenseState
 * @param {(engine: Engine, text: string) => Promise<object>} ctx.recoverOptions   the workbench's recovery options (settings + research plan)
 * @param {() => string[]} ctx.providers        owner-configured retrieval providers on this deployment
 * @param {(payload: object) => void} ctx.openInExpert
 */
export function initDeobPage(ctx) {
  const $ = (id) => document.getElementById(id);
  const ta = $('deob-text');
  if (!ta) return null;
  const drop = $('deob-drop');
  const recog = $('deob-recog');
  const runBtn = $('deob-run');
  const verifyBox = $('deob-verify');
  const progress = $('deob-progress');
  const rail = $('stage-rail');
  const now = $('stage-now');
  const result = $('deob-result');
  const engine = new Engine();
  const state = { name: 'pasted.lua', raw: null, loadedText: null, busy: false, last: null, selected: null, cancelled: false };

  // ---- input ------------------------------------------------------------------------------------------------------------------------------
  const currentText = () => (state.raw && ta.value === state.loadedText ? bytesToBinary(state.raw) : textToBinary(ta.value));
  const currentBytes = () => (state.raw && ta.value === state.loadedText ? state.raw : binaryToBytes(textToBinary(ta.value)));
  let recogTimer = 0;
  function describeInput() {
    const v = ta.value;
    if (!v.trim()) { recog.dataset.kind = 'empty'; recog.textContent = 'Waiting for a script, a loadstring or a link'; return; }
    const r = recognizeInput(v.length > 400_000 ? v.slice(0, 400_000) : v);
    recog.dataset.kind = r.error ? 'error' : r.kind;
    const size = state.raw && v === state.loadedText ? `${state.name}, ${fmtBytes(state.raw.length)}` : fmtBytes(new Blob([v]).size);
    recog.textContent = r.kind === 'github-link' ? (r.error ? `GitHub link — ${r.error}` : `GitHub ${r.ref.kind === 'repo' ? 'repository' : r.ref.kind === 'tree' ? 'folder' : r.ref.kind === 'profile' ? 'profile' : r.ref.kind} link: ${r.ref.owner}/${r.ref.repo || r.ref.gist || ''}${r.ref.path ? `/${r.ref.path}` : ''} — it will be retrieved`)
      : r.kind === 'link' ? 'A link — it will be fetched by this site’s server if its host is a public one it reads from'
      : r.kind === 'loader' ? `Loader (loadstring + HttpGet)${r.github && r.github.length ? `, ${r.github.length} GitHub address${r.github.length === 1 ? '' : 'es'}` : ''} — what it downloads is retrieved and deobfuscated`
      : r.kind === 'bytecode' ? `Compiled Lua chunk (${size})`
      : `Lua / Luau source (${size})`;
  }
  ta.addEventListener('input', () => { clearTimeout(recogTimer); recogTimer = setTimeout(describeInput, 120); });
  ta.addEventListener('keydown', (e) => { if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') { e.preventDefault(); run(); } });

  async function openFile(file) {
    try {
      const bytes = await readFileBytes(file);
      state.name = file.name;
      state.raw = bytes;
      ta.value = binaryToText(bytesToBinary(bytes));
      state.loadedText = ta.value;
      describeInput();
      toast(`Opened ${file.name} (${fmtBytes(bytes.length)})`);
    } catch (e) {
      toast(e instanceof FileRejected ? e.message : `Could not read the file: ${e.message}`, 6000);
    }
  }
  const picker = h('input', { type: 'file', accept: '.lua,.luau,.txt,.rbxm,.rbxmx', hidden: true });
  document.body.append(picker);
  picker.addEventListener('change', () => { const f = picker.files[0]; picker.value = ''; if (f) openFile(f); });
  $('deob-upload').addEventListener('click', () => picker.click());
  // drag and drop anywhere on the page while the site is shown (the workbench has its own handler while it is open)
  const onSite = () => !document.documentElement.classList.contains('in-work');
  let depth = 0;
  window.addEventListener('dragenter', (e) => { if (onSite() && e.dataTransfer && [...e.dataTransfer.types].includes('Files')) { depth++; drop.classList.add('drag'); } });
  window.addEventListener('dragleave', () => { if (!onSite()) return; depth = Math.max(0, depth - 1); if (!depth) drop.classList.remove('drag'); });
  window.addEventListener('dragover', (e) => { if (onSite() && e.dataTransfer && [...e.dataTransfer.types].includes('Files')) e.preventDefault(); });
  window.addEventListener('drop', (e) => {
    if (!onSite()) return;
    e.preventDefault();
    depth = 0; drop.classList.remove('drag');
    const f = (e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0]) || null;
    if (f) openFile(f);
  });

  // ---- progress ----------------------------------------------------------------------------------------------------------------------------
  const items = STAGES.map(([id, label], i) => {
    const li = h('li', { 'data-stage': id, tabindex: '0', title: label }, h('span.num', String(i + 1)), h('span.lbl', label));
    li.addEventListener('click', () => select(id));
    li.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); select(id); } });
    return li;
  });
  replace(rail, items);
  let snapshot = null;
  function paint(snap) {
    snapshot = snap;
    let running = null;
    for (const [i, s] of snap.stages.entries()) {
      const li = items[i];
      li.className = `${s.status}${state.selected === s.id ? ' sel' : ''}`;
      if (s.status === 'running') { running = running || s; li.setAttribute('aria-current', 'step'); } else li.removeAttribute('aria-current');
      li.title = `${s.label}: ${s.status}${s.detail ? ` — ${s.detail}` : ''}`;
    }
    const shown = state.selected ? snap.stages.find((s) => s.id === state.selected) : running || [...snap.stages].reverse().find((s) => s.status !== 'pending' && s.status !== 'skipped');
    if (shown) replace(now, h('b', `${shown.n}. ${shown.label}`), ` — ${shown.detail || (shown.status === 'running' ? 'working…' : shown.status)}`);
  }
  function select(id) { state.selected = state.selected === id ? null : id; if (snapshot) paint(snapshot); }

  // ---- running ----------------------------------------------------------------------------------------------------------------------------
  const setRunning = (on) => {
    state.busy = on;
    runBtn.classList.toggle('busy', on);
    runBtn.firstChild.textContent = on ? 'Cancel' : 'Deobfuscate';
    runBtn.setAttribute('aria-label', on ? 'Cancel the deobfuscation' : 'Deobfuscate');
    $('deob-upload').disabled = on;
    ta.readOnly = on;
  };
  runBtn.addEventListener('click', () => { if (state.busy) { state.cancelled = true; engine.cancel(); } else run(); });

  async function run() {
    if (state.busy) return;
    if (!ta.value.trim()) { toast('Paste a script, a loadstring or a link, or open a file first.'); ta.focus(); return; }
    if (!ctx.lic.allow('recover')) { toast('Deobfuscation is not part of this licence. Open Expert tools → Licence to add a key.', 6000); return; }
    const text = currentText();
    if (ctx.lic.ent.maxBytes && text.length > ctx.lic.ent.maxBytes) { toast(`Evaluation access is limited to ${fmtBytes(ctx.lic.ent.maxBytes)} of input.`, 5000); return; }
    const wantVerify = verifyBox.checked;
    if (wantVerify && !ctx.lic.allow('sandbox')) { toast('The behaviour check needs the sandbox, which is not part of this licence; the result will be unverified.', 6000); }
    const verify = wantVerify && ctx.lic.allow('sandbox');
    const name = state.raw && ta.value === state.loadedText ? state.name : 'pasted.lua';
    state.cancelled = false;
    state.selected = null;
    setRunning(true);
    progress.hidden = false;
    result.hidden = true;
    const t0 = performance.now();
    paint({ stages: STAGES.map(([id, label], i) => ({ n: i + 1, id, label, status: 'pending', detail: '' })) });
    const providers = ctx.providers();
    let options = null;
    const deps = {
      analyze: (src, o) => engine.run('loaderAnalyze', src, { ...o, providers }, { timeoutMs: 30_000 }),
      decode: (bytes, meta) => engine.run('payload', bytesToBinary(bytes), meta, { timeoutMs: 30_000 }),
      detect: async (t) => (await engine.run('detect', t, {}, { timeoutMs: 30_000 })).detection,
      recover: async (t) => { options = options || await ctx.recoverOptions(engine, t); return engine.run('recover', t, options, { timeoutMs: 180_000 }); },
      verify: verify ? (t, recovered, o) => engine.run('verify', t, { ...(o || {}), recovered }, { timeoutMs: 90_000 }) : undefined,
      // a format with a server-side adapter (src/pipeline/engines.js): the person confirms, the server rebuilds, the worker decompiles
      serverEngine: (adapter, t) => serverEngineRequest(adapter, t),
      fromBytecode: async (bc, o) => { options = options || await ctx.recoverOptions(engine, o.original); return engine.run('fromBytecode', bc, { ...o, recover: options }, { timeoutMs: 180_000 }); },
      fromSource: async (src, o) => { options = options || await ctx.recoverOptions(engine, o.original); return engine.run('fromSource', src, { ...o, recover: options }, { timeoutMs: 180_000 }); },
      github: (url, o) => githubRequest(url, o),
      fetchLink: fetchLink,
      choose: (listing) => chooseEntry(listing),
      onProgress: paint,
    };
    let R = null;
    try {
      R = await deobfuscate({ text, name, bytes: currentBytes() }, deps, { routes: ['link-fetcher', ...providers.map((p) => `provider:${p}`)] });
    } catch (e) {
      const cancelled = state.cancelled || (e instanceof EngineError && e.kind === 'cancelled');
      setRunning(false);
      if (snapshot) paint({ stages: snapshot.stages.map((s) => (s.status === 'running' ? { ...s, status: 'failed', detail: cancelled ? 'Cancelled.' : String(e.message || e) } : s)) });
      showError(cancelled ? 'Cancelled' : e instanceof EngineError && e.kind === 'timeout' ? 'Stopped: time limit' : 'The pipeline stopped', cancelled ? 'Nothing was delivered.' : String(e.message || e));
      return;
    }
    setRunning(false);
    R.wallMs = performance.now() - t0;
    R.inputName = name;
    state.last = R;
    paint({ stages: R.stages });
    renderResult(R);
  }

  async function fetchLink(url) {
    try {
      const res = await fetch(`/api/fetch?url=${encodeURIComponent(url)}`, { credentials: 'omit', referrerPolicy: 'no-referrer' });
      if (!res.ok) {
        let error = `HTTP ${res.status}`;
        try { const j = await res.json(); error = typeof j.error === 'string' ? j.error : (j.error && j.error.message) || error; } catch { if (res.status === 404) error = 'Fetching links needs the deployed site (its /api/fetch function); it is not available on this server.'; }
        return { ok: false, status: res.status, error };
      }
      return { ok: true, status: res.status, bytes: new Uint8Array(await res.arrayBuffer()), contentType: res.headers.get('x-qs-upstream-type') || '', name: res.headers.get('x-qs-name') || undefined };
    } catch (e) { return { ok: false, error: `The site could not be reached: ${e.message || e}` }; }
  }

  // ---- result ------------------------------------------------------------------------------------------------------------------------------
  let viewer = null;
  function showError(title, text) {
    result.hidden = false;
    replace(result, h('div.res-head', h('div.res-title', h('span.verdict.bad', title), h('p', text))));
  }

  function renderResult(R) {
    result.hidden = false;
    const v = R.verdict || { outcome: 'not-deobfuscated', label: 'Not classified', reasons: [] };
    const f = R.final;
    const det = (f && f.node && f.node.detection) || (R.chain[0] && R.chain[0].detection) || null;
    const fam = det && (det.families || []).find((x) => x.confidence >= 0.5);
    const src = R.source || { class: 'input', label: SOURCE.input };
    const facts = [
      ['Source', src.label],
      fam ? ['Protection', `${fam.name}${fam.version ? ` ${fam.version}` : ''}`] : det ? ['Protection', 'none recognised'] : null,
      f && f.output != null ? ['Output', `${f.output.split('\n').length.toLocaleString('en')} lines`] : null,
      R.chain.length > 1 ? ['Chain', `${R.chain.length} stages`] : null,
      ['Time', fmtMs(R.wallMs || R.ms)],
    ].filter(Boolean);
    const title = f ? (f.isPayload ? f.name : `${f.name} — the loader, not the payload`) : 'Nothing delivered';
    const sub = f && f.isPayload
      ? (f.node && f.node.address ? `Reconstructed from the payload retrieved from ${f.node.address}.` : 'Reconstructed from the input.')
      : f ? 'The payload this loader fetches was not obtained, so it is not shown: only the loader’s own code is, labelled as such.' : (R.source && R.source.message) || (v.reasons || []).join(' ') || 'No reconstruction was produced.';
    const acts = [];
    if (f && f.output != null) {
      acts.push(h('button.btn-ghost.primary', { type: 'button', onclick: () => save(f.name, f.output) }, `Download ${f.isPayload ? '' : 'loader '}.lua`));
      acts.push(h('button.btn-ghost', { type: 'button', onclick: async () => { try { await navigator.clipboard.writeText(binaryToText(f.output)); toast('Copied'); } catch { toast('The browser did not allow copying.'); } } }, 'Copy'));
    }
    acts.push(h('button.btn-ghost', { type: 'button', onclick: () => { if (ctx.lic.allow('export')) download(`${baseName(R.inputName)}.report.md`, new TextEncoder().encode(unifiedMarkdown(R, { name: R.inputName })), 'text/markdown'); else toast('Export is not included in evaluation access.'); } }, 'Report'));
    if (f && f.output != null) acts.push(h('button.btn-ghost', { type: 'button', title: 'Open the input and this result in the expert workbench (compare, trace, analysis, export)', onclick: () => ctx.openInExpert({ name: f.node && f.node.via !== 'input' ? f.node.name : R.inputName, bytes: f.node && f.node.via !== 'input' ? null : currentBytes(), text: f.node && f.node.program ? f.node.program.source : null, output: f.output, recovery: f.node && f.node.recovery }) }, 'Open in Expert tools'));

    const head = h('div.res-head',
      h('div.res-title',
        h(`span.verdict.${f && !f.isPayload ? 'bad' : tone(v.outcome)}`, v.label),
        h('h2', title),
        h('p', sub),
        h('div.res-facts', facts.map(([k, x]) => h('span', `${k}: `, h('b', x))))),
      h('div.res-acts', acts));

    const parts = [head];
    if (f && f.output != null) {
      viewer = new Viewer();
      const box = h('div.res-code', viewer.root);
      parts.push(box);
      requestAnimationFrame(() => viewer.setText(binaryToText(f.output)));
    } else {
      parts.push(h('div.res-empty', (v.reasons && v.reasons.length) ? h('ul.why', v.reasons.map((x) => h('li', x))) : null));
    }

    const details = [];
    details.push(section('Why this verdict', `${v.label}`, [
      v.met && v.met.length ? h('p', 'Established: ', v.met.join('; '), '.') : null,
      v.reasons && v.reasons.length ? h('ul', v.reasons.map((x) => h('li', x))) : h('p', 'Nothing held it back.'),
      v.notes && v.notes.length ? h('ul', v.notes.map((x) => h('li', x))) : null,
    ], !GOOD.has(v.outcome)));
    details.push(section('All fourteen stages', `${R.stages.filter((s) => s.status === 'done').length} done, ${R.stages.filter((s) => s.status === 'warn').length} with warnings, ${R.stages.filter((s) => s.status === 'failed').length} failed`, [
      h('table.stage-table', h('tbody', R.stages.map((s) => h('tr', h('td', String(s.n)), h('td', h('b', s.label)), h(`td.st.${s.status}`, s.status), h('td', s.detail || ''))))),
    ]));
    if (R.chain.length > 1 || R.requests.length) {
      details.push(section('Loader chain and retrievals', `${R.requests.length} address${R.requests.length === 1 ? '' : 'es'}, ${R.chain.length} stage${R.chain.length === 1 ? '' : 's'}`, [
        h('ul', R.chain.map((n) => h('li', `Depth ${n.depth}: `, h('code', n.name), n.address ? [' from ', h('code', n.address)] : null, ` — ${ROLES[n.role] || n.role}`, n.program && n.program.result ? `; ${n.program.result.label}` : '', n.sha256 ? `; SHA-256 ${String(n.sha256).slice(0, 16)}…` : ''))),
        R.requests.length ? h('ul', R.requests.map((r) => h('li', h('code', r.api), ' → ', h('code', r.address), `: ${r.outcome || '—'}${r.reason ? ` — ${r.reason}` : ''}`))) : null,
      ], !GOOD.has(v.outcome)));
    }
    if (f && f.dependencies && f.dependencies.length) {
      details.push(section('Also delivered', `${f.dependencies.length} file${f.dependencies.length === 1 ? '' : 's'}`, [
        h('ul.extras', f.dependencies.map((d) => h('li', h('code', d.name), h('span', ` ${ROLES[d.role] || d.role}${d.outcome ? ` · ${d.outcome.label}` : ''}`), d.address ? h('span.faint', ` ${d.address}`) : null, h('button.btn-ghost', { type: 'button', onclick: () => save(d.name, d.output) }, 'Download')))),
      ], true));
    }
    const vm = f && f.node && f.node.recovery && f.node.recovery.vm;
    if (vm && vm.kind) {
      const st = (f.node.recovery.steps || []).find((x) => /\.vm\d*$|\.bvm$/.test(x.id) && x.status === 'applied');
      const ks = st && st.detail && st.detail.keysearch;
      details.push(section('Virtual machine', `${vm.kind}: ${vm.lifted ? 'lifted to source' : 'recognised, not lifted'}`, [
        h('ul', [
          h('li', vm.lifted ? `The ${vm.kind} interpreter was read and the program lifted back to Lua${vm.stats && vm.stats.functions ? `: ${vm.stats.functions} functions, ${vm.stats.instructions} instructions, ${vm.stats.constants} constants` : ''}.` : `The ${vm.kind} interpreter is still in the output: its program was not lifted.`),
          ks ? h('li', `${ks.decided} masked strings read back by key search (${ks.byName} by names the runtime defines); ${(ks.ambiguous || []).length} left undecided.`) : null,
        ].filter(Boolean)),
      ]));
    }
    if (R.notes.length) details.push(section('Notes', `${R.notes.length}`, [h('ul', R.notes.map((n) => h('li', n.text)))]));
    parts.push(h('div.res-details', details));
    replace(result, parts);
    result.scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start' });
  }

  function section(title, sub, body, open = false) {
    return h('details', open ? { open: true } : {}, h('summary', title, sub ? h('span.faint', ` ${sub}`) : null), h('div.body', body));
  }
  function save(name, bin) {
    if (!ctx.lic.allow('export')) { toast('Export is not included in evaluation access. Open Expert tools → Licence to add a key.', 5000); return; }
    download(name, binaryToBytes(bin), 'text/plain');
  }

  describeInput();
  return {
    /** Coverage list on the page: what the reconstruction reads, from the same table the workbench uses. */
    setCoverage(list) {
      const ul = $('cov-list');
      if (!ul) return;
      replace(ul, list.map((x) => h(`li.${x.st}`, { title: x.what || '' }, x.name)));
    },
    setTier(premium) {
      for (const node of [$('user-badge'), $('premium-tag')]) if (node) node.classList.toggle('eval', !premium);
      const t = $('user-badge-text'); if (t) t.textContent = premium ? 'Premium User' : 'Evaluation';
      const tag = $('premium-tag'); if (tag) tag.textContent = premium ? 'Premium User' : 'Premium · evaluation';
    },
    get last() { return state.last; },
    run,
    openFile,
    findGitHubRefs,
  };
}
