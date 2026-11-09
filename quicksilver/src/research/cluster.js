// Grouping unlabelled scripts by how they are built, for systems nobody has described to the engine.
//
// Input: scripts with no label. Output: groups of scripts that look alike in structure, and for each group what its members share. A group says
// "these were probably made the same way"; it never says WHICH tool made them, and the report says so. Nothing is executed.
//
// Similarity of two scripts is the mean of
//   * Jaccard similarity of their structural features (features.js): yes/no facts such as "program functions live in a table";
//   * cosine similarity of their token profiles: the share of each kind of token (names, numbers, strings, punctuation) and of a few shape ratios.
// Groups are formed by average-linkage agglomeration and stop at `threshold`. A group's `shared` features are the ones every member has.
// What this cannot see is what the vocabulary cannot see: two different tools with the same surface fall into one group, and one tool with
// very different settings may fall into several. study.js measures a signature against held-out programs; this only proposes candidates for it.

import { tokenize } from '../core/lexer.js';
import { extractFeatures, FEATURES } from './features.js';

const KINDS = ['name', 'keyword', 'number', 'string', 'op', 'punct'];

function profile(source) {
  const f = extractFeatures(source);
  let toks = [];
  try { toks = tokenize(source).tokens; } catch { /* a script that does not tokenize has features 'syntax:invalid' only */ }
  const total = Math.max(1, toks.length);
  const count = Object.fromEntries(KINDS.map((k) => [k, 0]));
  for (const t of toks) { const k = KINDS.includes(t.t) ? t.t : /^[a-z]+$/i.test(t.v || '') ? 'keyword' : 'op'; count[k]++; }
  const lines = source.split('\n');
  const vec = [
    ...KINDS.map((k) => count[k] / total),
    Math.min(1, (f.metrics.longestLine || 0) / 2000),
    Math.min(1, (f.metrics.comments || 0) / total),
    Math.min(1, (f.metrics.numberDensity || 0)),
    Math.min(1, lines.length / Math.max(1, source.length / 40)),
    Math.min(1, (f.metrics.largestTable || 0) / 256),
  ];
  return { features: f.features, vec };
}

const jaccard = (a, b) => { if (!a.size && !b.size) return 1; let i = 0; for (const x of a) if (b.has(x)) i++; return i / (a.size + b.size - i); };
const cosine = (a, b) => { let d = 0, na = 0, nb = 0; for (let i = 0; i < a.length; i++) { d += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]; } return na && nb ? d / Math.sqrt(na * nb) : 0; };

export function similarity(p, q) { return 0.5 * jaccard(p.features, q.features) + 0.5 * cosine(p.vec, q.vec); }

/**
 * @param {Array<{id: string, source: string}>} samples
 * @param {{threshold?: number}} [opts]  minimum average similarity for two groups to merge (default 0.8, chosen on the labelled test set in tests/research-system.test.mjs)
 * @returns {{groups: Array<{members: string[], shared: string[], absent: string[], cohesion: number}>, singletons: string[], notes: string[]}}
 */
export function cluster(samples, { threshold = 0.8 } = {}) {
  const ps = samples.map((s) => ({ id: s.id, ...profile(s.source) }));
  const sim = ps.map((p) => ps.map((q) => similarity(p, q)));
  let groups = ps.map((_, i) => [i]);
  const avg = (a, b) => { let s = 0; for (const i of a) for (const j of b) s += sim[i][j]; return s / (a.length * b.length); };
  for (;;) {
    let best = null;
    for (let a = 0; a < groups.length; a++) for (let b = a + 1; b < groups.length; b++) { const v = avg(groups[a], groups[b]); if (v >= threshold && (!best || v > best.v)) best = { a, b, v }; }
    if (!best) break;
    groups = groups.filter((_, i) => i !== best.a && i !== best.b).concat([[...groups[best.a], ...groups[best.b]]]);
  }
  const multi = groups.filter((g) => g.length > 1);
  const out = multi.map((g) => {
    const sets = g.map((i) => ps[i].features);
    let within = 0, pairs = 0;
    for (let x = 0; x < g.length; x++) for (let y = x + 1; y < g.length; y++) { within += sim[g[x]][g[y]]; pairs++; }
    return {
      members: g.map((i) => ps[i].id).sort(),
      shared: FEATURES.filter((f) => sets.every((s) => s.has(f))),
      absent: FEATURES.filter((f) => sets.every((s) => !s.has(f))).length,
      cohesion: Math.round((within / pairs) * 1000) / 1000,
    };
  }).sort((a, b) => b.members.length - a.members.length);
  const notes = [
    'A group means its members are built alike. It does not say which tool made them, or that one tool did: different tools with the same surface fall into one group, and one tool with different settings may fall into several.',
    ...(samples.length < 6 ? ['Fewer than 6 samples: groups at this size are suggestions.'] : []),
  ];
  return { groups: out, singletons: groups.filter((g) => g.length === 1).map((g) => ps[g[0]].id), notes };
}
