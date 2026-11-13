// A string table that decrypts itself in place.
//
//     local T = { [1] = "\026W..", [2] = "\004" }
//     do
//       local D = (function() ... return function(s, key, i) ... end end)()
//       T[1] = D(T[1], 47138, 1)
//       T[2] = D(T[2], 44241, 2)
//     end
//     local a = T[1]   ...   print(T[2])
//
// The decoder's arguments are not constants (the first is a read of the table), so nothing can evaluate them, and the table keeps looking like data.
// It is plain, though: the table is only ever read with constant keys, each entry is written at most once, and every write happens in straight-line
// code before the first read. Two steps, on either side of the pass that evaluates decoder calls:
//
//   seedDecoderCalls   `T[k] = D(T[k], ...)` becomes `T[k] = D("<what the constructor stored>", ...)`, which the evaluator can run;
//   inlineStringTable  once those calls hold their results (`T[k] = "plain"`), each read `T[k]` is that string and the writes go.
//
// The table may be set to nil once everything has been read (Obscura does, to free it). A table that is passed anywhere, indexed with a
// computed key, written in a loop or a branch, or read before its last write is left alone.

import { walk } from '../core/walk.js';
import { analyze } from '../core/scope.js';
import { NOT_CONST } from './consteval.js';
import { constOf } from './fold.js';
import { isMachineName } from './rename.js';

/** key -> string for a constructor of constant strings under constant keys, else null. */
function entriesOf(table) {
  const out = new Map();
  let pos = 1;
  for (const f of table.fields) {
    if (f.value.type !== 'String') return null;
    let key;
    if (f.kind === 'item') key = pos++;
    else if (f.kind === 'named') key = f.key;
    else { key = constOf(f.key); if (key === NOT_CONST || key === undefined) return null; }
    out.set(key, f.value.value);
  }
  return out.size ? out : null;
}

const keyOfIndex = (idx) => (idx.key.type === 'String' ? idx.key.value : constOf(idx.key));

/** Candidate tables of the chunk: every use of the variable is a constant-key read or a single-value assignment to a constant key. */
function candidates(chunk) {
  const info = analyze(chunk);
  const parentOf = new Map();
  const order = new Map();
  let counter = 0;
  const assigns = [];
  const clears = [];                                // `T = nil`
  walk(chunk, (n, parent) => {
    order.set(n, ++counter);
    if (n.type === 'Name') parentOf.set(n, parent);
    if (n.type === 'Assign' && n.targets.length === 1 && n.values.length === 1) {
      if (n.targets[0].type === 'Index' && n.targets[0].obj.type === 'Name') assigns.push(n);
      else if (n.targets[0].type === 'Name' && n.values[0].type === 'Nil') clears.push(n);
    }
  });
  // statement lists that run straight through, once, before anything that follows them
  const straight = new Set();
  const collect = (list) => { for (const s of list) { straight.add(s); if (s.type === 'Do') collect(s.body); } };
  collect(chunk.body);
  const out = [];
  for (const v of info.vars) {
    if (v.kind !== 'local' || !v.init || v.init.type !== 'Table') continue;
    const entries = entriesOf(v.init);
    if (!entries) continue;
    const cleared = clears.filter((a) => v.writes.includes(a.targets[0]));
    if (cleared.length !== v.writes.length || cleared.some((a) => !straight.has(a))) continue;
    const writes = [];
    const reads = [];
    let ok = true;
    for (const r of v.reads) {
      const p = parentOf.get(r);
      if (!p || p.type !== 'Index' || p.obj !== r) { ok = false; break; }
      const k = keyOfIndex(p);
      if (k === NOT_CONST || k === undefined) { ok = false; break; }
      const w = assigns.find((a) => a.targets[0] === p);
      if (w) writes.push({ stmt: w, key: k, index: p }); else reads.push({ index: p, key: k });
    }
    if (!ok) continue;
    // a write to the table that is not a read of it by the scope analysis (a target is a write)
    for (const a of assigns) {
      const t = a.targets[0];
      if (info.varOf.get(t.obj) === v && !writes.some((w) => w.stmt === a)) {
        const k = keyOfIndex(t);
        if (k === NOT_CONST || k === undefined) { ok = false; break; }
        writes.push({ stmt: a, key: k, index: t });
      }
    }
    if (!ok || !writes.length) continue;
    const seen = new Set();
    if (writes.some((w) => seen.has(w.key) || (seen.add(w.key), !straight.has(w.stmt) || !entries.has(w.key)))) continue;
    // the writes run in order and the table is declared before them; anything that reads the table must come after the last one
    const lastWrite = Math.max(...writes.map((w) => order.get(w.stmt)));
    // `T[k] = D(T[k], ...)` reads the stored text of the entry it replaces; that read is the decoder's input, not a use of the decrypted text
    const selfRead = (r) => writes.some((w) => { const val = w.stmt.values[0]; return val.type === 'Call' && val.args[0] === r.index && w.key === r.key; });
    const reads2 = reads.filter((r) => !writes.some((w) => w.index === r.index) && !selfRead(r));
    if (reads2.some((r) => order.get(r.index) < lastWrite)) continue;
    // the table is set to nil only after the last read
    if (cleared.some((a) => reads2.some((r) => order.get(r.index) > order.get(a)))) continue;
    out.push({ v, entries, writes, reads: reads2, cleared });
  }
  return out;
}

/** `T[k] = D(T[k], ...)` -> `T[k] = D("stored", ...)`. */
export function seedDecoderCalls(chunk) {
  let changed = 0;
  for (const c of candidates(chunk)) {
    for (const w of c.writes) {
      const val = w.stmt.values[0];
      if (val.type !== 'Call' || val.args.length === 0) continue;
      const a0 = val.args[0];
      if (a0.type !== 'Index' || a0.obj.type !== 'Name' || a0.obj.name !== w.index.obj.name) continue;
      if (keyOfIndex(a0) !== w.key) continue;
      val.args[0] = { type: 'String', value: c.entries.get(w.key), raw: null };
      changed++;
    }
  }
  return { changed };
}

/** Reads of a table whose every write is now a string literal are those strings. */
export function inlineStringTable(chunk) {
  let changed = 0;
  for (const c of candidates(chunk)) {
    if (!c.writes.every((w) => w.stmt.values[0].type === 'String')) continue;
    const final = new Map(c.entries);
    for (const w of c.writes) final.set(w.key, w.stmt.values[0].value);
    if (!c.reads.every((r) => final.has(r.key))) continue;
    const swap = new Map(c.reads.map((r) => [r.index, final.get(r.key)]));
    const drop = new Set([...c.writes.map((w) => w.stmt), ...c.cleared]);
    // `local a = T[1]`: a copy that is never assigned again was hoisted by the obfuscator (the table is wiped right after, or the copy is machine-named); its uses are the string and the copy goes
    {
      const info = analyze(chunk);
      walk(chunk, (n) => {
        if (n.type !== 'Local' || n.ids.length !== 1 || n.values.length !== 1 || !swap.has(n.values[0])) return undefined;
        const v = info.varOf.get(n.ids[0]);
        if (!v || v.writes.length || !(c.cleared.length || isMachineName(v.name))) return undefined;
        for (const r of v.reads) swap.set(r, swap.get(n.values[0]));
        drop.add(n);
        return undefined;
      });
    }
    const rewrite = (node) => {
      if (!node || typeof node !== 'object') return;
      if (Array.isArray(node)) {
        for (let i = node.length - 1; i >= 0; i--) {
          if (drop.has(node[i])) { node.splice(i, 1); changed++; }
          else if (swap.has(node[i])) { node[i] = { type: 'String', value: swap.get(node[i]), raw: null }; changed++; }
          else rewrite(node[i]);
        }
        return;
      }
      for (const k of Object.keys(node)) {
        if (k === 'line' || k === 'comments' || k === 'trailing') continue;
        const child = node[k];
        if (child && typeof child === 'object') {
          if (swap.has(child)) { node[k] = { type: 'String', value: swap.get(child), raw: null }; changed++; } else rewrite(child);
        }
      }
    };
    rewrite(chunk);
  }
  return { changed };
}

// ---- a table of constants that is only read ------------------------------------------------------------------------------------------------------

const literalOf = (e) => {
  if (!e) return null;
  if (e.type === 'Number' || e.type === 'String' || e.type === 'True' || e.type === 'False' || e.type === 'Nil') return e;
  if (e.type === 'Unary' && e.op === '-' && e.arg.type === 'Number') return e;
  if (e.type === 'Paren') return literalOf(e.expr);
  return null;
};

/** key -> literal node for a constructor of constants under positional or `[number] =` keys, else null. */
function constantEntries(table) {
  const out = new Map();
  let pos = 1;
  for (const f of table.fields) {
    const v = literalOf(f.value);
    if (!v) return null;
    let key;
    if (f.kind === 'item') key = pos++;
    else if (f.kind === 'keyed') { key = constOf(f.key); if (typeof key !== 'number') return null; }
    else return null;
    out.set(key, v);
  }
  return out;
}

/**
 * A local table of numbers, strings, booleans and nils, machine-named or written key by key, that is only ever read with a constant number as the key is a list of constants: each
 * read is the constant and the table goes. (XFuscator keeps every constant of the program in one such table, with `[k] = nil` entries where the program had nil, which is why it is written key by key.)
 */
export function inlineConstantTable(chunk) {
  const info = analyze(chunk);
  const parentOf = new Map();
  const stored = new Set();                         // the indexed places something is assigned to
  walk(chunk, (n, parent) => {
    if (n.type === 'Name') parentOf.set(n, parent);
    if (n.type === 'Assign') for (const t of n.targets) stored.add(t);
  });
  const swap = new Map();
  const drop = new Set();
  walk(chunk, (n) => {
    if (n.type !== 'Local' || n.ids.length !== 1 || n.values.length !== 1 || n.values[0].type !== 'Table') return undefined;
    const v = info.varOf.get(n.ids[0]);
    if (!v || v.kind !== 'local' || v.writes.length || !v.reads.length) return undefined;
    const entries = constantEntries(n.values[0]);
    if (!entries || entries.size < 3) return undefined;
    // a machine-named table, or one written key by key (`[1] = ..., [2] = ...`, the way a program that has nil among its constants has to): nobody writes a list like that by hand
    if (!isMachineName(v.name) && !(entries.size >= 5 && n.values[0].fields.every((f) => f.kind === 'keyed'))) return undefined;
    const sites = [];
    for (const r of v.reads) {
      const p = parentOf.get(r);
      if (!p || p.type !== 'Index' || p.obj !== r || stored.has(p)) return undefined;
      const k = constOf(p.key);
      if (typeof k !== 'number') return undefined;
      sites.push({ index: p, key: k });
    }
    for (const s of sites) swap.set(s.index, entries.get(s.key) || { type: 'Nil' });
    drop.add(n);
    return undefined;
  });
  if (!swap.size) return { changed: 0 };
  let changed = 0;
  const rewrite = (node) => {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) {
      for (let i = node.length - 1; i >= 0; i--) {
        if (drop.has(node[i])) { node.splice(i, 1); changed++; }
        else if (swap.has(node[i])) { node[i] = JSON.parse(JSON.stringify(swap.get(node[i]))); changed++; }
        else rewrite(node[i]);
      }
      return;
    }
    for (const k of Object.keys(node)) {
      if (k === 'line' || k === 'comments' || k === 'trailing') continue;
      const child = node[k];
      if (child && typeof child === 'object') {
        if (swap.has(child)) { node[k] = JSON.parse(JSON.stringify(swap.get(child))); changed++; } else rewrite(child);
      }
    }
  };
  rewrite(chunk);
  return { changed };
}
