-- Smoke test: runs the UI script against a permissive fake Roblox environment.
-- Catches syntax errors, nil-call / undefined-variable bugs and crashes in our own logic, exercises every
-- click handler, the background-image pipeline and the clean-up / re-run behaviour.
-- It does NOT validate real Roblox property names - only a real executor can do that.
-- Runs on Lua 5.x (via lupa) and on real Luau (the language Roblox uses): SCRIPT_SOURCE is set by the Luau wrapper.
local SCRIPT = SCRIPT_PATH or "../dist/tsb_hub_executor.lua"

local function readScript()
    if SCRIPT_SOURCE then return SCRIPT_SOURCE end
    local f = assert(io.open(SCRIPT, "r")); local s = f:read("a"); f:close(); return s
end

local function compile(src, chunk, env)
    if loadstring and setfenv then                       -- Luau / Lua 5.1
        local fn, err = loadstring(src, chunk)
        if not fn then return nil, err end
        setfenv(fn, env)
        return fn
    end
    return load(src, chunk, "t", env)
end

local function finish(code)
    if os.exit then os.exit(code) elseif code ~= 0 then error("smoke test failed") end
end

-- would Roblox accept this as an Instance? (dummy value types such as UDim2 / Color3 / Enum are not Instances)
local NON_INSTANCE = {"UDim2", "UDim", "Color3", "ColorSequence", "NumberSequence", "TweenInfo", "CFrame", "Enum", "Vector3"}
local function isInstanceLike(v)
    if type(v) ~= "table" then return false end
    local nm = rawget(v, "__name")
    if type(nm) ~= "string" then return false end                    -- a plain Lua table (e.g. a UI wrapper object) is not an Instance
    for _, bad in ipairs(NON_INSTANCE) do
        if nm:sub(1, #bad) == bad then return false end
    end
    return true
end

-- Real Roblox property types (tests/prop_types.lua, generated from the API dump). Assigning a value of the wrong kind throws in Roblox
-- ("invalid argument #3 (Instance expected, got number)"), so the fake environment must throw too - or at least report it.
local PROP_TYPES = {}
do
    local loader = loadstring or load
    if type(PROP_TYPES_SOURCE) == "string" and loader then
        local chunk = loader(PROP_TYPES_SOURCE)
        if chunk then PROP_TYPES = chunk() end
    end
end
local DATATYPES = {UDim2 = true, UDim = true, Color3 = true, ColorSequence = true, NumberSequence = true, Vector3 = true, CFrame = true, TweenInfo = true}
local function valueKind(v)
    local t = type(v)
    if t ~= "table" then return t end                               -- string / number / boolean / nil / function
    local nm = rawget(v, "__name")
    if type(nm) ~= "string" then
        if type(rawget(v, "X")) == "number" and type(rawget(v, "Y")) == "number" then return "Vector2" end
        return "table"
    end
    local base = nm:match("^([%w_]+)")
    if base == "Enum" then return "Enum:" .. (nm:match("^Enum%.([%w_]+)") or "?") end
    if DATATYPES[base] then return base end
    return "dummy"                                                  -- an Instance or an unknown value from the fake environment
end
local PRIMITIVE = {string = "string", ContentId = "string", Content = "string", int = "number", float = "number", double = "number", int64 = "number", bool = "boolean"}
-- nil when the assignment is fine, otherwise a description of what is wrong
local function propProblem(class, key, v)
    local types = PROP_TYPES[class]
    if not types then return nil end
    local expected = types[key]
    if not expected then return class .. "." .. tostring(key) .. " is not a property of " .. class end
    local kind = valueKind(v)
    if kind == "dummy" then return nil end                          -- cannot tell what the fake environment stands for
    local want = PRIMITIVE[expected]
    local ok
    if want then ok = kind == want
    elseif expected == "Instance" then ok = false                   -- (instances are "dummy"; nil is checked below)
    else ok = kind == expected end                                  -- UDim2 / Color3 / Vector2 / Enum:X / ColorSequence ...
    if expected == "Instance" and kind == "nil" then ok = true end
    if ok then return nil end
    return string.format("%s.%s expects %s but got %s (%s)", class, key, expected, kind, tostring(v))
end

-- an object that answers every index / call with another dummy (so unknown Roblox APIs do not crash the test)
local function dummy(name, ctx)
    local t = {__name = name}
    return setmetatable(t, {
        __index = function(self, k)
            if k == "Connect" or k == "Wait" then
                return function(_, fn)
                    if type(fn) == "function" and name:find("Click") then ctx.callbacks[#ctx.callbacks + 1] = fn end
                    if type(fn) == "function" and name:find("Heartbeat") then ctx.heartbeats[#ctx.heartbeats + 1] = fn end
                    if type(fn) == "function" and name == "UserInputService.InputBegan" then ctx.inputBegan[#ctx.inputBegan + 1] = fn end
                    if type(fn) == "function" and name == "UserInputService.InputChanged" then ctx.inputChanged[#ctx.inputChanged + 1] = fn end
                    if type(fn) == "function" and name == "UserInputService.InputEnded" then ctx.inputEnded[#ctx.inputEnded + 1] = fn end
                    if type(fn) == "function" and name:find("AnimationPlayed") then ctx.animPlayed[#ctx.animPlayed + 1] = fn end
                    ctx.connections = ctx.connections + 1
                    return {Disconnect = function() ctx.disconnects = ctx.disconnects + 1 end}
                end
            end
            if k == "GetChildren" or k == "GetPlayers" then return function() return {} end end
            local v = dummy(name .. "." .. tostring(k), ctx); rawset(self, k, v); return v
        end,
        __newindex = function(t, k, v)
            rawset(t, k, v)
            if ctx.errors and next(PROP_TYPES) ~= nil then
                local class = rawget(t, "__name")
                local problem = type(class) == "string" and propProblem(class, k, v)
                if problem then
                    ctx.typeSeen = ctx.typeSeen or {}
                    if not ctx.typeSeen[problem] then
                        ctx.typeSeen[problem] = true
                        ctx.errors[#ctx.errors + 1] = "wrong property type: " .. problem
                    end
                end
            end
            if k == "Parent" and v ~= nil and ctx.errors and not isInstanceLike(v) then   -- real Roblox: "invalid argument #3 (Instance expected, got ...)"
                ctx.errors[#ctx.errors + 1] = "Parent was set to a non-Instance (" .. type(v) .. " " .. tostring(v) .. ") on "
                    .. tostring(rawget(t, "__name")) .. " " .. tostring(rawget(t, "Text")) .. " @ " .. debug.traceback("", 3):gsub("\n", " | "):sub(1, 400)
            end
            if k == "Parent" and type(v) == "table" then          -- remember who is whose child, so tests can walk the UI
                local kids = rawget(v, "__children")
                if not kids then kids = {}; rawset(v, "__children", kids) end
                kids[#kids + 1] = t
            end
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

-- a plain-Lua character (real numbers, not dummies) so geometry code can be tested: pos / look = {x=, y=, z=}
local function fakeChar(pos, look, animFns, writes, healthFns)
    -- a proxy: every WRITE to the character's root part (even re-assigning an existing field) is recorded
    local data = {Position = {X = pos.x, Y = pos.y, Z = pos.z}, CFrame = {LookVector = {X = look.x, Y = look.y, Z = look.z}}}
    local hrp = setmetatable({}, {__index = data, __newindex = function(_, k, v) writes[#writes + 1] = k; data[k] = v end})
    local animator = {AnimationPlayed = {Connect = function(_, fn) animFns[#animFns + 1] = fn; return {Disconnect = function() end} end}}
    local hum = {Health = 100, GetState = function() return "Running" end,
                 HealthChanged = {Connect = function(_, fn) healthFns[#healthFns + 1] = fn; return {Disconnect = function() end} end},
                 FindFirstChildOfClass = function() return animator end, WaitForChild = function() return animator end}
    local char = {
        FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return hrp end end,
        FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return hum end end,
        WaitForChild = function(_, n) if n == "Humanoid" then return hum end return hrp end,
        GetAttribute = function() return nil end,
    }
    return char, hrp, hum
end

-- every scenario's error list, so a final sweep also catches errors that happen AFTER the scenario was built
local ALL_ERRORS = {}

-- scenario = {executor = "full" | "nofiles", body = bytes the image host returns}
local function run(scenario)
    local ctx = {callbacks = {}, heartbeats = {}, inputBegan = {}, inputChanged = {}, inputEnded = {}, animPlayed = {}, keys = {}, mouse = {}, waits = {},
                 connections = 0, disconnects = 0}
    local errors, instances, writes, assets = {}, {}, {}, {}
    ctx.errors = errors
    ALL_ERRORS[#ALL_ERRORS + 1] = errors
    local genvStore = {AH_DISABLE_REBUILD = not scenario.allowRebuild}   -- clicking every button must not rebuild the menu mid-test
    local env = setmetatable({}, {__index = _G})

    env.game = dummy("game", ctx); env.workspace = dummy("workspace", ctx)
    env.workspace.CurrentCamera = {ViewportSize = {X = 800, Y = 450}, CFrame = {RightVector = {X = 1, Y = 0, Z = 0}}}
    local world = scenario.world            -- optional: {me = {pos, look}, enemies = {{name, pos, look}...}, right = {x,y,z}}
    local myAnim, myWrites, enemyAnim, enemies, myHealth = {}, {}, {}, {}, {}
    local myChar, myHrp, myHum
    if world then
        myChar, myHrp, myHum = fakeChar(world.me.pos, world.me.look, myAnim, myWrites, myHealth)
        if world.right then env.workspace.CurrentCamera.CFrame = {RightVector = {X = world.right.x, Y = world.right.y, Z = world.right.z}} end
        for i, e in ipairs(world.enemies or {}) do
            enemyAnim[i] = {}
            local c = fakeChar(e.pos, e.look, enemyAnim[i], {}, {})
            enemies[i] = {Name = e.name, DisplayName = e.name, Character = c, CharacterAdded = {Connect = function() return {Disconnect = function() end} end}}
        end
    end
    env.workspace.FindFirstChildWhichIsA = function() return nil end
    env.game.IsLoaded = function() return true end
    env.game.GetService = function(_, n)
        local s = dummy(n, ctx)
        if n == "Players" then
            s.GetPlayers = function() return enemies end
            s.LocalPlayer = {DisplayName = "Tester", Name = "tester", UserId = 1, Character = myChar or dummy("Character", ctx),
                WaitForChild = function() return dummy("PlayerGui", ctx) end,
                Idled = dummy("Idled", ctx), CharacterAdded = dummy("CharacterAdded", ctx)}
            s.GetUserThumbnailAsync = function() return "rbx://x" end
        elseif n == "TweenService" then
            s.Create = function(_, inst, info, props)              -- Roblox rejects a tween whose targets have the wrong type
                local class = type(inst) == "table" and rawget(inst, "__name")
                if type(props) == "table" and type(class) == "string" and next(PROP_TYPES) ~= nil then
                    for key, value in pairs(props) do
                        local problem = propProblem(class, key, value)
                        if problem then errors[#errors + 1] = "wrong tween property: " .. problem end
                    end
                end
                return dummy("Tween", ctx)
            end
        elseif n == "VirtualInputManager" then
            s.SendKeyEvent = function(_, down, key) ctx.keys[#ctx.keys + 1] = {down = down, key = key, t = ctx.now} end
            s.SendMouseButtonEvent = function(_, _, _, _, down) ctx.mouse[#ctx.mouse + 1] = {down = down} end
        elseif n == "Stats" and scenario.ping then
            s.Network = {ServerStatsItem = {["Data Ping"] = {GetValue = function() return scenario.ping end}}}
        elseif n == "HttpService" then
            s.JSONDecode = function(_, raw)
                if raw == "SETTINGS_RAW" then
                    if scenario.settingsThrows then error("malformed json") end
                    return scenario.settings
                end
                return {url = "https://i.waifu.pics/a.png"}
            end
            s.JSONEncode = function(_, t) ctx.encoded = t; return "{}" end
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
        rawset(inst, "InputBegan", {Connect = function(_, fn) rawset(inst, "__inputBegan", fn); return {Disconnect = function() end} end})
        rawset(inst, "MouseButton1Click", {Connect = function(_, fn)       -- keep each button's own handlers reachable
            ctx.callbacks[#ctx.callbacks + 1] = fn
            local mine = rawget(inst, "__clicks") or {}
            rawset(inst, "__clicks", mine)
            mine[#mine + 1] = fn
            return {Disconnect = function() ctx.disconnects = ctx.disconnects + 1 end}
        end})
        return inst
    end}
    for _, n in ipairs({"UDim2", "UDim", "Color3", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint",
                        "TweenInfo", "CFrame", "Enum", "Vector3"}) do
        env[n] = dummy(n, ctx)
    end
    env.Vector2 = {new = function(x, y) return {X = x or 0, Y = y or 0} end}
    env.typeof = function(v) return isInstanceLike(v) and "Instance" or type(v) end
    env.Enum.AnimationPriority.Action = {Value = 2}                      -- real Roblox: Idle 0, Movement 1, Action 2, Action2 3 ...
    env.task = {
        spawn = function(f, ...) local ok, e = pcall(f, ...); if not ok then errors[#errors + 1] = "task: " .. tostring(e) end end,
        wait = function(t) ctx.waits[#ctx.waits + 1] = t or 0; ctx.now = ctx.now + (t or 0); return 0 end,
    }
    env.warn = function(...) errors[#errors + 1] = "warn: " .. table.concat({...}, " ") end
    env.print = function() end
    ctx.now = 1000                                                      -- fake clock: only task.wait / advance() move it
    env.os = {clock = function() return ctx.now end}
    if not math.clamp then   -- stock Lua lacks the Luau additions the script uses; real Luau already has them
        env.math = setmetatable({clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end}, {__index = math})
    end
    if not table.find then
        env.table = setmetatable({find = function(t, v) for i, x in ipairs(t) do if x == v then return i end end end}, {__index = table})
    end
    env._G = genvStore
    env.getgenv = function() return genvStore end
    ctx.readPaths, ctx.deleted = {}, {}
    if scenario.settings or scenario.settingsThrows then
        env.isfile = function() return true end
        env.readfile = function(path) ctx.readPaths[#ctx.readPaths + 1] = path; return "SETTINGS_RAW" end
    end
    if not scenario.noDelfile then env.delfile = function(path) ctx.deleted[#ctx.deleted + 1] = path end end
    if scenario.executor == "full" then
        env.request = function(req)
            if req.Url:find("api.waifu.pics", 1, true) then return {StatusCode = 200, Body = '{"url":"https://i.waifu.pics/a.png"}'} end
            return {StatusCode = 200, Body = scenario.body}
        end
        env.writefile = function(path, body) writes[#writes + 1] = {path = path, body = body} end  -- returns nothing, like real executors
        env.getcustomasset = function(p) assets[#assets + 1] = p; return "rbxasset://" .. p end
    end

    local fn, err = compile(readScript(), "@" .. SCRIPT, env)
    if not fn then return nil, {"SYNTAX ERROR: " .. err} end
    local ok, e = pcall(fn)
    if not ok then errors[#errors + 1] = "top level: " .. tostring(e) end

    local bgSet = false
    local function textOf(pattern)
        for _, inst in ipairs(instances) do
            local t = rawget(inst, "Text")
            if type(t) == "string" and t:find(pattern) then return t end
        end
    end
    for _, inst in ipairs(instances) do
        local img = rawget(inst, "Image")
        if type(img) == "string" and img:find("animation_hub_bg_", 1, true) then bgSet = true end
    end
    local function findButton(text)             -- a real TextButton (not a label) showing this text
        for _, inst in ipairs(instances) do
            if rawget(inst, "__name") == "TextButton" and rawget(inst, "Text") == text then return inst end
        end
    end
    local function findLastButton(text)         -- the newest one (after a menu rebuild the old menu's buttons still exist)
        for i = #instances, 1, -1 do
            local inst = instances[i]
            if rawget(inst, "__name") == "TextButton" and rawget(inst, "Text") == text then return inst end
        end
    end
    local function tap(inst)                                               -- fire a real button's click handlers
        for _, fn in ipairs(rawget(inst, "__clicks") or {}) do
            local ok, e = pcall(fn)
            if not ok then errors[#errors + 1] = "tap: " .. tostring(e) end
        end
    end
    local function toggleRowHit(labelText)                                 -- the full-row hit area of a Toggle
        for _, inst in ipairs(instances) do
            if rawget(inst, "__name") == "TextLabel" and rawget(inst, "Text") == labelText then
                local row = rawget(inst, "Parent")
                for _, kid in ipairs(row and rawget(row, "__children") or {}) do
                    if rawget(kid, "__name") == "TextButton" and rawget(kid, "Text") == "" then return kid end
                end
            end
        end
    end
    local function fireKey(keyCode, gameProcessed)                         -- a real key press reaches UserInputService.InputBegan
        local input = {KeyCode = keyCode, UserInputType = env.Enum.UserInputType.Keyboard}
        for _, fn in ipairs(ctx.inputBegan) do
            local ok, e = pcall(fn, input, gameProcessed or false)
            if not ok then errors[#errors + 1] = "InputBegan handler: " .. tostring(e) end
        end
    end
    local function playAnimation(id, looped)
        for _, fn in ipairs(ctx.animPlayed) do
            local ok, e = pcall(fn, {Animation = {AnimationId = id}, Looped = looped})
            if not ok then errors[#errors + 1] = "AnimationPlayed handler: " .. tostring(e) end
        end
    end
    local function advance(seconds) ctx.now = ctx.now + seconds end
    local function save()                                                  -- press "Save config"; returns the table that was written
        ctx.encoded = nil
        local b = findLastButton("Save config")
        if not b then errors[#errors + 1] = "no 'Save config' button"; return nil end
        tap(b)
        return ctx.encoded
    end
    local function frames(seconds, step)                                   -- run the game loop: clock moves, Heartbeat fires
        step = step or 0.016
        local n = math.max(1, math.floor(seconds / step + 0.5))
        for _ = 1, n do
            ctx.now = ctx.now + step
            for _, hb in ipairs(ctx.heartbeats) do pcall(hb, step) end
        end
    end
    local function fireInput(userInputType, keyCode, gameProcessed)
        local input = {UserInputType = userInputType, KeyCode = keyCode or env.Enum.KeyCode.Unknown}
        for _, fn in ipairs(ctx.inputBegan) do
            local ok, e = pcall(fn, input, gameProcessed or false)
            if not ok then errors[#errors + 1] = "InputBegan handler: " .. tostring(e) end
        end
    end
    local function swing(i, priority, looped, id, length)                  -- enemy i starts an attack animation
        for _, fn in ipairs(enemyAnim[i] or {}) do
            local ok, e = pcall(fn, {Animation = {AnimationId = id or "rbxassetid://777"}, Looped = looped or false, Priority = {Value = priority or 3}, Length = length})
            if not ok then errors[#errors + 1] = "enemy AnimationPlayed handler: " .. tostring(e) end
        end
    end
    local function hurt(amount)                                            -- I lose health: Humanoid.HealthChanged fires
        if not myHum then return end
        myHum.Health = myHum.Health - amount
        for _, fn in ipairs(myHealth) do
            local ok, e = pcall(fn, myHum.Health)
            if not ok then errors[#errors + 1] = "HealthChanged handler: " .. tostring(e) end
        end
    end
    local function drag(inst, fromX, fromY, toX, toY)                      -- press on a GUI object, move the pointer, release
        local down = rawget(inst, "__inputBegan")
        if not down then errors[#errors + 1] = "drag: object has no InputBegan handler"; return end
        local M1, MM = env.Enum.UserInputType.MouseButton1, env.Enum.UserInputType.MouseMovement
        pcall(down, {UserInputType = M1, Position = {X = fromX, Y = fromY}})
        for step = 1, 4 do
            local x, y = fromX + (toX - fromX) * step / 4, fromY + (toY - fromY) * step / 4
            for _, fn in ipairs(ctx.inputChanged) do pcall(fn, {UserInputType = MM, Position = {X = x, Y = y}}) end
        end
        for _, fn in ipairs(ctx.inputEnded) do pcall(fn, {UserInputType = M1, Position = {X = toX, Y = toY}}) end
    end
    return {instances = instances, save = save, findLastButton = findLastButton, hurt = hurt, drag = drag, frames = frames, fireInput = fireInput, swing = swing, myWrites = myWrites, advance = advance, tap = tap, toggleRowHit = toggleRowHit, fireKey = fireKey, playAnimation = playAnimation,
            findButton = findButton, textOf = textOf, errors = errors, ctx = ctx, writes = writes, assets = assets, bgSet = bgSet, genv = genvStore, env = env, fn = fn}
end

local failures = {}
local function check(cond, msg) if not cond then failures[#failures + 1] = msg end end

-- click every handler, newest first (so the Close button runs last); `times` = clicks per handler
local function clickAll(r, times)
    local n = 0
    for i = #r.ctx.callbacks, 1, -1 do
        for _ = 1, times do
            local ok2, e2 = pcall(r.ctx.callbacks[i])
            n = n + 1
            if not ok2 then failures[#failures + 1] = "click handler: " .. tostring(e2) end
        end
    end
    return n
end

-- 1. normal executor, valid PNG, 100 ms ping
local a, synErr = run({executor = "full", body = PNG, ping = 100})
if not a then print(synErr[1]); finish(1) end
for _, e in ipairs(a.errors) do failures[#failures + 1] = e end
check(#a.writes == 1 and a.writes[1].path:match("%.png$"), "background: expected exactly one .png written (writefile returns nothing on success!)")
check(a.bgSet, "background: Image was never set from getcustomasset")
check(type(a.genv.__AnimationHubCleanup) == "function", "cleanup function not registered")

-- ping: feed a few Heartbeat ticks, the label must show the measured 100 ms
for _ = 1, 6 do for _, hb in ipairs(a.ctx.heartbeats) do pcall(hb, 1) end end
check(a.textOf("Ping: 100 ms"), "ping label did not show the measured 100 ms; got: " .. tostring(a.textOf("^Ping:") or "no label"))
check(a.textOf("Gaps now"), "effective-gaps label missing")
check(a.textOf("%(auto%)"), "auto timing should be on by default")

-- every handler twice in a row: toggles flip and flip back, so Auto timing stays ON while the macros run
local beforeDrawers = #a.ctx.callbacks
local clicked = clickAll(a, 2)
clicked = clicked + clickAll(a, 2)      -- again: now also reaches the controls inside the option drawers
print("exercised " .. clicked .. " clicks on " .. #a.ctx.callbacks .. " handlers (" .. (#a.ctx.callbacks - beforeDrawers) .. " created by opening option drawers)")
check(#a.ctx.callbacks - beforeDrawers > 50, "opening the Opt drawers should create many more controls")

-- macros ran with auto timing: dependent gaps (move 0.5, dash 0.3) must always be shortened,
-- independent ones (M1 0.2, jump 0.25) untouched, nothing negative
local saw = {short_move = false, m1 = false, raw_move = false, raw_dash = false, neg = false, jump = false}
for _, w in ipairs(a.ctx.waits) do
    if math.abs(w - 0.4) < 1e-9 then saw.short_move = true end   -- 0.5 s move gap minus min(100 ms, 40%)
    if math.abs(w - 0.2) < 1e-9 then saw.m1 = true end
    if math.abs(w - 0.25) < 1e-9 then saw.jump = true end
    if math.abs(w - 0.5) < 1e-9 then saw.raw_move = true end
    if math.abs(w - 0.3) < 1e-9 then saw.raw_dash = true end
    if w < 0 then saw.neg = true end
end
check(saw.short_move, "auto timing did not shorten the 0.5 s move gap to 0.4 s")
check(saw.m1, "M1 gaps should stay at 0.2 s")
check(saw.jump, "jump gaps should stay at 0.25 s")
check(not saw.raw_move, "a move gap went out uncompensated (0.5 s)")
check(not saw.raw_dash, "a dash gap went out uncompensated (0.3 s)")
check(not saw.neg, "negative wait produced")

do
-- 1b. single clicks: floating bar state + clean-up
local f = run({executor = "full", body = PNG})
for _, e in ipairs(f.errors) do failures[#failures + 1] = "scenario f: " .. e end
clickAll(f, 1)
check(f.ctx.disconnects > 0, "cleanup did not disconnect any listener")
check(f.genv.__AnimationHubCleanup == nil, "cleanup should unregister itself")

-- 1c. the bar's state (position / lock / minimised) is part of the config, written only by "Save config"
local fc = run({executor = "full", body = PNG})
for _, e in ipairs(fc.errors) do failures[#failures + 1] = "bar state scenario: " .. e end
local lockB, minB = fc.findLastButton("Lock"), fc.findLastButton("-")
check(lockB ~= nil and minB ~= nil, "bar: the Lock / - buttons are missing")
if lockB then fc.tap(lockB) end
if minB then fc.tap(minB) end
check(fc.ctx.encoded == nil, "bar: changing the bar must not write anything by itself")
local fcEnc = fc.save()
local fab = fcEnc and fcEnc.fab
check(type(fab) == "table", "floating bar state was not part of the saved config")
if fab then
    check(fab.locked == true, "Lock button did not lock")
    check(fab.minimized == true, "minimise button did not minimise")
    check(type(fab.x) == "number" and fab.x >= 4 and fab.x <= 800, "bar x is off screen: " .. tostring(fab.x))
    check(type(fab.y) == "number" and fab.y >= 4 and fab.y <= 450, "bar y is off screen: " .. tostring(fab.y))
end
local fcRestore = run({executor = "full", body = PNG, settings = {fab = {x = 123, y = 45, locked = true, minimized = true}}})
for _, e in ipairs(fcRestore.errors) do failures[#failures + 1] = "bar restore scenario: " .. e end
local fcAgain = fcRestore.save()
check(fcAgain and fcAgain.fab and fcAgain.fab.x == 123 and fcAgain.fab.y == 45 and fcAgain.fab.locked == true and fcAgain.fab.minimized == true,
    "a saved config must restore the bar's position / lock / minimised state")
local fcBad = run({executor = "full", body = PNG, settings = {fab = {x = "left", y = {}, locked = "yes", minimized = 1}}})
for _, e in ipairs(fcBad.errors) do failures[#failures + 1] = "bad bar settings: " .. e end
local fcBadEnc = fcBad.save()
check(fcBadEnc and fcBadEnc.fab and type(fcBadEnc.fab.x) == "number" and fcBadEnc.fab.locked == false and fcBadEnc.fab.minimized == false,
    "garbage bar settings must fall back to defaults")

-- 2. re-running the script must clean the previous copy first
local b = run({executor = "full", body = PNG})
local before = b.ctx.disconnects
local lock0 = b.findButton("Lock"); if lock0 then b.tap(lock0) end           -- the user changes the bar...
local ok3 = pcall(b.fn)                      -- ...then runs the script again in the same environment
check(ok3, "second execution crashed")
check(b.ctx.disconnects > before, "re-run did not clean up the previous instance")
check(b.genv.__AnimationHubSession == nil, "re-run: nothing may be carried over to a plain re-run")
local lock1 = b.findLastButton("Lock")
local b2 = b.save()
check(b2 and b2.fab and b2.fab.locked == false and lock1 ~= lock0, "re-run: a plain re-run starts fresh - the bar must not stay locked")
check(#b.ctx.readPaths == 0 or b.ctx.readPaths[1] == "animation_hub_config.json", "the config file name must be animation_hub_config.json")

-- 3. image host returns an HTML error page -> nothing written, no crash
local c = run({executor = "full", body = "<html>429 Too Many Requests</html>"})
for _, e in ipairs(c.errors) do failures[#failures + 1] = "html scenario: " .. e end
check(#c.writes == 0 and not c.bgSet, "html error page must not be saved as an image")

-- 4. executor without file functions -> UI still builds, no network image
local d = run({executor = "nofiles", body = PNG})
for _, e in ipairs(d.errors) do failures[#failures + 1] = "nofiles scenario: " .. e end
check(#d.writes == 0 and not d.bgSet, "no-file executor must skip the background")

-- 5. saved settings: garbage values are cleaned up, valid ones applied, and the file is re-written
local g = run({executor = "full", body = PNG, settings = {
    timing = {m1 = 0.3, dash = "bad"}, auto = {on = false, strength = 99}, speed = 1.4,
    combos = {Kyoto = {speed = 99, auto = "weird", side = "Right", move = 0.7}, [7] = {speed = 1}},
    pins = {Kyoto = {x = 120, y = 80}, Bogus = {x = "a"}, NoSuchCombo = {x = 5, y = 6}},
}})
for _, e in ipairs(g.errors) do failures[#failures + 1] = "settings scenario: " .. e end
for _ = 1, 40 do for _, hb in ipairs(g.ctx.heartbeats) do pcall(hb, 1) end end      -- lots of time passes
check(g.ctx.encoded == nil, "a loaded config must not be re-written on its own")
check(g.ctx.readPaths[1] == "animation_hub_config.json", "the hub must read animation_hub_config.json, got " .. tostring(g.ctx.readPaths[1]))
local enc = g.save()
check(type(enc) == "table", "Save config did not write the settings")
for _, w in ipairs(g.writes) do
    if w.path:find("%.json$") then check(w.path == "animation_hub_config.json", "config written to the wrong file: " .. w.path) end
end
if enc then
    check(enc.timing and enc.timing.m1 == 0.3 and enc.timing.dash == 0.3, "timing: valid value kept, bad value back to default")
    check(enc.auto and enc.auto.on == false and enc.auto.strength == 1.5, "auto: off kept, strength clamped to 1.5")
    check(enc.speed == 1.4, "overall speed lost")
    local k = enc.combos and enc.combos.Kyoto
    check(k and k.speed == 2 and k.auto == "global" and k.side == "Right" and k.move == 0.7, "per-combo options were not cleaned up / kept")
    check(not (enc.combos and enc.combos[7]), "non-string combo name must be dropped")
end
check(g.textOf("%(manual%)"), "auto timing off in the saved file must show (manual)")
local pinBtn = g.findButton("Kyoto")
check(pinBtn ~= nil, "a pin saved in the file must come back as an on-screen button")
check(pinBtn and rawget(pinBtn, "Visible") == true, "restored pin button must be visible")
check(g.textOf("Pins 1"), "the floating bar must show how many pins exist")
if enc then
    local pk = enc.pins and enc.pins.Kyoto
    check(pk and pk.x == 120 and pk.y == 80, "a pinned combo and its position must survive a save/load")
    check(enc.pins and enc.pins.Bogus == nil, "a pin with garbage coordinates must be dropped")
    check(enc.pins and enc.pins.NoSuchCombo and enc.pins.NoSuchCombo.x == 5, "a valid pin for an unknown combo is kept untouched")
end

-- 6. unreadable settings file must not stop the script
local h = run({executor = "full", body = PNG, settingsThrows = true})
for _, e in ipairs(h.errors) do failures[#failures + 1] = "bad settings file: " .. e end
check(h.textOf("Gaps now") ~= nil, "script did not finish building with a broken settings file")

end

-- 7. ASSIST: arm the Garou catch, then cast Hunter's Grasp "yourself" - the script must play only what comes after
local function pressed(r, key) for _, k in ipairs(r.ctx.keys) do if k.down and k.key == key then return true end end return false end
local as = run({executor = "full", body = PNG, settings = {pins = {Garou_Catch = {x = 100, y = 100}}}})
for _, e in ipairs(as.errors) do failures[#failures + 1] = "assist scenario: " .. e end
local K, UIT = as.env.Enum.KeyCode, as.env.Enum.UserInputType
local catchBtn = as.findButton("Garou Catch")
check(catchBtn ~= nil, "assist: the pinned Garou catch button is missing")
as.fireKey(K.Three)
check(#as.ctx.keys == 0 and #as.ctx.mouse == 0, "assist: a combo that is NOT armed must never react to your casts")
if catchBtn then as.tap(catchBtn) end                                   -- arm it (assist-mode pin = on/off toggle)
as.fireKey(K.Two)
check(#as.ctx.keys == 0, "assist: casting a move that is not the trigger must do nothing")
as.fireKey(K.Three, true)
check(#as.ctx.keys == 0, "assist: input the game already consumed (gameProcessed) must be ignored")
as.fireKey(K.Three)                                                     -- YOU cast Hunter's Grasp
check(pressed(as, K.Q), "assist: after your Hunter's Grasp it must side dash (Q)")
check(pressed(as, K.A), "assist: the side dash must use the Left (A) key by default")
check(#as.ctx.mouse >= 2, "assist: the M1 after the side dash was not clicked")
check(not pressed(as, K.Three), "assist: the script pressed Hunter's Grasp itself - that step is YOURS")
local afterFirst = #as.ctx.keys
as.fireKey(K.Three)
check(#as.ctx.keys == afterFirst, "assist: its own inputs / a quick repeat must not re-trigger (cooldown)")
as.advance(2)                                                           -- cooldown over, still armed
as.fireKey(K.Three)
check(#as.ctx.keys > afterFirst, "assist: after the cooldown a new cast must trigger it again")
local afterSecond = #as.ctx.keys
if catchBtn then as.tap(catchBtn) end                                   -- DISARM
as.advance(2)
as.fireKey(K.Three)
check(#as.ctx.keys == afterSecond, "assist: once disarmed, your casts must not trigger anything")

-- 7b. run-mode pin (side dash left) runs immediately; assist-mode pins never do
local sd = run({executor = "full", body = PNG, settings = {pins = {SideDash_Left = {x = 90, y = 90}}}})
for _, e in ipairs(sd.errors) do failures[#failures + 1] = "side dash scenario: " .. e end
local sdBtn = sd.findButton("Dash Left")
check(sdBtn ~= nil, "side dash: pinned button missing")
if sdBtn then sd.tap(sdBtn) end
check(pressed(sd, sd.env.Enum.KeyCode.Q) and pressed(sd, sd.env.Enum.KeyCode.A), "side dash left button must press Q + A")
check(not pressed(sd, sd.env.Enum.KeyCode.D), "side dash left must not press D")

-- 7c. learned animation trigger (touch players)
local an = run({executor = "full", body = PNG, settings = {
    pins = {Garou_Catch = {x = 100, y = 100}}, combos = {Garou_Catch = {trigAnim = "rbxassetid://99"}},
}})
for _, e in ipairs(an.errors) do failures[#failures + 1] = "animation scenario: " .. e end
local anBtn = an.findButton("Garou Catch")
if anBtn then an.tap(anBtn) end
an.playAnimation("rbxassetid://99", true)
check(#an.ctx.keys == 0, "animation trigger: a LOOPED animation (walk / idle) must be ignored")
an.playAnimation("rbxassetid://5", false)
check(#an.ctx.keys == 0, "animation trigger: a different animation must be ignored")
an.playAnimation("rbxassetid://99", false)
check(pressed(an, an.env.Enum.KeyCode.Q), "animation trigger: the learned animation must start the follow-up")

-- 7d. auto side dash after my moves
local au = run({executor = "full", body = PNG})
for _, e in ipairs(au.errors) do failures[#failures + 1] = "auto side dash scenario: " .. e end
au.fireKey(au.env.Enum.KeyCode.One)
check(#au.ctx.keys == 0, "auto side dash: off by default")
local hit = au.toggleRowHit("Auto side dash after my moves")
check(hit ~= nil, "auto side dash: toggle not found")
if hit then au.tap(hit) end
au.fireKey(au.env.Enum.KeyCode.Q)                                       -- Q is not a move key
check(#au.ctx.keys == 0, "auto side dash: a non-move key must not trigger it")
au.fireKey(au.env.Enum.KeyCode.One)                                     -- you cast move 1
check(pressed(au, au.env.Enum.KeyCode.Q) and pressed(au, au.env.Enum.KeyCode.A), "auto side dash: first dash goes Left (Alternate starts Left)")

-- 8. SIDE DASH toward the closest player: picks the A or D key, never moves you
local ME, LOOK = {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = -1}
local function keyNamed(r, name) return r.env.Enum.KeyCode[name] end
local rightSide = run({executor = "full", body = PNG, settings = {pins = {SideDash_Closest = {x = 90, y = 90}}}, world = {
    me = {pos = ME, look = LOOK}, right = {x = 1, y = 0, z = 0},
    enemies = {{name = "Far", pos = {x = -80, y = 0, z = 0}, look = LOOK}, {name = "Near", pos = {x = 12, y = 0, z = -4}, look = LOOK}}}})
for _, e in ipairs(rightSide.errors) do failures[#failures + 1] = "closest side dash (right): " .. e end
local closeBtn = rightSide.findButton("Side Dash")
check(closeBtn ~= nil, "closest side dash: the round button is missing")
if closeBtn then rightSide.tap(closeBtn) end
check(pressed(rightSide, keyNamed(rightSide, "D")) and pressed(rightSide, keyNamed(rightSide, "Q")), "closest side dash: nearest player is on my right -> Q + D")
check(not pressed(rightSide, keyNamed(rightSide, "A")), "closest side dash: must not press A when the nearest player is on the right")
check(#rightSide.myWrites == 0, "closest side dash: it must NOT move / teleport me - my character was written to: " .. table.concat(rightSide.myWrites, ","))

local leftSide = run({executor = "full", body = PNG, settings = {pins = {SideDash_Closest = {x = 90, y = 90}}}, world = {
    me = {pos = ME, look = LOOK}, right = {x = 1, y = 0, z = 0},
    enemies = {{name = "Near", pos = {x = -9, y = 0, z = -2}, look = LOOK}, {name = "Far", pos = {x = 70, y = 0, z = 0}, look = LOOK}}}})
local lb = leftSide.findButton("Side Dash")
if lb then leftSide.tap(lb) end
check(pressed(leftSide, keyNamed(leftSide, "A")) and not pressed(leftSide, keyNamed(leftSide, "D")), "closest side dash: nearest player on my left -> Q + A")

local nobody = run({executor = "full", body = PNG, settings = {pins = {SideDash_Closest = {x = 90, y = 90}}}, world = {
    me = {pos = ME, look = LOOK}, enemies = {}}})
local nb = nobody.findButton("Side Dash")
if nb then nobody.tap(nb) end
check(pressed(nobody, keyNamed(nobody, "A")), "closest side dash: with nobody around it falls back to Left (A) instead of failing")

-- every side dash inside a tech / combo follows the same rule (default side = Closest)
local techDash = run({executor = "full", body = PNG, settings = {pins = {Garou_Catch = {x = 100, y = 100}}}, world = {
    me = {pos = ME, look = LOOK}, right = {x = 1, y = 0, z = 0}, enemies = {{name = "Near", pos = {x = 10, y = 0, z = 0}, look = LOOK}}}})
local tdBtn = techDash.findButton("Garou Catch")
if tdBtn then techDash.tap(tdBtn) end
techDash.fireKey(techDash.env.Enum.KeyCode.Three)
check(pressed(techDash, keyNamed(techDash, "D")), "assist combos: their SIDEDASH steps must also go toward the closest player")
check(#techDash.myWrites == 0, "assist combos: side dash must not move me")

-- 9. AUTO BLOCK: blocks every hit, lets go quickly, drops the moment I punch
local BLOCKER = {x = 0, y = 0, z = -6}
local TOWARD_ME = {x = 0, y = 0, z = 1}                                    -- enemy looks back at me (I am at the origin)
local function blockWorld(enemyPos, enemyLook)
    return {me = {pos = ME, look = LOOK}, enemies = {{name = "Enemy", pos = enemyPos, look = enemyLook}}}
end
local function fEvents(r, F)                                               -- list of {down=bool, t=time} for the F key
    local out = {}
    for _, k in ipairs(r.ctx.keys) do if k.key == F then out[#out + 1] = k end end
    return out
end
local function newBlocker(world, extra)
    local r = run({executor = "full", body = PNG, ping = extra and extra.ping, world = world or blockWorld(BLOCKER, TOWARD_ME)})
    for _, e in ipairs(r.errors) do failures[#failures + 1] = "auto block scenario: " .. e end
    if extra and extra.ping then r.frames(2) end                              -- let it measure the ping
    local hit = r.toggleRowHit("Auto block")
    if hit then r.tap(hit) end
    return r, keyNamed(r, "F")
end

-- off by default
local off = run({executor = "full", body = PNG, world = blockWorld(BLOCKER, TOWARD_ME)})
off.swing(1); off.frames(1)
check(#fEvents(off, keyNamed(off, "F")) == 0, "auto block: off by default - it must not block")

-- one hit: press after the (ping-shortened) delay, release shortly after the attack
local ab, F = newBlocker(nil, {ping = 100})
local t0 = ab.ctx.now
ab.swing(1, 3, true);  ab.frames(0.5)
check(#fEvents(ab, F) == 0, "auto block: a looping animation (walk / idle) is not an attack")
ab.swing(1, 1, false); ab.frames(0.5)
check(#fEvents(ab, F) == 0, "auto block: a low-priority animation layer is not an attack")
t0 = ab.ctx.now
ab.swing(1, 3, false)                                                      -- their attack starts now
ab.frames(0.03)
check(#fEvents(ab, F) == 0, "auto block: it must wait for the delay (0.10 s shortened by the 100 ms ping = 0.06 s)")
ab.frames(0.06)
local ev = fEvents(ab, F)
check(#ev == 1 and ev[1].down, "auto block: F must go down after ~0.06 s")
check(ev[1] and math.abs((ev[1].t - t0) - 0.06) < 0.03, "auto block: F went down at the wrong time: " .. tostring(ev[1] and (ev[1].t - t0)))
ab.frames(1.0)
ev = fEvents(ab, F)
check(#ev == 2 and not ev[2].down, "auto block: F must be released again once their attack is over")
check(ev[2] and (ev[2].t - t0) < 0.8, "auto block: it must let go within a second so I can punch - held until " .. tostring(ev[2] and (ev[2].t - t0)))

-- every hit of a combo: one continuous block (no gap, no re-press), released after the last hit
local combo, F2 = newBlocker()
local c0 = combo.ctx.now
combo.swing(1, 3, false); combo.frames(0.30)
combo.swing(1, 3, false); combo.frames(0.30)
combo.swing(1, 3, false); combo.frames(0.30)
local downs = 0
for _, k in ipairs(fEvents(combo, F2)) do if k.down then downs = downs + 1 end end
check(downs == 1, "auto block: a combo must be ONE continuous block, F went down " .. downs .. " times")
local stillHeld = true
for _, k in ipairs(fEvents(combo, F2)) do if not k.down then stillHeld = false end end
check(stillHeld, "auto block: it released in the middle of a combo - a hit would have gone through")
combo.frames(1.0)
local lastEv = fEvents(combo, F2)
check(not lastEv[#lastEv].down, "auto block: it must let go after the combo ends")

-- never holds longer than the cap, even if they never stop
local chain, F3 = newBlocker()
for _ = 1, 14 do chain.swing(1, 3, false); chain.frames(0.25) end
local longest, pressedAt = 0, nil
for _, k in ipairs(fEvents(chain, F3)) do
    if k.down then pressedAt = k.t elseif pressedAt then longest = math.max(longest, k.t - pressedAt); pressedAt = nil end
end
check(longest > 0 and longest <= 1.05, "auto block: one block must never be held longer than ~1 s, longest was " .. longest)

-- I punch: M1 drops the block at once; no instant re-block; later hits are blocked again
local pu, F4 = newBlocker()
pu.swing(1, 3, false); pu.frames(0.2)
check(#fEvents(pu, F4) == 1, "auto block (punch): should be blocking now")
pu.fireInput(pu.env.Enum.UserInputType.MouseButton1)
local pe = fEvents(pu, F4)
check(#pe == 2 and not pe[2].down, "auto block (punch): M1 must drop the block immediately")
pu.swing(1, 3, false); pu.frames(0.2)
check(#fEvents(pu, F4) == 2, "auto block (punch): right after my punch it must not clamp down again")
pu.frames(0.5)
pu.swing(1, 3, false); pu.frames(0.2)
check(#fEvents(pu, F4) == 3, "auto block (punch): after the short pause it must block the next hit")
local pg = newBlocker()
pg.swing(1, 3, false); pg.frames(0.2)
pg.fireInput(pg.env.Enum.UserInputType.MouseButton1, nil, true)           -- consumed by the game's UI: not a real punch
check(#fEvents(pg, keyNamed(pg, "F")) == 1, "auto block (punch): input already consumed by the game must not count")

-- switching it off while holding lets go of F
local sw, F5 = newBlocker()
sw.swing(1, 3, false); sw.frames(0.2)
local swHit = sw.toggleRowHit("Auto block")
if swHit then sw.tap(swHit) end
local se = fEvents(sw, F5)
check(#se == 2 and not se[2].down, "auto block: switching it off while blocking must release F")

-- a combo / assist starting lets go of F as well (otherwise its own inputs run into the held block)
local am = run({executor = "full", body = PNG, settings = {pins = {SideDash_Left = {x = 90, y = 90}}}, world = blockWorld(BLOCKER, TOWARD_ME)})
local amHit = am.toggleRowHit("Auto block")
if amHit then am.tap(amHit) end
local AF = keyNamed(am, "F")
am.swing(1, 3, false); am.frames(0.2)
check(#fEvents(am, AF) == 1, "auto block (macro): should be blocking before the combo starts")
local dashBtn = am.findButton("Dash Left")
if dashBtn then am.tap(dashBtn) end
local ae = fEvents(am, AF)
check(#ae == 2 and not ae[2].down, "auto block (macro): starting a combo / side dash must let go of F first")

local function blockedWith(world)
    local r, f = newBlocker(world)
    r.swing(1, 3, false); r.frames(0.6)
    return #fEvents(r, f) > 0
end
check(not blockedWith(blockWorld({x = 0, y = 0, z = -40}, TOWARD_ME)), "auto block: attacker out of range must be ignored")
check(not blockedWith(blockWorld(BLOCKER, {x = 0, y = 0, z = -1})), "auto block: attacker looking away must be ignored")
check(not blockedWith(blockWorld({x = 0, y = 0, z = 6}, {x = 0, y = 0, z = -1})), "auto block: an attack from BEHIND cannot be blocked - do not waste F")
check(blockedWith(blockWorld({x = 3, y = 0, z = -5}, {x = -0.5, y = 0, z = 1})), "auto block: slightly off-centre but aimed at me must still block")

do
-- 10. TECH TOGGLES: every tech in the character tab is an on/off switch that arms Assist
local tg = run({executor = "full", body = PNG, world = {me = {pos = ME, look = LOOK}, enemies = {}}})
for _, e in ipairs(tg.errors) do failures[#failures + 1] = "tech toggle scenario: " .. e end
local flowHit = tg.toggleRowHit("Flowing + Grasp")
check(flowHit ~= nil, "tech toggles: the Garou 'Flowing + Grasp' switch is missing")
tg.fireKey(tg.env.Enum.KeyCode.One)
check(#tg.ctx.keys == 0, "tech toggles: off by default")
if flowHit then tg.tap(flowHit) end
tg.fireKey(tg.env.Enum.KeyCode.Two)                                              -- not the trigger (Lethal)
check(#tg.ctx.keys == 0, "tech toggles: a different move must not trigger it")
tg.fireKey(tg.env.Enum.KeyCode.One)                                              -- YOU cast Flowing Water
check(pressed(tg, keyNamed(tg, "Q")) and pressed(tg, tg.env.Enum.KeyCode.Three), "tech toggles: after your Flowing Water it must side dash and cast Hunter's Grasp")
check(not pressed(tg, tg.env.Enum.KeyCode.One), "tech toggles: it must not press Flowing Water itself")

-- 11. MENU REBUILD with a new theme (rebuild enabled in this one scenario)
local rb = run({executor = "full", body = PNG, allowRebuild = true, settings = {ui = {theme = "Ocean", scale = 1.1, glass = 0.6}}})
for _, e in ipairs(rb.errors) do failures[#failures + 1] = "rebuild scenario: " .. e end
check(rb.genv.__AnimationHubCleanup ~= nil, "rebuild scenario: menu did not start with a saved theme")
local applyBtn = rb.findButton("Apply theme (rebuilds the menu)")
check(applyBtn ~= nil, "rebuild: the Apply theme button is missing")
local cleanupBefore = rb.genv.__AnimationHubCleanup
if applyBtn then rb.tap(applyBtn) end
check(rb.genv.__AnimationHubCleanup ~= nil and rb.genv.__AnimationHubCleanup ~= cleanupBefore, "rebuild: a fresh menu instance must replace the old one")
check(rb.genv.__AnimationHubSession == nil, "rebuild: the hand-over table must be consumed by the new menu")
local rbEnc = rb.save()
check(rbEnc and rbEnc.ui and rbEnc.ui.theme == "Ocean", "rebuild: the chosen theme must survive the rebuild")
check(rbEnc and rbEnc.ui and rbEnc.ui.scale == 1.1 and rbEnc.ui.glass == 0.6, "rebuild: menu size / glass must survive the rebuild")

end

do   -- (own scope: the main chunk may only hold 200 locals)
-- 12. AUTO BLOCK LEARNS WHEN THEY REALLY HIT: the damage I take teaches it each attack animation's hit time
local ID_A, ID_B = "rbxassetid://111", "rbxassetid://222"
local function learnRound(r, id, hitAfter, length)               -- they swing, `hitAfter` seconds later I lose health
    r.swing(1, 3, false, id, length or 0.5)
    r.frames(hitAfter)
    r.hurt(10)
    r.frames(1.6)                                                -- long pause: not part of the same chain
end
local lr = run({executor = "full", body = PNG, world = blockWorld(BLOCKER, TOWARD_ME)})
for _, e in ipairs(lr.errors) do failures[#failures + 1] = "learning scenario: " .. e end
learnRound(lr, ID_A, 0.2); learnRound(lr, ID_A, 0.2)
local learnedSaved = (lr.save() or {}).learned
local la = learnedSaved and learnedSaved[ID_A]
check(la ~= nil and la.n == 2, "learning: two hits should have been learned for the animation, got " .. tostring(la and la.n))
check(la and math.abs(la.offset - 0.2) < 0.03, "learning: hit offset should be ~0.2 s, got " .. tostring(la and la.offset))
check(la and la.length == 0.5, "learning: the animation's length (0.5 s) should be remembered, got " .. tostring(la and la.length))
check(#fEvents(lr, keyNamed(lr, "F")) == 0, "learning: while Auto block is OFF, learning must never press F")
lr.frames(1.1)
check(lr.textOf("Learned: 1 attack animation%(s%) from 2 hit%(s%)"), "learning: the label should report 1 animation / 2 hits; got: " .. tostring(lr.textOf("^Learned:")))
check(lr.textOf("Last: hit %d+ ms after"), "learning: the label should show the last measured hit time")

-- damage that no swing explains (poison, fall, a swing from behind a wall) teaches nothing
local lq = run({executor = "full", body = PNG, world = blockWorld(BLOCKER, TOWARD_ME)})
lq.hurt(15); lq.frames(0.3)                                                -- damage out of nowhere
lq.swing(1, 3, false, ID_A); lq.frames(2.0); lq.hurt(10)                   -- damage far too late for that swing
lq.swing(1, 3, true, ID_B); lq.frames(0.2); lq.hurt(10)                    -- a looping animation is not an attack
local lqEnc = lq.save()
check(lqEnc and (lqEnc.learned == nil or next(lqEnc.learned) == nil), "learning: damage nothing explains must not teach anything")
local lf = run({executor = "full", body = PNG, world = blockWorld({x = 0, y = 0, z = -40}, TOWARD_ME)})
lf.swing(1, 3, false, ID_A); lf.frames(0.2); lf.hurt(10)
local lfEnc = lf.save()
check(lfEnc and (lfEnc.learned == nil or next(lfEnc.learned) == nil), "learning: a swing from a player far away is not what hurt me")

-- "Learn from hits I take" off -> nothing is learned
local ln = run({executor = "full", body = PNG, world = blockWorld(BLOCKER, TOWARD_ME)})
local learnHit = ln.toggleRowHit("Learn from hits I take")
check(learnHit ~= nil, "learning: the 'Learn from hits I take' switch is missing")
if learnHit then ln.tap(learnHit) end
learnRound(ln, ID_A, 0.2); learnRound(ln, ID_A, 0.2); ln.frames(1.1)
check(ln.textOf("Learned: 0 attack animation%(s%) from 0 hit%(s%)"), "learning: with learning switched off nothing may be learned; got: " .. tostring(ln.textOf("^Learned:")))

-- "Forget learned timings" wipes it
local lg = run({executor = "full", body = PNG, world = blockWorld(BLOCKER, TOWARD_ME), settings = {learned = {[ID_A] = {n = 5, offset = 0.3, spread = 0.01, length = 0.4}}}})
lg.frames(1.1)
check(lg.textOf("Learned: 1 attack animation"), "learning: a saved timing should be loaded from the settings file; got: " .. tostring(lg.textOf("^Learned:")))
local forgetBtn = lg.findButton("Forget learned timings")
check(forgetBtn ~= nil, "learning: the Forget button is missing")
if forgetBtn then lg.tap(forgetBtn) end
lg.frames(1.1)
check(lg.textOf("Learned: 0 attack animation"), "learning: Forget must wipe the learned timings; got: " .. tostring(lg.textOf("^Learned:")))

-- garbage in the settings file is cleaned (no crash, bad entries dropped)
local lb2 = run({executor = "full", body = PNG, world = blockWorld(BLOCKER, TOWARD_ME), settings = {
    learned = {[ID_A] = {n = 3, offset = 99, spread = "x"}, [42] = {n = 1}, [ID_B] = "junk"}, floater = {x = "left", y = 5}}})
for _, e in ipairs(lb2.errors) do failures[#failures + 1] = "bad learned settings: " .. e end
lb2.frames(1.1)
check(lb2.textOf("Learned: 1 attack animation"), "learning: only the one valid saved entry should survive; got: " .. tostring(lb2.textOf("^Learned:")))

-- PREDICTION: with a learned hit time F goes down shortly BEFORE that hit, not at the fixed default delay
local LEARNED = {learned = {[ID_A] = {n = 5, offset = 0.30, spread = 0.01, length = 0.4}}}
local function blockerWith(extra)
    extra = extra or {}
    local r = run({executor = "full", body = PNG, ping = extra.ping, world = blockWorld(BLOCKER, TOWARD_ME), settings = extra.settings})
    for _, e in ipairs(r.errors) do failures[#failures + 1] = "prediction scenario: " .. e end
    if extra.ping then r.frames(2) end
    local hit = r.toggleRowHit("Auto block")
    if hit then r.tap(hit) end
    return r, keyNamed(r, "F")
end
local pr, PF = blockerWith({ping = 100, settings = LEARNED})
local p0 = pr.ctx.now
pr.swing(1, 3, false, ID_A, 0.4)
pr.frames(0.10)
check(#fEvents(pr, PF) == 0, "prediction: with a learned 0.30 s hit it must NOT press at the default delay (0.06 s)")
pr.frames(0.10)
local pe2 = fEvents(pr, PF)
check(#pe2 == 1 and pe2[1].down, "prediction: F should be down by 0.2 s (learned 0.30 - lead 0.05 - ping 0.10 = 0.15 s)")
check(pe2[1] and math.abs((pe2[1].t - p0) - 0.15) < 0.03, "prediction: F went down at the wrong time: " .. tostring(pe2[1] and (pe2[1].t - p0)))
pr.frames(0.4)
pe2 = fEvents(pr, PF)
check(#pe2 == 2 and not pe2[2].down, "prediction: F must be released again after the hit")
check(pe2[2] and (pe2[2].t - p0) > 0.35 and (pe2[2].t - p0) < 0.55, "prediction: F should be held through the hit (0.30 s) and let go ~0.45 s, got " .. tostring(pe2[2] and (pe2[2].t - p0)))
-- an animation it has not learned still uses the default delay
local pu2 = blockerWith({ping = 100, settings = LEARNED})
local pu0 = pu2.ctx.now
pu2.swing(1, 3, false, ID_B, 0.4); pu2.frames(0.10)
local pue = fEvents(pu2, keyNamed(pu2, "F"))
check(#pue == 1 and pue[1].down and (pue[1].t - pu0) < 0.12, "prediction: an animation it has not learned must use the default delay")
-- "Use learned timing" off -> default delay even for a learned animation
local po, POF = blockerWith({ping = 100, settings = LEARNED})
local useHit = po.toggleRowHit("Use learned timing (predict the punch)")
check(useHit ~= nil, "prediction: the 'Use learned timing' switch is missing")
if useHit then po.tap(useHit) end
po.swing(1, 3, false, ID_A, 0.4); po.frames(0.10)
check(#fEvents(po, POF) == 1, "prediction: with 'Use learned timing' off the fixed delay (0.06 s) must apply")
-- the lead slider's default (0.05 s) really is what presses early: no ping -> 0.30 - 0.05 = 0.25 s
local pn, PNF = blockerWith({settings = LEARNED})
local pn0 = pn.ctx.now
pn.swing(1, 3, false, ID_A, 0.4); pn.frames(0.18)
check(#fEvents(pn, PNF) == 0, "prediction: without ping F must wait until hit - lead (0.25 s)")
pn.frames(0.12)
local pne = fEvents(pn, PNF)
check(#pne == 1 and pne[1].down and math.abs((pne[1].t - pn0) - 0.25) < 0.03, "prediction: without ping F should go down ~0.25 s after the swing, got " .. tostring(pne[1] and (pne[1].t - pn0)))

-- CHAIN: after seeing A -> B a few times, A alone also covers the next punch (B) before it shows up
local CHAIN = {learned = {[ID_A] = {n = 5, offset = 0.20, spread = 0.01, length = 0.4}, [ID_B] = {n = 5, offset = 0.20, spread = 0.01, length = 0.4}}}
local function chainRun(chainOn, rounds, learnOff, blockStaysOn)
    local r = blockerWith({settings = CHAIN})
    local off2 = r.toggleRowHit("Auto block"); if off2 and not blockStaysOn then r.tap(off2) end   -- off while it watches the chain
    if learnOff then local l = r.toggleRowHit("Learn from hits I take"); if l then r.tap(l) end end
    for _ = 1, rounds or 4 do r.swing(1, 3, false, ID_A); r.frames(0.3); r.swing(1, 3, false, ID_B); r.frames(1.6) end
    if chainOn then local c = r.toggleRowHit("Predict chain hits (experimental)"); if c then r.tap(c) end end
    local on2 = r.toggleRowHit("Auto block"); if on2 and not blockStaysOn then r.tap(on2) end
    local F6 = keyNamed(r, "F")
    local before = #fEvents(r, F6)
    r.swing(1, 3, false, ID_A)                                                        -- only the FIRST punch is seen
    r.frames(0.6)
    local ev2 = fEvents(r, F6)
    return #ev2 - before, ev2[#ev2] and ev2[#ev2].down
end
local nOn, heldOn = chainRun(true)
local nOff, heldOff = chainRun(false)
check(nOn == 1 and heldOn == true, "chain prediction ON: F should still be held 0.6 s after the first punch (the 2nd punch is predicted); events " .. nOn)
check(nOff == 2 and heldOff == false, "chain prediction OFF: F should already be released 0.6 s after one punch; events " .. nOff)
local nFew, heldFew = chainRun(true, 2)
check(nFew == 2 and heldFew == false, "chain prediction: a pair seen only twice is not a pattern yet (needs 3 sightings); events " .. nFew)
local nNoLearn, heldNoLearn = chainRun(true, 4, true)
check(nNoLearn == 2 and heldNoLearn == false, "chain prediction: with 'Learn from hits' off it must not learn new chains; events " .. nNoLearn)
local nNoLearn2, heldNoLearn2 = chainRun(true, 4, true, true)       -- same, but Auto block is ON while the chains go by
check(nNoLearn2 == 2 and heldNoLearn2 == false, "chain prediction: Auto block on + 'Learn from hits' off must still not learn chains; events " .. nNoLearn2)

-- 13. THE FLOATER: a round, draggable Auto-block button
local fl = run({executor = "full", body = PNG, world = blockWorld(BLOCKER, TOWARD_ME), settings = {floater = {x = 200, y = 100}}})
for _, e in ipairs(fl.errors) do failures[#failures + 1] = "floater scenario: " .. e end
local floatBtn = fl.findButton("BLOCK\nOFF")
check(floatBtn ~= nil and rawget(floatBtn, "Visible") == true, "floater: a visible round BLOCK / OFF button must exist")
local FF = keyNamed(fl, "F")
if floatBtn then
    fl.tap(floatBtn); fl.frames(0.05)
    check(fl.findButton("BLOCK\nREADY") == floatBtn, "floater: tapping it must switch Auto block on (READY)")
    fl.swing(1, 3, false); fl.frames(0.2)
    check(#fEvents(fl, FF) == 1 and fl.findButton("BLOCK\nHOLD") == floatBtn, "floater: it must show HOLD while F is down, and F must really be down")
    fl.frames(1.2)
    check(fl.findButton("BLOCK\nREADY") == floatBtn, "floater: after the block ends it goes back to READY")
    fl.swing(1, 3, false); fl.frames(0.2)
    fl.tap(floatBtn); fl.frames(0.05)
    local fe = fEvents(fl, FF)
    check(fl.findButton("BLOCK\nOFF") == floatBtn and #fe == 4 and not fe[4].down, "floater: tapping it again switches Auto block off AND lets go of F")
    -- dragging: moves it, is saved, never counts as a tap
    local posBefore = fl.ctx.now
    fl.drag(floatBtn, 230, 120, 170, 160)                                      -- 60 left, 40 down
    fl.tap(floatBtn)                                                           -- the click that ends a drag
    check(fl.findButton("BLOCK\nOFF") == floatBtn, "floater: the click that ends a drag must not toggle Auto block")
    local fp = (fl.save() or {}).floater
    check(fp and fp.x == 140 and fp.y == 140, "floater: dragging should move it by the pointer's distance and save it, got " .. tostring(fp and (fp.x .. "," .. fp.y)))
    fl.advance(1)
    fl.drag(floatBtn, 140, 140, 5000, 5000)                                    -- far off screen
    fp = (fl.save() or {}).floater
    check(fp and fp.x == 732 and fp.y == 382, "floater: it must stay on screen (800x450 minus its 64 px + 4 px margin), got " .. tostring(fp and (fp.x .. "," .. fp.y)))
    -- Lock freezes it, taps still work
    local lockBtn = fl.findButton("Lock")
    if lockBtn then fl.tap(lockBtn) end
    fl.advance(1)
    fl.drag(floatBtn, 732, 382, 600, 300)
    fp = (fl.save() or {}).floater
    check(fp and fp.x == 732 and fp.y == 382, "floater: once locked it must not move, got " .. tostring(fp and (fp.x .. "," .. fp.y)))
    fl.advance(1)
    fl.tap(floatBtn); fl.frames(0.05)
    check(fl.findButton("BLOCK\nREADY") == floatBtn, "floater: a locked floater can still be tapped")
end
-- the "Show the block floater" switch hides it; saved settings restore the choice
local showHit = fl.toggleRowHit("Show the block floater")
check(showHit ~= nil, "floater: the 'Show the block floater' switch is missing")
if showHit and floatBtn then
    fl.tap(showHit)
    check(rawget(floatBtn, "Visible") == false, "floater: switching the show-switch off must hide it")
    fl.tap(showHit)
    check(rawget(floatBtn, "Visible") == true, "floater: switching it back on must show it again")
end
local fh = run({executor = "full", body = PNG, settings = {block = {floater = false}}})
local fhBtn = fh.findButton("BLOCK\nOFF")
check(fhBtn ~= nil and rawget(fhBtn, "Visible") == false, "floater: a hidden floater must stay hidden after a restart")

-- 14. ATTACKS THAT HIT THROUGH A HELD BLOCK (grabs, downslam, charged hits ...) are learned and can be skipped / dodged
local ID_C = "rbxassetid://333"
local function pierceRound(r, hitAfter)                           -- they swing, F is already down, and it hurts anyway
    r.swing(1, 3, false, ID_C, 0.5); r.frames(hitAfter); r.hurt(10); r.frames(1.6)
end
local function countDown(r, F) local n = 0 for _, k in ipairs(fEvents(r, F)) do if k.down then n = n + 1 end end return n end
local RIGHT_ENEMY = blockWorld({x = 3, y = 0, z = -5}, {x = -0.5, y = 0, z = 1})
for _, mode in ipairs({"block", "skip", "dash"}) do
    local pz, PZF = blockerWith({settings = {block = {pierceMode = mode}}, world = nil})
    pierceRound(pz, 0.4); pierceRound(pz, 0.4)
    check(countDown(pz, PZF) == 2, "ignore-block (" .. mode .. "): the first two swings are blocked normally, got " .. countDown(pz, PZF) .. " presses")
    pz.frames(1.1)
    check(pz.textOf("1 of them ignore block"), "ignore-block (" .. mode .. "): the label should say 1 attack ignores block; got: " .. tostring(pz.textOf("^Learned:")))
    local before = countDown(pz, PZF)
    pz.swing(1, 3, false, ID_C, 0.5); pz.frames(0.7)
    if mode == "block" then
        check(countDown(pz, PZF) == before + 1, "ignore-block (block anyway): F must still go down for it")
    elseif mode == "skip" then
        check(countDown(pz, PZF) == before, "ignore-block (do nothing): F must NOT go down for an attack that ignores block")
    end
    if mode ~= "dash" then
        check(not pressed(pz, keyNamed(pz, "Q")), "ignore-block (" .. mode .. "): no side dash unless 'Side dash' is chosen")
    end
end
-- side dash mode: Q + the key AWAY from the closest player (he is on my right -> A), around the time the hit lands, no F
local dw = run({executor = "full", body = PNG, world = RIGHT_ENEMY, settings = {block = {pierceMode = "dash"}}})
for _, e in ipairs(dw.errors) do failures[#failures + 1] = "ignore-block dash scenario: " .. e end
local dwHit = dw.toggleRowHit("Auto block"); if dwHit then dw.tap(dwHit) end
local DWF = keyNamed(dw, "F")
pierceRound(dw, 0.4); pierceRound(dw, 0.4)
local keysBefore = #dw.ctx.keys
local dt0 = dw.ctx.now
dw.swing(1, 3, false, ID_C, 0.5); dw.frames(0.7)
local sawA, sawQ, sawD, aTime = false, false, false, nil
for i = keysBefore + 1, #dw.ctx.keys do
    local k = dw.ctx.keys[i]
    if k.down and k.key == keyNamed(dw, "A") then sawA = true; aTime = k.t end
    if k.down and k.key == keyNamed(dw, "Q") then sawQ = true end
    if k.down and k.key == keyNamed(dw, "D") then sawD = true end
end
check(sawQ and sawA and not sawD, "ignore-block (side dash): must dash Q + A (away from the player on my right)")
check(aTime and math.abs((aTime - dt0) - 0.35) < 0.04, "ignore-block (side dash): the dash should come ~0.35 s after the swing (learned 0.40 - lead 0.05), got " .. tostring(aTime and (aTime - dt0)))
check(countDown(dw, DWF) == 2, "ignore-block (side dash): F must not be pressed for it")
check(#dw.myWrites == 0, "ignore-block (side dash): it must never move / teleport me")
local function qPresses(r) local n = 0 for _, k in ipairs(r.ctx.keys) do if k.down and k.key == keyNamed(r, "Q") then n = n + 1 end end return n end
local qBefore = qPresses(dw)
dw.advance(2)                                                              -- the 1 s dodge cooldown is over
dw.swing(1, 3, false, ID_C, 0.5); dw.swing(1, 3, false, ID_C, 0.5); dw.frames(0.7)
check(qPresses(dw) - qBefore == 1, "ignore-block (side dash): two attacks in a row must give ONE dash (cooldown), got " .. (qPresses(dw) - qBefore))

-- a hit that lands before F has been down for ping + 60 ms proves nothing (a late block): never flagged
local pq, PQF = blockerWith({settings = {block = {pierceMode = "skip"}}})
for _ = 1, 4 do pierceRound(pq, 0.10) end
local pqBefore = countDown(pq, PQF)
pq.swing(1, 3, false, ID_C, 0.5); pq.frames(0.5)
check(countDown(pq, PQF) == pqBefore + 1, "ignore-block: hits that landed right after F went down must not flag the attack as unblockable")
-- with a 100 ms ping, F must have been down for ping + 60 ms (not just 60 ms) before a hit counts as "ignores block"
local pp, PPF = blockerWith({ping = 100, settings = {block = {pierceMode = "skip"}}})
for _ = 1, 4 do pierceRound(pp, 0.12) end
local ppBefore = countDown(pp, PPF)
pp.swing(1, 3, false, ID_C, 0.5); pp.frames(0.5)
check(countDown(pp, PPF) == ppBefore + 1, "ignore-block: the ping must be added to the 'F was already down' requirement")
-- and while Auto block is OFF F is not held at all, so nothing is flagged either
local po2 = run({executor = "full", body = PNG, world = blockWorld(BLOCKER, TOWARD_ME), settings = {block = {pierceMode = "skip"}}})
pierceRound(po2, 0.4); pierceRound(po2, 0.4); pierceRound(po2, 0.4)
local po2Hit = po2.toggleRowHit("Auto block"); if po2Hit then po2.tap(po2Hit) end
po2.swing(1, 3, false, ID_C, 0.5); po2.frames(0.5)
check(countDown(po2, keyNamed(po2, "F")) == 1, "ignore-block: with Auto block off nothing is learned as unblockable")

-- 15. CONFIG: nothing is remembered unless "Save config" is pressed
local function jsonWrites(r) local n = 0 for _, w in ipairs(r.writes) do if w.path:find("%.json$") then n = n + 1 end end return n end
local cf = run({executor = "full", body = PNG, settings = {pins = {Garou_Catch = {x = 100, y = 100}}}, world = blockWorld(BLOCKER, TOWARD_ME)})
for _, e in ipairs(cf.errors) do failures[#failures + 1] = "config scenario: " .. e end
check(cf.textOf("A config file was found and loaded"), "config: the status line should say a config file was loaded; got: " .. tostring(cf.textOf("^A config") or cf.textOf("config")))
check(not cf.textOf("changes that are NOT saved"), "config: right after loading there are no unsaved changes")
local cfCatch = cf.findButton("Garou Catch"); if cfCatch then cf.tap(cfCatch) end              -- arm it
cf.swing(1, 3, false, ID_A); cf.frames(0.3); cf.hurt(10)                                     -- learn something
local cfShow = cf.toggleRowHit("Show the block floater"); if cfShow then cf.tap(cfShow) end   -- change a setting
local cfBlock = cf.toggleRowHit("Auto block"); if cfBlock then cf.tap(cfBlock) end
for _ = 1, 60 do for _, hb in ipairs(cf.ctx.heartbeats) do pcall(hb, 1) end end              -- a minute passes
check(cf.textOf("changes that are NOT saved"), "config: after a change the status line must warn about unsaved changes")
check(jsonWrites(cf) == 0 and cf.ctx.encoded == nil, "config: NOTHING may be written automatically (no timer, no save on change)")
pcall(cf.genv.__AnimationHubCleanup)                                                          -- closing the hub
check(jsonWrites(cf) == 0 and cf.ctx.encoded == nil, "config: closing the hub must not write anything")

local cs = run({executor = "full", body = PNG, settings = {}, world = blockWorld(BLOCKER, TOWARD_ME)})
local csShow = cs.toggleRowHit("Show the block floater"); if csShow then cs.tap(csShow) end
check(cs.textOf("changes that are NOT saved"), "config: the unsaved warning must appear before saving")
local csEnc = cs.save()
check(csEnc ~= nil and jsonWrites(cs) == 1, "config: Save config must write exactly one file")
local csPath; for _, w in ipairs(cs.writes) do if w.path:find("%.json$") then csPath = w.path end end
check(csPath == "animation_hub_config.json", "config: the file must be animation_hub_config.json, got " .. tostring(csPath))
check(not cs.textOf("changes that are NOT saved") and cs.textOf("A config file was found"), "config: after saving the warning goes away; got: " .. tostring(cs.textOf("config")))
check(csEnc and csEnc.block and csEnc.block.floater == false, "config: the saved file must contain the changed setting")

local cn = run({executor = "full", body = PNG})
check(cn.textOf("No config file loaded"), "config: with no file the status line says so")
check(cn.ctx.encoded == nil and jsonWrites(cn) == 0, "config: a first run must not write a file")

-- delete: removes the file (or empties it when the executor has no delfile)
local cd = run({executor = "full", body = PNG, settings = {}})
local cdBtn = cd.findButton("Delete saved config"); if cdBtn then cd.tap(cdBtn) end
check(cd.ctx.deleted[1] == "animation_hub_config.json", "config: Delete must remove animation_hub_config.json")
check(cd.textOf("No config file loaded"), "config: after Delete the status line says there is no config")
local cd2 = run({executor = "full", body = PNG, settings = {}, noDelfile = true})
local cd2Btn = cd2.findButton("Delete saved config"); if cd2Btn then cd2.tap(cd2Btn) end
local emptied = false
for _, w in ipairs(cd2.writes) do if w.path == "animation_hub_config.json" and w.body == "" then emptied = true end end
check(emptied and #cd2.ctx.deleted == 0, "config: without delfile, Delete must empty the file instead")

-- reload: rebuilds the menu from the file; with no file it does nothing
local cr = run({executor = "full", body = PNG, allowRebuild = true, settings = {pins = {Garou_Catch = {x = 100, y = 100}}}})
for _, e in ipairs(cr.errors) do failures[#failures + 1] = "reload scenario: " .. e end
local crBefore = cr.genv.__AnimationHubCleanup
local crBtn = cr.findButton("Reload saved config (rebuilds the menu)"); if crBtn then cr.tap(crBtn) end
check(cr.genv.__AnimationHubCleanup ~= nil and cr.genv.__AnimationHubCleanup ~= crBefore, "config: Reload must rebuild the menu")
check(cr.textOf("A config file was found"), "config: after Reload the data counts as loaded from the file")
local cm = run({executor = "full", body = PNG, allowRebuild = true})
local cmBefore = cm.genv.__AnimationHubCleanup
local cmBtn = cm.findButton("Reload saved config (rebuilds the menu)"); if cmBtn then cm.tap(cmBtn) end
check(cm.genv.__AnimationHubCleanup == cmBefore, "config: Reload with no saved config must do nothing")

-- Apply theme keeps what you have set in this session (pins, learned timings) but writes nothing
local ct = run({executor = "full", body = PNG, allowRebuild = true, settings = {pins = {Garou_Catch = {x = 100, y = 100}}, learned = {[ID_A] = {n = 5, offset = 0.3, spread = 0.01}}}})
local ctBtn = ct.findButton("Apply theme (rebuilds the menu)"); if ctBtn then ct.tap(ctBtn) end
check(jsonWrites(ct) == 0, "config: Apply theme must not write the config file")
local ctEnc = ct.save()
check(ctEnc and ctEnc.pins and ctEnc.pins.Garou_Catch and ctEnc.learned and ctEnc.learned[ID_A], "config: Apply theme must keep the pins and learned timings of this session")


-- 16. ADJUSTMENTS ONLY WHERE THEY ARE NEEDED: a combo's Opt drawer shows just the controls that change what it does
local function optionTexts(r, title)                           -- tap the Opt button of the card called `title`; texts of what appeared
    local card
    for _, inst in ipairs(r.instances) do
        if rawget(inst, "__name") == "TextLabel" and rawget(inst, "Text") == title then
            for _, kid in ipairs(rawget(rawget(inst, "Parent") or {}, "__children") or {}) do
                if rawget(kid, "__name") == "TextButton" and rawget(kid, "Text") == "Opt" then card = kid end
            end
        end
    end
    if not card then return nil end
    local before = #r.instances
    r.tap(card)
    local texts = {}
    for i = before + 1, #r.instances do
        local t = rawget(r.instances[i], "Text")
        if type(t) == "string" and t ~= "" then texts[t] = true end
    end
    return texts
end
local function has(texts, prefix) for t in pairs(texts) do if t:sub(1, #prefix) == prefix then return true end end return false end
local ad = run({executor = "full", body = PNG, settings = {combos = {WallTech = {trigAnim = "rbxassetid://5"}}}})
for _, e in ipairs(ad.errors) do failures[#failures + 1] = "adjustment scenario: " .. e end
local twisted = optionTexts(ad, "Garou InstantTwisted")             -- M1 x4, BACKDASH, FRONTDASH
check(twisted ~= nil, "adjustments: the Garou InstantTwisted card / Opt button is missing")
if twisted then
    check(has(twisted, "M1 gap") and has(twisted, "Dash gap"), "adjustments: a combo with M1s and dashes needs the M1 and Dash gaps")
    check(has(twisted, "Auto timing") and has(twisted, "Fine-tune"), "adjustments: dashes wait for a cue, so Auto timing / fine-tune belong here")
    check(has(twisted, "Speed") and has(twisted, "Trigger step") and has(twisted, "Pinned button does"), "adjustments: speed / trigger / pin mode belong to a 6-step combo")
    check(not has(twisted, "Jump gap") and not has(twisted, "Move gap") and not has(twisted, "Side dash goes"), "adjustments: no jump, move or side dash in it -> no such controls")
end
local tatsu = optionTexts(ad, "Tatsu Safe")                         -- two moves only
check(tatsu ~= nil, "adjustments: the Tatsu Safe card / Opt button is missing")
if tatsu then
    check(not (has(tatsu, "M1 gap") or has(tatsu, "Dash gap") or has(tatsu, "Jump gap") or has(tatsu, "Side dash goes")),
        "adjustments: a two-move combo has no M1 / dash / jump / side dash controls")
    check(not has(tatsu, "Trigger step"), "adjustments: with 2 steps there is nothing to choose for the trigger")
    check(has(tatsu, "Pinned button does") and has(tatsu, "Reset this combo") and has(tatsu, "Learn trigger"), "adjustments: pin mode / learn trigger / reset always stay")
end
local jumpy = optionTexts(ad, "Saitama UppercutShoveReset")         -- ... JUMP ... FRONTDASH (a dash only as the last step)
check(jumpy ~= nil and has(jumpy, "Jump gap"), "adjustments: a combo that jumps in the middle needs the jump gap")
check(jumpy ~= nil and not has(jumpy, "Dash gap"), "adjustments: a dash only as the LAST step has no wait after it -> no dash gap")
local wall = optionTexts(ad, "WallTech")
check(wall ~= nil and has(wall, "M1 gap") and has(wall, "Dash gap") and not has(wall, "Jump gap"), "adjustments: WallTech = M1s + a dash")
local function forgetVisible(r, findIndex)
    local n = 0
    for _, inst in ipairs(r.instances) do
        if rawget(inst, "__name") == "TextButton" and rawget(inst, "Text") == "Forget learned trigger" then
            n = n + 1
            if n == findIndex then return rawget(rawget(inst, "Parent"), "Visible") end
        end
    end
end
-- drawers were opened in this order: Garou InstantTwisted, Tatsu Safe, Saitama UppercutShoveReset, WallTech (the only one with a learned trigger)
check(forgetVisible(ad, 4) == true, "adjustments: 'Forget learned trigger' must be visible when a trigger was learned (WallTech)")
check(forgetVisible(ad, 1) == false and forgetVisible(ad, 2) == false and forgetVisible(ad, 3) == false,
    "adjustments: 'Forget learned trigger' must be hidden when nothing was learned")
local genosBlitz = optionTexts(ad, "Genos UppercutBlitz")        -- M1 x3, an unmapped move, then ONE move as the last step
check(genosBlitz ~= nil and has(genosBlitz, "M1 gap") and not has(genosBlitz, "Auto timing") and not has(genosBlitz, "Fine-tune"),
    "adjustments: when no gap waits for a visible cue there is no Auto timing / fine-tune")
end

do   -- anything that went wrong at any time in any scenario (taps, frames, drags, ...) fails the run
    local seen = {}
    for _, list in ipairs(ALL_ERRORS) do
        for _, e in ipairs(list) do
            if not seen[e] then seen[e] = true; failures[#failures + 1] = "(late) " .. e end
        end
    end
end

if #failures > 0 then
    print("PROBLEMS:"); for _, x in ipairs(failures) do print("  " .. x) end
    finish(1)
    return
end
print("smoke test passed (28 scenarios)")
