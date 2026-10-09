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
            if type(k) == "number" then return nil end                    -- a fake "list" ends: ipairs() over it must terminate
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
local function fakeChar(pos, look, animFns, writes, healthFns, vel)
    -- a proxy: every WRITE to the character's root part (even re-assigning an existing field) is recorded
    local data = {Position = {X = pos.x, Y = pos.y, Z = pos.z}, CFrame = {LookVector = {X = look.x, Y = look.y, Z = look.z}}}
    if vel then data.AssemblyLinearVelocity = {X = vel.x, Y = vel.y, Z = vel.z} end
    local hrp = setmetatable({}, {__index = data, __newindex = function(_, k, v) writes[#writes + 1] = k; data[k] = v end})
    local playing = {}
    local animator = {AnimationPlayed = {Connect = function(_, fn) animFns[#animFns + 1] = fn; return {Disconnect = function() end} end},
                      playing = playing,
                      GetPlayingAnimationTracks = function() local copy = {} for i, t in ipairs(playing) do copy[i] = t end return copy end}
    local hum = {Health = 100, WalkSpeed = 16, GetState = function() return "Running" end,
                 HealthChanged = {Connect = function(_, fn) healthFns[#healthFns + 1] = fn; return {Disconnect = function() end} end},
                 FindFirstChildOfClass = function() return animator end, WaitForChild = function() return animator end}
    local char = {
        FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return hrp end end,
        FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return hum end end,
        WaitForChild = function(_, n) if n == "Humanoid" then return hum end return hrp end,
        GetAttribute = function() return nil end,
        GetAttributes = function() return {} end,
    }
    return char, hrp, hum, animator
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
    env.workspace.CurrentCamera = {ViewportSize = {X = 800, Y = 450}, CFrame = {RightVector = {X = 1, Y = 0, Z = 0}, LookVector = {X = 0, Y = 0, Z = -1}}}
    ctx.blockSim = scenario.blockSim
    local world = scenario.world            -- optional: {me = {pos, look}, enemies = {{name, pos, look}...}, right = {x,y,z}}
    local myAnim, myWrites, enemyAnim, enemies, myHealth, enemyAnimators = {}, {}, {}, {}, {}, {}
    local myChar, myHrp, myHum
    if world then
        myChar, myHrp, myHum = fakeChar(world.me.pos, world.me.look, myAnim, myWrites, myHealth, world.me.vel)
        if world.right or world.camLook then
            local r, l = world.right or {x = 1, y = 0, z = 0}, world.camLook or {x = 0, y = 0, z = -1}
            env.workspace.CurrentCamera.CFrame = {RightVector = {X = r.x, Y = r.y, Z = r.z}, LookVector = {X = l.x, Y = l.y, Z = l.z}}
        end
        for i, e in ipairs(world.enemies or {}) do
            enemyAnim[i] = {}
            local c, _, _, animator = fakeChar(e.pos, e.look, enemyAnim[i], {}, {}, e.vel)
            enemyAnimators[i] = animator
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
            s.SendKeyEvent = function(_, down, key)
                ctx.seq = (ctx.seq or 0) + 1
                ctx.keys[#ctx.keys + 1] = {down = down, key = key, t = ctx.now, n = ctx.seq}
                local sim = ctx.blockSim                              -- the fake game: F makes you slow (= blocking) unless it is ignored
                if sim and myHum and key == env.Enum.KeyCode.F then
                    if down then
                        if not sim.never and ctx.now >= (sim.lockoutUntil or 0) then myHum.WalkSpeed = 6; sim.up = true; sim.ups = (sim.ups or 0) + 1
                        else sim.dropped = (sim.dropped or 0) + 1 end
                    else myHum.WalkSpeed = 16; sim.up = false end
                end
            end
            s.SendMouseButtonEvent = function(_, _, _, _, down) ctx.seq = (ctx.seq or 0) + 1; ctx.mouse[#ctx.mouse + 1] = {down = down, t = ctx.now, n = ctx.seq} end
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
        rawset(inst, "FocusLost", {Connect = function(_, fn) rawset(inst, "__focusLost", fn); return {Disconnect = function() end} end})
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
    env.Color3 = {fromRGB = function(r, g, b)                                -- keeps its numbers, so palette tests can read them
        local c = dummy("Color3.fromRGB()", ctx)
        rawset(c, "R", r); rawset(c, "G", g); rawset(c, "B", b)
        return c
    end}
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
    if scenario.settings or scenario.settingsThrows or scenario.files then
        env.isfile = function(path)
            if scenario.files and scenario.files[path] ~= nil then return true end
            return path == "animation_hub_config.json" and (scenario.settings ~= nil or scenario.settingsThrows == true)
        end
        env.readfile = function(path)
            ctx.readPaths[#ctx.readPaths + 1] = path
            if scenario.files and scenario.files[path] ~= nil then return scenario.files[path] end
            return "SETTINGS_RAW"
        end
    end
    if not scenario.noDelfile then env.delfile = function(path) ctx.deleted[#ctx.deleted + 1] = path end end
    if scenario.executor == "full" then
        ctx.requests = {}
        env.request = function(req)
            ctx.requests[#ctx.requests + 1] = req.Url
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
    local function typeInto(placeholderStart, text)                        -- type into the TextBox whose placeholder starts with this, then leave it
        for _, inst in ipairs(instances) do
            if rawget(inst, "__name") == "TextBox" then
                local ph = rawget(inst, "PlaceholderText")
                if type(ph) == "string" and ph:sub(1, #placeholderStart) == placeholderStart then
                    rawset(inst, "Text", text)
                    local fn = rawget(inst, "__focusLost")
                    if fn then local ok, e = pcall(fn, true); if not ok then errors[#errors + 1] = "FocusLost: " .. tostring(e) end end
                    return true
                end
            end
        end
        errors[#errors + 1] = "no TextBox with placeholder " .. placeholderStart
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
    local function newTrack(priority, looped, id, length, name, timePos)
        return {Animation = {AnimationId = id or "rbxassetid://777", Name = name}, Name = name, Looped = looped or false,
                Priority = {Value = priority or 3}, Length = length, TimePosition = timePos or 0}
    end
    local function swing(i, priority, looped, id, length, name)            -- enemy i starts an attack animation (the event fires)
        local track = newTrack(priority, looped, id, length, name)
        local animator = enemyAnimators[i]
        if animator then animator.playing[#animator.playing + 1] = track end
        for _, fn in ipairs(enemyAnim[i] or {}) do
            local ok, e = pcall(fn, track)
            if not ok then errors[#errors + 1] = "enemy AnimationPlayed handler: " .. tostring(e) end
        end
    end
    local function silentSwing(i, priority, looped, id, length, name, timePos)   -- the track is playing but the event never fires
        local animator = enemyAnimators[i]
        if animator then animator.playing[#animator.playing + 1] = newTrack(priority, looped, id, length, name, timePos) end
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
    return {typeInto = typeInto, silentSwing = silentSwing, instances = instances, save = save, findLastButton = findLastButton, hurt = hurt, drag = drag, frames = frames, fireInput = fireInput, swing = swing, myWrites = myWrites, advance = advance, tap = tap, toggleRowHit = toggleRowHit, fireKey = fireKey, playAnimation = playAnimation,
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

-- 8. SIDE DASHES: only ever Q + a direction key, never a move of my character
local ME, LOOK = {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = -1}
local function keyNamed(r, name) return r.env.Enum.KeyCode[name] end
do   -- (own scope: the main chunk may only hold 200 locals)
local function pins(...) local t = {} for _, n in ipairs({...}) do t[n] = {x = 90, y = 90} end return {pins = t} end
local function keysDown(r) local out = {} for _, k in ipairs(r.ctx.keys) do if k.down then out[#out + 1] = k.key end end return out end
local function countKey(r, name) local n = 0 for _, k in ipairs(r.ctx.keys) do if k.down and k.key == keyNamed(r, name) then n = n + 1 end end return n end

-- "Toward": at the closest player (the old behaviour, still available)
local rightSide = run({executor = "full", body = PNG, settings = pins("SideDash_Toward"), world = {
    me = {pos = ME, look = LOOK}, right = {x = 1, y = 0, z = 0},
    enemies = {{name = "Far", pos = {x = -80, y = 0, z = 0}, look = LOOK}, {name = "Near", pos = {x = 12, y = 0, z = -4}, look = LOOK}}}})
for _, e in ipairs(rightSide.errors) do failures[#failures + 1] = "toward side dash (right): " .. e end
local closeBtn = rightSide.findButton("Toward")
check(closeBtn ~= nil, "toward side dash: the round button is missing")
if closeBtn then rightSide.tap(closeBtn) end
check(pressed(rightSide, keyNamed(rightSide, "D")) and pressed(rightSide, keyNamed(rightSide, "Q")), "toward side dash: nearest player is on my right -> Q + D")
check(not pressed(rightSide, keyNamed(rightSide, "A")), "toward side dash: must not press A when the nearest player is on the right")
check(#rightSide.myWrites == 0, "toward side dash: it must NOT move / teleport me - my character was written to: " .. table.concat(rightSide.myWrites, ","))

local leftSide = run({executor = "full", body = PNG, settings = pins("SideDash_Toward"), world = {
    me = {pos = ME, look = LOOK}, right = {x = 1, y = 0, z = 0},
    enemies = {{name = "Near", pos = {x = -9, y = 0, z = -2}, look = LOOK}, {name = "Far", pos = {x = 70, y = 0, z = 0}, look = LOOK}}}})
local lb = leftSide.findButton("Toward")
if lb then leftSide.tap(lb) end
check(pressed(leftSide, keyNamed(leftSide, "A")) and not pressed(leftSide, keyNamed(leftSide, "D")), "toward side dash: nearest player on my left -> Q + A")

local nobody = run({executor = "full", body = PNG, settings = pins("SideDash_Toward"), world = {
    me = {pos = ME, look = LOOK}, enemies = {}}})
local nb = nobody.findButton("Toward")
if nb then nobody.tap(nb) end
check(pressed(nobody, keyNamed(nobody, "A")), "toward side dash: with nobody around it falls back to Left (A) instead of failing")

-- "Behind": round the closest player toward his BACK, so the next hit cannot be blocked
local function behindWorld(enemyPos, enemyLook, extra)
    local w = {me = {pos = ME, look = LOOK}, enemies = {{name = "Target", pos = enemyPos, look = enemyLook}}}
    for k, v in pairs(extra or {}) do w[k] = v end
    return w
end
local FRONT_POS = {x = 0, y = 0, z = -6}                                      -- he stands 6 studs ahead of me, camera looks at him
local function behindRun(enemyPos, enemyLook, settings, world)
    local st = settings or pins("SideDash_Behind")
    local r = run({executor = "full", body = PNG, settings = st, world = world or behindWorld(enemyPos, enemyLook)})
    for _, e in ipairs(r.errors) do failures[#failures + 1] = "behind side dash: " .. e end
    local btn = r.findButton("Behind")
    if btn then r.tap(btn) else failures[#failures + 1] = "behind side dash: the round 'Behind' button is missing" end
    return r
end
local b1 = behindRun(FRONT_POS, {x = 0, y = 0, z = 1})                        -- facing me head on
check(pressed(b1, keyNamed(b1, "Q")) and pressed(b1, keyNamed(b1, "D")) and not pressed(b1, keyNamed(b1, "A")), "behind: head on, the camera's right is +x -> Q + D (round him, not into him)")
check(not pressed(b1, keyNamed(b1, "W")) and #b1.myWrites == 0, "behind: it must not dash at him and must not move / teleport me")
local b2 = behindRun(FRONT_POS, {x = 0.447, y = 0, z = 0.894})                -- he is already turning to his left-of-me side
check(pressed(b2, keyNamed(b2, "A")) and not pressed(b2, keyNamed(b2, "D")), "behind: he looks a little toward +x, so the quicker way round is the other side -> A")
local b3 = behindRun(FRONT_POS, {x = -0.447, y = 0, z = 0.894})
check(pressed(b3, keyNamed(b3, "D")) and not pressed(b3, keyNamed(b3, "A")), "behind: mirrored -> D")
local b4 = behindRun(FRONT_POS, {x = 0, y = 0, z = -1})                       -- I am already standing behind him
check(#keysDown(b4) == 0, "behind: already behind him -> no dash at all (it would take me away from his back)")
local b5 = behindRun(nil, nil, pins("SideDash_Behind"), {me = {pos = ME, look = LOOK}, enemies = {}})
check(#keysDown(b5) == 0, "behind: nobody around -> nothing happens")
local b6 = behindRun(FRONT_POS, {x = 0, y = 0, z = 1}, {behind = {count = 3, gap = 0.2}, pins = {SideDash_Behind = {x = 90, y = 90}}})
check(countKey(b6, "Q") == 3, "behind: 'most dashes' = 3 -> three dashes while I am not behind him yet, got " .. countKey(b6, "Q"))
local b7 = behindRun(FRONT_POS, {x = 0, y = 0, z = 1}, {behind = {count = 1, gap = 0.2}, pins = {SideDash_Behind = {x = 90, y = 90}}})
check(countKey(b7, "Q") == 1, "behind: 'most dashes' = 1 -> one dash")
local b8 = behindRun(FRONT_POS, {x = 0, y = 0, z = 1}, {behind = {count = 2, gap = 0.2, m1 = true}, pins = {SideDash_Behind = {x = 90, y = 90}}})
check(#b8.ctx.mouse == 0, "behind + M1: if the dashes did not get me behind him I must NOT hit him from the front")
local b9 = behindRun(FRONT_POS, {x = 0, y = 0, z = -1}, {behind = {m1 = true}, pins = {SideDash_Behind = {x = 90, y = 90}}})
check(#keysDown(b9) == 0 and #b9.ctx.mouse >= 2, "behind + M1: already behind him -> no dash, just the M1")
local b10 = behindRun(FRONT_POS, {x = 0, y = 0, z = 1}, {behind = {count = 99, gap = 99, m1 = "yes"}, pins = {SideDash_Behind = {x = 90, y = 90}}})
check(countKey(b10, "Q") == 3 and #b10.ctx.mouse == 0, "behind: garbage settings are clamped (max 3 dashes, m1 must be true)")
local b12 = behindRun(FRONT_POS, {x = 0, y = 0, z = -1}, {behind = {m1 = "yes"}, pins = {SideDash_Behind = {x = 90, y = 90}}})
check(#keysDown(b12) == 0 and #b12.ctx.mouse == 0, "behind: M1 is only on when the saved value is exactly true, not any truthy garbage")
-- ALWAYS a side dash: Q + A or Q + D, never W / S (those are the front / back dashes), whatever the camera does
local poses = {
    {{x = 0, y = 0, z = -6}, {x = 0, y = 0, z = 1}}, {{x = 7, y = 0, z = -2}, {x = -1, y = 0, z = 0}}, {{x = -7, y = 0, z = 1}, {x = 1, y = 0, z = 0}},
    {{x = 4, y = 0, z = 5}, {x = 0, y = 0, z = -1}}, {{x = 0, y = 0, z = -14}, {x = 0.3, y = 0, z = 1}}, {{x = -9, y = 0, z = -9}, {x = 1, y = 0, z = 1}},
}
local cameras = {{right = {x = 1, y = 0, z = 0}, camLook = {x = 0, y = 0, z = -1}}, {right = {x = 0, y = 0, z = 1}, camLook = {x = 1, y = 0, z = 0}},
                 {right = {x = -1, y = 0, z = 0}, camLook = {x = 0, y = 0, z = 1}}, {right = {x = 0.7, y = 0, z = 0.7}, camLook = {x = 0.7, y = 0, z = -0.7}}}
local wrong, dashed = 0, 0
for _, cam in ipairs(cameras) do
    for _, pose in ipairs(poses) do
        local r = behindRun(nil, nil, nil, behindWorld(pose[1], pose[2], cam))
        local sideKeys = countKey(r, "A") + countKey(r, "D")
        if sideKeys + countKey(r, "W") + countKey(r, "S") > 0 then dashed = dashed + 1 end
        if countKey(r, "W") + countKey(r, "S") > 0 or sideKeys > 1 or (sideKeys == 1 and countKey(r, "Q") ~= 1) then wrong = wrong + 1 end
    end
end
check(dashed > 15 and wrong == 0, "behind: in " .. dashed .. " dashing situations it must be one side dash (Q + A/D) every time, never W / S; wrong in " .. wrong)
-- a side dash has a ~2 s cooldown: a second dash waits for it
local b13 = behindRun(FRONT_POS, {x = 0, y = 0, z = 1}, {behind = {count = 2}, pins = {SideDash_Behind = {x = 90, y = 90}}})
local qTimes = {}
for _, k in ipairs(b13.ctx.keys) do if k.down and k.key == keyNamed(b13, "Q") then qTimes[#qTimes + 1] = k.t end end
check(#qTimes == 2 and qTimes[2] - qTimes[1] >= 2.05, "behind: the second dash waits out the 2 s side dash cooldown, gap was " .. tostring(#qTimes == 2 and (qTimes[2] - qTimes[1])))
local b14 = behindRun(FRONT_POS, {x = 0, y = 0, z = 1}, {behind = {count = 1, gap = 0.01, settle = 99}, pins = {SideDash_Behind = {x = 90, y = 90}}})
check(countKey(b14, "Q") == 1, "behind: the cooldown / settle settings are clamped too")
local b15 = run({executor = "full", body = PNG, settings = {behind = {m1 = true, settle = 99}, pins = {SideDash_Behind = {x = 90, y = 90}}},
    world = behindWorld(FRONT_POS, {x = 0, y = 0, z = -1})})
local b15t0 = b15.ctx.now
local b15btn = b15.findButton("Behind"); if b15btn then b15.tap(b15btn) end
check(#b15.ctx.mouse >= 2 and b15.ctx.mouse[1].t - b15t0 <= 1.05, "behind: the wait before the M1 is clamped to 1 s, was " .. tostring(b15.ctx.mouse[1] and (b15.ctx.mouse[1].t - b15t0)))
local b16 = run({executor = "full", body = PNG, settings = {behind = {m1 = true}, pins = {SideDash_Behind = {x = 90, y = 90}}},
    world = behindWorld(FRONT_POS, {x = 0, y = 0, z = -1})})
local b16t0 = b16.ctx.now
local b16btn = b16.findButton("Behind"); if b16btn then b16.tap(b16btn) end
check(#b16.ctx.mouse >= 2 and math.abs((b16.ctx.mouse[1].t - b16t0) - 0.3) < 0.05, "behind: the default wait for the dash to finish is 0.3 s, was " .. tostring(b16.ctx.mouse[1] and (b16.ctx.mouse[1].t - b16t0)))

-- every SIDEDASH inside a tech / combo goes behind the closest player by default, "Toward" / Left / Right still work
local function techDashRun(enemyPos, enemyLook, comboSide)
    local settings = {pins = {Garou_Catch = {x = 100, y = 100}}}
    if comboSide then settings.combos = {Garou_Catch = {side = comboSide}} end
    local r = run({executor = "full", body = PNG, settings = settings, world = behindWorld(enemyPos, enemyLook, {right = {x = 1, y = 0, z = 0}})})
    for _, e in ipairs(r.errors) do failures[#failures + 1] = "assist side dash: " .. e end
    local btn = r.findButton("Garou Catch"); if btn then r.tap(btn) end
    r.fireKey(r.env.Enum.KeyCode.Three)
    return r
end
local td1 = techDashRun(FRONT_POS, {x = 0.447, y = 0, z = 0.894})
check(pressed(td1, keyNamed(td1, "A")) and not pressed(td1, keyNamed(td1, "D")), "assist combos: their SIDEDASH steps go round the closest player toward his back by default")
check(#td1.myWrites == 0, "assist combos: side dash must not move me")
local td5 = techDashRun({x = 10, y = 0, z = 0}, LOOK)                       -- he stands to my right and looks along -z (my own look direction)
check(pressed(td5, keyNamed(td5, "D")) and not pressed(td5, keyNamed(td5, "S")) and not pressed(td5, keyNamed(td5, "W")),
    "assist combos: default = a SIDE dash round him toward his back: he is on my right, the side dash that gets me closest is D (never W / S)")
local td6 = techDashRun({x = -10, y = 0, z = 0}, LOOK)
check(pressed(td6, keyNamed(td6, "A")) and not pressed(td6, keyNamed(td6, "S")), "assist combos: mirrored -> A")
local td2 = techDashRun({x = 10, y = 0, z = 0}, LOOK, "Toward")
check(pressed(td2, keyNamed(td2, "D")), "assist combos: side = Toward still dashes at the closest player")
local td3 = techDashRun(FRONT_POS, {x = 0, y = 0, z = 1}, "Left")
check(pressed(td3, keyNamed(td3, "A")), "assist combos: side = Left")
local td4 = techDashRun(FRONT_POS, {x = 0, y = 0, z = 1}, "Closest")
check(#td4.errors == 0, "assist combos: the old name 'Closest' in a saved config must not break anything")

-- automatic side dash after my moves goes behind too (old saved name 'Closest' = Toward)
local function autoDashRun(dir, enemyPos, enemyLook)
    local r = run({executor = "full", body = PNG, settings = {sideAuto = {dir = dir}}, world = behindWorld(enemyPos, enemyLook, {right = {x = 1, y = 0, z = 0}})})
    local hit = r.toggleRowHit("Auto side dash after my moves"); if hit then r.tap(hit) end
    r.fireKey(r.env.Enum.KeyCode.One)
    return r
end
local ad1 = autoDashRun(nil, FRONT_POS, {x = 0.447, y = 0, z = 0.894})
check(pressed(ad1, keyNamed(ad1, "Q")) and pressed(ad1, keyNamed(ad1, "A")), "auto side dash: default goes round the closest player (here A)")
local ad2 = autoDashRun("Closest", {x = 10, y = 0, z = 0}, LOOK)
check(pressed(ad2, keyNamed(ad2, "D")), "auto side dash: a saved 'Closest' means Toward the closest player (here D)")

end

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
local OLD = {style = "Balanced", delay = 0.10}                               -- the timings most checks below were written for
local function withOld(block)                                                -- {pierceMode = ...} + the old timings
    local b = {}
    for k, v in pairs(OLD) do b[k] = v end
    for k, v in pairs(block or {}) do b[k] = v end
    return b
end
local function newBlocker(world, extra)
    local r = run({executor = "full", body = PNG, ping = extra and extra.ping, world = world or blockWorld(BLOCKER, TOWARD_ME),
        settings = {block = withOld(extra and extra.block)}})
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
pu.swing(1, 3, false); pu.frames(0.1)
check(#fEvents(pu, F4) == 2, "auto block (punch): right after my punch F cannot come up (the game's ~0.2 s lockout)")
pu.frames(0.15)
check(#fEvents(pu, F4) == 3 and fEvents(pu, F4)[3].down, "auto block (punch): the moment the lockout is over F goes down for the attack that is still coming")
pu.frames(1.0)
check(#fEvents(pu, F4) == 4 and not fEvents(pu, F4)[4].down, "auto block (punch): and it is let go after that attack")
pu.swing(1, 3, false); pu.frames(0.2)
check(#fEvents(pu, F4) == 5, "auto block (punch): later attacks are blocked as usual")
local puLate = newBlocker()
puLate.swing(1, 3, false); puLate.frames(0.2)
puLate.fireInput(puLate.env.Enum.UserInputType.MouseButton1)
puLate.frames(1.0)
puLate.fireInput(puLate.env.Enum.UserInputType.MouseButton1)                -- punch again with nothing coming
puLate.frames(0.5)
local pl = fEvents(puLate, keyNamed(puLate, "F"))
check(#pl == 2, "auto block (punch): a punch with no attack coming must not make F go down, events " .. #pl)
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
local rb = run({executor = "full", body = PNG, allowRebuild = true, settings = {ui = {theme = "Ocean", scale = 1.1, glass = 0.6, bright = 1.15}}})
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
check(rbEnc and rbEnc.ui and rbEnc.ui.bright == 1.15, "rebuild: the Brightness setting must survive the rebuild")
local brHigh = run({executor = "full", body = PNG, settings = {ui = {bright = 99}}})
local brLow = run({executor = "full", body = PNG, settings = {ui = {bright = "x"}}})
local brDefault = run({executor = "full", body = PNG})
local bhE, blE, bdE = brHigh.save(), brLow.save(), brDefault.save()
check(bhE and bhE.ui.bright == 1.2, "brightness: a silly saved value is clamped to the slider's maximum (1.2)")
check(blE and blE.ui.bright == 1, "brightness: garbage falls back to 1")
check(bdE and bdE.ui.bright == 1 and bdE.ui.glass == 0.82, "brightness / glass defaults: 1 and 0.82 (a clear, bright window)")
local function windowColor(r)                                                  -- the window's own background colour
    for _, inst in ipairs(r.instances) do
        if rawget(inst, "__name") == "CanvasGroup" then
            local c = rawget(inst, "BackgroundColor3")
            return c and {rawget(c, "R"), rawget(c, "G"), rawget(c, "B")}
        end
    end
end
local function sameColor(c, r, g, b) return c ~= nil and c[1] == r and c[2] == g and c[3] == b end
local wc = windowColor(brDefault)
check(sameColor(wc, 121, 51, 107), "palette: the default Rose Gold window colour is (121, 51, 107), got " .. tostring(wc and table.concat(wc, ",")))
local wOcean = run({executor = "full", body = PNG, settings = {ui = {theme = "Ocean", bright = 1.2}}})
wc = windowColor(wOcean)
check(sameColor(wc, 38, 96, 152), "palette: Ocean at brightness 1.2 -> (38, 96, 152), got " .. tostring(wc and table.concat(wc, ",")))
local wDim = run({executor = "full", body = PNG, settings = {ui = {bright = 0.8}}})
wc = windowColor(wDim)
check(sameColor(wc, 97, 41, 86), "palette: Rose Gold at brightness 0.8 -> (97, 41, 86), got " .. tostring(wc and table.concat(wc, ",")))

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
local LEARNED = {learned = {[ID_A] = {n = 5, offset = 0.30, spread = 0.01, length = 0.4}}, block = withOld()}
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
local CHAIN = {learned = {[ID_A] = {n = 5, offset = 0.20, spread = 0.01, length = 0.4}, [ID_B] = {n = 5, offset = 0.20, spread = 0.01, length = 0.4}}, block = withOld()}
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
    local pz, PZF = blockerWith({settings = {block = withOld({pierceMode = mode})}})
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
local dw = run({executor = "full", body = PNG, world = RIGHT_ENEMY, settings = {block = withOld({pierceMode = "dash"})}})
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
local pq, PQF = blockerWith({settings = {block = withOld({pierceMode = "skip"})}})
for _ = 1, 4 do pierceRound(pq, 0.10) end
local pqBefore = countDown(pq, PQF)
pq.swing(1, 3, false, ID_C, 0.5); pq.frames(0.5)
check(countDown(pq, PQF) == pqBefore + 1, "ignore-block: hits that landed right after F went down must not flag the attack as unblockable")
-- with a 100 ms ping, F must have been down for ping + 60 ms (not just 60 ms) before a hit counts as "ignores block"
local pp, PPF = blockerWith({ping = 100, settings = {block = withOld({pierceMode = "skip"})}})
for _ = 1, 4 do pierceRound(pp, 0.12) end
local ppBefore = countDown(pp, PPF)
pp.swing(1, 3, false, ID_C, 0.5); pp.frames(0.5)
check(countDown(pp, PPF) == ppBefore + 1, "ignore-block: the ping must be added to the 'F was already down' requirement")
-- and while Auto block is OFF F is not held at all, so nothing is flagged either
local po2 = run({executor = "full", body = PNG, world = blockWorld(BLOCKER, TOWARD_ME), settings = {block = withOld({pierceMode = "skip"})}})
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

-- 17. RELIABILITY: the things that used to make Auto block hit-and-miss (all with the NEW defaults: no OLD timings pinned)
do
    local function defaultBlocker(enemy, settings, ping)
        local world = {me = {pos = ME, look = LOOK}, enemies = {enemy or {name = "Enemy", pos = BLOCKER, look = TOWARD_ME}}}
        local r = run({executor = "full", body = PNG, ping = ping, world = world, settings = settings})
        for _, e in ipairs(r.errors) do failures[#failures + 1] = "reliability scenario: " .. e end
        if ping then r.frames(2) end
        local hit = r.toggleRowHit("Auto block"); if hit then r.tap(hit) end
        return r, keyNamed(r, "F")
    end
    local function firstDown(r, F, t0) local ev = fEvents(r, F)[1] return ev and ev.down and (ev.t - t0) or nil end
    local XID = "rbxassetid://444"

    do -- new defaults: early and generous
    local d1, DF = defaultBlocker()
    local d1t = d1.ctx.now
    d1.swing(1, 3, false, XID, 0.5); d1.frames(0.05)
    local d1p = firstDown(d1, DF, d1t)
    check(d1p and d1p <= 0.04, "defaults: F goes down AT ONCE when an attack is seen (no delay - the animation already arrives a round trip late), got " .. tostring(d1p))
    d1.frames(0.7)
    check(d1.textOf("%-> block"), "diagnostics: the readout must say the attack was answered; got: " .. tostring(d1.textOf("^Last:")))

    end
    do -- style presets (learned 0.30 s hit, no ping): Safe 0.12 -> 0.18 s, Balanced 0.05 -> 0.25 s, Perfect 0.02 -> 0.28 s
    local function pressAfterStyle(style)
        local settings = {learned = {[XID] = {n = 5, offset = 0.30, spread = 0.01, length = 0.4}}}
        if style then settings.block = {style = style} end
        local r, F = defaultBlocker(nil, settings)
        local t0 = r.ctx.now
        r.swing(1, 3, false, XID, 0.4); r.frames(0.6)
        return firstDown(r, F, t0)
    end
    local safe, balanced, perfect, deflt = pressAfterStyle("Safe"), pressAfterStyle("Balanced"), pressAfterStyle("Perfect"), pressAfterStyle(nil)
    check(safe and math.abs(safe - 0.18) < 0.03, "style Safe: F ~0.18 s after the swing, got " .. tostring(safe))
    check(balanced and math.abs(balanced - 0.25) < 0.03, "style Balanced: F ~0.25 s after the swing, got " .. tostring(balanced))
    check(perfect and math.abs(perfect - 0.28) < 0.03, "style Perfect: F ~0.28 s after the swing, got " .. tostring(perfect))
    check(deflt and safe and math.abs(deflt - safe) < 0.02, "the default style is Safe")

    end
    do -- backup detection: a track that is playing but never fired AnimationPlayed is still answered
    local pl, PLF = defaultBlocker()
    local plt = pl.ctx.now
    pl.silentSwing(1, 3, false, XID, 0.5, nil, 0.02)
    pl.frames(0.25)
    local plp = firstDown(pl, PLF, plt)
    check(plp ~= nil and plp <= 0.2, "polling: an attack whose event never fired must be caught within ~0.1 s, F at " .. tostring(plp))
    pl.frames(1.5)
    check(#fEvents(pl, PLF) == 2, "polling: the same track must only be answered once (no repeated presses), events " .. #fEvents(pl, PLF))
    local pe2, PEF = defaultBlocker()
    pe2.swing(1, 3, false, XID, 0.5); pe2.frames(2.0)
    check(#fEvents(pe2, PEF) == 2 and pe2.textOf("Seen 1 attacks"), "polling + event for one swing count once; got: " .. tostring(pe2.textOf("^Last:")))
    local pm, PMF = defaultBlocker()
    pm.silentSwing(1, 3, false, XID, 2.0, nil, 0.8); pm.frames(0.5)
    check(#fEvents(pm, PMF) == 0, "polling: an animation that is already 0.8 s in when first seen is not a new attack")
    local pg2, PGF = defaultBlocker()
    local pg2t = pg2.ctx.now
    pg2.silentSwing(1, 3, false, XID, 0.5, nil, 0.25); pg2.frames(0.2)
    local pg2p = firstDown(pg2, PGF, pg2t)
    check(pg2p ~= nil and pg2p <= 0.16, "polling: an attack seen 0.25 s late does not wait the default delay again, F at " .. tostring(pg2p))

    end
    do -- idle / movement layers are not attacks - unless the name (or what hurt me) says otherwise
    local pr1, PR1 = defaultBlocker()
    pr1.swing(1, 1, false, XID, 0.5); pr1.frames(0.5)
    check(#fEvents(pr1, PR1) == 0, "priority: an unnamed movement-layer animation is not an attack")
    local pr2, PR2 = defaultBlocker()
    pr2.swing(1, 1, false, XID, 0.5, "Hunter's Grasp"); pr2.frames(1.2)
    check(#fEvents(pr2, PR2) == 2, "priority: ...but a known attack name on a low layer is answered")
    local pr3, PR3 = defaultBlocker(nil, {learned = {[XID] = {n = 5, offset = 0.20, spread = 0.01}}})
    pr3.swing(1, 1, false, XID, 0.5); pr3.frames(0.5)
    check(#fEvents(pr3, PR3) == 2, "priority: ...and so is one that hurt me before")

    end
    do -- geometry that looks ahead
    local function pressedFor(enemy)
        local r, F = defaultBlocker(enemy)
        r.swing(1, 3, false, XID, 0.5); r.frames(0.8)
        return #fEvents(r, F) > 0, r
    end
    check(pressedFor({name = "Dasher", pos = {x = 0, y = 0, z = -30}, look = TOWARD_ME, vel = {x = 0, y = 0, z = 80}}), "geometry: an attacker 30 studs away DASHING in (80 studs/s) must be blocked")
    local slowFar, slowFarR = pressedFor({name = "Far", pos = {x = 0, y = 0, z = -30}, look = TOWARD_ME, vel = {x = 0, y = 0, z = 10}})
    check(not slowFar, "geometry: a slow attacker 30 studs away is too far")
    check(slowFarR.textOf("too far away"), "diagnostics: the readout must say WHY it ignored it; got: " .. tostring(slowFarR.textOf("^Last:")))
    check(pressedFor({name = "Side", pos = {x = 0, y = 0, z = -6}, look = {x = 1, y = 0, z = 0.1}}), "geometry: an attacker whose look is 90 degrees off still counts (M1s snap on)")
    check(pressedFor({name = "Adjacent", pos = {x = 0, y = 0, z = -3}, look = {x = 0, y = 0, z = -1}}), "geometry: right next to me the aim test is skipped")
    local away, awayR = pressedFor({name = "Away", pos = {x = 0, y = 0, z = -9}, look = {x = 0, y = 0, z = -1}})
    check(not away and awayR.textOf("not aimed at you"), "geometry: 9 studs away and looking away is not aimed at me (and the readout says so)")
    local behind, behindR = pressedFor({name = "Behind", pos = {x = 0, y = 0, z = 6}, look = {x = 0, y = 0, z = -1}})
    check(not behind and behindR.textOf("behind you"), "geometry: from behind F cannot help (and the readout says so)")
    local running, runningR = defaultBlocker({name = "Runner", pos = {x = 0, y = 0, z = -8}, look = {x = 0, y = 0, z = -1}, vel = {x = 0, y = 0, z = 14}})
    runningR = nil
    running.swing(1, 3, false, XID, 0.5); running.frames(0.4)
    check(#fEvents(running, keyNamed(running, "F")) > 0, "geometry: an attacker RUNNING AT me counts as aimed at me even if his body still points elsewhere")

    end
    do -- names tell what ignores block (only matters when the 'ignores block' action is not 'Block anyway')
    for _, case in ipairs({{"Hunter's Grasp", "skip", false}, {"Flowing_Water", "skip", false}, {"Homerun", "skip", false}, {"Mini Uppercut", "skip", false},
                           {"Hunter's Grasp", "block", true}, {"Lethal Whirlwind Stream", "skip", true}, {"M1_2", "skip", true}, {"Pinpoint Cut", "skip", true}}) do
        local r, F = defaultBlocker(nil, {block = {pierceMode = case[2]}})
        r.swing(1, 3, false, XID, 0.5, case[1]); r.frames(0.4)
        local did = #fEvents(r, F) > 0
        check(did == case[3], string.format("names: '%s' with '%s' -> F %s, expected %s", case[1], case[2], tostring(did), tostring(case[3])))
    end
    local nd, NDF = defaultBlocker(nil, {block = {pierceMode = "skip"}})
    nd.swing(1, 3, false, XID, 0.5, "Hunter's Grasp"); nd.frames(0.8)
    check(nd.textOf("skipped %(known to ignore block%)"), "diagnostics: the readout must say it skipped a known unblockable move; got: " .. tostring(nd.textOf("^Last:")))

    end
    do -- the same swing seen twice is one attack; two different animations at once are two (but teach the learner once)
    local r1, F1 = defaultBlocker()
    r1.swing(1, 3, false, XID, 0.5); r1.frames(0.05); r1.swing(1, 3, false, XID, 0.5); r1.frames(0.9)
    check(r1.textOf("Seen 1 attacks: 1 answered"), "dedupe: the same animation twice within 0.12 s is ONE attack and one is answered; got: " .. tostring(r1.textOf("^Last:")))
    local r2 = defaultBlocker()
    r2.swing(1, 3, false, XID, 0.5); r2.frames(0.05); r2.swing(1, 3, false, "rbxassetid://555", 0.5); r2.frames(0.9)
    check(r2.textOf("Seen 2 attacks: 2 answered"), "dedupe: two different animations are two attacks; got: " .. tostring(r2.textOf("^Last:")))
    end
    do -- what ignores block, per character (names from the guides)
    local r = run({executor = "full", body = PNG})
    check(r.textOf("Ignore or break block: .*Flowing Water %(guardbreak, medium%)"), "info: the Garou tab must list Flowing Water as a guard-break")
    check(r.textOf("Ignore or break block: .*Hunter's Grasp %(unblockable"), "info: ... and Hunter's Grasp as unblockable")
    check(r.textOf("Ignore or break block: .*Homerun %(guardbreak"), "info: the Metal Bat tab lists Homerun")
    check(r.textOf("Ignore or break block: .*Downslam %(unblockable"), "info: the Universal tab lists Downslam")
    check(r.textOf("Other notes: .*Lethal Whirlwind Stream %(disputed"), "info: disputed moves are shown as disputed, not as unblockable")
    check(r.textOf("Everything not listed is treated as blockable"), "info: it must say what the rest means")
    end
    do -- the counters can be reset
    local rs = defaultBlocker()
    rs.swing(1, 3, false, XID, 0.5); rs.frames(1.0)
    check(rs.textOf("Seen 1 attacks"), "diagnostics: Seen counter")
    local rsb = rs.findButton("Reset the attack counters"); if rsb then rs.tap(rsb) end
    check(rs.textOf("Seen 0 attacks"), "diagnostics: Reset must zero the counters; got: " .. tostring(rs.textOf("^Last:")))
    end
end


-- 18. GAROU "Flowing Water -> Kyoto": you cast Flowing Water, the script does side dash -> Lethal Whirlwind Stream -> whirlwind dash -> M1s -> instant twisted
do
    local KC = {}
    local function kyotoRun(kyoto, enemyPos)
        local r = run({executor = "full", body = PNG, settings = {kyoto = kyoto},
            world = {me = {pos = ME, look = LOOK}, right = {x = 1, y = 0, z = 0}, enemies = {{name = "Target", pos = enemyPos or {x = 10, y = 0, z = 0}, look = LOOK}}}})
        for _, e in ipairs(r.errors) do failures[#failures + 1] = "kyoto scenario: " .. e end
        local hit = r.toggleRowHit("Flowing Water -> Kyoto")
        if hit then r.tap(hit) else failures[#failures + 1] = "kyoto: the 'Flowing Water -> Kyoto' switch is missing" end
        r.ctx.keys, r.ctx.mouse = {}, {}
        local t0 = r.ctx.now
        r.fireKey(r.env.Enum.KeyCode.One)                                    -- YOU cast Flowing Water
        -- what was pressed, in order: key names for key downs, "M1" for clicks
        local seq, times = {}, {}
        local names = {}
        for name, code in pairs({A = "A", D = "D", W = "W", S = "S", Q = "Q", One = "One", Two = "Two", Three = "Three"}) do names[r.env.Enum.KeyCode[name]] = code end
        local events = {}
        for _, k in ipairs(r.ctx.keys) do if k.down then events[#events + 1] = {t = k.t, n = k.n, name = names[k.key] or "?"} end end
        for _, m in ipairs(r.ctx.mouse) do if m.down then events[#events + 1] = {t = m.t, n = m.n, name = "M1"} end end
        table.sort(events, function(a, b) return a.n < b.n end)
        for _, e in ipairs(events) do seq[#seq + 1] = e.name; times[#times + 1] = e.t - t0 end
        return r, seq, times
    end
    local r1, seq1, t1 = kyotoRun({})
    check(not seq1 or #seq1 > 0, "kyoto: nothing happened after casting Flowing Water")
    check(table.concat(seq1, " ") == "D Q Two W Q M1 M1 M1 S Q W Q",
        "kyoto (defaults): side dash toward him (D+Q), Lethal Whirlwind Stream (key 2), whirlwind dash (W+Q), 3 M1, step back (S+Q), twisted dash (W+Q); got: " .. table.concat(seq1, " "))
    check(math.abs(t1[1] - 0.30) < 0.02, "kyoto: the side dash comes 0.30 s after Flowing Water, got " .. tostring(t1[1]))
    check(math.abs((t1[3] - t1[1]) - 0.19) < 0.03, "kyoto: Lethal Whirlwind Stream right after the side dash (0.07 dash + 0.12 catch), got " .. tostring(t1[3] - t1[1]))
    check(math.abs((t1[4] - t1[3]) - 0.17) < 0.03, "kyoto: the whirlwind dash 'as early as possible' (0.05 cast + 0.12), got " .. tostring(t1[4] - t1[3]))
    check(math.abs((t1[6] - t1[4]) - 0.37) < 0.03, "kyoto: the first M1 comes after the whirlwind dash has landed (0.07 + 0.30), got " .. tostring(t1[6] - t1[4]))
    check(#r1.myWrites == 0, "kyoto: nothing may move / teleport me")
    for n = 1, 3 do
        local _, seq = kyotoRun({m1 = n})
        local want = "D Q Two W Q " .. string.rep("M1 ", n) .. "S Q W Q"
        check(table.concat(seq, " ") == want, "kyoto: M1 option " .. n .. " -> " .. want .. "; got: " .. table.concat(seq, " "))
    end
    local _, seqNoWhirl = kyotoRun({whirl = false, m1 = 2})
    check(table.concat(seqNoWhirl, " ") == "D Q Two M1 M1 S Q W Q", "kyoto: without the whirlwind dash; got: " .. table.concat(seqNoWhirl, " "))
    local _, seqNoTwist = kyotoRun({twisted = false, m1 = 2})
    check(table.concat(seqNoTwist, " ") == "D Q Two W Q M1 M1", "kyoto: without the instant twisted; got: " .. table.concat(seqNoTwist, " "))
    local _, seqBare = kyotoRun({whirl = false, twisted = false, m1 = 1})
    check(table.concat(seqBare, " ") == "D Q Two M1", "kyoto: the bare Kyoto + one M1; got: " .. table.concat(seqBare, " "))
    local _, seqLeft, tLeft = kyotoRun({side = "Left", wait = 0.6})
    check(seqLeft[1] == "A" and math.abs(tLeft[1] - 0.6) < 0.02, "kyoto: side = Left and wait 0.6 s; got " .. tostring(seqLeft[1]) .. " at " .. tostring(tLeft[1]))
    local _, seqBehind = kyotoRun({side = "Behind"}, {x = 0, y = 0, z = -6})
    check(seqBehind[1] == "D" or seqBehind[1] == "A", "kyoto: side = Behind is still a side dash")
    local _, seqLeftEnemy = kyotoRun({}, {x = -10, y = 0, z = 0})
    check(seqLeftEnemy[1] == "A", "kyoto: toward an enemy on my left -> A")
    -- garbage in the config is cleaned
    local _, seqBad = kyotoRun({m1 = 99, wait = "x", whirl = "no", twisted = 5, side = "Up"})
    check(table.concat(seqBad, " ") == "D Q Two M1 M1 M1", "kyoto: garbage options are cleaned (m1 3, default wait, whirl / twisted need exactly true); got: " .. table.concat(seqBad, " "))
    -- not armed -> nothing; only the trigger starts it
    local ra = run({executor = "full", body = PNG, world = {me = {pos = ME, look = LOOK}, enemies = {}}})
    ra.fireKey(ra.env.Enum.KeyCode.One)
    check(#ra.ctx.keys == 0, "kyoto: not armed -> casting Flowing Water must do nothing")
    local rb = run({executor = "full", body = PNG, world = {me = {pos = ME, look = LOOK}, enemies = {}}})
    local rbHit = rb.toggleRowHit("Flowing Water -> Kyoto"); if rbHit then rb.tap(rbHit) end
    rb.fireKey(rb.env.Enum.KeyCode.Two)
    check(#rb.ctx.keys == 0, "kyoto: only Flowing Water (key 1) starts it, not another move")
    -- the options are saved with the config
    local rc = run({executor = "full", body = PNG, settings = {kyoto = {m1 = 2, wait = 0.45, whirl = false, twisted = true, side = "Left"}}})
    local rcEnc = rc.save()
    check(rcEnc and rcEnc.kyoto and rcEnc.kyoto.m1 == 2 and rcEnc.kyoto.wait == 0.45 and rcEnc.kyoto.whirl == false and rcEnc.kyoto.twisted == true and rcEnc.kyoto.side == "Left",
        "kyoto: options must be part of the saved config")
    local rd = run({executor = "full", body = PNG}); local rdEnc = rd.save()
    check(rdEnc and rdEnc.kyoto and rdEnc.kyoto.m1 == 3 and rdEnc.kyoto.whirl == true and rdEnc.kyoto.twisted == true and rdEnc.kyoto.side == "Toward", "kyoto: defaults 3 M1, whirl on, twisted on, Toward")
    check(rd.textOf("Kyoto: M1s before the twisted dash"), "kyoto: the M1 option is shown in the Garou tab")
end

-- 19. BLOCK AGAINST LATENCY: stay up between a combo's hits, pre-block rushers, say how much time is left, and check the block really came up
do
    local function blocker(settings, opts)
        opts = opts or {}
        local enemy = opts.enemy or {name = "Enemy", pos = BLOCKER, look = TOWARD_ME}
        local r = run({executor = "full", body = PNG, ping = opts.ping, settings = settings, blockSim = opts.sim,
            world = {me = {pos = ME, look = LOOK}, enemies = {enemy}}})
        for _, e in ipairs(r.errors) do failures[#failures + 1] = "latency scenario: " .. e end
        if opts.ping then r.frames(2) end
        local hit = r.toggleRowHit("Auto block"); if hit then r.tap(hit) end
        return r, keyNamed(r, "F")
    end
    local function downs(r, F) local n = 0 for _, k in ipairs(fEvents(r, F)) do if k.down then n = n + 1 end end return n end
    local ID = "rbxassetid://901"

    do -- a combo's next hits keep the block up between them (default 0.35 s); with 0 the block lets go and presses again for every hit
        local function comboDowns(settings)
            local r, F = blocker(settings)
            for _ = 1, 4 do r.swing(1, 3, false, ID, 0.3); r.frames(0.5) end                -- an M1 chain: a swing every 0.5 s
            r.frames(1.0)
            return downs(r, F), r, F
        end
        local withChain, rc, FC = comboDowns(nil)
        local without = comboDowns({block = {chainGrace = 0}})
        check(withChain == 2, "chain hold (default 0.35 s): hit 1 is blocked, then F stays up through hits 2-4: expected 2 presses, got " .. withChain)
        check(without == 4, "chain hold off (0 s): every swing needs its own press: expected 4, got " .. without)
        local lastEv = fEvents(rc, FC)
        check(not lastEv[#lastEv].down, "chain hold: it still lets go after the combo")
        local rs = run({executor = "full", body = PNG, settings = {block = {chainGrace = 99}}})
        local enc = rs.save()
        check(enc and enc.block.chainGrace == 0.8, "chain hold: garbage is clamped to 0.8 s, got " .. tostring(enc and enc.block.chainGrace))
    end

    do -- pre-block: he dashes at me, F goes down BEFORE any swing; it can be switched off
        local dasher = {name = "Dasher", pos = {x = 0, y = 0, z = -14}, look = TOWARD_ME, vel = {x = 0, y = 0, z = 80}}
        local r, F = blocker(nil, {enemy = dasher})
        local t0 = r.ctx.now
        r.frames(0.4)
        local first = fEvents(r, F)[1]
        check(first and first.down and first.t - t0 <= 0.2, "pre-block: a player dashing at me at 80 studs/s gets F down before he even swings, at " .. tostring(first and (first.t - t0)))
        r.frames(0.2)
        check(r.textOf("1 pre%-block%(s%) on rushers"), "pre-block: the readout counts it; got: " .. tostring(r.textOf("^Last:")))
        local r2, F2 = blocker({block = {rush = false}}, {enemy = dasher})
        r2.frames(1.0)
        check(#fEvents(r2, F2) == 0, "pre-block: switched off -> nothing happens until he swings")
        local rSlow, FSlow = blocker(nil, {enemy = {name = "Jogger", pos = {x = 0, y = 0, z = -14}, look = TOWARD_ME, vel = {x = 0, y = 0, z = 10}}})
        rSlow.frames(1.5)
        check(#fEvents(rSlow, FSlow) == 0, "pre-block: he would need ~1 s to arrive (10 studs/s): too early to hold F")
        local r3, F3 = blocker(nil, {enemy = {name = "Walker", pos = {x = 0, y = 0, z = -9}, look = TOWARD_ME, vel = {x = 0, y = 0, z = 6}}})
        r3.frames(1.0)
        check(#fEvents(r3, F3) == 0, "pre-block: somebody just walking at me is not a rush")
        local r4, F4 = blocker(nil, {enemy = {name = "Passer", pos = {x = 0, y = 0, z = -9}, look = {x = 1, y = 0, z = 0}, vel = {x = 40, y = 0, z = 0}}})
        r4.frames(1.0)
        check(#fEvents(r4, F4) == 0, "pre-block: running past me sideways is not a rush")
        local r5, F5 = blocker(nil, {enemy = {name = "Far", pos = {x = 0, y = 0, z = -40}, look = TOWARD_ME, vel = {x = 0, y = 0, z = 80}}})
        r5.frames(0.2)
        check(#fEvents(r5, F5) == 0, "pre-block: still 40 studs away (outside the range) -> wait")
        local r6, F6 = blocker(nil, {enemy = {name = "Behind", pos = {x = 0, y = 0, z = 10}, look = LOOK, vel = {x = 0, y = 0, z = -60}}})
        r6.frames(0.5)
        check(#fEvents(r6, F6) == 0, "pre-block: a rusher BEHIND me cannot be blocked: no press")
        local r7 = run({executor = "full", body = PNG, settings = {block = {rush = 0}}}); local e7 = r7.save()
        check(e7 and e7.block.rush == true, "pre-block: garbage in the saved value falls back to on")
    end

    do -- the reaction-time readout is honest about the ping
        local r = blocker(nil, {ping = 100}); r.frames(1.0)
        check(r.textOf("your ping is 100 ms, so ~83 ms are left"), "budget: 183 ms M1 - 100 ms ping = 83 ms; got: " .. tostring(r.textOf("^Reaction time")))
        check(not r.textOf("too little for the FIRST hit"), "budget: 83 ms is enough, no warning")
        local r2 = blocker(nil, {ping = 150}); r2.frames(1.0)
        check(r2.textOf("your ping is 150 ms, so ~33 ms are left"), "budget: 33 ms left at 150 ms ping; got: " .. tostring(r2.textOf("^Reaction time")))
        check(r2.textOf("too little for the FIRST hit"), "budget: it says the first hit of a combo is the problem")
        local r3 = blocker(nil); r3.frames(1.0)
        check(r3.textOf("your ping is not known yet"), "budget: no ping -> says so")
    end

    do -- does the block really come up? teach it, learn it from presses, repeat a press that did not take
        local function senseOf(r) local e = r.save() return e and e.block and e.block.sense end
        local function has(list, f) for _, x in ipairs(list or {}) do if x == f then return true end end return false end
        -- Teach button
        local rt = blocker(nil, {sim = {}})
        local teach = rt.findButton("Teach it what blocking looks like (stand still)"); if teach then rt.tap(teach) end
        rt.frames(1.0)
        check(has(senseOf(rt), "ws:6"), "teach: the walk-speed change while blocking (ws:6) must be learned from the Teach button")
        check(rt.textOf("I know what blocking looks like %(ws:6%)"), "teach: the readout says what it learned; got: " .. tostring(rt.textOf("^Block check")))
        check(rt.ctx.blockSim.up == false, "teach: it lets go of F afterwards")
        -- passive learning from two real blocks
        local rp, FP = blocker(nil, {sim = {}})
        for _ = 1, 2 do rp.swing(1, 3, false, ID, 0.5); rp.frames(1.0) end
        check(has(senseOf(rp), "ws:6"), "passive: two real blocks teach it what blocking looks like")
        -- a press that does not take (your own M1 lockout) is repeated
        local sim = {}
        local rr, FR = blocker({block = {sense = {"ws:6"}}}, {sim = sim})
        sim.lockoutUntil = rr.ctx.now + 0.2
        rr.swing(1, 3, false, ID, 0.5); rr.frames(1.0)
        check(sim.dropped and sim.dropped >= 2, "retry: the first presses fall into the lockout and are dropped; dropped = " .. tostring(sim.dropped))
        check((sim.ups or 0) >= 1, "retry: ... and a later press takes (the block really came up)")
        check(downs(rr, FR) >= 3, "retry: F was pressed again, presses = " .. downs(rr, FR))
        check(rr.textOf("press%(es%) repeated because the block was not up"), "retry: the readout says so; got: " .. tostring(rr.textOf("^Last:")))
        local ev = fEvents(rr, FR)
        check(not ev[#ev].down and sim.up == false, "retry: and it still lets go at the end")
        -- a press that took is not repeated
        local sim2 = {}
        local ro, FO = blocker({block = {sense = {"ws:6"}}}, {sim = sim2})
        ro.swing(1, 3, false, ID, 0.5); ro.frames(1.0)
        check(downs(ro, FO) == 1 and (sim2.dropped or 0) == 0, "retry: a block that came up is left alone, presses = " .. downs(ro, FO))
        check(ro.textOf("Confirmed 1"), "retry: the readout counts the confirmation; got: " .. tostring(ro.textOf("^Block check")))
        -- switched off in the settings -> no repeats even when dropped
        local sim3 = {}
        local rv, FV = blocker({block = {sense = {"ws:6"}, verify = false}}, {sim = sim3})
        sim3.lockoutUntil = rv.ctx.now + 0.2
        rv.swing(1, 3, false, ID, 0.5); rv.frames(1.0)
        check(downs(rv, FV) == 1, "verify off: no repeated presses, presses = " .. downs(rv, FV))
        check(rv.textOf("Block check: off"), "verify off: the readout says so")
        -- if it NEVER comes up it stops second-guessing after 3 tries
        local sim4 = {never = true}
        local rn, FN = blocker({block = {sense = {"ws:6"}}}, {sim = sim4})
        for _ = 1, 3 do rn.swing(1, 3, false, ID, 0.5); rn.frames(1.5) end
        rn.frames(1.0)
        check(rn.textOf("switched off"), "never: after 3 holds where the block never came up it switches the check off; got: " .. tostring(rn.textOf("^Block check")))
        local before = downs(rn, FN)
        rn.swing(1, 3, false, ID, 0.5); rn.frames(1.5)
        check(downs(rn, FN) == before + 1, "never: once off, one press per attack again (no repeats)")
        -- forget
        local rf = blocker({block = {sense = {"ws:6"}}}, {sim = {}})
        rf.frames(1.0)
        check(rf.textOf("I know what blocking looks like"), "forget: starts learned from the saved config")
        local fb = rf.findButton("Forget what blocking looks like"); if fb then rf.tap(fb) end
        rf.frames(1.0)
        check(rf.textOf("still learning what blocking looks like"), "forget: the Forget button wipes it; got: " .. tostring(rf.textOf("^Block check")))
        -- garbage in the saved signature is cleaned
        local rg = run({executor = "full", body = PNG, settings = {block = {sense = {"junk", 5, "ws:6", string.rep("x", 300), "anim:ok"}}}})
        local sg = senseOf(rg)
        check(has(sg, "ws:6") and has(sg, "anim:ok") and #sg == 2, "saved signature: only valid features survive, got " .. tostring(sg and #sg))
    end
end

-- 20. YOUR OWN PICTURE + the hero banner
do
    local function pictureImages(r)                                           -- every ImageLabel showing a downloaded / chosen picture
        local out = {}
        for _, inst in ipairs(r.instances) do
            local img = rawget(inst, "Image")
            if rawget(inst, "__name") == "ImageLabel" and type(img) == "string" and (img:find("animation_hub_bg_", 1, true) or img:find("mine.png", 1, true) or img:find("rbxassetid://", 1, true)) then out[#out + 1] = img end
        end
        return out
    end
    local function lastPicture(r) local l = pictureImages(r) return l[#l] end
    local function use(r, text) r.typeInto("https://", text); local b = r.findButton("Use this picture"); if b then r.tap(b) end r.frames(0.1) end
    local base = run({executor = "full", body = PNG})
    for _, e in ipairs(base.errors) do failures[#failures + 1] = "picture scenario: " .. e end
    check(#pictureImages(base) >= 2, "banner: the window background AND the hero banner show the picture, got " .. #pictureImages(base) .. " image(s)")

    local r1 = run({executor = "full", body = PNG})
    use(r1, "https://example.com/my picture.png")
    check(r1.textOf("Your picture is on%."), "picture: a link to a PNG is accepted; got: " .. tostring(r1.textOf("^Your picture") or r1.textOf("Not changed")))
    local e1 = r1.save()
    check(e1 and e1.picture == "https://example.com/my picture.png", "picture: the link is kept in the config, got " .. tostring(e1 and e1.picture))
    local imgs = pictureImages(r1)
    check(#imgs >= 2 and imgs[#imgs]:find("animation_hub_bg_", 1, true), "picture: background and banner switch to the new picture")
    local backBtn = r1.findButton("Back to random anime pictures"); if backBtn then r1.tap(backBtn) end
    local e1b = r1.save()
    check(e1b and e1b.picture == "", "picture: 'Back to random anime pictures' clears it")

    local r2 = run({executor = "full", body = "<html>404</html>"})
    use(r2, "https://example.com/not-a-picture")
    check(r2.textOf("did not give a PNG or JPG"), "picture: a link that is not a PNG / JPG is refused with a reason; got: " .. tostring(r2.textOf("Not changed")))
    check((r2.save() or {}).picture == "", "picture: a refused link is not saved")

    local r3 = run({executor = "full", body = PNG, files = {["mine.png"] = PNG, ["notes.txt"] = "hello hello hello hello"}})
    use(r3, "mine.png")
    check(lastPicture(r3) == "rbxasset://mine.png", "picture: a file in the workspace folder is used as it is, got " .. tostring(lastPicture(r3)))
    check((r3.save() or {}).picture == "mine.png", "picture: the file name is kept in the config")
    use(r3, "missing.png")
    check(r3.textOf("there is no file called 'missing.png'"), "picture: a missing file says so; got: " .. tostring(r3.textOf("Not changed")))
    use(r3, "notes.txt")
    check(r3.textOf("that file is not a PNG or JPG"), "picture: a text file is refused; got: " .. tostring(r3.textOf("Not changed")))
    check((r3.save() or {}).picture == "mine.png", "picture: refused entries leave the picture and the config as they were")

    local r4 = run({executor = "full", body = PNG})
    use(r4, "rbxassetid://5551212")
    check(lastPicture(r4) == "rbxassetid://5551212", "picture: a Roblox image id works")
    use(r4, "  4242  ")
    check(lastPicture(r4) == "rbxassetid://4242", "picture: plain digits are an image id too (spaces trimmed)")
    use(r4, "")
    check(r4.textOf("not a usable link or file name"), "picture: nothing typed is refused")
    use(r4, string.rep("a", 400))
    check(r4.textOf("not a usable link or file name"), "picture: a 400 character entry is refused")
    use(r4, "bad\1name")
    check(r4.textOf("not a usable link or file name"), "picture: control characters are refused")

    local r5 = run({executor = "nofiles", body = PNG})
    use(r5, "https://example.com/x.png")
    check(r5.textOf("cannot show downloaded pictures"), "picture: an executor without file functions says so; got: " .. tostring(r5.textOf("Not changed")))

    -- a saved picture is loaded at start (instead of a random one); a broken one falls back with a note; garbage is dropped
    local r6 = run({executor = "full", body = PNG, settings = {picture = "https://example.com/saved.png"}})
    local usedSaved, usedRandom = false, false
    for _, u in ipairs(r6.ctx.requests) do
        if u == "https://example.com/saved.png" then usedSaved = true end
        if u:find("waifu.pics", 1, true) then usedRandom = true end
    end
    check(usedSaved and not usedRandom, "picture: a saved picture is loaded at start, not a random one")
    local r7 = run({executor = "full", body = "<html>gone</html>", settings = {picture = "https://example.com/gone.png"}})
    r7.frames(0.2)
    check(r7.textOf("Your picture did not load"), "picture: a saved picture that no longer loads says so; got: " .. tostring(r7.textOf("^Your picture") or r7.textOf("Random")))
    local r8 = run({executor = "full", body = PNG, settings = {picture = 5}})
    check((r8.save() or {}).picture == "", "picture: a non-text saved value is dropped")
    local r9 = run({executor = "full", body = PNG, settings = {picture = "bad\1"}})
    check((r9.save() or {}).picture == "", "picture: control characters in the saved value are dropped")
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
print("smoke test passed (32 scenarios)")
