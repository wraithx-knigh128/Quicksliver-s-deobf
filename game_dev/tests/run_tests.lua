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
local BS = ex:require("block_state.lua")
local BP = ex:require("block_predict.lua")
local BI = ex:require("block_info.lua")
local KP = ex:require("kyoto_plan.lua")
local BSense = ex:require("block_sense.lua")
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
    eq(bad.auto, "global"); eq(bad.side, "Behind")
    eq(CO.sanitize({side = "Left"}).side, "Left"); eq(CO.sanitize({side = "Behind"}).side, "Behind"); eq(CO.sanitize({side = "Toward"}).side, "Toward")
    eq(CO.sanitize({side = "Closest"}).side, "Toward", "the old name 'Closest' means 'Toward'")
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

test("block state: one hit = press after the delay, release shortly after the attack ends", function()
    local b = BS.new({grace = 0.15, maxHold = 1.0, minHold = 0.12})
    b:threat(0, 0.1, 0.4)
    eq(b:tick(0.05), nil, "too early to press")
    eq(b:tick(0.1), "press")
    eq(b:tick(0.3), nil, "still holding during the attack")
    eq(b:tick(0.64), nil, "attack ends at 0.5, grace until 0.65")
    eq(b:tick(0.65), "release")
    eq(b:tick(0.7), nil, "idle again")
end)

test("block state: every hit of a combo is blocked, with no gap, but never past maxHold", function()
    local b = BS.new({grace = 0.15, maxHold = 1.0, minHold = 0.12})
    b:threat(0, 0.1, 0.3)                                   -- hit 1
    eq(b:tick(0.1), "press")
    b:threat(0.35, 0.1, 0.3)                                -- hit 2 arrives while still blocking
    b:threat(0.7, 0.1, 0.3)                                 -- hit 3
    eq(b:tick(0.9), nil, "still holding through the combo")
    eq(b:tick(1.0), nil)
    eq(b:tick(1.09), nil, "cap is holdStart(0.1) + maxHold(1.0) = 1.1")
    eq(b:tick(1.1), "release")
    b:threat(1.12, 0.05, 0.3)                               -- the combo goes on: block again right away
    eq(b:tick(1.15), nil, "not before the delay")
    eq(b:tick(1.18), "press")
end)

test("block state: even one very long attack is capped at maxHold", function()
    local b = BS.new({grace = 0.15, maxHold = 1.0, minHold = 0.12})
    b:threat(0, 0, 5)                                       -- a 5 s animation (e.g. a stuck / looping attack track)
    eq(b:tick(0), "press")
    eq(b:tick(0.99), nil)
    eq(b:tick(1.0), "release", "never stuck blocking: released at maxHold")
    local c = BS.new({grace = 0.15, maxHold = 0.05, minHold = 0.12})     -- a silly config must not break the order
    c:threat(0, 0, 0.1)
    eq(c:tick(0), "press")
    eq(c:tick(0.12), "release", "maxHold can never be shorter than minHold")
end)

test("block state: letting go when they stop attacking", function()
    local b = BS.new({grace = 0.2, maxHold = 2.0, minHold = 0.12})
    b:threat(0, 0, 0.3)
    eq(b:tick(0), "press")
    eq(b:tick(0.49), nil)
    eq(b:tick(0.5), "release", "0.3 attack + 0.2 grace")
    local b2 = BS.new({grace = 0, maxHold = 2.0, minHold = 0.3})
    b2:threat(0, 0, 0.05)
    eq(b2:tick(0), "press")
    eq(b2:tick(0.29), nil, "never shorter than minHold")
    eq(b2:tick(0.3), "release")
end)

test("block state: punching drops the block at once and pauses re-blocking", function()
    local b = BS.new({grace = 0.15, maxHold = 1.0, minHold = 0.12, punchPause = 0.4})
    b:threat(0, 0, 0.5)
    eq(b:tick(0), "press")
    eq(b:punch(0.2), "release", "you hit M1 while blocking -> unblock immediately")
    eq(b:tick(0.25), nil)
    b:threat(0.3, 0, 0.2)
    eq(b:tick(0.3), nil, "inside the lockout the block cannot come up")
    eq(b:tick(0.55), nil, "an attack that is over before the lockout ends cannot be blocked: nothing happens")
    b:threat(0.61, 0, 0.3)
    eq(b:tick(0.61), "press", "after the pause it blocks again")
    local c = BS.new({punchPause = 0.4})
    c:threat(0, 0.2, 0.3)
    eq(c:punch(0.1), nil, "nothing to release yet")
    eq(c:tick(0.2), nil, "a block that was only scheduled is cancelled by the punch")
end)

test("block state: a hit that lands AFTER your punch lockout is still blocked (press waits for the lockout)", function()
    local b = BS.new({grace = 0.15, maxHold = 1.0, minHold = 0.12, punchPause = 0.22})
    eq(b:punch(1.0), nil)                                            -- you throw an M1 at t = 1.0; lockout until 1.22
    b:threat(1.05, 0.05, 0.4)                                        -- their attack starts now and lasts until 1.5
    eq(b:tick(1.1), nil, "not before the lockout is over")
    eq(b:tick(1.21), nil)
    eq(b:tick(1.23), "press", "as soon as the lockout is over F goes down")
    eq(b:tick(1.6), nil, "still down: their attack ends at 1.45 and the grace is 0.15 (release at 1.65)")
    eq(b:tick(1.66), "release", "and it is let go after their attack, not later than that")
    local c = BS.new({punchPause = 0.22, grace = 0.1, minHold = 0.1})
    c:punch(0)
    c:threat(0.05, 0, 0.1)                                           -- over at 0.15, before the lockout (0.22) ends
    eq(c:tick(0.3), nil, "nothing to block any more")
    local d = BS.new({punchPause = 0.22, grace = 0.1, minHold = 0.1})
    d:punch(0)
    d:threat(0.05, 0.3, 0)                                           -- lands at 0.35: after the lockout
    eq(d:tick(0.34), nil, "it was due at 0.35: not earlier")
    eq(d:tick(0.36), "press", "and not later than it was due (the lockout was over long before)")
end)

test("block state: several attacks before the press, bad input, reset", function()
    local b = BS.new({grace = 0.1, maxHold = 1.0, minHold = 0.1})
    b:threat(0, 0.3, 0.2)
    b:threat(0.05, 0.05, 0.4)                               -- sooner and longer: wins
    eq(b:tick(0.09), nil); eq(b:tick(0.1), "press")
    eq(b:tick(0.58), nil, "release is at 0.05 + 0.05 + 0.4 + 0.1 = 0.6 (the later attack, merged)")
    b:threat(nil, 1, 1); b:threat("x", 1, 1)               -- garbage is ignored
    eq(b:tick(0.59), nil, "garbage threats changed nothing")
    eq(b:reset(), "release")
    eq(b:reset(), nil)
    eq(b:tick(5), nil)
end)

test("block predict: learns the hit offset of an animation from the damage that follows it", function()
    local p = BP.new()
    eq(p:offset("a"), nil)
    p:swing("E", "a", 10.00, 0.4); eq(p:damage(10.22) ~= nil, true)                 -- hit 0.22 s after the swing started
    eq(p:offset("a"), nil, "one sample is not enough")
    p:swing("E", "a", 20.00, 0.4); p:damage(20.24)
    local off, spread, n = p:offset("a")
    near(off, 0.22 + 0.3 * (0.24 - 0.22), 1e-9); eq(n, 2); assert(spread > 0)
    for i = 1, 20 do p:swing("E", "a", 30 + i * 3, 0.4); p:damage(30 + i * 3 + 0.25) end
    near(p:offset("a"), 0.25, 0.01, "converges on the true offset")
    eq(select(1, p:stats()), 1)
end)

test("block predict: damage is attributed to the swing that fits, outliers and old swings are ignored", function()
    local p = BP.new()
    for i = 1, 5 do p:swing("E", "slow", i * 4, 0.5); p:damage(i * 4 + 0.40) end      -- slow move: ~0.40 s
    for i = 1, 5 do p:swing("E", "fast", 40 + i * 4, 0.3); p:damage(40 + i * 4 + 0.15) end
    -- both swings are in flight; the damage 0.41 s after "slow" started and 0.16 s after "fast" must go to the better fit
    p:swing("E", "slow", 100.00, 0.5); p:swing("F", "fast", 100.25, 0.3)
    local id = p:damage(100.41)                                                       -- slow at 0.41, fast at 0.16
    assert(id == "slow" or id == "fast", "attributed to something")
    local before = select(3, p:offset("fast"))
    p:swing("E", "fast", 200, 0.3)
    eq(p:damage(201.9), nil, "1.9 s after the swing is too late to be its hit")
    eq(p:damage(200.0), nil, "damage at the same instant (0 s) is not a hit from that swing")
    p:swing("E", "fast", 300, 0.3); p:damage(300.9)                                   -- an ult / poison tick: 0.9 s, a big outlier
    eq(select(3, p:offset("fast")), before, "an outlier must not move a well-known animation")
    eq(p:damage("x"), nil)
end)

test("block predict: remembers which animation follows which (a chain) and how long after", function()
    local p = BP.new()
    for round = 0, 3 do
        local t = round * 10
        p:swing("E", "m1a", t, 0.3); p:swing("E", "m1b", t + 0.30, 0.3); p:swing("E", "m1c", t + 0.62, 0.3)
    end
    local nid, dt, n = p:next("m1a")
    eq(nid, "m1b"); near(dt, 0.30, 0.01); assert(n >= 3)
    eq(p:next("m1b"), "m1c"); eq(p:next("m1c"), nil, "the next round starts 9 s later: not a chain")
    eq(p:next("unknown"), nil)
    local q = BP.new(); q:swing("E", "a", 0, 0.3); q:swing("E", "b", 0.3, 0.3)
    eq(q:next("a"), nil, "seen only once: not trusted")
    q:swing("X", "a", 5, 0.3); q:swing("Y", "b", 5.3, 0.3)
    eq(q:next("a"), nil, "different enemies do not form a chain")
end)

test("block predict: export / import round-trips and import sanitises garbage", function()
    local p = BP.new()
    for i = 1, 3 do p:swing("E", "a", i * 5, 0.4); p:damage(i * 5 + 0.2) end
    local data = p:export()
    local q = BP.new(); q:import(data)
    near(q:offset("a"), p:offset("a"), 1e-9); near(q:length("a"), 0.4, 1e-9)
    local bad = BP.new()
    bad:import({a = {n = 99999, offset = 99, spread = -3, length = "x"}, [5] = {n = 1}, b = "x", [string.rep("z", 500)] = {n = 2, offset = 0.2}, c = {n = 3, offset = 0/0}})
    local o, sp, n = bad:offset("a")
    near(o, 1.3, 1e-9); eq(sp, 0); eq(n, 500)
    assert(bad:offset("b") == nil and bad:offset(5) == nil and bad:offset(string.rep("z", 500)) == nil, "garbage entries dropped")
    near(bad:offset("c"), 0.2, 1e-9, "NaN offset replaced by a sane default")
    bad:import("not a table"); bad:import(nil)
    p:forget(); eq(p:offset("a"), nil); eq(select(2, p:stats()), 0)
    local big = {}
    for i = 1, 300 do big["id" .. i] = {n = 3, offset = 0.2} end
    local r = BP.new(); r:import(big)
    local cnt = 0
    for _ in pairs(r:export()) do cnt = cnt + 1 end
    assert(cnt <= 120, "never keep more than 120 animations")
end)

test("block predict: attacks that hit through a held block are remembered as unblockable (2 times)", function()
    local p = BP.new()
    eq(p:isPierce("g"), false, "unknown animation is not unblockable")
    eq(p:pierced("g"), 1)
    eq(p:isPierce("g"), false, "one sighting is not enough")
    eq(p:pierced("g"), 2)
    eq(p:isPierce("g"), true)
    eq(p:isPierce("other"), false)
    local learned, hits, piercing = p:stats()
    eq(piercing, 1, "stats count unblockable animations")
    eq(p:pierced(42), 0, "non-string id ignored"); eq(p:pierced(""), 0)
    for _ = 1, 100 do p:pierced("g") end
    local q = BP.new(); q:import(p:export())
    eq(q:isPierce("g"), true, "export / import keeps it")
    local bad = BP.new(); bad:import({x = {n = 0, pierce = 99999}, y = {n = 1, offset = 0.2, pierce = "no"}, z = {n = 0, pierce = -5}})
    eq(bad:isPierce("x"), true); eq(bad:isPierce("y"), false); eq(bad:isPierce("z"), false)
    p:forget(); eq(p:isPierce("g"), false, "forget wipes it")
end)

test("combo options: only the adjustments a combo needs are offered", function()
    local kinds = {M1 = "m1", JUMP_M1 = "m1", JUMP = "jump", Q = "dash", FRONTDASH = "dash", SIDEDASH = "dash", BACKDASH = "dash", Flowing = "move", Lethal = "move"}
    local function kindOf(tok) return kinds[tok] end
    local n = CO.needs({"M1", "M1", "M1"}, kindOf)
    eq(n.m1, true); eq(n.dash, false); eq(n.move, false); eq(n.jump, false); eq(n.side, false); eq(n.dependent, false, "M1 gaps do not wait for a cue")
    n = CO.needs({"Flowing", "SIDEDASH", "Lethal"}, kindOf)
    eq(n.move, true); eq(n.dash, true); eq(n.side, true); eq(n.dependent, true); eq(n.m1, false); eq(n.choosable, true)
    eq(n.played, 3)
    n = CO.needs({"M1", "SIDEDASH"}, kindOf)
    eq(n.dash, false, "the wait after the LAST step changes nothing"); eq(n.side, true, "but a side dash still needs the side choice")
    eq(n.m1, true); eq(n.dependent, false); eq(n.choosable, false)
    n = CO.needs({"JUMP", "M1", "Unmapped", "M1"}, kindOf)
    eq(n.jump, true); eq(n.m1, true); eq(n.played, 3, "an unplayable step is not counted"); eq(n.choosable, true)
    n = CO.needs({"SIDEDASH"}, kindOf)
    eq(n.side, true); eq(n.m1, false); eq(n.dash, false); eq(n.played, 1)
    n = CO.needs({"Unmapped", "Other"}, kindOf)
    eq(n.played, 0); eq(n.m1, false); eq(n.dependent, false)
    eq(CO.needs(nil, kindOf).played, 0); eq(CO.needs({}, kindOf).m1, false)
end)

test("combat math: assess looks ahead (running attackers, snapping M1s) and says why it will not block", function()
    local me, look = {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = -1}
    local function A(o)
        local base = {mp = me, ml = look, tp = {x = 0, y = 0, z = -6}, tl = {x = 0, y = 0, z = 1}, range = 16, aim = 90}
        for k, v in pairs(o or {}) do base[k] = v end
        return CM.assess(base)
    end
    eq(A(), "block")
    eq(A({tp = {x = 0, y = 0, z = -30}}), "far")
    eq(A({tp = {x = 0, y = 0, z = -30}, tv = {x = 0, y = 0, z = 60}, hitIn = 0.3}), "block", "30 studs away but dashing in: he is 12 studs away when it lands")
    eq(A({tp = {x = 0, y = 0, z = -30}, tv = {x = 0, y = 0, z = 20}, hitIn = 0.2}), "far", "too slow to arrive")
    eq(A({tl = {x = 0, y = 0, z = -1}}), "unaimed", "looking away, 6 studs: the swing is for someone else")
    eq(A({tp = {x = 0, y = 0, z = -3}, tl = {x = 0, y = 0, z = -1}}), "block", "right next to me the aim test is skipped (M1s snap on)")
    eq(A({tl = {x = 1, y = 0, z = 0.1}}), "block", "90 degrees to the side is inside a 90 degree half-cone")
    eq(A({tl = {x = 1, y = 0, z = 0.1}, aim = 60}), "unaimed", "but not inside a 60 degree one")
    eq(A({tl = {x = 0, y = 0, z = -1}, tv = {x = 0, y = 0, z = 14}}), "block", "running at me counts as aimed at me")
    eq(A({tl = {x = 0, y = 0, z = -1}, tv = {x = 0, y = 0, z = -14}}), "unaimed", "running away does not")
    eq(A({tp = {x = 0, y = 0, z = 6}, tl = {x = 0, y = 0, z = -1}}), "behind", "from behind: a block would be wasted")
    eq(A({tp = {x = 0, y = 0, z = 10}, tl = {x = 0, y = 0, z = -1}, tv = {x = 0, y = 0, z = -60}}), "behind", "running at me from behind: he will go THROUGH me, not hit me from the front")
    eq(A({tp = {x = 5, y = 0, z = -5}, tl = {x = -1, y = 0, z = 1}}), "block", "diagonal in front")
    eq(A({mv = {x = 0, y = 0, z = -30}, tp = {x = 0, y = 0, z = -25}, tl = {x = 0, y = 0, z = 1}, hitIn = 0.3}), "block", "I run toward him")
    eq(CM.assess({mp = me, ml = look, tp = {x = 0, y = 0, z = -6}, tl = {x = 0, y = 0, z = 1}, aim = 90}), "unknown", "no range")
    eq(CM.assess(nil), "unknown"); eq(A({mp = {x = 1}}), "unknown")
    eq(A({hitIn = 99, tp = {x = 0, y = 0, z = -20}, tv = {x = 0, y = 0, z = 20}}), "block", "hitIn is capped at 1 s (he arrives in 1 s; 99 s would put him miles away)")
end)

test("combat math: orbitStep goes round the player towards his back", function()
    local him, look = {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 1}         -- he looks toward +z
    local st = CM.orbitStep({x = 0, y = 0, z = 6}, him, look)               -- I am right in front of him
    near(st.angle, 0, 1e-6); eq(st.behind, false); near(st.radius, 6, 1e-9)
    assert(math.abs(st.dz) < 0.2 and math.abs(st.dx) > 0.9, "in front: dash sideways (round him), not at him")
    local sr = CM.orbitStep({x = 0, y = 0, z = 6}, him, look, {x = 1, y = 0, z = 0})
    assert(sr.dx > 0.9, "in front, camera right is +x: start to my right")
    local sl = CM.orbitStep({x = 0, y = 0, z = 6}, him, look, {x = -1, y = 0, z = 0})
    assert(sl.dx < -0.9, "...and to my left when the camera says so")
    local side = CM.orbitStep({x = 6, y = 0, z = 0}, him, look)              -- at his side (90 degrees)
    near(side.angle, 90, 1e-6); eq(side.behind, false)
    assert(side.dz < -0.9, "at his right side the next step is toward his back (-z)")
    local back = CM.orbitStep({x = 0, y = 0, z = -6}, him, look)
    near(back.angle, 180, 1e-6); eq(back.behind, true)
    eq(CM.orbitStep({x = 4, y = 0, z = -5}, him, look).behind, true, "angle ~141 degrees counts as behind")
    local far = CM.orbitStep({x = 20, y = 0, z = 0}, him, look)             -- far away: also close in
    assert(far.dx < -0.2 and far.dz < -0.2, "far away: go round AND come closer")
    local near2 = CM.orbitStep({x = 2, y = 0, z = 0}, him, look)
    assert(near2.dx > 0 or near2.dz < 0, "very close: do not run into him")
    eq(CM.orbitStep({x = 0, y = 0, z = 0}, him, look), nil, "on top of him: no direction")
    eq(CM.orbitStep(nil, him, look), nil); eq(CM.orbitStep({x = 1, y = 0, z = 1}, him, {x = 0, y = 5, z = 0}), nil, "vertical look")
    -- walk the whole thing: repeated 12-stud dashes along the suggested direction reach his back within 3 dashes (any start, radius 5..9)
    for _, start in ipairs({{0, 6}, {6, 0}, {-6, 0}, {4, 4}, {-5, 5}, {0, 9}, {7, 3}}) do
        local pos, dashes = {x = start[1], y = 0, z = start[2]}, 0
        while dashes < 4 do
            local s2 = CM.orbitStep(pos, him, look)
            if s2.behind then break end
            local len = 12
            pos = {x = pos.x + s2.dx * len, y = 0, z = pos.z + s2.dz * len}
            local r = math.sqrt(pos.x * pos.x + pos.z * pos.z)
            if r > 7 then pos.x, pos.z = pos.x * 6 / r, pos.z * 6 / r end   -- dashes stop at the player: keep a circle of radius ~6
            dashes = dashes + 1
        end
        assert(dashes <= 3, "from " .. start[1] .. "," .. start[2] .. " it took " .. dashes .. " dashes to get behind")
    end
end)

test("combat math: sideKey picks the SIDE dash key (A or D) that goes furthest toward a direction", function()
    local right = {x = 1, y = 0, z = 0}                                   -- the camera's right is +x
    local k, share = CM.sideKey(1, 0, right); eq(k, "D"); near(share, 1, 1e-9)
    k, share = CM.sideKey(-1, 0, right); eq(k, "A"); near(share, -1, 1e-9)
    k, share = CM.sideKey(0.6, -0.8, right); eq(k, "D"); near(share, 0.6, 1e-9)
    k, share = CM.sideKey(-0.2, 0.9, right); eq(k, "A"); assert(share < 0 and share > -0.3, "mostly forward / back: poor for a side dash")
    k, share = CM.sideKey(0, 1, right); eq(k, "D", "no sideways part at all: D by convention"); near(share, 0, 1e-9)
    eq((CM.sideKey(3, 4, {x = 0, y = 0, z = 2})), "D", "any length of vectors works"); eq((CM.sideKey(3, -4, {x = 0, y = 0, z = 2})), "A")
    eq(CM.sideKey(0, 0, right), nil); eq(CM.sideKey(1, 0, {x = 0, y = 1, z = 0}), nil, "camera right must have a horizontal part")
    eq(CM.sideKey(1, 0, nil), nil); eq(CM.sideKey("x", 0, right), nil)
    eq(CM.BEHIND_ANGLE, 105)
    eq(CM.orbitStep({x = 5.5, y = 0, z = -1.2}, {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 1}).behind, false, "about 102 degrees: not yet")
    eq(CM.orbitStep({x = 5, y = 0, z = -3}, {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 1}).behind, true, "~121 degrees: behind")
    eq(CM.orbitStep({x = 5, y = 0, z = -2}, {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 1}).behind, true, "~112 degrees: already past the 90 degree edge of his block (+ a margin)")
end)

test("block info: which moves ignore block (names only, never from the game)", function()
    eq((BI.classify("Flowing Water")), "guardbreak"); eq((BI.classify("flowing_water")), "guardbreak", "case / underscores ignored")
    eq((BI.classify("Hunter's Grasp")), "unblockable"); eq((BI.classify("HUNTERS_GRASP")), "unblockable")
    eq((BI.classify("Lethal Whirlwind Stream")), "disputed")
    eq((BI.classify("Homerun")), "guardbreak"); eq((BI.classify("Grand Slam")), "guardbreak"); eq((BI.classify("FoulBall")), "guardbreak")
    eq((BI.classify("Downslam")), "unblockable"); eq((BI.classify("Normal Punch")), "unblockable")
    eq((BI.classify("Pinpoint Cut")), "blockable"); eq((BI.classify("Whirlwind Drop")), "chip")
    eq((BI.classify("Ragdoll Cancel")), "unblockable", "longest match wins over a shorter one")
    eq((BI.classify("M1_3")), nil, "ordinary attacks are not listed"); eq((BI.classify("")), nil); eq((BI.classify(42)), nil); eq((BI.classify(nil)), nil)
    local kind, entry = BI.classify("Mini Uppercut")
    eq(kind, "unblockable"); eq(entry.name, "Uppercut"); eq(entry.who, "Universal")
    eq(BI.ignoresBlock("unblockable"), true); eq(BI.ignoresBlock("guardbreak"), true)
    eq(BI.ignoresBlock("chip"), false); eq(BI.ignoresBlock("blockable"), false); eq(BI.ignoresBlock("disputed"), false); eq(BI.ignoresBlock(nil), false)
    for _, e in ipairs(BI.entries) do
        assert(type(e[1]) == "string" and #e == 4 and (e[4] == "medium" or e[4] == "low"), "entry shape: " .. tostring(e[1]))
        assert(BI.classify(e[1]) ~= nil, "every listed name must classify: " .. e[1])
    end
end)

test("kyoto plan: Flowing Water -> side dash -> Lethal Whirlwind Stream -> whirlwind dash -> M1s -> instant twisted", function()
    local steps, gaps, o = KP.build({})
    local expect = {"FLOWING_WATER", "SIDEDASH", "LETHAL_WHIRLWIND_STREAM", "FRONTDASH", "M1", "M1", "M1", "BACKDASH", "FRONTDASH"}
    eq(#steps, #expect, "default plan length")
    for i, t in ipairs(expect) do eq(steps[i], t, "step " .. i) end
    near(gaps[1], 0.30, 1e-9, "wait after Flowing Water"); near(gaps[2], KP.CATCH, 1e-9); near(gaps[3], KP.WHIRL, 1e-9, "whirlwind dash as early as possible")
    near(gaps[4], KP.LAND, 1e-9); eq(gaps[5], nil, "M1 gaps are the engine's own"); near(gaps[8], KP.STEP_BACK, 1e-9)
    eq(o.side, "Toward")
    for n = 1, 3 do
        local s2 = KP.build({m1 = n})
        local count = 0
        for _, t in ipairs(s2) do if t == "M1" then count = count + 1 end end
        eq(count, n, n .. " M1 option")
    end
    local noWhirl = KP.build({whirl = false})
    eq(table.concat(noWhirl, ","), "FLOWING_WATER,SIDEDASH,LETHAL_WHIRLWIND_STREAM,M1,M1,M1,BACKDASH,FRONTDASH")
    local noTwist, g3 = KP.build({twisted = false, m1 = 1})
    eq(table.concat(noTwist, ","), "FLOWING_WATER,SIDEDASH,LETHAL_WHIRLWIND_STREAM,FRONTDASH,M1")
    eq(g3[8], nil, "no step-back gap without the twisted dash")
    local bare = KP.build({whirl = false, twisted = false, m1 = 2})
    eq(table.concat(bare, ","), "FLOWING_WATER,SIDEDASH,LETHAL_WHIRLWIND_STREAM,M1,M1")
    local c = KP.clean({m1 = 99, wait = -5, whirl = "yes", twisted = 0, side = "Closest"})
    eq(c.m1, 3); near(c.wait, 0.05, 1e-9); eq(c.whirl, false, "only true counts"); eq(c.twisted, false); eq(c.side, "Toward", "old name")
    local d = KP.clean({m1 = 0, wait = 0/0, side = "Sideways"})
    eq(d.m1, 1); near(d.wait, 0.30, 1e-9, "NaN -> default"); eq(d.side, "Toward"); eq(d.whirl, true); eq(d.twisted, true)
    eq(KP.clean(nil).m1, 3); eq(KP.clean("junk").side, "Toward")
    eq(KP.clean({m1 = 2.9}).m1, 2, "floors")
end)

test("block state: a combo's next hit keeps the block up (grace override)", function()
    local b = BS.new({grace = 0.15, maxHold = 2.0, minHold = 0.1})
    b:threat(0, 0, 0.3, 0.5)                                         -- another hit is coming: stay up 0.5 s after this one
    eq(b:tick(0), "press")
    eq(b:tick(0.7), nil, "0.3 + 0.5 = 0.8: still blocking at 0.7 (the normal grace would have ended it at 0.45)")
    eq(b:tick(0.81), "release")
    local c = BS.new({grace = 0.15, maxHold = 2.0, minHold = 0.1})
    c:threat(0, 0, 0.3)
    eq(c:tick(0), "press"); eq(c:tick(0.44), nil); eq(c:tick(0.46), "release", "without the override: the normal 0.15 s")
    local d = BS.new({grace = 0.15, maxHold = 0.6, minHold = 0.1})
    d:threat(0, 0, 0.3, 5)
    eq(d:tick(0), "press"); eq(d:tick(0.59), nil); eq(d:tick(0.61), "release", "the longest hold still caps it")
    local e = BS.new({grace = 0.15, maxHold = 2.0, minHold = 0.1})
    e:threat(0, 0, 0.3, "x"); eq(e:tick(0), "press"); eq(e:tick(0.46), "release", "a non-number override is ignored")
    local f = BS.new({grace = 0.15, maxHold = 2.0, minHold = 0.1})
    f:threat(0, 0, 0.3, -3); eq(f:tick(0), "press"); eq(f:tick(0.31), "release", "negative becomes 0")
end)

test("combat math: rushing = he is closing in fast, and when he is in striking range", function()
    local me = {x = 0, y = 0, z = 0}
    local function R(tp, tv, o) return CM.rushing(me, tp, tv, o) end
    near(R({x = 0, y = 0, z = -14}, {x = 0, y = 0, z = 80}, {range = 20}), (14 - 4.5) / 80, 1e-9, "14 studs away at 80 studs/s")
    eq(R({x = 0, y = 0, z = -14}, {x = 0, y = 0, z = 80}), nil, "default range is 12")
    near(R({x = 0, y = 0, z = -10}, {x = 0, y = 0, z = 50}), 5.5 / 50, 1e-9)
    eq(R({x = 0, y = 0, z = -3}, {x = 0, y = 0, z = 30}), 0, "already in striking range and still coming: 0 s")
    eq(R({x = 0, y = 0, z = -10}, {x = 0, y = 0, z = 6}), nil, "too slow (walking)")
    eq(R({x = 0, y = 0, z = -10}, {x = 0, y = 0, z = -40}), nil, "running away")
    eq(R({x = 0, y = 0, z = -10}, {x = 40, y = 0, z = 0}), nil, "running past (sideways)")
    assert(R({x = 0, y = 0, z = -10}, {x = 20, y = 0, z = 40}) ~= nil, "diagonal but mostly toward me")
    eq(R({x = 0, y = 0, z = -10}, {x = 0, y = 0, z = 12}, {speed = 20}), nil, "custom speed threshold")
    eq(R({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 50}), nil, "on top of me: no direction")
    eq(CM.rushing(nil, {x = 0, y = 0, z = -5}, {x = 0, y = 0, z = 50}), nil); eq(R({x = 0, y = 0, z = -5}, nil), nil)
    near(R({x = 0, y = 90, z = -10}, {x = 0, y = 90, z = 50}), 5.5 / 50, 1e-9, "height is ignored")
end)

test("block sense: learns what blocking looks like and says whether the block is up", function()
    local S = BSense.new()
    local function snap(ws, attrs, tracks) return {ws = ws, attrs = attrs or {}, tracks = tracks or {}} end
    eq(S:ready(), false); eq(S:isUp(snap(16)), nil, "does not know yet")
    S:observe(snap(16, {}, {idle = true}), snap(6, {}, {idle = true, blockAnim = true}))
    eq(S:ready(), false, "one sample is not enough")
    eq(S:observe(snap(16, {}, {idle = true, walk = true}), snap(6, {Hit = 1}, {idle = true, blockAnim = true, hurt = true})), true,
        "the second sample agrees on ws:6 and the block animation; the hurt animation was a coincidence")
    eq(S:isUp(snap(6)), true); eq(S:isUp(snap(16, {}, {blockAnim = true})), true); eq(S:isUp(snap(16, {}, {idle = true})), false)
    assert(S:describe():find("ws:6") and S:describe():find("anim:blockAnim") and not S:describe():find("hurt"), S:describe())
    local out = S:export()
    local T = BSense.new(); T:import(out)
    eq(T:ready(), true); eq(T:isUp(snap(6)), true); eq(T:isUp(snap(16)), false)
    S:forget(); eq(S:ready(), false); eq(S:isUp(snap(6)), nil)
    -- a press that did not take (nothing new) teaches nothing, disagreeing samples start over
    local U = BSense.new()
    U:observe(snap(16), snap(16)); U:observe(snap(16), snap(16)); eq(U:ready(), false)
    U:observe(snap(16), snap(6)); U:observe(snap(16), snap(9, {}, {x = true}))
    eq(U:ready(), false, "ws:6 vs ws:9 + anim: nothing in common")
    U:observe(snap(16), snap(9)); eq(U:ready(), true, "the newest two agree on ws:9")
    -- attributes
    local V = BSense.new()
    V:observe(snap(16, {Blocking = false}), snap(16, {Blocking = true})); V:observe(snap(16, {Blocking = false}), snap(16, {Blocking = true}))
    eq(V:ready(), true); eq(V:isUp(snap(16, {Blocking = true})), true); eq(V:isUp(snap(16, {Blocking = false})), false)
    assert(V:describe():find("attr:Blocking=true"))
    -- garbage
    local W = BSense.new()
    eq(W:observe(nil, nil), false); eq(W:observe("x", 5), false); W:import("junk"); W:import({5, {}, string.rep("x", 500), "bad:thing", "ws:6"})
    eq(W:ready(), true); eq(W:isUp(snap(6)), true); eq(#W:export(), 1, "only the valid feature is kept")
    local X = BSense.new()
    local many = {}
    for i = 1, 40 do many[i] = "anim:id" .. i end
    X:import(many); eq(#X:export(), 12, "at most 12 features")
    eq(BSense.features({ws = 0/0}).x, nil); eq(next(BSense.features({ws = 0/0})), nil, "NaN walk speed is not a feature")
end)

test("assist: start with M1 - what you do yourself and what the script plays", function()
    eq(Assist.leadingM1({"M1", "M1", "M1", "SIDEDASH", "FLOWING_WATER"}), 3)
    eq(Assist.leadingM1({"FLOWING_WATER", "M1"}), 0, "only the FIRST steps count"); eq(Assist.leadingM1({"M1", "SIDEDASH", "M1"}), 1)
    eq(Assist.leadingM1({}), 0); eq(Assist.leadingM1(nil), 0); eq(Assist.leadingM1({"M1", "M1"}), 2)
    local rest, k = Assist.afterM1({"M1", "M1", "M1", "SIDEDASH", "FLOWING_WATER"})
    eq(k, 3); eq(table.concat(rest, ","), "SIDEDASH,FLOWING_WATER")
    rest, k = Assist.afterM1({"FLOWING_WATER", "SIDEDASH", "LETHAL"})
    eq(k, 0); eq(table.concat(rest, ","), "FLOWING_WATER,SIDEDASH,LETHAL", "no leading M1: your M1 is only the start button, ALL steps are played")
    rest, k = Assist.afterM1({"M1", "M1"}); eq(rest, nil, "nothing after your M1s"); eq(k, 2)
    rest = Assist.afterM1({}); eq(rest, nil); rest = Assist.afterM1("x"); eq(rest, nil)
    eq(Assist.m1Cap({"M1", "M1", "M1", "SIDEDASH"}, 3), 3); eq(Assist.m1Cap({"M1", "SIDEDASH"}, 3), 1, "the tech's own M1 count wins")
    eq(Assist.m1Cap({"FLOWING_WATER"}, 3), 3); eq(Assist.m1Cap({"FLOWING_WATER"}, 2), 2); eq(Assist.m1Cap({"FLOWING_WATER"}, 0), 3, "bad value -> 3"); eq(Assist.m1Cap({"FLOWING_WATER"}, nil), 3)
    eq(Assist.m1Count(nil, nil, 10, 0.8), 1); eq(Assist.m1Count(1, 10, 10.5, 0.8), 2); eq(Assist.m1Count(2, 10.5, 11.0, 0.8), 3)
    eq(Assist.m1Count(3, 11, 12.5, 0.8), 1, "a pause longer than the window starts a new count"); eq(Assist.m1Count("x", 1, 2, 0.8), 1)
    eq(Assist.m1Ready(0, 0, 1, 3, 0.35), false); eq(Assist.m1Ready(1, 10, 10.2, 3, 0.35), false, "still within the settle time")
    eq(Assist.m1Ready(1, 10, 10.35, 3, 0.35), true, "you stopped M1ing"); eq(Assist.m1Ready(3, 10, 10.0, 3, 0.35), true, "cap reached: go at once")
    eq(Assist.m1Ready(2, 10, 10.1, 2, 0.35), true); eq(Assist.m1Ready(nil, 1, 2, 3, 0.35), false); eq(Assist.m1Ready(1, "x", 2, 3, 0.35), false)
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
