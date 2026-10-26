// MoonVeil (moonveil.cc, closed source), as seen in one build: "generated using MoonVeil 2.0.25".
//
// What that build does to a script, read from its output (nothing in this file was taken from the vendor; the vendor's public documentation
// only names the macros MV_VM, MV_ENC_FUNC, MV_CFF and MV_OMIT):
//   * every function is lifted into one table, `return ({ function(_, a) return function() ... end end, ... })`, and the variables a function
//     shares with others live in two-slot "cells" `{ [1] = 3, [3] = value, [2] = itself }`, read as `a[n][2][a[n][1]]`;
//   * the table also holds the helpers, under one- and two-letter names that a bootstrap (`ve`) assigns from a permutation of the function list:
//     the function at position h + 1 is called names[(M * h + K) % #names + 1], with M and K in the bootstrap's code;
//   * strings are cut into two Z85 (RFC 1924 alphabet) texts, a cipher and a key, and decrypted by an XOR with the repeating key; numbers are
//     written as bit32 expressions over two constants; both are cached in tables under a numeric id, `cache[id] or self:wrapper(a, b, id)`;
//   * some functions are flattened (`while true do if j > ... then`), and chosen functions are compiled to a VM whose program is one more
//     Z85 text, compressed, handed to a runtime (`Pe(De(Ae(blob)), env)`).
//
// This module undoes the second and third items statically: it finds the permutation, evaluates the number wrappers (closed bit32
// arithmetic, in the same order and precision as the script would) and decrypts the string wrappers, and replaces each call by its value. It never
// runs the script. It does not touch the VM blobs: that part of a MoonVeil script is not recovered.

import { walk, transform, structuralKey } from '../core/walk.js';

const Z85 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~';
const u32 = (x) => x >>> 0; // Luau's bit32 truncates toward zero and wraps modulo 2^32, as ToUint32 does
const BIT = { band: (a, b) => u32(u32(a) & u32(b)), bor: (a, b) => u32(u32(a) | u32(b)), bxor: (a, b) => u32(u32(a) ^ u32(b)), bnot: (a) => u32(~u32(a)) };

/** Z85 text to bytes the way the script's decoder does it: pad to a multiple of five with the last digit, decode, drop the padding. */
export function z85Decode(text) {
  const pad = (5 - (text.length % 5)) % 5;
  const t = text + '~'.repeat(pad);
  const out = [];
  for (let i = 0; i < t.length; i += 5) {
    let v = 0;
    for (let k = 0; k < 5; k++) { const d = Z85.indexOf(t[i + k]); if (d < 0) throw new Error('not Z85'); v = v * 85 + d; }
    out.push((v >>> 24) & 255, (v >>> 16) & 255, (v >>> 8) & 255, v & 255);
  }
  // in pieces: spreading a hundred thousand arguments overflows the (smaller) stack of a worker
  let text2 = '';
  const end = out.length - pad;
  for (let i = 0; i < end; i += 4096) text2 += String.fromCharCode.apply(null, out.slice(i, Math.min(end, i + 4096)));
  return text2;
}

/** XOR with the repeating key. `reversed`: the key is read from its last byte backwards (key[#key - i % #key]), as one of the two ciphers a build carries does. */
export function xorDecrypt(cipher, key, reversed = false) {
  let out = '';
  for (let i = 0; i < cipher.length; i++) out += String.fromCharCode(cipher.charCodeAt(i) ^ key.charCodeAt(reversed ? key.length - 1 - (i % key.length) : i % key.length));
  return out;
}

const isNum = (e) => e && e.type === 'Number';
const numberOf = (e) => (e.type === 'Number' ? e.value : e.type === 'Unary' && e.op === '-' && e.arg.type === 'Number' ? -e.arg.value : null);

/** The root of a MoonVeil script: `return ({ ...functions... }):builder({ names }, entry, ...)`, at the top or inside a wrapper function. */
export function findRoot(ast) {
  let found = null;
  walk(ast, (n) => {
    if (found || n.type !== 'Return' || n.values.length !== 1) return found ? false : undefined;
    const call = n.values[0];
    if (call.type !== 'MethodCall') return undefined;
    const table = call.obj.type === 'Paren' ? call.obj.expr : call.obj;
    if (table.type !== 'Table') return undefined;
    const names = call.args[0];
    if (!names || names.type !== 'Table' || !names.fields.length || !names.fields.every((f) => f.kind === 'item' && f.value.type === 'String')) return undefined;
    found = { call, table, names: names.fields.map((f) => f.value.value), builder: call.name };
    return false;
  });
  return found;
}

/** Is this the table script the module reads? True only when the bootstrap's permutation can be recovered and is one-to-one. */
export function moonveilShape(ast) {
  const root = findRoot(ast);
  return !!root && !!nameMap(root);
}

/** The constants of the bootstrap's permutation, found by the shape of its code: `a, d = K, a * h` after `.., a = .., M`. */
function permutationConstants(builder) {
  let mul = null;
  let add = null;
  let counter = null;
  walk(builder, (n) => {
    if (n.type !== 'Assign' || n.targets.length !== 2 || n.values.length !== 2) return;
    const [t0, t1] = n.targets;
    const [v0, v1] = n.values;
    if (t0.type === 'Name' && t1.type === 'Name' && isNum(v0) && v1.type === 'Binary' && v1.op === '*'
      && v1.left.type === 'Name' && v1.left.name === t0.name && v1.right.type === 'Name') { add = { name: t0.name, value: v0.value }; counter = v1.right.name; }
  });
  if (!add) return null;
  walk(builder, (n) => {
    if (n.type !== 'Assign' || n.targets.length !== 2 || n.values.length !== 2) return;
    if (n.targets[1].type === 'Name' && n.targets[1].name === add.name && isNum(n.values[1]) && n.targets[0].type === 'Name') mul = n.values[1].value;
  });
  return mul === null ? null : { mul, add: add.value };
}

/** name -> the table entry the bootstrap stores under it. Null when the construction is not the one this module knows. */
export function nameMap(root) {
  const fn = root.table.fields.find((f) => f.kind === 'named' && f.key === root.builder);
  if (!fn || fn.value.type !== 'Func') return null;
  const k = permutationConstants(fn.value);
  if (!k) return null;
  const items = root.table.fields.filter((f) => f.kind === 'item').map((f) => f.value);
  const n = root.names.length;
  if (items.length !== n) return null;
  const map = new Map();
  for (let h = 0; h < n; h++) {
    const name = root.names[(k.mul * h + k.add) % n];
    if (map.has(name)) return null;
    map.set(name, items[h]);
  }
  for (const f of root.table.fields) if (f.kind === 'named') map.set(f.key, f.value);
  return map;
}

/**
 * The same names for the same table entries after the functions were rewritten in place (the entries keep their order, which is all the permutation
 * decides), for when the rewritten bootstrap is no longer in the shape `nameMap` reads.
 */
export function nameMapAfter(before, after, map = nameMap(before)) {
  if (!map) return null;
  const items = (r) => r.table.fields.filter((f) => f.kind === 'item').map((f) => f.value);
  const was = items(before);
  const now = items(after);
  if (was.length !== now.length) return null;
  const out = new Map();
  for (const [name, value] of map) {
    const i = was.indexOf(value);
    if (i >= 0) out.set(name, now[i]);
  }
  for (const f of after.table.fields) if (f.kind === 'named') out.set(f.key, f.value);
  return out;
}

const hasKey = (fn, key) => { let hit = false; walk(fn, (n) => { if (n.type === 'Index' && n.key.type === 'String' && n.key.value === key) hit = true; if (n.type === 'String' && n.value === key) hit = true; }); return hit; };
/**
 * Does the function compute `#x - i % n`? In a flattened body the three parts sit in separate statements, so: a name assigned `#x`, a name assigned
 * a remainder (or the remainder itself), and a subtraction of the second from the first.
 */
function subtractsRemainderFromLength(fn) {
  const lengths = new Set();
  const remainders = new Set();
  walk(fn, (n) => {
    if (n.type !== 'Assign') return;
    n.targets.forEach((t, i) => {
      const v = n.values[i];
      if (t.type !== 'Name' || !v) return;
      if (v.type === 'Unary' && v.op === '#') lengths.add(t.name);
      if (v.type === 'Binary' && v.op === '%') remainders.add(t.name);
    });
  });
  let found = false;
  walk(fn, (n) => {
    if (n.type !== 'Binary' || n.op !== '-') return;
    const l = n.left;
    const r = n.right;
    const lengthLike = (l.type === 'Name' && lengths.has(l.name)) || (l.type === 'Unary' && l.op === '#');
    const remainderLike = (r.type === 'Name' && remainders.has(r.name)) || (r.type === 'Binary' && r.op === '%');
    if (lengthLike && remainderLike) found = true;
  });
  return found;
}

const methodsCalled = (fn) => { const s = new Set(); walk(fn, (n) => { if (n.type === 'MethodCall') s.add(n.name); }); return s; };

/** Evaluates the closed bit32 / arithmetic expression of a number wrapper for given parameter values. Throws on anything else. */
function evaluate(e, env, ops) {
  switch (e.type) {
    case 'Number': return e.value;
    case 'Name': if (env.has(e.name)) return env.get(e.name); throw new Error('free name ' + e.name);
    case 'Paren': return evaluate(e.expr, env, ops);
    case 'Unary': if (e.op === '-') return -evaluate(e.arg, env, ops); throw new Error('unary ' + e.op);
    case 'Binary': {
      const a = evaluate(e.left, env, ops);
      const b = evaluate(e.right, env, ops);
      switch (e.op) {
        case '+': return a + b;
        case '-': return a - b;
        case '*': return a * b;
        case '%': return a - Math.floor(a / b) * b;
        default: throw new Error('operator ' + e.op);
      }
    }
    case 'Call': {
      if (e.fn.type !== 'Index' || e.fn.key.type !== 'String' || e.fn.obj.type !== 'Name') throw new Error('call');
      const op = ops.get(e.fn.key.value);
      if (!op) throw new Error('unknown helper ' + e.fn.key.value);
      return BIT[op](...e.args.map((a) => evaluate(a, env, ops)));
    }
    default: throw new Error('expression ' + e.type);
  }
}

/**
 * Replace `cache[id] or self:wrapper(...)` by the value it computes.
 * @returns {{changed:number, skipped?:string, strings:string[], numbers:number, undecoded:number}}
 */
export function decodeMoonVeilConstants(ast) {
  const root = findRoot(ast);
  if (!root) return { changed: 0, strings: [], numbers: 0, undecoded: 0 };
  const map = nameMap(root);
  if (!map) return { changed: 0, skipped: 'the bootstrap permutation was not recognised', strings: [], numbers: 0, undecoded: 0 };

  // the bit32 helpers stored under names: a = bit32.band, ...
  const ops = new Map();
  for (const [name, node] of map) {
    if (node.type === 'Index' && node.obj.type === 'Name' && node.obj.name === 'bit32' && node.key.type === 'String' && BIT[node.key.value]) ops.set(name, node.key.value);
  }
  // the Z85 decoder is the factory that (through two makers) reaches the function holding the alphabet
  let aeName = null;
  {
    const withAlphabet = [...map].find(([, f]) => f.type === 'Func' && hasKey(f, Z85))?.[0];
    const withPad = withAlphabet && [...map].find(([, f]) => f.type === 'Func' && methodsCalled(f).has(withAlphabet))?.[0];
    aeName = withPad && [...map].find(([, f]) => f.type === 'Func' && methodsCalled(f).has(withPad))?.[0];
  }
  if (!aeName) return { changed: 0, skipped: 'the Z85 string decoder was not found', strings: [], numbers: 0, undecoded: 0 };
  // XOR ciphers: factories that bind bit32.bxor, string.char and string.byte and build a closure through a maker
  // A build carries two of them: one reads the key forwards (key[i % #key + 1]), the other backwards (key[#key - i % #key]). The maker's inner
  // function tells which: the backwards one subtracts a remainder from the length.
  const xorMakers = new Map();
  for (const [name, f] of map) {
    if (f.type !== 'Func' || !hasKey(f, 'bxor') || !hasKey(f, 'char') || !hasKey(f, 'byte') || methodsCalled(f).size !== 1) continue;
    const [made] = methodsCalled(f);
    const inner = map.get(made);
    xorMakers.set(name, !!inner && subtractsRemainderFromLength(inner));
  }

  // wrappers: function(self, ...inputs, id) self.cache[id] = <expr or self:cipher(a, b)>; return self.cache[id] end
  const wrappers = new Map();
  for (const [name, f] of map) {
    if (f.type !== 'Func' || f.body.length !== 2 || f.params.length < 3) continue;
    const [asg, ret] = f.body;
    if (asg.type !== 'Assign' || asg.targets.length !== 1 || asg.values.length !== 1 || ret.type !== 'Return') continue;
    const t = asg.targets[0];
    const self = f.params[0].name;
    const idParam = f.params[f.params.length - 1].name;
    if (t.type !== 'Index' || t.key.type !== 'Name' || t.key.name !== idParam || t.obj.type !== 'Index' || t.obj.key.type !== 'String' || t.obj.obj.type !== 'Name' || t.obj.obj.name !== self) continue;
    const v = asg.values[0];
    const params = f.params.map((p) => p.name);
    if (v.type === 'Call' && v.fn.type === 'Index' && v.fn.obj.type === 'Name' && v.fn.obj.name === self && v.fn.key.type === 'String' && xorMakers.has(v.fn.key.value) && v.args.length === 2) wrappers.set(name, { reversed: xorMakers.get(v.fn.key.value), kind: 'string', cache: t.obj.key.value, params });
    else wrappers.set(name, { kind: 'number', cache: t.obj.key.value, params, expr: v });
  }

  const strings = [];
  let numbers = 0;
  let undecoded = 0;
  const aeCall = (a) => a.type === 'Call' && a.fn.type === 'Index' && a.fn.key.type === 'String' && a.fn.key.value === aeName && a.args.length === 1 && a.args[0].type === 'String';
  const replaced = new Map();

  const decode = (e) => {
    // cache[id] or self:wrapper(inputs..., id)
    if (e.type !== 'Binary' || e.op !== 'or' || e.right.type !== 'MethodCall') return undefined;
    const w = wrappers.get(e.right.name);
    if (!w || e.left.type !== 'Index' || e.left.obj.type !== 'Index' || e.left.obj.key.type !== 'String' || e.left.obj.key.value !== w.cache) return undefined;
    const args = e.right.args;
    if (args.length !== w.params.length - 1) return undefined;
    try {
      if (w.kind === 'string') {
        if (!(aeCall(args[0]) && aeCall(args[1]))) return undefined;
        const text = xorDecrypt(z85Decode(args[0].args[0].value), z85Decode(args[1].args[0].value), w.reversed);
        strings.push(text);
        return { type: 'String', value: text, raw: JSON.stringify(text), long: false };
      }
      const env = new Map(w.params.slice(1).map((p, i) => [p, numberOf(args[i])]));
      if ([...env.values()].some((v) => v === null)) return undefined;
      const value = evaluate(w.expr, env, ops);
      if (!Number.isFinite(value)) return undefined;
      numbers++;
      return value < 0 ? { type: 'Unary', op: '-', arg: { type: 'Number', value: -value, raw: String(-value) } } : { type: 'Number', value, raw: String(value) };
    } catch {
      undecoded++;
      return undefined;
    }
  };
  transform(ast, { expr(e) { const r = decode(e); if (r) replaced.set(e, r); return r; } });
  const changed = strings.length + numbers;
  return { changed, strings, numbers, undecoded, decoder: aeName, wrappers: wrappers.size, ciphers: [...xorMakers] };
}

/**
 * `a[n][2][a[n][1]]` is a cell read (and `a[n][2][a[n][1]] = v` a cell write): cells are `{ [1] = 3, [3] = value, [2] = itself }`, so both mean `a[n][3]`.
 * Only applied when every cell constructor in the script has that shape.
 */
export function simplifyCells(ast) {
  let cells = 0;
  let odd = 0;
  walk(ast, (n) => {
    if (n.type !== 'Table' || n.fields.length !== 2) return;
    const [a, b] = n.fields;
    if (a.kind === 'keyed' && b.kind === 'keyed' && a.key.type === 'Number' && b.key.type === 'Number' && a.key.value === 1 && b.key.value === 3) {
      cells++;
      if (!(a.value.type === 'Number' && a.value.value === 3)) odd++;
    }
  });
  if (!cells) return { changed: 0 };
  if (odd) return { changed: 0, skipped: 'a cell with another layout exists' };
  let changed = 0;
  transform(ast, {
    expr(e) {
      if (e.type !== 'Index' || e.key.type !== 'Index' || e.obj.type !== 'Index') return undefined;
      const slot = e.obj; // E[2]
      if (!(slot.key.type === 'Number' && slot.key.value === 2)) return undefined;
      const k = e.key; // E[1]
      if (!(k.key.type === 'Number' && k.key.value === 1)) return undefined;
      if (structuralKey(slot.obj) !== structuralKey(k.obj)) return undefined;
      changed++;
      return { type: 'Index', obj: slot.obj, key: { type: 'Number', value: 3, raw: '3' }, dot: false };
    },
  });
  return { changed };
}
