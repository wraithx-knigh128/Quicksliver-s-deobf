// Undo function inlining: `(function(a, b) <body> end)(x, y)` written out at every call site.
//
// An inliner (Hercules' function_inliner.lua; several custom obfuscators do the same) deletes a function's definition and pastes its
// text, wrapped in a closure, wherever the function was called. The copies are identical, so the function is still there: this pass
// gives every distinct closure text its own `local function` again and turns the copies back into calls.
//
//   * copies are grouped by structure (core/walk.js structuralKey), and inside a group by the variables the body takes from outside:
//     two copies are the same function only if every free variable is the very same declaration;
//   * the definition is put as far out as those variables allow (before the statement that holds the first copy, in the outermost
//     enclosing block where all of them are already declared): a function that needs nothing local goes to the top-level block;
//   * a copy that takes no arguments and stands as a statement on its own, with no `return` in it, is not a call of anything: its
//     body is put in a `do ... end` block where it stood;
//   * a closure that occurs once is only given a name when the caller says the script was produced by an inliner (`single`), because
//     `(function(x) ... end)(v)` written once by hand is an idiom, not an artefact.
//
// Nothing is evaluated, and the meaning is unchanged: creating a closure has no effect of its own, the variables it captures are
// the same ones, and arguments are still evaluated at the call.

import { walk, forEachChild, structuralKey } from '../core/walk.js';
import { analyze } from '../core/scope.js';

const funcOf = (call) => {
  if (!call || call.type !== 'Call') return null;
  let f = call.fn;
  while (f && f.type === 'Paren') f = f.expr;
  return f && f.type === 'Func' && !f.isMethod ? f : null;
};

/** The statement lists a node owns. */
function blocksOf(node) {
  switch (node.type) {
    case 'Chunk': case 'Do': case 'While': case 'Repeat': case 'NumFor': case 'GenFor': case 'Func': return [node.body];
    case 'If': return [...node.clauses.map((c) => c.body), ...(node.orelse ? [node.orelse] : [])];
    default: return [];
  }
}

function hasReturn(body) {
  let found = false;
  const visit = (n) => {
    if (found || !n || typeof n !== 'object') return;
    if (n.type === 'Func') return;                       // a return in a nested function is its own
    if (n.type === 'Return') { found = true; return; }
    forEachChild(n, visit);
  };
  body.forEach(visit);
  return found;
}

function usesVararg(body) {
  let found = false;
  const visit = (n) => {
    if (found || !n || typeof n !== 'object') return;
    if (n.type === 'Func') return;
    if (n.type === 'Vararg') { found = true; return; }
    forEachChild(n, visit);
  };
  body.forEach(visit);
  return found;
}

const maxLine = (node) => { let m = 0; walk(node, (n) => { if (n.line > m) m = n.line; }); return m; };

/**
 * `f(x)` followed on the next line by `(function() ... end)()` with no `;` in between reads as one statement, `f(x)(function() ... end)()`:
 * the result of f called with a closure. Lua 5.1 refuses that text as ambiguous, and a tool that pastes closures as statements produces it
 * by accident (Hercules' inliner did until its fix of 2026-06-15). When the closure starts on a later line than the call before it ends,
 * the two are separated again.
 */
function splitGluedClosures(chunk, opts = {}) {
  let split = 0;
  const visit = (node) => {
    if (!node || typeof node !== 'object') return;
    for (const stmts of blocksOf(node)) {
      for (let i = 0; i < stmts.length; i++) {
        const s = stmts[i];
        if (s.type !== 'CallStmt' || s.call.type !== 'Call' || s.call.fn.type !== 'Call') continue;
        const mid = s.call.fn;                                   // head(function ... end)
        const head = mid.fn;
        if (mid.args.length !== 1 || mid.args[0].type !== 'Func' || mid.sugar) continue;
        if (head.type !== 'Call' && head.type !== 'MethodCall') continue;
        // on a later line the two were separate statements; on the same line the tool dropped the line break itself (Hercules before
        // 2026-06-15), which shows in the closure being called with exactly the arguments it declares
        const f = mid.args[0];
        if (!(f.line > maxLine(head)) && !(opts.sameLine && !f.vararg && f.params.length === s.call.args.length)) continue;
        const first = { ...s, call: head };
        const second = { type: 'CallStmt', call: { ...s.call, fn: { type: 'Paren', expr: mid.args[0] } }, line: mid.args[0].line, endLine: s.endLine };
        delete first.endLine;
        stmts.splice(i, 1, first, second);
        split++;
      }
    }
    forEachChild(node, visit);
  };
  visit(chunk);
  return split;
}

/**
 * @param {object} chunk
 * @param {{single?: boolean}} [opts] single: also name closures that occur only once (the script is known to be inlined)
 * @returns {{changed: number, functions: number, calls: number, blocks: number}}
 */
/**
 * `local f = function() ... end` directly followed by `f()`, with f used nowhere else: a closure called where it is written, as a compiler
 * leaves it (the closure goes to a register, the call takes it from there). Put back into that form so the rest of this pass sees it.
 */
function rejoinTemporaries(chunk) {
  const info = analyze(chunk);
  let joined = 0;
  const visit = (node) => {
    if (!node || typeof node !== 'object') return;
    for (const stmts of blocksOf(node)) {
      for (let i = 0; i + 1 < stmts.length; i++) {
        const s = stmts[i];
        const next = stmts[i + 1];
        if (s.type !== 'Local' || s.ids.length !== 1 || s.values.length !== 1 || s.values[0].type !== 'Func' || s.values[0].params.length || s.values[0].vararg) continue;
        if (next.type !== 'CallStmt' || next.call.type !== 'Call' || next.call.fn.type !== 'Name' || next.call.args.length) continue;
        const v = info.varOf.get(s.ids[0]);
        if (!v || info.varOf.get(next.call.fn) !== v || v.reads.length !== 1 || v.writes.length) continue;
        stmts.splice(i, 2, { ...next, call: { ...next.call, fn: { type: 'Paren', expr: s.values[0] } }, comments: [...(s.comments || []), ...(next.comments || [])] });
        joined++;
      }
    }
    forEachChild(node, visit);
  };
  visit(chunk);
  return joined;
}

export function uninlinePass(chunk, opts = {}) {
  const split = opts.single ? splitGluedClosures(chunk, { sameLine: true }) + rejoinTemporaries(chunk) : 0;
  const info = analyze(chunk);
  const taken = new Set();
  walk(chunk, (n) => { if (n.type === 'Name' || n.type === 'Id') taken.add(n.name); });
  let counter = 0;
  // the names the renaming pass gives functions it has nothing better for, so a recovered function reads like the others
  const fresh = () => { let name; do { name = counter ? `fn${counter}` : 'fn'; counter++; } while (taken.has(name)); taken.add(name); return name; };

  // ---- every closure that is called where it is written, with the blocks around it ------------------------------------------
  const sites = [];
  const visit = (node, path, depth) => {
    if (!node || typeof node !== 'object') return;
    const f = funcOf(node);
    if (f) sites.push({ call: node, func: f, path, depth });
    const where = new Map();
    for (const arr of blocksOf(node)) for (const s of arr) where.set(s, { stmts: arr, stmt: s });
    const inner = node.type === 'Func' ? depth + 1 : depth;
    forEachChild(node, (c) => visit(c, where.has(c) ? [...path, where.get(c)] : path, inner));
  };
  visit(chunk, [], 0);
  if (!sites.length) return { changed: split, split };

  const declaredIn = new WeakMap();
  const varsDeclaredIn = (node) => {
    let set = declaredIn.get(node);
    if (!set) {
      set = new Set();
      walk(node, (n) => { if (n.type === 'Id') { const v = info.varOf.get(n); if (v) set.add(v); } });
      if (node.type === 'Func') { const self = info.selfOf.get(node); if (self) set.add(self); }
      declaredIn.set(node, set);
    }
    return set;
  };
  const freeVars = (f) => {
    const own = varsDeclaredIn(f);
    const free = new Set();
    walk(f, (n) => { if (n.type === 'Name') { const v = info.varOf.get(n); if (v && !v.isGlobal && !own.has(v)) free.add(v); } });
    return free;
  };

  // The text of a closure with its own variables numbered in the order they appear and the captured ones named by their declaration: two
  // copies with the same key are the same function whatever their locals are called (a decompiler names them after where the copy stands).
  const alphaKey = (f) => {
    const own = varsDeclaredIn(f);
    const order = new Map();
    const label = (node) => {
      const v = info.varOf.get(node);
      if (!v || v.isGlobal) return `g:${node.name}`;
      if (!own.has(v)) return `f:${v.id}`;
      if (!order.has(v)) order.set(v, order.size);
      return `l:${order.get(v)}`;
    };
    const mark = new Map();
    walk(f, (n) => { if (n.type === 'Name' || n.type === 'Id') mark.set(n, label(n)); });
    for (const n of mark.keys()) { n.__k = n.name; n.name = mark.get(n); }
    let key;
    try { key = structuralKey(f); } finally { for (const n of mark.keys()) { n.name = n.__k; delete n.__k; } }
    return key;
  };

  // ---- group: same text, same captured variables -----------------------------------------------------------------------------
  const groups = new Map();
  for (const s of sites) {
    s.free = freeVars(s.func);
    const key = alphaKey(s.func);
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(s);
  }
  // innermost first, so that a body is already tidy when it becomes a definition
  const ordered = [...groups.values()].sort((a, b) => Math.max(...b.map((s) => s.depth)) - Math.max(...a.map((s) => s.depth)));

  let functions = 0, calls = 0, blocks = 0;
  const hoisted = new Map();             // name -> the definition this pass made
  const hoistedStmts = new Set();
  const holder = new WeakMap();          // call node -> the statement that is exactly this call (set below)
  walk(chunk, (n) => { if (n.type === 'CallStmt') holder.set(n.call, n); });

  // lines still free in each hole of the text (see `place`), by the statement that follows the hole
  const room = new Map();
  /**
   * Where the definition of a group's function goes: { stmts, at, hole } or null.
   * The outermost of the blocks around every copy where each captured variable is already declared before the statement that holds the
   * first copy; in it, the earliest place where that is still true. The inliner deleted the definition, so where it stood is not known:
   * helpers are conventionally defined before the code that uses them, and the earliest valid place needs no guess about the rest of
   * the block. One thing can be known: Hercules' inliner blanks a deleted definition line by line, so the hole it left is still in the
   * text, a run of empty lines as long as the functions that stood there. Where the valid range has a hole the function fits in, that is
   * where it stood (`hole`), and several functions share a hole in the order they are first used.
   */
  const place = (group) => {
    const { func } = group[0];
    let common = group[0].path.length;
    for (const s of group) {
      let k = 0;
      while (k < common && k < s.path.length && s.path[k].stmts === group[0].path[k].stmts) k++;
      common = k;
    }
    for (let level = 0; level < common; level++) {
      const stmts = group[0].path[level].stmts;
      const first = Math.min(...group.map((s) => stmts.indexOf(s.path[level].stmt)));
      if (first < 0) return null;
      const within = varsDeclaredIn(stmts[first]);
      let ok = true;
      for (const v of group[0].free) if (within.has(v)) { ok = false; break; }
      // a variable declared by a later statement of the same block cannot be seen from here either
      if (ok) for (const v of group[0].free) { if (v.declStmt && stmts.indexOf(v.declStmt) > first) { ok = false; break; } }
      if (!ok) continue;
      let at = 0;
      for (const v of group[0].free) { const d = v.declStmt ? stmts.indexOf(v.declStmt) : -1; if (d >= 0) at = Math.max(at, d + 1); }
      // functions this body calls that were given a definition a moment ago must come first, and earlier definitions stay in front
      walk(func, (n) => { if (n.type === 'Name' && hoisted.has(n.name)) { const d = stmts.indexOf(hoisted.get(n.name)); if (d >= 0) at = Math.max(at, d + 1); } });
      for (let j = first - 1; j >= at; j--) if (hoistedStmts.has(stmts[j])) { at = j + 1; break; }
      at = Math.min(at, first);
      const body = func.body;
      const lines = body.length && body[0].line && body[body.length - 1].endLine ? body[body.length - 1].endLine - body[0].line + 1 : 0;
      let best = null;
      if (lines) {
        for (let i = at; i <= first; i++) {
          const next = stmts[i];
          if (!next || !next.line) continue;
          if (!room.has(next)) {
            // measured from the statement before; the first statement of a nested block has none, and where its block began is not kept
            let prevEnd = stmts === chunk.body ? 0 : -1;
            for (let j = i - 1; j >= 0; j--) if (stmts[j].endLine) { prevEnd = stmts[j].endLine; break; }
            room.set(next, prevEnd < 0 ? 0 : next.line - prevEnd - 1 - (next.comments || []).length);
          }
          const left = room.get(next) - lines;
          // an ordinary blank line or two between statements is not a hole: the function's own lines must fit, and take up most of it
          if (left >= 0 && room.get(next) >= 3 && (!best || left < best.left)) best = { i, left, next };
        }
      }
      if (best) { room.set(best.next, best.left - 2 < 0 ? 0 : best.left - 2); return { stmts, at: best.i, hole: true }; }
      return { stmts, at, hole: false };
    }
    return null;
  };

  for (const group of ordered) {
    const { func } = group[0];
    const params = func.params.length;
    let placed = null;
    // a parameterless closure standing as a statement: its body, in place, unless the text has the hole of a deleted definition for it
    if (params === 0 && !func.vararg && !hasReturn(func.body) && group.every((s) => s.call.args.length === 0 && holder.has(s.call))) {
      placed = opts.single ? place(group) : null;
      if (!placed || !placed.hole) {
        for (const site of group) {
          const stmt = holder.get(site.call);
          const at = site.path[site.path.length - 1];
          const i = at ? at.stmts.indexOf(stmt) : -1;
          if (i >= 0) { at.stmts[i] = { type: 'Do', body: site.func.body, comments: stmt.comments, line: stmt.line, endLine: stmt.endLine }; blocks++; }
        }
        continue;
      }
    } else {
      if (group.length === 1 && !(opts.single && (params > 0 || func.vararg))) continue;
      placed = place(group);
    }
    if (!placed) continue;
    placed.first = placed.at;
    const name = fresh();
    const def = { type: 'LocalFunction', id: { type: 'Id', name }, func: { ...func, isMethod: false } };
    // a comment above the first statement of the script (a banner) stays above everything
    const next = placed.stmts[placed.first];
    if (placed.first === 0 && next && next.comments && next.comments.length) { def.comments = next.comments; next.comments = []; }
    placed.stmts.splice(placed.first, 0, def);
    hoisted.set(name, def); hoistedStmts.add(def);
    functions++;
    for (const s of group) {
      s.call.fn = { type: 'Name', name };
      calls++;
    }
  }
  return { changed: functions + blocks + split, functions, calls, blocks, split };
}
