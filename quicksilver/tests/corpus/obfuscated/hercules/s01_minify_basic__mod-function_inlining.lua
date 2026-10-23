--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s01: arithmetic and string utilities. Used for minification / formatting tests.




































local primes = {}
for candidate = 1, 50 do
  if (function(n)

  if n < 2 then
    return false
  end
  for i = 2, math.floor(math.sqrt(n)) do
    if n % i == 0 then
      return false
    end
  end
  return true

end)(candidate) then
    primes[#primes + 1] = candidate
  end
end

print("primes: " ..(function(list, separator)

  local parts = {}
  for index = 1, #list do
    parts[#parts + 1] = tostring(list[index])
  end
  return table.concat(parts, separator)

end)(primes, ","))
print("(function(a, b)

  while b ~= 0 do
    a, b = b, a % b
  end
  return a

end)(84, 36) = " ..(function(a, b)

  while b ~= 0 do
    a, b = b, a % b
  end
  return a

end)(84, 36))
print("clamp: " ..(function(value, low, high)

  if value < low then
    return low
  elseif value > high then
    return high
  end
  return value

end)(15, 0, 10) .. " " ..(function(value, low, high)

  if value < low then
    return low
  elseif value > high then
    return high
  end
  return value

end)(-3, 0, 10) .. " " ..(function(value, low, high)

  if value < low then
    return low
  elseif value > high then
    return high
  end
  return value

end)(7, 0, 10))
print(string.format("%5.2f|%-6s|%03d", 3.14159, "ab", 7))
