// Random program generators for the decompiler's property tests (tests/decompile-property.test.mjs). Each case is compiled by
// reference Lua 5.1, stripped of debug information (as rebuilt VM chunks are), decompiled by QuickSilver, and both programs are run by
// reference Lua on the same inputs. Deterministic: a seed gives the same programs every run.

export function rng(seed) {
  let s = seed;
  return (n) => { s = (s * 1103515245 + 12345) % 2147483648; return s % n; };
}

/** Short-circuit expressions over values, fields, method calls and calls with side effects, in four positions. */
export function expressionCase(rnd) {
  const vals = ['a', 'b', 'c', 't', 'c.x', 'c:F("H")', 't.k', 'a.T', 'b.T', 'c.H', 'f(a)'];
  const consts = ['1', '0', '"s"', 'nil', 'true', 'false'];
  const cmp = () => { const ops = ['==', '~=', '<', '<=', '>', '>=']; const l = vals[rnd(vals.length)]; const r = rnd(2) ? vals[rnd(vals.length)] : consts[rnd(consts.length)]; return `${l} ${ops[rnd(ops.length)]} ${r}`; };
  const gen = (d) => {
    const r = rnd(d > 2 ? 4 : 10);
    if (r < 2) return vals[rnd(vals.length)];
    if (r < 4 || d > 2) return cmp();
    if (r < 6) return `${gen(d + 1)} and ${gen(d + 1)}`;
    if (r < 8) return `(${gen(d + 1)} or ${gen(d + 1)})`;
    if (r < 9) return `not (${gen(d + 1)})`;
    return consts[rnd(consts.length)];
  };
  const forms = [(e) => `local a, b, c, t = ...\nreturn ${e}`, (e) => `local a, b, c, t = ...\nlocal x = ${e}\nreturn x, a`, (e) => `local a, b, c, t = ...\nif ${e} then return 1 end\nreturn 2`, (e) => `local a, b, c, t = ...\nreturn g(${e}, b)`];
  const e = gen(0);
  return forms[rnd(forms.length)](e);
}

/** Runs a compiled expression case on every combination of eight values for its four inputs; prints a digest of results, errors and call order. */
export const expressionHarness = (quoted) => `
local T1 = { x = 1, H = { x = 1 }, k = true, T = 1 } ; T1.F = function(self, h) return self.x end
local T2 = { x = 0, H = { x = -1 }, k = false, T = 2 } ; T2.F = function(self, h) return nil end
local D = { nil, false, true, 0, 5, "s", T1, T2 } ; local N = 8
local log = {}
function f(v) log[#log + 1] = "f" .. type(v) ; return v end
function g(v, w) log[#log + 1] = "g" .. type(v) ; return v end
local fn = assert(loadstring(${quoted}))
local names = { [T1] = "T1", [T2] = "T2", [T1.H] = "T1.H", [T2.H] = "T2.H", [T1.F] = "T1.F", [T2.F] = "T2.F" }
local function show(v) if names[v] then return names[v] end if type(v) == "table" or type(v) == "function" then return type(v) end return type(v) .. ":" .. tostring(v) end
local out = {}
for i = 1, N do for j = 1, N do for k = 1, N do for l = 1, N do
  log = {}
  local r = { pcall(fn, D[i], D[j], D[k], D[l]) }
  local s = {}
  for q = 1, 3 do s[q] = show(r[q]) end
  if not r[1] then s[2] = "error" end
  out[#out + 1] = table.concat(s, ",") .. "|" .. table.concat(log, ",")
end end end end
local h = 0
local all = table.concat(out, ";")
for p = 1, #all do h = (h * 31 + all:byte(p)) % 2147483647 end
print(#out, h)`;

/** Programs of statements: if/elseif/else, while with compound conditions, numeric and generic for, break, return, value expressions. */
export function statementCase(rnd) {
  let label = 0;
  const cmp = () => { const ops = ['==', '~=', '<', '<=', '>', '>=']; const l = ['n', 'x', '#t', 'k'][rnd(4)]; return `${l} ${ops[rnd(6)]} ${rnd(4)}`; };
  const cond = (d) => { const r = rnd(6); if (r < 2 || d > 1) return cmp(); if (r < 3) return ['a', 'b', 'not a', 'f(b)'][rnd(4)]; if (r < 4) return `${cond(d + 1)} and ${cond(d + 1)}`; if (r < 5) return `(${cond(d + 1)} or ${cond(d + 1)})`; return `not (${cond(d + 1)})`; };
  const val = (d) => { const r = rnd(5); if (r < 2) return ['n', 'x', 'a', 'b', '"s"', '1'][rnd(6)]; if (r < 3) return `${val(d + 1)} and ${val(d + 1)}`; if (r < 4) return `${val(d + 1)} or ${val(d + 1)}`; return cond(d); };
  const block = (d, inLoop) => {
    const out = [];
    const n = 1 + rnd(d > 2 ? 2 : 4);
    for (let i = 0; i < n; i++) {
      const r = rnd(d > 2 ? 4 : 14);
      if (r < 2) out.push(`print(${++label}, ${val(0)})`);
      else if (r < 3) out.push('x = x + 1');
      else if (r < 4) out.push(`local y${label} = ${val(0)} print(${++label}, y${label - 1})`);
      else if (r < 6) out.push(`if ${cond(0)} then ${block(d + 1, inLoop)} ${rnd(2) ? `elseif ${cond(0)} then ${block(d + 1, inLoop)} ` : ''}${rnd(2) ? `else ${block(d + 1, inLoop)} ` : ''}end`);
      else if (r < 8) out.push(`local w${label} = 0 while w${label} < 3 and (${cond(0)}) do w${label} = w${label} + 1 ${block(d + 1, true)} end`);
      else if (r < 10) out.push(`for i${++label} = 1, 3 do ${block(d + 1, true)} end`);
      else if (r < 12) out.push(`for k, v in ipairs(t) do ${block(d + 1, true)} end`);
      else if (r < 13 && inLoop) { out.push(`if ${cond(0)} then break end`); }
      else if (r < 14 && i === n - 1) { out.push(`return ${val(0)}`); break; }
      else out.push(`print(${++label})`);
    }
    return out.join(' ');
  };
  return `local n, a, b, t = ...\nx = x or 0\n${block(0, false)}`;
}

/** Runs a compiled statement case on four inputs, recording what it printed, returned and left in the global x. */
export const statementHarness = (quoted) => `
local fn = assert(loadstring(${quoted}))
local buf = {}
function f(v) buf[#buf + 1] = "f" return v end
local out = {}
local _print = print
for _, inp in ipairs({ {0, false, true, {1, 2}}, {2, true, false, {3}}, {5, true, true, {}}, {1, false, false, {2, 2, 2}} }) do
  buf = {}
  print = function(...) local p = {} for i = 1, select("#", ...) do p[#p + 1] = tostring((select(i, ...))) end buf[#buf + 1] = table.concat(p, " ") end
  x = 0
  local ok, r = pcall(fn, inp[1], inp[2], inp[3], inp[4])
  print = _print
  out[#out + 1] = tostring(ok) .. ":" .. tostring(r) .. ":" .. tostring(x) .. "|" .. table.concat(buf, ";")
end
print(table.concat(out, "#"))`;

/**
 * Prompt XXX: interior AST nodes (nodes with children) that appear more than once in a decompiled tree. Sharing one would print the same
 * code twice, so it would also run twice; it is how a speculative step that mutated a pending table showed up. Leaves (names, constants)
 * may be shared.
 */
export function sharedSubtrees(ast) {
  const seen = new Set();
  let shared = 0;
  const visit = (n) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(visit); return; }
    const kids = Object.entries(n).filter(([k, v]) => v && typeof v === 'object' && k !== 'comments');
    if (kids.length && seen.has(n)) { shared++; return; }
    seen.add(n);
    for (const [, v] of kids) visit(v);
  };
  visit(ast);
  return shared;
}

/**
 * Prompt XXXI (KNOWN-ISSUES #114): statements whose value conditions read fields through `__index`, call methods and functions, in
 * chains of `and` / `or` that keep the variable's old value, take a new one or fall through to code. The harness logs every read and
 * call, so a decompiled program that evaluates something twice, once too few, or in another order, prints a different log.
 */
export function evaluationCase(rnd) {
  const atoms = ['t.a', 't.b', 't[k]', 't:m()', 'f(t.c)', 'u.a', 'u[k]', 'n', 'c'];
  const atom = () => atoms[rnd(atoms.length)];
  const chain = (len, op) => Array.from({ length: len }, atom).join(` ${op} `);
  const stmts = [
    () => `x = ${atom()} or x`,
    () => `x = ${atom()} and x`,
    () => `x = ${chain(2, 'or')} or x`,
    () => `x = ${chain(2, 'and')} and x`,
    () => `x = ${atom()} or ${atom()}`,
    () => `x = ${atom()} and ${atom()}`,
    () => `x = ${chain(3, 'or')}`,
    () => `x = c and ${atom()} or x`,
    () => `x = (${atom()} and ${atom()}) or x`,
    () => `x = ${atom()} or g(x)`,
    () => `x = ${atom()} or (x and ${atom()})`,
    () => `x = ${atom()} or ${atom()} or g(x) or x`,
    () => `if ${atom()} then x = ${atom()} end`,
    () => `local y = ${atom()} or ${atom()} x = y`,
    () => `for i = 1, 2 do x = t[i] or x end`,
    () => `for i = 1, 2 do x = u[i] and x or ${atom()} end`,
    () => `n = ${atom()} or n x = n or x`,
    () => `g(${atom()} or x, ${atom()} and x)`,
    // a guard before the tested value (`x = A and B or c`), with x read afterwards so the value is kept in a statement
    () => `x = ${atom()} and ${atom()} or nil g(x)`,
    () => `x = ${atom()} and ${atom()} or ${atom()} g(x)`,
    () => `x = ${atom()} and ${atom()} or x g(x)`,
    () => `x = ${atom()} and ${atom()} and ${atom()} or nil g(x)`,
  ];
  const body = Array.from({ length: 1 + rnd(3) }, () => stmts[rnd(stmts.length)]()).join('\n');
  return `local t, u, k, x, n, c = ...\n${body}\nreturn x, n`;
}

/** Runs an evaluation case on rows of field values through logging proxies; prints, per row, the results and the read/call log. */
export const evaluationHarness = (quoted) => `
local fn = assert(loadstring(${quoted}))
local log
local function proxy(name, V)
  return setmetatable({}, { __index = function(_, key)
    log[#log + 1] = name .. "." .. tostring(key)
    if key == "m" then return function(self) log[#log + 1] = name .. ":m" return V.m end end
    return V[key]
  end })
end
function f(v) log[#log + 1] = "f(" .. tostring(v) .. ")" return v end
function g(v, w) log[#log + 1] = "g(" .. tostring(v) .. "," .. tostring(w) .. ")" return w end
local D = { nil, false, 0, "s" }
local out = {}
for row = 1, 24 do
  local function pick(j) return D[(row * 7 + j * 3) % 4 + 1] end
  local V = { a = pick(1), b = pick(2), c = pick(3), m = pick(4), [1] = pick(5), [2] = pick(6) }
  local W = { a = pick(7), [1] = pick(8), [2] = pick(9) }
  log = {}
  local t, u = proxy("t", V), proxy("u", W)
  local r = { pcall(fn, t, u, (row % 3 == 0) and "a" or (row % 2) + 1, pick(10), pick(11), pick(12)) }
  out[#out + 1] = tostring(r[1]) .. ":" .. tostring(r[2]) .. ":" .. tostring(r[3]) .. "|" .. table.concat(log, ",")
end
print(table.concat(out, "\\n"))`;
