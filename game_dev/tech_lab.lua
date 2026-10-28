--[[
    tech_lab.lua - the Tech Lab: Strongest Battlegrounds techs as small sequences on one shared engine.

    The script you uploaded had the same skeleton copied five times (see an animation -> wait -> do something -> hope nothing was left behind). Here the skeleton
    exists ONCE and every tech is only its sequence:

        trigger  ->  checks (enabled, cooldown, dash ready, macro running)  ->  sequence(ctx)  ->  cleanup, whatever happened

    The engine gives every sequence the same safe tools through `ctx`: ctx.wait (stops the moment you die, switch the tech off or press Panic), ctx.target, ctx.dash /
    ctx.m1 / ctx.move (the game's own Communicate remote, keys as a fallback), ctx.moveTo, ctx.push (a velocity that is always removed again), ctx.faceLoop, ctx.lockRotation,
    ctx.aimCamera ... and everything a sequence creates is destroyed when it ends - an error half way cannot leave you spinning, locked or stuck to somebody.

    New in the engine (the original had none of it): ONE animation hook for all techs, dash cooldown tracking (a tech that starts with a dash does not start while the
    dash is on cooldown), "busy" awareness (not while a combo macro plays), a Panic that cancels everything, per-tech status text and counters, options that are
    clamped and saved only with Save config, learned trigger ids, and nothing is waited for with Tween.Completed (a cancelled tween never finishes - ctx.moveTo does not hang).

    It never touches a Roblox global at load time, so it can be bundled and unit-tested with a fake world.  Used as:
        local lab = TechLab.new({Players=, RunService=, UserInputService=, Workspace=, LocalPlayer=, VirtualInput=, TechMath=, TechData=, TechOptions=,
                                 connect=, safe=, clock=, pingMs=, busy=, log=, toast=, onStatus=})
        lab:setEnabled("supa", true)       lab:fire("hook")       lab:cancelAll()       lab:export()  lab:import(table)  lab:destroy()

    Credits: the tech ideas (Supa, Hook Dash, Loop Dash, Kyoto, Lethal Dash, M1 Reset, Twisted, Kiba / Kitty Tech by ItzSoph, ...) come from the script you uploaded;
    this file is a rewrite, not a copy, and nothing in it has been run in the real game.
]]

local M = {}

local atan2 = math.atan2 or math.atan

local function N(key, label, min, max, step, default, tip) return {key = key, label = label, kind = "number", min = min, max = max, step = step, default = default, tip = tip} end
local function B(key, label, default, tip) return {key = key, label = label, kind = "bool", default = default, tip = tip} end
local function C(key, label, choices, default, tip) return {key = key, label = label, kind = "choice", choices = choices, default = default, tip = tip} end
local function S(key, label, default, tip) return {key = key, label = label, kind = "string", default = default, tip = tip} end

local KEYS = {"V", "C", "X", "Z", "B", "G", "H", "J", "K", "L", "R", "T"}

----------------------------------------------------------------------------------------------------------------- the tech catalogue (definitions only)
-- group, title, desc, when = text shown as "starts: ...", needsDash = "forward" | "side" | nil, ids = trigger animation list name in TechData.ANIM (or nil)
local DEFS = {
    {id = "supa", group = "Dash techs", title = "Supa Tech", needsDash = "forward", ids = "uppercut", when = "after your uppercut",
     desc = "Dash in on them: after your uppercut it dashes, snaps under them, finishes behind them and dashes again.",
     opts = {N("delay", "Delay after the uppercut (ms)", 0, 600, 5, 320), N("speed", "Dash-in speed (x)", 0.5, 2.5, 0.1, 1), N("radius", "Search radius (studs)", 10, 100, 5, 50),
             N("under", "Depth under them (studs)", 0, 8, 0.5, 3), N("lock", "Look-at lock (%)", 0, 100, 5, 100), N("jitter", "Random look offset (studs)", 0, 12, 1, 6),
             B("behind", "Finish behind them (teleport)", true, "Ends a few studs behind their back and dashes again."), N("behindOffset", "Finish distance (studs)", 1, 12, 0.5, 5),
             N("cooldown", "Cooldown (s)", 0, 5, 0.1, 1)}},
    {id = "hook", group = "Dash techs", title = "Hook Dash", needsDash = "side", manual = true, when = "V = pick a target, C = go (phone: double tap them, then the button)",
     desc = "A side dash that passes the target on its side and overshoots, then throws an M1 and holds your camera on them. Pick the target with V (the player nearest your cursor), go with C.",
     opts = {N("maxDist", "Max distance (studs)", 10, 80, 1, 35), N("range", "Pass range (studs)", 0, 8, 0.5, 2), N("prediction", "Prediction (s)", 0, 1, 0.05, 0.3),
             N("reach", "Overshoot (studs)", 0, 15, 0.5, 6.5), N("duration", "Dash time (s)", 0.05, 0.4, 0.01, 0.15), N("m1Delay", "M1 after (s)", 0, 0.4, 0.01, 0.11),
             C("side", "Pass them on", {"Closest", "Behind them", "Left", "Right"}, "Closest"), C("face", "Body while dashing", {"Side-on", "Face target"}, "Side-on"),
             N("smooth", "Turn smoothness", 0.05, 1, 0.05, 0.4), B("m1After", "M1 at the end", true), N("aimAfter", "Aim lock after (s)", 0, 1, 0.05, 0.5),
             N("maxY", "Ignore above height (0 = off)", 0, 1000, 1, 442), B("highlight", "Highlight the target", true), N("cooldown", "Cooldown (s)", 0, 5, 0.1, 1),
             C("selectKey", "Select key", KEYS, "V"), C("goKey", "Go key", KEYS, "C")}},
    {id = "loop", group = "Dash techs", title = "Loop Dash", needsDash = "forward", ids = "uppercut", when = "after your uppercut",
     desc = "A loop round the target while dashing, then you settle above them.",
     opts = {N("delay", "Delay (ms)", 0, 500, 5, 160), N("radius", "Loop radius (studs)", 2, 10, 0.5, 6), N("targetRadius", "Target within (studs)", 5, 40, 1, 15),
             N("maxHeight", "Max height (studs)", 2, 20, 1, 10), N("orbitTime", "Loop time (s)", 0.2, 1, 0.05, 0.5), N("dashEvery", "Dash every (ms)", 20, 300, 10, 80),
             N("settle", "Settle time (ms)", 0, 500, 10, 120), N("hold", "Settle hold (ms)", 100, 1500, 50, 600), N("cooldown", "Cooldown (s)", 0, 5, 0.1, 1)}},
    {id = "loop2", group = "Dash techs", title = "Loop Dash 2", needsDash = "forward", ids = "uppercut", template = "jumpLock", when = "after your uppercut",
     desc = "Better loop dash (also for oreo tech): jump, dash, then lock your body on the target. Pauses while someone is blocking.",
     opts = {N("detect", "Delay (s)", 0, 2, 0.05, 0.3), B("jump", "Jump assist", true, "Forces the jump (use it for oreo tech)."), N("jumpPower", "Jump height", 10, 100, 1, 52),
             N("flick", "First flick delay (s)", 0, 1, 0.05, 0.1), N("smooth", "Smoothness", 1, 1000, 1, 600), N("lock", "Lock time (s)", 0, 3, 0.1, 1.5),
             N("radius", "Target within (studs)", 5, 100, 1, 50), B("pauseOnBlock", "Pause while someone blocks", true), N("cooldown", "Cooldown (s)", 0, 5, 0.1, 1)}},
    {id = "lethal", group = "Dash techs", title = "Lethal Dash", needsDash = "forward", ids = "lethalWhirlwind", template = "jumpLock", when = "after Lethal Whirlwind Stream",
     desc = "Lethal water into a dash: jump, dash and lock on to the target once the move is over.",
     opts = {N("detect", "Delay (s)", 0, 3, 0.05, 1.6), B("jump", "Jump assist", true), N("jumpPower", "Jump height", 10, 100, 1, 52), N("flick", "First flick delay (s)", 0, 1, 0.05, 0.1),
             N("smooth", "Smoothness", 1, 1000, 1, 300), N("lock", "Lock time (s)", 0, 3, 0.1, 1.6), N("radius", "Target within (studs)", 5, 100, 1, 25),
             B("pauseOnBlock", "Pause while someone blocks", true), N("cooldown", "Cooldown (s)", 0, 5, 0.1, 0)}},
    {id = "kiba", group = "Dash techs", title = "Kiba / Kitty Tech", needsDash = "forward", ids = "uppercut", when = "after your uppercut",
     desc = "After the uppercut: dash and hang on the target head-down (Kiba), or circle them (Kitty Tech, idea by ItzSoph).",
     opts = {C("mode", "Style", {"Hang (Kiba)", "Orbit (Kitty)"}, "Hang (Kiba)"), N("delay", "Delay (ms)", 0, 600, 5, 320), N("radius", "Target within (studs)", 3, 30, 1, 10),
             N("hold", "Hold time (s)", 0.2, 1.5, 0.05, 0.5), N("pitch", "Hang angle (deg)", 0, 120, 5, 85), N("orbitRadius", "Orbit radius", 1, 8, 0.5, 3), N("orbitHeight", "Orbit height", 0, 5, 0.5, 1),
             N("spin", "Orbit lap time (s)", 0.3, 2, 0.1, 0.6), B("pingWait", "Wait for my ping before the dash (Orbit)", true), N("cooldown", "Cooldown (s)", 0, 8, 0.1, 0.5)}},
    {id = "twisted", group = "Dash techs", title = "Twisted (4 M1 into a dash)", needsDash = "forward", ids = "twisted", when = "after the M1 string's last move",
     desc = "A small step back, then a dash at them. 'Instant' also turns you to face them during the dash.",
     opts = {N("wait", "Wait before the step (ms)", 0, 600, 5, 230), N("stepBack", "Step back (studs)", 0, 10, 0.1, 3.4), C("dashKey", "Dash direction", {"W", "A", "S", "D"}, "W"),
             B("instant", "Instant: face them while dashing", false), N("cooldown", "Cooldown (s)", 0, 10, 0.1, 5)}},
    {id = "kyoto", group = "Combos", title = "Auto Kyoto", ids = "flowingWater", when = "after Flowing Water",
     desc = "Flowing water into lethal: casts Lethal Whirlwind Stream for you, then hops sideways.",
     opts = {N("wait", "Wait after Flowing Water (s)", 0.3, 3, 0.05, 1.5), N("startDelay", "Extra delay (ms)", 0, 1000, 10, 0), N("distance", "Hop distance (studs)", 0, 50, 1, 20),
             N("hopTime", "Hop time (ms)", 50, 500, 10, 150), B("hotbar", "Press hotbar 1 and 2 around the hop", true), S("moveName", "Move to cast (empty = Lethal Whirlwind Stream)", ""),
             N("cooldown", "Cooldown (s)", 0, 8, 0.1, 3)}},
    {id = "dunk", group = "Combos", title = "Lethal Dunk", ids = "lethalWhirlwind", when = "after Lethal Whirlwind Stream",
     desc = "Lifts you above them a moment after Lethal Whirlwind Stream.",
     opts = {N("wait", "Wait (s)", 0, 3, 0.05, 1), N("height", "Lift (studs)", 0, 150, 5, 70), N("cooldown", "Cooldown (s)", 0, 8, 0.1, 1)}},
    {id = "surf", group = "Combos", title = "Auto Hunter Surf", ids = "surf", when = "when the surf starts",
     desc = "Carries you forward on the surf.",
     opts = {N("wait", "Wait (s)", 0, 2, 0.05, 0.6), N("distance", "Distance (studs)", 0, 120, 5, 50), N("time", "Time (s)", 0.2, 2, 0.02, 0.78), N("cooldown", "Cooldown (s)", 0, 8, 0.1, 2)}},
    {id = "counter", group = "Defence", title = "Auto Counter", observer = true, when = "when somebody dashes / M1s at you",
     desc = "Casts your counter (Prey's Peril / Split Second Counter) when a close player starts a dash or an M1 at you.",
     opts = {N("distance", "Counter distance (studs)", 5, 30, 1, 13), B("facing", "Only when they face me", true), B("answerDashes", "Answer dashes", true), B("answerM1", "Answer M1s", true),
             N("dashDelay", "Delay after a dash (ms)", 0, 300, 5, 0), S("moveName", "Move to cast (empty = automatic)", ""), N("cooldown", "Cooldown (s)", 0, 3, 0.1, 0.6)}},
    {id = "flip", group = "Helpers", title = "Dash Flip", ids = "forwardDash", when = "after your forward dash",
     desc = "Pitches you up a little while you dash (the tech helper's flip).",
     opts = {N("delay", "Delay (ms)", 0, 600, 5, 300), N("hold", "Hold (ms)", 50, 500, 10, 150), N("lock", "Flip (%)", 0, 100, 5, 50), B("lookUp", "Look up (off = look down)", true),
             N("cooldown", "Cooldown (s)", 0, 3, 0.1, 0.5)}},
    {id = "catch", group = "Helpers", title = "M1 Catch", poll = true, when = "while somebody is in front of you",
     desc = "Holds M1 for you when somebody steps into the box in front of you.",
     opts = {N("range", "Range (studs)", 2, 20, 1, 13), N("halfWidth", "Half width (studs)", 1, 6, 0.5, 2), N("hold", "Hold (ms)", 10, 1000, 10, 200), N("lead", "Prediction (%)", 0, 100, 5, 0)}},
    {id = "mousedash", group = "Helpers", title = "Mouse Dash", ids = "forwardDash", when = "after your forward dash",
     desc = "Turns you toward your cursor for a moment after a forward dash, so the dash goes where you point.",
     opts = {N("window", "How long (ms)", 100, 3000, 50, 500)}},
    {id = "sidem1", group = "Helpers", title = "Side M1 (hitbox abuse)", mouse = true, when = "when you click",
     desc = "Swings your body to the side for a moment when you M1, then back. PC only.",
     opts = {N("angle", "Angle (deg)", 0, 180, 5, 45), N("duration", "Duration (ms)", 10, 500, 10, 50), N("delay", "Delay (ms)", 0, 200, 5, 0), B("silent", "Only turn the body (not the camera)", false)}},
    {id = "noendlag", group = "Helpers", title = "No End Lag", key = "Q", when = "Q right after a side dash",
     desc = "Press Q within a moment of a side dash and the forward dash goes out at once.",
     opts = {N("window", "Window (s)", 0.3, 1.5, 0.05, 0.85), C("dashKey", "Dash direction", {"W", "A", "S", "D"}, "W")}},
    {id = "slidem1", group = "Helpers", title = "M1 Slide", ids = "sideDash", when = "after a side dash",
     desc = "Throws an M1 for you right after every side dash.",
     opts = {N("cooldown", "Cooldown (s)", 0.3, 3, 0.1, 1.5)}},
    {id = "downslam", group = "Helpers", title = "True Down Slam", ids = "slam", when = "when your down slam starts",
     desc = "Lifts you when your down slam starts with somebody close, so it lands as the aerial one.",
     opts = {N("radius", "Somebody within (studs)", 5, 40, 1, 15), N("lift", "Lift (studs)", 0, 15, 1, 6), N("liftTime", "Lift time (s)", 0.1, 1, 0.05, 0.35)}},
    {id = "m1reset", group = "Actions", title = "M1 Reset", manual = true, key = "R", when = "key / button",
     desc = "Side step, turn and dash - resets your M1 chain.",
     opts = {N("distance", "Step (studs)", 0, 60, 0.5, 25.5), N("duration", "Step time (s)", 0.1, 0.6, 0.01, 0.22), N("rotation", "Turn (deg)", 0, 180, 5, 65),
             C("dashAfter", "Dash after", {"W", "A", "S", "D", "None"}, "W"), N("cooldown", "Cooldown (s)", 0, 3, 0.1, 0.2), C("key", "Key", KEYS, "R")}},
    {id = "emotedash", group = "Actions", title = "Emote Dash", manual = true, key = "T", when = "key / button",
     desc = "Turns and throws you sideways in an arc.",
     opts = {N("rotation", "Turn (deg)", 0, 180, 5, 90), N("distance", "Distance", 0, 80, 1, 38), N("height", "Height", 0, 30, 1, 8), N("power", "Power", 20, 200, 5, 95),
             N("duration", "Duration (s)", 0.1, 0.6, 0.01, 0.27), N("cooldown", "Cooldown (s)", 0, 3, 0.1, 0.2), C("key", "Key", KEYS, "T")}},
}
M.DEFS = DEFS

local GROUPS = {"Dash techs", "Combos", "Defence", "Helpers", "Actions"}
M.GROUPS = GROUPS

-- techs that move or turn my character: only one of them runs at a time (two of them at once would fight over the root part)
local MOVES = {supa = true, hook = true, loop = true, loop2 = true, lethal = true, kiba = true, twisted = true, kyoto = true, dunk = true, surf = true, flip = true,
               mousedash = true, sidem1 = true, downslam = true, m1reset = true, emotedash = true}

----------------------------------------------------------------------------------------------------------------- the engine
function M.new(env)
    local Players, RunService, UIS, Workspace, LocalPlayer = env.Players, env.RunService, env.UserInputService, env.Workspace, env.LocalPlayer
    local TM, TD, TO = env.TechMath, env.TechData, env.TechOptions
    local clock = env.clock or os.clock
    local connect = env.connect or function(sig, fn) return sig:Connect(fn) end
    local safe = env.safe or function(fn, ...) local ok, r = pcall(fn, ...) if ok then return r end end
    local log = env.log or function() end

    local lab = {techs = {}, order = {}, byId = {}, alive = true, master = true, input = "Auto", dashGuard = true, releaseBlock = true,
                 dashClock = TM.dashClock(TD.DASH_COOLDOWN), hook = {}, conns = {}, lastOwn = {}}
    local charConns = {}
    local watched = setmetatable({}, {__mode = "k"})              -- enemy model -> its connections
    local animCache = {}
    local ownTracks = setmetatable({}, {__mode = "k"})             -- tracks the Tech Lab played itself: they must not trigger techs or the dash clock
    local blockSet = TD.set(TD.ANIM.block)
    local SIDE_ID = {Right = TD.ANIM.sideRight[1], Left = TD.ANIM.sideLeft[1]}

    local function num(x) return type(x) == "number" and x == x and x or 0 end
    local function vec(p) return TM.v3(num(p.X), num(p.Y), num(p.Z)) end
    local function healthy(hum) local h = hum.Health; return type(h) == "number" and h > 0 end
    -- a signal that may be missing (an unusual character): nothing to listen to, nothing to break
    local function listen(sig, fn)
        if sig == nil then return nil end
        local ok, conn = pcall(connect, sig, fn)
        return ok and conn or nil
    end
    local function V3(p) return Vector3.new(p.x, p.y, p.z) end

    -------------------------------------------------------------------------------------------------------- techs from the catalogue
    for _, d in ipairs(DEFS) do
        local tech = {id = d.id, group = d.group, title = d.title, desc = d.desc, when = d.when, defs = d.opts, needsDash = d.needsDash, manual = d.manual, template = d.template,
                      observer = d.observer, poll = d.poll, mouse = d.mouse, key = d.key, idList = d.ids, moves = MOVES[d.id] == true, enabled = false, token = 0, running = false, cooldownUntil = 0,
                      status = "off", stats = {runs = 0, aborts = 0, errors = 0}, extra = {}, ids = {}}
        tech.opt = TO.defaults(d.opts)
        lab.techs[d.id] = tech
        lab.byId[d.id] = tech
        lab.order[#lab.order + 1] = tech
    end

    local function rebuildIds(tech)
        local set = {}
        if tech.idList == "sideDash" then
            for _, id in ipairs(TD.ANIM.sideRight) do set[id] = true end
            for _, id in ipairs(TD.ANIM.sideLeft) do set[id] = true end
        elseif tech.idList then
            for _, id in ipairs(TD.ANIM[tech.idList] or {}) do set[tostring(id)] = true end
        end
        for id in pairs(tech.extra) do set[id] = true end
        tech.ids = set
    end
    for _, tech in ipairs(lab.order) do rebuildIds(tech) end

    local function setStatus(tech, text)
        tech.status = text
        if env.onStatus then pcall(env.onStatus, tech) end
    end
    lab.setStatus = setStatus

    -------------------------------------------------------------------------------------------------------- the character and the people around me
    local function myParts()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if hum and root then return char, hum, root end
    end
    lab.myParts = myParts

    local function validEnemy(model, char)
        if model == char or not model:IsA("Model") then return nil end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart")
        if not (hum and root) or not healthy(hum) then return nil end
        local plr = Players:GetPlayerFromCharacter(model)
        if not (plr or model.Name == "Weakest Dummy") then return nil end
        return {model = model, hum = hum, root = root, player = plr, name = plr and plr.Name or model.Name}
    end
    -- everybody I could fight (players and the dummy in Workspace.Live), nearest first when a radius is given
    function lab:enemies(radius)
        local list = {}
        local char, _, myRoot = myParts()
        if not myRoot then return list end
        local live = Workspace:FindFirstChild("Live")
        local pool = live and live:GetChildren() or {}
        if not live then for _, p in ipairs(Players:GetPlayers()) do if p.Character then pool[#pool + 1] = p.Character end end end
        local origin = myRoot.Position
        for _, model in ipairs(pool) do
            local e = validEnemy(model, char)
            if e then
                local p = e.root.Position
                e.x, e.y, e.z = p.X, p.Y, p.Z
                e.dist = (p - origin).Magnitude
                if e.dist <= (radius or math.huge) then list[#list + 1] = e end
            end
        end
        table.sort(list, function(a, b) return a.dist < b.dist end)
        return list
    end
    function lab:nearestEnemy(radius)
        local list = lab:enemies(radius)
        return list[1]
    end

    local function tracksOf(model)
        local hum = model:FindFirstChildOfClass("Humanoid")
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        if not animator then return {} end
        return safe(function() return animator:GetPlayingAnimationTracks() end) or {}
    end
    local function playingAny(model, set)
        for _, tr in ipairs(tracksOf(model)) do
            local id = TD.idOf(safe(function() return tr.Animation.AnimationId end))
            if id and set[id] then return true end
        end
        return false
    end

    -------------------------------------------------------------------------------------------------------- input: the game's remote first, keys as the fallback
    local function communicate()
        local char = LocalPlayer.Character
        return char and char:FindFirstChild("Communicate")
    end
    function lab:fireRemote(args)
        local remote = communicate()
        if not remote then return false end
        return pcall(function() remote:FireServer(args) end)
    end
    local function keyEvent(down, name)
        local vim = env.VirtualInput
        if not (vim and Enum.KeyCode[name]) then return false end
        return pcall(function() vim:SendKeyEvent(down, Enum.KeyCode[name], false, game) end)
    end
    function lab:tapKey(name)
        if not keyEvent(true, name) then return false end
        task.wait(0.03)
        keyEvent(false, name)
        return true
    end
    -- dir = "W" | "A" | "S" | "D" (the dash goes that way, relative to the camera, like holding the key)
    function lab:dash(dir)
        if lab.input ~= "Keys" and lab:fireRemote(TD.dashArgs(Enum.KeyCode, dir)) then return true end
        if lab.input == "Remote" then return false end
        keyEvent(true, dir)
        keyEvent(true, "Q"); task.wait(0.03); keyEvent(false, "Q")
        task.wait(0.03); keyEvent(false, dir)
        return true
    end
    function lab:m1(hold)
        hold = hold or 0.03
        if lab.input ~= "Keys" and communicate() then
            if lab.releaseBlock then lab:fireRemote(TD.blockArgs(Enum.KeyCode, false)) end
            if lab:fireRemote(TD.clickArgs(true)) then
                task.delay(hold, function() lab:fireRemote(TD.clickArgs(false)) end)
                return true
            end
        end
        if lab.input == "Remote" then return false end
        local vim, cam = env.VirtualInput, Workspace.CurrentCamera
        if not (vim and cam) then return false end
        local mid = cam.ViewportSize / 2
        local ok = pcall(function() vim:SendMouseButtonEvent(mid.X, mid.Y, 0, true, game, 0) end)
        task.delay(hold, function() pcall(function() vim:SendMouseButtonEvent(mid.X, mid.Y, 0, false, game, 0) end) end)
        return ok
    end
    -- cast a move by tool name (the Console Move remote); names = list of acceptable names
    function lab:findTool(names)
        local sources = {LocalPlayer:FindFirstChild("Backpack"), LocalPlayer.Character}
        for _, src in ipairs(sources) do
            if src then
                for _, t in ipairs(src:GetChildren()) do
                    if t:IsA("Tool") then
                        for _, n in ipairs(names) do if TD.toolMatches(t.Name, n) then return t end end
                    end
                end
            end
        end
    end
    function lab:useMove(names)
        local tool = lab:findTool(names)
        if not tool then return false, "you do not have " .. tostring(names[1]) end
        if not lab:fireRemote(TD.moveArgs(tool)) then return false, "no Communicate remote" end
        return true
    end

    -------------------------------------------------------------------------------------------------------- the context every sequence receives
    local function newCtx(tech, token, info)
        local char, hum, root = myParts()
        if not char then return nil end
        local c = {tech = tech, opt = tech.opt, info = info, char = char, hum = hum, root = root, lab = lab}
        local cleanups = {}
        local function alive()
            return lab.alive and tech.token == token and char.Parent ~= nil and healthy(hum) and (info.manual or (lab.master and tech.enabled))
        end
        c.alive = alive
        function c.onFinish(fn) cleanups[#cleanups + 1] = fn end
        function c.instance(inst) cleanups[#cleanups + 1] = function() if inst.Parent then inst:Destroy() end end; return inst end
        function c.conn(conn) cleanups[#cleanups + 1] = function() conn:Disconnect() end; return conn end
        function c.finish()
            for i = #cleanups, 1, -1 do pcall(cleanups[i]) end
            cleanups = {}
        end
        function c.commit()                                           -- from here the run counts: the cooldown starts and the stats go up
            if not c.committed then c.committed = true; tech.stats.runs = tech.stats.runs + 1 end
        end
        function c.abort(text) c.result = text; tech.stats.aborts = tech.stats.aborts + 1 end
        function c.say(text) c.result = text end

        function c.wait(sec)
            sec = tonumber(sec) or 0
            local t0 = clock()
            while clock() - t0 < sec do
                if not alive() then return false end
                task.wait()
            end
            return alive()
        end
        -- fn(a) every frame for `seconds`, a = 0..1 (a = 1 on the last call); false when cancelled
        function c.frames(seconds, fn)
            local t0 = clock()
            while true do
                local a = (clock() - t0) / math.max(seconds, 0.001)
                if a >= 1 then fn(1); return alive() end
                if not alive() then return false end
                fn(a)
                task.wait()
            end
        end

        function c.target(radius) return lab:nearestEnemy(radius) end
        function c.dash(dir) return lab:dash(dir) end
        function c.m1(hold) return lab:m1(hold) end
        function c.key(name) return lab:tapKey(name) end
        function c.useMove(names) return lab:useMove(names) end
        function c.enemyBlocking(radius)
            for _, e in ipairs(lab:enemies(radius)) do if playingAny(e.model, blockSet) then return e end end
        end
        function c.dashReady(kind) return lab.dashClock:ready(kind, clock()) end

        function c.stopAnims()
            local animator = hum:FindFirstChildOfClass("Animator")
            local list = animator and safe(function() return animator:GetPlayingAnimationTracks() end) or {}
            for _, tr in ipairs(list) do pcall(function() tr:Stop() end) end
        end
        function c.play(id, speed)
            local animator = hum:FindFirstChildOfClass("Animator")
            if not animator then return nil end
            local anim = animCache[id]
            if not anim then
                anim = Instance.new("Animation")
                anim.AnimationId = "rbxassetid://" .. id
                animCache[id] = anim
            end
            local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
            if not (ok and track) then return nil end
            ownTracks[track] = true
            pcall(function() track:Play() end)
            if speed then pcall(function() track:AdjustSpeed(speed) end) end
            return track
        end

        function c.lockRotation()
            if c.rotLocked then return end
            c.rotLocked = true
            local prev = hum.AutoRotate
            hum.AutoRotate = false
            local conn = hum:GetPropertyChangedSignal("AutoRotate"):Connect(function() if hum.AutoRotate then hum.AutoRotate = false end end)
            c.onFinish(function() conn:Disconnect(); if hum.Parent then hum.AutoRotate = prev end end)
        end

        local function place(pos, lookAt)
            if lookAt and (lookAt - pos).Magnitude > 1e-3 then
                root.CFrame = CFrame.lookAt(pos, lookAt)
            else
                root.CFrame = CFrame.new(pos) * (root.CFrame - root.CFrame.Position)
            end
        end
        -- slide the root to `point` ({x,y,z}) in `seconds`, looking at `lookAt` ({x,y,z}) when given; false when cancelled
        function c.moveTo(point, seconds, lookAt, ease)
            local start = root.Position
            local goal = V3(point)
            local look = lookAt and V3(lookAt) or nil
            if seconds <= 0.03 then place(goal, look); return alive() end
            return c.frames(seconds, function(a)
                place(start:Lerp(goal, TM.ease(ease or "quad_out", a)), look)
            end)
        end
        -- a velocity that is always removed again: returns {set = function(v3), stop = function()}
        function c.push(v)
            local att = c.instance(Instance.new("Attachment"))
            att.Parent = root
            local lv = c.instance(Instance.new("LinearVelocity"))
            lv.Attachment0 = att
            lv.MaxForce = math.huge
            lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
            lv.RelativeTo = Enum.ActuatorRelativeTo.World
            lv.VectorVelocity = Vector3.new(v.x, v.y, v.z)
            lv.Parent = root
            return {
                set = function(nv) if lv.Parent then lv.VectorVelocity = Vector3.new(nv.x, nv.y, nv.z) end end,
                stop = function() if lv.Parent then lv:Destroy() end; if att.Parent then att:Destroy() end end,
            }
        end
        local function myYaw()
            local look = root.CFrame.LookVector
            return atan2(-look.X, -look.Z)
        end
        -- turn the root toward getPoint() ({x,y,z} or nil) every frame; alpha = how fast (0..1 per frame), or smooth = the 1..1000 slider
        function c.faceLoop(getPoint, seconds, smooth, offsetRad, alphaFixed)
            local t0 = clock()
            local conn
            conn = RunService.RenderStepped:Connect(function(dt)
                if not alive() or clock() - t0 >= seconds then conn:Disconnect(); return end
                local p = getPoint()
                if not p then return end
                local want = TM.yawTo(vec(root.Position), p)
                if not want then return end
                local alpha = alphaFixed or TM.smoothAlpha(smooth, dt)
                root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, TM.lerpAngle(myYaw(), want + (offsetRad or 0), alpha), 0)
            end)
            c.conn(conn)
            return conn
        end
        -- Roblox's camera script rewrites the camera every frame, so a camera aim has to be put back by a render step that runs right after it
        function c.aimCamera(getPoint, seconds)
            local name = "TechLabAim_" .. tech.id
            local t0 = clock()
            local bound = true
            local function unbind() if bound then bound = false; pcall(function() RunService:UnbindFromRenderStep(name) end) end end
            c.onFinish(unbind)
            local ok = pcall(function()
                RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 2, function()
                    local cam = Workspace.CurrentCamera
                    local p = getPoint()
                    if not (cam and p) or clock() - t0 >= seconds or not alive() then unbind(); return end
                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, V3(p))
                end)
            end)
            if not ok then bound = false end
        end
        function c.floorY(pos)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {char}
            local hit = Workspace:Raycast(Vector3.new(pos.x, pos.y + 80, pos.z), Vector3.new(0, -300, 0), params)
            return hit and hit.Position.Y or pos.y
        end
        function c.jump(power)
            pcall(function()
                hum.PlatformStand = false
                hum.Jump = true
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
            local v = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(v.X, power, v.Z)
        end
        return c
    end

    -------------------------------------------------------------------------------------------------------- running a tech
    function lab:fire(id, info)
        local tech = type(id) == "table" and id or lab.byId[id]
        if not tech then return false, "unknown tech" end
        info = info or {}
        info.manual = info.manual or tech.manual or nil           -- a key / button press (the keys and the UI call lab:fire with manual = true)
        if not lab.alive then return false, "off" end
        if not info.manual and not (lab.master and tech.enabled) then return false, "off" end
        if tech.running then return false, "running" end
        if tech.moves then
            for _, other in ipairs(lab.order) do
                if other ~= tech and other.moves and other.running then
                    if info.manual then setStatus(tech, "not now: " .. other.title .. " is running") end
                    return false, "exclusive"
                end
            end
        end
        if not info.manual and env.busy and env.busy() then return false, "busy" end
        local now = clock()
        if now < tech.cooldownUntil and not info.force then return false, "cooldown" end
        if tech.needsDash and lab.dashGuard and not lab.dashClock:ready(tech.needsDash, now) and not info.force then
            setStatus(tech, string.format("waiting: the %s dash is on cooldown (%.1f s)", tech.needsDash, lab.dashClock:left(tech.needsDash, now)))
            return false, "dash cooldown"
        end
        tech.token = tech.token + 1
        local token = tech.token
        local ctx = newCtx(tech, token, info)
        if not ctx then setStatus(tech, "no character"); return false, "no character" end
        tech.running = true
        setStatus(tech, "running...")
        task.spawn(function()
            local startedAt = clock()
            local ok, err = pcall(tech.run, ctx)
            ctx.finish()
            if tech.token ~= token then return end                  -- cancelled from outside (Panic, switched off, died, respawned): that already wrote the status
            tech.running = false
            if not ok then
                tech.stats.errors = tech.stats.errors + 1
                setStatus(tech, "error: " .. tostring(err):sub(1, 90))
                log("[" .. tech.id .. "] " .. tostring(err))
            elseif ctx.result then
                setStatus(tech, ctx.result)
            elseif ctx.committed then
                setStatus(tech, string.format("done in %.2f s (%d runs)", clock() - startedAt, tech.stats.runs))
            else
                setStatus(tech, "ready")
            end
            if ok and ctx.committed then tech.cooldownUntil = clock() + (tech.opt.cooldown or 0) end
        end)
        return true
    end

    function lab:cancel(id, why)
        local tech = lab.byId[id]
        if not tech then return end
        tech.token = tech.token + 1
        tech.running = false
        if why then setStatus(tech, why) end
    end
    function lab:cancelAll(why)
        for _, tech in ipairs(lab.order) do
            if tech.running then lab:cancel(tech.id, why or "cancelled") end
        end
    end

    -------------------------------------------------------------------------------------------------------- triggers: my own animations, enemy animations, the mouse, keys, a poll
    local function learnedTrigger(id, track)
        local L = lab.learning
        if not L then return false end
        if clock() > L.expires then lab.learning = nil; return false end   -- nobody played anything in time: stop listening
        if safe(function() return track.Looped end) == true then return false end
        lab.learning = nil
        local n = 0
        for _ in pairs(L.tech.extra) do n = n + 1 end
        if n < 6 then L.tech.extra[id] = true; rebuildIds(L.tech) end
        if env.toast then env.toast("Learned " .. id .. " as a trigger for " .. L.tech.title) end
        if L.cb then pcall(L.cb, id) end
        return true
    end
    function lab:learnTrigger(id, cb)
        local tech = lab.byId[id]
        if tech then lab.learning = {tech = tech, cb = cb, expires = clock() + 15} end
    end
    function lab:forgetTriggers(id)
        local tech = lab.byId[id]
        if tech then tech.extra = {}; rebuildIds(tech) end
    end

    local function onOwnAnim(track)
        if ownTracks[track] then return end
        local id = TD.idOf(safe(function() return track.Animation.AnimationId end))
        if not id then return end
        local now = clock()
        local kind = TD.dashKind(id)
        if kind then
            lab.dashClock:seen(kind, now)
            lab.lastOwn[kind] = now
        end
        lab.lastOwn.id, lab.lastOwn.t = id, now
        if learnedTrigger(id, track) then return end
        for _, tech in ipairs(lab.order) do
            if tech.enabled and tech.ids[id] and not tech.observer then lab:fire(tech, {anim = id, track = track}) end
        end
    end

    -- somebody else's animation: Auto Counter answers dashes and M1s aimed at me
    local function onEnemyAnim(model, track)
        local tech = lab.techs.counter
        if not (tech and tech.enabled and lab.master) then return end
        local id = TD.idOf(safe(function() return track.Animation.AnimationId end))
        if not id then return end
        local o = tech.opt
        local isDash = o.answerDashes and tech.dashSet[id]
        local isM1 = o.answerM1 and tech.m1Set[id]
        if not (isDash or isM1) then return end
        local char, _, root = myParts()
        local eroot = model:FindFirstChild("HumanoidRootPart")
        if not (root and eroot) or model == char then return end
        local d = (eroot.Position - root.Position).Magnitude
        if d > o.distance then return end
        if o.facing then
            local to = TM.unit(TM.flat(TM.sub(vec(root.Position), vec(eroot.Position))))
            if TM.dot(TM.unit(TM.flat(vec(eroot.CFrame.LookVector))), to) < -0.2 then return end
        end
        tech.pending = {isDash = isDash, name = model.Name}
        lab:fire(tech, {anim = id, enemy = model.Name})
    end

    local function watchEnemy(model)
        if watched[model] or not model:IsA("Model") then return end
        local hum = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 3)
        local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 3))
        if not animator then return end
        watched[model] = listen(animator.AnimationPlayed, function(track) onEnemyAnim(model, track) end)
    end
    local function unwatchEnemies()
        for model, conn in pairs(watched) do pcall(function() conn:Disconnect() end); watched[model] = nil end
    end
    local function startEnemyWatch()
        if lab.liveConns then return end
        lab.liveConns = {}
        local live = Workspace:FindFirstChild("Live")
        if not live then return end
        for _, m in ipairs(live:GetChildren()) do task.spawn(watchEnemy, m) end
        lab.liveConns[#lab.liveConns + 1] = listen(live.ChildAdded, function(m) task.spawn(watchEnemy, m) end)
        lab.liveConns[#lab.liveConns + 1] = listen(live.ChildRemoved, function(m)
            if watched[m] then pcall(function() watched[m]:Disconnect() end); watched[m] = nil end
        end)
    end
    local function stopEnemyWatch()
        for _, c in ipairs(lab.liveConns or {}) do pcall(function() c:Disconnect() end) end
        lab.liveConns = nil
        unwatchEnemies()
    end

    local function hookCharacter(char)
        for _, c in ipairs(charConns) do pcall(function() c:Disconnect() end) end
        charConns = {}
        task.spawn(function()
            local hum = char:WaitForChild("Humanoid", 10)
            if not (hum and lab.alive and LocalPlayer.Character == char) then return end
            local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 10)
            charConns[#charConns + 1] = listen(animator and animator.AnimationPlayed or hum.AnimationPlayed, onOwnAnim)
            charConns[#charConns + 1] = listen(hum.Died, function() lab:cancelAll("cancelled: you died") end)
        end)
    end

    -------------------------------------------------------------------------------------------------------- mouse / key / poll triggers and the hook dash selection
    local function keyOf(tech, optName) return Enum.KeyCode[tech.opt[optName] or tech.opt.key or ""] end

    local function hookClear()
        local h = lab.hook
        if h.light then pcall(function() h.light:Destroy() end) end
        h.light, h.target = nil, nil
        local tech = lab.techs.hook
        if tech and not tech.running then setStatus(tech, "no target selected") end
    end
    local function hookSelect(entry)
        local h, tech = lab.hook, lab.techs.hook
        if h.target and entry and h.target.model == entry.model then hookClear(); return end          -- the same one again: deselect
        hookClear()
        if not entry then return end
        h.target = entry
        if tech.opt.highlight then
            local light = Instance.new("Highlight")
            light.Name = "TechLabHook"
            light.FillColor = Color3.fromRGB(173, 216, 230)
            light.OutlineColor = Color3.fromRGB(173, 216, 230)
            light.FillTransparency = 0.8
            light.OutlineTransparency = 0.3
            light.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            light.Adornee = entry.model
            light.Parent = entry.model
            h.light = light
        end
        setStatus(tech, "target: " .. entry.name)
    end
    -- the enemy nearest to a world point (the cursor's hit)
    function lab:hookSelectNear(point)
        local best, bestD = nil, 30                                   -- nobody within 30 studs of the cursor: nothing is selected
        for _, e in ipairs(lab:enemies()) do
            local d = (e.root.Position - point).Magnitude
            if d < bestD then best, bestD = e, d end
        end
        if not best then setStatus(lab.techs.hook, "no player near your cursor") return nil end
        hookSelect(best)
        return best
    end
    -- the model under a screen point (a tap on a phone)
    function lab:hookSelectAt(x, y)
        local cam = Workspace.CurrentCamera
        local char = LocalPlayer.Character
        if not (cam and char) then return nil end
        local ray = cam:ScreenPointToRay(x, y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char}
        local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
        local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
        local entry = model and validEnemy(model, char)
        if entry then hookSelect(entry) end
        return entry
    end
    function lab:hookClear() hookClear() end
    function lab:hookTarget() return lab.hook.target end

    local lastTap = 0
    local function onInput(input, processed)
        if processed or not lab.alive or not lab.master then return end
        local ut = input.UserInputType
        local now = clock()
        if ut == Enum.UserInputType.Touch then
            local hook = lab.techs.hook
            if hook.enabled then
                if now - lastTap < 0.35 then lab:hookSelectAt(input.Position.X, input.Position.Y) end
                lastTap = now
            end
            return
        end
        if ut == Enum.UserInputType.MouseButton1 then
            local tech = lab.techs.sidem1
            if tech.enabled then lab:fire(tech, {mouse = true}) end
            return
        end
        if ut ~= Enum.UserInputType.Keyboard then return end
        local code = input.KeyCode
        local hook = lab.techs.hook
        if hook.enabled then
            if code == Enum.KeyCode[hook.opt.selectKey] then
                local mouse = safe(function() return LocalPlayer:GetMouse() end)
                local p = mouse and safe(function() return mouse.Hit.Position end)
                if p then lab:hookSelectNear(p) end
                return
            elseif code == Enum.KeyCode[hook.opt.goKey] then
                if lab.hook.target then lab:fire(hook, {manual = true}) else setStatus(hook, "no target selected (press the select key near them)") end
                return
            end
        end
        for _, id in ipairs({"m1reset", "emotedash"}) do
            local tech = lab.techs[id]
            if tech.enabled and code == Enum.KeyCode[tech.opt.key] then lab:fire(tech, {manual = true}) end
        end
        local nel = lab.techs.noendlag
        if nel.enabled and code == Enum.KeyCode.Q and lab.lastOwn.side and now - lab.lastOwn.side <= nel.opt.window then
            lab.lastOwn.side = nil
            lab:fire(nel, {key = true})
        end
    end

    local pollAcc, catching = 0, false
    local function onHeartbeat(dt)
        if not lab.alive then return end
        -- the hook target is dropped the moment it dies or leaves
        local t = lab.hook.target
        if t and (not t.model.Parent or not healthy(t.hum)) then hookClear() end
        local tech = lab.techs.catch
        if not (lab.master and tech.enabled) then catching = false; return end
        pollAcc = pollAcc + dt
        if pollAcc < 0.03 then return end
        pollAcc = 0
        local _, _, root = myParts()
        if not root then return end
        local o = tech.opt
        local me, look = vec(root.Position), vec(root.CFrame.LookVector)
        local inside = false
        for _, e in ipairs(lab:enemies(o.range + 6)) do
            local v = vec(e.root.AssemblyLinearVelocity)
            if TM.inFrontBox(me, look, vec(e.root.Position), v, {range = o.range, halfWidth = o.halfWidth, halfHeight = 3, lead = o.lead / 100}) then inside = true; break end
        end
        if inside and not catching and not (env.busy and env.busy()) then
            catching = true
            tech.stats.runs = tech.stats.runs + 1
            lab:m1(o.hold / 1000)
            setStatus(tech, "caught somebody (" .. tech.stats.runs .. ")")
        elseif not inside then
            catching = false
        end
    end

    -------------------------------------------------------------------------------------------------------- the techs (sequences)
    local function sideKeyFor(dir)                                    -- the side-dash key whose camera-relative direction fits `dir` best
        local cam = Workspace.CurrentCamera
        local right = cam and cam.CFrame.RightVector or Vector3.new(1, 0, 0)
        return (dir.x * right.X + dir.z * right.Z) >= 0 and "D" or "A"
    end

    lab.techs.supa.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(o.delay / 1000) then return end
        local entry = ctx.target(o.radius)
        if not entry then return ctx.abort("no target within " .. o.radius .. " studs") end
        ctx.commit()
        ctx.dash("W")
        if not ctx.wait(0.02) then return end
        local me, tp = vec(ctx.root.Position), vec(entry.root.Position)
        local pts = TM.supaPoints(me, tp, {under = o.under, lock = o.lock, jitter = o.jitter, behind = false})
        if not ctx.moveTo(pts.under, 0.2 / o.speed, pts.look, "quad_out") then return end
        if o.behind and entry.root.Parent then
            local now = vec(entry.root.Position)
            -- the finishing spot is worked out from where I STARTED (standing under them there is no direction left to work from)
            local end2 = TM.supaPoints(me, now, {behind = true, behindOffset = o.behindOffset, targetLook = vec(entry.root.CFrame.LookVector)})
            if not ctx.moveTo(end2.behind, 0.1, now, "quad_out") then return end
        end
        ctx.dash("W")
    end

    lab.techs.hook.run = function(ctx)
        local o, h = ctx.opt, lab.hook
        local entry = h.target
        if not entry or not healthy(entry.hum) or not entry.model.Parent then return ctx.abort("no target selected") end
        if o.maxY > 0 and (ctx.root.Position.Y > o.maxY or entry.root.Position.Y > o.maxY + 6) then return ctx.abort("too high up for a hook dash") end
        local dist = (entry.root.Position - ctx.root.Position).Magnitude
        if dist > o.maxDist then return ctx.abort(string.format("too far (%.0f > %.0f studs)", dist, o.maxDist)) end
        ctx.commit()
        local sideMode = ({["Behind them"] = "Behind", Closest = "Closest", Left = "Left", Right = "Right"})[o.side] or "Closest"
        local function plan(side, dir)
            return TM.hookPoint(vec(ctx.root.Position), vec(entry.root.Position), vec(entry.root.AssemblyLinearVelocity), vec(entry.root.CFrame.LookVector),
                {range = o.range, prediction = o.prediction, reach = o.reach, side = side or sideMode, dir = dir})
        end
        local first = plan()
        local toEnd = TM.sub(first.point, vec(ctx.root.Position))
        local key = sideKeyFor(toEnd)
        local sign = key == "D" and 1 or -1
        ctx.lockRotation()
        local before = lab.lastOwn.t or 0
        ctx.dash(key)
        task.delay(0.08, function()                                    -- the server's dash animation did not show up: play the side dash myself
            if ctx.alive() and (lab.lastOwn.t or 0) <= before then ctx.play(SIDE_ID[key == "D" and "Right" or "Left"], 1) end
        end)
        local lv = ctx.push({x = 0, y = 0, z = 0})
        local fixedSide = first.side
        local t0 = clock()
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not ctx.alive() then conn:Disconnect(); return end
            local p = plan(fixedSide, first.dir)
            -- the velocity that arrives exactly when the dash time is up (a fixed time constant would only ever cover 63 % of the way)
            local left = math.max(o.duration - (clock() - t0), 1 / 60)
            local v = TM.steer(vec(ctx.root.Position), p.point, left, 300)
            lv.set(v)
            local want = TM.yawTo(vec(ctx.root.Position), vec(entry.root.Position))
            if want then
                if o.face == "Side-on" then want = want + sign * math.rad(140) end
                local look = ctx.root.CFrame.LookVector
                local cur = atan2(-look.X, -look.Z)
                ctx.root.CFrame = CFrame.new(ctx.root.Position) * CFrame.Angles(0, TM.lerpAngle(cur, want, o.smooth), 0)
            end
        end)
        ctx.conn(conn)
        if o.m1After then
            task.delay(o.m1Delay, function() if ctx.alive() then lab:m1() end end)
        end
        if not ctx.wait(o.duration) then return end
        lv.stop()
        conn:Disconnect()
        if o.aimAfter > 0 then ctx.aimCamera(function() return vec(entry.root.Position) end, o.aimAfter) end
        ctx.wait(o.aimAfter)
    end

    lab.techs.loop.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(o.delay / 1000 + 0.065) then return end
        if ctx.info.track and ctx.info.track.IsPlaying == false and not ctx.info.manual then return ctx.abort("uppercut cancelled") end
        local entry = ctx.target(o.targetRadius)
        if not entry then return ctx.abort("no target within " .. o.targetRadius .. " studs") end
        ctx.commit()
        local me = vec(ctx.root.Position)
        local h = TM.heightAbove(ctx.floorY(me), me.y, o.maxHeight)
        ctx.dash("W")
        local startAngle = atan2(me.z - entry.root.Position.Z, me.x - entry.root.Position.X)
        local seed = math.random() * 1000
        local lastDash = clock() - o.dashEvery / 1000
        local ok = ctx.frames(o.orbitTime, function(a)
            local tp = vec(entry.root.Position)
            local y = ctx.floorY(tp) + math.min(h, o.maxHeight)
            local pos, nxt = TM.orbitPose(tp, startAngle, a, {radius = o.radius, steps = 100, seed = seed, height = y})
            ctx.root.CFrame = CFrame.lookAt(V3(pos), V3(nxt))
            if clock() - lastDash >= o.dashEvery / 1000 then lastDash = clock(); lab:dash("W") end
        end)
        if not ok then return end
        local tp = vec(entry.root.Position)
        local hover = TM.v3(tp.x, ctx.floorY(tp) + math.min(h, o.maxHeight), tp.z)
        if not ctx.moveTo(hover, o.settle / 1000, TM.add(tp, TM.v3(0, 0.1, 0)), "quad_out") then return end
        local bp = ctx.instance(Instance.new("BodyPosition"))
        bp.MaxForce = Vector3.new(1e5, 1e5, 1e5); bp.P = 10000; bp.D = 100; bp.Position = V3(hover); bp.Parent = ctx.root
        local bg = ctx.instance(Instance.new("BodyGyro"))
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5); bg.P = 5000; bg.D = 100; bg.CFrame = ctx.root.CFrame; bg.Parent = ctx.root
        ctx.frames(o.hold / 1000, function()
            if not (bg.Parent and entry.root.Parent) then return end
            local mine, theirs = ctx.root.Position, entry.root.Position
            local look = ctx.root.CFrame.LookVector
            local toward = (theirs - mine)
            local mix = look + (toward.Magnitude > 0 and toward.Unit or Vector3.new(0, 0, 0))
            if mix.Magnitude > 0 then bg.CFrame = CFrame.new(mine, mine + mix.Unit) end
        end)
    end

    local function jumpLock(ctx)
        local o = ctx.opt
        if not ctx.wait(o.detect) then return end
        if o.pauseOnBlock and ctx.enemyBlocking(o.radius) then return ctx.abort("paused: somebody is blocking") end
        ctx.commit()
        ctx.lockRotation()
        if o.jump then ctx.jump(o.jumpPower) end
        ctx.dash("W")
        if not ctx.wait(o.flick) then return end
        local entry = ctx.target(o.radius)
        if entry then ctx.faceLoop(function() return entry.root.Parent and vec(entry.root.Position) or nil end, o.lock, o.smooth) end
        ctx.wait(math.max(o.lock, 1.2))
    end
    lab.techs.loop2.run = jumpLock
    lab.techs.lethal.run = jumpLock

    lab.techs.kiba.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(o.delay / 1000) then return end
        local entry = ctx.target(o.radius)
        if not entry then return ctx.abort("no target within " .. o.radius .. " studs") end
        ctx.commit()
        if o.mode == "Orbit (Kitty)" and o.pingWait then
            if not ctx.wait(TM.pingWait(env.pingMs and env.pingMs() or 60, 1.3, 0.03, 0.22)) then return end
        end
        ctx.dash("W")
        -- a part that follows the target (hanging on it / circling it), and the root is held to it by constraints that are always removed
        local follow = ctx.instance(Instance.new("Part"))
        follow.Size = Vector3.new(0.5, 0.5, 0.5); follow.Transparency = 1; follow.Anchored = true; follow.CanCollide = false; follow.Name = "TechLabFollow"; follow.Parent = Workspace
        local a0, a1 = ctx.instance(Instance.new("Attachment")), ctx.instance(Instance.new("Attachment"))
        a0.Parent = ctx.root; a1.Parent = follow
        local b0, b1 = ctx.instance(Instance.new("Attachment")), ctx.instance(Instance.new("Attachment"))
        b0.Parent = ctx.root; b1.Parent = follow
        local ap = ctx.instance(Instance.new("AlignPosition"))
        ap.Attachment0 = a0; ap.Attachment1 = a1; ap.RigidityEnabled = true; ap.Responsiveness = 200; ap.MaxForce = math.huge; ap.Parent = ctx.root
        local ao = ctx.instance(Instance.new("AlignOrientation"))
        ao.Attachment0 = b0; ao.Attachment1 = b1; ao.RigidityEnabled = true; ao.Responsiveness = 200; ao.MaxTorque = math.huge; ao.Parent = ctx.root
        local snapped = false
        ctx.frames(o.hold, function(a)
            if not entry.root.Parent then return end
            local t = entry.root
            if o.mode == "Orbit (Kitty)" then
                local lap = (a * o.hold) / o.spin
                local center = t.Position + Vector3.new(0, o.orbitHeight, 0)
                local ang = 2 * math.pi * lap
                local pos = center + Vector3.new(math.cos(ang) * o.orbitRadius, 0, math.sin(ang) * o.orbitRadius)
                follow.CFrame = CFrame.lookAt(pos, t.Position)
            else
                follow.CFrame = t.CFrame * CFrame.Angles(math.rad(o.pitch), 0, 0)
            end
            if not snapped then snapped = true; ctx.root.CFrame = follow.CFrame end
        end)
    end

    lab.techs.twisted.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(o.wait / 1000) then return end
        ctx.commit()
        ctx.root.CFrame = ctx.root.CFrame * CFrame.new(0, 0, o.stepBack)
        ctx.dash(o.dashKey)
        if o.instant then
            local entry = ctx.target(30)
            if entry then
                ctx.lockRotation()
                ctx.faceLoop(function() return entry.root.Parent and vec(entry.root.Position) or nil end, 0.3, 1000)
                ctx.wait(0.3)
            end
        end
    end

    lab.techs.kyoto.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(o.wait) then return end
        if not ctx.wait(o.startDelay / 1000) then return end
        ctx.commit()
        local names = o.moveName ~= "" and {o.moveName} or TD.TOOLS.lethal
        local ok, why = ctx.useMove(names)
        if not ok then ctx.say("cast failed: " .. tostring(why)) end
        if o.hotbar then ctx.key("One") end
        ctx.stopAnims()
        ctx.play(SIDE_ID.Right, 1)
        ctx.lockRotation()
        local look = TM.unit(TM.flat(vec(ctx.root.CFrame.LookVector)), TM.v3(0, 0, -1))
        local right = TM.v3(-look.z, 0, look.x)
        local here = vec(ctx.root.Position)
        local dest = TM.add(here, TM.scale(look, o.distance))
        if not ctx.moveTo(dest, o.hopTime / 1000, TM.add(dest, right), "linear") then return end
        if o.hotbar then ctx.key("Two") end
        ctx.wait(0.25)
    end

    lab.techs.dunk.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(o.wait) then return end
        ctx.commit()
        ctx.root.CFrame = ctx.root.CFrame + Vector3.new(0, o.height, 0)
    end

    lab.techs.surf.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(o.wait) then return end
        ctx.commit()
        local look = TM.unit(TM.flat(vec(ctx.root.CFrame.LookVector)), TM.v3(0, 0, -1))
        local dest = TM.add(vec(ctx.root.Position), TM.scale(look, o.distance))
        ctx.moveTo(dest, o.time, nil, "linear")
    end

    lab.techs.counter.run = function(ctx)
        local o = ctx.opt
        local p = lab.techs.counter.pending or {}
        ctx.commit()
        if p.isDash and o.dashDelay > 0 then if not ctx.wait(o.dashDelay / 1000) then return end end
        local names = o.moveName ~= "" and {o.moveName} or TD.TOOLS.counters
        local ok, why = ctx.useMove(names)
        if ok then ctx.say("countered " .. tostring(p.name or "?")) else ctx.abort("no counter: " .. tostring(why)) end
    end

    lab.techs.flip.run = function(ctx)
        local o = ctx.opt
        if not ctx.wait(o.delay / 1000) then return end
        ctx.commit()
        local keepVel = ctx.root.AssemblyLinearVelocity
        ctx.lockRotation()
        local bg = ctx.instance(Instance.new("BodyGyro"))
        bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9); bg.P = 20000; bg.D = 100
        bg.CFrame = ctx.root.CFrame * CFrame.Angles(TM.flipAngle(o.lock, o.lookUp), 0, 0)
        bg.Parent = ctx.root
        local bv = ctx.instance(Instance.new("BodyVelocity"))
        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9); bv.Velocity = keepVel; bv.Parent = ctx.root
        ctx.wait(o.hold / 1000)
    end

    lab.techs.mousedash.run = function(ctx)
        local o = ctx.opt
        ctx.commit()
        local mouse = safe(function() return LocalPlayer:GetMouse() end)
        if not mouse then return ctx.abort("no mouse") end
        ctx.frames(o.window / 1000, function()
            local p = safe(function() return mouse.Hit.Position end)
            if not p then return end
            local pos = ctx.root.Position
            local at = Vector3.new(p.X, pos.Y, p.Z)
            if (at - pos).Magnitude > 1e-3 then ctx.root.CFrame = CFrame.lookAt(pos, at) end
        end)
    end

    lab.techs.sidem1.run = function(ctx)
        local o = ctx.opt
        if o.delay > 0 and not ctx.wait(o.delay / 1000) then return end
        ctx.commit()
        ctx.lockRotation()
        local ang = math.rad(o.angle)
        ctx.root.CFrame = ctx.root.CFrame * CFrame.Angles(0, ang, 0)
        local cam = Workspace.CurrentCamera
        local camBefore = cam and cam.CFrame
        if cam and not o.silent then
            local rel = cam.CFrame.Position - ctx.root.Position
            local flat = Vector3.new(rel.X, 0, rel.Z)
            local rotated = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), ang) * flat
            cam.CFrame = CFrame.lookAt(Vector3.new(ctx.root.Position.X + rotated.X, cam.CFrame.Position.Y, ctx.root.Position.Z + rotated.Z), ctx.root.Position)
        end
        ctx.wait(o.duration / 1000)
        if ctx.root.Parent then ctx.root.CFrame = ctx.root.CFrame * CFrame.Angles(0, -ang, 0) end
        if cam and camBefore and not o.silent then cam.CFrame = camBefore end
    end

    lab.techs.noendlag.run = function(ctx)
        ctx.commit()
        ctx.dash(ctx.opt.dashKey)
    end

    lab.techs.slidem1.run = function(ctx)
        ctx.commit()
        lab:m1()
    end

    lab.techs.downslam.run = function(ctx)
        local o = ctx.opt
        local near = ctx.target(o.radius)
        if not near then return ctx.abort("nobody within " .. o.radius .. " studs") end
        ctx.commit()
        local up = TM.add(vec(ctx.root.Position), TM.v3(0, o.lift, 0))
        ctx.moveTo(up, o.liftTime, nil, "quad_out")
        pcall(function()
            for _, st in ipairs({Enum.HumanoidStateType.PlatformStanding, Enum.HumanoidStateType.Freefall, Enum.HumanoidStateType.GettingUp}) do
                if ctx.hum:GetState() == st then ctx.hum:ChangeState(Enum.HumanoidStateType.Physics); task.wait() end
            end
            ctx.hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end

    lab.techs.m1reset.run = function(ctx)
        local o = ctx.opt
        ctx.commit()
        ctx.stopAnims()
        ctx.play(SIDE_ID.Right, 1.2)
        local right = TM.unit(TM.flat(vec(ctx.root.CFrame.RightVector)), TM.v3(1, 0, 0))
        local dest = TM.add(vec(ctx.root.Position), TM.scale(right, o.distance))
        if not ctx.moveTo(dest, o.duration, nil, "sine_out") then return end
        local ang = math.rad(o.rotation)
        ctx.root.CFrame = ctx.root.CFrame * CFrame.Angles(0, ang, 0)
        local cam = Workspace.CurrentCamera
        if cam then
            local rel = cam.CFrame.Position - ctx.root.Position
            local rotated = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), ang) * Vector3.new(rel.X, 0, rel.Z)
            cam.CFrame = CFrame.lookAt(Vector3.new(ctx.root.Position.X + rotated.X, cam.CFrame.Position.Y, ctx.root.Position.Z + rotated.Z), ctx.root.Position)
        end
        ctx.wait(0.003)
        if o.dashAfter ~= "None" then ctx.dash(o.dashAfter) end
    end

    lab.techs.emotedash.run = function(ctx)
        local o = ctx.opt
        ctx.commit()
        ctx.stopAnims()
        ctx.play(SIDE_ID.Right, 1.2)
        ctx.root.CFrame = ctx.root.CFrame * CFrame.Angles(0, math.rad(o.rotation), 0)
        local dir = ctx.root.CFrame.RightVector * o.distance + Vector3.new(0, o.height, 0)
        if dir.Magnitude == 0 then dir = Vector3.new(0, 1, 0) end
        local bv = ctx.instance(Instance.new("BodyVelocity"))
        bv.Velocity = dir.Unit * o.power
        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        bv.Parent = ctx.root
        ctx.wait(o.duration)
    end

    do   -- Auto Counter's animation sets (built once, they depend on the data only)
        local c = lab.techs.counter
        c.dashSet, c.m1Set = TD.set(TD.ANIM.counterDash), TD.set(TD.ANIM.counterM1)
    end

    -------------------------------------------------------------------------------------------------------- switching, config, lifecycle
    local function refreshHooks()
        local needEnemies = lab.techs.counter.enabled and lab.master
        if needEnemies then startEnemyWatch() else stopEnemyWatch() end
    end
    function lab:setEnabled(id, on)
        local tech = lab.byId[id]
        if not tech then return end
        tech.enabled = on == true
        if not tech.enabled then lab:cancel(id, "off") else setStatus(tech, tech.manual and (tech.key and ("ready (" .. tech.key .. ")") or "ready") or "armed") end
        if id == "hook" and not tech.enabled then hookClear() end
        refreshHooks()
    end
    function lab:setMaster(on)
        lab.master = on == true
        if not lab.master then lab:cancelAll("off") end
        refreshHooks()
    end
    function lab:setOption(id, key, value)
        local tech = lab.byId[id]
        if not tech then return end
        local test = TO.clean(tech.defs, {[key] = value})
        tech.opt[key] = test[key]
    end
    function lab:setInput(mode) if mode == "Auto" or mode == "Remote" or mode == "Keys" then lab.input = mode end end
    function lab:dashLeft(kind) return lab.dashClock:left(kind, clock()) end

    function lab:export()
        local out = {enabled = {}, opts = {}, triggers = {}, input = lab.input, dashGuard = lab.dashGuard, releaseBlock = lab.releaseBlock, master = lab.master}
        for _, tech in ipairs(lab.order) do
            if tech.enabled then out.enabled[tech.id] = true end
            local diff = TO.diff(tech.defs, tech.opt)
            if next(diff) then out.opts[tech.id] = diff end
            local ids = {}
            for id in pairs(tech.extra) do ids[#ids + 1] = id end
            if #ids > 0 then table.sort(ids); out.triggers[tech.id] = ids end
        end
        return out
    end
    function lab:import(saved)
        if type(saved) ~= "table" then return end
        if saved.input == "Auto" or saved.input == "Remote" or saved.input == "Keys" then lab.input = saved.input end
        if type(saved.dashGuard) == "boolean" then lab.dashGuard = saved.dashGuard end
        if type(saved.releaseBlock) == "boolean" then lab.releaseBlock = saved.releaseBlock end
        if type(saved.master) == "boolean" then lab.master = saved.master end
        for _, tech in ipairs(lab.order) do
            tech.opt = TO.clean(tech.defs, type(saved.opts) == "table" and saved.opts[tech.id] or nil)
            local ids = type(saved.triggers) == "table" and saved.triggers[tech.id]
            tech.extra = {}
            if type(ids) == "table" then
                for i, id in ipairs(ids) do
                    if i <= 6 and type(id) == "string" and id:match("^%d+$") and #id <= 20 then tech.extra[id] = true end
                end
            end
            rebuildIds(tech)
            if type(saved.enabled) == "table" and saved.enabled[tech.id] == true then lab:setEnabled(tech.id, true) end
        end
    end

    function lab:destroy()
        lab.alive = false
        lab:cancelAll("off")
        hookClear()
        stopEnemyWatch()
        for _, c in ipairs(lab.conns) do pcall(function() c:Disconnect() end) end
        for _, c in ipairs(charConns) do pcall(function() c:Disconnect() end) end
        lab.conns, charConns = {}, {}
        for _, a in pairs(animCache) do pcall(function() a:Destroy() end) end
        animCache = {}
    end

    -- start listening
    lab.conns[#lab.conns + 1] = listen(UIS.InputBegan, onInput)
    lab.conns[#lab.conns + 1] = listen(RunService.Heartbeat, onHeartbeat)
    if LocalPlayer.Character then hookCharacter(LocalPlayer.Character) end
    lab.conns[#lab.conns + 1] = listen(LocalPlayer.CharacterAdded, function(char) lab:cancelAll("cancelled: respawned"); hookCharacter(char) end)
    return lab
end

return M
