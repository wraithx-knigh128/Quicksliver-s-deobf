// The three primitives a MoonVeil-style VM runtime carries, ported so that data the runtime would decrypt can be read back without running it:
//
//   sha256(bytes)               plain SHA-256; the runtime uses it to turn a key string into a 32-byte cipher key
//   chacha(data, nonce, key)    a ChaCha20 whose four constants are not "expand 32-byte k" (the runtime picks its own), 20 rounds, the block
//                               counter in word 12 counting from 0, the 12-byte nonce in words 13..15
//   lz(bytes)                   the byte-oriented LZ with a 2048-byte window that the runtime applies after decrypting
//
// Strings are "binary strings" (one char per byte, as the parser and printer use), results are binary strings too. Nothing here runs the
// script it was taken from: these are the algorithms, applied by this program to data that is already in the file.

const K = new Uint32Array([
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]);

const bytesOf = (s) => { const b = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) b[i] = s.charCodeAt(i) & 255; return b; };
const stringOf = (b) => { let out = ''; for (let i = 0; i < b.length; i += 4096) out += String.fromCharCode.apply(null, b.subarray(i, Math.min(b.length, i + 4096))); return out; };
const rotr = (x, n) => (x >>> n) | (x << (32 - n));
const rotl = (x, n) => (x << n) | (x >>> (32 - n));

/** SHA-256 of a binary string, as a 32-char binary string. */
export function sha256(str) {
  const msg = bytesOf(str);
  const len = msg.length;
  const total = ((len + 9 + 63) >> 6) << 6;
  const buf = new Uint8Array(total);
  buf.set(msg);
  buf[len] = 0x80;
  const bits = len * 8;
  const dv = new DataView(buf.buffer);
  dv.setUint32(total - 8, Math.floor(bits / 4294967296));
  dv.setUint32(total - 4, bits >>> 0);
  const h = new Uint32Array([0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]);
  const w = new Uint32Array(64);
  for (let off = 0; off < total; off += 64) {
    for (let i = 0; i < 16; i++) w[i] = dv.getUint32(off + 4 * i);
    for (let i = 16; i < 64; i++) {
      const s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
      const s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) | 0;
    }
    let [a, b, c, d, e, f, g, hh] = h;
    for (let i = 0; i < 64; i++) {
      const t1 = (hh + (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) + ((e & f) ^ (~e & g)) + K[i] + w[i]) | 0;
      const t2 = ((rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) + ((a & b) ^ (a & c) ^ (b & c))) | 0;
      hh = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0;
    }
    h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
  }
  const out = new Uint8Array(32);
  const odv = new DataView(out.buffer);
  for (let i = 0; i < 8; i++) odv.setUint32(4 * i, h[i]);
  return stringOf(out);
}

/** The runtime's ChaCha20: `constants` are its four state words; data, nonce (12 bytes) and key (32 bytes) are binary strings. */
export function chacha(data, nonce, key, constants = [2846445141, 1400178223, 2515970237, 3225862554]) {
  if (key.length !== 32 || nonce.length !== 12) return null;
  const input = bytesOf(data);
  const k = bytesOf(key);
  const n = bytesOf(nonce);
  const kdv = new DataView(k.buffer);
  const ndv = new DataView(n.buffer);
  const out = new Uint8Array(input.length);
  const state = new Uint32Array(16);
  const x = new Uint32Array(16);
  for (let i = 0; i < 4; i++) state[i] = constants[i] >>> 0;
  for (let i = 0; i < 8; i++) state[4 + i] = kdv.getUint32(4 * i, true);
  for (let i = 0; i < 3; i++) state[13 + i] = ndv.getUint32(4 * i, true);
  const qr = (a, b, c, d) => {
    x[a] = (x[a] + x[b]) | 0; x[d] = rotl(x[d] ^ x[a], 16);
    x[c] = (x[c] + x[d]) | 0; x[b] = rotl(x[b] ^ x[c], 12);
    x[a] = (x[a] + x[b]) | 0; x[d] = rotl(x[d] ^ x[a], 8);
    x[c] = (x[c] + x[d]) | 0; x[b] = rotl(x[b] ^ x[c], 7);
  };
  for (let block = 0; block * 64 < input.length; block++) {
    state[12] = block;
    x.set(state);
    for (let r = 0; r < 10; r++) { qr(0, 4, 8, 12); qr(1, 5, 9, 13); qr(2, 6, 10, 14); qr(3, 7, 11, 15); qr(0, 5, 10, 15); qr(1, 6, 11, 12); qr(2, 7, 8, 13); qr(3, 4, 9, 14); }
    for (let i = 0; i < 16; i++) {
      const word = (x[i] + state[i]) >>> 0;
      for (let b = 0; b < 4; b++) { const pos = block * 64 + 4 * i + b; if (pos < input.length) out[pos] = input[pos] ^ ((word >>> (8 * b)) & 255); }
    }
  }
  return stringOf(out);
}

/**
 * The runtime's LZ: groups of eight items behind a control byte; bit 1 is a literal byte, bit 0 a two-byte reference (11-bit offset, 5-bit
 * length minus 3) into the last 2048 bytes produced. A reference reads the window as it stood before the item, so it never repeats itself.
 */
export function lz(input) {
  const src = bytesOf(input);
  const out = [];
  let a = 0;
  while (a < src.length) {
    let ctrl = src[a++];
    for (let r = 0; r < 8; r++) {
      if (ctrl & 1) {
        if (a < src.length) out.push(src[a++]);
      } else if (a + 1 < src.length) {
        const p = (src[a] << 8) | src[a + 1];
        a += 2;
        const off = p >> 5;
        const len = (p & 31) + 3;
        const base = Math.max(0, out.length - 2048);
        const size = out.length - base;
        let from = size - off - 1;
        if (from < 0) from = Math.max(size + from, 0);
        const start = base + from;
        const end = Math.min(start + len, out.length);
        for (let i = start; i < end; i++) out.push(out[i]);
      }
      ctrl >>= 1;
    }
  }
  return stringOf(Uint8Array.from(out));
}

/** The stub's key: SHA-256 of a 32-byte value with a small number added to it, little-endian (the runtime adds the sum of its environment probes). */
export function addLE(base, n) {
  const b = bytesOf(base);
  let carry = n;
  for (let i = 0; i < b.length && carry > 0; i++) { const v = b[i] + carry; b[i] = v & 255; carry = Math.floor(v / 256); }
  return stringOf(b);
}
