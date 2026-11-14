// MoonVeil 2.1.0: the container the program is shipped in, read without running anything.
//
// 2.1.0 is a bytecode VM again (2.0.26 was a table of factories). The bootstrap ends in
//
//     ctx.RUN(ctx.UNPACK(ctx.TEXT "<digits>"), ...)          member names differ per build (sample 6: H / v / s, sample 7: I / w / t)
//
// and each of the three is a factory in MoonVeil's table whose body, once the control flow is undone (moonveil-cff.js), reads as:
//
//   TEXT     base 85, RFC 1924 digits `0-9A-Za-z!#$%&()*+-;<=>?@^_`{|}~`, five digits to four bytes, big-endian; the text is padded with `~` to a multiple of five and the
//            padding's bytes dropped again (factories t and u of sample 6)
//   UNPACK   LZSS: a flag byte governs the next eight items, bit 1 is a literal byte, bit 0 a big-endian u16 back-reference into the last 2048 bytes written
//            (start = #window - (v >> 5) as a 1-based position, length = (v & 31) + 3); results are memoised by input (factory w)
//   RUN      the deserializer (factory L): a LEB128 count, that many strings (LEB128 length + bytes), then the function reader (factory la), which reads a marker byte
//            (a per-build constant, 192 in sample 6 and 93 in sample 7, for a function of the program; any other value is a native stub with two strings), a LEB128 instruction count and, per instruction, an opcode byte that
//            a per-build decision tree maps to one of the interpreter's handlers, followed by that handler's operands.
//
// What this module reads: the first three stages and the header of the main function. The operand layout of each handler (factory la, about 650 lines per build) is
// not read yet, so nothing here is a program: the result is evidence for the report and a fixed point for the next reader. The strings of the table are kept as
// they are; in both samples they do not read as text (`HXSIO`, `gmx`), so they are deciphered later, where they are used, and are not given out as names.

const DIGITS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~';
const VALUE = new Map([...DIGITS].map((c, i) => [c, i]));

export class Container21Error extends Error {}
const fail = (m) => { throw new Container21Error(m); };

/** Base 85 with RFC 1924 digits, as MoonVeil 2.1.0's text stage writes it. */
export function base85(text) {
  const pad = text.length % 5 ? 5 - (text.length % 5) : 0;
  const s = text + '~'.repeat(pad);
  const out = [];
  for (let i = 0; i < s.length; i += 5) {
    let v = 0;
    for (let j = 0; j < 5; j++) {
      const d = VALUE.get(s[i + j]);
      if (d === undefined) fail(`not a base-85 digit at ${i + j}: ${JSON.stringify(s[i + j])}`);
      v = v * 85 + d;
    }
    if (v > 0xffffffff) fail(`a group of five digits at ${i} is larger than four bytes`);
    out.push(Math.floor(v / 16777216) & 255, (v >>> 16) & 255, (v >>> 8) & 255, v & 255);
  }
  return Uint8Array.from(out.slice(0, out.length - pad));
}

/** LZSS as the unpack stage reads it: flag byte (bit set = literal), u16 big-endian references into a 2048-byte window. */
export function lzss(bytes) {
  const out = [];
  let i = 0;
  while (i < bytes.length) {
    let flags = bytes[i++];
    for (let k = 0; k < 8 && i < bytes.length; k++, flags >>= 1) {
      if (flags & 1) { out.push(bytes[i++]); continue; }
      if (i + 1 >= bytes.length) fail('a back-reference is cut off at the end of the data');
      const v = (bytes[i] << 8) | bytes[i + 1];
      i += 2;
      const window = Math.min(out.length, 2048);
      const off = v >> 5;
      const len = (v & 31) + 3;
      if (off >= window) fail(`a back-reference reaches ${off} bytes back, before the start of the window`);
      const start = out.length - off - 1;
      for (let q = 0; q < len; q++) out.push(out[start + q]);
    }
  }
  return Uint8Array.from(out);
}

function reader(bytes) {
  let p = 0;
  const byte = () => { if (p >= bytes.length) fail('the data ends early'); return bytes[p++]; };
  const varint = () => {
    let n = 0;
    for (let k = 0; k < 5; k++) {
      const b = byte();
      n += (b & 127) * 2 ** (7 * k);
      if (!(b & 128)) return n;
    }
    return n;
  };
  const string = () => {
    const n = varint();
    if (p + n > bytes.length) fail('a string runs past the end of the data');
    let s = '';
    for (let k = 0; k < n; k++) s += String.fromCharCode(bytes[p + k]);
    p += n;
    return s;
  };
  return { byte, varint, string, get at() { return p; }, size: bytes.length };
}

/** The three stages and the header of the main function. */
export function readContainer21(text) {
  const packed = base85(text);
  const program = lzss(packed);
  const r = reader(program);
  const count = r.varint();
  if (count > program.length) fail('the string table says it has more strings than the data has bytes');
  const strings = [];
  for (let i = 0; i < count; i++) strings.push(r.string());
  const tableEnd = r.at;
  // the marker of a function of the program is a constant of the build (192 in sample 6, 93 in sample 7); the main function is one, so its marker is that constant
  const marker = r.byte();
  const main = { marker, instructions: r.varint() };
  if (main.instructions === 0 || main.instructions > program.length) fail(`the main function says it has ${main.instructions} instructions in ${program.length} bytes`);
  return { packedBytes: packed.length, programBytes: program.length, strings, tableEnd, main, program };
}

/** `a.X(a.Y(a.Z "<base-85 text>"), ...)`: the call that starts the program, found by its shape. */
export function findContainerCall(ast, walk) {
  let found = null;
  const isMember = (f) => f && f.type === 'Index' && f.obj.type === 'Name' && f.key.type === 'String';
  walk(ast, (n) => {
    if (found || n.type !== 'Call' || !isMember(n.fn) || !n.args[0] || n.args[0].type !== 'Call') return undefined;
    const mid = n.args[0];
    if (!isMember(mid.fn) || !mid.args[0] || mid.args[0].type !== 'Call') return undefined;
    const inner = mid.args[0];
    const s = inner.args[0];
    if (!isMember(inner.fn) || !s || s.type !== 'String' || s.value.length < 20 || ![...s.value].every((c) => VALUE.has(c))) return undefined;
    found = { run: n.fn.key.value, unpack: mid.fn.key.value, text: inner.fn.key.value, data: s.value };
    return false;
  });
  return found;
}
