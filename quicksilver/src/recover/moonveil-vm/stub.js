// The encrypted part of a protected program, found without running anything.
//
// A prototype that is not a prototype (its first byte is not the magic number) is a stub: an encrypted, compressed prototype and the 12-byte
// nonce that goes with it. The runtime decrypts it with ChaCha20 under a key it derives when the program starts:
//
//     key = SHA-256( S + P )      S: a 32-byte value built by XORing 32-byte constants of one of the program's functions
//                                 P: a small whole number the runtime sums from probes of its environment (the numbers the probes return
//                                    when the environment is the real one are not in the file)
//
// The file holds everything but P. P is small, and the plain text begins with something checkable (a control byte for the compression, then the
// magic number of a prototype), so P is searched: for each P in turn, for each way of combining the constants, derive the key, decrypt the first
// block and test the start. A key that passes is then used on the whole stub and kept only if what comes out is a complete program (it parses to
// its last byte). Nothing from the file is executed; this is arithmetic on the file's own data.

import { sha256, chacha, lz } from '../moonveil-crypto.js';
import { readBlob } from './blob.js';

const K = new Uint32Array([
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]);

const bswap = (x) => ((x << 24) | ((x & 0xff00) << 8) | ((x >>> 8) & 0xff00) | (x >>> 24)) | 0;

/**
 * The first 64 bytes of keystream for each trial: SHA-256 of a 32-byte message, then one ChaCha20 block. All state is preallocated and the
 * rounds are written out over local variables, since this runs millions of times.
 */
function makeTrial(constants, nonceBytes) {
  const w = new Int32Array(64);
  const out = new Int32Array(16);
  const c0 = constants[0] | 0, c1 = constants[1] | 0, c2 = constants[2] | 0, c3 = constants[3] | 0;
  const n0 = (nonceBytes[0] | (nonceBytes[1] << 8) | (nonceBytes[2] << 16) | (nonceBytes[3] << 24)) | 0;
  const n1 = (nonceBytes[4] | (nonceBytes[5] << 8) | (nonceBytes[6] << 16) | (nonceBytes[7] << 24)) | 0;
  const n2 = (nonceBytes[8] | (nonceBytes[9] << 8) | (nonceBytes[10] << 16) | (nonceBytes[11] << 24)) | 0;
  /** `words` are the eight big-endian words of the 32-byte message */
  return function trial(words) {
    for (let i = 0; i < 8; i++) w[i] = words[i];
    w[8] = 0x80000000 | 0; w[9] = 0; w[10] = 0; w[11] = 0; w[12] = 0; w[13] = 0; w[14] = 0; w[15] = 256;
    for (let i = 16; i < 64; i++) {
      const a = w[i - 15], b = w[i - 2];
      w[i] = (w[i - 16] + (((a >>> 7) | (a << 25)) ^ ((a >>> 18) | (a << 14)) ^ (a >>> 3)) + w[i - 7] + (((b >>> 17) | (b << 15)) ^ ((b >>> 19) | (b << 13)) ^ (b >>> 10))) | 0;
    }
    let a = 0x6a09e667 | 0, b = 0xbb67ae85 | 0, c = 0x3c6ef372 | 0, d = 0xa54ff53a | 0, e = 0x510e527f | 0, f = 0x9b05688c | 0, g = 0x1f83d9ab | 0, h = 0x5be0cd19 | 0;
    for (let i = 0; i < 64; i++) {
      const t1 = (h + (((e >>> 6) | (e << 26)) ^ ((e >>> 11) | (e << 21)) ^ ((e >>> 25) | (e << 7))) + ((e & f) ^ (~e & g)) + K[i] + w[i]) | 0;
      const t2 = ((((a >>> 2) | (a << 30)) ^ ((a >>> 13) | (a << 19)) ^ ((a >>> 22) | (a << 10))) + ((a & b) ^ (a & c) ^ (b & c))) | 0;
      h = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0;
    }
    // the digest, read back as the little-endian words of the cipher key
    const k0 = bswap((0x6a09e667 + a) | 0), k1 = bswap((0xbb67ae85 + b) | 0), k2 = bswap((0x3c6ef372 + c) | 0), k3 = bswap((0xa54ff53a + d) | 0);
    const k4 = bswap((0x510e527f + e) | 0), k5 = bswap((0x9b05688c + f) | 0), k6 = bswap((0x1f83d9ab + g) | 0), k7 = bswap((0x5be0cd19 + h) | 0);
    let x0 = c0, x1 = c1, x2 = c2, x3 = c3, x4 = k0, x5 = k1, x6 = k2, x7 = k3, x8 = k4, x9 = k5, x10 = k6, x11 = k7, x12 = 0, x13 = n0, x14 = n1, x15 = n2;
    for (let r = 0; r < 10; r++) {
      // columns
      x0 = (x0 + x4) | 0; x12 ^= x0; x12 = (x12 << 16) | (x12 >>> 16); x8 = (x8 + x12) | 0; x4 ^= x8; x4 = (x4 << 12) | (x4 >>> 20);
      x0 = (x0 + x4) | 0; x12 ^= x0; x12 = (x12 << 8) | (x12 >>> 24); x8 = (x8 + x12) | 0; x4 ^= x8; x4 = (x4 << 7) | (x4 >>> 25);
      x1 = (x1 + x5) | 0; x13 ^= x1; x13 = (x13 << 16) | (x13 >>> 16); x9 = (x9 + x13) | 0; x5 ^= x9; x5 = (x5 << 12) | (x5 >>> 20);
      x1 = (x1 + x5) | 0; x13 ^= x1; x13 = (x13 << 8) | (x13 >>> 24); x9 = (x9 + x13) | 0; x5 ^= x9; x5 = (x5 << 7) | (x5 >>> 25);
      x2 = (x2 + x6) | 0; x14 ^= x2; x14 = (x14 << 16) | (x14 >>> 16); x10 = (x10 + x14) | 0; x6 ^= x10; x6 = (x6 << 12) | (x6 >>> 20);
      x2 = (x2 + x6) | 0; x14 ^= x2; x14 = (x14 << 8) | (x14 >>> 24); x10 = (x10 + x14) | 0; x6 ^= x10; x6 = (x6 << 7) | (x6 >>> 25);
      x3 = (x3 + x7) | 0; x15 ^= x3; x15 = (x15 << 16) | (x15 >>> 16); x11 = (x11 + x15) | 0; x7 ^= x11; x7 = (x7 << 12) | (x7 >>> 20);
      x3 = (x3 + x7) | 0; x15 ^= x3; x15 = (x15 << 8) | (x15 >>> 24); x11 = (x11 + x15) | 0; x7 ^= x11; x7 = (x7 << 7) | (x7 >>> 25);
      // diagonals
      x0 = (x0 + x5) | 0; x15 ^= x0; x15 = (x15 << 16) | (x15 >>> 16); x10 = (x10 + x15) | 0; x5 ^= x10; x5 = (x5 << 12) | (x5 >>> 20);
      x0 = (x0 + x5) | 0; x15 ^= x0; x15 = (x15 << 8) | (x15 >>> 24); x10 = (x10 + x15) | 0; x5 ^= x10; x5 = (x5 << 7) | (x5 >>> 25);
      x1 = (x1 + x6) | 0; x12 ^= x1; x12 = (x12 << 16) | (x12 >>> 16); x11 = (x11 + x12) | 0; x6 ^= x11; x6 = (x6 << 12) | (x6 >>> 20);
      x1 = (x1 + x6) | 0; x12 ^= x1; x12 = (x12 << 8) | (x12 >>> 24); x11 = (x11 + x12) | 0; x6 ^= x11; x6 = (x6 << 7) | (x6 >>> 25);
      x2 = (x2 + x7) | 0; x13 ^= x2; x13 = (x13 << 16) | (x13 >>> 16); x8 = (x8 + x13) | 0; x7 ^= x8; x7 = (x7 << 12) | (x7 >>> 20);
      x2 = (x2 + x7) | 0; x13 ^= x2; x13 = (x13 << 8) | (x13 >>> 24); x8 = (x8 + x13) | 0; x7 ^= x8; x7 = (x7 << 7) | (x7 >>> 25);
      x3 = (x3 + x4) | 0; x14 ^= x3; x14 = (x14 << 16) | (x14 >>> 16); x9 = (x9 + x14) | 0; x4 ^= x9; x4 = (x4 << 12) | (x4 >>> 20);
      x3 = (x3 + x4) | 0; x14 ^= x3; x14 = (x14 << 8) | (x14 >>> 24); x9 = (x9 + x14) | 0; x4 ^= x9; x4 = (x4 << 7) | (x4 >>> 25);
    }
    out[0] = (x0 + c0) | 0; out[1] = (x1 + c1) | 0; out[2] = (x2 + c2) | 0; out[3] = (x3 + c3) | 0;
    out[4] = (x4 + k0) | 0; out[5] = (x5 + k1) | 0; out[6] = (x6 + k2) | 0; out[7] = (x7 + k3) | 0;
    out[8] = (x8 + k4) | 0; out[9] = (x9 + k5) | 0; out[10] = (x10 + k6) | 0; out[11] = (x11 + k7) | 0;
    out[12] = x12; out[13] = (x13 + n0) | 0; out[14] = (x14 + n1) | 0; out[15] = (x15 + n2) | 0;
    return out;
  };
}

/** The first 64 bytes of the stub, as a compressed stream must begin: a control byte, then items whose back-references point at bytes already produced. */
function plausibleStart(plain) {
  if (!(plain[0] & 1)) return false;
  let olen = 0;
  let a = 0;
  while (a < 64) {
    let ctrl = plain[a++];
    for (let r = 0; r < 8 && a < 64; r++) {
      if (ctrl & 1) { a++; olen++; } else {
        if (a + 1 >= 64) return true;
        const p = (plain[a] << 8) | plain[a + 1];
        a += 2;
        const off = p >> 5;
        const len = (p & 31) + 3;
        if (off < 1 || off > olen) return false;
        olen += Math.min(len, off);
      }
      ctrl >>= 1;
    }
  }
  return true;
}

const asString = (bytes) => { let s = ''; for (let i = 0; i < bytes.length; i += 4096) s += String.fromCharCode.apply(null, bytes.subarray(i, Math.min(bytes.length, i + 4096))); return s; };
const asBytes = (s) => { const b = new Uint8Array(s.length); for (let i = 0; i < s.length; i++) b[i] = s.charCodeAt(i) & 255; return b; };

/**
 * Combinations of the constants: every non-empty subset XORed together, the likeliest first. Without more to go on, the ones that use most of the
 * constants are likeliest. `roles` says how the program uses a constant: one that is an argument of a call (read byte by byte and combined) is an
 * operand; one that is only assigned to a variable (a value put in place of another when a check fails) is not, and a subset is better the more
 * operands it has and the fewer of the others.
 */
export function combinations(constants, max = 10, roles = new Map()) {
  const list = constants.slice(0, max);
  const operand = list.map((c) => roles.get(c) === 'operand');
  const known = operand.some(Boolean);
  const out = [];
  for (let mask = 1; mask < (1 << list.length); mask++) {
    const bytes = new Uint8Array(32);
    let score = 0;
    for (let i = 0; i < list.length; i++) {
      const inside = (mask & (1 << i)) !== 0;
      if (inside) for (let k = 0; k < 32; k++) bytes[k] ^= list[i].charCodeAt(k);
      score += known ? (inside === operand[i] ? 1 : 0) : (inside ? 1 : 0);
    }
    out.push({ mask, bytes, size: popcount(mask), of: list.length, score });
  }
  out.sort((p, q) => q.score - p.score || q.size - p.size || p.mask - q.mask);
  // the single best guess is searched on its own first; a guess backed by evidence is right far more often than not
  out.forEach((c, i) => { c.likely = i < 5; c.best = known && i === 0; });
  return out;
}
const popcount = (n) => { let c = 0; for (; n; n &= n - 1) c++; return c; };

const beWord = (b, i) => ((b[4 * i] << 24) | (b[4 * i + 1] << 16) | (b[4 * i + 2] << 8) | b[4 * i + 3]) | 0;

/**
 * @param {{payload: Uint8Array, nonce: Uint8Array}} stub
 * @param {{bytes: Uint8Array, mask: number, size: number, of: number}[]} bases   the values S can be (all but at most one of the constants first)
 * @param {{constants: number[], profile: object, limit?: number, onProgress?: Function, shouldStop?: Function}} opts
 * @returns {{key: string, offset: number, mask: number, bytes: Uint8Array, root: object} | null}
 */
export function searchStubKey(stub, bases, { constants, profile, limit = 1 << 21, onProgress, shouldStop }) {
  if (stub.nonce.length !== 12 || stub.payload.length < 64 || !bases.length) return null;
  const trial = makeTrial(constants, stub.nonce);
  const cipher = new Int32Array(16);
  for (let i = 0; i < 16; i++) cipher[i] = (stub.payload[4 * i] | (stub.payload[4 * i + 1] << 8) | (stub.payload[4 * i + 2] << 16) | (stub.payload[4 * i + 3] << 24)) | 0;
  const magic = profile.protoMagic;
  const payloadStr = asString(stub.payload);
  const nonceStr = asString(stub.nonce);
  const plain = new Uint8Array(64);
  const words = new Int32Array(8);
  const msg = new Uint8Array(32);
  const prepared = bases.map((base) => ({ base, lo: (base.bytes[0] | (base.bytes[1] << 8) | (base.bytes[2] << 16) | (base.bytes[3] << 24)) >>> 0, rest: Array.from({ length: 8 }, (_, i) => beWord(base.bytes, i)) }));

  /** the best guess alone, then the likeliest few, then the rest; each group over its own range of numbers */
  const groups = [
    { bases: prepared.filter((x) => x.base.best), range: Math.min(limit, 1 << 19) },
    { bases: prepared.filter((x) => x.base.likely && !x.base.best), range: limit },
    { bases: prepared.filter((x) => !x.base.likely), range: Math.min(limit, 1 << 18) },
  ].filter((g) => g.bases.length);
  let total = 0;
  for (const [gi, { bases: group, range }] of groups.entries()) {
    for (let p = 0; p < range; p++) {
      if ((p & 0x3fff) === 0) {
        if (onProgress) onProgress(p, range, gi);
        if (shouldStop && shouldStop()) return null;
      }
      for (const item of group) {
        const sum = item.lo + p;
        let ks;
        if (sum < 4294967296) {
          // only the first word of the message changes (the low four bytes of S + P, which the hash reads as one big-endian word)
          for (let i = 1; i < 8; i++) words[i] = item.rest[i];
          words[0] = bswap(sum | 0);
          ks = trial(words);
          for (let i = 0; i < 4; i++) msg[i] = (sum >>> (8 * i)) & 255;
          for (let i = 4; i < 32; i++) msg[i] = item.base.bytes[i];
        } else {
          // the carry runs on into the following bytes
          let carry = p;
          for (let i = 0; i < 32; i++) {
            if (carry === 0) { msg[i] = item.base.bytes[i]; continue; }
            const v = item.base.bytes[i] + carry;
            msg[i] = v & 255;
            carry = Math.floor(v / 256);
          }
          for (let i = 0; i < 8; i++) words[i] = beWord(msg, i);
          ks = trial(words);
        }
        total++;
        // the second byte of the plain text is the magic number
        if ((((cipher[0] ^ ks[0]) >>> 8) & 255) !== magic) continue;
        for (let i = 0; i < 16; i++) { const v = cipher[i] ^ ks[i]; plain[4 * i] = v & 255; plain[4 * i + 1] = (v >>> 8) & 255; plain[4 * i + 2] = (v >>> 16) & 255; plain[4 * i + 3] = (v >>> 24) & 255; }
        if (!plausibleStart(plain)) continue;
        const key = sha256(asString(msg));
        const bytes = asBytes(lz(chacha(payloadStr, nonceStr, key, constants)));
        let parsed;
        try { parsed = readBlob(bytes, profile); } catch { continue; }
        if (parsed.end !== parsed.length) continue;
        return { key, offset: p, mask: item.base.mask, bytes, root: parsed.root, trials: total };
      }
    }
  }
  return null;
}
