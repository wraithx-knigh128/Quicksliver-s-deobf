// Closed-region evaluation.
//
// Some obfuscators decrypt every string where it is used, with the routine written out in place:
//
//     c = ""; t = {}; for j = 0, 255 do t[string.char(j)] = j ... end
//     key = "\19\83..."; for i = 1, #enc do c = c .. t[xor(...)] end        -- c is now the plain text
//
// Nothing in such a stretch of code depends on anything but constants, so what it leaves behind is a constant too.
// This pass finds the stretches, runs them, and writes the result instead:  c = "Hello, QuickSilver!"
//
// What makes it safe is the shape of the code, checked before anything runs, and the machine it runs on:
//
//   * a *run* is a series of consecutive statements that touch only (a) locals no closure captured, whose value is
//     either a known constant or is set earlier in the run, and (b) a short list of pure standard functions
//     (string.*, math.* without random, table.concat/insert/remove/unpack, tostring, tonumber, select, type, ...);
//   * it contains no function definition, no `return`, no `goto`, no write to a global and no call of anything else;
//   * it runs in the sandbox interpreter, which has no host access, under a small fuel and time budget;
//   * only the variables that are still read after the run are written back, and only if their value is a number,
//     a string, a boolean or nil. A run that leaves a table or a function behind is not replaced.
//
// So the pass can only replace code by the constant that code computes. It does not run the script.

import { analyze } from '../core/scope.js';
import { walk, clone } from '../core/walk.js';
import { createMachine, classify } from '../sandbox/sandbox.js';
import { compileAst, callValue } from '../sandbox/interp.js';
import { makeConst, constOf } from './fold.js';
import { NOT_CONST } from './consteval.js';
import { Liveness, Unsupported, trackerWithCaptured, captureExposure, childBlocks, writtenIn, functionUnits, hasJumps } from './dataflow.js';

const SAFE_GLOBAL_FUNCS = new Set(['select', 'tostring', 'tonumber', 'type', 'unpack', 'ipairs', 'pairs', 'next', 'rawget', 'rawequal']);
const SAFE_MEMBERS = {
  string: new Set(['byte', 'char', 'find', 'format', 'gmatch', 'gsub', 'len', 'lower', 'match', 'rep', 'reverse', 'sub', 'upper']),
  math: new Set(['abs', 'acos', 'asin', 'atan', 'atan2', 'ceil', 'cos', 'cosh', 'deg', 'exp', 'floor', 'fmod', 'frexp', 'huge', 'ldexp', 'log', 'log10', 'max', 'min', 'modf', 'pi', 'pow', 'rad', 'sin', 'sinh', 'sqrt', 'tan', 'tanh']),
  table: new Set(['concat', 'insert', 'remove', 'unpack', 'getn', 'maxn']),
};

const FUEL = 4_000_000;
const TIME_MS = 750;
const MAX_RESULT_STRING = 1 << 16;

/** Static check of a run: which variables it needs, which it sets, whether it computes anything. */
class Run {
  constructor(info, v, known) {
    this.info = info;
    this.v = v;
    this.known = known;
    this.defined = new Set();     // variables with a value at this point of the run
    this.assigned = new Set();    // variables the run writes (declared or assigned)
    this.topLocals = new Set();   // declared by a `local` directly in the run (their scope continues after it)
    this.inner = new Set();       // declared inside a nested block or loop of the run (gone when it ends)
    this.needs = new Set();       // known variables the run reads
    this.worth = false;
    this.hasLoop = false;
    this.depth = 0;
    this.loops = 0;
  }

  snapshot() { return [new Set(this.defined), new Set(this.assigned), new Set(this.topLocals), new Set(this.needs), new Set(this.inner), this.worth, this.hasLoop]; }
  restore([d, a, t, n, i, w, l]) { this.defined = d; this.assigned = a; this.topLocals = t; this.needs = n; this.inner = i; this.worth = w; this.hasLoop = l; }

  /** Can statement `s` join the run? On failure the state is left as it was. */
  tryStmt(s) {
    const saved = this.snapshot();
    let ok;
    try { ok = this.stmt(s); } catch (e) { if (e === FAIL) ok = false; else throw e; }
    if (!ok) this.restore(saved);
    return ok;
  }

  declare(id, top) {
    const x = this.v(id);
    if (!x || id.attrib) throw FAIL;
    this.defined.add(x);
    if (top) { this.assigned.add(x); this.topLocals.add(x); } else this.inner.add(x);
  }

  stmt(s) {
    switch (s.type) {
      case 'Local':
        if (!s.values.length) throw FAIL;     // `local a, b, c` lists are declarations, not computations
        s.values.forEach((e) => this.expr(e));
        s.ids.forEach((id) => this.declare(id, this.depth === 0));
        return true;
      case 'Assign':
        s.values.forEach((e) => this.expr(e));
        for (const t of s.targets) {
          if (t.type === 'Name') {
            const x = this.v(t);
            if (!x) throw FAIL;
            this.defined.add(x);
            if (!this.inner.has(x)) this.assigned.add(x);
          } else if (t.type === 'Index') {
            this.expr(t.obj);
            if (!(t.key.type === 'String' && t.dot)) this.expr(t.key);
            if (t.obj.type === 'Name' && !this.v(t.obj)) throw FAIL;   // never write into a global table
          } else throw FAIL;
        }
        return true;
      case 'CompoundAssign':
        this.expr(s.target);
        this.expr(s.value);
        if (s.target.type === 'Name' && !this.inner.has(this.v(s.target))) this.assigned.add(this.v(s.target));
        return true;
      case 'CallStmt': this.expr(s.call); return true;
      case 'Do': return this.block(s.body);
      case 'If':
        for (const c of s.clauses) { this.expr(c.cond); this.block(c.body); }
        if (s.orelse) this.block(s.orelse);
        return true;
      case 'While': this.loops++; this.worth = true; this.hasLoop = true; this.expr(s.cond); this.block(s.body); this.loops--; return true;
      case 'Repeat': this.loops++; this.worth = true; this.hasLoop = true; this.depth++; s.body.forEach((x) => this.stmt(x)); this.expr(s.cond); this.depth--; this.loops--; return true;
      case 'NumFor':
        this.loops++; this.worth = true; this.hasLoop = true;
        this.expr(s.start); this.expr(s.stop); if (s.step) this.expr(s.step);
        this.depth++; this.declare(s.id, false); s.body.forEach((x) => this.stmt(x)); this.depth--;
        this.loops--;
        return true;
      case 'GenFor':
        this.loops++; this.worth = true; this.hasLoop = true;
        s.exprs.forEach((e) => this.expr(e));
        this.depth++; s.ids.forEach((id) => this.declare(id, false)); s.body.forEach((x) => this.stmt(x)); this.depth--;
        this.loops--;
        return true;
      case 'Break': if (!this.loops) throw FAIL; return true;
      default: throw FAIL;
    }
  }

  block(stmts) { this.depth++; stmts.forEach((x) => this.stmt(x)); this.depth--; return true; }

  expr(e) {
    switch (e.type) {
      case 'Nil': case 'True': case 'False': case 'Number': case 'String': return;
      case 'Name': {
        const x = this.v(e);
        const g = this.info.varOf.get(e);
        if (x) {
          if (this.defined.has(x)) return;
          if (this.known.has(x)) { this.needs.add(x); return; }
          throw FAIL;
        }
        // a captured local, or a global used as a value: only the plain function names are allowed
        if (g && g.isGlobal && g.writes.length === 0 && SAFE_GLOBAL_FUNCS.has(e.name)) return;
        throw FAIL;
      }
      case 'Index': {
        const root = e.obj.type === 'Name' ? this.info.varOf.get(e.obj) : null;
        if (root && root.isGlobal) {
          const members = SAFE_MEMBERS[e.obj.name];
          if (!members || root.writes.length || e.key.type !== 'String' || !members.has(e.key.value)) throw FAIL;
          return;
        }
        this.expr(e.obj);
        if (!(e.key.type === 'String' && e.dot)) this.expr(e.key);
        return;
      }
      case 'Call': this.worth = true; this.expr(e.fn); e.args.forEach((a) => this.expr(a)); return;
      case 'MethodCall': this.worth = true; this.expr(e.obj); e.args.forEach((a) => this.expr(a)); return;
      case 'Table': for (const f of e.fields) { if (f.kind === 'keyed') this.expr(f.key); this.expr(f.value); } return;
      case 'Binary': this.expr(e.left); this.expr(e.right); return;
      case 'Unary': this.expr(e.arg); return;
      case 'Paren': this.expr(e.expr); return;
      case 'IfExpr': this.expr(e.cond); this.expr(e.then); this.expr(e.orelse); return;
      default: throw FAIL;
    }
  }
}

const FAIL = Symbol('not a closed run');

/** Value computed by the sandbox -> literal node, or null when it cannot be written down exactly. */
function literal(value) {
  if (value === undefined || value === true || value === false) return makeConst(value);
  if (typeof value === 'number') return Number.isFinite(value) && !Object.is(value, -0) ? makeConst(value) : null;
  if (typeof value === 'string') return value.length <= MAX_RESULT_STRING ? makeConst(value) : null;
  return null;
}

/**
 * Run statements [i, j) of `stmts` and return { values: Map<Var, node> } for `wanted`, or null if anything about the run
 * is not exactly what the checker promised.
 */
const debug = (...a) => { if (typeof process !== 'undefined' && process.env && process.env.QS_DEBUG_REGIONS) console.error('regions:', ...a); };

function execute(stmts, i, j, run, wanted, known, v) {
  const names = new Map();      // name -> Var, to rule out two variables sharing a name inside the synthetic function
  const bind = (x) => { const old = names.get(x.name); if (old && old !== x) { debug('two variables named', x.name); return false; } names.set(x.name, x); return true; };
  const header = [];
  const headerVars = [];
  for (const x of run.needs) { if (!bind(x)) return null; headerVars.push(x); header.push({ type: 'Id', name: x.name }); }
  const bare = [];
  for (const x of run.assigned) {
    if (run.topLocals.has(x) || run.needs.has(x)) continue;
    if (!bind(x)) return null;
    bare.push({ type: 'Id', name: x.name });
  }
  for (const x of wanted) if (!bind(x)) return null;
  const body = [];
  if (header.length) body.push({ type: 'Local', ids: header, values: headerVars.map((x) => clone(known.get(x))) });
  if (bare.length) body.push({ type: 'Local', ids: bare, values: [] });
  for (let k = i; k < j; k++) body.push(clone(stmts[k]));
  body.push({ type: 'Return', values: wanted.map((x) => ({ type: 'Name', name: x.name })) });

  const m = createMachine({ fuel: FUEL, timeMs: TIME_MS, dialect: 'lua51' });
  let out;
  try {
    const fn = compileAst(m, { type: 'Chunk', body, endComments: [], features: new Set() }, 'region', m.globals);
    out = callValue(m, fn, [], '');
  } catch (e) {
    let why = String(e && e.message);
    try { const c = classify(e); why = c.error || why; } catch { /* an interpreter fault is not a reason to fail the whole recovery */ }
    if (typeof process !== 'undefined' && process.env && process.env.QS_DEBUG_REGIONS) console.error('region failed:', why);
    return null;
  }
  const values = new Map();
  for (let k = 0; k < wanted.length; k++) {
    const lit = literal(out[k]);
    if (!lit) { debug('result of', wanted[k].name, 'is', typeof out[k]); return { offender: wanted[k] }; }
    values.set(wanted[k], lit);
  }
  void v;
  return { values };
}

/**
 * @returns {{changed: number, regions: number, rejected: number}}
 */
export function regionPass(chunk) {
  const stats = { changed: 0, regions: 0, rejected: 0 };
  for (let round = 0; round < 4; round++) {
    const before = stats.regions;
    const info = analyze(chunk);
    const v = trackerWithCaptured(info);
    for (const { body, params } of functionUnits(chunk, info)) {
      if (hasJumps(body)) continue;
      const exposure = captureExposure(body, info, params);
      const after = new Map();
      try { new Liveness(info, v, { record: after, exposure }).block(body, new Set()); } catch (e) { if (e instanceof Unsupported) continue; throw e; }
      processBlock(body, new Map(), { info, v, after, stats, exposure });
    }
    if (stats.regions === before) break;
  }
  stats.changed = stats.regions;
  return stats;
}

function growRun(stmts, i, limit, info, v, known) {
  const run = new Run(info, v, known);
  let j = i;
  while (j < limit && run.tryStmt(stmts[j])) j++;
  return { run, j };
}

function processBlock(stmts, known, ctx) {
  const { info, v, after, stats, exposure } = ctx;
  let i = 0;
  while (i < stmts.length) {
    // a closure created earlier may have changed a captured variable since the value was recorded
    for (const x of exposure.before(stmts[i])) known.delete(x);
    let { run, j } = growRun(stmts, i, stmts.length, info, v, known);
    let done = false;
    if (j > i) debug(`candidate ${i}..${j} worth=${run.worth} loop=${run.hasLoop} live=${after.has(stmts[j - 1])}`);
    // The longest prefix of the run whose leftovers can all be written down as constants.
    for (let attempt = 0; attempt < 8 && j > i && run.worth && !done; attempt++) {
      const last = stmts[j - 1];
      const live = after.get(last);
      if (!live) break;
      const wanted = [...run.assigned].filter((x) => live.has(x));
      debug(`run ${i}..${j} of ${stmts.length}, wants`, wanted.map((x) => x.name).join(','));
      const result = execute(stmts, i, j, run, wanted, known, v);
      if (result && result.values && !(run.hasLoop && [...result.values.values()].some((n) => n.type === 'String'))) {
        // Arithmetic the program does on purpose is its logic, not something to fold away. What is replaced is text that a
        // loop builds out of constants: the signature of a decryptor.
        debug('run computes no text; kept');
        break;
      }
      if (result && result.values) {
        const values = result.values;
        const replacement = [];
        for (const x of wanted) {
          const decl = declarationOf(stmts, i, j, x);
          replacement.push(decl
            ? { type: 'Local', ids: [decl], values: [values.get(x)], computed: true }
            : { type: 'Assign', targets: [{ type: 'Name', name: x.name }], values: [values.get(x)], computed: true });
        }
        // a variable the run declared stays declared if anything outside the run still names it
        for (const x of run.topLocals) {
          if (wanted.includes(x)) continue;
          if (x.reads.some((r) => !inside(stmts, i, j, r)) || x.writes.some((w) => !inside(stmts, i, j, w))) {
            replacement.push({ type: 'Local', ids: [declarationOf(stmts, i, j, x)], values: [] });
          }
        }
        const comments = stmts[i].comments;
        if (replacement.length && comments) replacement[0].comments = comments;
        stmts.splice(i, j - i, ...replacement);
        stats.regions++;
        for (const x of run.assigned) known.delete(x);
        for (const x of wanted) known.set(x, values.get(x));
        i += replacement.length;
        done = true;
        break;
      }
      if (!result) break;
      // stop the run before the statement that last wrote the variable that is not a constant
      let cut = -1;
      for (let k = j - 1; k >= i; k--) if (writtenIn(stmts[k], v).has(result.offender)) { cut = k; break; }
      debug('cut before', cut, 'because of', result.offender.name);
      if (cut <= i) break;
      ({ run, j } = growRun(stmts, i, cut, info, v, known));
    }
    if (done) continue;
    stats.rejected++;
    // not replaced: the statement stays, so whatever it writes is no longer known
    const s = stmts[i];
    const target = s.type === 'Assign' && s.targets.length === 1 && s.targets[0].type === 'Name' && s.values.length === 1 ? s.targets[0]
      : s.type === 'Local' && s.ids.length === 1 && s.values.length === 1 && !s.ids[0].attrib ? s.ids[0] : null;
    if (target) {
      const x = v(target);
      const c = constOf(s.values[0]);
      if (x && c !== NOT_CONST && s.values[0].type !== 'Paren' && !exposure.after(s).has(x)) { known.set(x, s.values[0]); i++; continue; }
    }
    for (const x of writtenIn(s, v)) known.delete(x);
    // `local a, b` declares nil until something is stored: that is a known value too (registers read before they are set)
    if (s.type === 'Local' && s.values.length === 0) for (const id of s.ids) { const x = v(id); if (x && !id.attrib && !exposure.after(s).has(x)) known.set(x, { type: 'Nil' }); }
    for (const b of childBlocks(s)) processBlock(b, new Map(known), ctx);
    i++;
  }
}

/** The Id node of the `local` statement inside [i, j) that declares x, or null. */
function declarationOf(stmts, i, j, x) {
  for (let k = i; k < j; k++) {
    const s = stmts[k];
    if (s.type === 'Local') for (const id of s.ids) if (id.name === x.name && x.decl === id) return { type: 'Id', name: id.name };
  }
  return null;
}

function inside(stmts, i, j, node) {
  for (let k = i; k < j; k++) { let hit = false; walk(stmts[k], (n) => { if (n === node) hit = true; return !hit; }); if (hit) return true; }
  return false;
}
