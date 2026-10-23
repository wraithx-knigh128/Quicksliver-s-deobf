// "Luast": the syntax tree as plain JSON, for the AST viewer and for export.
//
// Source positions are kept (line numbers), everything is structured-clone safe (no Sets, Maps or
// shared nodes) and the size is capped, because a 2 MB obfuscated script has hundreds of thousands of
// nodes and the viewer is not the place to find that out the hard way.

import { forEachChild } from '../core/walk.js';

const DETAIL = {
  Id: (n) => n.name,
  Name: (n) => n.name,
  Number: (n) => String(n.value),
  String: (n) => JSON.stringify(n.value).slice(0, 120),
  Binary: (n) => n.op,
  Unary: (n) => n.op,
  CompoundAssign: (n) => `${n.op}=`,
  MethodCall: (n) => n.name,
  Goto: (n) => n.label,
  Label: (n) => n.name,
  Function: (n) => (n.method ? `:${n.method}` : ''),
  Func: (n) => `(${n.params.map((p) => p.name).join(', ')}${n.vararg ? (n.params.length ? ', ...' : '...') : ''})`,
  Local: (n) => n.ids.map((i) => i.name).join(', '),
  LocalFunction: (n) => n.id.name,
  NumFor: (n) => n.id.name,
  GenFor: (n) => n.ids.map((i) => i.name).join(', '),
  Index: (n) => (n.key.type === 'String' ? n.key.value : ''),
  Table: (n) => `${n.fields.length} field${n.fields.length === 1 ? '' : 's'}`,
};

/**
 * @param {object} ast Chunk
 * @param {{maxNodes?: number}} [options]
 * @returns {{tree: object, nodes: number, truncated: boolean}}
 */
export function toLuast(ast, { maxNodes = 40000 } = {}) {
  let count = 0;
  let truncated = false;
  const convert = (n) => {
    if (count >= maxNodes) { truncated = true; return null; }
    count++;
    const node = { type: n.type };
    const d = DETAIL[n.type];
    if (d) node.detail = d(n);
    if (n.line) node.line = n.line;
    const kids = [];
    // identifiers declared by a statement are shown as children so scope can be read off the tree
    if (n.type === 'Local') n.ids.forEach((id) => kids.push(id));
    if (n.type === 'Func') n.params.forEach((id) => kids.push(id));
    forEachChild(n, (child) => kids.push(child));
    const out = [];
    for (const k of kids) {
      const c = convert(k);
      if (c) out.push(c);
    }
    if (out.length) node.children = out;
    return node;
  };
  const tree = convert(ast);
  return { tree, nodes: count, truncated };
}
