// The compatibility dashboard. Every number in it comes from data/compat.json, which is generated from the
// measured test results (tools/build-compat.mjs); nothing here is typed in.

import { h, pct, clear } from './dom.js';
import { statusBadge, STATUS_LABEL } from './views.js';

const BASIS = {
  'real-output': 'Tested on output of the real tool',
  synthetic: 'Tested on fixtures written to imitate the published technique',
  signature: 'Signature only; nothing was run',
};
const ORDER = ['supported', 'partial', 'experimental', 'unsupported'];
/** The same status in words for someone who just wants to know what they will get. */
const MEANING = {
  supported: 'Readable source back, checked against the original',
  partial: 'Most of it is undone; some parts stay',
  experimental: 'Recognised; recovery was not measured',
  unsupported: 'Recognised only; the source cannot be rebuilt',
};

export async function loadCompat() {
  const res = await fetch('data/compat.json', { cache: 'no-cache' });
  if (!res.ok) throw new Error(`data/compat.json: HTTP ${res.status}`);
  return res.json();
}

export class CompatDashboard {
  constructor(data, { onOpenSample } = {}) {
    this.data = data;
    this.filter = 'all';
    this.open = new Set();
    this.onOpenSample = onOpenSample;
    this.root = h('div.view');
    this.listeners = [];
    this.render();
  }

  select(id) {
    this.open.add(id);
    this.filter = 'all';
    this.render();
    const row = this.root.querySelector(`[data-fid="${id}"]`);
    if (row) row.scrollIntoView({ block: 'center' });
  }

  render() {
    const { families } = this.data;
    const counts = Object.fromEntries(ORDER.map((s) => [s, families.filter((f) => f.status === s).length]));
    const shown = families.filter((f) => this.filter === 'all' || f.status === this.filter)
      .sort((a, b) => ORDER.indexOf(a.status) - ORDER.indexOf(b.status) || a.name.localeCompare(b.name));
    const chip = (id, label) => h('button.chip', { type: 'button', 'aria-pressed': String(this.filter === id), onclick: () => { this.filter = id; this.render(); } }, label);

    const bar = h('div.legend', [
      h('span', { style: { color: 'var(--text)' } }, `${families.length} families`),
      ...ORDER.map((s) => h('span', [h('span.st.' + s, { style: { display: 'inline-block', width: '7px', height: '7px', borderRadius: '50%', marginRight: '6px' } }), `${counts[s]} ${STATUS_LABEL[s].toLowerCase()}`])),
      h('span', { style: { flex: 1 } }),
      h('span.faint.mono', `${this.data.scorecard.fixtures} fixtures · ${this.data.scorecard.generatedAt.slice(0, 10)} · engine ${this.data.engineVersion}`),
    ]);
    const filters = h('div.filters', [chip('all', 'all'), ...ORDER.map((s) => chip(s, s))]);

    const body = h('tbody');
    for (const f of shown) {
      const open = this.open.has(f.id);
      const m = f.measured;
      body.append(h('tr.row-main', {
        dataset: { fid: f.id }, class: open ? 'sel' : '', tabindex: '0', 'aria-expanded': String(open),
        onclick: () => this.toggle(f.id),
        onkeydown: (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); this.toggle(f.id); } },
      }, [
        h('td', [h('b', f.name), h('div.faint', f.kind)]),
        h('td', statusBadge(f.status)),
        h('td', MEANING[f.status]),
        h('td.faint', BASIS[f.basis]),
        h('td.num', m ? `${pct(m.fidelityBefore)} → ${pct(m.fidelityAfter)}` : '—'),
        h('td.num', m ? String(m.fixtures) : '—'),
      ]));
      if (open) body.append(h('tr', h('td.detail-cell', { colspan: '6' }, this.detail(f))));
    }

    clear(this.root);
    this.root.append(bar, filters, h('div.table-wrap', h('table.grid', [
      h('thead', h('tr', [h('th', 'Obfuscator'), h('th', 'Status'), h('th', 'What you get'), h('th', 'Tested on'), h('th', { title: 'Mean similarity to the original source, before → after recovery' }, 'Fidelity'), h('th', 'Fixtures')])),
      body,
    ])), this.footer());
  }

  toggle(id) {
    if (this.open.has(id)) this.open.delete(id); else this.open.add(id);
    this.render();
  }

  detail(f) {
    const parts = [];
    parts.push(h('div', [h('p', { style: { margin: '0 0 8px' } }, f.summary), h('p.dim', { style: { margin: 0 } }, f.detect)]));
    if (f.techniques.length) {
      parts.push(h('div', { style: { gridColumn: '1 / -1' } }, [
        h('h4', 'Measured per technique'),
        h('table.grid', { style: { marginTop: '4px' } }, [
          h('thead', h('tr', [h('th', 'Technique'), h('th', 'Status'), h('th', 'Fidelity'), h('th', 'Needs sandbox'), h('th', { title: 'Output of the recovered script equals the output of the original program, on a real Lua' }, 'Behaviour'), h('th', { title: 'Trace of the obfuscated script equals the trace of the original program' }, 'Trace'), h('th', 'Note')])),
          h('tbody', f.techniques.map((t) => h('tr', [
            h('td', [t.label, h('span.faint', `  ${t.kind}`)]),
            h('td', statusBadge(t.status)),
            h('td.num', `${pct(t.fidelityBefore)} → ${pct(t.fidelityAfter)}`),
            h('td', t.needsSandbox ? `yes (${pct(t.fidelityStatic)} without)` : 'no'),
            h('td.num', t.behaviourChecked ? `${t.behaviourSame}/${t.behaviourChecked} same` : '—'),
            h('td.num', t.traceChecked ? `${t.traceIdentical}/${t.traceChecked}` : '—'),
            h('td', [t.note || '', t.toolBroken ? h('div.faint', `the tool's own output was wrong for ${t.toolBroken} of ${t.samples} samples`) : null]),
          ]))),
        ]),
      ]));
    }
    if (f.limits.length) parts.push(h('div', [h('h4', 'Limits'), h('ul', f.limits.map((x) => h('li', x)))]));
    if (f.untestedTechniques.length) parts.push(h('div', [h('h4', 'Documented, not covered by any fixture'), h('ul', f.untestedTechniques.map((x) => h('li', x)))]));
    if (f.sources.length) parts.push(h('div', [h('h4', 'Public sources'), h('ul', f.sources.map((u) => h('li.mono', u)))]));
    return h('div.detail-grid', parts);
  }

  footer() {
    return h('div.legend', { style: { borderTop: '1px solid var(--line)', borderBottom: 0 } }, [
      h('span', [
        h('b', 'How to read this. '),
        'Fidelity is the overlap between the recovered code and the original program the fixture was made from (identifier names ignored). ',
        'Behaviour compares what the recovered script prints against what the original program prints, on a real Lua. ',
        '“Supported” needs both. Entries without fixtures are signatures only. ',
        'Trace is a separate fallback: the script is run in the sandbox against stand-in objects and what it does is listed. It is a description of one run, not recovered source, and it needs the sandbox consent.',
      ]),
    ]);
  }
}
