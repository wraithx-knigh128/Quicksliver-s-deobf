// Give every value its own variable again.
//
// A compiler keeps unrelated values in one register when their lifetimes do not overlap, and bytecode without debug information says
// nothing about where one source variable ended and the next began. A decompiled function then reads
//
//     local a                         local a = "x" .. "y"
//     a = "x" .. "y"                  print(a)
//     print(a)              ==>       local a1 = function() ... end
//     a = function() ... end          a1()
//     a()
//
// which is correct but hides everything the later passes look for (a constant is no longer a constant once its variable is assigned
// twice). This pass splits such a variable where that is provably the same program:
//
//   * a split starts at a plain assignment `v = e` that is a statement of a block, and covers every use of v from there to the next such
//     assignment in the same block (whose right-hand side still reads the old value). Everything in between, nested blocks included, sees
//     only this assignment's value or later assignments inside the range, so renaming all of it changes nothing;
//   * the last range of a block runs to the end of the block. In a function's own top-level block nothing comes after it; in a nested
//     block the value may be read after the block or on the next turn of a loop, so the last range of a nested block is left alone;
//   * a closure captures the variable, not the value: once any closure that mentions v has been created, later assignments are visible
//     to it, so no split starts at or after the first statement that contains such a closure;
//   * functions that use goto are left alone (the order of statements is not the order of execution there).
//
// Nothing is evaluated. The first range keeps the variable's declaration; a declaration that ends up unused is removed by the ordinary
// clean-up.

import { walk, forEachChild } from '../core/walk.js';
import { analyze } from '../core/scope.js';

function blocksOf(node) {
  switch (node.type) {
    case 'Do': case 'While': case 'Repeat': case 'NumFor': case 'GenFor': return [node.body];
    case 'If': return [...node.clauses.map((c) => c.body), ...(node.orelse ? [node.orelse] : [])];
    default: return [];
  }
}

export function splitWebs(chunk) {
  const info = analyze(chunk);
  const taken = new Set();
  walk(chunk, (n) => { if (n.type === 'Name' || n.type === 'Id') taken.add(n.name); });
  const fresh = (base) => { let i = 1; let name; do { name = `${base}_${i++}`; } while (taken.has(name)); taken.add(name); return name; };
  let changed = 0;

  const processFunction = (fn) => {
    // text order of every node of this function, and the first place each variable is mentioned by a nested closure
    const order = new WeakMap();
    const lastOf = new WeakMap();                  // statement -> order of its last node
    let counter = 0;
    let hasGoto = false;
    const firstCapture = new Map();                // Var -> order
    const number = (n, depth) => {
      if (!n || typeof n !== 'object') return;
      order.set(n, ++counter);
      if (n.type === 'Goto' || n.type === 'Label') hasGoto = true;
      if (depth > 0 && n.type === 'Name') { const v = info.varOf.get(n); if (v && !firstCapture.has(v)) firstCapture.set(v, counter); }
      forEachChild(n, (c) => number(c, n.type === 'Func' && n !== fn ? depth + 1 : depth));
      lastOf.set(n, counter);
    };
    for (const s of fn.body) number(s, 0);
    if (hasGoto) return;
    const own = new Set();                         // variables this function declares itself (not those of nested functions)
    const collectOwn = (n) => {
      if (!n || typeof n !== 'object') return;
      if (n.type === 'Func' && n !== fn) return;
      if (n.type === 'Local') for (const id of n.ids) { const v = info.varOf.get(id); if (v) own.add(v); }
      forEachChild(n, collectOwn);
    };
    fn.body.forEach(collectOwn);
    if (fn.params) for (const p of fn.params) { const v = info.varOf.get(p); if (v) own.add(v); }

    const processBlock = (stmts, top) => {
      // plain top-level assignments of this block, per variable
      const defs = new Map();
      stmts.forEach((s, i) => {
        if (s.type !== 'Assign' || s.targets.length !== 1 || s.values.length !== 1 || s.targets[0].type !== 'Name') return;
        const v = info.varOf.get(s.targets[0]);
        if (!v || v.isGlobal || !own.has(v)) return;
        if (!defs.has(v)) defs.set(v, []);
        defs.get(v).push(i);
      });
      for (const [v, at] of defs) {
        const cap = firstCapture.has(v) ? firstCapture.get(v) : Infinity;
        const starts = at.filter((i) => lastOf.get(stmts[i]) < cap);
        for (let j = 0; j < starts.length; j++) {
          const k = starts[j];
          const next = at.find((i) => i > k);                      // the assignment that ends this range, if any
          const closed = next !== undefined && starts.includes(next);
          if (!closed && !(top && next === undefined) && !(top && !starts.includes(next) && j === starts.length - 1)) continue;
          const end = closed ? next : stmts.length;
          // nothing to gain from a range that is the whole life of the variable and already starts at its only assignment
          const name = fresh(v.name);
          const rename = (node) => walk(node, (n) => { if ((n.type === 'Name') && info.varOf.get(n) === v) n.name = name; });
          for (let i = k + 1; i < end; i++) rename(stmts[i]);
          if (closed) rename(stmts[next].values);
          const s = stmts[k];
          stmts[k] = { type: 'Local', ids: [{ type: 'Id', name }], values: s.values, comments: s.comments, line: s.line, endLine: s.endLine };
          changed++;
        }
      }
      for (const s of stmts) {
        const visit = (n) => {
          if (!n || typeof n !== 'object' || n.type === 'Func') return;
          for (const b of blocksOf(n)) processBlock(b, false);
          forEachChild(n, (c) => { if (!blocksOf(n).some((b) => b.includes(c))) visit(c); });
        };
        visit(s);
      }
    };
    processBlock(fn.body, true);
  };

  processFunction(chunk);
  walk(chunk, (n) => { if (n.type === 'Func') processFunction(n); });
  return { changed };
}
