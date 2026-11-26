local function f1(p1)
  if p1 < 2 then
    return false
  end

  for i = 2, math.floor(math.sqrt(p1)) do
    if p1 % i == 0 then
      return false
    end
  end

  return true
end

local function f2(p2, p3)
  local v1 = {}
  local v2 = #p2
  local count = 0

  while true do
    count = 1 + count

    if not (v2 >= count) then
      break
    end

    v1[#v1 + 1] = tostring(p2[count])
  end

  return table.concat(v1, p3)
end

local v3 = {}

for j = 1, 50 do
  if f1(j) then
    v3[#v3 + 1] = j
  end
end

print("primes: " .. f2(v3, ","))
print("gcd(84, 36) = 12")
print("clamp: 10 0 7")
print(string.format("%5.2f|%-6s|%03d", 3.14159, "ab", 7))
