// Obscura's virtual machine, lifted back to source (https://github.com/vo3pal/obscura, MIT; the VM layer of the revisions 1.0.1 and 1.1.0).
//
// The VM is a register machine close to Lua 5.1 with three differences: captured locals live in one-slot "boxes" (MKBOX / GETBOX / SETBOX), jumps are byte offsets, and every
// build draws its own opcode bytes (several aliases per operation), encrypts the instruction bytes with a repeating XOR key, and writes the interpreter out as a chain of `if op == a or
// op == b then ... end` handlers. Only the operations the program uses get a handler.
//
// Nothing here is a table of opcode numbers. What is read is the interpreter the script carries:
//
//   1. every handler is taken apart into the operands it reads (`local x = d(bc[pc]) + d(bc[pc + 1]) * 256`) and the rest of its body;
//   2. the rest is written in a canonical form in which every name is replaced by the order it first appears in (the operands by the order they are first USED, so that a build which
//      shuffles the order the operands are stored in writes the same text), and
//   3. that text is recognised: `R[x] = R[y][R[z]]` with x, y, z the 1st, 2nd and 3rd operand used is GETTABLE, whatever the build called its variables and numbered its opcodes.
//
// The program's functions are then decoded with the script's own key, every instruction becomes the Lua 5.1 instruction of the same meaning (a box is the variable it stands for,
// a byte offset is an instruction offset), and the result is handed to the decompiler that already reads IronBrew 2 and Hercules chunks. A handler no rule recognises makes the
// function that uses it fail with its text, rather than be guessed at.

import { print } from '../core/printer.js';
import { dumpChunk51 } from '../sandbox/bytecode.js';
import { encode, maxStack } from './ironbrew.js';
import { bodyOf, fieldOf, unparen, contains } from './vmprofile.js';

export class ObscuraVmError extends Error {}
const fail = (m) => { throw new ObscuraVmError(m); };

const clone = (x) => JSON.parse(JSON.stringify(x));
const text = (stmts) => print({ type: 'Chunk', body: stmts, endComments: [], features: new Set() }).replace(/\s*\n\s*/g, ' ').replace(/([(\[]) /g, '$1').replace(/ ([)\]])/g, '$1').trim();
const exprText = (e) => text([{ type: 'Return', values: [e] }]).replace(/^return /, '');
const STD = new Set(['math', 'string', 'table', 'select', 'type', 'unpack', 'error', 'pcall', 'tostring', 'tonumber', 'ipairs', 'pairs', 'setmetatable', 'getmetatable', 'rawget', 'rawset', 'next']);

const find = (n, f, out = []) => {
  if (!n || typeof n !== 'object') return out;
  if (Array.isArray(n)) { n.forEach((x) => find(x, f, out)); return out; }
  if (f(n)) out.push(n);
  for (const k of Object.keys(n)) if (k !== 'line') find(n[k], f, out);
  return out;
};

// ---- the interpreter ------------------------------------------------------------------------------------------------------------

/** The function that runs one prototype: a `while true do` whose body is a long chain of tests on the opcode. */
export function findInterpreter(body) {
  for (const s of body) {
    const loops = find(s, (n) => n.type === 'While' && unparen(n.cond).type === 'True');
    for (const w of loops) {
      const chain = find(w.body, (m) => m.type === 'If' && m.clauses.length >= 8)[0];
      if (chain) return { loop: w, chain, stmt: s };
    }
  }
  return null;
}

/** `local op = X(bc[pc], KEY[(pc - 1) % n + 1])` ahead of the chain: the decoder, the key and the names of the program counter and the byte list. */
export function readFetch(loop) {
  for (const s of loop.body) {
    if (s.type !== 'Local' || s.ids.length !== 1 || s.values.length !== 1) continue;
    const t = text([s]);
    const m = /^local (\S+) = (\S+)\((\S+)\[(\S+)\], (\S+)\[\(\4 - 1\) % (\S+) \+ 1\]\)$/.exec(t);
    if (m) return { op: m[1], decoder: m[2], bytes: m[3], pc: m[4], key: m[5], keyLen: m[6] };
  }
  return null;
}

/** An operand read: `local x = d(bc[pc]) + d(bc[pc + 1]) * 256` (optionally `- 32768`), followed by `pc = pc + 2`. */
const READ = /^local (\S+) = (\S+)\((\S+)\[(.+?)\], (\S+)\[.*?\]\) \+ \2\(\3\[.+?\], \5\[.*?\]\) \* 256( - 32768)?$/;

export function splitHandler(stmts, fetch) {
  const reads = [];
  const rest = [];
  for (let i = 0; i < stmts.length; i++) {
    const s = stmts[i];
    const t = s.type === 'Local' && s.ids.length === 1 ? text([s]) : '';
    const m = t && READ.exec(t);
    if (m && m[2] === fetch.decoder && m[3] === fetch.bytes) {
      reads.push({ name: s.ids[0].name, signed: !!m[6] });
      const nx = stmts[i + 1];
      if (nx && text([nx]) === `${fetch.pc} = ${fetch.pc} + 2`) i++;
      continue;
    }
    rest.push(s);
  }
  return { reads, rest };
}

/** The body written with the operands numbered by first use and every other name by first appearance. Returns {text, order} with order[rank] = index of the operand read. */
export function canonical(rest, reads) {
  const body = clone(rest);
  const rank = new Map();
  const order = [];
  const names = new Map();
  let n = 0;
  const byName = new Map(reads.map((r, i) => [r.name, i]));
  const visit = (x) => {
    if (!x || typeof x !== 'object') return;
    if (Array.isArray(x)) { x.forEach(visit); return; }
    if ((x.type === 'Name' || x.type === 'Id') && typeof x.name === 'string') {
      if (byName.has(x.name)) {
        const idx = byName.get(x.name);
        if (!rank.has(idx)) { rank.set(idx, order.length); order.push(idx); }
        x.name = `${reads[idx].signed ? 'S' : '$'}${rank.get(idx)}`;
      } else if (!STD.has(x.name) && !/^[$S]\d+$/.test(x.name)) {
        if (!names.has(x.name)) names.set(x.name, `v${++n}`);
        x.name = names.get(x.name);
      }
    }
    for (const k of Object.keys(x)) if (k !== 'line') visit(x[k]);
  };
  visit(body);
  return { text: text(body).replace(/v(\d+)\((\$\d+ \+ 1)\)/g, 'v$1[$2]'), order };
}

/**
 * What each handler body is. A template is written with the operands numbered in the order they are STORED (`$0` first, `S` for the signed ones, the plain-layout order); at load it is
 * rewritten the way a body is canonicalised (operands numbered by first use), so that the same template matches a build that shuffled the order of its operands. `fields` says which
 * stored operand is which field of the Lua instruction. `prefix` templates match the start of the body (the long ones differ in their tails by how many results they unpack).
 */
const TEMPLATES = [
  ['', 'NOP', {}],
  ['v1[$0] = {}', 'NEWTABLE', { A: '$0' }],
  ['v1 = v1 + S0', 'JMP', { sBx: 'S0' }],
  ['v1[$0] = v1[$1]', 'MOVE', { A: '$0', B: '$1' }],
  ['v1[$0] = -v1[$1]', 'UNM', { A: '$0', B: '$1' }],
  ['v1[$0] = #(v1[$1])', 'LEN', { A: '$0', B: '$1' }],
  ['v1[$0] = not v1[$1]', 'NOT', { A: '$0', B: '$1' }],
  ['v1[$0] = v1[$1][1]', 'GETBOX', { A: '$0', B: '$1' }],
  ['v1[$0][1] = v1[$1]', 'SETBOX', { A: '$0', B: '$1' }],
  ['v1[$0] = { v1[$1] }', 'MKBOX', { A: '$0', B: '$1' }],
  ['v1[$0] = v2[$1 + 1]', 'LOADK', { A: '$0', B: '$1' }],
  ['v1[$0] = v2[$1 + 1][1]', 'GETUPVAL', { A: '$0', B: '$1' }],
  ['v1[$1 + 1][1] = v2[$0]', 'SETUPVAL', { A: '$0', B: '$1' }],
  ['v1[$0] = v2[v3[$1 + 1]]', 'GETGLOBAL', { A: '$0', B: '$1' }],
  ['v1[v2[$1 + 1]] = v3[$0]', 'SETGLOBAL', { A: '$0', B: '$1' }],
  ['v1[$0][v1[$1]] = v1[$2]', 'SETTABLE', { A: '$0', B: '$1', C: '$2' }],
  ['v1[$0] = v1[$1][v1[$2]]', 'GETTABLE', { A: '$0', B: '$1', C: '$2' }],
  ['v1[$0] = v1[$1][v2[$2 + 1]]', 'GETTABLEK', { A: '$0', B: '$1', C: '$2' }],
  ['v1[$0][v2[$1 + 1]] = v1[$2]', 'SETTABLEK', { A: '$0', B: '$1', C: '$2' }],
  ['v1[$0 + 1] = v1[$1] v1[$0] = v1[$1][v2[$2 + 1]]', 'SELF', { A: '$0', B: '$1', C: '$2' }],
  ['v1[$0] = v1[$1] + v1[$2]', 'ADD', { A: '$0', B: '$1', C: '$2' }],
  ['v1[$0] = v1[$1] - v1[$2]', 'SUB', { A: '$0', B: '$1', C: '$2' }],
  ['v1[$0] = v1[$1] * v1[$2]', 'MUL', { A: '$0', B: '$1', C: '$2' }],
  ['v1[$0] = v1[$1] / v1[$2]', 'DIV', { A: '$0', B: '$1', C: '$2' }],
  ['v1[$0] = v1[$1] % v1[$2]', 'MOD', { A: '$0', B: '$1', C: '$2' }],
  ['v1[$0] = v1[$1] ^ v1[$2]', 'POW', { A: '$0', B: '$1', C: '$2' }],
  ['for v1 = $0, $0 + $1 do v2[v1] = nil end', 'LOADNIL', { A: '$0', B: '$1' }],
  ['local v1 = v2[$1] for v3 = $1 + 1, $2 do v1 = v1 .. v2[v3] end v2[$0] = v1', 'CONCAT', { A: '$0', B: '$1', C: '$2' }],
  ['v1[$0] = ($1 ~= 0) if $2 ~= 0 then', 'LOADBOOL', { A: '$0', B: '$1', C: '$2' }, true],
  ['if (v1[$1] == v1[$2]) ~= ($0 ~= 0) then', 'EQ', { A: '$0', B: '$1', C: '$2' }, true],
  ['if (v1[$1] < v1[$2]) ~= ($0 ~= 0) then', 'LT', { A: '$0', B: '$1', C: '$2' }, true],
  ['if (v1[$1] <= v1[$2]) ~= ($0 ~= 0) then', 'LE', { A: '$0', B: '$1', C: '$2' }, true],
  ['local v1 = v2[$0] local v3 = (v1 ~= nil and v1 ~= false) if v3 ~= ($1 ~= 0) then', 'TEST', { A: '$0', C: '$1' }, true],
  ['local v1 = v2[$1] local v3 = (v1 ~= nil and v1 ~= false) if v3 == ($2 ~= 0) then v2[$0] = v1 else', 'TESTSET', { A: '$0', B: '$1', C: '$2' }, true],
  ['v1[$0] = v1[$0] - v1[$0 + 2] v2 = v2 + S1', 'FORPREP', { A: '$0', sBx: 'S1' }],
  ['v1[$0] = v1[$0] + v1[$0 + 2] local v2', 'FORLOOP', { A: '$0', sBx: 'S1' }, true],
  ['local v1 = v2[$0] local v3 = v2[$0 + 1] local v4 = v2[$0 + 2] local v5 = { v1(v3, v4) } if v5[1] ~= nil then v2[$0 + 2] = v5[1] for v6 = 1, $2 do v2[$0 + 2 + v6] = v5[v6] end v7 = v7 + $1 end', 'TFORLOOP', { A: '$0', jump: '$1', C: '$2' }],
  ['if $1 >= 32768 then $1 = $1 - 65536 end local v1 = v2[$0] local v3 = v2[$0 + 1] local v4 = v2[$0 + 2] if $2 <= 3 then', 'TFORLOOP', { A: '$0', jump: '$1', C: '$2', signed: true }, true],
  ["local v1 = v2[$0] if type(v1) ~= 'function' then", 'TFORPREP', { A: '$0' }, true],
  ['local v1 = v2[$1 + 1] local v3 = v4[v1] local v5 = v3.nuv', 'CLOSURE', { A: '$0', B: '$1' }, true],
  ['if $1 == 0 then local v1 = v2 - v3.np', 'VARARG', { A: '$0', B: '$1' }, true],
  ['if $1 == 0 then local v1 = {} for v2 = $0, v3 - 1 do', 'RETURN', { A: '$0', B: '$1' }, true],
  ['local v1 = v2[$0] local v3 if $1 == 0 then v3 = v4 - $0 - 1 else v3 = $1 - 1 end local v5 = {} for v6 = 1, v3 do v5[v6] = v2[$0 + v6] end return v1(', 'TAILCALL', { A: '$0', B: '$1' }, true],
  ['local v1 = v2[$0] local v3 if $1 == 0 then v3 = v4 - $0 - 1 else v3 = $1 - 1 end', 'CALL', { A: '$0', B: '$1', C: '$2' }, true],
  ['local v1 = v2[$0] local v3 = ($2 - 1) * W local v4 = ($1 == 0)', 'SETLIST', { A: '$0', B: '$1', C: '$2' }, true],
  ['local v1 = v2[$0] local v3 = $2 local v4 = ($1 == 0)', 'SETLISTAT', { A: '$0', B: '$1', base: '$2' }, true],
];

/** The template in canonical form: operands renamed by first use. fieldRank maps each field to the rank of its operand. */
function compileTemplate([tpl, op, fields, prefix]) {
  const rank = new Map();
  const ranked = tpl.replace(/[$S]\d+/g, (tok) => {
    if (!rank.has(tok)) rank.set(tok, rank.size);
    return `${tok[0]}${rank.get(tok)}`;
  });
  const fieldRank = {};
  for (const [f, tok] of Object.entries(fields)) if (typeof tok === 'string') fieldRank[f] = rank.get(tok);
  return { text: ranked, op, fieldRank, signed: !!fields.signed, prefix: !!prefix };
}
const COMPILED = TEMPLATES.map(compileTemplate);

function classify(canonText) {
  let t = canonText;
  let width;
  const w = /\(\$\d+ - 1\) \* (\d+)/.exec(t);
  if (w) { width = Number(w[1]); t = t.replace(/(\(\$\d+ - 1\) \* )\d+/, '$1W'); }
  for (const r of COMPILED) {
    if (r.prefix ? t.startsWith(r.text) : t === r.text) return { ...r, width };
  }
  return null;
}

/** alias byte -> {op, fieldAt (field -> index of the stored operand), reads, signed}. */
export function readHandlers(interp, fetch) {
  const table = new Map();
  const unknown = [];
  for (const c of interp.chain.clauses) {
    const aliases = [...exprText(c.cond).matchAll(/== (\d+)/g)].map((m) => Number(m[1]));
    const { reads, rest } = splitHandler(c.body, fetch);
    const canon = canonical(rest, reads);
    const kind = classify(canon.text);
    if (!kind) { unknown.push({ aliases, text: canon.text }); continue; }
    const fieldAt = {};
    const missing = [];
    for (const [f, r] of Object.entries(kind.fieldRank)) { if (r === undefined) missing.push(f); else fieldAt[f] = canon.order[r]; }
    // a template cut short (the long handlers) names the fields it covers; the one operand left over is the field it does not
    if (missing.length) {
      const free = reads.map((_, i) => i).filter((i) => !Object.values(fieldAt).includes(i));
      if (missing.length !== 1 || free.length < 1) { unknown.push({ aliases, text: `${canon.text} (cannot tell which operand is ${missing.join(', ')})` }); continue; }
      fieldAt[missing[0]] = free[0];
    }
    for (const a of aliases) table.set(a, { op: kind.op, fieldAt, reads: reads.length, signed: reads.map((r) => r.signed), width: kind.width, signedJump: kind.signed });
  }
  return { table, unknown };
}

// ---- the program's data ---------------------------------------------------------------------------------------------------------

const numberList = (t) => {
  const e = unparen(t);
  if (!e || e.type !== 'Table' || !e.fields.every((f) => f.kind === 'item' && unparen(f.value).type === 'Number')) return null;
  return e.fields.map((f) => unparen(f.value).value);
};

/** The function records `T[id] = { bc = {...}, np = n, va = bool, nuv = n, ms = n, sp = {...} }`, by id. */
function readRecords(body) {
  const records = new Map();
  for (const s of body) {
    if (s.type !== 'Assign' || s.targets.length !== 1 || s.values.length !== 1 || s.targets[0].type !== 'Index') continue;
    const v = unparen(s.values[0]);
    if (v.type !== 'Table') continue;
    const bc = fieldOf(v, 'bc');
    if (!bc || !fieldOf(v, 'np') || !fieldOf(v, 'ms')) continue;
    const key = unparen(s.targets[0].key);
    if (key.type !== 'Number') continue;
    const bytes = numberList(bc.value);
    if (!bytes) fail('the instruction bytes are stored encrypted (the hardened build): they are opened in the sandbox, and this reader does not read them yet');
    const num = (name) => { const f = fieldOf(v, name); const x = f && unparen(f.value); return x && x.type === 'Number' ? x.value : 0; };
    const flag = (name) => { const f = fieldOf(v, name); const x = f && unparen(f.value); return !!x && x.type === 'True'; };
    const sp = fieldOf(v, 'sp');
    records.set(key.value, { id: key.value, bytes, np: num('np'), va: flag('va'), nuv: num('nuv'), ms: num('ms'), sp: (sp && numberList(sp.value)) || [] });
  }
  return records;
}

/** The numbers of the main prototype: the call that starts the program, `interp(T[1], {}, ...)`. */
function entryOf(body) {
  const hits = find(body, (n) => n.type === 'Call' && n.args.length === 3 && n.args[0].type === 'Index' && unparen(n.args[0].key).type === 'Number'
    && unparen(n.args[1]).type === 'Table' && n.args[1].fields.length === 0 && n.args[2].type === 'Vararg');
  return hits.length ? unparen(hits[0].args[0].key).value : null;
}

/** The set of link-record kinds that mean "capture a register": the table the CLOSURE handler indexes with the kind byte. */
function localKinds(body, interp) {
  if (!interp.chain.clauses.some((c) => /\.nuv/.test(text(c.body)))) return new Set();       // no closures in this program
  for (const c of interp.chain.clauses) {
    if (!/\.nuv/.test(text(c.body))) continue;
    const cond = find(c.body, (n) => n.type === 'If' && n.clauses[0].cond.type === 'Index' && n.clauses[0].cond.obj.type === 'Name' && n.clauses[0].cond.key.type === 'Name')[0];
    if (!cond) continue;
    const name = cond.clauses[0].cond.obj.name;
    for (const s of body) {
      if (s.type === 'Local' && s.ids[0].name === name && s.values.length === 1 && unparen(s.values[0]).type === 'Table') {
        return new Set(unparen(s.values[0]).fields.filter((f) => f.kind === 'keyed' && unparen(f.key).type === 'Number').map((f) => unparen(f.key).value));
      }
    }
  }
  fail('the table that tells a closure’s captured registers from its captured upvalues was not found');
  return null;
}

// ---- decoding -------------------------------------------------------------------------------------------------------------------

function decodeProto(rec, ctx) {
  const n = rec.bytes.length;
  const byte = (i) => (rec.bytes[i] ^ ctx.key[i % ctx.key.length]) & 255;
  const u16 = (i) => byte(i) + byte(i + 1) * 256;
  const out = [];
  let pos = 0;
  while (pos < n) {
    const start = pos;
    const alias = byte(pos++);
    const h = ctx.handlers.get(alias);
    if (!h) fail(`opcode ${alias} has no handler this reader recognises (offset ${start})`);
    const operands = [];
    for (let k = 0; k < h.reads; k++) {
      if (pos + 1 >= n + 0 && pos + 2 > n) fail(`instruction at offset ${start} runs past the end of the function`);
      let v = u16(pos);
      pos += 2;
      if (h.signed[k]) v -= 32768;
      operands.push(v);
    }
    const f = {};
    for (const [name, idx] of Object.entries(h.fieldAt)) f[name] = operands[idx];
    const ins = { op: h.op, f, start, width: h.width, signedJump: h.signedJump, raw: operands };
    if (h.op === 'CLOSURE') {
      const child = rec.sp[f.B];
      const crec = ctx.records.get(child);
      if (!crec) fail(`a closure at offset ${start} names prototype ${child}, which does not exist`);
      ins.child = child;
      ins.links = [];
      for (let u = 0; u < crec.nuv; u++) {
        const kind = byte(pos); pos += 1;
        pos += 2;                                   // the second field of a link record is not read by the interpreter
        const idx = u16(pos); pos += 2;
        ins.links.push({ local: ctx.localKinds.has(kind), idx });
      }
    }
    ins.end = pos;
    out.push(ins);
  }
  return out;
}

// ---- Lua 5.1 -------------------------------------------------------------------------------------------------------------------

const ARITH = { ADD: 'Add', SUB: 'Sub', MUL: 'Mul', DIV: 'Div', MOD: 'Mod', POW: 'Pow' };
const UNARY = { UNM: 'Unm', NOT: 'Not', LEN: 'Len' };

function buildFunction(rec, ctx, built) {
  if (built.has(rec.id)) return built.get(rec.id);
  const decoded = decodeProto(rec, ctx);
  const k = [];
  const kindex = (globalIndex) => {
    const v = ctx.constants[globalIndex];
    if (v === undefined || v === null) fail(`constant ${globalIndex} was not read`);
    const at = k.findIndex((x) => x === v && typeof x === typeof v);
    if (at >= 0) return at;
    k.push(v);
    return k.length - 1;
  };
  const protos = [];
  const protoIndex = (id) => {
    let at = protos.findIndex((p) => p.id === id);
    if (at < 0) { at = protos.length; protos.push({ id, fn: buildFunction(ctx.records.get(id), ctx, built) }); }
    return at;
  };
  const code = [];
  const startOf = new Map();               // byte offset -> index in code
  const pending = [];                      // jumps to fix: {at, target (byte offset)}
  const emit = (ins) => { code.push(ins); return code.length - 1; };
  const rk = (g) => 256 + kindex(g);
  for (const d of decoded) {
    startOf.set(d.start, code.length);
    const { A, B, C } = d.f;
    switch (d.op) {
      case 'NOP': case 'TFORPREP': break;
      case 'MOVE': case 'GETBOX': case 'SETBOX': case 'MKBOX': emit({ op: 'Move', a: A, b: B, c: 0 }); break;
      case 'LOADK': emit({ op: 'LoadConst', a: A, b: kindex(B), c: 0 }); break;
      case 'LOADBOOL': emit({ op: 'LoadBool', a: A, b: B ? 1 : 0, c: C ? 1 : 0 }); break;
      case 'LOADNIL': emit({ op: 'LoadNil', a: A, b: A + B, c: 0 }); break;
      case 'GETUPVAL': emit({ op: 'GetUpval', a: A, b: B, c: 0 }); break;
      case 'SETUPVAL': emit({ op: 'SetUpval', a: A, b: B, c: 0 }); break;
      case 'GETGLOBAL': emit({ op: 'GetGlobal', a: A, b: kindex(B), c: 0 }); break;
      case 'SETGLOBAL': emit({ op: 'SetGlobal', a: A, b: kindex(B), c: 0 }); break;
      case 'NEWTABLE': emit({ op: 'NewTable', a: A, b: 0, c: 0 }); break;
      case 'GETTABLE': emit({ op: 'GetTable', a: A, b: B, c: C }); break;
      case 'GETTABLEK': emit({ op: 'GetTable', a: A, b: B, c: rk(C) }); break;
      case 'SETTABLE': emit({ op: 'SetTable', a: A, b: B, c: C }); break;
      case 'SETTABLEK': emit({ op: 'SetTable', a: A, b: rk(B), c: C }); break;
      case 'SELF': emit({ op: 'Self', a: A, b: B, c: rk(C) }); break;
      case 'CONCAT': emit({ op: 'Concat', a: A, b: B, c: C }); break;
      case 'EQ': emit({ op: 'Eq', a: A ? 1 : 0, b: B, c: C }); break;
      case 'LT': emit({ op: 'Lt', a: A ? 1 : 0, b: B, c: C }); break;
      case 'LE': emit({ op: 'Le', a: A ? 1 : 0, b: B, c: C }); break;
      case 'TEST': emit({ op: 'Test', a: A, b: 0, c: C ? 1 : 0 }); break;
      case 'TESTSET': emit({ op: 'TestSet', a: A, b: B, c: C ? 1 : 0 }); break;
      case 'CALL': emit({ op: 'Call', a: A, b: B, c: C }); break;
      case 'TAILCALL': emit({ op: 'TailCall', a: A, b: B, c: 0 }); emit({ op: 'Return', a: A, b: 0, c: 0 }); break;
      case 'RETURN': emit({ op: 'Return', a: A, b: B, c: 0 }); break;
      case 'VARARG': emit({ op: 'VarArg', a: A, b: B, c: 0 }); break;
      case 'JMP': pending.push({ at: emit({ op: 'Jmp', a: 0, b: 0, c: 0 }), target: d.end + d.f.sBx }); break;
      case 'FORPREP': pending.push({ at: emit({ op: 'ForPrep', a: A, b: 0, c: 0 }), target: d.end + d.f.sBx }); break;
      case 'FORLOOP': pending.push({ at: emit({ op: 'ForLoop', a: A, b: 0, c: 0 }), target: d.end + d.f.sBx }); break;
      case 'TFORLOOP': {
        let j = d.f.jump;
        if (j >= 32768) j -= 65536;
        emit({ op: 'TForLoop', a: A, b: 0, c: C });
        pending.push({ at: emit({ op: 'Jmp', a: 0, b: 0, c: 0 }), target: d.end + j });
        break;
      }
      case 'SETLIST': if (d.width !== 50) fail(`SETLIST flushes ${d.width} items at a time; Lua 5.1 flushes 50`); emit({ op: 'SetList', a: A, b: B, c: C }); break;
      case 'SETLISTAT': {
        if (d.f.base % 50) fail(`SETLIST starts at item ${d.f.base}, which is not a multiple of 50`);
        emit({ op: 'SetList', a: A, b: B, c: d.f.base / 50 + 1 });
        break;
      }
      case 'CLOSURE': {
        emit({ op: 'Closure', a: A, b: protoIndex(d.child), c: 0 });
        for (const l of d.links) emit(l.local ? { op: 'Move', a: 0, b: l.idx, c: 0 } : { op: 'GetUpval', a: 0, b: l.idx, c: 0 });
        break;
      }
      default:
        if (ARITH[d.op]) emit({ op: ARITH[d.op], a: A, b: B, c: C });
        else if (UNARY[d.op]) emit({ op: UNARY[d.op], a: A, b: B, c: 0 });
        else fail(`instruction ${d.op} has no Lua 5.1 equivalent in this reader`);
    }
  }
  // Obscura 1.0.1 asks for "all results" of a call whose results nothing reads (a statement). Lua 5.1 only allows that when the next instruction takes the open list; otherwise the call returns nothing.
  const takesOpen = (i) => i && ((i.op === 'Call' || i.op === 'TailCall' || i.op === 'Return' || i.op === 'SetList') && i.b === 0);
  code.forEach((ins, i) => { if (ins.op === 'Call' && ins.c === 0 && !takesOpen(code[i + 1])) ins.c = 1; });
  const last = code[code.length - 1];
  startOf.set(rec.bytes.length, code.length);
  if (!last || last.op !== 'Return') emit({ op: 'Return', a: 0, b: 1, c: 0 });
  for (const p of pending) {
    if (!startOf.has(p.target)) fail(`a jump lands inside an instruction (byte ${p.target})`);
    code[p.at].b = startOf.get(p.target) - (p.at + 1);
  }
  const fn = {
    source: null, line: 0, lastLine: 0, nups: rec.nuv, numParams: rec.np, isVararg: rec.va,
    maxStack: Math.max(maxStack(code), Math.min(250, rec.ms + 2)),
    code: Uint32Array.from(code.map(encode)), k, protos: protos.map((p) => p.fn), lines: [], locals: [], upNames: [],
  };
  built.set(rec.id, fn);
  return fn;
}

/**
 * @param {object} ast the parsed script
 * @param {{constants: (string|number|boolean|null)[]}} options the constants the profile read in the sandbox
 * @returns {{bytes: string, stats: object}} a Lua 5.1 binary chunk for the decompiler
 */
export function liftObscuraVm(ast, { constants } = {}) {
  const body = bodyOf(ast);
  const interp = findInterpreter(body);
  if (!interp) fail('no interpreter loop with a chain of opcode tests was found');
  const fetch = readFetch(interp.loop);
  if (!fetch) fail('the opcode fetch is not in the shape this reader knows');
  if (!constants || !constants.length) fail('the constants were not read (they need the sandbox)');
  const keyDecl = body.find((s) => s.type === 'Local' && s.ids.length === 1 && s.ids[0].name === fetch.key && s.values.length === 1);
  const key = keyDecl && numberList(keyDecl.values[0]);
  if (!key || !key.length) fail('the key the instruction bytes are masked with was not found');
  const { table: handlers, unknown } = readHandlers(interp, fetch);
  const records = readRecords(body);
  if (!records.size) fail('no function records were found');
  const entry = entryOf(body);
  if (entry == null || !records.has(entry)) fail('the call that starts the program was not found');
  const ctx = { handlers, records, key, constants, localKinds: localKinds(body, interp) };
  const used = new Set();
  const main = buildFunction(records.get(entry), ctx, new Map());
  main.isVararg = true;
  const bin = dumpChunk51({ main, header: { little: true, intSize: 4, sizeT: 8, numSize: 8 } }, { strip: true });
  let functions = 0; let instructions = 0;
  const count = (f) => { functions++; instructions += f.code.length; f.protos.forEach(count); };
  count(main);
  return { bytes: bin, stats: { functions, instructions, opcodes: handlers.size, handlersUnread: unknown.length, constants: constants.length, used: used.size } };
}
