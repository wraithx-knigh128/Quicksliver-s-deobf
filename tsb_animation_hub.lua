--[[
    Animation Hub - The Strongest Battlegrounds
    Smooth sidebar UI + Auto Tech

    Setup:
      * Background: a random SFW anime image is fetched from waifu.pics / nekos.best.
        NOTE: those are community fan-art images, NOT copyright-free. For art you may
        legally redistribute, set BACKGROUND_URL to your own / CC0 image.
      * Needs request + writefile + getcustomasset for the image; everything else works without them.

    Auto Tech: when you get knocked down / ragdolled it waits a short delay and
    presses the dash key in the chosen direction so you recover instantly.
    Delay / cooldown / direction are adjustable in the "Auto Tech" tab.
]]

local BACKGROUND_URL = ""   -- optional fixed image (direct link). "" = pick one from the waifu API below
local BACKGROUND_SOURCE = "waifu.pics"   -- "waifu.pics" or "nekos.best" (SFW endpoints only)
local BACKGROUND_TRANSPARENCY = 0.55
local GUI_PARENT = "auto"   -- "auto" (gethui, CoreGui, PlayerGui) | "coregui" | "playergui". If the menu never shows, try "playergui".
-- ...or set it before running without editing anything:  getgenv().AH_GUI_PARENT = "playergui"
pcall(function() if getgenv and getgenv().AH_GUI_PARENT then GUI_PARENT = getgenv().AH_GUI_PARENT end end)

-- Your own combos, shown as cards in the character tab. "Instant Twisted" has no published inputs, so
-- add it here once you know them. Tokens: M1 Q FRONTDASH SIDEDASH BACKDASH JUMP or a move name such as
-- FLOWING_WATER / HUNTERS_GRASP (see tsb_data.lua). Example:
--   {name = "Instant Twisted", character = "Hero Hunter", steps = {"M1", "M1", "SIDEDASH", "HUNTERS_GRASP"}},
local CUSTOM_COMBOS = {
}

-- Feedback so you always know how far it got: "Loading" = the script started, "Ready" = the menu was built,
-- a red "error" notification = it failed (and says why). Seeing nothing at all means the executor never ran it
-- (pasted text cut off, or too long) - use the short loadstring link instead of pasting.
local function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = text, Duration = duration or 4})
    end)
end
print("[Animation Hub] starting")
notify("Animation Hub", "Loading...", 3)

if not game:IsLoaded() then game.Loaded:Wait() end

local function __run()
    ---------------------------------------------------------------- services
    local Players           = game:GetService("Players")
    local RunService        = game:GetService("RunService")
    local TweenService      = game:GetService("TweenService")
    local UserInputService  = game:GetService("UserInputService")
    local VirtualInput      = game:GetService("VirtualInputManager")
    local CoreGui           = game:GetService("CoreGui")

    local LocalPlayer = Players.LocalPlayer

    ---------------------------------------------------------------- helpers
    local function safe(fn, ...)
        local ok, res = pcall(fn, ...)
        if ok then return res end
    end

    local function guiParent()
        if GUI_PARENT == "playergui" then return LocalPlayer:WaitForChild("PlayerGui") end
        if GUI_PARENT == "coregui" then return CoreGui end
        local p = safe(function() return gethui() end)
        if p then return p end
        p = safe(function() return CoreGui end)
        if p and safe(function() return #p:GetChildren() end) then return p end
        return LocalPlayer:WaitForChild("PlayerGui")   -- always allowed, works on any executor
    end

    local function tween(obj, props, t, style, dir)
        local tw = TweenService:Create(obj, TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
        tw:Play()
        return tw
    end

    local function new(class, props, children)
        local inst = Instance.new(class)
        for k, v in pairs(props or {}) do inst[k] = v end
        for _, c in ipairs(children or {}) do c.Parent = inst end
        return inst
    end

    local function corner(r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}) end
    local function stroke(color, thick, trans)
        return new("UIStroke", {Color = color, Thickness = thick or 1, Transparency = trans or 0})
    end

    local loadBackground
    do
    local httpRequest = request or http_request or (syn and syn.request)
    local function httpGet(url)
        if httpRequest then
            local res = safe(httpRequest, {Url = url, Method = "GET"})
            if res and (res.StatusCode == 200 or (res.StatusCode == nil and res.Success)) and type(res.Body) == "string" then
                return res.Body
            end
        end
        local body = safe(function() return game:HttpGet(url) end)
        if type(body) == "string" then return body end
    end

    local BgSources = {
        ["waifu.pics"] = {api = "https://api.waifu.pics/sfw/waifu", parse = function(j) return j.url end},
        ["nekos.best"] = {api = "https://nekos.best/api/v2/waifu", parse = function(j) return j.results and j.results[1] and j.results[1].url end},
    }
    local bgCounter = 0

    -- identify the real file type from its first bytes (Roblox can only show png/jpg; this also
    -- rejects gif/webp and HTML error pages that would otherwise be saved as "images")
    local function imageKind(body)
        if type(body) ~= "string" or #body < 16 or #body > 12 * 1024 * 1024 then return nil end
        if body:sub(1, 8) == "\137PNG\r\n\26\n" then return "png" end
        if body:sub(1, 3) == "\255\216\255" then return "jpg" end
    end

    -- download one image url -> executor asset id
    local function imageToAsset(url)
        if type(url) ~= "string" or url:sub(1, 4) ~= "http" then return nil end
        local body = httpGet(url)
        local kind = imageKind(body)
        if not kind then return nil end
        bgCounter = bgCounter + 1
        local path = ("animation_hub_bg_%d.%s"):format(bgCounter, kind)
        -- writefile returns nothing on success, so test with pcall (NOT safe(), which returns the value)
        if not pcall(writefile, path, body) then return nil end
        return safe(getcustomasset, path)
    end

    function loadBackground(sourceName)
        if not (getcustomasset and writefile) then return nil end   -- executor cannot show downloaded files
        if BACKGROUND_URL ~= "" and not sourceName then
            local fixed = imageToAsset(BACKGROUND_URL)
            if fixed then return fixed end                            -- else fall through to the API
        end
        local src = BgSources[sourceName or BACKGROUND_SOURCE] or BgSources["waifu.pics"]
        for _ = 1, 4 do                                               -- retry: the API may hand back a gif/webp
            local raw = httpGet(src.api)
            local data = raw and safe(function() return game:GetService("HttpService"):JSONDecode(raw) end)
            local url = type(data) == "table" and safe(src.parse, data)
            local asset = imageToAsset(url)
            if asset then return asset end
        end
    end

    end

    ---------------------------------------------------------------- saved settings (loaded first: the theme needs them)
    local genv = safe(function() return getgenv() end) or _G
    local SETTINGS_FILE = "animation_hub_settings.json"
    local function loadSaved()
        if not (isfile and readfile) then return {} end
        local raw = safe(function() if isfile(SETTINGS_FILE) then return readfile(SETTINGS_FILE) end end)
        if type(raw) ~= "string" or raw == "" then return {} end
        local data = safe(function() return game:GetService("HttpService"):JSONDecode(raw) end)
        return type(data) == "table" and data or {}
    end
    local function num(v, lo, hi, default)
        if type(v) ~= "number" or v ~= v then return default end
        return math.min(math.max(v, lo), hi)
    end
    local Saved = loadSaved()

    ---------------------------------------------------------------- theme
    -- menu look: saved in the file, or (executors without files) kept in memory for the rebuild
    local UiSaved = type(genv.__AnimationHubUi) == "table" and genv.__AnimationHubUi
        or (type(Saved.ui) == "table" and Saved.ui) or {}
    local Themes = {
        ["Rose Gold"] = {Back = {30, 20, 46}, Panel = {54, 38, 78}, Item = {76, 56, 106}, Hover = {98, 74, 136},
            Accent = {255, 112, 176}, Accent2 = {160, 112, 255}, Gold = {255, 214, 150}, WinA = {104, 62, 142}, WinB = {34, 22, 56}},
        ["Ocean"] = {Back = {14, 26, 46}, Panel = {26, 48, 84}, Item = {38, 68, 112}, Hover = {54, 92, 146},
            Accent = {90, 200, 255}, Accent2 = {124, 140, 255}, Gold = {196, 242, 255}, WinA = {40, 98, 156}, WinB = {12, 24, 50}},
        ["Violet"] = {Back = {24, 16, 48}, Panel = {46, 32, 90}, Item = {66, 48, 124}, Hover = {90, 68, 160},
            Accent = {190, 120, 255}, Accent2 = {255, 120, 220}, Gold = {255, 222, 255}, WinA = {94, 60, 174}, WinB = {28, 18, 62}},
        ["Emerald"] = {Back = {12, 32, 30}, Panel = {24, 58, 54}, Item = {34, 82, 74}, Hover = {48, 106, 96},
            Accent = {90, 235, 170}, Accent2 = {90, 190, 255}, Gold = {222, 255, 204}, WinA = {36, 112, 98}, WinB = {10, 30, 30}},
        ["Sunset"] = {Back = {42, 18, 30}, Panel = {78, 34, 54}, Item = {106, 50, 72}, Hover = {132, 68, 92},
            Accent = {255, 140, 90}, Accent2 = {255, 100, 150}, Gold = {255, 228, 164}, WinA = {152, 60, 82}, WinB = {46, 18, 32}},
    }
    local ThemeNames = {"Rose Gold", "Ocean", "Violet", "Emerald", "Sunset"}
    local themeName = Themes[UiSaved.theme] and UiSaved.theme or "Rose Gold"
    local pendingTheme = themeName                    -- picked in Effects Preset; applied by "Apply theme"
    local uiScale = num(UiSaved.scale, 0.7, 1.25, 1)  -- menu size
    local glass = num(UiSaved.glass, 0.4, 0.95, 0.72) -- how see-through the dark veil over the picture is
    local TH = Themes[themeName]
    local function rgb(c) return Color3.fromRGB(c[1], c[2], c[3]) end
    local Theme = {
        Back = rgb(TH.Back), Panel = rgb(TH.Panel), Item = rgb(TH.Item), Hover = rgb(TH.Hover),
        Accent = rgb(TH.Accent), Accent2 = rgb(TH.Accent2), Gold = rgb(TH.Gold),
        Text     = Color3.fromRGB(252, 246, 254),
        SubText  = Color3.fromRGB(200, 182, 218),
        Good     = Color3.fromRGB(120, 235, 175),
        White    = Color3.fromRGB(255, 255, 255),
    }
    local function accentGradient(parent, rotation)
        return new("UIGradient", {Color = ColorSequence.new(Theme.Accent, Theme.Accent2), Rotation = rotation or 0, Parent = parent})
    end
    local function hairline(parent, transparency)     -- subtle glass border
        return new("UIStroke", {Color = Theme.White, Thickness = 1, Transparency = transparency or 0.9, Parent = parent})
    end
    -- shiny sweep: a soft diagonal highlight that glides across a surface; call the returned function to play it
    local function sheen(parent, radius)
        local grad = new("UIGradient", {
            Rotation = 25, Offset = Vector2.new(-1, 0),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.5, 0.78),
                NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1),
            }),
        })
        new("Frame", {
            Name = "Sheen", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.White, BorderSizePixel = 0, ZIndex = 0, Parent = parent,
        }, {new("UICorner", {CornerRadius = UDim.new(0, radius or 12)}), grad})
        return function()
            grad.Offset = Vector2.new(-1, 0)
            tween(grad, {Offset = Vector2.new(1, 0)}, 0.7, Enum.EasingStyle.Quad)
        end
    end
    -- glossy sheen: a white film that is strongest at the top edge and fades out (the "glass" look)
    local function gloss(parent, radius, strength)
        local top = 0.80 + (1 - (strength or 1)) * 0.2          -- strength 1 = brightest sheen
        return new("Frame", {
            Name = "Gloss", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.White, BorderSizePixel = 0,
            ZIndex = 0, Parent = parent,
        }, {
            new("UICorner", {CornerRadius = UDim.new(0, radius or 12)}),
            new("UIGradient", {
                Rotation = 90,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, top), NumberSequenceKeypoint.new(0.5, 0.96), NumberSequenceKeypoint.new(1, 1),
                }),
                Parent = nil,
            }),
        })
    end

    ---------------------------------------------------------------- cleanup old
    -- re-running the script must not leave the old copy's listeners (Auto Tech, predictor...) alive
    if type(genv.__AnimationHubCleanup) == "function" then pcall(genv.__AnimationHubCleanup) end
    local old = guiParent():FindFirstChild("AnimationHubTSB")
    if old then old:Destroy() end

    ---------------------------------------------------------------- window
    local Gui = new("ScreenGui", {
        Name = "AnimationHubTSB", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
    })
    Gui.DisplayOrder = 999999          -- above the game's own UI
    Gui.Parent = guiParent()
    if not Gui.Parent then Gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end   -- the chosen container refused it

    -- every global listener goes through connect() so cleanup() can remove it
    local alive, conns, onCleanup = true, {}, {}
    local function connect(signal, fn)
        local c = signal:Connect(fn)
        conns[#conns + 1] = c
        return c
    end
    local function cleanup()
        if not alive then return end
        alive = false
        for _, f in ipairs(onCleanup) do pcall(f) end
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        pcall(function() Gui:Destroy() end)
        if genv.__AnimationHubCleanup == cleanup then genv.__AnimationHubCleanup = nil end
    end
    genv.__AnimationHubCleanup = cleanup

    -- fit small phone screens: never taller/wider than the viewport
    local function viewport()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize
        if vp and type(vp.X) == "number" and type(vp.Y) == "number" and vp.X > 0 and vp.Y > 0 then return vp.X, vp.Y end
    end
    local WIN_W, WIN_H = 600, 390
    do
        local vw, vh = viewport()
        if vw then
            WIN_W = math.max(360, math.min(WIN_W, vw - 24))
            WIN_H = math.max(240, math.min(WIN_H, vh - 24))
        end
    end
    local COMPACT = WIN_W < 500                 -- narrow screens: icon-only sidebar
    local SIDE_W = COMPACT and 58 or 168

    -- the whole window is a CanvasGroup so it can fade and scale as one piece
    local Main = new("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0),     -- top edge stays put when minimising / opening
        Size = UDim2.fromOffset(WIN_W, WIN_H), Position = UDim2.new(0.5, 0, 0.5, -WIN_H / 2),
        BackgroundColor3 = Theme.Back, BorderSizePixel = 0, GroupTransparency = 1,
        Parent = Gui,
    }, {corner(18)})
    local function fitScale()           -- the menu size the user asked for, never bigger than the screen
        local vw, vh = viewport()
        if not vw then return uiScale end
        return math.max(0.5, math.min(uiScale, (vw - 8) / WIN_W, (vh - 8) / WIN_H))
    end
    local MainScale = new("UIScale", {Scale = 0.92 * fitScale(), Parent = Main})
    local MainStroke = stroke(Theme.White, 1.6, 0.15)
    MainStroke.Parent = Main
    local BorderGrad = new("UIGradient", {      -- gold -> accent -> accent2 rim that slowly rotates
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Gold), ColorSequenceKeypoint.new(0.5, Theme.Accent), ColorSequenceKeypoint.new(1, Theme.Accent2),
        }),
        Rotation = 45, Parent = MainStroke,
    })

    -- background: tinted gradient, optional image, and a dark veil so text stays readable
    new("UIGradient", {
        Color = ColorSequence.new(rgb(TH.WinA), rgb(TH.WinB)),
        Rotation = 60, Parent = Main,
    })
    local Background = new("ImageLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "",
        ScaleType = Enum.ScaleType.Crop, ImageTransparency = BACKGROUND_TRANSPARENCY,
        ZIndex = 0, Parent = Main,
    })
    local Veil = new("Frame", {                      -- dark veil over the picture (the "Glass" slider)
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Back, BackgroundTransparency = glass,
        BorderSizePixel = 0, ZIndex = 0, Parent = Main,
    })
    gloss(Main, 18, 1)
    local bgGen = 0
    local function refreshBackground(sourceName)
        bgGen = bgGen + 1
        local mine = bgGen                       -- only the newest request may set the image
        task.spawn(function()
            local asset = loadBackground(sourceName)
            if asset and mine == bgGen and alive then
                Background.Image = asset
                Background.ImageTransparency = 1                 -- fade the new picture in
                tween(Background, {ImageTransparency = BACKGROUND_TRANSPARENCY}, 0.8)
            end
        end)
    end
    refreshBackground()

    local toast
    do
    -- toast: a small message that slides up from the bottom (pins, errors, confirmations)
    local Toast = new("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40),
        Size = UDim2.fromOffset(280, 38), BackgroundColor3 = Theme.Panel, GroupTransparency = 1, ZIndex = 50, Parent = Gui,
    }, {corner(12), hairline(nil, 0.6), gloss(nil, 12, 1)})
    local ToastText = new("TextLabel", {
        Text = "", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text, BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), TextTruncate = Enum.TextTruncate.AtEnd, Parent = Toast,
    })
    local toastId = 0
    function toast(text)
        toastId = toastId + 1
        local mine = toastId
        ToastText.Text = tostring(text)
        Toast.Position = UDim2.new(0.5, 0, 1, -22)
        tween(Toast, {GroupTransparency = 0, Position = UDim2.new(0.5, 0, 1, -40)}, 0.3)
        task.spawn(function()
            task.wait(1.9)
            if mine == toastId and alive then
                tween(Toast, {GroupTransparency = 1, Position = UDim2.new(0.5, 0, 1, -28)}, 0.3)
            end
        end)
    end

    end

    -- title bar
    local pingPill                                   -- small live ping readout, filled in by the ping block
    local TopBar = new("Frame", {Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, Parent = Main})
    local Title = new("TextLabel", {
        Text = "Animation Hub", Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = Theme.White,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 9), Size = UDim2.new(1, -230, 0, 22), Parent = TopBar,
    })
    local TitleGrad = new("UIGradient", {
        Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.Gold), ColorSequenceKeypoint.new(1, Theme.Accent)}),
        Parent = Title,
    })
    new("TextLabel", {
        Text = "The Strongest Battlegrounds", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 31), Size = UDim2.new(1, -230, 0, 16), Parent = TopBar,
    })
    pingPill = new("TextLabel", {
        Text = "-- ms", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Good,
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.3,
        Size = UDim2.fromOffset(64, 24), Position = UDim2.new(1, -176, 0, 16), Parent = TopBar,
    }, {corner(12), hairline(nil, 0.85)})
    new("Frame", {                                   -- divider under the title bar
        Size = UDim2.new(1, -32, 0, 1), Position = UDim2.new(0, 16, 1, 0), BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = TopBar,
    })

    local function topButton(text, xOff, hoverColor, cb)
        local b = new("TextButton", {
            Text = text, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text,
            BackgroundColor3 = Theme.Item, BackgroundTransparency = 0.4, AutoButtonColor = false,
            Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, xOff, 0, 12), Parent = TopBar,
        }, {corner(16)})
        b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = hoverColor, BackgroundTransparency = 0.1}, 0.15) end)
        b.MouseLeave:Connect(function() tween(b, {BackgroundColor3 = Theme.Item, BackgroundTransparency = 0.4}, 0.2) end)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    -- show / hide the menu with a fade + scale (RightShift on PC, the floating bar on touch devices)
    local menuOpen, menuTok = true, 0
    local renderFab   -- assigned by the floating bar further down
    local function setMenu(v)
        menuOpen = v and true or false
        menuTok = menuTok + 1
        local mine = menuTok
        if menuOpen then
            Main.Visible = true
            tween(Main, {GroupTransparency = 0}, 0.25)
            tween(MainScale, {Scale = fitScale()}, 0.4, Enum.EasingStyle.Back)
        else
            tween(Main, {GroupTransparency = 1}, 0.18)
            tween(MainScale, {Scale = 0.94 * fitScale()}, 0.18)
            task.spawn(function()
                task.wait(0.2)
                if mine == menuTok and alive then Main.Visible = false end
            end)
        end
        if renderFab then renderFab() end
    end
    local function toggleMenu() setMenu(not menuOpen) end

    do
    local minimized = false
    local fullSize = UDim2.fromOffset(WIN_W, WIN_H)
    topButton("-", -84, Theme.Hover, function()
        minimized = not minimized
        tween(Main, {Size = minimized and UDim2.fromOffset(WIN_W, 57) or fullSize}, 0.35, Enum.EasingStyle.Quint)
    end)
    topButton("X", -44, Color3.fromRGB(200, 70, 100), function()
        tween(Main, {GroupTransparency = 1}, 0.2)
        tween(MainScale, {Scale = 0.9}, 0.2)
        task.spawn(function() task.wait(0.24); cleanup() end)
    end)

    end

    -- dragging (keeps the title bar on screen)
    do
        local dragging, dragStart, startPos = false, nil, nil
        local function isPointer(i)
            return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
        end
        TopBar.InputBegan:Connect(function(i)
            if isPointer(i) then
                dragging, dragStart, startPos = true, i.Position, Main.Position
            end
        end)
        connect(UserInputService.InputEnded, function(i)
            if isPointer(i) then dragging = false end
        end)
        connect(UserInputService.InputChanged, function(i)
            if not dragging then return end
            if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
            local d = i.Position - dragStart
            local ox, oy = startPos.X.Offset + d.X, startPos.Y.Offset + d.Y
            local vw, vh = viewport()
            if vw then
                local mx = vw / 2 + WIN_W / 2 - 60
                ox = math.clamp(ox, -mx, mx)
                oy = math.clamp(oy, -vh / 2, vh / 2 - 52)       -- title bar always reachable
            end
            Main.Position = UDim2.new(startPos.X.Scale, ox, startPos.Y.Scale, oy)
        end)
    end

    connect(UserInputService.InputBegan, function(i, gp)
        if not gp and i.KeyCode == Enum.KeyCode.RightShift then toggleMenu() end
    end)

    ---------------------------------------------------------------- sidebar / pages
    new("Frame", {                                   -- frosted glass panel behind the sidebar
        Position = UDim2.fromOffset(6, 60), Size = UDim2.new(0, SIDE_W + 2, 1, -124),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.45, BorderSizePixel = 0,
    }, {corner(16), hairline(nil, 0.84), gloss(nil, 16, 0.9)}).Parent = Main
    local Sidebar = new("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 62), Size = UDim2.new(0, SIDE_W, 1, -126),
        BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(), BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = Main,
    }, {
        new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
        new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6)}),
    })

    local Content = new("Frame", {
        Position = UDim2.fromOffset(SIDE_W + 6, 62), Size = UDim2.new(1, -(SIDE_W + 20), 1, -76),
        BackgroundTransparency = 1, Parent = Main,
    })

    -- footer: player card
    do
    local Card = new("Frame", {
        Position = UDim2.new(0, 8, 1, -58), Size = UDim2.fromOffset(SIDE_W - 16, 46),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.2, Parent = Main,
    }, {corner(12), hairline(nil, 0.8), gloss(nil, 12, 1)})
    local avatar = new("ImageLabel", {
        Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(7, 7),
        BackgroundColor3 = Theme.Item, Parent = Card,
    }, {corner(16)})
    if not COMPACT then
        new("TextLabel", {
            Text = LocalPlayer.DisplayName, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Text,
            BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(46, 6), Size = UDim2.new(1, -52, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left, Parent = Card,
        })
        new("TextLabel", {
            Text = "@" .. LocalPlayer.Name, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Theme.SubText,
            BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(46, 23), Size = UDim2.new(1, -52, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Left, Parent = Card,
        })
    end
    task.spawn(function()
        local img = safe(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        if img then avatar.Image = img end
    end)

    end

    local Tabs, currentTab, sideOrder = {}, nil, 0

    -- small caps divider in the sidebar ("CHARACTERS", "TOOLS" ...)
    local function sideHeader(text)
        sideOrder = sideOrder + 1
        if COMPACT then
            new("Frame", {Size = UDim2.new(1, 0, 0, 8), BackgroundTransparency = 1, LayoutOrder = sideOrder, Parent = Sidebar})
            return
        end
        new("TextLabel", {
            Text = text, Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Theme.SubText, TextTransparency = 0.25,
            TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 24), LayoutOrder = sideOrder, Parent = Sidebar,
        }, {new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 8)})})
    end

    local function createTab(name, icon)
        sideOrder = sideOrder + 1
        local btn = new("TextButton", {
            Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Item, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 38), LayoutOrder = sideOrder, Parent = Sidebar,
        }, {corner(12)})
        local tile = new("Frame", {
            Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(COMPACT and 11 or 8, 6),
            BackgroundColor3 = Theme.Panel, Parent = btn,
        }, {corner(9)})
        local tileText = new("TextLabel", {
            Text = icon, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.SubText,
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = tile,
        })
        local text = new("TextLabel", {
            Text = name, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -46, 1, 0), Visible = not COMPACT, Parent = btn,
        })
        local bar = new("Frame", {
            Size = UDim2.fromOffset(3, 0), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = btn,
        }, {corner(2)})

        -- each page is a CanvasGroup (fades / slides in) holding a scrolling list
        local group = new("CanvasGroup", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, GroupTransparency = 1, Parent = Content,
        })
        local page = new("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent, ScrollBarImageTransparency = 0.3,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0,
            Parent = group,
        }, {
            new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
            new("UIPadding", {PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10)}),
        })

        local tab = {Btn = btn, Bar = bar, Page = group, tok = 0}
        local function paint(active)
            tween(btn, {BackgroundTransparency = active and 0.35 or 1}, 0.25)
            tween(text, {TextColor3 = active and Theme.Text or Theme.SubText}, 0.25)
            tween(tileText, {TextColor3 = active and Theme.Back or Theme.SubText}, 0.25)
            tween(tile, {BackgroundColor3 = active and Theme.Accent or Theme.Panel}, 0.25)
            tween(bar, {Size = UDim2.fromOffset(3, active and 22 or 0)}, 0.3, Enum.EasingStyle.Back)
        end
        function tab:Select()
            if currentTab == tab then return end
            local prev = currentTab
            currentTab = tab
            if prev then prev:Hide() end
            tab.tok = tab.tok + 1
            group.Visible = true
            group.Position = UDim2.fromOffset(0, 16)
            group.GroupTransparency = 1
            tween(group, {Position = UDim2.fromOffset(0, 0), GroupTransparency = 0}, 0.3)
            paint(true)
        end
        function tab:Hide()
            paint(false)
            tab.tok = tab.tok + 1
            local mine = tab.tok
            tween(group, {GroupTransparency = 1}, 0.12)
            task.spawn(function()
                task.wait(0.14)
                if tab.tok == mine and currentTab ~= tab then group.Visible = false end   -- not re-selected meanwhile
            end)
        end
        btn.MouseButton1Click:Connect(function() tab:Select() end)
        local sweepTab = sheen(btn, 12)
        btn.MouseEnter:Connect(function()
            sweepTab()
            if currentTab ~= tab then tween(btn, {BackgroundTransparency = 0.7}, 0.15) end
        end)
        btn.MouseLeave:Connect(function() if currentTab ~= tab then tween(btn, {BackgroundTransparency = 1}, 0.2) end end)

        -- elements ------------------------------------------------------
        local function row(height, parent)
            return new("Frame", {
                Size = UDim2.new(1, 0, 0, height or 44), BackgroundColor3 = Theme.Item,
                BackgroundTransparency = 0.28, Parent = parent or page,
            }, {corner(12), hairline(nil, 0.82), gloss(nil, 12, 0.8)})
        end
        local function label(parent, text, size, color, pos, font)
            return new("TextLabel", {
                Text = text, Font = font or Enum.Font.GothamMedium, TextSize = size or 13,
                TextColor3 = color or Theme.Text, BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                Position = pos or UDim2.fromOffset(14, 0), Size = UDim2.new(1, -90, 1, 0), Parent = parent,
            })
        end
        local function isPointer(i)
            return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
        end

        -- wrapped text that grows with its content
        function tab:Label(text, parent)
            return new("TextLabel", {
                Text = text, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText,
                TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent or page,
            }, {new("UIPadding", {
                PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2),
            })})
        end

        -- an on/off switch, used by Toggle rows and by the "On screen" switch on combo cards
        local function makeSwitch(parent, position, width, height)
            local track = new("Frame", {
                Size = UDim2.fromOffset(width, height), Position = position, BackgroundColor3 = Theme.Panel, Parent = parent,
            }, {corner(height / 2), hairline(nil, 0.85)})
            local pad = 3
            local knobSize = height - pad * 2
            local knob = new("Frame", {
                Size = UDim2.fromOffset(knobSize, knobSize), Position = UDim2.fromOffset(pad, pad),
                BackgroundColor3 = Theme.Text, Parent = track,
            }, {corner(knobSize / 2)})
            local sw = {}
            function sw.render(on, animate)
                local t = animate and 0.28 or 0
                tween(track, {BackgroundColor3 = on and Theme.Accent or Theme.Panel}, t)
                tween(knob, {Position = on and UDim2.fromOffset(width - knobSize - pad, pad) or UDim2.fromOffset(pad, pad)},
                    t, Enum.EasingStyle.Back)
            end
            return sw
        end

        function tab:Toggle(text, default, cb, parent, subtitle)
            local r = row(subtitle and 58 or 44, parent)
            local main = label(r, text)
            if subtitle then
                main.Position = UDim2.fromOffset(14, 7)
                main.Size = UDim2.new(1, -90, 0, 22)
                new("TextLabel", {
                    Text = subtitle, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.SubText,
                    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
                    TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(14, 29), Size = UDim2.new(1, -90, 0, 24), Parent = r,
                })
            end
            local state = default and true or false
            local sw = makeSwitch(r, UDim2.new(1, -60, 0.5, -12), 46, 24)
            sw.render(state, false)
            -- the whole row is the hit area (the switch alone is too small for a finger)
            local hit = new("TextButton", {Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.fromScale(1, 1), Parent = r})
            local api = {}
            function api:Get() return state end
            function api:Set(v)
                v = v and true or false
                if v == state then return end
                state = v
                sw.render(state, true)
                task.spawn(cb, state)
            end
            hit.MouseButton1Click:Connect(function() api:Set(not state) end)
            hit.MouseEnter:Connect(function() tween(r, {BackgroundTransparency = 0.2}, 0.15) end)
            hit.MouseLeave:Connect(function() tween(r, {BackgroundTransparency = 0.35}, 0.2) end)
            task.spawn(cb, state)
            return api
        end

        function tab:Button(text, cb, parent)
            local r = row(42, parent)
            local b = new("TextButton", {
                Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text,
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, AutoButtonColor = false, Parent = r,
            })
            b.MouseEnter:Connect(function() tween(r, {BackgroundTransparency = 0.15}, 0.15) end)
            b.MouseLeave:Connect(function() tween(r, {BackgroundTransparency = 0.35}, 0.2) end)
            b.MouseButton1Click:Connect(function()
                tween(r, {BackgroundColor3 = Theme.Accent}, 0.1).Completed:Connect(function()
                    tween(r, {BackgroundColor3 = Theme.Item}, 0.3)
                end)
                task.spawn(cb)
            end)
        end

        function tab:Slider(text, min, max, default, step, cb, parent)
            assert(max > min and step > 0, "Slider: need max > min and step > 0")
            local r = row(60, parent)
            label(r, text, 13, Theme.Text, UDim2.fromOffset(14, 6)).Size = UDim2.new(1, -90, 0, 22)
            local val = new("TextLabel", {
                Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Text, BackgroundColor3 = Theme.Panel,
                Position = UDim2.new(1, -72, 0, 6), Size = UDim2.fromOffset(58, 22), Parent = r,
            }, {corner(8)})
            local rail = new("Frame", {
                Position = UDim2.new(0, 16, 1, -22), Size = UDim2.new(1, -32, 0, 8), BackgroundColor3 = Theme.Panel, Parent = r,
            }, {corner(4)})
            local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.White, BorderSizePixel = 0, Parent = rail}, {corner(4)})
            accentGradient(fill, 0)
            local knob = new("Frame", {
                Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
                BackgroundColor3 = Theme.White, ZIndex = 3, Parent = rail,
            }, {corner(9), stroke(Theme.Accent, 2, 0)})
            local touch = new("TextButton", {            -- generous invisible hit area for fingers
                Text = "", BackgroundTransparency = 1, AutoButtonColor = false,
                Position = UDim2.new(0, -8, 0.5, -16), Size = UDim2.new(1, 16, 0, 32), Parent = rail,
            })
            local function set(v, fire)
                v = math.floor((v - min) / step + 0.5) * step + min       -- snap relative to min
                v = math.clamp(tonumber(string.format("%.4f", v)), min, max)   -- no float noise in callbacks
                val.Text = tostring(v)
                local frac = (v - min) / (max - min)
                tween(fill, {Size = UDim2.fromScale(frac, 1)}, 0.1, Enum.EasingStyle.Linear)
                tween(knob, {Position = UDim2.new(frac, 0, 0.5, 0)}, 0.1, Enum.EasingStyle.Linear)
                if fire then task.spawn(cb, v) end
            end
            set(default, true)
            local dragging = false
            local function fromInput(i)
                local w = rail.AbsoluteSize.X
                if w <= 0 then return end
                set(min + (max - min) * math.clamp((i.Position.X - rail.AbsolutePosition.X) / w, 0, 1), true)
            end
            touch.InputBegan:Connect(function(i)
                if isPointer(i) then
                    dragging = true
                    tween(knob, {Size = UDim2.fromOffset(22, 22)}, 0.12)
                    fromInput(i)
                end
            end)
            connect(UserInputService.InputEnded, function(i)
                if isPointer(i) and dragging then
                    dragging = false
                    tween(knob, {Size = UDim2.fromOffset(18, 18)}, 0.2, Enum.EasingStyle.Back)
                end
            end)
            connect(UserInputService.InputChanged, function(i)
                if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromInput(i) end
            end)
            local api = {}
            function api:Set(v) set(v, true) end
            return api
        end

        function tab:Dropdown(text, options, default, cb, parent)
            local r = row(44, parent)
            label(r, text)
            local i = table.find(options, default) or 1        -- unknown default -> first option (and show it)
            local b = new("TextButton", {
                Text = options[i], Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Accent,
                BackgroundColor3 = Theme.Panel, AutoButtonColor = false,
                Size = UDim2.fromOffset(112, 30), Position = UDim2.new(1, -126, 0.5, -15), Parent = r,
            }, {corner(10), hairline(nil, 0.85)})
            b.MouseButton1Click:Connect(function()
                i = i % #options + 1
                b.Text = options[i]
                tween(b, {BackgroundColor3 = Theme.Hover}, 0.08).Completed:Connect(function() tween(b, {BackgroundColor3 = Theme.Panel}, 0.25) end)
                task.spawn(cb, options[i])
            end)
            task.spawn(cb, options[i])
            local api = {}
            function api:Set(v)
                local idx = table.find(options, v)
                if not idx then return end
                i = idx
                b.Text = options[i]
                task.spawn(cb, options[i])
            end
            return api
        end

        -- collapsible section with cards (like the reference UI)
        function tab:Section(title)
            local holder = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, Parent = page,
            }, {new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})})
            local head = new("TextButton", {
                Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 0, Parent = holder,
            })
            new("Frame", {                               -- accent tick before the title
                Size = UDim2.fromOffset(4, 16), Position = UDim2.fromOffset(2, 7), BackgroundColor3 = Theme.White,
                BorderSizePixel = 0, Parent = head,
            }, {corner(2), accentGradient(nil, 90)})
            new("TextLabel", {
                Text = title, Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
                Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -50, 1, 0), Parent = head,
            })
            local arrow = new("TextLabel", {
                Text = "v", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Accent,
                BackgroundTransparency = 1, Position = UDim2.new(1, -30, 0, 0), Size = UDim2.fromOffset(24, 30),
                Rotation = 180, Parent = head,
            })
            local body = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, LayoutOrder = 1, Parent = holder,
            }, {new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})})
            local open = true
            head.MouseButton1Click:Connect(function()
                open = not open
                body.Visible = open
                tween(arrow, {Rotation = open and 180 or 0}, 0.25, Enum.EasingStyle.Back)
            end)

            local sec = {}
            -- cb = what "Run" does. extra (optional) = {
            --   conf = "high|medium|low|custom",
            --   options = function(drawer) ... end                  fills an options drawer that opens with "Opt"
            --   pin = {default = bool, onChange = function(on)}     the "On screen" switch
            --   assist = {default = bool, onChange = function(on)}  the "Assist" (armed) switch
            -- }
            -- returns a handle with :SetPinned(bool) and :SetArmed(bool) (they never fire onChange)
            function sec:Button(name, desc, cb, extra)
                extra = extra or {}
                local confColor = extra.conf == "high" and Theme.Good or (extra.conf == "medium" and Theme.Accent2 or Theme.SubText)
                local holder2 = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1, Parent = body,
                }, {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
                local card = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 114), BackgroundColor3 = Theme.Item,
                    BackgroundTransparency = 0.25, LayoutOrder = 0, Parent = holder2,
                }, {corner(14), gloss(nil, 14, 1)})
                local cardStroke = hairline(card, 0.82)
                local sweepCard = sheen(card, 14)
                new("Frame", {                           -- confidence colour strip
                    Size = UDim2.fromOffset(4, 70), Position = UDim2.fromOffset(0, 18), BackgroundColor3 = confColor,
                    BorderSizePixel = 0, Parent = card,
                }, {corner(2)})
                new("TextLabel", {
                    Text = name, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -146, 0, 20), Parent = card,
                })
                new("TextLabel", {
                    Text = desc or "", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Theme.SubText,
                    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
                    TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(16, 30), Size = UDim2.new(1, -146, 0, 78), Parent = card,
                })
                -- right column: confidence chip, two switches, Run / Opt
                new("TextLabel", {
                    Text = extra.conf or "?", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = confColor,
                    BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.2,
                    Position = UDim2.new(1, -124, 0, 8), Size = UDim2.fromOffset(112, 18), Parent = card,
                }, {corner(9)})
                local handle = {}
                function handle:SetPinned() end
                function handle:SetArmed() end
                local function switchRow(labelText, y, spec)
                    local state = false
                    new("TextLabel", {
                        Text = labelText, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.SubText,
                        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
                        Position = UDim2.new(1, -124, 0, y), Size = UDim2.fromOffset(62, 20), Parent = card,
                    })
                    local sw = makeSwitch(card, UDim2.new(1, -52, 0, y), 40, 20)
                    local hit = new("TextButton", {
                        Text = "", BackgroundTransparency = 1, AutoButtonColor = false,
                        Position = UDim2.new(1, -126, 0, y - 4), Size = UDim2.fromOffset(116, 28), Parent = card,
                    })
                    local function apply(v, silent)
                        v = v and true or false
                        if v == state then return end
                        state = v
                        sw.render(v, true)
                        if not silent then task.spawn(spec.onChange, v) end
                    end
                    hit.MouseButton1Click:Connect(function() apply(not state) end)
                    if spec.default then state = true; sw.render(true, false); task.spawn(spec.onChange, true) end
                    return apply
                end
                if extra.pin then
                    local apply = switchRow("On screen", 32, extra.pin)
                    function handle:SetPinned(v) apply(v, true) end
                end
                if extra.assist then
                    local apply = switchRow("Assist", 56, extra.assist)
                    function handle:SetArmed(v) apply(v, true) end
                end
                local run = new("TextButton", {
                    Text = "Run", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Back,
                    BackgroundColor3 = Theme.White, AutoButtonColor = false,
                    Position = UDim2.new(1, -124, 1, -34), Size = UDim2.fromOffset(60, 26), Parent = card,
                }, {corner(10), accentGradient(nil, 0)})
                run.MouseButton1Click:Connect(function()
                    tween(run, {Size = UDim2.fromOffset(56, 24), Position = UDim2.new(1, -122, 1, -33)}, 0.07).Completed:Connect(function()
                        tween(run, {Size = UDim2.fromOffset(60, 26), Position = UDim2.new(1, -124, 1, -34)}, 0.25, Enum.EasingStyle.Back)
                    end)
                    task.spawn(cb)
                end)
                card.MouseEnter:Connect(function()
                    tween(card, {BackgroundTransparency = 0.12}, 0.18); tween(cardStroke, {Transparency = 0.5}, 0.18)
                    sweepCard()
                end)
                card.MouseLeave:Connect(function()
                    tween(card, {BackgroundTransparency = 0.25}, 0.25); tween(cardStroke, {Transparency = 0.82}, 0.25)
                end)

                if extra.options then
                    local drawer = new("Frame", {
                        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                        BackgroundTransparency = 1, Visible = false, LayoutOrder = 1, Parent = holder2,
                    }, {
                        new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
                        new("UIPadding", {PaddingLeft = UDim.new(0, 10)}),
                    })
                    local built, open2 = false, false
                    local optBtn = new("TextButton", {
                        Text = "Opt", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Accent,
                        BackgroundColor3 = Theme.Panel, AutoButtonColor = false,
                        Position = UDim2.new(1, -60, 1, -34), Size = UDim2.fromOffset(48, 26), Parent = card,
                    }, {corner(10), hairline(nil, 0.85)})
                    optBtn.MouseButton1Click:Connect(function()
                        open2 = not open2
                        if open2 and not built then       -- build lazily: hundreds of sliders up front would be slow on phones
                            built = true
                            extra.options(drawer)
                        end
                        drawer.Visible = open2
                        optBtn.Text = open2 and "Close" or "Opt"
                        tween(optBtn, {BackgroundColor3 = open2 and Theme.Accent or Theme.Panel,
                            TextColor3 = open2 and Theme.Back or Theme.Accent}, 0.2)
                    end)
                end
                return handle
            end

            -- read-only card with wrapped text (used for the tech library)
            function sec:Info(name, desc)
                local card = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Theme.Item, BackgroundTransparency = 0.35, Parent = body,
                }, {
                    corner(14), hairline(nil, 0.9),
                    new("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10)}),
                    new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
                })
                new("TextLabel", {
                    Text = name, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 0, Parent = card,
                })
                new("TextLabel", {
                    Text = desc or "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText,
                    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
                    TextWrapped = true, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = card,
                })
            end
            function sec:Toggle(name, default, cb, subtitle) return tab:Toggle(name, default, cb, body, subtitle) end
            function sec:Clear()
                for _, ch in ipairs(body:GetChildren()) do
                    if not ch:IsA("UIListLayout") then ch:Destroy() end
                end
            end
            return sec
        end

        Tabs[#Tabs + 1] = tab
        return tab
    end

    -- ambient shine: the border rotates slowly, and every ~6 s a shimmer runs over the title
    do
        local shimmerAcc = 0
        connect(RunService.Heartbeat, function(dt)
            if not menuOpen then return end
            BorderGrad.Rotation = (BorderGrad.Rotation + dt * 24) % 360
            shimmerAcc = shimmerAcc + dt
            if shimmerAcc >= 6 then
                shimmerAcc = 0
                TitleGrad.Offset = Vector2.new(-0.7, 0)
                tween(TitleGrad, {Offset = Vector2.new(0.7, 0)}, 1.1, Enum.EasingStyle.Sine)
            end
        end)
    end

    ---------------------------------------------------------------- state
    local Settings = {
        AutoTech      = false,
        TechKey       = Enum.KeyCode.Q,
        TechDelay     = 0.05,
        TechCooldown  = 0.6,
        TechDirection = "Back",
    }

    ---------------------------------------------------------------- Auto Tech
    local lastTech = 0

    local DirectionKeys = {
        Forward = Enum.KeyCode.W, Back = Enum.KeyCode.S,
        Left    = Enum.KeyCode.A, Right = Enum.KeyCode.D,
    }

    local function keyEvent(down, key) VirtualInput:SendKeyEvent(down, key, false, game) end
    local function press(key, hold)
        keyEvent(true, key)
        task.wait(hold or 0.03)
        keyEvent(false, key)
    end

    local function isKnocked(char)
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Ragdoll
            or st == Enum.HumanoidStateType.FallingDown
            or st == Enum.HumanoidStateType.PlatformStanding then
            return true
        end
        -- the game may flag knockdown with attributes / values
        return char:GetAttribute("Ragdolled") == true or char:GetAttribute("Stunned") == true
            or char:FindFirstChild("Ragdolled") ~= nil
    end

    local macroRunning = false   -- set by the macro runner below; Auto Tech stays quiet while a macro plays

    local function doTech()
        if macroRunning then return end
        local now = os.clock()
        if now - lastTech < Settings.TechCooldown then return end
        lastTech = now
        task.spawn(function()
            task.wait(Settings.TechDelay)
            -- the world may have changed during the delay: toggled off, UI closed, or already recovered
            if not (alive and Settings.AutoTech and isKnocked(LocalPlayer.Character)) then return end
            local dir = DirectionKeys[Settings.TechDirection]
            if dir then keyEvent(true, dir) end
            pcall(press, Settings.TechKey, 0.04)
            if dir then task.wait(0.05); keyEvent(false, dir) end   -- always release the direction key
        end)
    end

    local wasKnocked = false
    connect(RunService.Heartbeat, function()
        if not Settings.AutoTech then wasKnocked = false return end
        local knocked = isKnocked(LocalPlayer.Character)
        if knocked and not wasKnocked then doTech() end
        wasKnocked = knocked
    end)

    ---------------------------------------------------------------- timing + ping
    -- Gaps (seconds) after each kind of step. Adjustable in the Timing tab. With "Auto timing" on, the gaps
    -- that wait for a visible cue (after a move or dash) are additionally shortened by about your ping
    -- (see ping_model.lua). Heuristic: it cannot read other players' ping and cannot guarantee a hit.
    local TimingDefaults = {m1 = 0.2, dash = 0.3, move = 0.5, jump = 0.25}
    local Timing = {m1 = 0.2, dash = 0.3, move = 0.5, jump = 0.25}
    local Auto = {on = true, strength = 1, offsetMs = 0, manualPing = 0}
    local macroSpeed = 1
    local PingState = {model = PingModel and PingModel.new(0.2)}

    local ComboOpts = {}                                   -- combo name -> options table (see combo_options.lua)
    local Pins = {}                                        -- pinned on-screen buttons (see the manager further down)
    local SavedPins = type(Saved.pins) == "table" and Saved.pins or {}
    local Armed, armedOrder = {}, {}                       -- Assist: armed combos (never saved: you start disarmed)
    local Block = {on = false, range = 14, aim = 60, delay = 0.10, hold = 0.35, cooldown = 0.25, usePing = true}   -- auto block
    if type(Saved.block) == "table" then
        local sb = Saved.block
        Block.range = num(sb.range, 6, 30, Block.range)
        Block.aim = num(sb.aim, 20, 120, Block.aim)
        Block.delay = num(sb.delay, 0, 0.4, Block.delay)
        Block.hold = num(sb.hold, 0.1, 1, Block.hold)
        Block.cooldown = num(sb.cooldown, 0.1, 1, Block.cooldown)
        Block.usePing = sb.usePing ~= false
    end
    local SideAuto = {on = false, dir = "Closest", delay = 0.25, cooldown = 0.8, anims = {}}   -- auto side dash after your moves
    if type(Saved.sideAuto) == "table" then
        local sa = Saved.sideAuto
        if sa.dir == "Left" or sa.dir == "Right" or sa.dir == "Alternate" or sa.dir == "Closest" then SideAuto.dir = sa.dir end
        SideAuto.delay = num(sa.delay, 0, 1, SideAuto.delay)
        SideAuto.cooldown = num(sa.cooldown, 0.2, 3, SideAuto.cooldown)
        if type(sa.anims) == "table" then
            local n = 0
            for id, v in pairs(sa.anims) do
                if v == true and type(id) == "string" and #id <= 120 and not id:find("%c") and n < 24 then
                    SideAuto.anims[id] = true
                    n = n + 1
                end
            end
        end
    end
    if type(Saved.timing) == "table" then
        Timing.m1   = num(Saved.timing.m1,   0.08, 0.6, Timing.m1)
        Timing.dash = num(Saved.timing.dash, 0.08, 0.8, Timing.dash)
        Timing.move = num(Saved.timing.move, 0.15, 1.2, Timing.move)
        Timing.jump = num(Saved.timing.jump, 0.08, 0.6, Timing.jump)
    end
    if type(Saved.auto) == "table" then
        Auto.on = Saved.auto.on ~= false
        Auto.strength = num(Saved.auto.strength, 0, 1.5, Auto.strength)
        Auto.offsetMs = num(Saved.auto.offsetMs, -100, 100, Auto.offsetMs)
        Auto.manualPing = num(Saved.auto.manualPing, 0, 400, Auto.manualPing)
    end
    macroSpeed = num(Saved.speed, 0.5, 2, macroSpeed)
    if ComboOptions and type(Saved.combos) == "table" then
        for name, o in pairs(Saved.combos) do
            if type(name) == "string" then ComboOpts[name] = ComboOptions.sanitize(o) end
        end
    end
    local function getOpts(name)
        if not ComboOptions then return nil end
        if not ComboOpts[name] then ComboOpts[name] = ComboOptions.new() end
        return ComboOpts[name]
    end

    local dirty, ready = false, false
    local function markDirty() if ready then dirty = true end end
    local function saveNow()
        dirty = false
        genv.__AnimationHubUi = {theme = pendingTheme, scale = uiScale, glass = glass}
        if not (writefile and ComboOptions) then return end
        local combos = {}
        for name, o in pairs(ComboOpts) do
            if not ComboOptions.isDefault(o) then combos[name] = o end    -- only what differs from the defaults
        end
        local pinData = {}
        if Pins then
            for name, p in pairs(Pins) do pinData[name] = {x = p.x, y = p.y} end
        end
        for name, pos in pairs(SavedPins or {}) do      -- pins in the file whose card is not built (yet): keep only valid ones
            if type(name) == "string" and pinData[name] == nil and type(pos) == "table"
                and type(pos.x) == "number" and type(pos.y) == "number" then
                pinData[name] = {x = pos.x, y = pos.y}
            end
        end
        local uiData = {theme = pendingTheme, scale = uiScale, glass = glass}
        genv.__AnimationHubUi = uiData                    -- also kept in memory so executors without files can rebuild
        local data = {version = 1, timing = Timing, speed = macroSpeed, auto = Auto, combos = combos, pins = pinData, ui = uiData,
            block = {range = Block.range, aim = Block.aim, delay = Block.delay, hold = Block.hold, cooldown = Block.cooldown, usePing = Block.usePing},
            sideAuto = {dir = SideAuto.dir, delay = SideAuto.delay, cooldown = SideAuto.cooldown, anims = SideAuto.anims}}
        local json = safe(function() return game:GetService("HttpService"):JSONEncode(data) end)
        if type(json) == "string" then pcall(writefile, SETTINGS_FILE, json) end
    end
    onCleanup[#onCleanup + 1] = function() if dirty then saveNow() end end
    do
        local acc = 0
        connect(RunService.Heartbeat, function(dt)
            acc = acc + dt
            if acc < 2 then return end                  -- write at most every 2 s, only when something changed
            acc = 0
            if dirty then saveNow() end
        end)
    end
    local pingLabel, gapsLabel

    local function readPing()
        local item = safe(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"] end)
        local v = item and safe(function() return item:GetValue() end)
        if type(v) == "number" then return v end
    end
    local function currentPing()                       -- ms, or nil when unknown
        if Auto.manualPing > 0 then return Auto.manualPing end
        return PingState.model and PingState.model:value()
    end
    -- final wait for one step. o = that combo's options (nil = defaults): own gap or global gap, x speeds, then
    -- (auto timing on for this combo) the ping adjustment for gaps that wait for a visible cue
    local DefaultOpts = ComboOptions and ComboOptions.new()
    -- the ping adjustment alone, for one gap in seconds (o = combo options; nil = defaults)
    local function adjustGap(gap, dependent, o)
        o = o or DefaultOpts
        local autoOn = (o and ComboOptions) and ComboOptions.autoOn(Auto.on, o) or Auto.on
        if not (autoOn and PingModel) then return gap end
        return PingModel.adjustDelay(gap, currentPing(), Auto.strength, {dependent = dependent, offsetMs = Auto.offsetMs + (o and o.offsetMs or 0)})
    end
    local function stepDelay(kind, dependent, o)
        o = o or DefaultOpts
        local gap
        if o and ComboOptions then gap = ComboOptions.gap(kind, Timing, o, macroSpeed)
        else gap = Timing[kind] * macroSpeed end
        return adjustGap(gap, dependent, o)
    end

    do
        local acc = 0
        connect(RunService.Heartbeat, function(dt)
            acc = acc + dt
            if acc < 0.25 then return end              -- 4 samples per second is plenty
            acc = 0
            if PingState.model then
                local v = readPing()
                if v then PingState.model:sample(v) end
            end
            if pingLabel then
                local p = currentPing()
                if p then
                    local j = PingState.model and PingState.model:jitter() or 0
                    local note = (PingState.model and Auto.manualPing <= 0 and not PingState.model:stable()) and "  (unstable)" or ""
                    pingLabel.Text = string.format("Ping: %d ms   jitter: %d ms%s", math.floor(p + 0.5), math.floor(j + 0.5), note)
                else
                    pingLabel.Text = "Ping: unknown - set Manual ping below"
                end
            end
            if pingPill then
                local shown = currentPing()
                pingPill.Text = shown and (math.floor(shown + 0.5) .. " ms") or "-- ms"
                pingPill.TextColor3 = (shown and shown > 150) and Color3.fromRGB(255, 120, 120) or Theme.Good
            end
            if gapsLabel then
                gapsLabel.Text = string.format("Gaps now  M1 %.2fs  dash %.2fs  move %.2fs  jump %.2fs%s",
                    stepDelay("m1", false), stepDelay("dash", true), stepDelay("move", true), stepDelay("jump", false),
                    Auto.on and "   (auto)" or "   (manual)")
            end
        end)
    end

    ---------------------------------------------------------------- macro runner
    -- Plays a combo from tsb_data as real inputs. Move slots assume the hotbar order = the move list
    -- order in tsb_data (1..4). That order is UNVERIFIED: if a move fires the wrong skill, edit MoveSlots.
    local MoveSlots = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four}
    local macroId = 0
    local assistBlockedUntil = 0 -- our own inputs must not re-trigger Assist: ignore triggers until this time
    local runningName            -- name of the combo currently playing (pinned buttons light up)
    local renderPins             -- assigned by the pinned-buttons manager below

    local function click()
        local vw, vh = viewport()
        vw, vh = vw or 400, vh or 300
        VirtualInput:SendMouseButtonEvent(vw / 2, vh / 2, 0, true, game, 0)
        task.wait(0.03)
        VirtualInput:SendMouseButtonEvent(vw / 2, vh / 2, 0, false, game, 0)
    end
    local function dash(dirKey)
        if dirKey then keyEvent(true, dirKey) end
        pcall(press, Enum.KeyCode.Q, 0.04)
        if dirKey then task.wait(0.03); keyEvent(false, dirKey) end
    end

    -- which timing category a generic token belongs to
    local KIND = {M1 = "m1", JUMP_M1 = "m1", JUMP = "jump", Q = "dash", FRONTDASH = "dash", BACKDASH = "dash", SIDEDASH = "dash"}
    local function moveKey(tok, charName)
        local char = Data and Data.Characters[charName]
        local list = char and (char.moveList or char.moves)          -- moveList = hotbar order for characters whose moves carry stats
        if type(list) == "table" then
            for i, mv in ipairs(list) do
                if mv == tok then return MoveSlots[i] end
            end
        end
    end
    local function canPlay(tok, charName) return KIND[tok] ~= nil or moveKey(tok, charName) ~= nil end

    local function vec3(v)
        if v == nil then return nil end
        local x, y, z = v.X, v.Y, v.Z
        if type(x) == "number" and type(y) == "number" and type(z) == "number" then return {x = x, y = y, z = z} end
    end
    -- Which way a SIDEDASH goes. "Left" / "Right" are fixed; "Closest" looks at where the nearest player is
    -- compared with your camera and picks the side that moves you toward them. It only chooses between the A
    -- and D key - it never moves or teleports your character.
    local function resolveSide(mode)
        if mode == "Left" or mode == "Right" then return mode end
        local cam = workspace.CurrentCamera
        local mine = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local right = cam and safe(function() return vec3(cam.CFrame.RightVector) end)
        local myPos = mine and safe(function() return vec3(mine.Position) end)
        if not (CombatMath and right and myPos) then return "Left" end
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local c = p.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                local hum = c and c:FindFirstChildOfClass("Humanoid")
                local pos = hrp and safe(function() return vec3(hrp.Position) end)
                local hp = hum and hum.Health
                if pos and (type(hp) ~= "number" or hp > 0) then list[#list + 1] = pos end
            end
        end
        local target = CombatMath.closest(myPos, list, 250)
        return (target and CombatMath.sideToward(myPos, right, target)) or "Left"
    end

    -- plays one step; returns (kind of gap that follows it, whether that gap waits for a visible cue),
    -- or nil if the token cannot be played. o = this combo's options.
    local function playToken(tok, charName, o)
        local kind = KIND[tok]
        if tok == "M1" then click()
        elseif tok == "Q" then dash(nil)
        elseif tok == "FRONTDASH" then dash(Enum.KeyCode.W)
        elseif tok == "BACKDASH" then dash(Enum.KeyCode.S)
        elseif tok == "SIDEDASH" then dash(resolveSide(o and o.side or "Closest") == "Right" and Enum.KeyCode.D or Enum.KeyCode.A)
        elseif tok == "JUMP" then press(Enum.KeyCode.Space, 0.05)
        elseif tok == "JUMP_M1" then press(Enum.KeyCode.Space, 0.05); task.wait(0.12); click()
        else
            local key = moveKey(tok, charName)
            if not key then return nil end
            press(key, 0.05)
            return "move", true
        end
        return kind, kind == "dash"
    end

    local function stopMacro()
        macroId = macroId + 1          -- any running macro thread notices the new id and exits
        macroRunning = false
        runningName = nil
        if renderPins then renderPins() end
    end
    onCleanup[#onCleanup + 1] = stopMacro

    -- lead (optional) = {kind, dependent}: wait out the gap that follows the step YOU just did, then play steps
    local function runMacro(steps, charName, comboName, lead)
        if macroRunning then stopMacro() return end        -- tapping again stops it
        macroId = macroId + 1
        local myId = macroId
        macroRunning = true
        runningName = comboName
        if renderPins then renderPins() end
        local opts = comboName and getOpts(comboName) or nil
        task.spawn(function()
            local ok, err = pcall(function()
                if lead then task.wait(stepDelay(lead.kind, lead.dependent, opts)) end
                for _, tok in ipairs(steps) do
                    if myId ~= macroId then return end       -- stopped, or replaced by a newer macro
                    local kind, dependent = playToken(tok, charName, opts)
                    if kind then task.wait(stepDelay(kind, dependent, opts)) end
                end
            end)
            assistBlockedUntil = os.clock() + 0.6
            if myId == macroId then                            -- never clobber a newer macro's flag
                macroRunning = false
                runningName = nil
                if renderPins then renderPins() end
            end
            if not ok then warn("[Animation Hub] macro failed: " .. tostring(err)) end
        end)
    end

    -- "M1 x3 > SIDEDASH > FLOWING WATER ...", plus how many steps cannot be played automatically
    local function describe(steps, charName)
        local out, i, skipped = {}, 1, 0
        while i <= #steps do
            local j = i
            while steps[j + 1] == steps[i] do j = j + 1 end
            local name = steps[i]:gsub("_", " ")
            local playable = canPlay(steps[i], charName)
            if not playable then skipped = skipped + (j - i + 1); name = name .. "*" end
            out[#out + 1] = (j > i) and (name .. " x" .. (j - i + 1)) or name
            i = j + 1
        end
        local text = table.concat(out, " > ")
        if skipped > 0 then text = text .. "   (* " .. skipped .. " step(s) skipped: no key mapped)" end
        return text
    end

    ---------------------------------------------------------------- assist: arm a combo, YOU do the first move
    -- Arming a combo does NOT run it. It waits until you cast the trigger move yourself (by default the first
    -- move of the combo, e.g. Flowing Water for Kyoto, Hunter's Grasp for the Garou catch) and then plays
    -- everything that comes after it. Your cast is recognised from the keyboard (hotbar keys 1-4) or, for
    -- on-screen touch buttons, from the animation that move plays (taught once with "Learn trigger").
    local function shortLabel(name) return (name:gsub("_", " ")) end
    local ComboInfo = {}             -- name -> {steps, charName}, filled in when the cards are built
    local ArmHandles = {}            -- name -> card handle (keeps the Assist switch in step with the pinned button)
    local triggerOf, setArmed, startLearning     -- the only pieces the cards need; the rest lives in the block below
    do
    local learning, learnGen = nil, 0

    local function moveTester(charName) return function(tok) return moveKey(tok, charName) ~= nil end end
    function triggerOf(name)   -- index, token, options of the step YOU perform
        local info = ComboInfo[name]
        if not (info and Assist) then return nil end
        local o = getOpts(name)
        local idx = Assist.triggerIndex(info.steps, moveTester(info.charName), o and o.trigger)
        if not idx then return nil end
        return idx, info.steps[idx], o
    end
    local function gapKindOf(tok, charName)          -- (kind, dependent) of the gap that follows a step
        if KIND[tok] then return KIND[tok], KIND[tok] == "dash" end
        if moveKey(tok, charName) then return "move", true end
        return "m1", false
    end
    local function matchesToken(input, tok, charName)
        local kc = input.KeyCode
        if tok == "M1" then return input.UserInputType == Enum.UserInputType.MouseButton1 end
        if tok == "JUMP" or tok == "JUMP_M1" then return kc == Enum.KeyCode.Space end
        if KIND[tok] == "dash" then
            if kc ~= Enum.KeyCode.Q then return false end
            local function down(k) return UserInputService:IsKeyDown(k) end
            if tok == "FRONTDASH" then return down(Enum.KeyCode.W) end
            if tok == "BACKDASH" then return down(Enum.KeyCode.S) end
            if tok == "SIDEDASH" then return down(Enum.KeyCode.A) or down(Enum.KeyCode.D) end
            return not (down(Enum.KeyCode.W) or down(Enum.KeyCode.A) or down(Enum.KeyCode.S) or down(Enum.KeyCode.D))
        end
        local key = moveKey(tok, charName)
        return key ~= nil and kc == key
    end

    local function startAssist(name)
        if macroRunning or os.clock() < assistBlockedUntil then return end
        local idx, trigTok = triggerOf(name)
        if not idx then return end
        local info = ComboInfo[name]
        local rest = Assist.remaining(info.steps, idx)
        if not rest then return end
        local kind, dependent = gapKindOf(trigTok, info.charName)
        runMacro(rest, info.charName, name, {kind = kind, dependent = dependent})
    end

    function setArmed(name, on)
        on = on and true or false
        if (Armed[name] == true) == on then return end
        Armed[name] = on or nil
        for i, n in ipairs(armedOrder) do if n == name then table.remove(armedOrder, i) break end end
        if on then armedOrder[#armedOrder + 1] = name end
        if ArmHandles[name] then ArmHandles[name]:SetArmed(on) end
        if renderPins then renderPins() end
        if ready then
            local idx, trigTok = triggerOf(name)
            local info = ComboInfo[name]
            if not on then toast(shortLabel(name) .. " disarmed")
            elseif idx and info and Assist.remaining(info.steps, idx) then
                toast(shortLabel(name) .. " armed - cast " .. shortLabel(trigTok) .. " yourself, I do the rest")
            else toast(shortLabel(name) .. " has nothing after its trigger step") end
        end
    end
    onCleanup[#onCleanup + 1] = function() armedOrder = {}; Armed = {} end

    -- auto side dash: after one of YOUR moves (hotbar key, or an animation you taught it) it dashes sideways
    local lastSideAuto, lastSide = 0, nil
    local function performSideAuto()
        local now = os.clock()
        if now - lastSideAuto < SideAuto.cooldown then return end
        lastSideAuto = now
        local side
        if SideAuto.dir == "Alternate" then side = Assist.nextSide("Alternate", lastSide) else side = resolveSide(SideAuto.dir) end
        lastSide = side
        task.spawn(function()
            task.wait(adjustGap(SideAuto.delay, true, nil))
            if not (alive and SideAuto.on) or macroRunning then return end
            dash(side == "Right" and Enum.KeyCode.D or Enum.KeyCode.A)
            assistBlockedUntil = os.clock() + 0.5
        end)
    end

    local function isSlotKey(kc)
        for _, k in ipairs(MoveSlots) do if k == kc then return true end end
        return false
    end
    connect(UserInputService.InputBegan, function(input, gp)
        if gp or macroRunning or os.clock() < assistBlockedUntil then return end
        if #armedOrder > 0 then
            local name = Assist.pick(armedOrder, function(n)
                local idx, tok = triggerOf(n)
                return idx ~= nil and matchesToken(input, tok, ComboInfo[n].charName)
            end)
            if name then startAssist(name) return end
        end
        if SideAuto.on and isSlotKey(input.KeyCode) then performSideAuto() end
    end)

    -- touch players: the game's own skill buttons are not keyboard keys, so watch the animation your move plays
    local function shortId(id) return (id:gsub("^rbxassetid://", "")) end
    local function onAnimationPlayed(track)
        local id = safe(function() return track.Animation.AnimationId end)
        if type(id) ~= "string" or id == "" or #id > 120 then return end
        if safe(function() return track.Looped end) == true then return end        -- walking / idle loops are not moves
        if learning then
            local what = learning
            learning = nil
            learnGen = learnGen + 1
            if what.kind == "combo" then
                local o = getOpts(what.name)
                if o then o.trigAnim = id; markDirty() end
                toast("Learned the trigger for " .. shortLabel(what.name))
            else
                local n = 0
                for _ in pairs(SideAuto.anims) do n = n + 1 end
                if n < 24 then SideAuto.anims[id] = true; markDirty() end
                toast("Learned a move for auto side dash (" .. shortId(id) .. ")")
            end
            return
        end
        if macroRunning or os.clock() < assistBlockedUntil then return end
        local name = Assist.pick(armedOrder, function(n)
            local o = getOpts(n)
            return o ~= nil and o.trigAnim ~= "" and o.trigAnim == id
        end)
        if name then startAssist(name) return end
        if SideAuto.on and SideAuto.anims[id] then performSideAuto() end
    end
    function startLearning(kind, name, hint)
        learning = {kind = kind, name = name}
        learnGen = learnGen + 1
        local mine = learnGen
        toast(hint)
        task.spawn(function()
            task.wait(10)
            if learning and mine == learnGen and alive then learning = nil; toast("Learning timed out - tap Learn again") end
        end)
    end
    local function hookCharacter(char)
        task.spawn(function()
            local hum = char:WaitForChild("Humanoid", 10)
            local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 10))
            if animator and alive then connect(animator.AnimationPlayed, onAnimationPlayed) end
        end)
    end
    if LocalPlayer.Character then hookCharacter(LocalPlayer.Character) end
    connect(LocalPlayer.CharacterAdded, hookCharacter)
    end

    ---------------------------------------------------------------- auto block
    -- When another player in front of you starts an attack animation aimed at you, hold F for a moment.
    -- Only attacks that CAN be blocked are answered: in range, aimed at you, in front of you (hits from behind
    -- always connect, charged hits and grabs ignore block). The delay is shortened by your ping so the block lands
    -- when the hit does - but I cannot read the move's real hit frame, so tune "Delay" until it blocks in time.
    do
        local blockBusyUntil = 0
        local lastSwing = setmetatable({}, {__mode = "k"})
        local function onEnemyAnimation(player, track)
            if not (Block.on and CombatMath) then return end
            local now = os.clock()
            if now < blockBusyUntil or macroRunning then return end
            if safe(function() return track.Looped end) == true then return end                  -- walk / idle loops
            local prio = safe(function() return track.Priority.Value end)
            local minPrio = safe(function() return Enum.AnimationPriority.Action.Value end)
            if type(prio) == "number" and type(minPrio) == "number" and prio < minPrio then return end   -- not an action layer
            if lastSwing[player] and now - lastSwing[player] < 0.12 then return end                 -- same swing, several tracks
            local mine = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local theirs = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if not (mine and theirs) then return end
            local ok = safe(function()
                return CombatMath.shouldBlock(vec3(mine.Position), vec3(mine.CFrame.LookVector),
                    vec3(theirs.Position), vec3(theirs.CFrame.LookVector), Block.range, Block.aim)
            end)
            if not ok or isKnocked(LocalPlayer.Character) then return end
            lastSwing[player] = now
            local delay = Block.delay
            if Block.usePing and PingModel then
                delay = PingModel.adjustDelay(delay, currentPing(), Auto.strength, {dependent = true, offsetMs = Auto.offsetMs, minDelay = 0})
            end
            blockBusyUntil = now + delay + Block.hold + Block.cooldown
            task.spawn(function()
                if delay > 0 then task.wait(delay) end
                if not (alive and Block.on) or macroRunning then return end
                keyEvent(true, Enum.KeyCode.F)
                task.wait(Block.hold)
                keyEvent(false, Enum.KeyCode.F)                                                 -- always let go
            end)
        end
        local function hookEnemy(player)
            if player == LocalPlayer then return end
            local function hookChar(char)
                task.spawn(function()
                    local hum = char:WaitForChild("Humanoid", 10)
                    local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 10))
                    if animator and alive then connect(animator.AnimationPlayed, function(track) onEnemyAnimation(player, track) end) end
                end)
            end
            if player.Character then hookChar(player.Character) end
            connect(player.CharacterAdded, hookChar)
        end
        for _, p in ipairs(Players:GetPlayers()) do hookEnemy(p) end
        connect(Players.PlayerAdded, hookEnemy)
        onCleanup[#onCleanup + 1] = function() Block.on = false end
    end

    ---------------------------------------------------------------- pinned on-screen buttons
    -- Turn a combo's "On screen" switch on and a button for it appears on your screen. Tap it to run the combo
    -- (tap again to stop), drag it anywhere, the Lock button on the floating bar pins them in place, and the
    -- Pins button on the bar hides / shows all of them. Pinned combos and their positions are saved.
    local PinLayer = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 8, Parent = Gui})
    local pinOrder = {}                            -- Pins: name -> {btn, scale, stroke, tracker, x, y}
    local pinsVisible, pinsLocked = true, false
    local PIN_W, PIN_H = 74, 58

    local function pinDefaultPos(index)
        local vw, vh = viewport()
        vw, vh = vw or 800, vh or 450
        local perColumn = math.max(1, math.floor((vh - 90) / (PIN_H + 8)))
        local col, row = math.floor((index - 1) / perColumn), (index - 1) % perColumn
        return vw - PIN_W - 12 - col * (PIN_W + 8), 70 + row * (PIN_H + 8)
    end
    local function placePin(p)
        local vw, vh = viewport()
        if DragTracker and vw then p.x, p.y = DragTracker.clamp(p.x, p.y, p.w or PIN_W, p.h or PIN_H, vw, vh, 4) end
        p.btn.Position = UDim2.fromOffset(p.x, p.y)
    end
    renderPins = function()
        for name, p in pairs(Pins) do
            local o = getOpts(name)
            local assistMode = o == nil or o.pinMode ~= "run"
            local running = runningName == name
            local armed = Armed[name] == true
            local lit = running or (assistMode and armed)
            tween(p.btn, {BackgroundColor3 = running and Theme.Accent or (lit and Theme.Hover or Theme.Panel)}, 0.18)
            tween(p.stroke, {Transparency = lit and 0 or 0.4}, 0.18)
            p.btn.TextColor3 = running and Theme.Back or Theme.Text
            p.dot.Visible = assistMode
            tween(p.dot, {BackgroundColor3 = armed and Theme.Good or Theme.SubText}, 0.18)
            p.btn.Visible = pinsVisible
        end
    end
    local function setPinsLocked(v)
        pinsLocked = v and true or false
        for _, p in pairs(Pins) do if p.tracker then p.tracker:setLocked(pinsLocked) end end
    end
    local function setPinsVisible(v)
        pinsVisible = v and true or false
        renderPins()
        if renderFab then renderFab() end
    end

    local function setPinned(name, on, steps, charName, shape, caption)
        local p = Pins[name]
        if not on then
            if p then
                tween(p.scale, {Scale = 0}, 0.18)
                local btn = p.btn
                task.spawn(function() task.wait(0.2); btn:Destroy() end)
                Pins[name] = nil
                SavedPins[name] = nil                     -- forget it, or the saved file would bring it back
                for i, n in ipairs(pinOrder) do if n == name then table.remove(pinOrder, i) break end end
                if ready then toast(shortLabel(name) .. " removed from screen") end
                markDirty()
            end
            return
        end
        if p then return end
        pinOrder[#pinOrder + 1] = name
        local pos = SavedPins[name]
        local x, y
        if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" then
            x, y = pos.x, pos.y
        else
            x, y = pinDefaultPos(#pinOrder)
        end
        local circle = shape == "circle"
        local pw, ph = PIN_W, PIN_H
        if circle then pw, ph = 70, 70 end
        local radius = circle and 35 or 16
        local btn = new("TextButton", {
            Text = caption or shortLabel(name), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Text,
            TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
            BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.12, AutoButtonColor = false,
            Size = UDim2.fromOffset(pw, ph), Visible = pinsVisible, Parent = PinLayer,
        }, {corner(radius), new("UIPadding", {PaddingLeft = UDim.new(0, circle and 12 or 6), PaddingRight = UDim.new(0, circle and 12 or 6)}), gloss(nil, radius, 1)})
        local pinStroke = stroke(Theme.Accent, 1.6, 0.35)
        pinStroke.Parent = btn
        local pinDot = new("Frame", {                   -- green = armed (Assist mode only)
            Size = UDim2.fromOffset(9, 9), Position = circle and UDim2.new(0.5, -4, 0, 5) or UDim2.new(1, -16, 0, 7), BackgroundColor3 = Theme.SubText,
            BorderSizePixel = 0, ZIndex = 3, Parent = btn,
        }, {corner(5)})
        local scale = new("UIScale", {Scale = 0, Parent = btn})
        p = {btn = btn, scale = scale, stroke = pinStroke, dot = pinDot, x = x, y = y, w = pw, h = ph}
        p.tracker = DragTracker and DragTracker.new(8)
        if p.tracker then p.tracker:setLocked(pinsLocked) end
        Pins[name] = p
        placePin(p)
        tween(scale, {Scale = 1}, 0.35, Enum.EasingStyle.Back)

        btn.InputBegan:Connect(function(i)
            if p.tracker and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
                p.tracker:begin(i.Position.X, i.Position.Y, p.x, p.y)
            end
        end)
        btn.MouseButton1Down:Connect(function() tween(scale, {Scale = 0.92}, 0.08) end)
        btn.MouseButton1Up:Connect(function() tween(scale, {Scale = 1}, 0.2, Enum.EasingStyle.Back) end)
        btn.MouseButton1Click:Connect(function()
            if p.tracker and p.tracker:suppressClick(os.clock()) then return end     -- that "click" ended a drag
            local o = getOpts(name)
            if o and o.pinMode == "run" then runMacro(steps, charName, name)      -- run mode: play the whole combo
            else setArmed(name, not Armed[name]) end                              -- assist mode: arm / disarm
        end)
        renderPins()
        if ready then
            local o = getOpts(name)
            toast(shortLabel(name) .. ((o and o.pinMode == "run") and " pinned - tap it to run" or " pinned - tap it to arm Assist"))
        end
        markDirty()
    end

    do   -- one pair of global listeners moves / releases whichever pinned button is being dragged
        connect(UserInputService.InputChanged, function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
            for _, p in pairs(Pins) do
                if p.tracker then
                    local nx, ny = p.tracker:move(i.Position.X, i.Position.Y)
                    if nx then p.x, p.y = nx, ny; placePin(p) end
                end
            end
        end)
        connect(UserInputService.InputEnded, function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
            for _, p in pairs(Pins) do
                if p.tracker then
                    local moved = p.tracker.moved
                    p.tracker:finish(os.clock())
                    if moved then markDirty() end          -- a drag just ended: remember the new position
                end
            end
        end)
    end

    ---------------------------------------------------------------- tabs
    sideHeader("MENU")
    local Main_  = createTab("Main", "#")
    local Credit = createTab("Credit", "+")
    local CharList = {
        {"The Strongest Hero", "Saitama"}, {"Hero Hunter", "Garou"}, {"Hero Hunter (Monster form)", "Garou Monster"}, {"Destructive Cyborg", "Genos"},
        {"Deadly Ninja", "Sonic"}, {"Brutal Demon", "Metal Bat"}, {"Wild Psychic", "Tatsumaki"},
        {"Blade Master", "Atomic Samurai"}, {"Tech Prodigy", "Tech Prodigy"},
    }
    local CharTabs = {}
    if Data then
        sideHeader("CHARACTERS")
        for _, ch in ipairs(CharList) do
            CharTabs[#CharTabs + 1] = {tab = createTab(ch[2], ch[2]:sub(1, 1)), full = ch[1], short = ch[2]}
        end
    end
    sideHeader("TOOLS")
    local Timing_ = createTab("Timing", "T")
    local TechLib = Data and createTab("Techs", "?")
    local Tech   = createTab("Auto Tech", "*")
    local Tele   = createTab("Teleports", "@")
    local Effects = createTab("Effects Preset", "~")

    -- Main
    Main_:Label("General utilities")
    do
    local wantSpeed
    local function applySpeed()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and wantSpeed then hum.WalkSpeed = wantSpeed end
    end
    Main_:Slider("WalkSpeed", 16, 120, 16, 1, function(v)
        if v ~= 16 or wantSpeed then wantSpeed = v; applySpeed() end   -- leave the game's own speed alone until touched
    end)
    connect(LocalPlayer.CharacterAdded, function(char)
        char:WaitForChild("Humanoid", 5)
        if alive then applySpeed() end                                  -- survive respawns
    end)
    local antiAfk = true
    connect(LocalPlayer.Idled, function()          -- one listener for the whole session; the toggle just gates it
        if not antiAfk then return end
        local vu = safe(function() return game:GetService("VirtualUser") end)
        if vu then
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        else
            pcall(press, Enum.KeyCode.Space, 0.03)
        end
    end)
    Main_:Toggle("Anti AFK", true, function(on) antiAfk = on end)
    end
    Main_:Button("Reset Character", function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end)

    -- character tabs built from tsb_data (only when bundled in)
    local function buildCharacter(tab, fullName, label)
        if not tab then return end
        local sec = {}
        local function get(key, title)
            if not sec[key] then sec[key] = tab:Section(title) end
            return sec[key]
        end
        local names = {}
        for name, c in pairs(Data.Combos) do
            if c.character == fullName then names[#names + 1] = name end
        end
        table.sort(names)
        for _, name in ipairs(names) do
            local c = Data.Combos[name]
            local key, title = "combos", label .. " combos"
            if name:find("Kyoto") then key, title = "kyoto", label .. " kyoto"
            elseif name:find("Catch") then key, title = "tech", label .. " Tech" end
            local o = getOpts(name)
            ComboInfo[name] = {steps = c.steps, charName = fullName}
            local function drawer(parent)                       -- this combo's own options
                local function set(key) return function(v) if o[key] ~= v then o[key] = v; markDirty() end end end
                local pickers, sliders = {}, {}
                pickers.auto = tab:Dropdown("Auto timing", {"global", "on", "off"}, o.auto, set("auto"), parent)
                sliders.speed = tab:Slider("Speed (higher = slower)", 0.5, 2, o.speed, 0.05, set("speed"), parent)
                sliders.m1 = tab:Slider("M1 gap (0 = global)", 0, 0.6, o.m1, 0.01, set("m1"), parent)
                sliders.dash = tab:Slider("Dash gap (0 = global)", 0, 0.8, o.dash, 0.01, set("dash"), parent)
                sliders.move = tab:Slider("Move gap (0 = global)", 0, 1.2, o.move, 0.01, set("move"), parent)
                sliders.jump = tab:Slider("Jump gap (0 = global)", 0, 0.6, o.jump, 0.01, set("jump"), parent)
                sliders.offsetMs = tab:Slider("Fine-tune (ms, + = later)", -100, 100, o.offsetMs, 5, set("offsetMs"), parent)
                pickers.side = tab:Dropdown("Side dash goes", {"Closest", "Left", "Right"}, o.side, set("side"), parent)
                pickers.pinMode = tab:Dropdown("Pinned button does", {"assist", "run"}, o.pinMode, function(v)
                    if o.pinMode ~= v then o.pinMode = v; markDirty(); if renderPins then renderPins() end end
                end, parent)
                -- Assist: which step is YOURS (everything after it is played for you)
                local trigText = tab:Label("", parent)
                local function refreshTrig()
                    local idx, tok = triggerOf(name)
                    trigText.Text = idx and ("Trigger: step " .. idx .. " (" .. shortLabel(tok) .. ") - you cast it, I play the rest."
                        .. (o.trigAnim ~= "" and " Touch animation learned." or "")) or "No trigger"
                end
                sliders.trigger = tab:Slider("Trigger step # (0 = your first move)", 0, #c.steps, o.trigger, 1, function(v)
                    if o.trigger ~= v then o.trigger = v; markDirty() end
                    refreshTrig()
                end, parent)
                refreshTrig()
                tab:Button("Learn trigger (for on-screen touch buttons)", function()
                    local _, tok = triggerOf(name)
                    startLearning("combo", name, "Now cast " .. (tok and shortLabel(tok) or "the trigger move") .. " yourself, once")
                end, parent)
                tab:Button("Forget learned trigger", function()
                    if o.trigAnim ~= "" then o.trigAnim = ""; markDirty(); refreshTrig(); toast("Trigger forgotten") end
                end, parent)
                local reset = new("TextButton", {
                    Text = "Reset this combo", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text,
                    BackgroundColor3 = Theme.Panel, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 34), Parent = parent,
                }, {corner(8)})
                reset.MouseButton1Click:Connect(function()
                    for key, sl in pairs(sliders) do sl:Set(ComboOptions.DEFAULTS[key]) end
                    for key, dd in pairs(pickers) do dd:Set(ComboOptions.DEFAULTS[key]) end
                    if o.trigAnim ~= "" then o.trigAnim = ""; markDirty() end
                    refreshTrig()
                end)
            end
            ArmHandles[name] = get(key, title):Button((name:gsub("_", " ")), describe(c.steps, fullName), function()
                runMacro(c.steps, fullName, name)
            end, {
                conf = c.confidence,
                options = o and drawer or nil,
                pin = {
                    default = SavedPins[name] ~= nil,                       -- pinned last time -> pinned again
                    onChange = function(on) setPinned(name, on, c.steps, fullName) end,
                },
                assist = {onChange = function(on) setArmed(name, on) end},
            })
        end
        -- the Tech section: one on/off switch per tech. Switch it on, cast the first move yourself, the rest is played.
        local techs = {}
        for _, t in ipairs(Data.TechAssists or {}) do
            if t.character == fullName then techs[#techs + 1] = t end
        end
        if #techs > 0 then
            local techSec = get("tech", label .. " Tech")
            for _, t in ipairs(techs) do
                local key = "Tech_" .. (t.name:gsub("[^%w]+", "_"))
                ComboInfo[key] = {steps = t.steps, charName = fullName}
                techSec:Toggle(t.name, false, function(on) setArmed(key, on) end, t.desc .. "  [" .. tostring(t.confidence) .. "]")
            end
        end
        tab:Label("ASSIST: switch it on, then cast the first move yourself - I play everything after it (Kyoto: you cast Flowing Water, I do Lethal Whirlwind and the rest). Run plays the whole combo for you. On screen adds a button for it. Moves use hotbar slots 1-4 (unverified order); on a phone use Opt > Learn trigger once. Steps marked * have no key mapped and are skipped.")
    end
    if Data then
        for _, c in ipairs(CUSTOM_COMBOS) do
            if type(c) == "table" and type(c.name) == "string" and type(c.steps) == "table" and #c.steps > 0 then
                Data.Combos[c.name] = {character = c.character or "Hero Hunter", confidence = c.confidence or "custom", steps = c.steps}
            end
        end
    end
    -- Side dash: round one-tap buttons you can put on screen, plus an automatic side dash after your own moves.
    -- None of this teleports you: it presses Q + A or Q + D. "Closest" chooses A or D by where the nearest player is.
    do
        local sideSec = Main_:Section("Side dash")
        local function sideCard(name, title, desc, side, caption)
            local o = getOpts(name)
            if o then o.side = side; o.pinMode = "run" end            -- fixed: always this way, the button runs it
            ComboInfo[name] = {steps = {"SIDEDASH"}, charName = "Universal"}
            sideSec:Button(title, desc, function() runMacro({"SIDEDASH"}, "Universal", name) end, {
                conf = "custom",
                pin = {
                    default = SavedPins[name] ~= nil,
                    onChange = function(on) setPinned(name, on, {"SIDEDASH"}, "Universal", "circle", caption) end,
                },
            })
        end
        sideCard("SideDash_Closest", "Side dash toward closest player", "Q + A or Q + D, whichever side the nearest player is on. No teleport - it only dashes. On screen = round button.", "Closest", "Side Dash")
        sideCard("SideDash_Left", "Side dash left", "Q + A in one tap. On screen = round button.", "Left", "Dash Left")
        sideCard("SideDash_Right", "Side dash right", "Q + D in one tap. On screen = round button.", "Right", "Dash Right")
    end
    Main_:Toggle("Auto side dash after my moves", false, function(on)
        SideAuto.on = on
        if ready then toast(on and "Auto side dash ON - cast a move and I dash" or "Auto side dash OFF") end
    end)
    Main_:Dropdown("Side", {"Closest", "Alternate", "Left", "Right"}, SideAuto.dir, function(v)
        if SideAuto.dir ~= v then SideAuto.dir = v; markDirty() end
    end)
    Main_:Slider("Delay after my move (s)", 0, 1, SideAuto.delay, 0.05, function(v)
        if SideAuto.delay ~= v then SideAuto.delay = v; markDirty() end
    end)
    Main_:Slider("Cooldown (s)", 0.2, 3, SideAuto.cooldown, 0.1, function(v)
        if SideAuto.cooldown ~= v then SideAuto.cooldown = v; markDirty() end
    end)
    Main_:Button("Learn a move for auto side dash (cast it once)", function()
        startLearning("side", nil, "Now cast one of your moves, once")
    end)
    Main_:Button("Forget learned moves", function()
        SideAuto.anims = {}
        markDirty()
        toast("Forgot the learned moves")
    end)
    Main_:Label("Auto side dash: on a PC your hotbar keys 1-4 trigger it. On a phone tap Learn, then cast each move once so it recognises the animation. Delay is adjusted by Auto timing like the combo gaps.")
    buildCharacter(Main_, "Universal", "Universal")
    for _, ct in ipairs(CharTabs) do buildCharacter(ct.tab, ct.full, ct.short) end

    -- Timing tab
    pingLabel = Timing_:Label("Ping: measuring...")
    gapsLabel = Timing_:Label("Gaps now ...")
    do
    local function changed(tbl, key) return function(v) if tbl[key] ~= v then tbl[key] = v; markDirty() end end end
    Timing_:Toggle("Auto timing from ping", Auto.on, changed(Auto, "on"))
    Timing_:Slider("Auto strength", 0, 1.5, Auto.strength, 0.05, changed(Auto, "strength"))
    Timing_:Slider("Fine-tune (ms, + = later)", -100, 100, Auto.offsetMs, 5, changed(Auto, "offsetMs"))
    Timing_:Slider("Manual ping ms (0 = measured)", 0, 400, Auto.manualPing, 5, changed(Auto, "manualPing"))
    Timing_:Label("These are the global values. Every combo card also has an Opt button with its own overrides (speed, gaps, fine-tune, auto mode, side-dash key).")
    Timing_:Label("Auto timing shortens the gaps that wait for a visible cue (after moves and dashes) by about your ping. Your own ping only: other players' ping can't be read, and the server decides if a hit lands, so tune Fine-tune until it lands for you.")
    Timing_:Label("Base gaps (seconds between steps)")
    local gapSliders = {
        m1   = Timing_:Slider("M1 gap",   0.08, 0.6, Timing.m1,   0.01, changed(Timing, "m1")),
        dash = Timing_:Slider("Dash gap", 0.08, 0.8, Timing.dash, 0.01, changed(Timing, "dash")),
        move = Timing_:Slider("Move gap", 0.15, 1.2, Timing.move, 0.01, changed(Timing, "move")),
        jump = Timing_:Slider("Jump gap", 0.08, 0.6, Timing.jump, 0.01, changed(Timing, "jump")),
    }
    Timing_:Slider("Overall speed (higher = slower)", 0.5, 2, macroSpeed, 0.05, function(v)
        if macroSpeed ~= v then macroSpeed = v; markDirty() end
    end)
    Timing_:Button("Reset timing to defaults", function()
        for k, sl in pairs(gapSliders) do sl:Set(TimingDefaults[k]) end
    end)

    end

    -- Tech library: every tech found in research, with how sure the sources are
    if TechLib then
        local byChar, order = {}, {}
        for _, t in ipairs(Data.Techs or {}) do
            local who = t.character or "Universal"
            if not byChar[who] then byChar[who] = {}; order[#order + 1] = who end
            table.insert(byChar[who], t)
        end
        table.sort(order, function(a, b)
            if a == "Universal" then return b ~= "Universal" end
            if b == "Universal" then return false end
            return a < b
        end)
        TechLib:Label("Everything found in research (fan wikis, guides, forum posts, videos). Confidence shows how well sourced it is; a lot of it is unverified and the game is patched often.")
        for _, who in ipairs(order) do
            local sec = TechLib:Section(who .. " (" .. #byChar[who] .. ")")
            for _, t in ipairs(byChar[who]) do
                sec:Info(t.name .. "  [" .. tostring(t.confidence or "?") .. "]", t.desc)
            end
        end
    end

    -- Auto Tech
    local blockToggle
    Tech:Label("Recovers automatically when you get knocked down.")
    local techToggle = Tech:Toggle("Auto Tech", false, function(on)
        Settings.AutoTech = on
        if renderFab then renderFab() end
    end)
    Tech:Dropdown("Direction", {"Back", "Forward", "Left", "Right"}, "Back", function(v) Settings.TechDirection = v end)
    Tech:Slider("Reaction Delay (s)", 0, 0.5, 0.05, 0.01, function(v) Settings.TechDelay = v end)
    Tech:Slider("Cooldown (s)", 0.1, 3, 0.6, 0.05, function(v) Settings.TechCooldown = v end)
    Tech:Label("Dash key defaults to Q - change Settings.TechKey if you rebound it.")

    -- Auto block
    Tech:Label("AUTO BLOCK - holds F for you when a player in front of you starts an attack aimed at you. Hits from behind, charged hits and grabs cannot be blocked, so those are skipped.")
    blockToggle = Tech:Toggle("Auto block", false, function(on)
        Block.on = on
        if renderFab then renderFab() end
        if ready then toast(on and "Auto block ON" or "Auto block OFF") end
    end)
    local function blockSet(key) return function(v) if Block[key] ~= v then Block[key] = v; markDirty() end end end
    Tech:Slider("Range (studs)", 6, 30, Block.range, 1, blockSet("range"))
    Tech:Slider("Aim cone (+- degrees)", 20, 120, Block.aim, 5, blockSet("aim"))
    Tech:Slider("Delay after their swing starts (s)", 0, 0.4, Block.delay, 0.01, blockSet("delay"))
    Tech:Slider("Hold block (s)", 0.1, 1, Block.hold, 0.05, blockSet("hold"))
    Tech:Slider("Cooldown (s)", 0.1, 1, Block.cooldown, 0.05, blockSet("cooldown"))
    Tech:Toggle("Shorten the delay by my ping", Block.usePing, blockSet("usePing"))
    Tech:Label("Perfect block timing depends on each move's hit frame, which I cannot read. Delay is shortened by your ping (Auto timing strength / fine-tune apply). Start at 0.10 s and nudge it: lower = blocks sooner.")

    -- Teleports (list follows players joining / leaving)
    do
    local playerSec = Tele:Section("Players")
    local function teleportTo(p)
        local mine = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local theirs = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if mine and theirs then mine.CFrame = theirs.CFrame * CFrame.new(0, 0, 4) end
    end
    local function refreshPlayers(leaving)
        playerSec:Clear()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p ~= leaving then list[#list + 1] = p end
        end
        table.sort(list, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)
        for _, p in ipairs(list) do
            playerSec:Button(p.DisplayName, "@" .. p.Name, function() teleportTo(p) end)
        end
    end
    refreshPlayers()
    connect(Players.PlayerAdded, function() refreshPlayers() end)
    connect(Players.PlayerRemoving, function(p) refreshPlayers(p) end)
    Tele:Button("Teleport to Spawn", function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
        if hrp and spawn then hrp.CFrame = spawn.CFrame + Vector3.new(0, 5, 0) end
    end)

    end

    -- Credit
    Credit:Label("Animation Hub UI")
    Credit:Label("Toggle menu: RightShift, or the floating bar: Menu = show/hide, Tech = Auto Tech on/off, Pins = show/hide pinned buttons, Lock = freeze bar and pinned buttons, - = shrink to a dot.")
    Credit:Label("Background: random SFW image from waifu.pics / nekos.best (fan art, not copyright-free).", 40)

    -- Effects Preset: look + menu adjustments
    Effects:Label("Menu look")
    Effects:Dropdown("Theme", ThemeNames, themeName, function(v) pendingTheme = v end)
    local function rebuild()                          -- rebuild the whole menu so a new theme applies everywhere
        if genv.AH_DISABLE_REBUILD then toast("Rebuild is disabled") return end
        saveNow()
        genv.__AnimationHubUi = {theme = pendingTheme, scale = uiScale, glass = glass}
        cleanup()
        task.spawn(function()
            task.wait(0.4)
            local ok, err = pcall(__run)
            if not ok then
                warn("[Animation Hub] rebuild failed: " .. tostring(err))
                notify("Animation Hub error", tostring(err):sub(1, 180), 15)
            end
        end)
    end
    Effects:Button("Apply theme (rebuilds the menu)", rebuild)
    Effects:Slider("Menu size", 0.7, 1.25, uiScale, 0.05, function(v)
        if uiScale ~= v then
            uiScale = v
            if menuOpen then MainScale.Scale = fitScale() end
            markDirty()
        end
    end)
    Effects:Slider("Glass (higher = clearer picture)", 0.4, 0.95, glass, 0.01, function(v)
        if glass ~= v then glass = v; Veil.BackgroundTransparency = v; markDirty() end
    end)
    Effects:Label("Background image", 24)
    Effects:Slider("Image opacity", 0.1, 1, 1 - BACKGROUND_TRANSPARENCY, 0.05, function(v)
        Background.ImageTransparency = 1 - v
    end)
    Effects:Dropdown("Source", {"waifu.pics", "nekos.best"}, BACKGROUND_SOURCE, function(v) BACKGROUND_SOURCE = v end)
    Effects:Button("New random background", function() refreshBackground(BACKGROUND_SOURCE) end)
    Effects:Label("Images come from public waifu APIs (SFW endpoints). They are community fan art, so the artists keep the copyright - use your own CC0 image via BACKGROUND_URL if you need that.", 60)

    -- Predictor tab: only when combo_engine/tsb_data were bundled in (see game_dev/build_executor.py)
    if Engine and Data then
        Engine.loadData(Data)
        local Pred = createTab("Predictor", "?")
        Pred:Label("Guesses which combo you are doing from your M1 / dash / jump inputs and what usually comes next.", 40)
        local out = Pred:Label("Waiting for input...")
        out.TextSize = 13
        out.TextColor3 = Theme.Text
        local predictor = Engine.newPredictor()
        local function token(input)
            local k = input.KeyCode
            if input.UserInputType == Enum.UserInputType.MouseButton1 then return "M1" end
            if k == Enum.KeyCode.Space then return "JUMP" end
            if k == Enum.KeyCode.Q then
                local down = function(key) return UserInputService:IsKeyDown(key) end
                if down(Enum.KeyCode.W) then return "FRONTDASH" end
                if down(Enum.KeyCode.S) then return "BACKDASH" end
                if down(Enum.KeyCode.A) or down(Enum.KeyCode.D) then return "SIDEDASH" end
                return "Q"
            end
        end
        connect(UserInputService.InputBegan, function(input, gp)
            if gp then return end
            local t = token(input)
            if t then predictor:feed(t, os.clock()) end
        end)
        local acc = 0
        connect(RunService.Heartbeat, function(dt)
            acc = acc + dt
            if acc < 0.1 then return end
            acc = 0
            local now = os.clock()
            local list = predictor:predict(now)
            if #list == 0 then out.Text = "No combo detected." return end
            local lines = {}
            for i = 1, math.min(4, #list) do
                local r = list[i]
                lines[#lines + 1] = string.format("%s  %d/%d  (%d%%)  next: %s", r.name, r.progress, r.total, math.floor(r.confidence * 100), tostring(r.next))
            end
            local _, best = predictor:nextInputs(now)
            lines[#lines + 1] = "Best guess next: " .. tostring(best)
            out.Text = table.concat(lines, "\n")
        end)
    end

    ---------------------------------------------------------------- floating bar (touch "keybind")
    -- [Menu] [Tech] [Pins] [Lock] [-]
    --   Menu  show / hide this window          Tech  Auto Tech on / off
    --   Pins  show / hide the pinned buttons   Lock  freeze the bar AND the pinned buttons in place
    --   -     shrink the bar to a dot (tap the dot to bring it back). Drag the bar anywhere.
    -- Position / lock / minimised state survive re-running the script in the same game session.
    do
        local BAR_W, BAR_H, DOT = 304, 46, 38
        local saved = genv.__AnimationHubFab or {}
        local fabState = {x = saved.x, y = saved.y, locked = saved.locked == true, minimized = saved.minimized == true}
        local vw0 = viewport()
        fabState.x = fabState.x or math.floor(((vw0 or 800) - BAR_W) / 2)     -- top centre: clear of the thumbsticks
        fabState.y = fabState.y or 10

        local tracker = DragTracker and DragTracker.new(8)    -- no tracker (unbundled file): bar is simply fixed
        if tracker then tracker:setLocked(fabState.locked) end
        setPinsLocked(fabState.locked)

        local fab = new("Frame", {
            Size = UDim2.fromOffset(BAR_W, BAR_H), Position = UDim2.fromOffset(fabState.x, fabState.y),
            BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.08, ZIndex = 10, Parent = Gui,
        }, {corner(23), gloss(nil, 23, 1)})
        local fabScale = new("UIScale", {Scale = 0, Parent = fab})
        local fabStroke = stroke(Theme.White, 1.5, 0.2)
        fabStroke.Parent = fab
        accentGradient(fabStroke, 0)

        local function isPointer(i)
            return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
        end
        local function attachDrag(obj)
            if not tracker then return end
            obj.InputBegan:Connect(function(i)
                if isPointer(i) then tracker:begin(i.Position.X, i.Position.Y, fabState.x, fabState.y) end
            end)
        end
        local function paint(btn, on)
            tween(btn, {BackgroundColor3 = on and Theme.Accent or Theme.Item, TextColor3 = on and Theme.Back or Theme.Text}, 0.2)
        end
        local function tappable(onTap)
            return function()
                if tracker and tracker:suppressClick(os.clock()) then return end   -- that "click" was the end of a drag
                onTap()
            end
        end
        local function barButton(text, x, w, onTap)
            local b = new("TextButton", {
                Text = text, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Theme.Text,
                BackgroundColor3 = Theme.Item, AutoButtonColor = false,
                Size = UDim2.fromOffset(w, BAR_H - 10), Position = UDim2.fromOffset(x, 5), ZIndex = 11, Parent = fab,
            }, {corner(15)})
            b.MouseButton1Click:Connect(tappable(onTap))
            b.MouseButton1Down:Connect(function() tween(b, {Size = UDim2.fromOffset(w - 4, BAR_H - 14), Position = UDim2.fromOffset(x + 2, 7)}, 0.07) end)
            local function release() tween(b, {Size = UDim2.fromOffset(w, BAR_H - 10), Position = UDim2.fromOffset(x, 5)}, 0.2, Enum.EasingStyle.Back) end
            b.MouseButton1Up:Connect(release)
            b.MouseLeave:Connect(release)
            attachDrag(b)
            return b
        end

        local menuBtn, techBtn, blockBtn, pinsBtn, lockBtn, minBtn, dot
        local function place()
            local w, h = BAR_W, BAR_H
            if fabState.minimized then w, h = DOT, DOT end
            local vw, vh = viewport()
            if DragTracker and vw then
                fabState.x, fabState.y = DragTracker.clamp(fabState.x, fabState.y, w, h, vw, vh, 4)
            end
            fab.Size = UDim2.fromOffset(w, h)
            fab.Position = UDim2.fromOffset(fabState.x, fabState.y)
            genv.__AnimationHubFab = fabState
        end
        renderFab = function()
            paint(menuBtn, menuOpen)
            paint(techBtn, Settings.AutoTech)
            techBtn.Text = Settings.AutoTech and "Tech ON" or "Tech OFF"
            paint(blockBtn, Block.on)
            blockBtn.Text = Block.on and "Block ON" or "Block"
            paint(pinsBtn, pinsVisible and #pinOrder > 0)
            pinsBtn.Text = #pinOrder > 0 and ("Pins " .. #pinOrder) or "Pins"
            paint(lockBtn, fabState.locked)
            lockBtn.Text = fabState.locked and "Locked" or "Lock"
            for _, b in ipairs({menuBtn, techBtn, blockBtn, pinsBtn, lockBtn, minBtn}) do b.Visible = not fabState.minimized end
            dot.Visible = fabState.minimized
            place()
        end

        menuBtn = barButton("Menu", 4, 46, toggleMenu)
        techBtn = barButton("Tech OFF", 54, 56, function() techToggle:Set(not techToggle:Get()) end)
        blockBtn = barButton("Block", 114, 54, function() blockToggle:Set(not blockToggle:Get()) end)
        pinsBtn = barButton("Pins", 172, 46, function()
            if #pinOrder == 0 then toast("Nothing pinned yet - turn On screen on for a combo") return end
            setPinsVisible(not pinsVisible)
            toast(pinsVisible and "Pinned buttons shown" or "Pinned buttons hidden")
        end)
        lockBtn = barButton("Lock", 222, 50, function()
            fabState.locked = not fabState.locked
            if tracker then tracker:setLocked(fabState.locked) end
            setPinsLocked(fabState.locked)
            toast(fabState.locked and "Locked: the bar and pinned buttons stay where they are" or "Unlocked: drag them anywhere")
            renderFab()
        end)
        minBtn = barButton("-", 276, 24, function() fabState.minimized = true; renderFab() end)
        dot = new("TextButton", {
            Text = "AH", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Theme.Back,
            BackgroundColor3 = Theme.White, AutoButtonColor = false, Visible = false,
            Size = UDim2.fromOffset(DOT - 8, DOT - 8), Position = UDim2.fromOffset(4, 4), ZIndex = 11, Parent = fab,
        }, {corner(15), accentGradient(nil, 0)})
        dot.MouseButton1Click:Connect(tappable(function() fabState.minimized = false; renderFab() end))
        attachDrag(dot)
        attachDrag(fab)

        if tracker then
            connect(UserInputService.InputChanged, function(i)
                if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
                local nx, ny = tracker:move(i.Position.X, i.Position.Y)
                if nx then fabState.x, fabState.y = nx, ny; place() end
            end)
            connect(UserInputService.InputEnded, function(i)
                if isPointer(i) then tracker:finish(os.clock()) end
            end)
        end

        -- keep everything on screen when the screen rotates / resizes
        local cam = workspace.CurrentCamera
        local sig = cam and safe(function() return cam:GetPropertyChangedSignal("ViewportSize") end)
        if sig then
            connect(sig, function()
                place()
                for _, p in pairs(Pins) do placePin(p) end
            end)
        end

        renderFab()
        tween(fabScale, {Scale = 1}, 0.55, Enum.EasingStyle.Back)       -- pops in so you notice it
    end

    ready = true                       -- from here on, changing a slider marks the settings as unsaved
    dirty = next(Saved) ~= nil         -- a loaded file is re-written once in its cleaned-up form
    Main_:Select()
    setMenu(true)                      -- fade + scale the window in
    notify("Animation Hub", "Ready - the floating bar is at the top of your screen (Menu / Tech / Pins / Lock). RightShift also toggles the menu.", 7)
    print("[Animation Hub] ready, UI parent: " .. tostring(Gui.Parent and Gui.Parent.Name))

    -- soft game check: warn (never block) if this is not The Strongest Battlegrounds
    task.spawn(function()
        local ok, info = pcall(function()
            return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
        end)
        if ok and info and not info:lower():find("strongest battlegrounds") then
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "Animation Hub", Text = "This place is '" .. info .. "', not TSB. Auto Tech is tuned for TSB.", Duration = 6,
                })
            end)
        end
    end)

end

-- run guarded so a failure shows a message instead of silently doing nothing (common on mobile executors)
local ok, err = pcall(__run)
if not ok then
    warn("[Animation Hub] failed to start: " .. tostring(err))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Animation Hub error", Text = tostring(err):sub(1, 180), Duration = 15,
        })
    end)
end
