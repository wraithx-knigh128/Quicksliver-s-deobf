// Doubles or Lua 5.4 integers?
//
// The sandbox computes with doubles, as Lua 5.1 and Luau do. Lua 5.4 has 64-bit integers, so a script that multiplies past 2^53
// (a string decryptor built on a linear congruential generator, say) produces different numbers there, and different text.
// The interpreter can count such results ('watch') and can compute them exactly ('int64'). Which of the two a script was
// written for cannot be read off the script, so when they disagree the answer is taken from the text they produce: bytes that
// were decrypted correctly read as text, bytes that were not look like noise.

/** Printable ASCII, whitespace, or well-formed UTF-8 (the argument is a binary string holding bytes). */
export function readsAsText(s) {
  let i = 0;
  while (i < s.length) {
    const c = s.charCodeAt(i);
    if (c === 9 || c === 10 || c === 13 || (c >= 32 && c < 127)) { i++; continue; }
    const need = c >= 0xf0 && c < 0xf5 ? 3 : c >= 0xe0 && c < 0xf0 ? 2 : c >= 0xc2 && c < 0xe0 ? 1 : -1;
    if (need < 0 || i + need >= s.length) return false;
    for (let k = 1; k <= need; k++) { const d = s.charCodeAt(i + k); if (d < 0x80 || d > 0xbf) return false; }
    i += need + 1;
  }
  return true;
}
