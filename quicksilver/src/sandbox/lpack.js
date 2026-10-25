// string.pack, string.unpack and string.packsize (Lua 5.3+, Luau), after lstrlib.c.
//
// Supported: the endianness switches < > =, the integer sizes b B h H i[n] I[n] l L j J T (n up to 8), f d n, s[n] z c<n> and x.
// Not supported, and refused with an error rather than guessed at: alignment (! and X) and integer sizes above 8.
// Integers beyond 2^53 come back as BigInts (see interp.js); everything else is an ordinary number.

import { LuaError } from './value.js';

const norm = (b) => (b >= -9007199254740991n && b <= 9007199254740991n ? Number(b) : b);

const FIXED = { b: [1, true], B: [1, false], h: [2, true], H: [2, false], l: [8, true], L: [8, false], j: [8, true], J: [8, false], T: [8, false] };

/** Splits a format string into options. */
function options(fname, fmt) {
  const out = [];
  let little = true;
  for (let i = 0; i < fmt.length;) {
    const c = fmt[i++];
    const number = (def) => {
      let s = '';
      while (i < fmt.length && fmt[i] >= '0' && fmt[i] <= '9') s += fmt[i++];
      return s ? Number(s) : def;
    };
    if (c === ' ') continue;
    if (c === '<' || c === '=') { little = true; continue; }
    if (c === '>') { little = false; continue; }
    if (c === '!' || c === 'X') throw new LuaError(`${fname}: alignment option '${c}' is not supported in the sandbox`);
    if (FIXED[c]) { out.push({ k: 'int', size: FIXED[c][0], signed: FIXED[c][1], little }); continue; }
    if (c === 'i' || c === 'I') {
      const size = number(4);
      if (size < 1 || size > 16) throw new LuaError(`${fname}: integral size (${size}) out of limits [1,16]`);
      if (size > 8) throw new LuaError(`${fname}: integer sizes above 8 are not supported in the sandbox`);
      out.push({ k: 'int', size, signed: c === 'i', little });
    } else if (c === 'f') out.push({ k: 'float', size: 4, little });
    else if (c === 'd' || c === 'n') out.push({ k: 'float', size: 8, little });
    else if (c === 's') {
      const size = number(8);
      if (size < 1 || size > 8) throw new LuaError(`${fname}: integral size (${size}) out of limits [1,8]`);
      out.push({ k: 'lstr', size, little });
    } else if (c === 'z') out.push({ k: 'zstr' });
    else if (c === 'x') out.push({ k: 'pad' });
    else if (c === 'c') {
      const size = number(-1);
      if (size < 0) throw new LuaError(`${fname}: missing size for format option 'c'`);
      out.push({ k: 'chars', size });
    } else throw new LuaError(`${fname}: invalid format option '${c}'`);
  }
  return out;
}

function readInt(s, pos, o) {
  let v = 0n;
  for (let i = 0; i < o.size; i++) {
    const byte = BigInt(s.charCodeAt(o.little ? pos + o.size - 1 - i : pos + i));
    v = (v << 8n) | byte;
  }
  if (o.signed) v = BigInt.asIntN(o.size * 8, v);
  return norm(o.size === 8 && !o.signed ? BigInt.asIntN(64, v) : v);
}

function floatBytes(size, little, value) {
  const dv = new DataView(new ArrayBuffer(size));
  if (size === 4) dv.setFloat32(0, value, little); else dv.setFloat64(0, value, little);
  let out = '';
  for (let i = 0; i < size; i++) out += String.fromCharCode(dv.getUint8(i));
  return out;
}

export function strUnpack(fmt, s, init) {
  const list = options('string.unpack', fmt);
  let pos = init === undefined ? 0 : init > 0 ? init - 1 : init < 0 ? Math.max(s.length + init, 0) : 0;
  if (pos > s.length) throw new LuaError("bad argument #3 to 'unpack' (initial position out of string)");
  const out = [];
  const need = (n) => { if (pos + n > s.length) throw new LuaError("bad argument #2 to 'unpack' (data string too short)"); };
  for (const o of list) {
    switch (o.k) {
      case 'int': need(o.size); out.push(readInt(s, pos, o)); pos += o.size; break;
      case 'float': {
        need(o.size);
        const dv = new DataView(new ArrayBuffer(o.size));
        for (let i = 0; i < o.size; i++) dv.setUint8(i, s.charCodeAt(pos + i));
        out.push(o.size === 4 ? dv.getFloat32(0, o.little) : dv.getFloat64(0, o.little));
        pos += o.size;
        break;
      }
      case 'lstr': {
        need(o.size);
        const len = Number(readInt(s, pos, { size: o.size, signed: false, little: o.little }));
        pos += o.size;
        need(len);
        out.push(s.slice(pos, pos + len));
        pos += len;
        break;
      }
      case 'chars': need(o.size); out.push(s.slice(pos, pos + o.size)); pos += o.size; break;
      case 'zstr': {
        const end = s.indexOf('\0', pos);
        if (end < 0) throw new LuaError("bad argument #2 to 'unpack' (unfinished string for format 'z')");
        out.push(s.slice(pos, end));
        pos = end + 1;
        break;
      }
      default: need(1); pos += 1; // x
    }
  }
  out.push(pos + 1);
  return out;
}

export function strPack(fmt, values) {
  const list = options('string.pack', fmt);
  let out = '';
  let arg = 0;
  const next = () => { if (arg >= values.length) throw new LuaError(`bad argument #${arg + 2} to 'pack' (no value)`); return values[arg++]; };
  const int = (o, v) => {
    const x = typeof v === 'bigint' ? v : typeof v === 'number' && Number.isInteger(v) ? BigInt(v) : null;
    if (x === null) throw new LuaError(`bad argument #${arg + 1} to 'pack' (number has no integer representation)`);
    const bits = BigInt(o.size * 8);
    if (o.size < 8) {
      const ok = o.signed ? x >= -(1n << (bits - 1n)) && x < (1n << (bits - 1n)) : x >= 0n && x < (1n << bits);
      if (!ok) throw new LuaError(`bad argument #${arg + 1} to 'pack' (${o.signed ? 'integer' : 'unsigned'} overflow)`);
    }
    const u = BigInt.asUintN(o.size * 8, x);
    let bytes = '';
    for (let i = 0; i < o.size; i++) bytes += String.fromCharCode(Number((u >> BigInt(8 * i)) & 0xffn));
    return o.little ? bytes : [...bytes].reverse().join('');
  };
  for (const o of list) {
    switch (o.k) {
      case 'int': out += int(o, next()); break;
      case 'float': { const v = next(); if (typeof v !== 'number') throw new LuaError(`bad argument #${arg + 1} to 'pack' (number expected)`); out += floatBytes(o.size, o.little, v); break; }
      case 'lstr': { const v = String(next()); out += int({ size: o.size, signed: false, little: o.little }, BigInt(v.length)) + v; break; }
      case 'chars': { const v = String(next()); if (v.length > o.size) throw new LuaError(`bad argument #${arg + 1} to 'pack' (string longer than given size)`); out += v + '\0'.repeat(o.size - v.length); break; }
      case 'zstr': { const v = String(next()); if (v.includes('\0')) throw new LuaError(`bad argument #${arg + 1} to 'pack' (string contains zeros)`); out += v + '\0'; break; }
      default: out += '\0';
    }
  }
  return out;
}

export function strPackSize(fmt) {
  let n = 0;
  for (const o of options('string.packsize', fmt)) {
    if (o.k === 'lstr' || o.k === 'zstr') throw new LuaError("bad argument #1 to 'packsize' (variable-size format in packsize)");
    n += o.k === 'chars' ? o.size : o.k === 'pad' ? 1 : o.size;
  }
  return n;
}
