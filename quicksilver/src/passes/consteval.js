// Constant evaluation with Lua semantics.
//
// A "constant" here is a JS value standing for a Lua one: undefined = nil, boolean, number (a double,
// as in Lua 5.1 / Luau) or string (a binary string, see core/bytes.js). Evaluation is deliberately
// conservative: anything that could raise an error at run time, depend on the environment, or yield
// several values is reported as "not constant" and left alone.

export const NOT_CONST = Symbol('not-const');

// ---- value helpers ----------------------------------------------------------

/** Lua's tostring() for numbers: printf("%.14g"). */
export function numberToLuaString(n) {
  if (Number.isNaN(n)) return 'nan';
  if (n === Infinity) return 'inf';
  if (n === -Infinity) return '-inf';
  if (Number.isInteger(n) && Math.abs(n) < 1e15) return Object.is(n, -0) ? '-0' : String(n);
  const exp = Number(n.toExponential(13).split('e')[1]);
  if (exp < -4 || exp >= 14) {
    const [mant, e] = n.toExponential(13).split('e');
    const m = mant.includes('.') ? mant.replace(/\.?0+$/, '') : mant;
    return `${m}e${e[0]}${e.slice(1).padStart(2, '0')}`;
  }
  let s = n.toFixed(Math.max(0, 13 - exp));
  if (s.includes('.')) s = s.replace(/\.?0+$/, '');
  return s;
}

const NUMERIC = /^\s*[+-]?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)\s*$/;

/** Lua's tonumber(s) for decimal and hex strings; undefined when s is not numeric. */
export function stringToNumber(s) {
  if (!NUMERIC.test(s)) return undefined;
  const t = s.trim();
  const m = /^([+-]?)0[xX]([0-9a-fA-F]+)$/.exec(t);
  if (m) return (m[1] === '-' ? -1 : 1) * parseInt(m[2], 16);
  return Number(t);
}

const isFalsy = (v) => v === undefined || v === false;

function toArith(v) {
  if (typeof v === 'number') return v;
  if (typeof v === 'string') return stringToNumber(v);
  return undefined;
}

function toConcat(v) {
  if (typeof v === 'string') return v;
  if (typeof v === 'number') return numberToLuaString(v);
  return undefined;
}

function luaMod(a, b) {
  return a - Math.floor(a / b) * b;
}

/** Evaluate `a op b` on constants, or NOT_CONST. */
export function evalBinary(op, a, b) {
  switch (op) {
    case 'and': return isFalsy(a) ? a : b;
    case 'or': return isFalsy(a) ? b : a;
    case '==': return a === b;
    case '~=': return a !== b;
    case '..': {
      const x = toConcat(a);
      const y = toConcat(b);
      return x === undefined || y === undefined ? NOT_CONST : x + y;
    }
    case '<': case '<=': case '>': case '>=': {
      if (typeof a !== typeof b || (typeof a !== 'number' && typeof a !== 'string')) return NOT_CONST;
      if (op === '<') return a < b;
      if (op === '<=') return a <= b;
      if (op === '>') return a > b;
      return a >= b;
    }
    case '+': case '-': case '*': case '/': case '%': case '^': case '//': {
      const x = toArith(a);
      const y = toArith(b);
      if (x === undefined || y === undefined) return NOT_CONST;
      let r;
      if (op === '+') r = x + y;
      else if (op === '-') r = x - y;
      else if (op === '*') r = x * y;
      else if (op === '/') r = x / y;
      else if (op === '%') r = luaMod(x, y);
      else if (op === '^') r = Math.pow(x, y);
      else r = Math.floor(x / y);
      return Number.isFinite(r) ? r : NOT_CONST; // inf / nan: leave the expression visible
    }
    default: return NOT_CONST;
  }
}

export function evalUnary(op, v) {
  switch (op) {
    case 'not': return isFalsy(v);
    case '-': {
      const n = toArith(v);
      return n === undefined ? NOT_CONST : -n;
    }
    case '#': return typeof v === 'string' ? v.length : NOT_CONST;
    default: return NOT_CONST;
  }
}

// ---- standard library calls --------------------------------------------------

const toInt = (v) => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : NOT_CONST);

function luaSub(s, i, j) {
  const len = s.length;
  if (i < 0) i = Math.max(len + i + 1, 1); else if (i === 0) i = 1;
  if (j < 0) j = len + j + 1; else if (j > len) j = len;
  return i > j ? '' : s.slice(i - 1, j);
}

function formatPercent(fmt, args) {
  let ai = 0;
  let bad = false;
  const out = fmt.replace(/%([-+ #0]*)(\d*)(?:\.(\d+))?([diouxXeEfgGcsq%])/g, (m, flags, width, prec, conv) => {
    if (conv === '%') return '%';
    const arg = args[ai++];
    let s;
    switch (conv) {
      case 's': {
        // Lua 5.1 only accepts strings and numbers for %s (booleans / nil raise an error)
        if (typeof arg !== 'string' && typeof arg !== 'number') { bad = true; return m; }
        const t = typeof arg === 'string' ? arg : numberToLuaString(arg);
        s = prec !== undefined ? t.slice(0, Number(prec)) : t;
        break;
      }
      case 'd': case 'i': case 'u': {
        const n = toArith(arg);
        if (n === undefined) { bad = true; return m; }
        s = String(Math.trunc(n));
        if (flags.includes('+') && n >= 0) s = '+' + s;
        break;
      }
      case 'x': case 'X': {
        const n = toArith(arg);
        if (n === undefined || n < 0) { bad = true; return m; }
        s = Math.trunc(n).toString(16);
        if (conv === 'X') s = s.toUpperCase();
        break;
      }
      case 'c': {
        const n = toArith(arg);
        if (n === undefined) { bad = true; return m; }
        s = String.fromCharCode(Math.trunc(n) & 255);
        break;
      }
      case 'f': {
        const n = toArith(arg);
        if (n === undefined || !Number.isFinite(n)) { bad = true; return m; }
        s = n.toFixed(prec === undefined ? 6 : Number(prec));
        if (flags.includes('+') && n >= 0) s = '+' + s;
        break;
      }
      default: bad = true; return m;
    }
    if (width) {
      const w = Number(width);
      if (flags.includes('-')) s = s.padEnd(w);
      else if (flags.includes('0') && conv !== 's' && conv !== 'c') {
        const neg = /^[+-]/.test(s) ? s[0] : '';
        s = neg + s.slice(neg.length).padStart(w - neg.length, '0');
      } else s = s.padStart(w);
    }
    return s;
  });
  return bad ? NOT_CONST : out;
}

const U32 = 0x100000000;
const u32 = (n) => ((n % U32) + U32) % U32;
const s32 = (n) => (u32(n) | 0);

function bitArgs(args) {
  if (!args.length || !args.every((a) => typeof a === 'number' && Number.isFinite(a))) return null;
  return args.map((a) => u32(Math.floor(a)));
}

/** bit32.* (Luau / Lua 5.2) results are unsigned; LuaJIT's bit.* results are signed. */
function bitCall(lib, fn, args) {
  const a = bitArgs(args);
  if (!a) return NOT_CONST;
  const out = lib === 'bit' ? s32 : u32;
  switch (fn) {
    case 'bxor': return out(a.reduce((x, y) => (x ^ y) >>> 0));
    case 'band': return out(a.reduce((x, y) => (x & y) >>> 0));
    case 'bor': return out(a.reduce((x, y) => (x | y) >>> 0));
    case 'bnot': return a.length === 1 ? out(~a[0] >>> 0) : NOT_CONST;
    case 'lshift': return a.length === 2 ? out(a[1] >= 32 ? 0 : (a[0] << a[1]) >>> 0) : NOT_CONST;
    case 'rshift': return a.length === 2 ? out(a[1] >= 32 ? 0 : a[0] >>> a[1]) : NOT_CONST;
    case 'lrotate': case 'rol': { if (a.length !== 2) return NOT_CONST; const k = a[1] % 32; return out(((a[0] << k) | (a[0] >>> (32 - k))) >>> 0); }
    case 'rrotate': case 'ror': { if (a.length !== 2) return NOT_CONST; const k = a[1] % 32; return out(((a[0] >>> k) | (a[0] << (32 - k))) >>> 0); }
    case 'arshift': case 'sar': {
      if (a.length !== 2) return NOT_CONST;
      const k = a[1] >= 32 ? 31 : a[1];
      return out(((a[0] | 0) >> k) >>> 0);
    }
    default: return NOT_CONST;
  }
}

/** Call `lib.fn(...args)` for a pure standard function; NOT_CONST when unknown or unsafe. */
export function evalLibCall(lib, fn, args) {
  const allStr = (n) => args.length >= n && typeof args[0] === 'string';
  switch (`${lib}.${fn}`) {
    case 'string.char': {
      let out = '';
      for (const a of args) {
        const n = toArith(a);
        if (n === undefined || !Number.isInteger(n) || n < 0 || n > 255) return NOT_CONST;
        out += String.fromCharCode(n);
      }
      return out;
    }
    case 'string.byte': {
      if (!allStr(1)) return NOT_CONST;
      const i = args.length > 1 ? toInt(args[1]) : 1;
      const j = args.length > 2 ? toInt(args[2]) : i;
      if (i === NOT_CONST || j === NOT_CONST || i !== j) return NOT_CONST; // only the single-result form
      const s = luaSub(args[0], i, j);
      return s.length === 1 ? s.charCodeAt(0) : NOT_CONST;
    }
    case 'string.sub': {
      if (!allStr(2)) return NOT_CONST;
      const i = toInt(args[1]);
      const j = args.length > 2 ? toInt(args[2]) : -1;
      return i === NOT_CONST || j === NOT_CONST ? NOT_CONST : luaSub(args[0], i, j);
    }
    case 'string.rep': {
      if (!allStr(2)) return NOT_CONST;
      const n = toInt(args[1]);
      if (n === NOT_CONST || n < 0 || n * args[0].length > 1_000_000 || args.length > 2) return NOT_CONST;
      return args[0].repeat(n);
    }
    case 'string.reverse': return allStr(1) && args.length === 1 ? [...args[0]].reverse().join('') : NOT_CONST;
    case 'string.lower': return allStr(1) && args.length === 1 ? args[0].replace(/[A-Z]/g, (c) => c.toLowerCase()) : NOT_CONST;
    case 'string.upper': return allStr(1) && args.length === 1 ? args[0].replace(/[a-z]/g, (c) => c.toUpperCase()) : NOT_CONST;
    case 'string.len': return allStr(1) && args.length === 1 ? args[0].length : NOT_CONST;
    case 'string.format': return allStr(1) ? formatPercent(args[0], args.slice(1)) : NOT_CONST;
    case 'math.floor': case 'math.ceil': case 'math.abs': case 'math.sqrt': {
      const n = args.length === 1 ? toArith(args[0]) : undefined;
      if (n === undefined) return NOT_CONST;
      const r = fn === 'floor' ? Math.floor(n) : fn === 'ceil' ? Math.ceil(n) : fn === 'abs' ? Math.abs(n) : Math.sqrt(n);
      return Number.isFinite(r) ? r : NOT_CONST;
    }
    case 'math.max': case 'math.min': {
      const nums = args.map(toArith);
      if (!nums.length || nums.some((x) => x === undefined)) return NOT_CONST;
      return fn === 'max' ? Math.max(...nums) : Math.min(...nums);
    }
    case 'table.concat': return NOT_CONST;
    default:
      if (lib === 'bit32' || lib === 'bit') return bitCall(lib, fn, args);
      return NOT_CONST;
  }
}

export function evalGlobalCall(name, args) {
  switch (name) {
    case 'tostring':
      if (args.length !== 1) return NOT_CONST;
      if (typeof args[0] === 'string') return args[0];
      if (typeof args[0] === 'number') return numberToLuaString(args[0]);
      if (typeof args[0] === 'boolean') return String(args[0]);
      return args[0] === undefined ? 'nil' : NOT_CONST;
    case 'tonumber': {
      if (args.length !== 1) return NOT_CONST;
      if (typeof args[0] === 'number') return args[0];
      if (typeof args[0] === 'string') return stringToNumber(args[0]);
      return NOT_CONST;
    }
    case 'type':
      if (args.length !== 1) return NOT_CONST;
      return args[0] === undefined ? 'nil' : typeof args[0] === 'boolean' ? 'boolean' : typeof args[0];
    default: return NOT_CONST;
  }
}

/** Methods callable on a string constant: ("x"):rep(3), s:sub(1, 2), ... */
export function evalStringMethod(name, recv, args) {
  switch (name) {
    case 'rep': case 'sub': case 'reverse': case 'lower': case 'upper': case 'len': case 'format': case 'byte':
      return evalLibCall('string', name, [recv, ...args]);
    default: return NOT_CONST;
  }
}
