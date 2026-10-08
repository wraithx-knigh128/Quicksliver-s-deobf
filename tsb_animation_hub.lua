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

    local httpRequest = request or http_request or (syn and syn.request)
    local function httpGet(url)
        if httpRequest then
            local res = safe(httpRequest, {Url = url, Method = "GET"})
            if res and res.StatusCode == 200 then return res.Body end
        end
        return safe(function() return game:HttpGet(url) end)
    end

    local BgSources = {
        ["waifu.pics"] = {api = "https://api.waifu.pics/sfw/waifu", parse = function(j) return j.url end},
        ["nekos.best"] = {api = "https://nekos.best/api/v2/waifu", parse = function(j) return j.results and j.results[1] and j.results[1].url end},
    }
    local bgCounter = 0

    -- download one image url -> executor asset id (png/jpg only, Roblox cannot show gif/webp)
    local function imageToAsset(url)
        local ext = url:match("%.(%w+)$") and url:match("%.(%w+)$"):lower()
        if ext ~= "png" and ext ~= "jpg" and ext ~= "jpeg" then return nil end
        if not (getcustomasset and writefile) then return nil end
        local body = httpGet(url)
        if not body then return nil end
        bgCounter = bgCounter + 1
        local path = ("animation_hub_bg_%d.%s"):format(bgCounter, ext)
        if not safe(writefile, path, body) then return nil end
        return safe(getcustomasset, path)
    end

    local function loadBackground(sourceName)
        if BACKGROUND_URL ~= "" and not sourceName then return imageToAsset(BACKGROUND_URL) end
        local src = BgSources[sourceName or BACKGROUND_SOURCE] or BgSources["waifu.pics"]
        for _ = 1, 4 do                                   -- retry: the API may hand back a gif/webp
            local raw = httpGet(src.api)
            local data = raw and safe(function() return game:GetService("HttpService"):JSONDecode(raw) end)
            local url = data and safe(src.parse, data)
            local asset = url and imageToAsset(url)
            if asset then return asset end
        end
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
    local function refreshBackground(sourceName)
        task.spawn(function()
            local asset = loadBackground(sourceName)
            if asset then Background.Image = asset end
        end)
    end
    refreshBackground()

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

        local tab = {Btn = btn, Page = page}
        function tab:Select()
            if currentTab then
                local c = currentTab
                c.Page.Visible = false
                tween(c.Btn, {BackgroundTransparency = 1, TextColor3 = Theme.SubText}, 0.2)
                tween(c.Btn:FindFirstChildOfClass("Frame"), {Size = UDim2.fromOffset(3, 0)}, 0.2)
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
        local function row(height, parent)
            return new("Frame", {
                Size = UDim2.new(1, 0, 0, height or 40), BackgroundColor3 = Theme.Item,
                BackgroundTransparency = 0.25, Parent = parent or page,
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

        function tab:Label(text, height)
            local r = row(height or 28)
            r.BackgroundTransparency = 1
            local l = label(r, text, 12, Theme.SubText, UDim2.fromOffset(4, 0), Enum.Font.Gotham)
            l.Size = UDim2.new(1, -8, 1, 0)
            l.TextWrapped = true
            l.TextYAlignment = Enum.TextYAlignment.Top
            return l
        end

        function tab:Toggle(text, default, cb, parent)
            local r = row(40, parent)
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

        -- collapsible section with card buttons / toggles (like the reference UI)
        function tab:Section(title)
            local holder = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, Parent = page,
            }, {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
            local head = new("TextButton", {
                Text = title, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 30), AutoButtonColor = false, LayoutOrder = 0, Parent = holder,
            })
            local arrow = new("TextLabel", {
                Text = "^", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Accent,
                BackgroundTransparency = 1, Position = UDim2.new(1, -24, 0, 0), Size = UDim2.fromOffset(20, 30), Parent = head,
            })
            local body = new("Frame", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, LayoutOrder = 1, Parent = holder,
            }, {new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})})
            local open = true
            head.MouseButton1Click:Connect(function()
                open = not open
                body.Visible = open
                arrow.Text = open and "^" or "v"
            end)

            local sec = {}
            function sec:Button(name, desc, cb)
                local card = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = Theme.Item,
                    BackgroundTransparency = 0.35, Parent = body,
                }, {corner(10)})
                new("TextLabel", {
                    Text = name, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -60, 0, 18), Parent = card,
                })
                new("TextLabel", {
                    Text = desc or "", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Theme.SubText,
                    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                    BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -60, 0, 18), Parent = card,
                })
                new("TextLabel", {
                    Text = ">", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Theme.Accent,
                    BackgroundTransparency = 1, Position = UDim2.new(1, -40, 0, 0), Size = UDim2.fromOffset(30, 58), Parent = card,
                })
                local hit = new("TextButton", {
                    Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), AutoButtonColor = false, Parent = card,
                })
                hit.MouseEnter:Connect(function() tween(card, {BackgroundTransparency = 0.15}, 0.15) end)
                hit.MouseLeave:Connect(function() tween(card, {BackgroundTransparency = 0.35}, 0.15) end)
                hit.MouseButton1Click:Connect(function()
                    tween(card, {BackgroundColor3 = Theme.Accent}, 0.1).Completed:Connect(function()
                        tween(card, {BackgroundColor3 = Theme.Item}, 0.25)
                    end)
                    task.spawn(cb)
                end)
            end
            function sec:Toggle(name, default, cb) return tab:Toggle(name, default, cb, body) end
            return sec
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

    ---------------------------------------------------------------- macro runner
    -- Plays a combo from tsb_data as real inputs. Move slots assume the hotbar order = the move list
    -- order in tsb_data (1..4). That order is UNVERIFIED: if a move fires the wrong skill, edit MoveSlots.
    local MoveSlots = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four}
    local macroSpeed, macroRunning = 1, false

    local function click()
        local c = Camera.ViewportSize / 2
        VirtualInput:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 0)
        task.wait(0.03)
        VirtualInput:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 0)
    end
    local function hold(key, t) press(key, t) end
    local function dash(dirKey)
        if dirKey then VirtualInput:SendKeyEvent(true, dirKey, false, game) end
        press(Enum.KeyCode.Q, 0.04)
        if dirKey then task.wait(0.03); VirtualInput:SendKeyEvent(false, dirKey, false, game) end
    end

    -- returns the delay after the step, or nil if this token cannot be played
    local function playToken(tok, charName)
        if tok == "M1" then click() return 0.2 end
        if tok == "Q" then dash(nil) return 0.3 end
        if tok == "FRONTDASH" then dash(Enum.KeyCode.W) return 0.3 end
        if tok == "BACKDASH" then dash(Enum.KeyCode.S) return 0.3 end
        if tok == "SIDEDASH" then dash(Enum.KeyCode.A) return 0.3 end
        if tok == "JUMP" then hold(Enum.KeyCode.Space, 0.05) return 0.25 end
        local char = Data and Data.Characters[charName]
        if char and char.moves then
            for i, mv in ipairs(char.moves) do
                if mv == tok and MoveSlots[i] then hold(MoveSlots[i], 0.05) return 0.5 end
            end
        end
        return nil
    end

    local function runMacro(steps, charName)
        if macroRunning then macroRunning = false return end   -- press again to stop
        macroRunning = true
        task.spawn(function()
            for _, tok in ipairs(steps) do
                if not macroRunning then break end
                local d = playToken(tok, charName)
                task.wait((d or 0) * macroSpeed)
            end
            macroRunning = false
        end)
    end

    local function describe(steps)   -- "M1 x3 > SIDEDASH > FLOWING WATER ..."
        local out, i = {}, 1
        while i <= #steps do
            local j = i
            while steps[j + 1] == steps[i] do j = j + 1 end
            local name = steps[i]:gsub("_", " ")
            out[#out + 1] = (j > i) and (name .. " x" .. (j - i + 1)) or name
            i = j + 1
        end
        return table.concat(out, " > ")
    end

    ---------------------------------------------------------------- tabs
    local Main_  = createTab("Main", "#")
    local Credit = createTab("Credit", "+")
    local Saitama = Data and createTab("Saitama", "S")
    local Garou   = Data and createTab("Garou", "G")
    local Tech   = createTab("Auto Tech", "*")
    local Tele   = createTab("Teleports", "@")
    local Effects = createTab("Effects Preset", "~")

    -- character tabs built from tsb_data (only when bundled in)
    local function buildCharacter(tab, fullName, label, sectionNames)
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
            elseif name:find("Catch") then key, title = "tech", label .. " tech" end
            get(key, title):Button(name:gsub("_", " ") .. "  [" .. c.confidence .. "]", describe(c.steps), function()
                runMacro(c.steps, fullName)
            end)
        end
        tab:Slider("Macro speed (higher = slower)", 0.5, 2, 1, 0.05, function(v) macroSpeed = v end)
        tab:Label("Tap a card to play the combo as inputs, tap again to stop. Moves use hotbar slots 1-4 (unverified order).", 40)
    end
    buildCharacter(Saitama, "The Strongest Hero", "Saitama")
    buildCharacter(Garou, "Hero Hunter", "Garou")

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
    Credit:Label("Background: random SFW image from waifu.pics / nekos.best (fan art, not copyright-free).", 40)

    -- Effects Preset
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
        local out = Pred:Label("Waiting for input...", 120)
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
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            local t = token(input)
            if t then predictor:feed(t, os.clock()) end
        end)
        local acc = 0
        RunService.Heartbeat:Connect(function(dt)
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
