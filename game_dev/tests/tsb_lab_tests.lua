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
        check(lab.byId[d.id] and (type(lab.byId[d.id].run) == "function" or d.poll), d.id .. ": has no sequence")
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
    check(#Lab.DEFS == 20, "20 techs expected, got " .. #Lab.DEFS)
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

------------------------------------------------------------------------------------------------ done
print(string.format("\n%d checks passed, %d failed", passes, #failures))
for _, f in ipairs(failures) do print("FAIL  " .. f) end
if #failures > 0 then os.exit(1) end
