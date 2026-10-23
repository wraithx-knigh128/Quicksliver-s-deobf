// Read-only code viewer with a virtual row list: only the rows in view exist in the DOM, so a 100,000 line
// recovered script scrolls as smoothly as a ten line one. Syntax colouring is applied per visible row.

import { h } from './dom.js';
import { lineStates, lineNodes } from './highlight.js';

export const LH = 18;
const OVERSCAN = 20;

let charWidthCache = 0;
export function charWidth() {
  if (charWidthCache) return charWidthCache;
  const probe = h('span.mono', { style: { position: 'absolute', visibility: 'hidden', font: '12.5px/18px var(--mono)', whiteSpace: 'pre' } }, 'x'.repeat(200));
  document.body.append(probe);
  charWidthCache = probe.getBoundingClientRect().width / 200 || 7.5;
  probe.remove();
  return charWidthCache;
}

export class Viewer {
  constructor() {
    this.lines = [];
    this.kind = null;
    this.matches = [];
    this.current = -1;
    this.query = '';
    this.spacer = h('div.spacer');
    this.rows = h('div.rows');
    this.root = h('div.viewer', { tabindex: '0', role: 'document' }, this.spacer, this.rows);
    this.root.addEventListener('scroll', () => this.schedule());
    this.raf = 0;
    new ResizeObserver(() => this.schedule()).observe(this.root);
  }

  setText(text, { highlight = true } = {}) {
    this.text = text;
    this.lines = text.split('\n');
    if (this.lines.length > 1 && this.lines[this.lines.length - 1] === '') this.lines.pop();
    this.highlight = highlight;
    this.states = highlight ? lineStates(this.lines) : null;
    let longest = 0;
    for (const l of this.lines) if (l.length > longest) longest = l.length;
    this.spacer.style.height = `${this.lines.length * LH}px`;
    this.spacer.style.width = `${Math.min(longest, 3040) * charWidth() + 90}px`;
    this.matches = [];
    this.current = -1;
    if (this.query) this.find(this.query, 0, true);
    this.root.scrollTop = 0;
    this.root.scrollLeft = 0;
    this.render();
  }

  schedule() {
    if (this.raf) return;
    this.raf = requestAnimationFrame(() => { this.raf = 0; this.render(); });
  }

  render() {
    const total = this.lines.length;
    const first = Math.max(0, Math.floor(this.root.scrollTop / LH) - OVERSCAN);
    const visible = Math.ceil(this.root.clientHeight / LH) + OVERSCAN * 2;
    const last = Math.min(total, first + visible);
    this.rows.style.transform = `translateY(${first * LH}px)`;
    const hits = this.matchSet || new Set();
    const frag = document.createDocumentFragment();
    for (let i = first; i < last; i++) {
      const tx = h('span.tx');
      if (this.highlight) tx.append(lineNodes(this.lines[i], this.states.states[i], this.states.kind[i]));
      else tx.textContent = this.lines[i].length > 3000 ? `${this.lines[i].slice(0, 3000)} …` : this.lines[i];
      const cls = 'row' + (this.current >= 0 && this.matches[this.current] === i ? ' cur' : hits.has(i) ? ' hit' : '');
      frag.append(h('div', { class: cls }, h('span.ln', String(i + 1)), tx));
    }
    this.rows.replaceChildren(frag);
  }

  scrollToLine(line, { center = true } = {}) {
    const top = line * LH;
    const view = this.root.clientHeight;
    this.root.scrollTop = center ? Math.max(0, top - view / 2) : top;
    this.render();
  }

  /** @returns {{count: number, index: number}} */
  find(query, step = 1, keepPosition = false) {
    const q = query.toLowerCase();
    if (q !== this.query || !this.matches.length) {
      this.query = q;
      this.matches = [];
      if (q) for (let i = 0; i < this.lines.length; i++) if (this.lines[i].toLowerCase().includes(q)) this.matches.push(i);
      this.matchSet = new Set(this.matches);
      this.current = -1;
      if (this.matches.length) {
        const here = Math.floor(this.root.scrollTop / LH);
        let k = this.matches.findIndex((m) => m >= here);
        if (k < 0) k = 0;
        this.current = keepPosition ? -1 : k;
      }
    } else if (this.matches.length) {
      this.current = (this.current + step + this.matches.length) % this.matches.length;
    }
    if (this.current >= 0) this.scrollToLine(this.matches[this.current]);
    else this.render();
    return { count: this.matches.length, index: this.current };
  }

  get lineCount() { return this.lines.length; }
}
