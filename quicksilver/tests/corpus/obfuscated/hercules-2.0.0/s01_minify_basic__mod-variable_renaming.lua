--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local wPdZwiguCp,kweuqlPhf,xHvKEpMRBuM,jgqTeQsBpB,ArfoPVZM,cDGcFkDJOk
wPdZwiguCp=print;kweuqlPhf=tostring;xHvKEpMRBuM=math.floor;jgqTeQsBpB=math.sqrt;ArfoPVZM=string.format;cDGcFkDJOk=table.concat;
-- s01: arithmetic and string utilities. Used for minification / formatting tests.
local function IIMfMjZurC(value, low, high)
  if value < low then
    return low
  elseif value > high then
    return high
  end
  return value
end

local function JxEmbDXKy(a, b)
  while b ~= 0 do
    a, b = b, a % b
  end
  return a
end

local function gIOyIDrVQe(n)
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

local function yinXFpSjudBm(list, separator)
  local zxWmdlERE = {}
  for index = 1, #list do
    zxWmdlERE[#zxWmdlERE + 1] = kweuqlPhf(list[index])
  end
  return table.concat(zxWmdlERE, separator)
end

local ycbhbXasaqVk = {}
for candidate = 1, 50 do
  if gIOyIDrVQe(candidate) then
    ycbhbXasaqVk[#ycbhbXasaqVk + 1] = candidate
  end
end

wPdZwiguCp("primes: " .. yinXFpSjudBm(ycbhbXasaqVk, ","))
wPdZwiguCp("gcd(84, 36) = " .. JxEmbDXKy(84, 36))
wPdZwiguCp("clamp: " .. IIMfMjZurC(15, 0, 10) .. " " .. IIMfMjZurC(-3, 0, 10) .. " " .. IIMfMjZurC(7, 0, 10))
wPdZwiguCp(string.format("%5.2f|%-6s|%03d", 3.14159, "ab", 7))
