// Which Lua is this written for?
//
// The parser records every dialect-specific construct it meets (parser.js `features`), the lexer's raw
// string literals reveal escape forms, and the global names a script uses reveal its runtime. Each piece
// of evidence supports some dialects and rules out others; the answer lists every dialect that is still
// consistent with the evidence, with the most specific one first.

const LUAU_GLOBALS = ['game', 'workspace', 'script', 'Instance', 'Enum', 'task', 'typeof', 'Vector3', 'CFrame', 'Color3', 'UDim2', 'tick', 'warn', 'wait', 'spawn', 'delay', 'bit32', 'Random', 'shared'];
const LUAJIT_GLOBALS = ['jit', 'ffi', 'bit'];
const LUA52_GLOBALS = ['bit32'];

/**
 * @param {Set<string>} features parser feature flags
 * @param {Set<string>} globals  names of free identifiers used by the script
 * @param {string} src
 */
export function detectDialect(features, globals, src) {
  const evidence = [];
  const score = { luau: 0, lua51: 0, luajit: 0, lua52: 0, lua53: 0, lua54: 0 };
  const ruledOut = new Set();
  const add = (list, why, weight = 3) => { for (const d of list) score[d] += weight; evidence.push(why); };
  const only = (keep, why) => {
    for (const d of Object.keys(score)) if (!keep.includes(d)) ruledOut.add(d);
    evidence.push(why);
  };

  // syntax only available in one family
  if (features.has('continue')) only(['luau'], '`continue` statement (Luau)');
  if (features.has('compound-assign')) only(['luau'], 'compound assignment (+=, ..=) (Luau)');
  if (features.has('type-annotation')) only(['luau'], 'type annotations (Luau)');
  if (features.has('if-expression')) only(['luau'], 'if-then-else expressions (Luau)');
  if (features.has('interp-string')) only(['luau'], 'interpolated strings (Luau)');
  if (features.has('type-assert')) only(['luau'], 'type assertion `::` (Luau)');
  if (features.has('luau-number')) only(['luau'], 'binary literals or `_` digit separators (Luau)');
  if (features.has('attribute')) only(['luau'], 'function attributes (@native / @checked) (Luau)');
  if (features.has('attrib')) only(['lua54'], '`<const>` / `<close>` attributes (Lua 5.4)');
  if (features.has('bitops')) only(['lua53', 'lua54'], 'bitwise operators (Lua 5.3+)');
  if (features.has('goto') || features.has('label')) only(['lua52', 'lua53', 'lua54', 'luajit'], 'goto / labels (Lua 5.2+, LuaJIT; Luau has no goto)');
  if (features.has('floordiv')) only(['luau', 'lua53', 'lua54'], '`//` operator (Luau, Lua 5.3+)');

  // escape forms in string literals
  if (/\\z|\\u\{/.test(src) && !features.has('type-annotation')) {
    if (/\\u\{/.test(src)) evidence.push('\\u{...} escapes (Lua 5.3+, Luau)');
    else evidence.push('\\z escapes (Lua 5.2+, Luau)');
  }

  // runtime library
  const hasAny = (names) => names.filter((n) => globals.has(n));
  const luau = hasAny(LUAU_GLOBALS.filter((n) => n !== 'bit32' && n !== 'shared'));
  if (luau.length) add(['luau'], `Roblox / Luau globals used: ${luau.slice(0, 5).join(', ')}`, 2 + Math.min(luau.length, 4));
  const jit = hasAny(LUAJIT_GLOBALS);
  if (jit.length) add(['luajit'], `LuaJIT globals used: ${jit.join(', ')}`, 4);
  if (globals.has('bit32')) add(['luau', 'lua52'], '`bit32` library (Luau, Lua 5.2)', 2);
  if (globals.has('utf8') || (globals.has('math') && /math\.(tointeger|ult)|table\.move|string\.pack/.test(src))) add(['lua53', 'lua54'], '5.3+ standard library functions', 3);
  if (globals.has('setfenv') || globals.has('getfenv') || globals.has('loadstring') || globals.has('unpack') || globals.has('newproxy')) {
    add(['lua51', 'luajit', 'luau'], 'uses 5.1-style globals (setfenv / getfenv / loadstring / unpack)', 1);
  }
  if (/\bmodule\s*\(/.test(src) && globals.has('module')) add(['lua51'], '`module(...)` (Lua 5.1)', 2);

  const order = Object.keys(score)
    .filter((d) => !ruledOut.has(d))
    .sort((a, b) => score[b] - score[a] || ['luau', 'luajit', 'lua51', 'lua52', 'lua53', 'lua54'].indexOf(a) - ['luau', 'luajit', 'lua51', 'lua52', 'lua53', 'lua54'].indexOf(b));

  const compatible = order.filter((d) => {
    if (d === 'lua51') return !['goto', 'label', 'bitops', 'floordiv', 'attrib'].some((f) => features.has(f)) && ![...features].some((f) => ['continue', 'compound-assign', 'type-annotation', 'if-expression', 'interp-string', 'type-assert', 'luau-number', 'attribute'].includes(f));
    return true;
  });

  const decisive = [...features].some((f) => ['continue', 'compound-assign', 'type-annotation', 'if-expression', 'interp-string', 'type-assert', 'luau-number', 'attribute', 'attrib', 'bitops'].includes(f));
  const label = { luau: 'Luau', lua51: 'Lua 5.1', luajit: 'LuaJIT (Lua 5.1 + ext.)', lua52: 'Lua 5.2', lua53: 'Lua 5.3', lua54: 'Lua 5.4', generic: 'Plain Lua (nothing dialect-specific)' };
  const best = order[0] || 'lua51';
  const top = score[best];
  // With no syntax or library evidence that singles a dialect out, naming one would be a guess dressed as a finding.
  if (!decisive && top < 3) {
    const list = compatible.map((d) => ({ id: d, label: label[d] }));
    if (ruledOut.size === 0) {
      evidence.unshift('no dialect-specific syntax: a plain Lua 5.1 subset, valid in several runtimes');
      return { id: 'generic', label: label.generic, confidence: 0.9, compatible: list, evidence };
    }
    return { id: 'ambiguous', label: `One of ${list.map((d) => d.label).join(', ')}`, confidence: 0.9, compatible: list, evidence };
  }
  const confidence = decisive ? 0.97 : top >= 6 ? 0.9 : 0.75;
  return {
    id: best,
    label: label[best],
    confidence,
    compatible: compatible.map((d) => ({ id: d, label: label[d] })),
    evidence: evidence.length ? evidence : ['no dialect-specific syntax: plain Lua 5.1 subset, valid in several runtimes'],
  };
}
