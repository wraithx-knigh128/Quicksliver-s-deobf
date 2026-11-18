// The Loader tab: what a loader script downloads, from where, under which conditions, and whether that payload can be obtained through an
// authorised route — then, on the user's action only, the downloaded stages kept as separate artifacts and handed to the pipeline.
//
// Everything shown comes from src/loader/analyze.js (static; nothing is run). Text that came from a script is only ever inserted as text.

import { h, fmtBytes } from './dom.js';
import { section, kv, note } from './views.js';

const ROUTE_TEXT = {
  'link-fetcher': ['ok', 'Fetchable'],
  manual: ['warn', 'Fetch it yourself'],
  owner: ['warn', 'Owner only'],
  none: ['bad', 'Not retrievable'],
};

/** The six cases as a ladder, with the one that applies marked and the others that also apply flagged. */
function caseLadder(a) {
  const all = [1, 2, 3, 4, 5, 6];
  const also = new Set(a.alsoApplies.map((c) => c.n));
  const LABEL = { 1: 'In the file', 2: 'Public address', 3: 'Needs your key', 4: 'Generated at run time', 5: 'Encrypted / transformed', 6: 'No authorised interface' };
  return h('ol.case-ladder', { 'aria-label': 'The six accessibility cases' }, all.map((n) => h('li' + (n === a.case.n ? '.on' : also.has(n) ? '.also' : ''),
    h('span.n', String(n)), h('span.t', LABEL[n]), n === a.case.n ? h('span.badge.accent', 'applies') : also.has(n) ? h('span.badge', 'also') : null)));
}

function progress(state, a) {
  const stages = state.stages;
  const fetchable = a.requests.filter((r) => r.retrieval.possible);
  const step = (label, status, detail) => h('li.' + status, h('span.dot'), h('span.name', label), detail ? h('span.detail.faint', detail) : null);
  return h('ol.loader-steps', { 'aria-label': 'What has been done' },
    step('Read the loader', 'done', a.parsed ? `${a.requests.length} request${a.requests.length === 1 ? '' : 's'} found` : 'does not parse'),
    step('Identify the service', 'done', a.families.length ? a.families.map((f) => f.name).join(', ') : 'none recognised'),
    step('Decide the access route', 'done', `case ${a.case.n}: ${a.case.label.toLowerCase()}`),
    step('Retrieve the payload', !a.isLoader ? 'skipped' : stages.length ? 'done' : fetchable.length ? 'waiting' : 'blocked',
      !a.isLoader ? 'nothing to retrieve' : stages.length ? `${stages.length} stage${stages.length === 1 ? '' : 's'} downloaded` : fetchable.length ? 'waiting for you to fetch' : 'no authorised route'),
    step('Analyse the payload', stages.some((s) => s.opened) ? 'done' : a.isLoader ? (stages.length ? 'waiting' : 'blocked') : 'done',
      stages.some((s) => s.opened) ? 'opened in the Deobfuscator' : !a.isLoader ? 'the normal pipeline handles this file' : stages.length ? 'open a stage to analyse it' : 'needs a retrieved stage'));
}

function requestRow(r, { onFetch, busy }) {
  const [cls, label] = ROUTE_TEXT[r.retrieval.route] || ['', r.retrieval.route];
  return h('tr',
    h('td.mono', r.line ? String(r.line) : '—'),
    h('td.call', h('code', r.api), r.executes ? h('div.faint', `→ ${r.sink}${r.decoder ? ` after ${r.decoder}` : ''}`) : h('div.faint', 'result not run')),
    h('td.addr', h('code', r.url || r.template), h('div.faint', r.urlKind === 'literal' ? 'fixed address' : r.urlKind === 'encoded' ? 'decoded from the script' : r.urlKind === 'constructed' ? 'partly computed at run time' : 'only known at run time')),
    h('td', r.familyName || h('span.faint', '—')),
    h('td', h('span.badge.' + cls, label), h('div.faint.why', r.retrieval.reason)),
    h('td.acts', r.retrieval.possible ? h('button.btn.small.outline', { type: 'button', disabled: busy, onclick: () => onFetch(r) }, 'Fetch stage…') : null));
}

function stageCard(s, i, { onOpen, onAnalyzeStage }) {
  return h('div.stage-card',
    h('div.stage-head', h('b', `Stage ${i + 1}`), h('span.badge' + (s.kind === 'loader' ? '.warn' : s.kind === 'script' || s.kind === 'bytecode' ? '.ok' : '.bad'), s.label), h('span.grow'),
      s.kind === 'loader' ? h('button.btn.small.outline', { type: 'button', onclick: () => onAnalyzeStage(s) }, 'Analyse as loader') : null,
      s.kind === 'script' || s.kind === 'bytecode' || s.kind === 'loader' ? h('button.btn.small.outline', { type: 'button', onclick: () => onOpen(s) }, s.opened ? 'Open again' : 'Open in Deobfuscator') : null),
    kv([
      ['From', h('code', s.url)],
      ['Size', fmtBytes(s.bytes)],
      ['SHA-256', h('code.hash', s.sha256 || '…')],
      ['Fetched', s.at],
    ]));
}

const OUTCOME = {
  'not-retrievable': ['', 'Not retrievable'],
  'transport-failed': ['bad', 'Request failed'],
  'not-code': ['bad', 'Not code'],
  'retrieved-unrecoverable': ['warn', 'Retrieved, not reconstructed'],
  'retrieved-reconstructed': ['ok', 'Reconstructed'],
  'retrieved-plain': ['ok', 'Plain code'],
  'nested-loader': ['info', 'Another loader'],
};

/** Loader Intelligence: one row per request, each stage (route, transport, payload, program, reconstruction) shown on its own. */
function intelSection(state, a, { onIntel, onOpenText, onExport }) {
  const routes = ['link-fetcher', ...(state.providers || []).map((p) => `provider:${p}`)];
  const n = a.requests.filter((r) => r.retrieval.possible && routes.includes(r.retrieval.route)).length;
  const head = h('div.intel-head',
    h('button.btn.primary', { type: 'button', disabled: state.busy || !n, onclick: onIntel }, state.intel ? 'Run again…' : 'Retrieve and analyse…'),
    h('span.meta', n ? `${n} address${n === 1 ? '' : 'es'} with an authorised route. Each response is checked, decoded and reconstructed separately; nothing is run.` : 'No request has an authorised route on this deployment, so nothing can be retrieved.'),
    state.intel ? h('span.grow') : null,
    state.intel ? h('button.btn.small.outline', { type: 'button', onclick: () => onExport('md') }, 'Report (.md)') : null,
    state.intel ? h('button.btn.small.outline', { type: 'button', onclick: () => onExport('json') }, 'Report (.json)') : null);
  if (!state.intel) return section('Loader Intelligence', head);
  const r = state.intel;
  const s = r.summary;
  const metric = (v, label) => h('div.metric', h('b', String(v)), h('span', label));
  return section('Loader Intelligence', [
    head,
    h('div.metrics', metric(s.requests, 'requests'), metric(s.transportOk, 'retrieved'), metric(s.payloadCode, 'were code'), metric(s.reconstructed, 'reconstructed'), metric(s.plain, 'plain'), metric(s.unrecoverable + s.notCode + s.transportFailed, 'not recovered')),
    h('div.table-scroll', h('table.grid.intel-table',
      h('thead', h('tr', h('th', '#'), h('th', 'Address'), h('th', 'Transport'), h('th', 'Payload'), h('th', 'Program → result'), h('th', 'Outcome'))),
      h('tbody', r.stages.map((st, i) => {
        const [cls, label] = OUTCOME[st.outcome] || ['', st.outcome];
        return h('tr',
          h('td.mono', `${i + 1}${st.depth ? `·${st.depth}` : ''}`),
          h('td.addr', h('code', st.request.address), h('div.faint', st.route.route)),
          h('td', st.transport ? (st.transport.ok ? h('span.nowrap', `HTTP ${st.transport.status ?? 200} · ${fmtBytes(st.transport.bytes)}`) : h('span.bad-text', st.transport.error || 'failed')) : h('span.faint', 'not requested')),
          h('td', st.payload ? [st.payload.label, st.payload.layers.length ? h('div.faint', st.payload.layers.map((l) => l.kind).join(' → ')) : null] : h('span.faint', '—')),
          h('td', (st.programs || []).length ? st.programs.map((p) => h('div.prog',
            h('span', p.nestedLoader ? 'a further loader' : p.families.length ? p.families.join(', ') : p.obfuscated ? 'obfuscated' : 'not obfuscated'),
            p.nestedLoader ? h('span.faint', ` · case ${p.nestedLoader.case}, analysed as the next stage`) : p.reconstruction ? h('span.faint', ` · confidence ${p.reconstruction.level || '—'}`) : null,
            p.source ? h('button.btn.small.outline', { type: 'button', onclick: () => onOpenText(`${(p.name || 'payload').split('/').pop() || 'payload'}`, p.source) }, 'Payload') : null,
            p.output ? h('button.btn.small.outline', { type: 'button', onclick: () => onOpenText(`${(p.name || 'payload').split('/').pop() || 'payload'}.recovered.lua`, p.output) }, 'Result') : null)) : h('span.faint', '—')),
          h('td', h('span.badge.' + (cls || 'plain'), label)));
      })))),
    note('', 'Counted on their own: a successful request is not a payload, a payload is not a reconstruction, and the confidence is the pipeline\u2019s own estimate (behaviour is checked separately in the Deobfuscator).'),
  ]);
}

const OP_STATUS = { done: ['ok', 'done'], partial: ['warn', 'partial'], 'via-pipeline': ['info', 'via the Deobfuscator'], 'not-available': ['bad', 'not available'], 'needs-input': ['', 'needs your input'] };

/** Luarmor loader analysis (src/loader/luarmor.js): the five operations kept apart, the local logic, the data, the remote parts. */
function luarmorSection(l, { onOpenText }) {
  if (!l || !l.recognised) return null;
  if (!l.parsed) return section('Luarmor loader', note('warn', l.note || l.error));
  return section('Luarmor loader', [
    h('p', h('b', `Variant: ${l.variants.join(', ')}. `), l.answer),
    h('table.table.ops', h('tbody', l.operations.map((o) => {
      const [cls, label] = OP_STATUS[o.status] || ['', o.status];
      return h('tr', h('td.mono', String(o.n)), h('td', o.name), h('td', h('span.badge.' + (cls || 'plain'), label)), h('td.dim', o.detail));
    }))),
    h('div.row-item', h('b', 'The loader\u2019s own code'), h('ul', l.local.describes.map((d) => h('li', d))),
      l.local.code ? h('button.btn.small.outline', { type: 'button', onclick: () => onOpenText('luarmor-loader.recovered.lua', l.local.code) }, 'Open the recovered loader logic') : null),
    l.data.length ? h('div.row-item', h('b', 'Embedded data'), l.data.map((d) => h('div',
      h('code', d.name), ` (line ${d.line}): ${d.entries} values — ${d.numbers} number${d.numbers === 1 ? '' : 's'}${d.strings.length ? `, ${d.strings.map((x) => x.note).join('; ')}` : ''}.`,
      h('div.dim', `Opaque: ${d.why}.`)))) : null,
    l.remote.length ? h('div.row-item', h('b', 'Not in this file'), h('ul', l.remote.map((x) => h('li', h('b', x.role), `: ${x.what}${x.address ? ' — ' : ''}`, x.address ? h('code', x.address) : null, h('span.dim', ` (${x.why})`))))) : null,
    l.key.set ? note('', `The loader sets script_key from ${[...new Set(l.key.sources)].join('; ')}. Its value is never shown or sent anywhere by this tool.`) : null,
  ]);
}

export function loaderView(state, { onAnalyze, onFetch, onOpen, onAnalyzeStage, onIntel, onOpenText, onExport }) {
  const { result, busy, error } = state;
  const head = h('div.codebar',
    h('button.btn.primary', { type: 'button', disabled: busy, onclick: onAnalyze }, busy ? 'Analysing…' : 'Analyse the loader'),
    h('span.meta', 'Reads the script in the Deobfuscator tab. Nothing is run, and nothing is downloaded unless you press Fetch.'));
  if (error) return h('div.pad.loader', head, note('bad', error));
  if (!result) {
    return h('div.pad.loader', head, h('div.empty-block',
      h('h2', 'What does this loader fetch, and can it be retrieved?'),
      h('p.dim', 'Loader Analysis reads a loader without running it: the requests it makes, the address of each (as far as the file fixes it), keys and device checks, the service behind it, and which of six access cases applies.'),
      h('ul.dim', h('li', 'Public addresses can be fetched on your action, through this site’s fetcher, and each download is kept as a separate stage.'),
        h('li', 'Payloads that need a key, or that a service only hands to its own client, are not retrieved; the loader’s visible structure is analysed instead.'),
        h('li', 'Keys and tokens found in a loader are redacted in everything shown here.'))));
  }
  const a = result.best === 'recovered' && result.recovered ? result.recovered : result.input;
  const via = result.best === 'recovered' ? note('info', 'The input was obfuscated; this reads the recovered text, where the requests are visible.') : null;
  return h('div.pad.loader', head, via,
    h('div.loader-top',
      h('div.loader-case',
        h('div.eyebrow', `Case ${a.case.n} of 6`),
        h('h2', a.case.label),
        h('p', a.case.retrieval),
        a.explanation.map((e) => h('p.dim', e))),
      h('div.loader-side', caseLadder(a), progress(state, a))),
    luarmorSection(result.luarmor, { onOpenText }),
    a.isLoader ? intelSection(state, a, { onIntel, onOpenText, onExport }) : null,
    a.architectures.length ? section('Architecture', h('div.arch-list', a.architectures.map((x) => h('div.arch',
      h('b', x.label), x.evidence.length ? h('ul', x.evidence.map((e) => h('li', h('code', e)))) : null)))) : null,
    a.isLoader ? section(`Requests (${a.requests.length})`, h('div.table-scroll', h('table.grid.req-table',
      h('thead', h('tr', h('th', 'Line'), h('th', 'Call'), h('th', 'Address'), h('th', 'Service'), h('th', 'Retrieval'), h('th', ''))),
      h('tbody', a.requests.map((r) => requestRow(r, { onFetch, busy })))))) : null,
    a.families.length ? section('Service', a.families.map((f) => h('div.row-item', h('b', f.name), h('p.dim', f.access)))) : null,
    a.auth.markers.length ? section('Keys, tokens and device checks', [
      h('ul', a.auth.markers.map((m) => h('li', h('b', m.kind.replace(/-/g, ' ')), ': ', h('code', m.name), m.value ? [' = ', h('code', m.value)] : null, m.line ? h('span.faint', ` (line ${m.line})`) : null))),
      note('', 'Values are redacted. A key identifies its holder to the service; it is not used or sent by this tool.'),
    ]) : null,
    section(`Retrieved stages (${state.stages.length})`, state.stages.length
      ? state.stages.map((s, i) => stageCard(s, i, { onOpen, onAnalyzeStage }))
      : note('', a.requests.some((r) => r.retrieval.possible) ? 'Nothing fetched yet. Use Fetch stage on a request above; the download is kept here, separate from the loader, and is not run.' : 'No request of this loader can be retrieved through an authorised route.')));
}
