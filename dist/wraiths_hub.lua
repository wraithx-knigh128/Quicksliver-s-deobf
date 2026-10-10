--[[ Wraith's Hub (Murder Mystery 2) - roles, ESP, gun finder, perfect shoot / throw, aim reticle, hitbox, player mods.
  Source file: build it into one script with `python3 game_dev/mm2/build_mm2.py` (it fills in the UILib / Logic modules below).
  Everything that depends on the game's private internals (remote names, hit detection) is DISCOVERED at run time - see MM2_NOTES.md. ]]
local Logic = (function()

local Logic = {}

local sqrt, atan2, floor, max, min = math.sqrt, math.atan2 or math.atan, math.floor, math.max, math.min

------------------------------------------------------------------------------------------------ roles
local ROLE_WORDS = {
    murderer = "Murderer", murder = "Murderer", killer = "Murderer", infected = "Infected", zombie = "Infected",
    sheriff = "Sheriff", detective = "Sheriff", gunner = "Sheriff",
    hero = "Hero",
    innocent = "Innocent", civilian = "Innocent", survivor = "Innocent", innocents = "Innocent",
}

-- "murderer " -> "Murderer"; anything unknown -> nil
function Logic.normalizeRole(s)
    if type(s) ~= "string" then return nil end
    return ROLE_WORDS[(s:lower():gsub("[^%a]", ""))]
end

-- what a Tool's name says about its owner: knife -> Murderer, gun -> Sheriff (or Hero), anything else nil
function Logic.toolRole(name)
    if type(name) ~= "string" then return nil end
    local n = name:lower()
    if n:find("knife", 1, true) then return "Murderer" end
    if n == "gun" or n == "revolver" or n:find("^gun[^%a]") then return "Sheriff" end
    return nil
end

-- "Gun" / "Knife" / nil : which weapon slot a tool name belongs to
function Logic.weaponOf(name)
    local r = Logic.toolRole(name)
    if r == "Murderer" then return "Knife" end
    if r == "Sheriff" then return "Gun" end
    return nil
end

local function deadFlag(v)
    if v.Dead == true or v.dead == true or v.Killed == true or v.killed == true then return true end
    if v.Alive == false or v.alive == false then return true end
    return false
end

-- Walks whatever table a "player data" remote returned and lists {key=, role=, dead=}. It accepts the shapes seen in
-- Roblox games: {[name] = {Role = "Murderer"}}, {[name] = "Murderer"}, {Murderer = "name", Sheriff = "name"}, and one level of nesting.
function Logic.parseRoles(data, depth)
    local out = {}
    depth = depth or 0
    if type(data) ~= "table" or depth > 2 then return out end
    for k, v in pairs(data) do
        local keyRole = type(k) == "string" and Logic.normalizeRole(k) or nil
        if type(v) == "table" then
            local r = Logic.normalizeRole(v.Role or v.role or v.Team or v.team)
            if r then
                out[#out + 1] = {key = k, role = r, dead = deadFlag(v)}
            elseif keyRole and (v.Name or v.name or v.Player or v.player) then
                out[#out + 1] = {key = v.Name or v.name or v.Player or v.player, role = keyRole, dead = deadFlag(v)}
            else
                for _, e in ipairs(Logic.parseRoles(v, depth + 1)) do out[#out + 1] = e end
            end
        elseif type(v) == "string" then
            local r = Logic.normalizeRole(v)
            if r and keyRole == nil then out[#out + 1] = {key = k, role = r, dead = false}
            elseif keyRole then out[#out + 1] = {key = v, role = keyRole, dead = false} end
        end
    end
    return out
end

------------------------------------------------------------------------------------------------ aim
-- Where to aim at a moving target. target / velocity / shooter are {x,y,z}; opts:
--   speed    projectile speed in studs/s (0 or nil = instant hit, only latency is led)
--   latency  seconds (one way) added on top
--   strength 0..2 multiplier on the lead (1 = full prediction)
--   maxLead  seconds, never lead further than this
--   vertical 0..1 how much of the vertical velocity to lead (jumping targets are hard to predict)
function Logic.lead(tx, ty, tz, vx, vy, vz, sx, sy, sz, opts)
    opts = opts or {}
    local speed = opts.speed or 0
    local latency = max(0, opts.latency or 0)
    local strength = opts.strength == nil and 1 or opts.strength
    local maxLead = opts.maxLead or 0.6
    local vertical = opts.vertical == nil and 0.5 or opts.vertical
    local t = latency
    local px, py, pz = tx, ty, tz
    for _ = 1, 4 do                                      -- solve "where is it when the shot arrives" (converges in a few steps)
        local dx, dy, dz = px - sx, py - sy, pz - sz
        local flight = speed > 0 and sqrt(dx * dx + dy * dy + dz * dz) / speed or 0
        t = min(maxLead, (latency + flight) * strength)
        px, py, pz = tx + vx * t, ty + vy * t * vertical, tz + vz * t
    end
    return px, py, pz, t
end

-- Direction of (dx,dz) relative to where I look (lx,lz), as one of 8 words; ahead is 0 degrees, right 90.
function Logic.direction(dx, dz, lx, lz)
    local ll = sqrt(lx * lx + lz * lz)
    if ll < 1e-6 then lx, lz, ll = 0, -1, 1 end
    lx, lz = lx / ll, lz / ll
    local fwd = dx * lx + dz * lz
    local rgt = dx * (-lz) + dz * lx                     -- right vector of look (lx, lz): (-lz, lx)
    local ang = atan2(rgt, fwd) * 180 / math.pi          -- 0 ahead, 90 right, -90 left, +-180 behind
    local names = {"ahead", "ahead-right", "right", "behind-right", "behind", "behind-left", "left", "ahead-left"}
    local idx = floor(((ang + 22.5) % 360) / 45) + 1
    return names[idx], ang
end

-- "37 studs ahead-left, 6 higher"
function Logic.describe(dx, dy, dz, lx, lz)
    local flat = sqrt(dx * dx + dz * dz)
    local dist = sqrt(dx * dx + dy * dy + dz * dz)
    local where = flat < 3 and "right here" or Logic.direction(dx, dz, lx, lz)
    local s = string.format("%d studs %s", floor(dist + 0.5), where)
    if dy > 6 then s = s .. ", " .. floor(dy + 0.5) .. " higher" elseif dy < -6 then s = s .. ", " .. floor(-dy + 0.5) .. " lower" end
    return s
end

-- Picks one candidate id. cands: {{id=, dist=, screen=(pixels from the crosshair or nil when off screen), visible=bool, role=, alive=bool}}
-- opts: mode ("Murderer" | "Sheriff" | "Sheriff first" | "Closest to crosshair" | "Nearest"), fov (pixels), maxDist, needVisible
function Logic.pickTarget(cands, opts)
    local best, bestScore
    local mode = opts.mode or "Nearest"
    for _, c in ipairs(cands) do
        local ok = c.alive ~= false and c.dist <= (opts.maxDist or math.huge)
        if ok and opts.needVisible and not c.visible then ok = false end
        if ok and mode == "Murderer" and c.role ~= "Murderer" and c.role ~= "Infected" then ok = false end
        if ok and mode == "Sheriff" and c.role ~= "Sheriff" and c.role ~= "Hero" then ok = false end
        local score = c.dist
        if ok and mode == "Sheriff first" and c.role ~= "Sheriff" and c.role ~= "Hero" then score = c.dist + 1e6 end   -- anyone, but the sheriff / hero wins
        if ok and mode == "Closest to crosshair" then
            if c.screen == nil or c.screen > (opts.fov or math.huge) then ok = false else score = c.screen end
        end
        if ok and opts.fov and opts.fovAlways and (c.screen == nil or c.screen > opts.fov) then ok = false end
        if ok and (bestScore == nil or score < bestScore) then best, bestScore = c.id, score end
    end
    return best
end


------------------------------------------------------------------------------------------------ ping + velocity
-- Smoothed round-trip time. Samples are milliseconds; one spike (a lag blip) must not move the aim, so the value is the EMA of the median of
-- the last few samples.
function Logic.newPing(opts)
    opts = opts or {}
    local keep, alpha = opts.keep or 5, opts.alpha or 0.35
    local self = {samples = {}, ema = nil}
    function self:add(ms)
        if type(ms) ~= "number" or ms ~= ms or ms < 0 or ms > 5000 then return end
        local s = self.samples
        s[#s + 1] = ms
        if #s > keep then table.remove(s, 1) end
        local sorted = {}
        for i, v in ipairs(s) do sorted[i] = v end
        table.sort(sorted)
        local median = sorted[floor((#sorted + 1) / 2)]
        self.ema = self.ema and (self.ema + (median - self.ema) * alpha) or median
    end
    function self:ms() return self.ema or (opts.default or 80) end
    function self:seconds() return self:ms() / 1000 end
    return self
end

-- How far ahead of what I SEE the target really is when my shot arrives: my screen shows other players about one interpolation delay plus half
-- the round trip in the past, and the shot needs another half round trip to reach the server => about ping + interpolation.
--   pingMs      smoothed round trip (ms)       comp  0..1.5 multiplier on the ping part      interpMs  render delay of remote players
--   extraMs     manual trim (can be negative)  max   upper bound in seconds
function Logic.pingLead(pingMs, comp, interpMs, extraMs, maxLead)
    local lead = (pingMs or 0) * (comp == nil and 1 or comp) + (interpMs or 0) + (extraMs or 0)
    return max(0, min(maxLead or 0.8, lead / 1000))
end

-- Velocity from recent position samples {{t=, x=, y=, z=}, ...} (oldest first): the displacement over the last `window` seconds.
-- A jump faster than `maxSpeed` studs/s is a teleport / respawn, not running: it reports 0.
function Logic.estimateVelocity(samples, window, maxSpeed)
    local n = #samples
    if n < 2 then return 0, 0, 0 end
    local cap = maxSpeed or 90
    local last = samples[n]
    local first = last
    for i = n - 1, 1, -1 do
        local a, b = samples[i], samples[i + 1]
        local sdt = b.t - a.t
        if sdt > 0 and sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 + (b.z - a.z) ^ 2) / sdt > cap then break end   -- a teleport: nothing older counts
        first = a
        if last.t - a.t >= (window or 0.18) then break end
    end
    local dt = last.t - first.t
    if dt < 0.04 then return 0, 0, 0 end
    local vx, vy, vz = (last.x - first.x) / dt, (last.y - first.y) / dt, (last.z - first.z) / dt
    if sqrt(vx * vx + vy * vy + vz * vz) > cap then return 0, 0, 0 end
    return vx, vy, vz
end

-- physics velocity when the engine reports one, otherwise what the position history says; never faster than `maxSpeed`
function Logic.pickVelocity(px, py, pz, hx, hy, hz, maxSpeed)
    local ps = sqrt(px * px + py * py + pz * pz)
    local hs = sqrt(hx * hx + hy * hy + hz * hz)
    local vx, vy, vz, speed = px, py, pz, ps
    if not (ps >= 0.5 or hs < 1) then vx, vy, vz, speed = hx, hy, hz, hs end
    local cap = maxSpeed or 90
    if speed > cap then local k = cap / speed; return vx * k, vy * k, vz * k end
    return vx, vy, vz
end

------------------------------------------------------------------------------------------------ shot templates
-- A recorded shot is a list of arguments. descs[i] = {kind = "vec" | "cf" | "inst" | "other", x,y,z}.
-- Returns plan[i] = "origin" | "target" for the position arguments:
--   one position  -> it is the aim point
--   several       -> the one closest to my head (within maxOrigin studs) is the origin, the others are aim points
function Logic.planShot(descs, hx, hy, hz, maxOrigin)
    local plan, positions = {}, {}
    for i, d in ipairs(descs) do
        if d.kind == "vec" or d.kind == "cf" then positions[#positions + 1] = i end
    end
    if #positions == 0 then return plan end
    if #positions == 1 then plan[positions[1]] = "target"; return plan end
    local nearest, nd
    for _, i in ipairs(positions) do
        local d = descs[i]
        local dist = sqrt((d.x - hx) ^ 2 + (d.y - hy) ^ 2 + (d.z - hz) ^ 2)
        if nd == nil or dist < nd then nearest, nd = i, dist end
    end
    for _, i in ipairs(positions) do plan[i] = "target" end
    if nd <= (maxOrigin or 25) then plan[nearest] = "origin" end
    return plan
end

-- remote names worth recording when they are NOT inside the weapon tool
function Logic.looksLikeShotRemote(name)
    if type(name) ~= "string" then return false end
    local n = name:lower()
    for _, w in ipairs({"shoot", "fire", "throw", "knife", "gun", "stab", "slash", "hit", "bullet", "attack"}) do
        if n:find(w, 1, true) then return true end
    end
    return false
end

------------------------------------------------------------------------------------------------ config
-- copy only the keys the script knows, and only with the right type (a hand-edited or old file cannot break anything)
function Logic.mergeFlags(defaults, saved)
    local out = {}
    for k, v in pairs(defaults) do out[k] = v end
    if type(saved) ~= "table" then return out end
    for k, v in pairs(saved) do
        local d = defaults[k]
        if d ~= nil and type(v) == type(d) then out[k] = v end
    end
    return out
end

function Logic.clamp(v, lo, hi) return max(lo, min(hi, v)) end

return Logic

end)()
local UILib = (function()

local UILib = {}

local THEMES = {
    Crimson = {bg = {9, 5, 6}, side = {9, 5, 6}, row = {21, 15, 16}, rowHover = {33, 24, 25}, stroke = {47, 32, 34}, text = {240, 236, 236}, sub = {152, 140, 142},
               accent = {236, 52, 64}, accent2 = {255, 110, 118}, ring = {146, 98, 255}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {60, 47, 49}},
    Ocean = {bg = {5, 8, 13}, side = {5, 8, 13}, row = {14, 21, 32}, rowHover = {22, 33, 49}, stroke = {32, 47, 69}, text = {232, 240, 250}, sub = {131, 150, 176},
             accent = {52, 152, 255}, accent2 = {120, 195, 255}, ring = {120, 195, 255}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {52, 66, 90}},
    Emerald = {bg = {5, 10, 8}, side = {5, 10, 8}, row = {14, 25, 21}, rowHover = {22, 38, 32}, stroke = {32, 56, 48}, text = {232, 247, 240}, sub = {128, 160, 146},
               accent = {46, 204, 113}, accent2 = {120, 235, 170}, ring = {120, 235, 170}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {50, 76, 66}},
    Violet = {bg = {9, 6, 15}, side = {9, 6, 15}, row = {21, 15, 34}, rowHover = {32, 23, 52}, stroke = {50, 36, 78}, text = {242, 236, 252}, sub = {154, 138, 184},
              accent = {155, 89, 255}, accent2 = {196, 150, 255}, ring = {196, 150, 255}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {70, 56, 98}},
    Gold = {bg = {10, 8, 4}, side = {10, 8, 4}, row = {24, 19, 11}, rowHover = {37, 30, 17}, stroke = {62, 51, 31}, text = {250, 244, 230}, sub = {171, 158, 128},
            accent = {240, 178, 40}, accent2 = {255, 214, 100}, ring = {255, 214, 100}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {82, 70, 46}},
}
UILib.ThemeNames = {"Crimson", "Ocean", "Emerald", "Violet", "Gold"}
UILib.IconNames = {"spark", "grid", "eye", "crosshair", "user", "dots", "gear", "terminal", "bolt", "knife", "pistol", "search", "chevron_up", "chevron_down", "close", "minus", "maximize", "move"}

local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end

-- wave skins: layers of travelling grey-white bands (a UIGradient whose Offset moves) over the button's own fill
local WAVE_LAYERS = {
    {rot = 24, periods = 2.0, speed = 0.7, amp = 0.30, phase = 0.0},
    {rot = -20, periods = 2.6, speed = 1.15, amp = 0.24, phase = 2.1},
    {rot = 76, periods = 1.6, speed = 0.45, amp = 0.34, phase = 4.0},
}
local WAVE_LOOKS = {
    ui = {lo = {150, 154, 162}, hi = {236, 240, 248}, alpha = {1.0, 0.86}},        -- rows and small controls: faint light ripples on the dark fill
    float = {lo = {140, 144, 154}, hi = {240, 244, 252}, alpha = {0.97, 0.45}},    -- floating buttons: clearly visible grey-white waves
    pill = {lo = {150, 154, 162}, hi = {236, 240, 248}, alpha = {1.0, 0.78}},
}
-- one layer = 20 keypoints of a sharpened sine: thin bright crests on a transparent background, which reads as ripples on water
local function waveSequences(look, layer, strength)
    local n = 19
    local colors, alphas = {}, {}
    for i = 0, n do
        local t = i / n
        local s = (0.5 + 0.5 * math.sin(2 * math.pi * layer.periods * t + layer.phase)) ^ 2.2
        colors[#colors + 1] = ColorSequenceKeypoint.new(t, Color3.fromRGB(
            math.floor(look.lo[1] + (look.hi[1] - look.lo[1]) * s), math.floor(look.lo[2] + (look.hi[2] - look.lo[2]) * s), math.floor(look.lo[3] + (look.hi[3] - look.lo[3]) * s)))
        alphas[#alphas + 1] = NumberSequenceKeypoint.new(t, look.alpha[1] + (look.alpha[2] - look.alpha[1]) * s * (strength or 1))
    end
    return ColorSequence.new(colors), NumberSequence.new(alphas)
end

function UILib.new(cfg)
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")

    local win = {Flags = {}, Tabs = {}, Elements = {}, Connections = {}, Alive = true, Floats = {}}
    local themeName = THEMES[cfg.Theme] and cfg.Theme or "Crimson"
    local T = THEMES[themeName]
    local themed = {}                                                    -- {inst, prop, key}: re-coloured by SetTheme
    local onError = cfg.OnError or function() end

    local function connect(signal, fn)
        local c = signal:Connect(fn)
        win.Connections[#win.Connections + 1] = c
        return c
    end
    win.Connect = connect
    local function safe(where, fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then onError(where, err) end
        return ok
    end
    win.Safe = safe

    local function mk(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props) do o[k] = v end
        if parent then o.Parent = parent end
        return o
    end
    local function bind(inst, prop, key)                                 -- colour from the theme, now and after SetTheme
        inst[prop] = rgb(T[key])
        themed[#themed + 1] = {inst, prop, key}
    end
    local function corner(inst, px) return mk("UICorner", {CornerRadius = px == "full" and UDim.new(1, 0) or UDim.new(0, px or 8)}, inst) end
    local function stroke(inst, key, thickness)
        local s = mk("UIStroke", {Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, inst)
        bind(s, "Color", key or "stroke")
        return s
    end
    local function tween(inst, props, secs)
        local ok = pcall(function()
            TweenService:Create(inst, TweenInfo.new(secs or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
        end)
        if not ok then for k, v in pairs(props) do pcall(function() inst[k] = v end) end end
    end
    local function viewport()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize
        if not vp or vp.X < 100 then return Vector2.new(1280, 720) end
        return vp
    end

    ---------------------------------------------------------------------------------------------- vector icons
    -- every icon is a handful of Frames drawn on a 20x20 grid; `color` is a theme key or a Color3
    local function icon(kind, parent, size, color, pos)
        size = size or 18
        local k = size / 20
        local holder = mk("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(size, size), Name = "Icon_" .. kind}, parent)
        if pos then holder.Position = pos end
        local function paint(inst, prop)
            if type(color) == "string" then bind(inst, prop, color) else inst[prop] = color end
        end
        local function bar(x, y, w, h, rot, round)
            local f = mk("Frame", {BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x + w / 2) * k, (y + h / 2) * k),
                Size = UDim2.fromOffset(math.max(1, w * k), math.max(1, h * k)), Rotation = rot or 0}, holder)
            paint(f, "BackgroundColor3")
            if round then corner(f, round == true and "full" or round * k) end
            return f
        end
        local function ring(x, y, w, h, thick)
            local f = mk("Frame", {BorderSizePixel = 0, BackgroundTransparency = 1, Position = UDim2.fromOffset(x * k, y * k),
                Size = UDim2.fromOffset(w * k, h * k)}, holder)
            corner(f, "full")
            local s = mk("UIStroke", {Thickness = math.max(1, thick * k), ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, f)
            paint(s, "Color")
            return f
        end
        if kind == "spark" then
            bar(9, 1, 2, 18, 0, true); bar(1, 9, 18, 2, 0, true); bar(4.5, 9, 11, 2, 45, true); bar(4.5, 9, 11, 2, -45, true)
        elseif kind == "grid" then
            bar(2, 2, 7, 7, 0, 2); bar(11, 2, 7, 7, 0, 2); bar(2, 11, 7, 7, 0, 2); bar(11, 11, 7, 7, 0, 2)
        elseif kind == "eye" then
            ring(1, 5, 18, 10, 2); bar(7.5, 7.5, 5, 5, 0, true)
        elseif kind == "crosshair" then
            ring(3, 3, 14, 14, 2); bar(9, 0, 2, 6, 0, true); bar(9, 14, 2, 6, 0, true); bar(0, 9, 6, 2, 0, true); bar(14, 9, 6, 2, 0, true); bar(9, 9, 2, 2, 0, true)
        elseif kind == "user" then
            bar(6, 1.5, 8, 8, 0, true); bar(3, 11, 14, 7, 0, 3.5)
        elseif kind == "dots" then
            bar(2, 8.5, 3.5, 3.5, 0, true); bar(8.25, 8.5, 3.5, 3.5, 0, true); bar(14.5, 8.5, 3.5, 3.5, 0, true)
        elseif kind == "gear" then
            bar(9, 0.5, 2, 19, 0, true); bar(0.5, 9, 19, 2, 0, true); bar(1.5, 9, 17, 2, 45, true); bar(1.5, 9, 17, 2, -45, true); ring(4.5, 4.5, 11, 11, 3)
        elseif kind == "terminal" then
            bar(3, 5.5, 8, 2.2, 38, true); bar(3, 11.5, 8, 2.2, -38, true); bar(11, 15, 7, 2.2, 0, true)
        elseif kind == "bolt" then
            bar(8, 1, 3, 10, 18, 1); bar(9, 9, 3, 10, 18, 1); bar(5, 9, 9, 2.4, 0, 1)
        elseif kind == "knife" then
            bar(8.5, 0, 4, 12, 40, 1.5); bar(3.5, 11.5, 9, 2, 40, true); bar(2, 13, 3, 7, 40, 1)
        elseif kind == "pistol" then
            bar(2, 4, 16, 5.5, 0, 1.5); bar(9, 9, 5, 9, 14, 1.5); bar(5.5, 9.5, 3.5, 3, 0, 1)
        elseif kind == "search" then
            ring(1.5, 1.5, 11, 11, 2); bar(11.2, 14.2, 2.2, 6.5, -45, true)
        elseif kind == "chevron_up" then
            bar(3, 9, 8, 2.2, -42, true); bar(9, 9, 8, 2.2, 42, true)
        elseif kind == "chevron_down" then
            bar(3, 9, 8, 2.2, 42, true); bar(9, 9, 8, 2.2, -42, true)
        elseif kind == "close" then
            bar(2, 9, 16, 2.2, 45, true); bar(2, 9, 16, 2.2, -45, true)
        elseif kind == "minus" then
            bar(3, 9, 14, 2.2, 0, true)
        elseif kind == "maximize" then
            bar(3, 3, 6, 2, 0, 1); bar(3, 3, 2, 6, 0, 1); bar(11, 3, 6, 2, 0, 1); bar(15, 3, 2, 6, 0, 1)
            bar(3, 15, 6, 2, 0, 1); bar(3, 11, 2, 6, 0, 1); bar(11, 15, 6, 2, 0, 1); bar(15, 11, 2, 6, 0, 1)
        elseif kind == "move" then
            bar(9, 1, 2, 18, 0, true); bar(1, 9, 18, 2, 0, true); bar(6.5, 1, 7, 2, 0, true); bar(6.5, 17, 7, 2, 0, true); bar(1, 6.5, 2, 7, 0, true); bar(17, 6.5, 2, 7, 0, true)
        end
        return holder
    end
    win.Icon = icon

    ---------------------------------------------------------------------------------------------- water-wave skins
    -- A skin is a clipped holder with 1-3 gradient layers sitting under the button's text. One Heartbeat connection moves all of them.
    local skins = {}
    win.WaveMode = cfg.WaveMode or "High"
    local function layersFor(mode) return mode == "High" and 3 or mode == "Low" and 1 or 0 end

    function win:Skin(host, o)
        o = o or {}
        local look = WAVE_LOOKS[o.Look or "ui"]
        local holder = mk("Frame", {Name = "Waves", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), ClipsDescendants = true,
            Active = false}, host)
        local skin = {host = host, holder = holder, layers = {}, page = o.Page, global = o.Global, active = o.Active, look = look, radius = o.Radius or 8}
        corner(holder, o.Radius or 8)
        for i, layer in ipairs(WAVE_LAYERS) do
            local f = mk("Frame", {Name = "Wave" .. i, BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0)}, holder)
            corner(f, o.Radius or 8)
            local colorSeq, alphaSeq = waveSequences(look, layer, o.Strength)
            local g = mk("UIGradient", {Color = colorSeq, Transparency = alphaSeq, Rotation = layer.rot, Offset = Vector2.new(0, 0)}, f)
            skin.layers[i] = {frame = f, grad = g, def = layer}
        end
        local n = layersFor(win.WaveMode)
        holder.Visible = n > 0
        for i, l in ipairs(skin.layers) do l.frame.Visible = i <= n end
        skins[#skins + 1] = skin
        function skin:Ripple(x, y)                                        -- a ring of water spreading from the press point
            if win.WaveMode == "Off" or not skin.host.Parent then return end
            local size = math.max(skin.host.AbsoluteSize.X, skin.host.AbsoluteSize.Y, 20)
            local px = clamp((x or skin.host.AbsolutePosition.X + skin.host.AbsoluteSize.X / 2) - skin.host.AbsolutePosition.X, 0, math.max(1, skin.host.AbsoluteSize.X))
            local py = clamp((y or skin.host.AbsolutePosition.Y + skin.host.AbsoluteSize.Y / 2) - skin.host.AbsolutePosition.Y, 0, math.max(1, skin.host.AbsoluteSize.Y))
            local r = mk("Frame", {Name = "Ripple", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(px, py), Size = UDim2.fromOffset(6, 6),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.55, BorderSizePixel = 0}, holder)
            corner(r, "full")
            tween(r, {Size = UDim2.fromOffset(size * 2.2, size * 2.2), BackgroundTransparency = 1}, 0.55)
            task.delay(0.6, function() if r.Parent then r:Destroy() end end)
        end
        return skin
    end

    function win:SetWaveMode(mode)
        if mode ~= "High" and mode ~= "Low" and mode ~= "Off" then return end
        win.WaveMode = mode
        local n = layersFor(mode)
        for _, s in ipairs(skins) do
            if s.holder.Parent then
                s.holder.Visible = n > 0
                for i, l in ipairs(s.layers) do l.frame.Visible = i <= n end
            end
        end
    end

    local waveClock, lastWave = 0, 0
    connect(RunService.Heartbeat, function(dt)
        if win.WaveMode == "Off" then return end
        waveClock = waveClock + dt
        local step = win.WaveMode == "High" and 1 / 30 or 1 / 15
        if waveClock - lastWave < step then return end
        lastWave = waveClock
        local n = layersFor(win.WaveMode)
        local shown = win.Main and win.Main.Visible
        local i = 1
        while i <= #skins do
            local s = skins[i]
            if not s.host.Parent then
                table.remove(skins, i)
            else
                local active = s.global and s.host.Visible or (shown and s.host.Visible and (not s.page or s.page.Visible))
                if active and s.active then active = s.active() end
                if active then
                    for li = 1, n do
                        local l = s.layers[li]
                        l.grad.Offset = Vector2.new(l.def.amp * math.sin(waveClock * l.def.speed + l.def.phase), 0)
                    end
                end
                i = i + 1
            end
        end
    end)

    ---------------------------------------------------------------------------------------------- window frame
    local TOP = 44
    local W, H, SIDE, bigW, bigH
    local function metrics()
        local vp = viewport()
        W = clamp(math.floor(vp.X * 0.52), 380, 680)
        H = clamp(math.floor(vp.Y * 0.88), 290, 480)
        SIDE = clamp(math.floor(W * 0.30), 120, 190)
        bigW, bigH = clamp(math.floor(vp.X * 0.92), 380, 980), clamp(math.floor(vp.Y * 0.92), 280, 640)
    end
    metrics()

    local gui = mk("ScreenGui", {Name = cfg.GuiName or "WraithUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true, DisplayOrder = 50}, nil)
    win.Gui = gui

    local main = mk("Frame", {Name = "Window", Size = UDim2.fromOffset(W, H), Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
        BorderSizePixel = 0, ClipsDescendants = true}, gui)
    bind(main, "BackgroundColor3", "bg")
    corner(main, 12); stroke(main)
    win.Main = main

    -- header: logo, title, subtitle on the left; minimise / maximise / close on the right
    local top = mk("Frame", {Name = "Header", Size = UDim2.new(1, 0, 0, TOP), BackgroundTransparency = 1, BorderSizePixel = 0}, main)
    icon("spark", top, 22, "accent", UDim2.fromOffset(14, 11))
    local logo = mk("TextLabel", {Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(44, 6), Size = UDim2.new(1, -230, 0, 18), Text = cfg.Title or "Hub",
        Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, top)
    bind(logo, "TextColor3", "text")
    local subtitle = mk("TextLabel", {Name = "Subtitle", BackgroundTransparency = 1, Position = UDim2.fromOffset(44, 24), Size = UDim2.new(1, -230, 0, 14), Text = cfg.Subtitle or "",
        Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, top)
    bind(subtitle, "TextColor3", "sub")

    local function ctlButton(kind, offsetFromRight, name)
        local b = mk("TextButton", {Name = name, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -offsetFromRight, 0.5, 0), Size = UDim2.fromOffset(30, 30),
            Text = "", AutoButtonColor = false, BorderSizePixel = 0}, top)
        bind(b, "BackgroundColor3", "row"); corner(b, 8); stroke(b)
        local sk = win:Skin(b, {Radius = 8, Look = "ui", Strength = 0.8})
        icon(kind, b, 16, "accent", UDim2.fromOffset(7, 7))
        return b, sk
    end
    local btnClose, skClose = ctlButton("close", 10, "Close")
    local btnMax, skMax = ctlButton("maximize", 46, "Maximize")
    local btnMin, skMin = ctlButton("minus", 82, "Minimize")

    -- body: sidebar + content
    local body = mk("Frame", {Name = "Body", Position = UDim2.new(0, 0, 0, TOP), Size = UDim2.new(1, 0, 1, -TOP), BackgroundTransparency = 1, BorderSizePixel = 0}, main)
    local side = mk("Frame", {Name = "Sidebar", Size = UDim2.new(0, SIDE, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0}, body)

    local searchBox = mk("Frame", {Name = "SearchBox", Position = UDim2.new(0, 10, 0, 2), Size = UDim2.new(1, -18, 0, 32), BorderSizePixel = 0}, side)
    bind(searchBox, "BackgroundColor3", "row"); corner(searchBox, 9); stroke(searchBox)
    icon("search", searchBox, 16, "accent", UDim2.fromOffset(9, 8))
    local search = mk("TextBox", {Name = "Search", BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -38, 1, 0), Text = "", PlaceholderText = "Search",
        ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}, searchBox)
    bind(search, "TextColor3", "text"); bind(search, "PlaceholderColor3", "sub")

    local groupRow = mk("TextButton", {Name = "Group", Position = UDim2.new(0, 10, 0, 42), Size = UDim2.new(1, -18, 0, 24), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, BorderSizePixel = 0}, side)
    win:Skin(groupRow, {Radius = 8, Look = "ui", Strength = 0.4})
    local groupLabel = mk("TextLabel", {Name = "GroupName", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -30, 1, 0), Text = cfg.Group or "Menu",
        Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, groupRow)
    bind(groupLabel, "TextColor3", "sub")
    local chevUp = icon("chevron_up", groupRow, 14, "sub", UDim2.new(1, -18, 0.5, -7))
    local chevDown = icon("chevron_down", groupRow, 14, "sub", UDim2.new(1, -18, 0.5, -7))
    chevDown.Visible = false

    local tabList = mk("ScrollingFrame", {Name = "Tabs", Position = UDim2.new(0, 0, 0, 68), Size = UDim2.new(1, 0, 1, -72), BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0}, side)
    mk("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, tabList)
    mk("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8)}, tabList)
    local groupOpen = true
    connect(groupRow.MouseButton1Click, function()
        groupOpen = not groupOpen
        tabList.Visible = groupOpen
        chevUp.Visible = groupOpen
        chevDown.Visible = not groupOpen
    end)

    local content = mk("Frame", {Name = "Content", Position = UDim2.new(0, SIDE, 0, 0), Size = UDim2.new(1, -SIDE, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true,
        BorderSizePixel = 0}, body)
    local scroll = mk("ScrollingFrame", {Name = "Pages", Position = UDim2.new(0, 4, 0, 2), Size = UDim2.new(1, -12, 1, -8), BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y}, content)
    bind(scroll, "ScrollBarImageColor3", "accent")
    mk("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
    mk("UIPadding", {PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, scroll)
    win.Scroll = scroll

    -- round avatar with a ring, floating over the top right of the content
    local avatar = mk("ImageLabel", {Name = "Avatar", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, TOP - 4), Size = UDim2.fromOffset(38, 38),
        BorderSizePixel = 0, Image = "", ZIndex = 5}, main)
    bind(avatar, "BackgroundColor3", "row"); corner(avatar, "full")
    local avatarRing = stroke(avatar, "ring"); avatarRing.Thickness = 2

    -- the floating hub pill: shows while the window is hidden; tap = open, drag the handle = move it
    local pill = mk("Frame", {Name = "Pill", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(190, 36), BorderSizePixel = 0,
        Visible = false}, gui)
    bind(pill, "BackgroundColor3", "bg"); corner(pill, "full")
    local pillStroke = stroke(pill, "accent", 2)
    local pillSkin = win:Skin(pill, {Radius = 18, Look = "pill", Global = true})
    local pillHandle = mk("Frame", {Name = "Handle", Position = UDim2.fromOffset(6, 5), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, BorderSizePixel = 0}, pill)
    icon("move", pillHandle, 18, "accent", UDim2.fromOffset(4, 4))
    local pillOpen = mk("TextButton", {Name = "OpenButton", Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, BorderSizePixel = 0}, pill)
    icon("spark", pillOpen, 18, "accent", UDim2.fromOffset(2, 9))
    local pillText = mk("TextLabel", {Name = "PillTitle", BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -30, 1, 0), Text = cfg.Title or "Hub",
        Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, pillOpen)
    bind(pillText, "TextColor3", "text")

    ---------------------------------------------------------------------------------------------- dragging
    local function makeDraggable(handle, target, onEnd)
        local dragging, startX, startY, basePos = false, 0, 0, nil
        connect(handle.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging, startX, startY, basePos = true, input.Position.X, input.Position.Y, target.Position
            end
        end)
        connect(UIS.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                target.Position = UDim2.new(basePos.X.Scale, basePos.X.Offset + (input.Position.X - startX), basePos.Y.Scale, basePos.Y.Offset + (input.Position.Y - startY))
            end
        end)
        connect(UIS.InputEnded, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
                if onEnd then onEnd() end
            end
        end)
    end
    makeDraggable(top, main)
    makeDraggable(side, main)
    makeDraggable(pillHandle, pill)

    ---------------------------------------------------------------------------------------------- tabs, search
    local currentTab
    local function selectTab(tab)
        currentTab = tab
        for _, t in ipairs(win.Tabs) do
            local on = t == tab
            t.page.Visible = on
            t.bar.Visible = on
            t.button.BackgroundTransparency = on and 0 or 1
            t.label.TextColor3 = rgb(on and T.text or T.sub)
        end
        scroll.CanvasPosition = Vector2.new(0, 0)
    end

    local function applySearch()
        local q = (search.Text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if q == "" then
            for _, t in ipairs(win.Tabs) do
                for _, e in ipairs(t.entries) do e.frame.Visible = true end
                t.heading.Visible = false
            end
            selectTab(currentTab or win.Tabs[1])
            return
        end
        for _, t in ipairs(win.Tabs) do
            local section, any = nil, false
            for _, e in ipairs(t.entries) do
                if e.isSection then
                    section = e; e.hits = 0; e.frame.Visible = false
                else
                    local hit = e.key:find(q, 1, true) ~= nil
                    e.frame.Visible = hit
                    if hit then any = true; if section then section.hits = section.hits + 1; section.frame.Visible = true end end
                end
            end
            t.page.Visible = any
            t.heading.Visible = any
            t.bar.Visible = false
            t.button.BackgroundTransparency = 1
        end
    end
    connect(search:GetPropertyChangedSignal("Text"), function() safe("search", applySearch) end)

    function win:Tab(name, iconKind)
        local tab = {name = name, entries = {}, order = 0}
        local button = mk("TextButton", {Name = name, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
            LayoutOrder = #win.Tabs + 1}, tabList)
        bind(button, "BackgroundColor3", "row"); corner(button, 9)
        local tabSkin = win:Skin(button, {Radius = 9, Look = "ui", Strength = 0.55, Active = function() return groupOpen end})
        local bar = mk("Frame", {Name = "Bar", Position = UDim2.new(0, 0, 0.5, -8), Size = UDim2.new(0, 3, 0, 16), BorderSizePixel = 0, Visible = false}, button)
        bind(bar, "BackgroundColor3", "accent"); corner(bar, "full")
        icon(iconKind or "dots", button, 16, "accent", UDim2.fromOffset(12, 7))
        local label = mk("TextLabel", {Name = "Name", BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -40, 1, 0), Text = name,
            Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, button)
        bind(label, "TextColor3", "sub")
        local page = mk("Frame", {Name = name, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0,
            Visible = false, LayoutOrder = #win.Tabs + 1}, scroll)
        mk("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, page)
        local heading = mk("TextLabel", {Name = "SearchHeading", Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = string.upper(name), Font = Enum.Font.GothamBold,
            TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Visible = false, LayoutOrder = 0}, page)
        bind(heading, "TextColor3", "accent")
        tab.button, tab.bar, tab.page, tab.heading, tab.label, tab.skin = button, bar, page, heading, label, tabSkin
        win.Tabs[#win.Tabs + 1] = tab
        connect(button.MouseButton1Click, function()
            if (search.Text or "") ~= "" then search.Text = "" end
            selectTab(tab)
        end)
        connect(button.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then tabSkin:Ripple(input.Position.X, input.Position.Y) end
        end)
        if #win.Tabs == 1 then selectTab(tab) end

        local function nextOrder() tab.order = tab.order + 1; return tab.order end
        local function register(frame, key, isSection)
            local entry = {frame = frame, key = (key or ""):lower(), isSection = isSection, hits = 0}
            tab.entries[#tab.entries + 1] = entry
            return entry
        end
        local function fire(cb, ...) if cb then safe("callback", cb, ...) end end

        -- a row: dark rounded card; text column on the left (wraps, so long descriptions never get cut), a control reserved on the right
        local function newRow(title, desc, controlW, o)
            o = o or {}
            local row = mk("Frame", {Size = UDim2.new(1, 0, 0, o.MinHeight or 40), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = nextOrder()}, page)
            bind(row, "BackgroundColor3", "row"); corner(row, 10); stroke(row)
            local rowSkin
            if o.Skin then rowSkin = win:Skin(row, {Radius = 10, Look = "ui", Strength = 0.5, Page = page}) end
            local col = mk("Frame", {Name = "Text", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, row)
            mk("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, (controlW or 0) + 14), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10)}, col)
            mk("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, col)
            local t = mk("TextLabel", {Name = "Title", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = title or "",
                Font = o.Bold and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 1}, col)
            bind(t, "TextColor3", "text")
            if desc then
                local d = mk("TextLabel", {Name = "Desc", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = desc,
                    Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2}, col)
                bind(d, "TextColor3", "sub")
            end
            local entry = register(row, (title or "") .. " " .. (desc or ""))
            return row, t, rowSkin, entry
        end
        local function addElement(el, flag)
            win.Elements[#win.Elements + 1] = el
            if flag then win.Flags[flag] = el; el.Flag = flag end
            return el
        end
        local function hitOver(row, skin)
            local hit = mk("TextButton", {Name = "Hit", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 4}, row)
            if skin then
                connect(hit.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then skin:Ripple(input.Position.X, input.Position.Y) end
                end)
            end
            return hit
        end

        function tab:Section(title)
            local row, _, _, entry = newRow(title, nil, 54, {Bold = true, MinHeight = 38})
            entry.isSection = true
            return row
        end

        function tab:Label(text)
            local row = mk("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = nextOrder()}, page)
            bind(row, "BackgroundColor3", "row"); corner(row, 10); stroke(row)
            mk("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, row)
            local lbl = mk("TextLabel", {Name = "Text", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text or "",
                Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, row)
            bind(lbl, "TextColor3", "sub")
            local entry = register(row, text)
            local el = {Value = text}
            function el:Set(v) el.Value = tostring(v); lbl.Text = el.Value; entry.key = el.Value:lower() end
            return el
        end

        function tab:Button(o)
            local row, _, rowSkin = newRow(o.Title, o.Desc, 66, {Skin = true})
            local pill = mk("Frame", {Name = "RunPill", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(52, 24), BorderSizePixel = 0}, row)
            bind(pill, "BackgroundColor3", "accent"); corner(pill, 7)
            win:Skin(pill, {Radius = 7, Look = "pill", Page = page})
            local pl = mk("TextLabel", {Name = "PillText", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = o.Label or "Run", Font = Enum.Font.GothamBold, TextSize = 11,
                TextStrokeTransparency = 0.6, ZIndex = 3}, pill)
            bind(pl, "TextColor3", "text")
            local hit = hitOver(row, rowSkin)
            connect(hit.MouseButton1Click, function()
                tween(row, {BackgroundColor3 = rgb(T.rowHover)}, 0.08)
                task.delay(0.12, function() if row.Parent then tween(row, {BackgroundColor3 = rgb(T.row)}, 0.15) end end)
                fire(o.Callback)
            end)
            local el = {Value = nil, Click = function() fire(o.Callback) end}
            function el:Set() end
            return addElement(el)
        end

        function tab:Toggle(o)
            local row = newRow(o.Title, o.Desc, 56)
            local sw = mk("Frame", {Name = "Switch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(44, 24), BorderSizePixel = 0}, row)
            corner(sw, "full")
            local swStroke = mk("UIStroke", {Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, sw)
            bind(swStroke, "Color", "stroke")
            local knob = mk("Frame", {Name = "Knob", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(18, 18), BorderSizePixel = 0}, sw)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); corner(knob, "full")
            local hit = hitOver(row)
            local el = {Value = o.Default == true}
            local function render()
                tween(sw, {BackgroundColor3 = rgb(el.Value and T.accent or T.off)}, 0.12)
                tween(knob, {Position = UDim2.new(0, el.Value and 23 or 3, 0.5, 0)}, 0.12)
            end
            el.render = render
            function el:Set(v, silent)
                v = v == true
                local changed = v ~= el.Value
                el.Value = v; render()
                if not silent and (changed or o.FireSame) then fire(o.Callback, v) end
            end
            sw.BackgroundColor3 = rgb(el.Value and T.accent or T.off)
            knob.Position = UDim2.new(0, el.Value and 23 or 3, 0.5, 0)
            connect(hit.MouseButton1Click, function() el:Set(not el.Value) end)
            addElement(el, o.Flag)
            if el.Value and o.Callback and not o.NoInitialCallback then fire(o.Callback, true) end
            return el
        end

        function tab:Slider(o)
            local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
            local row = mk("Frame", {Name = "SliderRow", Size = UDim2.new(1, 0, 0, 58), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = nextOrder()}, page)
            bind(row, "BackgroundColor3", "row"); corner(row, 10); stroke(row)
            register(row, o.Title)
            local col = mk("Frame", {Name = "Text", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, row)
            mk("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 104), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 30)}, col)
            local t = mk("TextLabel", {Name = "Title", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = o.Title or "",
                Font = Enum.Font.GothamMedium, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, col)
            bind(t, "TextColor3", "text")
            local valueLabel = mk("TextLabel", {Name = "Value", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 10), Size = UDim2.fromOffset(92, 18),
                Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Text = ""}, row)
            bind(valueLabel, "TextColor3", "accent2")
            local track = mk("Frame", {Name = "Track", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.new(1, -28, 0, 6), BorderSizePixel = 0}, row)
            bind(track, "BackgroundColor3", "off"); corner(track, "full")
            local fill = mk("Frame", {Name = "Fill", Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0}, track)
            bind(fill, "BackgroundColor3", "accent"); corner(fill, "full")
            local knob = mk("Frame", {Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0}, track)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); corner(knob, "full")
            local hit = mk("TextButton", {Name = "Hit", AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 34), Text = "",
                AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 4}, row)
            local el = {Value = o.Default or min}
            local decimals = step < 1 and (step < 0.1 and 2 or 1) or 0
            local function snap(v)
                v = clamp(v, min, max)
                v = min + math.floor((v - min) / step + 0.5) * step
                return clamp(tonumber(string.format("%." .. decimals .. "f", v)), min, max)
            end
            local function render()
                local f = max > min and (el.Value - min) / (max - min) or 0
                fill.Size = UDim2.new(f, 0, 1, 0)
                knob.Position = UDim2.new(f, 0, 0.5, 0)
                valueLabel.Text = string.format("%." .. decimals .. "f", el.Value) .. (o.Suffix or "")
            end
            el.Value = snap(el.Value); render()
            function el:Set(v, silent)
                if type(v) ~= "number" then return end
                v = snap(v)
                local changed = v ~= el.Value
                el.Value = v; render()
                if not silent and changed then fire(o.Callback, v) end
            end
            local dragging = false
            local function fromX(x)
                local w = track.AbsoluteSize.X
                el:Set(min + clamp((x - track.AbsolutePosition.X) / (w > 0 and w or 1), 0, 1) * (max - min))
            end
            connect(hit.InputBegan, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true; scroll.ScrollingEnabled = false; fromX(input.Position.X)
                end
            end)
            connect(UIS.InputChanged, function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then fromX(input.Position.X) end
            end)
            connect(UIS.InputEnded, function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                    dragging = false; scroll.ScrollingEnabled = true
                end
            end)
            addElement(el, o.Flag)
            return el
        end

        function tab:Dropdown(o)
            local holder = mk("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = nextOrder()}, page)
            mk("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, holder)
            -- the head stacks the title over the current value, so a long value never gets cut on a narrow phone window
            local head = mk("Frame", {Name = "Head", Size = UDim2.new(1, 0, 0, 40), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = 1}, holder)
            bind(head, "BackgroundColor3", "row"); corner(head, 10); stroke(head)
            local col = mk("Frame", {Name = "Text", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, head)
            mk("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 40), PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9)}, col)
            mk("UIListLayout", {Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder}, col)
            local title = mk("TextLabel", {Name = "Title", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = o.Title or "",
                Font = Enum.Font.GothamMedium, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 1}, col)
            bind(title, "TextColor3", "text")
            local current = mk("TextLabel", {Name = "Value", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = "",
                Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2}, col)
            bind(current, "TextColor3", "accent2")
            local chevron = icon("chevron_down", head, 14, "sub", UDim2.new(1, -26, 0.5, -7))
            local hit = mk("TextButton", {Name = "Hit", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 4}, head)
            local list = mk("Frame", {Name = "Options", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0,
                Visible = false, LayoutOrder = 2}, holder)
            mk("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, list)
            mk("UIPadding", {PaddingLeft = UDim.new(0, 10)}, list)
            register(holder, (o.Title or "") .. " " .. table.concat(o.Values or {}, " "))
            local el = {Value = o.Default, Values = o.Values or {}}
            local buttons = {}
            local function paint()
                current.Text = tostring(el.Value or "-")
                for _, b in ipairs(buttons) do
                    b.label.TextColor3 = rgb(b.value == el.Value and T.accent2 or T.text)
                end
            end
            local function rebuild()
                for _, b in ipairs(buttons) do b.inst:Destroy() end
                buttons = {}
                for i, v in ipairs(el.Values) do
                    local b = mk("TextButton", {Name = "Option", Size = UDim2.new(1, 0, 0, 32), Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i}, list)
                    bind(b, "BackgroundColor3", "rowHover"); corner(b, 8)
                    win:Skin(b, {Radius = 8, Look = "ui", Page = page, Active = function() return list.Visible end})
                    local lb = mk("TextLabel", {Name = "Text", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -16, 1, 0), Text = tostring(v),
                        Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3}, b)
                    buttons[#buttons + 1] = {inst = b, value = v, label = lb}
                    connect(b.MouseButton1Click, function() el:Set(v); list.Visible = false; chevron.Rotation = 0 end)
                end
                paint()
            end
            function el:Set(v, silent)
                local changed = v ~= el.Value
                el.Value = v; paint()
                if not silent and changed then fire(o.Callback, v) end
            end
            function el:SetValues(values) el.Values = values; rebuild() end
            if el.Value == nil then el.Value = el.Values[1] end
            rebuild()
            connect(hit.MouseButton1Click, function() list.Visible = not list.Visible; chevron.Rotation = list.Visible and 180 or 0 end)
            addElement(el, o.Flag)
            return el
        end

        function tab:Keybind(o)
            local row, _, rowSkin = newRow(o.Title, o.Desc, 100, {})
            local btn = mk("TextButton", {Name = "Key", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(84, 26), Text = "",
                AutoButtonColor = false, BorderSizePixel = 0}, row)
            bind(btn, "BackgroundColor3", "rowHover"); corner(btn, 7); stroke(btn)
            win:Skin(btn, {Radius = 7, Look = "ui", Page = page})
            local keyText = mk("TextLabel", {Name = "KeyText", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", Font = Enum.Font.GothamBold, TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3}, btn)
            bind(keyText, "TextColor3", "accent2")
            local el = {Value = o.Default or "None", Down = false}
            local capturing = false
            local function nameOf(input)
                if input.UserInputType == Enum.UserInputType.Keyboard then return input.KeyCode.Name end
                if input.UserInputType == Enum.UserInputType.MouseButton2 then return "MouseButton2" end
                if input.UserInputType == Enum.UserInputType.MouseButton3 then return "MouseButton3" end
                return nil
            end
            function el:Set(v, silent)
                el.Value = type(v) == "string" and v or "None"
                keyText.Text = el.Value
                if not silent and o.Changed then fire(o.Changed, el.Value) end
            end
            keyText.Text = el.Value
            connect(btn.MouseButton1Click, function() capturing = true; keyText.Text = "press a key" end)
            connect(UIS.InputBegan, function(input, processed)
                local n = nameOf(input)
                if not n then return end
                if capturing then
                    capturing = false
                    el:Set(n == "Escape" and "None" or n)
                    return
                end
                if n == el.Value and (not processed or o.IgnoreProcessed) then
                    el.Down = true
                    if o.Callback then fire(o.Callback) end
                end
            end)
            connect(UIS.InputEnded, function(input)
                if nameOf(input) == el.Value then el.Down = false end
            end)
            addElement(el, o.Flag)
            return el
        end

        return tab
    end

    ---------------------------------------------------------------------------------------------- notifications
    local toasts = mk("Frame", {Name = "Toasts", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 10, 0, 58), Size = UDim2.new(0, 200, 1, -70),
        BackgroundTransparency = 1, BorderSizePixel = 0}, gui)
    mk("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Left}, toasts)
    local toastCount, liveToasts = 0, {}
    function win:Notify(o)
        if not win.Alive then return end
        toastCount = toastCount + 1
        local tw = clamp(math.floor(viewport().X * 0.235), 180, 280)
        toasts.Size = UDim2.new(0, tw, 1, -70)
        local kind = o.Type == "good" and "good" or o.Type == "warn" and "warn" or o.Type == "bad" and "bad" or "accent"
        local card = mk("Frame", {Name = "Toast", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, BackgroundTransparency = 1,
            LayoutOrder = toastCount}, toasts)
        bind(card, "BackgroundColor3", "row"); corner(card, 10)
        local edge = stroke(card, kind)
        local bar = mk("Frame", {Name = "Bar", Position = UDim2.fromOffset(7, 7), Size = UDim2.new(0, 3, 1, -14), BorderSizePixel = 0}, card)
        bind(bar, "BackgroundColor3", kind); corner(bar, "full")
        local col = mk("Frame", {Name = "Text", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, card)
        mk("UIPadding", {PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)}, col)
        mk("UIListLayout", {Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder}, col)
        local t = mk("TextLabel", {Name = "Title", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = o.Title or "",
            Font = Enum.Font.GothamBold, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 1}, col)
        bind(t, "TextColor3", "text")
        local c
        if o.Content then
            c = mk("TextLabel", {Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = o.Content, Font = Enum.Font.Gotham,
                TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2}, col)
            bind(c, "TextColor3", "sub")
        end
        liveToasts[#liveToasts + 1] = card
        while #liveToasts > 3 do                                           -- never more than three at once
            local old = table.remove(liveToasts, 1)
            if old.Parent then old:Destroy() end
        end
        tween(card, {BackgroundTransparency = 0}, 0.2)
        task.delay(o.Duration or 3, function()
            if not card.Parent then return end
            tween(card, {BackgroundTransparency = 1}, 0.25)
            tween(t, {TextTransparency = 1}, 0.25)
            if c then tween(c, {TextTransparency = 1}, 0.25) end
            tween(bar, {BackgroundTransparency = 1}, 0.25)
            tween(edge, {Transparency = 1}, 0.25)
            task.delay(0.3, function()
                if card.Parent then card:Destroy() end
                for i, x in ipairs(liveToasts) do if x == card then table.remove(liveToasts, i) break end end
            end)
        end)
    end

    ---------------------------------------------------------------------------------------------- window state
    local expanded, minimized = false, false
    local function layoutSize()
        local w, h = expanded and bigW or W, expanded and bigH or H
        if minimized then h = TOP end
        local keep = main.Position
        main.Size = UDim2.fromOffset(w, h)
        body.Visible = not minimized
        side.Size = UDim2.new(0, SIDE, 1, 0)
        content.Position = UDim2.new(0, SIDE, 0, 0)
        content.Size = UDim2.new(1, -SIDE, 1, 0)
        avatar.Visible = not minimized
        return keep
    end
    local function recenter()
        local w, h = main.Size.X.Offset, main.Size.Y.Offset
        main.Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2)
    end
    function win:Relayout()
        metrics()
        layoutSize()
        recenter()
    end
    function win:SetVisible(v)
        main.Visible = v
        pill.Visible = not v
    end
    function win:Toggle() win:SetVisible(not main.Visible) end
    function win:Minimize() minimized = not minimized; layoutSize() end
    function win:Maximize() expanded = not expanded; if expanded then minimized = false end; layoutSize(); recenter() end
    connect(btnClose.MouseButton1Click, function()
        win:SetVisible(false)
        win:Notify{Title = "Menu hidden", Content = "Tap the pill at the top" .. (win.ToggleKey and (" or press " .. win.ToggleKey.Name) or "") .. " to open it again.", Duration = 3}
    end)
    connect(btnMin.MouseButton1Click, function() win:Minimize() end)
    connect(btnMax.MouseButton1Click, function() win:Maximize() end)
    connect(pillOpen.MouseButton1Click, function() win:SetVisible(true) end)
    for _, pair in ipairs({{btnClose, skClose}, {btnMax, skMax}, {btnMin, skMin}, {pillOpen, pillSkin}}) do
        connect(pair[1].InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then pair[2]:Ripple(input.Position.X, input.Position.Y) end
        end)
    end
    win.ToggleKey = cfg.ToggleKey
    connect(UIS.InputBegan, function(input, processed)
        if not processed and win.ToggleKey and input.KeyCode == win.ToggleKey then win:Toggle() end
    end)
    do   -- a phone turned sideways changes the viewport: keep the window inside it
        local cam = workspace.CurrentCamera
        if cam then connect(cam:GetPropertyChangedSignal("ViewportSize"), function() safe("viewport", function() win:Relayout() end) end) end
    end

    function win:SetTheme(name)
        if not THEMES[name] then return end
        themeName, T = name, THEMES[name]
        for _, b in ipairs(themed) do
            if b[1].Parent ~= nil or b[1] == gui then pcall(function() b[1][b[2]] = rgb(T[b[3]]) end) end
        end
        for _, el in ipairs(win.Elements) do if el.render then el.render() end end
        if currentTab then selectTab(currentTab) end
    end
    function win:GetTheme() return themeName end
    function win:SelectTab(name) for _, t in ipairs(win.Tabs) do if t.name == name then selectTab(t) end end end

    function win:SetAvatar(userId)
        task.spawn(function()
            local ok, img = pcall(function()
                return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok and type(img) == "string" and img ~= "" then avatar.Image = img end
        end)
    end

    function win:GetState()
        local out = {}
        for flag, el in pairs(win.Flags) do out[flag] = el.Value end
        return out
    end
    function win:SetState(state, silent)
        if type(state) ~= "table" then return end
        for flag, v in pairs(state) do
            local el = win.Flags[flag]
            if el and el.Set and type(v) == type(el.Value) then el:Set(v, silent) end
        end
    end

    ---------------------------------------------------------------------------------------------- floating action buttons
    -- A square button with an icon and a label that lives outside the window (it stays when the menu is hidden). Tap = OnPress, drag = move it.
    local floatGui
    local function ensureFloatGui()
        if floatGui then return floatGui end
        floatGui = mk("ScreenGui", {Name = (cfg.GuiName or "WraithUI") .. "_Buttons", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
            DisplayOrder = 45}, nil)
        floatGui.Parent = cfg.Parent
        win.FloatGui = floatGui
        return floatGui
    end

    function win:Floating(o)
        local g = ensureFloatGui()
        local f = {Id = o.Id, Locked = o.Locked == true, Size = o.Size or 72, State = o.State == true}
        local accent = o.Accent or T.accent
        local vp = viewport()
        local fx, fy = (o.Pos and o.Pos[1]) or 0.8, (o.Pos and o.Pos[2]) or 0.25
        local btn = mk("TextButton", {Name = "Float_" .. tostring(o.Id), Text = "", AutoButtonColor = false, BorderSizePixel = 0, Size = UDim2.fromOffset(f.Size, f.Size),
            Position = UDim2.fromOffset(fx * vp.X, fy * vp.Y), BackgroundColor3 = Color3.fromRGB(58, 60, 66), BackgroundTransparency = 0.12, Visible = o.Visible ~= false}, g)
        corner(btn, 14)
        local ring = mk("UIStroke", {Thickness = 2, Color = rgb(accent), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.15}, btn)
        local skin = win:Skin(btn, {Radius = 14, Look = "float", Global = true})
        local iconBox = mk("CanvasGroup", {Name = "IconBox", BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.fromOffset(f.Size, f.Size * 0.62), ZIndex = 3}, btn)
        local ic = icon(o.Icon or "crosshair", iconBox, math.floor(f.Size * 0.42), Color3.fromRGB(246, 247, 250), UDim2.new(0.5, -math.floor(f.Size * 0.21), 0.5, -math.floor(f.Size * 0.21)))
        local label = mk("TextLabel", {Name = "Label", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -6, 0, 14),
            Text = o.Title or "", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.fromRGB(250, 250, 252), TextStrokeTransparency = 0.45, TextStrokeColor3 = Color3.fromRGB(20, 20, 24),
            ZIndex = 3}, btn)
        local shade = mk("Frame", {Name = "Cooldown", BackgroundColor3 = Color3.fromRGB(10, 10, 14), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), ZIndex = 6}, btn)
        corner(shade, 14)
        f.Button, f.Gui = btn, g

        local function place(px, py)
            local v = viewport()
            px = clamp(px, 0, math.max(0, v.X - f.Size)); py = clamp(py, 0, math.max(0, v.Y - f.Size))
            btn.Position = UDim2.fromOffset(px, py)
            return px, py
        end
        function f:GetPos()
            local v = viewport()
            return btn.Position.X.Offset / v.X, btn.Position.Y.Offset / v.Y
        end
        function f:SetPos(x, y) local v = viewport(); place(x * v.X, y * v.Y) end
        function f:SetVisible(b) btn.Visible = b == true end
        function f:SetLocked(b) f.Locked = b == true end
        function f:SetSize(px)
            f.Size = clamp(px, 56, 140)
            label.TextSize = clamp(math.floor(f.Size * 0.135), 8, 13)
            btn.Size = UDim2.fromOffset(f.Size, f.Size)
            iconBox.Size = UDim2.fromOffset(f.Size, f.Size * 0.62)
            ic.Size = UDim2.fromOffset(math.floor(f.Size * 0.42), math.floor(f.Size * 0.42))
            ic.Position = UDim2.new(0.5, -math.floor(f.Size * 0.21), 0.5, -math.floor(f.Size * 0.21))
            local fx2, fy2 = f:GetPos()
            f:SetPos(fx2, fy2)
        end
        function f:SetState(on)                                           -- toggle buttons (SPEED ON / SPEED OFF): label and ring show the state
            f.State = on == true
            if o.Toggle then
                label.Text = f.State and (o.LabelOn or o.Title or "") or (o.LabelOff or o.Title or "")
                local c = f.State and (o.Accent or T.accent) or {150, 150, 160}
                ring.Color = rgb(c)
            end
        end
        function f:SetDim(b)                                              -- e.g. you do not hold the weapon right now
            iconBox.GroupTransparency = b and 0.55 or 0
            label.TextTransparency = b and 0.45 or 0
        end
        function f:Flash(ok)                                              -- green = fired, red = nothing happened
            local c = ok and T.good or T.bad
            ring.Color = rgb(c)
            tween(ring, {Thickness = 4}, 0.08)
            task.delay(0.35, function()
                if not btn.Parent then return end
                local base = accent
                if o.Toggle and not f.State then base = {150, 150, 160} end
                ring.Color = rgb(base); tween(ring, {Thickness = 2}, 0.2)
            end)
        end
        function f:Cooldown(seconds)
            if not seconds or seconds <= 0.05 then return end
            shade.BackgroundTransparency = 0.45
            tween(shade, {BackgroundTransparency = 1}, seconds)
        end
        function f:Destroy() pcall(function() btn:Destroy() end) end
        f:SetSize(f.Size)
        if o.Toggle then f:SetState(f.State) end

        -- press / drag: a tap fires OnPress, moving more than 8 px drags the button (unless it is locked)
        local pressed, dragging, cancelled, sx, sy, bx, by = false, false, false, 0, 0, 0, 0
        connect(btn.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                pressed, dragging, cancelled = true, false, false
                sx, sy = input.Position.X, input.Position.Y
                bx, by = btn.Position.X.Offset, btn.Position.Y.Offset
                skin:Ripple(sx, sy)
            end
        end)
        connect(UIS.InputChanged, function(input)
            if not pressed then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local dx, dy = input.Position.X - sx, input.Position.Y - sy
                if not dragging and not f.Locked and (dx * dx + dy * dy) > 64 then dragging = true end
                if f.Locked and (dx * dx + dy * dy) > 576 then cancelled = true end        -- locked: a long swipe is not a tap either
                if dragging then place(bx + dx, by + dy) end
            end
        end)
        connect(UIS.InputEnded, function(input)
            if not pressed then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                pressed = false
                if dragging then
                    dragging = false
                    if o.OnMoved then safe("float moved", o.OnMoved, f:GetPos()) end
                elseif o.OnPress and not cancelled then
                    local ok, ret = pcall(o.OnPress)
                    if not ok then onError("float press", ret); f:Flash(false)
                    elseif ret == "async" or o.Toggle then                    -- the caller flashes / cools down when it knows the result (toggles show their state instead)
                    else
                        if ret == nil then ret = true end
                        f:Flash(ret ~= false)
                        if type(o.Cooldown) == "number" and ret ~= false then f:Cooldown(o.Cooldown) end
                    end
                end
            end
        end)
        win.Floats[#win.Floats + 1] = f
        return f
    end

    function win:Destroy()
        if not win.Alive then return end
        win.Alive = false
        for _, c in ipairs(win.Connections) do pcall(function() c:Disconnect() end) end
        win.Connections = {}
        skins = {}
        pcall(function() gui:Destroy() end)
        if floatGui then pcall(function() floatGui:Destroy() end) end
    end

    layoutSize()
    gui.Parent = cfg.Parent
    return win
end

return UILib

end)()


local function __run()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local StarterGui = game:GetService("StarterGui")
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = Players.LocalPlayer
    while LocalPlayer == nil do task.wait(0.1); LocalPlayer = Players.LocalPlayer end

    local function service(name) local ok, s = pcall(function() return game:GetService(name) end); return ok and s or nil end
    local VIM, VirtualUser, TeleportService, Stats = service("VirtualInputManager"), service("VirtualUser"), service("TeleportService"), service("Stats")

    ------------------------------------------------------------------------------------------ session / logging
    local genv = (getgenv and getgenv()) or _G
    if type(genv.__WraithsHub) == "table" and genv.__WraithsHub.Destroy then pcall(genv.__WraithsHub.Destroy) end
    local Hub = {Alive = true, Conns = {}, Cleanups = {}}
    genv.__WraithsHub = Hub
    Hub.Destroy = function()
        if not Hub.Alive then return end
        Hub.Alive = false
        for _, c in ipairs(Hub.Conns) do pcall(function() c:Disconnect() end) end
        for _, fn in ipairs(Hub.Cleanups) do pcall(fn) end
        if Hub.Win then pcall(function() Hub.Win:Destroy() end) end
        if genv.__WraithsHub == Hub then genv.__WraithsHub = nil end
    end

    local LOG, LOG_MAX = {}, 40
    Hub.Log = LOG
    local function logLine(s)
        LOG[#LOG + 1] = string.format("%s  %s", string.format("%.0f", os.clock() % 100000), s)
        if #LOG > LOG_MAX then table.remove(LOG, 1) end
    end
    local function report(where, err) logLine("[" .. where .. "] " .. tostring(err)) end
    local function guard(where, fn)
        return function(...)
            local ok, err = pcall(fn, ...)
            if not ok then report(where, err) end
        end
    end
    local function track(conn) Hub.Conns[#Hub.Conns + 1] = conn; return conn end
    local function onCleanup(fn) Hub.Cleanups[#Hub.Cleanups + 1] = fn end
    local function now() return os.clock() end

    ------------------------------------------------------------------------------------------ what this executor can do
    local Cap = {
        hook = type(hookmetamethod) == "function" and type(getnamecallmethod) == "function",
        newcclosure = type(newcclosure) == "function",
        setnamecall = type(setnamecallmethod) == "function",
        drawing = type(Drawing) == "table" and type(Drawing.new) == "function",
        files = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function",
        clipboard = type(setclipboard) == "function",
        mouseRel = type(mousemoverel) == "function",
        mouseClick = type(mouse1click) == "function",
        gethui = type(gethui) == "function",
        http = type(game.HttpGet) == "function" or type(request) == "function",
    }

    ------------------------------------------------------------------------------------------ settings
    local DEFAULTS = {
        notifyRoles = true, murdererAlert = true, alertDistance = 40, notifyGun = true, gunHud = true, useRemoteData = true,
        espPlayers = true, espChams = true, espNames = true, espDistance = true, espHealth = false, espInnocents = true, espTracers = false,
        espGun = true, gunTracer = true,
        aimMode = "Auto (by my role)", aimPart = "Head", wallCheck = true, maxDistance = 300, fov = 220, showFov = false,
        predict = true, bulletSpeed = 0, predictStrength = 1, addPing = true,
        aimLock = false, aimMethod = "Camera", aimSmooth = 0, aimKey = "Z",
        autoShoot = false, shootGap = 2.5, shootKey = "X", silentAim = false, fireMethod = "Auto",
        throwKey = "E", throwAtKey = "C", autoThrow = false, throwGap = 2, slashAura = false, slashRange = 9,
        hitbox = false, hitboxSize = 8, hitboxAlpha = 0.6, hitboxWho = "Murderer",
        reticle = "Weapon in hand", pingComp = 1, interpMs = 50, extraLead = 0,
        btnShoot = true, btnThrow = true, btnGrab = false, btnSpeed = false, btnJump = false, btnSize = 80, btnLock = false, waves = "High",
        shootX = -1, shootY = -1, throwX = -1, throwY = -1, grabX = -1, grabY = -1, speedX = -1, speedY = -1, jumpX = -1, jumpY = -1,   -- -1 = placed automatically (down the right edge)
        walkOn = false, walkSpeed = 24, jumpOn = false, jumpPower = 60, infJump = false, noclip = false, fovOn = false, fovValue = 80,
        antiAfk = true, theme = "Crimson", uiKey = "RightShift",
    }
    local CONFIG_FILE = "wraiths_hub_config.json"
    local saved
    if Cap.files then
        local okf, exists = pcall(isfile, CONFIG_FILE)
        if okf and exists then
            local okr, decoded = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
            if okr then saved = decoded else report("config", decoded) end
        end
    end
    local S = Logic.mergeFlags(DEFAULTS, saved)

    ------------------------------------------------------------------------------------------ small helpers
    local function camera() return workspace.CurrentCamera end
    local function myChar() return LocalPlayer.Character end
    local function rootOf(char)
        return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
    end
    local function headOf(char) return char and (char:FindFirstChild("Head") or rootOf(char)) end
    local function humOf(char) return char and char:FindFirstChildOfClass("Humanoid") end
    local function isAlive(char) local h = humOf(char); return h ~= nil and h.Health > 0 end
    local function myRoot() return rootOf(myChar()) end
    local function lookXZ() local cam = camera(); local l = cam and cam.CFrame.LookVector; return l and l.X or 0, l and l.Z or -1 end
    local function nameOf(plr) return plr.DisplayName ~= "" and plr.DisplayName or plr.Name end

    -- measured ping (round trip), smoothed so one lag spike cannot throw the aim off
    local Ping = Logic.newPing{default = 80}
    local function samplePing()
        local ok, ms = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if ok and type(ms) == "number" then Ping:add(ms) end
    end
    -- how far ahead of what I see the aim point goes (seconds): ping + the render delay of remote players
    local function leadSeconds()
        return Logic.pingLead(Ping:ms(), S.addPing and S.pingComp or 0, S.interpMs, S.extraLead, 0.8)
    end

    local function uiParent()
        if Cap.gethui then local ok, h = pcall(gethui); if ok and h then return h end end
        local ok, cg = pcall(function() return game:GetService("CoreGui") end)
        if ok and cg then
            local okp = pcall(function() local f = Instance.new("Folder"); f.Parent = cg; f:Destroy() end)
            if okp then return cg end
        end
        return LocalPlayer:WaitForChild("PlayerGui")
    end
    local PARENT = uiParent()

    local Win   -- the window; created further down. Toasts raised before that wait in a queue.
    local queued = {}
    local function notify(title, content, kind, secs)
        if Win then Win:Notify{Title = title, Content = content, Type = kind or "info", Duration = secs or 4}; return end
        queued[#queued + 1] = {title, content, kind, secs}
    end

    ------------------------------------------------------------------------------------------ roles
    local Roles = {map = {}, data = {}, announced = {}, mapSeen = false, lastActive = 0, dataFails = 0, getter = nil}
    Roles.mine = nil

    local function findPlayerByKey(key)
        if typeof(key) == "Instance" and key:IsA("Player") then return key end
        if type(key) == "number" then return Players:GetPlayerByUserId(key) end
        if type(key) == "string" then
            local id = tonumber(key)
            if id then local p = Players:GetPlayerByUserId(id); if p then return p end end
            local p = Players:FindFirstChild(key)
            if p and p:IsA("Player") then return p end
            for _, q in ipairs(Players:GetPlayers()) do
                if q.Name == key or q.DisplayName == key then return q end
            end
        end
    end

    function Roles.ingest(tbl, replace)
        if type(tbl) ~= "table" then return 0 end
        local entries = Logic.parseRoles(tbl)
        if replace then Roles.data = {} end
        local n = 0
        for _, e in ipairs(entries) do
            local plr = findPlayerByKey(e.key)
            if plr then Roles.data[plr] = {role = e.role, dead = e.dead, t = now()}; n = n + 1 end
        end
        if n == 0 and next(tbl) ~= nil and not Roles.warnedShape then
            Roles.warnedShape = true
            local keys = {}
            for k in pairs(tbl) do keys[#keys + 1] = tostring(k); if #keys >= 5 then break end end
            logLine("player data not understood, keys: " .. table.concat(keys, ","))
        end
        return n
    end

    local function connectDataRemotes()
        local ok, err = pcall(function()
            local ev = ReplicatedStorage:FindFirstChild("PlayerDataChanged", true)
            if ev and ev:IsA("RemoteEvent") then
                track(ev.OnClientEvent:Connect(guard("PlayerDataChanged", function(...)
                    local args = table.pack(...)
                    for i = 1, args.n do if type(args[i]) == "table" then Roles.ingest(args[i], true); break end end
                end)))
                logLine("listening to " .. ev:GetFullName())
            end
            local getter = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
            if getter and getter:IsA("RemoteFunction") then Roles.getter = getter; logLine("found " .. getter:GetFullName()) end
        end)
        if not ok then report("data remotes", err) end
    end

    local function pollData()
        if not (S.useRemoteData and Roles.getter and Roles.dataFails < 3 and Roles.getter.Parent) then return end
        if Roles.polling then return end
        Roles.polling = true
        task.spawn(function()
            local ok, res = pcall(function() return Roles.getter:InvokeServer() end)
            Roles.polling = false
            if ok and type(res) == "table" then
                if Roles.ingest(res, true) > 0 then Roles.dataFails = 0 else Roles.dataFails = Roles.dataFails + 1 end
            else
                Roles.dataFails = Roles.dataFails + 1
                if not ok then report("GetPlayerData", res) end
            end
        end)
    end

    local function toolsIn(container, fn)
        if not container then return end
        for _, t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") then fn(t) end
        end
    end

    local function mapLoaded()                       -- a round map holds the coins; only used to expire stale player data
        for _, c in ipairs(workspace:GetChildren()) do
            if c:IsA("Model") and c:FindFirstChild("CoinContainer") then return true end
        end
        return false
    end

    function Roles.scan()
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        local list, toolRole, toolAny = Players:GetPlayers(), {}, false
        for _, plr in ipairs(list) do                                         -- 1. who visibly holds a knife / gun
            local role
            local function look(t)
                local r = Logic.toolRole(t.Name)
                if r == "Murderer" then role = "Murderer" elseif r == "Sheriff" and role ~= "Murderer" then role = "Sheriff" end
            end
            toolsIn(plr.Character, look)
            if plr == LocalPlayer then toolsIn(backpack, look) end
            toolRole[plr] = role
            if role then toolAny = true end
        end
        -- 2. data from the previous round: the map is gone and nobody holds a weapon
        local loaded = mapLoaded()
        if loaded then Roles.mapSeen = true end
        if not toolAny and Roles.mapSeen and not loaded then Roles.data = {} end
        -- 3. merge tools + data
        local map, any = {}, false
        for _, plr in ipairs(list) do
            local role, dead = toolRole[plr], false
            local d = Roles.data[plr]
            if d then
                if role == nil then role = d.role elseif role == "Sheriff" and d.role == "Hero" then role = "Hero" end
                dead = d.dead == true
            end
            if plr.Character and not isAlive(plr.Character) then dead = true end
            if role and role ~= "Innocent" then any = true end
            map[plr] = {role = role, dead = dead}
        end
        if any then
            for _, info in pairs(map) do if info.role == nil then info.role = "Innocent" end end
        end
        Roles.map = map
        Roles.active = any
        if any then Roles.lastActive = now() end
        Roles.mine = map[LocalPlayer] and map[LocalPlayer].role
        return map
    end

    function Roles.find(role)
        for plr, info in pairs(Roles.map) do
            if info.role == role and not info.dead then return plr end
        end
    end
    function Roles.murderer() return Roles.find("Murderer") or Roles.find("Infected") end
    function Roles.sheriff() return Roles.find("Sheriff") or Roles.find("Hero") end

    local ROLE_COLOR = {
        Murderer = Color3.fromRGB(255, 70, 70), Infected = Color3.fromRGB(255, 120, 60), Sheriff = Color3.fromRGB(70, 150, 255),
        Hero = Color3.fromRGB(255, 205, 60), Innocent = Color3.fromRGB(90, 225, 125),
    }
    local NO_ROLE = Color3.fromRGB(220, 220, 230)

    ------------------------------------------------------------------------------------------ gun drops
    local Guns = {drops = {}, announced = {}}

    local function posOfThing(inst)
        if inst:IsA("BasePart") then return inst.Position end
        if inst:IsA("Model") then
            local ok, cf = pcall(function() return inst:GetPivot() end)
            if ok then return cf.Position end
        end
    end
    local function acceptDrop(inst, loose)
        if not (inst:IsA("BasePart") or inst:IsA("Model")) then return false end
        local n = inst.Name:lower()
        local exact = n == "gundrop" or n == "gun_drop" or n == "gun drop" or n == "droppedgun"
        if not exact and not (loose and n:find("^gun")) then return false end
        if inst:FindFirstAncestorOfClass("Tool") then return false end
        if inst.Parent and inst.Parent:FindFirstChildOfClass("Humanoid") then return false end
        return true
    end

    local function myPos() local r = myRoot(); return r and r.Position end
    local function describeFromMe(pos)
        local me = myPos()
        if not me then return "somewhere" end
        local lx, lz = lookXZ()
        return Logic.describe(pos.X - me.X, pos.Y - me.Y, pos.Z - me.Z, lx, lz)
    end

    function Guns.add(inst, loose)
        if Guns.drops[inst] or not acceptDrop(inst, loose) then return end
        Guns.drops[inst] = {t = now()}
        Guns.fallback = nil
        logLine("gun drop: " .. inst:GetFullName())
        if S.notifyGun then
            local pos = posOfThing(inst)
            notify("Gun dropped!", pos and describeFromMe(pos) or "check the map", "warn", 6)
        end
    end
    function Guns.remove(inst)
        if not Guns.drops[inst] then return end
        Guns.drops[inst] = nil
        Guns.pickedAt = now()
        if S.notifyGun and next(Guns.drops) == nil then notify("Gun picked up", "someone grabbed it", "info", 3) end
    end

    local function nearestGun()   -- returns the part (nil for the 'sheriff died here' fallback), its position, and the distance
        local me = myPos()
        local best, bestD, bestPos
        for inst in pairs(Guns.drops) do
            local p = inst.Parent and posOfThing(inst)
            if p then
                local d = me and (p - me).Magnitude or 0
                if not bestD or d < bestD then best, bestD, bestPos = inst, d, p end
            end
        end
        if best then return best, bestPos, bestD end
        local fb = Guns.fallback
        if fb and now() - fb.t < 60 then return nil, fb.pos, me and (fb.pos - me).Magnitude or 0 end
    end

    local function scanWorkspaceForGuns()
        task.spawn(function()
            local list = workspace:GetDescendants()
            for i, inst in ipairs(list) do
                if not Hub.Alive then return end
                pcall(Guns.add, inst, false)
                if i % 4000 == 0 then task.wait() end
            end
        end)
    end

    ------------------------------------------------------------------------------------------ ESP
    local ESP = {objs = {}, tracers = {}, gunObjs = {}}
    local espFolder = Instance.new("Folder")
    espFolder.Name = "WraithsHubESP"
    espFolder.Parent = PARENT:IsA("PlayerGui") and workspace or PARENT    -- Highlights do not render under a PlayerGui
    onCleanup(function() espFolder:Destroy() end)

    local function removeESP(plr)
        local o = ESP.objs[plr]
        if o then
            pcall(function() o.hl:Destroy() end)
            pcall(function() o.bb:Destroy() end)
            ESP.objs[plr] = nil
        end
    end

    local function buildESP(plr, char)
        local o = {char = char}
        local hl = Instance.new("Highlight")
        hl.Name = "H"
        hl.Adornee = char
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 0.7
        hl.OutlineTransparency = 0
        hl.Parent = espFolder
        o.hl = hl
        local bb = Instance.new("BillboardGui")
        bb.Name = "B"
        bb.Adornee = headOf(char)
        bb.AlwaysOnTop = true
        bb.Size = UDim2.new(0, 170, 0, 34)
        bb.StudsOffset = Vector3.new(0, 2.6, 0)
        bb.LightInfluence = 0
        bb.ResetOnSpawn = false
        bb.Parent = espFolder
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13
        lbl.TextStrokeTransparency = 0.4
        lbl.Text = ""
        lbl.Parent = bb
        o.bb, o.label = bb, lbl
        ESP.objs[plr] = o
        return o
    end

    function ESP.update()
        local me = myPos()
        for plr, info in pairs(Roles.map) do
            if plr ~= LocalPlayer then
                local char = plr.Character
                local role = info.role
                local want = S.espPlayers and char ~= nil and not info.dead and rootOf(char) ~= nil
                if want and role == "Innocent" and not S.espInnocents then want = false end
                local o = ESP.objs[plr]
                if want then
                    if o and o.char ~= char then removeESP(plr); o = nil end
                    if not o then o = buildESP(plr, char) end
                    local color = ROLE_COLOR[role] or NO_ROLE
                    o.hl.Enabled = S.espChams
                    o.hl.FillColor = color
                    o.hl.OutlineColor = color
                    o.bb.Enabled = S.espNames or S.espDistance or S.espHealth
                    o.label.TextColor3 = color
                    local parts = {}
                    if S.espNames then parts[#parts + 1] = nameOf(plr) end
                    if role and role ~= "Innocent" then parts[#parts + 1] = "[" .. role .. "]" end
                    if S.espHealth then local h = humOf(char); if h then parts[#parts + 1] = math.floor(h.Health + 0.5) .. "hp" end end
                    if S.espDistance and me then local r = rootOf(char); if r then parts[#parts + 1] = math.floor((r.Position - me).Magnitude + 0.5) .. "m" end end
                    o.label.Text = table.concat(parts, " ")
                elseif o then
                    removeESP(plr)
                end
            end
        end
        for plr in pairs(ESP.objs) do
            if Roles.map[plr] == nil or plr.Parent == nil then removeESP(plr) end
        end
        -- guns
        for inst, o in pairs(ESP.gunObjs) do
            if not Guns.drops[inst] or not S.espGun or not inst.Parent then
                pcall(function() o.hl:Destroy() end); pcall(function() o.bb:Destroy() end)
                ESP.gunObjs[inst] = nil
            end
        end
        if S.espGun then
            for inst in pairs(Guns.drops) do
                if inst.Parent then
                    local o = ESP.gunObjs[inst]
                    if not o then
                        o = {}
                        o.hl = Instance.new("Highlight")
                        o.hl.Adornee = inst
                        o.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        o.hl.FillColor = Color3.fromRGB(255, 205, 60)
                        o.hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        o.hl.FillTransparency = 0.35
                        o.hl.Parent = espFolder
                        o.bb = Instance.new("BillboardGui")
                        o.bb.Adornee = inst
                        o.bb.AlwaysOnTop = true
                        o.bb.Size = UDim2.new(0, 140, 0, 26)
                        o.bb.StudsOffset = Vector3.new(0, 2, 0)
                        o.bb.ResetOnSpawn = false
                        o.bb.Parent = espFolder
                        o.label = Instance.new("TextLabel")
                        o.label.BackgroundTransparency = 1
                        o.label.Size = UDim2.new(1, 0, 1, 0)
                        o.label.Font = Enum.Font.GothamBold
                        o.label.TextSize = 14
                        o.label.TextColor3 = Color3.fromRGB(255, 215, 80)
                        o.label.TextStrokeTransparency = 0.3
                        o.label.Parent = o.bb
                        ESP.gunObjs[inst] = o
                    end
                    local p = posOfThing(inst)
                    o.label.Text = "GUN" .. ((p and me) and (" " .. math.floor((p - me).Magnitude + 0.5) .. "m") or "")
                end
            end
        end
    end

    -- tracers: Drawing lines from the bottom of the screen to players / the gun (only when the executor has Drawing)
    local function getLine(key)
        local l = ESP.tracers[key]
        if not l then
            l = Drawing.new("Line")
            l.Thickness = 1.5
            l.Transparency = 1
            l.Visible = false
            ESP.tracers[key] = l
        end
        return l
    end
    function ESP.drawTracers()
        if not Cap.drawing then return end
        local cam = camera()
        local used = {}
        if cam and (S.espTracers or S.gunTracer) then
            local vp = cam.ViewportSize
            local from = Vector2.new(vp.X / 2, vp.Y)
            local function line(key, pos, color)
                local v, on = cam:WorldToViewportPoint(pos)
                if not on then return end
                local l = getLine(key)
                l.From, l.To, l.Color, l.Visible = from, Vector2.new(v.X, v.Y), color, true
                used[key] = true
            end
            if S.espTracers and S.espPlayers then
                for plr, o in pairs(ESP.objs) do
                    local r = rootOf(o.char)
                    if r then line(plr, r.Position, o.label.TextColor3) end
                end
            end
            if S.gunTracer then
                for inst in pairs(Guns.drops) do
                    local p = inst.Parent and posOfThing(inst)
                    if p then line(inst, p, Color3.fromRGB(255, 215, 80)) end
                end
            end
        end
        for key, l in pairs(ESP.tracers) do
            if not used[key] then l.Visible = false end
        end
    end
    onCleanup(function()
        for _, l in pairs(ESP.tracers) do pcall(function() l:Remove() end) end
        ESP.tracers = {}
    end)

    ------------------------------------------------------------------------------------------ HUD: gun finder + FOV circle
    local hud = Instance.new("ScreenGui")
    hud.Name = "WraithsHubHud"
    hud.ResetOnSpawn = false
    hud.IgnoreGuiInset = true
    hud.DisplayOrder = 40
    hud.Parent = PARENT
    onCleanup(function() hud:Destroy() end)

    local gunBox = Instance.new("Frame")
    gunBox.AnchorPoint = Vector2.new(0.5, 0)
    gunBox.Position = UDim2.new(0.5, 0, 0, 52)
    gunBox.Size = UDim2.new(0, 300, 0, 40)
    gunBox.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    gunBox.BackgroundTransparency = 0.15
    gunBox.BorderSizePixel = 0
    gunBox.Visible = false
    gunBox.Parent = hud
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = gunBox
        local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(255, 205, 60); st.Thickness = 1.5; st.Parent = gunBox
    end
    local gunText = Instance.new("TextLabel")
    gunText.BackgroundTransparency = 1
    gunText.Position = UDim2.new(0, 46, 0, 0)
    gunText.Size = UDim2.new(1, -52, 1, 0)
    gunText.Font = Enum.Font.GothamBold
    gunText.TextSize = 14
    gunText.TextColor3 = Color3.fromRGB(255, 225, 120)
    gunText.TextXAlignment = Enum.TextXAlignment.Left
    gunText.Text = ""
    gunText.Parent = gunBox
    local compass = Instance.new("Frame")      -- little ring with a dot that points at the gun
    compass.Position = UDim2.new(0, 8, 0.5, -14)
    compass.Size = UDim2.new(0, 28, 0, 28)
    compass.BackgroundTransparency = 1
    compass.Parent = gunBox
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = compass
        local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(255, 205, 60); st.Thickness = 1.5; st.Parent = compass
    end
    local compassDot = Instance.new("Frame")
    compassDot.AnchorPoint = Vector2.new(0.5, 0.5)
    compassDot.Size = UDim2.new(0, 8, 0, 8)
    compassDot.BackgroundColor3 = Color3.fromRGB(255, 225, 120)
    compassDot.BorderSizePixel = 0
    compassDot.Position = UDim2.new(0.5, 0, 0.5, 0)
    compassDot.Parent = compass
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = compassDot end

    local fovRing = Instance.new("Frame")
    fovRing.AnchorPoint = Vector2.new(0.5, 0.5)
    fovRing.Position = UDim2.new(0.5, 0, 0.5, 0)
    fovRing.Size = UDim2.new(0, 400, 0, 400)
    fovRing.BackgroundTransparency = 1
    fovRing.Visible = false
    fovRing.Parent = hud
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = fovRing
        local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(255, 255, 255); st.Thickness = 1; st.Transparency = 0.4; st.Parent = fovRing
    end

    -- the aim reticle: a ring with spinning ticks that glides onto the predicted point of the current target
    local reticle = Instance.new("Frame")
    reticle.Name = "AimReticle"
    reticle.AnchorPoint = Vector2.new(0.5, 0.5)
    reticle.Size = UDim2.new(0, 56, 0, 56)
    reticle.BackgroundTransparency = 1
    reticle.BorderSizePixel = 0
    reticle.Visible = false
    reticle.Parent = hud
    local reticleSpin = Instance.new("Frame")
    reticleSpin.Name = "Spin"
    reticleSpin.Size = UDim2.new(1, 0, 1, 0)
    reticleSpin.BackgroundTransparency = 1
    reticleSpin.BorderSizePixel = 0
    reticleSpin.Parent = reticle
    local reticleRing = Instance.new("Frame")
    reticleRing.Name = "Ring"
    reticleRing.AnchorPoint = Vector2.new(0.5, 0.5)
    reticleRing.Position = UDim2.new(0.5, 0, 0.5, 0)
    reticleRing.Size = UDim2.new(0, 38, 0, 38)
    reticleRing.BackgroundTransparency = 1
    reticleRing.BorderSizePixel = 0
    reticleRing.Parent = reticle
    local reticleStroke = Instance.new("UIStroke")
    reticleStroke.Thickness = 2
    reticleStroke.Color = Color3.fromRGB(255, 255, 255)
    reticleStroke.Parent = reticleRing
    do
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = reticleRing
        for _, spec in ipairs({{0.5, 0, 2, 9}, {0.5, 1, 2, 9}, {0, 0.5, 9, 2}, {1, 0.5, 9, 2}}) do
            local tick = Instance.new("Frame")
            tick.Name = "Tick"
            tick.AnchorPoint = Vector2.new(0.5, 0.5)
            tick.Position = UDim2.new(spec[1], 0, spec[2], 0)
            tick.Size = UDim2.new(0, spec[3], 0, spec[4])
            tick.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            tick.BorderSizePixel = 0
            tick.Parent = reticleSpin
        end
        local dot = Instance.new("Frame")
        dot.Name = "Dot"
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Position = UDim2.new(0.5, 0, 0.5, 0)
        dot.Size = UDim2.new(0, 6, 0, 6)
        dot.BackgroundColor3 = Color3.fromRGB(255, 80, 90)
        dot.BorderSizePixel = 0
        dot.Parent = reticle
        local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot
    end
    local reticleTag = Instance.new("TextLabel")
    reticleTag.Name = "Tag"
    reticleTag.AnchorPoint = Vector2.new(0.5, 0)
    reticleTag.Position = UDim2.new(0.5, 0, 1, 2)
    reticleTag.Size = UDim2.new(0, 170, 0, 14)
    reticleTag.BackgroundTransparency = 1
    reticleTag.Font = Enum.Font.GothamBold
    reticleTag.TextSize = 11
    reticleTag.TextColor3 = Color3.fromRGB(255, 255, 255)
    reticleTag.TextStrokeTransparency = 0.35
    reticleTag.Text = ""
    reticleTag.Parent = reticle

    function Guns.updateHud()
        local inst, pos = nearestGun()
        if not (S.gunHud and pos) then gunBox.Visible = false; return end
        gunBox.Visible = true
        local me = myPos()
        local lx, lz = lookXZ()
        local dx, dz = me and (pos.X - me.X) or 0, me and (pos.Z - me.Z) or 0
        local _, ang = Logic.direction(dx, dz, lx, lz)
        local rad = math.rad(ang)
        compassDot.Position = UDim2.new(0.5, math.sin(rad) * 9, 0.5, -math.cos(rad) * 9)
        gunText.Text = (inst and "GUN  " or "Sheriff died here  ") .. describeFromMe(pos)
    end

    ------------------------------------------------------------------------------------------ targeting + prediction
    local Aim = {cache = {}, entry = nil}

    local function pickPartFor(char)
        if S.aimPart == "Head" then return headOf(char) end
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or rootOf(char)
    end

    local rayParams
    local function visibleFrom(origin, part, char)
        if not S.wallCheck then return true end
        if not rayParams then
            rayParams = RaycastParams.new()
            local ok = pcall(function() rayParams.FilterType = Enum.RaycastFilterType.Exclude end)
            if not ok then pcall(function() rayParams.FilterType = Enum.RaycastFilterType.Blacklist end) end
            rayParams.IgnoreWater = true
        end
        local filter, mine = {char}, myChar()
        if mine then filter[2] = mine end                       -- (a list with a nil hole would be rejected)
        rayParams.FilterDescendantsInstances = filter
        local hit = workspace:Raycast(origin, part.Position - origin, rayParams)
        return hit == nil
    end

    -- recent positions of every other player: a velocity that does not depend on the engine reporting one
    local Tracks = {}
    local function sampleTracks()
        local t = now()
        for plr, info in pairs(Roles.map) do
            local r = plr ~= LocalPlayer and not info.dead and plr.Character and rootOf(plr.Character)
            if r then
                local tr = Tracks[plr]
                if not tr then tr = {}; Tracks[plr] = tr end
                local sample = (#tr >= 12) and table.remove(tr, 1) or {}
                local p = r.Position
                sample.t, sample.x, sample.y, sample.z = t, p.X, p.Y, p.Z
                tr[#tr + 1] = sample
            else
                Tracks[plr] = nil
            end
        end
        for plr in pairs(Tracks) do if Roles.map[plr] == nil then Tracks[plr] = nil end end
    end

    local function velocityOf(plr, part, char)
        local root = rootOf(char) or part
        local pv = root.AssemblyLinearVelocity
        local hx, hy, hz = 0, 0, 0
        if Tracks[plr] then hx, hy, hz = Logic.estimateVelocity(Tracks[plr], 0.18) end
        return Logic.pickVelocity(pv.X, pv.Y, pv.Z, hx, hy, hz)
    end

    -- where to aim: the target's position when my shot arrives (ping + render delay + bullet flight), and the lead time used
    local function predictedPos(part, char, shooterPos, plr)
        local pos = part.Position
        if not S.predict then return pos, 0 end
        local vx, vy, vz = velocityOf(plr, part, char)
        local x, y, z, t = Logic.lead(pos.X, pos.Y, pos.Z, vx, vy, vz, shooterPos.X, shooterPos.Y, shooterPos.Z,
            {speed = S.bulletSpeed, latency = leadSeconds(), strength = S.predictStrength, maxLead = 0.8, vertical = 0.5})
        return Vector3.new(x, y, z), t
    end

    -- which mode is in effect for this weapon
    local function modeFor(weapon)
        local m = S.aimMode
        if m ~= "Auto (by my role)" then return m end
        if weapon == "Gun" then return "Murderer" end
        return "Closest to crosshair"
    end

    -- picks the best target for the weapon: returns plr, char, part, aimPosition, lead seconds
    function Aim.pick(weapon, modeOverride)
        local cam = camera()
        local me = myRoot()
        if not (cam and me) then return end
        local head = headOf(myChar())
        local origin = head and head.Position or me.Position
        local vp = cam.ViewportSize
        local cx, cy = vp.X / 2, vp.Y / 2
        local cands, byId = {}, {}
        for plr, info in pairs(Roles.map) do
            local char = plr.Character
            if plr ~= LocalPlayer and char and not info.dead and isAlive(char) then
                local part = pickPartFor(char)
                if part then
                    local v, on = cam:WorldToViewportPoint(part.Position)
                    local screen = on and math.sqrt((v.X - cx) ^ 2 + (v.Y - cy) ^ 2) or nil
                    local dist = (part.Position - origin).Magnitude
                    local c = {id = plr, dist = dist, screen = screen, role = info.role, alive = true,
                               visible = (dist <= S.maxDistance) and visibleFrom(origin, part, char) or false}
                    cands[#cands + 1] = c
                    byId[plr] = {part = part, char = char}
                end
            end
        end
        local id = Logic.pickTarget(cands, {mode = modeOverride or modeFor(weapon), fov = S.fov, maxDist = S.maxDistance, needVisible = S.wallCheck})
        if not id then return end
        local e = byId[id]
        local pp, lt = predictedPos(e.part, e.char, origin, id)
        return id, e.char, e.part, pp, lt
    end

    -- the data the namecall hook may read (it must not call methods): refreshed every frame
    local function refreshCache()
        local c = Aim.cache
        local head = headOf(myChar())
        c.origin = head and head.Position
        c.chars = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then c.chars[plr.Character] = true end
        end
        c.gun, c.knife = nil, nil
        if S.silentAim and c.origin then
            for _, w in ipairs({"Gun", "Knife"}) do
                local plr, char, part, pos = Aim.pick(w)
                if plr then
                    local parts = {}
                    for _, p in ipairs(char:GetChildren()) do if p:IsA("BasePart") then parts[p.Name] = p end end
                    local entry = {plr = plr, char = char, pos = pos, hum = humOf(char), parts = parts, root = rootOf(char)}
                    if w == "Gun" then c.gun = entry else c.knife = entry end
                end
            end
        end
    end

    ------------------------------------------------------------------------------------------ cursor / camera / clicks
    local function moveCursorTo(pos, alpha)
        local cam = camera()
        if not (cam and Cap.mouseRel) then return false end
        local v, on = cam:WorldToViewportPoint(pos)
        if not on then return false end
        local loc = UIS:GetMouseLocation()
        pcall(mousemoverel, (v.X - loc.X) * alpha, (v.Y - loc.Y) * alpha)
        return true
    end

    local function applyAim(pos, method, smooth)
        local cam = camera()
        if not cam then return end
        smooth = smooth or 0
        if method ~= "Mouse cursor" then
            local goal = CFrame.lookAt(cam.CFrame.Position, pos)
            cam.CFrame = smooth <= 0.01 and goal or cam.CFrame:Lerp(goal, 1 - smooth)
        end
        if method ~= "Camera" then moveCursorTo(pos, smooth <= 0.01 and 1 or (1 - smooth)) end
    end

    local function pressKey(name)
        if not VIM then return false end
        local ok, code = pcall(function() return Enum.KeyCode[name] end)
        if not (ok and code) then return false end
        pcall(function() VIM:SendKeyEvent(true, code, false, game) end)
        task.delay(0.05, function() pcall(function() VIM:SendKeyEvent(false, code, false, game) end) end)
        return true
    end

    ------------------------------------------------------------------------------------------ weapons: record / replay / silent aim
    local Shots = {templates = {}, pending = {}, counts = {Gun = 0, Knife = 0}, window = 0, windowWeapon = nil, skip = nil, last = {}, firing = {}}

    local function findTool(weapon)
        local char = myChar()
        if char then
            for _, t in ipairs(char:GetChildren()) do
                if t:IsA("Tool") and Logic.weaponOf(t.Name) == weapon then return t, true end
            end
        end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
            for _, t in ipairs(bp:GetChildren()) do
                if t:IsA("Tool") and Logic.weaponOf(t.Name) == weapon then return t, false end
            end
        end
    end
    local function equip(weapon)
        local tool, held = findTool(weapon)
        if tool and not held then
            local hum = humOf(myChar())
            if hum then hum:EquipTool(tool) end
        end
        return tool, held
    end

    -- property reads only: this runs inside the namecall hook (a method call there can corrupt the pending method name)
    local function weaponAbove(inst)
        local p = inst
        for _ = 1, 8 do
            if p == nil then return nil end
            if p.ClassName == "Tool" then return Logic.weaponOf(p.Name) end
            p = p.Parent
        end
    end

    local function describeArg(a)
        local t = typeof(a)
        if t == "Vector3" then return {kind = "vec", x = a.X, y = a.Y, z = a.Z} end
        if t == "CFrame" then local p = a.Position; return {kind = "cf", x = p.X, y = p.Y, z = p.Z} end
        if t == "Instance" then return {kind = "inst"} end
        return {kind = "other"}
    end

    -- a shot with its aim point(s) replaced. entry = {char, hum, parts, root}; origin = my head position
    local function retarget(tpl, args, aimPos, entry, origin)
        local out = {n = args.n}
        for i = 1, args.n do out[i] = args[i] end
        for i, role in pairs(tpl.plan) do
            local a = out[i]
            local isCF = typeof(a) == "CFrame"
            if role == "target" then
                out[i] = isCF and CFrame.new(aimPos) or aimPos
            elseif role == "origin" and origin then
                out[i] = isCF and CFrame.lookAt(origin, aimPos) or origin
            end
        end
        for i = 1, args.n do                                     -- hit part / humanoid / character arguments follow the new target
            local a = out[i]
            if typeof(a) == "Instance" and entry then
                local cls = a.ClassName
                if cls == "Humanoid" then
                    if entry.hum then out[i] = entry.hum end
                elseif cls == "Model" then
                    if Aim.cache.chars and Aim.cache.chars[a] then out[i] = entry.char end
                elseif Aim.cache.chars and a.Parent and Aim.cache.chars[a.Parent] then
                    out[i] = entry.parts[a.Name] or entry.root or a
                end
            end
        end
        return out
    end

    local function templateFits(tpl, self, args)
        return tpl and tpl.name == self.Name and tpl.args.n == args.n
    end

    -- the hook's whole job: remember what the game sends when I shoot / throw, and (silent aim) swap the aim point
    function Shots.onCall(self, method, args)
        local cls = self.ClassName
        if cls ~= "RemoteEvent" and cls ~= "RemoteFunction" and cls ~= "UnreliableRemoteEvent" then return nil end
        local weapon = weaponAbove(self)
        if not weapon and now() < Shots.window and Logic.looksLikeShotRemote(self.Name) then weapon = Shots.windowWeapon end
        if not weapon then return nil end
        local hasPos = false
        for i = 1, args.n do
            local t = typeof(args[i])
            if t == "Vector3" or t == "CFrame" then hasPos = true; break end
        end
        if not hasPos then return nil end
        local tpl = Shots.templates[weapon]
        local rewritten
        if S.silentAim and templateFits(tpl, self, args) then
            local entry = weapon == "Gun" and Aim.cache.gun or Aim.cache.knife
            if entry and Aim.cache.origin then rewritten = retarget(tpl, args, entry.pos, entry, Aim.cache.origin) end
        end
        if #Shots.pending < 20 then Shots.pending[#Shots.pending + 1] = {remote = self, method = method, args = args, weapon = weapon, t = now(), silent = rewritten ~= nil} end
        return rewritten
    end

    -- outside the hook: turn what was captured into a reusable template
    function Shots.process()
        local list = Shots.pending
        if #list == 0 then return end
        Shots.pending = {}
        local head = headOf(myChar())
        local hp = head and head.Position or Vector3.new(0, 0, 0)
        for _, p in ipairs(list) do
            local descs = {}
            for i = 1, p.args.n do descs[i] = describeArg(p.args[i]) end
            local underTool = false
            local path = {}
            local cur = p.remote
            for _ = 1, 8 do
                if cur == nil then break end
                if cur.ClassName == "Tool" then underTool = true; break end
                table.insert(path, 1, cur.Name)
                cur = cur.Parent
            end
            if not underTool then path = nil end
            if not p.silent then            -- (a rewritten call carries the aim point I chose, not the player's own shot)
                local plan = Logic.planShot(descs, hp.X, hp.Y, hp.Z, 25)
                Shots.templates[p.weapon] = {weapon = p.weapon, remote = p.remote, name = p.remote.Name, method = p.method, args = p.args, descs = descs,
                                             plan = plan, path = path, t = p.t}
                logLine(string.format("recorded %s shot via %s (%s, %d args)", p.weapon, p.remote:GetFullName(), p.method, p.args.n))
                if Shots.counts[p.weapon] == 0 then
                    notify("Learned your " .. p.weapon:lower() .. " shot", "I can fire it at targets for you now.", "good", 4)
                end
            end
            Shots.counts[p.weapon] = Shots.counts[p.weapon] + 1
        end
    end

    local function resolveRemote(tpl)
        if tpl.path then
            local tool = findTool(tpl.weapon)
            if not tool then return nil end
            local cur = tool
            for _, name in ipairs(tpl.path) do
                cur = cur:FindFirstChild(name)
                if not cur then return nil end
            end
            return cur
        end
        if tpl.remote and tpl.remote.Parent then return tpl.remote end
    end

    -- fire the recorded shot at a new aim point; returns ok, reason
    function Shots.replay(weapon, plr, char, part, aimPos)
        local tpl = Shots.templates[weapon]
        if not tpl then return false, "no recorded " .. weapon:lower() .. " shot yet (use it once by hand)" end
        local remote = resolveRemote(tpl)
        if not remote then return false, weapon:lower() .. " is not equipped" end
        local head = headOf(myChar())
        local parts = {}
        for _, p in ipairs(char:GetChildren()) do if p:IsA("BasePart") then parts[p.Name] = p end end
        refreshCache()
        local entry = {plr = plr, char = char, hum = humOf(char), parts = parts, root = rootOf(char)}
        local args = retarget(tpl, tpl.args, aimPos, entry, head and head.Position)
        Shots.skip = remote
        local method = tpl.method
        if method == "InvokeServer" then
            task.spawn(function()
                local ok, err = pcall(function() return remote:InvokeServer(table.unpack(args, 1, args.n)) end)
                if Shots.skip == remote then Shots.skip = nil end
                if not ok then report("replay", err) end
            end)
        else
            local ok, err = pcall(function() remote:FireServer(table.unpack(args, 1, args.n)) end)
            if Shots.skip == remote then Shots.skip = nil end
            if not ok then report("replay", err); return false, tostring(err) end
        end
        return true
    end

    local function pickFor(weapon)
        local plr, char, part, pos, lt = Aim.pick(weapon)
        if not plr and S.aimMode == "Auto (by my role)" and weapon == "Knife" then plr, char, part, pos, lt = Aim.pick(weapon, "Nearest") end
        return plr, char, part, pos, lt
    end

    function Shots.fire(weapon)           -- aim at the best target and use the weapon; returns ok, text
        local plr, char, part, pos, lead = pickFor(weapon)
        if not plr then return false, "no target in range / line of sight" end
        local tool, held = equip(weapon)
        if not tool then return false, "you do not have the " .. weapon:lower() end
        if not held then task.wait(0.06) end                     -- let the equip land
        task.wait()                                              -- one frame so the equip and the aim have taken effect
        if not Hub.Alive then return false, "unloaded" end
        local p2, c2, pt2, pos2, lead2 = pickFor(weapon)         -- the target kept moving: aim with fresh numbers
        if p2 == plr then char, part, pos, lead = c2, pt2, pos2, lead2 end
        local method = S.fireMethod
        local auto = method == "Auto"
        if auto then method = Shots.templates[weapon] and "Remote replay" or (weapon == "Knife" and "Throw key" or "Tool:Activate") end
        local aimMethod = S.aimMethod == "Mouse cursor" and "Mouse cursor" or "Both"
        local ok, why = true, nil
        local function viaTool()
            applyAim(pos, aimMethod, 0)
            task.wait()
            if weapon == "Knife" and (auto or method == "Throw key") and pressKey(S.throwKey) then return true end
            local t2 = findTool(weapon)
            if t2 then pcall(function() t2:Activate() end); return true end
            return false, "weapon not ready"
        end
        if method == "Remote replay" then
            ok, why = Shots.replay(weapon, plr, char, part, pos)
            if not ok and auto then ok, why = viaTool() end
        elseif method == "Throw key" then
            applyAim(pos, aimMethod, 0); task.wait()
            ok = pressKey(S.throwKey); why = not ok and "set the game's throw key in Combat" or nil
        elseif method == "Mouse click" and Cap.mouseClick then
            applyAim(pos, aimMethod, 0); task.wait()
            pcall(mouse1click)
        else
            ok, why = viaTool()
        end
        Shots.last[weapon] = now()
        if not ok then return false, why end
        local me = myPos()
        return true, string.format("%s  %dm  lead %d ms", nameOf(plr), me and math.floor((part.Position - me).Magnitude + 0.5) or 0, math.floor((lead or 0) * 1000 + 0.5))
    end

    -- the hook (installed once; harmless when the executor cannot do it)
    local function installHook()
        if not Cap.hook then return false, "this executor has no hookmetamethod / getnamecallmethod" end
        local old
        local function hooked(self, ...)
            local method = getnamecallmethod()
            if Hub.Alive and (method == "FireServer" or method == "InvokeServer") then
                if Shots.skip == self then
                    Shots.skip = nil
                else
                    local args = table.pack(...)
                    local ok, rewritten = pcall(Shots.onCall, self, method, args)
                    if Cap.setnamecall then pcall(setnamecallmethod, method) end
                    if ok and rewritten then return old(self, table.unpack(rewritten, 1, rewritten.n)) end
                end
            end
            return old(self, ...)
        end
        local ok, err = pcall(function()
            old = hookmetamethod(game, "__namecall", Cap.newcclosure and newcclosure(hooked) or hooked)
        end)
        if not ok then return false, tostring(err) end
        return true
    end
    local hookOk, hookWhy = installHook()
    if not hookOk then logLine("hook: " .. tostring(hookWhy)) end

    -- any input while a weapon is in hand opens a short "the next shot-looking remote is a shot" window
    track(UIS.InputBegan:Connect(guard("input window", function(input, processed)
        if processed then return end
        local t = input.UserInputType
        if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.Keyboard and t ~= Enum.UserInputType.MouseButton2 then return end
        local char = myChar()
        if not char then return end
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                local w = Logic.weaponOf(tool.Name)
                if w then Shots.window = now() + 0.6; Shots.windowWeapon = w; return end
            end
        end
    end)))

    ------------------------------------------------------------------------------------------ hitbox expander
    local Hitbox = {orig = {}}
    local function hitboxWanted(plr, info)
        if plr == LocalPlayer or info.dead then return false end
        local who = S.hitboxWho
        if who == "Everyone else" then return true end
        if who == "Murderer" then return info.role == "Murderer" or info.role == "Infected" end
        if who == "Sheriff" then return info.role == "Sheriff" or info.role == "Hero" end
        return false
    end
    function Hitbox.restore(part)
        local o = Hitbox.orig[part]
        if o then
            pcall(function() part.Size, part.Transparency, part.CanCollide, part.Massless = o[1], o[2], o[3], o[4] end)
            Hitbox.orig[part] = nil
        end
    end
    function Hitbox.restoreAll() for part in pairs(Hitbox.orig) do Hitbox.restore(part) end end
    function Hitbox.apply()
        local active = {}
        if S.hitbox then
            local size = Vector3.new(S.hitboxSize, S.hitboxSize, S.hitboxSize)
            for plr, info in pairs(Roles.map) do
                if hitboxWanted(plr, info) then
                    local root = rootOf(plr.Character)
                    if root then
                        active[root] = true
                        if not Hitbox.orig[root] then Hitbox.orig[root] = {root.Size, root.Transparency, root.CanCollide, root.Massless} end
                        root.Size = size
                        root.Transparency = S.hitboxAlpha
                        root.CanCollide = false
                        root.Massless = true
                    end
                end
            end
        end
        for part in pairs(Hitbox.orig) do
            if not active[part] then Hitbox.restore(part) end
        end
    end
    onCleanup(Hitbox.restoreAll)

    ------------------------------------------------------------------------------------------ player mods
    local Mods = {origWalk = nil, origJump = nil, origFov = nil}
    function Mods.apply()
        local hum = humOf(myChar())
        if hum then
            if S.walkOn then
                if Mods.origWalk == nil then Mods.origWalk = hum.WalkSpeed end
                if hum.WalkSpeed ~= S.walkSpeed then hum.WalkSpeed = S.walkSpeed end
            elseif Mods.origWalk ~= nil then hum.WalkSpeed = Mods.origWalk; Mods.origWalk = nil end
            if S.jumpOn then
                if Mods.origJump == nil then Mods.origJump = hum.JumpPower end
                hum.UseJumpPower = true
                if hum.JumpPower ~= S.jumpPower then hum.JumpPower = S.jumpPower end
            elseif Mods.origJump ~= nil then hum.JumpPower = Mods.origJump; Mods.origJump = nil end
        end
        local cam = camera()
        if cam then
            if S.fovOn then
                if Mods.origFov == nil then Mods.origFov = cam.FieldOfView end
                cam.FieldOfView = S.fovValue
            elseif Mods.origFov ~= nil then cam.FieldOfView = Mods.origFov; Mods.origFov = nil end
        end
    end
    onCleanup(function()
        local hum = humOf(myChar())
        if hum then
            if Mods.origWalk then hum.WalkSpeed = Mods.origWalk end
            if Mods.origJump then hum.JumpPower = Mods.origJump end
        end
        local cam = camera()
        if cam and Mods.origFov then cam.FieldOfView = Mods.origFov end
    end)
    track(UIS.JumpRequest:Connect(guard("infinite jump", function()
        if S.infJump then
            local hum = humOf(myChar())
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)))
    track(RunService.Stepped:Connect(guard("noclip", function()
        if not S.noclip then return end
        local char = myChar()
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end)))
    if VirtualUser then
        track(LocalPlayer.Idled:Connect(guard("anti afk", function()
            if S.antiAfk then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(0, 0)) end
        end)))
    end

    ------------------------------------------------------------------------------------------ actions
    local Floats = {}
    local autoPos                                                         -- (defined with the floating buttons below)
    -- Perfect shoot / throw: pick the best target, aim ahead of it by my ping, equip the weapon and use it. Runs in its own thread; the floating
    -- button (if any) flashes green when it fired and red when it could not.
    local function perfectAction(weapon)
        local float = weapon == "Gun" and Floats.shoot or Floats.throw
        local function fail(title, text)
            notify(title, text, "warn", 2)
            if float then float:Flash(false) end
        end
        if Shots.firing[weapon] then return "async" end
        if not findTool(weapon) then
            if weapon == "Gun" then fail("No gun", "You are not holding the gun.") else fail("No knife", "You are not the murderer.") end
            return "async"
        end
        Shots.firing[weapon] = true
        task.spawn(function()
            local okc, ok, why = pcall(Shots.fire, weapon)
            Shots.firing[weapon] = false
            if not okc then report("perfect " .. weapon, ok); ok, why = false, "error - see the Debug tab" end
            if ok then
                notify(weapon == "Gun" and "Shot fired" or "Knife thrown", tostring(why), "good", 2)
                if float then float:Flash(true); float:Cooldown(weapon == "Gun" and S.shootGap or S.throwGap) end
            else
                notify(weapon == "Gun" and "Could not shoot" or "Could not throw", tostring(why), "warn", 3)
                if float then float:Flash(false) end
            end
        end)
        return "async"
    end
    local function perfectShoot() return perfectAction("Gun") end
    local function perfectThrow() return perfectAction("Knife") end
    local function grabGun()
        local inst, pos = nearestGun()
        local root = myRoot()
        if not (pos and root) then notify("No gun on the map", nil, "warn", 3); return false end
        local back = root.CFrame
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        task.delay(0.45, function()
            local r = myRoot()
            if r then r.CFrame = back end
            notify("Back where you were", "Check your hotbar for the gun.", "info", 3)
        end)
        return true
    end

    ------------------------------------------------------------------------------------------ main loops
    local acc = {slow = 0, mid = 0, poll = 0, auto = 0, ping = 0, dim = 0}
    local announced = {}
    local alertAt = 0

    local function announceRoles()
        if not Roles.active then
            if now() - Roles.lastActive > 6 then announced = {}; Guns.fallback = nil end
            return
        end
        if not S.notifyRoles then return end
        for _, role in ipairs({"Murderer", "Sheriff"}) do
            local plr = role == "Murderer" and Roles.murderer() or Roles.sheriff()
            if plr and announced[role] ~= plr then
                announced[role] = plr
                local r = rootOf(plr.Character)
                local where = r and plr ~= LocalPlayer and describeFromMe(r.Position) or (plr == LocalPlayer and "that is you" or "")
                notify(role .. ": " .. nameOf(plr), where, role == "Murderer" and "bad" or "info", 5)
            end
        end
    end

    local function murdererAlert()
        if not S.murdererAlert or Roles.mine == "Murderer" or not Roles.active then return end
        local m = Roles.murderer()
        if not m or m == LocalPlayer or now() - alertAt < 8 then return end
        local r, me = rootOf(m.Character), myPos()
        if r and me and (r.Position - me).Magnitude <= S.alertDistance then
            alertAt = now()
            notify("Murderer nearby!", nameOf(m) .. " - " .. describeFromMe(r.Position), "bad", 3)
        end
    end

    local function trackSheriffDeath()
        local sh = Roles.sheriff()
        if sh and sh.Character then
            local r = rootOf(sh.Character)
            if r and isAlive(sh.Character) then Guns.lastSheriff = {plr = sh, pos = r.Position, t = now()}; return end
        end
        local ls = Guns.lastSheriff
        if not ls then return end
        if not Roles.active then Guns.lastSheriff = nil; return end        -- the round is over
        if not ls.deadAt then ls.deadAt = now(); Guns.looseUntil = now() + 6 end
        if now() - ls.deadAt > 1.2 then
            if not Guns.fallback and next(Guns.drops) == nil then
                Guns.fallback = {pos = ls.pos, t = now()}
                if S.notifyGun then notify("Sheriff down", "the gun should be near: " .. describeFromMe(ls.pos), "warn", 6) end
            end
            Guns.lastSheriff = nil
        end
    end

    local function autoActions()
        local role = Roles.mine
        if S.autoShoot and (role == "Sheriff" or role == "Hero") and not Shots.busy and now() - (Shots.last.Gun or 0) >= S.shootGap then
            local plr = Aim.pick("Gun", "Murderer")
            if plr then
                Shots.busy = true
                task.spawn(function() pcall(Shots.fire, "Gun"); Shots.busy = false end)
            end
        end
        if role == "Murderer" then
            if S.autoThrow and not Shots.busy and now() - (Shots.last.Knife or 0) >= S.throwGap then
                local plr = Aim.pick("Knife")
                if plr then Shots.busy = true; perfectThrow(); task.delay(0.5, function() Shots.busy = false end) end
            end
            if S.slashAura and now() - (Shots.last.Slash or 0) >= 0.45 then
                local me = myPos()
                local tool = findTool("Knife")
                if me and tool then
                    for plr, info in pairs(Roles.map) do
                        local r = plr ~= LocalPlayer and not info.dead and plr.Character and rootOf(plr.Character)
                        if r and (r.Position - me).Magnitude <= S.slashRange then
                            Shots.last.Slash = now()
                            task.spawn(function()
                                local t2 = equip("Knife")
                                task.wait()
                                applyAim(r.Position, "Camera", 0)
                                if t2 then pcall(function() t2:Activate() end) end
                            end)
                            break
                        end
                    end
                end
            end
        end
    end

    local function aimHeld()
        return S.aimLock and Win and Win.Flags.aimKey and Win.Flags.aimKey.Down
    end

    -- the target the aim assist / reticle follow right now
    local function currentPick()
        local weapon = Roles.mine == "Murderer" and "Knife" or "Gun"
        local override
        if S.aimMode == "Auto (by my role)" then override = Roles.mine == "Murderer" and "Closest to crosshair" or "Murderer" end
        return Aim.pick(weapon, override)
    end

    -- the moving aim: the reticle glides (exponential smoothing) onto where the shot will land, with the ping lead in its label
    local Ret = {x = nil, y = nil, nextPick = 0, plr = nil, pos = nil, lead = 0, spin = 0}
    local function updateReticle(dt)
        local mode = S.reticle
        local cam = camera()
        local function hide() reticle.Visible = false; Ret.x = nil end
        if mode == "Off" or not cam or not Roles.active then return hide() end
        if mode ~= "Always" then
            local holding = false
            local char = myChar()
            if char then
                for _, tool in ipairs(char:GetChildren()) do
                    if tool:IsA("Tool") and Logic.weaponOf(tool.Name) then holding = true end
                end
            end
            if not holding and not aimHeld() then return hide() end
        end
        local t = now()
        if t >= Ret.nextPick then
            Ret.nextPick = t + 0.05
            local plr, _, _, pos, lead = currentPick()
            Ret.plr, Ret.pos, Ret.lead = plr, pos, lead
        end
        if not Ret.plr then return hide() end
        local v, on = cam:WorldToViewportPoint(Ret.pos)
        if not on then return hide() end
        local k = 1 - math.exp(-dt * 16)
        if Ret.x == nil then Ret.x, Ret.y = v.X, v.Y else Ret.x, Ret.y = Ret.x + (v.X - Ret.x) * k, Ret.y + (v.Y - Ret.y) * k end
        reticle.Position = UDim2.new(0, Ret.x, 0, Ret.y)
        Ret.spin = (Ret.spin + dt * 110) % 360
        reticleSpin.Rotation = Ret.spin
        reticleStroke.Color = aimHeld() and Color3.fromRGB(90, 235, 130) or Color3.fromRGB(255, 255, 255)
        local me = myPos()
        reticleTag.Text = string.format("%s  %dm  lead %dms", nameOf(Ret.plr), me and math.floor((Ret.pos - me).Magnitude + 0.5) or 0, math.floor((Ret.lead or 0) * 1000 + 0.5))
        reticle.Visible = true
    end

    track(RunService.Heartbeat:Connect(guard("heartbeat", function(dt)
        if not Hub.Alive then return end
        acc.slow, acc.mid, acc.poll, acc.auto = acc.slow + dt, acc.mid + dt, acc.poll + dt, acc.auto + dt
        acc.ping, acc.dim = acc.ping + dt, acc.dim + dt
        Shots.process()
        sampleTracks()
        if acc.ping >= 0.25 then acc.ping = 0; samplePing() end
        if acc.dim >= 0.5 then
            acc.dim = 0
            if Floats.shoot then Floats.shoot:SetDim(findTool("Gun") == nil) end
            if Floats.throw then Floats.throw:SetDim(findTool("Knife") == nil) end
            if Floats.grab then Floats.grab:SetDim(next(Guns.drops) == nil and Guns.fallback == nil) end
        end
        if acc.mid >= 0.4 then
            acc.mid = 0
            Roles.scan()
            announceRoles()
            murdererAlert()
            trackSheriffDeath()
            Hitbox.apply()
        end
        if acc.slow >= 0.12 then
            acc.slow = 0
            ESP.update()
            Guns.updateHud()
            fovRing.Visible = S.showFov
            fovRing.Size = UDim2.new(0, S.fov * 2, 0, S.fov * 2)
            Mods.apply()
        end
        if acc.poll >= 3 then acc.poll = 0; pollData() end
        if acc.auto >= 0.1 then acc.auto = 0; autoActions() end
        refreshCache()
    end)))

    pcall(function()
        RunService:BindToRenderStep("WraithsHubAim", Enum.RenderPriority.Camera.Value + 1, guard("aim lock", function(dt)
            ESP.drawTracers()
            if aimHeld() then
                local plr, _, _, pos = currentPick()
                if plr then applyAim(pos, S.aimMethod, S.aimSmooth) end
            end
            updateReticle(dt or 1 / 60)
        end))
    end)
    onCleanup(function() pcall(function() RunService:UnbindFromRenderStep("WraithsHubAim") end) end)

    ------------------------------------------------------------------------------------------ events
    track(workspace.DescendantAdded:Connect(guard("gun drop added", function(inst)
        Guns.add(inst, now() < (Guns.looseUntil or 0))
    end)))
    track(workspace.DescendantRemoving:Connect(guard("gun drop removed", function(inst) Guns.remove(inst) end)))
    track(Players.PlayerRemoving:Connect(guard("player left", function(plr) removeESP(plr); Roles.data[plr] = nil end)))
    connectDataRemotes()
    scanWorkspaceForGuns()

    ------------------------------------------------------------------------------------------ the window
    local function keyCodeFor(name)
        local ok, code = pcall(function() return Enum.KeyCode[name] end)
        return ok and code or Enum.KeyCode.RightShift
    end
    Win = UILib.new{Title = "Wraith's Hub", Subtitle = "Murder Mystery 2", Group = "Wraith's Hub", Parent = PARENT, GuiName = "WraithsHubWindow", Theme = S.theme,
        WaveMode = S.waves, ToggleKey = keyCodeFor(S.uiKey), OnError = report}
    Hub.Win = Win
    Win:SetAvatar(LocalPlayer.UserId)
    do
        local summary = {}
        if not Cap.hook then summary[#summary + 1] = "no hook (silent aim / shot recording off)" end
        if not Cap.drawing then summary[#summary + 1] = "no Drawing (no tracers)" end
        if not Cap.mouseRel then summary[#summary + 1] = "no mousemoverel (cursor aim off)" end
        if game.PlaceId ~= 142823291 then summary[#summary + 1] = "this does not look like Murder Mystery 2" end
        notify("Wraith's Hub loaded", #summary > 0 and table.concat(summary, "; ") or "All features available.", #summary > 0 and "warn" or "good", 5)
    end
    for _, q in ipairs(queued) do notify(q[1], q[2], q[3], q[4]) end
    queued = {}

    local function tog(tab, flag, title, desc, after)
        return tab:Toggle{Title = title, Desc = desc, Default = S[flag], Flag = flag, NoInitialCallback = true, Callback = function(v)
            S[flag] = v
            if after then after(v) end
        end}
    end
    local function sld(tab, flag, title, min, max, step, suffix, after)
        return tab:Slider{Title = title, Min = min, Max = max, Step = step, Suffix = suffix, Default = S[flag], Flag = flag, Callback = function(v)
            S[flag] = v
            if after then after(v) end
        end}
    end
    local function drop(tab, flag, title, values, after)
        return tab:Dropdown{Title = title, Values = values, Default = S[flag], Flag = flag, Callback = function(v)
            S[flag] = v
            if after then after(v) end
        end}
    end
    local function key(tab, flag, title, desc, press, after)
        return tab:Keybind{Title = title, Desc = desc, Default = S[flag], Flag = flag, Callback = press, Changed = function(v)
            S[flag] = v
            if after then after(v) end
        end}
    end

    local main = Win:Tab("Main", "grid")
    local esp = Win:Tab("ESP", "eye")
    local combat = Win:Tab("Combat", "crosshair")
    local btns = Win:Tab("Buttons", "bolt")
    local player = Win:Tab("Player", "user")
    local settings = Win:Tab("Settings", "gear")
    local dbg = Win:Tab("Debug", "terminal")

    -- Main
    main:Section("Live round info")
    local roundLabel = main:Label("Waiting for a round...")
    local gunLabel = main:Label("Gun: not dropped")
    main:Section("Notifications")
    tog(main, "notifyRoles", "Announce murderer / sheriff", "A toast the moment a role becomes known (needs the role data or a visible weapon).")
    tog(main, "murdererAlert", "Murderer proximity alert", "Warns you when the murderer gets close.")
    sld(main, "alertDistance", "Alert distance", 10, 120, 5, " studs")
    tog(main, "notifyGun", "Gun drop notification", "Says where the gun is the moment the sheriff goes down.")
    tog(main, "gunHud", "Gun finder HUD", "Top-centre bar with distance, direction and a little compass.")
    main:Section("Quick actions")
    main:Label("First time: take your gun / knife out and fire or throw it ONCE by hand. I watch what the game sends (see the Debug tab), then Perfect shoot / throw, auto shoot and silent aim use the same call with a better aim point.")
    main:Button{Title = "Perfect shoot", Desc = "Sheriff / hero: aims ahead of the murderer by your ping and fires the gun.", Label = "Fire", Callback = perfectShoot}
    main:Button{Title = "Perfect throw", Desc = "Murderer: aims ahead of the best target by your ping and throws the knife.", Label = "Throw", Callback = perfectThrow}
    main:Button{Title = "Grab the gun", Desc = "Teleports to the dropped gun for a moment and brings you straight back.", Label = "Go", Callback = function() grabGun() end}
    main:Section("Data")
    tog(main, "useRemoteData", "Read roles from the game's data remote", "Lets me see roles even when nobody holds a weapon. Off = only visible weapons.")

    -- ESP
    esp:Section("Players")
    tog(esp, "espPlayers", "Player ESP", "Colour by role: red murderer, blue sheriff, gold hero, green innocent.")
    tog(esp, "espChams", "Chams (see-through glow)")
    tog(esp, "espNames", "Names")
    tog(esp, "espDistance", "Distance")
    tog(esp, "espHealth", "Health")
    tog(esp, "espInnocents", "Show innocents", "Off = only murderer, sheriff and hero.")
    tog(esp, "espTracers", "Tracers", Cap.drawing and "Lines from the bottom of your screen." or "Your executor has no Drawing library: tracers are unavailable.")
    esp:Section("Gun")
    tog(esp, "espGun", "Gun ESP", "Highlight + label on the dropped gun, visible through walls.")
    tog(esp, "gunTracer", "Gun tracer", Cap.drawing and "A line pointing at the gun." or "Needs the Drawing library (not available here).")

    -- Combat
    combat:Section("Targeting")
    drop(combat, "aimMode", "Aim target", {"Auto (by my role)", "Murderer", "Sheriff", "Sheriff first", "Closest to crosshair", "Nearest"})
    drop(combat, "aimPart", "Aim at", {"Head", "Torso"})
    tog(combat, "wallCheck", "Wall check", "Only targets with a clear line of sight.")
    sld(combat, "maxDistance", "Max distance", 30, 600, 10, " studs")
    sld(combat, "fov", "Crosshair FOV", 40, 600, 10, " px")
    tog(combat, "showFov", "Show FOV circle")
    combat:Section("Prediction")
    tog(combat, "predict", "Lead moving targets", "Aims where they will be, using their velocity.")
    sld(combat, "bulletSpeed", "Bullet speed (0 = instant)", 0, 600, 10, " sps")
    sld(combat, "predictStrength", "Lead strength", 0, 2, 0.1, "x")
    combat:Section("Ping and lead")
    local pingLabel = combat:Label("Measuring your ping...")
    tog(combat, "addPing", "Lead by my ping", "Aims ahead of moving players by your measured ping (smoothed, lag spikes ignored).")
    sld(combat, "pingComp", "Ping compensation", 0, 1.5, 0.05, "x")
    sld(combat, "interpMs", "Render delay (others)", 0, 200, 5, " ms")
    sld(combat, "extraLead", "Extra lead (trim)", -100, 200, 5, " ms")
    drop(combat, "reticle", "Aim reticle", {"Weapon in hand", "Always", "Off"})
    combat:Section("Aim assist (hold the key)")
    tog(combat, "aimLock", "Aim assist", "While the key is held, your camera / cursor follows the target.")
    key(combat, "aimKey", "Aim key (hold)", "Right-click is the camera drag, so use a key.")
    drop(combat, "aimMethod", "Aim method", {"Camera", "Mouse cursor", "Both"})
    sld(combat, "aimSmooth", "Smoothness", 0, 0.9, 0.05, "")
    combat:Section("Gun - sheriff / hero")
    key(combat, "shootKey", "Perfect shoot key", "One press: aim, predict and fire.", perfectShoot)
    tog(combat, "autoShoot", "Auto shoot", "Fires as soon as the murderer is in range and visible.")
    sld(combat, "shootGap", "Time between shots", 0.5, 6, 0.1, " s")
    tog(combat, "silentAim", "Silent aim (your own shots)", Cap.hook and "Your normal shots fly at the predicted target. Needs one recorded shot." or "Needs hookmetamethod - not available here.")
    drop(combat, "fireMethod", "How to fire", {"Auto", "Remote replay", "Tool:Activate", "Mouse click"})
    combat:Section("Knife - murderer")
    key(combat, "throwAtKey", "Perfect throw key", "One press: aim, predict and throw.", perfectThrow)
    key(combat, "throwKey", "The game's throw key", "Used when no throw has been recorded yet.")
    tog(combat, "autoThrow", "Auto throw", "Throws at anyone in range and in sight.")
    sld(combat, "throwGap", "Time between throws", 0.5, 8, 0.1, " s")
    tog(combat, "slashAura", "Slash aura", "Swings when someone is close.")
    sld(combat, "slashRange", "Slash range", 4, 20, 1, " studs")
    combat:Section("Hitbox expander (experimental)")
    tog(combat, "hitbox", "Expand hitboxes", "Grows their root part on YOUR screen only. Works only where the game trusts what your client sees.", function() Hitbox.apply() end)
    sld(combat, "hitboxSize", "Size", 2, 30, 1, " studs")
    sld(combat, "hitboxAlpha", "Transparency", 0.2, 1, 0.1, "")
    drop(combat, "hitboxWho", "Who", {"Murderer", "Sheriff", "Everyone else"})

    -- Buttons: the floating on-screen buttons and their look
    btns:Section("On-screen buttons")
    btns:Label("Tap = fire. Hold and drag = move (unless locked). Dimmed = you do not have that weapon.")
    tog(btns, "btnShoot", "Show Perfect Shoot", "A SHOOT button: aims ahead of the murderer by your ping and fires.", function(v) if Floats.shoot then Floats.shoot:SetVisible(v) end end)
    tog(btns, "btnThrow", "Show Perfect Throw", "A THROW button: aims ahead of the best target by your ping and throws.", function(v) if Floats.throw then Floats.throw:SetVisible(v) end end)
    tog(btns, "btnGrab", "Show Grab Gun", "A GRAB GUN button: hops onto the dropped gun and back.", function(v) if Floats.grab then Floats.grab:SetVisible(v) end end)
    tog(btns, "btnSpeed", "Show Speed toggle", "A SPEED ON / OFF button for walk speed.", function(v) if Floats.speed then Floats.speed:SetVisible(v) end end)
    tog(btns, "btnJump", "Show Jump toggle", "A JUMP ON / OFF button for jump power.", function(v) if Floats.jump then Floats.jump:SetVisible(v) end end)
    sld(btns, "btnSize", "Button size", 56, 120, 2, " px", function(v) for _, f in pairs(Floats) do f:SetSize(v) end end)
    tog(btns, "btnLock", "Lock button positions", "Stops a tap that wobbles from dragging the button.", function(v) for _, f in pairs(Floats) do f:SetLocked(v) end end)
    btns:Button{Title = "Reset button positions", Label = "Reset", Callback = function()
        for id, f in pairs(Floats) do
            local fx, fy = autoPos(id)
            S[id .. "X"], S[id .. "Y"] = -1, -1
            f:SetPos(fx, fy)
        end
    end}
    btns:Section("Water waves")
    drop(btns, "waves", "Button waves", {"High", "Low", "Off"}, function(v) Win:SetWaveMode(v) end)
    btns:Label("Every button wears an animated grey-white wave texture. Low uses one layer at half speed; Off is the lightest on weak phones.")

    -- Player
    player:Section("Movement")
    tog(player, "walkOn", "Walk speed", nil, function(v) if Floats.speed then Floats.speed:SetState(v) end end)
    sld(player, "walkSpeed", "Speed", 16, 80, 1, "")
    tog(player, "jumpOn", "Jump power", nil, function(v) if Floats.jump then Floats.jump:SetState(v) end end)
    sld(player, "jumpPower", "Power", 50, 200, 5, "")
    tog(player, "infJump", "Infinite jump")
    tog(player, "noclip", "Noclip")
    player:Section("Camera")
    tog(player, "fovOn", "Field of view")
    sld(player, "fovValue", "FOV", 40, 120, 1, "")

    -- session tools live on the Player tab
    player:Section("Session")
    local misc = player
    tog(misc, "antiAfk", "Anti AFK")
    misc:Button{Title = "Rejoin this server", Label = "Go", Callback = function()
        if TeleportService then pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end) end
    end}
    misc:Button{Title = "Hop to another server", Label = "Go", Callback = function()
        task.spawn(function()
            local ok, err = pcall(function()
                local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
                local raw
                if game.HttpGet then raw = game:HttpGet(url) elseif request then raw = request({Url = url, Method = "GET"}).Body end
                local data = HttpService:JSONDecode(raw)
                for _, s in ipairs(data.data or {}) do
                    if s.id ~= game.JobId and (s.playing or 0) < (s.maxPlayers or 0) then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                        return
                    end
                end
                notify("No other server found", nil, "warn")
            end)
            if not ok then notify("Server hop failed", tostring(err), "bad", 5) end
        end)
    end}

    -- Settings
    settings:Section("Look")
    drop(settings, "theme", "Theme", UILib.ThemeNames, function(v) Win:SetTheme(v) end)
    key(settings, "uiKey", "Show / hide menu", "Also tap the pill at the top of the screen.", nil, function(v) Win.ToggleKey = keyCodeFor(v) end)
    settings:Section("Config")
    settings:Label("Nothing is saved unless you press Save config.")
    settings:Button{Title = "Save config", Label = "Save", Callback = function()
        if not Cap.files then notify("Cannot save", "This executor has no writefile.", "bad"); return end
        local state = Win:GetState()
        state.theme = Win:GetTheme()
        for _, k in ipairs({"shootX", "shootY", "throwX", "throwY", "grabX", "grabY", "speedX", "speedY", "jumpX", "jumpY"}) do state[k] = S[k] end
        local ok, err = pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(state)) end)
        notify(ok and "Config saved" or "Save failed", ok and CONFIG_FILE or tostring(err), ok and "good" or "bad")
    end}
    settings:Button{Title = "Load config", Label = "Load", Callback = function()
        if not Cap.files then return end
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
        if not ok then notify("Nothing to load", nil, "warn"); return end
        local merged = Logic.mergeFlags(DEFAULTS, data)
        Win:SetState(merged, false)
        if merged.theme ~= Win:GetTheme() then Win:SetTheme(merged.theme) end
        for _, id in ipairs({"shoot", "throw", "grab", "speed", "jump"}) do
            S[id .. "X"], S[id .. "Y"] = merged[id .. "X"], merged[id .. "Y"]
            if Floats[id] then
                local fx, fy = S[id .. "X"], S[id .. "Y"]
                if fx < 0 or fy < 0 then fx, fy = autoPos(id) end
                Floats[id]:SetPos(fx, fy)
            end
        end
        notify("Config loaded", nil, "good", 2)
    end}
    settings:Button{Title = "Delete saved config", Label = "Delete", Callback = function()
        if Cap.files and delfile then pcall(delfile, CONFIG_FILE) end
        notify("Saved config deleted", nil, "info", 2)
    end}
    settings:Section("Script")
    settings:Button{Title = "Unload the hub", Desc = "Removes the menu, ESP and every hook effect.", Label = "Unload", Callback = function() Hub.Destroy() end}

    -- Debug
    dbg:Section("Executor support")
    local function yes(b) return b and "yes" or "NO" end
    dbg:Label(string.format("hook %s | setnamecall %s | drawing %s | mousemoverel %s | mouse1click %s | files %s | clipboard %s | gethui %s",
        yes(Cap.hook), yes(Cap.setnamecall), yes(Cap.drawing), yes(Cap.mouseRel), yes(Cap.mouseClick), yes(Cap.files), yes(Cap.clipboard), yes(Cap.gethui)))
    dbg:Section("Recorded shots")
    local shotLabel = dbg:Label("Nothing recorded yet. Shoot / throw once by hand with the weapon equipped.")
    dbg:Button{Title = "Forget recorded shots", Label = "Clear", Callback = function() Shots.templates = {}; Shots.counts = {Gun = 0, Knife = 0}; notify("Recorded shots cleared", nil, "info", 2) end}
    dbg:Section("Log")
    local logLabel = dbg:Label("(empty)")
    local function diagnostics()
        local lines = {"Wraith's Hub diagnostics", "place " .. tostring(game.PlaceId), string.format("role %s | murderer %s | sheriff %s", tostring(Roles.mine),
            Roles.murderer() and Roles.murderer().Name or "?", Roles.sheriff() and Roles.sheriff().Name or "?")}
        for _, w in ipairs({"Gun", "Knife"}) do
            local t = Shots.templates[w]
            if t then
                local kinds = {}
                for i, d in ipairs(t.descs) do kinds[i] = d.kind .. (t.plan[i] and ("=" .. t.plan[i]) or "") end
                lines[#lines + 1] = string.format("%s: %s %s (%s) args [%s] x%d", w, t.method, t.remote:GetFullName(), t.path and "tool remote" or "global remote", table.concat(kinds, ","), Shots.counts[w])
            end
        end
        for _, l in ipairs(LOG) do lines[#lines + 1] = l end
        return table.concat(lines, "\n")
    end
    dbg:Button{Title = "Copy diagnostics", Desc = "Paste it to whoever is helping you.", Label = "Copy", Callback = function()
        if Cap.clipboard then pcall(setclipboard, diagnostics()); notify("Copied", nil, "good", 2) else notify("No clipboard", "See the Log below instead.", "warn") end
    end}

    -- the floating buttons (Perfect shoot / Perfect throw / Grab gun / Speed / Jump)
    local AUTO_SLOT = {shoot = {1, 1}, throw = {1, 2}, grab = {1, 3}, speed = {2, 1}, jump = {2, 2}}      -- {column from the right edge, row from the top}
    autoPos = function(id)
        local vp = camera() and camera().ViewportSize or Vector2.new(1280, 720)
        local size = S.btnSize
        local col, row = AUTO_SLOT[id][1], AUTO_SLOT[id][2]
        local x = vp.X - 12 - col * size - (col - 1) * 8
        local y = vp.Y * 0.18 + (row - 1) * (size + 10)
        return Logic.clamp(x, 0, math.max(0, vp.X - size)) / vp.X, Logic.clamp(y, 0, math.max(0, vp.Y - size)) / vp.Y
    end
    for _, d in ipairs({
        {id = "shoot", title = "SHOOT", icon = "crosshair", accent = {255, 255, 255}, flag = "btnShoot", weapon = "Gun"},
        {id = "throw", title = "THROW", icon = "knife", accent = {236, 52, 64}, flag = "btnThrow", weapon = "Knife"},
        {id = "grab", title = "GRAB GUN", icon = "pistol", accent = {250, 190, 60}, flag = "btnGrab"},
        {id = "speed", title = "SPEED", labelOn = "SPEED ON", labelOff = "SPEED OFF", icon = "bolt", accent = {64, 214, 190}, flag = "btnSpeed", state = "walkOn"},
        {id = "jump", title = "JUMP", labelOn = "JUMP ON", labelOff = "JUMP OFF", icon = "chevron_up", accent = {96, 170, 255}, flag = "btnJump", state = "jumpOn"},
    }) do
        local fx, fy = S[d.id .. "X"], S[d.id .. "Y"]
        if fx < 0 or fy < 0 then fx, fy = autoPos(d.id) end
        Floats[d.id] = Win:Floating{Id = d.id, Title = d.title, Icon = d.icon, Accent = d.accent, Size = S.btnSize, Pos = {fx, fy},
            Visible = S[d.flag], Locked = S.btnLock, Toggle = d.state ~= nil, LabelOn = d.labelOn, LabelOff = d.labelOff, State = d.state and S[d.state] or false,
            OnPress = function()
                if d.state then                                           -- a toggle: flip the matching switch in the Player tab
                    local el = Win.Flags[d.state]
                    if el then el:Set(not el.Value) end
                    return true
                end
                if d.weapon then return perfectAction(d.weapon) end
                return grabGun()
            end,
            OnMoved = function(fx, fy) S[d.id .. "X"], S[d.id .. "Y"] = fx, fy end}
    end

    -- live labels
    local lastLabels = 0
    track(RunService.Heartbeat:Connect(guard("labels", function()
        if now() - lastLabels < 0.6 or not Win.Main.Visible then return end
        lastLabels = now()
        local m, s = Roles.murderer(), Roles.sheriff()
        roundLabel:Set(string.format("You: %s\nMurderer: %s\nSheriff / hero: %s", Roles.mine or (Roles.active and "spectating" or "lobby"), m and nameOf(m) or "unknown", s and nameOf(s) or "unknown"))
        local _, pos = nearestGun()
        gunLabel:Set(pos and ("Gun: " .. describeFromMe(pos)) or "Gun: not dropped")
        pingLabel:Set(string.format("Ping %d ms (smoothed)  ->  aim %d ms ahead of what you see", math.floor(Ping:ms() + 0.5), math.floor(leadSeconds() * 1000 + 0.5)))
        local parts = {}
        for _, w in ipairs({"Gun", "Knife"}) do
            local t = Shots.templates[w]
            parts[#parts + 1] = t and string.format("%s: %s %s, %d args, used x%d", w, t.method, t.path and "(in tool)" or "(global)", t.args.n, Shots.counts[w]) or (w .. ": not recorded")
        end
        shotLabel:Set(table.concat(parts, "\n"))
        logLabel:Set(#LOG > 0 and table.concat(LOG, "\n", math.max(1, #LOG - 9), #LOG) or "(empty)")
    end)))

    -- start-up
    Roles.scan()
end

local ok, err = xpcall(__run, function(e) return debug.traceback(tostring(e), 2) end)
if not ok then
    warn("[Wraith's Hub] failed to start: " .. tostring(err))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Wraith's Hub failed to start", Text = tostring(err):sub(1, 180), Duration = 20})
    end)
end
