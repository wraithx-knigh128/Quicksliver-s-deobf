--[[ Wraith's TSB Lab (The Strongest Battlegrounds): the Tech Lab (tech_lab.lua) on the WindUI window library, laid out like the tech hub it was rewritten from:
  one tab per tech family, an Overview with the master switch / Panic / live cooldowns and ping, a Settings tab with the menu options, the ping model and a config manager.
  The tabs are generated from the tech definitions in tech_lab.lua, so a new tech needs no UI code.
  Source file: build it into one script with `python3 game_dev/tsb/build_tsb_lab.py` (it fills in the PingModel / Tech* / UILib / WindUI modules below).
  Nothing in it has been run in the real game - see the README. Nothing is saved unless you press Save config. ]]
-- @@MODULES@@

local function __run()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = Players.LocalPlayer
    while LocalPlayer == nil do task.wait(0.1); LocalPlayer = Players.LocalPlayer end

    local function service(name) local ok, s = pcall(function() return game:GetService(name) end); return ok and s or nil end
    local VIM, Stats = service("VirtualInputManager"), service("Stats")

    ------------------------------------------------------------------------------------------ session / logging
    local genv = (getgenv and getgenv()) or _G
    if type(genv.__TSBLab) == "table" and genv.__TSBLab.Destroy then pcall(genv.__TSBLab.Destroy) end
    local Hub = {Alive = true, Conns = {}, Cleanups = {}}
    genv.__TSBLab = Hub
    Hub.Destroy = function()
        if not Hub.Alive then return end
        Hub.Alive = false
        for _, c in ipairs(Hub.Conns) do pcall(function() c:Disconnect() end) end
        for _, fn in ipairs(Hub.Cleanups) do pcall(fn) end
        if Hub.Win then pcall(function() Hub.Win:Destroy() end) end
        if genv.__TSBLab == Hub then genv.__TSBLab = nil end
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

    ------------------------------------------------------------------------------------------ what this executor can do
    local Cap = {
        files = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function",
        listfiles = type(listfiles) == "function",
        folders = type(makefolder) == "function" and type(isfolder) == "function",
        delfile = type(delfile) == "function",
        clipboard = type(setclipboard) == "function",
        gethui = type(gethui) == "function",
    }
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

    ------------------------------------------------------------------------------------------ ping (round trip, smoothed: one lag spike must not move every timing)
    local PingM = PingModel.new(0.2)
    local function samplePing()
        local ok, ms = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if ok and type(ms) == "number" then PingM:sample(ms) end
    end
    samplePing()

    ------------------------------------------------------------------------------------------ menu settings + config files
    local function clampNum(v, lo, hi, default) if type(v) == "number" and v == v then return math.max(lo, math.min(hi, v)) end return default end
    -- the Lab's own colours (the standard WindUI themes stay available too)
    WindAdapter.addThemes({
        {Name = "Frost", Accent = "#0f1c24", Dialog = "#101c24", Outline = "#bfefff", Text = "#eaf8ff", Placeholder = "#7fa3b3", Background = "#0b1218", Button = "#2c4a5a", Icon = "#8fd8f0",
         Toggle = "#36d1ff", Slider = "#36d1ff", Checkbox = "#36d1ff", Primary = "#36d1ff", SliderIcon = "#8fd8f0", PanelBackground = "#bfefff", PanelBackgroundTransparency = 0.95,
         LabelBackground = "#000000", LabelBackgroundTransparency = 0.8, ElementBackground = "#17262f", ElementBackgroundTransparency = 0},
        {Name = "Ember", Accent = "#1f1410", Dialog = "#22160f", Outline = "#ffd9b8", Text = "#fff1e6", Placeholder = "#b39a88", Background = "#140d09", Button = "#5a3a28", Icon = "#ffb27a",
         Toggle = "#ff8a3d", Slider = "#ff8a3d", Checkbox = "#ff8a3d", Primary = "#ff8a3d", SliderIcon = "#ffb27a", PanelBackground = "#ffd9b8", PanelBackgroundTransparency = 0.95,
         LabelBackground = "#000000", LabelBackgroundTransparency = 0.8, ElementBackground = "#2b1c14", ElementBackgroundTransparency = 0},
        {Name = "Mint", Accent = "#0f1f19", Dialog = "#10201a", Outline = "#c9ffe6", Text = "#ecfff6", Placeholder = "#84ad9a", Background = "#0a130f", Button = "#2c5a46", Icon = "#8fe8c0",
         Toggle = "#3ddc97", Slider = "#3ddc97", Checkbox = "#3ddc97", Primary = "#3ddc97", SliderIcon = "#8fe8c0", PanelBackground = "#c9ffe6", PanelBackgroundTransparency = 0.95,
         LabelBackground = "#000000", LabelBackgroundTransparency = 0.8, ElementBackground = "#16291f", ElementBackgroundTransparency = 0},
    })
    local THEMES = WindAdapter.ThemeNames
    local FLOAT_DEFS = {   -- the on-screen buttons: id, label, icon, accent, the tech it runs (nil = Panic)
        {id = "panic", title = "PANIC", icon = "close", accent = {236, 64, 72}},
        {id = "hook", title = "HOOK", icon = "crosshair", accent = {120, 200, 255}, tech = "hook"},
        {id = "m1reset", title = "M1 RESET", icon = "bolt", accent = {255, 200, 80}, tech = "m1reset"},
        {id = "emotedash", title = "EMOTE DASH", icon = "move", accent = {170, 120, 255}, tech = "emotedash"},
        {id = "backdash", title = "BACKDASH", icon = "chevron_down", accent = {120, 230, 160}, tech = "backdash"},
        {id = "microdash", title = "MICRO", icon = "spark", accent = {255, 140, 200}, tech = "microdash"},
        {id = "shovedash", title = "SHOVE", icon = "knife", accent = {255, 160, 90}, tech = "shovedash"},
    }
    local DEFAULT_UI = {theme = "Frost", uiKey = "RightShift", uiScale = 0.9, uiAlpha = 0.45, waves = "High", btnSize = 76, btnLock = false, autoLoad = false, configName = "default"}
    local S = {}
    for k, v in pairs(DEFAULT_UI) do S[k] = v end
    S.floats = {}
    for i, d in ipairs(FLOAT_DEFS) do S.floats[d.id] = {x = -1, y = -1, visible = d.id == "panic"} end      -- -1 = placed down the right edge

    local DIR, INDEX = "TSBLab", "TSBLab/index.json"
    local function cleanName(name)
        name = tostring(name or ""):gsub("[^%w_%- ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if #name > 32 then name = name:sub(1, 32) end
        return name ~= "" and name or "default"
    end
    local function pathOf(name) return DIR .. "/" .. cleanName(name) .. ".json" end
    local function ensureDir()
        if Cap.folders then
            local okd, has = pcall(isfolder, DIR)
            if okd and not has then pcall(makefolder, DIR) end
        end
    end
    local function decodeFile(path)
        if not (Cap.files and pcall(isfile, path) and isfile(path)) then return nil end
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if ok and type(data) == "table" then return data end
        report("config", data)
    end
    local function listConfigs()
        local out = {}
        if Cap.listfiles then
            local ok, files = pcall(listfiles, DIR)
            if ok and type(files) == "table" then
                for _, f in ipairs(files) do
                    local name = tostring(f):match("([^/\\]+)%.json$")
                    if name and name ~= "index" then out[#out + 1] = name end
                end
            end
        end
        table.sort(out)
        return out
    end
    -- the settings that live outside the Tech Lab; anything invalid in a file falls back to the default
    local function mergeUI(saved)
        if type(saved) ~= "table" then return end
        if type(saved.theme) == "string" then for _, t in ipairs(THEMES) do if t == saved.theme then S.theme = t end end end
        if type(saved.uiKey) == "string" and saved.uiKey:match("^%a[%w]*$") and #saved.uiKey <= 16 then S.uiKey = saved.uiKey end
        S.uiScale = clampNum(saved.uiScale, 0.55, 1.2, S.uiScale)
        S.uiAlpha = clampNum(saved.uiAlpha, 0, 0.9, S.uiAlpha)
        if saved.waves == "High" or saved.waves == "Low" or saved.waves == "Off" then S.waves = saved.waves end
        S.btnSize = clampNum(saved.btnSize, 56, 120, S.btnSize)
        if type(saved.btnLock) == "boolean" then S.btnLock = saved.btnLock end
    end
    local function mergeFloats(saved)
        if type(saved) ~= "table" then return end
        for id, f in pairs(S.floats) do
            local sf = saved[id]
            if type(sf) == "table" then
                f.x, f.y = clampNum(sf.x, -1, 1, f.x), clampNum(sf.y, -1, 1, f.y)
                if type(sf.visible) == "boolean" then f.visible = sf.visible end
            end
        end
    end
    local savedTech
    local loadedFrom = "none"
    local function adopt(data, name)
        if type(data) ~= "table" then return false end
        mergeUI(data.ui)
        mergeFloats(data.floats)
        savedTech = type(data.techlab) == "table" and data.techlab or nil
        S.configName = cleanName(name)
        loadedFrom = "file"
        return true
    end
    do   -- start-up: only a config you saved yourself is loaded, and only when you asked for Auto load when you saved it
        local index = decodeFile(INDEX)
        if index and index.autoload == true and type(index.name) == "string" then
            if adopt(decodeFile(pathOf(index.name)), index.name) then S.autoLoad = true end
        end
    end

    ------------------------------------------------------------------------------------------ the window (declared first: toasts raised before it exists wait in a queue)
    local Win
    local queued = {}
    local function notify(title, content, kind, secs)
        if Win then Win:Notify{Title = title, Content = content, Type = kind or "info", Duration = secs or 4}; return end
        queued[#queued + 1] = {title, content, kind, secs}
    end

    ------------------------------------------------------------------------------------------ the Tech Lab engine
    local Floats = {}
    local statusLabels = {}
    local dirty = false
    local ready = false
    local configStatus
    local function refreshConfigStatus()
        if not configStatus then return end
        local where = loadedFrom == "file" and ("Config '" .. S.configName .. "' is loaded.") or "No config loaded: everything is at its defaults."
        configStatus:Set(where .. (dirty and "  Changes since then are NOT saved." or ""))
    end
    local function markDirty()
        if not ready or dirty then return end
        dirty = true
        refreshConfigStatus()
    end
    local function shortStatus(tech)
        local t = tech.status or ""
        if #t > 26 then t = t:sub(1, 25) .. "~" end
        return t
    end
    local lab
    local function statusText(tech) return "Starts: " .. tech.when .. "\nStatus: " .. tech.status end
    lab = TechLab.new({
        Players = Players, RunService = RunService, UserInputService = UIS, Workspace = workspace, LocalPlayer = LocalPlayer, VirtualInput = VIM,
        TechMath = TechMath, TechData = TechData, TechOptions = TechOptions,
        connect = function(sig, fn) return track(sig:Connect(fn)) end,
        safe = function(fn, ...) local ok, r = pcall(fn, ...); if ok then return r end end,
        clock = os.clock,
        pingMs = function() return PingM:value() end,
        jitterMs = function() return PingM:jitter() end,
        busy = function() return false end,
        log = function(msg) logLine(msg) end,
        toast = function(msg) notify("Tech Lab", msg, "info", 3) end,
        onStatus = function(tech)
            local l = statusLabels[tech.id]
            if l then l:Set(statusText(tech)) end
            local f = Floats[tech.id]
            if f then
                local kind = tech.running and "wait" or (tech.enabled and "ready" or "off")
                f:SetStatus(shortStatus(tech), kind)
            end
        end,
    })
    if savedTech then lab:import(savedTech) end
    onCleanup(function() lab:destroy() end)

    local function snapshot()
        local floats = {}
        for id, f in pairs(S.floats) do
            local live = Floats[id]
            local x, y = f.x, f.y
            if live then x, y = live:GetPos() end
            floats[id] = {x = x, y = y, visible = f.visible}
        end
        return {version = 1, ui = {theme = S.theme, uiKey = S.uiKey, uiScale = S.uiScale, uiAlpha = S.uiAlpha, waves = S.waves, btnSize = S.btnSize, btnLock = S.btnLock},
            floats = floats, techlab = lab:export()}
    end
    local function saveConfig(name)
        if not Cap.files then return false, "Your executor cannot write files, so nothing can be saved." end
        name = cleanName(name)
        ensureDir()
        local okj, json = pcall(function() return HttpService:JSONEncode(snapshot()) end)
        if not okj or type(json) ~= "string" then return false, "Could not turn the settings into a file." end
        if not pcall(writefile, pathOf(name), json) then return false, "Your executor refused to write the file." end
        pcall(writefile, INDEX, HttpService:JSONEncode({autoload = S.autoLoad == true, name = name}))      -- (what Auto load means is decided when you SAVE)
        S.configName, loadedFrom, dirty = name, "file", false
        refreshConfigStatus()
        return true
    end
    local function deleteConfig(name)
        name = cleanName(name)
        local path = pathOf(name)
        local existed = Cap.files and pcall(isfile, path) and isfile(path)
        if not existed then return false, "There is no config called " .. name end
        if Cap.delfile then pcall(delfile, path) elseif Cap.files then pcall(writefile, path, "") end
        local index = decodeFile(INDEX)
        if index and index.name == name then pcall(writefile, INDEX, HttpService:JSONEncode({autoload = false, name = name})) end
        if S.configName == name then loadedFrom = "none" end
        refreshConfigStatus()
        return true
    end

    ------------------------------------------------------------------------------------------ the window
    local function traceback(e) return debug.traceback(tostring(e), 2) end
    local usingWind = false
    local function keyCodeFor(name)
        local ok, code = pcall(function() return Enum.KeyCode[name] end)
        return ok and code or Enum.KeyCode.RightShift
    end
    local function makeWindow(cfg)
        local okLib, WindUI = xpcall(WindUILoader, traceback)
        if okLib and type(WindUI) == "table" and WindUI.CreateWindow then
            cfg.Theme = WindAdapter.themeFor(S.theme)
            local ok, res = xpcall(WindAdapter.new, traceback, WindUI, UILib, cfg)
            if ok then usingWind = true; return res end
            report("WindUI window", res)
        else
            report("WindUI load", WindUI)
        end
        queued[#queued + 1] = {"WindUI could not start", "Using the small built-in menu instead (details: Settings > Log). Your executor may block the library's file / web calls.", "warn", 8}
        local theme = "Ocean"
        cfg.Theme = theme
        return UILib.new(cfg)
    end
    Win = makeWindow{Title = "Wraith's TSB Lab", Subtitle = "The Strongest Battlegrounds", Group = "Wraith's TSB Lab", Parent = PARENT, GuiName = "WraithsTSBLab", Folder = "TSBLab",
        WaveMode = S.waves, ToggleKey = keyCodeFor(S.uiKey), OnError = report, WindowAlpha = S.uiAlpha, Scale = S.uiScale, Mono = false,
        WindowIcon = "sword", OpenColors = {"#7ad7ff", "#9b7bff"}}
    S.theme = Win:GetTheme()
    Hub.Win = Win
    Hub.Lab = lab
    Hub.S = S
    for _, q in ipairs(queued) do notify(q[1], q[2], q[3], q[4]) end
    queued = {}

    ------------------------------------------------------------------------------------------ the on-screen buttons
    local function floatPos(index)                                  -- down the right edge, two columns
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        local size = S.btnSize
        local col = (index - 1) % 2 + 1
        local row = math.floor((index - 1) / 2)
        local x = vp.X - 12 - col * size - (col - 1) * 8
        local y = vp.Y * 0.14 + row * (size + 26)
        return math.max(0, math.min(x, vp.X - size)) / vp.X, math.max(0, math.min(y, vp.Y - size)) / vp.Y
    end
    for i, d in ipairs(FLOAT_DEFS) do
        local f = S.floats[d.id]
        local fx, fy = f.x, f.y
        if fx < 0 or fy < 0 then fx, fy = floatPos(i) end
        Floats[d.id] = Win:Floating{Id = d.id, Title = d.title, Icon = d.icon, Accent = d.accent, Size = S.btnSize, Pos = {fx, fy}, Visible = f.visible, Locked = S.btnLock,
            OnPress = function()
                if not d.tech then
                    lab:cancelAll("cancelled: panic")
                    return true
                end
                local ok = lab:fire(d.tech, {manual = true})
                local tech, f = lab.techs[d.tech], Floats[d.id]
                if f then
                    f:Flash(ok == true)
                    if ok and tech.opt.cooldown and tech.opt.cooldown > 0.1 then f:Cooldown(tech.opt.cooldown) end
                end
                return "async"
            end,
            OnMoved = function(x, y) f.x, f.y = x, y; markDirty() end}
    end

    ------------------------------------------------------------------------------------------ building the menu a few controls per frame (a phone builds a WindUI menu slowly)
    local paceCount, paceStart = 0, os.clock()
    local function pace()
        paceCount = paceCount + 1
        if paceCount >= 6 or os.clock() - paceStart > 0.012 then
            paceCount = 0
            task.wait()
            paceStart = os.clock()
            if not Hub.Alive then error("__unloaded__", 0) end
        end
    end
    local function paced(tab)
        for _, name in ipairs({"Section", "Label", "Toggle", "Slider", "Dropdown", "Keybind", "Button", "Input"}) do
            local f = tab[name]
            if f then tab[name] = function(self, ...) local r = f(self, ...); pace(); return r end end
        end
        return tab
    end
    local function tabIcon(wind, classic) return usingWind and wind or classic end

    ------------------------------------------------------------------------------------------ Overview
    local overview = paced(Win:Tab("Overview", tabIcon("layout-dashboard", "grid")))
    overview:Section("Tech Lab")
    overview:Label("The techs from your own Dovi's Hub script, rebuilt as small sequences on one engine: every wait stops when you die, respawn, press Panic or switch the tech off, everything a tech creates is removed again, a tech that starts with a dash waits for that dash's cooldown, and only one moving tech runs at a time. Everything starts OFF. Nothing was run in the real game - if a tech does not react, its trigger animation id has probably changed: use 'Learn trigger' inside the tech.")
    overview:Toggle{Title = "Tech Lab master switch", Desc = "Off = every tech stops and ignores its trigger", Default = lab.master, Flag = "master", NoInitialCallback = true, Callback = guard("master", function(on)
        if lab.master ~= on then lab:setMaster(on); markDirty() end
    end)}
    overview:Button{Title = "Panic - cancel every running tech", Desc = "Also the red PANIC button on screen", Callback = guard("panic", function()
        lab:cancelAll("cancelled: panic")
        notify("Tech Lab", "Everything cancelled", "good", 2)
    end)}
    overview:Dropdown{Title = "Inputs", Desc = "Auto = the game's own remote, keys when it is missing", Values = {"Auto", "Remote", "Keys"}, Default = lab.input, Flag = "input", Callback = guard("input", function(v)
        if lab.input ~= v then lab:setInput(v); markDirty() end
    end)}
    overview:Toggle{Title = "Wait for the dash cooldown", Desc = "A tech that starts with a dash does not start while that dash is on cooldown", Default = lab.dashGuard, Flag = "dashGuard", NoInitialCallback = true,
        Callback = guard("dashGuard", function(on) if lab.dashGuard ~= on then lab.dashGuard = on; markDirty() end end)}
    overview:Toggle{Title = "Let go of block before an M1", Default = lab.releaseBlock, Flag = "releaseBlock", NoInitialCallback = true,
        Callback = guard("releaseBlock", function(on) if lab.releaseBlock ~= on then lab.releaseBlock = on; markDirty() end end)}
    overview:Section("Live")
    local cooldownLabel = overview:Label("")
    local pingLabel = overview:Label("")

    ------------------------------------------------------------------------------------------ one tab per tech family
    local TABS = {
        {"Supa", "sword", "spark", {"supa"}},
        {"Hook Dash", "link", "crosshair", {"hook"}},
        {"Loop Dash", "refresh-cw", "bolt", {"loop", "loop2"}},
        {"Kiba / Kitty", "crosshair", "crosshair", {"kiba"}},
        {"Kyoto Combo", "swords", "knife", {"kyoto", "dunk", "surf"}},
        {"Lethal Dash", "zap", "bolt", {"lethal", "lethalgrasp"}},
        {"Twisted", "move", "move", {"twisted"}},
        {"M1 Reset", "timer", "dots", {"m1reset", "emotedash", "shovedash"}},
        {"Cancels", "gauge", "dots", {"backdash", "microdash", "uppercutcatch", "uppercutgrasp", "flowinggrasp"}},
        {"Auto Counter", "shield", "dots", {"counter"}},
        {"Tech Helper", "wrench", "gear", {"flip", "catch", "mousedash", "sidem1", "noendlag", "slidem1", "downslam", "fastdash", "dashclip"}},
        {"Awareness", "eye", "eye", {"counteresp", "deathcounter", "blockwarn", "blockesp"}},
    }
    Hub.Tabs = TABS
    local FLOAT_OF = {}
    for _, d in ipairs(FLOAT_DEFS) do if d.tech then FLOAT_OF[d.tech] = d end end

    local function buildTech(tab, id)
        local tech = lab.techs[id]
        tab:Section(tech.title)
        tab:Toggle{Title = "Enable " .. tech.title, Desc = tech.desc, Default = tech.enabled, Flag = id .. ".on", NoInitialCallback = true, Callback = guard(id .. " switch", function(on)
            if lab.techs[id].enabled ~= on then lab:setEnabled(id, on); markDirty() end
        end)}
        statusLabels[id] = tab:Label(statusText(tech))
        local controls = {}
        if tech.manual then
            tab:Button{Title = "Run " .. tech.title .. " now", Desc = tech.when, Callback = guard(id .. " run", function() lab:fire(id, {manual = true}) end)}
        end
        for _, d in ipairs(tech.defs) do
            local key = d.key
            local function put(v)
                if lab.techs[id].opt[key] ~= v then lab:setOption(id, key, v); markDirty() end
            end
            local flag = id .. "." .. key
            local el
            if d.kind == "number" then
                el = tab:Slider{Title = d.label, Min = d.min, Max = d.max, Step = d.step, Default = tech.opt[key], Flag = flag, Callback = guard(flag, put)}
            elseif d.kind == "bool" then
                el = tab:Toggle{Title = d.label, Desc = d.tip, Default = tech.opt[key], Flag = flag, NoInitialCallback = true, Callback = guard(flag, put)}
            elseif d.kind == "choice" then
                el = tab:Dropdown{Title = d.label, Values = d.choices, Default = tech.opt[key], Flag = flag, Callback = guard(flag, put)}
            elseif d.kind == "key" then
                el = tab:Keybind{Title = d.label, Desc = "Press the key you want (any key)", Default = tech.opt[key], Flag = flag, Changed = guard(flag, put), IgnoreProcessed = false}
            else
                el = tab:Input{Title = d.label, Default = tech.opt[key], Placeholder = "empty = the default", Flag = flag, Callback = guard(flag, function(text) put((text:gsub("^%s+", ""):gsub("%s+$", ""))) end)}
            end
            controls[#controls + 1] = {def = d, el = el}
        end
        if not (tech.observer or tech.poll or tech.manual or tech.mouse or tech.key) then
            tab:Button{Title = "Learn trigger: play the move that should start " .. tech.title, Desc = "Listens for the next animation you play (15 s)", Callback = guard(id .. " learn", function()
                lab:learnTrigger(id, function() markDirty() end)
                notify("Tech Lab", "Now play the move that should start " .. tech.title, "info", 4)
            end)}
            tab:Button{Title = "Forget the triggers I taught " .. tech.title, Callback = guard(id .. " forget", function()
                lab:forgetTriggers(id)
                markDirty()
                notify("Tech Lab", "Learned triggers forgotten", "info", 3)
            end)}
        end
        local fd = FLOAT_OF[id]
        if fd then
            tab:Toggle{Title = "Show the on-screen " .. fd.title .. " button", Default = S.floats[fd.id].visible, Flag = "float." .. fd.id, NoInitialCallback = true, Callback = guard(fd.id .. " button", function(on)
                if S.floats[fd.id].visible ~= on then S.floats[fd.id].visible = on; markDirty() end
                if Floats[fd.id] then Floats[fd.id]:SetVisible(on) end
            end)}
        end
        tab:Button{Title = "Reset " .. tech.title .. " to its defaults", Callback = guard(id .. " reset", function()
            for _, c in ipairs(controls) do
                lab:setOption(id, c.def.key, c.def.default)
                c.el:Set(c.def.default, true)
            end
            markDirty()
            notify("Tech Lab", tech.title .. ": options reset", "info", 2)
        end)}
    end
    for _, t in ipairs(TABS) do
        local tab = paced(Win:Tab(t[1], tabIcon(t[2], t[3])))
        for _, id in ipairs(t[4]) do buildTech(tab, id) end
    end

    ------------------------------------------------------------------------------------------ Settings
    local settings = paced(Win:Tab("Settings", tabIcon("settings", "gear")))
    settings:Section("Menu")
    settings:Keybind{Title = "Menu key", Desc = "Shows / hides this window", Default = S.uiKey, Flag = "uiKey", Changed = guard("menu key", function(v)
        if S.uiKey ~= v then S.uiKey = v; Win.ToggleKey = keyCodeFor(v); markDirty() end
    end)}
    settings:Dropdown{Title = "Theme", Values = THEMES, Default = S.theme, Flag = "theme", Callback = guard("theme", function(v)
        if S.theme ~= v then S.theme = v; Win:SetTheme(v); markDirty() end
    end)}
    settings:Slider{Title = "Menu size", Min = 0.55, Max = 1.2, Step = 0.05, Default = S.uiScale, Flag = "uiScale", Callback = guard("uiScale", function(v)
        if S.uiScale ~= v then S.uiScale = v; if Win.SetScale then Win:SetScale(v) end; markDirty() end
    end)}
    settings:Slider{Title = "Window transparency", Min = 0, Max = 0.9, Step = 0.05, Default = S.uiAlpha, Flag = "uiAlpha", Callback = guard("uiAlpha", function(v)
        if S.uiAlpha ~= v then S.uiAlpha = v; if Win.SetBackgroundTransparency then Win:SetBackgroundTransparency(v) end; markDirty() end
    end)}
    settings:Section("Ping")
    settings:Label("What the Tech Lab does with your ping: waits that start at one of your own animations start earlier by how late those animations arrive after your input (measured from your own dashes), another player is led by half your ping plus Roblox's drawing delay, and a number tuned at 60 ms scales with your ping.")
    settings:Slider{Title = "Ping compensation (0 = off, 1 = full)", Min = 0, Max = 2, Step = 0.05, Default = lab.net.strength, Flag = "net.strength", Callback = guard("net.strength", function(v)
        if lab.net.strength ~= v then lab:setNet("strength", v); markDirty() end
    end)}
    settings:Slider{Title = "Typed ping in ms (0 = measure it)", Min = 0, Max = 600, Step = 5, Default = lab.net.manual, Flag = "net.manual", Callback = guard("net.manual", function(v)
        if lab.net.manual ~= v then lab:setNet("manual", v); markDirty() end
    end)}
    settings:Slider{Title = "Roblox's drawing delay for other players (ms)", Min = 0, Max = 250, Step = 5, Default = lab.net.interp, Flag = "net.interp", Callback = guard("net.interp", function(v)
        if lab.net.interp ~= v then lab:setNet("interp", v); markDirty() end
    end)}
    settings:Slider{Title = "The ping my default numbers were tuned at (ms)", Min = 10, Max = 300, Step = 5, Default = lab.net.ref, Flag = "net.ref", Callback = guard("net.ref", function(v)
        if lab.net.ref ~= v then lab:setNet("ref", v); markDirty() end
    end)}
    settings:Toggle{Title = "Measure how late my own animations arrive", Desc = "Every dash I send and the animation that answers it", Default = lab.net.learn, Flag = "net.learn", NoInitialCallback = true,
        Callback = guard("net.learn", function(on) if lab.net.learn ~= on then lab:setNet("learn", on); markDirty() end end)}
    settings:Section("On-screen buttons")
    settings:Slider{Title = "Button size", Min = 56, Max = 120, Step = 2, Default = S.btnSize, Flag = "btnSize", Callback = guard("btnSize", function(v)
        if S.btnSize ~= v then
            S.btnSize = v
            for _, f in pairs(Floats) do f:SetSize(v) end
            markDirty()
        end
    end)}
    settings:Toggle{Title = "Lock the buttons in place", Default = S.btnLock, Flag = "btnLock", NoInitialCallback = true, Callback = guard("btnLock", function(on)
        if S.btnLock ~= on then S.btnLock = on; for _, f in pairs(Floats) do f:SetLocked(on) end; markDirty() end
    end)}
    settings:Toggle{Title = "Show the PANIC button", Default = S.floats.panic.visible, Flag = "float.panic", NoInitialCallback = true, Callback = guard("panic button", function(on)
        if S.floats.panic.visible ~= on then S.floats.panic.visible = on; markDirty() end
        if Floats.panic then Floats.panic:SetVisible(on) end
    end)}
    settings:Label("The buttons for Hook Dash, M1 Reset, Emote Dash, Backdash Cancel, Micro Dash and Shove Dash are switched on inside each tech. Drag one to move it; it keeps its place when you press Save config.")
    settings:Section("Config")
    settings:Label("NOTHING is saved automatically. A config holds the menu options, the on-screen buttons and every tech's switch / option / learned trigger. Auto load is decided when you press Save.")
    configStatus = settings:Label("")
    local nameInput = settings:Input{Title = "Config name", Default = S.configName, Placeholder = "default", Flag = "configName", Callback = guard("config name", function(v) S.configName = cleanName(v) end)}
    local allConfigs = settings:Dropdown{Title = "All configs", Desc = "Pick one, then Load", Values = (function() local l = listConfigs(); return #l > 0 and l or {"(none yet)"} end)(), Default = S.configName, Flag = "allConfigs",
        Callback = guard("all configs", function(v) if v ~= "(none yet)" then S.configName = cleanName(v); nameInput:Set(S.configName, true) end end)}
    local function refreshConfigList()
        local l = listConfigs()
        allConfigs:SetValues(#l > 0 and l or {"(none yet)"})
    end
    settings:Toggle{Title = "Auto load", Desc = "Load this config the next time the script starts (written when you press Save)", Default = S.autoLoad, Flag = "autoLoad", NoInitialCallback = true,
        Callback = guard("autoLoad", function(on) if S.autoLoad ~= on then S.autoLoad = on; markDirty() end end)}
    settings:Button{Title = "Save config", Callback = guard("save", function()
        local ok, why = saveConfig(S.configName)
        notify(ok and "Config saved" or "Not saved", ok and ("'" .. S.configName .. "' will be available next time") or tostring(why), ok and "good" or "bad", 4)
        if ok then refreshConfigList() end
    end)}
    settings:Button{Title = "Load config (rebuilds nothing - applies live)", Callback = guard("load", function()
        local data = decodeFile(pathOf(S.configName))
        if not data then notify("Not loaded", "There is no saved config called " .. S.configName, "warn", 4) return end
        mergeUI(data.ui)
        mergeFloats(data.floats)
        if type(data.techlab) == "table" then lab:import(data.techlab) end
        loadedFrom, dirty = "file", false
        for _, el in ipairs(Win.Elements) do                       -- the controls follow the new values
            local flag = el.Flag
            if flag then
                local id, key = flag:match("^([%w]+)%.([%w]+)$")
                local tech = id and lab.techs[id]
                if tech and key == "on" then el:Set(tech.enabled, true)
                elseif tech and tech.opt[key] ~= nil then el:Set(tech.opt[key], true)
                elseif id == "net" and lab.net[key] ~= nil then el:Set(lab.net[key], true)
                elseif id == "float" and S.floats[key] then el:Set(S.floats[key].visible, true) end
            end
        end
        for id, f in pairs(Floats) do f:SetVisible(S.floats[id].visible) end
        Win:SetTheme(S.theme)
        if Win.SetScale then Win:SetScale(S.uiScale) end
        if Win.SetBackgroundTransparency then Win:SetBackgroundTransparency(S.uiAlpha) end
        refreshConfigStatus()
        notify("Config loaded", "'" .. S.configName .. "' is applied", "good", 3)
    end)}
    settings:Button{Title = "Delete config", Callback = guard("delete", function()
        local ok, why = deleteConfig(S.configName)
        notify(ok and "Config deleted" or "Not deleted", ok and "The next start is clean" or tostring(why), ok and "good" or "warn", 3)
        if ok then refreshConfigList() end
    end)}
    settings:Button{Title = "Refresh the list", Callback = guard("refresh", refreshConfigList)}
    settings:Section("Help")
    settings:Button{Title = "Copy the log (for a bug report)", Callback = guard("copy log", function()
        local text = #LOG > 0 and table.concat(LOG, "\n") or "no errors logged"
        if Cap.clipboard and pcall(setclipboard, text) then notify("Log copied", #LOG .. " lines", "good", 2) else notify("Log", LOG[#LOG] or "empty", "info", 6) end
    end)}
    settings:Button{Title = "Unload the script", Desc = "Removes the window and every tech", Callback = guard("unload", function() Hub.Destroy() end)}

    ------------------------------------------------------------------------------------------ the live panel
    do
        local acc, last = 0, ""
        track(RunService.Heartbeat:Connect(function(dt)
            acc = acc + dt
            if acc < 0.25 then return end
            acc = 0
            samplePing()
            if not Win.Main.Visible then return end
            local f, sd = lab:dashLeft("forward"), lab:dashLeft("side")
            local n = lab:netInfo()
            local text = string.format("Forward dash: %s   |   Side dash: %s\nPing %s ms (jitter %.0f)   |   my animations arrive %s after my input   |   other players are led by %.0f ms",
                f > 0 and string.format("%.1f s", f) or "ready", sd > 0 and string.format("%.1f s", sd) or "ready", n.ping and string.format("%.0f", n.ping) or "?", n.jitter,
                n.lag and string.format("%.0f ms", n.lag * 1000) or string.format("not measured yet (%d of 3 samples)", n.samples), n.lead * 1000)
            if text ~= last then
                last = text
                local a, b = text:match("^(.-)\n(.*)$")
                cooldownLabel:Set(a); pingLabel:Set(b)
            end
        end))
    end

    refreshConfigStatus()
    Win:SelectTab("Overview")
    ready = true
    notify("Wraith's TSB Lab loaded", "33 techs, all off. Nothing was run in the real game: use Learn trigger if one does not react.", "good", 5)
end

local ok, err = xpcall(__run, function(e) return debug.traceback(tostring(e), 2) end)
if not ok and not tostring(err):find("__unloaded__", 1, true) then
    warn("[Wraith's TSB Lab] failed to start: " .. tostring(err))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Wraith's TSB Lab failed to start", Text = tostring(err):sub(1, 180), Duration = 20})
    end)
end
