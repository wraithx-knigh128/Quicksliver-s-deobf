-- A small Murder Mystery 2 server + world on top of the fake Roblox world (tests/mm2_env.lua): full player rigs, roles, the sheriff's gun, the murderer's knife,
-- a network with a ping and an interpolation delay, bots that run in patterns, the dropped gun - so the hub can be run end to end:
-- tap a button -> the hub aims -> a tool "LocalScript" sends a remote -> the "server" decides whether it hit.
--
-- THIS IS A MODEL, NOT THE REAL GAME. Everything marked ASSUMPTION is my guess at how MM2 behaves (bullet speed, knife speed, reload, hit boxes, the remote
-- layouts ...): the real numbers are not published. What the tests prove is that the hub does the right thing in a world that behaves like this one and
-- (with the options below) in a family of worlds around it - never that the real game behaves like it.
--
--   local sim = MM2_SIM.new{ping = 80, rig = "R15", gunSpeed = nil, knifeSpeed = 80, gunLayout = "knifelocal", knifeLayout = "events"}
--   local me  = sim:spawn("Me", {pos = {0, 3, 0}, rig = "R6"})            -- the first actor spawned with {me = true} (or called Me) is the local player
--   local bob = sim:spawn("Bob", {pos = {20, 3, -40}, move = {kind = "circle", speed = 16, radius = 12}})
--   sim:startRound{murderer = "Alice", sheriff = "Me"}
--   sim.w:load(SCRIPT_SOURCE); sim:run(1)
local World = MM2_WORLD
local Sim = {}
Sim.__index = Sim
MM2_SIM = Sim

local sqrt, floor, ceil, max, min, abs, sin, cos, pi = math.sqrt, math.floor, math.ceil, math.max, math.min, math.abs, math.sin, math.cos, math.pi
local atan2 = math.atan2 or math.atan
local function P(inst) return rawget(inst, "__d").props end        -- raw property table: the engine writing its own state (no strict checks, no signals)

------------------------------------------------------------------------------------------------ rigs
-- {name, size x, y, z, offset x, y, z} from the root part's centre (the root stands 3 studs above the floor in both rigs)
local RIGS = {
    R6 = {
        {"HumanoidRootPart", 2, 2, 1, 0, 0, 0}, {"Torso", 2, 2, 1, 0, 0, 0}, {"Head", 2, 1, 1, 0, 1.5, 0},
        {"Left Arm", 1, 2, 1, -1.5, 0, 0}, {"Right Arm", 1, 2, 1, 1.5, 0, 0},
        {"Left Leg", 1, 2, 1, -0.5, -2, 0}, {"Right Leg", 1, 2, 1, 0.5, -2, 0},
    },
    R15 = {
        {"HumanoidRootPart", 2, 2, 1, 0, 0, 0}, {"LowerTorso", 2, 0.4, 1, 0, -0.8, 0}, {"UpperTorso", 2, 1.6, 1, 0, 0.2, 0}, {"Head", 2, 1, 1, 0, 1.6, 0},
        {"LeftUpperArm", 1, 1.2, 1, -1.5, 0.4, 0}, {"LeftLowerArm", 1, 1.1, 1, -1.5, -0.7, 0}, {"LeftHand", 1, 0.3, 1, -1.5, -1.4, 0},
        {"RightUpperArm", 1, 1.2, 1, 1.5, 0.4, 0}, {"RightLowerArm", 1, 1.1, 1, 1.5, -0.7, 0}, {"RightHand", 1, 0.3, 1, 1.5, -1.4, 0},
        {"LeftUpperLeg", 1, 1.0, 1, -0.5, -1.5, 0}, {"LeftLowerLeg", 1, 1.0, 1, -0.5, -2.2, 0}, {"LeftFoot", 1, 0.3, 1, -0.5, -2.85, 0},
        {"RightUpperLeg", 1, 1.0, 1, 0.5, -1.5, 0}, {"RightLowerLeg", 1, 1.0, 1, 0.5, -2.2, 0}, {"RightFoot", 1, 0.3, 1, 0.5, -2.85, 0},
    },
}
Sim.RIGS = RIGS

------------------------------------------------------------------------------------------------ construction
local DEFAULT_OPTS = {
    ping = 80,              -- round trip in ms (what Stats reports)
    jitter = 0,             -- +- ms of random delay per message
    interpMs = 100,         -- ASSUMPTION: other players are drawn this much further in the past than the one-way latency (Roblox interpolates replicated movement)
    rig = "R15",
    reportVelocity = true,  -- other players' parts report AssemblyLinearVelocity (false: the engine says 0 and the hub has to use its position history)
    gunSpeed = nil,         -- ASSUMPTION: nil = the bullet is a hitscan on the server; a number = a travelling bullet (studs/s)
    gunReload = 2.5, gunRange = 300, gunSpread = 0,
    knifeSpeed = 80,        -- ASSUMPTION: studs/s of a thrown knife
    knifeCooldown = 3, knifeRange = 200, stabRange = 5,
    gunLayout = "knifelocal",   -- knifelocal = Gun.KnifeLocal.CreateBeam.RemoteFunction:InvokeServer(1, aim, "AH2") | shoot = Gun.Remotes.Shoot:FireServer(originCF, aim, hitPart)
    knifeLayout = "events",     -- events = Knife.Events.KnifeThrown:FireServer(cf, cf) | throw = Knife.Throw:FireServer(cf, cf) | other = Knife.Remotes.ThrowRE:FireServer(aimVec, originVec, 1)
    throwKey = "E",
    dataRemote = true,      -- ReplicatedStorage.Remotes.Gameplay.PlayerDataChanged / GetPlayerData exist and tell the client every role (ASSUMPTION)
    botsHold = true,        -- the murderer / sheriff bots keep their weapon in hand (so their tool is visible to everybody)
    camBack = 0,            -- how far behind the head the camera sits (0 = the camera is at the head: no parallax between camera ray and shot)
    cameraScript = true,    -- Roblox's own camera script rewrites Camera.CFrame every render frame (priority Camera = 200): a script that sets it once loses it before the next frame
    speedPolicy = "trust",  -- trust (the client owns its movement) | clientlock (a local game script puts WalkSpeed back) | rubberband (the server pulls speeders back)
    faceCamera = true,      -- my character faces where the camera looks (shift-lock), so a stab goes where I aim
    seed = 12345,
}

function Sim.new(opts)
    local self = setmetatable({}, Sim)
    local o = {}
    for k, v in pairs(DEFAULT_OPTS) do o[k] = v end
    for k, v in pairs(opts or {}) do o[k] = v end
    self.opts = o
    local worldOpts = {ping = o.ping}
    for k, v in pairs(o.world or {}) do worldOpts[k] = v end
    local w = World.new(worldOpts)
    self.w = w
    w:installJson()
    w.genv.WraithsHubUI = MM2_UI
    self.v3 = w.env.Vector3.new
    self.cf = w.env.CFrame
    self.actors, self.byName, self.byPlayer = {}, {}, {}
    self.queue, self.proj, self.dying, self.extras = {}, {}, {}, {}
    self.walls = {}
    self.stats = {shots = 0, throws = 0, stabs = 0, hits = 0, kills = 0, friendly = 0, rejected = 0, rubberbands = 0, pickups = 0}
    self.log = {}
    self.tick = 0
    self.rng = o.seed
    self.handlers = {}
    self.unhandled = {}
    self.pingNow = o.ping
    w.pingMs = o.ping
    self.camUp = 0
    self.userLook = self.v3(0, 0, -1)
    self.round = nil

    -- the ground and the camera
    self.floor = w:make("Part", "Baseplate", {CFrame = self.cf.new(0, -0.5, 0), Size = self.v3(1000, 1, 1000), Anchored = true}, w.workspace)
    w.raycast = function(origin, dir, params) return self:engineRaycast(origin, dir, params) end
    w.serverHandler = function(remote, method, args) return self:onRemote(remote, method, args) end
    w.remoteFunctions = {}
    self:hookInput()
    w.preStep = function(dt) self:update(dt) end
    w.renderSteps["Sim_CameraScript"] = {prio = 200, fn = function() self:cameraScript() end}
    if o.dataRemote then self:ensureDataRemotes() end              -- (they exist from the start, like in the real game: the hub looks for them when it loads)
    return self
end

function Sim:random()                                                  -- deterministic 0..1
    self.rng = (self.rng * 1103515245 + 12345) % 2147483648
    return self.rng / 2147483648
end
function Sim:oneWay()                                                  -- seconds from the client to the server (and back)
    local j = self.opts.jitter
    return max(0.001, (self.pingNow + (j > 0 and (self:random() * 2 - 1) * j or 0)) / 2000)
end
function Sim:later(delay, fn)
    local q = self.queue
    local item = {at = self.w.now + delay, fn = fn}
    local i = #q + 1
    while i > 1 and q[i - 1].at > item.at do q[i] = q[i - 1]; i = i - 1 end
    q[i] = item
end
function Sim:note(kind, text) self.log[#self.log + 1] = {t = self.w.now, kind = kind, text = text} end
function Sim:run(seconds) self.w:run(seconds) end

------------------------------------------------------------------------------------------------ actors
local function buildHist(a) a.hist = {n = 0} end
local function rotate(ox, oz, yaw)
    local c, s = cos(yaw), sin(yaw)
    return ox * c + oz * s, -ox * s + oz * c
end

function Sim:buildChar(a)
    local w = self.w
    local char = w:make("Model", a.name, {}, nil)
    a.char = char
    a.parts = {}
    for _, spec in ipairs(RIGS[a.rig]) do
        local part = w:make("Part", spec[1], {CFrame = self.cf.new(a.x + spec[5], a.y + spec[6], a.z + spec[7]), Size = self.v3(spec[2], spec[3], spec[4]),
            AssemblyLinearVelocity = self.v3(0, 0, 0), CanCollide = spec[1] ~= "HumanoidRootPart", Anchored = false}, char)
        a.parts[#a.parts + 1] = {inst = part, name = spec[1], sx = spec[2], sy = spec[3], sz = spec[4], ox = spec[5], oy = spec[6], oz = spec[7]}
        if spec[1] == "HumanoidRootPart" then a.rootInst = part end
        if spec[1] == "Head" then a.headInst = part end
    end
    P(char).PrimaryPart = a.rootInst
    a.hum = w:make("Humanoid", "Humanoid", {Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, UseJumpPower = true,
        RigType = w.Enum.HumanoidRigType[a.rig], HipHeight = a.rig == "R15" and 2 or 0, MoveDirection = self.v3(0, 0, 0)}, char)
    a.view = {x = a.x, y = a.y, z = a.z, yaw = a.yaw}
    a.placed = {a.x, a.y, a.z}
    self:placeParts(a, a.x, a.y, a.z, a.yaw, 0, 0, 0)
end

function Sim:placeParts(a, x, y, z, yaw, vx, vy, vz)
    local v3, lookAt = self.v3, self.cf.lookAt
    local fx, fz = -sin(yaw), -cos(yaw)
    local vel = self.v3(vx, vy, vz)
    for _, p in ipairs(a.parts) do
        local rx, rz = rotate(p.ox, p.oz, yaw)
        local px, py, pz = x + rx, y + p.oy, z + rz
        local props = P(p.inst)
        props.CFrame = lookAt(v3(px, py, pz), v3(px + fx, py, pz + fz))
        props.AssemblyLinearVelocity = vel
    end
    a.view.x, a.view.y, a.view.z, a.view.yaw = x, y, z, yaw
end

-- opts: pos = {x, y, z}, move = behaviour, rig = "R6" | "R15", me = true
function Sim:spawn(name, o)
    o = o or {}
    local w = self.w
    local pos = o.pos or {0, 3, 0}
    local plr = w:make("Player", name, {UserId = 1000 + #self.actors + 1, DisplayName = o.display or name}, nil)
    w:make("Backpack", "Backpack", {}, plr)
    w:make("PlayerGui", "PlayerGui", {}, plr)
    local a = {name = name, plr = plr, rig = o.rig or self.opts.rig, x = pos[1], y = pos[2] or 3, z = pos[3], vx = 0, vy = 0, vz = 0,
               yaw = o.yaw or 0, alive = true, role = "Innocent", born = w.now, beh = o.move or {kind = "stand"}, isMe = o.me or name == "Me",
               move = {0, 0}, grounded = true, reload = 0, knifeReady = 0, groundY = pos[2] or 3}
    buildHist(a)
    self:buildChar(a)
    P(plr).Character = a.char
    w.setParent(a.char, w.workspace)
    w.fire(rawget(plr, "__d").signals.CharacterAdded, a.char)
    w.setParent(plr, w.players)
    self.actors[#self.actors + 1] = a
    self.byName[name] = a
    self.byPlayer[plr] = a
    if a.isMe then
        self.me = a
        P(w.players).LocalPlayer = plr
        w.localPlayer = plr
        w.me = plr
        self:trackCamera(true)
        local look = self.v3(0, 0, -1)
        P(w.camera).CFrame = self.cf.lookAt(self:headPos(a), self:headPos(a) + look)
        self:installLocalScripts(a)
    end
    return a
end

function Sim:headPos(a, x, y, z)
    return self.v3(x or a.x, (y or a.y) + (a.rig == "R15" and 1.6 or 1.5), z or a.z)
end

function Sim:setBehaviour(a, beh) a.beh = beh; a.born = self.w.now end

------------------------------------------------------------------------------------------------ bot motion (server truth)
-- every behaviour gives the desired horizontal velocity at time t since it started; jumping adds a vertical arc
local function desiredVelocity(beh, t)
    local k = beh.kind
    if k == "line" then
        local dx, dz = beh.dx or 1, beh.dz or 0
        local m = sqrt(dx * dx + dz * dz); if m == 0 then return 0, 0 end
        return dx / m * beh.speed, dz / m * beh.speed
    elseif k == "circle" then
        local r, dir = beh.radius or 10, beh.dir or 1
        local th = (beh.phase or 0) + dir * beh.speed / r * t
        return -sin(th) * beh.speed * dir, cos(th) * beh.speed * dir
    elseif k == "zigzag" then
        local period = beh.period or 0.7
        local flip = (floor(t / period) % 2 == 0) and 1 or -1
        local ang = (beh.angle or 0.8) * flip
        local dx, dz = beh.dx or 1, beh.dz or 0
        local m = sqrt(dx * dx + dz * dz)
        dx, dz = dx / m, dz / m
        local c, s = cos(ang), sin(ang)
        return (dx * c - dz * s) * beh.speed, (dx * s + dz * c) * beh.speed
    elseif k == "stopgo" then
        local run, stop = beh.run or 1.0, beh.stop or 0.7
        if t % (run + stop) < run then
            local dx, dz = beh.dx or 1, beh.dz or 0
            local m = sqrt(dx * dx + dz * dz)
            return dx / m * beh.speed, dz / m * beh.speed
        end
        return 0, 0
    elseif k == "jumpy" then                                         -- bunny hops with Roblox's gravity (a JumpPower 50 jump lasts 0.51 s) and a short pause on the ground
        local dx, dz = beh.dx or 1, beh.dz or 0
        local m = sqrt(dx * dx + dz * dz)
        return dx / m * beh.speed, dz / m * beh.speed
    end
    return 0, 0
end

function Sim:stepBot(a, dt)
    local t = self.w.now - a.born
    if not a.alive then a.vx, a.vz, a.vy = 0, 0, 0; return end
    local vx, vz = desiredVelocity(a.beh, t)
    a.vx, a.vz = vx, vz
    a.x, a.z = a.x + vx * dt, a.z + vz * dt
    if a.beh.kind == "jumpy" then
        local v0, pause = a.beh.jumpPower or 50, a.beh.pause or 0.2
        local air = 2 * v0 / 196.2
        local s = t % (air + pause)
        local ny = s < air and (a.groundY + v0 * s - 0.5 * 196.2 * s * s) or a.groundY
        a.vy = (ny - a.y) / dt
        a.y = ny
    end
    if vx ~= 0 or vz ~= 0 then a.yaw = atan2(-vx, -vz) end
end

-- my own character: the client owns it. WalkSpeed / JumpPower come from the Humanoid (so the hub's changes matter), a script that writes the root's CFrame moves me
function Sim:stepMe(a, dt)
    local props = P(a.hum)
    local root = P(a.rootInst)
    local cfp = root.CFrame.Position
    local pl = a.placed
    if abs(cfp.X - pl[1]) > 1e-4 or abs(cfp.Y - pl[2]) > 1e-4 or abs(cfp.Z - pl[3]) > 1e-4 then      -- somebody (the hub, a game script) moved my root
        a.jumpedBy = a.jumpedBy or 0
        a.x, a.y, a.z = cfp.X, cfp.Y, cfp.Z
        if abs(cfp.Y - pl[2]) > 0.5 then a.vy = 0 end
    end
    if not a.alive then a.vx, a.vz = 0, 0; return end
    local speed = props.WalkSpeed or 16
    local mx, mz = a.move[1], a.move[2]
    local m = sqrt(mx * mx + mz * mz)
    if m > 0 then mx, mz = mx / m, mz / m end
    a.vx, a.vz = mx * speed, mz * speed
    props.MoveDirection = self.v3(mx, 0, mz)
    a.x, a.z = a.x + a.vx * dt, a.z + a.vz * dt
    -- vertical: gravity, jumping with JumpPower
    local jumpPower = props.JumpPower or 50
    if a.wantJump and a.grounded then a.vy = (props.UseJumpPower == false) and sqrt(2 * 196.2 * 7.2) or jumpPower; a.grounded = false end
    a.wantJump = false
    if not a.grounded then
        a.vy = a.vy - 196.2 * dt
        a.y = a.y + a.vy * dt
        if a.y <= a.groundY then a.y = a.groundY; a.vy = 0; a.grounded = true end
    elseif a.y > a.groundY + 0.01 then a.grounded = false end
    if self.opts.faceCamera then
        local look = P(self.w.camera).CFrame.LookVector
        if abs(look.X) + abs(look.Z) > 1e-6 then a.yaw = atan2(-look.X, -look.Z) end
    elseif m > 0 then a.yaw = atan2(-mx, -mz) end
end

------------------------------------------------------------------------------------------------ history + replication to the client
local function record(a, t)
    local h = a.hist
    local n = h.n + 1
    h.n = n
    h[n] = {t = t, x = a.x, y = a.y, z = a.z, vx = a.vx, vy = a.vy, vz = a.vz, yaw = a.yaw}
    if n > 360 then                                                    -- 6 seconds at 60 Hz
        for i = 1, n - 300 do h[i] = h[i + 300] end
        for i = n - 299, n do h[i] = nil end
        h.n = n - 300
    end
end
local function sampleAt(a, t)                                          -- interpolated {x,y,z,vx,vy,vz,yaw} at time t (clamped to the recorded range)
    local h = a.hist
    local n = h.n
    if n == 0 then return nil end
    if t >= h[n].t then return h[n] end
    if t <= h[1].t then return h[1] end
    local i = n
    while i > 1 and h[i - 1].t > t do i = i - 1 end
    local b, c = h[i - 1], h[i]
    local f = (t - b.t) / max(1e-9, c.t - b.t)
    return {x = b.x + (c.x - b.x) * f, y = b.y + (c.y - b.y) * f, z = b.z + (c.z - b.z) * f, vx = c.vx, vy = c.vy, vz = c.vz, yaw = c.yaw}
end
Sim.sampleAt = sampleAt

function Sim:replicate(a)
    local delay = self:oneWay() + self.opts.interpMs / 1000
    local s = sampleAt(a, self.w.now - delay)
    if not s then return end
    local rv = self.opts.reportVelocity
    self:placeParts(a, s.x, s.y, s.z, s.yaw, rv and s.vx or 0, rv and s.vy or 0, rv and s.vz or 0)
end

------------------------------------------------------------------------------------------------ geometry: boxes, rays
local function boxesOf(self, a, x, y, z, yaw)
    local c, s = abs(cos(yaw)), abs(sin(yaw))
    local out = {}
    for i, p in ipairs(a.parts) do
        local rx, rz = rotate(p.ox, p.oz, yaw)
        out[i] = {cx = x + rx, cy = y + p.oy, cz = z + rz, hx = c * p.sx / 2 + s * p.sz / 2, hy = p.sy / 2, hz = s * p.sx / 2 + c * p.sz / 2, name = p.name, part = p.inst}
    end
    return out
end
Sim.boxesOf = boxesOf

-- slab test of the segment o + d*t, t in [0, tmax], against a box grown by `pad`; returns the entry t
local function rayBox(ox, oy, oz, dx, dy, dz, tmax, b, pad)
    pad = pad or 0
    local t0, t1 = 0, tmax
    local function slab(o, d, c, h)
        if abs(d) < 1e-9 then return o >= c - h and o <= c + h end
        local a, bb = (c - h - o) / d, (c + h - o) / d
        if a > bb then a, bb = bb, a end
        if a > t0 then t0 = a end
        if bb < t1 then t1 = bb end
        return t0 <= t1
    end
    if not slab(ox, dx, b.cx, b.hx + pad) then return nil end
    if not slab(oy, dy, b.cy, b.hy + pad) then return nil end
    if not slab(oz, dz, b.cz, b.hz + pad) then return nil end
    return t0
end

function Sim:addWall(cx, cy, cz, sx, sy, sz, name)
    local part = self.w:make("Part", name or "Wall", {CFrame = self.cf.new(cx, cy, cz), Size = self.v3(sx, sy, sz), Anchored = true}, self.round and self.round.map or self.w.workspace)
    self.walls[#self.walls + 1] = {cx = cx, cy = cy, cz = cz, hx = sx / 2, hy = sy / 2, hz = sz / 2, part = part}
    return part
end

-- the nearest thing a ray from o along d (unit) hits within tmax. server = true: actors at their true positions (server truth); false: as drawn on my screen.
-- ignore = set of actors to skip. Returns {t, kind = "wall"|"floor"|"actor", actor, part, name}
function Sim:cast(ox, oy, oz, dx, dy, dz, tmax, server, ignore)
    local best
    local function offer(t, kind, a, name, part) if t and (best == nil or t < best.t) then best = {t = t, kind = kind, actor = a, name = name, part = part} end end
    if dy < -1e-9 and oy > 0 then offer(-oy / dy <= tmax and -oy / dy or nil, "floor") end
    for _, wl in ipairs(self.walls) do offer(rayBox(ox, oy, oz, dx, dy, dz, tmax, wl), "wall", nil, wl.part.Name, wl.part) end
    for _, a in ipairs(self.actors) do
        if not (ignore and ignore[a]) then
            local px, py, pz, yaw
            if server then px, py, pz, yaw = a.x, a.y, a.z, a.yaw else px, py, pz, yaw = a.view.x, a.view.y, a.view.z, a.view.yaw end
            if (px - ox) * (px - ox) + (pz - oz) * (pz - oz) < (tmax + 6) ^ 2 then
                for _, b in ipairs(boxesOf(self, a, px, py, pz, yaw)) do offer(rayBox(ox, oy, oz, dx, dy, dz, tmax, b), "actor", a, b.name, b.part) end
            end
        end
    end
    return best
end

-- workspace:Raycast(origin, direction, params) as the hub uses it (line of sight): walls only, plus any character not in the filter list
function Sim:engineRaycast(origin, dir, params)
    local len = dir.Magnitude
    if len < 1e-9 then return nil end
    local dx, dy, dz = dir.X / len, dir.Y / len, dir.Z / len
    local ignore = {}
    local list = params and params.FilterDescendantsInstances or {}
    for _, inst in ipairs(list) do local a = self.byPlayer[self.w.M.GetPlayerFromCharacter(self.w.players, inst)]; if a then ignore[a] = true end end
    local hit = self:cast(origin.X, origin.Y, origin.Z, dx, dy, dz, len, false, ignore)
    if hit and hit.kind ~= "floor" then
        local pos = self.v3(origin.X + dx * hit.t, origin.Y + dy * hit.t, origin.Z + dz * hit.t)
        return {Position = pos, Distance = hit.t, Instance = hit.part, Normal = self.v3(0, 1, 0)}
    end
    return nil
end

------------------------------------------------------------------------------------------------ the server
function Sim:serverView(a)                                            -- where the server believes `a` is right now (my own position arrives one way late)
    if a.isMe then return sampleAt(a, self.w.now - self:oneWay()) or a end
    return a
end

function Sim:killActor(victim, killer, cause)
    if not victim.alive then return end
    victim.alive = false
    victim.diedAt = self.w.now
    victim.killedBy = killer and killer.name or cause
    self.stats.kills = self.stats.kills + 1
    self:note("kill", string.format("%s killed %s (%s)", killer and killer.name or "?", victim.name, cause or ""))
    local pos = {victim.x, victim.y, victim.z}
    if victim.role == "Sheriff" or victim.role == "Hero" then self:dropGun(pos) end
    self:later(self:oneWay(), function()                               -- the news reaches my client
        local props = P(victim.hum)
        props.Health = 0
        self.w.fire(rawget(victim.hum, "__d").signals["Changed:Health"])
        self.w.fire(rawget(victim.hum, "__d").signals.Died)
    end)
    self:pushRoles()
    self:checkRoundEnd()
end

function Sim:onHit(shooter, victim, weapon)
    self.stats.hits = self.stats.hits + 1
    self:note("hit", string.format("%s hit %s with the %s", shooter.name, victim.name, weapon))
    if weapon == "gun" and victim.role ~= "Murderer" then              -- ASSUMPTION (common knowledge): the sheriff dies for shooting an innocent
        self.stats.friendly = self.stats.friendly + 1
        self:killActor(victim, shooter, "shot by the sheriff")
        self:killActor(shooter, nil, "shot an innocent")
    else
        self:killActor(victim, shooter, weapon)
    end
end

-- a ray fired from the shooter's head at the server's current positions
function Sim:serverRay(shooter, ox, oy, oz, dx, dy, dz, range, ignore)
    local hit = self:cast(ox, oy, oz, dx, dy, dz, range, true, ignore)
    return hit
end

function Sim:gunShot(shooter, aim)
    local o = self.opts
    if not shooter.alive or (shooter.role ~= "Sheriff" and shooter.role ~= "Hero") then self.stats.rejected = self.stats.rejected + 1; return end
    if self.w.now < shooter.reload then self.stats.rejected = self.stats.rejected + 1; self:note("reject", "gun still reloading"); return end
    shooter.reload = self.w.now + o.gunReload - 0.05
    self.stats.shots = self.stats.shots + 1
    local v = self:serverView(shooter)
    local ox, oy, oz = v.x, v.y + (shooter.rig == "R15" and 1.6 or 1.5), v.z
    local dx, dy, dz = aim.X - ox, aim.Y - oy, aim.Z - oz
    local m = sqrt(dx * dx + dy * dy + dz * dz)
    if m < 1e-6 then return end
    dx, dy, dz = dx / m, dy / m, dz / m
    if o.gunSpread > 0 then                                            -- ASSUMPTION: the gun is "inaccurate" by up to this many degrees
        local a1, a2 = (self:random() * 2 - 1) * o.gunSpread * pi / 180, (self:random() * 2 - 1) * o.gunSpread * pi / 180
        local c, s = cos(a1), sin(a1)
        dx, dz = dx * c - dz * s, dx * s + dz * c
        dy = dy + a2
        local mm = sqrt(dx * dx + dy * dy + dz * dz); dx, dy, dz = dx / mm, dy / mm, dz / mm
    end
    local ignore = {[shooter] = true}
    if o.gunSpeed == nil then
        local hit = self:serverRay(shooter, ox, oy, oz, dx, dy, dz, o.gunRange, ignore)
        if hit and hit.kind == "actor" then self:onHit(shooter, hit.actor, "gun") else self:note("miss", "gun shot hit " .. (hit and hit.kind or "nothing")) end
    else
        self:spawnProjectile{kind = "bullet", owner = shooter, x = ox, y = oy, z = oz, dx = dx, dy = dy, dz = dz, speed = o.gunSpeed, life = o.gunRange / o.gunSpeed, radius = 0.15}
    end
end

function Sim:knifeThrow(thrower, aim, originHint)
    local o = self.opts
    if not thrower.alive or thrower.role ~= "Murderer" then self.stats.rejected = self.stats.rejected + 1; return end
    if self.w.now < thrower.knifeReady then self.stats.rejected = self.stats.rejected + 1; self:note("reject", "knife on cooldown"); return end
    thrower.knifeReady = self.w.now + o.knifeCooldown
    self.stats.throws = self.stats.throws + 1
    local v = self:serverView(thrower)
    local ox, oy, oz = v.x, v.y + (thrower.rig == "R15" and 1.6 or 1.5), v.z
    local dx, dy, dz = aim.X - ox, aim.Y - oy, aim.Z - oz
    local m = sqrt(dx * dx + dy * dy + dz * dz)
    if m < 1e-6 then return end
    self:spawnProjectile{kind = "knife", owner = thrower, x = ox, y = oy, z = oz, dx = dx / m, dy = dy / m, dz = dz / m, speed = o.knifeSpeed, life = o.knifeRange / o.knifeSpeed, radius = 0.6}
end

function Sim:stab(attacker)
    if not attacker.alive or attacker.role ~= "Murderer" then return end
    self.stats.stabs = self.stats.stabs + 1
    local fx, fz = -sin(attacker.yaw), -cos(attacker.yaw)
    local v = self:serverView(attacker)
    for _, a in ipairs(self.actors) do
        if a ~= attacker and a.alive then
            local dx, dz = a.x - v.x, a.z - v.z
            local d = sqrt(dx * dx + dz * dz)
            if d <= self.opts.stabRange and abs(a.y - v.y) < 4 and (d < 1.5 or (dx * fx + dz * fz) / d > 0.3) then
                self:onHit(attacker, a, "knife")
            end
        end
    end
end

function Sim:spawnProjectile(p)
    p.t0 = self.w.now
    p.hist = {n = 0}
    p.vx, p.vy, p.vz = p.dx * p.speed, p.dy * p.speed, p.dz * p.speed
    p.yaw = atan2(-p.dx, -p.dz)
    record(p, self.w.now)
    self.proj[#self.proj + 1] = p
    p.name = p.kind == "knife" and "ThrownKnife" or "BulletTrail"
    self:later(self:oneWay(), function() self:makeReplica(p) end)
    self:note("spawn", p.kind .. " fired by " .. p.owner.name)
end

function Sim:makeReplica(p)                                            -- what every client draws: a part flying along the path, one way late
    local w = self.w
    p.replica = w:make("Part", p.name, {CFrame = self.cf.new(p.x, p.y, p.z), Size = self.v3(0.4, 0.4, 2), Anchored = true, CanCollide = false,
        AssemblyLinearVelocity = self.v3(p.vx, p.vy, p.vz)}, w.workspace)
end

-- a loose part flying through the world (a coin, a visual effect, somebody else's projectile): {pos = {x,y,z}, vel = {x,y,z}, life = secs, zig = studs of sideways wobble, zigz = studs of
-- wobble along z}
function Sim:fly(o)
    local p = self.w:make("Part", o.name or "Debris", {CFrame = self.cf.new(o.pos[1], o.pos[2], o.pos[3]), Size = self.v3(0.5, 0.5, 0.5), Anchored = true, CanCollide = false}, self.w.workspace)
    self.extras[#self.extras + 1] = {part = p, x = o.pos[1], y = o.pos[2], z = o.pos[3], vx = o.vel[1], vy = o.vel[2], vz = o.vel[3], t0 = self.w.now, life = o.life or 2, zig = o.zig or 0, zigz = o.zigz or 0}
end
function Sim:stepExtras(dt)
    for i = #self.extras, 1, -1 do
        local e = self.extras[i]
        e.x, e.y, e.z = e.x + e.vx * dt, e.y + e.vy * dt, e.z + e.vz * dt
        local wob = e.zig * math.sin((self.w.now - e.t0) * 18)
        local wobz = e.zigz * math.sin((self.w.now - e.t0) * 18)
        P(e.part).CFrame = self.cf.new(e.x + wob, e.y, e.z + wobz)
        if self.w.now - e.t0 >= e.life then self.w.M.Destroy(e.part); table.remove(self.extras, i) end
    end
end

function Sim:stepProjectiles(dt)
    local now = self.w.now
    for i = #self.proj, 1, -1 do
        local p = self.proj[i]
        local done
        local dist = p.speed * dt
        local steps = max(1, ceil(dist / 0.4))
        local sx, sy, sz = dist / steps * p.dx, dist / steps * p.dy, dist / steps * p.dz
        for _ = 1, steps do
            p.x, p.y, p.z = p.x + sx, p.y + sy, p.z + sz
            if p.y <= 0 then done = "ground"; break end
            for _, wl in ipairs(self.walls) do
                if abs(p.x - wl.cx) <= wl.hx and abs(p.y - wl.cy) <= wl.hy and abs(p.z - wl.cz) <= wl.hz then done = "wall"; break end
            end
            if done then break end
            for _, a in ipairs(self.actors) do
                if a ~= p.owner and a.alive and (a.x - p.x) ^ 2 + (a.z - p.z) ^ 2 < 36 then
                    for _, b in ipairs(boxesOf(self, a, a.x, a.y, a.z, a.yaw)) do
                        if abs(p.x - b.cx) <= b.hx + p.radius and abs(p.y - b.cy) <= b.hy + p.radius and abs(p.z - b.cz) <= b.hz + p.radius then
                            done = a; break
                        end
                    end
                    if done then break end
                end
            end
            if done then break end
        end
        if not done and now - p.t0 >= p.life then done = "range" end
        record(p, now)
        if done then
            p.endT = now
            if type(done) == "table" then self:onHit(p.owner, done, p.kind == "knife" and "knife" or "gun") else self:note("miss", p.kind .. " ended: " .. tostring(done)) end
            table.remove(self.proj, i)
            self.dying[#self.dying + 1] = p
        end
    end
    -- replicas follow the server path one way late; they go away when the path ends
    local d = self:oneWay()
    local function follow(p)
        if not p.replica then return end
        local s = sampleAt(p, now - d)
        if s then
            local props = P(p.replica)
            props.CFrame = self.cf.lookAt(self.v3(s.x, s.y, s.z), self.v3(s.x + p.dx, s.y + p.dy, s.z + p.dz))
        end
    end
    for _, p in ipairs(self.proj) do follow(p) end
    for i = #self.dying, 1, -1 do
        local p = self.dying[i]
        follow(p)
        if now - d >= p.endT then
            if p.replica then self.w.M.Destroy(p.replica) end
            table.remove(self.dying, i)
        end
    end
end

------------------------------------------------------------------------------------------------ rounds, roles, tools, the dropped gun
function Sim:roleTable()
    local out = {}
    for _, a in ipairs(self.actors) do out[a.name] = {Role = a.role, Dead = not a.alive} end
    return out
end
function Sim:pushRoles()
    local ev = self.dataEvent
    if not ev then return end
    local data = self:roleTable()
    self:later(self:oneWay(), function() self.w.fire(self.w.signalOf(ev, "OnClientEvent"), data) end)
end

function Sim:makeTool(a, kind, held)
    local w = self.w
    local name = kind == "gun" and "Gun" or "Knife"
    local tool = w:make("Tool", name, {Enabled = true}, nil)
    w:make("Part", "Handle", {CFrame = self.cf.new(a.x, a.y, a.z), Size = self.v3(0.5, 0.5, 2)}, tool)
    if a.isMe then
        local function remote(class, rname, parentTool, folders)
            local parent = parentTool
            for _, f in ipairs(folders or {}) do parent = w.M.FindFirstChild(parent, f) or w:make("Folder", f, {}, parent) end
            return w:make(class, rname, {}, parent)
        end
        if kind == "gun" then
            if self.opts.gunLayout == "knifelocal" then
                local r = remote("RemoteFunction", "RemoteFunction", tool, {"KnifeLocal", "CreateBeam"})
                self.handlers[r] = function(sender, args) self:gunShot(sender, Sim.posOf(args[2])) end
            else
                local r = remote("RemoteEvent", "Shoot", tool, {"Remotes"})
                self.handlers[r] = function(sender, args) self:gunShot(sender, Sim.posOf(args[2])) end
            end
        else
            local layout = self.opts.knifeLayout
            local r
            if layout == "events" then r = remote("RemoteEvent", "KnifeThrown", tool, {"Events"})
            elseif layout == "throw" then r = remote("RemoteEvent", "Throw", tool, {})
            else r = remote("RemoteEvent", "ThrowRE", tool, {"Remotes"}) end
            self.handlers[r] = function(sender, args)
                local aim = (layout == "other") and args[1] or args[2]
                self:knifeThrow(sender, Sim.posOf(aim))
            end
            local s = remote("RemoteEvent", "Stab", tool, {"Events"})
            self.handlers[s] = function(sender) self:stab(sender) end
        end
        self:wireTool(a, tool, kind)
    end
    local where = held and a.char or w.M.FindFirstChildOfClass(a.plr, "Backpack")
    w.setParent(tool, where)
    a.tools = a.tools or {}
    a.tools[kind] = tool
    return tool
end

function Sim:startRound(spec)
    local w = self.w
    self:endRound(true)
    local map = w:make("Model", "Map", {}, w.workspace)
    w:make("Folder", "CoinContainer", {}, map)
    self.round = {map = map, murderer = spec.murderer, sheriff = spec.sheriff, startedAt = w.now}
    self.walls = {}
    for _, wl in ipairs(spec.walls or {}) do self:addWall(wl[1], wl[2], wl[3], wl[4], wl[5], wl[6]) end
    for _, a in ipairs(self.actors) do
        a.role = "Innocent"
        if a.name == spec.murderer then a.role = "Murderer" elseif a.name == spec.sheriff then a.role = "Sheriff" end
        if not a.alive then
            a.alive = true; P(a.hum).Health = 100
        end
        a.reload, a.knifeReady = 0, 0
        if a.role == "Murderer" then self:makeTool(a, "knife", a.isMe and spec.hold == true or (not a.isMe and self.opts.botsHold)) end
        if a.role == "Sheriff" then self:makeTool(a, "gun", a.isMe and spec.hold == true or (not a.isMe and self.opts.botsHold)) end
    end
    self:pushRoles()
end

function Sim:ensureDataRemotes()
    local w = self.w
    if self.dataEvent then return end
    local remotes = w:make("Folder", "Remotes", {}, w.replicated)
    local gameplay = w:make("Folder", "Gameplay", {}, remotes)
    self.dataEvent = w:make("RemoteEvent", "PlayerDataChanged", {}, gameplay)
    local getter = w:make("RemoteFunction", "GetPlayerData", {}, gameplay)
    w.remoteFunctions[getter] = function() return self:roleTable() end
end

function Sim:endRound(silent)
    if not self.round then return end
    local w = self.w
    for _, a in ipairs(self.actors) do
        for kind, tool in pairs(a.tools or {}) do if tool.Parent then w.M.Destroy(tool) end end
        a.tools = {}
        a.role = "Innocent"
    end
    if self.drop and self.drop.inst then w.M.Destroy(self.drop.inst) end
    self.drop = nil
    if self.round.map then w.M.Destroy(self.round.map) end
    self.round = nil
    self.walls = {}
    if not silent then self:pushRoles() end
end

function Sim:checkRoundEnd()
    if not self.round or self.round.over then return end
    local murderer = self.byName[self.round.murderer]
    if murderer and not murderer.alive then self.round.over = "innocents"; self:note("round", "innocents win") end
end

function Sim:dropGun(pos)
    local w = self.w
    self.drop = {x = pos[1], y = 0.6, z = pos[3]}
    self:later(self:oneWay(), function()
        if self.drop and not self.drop.inst then
            self.drop.inst = w:make("Part", "GunDrop", {CFrame = self.cf.new(self.drop.x, 0.6, self.drop.z), Size = self.v3(1, 1, 2), Anchored = true}, w.workspace)
        end
    end)
end

function Sim:stepDrop()
    local d = self.drop
    if not d then return end
    for _, a in ipairs(self.actors) do
        if a.alive and a.role ~= "Murderer" and a.role ~= "Sheriff" then
            local v = self:serverView(a)
            if (v.x - d.x) ^ 2 + (v.z - d.z) ^ 2 <= 16 and abs(v.y - 3) < 8 then
                self.stats.pickups = self.stats.pickups + 1
                a.role = "Hero"
                self:note("pickup", a.name .. " picked up the gun")
                local inst = d.inst
                self.drop = nil
                if inst then self:later(self:oneWay(), function() if inst.Parent then self.w.M.Destroy(inst) end end) end
                local held = not a.isMe and self.opts.botsHold
                self:later(self:oneWay(), function() self:makeTool(a, "gun", held) end)
                self:pushRoles()
                return
            end
        end
    end
end

------------------------------------------------------------------------------------------------ the client: camera, mouse, tool scripts
function Sim:trackCamera(on) self.camTrack = on end

function Sim:mouse() return self.w.mouse or self.w.env.Vector2.new(640, 360) end
-- the ray under the mouse cursor (origin, unit direction)
function Sim:mouseRay()
    local w = self.w
    local cam = w.camera
    local cf = P(cam).CFrame
    local vp = P(cam).ViewportSize
    local fov = math.rad(P(cam).FieldOfView or 70)
    local m = self:mouse()
    local f = (vp.Y / 2) / math.tan(fov / 2)
    local xr, yr = (m.X - vp.X / 2) / f, -(m.Y - vp.Y / 2) / f
    local look, right, up = cf.LookVector, cf.RightVector, cf.UpVector
    local dx, dy, dz = look.X + right.X * xr + up.X * yr, look.Y + right.Y * xr + up.Y * yr, look.Z + right.Z * xr + up.Z * yr
    local mm = sqrt(dx * dx + dy * dy + dz * dz)
    return cf.Position, dx / mm, dy / mm, dz / mm
end
-- where the mouse points in the world as MY screen shows it (a tool script reads Mouse.Hit): the first thing under the cursor, or far away
function Sim:mouseHit()
    local o, dx, dy, dz = self:mouseRay()
    local hit = self:cast(o.X, o.Y, o.Z, dx, dy, dz, 500, false, {[self.me] = true})
    local t = hit and hit.t or 300
    return self.v3(o.X + dx * t, o.Y + dy * t, o.Z + dz * t), hit
end

function Sim:wireTool(a, tool, kind)
    local w = self.w
    local function equipped() return tool.Parent == a.char end
    local sig = w.signalOf(tool, "Activated")
    sig.Connect(sig, function()
        if not equipped() or not a.alive then return end
        if kind == "gun" then
            if P(tool).Enabled == false then return end
            local aim = self:mouseHit()
            P(tool).Enabled = false                                     -- the tool script shows the reload by disabling the tool
            self:later(self.opts.gunReload, function() if tool.Parent then P(tool).Enabled = true end end)
            local gunRemote = (self.opts.gunLayout == "knifelocal") and w.M.FindFirstChild(w.M.FindFirstChild(w.M.FindFirstChild(tool, "KnifeLocal"), "CreateBeam"), "RemoteFunction")
                or w.M.FindFirstChild(w.M.FindFirstChild(tool, "Remotes"), "Shoot")
            self.clientShots = (self.clientShots or 0) + 1
            if self.opts.gunLayout == "knifelocal" then gunRemote:InvokeServer(1, aim, "AH2")
            else
                local _, hit = self:mouseHit()
                local o = P(w.camera).CFrame.Position
                gunRemote:FireServer(self.cf.new(o.X, o.Y, o.Z), aim, hit and hit.part or nil)
            end
        else
            local stab = w.M.FindFirstChild(w.M.FindFirstChild(tool, "Events"), "Stab")
            self.clientStabs = (self.clientStabs or 0) + 1
            stab:FireServer()
        end
    end)
    if kind == "knife" then
        local uis = w.uis
        w.signalOf(uis, "InputBegan").Connect(w.signalOf(uis, "InputBegan"), function(input, processed)
            if processed or not equipped() or not a.alive then return end
            if input.KeyCode == w.Enum.KeyCode[self.opts.throwKey] then
                local aim = self:mouseHit()
                local o = self:headPos(a)
                local layout = self.opts.knifeLayout
                local remote
                if layout == "events" then remote = w.M.FindFirstChild(w.M.FindFirstChild(tool, "Events"), "KnifeThrown")
                elseif layout == "throw" then remote = w.M.FindFirstChild(tool, "Throw")
                else remote = w.M.FindFirstChild(w.M.FindFirstChild(tool, "Remotes"), "ThrowRE") end
                self.clientThrows = (self.clientThrows or 0) + 1
                if layout == "other" then remote:FireServer(aim, o, 1)
                else remote:FireServer(self.cf.new(o.X, o.Y, o.Z), self.cf.new(aim.X, aim.Y, aim.Z)) end
            end
        end)
    end
end

-- executor input (VirtualInputManager / mousemoverel / mouse1click) and the engine's own tool rules
function Sim:hookInput()
    local w = self.w
    local M = w.M
    local oldKey, oldBtn, oldMove = M.SendKeyEvent, M.SendMouseButtonEvent, M.SendMouseMoveEvent
    M.SendKeyEvent = function(s, pressed, key, ...)
        oldKey(s, pressed, key, ...)
        if key and key.Name then if pressed then w:keyDown(key.Name, false) else w:keyUp(key.Name) end end
    end
    M.SendMouseMoveEvent = function(s, x, y) oldMove(s, x, y); w.mouse = w.env.Vector2.new(x, y) end
    M.SendMouseButtonEvent = function(s, x, y, button, pressed)
        oldBtn(s, x, y, button, pressed)
        w.mouse = w.env.Vector2.new(x, y)
        if pressed then self:click() else w:mouseUp("MouseButton1") end
    end
    M.Activate = function(tool)                                       -- Tool:Activate: only an enabled tool in my hands reacts
        w.calls[#w.calls + 1] = {"Activate", tool}
        local d = rawget(tool, "__d")
        if d.props.Enabled == false then return end
        if self.me and tool.Parent ~= self.me.char then return end
        w.fire(w.signalOf(tool, "Activated"))
    end
    M.EquipTool = function(hum, tool)
        local char = rawget(hum, "__d").parent
        if char and w.isInstance(tool) then
            w.setParent(tool, char)
            w.fire(w.signalOf(tool, "Equipped"))
        end
    end
    local e = w.env
    local oldRel = e.mousemoverel
    e.mousemoverel = function(dx, dy)
        local vp = P(w.camera).ViewportSize
        local m = self:mouse()
        w.mouse = w.env.Vector2.new(max(0, min(vp.X, m.X + dx)), max(0, min(vp.Y, m.Y + dy)))
        if oldRel then oldRel(dx, dy) end
    end
    e.mouse1click = function() w.clicks = (w.clicks or 0) + 1; self:click() end
end

-- a real click of the left mouse button (down + the equipped tool's Activated)
function Sim:click()
    local w = self.w
    w:mouseDown("MouseButton1", false)
    local me = self.me
    for _, c in ipairs(w.M.GetChildren(me.char)) do
        if c.ClassName == "Tool" then w.M.Activate(c) end
    end
    w:mouseUp("MouseButton1")
end

-- the player does it by hand: put the cursor on a world point, click
function Sim:aimMouseAt(pos)
    local cam = self.w.camera
    local v = cam:WorldToViewportPoint(pos)
    self.w.mouse = self.w.env.Vector2.new(v.X, v.Y)
end
function Sim:look(at)                                                  -- the player turns the camera to a world point
    local w = self.w
    local from = self.me and self:headPos(self.me) or P(w.camera).CFrame.Position
    local d = at - from
    if d.Magnitude > 1e-6 then self.userLook = d.Unit end
    P(w.camera).CFrame = self.cf.lookAt(P(w.camera).CFrame.Position, at)
end
-- what the default camera script does every render frame: the camera sits at my head (or camBack behind it) and looks where the PLAYER looks - whatever
-- another script put in Camera.CFrame since the last frame is gone
function Sim:cameraScript()
    local me = self.me
    if not (me and self.camTrack and self.opts.cameraScript) then return end
    local look = self.userLook
    local head = self:headPos(me)
    local back = self.opts.camBack
    local pos = self.v3(head.X - look.X * back, head.Y - look.Y * back + (back > 0 and 2 or 0), head.Z - look.Z * back)
    P(self.w.camera).CFrame = self.cf.lookAt(pos, pos + look)
end

function Sim:installLocalScripts(a)
    local w = self.w
    if self.opts.speedPolicy == "clientlock" then                      -- a local game script that puts WalkSpeed back whenever it changes
        local hum = a.hum
        local sig = w.signalOf(hum, "Changed:WalkSpeed")
        sig.Connect(sig, function() if P(hum).WalkSpeed ~= 16 then P(hum).WalkSpeed = 16 end end)
    end
end

------------------------------------------------------------------------------------------------ the per-frame update (called by World:step before the scripts run)
function Sim:update(dt)
    local w = self.w
    self.tick = self.tick + 1
    -- ping noise the client can measure
    if self.opts.jitter > 0 then self.pingNow = self.opts.ping + (self:random() * 2 - 1) * self.opts.jitter else self.pingNow = self.opts.ping end
    w.pingMs = self.pingNow
    -- due messages first
    local q = self.queue
    while q[1] and q[1].at <= w.now do
        local item = table.remove(q, 1)
        local ok, err = pcall(item.fn)
        if not ok then w.errors[#w.errors + 1] = "sim: " .. tostring(err) end
    end
    for _, a in ipairs(self.actors) do
        if a.isMe then self:stepMe(a, dt) else self:stepBot(a, dt) end
        record(a, w.now)
    end
    self:stepProjectiles(dt)
    self:stepExtras(dt)
    self:stepDrop()
    self:stepAnticheat()
    for _, a in ipairs(self.actors) do
        if a.isMe then
            self:placeParts(a, a.x, a.y, a.z, a.yaw, a.vx, a.vy, a.vz)
            a.placed = {a.x, a.y, a.z}
        else
            self:replicate(a)
        end
    end
    -- (without the camera script the camera still follows my head, keeping whatever direction it was given)
    local me = self.me
    if me and self.camTrack and not self.opts.cameraScript then
        local cf = P(w.camera).CFrame
        local look = cf.LookVector
        local head = self:headPos(me)
        local back = self.opts.camBack
        local pos = self.v3(head.X - look.X * back, head.Y - look.Y * back + (back > 0 and 2 or 0), head.Z - look.Z * back)
        P(w.camera).CFrame = self.cf.lookAt(pos, pos + look)
    end
end

function Sim:stepAnticheat()
    if self.opts.speedPolicy ~= "rubberband" or not self.me then return end
    local me = self.me
    local now = self.w.now
    local a, b = sampleAt(me, now - self:oneWay()), sampleAt(me, now - self:oneWay() - 0.5)
    if a and b and me.hist.n > 40 then
        local sp = sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) / 0.5
        if sp > 24 and now - (me.lastBand or -9) > 1.0 then                 -- ASSUMPTION: the server notices > 24 studs/s sustained for half a second and pulls me back
            me.lastBand = now
            self.stats.rubberbands = self.stats.rubberbands + 1
            self:later(self:oneWay(), function() me.x, me.z = b.x, b.z end)
        end
    end
end

------------------------------------------------------------------------------------------------ client -> server
function Sim:onRemote(remote, method, args)
    local h = self.handlers[remote]
    if not h then self.unhandled[#self.unhandled + 1] = remote:GetFullName(); return nil end
    local sender = self.me
    self:later(self:oneWay(), function() h(sender, args) end)
    return true
end

------------------------------------------------------------------------------------------------ small helpers for the tests
function Sim:actor(name) return self.byName[name] end
function Sim:dead(name) local a = self.byName[name]; return a ~= nil and not a.alive end
function Sim:distance(a, b) return sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) end
function Sim:logHas(kind, pattern)
    for _, e in ipairs(self.log) do if e.kind == kind and (pattern == nil or e.text:find(pattern)) then return true end end
    return false
end
function Sim:summary()
    local out = {}
    for _, e in ipairs(self.log) do out[#out + 1] = string.format("%.2f %s %s", e.t - 1000, e.kind, e.text) end
    return table.concat(out, "\n")
end
-- a bot takes its weapon out (so everybody can see it): a murderer pulls the knife, a sheriff / hero the gun
function Sim:hold(name)
    local a = self.byName[name]
    local kind = (a.role == "Murderer") and "knife" or "gun"
    if a.tools and a.tools[kind] and a.tools[kind].Parent then self.w.setParent(a.tools[kind], a.char); return a.tools[kind] end
    return self:makeTool(a, kind, true)
end
function Sim:preset(settings)                                          -- a saved hub config the script will find when it starts
    self.w.files["wraiths_hub_config.json"] = self.w.jsonEncode(settings)
end
function Sim:setMove(dx, dz) self.me.move = {dx, dz} end
function Sim:jump() self.me.wantJump = true end

-- the position inside whatever a shot sends (a Vector3 or a CFrame)
function Sim.posOf(v)
    local k = World.kindOf(v)
    if k == "CFrame" then return v.Position end
    if k == "Vector3" then return v end
    error("a shot without a position: " .. tostring(k))
end
