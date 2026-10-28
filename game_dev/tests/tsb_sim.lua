-- A small Strongest Battlegrounds arena for the Tech Lab tests, on top of the fake Roblox world of tests/mm2_env.lua.
--   * characters live in Workspace.Live (players and a "Weakest Dummy"), every character has a Humanoid + Animator, mine also has the Communicate remote
--   * playing an animation fires Animator.AnimationPlayed like the engine does; Animator:GetPlayingAnimationTracks() lists what is playing
--   * the "server" reads Communicate:FireServer(...) (dash / M1 / block / Console Move), records it and answers a dash with the dash animation
--   * LinearVelocity / BodyVelocity inside a root part move it (so a Hook Dash really travels), nothing else is simulated
-- None of this is the real game: it is the shape of it as described by the script the user uploaded. A passing test means "the code does what it says in a world
-- that behaves like that", not "it works in Strongest Battlegrounds".
local World = MM2_WORLD
local S = {}
S.__index = S

local function compileIn(env, src, name)
    local fn, err
    if loadstring and setfenv then fn, err = loadstring(src, name); if fn then setfenv(fn, env) end
    else fn, err = load(src, name, "t", env) end
    if not fn then error("SYNTAX ERROR in " .. name .. ": " .. tostring(err)) end
    return fn
end

local DASH_ANIM = {W = "10479335397", S = "10479335397", A = "10480796021", D = "10480793962"}
local DASH_KIND = {W = "forward", S = "forward", A = "side", D = "side"}

function S.new(opts)
    opts = opts or {}
    local W = World.new({ping = opts.ping or 60, gethui = opts.gethui})
    W:installJson()
    local self = setmetatable({W = W, log = {}, statuses = {}, ignored = {}, dashReadyAt = {}, enemyVel = {}, truth = {}, mouseHit = nil, rayHit = nil, serverDashMoves = false,
                               animMode = opts.animMode or "predicted", jitter = opts.jitter or 0, interp = 0.08}, S)
    local env = W.env
    local E = env.Enum

    ---------------------------------------------------------------------------------------------------- the maths the world does not ship (CFrame.Angles / fromAxisAngle)
    local function setRot(cf, m)                                  -- m = rows {{r11,r12,r13},{r21,..},{r31,..}} -> the world's column layout
        cf.r = {m[1][1], m[2][1], m[3][1], m[1][2], m[2][2], m[3][2], m[1][3], m[2][3], m[3][3]}
        return cf
    end
    local function mul(a, b)
        local out = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}}
        for i = 1, 3 do for j = 1, 3 do for k = 1, 3 do out[i][j] = out[i][j] + a[i][k] * b[k][j] end end end
        return out
    end
    env.CFrame.Angles = function(rx, ry, rz)
        local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
        local RX = {{1, 0, 0}, {0, cx, -sx}, {0, sx, cx}}
        local RY = {{cy, 0, sy}, {0, 1, 0}, {-sy, 0, cy}}
        local RZ = {{cz, -sz, 0}, {sz, cz, 0}, {0, 0, 1}}
        return setRot(env.CFrame.new(0, 0, 0), mul(mul(RX, RY), RZ))
    end
    env.CFrame.fromAxisAngle = function(axis, angle)
        local m = axis.Magnitude
        local x, y, z = axis.X / m, axis.Y / m, axis.Z / m
        local c, s = math.cos(angle), math.sin(angle)
        local t = 1 - c
        return setRot(env.CFrame.new(0, 0, 0), {{t * x * x + c, t * x * y - s * z, t * x * z + s * y}, {t * x * y + s * z, t * y * y + c, t * y * z - s * x},
                                                {t * x * z - s * y, t * y * z + s * x, t * z * z + c}})
    end
    -- real Luau has math.atan2 (kept so the modules that call it also run under plain Lua 5.4)
    env.math = setmetatable({atan2 = math.atan2 or math.atan}, {__index = math})

    ---------------------------------------------------------------------------------------------------- the services and the arena
    W.virtualInput = W.game:GetService("VirtualInputManager")
    env.listfiles = function(dir)                                  -- the executor's file list: every file written under `dir`
        local out = {}
        for path in pairs(W.files) do
            if path:sub(1, #dir + 1) == dir .. "/" then out[#out + 1] = path end
        end
        table.sort(out)
        return out
    end
    local live = W:make("Folder", "Live", {}, W.workspace)
    self.live = live
    self.floor = W:make("Part", "Baseplate", {CFrame = env.CFrame.new(0, -0.5, 0), Size = env.Vector3.new(2000, 1, 2000), Anchored = true}, W.workspace)

    local function addAnimator(char)
        local hum = W.M.FindFirstChildOfClass(char, "Humanoid")
        rawget(hum, "__d").props.AutoRotate = true
        W:make("Animator", "Animator", {}, hum)
        return hum
    end
    local function toLive(char) W.setParent(char, live) end

    function self:addMe(pos)
        local plr, char = W:addPlayer("Me", {pos = pos or {0, 3, 0}})
        addAnimator(char)                                         -- (a real client has the Animator by the time a script looks: WaitForChild is not simulated)
        W:make("RemoteEvent", "Communicate", {}, char)
        toLive(char)
        W:setLocal(plr)
        self.mePlayer, self.meChar = plr, char
        self.meHum = W.M.FindFirstChildOfClass(char, "Humanoid")
        self.meRoot = W.M.FindFirstChild(char, "HumanoidRootPart")
        return plr, char
    end
    function self:respawn(pos)                                    -- a full new character, complete before CharacterAdded fires (like a real client)
        local plr = self.mePlayer
        W.M.Destroy(self.meChar)
        local p = pos or {0, 3, 0}
        local char = W:make("Model", "Me", {}, nil)
        for _, n in ipairs({"HumanoidRootPart", "Head", "Torso"}) do
            W:make("Part", n, {CFrame = env.CFrame.new(p[1], p[2], p[3]), Size = env.Vector3.new(2, 2, 1)}, char)
        end
        local hum = W:make("Humanoid", "Humanoid", {Health = 100, MaxHealth = 100, AutoRotate = true}, char)
        W:make("Animator", "Animator", {}, hum)
        W:make("RemoteEvent", "Communicate", {}, char)
        rawget(plr, "__d").props.Character = char
        W.setParent(char, live)
        W.fire(W.signalOf(plr, "CharacterAdded"), char)
        self.meChar, self.meHum, self.meRoot = char, hum, W.M.FindFirstChild(char, "HumanoidRootPart")
        return char
    end
    function self:addEnemy(name, pos, o)
        o = o or {}
        local plr, char = W:addPlayer(name, {pos = pos, vel = o.vel})
        addAnimator(char)
        toLive(char)
        if o.look then                                            -- face a point
            local root = W.M.FindFirstChild(char, "HumanoidRootPart")
            local p = root.Position
            rawget(root, "__d").props.CFrame = env.CFrame.lookAt(p, env.Vector3.new(o.look[1], p.Y, o.look[3]))
        end
        return plr, char
    end
    function self:addDummy(pos)
        local m = W:make("Model", "Weakest Dummy", {}, nil)
        local p = pos or {20, 3, 0}
        W:make("Part", "HumanoidRootPart", {CFrame = env.CFrame.new(p[1], p[2], p[3]), Size = env.Vector3.new(2, 2, 1)}, m)
        W:make("Humanoid", "Humanoid", {Health = 100, MaxHealth = 100}, m)
        addAnimator(m)
        toLive(m)
        return m
    end
    function self:root(model) return W.M.FindFirstChild(model, "HumanoidRootPart") end
    function self:pos(model) local p = self:root(model).Position; return {p.X, p.Y, p.Z} end
    function self:place(model, pos, lookAt)
        local d = rawget(self:root(model), "__d")
        if lookAt then d.props.CFrame = env.CFrame.lookAt(env.Vector3.new(pos[1], pos[2], pos[3]), env.Vector3.new(lookAt[1], lookAt[2], lookAt[3]))
        else d.props.CFrame = env.CFrame.new(pos[1], pos[2], pos[3]) end
    end
    function self:give(plr, toolName) return W:giveTool(plr, toolName) end

    ---------------------------------------------------------------------------------------------------- animations
    local function animatorOf(model)
        local hum = W.M.FindFirstChildOfClass(model, "Humanoid")
        return hum and W.M.FindFirstChildOfClass(hum, "Animator")
    end
    local function startTrack(animator, track)
        local d = rawget(animator, "__d")
        d.tracks = d.tracks or {}
        d.tracks[#d.tracks + 1] = track
        rawget(track, "__d").props.IsPlaying = true
        W.fire(W.signalOf(animator, "AnimationPlayed"), track)
    end
    local function stopTrack(track)
        local td = rawget(track, "__d")
        local wasPlaying = td.props.IsPlaying
        td.props.IsPlaying = false
        if wasPlaying then W.fire(W.signalOf(track, "Stopped")) end
        local animator = td.animator
        if animator then
            local list = rawget(animator, "__d").tracks or {}
            for i, t in ipairs(list) do if t == track then table.remove(list, i); break end end
        end
    end
    -- an animation starts on `model` (the engine: Animator.AnimationPlayed fires); stops after `seconds`
    function self:anim(model, id, seconds)
        local animator = animatorOf(model)
        local anim = W:make("Animation", "Anim" .. id, {AnimationId = "rbxassetid://" .. id}, nil)
        local track = W:make("AnimationTrack", "Track", {Animation = anim, IsPlaying = false, Looped = false}, nil)
        rawget(track, "__d").animator = animator
        startTrack(animator, track)
        env.task.delay(seconds or 0.5, function() stopTrack(track) end)
        return track
    end
    function self:playing(model, id)
        local animator = animatorOf(model)
        for _, t in ipairs(animator and rawget(animator, "__d").tracks or {}) do
            if t.Animation.AnimationId == "rbxassetid://" .. id then return true end
        end
        return false
    end
    W.M.GetPlayingAnimationTracks = function(animator)
        local out = {}
        for i, t in ipairs(rawget(animator, "__d").tracks or {}) do out[i] = t end
        return out
    end
    W.M.LoadAnimation = function(animator, anim)
        local track = W:make("AnimationTrack", "Track", {Animation = anim, IsPlaying = false, Looped = false}, nil)
        rawget(track, "__d").animator = animator
        self.loaded = (self.loaded or 0) + 1
        return track
    end
    W.M.Play = function(track)
        local td = rawget(track, "__d")
        if td.animator then startTrack(td.animator, track) end
        self.played = self.played or {}
        self.played[#self.played + 1] = track.Animation.AnimationId
    end
    W.M.Stop = function(track) stopTrack(track) end
    W.M.AdjustSpeed = function() end

    -- key events sent through the virtual input, with their time
    self.keys = {}
    local origKey = W.M.SendKeyEvent
    W.M.SendKeyEvent = function(vim, pressed, key, ...)
        self.keys[#self.keys + 1] = {name = key.Name, down = pressed, t = W.now}
        return origKey(vim, pressed, key, ...)
    end
    function self:keyTimes(name, down)
        local out = {}
        for _, k in ipairs(self.keys) do if k.name == name and k.down == (down ~= false) then out[#out + 1] = k.t end end
        return out
    end

    ---------------------------------------------------------------------------------------------------- the mouse, rays, raycasts
    W.M.GetMouse = function() return {Hit = self.mouseHit or env.CFrame.new(0, 0, -50)} end
    W.M.ScreenPointToRay = function(cam, x, y)
        local cf = cam.CFrame
        return {Origin = cf.Position, Direction = self.rayDir or cf.LookVector}
    end
    W.raycast = function(origin, dir)
        if self.rayHit then return {Position = self:root(self.rayHit).Position, Instance = self:root(self.rayHit)} end
        if dir.Y < 0 then return {Position = env.Vector3.new(origin.X, 0, origin.Z), Instance = self.floor} end
        return nil
    end

    ---------------------------------------------------------------------------------------------------- the server: Communicate
    local function argName(v) return type(v) == "table" and v.Name or v end
    W.serverHandler = function(remote, method, args)
        if remote.Name ~= "Communicate" then return end
        local a = args[1]
        if type(a) ~= "table" then self.log[#self.log + 1] = {goal = "malformed", t = W.now}; return end
        local rec = {goal = a.Goal, dash = argName(a.Dash), key = argName(a.Key), mobile = a.Mobile, t = W.now,
                     tool = a.Tool and a.Tool.Name or nil, pos = self.meRoot and {self.meRoot.Position.X, self.meRoot.Position.Y, self.meRoot.Position.Z}}
        self.log[#self.log + 1] = rec
        rec.arrive = W.now + W.pingMs / 2000
        if a.Goal == "KeyPress" and rec.key == "Q" and rec.dash then
            local kind = DASH_KIND[rec.dash]
            if rec.arrive < (self.dashReadyAt[kind] or 0) then
                self.ignored[#self.ignored + 1] = rec
                return
            end
            self.dashReadyAt[kind] = rec.arrive + (kind == "forward" and 4.8 or 2.0)
            local lag = self:ownAnimLag()
            if lag > 0 then env.task.delay(lag, function() self:anim(self.meChar, DASH_ANIM[rec.dash], 0.3) end) else self:anim(self.meChar, DASH_ANIM[rec.dash], 0.3) end
            if self.serverDashMoves then
                local root = self.meRoot
                local look = root.CFrame.LookVector
                self.pushes = self.pushes or {}
                self.pushes[#self.pushes + 1] = {root = root, v = look * 70, left = 0.25}
            end
        end
    end
    -- how many log entries match (all fields given must equal)
    function self:count(filter)
        local n = 0
        for _, r in ipairs(self.log) do
            local ok = true
            for k, v in pairs(filter) do if r[k] ~= v then ok = false; break end end
            if ok then n = n + 1 end
        end
        return n
    end
    function self:clearLog() self.log = {}; self.ignored = {} end

    ---------------------------------------------------------------------------------------------------- physics: velocity constraints move parts; enemies keep their velocity
    W.preStep = function(dt)
        if self.humanoidCollides ~= false and self.meChar then              -- the Humanoid switches collisions back on every frame (a noclip has to be re-applied)
            for _, part in ipairs(W.M.GetDescendants(self.meChar)) do
                if part:IsA("BasePart") and not part.CanCollide then rawget(part, "__d").props.CanCollide = true end
            end
        end
        for _, inst in ipairs(W.M.GetDescendants(W.workspace)) do
            local cls = inst.ClassName
            if cls == "LinearVelocity" or cls == "BodyVelocity" then
                local part = inst.Parent
                if part and part:IsA("BasePart") then
                    local v = cls == "LinearVelocity" and inst.VectorVelocity or inst.Velocity
                    rawget(part, "__d").props.CFrame = part.CFrame + v * dt
                end
            end
        end
        for model, v in pairs(self.enemyVel) do
            local root = self:root(model)
            local t = self.truth[model]
            if root and t then                                               -- real position moves on; the client shows it a moment late
                t[1], t[2], t[3] = t[1] + v[1] * dt, t[2] + v[2] * dt, t[3] + v[3] * dt
                local d = self:displayDelay()
                local rd = rawget(root, "__d")
                rd.props.CFrame = env.CFrame.new(t[1] - v[1] * d, t[2] - v[2] * d, t[3] - v[3] * d)
                rd.props.AssemblyLinearVelocity = env.Vector3.new(v[1], v[2], v[3])
            elseif root then
                rawget(root, "__d").props.CFrame = root.CFrame + env.Vector3.new(v[1] * dt, v[2] * dt, v[3] * dt)
            end
        end
        for i = #(self.pushes or {}), 1, -1 do
            local p = self.pushes[i]
            rawget(p.root, "__d").props.CFrame = p.root.CFrame + p.v * dt
            p.left = p.left - dt
            if p.left <= 0 then table.remove(self.pushes, i) end
        end
    end

    ---------------------------------------------------------------------------------------------------- the Tech Lab inside this world
    local mods = {}
    for _, name in ipairs({"tech_math.lua", "tech_data.lua", "tech_options.lua", "tech_lab.lua"}) do
        mods[name] = compileIn(env, TECH_SOURCES[name], "=" .. name)()
    end
    self.TM, self.TD, self.TO, self.Lab = mods["tech_math.lua"], mods["tech_data.lua"], mods["tech_options.lua"], mods["tech_lab.lua"]
    self.busy = false
    self.toasts = {}
    function self:newLab(overrides)
        local e = {
            Players = W.players, RunService = W.runService, UserInputService = W.uis, Workspace = W.workspace, LocalPlayer = self.mePlayer, VirtualInput = W.virtualInput,
            TechMath = self.TM, TechData = self.TD, TechOptions = self.TO,
            connect = function(sig, fn) return sig:Connect(fn) end,
            safe = function(fn, ...) local ok, r = pcall(fn, ...); if ok then return r end end,
            clock = function() return W.now end,
            pingMs = function() return W.pingMs end,
            jitterMs = function() return self.jitter end,
            busy = function() return self.busy end,
            log = function(msg) self.logged = self.logged or {}; self.logged[#self.logged + 1] = msg end,
            toast = function(msg) self.toasts[#self.toasts + 1] = msg end,
            onStatus = function(tech) self.statuses[tech.id] = tech.status end,
        }
        for k, v in pairs(overrides or {}) do e[k] = v end
        self.lab = self.Lab.new(e)
        return self.lab
    end

    function self:run(seconds) W:run(seconds) end

    -- The network (ping = W.pingMs, a round trip). A command I send reaches the server ping / 2 later. My own animations are either played by my client at once
    -- ("predicted") or by the server and sent back ("server": they show up a whole ping after my input). Other players are drawn (ping / 2 + interp) in the past.
    function self:ownAnimLag() return self.animMode == "server" and W.pingMs / 1000 or 0 end
    function self:displayDelay() return (W.pingMs / 2) / 1000 + self.interp end
    -- the player presses a button whose animation `id` the server plays; returns the time of the press and the time the SERVER got it
    function self:press(id, seconds)
        local t0 = W.now
        self.serverTime = self.serverTime or {}
        self.serverTime[id] = t0 + W.pingMs / 2000
        local lag = self:ownAnimLag()
        if lag > 0 then env.task.delay(lag, function() self:anim(self.meChar, id, seconds) end) else self:anim(self.meChar, id, seconds) end
        return t0, self.serverTime[id]
    end
    -- somebody walks at constant velocity v ({x,y,z}); the world moves him for real, what the client shows is old by displayDelay()
    function self:walk(model, v)
        local p = self:pos(model)
        self.truth[model] = {p[1], p[2], p[3]}
        self.enemyVel[model] = v
    end
    function self:truePos(model) local t = self.truth[model]; return t and {t[1], t[2], t[3]} or self:pos(model) end
    -- how many handlers of a fake signal are still connected
    function self:connected(signal)
        local n = 0
        for _, h in ipairs(signal.handlers) do if h.on then n = n + 1 end end
        return n
    end
    -- every instance under my character that a tech may have left behind
    function self:leftovers()
        local out = {}
        local bad = {LinearVelocity = true, BodyVelocity = true, BodyGyro = true, BodyPosition = true, AlignPosition = true, AlignOrientation = true, Attachment = true}
        for _, inst in ipairs(W.M.GetDescendants(W.workspace)) do
            if bad[inst.ClassName] or inst.Name == "TechLabFollow" or inst.Name == "TechLabHook" or inst.Name == "TechLabMark" or inst.Name == "TechLabArrow" then out[#out + 1] = inst.ClassName .. ":" .. inst.Name end
        end
        return out
    end
    function self:errors() return {table.unpack(W.errors)} end
    function self:dist(a, b) local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]; return math.sqrt(dx * dx + dy * dy + dz * dz) end
    function self:kill(model)
        local hum = W.M.FindFirstChildOfClass(model, "Humanoid")
        rawget(hum, "__d").props.Health = 0
        W.fire(W.signalOf(hum, "Died"))
    end
    return self
end

TSB_SIM = S
