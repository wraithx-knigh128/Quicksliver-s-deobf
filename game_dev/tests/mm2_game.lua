-- The hub played end to end in a SIMULATED Murder Mystery 2 round (tests/mm2_sim.lua): player rigs (R6 / R15), a server that decides who is hit, a network with a ping
-- and an interpolation delay, bots running in patterns, Roblox's camera script. Every number below is about that simulated game - see the header of mm2_sim.lua for the
-- assumptions. Passing means "the hub behaves in a world like this one", never "it works in the real game".
local World, Sim = MM2_WORLD, MM2_SIM
local failures, passes = {}, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures[#failures + 1] = msg end end
local function section(name) print(string.format("--- %s", name)) end
local function P(inst) return rawget(inst, "__d").props end

------------------------------------------------------------------------------------------------ helpers
local function boot(sim, seconds)
    local ok, err = sim.w:load(SCRIPT_SOURCE)
    if not ok then failures[#failures + 1] = "load: " .. tostring(err); return false end
    sim:run((seconds or 1.0) + 0.5)
    return true
end
local function hub(sim) return sim.w.genv.__WraithsHub end
local function clean(sim, name)               -- nothing thrown at the script by the strict world, nothing swallowed by a handler, nothing in the script's own error log
    local w = sim.w
    check(#w.thrown == 0, name .. ": members/types the real Roblox API rejects: " .. table.concat(w.thrown, " | "):sub(1, 600))
    check(#w.errors == 0, name .. ": errors inside handlers/threads: " .. table.concat(w.errors, " | "):sub(1, 600))
    check(#w.warns == 0, name .. ": warn(): " .. table.concat(w.warns, " | "):sub(1, 400))
    local bad = {}
    for _, l in ipairs(hub(sim) and hub(sim).Log or {}) do if l:find("%[") and not l:find("recorded") then bad[#bad + 1] = l end end
    check(#bad == 0, name .. ": the script's own error log is not empty: " .. table.concat(bad, " | "):sub(1, 600))
    check(#sim.unhandled == 0, name .. ": remotes the sim server does not know: " .. table.concat(sim.unhandled, ","))
end
local function toasts(w)
    local out = {}
    for _, i in ipairs(w:findAll(function(i)
        if i.ClassName ~= "TextLabel" then return false end
        local p = i.Parent
        for _ = 1, 4 do
            if not p then return false end
            if p.Name == "Toasts" then return true end
            p = p.Parent
        end
        return false
    end)) do out[#out + 1] = i.Text end
    return out
end
local function hasToast(w, pattern)
    for _, t in ipairs(toasts(w)) do if t:find(pattern) then return true end end
    return false
end
local function espColors(w)
    local out = {}
    for _, h in ipairs(w:findAll(function(i) return i.ClassName == "Highlight" end)) do
        if h.Adornee then out[h.Adornee.Name] = h.FillColor end
    end
    return out
end
local function red(c) return c and c.R > 0.9 and c.G < 0.4 and c.B < 0.4 end
local function blue(c) return c and c.B > 0.9 and c.R < 0.4 and c.G < 0.7 end
local function green(c) return c and c.G > 0.8 and c.R < 0.5 and c.B < 0.6 end
local function orange(c) return c and c.R > 0.9 and c.G > 0.4 and c.G < 0.7 and c.B < 0.3 end
local function tapShoot(sim) sim.w:tap(sim.w:button("Float_shoot"), 1050, 160) end
local function tapThrow(sim) sim.w:tap(sim.w:button("Float_throw"), 1050, 260) end
local function myTool(sim, name)
    local me = sim.me
    for _, c in ipairs(sim.w.M.GetChildren(me.char)) do if c.Name == name then return c end end
    for _, c in ipairs(sim.w.M.GetChildren(sim.w.M.FindFirstChildOfClass(me.plr, "Backpack"))) do if c.Name == name then return c end end
end

-- one shot of the sheriff (me) at the murderer, who runs in a pattern; k varies the start (bearing, phase); returns true when the murderer died
local function trial(o)
    local ang = (o.k or 0) * 0.9 + 0.3
    local dist = o.dist or 50
    local px, pz = math.sin(ang) * dist, -math.cos(ang) * dist
    local beh = {kind = o.kind or "line", speed = o.speed or 16, dx = math.cos(ang), dz = math.sin(ang), radius = 12, phase = (o.k or 0) * 1.3,
                 period = 0.7, run = 1.0, stop = 0.7}
    local sim = Sim.new(o.sim or {})
    sim:spawn("Me", {pos = {0, 3, 0}, rig = o.myRig})
    sim:spawn("Alice", {pos = {px, 3, pz}, move = beh, rig = o.rig})
    sim:spawn("Bob", {pos = {-60, 3, 60}})
    sim:spawn("Cy", {pos = {60, 3, 60}})
    if o.preset then sim:preset(o.preset) end
    sim:startRound{murderer = "Alice", sheriff = "Me"}
    boot(sim, 0.8)
    sim:look(sim.v3(px, 3, pz))                       -- the player looks roughly towards the murderer, like a real tap would
    sim:run(0.3)
    if o.before then o.before(sim) end
    tapShoot(sim)
    sim:run(o.after or 2.0)
    return sim:dead("Alice"), sim
end

------------------------------------------------------------------------------------------------ 1. rigs
section("player rigs: R6 and R15 with every body part")
do
    local sim = Sim.new{}
    local r6 = sim:spawn("Six", {pos = {0, 3, -20}, rig = "R6"})
    local r15 = sim:spawn("Fifteen", {pos = {10, 3, -20}, rig = "R15"})
    local function names(char)
        local out = {}
        for _, c in ipairs(sim.w.M.GetChildren(char)) do if c.ClassName == "Part" then out[c.Name] = c end end
        return out
    end
    local n6, n15 = names(r6.char), names(r15.char)
    for _, nm in ipairs({"HumanoidRootPart", "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}) do check(n6[nm] ~= nil, "R6 has " .. nm) end
    for _, nm in ipairs({"HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"}) do check(n15[nm] ~= nil, "R15 has " .. nm) end
    local c6 = 0; for _ in pairs(n6) do c6 = c6 + 1 end
    local c15 = 0; for _ in pairs(n15) do c15 = c15 + 1 end
    check(c6 == 7 and c15 == 16, "R6 has 7 parts and R15 has 16 (" .. c6 .. ", " .. c15 .. ")")
    check(n15.Head.Position.Y > n15.UpperTorso.Position.Y and n15.UpperTorso.Position.Y > n15.LowerTorso.Position.Y, "R15: head above upper torso above lower torso")
    check(n6.Head.Position.Y > n6.Torso.Position.Y and n6["Left Leg"].Position.Y < n6.Torso.Position.Y, "R6: head above the torso above the legs")
    check(math.abs(n6["Left Arm"].Position.X + n6["Right Arm"].Position.X - 2 * n6.Torso.Position.X) < 1e-6, "R6: arms symmetrical about the torso")
    check(P(r6.hum).RigType == sim.w.Enum.HumanoidRigType.R6 and P(r15.hum).RigType == sim.w.Enum.HumanoidRigType.R15, "rig types on the humanoids")
    check(P(r6.char).PrimaryPart == n6.HumanoidRootPart and P(r15.char).PrimaryPart == n15.HumanoidRootPart, "primary part is the root")
    -- they move as one body
    sim:setBehaviour(r15, {kind = "line", speed = 10, dx = 1, dz = 0})
    sim:run(1.5)
    check(math.abs(n15.LeftFoot.Position.X - n15.Head.Position.X) < 1.0, "R15: the feet stay under the head while it runs")
    check(n15.HumanoidRootPart.Position.X > 10 + 5, "R15 moved along +X (replicated to my screen)")
end

section("the hub shoots both rigs, aiming at the head or the torso")
do
    for _, rig in ipairs({"R6", "R15"}) do
        for _, part in ipairs({"Head", "Torso"}) do
            local dead, sim = trial{k = 2, rig = rig, preset = {aimPart = part}, sim = {ping = 80}}
            check(dead, string.format("sheriff kills a running %s murderer aiming at the %s", rig, part))
            clean(sim, "rig " .. rig .. "/" .. part)
        end
    end
    -- my own rig does not matter either
    local dead = trial{k = 3, myRig = "R6", rig = "R15", sim = {ping = 120}}
    check(dead, "R6 sheriff vs R15 murderer")
end

------------------------------------------------------------------------------------------------ 2. roles and ESP in a round
section("roles + ESP from the round")
do
    local function round(opts)
        local sim = Sim.new(opts)
        sim:spawn("Me", {pos = {0, 3, 0}})
        sim:spawn("Alice", {pos = {0, 3, -40}, move = {kind = "line", speed = 8, dx = 1, dz = 0}})
        sim:spawn("Bob", {pos = {20, 3, -20}})
        sim:spawn("Cy", {pos = {-15, 3, -30}, rig = "R6"})
        sim:startRound{murderer = "Alice", sheriff = "Bob"}
        return sim
    end
    -- the game's data remote tells me everything
    local sim = round{dataRemote = true, botsHold = false}
    boot(sim, 3.5)
    local c = espColors(sim.w)
    check(red(c.Alice) and blue(c.Bob) and green(c.Cy), "colours from the data remote alone (nobody holds a weapon)")
    check(c.Me == nil, "no ESP on myself")
    clean(sim, "roles/data")
    -- no data remote: the weapon in their hand says it
    local sim2 = round{dataRemote = false, botsHold = true}
    boot(sim2, 1.0)
    local c2 = espColors(sim2.w)
    check(red(c2.Alice) and blue(c2.Bob) and green(c2.Cy), "colours from the weapons in their hands")
    clean(sim2, "roles/tools")
    -- no remote, weapons away: nobody is singled out until a weapon comes out - then it is the same frame
    local sim3 = round{dataRemote = false, botsHold = false}
    boot(sim3, 1.0)
    local c3 = espColors(sim3.w)
    check(not red(c3.Alice) and not blue(c3.Bob), "nothing is guessed while all weapons are away")
    sim3:hold("Alice")
    sim3:run(0.05)
    check(red(espColors(sim3.w).Alice), "the knife comes out -> red within 3 frames")
    sim3:hold("Bob")
    sim3:run(0.05)
    check(blue(espColors(sim3.w).Bob), "the gun comes out -> blue within 3 frames")
    clean(sim3, "roles/events")
    -- a new round with other roles: the colours follow, the old ones are gone
    sim:endRound()
    sim:run(0.8)
    check(not red(espColors(sim.w).Alice), "after the round the murderer is not red any more")
    sim:startRound{murderer = "Cy", sheriff = "Alice"}
    sim:run(1.0)
    local c4 = espColors(sim.w)
    check(red(c4.Cy) and blue(c4.Alice) and green(c4.Bob), "next round: Cy murderer, Alice sheriff, Bob innocent")
    clean(sim, "roles/next round")
end

------------------------------------------------------------------------------------------------ 3. the sheriff's shot
section("sheriff: tap SHOOT at a running murderer (hit rate by motion and ping)")
do
    local patterns = {"line", "circle", "zigzag", "stopgo", "jumpy"}
    local pings = {30, 80, 150, 250, 400}
    -- the fewest hits out of 10 that each cell must reach; 0 = reported only (the motion cannot be predicted at that delay by any aim)
    local need = {
        line = {10, 10, 10, 10, 10}, circle = {9, 9, 9, 7, 0}, zigzag = {9, 9, 9, 8, 0}, stopgo = {9, 9, 9, 0, 0}, jumpy = {9, 9, 9, 9, 9},
    }
    local total, totalN = 0, 0
    for _, kind in ipairs(patterns) do
        local row = {}
        for pi, ping in ipairs(pings) do
            local hits, n = 0, 10
            for k = 1, n do if trial{kind = kind, k = k, sim = {ping = ping}} then hits = hits + 1 end end
            total, totalN = total + hits, totalN + n
            row[#row + 1] = string.format("%2d/%d", hits, n)
            check(hits >= need[kind][pi], string.format("%s at ping %d: %d/%d hits (need %d)", kind, ping, hits, n, need[kind][pi]))
        end
        print(string.format("  %-7s ping %s ms: %s", kind, table.concat(pings, "/"), table.concat(row, "  ")))
    end
    print(string.format("  total %d/%d", total, totalN))
    check(total >= 205, "overall hit rate " .. total .. "/" .. totalN)
end

section("sheriff: prediction is what makes the difference")
do
    local off, on = 0, 0
    for k = 1, 10 do
        if trial{k = k, sim = {ping = 150}, preset = {predict = false}} then off = off + 1 end
        if trial{k = k, sim = {ping = 150}} then on = on + 1 end
    end
    check(on == 10 and off <= 3, string.format("line at ping 150: lead on %d/10, lead off %d/10", on, off))
    -- the engine may report no velocity for other players: the hub then uses its own position history
    local noVel = 0
    for k = 1, 10 do if trial{k = k, sim = {ping = 150, reportVelocity = false}} then noVel = noVel + 1 end end
    check(noVel >= 8, "engine reports no velocity: position history still leads (" .. noVel .. "/10)")
    -- the real render delay of other players is not known: the hub assumes 100 ms, a tap must still hit a runner when it is really 40 or 160 ms
    local early, late = 0, 0
    for k = 1, 10 do
        if trial{k = k, sim = {ping = 120, interpMs = 40}} then early = early + 1 end
        if trial{k = k, sim = {ping = 120, interpMs = 160}} then late = late + 1 end
    end
    check(early >= 8 and late >= 8, string.format("render delay really 40 ms: %d/10, really 160 ms: %d/10 (hub assumes 100)", early, late))
    local slow = late
    print(string.format("  line @150 ms: lead on %d/10, off %d/10; no engine velocity %d/10; real render delay 40 ms %d/10, 160 ms %d/10", on, off, noVel, early, late))
end

section("sheriff: the aim survives Roblox's camera script (it rewrites the camera every frame)")
do
    local dead, sim = trial{k = 2, sim = {ping = 80, cameraScript = true}}
    check(dead, "hit with the camera script on")
    -- the camera script puts the player's own view back afterwards
    local look = P(sim.w.camera).CFrame.LookVector
    check(math.abs(look.X - sim.userLook.X) < 1e-3 and math.abs(look.Z - sim.userLook.Z) < 1e-3, "afterwards the camera looks where the player looks again (the hold is released)")
    clean(sim, "camera script")
    -- the weapon in the backpack gets equipped by the hub first
    local sim2 = Sim.new{ping = 80}
    sim2:spawn("Me", {pos = {0, 3, 0}}); sim2:spawn("Alice", {pos = {0, 3, -40}, move = {kind = "line", speed = 16, dx = 1, dz = 0}})
    sim2:startRound{murderer = "Alice", sheriff = "Me"}
    boot(sim2, 0.8)
    check(myTool(sim2, "Gun").Parent ~= sim2.me.char, "the gun starts in the backpack")
    tapShoot(sim2); sim2:run(1.5)
    check(myTool(sim2, "Gun").Parent == sim2.me.char, "...the hub equipped it for the shot")
end

section("sheriff: what the hub will NOT shoot")
do
    -- the murderer is not known (no data, weapons away): nobody is shot
    local sim = Sim.new{dataRemote = false, botsHold = false, ping = 60}
    sim:spawn("Me", {pos = {0, 3, 0}}); sim:spawn("Alice", {pos = {0, 3, -40}}); sim:spawn("Cy", {pos = {20, 3, -30}})
    sim:startRound{murderer = "Alice", sheriff = "Me"}
    boot(sim, 1.0)
    sim:look(sim.v3(0, 3, -40))
    tapShoot(sim); sim:run(2.0)
    check(sim.stats.shots == 0 and not sim:dead("Alice") and not sim:dead("Cy") and not sim:dead("Me"), "murderer unknown: no shot, nobody dies")
    check(hasToast(sim.w, "not known"), "...and it says why")
    clean(sim, "unknown murderer")

    -- an innocent in the line of fire blocks the shot (the hub's line-of-sight check sees players too)
    local sim2 = Sim.new{ping = 60}
    sim2:spawn("Me", {pos = {0, 3, 0}}); sim2:spawn("Alice", {pos = {0, 3, -50}}); sim2:spawn("Cy", {pos = {0, 3, -25}})
    sim2:startRound{murderer = "Alice", sheriff = "Me"}
    boot(sim2, 1.0)
    sim2:look(sim2.v3(0, 3, -50)); sim2:run(0.2)
    tapShoot(sim2); sim2:run(2.0)
    check(sim2.stats.shots == 0 and sim2.stats.friendly == 0 and not sim2:dead("Cy") and not sim2:dead("Me"), "an innocent stands between us: the sheriff does not shoot")
    clean(sim2, "innocent in line")

    -- the murderer behind a wall
    local sim3 = Sim.new{ping = 60}
    sim3:spawn("Me", {pos = {0, 3, 0}}); sim3:spawn("Alice", {pos = {0, 3, -50}})
    sim3:startRound{murderer = "Alice", sheriff = "Me", walls = {{0, 6, -25, 40, 12, 2}}}
    boot(sim3, 1.0)
    sim3:look(sim3.v3(0, 3, -50)); sim3:run(0.2)
    tapShoot(sim3); sim3:run(1.5)
    check(sim3.stats.shots == 0 and not sim3:dead("Alice"), "murderer behind a wall: no shot")
    check(hasToast(sim3.w, "line of sight") or hasToast(sim3.w, "no target"), "...and it says so")
    clean(sim3, "wall")

    -- the round is over (murderer dead): the button does nothing to anybody
    local sim4 = Sim.new{ping = 60}
    sim4:spawn("Me", {pos = {0, 3, 0}}); sim4:spawn("Alice", {pos = {0, 3, -40}}); sim4:spawn("Cy", {pos = {10, 3, -30}})
    sim4:startRound{murderer = "Alice", sheriff = "Me"}
    boot(sim4, 1.0)
    sim4:killActor(sim4:actor("Alice"), sim4:actor("Cy"), "test")
    sim4:run(1.0)
    tapShoot(sim4); sim4:run(1.5)
    check(sim4.stats.shots == 0 and not sim4:dead("Cy") and not sim4:dead("Me"), "murderer already dead: the button shoots nobody")
    clean(sim4, "dead murderer")

    -- an innocent right next to the murderer: across ten starts the sheriff never shoots the wrong one
    local friendly, kills = 0, 0
    for k = 1, 10 do
        local ang = k * 0.9 + 0.3
        local sim5 = Sim.new{ping = 100}
        sim5:spawn("Me", {pos = {0, 3, 0}})
        local px, pz = math.sin(ang) * 45, -math.cos(ang) * 45
        local beh = {kind = "line", speed = 14, dx = math.cos(ang), dz = math.sin(ang)}
        sim5:spawn("Alice", {pos = {px, 3, pz}, move = beh})
        sim5:spawn("Cy", {pos = {px + math.cos(ang) * -3 + math.sin(ang) * 2.2, 3, pz + math.sin(ang) * -3 - math.cos(ang) * 2.2}, move = beh})   -- running right beside her
        sim5:startRound{murderer = "Alice", sheriff = "Me"}
        boot(sim5, 0.8)
        sim5:look(sim5.v3(px, 3, pz)); sim5:run(0.3)
        tapShoot(sim5); sim5:run(2.0)
        friendly = friendly + sim5.stats.friendly
        if sim5:dead("Alice") then kills = kills + 1 end
    end
    check(friendly == 0, "an innocent running beside the murderer was shot " .. friendly .. " times out of 10")
    check(kills >= 8, "...and the murderer still died " .. kills .. "/10")
end

------------------------------------------------------------------------------------------------ 4. the murderer's knife
section("murderer: tap THROW (the knife flies - its speed is learned from the throw)")
do
    local function murdererRound(opts, bobBeh, preset)
        local sim = Sim.new(opts)
        sim:spawn("Me", {pos = {0, 3, 0}})
        sim:spawn("Bob", {pos = {0, 3, -35}, move = bobBeh})
        sim:spawn("Cy", {pos = {50, 3, 50}})
        if preset then sim:preset(preset) end
        sim:startRound{murderer = "Me", sheriff = "Cy"}
        boot(sim, 0.8)
        return sim
    end
    local beh = {kind = "line", speed = 14, dx = 1, dz = 0.3}
    -- 1st throw: the speed is unknown. 2nd throw (after the cooldown): the measured speed is used.
    local sim = murdererRound({ping = 80, knifeSpeed = 80}, beh)
    sim:look(sim.v3(0, 3, -35)); sim:run(0.2)
    tapThrow(sim); sim:run(2.2)
    local learned = hub(sim).Shots.lastWatch and hub(sim).Shots.lastWatch.speed
    check(sim.stats.throws == 1, "the throw reached the server")
    check(learned and math.abs(learned - 80) < 8, "the knife's speed was measured from the real projectile: " .. tostring(learned))
    check(hasToast(sim.w, "Knife thrown") or hasToast(sim.w, "Knife hit") or hasToast(sim.w, "Knife missed"), "toast for the throw")
    local firstDead = sim:dead("Bob")
    sim:run(1.2)                                                       -- the server's knife cooldown (3 s) is over
    if not firstDead then
        local b = sim:actor("Bob")
        sim:look(sim.v3(b.x, 3, b.z)); sim:run(0.2)
        tapThrow(sim); sim:run(2.5)
    end
    check(sim:dead("Bob"), "the second throw, aimed with the measured speed, kills the runner (first throw " .. (firstDead and "already did" or "missed") .. ")")
    clean(sim, "knife learn")

    -- other flying parts appear right after the throw (an effect, a coin, somebody else's projectile): none of them is mistaken for the knife
    local simD = murdererRound({ping = 80, knifeSpeed = 80}, beh)
    simD:look(simD.v3(0, 3, -35)); simD:run(0.2)
    tapThrow(simD)
    local guard = 0
    while not hub(simD).Shots.lastWatch and guard < 120 do simD:run(1 / 60); guard = guard + 1 end      -- the hub is watching for the knife from here on
    check(hub(simD).Shots.lastWatch ~= nil, "(the hub started watching the throw)")
    simD:fly{pos = {2, 3, -2}, vel = {0, 0, -10}, life = 1.5}                  -- too slow
    simD:fly{pos = {3, 3, -2}, vel = {200, 0, 0}, life = 1.5}                  -- fast but not going where I threw
    simD:fly{pos = {-3, 3, -2}, vel = {0, 0, -150}, life = 1.5, zig = 3}        -- fast, the right way, but wobbling: not a straight path
    simD:fly{pos = {0, 3, -200}, vel = {0, 0, -150}, life = 1.5}                -- fast, straight, the right way, but nowhere near me
    simD:run(2.2)
    local lw = hub(simD).Shots.lastWatch
    check(lw and lw.speed and math.abs(lw.speed - 80) < 8, "decoy parts are ignored: the measured speed is the knife's, " .. tostring(lw and lw.speed))
    clean(simD, "knife decoys")

    -- with the speed set by hand the first throw lands
    local sim2 = murdererRound({ping = 80, knifeSpeed = 80}, beh, {knifeSpeed = 80})
    sim2:look(sim2.v3(0, 3, -35)); sim2:run(0.2)
    tapThrow(sim2); sim2:run(2.5)
    check(sim2:dead("Bob"), "knife speed set to 80 by hand: the first throw kills a runner 35 studs away")
    check(hasToast(sim2.w, "Knife hit"), "...and the hub says it hit")
    clean(sim2, "knife manual speed")

    -- a different layout of the knife's remotes
    for _, layout in ipairs({"throw", "other"}) do
        local sim3 = murdererRound({ping = 80, knifeSpeed = 80, knifeLayout = layout}, {kind = "stand"}, {knifeSpeed = 80})
        sim3:look(sim3.v3(0, 3, -35)); sim3:run(0.2)
        tapThrow(sim3); sim3:run(2.0)
        check(sim3:dead("Bob"), "knife remotes laid out as '" .. layout .. "': a standing target dies (the hub presses the throw key, the game's own script sends the remote)")
        clean(sim3, "knife layout " .. layout)
    end

    -- as the murderer the SHOOT button throws too
    local sim4 = murdererRound({ping = 80, knifeSpeed = 80}, {kind = "stand"}, {knifeSpeed = 80})
    sim4:look(sim4.v3(0, 3, -35)); sim4:run(0.2)
    tapShoot(sim4); sim4:run(2.0)
    check(sim4:dead("Bob") and sim4.stats.throws == 1, "the SHOOT button throws the knife when I am the murderer")

    -- the closest player is the target
    local sim5 = Sim.new{ping = 60, knifeSpeed = 80}
    sim5:spawn("Me", {pos = {0, 3, 0}}); sim5:spawn("Far", {pos = {0, 3, -60}}); sim5:spawn("Near", {pos = {25, 3, -10}}); sim5:spawn("Cy", {pos = {-50, 3, 40}})
    sim5:preset({knifeSpeed = 80})
    sim5:startRound{murderer = "Me", sheriff = "Cy"}
    boot(sim5, 0.8)
    sim5:look(sim5.v3(0, 3, -60)); sim5:run(0.2)
    tapThrow(sim5); sim5:run(2.0)
    check(sim5:dead("Near") and not sim5:dead("Far"), "the knife goes to the closest player, not the one I happen to look at")
end

section("sheriff: a gun that really flies (bullet 150 studs/s) - the speed is only used when it is set by hand")
do
    -- the sim's bullet is drawn as a part flying away from me; the hub does NOT take that for the hit speed of a gun (a trail is not how fast the server resolves the hit)
    local sim = Sim.new{ping = 80, gunSpeed = 150}
    sim:spawn("Me", {pos = {0, 3, 0}}); sim:spawn("Alice", {pos = {0, 3, -45}, move = {kind = "line", speed = 14, dx = 1, dz = 0}}); sim:spawn("Cy", {pos = {50, 3, 50}})
    sim:startRound{murderer = "Alice", sheriff = "Me"}
    boot(sim, 0.8)
    sim:look(sim.v3(0, 3, -45)); sim:run(0.2)
    tapShoot(sim); sim:run(2.5)
    local measured = false
    for _, l in ipairs(hub(sim).Log) do if l:find("measured") then measured = true end end
    check(not measured, "the hub does not guess a gun's speed from its bullet trail")
    check(not sim:dead("Alice"), "(so a runner is missed by a travelling bullet at default settings)")
    -- set by hand, the same shot lands
    local hits = 0
    for k = 1, 6 do
        local ang = k * 0.9 + 0.3
        local px, pz = math.sin(ang) * 45, -math.cos(ang) * 45
        local sim2 = Sim.new{ping = 80, gunSpeed = 150}
        sim2:spawn("Me", {pos = {0, 3, 0}}); sim2:spawn("Alice", {pos = {px, 3, pz}, move = {kind = "line", speed = 14, dx = math.cos(ang), dz = math.sin(ang)}})
        sim2:spawn("Cy", {pos = {50, 3, 50}})
        sim2:preset({bulletSpeed = 150})
        sim2:startRound{murderer = "Alice", sheriff = "Me"}
        boot(sim2, 0.8)
        sim2:look(sim2.v3(px, 3, pz)); sim2:run(0.2)
        tapShoot(sim2); sim2:run(2.5)
        if sim2:dead("Alice") then hits = hits + 1 end
    end
    check(hits >= 5, "Bullet speed set to 150: a running murderer is hit " .. hits .. "/6")
end

section("murderer: slash aura")
do
    local sim = Sim.new{ping = 60}
    sim:spawn("Me", {pos = {0, 3, 0}}); sim:spawn("Close", {pos = {0, 3, -3.5}}); sim:spawn("Far", {pos = {30, 3, 0}}); sim:spawn("Cy", {pos = {-40, 3, -30}})
    sim:preset({slashAura = true, slashRange = 9})
    sim:startRound{murderer = "Me", sheriff = "Cy"}
    boot(sim, 1.0)
    sim:run(1.5)
    check(sim:dead("Close"), "the slash aura stabs someone standing next to me")
    check(not sim:dead("Far"), "...and not the one 30 studs away")
    clean(sim, "slash aura")
end

------------------------------------------------------------------------------------------------ 5. the dropped gun
section("sheriff killed -> the gun drops -> GRAB GUN -> hero shoots the murderer")
do
    local sim = Sim.new{ping = 100}
    sim:spawn("Me", {pos = {0, 3, 0}})
    sim:spawn("Alice", {pos = {40, 3, -40}, move = {kind = "line", speed = 12, dx = -1, dz = 0}})
    sim:spawn("Bob", {pos = {-25, 3, -25}})
    sim:spawn("Cy", {pos = {20, 3, 30}})
    sim:preset({btnGrab = true})
    sim:startRound{murderer = "Alice", sheriff = "Bob"}
    boot(sim, 1.5)
    sim:killActor(sim:actor("Bob"), sim:actor("Alice"), "knife")
    sim:run(0.6)
    check(hasToast(sim.w, "Gun dropped"), "a toast says the gun dropped")
    local drop = sim.w:find(function(i) return i.Name == "GunDrop" end, sim.w.workspace)
    check(drop ~= nil, "the dropped gun exists on my screen")
    local c = espColors(sim.w)
    check(c.GunDrop and orange(c.GunDrop), "the gun drop is highlighted orange")
    check(not red(c.Bob) and not blue(c.Bob), "the dead sheriff is not coloured any more")
    local before = sim.me.x
    sim.w:tap(sim.w:button("Float_grab"), 1050, 360)
    sim:run(1.6)
    check(sim.stats.pickups == 1, "the server gave me the gun (pickups: " .. sim.stats.pickups .. ")")
    check(myTool(sim, "Gun") ~= nil, "the Gun tool is in my backpack")
    check(math.abs(sim.me.x - before) < 1 and math.abs(sim.me.z) < 1, "the hub put me back where I stood")
    check(sim.me.role == "Hero", "I am the hero now")
    sim:run(1.0)
    local a = sim:actor("Alice")
    sim:look(sim.v3(a.x, 3, a.z)); sim:run(0.3)
    tapShoot(sim); sim:run(2.0)
    check(sim:dead("Alice"), "the hero shoots the murderer with the picked up gun")
    clean(sim, "gun drop")
end

------------------------------------------------------------------------------------------------ 6. recorded shots, silent aim
section("a shot the player made by hand is recorded, then replayed at the murderer")
do
    local sim = Sim.new{ping = 80, gunLayout = "shoot"}
    sim:spawn("Me", {pos = {0, 3, 0}})
    sim:spawn("Alice", {pos = {30, 3, -40}, move = {kind = "line", speed = 12, dx = 0, dz = -1}})
    sim:spawn("Cy", {pos = {-30, 3, -20}})
    sim:preset({fireMethod = "Remote replay"})
    sim:startRound{murderer = "Alice", sheriff = "Me", hold = true}
    boot(sim, 1.0)
    -- with nothing recorded yet, "Remote replay" cannot fire: the button reports it
    sim:look(sim.v3(30, 3, -40)); sim:run(0.2)
    tapShoot(sim); sim:run(0.8)
    check(sim.stats.shots == 0 and hasToast(sim.w, "recorded"), "no recorded shot yet: the hub says so instead of pretending")
    -- the player shoots by hand at empty ground to the left (a miss) - the call is recorded
    sim:look(sim.v3(-60, 3, -10)); sim:run(0.1)
    sim:click(); sim:run(0.5)
    check(sim.stats.shots == 1 and not sim:dead("Alice"), "a manual shot into nothing")
    check(hub(sim).Shots.templates.Gun ~= nil, "the hub recorded it")
    sim:run(2.5)                                                       -- the gun reloads
    local a = sim:actor("Alice")
    sim:look(sim.v3(a.x, 3, a.z)); sim:run(0.2)
    tapShoot(sim); sim:run(2.0)
    check(sim:dead("Alice"), "the recorded shot, replayed at the predicted position, kills the murderer (remote layout: Gun.Remotes.Shoot(originCF, aim, hitPart))")
    clean(sim, "replay")

    -- silent aim: my own hand-made shot is sent at the murderer instead of where I clicked
    local sim2 = Sim.new{ping = 80, gunLayout = "shoot"}
    sim2:spawn("Me", {pos = {0, 3, 0}})
    sim2:spawn("Alice", {pos = {30, 3, -40}, move = {kind = "line", speed = 12, dx = 0, dz = -1}})
    sim2:spawn("Cy", {pos = {-30, 3, -20}})
    sim2:preset({silentAim = true})
    sim2:startRound{murderer = "Alice", sheriff = "Me", hold = true}
    boot(sim2, 1.0)
    sim2:look(sim2.v3(-60, 3, -10)); sim2:run(0.1)
    sim2:click(); sim2:run(0.5)                                         -- first shot: nothing to copy yet - it goes where I clicked
    check(not sim2:dead("Alice"), "silent aim has nothing recorded for the first shot")
    sim2:run(2.5)
    sim2:click(); sim2:run(1.0)
    check(sim2:dead("Alice"), "silent aim: the second manual click, aimed at empty ground, kills the murderer")
    clean(sim2, "silent aim")
end

------------------------------------------------------------------------------------------------ 7. feedback
section("the hub tells whether the shot hit")
do
    local dead, sim = trial{k = 2, sim = {ping = 80}}
    check(dead and hasToast(sim.w, "Shot hit"), "a kill is reported as a hit")
    check(hub(sim).Shots.lastResult and hub(sim).Shots.lastResult.hit == true, "...and recorded")
    -- a shot that cannot land: stop-and-go at a very high ping
    local missed, sim2 = false, nil
    for k = 1, 10 do
        local d, s = trial{kind = "stopgo", k = k, sim = {ping = 400}}
        if not d then missed, sim2 = true, s; break end
    end
    check(missed and sim2, "(found a shot that misses)")
    if sim2 then
        check(hasToast(sim2.w, "Shot missed"), "a miss is reported too - not 'shot fired' and silence")
        check(hub(sim2).Shots.lastResult and hub(sim2).Shots.lastResult.hit == false, "...and recorded")
    end
end

------------------------------------------------------------------------------------------------ 7b. the floating buttons tell what a tap will do
section("floating buttons: status line, pip, reload bar, ripple, HIT / MISS")
do
    local function parts(sim, id)
        local b = sim.w:button("Float_" .. id)
        local M = sim.w.M
        return {btn = b, status = M.FindFirstChild(b, "Status"), pip = M.FindFirstChild(b, "Pip"), track = M.FindFirstChild(b, "ProgressTrack"),
                fill = M.FindFirstChild(M.FindFirstChild(b, "ProgressTrack"), "Progress"), shade = M.FindFirstChild(b, "Cooldown"), outline = M.FindFirstChild(b, "Outline")}
    end
    local sim = Sim.new{ping = 80}
    sim:spawn("Me", {pos = {0, 3, 0}})
    sim:spawn("Alice", {pos = {0, 3, -40}, move = {kind = "line", speed = 4, dx = 1, dz = 0}})
    sim:spawn("Cy", {pos = {30, 3, 30}})
    sim:preset({btnGrab = true})
    boot(sim, 1.0)
    local sh, th = parts(sim, "shoot"), parts(sim, "throw")
    check(sh.status.Text == "NO GUN" and th.status.Text == "NO KNIFE", "before the round: NO GUN / NO KNIFE (" .. sh.status.Text .. " / " .. th.status.Text .. ")")
    check(red(sh.pip.BackgroundColor3) or sh.pip.BackgroundColor3.R > 0.8, "...with a red pip")
    sim:startRound{murderer = "Alice", sheriff = "Me"}
    sim:run(1.0)
    check(sh.status.Text:find("^Alice  4%d?m$") or sh.status.Text:find("^Alice  %d+m$"), "sheriff, murderer in sight: the SHOOT line names the target and the distance (" .. sh.status.Text .. ")")
    check(green(sh.pip.BackgroundColor3), "...with a green pip")
    check(th.status.Text:find("^Alice") ~= nil, "the THROW button names the same target: as the sheriff it shoots (" .. th.status.Text .. ")")
    check(sh.track.Visible == false and sh.shade.BackgroundTransparency == 1, "no reload bar and nothing over the inside while ready")
    -- a tap: the ring spreads, the shot is a hit, HIT is shown, the reload bar fills
    sim:look(sim.v3(sim:actor("Alice").x, 3, sim:actor("Alice").z)); sim:run(0.2)
    sim.w:press(sh.btn, 1050, 160)
    check(sim.w.M.FindFirstChild(sh.btn, "Ripple") ~= nil, "a ring spreads from a tap")
    sim.w:release(1050, 160)
    sim:run(0.5)
    check(sim.w.M.FindFirstChild(sh.btn, "Ripple") == nil, "...and is gone half a second later")
    check(sh.track.Visible, "the reload bar is showing")
    local waited = 0
    while not (hub(sim).Shots.lastResult) and waited < 3 do sim:run(1 / 60); waited = waited + 1 / 60 end
    check(hub(sim).Shots.lastResult and hub(sim).Shots.lastResult.hit == true, "the verdict arrives: hit")
    check(sh.status.Text == "HIT", "the button shows HIT the moment the verdict is in (" .. sh.status.Text .. ")")
    sim:run(1.0)
    check(sh.status.Text == "HIT", "...and keeps it for a moment")
    sim:run(2.0)
    check(sh.status.Text ~= "HIT", "HIT does not stay on (" .. sh.status.Text .. ")")
    sim:run(1.5)
    check(sh.track.Visible == false, "the bar is gone when the reload is over")
    check(sim:dead("Alice"), "(the shot killed her)")
    clean(sim, "buttons")

    -- a miss shows MISS
    local missSim
    for k = 1, 10 do
        local ang = k * 0.9 + 0.3
        local px, pz = math.sin(ang) * 50, -math.cos(ang) * 50
        local s2 = Sim.new{ping = 400}
        s2:spawn("Me", {pos = {0, 3, 0}}); s2:spawn("Alice", {pos = {px, 3, pz}, move = {kind = "stopgo", speed = 16, dx = math.cos(ang), dz = math.sin(ang), run = 1.0, stop = 0.7}})
        s2:spawn("Cy", {pos = {60, 3, 60}})
        s2:startRound{murderer = "Alice", sheriff = "Me"}
        boot(s2, 0.8)
        s2:look(s2.v3(px, 3, pz)); s2:run(0.3)
        tapShoot(s2)
        local t = 0
        while not hub(s2).Shots.lastResult and t < 4 do s2:run(1 / 60); t = t + 1 / 60 end
        if hub(s2).Shots.lastResult and hub(s2).Shots.lastResult.hit == false then missSim = s2; break end
    end
    check(missSim ~= nil, "(found a shot that misses)")
    if missSim then
        local p = parts(missSim, "shoot")
        check(p.status.Text == "MISS", "a miss shows MISS on the button the moment the verdict is in (" .. p.status.Text .. ")")
        missSim:run(2.0)
        check(p.status.Text ~= "MISS", "...and it goes away")
    end

    -- the murderer is not known: the line says so instead of naming a target
    local sim2 = Sim.new{dataRemote = false, botsHold = false, ping = 60}
    sim2:spawn("Me", {pos = {0, 3, 0}}); sim2:spawn("Alice", {pos = {0, 3, -40}})
    sim2:startRound{murderer = "Alice", sheriff = "Me"}
    boot(sim2, 1.0)
    check(parts(sim2, "shoot").status.Text == "MURDERER?", "murderer unknown: MURDERER? (" .. parts(sim2, "shoot").status.Text .. ")")
    -- the murderer's THROW button
    local sim3 = Sim.new{ping = 60}
    sim3:spawn("Me", {pos = {0, 3, 0}}); sim3:spawn("Bob", {pos = {0, 3, -22}}); sim3:spawn("Cy", {pos = {40, 3, 40}})
    sim3:startRound{murderer = "Me", sheriff = "Cy"}
    boot(sim3, 1.0)
    local t3 = parts(sim3, "throw")
    check(t3.status.Text:find("^Bob  2[12]m$") ~= nil, "murderer: THROW names the closest player (" .. t3.status.Text .. ")")
    check(parts(sim3, "shoot").status.Text:find("^Bob") ~= nil, "...and SHOOT, which throws for a murderer, names the same one")
    -- the gun drop
    local sim4 = Sim.new{ping = 60}
    sim4:spawn("Me", {pos = {0, 3, 0}}); sim4:spawn("Alice", {pos = {40, 3, -40}}); sim4:spawn("Bob", {pos = {-20, 3, -15}})
    sim4:preset({btnGrab = true})
    sim4:startRound{murderer = "Alice", sheriff = "Bob"}
    boot(sim4, 1.0)
    check(parts(sim4, "grab").status.Text == "NO GUN DROP", "GRAB GUN: NO GUN DROP while the sheriff lives (" .. parts(sim4, "grab").status.Text .. ")")
    sim4:killActor(sim4:actor("Bob"), sim4:actor("Alice"), "knife")
    sim4:run(1.0)
    check(parts(sim4, "grab").status.Text:find("^GUN  2%d?m$") ~= nil, "...and GUN 25m once it dropped (" .. parts(sim4, "grab").status.Text .. ")")
end

------------------------------------------------------------------------------------------------ 8. player mods
section("walk speed / jump power in the simulated game")
do
    local function run(opts, preset, seconds)
        local sim = Sim.new(opts)
        sim:spawn("Me", {pos = {0, 3, 0}}); sim:spawn("Alice", {pos = {0, 3, -80}})
        if preset then sim:preset(preset) end
        sim:startRound{murderer = "Alice", sheriff = "Me"}
        boot(sim, 0.8)
        local x0 = sim.me.x
        sim:setMove(1, 0)
        sim:run(seconds or 3)
        sim:setMove(0, 0)
        return sim, sim.me.x - x0
    end
    local _, plain = run({ping = 60})
    check(math.abs(plain - 48) < 3, "no mod: 16 studs/s for 3 s = " .. string.format("%.1f", plain))
    local sim, fast = run({ping = 60}, {walkOn = true, walkSpeed = 24})
    check(math.abs(fast - 72) < 4, "walk speed 24: " .. string.format("%.1f", fast) .. " studs in 3 s (72 expected)")
    clean(sim, "walk speed")
    -- a game script that puts WalkSpeed back whenever it changes: the hub notices the value never sticks and moves the character itself
    local sim2, locked = run({ping = 60, speedPolicy = "clientlock"}, {walkOn = true, walkSpeed = 24})
    check(math.abs(locked - 72) < 6, "WalkSpeed locked by the game: still " .. string.format("%.1f", locked) .. " studs in 3 s (72 expected)")
    clean(sim2, "walk speed lock")
    -- jumping
    local function apex(preset)
        local sim3 = Sim.new{ping = 60}
        sim3:spawn("Me", {pos = {0, 3, 0}}); sim3:spawn("Alice", {pos = {0, 3, -80}})
        if preset then sim3:preset(preset) end
        sim3:startRound{murderer = "Alice", sheriff = "Me"}
        boot(sim3, 0.8)
        local top = 0
        sim3:jump()
        for _ = 1, 60 do sim3:run(1 / 60); top = math.max(top, sim3.me.y - 3) end
        return top
    end
    local a50, a100 = apex(nil), apex({jumpOn = true, jumpPower = 100})
    check(math.abs(a50 - 6.4) < 0.5, "jump power 50 rises about 6.4 studs: " .. string.format("%.2f", a50))
    check(math.abs(a100 - 25.5) < 1.5, "jump power 100 rises about 25.5 studs: " .. string.format("%.2f", a100))
end

------------------------------------------------------------------------------------------------ done
print(string.format("\n%d checks passed, %d failed", passes, #failures))
for _, f in ipairs(failures) do print("FAIL  " .. f) end
if #failures > 0 then os.exit(1) end
