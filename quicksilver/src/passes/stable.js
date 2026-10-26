// Copies of values that never change.
//
// Rebuilding a register machine leaves code that reaches things through copies made at the top of each function:
//
//     local value4 = tbl4            -- never assigned again
//     local value5 = decrypt         -- never assigned again
//     local str = "\90\133..."       -- never assigned again
//     ... value4[value5(str, 3853553731330)] ...
//
// A local that is declared with a value and never assigned afterwards holds that value for its whole life, whether or not a nested function
// reads it. When the value is another such local, or a literal, the copy says nothing the original does not, and every read of it can be a read
// of the original (or the literal). That is the whole transformation; its use is that what looks at the code afterwards (the decoder finder
// first of all) sees the call `decrypt("\90\133...", 3853553731330)` where it saw a call of an unknown local.
//
//   * a copy of a name is followed only when the source is a local, parameter or loop variable that is never assigned either, so it cannot
//     have changed between the copy and the read;
//   * a string that is data (it does not read as text) is put in place of its reads when it is short, or read once (a long one read twice stays a
//     variable); readable constants keep their names;
//   * after the substitution the scope analysis is run again and a read that would now be captured by a different variable of the same
//     name is put back as it was;
//   * a declaration whose reads are all gone is removed with its value (a name or a literal has no effect to keep).

import { analyze } from '../core/scope.js';
import { walk } from '../core/walk.js';
import { makeConst } from './fold.js';
import { readsAsText } from '../sandbox/numeric.js';

const SHORT_LITERAL = 48;

const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const isLiteral = (e) => e && (e.type === 'String' || e.type === 'Number' || e.type === 'True' || e.type === 'False' || e.type === 'Nil');

const lists = (chunk) => {
  const out = [];
  walk(chunk, (n) => {
    if (n.type === 'Chunk' || n.type === 'Func' || n.type === 'Do' || n.type === 'While' || n.type === 'Repeat' || n.type === 'NumFor' || n.type === 'GenFor') out.push(n.body);
    else if (n.type === 'If') { n.clauses.forEach((c) => out.push(c.body)); if (n.orelse) out.push(n.orelse); }
  });
  return out;
};

const literalValue = (e) => {
  switch (e.type) {
    case 'String': return e.value;
    case 'Number': return e.value;
    case 'True': return true;
    case 'False': return false;
    default: return null;
  }
};

/** One round: returns the substitutions made, as { node, was, decl } with `decl` the declaration the read must still resolve to (null for literals). */
function round(chunk) {
  const info = analyze(chunk);
  const stable = (v) => v && !v.isGlobal && v.writes.length === 0 && (v.kind === 'param' || v.kind === 'for' || v.kind === 'localfunc' || (v.kind === 'local' && v.hasInit));
  const done = [];
  const copies = [];
  for (const v of info.vars) {
    if (v.kind !== 'local' || !v.hasInit || v.writes.length !== 0 || !v.reads.length || !v.init) continue;
    const init = strip(v.init);
    if (init.type === 'Name') {
      const src = info.varOf.get(init);
      if (!stable(src) || src === v) continue;
      copies.push({ v, src });
    } else if (init.type === 'String' && !readsAsText(init.value)) {
      // only data (encrypted text, bytes) is moved to where it is read: it is what a decoder is called with. A readable constant keeps the
      // name its author gave it (`local maxWeight = 40`, `local url = "https://..."`), which is part of what makes the program readable.
      const long = init.value.length > SHORT_LITERAL && v.reads.length > 1;
      if (!long) copies.push({ v, literal: init });
    }
  }
  for (const c of copies) {
    for (const node of c.v.reads) {
      if (c.src) {
        done.push({ node, was: { name: node.name }, decl: c.src.decl, v: c.v });
        node.name = c.src.name;
      } else {
        const keep = {};
        for (const k of Object.keys(node)) keep[k] = node[k];
        done.push({ node, was: keep, decl: null, v: c.v });
        const lit = makeConst(literalValue(c.literal));
        for (const k of Object.keys(node)) delete node[k];
        Object.assign(node, lit);
      }
    }
  }
  if (!done.length) return { done, removed: 0, reverted: 0 };

  // a name that now sits under a declaration of the same name that is not the one meant has to go back
  const after = analyze(chunk);
  const bad = new Set();
  for (const d of done) {
    if (d.decl === null) continue;
    const now = after.varOf.get(d.node);
    if (!now || now.decl !== d.decl) bad.add(d.v);
  }
  let reverted = 0;
  for (const d of done) {
    if (!bad.has(d.v)) continue;
    if (d.decl === null) { for (const k of Object.keys(d.node)) delete d.node[k]; Object.assign(d.node, d.was); } else d.node.name = d.was.name;
    reverted++;
  }

  // declarations nothing reads any more
  let removed = 0;
  // (judged on the tree as it is now: a read can have been made by this very round, when a copy of a copy was renamed onto this variable,
  // and a read put back as it was has to count again)
  const final = reverted ? analyze(chunk) : after;
  const gone = new Set();
  for (const d of done) {
    if (bad.has(d.v)) continue;
    const now = final.varOf.get(d.v.decl);
    if (now && now.reads.length === 0 && now.writes.length === 0) gone.add(d.v.decl);
  }
  for (const body of lists(chunk)) {
    for (let i = 0; i < body.length; i++) {
      const st = body[i];
      if (st.type !== 'Local' || !st.ids.some((id) => gone.has(id))) continue;
      if (st.values.length > st.ids.length) continue;
      const keep = st.ids.map((id, k) => (gone.has(id) ? -1 : k)).filter((k) => k >= 0);
      removed += st.ids.length - keep.length;
      if (!keep.length) { body.splice(i, 1); i--; continue; }
      // dropping a name from the middle of a list shifts later values onto the wrong names unless every value is a single, effect-free one
      const simple = st.values.every((x) => { const y = strip(x); return y.type === 'Name' || isLiteral(y); });
      if (!simple) { removed -= st.ids.length - keep.length; continue; }
      st.ids = keep.map((k) => st.ids[k]);
      st.values = keep.filter((k) => k < st.values.length).map((k) => st.values[k]);
    }
  }
  return { done, removed, reverted };
}

/**
 * Replace reads of locals that never change by the value they were given (another such local, or a literal).
 * @returns {{changed: number}} the number of reads replaced
 */
export function propagateStable(chunk) {
  let changed = 0;
  for (let i = 0; i < 8; i++) {
    const r = round(chunk);
    const n = r.done.length - r.reverted;
    if (n <= 0 && !r.removed) break;
    changed += Math.max(0, n);
    // a round that only put things back would repeat itself
    if (n <= 0) break;
  }
  return { changed };
}
