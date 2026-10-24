// Decompiler for Lua 5.1 / 5.4 bytecode chunks.
//
// Pipeline: lift to the register IR (lift.js), compute liveness, then rebuild structured code by walking the IR:
//
//   * temporaries are folded back into expressions while the evaluation order is preserved (pending entries);
//   * locals come from the chunk's debug information when it has any: names, and the point where each one
//     becomes active, which is where its `local` declaration goes; stripped chunks get `_rN` names;
//   * control flow is rebuilt from the jump layout the Lua compiler produces: if / elseif / else, while,
//     repeat-until, numeric and generic for, break. Chains of conditional jumps are folded into and/or
//     conditions;
//   * anything outside those shapes (goto, jumps into the middle of a statement) raises `Unstructured`, and the
//     caller reports the function as not decompilable instead of printing something wrong.
//
// The result is a syntax tree in the shape core/parser.js produces, so core/printer.js prints it and the
// ordinary recovery passes can clean it further. Correctness is tested by running original and decompiled
// code on the reference interpreters (tests/decompile.test.mjs).

import { lift, LiftError } from './lift.js';
import { isIdentifier } from '../core/printer.js';

export class Unstructured extends Error {}

const KEYWORDS = new Set(['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while']);

const nameNode = (name) => ({ type: 'Name', name });
const idNode = (name) => ({ type: 'Id', name });
const strNode = (value) => ({ type: 'String', value, raw: null });

function constNode(v, float) {
  if (float && typeof v === 'number' && Number.isFinite(v) && Number.isInteger(v) && !Object.is(v, -0)) {
    // a float that prints like an integer keeps its `.0` so the program means the same thing
    const n = { type: 'Number', value: Math.abs(v), raw: /e/i.test(String(Math.abs(v))) ? String(Math.abs(v)) : `${Math.abs(v)}.0` };
    return v < 0 ? { type: 'Unary', op: '-', arg: n } : n;
  }
  if (v === undefined) return { type: 'Nil' };
  if (v === true) return { type: 'True' };
  if (v === false) return { type: 'False' };
  if (typeof v === 'string') return strNode(v);
  if (Number.isNaN(v)) return { type: 'Binary', op: '/', left: { type: 'Number', value: 0, raw: null }, right: { type: 'Number', value: 0, raw: null } };
  if (v === Infinity) return { type: 'Binary', op: '/', left: { type: 'Number', value: 1, raw: null }, right: { type: 'Number', value: 0, raw: null } };
  if (v === -Infinity) return { type: 'Unary', op: '-', arg: constNode(Infinity) };
  if (v < 0 || Object.is(v, -0)) return { type: 'Unary', op: '-', arg: { type: 'Number', value: -v, raw: null } };
  return { type: 'Number', value: v, raw: null };
}

// De Morgan is exact in Lua: `not` always yields a boolean and and/or of booleans short-circuit identically.
const mkNot = (e) => {
  if (e.type === 'Unary' && e.op === 'not') return e.arg;
  if (e.type === 'Binary' && e.op === '==') return { ...e, op: '~=' };
  if (e.type === 'Binary' && e.op === '~=') return { ...e, op: '==' };
  if (e.type === 'Binary' && (e.op === 'and' || e.op === 'or')) return { type: 'Binary', op: e.op === 'and' ? 'or' : 'and', left: mkNot(e.left), right: mkNot(e.right) };
  return { type: 'Unary', op: 'not', arg: e };
};
/** A call or `...` that produced exactly one value must be parenthesised where a list would expand it. */
const fixTail = (list) => {
  const last = list[list.length - 1];
  if (last && last.single && (last.type === 'Call' || last.type === 'MethodCall' || last.type === 'Vararg')) list[list.length - 1] = { type: 'Paren', expr: last };
  return list;
};
const mkAnd = (a, b) => ({ type: 'Binary', op: 'and', left: a, right: b });
const mkOr = (a, b) => ({ type: 'Binary', op: 'or', left: a, right: b });

// ---- register read / write sets of IR instructions ----------------------------------------------------------------------

function regOf(x) { return x && x.r !== undefined ? x.r : -1; }

function readsOf(o, out) {
  const add = (x) => { const r = regOf(x); if (r >= 0) out.push(r); };
  switch (o.op) {
    case 'move': out.push(o.s); break;
    case 'setup': case 'setglobal': add(o.val); break;
    case 'index': add(o.obj); add(o.key); break;
    case 'setindex': add(o.obj); add(o.key); add(o.val); break;
    case 'self': add(o.obj); add(o.key); break;
    case 'bin': add(o.a); add(o.b); break;
    case 'un': add(o.a); break;
    case 'concat': for (let r = o.from; r <= o.to; r++) out.push(r); break;
    case 'call': {
      out.push(o.base);
      const last = o.nargs === -1 ? o.topFrom - 1 : o.base + o.nargs;
      for (let r = o.base + 1; r <= last; r++) out.push(r);
      break;
    }
    case 'ret': {
      const last = o.n === -1 ? o.topFrom - 1 : o.base + o.n - 1;
      for (let r = o.base; r <= last; r++) out.push(r);
      break;
    }
    case 'closure': for (const u of o.ups) if (u.instack) out.push(u.idx); break;
    case 'setlist': {
      out.push(o.base);
      const last = o.n === -1 ? o.topFrom - 1 : o.base + o.n;
      for (let r = o.base + 1; r <= last; r++) out.push(r);
      break;
    }
    case 'cjmp': add(o.a); add(o.b); break;
    case 'testset': out.push(o.s); break;
    case 'forprep': out.push(o.base, o.base + 1, o.base + 2); break;
    case 'tforprep': out.push(o.base, o.base + 1, o.base + 2); break;
    case 'tforloop': break;
    default: break;
  }
}

function writesOf(o, out) {
  switch (o.op) {
    case 'move': case 'loadk': case 'getup': case 'getglobal': case 'index': case 'newtable': case 'bin': case 'un': case 'concat': case 'closure': out.push(o.d); break;
    case 'testset': out.push(o.d); break;
    case 'loadnil': for (let r = o.from; r <= o.to; r++) out.push(r); break;
    case 'self': out.push(o.d, o.d + 1); break;
    case 'call': if (!o.tail) for (let r = 0; r < Math.max(0, o.nres); r++) out.push(o.base + r); break;
    case 'vararg': for (let r = 0; r < Math.max(0, o.n); r++) out.push(o.d + r); break;
    case 'forprep': case 'forloop': out.push(o.base + 3); break;
    case 'tforcall': for (let r = 0; r < o.nvars; r++) out.push(o.varBase + r); break;
    default: break;
  }
}

// ---- the decompiler of one function --------------------------------------------------------------------------------------------

class FunctionDecompiler {
  constructor(f, opts) {
    this.f = f;
    this.o = opts;
    const l = lift(f, { envUps: opts.envUps });
    this.ir = l.ir;
    this.n = this.ir.length;
    this.nregs = f.maxStack + 2;
    this.P = new Map();       // register -> pending entry
    this.topEntry = null;     // pending multi-value (call / vararg with open result count)
    this.multi = null;        // pending multi-register result of a call
    this.seq = 0;
    this.hoisted = new Map(); // temp variable name -> register
    this.skipDecl = new Set();
    this.scopes = [new Set()];
    this.prepare();
    for (const lv of this.locals) if (lv.param) this.nameOf(lv);
  }

  // ---- analysis ---------------------------------------------------------------------------------------------------------------------

  prepare() {
    const { ir, n, f } = this;
    // next original pc after each IR op
    this.npc = new Array(n);
    for (let i = n - 1; i >= 0; i--) this.npc[i] = i + 1 < n ? (ir[i + 1].pc > ir[i].pc ? ir[i + 1].pc : this.npc[i + 1]) : f.code.length;
    // multi-value consumers need to know where the open results start
    for (let i = 0; i < n; i++) {
      const o = ir[i];
      const open = (o.op === 'call' && o.nargs === -1) || (o.op === 'ret' && o.n === -1) || (o.op === 'setlist' && o.n === -1);
      if (!open) continue;
      const p = ir[i - 1];
      if (!p || !((p.op === 'call' && (p.nres === -1 || p.tail)) || (p.op === 'vararg' && p.n === -1))) throw new Unstructured(`open value list at ${o.pc} has no producer`);
      o.topFrom = p.op === 'call' ? p.base : p.d;
    }
    // jump targets
    this.isTarget = new Uint8Array(n + 1);
    for (const o of ir) if (o.t !== undefined) this.isTarget[o.t] = 1;
    // locals from debug information
    const locals = (f.locals || []).map((l, idx) => ({ ...l, idx }));
    this.hasDebug = locals.length > 0;
    if (!this.hasDebug) for (let r = 0; r < f.numParams; r++) locals.push({ name: this.o.depth === 0 ? `a${r + 1}` : `a${this.o.depth}_${r + 1}`, start: 0, end: Infinity, idx: r, synthetic: true });
    for (const lv of locals) {
      lv.internal = typeof lv.name !== 'string' || lv.name.startsWith('(');
      lv.reg = 0;
    }
    // Lua 5.1 declares a hidden `arg` local after the parameters of every vararg function
    if (f.version !== 0x54 && f.isVararg) {
      const hidden = locals.find((lv) => lv.name === 'arg' && lv.start === 0 && lv.idx === f.numParams);
      if (hidden) hidden.internal = true;
    }
    // register of each local = how many earlier locals are still active when it starts
    for (let a = 0; a < locals.length; a++) {
      let c = 0;
      for (let b = 0; b < a; b++) if (locals[b].start <= locals[a].start && locals[a].start < locals[b].end) c++;
      locals[a].reg = c;
    }
    this.locals = locals;
    this.startAt = new Map();
    for (const lv of locals) {
      if (lv.reg < f.numParams && lv.start === 0 && lv.idx < f.numParams) { lv.param = true; continue; }
      if (!this.startAt.has(lv.start)) this.startAt.set(lv.start, []);
      this.startAt.get(lv.start).push(lv);
    }
    for (const list of this.startAt.values()) list.sort((a, b) => a.reg - b.reg);
    // Without debug information a register captured by a closure has to stay a variable. With it, only named
    // locals are ever captured and they are never forwarded anyway.
    this.captured = new Set();
    if (!this.hasDebug) for (const o of ir) if (o.op === 'closure') for (const u of o.ups) if (u.instack) this.captured.add(u.idx);
    // loops: backward jumps. The compiler threads a jump that would land on a loop's closing `jmp` straight to
    // the loop head; undo that, so every such jump is a forward jump to the end of the body.
    const scanLoops = () => {
      this.loopAt = new Map();
      for (let j = 0; j < n; j++) {
        const o = ir[j];
        if ((o.op === 'jmp' || o.op === 'cjmp') && o.t <= j) {
          const cur = this.loopAt.get(o.t);
          if (!cur || cur.j < j) this.loopAt.set(o.t, { j, kind: o.op === 'jmp' ? 'jmp' : 'cjmp' });
        }
      }
    };
    scanLoops();
    let rewrote = true;
    for (let round = 0; rewrote && round < 8; round++) {
      rewrote = false;
      for (const [s, loop] of this.loopAt) {
        if (loop.kind !== 'jmp') continue;
        for (let k = s; k < loop.j; k++) {
          const o = ir[k];
          if ((o.op === 'jmp' || o.op === 'cjmp') && o.t === s) { o.t = loop.j; rewrote = true; }
        }
      }
      if (rewrote) scanLoops();
    }
    this.isTarget = new Uint8Array(n + 1);
    for (const o of ir) if (o.t !== undefined) this.isTarget[o.t] = 1;
    // names of the upvalues this function actually uses: its own locals must not hide them
    const usedUps = new Set();
    for (const o of ir) {
      if (o.op === 'getup' || o.op === 'setup') usedUps.add(o.u);
      if (o.op === 'closure') for (const u of o.ups) if (!u.instack) usedUps.add(u.idx);
    }
    for (const u of usedUps) this.scopes[0].add(this.upName(u));
    this.liveness();
    this.forwardability();
  }

  succs(i) {
    const o = this.ir[i];
    switch (o.op) {
      case 'jmp': case 'tforprep': return [o.t];
      case 'cjmp': case 'testset': return [i + 1, o.t];
      case 'ret': return [];
      case 'call': return o.tail ? [] : [i + 1];
      case 'forprep': return [i + 1, o.t + 1];
      case 'forloop': return [i + 1, o.t];
      case 'tforloop': return [i + 1, o.t];
      default: return [i + 1];
    }
  }

  liveness() {
    const { n, ir } = this;
    const R = this.nregs + 4;
    const reads = new Array(n);
    const writes = new Array(n);
    for (let i = 0; i < n; i++) { reads[i] = []; writes[i] = []; readsOf(ir[i], reads[i]); writesOf(ir[i], writes[i]); }
    // the hidden state of loops is not an ordinary register: the body must not look like it reads it
    for (let i = 0; i < n; i++) {
      const o = ir[i];
      if (o.op === 'forloop' || o.op === 'tforloop') { reads[i] = []; }
      if (o.op === 'tforcall') reads[i] = [];
    }
    const liveIn = Array.from({ length: n + 1 }, () => new Uint8Array(R));
    const liveOut = Array.from({ length: n + 1 }, () => new Uint8Array(R));
    const succ = Array.from({ length: n }, (_, i) => this.succs(i).filter((s) => s <= n));
    let changed = true;
    let guard = 0;
    while (changed && guard++ < 1000) {
      changed = false;
      for (let i = n - 1; i >= 0; i--) {
        const out = liveOut[i];
        for (const s of succ[i]) {
          const src = liveIn[s];
          for (let r = 0; r < R; r++) if (src[r] && !out[r]) { out[r] = 1; changed = true; }
        }
        const inn = liveIn[i];
        for (let r = 0; r < R; r++) if (out[r]) inn[r] = 1;
        for (const w of writes[i]) if (!(ir[i].op === 'testset' || ir[i].op === 'forloop')) inn[w] = 0;
        for (const rd of reads[i]) if (!inn[rd]) { inn[rd] = 1; changed = true; }
      }
    }
    this.liveOut = liveOut;
    this.reads = reads;
    this.writes = writes;
  }

  /** Is the register `d` written by IR op `i` a temporary that is read exactly once, soon, and nowhere else? */
  forwardability() {
    const { n, ir } = this;
    this.forward = new Uint8Array(n);       // single-register writers
    this.forwardReg = new Set();            // `${i}:${d}` for every writer, including multi-register ones
    const isBuild = (k, d) => {
      const x = ir[k];
      if (x.op === 'setindex') return regOf(x.obj) === d && regOf(x.key) !== d && regOf(x.val) !== d;
      if (x.op === 'setlist') return x.base === d;
      return false;
    };
    for (let i = 0; i < n; i++) {
      const o = ir[i];
      if (o.op === 'testset' || o.op === 'forprep' || o.op === 'forloop' || o.op === 'tforcall' || o.op === 'self') continue;
      if (o.op === 'call' && o.nres !== 1) continue;
      if (o.op === 'vararg' && o.n !== 1) continue;
      for (const d of this.writes[i]) {
        if (this.captured.has(d)) continue;
        if (this.localActive(d, o.pc)) continue;
        const building = o.op === 'newtable';
        let j = -1;
        let ok = true;
        let declared = this.localsStartingAt(this.npc[i]).some((x) => x.reg === d);
        for (let k = i + 1; k < n && !declared; k++) {
          // a local that becomes active at this instruction takes the value over before the instruction runs
          if (this.localsStartingAt(ir[k].pc).some((x) => x.reg === d)) { declared = true; break; }
          if (this.reads[k].includes(d)) {
            if (building && isBuild(k, d)) continue;
            j = k;
            break;
          }
          if (this.writes[k].includes(d)) { ok = false; break; }
          const x = ir[k];
          if (this.isTarget[k] || x.op === 'jmp' || x.op === 'cjmp' || x.op === 'testset' || x.op === 'ret' || x.op === 'forprep' || x.op === 'tforprep') { ok = false; break; }
        }
        let yes = false;
        if (declared) yes = true;
        else if (ok && j >= 0 && this.reads[j].filter((x) => x === d).length === 1) {
          // the reader may overwrite the register itself (`ADD R1 R1 R2`): then the old value dies there
          yes = !(this.liveOut[j][d] && !this.writes[j].includes(d));
        }
        if (yes) { this.forwardReg.add(`${i}:${d}`); if (this.writes[i].length === 1) this.forward[i] = 1; }
      }
    }
  }

  // ---- locals -----------------------------------------------------------------------------------------------------------------------

  localActive(reg, pc) {
    for (const lv of this.locals) if (!lv.internal && lv.reg === reg && lv.start <= pc && pc < lv.end) return lv;
    return null;
  }

  localsStartingAt(pc) {
    return (this.startAt.get(pc) || []).filter((lv) => !lv.internal && !this.skipDecl.has(lv));
  }

  safeName(name) {
    let s = String(name).replace(/[^A-Za-z0-9_]/g, '_');
    if (!s || /^[0-9]/.test(s)) s = `_${s}`;
    if (KEYWORDS.has(s)) s += '_';
    return s;
  }

  /**
   * The name a local is printed with. The printed code has no `do ... end` for scopes that ended in the original, so
   * a name that is already visible (an outer local, a parameter, an upvalue the function uses) is not reused: the new
   * local gets a numbered name. This keeps every reference pointing at the variable it meant.
   */
  nameOf(lv) {
    if (lv.outName) return lv.outName;
    const base = this.safeName(lv.name);
    let name = base;
    const taken = (n) => this.scopes.some((sc) => sc.has(n));
    for (let k = 2; taken(name); k++) name = `${base}_${k}`;
    lv.outName = name;
    this.scopes[this.scopes.length - 1].add(name);
    return name;
  }

  pushScope() { this.scopes.push(new Set()); }
  popScope() { this.scopes.pop(); }

  tempName(r) {
    const name = this.o.depth === 0 ? `_r${r}` : `_r${this.o.depth}_${r}`;
    this.hoisted.set(name, r);
    return name;
  }

  regRef(r, pc) {
    const lv = this.localActive(r, pc);
    if (lv) return nameNode(this.nameOf(lv));
    return nameNode(this.tempName(r));
  }

  upName(u) {
    const given = this.o.upNames && this.o.upNames[u];
    if (given) return given;
    const dbg = this.f.upNames && this.f.upNames[u];
    if (dbg) return this.safeName(dbg);
    return `up${u}`;
  }

  // ---- pending expressions --------------------------------------------------------------------------------------------------

  consumer(used, inline) {
    return (x, pc) => {
      if (x.k !== undefined || (x.r === undefined)) return constNode(x.k, x.float);
      const e = inline ? this.P.get(x.r) : null;
      if (e) { this.P.delete(x.r); used.push(e); return e.expr; }
      return this.regRef(x.r, pc);
    };
  }

  orderOk(used) {
    // Only impure values (calls) have an evaluation order that must be kept. The compiler swaps the operands of `>` and
    // `>=`, so pure operands of a comparison are routinely consumed out of definition order.
    let last = -1;
    for (const e of used) { if (!e.impure) continue; if (e.seq < last) return false; last = e.seq; }
    const impureUsed = used.filter((e) => e.impure).map((e) => e.seq);
    if (!impureUsed.length) return true;
    const oldest = Math.min(...impureUsed);
    for (const x of this.P.values()) if (x.impure && x.seq > oldest) return false;
    if (this.topEntry && this.topEntry.impure && this.topEntry.seq > oldest && !used.includes(this.topEntry)) return false;
    return true;
  }

  flushAll(out) {
    const entries = [...this.P.entries()].sort((a, b) => a[1].seq - b[1].seq);
    for (const [r, e] of entries) this.flushEntry(out, r, e);
    this.P.clear();
    if (this.topEntry) throw new Unstructured('an open value list was not consumed');
    if (this.multi) this.flushMulti(out);
  }

  flushEntry(out, r, e) {
    if (e.selfOf !== undefined) return; // the object half of SELF; only meaningful inside a method call
    if (e.table) e.expr = e.table;
    if (e.method) throw new Unstructured('method lookup not followed by its call');
    out.push({ type: 'Assign', targets: [nameNode(this.tempName(r))], values: [e.expr] });
  }

  flushMulti(out) {
    const m = this.multi;
    this.multi = null;
    const targets = [];
    for (let k = 0; k < m.n; k++) targets.push(nameNode(this.tempName(m.base + k)));
    out.push({ type: 'Assign', targets, values: [m.expr] });
  }

  /**
   * Build one statement (mode 'stmt') or one pending expression (mode 'pending') from operands.
   * `build(consume)` must request its operands in evaluation order.
   */
  tx(out, mode, build) {
    const snapP = new Map(this.P);
    const snapTop = this.topEntry;
    const used = [];
    const result = build(this.consumer(used, true));
    if (!this.orderOk(used)) {
      this.P = snapP;
      this.topEntry = snapTop;
      this.flushAll(out);
      return build(this.consumer([], false));
    }
    if (mode === 'stmt') {
      const rest = [...this.P.entries()].sort((a, b) => a[1].seq - b[1].seq);
      for (const [r, e] of rest) this.flushEntry(out, r, e);
      this.P.clear();
      if (this.multi) this.flushMulti(out);
    }
    return result;
  }

  // ---- expression construction ------------------------------------------------------------------------------------------------

  define(out, i, d, impure, build) {
    const o = this.ir[i];
    const lv = this.localActive(d, o.pc);
    if (lv && !this.captured.has(d)) {
      const expr = this.tx(out, 'stmt', build);
      out.push({ type: 'Assign', targets: [nameNode(this.nameOf(lv))], values: [expr] });
      return;
    }
    if (lv) {
      const expr = this.tx(out, 'stmt', build);
      out.push({ type: 'Assign', targets: [nameNode(this.nameOf(lv))], values: [expr] });
      return;
    }
    if (this.forward[i]) {
      const expr = this.tx(out, 'pending', build);
      this.P.set(d, { expr, impure, seq: this.seq++ });
      return;
    }
    const expr = this.tx(out, 'stmt', build);
    out.push({ type: 'Assign', targets: [nameNode(this.tempName(d))], values: [expr] });
  }

  keyNode(expr) { return expr; }

  indexNode(obj, keyExpr) {
    if (keyExpr.type === 'String' && keyExpr.value.length && isIdentifier(keyExpr.value)) return { type: 'Index', obj, key: keyExpr, dot: true };
    return { type: 'Index', obj, key: keyExpr, dot: false };
  }

  // ---- declarations ----------------------------------------------------------------------------------------------------------------

  declareAt(i, out) {
    const o = this.ir[i];
    const list = this.localsStartingAt(o.pc);
    if (!list.length) return;
    // only locals that really begin before this instruction (their value is already in the register)
    const lvs = list.filter((lv) => !lv.declared);
    if (!lvs.length) return;
    for (const lv of lvs) lv.declared = true;
    const names = lvs.map((lv) => idNode(this.nameOf(lv)));
    // a call that produced several values into consecutive registers
    if (this.multi && lvs.length >= 1 && lvs[0].reg === this.multi.base && lvs.length <= this.multi.n) {
      const m = this.multi;
      this.multi = null;
      const rest = [];
      for (let k = lvs.length; k < m.n; k++) rest.push(m.base + k);
      this.flushAll(out);
      out.push({ type: 'Local', ids: names, values: [m.expr] });
      void rest;
      return;
    }
    // `local function f` : a closure that captured its own register
    if (lvs.length === 1) {
      const e = this.P.get(lvs[0].reg);
      if (e && e.closure && e.selfCapture) {
        this.P.delete(lvs[0].reg);
        this.flushAll(out);
        out.push({ type: 'LocalFunction', id: names[0], func: e.expr });
        return;
      }
    }
    const used = [];
    const consume = this.consumer(used, true);
    // a register nothing has written yet holds nil (the compiler leaves out LOADNIL at the start of a function)
    const values = lvs.map((lv) => {
      if (!this.P.has(lv.reg) && !this.writtenBefore(lv.reg, i)) return { type: 'Nil' };
      if (!this.P.has(lv.reg)) return nameNode(this.tempName(lv.reg)); // set earlier, in branches: it lives in a temporary variable
      return consume({ r: lv.reg }, o.pc);
    });
    if (!this.orderOk(used)) {
      // fall back to variables
      for (const lv of lvs) lv.declared = true;
      this.flushAll(out);
      out.push({ type: 'Local', ids: names, values: lvs.map((lv) => nameNode(this.tempName(lv.reg))) });
      return;
    }
    void 0;
    // everything still pending belongs before the declaration
    const rest = [...this.P.entries()].sort((a, b) => a[1].seq - b[1].seq);
    for (const [r, e] of rest) this.flushEntry(out, r, e);
    this.P.clear();
    // `local x` with a nil value and nothing else: keep it short
    const allNil = values.every((v) => v.type === 'Nil');
    out.push({ type: 'Local', ids: names, values: allNil && lvs.length >= 1 ? [] : values });
  }

  writtenBefore(reg, i) {
    for (let k = 0; k < i; k++) if (this.writes[k].includes(reg)) return true;
    return false;
  }

  // ---- conditions --------------------------------------------------------------------------------------------------------------------

  predicateOf(o, consume) {
    const pc = o.pc;
    if (o.kind === 'test') {
      const a = consume(o.a, pc);
      return o.sense ? a : mkNot(a);
    }
    const a = consume(o.a, pc);
    const b = consume(o.b, pc);
    const op = o.kind === 'eq' ? '==' : o.kind === 'lt' ? '<' : '<=';
    const isConst = (x) => x.type === 'Number' || x.type === 'String' || x.type === 'Nil' || x.type === 'True' || x.type === 'False' || (x.type === 'Unary' && x.op === '-' && x.arg.type === 'Number');
    // the compiler turns `a >= 1` into `1 <= a`; print the way it was most likely written
    if (o.kind !== 'eq' && o.sense && isConst(a) && !isConst(b)) return { type: 'Binary', op: o.kind === 'lt' ? '>' : '>=', left: b, right: a };
    const e = { type: 'Binary', op, left: a, right: b };
    if (o.sense) return e;
    return o.kind === 'eq' ? { ...e, op: '~=' } : { type: 'Unary', op: 'not', arg: e };
  }

  /** One condition: the setup instructions followed by a conditional jump, with no statement in between. */
  parseCondNode(i, hi) {
    const saveP = new Map(this.P);
    const saveSeq = this.seq;
    const saveTop = this.topEntry;
    const saveMulti = this.multi;
    const scratch = [];
    let k = i;
    const fail = () => { this.P = saveP; this.seq = saveSeq; this.topEntry = saveTop; this.multi = saveMulti; return null; };
    const setupOps = new Set(['move', 'loadk', 'loadnil', 'getup', 'getglobal', 'index', 'bin', 'un', 'concat', 'self', 'call', 'vararg', 'newtable', 'closure']);
    while (k < hi) {
      const o = this.ir[k];
      if (k > i && this.isTarget[k]) return fail();
      if (this.startAt.has(o.pc) && this.localsStartingAt(o.pc).length && k > i) return fail();
      if (o.op === 'cjmp' || o.op === 'testset') {
        const used = [];
        const consume = this.consumer(used, true);
        let P;
        let assign = null;
        if (o.op === 'cjmp') P = this.predicateOf(o, consume);
        else {
          // TESTSET: when the tested value counts, it is also stored in the destination register
          const sExpr = consume({ r: o.s }, o.pc);
          if (used.some((e) => e.impure)) return fail();
          P = o.sense ? sExpr : mkNot(sExpr);
          assign = { d: o.d, expr: sExpr, op: o.sense ? 'or' : 'and', pc: o.pc };
        }
        if (!this.orderOk(used) || this.P.size || this.topEntry || this.multi) return fail();
        if (scratch.length) return fail();
        return { P, t: o.t, start: i, end: k, next: k + 1, assign };
      }
      if (!setupOps.has(o.op)) return fail();
      if (o.op === 'call' && (o.tail || o.nres < 0 || o.nres > 1)) return fail();
      try { this.stepSimple(k, scratch); } catch (e) { if (e instanceof Unstructured) return fail(); throw e; }
      if (scratch.length) return fail();
      k++;
    }
    return fail();
  }

  /** Greedily parse conditions, then keep the longest prefix that folds into one and/or condition. */
  parseGroup(i, hi) {
    if (this.P.size || this.topEntry || this.multi) return null;
    const nodes = [];
    let k = i;
    while (k < hi) {
      const node = this.parseCondNode(k, hi);
      if (!node) break;
      nodes.push(node);
      k = node.next;
    }
    if (!nodes.length) return null;
    for (let len = nodes.length; len >= 1; len--) {
      const g = this.reduce(nodes.slice(0, len));
      if (g) return g;
    }
    return null;
  }

  reduce(nodes) {
    const bodyStart = nodes[nodes.length - 1].next;
    const work = nodes.map((nd, idx) => ({ P: nd.P, t: nd.t, f: nd.next, start: nd.start, end: nd.end, idx, assign: nd.assign || null }));
    const starts = new Set(work.map((w) => w.start));
    const preds = (s, list) => list.filter((w) => w.t === s || w.f === s).length;
    let changed = true;
    while (work.length > 1 && changed) {
      changed = false;
      for (let a = 0; a < work.length && !changed; a++) {
        const A = work[a];
        for (const D of [A.f, A.t]) {
          const bIdx = work.findIndex((w, ix) => ix !== a && w.start === D);
          if (bIdx < 0) continue;
          const B = work[bIdx];
          if (preds(B.start, work) !== 1) continue;
          let merged = null;
          if (D === A.f) {
            if (A.t === B.t) {
              // A or B; both may carry a value for the destination register: it is the first one that fired
              if (A.assign && B.assign) {
                if (A.assign.op !== B.assign.op || A.assign.d !== B.assign.d) continue;
                const op = A.assign.op;
                merged = { P: mkOr(A.P, B.P), t: B.t, f: B.f, assign: { ...A.assign, expr: { type: 'Binary', op, left: A.assign.expr, right: B.assign.expr } } };
              } else if (!A.assign && !B.assign) merged = { P: mkOr(A.P, B.P), t: B.t, f: B.f, assign: null };
            } else if (A.t === B.f && !A.assign) merged = { P: mkAnd(mkNot(A.P), B.P), t: B.t, f: A.t, assign: B.assign };
          } else if (D === A.t) {
            if (A.f === B.f && !A.assign) merged = { P: mkAnd(A.P, B.P), t: B.t, f: B.f, assign: B.assign };
            else if (A.f === B.t && !A.assign && !B.assign) merged = { P: mkAnd(A.P, mkNot(B.P)), t: B.f, f: B.t, assign: null };
          }
          if (!merged) continue;
          work[a] = { ...A, ...merged };
          work.splice(bIdx, 1);
          changed = true;
          break;
        }
      }
    }
    if (work.length !== 1) return null;
    const w = work[0];
    void starts;
    // the group must be entered at its first node and leave through the fall-through and one other place
    if (w.start !== nodes[0].start) return null;
    if (w.t !== bodyStart && w.f !== bodyStart) return null;
    return { P: w.P, t: w.t, f: w.f, start: nodes[0].start, end: nodes[nodes.length - 1].end, bodyStart, assign: w.assign };
  }

  // ---- structuring ------------------------------------------------------------------------------------------------------------------

  decompile() {
    const body = this.block(0, this.n, { exit: null, innerStart: -1, until: -1 }).stmts;
    this.flushAll(body);
    // drop the implicit final `return`
    const last = body[body.length - 1];
    if (last && last.type === 'Return' && last.values.length === 0) body.pop();
    if (this.hoisted.size) {
      const decl = { type: 'Local', ids: [...this.hoisted.keys()].map(idNode), values: [] };
      body.unshift(decl);
    }
    const params = [];
    for (let r = 0; r < this.f.numParams; r++) {
      const lv = this.locals.find((l) => l.param && l.reg === r);
      params.push(idNode(lv ? this.nameOf(lv) : `a${r + 1}`));
    }
    return { type: 'Func', params, vararg: !!this.f.isVararg, body, line: this.f.line };
  }

  block(lo, hi, ctx) {
    const out = [];
    let i = lo;
    while (i < hi) {
      this.declareAt(i, out);
      // loops that begin here
      const loop = this.loopAt.get(i);
      if (loop && loop.j < hi && ctx.innerStart !== i) {
        this.flushAll(out);
        i = this.loop(i, loop, out, ctx);
        continue;
      }
      // conditions
      const g = this.parseGroup(i, hi);
      if (g) {
        if (ctx.until >= 0 && g.end === ctx.until) { return { stmts: out, until: g, stop: i }; }
        i = this.branch(g, hi, out, ctx);
        continue;
      }
      i = this.step(i, hi, out, ctx);
    }
    return { stmts: out };
  }

  /** if / elseif / else, `if cond then break end`. */
  branch(g, hi, out, ctx) {
    const bodyStart = g.bodyStart;
    const jumpWhenP = g.t !== bodyStart; // the other destination is where the jump goes
    const X = jumpWhenP ? g.t : g.f;
    const toX = jumpWhenP ? g.P : mkNot(g.P);        // truth leading to X
    const toBody = mkNot(toX);                       // truth leading into the fall-through code
    if (g.t === g.f) {
      // both outcomes continue at the same place: only the (possible) assignment of a value condition remains
      if (g.assign) {
        const target = this.regTarget(g.assign.d, g.assign.pc);
        out.push({ type: 'If', clauses: [{ cond: g.P, body: [{ type: 'Assign', targets: [target], values: [g.assign.expr] }] }], orelse: null });
      } else out.push({ type: 'If', clauses: [{ cond: g.P, body: [] }], orelse: null });
      return bodyStart;
    }
    if (g.assign) {
      // a value condition: on the jump edge the register receives the value, otherwise the fall-through code computes it
      if (!jumpWhenP || X <= g.end || X > hi) throw new Unstructured(`value condition at ${this.ir[g.end].pc} is not in a recognised shape`);
      const target = this.regTarget(g.assign.d, g.assign.pc);
      const fall = this.sub(bodyStart, X, ctx);
      out.push({ type: 'If', clauses: [{ cond: g.P, body: [{ type: 'Assign', targets: [target], values: [g.assign.expr] }] }], orelse: fall.length ? fall : null });
      return X;
    }
    if (ctx.exit !== null && X === ctx.exit) {
      out.push({ type: 'If', clauses: [{ cond: toX, body: [{ type: 'Break' }] }], orelse: null });
      return bodyStart;
    }
    if (X <= g.end) throw new Unstructured(`backward conditional jump at ${this.ir[g.end].pc}`);
    if (X > hi) throw new Unstructured(`conditional jump at ${this.ir[g.end].pc} leaves its block`);
    // `if ... else ... end`: the compiler sends jumps that would reach the closing `jmp` of the then-branch straight to
    // its destination. Undo that, so that they are plain jumps to the end of the then-branch.
    const closing = this.ir[X - 1];
    if (X - 1 >= bodyStart && closing.op === 'jmp' && closing.t > X && closing.t <= hi && (ctx.exit === null || closing.t !== ctx.exit) && !this.isLoopBackEdge(X - 1)) {
      for (let k = bodyStart; k < X - 1; k++) {
        const q = this.ir[k];
        if ((q.op === 'jmp' || q.op === 'cjmp' || q.op === 'testset') && q.t === closing.t) { q.t = X - 1; this.isTarget[X - 1] = 1; }
      }
    }
    // A jump from inside the fall-through code to a place beyond X (`a and b or c`): both branches end at that
    // place, and the code between X and it runs on both paths, so it is written out twice.
    let shared = X;
    for (let k = bodyStart; k < X; k++) {
      const q = this.ir[k];
      if (k === X - 1 && q.op === 'jmp') continue; // the jump that closes an if/else
      if ((q.op === 'jmp' || q.op === 'cjmp' || q.op === 'testset') && q.t > shared && q.t <= hi && (ctx.exit === null || q.t !== ctx.exit)) shared = q.t;
    }
    if (shared > X) {
      if (shared - X > 80) throw new Unstructured(`shared tail at ${this.ir[X].pc} is too large to duplicate`);
      const thenBlock = this.sub(bodyStart, shared, ctx);
      const elseBlock = this.sub(X, shared, ctx);
      let node = { type: 'If', clauses: [{ cond: toBody, body: thenBlock }], orelse: elseBlock.length ? elseBlock : null };
      out.push(node);
      return shared;
    }
    let thenEnd = X;
    let elseRange = null;
    const tail = this.ir[X - 1];
    if (X - 1 >= bodyStart && tail.op === 'jmp' && tail.t > X && tail.t <= hi && (ctx.exit === null || tail.t !== ctx.exit) && !this.isLoopBackEdge(X - 1)) {
      thenEnd = X - 1;
      elseRange = [X, tail.t];
    }
    const thenBlock = this.sub(bodyStart, thenEnd, ctx);
    let elseBlock = null;
    if (elseRange) elseBlock = this.sub(elseRange[0], elseRange[1], ctx);
    let node;
    if (elseBlock && elseBlock.length === 0) elseBlock = null;
    if (toBody.type === 'Unary' && toBody.op === 'not' && elseBlock && elseBlock.length) {
      node = { type: 'If', clauses: [{ cond: toBody.arg, body: elseBlock }], orelse: thenBlock.length ? thenBlock : null };
    } else {
      node = { type: 'If', clauses: [{ cond: toBody, body: thenBlock }], orelse: elseBlock };
    }
    // else { if ... } -> elseif
    if (node.orelse && node.orelse.length === 1 && node.orelse[0].type === 'If' && !node.orelse[0].comments) {
      const inner = node.orelse[0];
      node.clauses.push(...inner.clauses);
      node.orelse = inner.orelse;
    }
    out.push(node);
    return elseRange ? elseRange[1] : X;
  }

  isLoopBackEdge(idx) {
    const o = this.ir[idx];
    return o.t <= idx;
  }

  sub(lo, hi, ctx) {
    if (lo >= hi) return [];
    const savedP = this.P;
    // statements inside a branch must not depend on pending values from outside it
    this.P = new Map();
    this.pushScope();
    const r = this.block(lo, hi, { ...ctx, until: -1 });
    this.flushAll(r.stmts);
    this.popScope();
    this.P = savedP;
    return this.wrapReturns(r.stmts, true);
  }

  wrapReturns(stmts) {
    // `return` must be the last statement of a block; anything after it becomes unreachable and is dropped
    const k = stmts.findIndex((s) => s.type === 'Return' || s.type === 'Break');
    return k >= 0 && k < stmts.length - 1 ? stmts.slice(0, k + 1) : stmts;
  }

  loop(s, loop, out, ctx) {
    const { j } = loop;
    const exit = j + 1;
    const lctx = { exit, innerStart: -1, until: -1 };
    if (loop.kind === 'cjmp') {
      // repeat ... until cond
      this.pushScope();
      const r = this.block(s, j + 1, { exit, innerStart: s, until: j });
      if (!r.until) throw new Unstructured(`loop at ${this.ir[s].pc} does not end in a recognisable condition`);
      const g = r.until;
      const body = r.stmts;
      this.flushAll(body);
      // the group jumps back to s while P holds on the back edge
      const backWhenP = g.t === s;
      const exitCond = backWhenP ? mkNot(g.P) : g.P;
      if (!(g.t === s || g.f === s)) throw new Unstructured('repeat loop condition does not close the loop');
      this.popScope();
      out.push({ type: 'Repeat', body: this.wrapReturns(body), cond: exitCond });
      return exit;
    }
    // while: a leading condition group that leaves the loop, or an endless loop
    this.P = new Map();
    const g = this.parseGroup(s, j);
    if (g && ((g.t === exit && g.f === g.bodyStart) || (g.f === exit && g.t === g.bodyStart))) {
      const cont = g.t === g.bodyStart ? g.P : mkNot(g.P);
      const body = this.sub(g.bodyStart, j, lctx);
      out.push({ type: 'While', cond: cont, body });
      return exit;
    }
    const body = this.sub(s, j, { ...lctx, innerStart: s });
    out.push({ type: 'While', cond: { type: 'True' }, body });
    return exit;
  }

  // ---- single instructions ------------------------------------------------------------------------------------------------------

  stepSimple(i, out) { return this.step(i, i + 1, out, { exit: null, innerStart: -1, until: -1 }, true); }

  step(i, hi, out, ctx, simple = false) {
    const o = this.ir[i];
    const pc = o.pc;
    switch (o.op) {
      case 'move':
        this.define(out, i, o.d, false, (c) => c({ r: o.s }, pc));
        return i + 1;
      case 'loadk':
        this.define(out, i, o.d, false, () => constNode(o.v, o.float));
        return i + 1;
      case 'loadnil': {
        for (let r = o.from; r <= o.to; r++) {
          const lv = this.localActive(r, pc);
          if (lv || !this.forwardReg.has(`${i}:${r}`)) {
            this.flushAll(out);
            out.push({ type: 'Assign', targets: [lv ? nameNode(this.nameOf(lv)) : nameNode(this.tempName(r))], values: [{ type: 'Nil' }] });
          } else this.P.set(r, { expr: { type: 'Nil' }, impure: false, seq: this.seq++ });
        }
        return i + 1;
      }
      case 'getup':
        this.define(out, i, o.d, false, () => nameNode(this.upName(o.u)));
        return i + 1;
      case 'getglobal':
        this.define(out, i, o.d, false, () => nameNode(this.safeGlobal(o.name)));
        return i + 1;
      case 'index':
        this.define(out, i, o.d, false, (c) => {
          const obj = c(o.obj, pc);
          const key = c(o.key, pc);
          return this.indexNode(obj, key);
        });
        return i + 1;
      case 'newtable': {
        const lv = this.localActive(o.d, pc);
        if (lv || !this.forward[i]) {
          const expr = { type: 'Table', fields: [] };
          this.flushAll(out);
          out.push({ type: 'Assign', targets: [lv ? nameNode(this.nameOf(lv)) : nameNode(this.tempName(o.d))], values: [expr] });
        } else {
          const t = { type: 'Table', fields: [] };
          this.P.set(o.d, { expr: t, table: t, impure: false, seq: this.seq++ });
        }
        return i + 1;
      }
      case 'self': {
        const used = [];
        const consume = this.consumer(used, true);
        const obj = consume(o.obj, pc);
        const key = consume(o.key, pc);
        if (!this.orderOk(used)) throw new Unstructured('method lookup out of order');
        const idx = this.indexNode(obj, key);
        this.P.set(o.d, { expr: idx, method: { obj, key }, impure: false, seq: this.seq++ });
        this.P.set(o.d + 1, { expr: obj, selfOf: o.d, impure: used.some((e) => e.impure), seq: this.seq++ });
        return i + 1;
      }
      case 'bin':
        this.define(out, i, o.d, false, (c) => ({ type: 'Binary', op: o.bop, left: c(o.a, pc), right: c(o.b, pc) }));
        return i + 1;
      case 'un':
        this.define(out, i, o.d, false, (c) => ({ type: 'Unary', op: o.uop, arg: c({ r: o.a.r, k: o.a.k }, pc) }));
        return i + 1;
      case 'concat':
        this.define(out, i, o.d, false, (c) => {
          const parts = [];
          for (let r = o.from; r <= o.to; r++) parts.push(c({ r }, pc));
          let e = parts[parts.length - 1];
          for (let k = parts.length - 2; k >= 0; k--) e = { type: 'Binary', op: '..', left: parts[k], right: e };
          return e;
        });
        return i + 1;
      case 'closure': return this.stepClosure(i, out);
      case 'vararg': {
        if (o.n === -1) { this.topEntry = { expr: { type: 'Vararg' }, impure: false, seq: this.seq++ }; return i + 1; }
        if (o.n === 1) { this.define(out, i, o.d, false, () => ({ type: 'Vararg', single: true })); return i + 1; }
        this.flushAll(out);
        const targets = [];
        for (let k = 0; k < o.n; k++) targets.push(this.regTarget(o.d + k, pc));
        if (targets.length) out.push({ type: 'Assign', targets, values: [{ type: 'Vararg' }] });
        return i + 1;
      }
      case 'call': return this.stepCall(i, out);
      case 'ret': {
        if (simple) throw new Unstructured('return inside a condition');
        // the RETURN the compiler emits after a tail call can never run
        if (i > 0 && this.ir[i - 1].op === 'call' && this.ir[i - 1].tail) return i + 1;
        const values = this.tx(out, 'stmt', (c) => {
          const vs = [];
          const last = o.n === -1 ? o.topFrom - 1 : o.base + o.n - 1;
          for (let r = o.base; r <= last; r++) vs.push(c({ r }, pc));
          if (o.n === -1) vs.push(this.takeTop());
          return fixTail(vs);
        });
        out.push({ type: 'Return', values });
        return i + 1;
      }
      case 'setup':
        this.assignStmt(out, (c) => ({ target: nameNode(this.upName(o.u)), value: c(o.val, pc) }));
        return i + 1;
      case 'setglobal':
        this.assignStmt(out, (c) => ({ target: nameNode(this.safeGlobal(o.name)), value: c(o.val, pc) }));
        return i + 1;
      case 'setindex': return this.stepSetIndex(i, out);
      case 'setlist': return this.stepSetList(i, out);
      case 'close': return i + 1;
      case 'jmp': {
        if (simple) throw new Unstructured('jump inside a condition');
        if (ctx.exit !== null && o.t === ctx.exit) { this.flushAll(out); out.push({ type: 'Break' }); return i + 1; }
        if (o.t > i + 1 && o.t <= hi) {
          // a jump over code that nothing else can reach (the compiler's LOADBOOL pairs): skip it
          let dead = true;
          for (let k = i + 1; k < o.t; k++) if (this.isTarget[k]) { dead = false; break; }
          if (dead) { this.flushAll(out); return o.t; }
        }
        throw new Unstructured(`unstructured jump at ${pc} to ${this.ir[o.t] ? this.ir[o.t].pc : '?'}`);
      }
      case 'cjmp': case 'testset': {
        if (o.op === 'testset') return this.stepTestSet(i, hi, out, ctx);
        throw new Unstructured(`condition at ${pc} could not be folded`);
      }
      case 'forprep': return this.stepNumFor(i, out, ctx);
      case 'tforprep': return this.stepGenFor(i, out, ctx);
      default: throw new Unstructured(`unexpected ${o.op} at ${pc}`);
    }
  }

  safeGlobal(name) {
    if (typeof name !== 'string' || !isIdentifier(name)) return name;
    return name;
  }

  takeTop() {
    if (!this.topEntry) throw new Unstructured('open value list is missing its producer');
    const e = this.topEntry;
    this.topEntry = null;
    return e.expr;
  }

  regTarget(r, pc) {
    const lv = this.localActive(r, pc);
    return lv ? nameNode(this.nameOf(lv)) : nameNode(this.tempName(r));
  }

  assignStmt(out, build) {
    let parts;
    this.tx(out, 'stmt', (c) => { parts = build(c); return parts.value; });
    out.push({ type: 'Assign', targets: [parts.target], values: [parts.value] });
  }

  stepSetIndex(i, out) {
    const o = this.ir[i];
    const pc = o.pc;
    // constructor field: the table is still pending
    const tr = regOf(o.obj);
    const te = tr >= 0 ? this.P.get(tr) : null;
    if (te && te.table && this.canFold(te, o, i)) {
      const used = [];
      const consume = this.consumer(used, true);
      const key = consume(o.key, pc);
      const val = consume(o.val, pc);
      if (this.orderOk(used)) {
        if (used.some((e) => e.impure)) te.impure = true;
        const isName = key.type === 'String' && isIdentifier(key.value);
        te.table.fields.push(isName ? { kind: 'named', key: key.value, value: val } : { kind: 'keyed', key, value: val });
        return i + 1;
      }
      // could not keep order: restore by flushing everything as ordinary statements
      throw new Unstructured('table constructor field out of order');
    }
    // a table that is still being built cannot be the target of an ordinary assignment: give it a name first
    if (te && te.table) this.flushAll(out);
    let parts;
    this.tx(out, 'stmt', (c) => {
      const obj = c(o.obj, pc);
      const key = c(o.key, pc);
      const value = c(o.val, pc);
      parts = { obj, key, value };
      return value;
    });
    out.push({ type: 'Assign', targets: [this.indexNode(parts.obj, parts.key)], values: [parts.value] });
    return i + 1;
  }

  /**
   * Folding a field into a pending constructor keeps the evaluation order as long as no other impure value that was
   * produced after the table is still waiting (values produced before it stay ahead of it either way).
   */
  canFold(te, o, i) {
    for (const [r, e] of this.P) {
      if (e === te || !e.impure || e.seq < te.seq) continue;
      if (!(this.reads[i] || []).includes(r)) return false;
    }
    return true;
  }

  stepSetList(i, out) {
    const o = this.ir[i];
    const pc = o.pc;
    const te = this.P.get(o.base);
    if (!(te && te.table)) {
      // the table is an ordinary variable: store the items one by one
      const items = [];
      this.tx(out, 'stmt', (c) => {
        const last = o.n === -1 ? o.topFrom - 1 : o.base + o.n;
        for (let r = o.base + 1; r <= last; r++) items.push(c({ r }, pc));
        if (o.n === -1) items.push(this.takeTop());
        return items[0];
      });
      const tref = this.regRef(o.base, pc);
      items.forEach((v, k) => out.push({ type: 'Assign', targets: [{ type: 'Index', obj: tref, key: constNode(o.off + k + 1), dot: false }], values: [v] }));
      return i + 1;
    }
    const used = [];
    const consume = this.consumer(used, true);
    const last = o.n === -1 ? o.topFrom - 1 : o.base + o.n;
    const items = [];
    for (let r = o.base + 1; r <= last; r++) items.push(consume({ r }, pc));
    if (o.n === -1) items.push(this.takeTop());
    fixTail(items);
    if (!this.orderOk(used)) throw new Unstructured('table constructor items out of order');
    if (used.some((e) => e.impure) || o.n === -1) te.impure = true;
    for (const v of items) te.table.fields.push({ kind: 'item', value: v });
    return i + 1;
  }

  stepClosure(i, out) {
    const o = this.ir[i];
    const pc = o.pc;
    const upNames = o.ups.map((u) => {
      if (u.instack) {
        const lv = this.localActive(u.idx, this.npc[i]) || this.localActive(u.idx, pc);
        return lv ? this.nameOf(lv) : this.tempName(u.idx);
      }
      return this.upName(u.idx);
    });
    const envUps = o.ups.map((u) => (!u.instack && this.o.envUps && this.o.envUps[u.idx] === true));
    let func;
    try {
      func = decompileFunction(o.proto, { depth: this.o.depth + 1, upNames, envUps, version: this.f.version });
    } catch (e) {
      if (!(e instanceof Unstructured || e instanceof LiftError)) throw e;
      func = failedFunction(o.proto, e.message);
    }
    const selfCapture = o.ups.some((u) => u.instack && u.idx === o.d);
    const declaredLater = this.localsStartingAt(this.npc[i]).some((lv) => lv.reg === o.d);
    const lv = this.localActive(o.d, pc);
    if (lv || !this.forward[i]) {
      this.flushAll(out);
      out.push({ type: 'Assign', targets: [lv ? nameNode(this.nameOf(lv)) : nameNode(this.tempName(o.d))], values: [func] });
    } else {
      this.P.set(o.d, { expr: func, impure: false, closure: true, selfCapture: selfCapture && declaredLater, seq: this.seq++ });
    }
    return i + 1;
  }

  stepCall(i, out) {
    const o = this.ir[i];
    const pc = o.pc;
    const used = [];
    const snapP = new Map(this.P);
    const snapTop = this.topEntry;
    const build = (c) => {
      const fnEntry = this.P.get(o.base);
      const fnE = c({ r: o.base }, pc);
      const last = o.nargs === -1 ? o.topFrom - 1 : o.base + o.nargs;
      const args = [];
      let method = null;
      if (fnEntry && fnEntry.method) {
        const objEntry = this.P.get(o.base + 1);
        if (last >= o.base + 1 && (objEntry === undefined) && fnEntry.method) {
          // the object half has been consumed already or is held back: it was recorded on the entry
        }
        method = fnEntry.method;
      }
      for (let r = o.base + 1; r <= last; r++) {
        if (method && r === o.base + 1) {
          const e = this.P.get(r);
          if (e && e.selfOf === o.base) { this.P.delete(r); continue; }
          throw new Unstructured('method call whose object was not forwarded');
        }
        args.push(c({ r }, pc));
      }
      if (o.nargs === -1) args.push(this.takeTop());
      fixTail(args);
      if (method) return { type: 'MethodCall', obj: method.obj, name: method.key.value, args, sugar: null };
      return { type: 'Call', fn: fnE, args, sugar: null };
    };
    // a method lookup whose object entry is consumed together with it
    const call = (() => {
      const calc = this.tx(out, 'pending', (c) => build((x, p) => c(x, p)));
      return calc;
    })();
    void used; void snapP; void snapTop;
    if (o.tail) { out.push({ type: 'Return', values: [call] }); return i + 1; }
    if (o.nres === 0) { this.flushAll(out); out.push({ type: 'CallStmt', call }); return i + 1; }
    if (o.nres === -1) { this.topEntry = { expr: call, impure: true, seq: this.seq++ }; return i + 1; }
    if (o.nres === 1) {
      call.single = true;
      const d = o.base;
      const lv = this.localActive(d, pc);
      if (lv) { this.flushAll(out); out.push({ type: 'Assign', targets: [nameNode(this.nameOf(lv))], values: [call] }); return i + 1; }
      if (this.forward[i]) { this.P.set(d, { expr: call, impure: true, seq: this.seq++ }); return i + 1; }
      this.flushAll(out);
      out.push({ type: 'Assign', targets: [nameNode(this.tempName(d))], values: [call] });
      return i + 1;
    }
    // several results
    this.flushAll(out);
    this.multi = { base: o.base, n: o.nres, expr: call };
    // locals that are already active receive the values by assignment
    const active = [];
    for (let k = 0; k < o.nres; k++) active.push(this.localActive(o.base + k, pc));
    if (active.every((x) => x)) {
      const targets = active.map((lv) => nameNode(this.nameOf(lv)));
      this.multi = null;
      out.push({ type: 'Assign', targets, values: [call] });
    }
    return i + 1;
  }

  stepTestSet(i, hi, out, ctx) {
    // `d = s` on the jump edge, otherwise fall through: if truthy(s) == sense then d = s else <fall-through up to t>
    const o = this.ir[i];
    const pc = o.pc;
    this.flushAll(out);
    if (o.t <= i || o.t > hi) throw new Unstructured(`value condition at ${pc} jumps out of its block`);
    const s = this.regRef(o.s, pc);
    const cond = o.sense ? s : mkNot(s);
    const target = this.regTarget(o.d, pc);
    const thenBlock = [{ type: 'Assign', targets: [target], values: [s] }];
    const elseBlock = this.sub(i + 1, o.t, ctx);
    out.push({ type: 'If', clauses: [{ cond, body: thenBlock }], orelse: elseBlock.length ? elseBlock : null });
    return o.t;
  }

  stepNumFor(i, out, ctx) {
    const o = this.ir[i];
    const pc = o.pc;
    const f = o.t; // index of the FORLOOP
    const loopOp = this.ir[f];
    if (!loopOp || loopOp.op !== 'forloop') throw new Unstructured('numeric for without its loop instruction');
    const exprs = [];
    this.tx(out, 'stmt', (c) => {
      exprs.push(c({ r: o.base }, pc), c({ r: o.base + 1 }, pc), c({ r: o.base + 2 }, pc));
      return exprs[0];
    });
    const bodyPc = this.ir[i + 1] ? this.ir[i + 1].pc : pc + 1;
    const lv = this.locals.find((l) => !l.internal && l.reg === o.base + 3 && l.start === bodyPc);
    if (lv) this.skipDecl.add(lv);
    for (const l of this.locals) if (l.internal && l.start === bodyPc) this.skipDecl.add(l);
    this.pushScope();
    const varName = lv ? this.nameOf(lv) : this.tempName(o.base + 3);
    if (!lv) this.hoisted.delete(varName);
    const body = this.sub(i + 1, f, { exit: f + 1, innerStart: -1, until: -1 });
    this.popScope();
    let step = exprs[2];
    if (step.type === 'Number' && step.value === 1) step = null;
    out.push({ type: 'NumFor', id: idNode(varName), start: exprs[0], stop: exprs[1], step, body });
    return f + 1;
  }

  stepGenFor(i, out, ctx) {
    const o = this.ir[i];
    const pc = o.pc;
    const c = o.t; // index of TFORCALL
    const call = this.ir[c];
    const loopOp = this.ir[c + 1];
    if (!call || call.op !== 'tforcall' || !loopOp || loopOp.op !== 'tforloop') throw new Unstructured('generic for without its loop instructions');
    let exprs;
    if (this.multi && this.multi.base === o.base) {
      exprs = [this.multi.expr];
      this.multi = null;
      this.flushAll(out);
    } else {
      const list = [];
      this.tx(out, 'stmt', (cc) => {
        for (let k = 0; k < 3; k++) list.push(cc({ r: o.base + k }, pc));
        return list[0];
      });
      while (list.length > 1 && list[list.length - 1].type === 'Nil') list.pop();
      exprs = list;
    }
    const bodyPc = this.ir[i + 1] ? this.ir[i + 1].pc : pc + 1;
    const ids = [];
    this.pushScope();
    for (let k = 0; k < call.nvars; k++) {
      const lv = this.locals.find((l) => !l.internal && l.reg === call.varBase + k && l.start === bodyPc);
      if (lv) { this.skipDecl.add(lv); ids.push(idNode(this.nameOf(lv))); } else ids.push(idNode(this.tempName(call.varBase + k)));
    }
    for (const l of this.locals) if (l.internal && l.start === bodyPc) this.skipDecl.add(l);
    const body = this.sub(i + 1, c, { exit: c + 2, innerStart: -1, until: -1 });
    this.popScope();
    out.push({ type: 'GenFor', ids, exprs, body });
    return c + 2;
  }
}

function failedFunction(proto, reason) {
  const params = [];
  for (let r = 0; r < proto.numParams; r++) params.push(idNode(`a${r + 1}`));
  const stmt = { type: 'CallStmt', call: { type: 'Call', fn: nameNode('error'), args: [strNode(`QuickSilver: this function could not be decompiled (${reason})`)], sugar: null } };
  stmt.comments = [{ kind: 'line', text: ` could not decompile (${reason}); ${proto.code.length} bytecode instructions` }];
  return { type: 'Func', params, vararg: !!proto.isVararg, body: [stmt], line: proto.line };
}

export function decompileFunction(f, opts) {
  const d = new FunctionDecompiler(f, opts);
  return d.decompile();
}

/**
 * @param {{version: number, main: object}} chunk result of parseChunk()
 * @returns {{ast: object, failures: string[]}}
 */
export function decompile(chunk) {
  const failures = [];
  const envUps = chunk.version === 0x54 ? [true] : [];
  let fn;
  try {
    fn = decompileFunction(chunk.main, { depth: 0, upNames: [], envUps, version: chunk.version });
  } catch (e) {
    if (!(e instanceof Unstructured || e instanceof LiftError)) throw e;
    failures.push(e.message);
    fn = failedFunction(chunk.main, e.message);
  }
  const countFailed = (node) => {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) { node.forEach(countFailed); return; }
    if (node.comments && node.comments.some((c) => /could not decompile/.test(c.text))) failures.push(node.comments[0].text.trim());
    for (const v of Object.values(node)) if (v && typeof v === 'object') countFailed(v);
  };
  countFailed(fn.body);
  return { ast: { type: 'Chunk', body: fn.body, endComments: [], features: new Set() }, failures };
}
