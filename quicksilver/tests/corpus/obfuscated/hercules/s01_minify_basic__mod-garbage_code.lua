--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
if false then local _ = 18 end
local xqmwdl = 31
if true then local _ = 85 end
local function inrpmj(uudmrd) local _ = 88 end
local eyuycb = 8
local rvasaq = 75
while false do local _ = 5 break end
while false do local _ = 54 break end
local kweuql = 42
if false then local _ = 98 end
if false then local _ = 21 end
if true then local _ = 43 end
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

local function nekspf(virfoj) local _ = 48 end
if false then local _ = 24 end
if false then local _ = 75 end
if true then local _ = 5 end
if true then local _ = 46 end
if true then local _ = 70 end
local tvyram = 71
local gnbjsz = 95
local function thyqru(jpqnzk) local _ = 27 end
local xogbhx = 87
local function cipkvg(uexsce) local _ = 45 end
local function vgcrmi(xqrmiw) local _ = 31 end
if false then local _ = 72 end