--[[
    Animation Hub - The Strongest Battlegrounds
    Smooth sidebar UI + Auto Tech

    Setup:
      * Set BACKGROUND_URL to a direct link to an image you have the right to use
        (public domain / CC0 / your own art). Leave it "" for a plain gradient.
      * Run in your executor. Needs getcustomasset + writefile for the image;
        everything else works without them.

    Auto Tech: when you get knocked down / ragdolled it waits a short delay and
    presses the dash key in the chosen direction so you recover instantly.
    Delay / cooldown / direction are adjustable in the "Auto Tech" tab.
]]

local BACKGROUND_URL = ""   -- e.g. "https://example.com/my_cc0_image.png"
local BACKGROUND_TRANSPARENCY = 0.55

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
    local Camera      = workspace.CurrentCamera

    ---------------------------------------------------------------- helpers
    local function safe(fn, ...)
        local ok, res = pcall(fn, ...)
        if ok then return res end
    end

    local function guiParent()
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

    local function loadBackground()
        if BACKGROUND_URL == "" or not (getcustomasset and writefile) then return nil end
        local req = request or http_request or (syn and syn.request)
        if not req then return nil end
        local res = safe(req, {Url = BACKGROUND_URL, Method = "GET"})
        if not res or res.StatusCode ~= 200 then return nil end
        local path = "animation_hub_bg.png"
        if not safe(writefile, path, res.Body) then return nil end
        return safe(getcustomasset, path)
    end

    ---------------------------------------------------------------- theme
    local Theme = {
        Back     = Color3.fromRGB(24, 18, 26),
        Panel    = Color3.fromRGB(38, 28, 42),
        Item     = Color3.fromRGB(52, 38, 58),
        Accent   = Color3.fromRGB(255, 120, 180),
        Text     = Color3.fromRGB(245, 235, 245),
        SubText  = Color3.fromRGB(190, 170, 190),
    }

    ---------------------------------------------------------------- cleanup old
    local old = guiParent():FindFirstChild("AnimationHubTSB")
    if old then old:Destroy() end

    ---------------------------------------------------------------- window
    local Gui = new("ScreenGui", {
        Name = "AnimationHubTSB", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
    })
    Gui.Parent = guiParent()

    local Main = new("Frame", {
        Size = UDim2.fromOffset(580, 380), Position = UDim2.new(0.5, -290, 0.5, -190),
        BackgroundColor3 = Theme.Back, BorderSizePixel = 0, ClipsDescendants = true,
        Parent = Gui,
    }, {corner(14), stroke(Theme.Accent, 1.5, 0.6)})

    -- background image (optional, loaded in the background so the UI never freezes)
    new("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(60, 36, 70), Color3.fromRGB(24, 18, 26)),
        Rotation = 45, Parent = Main,
    })
    local Background = new("ImageLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "",
        ScaleType = Enum.ScaleType.Crop, ImageTransparency = BACKGROUND_TRANSPARENCY,
        ZIndex = 0, Parent = Main,
    }, {corner(14)})
    task.spawn(function()
        local asset = loadBackground()
        if asset then Background.Image = asset end
    end)

    -- title bar
    local TopBar = new("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = Main})
    new("TextLabel", {
        Text = "Animation Hub", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 8), Size = UDim2.new(1, -140, 0, 20), Parent = TopBar,
    })
    new("TextLabel", {
        Text = "The Strongest Battlegrounds", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 28), Size = UDim2.new(1, -140, 0, 16), Parent = TopBar,
    })

    local function topButton(text, xOff, cb)
        local b = new("TextButton", {
            Text = text, Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Theme.Accent,
            BackgroundTransparency = 1, Size = UDim2.fromOffset(32, 32),
            Position = UDim2.new(1, xOff, 0, 10), AutoButtonColor = false, Parent = TopBar,
        })
        b.MouseEnter:Connect(function() tween(b, {TextColor3 = Theme.Text}, 0.15) end)
        b.MouseLeave:Connect(function() tween(b, {TextColor3 = Theme.Accent}, 0.15) end)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    local minimized = false
    local fullSize = Main.Size
    topButton("-", -108, function()
        minimized = not minimized
        tween(Main, {Size = minimized and UDim2.fromOffset(fullSize.X.Offset, 52) or fullSize}, 0.3)
    end)
    topButton("X", -40, function()
        tween(Main, {Size = UDim2.fromOffset(fullSize.X.Offset, 0)}, 0.25).Completed:Wait()
        Gui:Destroy()
    end)

    -- dragging
    do
        local dragging, dragStart, startPos
        TopBar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging, dragStart, startPos = true, i.Position, Main.Position
                i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - dragStart
                tween(Main, {Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)}, 0.08, Enum.EasingStyle.Linear)
            end
        end)
    end

    -- toggle UI with RightShift
    UserInputService.InputBegan:Connect(function(i, gp)
        if not gp and i.KeyCode == Enum.KeyCode.RightShift then Main.Visible = not Main.Visible end
    end)

    -- floating button for touch devices (no keyboard to press RightShift)
    do
        local fab = new("TextButton", {
            Text = "AH", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text,
            Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 12, 0.5, -22),
            BackgroundColor3 = Theme.Accent, AutoButtonColor = true, ZIndex = 10, Parent = Gui,
        }, {corner(22)})
        fab.MouseButton1Click:Connect(function() Main.Visible = not Main.Visible end)
    end

    ---------------------------------------------------------------- sidebar / pages
    local Sidebar = new("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 56), Size = UDim2.new(0, 160, 1, -112),
        BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = Main,
    }, {
        new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
        new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}),
    })

    local Content = new("Frame", {
        Position = UDim2.fromOffset(170, 56), Size = UDim2.new(1, -184, 1, -70),
        BackgroundTransparency = 1, Parent = Main,
    })

    -- footer: player card
    local Card = new("Frame", {
        Position = UDim2.new(0, 10, 1, -50), Size = UDim2.fromOffset(140, 40),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.25, Parent = Main,
    }, {corner(10)})
    new("TextLabel", {
        Text = LocalPlayer.DisplayName, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text,
        BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(46, 4), Size = UDim2.new(1, -52, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = Card,
    })
    new("TextLabel", {
        Text = "@" .. LocalPlayer.Name, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Theme.SubText,
        BackgroundTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(46, 20), Size = UDim2.new(1, -52, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = Card,
    })
    local avatar = new("ImageLabel", {
        Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(8, 5),
        BackgroundColor3 = Theme.Item, Parent = Card,
    }, {corner(15)})
    task.spawn(function()
        local img = safe(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        if img then avatar.Image = img end
    end)

    local Tabs, currentTab = {}, nil

    local function createTab(name, icon)
        local btn = new("TextButton", {
            Text = "   " .. icon .. "  " .. name, Font = Enum.Font.GothamMedium, TextSize = 14,
            TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = Theme.Panel, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 36), AutoButtonColor = false, Parent = Sidebar,
        }, {corner(8)})
        local bar = new("Frame", {
            Size = UDim2.fromOffset(3, 0), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = btn,
        }, {corner(2)})

        local page = new("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
            ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0,
            Parent = Content,
        }, {
            new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
            new("UIPadding", {PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2)}),
        })

        local tab = {Button = btn, Page = page}
        function tab:Select()
            if currentTab then
                local c = currentTab
                c.Page.Visible = false
                tween(c.Button, {BackgroundTransparency = 1, TextColor3 = Theme.SubText}, 0.2)
                tween(c.Button:FindFirstChildOfClass("Frame"), {Size = UDim2.fromOffset(3, 0)}, 0.2)
            end
            currentTab = tab
            page.Visible = true
            tween(btn, {BackgroundTransparency = 0.35, TextColor3 = Theme.Text}, 0.2)
            tween(bar, {Size = UDim2.fromOffset(3, 20)}, 0.25)
        end
        btn.MouseButton1Click:Connect(function() tab:Select() end)
        btn.MouseEnter:Connect(function() if currentTab ~= tab then tween(btn, {BackgroundTransparency = 0.7}, 0.15) end end)
        btn.MouseLeave:Connect(function() if currentTab ~= tab then tween(btn, {BackgroundTransparency = 1}, 0.15) end end)

        -- elements ------------------------------------------------------
        local function row(height)
            return new("Frame", {
                Size = UDim2.new(1, 0, 0, height or 40), BackgroundColor3 = Theme.Item,
                BackgroundTransparency = 0.25, Parent = page,
            }, {corner(8)})
        end
        local function label(parent, text, size, color, pos, font)
            return new("TextLabel", {
                Text = text, Font = font or Enum.Font.GothamMedium, TextSize = size or 13,
                TextColor3 = color or Theme.Text, BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                Position = pos or UDim2.fromOffset(12, 0), Size = UDim2.new(1, -80, 1, 0), Parent = parent,
            })
        end

        function tab:Label(text)
            local r = row(28)
            r.BackgroundTransparency = 1
            label(r, text, 12, Theme.SubText, UDim2.fromOffset(4, 0), Enum.Font.Gotham).Size = UDim2.new(1, -8, 1, 0)
        end

        function tab:Toggle(text, default, cb)
            local r = row(40)
            label(r, text)
            local track = new("TextButton", {
                Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(40, 20),
                Position = UDim2.new(1, -52, 0.5, -10), BackgroundColor3 = Theme.Panel, Parent = r,
            }, {corner(10)})
            local knob = new("Frame", {
                Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3),
                BackgroundColor3 = Theme.Text, Parent = track,
            }, {corner(7)})
            local state = default and true or false
            local function render(animate)
                local t = animate and 0.2 or 0
                tween(track, {BackgroundColor3 = state and Theme.Accent or Theme.Panel}, t)
                tween(knob, {Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)}, t)
            end
            render(false)
            track.MouseButton1Click:Connect(function()
                state = not state
                render(true)
                task.spawn(cb, state)
            end)
            task.spawn(cb, state)
        end

        function tab:Button(text, cb)
            local r = row(40)
            local b = new("TextButton", {
                Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text,
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, AutoButtonColor = false, Parent = r,
            })
            b.MouseEnter:Connect(function() tween(r, {BackgroundTransparency = 0.05}, 0.15) end)
            b.MouseLeave:Connect(function() tween(r, {BackgroundTransparency = 0.25}, 0.15) end)
            b.MouseButton1Click:Connect(function()
                tween(r, {BackgroundColor3 = Theme.Accent}, 0.1).Completed:Connect(function()
                    tween(r, {BackgroundColor3 = Theme.Item}, 0.25)
                end)
                task.spawn(cb)
            end)
        end

        function tab:Slider(text, min, max, default, step, cb)
            local r = row(54)
            label(r, text, 13, Theme.Text, UDim2.fromOffset(12, 4)).Size = UDim2.new(1, -80, 0, 20)
            local val = new("TextLabel", {
                Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Accent, BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -72, 0, 4),
                Size = UDim2.fromOffset(60, 20), Parent = r,
            })
            local rail = new("TextButton", {
                Text = "", AutoButtonColor = false, Position = UDim2.new(0, 12, 1, -16),
                Size = UDim2.new(1, -24, 0, 6), BackgroundColor3 = Theme.Panel, Parent = r,
            }, {corner(3)})
            local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = rail}, {corner(3)})
            local value = default
            local function set(v, fire)
                v = math.clamp(math.floor(v / step + 0.5) * step, min, max)
                value = v
                val.Text = tostring(math.floor(v * 100 + 0.5) / 100)
                tween(fill, {Size = UDim2.fromScale((v - min) / (max - min), 1)}, 0.08, Enum.EasingStyle.Linear)
                if fire then task.spawn(cb, v) end
            end
            set(default, true)
            local dragging = false
            local function fromInput(i)
                local a = math.clamp((i.Position.X - rail.AbsolutePosition.X) / rail.AbsoluteSize.X, 0, 1)
                set(min + (max - min) * a, true)
            end
            rail.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    dragging = true; fromInput(i)
                end
            end)
            UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
            end)
            UserInputService.InputChanged:Connect(function(i)
                if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromInput(i) end
            end)
        end

        function tab:Dropdown(text, options, default, cb)
            local r = row(40)
            label(r, text)
            local b = new("TextButton", {
                Text = default, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Accent,
                BackgroundColor3 = Theme.Panel, AutoButtonColor = false,
                Size = UDim2.fromOffset(110, 26), Position = UDim2.new(1, -122, 0.5, -13), Parent = r,
            }, {corner(6)})
            local i = table.find(options, default) or 1
            b.MouseButton1Click:Connect(function()
                i = i % #options + 1
                b.Text = options[i]
                task.spawn(cb, options[i])
            end)
            task.spawn(cb, options[i])
        end

        Tabs[#Tabs + 1] = tab
        return tab
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

    local function press(key, hold)
        VirtualInput:SendKeyEvent(true, key, false, game)
        task.wait(hold or 0.03)
        VirtualInput:SendKeyEvent(false, key, false, game)
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

    local function doTech()
        if os.clock() - lastTech < Settings.TechCooldown then return end
        lastTech = os.clock()
        task.wait(Settings.TechDelay)
        local dir = DirectionKeys[Settings.TechDirection]
        task.spawn(function()
            if dir then VirtualInput:SendKeyEvent(true, dir, false, game) end
            press(Settings.TechKey, 0.04)
            if dir then task.wait(0.05); VirtualInput:SendKeyEvent(false, dir, false, game) end
        end)
    end

    local wasKnocked = false
    RunService.Heartbeat:Connect(function()
        if not Settings.AutoTech then wasKnocked = false return end
        local knocked = isKnocked(LocalPlayer.Character)
        if knocked and not wasKnocked then doTech() end
        wasKnocked = knocked
    end)

    ---------------------------------------------------------------- tabs
    local Main_  = createTab("Main", "#")
    local Tech   = createTab("Auto Tech", "*")
    local Tele   = createTab("Teleports", "@")
    local Credit = createTab("Credit", "+")

    -- Main
    Main_:Label("General utilities")
    Main_:Slider("WalkSpeed", 16, 120, 16, 1, function(v)
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end)
    Main_:Toggle("Anti AFK", true, function(on)
        if not on then return end
        LocalPlayer.Idled:Connect(function()
            VirtualInput:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            VirtualInput:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end)
    Main_:Button("Reset Character", function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end)

    -- Auto Tech
    Tech:Label("Recovers automatically when you get knocked down.")
    Tech:Toggle("Auto Tech", false, function(on) Settings.AutoTech = on end)
    Tech:Dropdown("Direction", {"Back", "Forward", "Left", "Right"}, "Back", function(v) Settings.TechDirection = v end)
    Tech:Slider("Reaction Delay (s)", 0, 0.5, 0.05, 0.01, function(v) Settings.TechDelay = v end)
    Tech:Slider("Cooldown (s)", 0.1, 3, 0.6, 0.05, function(v) Settings.TechCooldown = v end)
    Tech:Label("Dash key defaults to Q - change Settings.TechKey if you rebound it.")

    -- Teleports
    Tele:Label("Teleport to a player")
    local function refreshPlayers()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                Tele:Button(p.DisplayName .. " (@" .. p.Name .. ")", function()
                    local mine = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    local theirs = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    if mine and theirs then mine.CFrame = theirs.CFrame * CFrame.new(0, 0, 4) end
                end)
            end
        end
    end
    refreshPlayers()
    Tele:Button("Teleport to Spawn", function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
        if hrp and spawn then hrp.CFrame = spawn.CFrame + Vector3.new(0, 5, 0) end
    end)

    -- Credit
    Credit:Label("Animation Hub UI")
    Credit:Label("Toggle menu: RightShift")
    Credit:Label("Background: set BACKGROUND_URL at the top of the script.")

    Main_:Select()

    -- open animation
    Main.Size = UDim2.fromOffset(fullSize.X.Offset, 0)
    tween(Main, {Size = fullSize}, 0.45, Enum.EasingStyle.Back)

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
