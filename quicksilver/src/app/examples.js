// The Examples tab: every bundled script, grouped by the obfuscator that made it, with a timer.
//
// "Time" runs the same recovery as the Deobfuscate button on one example in the background and shows how long it took and
// what came out; "Time all" does that for every obfuscated example in turn. Opening an example puts it in the editor.
// The offline column is not measured here: it is the fidelity and behaviour check recorded when the sample set was built
// (tools/build-samples.mjs reads tests/results/scorecard.json), against the original program the example was made from.

import { h, icon, replace, fmtBytes, pct } from './dom.js';

const clock = (ms) => (ms < 60_000 ? `${(ms / 1000).toFixed(2)} s` : `${Math.floor(ms / 60_000)}:${String(Math.floor(ms / 1000) % 60).padStart(2, '0')}.${Math.floor((ms % 1000) / 100)}`);

export class ExamplesBoard {
  /**
   * @param {{
   *   samples: () => Promise<{groups: Array}>,
   *   open: (item) => Promise<void>,
   *   bench: (item) => Promise<{wall: number, r: object}>,
   *   begin: (label: string) => boolean,
   *   end: () => void,
   *   sandbox: () => boolean,
   * }} ctl
   */
  constructor(ctl) {
    this.ctl = ctl;
    this.index = null;
    this.rows = new Map(); // file -> { item, state, cells }
    this.stop = false;
    this.running = false;
    this.summary = h('span.summary');
    this.runAll = h('button.btn.small.outline', { type: 'button', title: 'Recover every obfuscated example in turn and time each one', onclick: () => this.timeAll() }, icon('timer'), h('span.lbl', 'Time all'));
    this.stopBtn = h('button.btn.small', { type: 'button', hidden: true, onclick: () => { this.stop = true; this.stopBtn.disabled = true; } }, icon('stop'), h('span.lbl', 'Stop after this one'));
    this.note = h('span.faint');
    this.body = h('div.table-wrap');
    this.root = h('div.view.examples', h('div.codebar', this.summary, h('span.grow'), this.note, this.runAll, this.stopBtn), this.body);
  }

  async show() {
    if (this.index) { this.refreshNote(); return; }
    replace(this.body, h('div.empty', h('b', 'Loading'), h('span', 'Reading data/samples/index.json')));
    this.index = await this.ctl.samples();
    this.build();
  }

  refreshNote() {
    this.note.textContent = this.ctl.sandbox() ? 'sandbox on: string decoders are evaluated' : 'sandbox off: encoded strings stay encoded (Settings)';
  }

  build() {
    this.rows.clear();
    this.refreshNote();
    const table = h('table.grid.examples-table');
    table.append(h('thead', h('tr', ['Example', 'Size', 'Offline check', 'Time', 'Result', ''].map((t, i) => h('th' + (i === 1 || i === 3 ? '.num' : ''), t)))));
    for (const g of this.index.groups) {
      const tbody = h('tbody');
      tbody.append(h('tr.group', h('td', { colspan: '6' }, h('b', g.label), g.note ? h('span.faint', `  ${g.note}`) : null)));
      for (const item of g.items) {
        const cells = {
          status: h('td.res'), time: h('td.num.time'), off: h('td.off'),
        };
        const open = h('button.btn.small', { type: 'button', title: 'Put this example in the editor', onclick: () => this.ctl.open(item, false) }, 'Open');
        const run = h('button.btn.small', { type: 'button', title: 'Open it and press Deobfuscate', onclick: () => this.ctl.open(item, true) }, 'Open + deobfuscate');
        const time = h('button.btn.small.icon', { type: 'button', title: 'Time the recovery of this example only', 'aria-label': `Time ${item.label}`, onclick: () => this.timeOne(item) }, icon('timer'));
        const row = h('tr.row-main', { dataset: { file: item.file } },
          h('td', h('b', item.label), h('div.faint', item.file)),
          h('td.num', item.sub || fmtBytes(item.bytes)),
          cells.off,
          cells.time, cells.status,
          h('td.acts', time, open, run));
        this.rows.set(item.file, { item, cells, buttons: [time, open, run], state: { kind: 'idle' }, obfuscated: !g.plain });
        this.paintOffline(item, cells.off);
        this.paint(item.file);
        tbody.append(row);
      }
      table.append(tbody);
    }
    replace(this.body, table);
    this.paintSummary();
  }

  paintOffline(item, cell) {
    const m = item.measured;
    if (!m || m.after == null) { replace(cell, h('span.faint', 'not measured')); return; }
    const badge = { same: ['.ok', 'same output as the original'], differs: ['.bad', 'output differs'], 'tool-broken': ['.warn', 'the tool\u2019s own output is broken'] }[m.behaviour];
    replace(cell, [`${pct(m.before ?? 0)} \u2192 `, h('b', pct(m.after)), ' ', badge ? h(`span.badge${badge[0]}`, badge[1]) : null]);
  }

  paint(file) {
    const row = this.rows.get(file);
    const { cells, state } = row;
    cells.time.textContent = state.ms != null ? clock(state.ms) : '';
    cells.time.classList.toggle('live', state.kind === 'running');
    let text = null;
    switch (state.kind) {
      case 'running': text = h('span.badge.accent', 'running'); break;
      case 'ok': text = [state.family ? h('b', state.family) : 'No known obfuscator', ` · confidence ${pct(state.confidence ?? 0)}`, ' ', h('span.badge' + (state.parses ? '.ok' : '.bad'), state.parses ? 'parses' : 'does not parse')]; break;
      case 'fail': text = h('span.badge.bad', state.message); break;
      case 'cancel': text = h('span.badge.warn', state.message); break;
      default: text = null;
    }
    replace(cells.status, text);
  }

  paintSummary() {
    const rows = [...this.rows.values()].filter((r) => r.obfuscated);
    const done = rows.filter((r) => r.state.kind === 'ok');
    const total = done.reduce((n, r) => n + r.state.ms, 0);
    const slowest = done.reduce((a, r) => (!a || r.state.ms > a.state.ms ? r : a), null);
    this.summary.textContent = done.length
      ? `${done.length} of ${rows.length} timed · total ${clock(total)} · slowest ${slowest.item.label} (${clock(slowest.state.ms)})`
      : `${rows.length} obfuscated examples · none timed yet`;
  }

  setDisabled(on) {
    this.runAll.disabled = on;
    for (const r of this.rows.values()) for (const b of r.buttons) b.disabled = on;
  }

  async timeOne(item) {
    if (this.running) return;
    if (!this.ctl.begin(`Timing ${item.label}`)) return;
    this.running = true;
    this.setDisabled(true);
    try { await this.measure(item); } finally { this.running = false; this.setDisabled(false); this.ctl.end(); this.paintSummary(); }
  }

  async timeAll() {
    if (this.running || !this.index) return;
    if (!this.ctl.begin('Timing all examples')) return;
    this.running = true;
    this.stop = false;
    this.setDisabled(true);
    this.stopBtn.hidden = false;
    this.stopBtn.disabled = false;
    try {
      for (const r of this.rows.values()) {
        if (!r.obfuscated) continue;
        if (this.stop) break;
        const ok = await this.measure(r.item);
        if (ok === 'cancelled') break;
      }
    } finally {
      this.running = false;
      this.stopBtn.hidden = true;
      this.setDisabled(false);
      this.ctl.end();
      this.paintSummary();
    }
  }

  /** Runs one example; keeps the row up to date while it runs. Resolves 'cancelled' when the user cancelled the run. */
  async measure(item) {
    const row = this.rows.get(item.file);
    const t0 = performance.now();
    row.state = { kind: 'running', ms: 0 };
    this.paint(item.file);
    row.cells.time.scrollIntoView({ block: 'nearest' });
    const tick = setInterval(() => { row.state.ms = performance.now() - t0; row.cells.time.textContent = clock(row.state.ms); }, 80);
    try {
      const { wall, r } = await this.ctl.bench(item);
      const top = r.detection && r.detection.families.find((f) => f.confidence >= 0.5);
      row.state = {
        kind: r.ok && r.output != null ? 'ok' : 'fail', ms: wall, engineMs: r.ms,
        family: top ? `${top.name}${top.version ? ` ${top.version}` : ''}` : null,
        confidence: r.confidence ? r.confidence.score : null,
        passes: (r.steps || []).filter((s) => s.status === 'applied').length,
        parses: !!(r.validation && r.validation.ok),
        message: r.error ? `stopped: ${r.error.message}` : 'no output',
      };
    } catch (e) {
      const cancelled = e && e.kind === 'cancelled';
      row.state = { kind: cancelled ? 'cancel' : 'fail', ms: performance.now() - t0, message: cancelled ? 'cancelled' : e && e.kind === 'timeout' ? 'timed out' : String((e && e.message) || e).split('\n')[0] };
      if (cancelled) { clearInterval(tick); this.paint(item.file); return 'cancelled'; }
    } finally { clearInterval(tick); }
    this.paint(item.file);
    return row.state.kind;
  }
}

