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

/** The research database (data/research/format-db.json): what was learned, what failed, what was changed, what is assumed. Optional: the dashboard works without it. */
export async function loadFormatDb() {
  try {
    const res = await fetch('data/research/format-db.json', { cache: 'no-cache' });
    return res.ok ? await res.json() : null;
  } catch { return null; }
}

const SUPPORT_WORDS = {
  verified: 'verified: recovery measured on real output, checked against the original on a real runtime',
  mixed: 'mixed: some configurations verified, others not',
  experimental: 'experimental: improvement measured, not yet at the bar',
  unsupported: 'unsupported: recognised; source cannot be rebuilt',
  'identification-only': 'identification only: nothing about recovery was measured',
};

export class CompatDashboard {
  constructor(data, { onOpenSample, db = null } = {}) {
    this.db = db;
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
    ])), this.layered(), this.collection(), this.footer());
  }

  /** What the scripts of the public collection that no rule recognised were classified as (the research database's collection block). */
  collection() {
    const c = this.db && this.db.collection;
    if (!c) return h('div');
    const rows = c.folders.filter((x) => x.unidentified && x.classOfUnidentified);
    if (!rows.length) return h('div');
    return h('div', { style: { margin: '18px 0 0' } }, [
      h('h4', 'Scripts of the public collection that no rule recognised'),
      h('p.dim', { style: { margin: '0 0 6px' } }, `${c.files} real scripts (${c.source}, commit ${String(c.commit).slice(0, 7)}). A script no rule knows is classified by what it is made of: a loader that downloads its program, a minified script, a program stored as numbers ... A class is not a claim about which tool made it.`),
      h('div.table-wrap', h('table.grid', [
        h('thead', h('tr', [h('th', 'Folder'), h('th', 'Files'), h('th', 'Not identified'), h('th', 'Classified as')])),
        h('tbody', rows.map((x) => h('tr', [h('td', x.label), h('td.num', String(x.files)), h('td.num', String(x.unidentified)),
          h('td', Object.entries(x.classOfUnidentified).sort((a, b) => b[1] - a[1]).map(([k, n]) => `${k} \u00d7${n}`).join(', '))]))),
      ])),
    ]);
  }

  /** Real tools stacked with packers and with home-made transformations: what the pipeline does when no single signature explains a script. */
  layered() {
    const rows = this.data.layered || [];
    if (!rows.length) return h('div');
    return h('div', { style: { margin: '18px 0 0' } }, [
      h('h4', 'Layered (mixed) obfuscation'),
      h('p.dim', { style: { margin: '0 0 6px' } }, 'The outermost layer is what an analyst sees first. Fidelity compares the recovered code with the program the chain protects; behaviour counts only chains whose own output runs like the original.'),
      h('div.table-wrap', h('table.grid', [
        h('thead', h('tr', [h('th', 'Chain'), h('th', 'Layers'), h('th', 'Detected'), h('th', 'Fidelity'), h('th', 'Same behaviour'), h('th', 'Status')])),
        h('tbody', rows.map((l) => h('tr', [
          h('td', [l.id, h('div.faint', l.stages.join(' \u2192 '))]), h('td.num', String(l.layers)), h('td.num', `${l.detected}/${l.samples}`),
          h('td.num', `${pct(l.fidelityBefore)} \u2192 ${pct(l.fidelityAfter)}`), h('td.num', l.behaviourChecked ? `${l.behaviourSame}/${l.behaviourChecked}` : '\u2014'), h('td', statusBadge(l.status)),
        ]))),
      ])),
    ]);
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
    if (f.versions && f.versions.length) {
      parts.push(h('div', { style: { gridColumn: '1 / -1' } }, [
        h('h4', 'Measured per revision of the tool'),
        h('p.dim', { style: { margin: '0 0 4px' } }, 'Each revision that can still be run, on its own fixtures; never averaged with the current one. A version is what the watermark in the tool\u2019s source says.'),
        h('table.grid', { style: { marginTop: '4px' } }, [
          h('thead', h('tr', [h('th', 'Version'), h('th', 'Revision'), h('th', 'Fidelity'), h('th', 'Same behaviour'), h('th', 'Configurations supported / partial / not'), h('th', 'Not supported')])),
          h('tbody', f.versions.map((v) => h('tr', [
            h('td', v.version), h('td.mono', `${String(v.revision).slice(0, 7)} ${v.revisionDate || ''}`),
            h('td.num', `${pct(v.fidelityBefore)} → ${pct(v.fidelityAfter)}`), h('td.num', `${v.behaviourSame}/${v.behaviourChecked}`),
            h('td.num', `${v.supported} / ${v.partial} / ${v.unsupported}`),
            h('td.faint', v.configs.filter((c) => c.status === 'unsupported').map((c) => `${c.config} (${pct(c.fidelityAfter)})`).join(', ') || '—'),
          ]))),
        ]),
      ]));
    }
    const rec = this.db && this.db.projects.find((p) => p.id === f.id);
    if (rec) {
      parts.push(h('div', { style: { gridColumn: '1 / -1' } }, [
        h('h4', 'Research record'),
        h('p.dim', { style: { margin: '0 0 6px' } }, `${SUPPORT_WORDS[rec.support] || rec.support}. Generated from the measured results and the hand-written notes in data/research/format-notes.json.`),
        rec.versions.length ? h('table.grid', { style: { marginTop: '4px' } }, [
          h('thead', h('tr', [h('th', 'Version'), h('th', 'Revision run'), h('th', 'Fixtures'), h('th', 'Tool failed on'), h('th', 'Configurations verified / partial / not'), h('th', 'Fixtures kept')])),
          h('tbody', rec.versions.map((v) => h('tr', [
            h('td', v.version), h('td.mono', v.revision ? `${String(v.revision).slice(0, 7)} ${v.revisionDate || ''}` : '\u2014'),
            h('td.num', String(v.fixtures.measured)), h('td.num', String(v.fixtures.toolErrors)),
            h('td.num', `${v.summary.verified} / ${v.summary.partial} / ${v.summary.unsupported}`),
            h('td.faint', v.committed === null ? '\u2014' : v.committed ? 'in the repository' : 'local only (licence)'),
          ]))),
        ]) : null,
      ]));
      const list = (title, items, row) => h('div', [h('h4', title), h('ul', items.map(row))]);
      if (rec.failurePatterns.length) {
        parts.push(list('Failure patterns', rec.failurePatterns, (x) => h('li', [
          h('b', x.id), h('span.faint', ` (${x.status}${x.configs && x.configs.length ? `; ${x.configs.join(', ')}` : ''})`), ` ${x.summary}`,
        ])));
      }
      if (rec.improvements.length) {
        parts.push(list('Improvements made because of them', rec.improvements, (x) => h('li', [
          h('b', x.id), ` ${x.summary}`, h('div.faint.mono', [...(x.files || []), ...(x.tests || [])].join('  \u00b7  ')),
        ])));
      }
      if (rec.assumptions.length) parts.push(list('Assumed, not shown', rec.assumptions, (x) => h('li', x)));
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
