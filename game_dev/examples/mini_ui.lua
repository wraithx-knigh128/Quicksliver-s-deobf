--[[
    mini_ui.lua - a small, complete "glass sidebar" menu for Roblox Studio.
    Put it in a LocalScript inside StarterPlayer > StarterPlayerScripts and press Play.
    It shows the same building blocks as the big hub: CanvasGroup window, rounded corners, gradient border,
    sidebar tabs with an active indicator, fading pages, a toggle switch, a card, and smooth TweenService animation.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local function tween(obj, props, t, style)
    TweenService:Create(obj, TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
end

-- tiny helper: create an Instance, set its properties, add children
local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    return inst
end
local function corner(r) return new("UICorner", {CornerRadius = UDim.new(0, r)}) end

local ACCENT, ACCENT2 = Color3.fromRGB(255, 112, 176), Color3.fromRGB(160, 112, 255)

local gui = new("ScreenGui", {Name = "MiniUI", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = Players.LocalPlayer:WaitForChild("PlayerGui")})

-- 1. the window: a CanvasGroup fades and scales as ONE piece (children included)
local window = new("CanvasGroup", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 320),
    BackgroundColor3 = Color3.fromRGB(34, 24, 54), GroupTransparency = 1, Parent = gui,
}, {
    corner(18),
    new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(96, 58, 134), Color3.fromRGB(30, 20, 50)), Rotation = 60}),
})
local scale = new("UIScale", {Scale = 0.92, Parent = window})
local rim = new("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 1.5, Parent = window})
new("UIGradient", {Color = ColorSequence.new(ACCENT, ACCENT2), Rotation = 45, Parent = rim})   -- gradient border

-- 2. sidebar + content area
local sidebar = new("Frame", {Size = UDim2.new(0, 140, 1, -20), Position = UDim2.fromOffset(10, 10),
    BackgroundColor3 = Color3.fromRGB(54, 38, 78), BackgroundTransparency = 0.4, Parent = window},
    {corner(14), new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
     new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)})})
local content = new("Frame", {Size = UDim2.new(1, -170, 1, -20), Position = UDim2.fromOffset(160, 10),
    BackgroundTransparency = 1, Parent = window})

-- 3. tabs: each tab = a sidebar button + a page (a CanvasGroup so it can fade)
local tabs, current = {}, nil
local function addTab(name)
    local button = new("TextButton", {Text = name, Font = Enum.Font.GothamMedium, TextSize = 14,
        TextColor3 = Color3.fromRGB(200, 182, 218), BackgroundColor3 = ACCENT, BackgroundTransparency = 1,
        AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 36), Parent = sidebar}, {corner(10)})
    local page = new("CanvasGroup", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1,
        Visible = false, Parent = content}, {new("UIListLayout", {Padding = UDim.new(0, 8)})})
    local tab = {button = button, page = page}
    function tab.select()                                   -- show this tab, hide the current one
        if current == tab then return end
        if current then
            tween(current.button, {BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(200, 182, 218)})
            tween(current.page, {GroupTransparency = 1}, 0.12)
            local old = current.page
            task.delay(0.14, function() if current and current.page ~= old then old.Visible = false end end)
        end
        current = tab
        page.Visible = true
        page.Position = UDim2.fromOffset(0, 14)
        tween(page, {GroupTransparency = 0, Position = UDim2.fromOffset(0, 0)}, 0.3)
        tween(button, {BackgroundTransparency = 0.35, TextColor3 = Color3.new(1, 1, 1)})
    end
    button.MouseButton1Click:Connect(tab.select)
    tabs[#tabs + 1] = tab
    return page
end

-- 4. widgets
local function addToggle(page, text, callback)
    local row = new("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(76, 56, 106),
        BackgroundTransparency = 0.3, Parent = page}, {corner(12)})
    new("TextLabel", {Text = text, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -80, 1, 0), Parent = row})
    local track = new("Frame", {Size = UDim2.fromOffset(46, 24), Position = UDim2.new(1, -58, 0.5, -12),
        BackgroundColor3 = Color3.fromRGB(54, 38, 78), Parent = row}, {corner(12)})
    local knob = new("Frame", {Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = track}, {corner(9)})
    local hit = new("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = row})
    local on = false
    hit.MouseButton1Click:Connect(function()
        on = not on
        tween(track, {BackgroundColor3 = on and ACCENT or Color3.fromRGB(54, 38, 78)})
        tween(knob, {Position = on and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)}, 0.28, Enum.EasingStyle.Back)
        callback(on)
    end)
end

local home = addTab("Home")
local combat = addTab("Combat")
addToggle(home, "Example toggle", function(on) print("toggle:", on) end)
addToggle(combat, "Auto thing", function(on) print("auto:", on) end)

-- 5. open: select the first tab and fade + pop the window in
tabs[1].select()
tween(window, {GroupTransparency = 0}, 0.3)
tween(scale, {Scale = 1}, 0.45, Enum.EasingStyle.Back)
