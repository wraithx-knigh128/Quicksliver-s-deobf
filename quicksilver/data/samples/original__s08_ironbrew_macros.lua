-- s08: written for IronBrew 2's own macros (IB_MAX_CFLOW_START / END, IB_INLINING_START). They are defined here as
-- no-ops so the program also runs un-obfuscated; IronBrew 2 recognises the calls by name and acts on them.
IB_MAX_CFLOW_START = function() end
IB_MAX_CFLOW_END = function() end
IB_INLINING_START = function() end

local function add(a, b)
  IB_INLINING_START(true)
  return a + b
end

local function scale(v, k)
  IB_INLINING_START(true)
  return v * k, v / k
end

local function classify(n)
  IB_MAX_CFLOW_START()
  local label
  if n < 0 then
    label = "negative"
  elseif n == 0 then
    label = "zero"
  elseif n % 2 == 0 then
    label = "even"
  else
    label = "odd"
  end
  IB_MAX_CFLOW_END()
  return label
end

local total = 0
for i = 1, 10 do total = add(total, i) end
print("total", total)

for _, n in ipairs({ -3, 0, 4, 7 }) do
  print(n, classify(n))
end

local up, down = scale(12, 5)
print(up, down)
print(select("#", scale(1, 2)))
