-- controlled: inside the subset LuaXen compiles correctly (locals only, no parameters, no assignment to globals or upvalues, no call result stored into a table)
local total = 0
for i = 1, 10 do
  if i % 2 == 0 then total = total + i else total = total - 1 end
end
print("total", total)
local t = { x = 3, y = 4 }
local p = t.x * t.y
print(p, t.x, t.y)
local n = 1
while n < 100 do n = n * 3 end
print("n", n)
local list = { 5, 7, 9 }
local sum = 0
for i = 1, #list do sum = sum + list[i] end
print("sum", sum, #list)
local s = "hello" .. " " .. "world"
print(s, #s)
local k = 0
repeat k = k + 2 until k >= 7
print("k", k)
local big = {}
big[1] = 10
big[2] = big[1] * 2
print(big[1], big[2])
if total > 5 and n > 50 then print("both") else print("not both") end
