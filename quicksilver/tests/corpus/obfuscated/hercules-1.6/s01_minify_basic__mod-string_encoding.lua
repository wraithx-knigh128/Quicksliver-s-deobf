--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
local function zxWmdlERE(gIOyIDrVQe)
    return (gIOyIDrVQe >= 48 and gIOyIDrVQe <= 57) or (gIOyIDrVQe >= 65 and gIOyIDrVQe <= 90) or (gIOyIDrVQe >= 97 and gIOyIDrVQe <= 122)
end
	
local function IIMfMjZurC(JxEmbDXKy, ycbhbXasaqVk)
    local yinXFpSjudBm = {}
    for i = 1, #JxEmbDXKy do
        local gIOyIDrVQe = JxEmbDXKy:byte(i)
        if zxWmdlERE(gIOyIDrVQe) then
            local wPdZwiguCp            if gIOyIDrVQe >= 48 and gIOyIDrVQe <= 57 then
                wPdZwiguCp = ((gIOyIDrVQe - 48 - ycbhbXasaqVk + 10) % 10) + 48
            elseif gIOyIDrVQe >= 65 and gIOyIDrVQe <= 90 then
                wPdZwiguCp = ((gIOyIDrVQe - 65 - ycbhbXasaqVk + 26) % 26) + 65
            elseif gIOyIDrVQe >= 97 and gIOyIDrVQe <= 122 then
                wPdZwiguCp = ((gIOyIDrVQe - 97 - ycbhbXasaqVk + 26) % 26) + 97
            end
            table.insert(yinXFpSjudBm, string.char(wPdZwiguCp))
        else
            table.insert(yinXFpSjudBm, string.char(gIOyIDrVQe))
        end
    end
    return table.concat(yinXFpSjudBm)
end

local function zxWmdlERE(gIOyIDrVQe)
    return (gIOyIDrVQe >= 48 and gIOyIDrVQe <= 57) or (gIOyIDrVQe >= 65 and gIOyIDrVQe <= 90) or (gIOyIDrVQe >= 97 and gIOyIDrVQe <= 122)
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

print(IIMfMjZurC("mofjbp: ", 23) .. join(primes, IIMfMjZurC(",", 8)))
print(IIMfMjZurC("lhi(39, 81) = ", 5) .. gcd(84, 36))
print(IIMfMjZurC("tcrdg: ", 17) .. clamp(15, 0, 10) .. IIMfMjZurC(" ", 5) .. clamp(-3, 0, 10) .. IIMfMjZurC(" ", 8) .. clamp(7, 0, 10))
print(string.format(IIMfMjZurC("%7.4b|%-8o|%25z", 22), 3.14159, IIMfMjZurC("cd", 2), 7))
