// Clean-up passes for the code a lifted MoonVeil program leaves behind, over the block graph (the shape cfg-opt.js and decompile/cfg.js take).
//
// The VM keeps the results of a call whose count is not fixed (`f(g())`, `return g()`, `{g()}`) in a run of registers and a "top" variable, and
// the next instruction reads the run back with RANGE(M, base, top). Lifted instruction by instruction that reads
//
//     t  = table.pack(g(x))            the call, once
//     La = t                           (copies)
//     t  = La.n                        how many values it gave
//     zb = t + 3                       top of the run that starts at register 4
//     table_move(La, 1, t, 4, M)       the values into registers 4, 5, ...
//     ...
//     r3 = f(RANGE(M, 4, zb))          the next instruction: everything from register 4 to the top
//
// openRuns() recognises that whole shape inside one block and rewrites the read as table.unpack(La), after which inlineTemps() folds a pack that
// is only ever unpacked back into the call it was made from:  r3 = f(g(x)).
//
// None of this changes what the program does; it removes the machinery between two instructions.

import { walk } from '../core/walk.js';

const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const isName = (e, n) => { e = strip(e); return !!e && e.type === 'Name' && (n === undefined || e.name === n); };
const isTableFn = (fn, member) => { fn = strip(fn); return fn.type === 'Index' && isName(fn.obj, 'table') && fn.key.type === 'String' && fn.key.value === member; };
const isPackCall = (e) => { e = strip(e); return !!e && e.type === 'Call' && isTableFn(e.fn, 'pack'); };
const isUnpackCall = (e) => { e = strip(e); return !!e && e.type === 'Call' && isTableFn(e.fn, 'unpack'); };
const unpackOf = (nameNode) => ({ type: 'Call', fn: { type: 'Index', obj: { type: 'Name', name: 'table' }, key: { type: 'String', value: 'unpack', raw: null }, dot: true }, args: [nameNode], sugar: null });

/** Bottom-up rewrite of an expression or statement: `fn` may return a replacement for a node, or undefined to keep it. */
function rewrite(node, fn) {
  if (!node || typeof node !== 'object') return node;
  if (Array.isArray(node)) { let changed = false; const out = node.map((x) => { const y = rewrite(x, fn); if (y !== x) changed = true; return y; }); return changed ? out : node; }
  let copy = null;
  for (const k of Object.keys(node)) {
    if (k === 'line' || k === 'pos' || k === 'endPos' || k === 'endLine') continue;
    const v = node[k];
    if (!v || typeof v !== 'object') continue;
    const w = rewrite(v, fn);
    if (w !== v) { if (!copy) copy = { ...node }; copy[k] = w; }
  }
  const cur = copy || node;
  const r = node.type ? fn(cur) : undefined;
  return r === undefined ? cur : r;
}

const countNames = (node, name) => { let n = 0; walk(node, (x) => { if (x.type === 'Name' && x.name === name) n++; }); return n; };
// `ref(r)` names the variable a closure captures: the variable, not its value, so the name stays where it is
const isCapture = (x) => x.type === 'Call' && strip(x.fn).type === 'Name' && (strip(x.fn).name === 'ref' || strip(x.fn).name === 'upref');
const captured = (node, name) => { let hit = false; walk(node, (x) => { if (isCapture(x) && x.args.some((a) => strip(a).type === 'Name' && strip(a).name === name)) hit = true; }); return hit; };
const containsEffect = (node) => { let hit = false; walk(node, (x) => { if (x.type === 'Call' || x.type === 'MethodCall' || x.type === 'Func') hit = true; return !hit; }); return hit; };

const capturedNames = (blocks) => {
  const out = new Set();
  const scan = (node) => walk(node, (x) => { if (isCapture(x)) for (const a of x.args) if (strip(a).type === 'Name') out.add(strip(a).name); });
  for (const b of blocks.values()) { scan(b.stmts); if (b.term.kind === 'branch') scan(b.term.cond); if (b.term.kind === 'return' && b.term.values) scan(b.term.values); }
  return out;
};


/**
 * Whether a closure is made over the variable `name` from here on, before the variable is assigned again: the value written now is the one the
 * closure will see, so the assignment has to stay. Looks at the rest of block `id` after statement `from` and then at what follows.
 */
function capturedLater(blocks, id, from, name) {
  const scan = (stmts, start) => {
    for (let i = start; i < stmts.length; i++) {
      const st = stmts[i];
      if (captured(st, name)) return 'capture';
      if (st.type === 'Assign' && st.targets.some((t) => t.type === 'Name' && t.name === name)) return 'write';
    }
    return null;
  };
  const first = scan(blocks.get(id).stmts, from);
  if (first) return first === 'capture';
  const seen = new Set([id]);
  const stack = [];
  const push = (t) => { for (const m of t.kind === 'goto' ? [t.to] : t.kind === 'branch' ? [t.t, t.f] : []) if (!seen.has(m)) { seen.add(m); stack.push(m); } };
  push(blocks.get(id).term);
  while (stack.length) {
    const m = stack.pop();
    const b = blocks.get(m);
    if (!b) continue;
    const r = scan(b.stmts, 0);
    if (r === 'capture') return true;
    if (r === 'write') continue;
    if (b.term.kind === 'branch' && captured(b.term.cond, name)) return true;
    push(b.term);
  }
  return false;
}

// ---- open runs ------------------------------------------------------------------------------------------------------------

/**
 * Reads of a run of results (RANGE(M, base, top)) whose producer is in the same block become table.unpack of the pack the producer made.
 * @returns {number} how many reads were rewritten
 */
export function openRuns(blocks) {
  let rewritten = 0;
  let nextId = 1;
  // a pack (and its size) made once and never assigned again, such as the arguments of a function, is the same pack in every block
  const writes = new Map();
  for (const b of blocks.values()) for (const st of b.stmts) if (st.type === 'Assign') for (const t of st.targets) if (t.type === 'Name') writes.set(t.name, (writes.get(t.name) || 0) + 1);
  const onePack = new Map();
  const oneCount = new Map();
  for (const b of blocks.values()) for (const st of b.stmts) {
    if (st.type !== 'Assign' || st.targets.length !== 1 || st.values.length !== 1 || st.targets[0].type !== 'Name') continue;
    const name = st.targets[0].name;
    if (writes.get(name) !== 1) continue;
    const v = strip(st.values[0]);
    if (isPackCall(v)) onePack.set(name, nextId++);
  }
  for (const b of blocks.values()) for (const st of b.stmts) {
    if (st.type !== 'Assign' || st.targets.length !== 1 || st.values.length !== 1 || st.targets[0].type !== 'Name') continue;
    const name = st.targets[0].name;
    const v = strip(st.values[0]);
    if (writes.get(name) === 1 && v.type === 'Index' && v.key.type === 'String' && v.key.value === 'n' && isName(v.obj) && onePack.has(strip(v.obj).name)) oneCount.set(name, onePack.get(strip(v.obj).name));
  }
  for (const b of blocks.values()) {
    const packs = new Map(onePack);   // name -> id of the pack it holds
    const counts = new Map(oneCount); // name -> id of the pack whose size it holds
    const tops = new Map();    // name -> { id, k }  (the name is the size of pack `id` plus k)
    const runs = [];           // { id, base, holder, at, consumed }
    const kill = (n) => { packs.delete(n); counts.delete(n); tops.delete(n); };
    const out = [];
    b.stmts.forEach((st0) => {
      // reads first: they see the state before this statement's own assignments
      let st = st0;
      const topInfo = (e) => {
        e = strip(e);
        if (e.type === 'Name' && tops.has(e.name)) return tops.get(e.name);
        // the top of a run that starts at register 1 is the size itself
        if (e.type === 'Name' && counts.has(e.name)) return { id: counts.get(e.name), k: 0 };
        if (e.type === 'Binary' && (e.op === '+' || e.op === '-') && isName(e.left) && counts.has(strip(e.left).name) && strip(e.right).type === 'Number') return { id: counts.get(strip(e.left).name), k: e.op === '+' ? strip(e.right).value : -strip(e.right).value };
        if (e.type === 'Binary' && e.op === '+' && isName(e.right) && counts.has(strip(e.right).name) && strip(e.left).type === 'Number') return { id: counts.get(strip(e.right).name), k: strip(e.left).value };
        return null;
      };
      // RANGE(M, from, top): the registers from `from` up to the top of the run, as the values they hold
      const expand = (n) => {
        if (n.type !== 'Call' || !isName(n.fn, 'RANGE') || n.args.length !== 3 || !isName(n.args[0], 'M')) return null;
        const from = strip(n.args[1]);
        if (from.type !== 'Number') return null;
        const t = topInfo(n.args[2]);
        if (!t) return null;
        const run = [...runs].reverse().find((r) => r.id === t.id && r.base >= from.value && t.k === r.base - 1 && packs.get(r.holder) === r.id);
        if (!run) return null;
        run.consumed = true;
        rewritten++;
        const fixed = [];
        for (let k = from.value; k < run.base; k++) fixed.push({ type: 'Name', name: `r${k}` });
        return [...fixed, unpackOf({ type: 'Name', name: run.holder })];
      };
      // the run is the last thing in an argument list, a table, a return or an assignment: it can stand for several items there
      st = rewrite(st, (n) => {
        const lastIsRange = (list) => list && list.length && expand0(list[list.length - 1]);
        const expand0 = (x) => { const y = strip(x); return y && y.type === 'Call' && isName(y.fn, 'RANGE') ? expand(y) : null; };
        if (n.type === 'Call' || n.type === 'MethodCall') {
          const e = lastIsRange(n.args);
          if (e) return { ...n, args: [...n.args.slice(0, -1), ...e] };
        } else if (n.type === 'Return' && n.values && n.values.length) {
          const e = lastIsRange(n.values);
          if (e) return { ...n, values: [...n.values.slice(0, -1), ...e] };
        } else if (n.type === 'Assign') {
          const e = lastIsRange(n.values);
          if (e) return { ...n, values: [...n.values.slice(0, -1), ...e] };
        } else if (n.type === 'Table') {
          const f = n.fields[n.fields.length - 1];
          const e = f && !f.key && expand0(f.value);
          if (e) return { ...n, fields: [...n.fields.slice(0, -1), ...e.map((x) => ({ kind: 'item', value: x }))] };
        }
        return undefined;
      });
      // a read in a single-value position
      st = rewrite(st, (n) => {
        const e = n.type === 'Call' ? expand(n) : null;
        return e ? e[0] : undefined;
      });
      if (st.type === 'Assign') {
        const facts = st.targets.map((t, k) => {
          if (t.type !== 'Name' || st.values.length !== st.targets.length) return null;
          const v = strip(st.values[k]);
          if (isPackCall(v)) return { pack: onePack.get(t.name) || nextId++ };
          if (v.type === 'Name') return { copy: v.name };
          if (v.type === 'Index' && v.key.type === 'String' && v.key.value === 'n' && isName(v.obj) && packs.has(strip(v.obj).name)) return { count: packs.get(strip(v.obj).name) };
          if (v.type === 'Binary' && (v.op === '+' || v.op === '-') && isName(v.left) && counts.has(strip(v.left).name) && strip(v.right).type === 'Number') return { top: { id: counts.get(strip(v.left).name), k: v.op === '+' ? strip(v.right).value : -strip(v.right).value } };
          if (isName(v) === false && v.type === 'Name') return null;
          return null;
        });
        const snapshot = st.targets.map((t, k) => (facts[k] && facts[k].copy !== undefined ? { packs: packs.get(facts[k].copy), counts: counts.get(facts[k].copy), tops: tops.get(facts[k].copy) } : null));
        st.targets.forEach((t, k) => {
          if (t.type !== 'Name') return;
          kill(t.name);
          const f = facts[k];
          if (!f) return;
          if (f.pack) packs.set(t.name, f.pack);
          else if (f.copy !== undefined) { const s = snapshot[k]; if (s.packs) packs.set(t.name, s.packs); if (s.counts) counts.set(t.name, s.counts); if (s.tops) tops.set(t.name, s.tops); }
          else if (f.count) counts.set(t.name, f.count);
          else if (f.top) tops.set(t.name, f.top);
        });
      } else if (st.type === 'CallStmt') {
        const c = strip(st.call);
        if (c.type === 'Call' && isName(c.fn, 'table_move') && c.args.length === 5 && isName(c.args[0]) && packs.has(strip(c.args[0]).name) && strip(c.args[1]).type === 'Number' && strip(c.args[1]).value === 1 && strip(c.args[3]).type === 'Number' && isName(c.args[4], 'M')) {
          const id = packs.get(strip(c.args[0]).name);
          const n = strip(c.args[2]);
          const countsMatch = (n.type === 'Name' && counts.get(n.name) === id) || (n.type === 'Index' && isName(n.obj, strip(c.args[0]).name) && n.key.value === 'n');
          if (countsMatch) runs.push({ id, base: strip(c.args[3]).value, holder: strip(c.args[0]).name, at: out.length, consumed: false });
        }
      } else if (st.type !== 'Local') {
        // a statement of another kind may assign names (a for loop, say): forget what is known about them
        walk(st, (x) => { if (x.type === 'Name') kill(x.name); });
      }
      out.push(st);
    });
    const dropped = new Set(runs.filter((r) => r.consumed).map((r) => r.at));
    if (dropped.size) b.stmts = out.filter((_, i) => !dropped.has(i));
    else b.stmts = out;
  }
  return rewritten;
}

// ---- copies ------------------------------------------------------------------------------------------------------------------

const PLAIN = /^(r\d+|[A-Za-z_][A-Za-z0-9_]{0,2})$/;
const plain = (n) => PLAIN.test(n) && !/^up\d/.test(n);

/**
 * Inside one block, a read of X after `X = Y` reads Y instead, until either is assigned again. The assignment is left for the dead-store
 * pass to remove once nobody reads X. Only short local names are copied: upvalues and anything a called function could change are not.
 * @returns {number} how many reads were replaced
 */
export function copyPropagate(blocks) {
  let replaced = 0;
  const pinned = capturedNames(blocks);
  for (const [bid, b] of blocks) {
    const copies = new Map();
    const sub = (node) => rewrite(node, (n) => {
      if (n.type === 'Func') return undefined;
      if (isCapture(n)) return n;
      if (n.type === 'Name' && copies.has(n.name)) { replaced++; return { ...n, name: copies.get(n.name) }; }
      return undefined;
    });
    const out = [];
    for (const st of b.stmts) {
      let cur = st;
      if (st.type === 'Assign') {
        cur = { ...st, values: sub(st.values), targets: st.targets.map((t) => (t.type === 'Name' ? t : sub(t))) };
      } else if (st.type === 'CallStmt') cur = sub(st);
      if (cur.type === 'Assign') {
        const written = cur.targets.filter((t) => t.type === 'Name').map((t) => t.name);
        for (const w of written) { copies.delete(w); for (const [k, v] of [...copies]) if (v === w) copies.delete(k); }
        if (cur.targets.length === 1 && cur.values.length === 1 && cur.targets[0].type === 'Name' && isName(cur.values[0])) {
          const x = cur.targets[0].name;
          const y = strip(cur.values[0]).name;
          if (x !== y && plain(x) && plain(y) && !((pinned.has(x) && capturedLater(blocks, bid, out.length + 1, x)) || (pinned.has(y) && capturedLater(blocks, bid, out.length + 1, y)))) copies.set(x, y);
        }
      } else if (cur.type !== 'CallStmt') copies.clear();
      out.push(cur);
    }
    b.stmts = out;
    if (b.term.kind === 'branch') b.term = { ...b.term, cond: sub(b.term.cond) };
    else if (b.term.kind === 'return' && b.term.values) b.term = { ...b.term, values: sub(b.term.values) };
  }
  return replaced;
}

/** `table.unpack(table.pack(a, b))` is `a, b`: where several values are wanted all of them, elsewhere the first. */
export function unpackPack(blocks) {
  let n = 0;
  const inner = (e) => { e = strip(e); if (e && isUnpackCall(e) && e.args.length === 1) { const p = strip(e.args[0]); if (isPackCall(p)) return p; } return null; };
  const fix = (node) => rewrite(node, (x) => {
    const spliceLast = (list) => { if (!list || !list.length) return null; const p = inner(list[list.length - 1]); return p ? [...list.slice(0, -1), ...p.args] : null; };
    if (x.type === 'Call' || x.type === 'MethodCall') { const a = spliceLast(x.args); if (a) { n++; return { ...x, args: a }; } }
    else if (x.type === 'Return' && x.values) { const a = spliceLast(x.values); if (a) { n++; return { ...x, values: a }; } }
    else if (x.type === 'Assign') {
      // the last value supplies the targets the earlier values leave over; with only one to fill, the first item is all that is taken
      const needed = x.targets.length - (x.values.length - 1);
      const p = x.values.length ? inner(x.values[x.values.length - 1]) : null;
      if (p && p.args.length) { n++; return { ...x, values: [...x.values.slice(0, -1), ...(needed >= 2 ? p.args : p.args.slice(0, 1))] }; }
    }
    else if (x.type === 'Table') { const f = x.fields[x.fields.length - 1]; const p = f && !f.key ? inner(f.value) : null; if (p) { n++; return { ...x, fields: [...x.fields.slice(0, -1), ...p.args.map((v) => ({ kind: 'item', value: v }))] }; } }
    return undefined;
  });
  const fixOne = (node) => rewrite(node, (x) => {
    const p = x.type === 'Call' ? inner(x) : null;
    if (p && p.args.length) { n++; return p.args[0]; }
    // a pack made of the unpacked values of another pack is that pack
    if (isPackCall(x) && x.args.length === 1 && isUnpackCall(x.args[0]) && strip(strip(x.args[0]).args[0]).type === 'Name') { n++; return strip(x.args[0]).args[0]; }
    return undefined;
  });
  for (const b of blocks.values()) {
    b.stmts = b.stmts.map((s) => fixOne(fix(s)));
    if (b.term.kind === 'branch') b.term = { ...b.term, cond: fixOne(fix(b.term.cond)) };
    else if (b.term.kind === 'return' && b.term.values) b.term = { ...b.term, values: fixOne(fix(b.term.values)) };
  }
  return n;
}

// ---- hashed type tests --------------------------------------------------------------------------------------------------

// MoonVeil hides `type(x) == "table"` by hashing the name: the characters of type(x) are folded into a number (first character: seed + byte,
// then h * mul + byte, all masked to 32 bits) and the number is compared with a constant. The seed and multiplier differ from site to site.
const TYPE_NAMES = ['nil', 'boolean', 'number', 'string', 'table', 'function', 'userdata', 'thread', 'vector', 'buffer'];
function typeNameFor(seed, mul, expected) {
  for (const name of TYPE_NAMES) {
    let h = 0;
    for (let i = 0; i < name.length; i++) {
      const c = name.charCodeAt(i);
      h = i === 0 ? (seed + c) >>> 0 : (Math.imul(h, mul) + c) >>> 0;
    }
    if (h === expected) return name;
  }
  return null;
}
const num = (e) => { e = strip(e); return e && e.type === 'Number' ? e.value : null; };
const callOf = (st, fnName) => {
  if (!st || st.type !== 'Assign' || st.values.length !== 1) return null;
  const c = strip(st.values[0]);
  return c.type === 'Call' && isName(c.fn, fnName) ? { st, call: c } : null;
};

/**
 * The folding loop over the characters of type(x), and the comparison of its result with a constant, become `type(x) == "name"`.
 * @returns {number} how many tests were rewritten
 */
export function typeHashTests(blocks) {
  let found = 0;
  for (const [id, b] of blocks) {
    const n = b.stmts.length;
    if (n < 4 || b.term.kind !== 'branch') continue;
    const s1 = callOf(b.stmts[n - 4], 'type');
    const s2 = callOf(b.stmts[n - 3], 'gmatch');
    const s3 = callOf(b.stmts[n - 2], 'iter');
    const s4 = b.stmts[n - 1];
    if (!s1 || !s2 || !s3 || s4.type !== 'Assign' || s4.values.length !== 1 || strip(s4.values[0]).type !== 'Call') continue;
    if (s1.st.targets[0].type !== 'Name' || s2.st.targets[0].type !== 'Name' || s4.targets[0].type !== 'Name') continue;
    const typeVar = s1.st.targets[0].name;
    if (!isName(s2.call.args[0], typeVar)) continue;
    const R = s4.targets[0].name;
    // the first test: is the string empty?
    const c0 = strip(b.term.cond);
    const emptyTarget = c0.type === 'Binary' && c0.op === '==' && isName(c0.left, R) && strip(c0.right).type === 'Nil' ? b.term.t : null;
    if (emptyTarget === null) continue;
    const first = blocks.get(b.term.f);
    if (!first || first.term.kind !== 'branch') continue;
    // first character
    const f0 = first.stmts;
    if (f0.length < 4) continue;
    const band0 = strip(f0[1].values && f0[1].values[0]);
    if (!band0 || band0.type !== 'Call' || !isName(band0.fn, 'band')) continue;
    const sum = strip(band0.args[0]);
    if (sum.type !== 'Binary' || sum.op !== '+' || num(sum.left) === null) continue;
    const seed = num(sum.left);
    const acc = f0[1].targets[0].name;
    // the loop block
    const afterFirst = first.term;
    const c1 = strip(afterFirst.cond);
    if (!(c1.type === 'Binary' && c1.op === '==' && isName(c1.left, R) && strip(c1.right).type === 'Nil')) continue;
    const done = afterFirst.t;
    const loop = blocks.get(afterFirst.f);
    if (!loop || loop.stmts.length < 4) continue;
    const band1 = strip(loop.stmts[1].values && loop.stmts[1].values[0]);
    if (!band1 || band1.type !== 'Call' || !isName(band1.fn, 'band')) continue;
    const mulExpr = strip(band1.args[0]);
    // ... the loop folds `d * mul + byte`; mul is the constant factor
    const prod = mulExpr.type === 'Binary' && mulExpr.op === '+' ? strip(mulExpr.left) : null;
    if (!prod || prod.type !== 'Binary' || prod.op !== '*' || num(prod.right) === null) continue;
    const mul = num(prod.right);
    const doneBlock = blocks.get(done);
    if (!doneBlock || doneBlock.term.kind !== 'branch' || doneBlock.stmts.length) continue;
    // `acc ~= H` (or its negation) decides between "the same" and "different"
    let cond = strip(doneBlock.term.cond);
    let negated = false;
    if (cond.type === 'Unary' && cond.op === 'not') { negated = true; cond = strip(cond.arg); }
    if (cond.type !== 'Binary' || (cond.op !== '~=' && cond.op !== '==') || !isName(cond.left, acc) || num(cond.right) === null) continue;
    const expected = num(cond.right);
    const name = typeNameFor(seed, mul, expected);
    if (!name) continue;
    const equalWhenTrue = (cond.op === '==') !== negated;
    const sameTarget = equalWhenTrue ? doneBlock.term.t : doneBlock.term.f;
    const differentTarget = equalWhenTrue ? doneBlock.term.f : doneBlock.term.t;
    if (differentTarget !== emptyTarget) continue;
    b.stmts = b.stmts.slice(0, n - 3);
    b.term = { kind: 'branch', cond: { type: 'Binary', op: '==', left: { type: 'Name', name: typeVar }, right: { type: 'String', value: name, raw: null } }, t: sameTarget, f: differentTarget };
    found++;
  }
  return found;
}

// ---- single-use temporaries ---------------------------------------------------------------------------------------------------

// Results that are known to be one value: a call to one of these can stand where a single value is wanted without parentheses.
const ONE_VALUE = /^(CLOSURE|ref|upref|FindFirstChild|FindFirstChildOfClass|FindFirstChildWhichIsA|FindFirstAncestor|FindFirstAncestorOfClass|WaitForChild|GetService|tostring|tonumber|type|typeof|new|clock|time|floor|ceil|abs|sqrt|format|sub|lower|upper|rep|len|insert_)$/;
const calleeName = (e) => {
  e = strip(e);
  if (e.type === 'MethodCall') return e.name;
  if (e.type === 'Call') { const f = strip(e.fn); if (f.type === 'Name') return f.name; if (f.type === 'Index' && f.key.type === 'String') return f.key.value; }
  return null;
};
const isCallish = (e) => { e = strip(e); return e.type === 'Call' || e.type === 'MethodCall' || e.type === 'Vararg'; };
const reads = (e) => { const out = new Set(); walk(e, (n) => { if (n.type === 'Name') out.add(n.name); }); return out; };
const effectsOrMemory = (e) => { let hit = false; walk(e, (n) => { if (n.type === 'Call' || n.type === 'MethodCall' || n.type === 'Index' || n.type === 'Vararg' || n.type === 'Func') hit = true; return !hit; }); return hit; };
const writesOf = (st) => {
  const out = new Set();
  if (st.type === 'Assign') for (const t of st.targets) if (t.type === 'Name') out.add(t.name);
  return out;
};
const storesMemory = (st) => st.type === 'Assign' && st.targets.some((t) => t.type === 'Index');

// Where, in evaluation order, `name` is read in a statement, and whether anything that could matter is evaluated before it.
function orderCheck(st, name, needQuiet) {
  let seen = false;
  let busy = false;
  let ok = true;
  let multi = false;
  const visit = (n, isMulti) => {
    if (!n || typeof n !== 'object' || seen && !ok) return;
    if (Array.isArray(n)) { n.forEach((x, i) => visit(x, isMulti && i === n.length - 1)); return; }
    if (n.type === 'Func') { if (countNames(n, name)) ok = false; return; }
    if (n.type === 'Name') { if (n.name === name) { if (busy && needQuiet) ok = false; seen = true; multi = isMulti; } return; }
    switch (n.type) {
      case 'Call': visit(n.fn, false); n.args.forEach((a, i) => visit(a, i === n.args.length - 1)); if (!seen) busy = true; else busy = busy || true; break;
      case 'MethodCall': visit(n.obj, false); n.args.forEach((a, i) => visit(a, i === n.args.length - 1)); busy = true; break;
      case 'Index': visit(n.obj, false); visit(n.key, false); if (!seen) busy = busy || false; break;
      case 'Binary': visit(n.left, false); visit(n.right, false); break;
      case 'Unary': visit(n.arg, false); break;
      case 'Paren': visit(n.expr, false); break;
      case 'Table': n.fields.forEach((f, i) => { if (f.key && typeof f.key === 'object') visit(f.key, false); visit(f.value, !f.key && i === n.fields.length - 1); }); break;
      case 'Assign': if (n.targets.some((t) => t.type === 'Index' && countNames(t, name))) ok = false; visit(n.values, n.targets.length > n.values.length); break;
      case 'CallStmt': visit(n.call, false); break;
      default: for (const k of Object.keys(n)) if (k !== 'line' && k !== 'pos') visit(n[k], false);
    }
  };
  visit(st, false);
  return { ok: ok && seen, multi };
}

/**
 * `X = E` where X is read exactly once afterwards, in the same block, and nothing in between can change what E gives (or be changed by it):
 * E goes where X was read. The registers of a lifted function hold one value at a time; this puts the values back into the expressions they
 * came from. A call substituted where several values could be taken gets parentheses, unless it is known to give one.
 * @returns {number} how many assignments were folded away
 */
export function forwardSubstitute(blocks, liveIn, keep = () => true) {
  let changed = 0;
  const succs = (t) => (t.kind === 'goto' ? [t.to] : t.kind === 'branch' ? [t.t, t.f] : []);
  const captures = capturedNames(blocks);
  const escaping = new Set();
  for (const b of blocks.values()) walk([b.stmts, b.term.cond, b.term.values], (n) => { if (n.type === 'Func') { walk(n.body, (x) => { if (x.type === 'Name') escaping.add(x.name); }); return false; } return undefined; });
  for (const [id, b] of blocks) {
    const liveOut = new Set();
    for (const m of succs(b.term)) for (const x of liveIn.get(m) || []) liveOut.add(x);
    for (let i = 0; i < b.stmts.length; i++) {
      const st = b.stmts[i];
      if (st.type !== 'Assign' || st.targets.length !== 1 || st.values.length !== 1 || st.targets[0].type !== 'Name') continue;
      const X = st.targets[0].name;
      if (escaping.has(X) || !keep(X)) continue;
      if (captures.has(X) && capturedLater(blocks, id, i + 1, X)) continue;
      const E = st.values[0];
      if (strip(E).type === 'Vararg') continue;
      const names = reads(E);
      // a variable a closure may change is as good as memory: a call in between could write it
      const heavy = effectsOrMemory(E) || [...names].some((n) => captures.has(n));
      // the single read of X: in a later statement, or in the end of the block
      let useAt = -1;
      let nReads = 0;
      let reassigned = false;
      for (let j = i + 1; j < b.stmts.length; j++) {
        const sj = b.stmts[j];
        const c = countNames(sj.type === 'Assign' ? { ...sj, targets: sj.targets.filter((t) => t.type !== 'Name') } : sj, X);
        if (c) { nReads += c; useAt = j; }
        if (nReads > 1) break;
        if (writesOf(sj).has(X)) { reassigned = true; break; }
      }
      let inTerm = false;
      if (!reassigned && nReads <= 1) {
        const tc = b.term.kind === 'branch' ? countNames(b.term.cond, X) : b.term.kind === 'return' && b.term.values ? countNames(b.term.values, X) : 0;
        if (tc) { nReads += tc; inTerm = true; useAt = b.stmts.length; }
      }
      if (nReads !== 1) continue;
      if (!reassigned && !inTerm && liveOut.has(X)) continue;
      if (!reassigned && inTerm && liveOut.has(X)) continue;
      // nothing between may disturb E
      let clean = true;
      for (let j = i + 1; j < useAt && clean; j++) {
        const sj = b.stmts[j];
        for (const w of writesOf(sj)) if (names.has(w)) clean = false;
        if (heavy && (containsEffect(sj) || storesMemory(sj))) clean = false;
      }
      if (!clean) continue;
      let multi = false;
      let target;
      if (inTerm) {
        target = b.term;
        if (b.term.kind === 'return') { multi = true; }
      } else {
        const chk = orderCheck(b.stmts[useAt], X, heavy);
        if (!chk.ok) continue;
        multi = chk.multi;
        target = b.stmts[useAt];
      }
      // a block's end that reads X and writes it is not a use we can fold into
      let expr = E;
      if (multi && isCallish(E) && !ONE_VALUE.test(calleeName(E) || '')) expr = { type: 'Paren', expr: E };
      const swap = (n) => (n.type === 'Name' && n.name === X ? expr : undefined);
      // names being assigned are not reads
      const replaced = target.type === 'Assign' ? { ...target, values: rewrite(target.values, swap), targets: target.targets.map((t) => (t.type === 'Name' ? t : rewrite(t, swap))) } : rewrite(target, swap);
      if (inTerm) b.term = replaced; else b.stmts[useAt] = replaced;
      b.stmts.splice(i, 1);
      i--;
      changed++;
    }
  }
  return changed;
}

/**
 * `X = A; if X then X = B end` is `X = A and B`; `X = A; if not X then X = B end` is `X = A or B`. That is how a register holds the value of
 * `a and b or c` while it is being worked out.
 * @returns {number} how many were joined
 */
export function shortCircuit(blocks) {
  let n = 0;
  for (let again = true; again;) {
    again = false;
    const preds = new Map();
    for (const [id, b] of blocks) {
      const t = b.term;
      for (const m of t.kind === 'goto' ? [t.to] : t.kind === 'branch' ? [t.t, t.f] : []) { if (!preds.has(m)) preds.set(m, []); preds.get(m).push(id); }
    }
    for (const [id, a] of blocks) {
      if (a.term.kind !== 'branch' || !a.stmts.length) continue;
      const last = a.stmts[a.stmts.length - 1];
      if (last.type !== 'Assign' || last.targets.length !== 1 || last.values.length !== 1 || last.targets[0].type !== 'Name') continue;
      const X = last.targets[0].name;
      let cond = strip(a.term.cond);
      let negated = false;
      if (cond.type === 'Unary' && cond.op === 'not') { negated = true; cond = strip(cond.arg); }
      if (cond.type !== 'Name') continue;
      const rhs = strip(last.values[0]);
      const viaCopy = rhs.type === 'Name' && rhs.name === cond.name;
      if (cond.name !== X && !viaCopy) continue;
      // where control goes when X is truthy, and when it is not
      const truthyTo = negated ? a.term.f : a.term.t;
      const falsyTo = negated ? a.term.t : a.term.f;
      const assignsAt = (id2, joinTo) => {
        const bb = blocks.get(id2);
        if (!bb || id2 === id || bb.term.kind !== 'goto' || bb.term.to !== joinTo || bb.stmts.length !== 1) return null;
        if ((preds.get(id2) || []).length !== 1) return null;
        const st = bb.stmts[0];
        if (st.type !== 'Assign' || st.targets.length !== 1 || st.values.length !== 1 || st.targets[0].type !== 'Name' || st.targets[0].name !== X) return null;
        return st;
      };
      // `if X then X = B end` is `X and B`; `if not X then X = B end` is `X or B`
      let op = 'and';
      let st = assignsAt(truthyTo, falsyTo);
      let thenId = truthyTo;
      let joinId = falsyTo;
      if (!st) { op = 'or'; st = assignsAt(falsyTo, truthyTo); thenId = falsyTo; joinId = truthyTo; }
      if (!st) continue;
      const bb = blocks.get(thenId);
      void bb;
      const first = viaCopy ? rhs : last.values[0];
      a.stmts[a.stmts.length - 1] = { ...last, values: [{ type: 'Binary', op, left: first, right: st.values[0], line: last.line }] };
      a.term = { kind: 'goto', to: joinId };
      blocks.delete(thenId);
      n++;
      again = true;
      break;
    }
  }
  return n;
}

/** `table_move(M, a, b, c, T)` copies registers a..b into T from index c: that is T[c] = r<a>, ..., written out. */
export function setList(blocks) {
  let n = 0;
  for (const b of blocks.values()) {
    b.stmts = b.stmts.map((st) => {
      if (st.type !== 'CallStmt') return st;
      const c = strip(st.call);
      if (c.type !== 'Call' || !isName(c.fn, 'table_move') || c.args.length !== 5 || !isName(c.args[0], 'M') || !isName(c.args[4])) return st;
      const [a, z, from] = [strip(c.args[1]), strip(c.args[2]), strip(c.args[3])];
      if (a.type !== 'Number' || z.type !== 'Number' || from.type !== 'Number' || z.value < a.value || z.value - a.value > 200) return st;
      const T = strip(c.args[4]);
      const targets = [];
      const values = [];
      for (let k = a.value; k <= z.value; k++) {
        targets.push({ type: 'Index', obj: T, key: { type: 'Number', value: from.value + k - a.value, raw: null }, dot: false });
        values.push({ type: 'Name', name: `r${k}` });
      }
      n++;
      return { type: 'Assign', targets, values, line: st.line };
    });
  }
  return n;
}

/**
 * `T = {}` followed by stores into T, in order, is a table constructor: `T = { Title = x, Author = y, "a", "b" }`. Stops at the first statement that is
 * not such a store, or whose value reads T.
 * @returns {number} how many constructors were filled
 */
export function foldTableInit(blocks) {
  let n = 0;
  const ident = /^[A-Za-z_][A-Za-z0-9_]*$/;
  for (const b of blocks.values()) {
    for (let i = 0; i < b.stmts.length; i++) {
      const st = b.stmts[i];
      if (st.type !== 'Assign' || st.targets.length !== 1 || st.values.length !== 1 || st.targets[0].type !== 'Name') continue;
      const v = strip(st.values[0]);
      if (v.type !== 'Table') continue;
      const T = st.targets[0].name;
      const fields = [...v.fields];
      let arrayLen = fields.filter((f) => f.kind === 'item').length;
      let j = i + 1;
      for (; j < b.stmts.length; j++) {
        const sj = b.stmts[j];
        if (sj.type !== 'Assign' || sj.targets.length !== 1 || sj.values.length !== 1 || sj.targets[0].type !== 'Index') break;
        const t = sj.targets[0];
        if (!isName(t.obj, T) || countNames(sj.values, T) || countNames(t.key, T)) break;
        const key = strip(t.key);
        if (key.type === 'String' && ident.test(key.value) && !fields.some((f) => f.kind === 'named' && f.key === key.value)) fields.push({ kind: 'named', key: key.value, value: sj.values[0] });
        else if (key.type === 'Number' && key.value === arrayLen + 1 && fields.every((f) => f.kind === 'item' || f.kind === 'named')) { fields.push({ kind: 'item', value: sj.values[0] }); arrayLen++; }
        else break;
      }
      if (j === i + 1) continue;
      // positional items must come before the named ones that follow them only for readability: Lua accepts any order
      b.stmts.splice(i, j - i, { ...st, values: [{ ...v, fields }] });
      n++;
    }
  }
  return n;
}

/** `f = o.name; f(o, ...)` written as one expression is `o:name(...)`. */
export function methodSugar(blocks) {
  let n = 0;
  const fix = (node) => rewrite(node, (x) => {
    if (x.type !== 'Call') return undefined;
    const f = strip(x.fn);
    if (f.type !== 'Index' || f.key.type !== 'String' || !/^[A-Za-z_][A-Za-z0-9_]*$/.test(f.key.value) || !x.args.length) return undefined;
    const o = strip(f.obj);
    const a0 = strip(x.args[0]);
    if (o.type !== 'Name' && o.type !== 'Index') return undefined;
    if (JSON.stringify(stripPos(o)) !== JSON.stringify(stripPos(a0))) return undefined;
    n++;
    return { type: 'MethodCall', obj: f.obj, name: f.key.value, args: x.args.slice(1), sugar: null, line: x.line };
  });
  for (const b of blocks.values()) {
    b.stmts = b.stmts.map(fix);
    if (b.term.kind === 'branch') b.term = { ...b.term, cond: fix(b.term.cond) };
    else if (b.term.kind === 'return' && b.term.values) b.term = { ...b.term, values: fix(b.term.values) };
  }
  return n;
}
const stripPos = (e) => (Array.isArray(e) ? e.map(stripPos) : e && typeof e === 'object' ? Object.fromEntries(Object.entries(e).filter(([k]) => k !== 'line' && k !== 'pos' && k !== 'endPos' && k !== 'endLine' && k !== 'raw').map(([k, v]) => [k, stripPos(v)])) : e);

// ---- single-use packs ---------------------------------------------------------------------------------------------------

/**
 * `T = table.pack(C)` whose only use is `table.unpack(T)` (in the same block, with nothing in between that could be affected) is C, in place.
 * When T is not used at all, the call stands on its own.
 * @param {Map} blocks
 * @param {Map<any, Set<string>>} liveIn  names live on entry to every block (cfg-opt's liveness)
 * @returns {number} how many packs were removed
 */
export function inlineTemps(blocks, liveIn) {
  let changed = 0;
  const succs = (t) => (t.kind === 'goto' ? [t.to] : t.kind === 'branch' ? [t.t, t.f] : []);
  for (const b of blocks.values()) {
    const liveOut = new Set();
    for (const m of succs(b.term)) for (const x of liveIn.get(m) || []) liveOut.add(x);
    for (let i = 0; i < b.stmts.length; i++) {
      const st = b.stmts[i];
      if (st.type !== 'Assign' || st.targets.length !== 1 || st.targets[0].type !== 'Name' || st.values.length !== 1) continue;
      const T = st.targets[0].name;
      const v = strip(st.values[0]);
      if (!isPackCall(v) || v.args.length !== 1) continue;
      const inner = strip(v.args[0]);
      if (inner.type !== 'Call' && inner.type !== 'MethodCall') continue;
      // find the end of T's life in this block
      let end = b.stmts.length;
      let uses = 0;
      let useAt = -1;
      let other = false;
      for (let j = i + 1; j < b.stmts.length; j++) {
        const sj = b.stmts[j];
        const c = countNames(sj.type === 'Assign' ? { ...sj, targets: sj.targets.filter((t) => t.type !== 'Name') } : sj, T);
        if (c) {
          uses += c;
          useAt = j;
          let viaUnpack = 0;
          walk(sj, (x) => { if (isUnpackCall(x) && x.args.length === 1 && isName(x.args[0], T)) viaUnpack++; });
          if (viaUnpack !== c) other = true;
        }
        if (sj.type === 'Assign' && sj.targets.some((t) => t.type === 'Name' && t.name === T)) { end = j; break; }
      }
      const diesHere = end < b.stmts.length;
      if (!diesHere && liveOut.has(T)) continue;
      if (other) continue;
      // the end of the block may read it too (a `return table.unpack(T)`, a test)
      let inTerm = false;
      if (!diesHere) {
        const tc = b.term.kind === 'branch' ? countNames(b.term.cond, T) : b.term.kind === 'return' && b.term.values ? countNames(b.term.values, T) : 0;
        if (tc) {
          let viaUnpack = 0;
          walk(b.term.kind === 'branch' ? b.term.cond : b.term.values, (x) => { if (isUnpackCall(x) && x.args.length === 1 && isName(x.args[0], T)) viaUnpack++; });
          if (viaUnpack !== tc) continue;
          uses += tc;
          useAt = b.stmts.length;
          inTerm = true;
        }
      }
      if (uses === 0) {
        b.stmts[i] = { type: 'CallStmt', call: inner, line: st.line };
        changed++;
        continue;
      }
      if (uses !== 1) continue;
      // nothing between the pack and its use may do anything the call could depend on or change
      let clean = true;
      for (let j = i + 1; j < useAt; j++) if (containsEffect(b.stmts[j]) || b.stmts[j].type !== 'Assign') clean = false;
      if (!clean) continue;
      const swap = (x) => (isUnpackCall(x) && x.args.length === 1 && isName(x.args[0], T) ? inner : undefined);
      if (inTerm) b.term = b.term.kind === 'branch' ? { ...b.term, cond: rewrite(b.term.cond, swap) } : { ...b.term, values: rewrite(b.term.values, swap) };
      else b.stmts[useAt] = rewrite(b.stmts[useAt], swap);
      b.stmts.splice(i, 1);
      i--;
      changed++;
    }
  }
  return changed;
}
