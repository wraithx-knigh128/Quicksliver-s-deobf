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
//     are used. A decoder with hidden state (a call counter, say) would not agree;
//   * the sandbox computes with doubles (Lua 5.1 / Luau). Lua 5.4 integers are exact up to 2^63, so a decoder that
//     multiplies past 2^53 gives different text on the two. The run counts such results; when there are any, the slice is
//     run again with 5.4 integers and the two are compared: equal results are used, different ones only when exactly one
//     of the two reads as text (see chooseArithmetic), otherwise those sites are left alone.

import { walk, transform, forEachChild } from '../core/walk.js';
import { analyze, STDLIB_GLOBALS } from '../core/scope.js';
import { createMachine, classify } from '../sandbox/sandbox.js';
import { readsAsText } from '../sandbox/numeric.js';
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

/**
 * Replaces decoder calls with the text they produce. A `table[decode(...)]` lookup is tried as a whole first; when it has no value to
 * give (`class[decode('__index')] = class` assigns to it, or the table is filled in later) the constant key inside it is still worth
 * having, so a second run offers the remaining keys on their own.
 */
export function evaluatePass(chunk, ctx = {}) {
  const first = evaluateOnce(chunk, ctx);
  if (!first.indexRejected || ctx.keysOnly) return first;
  // what remains are a few calls of the decoder found the first time; a function called once with constant arguments is not a decoder
  const second = evaluateOnce(chunk, { ...ctx, keysOnly: true, knownDecoders: new Set(first.decoders.map((d) => d.name)) });
  if (second.skipped) return first;
  first.changed += second.changed;
  first.evaluated += second.evaluated;
  first.rejected += second.rejected;
  first.sites += second.sites;
  first.removedStatements = (first.removedStatements || 0) + (second.removedStatements || 0);
  for (const d of second.decoders) if (!first.decoders.some((x) => x.name === d.name)) first.decoders.push(d);
  return first;
}

/**
 * The same sites evaluated with doubles (`floats`) and with Lua 5.4 integers (`ints`): both are tables of `[ok, value]` pairs
 * per site number. Returns the sites whose value is trustworthy as `{ use: 'float'|'integer', unresolved: Set(site numbers) }`.
 * Where the two agree there is nothing to decide. Where they differ, the text of one reads as text and the other as noise
 * for nearly every differing site: that is evidence for the runtime the script was made for, and the answer says which.
 */
function chooseArithmetic(floats, ints, count) {
  const differ = [];
  for (let k = 1; k <= count; k++) {
    const a = floats(k);
    const b = ints(k);
    if (a.ok !== b.ok || (a.ok && a.value !== b.value)) differ.push([a, b]);
  }
  if (!differ.length) return { use: 'float', differing: 0, unresolved: new Set() };
  const text = (r) => r.ok && typeof r.value === 'string' && readsAsText(r.value);
  const strings = differ.filter(([a, b]) => (a.ok && typeof a.value === 'string') || (b.ok && typeof b.value === 'string'));
  const floatText = strings.filter(([a]) => text(a)).length;
  const intText = strings.filter(([, b]) => text(b)).length;
  // noise passes the text test by chance about once in three bytes, so a verdict needs a dozen bytes to rest on
  const enough = strings.reduce((n, [a, b]) => n + Math.max((a.ok && typeof a.value === 'string' && a.value.length) || 0, (b.ok && typeof b.value === 'string' && b.value.length) || 0), 0) >= 12;
  if (enough && intText >= 0.9 * strings.length && floatText <= 0.34 * strings.length) return { use: 'integer', differing: differ.length, unresolved: new Set() };
  if (enough && floatText >= 0.9 * strings.length && intText <= 0.34 * strings.length) return { use: 'float', differing: differ.length, unresolved: new Set() };
  return { use: null, differing: differ.length, unresolved: null };
}

function evaluateOnce(chunk, ctx = {}) {
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
  const offsetAccessor = new Set();
  for (const [v, st] of declOf) {
    const f = st.type === 'LocalFunction' ? st.func : (st.type === 'Local' && st.values.length === 1 && st.ids.length === 1 ? st.values[0] : null);
    if (f && f.type === 'Func' && f.body.length === 1 && f.body[0].type === 'Return' && f.body[0].values.length === 1) {
      const r = f.body[0].values[0];
      if (r.type === 'Index' && r.obj.type === 'Name' && viable.has(info.varOf.get(r.obj))) {
        accessorShaped.add(v);
        // `list[n - 5296]`: the offset that a constant-array scheme hides its indices behind. Ordinary code indexes by the parameter itself.
        const k = r.key;
        if (k.type === 'Binary' && (k.op === '+' || k.op === '-') && ((k.left.type === 'Name' && k.right.type === 'Number') || (k.left.type === 'Number' && k.right.type === 'Name' && k.op === '+'))) offsetAccessor.add(v);
      }
    }
  }
  const siteCount = new Map();
  for (const s of sites) for (const v of callTargets(s)) siteCount.set(v, (siteCount.get(v) || 0) + 1);
  // `s = (s * 1103515245 + 12345) % 2147483648` inside a function: a linear-congruential keystream, the core of a string decryptor. Such a
  // function is a decoder from its first call; a script with one or two hidden strings has no more call sites than that.
  const keystream = new Set();
  for (const [v, st] of declOf) {
    const f = st.type === 'LocalFunction' ? st.func : st.type === 'Local' && st.values.length === 1 && st.ids.length === 1 ? st.values[0] : null;
    if (!f || f.type !== 'Func') continue;
    const seen = new Set();
    walk(f.body, (n) => { if (n.type === 'Number' && (n.value === 1103515245 || n.value === 2147483648)) seen.add(n.value); return undefined; });
    if (seen.size === 2) keystream.add(v);
  }
  const decoders = new Set();
  for (const [v, n] of siteCount) {
    const machineName = looksObfuscated(v.name) || isShortName(v.name);
    const threshold = (ctx.knownDecoders && ctx.knownDecoders.has(v.name)) || (offsetAccessor.has(v) && machineName) || keystream.has(v) ? 1 : machineName ? minSites : (opts.minSitesReadable ?? MIN_SITES_READABLE_NAME);
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
  // the environment table (`local env = getfenv and getfenv() or _ENV`) is indexed with decoded names all over a program, but a
  // lookup in it yields a function: never a decoder result, and not a table whose state the slice has to reproduce
  const envLike = (e) => {
    const x = e.type === 'Paren' ? e.expr : e;
    if (x.type !== 'Name') return false;
    const v = info.varOf.get(x);
    const st = v && declOf.get(v);
    if (!st || st.type !== 'Local') return false;
    let hit = false;
    walk(st, (n) => { if (n.type === 'Name' && (n.name === 'getfenv' || n.name === '_ENV' || n.name === '_G')) { const w = info.varOf.get(n); if (w && w.isGlobal) hit = true; } });
    return hit;
  };
  const noCall = (e) => { const c = closed(e); return c.ok && !c.call && !envLike(e); };
  const unparen = (e) => (e.type === 'Paren' ? unparen(e.expr) : e);
  sites = [];
  owner = new Map();
  const late = new Set();       // sites inside a function body: they run when the function is called, after the set-up
  for (const stmt of top) {
    const visit = (e, inFunc = false) => {
      if (!e || typeof e !== 'object') return;
      let hit = false;
      if (!ctx.keysOnly && e.type === 'Index' && e.key.type !== 'String' && isDecoderCall(unparen(e.key)) && noCall(e.obj)) hit = true;
      else if (isDecoderCall(e)) hit = true;
      if (hit) { sites.push(e); owner.set(e, stmt); if (inFunc) late.add(e); return; }
      forEachChild(e, (c) => visit(c, inFunc || e.type === 'Func'));
    };
    visit(stmt);
  }
  result.sites = sites.length;
  if (!sites.length) { result.skipped = 'no decoder calls with closed arguments'; return result; }

  // a table of constants (the array a constant-array scheme keeps its strings in)
  const dataTable = (v) => {
    const st = declOf.get(v);
    if (!st || st.type !== 'Local') return false;
    const i = st.ids.findIndex((id) => info.varOf.get(id) === v);
    const init = i >= 0 ? st.values[i] : null;
    return !!init && init.type === 'Table' && init.fields.length >= 2
      && init.fields.every((f) => f.kind !== 'keyed' && ['String', 'Number', 'True', 'False', 'Nil'].includes(f.value.type));
  };

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
      // `local a = list`: a second name for a table the decoder reads, through which it may be changed as well
      const aliasesDep = s.type === 'Local' && s.values.length === s.ids.length
        && s.values.some((x) => x.type === 'Name' && deps.has(info.varOf.get(x)) && dataTable(info.varOf.get(x)));
      const declaresDep = declares.some((v) => deps.has(v)) || aliasesDep;
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
    if (perStmt.has(s)) for (const e of perStmt.get(s)) if (!late.has(e)) body.push(wrap(e, ids.get(e)));
    if (slice.has(s)) body.push(s);
  }
  for (const e of sites) if (late.has(e)) body.push(wrap(e, ids.get(e)));
  const n = sites.length;
  for (const e of [...sites].reverse()) body.push(wrap(e, ids.get(e) + n));
  body.push({ type: 'Return', values: [rn('__qs_r')] });
  const synthetic = { type: 'Chunk', body, endComments: [], features: new Set() };

  const execute = (numMode) => {
    const m = createMachine({ fuel: opts.fuel ?? 60_000_000, timeMs: opts.timeMs ?? 10_000, dialect: opts.dialect || 'luau', numMode });
    const t = callValue(m, compileAst(m, synthetic, 'decoder', m.globals), [], '')[0];
    return { table: t, loss: m.precisionLoss };
  };
  let table;
  let precisionLoss = 0;
  try {
    ({ table, loss: precisionLoss } = execute('watch'));
  } catch (e) {
    const c = classify(e);
    result.error = c.error || 'evaluation failed';
    result.skipped = `sandbox: ${result.error}`;
    return result;
  }
  if (!(table instanceof LuaTable)) { result.skipped = 'the sandbox returned no results'; return result; }

  // Some arithmetic went past 2^53, where doubles and Lua 5.4 integers disagree: run again with integers and compare.
  const unresolved = new Set();
  if (precisionLoss > 0) {
    let ints = null;
    try { ints = execute('int64').table; } catch { ints = null; } // a sandbox limit, or a library call that cannot take a 64-bit integer
    const pair = (t, k) => {
      const a = t instanceof LuaTable ? t.get(k) : undefined;
      const b = t instanceof LuaTable ? t.get(k + sites.length) : undefined;
      return a instanceof LuaTable && b instanceof LuaTable && a.get(1) === true && a.get(3) === undefined && b.get(1) === true && b.get(2) === a.get(2) ? { ok: true, value: a.get(2) } : { ok: false };
    };
    if (!(ints instanceof LuaTable)) {
      result.arithmetic = { note: 'some arithmetic leaves the range doubles hold exactly (Lua 5.1/Luau and Lua 5.4 would give different text) and the integer rerun did not finish', differing: null };
      for (let k = 1; k <= sites.length; k++) unresolved.add(k);
    } else {
      const verdict = chooseArithmetic((k) => pair(table, k), (k) => pair(ints, k), sites.length);
      if (verdict.use === 'integer') { table = ints; result.arithmetic = { use: 'Lua 5.4 integers', differing: verdict.differing }; } else if (verdict.use === 'float') result.arithmetic = { use: 'doubles', differing: verdict.differing };
      else {
        result.arithmetic = { use: null, differing: verdict.differing, note: 'the text depends on the Lua version and neither reading is clearly text' };
        for (let k = 1; k <= sites.length; k++) { if (pair(table, k).ok !== pair(ints, k).ok || pair(table, k).value !== pair(ints, k).value) unresolved.add(k); }
      }
    }
  }

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
    if (unresolved.has(ids.get(e)) || !single(a) || !single(b) || a.get(2) !== b.get(2) || !usable(a.get(2))) { result.rejected++; continue; }
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
    // a text decoder's number results are keys into a table it fills as a side effect; the call has to stay
    if (accessorShaped.has(v) || (stringy && typeof value === 'string')) accepted.set(e, value);
    else if (!stringy) result.notDecoder = (result.notDecoder || 0) + 1; // mostly numbers: the program's own helper, not a decoder that failed
    else result.rejected++;
  }
  if (accepted.size) {
    transform(chunk, { expr(e) { return accepted.has(e) ? makeConst(accepted.get(e)) : undefined; } });
    // a decoder called only for its side effect leaves a constant where the statement was; nothing is left to run
    const isConst = (e) => e && (e.type === 'Number' || e.type === 'String' || e.type === 'True' || e.type === 'False' || e.type === 'Nil');
    transform(chunk, { block(stmts) { return stmts.some((st) => st.type === 'CallStmt' && isConst(st.call)) ? stmts.filter((st) => !(st.type === 'CallStmt' && isConst(st.call))) : undefined; } });
    result.changed = accepted.size;
    result.removedStatements = removeSpentDecoder(chunk, slice, deps);
    result.changed += result.removedStatements;
  }
  result.evaluated = accepted.size;
  result.indexRejected = sites.filter((e) => e.type === 'Index' && !accepted.has(e)).length;
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
