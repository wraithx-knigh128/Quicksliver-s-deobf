// Statement-level clean-up that follows constant folding.
//
//   propagate   immutable locals holding a literal or an alias of a standard global are substituted
//   reduce      `if true`, `if false`, `while false` collapse; `do ... end` is flattened when safe
//   dead        unused locals, local functions and dead stores with side-effect-free values are removed
//   unrollOnce  `while` loops that provably run exactly once (opaque loop wrappers) are unwrapped
//
// Every transformation is justified by scope analysis (core/scope.js). Anything that would need a
// guess about run-time behaviour is skipped.

import { transform, walk, clone } from '../core/walk.js';
import { analyze, STDLIB_GLOBALS } from '../core/scope.js';
import { NOT_CONST, evalBinary, evalUnary } from './consteval.js';
import { constOf, makeConst, PURE_LIBS } from './fold.js';
import { isMachineName } from './rename.js';
import { numericExpr, numericVars, isArithmetic, isComparison } from './numeric.js';

// ---- purity ------------------------------------------------------------------

/** Standard functions that only compute a value (setmetatable merely tags a table that is not shared yet). */
const PURE_CALLEES = new Set([
  'setmetatable', 'rawget', 'rawequal', 'type', 'tostring', 'tonumber', 'select', 'unpack',
  'string.char', 'string.byte', 'string.sub', 'string.rep', 'string.reverse', 'string.lower', 'string.upper',
  'string.len', 'string.format', 'math.floor', 'math.ceil', 'math.abs', 'math.sqrt', 'math.max', 'math.min',
  'table.concat', 'table.unpack', 'getfenv', 'getmetatable',
]);

/** Name of the standard function a callee refers to (`string.char`), or null. Needs scope info. */
function pureCalleeName(fn, info) {
  if (!info) return null;
  const root = (e) => (e.type === 'Name' ? e : e.type === 'Index' && e.obj.type === 'Name' ? e.obj : null);
  const r = root(fn);
  if (!r) return null;
  const v = info.varOf.get(r);
  if (!v || !v.isGlobal || v.writes.length) return null;
  if (fn.type === 'Name') return fn.name;
  return fn.key.type === 'String' ? `${fn.obj.name}.${fn.key.value}` : null;
}

/** No observable effect and cannot fail in a way a script would rely on. `info` lets standard calls count as pure. */
export function isPure(e, info = null) {
  switch (e.type) {
    case 'Nil': case 'True': case 'False': case 'Number': case 'String': case 'Vararg': case 'Name': case 'Func':
      return true;
    case 'Paren': return isPure(e.expr, info);
    case 'Table': return e.fields.every((f) => (f.kind !== 'keyed' || isPure(f.key, info)) && isPure(f.value, info));
    case 'Index': return isPure(e.obj, info) && isPure(e.key, info);
    case 'Unary': return e.op === 'not' ? isPure(e.arg, info) : constOf(e.arg) !== NOT_CONST || (!!info && !!info.numeric && numericExpr(e, info));
    case 'Binary':
      if (info && info.numeric && (isArithmetic(e.op) || isComparison(e.op)) && numericExpr(e.left, info) && numericExpr(e.right, info)) return true;
      if (e.op === 'and' || e.op === 'or' || e.op === '==' || e.op === '~=') return isPure(e.left, info) && isPure(e.right, info);
      return constOf(e.left) !== NOT_CONST && constOf(e.right) !== NOT_CONST;
    case 'Call': {
      const name = pureCalleeName(e.fn, info);
      return !!name && PURE_CALLEES.has(name) && e.args.every((a) => isPure(a, info));
    }
    default: return false;
  }
}

const isTerminal = (s) => s && (s.type === 'Return' || s.type === 'Break' || s.type === 'Continue' || s.type === 'Goto');

// ---- propagate -----------------------------------------------------------------

/** `string.char`, `print`, `table.insert`: a reference to an untouched standard global. */
function stdAlias(e, info) {
  if (e.type === 'Name') {
    const v = info.varOf.get(e);
    return v && v.isGlobal && v.writes.length === 0 && STDLIB_GLOBALS.has(e.name);
  }
  if (e.type === 'Index' && e.key.type === 'String') return e.obj.type === 'Name' && stdAlias(e.obj, info);
  return false;
}

function propagate(chunk) {
  const info = analyze(chunk);
  const localNames = new Set(info.vars.map((v) => v.name));
  const replace = new Map(); // Name node -> replacement factory

  for (const v of info.vars) {
    if (v.kind !== 'local' || v.writes.length || !v.hasInit || !v.init || !v.reads.length) continue;
    const init = v.init;
    // A name the author chose is part of the source and stays. An alias of a standard function under a one-
    // or two-letter name (`local z = setmetatable`) is machine output even when the letter looks conventional.
    const shortAlias = v.name.length <= 2 && stdAlias(init, info);
    if (!isMachineName(v.name) && !shortAlias) continue;
    const c = constOf(init);
    let make = null;
    if (c !== NOT_CONST && init.type !== 'Paren') {
      // Numbers and strings stay as the named constants they are. Booleans and nil are inlined because they
      // decide branches (opaque predicates are built from them); aliases of standard functions are handled below.
      const worthInlining = typeof c === 'boolean' || c === undefined;
      if (worthInlining) make = () => makeConst(c);
    } else if (stdAlias(init, info)) {
      const root = init.type === 'Name' ? init.name : init.obj.name;
      if (!localNames.has(root)) make = () => clone(init);   // a same-named local could capture it
    }
    if (make) for (const r of v.reads) replace.set(r, make);
  }
  if (!replace.size) return 0;
  transform(chunk, { expr(e) { return e.type === 'Name' && replace.has(e) ? replace.get(e)() : undefined; } });
  return replace.size;
}

// ---- reduce ----------------------------------------------------------------------

function namesDeclared(body) {
  const out = new Set();
  for (const s of body) {
    if (s.type === 'Local') s.ids.forEach((id) => out.add(id.name));
    else if (s.type === 'LocalFunction') out.add(s.id.name);
  }
  return out;
}

function namesUsed(stmts) {
  const out = new Set();
  walk(stmts, (n) => { if (n.type === 'Name') out.add(n.name); if (n.type === 'Function' && n.method) out.add('self'); });
  return out;
}

function hasGotoOrLabel(body) {
  let found = false;
  walk(body, (n) => { if (n.type === 'Label' || n.type === 'Goto') found = true; });
  return found;
}

function reduce(chunk) {
  let changed = 0;
  transform(chunk, {
    stmt(s) {
      if (s.type === 'While') {
        const c = constOf(s.cond);
        if (c === undefined || c === false) { changed++; return null; }
      }
      if (s.type === 'If') {
        const kept = [];
        let orelse = s.orelse;
        let touched = false;
        for (let i = 0; i < s.clauses.length; i++) {
          const c = constOf(s.clauses[i].cond);
          if (c === NOT_CONST) { kept.push(s.clauses[i]); continue; }
          touched = true;
          if (c === undefined || c === false) continue;      // never taken
          orelse = s.clauses[i].body;                          // always taken: everything after is dead
          break;
        }
        if (touched) {
          changed++;
          if (kept.length) return { ...s, clauses: kept, orelse };
          return orelse && orelse.length ? { type: 'Do', body: orelse, comments: s.comments } : null;
        }
      }
      return undefined;
    },
    block(stmts) {
      const out = [];
      let touched = false;
      stmts.forEach((s, i) => {
        if (s.type !== 'Do') { out.push(s); return; }
        if (s.body.length === 0) { touched = true; return; }
        const last = i === stmts.length - 1;
        const tail = s.body[s.body.length - 1];
        if (hasGotoOrLabel(s.body) || (isTerminal(tail) && !last)) { out.push(s); return; }
        const declared = namesDeclared(s.body);
        if (declared.size) {
          const later = namesUsed(stmts.slice(i + 1));
          for (const n of declared) if (later.has(n)) { out.push(s); return; }
        }
        touched = true;
        if (s.comments && s.body[0]) s.body[0].comments = [...s.comments, ...(s.body[0].comments || [])];
        out.push(...s.body);
      });
      if (!touched) return undefined;
      changed++;
      return out;
    },
  });
  return changed;
}

// ---- dead code ------------------------------------------------------------------------

/**
 * Declarations that nothing reads in the program as it was handed to us. Anything that becomes unused later
 * is the result of our own transformations and may be deleted; the author's unused locals are left alone.
 * Take this snapshot once, before any pass has changed the tree.
 */
export function snapshotUnused(chunk) {
  const set = new WeakSet();
  for (const v of analyze(chunk).vars) if (v.reads.length === 0) set.add(v.decl);
  return set;
}

function removeDead(chunk, state) {
  const info = analyze(chunk);
  // arithmetic and comparisons over variables that only ever hold numbers cannot fail or call anything: `if n * 0 ~= 0 then end` is junk
  numericVars(chunk, info);
  const junkInit = (e) => e.type === 'Number' || e.type === 'String' || e.type === 'True' || e.type === 'False' || e.type === 'Nil';
  const removable = (v, init) => v.reads.length === 0 && (isMachineName(v.name) || !state.unusedAtStart.has(v.decl) || (init && junkInit(init)));
  const dead = (name) => {
    const v = info.varOf.get(name);
    return v && !v.isGlobal && v.reads.length === 0 && (isMachineName(v.name) || !state.unusedAtStart.has(v.decl));
  };
  let changed = 0;
  transform(chunk, {
    stmt(s) {
      if (s.type === 'Local') {
        const vars = s.ids.map((id) => info.varOf.get(id));
        // a declaration list without values (what a decompiler hoists) loses the names nothing uses
        if (s.values.length === 0 && s.ids.length > 1) {
          const keep = s.ids.filter((id, i) => !(removable(vars[i]) && vars[i].writes.length === 0));
          if (keep.length && keep.length < s.ids.length) { changed++; return { ...s, ids: keep }; }
        }
        if (vars.every((v, i) => removable(v, s.values[i]))) {
          if (s.values.every((x) => isPure(x, info))) { changed++; return null; }
          if (s.ids.length === 1 && s.values.length === 1 && (s.values[0].type === 'Call' || s.values[0].type === 'MethodCall')) {
            changed++;
            return { type: 'CallStmt', call: s.values[0], comments: s.comments, line: s.line };
          }
        }
      } else if (s.type === 'LocalFunction') {
        const v = info.varOf.get(s.id);
        const inside = new Set();
        walk(s.func, (n) => { if (n.type === 'Name') inside.add(n); });
        const trivial = s.func.body.every((x) => x.type === 'Local' && x.ids.length === 1 && x.ids[0].name === '_' && x.values.length === 1 && junkInit(x.values[0]));
        if ((isMachineName(v.name) || trivial || !state.unusedAtStart.has(v.decl)) && v.reads.every((r) => inside.has(r)) && v.writes.length === 0) { changed++; return null; }
      } else if (s.type === 'Assign') {
        if (s.targets.every((t) => t.type === 'Name' && dead(t)) && s.values.every((x) => isPure(x, info))) { changed++; return null; }
      } else if (s.type === 'NumFor') {
        const empty = s.body.length === 0 && !(s.body.endComments && s.body.endComments.length);
        if (empty && isPure(s.start, info) && isPure(s.stop, info) && (!s.step || isPure(s.step, info))) { changed++; return null; }
      } else if (s.type === 'If') {
        const empty = (b) => b.length === 0 && !(b.endComments && b.endComments.length);
        if (s.clauses.length === 1 && empty(s.clauses[0].body) && (!s.orelse || empty(s.orelse)) && isPure(s.clauses[0].cond, info)) {
          changed++;
          return null;
        }
      }
      return undefined;
    },
  });
  return changed;
}

// ---- once-only loops ---------------------------------------------------------------------------

/** Evaluate with a table of known local values (Var -> constant). */
function evalWith(e, env, info) {
  switch (e.type) {
    case 'Name': {
      const v = info.varOf.get(e);
      return v && env.has(v) ? env.get(v) : NOT_CONST;
    }
    case 'Paren': return evalWith(e.expr, env, info);
    case 'Unary': {
      const a = evalWith(e.arg, env, info);
      return a === NOT_CONST ? NOT_CONST : evalUnary(e.op, a);
    }
    case 'Binary': {
      const a = evalWith(e.left, env, info);
      if (a === NOT_CONST) return NOT_CONST;
      if ((e.op === 'and' && (a === undefined || a === false)) || (e.op === 'or' && a !== undefined && a !== false)) return a;
      const b = evalWith(e.right, env, info);
      return b === NOT_CONST ? NOT_CONST : evalBinary(e.op, a, b);
    }
    default: return constOf(e);
  }
}

function containsNode(root, targets) {
  const set = new Set(targets);
  let n = 0;
  walk(root, (x) => { if (set.has(x)) n++; });
  return n === set.size;
}

function levelHasBreak(stmts) {
  let found = false;
  const visit = (list) => {
    for (const s of list) {
      if (s.type === 'Break' || s.type === 'Goto') found = true;
      else if (s.type === 'Do') visit(s.body);
      else if (s.type === 'If') { s.clauses.forEach((c) => visit(c.body)); if (s.orelse) visit(s.orelse); }
      // nested loops and functions own their `break`
    }
  };
  visit(stmts);
  return found;
}

function unrollOnce(chunk) {
  const info = analyze(chunk);
  let changed = 0;

  transform(chunk, {
    block(stmts) {
      let out = null;
      stmts.forEach((s, idx) => {
        if (s.type !== 'While') { if (out) out.push(s); return; }
        const residual = tryUnroll(s, info);
        if (!residual) { if (out) out.push(s); return; }
        if (!out) out = stmts.slice(0, idx);
        changed++;
        if (residual.length) out.push({ type: 'Do', body: residual, comments: s.comments, blankBefore: s.blankBefore });
      });
      return out || undefined;
    },
  });
  return changed;
}

function tryUnroll(loop, info) {
  // Known values: constant-initialised locals declared before the loop. Those that the loop writes are
  // its "state"; read-only ones are plain constants and may be read by any statement.
  const env = new Map();
  const state = new Set();
  for (const v of info.vars) {
    if (v.kind !== 'local' || v.captured || !v.init) continue;
    if (containsNode(loop, [v.decl])) continue;   // loop state is declared before the loop, not inside it
    const c = constOf(v.init);
    if (c === NOT_CONST || v.init.type === 'Paren') continue;
    if (v.writes.length) {
      if (!containsNode(loop, v.writes)) continue;
      // The loop's writes disappear when it is unwrapped, so nothing outside may still read the variable.
      if (v.reads.length && !containsNode(loop, v.reads)) continue;
      state.add(v);
    }
    env.set(v, c);
  }
  if (!state.size) return null;
  const c0 = evalWith(loop.cond, env, info);
  if (c0 === NOT_CONST || c0 === undefined || c0 === false) return null;

  const residual = [];
  const touchesState = (node) => {
    let hit = false;
    walk(node, (n) => { if (n.type === 'Name' && state.has(info.varOf.get(n))) hit = true; });
    return hit;
  };

  let exited = false; // the executed path hit a `break`, so the loop ends there regardless of its condition
  const run = (body) => {
    for (const s of body) {
      if (exited) return true;
      if (s.type === 'Break') { exited = true; return true; }
      if (s.type === 'Assign' && s.targets.every((t) => t.type === 'Name' && state.has(info.varOf.get(t)))) {
        const vals = s.values.map((x) => evalWith(x, env, info));
        if (vals.length !== s.targets.length || vals.some((x) => x === NOT_CONST)) return false;
        s.targets.forEach((t, i) => env.set(info.varOf.get(t), vals[i]));
        continue;
      }
      if (s.type === 'If') {
        let chosen = null;
        let decided = true;
        for (const cl of s.clauses) {
          const c = evalWith(cl.cond, env, info);
          if (c === NOT_CONST) { decided = false; break; }
          if (c !== undefined && c !== false) { chosen = cl.body; break; }
        }
        if (!decided) return false;
        if (chosen === null) chosen = s.orelse || [];
        if (!run(chosen)) return false;
        continue;
      }
      if (touchesState(s)) return false;
      residual.push(s);
    }
    return true;
  };

  if (!run(loop.body)) return null;
  if (!exited) {
    const c1 = evalWith(loop.cond, env, info);
    if (c1 !== undefined && c1 !== false) return null;     // would iterate again
  }
  if (levelHasBreak(residual)) return null;
  if (residual.length && residual[residual.length - 1].type === 'Return') return null;
  return residual;
}

// ---- constant tables ----------------------------------------------------------------------------------------

/**
 * `local chars = { [104] = "h", [105] = "i" }` read only as `chars[104]`: every read is replaced by the
 * stored value. Only done when the table cannot change or escape, i.e. each use is a plain read with
 * a literal key.
 */
function inlineConstTables(chunk) {
  const info = analyze(chunk);
  const parentOf = new Map();
  const written = new Set(); // tables modified through t[k] = v
  walk(chunk, (n, parent) => {
    if (n.type === 'Name') parentOf.set(n, parent);
    const target = n.type === 'Assign' ? n.targets : n.type === 'CompoundAssign' ? [n.target] : [];
    for (const t of target) if (t.type === 'Index' && t.obj.type === 'Name') written.add(info.varOf.get(t.obj));
  });
  const replace = new Map();

  for (const v of info.vars) {
    if (v.kind !== 'local' || v.writes.length || written.has(v) || !v.init || v.init.type !== 'Table' || !v.reads.length) continue;
    const table = v.init;
    const charMap = table.fields.length > 0 && table.fields.every((f) => f.value.type === 'String' && f.value.value.length === 1);
    // An obfuscator's string array (machine-named, positional strings, read by constant index at several places)
    // is worth inlining; a table the author named, or one holding mixed data, is left alone.
    const stringArray = table.fields.length > 0 && table.fields.every((f) => f.kind === 'item' && f.value.type === 'String') && v.reads.length >= 3;
    if (!charMap && !(isMachineName(v.name) && stringArray)) continue;
    const entries = new Map();
    let ok = table.fields.length > 0;
    let positional = 1;
    table.fields.forEach((f, i) => {
      if (!ok) return;
      let key;
      if (f.kind === 'item') key = positional++;
      else if (f.kind === 'named') key = f.key;
      else { key = constOf(f.key); if (key === NOT_CONST || key === undefined) { ok = false; return; } }
      const val = constOf(f.value);
      const spreads = f.kind === 'item' && i === table.fields.length - 1 && (f.value.type === 'Call' || f.value.type === 'Vararg');
      if (val === NOT_CONST || spreads) { ok = false; return; }
      entries.set(key, val);
    });
    if (!ok) continue;
    const uses = [];
    for (const r of v.reads) {
      const p = parentOf.get(r);
      if (!p || p.type !== 'Index' || p.obj !== r) { ok = false; break; }
      const key = p.key.type === 'String' ? p.key.value : constOf(p.key);
      if (key === NOT_CONST || key === undefined || !entries.has(key)) { ok = false; break; }
      uses.push([p, entries.get(key)]);
    }
    if (ok) for (const [idx, val] of uses) replace.set(idx, val);
  }
  if (!replace.size) return 0;
  transform(chunk, { expr(e) { return replace.has(e) ? makeConst(replace.get(e)) : undefined; } });
  return replace.size;
}

// ---- sink declarations -----------------------------------------------------------------------------

/**
 * `local a, b` ... `a = print` -> `local a = print` at the point of assignment.
 * Legal when nothing refers to the variable in between, and it turns obfuscators' "declare
 * everything up front, assign later" style back into ordinary initialised locals, which the
 * propagate pass can then see through.
 */
function sinkDeclarations(chunk) {
  const info = analyze(chunk);
  let changed = 0;
  transform(chunk, {
    block(stmts) {
      let out = null;
      const work = () => out || (out = stmts.slice());
      for (let i = 0; i < stmts.length; i++) {
        const decl = stmts[i];
        if (decl.type !== 'Local') continue;
        const bare = decl.ids.filter((id, k) => k >= decl.values.length);
        if (decl.values.length && bare.length === decl.ids.length) continue;
        for (const id of bare) {
          const v = info.varOf.get(id);
          if (!v || v.writes.length === 0) continue;
          const refs = new Set([...v.reads, ...v.writes]);
          const firstUse = stmts.findIndex((s, j) => {
            if (j <= i) return false;
            let hit = false;
            walk(s, (n) => { if (refs.has(n)) hit = true; });
            return hit;
          });
          if (firstUse < 0) continue;
          const use = stmts[firstUse];
          if (use.type !== 'Assign' || use.targets.length !== 1 || use.values.length !== 1) continue;
          if (!v.writes.includes(use.targets[0])) continue;
          let selfRef = false;
          walk(use.values[0], (n) => { if (refs.has(n)) selfRef = true; });
          if (selfRef) continue;
          const list = work();
          const at = list.indexOf(use);
          list[at] = { type: 'Local', ids: [id], values: [use.values[0]], comments: use.comments, trailing: use.trailing, line: use.line, blankBefore: use.blankBefore, computed: use.computed };
          const d = list[list.indexOf(decl)];
          d.ids = d.ids.filter((x) => x !== id);
          changed++;
        }
      }
      if (!out) return undefined;
      return out.filter((s) => !(s.type === 'Local' && s.ids.length === 0 && s.values.length === 0));
    },
  });
  return changed;
}

/** The statement lists directly inside a compound statement: loop bodies, branches, `do` blocks. */
function nestedBlocks(s) {
  switch (s.type) {
    case 'NumFor': case 'GenFor': case 'While': case 'Repeat': case 'Do': return [s.body];
    case 'If': return [...s.clauses.map((c) => c.body), ...(s.orelse ? [s.orelse] : [])];
    default: return [];
  }
}

/**
 * `local v` ... `for ... do v = e ... end` -> `for ... do local v = e ... end`
 *
 * A variable that is declared up front but only ever used inside one block, and whose first use there is an
 * assignment on the block's own level, cannot carry a value from one pass of the block to the next, so the
 * declaration may move to that assignment. (A variable that a closure captured is left alone: a new local per
 * iteration is a different upvalue.) Decompilers declare every register at the top of the function; this puts
 * the declarations back where a person would write them.
 */
function sinkIntoBlocks(chunk) {
  const info = analyze(chunk);
  let changed = 0;
  const containsAny = (node, refs) => { let hit = false; walk(node, (n) => { if (refs.has(n)) hit = true; return !hit; }); return hit; };
  transform(chunk, {
    block(stmts) {
      let out = null;
      for (let i = 0; i < stmts.length; i++) {
        const decl = stmts[i];
        if (decl.type !== 'Local' || decl.attrib) continue;
        const moved = new Set();
        for (let n = decl.values.length; n < decl.ids.length; n++) {
          const id = decl.ids[n];
          const v = info.varOf.get(id);
          if (!v || v.captured || v.writes.length === 0 || id.attrib) continue;
          const refs = new Set([...v.reads, ...v.writes]);
          const users = [];
          for (let j = i + 1; j < stmts.length; j++) if (containsAny(stmts[j], refs)) users.push(j);
          if (users.length !== 1) continue;
          const host = stmts[users[0]];
          const bodies = nestedBlocks(host).filter((b) => b.some((x) => containsAny(x, refs)));
          if (bodies.length !== 1) continue;
          // everything that mentions the variable must be inside that one block, not in a loop condition or range
          let inside = 0;
          for (const r of refs) { let found = false; walk(bodies[0], (m) => { if (m === r) found = true; return !found; }); if (found) inside++; }
          if (inside !== refs.size) continue;
          const body = bodies[0];
          const first = body.findIndex((x) => containsAny(x, refs));
          const use = body[first];
          if (use.type !== 'Assign' || use.targets.length !== 1 || use.values.length !== 1 || !refs.has(use.targets[0]) || containsAny(use.values[0], refs)) continue;
          body[first] = { type: 'Local', ids: [id], values: [use.values[0]], comments: use.comments, trailing: use.trailing, line: use.line, blankBefore: use.blankBefore, computed: use.computed };
          moved.add(id);
          changed++;
        }
        if (moved.size) {
          if (!out) out = stmts.slice();
          out[i] = { ...decl, ids: decl.ids.filter((x) => !moved.has(x)) };
        }
      }
      if (!out) return undefined;
      return out.filter((s) => !(s.type === 'Local' && s.ids.length === 0 && s.values.length === 0));
    },
  });
  return changed;
}

// ---- driver --------------------------------------------------------------------------------------

export function simplifyPass(chunk, ctx = {}) {
  const deadState = { unusedAtStart: ctx.unusedAtStart || snapshotUnused(chunk) };
  const stats = { sunk: 0, tables: 0, propagated: 0, reduced: 0, dead: 0, unrolled: 0 };
  for (let round = 0; round < 24; round++) {
    const k = sinkDeclarations(chunk) + sinkIntoBlocks(chunk);
    const t = inlineConstTables(chunk);
    const p = propagate(chunk);
    const r = reduce(chunk);
    const d = removeDead(chunk, deadState);
    const u = unrollOnce(chunk);
    stats.tables += t;
    stats.sunk += k; stats.propagated += p; stats.reduced += r; stats.dead += d; stats.unrolled += u;
    if (!(k + t + p + r + d + u)) break;
  }
  if (ctx.log) ctx.log('simplify', stats);
  return { changed: Object.values(stats).reduce((x, y) => x + y, 0), stats };
}

export { PURE_LIBS };
