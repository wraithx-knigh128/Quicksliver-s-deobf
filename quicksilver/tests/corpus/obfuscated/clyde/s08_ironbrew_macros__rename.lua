IB_MAX_CFLOW_START = function()

end
IB_MAX_CFLOW_END = function()

end
IB_INLINING_START = function()

end
local function a(b, c)
  IB_INLINING_START(true)
  return (b + c)
end
local function d(e, f)
  IB_INLINING_START(true)
  return (e * f), (e / f)
end
local function g(h)
  IB_MAX_CFLOW_START()
  local i
  if (h < 0) then
    i = "negative"
  elseif (h == 0) then
    i = "zero"
  elseif ((h % 2) == 0) then
    i = "even"
  else
    i = "odd"
  end
  IB_MAX_CFLOW_END()
  return i
end
local j = 0
for k = 1, 10 do
  j = a(j, k)
end
print("total", j)
for l, m in ipairs({-3, 0, 4, 7}) do
  print(m, g(m))
end
local n, o = d(12, 5)
print(n, o)
print(select("#", d(1, 2)))