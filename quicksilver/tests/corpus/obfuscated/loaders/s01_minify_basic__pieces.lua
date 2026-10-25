(loadstring or load)("-- s01: arithmetic and string utiliti" ..
  "es. Used for minification / formattin" ..
  "g tests.\nlocal function clamp(value, " ..
  "low, high)\n  if value < low then\n    " ..
  "return low\n  elseif value > high then" ..
  "\n    return high\n  end\n  return value" ..
  "\nend\n\nlocal function gcd(a, b)\n  whil" ..
  "e b ~= 0 do\n    a, b = b, a % b\n  end" ..
  "\n  return a\nend\n\nlocal function isPri" ..
  "me(n)\n  if n < 2 then\n    return fals" ..
  "e\n  end\n  for i = 2, math.floor(math." ..
  "sqrt(n)) do\n    if n % i == 0 then\n  " ..
  "    return false\n    end\n  end\n  retu" ..
  "rn true\nend\n\nlocal function join(list" ..
  ", separator)\n  local parts = {}\n  for" ..
  " index = 1, #list do\n    parts[#parts" ..
  " + 1] = tostring(list[index])\n  end\n " ..
  " return table.concat(parts, separator" ..
  ")\nend\n\nlocal primes = {}\nfor candidat" ..
  "e = 1, 50 do\n  if isPrime(candidate) " ..
  "then\n    primes[#primes + 1] = candid" ..
  'ate\n  end\nend\n\nprint("primes: " .. jo' ..
  'in(primes, ","))\nprint("gcd(84, 36) =' ..
  ' " .. gcd(84, 36))\nprint("clamp: " ..' ..
  ' clamp(15, 0, 10) .. " " .. clamp(-3,' ..
  ' 0, 10) .. " " .. clamp(7, 0, 10))\npr' ..
  'int(string.format("%5.2f|%-6s|%03d", ' ..
  '3.14159, "ab", 7))\n')()
