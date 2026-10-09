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
local function fakeChar(pos, look, animFns, writes)
    -- a proxy: every WRITE to the character's root part (even re-assigning an existing field) is recorded
    local data = {Position = {X = pos.x, Y = pos.y, Z = pos.z}, CFrame = {LookVector = {X = look.x, Y = look.y, Z = look.z}}}
    local hrp = setmetatable({}, {__index = data, __newindex = function(_, k, v) writes[#writes + 1] = k; data[k] = v end})
    local animator = {AnimationPlayed = {Connect = function(_, fn) animFns[#animFns + 1] = fn; return {Disconnect = function() end} end}}
    local hum = {Health = 100, GetState = function() return "Running" end,
                 FindFirstChildOfClass = function() return animator end, WaitForChild = function() return animator end}
    local char = {
        FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return hrp end end,
        FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return hum end end,
        WaitForChild = function(_, n) if n == "Humanoid" then return hum end return hrp end,
        GetAttribute = function() return nil end,
    }
    return char, hrp
end

-- scenario = {executor = "full" | "nofiles", body = bytes the image host returns}
local function run(scenario)
    local ctx = {callbacks = {}, heartbeats = {}, inputBegan = {}, animPlayed = {}, keys = {}, mouse = {}, waits = {},
                 connections = 0, disconnects = 0}
    local errors, instances, writes, assets = {}, {}, {}, {}
    local genvStore = {AH_DISABLE_REBUILD = not scenario.allowRebuild}   -- clicking every button must not rebuild the menu mid-test
    local env = setmetatable({}, {__index = _G})

    env.game = dummy("game", ctx); env.workspace = dummy("workspace", ctx)
    env.workspace.CurrentCamera = {ViewportSize = {X = 800, Y = 450}, CFrame = {RightVector = {X = 1, Y = 0, Z = 0}}}
    local world = scenario.world            -- optional: {me = {pos, look}, enemies = {{name, pos, look}...}, right = {x,y,z}}
    local myAnim, myWrites, enemyAnim, enemies = {}, {}, {}, {}
    local myChar, myHrp
    if world then
        myChar, myHrp = fakeChar(world.me.pos, world.me.look, myAnim, myWrites)
        if world.right then env.workspace.CurrentCamera.CFrame = {RightVector = {X = world.right.x, Y = world.right.y, Z = world.right.z}} end
        for i, e in ipairs(world.enemies or {}) do
            enemyAnim[i] = {}
            local c = fakeChar(e.pos, e.look, enemyAnim[i], {})
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
    if scenario.settings or scenario.settingsThrows then
        env.isfile = function() return true end
        env.readfile = function() return "SETTINGS_RAW" end
    end
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
    local function swing(i, priority, looped)                              -- enemy i starts an attack animation
        for _, fn in ipairs(enemyAnim[i] or {}) do
            local ok, e = pcall(fn, {Animation = {AnimationId = "rbxassetid://777"}, Looped = looped or false, Priority = {Value = priority or 3}})
            if not ok then errors[#errors + 1] = "enemy AnimationPlayed handler: " .. tostring(e) end
        end
    end
    return {frames = frames, fireInput = fireInput, swing = swing, myWrites = myWrites, advance = advance, tap = tap, toggleRowHit = toggleRowHit, fireKey = fireKey, playAnimation = playAnimation,
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

-- 1b. single clicks: floating bar state + clean-up
local f = run({executor = "full", body = PNG})
for _, e in ipairs(f.errors) do failures[#failures + 1] = "scenario f: " .. e end
clickAll(f, 1)
local fab = f.genv.__AnimationHubFab
check(type(fab) == "table", "floating bar state was not saved")
if fab then
    check(fab.locked == true, "Lock button did not lock")
    check(fab.minimized == true, "minimise button did not minimise")
    check(type(fab.x) == "number" and fab.x >= 4 and fab.x <= 800, "bar x is off screen: " .. tostring(fab.x))
    check(type(fab.y) == "number" and fab.y >= 4 and fab.y <= 450, "bar y is off screen: " .. tostring(fab.y))
end
check(f.ctx.disconnects > 0, "cleanup did not disconnect any listener")
check(f.genv.__AnimationHubCleanup == nil, "cleanup should unregister itself")

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

-- 5. saved settings: garbage values are cleaned up, valid ones applied, and the file is re-written
local g = run({executor = "full", body = PNG, settings = {
    timing = {m1 = 0.3, dash = "bad"}, auto = {on = false, strength = 99}, speed = 1.4,
    combos = {Kyoto = {speed = 99, auto = "weird", side = "Right", move = 0.7}, [7] = {speed = 1}},
    pins = {Kyoto = {x = 120, y = 80}, Bogus = {x = "a"}, NoSuchCombo = {x = 5, y = 6}},
}})
for _, e in ipairs(g.errors) do failures[#failures + 1] = "settings scenario: " .. e end
for _ = 1, 4 do for _, hb in ipairs(g.ctx.heartbeats) do pcall(hb, 1) end end
local enc = g.ctx.encoded
check(type(enc) == "table", "settings were not re-saved")
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
check(type(rb.genv.__AnimationHubUi) == "table" and rb.genv.__AnimationHubUi.theme == "Ocean", "rebuild: the chosen theme must survive the rebuild")

if #failures > 0 then
    print("PROBLEMS:"); for _, x in ipairs(failures) do print("  " .. x) end
    finish(1)
    return
end
print("smoke test passed (20 scenarios)")
