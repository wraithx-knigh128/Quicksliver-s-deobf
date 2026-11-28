-- Prompt XXXI (found by the MoonSec V3 re-measurement: ab5c20be main/33/0 and main/43/1, decompiled by Prompt XXX, refused by the
-- first Luau `continue` rules): `n = n and n:FindFirstChild(seg) or nil` in a generic for loop. Its TESTSET delivers the value straight to
-- the loop's continue point; that jump is a value join, not a `continue`. Expected: decompiled as Luau and as Lua, the same output.
local names = {}
local function node(name, kids) local t = kids or {} names[t] = name return t end
local root = node("root", { A = node("A", { B = node("B", { C = node("C") }) }) })
local mt = { __index = { FindFirstChild = function(self, name) return rawget(self, name) end } }
for t in pairs(names) do setmetatable(t, mt) end
local function find(path)
  local n = root
  for seg in path:gmatch("[^%.]+") do
    n = n and n:FindFirstChild(seg) or nil
  end
  return n and names[n] or "nil"
end
print(find("A.B.C"), find("A.X.C"), find("A"), find(""))
