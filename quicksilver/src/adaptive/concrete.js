// Evaluation of an expression whose inputs are all known.
//
// The values are the constant evaluator's (undefined = nil, boolean, number, string) and ConstTable for a table whose contents the caller has
// proven never change. Nothing is guessed: an operand the environment cannot give, an operation the constant evaluator refuses and any
// call outside the pure standard functions end in NOT_CONST, and the caller leaves the expression alone.

import { NOT_CONST, evalBinary, evalUnary, evalLibCall, evalGlobalCall } from '../passes/consteval.js';
import { strip } from './util.js';

export { NOT_CONST };

/** A table of constants: array part and hash part. Equal only to itself. */
export class ConstTable {
  constructor() { this.map = new Map(); this.n = 0; }
  static fromNode(node, evaluate) {
    const t = new ConstTable();
    let next = 1;
    for (const f of node.fields) {
      if (f.kind === 'keyed' || f.kind === 'named') {
        const key = f.kind === 'named' ? f.key : evaluate(f.key);
        const value = evaluate(f.value);
        if (key === NOT_CONST || value === NOT_CONST || key === undefined) return null;
        t.set(key, value);
      } else {
        const value = evaluate(f.value);
        if (value === NOT_CONST) return null;
        t.set(next++, value);
      }
    }
    return t;
  }
  get(k) { return this.map.get(k); }
  set(k, v) { if (v === undefined) this.map.delete(k); else this.map.set(k, v); }
  has(k) { return this.map.has(k); }
  length() { let n = 0; while (this.map.has(n + 1)) n++; return n; }
}

const U64 = (1n << 64n) - 1n;
const toBig = (x) => (Number.isInteger(x) && Math.abs(x) <= Number.MAX_SAFE_INTEGER ? BigInt.asUintN(64, BigInt(x)) : null);
const fromBig = (b) => { const s = BigInt.asIntN(64, b); return s >= -9007199254740991n && s <= 9007199254740991n ? Number(s) : NOT_CONST; };

/** The integer operators of Lua 5.3 and Luau's compound forms, with 64-bit wrap-around, kept to results a double holds exactly. */
function bitwise(op, a, b) {
  if (typeof a !== 'number' || typeof b !== 'number') return NOT_CONST;
  const x = toBig(a);
  const y = toBig(b);
  if (x === null || y === null) return NOT_CONST;
  switch (op) {
    case '&': return fromBig(x & y);
    case '|': return fromBig(x | y);
    case '~': return fromBig(x ^ y);
    case '<<': return y >= 64n ? 0 : fromBig((x << y) & U64);
    case '>>': return y >= 64n ? 0 : fromBig(x >> y);
    default: return NOT_CONST;
  }
}

const LIBS = new Set(['string', 'math', 'bit32', 'bit']);
const NONE = new Set();

/**
 * @param {object} e expression
 * @param {(name: string) => any} lookup value of a plain name: a constant, a ConstTable, or NOT_CONST
 * @param {{shadowed?: Set<string>}} [opts] shadowed: names some local of the script is called, so `string.char(...)`, `tostring(...)` and the like
 *   may not be the standard functions
 */
export function evaluate(e, lookup, opts = {}) {
  e = strip(e);
  switch (e.type) {
    case 'Number': case 'String': return e.value;
    case 'True': return true;
    case 'False': return false;
    case 'Nil': return undefined;
    case 'Name': return lookup(e.name);
    case 'Unary': {
      if (e.op === '#') {
        const v = evaluate(e.arg, lookup, opts);
        if (typeof v === 'string') return v.length;
        if (v instanceof ConstTable) return v.length();
        return NOT_CONST;
      }
      if (e.op === '~') { const v = evaluate(e.arg, lookup, opts); return typeof v === 'number' && toBig(v) !== null ? fromBig(~toBig(v)) : NOT_CONST; }
      const v = evaluate(e.arg, lookup, opts);
      return v === NOT_CONST ? NOT_CONST : evalUnary(e.op, v);
    }
    case 'Binary': {
      if (e.op === 'and' || e.op === 'or') {
        const a = evaluate(e.left, lookup, opts);
        if (a === NOT_CONST) return NOT_CONST;
        const falsy = a === undefined || a === false;
        if (e.op === 'and' ? falsy : !falsy) return a;
        return evaluate(e.right, lookup, opts);
      }
      const a = evaluate(e.left, lookup, opts);
      if (a === NOT_CONST) return NOT_CONST;
      const b = evaluate(e.right, lookup, opts);
      if (b === NOT_CONST) return NOT_CONST;
      if (e.op === '&' || e.op === '|' || e.op === '~' || e.op === '<<' || e.op === '>>') return bitwise(e.op, a, b);
      if ((e.op === '==' || e.op === '~=') && (a instanceof ConstTable || b instanceof ConstTable)) return e.op === '==' ? a === b : a !== b;
      return evalBinary(e.op, a, b);
    }
    case 'Table': return ConstTable.fromNode(e, (x) => evaluate(x, lookup, opts)) || NOT_CONST;
    case 'IfExpr': {
      const c = evaluate(e.cond, lookup, opts);
      if (c === NOT_CONST) return NOT_CONST;
      return evaluate(c === undefined || c === false ? e.orelse : e.then, lookup, opts);
    }
    case 'Index': {
      const o = evaluate(e.obj, lookup, opts);
      if (!(o instanceof ConstTable)) return NOT_CONST;
      const k = e.key.type === 'String' && e.dot ? e.key.value : evaluate(e.key, lookup, opts);
      return k === NOT_CONST ? NOT_CONST : o.get(k);
    }
    case 'Call': {
      const f = e.fn;
      const shadowed = opts.shadowed || NONE;
      const std = f.type === 'Index' && f.obj.type === 'Name' && LIBS.has(f.obj.name) && f.key.type === 'String' && !shadowed.has(f.obj.name);
      const glob = f.type === 'Name' && !shadowed.has(f.name);
      if (!std && !glob) return NOT_CONST;
      const args = e.args.map((a) => evaluate(a, lookup, opts));
      if (args.some((a) => a === NOT_CONST)) return NOT_CONST;
      return std ? evalLibCall(f.obj.name, f.key.value, args) : evalGlobalCall(f.name, args);
    }
    default: return NOT_CONST;
  }
}

export const isFalsy = (v) => v === undefined || v === false;
