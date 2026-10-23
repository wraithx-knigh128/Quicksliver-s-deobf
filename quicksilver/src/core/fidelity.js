// How close is recovered code to a reference source?
//
// Both programs are parsed and flattened into a stream of "semantic tokens": node kinds, operators and
// literal values. Local variables are replaced by their order of declaration, so renaming does not
// matter, while global names (print, string, game) are kept because they carry meaning. The score is
// the Dice coefficient of the longest common subsequence of the two streams: 1.0 means the recovered
// program has the same structure, operators and constants as the reference.
//
// This is used for testing and for the compatibility dashboard; it is not a behavioural proof.

import { parse } from './parser.js';
import { analyze } from './scope.js';

/** Flatten source into semantic tokens. */
export function semanticTokens(source) {
  const ast = parse(source);
  const info = analyze(ast);
  const order = new Map();
  const local = (node) => {
    const v = info.varOf.get(node);
    if (!v || v.isGlobal) return 'g:' + node.name;
    if (!order.has(v)) order.set(v, order.size);
    return 'L' + order.get(v);
  };
  const out = [];
  const visit = (n) => {
    if (n === null || n === undefined) return;
    if (Array.isArray(n)) { n.forEach(visit); return; }
    switch (n.type) {
      case 'Id': out.push(local(n)); return;
      case 'Name': out.push(local(n)); return;
      case 'Number': out.push('#' + n.value); return;
      case 'String': out.push('"' + n.value); return;
      case 'Paren': visit(n.expr); return;            // redundant parentheses carry no meaning
      case 'Binary': out.push(n.type + n.op); visit(n.left); visit(n.right); return;
      case 'Unary': out.push(n.type + n.op); visit(n.arg); return;
      case 'Index':
        out.push('Index');
        visit(n.obj);
        visit(n.key);
        return;
      case 'Table':
        out.push('Table');
        for (const f of n.fields) {
          if (f.kind === 'named') { out.push('"' + f.key); } else if (f.kind === 'keyed') visit(f.key);
          visit(f.value);
        }
        return;
      case 'Chunk': visit(n.body); return;
      default: break;
    }
    out.push(n.type);
    for (const key of Object.keys(n)) {
      if (key === 'type' || key === 'features' || key === 'comments' || key === 'trailing' || key === 'endComments' || key === 'line' || key === 'pos' || key === 'endPos' || key === 'endLine' || key === 'blankBefore' || key === 'sugar' || key === 'dot' || key === 'raw' || key === 'long' || key === 'quote') continue;
      const v = n[key];
      if (v && typeof v === 'object') visit(v);
      else if (typeof v === 'string' && (key === 'op' || key === 'label' || key === 'method')) out.push(key + ':' + v);
    }
  };
  visit(ast);
  return out;
}

function lcsLength(a, b) {
  if (a.length < b.length) [a, b] = [b, a];
  let prev = new Uint32Array(b.length + 1);
  let cur = new Uint32Array(b.length + 1);
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      cur[j] = a[i - 1] === b[j - 1] ? prev[j - 1] + 1 : Math.max(prev[j], cur[j - 1]);
    }
    [prev, cur] = [cur, prev];
  }
  return prev[b.length];
}

/**
 * @returns {{score:number, referenceTokens:number, recoveredTokens:number}}
 */
export function fidelity(reference, recovered) {
  const a = semanticTokens(reference);
  const b = semanticTokens(recovered);
  if (a.length === 0 && b.length === 0) return { score: 1, referenceTokens: 0, recoveredTokens: 0 };
  // Very large inputs: compare a bounded window rather than spending quadratic time.
  const cap = 6000;
  const aa = a.slice(0, cap);
  const bb = b.slice(0, cap);
  const lcs = lcsLength(aa, bb);
  return { score: (2 * lcs) / (aa.length + bb.length), referenceTokens: a.length, recoveredTokens: b.length };
}
