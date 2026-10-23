// Side-by-side diff on a virtual row list (same idea as viewer.js). Rows come from the engine's diff op;
// unchanged stretches can be folded so a three-line change in a 40,000 line script is not a scroll hunt.

import { h } from './dom.js';
import { LH, charWidth } from './viewer.js';
import { collapseRows } from '../core/diff.js';

const OVERSCAN = 20;

export class DiffView {
  constructor() {
    this.rows = [];
    this.shown = [];
    this.a = [];
    this.b = [];
    this.fold = true;
    this.hunks = [];
    this.hunk = -1;
    this.spacer = h('div.spacer');
    this.body = h('div.rows', { style: { width: '100%' } });
    this.root = h('div.viewer', { tabindex: '0' }, this.spacer, this.body);
    this.root.addEventListener('scroll', () => this.schedule());
    this.raf = 0;
    new ResizeObserver(() => this.schedule()).observe(this.root);
  }

  /** @param {string[]} a left lines  @param {string[]} b right lines  @param {Array} rows from toRows() */
  setData(a, b, rows) {
    this.a = a;
    this.b = b;
    this.rows = rows;
    this.hunk = -1;
    this.reflow();
  }

  setFold(on) { this.fold = on; this.reflow(); }

  reflow() {
    this.shown = this.fold ? collapseRows(this.rows, 3) : this.rows;
    this.hunks = [];
    let inHunk = false;
    this.shown.forEach((r, i) => {
      const changed = r.kind !== 'eq' && r.kind !== 'fold';
      if (changed && !inHunk) this.hunks.push(i);
      inHunk = changed;
    });
    this.spacer.style.height = `${this.shown.length * LH}px`;
    this.root.scrollTop = 0;
    this.render();
  }

  schedule() {
    if (this.raf) return;
    this.raf = requestAnimationFrame(() => { this.raf = 0; this.render(); });
  }

  render() {
    const first = Math.max(0, Math.floor(this.root.scrollTop / LH) - OVERSCAN);
    const last = Math.min(this.shown.length, first + Math.ceil(this.root.clientHeight / LH) + OVERSCAN * 2);
    this.body.style.transform = `translateY(${first * LH}px)`;
    const frag = document.createDocumentFragment();
    const cap = Math.max(40, Math.floor((this.root.clientWidth / 2 - 60) / charWidth()));
    const cell = (lines, idx) => h('div.c', h('span.ln', idx >= 0 ? String(idx + 1) : ''), h('span.tx', idx >= 0 ? clip(lines[idx], cap) : ''));
    for (let i = first; i < last; i++) {
      const r = this.shown[i];
      if (r.kind === 'fold') {
        frag.append(h('div.diff-row', { style: { gridTemplateColumns: '1fr', color: 'var(--text-faint)' } },
          h('div.c', { style: { justifyContent: 'center', borderRight: '0', background: 'var(--bg)' } }, `${r.count} unchanged lines`)));
        continue;
      }
      frag.append(h('div', { class: `diff-row ${r.kind}` }, cell(this.a, r.a), cell(this.b, r.b)));
    }
    this.body.replaceChildren(frag);
  }

  jump(step) {
    if (!this.hunks.length) return { index: -1, count: 0 };
    this.hunk = (this.hunk + step + this.hunks.length) % this.hunks.length;
    this.root.scrollTop = Math.max(0, this.hunks[this.hunk] * LH - this.root.clientHeight / 3);
    this.render();
    return { index: this.hunk, count: this.hunks.length };
  }
}

const clip = (s, n) => (s.length > n ? `${s.slice(0, n - 1)}…` : s);
