// Minimal ZIP writer (stored, no compression): enough to bundle the original input, the recovered code and
// the report into one download without shipping a library. Entries are UTF-8 named; the CRC-32 is computed
// over the exact bytes, so the original file inside the archive is byte-identical to what was opened.

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

export function crc32(bytes) {
  let c = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) c = CRC_TABLE[(c ^ bytes[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function dosDateTime(date) {
  const y = Math.max(1980, date.getFullYear());
  return {
    time: (date.getHours() << 11) | (date.getMinutes() << 5) | (date.getSeconds() >> 1),
    date: ((y - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate(),
  };
}

/**
 * @param {Array<{name: string, data: Uint8Array}>} entries
 * @returns {Uint8Array}
 */
export function makeZip(entries, date = new Date()) {
  const enc = new TextEncoder();
  const { time, date: day } = dosDateTime(date);
  const chunks = [];
  const central = [];
  let offset = 0;
  const u16 = (v, n) => { v.push(n & 0xff, (n >> 8) & 0xff); };
  const u32 = (v, n) => { v.push(n & 0xff, (n >>> 8) & 0xff, (n >>> 16) & 0xff, (n >>> 24) & 0xff); };

  for (const e of entries) {
    const name = enc.encode(e.name);
    const crc = crc32(e.data);
    const local = [];
    u32(local, 0x04034b50); u16(local, 20); u16(local, 0x0800); u16(local, 0); u16(local, time); u16(local, day);
    u32(local, crc); u32(local, e.data.length); u32(local, e.data.length); u16(local, name.length); u16(local, 0);
    chunks.push(Uint8Array.from(local), name, e.data);

    const cd = [];
    u32(cd, 0x02014b50); u16(cd, 20); u16(cd, 20); u16(cd, 0x0800); u16(cd, 0); u16(cd, time); u16(cd, day);
    u32(cd, crc); u32(cd, e.data.length); u32(cd, e.data.length); u16(cd, name.length); u16(cd, 0); u16(cd, 0);
    u16(cd, 0); u16(cd, 0); u32(cd, 0); u32(cd, offset);
    central.push(Uint8Array.from(cd), name);
    offset += local.length + name.length + e.data.length;
  }
  let cdSize = 0;
  for (const c of central) cdSize += c.length;
  const end = [];
  u32(end, 0x06054b50); u16(end, 0); u16(end, 0); u16(end, entries.length); u16(end, entries.length);
  u32(end, cdSize); u32(end, offset); u16(end, 0);
  const all = [...chunks, ...central, Uint8Array.from(end)];
  const out = new Uint8Array(offset + cdSize + end.length);
  let p = 0;
  for (const c of all) { out.set(c, p); p += c.length; }
  return out;
}
