// Read the scripts out of a Roblox model file (.rbxm binary, .rbxmx XML).
//
// Why this is here: a loader of the form `require(<assetId>)` or `game:GetObjects("rbxassetid://…")` loads a *model*, not Lua text. When the
// owner retrieves that model through Roblox's documented Asset Delivery API (docs/API-CATALOGUE.md), or opens a model file they have, the
// program is the `Source` of the Script / LocalScript / ModuleScript instances inside it. This module extracts those, with their path in the
// model tree, so each one can go through the reconstruction pipeline as its own stage. Nothing is executed.
//
// Format references (community documentation of Roblox's format, checked against real Studio output in rojo-rbx/rbx-test-files, MIT):
//   binary: magic "<roblox!" + 89 FF 0D 0A 1A 0A, u16 version, i32 class count, i32 instance count, 8 reserved bytes; then chunks
//           { name[4], u32 compressed length, u32 uncompressed length, u32 reserved } whose data is an LZ4 block when the compressed length
//           is non-zero. INST (class id, class name, object format, count, referents), PROP (class id, property name, type id, one value
//           per instance), PRNT (child → parent referents), END. Integer arrays are byte-interleaved big-endian, zig-zag encoded, and
//           referents are delta-encoded.
//   XML:    <roblox> <Item class="…" referent="…"> <Properties> <string name="Name">…</string> <ProtectedString name="Source">…
//
// Limits (reported, not guessed): ZSTD-compressed chunks are recognised and reported as unsupported; property types other than strings are
// skipped, because only names and sources are needed.

export class RbxError extends Error {}

const SCRIPT_CLASSES = new Set(['Script', 'LocalScript', 'ModuleScript']);
const MAGIC = [0x3c, 0x72, 0x6f, 0x62, 0x6c, 0x6f, 0x78, 0x21]; // "<roblox!"
const SIG = [0x89, 0xff, 0x0d, 0x0a, 0x1a, 0x0a];

/** Is this a model file, and which kind? */
export function modelKind(bytes) {
  if (bytes.length >= 14 && MAGIC.every((b, i) => bytes[i] === b) && SIG.every((b, i) => bytes[8 + i] === b)) return 'rbxm';
  const head = String.fromCharCode(...bytes.subarray(0, Math.min(bytes.length, 512)));
  if (/^\s*(<\?xml[^>]*>\s*)?<roblox[\s>]/.test(head) && !head.startsWith('<roblox!')) return 'rbxmx';
  return null;
}

/** LZ4 block decompression (no frame header). `out` length is known from the chunk header. */
export function lz4Block(src, outLen) {
  const out = new Uint8Array(outLen);
  let i = 0;
  let o = 0;
  while (i < src.length) {
    const token = src[i++];
    let lit = token >> 4;
    if (lit === 15) { let b; do { b = src[i++]; lit += b; } while (b === 255 && i < src.length); }
    if (o + lit > outLen || i + lit > src.length) throw new RbxError('LZ4: literal run past the end');
    out.set(src.subarray(i, i + lit), o);
    i += lit; o += lit;
    if (i >= src.length) break;                                   // the last sequence has literals only
    const off = src[i] | (src[i + 1] << 8);
    i += 2;
    if (off === 0 || off > o) throw new RbxError('LZ4: bad match offset');
    let len = token & 15;
    if (len === 15) { let b; do { b = src[i++]; len += b; } while (b === 255 && i < src.length); }
    len += 4;
    if (o + len > outLen) throw new RbxError('LZ4: match past the end');
    for (let k = 0; k < len; k++, o++) out[o] = out[o - off];    // overlapping copies are byte by byte on purpose
  }
  if (o !== outLen) throw new RbxError(`LZ4: produced ${o} bytes, expected ${outLen}`);
  return out;
}

class Reader {
  constructor(b) { this.b = b; this.i = 0; this.dv = new DataView(b.buffer, b.byteOffset, b.byteLength); }
  need(n) { if (this.i + n > this.b.length) throw new RbxError('model data ends early'); }
  u8() { this.need(1); return this.b[this.i++]; }
  u32() { this.need(4); const v = this.dv.getUint32(this.i, true); this.i += 4; return v; }
  bytes(n) { this.need(n); const v = this.b.subarray(this.i, this.i + n); this.i += n; return v; }
  str() { const n = this.u32(); return utf8(this.bytes(n)); }
  /** byte-interleaved, big-endian, zig-zag i32 array */
  ints(count) {
    this.need(count * 4);
    const out = new Array(count);
    for (let k = 0; k < count; k++) {
      const v = ((this.b[this.i + k] << 24) | (this.b[this.i + count + k] << 16) | (this.b[this.i + 2 * count + k] << 8) | this.b[this.i + 3 * count + k]) >>> 0;
      out[k] = (v >>> 1) ^ -(v & 1);
    }
    this.i += count * 4;
    return out;
  }
  refs(count) { const d = this.ints(count); let acc = 0; return d.map((x) => (acc += x)); }
}

const utf8 = (bytes) => new TextDecoder('utf-8', { fatal: false }).decode(bytes);

function readBinary(bytes) {
  const r = new Reader(bytes);
  r.i = 14;
  const version = r.u8() | (r.u8() << 8);
  if (version !== 0) throw new RbxError(`unknown binary model version ${version}`);
  r.u32(); r.u32(); r.bytes(8);
  const classes = new Map();          // classId -> { name, refs }
  const props = new Map();            // referent -> { Name, Source }
  const parent = new Map();
  const notes = [];
  while (r.i < bytes.length) {
    const name = String.fromCharCode(...r.bytes(4)).replace(/\0+$/, '');
    const clen = r.u32();
    const ulen = r.u32();
    r.u32();
    let data;
    if (clen === 0) data = r.bytes(ulen);
    else {
      const raw = r.bytes(clen);
      if (raw[0] === 0x28 && raw[1] === 0xb5 && raw[2] === 0x2f && raw[3] === 0xfd) throw new RbxError('this model uses ZSTD-compressed chunks, which this reader does not decode yet');
      data = lz4Block(raw, ulen);
    }
    if (name === 'END') break;
    const c = new Reader(data);
    if (name === 'INST') {
      const id = c.u32();
      const cls = c.str();
      const format = c.u8();
      const count = c.u32();
      classes.set(id, { name: cls, refs: c.refs(count), format });
    } else if (name === 'PROP') {
      const id = c.u32();
      const prop = c.str();
      const type = c.u8();
      const cls = classes.get(id);
      if (!cls || (prop !== 'Name' && prop !== 'Source')) continue;
      // strings (0x01) are a u32 length and the bytes, one per instance; ProtectedString is written the same way
      if (type !== 0x01 && type !== 0x1d) { notes.push(`${cls.name}.${prop}: property type 0x${type.toString(16)} not read`); continue; }
      const start = c.i;
      try {
        for (const ref of cls.refs) {
          const p = props.get(ref) || {};
          p[prop] = c.str();
          props.set(ref, p);
        }
      } catch (e) { c.i = start; notes.push(`${cls.name}.${prop}: ${e.message}`); }
    } else if (name === 'PRNT') {
      c.u8();
      const n = c.u32();
      const kids = c.refs(n);
      const pars = c.refs(n);
      kids.forEach((k, j) => parent.set(k, pars[j]));
    }
  }
  const instances = [];
  for (const cls of classes.values()) for (const ref of cls.refs) instances.push({ ref, className: cls.name, ...(props.get(ref) || {}) });
  return { instances, parent, notes };
}

// ---- XML ----------------------------------------------------------------------------------------------------------------------------------
const ENT = { lt: '<', gt: '>', amp: '&', quot: '"', apos: "'" };
const unescape = (s) => s.replace(/&(#x[0-9a-f]+|#\d+|\w+);/gi, (m, e) => (e[0] === '#' ? String.fromCodePoint(e[1] === 'x' || e[1] === 'X' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10)) : ENT[e] ?? m));

function readXml(text) {
  const instances = [];
  const parent = new Map();
  const stack = [];
  let n = 0;
  const re = /<Item\b([^>]*)>|<\/Item>|<(string|ProtectedString)\s+name="(Name|Source)"\s*>([\s\S]*?)<\/\2>|<(string|ProtectedString)\s+name="(Name|Source)"\s*\/>/g;
  let m;
  while ((m = re.exec(text))) {
    if (m[0].startsWith('<Item')) {
      const cls = /class="([^"]*)"/.exec(m[1]);
      const inst = { ref: n++, className: cls ? cls[1] : '?' };
      if (stack.length) parent.set(inst.ref, stack[stack.length - 1].ref);
      stack.push(inst);
      instances.push(inst);
    } else if (m[0] === '</Item>') {
      stack.pop();
    } else if (stack.length) {
      const top = stack[stack.length - 1];
      const prop = m[3] || m[6];
      const raw = m[4] ?? '';
      const cdata = /^\s*<!\[CDATA\[([\s\S]*?)\]\]>\s*$/.exec(raw);
      top[prop] = cdata ? cdata[1] : unescape(raw);
    }
  }
  return { instances, parent, notes: [] };
}

/**
 * Extract the scripts of a model file.
 * @param {Uint8Array} bytes
 * @returns {{ kind: 'rbxm'|'rbxmx', instances: number, scripts: Array<{ className, name, path, source }>, notes: string[] }}
 */
export function extractScripts(bytes) {
  const kind = modelKind(bytes);
  if (!kind) throw new RbxError('not a Roblox model file');
  const model = kind === 'rbxm' ? readBinary(bytes) : readXml(utf8(bytes));
  const byRef = new Map(model.instances.map((x) => [x.ref, x]));
  const pathOf = (inst) => {
    const parts = [];
    for (let cur = inst, guard = 0; cur && guard < 256; guard++) {
      parts.unshift(cur.Name || cur.className);
      const p = model.parent.get(cur.ref);
      cur = p == null || p < 0 ? null : byRef.get(p);
    }
    return parts.join('.');
  };
  const scripts = model.instances
    .filter((x) => SCRIPT_CLASSES.has(x.className))
    .map((x) => ({ className: x.className, name: x.Name || x.className, path: pathOf(x), source: x.Source ?? '' }));
  return { kind, instances: model.instances.length, scripts, notes: model.notes, paths: model.instances.map((x) => `${pathOf(x)}:${x.className}`).sort() };
}
