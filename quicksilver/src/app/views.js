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

// ---- inspector: what happened in the last run ------------------------------------------------------------------------------

export function recoverySummary(r) {
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
