// Syntax colouring for the input editor.
//
// The editor stays a plain <textarea> (so typing, selection, undo, IME and paste behave exactly as the browser does
// them). Its text is made transparent and this layer draws the coloured copy underneath it. Only the rows in view
// exist, so a 100,000 line script costs the same as a ten line one. A very long line (the usual shape of a minified
// obfuscated script) is drawn only for the columns on screen, behind a spacer that keeps them where the text is.

import { h } from './dom.js';
import { lineStates, fullNodes, windowNodes } from './highlight.js';
import { LH, charWidth } from './viewer.js';

const OVERSCAN = 40;      // rows drawn above and below the viewport
const SLACK = 12;         // rows of margin before the window is rebuilt
const LONG = 2000;        // a line longer than this is drawn by columns
const COLS = 260;         // columns drawn left and right of the viewport on a long line
const COL_SLACK = 120;
const MAX_CHARS = 8_000_000;

export class HighlightLayer {
  /** @param {HTMLTextAreaElement} textarea */
  constructor(textarea) {
    this.ta = textarea;
    this.rows = h('div.hl-rows');
    this.cur = h('div.hl-cur', { hidden: true });
    this.root = h('div.hl', { 'aria-hidden': 'true' }, this.cur, this.rows);
    this.enabled = true;
    this.dirty = true;
    this.lines = [''];
    this.states = null;
    this.first = 0;
    this.last = 0;
    this.colLo = 0;
    this.colHi = 0;
    this.hasLong = false;
    this.curLine = 0;
    this.raf = 0;
    textarea.addEventListener('scroll', () => this.scrolled(), { passive: true });
    new ResizeObserver(() => this.schedule()).observe(textarea);
  }

  /** The text changed. */
  invalidate() { this.dirty = true; this.schedule(); }

  /** Turn the colouring off (wrapped lines no longer map one to one onto rows) or on. */
  setEnabled(on) {
    this.enabled = on;
    this.root.hidden = !on;
    this.ta.classList.toggle('hl-off', !on);
    if (on) { this.dirty = true; this.schedule(); }
  }

  /** 1-based line of the caret; 0 hides the marker. */
  setCaretLine(line) {
    this.curLine = line;
    this.place();
  }

  schedule() {
    if (this.raf || !this.enabled) return;
    this.raf = requestAnimationFrame(() => { this.raf = 0; this.render(); });
  }

  scrolled() {
    if (!this.enabled) return;
    this.place();
    const ta = this.ta;
    const top = Math.floor(ta.scrollTop / LH);
    const bottom = top + Math.ceil(ta.clientHeight / LH);
    const rowsOk = (this.first === 0 || top >= this.first + SLACK) && (this.last >= this.lines.length || bottom <= this.last - SLACK);
    let colsOk = true;
    if (this.hasLong) {
      const cw = charWidth();
      const lo = Math.floor(ta.scrollLeft / cw);
      const hi = Math.ceil((ta.scrollLeft + ta.clientWidth) / cw);
      colsOk = (this.colLo === 0 || lo >= this.colLo + COL_SLACK) && hi <= this.colHi - COL_SLACK;
    }
    if (!rowsOk || !colsOk) this.schedule();
  }

  place() {
    const ta = this.ta;
    this.rows.style.transform = `translate3d(${-ta.scrollLeft}px, ${this.first * LH - ta.scrollTop}px, 0)`;
    if (this.curLine > 0) {
      this.cur.hidden = false;
      this.cur.style.transform = `translate3d(0, ${(this.curLine - 1) * LH - ta.scrollTop}px, 0)`;
    } else this.cur.hidden = true;
  }

  render() {
    if (!this.enabled) return;
    const ta = this.ta;
    if (this.dirty) {
      const text = ta.value;
      if (text.length > MAX_CHARS) { this.setEnabled(false); return; }
      this.lines = text.split('\n');
      this.states = lineStates(this.lines);
      this.dirty = false;
    }
    const cw = charWidth();
    const row = Math.floor(ta.scrollTop / LH);
    const first = Math.max(0, row - OVERSCAN);
    const last = Math.min(this.lines.length, row + Math.ceil(ta.clientHeight / LH) + OVERSCAN);
    const lo = Math.max(0, Math.floor(ta.scrollLeft / cw) - COLS);
    const hi = Math.ceil((ta.scrollLeft + ta.clientWidth) / cw) + COLS;
    this.first = first; this.last = last; this.colLo = lo; this.colHi = hi;
    this.hasLong = false;
    const frag = document.createDocumentFragment();
    for (let i = first; i < last; i++) {
      const line = this.lines[i];
      const r = h('div.hl-row');
      if (line.length > LONG) {
        this.hasLong = true;
        r.append(windowNodes(line, this.states.states[i], this.states.kind[i], lo, hi, cw));
      } else r.append(fullNodes(line, this.states.states[i], this.states.kind[i]));
      frag.append(r);
    }
    this.rows.replaceChildren(frag);
    this.place();
  }
}
