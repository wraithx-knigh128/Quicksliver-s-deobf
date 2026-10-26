// The VM program as the runtime's deserializer reads it: a tree of prototypes, each with constants, instructions, names, a parameter count, a
// flag byte, a register count and its children. What differs from script to script is the instruction layout, which `profile` carries:
//   opMap    opcode id (16 bits, many ids per class) -> instruction class
//   layouts  class -> [[field id, format], ...] in reading order
//   constFields  field ids whose value is an index into the constants (resolved to {k, v} here)

/** @returns {{root: object, end: number, length: number}} */
export function readBlob(buf, profile) {
  const { opMap, layouts, constFields } = profile;
  let p = 0;
  const u8 = () => { if (p >= buf.length) throw new Error('blob: read past the end'); return buf[p++]; };
  const varint = () => { let acc = 0; for (let i = 0; i < 5; i++) { const b = u8(); acc += (b & 127) * 2 ** (7 * i); if (!(b & 128)) break; } return acc; };
  const rd = (fmt) => {
    if (fmt === 'B') return u8();
    const need = fmt === '<i4' ? 4 : 2;
    if (p + need > buf.length) throw new Error('blob: read past the end');
    let v;
    if (fmt === '<I2') v = buf[p] | (buf[p + 1] << 8);
    else if (fmt === '<i2') { v = buf[p] | (buf[p + 1] << 8); if (v & 0x8000) v -= 0x10000; }
    else if (fmt === '<i4') v = (buf[p] | (buf[p + 1] << 8) | (buf[p + 2] << 16) | (buf[p + 3] << 24));
    else throw new Error('blob: layout ' + fmt);
    p += need;
    return v;
  };
  const str = (n) => { if (p + n > buf.length) throw new Error('blob: read past the end'); let s = ''; for (let i = 0; i < n; i++) s += String.fromCharCode(buf[p + i]); p += n; return s; };
  const bytes = (n) => { if (p + n > buf.length) throw new Error('blob: read past the end'); const b = buf.subarray(p, p + n); p += n; return b; };
  function proto(depth = 0) {
    if (depth > 64) throw new Error('blob: prototypes nested too deep');
    const magic = u8();
    if (magic !== profile.protoMagic) {
      // a stub: two strings (an encrypted prototype and the nonce that goes with it), nothing else
      const n1 = varint(); const payload = bytes(n1);
      const n2 = varint(); const nonce = bytes(n2);
      return { stub: true, tag: magic, payload, nonce };
    }
    const nConst = varint();
    const consts = [];
    for (let i = 0; i < nConst; i++) {
      const tag = u8();
      if (tag === 1) { const n = varint(); consts.push(n ? str(n) : ''); }
      else if (tag === 2) consts.push(NaN);
      else if (tag === 5) consts.push(Infinity);
      else if (tag === 6) consts.push(-Infinity);
      else if (tag === 4) { const n = u8(); let v = 0n; const b = bytes(n); for (let k = 0; k < n; k++) v |= BigInt(b[k]) << BigInt(8 * k); if (n && (b[n - 1] & 128)) v -= 1n << BigInt(8 * n); consts.push(Number(v)); }
      else if (tag === 3) { const b = bytes(8); consts.push(new DataView(b.buffer, b.byteOffset, 8).getFloat64(0, true)); }
      else throw new Error('blob: constant tag ' + tag);
    }
    const nInstr = varint();
    const code = [];
    for (let i = 0; i < nInstr; i++) {
      const op = u8() | (u8() << 8);
      const cls = opMap[op];
      if (cls === null || cls === undefined) throw new Error('blob: opcode ' + op);
      const ins = { op, cls };
      for (const [key, fmt] of layouts[cls]) ins[key] = rd(fmt);
      code.push(ins);
    }
    const nNames = varint();
    const names = [];
    for (let i = 0; i < nNames; i++) names.push(str(varint()));
    const nparams = u8();
    const flag = u8();
    const maxreg = varint();
    for (const ins of code) for (const k of constFields) if (ins[k] !== undefined) ins[k] = ins[k] !== 0 ? { k: ins[k], v: consts[ins[k] - 1] } : 0;
    const nChild = varint();
    const children = [];
    for (let i = 0; i < nChild; i++) children.push(proto(depth + 1));
    return { consts, code, names, nparams, flag, maxreg, children };
  }
  const root = proto();
  return { root, end: p, length: buf.length };
}
