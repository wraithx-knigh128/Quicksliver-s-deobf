// Lua pattern matching and string.format, written after the reference implementation (lstrlib.c).
// Strings are binary strings; every function works on char codes 0..255.

import { LuaError } from './value.js';
import { numberToLuaString } from '../passes/consteval.js';

const L_ESC = 37;           // '%'
const CAP_UNFINISHED = -1;
const CAP_POSITION = -2;
const MAXCCALLS = 200;
const MAXCAPTURES = 32;

class MatchState {
  constructor(src, pat) {
    this.src = src;
    this.pat = pat;
    this.level = 0;
    this.capture = [];
    this.depth = 0;
  }
}

const isAlpha = (c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
const isDigit = (c) => c >= 48 && c <= 57;
const isLower = (c) => c >= 97 && c <= 122;
const isUpper = (c) => c >= 65 && c <= 90;
const isSpace = (c) => c === 32 || (c >= 9 && c <= 13);
const isCntrl = (c) => c < 32 || c === 127;
const isPunct = (c) => (c >= 33 && c <= 47) || (c >= 58 && c <= 64) || (c >= 91 && c <= 96) || (c >= 123 && c <= 126);
const isXdigit = (c) => isDigit(c) || (c >= 97 && c <= 102) || (c >= 65 && c <= 70);

function classEnd(ms, p) {
  const pat = ms.pat;
  if (p >= pat.length) throw new LuaError('malformed pattern (ends with \'%\')');
  const c = pat.charCodeAt(p++);
  if (c === L_ESC) {
    if (p >= pat.length) throw new LuaError("malformed pattern (ends with '%')");
    return p + 1;
  }
  if (c === 91) { // '['
    if (pat.charCodeAt(p) === 94) p++;
    do {
      if (p >= pat.length) throw new LuaError("malformed pattern (missing ']')");
      const cc = pat.charCodeAt(p++);
      if (cc === L_ESC) p++;
    } while (pat.charCodeAt(p) !== 93 || p >= pat.length);
    return p + 1;
  }
  return p;
}

function matchClass(c, cl) {
  let res;
  switch (cl | 32) { // lower-case the class letter
    case 97: res = isAlpha(c); break;            // a
    case 99: res = isCntrl(c); break;            // c
    case 100: res = isDigit(c); break;           // d
    case 108: res = isLower(c); break;           // l
    case 112: res = isPunct(c); break;           // p
    case 115: res = isSpace(c); break;           // s
    case 117: res = isUpper(c); break;           // u
    case 119: res = isAlpha(c) || isDigit(c); break; // w
    case 120: res = isXdigit(c); break;          // x
    case 103: res = c > 32 && c < 127; break;    // g
    default: return cl === c;
  }
  if (cl >= 65 && cl <= 90) res = !res;          // upper-case letter negates
  return res;
}

function matchBracketClass(ms, c, p, ec) {
  const pat = ms.pat;
  let sig = true;
  if (pat.charCodeAt(p + 1) === 94) { sig = false; p++; }
  while (++p < ec) {
    const pc = pat.charCodeAt(p);
    if (pc === L_ESC) {
      p++;
      if (matchClass(c, pat.charCodeAt(p))) return sig;
    } else if (pat.charCodeAt(p + 1) === 45 && p + 2 < ec) { // range a-z
      p += 2;
      if (pc <= c && c <= pat.charCodeAt(p)) return sig;
    } else if (pc === c) return sig;
  }
  return !sig;
}

function singleMatch(ms, s, p, ep) {
  if (s >= ms.src.length) return false;
  const c = ms.src.charCodeAt(s);
  const pc = ms.pat.charCodeAt(p);
  switch (pc) {
    case 46: return true;                                  // '.'
    case L_ESC: return matchClass(c, ms.pat.charCodeAt(p + 1));
    case 91: return matchBracketClass(ms, c, p, ep - 1);
    default: return pc === c;
  }
}

function matchBalance(ms, s, p) {
  if (p + 1 >= ms.pat.length) throw new LuaError("unbalanced pattern (missing arguments to '%b')");
  if (s >= ms.src.length || ms.src.charCodeAt(s) !== ms.pat.charCodeAt(p)) return -1;
  const b = ms.pat.charCodeAt(p);
  const e = ms.pat.charCodeAt(p + 1);
  let cont = 1;
  let i = s + 1;
  while (i < ms.src.length) {
    const c = ms.src.charCodeAt(i);
    if (c === e) { if (--cont === 0) return i + 1; }
    else if (c === b) cont++;
    i++;
  }
  return -1;
}

function maxExpand(ms, s, p, ep) {
  let i = 0;
  while (singleMatch(ms, s + i, p, ep)) i++;
  while (i >= 0) {
    const res = doMatch(ms, s + i, ep + 1);
    if (res !== -1) return res;
    i--;
  }
  return -1;
}

function minExpand(ms, s, p, ep) {
  for (;;) {
    const res = doMatch(ms, s, ep + 1);
    if (res !== -1) return res;
    if (singleMatch(ms, s, p, ep)) s++;
    else return -1;
  }
}

function startCapture(ms, s, p, what) {
  if (ms.level >= MAXCAPTURES) throw new LuaError('too many captures');
  ms.capture[ms.level] = { init: s, len: what };
  ms.level++;
  const res = doMatch(ms, s, p);
  if (res === -1) ms.level--;
  return res;
}

function endCapture(ms, s, p) {
  let l = -1;
  for (let i = ms.level - 1; i >= 0; i--) if (ms.capture[i].len === CAP_UNFINISHED) { l = i; break; }
  if (l < 0) throw new LuaError('invalid pattern capture');
  ms.capture[l].len = s - ms.capture[l].init;
  const res = doMatch(ms, s, p);
  if (res === -1) ms.capture[l].len = CAP_UNFINISHED;
  return res;
}

function matchCapture(ms, s, l) {
  l -= 49; // '1'
  if (l < 0 || l >= ms.level || ms.capture[l].len === CAP_UNFINISHED) throw new LuaError('invalid capture index');
  const cap = ms.src.substr(ms.capture[l].init, ms.capture[l].len);
  if (ms.src.length - s >= cap.length && ms.src.substr(s, cap.length) === cap) return s + cap.length;
  return -1;
}

function doMatch(ms, s, p) {
  if (++ms.depth > MAXCCALLS * 20) throw new LuaError('pattern too complex');
  try {
    for (;;) {
      if (p >= ms.pat.length) return s;
      const pc = ms.pat.charCodeAt(p);
      switch (pc) {
        case 40: // '('
          if (ms.pat.charCodeAt(p + 1) === 41) return startCapture(ms, s, p + 2, CAP_POSITION);
          return startCapture(ms, s, p + 1, CAP_UNFINISHED);
        case 41: return endCapture(ms, s, p + 1); // ')'
        case 36: // '$'
          if (p + 1 === ms.pat.length) return s === ms.src.length ? s : -1;
          break;
        case L_ESC: {
          const n = ms.pat.charCodeAt(p + 1);
          if (n === 98) { // %b
            s = matchBalance(ms, s, p + 2);
            if (s === -1) return -1;
            p += 4;
            continue;
          }
          if (n === 102) { // %f
            p += 2;
            if (ms.pat.charCodeAt(p) !== 91) throw new LuaError("missing '[' after '%f' in pattern");
            const ep = classEnd(ms, p);
            const prev = s === 0 ? 0 : ms.src.charCodeAt(s - 1);
            const cur = s < ms.src.length ? ms.src.charCodeAt(s) : 0;
            if (!matchBracketClass(ms, prev, p, ep - 1) && matchBracketClass(ms, cur, p, ep - 1)) { p = ep; continue; }
            return -1;
          }
          if (isDigit(n)) {
            s = matchCapture(ms, s, n);
            if (s === -1) return -1;
            p += 2;
            continue;
          }
          break;
        }
        default: break;
      }
      const ep = classEnd(ms, p);
      const epc = ms.pat.charCodeAt(ep);
      if (!singleMatch(ms, s, p, ep)) {
        if (epc === 42 || epc === 63 || epc === 45) { p = ep + 1; continue; } // * ? - accept empty
        return -1;
      }
      switch (epc) {
        case 63: { // '?'
          const res = doMatch(ms, s + 1, ep + 1);
          if (res !== -1) return res;
          p = ep + 1;
          continue;
        }
        case 43: return maxExpand(ms, s + 1, p, ep);   // '+'
        case 42: return maxExpand(ms, s, p, ep);       // '*'
        case 45: return minExpand(ms, s, p, ep);       // '-'
        default: s++; p = ep; continue;
      }
    }
  } finally {
    ms.depth--;
  }
}

function getCapture(ms, i, s, e) {
  if (i >= ms.level) {
    if (i === 0) return ms.src.slice(s, e);
    throw new LuaError('invalid capture index');
  }
  const cap = ms.capture[i];
  if (cap.len === CAP_UNFINISHED) throw new LuaError('unfinished capture');
  if (cap.len === CAP_POSITION) return cap.init + 1;
  return ms.src.substr(cap.init, cap.len);
}

function captures(ms, s, e, wholeIfNone) {
  const n = ms.level === 0 && wholeIfNone ? 1 : ms.level;
  const out = [];
  for (let i = 0; i < n; i++) out.push(getCapture(ms, i, s, e));
  return out;
}

const hasSpecials = (p) => /[\^$*+?.()[\]%-]/.test(p);

function posRelat(pos, len) {
  if (pos > 0) return pos;
  if (pos === 0) return 1;
  if (pos < -len) return 1;
  return len + pos + 1;
}

/** string.find / string.match core. Returns array of results (empty array for no match -> [undefined]). */
export function strFind(s, pat, init, plain, isFind) {
  let start = posRelat(init === undefined ? 1 : init, s.length) - 1;
  if (start > s.length) return [undefined];
  if (isFind && (plain || !hasSpecials(pat))) {
    const at = s.indexOf(pat, start);
    return at < 0 ? [undefined] : [at + 1, at + pat.length];
  }
  const anchor = pat.charCodeAt(0) === 94;
  const p0 = anchor ? 1 : 0;
  const ms = new MatchState(s, pat);
  let s1 = start;
  do {
    ms.level = 0;
    ms.depth = 0;
    const e = doMatch(ms, s1, p0);
    if (e !== -1) {
      if (isFind) return [s1 + 1, e, ...captures(ms, s1, e, false)];
      return captures(ms, s1, e, true);
    }
    s1++;
  } while (s1 <= s.length && !anchor);
  return [undefined];
}

/** Iterator state for string.gmatch. */
export function gmatchIter(s, pat) {
  let pos = 0;
  let lastMatch = -1;
  const ms = new MatchState(s, pat);
  return () => {
    for (let src = pos; src <= s.length; src++) {
      ms.level = 0;
      ms.depth = 0;
      const e = doMatch(ms, src, 0);
      if (e !== -1 && e !== lastMatch) {
        pos = lastMatch = e;
        return captures(ms, src, e, true);
      }
    }
    pos = s.length + 1;
    return [undefined];
  };
}

/**
 * string.gsub. `repl` is a string, a LuaTable-like lookup (function (key) -> value) or a call function;
 * `kind` tells which: 'string' | 'table' | 'function'.
 */
export function strGsub(s, pat, kind, repl, maxN, tostr) {
  const anchor = pat.charCodeAt(0) === 94;
  const p0 = anchor ? 1 : 0;
  const ms = new MatchState(s, pat);
  let out = '';
  let src = 0;
  let n = 0;
  const limit = maxN === undefined ? s.length + 1 : maxN;
  while (n < limit) {
    ms.level = 0;
    ms.depth = 0;
    const e = doMatch(ms, src, p0);
    if (e !== -1) {
      n++;
      const whole = s.slice(src, e);
      let value;
      if (kind === 'string') {
        let r = '';
        for (let i = 0; i < repl.length; i++) {
          const c = repl.charCodeAt(i);
          if (c !== L_ESC) { r += repl[i]; continue; }
          i++;
          const d = repl.charCodeAt(i);
          if (d === L_ESC) r += '%';
          else if (isDigit(d)) {
            const cap = d === 48 ? whole : getCapture(ms, d - 49, src, e);
            r += typeof cap === 'number' ? numberToLuaString(cap) : cap;
          } else throw new LuaError("invalid use of '%' in replacement string");
        }
        value = r;
      } else {
        const first = captures(ms, src, e, true)[0];
        value = repl(kind, first, captures(ms, src, e, true));
        if (value === undefined || value === false) value = whole;
        else if (typeof value === 'number') value = numberToLuaString(value);
        else if (typeof value !== 'string') throw new LuaError(`invalid replacement value (a ${tostr(value)})`);
      }
      out += value;
    }
    if (e !== -1 && e > src) src = e;
    else if (src < s.length) out += s[src++];
    else break;
    if (anchor) break;
  }
  if (src < s.length) out += s.slice(src);
  return [out, n];
}

// ---- string.format -------------------------------------------------------------------

function formatG(n, prec, upper, alt) {
  if (!Number.isFinite(n)) return Number.isNaN(n) ? (upper ? 'NAN' : 'nan') : (n < 0 ? '-' : '') + (upper ? 'INF' : 'inf');
  if (prec === 0) prec = 1;
  if (n === 0) return Object.is(n, -0) ? '-0' : '0';
  const exp = Number(n.toExponential(prec - 1).split('e')[1]);
  let s;
  if (exp < -4 || exp >= prec) {
    const [m, e] = n.toExponential(prec - 1).split('e');
    const mant = alt || !m.includes('.') ? m : m.replace(/\.?0+$/, '');
    s = `${mant}e${e[0]}${e.slice(1).padStart(2, '0')}`;
  } else {
    s = n.toFixed(Math.max(0, prec - 1 - exp));
    if (!alt && s.includes('.')) s = s.replace(/\.?0+$/, '');
  }
  return upper ? s.toUpperCase() : s;
}

function expFormat(n, prec, upper) {
  if (!Number.isFinite(n)) return Number.isNaN(n) ? 'nan' : (n < 0 ? '-inf' : 'inf');
  const [m, e] = n.toExponential(prec).split('e');
  const s = `${m}e${e[0]}${e.slice(1).padStart(2, '0')}`;
  return upper ? s.toUpperCase() : s;
}

function quoteLiteral(s) {
  let out = '"';
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c === 34) out += '\\"';
    else if (c === 92) out += '\\\\';
    else if (c === 10) out += '\\\n';
    else if (c === 13) out += '\\r';
    else if (c === 0) out += isDigit(s.charCodeAt(i + 1)) ? '\\000' : '\\0';
    else out += s[i];
  }
  return out + '"';
}

/** string.format. `tostr` converts any value like tostring() (honouring __tostring). */
export function strFormat(fmt, args, tostr, toNum) {
  let ai = 0;
  const bad = (n, msg) => { throw new LuaError(`bad argument #${n + 1} to 'format' (${msg})`); };
  return fmt.replace(/%([-+ #0]*)(\d*)(?:\.(\d*))?([A-Za-z%])/g, (m, flags, width, prec, conv) => {
    if (conv === '%') return '%';
    const idx = ai++;
    const arg = args[idx];
    const needNum = () => {
      const v = toNum(arg);
      if (v === undefined) bad(idx + 1, `number expected, got ${arg === undefined ? 'no value' : typeof arg}`);
      return v;
    };
    let s;
    const p = prec === undefined ? undefined : Number(prec || 0);
    switch (conv) {
      case 'd': case 'i': {
        const v = needNum();
        s = String(Math.trunc(v));
        if (p !== undefined) { const neg = s[0] === '-'; const digits = neg ? s.slice(1) : s; s = (neg ? '-' : '') + digits.padStart(p, '0'); }
        if (v >= 0) { if (flags.includes('+')) s = '+' + s; else if (flags.includes(' ')) s = ' ' + s; }
        break;
      }
      case 'u': s = String(Math.trunc(needNum()) >>> 0); break;
      case 'c': s = String.fromCharCode(Math.trunc(needNum()) & 255); break;
      case 'x': case 'X': case 'o': {
        let v = Math.trunc(needNum());
        if (v < 0) v += 2 ** 32;
        s = v.toString(conv === 'o' ? 8 : 16);
        if (conv === 'X') s = s.toUpperCase();
        if (p !== undefined) s = s.padStart(p, '0');
        if (flags.includes('#') && v !== 0) s = (conv === 'o' ? '0' : conv === 'x' ? '0x' : '0X') + s;
        break;
      }
      case 'e': case 'E': s = expFormat(needNum(), p === undefined ? 6 : p, conv === 'E'); break;
      case 'f': case 'F': {
        const v = needNum();
        s = Number.isFinite(v) ? v.toFixed(p === undefined ? 6 : p) : (Number.isNaN(v) ? 'nan' : v < 0 ? '-inf' : 'inf');
        break;
      }
      case 'g': case 'G': s = formatG(needNum(), p === undefined ? 6 : p, conv === 'G', flags.includes('#')); break;
      case 'a': case 'A': s = needNum().toString(16); break;
      case 'q': s = quoteLiteral(typeof arg === 'string' ? arg : tostr(arg)); break;
      case 's': {
        s = tostr(arg);
        if (idx >= args.length && arg === undefined) bad(idx + 1, 'no value');
        if (p !== undefined) s = s.slice(0, p);
        break;
      }
      default: throw new LuaError(`invalid option '%${conv}' to 'format'`);
    }
    if ((conv === 'd' || conv === 'i' || conv === 'f' || conv === 'e' || conv === 'g' || conv === 'E' || conv === 'G' || conv === 'F') && flags.includes('+') && !/^[+-]/.test(s)) s = '+' + s;
    if (width) {
      const w = Number(width);
      if (flags.includes('-')) s = s.padEnd(w);
      else if (flags.includes('0') && 'diuxXofeEgGF'.includes(conv) && !(p !== undefined && 'diuxXo'.includes(conv))) {
        const sign = /^[+-]/.test(s) ? s[0] : '';
        s = sign + s.slice(sign.length).padStart(w - sign.length, '0');
      } else s = s.padStart(w);
    }
    return s;
  });
}
