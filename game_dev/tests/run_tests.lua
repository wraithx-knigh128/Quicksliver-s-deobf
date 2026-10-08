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
