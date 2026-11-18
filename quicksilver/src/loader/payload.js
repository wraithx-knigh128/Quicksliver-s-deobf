// What a retrieved response actually is, layer by layer.
//
// A successful HTTP request is not a retrieved program: the body may be an error page, JSON with the code in one field, base64 or hex text,
// a gzip / zlib stream, a compiled chunk, or a Roblox model. This peels those transport layers off one at a time (each one recorded), and says
// what is left: Lua text, a compiled chunk, a model with scripts, or something that is not code. It never executes anything; decoding is
// done by this project's own DEFLATE and model readers.

import { inflateRaw, adler32 } from '../core/inflate.js';
import { modelKind, extractScripts } from './rbx.js';
import { parse } from '../core/parser.js';

const MAX_LAYERS = 8;
const MAX_OUT = 32 * 1024 * 1024;
const CODE_FIELDS = ['code', 'script', 'source', 'content', 'payload', 'data', 'body', 'result', 'lua'];

const toBin = (bytes) => { let s = ''; for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000)); return s; };
const fromBin = (s) => { const b = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) b[i] = s.charCodeAt(i) & 255; return b; };

function printable(bytes) {
  if (!bytes.length) return 1;
  let ok = 0;
  const n = Math.min(bytes.length, 8192);
  for (let i = 0; i < n; i++) { const c = bytes[i]; if (c === 9 || c === 10 || c === 13 || (c >= 32 && c < 127) || c >= 0xc2) ok++; }
  return ok / n;
}

let CRC;
function crc32(bytes) {
  if (!CRC) { CRC = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; CRC[n] = c >>> 0; } }
  let c = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) c = CRC[(c ^ bytes[i]) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function gunzip(b) {
  if (b[2] !== 8) throw new Error('gzip: not DEFLATE');
  const flg = b[3];
  let i = 10;
  if (flg & 4) { const xlen = b[i] | (b[i + 1] << 8); i += 2 + xlen; }
  if (flg & 8) { while (i < b.length && b[i] !== 0) i++; i++; }
  if (flg & 16) { while (i < b.length && b[i] !== 0) i++; i++; }
  if (flg & 2) i += 2;
  const out = inflateRaw(b.subarray(i, b.length - 8), MAX_OUT);
  const t = b.length - 8;
  const crc = (b[t] | (b[t + 1] << 8) | (b[t + 2] << 16) | (b[t + 3] << 24)) >>> 0;
  if (crc32(out) !== crc) throw new Error('gzip: CRC-32 mismatch');
  return out;
}

function unzlib(b) {
  const out = inflateRaw(b.subarray(2, b.length - 4), MAX_OUT);
  const t = b.length - 4;
  const sum = ((b[t] << 24) | (b[t + 1] << 16) | (b[t + 2] << 8) | b[t + 3]) >>> 0;
  if (adler32(out) >>> 0 !== sum) throw new Error('zlib: Adler-32 mismatch');
  return out;
}

const isZlib = (b) => b.length > 6 && (b[0] & 0x0f) === 8 && (b[0] >> 4) <= 7 && ((b[0] << 8) | b[1]) % 31 === 0;
const isGzip = (b) => b.length > 18 && b[0] === 0x1f && b[1] === 0x8b;

function b64(text) {
  const t = text.replace(/\s+/g, '');
  if (t.length < 16 || !/^[A-Za-z0-9+/_-]+={0,2}$/.test(t) || (t.length % 4 === 1)) return null;
  const s = t.replace(/-/g, '+').replace(/_/g, '/');
  try { return fromBin(atob(s + '='.repeat((4 - (s.length % 4)) % 4))); } catch { return null; }
}
function hex(text) {
  const t = text.replace(/\s+/g, '');
  if (t.length < 16 || t.length % 2 || !/^[0-9a-fA-F]+$/.test(t)) return null;
  const out = new Uint8Array(t.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(t.substr(2 * i, 2), 16);
  return out;
}

/** Something worth continuing with after a text decoding: code-like text, or a recognised binary container. */
const meaningful = (b) => isGzip(b) || isZlib(b) || modelKind(b) || b[0] === 0x1b || printable(b) > 0.95;

/**
 * @param {Uint8Array} input the response body
 * @param {{contentType?: string}} [meta]
 * @returns {{ kind: string, label: string, layers: Array<{kind:string, note:string, bytes:number}>, text?: string, parses?: boolean, scripts?: Array, notes: string[] }}
 */
export function decodePayload(input, meta = {}) {
  const layers = [];
  const notes = [];
  let b = input;
  for (let depth = 0; depth <= MAX_LAYERS; depth++) {
    if (!b.length) return { kind: 'empty', label: 'an empty response', layers, notes };
    try {
      if (isGzip(b)) { const o = gunzip(b); layers.push({ kind: 'gzip', note: 'gzip stream, CRC-32 checked', bytes: o.length }); b = o; continue; }
      if (isZlib(b)) { const o = unzlib(b); layers.push({ kind: 'zlib', note: 'zlib stream, Adler-32 checked', bytes: o.length }); b = o; continue; }
    } catch (e) { notes.push(e.message); return { kind: 'corrupt', label: 'a compressed stream that is cut off or corrupt (its checksum or structure does not hold)', layers, notes }; }
    const model = modelKind(b);
    if (model) {
      try {
        const m = extractScripts(b);
        layers.push({ kind: model, note: `Roblox model, ${m.instances} instances, ${m.scripts.length} script(s)`, bytes: b.length });
        return { kind: 'model', label: `a Roblox model with ${m.scripts.length} script${m.scripts.length === 1 ? '' : 's'}`, layers, scripts: m.scripts, notes: [...notes, ...m.notes] };
      } catch (e) { notes.push(e.message); return { kind: 'binary', label: 'a Roblox model that could not be read', layers, notes }; }
    }
    if (b[0] === 0x1b) {
      const sig = toBin(b.subarray(1, 4));
      if (sig.startsWith('Lua')) return { kind: 'luac', label: `a compiled Lua chunk (version byte 0x${b[4].toString(16)})`, layers, text: toBin(b), notes };
      if (sig.startsWith('LJ')) return { kind: 'luajit', label: 'a LuaJIT bytecode chunk', layers, text: toBin(b), notes };
    }
    const text = toBin(b);
    if (/^\s*<(!doctype html|html|head|body)\b/i.test(text) || /text\/html/i.test(meta.contentType || '') && /<html/i.test(text)) {
      return { kind: 'html', label: 'a web page (often an error, login or "key required" page), not a script', layers, notes };
    }
    if (/^\s*[[{]/.test(text)) {
      try {
        const j = JSON.parse(new TextDecoder().decode(b));
        const found = Object.entries(j && typeof j === 'object' && !Array.isArray(j) ? j : {}).filter(([k, v]) => typeof v === 'string' && v.length >= 16 && CODE_FIELDS.includes(k.toLowerCase()));
        if (found.length === 1) { layers.push({ kind: 'json', note: `JSON; the code is in the "${found[0][0]}" field`, bytes: found[0][1].length }); b = new TextEncoder().encode(found[0][1]); continue; }
        const err = j && typeof j === 'object' && (j.error || j.message);
        return { kind: 'json', label: err ? `a JSON answer: ${String(err).slice(0, 120)}` : 'a JSON document without one code field', layers, notes };
      } catch { /* not JSON after all; carry on */ }
    }
    if (printable(b) > 0.97 && !/^\s*[A-Za-z0-9+/=\s_-]+$/.test(text.slice(0, 4096))) {
      let parses = false;
      try { parse(text); parses = true; } catch { /* reported */ }
      return { kind: 'lua', label: parses ? 'Lua source' : 'text that does not parse as Lua', layers, text, parses, notes };
    }
    const h = hex(text);
    if (h && meaningful(h)) { layers.push({ kind: 'hex', note: 'hexadecimal text', bytes: h.length }); b = h; continue; }
    const d = b64(text);
    if (d && meaningful(d)) { layers.push({ kind: 'base64', note: 'base64 text', bytes: d.length }); b = d; continue; }
    if (printable(b) > 0.97) {
      let parses = false;
      try { parse(text); parses = true; } catch { /* reported */ }
      return { kind: 'lua', label: parses ? 'Lua source' : 'text that does not parse as Lua', layers, text, parses, notes };
    }
    if (b.length > 4 && b[0] >= 3 && b[0] <= 6) notes.push('the first byte is a Luau bytecode version (3–6); Luau bytecode is not decompiled here');
    return { kind: 'binary', label: 'binary data that is not a known container', layers, notes };
  }
  return { kind: 'binary', label: `more than ${MAX_LAYERS} layers`, layers, notes };
}
