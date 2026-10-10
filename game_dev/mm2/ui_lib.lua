--[[ Compact WindUI / RuzHub-style window for executors (no external downloads).
  Sidebar with tabs + search box, rows (toggle, slider, dropdown, keybind, button, label), toast notifications,
  round avatar, minimise / maximise / hide, floating re-open button for phones, five colour themes.
  Usage:
    local win = UILib.new{Title = "MM2 Hub", Subtitle = "...", Parent = someGuiParent, ToggleKey = Enum.KeyCode.RightShift, Theme = "Crimson", OnError = function(where, err) end}
    local tab = win:Tab("Main")
    tab:Section("Round")
    tab:Toggle{Title = "ESP", Desc = "...", Default = false, Flag = "esp", Callback = function(on) end}
    tab:Slider{Title = "Speed", Min = 16, Max = 80, Default = 16, Step = 1, Suffix = " sps", Flag = "speed", Callback = function(v) end}
    tab:Dropdown{Title = "Target", Values = {"A", "B"}, Default = "A", Flag = "target", Callback = function(v) end}
    tab:Keybind{Title = "Aim key", Default = "Z", Flag = "aimKey", Callback = function() end}     -- Callback runs when the key is pressed
    tab:Button{Title = "Do it", Desc = "...", Callback = function() end}
    tab:Label("text")                                                                          -- :Set(text) later
    win:Notify{Title = "Hi", Content = "...", Duration = 4, Type = "info" | "good" | "warn" | "bad"}
  Every element has :Set(value, silent) and .Value; elements with a Flag are collected by win:GetState() / win:SetState(t). ]]
local UILib = {}

local THEMES = {
    Crimson = {bg = {11, 11, 15}, side = {15, 15, 21}, row = {21, 21, 29}, rowHover = {30, 30, 41}, stroke = {42, 42, 55}, text = {236, 236, 243},
               sub = {140, 140, 158}, accent = {228, 54, 68}, accent2 = {255, 110, 120}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {64, 64, 82}},
    Ocean = {bg = {9, 13, 20}, side = {12, 18, 28}, row = {18, 27, 41}, rowHover = {26, 38, 57}, stroke = {36, 52, 76}, text = {232, 240, 250},
             sub = {131, 150, 176}, accent = {52, 152, 255}, accent2 = {120, 195, 255}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {58, 72, 96}},
    Emerald = {bg = {9, 15, 13}, side = {12, 21, 18}, row = {18, 31, 27}, rowHover = {26, 44, 38}, stroke = {36, 62, 54}, text = {232, 247, 240},
               sub = {128, 160, 146}, accent = {46, 204, 113}, accent2 = {120, 235, 170}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {56, 84, 74}},
    Violet = {bg = {13, 10, 20}, side = {18, 13, 29}, row = {26, 19, 41}, rowHover = {37, 27, 58}, stroke = {55, 40, 84}, text = {242, 236, 252},
              sub = {154, 138, 184}, accent = {155, 89, 255}, accent2 = {196, 150, 255}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {76, 62, 104}},
    Gold = {bg = {14, 12, 8}, side = {20, 17, 11}, row = {30, 25, 16}, rowHover = {42, 35, 22}, stroke = {66, 55, 34}, text = {250, 244, 230},
            sub = {171, 158, 128}, accent = {240, 178, 40}, accent2 = {255, 214, 100}, good = {78, 205, 124}, warn = {250, 190, 60}, bad = {240, 80, 80}, off = {88, 76, 52}},
}
UILib.ThemeNames = {"Crimson", "Ocean", "Emerald", "Violet", "Gold"}

local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end

function UILib.new(cfg)
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")

    local win = {Flags = {}, Tabs = {}, Elements = {}, Connections = {}, Alive = true}
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
    local function stroke(inst, key)
        local s = mk("UIStroke", {Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, inst)
        bind(s, "Color", key or "stroke")
        return s
    end
    local function tween(inst, props, secs)
        local ok = pcall(function()
            TweenService:Create(inst, TweenInfo.new(secs or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
        end)
        if not ok then for k, v in pairs(props) do pcall(function() inst[k] = v end) end end
    end

    ---------------------------------------------------------------------------------------------- window frame
    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local W = clamp(vp.X - 24, 340, 640)
    local H = clamp(vp.Y - 24, 250, 410)
    local SIDE = W < 520 and 132 or 172
    local TOP = 46
    local bigW, bigH = clamp(vp.X - 40, 340, 900), clamp(vp.Y - 40, 250, 600)

    local gui = mk("ScreenGui", {Name = cfg.GuiName or "UILibWindow", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true, DisplayOrder = 50}, nil)
    win.Gui = gui

    local main = mk("Frame", {Name = "Window", Size = UDim2.fromOffset(W, H), Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
        BorderSizePixel = 0, ClipsDescendants = true}, gui)
    bind(main, "BackgroundColor3", "bg")
    corner(main, 12); stroke(main)
    win.Main = main

    local side = mk("Frame", {Name = "Sidebar", Size = UDim2.new(0, SIDE, 1, 0), BorderSizePixel = 0}, main)
    bind(side, "BackgroundColor3", "side"); corner(side, 12)
    local sideFill = mk("Frame", {Position = UDim2.new(1, -14, 0, 0), Size = UDim2.new(0, 14, 1, 0), BorderSizePixel = 0}, side)   -- squares the inner edge
    bind(sideFill, "BackgroundColor3", "side")
    local sideEdge = mk("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BorderSizePixel = 0}, side)
    bind(sideEdge, "BackgroundColor3", "stroke")

    local logo = mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(1, -20, 0, 20), Text = cfg.Title or "Hub",
        Font = Enum.Font.GothamBold, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left}, side)
    bind(logo, "TextColor3", "text")
    local subtitle = mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 29), Size = UDim2.new(1, -20, 0, 14), Text = cfg.Subtitle or "",
        Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, side)
    bind(subtitle, "TextColor3", "sub")
    local accentLine = mk("Frame", {Position = UDim2.new(0, 14, 0, 48), Size = UDim2.new(0, 34, 0, 3), BorderSizePixel = 0}, side)
    bind(accentLine, "BackgroundColor3", "accent"); corner(accentLine, "full")

    local searchBox = mk("Frame", {Position = UDim2.new(0, 10, 0, 60), Size = UDim2.new(1, -20, 0, 30), BorderSizePixel = 0}, side)
    bind(searchBox, "BackgroundColor3", "row"); corner(searchBox, 8); stroke(searchBox)
    local search = mk("TextBox", {BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -16, 1, 0), Text = "", PlaceholderText = "Search...",
        ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left}, searchBox)
    bind(search, "TextColor3", "text"); bind(search, "PlaceholderColor3", "sub")

    local tabList = mk("ScrollingFrame", {Position = UDim2.new(0, 0, 0, 98), Size = UDim2.new(1, 0, 1, -104), BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0}, side)
    mk("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, tabList)
    mk("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, tabList)

    local top = mk("Frame", {Name = "Topbar", Position = UDim2.new(0, SIDE, 0, 0), Size = UDim2.new(1, -SIDE, 0, TOP), BackgroundTransparency = 1}, main)
    local pageTitle = mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(1, -190, 1, 0), Text = "",
        Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left}, top)
    bind(pageTitle, "TextColor3", "text")

    local function ctlButton(text, offsetFromRight)
        local b = mk("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -offsetFromRight, 0.5, 0), Size = UDim2.fromOffset(26, 26),
            Text = text, Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = false, BorderSizePixel = 0}, top)
        bind(b, "BackgroundColor3", "row"); bind(b, "TextColor3", "sub"); corner(b, 7); stroke(b)
        return b
    end
    local btnClose = ctlButton("X", 10)
    local btnMax = ctlButton("+", 42)
    local btnMin = ctlButton("-", 74)
    local avatar = mk("ImageLabel", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -108, 0.5, 0), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 0,
        BorderSizePixel = 0, Image = ""}, top)
    bind(avatar, "BackgroundColor3", "row"); corner(avatar, "full")
    local avatarRing = stroke(avatar, "accent"); avatarRing.Thickness = 2

    local content = mk("Frame", {Name = "Content", Position = UDim2.new(0, SIDE, 0, TOP), Size = UDim2.new(1, -SIDE, 1, -TOP), BackgroundTransparency = 1, ClipsDescendants = true}, main)
    local scroll = mk("ScrollingFrame", {Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -20, 1, -10), BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y}, content)
    bind(scroll, "ScrollBarImageColor3", "accent")
    mk("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
    mk("UIPadding", {PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, scroll)
    win.Scroll = scroll

    -- floating re-open button (phones have no keyboard shortcut)
    local fab = mk("TextButton", {Name = "Open", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(42, 42), Text = "M",
        Font = Enum.Font.GothamBold, TextSize = 18, AutoButtonColor = false, BorderSizePixel = 0, Visible = false}, gui)
    bind(fab, "BackgroundColor3", "accent"); bind(fab, "TextColor3", "text"); corner(fab, "full")

    ---------------------------------------------------------------------------------------------- dragging
    local function makeDraggable(handle, target)
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
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
    end
    makeDraggable(top, main)
    makeDraggable(side, main)

    ---------------------------------------------------------------------------------------------- tabs, search
    local currentTab
    local function selectTab(tab)
        currentTab = tab
        for _, t in ipairs(win.Tabs) do
            local on = t == tab
            t.page.Visible = on
            t.bar.Visible = on
            tween(t.button, {BackgroundTransparency = on and 0 or 1}, 0.12)
            t.button.TextColor3 = rgb(on and T.text or T.sub)
        end
        pageTitle.Text = tab and tab.name or ""
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
        pageTitle.Text = "Search results"
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
        end
    end
    connect(search:GetPropertyChangedSignal("Text"), function() safe("search", applySearch) end)

    function win:Tab(name)
        local tab = {name = name, entries = {}, order = 0}
        local button = mk("TextButton", {Name = name, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "   " .. name, Font = Enum.Font.GothamMedium,
            TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = #win.Tabs + 1}, tabList)
        bind(button, "BackgroundColor3", "row"); bind(button, "TextColor3", "sub"); corner(button, 8)
        local bar = mk("Frame", {Position = UDim2.new(0, 0, 0.5, -9), Size = UDim2.new(0, 3, 0, 18), BorderSizePixel = 0, Visible = false}, button)
        bind(bar, "BackgroundColor3", "accent"); corner(bar, "full")
        local page = mk("Frame", {Name = name, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            Visible = false, LayoutOrder = #win.Tabs + 1}, scroll)
        mk("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, page)
        local heading = mk("TextLabel", {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = string.upper(name), Font = Enum.Font.GothamBold, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, Visible = false, LayoutOrder = 0}, page)
        bind(heading, "TextColor3", "accent")
        tab.button, tab.bar, tab.page, tab.heading = button, bar, page, heading
        win.Tabs[#win.Tabs + 1] = tab
        connect(button.MouseButton1Click, function()
            if (search.Text or "") ~= "" then search.Text = "" end
            selectTab(tab)
        end)
        if #win.Tabs == 1 then selectTab(tab) end

        local function nextOrder() tab.order = tab.order + 1; return tab.order end
        local function register(frame, key, isSection)
            local entry = {frame = frame, key = (key or ""):lower(), isSection = isSection, hits = 0}
            tab.entries[#tab.entries + 1] = entry
            return entry
        end
        local function fire(cb, ...) if cb then safe("callback", cb, ...) end end

        local function newRow(height, title, desc, rightPad)
            local row = mk("Frame", {Size = UDim2.new(1, 0, 0, height), BorderSizePixel = 0, LayoutOrder = nextOrder()}, page)
            bind(row, "BackgroundColor3", "row"); corner(row, 8); stroke(row)
            local t = mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, desc and 6 or 0), Size = UDim2.new(1, -(rightPad or 20) - 14, 0, desc and 18 or height),
                Text = title or "", Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, row)
            bind(t, "TextColor3", "text")
            if desc then
                local d = mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 25), Size = UDim2.new(1, -(rightPad or 20) - 14, 0, 16), Text = desc,
                    Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, row)
                bind(d, "TextColor3", "sub")
            end
            register(row, (title or "") .. " " .. (desc or ""))
            return row, t
        end
        local function addElement(el, flag)
            win.Elements[#win.Elements + 1] = el
            if flag then win.Flags[flag] = el; el.Flag = flag end
            return el
        end

        function tab:Section(title)
            local lbl = mk("TextLabel", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = string.upper(title), Font = Enum.Font.GothamBold, TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder()}, page)
            bind(lbl, "TextColor3", "sub")
            mk("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 6)}, lbl)
            register(lbl, title, true)
            return lbl
        end

        function tab:Label(text)
            local row = mk("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = nextOrder()}, page)
            bind(row, "BackgroundColor3", "row"); corner(row, 8); stroke(row)
            mk("UIPadding", {PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, row)
            local lbl = mk("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text or "",
                Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, row)
            bind(lbl, "TextColor3", "sub")
            local entry = register(row, text)
            local el = {Value = text}
            function el:Set(v) el.Value = tostring(v); lbl.Text = el.Value; entry.key = el.Value:lower() end
            return el
        end

        function tab:Button(o)
            local row = newRow(o.Desc and 48 or 40, o.Title, o.Desc, 60)
            local pill = mk("TextLabel", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(44, 22), Text = o.Label or "Run",
                Font = Enum.Font.GothamBold, TextSize = 11, BorderSizePixel = 0}, row)
            bind(pill, "BackgroundColor3", "accent"); bind(pill, "TextColor3", "text"); corner(pill, 6)
            local hit = mk("TextButton", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", AutoButtonColor = false}, row)
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
            local row = newRow(o.Desc and 48 or 40, o.Title, o.Desc, 64)
            local sw = mk("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(38, 20), BorderSizePixel = 0}, row)
            corner(sw, "full")
            local knob = mk("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0}, sw)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); corner(knob, "full")
            local hit = mk("TextButton", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", AutoButtonColor = false}, row)
            local el = {Value = o.Default == true}
            local function render()
                tween(sw, {BackgroundColor3 = rgb(el.Value and T.accent or T.off)}, 0.12)
                tween(knob, {Position = UDim2.new(0, el.Value and 21 or 3, 0.5, 0)}, 0.12)
            end
            el.render = render
            function el:Set(v, silent)
                v = v == true
                local changed = v ~= el.Value
                el.Value = v; render()
                if not silent and (changed or o.FireSame) then fire(o.Callback, v) end
            end
            sw.BackgroundColor3 = rgb(el.Value and T.accent or T.off)
            knob.Position = UDim2.new(0, el.Value and 21 or 3, 0.5, 0)
            connect(hit.MouseButton1Click, function() el:Set(not el.Value) end)
            addElement(el, o.Flag)
            if el.Value and o.Callback and not o.NoInitialCallback then fire(o.Callback, true) end
            return el
        end

        function tab:Slider(o)
            local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
            local row = newRow(56, o.Title, nil, 90)
            local valueLabel = mk("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8), Size = UDim2.fromOffset(86, 18),
                Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Text = ""}, row)
            bind(valueLabel, "TextColor3", "accent2")
            local track = mk("Frame", {Position = UDim2.new(0, 14, 0, 38), Size = UDim2.new(1, -28, 0, 6), BorderSizePixel = 0}, row)
            bind(track, "BackgroundColor3", "off"); corner(track, "full")
            local fill = mk("Frame", {Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0}, track)
            bind(fill, "BackgroundColor3", "accent"); corner(fill, "full")
            local knob = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0}, track)
            knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); corner(knob, "full")
            local hit = mk("TextButton", {BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 0, 30), Text = "", AutoButtonColor = false}, row)
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
            local holder = mk("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder()}, page)
            mk("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, holder)
            local head = mk("Frame", {Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0, LayoutOrder = 1}, holder)
            bind(head, "BackgroundColor3", "row"); corner(head, 8); stroke(head)
            local title = mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.5, -14, 1, 0), Text = o.Title or "", Font = Enum.Font.GothamMedium,
                TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, head)
            bind(title, "TextColor3", "text")
            local current = mk("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 0), Size = UDim2.new(0.5, -20, 1, 0), Text = "",
                Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd}, head)
            bind(current, "TextColor3", "accent2")
            local hit = mk("TextButton", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", AutoButtonColor = false}, head)
            local list = mk("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, LayoutOrder = 2}, holder)
            mk("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, list)
            mk("UIPadding", {PaddingLeft = UDim.new(0, 10)}, list)
            register(holder, (o.Title or "") .. " " .. table.concat(o.Values or {}, " "))
            local el = {Value = o.Default, Values = o.Values or {}}
            local buttons = {}
            local function paint()
                current.Text = tostring(el.Value or "-")
                for _, b in ipairs(buttons) do
                    b.inst.TextColor3 = rgb(b.value == el.Value and T.accent2 or T.text)
                end
            end
            local function rebuild()
                for _, b in ipairs(buttons) do b.inst:Destroy() end
                buttons = {}
                for i, v in ipairs(el.Values) do
                    local b = mk("TextButton", {Size = UDim2.new(1, 0, 0, 30), Text = "  " .. tostring(v), Font = Enum.Font.GothamMedium, TextSize = 13,
                        TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i}, list)
                    bind(b, "BackgroundColor3", "rowHover"); corner(b, 6)
                    buttons[#buttons + 1] = {inst = b, value = v}
                    connect(b.MouseButton1Click, function() el:Set(v); list.Visible = false end)
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
            connect(hit.MouseButton1Click, function() list.Visible = not list.Visible end)
            addElement(el, o.Flag)
            return el
        end

        function tab:Keybind(o)
            local row = newRow(40, o.Title, o.Desc, 110)
            local btn = mk("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(86, 24), Text = "",
                Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0}, row)
            bind(btn, "BackgroundColor3", "rowHover"); bind(btn, "TextColor3", "accent2"); corner(btn, 6); stroke(btn)
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
                btn.Text = el.Value
                if not silent and o.Changed then fire(o.Changed, el.Value) end
            end
            btn.Text = el.Value
            connect(btn.MouseButton1Click, function() capturing = true; btn.Text = "press a key" end)
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
    local toasts = mk("Frame", {Name = "Toasts", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.new(0, 290, 1, -28),
        BackgroundTransparency = 1}, gui)
    mk("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right}, toasts)
    local toastCount = 0
    function win:Notify(o)
        if not win.Alive then return end
        toastCount = toastCount + 1
        local kind = o.Type == "good" and "good" or o.Type == "warn" and "warn" or o.Type == "bad" and "bad" or "accent"
        local card = mk("Frame", {Size = UDim2.fromOffset(280, o.Content and 58 or 40), BorderSizePixel = 0, BackgroundTransparency = 1, LayoutOrder = toastCount}, toasts)
        bind(card, "BackgroundColor3", "side"); corner(card, 10)
        local edge = stroke(card, kind)
        local bar = mk("Frame", {Size = UDim2.new(0, 4, 1, -16), Position = UDim2.new(0, 8, 0, 8), BorderSizePixel = 0}, card)
        bind(bar, "BackgroundColor3", kind); corner(bar, "full")
        local t = mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 22, 0, o.Content and 6 or 0), Size = UDim2.new(1, -30, 0, o.Content and 20 or 40),
            Text = o.Title or "", Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, card)
        bind(t, "TextColor3", "text")
        local c
        if o.Content then
            c = mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.new(0, 22, 0, 26), Size = UDim2.new(1, -30, 0, 28), Text = o.Content, Font = Enum.Font.Gotham,
                TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, card)
            bind(c, "TextColor3", "sub")
        end
        tween(card, {BackgroundTransparency = 0}, 0.2)
        task.delay(o.Duration or 4, function()
            if not card.Parent then return end
            tween(card, {BackgroundTransparency = 1}, 0.25)
            tween(t, {TextTransparency = 1}, 0.25)
            if c then tween(c, {TextTransparency = 1}, 0.25) end
            tween(bar, {BackgroundTransparency = 1}, 0.25)
            tween(edge, {Transparency = 1}, 0.25)
            task.delay(0.3, function() if card.Parent then card:Destroy() end end)
        end)
    end

    ---------------------------------------------------------------------------------------------- window state
    local expanded = false
    local minimized = false
    local function layoutSize()
        local w, h = expanded and bigW or W, expanded and bigH or H
        if minimized then h = TOP end
        main.Size = UDim2.fromOffset(w, h)
        side.Visible = not minimized
        content.Visible = not minimized
    end
    function win:SetVisible(v)
        main.Visible = v
        fab.Visible = not v
    end
    function win:Toggle() win:SetVisible(not main.Visible) end
    function win:Minimize() minimized = not minimized; layoutSize() end
    function win:Maximize() expanded = not expanded; if expanded then minimized = false end; layoutSize() end
    connect(btnClose.MouseButton1Click, function()
        win:SetVisible(false)
        win:Notify{Title = "Menu hidden", Content = "Tap the M button" .. (win.ToggleKey and (" or press " .. win.ToggleKey.Name) or "") .. " to open it again.", Duration = 3}
    end)
    connect(btnMin.MouseButton1Click, function() win:Minimize() end)
    connect(btnMax.MouseButton1Click, function() win:Maximize() end)
    connect(fab.MouseButton1Click, function() win:SetVisible(true) end)
    win.ToggleKey = cfg.ToggleKey
    connect(UIS.InputBegan, function(input, processed)
        if not processed and win.ToggleKey and input.KeyCode == win.ToggleKey then win:Toggle() end
    end)

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
        pcall(function() gui:Destroy() end)
    end

    layoutSize()
    gui.Parent = cfg.Parent
    return win
end

return UILib
