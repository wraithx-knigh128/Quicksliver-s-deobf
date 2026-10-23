// Decoder evaluation through the sandbox.
//
// String-decoding schemes (Caesar shifts, seed decryptors, constant arrays behind an accessor, ...)
// share one shape: an expression built from constants, calls to a decoder defined near the top of the
// script, and the tables that decoder reads. Such an expression has the same value wherever it is
// evaluated, so it can be replaced by that value.
//
// Safety, in the order it is enforced:
//   * only a *decoder* is ever evaluated: a top-level function called with constant arguments at many
//     sites (the program's own logic, `gcd(84, 36)`, is deliberately left alone);
//   * the code that is run is the smallest slice of the top-level code that defines what the
//     expressions depend on, in original order so state is mutated exactly as it would be;
//   * the slice may reference nothing but untouched standard globals;
//   * it runs in the sandbox interpreter (no host access) under fuel, time and depth limits;
//   * every expression is evaluated twice, forward and in reverse order, and only results that agree
//     are used. A decoder with hidden state (a call counter, say) would not agree.

import { walk, transform, forEachChild } from '../core/walk.js';
import { analyze, STDLIB_GLOBALS } from '../core/scope.js';
import { createMachine, classify } from '../sandbox/sandbox.js';
import { compileAst, callValue } from '../sandbox/interp.js';
import { LuaTable } from '../sandbox/value.js';
import { constOf, makeConst, PURE_LIBS } from './fold.js';
import { NOT_CONST } from './consteval.js';
import { looksObfuscated, isShortName } from './rename.js';

const PURE_GLOBAL_FUNCS = new Set(['tostring', 'tonumber', 'type', 'select', 'unpack']);

/** A function must be called this often, with constant arguments, to count as a decoder... */
const MIN_SITES = 4;
/** ...or this often when its name is not obviously machine generated. */
const MIN_SITES_READABLE_NAME = 12;

const rn = (name) => ({ type: 'Name', name });

export function evaluatePass(chunk, ctx = {}) {
  const opts = ctx.sandbox || {};
  const result = { changed: 0, sites: 0, evaluated: 0, rejected: 0, decoders: [], skipped: null, error: null };
  if (!opts.enabled) { result.skipped = 'sandboxed evaluation is not enabled'; return result; }

  const info = analyze(chunk);
  const top = chunk.body;
  const minSites = opts.minSites ?? MIN_SITES;

  // ---- top-level definitions ---------------------------------------------------------------
  const declOf = new Map(); // Var -> declaring top-level statement
  for (const s of top) {
    if (s.type === 'Local') s.ids.forEach((id) => declOf.set(info.varOf.get(id), s));
    else if (s.type === 'LocalFunction') declOf.set(info.varOf.get(s.id), s);
  }
  if (declOf.size === 0) { result.skipped = 'no top-level definitions'; return result; }

  const refCache = new Map();
  const refsOf = (node) => {
    if (refCache.has(node)) return refCache.get(node);
    const vars = new Set();
    const globals = new Set();
    walk(node, (n) => {
      if (n.type !== 'Name') return;
      const v = info.varOf.get(n);
      if (!v) return;
      if (v.isGlobal) globals.add(n.name); else vars.add(v);
    });
    const r = { vars, globals };
    refCache.set(node, r);
    return r;
  };

  // A top-level statement can be run in the sandbox if all it needs is standard globals and
  // other runnable top-level definitions.
  const foreignGlobal = (s) => [...refsOf(s).globals].find((g) => !STDLIB_GLOBALS.has(g)) || null;
  const viable = new Set(declOf.keys());
  const settle = (consumers) => {
    for (let changed = true; changed;) {
      changed = false;
      for (const v of [...viable]) {
        const s = declOf.get(v);
        const r = refsOf(s);
        if (foreignGlobal(s) || [...r.vars].some((w) => declOf.has(w) && !viable.has(w) && !(s.type === 'Local' && s.ids.some((id) => info.varOf.get(id) === w)) && !(s.type === 'LocalFunction' && info.varOf.get(s.id) === w))) {
          viable.delete(v);
          changed = true;
        }
      }
      // code that mutates a decoder's tables must be runnable too, otherwise its state is unknown
      for (const s of top) {
        if (consumers.has(s) || s.type === 'Return' || declOf.get(s) !== undefined) continue;
        const r = refsOf(s);
        const touched = [...r.vars].filter((v) => viable.has(v));
        if (!touched.length) continue;
        const bad = foreignGlobal(s) || [...r.vars].some((v) => declOf.has(v) && !viable.has(v));
        if (bad) { touched.forEach((v) => viable.delete(v)); changed = true; }
      }
    }
  };

  // ---- closed expressions ------------------------------------------------------------------
  const memo = new Map();
  const closed = (e) => {
    if (memo.has(e)) return memo.get(e);
    let r = { ok: false, call: false };
    switch (e.type) {
      case 'Nil': case 'True': case 'False': case 'Number': case 'String': r = { ok: true, call: false }; break;
      case 'Name': {
        const v = info.varOf.get(e);
        const std = v && v.isGlobal && v.writes.length === 0 && (PURE_LIBS.has(e.name) || PURE_GLOBAL_FUNCS.has(e.name));
        r = { ok: std || viable.has(v), call: false };
        break;
      }
      case 'Paren': r = closed(e.expr); break;
      case 'Unary': r = closed(e.arg); break;
      case 'Binary': { const a = closed(e.left); const b = closed(e.right); r = { ok: a.ok && b.ok, call: a.call || b.call }; break; }
      case 'IfExpr': { const c = [closed(e.cond), closed(e.then), closed(e.orelse)]; r = { ok: c.every((x) => x.ok), call: c.some((x) => x.call) }; break; }
      case 'Index': {
        const a = closed(e.obj);
        const b = e.key.type === 'String' ? { ok: true, call: false } : closed(e.key);
        r = { ok: a.ok && b.ok, call: a.call || b.call };
        break;
      }
      case 'Call': { const f = closed(e.fn); const args = e.args.map(closed); r = { ok: f.ok && args.every((x) => x.ok), call: true }; break; }
      case 'MethodCall': { const o = closed(e.obj); const args = e.args.map(closed); r = { ok: o.ok && args.every((x) => x.ok), call: true }; break; }
      case 'Table': {
        const parts = e.fields.map((f) => (f.kind === 'keyed' ? [closed(f.key), closed(f.value)] : [closed(f.value)])).flat();
        r = { ok: parts.every((x) => x.ok), call: parts.some((x) => x.call) };
        break;
      }
      default: break;
    }
    memo.set(e, r);
    return r;
  };

  const SITE_TYPES = new Set(['Call', 'MethodCall', 'Index', 'Binary', 'Paren', 'Unary']);
  const collectSites = () => {
    const found = [];
    const owner = new Map();
    for (const stmt of top) {
      const visit = (e) => {
        if (!e || typeof e !== 'object') return;
        if (SITE_TYPES.has(e.type)) {
          const c = closed(e);
          if (c.ok && c.call && constOf(e) === NOT_CONST) { found.push(e); owner.set(e, stmt); return; }
        }
        forEachChild(e, visit);
      };
      visit(stmt);
    }
    return { found, owner };
  };

  // Settle viability against the statements that consume decoder output, until stable.
  let sites;
  let owner;
  for (let round = 0; round < 6; round++) {
    memo.clear();
    ({ found: sites, owner } = collectSites());
    const before = viable.size;
    settle(new Set(owner.values()));
    if (viable.size === before) break;
  }
  memo.clear();
  ({ found: sites, owner } = collectSites());

  // ---- which called functions behave like decoders? ----------------------------------------------
  const callTargets = (site) => {
    const out = new Set();
    walk(site, (n) => {
      if (n.type === 'Call' && n.fn.type === 'Name') {
        const v = info.varOf.get(n.fn);
        if (v && viable.has(v)) out.add(v);
      }
    });
    return out;
  };
  // `local function get(i) return ARRAY[i - 17] end` is an array accessor whatever type it returns.
  const accessorShaped = new Set();
  for (const [v, st] of declOf) {
    const f = st.type === 'LocalFunction' ? st.func : (st.type === 'Local' && st.values.length === 1 && st.ids.length === 1 ? st.values[0] : null);
    if (f && f.type === 'Func' && f.body.length === 1 && f.body[0].type === 'Return' && f.body[0].values.length === 1) {
      const r = f.body[0].values[0];
      if (r.type === 'Index' && r.obj.type === 'Name' && viable.has(info.varOf.get(r.obj))) accessorShaped.add(v);
    }
  }
  const siteCount = new Map();
  for (const s of sites) for (const v of callTargets(s)) siteCount.set(v, (siteCount.get(v) || 0) + 1);
  const decoders = new Set();
  for (const [v, n] of siteCount) {
    const threshold = looksObfuscated(v.name) || isShortName(v.name) ? minSites : (opts.minSitesReadable ?? MIN_SITES_READABLE_NAME);
    if (n >= threshold) decoders.add(v);
  }
  result.decoders = [...decoders].map((v) => ({ name: v.name, sites: siteCount.get(v) }));
  if (!decoders.size) { result.skipped = 'no decoder-like function calls with constant arguments'; return result; }

  // The sites to replace are the decoder calls themselves (and `table[decode(...)]` lookups), never
  // a larger expression that merely contains one: the program's own logic must stay visible.
  const isDecoderCall = (e) => {
    if (e.type !== 'Call' || e.fn.type !== 'Name') return false;
    const v = info.varOf.get(e.fn);
    return decoders.has(v) && closed(e).ok;
  };
  const noCall = (e) => { const c = closed(e); return c.ok && !c.call; };
  const unparen = (e) => (e.type === 'Paren' ? unparen(e.expr) : e);
  sites = [];
  owner = new Map();
  for (const stmt of top) {
    const visit = (e) => {
      if (!e || typeof e !== 'object') return;
      let hit = false;
      if (e.type === 'Index' && e.key.type !== 'String' && isDecoderCall(unparen(e.key)) && noCall(e.obj)) hit = true;
      else if (isDecoderCall(e)) hit = true;
      if (hit) { sites.push(e); owner.set(e, stmt); return; }
      forEachChild(e, visit);
    };
    visit(stmt);
  }
  result.sites = sites.length;
  if (!sites.length) { result.skipped = 'no decoder calls with closed arguments'; return result; }

  // ---- dependency slice -------------------------------------------------------------------------------
  const consumer = new Set(sites.map((e) => owner.get(e)));
  const deps = new Set();
  for (const e of sites) for (const v of refsOf(e).vars) if (declOf.has(v)) deps.add(v);
  const slice = new Set();
  for (let grew = true; grew;) {
    grew = false;
    for (const s of top) {
      if (slice.has(s) || s.type === 'Return') continue;
      const r = refsOf(s);
      const declares = declOf.get(s) === undefined && s.type !== 'Local' && s.type !== 'LocalFunction'
        ? []
        : (s.type === 'Local' ? s.ids.map((id) => info.varOf.get(id)) : [info.varOf.get(s.id)]);
      const declaresDep = declares.some((v) => deps.has(v));
      const mutatesDep = !consumer.has(s) && s.type !== 'Local' && s.type !== 'LocalFunction' && [...r.vars].some((v) => deps.has(v));
      if (declaresDep || mutatesDep) {
        slice.add(s);
        grew = true;
        for (const v of r.vars) if (declOf.has(v)) deps.add(v);
        for (const v of declares) deps.add(v);
      }
    }
  }
  const byName = new Map();
  for (const v of deps) {
    if (byName.has(v.name) && byName.get(v.name) !== v) { result.skipped = `two top-level variables are both called '${v.name}'`; return result; }
    byName.set(v.name, v);
  }
  for (const s of slice) {
    const g = foreignGlobal(s);
    if (g) { result.skipped = `the decoder depends on '${g}', whose value is not known here`; return result; }
  }
  for (const e of sites) {
    const g = [...refsOf(e).globals].find((x) => !STDLIB_GLOBALS.has(x));
    if (g) { result.skipped = `an expression depends on '${g}', whose value is not known here`; return result; }
  }

  // ---- synthetic chunk ------------------------------------------------------------------------------------
  const ids = new Map(sites.map((e, i) => [e, i + 1]));
  const wrap = (e, k) => ({
    type: 'Assign',
    targets: [{ type: 'Index', obj: rn('__qs_r'), key: { type: 'Number', value: k, raw: String(k) }, dot: false }],
    values: [{ type: 'Table', fields: [{ kind: 'item', value: {
      type: 'Call', fn: rn('pcall'),
      args: [{ type: 'Func', params: [], vararg: false, isMethod: false, body: [{ type: 'Return', values: [e] }] }],
    } }] }],
  });
  const perStmt = new Map();
  for (const e of sites) {
    const s = owner.get(e);
    if (!perStmt.has(s)) perStmt.set(s, []);
    perStmt.get(s).push(e);
  }
  const body = [{ type: 'Local', ids: [{ type: 'Id', name: '__qs_r' }], values: [{ type: 'Table', fields: [] }] }];
  for (const s of top) {
    if (perStmt.has(s)) for (const e of perStmt.get(s)) body.push(wrap(e, ids.get(e)));
    if (slice.has(s)) body.push(s);
  }
  const n = sites.length;
  for (const e of [...sites].reverse()) body.push(wrap(e, ids.get(e) + n));
  body.push({ type: 'Return', values: [rn('__qs_r')] });
  const synthetic = { type: 'Chunk', body, endComments: [], features: new Set() };

  const m = createMachine({ fuel: opts.fuel ?? 60_000_000, timeMs: opts.timeMs ?? 10_000, dialect: opts.dialect || 'luau' });
  let table;
  try {
    table = callValue(m, compileAst(m, synthetic, 'decoder', m.globals), [], '')[0];
  } catch (e) {
    const c = classify(e);
    result.error = c.error || 'evaluation failed';
    result.skipped = `sandbox: ${result.error}`;
    return result;
  }
  if (!(table instanceof LuaTable)) { result.skipped = 'the sandbox returned no results'; return result; }

  // ---- accept consistent results --------------------------------------------------------------------------
  const accepted = new Map();
  const single = (t) => t instanceof LuaTable && t.get(1) === true && t.get(3) === undefined;
  const usable = (v) => typeof v === 'string' || typeof v === 'boolean' || (typeof v === 'number' && Number.isFinite(v));
  const perDecoder = new Map(); // Var -> { strings, others }
  const decoderOf = (e) => { let found = null; walk(e, (n) => { if (!found && n.type === 'Call' && n.fn.type === 'Name' && decoders.has(info.varOf.get(n.fn))) found = info.varOf.get(n.fn); }); return found; };
  const candidates = [];
  for (const e of sites) {
    const a = table.get(ids.get(e));
    const b = table.get(ids.get(e) + n);
    if (!single(a) || !single(b) || a.get(2) !== b.get(2) || !usable(a.get(2))) { result.rejected++; continue; }
    const v = decoderOf(e);
    const tally = perDecoder.get(v) || { strings: 0, others: 0 };
    if (typeof a.get(2) === 'string') tally.strings++; else tally.others++;
    perDecoder.set(v, tally);
    candidates.push([e, a.get(2), v]);
  }
  // A decoder yields text; a helper that mostly returns numbers is program logic, not a decoder.
  for (const [e, value, v] of candidates) {
    const t = perDecoder.get(v);
    const stringy = t.strings / (t.strings + t.others) >= 0.75;
    if (stringy || accessorShaped.has(v)) accepted.set(e, value); else result.rejected++;
  }
  if (accepted.size) {
    transform(chunk, { expr(e) { return accepted.has(e) ? makeConst(accepted.get(e)) : undefined; } });
    result.changed = accepted.size;
    result.removedStatements = removeSpentDecoder(chunk, slice, deps);
    result.changed += result.removedStatements;
  }
  result.evaluated = accepted.size;
  return result;
}

/**
 * After the decoder calls are gone, the slice that implemented the decoder is dead weight, unless
 * something outside it (a call that could not be evaluated, say) still refers to it. Keep exactly the
 * slice statements that are still reachable from outside the slice; delete the rest.
 */
function removeSpentDecoder(chunk, slice, deps) {
  const info = analyze(chunk);
  const depVars = new Set();
  for (const v of deps) { const nv = info.varOf.get(v.decl); if (nv) depVars.add(nv); }
  const varsIn = (node) => {
    const out = new Set();
    walk(node, (n) => { if (n.type === 'Name') { const v = info.varOf.get(n); if (v && depVars.has(v)) out.add(v); } });
    return out;
  };
  const declaredBy = (s) => (s.type === 'Local' ? s.ids.map((id) => info.varOf.get(id)) : s.type === 'LocalFunction' ? [info.varOf.get(s.id)] : []);

  const live = new Set();
  for (const s of chunk.body) if (!slice.has(s)) for (const v of varsIn(s)) live.add(v);
  const keep = new Set();
  for (let grew = true; grew;) {
    grew = false;
    for (const s of slice) {
      if (keep.has(s)) continue;
      const refs = varsIn(s);
      const declares = declaredBy(s);
      const touchesLive = declares.some((v) => live.has(v)) || (declares.length === 0 && [...refs].some((v) => live.has(v)));
      if (!touchesLive) continue;
      keep.add(s);
      grew = true;
      for (const v of refs) live.add(v);
    }
  }
  const before = chunk.body.length;
  chunk.body = chunk.body.filter((s) => !slice.has(s) || keep.has(s));
  return before - chunk.body.length;
}
