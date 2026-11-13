// MoonVeil 2.0.26 / 2.1.0: the table of factories joined into one program.
//
// These revisions do not keep the program as bytecode. They keep it as a table of functions that build each other:
//
//   return ({ <items>, h = pack, i = unpack, O = builder }):O({ <names> }, "entry", ...)
//
//   factory   function(ctx, cells) return function(...) BODY end end        a closure that has not been given its upvalues yet
//   site      ctx:NAME{ cellA, cellB }                                       the closure, built from the factory called NAME with those cells
//   cell      { [3] = 1, [1] = value }  read and written as cell[1]          a captured variable, one table slot wide
//   ctx._     getfenv()                                                      the environment: ctx._["print"] is the global print
//
// The names are a permutation of the table's positions that the builder undoes (moonveil.js: nameMap). The control flow of each factory is taken apart by moonveil-cff.js, and the
// strings and numbers are read by moonveil.js. What was left was this: a program in pieces that reach each other through a context object. Here the pieces are put back where
// they were used: every site becomes the function expression of its factory, the cells of the site become the variables they were, `ctx._.x` becomes the global `x`, and the
// context disappears. A site that cannot be read (a factory that does something else than return a closure, a context member this reader does not know) stops the join and says
// which; nothing is half done.

import { clone, walk, transform } from '../core/walk.js';
import { analyze } from '../core/scope.js';
import { findRoot, nameMap } from './moonveil.js';

export class JoinError extends Error {}
const fail = (m) => { throw new JoinError(m); };

const isFunc = (e) => e && e.type === 'Func';
const strip = (e) => (e && e.type === 'Paren' ? strip(e.expr) : e);
const name = (n) => ({ type: 'Name', name: n });
const str = (value) => ({ type: 'String', value, raw: null });
const IDENT = /^[A-Za-z_][A-Za-z0-9_]*$/;
const KEYWORDS = new Set(['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while', 'continue']);

/** What each position of the table is called, read before anything rewrites the builder. */
export function snapshotNames(chunk) {
  const root = findRoot(chunk);
  const map = root && nameMap(root);
  if (!map) return null;
  const items = root.table.fields.filter((f) => f.kind === 'item').map((f) => f.value);
  const byNode = new Map([...map].map(([k, v]) => [v, k]));
  const names = items.map((n) => byNode.get(n));
  if (names.some((n) => n === undefined)) return null;
  return { names, entry: root.call.args[1] && root.call.args[1].type === 'String' ? root.call.args[1].value : null };
}

/** Every local gets a name of its own, so that a function body can be copied into another scope without capturing anything there. */
function uniqueLocals(chunk) {
  const info = analyze(chunk);
  let n = 0;
  for (const v of info.vars) {
    const fresh = `u${++n}`;
    v.decl.name = fresh;
    for (const r of v.reads) r.name = fresh;
    for (const w of v.writes) w.name = fresh;
  }
  return n;
}

/** `{ [3] = 1, [1] = x }`-style cells are left to the box pass; what matters here is `cells[k]`. */
const cellIndex = (e, cells) => {
  if (e.type !== 'Index' || e.obj.type !== 'Name' || e.obj.name !== cells) return null;
  const k = strip(e.key);
  return k.type === 'Number' ? k.value : null;
};

export function joinMoonVeil(chunk, snapshot) {
  if (!snapshot) fail('the names of the functions were not read before the control flow was rebuilt');
  const root = findRoot(chunk);
  if (!root) fail('this is not a table of functions in the shape MoonVeil produces');
  const items = root.table.fields.filter((f) => f.kind === 'item').map((f) => f.value);
  if (items.length !== snapshot.names.length) fail('the table changed shape since its names were read');
  const members = new Map();
  items.forEach((node, i) => members.set(snapshot.names[i], node));
  for (const f of root.table.fields) if (f.kind === 'named') members.set(f.key, f.value);
  const entry = members.get(snapshot.entry);
  if (!isFunc(entry)) fail('the entry of the program is not a function');

  // work on a copy: the script is only changed when the whole join succeeded
  const work = clone({ type: 'Chunk', body: [{ type: 'Return', values: [{ type: 'Table', fields: [...members].map(([k, v]) => ({ kind: 'named', key: k, value: v })) }] }], endComments: [], features: new Set() });
  const table = work.body[0].values[0];
  const copy = new Map(table.fields.map((f) => [f.key, f.value]));
  uniqueLocals(work);

  const hoisted = [];                                       // helper definitions the program still needs: [localName, expression]
  const hoistedNames = new Map();
  const hoist = (key, expr) => {
    if (!hoistedNames.has(key)) { const n = `__${key}`; hoistedNames.set(key, n); hoisted.push([n, expr]); }
    return hoistedNames.get(key);
  };
  const stats = { sites: 0, factories: new Set(), env: 0 };
  const stack = [];

  /** A factory's closure, built for these cells. */
  function instantiate(key, cellArgs) {
    const F = copy.get(key);
    if (!isFunc(F)) return null;
    if (stack.includes(key)) fail(`the factory ${key} builds itself`);
    const ret = F.body[F.body.length - 1];
    const setup = F.body.slice(0, -1);
    if (!ret || ret.type !== 'Return' || ret.values.length !== 1 || !isFunc(strip(ret.values[0]))) fail(`the factory ${key} does something else than return a closure`);
    if (setup.some((s) => !(s.type === 'Local' && s.values.length === 0))) fail(`the factory ${key} does work before it returns its closure`);
    stack.push(key);
    stats.factories.add(key);
    const ctx = F.params[0] && F.params[0].name;
    const cells = F.params[1] && F.params[1].name;
    const inner = clone(strip(ret.values[0]));
    const pre = [];                                              // [name, expression]: cells that are not a plain name are bound around the closure
    const cellName = (k) => {
      const arg = cellArgs[k - 1];
      if (!arg) fail(`the factory ${key} reads cell ${k}, which its site does not give`);
      const a = strip(arg);
      if (a.type === 'Name') return a;
      const bound = `${cells}_${k}`;
      if (!pre.some(([n]) => n === bound)) pre.push([bound, arg]);
      return name(bound);
    };
    const wrapper = { type: 'Func', params: [], vararg: false, body: [{ type: 'Return', values: [inner] }] };
    // the places the context and the cell list may be named: the object of a member access, of a method call, of `cells[k]`
    const allowed = new WeakSet();
    walk(inner, (n) => {
      if ((n.type === 'Index' || n.type === 'MethodCall') && n.obj.type === 'Name' && (n.obj.name === ctx || n.obj.name === cells)) allowed.add(n.obj);
    });
    // the closure's own body, bottom-up: cells first, then the context, then the sites (whose arguments were rewritten by then)
    transform(inner, {
      expr(e) {
        const k = cells ? cellIndex(e, cells) : null;
        if (k !== null) return cellName(k);
        if (e.type === 'Name' && cells && e.name === cells && !allowed.has(e)) fail(`the factory ${key} uses its list of cells as a whole`);
        if (!ctx) return undefined;
        if (e.type === 'Index' && e.obj.type === 'Name' && e.obj.name === ctx) {
          const key2 = strip(e.key);
          if (key2.type !== 'String') fail(`the context is indexed with something that is not a name (in ${key})`);
          const m = key2.value;
          if (m === '_') { stats.env++; return name('__env'); }
          if (m === 'h' || m === 'i') return name(hoist(m, copy.get(m)));
          const member = copy.get(m);
          if (member && !isFunc(member)) {
            const x = strip(member);
            if (x.type === 'Index' && x.obj.type === 'Name' && !isFunc(x)) return clone(x);              // bit32.band and the like
            return name(hoist(m, member));
          }
          fail(`the context member ${m} (used in ${key}) is not one this reader knows`);
        }
        if (e.type === 'MethodCall' && e.obj.type === 'Name' && e.obj.name === ctx) {
          const arg = e.args[0] && strip(e.args[0]);
          const list = !arg ? [] : arg.type === 'Table' ? arg.fields.map((f) => { if (f.kind !== 'item') fail(`a site in ${key} gives its cells by name`); return f.value; }) : null;
          if (!list || e.args.length > 1) fail(`a site in ${key} passes something else than a list of cells`);
          const f = instantiate(e.name, list);
          if (!f) fail(`the site ${key} -> ${e.name} names something that is not a factory`);
          stats.sites++;
          return f;
        }
        if (e.type === 'Name' && e.name === ctx && !allowed.has(e)) fail(`the context of ${key} is used as a value`);
        return undefined;
      },
    });
    stack.pop();
    if (!pre.length && !setup.length) return inner;
    // a cell that is created where the closure is, or variables the factory declares for its closure to share: a scope of their own around the closure, given their first values by the call
    const outer = { type: 'Func', params: pre.map(([n]) => ({ type: 'Id', name: n })), vararg: false, body: [...clone(setup), { type: 'Return', values: [inner] }] };
    return { type: 'Call', fn: { type: 'Paren', expr: outer }, args: pre.map(([, a]) => a) };
  }

  // the entry: its context parameter and body become the program. What it sets on the context (the runtime the helpers use) is dropped when nothing reads it
  const entryFn = copy.get(snapshot.entry);
  const ctx = entryFn.params[0] && entryFn.params[0].name;
  const body = entryFn.body.filter((s) => !(s.type === 'Assign' && s.targets.every((t) => t.type === 'Index' && t.obj.type === 'Name' && t.obj.name === ctx) && s.values.every((v) => v.type === 'MethodCall' && v.obj.type === 'Name' && v.obj.name === ctx)));
  const holder = { type: 'Func', params: entryFn.params.slice(1), vararg: entryFn.vararg, body };
  // the entry is rewritten like any factory (its first parameter is the context), with no cells
  copy.set(snapshot.entry, { type: 'Func', params: [{ type: 'Id', name: ctx }], vararg: false, body: [{ type: 'Return', values: [holder] }] });
  stack.length = 0;
  const main = instantiate(snapshot.entry, []);
  let leftover = false;
  walk(main, (n) => { if (n.type === 'Name' && n.name === ctx) leftover = true; });
  if (leftover) fail('the context is still used after the join');

  const prologue = [];
  if (stats.env) prologue.push({ type: 'Local', ids: [{ type: 'Id', name: '__env' }], values: [{ type: 'Call', fn: name('getfenv'), args: [] }] });
  for (const [n, expr] of hoisted) prologue.push({ type: 'Local', ids: [{ type: 'Id', name: n }], values: [clone(expr)] });
  const result = { type: 'Chunk', body: [...prologue, { type: 'Return', values: [{ type: 'Call', fn: { type: 'Paren', expr: main }, args: [{ type: 'Vararg' }] }] }], endComments: [], features: new Set() };
  // the environment: `__env["print"]` is the global print
  transform(result, {
    expr(e) {
      if (e.type === 'Index' && e.obj.type === 'Name' && e.obj.name === '__env') {
        const k = strip(e.key);
        if (k.type === 'String' && IDENT.test(k.value) && !KEYWORDS.has(k.value)) return name(k.value);
      }
      return undefined;
    },
  });
  chunk.body = result.body;
  chunk.features = new Set([...(chunk.features || [])]);
  if (process.env.DBGJ) console.error([...stats.factories].sort().join(' '));
  return { changed: stats.sites, sites: stats.sites, factories: stats.factories.size, env: stats.env, helpers: hoisted.length };
}

// ---- cells become variables -----------------------------------------------------------------------------------------------------

/** `{ [a] = n, [n] = value }`: a cell. Its value sits at slot n; slot a says so. Returns {slot, value} or null. */
function cellOf(e) {
  const t = strip(e);
  if (!t || t.type !== 'Table' || t.fields.length !== 2) return null;
  const keyed = t.fields.map((f) => (f.kind === 'keyed' && strip(f.key).type === 'Number' ? { key: strip(f.key).value, value: strip(f.value), raw: f } : null));
  if (keyed.some((k) => !k)) return null;
  for (const [marker, content] of [[keyed[0], keyed[1]], [keyed[1], keyed[0]]]) {
    if (marker.value.type === 'Number' && marker.value.value === content.key && marker.key !== content.key) return { slot: content.key, value: content.raw.value };
  }
  return null;
}

/**
 * A variable that holds a cell and is only ever used as `v[slot]` is that slot's variable: `v = { [3] = 1, [1] = x }` is `v = x`, and `v[1]` is `v`. A cell that is created again
 * each time a loop runs, while closures hold on to the earlier ones, is a different variable each time, and is left as a cell.
 */
export function unboxCells(chunk) {
  const info = analyze(chunk);
  const parentOf = new Map();
  const loopsAround = new Map();           // node -> depth of loops (within its function) around it
  const visit = (n, parent, depth) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach((x) => visit(x, parent, depth)); return; }
    if (n.type) parentOf.set(n, parent);
    let d = depth;
    if (n.type === 'While' || n.type === 'Repeat' || n.type === 'NumFor' || n.type === 'GenFor') d = depth + 1;
    if (n.type === 'Func') d = 0;
    if (n.type) loopsAround.set(n, depth);
    for (const k of Object.keys(n)) if (k !== 'line' && n[k] && typeof n[k] === 'object') visit(n[k], n.type ? n : parent, d);
  };
  visit(chunk, null, 0);
  const constructors = new Map();           // constructor node -> its value
  const unboxed = new Map();                // Var -> slot
  const writeSites = new Map();             // Var -> [{constructor, node}]
  walk(chunk, (n) => {
    const pairs = n.type === 'Assign' ? n.targets.map((t, i) => [t, n.values[i]]) : n.type === 'Local' ? n.ids.map((t, i) => [t, n.values[i]]) : null;
    if (!pairs) return;
    for (const [t, v] of pairs) {
      if (!v) continue;
      const c = cellOf(v);
      if (!c) continue;
      const target = t.type === 'Name' || t.type === 'Id' ? info.varOf.get(t) : null;
      if (!target) continue;
      if (!writeSites.has(target)) writeSites.set(target, []);
      writeSites.get(target).push({ ctor: strip(v), slot: c.slot, value: c.value, stmt: n, node: v });
    }
  });
  for (const [v, sites] of writeSites) {
    if (v.isGlobal) continue;
    const slot = sites[0].slot;
    if (sites.some((s) => s.slot !== slot)) continue;
    // every write is one of these constructors; every read is v[slot]
    const writesAll = v.writes.length === sites.filter((s) => s.stmt.type === 'Assign').length;
    if (!writesAll) continue;
    if (v.hasInit && v.init && !sites.some((s) => s.stmt.type === 'Local')) continue;
    const reads = v.reads.every((r) => {
      const p = parentOf.get(r);
      return p && p.type === 'Index' && p.obj === r && strip(p.key).type === 'Number' && strip(p.key).value === slot;
    });
    if (!reads) continue;
    // a cell made again in a loop that the variable outlives, with closures holding the earlier ones
    if (v.captured && sites.some((s) => (loopsAround.get(s.stmt) || 0) > 0 && !(s.stmt.type === 'Local'))) continue;
    unboxed.set(v, slot);
    for (const s of sites) constructors.set(s.ctor, s.value);
  }
  if (!unboxed.size) return { changed: 0 };
  let changed = 0;
  const unboxedNames = new Map([...unboxed].flatMap(([v, slot]) => v.reads.map((r) => [r, slot])));       // the read of the cell -> the slot it is read at
  transform(chunk, {
    expr(e) {
      if (constructors.has(strip(e)) && constructors.get(strip(e)) !== undefined) { changed++; return constructors.get(strip(e)); }
      if (e.type === 'Index' && e.obj.type === 'Name' && unboxedNames.has(e.obj)) { const k = strip(e.key); if (k.type === 'Number' && k.value === unboxedNames.get(e.obj)) { changed++; return e.obj; } }
      return undefined;
    },
  });
  // `v = v` left by a parameter that was boxed in place
  transform(chunk, {
    block(stmts) {
      const out = stmts.filter((s) => !(s.type === 'Assign' && s.targets.length === 1 && s.values.length === 1 && s.targets[0].type === 'Name' && s.values[0].type === 'Name' && s.targets[0].name === s.values[0].name));
      return out.length === stmts.length ? undefined : out;
    },
  });
  return { changed, cells: unboxed.size };
}
