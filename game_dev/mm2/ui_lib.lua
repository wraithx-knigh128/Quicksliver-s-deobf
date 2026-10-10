--[[ Wraith UI: a compact WindUI / RuzHub-style window for executors (no external downloads).
  Header (logo, title, red minimise / maximise / close glyphs), sidebar (search box, collapsible tab group with icons), content rows
  (section header, toggle, slider, dropdown, keybind, button, label), round avatar, toasts, a floating hub pill that re-opens the window,
  draggable floating action buttons, five themes, and an animated grey-white "water wave" skin that every button wears.
  Usage:
    local win = UILib.new{Title = "Wraith's Hub", Subtitle = "...", Group = "Wraith's Hub", Parent = guiParent, ToggleKey = Enum.KeyCode.RightShift, Theme = "Crimson", OnError = fn}
    local tab = win:Tab("Main", "grid")          -- icons: grid eye crosshair user dots gear terminal bolt
    tab:Section("Round")                         -- bold header row
    tab:Toggle{Title = "ESP", Desc = "...", Default = false, Flag = "esp", Callback = function(on) end}
    tab:Slider{Title = "Speed", Min = 16, Max = 80, Default = 16, Step = 1, Suffix = " sps", Flag = "speed", Callback = function(v) end}
    tab:Dropdown{Title = "Target", Values = {"A", "B"}, Default = "A", Flag = "target", Callback = function(v) end}
    tab:Keybind{Title = "Aim key", Default = "Z", Flag = "aimKey", Callback = function() end, Changed = function(name) end}
    tab:Button{Title = "Do it", Desc = "...", Label = "Run", Callback = function() end}
    tab:Label("text")                            -- :Set(text) later
    win:Notify{Title = "Hi", Content = "...", Duration = 3, Type = "info" | "good" | "warn" | "bad"}
    local f = win:Floating{Id = "shoot", Title = "SHOOT", Icon = "crosshair", Pos = {0.82, 0.22}, Size = 72, OnPress = function() return true, "ok" end, OnMoved = function(fx, fy) end}
    win:SetWaveMode("High" | "Low" | "Off")
  Every element has :Set(value, silent) and .Value; elements with a Flag are collected by win:GetState() / win:SetState(t). ]]
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

UILib.WaveLayers = WAVE_LAYERS
UILib.WaveSequences = waveSequences

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
            Active = false, ZIndex = o.ZIndex or 1}, host)
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


    if cfg.Headless then
        -- the pieces other window libraries borrow (wave skins, floating buttons, theme names): no window of its own
        function win:SetTheme(name) if THEMES[name] then themeName, T = name, THEMES[name] end end
        function win:GetTheme() return themeName end
        function win:Destroy()
            if not win.Alive then return end
            win.Alive = false
            for _, c in ipairs(win.Connections) do pcall(function() c:Disconnect() end) end
            win.Connections = {}
            skins = {}
            if floatGui then pcall(function() floatGui:Destroy() end) end
        end
        return win
    end

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
