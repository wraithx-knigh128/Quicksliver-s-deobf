--[Obfuscated by Hercules v1.5 | discord.gg/Hx6RuYs8Ku]
local function zxWm3dlEREu(Qg2IO5y71ID9)
    return (Qg2IO5y71ID9 >= 48 and Qg2IO5y71ID9 <= 57) or 
           (Qg2IO5y71ID9 >= 65 and Qg2IO5y71ID9 <= 90) or 
           (Qg2IO5y71ID9 >= 97 and Qg2IO5y71ID9 <= 122)
end

local function IIM4fM4j0urC(BmXJxEmbDXKy1, cbhbX2asaq)
    local inX8FpSju1 = {}
    for i = 1, #BmXJxEmbDXKy1 do
        local Qg2IO5y71ID9 = BmXJxEmbDXKy1:byte(i)
        if zxWm3dlEREu(Qg2IO5y71ID9) then
            local VQeA5wPd0wi            if Qg2IO5y71ID9 >= 48 and Qg2IO5y71ID9 <= 57 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 48 - cbhbX2asaq + 10) % 10) + 48
            elseif Qg2IO5y71ID9 >= 65 and Qg2IO5y71ID9 <= 90 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 65 - cbhbX2asaq + 26) % 26) + 65
            elseif Qg2IO5y71ID9 >= 97 and Qg2IO5y71ID9 <= 122 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 97 - cbhbX2asaq + 26) % 26) + 97
            end
            table.insert(inX8FpSju1, string.char(VQeA5wPd0wi))
        else
            table.insert(inX8FpSju1, string.char(Qg2IO5y71ID9))
        end
    end
    return table.concat(inX8FpSju1)
end

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

print(IIM4fM4j0urC("vxosky: ", -319449722) .. join(primes, IIM4fM4j0urC(",", -255556012)))
print(IIM4fM4j0urC("jfg(51, 03) = ", 541087797) .. gcd(84, 36))
print(IIM4fM4j0urC("vetfi: ", -40125937) .. clamp(15, 0, 10) .. IIM4fM4j0urC(" ", -550623482) .. clamp(-3, 0, 10) .. IIM4fM4j0urC(" ", -1157038058) .. clamp(7, 0, 10))
print(string.format(IIM4fM4j0urC("%0.7a|%-1n|%58y", 1536593495), 3.14159, IIM4fM4j0urC("fg", 1457098297), 7))
