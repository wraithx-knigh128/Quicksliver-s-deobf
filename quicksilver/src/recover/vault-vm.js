// Vault-Obf (github.com/polarr-is67/Vault-Obfuscator, read as text at 4cf9664): its register VM, read without running it.
//
// The generator compiles the program to a 41-opcode register IR (`[op, a, b, c, d, e]` per instruction) and embeds:
//
//   * a payload table Q of blobs. Each blob is `D("<base-45 digits with a continuation flag, over a per-build 90-character
//     alphabet>", delta)`, `BIN("\206<fmt><key><bytes>")` (zig-zag LEB128 or fixed 2/4-byte fields, every byte rotated by
//     the key) or a plain table literal. A blob may be scattered: its string is the concatenation of locals defined among
//     decoy words.
//   * Q[1] the decode parameters: LCG a, c, m, s0, stride, string shift, integer multiplier and offset, instruction-delta
//     multiplier, modulus and per-field step, the permutation of the eight constant tags, and (strong builds) a string
//     xor key and the operand-order permutation.
//   * Q[3] metamethod keys, Q[4] error messages, Q[5] metadata, Q[6..] one record per prototype: header (params, vararg,
//     maxstack, code words, constant words, checksum, constant mode, grouped flag), children, upvalue pairs, code, constants,
//     and (the `scrambled` family) the physical order of the instructions.
//   * an interpreter whose opcode numbers are a per-build permutation. Handlers are fixed templates; only identifiers, the
//     dispatch (cascade, tree, table of closures, or a table reached through a remap blob) and the field access (one word
//     stream, or six parallel arrays) differ. A handler's meaning is read off its body; the arithmetic ones differ only in
//     the helper they call, whose own body says which operator it is.
//
// Everything here is arithmetic on literals: nothing of the script runs. What is not understood refuses the lift.

import { analyze } from '../core/scope.js';
import { walk } from '../core/walk.js';
import { print } from '../core/printer.js';
import { structure, CfgError } from '../decompile/cfg.js';

export class VaultVmError extends Error {}
const fail = (m) => { throw new VaultVmError(m); };
const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };

export const OPCODES = ['LOADCONST', 'LOADNIL', 'LOADBOOL', 'MOVE', 'LOADGLOBAL', 'STOREGLOBAL', 'GETUPVAL', 'SETUPVAL', 'ADD', 'SUB', 'MUL', 'DIV',
  'MOD', 'POW', 'EDIV', 'CONCAT', 'NEG', 'NOT', 'LEN', 'EQ', 'LT', 'LE', 'JMP', 'JMPIFTRUE', 'JMPIFFALSE', 'FCHECK', 'FADD', 'CALL', 'RETURN',
  'RETURNDYN', 'RETURNMIX', 'GETTABLE', 'SETTABLE', 'NEWTABLE', 'CLOSURE', 'VARARG', 'GETRET', 'MARK', 'NOP', 'ISTBL', 'ISTRG'];

// ---- constants of the script ---------------------------------------------------------------------------------------

/** The value of a literal expression: strings (also concatenated, also through locals that hold one), numbers. */
function makeEval(info) {
  const memo = new Map();
  const ev = (e) => {
    e = strip(e);
    if (!e) return undefined;
    switch (e.type) {
      case 'String': return e.value;
      case 'Number': return e.value;
      case 'Unary': { if (e.op !== '-') return undefined; const v = ev(e.arg); return typeof v === 'number' ? -v : undefined; }
      case 'Binary': {
        const l = ev(e.left); const r = ev(e.right);
        if (l === undefined || r === undefined) return undefined;
        if (e.op === '..') return String(l) + String(r);
        if (typeof l !== 'number' || typeof r !== 'number') return undefined;
        switch (e.op) { case '+': return l + r; case '-': return l - r; case '*': return l * r; default: return undefined; }
      }
      case 'Name': {
        const v = info.varOf.get(e);
        if (!v || v.isGlobal || v.writes.length || !v.init) return undefined;
        if (memo.has(v)) return memo.get(v);
        memo.set(v, undefined);
        const x = ev(v.init);
        memo.set(v, x);
        return x;
      }
      default: return undefined;
    }
  };
  return ev;
}

// ---- blobs ---------------------------------------------------------------------------------------------------------

const RADIX = 45;
export function decodeAlpha(s, alphabet, k) {
  const rv = new Map();
  for (let i = 0; i < alphabet.length; i++) rv.set(alphabet.charCodeAt(i), i);
  const out = [];
  let i = 0;
  while (i < s.length) {
    let ac = 0;
    let mv = 1;
    for (;;) {
      const bp = rv.get(s.charCodeAt(i++));
      if (bp === undefined) fail('a payload character outside the alphabet');
      ac += (bp % RADIX) * mv;
      if (bp < RADIX) break;
      mv *= RADIX;
    }
    const xv = ac % 2 === 0 ? ac / 2 : -(ac + 1) / 2;
    out.push(xv - (k || 0));
  }
  return out;
}

export function decodeBinary(s) {
  if (s.charCodeAt(0) !== 206) fail('a binary blob without its marker');
  const fmt = s.charCodeAt(1) % 4;
  const k = s.charCodeAt(2);
  const b = (i) => (s.charCodeAt(i) + k) % 256;
  const out = [];
  let i = 3;
  const zz = (z) => (z % 2 === 0 ? z / 2 : -(z + 1) / 2);
  if (fmt === 1 || fmt === 2) {
    const w = fmt === 2 ? 4 : 2;
    while (i < s.length) {
      let z = 0;
      for (let m = 0; m < w; m++) z += b(i + m) * 256 ** m;
      i += w;
      out.push(zz(z));
    }
  } else {
    while (i < s.length) {
      let r = 0; let sh = 0;
      for (;;) {
        const x = b(i++);
        r += (x % 128) * 2 ** sh;
        sh += 7;
        if (x < 128) break;
      }
      out.push(zz(r));
    }
  }
  return out;
}

/** The 90-character alphabet the base-45 decoder carries: a string of 90 distinct printable characters. */
function findAlphabet(chunk, ev) {
  let found = null;
  walk(chunk, (n) => {
    if (found || n.type !== 'Local' || n.ids.length !== 1 || n.values.length !== 1) return undefined;
    const v = ev(n.values[0]);
    if (typeof v === 'string' && v.length === 2 * RADIX && new Set(v).size === v.length && /^[\x21-\x7e]+$/.test(v)) found = v;
    return undefined;
  });
  return found;
}

/** The payload: `local Q = { params, { muls, salts, sums }, { n, keys }, { n, messages }, metadata, proto... }`. */
function findPayload(chunk) {
  let found = null;
  const isBlob = (e) => { e = strip(e); return e && (e.type === 'Call' || e.type === 'Table'); };
  walk(chunk, (n) => {
    if (found) return false;
    if (n.type !== 'Local' || n.ids.length !== 1 || n.values.length !== 1) return undefined;
    const t = strip(n.values[0]);
    if (!t || t.type !== 'Table' || t.fields.length < 6 || t.fields.some((f) => f.kind !== 'item')) return undefined;
    const it = t.fields.map((f) => strip(f.value));
    if (it[0].type !== 'Call' || it[1].type !== 'Table' || it[1].fields.length !== 3 || it[2].type !== 'Table' || it[2].fields.length !== 2) return undefined;
    if (it.slice(5).some((x) => x.type !== 'Table' || x.fields.length < 5 || !x.fields.every((f) => isBlob(f.value)))) return undefined;
    found = { decl: n, items: it };
    return false;
  });
  return found;
}

// ---- the payload ---------------------------------------------------------------------------------------------------

export function decodePayload(chunk) {
  const info = analyze(chunk);
  const ev = makeEval(info);
  const p = findPayload(chunk);
  if (!p) fail('no Vault payload table');
  const alphabet = findAlphabet(chunk, ev);
  const blob = (e) => {
    e = strip(e);
    if (e.type === 'Table') {
      return e.fields.map((f) => { const v = ev(f.value); if (typeof v !== 'number') fail('a plain payload list with something else than numbers'); return v; });
    }
    if (e.type !== 'Call' || e.args.length < 1) fail('a payload entry that is not a blob');
    const s = ev(e.args[0]);
    if (typeof s !== 'string') fail('a blob whose text could not be read');
    if (s.length >= 3 && s.charCodeAt(0) === 206 && s.charCodeAt(1) < 4) return decodeBinary(s);
    if (!alphabet) fail('a printable blob without the alphabet to read it');
    const k = e.args.length > 1 ? ev(e.args[1]) : 0;
    return decodeAlpha(s, alphabet, typeof k === 'number' ? k : 0);
  };
  const it = p.items;
  const P = blob(it[0]);
  if (P.length < 19) fail('the decode parameters are too short');
  const [A, C, M, S0, ST, SH, IM, IA, CMUL, CMOD, FST] = P;
  const tagPerm = P.slice(11, 19);
  const TR = new Map(tagPerm.map((v, i) => [v, i]));
  const SX = P[20];               // only in builds with per-prototype constant modes
  const CW = P.slice(21, 27);
  const lcg = (s) => (s * A + C) % M;

  const constant = (kb, bi, m) => {
    const tg = TR.get(kb[bi++]);
    if (tg === 0) return [{ t: 'nil' }, bi];
    if (tg === 1) return [{ t: 'bool', v: false }, bi];
    if (tg === 2) return [{ t: 'bool', v: true }, bi];
    if (tg === 3) {
      const v = kb[bi++];
      if (m === 1) return [{ t: 'num', v: (v + IA) / IM }, bi];
      if (m === 2) return [{ t: 'num', v: (v - IA - SX) / IM }, bi];
      return [{ t: 'num', v: (v - IA) / IM }, bi];
    }
    if (tg === 5) {
      const len = kb[bi++];
      const bytes = [];
      for (let u = 0; u < len; u++) {
        let bv = (kb[bi++] + SH) % 256;
        if (bv < 0) bv += 256;
        if (m === 1) bv = ((bv - SX) % 256 + 256) % 256;
        bytes.push(bv);
      }
      if (m === 2) bytes.reverse();
      return [{ t: 'str', v: String.fromCharCode(...bytes) }, bi];
    }
    if (tg === 6) {
      const n2 = m === 1 ? kb[bi + 1] : kb[bi];
      const d2 = m === 1 ? kb[bi] : kb[bi + 1];
      return [{ t: 'num', v: n2 / d2 }, bi + 2];
    }
    if (tg === 7) return [{ t: 'num', v: kb[bi] }, bi + 1];
    return fail(`a constant with an unknown tag (${kb[bi - 1]})`);
  };

  // error messages (Q[4]): `{ count, blob }`, decoded with the record decoder (mode 0)
  const record = (idx) => {
    const r = it[idx - 1];
    const cnt = ev(r.fields[0].value);
    const B = blob(r.fields[1].value);
    const out = [];
    let bi = 0;
    for (let z = 0; z < cnt; z++) { const [v, nbi] = constant(B, bi, 0); out.push(v); bi = nbi; }
    return out;
  };
  let messages = [];
  try { messages = record(4).map((x) => (x.t === 'str' ? x.v : null)); } catch { messages = []; }

  const protos = [];
  for (let i = 6; i <= it.length; i++) {
    const rec = it[i - 1].fields.map((f) => strip(f.value));
    const h = blob(rec[0]);
    const children = blob(rec[1]);
    const upv = blob(rec[2]);
    const kb2 = blob(rec[3]);
    const kb = blob(rec[4]);
    const order = rec[5] ? blob(rec[5]) : [];
    const [params, vararg, maxstack, nb, , , cm, cgrp] = h;
    const nk = h[4];
    // constants
    const consts = [];
    let bi = 0;
    for (let z = 0; z < nk && bi < kb.length; z++) { const [v, nbi] = constant(kb, bi, cm); consts.push(v); bi = nbi; }
    // instruction words
    const cd = new Array(nb);
    let s = (S0 + i * ST) % M;
    for (let wi = 0; wi < nb; wi += 6) {
      s = lcg(s);
      let dlt = ((s * CMUL) % M) % CMOD;
      const lst = Math.min(wi + 5, nb - 1);
      if (cgrp === 1 && lst === wi + 5) {
        for (let kz = 0; kz < 6; kz++) { cd[wi + CW[kz]] = kb2[wi + kz] - dlt; dlt = (dlt + FST) % CMOD; }
      } else {
        for (let z = wi; z <= lst; z++) { cd[z] = kb2[z] - dlt; dlt = (dlt + FST) % CMOD; }
      }
    }
    const groups = [];
    for (let g = 0; g * 6 < nb; g++) groups.push(cd.slice(g * 6, g * 6 + 6));
    // the scrambled family stores instructions in a shuffled physical order: logical i is physical order[i]
    const code = order.length ? order.map((ph) => groups[ph - 1]) : groups;
    if (code.some((g) => !g)) fail('an instruction order that points outside the code');
    const upvals = [];
    for (let z = 0; z + 1 < upv.length; z += 2) upvals.push({ instack: upv[z] === 1, idx: upv[z + 1] });
    protos.push({ index: i - 5, params, vararg: vararg === 1, maxstack, consts, code, children, upvals });
  }
  return { protos, messages, params: { tagPerm, grouped: CW }, alphabet: !!alphabet, info, payload: p, ev, blob };
}

// ---- the interpreter's handlers ------------------------------------------------------------------------------------

/** What a value helper computes, from its own `return x OP y, true` (or `return x == y`). */
export function helperKind(f) {
  const ps = f.params.map((p) => p.name);
  let kind = null;
  const isP = (e, i) => { e = strip(e); return e && e.type === 'Name' && e.name === ps[i]; };
  walk({ type: 'Chunk', body: f.body }, (n) => {
    if (kind || n.type !== 'Return') return undefined;
    const v = n.values.map(strip);
    if (v.length === 2 && v[1].type === 'True') {
      const x = v[0];
      if (x.type === 'Binary' && isP(x.left, 0) && isP(x.right, 1)) kind = { '+': 'ADD', '-': 'SUB', '*': 'MUL', '/': 'DIV', '%': 'MOD', '^': 'POW', '<': 'LT', '<=': 'LE' }[x.op] || null;
      else if (x.type === 'Binary' && x.op === '..') kind = 'CONCAT';
      else if (x.type === 'Unary' && x.op === '-' && isP(x.arg, 0)) kind = 'NEG';
      else if (x.type === 'Unary' && x.op === '#' && isP(x.arg, 0)) kind = 'LEN';
    } else if (v.length === 1 && v[0].type === 'Binary' && v[0].op === '==' && isP(v[0].left, 0) && isP(v[0].right, 1) && ps.length === 2) {
      // `return x == y` closes the equality helper (after the metamethod path)
      const last = f.body[f.body.length - 1];
      if (last === n) kind = 'EQ';
    }
    return undefined;
  });
  // the register write: `function(I, r, v) local c = I[o][r]; if c then c[1] = v end; I[k][r] = v end`
  if (!kind && ps.length === 3) {
    const last = f.body[f.body.length - 1];
    if (last && last.type === 'Assign' && last.targets.length === 1 && strip(last.targets[0]).type === 'Index' && isP(last.values[0], 2)) kind = 'WREG';
  }
  return kind;
}

/** Every function bound to a name in the script, by variable. */
export function functionsByVar(chunk, info) {
  const out = new Map();
  walk(chunk, (n) => {
    if (n.type === 'LocalFunction') out.set(info.varOf.get(n.id), n.func);
    else if (n.type === 'Local' || n.type === 'Assign') {
      const ts = n.type === 'Local' ? n.ids : n.targets;
      ts.forEach((t, i) => { const v = n.values[i] && strip(n.values[i]); if (v && v.type === 'Func' && (t.type === 'Id' || t.type === 'Name')) { const w = info.varOf.get(t); if (w) out.set(w, v); } });
    }
    return undefined;
  });
  return out;
}

const FIELD = { ca: 'A', cb: 'B', cc: 'C', cq: 'D', ce: 'E', a2: 'A', b2: 'B', c2: 'C', d2: 'D', e2: 'E' };

/** The handler written with its operands as A..E, the value helpers by what they compute and every other generated name as `_`. */
export function canonical(body, info, kinds) {
  const nodes = [];
  const swap = (n, name) => { nodes.push([n, { ...n }]); for (const k of Object.keys(n)) delete n[k]; n.type = 'Name'; n.name = name; };
  // collect first (the walk must not see half-rewritten nodes)
  const todo = [];
  walk({ type: 'Chunk', body }, (n) => {
    if (n.type === 'Index' && strip(n.obj).type === 'Name' && strip(n.obj).name === 'cd' && strip(n.key).type === 'Name' && FIELD[strip(n.key).name] && /2$/.test(strip(n.key).name)) { todo.push([n, FIELD[strip(n.key).name]]); return false; }
    if (n.type === 'Name') {
      if (FIELD[n.name] && !/2$/.test(n.name)) { todo.push([n, FIELD[n.name]]); return undefined; }
      const v = info.varOf.get(n);
      if (v && kinds.has(v)) todo.push([n, `H_${kinds.get(v)}`]);
      else if (v && !v.isGlobal && /^v\d+$|^[A-Za-z_]\w*$/.test(n.name) && !TEMPLATE_LOCALS.has(n.name)) todo.push([n, '_']);
    }
    return undefined;
  });
  for (const [n, name] of todo) swap(n, name);
  let text;
  try { text = print({ type: 'Chunk', body, endComments: [], features: new Set() }); } finally {
    for (const [n, old] of nodes.reverse()) { for (const k of Object.keys(n)) delete n[k]; Object.assign(n, old); }
  }
  return text.replace(/\s+/g, ' ').trim();
}
// names the handler templates write literally (template text, not generated identifiers)
const TEMPLATE_LOCALS = new Set(['I', 'cd', 'cs', 'regs', 'sk', 'av', 'rv', 'ok', 'xv', 'yv', 'iv', 'lv', 'sv', 'cv', 'nv', 'rres', 'blk', 'nn2', 'fn2', 'rn', 'er', 'i',
  'fro', 'bag', 'nwrgs', 'oum', 'tmod', 'md', 'ft', 'box', 'p2', 'n2f', 'rg2', 'vr2', 'av3', 'res2', 'rn2', 'cb', 'tt', 'nn', 'kv2', 'cel', 'opn', 'upcv',
  'zi', 'desc', 'ii', 'kk', 'cell', 'pr', 'FL', 'ip', 'ph']);

/** code -> handler body, for the four dispatch strategies. */
export function findHandlers(chunk, info, ev, blobOf) {
  const out = new Map();
  // table / indirect: `T[k] = function(I, cd, cs, regs, sk) ... end`
  const tables = new Map();
  walk(chunk, (n) => {
    if (n.type !== 'Assign' || n.targets.length !== 1 || n.values.length !== 1) return undefined;
    const t = strip(n.targets[0]); const f = strip(n.values[0]);
    if (t.type !== 'Index' || strip(t.obj).type !== 'Name' || f.type !== 'Func' || f.params.length !== 5) return undefined;
    const k = ev(t.key);
    if (typeof k !== 'number') return undefined;
    const tv = info.varOf.get(strip(t.obj));
    if (!tables.has(tv)) tables.set(tv, new Map());
    tables.get(tv).set(k, f.body);
    return undefined;
  });
  if (tables.size) {
    const [tv, map] = [...tables].sort((x, y) => y[1].size - x[1].size)[0];
    // indirect: `T[(op and RM[op + 1]) or 0]`, RM a blob mapping code + 1 to the key
    let rm = null;
    walk(chunk, (n) => {
      if (rm || n.type !== 'Index' || strip(n.obj).type !== 'Name' || info.varOf.get(strip(n.obj)) !== tv) return undefined;
      const k = strip(n.key);
      if (k.type === 'Binary' && k.op === 'or' && strip(k.left).type === 'Binary' && strip(k.left).op === 'and') {
        const ix = strip(strip(k.left).right);
        if (ix.type === 'Index' && strip(ix.obj).type === 'Name') {
          const rv = info.varOf.get(strip(ix.obj));
          if (rv && rv.init) rm = blobOf(rv.init);
        }
      }
      return undefined;
    });
    if (rm) rm.forEach((key, code) => { if (map.has(key)) out.set(code, map.get(key)); });
    else for (const [k, b] of map) out.set(k, b);
    if (out.size) return { handlers: out, strategy: rm ? 'indirect' : 'table' };
  }
  // cascade / tree: `if op == k then BODY` (the variable compared most often is the opcode)
  const counts = new Map();
  const clauses = [];
  walk(chunk, (n) => {
    if (n.type !== 'If') return undefined;
    for (const cl of n.clauses) {
      const c = strip(cl.cond);
      if (c.type !== 'Binary' || c.op !== '==' || strip(c.left).type !== 'Name') continue;
      const k = ev(c.right);
      if (typeof k !== 'number') continue;
      const v = info.varOf.get(strip(c.left));
      counts.set(v, (counts.get(v) || 0) + 1);
      clauses.push([v, k, cl.body]);
    }
    return undefined;
  });
  const opVar = [...counts].sort((x, y) => y[1] - x[1])[0];
  if (!opVar || opVar[1] < 30) fail('the interpreter dispatch was not found');
  for (const [v, k, b] of clauses) if (v === opVar[0] && !out.has(k)) out.set(k, b);
  return { handlers: out, strategy: 'cascade' };
}

/** The `do ... end` a handler template is, without the operand fetch a closure handler starts with. */
export function handlerBlock(body) {
  for (let i = body.length - 1; i >= 0; i--) if (body[i].type === 'Do') return body[i].body;
  return body;
}

/** What a handler does, from its canonical text. */
export function classify(c) {
  const t = c.trim();
  const W = (x) => new RegExp(`^H_WREG\\(I, A, ${x}\\)$`);
  if (t === '' || t === 'do end' || c === 'do end') return 'NOP';
  if (W('cs\\[B \\+ 1\\]').test(t)) return 'LOADCONST';
  if (W('nil').test(t)) return 'LOADNIL';
  if (W('B == 1').test(t)) return 'LOADBOOL';
  if (W('regs\\[B\\]').test(t)) return 'MOVE';
  if (W('_\\[cs\\[B \\+ 1\\]\\]').test(t)) return 'LOADGLOBAL';
  if (/^_\[cs\[B \+ 1\]\] = regs\[A\]$/.test(t)) return 'STOREGLOBAL';
  if (W('I\\[_\\]\\[B\\]\\[1\\]').test(t)) return 'GETUPVAL';
  if (/cv\.regs\[cv\.idx\] = nv/.test(t)) return 'SETUPVAL';
  let m = /^local rv, ok = H_(ADD|SUB|MUL|DIV|MOD|POW|CONCAT|LT|LE)\(regs\[B\], regs\[C\]\) if ok then H_WREG\(I, A, rv\)/.exec(t);
  if (m) return m[1];
  m = /^local rv, ok = H_(NEG|LEN)\(regs\[B\]\) if ok then H_WREG\(I, A, rv\)/.exec(t);
  if (m) return m[1];
  if (/^local xv = regs\[B\] local yv = regs\[C\] if _\(xv\) and _\(yv\) then H_WREG\(I, A, _\(xv \/ yv\)\)/.test(t)) return 'EDIV';
  if (W('not regs\\[B\\]').test(t)) return 'NOT';
  if (W("_\\(regs\\[B\\]\\) == 'table'").test(t) || W('_\\(regs\\[B\\]\\) == "table"').test(t)) return 'ISTBL';
  if (W("_\\(regs\\[B\\]\\) == 'string'").test(t) || W('_\\(regs\\[B\\]\\) == "string"').test(t)) return 'ISTRG';
  if (W('H_EQ\\(regs\\[B\\], regs\\[C\\]\\)').test(t)) return 'EQ';
  const JT = '(D \\* 6 \\+ 1|D \\+ 1)';
  const GO = `I\\[_\\] = ${JT};?( av = 1| return 1)`;
  if (new RegExp(`^${GO}$`).test(t)) return 'JMP';
  if (new RegExp(`^if regs\\[A\\] then ${GO} end$`).test(t)) return 'JMPIFTRUE';
  if (new RegExp(`^if not regs\\[A\\] then ${GO} end$`).test(t)) return 'JMPIFFALSE';
  if (/^local iv = regs\[A\] local lv = regs\[B\] local sv = regs\[C\]/.test(t) && /sv > 0 and iv > lv/.test(t)) return 'FCHECK';
  if (W('regs\\[A\\] \\+ regs\\[B\\]').test(t)) return 'FADD';
  if (/local oum = E local tmod = oum >= 3 local md = oum % 3/.test(t)) return 'CALL';
  if (/^local rres = \{\} local blk = A local nn2 = B for i = 1, nn2 do rres\[i\] = regs\[blk \+ i - 1\] end _\(I, rres, nn2, sk\)/.test(t)) return 'RETURN';
  if (/^_\(I, I\[_\], I\[_\], sk\);?( av = 1| return 1)$/.test(t)) return 'RETURNDYN';
  if (/^local blk = A local fn2 = B local rn = I\[_\]/.test(t) && /rres\[fn2 \+ i\] = er\[i\]/.test(t)) return 'RETURNMIX';
  if (W('regs\\[B\\]\\[regs\\[C\\]\\]').test(t)) return 'GETTABLE';
  if (/^regs\[A\]\[regs\[B\]\] = regs\[C\]$/.test(t)) return 'SETTABLE';
  if (W('\\{\\}').test(t)) return 'NEWTABLE';
  if (/^local p2 = _\[B\] local kv2 = p2\.kv/.test(t)) return 'CLOSURE';
  if (/^local vr2 = I\[_\] if B == 1 then H_WREG\(I, A, vr2\[1\]\) else I\[_\] = vr2;? I\[_\] = #vr2 end$/.test(t)) return 'VARARG';
  if (W('I\\[_\\]\\[B\\]').test(t)) return 'GETRET';
  return null;
}

/** code -> opcode name for the build, or a refusal. */
export function opcodeMap(chunk, d) {
  const blobOf = (e) => { try { return d.blob(e); } catch { return null; } };
  const { handlers, strategy } = findHandlers(chunk, d.info, d.ev, blobOf);
  const kinds = new Map();
  for (const [v, f] of functionsByVar(chunk, d.info)) { const k = helperKind(f); if (k) kinds.set(v, k); }
  const map = new Map();
  const unknown = [];
  for (const [code, body] of handlers) {
    const name = classify(canonical(handlerBlock(body), d.info, kinds));
    if (name) map.set(code, name); else unknown.push(code);
  }
  // each meaning once (MARK and NOP are both empty and mean the same)
  const seen = new Map();
  for (const [code, name] of map) { if (name !== 'NOP') { if (seen.has(name)) fail(`opcodes ${seen.get(name)} and ${code} both read as ${name}`); seen.set(name, code); } }
  return { map, unknown, strategy };
}

// ---- lifting -------------------------------------------------------------------------------------------------------

const N = (name) => ({ type: 'Name', name });
const num = (value) => (value < 0 || Object.is(value, -0) ? { type: 'Unary', op: '-', arg: { type: 'Number', value: -value, raw: null } } : { type: 'Number', value, raw: null });
const str = (value) => ({ type: 'String', value, raw: null });
const call = (fn, args) => ({ type: 'Call', fn: typeof fn === 'string' ? N(fn) : fn, args });
const idx = (obj, key) => ({ type: 'Index', obj, key, dot: false });
const assign = (targets, values) => ({ type: 'Assign', targets, values });
const bin = (op, left, right) => ({ type: 'Binary', op, left, right });
const IDENT = /^[A-Za-z_][A-Za-z0-9_]*$/;
const RESERVED = new Set(['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while']);
const BINOPS = { ADD: '+', SUB: '-', MUL: '*', DIV: '/', MOD: '%', POW: '^', CONCAT: '..', EQ: '==', LT: '<', LE: '<=' };
// instructions that neither run code nor read anything code could change: a call may be written after them
const QUIET = new Set(['LOADCONST', 'LOADNIL', 'LOADBOOL', 'MOVE', 'NEWTABLE', 'NOP', 'MARK', 'CLOSURE']);

/** Registers an instruction reads and writes, and whether it reads or sets the list of results (`E`). */
function facts(ins) {
  const { op, a, b, c, d, e } = ins;
  const range = (base, n) => Array.from({ length: Math.max(0, n) }, (_, i) => base + i);
  switch (op) {
    case 'LOADCONST': case 'LOADNIL': case 'LOADBOOL': case 'LOADGLOBAL': case 'GETUPVAL': case 'NEWTABLE': case 'CLOSURE': return { use: [], def: [a] };
    case 'MOVE': case 'NEG': case 'NOT': case 'LEN': case 'ISTBL': case 'ISTRG': return { use: [b], def: [a] };
    case 'STOREGLOBAL': case 'SETUPVAL': case 'JMPIFTRUE': case 'JMPIFFALSE': return { use: [a], def: [] };
    case 'FCHECK': return { use: [a, b, c], def: [] };
    case 'FADD': return { use: [a, b], def: [a] };
    case 'GETTABLE': return { use: [b, c], def: [a] };
    case 'SETTABLE': return { use: [a, b, c], def: [] };
    case 'CALL': return { use: [a, ...range(b, c)], def: e % 3 === 1 || (e % 3 === 2 && d !== 0) ? [d] : [], eUse: e >= 3, eDef: e % 3 === 2 };
    case 'RETURN': return { use: range(a, b), def: [] };
    case 'RETURNDYN': return { use: [], def: [], eUse: true };
    case 'RETURNMIX': return { use: range(a, b), def: [], eUse: true };
    case 'VARARG': return { use: [], def: b === 1 ? [a] : [], eDef: b !== 1 };
    case 'GETRET': return { use: [], def: [a], eUse: true };
    default: if (BINOPS[op] || op === 'EDIV') return { use: [b, c], def: [a] }; return { use: [], def: [] };
  }
}
const ENDS = new Set(['JMP', 'RETURN', 'RETURNDYN', 'RETURNMIX']);
const BRANCH = new Set(['JMPIFTRUE', 'JMPIFFALSE', 'FCHECK']);

class Lifter {
  constructor(d, opmap) {
    this.d = d; this.opmap = opmap;
    this.helpers = new Set();
    this.fnCount = 0;
    this.byIndex = new Map(d.protos.map((p) => [p.index, p]));
    this.lifted = 0;
    this.repaired = 0;
    this.unrepaired = 0;
  }

  value(k) {
    if (!k) return fail('a constant that does not exist');
    if (k.t === 'nil') return { type: 'Nil' };
    if (k.t === 'bool') return { type: k.v ? 'True' : 'False' };
    if (k.t === 'str') return str(k.v);
    if (Number.isNaN(k.v)) return bin('/', num(0), num(0));
    if (!Number.isFinite(k.v)) return bin('/', num(k.v > 0 ? 1 : -1), num(0));
    return num(k.v);
  }

  /**
   * Vault's generator shuffles a prototype's upvalue descriptors and builds the index remap for GETUPVAL/SETUPVAL, but never applies it
   * (bytecode/generator.py, _emit_proto / _emit_instruction): a closure with two or more upvalues reads the wrong ones, and the build fails
   * or computes something else. The original numbering is not stored. It is restored only on evidence: what the closure does with each
   * upvalue (calls it, indexes it, computes with it) against what each captured variable holds in the parent (a table it built, a function,
   * a number or a string constant). When the build's own order contradicts that evidence and exactly one other order agrees with it, that
   * order is used; otherwise the closure is lifted as the build runs it.
   */
  repairOrder(child, parent, parentCode) {
    const n = child.upvals.length;
    if (n < 2 || n > 6) return null;
    const ccode = child.code.map((w) => ({ op: this.opmap.get(w[0]), a: w[1], b: w[2], c: w[3], d: w[4], e: w[5] }));
    // what the closure does with upvalue k: follow the register it is loaded into to its first use
    const usage = Array.from({ length: n }, () => new Set());
    ccode.forEach((ins, i) => {
      if (ins.op !== 'GETUPVAL' || ins.b >= n) return;
      const r = ins.a;
      for (let j = i + 1; j < ccode.length; j++) {
        const x = ccode[j];
        const f = facts(x);
        let use = null;
        if (x.op === 'CALL' && x.a === r) use = 'call';
        else if ((x.op === 'GETTABLE' && x.b === r) || (x.op === 'SETTABLE' && x.a === r)) use = 'index';
        else if (['ADD', 'SUB', 'MUL', 'DIV', 'MOD', 'POW', 'EDIV', 'NEG', 'FADD'].includes(x.op) && f.use.includes(r)) use = 'arith';
        else if (x.op === 'CONCAT' && f.use.includes(r)) use = 'concat';
        else if (x.op === 'LEN' && x.b === r) use = 'len';
        else if ((x.op === 'LT' || x.op === 'LE') && f.use.includes(r)) use = 'compare';
        if (use) { usage[ins.b].add(use); break; }
        if (f.use.includes(r) || f.def.includes(r) || x.op === 'JMP' || BRANCH.has(x.op) || ENDS.has(x.op)) break;
      }
    });
    // what each captured parent register holds when the closure is made: the definition that reaches the CLOSURE in straight-line code
    // (a register is reused for other values elsewhere, so only the reaching definition says anything)
    const pk = parent.consts;
    const targets = new Set();
    parentCode.forEach((x) => { if (x.op === 'JMP' || BRANCH.has(x.op)) targets.add(x.d); });
    const kindAt = (r, at, depth = 0) => {
      if (depth > 6) return 'unknown';
      for (let q = at - 1; q >= 0; q--) {
        const x = parentCode[q];
        if (facts(x).def.includes(r)) {
          if (x.op === 'MOVE') return kindAt(x.b, q, depth + 1);
          if (x.op === 'NEWTABLE') return 'table';
          if (x.op === 'CLOSURE') return 'function';
          if (x.op === 'LOADCONST') { const k = pk[x.b]; return k ? (k.t === 'num' ? 'number' : k.t === 'str' ? 'string' : 'unknown') : 'unknown'; }
          if (['ADD', 'SUB', 'MUL', 'DIV', 'MOD', 'POW', 'EDIV', 'NEG', 'LEN', 'FADD'].includes(x.op)) return 'number';
          if (x.op === 'CONCAT') return 'string';
          return 'unknown';
        }
        if (targets.has(q) || x.op === 'JMP' || BRANCH.has(x.op) || ENDS.has(x.op)) return 'unknown';
      }
      return 'unknown';
    };
    const closureAt = parentCode.findIndex((x) => x.op === 'CLOSURE' && x.b === child.index);
    const kinds = child.upvals.map((u) => (u.instack && closureAt >= 0 ? kindAt(u.idx, closureAt) : 'unknown'));
    const ALLOWED = { table: ['index', 'len'], function: ['call'], number: ['arith', 'concat', 'compare'], string: ['index', 'concat', 'len', 'arith', 'compare'] };
    const fits = (k, j) => kinds[j] === 'unknown' || [...usage[k]].every((u) => ALLOWED[kinds[j]].includes(u));
    const ok = (pm) => pm.every((j, k) => fits(k, j));
    const ident = Array.from({ length: n }, (_, i) => i);
    const perms = (arr) => (arr.length <= 1 ? [arr] : arr.flatMap((x, i) => perms([...arr.slice(0, i), ...arr.slice(i + 1)]).map((q) => [x, ...q])));
    const good = perms(ident).filter(ok);
    // the order is known only when the evidence leaves one: otherwise the closure is lifted as the build runs it, and counted as undetermined
    if (good.length !== 1) { this.unrepaired++; return null; }
    if (good[0].every((j, k) => j === k)) return null;
    this.repaired++;
    return good[0];
  }

  global(name) {
    if (IDENT.test(name) && !RESERVED.has(name)) return N(name);
    return idx(call('getfenv', []), str(name));
  }

  // upNames: one name per upvalue as the closure's descriptors list them; perm: which descriptor the function's upvalue k is (identity:
  // what the build does)
  proto(pindex, upNames, perm = null) {
    const p = this.byIndex.get(pindex);
    if (!p) fail(`a closure of prototype ${pindex}, which the payload does not have`);
    this.lifted++;
    const fid = ++this.fnCount;
    const code = p.code.map((w, pc) => {
      const op = this.opmap.get(w[0]);
      if (!op) fail(`opcode ${w[0]} has no handler that was understood`);
      return { pc, op: op === 'MARK' ? 'NOP' : op, a: w[1], b: w[2], c: w[3], d: w[4], e: w[5] };
    });
    const used = new Set();
    const R = (r) => { used.add(r); return N(`r${fid}_${r}`); };
    const slot = (k) => (perm ? perm[k] : k);
    const up = (k) => { const n = upNames[slot(k)]; if (!n) fail('an upvalue the closure was not given'); return N(n); };
    const K = (b) => p.consts[b];
    const fx = code.map(facts);

    // blocks
    const leaders = new Set([0]);
    code.forEach((ins) => {
      if (ins.op === 'JMP' || BRANCH.has(ins.op)) leaders.add(ins.d);
      if (ENDS.has(ins.op) || BRANCH.has(ins.op)) leaders.add(ins.pc + 1);
    });
    const starts = [...leaders].filter((x) => x >= 0 && x < code.length).sort((x, y) => x - y);
    const blocks = starts.map((s, i) => ({ start: s, end: (starts[i + 1] ?? code.length) - 1 }));

    // the next read of the result list after `from`, in code order, before it is set again (a list is always read right after it is made)
    const nextEUse = (from) => {
      for (let q = from + 1; q < code.length; q++) { if (fx[q].eUse) return q; if (fx[q].eDef) return -1; }
      return -1;
    };
    const readsOf = (exprs) => { const s = new Set(); for (const x of exprs) walk({ type: 'Chunk', body: [{ type: 'Return', values: [x] }] }, (m) => { if (m.type === 'Name') { const k = new RegExp(`^r${fid}_(\\d+)$`).exec(m.name); if (k) s.add(Number(k[1])); } return undefined; }); return s; };

    let E = null;          // { expr } a list of values not yet written anywhere, or { name } a list kept in a local
    let eN = 0;
    const eVars = [];
    const listOfE = () => {
      if (!E) fail('a result list read before any was made');
      if (E.expr) { const x = E.expr; E = { used: true }; return [x]; }
      if (E.name) { this.helpers.add('unpack'); return [call('__unpack', [N(E.name)])]; }
      return fail('a result list read twice');
    };
    const keepE = (expr, put) => {
      const name = `e${fid}_${++eN}`;
      eVars.push(name);
      this.helpers.add('pack');
      put(assign([N(name)], [call('__pack', [expr])]));
      E = { name };
      return name;
    };

    const out = new Map();
    let condN = 0;
    const condVars = [];
    for (const b of blocks) {
      const stmts = [];
      const put = (s) => stmts.push(s);
      const set = (r, e) => put(assign([R(r)], [e]));
      let term = null;
      let skipTo = -1;
      for (let pc = b.start; pc <= b.end; pc++) {
        if (pc <= skipTo) continue;
        const ins = code[pc];
        const { op, a, c, d, e } = ins;
        const bb = ins.b;
        // a list that will be read once, by the instruction that is about to use it, is written there
        const produceList = (expr, firstInto) => {
          const j = nextEUse(pc);
          // `local x, y = f()`: GETRETs of the first, second ... results right after
          if (j === pc + 1 && firstInto === null) {
            const targets = [];
            let q = pc + 1;
            while (q <= b.end && code[q].op === 'GETRET' && code[q].b === targets.length + 1) { targets.push(code[q].a); q++; }
            if (targets.length && new Set(targets).size === targets.length && nextEUse(q - 1) === -1) {
              put(assign(targets.map((x) => R(x)), [expr]));
              E = { used: true };
              skipTo = q - 1;
              return;
            }
          }
          if (firstInto === null && j > pc && j <= b.end && ['CALL', 'RETURNDYN', 'RETURNMIX'].includes(code[j].op) && nextEUse(j) === -1) {
            const reads = readsOf([expr]);
            let ok = true;
            for (let q = pc + 1; q < j && ok; q++) {
              if (!QUIET.has(code[q].op)) ok = false;
              if (fx[q].def.some((x) => reads.has(x))) ok = false;
            }
            // the consumer's own operands are read before the list it appends
            if (ok) { E = { expr }; return; }
          }
          keepE(expr, put);
          if (firstInto !== null) set(firstInto, idx(N(E.name), num(1)));
        };
        switch (op) {
          case 'LOADCONST': set(a, this.value(K(bb))); break;
          case 'LOADNIL': set(a, { type: 'Nil' }); break;
          case 'LOADBOOL': set(a, { type: bb === 1 ? 'True' : 'False' }); break;
          case 'MOVE': set(a, R(bb)); break;
          case 'LOADGLOBAL': { const k = K(bb); if (!k || k.t !== 'str') fail('a global whose name is not a string'); set(a, this.global(k.v)); break; }
          case 'STOREGLOBAL': { const k = K(bb); if (!k || k.t !== 'str') fail('a global whose name is not a string'); put(assign([this.global(k.v)], [R(a)])); break; }
          case 'GETUPVAL': set(a, up(bb)); break;
          case 'SETUPVAL': put(assign([up(bb)], [R(a)])); break;
          case 'NEG': set(a, { type: 'Unary', op: '-', arg: R(bb) }); break;
          case 'NOT': set(a, { type: 'Unary', op: 'not', arg: R(bb) }); break;
          case 'LEN': set(a, { type: 'Unary', op: '#', arg: R(bb) }); break;
          case 'ISTBL': set(a, bin('==', call('type', [R(bb)]), str('table'))); break;
          case 'ISTRG': set(a, bin('==', call('type', [R(bb)]), str('string'))); break;
          case 'EDIV': set(a, call({ type: 'Index', obj: N('math'), key: str('floor'), dot: true }, [bin('/', R(bb), R(c))])); break;
          case 'FADD': set(a, bin('+', R(a), R(bb))); break;
          case 'GETTABLE': set(a, idx(R(bb), R(c))); break;
          case 'SETTABLE': put(assign([idx(R(a), R(bb))], [R(c)])); break;
          case 'NEWTABLE': set(a, { type: 'Table', fields: [] }); break;
          case 'NOP': break;
          case 'CALL': {
            const args = [];
            for (let i = 0; i < c; i++) args.push(R(bb + i));
            if (e >= 3) args.push(...listOfE());
            const ce = call(R(a), args);
            const md = e % 3;
            if (md === 0) put({ type: 'CallStmt', call: ce });
            else if (md === 1) set(d, ce);
            else produceList(ce, d !== 0 ? d : null);
            break;
          }
          case 'VARARG':
            if (bb === 1) set(a, { type: 'Paren', expr: { type: 'Vararg' } });
            else produceList({ type: 'Vararg' }, null);
            break;
          case 'GETRET': {
            if (!E || !E.name) fail('a single result taken from a list that is not kept');
            set(a, idx(N(E.name), num(bb)));
            break;
          }
          case 'RETURN': { const vals = []; for (let i = 0; i < bb; i++) vals.push(R(a + i)); term = { kind: 'return', values: vals }; break; }
          case 'RETURNDYN': term = { kind: 'return', values: listOfE() }; break;
          case 'RETURNMIX': { const vals = []; for (let i = 0; i < bb; i++) vals.push(R(a + i)); term = { kind: 'return', values: [...vals, ...listOfE()] }; break; }
          case 'CLOSURE': {
            const child = this.byIndex.get(bb);
            if (!child) fail('a closure of a prototype the payload does not have');
            const names = child.upvals.map((u) => (u.instack ? (used.add(u.idx), `r${fid}_${u.idx}`) : (upNames[slot(u.idx)] || fail('an upvalue the closure was not given'))));
            set(a, this.proto(bb, names, this.repairOrder(child, p, code)));
            break;
          }
          case 'JMP': term = { kind: 'goto', to: d }; break;
          case 'JMPIFTRUE': case 'JMPIFFALSE': {
            const cv = `c${fid}_${++condN}`;
            condVars.push(cv);
            put(assign([N(cv)], [R(a)]));
            term = op === 'JMPIFTRUE' ? { kind: 'branch', cond: N(cv), t: d, f: pc + 1 } : { kind: 'branch', cond: N(cv), t: pc + 1, f: d };
            break;
          }
          case 'FCHECK': {
            const msg = this.d.messages[6] || "'for' step is zero";
            put({ type: 'If', clauses: [{ cond: bin('==', R(c), num(0)), body: [{ type: 'CallStmt', call: call('error', [str(msg)]) }] }], orelse: null });
            const done = bin('or', { type: 'Paren', expr: bin('and', bin('>', R(c), num(0)), bin('>', R(a), R(bb))) }, { type: 'Paren', expr: bin('and', bin('<', R(c), num(0)), bin('<', R(a), R(bb))) });
            const cv = `c${fid}_${++condN}`;
            condVars.push(cv);
            put(assign([N(cv)], [done]));
            term = { kind: 'branch', cond: N(cv), t: d, f: pc + 1 };
            break;
          }
          default:
            if (BINOPS[op]) { set(a, bin(BINOPS[op], R(bb), R(c))); break; }
            fail(`an instruction this tool does not lift: ${op}`);
        }
        if (term) break;
      }
      if (E && E.expr) fail('a result list was left unused at the end of a block');
      if (!term) term = b.end + 1 < code.length ? { kind: 'goto', to: b.end + 1 } : { kind: 'return', values: null };
      out.set(b.start, { stmts, term });
    }
    let body;
    try {
      body = structure(out, 0, {
        negate: (cnd) => (cnd.type === 'Unary' && cnd.op === 'not' ? cnd.arg : { type: 'Unary', op: 'not', arg: cnd.type === 'Binary' ? { type: 'Paren', expr: cnd } : cnd }),
        makeReturn: (values) => ({ type: 'Return', values: values || [] }),
      });
    } catch (err) {
      if (err instanceof CfgError) fail(`function ${fid}: ${err.message}`);
      throw err;
    }
    const last = body[body.length - 1];
    if (last && last.type === 'Return' && !last.values.length) body.pop();
    const params = [];
    for (let i = 0; i < p.params; i++) params.push({ type: 'Id', name: `r${fid}_${i}` });
    const locals = [...used].filter((r) => r >= p.params).sort((x, y) => x - y).map((r) => `r${fid}_${r}`);
    const decl = [...locals, ...eVars, ...condVars];
    const head = decl.length ? [{ type: 'Local', ids: decl.map((n) => ({ type: 'Id', name: n })), values: [] }] : [];
    return { type: 'Func', params, vararg: p.vararg, body: [...head, ...body] };
  }
}

/** `RUN(PT[main], {}, 0, {})`: the call that starts the program, and which prototype it starts. */
function findRunSite(chunk, ev) {
  let site = null;
  walk(chunk, (n) => {
    if (n.type !== 'Call' || n.args.length !== 4) return undefined;
    const [p, t1, z, t2] = n.args.map(strip);
    if (p.type === 'Index' && t1.type === 'Table' && !t1.fields.length && t2.type === 'Table' && !t2.fields.length && ev(z) === 0) {
      const k = ev(p.key);
      if (typeof k === 'number') site = { node: n, main: k };
    }
    return undefined;
  });
  return site;
}

export function looksLikeVault(chunk) {
  try { return !!findPayload(chunk); } catch { return false; }
}

/** Lift the script. Returns { body, stats }; throws VaultVmError when something is not understood. */
export function liftVault(chunk) {
  const d = decodePayload(chunk);
  const { map, unknown, strategy } = opcodeMap(chunk, d);
  const site = findRunSite(chunk, d.ev);
  if (!site) fail('the call that starts the program was not found');
  const lifter = new Lifter(d, map);
  const main = lifter.proto(site.main, []);
  const helpers = [];
  if (lifter.helpers.has('pack')) helpers.push({ type: 'LocalFunction', id: { type: 'Id', name: '__pack' }, func: { type: 'Func', params: [], vararg: true, body: [{ type: 'Return', values: [{ type: 'Table', fields: [{ kind: 'named', key: 'n', value: call('select', [str('#'), { type: 'Vararg' }]) }, { kind: 'item', value: { type: 'Vararg' } }] }] }] } });
  if (lifter.helpers.has('unpack')) helpers.push({ type: 'LocalFunction', id: { type: 'Id', name: '__unpack' }, func: { type: 'Func', params: [{ type: 'Id', name: 't' }], vararg: false, body: [{ type: 'Return', values: [call({ type: 'Paren', expr: bin('or', N('unpack'), { type: 'Index', obj: N('table'), key: str('unpack'), dot: true }) }, [N('t'), num(1), { type: 'Index', obj: N('t'), key: str('n'), dot: true }])] }] } });
  chunk.body = [...helpers, ...main.body];
  return { changed: lifter.lifted, stats: { functions: lifter.lifted, payloadPrototypes: d.protos.length, opcodes: map.size, unknownOpcodes: unknown, dispatch: strategy, upvalueOrderRepaired: lifter.repaired, upvalueOrderUnresolved: lifter.unrepaired } };
}
