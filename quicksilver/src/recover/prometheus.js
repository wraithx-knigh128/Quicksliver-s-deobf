// Recovery modules for Prometheus (https://github.com/prometheus-lua/Prometheus, by levno-710).
//
// Every pattern handled here was read from the Prometheus source and checked against real output
// (tests/corpus/obfuscated/prometheus). Nothing is guessed from the look of the code.

import { transform, walk } from '../core/walk.js';
import { analyze } from '../core/scope.js';
import { constOf, makeConst } from '../passes/fold.js';
import { NOT_CONST } from '../passes/consteval.js';

// ---- AntiTamper ------------------------------------------------------------------------------------------
//
// steps/AntiTamper.lua prepends `do local X = "<random>" for i = 0, N do ... end ... end`. It raises
// "Tamper Detected!" when error-message line numbers disagree, i.e. when the source is reformatted.

function isAntiTamperBlock(stmt) {
  if (stmt.type !== 'Do' || stmt.body.length < 3) return false;
  const first = stmt.body[0];
  if (first.type !== 'Local' || first.values.length !== 1 || first.values[0].type !== 'String') return false;
  if (!stmt.body.slice(1, 3).some((s) => s.type === 'NumFor')) return false;
  let marker = false;
  walk(stmt, (n) => { if (n.type === 'String' && n.value === 'Tamper Detected!') marker = true; });
  return marker;
}

// A tool derived from Prometheus keeps the message ("Tamper Detected!") and the idea (random calls whose error messages carry line numbers, checked against each other) but
// writes the block differently (no leading string, no numeric loop in front). The block is then recognised by what it does, not by how this version writes it: it holds the
// marker message, and it depends on nothing outside itself except standard globals (and globals nothing outside reads), so with the script untouched it changes nothing.
const GUARD_STD = new Set(['pcall', 'error', 'math', 'string', 'table', 'tostring', 'tonumber', 'select', 'unpack', 'setmetatable', 'getmetatable', 'rawget', 'rawset', 'type', 'assert', 'ipairs', 'pairs', 'next']);

function isSelfContainedGuard(stmt, info) {
  if (stmt.type !== 'Do' || stmt.body.length < 3) return false;
  let marker = false;
  const ids = new Set();
  const names = new Set();
  walk(stmt, (n) => {
    if (n.type === 'String' && n.value === 'Tamper Detected!') marker = true;
    if (n.type === 'Id') ids.add(n);
    if (n.type === 'Name') names.add(n);
  });
  if (!marker) return false;
  for (const n of names) {
    const v = info.varOf.get(n);
    if (!v) return false;
    if (v.isGlobal) {
      if (GUARD_STD.has(v.name)) continue;
      if ([...v.reads, ...v.writes].every((m) => names.has(m))) continue;      // a global only this block touches (the loop that never ends writes two)
      return false;
    }
    if (!ids.has(v.decl)) return false;                                      // a local of the program: the block reads the program's state
  }
  return true;
}

export function removeAntiTamper(chunk) {
  let removed = 0;
  const info = analyze(chunk);
  const isGuard = (s) => isAntiTamperBlock(s) || isSelfContainedGuard(s, info);
  transform(chunk, {
    block(stmts) {
      if (!stmts.some(isGuard)) return undefined;
      const out = stmts.filter((s) => !isGuard(s));
      removed += stmts.length - out.length;
      return out;
    },
  });
  return { changed: removed };
}

/**
 * The same guard after a compiler has taken the `do` block apart (Vmify compiles the guard together with the program, and the rebuilt text has the guard's statements at the
 * top of the chunk and the rest of the program under one `if flag then ... end`):
 *
 *   local flag = true  ...statements that only decide `flag` (the marker message among them)...  flag = flag and <check> ...  if flag then PROGRAM end
 *
 * With the script untouched every check passes, so the program is PROGRAM. Whatever follows the `if` is the failure path (a loop that never ends), reached only when PROGRAM has
 * returned, which it does when the check failed. This is taken only when the statements from `local flag = true` to the `if` hold the marker, write `flag` only as
 * `flag = flag and ...`, and when nothing they declare is used by the program: nothing outside the guard can notice that it is gone.
 */
export function removeGuardFlag(chunk) {
  const body = chunk.body;
  let at = -1;
  for (let i = body.length - 1; i >= 0; i--) {
    const s = body[i];
    if (s.type === 'If' && s.clauses.length === 1 && !s.orelse && s.clauses[0].cond.type === 'Name') { at = i; break; }
  }
  if (at < 0) return { changed: 0 };
  const info = analyze(chunk);
  const test = body[at].clauses[0].cond;
  const flag = info.varOf.get(test);
  if (!flag || flag.isGlobal || !flag.init || flag.init.type !== 'True') return { changed: 0 };
  const from = body.findIndex((s) => s.type === 'Local' && s.ids.length === 1 && info.varOf.get(s.ids[0]) === flag);
  if (from < 0 || from >= at) return { changed: 0 };
  // after the `if`: nothing (the rest of the program was inside it), or the failure path, which is only reached when the program under `if` has returned (it ends in a bare `return`)
  const inner = body[at].clauses[0].body;
  const tail = body.slice(at + 1);
  const last = inner[inner.length - 1];
  const returns = !!last && last.type === 'Return' && last.values.length === 0;
  if (tail.length && !returns) return { changed: 0 };
  const segment = [...body.slice(from, at), ...tail];
  const names = new Set();
  const ids = new Set();
  let marker = false;
  for (const st of segment) walk(st, (n) => { if (n.type === 'Name') names.add(n); if (n.type === 'Id') ids.add(n); if (n.type === 'String' && n.value === 'Tamper Detected!') marker = true; });
  if (!marker) return { changed: 0 };
  // `flag` is written only as `flag = flag and X`
  let writesOk = true;
  for (const st of segment) walk(st, (n) => {
    if (n.type === 'Assign' && n.targets.some((t) => t.type === 'Name' && info.varOf.get(t) === flag)) {
      const v = n.values[0];
      const ok = n.targets.length === 1 && n.values.length === 1 && v.type === 'Binary' && v.op === 'and' && v.left.type === 'Name' && info.varOf.get(v.left) === flag;
      if (!ok) writesOk = false;
    }
  });
  if (!writesOk) return { changed: 0 };
  // nothing declared in the segment is used outside it, and the segment depends on nothing of the program
  for (const v of info.vars) {
    if (!ids.has(v.decl)) continue;
    if ([...v.reads, ...v.writes].some((m) => !names.has(m) && m !== test)) return { changed: 0 };
  }
  for (const n of names) {
    const v = info.varOf.get(n);
    if (!v) return { changed: 0 };
    if (v.isGlobal) { if (!GUARD_STD.has(v.name) && [...v.reads, ...v.writes].some((m) => !names.has(m))) return { changed: 0 }; continue; }
    if (!ids.has(v.decl)) return { changed: 0 };
  }
  chunk.body = [...body.slice(0, from), ...(returns ? inner.slice(0, -1) : inner)];
  return { changed: segment.length + 1 };
}

// ---- ProxifyLocals ------------------------------------------------------------------------------------
//
// steps/ProxifyLocals.lua turns each local into a table with a metatable:
//
//   local P = setmetatable({ K = init }, { <opA> = function(r, q) r.K = q end,
//                                          <opB> = function(r, q) return r.K end })
//
// A read of the local is `P <opB> literal`, an assignment is `P <opA> value`, and since an operator
// expression is not a statement it is passed to a dummy function: `(D <opB'> literal)(P <opA> value)`.

const OP_OF_META = {
  __add: '+', __sub: '-', __mul: '*', __div: '/', __mod: '%', __pow: '^', __concat: '..', __index: 'index',
};

const isGlobalCall = (call, name, info) => {
  if (call.fn.type !== 'Name' || call.fn.name !== name) return false;
  const v = info.varOf.get(call.fn);
  return v && v.isGlobal && v.writes.length === 0;
};

/** Is `f` `function(r, q) r.K = q end` (a setter) or `function(r, q) return r.K end` (a getter)? */
function proxyAccessor(f, key) {
  if (f.type !== 'Func' || f.params.length !== 2 || f.body.length !== 1) return null;
  const [r, q] = f.params.map((p) => p.name);
  const s = f.body[0];
  const isField = (e) => e.type === 'Index' && e.obj.type === 'Name' && e.obj.name === r && e.key.type === 'String' && e.key.value === key;
  if (s.type === 'Assign' && s.targets.length === 1 && s.values.length === 1 && isField(s.targets[0]) && s.values[0].type === 'Name' && s.values[0].name === q) return 'set';
  if (s.type === 'Return' && s.values.length === 1) {
    const v = s.values[0];
    if (isField(v)) return 'get';
    if (v.type === 'Call' && v.fn.type === 'Name' && v.fn.name === 'rawget' && v.args.length === 2
      && v.args[0].type === 'Name' && v.args[0].name === r && v.args[1].type === 'String' && v.args[1].value === key) return 'get';
  }
  return null;
}

export function undoProxifyLocals(chunk) {
  const info = analyze(chunk);
  const proxies = new Map(); // Var -> { key, get, set, declStmt, init }

  walk(chunk, (n) => {
    if (n.type !== 'Local' || n.ids.length !== 1 || n.values.length !== 1) return;
    const call = n.values[0];
    if (call.type !== 'Call' || call.args.length !== 2) return;
    // `setmetatable` may have been aliased to a local (local L = setmetatable); look through one alias.
    let isSet = isGlobalCall(call, 'setmetatable', info);
    if (!isSet && call.fn.type === 'Name') {
      const fv = info.varOf.get(call.fn);
      isSet = !!(fv && fv.init && fv.writes.length === 0 && fv.init.type === 'Name' && fv.init.name === 'setmetatable');
    }
    if (!isSet) return;
    // a tool derived from this one declares the table and the accessors apart (`local t = { K = f }`, `local function get(r, q) ... end`, `setmetatable(t, { __sub = get, ... })`):
    // a name bound once to a value stands for that value
    const through = (e) => {
      let x = e;
      for (let i = 0; i < 3 && x.type === 'Name'; i++) {
        const v = info.varOf.get(x);
        if (!v || v.isGlobal || v.writes.length || !v.init) break;
        x = v.init;
      }
      return x;
    };
    // `{ K = v }` and `{ ["K"] = v }` are the same field: a decoded name is a string constant, which is written the second way until the printer chooses
    const fieldName = (f) => (f.kind === 'named' ? f.key : f.kind === 'keyed' && f.key.type === 'String' ? f.key.value : null);
    const data = through(call.args[0]);
    const meta = through(call.args[1]);
    if (data.type !== 'Table' || data.fields.length !== 1 || fieldName(data.fields[0]) === null) return;
    if (meta.type !== 'Table' || meta.fields.length !== 2 || !meta.fields.every((f) => OP_OF_META[fieldName(f)])) return;
    const key = fieldName(data.fields[0]);
    const roles = meta.fields.map((f) => ({ meta: fieldName(f), role: proxyAccessor(through(f.value), key) }));
    const set = roles.find((r) => r.role === 'set');
    const get = roles.find((r) => r.role === 'get');
    if (!set || !get) return;
    proxies.set(info.varOf.get(n.ids[0]), { key, get: OP_OF_META[get.meta], set: OP_OF_META[set.meta], declStmt: n, init: data.fields[0].value });
  });
  // A proxy is undone only when every use of its variable is one this pass rewrites. A copy of the proxy (`local q = P`, which a rebuilt program makes for a register) or a use as an
  // argument would be left reading a table whose declaration is gone, and the program would no longer run.
  const unsafe = new Set();
  walk(chunk, (n, parent) => {
    if (n.type !== 'Name') return;
    const v = info.varOf.get(n);
    const p = v && proxies.get(v);
    if (!p) return;
    const asOperand = parent && parent.type === 'Binary' && parent.left === n && (parent.op === p.get || parent.op === p.set);
    const asIndex = parent && parent.type === 'Index' && parent.obj === n && (p.get === 'index' || p.set === 'index' || (parent.key.type === 'String' && parent.key.value === p.key));
    if (!asOperand && !asIndex) unsafe.add(v);
  });
  for (const v of unsafe) proxies.delete(v);
  if (!proxies.size) return { changed: 0 };

  // A read `P <get> literal` becomes the bare name `P`. That name stands for the proxy's *value*, not the proxy,
  // so it must never be matched as a proxy again: `t[k] = v` after the rewrite of `(t .. "x")[k] = v` is an
  // ordinary index assignment, while `P[v]` in the original is the proxy's setter.
  const synthetic = new WeakSet();
  const proxyOf = (e) => (e.type === 'Name' && !synthetic.has(e) ? proxies.get(info.varOf.get(e)) : undefined);
  const readOf = (name) => { const n = { type: 'Name', name: name.name }; synthetic.add(n); info.varOf.set(n, info.varOf.get(name)); return n; };
  let reads = 0;
  let writes = 0;

  transform(chunk, {
    expr(e) {
      if (e.type === 'Binary') {
        const p = proxyOf(e.left);
        if (p && p.get === e.op) { reads++; return readOf(e.left); }
        if (p && p.set === e.op) return { type: '__Set', target: e.left, value: e.right };
      }
      if (e.type === 'Index') {
        const p = proxyOf(e.obj);
        // `function Shape.new() end` is emitted as `function proxy.<K>.new() end`: a direct read of the stored value
        if (p && e.key.type === 'String' && e.key.value === p.key) { reads++; return readOf(e.obj); }
        if (p && p.get === 'index') { reads++; return readOf(e.obj); }
        if (p && p.set === 'index') return { type: '__Set', target: e.obj, value: e.key };
      }
      return undefined;
    },
    stmt(s) {
      // (D <get> literal)(P <set> value) -> P = value
      if (s.type === 'CallStmt' && s.call.type === 'Call' && s.call.args.length === 1 && s.call.args[0].type === '__Set') {
        const set = s.call.args[0];
        writes++;
        return { type: 'Assign', targets: [{ type: 'Name', name: set.target.name }], values: [set.value], comments: s.comments, trailing: s.trailing, line: s.line, blankBefore: s.blankBefore };
      }
      if (s.type === 'Local' && s.ids.length === 1) {
        const p = proxies.get(info.varOf.get(s.ids[0]));
        if (p && p.declStmt === s) return { ...s, values: [p.init] };
      }
      return undefined;
    },
  });
  // Reads of the dummy callee must be plain names again; anything still wrapped in __Set is not a pattern we know.
  let leftover = 0;
  walk(chunk, (n) => { if (n.type === '__Set') leftover++; });
  return { changed: reads + writes, reads, writes, proxies: proxies.size, leftover };
}


// ---- decryption machinery nothing reads any more ------------------------------------------------------------------------------------------

const PURE_STD = /^(string|math|table)$/;

/**
 * Prometheus' EncryptStrings keeps the text of every string encrypted and a cache that the program reads through the decryptor. Once every read has been replaced by its text, what is
 * left is calls of the decryptor as statements (a call whose result nothing uses), the decryptor, its pseudo-random generator and a loop that shuffles a lookup table: a machine that
 * only ever works on its own state. It is removed when
 *   * a local function is referenced only as the callee of call statements (their result is discarded),
 *   * it, and the local functions it calls, call nothing but the standard string, math and table libraries, and
 *   * every variable they write is read only by them and by top-level statements that write nothing else.
 */
export function removeOrphanDecoders(chunk) {
  const info = analyze(chunk);
  const top = new Set(chunk.body);
  const funcOf = new Map();                       // Var -> the function node of `local function f`
  const declId = (s) => (s.type === 'LocalFunction' ? s.id : s.type === 'Local' && s.ids.length === 1 && s.values.length === 1 && s.values[0].type === 'Func' ? s.ids[0] : null);
  for (const s of chunk.body) { const id = declId(s); const v = id && info.varOf.get(id); if (v) funcOf.set(v, s); }
  const inside = (node, target) => { let hit = false; walk(node, (n) => { if (n === target) hit = true; return hit ? false : undefined; }); return hit; };
  const callStmtsOf = (v) => { const out = []; walk(chunk, (n) => { if (n.type === 'CallStmt' && n.call.fn && n.call.fn.type === 'Name' && info.varOf.get(n.call.fn) === v) out.push(n); return undefined; }); return out; };
  let changed = 0;
  for (const [v, decl] of funcOf) {
    const calls = callStmtsOf(v);
    if (!calls.length || v.reads.length !== calls.length || v.writes.length) continue;
    // the group: this function and the local functions it calls
    const group = new Map([[v, decl]]);
    let ok = true;
    const gather = (fnNode) => {
      walk(fnNode, (n) => {
        if (n.type === 'MethodCall') ok = false;
        if (n.type === 'Call') {
          const f = n.fn;
          if (f.type === 'Name') {
            const w = info.varOf.get(f);
            if (w && funcOf.has(w)) { if (!group.has(w)) { group.set(w, funcOf.get(w)); gather(funcOf.get(w)); } }
            // a local that is an alias of a standard function is as pure as the function; any other callee (a parameter, a global, an upvalue of unknown value) is not known to be
            else if (!w || w.kind === 'global' || !(w.init && w.init.type === 'Index' && w.init.obj.type === 'Name' && PURE_STD.test(w.init.obj.name) && w.writes.length === 0)) ok = false;
          } else if (!(f.type === 'Index' && f.obj.type === 'Name' && PURE_STD.test(f.obj.name))) ok = false;
        }
        return undefined;
      });
    };
    gather(decl);
    if (!ok) continue;
    // the state they write
    const state = new Set();
    for (const g of group.values()) {
      walk(g, (n) => {
        if (n.type === 'Assign') for (const t of n.targets) { const base = t.type === 'Index' ? t.obj : t; if (base.type === 'Name') { const w = info.varOf.get(base); if (w && w.kind !== 'global' && !group.has(w)) state.add(w); } }
        return undefined;
      });
    }
    // a variable local to the group's own bodies is not state of the chunk
    const owned = new Set();
    for (const w of state) if (w.funcDepth > 0 && !chunk.body.includes(w.declStmt)) owned.add(w);
    for (const w of owned) state.delete(w);
    // top-level statements that work on that state and nothing else
    const feeders = new Set();
    for (const s of chunk.body) {
      if (s === decl || [...group.values()].includes(s) || s.type === 'Local' || s.type === 'LocalFunction' || s.type === 'CallStmt') continue;
      const writes = [];
      let impure = false;
      walk(s, (n) => {
        if (n.type === 'Assign') for (const t of n.targets) { const base = t.type === 'Index' ? t.obj : t; if (base.type === 'Name') writes.push(info.varOf.get(base)); }
        if (n.type === 'Call' && !(n.fn.type === 'Index' && n.fn.obj.type === 'Name' && PURE_STD.test(n.fn.obj.name))) impure = true;
        return undefined;
      });
      if (writes.length && !impure && writes.every((w) => w && state.has(w))) feeders.add(s);
    }
    // a machine that works on no state of its own is a program, not a decoder
    if (!state.size) continue;
    // every read of the state lies in the group or in a feeder
    for (const w of state) {
      for (const r of w.reads) {
        const inGroup = [...group.values()].some((g) => inside(g, r)) || [...feeders].some((f) => inside(f, r));
        if (!inGroup) { ok = false; break; }
      }
      if (!ok) break;
    }
    if (!ok) continue;
    const drop = new Set([...calls, ...group.values(), ...feeders]);
    for (const w of state) if (w.declStmt && top.has(w.declStmt) && w.declStmt.type === 'Local' && w.declStmt.ids.length === 1 && w.declStmt.values.every((x) => x.type === 'Table' || x.type === 'Number' || x.type === 'Nil')) drop.add(w.declStmt);
    transform(chunk, { block: (stmts) => (stmts.some((x) => drop.has(x)) ? stmts.filter((x) => !drop.has(x)) : undefined) });
    changed += drop.size;
    break;                                        // the analysis is stale; the next round looks again
  }
  return { changed };
}

/**
 * SplitStrings' joiner, `local j = function(t) local L, g = t[#t], "" for i = 1, #L do g = g .. L[t[i]] end return g end`, is written into every program the step
 * touches. When no string was split, or every split string has been joined back, nothing reads it: an unread local holding exactly that function is dropped.
 */
export function removeUnusedJoiner(chunk) {
  const info = analyze(chunk);
  const isJoiner = (f) => {
    if (!f || f.type !== 'Func' || f.params.length !== 1 || f.vararg || f.body.length !== 3) return false;
    const [decl, loop, ret] = f.body;
    if (decl.type !== 'Local' || decl.ids.length !== 2 || decl.values.length !== 2) return false;
    const [last, empty] = decl.values;
    const p = f.params[0].name;
    if (!(last.type === 'Index' && last.obj.type === 'Name' && last.obj.name === p && last.key.type === 'Unary' && last.key.op === '#')) return false;
    if (empty.type !== 'String' || empty.value !== '') return false;
    if (loop.type !== 'NumFor' || ret.type !== 'Return' || ret.values.length !== 1 || ret.values[0].type !== 'Name' || ret.values[0].name !== decl.ids[1].name) return false;
    return loop.body.length === 1 && loop.body[0].type === 'Assign' && loop.body[0].values.length === 1 && loop.body[0].values[0].type === 'Binary' && loop.body[0].values[0].op === '..';
  };
  const drop = new Set();
  for (const s of chunk.body) {
    const fn = s.type === 'LocalFunction' ? s.func : s.type === 'Local' && s.ids.length === 1 && s.values.length === 1 ? s.values[0] : null;
    const id = s.type === 'LocalFunction' ? s.id : s.type === 'Local' ? s.ids[0] : null;
    const v = id && info.varOf.get(id);
    if (v && isJoiner(fn) && v.writes.length === 0 && v.reads.filter((r) => !(s.type === 'LocalFunction' && (() => { let hit = false; walk(fn, (n) => { if (n === r) hit = true; }); return hit; })())).length === 0) drop.add(s);
  }
  if (!drop.size) return { changed: 0 };
  chunk.body = chunk.body.filter((s) => !drop.has(s));
  return { changed: drop.size };
}

export { makeConst, constOf, NOT_CONST };
