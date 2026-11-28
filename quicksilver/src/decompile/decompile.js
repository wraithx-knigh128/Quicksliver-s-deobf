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
import { isIdentifier, quoteString } from '../core/printer.js';

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
/**
 * Prompt XXXI: is P exactly the test of the value E a TESTSET (or a chain of them) stores? `or`: P is E itself, or `P1 or P2` over
 * `E1 or E2`; `and`: P is `not E`, or `P1 or P2` over `E1 and E2` (the chain fires when the first value is false). Identity, not
 * likeness: only then does P evaluate exactly what E evaluates, in the same order.
 */
function ownTest(P, E, op) {
  if (op === 'or' && P === E) return true;
  if (op === 'and' && P.type === 'Unary' && P.op === 'not' && P.arg === E) return true;
  return P.type === 'Binary' && P.op === 'or' && E.type === 'Binary' && E.op === op && ownTest(P.left, E.left, op) && ownTest(P.right, E.right, op);
}
const mkAnd = (a, b) => ({ type: 'Binary', op: 'and', left: a, right: b });
const mkOr = (a, b) => ({ type: 'Binary', op: 'or', left: a, right: b });
// Prompt XXX: value-exact helpers for short-circuit expressions whose value is used (not only their truth)
const RELATIONAL = new Set(['==', '~=', '<', '<=', '>', '>=']);
/** Is the value of e always a boolean (so `e and A` is false, not nil, when e fails)? */
const isBool = (e) => !!e && ((e.type === 'Binary' && RELATIONAL.has(e.op)) || (e.type === 'Unary' && e.op === 'not') || e.type === 'True' || e.type === 'False'
  || (e.type === 'Binary' && (e.op === 'and' || e.op === 'or') && isBool(e.left) && isBool(e.right)) || (e.type === 'Paren' && isBool(e.expr)));
/** `not e` as a value: only simplified where the result stays the same boolean. */
const vNot = (e) => {
  if (e.type === 'Unary' && e.op === 'not' && isBool(e.arg)) return e.arg;
  if (e.type === 'Binary' && (e.op === '==' || e.op === '~=')) return { ...e, op: e.op === '==' ? '~=' : '==' };
  if (e.type === 'True') return { type: 'False' };
  if (e.type === 'False') return { type: 'True' };
  return { type: 'Unary', op: 'not', arg: e };
};
/** The value of `if P then A else B` as one expression, where a rule makes it exact; null otherwise. */
const iteValue = (P, A, B) => {
  const t = (x) => x.type === 'True';
  const f = (x) => x.type === 'False';
  if (t(A) && f(B)) return isBool(P) ? P : null;
  if (f(A) && t(B)) return vNot(P);
  if (f(B)) return isBool(P) ? mkAnd(P, A) : null;          // P fails → false, which only a boolean P gives
  if (t(A)) return isBool(P) ? mkOr(P, B) : null;           // P holds → true, likewise
  if (f(A)) return mkAnd(vNot(P), B);                       // not P is boolean: false when P holds, else B
  if (t(B)) return mkOr(vNot(P), A);                        // not P is boolean: true when P fails, else A
  // One alternative ends in the other (the compiler sends both to the same code: `P and x or A` gives B = `x or A`). Exact for any P,
  // because only the truth of the left operand decides, and each part is evaluated once, in the original order:
  let x;
  // (the negations stand where only their truth is read, so mkNot's simplifications are exact there)
  if ((x = dropTail(B, 'or', A))) return mkOr(mkAnd(mkNot(P), x), A);   // P → A; else x or A
  if ((x = dropTail(B, 'and', A))) return mkAnd(mkOr(P, x), A);        // P → A; else x and A
  if ((x = dropTail(A, 'or', B))) return mkOr(mkAnd(P, x), B);         // P → x or B; else B
  if ((x = dropTail(A, 'and', B))) return mkAnd(mkOr(mkNot(P), x), B);  // P → x and B; else B
  return null;
};
/** `x1 op (x2 op tail)` without its last operand (`x1 op x2`; and/or are associative in value), when that operand is `tail` itself. */
const dropTail = (e, op, tail) => {
  if (!e || e.type !== 'Binary' || e.op !== op) return null;
  if (e.right === tail) return e.left;
  const r = dropTail(e.right, op, tail);
  return r ? { type: 'Binary', op, left: e.left, right: r } : null;
};
const exprSize = (e) => { let n = 0; const w = (x) => { if (!x || typeof x !== 'object') return; n++; for (const v of Object.values(x)) if (v && typeof v === 'object') w(v); }; w(e); return n; };

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
    if (opts.prune) this.pruneUnreachable();
    this.restoreLoopEnds();
    this.dethreadLoopExits();
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

  /**
   * Instructions nothing can reach (the junk an obfuscator puts after a jump, with jumps of its own among them) are removed, so that a jump over them is a jump over nothing and
   * the structure of what is left is not confused by targets that no run can arrive at.
   */
  /**
   * Prompt XXX: a loop whose body ends in `return` (or a jump elsewhere) has no closing `jmp` back to its head, and a generator
   * that threads jumps (MoonSec V3's rebuilt code) then sends every "next iteration" straight to the head from mid-body. The
   * structurer then saw the loop end at its last backward jump and the exit jump "leave its block", and abandoned the function.
   * Where that is the shape — code after the last backward jump that only the loop reaches, ending in an instruction that cannot
   * fall through, before the loop's exit — the missing closing `jmp head` is put back in front of the exit. It is reached only by
   * the jumps that went to the head already (the de-threading below redirects them to it), so nothing runs differently.
   */
  restoreLoopEnds() {
    for (let round = 0; round < 32; round++) {
      const ir = this.ir;
      const n = ir.length;
      const backs = new Map();
      for (let j = 0; j < n; j++) {
        const o = ir[j];
        if ((o.op === 'jmp' || o.op === 'cjmp') && o.t <= j) backs.set(o.t, Math.max(backs.has(o.t) ? backs.get(o.t) : -1, j));
      }
      let insertAt = -1;
      let head = -1;
      for (const [h, maxS] of [...backs].sort((a, b) => a[0] - b[0])) {
        if (ir[maxS].op === 'jmp') continue;
        let X = -1;
        for (let k = h; k <= maxS; k++) { const t = ir[k].t; if (typeof t === 'number' && t > maxS) { X = t; break; } }
        if (X < 0 || X - 1 <= maxS || X > n) continue;
        const last = ir[X - 1];
        if (!(last.op === 'ret' || (last.op === 'jmp' && last.t !== X))) continue;
        let ok = true;
        for (let k = 0; k < n && ok; k++) {
          const t = ir[k].t;
          if (typeof t !== 'number') continue;
          if ((k < h || k >= X) && t > maxS && t < X) ok = false;          // something outside jumps into the trailing code
          if (k >= h && k < X && t > X) ok = false;                         // a jump from the loop past its exit: not this shape
        }
        if (!ok) continue;
        insertAt = X;
        head = h;
        break;
      }
      if (insertAt < 0) return;
      for (const o of ir) if (typeof o.t === 'number' && o.t >= insertAt) o.t++;
      ir.splice(insertAt, 0, { op: 'jmp', t: head, pc: ir[insertAt - 1].pc, synthetic: true });
      this.n = ir.length;
    }
  }

  /**
   * Prompt XXX: Lua's code generator chains the jumps that are pending "to here" into the next JMP it emits (`fs->jpc`), so in
   * `while a do while b do … end break end` the inner loop's exit goes straight to the outer loop's exit, past the `break`. The
   * structurer then saw a jump leave the inner block and abandoned the function. A jump to T and a jump to an instruction that is only
   * `jmp T` do the same thing, so inside a loop whose natural exit (the instruction after its last backward jump) is `jmp T`, every
   * jump to T is sent to that exit instead. Measured on plain Lua 5.1 and 5.4 output and on MoonSec V3's rebuilt chunks.
   */
  dethreadLoopExits() {
    const ir = this.ir;
    const n = ir.length;
    const ends = new Map();
    // Prompt XXXI: numeric and generic for loops too (their back edge is FORLOOP / TFORLOOP): `for … do for … do if c then break end
    // end break end` sends the inner break through the outer one, past the inner loop's exit
    for (let k = 0; k < n; k++) {
      const o = ir[k];
      if ((o.op === 'jmp' || o.op === 'cjmp' || o.op === 'forloop' || o.op === 'tforloop') && typeof o.t === 'number' && o.t <= k) ends.set(o.t, Math.max(ends.has(o.t) ? ends.get(o.t) : -1, k));
    }
    const sameRet = (a, b) => a && b && a.op === 'ret' && b.op === 'ret' && a.n >= 0 && a.n === b.n && a.base === b.base;
    for (const [h, j] of ends) {
      const E = j + 1;
      const x = ir[E];
      // Prompt XXXI: the loop's exit is a `return` and a jump in the loop goes to another, identical `return` (the same registers,
      // nothing run in between): MoonSec V3's rebuilt code has a `while` whose condition leaves for a second `return` right after the
      // first. The two are the same jump; it is sent to the loop's exit.
      if (x && x.op === 'ret' && x.n >= 0) {
        for (let k = h; k <= j; k++) {
          const q = ir[k];
          if ((q.op === 'cjmp' || q.op === 'jmp') && typeof q.t === 'number' && q.t !== E && q.t > j && sameRet(ir[q.t], x)) q.t = E;
        }
        continue;
      }
      // Prompt XXXI: T may also lie before the loop, at the head of an enclosing one: MoonSec V3's rebuilt Luau code threads an inner
      // loop's exit through the `jmp head` that ends the outer loop's body (the outer loop's next iteration). Only a T inside this loop
      // (its own head, its body) is left alone.
      if (!x || x.op !== 'jmp' || typeof x.t !== 'number' || (x.t >= h && x.t <= E)) continue;
      for (let k = h; k <= j; k++) {
        const q = ir[k];
        if ((q.op === 'cjmp' || q.op === 'jmp') && q.t === x.t) q.t = E;
      }
    }
  }

  pruneUnreachable() {
    const { ir } = this;
    const n = ir.length;
    if (!n) return;
    const seen = new Uint8Array(n + 1);
    const stack = [0];
    while (stack.length) {
      const i = stack.pop();
      if (i < 0 || i >= n || seen[i]) continue;
      seen[i] = 1;
      for (const s of this.succs(i)) stack.push(s);
    }
    seen[n] = 1;
    if (seen.every((x) => x)) { return; }
    const at = new Array(n + 1);
    let k = 0;
    for (let i = 0; i <= n; i++) { at[i] = k; if (seen[i] && i < n) k++; }
    const kept = ir.filter((_, i) => seen[i]);
    for (const o of kept) if (o.t !== undefined) o.t = at[o.t];
    this.ir = kept;
    this.n = kept.length;
    this.pruned = true;
  }

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
    // backward dataflow over word bitsets (32 registers a word): live-in = reads ∪ (live-out − writes), live-out = ∪ live-in of
    // successors, iterated to the fixed point. (Prompt XXX: the byte-per-register version needed seconds on the largest rebuilt
    // MoonSec functions once their loop ends were restored; the result is the same.)
    const W = (R + 31) >>> 5;
    const inB = new Uint32Array((n + 1) * W);
    const outB = new Uint32Array((n + 1) * W);
    const killB = new Uint32Array(n * W);
    const genB = new Uint32Array(n * W);
    for (let i = 0; i < n; i++) {
      if (!(ir[i].op === 'testset' || ir[i].op === 'forloop')) for (const w of writes[i]) if (w >= 0 && w < R) killB[i * W + (w >>> 5)] |= 1 << (w & 31);
      for (const rd of reads[i]) if (rd >= 0 && rd < R) genB[i * W + (rd >>> 5)] |= 1 << (rd & 31);
    }
    const succ = Array.from({ length: n }, (_, i) => this.succs(i).filter((s) => s <= n));
    let changed = true;
    let guard = 0;
    while (changed && guard++ < 1000) {
      changed = false;
      for (let i = n - 1; i >= 0; i--) {
        const o = i * W;
        // Prompt XXX: a TESTSET writes its destination on the jump edge only, so the destination is not live into it from the jump
        // target (it was treated as live on both edges: a temporary in that register — `M.V` of `M.V == "Boss" and isBoss` — then
        // looked live after its single use and the value condition could not be read)
        const ts = ir[i].op === 'testset' ? ir[i] : null;
        const tsWord = ts && ts.d >= 0 && ts.d < R ? ts.d >>> 5 : -1;
        const tsMask = tsWord >= 0 ? ~(1 << (ts.d & 31)) : -1;
        for (const s of succ[i]) {
          const so = s * W;
          const edge = ts && s === ts.t && s !== i + 1;
          for (let w = 0; w < W; w++) {
            const inc = edge && w === tsWord ? inB[so + w] & tsMask : inB[so + w];
            const v = outB[o + w] | inc;
            if (v !== outB[o + w]) { outB[o + w] = v; changed = true; }
          }
        }
        for (let w = 0; w < W; w++) { const v = (outB[o + w] & ~killB[o + w]) | genB[o + w]; if (v !== inB[o + w]) { inB[o + w] = v; changed = true; } }
      }
    }
    const liveOut = new Array(n + 1);
    for (let i = 0; i <= n; i++) {
      const row = new Uint8Array(R);
      const o = i * W;
      for (let w = 0; w < W; w++) { let v = outB[o + w]; while (v) { const b = 31 - Math.clz32(v & -v); row[(w << 5) + b] = 1; v &= v - 1; } }
      liveOut[i] = row;
    }
    this.liveOut = liveOut;
    this.reads = reads;
    this.writes = writes;
  }

  /**
   * Without local names a register that some closure captures has to be a named variable, but only the values that can
   * reach the capture: a temporary that is overwritten before any closure sees the register is an ordinary temporary.
   * Anything the scan cannot follow in a straight line is assumed to reach it.
   */
  writeReachesCapture(i, d) {
    const { ir, n } = this;
    const own = ir[i];
    if (own.op === 'closure' && own.ups.some((u) => u.instack && u.idx === d)) return true;   // a function that refers to itself
    // Prompt XXX: follow every path (not only the straight line up to the first jump, which answered "yes" at any branch) and
    // stop where the register is written again: only a value that can still be in the register when a closure captures it has
    // to be a named variable. The straight-line answer made every temporary in a register some closure captures later — the
    // tested values of an `elseif a and b or c` — into a variable, and the condition could not be read.
    const seen = new Uint8Array(n + 1);
    const stack = [...this.succs(i)];
    while (stack.length) {
      const k = stack.pop();
      if (k < 0 || k >= n || seen[k]) continue;
      seen[k] = 1;
      const x = ir[k];
      if (x.op === 'closure' && x.ups.some((u) => u.instack && u.idx === d)) return true;
      if (this.writes[k].includes(d)) continue;
      for (const s of this.succs(k)) stack.push(s);
    }
    return false;
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
        // a captured register has to be a named variable, except that a fresh table may still collect its fields
        // first: it is written out under its name as soon as something needs the name (see stepClosure)
        if (this.captured.has(d) && o.op !== 'newtable' && this.writeReachesCapture(i, d)) continue;
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
          // A compiler builds a temporary in the register its consumer reads. A function that is copied out of its
          // register with MOVE was a variable (`local function f`), so it keeps a name instead of becoming an IIFE.
          if (yes && o.op === 'closure' && ir[j].op === 'move') yes = false;
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

  /**
   * Without debug information a register is one variable for the whole function, which is wrong for a register a closure captured: once
   * a CLOSE covering it has run, the closure keeps the old variable and the register is a new one. Each CLOSE starts a new generation of
   * the captured registers it covers, and a later generation gets a name of its own.
   */
  generation(r) {
    if (this.hasDebug || !this.captured.has(r) || this.curIdx === undefined) return 0;
    if (!this.closes) this.closes = this.ir.map((o, j) => (o.op === 'close' ? [j, o.from] : null)).filter(Boolean);
    let g = 0;
    for (const [j, from] of this.closes) if (j < this.curIdx && from <= r) g++;
    return g;
  }

  tempName(r) {
    const g = this.generation(r);
    const base = this.o.depth === 0 ? `_r${r}` : `_r${this.o.depth}_${r}`;
    const name = g ? `${base}_c${g}` : base;
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
    if (e.method) {
      // Something else has to run between `obj:method` and its call (an argument that needs statements of its own, as
      // after inlining). Lua's own order is: read the object, look the method up, evaluate the arguments, call; so the
      // two halves are written out as temporaries and the call uses them.
      out.push({ type: 'Assign', targets: [nameNode(this.tempName(r + 1))], values: [e.method.obj] });
      out.push({ type: 'Assign', targets: [nameNode(this.tempName(r))], values: [this.indexNode(nameNode(this.tempName(r + 1)), e.method.key)] });
      return;
    }
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
    let result = build(this.consumer(used, true));
    if (!this.orderOk(used)) {
      this.P = snapP;
      this.topEntry = snapTop;
      // Prompt XXX: first the precise repair — write out, in their order, the pending values with calls in them that are older
      // than the newest such value, and inline the rest; only if the order still cannot be kept, write out everything.
      const repaired = !snapTop && !this.multi ? this.repairOrder(out, build) : null;
      if (!repaired) {
        this.flushAll(out);
        this.lastUsed = [];
        return build(this.consumer([], false));
      }
      result = repaired.result;
      this.lastUsed = repaired.used;
    } else this.lastUsed = used;
    if (mode === 'stmt') {
      const rest = [...this.P.entries()].sort((a, b) => a[1].seq - b[1].seq);
      for (const [r, e] of rest) this.flushEntry(out, r, e);
      this.P.clear();
      if (this.multi) this.flushMulti(out);
    }
    return result;
  }

  repairOrder(out, build) {
    const impure = [...this.P.values()].filter((e) => e.impure);
    if (impure.length < 2) return null;
    const newest = Math.max(...impure.map((e) => e.seq));
    const older = [...this.P.entries()].filter(([, e]) => e.impure && e.seq < newest && e.selfOf === undefined && !e.method).sort((a, b) => a[1].seq - b[1].seq);
    if (!older.length) return null;
    const before = new Map(this.P);
    const mark = out.length;
    for (const [r, e] of older) { this.flushEntry(out, r, e); this.P.delete(r); }
    const used = [];
    const result = build(this.consumer(used, true));
    if (this.orderOk(used)) return { result, used };
    out.length = mark;
    this.P = before;
    return null;
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
      // Prompt XXX: an expression built from consumed values that hold calls (a moved, indexed, concatenated or computed call
      // result) is itself impure, and its side effects happened when the earliest of those calls ran — not now. Marking it pure,
      // with a fresh position, let it be inlined after calls that ran later (`local x = f().y; h(g(), x)` became `h(g(), f().y)`).
      const held = (this.lastUsed || []).filter((e) => e.impure);
      const seq = this.seq++;
      this.P.set(d, { expr, impure: impure || held.length > 0, seq: held.length ? Math.min(...held.map((e) => e.seq)) : seq });
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
    // (results the program never reads leave no local behind: `local _, e = pcall(f)` has only `e`; the first ones are named `_`)
    if (this.multi && lvs.length >= 1 && lvs[0].reg >= this.multi.base && lvs[0].reg - this.multi.base + lvs.length <= this.multi.n
      && lvs.every((lv, k) => lv.reg === lvs[0].reg + k)) {
      const m = this.multi;
      this.multi = null;
      const rest = [];
      for (let k = lvs.length; k < m.n; k++) rest.push(m.base + k);
      this.flushAll(out);
      const lead = Array.from({ length: lvs[0].reg - m.base }, () => idNode('_'));
      out.push({ type: 'Local', ids: [...lead, ...names], values: [m.expr] });
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
      this.lastTested = a;   // the tested value itself (valueRegion: a TEST on the result register delivers it)
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
  parseCondNode(i, hi, valueMode = false) {
    const saveP = new Map(this.P);
    const saveSeq = this.seq;
    const saveTop = this.topEntry;
    const saveMulti = this.multi;
    const scratch = [];
    let k = i;
    const fail = () => { this.P = saveP; this.seq = saveSeq; this.topEntry = saveTop; this.multi = saveMulti; return null; };
    // Prompt XXX: SETLIST / SETINDEX fill a table constructor inside the condition (`#f({ a, b }) > 0`); one that writes a statement
    // instead (the table is not a pending constructor) leaves `scratch` non-empty, and the node is refused as before
    const setupOps = new Set(['move', 'loadk', 'loadnil', 'getup', 'getglobal', 'index', 'bin', 'un', 'concat', 'self', 'call', 'vararg', 'newtable', 'closure', 'setlist', 'setindex']);
    while (k < hi) {
      const o = this.ir[k];
      if (k > i && this.isTarget[k]) return fail();
      // a local that begins inside the condition cannot be part of it. Prompt XXXI (KNOWN-ISSUES #115): one already declared is not
      // such a local: Lua 5.4's GETTABUP is two IR ops with one pc, so a local beginning at that pc was declared before the first of them
      if (this.startAt.has(o.pc) && this.localsStartingAt(o.pc).some((lv) => !lv.declared) && k > i) return fail();
      if (o.op === 'cjmp' || o.op === 'testset') {
        const used = [];
        const consume = this.consumer(used, true);
        let P;
        let assign = null;
        if (o.op === 'cjmp') P = this.predicateOf(o, consume);
        else {
          // TESTSET: when the tested value counts, it is also stored in the destination register
          const sExpr = consume({ r: o.s }, o.pc);
          // as a statement the tested value is written twice (tested, then assigned), so a call in it would run twice; in a value
          // region (valueMode) it appears once, in `x and rest` / `x or rest`
          if (used.some((e) => e.impure) && !valueMode) return fail();
          P = o.sense ? sExpr : mkNot(sExpr);
          assign = { d: o.d, expr: sExpr, op: o.sense ? 'or' : 'and', pc: o.pc, parts: [{ expr: sExpr, s: o.s, pc: o.pc }] };
        }
        if (!this.orderOk(used) || this.P.size || this.topEntry || this.multi) return fail();
        if (scratch.length) return fail();
        return { P, t: o.t, start: i, end: k, next: k + 1, assign, op: o, tested: o.op === 'cjmp' && o.kind === 'test' ? this.lastTested : null };
      }
      if (!setupOps.has(o.op)) return fail();
      // a call whose results are all passed on to the next call (`f(g(x))`) is part of the condition; any other open result is not
      const passesOn = o.op === 'call' && o.nres < 0 && !o.tail && this.ir[k + 1] && this.ir[k + 1].op === 'call' && this.ir[k + 1].nargs === -1;
      if (o.op === 'call' && (o.tail || (o.nres < 0 && !passesOn) || o.nres > 1)) return fail();
      try { this.stepSimple(k, scratch); } catch (e) { if (e instanceof Unstructured) return fail(); throw e; }
      if (scratch.length) return fail();
      k++;
    }
    return fail();
  }

  /**
   * Prompt XXX: a short-circuit expression whose value is kept (`return a ~= b and c and c.x > 0`) is compiled to condition
   * nodes whose jumps end at three places: a `false` load (F), a `true` load (T) and the join after them (E), where TESTSET
   * nodes also deliver the value they tested. Its value at E is rebuilt from the nodes as one expression, by rules that are exact
   * in Lua (`if P then A else false` is `P and A` only when P is boolean, ...). Any node, jump or combination outside those rules
   * leaves the region to the statement structuring, as before; this used to abandon the whole function in many shapes
   * ("unstructured jump", "conditional jump leaves its block").
   */
  valueRegion(i, hi, out) {
    if (this.topEntry || this.multi || this.P.size) return -1;
    if (!this.boolEnds) {
      this.boolEnds = [];
      for (let k = 0; k + 2 < this.n; k++) {
        const a = this.ir[k];
        const b = this.ir[k + 1];
        const c = this.ir[k + 2];
        if (a.op === 'loadk' && a.v === false && b.op === 'jmp' && b.t === k + 3 && c.op === 'loadk' && c.v === true && c.d === a.d) this.boolEnds.push(k);
      }
    }
    if (!this.conditionAhead(i, hi)) return -1;
    let R;
    let F = -2;
    let T = -2;
    let E;
    let end;
    const bf = this.boolEnds.find((k) => k > i);
    if (bf !== undefined && bf - i <= 400 && bf + 3 <= hi) {
      // a boolean result: the false load (F), the true load (T), the join (E)
      F = bf; T = F + 2; E = F + 3; end = F; R = this.ir[F].d;
    } else {
      // no boolean result (`x = a and b or c`): the join is where the expression's TESTSETs deliver their value
      let ts = -1;
      for (let k = i; k < hi && k < i + 400; k++) {
        const o = this.ir[k];
        if (o.op === 'testset') { ts = k; break; }
        if (o.op === 'ret' || o.op === 'forprep' || o.op === 'tforprep' || o.op === 'forloop' || o.op === 'tforloop' || o.op === 'tforcall' || o.op === 'setlist' || o.op === 'setup' || o.op === 'setglobal' || o.op === 'setindex') break;
        if (o.op === 'jmp' && o.t <= k) break;
      }
      if (ts < 0) return -1;
      R = this.ir[ts].d; E = this.ir[ts].t; end = E;
      if (E <= ts || E > hi) return -1;
    }
    // the region is entered at i only, and the join at E is reached only from inside it
    for (let k = 0; k < this.n; k++) {
      if (k >= i && k < E) continue;
      const t = this.ir[k].t;
      if (typeof t === 'number' && t > i && t <= E) return -1;
    }
    // a value computed into R and tested in place by a TEST that jumps to E is that node's value: it stays inline, although R is
    // live after the test (it is what E receives)
    const forced = [];
    const force = (k) => { if (!this.forward[k]) { forced.push(k); this.forward[k] = 1; } };
    for (let k = i + 1; k < end; k++) {
      const q = this.ir[k];
      if (q.op === 'cjmp' && q.kind === 'test' && regOf(q.a) === R && q.t === E && this.writes[k - 1].length === 1 && this.writes[k - 1][0] === R) force(k - 1);
    }
    const saved = { P: new Map(this.P), seq: this.seq, top: this.topEntry, multi: this.multi };
    const restore = () => { this.P = saved.P; this.seq = saved.seq; this.topEntry = saved.top; this.multi = saved.multi; for (const k of forced) this.forward[k] = 0; return -1; };
    const nodes = new Map();
    let pos = i;
    while (pos < end) {
      let nd = this.parseCondNode(pos, end, true);
      if (nd) {
        // the compiler tests a value that is already in the result register with TEST, not TESTSET: on the jump it is the value
        if (!nd.assign && nd.t === E && nd.op.kind === 'test' && regOf(nd.op.a) === R && nd.tested) nd.assign = { d: R, expr: nd.tested, op: nd.op.sense ? 'or' : 'and', pc: nd.op.pc };
        if (nd.assign) { if (nd.assign.d !== R || nd.t !== E) return restore(); }
        else if (!(nd.t === F || nd.t === T || (nd.t > nd.end && nd.t < end))) return restore();
      } else {
        nd = this.parseValueNode(pos, end, R, E, F < 0, force);
        if (!nd) return restore();
      }
      nodes.set(pos, nd);
      pos = nd.next;
    }
    if (pos !== end) return restore();
    for (const nd of nodes.values()) if (!nd.value && !nd.assign && nd.t !== F && nd.t !== T && !nodes.has(nd.t)) return restore();
    const memo = new Map();
    const V = (p) => {
      if (p === F) return { type: 'False' };
      if (p === T) return { type: 'True' };
      if (memo.has(p)) return memo.get(p);
      const nd = nodes.get(p);
      if (!nd) return null;
      if (nd.value) { memo.set(p, nd.value); return nd.value; }
      const rest = V(nd.next);
      if (rest === null) return null;
      let v;
      if (nd.assign) v = nd.assign.op === 'and' ? mkAnd(nd.assign.expr, rest) : mkOr(nd.assign.expr, rest);
      else { const a = V(nd.t); v = a === null ? null : iteValue(nd.P, a, rest); }
      memo.set(p, v);
      return v;
    };
    const expr = V(i);
    if (!expr || exprSize(expr) > 4000) return restore();
    let impure = false;
    for (let k = i; k < end; k++) if (this.ir[k].op === 'call') impure = true;
    const ePc = this.ir[E] ? this.ir[E].pc : this.ir[end - 1].pc;
    const once = this.ir[E] && this.reads[E].filter((x) => x === R).length === 1 && (!this.liveOut[E][R] || this.writes[E].includes(R)) && !this.localActive(R, ePc);
    // `local r = a and b or c`: the local begins at E, where its declaration takes the value
    const lvE = this.ir[E] ? this.localActive(R, ePc) : null;
    const declaredAtE = lvE && lvE.start === ePc && !lvE.declared && !this.localActive(R, this.ir[i].pc) && E < hi;
    if (once || declaredAtE) this.P.set(R, { expr, impure, seq: this.seq++ });
    else out.push({ type: 'Assign', targets: [this.regTarget(R, ePc)], values: [expr] });
    return E;
  }

  /**
   * One value of a value region: straight-line code that leaves the value in R and jumps to the join E (or, with no boolean
   * result, falls into it). Its expression is what R holds at the jump.
   */
  parseValueNode(pos, end, R, E, mayFallIn, force) {
    const save = { P: new Map(this.P), seq: this.seq, top: this.topEntry, multi: this.multi };
    const fail = () => { this.P = save.P; this.seq = save.seq; this.topEntry = save.top; this.multi = save.multi; return null; };
    const setupOps = new Set(['move', 'loadk', 'loadnil', 'getup', 'getglobal', 'index', 'bin', 'un', 'concat', 'self', 'call', 'vararg', 'newtable', 'closure', 'setlist', 'setindex']);
    const scratch = [];
    let k = pos;
    let next = -1;
    while (k <= end) {
      if (k === end) { if (!mayFallIn) return fail(); next = end; break; }
      const o = this.ir[k];
      if (k > pos && this.isTarget[k]) return fail();
      if (o.op === 'jmp') { if (o.t !== E) return fail(); next = k + 1; break; }
      if (!setupOps.has(o.op)) return fail();
      if (o.op === 'call' && (o.tail || o.nres !== 1)) return fail();
      if (o.op === 'vararg' && o.n !== 1) return fail();
      if (this.writes[k].includes(R)) force(k);
      try { this.stepSimple(k, scratch); } catch (e) { if (e instanceof Unstructured) return fail(); throw e; }
      if (scratch.length) return fail();
      k++;
    }
    const e = this.P.get(R);
    if (!e || this.P.size !== 1 || this.topEntry || this.multi) return fail();
    this.P.delete(R);
    return { value: e.expr, start: pos, end: k, next };
  }

  /** Is the code from i only the setup of a condition (computations, then a conditional jump), with nothing jumping into it? */
  conditionAhead(i, hi) {
    const setup = new Set(['move', 'loadk', 'loadnil', 'getup', 'getglobal', 'index', 'bin', 'un', 'concat', 'self', 'call', 'vararg', 'newtable', 'closure', 'setlist', 'setindex']);
    for (let k = i; k < hi && k < i + 64; k++) {
      const o = this.ir[k];
      if (k > i && this.isTarget[k]) return false;
      if (o.op === 'cjmp' || o.op === 'testset') return true;
      if (!setup.has(o.op)) return false;
    }
    return false;
  }

  /** Greedily parse conditions, then keep the longest prefix that folds into one and/or condition. */
  parseGroup(i, hi, allowPending = false) {
    // allowPending: values computed before the condition may be inlined into it, if the condition consumes every one of them
    // (parseCondNode still requires nothing pending at the jump, and orderOk keeps the order)
    if ((this.P.size && !allowPending) || this.topEntry || this.multi) return null;
    const nodes = [];
    let k = i;
    while (k < hi) {
      // Prompt XXX: a loop begins here, so the condition ends before it. `if on then while on do … end end` jumps to the same place
      // from both tests; read as one condition (`on and on`), the loop's head was inside it and its back-edge became unstructured.
      if (k > i && this.loopAt && this.loopAt.has(k)) break;
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
                // Prompt XXX: `A.value op B.value` is the first value that fired only when A fires exactly when its own value
                // decides (a plain TESTSET). A compound A (`b and a`) can fail while its value is truthy: merging it gave
                // `a or c` where the original yields c (found by the decompiler property test).
                const own = A.assign.op === 'or' ? A.P === A.assign.expr : (A.P.type === 'Unary' && A.P.op === 'not' && A.P.arg === A.assign.expr);
                if (!own) continue;
                const op = A.assign.op;
                merged = { P: mkOr(A.P, B.P), t: B.t, f: B.f, assign: { ...A.assign, parts: [...A.assign.parts, ...B.assign.parts], expr: { type: 'Binary', op, left: A.assign.expr, right: B.assign.expr } } };
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
      // conditions (without debug names, the results of a call nothing has named are written out first: they cannot be part of one)
      const vr = this.valueRegion(i, hi, out);
      if (vr >= 0) { i = vr; continue; }
      let g = this.parseGroup(i, hi);
      // Prompt XXX: values still pending when a condition begins (`local r = request(t)` then `if r.StatusCode ~= 200`) kept the
      // condition from being read at all — the function was abandoned ("condition could not be folded"). They run before the
      // condition either way: write them out, and read the condition.
      if (!g && this.P.size && !this.topEntry && !this.multi && this.conditionAhead(i, hi)) g = this.parseGroup(i, hi, true);
      if (!g && this.P.size && !this.topEntry && !this.multi && this.conditionAhead(i, hi)) {
        const saved = new Map(this.P);
        const written = [];
        this.flushAll(written);
        const again = this.parseGroup(i, hi);
        if (again) { out.push(...written); g = again; } else this.P = saved;
      }
      if (!g && this.multi && !this.hasDebug) {
        const saved = this.multi;
        const written = [];
        this.flushMulti(written);
        const again = this.parseGroup(i, hi);
        if (again) { out.push(...written); g = again; } else this.multi = saved;
      }
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
    // Prompt XXXI (KNOWN-ISSUES #114): a TESTSET's condition and the value it stores are one expression. Written `if E then x = E`,
    // E runs twice (`x = t.a or x` read t.a, and so called its __index, twice). Where the condition is exactly the test of the stored
    // value, the statement is written so that E runs once, in its place: `x = E or x` when both outcomes continue at the same place,
    // `x = E or c` when the fall-through code is that one assignment, and otherwise E goes to the register the bytecode tested
    // (`_rS = E; if _rS then x = _rS else ... end`), unless E is a plain local or a constant, which can be read twice.
    const own = g.assign && ownTest(g.P, g.assign.expr, g.assign.op);
    // a guard before the tested value (`x = A and B or c`, read later): the condition is `A and <B's own test>`, and A runs first, then B
    const guard = !own && g.assign && g.assign.op === 'or' && g.P.type === 'Binary' && g.P.op === 'and' && ownTest(g.P.right, g.assign.expr, 'or') ? g.P.left : null;
    const guarded = (rest) => ({ type: 'Binary', op: 'or', left: { type: 'Binary', op: 'and', left: guard, right: g.assign.expr }, right: rest });
    if (g.t === g.f) {
      // both outcomes continue at the same place: only the (possible) assignment of a value condition remains
      if (g.assign) {
        const target = this.regTarget(g.assign.d, g.assign.pc);
        if (own) out.push({ type: 'Assign', targets: [target], values: [{ type: 'Binary', op: g.assign.op, left: g.assign.expr, right: nameNode(target.name) }] });
        else if (guard) out.push({ type: 'Assign', targets: [target], values: [guarded(nameNode(target.name))] });
        else out.push({ type: 'If', clauses: [{ cond: g.P, body: [{ type: 'Assign', targets: [target], values: [g.assign.expr] }] }], orelse: null });
      } else out.push({ type: 'If', clauses: [{ cond: g.P, body: [] }], orelse: null });
      return bodyStart;
    }
    if (g.assign) {
      // a value condition: on the jump edge the register receives the value, otherwise the fall-through code computes it
      if (!jumpWhenP || X <= g.end || X > hi) throw new Unstructured(`value condition at ${this.ir[g.end].pc} is not in a recognised shape`);
      const target = this.regTarget(g.assign.d, g.assign.pc);
      const fall = this.sub(bodyStart, X, ctx);
      const only = fall.length === 1 && fall[0].type === 'Assign' && fall[0].targets.length === 1 && fall[0].values.length === 1 ? fall[0] : null;
      if ((own || guard) && only && only.targets[0].type === 'Name' && only.targets[0].name === target.name) {
        out.push({ type: 'Assign', targets: [target], values: [own ? { type: 'Binary', op: g.assign.op, left: g.assign.expr, right: only.values[0] } : guarded(only.values[0])] });
        return X;
      }
      const chain = own ? this.valueChain(g.assign, target, fall) : null;
      if (chain) { out.push(...chain); return X; }
      out.push({ type: 'If', clauses: [{ cond: g.P, body: [{ type: 'Assign', targets: [target], values: [g.assign.expr] }] }], orelse: fall.length ? fall : null });
      return X;
    }
    if (ctx.exit !== null && X === ctx.exit) {
      out.push({ type: 'If', clauses: [{ cond: toX, body: [{ type: 'Break' }] }], orelse: null });
      return bodyStart;
    }
    // Luau `continue` (Prompt XXXI): a conditional jump from inside a nested block to the loop's continue point. Where the block
    // is the loop body itself (X === hi) the ordinary `if` is written, as before; Lua 5.1 output never gets a `continue`.
    if (this.o.luau && ctx.cont != null && X === ctx.cont && X > hi) {
      out.push({ type: 'If', clauses: [{ cond: toX, body: [{ type: 'Continue' }] }], orelse: null });
      return bodyStart;
    }
    if (X <= g.end) throw new Unstructured(`backward conditional jump at ${this.ir[g.end].pc}`);
    // Prompt XXXI: a jump to a `return` that returns nothing is that `return` (nothing runs in between)
    if (X > hi && this.plainReturn(X)) {
      out.push({ type: 'If', clauses: [{ cond: toX, body: [{ type: 'Return', values: [] }] }], orelse: null });
      return bodyStart;
    }
    if (X > hi) throw new Unstructured(`conditional jump at ${this.ir[g.end].pc} leaves its block`);
    // `if ... else ... end`: the compiler sends jumps that would reach the closing `jmp` of the then-branch straight to
    // its destination. Undo that, so that they are plain jumps to the end of the then-branch.
    // (Prompt XXXI, Luau: a `jmp` / conditional jump to the loop's continue point is left alone, since it is a `continue` of its own and,
    // sent to the closing `jmp`, would look like the end of an inner then-branch; a TESTSET's jump delivers a value and is redirected
    // as before)
    const closing = this.ir[X - 1];
    if (X - 1 >= bodyStart && closing.op === 'jmp' && closing.t > X && closing.t <= hi && (ctx.exit === null || closing.t !== ctx.exit) && !this.isLoopBackEdge(X - 1)) {
      const keepContinues = this.o.luau && ctx.cont != null && closing.t === ctx.cont;
      for (let k = bodyStart; k < X - 1; k++) {
        const q = this.ir[k];
        if (keepContinues && q.op !== 'testset') continue;
        if ((q.op === 'jmp' || q.op === 'cjmp' || q.op === 'testset') && q.t === closing.t) { q.t = X - 1; this.isTarget[X - 1] = 1; }
      }
    }
    // A jump from inside the fall-through code to a place beyond X (`a and b or c`): both branches end at that
    // place, and the code between X and it runs on both paths, so it is written out twice.
    let shared = X;
    for (let k = bodyStart; k < X; k++) {
      const q = this.ir[k];
      if (k === X - 1 && q.op === 'jmp') continue; // the jump that closes an if/else
      if ((q.op === 'jmp' || q.op === 'cjmp' || q.op === 'testset') && q.t > shared && q.t <= hi && (ctx.exit === null || q.t !== ctx.exit) && !(this.o.luau && ctx.cont != null && q.t === ctx.cont && q.op !== 'testset')) shared = q.t;
    }
    // Prompt XXXI: a tail too large to duplicate that only jumps to a `return` of nothing made: those jumps are written `return` where
    // they are (the nested blocks do so), and the tail is the one before them, if any. Smaller tails are duplicated as before.
    if (shared > X && shared - X > 80) {
      let other = X;
      for (let k = bodyStart; k < X; k++) {
        const q = this.ir[k];
        if (k === X - 1 && q.op === 'jmp') continue;
        if ((q.op === 'jmp' || q.op === 'cjmp' || q.op === 'testset') && q.t > other && q.t <= hi && (ctx.exit === null || q.t !== ctx.exit) && !(this.o.luau && ctx.cont != null && q.t === ctx.cont && q.op !== 'testset') && !(q.op !== 'testset' && this.plainReturn(q.t))) other = q.t;
      }
      if (other <= X || other - X <= 80) shared = other;
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
    // Prompt XXXI, Luau: a then-block that ends in a jump to the loop's continue point and also jumps to X itself is no if/else
    // (no then-branch of one can reach its else): it ends in `if not c then continue end`, and X is what follows the `if`.
    const continueEnd = this.o.luau && ctx.cont != null && tail.op === 'jmp' && tail.t === ctx.cont && this.jumpsTo(bodyStart, X - 1, X);
    if (X - 1 >= bodyStart && tail.op === 'jmp' && tail.t > X && tail.t <= hi && (ctx.exit === null || tail.t !== ctx.exit) && !this.isLoopBackEdge(X - 1) && !continueEnd) {
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

  /** Prompt XXXI: is the instruction at idx a `return` with no values (so a jump to it is `return`)? */
  plainReturn(idx) {
    const o = this.ir[idx];
    return !!o && o.op === 'ret' && o.n === 0;
  }

  /** Does a jump in [lo, hi) go to T? */
  jumpsTo(lo, hi, T) {
    for (let k = lo; k < hi; k++) { const q = this.ir[k]; if ((q.op === 'jmp' || q.op === 'cjmp' || q.op === 'testset') && q.t === T) return true; }
    return false;
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
    const k = stmts.findIndex((s) => s.type === 'Return' || s.type === 'Break' || s.type === 'Continue');
    return k >= 0 && k < stmts.length - 1 ? stmts.slice(0, k + 1) : stmts;
  }

  loop(s, loop, out, ctx) {
    const { j } = loop;
    const exit = j + 1;
    // Prompt XXXI (KNOWN-ISSUES #112): the continue point of a `while` loop is its closing `jmp` (jumps to the head were sent there);
    // a Luau program reaches it from mid-body with `continue`. Repeat and for loops start a context without one.
    const lctx = { exit, innerStart: -1, until: -1, cont: loop.kind === 'jmp' ? j : null };
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
    this.curIdx = i;
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
        this.define(out, i, o.d, false, () => this.globalRef(o.name));
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
        // Prompt XXX: an object or key whose value cannot stay inline in order is written out first (tx), as for any other
        // expression; this used to abandon the whole function ("method lookup out of order")
        let obj;
        let key;
        this.tx(out, 'pending', (c) => { obj = c(o.obj, pc); key = c(o.key, pc); return obj; });
        const held = (this.lastUsed || []).filter((e) => e.impure);
        const idx = this.indexNode(obj, key);
        this.P.set(o.d, { expr: idx, method: { obj, key }, impure: false, seq: this.seq++ });
        const seq = this.seq++;
        this.P.set(o.d + 1, { expr: obj, selfOf: o.d, impure: held.length > 0, seq: held.length ? Math.min(...held.map((e) => e.seq)) : seq });
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
        this.assignStmt(out, (c) => ({ target: this.globalRef(o.name), value: c(o.val, pc) }));
        return i + 1;
      case 'setindex': return this.stepSetIndex(i, out);
      case 'setlist': return this.stepSetList(i, out);
      case 'close': return i + 1;
      case 'jmp': {
        if (simple) throw new Unstructured('jump inside a condition');
        if (o.t === i + 1) return i + 1;                         // a jump to the next instruction does nothing (what is left of a jump over removed junk)
        if (ctx.exit !== null && o.t === ctx.exit) { this.flushAll(out); out.push({ type: 'Break' }); return i + 1; }
        if (o.t > hi && this.plainReturn(o.t)) {
          // Prompt XXXI: a jump out of the block to a `return` of nothing is that `return`, where nothing after it here can be reached
          let dead = true;
          for (let k = i + 1; k < hi; k++) if (this.isTarget[k]) { dead = false; break; }
          if (dead) { this.flushAll(out); out.push({ type: 'Return', values: [] }); return hi; }
        }
        if (this.o.luau && ctx.cont != null && o.t === ctx.cont && o.t > hi) {
          // Luau `continue` (Prompt XXXI), only where nothing after it in this block can be reached
          let dead = true;
          for (let k = i + 1; k < hi; k++) if (this.isTarget[k]) { dead = false; break; }
          if (dead) { this.flushAll(out); out.push({ type: 'Continue' }); return hi; }
        }
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

  /** A global is a name when it can be one; a global whose name is not an identifier (or is a keyword) is a field of `_G`. */
  globalRef(name) {
    if (typeof name === 'string' && isIdentifier(name) && !KEYWORDS.has(name)) return nameNode(name);
    return { type: 'Index', obj: nameNode('_G'), key: { type: 'String', value: String(name), raw: quoteString(String(name)), long: false }, dot: false };
  }

  takeTop() {
    if (!this.topEntry) throw new Unstructured('open value list is missing its producer');
    const e = this.topEntry;
    this.topEntry = null;
    return e.expr;
  }

  /**
   * Prompt XXXI: `x = E1 or E2 ... or <fall-through code>` as statements in which every Ei runs once and in order, as the bytecode runs
   * them: a part that cannot be read twice is first stored in the register its TESTSET tested (`_r6 = t[k]`), and the parts after an
   * impure one are only reached on its false edge. Null when there is nothing to fix (every part is a local or a constant).
   */
  valueChain(assign, target, fall) {
    const op = assign.op;
    const leaf = (e) => ({ ...e });
    const join = (es) => es.reduce((l, r) => ({ type: 'Binary', op, left: l, right: r }));
    const test = (es) => (op === 'or' ? join(es) : es.map((e) => mkNot(e)).reduce((l, r) => mkOr(l, r)));
    const emit = (parts) => {
      if (parts.every((p) => this.readsTwice(p.expr))) {
        return [{ type: 'If', clauses: [{ cond: test(parts.map((p) => leaf(p.expr))), body: [{ type: 'Assign', targets: [target], values: [join(parts.map((p) => leaf(p.expr)))] }] }], orelse: fall.length ? fall : null }];
      }
      const [p, ...rest] = parts;
      const reg = this.regTarget(p.s, p.pc);
      const stored = { type: 'Assign', targets: [reg], values: [p.expr] };
      const held = { ...p, expr: nameNode(reg.name) };
      if (rest.every((q) => this.readsTwice(q.expr))) return [stored, ...emit([held, ...rest])];
      const inner = emit(rest);
      const cond = op === 'or' ? nameNode(reg.name) : { type: 'Unary', op: 'not', arg: nameNode(reg.name) };
      return [stored, { type: 'If', clauses: [{ cond, body: [{ type: 'Assign', targets: [target], values: [nameNode(reg.name)] }] }], orelse: inner }];
    };
    if (!assign.parts || assign.parts.every((p) => this.readsTwice(p.expr))) return null;
    return emit(assign.parts);
  }

  /** Prompt XXXI: an expression that may be written twice without running anything twice: a constant, or a local of this function. */
  readsTwice(e) {
    if (e.type === 'Nil' || e.type === 'True' || e.type === 'False' || e.type === 'Number' || e.type === 'String') return true;
    return e.type === 'Name' && (this.hoisted.has(e.name) || this.locals.some((lv) => lv.outName === e.name));
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
      const snap = new Map(this.P);
      const used = [];
      const consume = this.consumer(used, true);
      const key = consume(o.key, pc);
      const val = consume(o.val, pc);
      if (this.orderOk(used)) {
        const isName = key.type === 'String' && isIdentifier(key.value);
        this.extendTable(tr, te, [isName ? { kind: 'named', key: key.value, value: val } : { kind: 'keyed', key, value: val }], used.some((e) => e.impure));
        return i + 1;
      }
      // Prompt XXX: the field's value cannot join the constructor in order — the table so far is written out and the field is
      // assigned to it as a statement below (this used to abandon the whole function: "table constructor field out of order")
      this.P = snap;
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
    const snap = new Map(this.P);
    const snapTop = this.topEntry;
    for (let r = o.base + 1; r <= last; r++) items.push(consume({ r }, pc));
    if (o.n === -1) items.push(this.takeTop());
    fixTail(items);
    if (!this.orderOk(used)) {
      // Prompt XXX: as for a field — write the table out and store the items one by one, instead of abandoning the function
      this.P = snap;
      this.topEntry = snapTop;
      if (this.topEntry) throw new Unstructured('table constructor items out of order');
      this.flushAll(out);
      return this.stepSetList(i, out);
    }
    this.extendTable(o.base, te, items.map((v) => ({ kind: 'item', value: v })), used.some((e) => e.impure) || o.n === -1);
    return i + 1;
  }

  /**
   * Prompt XXX: a pending constructor gains fields as a new table node in a new entry, never in place. Condition readers try steps
   * speculatively and restore the pending map when a reading fails; a field pushed into the shared table survived that restore, so the
   * retry pushed it again and the output held the same subtrees twice (code written twice, and an AST walk that never finished).
   */
  extendTable(r, te, fields, impure) {
    const t = { ...te.table, fields: [...te.table.fields, ...fields] };
    this.P.set(r, { ...te, expr: t, table: t, impure: te.impure || impure });
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
    // the closure refers to these registers by name, so a value still waiting in one of them has to be written out first
    if (o.ups.some((u) => u.instack && this.P.has(u.idx))) this.flushAll(out);
    const envUps = o.ups.map((u) => (!u.instack && this.o.envUps && this.o.envUps[u.idx] === true));
    let func;
    try {
      func = decompileFunction(o.proto, { depth: this.o.depth + 1, upNames, envUps, version: this.f.version, luau: this.o.luau });
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
          // Prompt XXX: the object is consumed by this call like any argument, so it goes through the consumer and counts for the
          // evaluation order. Deleting it unseen hid an impure object (`game:GetService("HttpService")`) from orderOk, which then let
          // an argument whose value was computed earlier (a table holding `game:GetService("Players")`) be inlined after it — the
          // rebuilt program called the two in the opposite order.
          if (e && e.selfOf === o.base) { c({ r }, pc); this.P.delete(r); continue; }
          throw new Unstructured('method call whose object was not forwarded');
        }
        args.push(c({ r }, pc));
      }
      if (o.nargs === -1) args.push(this.takeTop());
      fixTail(args);
      if (method && method.key.type === 'String' && isIdentifier(method.key.value) && !KEYWORDS.has(method.key.value)) return { type: 'MethodCall', obj: method.obj, name: method.key.value, args, sugar: null };
      // a method whose name is not an identifier cannot be written with a colon: the object is passed as the first argument
      if (method) return { type: 'Call', fn: this.indexNode(method.obj, method.key), args: [method.obj, ...args], sugar: null };
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
    const body = this.sub(i + 1, f, { exit: f + 1, innerStart: -1, until: -1, cont: f }); // a jump to FORLOOP is the next iteration (Luau `continue`)
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
    const body = this.sub(i + 1, c, { exit: c + 2, innerStart: -1, until: -1, cont: c }); // a jump to TFORCALL is the next iteration (Luau `continue`)
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
  try {
    return new FunctionDecompiler(f, opts).decompile();
  } catch (e) {
    if (!(e instanceof Unstructured) || opts.prune) throw e;
    // code nothing can reach (the junk an obfuscator leaves after a jump, with jumps of its own) can stop the structure from being read: try again without it
    const again = new FunctionDecompiler(f, { ...opts, prune: true });
    if (again.n === again.ir.length && !again.pruned) throw e;
    return again.decompile();
  }
}

/**
 * @param {{version: number, main: object}} chunk result of parseChunk()
 * @param {{dialect?: string}} [options] dialect "luau": the rebuilt program is Luau, so a jump to a loop's continue point may be written `continue`
 * @returns {{ast: object, failures: string[]}}
 */
export function decompile(chunk, options = {}) {
  const failures = [];
  const envUps = chunk.version === 0x54 ? [true] : [];
  let fn;
  try {
    // options.dialect 'luau': the program is Luau (MoonSec V3 rebuilds Roblox scripts), so `continue` may be written
    fn = decompileFunction(chunk.main, { depth: 0, upNames: [], envUps, version: chunk.version, luau: options.dialect === 'luau' });
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
