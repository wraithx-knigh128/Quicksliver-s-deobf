// Raw DEFLATE (RFC 1951) decompression, small and dependency-free, so that it runs in the browser as well as in Node.
// Used for containers that carry a deflate stream inside a script (LuaQ's LQZ1). Throws InflateError on malformed input.

export class InflateError extends Error {}
const fail = (m) => { throw new InflateError(m); };

const LEN_BASE = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258];
const LEN_EXTRA = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0];
const DIST_BASE = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577];
const DIST_EXTRA = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13];
const CL_ORDER = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];

/** Canonical Huffman decoding table from code lengths: counts per length and symbols ordered by code. */
function huffman(lengths) {
  const counts = new Uint16Array(16);
  for (const l of lengths) counts[l]++;
  counts[0] = 0;
  const offs = new Uint16Array(16);
  for (let i = 1; i < 16; i++) offs[i] = offs[i - 1] + counts[i - 1];
  const symbols = new Uint16Array(lengths.length);
  lengths.forEach((l, s) => { if (l) symbols[offs[l]++] = s; });
  return { counts, symbols };
}

/**
 * @param {Uint8Array} data raw deflate stream
 * @param {number} [maxOut] refuse output larger than this
 * @returns {Uint8Array}
 */
export function inflateRaw(data, maxOut = 1 << 28) {
  let pos = 0;
  let bit = 0;
  let nbits = 0;
  let out = new Uint8Array(Math.min(maxOut, Math.max(1024, data.length * 4)));
  let len = 0;
  const need = (n) => {
    if (len + n <= out.length) return;
    if (len + n > maxOut) fail('the output is larger than allowed');
    let size = out.length * 2;
    while (size < len + n) size *= 2;
    const grown = new Uint8Array(Math.min(size, maxOut));
    grown.set(out.subarray(0, len));
    out = grown;
  };
  const bits = (n) => {
    while (nbits < n) {
      if (pos >= data.length) fail('the stream ends early');
      bit |= data[pos++] << nbits;
      nbits += 8;
    }
    const v = bit & ((1 << n) - 1);
    bit >>>= n;
    nbits -= n;
    return v;
  };
  const decode = (h) => {
    let code = 0;
    let first = 0;
    let index = 0;
    for (let l = 1; l < 16; l++) {
      code |= bits(1);
      const count = h.counts[l];
      if (code - first < count) return h.symbols[index + code - first];
      index += count;
      first = (first + count) << 1;
      code <<= 1;
    }
    return fail('an invalid Huffman code');
  };
  let fixedLit = null;
  let fixedDist = null;
  let final = 0;
  do {
    final = bits(1);
    const type = bits(2);
    if (type === 0) {
      bit = 0; nbits = 0;
      if (pos + 4 > data.length) fail('a stored block ends early');
      const n = data[pos] | (data[pos + 1] << 8);
      const nn = data[pos + 2] | (data[pos + 3] << 8);
      pos += 4;
      if ((n ^ 0xffff) !== nn) fail('a stored block has a bad length');
      if (pos + n > data.length) fail('a stored block ends early');
      need(n);
      out.set(data.subarray(pos, pos + n), len);
      len += n;
      pos += n;
      continue;
    }
    let lit;
    let dist;
    if (type === 1) {
      if (!fixedLit) {
        const l = new Array(288);
        for (let i = 0; i < 288; i++) l[i] = i < 144 ? 8 : i < 256 ? 9 : i < 280 ? 7 : 8;
        fixedLit = huffman(l);
        fixedDist = huffman(new Array(30).fill(5));
      }
      lit = fixedLit; dist = fixedDist;
    } else if (type === 2) {
      const hlit = bits(5) + 257;
      const hdist = bits(5) + 1;
      const hclen = bits(4) + 4;
      const cl = new Array(19).fill(0);
      for (let i = 0; i < hclen; i++) cl[CL_ORDER[i]] = bits(3);
      const clh = huffman(cl);
      const lengths = [];
      while (lengths.length < hlit + hdist) {
        const s = decode(clh);
        if (s < 16) lengths.push(s);
        else if (s === 16) { if (!lengths.length) fail('a repeat with nothing to repeat'); const p = lengths[lengths.length - 1]; for (let r = bits(2) + 3; r > 0; r--) lengths.push(p); }
        else if (s === 17) { for (let r = bits(3) + 3; r > 0; r--) lengths.push(0); }
        else { for (let r = bits(7) + 11; r > 0; r--) lengths.push(0); }
      }
      if (lengths.length > hlit + hdist) fail('code lengths run past their count');
      lit = huffman(lengths.slice(0, hlit));
      dist = huffman(lengths.slice(hlit));
    } else fail('a reserved block type');
    for (;;) {
      const s = decode(lit);
      if (s < 256) { need(1); out[len++] = s; continue; }
      if (s === 256) break;
      const li = s - 257;
      if (li >= 29) fail('an invalid length code');
      const n = LEN_BASE[li] + bits(LEN_EXTRA[li]);
      const di = decode(dist);
      if (di >= 30) fail('an invalid distance code');
      const d = DIST_BASE[di] + bits(DIST_EXTRA[di]);
      if (d > len) fail('a distance before the start of the output');
      need(n);
      for (let k = 0; k < n; k++) { out[len] = out[len - d]; len++; }
    }
  } while (!final);
  return out.subarray(0, len);
}

/** Adler-32 of bytes. */
export function adler32(bytes) {
  let a = 1;
  let b = 0;
  for (let i = 0; i < bytes.length; i++) { a = (a + bytes[i]) % 65521; b = (b + a) % 65521; }
  return (b * 65536 + a) >>> 0;
}
