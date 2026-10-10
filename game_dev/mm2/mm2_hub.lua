--[[ Murder Mystery 2 hub - roles, ESP, gun finder, aim / shot helpers, hitbox, player mods.
  Source file: build it into one script with `python3 game_dev/mm2/build_mm2.py` (it fills in the UILib / Logic modules below).
  Everything that depends on the game's private internals (remote names, hit detection) is DISCOVERED at run time - see MM2_NOTES.md. ]]
-- @@MODULES@@

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
    if type(genv.__MM2Hub) == "table" and genv.__MM2Hub.Destroy then pcall(genv.__MM2Hub.Destroy) end
    local Hub = {Alive = true, Conns = {}, Cleanups = {}}
    genv.__MM2Hub = Hub
    Hub.Destroy = function()
        if not Hub.Alive then return end
        Hub.Alive = false
        for _, c in ipairs(Hub.Conns) do pcall(function() c:Disconnect() end) end
        for _, fn in ipairs(Hub.Cleanups) do pcall(fn) end
        if Hub.Win then pcall(function() Hub.Win:Destroy() end) end
        if genv.__MM2Hub == Hub then genv.__MM2Hub = nil end
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
        walkOn = false, walkSpeed = 24, jumpOn = false, jumpPower = 60, infJump = false, noclip = false, fovOn = false, fovValue = 80,
        antiAfk = true, theme = "Crimson", uiKey = "RightShift",
    }
    local CONFIG_FILE = "mm2_hub_config.json"
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

    local pingCache, pingAt = 0.08, 0
    local function pingSeconds()
        if now() - pingAt < 1 then return pingCache end
        pingAt = now()
        local ok, ms = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if ok and type(ms) == "number" then pingCache = ms / 1000 end
        return pingCache
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
    espFolder.Name = "MM2HubESP"
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
    hud.Name = "MM2HubHud"
    hud.ResetOnSpawn = false
    hud.IgnoreGuiInset = true
    hud.DisplayOrder = 40
    hud.Parent = PARENT
    onCleanup(function() hud:Destroy() end)

    local gunBox = Instance.new("Frame")
    gunBox.AnchorPoint = Vector2.new(0.5, 0)
    gunBox.Position = UDim2.new(0.5, 0, 0, 14)
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

    local function predictedPos(part, char, shooterPos)
        local pos = part.Position
        if not S.predict then return pos end
        local vel = part.AssemblyLinearVelocity
        local root = rootOf(char)
        if root and root ~= part then vel = root.AssemblyLinearVelocity end
        local latency = S.addPing and pingSeconds() or 0
        local x, y, z = Logic.lead(pos.X, pos.Y, pos.Z, vel.X, vel.Y, vel.Z, shooterPos.X, shooterPos.Y, shooterPos.Z,
            {speed = S.bulletSpeed, latency = latency, strength = S.predictStrength, maxLead = 0.6, vertical = 0.5})
        return Vector3.new(x, y, z)
    end

    -- which mode is in effect for this weapon
    local function modeFor(weapon)
        local m = S.aimMode
        if m ~= "Auto (by my role)" then return m end
        if weapon == "Gun" then return "Murderer" end
        return "Closest to crosshair"
    end

    -- picks the best target for the weapon: returns plr, char, part, aimPosition
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
        return id, e.char, e.part, predictedPos(e.part, e.char, origin)
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
    local Shots = {templates = {}, pending = {}, counts = {Gun = 0, Knife = 0}, window = 0, windowWeapon = nil, skip = nil, last = {}}

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

    function Shots.fire(weapon)           -- aim at the best target and use the weapon; returns ok, text
        local plr, char, part, pos = Aim.pick(weapon)
        if not plr and S.aimMode == "Auto (by my role)" and weapon == "Knife" then plr, char, part, pos = Aim.pick(weapon, "Nearest") end
        if not plr then return false, "no target in range / line of sight" end
        local tool = equip(weapon)
        if not tool then return false, "you do not have the " .. weapon:lower() end
        local method = S.fireMethod
        if method == "Auto" then method = Shots.templates[weapon] and "Remote replay" or "Tool:Activate" end
        local aimMethod = S.aimMethod == "Mouse cursor" and "Mouse cursor" or "Both"
        if method ~= "Remote replay" then applyAim(pos, aimMethod, 0) end
        task.wait()                                              -- one frame so the equip and the aim have taken effect
        if not Hub.Alive then return false, "unloaded" end
        local ok, why = true, nil
        if method == "Remote replay" then
            ok, why = Shots.replay(weapon, plr, char, part, pos)
        elseif method == "Mouse click" and Cap.mouseClick then
            pcall(mouse1click)
        else
            local t2 = findTool(weapon)
            if t2 then pcall(function() t2:Activate() end) else ok, why = false, "weapon not ready" end
        end
        Shots.last[weapon] = now()
        return ok, ok and nameOf(plr) or why
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
    local function shootMurderer()
        local role = Roles.mine
        if role ~= "Sheriff" and role ~= "Hero" and not findTool("Gun") then notify("No gun", "You are not holding the gun.", "warn"); return end
        task.spawn(function()
            local ok, why = Shots.fire("Gun")
            if ok then notify("Shot fired", "at " .. tostring(why), "good", 2) else notify("Could not shoot", tostring(why), "warn", 3) end
        end)
    end
    local function throwKnife()
        if not findTool("Knife") then notify("No knife", "You are not the murderer.", "warn"); return end
        task.spawn(function()
            local plr, char, part, pos = Aim.pick("Knife")
            if not plr and S.aimMode == "Auto (by my role)" then plr, char, part, pos = Aim.pick("Knife", "Nearest") end
            if not plr then notify("Could not throw", "no target in range / line of sight", "warn", 3); return end
            local tool = equip("Knife")
            if not tool then return end
            task.wait()
            local ok = false
            if Shots.templates.Knife and S.fireMethod ~= "Tool:Activate" then
                ok = Shots.replay("Knife", plr, char, part, pos)
            end
            if not ok then
                applyAim(pos, S.aimMethod == "Mouse cursor" and "Mouse cursor" or "Both", 0)
                task.wait()
                ok = pressKey(S.throwKey)
            end
            Shots.last.Knife = now()
            notify(ok and "Knife thrown" or "Could not throw", ok and ("at " .. nameOf(plr)) or "set your throw key in Combat", ok and "good" or "warn", 2)
        end)
    end
    local function grabGun()
        local inst, pos = nearestGun()
        local root = myRoot()
        if not (pos and root) then notify("No gun on the map", nil, "warn", 3); return end
        local back = root.CFrame
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        task.delay(0.45, function()
            local r = myRoot()
            if r then r.CFrame = back end
            notify("Back where you were", "Check your hotbar for the gun.", "info", 3)
        end)
    end

    ------------------------------------------------------------------------------------------ main loops
    local acc = {slow = 0, mid = 0, poll = 0, auto = 0}
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
                if plr then Shots.busy = true; throwKnife(); task.delay(0.5, function() Shots.busy = false end) end
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

    track(RunService.Heartbeat:Connect(guard("heartbeat", function(dt)
        if not Hub.Alive then return end
        acc.slow, acc.mid, acc.poll, acc.auto = acc.slow + dt, acc.mid + dt, acc.poll + dt, acc.auto + dt
        Shots.process()
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
        RunService:BindToRenderStep("MM2HubAim", Enum.RenderPriority.Camera.Value + 1, guard("aim lock", function()
            ESP.drawTracers()
            if aimHeld() then
                local plr, _, _, pos = Aim.pick("Gun", S.aimMode == "Auto (by my role)" and (Roles.mine == "Murderer" and "Closest to crosshair" or "Murderer") or nil)
                if plr then applyAim(pos, S.aimMethod, S.aimSmooth) end
            end
        end))
    end)
    onCleanup(function() pcall(function() RunService:UnbindFromRenderStep("MM2HubAim") end) end)

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
    Win = UILib.new{Title = "MM2 Hub", Subtitle = "Murder Mystery 2", Parent = PARENT, GuiName = "MM2HubWindow", Theme = S.theme,
        ToggleKey = keyCodeFor(S.uiKey), OnError = report}
    Hub.Win = Win
    Win:SetAvatar(LocalPlayer.UserId)
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

    local main = Win:Tab("Main")
    local esp = Win:Tab("ESP")
    local combat = Win:Tab("Combat")
    local player = Win:Tab("Player")
    local misc = Win:Tab("Misc")
    local settings = Win:Tab("Settings")
    local dbg = Win:Tab("Debug")

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
    main:Label("First time: take your gun / knife out and fire or throw it ONCE by hand. I watch what the game sends (see the Debug tab), then the buttons below, auto shoot and silent aim use the same call with a better aim point.")
    main:Button{Title = "Shoot the murderer", Desc = "Sheriff / hero: aims with prediction and fires the gun.", Label = "Fire", Callback = shootMurderer}
    main:Button{Title = "Throw knife at best target", Desc = "Murderer: aims and throws using your throw key or the recorded throw.", Label = "Throw", Callback = throwKnife}
    main:Button{Title = "Grab the gun", Desc = "Teleports to the dropped gun for a moment and brings you straight back.", Label = "Go", Callback = grabGun}
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
    drop(combat, "aimMode", "Aim target", {"Auto (by my role)", "Murderer", "Sheriff", "Closest to crosshair", "Nearest"})
    drop(combat, "aimPart", "Aim at", {"Head", "Torso"})
    tog(combat, "wallCheck", "Wall check", "Only targets with a clear line of sight.")
    sld(combat, "maxDistance", "Max distance", 30, 600, 10, " studs")
    sld(combat, "fov", "Crosshair FOV", 40, 600, 10, " px")
    tog(combat, "showFov", "Show FOV circle")
    combat:Section("Prediction")
    tog(combat, "predict", "Lead moving targets", "Aims where they will be, using their velocity.")
    tog(combat, "addPing", "Add my ping", "Leads a little more on a laggy connection.")
    sld(combat, "bulletSpeed", "Bullet speed (0 = instant)", 0, 600, 10, " sps")
    sld(combat, "predictStrength", "Lead strength", 0, 2, 0.1, "x")
    combat:Section("Aim assist (hold the key)")
    tog(combat, "aimLock", "Aim assist", "While the key is held, your camera / cursor follows the target.")
    key(combat, "aimKey", "Aim key (hold)", "Right-click is the camera drag, so use a key.")
    drop(combat, "aimMethod", "Aim method", {"Camera", "Mouse cursor", "Both"})
    sld(combat, "aimSmooth", "Smoothness", 0, 0.9, 0.05, "")
    combat:Section("Gun - sheriff / hero")
    key(combat, "shootKey", "Shoot-the-murderer key", "One press: aim, predict and fire.", shootMurderer)
    tog(combat, "autoShoot", "Auto shoot", "Fires as soon as the murderer is in range and visible.")
    sld(combat, "shootGap", "Time between shots", 0.5, 6, 0.1, " s")
    tog(combat, "silentAim", "Silent aim (your own shots)", Cap.hook and "Your normal shots fly at the predicted target. Needs one recorded shot." or "Needs hookmetamethod - not available here.")
    drop(combat, "fireMethod", "How to fire", {"Auto", "Remote replay", "Tool:Activate", "Mouse click"})
    combat:Section("Knife - murderer")
    key(combat, "throwAtKey", "Throw-at-target key", "One press: aim, predict and throw.", throwKnife)
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

    -- Player
    player:Section("Movement")
    tog(player, "walkOn", "Walk speed")
    sld(player, "walkSpeed", "Speed", 16, 80, 1, "")
    tog(player, "jumpOn", "Jump power")
    sld(player, "jumpPower", "Power", 50, 200, 5, "")
    tog(player, "infJump", "Infinite jump")
    tog(player, "noclip", "Noclip")
    player:Section("Camera")
    tog(player, "fovOn", "Field of view")
    sld(player, "fovValue", "FOV", 40, 120, 1, "")

    -- Misc
    misc:Section("Session")
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
    key(settings, "uiKey", "Show / hide menu", "Also tap the M button on screen.", nil, function(v) Win.ToggleKey = keyCodeFor(v) end)
    settings:Section("Config")
    settings:Label("Nothing is saved unless you press Save config.")
    settings:Button{Title = "Save config", Label = "Save", Callback = function()
        if not Cap.files then notify("Cannot save", "This executor has no writefile.", "bad"); return end
        local state = Win:GetState()
        state.theme = Win:GetTheme()
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
        local lines = {"MM2 Hub diagnostics", "place " .. tostring(game.PlaceId), string.format("role %s | murderer %s | sheriff %s", tostring(Roles.mine),
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

    -- live labels
    local lastLabels = 0
    track(RunService.Heartbeat:Connect(guard("labels", function()
        if now() - lastLabels < 0.6 or not Win.Main.Visible then return end
        lastLabels = now()
        local m, s = Roles.murderer(), Roles.sheriff()
        roundLabel:Set(string.format("You: %s\nMurderer: %s\nSheriff / hero: %s", Roles.mine or (Roles.active and "spectating" or "lobby"), m and nameOf(m) or "unknown", s and nameOf(s) or "unknown"))
        local _, pos = nearestGun()
        gunLabel:Set(pos and ("Gun: " .. describeFromMe(pos)) or "Gun: not dropped")
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
    local summary = {}
    if not Cap.hook then summary[#summary + 1] = "no hook (silent aim / shot recording off)" end
    if not Cap.drawing then summary[#summary + 1] = "no Drawing (no tracers)" end
    if not Cap.mouseRel then summary[#summary + 1] = "no mousemoverel (cursor aim off)" end
    if game.PlaceId ~= 142823291 then summary[#summary + 1] = "this does not look like Murder Mystery 2" end
    notify("MM2 Hub loaded", #summary > 0 and table.concat(summary, "; ") or "All features available.", #summary > 0 and "warn" or "good", 5)
end

local ok, err = xpcall(__run, function(e) return debug.traceback(tostring(e), 2) end)
if not ok then
    warn("[MM2 Hub] failed to start: " .. tostring(err))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = "MM2 Hub failed to start", Text = tostring(err):sub(1, 180), Duration = 20})
    end)
end
