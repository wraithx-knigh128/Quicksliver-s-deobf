local function a(b)
  local c = 0
  while (b ~= 1) do
    if ((b % 2) == 0) then
      b = (b / 2)
    else
      b = ((3 * b) + 1)
    end
    c = (c + 1)
  end
  return c
end
local function d(e)
  if (e < 0) then
    return "negative"
  elseif (e == 0) then
    return "zero"
  elseif (e < 10) then
    return "small"
  elseif (e < 100) then
    return "medium"
  else
    return "large"
  end
end
local function f(g)
  local h
  for i = 2, g do
    if ((g % i) == 0) then
      h = i
      break
    end
  end
  return h
end
local function j(k)
  local l = 0
  repeat
    l = (l + (k % 10))
    k = math.floor((k / 10))
  until (k == 0)
  return l
end
local function m(n)
  local o = "start"
  local p = {}
  for q = 1, #n do
    local r = n:sub(q, q)
    if (o == "start") then
      if (r == "a") then
        o = "seenA"
      end
    elseif (o == "seenA") then
      if (r == "b") then
        o = "seenAB"
      elseif (r ~= "a") then
        o = "start"
      end
    elseif (o == "seenAB") then
      o = ((((r == "c")) and "accept") or "start")
    end
    p[(#p + 1)] = o
  end
  return o, table.concat(p, ">")
end
for s, t in ipairs({6, 7, 27}) do
  print(("collatz(" .. (t .. (") = " .. a(t)))))
end
for u, v in ipairs({-5, 0, 7, 42, 1000}) do
  print((v .. (" is " .. d(v))))
end
print(f(91), f(97), j(98765))
print(m("xxabcab"))
print(m("aabx"))