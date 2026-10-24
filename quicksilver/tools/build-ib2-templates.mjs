// Reads IronBrew 2's opcode classes (MIT, https://github.com/Trollicus/ironbrew-2, IronBrew2/Obfuscator/Opcodes/*.cs)
// and writes src/recover/ib2-templates.js: for every virtual opcode its Lua handler text and the exact inverse of
// the operand transform its `Mutate` method applies when the instruction is serialised.
//
//   node tools/build-ib2-templates.mjs /path/to/ironbrew-2 [--check]
//
// The inverse is derived, not typed in: each Mutate body is a short list of linear statements
// (`B += A - 1`, `A = B - 255`, ...). They are executed symbolically over the original operands A0, B0, C0, which
// gives the serialised operands as linear expressions; those are then solved for the originals. Operands the
// transform destroys (for example B of an Eq, which becomes a jump target) are pinned by the opcode's own
// IsInstruction condition (`A == 0`, `C != 0`, ...). An operand that matters for the Lua 5.1 instruction and can
// be neither solved nor pinned makes this script fail, so a class cannot silently lose information.

import fs from 'node:fs';
import path from 'node:path';

const root = process.argv[2];
if (!root) { console.error('usage: node tools/build-ib2-templates.mjs /path/to/ironbrew-2'); process.exit(2); }
const dir = path.join(root, 'IronBrew2', 'Obfuscator', 'Opcodes');
const out = path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'src', 'recover', 'ib2-templates.js');

// What the Lua 5.1 instruction needs, per opcode (the others are unused by the VM and read as 0).
const NEEDS = {
  Move: 'AB', LoadConst: 'AB', LoadBool: 'ABC', LoadNil: 'AB', GetUpval: 'AB', GetGlobal: 'AB', GetTable: 'ABC', SetGlobal: 'AB',
  SetUpval: 'AB', SetTable: 'ABC', NewTable: 'A', Self: 'ABC', Add: 'ABC', Sub: 'ABC', Mul: 'ABC', Div: 'ABC', Mod: 'ABC', Pow: 'ABC',
  Unm: 'AB', Not: 'AB', Len: 'AB', Concat: 'ABC', Jmp: 'B', Eq: 'ABC', Lt: 'ABC', Le: 'ABC', Test: 'AC', TestSet: 'ABC', Call: 'ABC',
  TailCall: 'AB', Return: 'AB', ForLoop: 'AB', ForPrep: 'AB', TForLoop: 'AC', SetList: 'AB', Close: 'A', Closure: 'AB', VarArg: 'AB',
  SetTop: 'A', PushStack: 'A', NewStack: '', SetFenv: 'A',
};

// classes whose serialised form drops an operand the Lua 5.1 instruction needs
const LOSSY = { OpSetListC0: 'B' };

function stripComments(s) { return s.replace(/\/\/[^\n]*/g, ''); }

function matchBrace(s, open) {
  let depth = 0;
  for (let i = open; i < s.length; i++) {
    if (s[i] === '"' ) { // skip string literals (regular or verbatim)
      const verbatim = s[i - 1] === '@';
      for (i++; i < s.length; i++) {
        if (verbatim) { if (s[i] === '"') { if (s[i + 1] === '"') i++; else break; } }
        else if (s[i] === '\\') i++;
        else if (s[i] === '"') break;
      }
      continue;
    }
    if (s[i] === '{') depth++;
    else if (s[i] === '}') { depth--; if (depth === 0) return i; }
  }
  throw new Error('unbalanced braces');
}

function firstStringLiteral(s) {
  const m = /(@?)"/.exec(s);
  if (!m) return null;
  let i = m.index + m[0].length;
  let text = '';
  if (m[1]) {
    for (; i < s.length; i++) { if (s[i] === '"') { if (s[i + 1] === '"') { text += '"'; i++; } else break; } else text += s[i]; }
  } else {
    for (; i < s.length; i++) {
      if (s[i] === '\\') { const n = s[++i]; text += n === 'n' ? '\n' : n === 't' ? '\t' : n; } else if (s[i] === '"') break; else text += s[i];
    }
  }
  return text;
}

// ---- IsInstruction -> opcode + predicates ------------------------------------------------------------------------------------------

function parsePredicate(expr) {
  const atoms = stripComments(expr).split('&&').map((x) => x.trim()).filter(Boolean);
  const pred = { op: null, fields: [], upvalueCount: null };
  for (const a of atoms) {
    let m;
    if ((m = /instruction\.OpCode == Opcode\.(\w+)/.exec(a))) pred.op = m[1];
    else if ((m = /instruction\.([ABC]) (==|!=|<=|>|>=|<) (\d+)$/.exec(a))) pred.fields.push({ f: m[1], cmp: m[2], k: Number(m[3]) });
    else if (/UpvalueCount (>|==) 0/.test(a)) pred.upvalueCount = /> 0/.test(a) ? 'some' : 'none';
    else throw new Error(`unhandled predicate atom: ${a}`);
  }
  if (!pred.op) throw new Error(`no opcode in predicate: ${expr}`);
  return pred;
}

// ---- Mutate -> linear transform -------------------------------------------------------------------------------------------------------

const lin = (c = 0, t = {}) => ({ c, t: { ...t } });
const add = (a, b, sign = 1) => { const r = lin(a.c + sign * b.c, a.t); for (const [k, v] of Object.entries(b.t)) { r.t[k] = (r.t[k] || 0) + sign * v; if (r.t[k] === 0) delete r.t[k]; } return r; };

function parseLinear(expr, state) {
  // tokens: instruction.X, instruction.PC, ints, the two Chunk lookups, + and -
  const tokens = [];
  const re = /instruction\.Chunk\.Instructions\[instruction\.PC \+ 1\]\.(B|Data)|instruction\.Chunk\.Functions\[instruction\.B\]\.UpvalueCount|instruction\.(A|B|C|PC)\b|\d+|[+-]/g;
  let m;
  while ((m = re.exec(expr))) {
    if (m[1]) tokens.push(lin(0, { [m[1] === 'B' ? 'NB' : 'ND']: 1 }));
    else if (m[0].includes('UpvalueCount')) tokens.push(lin(0, { UV: 1 }));
    else if (m[2]) tokens.push(m[2] === 'PC' ? lin(0, { PC: 1 }) : state[m[2]]);
    else if (/^\d/.test(m[0])) tokens.push(lin(Number(m[0])));
    else tokens.push(m[0]);
  }
  let acc = lin();
  let sign = 1;
  for (const tk of tokens) {
    if (tk === '+') sign = 1; else if (tk === '-') sign = -1; else { acc = add(acc, tk, sign); sign = 1; }
  }
  return acc;
}

function parseMutate(body) {
  const stmts = stripComments(body).split(';').map((s) => s.trim().replace(/^[{=>\s]+|[}\s]+$/g, '')).filter(Boolean);
  const state = { A: lin(0, { A0: 1 }), B: lin(0, { B0: 1 }), C: lin(0, { C0: 1 }) };
  let type = null;
  for (let s of stmts) {
    s = s.replace(/\b(instruction|ins)\b/g, 'instruction');
    let m;
    if (/ConstantMask/.test(s)) continue;
    if ((m = /^instruction\.InstructionType = InstructionType\.(\w+)$/.exec(s))) { type = m[1]; continue; }
    if ((m = /^instruction\.([ABC])\+\+$/.exec(s))) { state[m[1]] = add(state[m[1]], lin(1)); continue; }
    if ((m = /^instruction\.([ABC])\s*(=|\+=|-=)\s*(.+)$/.exec(s))) {
      const rhs = parseLinear(m[3], state);
      state[m[1]] = m[2] === '=' ? rhs : add(state[m[1]], rhs, m[2] === '+=' ? 1 : -1);
      continue;
    }
    if (/^Mutated\.Mutate/.test(s)) continue;
    throw new Error(`unhandled Mutate statement: ${s}`);
  }
  return { state, type };
}

// ---- solving ---------------------------------------------------------------------------------------------------------------------------------

function solve(state, pred, needs, cls) {
  const solved = {}; // 'A0' -> linear expression over sA, sB, sC, PC
  const ser = { A: 'sA', B: 'sB', C: 'sC' };
  const subst = (e) => { // replace already solved originals inside e
    let r = lin(e.c);
    for (const [k, v] of Object.entries(e.t)) {
      if (solved[k]) r = add(r, { c: solved[k].c * v, t: Object.fromEntries(Object.entries(solved[k].t).map(([a, b]) => [a, b * v])) });
      else r = add(r, lin(0, { [k]: v }));
    }
    return r;
  };
  const rounds = () => {
    for (let round = 0; round < 6; round++) {
      for (const f of ['A', 'B', 'C']) {
        // equation: sF = state[f]; usable when exactly one original is still unknown and its coefficient is +-1
        const e = subst(state[f]);
        const unknown = Object.keys(e.t).filter((k) => /^[ABC]0$/.test(k) && !solved[k]);
        if (unknown.length !== 1) continue;
        const u = unknown[0];
        const coef = e.t[u];
        if (Math.abs(coef) !== 1) continue;
        let rest = lin(e.c);
        for (const [k, v] of Object.entries(e.t)) if (k !== u) rest = add(rest, lin(0, { [k]: v }));
        let sol = add(lin(0, { [ser[f]]: 1 }), rest, -1);
        if (coef === -1) sol = add(lin(), sol, -1);
        // only expressions over serialised operands, PC and constants are available at run time
        if (Object.keys(sol.t).some((k) => !['sA', 'sB', 'sC', 'PC'].includes(k))) continue;
        solved[u] = sol;
      }
    }
  };
  rounds();
  // what the transform destroyed is pinned by the opcode's own condition (`A == 0`, `C != 0` -> 1, ...)
  for (const p of pred.fields) {
    const key = `${p.f}0`;
    if (solved[key]) continue;
    if (p.cmp === '==') solved[key] = lin(p.k);
    else if (p.cmp === '!=' && p.k === 0) solved[key] = lin(1);
  }
  rounds();
  const inv = {};
  for (const f of ['A', 'B', 'C']) {
    const s = solved[`${f}0`];
    if (!s) {
      if (needs.includes(f)) throw new Error(`${cls}: operand ${f} is needed but cannot be recovered`);
      inv[f] = null;
    } else inv[f] = { k: s.c, t: Object.entries(s.t) };
  }
  return inv;
}

// ---- main ----------------------------------------------------------------------------------------------------------------------------------

const classes = [];
for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.cs')).sort()) {
  const src = fs.readFileSync(path.join(dir, file), 'utf8').replace(/^﻿/, '');
  const re = /public class (\w+) : VOpcode\s*\{/g;
  let m;
  while ((m = re.exec(src))) {
    const open = m.index + m[0].length - 1;
    const close = matchBrace(src, open);
    const body = src.slice(open + 1, close);
    const name = m[1];
    if (name === 'OpMutated' || name === 'OpSuperOperator') continue;
    // skip commented-out classes: the class header is on a // line
    const lineStart = src.lastIndexOf('\n', m.index) + 1;
    if (/^\s*\/\//.test(src.slice(lineStart, m.index + 2))) continue;

    const isM = /IsInstruction\(Instruction instruction\)\s*=>\s*([^;]+);/.exec(body);
    if (!isM) throw new Error(`${name}: no IsInstruction`);
    const pred = parsePredicate(isM[1]);

    let getM = /GetObfuscated\(ObfuscationContext context\)\s*=>([\s\S]*?);\s*(?:public|\}|$)/.exec(body);
    let text;
    if (/GetObfuscated\(ObfuscationContext context\)\s*\{/.test(body)) {
      const o = body.search(/GetObfuscated\(ObfuscationContext context\)\s*\{/);
      const b0 = body.indexOf('{', o);
      text = firstStringLiteral(body.slice(b0, matchBrace(body, b0)));
    } else {
      const o = body.search(/GetObfuscated\(ObfuscationContext context\)\s*=>/);
      text = firstStringLiteral(body.slice(o));
    }
    if (text == null) throw new Error(`${name}: no handler text`);

    let mutate = { state: { A: lin(0, { A0: 1 }), B: lin(0, { B0: 1 }), C: lin(0, { C0: 1 }) }, type: null };
    const mm = /public override void Mutate\(Instruction (\w+)\)\s*(=>[^;]+;|\{)/.exec(body);
    if (mm) {
      if (mm[2] === '{') mutate = parseMutate(body.slice(mm.index + mm[0].length, matchBrace(body, mm.index + mm[0].length - 1)));
      else mutate = parseMutate(mm[2]);
    }
    let needs = NEEDS[pred.op];
    if (needs === undefined) throw new Error(`${name}: unknown opcode ${pred.op}`);
    // IronBrew 2 itself loses the operand here (it stores A plus the raw batch word in B), so the chunk cannot be rebuilt
    const lossy = LOSSY[name] || null;
    if (lossy) needs = needs.replace(lossy, '');
    const inv = solve(mutate.state, pred, needs, name);
    classes.push({ name, op: pred.op, needs: NEEDS[pred.op], text: text.replace(/\r/g, '').trim(), inv, upvalues: pred.upvalueCount, mutated: mutate.type, ...(lossy ? { lossy } : {}) });
  }
}

const header = `// GENERATED by tools/build-ib2-templates.mjs from IronBrew 2's Obfuscator/Opcodes/*.cs. Do not edit.
//
// IronBrew 2: Copyright (c) 2019 DefCon42, MIT License, https://github.com/Trollicus/ironbrew-2 (notice in THIRD_PARTY_NOTICES.md).
// \`text\` is the Lua handler each virtual opcode emits into the VM; \`inv\` undoes the operand transform that
// IronBrew 2's Serializer applies (see the build script for how it is derived). Operands are expressed over
// sA, sB, sC (the serialised A, B, C) and PC (index of the instruction); k is a constant.

`;
fs.writeFileSync(out, `${header}export const IB2_CLASSES = ${JSON.stringify(classes, null, 1)};\n`);
console.log(`${classes.length} classes written to ${path.relative(process.cwd(), out)}`);
