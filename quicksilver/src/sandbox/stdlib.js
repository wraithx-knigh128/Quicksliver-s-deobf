// Standard library for the sandbox interpreter.
//
// Deliberately absent: io, os.execute / remove / rename / exit / getenv, package, require, dofile,
// loadfile, any network or file access. `os.time` / `os.clock` / `math.random` are virtual and
// deterministic so that evaluating the same script twice gives the same answer.

import {
  LuaTable, LuaUserdata, LuaBuffer, LuaVector, LuaFunction, NativeFunction, LuaError, SandboxLimit, SandboxUnsupported,
  typeName, toNumber, truthy, isFunction, fromJsArray,
} from './value.js';
import { callValue, tostr, index, lessThan, compileSource, concat as vmConcat } from './interp.js';
import { LuaSyntaxError } from '../core/parser.js';
import { numberToLuaString, stringToNumber } from '../passes/consteval.js';
import { strFind, gmatchIter, strGsub, strFormat } from './lstring.js';
import { strPack, strUnpack, strPackSize } from './lpack.js';
import { isBytecode, loadBytecode, BytecodeError } from './bytecode.js';

const nf = (name, fn) => new NativeFunction(name, fn);

function lib(m, name, entries) {
  const t = new LuaTable();
  for (const [k, v] of Object.entries(entries)) t.set(k, typeof v === 'function' ? nf(`${name}.${k}`, v) : v);
  if (name) m.globals.set(name, t);
  return t;
}

const argError = (n, fname, msg) => new LuaError(`bad argument #${n} to '${fname}' (${msg})`);

function checkStr(args, i, fname) {
  const v = args[i];
  if (typeof v === 'string') return v;
  if (typeof v === 'number') return numberToLuaString(v);
  throw argError(i + 1, fname, `string expected, got ${i >= args.length ? 'no value' : typeName(v)}`);
}

function checkNum(args, i, fname, def) {
  const v = args[i];
  if (v === undefined && def !== undefined) return def;
  const n = toNumber(v);
  if (n === undefined) throw argError(i + 1, fname, `number expected, got ${i >= args.length ? 'no value' : typeName(v)}`);
  return n;
}

function checkInt(args, i, fname, def) {
  const n = checkNum(args, i, fname, def);
  return Number.isFinite(n) ? Math.trunc(n) : n;
}

function checkTable(args, i, fname) {
  const t = args[i];
  if (!(t instanceof LuaTable)) throw argError(i + 1, fname, `table expected, got ${i >= args.length ? 'no value' : typeName(t)}`);
  return t;
}

/** Install the library set. `options.dialect`: 'luau' (default) | 'lua51' | 'luajit'. */
export function installStdlib(m, options = {}) {
  const dialect = options.dialect || 'luau';
  const G = m.globals;
  G.set('_G', G);
  G.set('_VERSION', dialect === 'luau' ? 'Luau' : 'Lua 5.1');

  // ---- base ----
  const nextFn = nf('next', (a) => {
    const t = checkTable(a, 0, 'next');
    const kv = t.next(a[1]);
    return kv ? kv : [undefined];
  });
  m.nextFn = nextFn;

  const base = {
    print: (a) => { m.write(a.map((v) => tostr(m, v)).join('\t') + '\n'); return []; },
    type: (a) => {
      if (a.length === 0) throw argError(1, 'type', 'value expected');
      return [typeName(a[0])];
    },
    tostring: (a) => [tostr(m, a[0])],
    ...(dialect === 'luau' ? { typeof: (a) => { if (a.length === 0) throw argError(1, 'typeof', 'value expected'); return [typeName(a[0])]; } } : {}),
    tonumber: (a) => {
      const v = a[0];
      if (a[1] === undefined) {
        if (typeof v === 'number') return [v];
        if (typeof v === 'string') return [stringToNumber(v)];
        return [undefined];
      }
      const radix = checkInt(a, 1, 'tonumber');
      if (radix < 2 || radix > 36) throw argError(2, 'tonumber', 'base out of range');
      const s = checkStr(a, 0, 'tonumber').trim().toLowerCase();
      const ok = new RegExp(`^-?[${'0123456789abcdefghijklmnopqrstuvwxyz'.slice(0, radix)}]+$`);
      return [ok.test(s) ? parseInt(s, radix) : undefined];
    },
    rawget: (a) => [checkTable(a, 0, 'rawget').get(a[1])],
    rawset: (a) => { checkTable(a, 0, 'rawset').set(a[1], a[2]); return [a[0]]; },
    rawequal: (a) => [a[0] === a[1]],
    rawlen: (a) => [typeof a[0] === 'string' ? a[0].length : checkTable(a, 0, 'rawlen').length()],
    next: nextFn,
    pairs: (a) => {
      const h = a[0] instanceof LuaTable && a[0].meta ? a[0].meta.getStr('__pairs') : undefined;
      if (h !== undefined) { const r = callValue(m, h, [a[0]], ''); return [r[0], r[1], r[2]]; }
      checkTable(a, 0, 'pairs');
      return [nextFn, a[0], undefined];
    },
    ipairs: (a) => {
      if (a[0] === undefined) throw argError(1, 'ipairs', 'table expected, got no value');
      return [ipairsIter, a[0], 0];
    },
    select: (a) => {
      if (a[0] === '#') return [a.length - 1];
      const n = checkInt(a, 0, 'select');
      if (n < 0) { const k = a.length - 1 + n; if (k < 0) throw argError(1, 'select', 'index out of range'); return a.slice(k + 1); }
      if (n === 0) throw argError(1, 'select', 'index out of range');
      return a.slice(n);
    },
    assert: (a) => {
      if (a.length === 0) throw argError(1, 'assert', 'value expected');
      if (!truthy(a[0])) throw new LuaError(a.length > 1 ? a[1] : 'assertion failed!');
      return a;
    },
    error: (a) => {
      let v = a[0];
      const level = a[1] === undefined ? 1 : checkInt(a, 1, 'error');
      if (typeof v === 'string' && level > 0) v = `${m.where()} ${v}`;
      throw new LuaError(v);
    },
    pcall: (a) => {
      if (a.length === 0) throw argError(1, 'pcall', 'value expected');
      const saved = m.depth;
      try {
        return [true, ...callValue(m, a[0], a.slice(1), '')];
      } catch (e) {
        m.depth = saved;
        return [false, errorValue(e)];
      }
    },
    xpcall: (a) => {
      const saved = m.depth;
      try {
        return [true, ...callValue(m, a[0], a.slice(2), '')];
      } catch (e) {
        m.depth = saved;
        const v = errorValue(e);
        return [false, ...callValue(m, a[1], [v], '')];
      }
    },
    setmetatable: (a) => {
      const t = a[0];
      if (!(t instanceof LuaTable)) throw argError(1, 'setmetatable', `table expected, got ${typeName(t)}`);
      if (a[1] !== undefined && !(a[1] instanceof LuaTable)) throw argError(2, 'setmetatable', 'nil or table expected');
      if (t.meta && t.meta.getStr('__metatable') !== undefined) throw new LuaError('cannot change a protected metatable');
      t.meta = a[1] === undefined ? null : a[1];
      return [t];
    },
    getmetatable: (a) => {
      const v = a[0];
      const mt = v instanceof LuaTable || v instanceof LuaUserdata ? v.meta : typeof v === 'string' ? m.stringMeta : null;
      if (!mt) return [undefined];
      const protectedValue = mt.getStr('__metatable');
      return [protectedValue !== undefined ? protectedValue : mt];
    },
    getfenv: (a) => {
      const f = a[0];
      if (f instanceof LuaFunction) return [f.env];
      return [G];
    },
    setfenv: (a) => {
      if (a[0] instanceof LuaFunction && a[1] instanceof LuaTable) a[0].env = a[1];
      return [a[0]];
    },
    unpack: (a) => unpack(a),
    collectgarbage: (a) => {
      const opt = a[0] === undefined ? 'collect' : a[0];
      if (opt === 'count') return [312.5 + (m.fuel % 17) / 100, 0];
      return [0];
    },
    gcinfo: () => [312],
    newproxy: (a) => {
      const u = new LuaUserdata();
      if (a[0] === true) u.meta = new LuaTable();
      else if (a[0] instanceof LuaUserdata) u.meta = a[0].meta;
      return [u];
    },
    loadstring: (a) => loadImpl(a[0], a[1], undefined),
    load: (a) => {
      let src = a[0];
      if (isFunction(src)) {
        let all = '';
        for (;;) { const piece = callValue(m, src, [], '')[0]; if (piece === undefined || piece === '') break; all += piece; }
        src = all;
      }
      return loadImpl(src, a[1], a[3] instanceof LuaTable ? a[3] : undefined);
    },
  };
  for (const [k, fn] of Object.entries(base)) G.set(k, fn instanceof NativeFunction ? fn : nf(k, fn));
  G.set('next', nextFn);
  if (dialect === 'lua51' || dialect === 'luajit') G.set('_VERSION', 'Lua 5.1');

  const ipairsIter = nf('ipairs_iter', (a) => {
    const i = a[1] + 1;
    const v = a[0] instanceof LuaTable ? a[0].get(i) : index(m, a[0], i);
    return v === undefined ? [undefined] : [i, v];
  });

  function errorValue(e) {
    if (e instanceof LuaError) return e.value;
    if (e instanceof SandboxLimit || e instanceof SandboxUnsupported) throw e;
    if (e instanceof RangeError) return 'stack overflow';
    throw e;
  }

  function unpack(a) {
    const t = checkTable(a, 0, 'unpack');
    const i = a[1] === undefined ? 1 : checkInt(a, 1, 'unpack');
    const j = a[2] === undefined ? t.length() : checkInt(a, 2, 'unpack');
    if (j - i >= 1_000_000) throw new LuaError('too many results to unpack');
    const out = [];
    for (let k = i; k <= j; k++) out.push(t.get(k));
    return out;
  }

  function loadImpl(src, chunkName, env) {
    if (typeof src !== 'string') return [undefined, 'bad argument #1 to \'load\' (string expected)'];
    m.loads.push({ source: src, chunkName: typeof chunkName === 'string' ? chunkName : null });
    if (m.hooks.onLoad) m.hooks.onLoad(src, chunkName);   // may throw SandboxLimit('halt') to stop after capture
    if (isBytecode(src)) {
      try { return [loadBytecode(m, src, env || G)]; } catch (e) {
        if (e instanceof BytecodeError) return [undefined, `bad binary chunk: ${e.message}`];
        throw e;
      }
    }
    try {
      const display = typeof chunkName === 'string' ? chunkName.replace(/^[=@]/, '') : `[string "${src.split('\n')[0].slice(0, 40)}"]`;
      return [compileSource(m, src, display, env || G)];
    } catch (e) {
      if (e instanceof LuaSyntaxError) return [undefined, `[string "${src.split('\n')[0].slice(0, 40)}"]:${e.line}: ${e.message.replace(/^\d+:\d+: /, '')}`];
      throw e;
    }
  }

  // ---- string ----
  const strLib = lib(m, 'string', {
    len: (a) => [checkStr(a, 0, 'len').length],
    sub: (a) => {
      const s = checkStr(a, 0, 'sub');
      let i = checkInt(a, 1, 'sub', 1);
      let j = checkInt(a, 2, 'sub', -1);
      const len = s.length;
      if (i < 0) i = Math.max(len + i + 1, 1); else if (i === 0) i = 1;
      if (j < 0) j = len + j + 1; else if (j > len) j = len;
      return [i > j ? '' : s.slice(i - 1, j)];
    },
    upper: (a) => [checkStr(a, 0, 'upper').replace(/[a-z]/g, (c) => c.toUpperCase())],
    lower: (a) => [checkStr(a, 0, 'lower').replace(/[A-Z]/g, (c) => c.toLowerCase())],
    reverse: (a) => [checkStr(a, 0, 'reverse').split('').reverse().join('')],
    rep: (a) => {
      const s = checkStr(a, 0, 'rep');
      const n = checkInt(a, 1, 'rep');
      const sep = a[2] === undefined ? '' : checkStr(a, 2, 'rep');
      if (n <= 0) return [''];
      m.checkString((s.length + sep.length) * n);
      return [sep ? Array(n).fill(s).join(sep) : s.repeat(n)];
    },
    byte: (a) => {
      const s = checkStr(a, 0, 'byte');
      let i = checkInt(a, 1, 'byte', 1);
      let j = checkInt(a, 2, 'byte', i);
      const len = s.length;
      if (i < 0) i = Math.max(len + i + 1, 1); else if (i === 0) i = 1;
      if (j < 0) j = len + j + 1; else if (j > len) j = len;
      const out = [];
      for (let k = i; k <= j; k++) out.push(s.charCodeAt(k - 1));
      return out;
    },
    char: (a) => {
      let out = '';
      for (let i = 0; i < a.length; i++) {
        const n = checkInt(a, i, 'char');
        if (n < 0 || n > 255) throw argError(i + 1, 'char', 'invalid value');
        out += String.fromCharCode(n);
      }
      return [out];
    },
    ...(dialect === 'lua51' || dialect === 'luajit' ? {} : {
      pack: (a) => { const out = strPack(checkStr(a, 0, 'pack'), a.slice(1)); m.checkString(out.length); return [out]; },
      unpack: (a) => strUnpack(checkStr(a, 0, 'unpack'), checkStr(a, 1, 'unpack'), a[2] === undefined ? undefined : checkInt(a, 2, 'unpack')),
      packsize: (a) => [strPackSize(checkStr(a, 0, 'packsize'))],
    }),
    format: (a) => {
      const out = strFormat(checkStr(a, 0, 'format'), a.slice(1), (v) => tostr(m, v), toNumber);
      m.checkString(out.length);
      return [out];
    },
    find: (a) => strFind(checkStr(a, 0, 'find'), checkStr(a, 1, 'find'), a[2] === undefined ? 1 : checkInt(a, 2, 'find'), truthy(a[3]), true),
    match: (a) => strFind(checkStr(a, 0, 'match'), checkStr(a, 1, 'match'), a[2] === undefined ? 1 : checkInt(a, 2, 'match'), false, false),
    gmatch: (a) => {
      const it = gmatchIter(checkStr(a, 0, 'gmatch'), checkStr(a, 1, 'gmatch'));
      return [nf('gmatch_iter', () => { m.tick(); return it(); })];
    },
    gsub: (a) => {
      const s = checkStr(a, 0, 'gsub');
      const p = checkStr(a, 1, 'gsub');
      const r = a[2];
      const maxN = a[3] === undefined ? undefined : checkInt(a, 3, 'gsub');
      let kind;
      let repl = r;
      if (typeof r === 'string' || typeof r === 'number') { kind = 'string'; repl = typeof r === 'number' ? numberToLuaString(r) : r; }
      else if (r instanceof LuaTable) { kind = 'table'; repl = (_k, first) => index(m, r, first); }
      else if (isFunction(r)) { kind = 'function'; repl = (_k, _first, caps) => { m.tick(); return callValue(m, r, caps, '')[0]; }; }
      else throw argError(3, 'gsub', `string/function/table expected, got ${typeName(r)}`);
      const res = strGsub(s, p, kind, repl, maxN, (v) => typeName(v));
      m.checkString(res[0].length);
      return res;
    },
  });
  m.stringMeta = new LuaTable();
  m.stringMeta.set('__index', strLib);

  // ---- table ----
  lib(m, 'table', {
    insert: (a) => {
      const t = checkTable(a, 0, 'insert');
      if (t.readonly) throw new LuaError('attempt to modify a readonly table');
      const n = t.length();
      if (a.length === 2) { t.set(n + 1, a[1]); return []; }
      if (a.length !== 3) throw new LuaError("wrong number of arguments to 'insert'");
      const pos = checkInt(a, 1, 'insert');
      if (pos < 1 || pos > n + 1) throw argError(2, 'insert', 'position out of bounds');
      for (let i = n; i >= pos; i--) t.set(i + 1, t.get(i));
      t.set(pos, a[2]);
      return [];
    },
    remove: (a) => {
      const t = checkTable(a, 0, 'remove');
      if (t.readonly) throw new LuaError('attempt to modify a readonly table');
      const n = t.length();
      if (a[1] === undefined) { if (n === 0) return [undefined]; const v = t.get(n); t.set(n, undefined); return [v]; }
      const pos = checkInt(a, 1, 'remove');
      if (n === 0 && (pos === 0 || pos === n)) return [t.get(pos)];
      if (pos < 1 || pos > n + 1) throw argError(2, 'remove', 'position out of bounds');
      const v = t.get(pos);
      for (let i = pos; i < n; i++) t.set(i, t.get(i + 1));
      if (pos <= n) t.set(n, undefined);
      return [v];
    },
    concat: (a) => {
      const t = checkTable(a, 0, 'concat');
      const sep = a[1] === undefined ? '' : checkStr(a, 1, 'concat');
      const i = checkInt(a, 2, 'concat', 1);
      const j = a[3] === undefined ? t.length() : checkInt(a, 3, 'concat');
      const parts = [];
      let total = 0;
      for (let k = i; k <= j; k++) {
        const v = t.get(k);
        if (typeof v !== 'string' && typeof v !== 'number') throw new LuaError(`invalid value (at index ${k}) in table for 'concat'`);
        const s = typeof v === 'number' ? numberToLuaString(v) : v;
        total += s.length + sep.length;
        if (total > m.maxString) throw new SandboxLimit('memory', 'string too large');
        parts.push(s);
      }
      return [parts.join(sep)];
    },
    unpack: (a) => unpack(a),
    pack: (a) => { const t = fromJsArray(a); t.set('n', a.length); return [t]; },
    getn: (a) => [checkTable(a, 0, 'getn').length()],
    maxn: (a) => {
      const t = checkTable(a, 0, 'maxn');
      let mx = t.length();
      if (t.hash) for (const k of t.hash.keys()) if (typeof k === 'number' && k > mx) mx = k;
      return [mx];
    },
    sort: (a) => {
      const t = checkTable(a, 0, 'sort');
      const n = t.length();
      const items = [];
      for (let i = 1; i <= n; i++) items.push(t.get(i));
      const cmp = a[1];
      const lt = cmp === undefined ? (x, y) => lessThan(m, x, y) : (x, y) => { m.tick(); return truthy(callValue(m, cmp, [x, y], '')[0]); };
      items.sort((x, y) => (lt(x, y) ? -1 : lt(y, x) ? 1 : 0));
      for (let i = 0; i < n; i++) t.set(i + 1, items[i]);
      return [];
    },
    clear: (a) => { const t = checkTable(a, 0, 'clear'); t.arr = []; t.hash = null; t.keyCache = null; return []; },
    find: (a) => {
      const t = checkTable(a, 0, 'find');
      for (let i = checkInt(a, 2, 'find', 1); i <= t.length(); i++) if (t.get(i) === a[1]) return [i];
      return [undefined];
    },
    create: (a) => {
      const t = new LuaTable();
      const n = checkInt(a, 0, 'create');
      if (n > 1_000_000) throw new SandboxLimit('memory', 'table.create');
      for (let i = 1; i <= n; i++) t.set(i, a[1]);
      return [t];
    },
    clone: (a) => {
      const t = checkTable(a, 0, 'clone');
      const c = new LuaTable();
      c.arr = t.arr.slice();
      if (t.hash) c.hash = new Map(t.hash);
      return [c];
    },
    freeze: (a) => { checkTable(a, 0, 'freeze').readonly = true; return [a[0]]; },
    isfrozen: (a) => [checkTable(a, 0, 'isfrozen').readonly],
    move: (a) => {
      const src = checkTable(a, 0, 'move');
      const f = checkInt(a, 1, 'move');
      const e = checkInt(a, 2, 'move');
      const t = checkInt(a, 3, 'move');
      const dst = a[4] === undefined ? src : checkTable(a, 4, 'move');
      if (e >= f) {
        if (t > e || t <= f || dst !== src) for (let i = 0; i <= e - f; i++) dst.set(t + i, src.get(f + i));
        else for (let i = e - f; i >= 0; i--) dst.set(t + i, src.get(f + i));
      }
      return [dst];
    },
  });

  const u32 = (n) => ((n >>> 0) === n ? n : (Math.floor(n) % 4294967296 + 4294967296) % 4294967296);
  // ---- math ----
  let seed = 0x2545f491;
  const rnd = () => {
    seed ^= seed << 13; seed >>>= 0;
    seed ^= seed >>> 17;
    seed ^= seed << 5; seed >>>= 0;
    return seed / 4294967296;
  };
  const mathFn = (name, f) => (a) => [f(checkNum(a, 0, name))];
  lib(m, 'math', {
    pi: Math.PI,
    huge: Infinity,
    ...(dialect === 'lua51' || dialect === 'luajit' ? {} : { maxinteger: 9223372036854775807n, mininteger: -9223372036854775808n }),
    abs: mathFn('abs', Math.abs), ceil: mathFn('ceil', Math.ceil), floor: mathFn('floor', Math.floor),
    sqrt: mathFn('sqrt', Math.sqrt), sin: mathFn('sin', Math.sin), cos: mathFn('cos', Math.cos), tan: mathFn('tan', Math.tan),
    asin: mathFn('asin', Math.asin), acos: mathFn('acos', Math.acos), atan: mathFn('atan', Math.atan),
    sinh: mathFn('sinh', Math.sinh), cosh: mathFn('cosh', Math.cosh), tanh: mathFn('tanh', Math.tanh),
    exp: mathFn('exp', Math.exp), log10: mathFn('log10', Math.log10),
    deg: mathFn('deg', (x) => (x * 180) / Math.PI), rad: mathFn('rad', (x) => (x * Math.PI) / 180),
    atan2: (a) => [Math.atan2(checkNum(a, 0, 'atan2'), checkNum(a, 1, 'atan2'))],
    pow: (a) => [Math.pow(checkNum(a, 0, 'pow'), checkNum(a, 1, 'pow'))],
    fmod: (a) => [checkNum(a, 0, 'fmod') % checkNum(a, 1, 'fmod')],
    log: (a) => {
      const x = checkNum(a, 0, 'log');
      if (a[1] === undefined) return [Math.log(x)];
      const b = checkNum(a, 1, 'log');
      return [b === 2 ? Math.log2(x) : b === 10 ? Math.log10(x) : Math.log(x) / Math.log(b)];
    },
    modf: (a) => { const x = checkNum(a, 0, 'modf'); const i = x < 0 ? Math.ceil(x) : Math.floor(x); return [i, Number.isFinite(x) ? x - i : 0]; },
    frexp: (a) => {
      const x = checkNum(a, 0, 'frexp');
      if (x === 0 || !Number.isFinite(x)) return [x, 0];
      const e = Math.floor(Math.log2(Math.abs(x))) + 1;
      return [x / Math.pow(2, e), e];
    },
    ldexp: (a) => [checkNum(a, 0, 'ldexp') * Math.pow(2, checkInt(a, 1, 'ldexp'))],
    max: (a) => { let r = checkNum(a, 0, 'max'); for (let i = 1; i < a.length; i++) r = Math.max(r, checkNum(a, i, 'max')); return [r]; },
    min: (a) => { let r = checkNum(a, 0, 'min'); for (let i = 1; i < a.length; i++) r = Math.min(r, checkNum(a, i, 'min')); return [r]; },
    random: (a) => {
      if (a.length === 0) return [rnd()];
      const lo = a.length === 1 ? 1 : checkInt(a, 0, 'random');
      const hi = a.length === 1 ? checkInt(a, 0, 'random') : checkInt(a, 1, 'random');
      if (lo > hi) throw argError(a.length === 1 ? 1 : 2, 'random', 'interval is empty');
      return [lo + Math.floor(rnd() * (hi - lo + 1))];
    },
    randomseed: (a) => { seed = (Math.trunc(checkNum(a, 0, 'randomseed', 0)) >>> 0) || 0x2545f491; return []; },
    clamp: (a) => [Math.min(Math.max(checkNum(a, 0, 'clamp'), checkNum(a, 1, 'clamp')), checkNum(a, 2, 'clamp'))],
    sign: (a) => [Math.sign(checkNum(a, 0, 'sign'))],
    round: (a) => { const x = checkNum(a, 0, 'round'); return [x < 0 ? -Math.floor(-x + 0.5) : Math.floor(x + 0.5)]; },
    // Lua 5.3+ helpers. Numbers are doubles here, so "integer" means integer-valued.
    tointeger: (a) => { if (typeof a[0] === 'bigint') return [a[0]]; const x = toNumber(a[0]); return [typeof a[0] !== 'boolean' && x !== undefined && Number.isInteger(x) ? x : undefined]; },
    type: (a) => [typeof a[0] === 'bigint' ? 'integer' : typeof a[0] === 'number' ? (Number.isInteger(a[0]) ? 'integer' : 'float') : undefined],
    ult: (a) => [u32(checkNum(a, 0, 'ult')) < u32(checkNum(a, 1, 'ult'))],
  });

  // ---- os (virtual) ----
  let now = 1_700_000_000;
  lib(m, 'os', {
    time: (a) => {
      if (a[0] instanceof LuaTable) {
        const f = (k, d) => { const v = toNumber(a[0].get(k)); return v === undefined ? d : v; };
        return [Math.floor(Date.UTC(f('year', 1970), f('month', 1) - 1, f('day', 1), f('hour', 12), f('min', 0), f('sec', 0)) / 1000)];
      }
      return [now++];
    },
    clock: () => { m.clock += 0.001; return [m.clock]; },
    date: (a) => {
      const fmt = a[0] === undefined ? '%c' : checkStr(a, 0, 'date');
      const d = new Date((a[1] === undefined ? now : checkNum(a, 1, 'date')) * 1000);
      const p2 = (n) => String(n).padStart(2, '0');
      if (fmt.replace(/^!/, '').startsWith('*t')) {
        const t = new LuaTable();
        t.set('year', d.getUTCFullYear()); t.set('month', d.getUTCMonth() + 1); t.set('day', d.getUTCDate());
        t.set('hour', d.getUTCHours()); t.set('min', d.getUTCMinutes()); t.set('sec', d.getUTCSeconds());
        t.set('wday', d.getUTCDay() + 1); t.set('yday', 1); t.set('isdst', false);
        return [t];
      }
      const out = fmt.replace(/^!/, '').replace(/%([a-zA-Z%])/g, (_x, c) => ({
        Y: d.getUTCFullYear(), y: p2(d.getUTCFullYear() % 100), m: p2(d.getUTCMonth() + 1), d: p2(d.getUTCDate()),
        H: p2(d.getUTCHours()), M: p2(d.getUTCMinutes()), S: p2(d.getUTCSeconds()), '%': '%',
        c: d.toUTCString(), x: `${p2(d.getUTCMonth() + 1)}/${p2(d.getUTCDate())}/${p2(d.getUTCFullYear() % 100)}`,
        X: `${p2(d.getUTCHours())}:${p2(d.getUTCMinutes())}:${p2(d.getUTCSeconds())}`,
      }[c] ?? ''));
      return [out];
    },
    difftime: (a) => [checkNum(a, 0, 'difftime') - checkNum(a, 1, 'difftime', 0)],
  });

  // ---- bit libraries ----
  const s32 = (n) => u32(n) | 0;
  const bitOps = (conv, names) => {
    const fold = (f) => (a) => { if (a.length === 2 && typeof a[0] === 'number' && typeof a[1] === 'number') return [conv(f(u32(a[0]), u32(a[1])) >>> 0)]; let r = u32(checkNum(a, 0, 'bit')); for (let i = 1; i < a.length; i++) r = f(r, u32(checkNum(a, i, 'bit'))) >>> 0; return [conv(r)]; };
    const entries = {
      band: fold((x, y) => x & y), bor: fold((x, y) => x | y), bxor: fold((x, y) => x ^ y),
      bnot: (a) => [conv(~u32(checkNum(a, 0, 'bnot')) >>> 0)],
      lshift: (a) => { const n = checkInt(a, 1, 'lshift') & 255; return [conv(n >= 32 ? 0 : (u32(checkNum(a, 0, 'lshift')) << n) >>> 0)]; },
      rshift: (a) => { const n = checkInt(a, 1, 'rshift') & 255; return [conv(n >= 32 ? 0 : u32(checkNum(a, 0, 'rshift')) >>> n)]; },
      arshift: (a) => { const n = Math.min(checkInt(a, 1, 'arshift') & 255, 31); return [conv(((u32(checkNum(a, 0, 'arshift')) | 0) >> n) >>> 0)]; },
    };
    const rot = (left) => (a) => { const x = u32(checkNum(a, 0, 'rotate')); const n = ((checkInt(a, 1, 'rotate') % 32) + 32) % 32; const k = left ? n : (32 - n) % 32; return [conv(k === 0 ? x : ((x << k) | (x >>> (32 - k))) >>> 0)]; };
    for (const [k, v] of Object.entries(names(rot))) entries[k] = v;
    return entries;
  };
  if (dialect === 'luau') {
    lib(m, 'bit32', {
      ...bitOps((x) => x, (rot) => ({ lrotate: rot(true), rrotate: rot(false) })),
      countlz: (a) => [Math.clz32(u32(checkNum(a, 0, 'countlz')))],
      countrz: (a) => { const x = u32(checkNum(a, 0, 'countrz')); return [x === 0 ? 32 : 31 - Math.clz32(x & -x)]; },
      byteswap: (a) => { const x = u32(checkNum(a, 0, 'byteswap')); return [(((x & 255) << 24) | ((x & 65280) << 8) | ((x >>> 8) & 65280) | (x >>> 24)) >>> 0]; },
      btest: (a) => { let r = 0xffffffff; for (let i = 0; i < a.length; i++) r = (r & u32(checkNum(a, i, 'btest'))) >>> 0; return [r !== 0]; },
      extract: (a) => { const x = u32(checkNum(a, 0, 'extract')); const f = checkInt(a, 1, 'extract'); const w = checkInt(a, 2, 'extract', 1); return [(x >>> f) & (w >= 32 ? 0xffffffff : (1 << w) - 1)]; },
      replace: (a) => {
        const x = u32(checkNum(a, 0, 'replace')); const v = u32(checkNum(a, 1, 'replace')); const f = checkInt(a, 2, 'replace'); const w = checkInt(a, 3, 'replace', 1);
        const mask = (w >= 32 ? 0xffffffff : (1 << w) - 1) >>> 0;
        return [((x & ~(mask << f)) | ((v & mask) << f)) >>> 0];
      },
    });
  }
  if (dialect === 'luajit') {
    lib(m, 'bit', {
      ...bitOps(s32, (rot) => ({ rol: rot(true), ror: rot(false) })),
      tobit: (a) => [s32(checkNum(a, 0, 'tobit'))],
      tohex: (a) => { const n = checkInt(a, 1, 'tohex', 8); const h = u32(checkNum(a, 0, 'tohex')).toString(16).padStart(8, '0'); return [n < 0 ? h.slice(8 + n).toUpperCase() : h.slice(8 - n)]; },
      bswap: (a) => { const x = u32(checkNum(a, 0, 'bswap')); return [s32(((x & 255) << 24) | ((x & 65280) << 8) | ((x >>> 8) & 65280) | (x >>> 24))]; },
    });
  }

  // ---- buffer (Luau) ----
  if (dialect === 'luau') {
    const MAX_BUFFER = 64 * 1024 * 1024;
    const checkBuf = (a, i, fname) => {
      if (!(a[i] instanceof LuaBuffer)) throw argError(i + 1, fname, `buffer expected, got ${i >= a.length ? 'no value' : typeName(a[i])}`);
      return a[i];
    };
    const oob = () => new LuaError('buffer access out of bounds');
    const view = (b, off, size, fname) => {
      if (!Number.isFinite(off) || off < 0 || off + size > b.bytes.length) throw oob();
      return new DataView(b.bytes.buffer, b.bytes.byteOffset + Math.trunc(off), size);
    };
    const reader = (name, size, read) => (a) => { const b = checkBuf(a, 0, name); return [read(view(b, checkInt(a, 1, name), size, name))]; };
    const writer = (name, size, write) => (a) => { const b = checkBuf(a, 0, name); const v = checkNum(a, 2, name); write(view(b, checkInt(a, 1, name), size, name), v); return []; };
    const wrapInt = (bits, signed) => (v) => { const x = Math.trunc(v); const mod = 2 ** bits; const r = ((x % mod) + mod) % mod; return signed && r >= mod / 2 ? r - mod : r; };
    lib(m, 'buffer', {
      create: (a) => {
        const n = checkInt(a, 0, 'create');
        if (!(n >= 0)) throw argError(1, 'create', 'invalid size');
        if (n > MAX_BUFFER) throw new SandboxLimit('memory', `buffer of ${n} bytes`);
        m.checkMemory && m.checkMemory(n);
        return [new LuaBuffer(n)];
      },
      fromstring: (a) => {
        const s = checkStr(a, 0, 'fromstring');
        const b = new LuaBuffer(s.length);
        for (let i = 0; i < s.length; i++) b.bytes[i] = s.charCodeAt(i) & 255;
        return [b];
      },
      tostring: (a) => {
        const b = checkBuf(a, 0, 'tostring');
        let out = '';
        for (let i = 0; i < b.bytes.length; i += 8192) out += String.fromCharCode.apply(null, b.bytes.subarray(i, i + 8192));
        return [out];
      },
      len: (a) => [checkBuf(a, 0, 'len').bytes.length],
      readi8: reader('readi8', 1, (v) => v.getInt8(0)),
      readu8: reader('readu8', 1, (v) => v.getUint8(0)),
      readi16: reader('readi16', 2, (v) => v.getInt16(0, true)),
      readu16: reader('readu16', 2, (v) => v.getUint16(0, true)),
      readi32: reader('readi32', 4, (v) => v.getInt32(0, true)),
      readu32: reader('readu32', 4, (v) => v.getUint32(0, true)),
      readf32: reader('readf32', 4, (v) => v.getFloat32(0, true)),
      readf64: reader('readf64', 8, (v) => v.getFloat64(0, true)),
      writei8: writer('writei8', 1, (v, x) => v.setInt8(0, wrapInt(8, true)(x))),
      writeu8: writer('writeu8', 1, (v, x) => v.setUint8(0, wrapInt(8, false)(x))),
      writei16: writer('writei16', 2, (v, x) => v.setInt16(0, wrapInt(16, true)(x), true)),
      writeu16: writer('writeu16', 2, (v, x) => v.setUint16(0, wrapInt(16, false)(x), true)),
      writei32: writer('writei32', 4, (v, x) => v.setInt32(0, wrapInt(32, true)(x), true)),
      writeu32: writer('writeu32', 4, (v, x) => v.setUint32(0, wrapInt(32, false)(x), true)),
      writef32: writer('writef32', 4, (v, x) => v.setFloat32(0, x, true)),
      writef64: writer('writef64', 8, (v, x) => v.setFloat64(0, x, true)),
      readstring: (a) => {
        const b = checkBuf(a, 0, 'readstring');
        const off = checkInt(a, 1, 'readstring');
        const n = checkInt(a, 2, 'readstring');
        if (off < 0 || n < 0 || off + n > b.bytes.length) throw oob();
        return [String.fromCharCode.apply(null, b.bytes.subarray(off, off + n))];
      },
      writestring: (a) => {
        const b = checkBuf(a, 0, 'writestring');
        const off = checkInt(a, 1, 'writestring');
        const s = checkStr(a, 2, 'writestring');
        const n = a[3] === undefined ? s.length : checkInt(a, 3, 'writestring');
        if (off < 0 || n < 0 || n > s.length || off + n > b.bytes.length) throw oob();
        for (let i = 0; i < n; i++) b.bytes[off + i] = s.charCodeAt(i) & 255;
        return [];
      },
      copy: (a) => {
        const dst = checkBuf(a, 0, 'copy');
        const dOff = checkInt(a, 1, 'copy');
        const src = checkBuf(a, 2, 'copy');
        const sOff = a[3] === undefined ? 0 : checkInt(a, 3, 'copy');
        const n = a[4] === undefined ? src.bytes.length - sOff : checkInt(a, 4, 'copy');
        if (dOff < 0 || sOff < 0 || n < 0 || sOff + n > src.bytes.length || dOff + n > dst.bytes.length) throw oob();
        dst.bytes.set(src.bytes.subarray(sOff, sOff + n), dOff);
        return [];
      },
      fill: (a) => {
        const b = checkBuf(a, 0, 'fill');
        const off = checkInt(a, 1, 'fill');
        const v = checkInt(a, 2, 'fill') & 255;
        const n = a[3] === undefined ? b.bytes.length - off : checkInt(a, 3, 'fill');
        if (off < 0 || n < 0 || off + n > b.bytes.length) throw oob();
        b.bytes.fill(v, off, off + n);
        return [];
      },
      readbits: (a) => {
        const b = checkBuf(a, 0, 'readbits');
        const bit = checkInt(a, 1, 'readbits');
        const n = checkInt(a, 2, 'readbits');
        if (n < 0 || n > 32 || bit < 0 || bit + n > b.bytes.length * 8) throw oob();
        let r = 0;
        for (let i = 0; i < n; i++) { const p = bit + i; r += ((b.bytes[p >> 3] >> (p & 7)) & 1) * 2 ** i; }
        return [r];
      },
      writebits: (a) => {
        const b = checkBuf(a, 0, 'writebits');
        const bit = checkInt(a, 1, 'writebits');
        const n = checkInt(a, 2, 'writebits');
        const v = checkInt(a, 3, 'writebits');
        if (n < 0 || n > 32 || bit < 0 || bit + n > b.bytes.length * 8) throw oob();
        for (let i = 0; i < n; i++) {
          const p = bit + i; const on = Math.floor(v / 2 ** i) % 2 === 1;
          if (on) b.bytes[p >> 3] |= 1 << (p & 7); else b.bytes[p >> 3] &= ~(1 << (p & 7));
        }
        return [];
      },
    });
  }

  // ---- vector (Luau) ----
  if (dialect === 'luau') {
    const vecMeta = new LuaTable();
    const mk = (x, y, z) => { const v = new LuaVector(x, y, z); v.meta = vecMeta; return v; };
    const isVec = (v) => v instanceof LuaVector;
    const checkVec = (a, i, fname) => { if (!isVec(a[i])) throw argError(i + 1, fname, `vector expected, got ${i >= a.length ? 'no value' : typeName(a[i])}`); return a[i]; };
    const lift = (name, op) => nf(name, (a) => {
      const l = a[0]; const r = a[1];
      if (isVec(l) && isVec(r)) return [mk(op(l.x, r.x), op(l.y, r.y), op(l.z, r.z))];
      if (isVec(l) && typeof r === 'number') return [mk(op(l.x, r), op(l.y, r), op(l.z, r))];
      if (typeof l === 'number' && isVec(r)) return [mk(op(l, r.x), op(l, r.y), op(l, r.z))];
      throw new LuaError(`attempt to perform arithmetic (${name}) on ${typeName(l)} and ${typeName(r)}`);
    });
    vecMeta.set('__add', lift('add', (x, y) => x + y));
    vecMeta.set('__sub', lift('sub', (x, y) => x - y));
    vecMeta.set('__mul', lift('mul', (x, y) => x * y));
    vecMeta.set('__div', lift('div', (x, y) => x / y));
    vecMeta.set('__idiv', lift('idiv', (x, y) => Math.floor(x / y)));
    vecMeta.set('__unm', nf('unm', (a) => [mk(-a[0].x, -a[0].y, -a[0].z)]));
    vecMeta.set('__eq', nf('eq', (a) => [isVec(a[0]) && isVec(a[1]) && a[0].x === a[1].x && a[0].y === a[1].y && a[0].z === a[1].z]));
    vecMeta.set('__index', nf('index', (a) => {
      const k = a[1];
      if (k === 'x' || k === 'X') return [a[0].x];
      if (k === 'y' || k === 'Y') return [a[0].y];
      if (k === 'z' || k === 'Z') return [a[0].z];
      if (k === 'Magnitude') return [Math.hypot(a[0].x, a[0].y, a[0].z)];
      throw new LuaError(`${typeof k === 'string' ? k : typeName(k)} is not a valid member of vector`);
    }));
    const mag = (v) => Math.hypot(v.x, v.y, v.z);
    const vlib = lib(m, 'vector', {
      create: (a) => [mk(checkNum(a, 0, 'create'), checkNum(a, 1, 'create'), a[2] === undefined ? 0 : checkNum(a, 2, 'create'))],
      magnitude: (a) => [mag(checkVec(a, 0, 'magnitude'))],
      normalize: (a) => { const v = checkVec(a, 0, 'normalize'); const n = mag(v); return [mk(v.x / n, v.y / n, v.z / n)]; },
      dot: (a) => { const l = checkVec(a, 0, 'dot'); const r = checkVec(a, 1, 'dot'); return [l.x * r.x + l.y * r.y + l.z * r.z]; },
      cross: (a) => { const l = checkVec(a, 0, 'cross'); const r = checkVec(a, 1, 'cross'); return [mk(l.y * r.z - l.z * r.y, l.z * r.x - l.x * r.z, l.x * r.y - l.y * r.x)]; },
      angle: (a) => { const l = checkVec(a, 0, 'angle'); const r = checkVec(a, 1, 'angle'); return [Math.acos(Math.max(-1, Math.min(1, (l.x * r.x + l.y * r.y + l.z * r.z) / (mag(l) * mag(r)))))]; },
      floor: (a) => { const v = checkVec(a, 0, 'floor'); return [mk(Math.floor(v.x), Math.floor(v.y), Math.floor(v.z))]; },
      ceil: (a) => { const v = checkVec(a, 0, 'ceil'); return [mk(Math.ceil(v.x), Math.ceil(v.y), Math.ceil(v.z))]; },
      abs: (a) => { const v = checkVec(a, 0, 'abs'); return [mk(Math.abs(v.x), Math.abs(v.y), Math.abs(v.z))]; },
      sign: (a) => { const v = checkVec(a, 0, 'sign'); return [mk(Math.sign(v.x), Math.sign(v.y), Math.sign(v.z))]; },
      max: (a) => { const v = checkVec(a, 0, 'max'); let x = v.x; let y = v.y; let z = v.z; for (let i = 1; i < a.length; i++) { const w = checkVec(a, i, 'max'); x = Math.max(x, w.x); y = Math.max(y, w.y); z = Math.max(z, w.z); } return [mk(x, y, z)]; },
      min: (a) => { const v = checkVec(a, 0, 'min'); let x = v.x; let y = v.y; let z = v.z; for (let i = 1; i < a.length; i++) { const w = checkVec(a, i, 'min'); x = Math.min(x, w.x); y = Math.min(y, w.y); z = Math.min(z, w.z); } return [mk(x, y, z)]; },
      clamp: (a) => { const v = checkVec(a, 0, 'clamp'); const lo = checkVec(a, 1, 'clamp'); const hi = checkVec(a, 2, 'clamp'); const c = (x, l, h) => Math.min(Math.max(x, l), h); return [mk(c(v.x, lo.x, hi.x), c(v.y, lo.y, hi.y), c(v.z, lo.z, hi.z))]; },
    });
    vlib.set('zero', mk(0, 0, 0));
    vlib.set('one', mk(1, 1, 1));
  }

  // ---- coroutine: run-to-completion only ----
  const threads = new WeakMap();
  const unsupportedYield = () => { throw new SandboxUnsupported('coroutine.yield (resumable coroutines)'); };
  const resume = (th, args) => {
    const st = threads.get(th);
    if (!st || st.status === 'dead') return [false, 'cannot resume dead coroutine'];
    st.status = 'running';
    try {
      const r = callValue(m, st.fn, args, '');
      st.status = 'dead';
      return [true, ...r];
    } catch (e) {
      st.status = 'dead';
      if (e instanceof LuaError) return [false, e.value];
      throw e;
    }
  };
  lib(m, 'coroutine', {
    create: (a) => { const th = new LuaUserdata(); threads.set(th, { fn: a[0], status: 'suspended' }); return [th]; },
    resume: (a) => resume(a[0], a.slice(1)),
    wrap: (a) => {
      const th = new LuaUserdata();
      threads.set(th, { fn: a[0], status: 'suspended' });
      return [nf('wrap', (args) => {
        const r = resume(th, args);
        if (!r[0]) throw new LuaError(r[1]);
        return r.slice(1);
      })];
    },
    yield: unsupportedYield,
    status: (a) => [(threads.get(a[0]) || {}).status || 'dead'],
    isyieldable: () => [false],
    running: () => [new LuaUserdata(), true],
    close: () => [true],
  });

  // ---- utf8 (subset) ----
  lib(m, 'utf8', {
    charpattern: '[\0-\x7F\xC2-\xF4][\x80-\xBF]*',
    char: (a) => {
      let out = '';
      for (let i = 0; i < a.length; i++) out += String.fromCharCode(...Array.from(new TextEncoder().encode(String.fromCodePoint(checkInt(a, i, 'char')))));
      return [out];
    },
    len: (a) => { const s = checkStr(a, 0, 'len'); let n = 0; for (let i = 0; i < s.length; i++) if ((s.charCodeAt(i) & 0xc0) !== 0x80) n++; return [n]; },
  });

  // ---- debug (inert) ----
  lib(m, 'debug', {
    traceback: (a) => [typeof a[0] === 'string' || a[0] === undefined ? `${a[0] === undefined ? '' : a[0] + '\n'}stack traceback:\n\t[C]: in ?` : a[0]],
    getinfo: (a) => {
      const t = new LuaTable();
      const f = a[0];
      t.set('currentline', m.line); t.set('short_src', m.chunkName); t.set('source', '=' + m.chunkName);
      t.set('what', f instanceof NativeFunction ? 'C' : 'Lua'); t.set('namewhat', ''); t.set('nups', 0);
      if (f instanceof LuaFunction) { t.set('func', f); t.set('linedefined', f.proto.line); }
      return [t];
    },
    sethook: () => [], gethook: () => [undefined],
    getlocal: () => [undefined], getupvalue: () => [undefined], setupvalue: () => [undefined],
    getmetatable: (a) => [a[0] instanceof LuaTable || a[0] instanceof LuaUserdata ? a[0].meta || undefined : undefined],
    setmetatable: (a) => { if (a[0] instanceof LuaTable || a[0] instanceof LuaUserdata) a[0].meta = a[1] || null; return [a[0]]; },
  });

  void vmConcat;
  return m;
}
