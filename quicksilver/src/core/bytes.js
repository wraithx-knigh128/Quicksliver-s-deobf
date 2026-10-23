// Lua strings are byte sequences, not Unicode text. Internally the whole pipeline keeps them as
// "binary strings": JS strings in which every UTF-16 unit is one byte (0..255). The helpers here are
// the only place where that representation meets real text or file bytes.

const CHUNK = 0x8000;

export function bytesToBinary(bytes) {
  let out = '';
  for (let i = 0; i < bytes.length; i += CHUNK) {
    out += String.fromCharCode.apply(null, bytes.subarray(i, i + CHUNK));
  }
  return out;
}

export function binaryToBytes(bin) {
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i) & 0xff;
  return out;
}

/** Real text (e.g. from a textarea) to a binary string holding its UTF-8 encoding. */
export function textToBinary(text) {
  return bytesToBinary(new TextEncoder().encode(text));
}

/** Binary string to displayable text. Invalid UTF-8 becomes U+FFFD, so never round-trip through this. */
export function binaryToText(bin) {
  return new TextDecoder('utf-8', { fatal: false }).decode(binaryToBytes(bin));
}

/**
 * Length of the well-formed UTF-8 sequence starting at `i`, or 0 if the bytes there are not one.
 * Overlongs, surrogates and code points past U+10FFFF are rejected, like a strict decoder.
 */
export function utf8SequenceLength(bin, i) {
  const b0 = bin.charCodeAt(i);
  if (b0 < 0x80) return 1;
  const cont = (k) => {
    const c = bin.charCodeAt(i + k);
    return c >= 0x80 && c <= 0xbf;
  };
  if (b0 >= 0xc2 && b0 <= 0xdf) return cont(1) ? 2 : 0;
  if (b0 >= 0xe0 && b0 <= 0xef) {
    if (!cont(1) || !cont(2)) return 0;
    const b1 = bin.charCodeAt(i + 1);
    if (b0 === 0xe0 && b1 < 0xa0) return 0;
    if (b0 === 0xed && b1 > 0x9f) return 0;
    return 3;
  }
  if (b0 >= 0xf0 && b0 <= 0xf4) {
    if (!cont(1) || !cont(2) || !cont(3)) return 0;
    const b1 = bin.charCodeAt(i + 1);
    if (b0 === 0xf0 && b1 < 0x90) return 0;
    if (b0 === 0xf4 && b1 > 0x8f) return 0;
    return 4;
  }
  return 0;
}

/** Encode a code point as a UTF-8 binary string (used for the \u{...} escape). */
export function encodeCodePoint(cp) {
  if (cp < 0x80) return String.fromCharCode(cp);
  if (cp < 0x800) return String.fromCharCode(0xc0 | (cp >> 6), 0x80 | (cp & 0x3f));
  if (cp < 0x10000) {
    return String.fromCharCode(0xe0 | (cp >> 12), 0x80 | ((cp >> 6) & 0x3f), 0x80 | (cp & 0x3f));
  }
  return String.fromCharCode(
    0xf0 | (cp >> 18), 0x80 | ((cp >> 12) & 0x3f), 0x80 | ((cp >> 6) & 0x3f), 0x80 | (cp & 0x3f));
}

/** Share of bytes that are printable ASCII or whitespace; used to judge whether decoded data is text. */
export function printableRatio(bin) {
  if (bin.length === 0) return 1;
  let ok = 0;
  for (let i = 0; i < bin.length; i++) {
    const c = bin.charCodeAt(i);
    if (c === 9 || c === 10 || c === 13 || (c >= 32 && c < 127)) ok++;
  }
  return ok / bin.length;
}
