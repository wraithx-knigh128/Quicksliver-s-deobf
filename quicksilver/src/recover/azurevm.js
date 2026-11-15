// AzureVM (github.com/LionHub-Pino/AzureVM, MIT, read as text at 0e01e7a): its Lua 5.1 bytecode VM, read without running it.
//
// The generator compiles the script with the Lua 5.1 compiler model of Prometheus, then serialises the prototype tree:
//
//   payload  `[=[LPH>` + Ascii85 (with `z`) of a rolling byte encoding (three keys fed back by the ciphertext, the blob key a literal) ]=]
//   node     np up ms iv | om oa lm | instructions (5 bytes each) | constants (nil, boolean, double, string with a nonce) | children
//   word i   (raw + (seed + i * 1664525 + 1013904223 + prev * 37)) mod 2^34, prev the previous encoded word;
//            raw = the global opcode passed through the node's affine map `op * mul + add`, then the operands in one of three
//            layouts picked by (lm + prev % 3) % 3; operands B and C carry Bx as b + c * 512
//   strings  each byte plus a state seeded by the string key and the constant's nonce
//
// The global opcode of each standard instruction is a per-build random number in 1..250 that exists only as the dispatch table
// `D[n] = function(R, a, b, c, bx, sbx) ... end`; decoys fill other numbers. Each handler is one of the generator's 38 templates
// with the build's own names: it is matched by shape after the names are renamed in order of appearance. The program is then a
// standard Lua 5.1 chunk and goes to the decompiler.

import { walk } from '../core/walk.js';
import { parse } from '../core/parser.js';
import { print } from '../core/printer.js';
import { dumpChunk51 } from '../sandbox/bytecode.js';
import { TEMPLATES } from './azurevm-templates.js';

export class AzureVmError extends Error {}
const fail = (m) => { throw new AzureVmError(m); };
const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const numOf = (e) => { e = strip(e); if (!e) return undefined; if (e.type === 'Number') return e.value; if (e.type === 'Unary' && e.op === '-') { const v = numOf(e.arg); return v === undefined ? undefined : -v; } return undefined; };

// ---- handler shapes ------------------------------------------------------------------------------------------------

// names the templates write literally (template text, not generated identifiers)
const FIXED = new Set(['a', 'b', 'c', 'bx', 'sbx', 'i', 'pr', 'env', 'upvals', 'p', 'uv', 'n', 'g', 'r', 'l', 's', 'x', 'q', 'w', 't', 'cb', 'var', 'o',
  'op', 'pb', 'e', 'nk', 'ne', 'prev_e', 'prev_ne', 'nw', 'cbx', 'u', '_', 'type', 'pcall', 'math', 'select', 'MOVEOP']);

/** A function written with every generated name replaced in order of appearance, and the MOVE code a CLOSURE handler compares with as `MOVEOP`. */
function shape(func) {
  const names = new Map();
  const saved = [];
  walk(func, (n) => {
    if (n.type === 'Binary' && n.op === '==' && strip(n.left).type === 'Name' && strip(n.left).name === 'op' && strip(n.right).type === 'Number') {
      const r = strip(n.right);
      saved.push([r, { ...r }]);
      for (const k of Object.keys(r)) delete r[k];
      r.type = 'Name'; r.name = 'MOVEOP';
    }
    if ((n.type === 'Name' || n.type === 'Id') && !FIXED.has(n.name)) {
      if (!names.has(n.name)) names.set(n.name, `v${names.size}`);
      saved.push([n, { ...n }]);
      n.name = names.get(n.name);
    }
    return undefined;
  });
  let text;
  try { text = print({ type: 'Chunk', body: [{ type: 'Return', values: [func] }], endComments: [], features: new Set() }); } finally {
    for (const [n, old] of saved.reverse()) { for (const k of Object.keys(n)) delete n[k]; Object.assign(n, old); }
  }
  return text.replace(/\s+/g, ' ').trim();
}

let templateShapes = null;
function templates() {
  if (templateShapes) return templateShapes;
  templateShapes = new Map();
  TEMPLATES.forEach((body, std) => {
    // the RK helper and every placeholder are names of the build; MOVEOP stays as the CLOSURE handler's comparison
    const src = `return function(R,a,b,c,bx,sbx)${body}`;
    const ast = parse(src);
    const f = ast.body[0].values[0];
    templateShapes.set(shape(f), std);
  });
  return templateShapes;
}

/** `D[n] = function(R, a, b, c, bx, sbx) ... end`: global opcode -> standard opcode, and the build's MOVE code from CLOSURE. */
function readDispatch(chunk) {
  const shapes = templates();
  const byTable = new Map();
  walk(chunk, (n) => {
    if (n.type !== 'Assign' || n.targets.length !== 1 || n.values.length !== 1) return undefined;
    const t = strip(n.targets[0]); const f = strip(n.values[0]);
    if (t.type !== 'Index' || strip(t.obj).type !== 'Name' || f.type !== 'Func' || f.params.length !== 6) return undefined;
    if (f.params.slice(1).map((p) => p.name).join(',') !== 'a,b,c,bx,sbx') return undefined;
    const k = numOf(t.key);
    if (k === undefined) return undefined;
    const tn = strip(t.obj).name;
    if (!byTable.has(tn)) byTable.set(tn, []);
    byTable.get(tn).push([k, f]);
    return undefined;
  });
  const best = [...byTable.values()].sort((x, y) => y.length - x.length)[0];
  if (!best || best.length < 38) fail('the dispatch table was not found');
  const map = new Map();
  let moveOp = null;
  for (const [k, f] of best) {
    const std = shapes.get(shape(f));
    if (std === undefined) continue;                 // a decoy: it matches no template
    if ([...map.values()].includes(std)) fail(`two handlers read as Lua opcode ${std}`);
    map.set(k, std);
    if (std === 36) walk(f, (m) => { if (m.type === 'Binary' && m.op === '==' && strip(m.left).type === 'Name' && strip(m.left).name === 'op') { const v = numOf(m.right); if (v !== undefined) moveOp = v; } return undefined; });
  }
  if (map.size !== 38) fail(`only ${map.size} of the 38 handlers were recognised`);
  return { map, moveOp, decoys: best.length - 38 };
}

// ---- payload -------------------------------------------------------------------------------------------------------

function findPayload(chunk) {
  let s = null;
  walk(chunk, (n) => { if (!s && n.type === 'String' && n.value.startsWith('LPH>')) s = n.value; return undefined; });
  return s;
}

/** The literals the runtime decodes with: pad and blob key (the decode call), the string key, the VM seed, the payload checksum. */
export function findKeys(chunk) {
  const keys = {};
  // the payload decoder: a function of three parameters whose body carries the rolling-key constants
  const decoders = new Set();
  walk(chunk, (n) => {
    const f = n.type === 'LocalFunction' ? n.func : null;
    if (!f || f.params.length !== 3) return undefined;
    const nums = new Set();
    walk(f, (m) => { if (m.type === 'Number') nums.add(m.value); return undefined; });
    if ([13, 17, 29, 31].every((x) => nums.has(x))) decoders.add(n.id.name);
    return undefined;
  });
  walk(chunk, (n) => {
    // `local kseed, klm, kla, kmod = SEED, 1664525, 1013904223, 17179869184`
    if (n.type === 'Local' && n.values.length === 4 && n.values.every((v) => numOf(v) !== undefined) && numOf(n.values[1]) === 1664525) {
      [keys.seed, keys.lmul, keys.ladd, keys.lmod] = n.values.map(numOf);
    }
    // `(STR_KEY + entry[2]) % 2147483647`
    if (n.type === 'Binary' && n.op === '%' && numOf(n.right) === 2147483647) {
      const l = strip(n.left);
      if (l.type === 'Binary' && l.op === '+' && numOf(l.left) !== undefined && strip(l.right).type === 'Index' && numOf(strip(l.right).key) === 2) keys.strKey = numOf(l.left);
    }
    // `decode(payload, PAD, BKEY)`
    if (n.type === 'Call' && n.args.length === 3 && strip(n.fn).type === 'Name' && decoders.has(strip(n.fn).name) && numOf(n.args[1]) !== undefined && numOf(n.args[2]) !== undefined && keys.pad === undefined) {
      keys.pad = numOf(n.args[1]); keys.bkey = numOf(n.args[2]);
    }
    // `if B * 65536 + A ~= CHECKSUM then error(...) end`
    if (n.type === 'Binary' && n.op === '~=' && numOf(n.right) !== undefined) {
      const l = strip(n.left);
      if (l.type === 'Binary' && l.op === '+' && strip(l.left).type === 'Binary' && strip(l.left).op === '*' && numOf(strip(l.left).right) === 65536) keys.checksum = numOf(n.right);
    }
    return undefined;
  });
  for (const k of ['seed', 'lmul', 'ladd', 'lmod', 'strKey', 'pad', 'bkey']) if (keys[k] === undefined) fail(`the runtime's ${k} was not found`);
  return keys;
}

function ascii85(s) {
  const t = s.replace(/z/g, '!!!!!');
  const out = [];
  for (let i = 0; i + 5 <= t.length; i += 5) {
    let v = 0;
    for (let j = 0; j < 5; j++) v = v * 85 + (t.charCodeAt(i + j) - 33);
    out.push(Math.floor(v / 16777216) % 256, Math.floor(v / 65536) % 256, Math.floor(v / 256) % 256, v % 256);
  }
  return out;
}

function unroll(bytes, pad, bkey) {
  const bin = pad > 0 ? bytes.slice(0, bytes.length - pad) : bytes;
  const out = [];
  let k1 = bkey; let k2 = (bkey * 7 + 13) % 256; let k3 = (bkey * 31 + 17) % 256;
  const md = (x) => ((x % 256) + 256) % 256;
  for (let i = 1; i <= bin.length; i++) {
    const enc = bin[i - 1];
    const m = i % 3;
    out.push(m === 0 ? md(enc - k1 - k3 - i) : m === 1 ? md(enc + k2 - k3 + i) : md(enc - k2 + k1 - i));
    k1 = (k1 * 13 + enc) % 256;
    k2 = (k2 * 31 + 17 + i) % 256;
    k3 = (k3 * 29 + enc + 7) % 256;
  }
  return out;
}

function readNodes(b, keys) {
  let pos = 0;
  const u8 = () => { if (pos >= b.length) fail('the payload ends inside a prototype'); return b[pos++]; };
  const u32 = () => { const v = b[pos] + b[pos + 1] * 256 + b[pos + 2] * 65536 + b[pos + 3] * 16777216; pos += 4; if (pos > b.length) fail('the payload ends inside a prototype'); return v; };
  const f64 = () => { const dv = new DataView(new ArrayBuffer(8)); for (let i = 0; i < 8; i++) dv.setUint8(i, b[pos + i]); pos += 8; return dv.getFloat64(0, true); };
  const node = () => {
    const p = { np: u8(), up: u8(), ms: u8(), iv: u8(), om: u8(), oa: u8(), lm: u8(), ins: [], ks: [], ps: [] };
    const ni = u32();
    for (let i = 0; i < ni; i++) { let w = 0; for (let k = 0; k < 5; k++) w += u8() * 2 ** (8 * k); p.ins.push(w); }
    const nk = u32();
    for (let i = 0; i < nk; i++) {
      const t = u8();
      if (t === 0) p.ks.push(undefined);
      else if (t === 1) p.ks.push(u8() !== 0);
      else if (t === 3) p.ks.push(f64());
      else if (t === 4) {
        const len = u32(); const nonce = u32();
        let state = (keys.strKey + nonce) % 2147483647;
        let s = '';
        for (let x = 1; x <= len; x++) {
          const c = u8();
          s += String.fromCharCode((((c - (state % 256) - x) % 256) + 256) % 256);
          state = (state * 48271 + c + x) % 2147483647;
        }
        p.ks.push(s);
      } else fail(`a constant of unknown type ${t}`);
    }
    const nc = u32();
    for (let i = 0; i < nc; i++) p.ps.push(node());
    return p;
  };
  return node();
}

// ---- instructions --------------------------------------------------------------------------------------------------

const BX = new Set([1, 5, 7, 36]);         // LOADK GETGLOBAL SETGLOBAL CLOSURE
const SBX = new Set([22, 31, 32]);         // JMP FORLOOP FORPREP
const mod = (x, m) => ((x % m) + m) % m;

function toLua51(p, keys, map, stats) {
  const code = [];
  let prev = 0;
  let rawNext = false;
  for (let i = 1; i <= p.ins.length; i++) {
    const e = p.ins[i - 1];
    const k = (keys.seed + i * keys.lmul + keys.ladd + prev * 37) % keys.lmod;
    const w = mod(e - k, keys.lmod);
    const mode = (p.lm + prev % 3) % 3;
    let op; let a; let b; let c;
    if (mode === 0) { op = w % 256; a = Math.floor(w / 256) % 256; b = Math.floor(w / 65536) % 512; c = Math.floor(w / 33554432) % 512; }
    else if (mode === 1) { a = w % 256; op = Math.floor(w / 256) % 256; c = Math.floor(w / 65536) % 512; b = Math.floor(w / 33554432) % 512; }
    else { op = w % 256; b = Math.floor(w / 256) % 512; c = Math.floor(w / 131072) % 512; a = Math.floor(w / 67108864) % 256; }
    prev = e;
    const bx = b + c * 512;
    // the word after a SETLIST with C = 0 is the raw C
    if (rawNext) { code.push(bx); rawNext = false; continue; }
    const g = mod((op - p.oa) * p.om, 256);
    const std = map.get(g);
    if (std === undefined) fail(`instruction ${i} has opcode ${g}, which no handler implements`);
    stats.instructions++;
    let word;
    if (BX.has(std) || SBX.has(std)) word = (std | (a << 6)) + bx * 16384;
    else word = (std | (a << 6) | (c << 14)) + b * 8388608;
    code.push(word >>> 0 === word ? word : word % 4294967296);
    if (std === 34 && c === 0) rawNext = true;
  }
  stats.functions++;
  return {
    source: null, line: 0, lastLine: 0, nups: p.up, numParams: p.np, isVararg: p.iv !== 0, maxStack: Math.max(p.ms, 2),
    code, k: p.ks, protos: p.ps.map((c) => toLua51(c, keys, map, stats)),
  };
}

// ---- the whole script ----------------------------------------------------------------------------------------------

export function looksLikeAzureVM(chunk) {
  return !!findPayload(chunk);
}

/** The program as a Lua 5.1 binary chunk, and what was read. Throws AzureVmError when something is not understood. */
export function liftAzureVM(chunk) {
  const payload = findPayload(chunk);
  if (!payload) fail('no AzureVM payload');
  const keys = findKeys(chunk);
  const { map, moveOp, decoys } = readDispatch(chunk);
  if (moveOp !== null && map.get(moveOp) !== 0) fail('the CLOSURE handler compares with a code that is not MOVE');
  const bin = unroll(ascii85(payload.slice(4)), keys.pad, keys.bkey);
  if (keys.checksum !== undefined) {
    let A = 1; let B = 0;
    for (const x of bin) { A = (A + x) % 65521; B = (B + A) % 65521; }
    if (B * 65536 + A !== keys.checksum) fail('the payload does not match its checksum');
  }
  const root = readNodes(bin, keys);
  const stats = { functions: 0, instructions: 0, decoyHandlers: decoys };
  const main = toLua51(root, keys, map, stats);
  main.isVararg = true;
  const bytes = dumpChunk51({ main, header: { little: true, intSize: 4, sizeT: 8, numSize: 8 } }, { strip: true });
  return { bytes, stats };
}
