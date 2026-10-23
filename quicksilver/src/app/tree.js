// Collapsible view of the Luast tree. Children are created when a node is first opened, so a 40,000 node
// tree costs only what is on screen.

import { h } from './dom.js';

export class TreeView {
  constructor() {
    this.root = h('div.tree', { role: 'tree', tabindex: '0' });
    this.root.addEventListener('click', (e) => {
      const tw = e.target.closest('.tw');
      if (!tw) return;
      const node = tw.parentElement;
      this.toggle(node);
    });
  }

  setTree(tree, depthOpen = 2) {
    this.root.replaceChildren();
    this.root.append(this.build(tree, 0));
    this.openTo(this.root.firstElementChild, depthOpen);
  }

  build(n, depth) {
    const has = !!(n.children && n.children.length);
    const label = h('div.node', { style: { '--d': depth }, role: 'treeitem', 'aria-expanded': has ? 'false' : null },
      h('span.tw', has ? '▸' : ' '),
      h('span.ty', n.type),
      n.detail ? h('span.dt', ` ${n.detail}`) : null,
      n.line ? h('span.ln', `:${n.line}`) : null);
    label._n = n;
    label._depth = depth;
    const wrap = h('div', label);
    wrap._label = label;
    return wrap;
  }

  toggle(label, force) {
    const n = label._n;
    if (!n.children || !n.children.length) return;
    const wrap = label.parentElement;
    const open = force ?? label.getAttribute('aria-expanded') !== 'true';
    label.setAttribute('aria-expanded', String(open));
    label.firstChild.textContent = open ? '▾' : '▸';
    if (open && !label._built) {
      for (const c of n.children) wrap.append(this.build(c, label._depth + 1));
      label._built = true;
    }
    for (let el = label.nextElementSibling; el; el = el.nextElementSibling) el.hidden = !open;
  }

  openTo(wrap, depth) {
    const label = wrap._label;
    if (depth <= 0) return;
    this.toggle(label, true);
    for (const child of [...wrap.children].slice(1)) this.openTo(child, depth - 1);
  }

  expandAll(maxDepth = 4) { this.openTo(this.root.firstElementChild, maxDepth); }
  collapseAll() {
    const top = this.root.firstElementChild;
    if (!top) return;
    for (const el of this.root.querySelectorAll('.node[aria-expanded="true"]')) this.toggle(el, false);
    this.toggle(top._label, true);
  }
}
