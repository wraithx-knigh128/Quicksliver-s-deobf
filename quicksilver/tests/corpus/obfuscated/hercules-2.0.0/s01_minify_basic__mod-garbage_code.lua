--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
while false do local _ = 99 break end
if false then local _ = 21 end
if true then local _ = 90 end
if true then local _ = 49 end
if true then local _ = 96 end
if true then local _ = 65 end
while false do local _ = 71 break end
while false do local _ = 25 break end
while false do local _ = 99 break end
local wiguvp = 7
if true then local _ = 23 end
local xbvepg = 56
local ugkujg = 17
-- s01: arithmetic and string utilities. Used for minification / formatting tests.
local function clamp(value, low, high)
  if value < low then
    return low
  elseif value > high then
    return high
  end
  return value
end

local function gcd(a, b)
  while b ~= 0 do
    a, b = b, a % b
  end
  return a
end

local function isPrime(n)
  if n < 2 then
    return false
  end
  for i = 2, math.floor(math.sqrt(n)) do
    if n % i == 0 then
      return false
    end
  end
  return true
end

local function join(list, separator)
  local parts = {}
  for index = 1, #list do
    parts[#parts + 1] = tostring(list[index])
  end
  return table.concat(parts, separator)
end

local primes = {}
for candidate = 1, 50 do
  if isPrime(candidate) then
    primes[#primes + 1] = candidate
  end
end

print("primes: " .. join(primes, ","))
print("gcd(84, 36) = " .. gcd(84, 36))
print("clamp: " .. clamp(15, 0, 10) .. " " .. clamp(-3, 0, 10) .. " " .. clamp(7, 0, 10))
print(string.format("%5.2f|%-6s|%03d", 3.14159, "ab", 7))

if false then local _ = 52 end
local function cykuvy(dikdem) local _ = 29 end
local rncyek = 42
local fbtvyr = 1
if true then local _ = 70 end
local function thyqru(jpqnzk) local _ = 27 end
if true then local _ = 47 end
if true then local _ = 56 end
while false do local _ = 77 break end
local function ivgcrm(ixqrmi) local _ = 31 end
local ihhcns = 20
if false then local _ = 51 end
while false do local _ = 4 break end