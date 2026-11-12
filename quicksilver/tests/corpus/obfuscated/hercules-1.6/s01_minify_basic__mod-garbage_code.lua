--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
if false then local _ = 99 end while false do local _ = 21 break end local function wdlluy(inrpmj) local _ = 21 end local function dmrdxm(breyuy) local _ = 3 end if true then local _ = 81 end if false then local _ = 71 end if false then local _ = 25 end if false then local _ = 99 end local function rpkeyw(jdtwig) local _ = 85 end local function vpgwxz(kweuql) local _ = 42 end local function hfvxbv(epgvxl) local _ = 28 end local function gkujgq(nekspf) local _ = 86 end if true then local _ = 30 end if true then local _ = 91 end -- s01: arithmetic and string utilities. Used for minification / formatting tests.
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
 local function molrnc(yekjcy) local _ = 14 end local fbtvyr = 1 local function ghjgnb(jszfqt) local _ = 40 end if false then local _ = 47 end if false then local _ = 77 end local function mhoymi(facipk) local _ = 86 end local function exscem(xmoaiv) local _ = 71 end if true then local _ = 13 end if true then local _ = 19 end local tbdsxs = 4 local function vimccb(xqnaek) local _ = 100 end local kfzlkf = 18 if true then local _ = 18 end