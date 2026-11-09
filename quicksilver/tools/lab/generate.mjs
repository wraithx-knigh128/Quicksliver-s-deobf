// Lab: original test programs.
//
// A program is chosen by a seed and nothing else, so an experiment can be repeated from its record. Every program prints what it computes, which is
// what makes behaviour comparable: a transformed or reconstructed program is "the same" only if it prints the same lines and ends the same way.
// The programs are written for this laboratory; they are not copies of anyone's script.

import { rng } from '../../tests/helpers/mutators.mjs';

const WORDS = ['alpha', 'bravo', 'delta', 'echo', 'gamma', 'kilo', 'lima', 'mike', 'nova', 'oscar', 'tango', 'victor', 'whisky', 'zulu'];

const blocks = {
  arithmetic(r, i) {
    const k = r.int(3, 17); const m = r.int(50, 997); const n = r.int(8, 40);
    return `local function sumTo${i}(n)
  local total = 0
  for i = 1, n do
    total = (total + i * ${k}) % ${m}
  end
  return total
end
print("sum", sumTo${i}(${n}), sumTo${i}(${n + 7}))`;
  },
  strings(r, i) {
    const w = r.pick(WORDS); const v = r.pick(WORDS); const n = r.int(2, 4);
    return `local label${i} = "${w}-" .. string.rep("${v.slice(0, 2)}", ${n})
print(label${i}, #label${i}, string.upper(label${i}), string.sub(label${i}, 2, 5))
print(string.format("%s:%d:%5.2f", "${w}", ${r.int(1, 99)}, ${r.int(1, 9)} / 4))`;
  },
  sorting(r, i) {
    const seed = r.int(1, 9999); const n = r.int(5, 9);
    return `local function lcg${i}(s) return (s * 1103515245 + 12345) % 2147483648 end
local seed${i}, list${i} = ${seed}, {}
for i = 1, ${n} do
  seed${i} = lcg${i}(seed${i})
  list${i}[i] = seed${i} % 100
end
table.sort(list${i}, function(a, b) return a > b end)
print("sorted", table.concat(list${i}, ","))`;
  },
  closures(r, i) {
    const step = r.int(2, 7); const start = r.int(0, 9);
    return `local function counter${i}(start, step)
  local n = start
  return function() n = n + step return n end
end
local tick${i} = counter${i}(${start}, ${step})
print("ticks", tick${i}(), tick${i}(), tick${i}())`;
  },
  recursion(r, i) {
    const n = r.int(6, 12); const a = r.int(20, 90); const b = r.int(10, 60);
    return `local function fib${i}(n) if n < 2 then return n end return fib${i}(n - 1) + fib${i}(n - 2) end
local function gcd${i}(a, b) while b ~= 0 do a, b = b, a % b end return a end
print("rec", fib${i}(${n}), gcd${i}(${a}, ${b}))`;
  },
  protected(r, i) {
    const d = r.pick([0, 2, 5]);
    return `local function safeDiv${i}(a, b)
  if b == 0 then error("division by zero") end
  return a / b
end
local ok${i}, res${i} = pcall(safeDiv${i}, ${r.int(10, 90)}, ${d})
print("pcall", ok${i}, ok${i} and res${i} or "failed")`;
  },
  varargs(r, i) {
    const xs = Array.from({ length: r.int(3, 6) }, () => r.int(1, 30)).join(", ");
    return `local function total${i}(...)
  local sum = 0
  for i = 1, select("#", ...) do sum = sum + (select(i, ...)) end
  return sum, select("#", ...)
end
print("varargs", total${i}(${xs}))`;
  },
  objects(r, i) {
    const x = r.int(1, 9); const y = r.int(1, 9);
    return `local Point${i} = {}
Point${i}.__index = Point${i}
function Point${i}.new(x, y) return setmetatable({ x = x, y = y }, Point${i}) end
function Point${i}:add(o) return Point${i}.new(self.x + o.x, self.y + o.y) end
function Point${i}:len2() return self.x * self.x + self.y * self.y end
local p${i} = Point${i}.new(${x}, ${y}):add(Point${i}.new(${y}, ${x}))
print("point", p${i}.x, p${i}.y, p${i}:len2())`;
  },
  bytes(r, i) {
    const w = r.pick(WORDS);
    return `local word${i} = "${w}"
local codes${i} = {}
for i = 1, #word${i} do codes${i}[i] = string.byte(word${i}, i) end
print("bytes", table.concat(codes${i}, " "), string.char(unpack(codes${i})) == word${i})`;
  },
  collatz(r, i) {
    const n = r.int(7, 97);
    return `local function steps${i}(n)
  local c = 0
  while n ~= 1 do
    if n % 2 == 0 then n = n / 2 else n = 3 * n + 1 end
    c = c + 1
    if c > 500 then break end
  end
  return c
end
print("collatz", steps${i}(${n}), steps${i}(${n + 2}))`;
  },
  records(r, i) {
    // two different keys: a duplicate key in a table constructor is implementation-defined (PUC 5.1 keeps the last, LuaJIT does not when a value is a call),
    // which the reference runtimes showed and the in-house interpreter could not
    const a = r.pick(WORDS); let b = r.pick(WORDS);
    while (b === a) b = r.pick(WORDS);
    return `local inventory${i} = { ${a} = ${r.int(1, 20)}, ${b} = ${r.int(1, 20)} }
local keys${i} = {}
for k in pairs(inventory${i}) do keys${i}[#keys${i} + 1] = k end
table.sort(keys${i})
for _, k in ipairs(keys${i}) do print("item", k, inventory${i}[k]) end`;
  },
};

export const BLOCK_NAMES = Object.keys(blocks);

/** @returns {{seed: number, source: string, blocks: string[]}} */
export function generateProgram(seed) {
  const r = rng(seed * 7919 + 13);
  const count = r.int(4, 6);
  const chosen = r.shuffle(BLOCK_NAMES).slice(0, count);
  const parts = chosen.map((name, i) => blocks[name](r, i + 1));
  return { seed, blocks: chosen, source: `${parts.join('\n\n')}\n` };
}
