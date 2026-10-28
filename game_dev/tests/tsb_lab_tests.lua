-- Tech Lab scenarios in the simulated TSB arena (tests/tsb_sim.lua). Every check is about that simulated world, which only follows what the uploaded script says about
-- the game (remote layout, animation ids). Passing means "the code does what it claims in a world like that", never "it works in Strongest Battlegrounds".
local Sim = TSB_SIM
local failures, passes = {}, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures[#failures + 1] = msg end end
local function section(name) print("--- " .. name) end
local function near(a, b, tol) return math.abs(a - b) <= (tol or 0.01) end
local function fmt(p) return string.format("(%.1f, %.1f, %.1f)", p[1], p[2], p[3]) end

local UPPERCUT, FORWARD, SIDE_R, SIDE_L = "10503381238", "10479335397", "10480793962", "10480796021"
local FLOWING, LETHAL_ANIM, TWISTED, BLOCK, SLAM, SURF = "12273188754", "12296113986", "13294471966", "10471478869", "13532604085", "12309835105"

-- a fresh arena: me at (0,3,0) looking -Z, a rival 12 studs ahead, a lab with nothing switched on yet
local function arena(o)
    o = o or {}
    local sim = Sim.new(o)
    sim:addMe(o.mePos or {0, 3, 0})
    if o.rival ~= false then
        local _, char = sim:addEnemy("Rival", o.rivalPos or {0, 3, -12}, {look = o.rivalLook or {0, 3, 0}})
        sim.rival = char
    end
    local lab = sim:newLab()
    return sim, lab
end
local function clean(sim, name)
    local w = sim.W
    check(#w.thrown == 0, name .. ": members/types the real Roblox API rejects: " .. table.concat(w.thrown, " | "):sub(1, 500))
    check(#w.errors == 0, name .. ": errors inside handlers / threads: " .. table.concat(w.errors, " | "):sub(1, 500))
    check(not sim.logged, name .. ": the lab logged an error: " .. table.concat(sim.logged or {}, " | "):sub(1, 400))
    check(#sim:leftovers() == 0, name .. ": instances left behind: " .. table.concat(sim:leftovers(), ","))
end
local function dashes(sim, dir) return sim:count({goal = "KeyPress", key = "Q", dash = dir}) end
local function learnLag(sim, lab, n)                              -- send a few dashes so the lab can see how late my animations arrive
    for _ = 1, n or 3 do
        sim.dashReadyAt = {}
        lab:dash("W")
        sim:run(0.5)
    end
    lab.dashClock:reset()
    sim.dashReadyAt = {}
    sim:clearLog()
end


------------------------------------------------------------------------------------------------ the catalogue
section("catalogue")
do
    local sim, lab = arena()
    local Lab, TO, TM = sim.Lab, sim.TO, sim.TM
    local ids, groups = {}, {}
    for _, g in ipairs(Lab.GROUPS) do groups[g] = true end
    for _, d in ipairs(Lab.DEFS) do
        check(not ids[d.id], "duplicate tech id " .. d.id)
        ids[d.id] = true
        check(groups[d.group], d.id .. ": group " .. tostring(d.group) .. " is not listed")
        check(type(d.title) == "string" and #d.title > 0 and type(d.desc) == "string" and #d.desc > 10 and type(d.when) == "string", d.id .. ": needs title, desc, when")
        check(lab.byId[d.id] and (type(lab.byId[d.id].run) == "function" or d.poll or d.watches), d.id .. ": has no sequence")
        local keys = {}
        for _, od in ipairs(d.opts) do
            check(not keys[od.key], d.id .. ": duplicate option " .. od.key)
            keys[od.key] = true
            if od.kind == "number" then
                check(od.min <= od.default and od.default <= od.max, d.id .. "." .. od.key .. ": default " .. od.default .. " outside " .. od.min .. ".." .. od.max)
                check(od.step > 0 and od.min < od.max, d.id .. "." .. od.key .. ": bad step / range")
                local snapped = TO.clean({od}, {[od.key] = od.default})[od.key]
                check(near(snapped, od.default, 1e-6), d.id .. "." .. od.key .. ": the default " .. od.default .. " is not on its own step grid (" .. snapped .. ")")
            elseif od.kind == "choice" then
                local found = false
                for _, c in ipairs(od.choices) do found = found or c == od.default end
                check(found, d.id .. "." .. od.key .. ": default not among the choices")
            end
        end
        if d.manual and d.id ~= "hook" then check(keys.key, d.id .. ": manual tech without a key option") end
    end
    check(#Lab.DEFS == 33, "33 techs expected, got " .. #Lab.DEFS)
    check(TM and sim.TD, "modules loaded")
    clean(sim, "catalogue")
end

------------------------------------------------------------------------------------------------ Supa
section("Supa Tech")
do
    local sim, lab = arena()
    sim:run(0.1)
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(0.6)
    check(dashes(sim, "W") == 0, "supa off: nothing happens")
    lab:setEnabled("supa", true)
    sim.dashReadyAt = {}
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(0.2)
    check(sim:count({goal = "KeyPress"}) == 0, "supa waits its 320 ms before it dashes")
    sim:run(0.15)
    check(dashes(sim, "W") == 1, "supa dashes once the delay is over, got " .. dashes(sim, "W"))
    sim:run(0.6)
    -- the server ignores the second dash (the forward dash is on cooldown): the lab sends it anyway because Supa's own sequence does not ask the guard twice
    local p = sim:pos(sim.meChar)
    local r = sim:pos(sim.rival)
    -- the rival faces +Z (towards me, he is looking at (0,3,0)): his back is at -Z, 5 studs behind him
    check(near(p[1], 0, 0.6) and near(p[3], r[3] - 5, 0.6), "supa ends 5 studs behind his back " .. fmt(p) .. " vs rival " .. fmt(r))
    check(lab.techs.supa.stats.runs == 1 and lab.techs.supa.status:find("done"), "supa reports its run: " .. lab.techs.supa.status)
    sim:run(1.2)                                                      -- (Supa's own 1 s cooldown is over)
    sim:anim(sim.meChar, UPPERCUT, 0.5)       -- the forward dash is on cooldown (4.8 s) now: Supa must not start, and says why
    sim:run(0.6)
    check(lab.techs.supa.stats.runs == 1, "no second run while the forward dash is on cooldown")
    check(sim.statuses.supa and sim.statuses.supa:find("cooldown"), "the status explains the wait: " .. tostring(sim.statuses.supa))
    clean(sim, "supa")
end
do   -- the rival looks away from me: his back is on MY side of him
    local sim, lab = arena({rivalLook = {0, 3, -100}})
    lab:setEnabled("supa", true)
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(1.2)
    local p, r = sim:pos(sim.meChar), sim:pos(sim.rival)
    check(near(p[3], r[3] + 5, 0.6), "behind a man who looks away from me is 5 studs towards me: " .. fmt(p) .. " vs " .. fmt(r))
    clean(sim, "supa away")
end
do   -- nobody around: the run does not count and no dash is wasted
    local sim, lab = arena({rival = false})
    lab:setEnabled("supa", true)
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(0.8)
    check(dashes(sim, "W") == 0, "no target -> no dash")
    check(lab.techs.supa.stats.runs == 0 and lab.techs.supa.stats.aborts == 1, "no target is an abort, not a run")
    check(lab.techs.supa.status:find("no target"), "status: " .. lab.techs.supa.status)
    lab:setEnabled("slidem1", true)                                -- (acts at once, so only the master check itself can stop it)
    lab:setMaster(false)
    sim:anim(sim.meChar, SIDE_L, 0.3)
    sim:run(0.3)
    check(sim:count({goal = "LeftClick"}) == 0, "master off: even a tech that acts immediately stays quiet")
    lab:setMaster(true)
    lab:setMaster(false)
    sim:addEnemy("Late", {0, 3, -8})
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(0.8)
    check(dashes(sim, "W") == 0, "master switch off blocks every tech")
    clean(sim, "supa none")
end

------------------------------------------------------------------------------------------------ the engine itself
section("engine")
do
    local sim, lab = arena()
    lab:setEnabled("supa", true)
    sim.busy = true
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(0.8)
    check(dashes(sim, "W") == 0, "a running combo macro (busy) blocks triggered techs")
    sim.busy = false
    -- death in the middle of a run: the sequence stops, nothing is left behind
    sim.dashReadyAt = {}
    lab.dashClock:reset()
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(0.45)
    sim:kill(sim.meChar)
    sim:run(0.5)
    check(not lab.techs.supa.running, "death ends the run")
    check(lab.techs.supa.status:find("died") or lab.techs.supa.status:find("cancel"), "status says why: " .. lab.techs.supa.status)
    clean(sim, "death")
end
do
    local sim, lab = arena()
    lab:setEnabled("kyoto", true)
    sim:give(sim.mePlayer, "Lethal Whirlwind Stream")
    sim:anim(sim.meChar, FLOWING, 0.5)
    sim:run(0.5)
    check(lab.techs.kyoto.running, "kyoto is waiting for its 1.5 s")
    lab:cancelAll("panic")                                        -- Panic
    sim:run(1.5)
    check(sim:count({goal = "Console Move"}) == 0, "a cancelled tech never reaches its action")
    check(lab.techs.kyoto.status == "panic", "status: " .. lab.techs.kyoto.status)
    -- disabling mid-run cancels too
    sim:anim(sim.meChar, FLOWING, 0.5)
    sim:run(0.3)
    lab:setEnabled("kyoto", false)
    sim:run(1.6)
    check(sim:count({goal = "Console Move"}) == 0, "switching a tech off stops it")
    -- a respawn cancels
    lab:setEnabled("kyoto", true)
    sim:anim(sim.meChar, FLOWING, 0.5)
    sim:run(0.3)
    sim:respawn({0, 3, 0})
    sim:run(1.6)
    check(sim:count({goal = "Console Move"}) == 0, "a respawn stops the run")
    check(lab.techs.kyoto.status:find("respawn"), "status: " .. lab.techs.kyoto.status)
    -- and the new character is hooked: the trigger works again
    sim:give(sim.mePlayer, "Lethal Whirlwind Stream")
    sim:run(0.5)
    sim:anim(sim.meChar, FLOWING, 0.5)
    sim:run(1.8)
    check(sim:count({goal = "Console Move"}) == 1, "after the respawn the new character triggers kyoto again: " .. sim:count({goal = "Console Move"}))
    clean(sim, "cancel")
end
do   -- an error inside a sequence: caught, cleaned up, reported - and the next run still works
    local sim, lab = arena()
    local boom = true
    local tech = lab.techs.dunk
    local original = tech.run
    tech.run = function(ctx) ctx.commit(); ctx.instance(sim.W.env.Instance.new("BodyVelocity")).Parent = ctx.root; if boom then error("kaput") end end
    lab:setEnabled("dunk", true)
    sim:give(sim.mePlayer, "x")
    sim:anim(sim.meChar, LETHAL_ANIM, 0.5)
    sim:run(1.3)
    check(tech.stats.errors == 1 and tech.status:find("kaput"), "the error is reported: " .. tech.status)
    check(#sim:leftovers() == 0, "the BodyVelocity of the failed run was removed")
    check(sim.logged and #sim.logged == 1, "and logged once")
    sim.logged = nil
    boom = false
    tech.run = original
    tech.cooldownUntil = 0
    sim:anim(sim.meChar, LETHAL_ANIM, 0.5)
    sim:run(1.3)
    check(tech.stats.runs == 2, "the next run works")
    check(#sim.W.errors == 0 and #sim.W.thrown == 0, "no handler errors")
end

do   -- techs that move me never run at the same time
    local sim, lab = arena()
    lab:setEnabled("supa", true)
    lab:setEnabled("loop", true)
    lab:setEnabled("m1reset", true)
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(0.5)
    check(lab.techs.supa.running and not lab.techs.loop.running, "an uppercut starts Supa and not Loop Dash as well")
    check(lab.techs.loop.stats.runs == 0, "the second one is skipped, not queued")
    sim.W:keyDown("R")
    sim:run(0.1)
    check(lab.techs.m1reset.stats.runs == 0 and lab.techs.m1reset.status:find("Supa"), "a key press during a run is refused and says who is running: " .. lab.techs.m1reset.status)
    sim:run(1.5)
    sim.W:keyDown("R")
    sim:run(0.6)
    check(lab.techs.m1reset.stats.runs == 1, "afterwards it works")
    clean(sim, "exclusive")
end

------------------------------------------------------------------------------------------------ Hook Dash
section("Hook Dash")
do
    local sim, lab = arena({rivalPos = {6, 3, -20}})
    lab:setEnabled("hook", true)
    sim.mouseHit = sim.W.env.CFrame.new(5, 3, -19)                -- the cursor is on the rival
    sim.W:keyDown("C")
    sim:run(0.2)
    check(dashes(sim, "A") + dashes(sim, "D") == 0, "go without a target does nothing")
    check(lab.techs.hook.status:find("no target"), "status: " .. lab.techs.hook.status)
    sim.mouseHit = sim.W.env.CFrame.new(300, 3, 300)                -- the cursor is far from everybody
    sim.W:keyDown("V")
    check(lab:hookTarget() == nil and lab.techs.hook.status:find("near your cursor"), "V far from every player selects nobody: " .. lab.techs.hook.status)
    sim.mouseHit = sim.W.env.CFrame.new(5, 3, -19)
    sim.W:keyDown("V")
    check(lab:hookTarget() and lab:hookTarget().name == "Rival", "V picks the player nearest the cursor")
    local lights = 0
    for _, i in ipairs(sim.W.M.GetDescendants(sim.rival)) do if i.ClassName == "Highlight" then lights = lights + 1 end end
    check(lights == 1, "one highlight on the target")
    sim.W:keyDown("V")
    check(lab:hookTarget() == nil, "V again on the same player deselects")
    sim.W:keyDown("V")
    local before = sim:pos(sim.meChar)
    sim.W:keyDown("C")
    sim:run(0.05)
    check(dashes(sim, "D") == 1 and dashes(sim, "A") == 0, "the rival is to the right: a D side dash")
    sim:run(0.2)
    sim:run(1.1)
    local after = sim:pos(sim.meChar)
    local rp = sim:pos(sim.rival)
    check(sim:count({goal = "LeftClick"}) == 1 and sim:count({goal = "LeftClickRelease"}) == 1, "one M1 (press and release) at the end")
    local travelled = sim:dist(before, after)
    check(travelled > 15, "the dash really travelled " .. string.format("%.1f", travelled))
    -- it passed the rival's side and ended past him
    check(after[3] < rp[3] + 1, "it ended level with or past the target " .. fmt(after) .. " vs " .. fmt(rp))
    check(lab.techs.hook.status:find("done"), "status: " .. lab.techs.hook.status)
    check(sim.meHum.AutoRotate == true, "AutoRotate is back on")
    -- the camera was aimed at the target and the aim let go
    check(sim.W.renderSteps["TechLabAim_hook"] == nil, "the camera hold is unbound")
    lab:hookClear()
    clean(sim, "hook")
end
do   -- the camera is aimed at the target during the hold, and a cancel lets go of it at once
    local sim, lab = arena({rivalPos = {6, 3, -20}})
    lab:setEnabled("hook", true)
    sim.mouseHit = sim.W.env.CFrame.new(5, 3, -19)
    sim.W:keyDown("V")
    sim.W:keyDown("C")
    sim:run(0.5)
    check(sim.W.renderSteps["TechLabAim_hook"] ~= nil, "the camera hold is bound during the aim phase")
    local cam = sim.W.camera.CFrame
    local to = sim:pos(sim.rival)
    local dx, dy, dz = to[1] - cam.Position.X, to[2] - cam.Position.Y, to[3] - cam.Position.Z
    local m = math.sqrt(dx * dx + dy * dy + dz * dz)
    local look = cam.LookVector
    check((look.X * dx + look.Y * dy + look.Z * dz) / m > 0.999, "and the camera looks at the target")
    lab:cancelAll("panic")
    sim:run(0.05)
    check(sim.W.renderSteps["TechLabAim_hook"] == nil, "a cancel unbinds the hold at once")
    lab:hookClear()
    clean(sim, "hook camera")
end
do   -- guards
    local sim, lab = arena({rivalPos = {0, 3, -90}})
    lab:setEnabled("hook", true)
    sim.mouseHit = sim.W.env.CFrame.new(0, 3, -90)
    sim.W:keyDown("V")
    sim.W:keyDown("C")
    sim:run(0.3)
    check(dashes(sim, "A") + dashes(sim, "D") == 0 and lab.techs.hook.status:find("too far"), "too far: " .. lab.techs.hook.status)
    sim:place(sim.rival, {0, 3, -15})
    sim.W:keyDown("C")
    sim:run(0.8)
    check(lab.techs.hook.stats.runs == 1, "in range it runs")
    sim:kill(sim.rival)
    sim:run(0.1)
    check(lab:hookTarget() == nil, "a dead target is dropped")
    sim.W:keyDown("C")
    sim:run(0.1)
    check(lab.techs.hook.stats.runs == 1, "no second run without a target")
    clean(sim, "hook guards")
end
do   -- phone: double tap on the player, then the button
    local sim, lab = arena({rivalPos = {3, 3, -15}})
    lab:setEnabled("hook", true)
    sim.rayHit = sim.rival
    local function tap() sim.W.fire(sim.W.signalOf(sim.W.uis, "InputBegan"), {UserInputType = sim.W.env.Enum.UserInputType.Touch, KeyCode = sim.W.env.Enum.KeyCode.Unknown, Position = sim.W.env.Vector3.new(500, 300, 0)}, false) end
    tap(); sim:run(0.5)
    check(lab:hookTarget() == nil, "one tap is not a selection")
    tap(); sim:run(0.1); tap()
    check(lab:hookTarget() ~= nil, "a double tap on a player selects him")
    lab:fire("hook", {manual = true})                                 -- the UI button
    sim:run(1)
    check(lab.techs.hook.stats.runs == 1, "the on-screen button runs the dash")
    lab:hookClear()
    clean(sim, "hook phone")
end

------------------------------------------------------------------------------------------------ Loop Dash, Loop Dash 2, Lethal Dash
section("Loop / Lethal")
do
    local sim, lab = arena({rivalPos = {0, 3, -10}})
    lab:setEnabled("loop", true)
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(2)
    check(lab.techs.loop.stats.runs == 1, "loop dash ran: " .. lab.techs.loop.status)
    local seen = false
    local p, r = sim:pos(sim.meChar), sim:pos(sim.rival)
    check(sim:dist({p[1], 0, p[3]}, {r[1], 0, r[3]}) < 1.5, "it settles above the target " .. fmt(p) .. " vs " .. fmt(r))
    check(p[2] > 0.5 and p[2] <= 11, "at a sensible height: " .. p[2])
    check(dashes(sim, "W") >= 1, "dashes while looping")
    clean(sim, "loop")
end
do
    local sim, lab = arena({rivalPos = {0, 3, -20}})
    lab:setEnabled("loop2", true)
    local look0 = sim.meRoot.CFrame.LookVector
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(0.4)
    check(sim.meHum.AutoRotate == false, "body rotation is locked while the tech works")
    sim:run(0.3)
    check(sim:count({goal = "KeyPress", key = "Q"}) == 1, "one dash")
    check(sim.meRoot.AssemblyLinearVelocity.Y > 40, "jump assist: the vertical velocity was set")
    sim:run(2.3)
    check(sim.meHum.AutoRotate == true, "AutoRotate is restored afterwards")
    check(lab.techs.loop2.stats.runs == 1, "ran: " .. lab.techs.loop2.status)
    clean(sim, "loop2")
end
do   -- pauses while somebody blocks
    local sim, lab = arena({rivalPos = {0, 3, -20}})
    lab:setEnabled("loop2", true)
    sim:anim(sim.rival, BLOCK, 3)
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(1)
    check(dashes(sim, "W") == 0 and lab.techs.loop2.status:find("blocking"), "somebody blocks: " .. lab.techs.loop2.status)
    sim:run(3)
    lab.dashClock:reset()
    lab.techs.loop2.cooldownUntil = 0
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(1)
    check(dashes(sim, "W") == 1, "the block is over: it dashes")
    clean(sim, "loop2 block")
end
do
    local sim, lab = arena({rivalPos = {0, 3, -15}})
    lab:setEnabled("lethal", true)
    sim:anim(sim.meChar, LETHAL_ANIM, 0.5)
    sim:run(1.4)
    check(dashes(sim, "W") == 0, "lethal dash waits 1.6 s")
    sim:run(0.5)
    check(dashes(sim, "W") == 1, "then dashes")
    sim:run(2)
    check(sim.meHum.AutoRotate == true, "rotation restored")
    clean(sim, "lethal")
end

------------------------------------------------------------------------------------------------ Kiba / Kitty
section("Kiba / Kitty")
do
    local sim, lab = arena({rivalPos = {0, 3, -8}})
    lab:setEnabled("kiba", true)
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(0.45)
    check(dashes(sim, "W") == 1, "dash after the delay")
    sim:run(0.15)
    check(#sim:leftovers() >= 3, "constraints exist while hanging on the target")
    sim:run(1)
    check(#sim:leftovers() == 0, "the follow part and every constraint are gone afterwards: " .. table.concat(sim:leftovers(), ","))
    local p, r = sim:pos(sim.meChar), sim:pos(sim.rival)
    check(sim:dist(p, r) < 4, "it ended next to the target")
    clean(sim, "kiba")
end
do
    local sim, lab = arena({rivalPos = {0, 3, -8}})
    lab:setOption("kiba", "mode", "Orbit (Kitty)")
    lab:setEnabled("kiba", true)
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(1.5)
    check(lab.techs.kiba.stats.runs == 1, "orbit mode ran: " .. lab.techs.kiba.status)
    clean(sim, "kitty")
end

------------------------------------------------------------------------------------------------ Twisted
section("Twisted")
do
    local sim, lab = arena()
    lab:setEnabled("twisted", true)
    local z0 = sim:pos(sim.meChar)[3]
    sim:anim(sim.meChar, TWISTED, 0.4)
    sim:run(0.3)
    check(dashes(sim, "W") == 1, "dash after 230 ms")
    check(near(sim:pos(sim.meChar)[3], z0 + 3.4, 0.2), "stepped back 3.4 studs: " .. sim:pos(sim.meChar)[3])
    sim:run(1)
    lab:setOption("twisted", "instant", true)
    lab:setOption("twisted", "dashKey", "S")
    lab.techs.twisted.cooldownUntil = 0
    lab.dashClock:reset()
    sim:anim(sim.meChar, TWISTED, 0.4)
    sim:run(0.8)
    check(dashes(sim, "S") == 1, "the dash direction is an option")
    clean(sim, "twisted")
end

------------------------------------------------------------------------------------------------ Kyoto, Dunk, Surf
section("Kyoto / Dunk / Surf")
do
    local sim, lab = arena()
    lab:setEnabled("kyoto", true)
    sim:give(sim.mePlayer, "Lethal Whirlwind Stream")
    local z0 = sim:pos(sim.meChar)[3]
    sim:anim(sim.meChar, FLOWING, 0.5)
    sim:run(1.4)
    check(sim:count({goal = "Console Move"}) == 0, "waits 1.5 s after Flowing Water")
    sim:run(0.3)
    check(sim:count({goal = "Console Move", tool = "Lethal Whirlwind Stream"}) == 1, "casts Lethal Whirlwind Stream through the remote")
    sim:run(0.6)
    check(near(sim:pos(sim.meChar)[3], z0 - 20, 0.5), "hopped 20 studs forward: " .. sim:pos(sim.meChar)[3])
    check(sim:count({goal = "KeyPress", key = "One"}) == 0, "(hotbar keys go through the virtual input, not the remote)")
    local keys = 0
    for _, v in ipairs(sim.W.vim) do if v[1] == "key" and v[2] == true then keys = keys + 1 end end
    check(keys == 2, "hotbar 1 then 2 are pressed: " .. keys)
    clean(sim, "kyoto")
end
do   -- no such move: the sequence still hops and says why the cast failed
    local sim, lab = arena()
    lab:setEnabled("kyoto", true)
    sim:anim(sim.meChar, FLOWING, 0.5)
    sim:run(2.6)
    check(lab.techs.kyoto.status:find("cast failed"), "status: " .. lab.techs.kyoto.status)
    clean(sim, "kyoto no tool")
end
do
    local sim, lab = arena()
    lab:setEnabled("dunk", true)
    sim:anim(sim.meChar, LETHAL_ANIM, 0.5)
    sim:run(1.2)
    check(near(sim:pos(sim.meChar)[2], 73, 0.1), "dunk lifts 70 studs: " .. sim:pos(sim.meChar)[2])
    lab:setEnabled("surf", true)
    sim:place(sim.meChar, {0, 3, 0})
    sim:anim(sim.meChar, SURF, 1)
    sim:run(1.6)
    check(near(sim:pos(sim.meChar)[3], -50, 0.5), "surf carries 50 studs forward: " .. sim:pos(sim.meChar)[3])
    clean(sim, "dunk surf")
end

------------------------------------------------------------------------------------------------ Auto Counter
section("Auto Counter")
do
    local sim, lab = arena({rival = false})
    lab:setEnabled("counter", true)
    sim:give(sim.mePlayer, "Prey's Peril")
    local _, rival = sim:addEnemy("Dasher", {0, 3, -9}, {look = {0, 3, 0}})
    sim:run(0.2)
    sim:anim(rival, FORWARD, 0.3)
    sim:run(0.1)
    check(sim:count({goal = "Console Move", tool = "Prey's Peril"}) == 1, "a close, facing player dashes: counter cast")
    check(lab.techs.counter.status:find("Dasher"), "status names him: " .. lab.techs.counter.status)
    sim:run(1)
    local _, far = sim:addEnemy("Far", {0, 3, -40}, {look = {0, 3, 0}})
    sim:run(0.1)
    sim:anim(far, FORWARD, 0.3)
    sim:run(0.2)
    check(sim:count({goal = "Console Move"}) == 1, "too far away: no counter")
    local _, away = sim:addEnemy("Away", {0, 3, -8}, {look = {0, 3, -100}})
    sim:run(0.1)
    sim:place(rival, {0, 3, -60})
    sim:anim(away, FORWARD, 0.3)
    sim:run(0.2)
    check(sim:count({goal = "Console Move"}) == 1, "looking away from me: no counter")
    lab:setOption("counter", "facing", false)
    sim:run(1)
    sim:anim(away, "10469493270", 0.3)                           -- an M1
    sim:run(0.2)
    check(sim:count({goal = "Console Move"}) == 2, "facing check off + an M1: counter cast")
    sim:run(0.1)
    lab:setEnabled("counter", false)
    sim:run(0.8)
    sim:anim(away, "10469643643", 0.3)
    sim:run(0.2)
    check(sim:count({goal = "Console Move"}) == 2, "switched off: no counter")
    clean(sim, "counter")
end

------------------------------------------------------------------------------------------------ the helpers
section("helpers")
do
    local sim, lab = arena()
    lab:setEnabled("flip", true)
    sim:anim(sim.meChar, FORWARD, 0.3)
    sim:run(1)
    check(lab.techs.flip.stats.runs == 1 and sim.meHum.AutoRotate == true, "flip ran and gave rotation back: " .. lab.techs.flip.status)
    clean(sim, "flip")
end
do
    local sim, lab = arena()
    lab:setEnabled("mousedash", true)
    sim.mouseHit = sim.W.env.CFrame.new(30, 3, 0)               -- cursor to the right
    sim:anim(sim.meChar, FORWARD, 0.3)
    sim:run(0.3)
    local look = sim.meRoot.CFrame.LookVector
    check(look.X > 0.95, "the body turned to the cursor: " .. look.X)
    sim:run(1)
    clean(sim, "mouse dash")
end
do
    local sim, lab = arena()
    lab:setEnabled("sidem1", true)
    local before = sim.meRoot.CFrame
    local camBefore = sim.W.camera.CFrame
    sim.W:mouseDown("MouseButton1")
    sim:run(0.02)
    local mid = sim.meRoot.CFrame.LookVector
    check(math.abs(mid.X) > 0.5, "the body is turned for a moment: " .. mid.X)
    sim:run(0.3)
    local after = sim.meRoot.CFrame.LookVector
    check(near(after.X, before.LookVector.X, 0.01) and near(after.Z, before.LookVector.Z, 0.01), "and turned back")
    check(near(sim.W.camera.CFrame.Position.X, camBefore.Position.X, 0.01), "the camera is put back too")
    check(sim.meHum.AutoRotate == true, "rotation back")
    clean(sim, "side m1")
end
do
    local sim, lab = arena()
    lab:setEnabled("noendlag", true)
    sim:anim(sim.meChar, SIDE_R, 0.3)
    sim:run(0.3)
    sim.W:keyDown("Q")
    sim:run(0.1)
    check(dashes(sim, "W") == 1, "Q right after a side dash sends the forward dash")
    sim.W:keyDown("Q")
    sim:run(0.1)
    check(dashes(sim, "W") == 1, "and only once per side dash")
    clean(sim, "no end lag")
end
do
    local sim, lab = arena()
    lab:setEnabled("slidem1", true)
    sim:anim(sim.meChar, SIDE_L, 0.3)
    sim:run(0.2)
    check(sim:count({goal = "LeftClick"}) == 1, "an M1 after a side dash")
    sim:anim(sim.meChar, SIDE_L, 0.3)
    sim:run(0.2)
    check(sim:count({goal = "LeftClick"}) == 1, "(its own cooldown)")
    clean(sim, "slide m1")
end
do
    local sim, lab = arena({rivalPos = {0, 3, -8}})
    lab:setEnabled("downslam", true)
    local y0 = sim:pos(sim.meChar)[2]
    sim:anim(sim.meChar, SLAM, 0.5)
    sim:run(0.5)
    check(near(sim:pos(sim.meChar)[2], y0 + 6, 0.1), "lifted 6 studs: " .. sim:pos(sim.meChar)[2])
    sim:place(sim.rival, {0, 3, -90})
    sim:place(sim.meChar, {0, 3, 0})
    sim:anim(sim.meChar, SLAM, 0.5)
    sim:run(0.5)
    check(near(sim:pos(sim.meChar)[2], 3, 0.1), "nobody close: no lift")
    clean(sim, "down slam")
end
do
    local sim, lab = arena({rivalPos = {0, 3, -10}})
    lab:setEnabled("catch", true)
    sim.enemyVel[sim.rival] = {0, 0, 6}                            -- he walks towards me
    sim:run(1.2)
    check(sim:count({goal = "LeftClick"}) == 1, "M1 once when he steps into the box: " .. sim:count({goal = "LeftClick"}))
    sim:run(1)
    check(sim:count({goal = "LeftClick"}) == 1, "not again while he stays in it")
    sim.enemyVel[sim.rival] = nil
    clean(sim, "catch")
end
do
    local sim, lab = arena()
    lab:setEnabled("m1reset", true)
    lab:setEnabled("emotedash", true)
    local p0 = sim:pos(sim.meChar)
    sim.W:keyDown("R")
    sim:run(0.6)
    local p1 = sim:pos(sim.meChar)
    check(near(p1[1] - p0[1], 25.5, 0.5), "M1 reset steps 25.5 studs to the right: " .. (p1[1] - p0[1]))
    check(dashes(sim, "W") == 1, "and dashes")
    sim:place(sim.meChar, {0, 3, 0})
    sim.W:keyDown("T")
    sim:run(0.5)
    clean(sim, "m1 reset / emote dash")
end

------------------------------------------------------------------------------------------------ input modes, dash guard, own tracks
section("input")
do
    local sim, lab = arena()
    local function dashNow(dir) sim.W:startThread(function() lab:dash(dir) end); sim:run(0.2) end    -- (dash waits between its key events: it needs a thread)
    lab:setInput("Keys")
    dashNow("W")
    check(sim:count({goal = "KeyPress"}) == 0 and #sim.W.vim >= 4, "Keys mode dashes through the key events and not the remote: " .. #sim.W.vim)
    lab:setInput("Remote")
    sim.W.vim = {}
    sim.dashReadyAt = {}
    dashNow("S")
    check(sim:count({goal = "KeyPress", dash = "S"}) == 1 and #sim.W.vim == 0, "Remote mode uses only the remote")
    lab:setInput("Auto")
    sim.W.M.FindFirstChild(sim.meChar, "Communicate"):Destroy()    -- no Communicate (the game changed): Auto falls back to the keys
    sim.W.vim = {}
    dashNow("W")
    check(#sim.W.vim >= 4, "Auto falls back to the keys when the remote is missing: " .. #sim.W.vim)
    lab:setInput("bogus")
    check(lab.input == "Auto", "an invalid mode is ignored")
    clean(sim, "input")
end
do   -- the lab's own animation does not count as a dash
    local sim, lab = arena()
    lab:setEnabled("kyoto", true)
    lab:setEnabled("slidem1", true)
    sim:give(sim.mePlayer, "Lethal Whirlwind Stream")
    sim:anim(sim.meChar, FLOWING, 0.5)
    sim:run(2.6)
    check(sim:count({goal = "LeftClick"}) == 0, "the side-dash animation that kyoto plays itself does not trigger Side M1")
    check(lab:dashLeft("side") <= 0, "and does not start the side dash cooldown")
    check(sim.played and #sim.played >= 1, "(it did play it)")
    clean(sim, "own tracks")
end

------------------------------------------------------------------------------------------------ learning triggers, config
section("config")
do
    local sim, lab = arena()
    local learned
    lab:learnTrigger("supa", function(id) learned = id end)
    sim:anim(sim.meChar, "999111", 0.3)
    check(learned == "999111" and lab.techs.supa.ids["999111"], "the next animation becomes a trigger")
    check(#sim.toasts == 1, "and says so")
    lab:setEnabled("supa", true)
    sim:run(1)
    sim:anim(sim.meChar, "999111", 0.3)
    sim:run(0.6)
    check(lab.techs.supa.stats.runs == 1, "the learned id triggers the tech")
    local saved = lab:export()
    check(saved.triggers.supa[1] == "999111" and saved.enabled.supa == true, "it is exported")
    lab:setOption("supa", "delay", 50)
    lab:setOption("supa", "delay", 99999)                           -- clamped
    check(lab.techs.supa.opt.delay == 600, "options are clamped: " .. lab.techs.supa.opt.delay)
    lab:setOption("hook", "side", "Nowhere")
    check(lab.techs.hook.opt.side == "Closest", "a choice that does not exist is refused")
    local out = lab:export()
    check(out.opts.supa and out.opts.supa.delay == 600 and out.opts.hook == nil, "only options that differ from the defaults are exported")
    lab:forgetTriggers("supa")
    check(not lab.techs.supa.ids["999111"], "triggers can be forgotten")
    local sim2, lab2 = arena()
    lab2:import({enabled = {supa = true, nonsense = true}, opts = {supa = {delay = -5, radius = "x", junk = 1}, ghost = {a = 1}}, triggers = {supa = {"123", "x1", 5, string.rep("9", 40)}}, input = "Keys", master = false})
    check(lab2.techs.supa.enabled and lab2.techs.supa.opt.delay == 0 and lab2.techs.supa.opt.radius == 50, "import cleans every value")
    check(lab2.techs.supa.ids["123"] and not lab2.techs.supa.ids["x1"], "and the trigger ids")
    check(lab2.input == "Keys" and lab2.master == false, "mode and master come back")
    check(next(lab2.techs.supa.opt, nil) ~= nil, "(options table exists)")
    lab2:import("garbage")
    lab2:import(nil)
    clean(sim, "config")
end

------------------------------------------------------------------------------------------------ destroy
section("destroy")
do
    local sim, lab = arena()
    lab:setEnabled("supa", true)
    lab:setEnabled("counter", true)
    lab:setEnabled("hook", true)
    sim.mouseHit = sim.W.env.CFrame.new(0, 3, -12)
    sim.W:keyDown("V")
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(0.1)
    local W = sim.W
    local signals = {W.signalOf(W.uis, "InputBegan"), W.signalOf(W.runService, "Heartbeat"), W.signalOf(sim.mePlayer, "CharacterAdded"),
                     W.signalOf(sim.W.M.FindFirstChildOfClass(sim.meHum, "Animator"), "AnimationPlayed"), W.signalOf(sim.W.M.FindFirstChildOfClass(sim.W.M.FindFirstChildOfClass(sim.rival, "Humanoid"), "Animator"), "AnimationPlayed"),
                     W.signalOf(sim.live, "ChildAdded")}
    local before = {}
    for i, sg in ipairs(signals) do before[i] = sim:connected(sg) end
    check(before[1] >= 1 and before[2] >= 1 and before[3] >= 1 and before[4] >= 1 and before[5] >= 1 and before[6] >= 1, "(every listener is connected before destroy: " .. table.concat(before, ",") .. ")")
    lab:destroy()
    local after = {}
    for i, sg in ipairs(signals) do after[i] = sim:connected(sg) end
    check(after[1] == 0 and after[2] == 0 and after[3] == 0 and after[4] == 0 and after[5] == 0 and after[6] == 0, "destroy disconnects every listener: " .. table.concat(after, ","))
    sim:run(1)
    check(dashes(sim, "W") == 0, "destroyed: the running tech was cancelled")
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:anim(sim.rival, FORWARD, 0.3)
    sim.W:keyDown("C")
    sim:run(1)
    check(sim:count({goal = "KeyPress"}) == 0 and sim:count({goal = "Console Move"}) == 0, "and nothing listens any more")
    local lights = 0
    for _, i in ipairs(sim.W.M.GetDescendants(sim.W.workspace)) do if i.ClassName == "Highlight" then lights = lights + 1 end end
    check(lights == 0, "the highlight is removed")
    clean(sim, "destroy")
end

------------------------------------------------------------------------------------------------ techs from the wiki descriptions
section("new techs")
local GRASP, SHOVE = "Hunter's Grasp", "Shove"
local function firstLog(sim, filter)
    for _, r in ipairs(sim.log) do
        local ok = true
        for k, v in pairs(filter) do if r[k] ~= v then ok = false; break end end
        if ok then return r end
    end
end
do   -- Backdash Cancel
    local sim, lab = arena()
    lab:setEnabled("backdash", true)
    sim.W:keyDown("B")
    sim:run(0.5)
    local dash = firstLog(sim, {goal = "KeyPress", dash = "S"})
    local keyT = sim:keyTimes("One")[1]
    check(dash ~= nil, "B sends a back dash")
    check(keyT and dash and near(keyT - dash.t, 0.09, 0.03), "...and hotbar slot 1 about 90 ms later (" .. tostring(keyT and dash and keyT - dash.t) .. ")")
    check(lab.techs.backdash.status:find("done"), "status: " .. lab.techs.backdash.status)
    -- aerial: the jump comes first
    sim.dashReadyAt = {}
    lab.dashClock:reset()
    lab.techs.backdash.cooldownUntil = 0
    lab:setOption("backdash", "aerial", true)
    lab:setOption("backdash", "slot", "3")
    local before = #sim.log
    sim.W:keyDown("B")
    sim:run(0.05)
    check(sim.meRoot.AssemblyLinearVelocity.Y > 40, "aerial: the jump is set before the dash")
    sim:run(0.5)
    check(#sim:keyTimes("Three") == 1, "slot 3 is used when chosen")
    -- by name: the Console Move remote, not a key
    lab:setOption("backdash", "aerial", false)
    lab:setOption("backdash", "moveName", "Lethal Whirlwind Stream")
    sim:give(sim.mePlayer, "Lethal Whirlwind Stream")
    sim.dashReadyAt = {}; lab.dashClock:reset(); lab.techs.backdash.cooldownUntil = 0
    sim.W:keyDown("B")
    sim:run(0.5)
    check(sim:count({goal = "Console Move", tool = "Lethal Whirlwind Stream"}) == 1, "a move named in the options is cast through the remote")
    -- the forward dash is on cooldown: refused, and says so
    sim.dashReadyAt = {}
    sim:anim(sim.meChar, FORWARD, 0.3)
    sim:run(0.4)
    lab.techs.backdash.cooldownUntil = 0
    local n = sim:count({goal = "KeyPress", dash = "S"})
    sim.W:keyDown("B")
    sim:run(0.3)
    check(sim:count({goal = "KeyPress", dash = "S"}) == n and lab.techs.backdash.status:find("cooldown"), "on cooldown: " .. lab.techs.backdash.status)
    clean(sim, "backdash")
end
do   -- Micro Dash
    local sim, lab = arena({rival = false})
    sim:addEnemy("Left", {-10, 3, -5})
    lab:setEnabled("microdash", true)
    sim.W:keyDown("X")
    sim:run(0.4)
    check(dashes(sim, "A") == 1 and dashes(sim, "D") == 0, "a target on the left: side dash to the left")
    local dash = firstLog(sim, {goal = "KeyPress", dash = "A"})
    local keyT = sim:keyTimes("One")[1]
    check(keyT and near(keyT - dash.t, 0.06, 0.03), "the move follows 60 ms later")
    lab:setOption("microdash", "side", "Right")
    sim.dashReadyAt = {}; lab.dashClock:reset(); lab.techs.microdash.cooldownUntil = 0
    sim.W:keyDown("X")
    sim:run(0.4)
    check(dashes(sim, "D") == 1, "Right means D")
    clean(sim, "microdash")
end
do   -- Shove Dash
    local sim, lab = arena()
    lab:setEnabled("shovedash", true)
    sim.W:keyDown("Z")
    sim:run(0.3)
    check(lab.techs.shovedash.status:find("do not have Shove") and sim:count({goal = "Console Move"}) == 0, "no Shove in the backpack: " .. lab.techs.shovedash.status)
    sim:give(sim.mePlayer, SHOVE)
    local z0 = sim:pos(sim.meChar)[3]
    sim.W:keyDown("Z")
    sim:run(0.5)
    local cast, m1 = firstLog(sim, {goal = "Console Move", tool = SHOVE}), firstLog(sim, {goal = "LeftClick"})
    local dash = firstLog(sim, {goal = "KeyPress", dash = "W"})
    check(cast and m1 and dash and near(m1.t - cast.t, 0.04, 0.03) and near(dash.t - m1.t, 0.12, 0.03), "Shove, then the M1 40 ms later, then the dash 120 ms after that")
    check(near(sim:pos(sim.meChar)[3], z0 + 3, 0.2), "with a step back first: " .. sim:pos(sim.meChar)[3])
    clean(sim, "shove dash")
end
do   -- Uppercut Catch
    local sim, lab = arena({rivalPos = {0, 3, -14}})
    lab:setEnabled("uppercutcatch", true)
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(0.45)
    check(dashes(sim, "W") == 0, "waits 450 ms")
    sim:run(0.3)
    check(dashes(sim, "W") == 1 and sim:count({goal = "LeftClick"}) == 1, "far away: forward dash, then the M1")
    local d, m = firstLog(sim, {goal = "KeyPress", dash = "W"}), firstLog(sim, {goal = "LeftClick"})
    check(d and m and near(m.t - d.t, 0.12, 0.03), "M1 120 ms after the dash")
    -- close: walk into him instead
    local sim2, lab2 = arena({rivalPos = {0, 3, -4}})
    lab2:setEnabled("uppercutcatch", true)
    sim2:anim(sim2.meChar, UPPERCUT, 0.5)
    sim2:run(0.9)
    check(dashes(sim2, "W") == 0 and #sim2:keyTimes("W") == 1 and #sim2:keyTimes("W", false) == 1, "close: W is held and let go, no dash is wasted")
    local down, up = sim2:keyTimes("W")[1], sim2:keyTimes("W", false)[1]
    check(near(up - down, 0.3, 0.03), "for 300 ms")
    check(sim2:count({goal = "LeftClick"}) == 1, "and he is punched")
    -- far with the dash on cooldown: nothing is sent
    local sim3, lab3 = arena({rivalPos = {0, 3, -14}})
    lab3:setEnabled("uppercutcatch", true)
    sim3:anim(sim3.meChar, FORWARD, 0.3)
    sim3:run(0.4)
    sim3:anim(sim3.meChar, UPPERCUT, 0.5)
    sim3:run(0.9)
    check(sim3:count({goal = "LeftClick"}) == 0 and lab3.techs.uppercutcatch.status:find("cooldown"), "far and no dash: " .. lab3.techs.uppercutcatch.status)
    clean(sim, "uppercut catch"); clean(sim2, "uppercut catch close"); clean(sim3, "uppercut catch cooldown")
end
do   -- the Hunter's Grasp follow-ups
    local sim, lab = arena()
    lab:setEnabled("lethalgrasp", true)
    sim:anim(sim.meChar, LETHAL_ANIM, 0.5)
    sim:run(1.2)
    check(sim:count({goal = "Console Move"}) == 0 and lab.techs.lethalgrasp.status:find("do not have"), "no Grasp: " .. lab.techs.lethalgrasp.status)
    sim:give(sim.mePlayer, GRASP)
    lab.techs.lethalgrasp.cooldownUntil = 0
    sim:anim(sim.meChar, LETHAL_ANIM, 0.5)
    sim:run(0.8)
    check(sim:count({goal = "Console Move"}) == 0, "waits 0.9 s after Lethal Whirlwind Stream")
    sim:run(0.2)
    check(sim:count({goal = "Console Move", tool = GRASP}) == 1, "then casts Hunter's Grasp once")
    lab:setEnabled("flowinggrasp", true)
    sim:anim(sim.meChar, FLOWING, 0.5)
    sim:run(1.35)
    check(sim:count({goal = "Console Move"}) == 1, "Flowing Grasp waits 1.4 s")
    sim:run(0.6)
    check(sim:count({goal = "Console Move", tool = GRASP}) == 4, "and spams three casts: " .. sim:count({goal = "Console Move", tool = GRASP}))
    local times = {}
    for _, r in ipairs(sim.log) do if r.goal == "Console Move" then times[#times + 1] = r.t end end
    check(#times == 4 and near(times[3] - times[2], 0.15, 0.03) and near(times[4] - times[3], 0.15, 0.03), "150 ms apart")
    lab:setEnabled("uppercutgrasp", true)
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(0.6)
    check(sim:count({goal = "Console Move", tool = GRASP}) == 5, "Uppercut Grasp casts after the uppercut")
    clean(sim, "grasp")
    -- the delay is started a ping early when my animations arrive a ping late
    local sim2, lab2 = arena({ping = 160, animMode = "server"})
    learnLag(sim2, lab2, 3)
    sim2:give(sim2.mePlayer, GRASP)
    lab2:setEnabled("uppercutgrasp", true)
    local _, S0 = sim2:press(UPPERCUT, 0.5)
    sim2:run(1)
    local cast = firstLog(sim2, {goal = "Console Move", tool = GRASP})
    check(cast and near(cast.arrive - S0, 0.3, 0.03), "ping-aware like the others (" .. tostring(cast and cast.arrive - S0) .. ")")
end
do   -- Fast Dash
    local sim, lab = arena()
    lab:setEnabled("fastdash", true)
    local x0 = sim:pos(sim.meChar)[1]
    local track = sim:anim(sim.meChar, SIDE_R, 1)
    sim:run(0.1)
    check(near(sim:pos(sim.meChar)[1] - x0, 5, 1.5) or sim:pos(sim.meChar)[1] - x0 > 5, "the hop: " .. (sim:pos(sim.meChar)[1] - x0))
    check(track.IsPlaying == true, "(the animation is still playing at 0.1 s)")
    sim:run(0.2)
    check(track.IsPlaying == false, "the animation is cut at 0.22 s")
    sim:run(0.3)
    check(near(sim:pos(sim.meChar)[1] - x0, 5 + 250 * 0.25, 6), "a side dash to the right travels hop + burst: " .. (sim:pos(sim.meChar)[1] - x0))
    check(#sim:leftovers() == 0, "the burst is removed")
    local xl = sim:pos(sim.meChar)[1]
    sim:anim(sim.meChar, SIDE_L, 1)
    sim:run(0.7)
    check(sim:pos(sim.meChar)[1] < xl - 40, "a dash to the left goes left")
    clean(sim, "fast dash")
end
do   -- DashClip
    local sim, lab = arena()
    lab:setEnabled("dashclip", true)
    local part = sim.W.M.FindFirstChild(sim.meChar, "Head")
    check(part.CanCollide == true, "(collides to begin with)")
    sim:anim(sim.meChar, FORWARD, 0.3)
    sim:run(0.2)
    check(part.CanCollide == false, "no collision while dashing")
    sim:run(0.4)
    check(part.CanCollide == true, "and collision is back afterwards")
    -- where nothing but the tech switches collisions back on (so the restore itself is visible)
    sim.humanoidCollides = false
    lab.techs.dashclip.cooldownUntil = 0
    sim:anim(sim.meChar, SIDE_L, 0.3)
    sim:run(0.1)
    check(part.CanCollide == false, "(still off during the run)")
    sim:run(0.5)
    check(part.CanCollide == true, "the tech itself gives collision back when it ends")
    lab.techs.dashclip.cooldownUntil = 0
    sim:anim(sim.meChar, SIDE_L, 0.3)
    sim:run(0.1)
    lab:cancelAll("panic")
    sim:run(0.05)
    check(part.CanCollide == true, "a cancel gives it back at once")
    clean(sim, "dashclip")
end
do   -- Awareness
    local function lights(sim, adornee)
        local n, found = 0, nil
        for _, i in ipairs(sim.W.M.GetDescendants(sim.W.workspace)) do
            if i.ClassName == "Highlight" and i.Name == "TechLabMark" and (adornee == nil or i.Adornee == adornee) then n = n + 1; found = i end
        end
        return n, found
    end
    local sim, lab = arena()
    lab:setEnabled("counteresp", true)
    sim:anim(sim.rival, "12351854556", 0.5)
    sim:run(0.1)
    local n, light = lights(sim, sim.rival)
    check(n == 1 and light.FillColor.B > 0.9 and light.FillColor.R < 0.5, "a counter move highlights him in cyan")
    sim:run(3.2)
    check(lights(sim) == 0, "and the highlight goes after 3 s")
    sim:anim(sim.meChar, "12351854556", 0.5)
    sim:run(0.1)
    check(lights(sim) == 0, "my own counter is not marked")
    lab:setOption("counteresp", "color", "Red")
    sim:anim(sim.rival, "15311685628", 0.5)
    sim:run(0.1)
    local _, red = lights(sim, sim.rival)
    check(red and red.FillColor.R > 0.9 and red.FillColor.B < 0.5, "the colour is an option")
    lab:setEnabled("counteresp", false)
    check(lights(sim) == 0, "switching it off removes the highlight")
    lab:setEnabled("blockesp", true)
    sim:anim(sim.rival, BLOCK, 1.5)
    sim:run(0.1)
    check(lights(sim, sim.rival) == 1, "Block ESP marks a blocking player")
    sim:run(1.6)
    check(lights(sim) == 0, "and lets go when the block animation stops")
    -- a player who joins later is watched too
    local _, late = sim:addEnemy("Late", {5, 3, -5})
    sim:run(0.1)
    sim:anim(late, BLOCK, 1.5)
    sim:run(0.1)
    check(lights(sim, late) == 1, "players who arrive later are watched too")
    lab:setMaster(false)
    check(lights(sim) == 0, "the master switch clears every mark")
    lab:setMaster(true)
    -- the unblockable warning
    lab:setEnabled("blockwarn", true)
    sim:anim(sim.rival, "10470389827", 1)
    sim:run(0.1)
    local arrow
    for _, i in ipairs(sim.W.M.GetDescendants(sim.rival)) do if i.Name == "TechLabArrow" then arrow = i end end
    check(arrow ~= nil and arrow.AlwaysOnTop == true, "an arrow above the wind-up")
    sim:run(1)
    local still
    for _, i in ipairs(sim.W.M.GetDescendants(sim.rival)) do if i.Name == "TechLabArrow" then still = i end end
    check(still == nil, "...gone when the wind-up ends")
    -- Death Counter
    lab:setEnabled("deathcounter", true)
    sim.W:make("Folder", "Death Counter", {}, sim.rival)
    sim:run(0.1)
    check(lights(sim, sim.rival) == 1, "a Death Counter in his character highlights him")
    sim:run(12.3)
    check(lights(sim) == 0, "for 12 s")
    local _, other = sim:addEnemy("Already", {8, 3, -8})
    sim.W:make("Folder", "Death Counter", {}, other)
    sim:run(0.1)
    lab:setEnabled("deathcounter", false)
    lab:setEnabled("deathcounter", true)
    sim:run(0.1)
    check(lights(sim, other) == 1, "one that was already there when the tech is switched on is found too")
    lab:destroy()
    check(lights(sim) == 0, "destroy removes every mark")
    clean(sim, "awareness")
end
do   -- the colour names in the tech definitions are the ones the data module knows
    local sim, lab = arena()
    local TD = sim.TD
    for _, id in ipairs({"counteresp", "deathcounter", "blockesp"}) do
        for _, d in ipairs(lab.techs[id].defs) do
            if d.key == "color" then
                check(#d.choices == #TD.COLOR_NAMES, id .. ": the same number of colours")
                for i, name in ipairs(d.choices) do check(TD.COLOR_NAMES[i] == name and TD.COLORS[name] ~= nil, id .. ": colour " .. name .. " is known") end
            end
        end
    end
end

------------------------------------------------------------------------------------------------ ping
section("ping")
do   -- the lag of my own animations is measured, not guessed
    local sim, lab = arena({ping = 160, animMode = "server"})
    check(lab:netInfo().lag == nil and lab:lag() == 0, "nothing measured yet: no correction")
    learnLag(sim, lab, 2)
    check(lab:netInfo().lag == nil, "two samples are not enough")
    learnLag(sim, lab, 1)
    local info = lab:netInfo()
    check(info.lag and near(info.lag, 0.16, 0.02) and info.samples == 3, "a server-played animation arrives one ping after my input: " .. tostring(info.lag))
    check(near(info.ping, 160, 1e-9) and near(info.lead, 0.16, 0.001), "the lead is half a ping plus the interpolation delay: " .. info.lead)
    clean(sim, "lag learn")
end
do
    local sim, lab = arena({ping = 160, animMode = "predicted"})
    learnLag(sim, lab, 3)
    check(lab:netInfo().lag ~= nil and near(lab:netInfo().lag, 0, 0.02), "an animation my client plays at once has no lag: " .. tostring(lab:netInfo().lag))
    lab:setNet("learn", false)
    check(lab:lag() == 0, "learning off: the lag is not used")
    clean(sim, "lag predicted")
end
do   -- Supa's first dash reaches the server at the same moment in the server's own timeline, whatever the ping
    local function firstDashAfterUppercut(setup)
        local sim, lab = arena({ping = 160, animMode = "server"})
        learnLag(sim, lab, 3)
        lab:setEnabled("supa", true)
        if setup then setup(lab) end
        local _, S0 = sim:press(UPPERCUT, 0.5)
        sim:run(1.2)
        for _, r in ipairs(sim.log) do
            if r.goal == "KeyPress" and r.key == "Q" and r.dash == "W" then return r.arrive - S0, sim, lab end
        end
        return nil, sim, lab
    end
    local compensated, sim1 = firstDashAfterUppercut()
    check(compensated and near(compensated, 0.32, 0.03), "ping 160, server-played animations: the dash reaches the server 320 ms after the uppercut did (" .. tostring(compensated) .. ")")
    clean(sim1, "supa ping")
    local plain = firstDashAfterUppercut(function(lab) lab:setNet("strength", 0) end)
    check(plain and near(plain, 0.48, 0.03), "without the correction it is a whole ping late (" .. tostring(plain) .. ")")
    local off = firstDashAfterUppercut(function(lab) lab.techs.supa.opt.ping = false end)
    check(off and near(off, 0.48, 0.03), "the per-tech switch turns it off (" .. tostring(off) .. ")")
    local half = firstDashAfterUppercut(function(lab) lab:setNet("strength", 0.5) end)
    check(half and near(half, 0.40, 0.03), "strength 0.5 corrects half of it (" .. tostring(half) .. ")")
    -- when the animation is played at once there is nothing to correct
    local sim2, lab2 = arena({ping = 160, animMode = "predicted"})
    learnLag(sim2, lab2, 3)
    lab2:setEnabled("supa", true)
    local _, S2 = sim2:press(UPPERCUT, 0.5)
    sim2:run(1.2)
    local arrive
    for _, r in ipairs(sim2.log) do if r.goal == "KeyPress" and r.key == "Q" then arrive = r.arrive; break end end
    check(arrive and near(arrive - S2, 0.32, 0.03), "client-played animations: the delay is used as it is (" .. tostring(arrive and arrive - S2) .. ")")
end
do   -- the dash cooldown began when the server got the dash, a ping before I saw the animation
    local sim, lab = arena({ping = 200, animMode = "server"})
    learnLag(sim, lab, 3)
    lab:dash("W")
    sim:run(0.215)
    check(near(lab:dashLeft("forward"), 4.8 - 0.2 - 0.015, 0.03), "the clock does not wait for the part of the cooldown that already passed: " .. lab:dashLeft("forward"))
    local sim2, lab2 = arena({ping = 200, animMode = "server", jitter = 50})
    learnLag(sim2, lab2, 3)
    lab2:dash("W")
    sim2:run(0.215)
    check(near(lab2:dashLeft("forward"), 4.8 - 0.2 - 0.015 + 0.05, 0.03), "and a jittery connection gets a safety margin: " .. lab2:dashLeft("forward"))
    clean(sim, "dash clock lag")
end
do   -- No End Lag's window is counted from when I sent the side dash
    local function qAfterSideDash(secondsAfterSend)
        local sim, lab = arena({ping = 200, animMode = "server"})
        learnLag(sim, lab, 3)
        lab:setEnabled("noendlag", true)
        lab:dash("D")
        sim:run(secondsAfterSend)
        sim.W:keyDown("Q")
        sim:run(0.2)
        return sim:count({goal = "KeyPress", key = "Q", dash = "W"})
    end
    check(qAfterSideDash(0.8) == 1, "Q 0.8 s after I sent the side dash is inside the 0.85 s window")
    check(qAfterSideDash(0.95) == 0, "0.95 s after sending it is outside (counted from the animation it would still look like 0.75 s)")
end
do   -- a moving target: the hook dash leads him by more when the ping is higher
    local function hookEnd(pingMs, strength)
        local sim, lab = arena({ping = pingMs, rival = false})
        local _, rival = sim:addEnemy("Walker", {6, 3, -20}, {look = {0, 3, 0}})
        sim:walk(rival, {8, 0, 0})
        if strength then lab:setNet("strength", strength) end
        lab:setEnabled("hook", true)
        sim:run(0.3)
        lab:hookSelectNear(sim.W.env.Vector3.new(6, 3, -20))
        local before = sim:pos(sim.meChar)
        lab:fire("hook", {manual = true})
        sim:run(1.2)
        local after = sim:pos(sim.meChar)
        lab:hookClear()
        return after[1], sim
    end
    local x60 = hookEnd(60)
    local x220, simB = hookEnd(220)
    check(x220 - x60 > 1.0, "at ping 220 the dash ends further ahead of a man walking right than at ping 60 (" .. string.format("%.2f vs %.2f", x220, x60) .. ")")
    local f60 = hookEnd(60, 0)
    local f220 = hookEnd(220, 0)
    check(f220 - f60 < 0.3, "with the correction off it does not (" .. string.format("%.2f vs %.2f", f220, f60) .. ")")
    clean(simB, "hook ping")
end
do   -- aim lock leads a moving target by what the network costs
    local function facing(pingMs, strength)
        local sim, lab = arena({ping = pingMs, rival = false})
        local _, rival = sim:addEnemy("Runner", {-15, 3, -10}, {look = {0, 3, 0}})
        sim:walk(rival, {12, 0, 0})
        lab:setOption("lethal", "smooth", 1000)
        if strength then lab:setNet("strength", strength) end
        lab:setEnabled("lethal", true)
        sim:anim(sim.meChar, LETHAL_ANIM, 0.5)
        sim:run(1.95)                                                    -- 1.6 s delay + 0.1 s flick: the lock is on
        local look = sim.meRoot.CFrame.LookVector
        local me, shown = sim:pos(sim.meChar), sim:pos(rival)
        local function angleTo(p)
            local dx, dz = p[1] - me[1], p[3] - me[3]
            local m = math.sqrt(dx * dx + dz * dz)
            local c = (look.X * dx + look.Z * dz) / m
            return math.deg(math.acos(math.max(-1, math.min(1, c))))
        end
        local lead = (pingMs / 2 / 1000 + 0.08) * (strength or 1)
        return angleTo(shown), angleTo({shown[1] + 12 * lead, shown[2], shown[3]}), sim
    end
    local toShown, toPredicted, simA = facing(200)
    check(toPredicted < 1.0 and toShown > 3.0, "at ping 200 the body points at where the runner IS, not where the picture shows him (" .. string.format("%.1f deg off the prediction, %.1f off the picture", toPredicted, toShown) .. ")")
    local plainShown = facing(200, 0)
    check(plainShown < 1.0, "with the correction off it points at the picture (" .. string.format("%.1f", plainShown) .. ")")
    clean(simA, "aim lead")
end
do   -- settings: clamped, a typed ping wins over the measured one, saved and restored
    local sim, lab = arena({ping = 60})
    lab:setNet("manual", 300)
    check(lab:netInfo().ping == 300 and near(lab:lead(), 0.23, 1e-6), "a typed ping replaces the measured one: " .. tostring(lab:netInfo().ping))
    lab:setNet("manual", -5); check(lab.net.manual == 0, "negative is clamped")
    lab:setNet("strength", 99); check(lab.net.strength == 2, "strength is clamped to 2")
    lab:setNet("interp", "x"); check(lab.net.interp == 80, "garbage is ignored")
    lab:setNet("learn", "yes"); check(lab.net.learn == true, "learn is a boolean")
    lab:setNet("bogus", 1)
    lab:setNet("manual", 120); lab:setNet("strength", 0.5); lab:setNet("learn", false)
    local saved = lab:export()
    check(saved.net.manual == 120 and saved.net.strength == 0.5 and saved.net.learn == false, "exported")
    local sim2, lab2 = arena()
    lab2:import({net = {manual = 999999, strength = -3, learn = false, interp = 10, ref = 5, junk = 1}})
    check(lab2.net.manual == 1000 and lab2.net.strength == 0 and lab2.net.learn == false and lab2.net.interp == 10 and lab2.net.ref == 10, "imported values are cleaned")
    lab2:import({net = "garbage"})
    clean(sim, "net settings")
end

------------------------------------------------------------------------------------------------ done
print(string.format("\n%d checks passed, %d failed", passes, #failures))
for _, f in ipairs(failures) do print("FAIL  " .. f) end
if #failures > 0 then os.exit(1) end
