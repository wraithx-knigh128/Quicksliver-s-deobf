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
  const inHeader = (s, name) => headerNodes(s).some((e) => mentionsName(e, name));

  /** Is the first statement of the block that mentions `name` a plain `name = expr` that does not read it? */
  const definesFirst = (stmts, name) => {
    const s = stmts.find((x) => mentionsName(x, name));
    if (!s || s.type !== 'Assign' || s.targets.length !== 1 || s.values.length !== 1) return false;
    const t = s.targets[0];
    return t.type === 'Name' && t.name === name && !mentionsName(s.values[0], name);
  };

  /**
   * The innermost block that holds every mention of the name, found by going down while the name appears in exactly one
   * statement and, inside it, in exactly one block. Crossing a loop is only allowed when the name is written before it is
   * read each time the landing block runs; otherwise the declaration goes in front of the outermost loop crossed.
   */
  function landing(stmts, name) {
    let block = stmts;
    let crossed = null;
    for (;;) {
      const at = [];
      block.forEach((x, i) => { if (mentionsName(x, name)) at.push(i); });
      if (at.length !== 1) break;
      const s = block[at[0]];
      if (inHeader(s, name)) break;
      const inside = childBlocks(s).filter((b) => b.some((x) => mentionsName(x, name)));
      if (inside.length !== 1) break;
      if (isLoop(s) && !crossed) crossed = { block, index: at[0] };
      block = inside[0];
    }
    if (crossed && !definesFirst(block, name)) block = crossed.block;
    return block;
  }

  const byBlock = new Map();                         // block -> names declared in it
  for (const name of names) {
    if (!body.some((x) => mentionsName(x, name))) continue;
    const block = landing(body, name);
    if (!byBlock.has(block)) byBlock.set(block, []);
    byBlock.get(block).push(name);
  }
  for (const [stmts, list] of byBlock) {
    const first = new Map();
    list.forEach((name) => first.set(name, stmts.findIndex((x) => mentionsName(x, name))));
    const order = [...new Set(first.values())].sort((a, b) => b - a);
    for (const i of order) {
      const group = list.filter((name) => first.get(name) === i);
      const st = stmts[i];
      const rest = [];
      for (const n of group) {
        if (st.type === 'Assign' && st.targets.length === 1 && st.values.length === 1 && st.targets[0].type === 'Name' && st.targets[0].name === n && !mentionsName(st.values[0], n)) {
          stmts[i] = { type: 'Local', ids: [{ type: 'Id', name: n }], values: st.values, computed: st.computed, line: st.line, comments: st.comments, blankBefore: st.blankBefore };
        } else rest.push(n);
      }
      if (rest.length) stmts.splice(i, 0, { type: 'Local', ids: rest.map((name) => ({ type: 'Id', name })), values: [] });
    }
  }
}
