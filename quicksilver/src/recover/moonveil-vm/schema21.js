// MoonVeil 2.1.0: the layout of a function in the program data, read off the build's own function reader.
//
// Every build writes its reader differently: the marker byte of a function, the order of the sections after the instructions, the numbers of the constant
// tags, the slots an instruction's operands go to and the operand layout of each opcode all change (sample 6 and sample 7 share none of them). So nothing
// here is a constant of "the format": the reader (one factory of MoonVeil's table, ~650 lines once moonveil-cff.js has undone its flattening) is taken apart
// statement by statement, and each statement is recognised by what it does:
//
//   a LEB128 integer     a `repeat` that reads a byte, adds `band(b, 127) << 7k` and stops when `band(b, 128)` is 0
//   a byte               a single `unpack("B", data, pos)`
//   the marker           `if m ~= N then <stub: two strings> return {...} end`
//   a counted list       `if not (1 > n) then repeat ... until i > n end`, after the integer n; what is in it says what it is:
//                          a decision tree on the byte just read  -> the instructions; the tree, evaluated per opcode, gives each one's operands
//                          `"<d"`                                 -> the constants; each `tag == N` branch is classified by what it computes
//                          `"c" .. n`                             -> a list of strings
//                          a call of the reader itself            -> the nested functions
//
// The schema is then used by readProgram21 to read the data, and the reading is checked: the data must be consumed exactly, every opcode must have a layout,
// every constant index must exist. Two independent builds read to the last byte (tests/xv-targets.test.mjs), which is the evidence that the schema is right.

import { print } from '../../core/printer.js';
import { walk } from '../../core/walk.js';
import { partial } from '../zartha-vm.js';

export class Schema21Error extends Error {}
const fail = (m) => { throw new Schema21Error(m); };

// numbers are compared by value: the tree keeps each literal as it was written (`0xc0`, `0b1011`), so the text is printed from a copy without the spellings
const plain = (n) => JSON.parse(JSON.stringify(n, (k, v) => (k === 'raw' ? undefined : v)));
const text = (n) => print({ type: 'Chunk', body: plain(Array.isArray(n) ? n : [n]), endComments: [], features: new Set() });
const exprText = (e) => text({ type: 'Return', values: [e] }).replace(/^return /, '');
const isByteRead = (n, fmt = /^[bB]$/) => n && n.type === 'Call' && n.args.length >= 1 && n.args[0].type === 'String' && fmt.test(n.args[0].value);

/** The reader: the function that tests a marker byte against a number and reads constants with "<d". */
export function findReader(ast) {
  let found = null;
  walk(ast, (n) => {
    if (found || n.type !== 'Func') return undefined;
    const t = text(n.body);
    if (/"<d"/.test(t) && /~= \d+ then/.test(t) && /"c" \.\./.test(t) && n.body.length > 10) { found = n; return false; }
    return undefined;
  });
  if (!found) return null;
  // the factory returns the reader: `return function() ... end`
  const inner = found.body.length === 1 && found.body[0].type === 'Return' && found.body[0].values[0] && found.body[0].values[0].type === 'Func' ? found.body[0].values[0] : found;
  return inner;
}

function classifyTag(body) {
  const t = text(body);
  if (/"<i" \.\./.test(t)) return 'int';
  if (/"<d"/.test(t)) return 'f64';
  if (/\b1 \/ -0\b/.test(t) || /-1 \/ 0\b/.test(t)) return '-inf';
  if (/\b0 \/ 0\b/.test(t)) return 'nan';
  if (/\b1 \/ 0\b/.test(t)) return '+inf';
  if (/, 128\)/.test(t) && /\[\w+\]$/m.test(t.trim())) return 'string';
  if (/, 128\)/.test(t)) return 'string';
  if (/\btrue\b/.test(t)) return 'true';
  if (/\bfalse\b/.test(t)) return 'false';
  return null;
}

/** The constant tags: `if tag == N then ... elseif` chains, possibly nested in `else` branches. */
function constantTags(loop) {
  const tags = new Map();
  const visit = (stmts) => {
    for (const s of stmts) {
      if (s.type !== 'If') continue;
      for (const c of s.clauses) {
        const m = c.cond.type === 'Binary' && c.cond.op === '==' && c.cond.right.type === 'Number' ? c.cond.right.value : null;
        if (m !== null) { const k = classifyTag(c.body); if (k) tags.set(m, k); visit(c.body); }
      }
      if (s.orelse) visit(s.orelse);
    }
  };
  visit(loop.body);
  return tags;
}

/** The operand layout of every opcode: the decision tree after the opcode read, evaluated per value (two levels: opcode -> class, class -> reads). */
function opcodeLayouts(loop) {
  const at = loop.body.findIndex((s) => (s.type === 'Assign' || s.type === 'Local') && isByteRead((s.values || [])[0], /^B$/));
  if (at < 0) fail('the instruction loop does not read an opcode byte');
  const s0 = loop.body[at];
  const opVar = (s0.targets || s0.ids)[0].name;
  const rest = loop.body.slice(at + 1);
  const layouts = new Map();
  let slotOf = null;
  for (let v = 0; v < 256; v++) {
    let leaf;
    try { leaf = partial(rest, opVar, v); } catch { continue; }
    const cls = leaf.find((s) => s.type === 'Assign' && s.targets.length === 1 && s.targets[0].type === 'Name' && s.values[0].type === 'Number');
    let leaf2 = leaf;
    if (cls) { try { leaf2 = partial(leaf, cls.targets[0].name, cls.values[0].value); } catch { continue; } }
    const order = [];
    walk(leaf2, (n) => {
      if (isByteRead(n)) order.push({ fmt: n.args[0].value });
      if (n.type === 'Assign') for (const t of n.targets) if (t.type === 'Index' && t.key.type === 'Number' && t.obj.type === 'Name') order.push({ slot: t.key.value });
      return undefined;
    });
    // the instruction table: `{ [k] = opcode, [other] = 0, ... }` gives the slot the opcode itself is kept in
    if (slotOf === null) walk(leaf, (n) => { if (slotOf === null && n.type === 'Table') { const f = n.fields.find((x) => x.kind === 'keyed' && x.value.type === 'Name' && x.value.name === opVar); if (f) slotOf = f.key.value; } });
    const ops = [];
    let pending = null;
    for (const e of order) { if (e.fmt) pending = e.fmt; else if (pending) { ops.push([e.slot, pending]); pending = null; } }
    layouts.set(v, ops);
  }
  return { layouts, opcodeSlot: slotOf };
}

const isVarint = (s) => s.type === 'Repeat' && /, 128\)/.test(text(s)) && /\("B"/.test(text(s)) && /\* 7/.test(text(s));

/** The schema of one build. */
export function deriveSchema21(ast) {
  const reader = findReader(ast);
  if (!reader) fail('the function reader (a function that tests a marker byte and reads "<d" constants) was not found');
  const steps = [];
  let marker = null;
  let stubStrings = 0;
  for (const s of reader.body) {
    const t = text(s);
    if (s.type === 'If' && /~= (\d+) then/.test(t) && /return \{/.test(t) && marker === null) {
      marker = +/~= (\d+) then/.exec(t)[1];
      stubStrings = (t.match(/"c" \.\./g) || []).length;
      if (steps.length && steps[steps.length - 1].kind === 'byte') steps.pop();     // the byte the marker is read into
      continue;
    }
    if (isVarint(s)) { steps.push({ kind: 'varint' }); continue; }
    if ((s.type === 'Local' || s.type === 'Assign') && (s.values || []).some((v) => isByteRead(v))) { steps.push({ kind: 'byte' }); continue; }
    if (s.type === 'If' && /^if not \(1 > \w+\) then/.test(t) && s.clauses[0].body.some((x) => x.type === 'Repeat')) {
      const loop = s.clauses[0].body.find((x) => x.type === 'Repeat');
      const lt = text(loop);
      if (/"<d"/.test(lt)) steps.push({ kind: 'constants', tags: constantTags(loop) });
      else if (loop.body.some((x) => x.type === 'If' && x.clauses.length && !/, 128\)/.test(exprText(x.clauses[0].cond)) && /[<>]=? \d+/.test(exprText(x.clauses[0].cond)))) steps.push({ kind: 'instructions', ...opcodeLayouts(loop) });
      else if (/"c" \.\./.test(lt)) steps.push({ kind: 'strings' });
      else if (/\[\d+\]\[\d+\]\(\)/.test(lt)) steps.push({ kind: 'functions' });
      else if (/~= 0 and/.test(lt)) steps.push({ kind: 'resolve', slots: [...lt.matchAll(/(\w+)\[(\d+)\] = \1\[\2\] ~= 0 and/g)].map((m) => +m[2]) });
      else fail(`a counted list of a kind this reader does not know: ${lt.slice(0, 120)}`);
      continue;
    }
    if (s.type === 'Return') break;
  }
  if (marker === null) fail('the reader has no marker test');
  const kinds = steps.map((x) => x.kind);
  if (!kinds.includes('instructions') || !kinds.includes('constants') || !kinds.includes('functions')) fail(`the reader's sections are incomplete: ${kinds.join(', ')}`);
  return { marker, stubStrings, steps };
}

/** The program data (the output of the LZSS stage) read with a schema: the string table, then the main function and the functions in it. */
export function readProgram21(bytes, schema) {
  let p = 0;
  const byte = () => { if (p >= bytes.length) fail('the data ends early'); return bytes[p++]; };
  const varint = () => { let n = 0; for (let k = 0; k < 5; k++) { const b = byte(); n += (b & 127) * 2 ** (7 * k); if (!(b & 128)) return n; } return n; };
  const string = () => { const n = varint(); if (p + n > bytes.length) fail('a string runs past the end of the data'); let s = ''; for (let k = 0; k < n; k++) s += String.fromCharCode(bytes[p + k]); p += n; return s; };
  const strings = [];
  for (let i = varint(); i > 0; i--) strings.push(string());
  const stats = { functions: 0, natives: 0, instructions: 0, constants: 0 };
  const fn = (depth) => {
    if (depth > 200) fail('functions nested too deeply');
    const m = byte();
    if (m !== schema.marker) { for (let k = 0; k < Math.max(1, schema.stubStrings); k++) string(); stats.natives++; return { native: true }; }
    stats.functions++;
    const f = { code: [], strings: [], k: [], protos: [], ints: [], bytes: [] };
    let count = null;
    for (const st of schema.steps) {
      if (st.kind === 'varint') { const v = varint(); if (count !== null) f.ints.push(count); count = v; continue; }
      if (st.kind === 'byte') { f.bytes.push(byte()); continue; }
      const n = count ?? 0;
      count = null;
      if (st.kind === 'instructions') {
        for (let i = 0; i < n; i++) {
          const op = byte();
          const lay = st.layouts.get(op);
          if (!lay) fail(`opcode ${op} has no layout in this build`);
          const ins = { op };
          for (const [slot, fmt] of lay) { const b = byte(); ins[slot] = fmt === 'b' && b > 127 ? b - 256 : b; }
          f.code.push(ins);
        }
        stats.instructions += n;
      } else if (st.kind === 'strings') {
        for (let i = 0; i < n; i++) f.strings.push(string());
      } else if (st.kind === 'constants') {
        for (let i = 0; i < n; i++) {
          const tag = byte();
          const kind = st.tags.get(tag);
          let c = null;
          if (kind === '+inf') c = Infinity; else if (kind === '-inf') c = -Infinity; else if (kind === 'nan') c = NaN;
          else if (kind === 'f64') { if (p + 8 > bytes.length) fail('a number runs past the end'); c = new DataView(bytes.buffer, bytes.byteOffset + p, 8).getFloat64(0, true); p += 8; }
          else if (kind === 'string') { const ix = varint(); if (ix < 1 || ix > strings.length) fail(`a constant names string ${ix} of ${strings.length}`); c = { string: ix }; }
          else if (kind === 'int') { const w = byte(); let v = 0; for (let q = w - 1; q >= 0; q--) v = v * 256 + bytes[p + q]; if (w && bytes[p + w - 1] > 127) v -= 2 ** (8 * w); p += w; c = v; }
          else if (kind === 'true') c = true; else if (kind === 'false') c = false;
          f.k.push(c);
        }
        stats.constants += n;
      } else if (st.kind === 'functions') {
        for (let i = 0; i < n; i++) f.protos.push(fn(depth + 1));
      }
    }
    if (count !== null) f.ints.push(count);
    return f;
  };
  const main = fn(0);
  if (p !== bytes.length) fail(`the program is read and ${bytes.length - p} byte(s) are left over: the schema does not fit this data`);
  return { strings, main, stats };
}
