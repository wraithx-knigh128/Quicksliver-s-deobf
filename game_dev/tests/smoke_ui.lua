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
    local ctx = {callbacks = {}, heartbeats = {}, waits = {}, connections = 0, disconnects = 0}
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
        return inst
    end}
    for _, n in ipairs({"UDim2", "UDim", "Color3", "ColorSequence", "TweenInfo", "CFrame", "Enum", "Vector3"}) do
        env[n] = dummy(n, ctx)
    end
    env.Vector2 = {new = function(x, y) return {X = x or 0, Y = y or 0} end}
    env.task = {
        spawn = function(f, ...) local ok, e = pcall(f, ...); if not ok then errors[#errors + 1] = "task: " .. tostring(e) end end,
        wait = function(t) ctx.waits[#ctx.waits + 1] = t or 0; return 0 end,
    }
    env.warn = function(...) errors[#errors + 1] = "warn: " .. table.concat({...}, " ") end
    env.print = function() end
    env.os = {clock = os.clock}
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
    return {findButton = findButton, textOf = textOf, errors = errors, ctx = ctx, writes = writes, assets = assets, bgSet = bgSet, genv = genvStore, env = env, fn = fn}
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

if #failures > 0 then
    print("PROBLEMS:"); for _, x in ipairs(failures) do print("  " .. x) end
    finish(1)
    return
end
print("smoke test passed (6 scenarios)")
