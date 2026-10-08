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
