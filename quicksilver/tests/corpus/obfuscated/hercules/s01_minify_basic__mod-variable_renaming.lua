--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local wPdZwiguCp,kweuqlPhf,xHvKEpMRBuM,jgqTeQsBpB,ArfoPVZM,cDGcFkDJOk
wPdZwiguCp=print;kweuqlPhf=tostring;xHvKEpMRBuM=math.floor;jgqTeQsBpB=math.sqrt;ArfoPVZM=string.format;cDGcFkDJOk=table.concat;
-- s01: arithmetic and string utilities. Used for minification / formatting tests.
local function gIOyIDrVQe(value, low, high)
  if value < low then
    return low
  elseif value > high then
    return high
  end
  return value
end

local function ycbhbXasaqVk(a, b)
  while b ~= 0 do
    a, b = b, a % b
  end
  return a
end

local function zxWmdlERE(n)
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

local function JxEmbDXKy(list, separator)
  local yinXFpSjudBm = {}
  for index = 1, #list do
    yinXFpSjudBm[#yinXFpSjudBm + 1] = kweuqlPhf(list[index])
  end
  return table.concat(yinXFpSjudBm, separator)
end

local IIMfMjZurC = {}
for candidate = 1, 50 do
  if zxWmdlERE(candidate) then
    IIMfMjZurC[#IIMfMjZurC + 1] = candidate
  end
end

wPdZwiguCp("primes: " .. JxEmbDXKy(IIMfMjZurC, ","))
wPdZwiguCp("gcd(84, 36) = " .. ycbhbXasaqVk(84, 36))
wPdZwiguCp("clamp: " .. gIOyIDrVQe(15, 0, 10) .. " " .. gIOyIDrVQe(-3, 0, 10) .. " " .. gIOyIDrVQe(7, 0, 10))
wPdZwiguCp(string.format("%5.2f|%-6s|%03d", 3.14159, "ab", 7))
