// Sandboxed Lua interpreter: AST -> JS closures.
//
// Design notes
//  * Locals are resolved to frame slots at compile time (using core/scope.js). Locals captured by an
//    inner function live in a Box so closures share them; every execution of a declaration creates a
//    fresh Box, which gives the per-iteration semantics Lua requires.
//  * A statement closure returns a signal: 0 normal, 1 break, 2 return (values in frame.ret), 3 continue.
//  * Everything is bounded by the Machine: fuel (loop iterations and calls), wall-clock deadline,
//    call depth. Hitting a bound throws SandboxLimit, which scripts cannot catch.
//  * The interpreter has no access to JS globals, the DOM, the network or the file system. What a script
//    can reach is exactly what stdlib.js / the host put into Machine.globals.

import { parse, LuaSyntaxError } from '../core/parser.js';
import { analyze } from '../core/scope.js';
import {
  LuaTable, LuaUserdata, LuaFunction, NativeFunction, LuaError, SandboxLimit, SandboxUnsupported,
  typeName, rawToString, toNumber, truthy,
} from './value.js';
import { numberToLuaString } from '../passes/consteval.js';

const NORMAL = 0;
const BREAK = 1;
const RETURN = 2;
const CONTINUE = 3;
const GOTO = 4;     // the label is in Frame.gl; the nearest enclosing block that holds it takes over
const EMPTY = Object.freeze([]);

class Box { constructor(v) { this.v = v; } }

class Frame {
  constructor(nslots, up, env) {
    this.s = new Array(nslots);
    this.up = up;
    this.env = env;
    this.va = EMPTY;
    this.ret = EMPTY;
    this.gl = null;
  }
}

export class Machine {
  constructor(options = {}) {
    this.fuel = options.fuel ?? 20_000_000;
    this.deadline = options.timeMs ? Date.now() + options.timeMs : Infinity;
    this.maxDepth = options.maxDepth ?? 400;
    this.maxString = options.maxString ?? 16 * 1024 * 1024;
    this.maxOutput = options.maxOutput ?? 1024 * 1024;
    this.depth = 0;
    this.line = 0;
    this.chunkName = 'sample';
    this.globals = new LuaTable();
    this.stringMeta = null;
    this.output = [];
    this.outputBytes = 0;
    this.loads = [];           // payloads passed to load/loadstring
    this.hooks = { onLoad: null };
    this.clock = 0;
    this.lastTick = 0;
    // Numbers are doubles (Lua 5.1 / Luau). `numMode` opts in to two refinements, used by decoder evaluation only:
    //   'watch'  count integer + - * results that doubles cannot hold exactly (precisionLoss), nothing else changes;
    //   'int64'  Lua 5.4 integers: such results are kept exact, as 64-bit wrapping BigInts, until a % or // brings them back.
    this.numMode = options.numMode || null;
    this.precisionLoss = 0;
  }

  tick(n = 1) {
    this.fuel -= n;
    if (this.fuel < 0) throw new SandboxLimit('fuel');
    if ((this.fuel & 0x3fff) === 0 && Date.now() > this.deadline) throw new SandboxLimit('time');
  }

  checkString(len) {
    if (len > this.maxString) throw new SandboxLimit('memory', 'string too large');
  }

  write(text) {
    this.outputBytes += text.length;
    if (this.outputBytes > this.maxOutput) throw new SandboxLimit('output');
    this.output.push(text);
  }

  /** Where am I, for error messages. */
  where() { return `${this.chunkName}:${this.line}:`; }

  error(msg) { return new LuaError(`${this.where()} ${msg}`); }

  /** Call any callable with an argument array; returns an array of results. */
  call(fn, args) { return callValue(this, fn, args, ''); }
}

// ---- metatables ------------------------------------------------------------------------

function metaOf(m, v) {
  if (v instanceof LuaTable || v instanceof LuaUserdata) return v.meta;
  if (typeof v === 'string') return m.stringMeta;
  return null;
}

function metaHandler(m, v, event) {
  const mt = metaOf(m, v);
  return mt ? mt.getStr(event) : undefined;
}

export function tostr(m, v) {
  const h = metaHandler(m, v, '__tostring');
  if (h !== undefined) {
    const r = callValue(m, h, [v], '')[0];
    if (typeof r !== 'string') throw m.error("'__tostring' must return a string");
    return r;
  }
  const name = metaHandler(m, v, '__name');
  if (typeof name === 'string' && (v instanceof LuaTable || v instanceof LuaUserdata)) return name + ': 0x' + v.addr.toString(16).padStart(8, '0');
  return rawToString(v);
}

// ---- operations ------------------------------------------------------------------------------

export function index(m, obj, key, desc = '') {
  for (let i = 0; i < 100; i++) {
    let h;
    if (obj instanceof LuaTable) {
      const v = obj.get(key);
      if (v !== undefined) return v;
      const mt = obj.meta;
      if (mt === null) return undefined;
      h = mt.getStr('__index');
      if (h === undefined) return undefined;
    } else {
      h = metaHandler(m, obj, '__index');
      if (h === undefined) throw m.error(`attempt to index a ${typeName(obj)} value${desc}`);
    }
    if (h instanceof LuaFunction || h instanceof NativeFunction) return callValue(m, h, [obj, key], '')[0];
    obj = h;
  }
  throw m.error("loop in gettable");
}

export function setIndex(m, obj, key, value, desc = '') {
  if (obj instanceof LuaTable && obj.meta === null && !obj.readonly && key !== undefined && key === key) { obj.set(key, value); return; }
  for (let i = 0; i < 100; i++) {
    let h;
    if (obj instanceof LuaTable) {
      if (obj.readonly) throw m.error('attempt to modify a readonly table');
      const mt = obj.meta;
      if (mt === null) { setChecked(m, obj, key, value); return; }
      h = mt.getStr('__newindex');
      if (h === undefined || obj.get(key) !== undefined) { setChecked(m, obj, key, value); return; }
    } else {
      h = metaHandler(m, obj, '__newindex');
      if (h === undefined) throw m.error(`attempt to index a ${typeName(obj)} value${desc}`);
    }
    if (h instanceof LuaFunction || h instanceof NativeFunction) { callValue(m, h, [obj, key, value], ''); return; }
    obj = h;
  }
  throw m.error("loop in settable");
}

function setChecked(m, t, key, value) {
  try { t.set(key, value); } catch (e) { if (e instanceof LuaError && typeof e.value === 'string') throw m.error(e.value); throw e; }
}

const ARITH_EVENT = { '+': '__add', '-': '__sub', '*': '__mul', '/': '__div', '%': '__mod', '^': '__pow', '//': '__idiv' };

function luaMod(a, b) {
  const r = a % b;
  return r !== 0 && (r < 0) !== (b < 0) ? r + b : r;
}

const TWO53 = 9007199254740992;
const normInt = (b) => (b >= -9007199254740991n && b <= 9007199254740991n ? Number(b) : b);
const isNum = (v) => typeof v === 'number' || typeof v === 'bigint';

/** Arithmetic when an operand is a BigInt (only produced in 'int64' mode); undefined when an operand is not a number at all. */
function bigArith(m, op, a, b) {
  const x = isNum(a) ? a : toNumber(a);
  const y = isNum(b) ? b : toNumber(b);
  if (x === undefined || y === undefined) return undefined;
  const whole = (v) => typeof v === 'bigint' || Number.isInteger(v);
  if (!whole(x) || !whole(y) || op === '/' || op === '^') {
    const fx = Number(x); const fy = Number(y);
    switch (op) {
      case '+': return fx + fy;
      case '-': return fx - fy;
      case '*': return fx * fy;
      case '/': return fx / fy;
      case '%': return luaMod(fx, fy);
      case '^': return Math.pow(fx, fy);
      default: return Math.floor(fx / fy);
    }
  }
  const X = BigInt(x); const Y = BigInt(y);
  let r;
  switch (op) {
    case '+': r = X + Y; break;
    case '-': r = X - Y; break;
    case '*': r = X * Y; break;
    case '%':
      if (Y === 0n) throw m.error("attempt to perform 'n%%0'");
      r = X % Y;
      if (r !== 0n && (r < 0n) !== (Y < 0n)) r += Y;
      break;
    default:
      if (Y === 0n) throw m.error("attempt to perform 'n//0'");
      r = X / Y;
      if (X % Y !== 0n && (X < 0n) !== (Y < 0n)) r -= 1n;
  }
  return normInt(BigInt.asIntN(64, r));
}

/** + - * on two plain numbers under a numMode: counts, or widens to an exact integer, when the double result is no longer exact. */
function modeArith(m, op, a, b) {
  const r = op === '+' ? a + b : op === '-' ? a - b : a * b;
  if (r < TWO53 && r > -TWO53) return r;
  if (!Number.isInteger(a) || !Number.isInteger(b)) return r;
  if (m.numMode === 'watch') { m.precisionLoss++; return r; }
  return bigArith(m, op, a, b);
}

export function arith(m, op, a, b, da = '', db = '') {
  if (typeof a === 'bigint' || typeof b === 'bigint') {
    const r = bigArith(m, op, a, b);
    if (r !== undefined) return r;
  }
  const x = toNumber(a);
  const y = toNumber(b);
  if (x !== undefined && y !== undefined && typeof a !== 'boolean' && typeof b !== 'boolean') {
    switch (op) {
      case '+': return x + y;
      case '-': return x - y;
      case '*': return x * y;
      case '/': return x / y;
      case '%': return luaMod(x, y);
      case '^': return Math.pow(x, y);
      case '//': return Math.floor(x / y);
      default: break;
    }
  }
  const event = ARITH_EVENT[op];
  let h = metaHandler(m, a, event);
  if (h === undefined) h = metaHandler(m, b, event);
  if (h !== undefined) return callValue(m, h, [a, b], '')[0];
  const bad = x === undefined ? a : b;
  const d = x === undefined ? da : db;
  throw m.error(`attempt to perform arithmetic on a ${typeName(bad)} value${d}`);
}

// ---- Lua 5.4 bitwise operators: operands are integers (floats with a whole value convert), the result is a 64-bit integer ----

const BIT_EVENT = { '&': '__band', '|': '__bor', '~': '__bxor', '<<': '__shl', '>>': '__shr' };
const small = (v) => typeof v === 'number' && v >= -2147483648 && v <= 2147483647 && Number.isInteger(v);

// Lua 5.4 does not turn strings into numbers for bitwise operators (5.3 did): "7" | 0 is an error there.
function bitOperand(m, v) {
  if (typeof v === 'bigint') return v;
  if (typeof v !== 'number') return undefined;
  if (!Number.isFinite(v) || Math.floor(v) !== v) throw m.error('number has no integer representation');
  return BigInt.asIntN(64, BigInt(v));
}

const shiftLeft = (x, n) => {
  if (n <= -64n || n >= 64n) return 0n;
  return n >= 0n ? BigInt.asIntN(64, x << n) : BigInt.asIntN(64, BigInt.asUintN(64, x) >> -n);
};

export function bitop(m, op, a, b, da = '', db = '') {
  if (small(a) && small(b)) {
    if (op === '&') return a & b;
    if (op === '|') return a | b;
    if (op === '~') return a ^ b;
  }
  const x = bitOperand(m, a);
  const y = bitOperand(m, b);
  if (x === undefined || y === undefined) {
    let h = metaHandler(m, a, BIT_EVENT[op]);
    if (h === undefined) h = metaHandler(m, b, BIT_EVENT[op]);
    if (h !== undefined) return callValue(m, h, [a, b], '')[0];
    const bad = x === undefined ? a : b;
    throw m.error(`attempt to perform bitwise operation on a ${typeName(bad)} value${x === undefined ? da : db}`);
  }
  let r;
  switch (op) {
    case '&': r = x & y; break;
    case '|': r = x | y; break;
    case '~': r = x ^ y; break;
    case '<<': r = shiftLeft(x, y); break;
    default: r = shiftLeft(x, -y);
  }
  return normInt(BigInt.asIntN(64, r));
}

export function bitNot(m, a, d = '') {
  if (small(a)) return -a - 1;
  const x = bitOperand(m, a);
  if (x === undefined) {
    const h = metaHandler(m, a, '__bnot');
    if (h !== undefined) return callValue(m, h, [a, a], '')[0];
    throw m.error(`attempt to perform bitwise operation on a ${typeName(a)} value${d}`);
  }
  return normInt(BigInt.asIntN(64, ~x));
}

export function negate(m, a, d = '') {
  if (typeof a === 'bigint') return normInt(BigInt.asIntN(64, -a));
  const x = toNumber(a);
  if (x !== undefined && typeof a !== 'boolean') return -x;
  const h = metaHandler(m, a, '__unm');
  if (h !== undefined) return callValue(m, h, [a, a], '')[0];
  throw m.error(`attempt to perform arithmetic on a ${typeName(a)} value${d}`);
}

export function concat(m, a, b, da = '', db = '') {
  const sa = typeof a === 'string' ? a : typeof a === 'number' ? numberToLuaString(a) : undefined;
  const sb = typeof b === 'string' ? b : typeof b === 'number' ? numberToLuaString(b) : undefined;
  if (sa !== undefined && sb !== undefined) {
    m.checkString(sa.length + sb.length);
    return sa + sb;
  }
  let h = metaHandler(m, a, '__concat');
  if (h === undefined) h = metaHandler(m, b, '__concat');
  if (h !== undefined) return callValue(m, h, [a, b], '')[0];
  const bad = sa === undefined ? a : b;
  throw m.error(`attempt to concatenate a ${typeName(bad)} value${sa === undefined ? da : db}`);
}

export function length(m, v, d = '') {
  if (typeof v === 'string') return v.length;
  if (v instanceof LuaTable) {
    if (v.meta !== null) {
      const h = v.meta.getStr('__len');
      if (h !== undefined) return callValue(m, h, [v], '')[0];
    }
    return v.length();
  }
  const h = metaHandler(m, v, '__len');
  if (h !== undefined) return callValue(m, h, [v], '')[0];
  throw m.error(`attempt to get length of a ${typeName(v)} value${d}`);
}

export function equals(m, a, b) {
  if (a === b) return true;
  if (typeof a === 'number' && typeof b === 'number') return a === b; // NaN handled by ===
  if ((a instanceof LuaTable && b instanceof LuaTable) || (a instanceof LuaUserdata && b instanceof LuaUserdata)) {
    let h = metaHandler(m, a, '__eq');
    if (h === undefined) h = metaHandler(m, b, '__eq');
    if (h !== undefined) return truthy(callValue(m, h, [a, b], '')[0]);
  }
  return false;
}

function compareError(m, a, b) {
  const ta = typeName(a);
  const tb = typeName(b);
  return m.error(ta === tb ? `attempt to compare two ${ta} values` : `attempt to compare ${ta} with ${tb}`);
}

export function lessThan(m, a, b) {
  if (isNum(a) && isNum(b)) return a < b;
  if (typeof a === 'string' && typeof b === 'string') return a < b;
  let h = metaHandler(m, a, '__lt');
  if (h === undefined) h = metaHandler(m, b, '__lt');
  if (h !== undefined) return truthy(callValue(m, h, [a, b], '')[0]);
  throw compareError(m, a, b);
}

export function lessEqual(m, a, b) {
  if (isNum(a) && isNum(b)) return a <= b;
  if (typeof a === 'string' && typeof b === 'string') return a <= b;
  let h = metaHandler(m, a, '__le');
  if (h === undefined) h = metaHandler(m, b, '__le');
  if (h !== undefined) return truthy(callValue(m, h, [a, b], '')[0]);
  h = metaHandler(m, a, '__lt');
  if (h === undefined) h = metaHandler(m, b, '__lt');
  if (h !== undefined) return !truthy(callValue(m, h, [b, a], '')[0]);
  throw compareError(m, a, b);
}

// ---- calls ---------------------------------------------------------------------------------------

export function callValue(m, fn, args, desc) {
  if (fn instanceof LuaFunction) return fn.proto.call(m, fn, args);
  if (fn instanceof NativeFunction) { m.tick(); return fn.fn(args, m); }
  const h = metaHandler(m, fn, '__call');
  if (h !== undefined) return callValue(m, h, [fn, ...args], desc);
  throw m.error(`attempt to call a ${typeName(fn)} value${desc}`);
}

// ---- compiler ------------------------------------------------------------------------------------

class FuncCtx {
  constructor(parent, node, depth) {
    this.parent = parent;
    this.node = node;
    this.depth = depth;
    this.nslots = 0;
    this.slotOf = new Map();    // Var -> { slot, boxed }
    this.upvals = [];           // descriptors: { var, fromLocal: boolean, ref: slot | upvalue index }
    this.upIndex = new Map();   // Var -> index into upvals
  }
}

export class Compiler {
  constructor(machine, info) {
    this.m = machine;
    this.info = info;
    this.fc = null;
    this.depth = 0;
  }

  // -- variable resolution --

  declare(id) {
    const v = this.info.varOf.get(id);
    const entry = { slot: this.fc.nslots++, boxed: v.captured };
    this.fc.slotOf.set(v, entry);
    return entry;
  }

  /** Where does `v` live as seen from the function currently being compiled? */
  locate(v, fc = this.fc) {
    const own = fc.slotOf.get(v);
    if (own) return { kind: 'local', ...own };
    let idx = fc.upIndex.get(v);
    if (idx === undefined) {
      if (!fc.parent) throw new Error(`internal: unresolved variable ${v.name}`);
      const outer = this.locate(v, fc.parent);
      idx = fc.upvals.length;
      fc.upvals.push(outer.kind === 'local' ? { fromLocal: true, ref: outer.slot } : { fromLocal: false, ref: outer.index });
      fc.upIndex.set(v, idx);
    }
    return { kind: 'up', index: idx };
  }

  describe(e) {
    if (e.type === 'Name') {
      const v = this.info.varOf.get(e);
      if (v && v.isGlobal) return ` (global '${e.name}')`;
      if (v && this.fc.slotOf.has(v)) return ` (local '${e.name}')`;
      return ` (upvalue '${e.name}')`;
    }
    if (e.type === 'Index' && e.key.type === 'String') return ` (field '${e.key.value}')`;
    if (e.type === 'MethodCall') return ` (method '${e.name}')`;
    if (e.type === 'String') return '';
    return '';
  }

  // -- functions --

  compileFunction(node, name, selfParam) {
    const outer = this.fc;
    const fc = new FuncCtx(outer, node, this.depth + 1);
    this.fc = fc;
    this.depth++;
    const params = [];
    if (selfParam) {
      const v = this.info.selfOf.get(node);
      const entry = { slot: fc.nslots++, boxed: v.captured };
      fc.slotOf.set(v, entry);
      params.push(entry);
    }
    for (const p of node.params) params.push(this.declare(p));
    const body = this.block(node.body);
    this.depth--;
    this.fc = outer;

    const nparams = params.length;
    const hasVararg = !!node.vararg;
    const nslots = fc.nslots;
    return {
      name, line: node.line || 0, nparams, hasVararg, upvals: fc.upvals,
      call(machine, fn, args) {
        machine.tick();
        if (++machine.depth > machine.maxDepth) { machine.depth--; throw machine.error('stack overflow'); }
        try {
          const f = new Frame(nslots, fn.upvals, fn.env);
          for (let i = 0; i < nparams; i++) {
            const p = params[i];
            f.s[p.slot] = p.boxed ? new Box(args[i]) : args[i];
          }
          if (hasVararg) f.va = args.length > nparams ? args.slice(nparams) : EMPTY;
          const sig = body(f);
          return sig === RETURN ? f.ret : EMPTY;
        } finally {
          machine.depth--;
        }
      },
    };
  }

  funcExpr(node, name, selfParam) {
    const proto = this.compileFunction(node, name, selfParam);
    const ups = proto.upvals;
    return (f) => {
      const captured = new Array(ups.length);
      for (let i = 0; i < ups.length; i++) captured[i] = ups[i].fromLocal ? f.s[ups[i].ref] : f.up[ups[i].ref];
      return new LuaFunction(proto, captured, f.env);
    };
  }

  // -- statements --

  block(stmts) {
    const code = stmts.map((s) => this.stmt(s));
    const n = code.length;
    const labels = new Map();
    stmts.forEach((s, i) => { if (s.type === 'Label') labels.set(s.name, i); });
    if (labels.size) {
      const m = this.m;
      return (f) => {
        let i = 0;
        while (i < n) {
          const sig = code[i](f);
          if (sig === NORMAL) { i++; continue; }
          if (sig === GOTO && labels.has(f.gl)) { m.tick(); i = labels.get(f.gl); continue; }
          return sig;
        }
        return NORMAL;
      };
    }
    if (n === 0) return () => NORMAL;
    if (n === 1) return code[0];
    return (f) => {
      for (let i = 0; i < n; i++) {
        const sig = code[i](f);
        if (sig !== NORMAL) return sig;
      }
      return NORMAL;
    };
  }

  stmt(s) {
    const m = this.m;
    const line = s.line || 0;
    switch (s.type) {
      case 'Local': return this.localStmt(s, line);
      case 'LocalFunction': {
        const entry = this.declare(s.id);
        const make = this.funcExpr(s.func, s.id.name, false);
        if (entry.boxed) {
          return (f) => { m.line = line; const box = new Box(undefined); f.s[entry.slot] = box; box.v = make(f); return NORMAL; };
        }
        return (f) => { m.line = line; f.s[entry.slot] = make(f); return NORMAL; };
      }
      case 'Function': return this.functionStmt(s, line);
      case 'Assign': return this.assignStmt(s, line);
      case 'CompoundAssign': return this.compoundStmt(s, line);
      case 'CallStmt': {
        const call = this.multi(s.call);
        return (f) => { m.line = line; call(f); return NORMAL; };
      }
      case 'Do': return this.block(s.body);
      case 'While': {
        const cond = this.expr(s.cond);
        const body = this.block(s.body);
        return (f) => {
          m.line = line;
          while (truthy(cond(f))) {
            m.tick();
            const sig = body(f);
            if (sig === BREAK) break;
            if (sig === RETURN || sig === GOTO) return sig;
          }
          return NORMAL;
        };
      }
      case 'Repeat': {
        const body = this.block(s.body);
        const cond = this.expr(s.cond);
        return (f) => {
          m.line = line;
          for (;;) {
            m.tick();
            const sig = body(f);
            if (sig === BREAK) break;
            if (sig === RETURN || sig === GOTO) return sig;
            if (truthy(cond(f))) break;
          }
          return NORMAL;
        };
      }
      case 'If': {
        const clauses = s.clauses.map((c) => ({ cond: this.expr(c.cond), body: this.block(c.body) }));
        const orelse = s.orelse ? this.block(s.orelse) : null;
        // dispatch trees (VM interpreters) are long chains of one- and two-clause ifs: no loop, no indirection
        if (clauses.length === 1) {
          const c0 = clauses[0].cond;
          const b0 = clauses[0].body;
          if (orelse) return (f) => { m.line = line; const v = c0(f); return v !== undefined && v !== false ? b0(f) : orelse(f); };
          return (f) => { m.line = line; const v = c0(f); return v !== undefined && v !== false ? b0(f) : NORMAL; };
        }
        if (clauses.length === 2) {
          const c0 = clauses[0].cond; const b0 = clauses[0].body;
          const c1 = clauses[1].cond; const b1 = clauses[1].body;
          return (f) => {
            m.line = line;
            let v = c0(f);
            if (v !== undefined && v !== false) return b0(f);
            v = c1(f);
            if (v !== undefined && v !== false) return b1(f);
            return orelse ? orelse(f) : NORMAL;
          };
        }
        return (f) => {
          m.line = line;
          for (let i = 0; i < clauses.length; i++) {
            if (truthy(clauses[i].cond(f))) return clauses[i].body(f);
          }
          return orelse ? orelse(f) : NORMAL;
        };
      }
      case 'NumFor': return this.numFor(s, line);
      case 'GenFor': return this.genFor(s, line);
      case 'Return': return this.returnStmt(s, line);
      case 'Break': return () => BREAK;
      case 'Continue': return () => CONTINUE;
      case 'TypeAlias': return () => NORMAL;
      case 'Label': return () => NORMAL;
      case 'Goto': { const label = s.label; return (f) => { f.gl = label; return GOTO; }; }
      default:
        throw new Error('interp: unknown statement ' + s.type);
    }
  }

  localStmt(s, line) {
    const m = this.m;
    const vals = this.exprListMulti(s.values);        // evaluated before the new names exist
    const entries = s.ids.map((id) => this.declare(id));
    const n = entries.length;
    if (n === 1 && s.values.length === 1 && !this.isMulti(s.values[0])) {
      const e = entries[0];
      const one = this.expr(s.values[0]);
      if (e.boxed) return (f) => { m.line = line; f.s[e.slot] = new Box(one(f)); return NORMAL; };
      return (f) => { m.line = line; f.s[e.slot] = one(f); return NORMAL; };
    }
    return (f) => {
      m.line = line;
      const values = vals(f);
      for (let i = 0; i < n; i++) {
        const e = entries[i];
        f.s[e.slot] = e.boxed ? new Box(values[i]) : values[i];
      }
      return NORMAL;
    };
  }

  /** Compile an assignment target into { prepare(f) -> ctx, store(f, ctx, value) }. */
  target(t) {
    const m = this.m;
    if (t.type === 'Name') {
      const v = this.info.varOf.get(t);
      if (v.isGlobal) {
        const name = t.name;
        return { prepare: () => null, store: (f, _c, val) => setIndex(m, f.env, name, val) };
      }
      const loc = this.locate(v);
      if (loc.kind === 'local') {
        if (loc.boxed) return { prepare: () => null, store: (f, _c, val) => { f.s[loc.slot].v = val; } };
        return { prepare: () => null, store: (f, _c, val) => { f.s[loc.slot] = val; } };
      }
      return { prepare: () => null, store: (f, _c, val) => { f.up[loc.index].v = val; } };
    }
    const obj = this.expr(t.obj);
    const key = this.expr(t.key);
    const d = this.describe(t.obj);
    return { prepare: (f) => [obj(f), key(f)], store: (f, c, val) => setIndex(m, c[0], c[1], val, d) };
  }

  assignStmt(s, line) {
    const m = this.m;
    const targets = s.targets.map((t) => this.target(t));
    if (targets.length === 1 && s.values.length === 1 && !this.isMulti(s.values[0])) {
      const t = targets[0];
      const v = this.expr(s.values[0]);
      if (s.targets[0].type !== 'Name') {
        const obj = this.expr(s.targets[0].obj);
        const key = this.expr(s.targets[0].key);
        const d = this.describe(s.targets[0].obj);
        return (f) => { m.line = line; const o = obj(f); const k = key(f); setIndex(m, o, k, v(f), d); return NORMAL; };
      }
      return (f) => { m.line = line; const c = t.prepare(f); t.store(f, c, v(f)); return NORMAL; };
    }
    const vals = this.exprListMulti(s.values);
    const n = targets.length;
    return (f) => {
      m.line = line;
      const ctx = targets.map((t) => t.prepare(f));
      const values = vals(f);
      for (let i = n - 1; i >= 0; i--) targets[i].store(f, ctx[i], values[i]); // right to left, as the reference VM
      return NORMAL;
    };
  }

  compoundStmt(s, line) {
    const m = this.m;
    const t = this.target(s.target);
    const read = this.expr(s.target.type === 'Name' ? s.target : s.target);
    const rhs = this.expr(s.value);
    const op = s.op;
    return (f) => {
      m.line = line;
      const c = t.prepare(f);
      const cur = s.target.type === 'Name' ? read(f) : index(m, c[0], c[1]);
      const val = rhs(f);
      t.store(f, c, op === '..' ? concat(m, cur, val) : arith(m, op, cur, val));
      return NORMAL;
    };
  }

  functionStmt(s, line) {
    const m = this.m;
    const make = this.funcExpr(s.func, s.method ? '?:' + s.method : this.exprName(s.target), s.method !== null);
    if (s.method) {
      const obj = this.expr(s.target);
      const name = s.method;
      return (f) => { m.line = line; setIndex(m, obj(f), name, make(f)); return NORMAL; };
    }
    const t = this.target(s.target);
    return (f) => { m.line = line; const c = t.prepare(f); t.store(f, c, make(f)); return NORMAL; };
  }

  exprName(e) {
    if (e.type === 'Name') return e.name;
    if (e.type === 'Index' && e.key.type === 'String') return this.exprName(e.obj) + '.' + e.key.value;
    return '?';
  }

  numFor(s, line) {
    const m = this.m;
    const start = this.expr(s.start);
    const stop = this.expr(s.stop);
    const step = s.step ? this.expr(s.step) : null;
    const e = this.declare(s.id);
    const body = this.block(s.body);
    return (f) => {
      m.line = line;
      const a = toNumber(start(f));
      const b = toNumber(stop(f));
      const c = step ? toNumber(step(f)) : 1;
      if (a === undefined) throw m.error("'for' initial value must be a number");
      if (b === undefined) throw m.error("'for' limit must be a number");
      if (c === undefined) throw m.error("'for' step must be a number");
      if (c === 0) throw m.error("'for' step is zero");
      for (let i = a; c > 0 ? i <= b : i >= b; i += c) {
        m.tick();
        f.s[e.slot] = e.boxed ? new Box(i) : i;
        const sig = body(f);
        if (sig === BREAK) break;
        if (sig === RETURN || sig === GOTO) return sig;
      }
      return NORMAL;
    };
  }

  genFor(s, line) {
    const m = this.m;
    const exprs = this.exprListMulti(s.exprs);
    const entries = s.ids.map((id) => this.declare(id));
    const body = this.block(s.body);
    const n = entries.length;
    const assign = (f, vals) => {
      for (let i = 0; i < n; i++) {
        const e = entries[i];
        f.s[e.slot] = e.boxed ? new Box(vals[i]) : vals[i];
      }
    };
    return (f) => {
      m.line = line;
      const init = exprs(f);
      const iter = init[0];
      const state = init[1];
      let control = init[2];
      // Fast path for pairs(t) / next, t: walk the table directly instead of going through next().
      if (iter === m.nextFn && state instanceof LuaTable && control === undefined) {
        const t = state;
        for (let i = 0; i < t.arr.length; i++) {
          const v = t.arr[i];
          if (v === undefined) continue;
          m.tick();
          assign(f, [i + 1, v]);
          const sig = body(f);
          if (sig === BREAK) return NORMAL;
          if (sig === RETURN || sig === GOTO) return sig;
        }
        if (t.hash !== null) {
          for (const k of [...t.hash.keys()]) {
            const v = t.hash.get(k);
            if (v === undefined) continue;      // removed during traversal
            m.tick();
            assign(f, [k, v]);
            const sig = body(f);
            if (sig === BREAK) return NORMAL;
            if (sig === RETURN || sig === GOTO) return sig;
          }
        }
        return NORMAL;
      }
      for (;;) {
        m.tick();
        const vals = callValue(m, iter, [state, control], '');
        if (vals[0] === undefined) break;
        control = vals[0];
        assign(f, vals);
        const sig = body(f);
        if (sig === BREAK) break;
        if (sig === RETURN || sig === GOTO) return sig;
      }
      return NORMAL;
    };
  }

  returnStmt(s, line) {
    const m = this.m;
    if (s.values.length === 0) return (f) => { f.ret = EMPTY; return RETURN; };
    if (s.values.length === 1) {
      const e = s.values[0];
      if (e.type === 'Call' || e.type === 'MethodCall') {
        const call = this.multi(e);
        return (f) => { m.line = line; f.ret = call(f); return RETURN; };
      }
      if (!this.isMulti(e)) {
        const one = this.expr(e);
        return (f) => { m.line = line; f.ret = [one(f)]; return RETURN; };
      }
    }
    const vals = this.exprListMulti(s.values);
    return (f) => { m.line = line; f.ret = vals(f); return RETURN; };
  }

  // -- expressions --

  isMulti(e) { return e.type === 'Call' || e.type === 'MethodCall' || e.type === 'Vararg'; }

  /** Compile an expression list where the last expression may expand to several values. */
  exprListMulti(list) {
    if (list.length === 0) return () => EMPTY;
    const last = list[list.length - 1];
    const heads = list.slice(0, -1).map((e) => this.expr(e));
    if (this.isMulti(last)) {
      const tail = this.multi(last);
      if (heads.length === 0) return tail;
      return (f) => {
        const out = new Array(heads.length);
        for (let i = 0; i < heads.length; i++) out[i] = heads[i](f);
        return out.concat(tail(f));
      };
    }
    const all = heads.concat([this.expr(last)]);
    return (f) => {
      const out = new Array(all.length);
      for (let i = 0; i < all.length; i++) out[i] = all[i](f);
      return out;
    };
  }

  /** Expression yielding an array of values (calls and varargs). */
  multi(e) {
    const m = this.m;
    if (e.type === 'Vararg') return (f) => f.va;
    if (e.type === 'Call') {
      const fn = this.expr(e.fn);
      const args = this.exprListMulti(e.args);
      const d = this.describe(e.fn);
      const line = e.line || 0;
      return (f) => {
        const callee = fn(f);
        const a = args(f);
        if (line) m.line = line;
        return callValue(m, callee, a, d);
      };
    }
    if (e.type === 'MethodCall') {
      const obj = this.expr(e.obj);
      const args = this.exprListMulti(e.args);
      const name = e.name;
      const d = this.describe(e.obj);
      const line = e.line || 0;
      return (f) => {
        const o = obj(f);
        const fn = index(m, o, name, d);
        const a = args(f);
        const withSelf = new Array(a.length + 1);
        withSelf[0] = o;
        for (let i = 0; i < a.length; i++) withSelf[i + 1] = a[i];
        if (line) m.line = line;
        return callValue(m, fn, withSelf, ` (method '${name}')`);
      };
    }
    const one = this.expr(e);
    return (f) => [one(f)];
  }

  expr(e) {
    const m = this.m;
    switch (e.type) {
      case 'Nil': return () => undefined;
      case 'True': return () => true;
      case 'False': return () => false;
      case 'Number': { const v = e.value; return () => v; }
      case 'String': { const v = e.value; return () => v; }
      case 'Vararg': return (f) => f.va[0];
      case 'Paren': return this.expr(e.expr);
      case 'TypeAssert': return this.expr(e.expr);
      case 'Name': return this.nameExpr(e);
      case 'Index': {
        const obj = this.expr(e.obj);
        const d = this.describe(e.obj);
        if (e.key.type === 'String') {
          const k = e.key.value;
          return (f) => {
            const o = obj(f);
            if (o instanceof LuaTable) { const v = o.getStr(k); if (v !== undefined || o.meta === null) return v; }
            return index(m, o, k, d);
          };
        }
        const key = this.expr(e.key);
        return (f) => {
          const o = obj(f);
          const k = key(f);
          if (o instanceof LuaTable) { const v = o.get(k); if (v !== undefined || o.meta === null) return v; }
          return index(m, o, k, d);
        };
      }
      case 'Call': case 'MethodCall': {
        const call = this.multi(e);
        return (f) => call(f)[0];
      }
      case 'Func': return this.funcExpr(e, 'anonymous', false);
      case 'Table': return this.tableExpr(e);
      case 'Unary': return this.unaryExpr(e);
      case 'Binary': return this.binaryExpr(e);
      case 'IfExpr': {
        const c = this.expr(e.cond);
        const a = this.expr(e.then);
        const b = this.expr(e.orelse);
        return (f) => (truthy(c(f)) ? a(f) : b(f));
      }
      case 'Interp': {
        const parts = e.parts.map((p) => (typeof p === 'string' ? p : this.expr(p)));
        return (f) => parts.map((p) => (typeof p === 'string' ? p : tostr(m, p(f)))).join('');
      }
      default:
        throw new Error('interp: unknown expression ' + e.type);
    }
  }

  nameExpr(e) {
    const m = this.m;
    const v = this.info.varOf.get(e);
    if (v.isGlobal) {
      const name = e.name;
      // Lua 5.2+: a free `_ENV` is the environment itself (writing to it is not modelled)
      if (name === '_ENV') return (f) => { const x = f.env.getStr('_ENV'); return x !== undefined ? x : f.env; };
      return (f) => {
        const env = f.env;
        const x = env.getStr(name);
        if (x !== undefined || env.meta === null) return x;
        return index(m, env, name);
      };
    }
    const loc = this.locate(v);
    if (loc.kind === 'local') {
      const { slot } = loc;
      return loc.boxed ? (f) => f.s[slot].v : (f) => f.s[slot];
    }
    const i = loc.index;
    return (f) => f.up[i].v;
  }

  tableExpr(e) {
    const m = this.m;
    const items = [];
    let lastMulti = null;
    e.fields.forEach((fld, i) => {
      const isLast = i === e.fields.length - 1;
      if (fld.kind === 'item') {
        if (isLast && this.isMulti(fld.value)) lastMulti = this.multi(fld.value);
        else items.push({ kind: 'item', value: this.expr(fld.value) });
      } else if (fld.kind === 'named') items.push({ kind: 'keyed', key: () => fld.key, value: this.expr(fld.value) });
      else items.push({ kind: 'keyed', key: this.expr(fld.key), value: this.expr(fld.value) });
    });
    return (f) => {
      m.tick();
      const t = new LuaTable();
      let n = 1;
      for (let i = 0; i < items.length; i++) {
        const it = items[i];
        if (it.kind === 'item') t.listSet(n++, it.value(f));
        else {
          const k = it.key(f);
          if (k === undefined) throw m.error('table index is nil');
          setChecked(m, t, k, it.value(f));
        }
      }
      if (lastMulti) {
        const rest = lastMulti(f);
        for (let i = 0; i < rest.length; i++) t.listSet(n++, rest[i]);
      }
      return t;
    };
  }

  unaryExpr(e) {
    const m = this.m;
    const a = this.expr(e.arg);
    const d = this.describe(e.arg);
    switch (e.op) {
      case 'not': return (f) => !truthy(a(f));
      case '-': return (f) => { const v = a(f); return typeof v === 'number' ? -v : negate(m, v, d); };
      case '#': return (f) => length(m, a(f), d);
      case '~': return (f) => bitNot(m, a(f), d);
      default: throw new SandboxUnsupported(`unary operator ${e.op}`);
    }
  }

  binaryExpr(e) {
    const m = this.m;
    const l = this.expr(e.left);
    const r = this.expr(e.right);
    const dl = this.describe(e.left);
    const dr = this.describe(e.right);
    switch (e.op) {
      case 'and': return (f) => { const a = l(f); return truthy(a) ? r(f) : a; };
      case 'or': return (f) => { const a = l(f); return truthy(a) ? a : r(f); };
      case '==': return (f) => { const a = l(f); const b = r(f); return a === b || (typeof a === 'object' && typeof b === 'object' && equals(m, a, b)); };
      case '~=': return (f) => { const a = l(f); const b = r(f); return !(a === b || (typeof a === 'object' && typeof b === 'object' && equals(m, a, b))); };
      case '<': return (f) => { const a = l(f); const b = r(f); return typeof a === 'number' && typeof b === 'number' ? a < b : lessThan(m, a, b); };
      case '<=': return (f) => { const a = l(f); const b = r(f); return typeof a === 'number' && typeof b === 'number' ? a <= b : lessEqual(m, a, b); };
      case '>': return (f) => { const a = l(f); const b = r(f); return typeof a === 'number' && typeof b === 'number' ? b < a : lessThan(m, b, a); };
      case '>=': return (f) => { const a = l(f); const b = r(f); return typeof a === 'number' && typeof b === 'number' ? b <= a : lessEqual(m, b, a); };
      case '..': return (f) => concat(m, l(f), r(f), dl, dr);
      case '+': if (m.numMode) return (f) => { const a = l(f); const b = r(f); return typeof a === 'number' && typeof b === 'number' ? modeArith(m, '+', a, b) : arith(m, '+', a, b, dl, dr); };
        return (f) => { const a = l(f); const b = r(f); return typeof a === 'number' && typeof b === 'number' ? a + b : arith(m, '+', a, b, dl, dr); };
      case '-': if (m.numMode) return (f) => { const a = l(f); const b = r(f); return typeof a === 'number' && typeof b === 'number' ? modeArith(m, '-', a, b) : arith(m, '-', a, b, dl, dr); };
        return (f) => { const a = l(f); const b = r(f); return typeof a === 'number' && typeof b === 'number' ? a - b : arith(m, '-', a, b, dl, dr); };
      case '*': if (m.numMode) return (f) => { const a = l(f); const b = r(f); return typeof a === 'number' && typeof b === 'number' ? modeArith(m, '*', a, b) : arith(m, '*', a, b, dl, dr); };
        return (f) => { const a = l(f); const b = r(f); return typeof a === 'number' && typeof b === 'number' ? a * b : arith(m, '*', a, b, dl, dr); };
      case '/': return (f) => { const a = l(f); const b = r(f); return typeof a === 'number' && typeof b === 'number' ? a / b : arith(m, '/', a, b, dl, dr); };
      case '%': return (f) => {
        const a = l(f); const b = r(f);
        if (typeof a === 'number' && typeof b === 'number') { const q = a % b; return q !== 0 && (q < 0) !== (b < 0) ? q + b : q; }
        return arith(m, '%', a, b, dl, dr);
      };
      case '^': return (f) => { const a = l(f); const b = r(f); return typeof a === 'number' && typeof b === 'number' ? Math.pow(a, b) : arith(m, '^', a, b, dl, dr); };
      case '//': return (f) => { const a = l(f); const b = r(f); return typeof a === 'number' && typeof b === 'number' ? Math.floor(a / b) : arith(m, '//', a, b, dl, dr); };
      case '&': case '|': case '~': case '<<': case '>>': { const op = e.op; return (f) => bitop(m, op, l(f), r(f), dl, dr); }
      default: throw new SandboxUnsupported(`operator ${e.op}`);
    }
  }
}

/**
 * Compile an already parsed chunk into a LuaFunction bound to `env`.
 * The AST is only read, never modified.
 */
export function compileAst(m, ast, chunkName, env) {
  const info = analyze(ast);
  const compiler = new Compiler(m, info);
  const fn = { type: 'Func', params: [], vararg: true, body: ast.body, isMethod: false, line: 0 };
  const proto = compiler.compileFunction(fn, chunkName || 'main', false);
  return new LuaFunction(proto, [], env || m.globals);
}

/**
 * Compile Lua source (a binary string) into a LuaFunction bound to `env`.
 * @throws LuaSyntaxError
 */
export function compileSource(m, source, chunkName, env) {
  return compileAst(m, parse(source), chunkName, env);
}

export { LuaSyntaxError, NORMAL, BREAK, RETURN, CONTINUE, GOTO, EMPTY };
