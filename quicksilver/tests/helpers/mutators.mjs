// A small obfuscator for tests: independent program transformations of the kinds custom obfuscators apply.
//
// The adaptive engine is meant to recover structure it has no family rule for, so its tests need obfuscated programs that nothing in the
// engine was written against. These transformations are written from the outside, against the AST and the scope analysis only (never the
// engine's strategies), and each one comes in several encodings so that a test cannot pass by matching one fixed shape:
//
//   flatten      control flow into a dispatch loop: if/elseif chain, binary-search tree or sequential ifs; the next state as a literal, a
//                delta from the current one, or a choice; exit by sentinel or by break; locals hoisted
//   strings      string literals behind a decoder: an indexed table of shifted bytes, or byte lists decoded where they are used
//   opaque       branches guarded by predicates that arithmetic settles
//   proxies      operators and calls behind small local functions, one or two layers deep
//   junk         statements that do nothing
//   rename       locals renamed to machine-looking names
//   wrap         the whole script inside `return (function(...) ... end)(...)`
//
// Every transformation keeps the program's behaviour, which the tests check on a real Lua.

import { parse } from '../../src/core/parser.js';
import { print } from '../../src/core/printer.js';
import { walk, clone, transform } from '../../src/core/walk.js';
import { analyze } from '../../src/core/scope.js';

export function rng(seed) {
  let a = seed >>> 0;
  const next = () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  return { next, int: (lo, hi) => lo + Math.floor(next() * (hi - lo + 1)), pick: (xs) => xs[Math.floor(next() * xs.length)], shuffle: (xs) => { const o = [...xs]; for (let i = o.length - 1; i > 0; i--) { const j = Math.floor(next() * (i + 1)); [o[i], o[j]] = [o[j], o[i]]; } return o; } };
}

const N = (value) => ({ type: 'Number', value, raw: null });
const S = (value) => ({ type: 'String', value, raw: null });
const Nm = (name) => ({ type: 'Name', name });
const Id = (name) => ({ type: 'Id', name });
const B = (op, left, right) => ({ type: 'Binary', op, left, right });
const Call = (fn, args) => ({ type: 'Call', fn, args });
const Assign = (targets, values) => ({ type: 'Assign', targets, values });
const Local = (names, values = []) => ({ type: 'Local', ids: names.map(Id), values });
const If = (cond, body, orelse = null) => ({ type: 'If', clauses: [{ cond, body }], orelse });
const Ret = (...values) => ({ type: 'Return', values });
const Idx = (obj, key) => ({ type: 'Index', obj, key, dot: false });

const parseSrc = (src) => parse(src);
const printAst = (ast) => print(ast, { indent: '  ', width: 120, strings: 'preserve', numbers: 'preserve' });

let uid = 0;
const fresh = (stem) => `${stem}__${++uid}`;

// ---- unique names ------------------------------------------------------------------------------------------------------------

/** Rename every local to a name no other local has, so that moving declarations around cannot change what a name means. */
function uniquify(ast) {
  const info = analyze(ast);
  for (const v of info.vars) {
    if (!v.decl || (v.kind === 'param' && v.name === 'self')) continue;   // the implicit `self` of a method is declared by the language
    const nm = fresh(v.name.replace(/__\d+$/, ''));
    for (const n of [v.decl, ...v.reads, ...v.writes]) if (n) n.name = nm;
  }
  return ast;
}

// ---- flattening ---------------------------------------------------------------------------------------------------------------

class Lowering {
  constructor() { this.blocks = []; this.heads = []; this.loops = []; this.extra = 0; }
  block() { const b = { stmts: [], term: null }; this.blocks.push(b); return b; }
  hoist(names) { for (const n of names) if (!this.heads.includes(n)) this.heads.push(n); }

  /** Lower statements into `cur`; returns the block control continues in, or null when the path ended. */
  stmts(list, cur) {
    for (const st of list) {
      if (!cur) return null;
      cur = this.stmt(st, cur);
    }
    return cur;
  }

  stmt(st, cur) {
    switch (st.type) {
      case 'Local': {
        this.hoist(st.ids.map((i) => i.name));
        if (st.values.length) cur.stmts.push(Assign(st.ids.map((i) => Nm(i.name)), st.values));
        else cur.stmts.push(Assign(st.ids.map((i) => Nm(i.name)), st.ids.map(() => ({ type: 'Nil' }))));
        return cur;
      }
      case 'LocalFunction':
        this.hoist([st.id.name]);
        cur.stmts.push(Assign([Nm(st.id.name)], [st.func]));
        return cur;
      case 'Assign': case 'CallStmt': case 'CompoundAssign': case 'Function':
        cur.stmts.push(st);
        return cur;
      case 'Do': return this.stmts(st.body, cur);
      case 'Return': cur.term = { k: 'return', values: st.values }; return null;
      case 'Break': {
        const loop = this.loops[this.loops.length - 1];
        cur.term = { k: 'goto', to: loop.exit };
        return null;
      }
      case 'If': {
        const join = this.block();
        let test = cur;
        let any = false;
        for (const c of st.clauses) {
          const t = this.block();
          const f = this.block();
          test.term = { k: 'branch', cond: c.cond, t, f };
          const end = this.stmts(c.body, t);
          if (end) { end.term = { k: 'goto', to: join }; any = true; }
          test = f;
        }
        if (st.orelse) { const end = this.stmts(st.orelse, test); if (end) { end.term = { k: 'goto', to: join }; any = true; } } else { test.term = { k: 'goto', to: join }; any = true; }
        return any ? join : null;
      }
      case 'While': {
        const head = this.block();
        const body = this.block();
        const exit = this.block();
        cur.term = { k: 'goto', to: head };
        head.term = { k: 'branch', cond: st.cond, t: body, f: exit };
        this.loops.push({ exit });
        const end = this.stmts(st.body, body);
        this.loops.pop();
        if (end) end.term = { k: 'goto', to: head };
        return exit;
      }
      case 'Repeat': {
        const body = this.block();
        const exit = this.block();
        cur.term = { k: 'goto', to: body };
        this.loops.push({ exit });
        const end = this.stmts(st.body, body);
        this.loops.pop();
        if (end) end.term = { k: 'branch', cond: st.cond, t: exit, f: body };
        return exit;
      }
      case 'NumFor': {
        const v = st.id.name;
        const lim = fresh('lim');
        const stp = fresh('stp');
        const ctr = fresh('ctr');
        this.hoist([v, lim, stp, ctr]);
        cur.stmts.push(Assign([Nm(ctr), Nm(lim), Nm(stp)], [st.start, st.stop, st.step || N(1)]));
        const head = this.block();
        const body = this.block();
        const exit = this.block();
        cur.term = { k: 'goto', to: head };
        const cond = B('or', B('and', B('>', Nm(stp), N(0)), B('<=', Nm(ctr), Nm(lim))), B('and', B('<=', Nm(stp), N(0)), B('>=', Nm(ctr), Nm(lim))));
        head.term = { k: 'branch', cond, t: body, f: exit };
        body.stmts.push(Assign([Nm(v)], [Nm(ctr)]));
        this.loops.push({ exit });
        const end = this.stmts(st.body, body);
        this.loops.pop();
        if (end) { end.stmts.push(Assign([Nm(ctr)], [B('+', Nm(ctr), Nm(stp))])); end.term = { k: 'goto', to: head }; }
        return exit;
      }
      case 'GenFor': {
        const f = fresh('it');
        const s = fresh('st');
        const c = fresh('ct');
        const names = st.ids.map((i) => i.name);
        this.hoist([f, s, c, ...names]);
        cur.stmts.push(Assign([Nm(f), Nm(s), Nm(c)], st.exprs));
        const head = this.block();
        const body = this.block();
        const exit = this.block();
        cur.term = { k: 'goto', to: head };
        head.stmts.push(Assign(names.map(Nm), [Call(Nm(f), [Nm(s), Nm(c)])]));
        head.term = { k: 'branch', cond: B('~=', Nm(names[0]), { type: 'Nil' }), t: body, f: exit };
        body.stmts.push(Assign([Nm(c)], [Nm(names[0])]));
        this.loops.push({ exit });
        const end = this.stmts(st.body, body);
        this.loops.pop();
        if (end) end.term = { k: 'goto', to: head };
        return exit;
      }
      default: throw new Error(`cannot lower ${st.type}`);
    }
  }
}

const hasClosureInLoop = (body) => {
  let hit = false;
  const visit = (n, inLoop) => {
    if (hit || !n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach((x) => visit(x, inLoop)); return; }
    const loop = inLoop || ['While', 'Repeat', 'NumFor', 'GenFor'].includes(n.type);
    if (n.type === 'Func' && inLoop) { hit = true; return; }
    if (n.type === 'Func') { visit(n.body, false); return; }
    for (const k of Object.keys(n)) if (k !== 'line' && n[k] && typeof n[k] === 'object') visit(n[k], loop);
  };
  visit(body, false);
  return hit;
};

const supported = (body) => {
  let ok = true;
  const visit = (n) => {
    if (!ok || !n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(visit); return; }
    if (n.type === 'Func') return;
    if (['Goto', 'Label', 'Continue', 'TypeAlias', 'CompoundAssign'].includes(n.type)) { ok = false; return; }
    for (const k of ['body', 'orelse']) if (n[k]) visit(n[k]);
    if (n.clauses) n.clauses.forEach((c) => visit(c.body));
  };
  visit(body);
  return ok;
};

/**
 * @param {string} source
 * @param {{seed?: number, style?: 'chain'|'tree'|'seq', next?: 'literal'|'delta'|'choice', exit?: 'sentinel'|'break', minStatements?: number}} [o]
 */
export function flatten(source, o = {}) {
  const r = rng(o.seed ?? 1);
  const ast = uniquify(parseSrc(source));
  const style = o.style || r.pick(['chain', 'tree', 'seq']);
  const nextMode = o.next || r.pick(['literal', 'delta', 'choice']);
  const exitMode = o.exit || r.pick(['sentinel', 'break']);
  let count = 0;

  const rebuild = (body) => {
    const low = new Lowering();
    const entry = low.block();
    const last = low.stmts(body, entry);
    const end = last || null;
    if (end) end.term = { k: 'exit' };
    const ascending = [];
    for (let x = r.int(10, 40), i = 0; i < low.blocks.length; i++, x += r.int(1, 9)) ascending.push(x);
    const ids = r.shuffle(ascending);
    const idOf = new Map(low.blocks.map((b, i) => [b, ids[i]]));
    const st = fresh('st');
    const EXIT = 1;
    const jump = (from, to) => {
      const target = to === 'exit' ? EXIT : idOf.get(to);
      if (nextMode === 'delta' && to !== 'exit') return Assign([Nm(st)], [B('+', Nm(st), N(target - idOf.get(from)))]);
      return Assign([Nm(st)], [N(target)]);
    };
    const gotoStmt = (from, to) => (to === 'exit' && exitMode === 'break' ? { type: 'Break' } : jump(from, to));
    const bodies = low.blocks.map((b) => {
      const stmts = [...b.stmts];
      const t = b.term;
      if (t.k === 'goto') stmts.push(gotoStmt(b, t.to));
      else if (t.k === 'exit') stmts.push(gotoStmt(b, 'exit'));
      else if (t.k === 'return') stmts.push(Ret(...t.values));
      else if (t.k === 'branch') {
        if (nextMode === 'choice') stmts.push(Assign([Nm(st)], [B('or', B('and', t.cond, N(idOf.get(t.t))), N(idOf.get(t.f)))]));
        else stmts.push(If(t.cond, [jump(b, t.t)], [jump(b, t.f)]));
      }
      return stmts;
    });
    const order = r.shuffle(low.blocks.map((_, i) => i));
    let selection;
    if (style === 'seq') {
      selection = order.map((i) => If(B('==', Nm(st), N(ids[i])), bodies[i]));
    } else if (style === 'tree') {
      const sorted = [...order].sort((a, b) => ids[a] - ids[b]);
      const build = (lo, hi) => {
        if (lo === hi) return bodies[sorted[lo]];
        const mid = (lo + hi) >> 1;
        return [If(B('<=', Nm(st), N(ids[sorted[mid]])), build(lo, mid), build(mid + 1, hi))];
      };
      selection = build(0, sorted.length - 1);
    } else {
      const clauses = order.map((i) => ({ cond: B('==', Nm(st), N(ids[i])), body: bodies[i] }));
      selection = [{ type: 'If', clauses, orelse: null }];
    }
    const cond = exitMode === 'sentinel' ? B('~=', Nm(st), N(EXIT)) : { type: 'True' };
    const loop = { type: 'While', cond, body: selection };
    const heads = low.heads.length ? [Local(low.heads)] : [];
    return [...heads, Local([st], [N(idOf.get(entry))]), loop];
  };

  const visitOnce = (fn) => {
    const count0 = fn.body.length;
    if (count0 < (o.minStatements ?? 3) || !supported(fn.body) || hasClosureInLoop(fn.body)) return;
    // a function that uses `...` keeps it: the dispatcher is in the same function
    try { fn.body = rebuild(fn.body); count++; } catch { /* a statement the lowering does not know: leave the function alone */ }
  };
  // the walk lists a function before the ones inside it: reversed, the inner ones are rebuilt first
  const funcs = [];
  walk(ast, (n) => { if (n.type === 'Func') funcs.push(n); return undefined; });
  for (const f of funcs.reverse()) visitOnce(f);
  const topCount = ast.body.length;
  if (topCount >= (o.minStatements ?? 3) && supported(ast.body) && !hasClosureInLoop(ast.body) && o.top !== false) {
    try { ast.body = rebuild(ast.body); count++; } catch { /* leave it */ }
  }
  return { code: printAst(ast), flattened: count };
}

// ---- strings -----------------------------------------------------------------------------------------------------------------

const byteEscape = (bytes) => bytes.map((b) => String.fromCharCode(b)).join('');

/**
 * @param {string} source
 * @param {{seed?: number, scheme?: 'indexed'|'inline'}} [o]
 */
export function strings(source, o = {}) {
  const r = rng(o.seed ?? 1);
  const ast = parseSrc(source);
  const scheme = o.scheme || r.pick(['indexed', 'inline']);
  const key = r.int(3, 90);
  const offset = r.int(100, 4000);
  const table = fresh('E');
  const dec = fresh('D');
  const enc = (s) => { const out = []; for (let i = 0; i < s.length; i++) out.push((s.charCodeAt(i) + key + i + 1) % 256); return out; };
  const encoded = [];
  const skip = new WeakSet();
  walk(ast, (nd) => {
    if (nd.type === 'Index' && nd.key.type === 'String' && nd.dot) skip.add(nd.key);
    if (nd.type === 'Function' && nd.target.type === 'Index') skip.add(nd.target.key);
    return undefined;
  });
  transform(ast, {
    expr(e) {
      if (e.type !== 'String' || skip.has(e) || e.value.length < 2) return undefined;
      const bytes = enc(e.value);
      if (scheme === 'indexed') {
        encoded.push(bytes);
        return Call(Nm(dec), [N(encoded.length + offset)]);
      }
      return Call(Nm(dec), [{ type: 'Table', fields: bytes.map((b) => ({ kind: 'item', value: N(b) })) }]);
    },
  });
  const decoderIndexed = parseSrc(`
local ${table} = {}
local function ${dec}(i)
  local s = ${table}[i - ${offset}]
  local r = {}
  for j = 1, #s do
    r[j] = string.char((s:byte(j) - ${key} - j) % 256)
  end
  return table.concat(r)
end`).body;
  const decoderInline = parseSrc(`
local function ${dec}(t)
  local r = {}
  for j = 1, #t do
    r[j] = string.char((t[j] - ${key} - j) % 256)
  end
  return table.concat(r)
end`).body;
  if (scheme === 'indexed') {
    // the table is filled by one constructor, so it is a plain table of byte strings
    decoderIndexed[0] = Local([table], [{ type: 'Table', fields: encoded.map((bytes) => ({ kind: 'item', value: S(byteEscape(bytes)) })) }]);
    ast.body = [...decoderIndexed, ...ast.body];
  } else {
    ast.body = [...decoderInline, ...ast.body];
  }
  return { code: printAst(ast), strings: encoded.length };
}

// ---- opaque predicates -------------------------------------------------------------------------------------------------------

const PREDICATES = {
  true: [
    (x) => B('>=', B('*', x(), x()), N(0)),
    (x) => B('==', B('%', B('+', B('*', x(), x()), x()), N(2)), N(0)),
    (x) => B('==', B('%', B('+', B('*', N(7), x()), N(1)), N(7)), N(1)),
    (x) => B('==', B('%', B('*', x(), B('+', x(), N(1))), N(2)), N(0)),
    (x) => B('==', x(), x()),
  ],
  false: [
    (x) => B('<', B('*', x(), x()), N(0)),
    (x) => B('==', B('%', B('*', x(), x()), N(4)), N(2)),
    (x) => B('~=', B('%', B('*', x(), B('+', x(), N(1))), N(2)), N(0)),
    (x) => B('~=', x(), x()),
  ],
};

/** @param {{seed?: number, density?: number}} [o] */
export function opaque(source, o = {}) {
  const r = rng(o.seed ?? 1);
  const density = o.density ?? 0.4;
  const ast = parseSrc(source);
  const wrapList = (list, vars) => {
    const out = [];
    for (const st of list) {
      // one variable per predicate: the identities hold for a variable, not for two different ones
      const v = r.pick(vars);
      const x = () => Nm(v);
      if (st.type === 'CallStmt' && r.next() < density) {
        out.push(If(r.pick(PREDICATES.true)(x), [st], [Local([fresh('j')], [N(r.int(1, 99))])]));
      } else if (st.type === 'Assign' && r.next() < density) {
        out.push(If(r.pick(PREDICATES.true)(x), [st], [Assign([Nm(fresh('g'))], [N(r.int(1, 9))])]));
      } else if (r.next() < density / 2) {
        out.push(If(r.pick(PREDICATES.false)(x), [Assign([Nm(fresh('g'))], [N(r.int(1, 9))])]));
        out.push(st);
      } else out.push(st);
    }
    return out;
  };
  const doBody = (fnBody) => {
    const vars = [fresh('q'), fresh('q')];
    const decl = Local(vars, vars.map(() => N(r.int(3, 40))));
    return [decl, ...wrapList(fnBody, vars)];
  };
  const funcs = [];
  walk(ast, (n) => { if (n.type === 'Func') funcs.push(n); return undefined; });
  for (const f of funcs) f.body = doBody(f.body);
  ast.body = doBody(ast.body);
  return { code: printAst(ast) };
}

// ---- proxies -----------------------------------------------------------------------------------------------------------------

const OPS = ['+', '-', '*', '..', '==', '<', '<='];

/** @param {{seed?: number, layers?: number}} [o] */
export function proxies(source, o = {}) {
  const r = rng(o.seed ?? 1);
  const ast = parseSrc(source);
  const names = new Map();
  const prelude = [];
  const proxyFor = (op) => {
    if (names.has(op)) return names.get(op);
    const nm = fresh('P');
    names.set(op, nm);
    prelude.push(parseSrc(`local function ${nm}(a, b) return a ${op} b end`).body[0]);
    if ((o.layers ?? 1) > 1) {
      const outer = fresh('Q');
      prelude.push(parseSrc(`local function ${outer}(a, b) return ${nm}(a, b) end`).body[0]);
      names.set(op, outer);
      return outer;
    }
    return nm;
  };
  transform(ast, {
    expr(e) {
      if (e.type === 'Binary' && OPS.includes(e.op) && r.next() < 0.8) return Call(Nm(proxyFor(e.op)), [e.left, e.right]);
      return undefined;
    },
  });
  const constants = new Map();
  transform(ast, {
    expr(e) {
      if (e.type === 'Number' && Number.isInteger(e.value) && e.value >= 0 && e.value < 1000 && r.next() < 0.3) {
        let nm = constants.get(e.value);
        if (!nm) { nm = fresh('K'); constants.set(e.value, nm); prelude.push(parseSrc(`local function ${nm}() return ${e.value} end`).body[0]); }
        return Call(Nm(nm), []);
      }
      return undefined;
    },
  });
  ast.body = [...prelude, ...ast.body];
  return { code: printAst(ast) };
}

// ---- junk, names, wrapper ----------------------------------------------------------------------------------------------------

export function junk(source, o = {}) {
  const r = rng(o.seed ?? 1);
  const ast = parseSrc(source);
  const sprinkle = (list) => {
    const out = [];
    for (const st of list) {
      if (r.next() < 0.3) out.push(Local([fresh('z')], [N(r.int(0, 999))]));
      if (r.next() < 0.15) out.push({ type: 'Do', body: [Local([fresh('z')], [S('junk')])] });
      out.push(st);
    }
    return out;
  };
  const funcs = [];
  walk(ast, (n) => { if (n.type === 'Func') funcs.push(n); return undefined; });
  for (const f of funcs) f.body = sprinkle(f.body);
  ast.body = sprinkle(ast.body);
  return { code: printAst(ast) };
}

export function rename(source, o = {}) {
  const r = rng(o.seed ?? 1);
  const ast = parseSrc(source);
  const info = analyze(ast);
  const alphabet = ['I', 'l', '1', 'O', '0'];
  const used = new Set();
  for (const v of info.vars) {
    if (!v.decl || (v.kind === 'param' && v.name === 'self')) continue;
    let nm;
    do { nm = `l${Array.from({ length: 5 }, () => r.pick(alphabet)).join('')}`; } while (used.has(nm));
    used.add(nm);
    for (const n of [v.decl, ...v.reads, ...v.writes]) if (n) n.name = nm;
  }
  return { code: printAst(ast) };
}

export function wrap(source) {
  const ast = parseSrc(source);
  const fn = { type: 'Func', params: [], vararg: true, body: ast.body, isMethod: false };
  ast.body = [Ret(Call({ type: 'Paren', expr: fn }, [{ type: 'Vararg' }]))];
  return { code: printAst(ast) };
}

export const MUTATORS = { flatten, strings, opaque, proxies, junk, rename, wrap };

/**
 * Apply a list of transformations in order. Each entry is a name or [name, options].
 * @returns {{code: string, applied: string[]}}
 */
export function obfuscate(source, steps, seed = 1) {
  let code = source;
  const applied = [];
  steps.forEach((step, i) => {
    const [name, opts] = Array.isArray(step) ? step : [step, {}];
    const out = MUTATORS[name](code, { seed: seed * 101 + i, ...opts });
    code = out.code;
    applied.push(name);
  });
  void clone;
  return { code, applied };
}
