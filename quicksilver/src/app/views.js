// Renderers for the report-style tabs and the inspector. They take engine results and return DOM nodes;
// everything that comes from the script itself is inserted as text.

import { h, pct, fmtBytes, fmtMs } from './dom.js';

export const STATUS_LABEL = { supported: 'Supported', partial: 'Partially supported', experimental: 'Experimental', unsupported: 'Unsupported' };
const STATUS_BADGE = { supported: 'ok', partial: 'warn', experimental: 'info', unsupported: 'bad' };
export const statusBadge = (s) => h('span.badge.' + STATUS_BADGE[s], STATUS_LABEL[s] || s);

const levelBadge = (level) => h('span.badge.' + ({ high: 'ok', medium: 'warn', low: 'bad', minimal: 'bad', none: 'bad' }[level] || ''), level);

function meter(x) { return h('div.meter', h('i', { style: { width: `${Math.round(x * 100)}%` } })); }

const section = (title, body, aside) => h('section.section', h('h3', h('span', title), aside || null), h('div.body', body));
const kv = (rows) => h('dl.kv', rows.filter(Boolean).flatMap(([k, v]) => [h('dt', k), h('dd', v == null ? '—' : v)]));
const note = (kind, text) => h('p.note' + (kind ? '.' + kind : ''), text);

// ---- detection -------------------------------------------------------------------------------------------------------

const EVIDENCE_NOTE = {
  source: 'Signatures verified against the tool’s own output.',
  banner: 'Based on a banner or header only; the real structure was not available.',
  none: 'No public signature exists; this is a generic heuristic.',
};

export function detectionView(det, compat) {
  const wrap = h('div.pane-body', { style: { padding: '0' } });
  if (!det) return wrap;
  const fams = det.families.filter((f) => f.confidence >= 0.2);
  wrap.append(section('Obfuscator', [
    fams.length ? h('ul.list', fams.map((f) => {
      const c = compat && compat.get(f.id);
      return h('li', [
        h('div', { style: { display: 'flex', gap: '8px', alignItems: 'baseline' } },
          h('b', f.name), f.version ? h('span.dim.mono', f.version) : null, h('span.grow', { style: { flex: 1 } }),
          h('span.mono', pct(f.confidence)), c ? statusBadge(c.status) : null),
        meter(f.confidence),
        h('div.dim', { style: { marginTop: '4px' } }, EVIDENCE_NOTE[f.evidenceLevel] || ''),
        h('ul', { style: { margin: '4px 0 0', paddingLeft: '16px' } }, f.evidence.map((e) => h('li', { style: { border: 0, padding: '1px 0' } },
          e.text, ' ', h('span.faint.mono', `[${e.rule}]`), e.unrecoverable ? h('span.badge.bad', { style: { marginLeft: '6px' } }, 'not recoverable') : null))),
      ]);
    })) : note('ok', 'No known obfuscator signature matched. Structural traits below still apply.'),
  ]));
  wrap.append(section('Language', kv([
    ['Dialect', `${det.dialect.label}  (${pct(det.dialect.confidence)})`],
    ['Also valid as', det.dialect.compatible.filter((d) => d.id !== det.dialect.id).map((d) => d.label).join(', ') || '—'],
    ['Syntax', det.parsed ? 'parses' : `does not parse: ${det.parseError ? `${det.parseError.line}:${det.parseError.col} ${det.parseError.message}` : ''}`],
  ]), null));
  if (det.dialect.evidence.length) wrap.lastChild.querySelector('.body').append(h('ul', { style: { margin: '6px 0 0', paddingLeft: '16px' } }, det.dialect.evidence.map((e) => h('li', e))));
  wrap.append(section('Traits', det.traits.length
    ? h('ul.list', det.traits.map((t) => h('li', [h('span.mono.dim', t.id), '  ', t.text])))
    : note('', 'No structural traits of obfuscation were found.')));
  if (det.bytecode) {
    wrap.append(section('Compiled chunk', [
      kv([['Format', det.bytecode.format], ['Version', det.bytecode.version], ['Offset', det.bytecode.offset != null ? String(det.bytecode.offset) : null]]),
      note('warn', 'A compiled Lua chunk is not source. QuickSilver reports what it can see of it but cannot turn it back into source.'),
    ]));
  }
  const m = det.metrics || {};
  wrap.append(section('Measurements', kv([
    ['Size', fmtBytes(m.bytes || 0)],
    ['Lines', String(m.lines ?? '')],
    ['AST nodes', String(m.nodes ?? '')],
    ['Machine names', m.mangledRatio != null ? pct(m.mangledRatio) : null],
    ['Longest string', m.longestString != null ? `${m.longestString} chars` : null],
    ['VM score', m.vm ? String(m.vm.score) : null],
  ])));
  if (m.vm && m.vm.reasons && m.vm.reasons.length) wrap.lastChild.querySelector('.body').append(h('ul', { style: { margin: '6px 0 0', paddingLeft: '16px' } }, m.vm.reasons.map((r) => h('li', r))));
  return wrap;
}

// ---- analysis ----------------------------------------------------------------------------------------------------------

export function analysisView(rep) {
  const wrap = h('div.pane-body', { style: { padding: '0' } });
  if (!rep.ok) {
    wrap.append(section('Analysis', note('bad', `The script does not parse (${rep.error.line}:${rep.error.col} ${rep.error.message}), so there is no syntax tree to analyse. Detection still ran; use Beautify for a layout-only repair.`)));
    return wrap;
  }
  const s = rep.summary;
  wrap.append(section('Summary', kv([
    ['Size', `${fmtBytes(s.bytes)}, ${s.lines} lines`],
    ['Dialect', s.dialect],
    ['Functions', String(s.functions)],
    ['Locals / globals', `${s.locals} / ${s.globals}`],
    ['Max nesting', String(s.maxNesting)],
    ['String literals', String(s.strings)],
    ['AST nodes', String(s.nodes)],
  ])));
  const structure = structureSection(rep.structure, { onGoto: rep.onGoto });
  if (structure) wrap.append(structure);
  if (rep.indicators.length) {
    wrap.append(section('Indicators', h('ul.list', rep.indicators.map((i) => h('li', [
      h('span.badge.' + ({ high: 'bad', medium: 'warn', info: 'info' }[i.severity] || ''), i.severity), ' ', i.text])))));
    wrap.lastChild.querySelector('.body').append(note('', 'Indicators say what the code is able to do, not what it does. Nothing was run.'));
  }
  const list = (title, items, render = (x) => x) => items.length && section(title, h('ul.list.mono', items.map((x) => h('li', render(x)))), h('span.faint.mono', String(items.length)));
  [
    list('Webhooks', rep.webhooks),
    list('URLs', rep.urls),
    list('IP addresses', rep.ips),
  ].forEach((x) => x && wrap.append(x));
  if (rep.apiUse.length) wrap.append(section('API use', h('ul.list', rep.apiUse.map((g) => h('li', [h('b', g.label), '  ', h('span.mono.dim', g.names.join(', '))])))));
  if (rep.calls.length) wrap.append(section('Most called', h('ul.list.mono', rep.calls.map((c) => h('li', [c.name, h('span.faint', `  ×${c.count}`)])))));
  if (rep.globals.length) wrap.append(section('Globals touched', h('ul.list.mono', rep.globals.slice(0, 40).map((g) => h('li', [g.name, h('span.faint', `  read ${g.reads}, written ${g.writes}`)])))));
  if (rep.strings.length) wrap.append(section('Notable strings', h('ul.list.mono', rep.strings.slice(0, 80).map((x) => h('li', { style: { overflowWrap: 'anywhere' } }, JSON.stringify(x).slice(0, 200)))), h('span.faint.mono', String(rep.strings.length))));
  if (rep.functions.length) {
    wrap.append(section('Functions', h('ul.list.mono', rep.functions.slice(0, 60).map((f) =>
      h('li', `line ${f.line || '?'}  ${f.params} param${f.params === 1 ? '' : 's'}${f.vararg ? ' + ...' : ''}  ${f.statements} stmt`)))));
  }
  return wrap;
}

// ---- structure: what the shape of the code says -----------------------------------------------------------------------------

export const KIND_LABEL = {
  dispatcher: 'Flattened control flow',
  'opaque-predicate': 'Opaque predicates',
  'call-proxy': 'Call proxies',
  'constant-table': 'Constant tables',
  'string-decoder': 'String decoders',
  'dynamic-code': 'Code loaded at run time',
  interpreter: 'Virtual machine',
  payload: 'Encoded payload',
};
const kindLabel = (k) => KIND_LABEL[k] || k;
const OUTCOME = { accepted: ['ok', 'kept'], rejected: ['bad', 'undone'], noop: ['', 'nothing to do'], failed: ['bad', 'failed'], skipped: ['', 'skipped'] };

const lineLink = (line, onGoto) => (line && onGoto ? h('a', { href: '#', onclick: (e) => { e.preventDefault(); onGoto(line); } }, `line ${line}`) : line ? `line ${line}` : null);

/** The Analyze tab: what the structure of the code shows, read without changing anything. */
export function structureSection(st, { onGoto } = {}) {
  if (!st) return null;
  if (!st.findings.length) return section('Structure', note('ok', 'No disguised control flow, string decoders, call proxies or opaque conditions were found in the shape of the code.'));
  const byKind = new Map();
  for (const f of st.findings) { if (!byKind.has(f.kind)) byKind.set(f.kind, []); byKind.get(f.kind).push(f); }
  return section('Structure', [
    note('', 'Read from the shape of the code, not from any list of obfuscators. Nothing was run and nothing was changed.'),
    ...[...byKind].map(([kind, list]) => h('div', { style: { marginTop: '8px' } }, [
      h('b', `${kindLabel(kind)} `), h('span.faint.mono', `×${list.length}`),
      h('ul.list', list.slice(0, 12).map((f) => h('li', [
        f.label, ' ', lineLink(f.line, onGoto) ? h('span.faint', ['(', lineLink(f.line, onGoto), ')']) : null,
        h('ul', { style: { margin: '2px 0 0', paddingLeft: '16px' } }, f.evidence.map((e) => h('li', { style: { border: 0, padding: '1px 0' } }, e))),
        f.residual ? h('div.dim', { style: { marginTop: '2px' } }, f.residual) : null,
      ]))),
      list.length > 12 ? h('div.faint', `and ${list.length - 12} more`) : null,
    ])),
  ], h('span.faint.mono', `opacity ${st.score}`));
}

/** The inspector, after a recovery: what the adaptive engine saw, did and left, and the behaviour check. */
export function adaptiveSummary(ad, { onGoto, onVerify, verify, canVerify } = {}) {
  if (!ad || !ad.ran) return [];
  const out = [];
  const kept = ad.decisions.filter((d) => d.outcome === 'accepted' && !d.strategy.startsWith('cleanup.')).length;
  if (!ad.hypotheses.length) {
    out.push(section('Structure', [note('ok', 'No disguised control flow, string decoders, call proxies or opaque conditions were left for the structure reader to handle.')]));
  } else {
    out.push(section('Structure read', [
      kv([
        ['Disguise left', h('span', [`${ad.score.before} \u2192 ${ad.score.after}`, ' ', ad.score.after === 0 ? h('span.badge.ok', 'none') : h('span.badge.warn', 'some')])],
        ['Strategies kept', `${kept} of ${new Set(ad.decisions.filter((d) => !d.strategy.startsWith('cleanup.')).map((d) => d.strategy)).size} tried`],
        ['Time', fmtMs(ad.ms)],
      ]),
      h('table.steps', h('tbody', ad.kinds.map((k) => h('tr', [
        h('td', kindLabel(k.kind)),
        h('td', `${k.resolved} of ${k.found} resolved`),
      ])))),
      h('details', { style: { marginTop: '8px' } }, [
        h('summary', 'What it saw'),
        h('ul.list', ad.hypotheses.slice(0, 40).map((f) => h('li', [
          f.label, ' ', lineLink(f.line, onGoto) ? h('span.faint', ['(', lineLink(f.line, onGoto), ')']) : null,
          h('ul', { style: { margin: '2px 0 0', paddingLeft: '16px' } }, f.evidence.map((e) => h('li', { style: { border: 0, padding: '1px 0' } }, e))),
        ]))),
      ]),
      h('details', [
        h('summary', 'What it did'),
        h('table.steps', h('tbody', ad.decisions.filter((d) => d.outcome !== 'noop').map((d) => h('tr', [
          h('td', [d.title, d.note ? h('div.faint', d.note) : null]),
          h('td', [h('span.badge' + (OUTCOME[d.outcome][0] ? '.' + OUTCOME[d.outcome][0] : ''), OUTCOME[d.outcome][1]), d.outcome === 'accepted' && d.changed ? h('span.faint', ` \u00d7${d.changed}`) : null]),
        ])))),
      ]),
    ], h('span.faint.mono', 'adaptive')));
  }
  if (ad.residual.length) {
    out.push(section('Left as it was', [
      note('warn', 'The structure reader found these and could not take them apart. The output still contains them.'),
      h('ul.list', ad.residual.slice(0, 30).map((r) => h('li', [
        h('b', kindLabel(r.kind)), ' ', lineLink(r.line, onGoto) ? h('span.faint', ['(', lineLink(r.line, onGoto), ')']) : null,
        h('div', r.label),
        h('div.dim', r.reason),
      ]))),
    ], h('span.faint.mono', String(ad.residual.length))));
  }
  if (ad.blocked && ad.blocked.some((b) => b.why === 'sandbox')) {
    out.push(section('Needs the sandbox', [note('info', 'Some of the disguise can only be removed by running the script\u2019s own decoder functions in the sandbox. Switch it on in Settings and recover again.')]));
  }
  if (canVerify) {
    out.push(section('Check the behaviour', [
      h('p.note', 'Runs the original and the recovered program in the sandbox and compares what each one does: calls, properties set, printed output, how it ends. Equal runs are evidence, not proof.'),
      verify && verify.running ? h('p.note.info', 'Running both programs\u2026') : h('button.btn.small.outline', { type: 'button', onclick: onVerify }, verify && verify.result ? 'Check again' : 'Run both and compare\u2026'),
      verify && verify.error ? h('p.note.bad', verify.error) : null,
      verify && verify.result ? verifyResult(verify.result) : null,
    ]));
  }
  return out;
}

function verifyResult(v) {
  const kind = v.verdict === 'identical' ? 'ok' : v.verdict === 'different' ? 'bad' : 'warn';
  return h('div', { style: { marginTop: '8px' } }, [
    h('p.note.' + kind, [h('b', v.verdict === 'identical' ? 'Same behaviour. ' : v.verdict === 'different' ? 'Different behaviour. ' : 'Inconclusive. '), v.summary]),
    v.difference ? kv([
      ['First difference', v.difference.index >= 0 ? `event ${v.difference.index + 1}` : 'at the end'],
      ['Original', h('span.mono', v.difference.original)],
      ['Recovered', h('span.mono', v.difference.recovered)],
    ]) : null,
    ...v.notes.map((n) => h('p.note', n)),
    h('p.faint', `Original: ${v.original.events} events, ${v.original.status}. Recovered: ${v.recovered.events} events, ${v.recovered.status}. ${fmtMs(v.ms)}.`),
  ]);
}

// ---- inspector: what happened in the last run ------------------------------------------------------------------------------

export function recoverySummary(r, helpers = {}) {
  const out = [];
  if (!r) return out;
  if (!r.ok && r.stage === 'parse') {
    out.push(section('Recovery', [note('bad', `The input does not parse: ${r.error.line}:${r.error.col} ${r.error.message}. Recovery works on a syntax tree, so nothing was changed. Beautify can still repair the layout.`)]));
    return out;
  }
  const c = r.confidence;
  out.push(section('Result', [
    kv([
      ['Confidence', c ? h('span', [`${pct(c.score)} `, levelBadge(c.level)]) : null],
      ['Validation', r.validation ? (r.validation.ok ? 'parses, prints back identically' : r.validation.message) : null],
      ['Time', fmtMs(r.ms)],
    ]),
    c ? meter(c.score) : null,
    c ? h('ul.list', { style: { marginTop: '8px' } }, c.reasons.map((x) => h('li', [h('span.mono.faint', x.effect ? (x.effect > 0 ? `+${Math.round(x.effect * 100)}` : `${Math.round(x.effect * 100)}`).padStart(4) : '   ·'), '  ', x.text]))) : null,
    note('', 'Confidence is derived from what is still visible in the output. It is not a guarantee that the result equals the original program.'),
  ]));
  out.push(...adaptiveSummary(r.adaptive, { ...helpers, canVerify: helpers.canVerify && r.output != null }));
  const steps = r.steps || [];
  out.push(section('Passes', h('table.steps', h('tbody', steps.map((s) => h('tr', [
    h('td', { class: `s-${s.status}` }, s.label, s.status === 'failed' ? h('div.dim', s.error) : (s.status === 'skipped' && typeof s.detail === 'string' ? h('div.faint', s.detail) : null)),
    h('td', s.status === 'applied' ? `×${s.changed}` : s.status),
  ]))))));
  if (r.warnings && r.warnings.length) out.push(section('Warnings', r.warnings.map((w) => note('warn', w))));
  return out;
}

export function detectionSummary(det, compat) {
  if (!det) return [];
  const top = det.families.filter((f) => f.confidence >= 0.5);
  const out = [];
  out.push(section('Detected', [
    top.length ? h('ul.list', top.map((f) => {
      const c = compat && compat.get(f.id);
      return h('li', [h('div', { style: { display: 'flex', gap: '8px', alignItems: 'baseline' } }, h('b', f.name), h('span.mono', pct(f.confidence)), h('span', { style: { flex: 1 } }), c ? statusBadge(c.status) : null), meter(f.confidence)]);
    })) : note('', 'No known obfuscator matched.'),
    kv([['Dialect', det.dialect.label], ['Traits', det.traits.map((t) => t.id).join(', ') || '—']]),
  ]));
  return out;
}
