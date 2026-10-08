-- Smoke test: runs tsb_animation_hub.lua against a permissive fake Roblox environment.
-- Catches syntax errors, nil-call / undefined-variable bugs and crashes in our own logic.
-- It does NOT validate real Roblox property names - only a real executor can do that.
local function dummy(name)
    local t = {__name = name}
    return setmetatable(t, {
        __index = function(self, k)
            if k == "Connect" or k == "Wait" then
                return function() return dummy(name .. "." .. k) end
            end
            local v = dummy(name .. "." .. tostring(k)); rawset(self, k, v); return v
        end,
        __call = function(self, ...) return dummy(name .. "()") end,
        __add = function(a) return a end, __sub = function(a) return a end, __mul = function(a) return a end,
        __div = function(a) return a end, __unm = function(a) return a end,
        __lt = function() return false end, __le = function() return true end,
        __concat = function(a, b) return tostring(a.__name or a) .. tostring(type(b) == "table" and b.__name or b) end,
        __tostring = function() return name end,
    })
end

local errors = {}
local env = setmetatable({}, {__index = _G})
local function fake(n) return dummy(n) end
env.game = dummy("game"); env.workspace = dummy("workspace")
env.game.IsLoaded = function() return true end
env.game.GetService = function(_, n)
    local s = dummy(n)
    if n == "Players" then
        s.LocalPlayer = {DisplayName = "Tester", Name = "tester", UserId = 1, Character = nil,
            WaitForChild = function() return dummy("PlayerGui") end, Idled = dummy("Idled")}
        s.GetUserThumbnailAsync = function() return "rbx://x" end
        s.GetPlayers = function() return {} end
    end
    return s
end
env.Instance = {new = function(class)
    local inst = dummy(class)
    rawset(inst, "FindFirstChildOfClass", function() return dummy("child") end)
    rawset(inst, "FindFirstChild", function() return nil end)
    rawset(inst, "Destroy", function() end)
    rawset(inst, "Connect", nil)
    return inst
end}
for _, n in ipairs({"UDim2", "UDim", "Vector2", "Vector3", "Color3", "ColorSequence", "TweenInfo", "CFrame", "Enum"}) do
    env[n] = dummy(n)
end
env.task = {spawn = function(f, ...) local ok, e = pcall(f, ...); if not ok then errors[#errors + 1] = tostring(e) end end,
            wait = function() return 0 end}
env.warn = function(...) errors[#errors + 1] = table.concat({...}, " ") end
env.os = {clock = os.clock}
-- Luau additions missing from stock Lua
env.math = setmetatable({clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end}, {__index = math})
env.table = setmetatable({find = function(t, v) for i, x in ipairs(t) do if x == v then return i end end end}, {__index = table})
env.gethui = nil; env.request = nil; env.getcustomasset = nil; env.writefile = nil

local f = assert(io.open(ARGV or "../dist/tsb_hub_executor.lua", "r")); local src = f:read("a"); f:close()
local fn, err = load(src, "@tsb_animation_hub.lua", "t", env)
if not fn then print("SYNTAX ERROR: " .. err); os.exit(1) end
local ok, e = pcall(fn)
if not ok then errors[#errors + 1] = tostring(e) end
if #errors > 0 then print("RUNTIME PROBLEMS:"); for _, x in ipairs(errors) do print("  " .. x) end; os.exit(1) end
print("smoke test passed: script loads and builds the UI without Lua errors")
