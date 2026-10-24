// Where does `local x` go in a function whose variables came out of a register machine?
//
// The structurer hands back statements that assign names nobody declared. Declaring all of them at the top of the function
// is correct but hides the structure, and a function can only have 200 locals. The rule used here is the one a person
// follows: declare a variable where it first appears, and if everything that touches it sits inside one branch or loop body,
// declare it in there. A loop body only gets it when each pass writes it before reading it (`x = ...` as the first thing
// that mentions it); otherwise the value has to survive from one pass to the next and the declaration stays outside the loop.

import { walk } from '../core/walk.js';

const childBlocks = (s) => {
  switch (s.type) {
    case 'If': return [...s.clauses.map((c) => c.body), ...(s.orelse ? [s.orelse] : [])];
    case 'While': case 'Repeat': case 'NumFor': case 'GenFor': case 'Do': return [s.body];
    default: return [];
  }
};

const isLoop = (s) => s.type === 'While' || s.type === 'Repeat' || s.type === 'NumFor' || s.type === 'GenFor';

/** The expressions of a compound statement that are not part of one of its blocks. */
function headerNodes(s) {
  switch (s.type) {
    case 'If': return s.clauses.map((c) => c.cond);
    case 'While': return [s.cond];
    case 'Repeat': return [s.cond];                 // `until` can see the body's locals, so it counts with the body
    case 'NumFor': return [s.start, s.stop, s.step].filter(Boolean);
    case 'GenFor': return s.exprs;
    default: return [];
  }
}

export function placeDeclarations(body, names) {
  const wanted = new Set(names);
  const cache = new WeakMap();
  const mentions = (node) => {
    if (!node || typeof node !== 'object') return new Set();
    let hit = cache.get(node);
    if (hit) return hit;
    hit = new Set();
    walk(node, (n) => { if (n.type === 'Name' && wanted.has(n.name)) hit.add(n.name); });
    cache.set(node, hit);
    return hit;
  };
  const mentionsName = (node, name) => mentions(node).has(name);
  const inHeader = (s, name) => headerNodes(s).some((e) => mentionsName(e, name)) || (s.type === 'Repeat' && mentionsName(s.cond, name));

  /** Does the block write `name` before it reads it, in the first statement that mentions it? */
  const definesFirst = (stmts, name) => {
    const s = stmts.find((x) => mentionsName(x, name));
    if (!s || s.type !== 'Assign' || s.targets.length !== 1 || s.values.length !== 1) return false;
    const t = s.targets[0];
    return t.type === 'Name' && t.name === name && !mentionsName(s.values[0], name);
  };

  function place(stmts, pending) {
    const first = new Map();
    const count = new Map();
    stmts.forEach((s, i) => {
      for (const n of mentions(s)) if (pending.has(n)) { if (!first.has(n)) first.set(n, i); count.set(n, (count.get(n) || 0) + 1); }
    });
    const here = [];                                 // [index, name]
    const down = new Map();                          // statement -> Map(block -> Set(name))
    for (const n of pending) {
      if (!first.has(n)) continue;
      const i = first.get(n);
      const s = stmts[i];
      if (count.get(n) === 1 && !inHeader(s, n)) {
        const inside = childBlocks(s).filter((b) => b.some((x) => mentionsName(x, n)));
        if (inside.length === 1 && (!isLoop(s) || definesFirst(inside[0], n))) {
          if (!down.has(s)) down.set(s, new Map());
          const m = down.get(s);
          if (!m.has(inside[0])) m.set(inside[0], new Set());
          m.get(inside[0]).add(n);
          continue;
        }
      }
      here.push([i, n]);
    }
    for (const [s, blocks] of down) for (const [b, set] of blocks) place(b, set);

    // declare, last index first so earlier ones stay valid; names at the same statement keep one `local` line
    here.sort((a, b) => b[0] - a[0]);
    for (let k = 0; k < here.length;) {
      const i = here[k][0];
      const group = [];
      while (k < here.length && here[k][0] === i) group.push(here[k++][1]);
      const s = stmts[i];
      const rest = [];
      for (const n of group) {
        if (s.type === 'Assign' && s.targets.length === 1 && s.values.length === 1 && s.targets[0].type === 'Name' && s.targets[0].name === n && !mentionsName(s.values[0], n)) {
          stmts[i] = { type: 'Local', ids: [{ type: 'Id', name: n }], values: s.values, computed: s.computed, line: s.line, comments: s.comments, blankBefore: s.blankBefore };
          cache.delete(stmts[i]);
        } else rest.push(n);
      }
      if (rest.length) stmts.splice(i, 0, { type: 'Local', ids: rest.map((name) => ({ type: 'Id', name })), values: [] });
    }
  }

  place(body, new Set(names));
}
