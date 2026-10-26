// Zstandard decompression (RFC 8878), written for QuickSilver: scripts that go through Roblox's EncodingService carry their text as a
// base64 zstd frame, and the page has to read it without running anything. Browsers have no zstd, so this is a decoder of the format:
// frames, raw / RLE / compressed blocks, Huffman-coded literals (FSE-compressed or direct weights, one or four streams), FSE-coded sequences
// with the predefined, RLE, compressed and repeat modes, and the repeat-offset rules. Dictionaries are not supported (a frame that names one is
// refused), the content checksum is skipped, and the output is capped. Tested against Node's own zstd on generated data (tests/zstd.test.mjs).

export class ZstdError extends Error {}

const fail = (msg) => { throw new ZstdError(msg); };

const LL_BASE = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 28, 32, 40, 48, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536];
const LL_BITS = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
const ML_BASE = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 37, 39, 41, 43, 47, 51, 59, 67, 83, 99, 131, 259, 515, 1027, 2051, 4099, 8195, 16387, 32771, 65539];
const ML_BITS = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

const PREDEFINED = {
  ll: { log: 6, counts: [4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 2, 1, 1, 1, 1, 1, -1, -1, -1, -1] },
  ml: { log: 6, counts: [1, 4, 3, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1] },
  of: { log: 5, counts: [1, 1, 1, 1, 1, 1, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1] },
};

const highBit = (x) => 31 - Math.clz32(x);

/** Bits are read from the end of the buffer towards its start; the highest set bit of the last byte marks where the data ends. */
class BackwardBits {
  constructor(buf, start, end) {
    this.buf = buf;
    this.start = start;
    if (end <= start) fail('empty bitstream');
    const last = buf[end - 1];
    if (last === 0) fail('bitstream end marker missing');
    this.left = (end - 1 - start) * 8 + highBit(last); // data bits that are left
  }

  /** The next n (<= 32) bits; positions before the start of the stream read as zero, and `left` goes negative. */
  read(n) {
    if (n === 0) return 0;
    const from = this.left - n;
    this.left = from;
    let v = 0;
    for (let i = n - 1; i >= 0; i--) {
      const p = from + i;
      let bit = 0;
      if (p >= 0) bit = (this.buf[this.start + (p >> 3)] >> (p & 7)) & 1;
      v = v * 2 + bit;
    }
    return v;
  }

  /** The next n bits without consuming them. */
  peek(n) {
    const save = this.left;
    const v = this.read(n);
    this.left = save;
    return v;
  }
}

/** Reads a normalised-count table description from a forward bitstream. Returns { counts, log, used } (used = bytes). */
function readFseHeader(buf, pos, end, maxLog, maxSymbol) {
  let bitPos = 0;
  const bits = (n) => {
    let v = 0;
    for (let i = 0; i < n; i++) {
      const p = bitPos + i;
      const byte = pos + (p >> 3) < end ? buf[pos + (p >> 3)] : 0;
      v |= ((byte >> (p & 7)) & 1) << i;
    }
    return v;
  };
  const log = bits(4) + 5;
  bitPos += 4;
  if (log > maxLog) fail('FSE accuracy log too large');
  let remaining = (1 << log) + 1;
  let threshold = 1 << log;
  let nbBits = log + 1;
  const counts = [];
  let previousZero = false;
  while (remaining > 1 && counts.length <= maxSymbol) {
    if (previousZero) {
      // a run of zero-probability symbols: 2-bit repeat counts, a 3 meaning "and read another"
      for (;;) {
        const r = bits(2);
        bitPos += 2;
        for (let i = 0; i < r; i++) counts.push(0);
        if (r !== 3) break;
      }
      previousZero = false;
      if (counts.length > maxSymbol + 1) fail('FSE table has too many symbols');
      continue;
    }
    const max = 2 * threshold - 1 - remaining;
    let count;
    const low = bits(nbBits - 1);
    if (low < max) { count = low; bitPos += nbBits - 1; } else {
      count = bits(nbBits);
      bitPos += nbBits;
      if (count >= threshold) count -= max;
    }
    count -= 1;
    remaining -= count < 0 ? -count : count;
    counts.push(count);
    previousZero = count === 0;
    while (remaining < threshold) { nbBits--; threshold >>= 1; }
  }
  if (remaining !== 1) fail('FSE table does not add up');
  if (counts.length > maxSymbol + 1) fail('FSE table has too many symbols');
  return { counts, log, used: (bitPos + 7) >> 3 };
}

/** Decoding table: for each state, the symbol and how to reach the next one. */
function buildFse(counts, log) {
  const size = 1 << log;
  const symbol = new Uint16Array(size);
  const nbBits = new Uint8Array(size);
  const base = new Uint32Array(size);
  const next = new Uint32Array(counts.length);
  let high = size - 1;
  counts.forEach((c, s) => { if (c === -1) { symbol[high--] = s; next[s] = 1; } else next[s] = c; });
  const step = (size >> 1) + (size >> 3) + 3;
  const mask = size - 1;
  let pos = 0;
  counts.forEach((c, s) => {
    for (let i = 0; i < c; i++) {
      symbol[pos] = s;
      do { pos = (pos + step) & mask; } while (pos > high);
    }
  });
  if (pos !== 0) fail('FSE spread did not close');
  for (let u = 0; u < size; u++) {
    const s = symbol[u];
    const ns = next[s]++;
    const nb = log - highBit(ns);
    nbBits[u] = nb;
    base[u] = (ns << nb) - size;
  }
  return { log, symbol, nbBits, base };
}

const rleTable = (sym) => ({ log: 0, symbol: new Uint16Array([sym]), nbBits: new Uint8Array([0]), base: new Uint32Array([0]) });

/** Huffman weights coded with FSE: two interleaved states over a backward bitstream. */
function fseWeights(buf, start, end) {
  const { counts, log, used } = readFseHeader(buf, start, end, 6, 255);
  const table = buildFse(counts, log);
  const bits = new BackwardBits(buf, start + used, end);
  const out = [];
  let s1 = bits.read(log);
  let s2 = bits.read(log);
  for (;;) {
    out.push(table.symbol[s1]);
    s1 = table.base[s1] + bits.read(table.nbBits[s1]);
    if (bits.left < 0) { out.push(table.symbol[s2]); break; }
    out.push(table.symbol[s2]);
    s2 = table.base[s2] + bits.read(table.nbBits[s2]);
    if (bits.left < 0) { out.push(table.symbol[s1]); break; }
    if (out.length > 255) fail('too many Huffman weights');
  }
  return out;
}

function readHuffmanTree(buf, pos, end) {
  const header = buf[pos];
  let weights;
  let used;
  if (header >= 128) {
    const n = header - 127;
    weights = [];
    for (let i = 0; i < n; i++) { const b = buf[pos + 1 + (i >> 1)]; weights.push(i % 2 === 0 ? b >> 4 : b & 15); }
    used = 1 + ((n + 1) >> 1);
  } else {
    weights = fseWeights(buf, pos + 1, pos + 1 + header);
    used = 1 + header;
  }
  let total = 0;
  for (const w of weights) if (w > 0) total += 1 << (w - 1);
  if (total === 0) fail('empty Huffman tree');
  const maxBits = highBit(total) + 1;
  const missing = (1 << maxBits) - total;
  if (missing <= 0 || (missing & (missing - 1)) !== 0) fail('Huffman weights do not complete a tree');
  weights.push(highBit(missing) + 1); // the last symbol's weight is implied
  if (maxBits > 11) fail('Huffman code too long');
  // table: weights ascending, symbols ascending within a weight
  const size = 1 << maxBits;
  const symbol = new Uint8Array(size);
  const nbBits = new Uint8Array(size);
  let at = 0;
  for (let w = 1; w <= maxBits; w++) {
    for (let s = 0; s < weights.length; s++) {
      if (weights[s] !== w) continue;
      const len = 1 << (w - 1);
      symbol.fill(s, at, at + len);
      nbBits.fill(maxBits + 1 - w, at, at + len);
      at += len;
    }
  }
  return { tree: { maxBits, symbol, nbBits }, used };
}

function huffmanStream(buf, start, end, tree, count, out, outAt) {
  const bits = new BackwardBits(buf, start, end);
  for (let i = 0; i < count; i++) {
    const idx = bits.peek(tree.maxBits);
    out[outAt + i] = tree.symbol[idx];
    bits.read(tree.nbBits[idx]);
  }
  if (bits.left !== 0) fail('Huffman stream not fully consumed');
}

function readLiterals(buf, pos, end, state) {
  const b0 = buf[pos];
  const type = b0 & 3;
  const format = (b0 >> 2) & 3;
  if (type <= 1) {
    let size;
    let head;
    if (format === 0 || format === 2) { size = b0 >> 3; head = 1; } else if (format === 1) { size = (b0 >> 4) + (buf[pos + 1] << 4); head = 2; } else { size = (b0 >> 4) + (buf[pos + 1] << 4) + (buf[pos + 2] << 12); head = 3; }
    if (type === 0) {
      if (pos + head + size > end) fail('literals past the end of the block');
      return { lits: buf.subarray(pos + head, pos + head + size), next: pos + head + size };
    }
    return { lits: new Uint8Array(size).fill(buf[pos + head]), next: pos + head + 1 };
  }
  let regen;
  let comp;
  let head;
  let streams = 4;
  if (format === 0 || format === 1) {
    const v = b0 | (buf[pos + 1] << 8) | (buf[pos + 2] << 16);
    regen = (v >> 4) & 0x3ff; comp = (v >> 14) & 0x3ff; head = 3;
    if (format === 0) streams = 1;
  } else if (format === 2) {
    const v = (b0 | (buf[pos + 1] << 8) | (buf[pos + 2] << 16) | (buf[pos + 3] << 24)) >>> 0;
    regen = (v >>> 4) & 0x3fff; comp = (v >>> 18) & 0x3fff; head = 4;
  } else {
    const lo = (b0 | (buf[pos + 1] << 8) | (buf[pos + 2] << 16) | (buf[pos + 3] << 24)) >>> 0;
    regen = (lo >>> 4) & 0x3ffff; comp = ((lo >>> 22) | (buf[pos + 4] << 10)) & 0x3ffff; head = 5;
  }
  let at = pos + head;
  const stop = at + comp;
  if (stop > end) fail('compressed literals past the end of the block');
  if (type === 2) {
    const t = readHuffmanTree(buf, at, stop);
    state.huffman = t.tree;
    at += t.used;
  } else if (!state.huffman) fail('treeless literals without a previous tree');
  const out = new Uint8Array(regen);
  if (streams === 1) huffmanStream(buf, at, stop, state.huffman, regen, out, 0);
  else {
    const s1 = buf[at] | (buf[at + 1] << 8);
    const s2 = buf[at + 2] | (buf[at + 3] << 8);
    const s3 = buf[at + 4] | (buf[at + 5] << 8);
    const body = at + 6;
    const part = (regen + 3) >> 2;
    const e1 = body + s1; const e2 = e1 + s2; const e3 = e2 + s3;
    if (e3 > stop) fail('Huffman stream sizes exceed the section');
    huffmanStream(buf, body, e1, state.huffman, part, out, 0);
    huffmanStream(buf, e1, e2, state.huffman, part, out, part);
    huffmanStream(buf, e2, e3, state.huffman, part, out, 2 * part);
    huffmanStream(buf, e3, stop, state.huffman, regen - 3 * part, out, 3 * part);
  }
  return { lits: out, next: stop };
}

function chooseTable(mode, kind, buf, pos, end, state, maxLog, maxSym) {
  if (mode === 0) { const p = PREDEFINED[kind]; state[kind] = buildFse(p.counts, p.log); return pos; }
  if (mode === 1) { state[kind] = rleTable(buf[pos]); return pos + 1; }
  if (mode === 2) {
    const h = readFseHeader(buf, pos, end, maxLog, maxSym);
    state[kind] = buildFse(h.counts, h.log);
    return pos + h.used;
  }
  if (!state[kind]) fail('repeat table without a previous one');
  return pos;
}

function readSequences(buf, pos, end, state) {
  let n = buf[pos++];
  if (n === 0) return { count: 0, seqs: [] };
  if (n >= 128) {
    if (n < 255) n = ((n - 128) << 8) + buf[pos++];
    else { n = buf[pos] + (buf[pos + 1] << 8) + 0x7f00; pos += 2; }
  }
  const modes = buf[pos++];
  pos = chooseTable((modes >> 6) & 3, 'll', buf, pos, end, state, 9, 35);
  pos = chooseTable((modes >> 4) & 3, 'of', buf, pos, end, state, 8, 31);
  pos = chooseTable((modes >> 2) & 3, 'ml', buf, pos, end, state, 9, 52);
  const bits = new BackwardBits(buf, pos, end);
  const { ll, of, ml } = state;
  let sl = bits.read(ll.log);
  let so = bits.read(of.log);
  let sm = bits.read(ml.log);
  const seqs = [];
  for (let i = 0; i < n; i++) {
    const oc = of.symbol[so];
    const mc = ml.symbol[sm];
    const lc = ll.symbol[sl];
    if (oc > 31) fail('offset code out of range');
    const offsetValue = oc === 0 ? 1 : (2 ** oc) + bits.read(oc);
    const matchLength = ML_BASE[mc] + bits.read(ML_BITS[mc]);
    const litLength = LL_BASE[lc] + bits.read(LL_BITS[lc]);
    seqs.push([litLength, matchLength, offsetValue]);
    if (i + 1 < n) {
      sl = ll.base[sl] + bits.read(ll.nbBits[sl]);
      sm = ml.base[sm] + bits.read(ml.nbBits[sm]);
      so = of.base[so] + bits.read(of.nbBits[so]);
    }
  }
  if (bits.left < 0) fail('sequence bitstream overrun');
  return { count: n, seqs };
}

/**
 * @param {Uint8Array} input one or more zstd frames
 * @param {{maxOutput?: number}} [options]
 * @returns {Uint8Array}
 */
export function zstdDecompress(input, options = {}) {
  const maxOutput = options.maxOutput ?? 64 * 1024 * 1024;
  const buf = input;
  let pos = 0;
  let out = new Uint8Array(Math.min(Math.max(input.length * 4, 1024), maxOutput));
  let outLen = 0;
  const ensure = (extra) => {
    if (outLen + extra > maxOutput) fail('output exceeds the limit');
    if (outLen + extra > out.length) { const bigger = new Uint8Array(Math.min(Math.max(out.length * 2, outLen + extra), maxOutput)); bigger.set(out.subarray(0, outLen)); out = bigger; }
  };
  while (pos < buf.length) {
    const magic = (buf[pos] | (buf[pos + 1] << 8) | (buf[pos + 2] << 16) | (buf[pos + 3] << 24)) >>> 0;
    if ((magic & 0xfffffff0) >>> 0 === 0x184d2a50) { pos += 8 + (buf[pos + 4] | (buf[pos + 5] << 8) | (buf[pos + 6] << 16) | (buf[pos + 7] << 24)); continue; }
    if (magic !== 0xfd2fb528) fail('not a zstd frame');
    pos += 4;
    const fd = buf[pos++];
    const fcsFlag = fd >> 6;
    const single = (fd >> 5) & 1;
    const checksum = (fd >> 2) & 1;
    const dictFlag = fd & 3;
    if (fd & 8) fail('reserved bit set');
    if (!single) pos += 1; // window descriptor
    if (dictFlag) { const bytes = [0, 1, 2, 4][dictFlag]; let id = 0; for (let i = 0; i < bytes; i++) id += buf[pos + i] * 2 ** (8 * i); pos += bytes; if (id) fail('dictionaries are not supported'); }
    pos += fcsFlag === 0 ? (single ? 1 : 0) : fcsFlag === 1 ? 2 : fcsFlag === 2 ? 4 : 8;
    const state = { huffman: null, ll: null, of: null, ml: null };
    let reps = [1, 4, 8];
    for (let last = false; !last;) {
      if (pos + 3 > buf.length) fail('truncated block header');
      const h = buf[pos] | (buf[pos + 1] << 8) | (buf[pos + 2] << 16);
      pos += 3;
      last = (h & 1) === 1;
      const type = (h >> 1) & 3;
      const size = h >> 3;
      if (type === 0) {
        if (pos + size > buf.length) fail('truncated raw block');
        ensure(size);
        out.set(buf.subarray(pos, pos + size), outLen);
        outLen += size; pos += size;
      } else if (type === 1) {
        ensure(size);
        out.fill(buf[pos], outLen, outLen + size);
        outLen += size; pos += 1;
      } else if (type === 2) {
        const end = pos + size;
        if (end > buf.length) fail('truncated block');
        const { lits, next } = readLiterals(buf, pos, end, state);
        const { seqs } = next < end ? readSequences(buf, next, end, state) : { seqs: [] };
        let li = 0;
        for (const [litLength, matchLength, offsetValue] of seqs) {
          ensure(litLength + matchLength);
          if (li + litLength > lits.length) fail('sequence takes more literals than exist');
          out.set(lits.subarray(li, li + litLength), outLen);
          li += litLength; outLen += litLength;
          let offset;
          if (offsetValue > 3) { offset = offsetValue - 3; reps = [offset, reps[0], reps[1]]; } else {
            let idx = offsetValue;
            if (litLength === 0) idx++;
            if (idx === 1) offset = reps[0];
            else if (idx === 2) { offset = reps[1]; reps = [offset, reps[0], reps[2]]; } else if (idx === 3) { offset = reps[2]; reps = [offset, reps[0], reps[1]]; } else { offset = reps[0] - 1; reps = [offset, reps[0], reps[1]]; }
          }
          if (offset < 1 || offset > outLen) fail('match offset before the start of the output');
          for (let i = 0; i < matchLength; i++) out[outLen + i] = out[outLen + i - offset];
          outLen += matchLength;
        }
        ensure(lits.length - li);
        out.set(lits.subarray(li), outLen);
        outLen += lits.length - li;
        pos = end;
      } else fail('reserved block type');
    }
    if (checksum) pos += 4;
  }
  return out.slice(0, outLen);
}
