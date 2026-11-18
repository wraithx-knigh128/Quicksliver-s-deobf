// Learned analysis rules: structural fingerprints of functions whose role was CONFIRMED by a test on an authorised sample.
//
// A fingerprint abstracts away what changes between builds of the same generator — local names, numeric and string constants — and keeps
// the shape: node types, operators, the standard functions called, the loop structure. Two uses:
//
//   exact match   the same shape was confirmed before: the hypothesis is raised (and still tested on this script);
//   near match    a similar shape (Jaccard similarity of 4-gram shingles of the shape sequence ≥ 0.85): reported as "resembles", never merged
//                 with the rule — two generators can share a decoder idiom and still be different formats.
//
// Rules are built by tools/custom/learn.mjs from samples the project is authorised to use, and stored in data/research/learned-rules.json
// with their provenance (sample hashes, test results). A rule that was ever refuted is not stored.

import { walk } from '../core/walk.js';

const calleeName = (fn) => {
  let x = fn;
  while (x && x.type === 'Paren') x = x.expr;
  if (!x) return '';
  if (x.type === 'Name') return x.name;
  if (x.type === 'Index' && x.key && x.key.type === 'String') { const o = calleeName(x.obj); return o ? `${o}.${x.key.value}` : ''; }
  return '';
};
const STD = /^(string|table|math|bit32|bit|os|debug|coroutine)\.\w+$|^(pairs|ipairs|select|tostring|tonumber|type|unpack|setmetatable|getmetatable|rawget|rawset|getfenv|setfenv|loadstring|load|pcall|error)$/;

/** The shape sequence of a function and a hash of it. */
export function fingerprint(func) {
  const seq = [];
  walk(func.body, (n) => {
    switch (n.type) {
      case 'Binary': seq.push(`B${n.op}`); break;
      case 'Unary': seq.push(`U${n.op}`); break;
      case 'Call': { const c = calleeName(n.fn); seq.push(STD.test(c) ? `C:${c}` : 'C'); break; }
      case 'MethodCall': seq.push(STD.test(`string.${n.name}`) ? `M:${n.name}` : 'M'); break;
      case 'Func': seq.push('F'); break;
      case 'Number': case 'String': case 'Name': case 'Id': break;   // constants and names vary between builds
      default: seq.push(n.type);
    }
    return undefined;
  });
  return { hash: hashSeq(seq), seq, size: seq.length };
}

function hashSeq(seq) {
  // FNV-1a over the joined sequence: stable, dependency-free; collisions are guarded by the stored size
  let h = 0x811c9dc5;
  const s = seq.join(' ');
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; }
  return `${h.toString(16).padStart(8, '0')}-${seq.length}`;
}

export function shingles(seq, k = 4) {
  const s = new Set();
  for (let i = 0; i + k <= seq.length; i++) s.add(seq.slice(i, i + k).join(' '));
  return s;
}

export function similarity(a, b) {
  const A = shingles(a);
  const B = shingles(b);
  if (!A.size || !B.size) return 0;
  let inter = 0;
  for (const x of A) if (B.has(x)) inter++;
  return inter / (A.size + B.size - inter);
}

/** @returns {{ exact?: object, near?: object } | null} */
export function matchRules(fp, rules) {
  if (!rules || !Array.isArray(rules.rules)) return null;
  const exact = rules.rules.find((r) => r.fingerprint === fp.hash);
  if (exact) return { exact: { role: exact.role, confirmed: exact.confirmations, firstSeen: exact.firstSeen } };
  let best = null;
  for (const r of rules.rules) {
    if (!r.seq || Math.abs(r.seq.length - fp.seq.length) > fp.seq.length * 0.3) continue;
    const s = similarity(fp.seq, r.seq);
    if (s >= 0.85 && (!best || s > best.similarity)) best = { role: r.role, similarity: +s.toFixed(2) };
  }
  return best ? { near: best } : null;
}
