// IronBrew 2 recovery.
//
// IronBrew 2 (https://github.com/Trollicus/ironbrew-2, MIT) compiles a Lua 5.1 script with luac, re-encodes the
// resulting instructions for its own register VM, and emits that VM as Lua source together with the program
// as a compressed, XOR-masked byte string. Nothing in it is encrypted with a secret: the key, the layout of
// the byte string and the meaning of every virtual opcode are all in the emitted script. Recovery therefore
// needs no execution:
//
//   1. find the byte string, undo the LZW compression and the XOR mask;
//   2. read how this particular script deserialises it (constant type codes and the order of the chunk
//      steps are randomised per output) from the Deserialize function itself;
//   3. read the VM's dispatch tree and decide, for every virtual opcode, which IronBrew 2 handler it is.
//      A handler is recognised by its structure (alpha-equivalence of the syntax tree against the handler
//      texts in ib2-templates.js), so renamed locals, reordered opcode numbers, duplicated "mutated"
//      opcodes and fused "super operators" all resolve;
//   4. invert the operand transform the serialiser applied to each opcode, which gives back the original
//      Lua 5.1 instructions, constants and nested functions;
//   5. write them out as a Lua 5.1 binary chunk, which the decompiler turns back into source.
//
// Anything that does not match raises IronBrewError with the reason, so the caller can fall back to tracing.

import { analyze } from '../core/scope.js';
import { walk, forEachChild } from '../core/walk.js';
import { parse } from '../core/parser.js';
import { IB2_CLASSES } from './ib2-templates.js';
import { dumpChunk51 } from '../sandbox/bytecode.js';

export class IronBrewError extends Error {}
const fail = (message) => { throw new IronBrewError(message); };

// ---- canonical form of handler code ----------------------------------------------------------------------------------------------

/**
 * A string that is equal for two statement lists exactly when they are the same code up to the names of variables
 * (variables are numbered in order of first use). `roleOf(var, name)` may name a variable explicitly (`ENV`, `UPV`)
 * where the structure alone cannot tell two handlers apart.
 */
function canonicaliser(info, roleOf) {
  const ids = new Map();
  const nameOf = (node) => {
    const v = info.varOf.get(node);
    const key = v || `g:${node.name}`;
    const role = roleOf(v, node.name);
    if (role) return role;
    if (!ids.has(key)) ids.set(key, `v${ids.size}`);
    return ids.get(key);
  };
  const list = (xs) => xs.map(expr).join(',');
  const expr = (e) => {
    switch (e.type) {
      case 'Name': case 'Id': return nameOf(e);
      case 'Number': return `n${e.value}`;
      case 'String': return `s${JSON.stringify(e.value)}`;
      case 'Nil': return 'nil';
      case 'True': return 'true';
      case 'False': return 'false';
      case 'Vararg': return '...';
      case 'Paren': return `P(${expr(e.expr)})`;
      case 'Unary': return `(${e.op}${expr(e.arg)})`;
      case 'Binary':
        // `Mvm[1] == <opcode of MOVE>`: the number is the VM's own opcode numbering, not part of the handler's shape
        if (e.op === '==' && e.left.type === 'Index' && e.left.key.type === 'Number' && e.left.key.value === 1) return `(${expr(e.left)}==@)`;
        return `(${expr(e.left)}${e.op}${expr(e.right)})`;
      case 'Index': return `${expr(e.obj)}[${expr(e.key)}]`;
      case 'Call': return `${expr(e.fn)}(${list(e.args)})`;
      case 'MethodCall': return `${expr(e.obj)}:${e.name}(${list(e.args)})`;
      case 'Func': return `fn(${list(e.params)}${e.vararg ? ',...' : ''}){${block(e.body)}}`;
      case 'Table': return `{${e.fields.map((f) => (f.kind === 'keyed' ? `[${expr(f.key)}]=${expr(f.value)}` : expr(f.value))).join(',')}}`;
      default: throw new IronBrewError(`unexpected expression ${e.type} in a handler`);
    }
  };
  const block = (stmts) => stmts.map(stmt).filter((s) => s !== '').join(';');
  const stmt = (s) => {
    switch (s.type) {
      case 'Local':
        // a `local` with a value is an assignment for this purpose; declarations without a value say nothing
        // (super operators hoist them to the top of the handler)
        if (!s.values.length) return '';
        return `A(${list(s.ids)}|${list(s.values)})`;
      case 'Assign': return `A(${list(s.targets)}|${list(s.values)})`;
      case 'CallStmt': return `C(${expr(s.call)})`;
      case 'If': {
        const clauses = s.clauses.map((c) => ({ cond: c.cond, body: c.body }));
        let orelse = s.orelse;
        while (orelse && orelse.length === 1 && orelse[0].type === 'If') {
          clauses.push(...orelse[0].clauses);
          orelse = orelse[0].orelse;
        }
        return `if(${clauses.map((c) => `${expr(c.cond)}){${block(c.body)}}`).join('elif(')}${orelse ? `else{${block(orelse)}}` : ''}`;
      }
      case 'NumFor': return `for(${expr(s.id)}=${expr(s.start)},${expr(s.stop)},${s.step ? expr(s.step) : '1'}){${block(s.body)}}`;
      case 'GenFor': return `forin(${list(s.ids)}|${list(s.exprs)}){${block(s.body)}}`;
      case 'While': return `while(${expr(s.cond)}){${block(s.body)}}`;
      case 'Repeat': return `repeat{${block(s.body)}}until(${expr(s.cond)})`;
      case 'Return': return `ret(${list(s.values)})`;
      case 'Do': return `do{${block(s.body)}}`;
      case 'Break': return 'break';
      default: throw new IronBrewError(`unexpected statement ${s.type} in a handler`);
    }
  };
  return { block, expr };
}

// ---- template index -----------------------------------------------------------------------------------------------------------------------

let templateIndex = null;
function templates() {
  if (templateIndex) return templateIndex;
  const bySig = new Map();
  for (const cls of IB2_CLASSES) {
    const text = cls.text.replace(/OP_ENUM/g, '1').replace(/OP_A/g, '2').replace(/OP_B/g, '3').replace(/OP_C/g, '4').replace(/OP_MOVE/g, '-1');
    const ast = parse(text);
    const info = analyze(ast);
    const roleOf = (_v, name) => (name === 'Env' ? 'ENV' : name === 'Upvalues' ? 'UPV' : null);
    const sig = canonicaliser(info, roleOf).block(ast.body);
    if (!bySig.has(sig)) bySig.set(sig, []);
    bySig.get(sig).push(cls);
  }
  templateIndex = bySig;
  return bySig;
}

// ---- reading the VM out of the script -----------------------------------------------------------------------------------

const isName = (n, v, info) => n && n.type === 'Name' && info.varOf.get(n) === v;

/**
 * The VM's main loop: `while true do Inst = Instr[InstrPoint]; Enum = Inst[1]; <dispatch tree> InstrPoint = InstrPoint + 1 end`.
 * Returns the loop, the four variables it is built from, and the functions enclosing it (innermost last).
 */
function findDispatch(ast, info) {
  let found = null;
  const chain = [];
  const look = (node) => {
    if (found || !node || typeof node !== 'object') return;
    if (Array.isArray(node)) { node.forEach(look); return; }
    if (node.type === 'Func') chain.push(node);
    if (node.type === 'While' && node.cond.type === 'True' && node.body.length >= 3) {
      const [a, b] = node.body;
      const loadsInst = a.type === 'Assign' && a.targets.length === 1 && a.targets[0].type === 'Name' && a.values[0] && a.values[0].type === 'Index'
        && a.values[0].obj.type === 'Name' && a.values[0].key.type === 'Name';
      const loadsEnum = b.type === 'Assign' && b.targets.length === 1 && b.targets[0].type === 'Name' && b.values[0] && b.values[0].type === 'Index'
        && b.values[0].obj.type === 'Name' && b.values[0].key.type === 'Number' && b.values[0].key.value === 1;
      if (loadsInst && loadsEnum && info.varOf.get(b.values[0].obj) === info.varOf.get(a.targets[0])) {
        found = { loop: node, inst: info.varOf.get(a.targets[0]), instr: info.varOf.get(a.values[0].obj), pc: info.varOf.get(a.values[0].key), enum: info.varOf.get(b.targets[0]), funcs: [...chain] };
        return;
      }
    }
    forEachChild(node, look);
    if (node.type === 'Func') chain.pop();
  };
  look(ast.body);
  return found;
}

/** Evaluate `Enum <op> k` conditions of the dispatch tree. */
function dispatchCondition(cond, enumVar, info) {
  if (cond.type !== 'Binary' || cond.left.type !== 'Name' || info.varOf.get(cond.left) !== enumVar || cond.right.type !== 'Number') return null;
  const k = cond.right.value;
  switch (cond.op) {
    case '<=': return (e) => e <= k;
    case '<': return (e) => e < k;
    case '>': return (e) => e > k;
    case '>=': return (e) => e >= k;
    case '==': return (e) => e === k;
    case '~=': return (e) => e !== k;
    default: return null;
  }
}

/** The handler block (statement list) reached by opcode number `e`. */
function leafFor(stmts, e, enumVar, info) {
  let block = stmts;
  for (let guard = 0; guard < 64; guard++) {
    if (block.length !== 1 || block[0].type !== 'If') return block;
    const s = block[0];
    const tests = s.clauses.map((c) => dispatchCondition(c.cond, enumVar, info));
    if (tests.some((t) => !t)) return block; // an ordinary `if` inside a handler, not a dispatch node
    const hit = s.clauses.findIndex((c, i) => tests[i](e));
    if (hit >= 0) block = s.clauses[hit].body;
    else if (s.orelse) block = s.orelse;
    else return [];
  }
  fail('the dispatch tree is deeper than any IronBrew 2 output');
}

/** Split a super operator's handler at the statements that step to the next instruction. */
function splitSuper(block, vm, info) {
  const segments = [[]];
  for (let i = 0; i < block.length; i++) {
    const a = block[i];
    const b = block[i + 1];
    const stepsPc = a.type === 'Assign' && a.targets.length === 1 && isName(a.targets[0], vm.pc, info)
      && a.values[0].type === 'Binary' && a.values[0].op === '+' && isName(a.values[0].left, vm.pc, info) && a.values[0].right.type === 'Number' && a.values[0].right.value === 1;
    const loadsInst = b && b.type === 'Assign' && b.targets.length === 1 && isName(b.targets[0], vm.inst, info)
      && b.values[0].type === 'Index' && isName(b.values[0].obj, vm.instr, info) && isName(b.values[0].key, vm.pc, info);
    if (stepsPc && loadsInst) { segments.push([]); i++; continue; }
    segments[segments.length - 1].push(a);
  }
  return segments;
}

// ---- the byte string ------------------------------------------------------------------------------------------------------------

function lzwDecode(b) {
  let i = 0;
  const num = () => {
    const len = parseInt(b[i++], 36);
    const n = parseInt(b.slice(i, i + len), 36);
    i += len;
    return n;
  };
  const dict = new Map();
  for (let h = 0; h < 256; h++) dict.set(h, String.fromCharCode(h));
  let next = 256;
  let c = String.fromCharCode(num());
  const out = [c];
  while (i < b.length) {
    const n = num();
    const d = dict.has(n) ? dict.get(n) : c + c[0];
    dict.set(next++, c + d[0]);
    out.push(d);
    c = d;
  }
  return out.join('');
}

function findByteString(ast) {
  let best = null;
  for (const s of ast.body) {
    const vals = s.type === 'Local' || s.type === 'Assign' ? s.values : [];
    for (const v of vals) {
      const lit = v.type === 'String' ? v.value : v.type === 'Call' && v.args.length === 1 && v.args[0].type === 'String' ? v.args[0].value : null;
      if (lit !== null && lit.length > 40 && (!best || lit.length > best.length)) best = lit;
    }
  }
  if (!best) fail('no serialised program found at the top of the script');
  let uses36 = false;
  walk(ast, (n) => { if (n.type === 'Number' && n.value === 36) uses36 = true; });
  return /^[0-9A-Z]+$/.test(best) && uses36 ? lzwDecode(best) : best;
}

function findXorKey(ast, info) {
  // local BitXOR = bit and bit.bxor or function(a, b) ... end
  let xor = null;
  for (const s of ast.body) {
    if (s.type !== 'Local' || s.values.length !== 1) continue;
    const v = s.values[0];
    if (v.type === 'Binary' && v.op === 'or' && v.right.type === 'Func' && v.left.type === 'Binary' && v.left.op === 'and') xor = info.varOf.get(s.ids[0]);
  }
  if (!xor) fail('the XOR helper was not found');
  const keys = new Set();
  walk(ast, (n) => {
    if (n.type === 'Call' && n.fn.type === 'Name' && info.varOf.get(n.fn) === xor && n.args.length === 2 && n.args[1].type === 'Number') keys.add(n.args[1].value);
  });
  if (keys.size !== 1) fail(`expected one XOR key, found ${keys.size}`);
  return [...keys][0];
}

// ---- how Deserialize reads a chunk ---------------------------------------------------------------------------------

function findDeserialize(ast, info) {
  for (const s of ast.body) {
    if (s.type !== 'LocalFunction' || s.func.params.length !== 0) continue;
    const body = s.func.body;
    // local Instrs = {} ; local Functions = {} ; local Lines = {} ; local Chunk = { Instrs, Functions, nil, Lines }
    const tableAt = body.find((b) => b.type === 'Local' && b.values.length === 1 && b.values[0].type === 'Table' && b.values[0].fields.length === 4);
    if (tableAt && tableAt.values[0].fields[2].value.type === 'Nil') return { decl: s, fn: s.func, var: info.varOf.get(s.id) };
  }
  return fail('the Deserialize function was not found');
}

function functionBodyOf(varNode, ast, info) {
  const v = info.varOf.get(varNode);
  for (const s of ast.body) if (s.type === 'LocalFunction' && info.varOf.get(s.id) === v) return s.func;
  return null;
}

function readLayout(ast, info, bytes) {
  const des = findDeserialize(ast, info);
  const body = des.fn.body;
  // constants: the first numeric for loop is `for Idx = 1, ConstCount do local Type = gBits8() ... end`
  const constLoop = body.find((b) => b.type === 'NumFor');
  if (!constLoop) fail('the constant loop was not found');
  const typeVar = (() => {
    const decl = constLoop.body.find((b) => b.type === 'Local' && b.values.length === 1 && b.values[0].type === 'Call');
    return decl ? info.varOf.get(decl.ids[0]) : null;
  })();
  const ifs = constLoop.body.find((b) => b.type === 'If');
  if (!typeVar || !ifs) fail('the constant type switch was not found');
  const kinds = {};
  const clauses = [...ifs.clauses];
  let tail = ifs.orelse;
  while (tail && tail.length === 1 && tail[0].type === 'If') { clauses.push(...tail[0].clauses); tail = tail[0].orelse; }
  for (const c of clauses) {
    const k = c.cond.type === 'Paren' ? c.cond.expr : c.cond;
    if (k.type !== 'Binary' || k.op !== '==' || k.right.type !== 'Number') fail('unexpected constant type test');
    const assign = c.body.find((b) => b.type === 'Assign');
    if (!assign) fail('unexpected constant branch');
    let value = assign.values[0];
    if (value.type === 'Paren') value = value.expr;
    if (value.type === 'Binary' && value.op === '~=') kinds[k.right.value] = 'bool';
    else if (value.type === 'Call') {
      const fnBody = value.fn.type === 'Name' ? functionBodyOf(value.fn, ast, info) : null;
      let hasExp = false;
      if (fnBody) walk(fnBody, (n) => { if (n.type === 'Number' && n.value === 2047) hasExp = true; });
      kinds[k.right.value] = hasExp ? 'number' : 'string';
    } else fail('unexpected constant value');
  }
  if (Object.keys(kinds).length !== 3) fail('expected three constant kinds');

  // the chunk steps after the constants
  const steps = [];
  const afterConsts = body.slice(body.indexOf(constLoop) + 1);
  for (const s of afterConsts) {
    if (s.type === 'Assign' && s.targets[0].type === 'Index' && s.targets[0].key.type === 'Number' && s.targets[0].key.value === 3) steps.push('params');
    else if (s.type === 'NumFor') {
      let recursive = false;
      let descriptor = false;
      walk(s.body, (n) => {
        if (n.type === 'Call' && n.fn.type === 'Name' && info.varOf.get(n.fn) === des.var) recursive = true;
        if (n.type === 'Table' && n.fields.length === 4) descriptor = true;
      });
      steps.push(recursive ? 'functions' : descriptor ? 'instructions' : 'lines');
    }
  }
  if (!steps.includes('params') || !steps.includes('instructions') || !steps.includes('functions')) fail('the chunk layout could not be read');
  return { kinds, steps };
}

// ---- decoding bytes into protos ----------------------------------------------------------------------------------------

function decodeProtos(bytes, key, layout) {
  let p = 0;
  const u8 = () => { if (p >= bytes.length) fail('the serialised program ends early'); return bytes.charCodeAt(p++) ^ key; };
  const u16 = () => { const a = u8(); const b = u8(); return b * 256 + a; };
  const u32 = () => { const a = u8(); const b = u8(); const c = u8(); const d = u8(); return d * 16777216 + c * 65536 + b * 256 + a; };
  const f64 = () => {
    const buf = new DataView(new ArrayBuffer(8));
    for (let i = 0; i < 8; i++) buf.setUint8(i, u8());
    return buf.getFloat64(0, true);
  };
  const str = () => {
    const n = u32();
    let s = '';
    for (let i = 0; i < n; i++) s += String.fromCharCode(u8());
    return s;
  };
  const chunk = (depth) => {
    if (depth > 200) fail('functions are nested deeper than any real script');
    const proto = { consts: [], instrs: [], params: 0, protos: [] };
    const nconst = u32();
    for (let i = 0; i < nconst; i++) {
      const t = u8();
      const kind = layout.kinds[t];
      if (kind === 'bool') proto.consts.push({ t: 'bool', v: u8() !== 0 });
      else if (kind === 'number') proto.consts.push({ t: 'number', v: f64() });
      else if (kind === 'string') proto.consts.push({ t: 'string', v: str() });
      else proto.consts.push({ t: 'nil' });
    }
    for (const step of layout.steps) {
      if (step === 'params') proto.params = u8();
      else if (step === 'instructions') {
        const n = u32();
        for (let i = 0; i < n; i++) {
          const d = u8();
          if (d & 1) { proto.instrs.push(null); continue; }
          const type = (d >> 1) & 3;
          const op = u16();
          const a = u16();
          let b = 0;
          let c = 0;
          if (type === 0) { b = u16(); c = u16(); } else if (type === 1) b = u32(); else if (type === 2) b = u32() - 65536; else { b = u32() - 65536; c = u16(); }
          proto.instrs.push({ op, a, b, c, type });
        }
      } else if (step === 'functions') {
        const n = u32();
        for (let i = 0; i < n; i++) proto.protos.push(chunk(depth + 1));
      } else if (step === 'lines') {
        const n = u32();
        for (let i = 0; i < n; i++) u32();
      }
    }
    return proto;
  };
  const root = chunk(0);
  return root;
}

// ---- identifying the handlers ----------------------------------------------------------------------------------------

function identifyHandlers(ast, info, vm, usedEnums) {
  const bySig = templates();
  // roles that the structure of a handler cannot express: the 2nd and 3rd parameter of the function that builds closures
  const wrap = vm.funcs.find((f) => f.params.length === 3) || null;
  const roles = new Map();
  if (wrap) {
    roles.set(info.varOf.get(wrap.params[1]), 'UPV');
    roles.set(info.varOf.get(wrap.params[2]), 'ENV');
  }
  const roleOf = (v) => (v ? roles.get(v) || null : null);

  const classify = (stmts) => {
    const sig = canonicaliser(info, roleOf).block(stmts);
    const hit = bySig.get(sig);
    return hit || null;
  };

  const tree = vm.loop.body.slice(2, vm.loop.body.length - 1); // between the two loads and the `pc = pc + 1`
  const result = new Map();
  for (const e of usedEnums) {
    const leaf = leafFor(tree, e, vm.enum, info);
    if (!leaf.length) { result.set(e, { kind: 'unknown', why: 'no handler' }); continue; }
    const whole = classify(leaf);
    if (whole) { result.set(e, { kind: 'single', candidates: whole }); continue; }
    const segments = splitSuper(leaf, vm, info);
    if (segments.length > 1) {
      const seq = segments.map((s) => classify(s));
      if (seq.every(Boolean)) { result.set(e, { kind: 'super', seq }); continue; }
      const bad = seq.findIndex((s) => !s);
      result.set(e, { kind: 'unknown', why: `part ${bad + 1} of a fused handler is not an IronBrew 2 handler` });
      continue;
    }
    result.set(e, { kind: 'unknown', why: 'not an IronBrew 2 handler' });
  }
  return result;
}

// ---- rebuilding Lua 5.1 -----------------------------------------------------------------------------------------------------

const OP51 = { Move: 0, LoadConst: 1, LoadBool: 2, LoadNil: 3, GetUpval: 4, GetGlobal: 5, GetTable: 6, SetGlobal: 7, SetUpval: 8, SetTable: 9, NewTable: 10, Self: 11,
  Add: 12, Sub: 13, Mul: 14, Div: 15, Mod: 16, Pow: 17, Unm: 18, Not: 19, Len: 20, Concat: 21, Jmp: 22, Eq: 23, Lt: 24, Le: 25, Test: 26, TestSet: 27, Call: 28,
  TailCall: 29, Return: 30, ForLoop: 31, ForPrep: 32, TForLoop: 33, SetList: 34, Close: 35, Closure: 36, VarArg: 37 };
const BX = new Set(['LoadConst', 'GetGlobal', 'SetGlobal', 'Closure']);
const SBX = new Set(['Jmp', 'ForLoop', 'ForPrep']);

function evalInv(term, ser, pc) {
  if (!term) return 0;
  let v = term.k;
  for (const [sym, coef] of term.t) v += coef * (sym === 'sA' ? ser.a : sym === 'sB' ? ser.b : sym === 'sC' ? ser.c : pc);
  return v;
}

function chooseClass(candidates) {
  // two classes with the same handler text do not exist in IronBrew 2; if one ever does, the first is used
  return candidates[0];
}

function rebuildProto(proto, handlers) {
  const n = proto.instrs.length;
  const classes = new Array(n).fill(null);
  for (let i = 0; i < n; i++) {
    const ins = proto.instrs[i];
    if (!ins || classes[i]) continue;
    const h = handlers.get(ins.op);
    if (!h || h.kind === 'unknown') fail(`virtual opcode ${ins.op} is not recognised (${h ? h.why : 'no handler'})`);
    if (h.kind === 'single') classes[i] = chooseClass(h.candidates);
    else {
      for (let j = 0; j < h.seq.length; j++) {
        if (i + j >= n || !proto.instrs[i + j]) fail('a fused handler runs past the end of its function');
        classes[i + j] = chooseClass(h.seq[j]);
      }
    }
  }
  const code = [];
  const counters = new Map(); // table register -> items stored so far (to number SETLIST batches)
  for (let i = 0; i < n; i++) {
    const ins = proto.instrs[i];
    if (!ins) fail('a data word appears in the instruction stream (SETLIST with a very large batch number)');
    const cls = classes[i];
    if (cls.lossy) fail(`${cls.name} loses an operand the instruction needs`);
    if (cls.op === 'SetTop' || cls.op === 'NewStack') {
      // Helper opcodes of IronBrew 2's own transforms. NewStack re-creates the frame at the top of a function (a
      // no-op there); SetTop publishes how many values an inlined call returned, which only matters to an
      // instruction that consumes an open result list, so those functions are refused below.
      code.push({ op: 'Move', a: 0, b: 0, c: 0, helper: cls.op });
      continue;
    }
    if (!(cls.op in OP51)) fail(`${cls.name} is not an instruction IronBrew 2 emits for a Lua 5.1 program`);
    const ser = { a: ins.a, b: ins.b, c: ins.c };
    // operands the Lua instruction does not use are written as 0, as luac does; IronBrew 2 leaves stray values there
    let a = cls.needs.includes('A') ? evalInv(cls.inv.A, ser, i) : 0;
    let b = cls.needs.includes('B') ? evalInv(cls.inv.B, ser, i) : 0;
    let c = cls.needs.includes('C') ? evalInv(cls.inv.C, ser, i) : 0;
    if (cls.op === 'Closure') {
      const child = proto.protos[b];
      if (!child) fail('CLOSURE refers to a function that is not there');
      child.nups = cls.name === 'OpClosure' ? ins.c : 0;
    }
    if (cls.op === 'NewTable') counters.set(a, 0);
    if (cls.op === 'SetList') {
      const done = counters.get(a) || 0;
      c = Math.floor(done / 50) + 1;
      counters.set(a, done + b);
    }
    code.push({ op: cls.op, a, b, c });
  }
  // IronBrew 2's control-flow pass flips about half of the comparisons: `cmp A; JMP t` becomes `cmp !A; JMP over; JMP t`
  // with `over` just past the second jump. Both forms mean the same; this undoes the flip without moving any instruction
  // (the second jump becomes a jump to the next instruction, which the decompiler ignores).
  for (let k = 0; k + 2 < code.length; k++) {
    const c = code[k];
    const j1 = code[k + 1];
    const j2 = code[k + 2];
    if (!['Eq', 'Lt', 'Le', 'Test'].includes(c.op) || j1.op !== 'Jmp' || j2.op !== 'Jmp' || j1.b !== 1) continue;
    if (c.op === 'Test') c.c = c.c === 0 ? 1 : 0; else c.a = c.a === 0 ? 1 : 0;
    code[k + 1] = { op: 'Jmp', a: 0, b: 1 + j2.b, c: 0 };
    code[k + 2] = { op: 'Jmp', a: 0, b: 0, c: 0 };
    k += 2;
  }
  // a SetTop is followed by the jump out of the inlined body; the instruction it lands on is the only one that could
  // read the value count, and only if it takes an open result list (B = 0)
  for (let i = 0; i < code.length - 1; i++) {
    if (code[i].helper !== 'SetTop' || code[i + 1].op !== 'Jmp') continue;
    const landing = code[i + 2 + code[i + 1].b];
    if (landing && landing.b === 0 && !landing.helper && ['Call', 'TailCall', 'Return', 'SetList'].includes(landing.op)) {
      fail('an inlined call returns a variable number of values, which Lua 5.1 bytecode cannot express');
    }
  }
  return code;
}

function encode(ins) {
  const op = OP51[ins.op];
  if (BX.has(ins.op)) return (op | (ins.a << 6) | (ins.b << 14)) >>> 0;
  if (SBX.has(ins.op)) return (op | (ins.a << 6) | ((ins.b + 131071) << 14)) >>> 0;
  if (ins.b < 0 || ins.b > 511 || ins.c < 0 || ins.c > 511 || ins.a < 0 || ins.a > 255) fail(`operand out of range in ${ins.op}`);
  return (op | (ins.a << 6) | (ins.c << 14) | (ins.b << 23)) >>> 0;
}

function maxStack(code) {
  let m = 2;
  for (const ins of code) {
    const regs = [ins.a + 2];
    if (ins.op === 'Call' || ins.op === 'TailCall') regs.push(ins.a + Math.max(ins.b, ins.c, 2) + 1);
    if (ins.op === 'Return' || ins.op === 'VarArg' || ins.op === 'SetList') regs.push(ins.a + ins.b + 2);
    if (ins.op === 'TForLoop') regs.push(ins.a + 3 + ins.c);
    if (ins.op === 'ForLoop' || ins.op === 'ForPrep') regs.push(ins.a + 4);
    if (ins.op === 'Self') regs.push(ins.a + 2);
    if (ins.op === 'Concat') regs.push(ins.c + 1);
    for (const f of [ins.b, ins.c]) if (f < 256 && ['Move', 'GetTable', 'SetTable', 'Add', 'Sub', 'Mul', 'Div', 'Mod', 'Pow', 'Eq', 'Lt', 'Le', 'Unm', 'Not', 'Len', 'Self', 'TestSet'].includes(ins.op)) regs.push(f + 1);
    m = Math.max(m, ...regs);
  }
  return Math.min(250, m + 1);
}

/** The rebuilt function as the tree parseChunk returns, so it can be written out or handed straight to the decompiler. */
function toFunction(proto, handlers) {
  const code = rebuildProto(proto, handlers);
  const protos = proto.protos.map((p) => toFunction(p, handlers));
  return {
    source: null, line: 0, lastLine: 0,
    nups: proto.nups || 0, numParams: proto.params, isVararg: code.some((i) => i.op === 'VarArg'), maxStack: maxStack(code),
    code: Uint32Array.from(code.map(encode)),
    k: proto.consts.map((k) => (k.t === 'nil' ? undefined : k.v)),
    protos, lines: [], locals: [], upNames: [],
  };
}

/** How many instructions of each kind the script uses, for the report. */
function countStats(proto, stats) {
  stats.functions++;
  stats.instructions += proto.instrs.filter(Boolean).length;
  stats.constants += proto.consts.length;
  proto.protos.forEach((p) => countStats(p, stats));
}

/**
 * @param {object} ast parsed script
 * @returns {{bytes: string, stats: object}} a Lua 5.1 binary chunk (as a binary string) equal to what luac produced
 */
export function recoverIronBrew(ast) {
  const info = analyze(ast);
  const vm = findDispatch(ast, info);
  if (!vm) fail('no virtual machine dispatch loop found');
  const bytes = findByteString(ast);
  const key = findXorKey(ast, info);
  const layout = readLayout(ast, info);
  const root = decodeProtos(bytes, key, layout);
  const used = new Set();
  const collect = (p) => { p.instrs.forEach((i) => { if (i) used.add(i.op); }); p.protos.forEach(collect); };
  collect(root);
  const handlers = identifyHandlers(ast, info, vm, used);
  const main = toFunction(root, handlers);
  main.isVararg = true; // the main chunk of a Lua 5.1 script always is
  const bin = dumpChunk51({ main, header: { little: true, intSize: 4, sizeT: 8, numSize: 8 } }, { strip: true });
  const stats = { functions: 0, instructions: 0, constants: 0, virtualOpcodes: used.size, superOperators: [...handlers.values()].filter((h) => h.kind === 'super').length, xorKey: key, compressed: bytes.length };
  countStats(root, stats);
  return { bytes: bin, stats };
}
