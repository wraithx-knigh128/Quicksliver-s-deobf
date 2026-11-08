// Lab: controlled transformations.
//
// "Known systems" here are the independent mutators that already exist for the adaptive tests, comment confetti, and stacked (nested) combinations
// of them. "Custom systems" are three small protectors written for this laboratory from the outside, against the syntax tree only, never against the
// recovery code, so that the engine has no rule for them:
//
//   xorpack      every string literal becomes a call of a local decoder that undoes a stream cipher (a linear congruential key stream added to the bytes)
//   loadwrap     the whole program becomes a list of byte values that a stub joins into text and hands to loadstring
//   tabledispatch the program's local functions move into a table and are called through it
//
// None of these is the output of a third-party tool, and the results say "lab-made custom system", never a tool's name.

import { parse } from '../../src/core/parser.js';
import { print } from '../../src/core/printer.js';
import { analyze } from '../../src/core/scope.js';
import { transform } from '../../src/core/walk.js';
import { rng, flatten, strings, opaque, proxies, junk, rename, wrap, obfuscate } from '../../tests/helpers/mutators.mjs';
import { confetti, SENTENCE } from '../../tests/helpers/confetti.mjs';

const printAst = (ast) => print(ast, { indent: '  ', width: 120, strings: 'preserve', numbers: 'preserve' });
const Nm = (name) => ({ type: 'Name', name });
const S = (value) => ({ type: 'String', value, raw: null });
const N = (value) => ({ type: 'Number', value, raw: null });

// ---- xorpack ------------------------------------------------------------------------------------------------------------------
function xorpack(source, seed = 1) {
  const r = rng(seed * 31 + 5);
  const key = r.int(100, 60000);
  const dec = `Z${r.int(10, 99)}x${r.int(10, 99)}`;
  const ast = parse(source);
  let count = 0;
  const encode = (text) => {
    let k = key;
    const out = [];
    for (let i = 0; i < text.length; i++) {
      k = (k * 75 + 74) % 65537;
      out.push((text.charCodeAt(i) + (k % 256)) % 256);
    }
    return out;
  };
  const out = transform(ast, {
    expr(e) {
      if (e.type === 'String' && e.value.length > 0) {
        count++;
        const call = { type: 'Call', fn: Nm(dec), args: [{ type: 'Table', fields: encode(e.value).map((b) => ({ kind: 'item', value: N(b) })) }, N(key)], sugar: null };
        return call;
      }
      return undefined;
    },
  });
  void out;
  // `a.b` keys and call sugar must stay as they were written: only expression strings were replaced above
  const decoder = parse(`local function ${dec}(t, k)
  local s = {}
  for i = 1, #t do
    k = (k * 75 + 74) % 65537
    s[i] = string.char((t[i] - (k % 256)) % 256)
  end
  return table.concat(s)
end`);
  ast.body = [...decoder.body, ...ast.body];
  return { code: printAst(ast), strings: count };
}

// ---- loadwrap -----------------------------------------------------------------------------------------------------------------
function loadwrap(source, seed = 1) {
  const r = rng(seed * 17 + 3);
  const bytes = Array.from(source, (c) => c.charCodeAt(0));
  const shift = r.int(1, 40);
  const names = ['p', 'q', 'u', 's'].map((n) => `${n}${r.int(10, 99)}`);
  const [list, out, i, fn] = names;
  const code = `local ${list} = { ${bytes.map((b) => b + shift).join(', ')} }
local ${out} = {}
for ${i} = 1, #${list} do ${out}[${i}] = string.char(${list}[${i}] - ${shift}) end
local ${fn} = loadstring(table.concat(${out}))
return ${fn}()
`;
  return { code };
}

// ---- tabledispatch -------------------------------------------------------------------------------------------------------------
function tabledispatch(source, seed = 1) {
  const r = rng(seed * 13 + 1);
  const ast = parse(source);
  const info = analyze(ast);
  // names of the kind a tool hands out, the same alphabet the rename mutator uses
  const alphabet = ['I', 'l', '1', 'O', '0'];
  const machine = () => `l${Array.from({ length: 6 }, () => r.pick(alphabet)).join('')}`;
  const table = machine();
  const moved = new Map();
  for (const v of info.vars) if (v.kind === 'localfunc' && v.funcDepth === 0) moved.set(v, `${machine()}${moved.size}`);
  if (!moved.size) return { code: source, moved: 0 };
  const names = new Map();
  for (const [v, nm] of moved) for (const n of [v.decl, ...v.reads, ...v.writes]) if (n) names.set(n, nm);
  const field = (nm) => ({ type: 'Index', obj: Nm(table), key: S(nm), dot: true });
  transform(ast, {
    expr(e) { if (e.type === 'Name' && names.has(e)) return field(names.get(e)); return undefined; },
    stmt(s) {
      if (s.type === 'LocalFunction' && names.has(s.id)) {
        return { type: 'Assign', targets: [field(names.get(s.id))], values: [s.func] };
      }
      return undefined;
    },
  });
  ast.body = [{ type: 'Local', ids: [{ type: 'Id', name: table }], values: [{ type: 'Table', fields: [] }] }, ...ast.body];
  return { code: printAst(ast), moved: moved.size };
}

// ---- the catalogue ------------------------------------------------------------------------------------------------------------
const m = (name, opts) => (src, seed) => obfuscate(src, [[name, opts || {}]], seed).code;
const seq = (...steps) => (src, seed) => steps.reduce((code, fn, i) => fn(code, seed + i), src);
const c = (fn) => (src, seed) => fn(src, seed).code;

export const confettiT = (src) => confetti(src, SENTENCE);

/** kind: known (an existing independent mutator), stacked (several in order), custom (written for this laboratory) */
export const TRANSFORMS = [
  { id: 'confetti', kind: 'known', label: 'comment confetti', apply: (s) => confettiT(s) },
  { id: 'flatten-chain', kind: 'known', label: 'control-flow flattening (if chain)', apply: m('flatten', { style: 'chain' }) },
  { id: 'flatten-tree', kind: 'known', label: 'control-flow flattening (search tree)', apply: m('flatten', { style: 'tree' }) },
  { id: 'flatten-seq', kind: 'known', label: 'control-flow flattening (sequential ifs)', apply: m('flatten', { style: 'seq' }) },
  { id: 'strings-indexed', kind: 'known', label: 'string table behind a decoder', apply: m('strings', { scheme: 'indexed' }) },
  { id: 'strings-inline', kind: 'known', label: 'inline byte-list strings', apply: m('strings', { scheme: 'inline' }) },
  { id: 'opaque', kind: 'known', label: 'opaque predicates', apply: m('opaque') },
  { id: 'proxies', kind: 'known', label: 'operator and call proxies', apply: m('proxies') },
  { id: 'junk', kind: 'known', label: 'junk statements', apply: m('junk') },
  { id: 'rename', kind: 'known', label: 'machine-made local names', apply: m('rename') },
  { id: 'wrap', kind: 'known', label: 'wrapper function', apply: m('wrap') },
  { id: 'xorpack', kind: 'custom', label: 'lab custom: stream-cipher strings', apply: c(xorpack) },
  { id: 'loadwrap', kind: 'custom', label: 'lab custom: program as bytes behind loadstring', apply: c(loadwrap) },
  { id: 'tabledispatch', kind: 'custom', label: 'lab custom: functions called through a table', apply: c(tabledispatch) },
  { id: 'stack-rename-strings', kind: 'stacked', label: 'renamed locals + string table', apply: seq(m('rename'), m('strings', { scheme: 'indexed' })) },
  { id: 'stack-flatten-opaque', kind: 'stacked', label: 'flattening + opaque predicates', apply: seq(m('flatten', { style: 'chain' }), m('opaque')) },
  { id: 'stack-wrap-flatten-junk', kind: 'stacked', label: 'wrapper + flattening + junk', apply: seq(m('wrap'), m('flatten', { style: 'tree' }), m('junk')) },
  { id: 'stack-confetti-rename-strings', kind: 'stacked', label: 'confetti over renamed locals and a string table', apply: (s, seed) => confettiT(seq(m('rename'), m('strings', { scheme: 'inline' }))(s, seed)) },
  { id: 'stack-xorpack-loadwrap', kind: 'stacked', label: 'lab custom: stream-cipher strings inside a loadstring wrapper', apply: seq(c(xorpack), c(loadwrap)) },
  { id: 'stack-tabledispatch-rename-proxies', kind: 'stacked', label: 'lab custom: table dispatch + renamed locals + proxies', apply: seq(c(tabledispatch), m('rename'), m('proxies')) },
];

export const transformById = (id) => TRANSFORMS.find((t) => t.id === id);
