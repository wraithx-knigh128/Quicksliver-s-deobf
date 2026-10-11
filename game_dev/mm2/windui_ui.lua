--[[ WindUI backend for Wraith's Hub: gives the hub the same window API as ui_lib.lua, but the window, tabs, toggles, sliders, dropdowns, keybinds, buttons and
  notifications are the real WindUI (Footagesus/WindUI, MIT - see mm2/vendor). The floating Perfect Shoot / Throw buttons and their water-wave skin stay ours:
  they come from a headless ui_lib core (UILib.new{Headless = true}), so they live in their own ScreenGui and survive the menu being closed.
    local win = Adapter.new(WindUILib, UILib, {Title = ..., Subtitle = ..., Group = ..., Parent = gui, GuiName = ..., Theme = "Dark", WaveMode = "High", ToggleKey = Enum.KeyCode.RightShift,
                                                  OnError = fn, Folder = "WraithsHub", Background = "https://.../clip.mp4", BackgroundDim = 0.45})
    win:Tab(name, iconKind) / tab:Section / Label / Toggle / Slider / Dropdown / Keybind / Button / Input   (same fields as ui_lib.lua), win:Notify, win:Floating, ...
  Window background: a video (.mp4 / .webm) or picture link is downloaded once, kept in the executor's workspace folder and shown the way WindUI shows its own
  `Background` option (a VideoFrame / ImageLabel inside the window's background), with a dim layer on top so the menu text stays readable. ]]
local Adapter = {}

Adapter.ThemeNames = {"Dark", "Crimson", "Violet", "Sky", "Emerald", "Amber", "Midnight", "Rose", "Monokai Pro", "Cotton Candy"}
local OLD_THEMES = {Ocean = "Sky", Gold = "Amber"}                       -- names the classic menu used

local ICONS = {grid = "layout-grid", eye = "eye", crosshair = "crosshair", bolt = "zap", user = "user", gear = "settings", terminal = "terminal", dots = "ellipsis",
    knife = "sword", pistol = "crosshair", spark = "sparkles", search = "search"}
local TAB_COLORS = {grid = "#7775F2", eye = "#10C550", crosshair = "#EF4F1D", bolt = "#257AF7", user = "#ECA201", gear = "#83889E", terminal = "#83889E"}
local NOTE_ICONS = {good = "check", warn = "triangle-alert", bad = "circle-x", info = "info"}

local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end

function Adapter.themeFor(name)
    name = OLD_THEMES[name] or name
    for _, n in ipairs(Adapter.ThemeNames) do if n == name then return n end end
    return "Dark"
end

-- tiny string hash for cache file names
local function hashOf(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return string.format("%08x", h)
end

local VIDEO_EXT = {mp4 = true, webm = true, mov = true}
local IMAGE_EXT = {png = true, jpg = true, jpeg = true, webp = true}
local function extensionOf(url)
    local path = url:match("^([^?#]+)") or url
    local e = path:match("%.(%w+)$")
    return e and e:lower() or nil
end

-- the hub asks for a link; a pixabay.com video PAGE is turned into the file link inside it (best effort: the site may refuse automated requests)
local function pickPixabayFile(html)
    local found = {}
    for url in html:gmatch("https://cdn%.pixabay%.com/[%w%-%._/%%]+%.mp4") do found[#found + 1] = url end
    for _, size in ipairs({"_medium", "_small", "_large", "_tiny"}) do
        for _, url in ipairs(found) do if url:find(size, 1, true) then return url end end
    end
    return found[1]
end

local function build(win, WindUI, UILib, cfg)
    local UIS = game:GetService("UserInputService")
    local coreDestroy = win.Destroy
    local connect, safe = win.Connect, win.Safe
    win.Flags, win.Tabs, win.Elements = {}, {}, {}
    win.Backend = "WindUI"
    local onError = cfg.OnError or function() end

    local function viewport()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize
        if not vp or vp.X < 100 then return Vector2.new(1280, 720) end
        return vp
    end

    ---------------------------------------------------------------------------------------------- the window
    -- Small and clean, like the reference: Mac-style close button, no search bar / version tag / user card / minimise / fullscreen, tabs straight in the sidebar.
    local themeName = Adapter.themeFor(cfg.Theme)
    local vp = viewport()
    local size = UDim2.fromOffset(clamp(math.floor(vp.X * 0.6), 440, 560), clamp(vp.Y - 70, 250, 380))      -- WindUI scales the window down by itself if it does not fit
    win.Tickers = win.Tickers or {}
    local glassTouched = {}

    -- frosted cards: every theme's element background becomes translucent grey (the backdrop shows through), and each card fades out towards the right
    local function glass(name)
        local t = WindUI.Themes and WindUI.Themes[name]
        if t and not glassTouched[name] then
            glassTouched[name] = true
            t.ElementBackgroundTransparency = math.max(t.ElementBackgroundTransparency or 0, 0.42)
        end
    end
    glass(themeName)

    local Window = WindUI:CreateWindow{
        Title = cfg.Title or "Hub", Author = cfg.Subtitle, Folder = cfg.Folder or "WraithsHub", Icon = "swords", NewElements = true, Theme = themeName,
        Size = size, MinSize = Vector2.new(380, 230), SideBarWidth = vp.X < 900 and 124 or 150, HideSearchBar = true,
        Transparent = true, HidePanelBackground = true, ElementsRadius = 14, Radius = 16, ToggleKey = cfg.ToggleKey,
        Topbar = {Height = 38, ButtonsType = "Mac"},
        User = {Enabled = false},
        OpenButton = {Title = cfg.Title or "Hub", CornerRadius = UDim.new(1, 0), StrokeThickness = 2, Enabled = true, Draggable = true, OnlyMobile = false, Scale = 0.7,
            Color = ColorSequence.new(Color3.fromHex("#9aa0b4"), Color3.fromHex("#e84a8a"))},
    }
    win.Window, win.WindUI = Window, WindUI
    if cfg.Parent and WindUI.SetParent then pcall(function() WindUI:SetParent(cfg.Parent) end) end
    -- WindUI's own topbar "x" does not hide the window: it opens a confirmation dialog ("you will not be able to open it again") and, if confirmed
    -- (or if IgnoreAlerts is set), permanently DESTROYS the window - there is no built-in way to make it a reversible hide. So all three native buttons
    -- are hidden and replaced with one small dot of our own that calls Window:Close() (the *method*, not the topbar button): that hides the window and
    -- leaves WindUI's own open button on screen to bring it back, exactly like tapping the pill in the Classic menu or pressing the toggle key.
    pcall(function() Window:DisableTopbarButtons{"Close", "Minimize", "Fullscreen"} end)
    pcall(function()
        local right = Window.UIElements.Main.Main.Topbar.Right
        local dot = Instance.new("TextButton")
        dot.Name = "WraithClose"
        dot.Text = ""
        dot.AutoButtonColor = false
        dot.BackgroundColor3 = Color3.fromHex("#F4695F")
        dot.BorderSizePixel = 0
        dot.Size = UDim2.fromOffset(14, 14)
        dot.LayoutOrder = 999
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = dot
        dot.Parent = right
        connect(dot.MouseButton1Click, function() Window:Close() end)
    end)
    pcall(function() Window:SetUIScale(clamp(cfg.Scale or 0.9, 0.55, 1.2)) end)
    if cfg.Mono ~= false then                                                -- the reference menu uses a monospace face
        pcall(function()
            local family = Font.fromEnum(Enum.Font.Code).Family
            if type(family) == "string" and family ~= "" then WindUI:SetFont(family) end
        end)
    end
    pcall(function() WindUI:SetTheme(themeName) end)                           -- (re-applies the theme with the frosted element background)

    -- the hub reads win.Main.Visible and sets win.ToggleKey, like with the classic menu
    local toggleKey = cfg.ToggleKey
    local mainProxy = setmetatable({}, {__index = function(_, k) if k == "Visible" then return not Window.Closed end end})
    setmetatable(win, {
        __index = function(_, k)
            if k == "Main" then return mainProxy elseif k == "ToggleKey" then return toggleKey end
        end,
        __newindex = function(t, k, v)
            if k == "ToggleKey" then
                toggleKey = v
                pcall(function() Window:SetToggleKey(v) end)
            else rawset(t, k, v) end
        end,
    })

    ---------------------------------------------------------------------------------------------- elements
    local function addElement(el, flag)
        win.Elements[#win.Elements + 1] = el
        if flag then win.Flags[flag] = el; el.Flag = flag end
        return el
    end
    local function fire(cb, ...) if cb then safe("callback", cb, ...) end end

    local FADE = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.12), NumberSequenceKeypoint.new(1, 0.78)})
    local function decorate(p, ui)                                           -- a card fades out to the right
        pcall(function()
            local host = p.ElementFrame
            if not (host and host:IsA("GuiObject")) then return end
            local g = Instance.new("UIGradient")
            g.Name = "WraithFade"
            g.Transparency = FADE
            g.Parent = host
        end)
    end

    function win:Tab(name, iconKind)
        local ui = Window:Tab{Title = name, Icon = ICONS[iconKind or "dots"] or "circle"}
        local tab = {name = name, ui = ui}
        win.Tabs[#win.Tabs + 1] = tab

        function tab:Section(title)
            return ui:Section{Title = title, TextSize = 18}
        end

        function tab:Label(text)                                          -- body text, the way the official WindUI example writes it: a Section with a small, softer title
            local el = {Value = tostring(text or "")}
            local p = ui:Section{Title = el.Value ~= "" and el.Value or " ", TextSize = 14, TextTransparency = 0.25, FontWeight = Enum.FontWeight.Medium}
            function el:Set(v)
                v = tostring(v)
                if v == el.Value then return end
                el.Value = v
                pcall(function() p:SetTitle(v ~= "" and v or " ") end)
            end
            return el
        end

        function tab:Button(o)
            local el = {Value = nil, Title = o.Title, Click = function() fire(o.Callback) end}
            el.Ui = ui:Button{Title = o.Title or "Button", Desc = o.Desc, Icon = "mouse-pointer-click", Callback = function() fire(o.Callback) end}
            decorate(el.Ui, ui)
            function el:Set() end
            -- the grey water flows round the button's OUTLINE (nothing is drawn inside it); it runs while this tab is open
            local okSkin, skinErr = pcall(function()
                local host = el.Ui.ElementFrame
                local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = host
                el.Outline = win:Outline(host, {Thickness = 1.5, Glow = false, Page = ui.ContainerFrame})
            end)
            if not okSkin then onError("button outline", skinErr) end
            return addElement(el)
        end

        function tab:Toggle(o)
            local el = {Value = o.Default == true}
            local p = ui:Toggle{Title = o.Title or "Toggle", Desc = o.Desc, Value = el.Value, Callback = function(v)
                if v == el.Value then return end                      -- WindUI also reports the value we just set ourselves
                el.Value = v == true
                fire(o.Callback, el.Value)
            end}
            function el:Set(v, silent)
                v = v == true
                local changed = v ~= el.Value
                el.Value = v
                pcall(function() p:Set(v) end)
                if not silent and (changed or o.FireSame) then fire(o.Callback, v) end
            end
            el.Title, el.Ui = o.Title, p
            decorate(p, ui)
            addElement(el, o.Flag)
            if el.Value and o.Callback and not o.NoInitialCallback then fire(o.Callback, true) end
            return el
        end

        function tab:Slider(o)
            local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
            local decimals = step < 1 and (step < 0.1 and 2 or 1) or 0
            local function snap(v)
                v = clamp(v, min, max)
                v = min + math.floor((v - min) / step + 0.5) * step
                return clamp(tonumber(string.format("%." .. decimals .. "f", v)), min, max)
            end
            local el = {Value = snap(o.Default or min)}
            local unit = o.Suffix and o.Suffix:match("%S") and o.Suffix:gsub("^%s+", "") or nil
            local p = ui:Slider{Title = o.Title or "Slider", Desc = unit and ("in " .. unit) or nil, Step = step, IsTooltip = true,
                Value = {Min = min, Max = max, Default = el.Value}, Callback = function(v)
                    if type(v) ~= "number" then return end
                    v = snap(v)
                    if v == el.Value then return end
                    el.Value = v
                    fire(o.Callback, v)
                end}
            function el:Set(v, silent)
                if type(v) ~= "number" then return end
                v = snap(v)
                local changed = v ~= el.Value
                el.Value = v
                pcall(function() p:Set(v) end)
                if not silent and changed then fire(o.Callback, v) end
            end
            el.Title, el.Ui = o.Title, p
            decorate(p, ui)
            addElement(el, o.Flag)
            return el
        end

        function tab:Dropdown(o)
            local el = {Value = o.Default, Values = o.Values or {}}
            if el.Value == nil then el.Value = el.Values[1] end
            local p
            p = ui:Dropdown{Title = o.Title or "Dropdown", Desc = o.Desc, Values = el.Values, Value = el.Value, AllowNone = false, Callback = function(v)
                if type(v) == "table" then v = v.Title end
                if v == nil or v == el.Value then return end
                el.Value = v
                fire(o.Callback, v)
            end}
            function el:Set(v, silent)
                local changed = v ~= el.Value
                el.Value = v
                pcall(function() p:Select(v) end)
                if not silent and changed then fire(o.Callback, v) end
            end
            function el:SetValues(values)
                el.Values = values
                pcall(function() p:Refresh(values) end)
            end
            el.Title, el.Ui = o.Title, p
            decorate(p, ui)
            return addElement(el, o.Flag)
        end

        function tab:Input(o)
            local el = {Value = o.Default or ""}
            local p = ui:Input{Title = o.Title or "Input", Desc = o.Desc, Value = el.Value, Placeholder = o.Placeholder or "", Type = "Input", Callback = function(v)
                v = tostring(v or "")
                if v == el.Value then return end
                el.Value = v
                fire(o.Callback, v)
            end}
            function el:Set(v, silent)
                v = tostring(v or "")
                local changed = v ~= el.Value
                el.Value = v
                pcall(function() p:Set(v) end)
                if not silent and changed then fire(o.Callback, v) end
            end
            el.Title, el.Ui = o.Title, p
            decorate(p, ui)
            return addElement(el, o.Flag)
        end

        function tab:Keybind(o)
            local el = {Value = o.Default or "None", Down = false}
            local p = ui:Keybind{Title = o.Title or "Keybind", Desc = o.Desc, Value = el.Value ~= "None" and el.Value or "F", Callback = function() end}
            local label
            pcall(function() label = p.UIElements.Keybind.Frame.Frame.TextLabel end)
            if label then
                connect(label:GetPropertyChangedSignal("Text"), function()
                    local t = label.Text
                    if t ~= "..." and t ~= el.Value then
                        el.Value = t
                        if o.Changed then fire(o.Changed, t) end
                    end
                end)
            end
            function el:Set(v, silent)
                el.Value = type(v) == "string" and v or "None"
                pcall(function() p:Set(el.Value == "None" and "F" or el.Value) end)
                if not silent and o.Changed then fire(o.Changed, el.Value) end
            end
            -- WindUI only reports presses; the hub also needs "is it held" (aim assist), so it listens for the key itself
            connect(UIS.InputBegan, function(input, processed)
                if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
                if input.KeyCode.Name == el.Value and not UIS:GetFocusedTextBox() then
                    el.Down = true
                    if o.Callback and (not processed or o.IgnoreProcessed) then fire(o.Callback) end
                end
            end)
            connect(UIS.InputEnded, function(input)
                if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == el.Value then el.Down = false end
            end)
            el.Title, el.Ui = o.Title, p
            decorate(p, ui)
            return addElement(el, o.Flag)
        end

        return tab
    end

    ---------------------------------------------------------------------------------------------- notifications, theme, state
    function win:Notify(o)
        if not win.Alive then return end
        safe("notify", function()
            WindUI:Notify{Title = o.Title or "", Content = o.Content or "", Duration = o.Duration or 3, Icon = NOTE_ICONS[o.Type or "info"] or "info"}
        end)
    end
    function win:SetTheme(name)
        name = Adapter.themeFor(name)
        themeName = name
        glass(name)
        pcall(function() WindUI:SetTheme(name) end)
    end
    function win:GetTheme() return themeName end
    function win:SetAvatar() end                                           -- WindUI shows the player's own avatar and name (User option)
    function win:SelectTab(name)                                              -- WindUI shows no tab until one is selected, so the hub selects the first one
        for i, t in ipairs(win.Tabs) do
            if t.name == name or i == name then pcall(function() Window:SelectTab(i) end); return end
        end
    end
    function win:SetVisible(v) if v then Window:Open() else Window:Close() end end
    function win:Toggle() Window:Toggle() end
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
    win.SetTheme(win, themeName)

    ---------------------------------------------------------------------------------------------- window background (video / picture)
    local function folder() return (cfg.Folder or "WraithsHub") .. "/assets" end

    -- executors' request() looks like a browser (some sites turn Roblox's own HttpGet away); HttpGet is the fallback
    local function httpGet(url)
        local req = request or http_request or (syn and syn.request)
        local lastErr
        if req then
            local headers = {["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36", ["Accept"] = "*/*"}
            if url:find("pixabay.com", 1, true) then headers["Referer"] = "https://pixabay.com/" end
            local ok, res = pcall(req, {Url = url, Method = "GET", Headers = headers})
            if ok and type(res) == "table" and (res.StatusCode == nil or res.StatusCode == 200) and type(res.Body) == "string" and res.Body ~= "" then return res.Body end
            lastErr = ok and ("HTTP " .. tostring(type(res) == "table" and res.StatusCode or res)) or tostring(res)
        end
        if game.HttpGet then return game:HttpGet(url) end
        error(lastErr or "no HttpGet / request in this executor")
    end

    -- resolves a link to something a VideoFrame / ImageLabel can show: returns kind ("video" | "image"), asset
    local function resolveMedia(url)
        if url:find("^rbxassetid://") or url:find("^rbxasset://") then return "image", url end
        local ext = extensionOf(url)
        local kind = VIDEO_EXT[ext] and "video" or IMAGE_EXT[ext] and "image" or nil
        if url:find("^https?://[%w%.]*pixabay%.com/videos/") then
            local html = httpGet(url)
            local file = pickPixabayFile(html)
            if not file then error("no video file link found on that Pixabay page (the site may block automated requests) - paste the direct .mp4 link instead") end
            url, ext, kind = file, "mp4", "video"
        end
        if not kind then error("unsupported link: it must end in .mp4 / .webm / .png / .jpg") end
        if not (writefile and isfile and getcustomasset) then error("this executor has no writefile / getcustomasset, so a downloaded background cannot be shown") end
        if makefolder and isfolder then
            for _, dir in ipairs({cfg.Folder or "WraithsHub", folder()}) do
                if not isfolder(dir) then pcall(makefolder, dir) end
            end
        end
        local path = string.format("%s/bg_%s.%s", folder(), hashOf(url), ext)
        if not isfile(path) then writefile(path, httpGet(url)) end
        return kind, getcustomasset(path)
    end

    ---------------------------------------------------------------------------------------------- outline water, transparent inside
    -- The inside of the window stays transparent. The grey water-flow texture lives only on OUTLINES: the window's border (here) and the borders of the buttons (above).
    local bgLayer = Window.UIElements and Window.UIElements.Main and Window.UIElements.Main:FindFirstChild("Background")
    local radius = Window.UICorner or 16
    local function rounded(f, r) local c = Instance.new("UICorner"); c.CornerRadius = r or UDim.new(0, radius); c.Parent = f; return c end
    do
        local frame = Instance.new("Frame")
        frame.Name = "WraithOutline"
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.Active = false
        frame.ZIndex = 100
        rounded(frame)
        frame.Parent = Window.UIElements.Main
        win.WindowOutline = win:Outline(frame, {Thickness = 2, Global = true, Speed = 24, Active = function() return not Window.Closed end})
    end
    pcall(function() Window:SetBackgroundTransparency(clamp(cfg.WindowAlpha or 0.5, 0, 0.9)) end)      -- a see-through window
    function win:SetBackgroundTransparency(v) pcall(function() Window:SetBackgroundTransparency(clamp(tonumber(v) or 0.5, 0, 0.9)) end) end

    local dimFrame
    if bgLayer then
        dimFrame = Instance.new("Frame")
        dimFrame.Name = "WraithDim"
        dimFrame.Size = UDim2.new(1, 0, 1, 0)
        dimFrame.BackgroundColor3 = Color3.fromRGB(6, 6, 12)
        dimFrame.BackgroundTransparency = 1
        dimFrame.BorderSizePixel = 0
        dimFrame.Active = false
        dimFrame.ZIndex = 9
        dimFrame.Visible = false
        rounded(dimFrame)
        dimFrame.Parent = bgLayer
    end
    local backdrop = {media = nil, Dim = clamp(cfg.BackgroundDim or 0.35, 0, 0.9), Url = nil, Token = 0}
    local function refreshBackdrop()                                          -- the dim layer only exists while a picture / video is showing
        if dimFrame then
            dimFrame.Visible = backdrop.media ~= nil
            dimFrame.BackgroundTransparency = 1 - clamp(backdrop.Dim, 0, 0.9)
        end
    end
    refreshBackdrop()

    local function clearMedia()
        if backdrop.media then pcall(function() backdrop.media:Destroy() end); backdrop.media = nil end
    end
    function win:SetBackgroundDim(v) backdrop.Dim = clamp(tonumber(v) or backdrop.Dim, 0, 0.9); refreshBackdrop() end
    function win:SetScale(v) pcall(function() Window:SetUIScale(clamp(tonumber(v) or 0.9, 0.55, 1.2)) end) end

    -- url == nil or "" removes the picture / video. Async: the download happens in a task; `done(ok, message)` is called when it is over.
    function win:SetBackground(url, done)
        backdrop.Token = backdrop.Token + 1
        local token = backdrop.Token
        url = type(url) == "string" and url:gsub("^%s+", ""):gsub("%s+$", "") or ""
        if url == "" then
            clearMedia(); backdrop.Url = nil; refreshBackdrop()
            if done then done(true, "removed") end
            return
        end
        task.spawn(function()
            local ok, kindOrErr, asset = pcall(resolveMedia, url)
            if token ~= backdrop.Token or not win.Alive then return end
            if not ok then
                onError("background", tostring(kindOrErr))
                if done then done(false, tostring(kindOrErr)) end
                return
            end
            if not bgLayer then if done then done(false, "the window has no background layer") end return end
            clearMedia()
            if kindOrErr == "video" then
                backdrop.media = Instance.new("VideoFrame")
                backdrop.media.Name = "WraithVideo"
                backdrop.media.Video = asset
                backdrop.media.Looped = true
                backdrop.media.Volume = 0
            else
                backdrop.media = Instance.new("ImageLabel")
                backdrop.media.Name = "WraithPicture"
                backdrop.media.Image = asset
                backdrop.media.ScaleType = Enum.ScaleType.Crop
            end
            backdrop.media.BackgroundTransparency = 1
            backdrop.media.BorderSizePixel = 0
            backdrop.media.Size = UDim2.new(1, 0, 1, 0)
            backdrop.media.ZIndex = 2
            rounded(backdrop.media)
            backdrop.media.Parent = bgLayer
            backdrop.Url = url
            if kindOrErr == "video" then pcall(function() backdrop.media:Play() end) end
            refreshBackdrop()
            if done then done(true, kindOrErr) end
        end)
    end
    if cfg.Background and cfg.Background ~= "" then win:SetBackground(cfg.Background, cfg.OnBackground) end

    ---------------------------------------------------------------------------------------------- teardown
    function win:Destroy()
        if not win.Alive then return end
        backdrop.Token = backdrop.Token + 1
        coreDestroy()                                                       -- (also marks the window dead and removes the floating buttons)
        clearMedia()
        pcall(function() Window:Destroy() end)
        for _, key in ipairs({"ScreenGui", "NotificationGui", "DropdownGui", "TooltipGui"}) do
            local g = WindUI[key]
            if g then pcall(function() g:Destroy() end) end
        end
    end

    return win
end

-- builds the window; if anything goes wrong half way, what was already made is removed again and the error is raised (the hub then falls back to the classic menu)
function Adapter.new(WindUI, UILib, cfg)
    -- the headless core brings the water-wave skin and the floating buttons (and the Connect / Safe helpers)
    local win = UILib.new{Headless = true, Parent = cfg.Parent, GuiName = cfg.GuiName, Theme = "Crimson", WaveMode = cfg.WaveMode, OnError = cfg.OnError}
    local ok, err = pcall(build, win, WindUI, UILib, cfg)
    if not ok then
        pcall(function() if rawget(win, "Window") then win.Window:Destroy() end end)
        pcall(function() win.Alive = true; win:Destroy() end)
        for _, key in ipairs({"ScreenGui", "NotificationGui", "DropdownGui", "TooltipGui"}) do
            local g = WindUI[key]
            if g then pcall(function() g:Destroy() end) end
        end
        error(err, 0)
    end
    return win
end

return Adapter
