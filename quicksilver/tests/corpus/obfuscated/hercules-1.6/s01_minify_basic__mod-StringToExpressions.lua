--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
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

print(string.char(-235 + 347)..string.char(-404 + 518)..string.char(-58 + 163)..string.char(859 - (750))..string.char(714 - (613))..string.char(749 - (634))..string.char(376 - (318))..string.char(256 - (224)) .. join(primes, string.char(573 - (529))))
print(string.char(-724 + 827)..string.char(-461 + 560)..string.char(999 - (899))..string.char(130 - (90))..string.char(-768 + 824)..string.char(940 - (888))..string.char(853 - (809))..string.char(451 - (419))..string.char(720 - (669))..string.char(482 - (428))..string.char(-470 + 511)..string.char(917 - (885))..string.char(443 - (382))..string.char(-482 + 514) .. gcd(84, 36))
print(string.char(421 - (322))..string.char(-425 + 533)..string.char(-155 + 252)..string.char(-655 + 764)..string.char(997 - (885))..string.char(229 - (171))..string.char(-825 + 857) .. clamp(15, 0, 10) .. string.char(-450 + 482) .. clamp(-3, 0, 10) .. string.char(-772 + 804) .. clamp(7, 0, 10))
print(string.format(string.char(-558 + 595)..string.char(-409 + 462)..string.char(-299 + 345)..string.char(-858 + 908)..string.char(-790 + 892)..string.char(326 - (202))..string.char(245 - (208))..string.char(-929 + 974)..string.char(-840 + 894)..string.char(205 - (90))..string.char(-358 + 482)..string.char(-391 + 428)..string.char(-698 + 746)..string.char(896 - (845))..string.char(-783 + 883), 3.14159, string.char(378 - (281))..string.char(-827 + 925), 7))
