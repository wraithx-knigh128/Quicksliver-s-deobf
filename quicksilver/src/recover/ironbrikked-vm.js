// LuaXen's IronBrikked virtual machine, lifted back to source (https://github.com/luauminati/LuaXen, a reimplementation of the IronBrew 2 design).
//
// What the script carries:
//
//   * the program as a long string, compressed (an LZW whose codes are written in base 36), then a byte format: for every function its constants (a tag, then a double, a string or a
//     boolean), its instructions (a mode byte, an opcode byte and operands of 16 or 32 bits) and its nested functions;
//   * an interpreter that is a binary search of `if op <= n` over the opcode, with the handlers at the leaves, and a numbering that is Lua 5.1's own for the first 38 operations
//     and an expansion of the rest by what the operands are (`v[A] = m[B] + v[C]` is one opcode, `v[A] = v[B] + v[C]` another).
//
// The dispatch is evaluated for every opcode (the reader shared with Zartha and FusGato), the handlers of the expanded opcodes are recognised by their text (which operand is a
// constant, which a register), and the first 38 are recognised by the text of the handler too. The generator's handlers for some of those do not do what the instruction does (SETGLOBAL
// and SETUPVAL swap their operands, TEST and TFORLOOP read a field that is always zero, the constants are numbered from one more than where a comparison looks for them): the
// instruction is read as the Lua 5.1 instruction the handler stands for, which is what the program was, and the report says the build does not run the way the program did.
//
// A handler no rule recognises makes the function that uses it fail with its text.

import { dumpChunk51 } from '../sandbox/bytecode.js';
import { encode, maxStack } from './ironbrew.js';
import { find, partial, alphaRename, applyRoles, canon } from './zartha-vm.js';

export class IronbrikkedVmError extends Error {}
const fail = (m) => { throw new IronbrikkedVmError(m); };

// ---- the data ----------------------------------------------------------------------------------------------------------------

function lzw(X) {
  const T = [];
  for (let i = 0; i < 256; i++) T[i] = String.fromCharCode(i);
  let f = 0;
  const g = () => {
    const h = parseInt(X[f], 36); f++;
    if (Number.isNaN(h) || h < 1) fail('the compressed program is not in the shape this reader knows');
    const i = parseInt(X.slice(f, f + h), 36); f += h;
    return i;
  };
  const d = new Map();
  for (let e = 0; e < 256; e++) d.set(e, T[e]);
  let b = 256;
  let prev = T[g()];
  const out = [prev];
  while (f < X.length) {
    const h = g();
    const cur = d.has(h) ? d.get(h) : prev + prev[0];
    d.set(b, prev + cur[0]);
    out.push(cur); prev = cur; b++;
  }
  return out.join('');
}

function readProgram(D) {
  let L = 0;
  const need = (n) => { if (L + n > D.length) fail('the program ends inside an item'); };
  const u8 = () => { need(1); return D.charCodeAt(L++); };
  const u16 = () => { need(2); const v = D.charCodeAt(L) + D.charCodeAt(L + 1) * 256; L += 2; return v; };
  const u32 = () => { need(4); const v = D.charCodeAt(L) + D.charCodeAt(L + 1) * 256 + D.charCodeAt(L + 2) * 65536 + D.charCodeAt(L + 3) * 16777216; L += 4; return v; };
  const dbl = () => { const lo = u32(); const hi = u32(); const dv = new DataView(new ArrayBuffer(8)); dv.setUint32(0, lo, true); dv.setUint32(4, hi, true); return dv.getFloat64(0, true); };
  const str = () => { const n = u32(); if (!n) return ''; need(n); const s = D.slice(L, L + n); L += n; return s; };
  const proto = () => {
    const k = [];
    const n = u32();
    for (let t = 1; t <= n; t++) {
      const ty = u8();
      if (ty === 0) k[t] = dbl(); else if (ty === 1) k[t] = str(); else if (ty === 3) k[t] = u8() === 1; else k[t] = undefined;
    }
    const ni = u32();
    const ins = [];
    for (let u = 1; u <= ni; u++) {
      const mode = u8();
      const F = { 1: u8() };
      if (mode === 0) { F[2] = u16(); F[3] = u16(); F[4] = u16(); } else if (mode === 1 || mode === 2) { F[2] = u16(); F[3] = u32() - 65536; } else fail(`an instruction has a mode (${mode}) this reader does not know`);
      ins.push({ mode, F });
    }
    const field = u8();
    const np = u32();
    const protos = [];
    for (let w = 0; w < np; w++) protos.push(proto());
    return { k, ins, field, protos };
  };
  const root = proto();
  if (L !== D.length) fail('the program does not end where its data does');
  return root;
}

// ---- the interpreter -------------------------------------------------------------------------------------------------------------

const ins = (op, a = 0, b = 0, c = 0) => ({ op, a, b, c });
const k0 = (x) => x - 257;                          // a constant is written as 256 plus its place counting from one

function substFields(node, Y) {
  if (!node || typeof node !== 'object') return node;
  if (Array.isArray(node)) return node.map((x) => substFields(x, Y));
  if (node.type === 'Func') return node;
  if (node.type === 'Index' && node.obj.type === 'Name' && node.obj.name === Y && node.key.type === 'Number') return { type: 'Name', name: `F${node.key.value}` };
  const o = {};
  for (const k of Object.keys(node)) o[k] = substFields(node[k], Y);
  return o;
}

const GRID = { '+': 'Add', '-': 'Sub', '*': 'Mul', '/': 'Div', '%': 'Mod', '^': 'Pow' };
// in the expanded operations a constant operand is the place of the constant counting from one, a register operand is the register
const RK = (kind, F) => (kind === 'm' ? 255 + F : F);

/** The instruction one handler is, from its text and the decoded fields; null when no rule knows it. */
const tidyText = (x) => x.replace(/\((not (?:not )?[^()]*)\)/g, '$1');                // `(not a) == b` and `not a == b` are the same text once the layer above was undone

function recognise(t0, F) {
  let m;
  const t = tidyText(t0);
  const exact = {
    'v[F2] = v[F3]': () => ins('Move', F[2], F[3]),
    'v[F2] = F3': () => ins('LoadConst', F[2], k0(F[3])),
    'v[F2] = F3 == 1 if F4 == 1 then q = q + 1 end': () => ins('LoadBool', F[2], F[3], F[4]),
    'v[F2] = j[F3]': () => ins('GetUpval', F[2], F[3]),
    'v[F2] = N[F3]': () => ins('GetGlobal', F[2], k0(F[3])),
    'N[F2] = v[F3]': () => ins('SetGlobal', F[2], k0(F[3])),
    'j[F2] = v[F3]': () => ins('SetUpval', F[2], F[3]),
    'v[F2] = {}': () => ins('NewTable', F[2]),
    'v[F2] = -F3': () => ins('Unm', F[2], F[3]),
    'v[F2] = not F3': () => ins('Not', F[2], F[3]),
    'v[F2] = #F3': () => ins('Len', F[2], F[3]),
    'q = q + F3': () => ins('Jmp', 0, F[3]),
    'local v1 = F3 or F4 if (not v[F2]) == (v1 == 1) then q = q + 1 end': () => ins('Test', F[2], 0, F[3]),
    'if (not not v[F3]) == (F4 == 1) then v[F2] = v[F3] else q = q + 1 end': () => ins('TestSet', F[2], F[3], F[4]),
    'local v1 = "" for v2 = F3, F4 do v1 = v1 .. v[v2] end v[F2] = v1': () => ins('Concat', F[2], F[3], F[4]),
    'for v1 = F2, F3 do v[v1] = nil end': () => ins('LoadNil', F[2], F[3]),
    'local v1 = v[F2] + v[F2 + 2] if v1 <= v[F2 + 1] then q = q + F3 v[F2 + 3] = v1 end v[F2] = v1': () => ins('ForLoop', F[2], F[3]),
    'v[F2] = v[F2] - v[F2 + 2] q = q + F3': () => ins('ForPrep', F[2], F[3]),
  };
  const hit = Object.keys(exact).find((k) => tidyText(k) === t);
  if (hit) return exact[hit]();
  if (/^local v1 = \{\} local v2 = 1 for v3 = F2 \+ 1, F2 \+ F3 - 1 do v1\[v2\] = v\[v3\] v2 = v2 \+ 1 end local v4 = \{v\[F2\]\(V\(v1\)\)\} /.test(t)) return ins('Call', F[2], F[3], F[4]);
  if (/^local v1 = \{\} local v2 = 1 for v3 = F2 \+ 1, F2 \+ F3 - 1 do v1\[v2\] = v\[v3\] v2 = v2 \+ 1 end return v\[F2\]\(V\(v1\)\)$/.test(t)) return ins('TailCall', F[2], F[3], 0);
  if (/^local v1 = \{\} local v2 = 1 for v3 = F2, F2 \+ F3 - 2 do v1\[v2\] = v\[v3\] v2 = v2 \+ 1 end return V\(v1\)$/.test(t)) return ins('Return', F[2], F[3]);
  if (/^local v1 = F3 or F4 local v2 = \{v\[F2\]\(v\[F2 \+ 1\], v\[F2 \+ 2\]\)\}/.test(t)) return ins('TForLoop', F[2], 0, F[3]);
  if (/^local v1 = F4 - 1 local v2 = v1 \+ F3 - 1 local v3 = v\[F2\] for/.test(t)) return ins('SetList', F[2], F[3], F[4]);
  if (/^local v1 = o\[F3\] local v2 = v1\[3\]/.test(t)) return ins('Closure', F[2], F[3] - 1);
  if (/^local v1 = 1 for v2 = F2, F2 \+ F3 - 1 do v\[v2\] = u\[v1\] v1 = v1 \+ 1 end$/.test(t)) return ins('VarArg', F[2], F[3] + 1);
  // the expanded operations: which operand is a constant (m) and which a register (v)
  if ((m = /^v\[F2\] = (m|v)\[F3\] ([-+*/%^]) (m|v)\[F4\]$/.exec(t))) return ins(GRID[m[2]], F[2], RK(m[1], F[3]), RK(m[3], F[4]));
  if ((m = /^v\[F2\] = (m|v)\[F3\]\[(m|v)\[F4\]\]$/.exec(t))) return ins('GetTable', F[2], m[1] === 'v' ? F[3] : -1, RK(m[2], F[4]));
  if ((m = /^v\[F2\]\[(m|v)\[F3\]\] = (m|v)\[F4\]$/.exec(t))) return ins('SetTable', F[2], RK(m[1], F[3]), RK(m[2], F[4]));
  if ((m = /^v\[F2 \+ 1\] = v\[F3\] v\[F2\] = v\[F3\]\[(m|v)\[F4\]\]$/.exec(t))) return ins('Self', F[2], F[3], RK(m[1], F[4]));
  if ((m = /^if \(?(m|v)\[F3\] (==|<|<=) (m|v)\[F4\]\)? ~= \(?F2 == 1\)? then q = q \+ 1 end$/.exec(t))) return ins({ '==': 'Eq', '<': 'Lt', '<=': 'Le' }[m[2]], F[2], RK(m[1], F[3]), RK(m[3], F[4]));
  return null;
}

/** The registers an instruction reads. */
const readsOf = (i) => {
  const r = [];
  const rk = (x) => { if (x < 256) r.push(x); };
  switch (i.op) {
    case 'Move': case 'Len': case 'Not': case 'Unm': r.push(i.b); break;
    case 'SetUpval': case 'SetGlobal': case 'Test': r.push(i.a); break;
    case 'TestSet': r.push(i.b); break;
    case 'GetTable': r.push(i.b); rk(i.c); break;
    case 'Self': r.push(i.b); rk(i.c); break;
    case 'SetTable': r.push(i.a); rk(i.b); rk(i.c); break;
    case 'Add': case 'Sub': case 'Mul': case 'Div': case 'Mod': case 'Pow': case 'Eq': case 'Lt': case 'Le': rk(i.b); rk(i.c); break;
    case 'Concat': for (let k = i.b; k <= i.c; k++) r.push(k); break;
    case 'Call': case 'TailCall': for (let k = 0; k < Math.max(1, i.b); k++) r.push(i.a + k); break;
    case 'Return': if (i.b >= 2) for (let k = 0; k < i.b - 1; k++) r.push(i.a + k); else if (i.b === 0) r.push(i.a); break;
    case 'TForLoop': case 'ForLoop': case 'ForPrep': r.push(i.a, i.a + 1, i.a + 2); break;
    case 'SetList': r.push(i.a); for (let k = 0; k < i.b; k++) r.push(i.a + 1 + k); break;
    default: break;
  }
  return r;
};

function inferParams(code) {
  const written = new Set();
  code.forEach((i) => { if (i.op === 'TForLoop') for (let k = 0; k < i.c; k++) written.add(i.a + 3 + k); if (i.op === 'ForLoop' || i.op === 'ForPrep') written.add(i.a + 3); });
  let n = 0;
  for (const i of code) {
    for (const r of readsOf(i)) if (!written.has(r)) n = Math.max(n, r + 1);
    if (i.pseudo || ['SetGlobal', 'SetUpval', 'SetTable', 'Jmp', 'Eq', 'Lt', 'Le', 'Test', 'Return', 'TailCall', 'SetList', 'Close'].includes(i.op)) continue;
    if (i.op === 'Call') { for (let k = 0; k < Math.max(1, i.c - 1); k++) written.add(i.a + k); continue; }
    if (i.op === 'LoadNil') { for (let k = i.a; k <= i.b; k++) written.add(k); continue; }
    written.add(i.a);
  }
  return n;
}

function buildFunction(p, ctx, label) {
  const code = []; const protos = [];
  let links = 0;
  p.ins.forEach(({ F }, idx) => {
    const op0 = F[1];
    const t = ctx.handlers(op0);
    let op;
    if (t === null) {
      if (op0 === 35) op = ins('Close', F[2]);
      else fail(`${label}: instruction ${idx + 1} uses opcode ${op0}, which this build has no handler for`);
    } else {
      op = recognise(t, F);
      if (!op || (op.op === 'GetTable' && op.b === -1)) fail(`${label}: instruction ${idx + 1} (opcode ${op0}) is not one this reader recognises: ${t.slice(0, 160)}`);
    }
    // LuaXen's compiler writes RETURN's B as first register + count + 1 (`(expressionRegisters[1] + #expressionRegisters) + 1`), where Lua means count + 1: the count is B - A
    if (op.op === 'Return' && op.b > 0) {
      if (op.b - op.a < 1) fail(`${label}: instruction ${idx + 1} returns from register ${op.a} with an end (${op.b}) before it`);
      op.b -= op.a;
    }
    // a jump is written with its distance when it goes forward and 256 plus its distance when it goes back
    if (op.op === 'Jmp' || op.op === 'ForLoop' || op.op === 'ForPrep') op.b = op.b > 256 ? -(op.b - 256) : op.b;
    if (op.op === 'Closure') {
      const child = p.protos[op.b];
      if (!child) fail(`${label}: instruction ${idx + 1} makes a function the data does not hold`);
      protos.push(buildFunction(child, ctx, `${label} > function ${op.b + 1}`));
      op.b = protos.length - 1;
      links = child.field;
    } else if (links > 0) {
      links--;
      if (op.op !== 'Move' && op.op !== 'GetUpval') fail(`${label}: instruction ${idx + 1} follows a closure and is not a link to an upvalue`);
      op.a = 0; op.pseudo = true;
    }
    code.push(op);
  });
  // the generator puts a SETLIST with no items after the NEWTABLE of an empty constructor (its handler stores nothing for a count of zero; in Lua 5.1 a zero would mean "up to the top")
  {
    const gone = new Set();
    code.forEach((i, k) => { if (i.op === 'SetList' && i.b === 0 && k > 0 && code[k - 1].op === 'NewTable' && code[k - 1].a === i.a) gone.add(k); });
    if (gone.size) {
      const at = []; let n = 0;
      for (let k = 0; k <= code.length; k++) { at[k] = n; if (!gone.has(k)) n++; }
      code.forEach((i, k) => { if (i.op === 'Jmp' || i.op === 'ForLoop' || i.op === 'ForPrep') { const t = k + 1 + i.b; i.b = at[Math.max(0, Math.min(code.length, t))] - (at[k] + 1); } });
      const kept = code.filter((_, k) => !gone.has(k));
      code.length = 0; code.push(...kept);
    }
  }
  // the call that makes the iterator of a generic `for` is written with "all results"; the three the loop needs are meant
  code.forEach((i, k) => {
    if (i.op !== 'Call' || i.c !== 0) return;
    const j = code[k + 1];
    if (j && j.op === 'Jmp') { const tgt = code[k + 2 + j.b]; if (tgt && tgt.op === 'TForLoop' && tgt.a === i.a) i.c = 4; }
  });
  // The generator writes the number of results of a call as 0 or 1 whether or not anything uses them (its own handler copies C - 1 of them, so a call whose result is needed loses it
  // and the program fails, which is why its output does not run). What the call was is told by the code after it: the registers from A up that are read before they are written.
  {
    const writes = (i, r) => !i.pseudo && !['SetGlobal', 'SetUpval', 'SetTable', 'Jmp', 'Eq', 'Lt', 'Le', 'Test', 'Return', 'TailCall', 'SetList', 'Close', 'Call', 'TForLoop', 'ForLoop', 'ForPrep'].includes(i.op) && i.a === r;
    code.forEach((i, k) => {
      if (i.op !== 'Call' || i.c > 1) return;
      const nx = code[k + 1];
      if (nx && (nx.op === 'Call' || nx.op === 'TailCall' || nx.op === 'Return' || nx.op === 'SetList') && nx.b === 0) return;
      let n = 0;
      for (let reg = i.a; reg < i.a + 8; reg++) {
        let used = false;
        for (let q = k + 1; q < Math.min(code.length, k + 40); q++) {
          if (readsOf(code[q]).includes(reg)) { used = true; break; }
          if (writes(code[q], reg) || code[q].op === 'Return' || (code[q].op === 'Call' && code[q].a <= reg && i.c === 1 && code[q].a === reg)) break;
        }
        if (!used) break;
        n++;
      }
      i.c = n > 0 ? n + 1 : 1;
    });
  }
  const takesOpen = (i) => i && (i.op === 'Call' || i.op === 'TailCall' || i.op === 'Return' || i.op === 'SetList') && i.b === 0;
  code.forEach((i, k) => { if (i.op === 'Call' && i.c === 0 && !takesOpen(code[k + 1])) i.c = 1; });
  const last = code[code.length - 1];
  if (!last || last.op !== 'Return') code.push(ins('Return', 0, 1));
  const k = p.k.slice(1);
  for (const i of code) {
    for (const f of ['b', 'c']) if (i[f] >= 256 && !['Call', 'TailCall', 'Return', 'VarArg', 'SetList', 'TForLoop', 'Closure', 'LoadBool', 'Jmp', 'ForLoop', 'ForPrep'].includes(i.op) && i[f] - 256 >= k.length) fail(`${label}: a constant that does not exist is used`);
    if (['LoadConst', 'GetGlobal', 'SetGlobal'].includes(i.op) && (i.b < 0 || i.b >= k.length)) fail(`${label}: a constant that does not exist is used`);
  }
  return {
    source: null, line: 0, lastLine: 0, nups: p.field, numParams: inferParams(code), isVararg: code.some((i) => i.op === 'VarArg'), maxStack: maxStack(code),
    code: Uint32Array.from(code.map(encode)), k, protos, lines: [], locals: [], upNames: [],
  };
}

const isDispatch = (n) => n.type === 'Repeat' && n.body[0] && n.body[0].type === 'Local' && n.body[0].ids.length === 2 && n.body.some((s) => s.type === 'If');

/** @returns {{bytes: string, stats: object}} a Lua 5.1 binary chunk for the decompiler */
export function liftIronbrikkedVm(ast) {
  const data = find(ast, (n) => n.type === 'Call' && n.args.some((a) => a.type === 'String' && a.value.length > 300)).map((c) => c.args.find((a) => a.type === 'String' && a.value.length > 300));
  if (!data.length) fail('the compressed program was not found');
  const rep = find(ast, isDispatch)[0];
  if (!rep) fail('the dispatch loop was not found');
  const [Y, Z] = rep.body[0].ids.map((i) => i.name);
  const tree = rep.body.find((s) => s.type === 'If');
  const root = readProgram(lzw(data[0].value));
  // the stack, the constants and the rest are named by what the handlers do with them
  const roles = new Map();
  const move = partial([tree], Z, 0)[0];
  const probe = move && substFields(move, Y);
  if (!(probe && probe.type === 'Assign' && probe.targets[0].type === 'Index' && probe.values[0].type === 'Index' && probe.targets[0].key.name === 'F2' && probe.values[0].key.name === 'F3')) fail('the handler of opcode 0 is not a move');
  roles.set(probe.targets[0].obj.name, 'v');
  // the other names are fixed by the shape of the handlers of Lua's own operations: upvalues, environment, the counter, unpack, the functions, the varargs
  const leaf = (op) => { const r = partial([tree], Z, op); return r.length ? r.map((x) => substFields(x, Y)) : null; };
  const nameIn = (op, f) => { const r = leaf(op); const hit = r && find(r, f)[0]; return hit || null; };
  const up = nameIn(4, (n) => n.type === 'Index' && n.obj.type === 'Name' && n.key.type === 'Name' && n.key.name === 'F3');
  const gl = nameIn(5, (n) => n.type === 'Index' && n.obj.type === 'Name' && n.key.type === 'Name' && n.key.name === 'F3');
  const pcn = nameIn(22, (n) => n.type === 'Assign' && n.targets[0].type === 'Name');
  const unp = nameIn(30, (n) => n.type === 'Return' && n.values[0].type === 'Call' && n.values[0].fn.type === 'Name');
  const fns = nameIn(36, (n) => n.type === 'Local' && n.values[0].type === 'Index' && n.values[0].obj.type === 'Name');
  const vag = nameIn(37, (n) => n.type === 'Assign' && n.values[0].type === 'Index' && n.values[0].obj.type === 'Name' && n.values[0].obj.name !== roles.get('x'));
  if (up) roles.set(up.obj.name, 'j');
  if (gl) roles.set(gl.obj.name, 'N');
  if (pcn) roles.set(pcn.targets[0].name, 'q');
  if (unp) roles.set(unp.values[0].fn.name, 'V');
  if (fns) roles.set(fns.values[0].obj.name, 'o');
  if (vag) roles.set(vag.values[0].obj.name, 'u');
  const cache = new Map();
  const handlers = (op) => {
    if (cache.has(op)) return cache.get(op);
    const raw = partial([tree], Z, op);
    const t = raw.length ? canon(alphaRename(raw).map((s) => applyRoles(substFields(s, Y), roles))) : null;
    cache.set(op, t);
    return t;
  };
  // constants are `m[..]`: the name the variants index the constants with
  const m = (() => { for (let op = 38; op < 60; op++) { const raw = partial([tree], Z, op); if (raw.length && raw[0].type === 'Assign' && raw[0].values[0].type === 'Index') { const n = substFields(raw[0], Y); const v = n.values[0]; if (v.obj.type === 'Index' && v.obj.obj.type === 'Name') return v.obj.obj.name; } } return null; })();
  if (m) roles.set(m, 'm');
  const fn = buildFunction(root, { handlers }, 'the program');
  fn.isVararg = true; fn.numParams = 0; fn.nups = 0;
  let functions = 0; let instructions = 0;
  const count = (f) => { functions++; instructions += f.code.length; f.protos.forEach(count); };
  count(fn);
  const bin = dumpChunk51({ main: fn, header: { little: true, intSize: 4, sizeT: 8, numSize: 8 } }, { strip: true });
  return { bytes: bin, stats: { functions, instructions, constants: fn.k.length } };
}

/** The shape of an IronBrikked build: a long compressed string passed to a function that runs a repeat loop dispatching on an opcode. */
export function looksLikeIronbrikked(ast) {
  try { return find(ast, isDispatch).length > 0 && find(ast, (n) => n.type === 'String' && n.value.length > 300 && /^[0-9A-Z]+$/.test(n.value)).length > 0; } catch { return false; }
}
