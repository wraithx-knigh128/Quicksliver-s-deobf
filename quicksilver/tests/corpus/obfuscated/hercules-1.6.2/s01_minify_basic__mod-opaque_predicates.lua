--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s01: arithmetic and string utilities. Used for minification / formatting tests.
local function clamp(value, low, high)
  if value < low then
    if 35 + 35 == 70 then
        return low
    end
  elseif value > high then
    if 39 + 6 == 45 then
        return high
    end
  end
  if not (10 ~= 10) then
      return value
  elseif (not (21 < 39)) == (21 >= 39) then
      -- dead
  end
end

local function gcd(a, b)
  while b ~= 0 do
    if true then
        a, b = b, a % b
    end
  end
  if 26 + 26 == 52 then
      return a
  end
end

local function isPrime(n)
  if n < 2 then
    if 49 + 13 == 62 then
        return false
    elseif 4 + 12 ~= 16 then
        -- dead
    end
  end
  for i = 2, math.floor(math.sqrt(n)) do
    if n % i == 0 then
      if not (31 ~= 31) then
          return false
      end
    end
  end
  if true then
      return true
  end
end

local function join(list, separator)
  local parts = {}
  for index = 1, #list do
    if 82 % 82 == 0 then
        parts[#parts + 1] = tostring(list[index])
    elseif not (60 == 60) then
        -- dead
    end
  end
  if 16 + 45 == 61 then
      return table.concat(parts, separator)
  end
end

local primes = {}
for candidate = 1, 50 do
  if isPrime(candidate) then
    if 21 - 21 == 0 then
        primes[#primes + 1] = candidate
    end
  end
end

if true then
    print("primes: " .. join(primes, ","))
elseif 4 + 28 ~= 32 then
    -- dead
end
if true then
    print("gcd(84, 36) = " .. gcd(84, 36))
end
if 100 - 100 == 0 then
    print("clamp: " .. clamp(15, 0, 10) .. " " .. clamp(-3, 0, 10) .. " " .. clamp(7, 0, 10))
end
if 31 + 13 == 44 then
    print(string.format("%5.2f|%-6s|%03d", 3.14159, "ab", 7))
elseif 30 ~= 30 then
    -- dead
end
