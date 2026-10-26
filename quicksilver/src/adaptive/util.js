// Small helpers shared by the adaptive engine's observers and strategies.

import { walk } from '../core/walk.js';

export const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
export const num = (value) => ({ type: 'Number', value, raw: null });
export const str = (value) => ({ type: 'String', value, raw: null });
export const name = (n) => ({ type: 'Name', name: n });
export const isLit = (e) => !!e && (e.type === 'Number' || e.type === 'String' || e.type === 'True' || e.type === 'False' || e.type === 'Nil');

/** Source line of a node: its own, or that of the first descendant that has one. */
export function lineOf(node) {
  if (!node || typeof node !== 'object') return 0;
  if (node.line) return node.line;
  let line = 0;
  walk(node, (n) => { if (!line && n !== node && n.line) line = n.line; return line ? false : undefined; });
  return line;
}

/** Number of nodes below (and including) `node`. */
export function sizeOf(node) {
  let n = 0;
  walk(node, () => { n++; });
  return n;
}

/** Names mentioned as plain `Name` nodes anywhere below `node` (nested functions included). */
export function namesIn(node) {
  const out = new Set();
  walk(node, (n) => { if (n.type === 'Name') out.add(n.name); });
  return out;
}

/** Does `node` assign to the plain name `nm` (nested functions included: a closure may write it at any time)? */
export function writesName(node, nm) {
  let hit = false;
  walk(node, (n) => {
    if (hit) return false;
    switch (n.type) {
      case 'Assign': if (n.targets.some((t) => t.type === 'Name' && t.name === nm)) hit = true; break;
      case 'CompoundAssign': if (n.target.type === 'Name' && n.target.name === nm) hit = true; break;
      case 'Function': if (n.target.type === 'Name' && n.target.name === nm) hit = true; break;
      case 'NumFor': if (n.id.name === nm) hit = true; break;
      case 'GenFor': if (n.ids.some((i) => i.name === nm)) hit = true; break;
      case 'Local': if (n.ids.some((i) => i.name === nm)) hit = true; break;
      case 'LocalFunction': if (n.id.name === nm) hit = true; break;
      case 'Func': if (n.params.some((p) => p.name === nm)) hit = true; break;
      default: break;
    }
    return hit ? false : undefined;
  });
  return hit;
}

/** Does `node` read the plain name `nm` anywhere (reads only: the targets of plain assignments do not count)? */
export function readsName(node, nm) {
  let hit = false;
  const skip = new Set();   // Name nodes that are only written
  walk(node, (n) => {
    if (hit) return false;
    if (n.type === 'Assign') { for (const t of n.targets) if (t.type === 'Name') skip.add(t); }
    else if (n.type === 'Function' && n.target.type === 'Name') skip.add(n.target);
    else if (n.type === 'Name' && n.name === nm && !skip.has(n)) hit = true;
    return hit ? false : undefined;
  });
  return hit;
}

/** Does any statement below `node` (not inside a nested function) have type `type`? */
export function containsStmt(node, types, { intoFunctions = false } = {}) {
  let hit = false;
  walk(node, (n) => {
    if (hit) return false;
    if (n.type === 'Func' && !intoFunctions) return false;
    if (types.has(n.type)) hit = true;
    return hit ? false : undefined;
  });
  return hit;
}

/** Is `node` free of anything that could do something when evaluated (calls, function creation aside)? */
export function noCalls(node) {
  let ok = true;
  walk(node, (n) => { if (n.type === 'Call' || n.type === 'MethodCall') ok = false; return ok ? undefined : false; });
  return ok;
}

/** A readable one-line rendering of a node for evidence texts (cut off, never exact). */
export function glance(node, printer, max = 60) {
  let text;
  try { text = printer(node); } catch { text = node.type; }
  text = text.replace(/\s+/g, ' ').trim();
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}
