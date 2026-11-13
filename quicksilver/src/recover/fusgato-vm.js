// FusGato's virtual machine, lifted back to source (https://github.com/adzwang/fusgato-v1, MIT).
//
// FusGato is a fork of IronBrew 2's idea with two differences that matter here:
//
//   * the program is a string of bits: for every function a header (how many upvalues, where the instructions start), then items, each introduced by a 3-bit code: a boolean, a number,
//     a string, a float, a skipped constant slot, a nested function, or an instruction word of 26 bits that carries NO opcode, only three fields A (8 bits), B and C (9 bits each);
//   * the interpreter is not a switch on an opcode: it is `if pc == 1 then <handler> elseif pc == 2 then <handler> ...`, the handler of instruction `pc` written out in place with its
//     operands read from the decoded table (`S[F[pc][1]] = K[F[pc][4]]`). The numbers it compares with are written as `#("some text") + 5`, which the evaluation of the dispatch reads.
//
// So the instruction is told by the handler text (the same technique as for Zartha, whose reader this one shares), and its operands by the decoded data. The generator turns every
// global access into an index of a register that holds the environment (`{[18] = getfenv()}` in the table that is the stack), and that is read back as GETGLOBAL / SETGLOBAL.
//
// The generator's comparison handlers ignore the A field (the test is always the same), so builds that compare do not run like the program; the instruction is read with the A its
// word carries, which is what the program was.
//
// A handler no rule recognises makes the function fail with its text. Only handlers that occur in the committed fixtures are recognised: nothing here is guessed for an operation
// that was not seen.

import { dumpChunk51 } from '../sandbox/bytecode.js';
import { encode, maxStack } from './ironbrew.js';
import { unparen } from './vmprofile.js';
import { find, partial, alphaRename, applyRoles, canon } from './zartha-vm.js';

export class FusgatoVmError extends Error {}
const fail = (m) => { throw new FusgatoVmError(m); };

// ---- the container ---------------------------------------------------------------------------------------------------------------

const CODES = { '000': 'bool', '001': 'number', '010': 'string', '011': 'instruction', '100': 'slot2', '101': 'proto', '110': 'skip', '111': 'float' };

function readProto(bits, top) {
  let pos = 0;
  const take = (k) => { if (pos + k > bits.length) fail('the data ends inside an item'); const v = bits.slice(pos, pos + k); pos += k; return v; };
  const num = (b) => parseInt(b, 2);
  if (top) take(3);
  take(3);
  const ups = num(take(32));
  take(3);
  let t = num(take(32));
  const start = t;
  for (let k = 0; k < ups; k++) { take(9); const n = num(take(32)); for (let q = 0; q < n; q++) take(8); }
  const p = { ups, start, instrs: new Map(), consts: [], protos: [] };
  let n = 1;
  while (pos < bits.length) {
    const kind = CODES[take(3)];
    if (kind === 'bool') p.consts[n++] = take(1) === '1';
    else if (kind === 'number') p.consts[n++] = num(take(32));
    else if (kind === 'string') { take(3); const len = num(take(32)); let s = ''; for (let q = 0; q < len; q++) s += String.fromCharCode(num(take(8))); p.consts[n++] = s; }
    else if (kind === 'instruction') {
      const w = num(take(26));
      const F = { 1: Math.floor(w / 262144), 2: Math.floor(w / 512) % 512, 3: w % 512, 4: w % 262144 };
      let s = F[4]; if (s > 131072) s = 131072 - s; F[5] = s;
      if (F[2] > 255) F[6] = F[2] - 255;
      if (F[3] > 255) F[7] = F[3] - 255;
      p.instrs.set(t++, F);
    } else if (kind === 'slot2') { /* a record the interpreter does not use */ }
    else if (kind === 'proto') { take(3); const size = num(take(32)); p.protos.push(readProto(take(size), false)); }
    else if (kind === 'skip') n++;
    else if (kind === 'float') { take(3); const a = String(num(take(32))); take(3); const b = String(num(take(32))); p.consts[n++] = Number(`${a}.${b}`); }
  }
  return p;
}

// ---- the interpreter -------------------------------------------------------------------------------------------------------------

const isBits = (s) => s.type === 'Local' && s.ids.length === 1 && s.values.length === 1 && unparen(s.values[0]).type === 'String' && /^[01]{200,}$/.test(unparen(s.values[0]).value);
const fieldOf = (e, P) => {                                // `X[pc][k]` -> k, with X the instruction table
  const x = unparen(e);
  if (x.type !== 'Index' || x.key.type !== 'Number') return null;
  const o = unparen(x.obj);
  return o.type === 'Index' && unparen(o.key).type === 'Name' && unparen(o.key).name === P && o.obj.type === 'Name' ? { table: o.obj.name, k: x.key.value } : null;
};

function substFields(node, P, names) {
  if (!node || typeof node !== 'object') return node;
  if (Array.isArray(node)) return node.map((x) => substFields(x, P, names));
  if (node.type === 'Func') return node;
  const f = fieldOf(node, P);
  if (f) { names.table = f.table; return { type: 'Name', name: `F${f.k}` }; }
  const o = {};
  for (const k of Object.keys(node)) o[k] = substFields(node[k], P, names);
  return o;
}

/** The text of one handler, with the fields written `F1`.. and the machine's names replaced by roles. */
function handlerText(raw, P, roles) {
  const names = {};
  const withFields = alphaRename(raw).map((s) => substFields(s, P, names));
  return canon(withFields.map((s) => applyRoles(s, roles)));
}

const ARITH = { '+': 'Add', '-': 'Sub', '*': 'Mul', '/': 'Div', '%': 'Mod', '^': 'Pow' };
const ins = (op, a = 0, b = 0, c = 0) => ({ op, a, b, c });
const RKB = '\\(?F6 and K\\[F6\\] or S\\[F2\\]\\)?';
const RKC = '\\(?F7 and K\\[F7\\] or S\\[F3\\]\\)?';
const rkB = (F) => (F[6] ? 255 + F[6] : F[2]);
const rkC = (F) => (F[7] ? 255 + F[7] : F[3]);

const CALL_TEXT = 'local v1 = S[F1] local v2 = {} local v3 = F1 + F2 - 1 if F2 == 0 then v3 = TOP + 1 end for v4 = F1 + 1, v3 do INS(v2, S[v4]) end TOP = F1 - 1 local v5 = {v1(UNP(v2))} if F3 < 1 then for v6 = F1, F1 + #v5 - 1 do S[v6] = v5[v6 + 1 - F1] end elseif F3 > 1 then for v7 = F1, F1 + F3 - 2 do S[v7] = v5[v7 + 1 - F1] end end';
const RETURN_TEXT = 'local v1 = {} if F2 == 0 then for v2 = F1, TOP do INS(v1, S[v2]) end elseif F2 > 1 then for v3 = F1, F1 + F2 - 2 do INS(v1, S[v3]) end end return UNP(v1)';
const SETLIST_TEXT = 'if F3 == 0 then P = P - 1 end local v1 = F2 if v1 == 0 then v1 = TOP - F1 + 1 end for v2 = 1, v1 do S[F1][(F3 - 1) * 50 + v2] = S[F1 + v2] end';
const TFOR_TEXT = 'local v1 = {S[F1](S[F1 + 1], S[F1 + 2])} for v2 = 1, F3 do S[F1 + 2 + v2] = v1[v2] end if S[F1 + 3] then S[F1 + 2] = S[F1 + 3] else P = P + 1 end';
const CONCAT_TEXT = 'S[F1] = "" for v1 = F2, F3 do S[F1] = S[F1] .. S[v1] end';

/** The instruction a handler is, with the decoded fields of the instruction it belongs to; null when no rule knows it. */
function recognise(t, F, env) {
  let m;
  if (t === CALL_TEXT) return ins('Call', F[1], F[2], F[3]);
  if (t === RETURN_TEXT) return ins('Return', F[1], F[2]);
  if (t === SETLIST_TEXT) return ins('SetList', F[1], F[2], F[3]);
  if (t === TFOR_TEXT) return ins('TForLoop', F[1], 0, F[3]);
  if (t === CONCAT_TEXT) return ins('Concat', F[1], F[2], F[3]);
  if (t === 'S[F1] = S[F2]') return ins('Move', F[1], F[2]);
  if (t === 'S[F1] = K[F4]') return ins('LoadConst', F[1], F[4] - 1);
  if (t === 'S[F1] = {}') return ins('NewTable', F[1]);
  if (t === 'S[F1] = #S[F2]') return ins('Len', F[1], F[2]);
  if (t === 'S[F1] = not S[F2]') return ins('Not', F[1], F[2]);
  if (t === 'S[F1] = -S[F2]') return ins('Unm', F[1], F[2]);
  if (t === 'P = P + F5') return ins('Jmp', 0, F[5]);
  if (t === 'S[F1] = TRUE') return ins('LoadBool', F[1], 1, F[3] ? 1 : 0);
  if (t === 'S[F1] = FALSE') return ins('LoadBool', F[1], 0, F[3] ? 1 : 0);
  if (t === 'if not (S[F1] == (F3 ~= 0)) then P = P + 1 end') return ins('Test', F[1], 0, F[3] ? 1 : 0);
  if ((m = new RegExp(`^S\\[F1\\] = S\\[F2\\]\\[${RKC}\\]$`).exec(t))) {
    if (F[2] === env && F[7]) return ins('GetGlobal', F[1], F[7] - 1);
    return ins('GetTable', F[1], F[2], rkC(F));
  }
  if (new RegExp(`^S\\[F1\\]\\[${RKB}\\] = ${RKC}$`).test(t)) {
    if (F[1] === env && F[6] && !F[7]) return ins('SetGlobal', F[3], F[6] - 1);
    return ins('SetTable', F[1], rkB(F), rkC(F));
  }
  if ((m = new RegExp(`^S\\[F1\\] = ${RKB} ([-+*/%^]) ${RKC}$`).exec(t))) return ins(ARITH[m[1]], F[1], rkB(F), rkC(F));
  if ((m = new RegExp(`^if not \\(${RKB} (<=|<|==) ${RKC}\\) then P = P \\+ 1 end$`).exec(t))) return ins({ '<=': 'Le', '<': 'Lt', '==': 'Eq' }[m[1]], F[1] ? 1 : 0, rkB(F), rkC(F));
  if ((m = new RegExp(`^if ${RKB} (<=|<|==) ${RKC} then P = P \\+ 1 end$`).exec(t))) return ins({ '<=': 'Le', '<': 'Lt', '==': 'Eq' }[m[1]], F[1] ? 1 : 0, rkB(F), rkC(F));
  if ((m = /^S\[F1\] = (\w+)\[F2\]$/.exec(t)) && m[1] !== 'S' && m[1] !== 'K') return ins('GetUpval', F[1], F[2] - 1);
  if ((m = /^(\w+)\[F2\] = S\[F1\]$/.exec(t)) && m[1] !== 'S' && m[1] !== 'K') return ins('SetUpval', F[1], F[2] - 1);
  return null;
}

function inferParams(code) {
  const READS = (i) => {
    const r = [];
    const rk = (x) => { if (x < 256) r.push(x); };
    switch (i.op) {
      case 'Move': case 'Len': case 'Not': case 'Unm': r.push(i.b); break;
      case 'SetUpval': case 'SetGlobal': case 'Test': r.push(i.a); break;
      case 'GetTable': r.push(i.b); rk(i.c); break;
      case 'SetTable': r.push(i.a); rk(i.b); rk(i.c); break;
      case 'Add': case 'Sub': case 'Mul': case 'Div': case 'Mod': case 'Pow': case 'Eq': case 'Lt': case 'Le': rk(i.b); rk(i.c); break;
      case 'Concat': for (let k = i.b; k <= i.c; k++) r.push(k); break;
      case 'Call': for (let k = 0; k < Math.max(1, i.b); k++) r.push(i.a + k); break;
      case 'Return': if (i.b >= 2) for (let k = 0; k < i.b - 1; k++) r.push(i.a + k); else if (i.b === 0) r.push(i.a); break;
      case 'TForLoop': r.push(i.a, i.a + 1, i.a + 2); break;
      case 'SetList': r.push(i.a); for (let k = 0; k < i.b; k++) r.push(i.a + 1 + k); break;
      default: break;
    }
    return r;
  };
  const written = new Set();
  code.forEach((i) => { if (i.op === 'TForLoop') for (let k = 0; k < i.c; k++) written.add(i.a + 3 + k); });
  let n = 0;
  for (const i of code) {
    for (const r of READS(i)) if (!written.has(r)) n = Math.max(n, r + 1);
    if (i.pseudo || ['SetGlobal', 'SetUpval', 'SetTable', 'Jmp', 'Eq', 'Lt', 'Le', 'Test', 'Return', 'SetList'].includes(i.op)) continue;
    if (i.op === 'Call') { for (let k = 0; k < Math.max(1, i.c - 1); k++) written.add(i.a + k); continue; }
    written.add(i.a);
  }
  return n;
}

const isClosureLeaf = (raw, P, L) => raw.some((x) => x.type === 'Local' && x.ids.length === 1 && x.values.length === 1 && x.values[0].type === 'Index' && x.values[0].obj.type === 'Name' && x.values[0].obj.name === L && x.values[0].key.type === 'Name' && x.values[0].key.name === P)
  && find(raw, (n) => n.type === 'Table' && n.fields.some((f) => f.key === '__index' || (f.key && f.key.type === 'Name' && f.key.name === '__index'))).length > 0;

function build(p, ctx, label) {
  const code = []; const protos = [];
  const last = Math.max(...p.instrs.keys());
  let links = 0;                                  // the words after a closure are the links to its upvalues
  for (let pc = p.start; pc <= last; pc++) {
    const F = p.instrs.get(pc);
    if (!F) fail(`${label}: instruction ${pc} is missing from the data`);
    const raw = partial([ctx.chain], ctx.P, pc);
    if (isClosureLeaf(raw, ctx.P, ctx.L)) {
      const child = p.protos[F[4] - 1];
      if (!child) fail(`${label}: instruction ${pc} makes a function the data does not hold`);
      protos.push(build2(child, ctx, `${label} > function ${F[4]}`));
      code.push(ins('Closure', F[1], protos.length - 1));
      links = child.ups;
      continue;
    }
    const h = handlerText(raw, ctx.P, ctx.roles);
    const op = recognise(h, F, ctx.env);
    if (!op) fail(`${label}: instruction ${pc} is not one this reader recognises: ${h.slice(0, 160)}`);
    if (links > 0) { links--; if (op.op !== 'Move' && op.op !== 'GetUpval') fail(`${label}: instruction ${pc} follows a closure and is not a link to an upvalue`); op.a = 0; op.pseudo = true; }
    code.push(op);
  }
  return { code, protos };
}

function build2(p, ctx, label) {
  const { code, protos } = build(p, ctx, label);
  const takesOpen = (i) => i && (i.op === 'Call' || i.op === 'Return' || i.op === 'SetList') && i.b === 0;
  code.forEach((i, k) => { if (i.op === 'Call' && i.c === 0 && !takesOpen(code[k + 1])) i.c = 1; });
  const last = code[code.length - 1];
  if (!last || last.op !== 'Return') code.push(ins('Return', 0, 1));
  return {
    source: null, line: 0, lastLine: 0, nups: p.ups, numParams: inferParams(code), isVararg: false, maxStack: maxStack(code), code: Uint32Array.from(code.map(encode)),
    k: p.consts.slice(1), protos, lines: [], locals: [], upNames: [],
  };
}

/** @returns {{bytes: string, stats: object}} a Lua 5.1 binary chunk for the decompiler */
export function liftFusgatoVm(ast) {
  const bitsDecl = find(ast, isBits)[0];
  if (!bitsDecl) fail('the string of bits that holds the program was not found');
  const main = readProto(unparen(bitsDecl.values[0]).value, true);
  const loops = find(ast, (n) => n.type === 'While' && unparen(n.cond).type === 'True' && n.body.some((s) => s.type === 'If' && s.clauses.length > 5));
  if (loops.length !== 1) fail('the dispatch loop was not found');
  const chain = loops[0].body.find((s) => s.type === 'If');
  const P = unparen(chain.clauses[0].cond).left.name;
  // roles, from the shape of the handlers
  const roles = new Map();
  const names = {};
  let load = null;
  for (let pc = main.start; pc <= Math.max(...main.instrs.keys()) && !load; pc++) {
    const probe = partial([chain], P, pc).map((x) => substFields(x, P, names));
    const a = probe[0];
    if (probe.length === 1 && a.type === 'Assign' && a.targets[0].type === 'Index' && a.values[0].type === 'Index' && a.targets[0].key.type === 'Name' && a.targets[0].key.name === 'F1' && a.values[0].key.type === 'Name' && a.values[0].key.name === 'F4') load = a;
  }
  if (!load) fail('no handler that loads a constant was found');
  roles.set(load.targets[0].obj.name, 'S'); roles.set(load.values[0].obj.name, 'K'); roles.set(P, 'P'); roles.set(names.table, 'L');
  // the stack is created with the environment in one register: `setmetatable({ [18] = getfenv() }, ...)`
  const envField = find(ast, (n) => n.type === 'Table' && n.fields.some((f) => f.kind === 'keyed' && f.key.type === 'Number' && unparen(f.value).type === 'Call' && unparen(f.value).fn.type === 'Name'))[0];
  const env = envField ? envField.fields.find((f) => f.kind === 'keyed' && f.key.type === 'Number').key.value : null;
  if (env === null) fail('the register that holds the environment was not found');
  // library aliases of the header, and the counters
  const header = find(ast, (n) => n.type === 'Local' && n.ids.length === 1 && n.values.length === 1);
  for (const s of header) {
    const v = unparen(s.values[0]);
    if (v.type === 'Index' && v.obj.type === 'Name' && v.obj.name === 'table' && v.key.value === 'insert') roles.set(s.ids[0].name, 'INS');
    else if (v.type === 'Name' && v.name === 'unpack') roles.set(s.ids[0].name, 'UNP');
    else if (v.type === 'True') roles.set(s.ids[0].name, 'TRUE');
    else if (v.type === 'False') roles.set(s.ids[0].name, 'FALSE');
  }
  // the top of the stack: the name the call handler sets to `A - 1`
  const callLeaf = (() => { for (let p = main.start; p < main.start + 400; p++) { const r = partial([chain], P, p); const t = r.length && find(r, (n) => n.type === 'Assign' && n.targets[0].type === 'Name' && n.values[0].type === 'Binary' && n.values[0].op === '-' && fieldOf(n.values[0].left, P)); if (t && t.length) return t[0]; } return null; })();
  // the machine's own locals shadow the header's names
  roles.set(load.targets[0].obj.name, 'S'); roles.set(load.values[0].obj.name, 'K'); roles.set(P, 'P'); roles.set(names.table, 'L');
  if (callLeaf) roles.set(callLeaf.targets[0].name, 'TOP');
  const ctx = { chain, P, L: names.table, roles, env };
  const fn = build2(main, ctx, 'the program');
  fn.isVararg = true; fn.numParams = 0;
  let functions = 0; let instructions = 0;
  const count = (f) => { functions++; instructions += f.code.length; f.protos.forEach(count); };
  count(fn);
  const k = fn.k;
  const bin = dumpChunk51({ main: fn, header: { little: true, intSize: 4, sizeT: 8, numSize: 8 } }, { strip: true });
  return { bytes: bin, stats: { functions, instructions, constants: k.length } };
}

/** The shape of a FusGato build: a long string of bits and a dispatch on the instruction index. */
export function looksLikeFusgato(ast) {
  try {
    return find(ast, isBits).length === 1 && find(ast, (n) => n.type === 'While' && unparen(n.cond).type === 'True' && n.body.some((s) => s.type === 'If' && s.clauses.length > 5)).length === 1;
  } catch { return false; }
}
