-- Mock environment shared by the real-Lua oracle (run_lua.py) and the sandbox interpreter tests.
-- Captures print() into QS_OUT / QS_N and provides a tiny Roblox-style API surface.
QS_OUT, QS_N = {}, 0
local function emit(s) QS_N = QS_N + 1; QS_OUT[QS_N] = s end
local tostr, tconcat, unpack_ = tostring, table.concat, unpack or table.unpack
local select_, type_, pcall_ = select, type, pcall

local function fmt(...)
  local t = {}
  for i = 1, select_("#", ...) do t[i] = tostr((select_(i, ...))) end
  return tconcat(t, "\t")
end

_G.print = function(...) emit(fmt(...) .. "\n") end

---------------------------------------------------------------- mock Roblox
local function newMock(name, props)
  local o = props or {}
  local methods = {}
  local mt = {}
  mt.__index = function(t, k)
    local v = rawget(t, k)
    if v ~= nil then return v end
    return function(self, ...) return newMock(name .. ":" .. tostr(k) .. "()") end
  end
  mt.__tostring = function() return name end
  return setmetatable(o, mt)
end

-- Signals queue their callbacks; QS_PUMP fires them after the main chunk returns,
-- like a real engine would (a Connect callback never runs before Connect returns).
local pending = {}
local signal = function(label)
  local s = {}
  function s:Connect(fn)
    local conn = { live = true }
    function conn:Disconnect() self.live = false end
    pending[#pending + 1] = { fn = fn, conn = conn }
    return conn
  end
  return s
end
QS_PUMP = function()
  for tick = 1, 3 do
    for i = 1, #pending do
      local p = pending[i]
      if p.conn.live then p.fn(0.016) end
    end
  end
end

local humanoid = newMock("Humanoid", { WalkSpeed = 16, JumpPower = 50 })
local character = newMock("Character", {})
character.WaitForChild = function(self, nm) return humanoid end
local localPlayer = newMock("LocalPlayer", { Character = character, Name = "Tester", UserId = 1 })
local players = newMock("Players", { LocalPlayer = localPlayer })
local runService = newMock("RunService", { Heartbeat = signal("Heartbeat"), Stepped = signal("Stepped") })
local remote = newMock("Remote", {})
remote.FireServer = function(self, ...) emit("FireServer " .. fmt(...) .. "\n") end
local replicated = newMock("ReplicatedStorage", {})
replicated.WaitForChild = function(self, nm) return remote end
local services = { Players = players, RunService = runService, ReplicatedStorage = replicated }
_G.game = newMock("game", {})
_G.game.GetService = function(self, nm) return services[nm] or newMock(nm, {}) end
_G.workspace = newMock("Workspace", {})
_G.Instance = { new = function(cls) return newMock(cls, { ClassName = cls }) end }
_G.task = { wait = function() return 0 end, spawn = function(f, ...) return f(...) end,
            delay = function(_, f, ...) return f(...) end }
_G.wait = function() return 0 end
_G.warn = _G.print
