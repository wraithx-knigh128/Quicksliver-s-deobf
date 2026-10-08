-- Smoke test: runs the UI script against a permissive fake Roblox environment.
-- Catches syntax errors, nil-call / undefined-variable bugs and crashes in our own logic, exercises every
-- click handler, the background-image pipeline and the clean-up / re-run behaviour.
-- It does NOT validate real Roblox property names - only a real executor can do that.
local SCRIPT = SCRIPT_PATH or "../dist/tsb_hub_executor.lua"

local function readScript()
    local f = assert(io.open(SCRIPT, "r")); local s = f:read("a"); f:close(); return s
end

-- an object that answers every index / call with another dummy (so unknown Roblox APIs do not crash the test)
local function dummy(name, ctx)
    local t = {__name = name}
    return setmetatable(t, {
        __index = function(self, k)
            if k == "Connect" or k == "Wait" then
                return function(_, fn)
                    if type(fn) == "function" and name:find("Click") then ctx.callbacks[#ctx.callbacks + 1] = fn end
                    ctx.connections = ctx.connections + 1
                    return {Disconnect = function() ctx.disconnects = ctx.disconnects + 1 end}
                end
            end
            if k == "GetChildren" or k == "GetPlayers" then return function() return {} end end
            local v = dummy(name .. "." .. tostring(k), ctx); rawset(self, k, v); return v
        end,
        __call = function() return dummy(name .. "()", ctx) end,
        __add = function(a) return a end, __sub = function(a) return a end, __mul = function(a) return a end,
        __div = function(a) return a end, __unm = function(a) return a end,
        __lt = function() return false end, __le = function() return true end,
        __concat = function(a, b) return tostring(a.__name or a) .. tostring(type(b) == "table" and b.__name or b) end,
        __tostring = function() return name end,
    })
end

local PNG = "\137PNG\r\n\26\n" .. string.rep("x", 32)

-- scenario = {executor = "full" | "nofiles", body = bytes the image host returns}
local function run(scenario)
    local ctx = {callbacks = {}, connections = 0, disconnects = 0}
    local errors, instances, writes, assets = {}, {}, {}, {}
    local genvStore = {}
    local env = setmetatable({}, {__index = _G})

    env.game = dummy("game", ctx); env.workspace = dummy("workspace", ctx)
    env.workspace.CurrentCamera = {ViewportSize = {X = 800, Y = 450}}
    env.workspace.FindFirstChildWhichIsA = function() return nil end
    env.game.IsLoaded = function() return true end
    env.game.GetService = function(_, n)
        local s = dummy(n, ctx)
        if n == "Players" then
            s.LocalPlayer = {DisplayName = "Tester", Name = "tester", UserId = 1, Character = nil,
                WaitForChild = function() return dummy("PlayerGui", ctx) end,
                Idled = dummy("Idled", ctx), CharacterAdded = dummy("CharacterAdded", ctx)}
            s.GetUserThumbnailAsync = function() return "rbx://x" end
        elseif n == "HttpService" then
            s.JSONDecode = function() return {url = "https://i.waifu.pics/a.png"} end
        end
        return s
    end
    env.Instance = {new = function(class)
        local inst = dummy(class, ctx)
        instances[#instances + 1] = inst
        rawset(inst, "FindFirstChildOfClass", function() return dummy("child", ctx) end)
        rawset(inst, "FindFirstChild", function() return nil end)
        rawset(inst, "Destroy", function() end)
        rawset(inst, "IsA", function() return false end)
        return inst
    end}
    for _, n in ipairs({"UDim2", "UDim", "Color3", "ColorSequence", "TweenInfo", "CFrame", "Enum", "Vector3"}) do
        env[n] = dummy(n, ctx)
    end
    env.Vector2 = {new = function(x, y) return {X = x or 0, Y = y or 0} end}
    env.task = {
        spawn = function(f, ...) local ok, e = pcall(f, ...); if not ok then errors[#errors + 1] = "task: " .. tostring(e) end end,
        wait = function() return 0 end,
    }
    env.warn = function(...) errors[#errors + 1] = "warn: " .. table.concat({...}, " ") end
    env.os = {clock = os.clock}
    env.math = setmetatable({clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end}, {__index = math})
    env.table = setmetatable({find = function(t, v) for i, x in ipairs(t) do if x == v then return i end end end}, {__index = table})
    env._G = genvStore
    env.getgenv = function() return genvStore end
    if scenario.executor == "full" then
        env.request = function(req)
            if req.Url:find("api.waifu.pics", 1, true) then return {StatusCode = 200, Body = '{"url":"https://i.waifu.pics/a.png"}'} end
            return {StatusCode = 200, Body = scenario.body}
        end
        env.writefile = function(path, body) writes[#writes + 1] = {path = path, body = body} end  -- returns nothing, like real executors
        env.getcustomasset = function(p) assets[#assets + 1] = p; return "rbxasset://" .. p end
    end

    local fn, err = load(readScript(), "@" .. SCRIPT, "t", env)
    if not fn then return nil, {"SYNTAX ERROR: " .. err} end
    local ok, e = pcall(fn)
    if not ok then errors[#errors + 1] = "top level: " .. tostring(e) end

    local bgSet = false
    for _, inst in ipairs(instances) do
        local img = rawget(inst, "Image")
        if type(img) == "string" and img:find("animation_hub_bg_", 1, true) then bgSet = true end
    end
    return {errors = errors, ctx = ctx, writes = writes, assets = assets, bgSet = bgSet, genv = genvStore, env = env, fn = fn}
end

local failures = {}
local function check(cond, msg) if not cond then failures[#failures + 1] = msg end end

-- 1. normal executor, valid PNG
local a, synErr = run({executor = "full", body = PNG})
if not a then print(synErr[1]); os.exit(1) end
for _, e in ipairs(a.errors) do failures[#failures + 1] = e end
check(#a.writes == 1 and a.writes[1].path:match("%.png$"), "background: expected exactly one .png written (writefile returns nothing on success!)")
check(a.bgSet, "background: Image was never set from getcustomasset")
check(type(a.genv.__AnimationHubCleanup) == "function", "cleanup function not registered")

-- exercise every click handler (newest first so the Close button runs last)
local clicked = 0
for i = #a.ctx.callbacks, 1, -1 do
    local ok2, e2 = pcall(a.ctx.callbacks[i])
    clicked = clicked + 1
    if not ok2 then failures[#failures + 1] = "click handler: " .. tostring(e2) end
end
print("exercised " .. clicked .. " click handlers")

-- floating bar: lock and minimise clicks must land in the saved state
local fab = a.genv.__AnimationHubFab
check(type(fab) == "table", "floating bar state was not saved")
if fab then
    check(fab.locked == true, "Lock button did not lock")
    check(fab.minimized == true, "minimise button did not minimise")
    check(type(fab.x) == "number" and fab.x >= 4 and fab.x <= 800, "bar x is off screen: " .. tostring(fab.x))
    check(type(fab.y) == "number" and fab.y >= 4 and fab.y <= 450, "bar y is off screen: " .. tostring(fab.y))
end

-- Close button must have run cleanup: global listeners disconnected, cleanup unregistered
check(a.ctx.disconnects > 0, "cleanup did not disconnect any listener")
check(a.genv.__AnimationHubCleanup == nil, "cleanup should unregister itself")

-- 2. re-running the script must clean the previous copy first
local b = run({executor = "full", body = PNG})
local before = b.ctx.disconnects
b.genv.__AnimationHubFab = {x = 300, y = 200, locked = true, minimized = true}   -- pretend the user set this up
local ok3 = pcall(b.fn)                      -- second execution in the same environment
check(ok3, "second execution crashed")
check(b.ctx.disconnects > before, "re-run did not clean up the previous instance")
local fb = b.genv.__AnimationHubFab
check(fb and fb.locked == true and fb.minimized == true and fb.x == 300 and fb.y == 200,
    "re-run did not restore the floating bar's position / lock / minimised state")

-- 3. image host returns an HTML error page -> nothing written, no crash
local c = run({executor = "full", body = "<html>429 Too Many Requests</html>"})
for _, e in ipairs(c.errors) do failures[#failures + 1] = "html scenario: " .. e end
check(#c.writes == 0 and not c.bgSet, "html error page must not be saved as an image")

-- 4. executor without file functions -> UI still builds, no network image
local d = run({executor = "nofiles", body = PNG})
for _, e in ipairs(d.errors) do failures[#failures + 1] = "nofiles scenario: " .. e end
check(#d.writes == 0 and not d.bgSet, "no-file executor must skip the background")

if #failures > 0 then
    print("PROBLEMS:"); for _, x in ipairs(failures) do print("  " .. x) end
    os.exit(1)
end
print("smoke test passed (4 scenarios)")
