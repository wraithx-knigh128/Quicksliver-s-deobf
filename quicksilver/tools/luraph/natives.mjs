#!/usr/bin/env node
// Test 8 (Prompt XXV): the functions a Luraph 14.x script keeps OUTSIDE its virtual machine.
//
// A Luraph 14.x "handler table" output is `return({ name = function(...) ... end, ... }):entry()(...)`. Most entries are the VM's own
// machinery; the program is an encoded payload (LPH...) the VM decrypts with a key it derives while it runs. But functions the author marked
// LPH_NO_VIRTUALIZE (and closures Luraph chose not to virtualise) are kept as plain Lua: a factory `function(cells) local a = cells[k] ...
// return function(...) <the author's code> end end`, whose upvalues are boxes read as `a[1][a[3]]`. Those are recovered here as they are.
//
//   node tools/luraph/natives.mjs <cleaned-output.lua> [--out file]
//
// The input is the recovery pipeline's output (constants folded, names made readable). For reading only, each box access `a[1][a[3]]` is
// shown as a named upvalue (`upvalue_a`); the factories are otherwise printed unchanged. This is a view of what the file contains, not the
// program: the code that creates the boxes and calls these functions is inside the encrypted payload.

import fs from 'node:fs';
import { parse } from '../../src/core/parser.js';
import { print } from '../../src/core/printer.js';

const PROGRAM = /\b(GetService|Enabled|Character|Humanoid|task\.|tick\(|Instance\.new|Players|LocalPlayer|workspace|game[.:]|_G\.|Drawing|Vector3|CFrame|Color3|TweenService|RunService|UserInputService|Heartbeat|RenderStepped|FindFirstChild|Connect|Enum\.)\b/;

function handlerTable(ast) {
  let best = null;
  const visit = (n) => {
    if (!n || typeof n !== 'object') return;
    if (n.type === 'Table' && n.fields && n.fields.length > 40 && (!best || n.fields.length > best.fields.length)) best = n;
    for (const k of Object.keys(n)) { const v = n[k]; if (Array.isArray(v)) v.forEach(visit); else if (v && typeof v === 'object' && k !== 'line') visit(v); }
  };
  visit(ast);
  return best;
}

/** `x[1][x[3]]` -> `upvalue_x` (read and write): Luraph's upvalue box, shown as the variable it stands for. */
function showBoxes(node, slots = new Map()) {
  if (!node || typeof node !== 'object') return node;
  if (Array.isArray(node)) return node.map((x) => showBoxes(x, slots));
  // the factory's `local a = param[k]`: box a holds upvalue slot k
  if (node.type === 'Func' && node.params.length === 1) {
    const p = node.params[0].name;
    for (const s of node.body) {
      if (s.type === 'Local' && s.ids.length === 1 && s.values[0] && s.values[0].type === 'Index' && s.values[0].obj.type === 'Name' && s.values[0].obj.name === p && s.values[0].key.type === 'Number') slots.set(s.ids[0].name, s.values[0].key.value);
    }
  }
  if (node.type === 'Index' && node.obj.type === 'Index' && node.obj.obj.type === 'Name' && node.obj.key.type === 'Number' && node.obj.key.value === 1
    && node.key.type === 'Index' && node.key.obj.type === 'Name' && node.key.obj.name === node.obj.obj.name && node.key.key.type === 'Number' && node.key.key.value === 3) {
    const slot = slots.get(node.obj.obj.name);
    return { type: 'Name', name: slot === undefined ? `upvalue_${node.obj.obj.name}` : `upvalue${slot}` };
  }
  const o = {};
  for (const k of Object.keys(node)) o[k] = showBoxes(node[k], slots);
  return o;
}

export function extractNatives(source) {
  const ast = parse(source);
  const tbl = handlerTable(ast);
  if (!tbl) return { functions: [], total: 0 };
  const out = [];
  let total = 0;
  for (const f of tbl.fields) {
    if (!f.value || f.value.type !== 'Func') continue;
    total++;
    const text = print({ type: 'Chunk', body: [{ type: 'Return', values: [f.value] }] });
    if (!PROGRAM.test(text)) continue;
    const key = typeof f.key === 'string' ? f.key : f.key ? (f.key.value ?? f.key.name ?? '?') : '?';
    out.push({ key: String(key), raw: text, view: print({ type: 'Chunk', body: [{ type: 'Return', values: [showBoxes(f.value)] }] }) });
  }
  return { functions: out, total };
}

if (process.argv[1] && process.argv[1].endsWith('natives.mjs')) {
  const [file] = process.argv.slice(2);
  const outIdx = process.argv.indexOf('--out');
  const r = extractNatives(fs.readFileSync(file, 'latin1'));
  const text = [`-- ${r.functions.length} of the ${r.total} functions in the handler table are plain Lua (not virtualised) and contain program code.`,
    '-- Upvalue boxes x[1][x[3]] are shown as upvalueK, K being the box\u2019s slot in the factory\u2019s argument (a reading aid: this file is a view, not a runnable program).',
    '-- What creates the boxes and calls these functions is inside the encrypted VM payload, which is NOT recovered.', '',
    ...r.functions.map((f) => `-- handler-table entry "${f.key}"\nlocal factory_${f.key.replace(/\W/g, '_')} = ${f.view.replace(/^return /, '')}\n`)].join('\n');
  if (outIdx > 0) fs.writeFileSync(process.argv[outIdx + 1], text); else process.stdout.write(text);
  console.error(`${r.functions.length} native function(s) of ${r.total}`);
}
