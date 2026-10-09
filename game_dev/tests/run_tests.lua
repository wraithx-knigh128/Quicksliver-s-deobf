-- Run from game_dev/:  lua tests/run_tests.lua
package.path = "./?.lua;" .. package.path
local Executor = require("mini_executor")

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print("PASS  " .. name)
    else failed = failed + 1; print("FAIL  " .. name .. "\n      " .. tostring(err)) end
end
local function eq(a, b, msg)
    if a ~= b then error((msg or "expected equal") .. ": got " .. tostring(a) .. ", want " .. tostring(b), 2) end
end

local ex = Executor.new(".")
local Engine = ex:require("combo_engine.lua")
local Data = ex:require("tsb_data.lua")
local Drag = ex:require("drag_tracker.lua")
local Ping = ex:require("ping_model.lua")
local CO = ex:require("combo_options.lua")
local Assist = ex:require("assist.lua")
local CM = ex:require("combat_math.lua")
Engine.loadData(Data)

local function feedAll(p, tokens, t0, dt)
    local t = t0
    for _, tok in ipairs(tokens) do p:feed(tok, t); t = t + dt end
    return t
end

test("Kyoto predicted mid-combo with correct next input", function()
    local p = Engine.newPredictor()
    local t = feedAll(p, {"M1", "M1", "M1", "SIDEDASH"}, 0, 0.3)
    local pred = p:predict(t - 0.3)
    local byName = {}
    for _, r in ipairs(pred) do byName[r.name] = r end
    assert(byName.Kyoto, "Kyoto not predicted"); eq(byName.Kyoto.progress, 4)
    eq(byName.Kyoto.next, "FLOWING_WATER")
    assert(byName.M1Reset, "ambiguous prefix should also keep M1Reset alive")
    local weights, best = p:nextInputs(t - 0.3)
    assert(weights.FLOWING_WATER and weights.FRONTDASH, "both continuations weighted")
    assert(best, "has a best guess")
end)

test("full Kyoto fires onComplete", function()
    local p, done = Engine.newPredictor(), nil
    p.onComplete = function(n) done = n end
    feedAll(p, Engine.Combos.Kyoto.steps, 0, 0.3)
    eq(done, "Kyoto")
end)

test("gap longer than maxGap drops the prediction", function()
    local p = Engine.newPredictor()
    p:feed("M1", 0); p:feed("M1", 0.3)
    assert(#p:predict(0.3) > 0)
    eq(#p:predict(5), 0, "expired")
    p:feed("M1", 5)                      -- late third M1 must restart at step 1, not step 3
    eq(p:predict(5)[1].progress, 1)
end)

test("wrong input resets progress", function()
    local p = Engine.newPredictor()
    p:feed("M1", 0); p:feed("M1", 0.2); p:feed("BACKDASH", 0.4)
    eq(#p:predict(0.4), 0)
end)

test("custom combo (Oreo placeholder) can be defined and predicted", function()
    Engine.define("OreoTest", {"M1", "UPPERCUT", "Q"}, 1.0)
    local p = Engine.newPredictor()
    p:feed("M1", 0); p:feed("UPPERCUT", 0.4)
    local pred = p:predict(0.4)
    local found
    for _, r in ipairs(pred) do if r.name == "OreoTest" then found = r end end
    assert(found, "OreoTest not predicted"); eq(found.next, "Q")
    Engine.Combos.OreoTest = nil
end)

test("tech direction: thrown backwards -> Forward, sideways -> Left/Right, wall -> Left", function()
    local f = {x = 0, z = -1}
    eq(Engine.chooseTechDirection({knockback = {x = 0, z = 1}, facing = f}), "Forward")
    eq(Engine.chooseTechDirection({knockback = {x = 0, z = -1}, facing = f}), "Back")
    eq(Engine.chooseTechDirection({knockback = {x = 1, z = 0}, facing = f}), "Left")
    eq(Engine.chooseTechDirection({knockback = {x = -1, z = 0}, facing = f}), "Right")
    eq(Engine.chooseTechDirection({knockback = {x = 0, z = 1}, facing = f, wallAhead = true}), "Left")
    eq(Engine.chooseTechDirection({knockback = {x = 0, z = 0}, facing = f}), "Back")
end)

test("every combo in the data is well-formed and uses known tokens", function()
    local generic = {M1=1, Q=1, FRONTDASH=1, SIDEDASH=1, BACKDASH=1, JUMP=1, JUMP_M1=1, UPPERCUT=1,
        MINI_UPPERCUT=1, DOWNSLAM=1, WALL_COMBO=1, GRAND_SLAM_AIR=1}
    local conf = {high=1, medium=1, low=1}
    local n = 0
    for name, c in pairs(Data.Combos) do
        n = n + 1
        assert(#c.steps >= 2, name .. " too short")
        assert(conf[c.confidence], name .. " bad confidence")
        local char = Data.Characters[c.character]
        assert(char or c.character == "Universal", name .. " unknown character " .. tostring(c.character))
        local known = {}
        if char then
            for _, list in ipairs({char.moves or {}, char.ultimates or {}}) do
                for k, v in pairs(list) do known[type(k) == "string" and k or v] = true end
            end
        end
        for i, tok in ipairs(c.steps) do
            assert(generic[tok] or known[tok], ("%s step %d: unknown token %s"):format(name, i, tok))
        end
    end
    assert(n >= 25, "expected the full combo set, got " .. n)
end)

test("every tech assist is well-formed and uses known tokens", function()
    local generic = {M1=1, Q=1, FRONTDASH=1, SIDEDASH=1, BACKDASH=1, JUMP=1, JUMP_M1=1, UPPERCUT=1, MINI_UPPERCUT=1, DOWNSLAM=1}
    local conf = {high=1, medium=1, low=1}
    local names = {}
    assert(#Data.TechAssists >= 15, "expected the full tech list")
    for _, t in ipairs(Data.TechAssists) do
        assert(type(t.name) == "string" and t.name ~= "", "tech without a name")
        assert(not names[t.name .. t.character], t.name .. " listed twice for " .. t.character); names[t.name .. t.character] = true
        assert(conf[t.confidence], t.name .. " bad confidence")
        assert(#t.steps >= 2, t.name .. " needs a trigger and at least one follow-up")
        assert(type(t.desc) == "string" and #t.desc > 0, t.name .. " has no description")
        local char = Data.Characters[t.character]
        assert(char or t.character == "Universal", t.name .. " unknown character " .. tostring(t.character))
        local known = {}
        if char then
            for _, list in ipairs({char.moves or {}, char.ultimates or {}}) do
                for k, v in pairs(list) do known[type(k) == "string" and k or v] = true end
            end
        end
        for i, tok in ipairs(t.steps) do
            assert(generic[tok] or known[tok], ("%s step %d: unknown token %s"):format(t.name, i, tok))
        end
    end
end)

test("no combo is a strict duplicate of another", function()
    local seen = {}
    for name, c in pairs(Data.Combos) do
        local key = table.concat(c.steps, ",")
        assert(not seen[key], name .. " duplicates " .. tostring(seen[key]))
        seen[key] = name
    end
end)

test("mechanics loaded", function()
    eq(Engine.Mechanics.ragdollCancelCooldown, 30); eq(Engine.Mechanics.m1Chain[4], 5)
end)

test("overlapping prefix: M1 M1 M1 SIDEDASH still matches a combo 'M1 M1 SIDEDASH'", function()
    local p, done = Engine.newPredictor({Short = {steps = {"M1", "M1", "SIDEDASH"}, maxGap = 1}}), nil
    p.onComplete = function(n) done = n end
    feedAll(p, {"M1", "M1", "M1", "SIDEDASH"}, 0, 0.2)
    eq(done, "Short", "suffix alignment lost (KMP bug)")
end)

test("repeated openers keep the furthest alignment", function()
    local p = Engine.newPredictor({A = {steps = {"M1", "M1", "M1", "Q"}, maxGap = 1}})
    feedAll(p, {"M1", "M1", "M1", "M1", "M1"}, 0, 0.2)   -- more M1s than needed: still 3 in a row
    local r = p:predict(0.8)[1]
    assert(r and r.progress == 3 and r.next == "Q", "expected progress 3 waiting for Q")
end)

test("single-step combo completes; bad input is ignored", function()
    local p, n = Engine.newPredictor({One = {steps = {"Q"}, maxGap = 1}}), 0
    p.onComplete = function() n = n + 1 end
    p:feed("Q", 0); p:feed(nil, 0.1); p:feed("Q", "x"); p:feed("Q", 0.2)
    eq(n, 2)
end)

test("expired gap clears every alignment, boundary is inclusive", function()
    local p, done = Engine.newPredictor({A = {steps = {"M1", "Q"}, maxGap = 1}}), nil
    p.onComplete = function(x) done = x end
    p:feed("M1", 0); p:feed("Q", 1.0)
    eq(done, "A", "gap == maxGap should still count")
    done = nil
    p:feed("M1", 5); p:feed("Q", 6.5)
    eq(done, nil, "gap > maxGap must not count")
end)

test("loadData skips malformed combos and define validates", function()
    local e = Engine.loadData({Combos = {Bad = {steps = {}}, Worse = {steps = {1, 2}}, Good = {steps = {"M1", "Q"}}}})
    local _, skipped = Engine.loadData({Combos = {Bad = {steps = {}}, Worse = {steps = {1}}}})
    eq(#skipped, 2)
    assert(not pcall(Engine.define, "x", {}), "empty steps accepted")
    assert(not pcall(Engine.define, "", {"M1"}), "empty name accepted")
    assert(not pcall(Engine.define, "x", {"M1"}, -1), "negative gap accepted")
    Engine.Combos.Good = nil
    Engine.loadData(Data)
end)

test("tech direction tolerates missing/unnormalised input", function()
    eq(Engine.chooseTechDirection(nil), "Back")
    eq(Engine.chooseTechDirection({}), "Back")
    eq(Engine.chooseTechDirection({knockback = {x = 0, z = 5}, facing = {x = 0, z = -10}}), "Forward")
    eq(Engine.chooseTechDirection({knockback = {x = 0, z = 5}, facing = {x = 0, z = 0}}), "Back")
end)

test("drag tracker: a tap never counts as a drag", function()
    local d = Drag.new(8)
    d:begin(100, 100, 50, 60)
    eq(d:move(103, 104), nil, "below threshold")
    assert(not d:suppressClick(1), "tap must not suppress its click")
    d:finish(1)
    assert(not d:suppressClick(1.01), "tap must not suppress later clicks")
end)

test("drag tracker: drag moves the origin and suppresses the click in both event orders", function()
    local d = Drag.new(8)
    d:begin(100, 100, 50, 60)
    local x, y = d:move(130, 90)
    eq(x, 80); eq(y, 50)
    assert(d:suppressClick(1), "click before pointer-up must be suppressed")
    d:finish(1)
    assert(d:suppressClick(1.1), "click right after pointer-up must be suppressed")
    assert(not d:suppressClick(1.3), "later taps must work again")
end)

test("drag tracker: threshold is exact, and move without begin is ignored", function()
    local d = Drag.new(10)
    eq(d:move(500, 500), nil)
    d:begin(0, 0, 0, 0)
    eq(d:move(9, 0), nil)
    local x = d:move(10, 0)
    eq(x, 10, "exactly at the threshold counts as a drag")
end)

test("drag tracker: locked buttons never drag but still tap", function()
    local d = Drag.new(8)
    d:setLocked(true)
    d:begin(0, 0, 5, 5)
    eq(d:move(200, 200), nil)
    assert(not d:suppressClick(1), "locked: click must go through")
    d:finish(1)
    assert(not d:suppressClick(1.05), "locked: no drag-end suppression")
    -- locking in the middle of a drag cancels it
    d:setLocked(false); d:begin(0, 0, 0, 0); assert(d:move(50, 0)); d:setLocked(true)
    eq(d:move(80, 0), nil); assert(not d:suppressClick(2))
end)

test("drag tracker: clamp keeps the box on screen", function()
    local x, y = Drag.clamp(-50, 900, 170, 44, 800, 450, 4)
    eq(x, 4); eq(y, 402)
    x, y = Drag.clamp(700, -3, 170, 44, 800, 450, 4)
    eq(x, 626); eq(y, 4)
    x, y = Drag.clamp(10, 10, 900, 600, 800, 450, 4)   -- box bigger than the screen: pin to the margin
    eq(x, 4); eq(y, 4)
end)

local function near(a, b, tol, msg)
    if math.abs(a - b) > (tol or 1e-9) then error((msg or "not close") .. ": got " .. tostring(a) .. ", want " .. tostring(b), 2) end
end

test("ping model: first sample seeds, EWMA converges, garbage is ignored", function()
    local m = Ping.new(0.5)
    eq(m:value(), nil)
    m:sample(100); eq(m:value(), 100)
    m:sample(0/0); m:sample(-5); m:sample(99999); m:sample("x"); m:sample(nil)
    eq(m:value(), 100, "garbage must not change the estimate")
    for _ = 1, 30 do m:sample(200) end
    near(m:value(), 200, 0.01, "should converge to the new ping")
end)

test("ping model: jitter and stability", function()
    local steady = Ping.new(0.3)
    for _ = 1, 10 do steady:sample(80) end
    assert(steady:stable(), "constant ping should be stable")
    local wild = Ping.new(0.3)
    for i = 1, 10 do wild:sample(i % 2 == 0 and 40 or 400) end
    assert(not wild:stable(), "swinging ping should not be stable")
    local fresh = Ping.new(); fresh:sample(50)
    assert(not fresh:stable(), "too few samples")
end)

test("ping model: adjustDelay only shifts dependent gaps and is bounded", function()
    near(Ping.adjustDelay(0.2, 100, 1), 0.2, 0, "M1 spacing (<0.3) must not move")
    near(Ping.adjustDelay(0.5, 100, 1), 0.4, 1e-9)
    near(Ping.adjustDelay(0.5, 100, 0), 0.5, 0, "strength 0 = off")
    near(Ping.adjustDelay(0.5, 0, 1), 0.5, 0, "no ping reading = off")
    near(Ping.adjustDelay(0.5, 900, 1), 0.3, 1e-9, "capped at 40% of the gap")
    near(Ping.adjustDelay(0.5, 100, 1.5), 0.35, 1e-9)
    near(Ping.adjustDelay(0.5, 100, nil), 0.5, 0, "bad strength = off")
    eq(Ping.adjustDelay(nil, 100, 1), nil)
end)

test("ping model: explicit dependent flag and fine-tune offset", function()
    near(Ping.adjustDelay(0.2, 100, 1, {dependent = true}), 0.12, 1e-9, "flagged dependent; shortening capped at 40% of 0.2 s")
    near(Ping.adjustDelay(0.5, 100, 1, {dependent = false}), 0.5, 0, "flagged independent never moves")
    near(Ping.adjustDelay(0.5, 100, 1, {dependent = true, offsetMs = 30}), 0.43, 1e-9, "+30 ms later")
    near(Ping.adjustDelay(0.5, 100, 1, {dependent = true, offsetMs = -50}), 0.35, 1e-9, "-50 ms earlier")
    near(Ping.adjustDelay(0.5, nil, 1, {dependent = true, offsetMs = 20}), 0.52, 1e-9, "offset works without a ping reading")
    near(Ping.adjustDelay(0.1, 100, 1, {dependent = true, offsetMs = -500}), 0.05, 1e-9, "never below the minimum")
    near(Ping.adjustDelay(0.5, 100, 1, {dependent = false, offsetMs = 80}), 0.5, 0, "offset never touches independent gaps")
end)

test("combo options: sanitize always returns a complete valid table", function()
    local o = CO.sanitize(nil)
    for k, v in pairs(CO.DEFAULTS) do eq(o[k], v, "default " .. k) end
    local bad = CO.sanitize({speed = 99, m1 = -3, dash = "x", move = 0/0, jump = 5, offsetMs = 1e9, auto = "weird", side = 7})
    eq(bad.speed, 2); eq(bad.m1, 0); eq(bad.dash, 0); eq(bad.move, 0); eq(bad.jump, 0.6); eq(bad.offsetMs, 100)
    eq(bad.auto, "global"); eq(bad.side, "Closest")
    eq(CO.sanitize({side = "Left"}).side, "Left"); eq(CO.sanitize({side = "Closest"}).side, "Closest")
    local ok = CO.sanitize({speed = 1.25, auto = "off", side = "Right", dash = 0.35, offsetMs = -20})
    eq(ok.speed, 1.25); eq(ok.auto, "off"); eq(ok.side, "Right"); eq(ok.dash, 0.35); eq(ok.offsetMs, -20)
    local a, b = CO.sanitize(nil), CO.sanitize(nil)
    a.speed = 2
    eq(b.speed, 1, "sanitize must not share tables")
    eq(CO.DEFAULTS.speed, 1, "defaults must stay untouched")
end)

test("combo options: isDefault and autoOn", function()
    assert(CO.isDefault(CO.new()), "fresh options are default")
    local o = CO.new(); o.speed = 1.1
    assert(not CO.isDefault(o), "changed options are not default")
    assert(CO.autoOn(true, CO.new()) and not CO.autoOn(false, CO.new()), "global mode follows the global toggle")
    o = CO.new(); o.auto = "on";  assert(CO.autoOn(false, o), "forced on")
    o.auto = "off"; assert(not CO.autoOn(true, o), "forced off")
end)

test("combo options: per-combo gap overrides the global gap, speeds multiply", function()
    local timing = {m1 = 0.2, dash = 0.3, move = 0.5, jump = 0.25}
    local o = CO.new()
    near(CO.gap("move", timing, o, 1), 0.5, 1e-9, "0 override = global gap")
    o.move = 0.8
    near(CO.gap("move", timing, o, 1), 0.8, 1e-9, "own gap wins")
    near(CO.gap("dash", timing, o, 1), 0.3, 1e-9, "other kinds still global")
    o.speed = 1.5
    near(CO.gap("move", timing, o, 2), 2.4, 1e-9, "global speed x combo speed x gap")
    near(CO.gap("m1", timing, CO.new(), nil), 0.2, 1e-9, "missing global speed = 1")
end)

test("combo options: trigger step, pin mode and learned animation are sanitised", function()
    local o = CO.sanitize({trigger = 7.9, pinMode = "run", trigAnim = "rbxassetid://123"})
    eq(o.trigger, 7); eq(o.pinMode, "run"); eq(o.trigAnim, "rbxassetid://123")
    local bad = CO.sanitize({trigger = -4, pinMode = "banana", trigAnim = "x\ny"})
    eq(bad.trigger, 0); eq(bad.pinMode, "assist"); eq(bad.trigAnim, "")
    eq(CO.sanitize({trigger = 9999}).trigger, 64); eq(CO.sanitize({trigAnim = string.rep("a", 500)}).trigAnim, "")
    eq(CO.sanitize({trigAnim = 5}).trigAnim, "")
    assert(not CO.isDefault(CO.sanitize({pinMode = "run"})), "pin mode run is a non-default setting")
end)

test("assist: trigger is the first move; remaining steps follow it", function()
    local moves = {FLOWING_WATER = true, HUNTERS_GRASP = true}
    local isMove = function(t) return moves[t] end
    local catch = {"DOWNSLAM", "HUNTERS_GRASP", "SIDEDASH", "M1"}
    eq(Assist.triggerIndex(catch, isMove), 2)
    local rest = Assist.remaining(catch, 2)
    eq(#rest, 2); eq(rest[1], "SIDEDASH"); eq(rest[2], "M1")
    eq(Assist.triggerIndex({"M1", "M1", "SIDEDASH"}, isMove), 1, "no move at all -> after step 1")
    eq(Assist.triggerIndex(catch, isMove, 3), 3, "override wins")
    eq(Assist.triggerIndex(catch, isMove, 99), 4, "override clamped to the length")
    eq(Assist.triggerIndex(catch, isMove, 0), 2, "0 = auto")
    eq(Assist.triggerIndex({}, isMove), nil); eq(Assist.triggerIndex(nil, isMove), nil)
    eq(Assist.remaining(catch, 4), nil, "nothing after the last step")
    eq(Assist.remaining(catch, "x"), nil)
end)

test("assist: newest armed combo wins, side alternates", function()
    local order = {"A", "B", "C"}
    eq(Assist.pick(order, function(n) return n ~= "C" end), "B")
    eq(Assist.pick(order, function() return false end), nil)
    eq(Assist.pick({}, function() return true end), nil)
    eq(Assist.nextSide("Left"), "Left"); eq(Assist.nextSide("Right", "Right"), "Right")
    eq(Assist.nextSide("Alternate", nil), "Left"); eq(Assist.nextSide("Alternate", "Left"), "Right"); eq(Assist.nextSide("Alternate", "Right"), "Left")
end)

test("combat math: closest player ignores myself, respects range, survives garbage", function()
    local me = {x = 0, y = 0, z = 0}
    local list = {{x = 0, y = 0, z = 0, id = "me"}, {x = 30, y = 0, z = 0, id = "far"}, {x = 5, y = 0, z = 5, id = "near"}, {x = 0/0, y = 0, z = 0, id = "nan"}}
    local c, d = CM.closest(me, list)
    eq(c.id, "near"); near(d, math.sqrt(50), 1e-9)
    eq(CM.closest(me, list, 4), nil, "nothing within 4 studs")
    eq(CM.closest(me, {}), nil); eq(CM.closest(nil, list), nil); eq(CM.closest(me, nil), nil)
    eq(CM.distance({x = 1, y = 2, z = 3}, {x = 1, y = 2}), nil)
end)

test("combat math: side toward the target uses the camera's right vector", function()
    local me, right = {x = 0, y = 0, z = 0}, {x = 1, y = 0, z = 0}
    eq(CM.sideToward(me, right, {x = 10, y = 0, z = 3}), "Right")
    eq(CM.sideToward(me, right, {x = -10, y = 0, z = -3}), "Left")
    eq(CM.sideToward(me, right, {x = 0, y = 0, z = 10}), nil, "dead ahead / behind has no side")
    eq(CM.sideToward(me, right, {x = 10, y = 99, z = 0}), "Right", "height is ignored")
    local rotated = {x = 0, y = 0, z = 1}                       -- camera turned: right now points along +Z
    eq(CM.sideToward(me, rotated, {x = 0, y = 0, z = 8}), "Right"); eq(CM.sideToward(me, rotated, {x = 8, y = 0, z = 0}), nil)
    eq(CM.sideToward(me, {x = 0, y = 5, z = 0}, {x = 3, y = 0, z = 3}), nil, "degenerate right vector")
    eq(CM.sideToward(me, right, me), nil, "target on top of me")
    eq(CM.sideToward(nil, right, me), nil)
end)

test("combat math: facing / shouldBlock only block what can be blocked", function()
    local me, look = {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = -1}          -- I look toward -Z
    local front = {x = 0, y = 0, z = -6}                                      -- attacker in front of me ...
    local aimedAtMe = {x = 0, y = 0, z = 1}                                   -- ... looking back toward me (+Z)
    assert(CM.shouldBlock(me, look, front, aimedAtMe, 14, 60), "front + aimed + in range must block")
    assert(not CM.shouldBlock(me, look, front, aimedAtMe, 4, 60), "out of range")
    assert(not CM.shouldBlock(me, look, front, {x = 0, y = 0, z = -1}, 14, 60), "attacker looks away")
    assert(not CM.shouldBlock(me, look, front, {x = 1, y = 0, z = 0}, 14, 60), "attacker aims sideways")
    assert(CM.shouldBlock(me, look, front, {x = 0.5, y = 0, z = 1}, 14, 60), "within the aim cone")
    local behind = {x = 0, y = 0, z = 6}
    assert(not CM.shouldBlock(me, look, behind, {x = 0, y = 0, z = -1}, 14, 60), "from behind always connects: do not waste a block")
    assert(not CM.shouldBlock(me, look, front, aimedAtMe, nil, 60) and not CM.shouldBlock(nil, look, front, aimedAtMe, 14, 60))
    assert(not CM.facing(me, {x = 0, y = 5, z = 0}, front, 60), "vertical look vector has no heading")
end)

test("sandboxed script runs, records key events and virtual time", function()
    local ok, err = ex:run([[
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
        task.wait(0.04)
        vim:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
        print("tech sent at", os.clock())
    ]])
    assert(ok, err)
    eq(#ex.keys, 2); eq(ex.keys[1].key, "KeyCode.Q"); eq(ex.keys[2].t, 0.04)
    eq(ex.log[1], "tech sent at\t0.04")
end)

test("sandbox blocks io/os.execute/require of real libs", function()
    local ok1 = ex:run("return io.open('x')")
    local ok2 = ex:run("return os.execute('true')")
    eq(ok1, false); eq(ok2, false)
end)

print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
