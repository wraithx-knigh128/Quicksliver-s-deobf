// Small DOM helpers. Text from scripts, detections and reports always goes through textContent, never
// innerHTML: the inputs to this tool are hostile by definition.

export const $ = (sel, root = document) => root.querySelector(sel);
export const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

/**
 * h('div#id.row', { title: 'x', onclick: fn, dataset: { id: 1 } }, 'text', childNode, ...)
 * The first argument is tag, #id and .classes (all optional). Falsy children are skipped; arrays are flattened.
 */
export function h(spec, attrs, ...children) {
  const [head, ...classes] = spec.split('.');
  const [tag, id] = head.split('#');
  const el = document.createElement(tag || 'div');
  if (id) el.id = id;
  if (classes.length) el.className = classes.join(' ');
  if (attrs && (typeof attrs !== 'object' || attrs instanceof Node || Array.isArray(attrs))) { children.unshift(attrs); attrs = null; }
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v === false || v == null) continue;
    if (k === 'class') el.className += (el.className ? ' ' : '') + v;
    else if (k === 'dataset') Object.assign(el.dataset, v);
    else if (k === 'style' && typeof v === 'object') {
      for (const [prop, val] of Object.entries(v)) { if (prop.startsWith('--')) el.style.setProperty(prop, String(val)); else el.style[prop] = val; }
    }
    else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2), v);
    else if (v === true) el.setAttribute(k, '');
    else el.setAttribute(k, String(v));
  }
  append(el, children);
  return el;
}

export function append(el, children) {
  for (const c of children) {
    if (c == null || c === false) continue;
    if (Array.isArray(c)) append(el, c);
    else el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el;
}

export function clear(el) { while (el.firstChild) el.removeChild(el.firstChild); return el; }
export function replace(el, ...children) { clear(el); append(el, children); return el; }

const SVG_NS = 'http://www.w3.org/2000/svg';
/** <svg><use href="#i-name"/></svg> referring to the sprite in index.html */
export function icon(name) {
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.setAttribute('aria-hidden', 'true');
  const use = document.createElementNS(SVG_NS, 'use');
  use.setAttribute('href', `#i-${name}`);
  svg.append(use);
  return svg;
}

export const fmtBytes = (n) => (n < 1024 ? `${n} B` : n < 1048576 ? `${(n / 1024).toFixed(1)} KiB` : `${(n / 1048576).toFixed(2)} MiB`);
export const fmtMs = (ms) => (ms < 1000 ? `${Math.round(ms)} ms` : `${(ms / 1000).toFixed(2)} s`);
export const pct = (x) => `${Math.round(x * 100)}%`;

let toastTimer = 0;
export function toast(message, ms = 3200) {
  let t = document.getElementById('toast');
  if (!t) { t = h('div.toast', { id: 'toast', role: 'status' }); document.body.append(t); }
  t.textContent = message;
  t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { t.hidden = true; }, ms);
}

/** Modal dialog. Resolves with the id of the button pressed ('cancel' on Escape or backdrop click). */
export function modal({ title, body, buttons = [{ id: 'ok', label: 'Close', primary: true }] }) {
  return new Promise((resolve) => {
    const previous = document.activeElement;
    const done = (id) => { back.remove(); document.removeEventListener('keydown', onKey, true); if (previous && previous.focus) previous.focus(); resolve(id); };
    const onKey = (e) => { if (e.key === 'Escape') { e.stopPropagation(); done('cancel'); } };
    const foot = h('div.mfoot', buttons.map((b) => h('button.btn' + (b.primary ? '.primary' : ''), { type: 'button', onclick: () => done(b.id) }, b.label)));
    const back = h('div.modal-back', { onmousedown: (e) => { if (e.target === back) done('cancel'); } },
      h('div.modal', { role: 'dialog', 'aria-modal': 'true', 'aria-label': title }, h('h2', title), h('div.mbody', body), foot));
    document.body.append(back);
    document.addEventListener('keydown', onKey, true);
    (foot.querySelector('.primary') || foot.lastElementChild).focus({ preventScroll: true });
  });
}
