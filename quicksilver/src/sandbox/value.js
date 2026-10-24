// Value model of the sandbox interpreter.
//
//   nil -> undefined      boolean -> boolean      number -> number (double)
//   string -> JS string holding bytes (see core/bytes.js)
//   table -> LuaTable     function -> LuaFunction | NativeFunction     userdata -> LuaUserdata
//
// Nothing here touches the host: no globals, no I/O, no eval.

import { numberToLuaString, stringToNumber } from '../passes/consteval.js';

let ids = 0x1000;
const nextAddress = () => (ids += 0x28);

/** A Lua error value travelling through the JS stack; catchable by pcall. */
export class LuaError extends Error {
  constructor(value, traceback = null) {
    super(typeof value === 'string' ? value : 'lua error');
    this.value = value;
    this.traceback = traceback;
  }
}

/** The sandbox ran out of a budget (fuel, time, memory, output). Scripts cannot catch this. */
export class SandboxLimit extends Error {
  constructor(kind, detail = '') {
    super(`sandbox limit reached: ${kind}${detail ? ' (' + detail + ')' : ''}`);
    this.kind = kind;
  }
}

/** The script used something the sandbox deliberately does not provide. */
export class SandboxUnsupported extends Error {
  constructor(feature) {
    super(`unsupported in sandbox: ${feature}`);
    this.feature = feature;
  }
}

export class LuaTable {
  constructor() {
    this.arr = [];          // arr[i - 1] holds key i
    this.hash = null;       // Map for every other key
    this.meta = null;
    this.keyCache = null;   // snapshot of hash keys for next()
    this.keyPos = null;     // key -> position in keyCache
    this.addr = nextAddress();
    this.readonly = false;
  }

  get(key) {
    if (typeof key === 'number') {
      const i = key - 1;
      if (i >= 0 && i < this.arr.length && Number.isInteger(i)) return this.arr[i];
    }
    return this.hash === null ? undefined : this.hash.get(key);
  }

  getStr(key) { return this.hash === null ? undefined : this.hash.get(key); }

  set(key, value) {
    if (typeof key === 'number') {
      if (Number.isNaN(key)) throw new LuaError('table index is NaN');
      const i = key - 1;
      if (Number.isInteger(i) && i >= 0) {
        const arr = this.arr;
        if (i < arr.length) {
          arr[i] = value;
          if (value === undefined && i === arr.length - 1) {
            let n = arr.length - 1;
            while (n > 0 && arr[n - 1] === undefined) n--;
            arr.length = n;
          }
          return;
        }
        if (i === arr.length) {
          if (value === undefined) { if (this.hash) this.hash.delete(key); return; }
          arr.push(value);
          if (this.hash !== null && this.hash.size) this.migrate();
          return;
        }
      }
    } else if (key === undefined) {
      throw new LuaError('table index is nil');
    }
    if (value === undefined) {
      // keep the key snapshot: a traversal may clear fields it has already visited (allowed in Lua), and
      // next() must still find the key it is asked to continue from
      if (this.hash !== null) this.hash.delete(key);
      return;
    }
    if (this.hash === null) this.hash = new Map();
    if (!this.hash.has(key)) this.keyCache = null;
    this.hash.set(key, value);
  }

  /** After push(), pull following integer keys out of the hash part. */
  migrate() {
    let k = this.arr.length + 1;
    while (this.hash.has(k)) {
      this.arr.push(this.hash.get(k));
      this.hash.delete(k);
      this.keyCache = null;
      k++;
    }
  }

  /**
   * Positional store used by table constructors and SETLIST. Unlike set(), a nil keeps its slot, so
   * `{1, nil, 3}` has three array slots the way it does in the reference implementation.
   */
  listSet(i, value) {
    const idx = i - 1;
    if (idx === this.arr.length) this.arr.push(value);
    else if (idx < this.arr.length) this.arr[idx] = value;
    else this.set(i, value);
  }

  /** The border used by #t: the reference implementation's array-part search (luaH_getn). */
  length() {
    const a = this.arr;
    let j = a.length;
    if (j > 0 && a[j - 1] === undefined) {
      let i = 0;
      while (j - i > 1) {
        const m = (i + j) >>> 1;
        if (a[m - 1] === undefined) j = m; else i = m;
      }
      return i;
    }
    return j;
  }

  /** next(table, key) -> [key, value] | undefined when finished. */
  next(key) {
    const arr = this.arr;
    let i = 0;
    if (key !== undefined) {
      if (typeof key === 'number' && Number.isInteger(key) && key >= 1 && key <= arr.length) i = key;
      else {
        const keys = this.hashKeys();
        const at = this.keyPos.get(key);
        // an array slot cleared during the traversal can leave the array shorter than the key it is asked to
        // continue from; everything after it in the array part is empty, so carry on with the hash part
        if (at === undefined && Number.isInteger(key) && key >= 1) return this.nextInHash(keys, 0);
        if (at === undefined) throw new LuaError("invalid key to 'next'");
        return this.nextInHash(keys, at + 1);
      }
    }
    for (; i < arr.length; i++) if (arr[i] !== undefined) return [i + 1, arr[i]];
    return this.nextInHash(this.hashKeys(), 0);
  }

  hashKeys() {
    if (this.keyCache === null) {
      this.keyCache = this.hash ? [...this.hash.keys()] : [];
      this.keyPos = new Map();
      this.keyCache.forEach((k, i) => this.keyPos.set(k, i));
    }
    return this.keyCache;
  }

  nextInHash(keys, from) {
    for (let j = from; j < keys.length; j++) {
      const v = this.hash.get(keys[j]);
      if (v !== undefined) return [keys[j], v];
    }
    return undefined;
  }
}

export class LuaUserdata {
  constructor() { this.meta = null; this.addr = nextAddress(); }
}

/** Luau's `vector`: three floats. Behaves as a userdata whose metatable is shared (set up in the stdlib). */
export class LuaVector extends LuaUserdata {
  constructor(x, y, z) { super(); this.x = x; this.y = y; this.z = z; }
}

/** Luau's `buffer`: a fixed-size block of bytes. type() and typeof() answer "buffer". */
export class LuaBuffer {
  constructor(size) { this.bytes = new Uint8Array(size); this.addr = nextAddress(); }
}

/** Function implemented in JS. `fn(args, machine)` returns an array of results. */
export class NativeFunction {
  constructor(name, fn) { this.name = name; this.fn = fn; this.addr = nextAddress(); }
}

/** Function compiled from Lua source. */
export class LuaFunction {
  constructor(proto, upvals, env) {
    this.proto = proto;     // { name, line, nparams, call(fn, args) }
    this.upvals = upvals;
    this.env = env;
    this.addr = nextAddress();
  }
}

export const isFunction = (v) => v instanceof LuaFunction || v instanceof NativeFunction;

export function typeName(v) {
  switch (typeof v) {
    case 'undefined': return 'nil';
    case 'boolean': return 'boolean';
    case 'number': return 'number';
    case 'string': return 'string';
    default:
      if (v instanceof LuaTable) return 'table';
      if (isFunction(v)) return 'function';
      if (v instanceof LuaVector) return 'vector';
      if (v instanceof LuaBuffer) return 'buffer';
      return 'userdata';
  }
}

const hex = (n) => '0x' + n.toString(16).padStart(8, '0');

/** tostring() without metamethods. */
export function rawToString(v) {
  switch (typeof v) {
    case 'undefined': return 'nil';
    case 'boolean': return v ? 'true' : 'false';
    case 'number': return numberToLuaString(v);
    case 'string': return v;
    default:
      if (v instanceof LuaTable) return 'table: ' + hex(v.addr);
      if (v instanceof NativeFunction) return 'function: builtin: ' + hex(v.addr);
      if (v instanceof LuaFunction) return 'function: ' + hex(v.addr);
      if (v instanceof LuaVector) return numberToLuaString(v.x) + ', ' + numberToLuaString(v.y) + ', ' + numberToLuaString(v.z);
      if (v instanceof LuaUserdata) return 'userdata: ' + hex(v.addr);
      if (v instanceof LuaBuffer) return 'buffer: ' + hex(v.addr);
      return 'userdata: ' + hex(0);
  }
}

/** Lua's tonumber for a value (strings are parsed), undefined if not numeric. */
export function toNumber(v) {
  if (typeof v === 'number') return v;
  if (typeof v === 'string') return stringToNumber(v);
  return undefined;
}

export const truthy = (v) => v !== undefined && v !== false;

export function fromJsArray(list) {
  const t = new LuaTable();
  for (let i = 0; i < list.length; i++) t.set(i + 1, list[i]);
  return t;
}
