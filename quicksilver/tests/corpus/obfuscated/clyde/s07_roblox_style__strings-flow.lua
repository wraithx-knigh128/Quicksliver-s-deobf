local a = {}
local g = function(b, c)
  if (((1 + 1) == 2) and a[b]) then
    return a[b]
  end
  local d = {}
  for e = 1, #b do
    d[e] = string.char(bit32.bxor(b[e], c))
  end
  local f = table.concat(d)
  a[b] = f
  return f
end
local Players = game:GetService(g({10, 54, 59, 35, 63, 40, 41}, 90))
local h = game:GetService(g({8, 47, 52, 9, 63, 40, 44, 51, 57, 63}, 90))
local i = game:GetService(g({8, 63, 42, 54, 51, 57, 59, 46, 63, 62, 9, 46, 53, 40, 59, 61, 63}, 90))
local j = Players.LocalPlayer
local k = {speed = 24, jump = 50, label = g({11, 47, 51, 57, 49, 9, 51, 54, 44, 63, 40}, 90)}
local function l(m)
  local n = m:WaitForChild(g({18, 47, 55, 59, 52, 53, 51, 62}, 90))
  n.WalkSpeed = k.speed
  n.JumpPower = k.jump
  return n
end
local o = Instance.new(g({10, 59, 40, 46}, 90))
o.Name = (k.label .. g({23, 59, 40, 49, 63, 40}, 90))
o.Anchored = true
o.Parent = workspace
local p = l(j.Character)
print(g({57, 53, 52, 60, 51, 61, 47, 40, 63, 62}, 90), p.WalkSpeed, p.JumpPower, o.Name)
local q = 0
local r
r = h.Heartbeat:Connect(function(s)
  q = (q + 1)
  if (((15 * 15) == 225) and (q >= 3)) then
    r:Disconnect()
    print(g({50, 63, 59, 40, 46, 56, 63, 59, 46, 122, 62, 53, 52, 63}, 90), q)
  end
end)
local t = i:WaitForChild(g({8, 63, 55, 53, 46, 63}, 90))
t:FireServer(g({50, 63, 54, 54, 53}, 90), 42)