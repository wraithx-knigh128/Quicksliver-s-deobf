-- RideAPet.lua, deobfuscated by QuickSilver (static analysis; nothing in it was run), wrapped so it can be started with loadstring.
-- Same program as RideAPet.deobf.lua: this file only holds that source in a long string and runs it with the arguments it was given.
return (loadstring or load)([==[
--[[
  RideAPet.lua, deobfuscated by QuickSilver (static analysis; nothing in the file was run)

  What the original is
    A MoonVeil 2.0.25 script: a bootstrap, a register VM (its interpreter, a ChaCha20/SHA-256 stub guard and 270 helper closures
    written out as separate functions) and one 93,870-byte encrypted VM program with 55 functions. This file is that program.

  How it was recovered
    1. The VM program was decrypted with the runtime's own algorithms (ChaCha20 with its custom constants, SHA-256 key, LZ). Its key
       depends on three environment probes of the original; the missing number was found by exhaustive search, and the result is
       confirmed because the decrypted data parses to exactly its declared length (55 functions, no bytes left over).
    2. Every instruction was read back through the interpreter's own handlers (partial evaluation), the runtime-keyed constants were
       decrypted (all of them: no encrypted string is left), and the control flow was rebuilt as if / while / for.
    3. The 270 helper closures the VM calls natively were put where they are made, so each function is written once, in place.

  What you are reading
    * The logic, the strings, the calls and the control flow are the program's. Names are not: the compiler threw them away, so
      variables are r<n> (main chunk), s<n>, t<n>, ... (one letter per nesting level) after the VM register they lived in, and
      values the lifter had to name are <letter>v<n>. The 270 helper closures were never register code, but their local names were
      stripped as well: QuickSilver's renamer chose param, value, item, ... from how each name is used.
    * A closure captures a register, not a value; where the VM reused a register for something else later, the same name can
      mean two things in different places. Read a name together with its nearest assignment.
    * Checked without running it: all 908 readable constants the instructions use are in the text, no register is read without being
      assigned, all 55 functions were structured (no labels or jumps), every generic for is a `for ... in`.
    * Not executed, so behaviour is read, not tested.
]]

local r5, r26, r25, r35, r38, r43, r103
local r1 = getgenv and getgenv() or _G
local r2 = r1.LH_Loading

if r2 then
  r5 = os
  r5 = r1.LH_LoadStartTime or 0
  r2 = os.clock() - r5 < 20
end

if r2 then
  warn("[Linkhive] Script is already loading, skipping duplicate execution.")
  return
end

r1.LH_Loading = true
local r3 = os
r1.LH_LoadStartTime = os.clock()
r2 = os.clock()

if r1.LH_Running then
  if type(r1.LH_LocalMovementCleanup) == "function" then
    pcall(r1.LH_LocalMovementCleanup)
  end

  if type(r1.LH_AutoPickupCleanup) == "function" then
    pcall(r1.LH_AutoPickupCleanup)
  end

  if type(r1.LH_AutoStealCleanup) == "function" then
    pcall(r1.LH_AutoStealCleanup)
  end

  if type(r1.LH_ServerHopCleanup) == "function" then
    pcall(r1.LH_ServerHopCleanup)
  end

  if type(r1.LH_GameStatsCleanup) == "function" then
    pcall(r1.LH_GameStatsCleanup)
  end

  if type(r1.LH_AutoHatchCleanup) == "function" then
    pcall(r1.LH_AutoHatchCleanup)
  end

  if type(r1.LH_AutoCollectCleanup) == "function" then
    pcall(r1.LH_AutoCollectCleanup)
  end

  if type(r1.LH_AutoPlaceEggCleanup) == "function" then
    pcall(r1.LH_AutoPlaceEggCleanup)
  end

  if type(r1.LH_AutoShopCleanup) == "function" then
    pcall(r1.LH_AutoShopCleanup)
  end

  if type(r1.LH_AutoFeedCleanup) == "function" then
    pcall(r1.LH_AutoFeedCleanup)
  end

  if type(r1.LH_AutoRebirthCleanup) == "function" then
    pcall(r1.LH_AutoRebirthCleanup)
  end

  if type(r1.LH_AutoSellCleanup) == "function" then
    pcall(r1.LH_AutoSellCleanup)
  end

  if type(r1.LH_AutoPlotCleanup) == "function" then
    pcall(r1.LH_AutoPlotCleanup)
  end

  if type(r1.LH_ESPCleanup) == "function" then
    pcall(r1.LH_ESPCleanup)
  end

  if type(r1.LH_PerformanceCleanup) == "function" then
    pcall(r1.LH_PerformanceCleanup)
  end

  if type(r1.LH_AntiCleanup) == "function" then
    pcall(r1.LH_AntiCleanup)
  end

  if type(r1.LH_MiscCleanup) == "function" then
    pcall(r1.LH_MiscCleanup)
  end

  if type(r1.LH_WebhookCleanup) == "function" then
    pcall(r1.LH_WebhookCleanup)
  end

  if type(r1.LH_WindowCleanup) == "function" then
    pcall(r1.LH_WindowCleanup)
  end
end

r1.LH_Running = true
r1.LH_RunToken = r2
r3 = game:GetService("Players")
local r4 = game:GetService("Workspace")
r5 = game:GetService("ReplicatedStorage")
local r6 = game:GetService("RunService")
local r7 = game:GetService("UserInputService")
local r8 = game:GetService("HttpService")
local r9 = game:GetService("CoreGui")
local r10 = game:GetService("Lighting")
local r11 = game:GetService("SoundService")
local r12 = game:GetService("TweenService")
local r13 = game:GetService("TeleportService")
local r14 = game:GetService("GuiService")
local r15 = r3.LocalPlayer

local r16 = type(isfile) == "function" and isfile or function()
  return false
end

local r17 = type(readfile) == "function" and readfile or function()
  return ""
end

local r18 = type(writefile) == "function" and writefile or function() end

local r19 = type(isfolder) == "function" and isfolder or function()
  return false
end

local r20 = type(makefolder) == "function" and makefolder or function() end
local r21 = type(fireproximityprompt) == "function" and fireproximityprompt or function() end
local r22 = type(setclipboard) == "function" and setclipboard or function() end
local r23 = type(queueonteleport) == "function" and queueonteleport or (type(queue_on_teleport) == "function" and queue_on_teleport or nil)
local r24 = type(request) == "function" and request

if not r24 then
  r24 = type(http_request) == "function" and http_request

  if not r24 then
    r24 = syn

    if r24 then
      r26 = syn
      r24 = type(syn.request) == "function"
    end

    if r24 then
      r25 = syn
      r24 = syn.request
    end

    if not r24 then
      r24 = nil
    end
  end
end

r25 = true
r26 = false

local r27 = function(...)
  if not r25 or not r23 or r26 then
    return
  end

  pcall(
    r23,
    'if not getgenv().LH_TeleportExecuted then getgenv().LH_TeleportExecuted = true; loadstring(game:HttpGet("https://raw.githubusercontent.com/afkar-gg/sc/refs/heads/main/Linkhive/RideAPet.lua"))() end'
  )
end

local r28 = function(...) end
local r29 = UDim2.fromOffset(620, 480)
local r30 = UDim2.fromOffset(580, 350)

local rv1 = function(param1)
  if not r19(param1) then
    pcall(r20, param1)
  end
end

rv1("LinkhiveCache")
rv1("WindUI")
rv1("WindUI/RideAPet")
rv1("Linkhive_RideAPet")

local r32 = function(param1, param2)
  if not r16(param1) then
    return param2
  end

  local value, value1 = pcall(r17, param1)

  if not value or type(value1) ~= "string" or #value1 == 0 then
    return param2
  end

  local value2, value3 = pcall(r8.JSONDecode, r8, value1)

  if not value2 or type(value3) ~= "table" then
    return param2
  end

  return value3
end

local r33 = function(param1, param2)
  local value, value1 = pcall(r8.JSONEncode, r8, param2)

  if not value then
    return false
  end

  return pcall(r18, param1, value1)
end

local r34 = nil

rv1 = function(...)
  local s1, s2

  if r16("LinkhiveCache/windui_source.lua") then
    s1 = r17("LinkhiveCache/windui_source.lua")

    if type(s1) == "string" and #s1 > 1000 then
      s2 = loadstring(s1)()
    end
  end
end

local r36 = rv1
pcall(rv1)

if not r34 then
  rv1 = function()
    return game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua")
  end

  r36 = rv1
  r35, r36 = pcall(rv1)

  if r35 and type(r36) == "string" and #r36 > 1000 then
    rv1 = function(...)
      r18("LinkhiveCache/windui_source.lua", r36)
    end

    r38 = rv1
    pcall(rv1)
    r38 = r36
    r34 = loadstring(r36)()
  else
    if r16("random/windui.lua") then
      r38 = r17
      r34 = loadstring(r17("random/windui.lua"))()
    end
  end
end

if not r34 then
  warn("[Linkhive] Failed to load WindUI.")
  return
end

r34:SetNotificationLower(true)

r34:AddTheme({
  Name = "Beeswarm",
  Accent = Color3.fromRGB(250, 180, 20),
  Dialog = Color3.fromRGB(28, 24, 14),
  Outline = Color3.fromRGB(90, 75, 25),
  Surface = Color3.fromRGB(38, 32, 18),
  Background = Color3.fromHex("#FFC700"),
  Text = Color3.fromHex("#ffffff"),
  Placeholder = Color3.fromRGB(120, 95, 35),
  Button = Color3.fromHex("#241C10"),
  Icon = Color3.fromHex("#3E2D0C"),
  ElementBackground = Color3.fromHex("#1C170E"),
  ElementBackgroundTransparency = 0,
  ElementTitle = Color3.fromHex("#FFFFFF"),
  ElementDesc = Color3.fromHex("#E2D4BA"),
  ElementIcon = Color3.fromRGB(250, 180, 20),
  Toggle = Color3.fromRGB(250, 180, 20),
  ToggleBar = Color3.fromHex("#FFFFFF"),
  SectionBox = Color3.fromHex("#261A07"),
  SectionBoxBackground = Color3.fromHex("#171209"),
  SectionBoxBackgroundTransparency = 0,
  SectionBoxBorder = Color3.fromHex("#523D18"),
  SectionBoxBorderTransparency = 0.5,
  TabTitle = Color3.fromHex("#261A07"),
  TabIcon = Color3.fromHex("#3E2D0C"),
  TabText = Color3.fromHex("#261A07"),
  WindowTopbarTitle = Color3.fromHex("#261A07"),
  WindowTopbarAuthor = Color3.fromHex("#523D18"),
  WindowTopbarIcon = Color3.fromHex("#261A07"),
  WindowTopbarButtonIcon = Color3.fromHex("#261A07"),
  DropdownBackground = Color3.fromHex("#171209"),
  DropdownTabBackground = Color3.fromHex("#241D12"),
})

r34:AddTheme({
  Name = "Beeswarm Dark",
  Accent = Color3.fromRGB(250, 180, 20),
  Dialog = Color3.fromHex("#1A140A"),
  Outline = Color3.fromHex("#523D18"),
  Surface = Color3.fromHex("#241C10"),
  Background = Color3.fromHex("#120E06"),
  Text = Color3.fromHex("#FEF3C7"),
  Placeholder = Color3.fromRGB(180, 160, 100),
  Button = Color3.fromHex("#2C2214"),
  Icon = Color3.fromRGB(250, 180, 20),
  ElementBackground = Color3.fromHex("#1C160C"),
  ElementBackgroundTransparency = 0,
  ElementTitle = Color3.fromHex("#FFFFFF"),
  ElementDesc = Color3.fromHex("#E2D4BA"),
  ElementIcon = Color3.fromRGB(250, 180, 20),
  Toggle = Color3.fromRGB(250, 180, 20),
  ToggleBar = Color3.fromHex("#FFFFFF"),
  SectionBox = Color3.fromHex("#FEF3C7"),
  SectionBoxBackground = Color3.fromHex("#171209"),
  SectionBoxBackgroundTransparency = 0,
  SectionBoxBorder = Color3.fromHex("#523D18"),
  SectionBoxBorderTransparency = 0.5,
  TabTitle = Color3.fromHex("#FEF3C7"),
  TabIcon = Color3.fromRGB(250, 180, 20),
  TabText = Color3.fromHex("#FEF3C7"),
  DropdownBackground = Color3.fromHex("#171209"),
  DropdownTabBackground = Color3.fromHex("#241D12"),
})

r34:AddTheme({
  Name = "Mid Summer",
  Accent = Color3.fromHex("#FF5722"),
  Dialog = Color3.fromHex("#1E100D"),
  Outline = Color3.fromHex("#8D3C1B"),
  Surface = Color3.fromHex("#2D1612"),
  Background = Color3.fromHex("#170B08"),
  Text = Color3.fromHex("#FFEBE6"),
  Placeholder = Color3.fromHex("#CC7052"),
})

r34:AddTheme({
  Name = "Lunar Moon",
  Accent = Color3.fromHex("#FFFFFF"),
  Dialog = Color3.fromHex("#0F0F14"),
  Outline = Color3.fromHex("#404050"),
  Surface = Color3.fromHex("#1A1A22"),
  Background = Color3.fromHex("#08080C"),
  Text = Color3.fromHex("#FFFFFF"),
  Placeholder = Color3.fromHex("#888899"),
})

r34:AddTheme({
  Name = "Winter Frost",
  Accent = Color3.fromHex("#00BFFF"),
  Dialog = Color3.fromHex("#0B1520"),
  Outline = Color3.fromHex("#1E4A6E"),
  Surface = Color3.fromHex("#102232"),
  Background = Color3.fromHex("#070E16"),
  Text = Color3.fromHex("#E0F4FF"),
  Placeholder = Color3.fromHex("#5A94B8"),
})

r34:AddTheme({
  Name = "Elegant Night",
  Accent = Color3.fromHex("#9B59B6"),
  Dialog = Color3.fromHex("#140D1A"),
  Outline = Color3.fromHex("#4E2866"),
  Surface = Color3.fromHex("#1F1329"),
  Background = Color3.fromHex("#0D0812"),
  Text = Color3.fromHex("#F5E6FF"),
  Placeholder = Color3.fromHex("#8E5A9E"),
})

r34:AddTheme({
  Name = "Lunar Abyss",
  Accent = Color3.fromHex("#00D2FF"),
  Dialog = Color3.fromHex("#050B14"),
  Outline = Color3.fromHex("#0A3A60"),
  Surface = Color3.fromHex("#08182B"),
  Background = Color3.fromHex("#02060D"),
  Text = Color3.fromHex("#00aeff"),
  Placeholder = Color3.fromHex("#3A789E"),
})

r34:AddTheme({
  Name = "Lunar Eclipse",
  Accent = Color3.fromHex("#FF2A55"),
  Dialog = Color3.fromHex("#15050A"),
  Outline = Color3.fromHex("#600A20"),
  Surface = Color3.fromHex("#220A12"),
  Background = Color3.fromHex("#0D0206"),
  Text = Color3.fromHex("#FFE5EC"),
  Placeholder = Color3.fromHex("#9E3A54"),
})

r35 = r32

r35 = r32(
  "Linkhive_RideAPet/WindowPrefs.json",
  { Theme = "Beeswarm", Background = "rbxassetid://78131090774816", Transparency = 0.2 }
)

r36 = r35.Theme or "Beeswarm"
local r37 = r35.Background or "rbxassetid://78131090774816"
r38 = tonumber(r35.Transparency) or 0.2

local r39 = function(param, param1, param2)
  local str = ""
  local count = #param

  for i = 1, count do
    local num = (i - 1) / math.max(count - 1, 1)
    local num1 = math.floor(param1.R * 255 + (param2.R * 255 - param1.R * 255) * num)
    local num2 = math.floor(param1.G * 255 + (param2.G * 255 - param1.G * 255) * num)
    local num3 = math.floor(param1.B * 255 + (param2.B * 255 - param1.B * 255) * num)
    local value = param:sub(i, i)
    str = str .. string.format('<font color="rgb(%d,%d,%d)">%s</font>', num1, num2, num3, value)
  end

  return str
end

local r40 = true

local r41 = function(param1, param2, param3, param4)
  if not r40 then
    return
  end

  r34:Notify{
    Title = param1 or "Linkhive",
    Content = param2 or "",
    Icon = param3 or "check",
    Duration = param4 or 3,
    Background = r37,
  }
end

local r42 = r7.TouchEnabled

if r15 and r15.OsPlatform then
  r43 = r15.OsPlatform

  if r43 == Enum.Platform.IOS or r43 == Enum.Platform.Android then
    r42 = true
  end
end

local r46 = Color3.fromHex

local r44 = r34:CreateWindow({
  Title = r39("Linkhive - Ride A Pet", Color3.fromHex("#777777"), r46("#000000")),
  Author = "discord.gg/linkhive",
  Theme = r36,
  Size = r42 and r30 or r29,
  Folder = "RideAPet",
  SideBarWidth = 180,
  ScrollBarEnabled = true,
  Icon = "rbxassetid://95796400321273",
  BackgroundImageTransparency = r38,
  Background = r37,
})

r44:Tag({ Title = "Keyless", Color = Color3.fromHex("#ffa600"), Radius = 8 })
r44:DisableTopbarButtons({ "Fullscreen" })
r44:SetUIScale(0.9)
r44:SetToggleKey(Enum.KeyCode.RightShift)

local r47 = {
  Title = "Open Linkhive",
  Icon = "rbxassetid://95796400321273",
  CornerRadius = UDim.new(0, 16),
  StrokeThickness = 2,
  Draggable = true,
}

local r50 = Color3.fromRGB
r47.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0), r50(255, 140, 0))
r47.Enabled = true
r44:EditOpenButton(r47)
local r45 = r44:Section({ Title = "Home", Icon = "star", Opened = true })
task.wait(0.08)
r46 = r45:Tab({ Title = "Discord", Icon = "messages-square" })
task.wait(0.08)
r47 = r45:Tab({ Title = "Game Stats", Icon = "bar-chart-2" })
task.wait(0.08)
r44:Divider()
local r48 = r44:Section({ Title = "Features", Icon = "box", Opened = true, Box = true })
task.wait(0.08)
local r49 = r48:Tab({ Title = "Main", Icon = "terminal", Box = true })
task.wait(0.08)
r50 = r48:Tab({ Title = "Auto", Icon = "zap", Box = true })
task.wait(0.08)
local r51 = r48:Tab({ Title = "Misc", Icon = "boxes" })
task.wait(0.08)
local r52 = r48:Tab({ Title = "Local", Icon = "user" })
task.wait(0.08)
local r53 = r48:Tab({ Title = "Webhook", Icon = "bell" })
task.wait(0.08)
r44:Divider()
local r54 = r44:Tab({ Title = "Settings", Icon = "settings" })
task.wait(0.08)
local r56 = r46

r46:Paragraph({
  Title = "Join the Linkhive Community",
  Desc = "Get the latest updates, give feedback, and get support for Linkhive automation tools.",
  Image = "rbxassetid://95796400321273",
  ImageSize = 32,
})

local r57 = { Title = "Copy Discord Invite", Icon = "copy" }

local rv2 = function()
  r22("https://discord.gg/linkhive")
  r41("Discord", "Copied invite link to clipboard!", "check", 3)
end

local r58 = rv2
r57.Callback = rv2
r56 = r46
r46:Button(r57)
task.wait(0.08)
r57 = { Title = "Egg Tracker Data", Icon = "egg" }
r58 = true
r57.Box = r58
r57.BoxBorder = r58
r57.Opened = r58
r56 = r47
local r55 = r47:Section(r57)

r56 = function()
  local tbl = {}
  local num = 0

  local value = r15
    and r15:FindFirstChild("PlayerGui")
    and r15.PlayerGui:FindFirstChild("Main")
    and r15.PlayerGui.Main:FindFirstChild("EggTracker")
    and r15.PlayerGui.Main.EggTracker:FindFirstChild("EggsHolder")

  if value then
    for _, item in ipairs(value:GetChildren()) do
      if item:IsA("Frame") then
        local count = item:FindFirstChild("Count", true)
        local luck = item:FindFirstChild("Luck", true)
        local value = count and count.Text or "x0"
        local value1 = luck and luck.Text or "0"
        local value2 = tonumber(value:match("%d+")) or 0

        if value2 > 0 then
          num = num + value2

          table.insert(tbl, {
            name = item.Name,
            count = value,
            num = value2,
            luck = value1,
            order = item.LayoutOrder or 0,
          })
        end
      end
    end
  end

  if #tbl == 0 then
    local renderedEggs = r4:FindFirstChild("RenderedEggs")

    if renderedEggs then
      local tbl1 = {}

      for _, item in ipairs(renderedEggs:GetChildren()) do
        tbl1[item.Name] = (tbl1[item.Name] or 0) + 1
        num = num + 1
      end

      for key, value in pairs(tbl1) do
        table.insert(tbl, {
          name = key,
          count = "x" .. tostring(value),
          num = value,
          luck = "-",
          order = 0,
        })
      end
    end
  end

  table.sort(tbl, function(param, param1)
    if param.order ~= param1.order and param.order > 0 and param1.order > 0 then
      return param.order < param1.order
    end

    return param.num > param1.num
  end)

  return tbl, num
end

r58 = r55

r57 = r55:Paragraph({
  Title = "Active World Eggs",
  Desc = "Scanning eggs in game...",
  Image = "egg",
  ImageSize = 28,
})

local r59 = r55
r58 = r55:Paragraph({ Title = "Egg Distribution", Desc = "Loading..." })

r59 = function()
  local value, value1 = r56()

  pcall(function()
    r57:SetTitle("Active World Eggs: " .. tostring(value1))
    r57:SetDesc("Unique Egg Types: " .. tostring(#value))
  end)

  local tbl = {}

  for _, item in ipairs(value) do
    table.insert(tbl, string.format("• %s: %s (Luck: %s)", item.name, item.count, item.luck))
  end

  local value2 = #tbl > 0 and table.concat(tbl, "\n") or "No eggs currently tracked."

  pcall(function()
    r58:SetDesc(value2)
  end)
end

local r62 = { Title = "Refresh Eggs Data", Icon = "rotate-cw" }

rv1 = function()
  pcall(function()
    local value = r5:FindFirstChild("Remotes")
      and r5.Remotes:FindFirstChild("Game")
      and r5.Remotes.Game:FindFirstChild("OpenEggTracker")

    if value then
      value:FireServer()
    end
  end)

  task.wait(0.2)
  r59()
  r41("Game Stats", "Egg tracker data refreshed!", "check", 2)
end

local r63 = rv1
r62.Callback = rv1
local r61 = r55
r55:Button(r62)
task.wait(0.08)
r62 = { Title = "Server & Game Info", Icon = "server" }
r63 = true
r62.Box = r63
r62.BoxBorder = r63
r62.Opened = r63
r61 = r47
local r60 = r47:Section(r62)

r61 = function(param)
  param = math.floor(param or 0)
  local num = math.floor(param / 3600)
  local num1 = math.floor(param % 3600 / 60)
  local num2 = param % 60

  if num > 0 then
    return string.format("%dh %dm %ds", num, num1, num2)
  elseif num1 > 0 then
    return string.format("%dm %ds", num1, num2)
  else
    return string.format("%ds", num2)
  end
end

local r64 = { Title = "Server Details" }
local r69 = r61
local r70 = r4.DistributedGameTime

r64.Desc = string.format([[Job ID: %s
Game Version: %s
Server Uptime: %s]], game.JobId, tostring(game.PlaceVersion), r69(r70))

r64.Image = "activity"
r64.ImageSize = 28
r63 = r60
r62 = r60:Paragraph(r64)
local r65 = { Title = "Copy Job ID", Icon = "copy" }

rv2 = function()
  r22(game.JobId)
  r41("Server Info", "Job ID copied to clipboard!", "check", 3)
end

local r66 = rv2
r65.Callback = rv2
r64 = r60
r60:Button(r65)
task.wait(0.08)
r63 = false

task.spawn((function()
  r59()
  local num = 0

  while not r63 do
    task.wait(1)
    num = num + 1

    pcall(function()
      r62:SetDesc(string.format([[Job ID: %s
Game Version: %s
Server Uptime: %s]], game.JobId, tostring(game.PlaceVersion), r61(r4.DistributedGameTime)))
    end)

    if num % 3 == 0 then
      pcall(r59)
    end
  end
end))

rv2 = function()
  r63 = true

  if r1.LH_GameStatsCleanup then
    r1.LH_GameStatsCleanup = nil
  end
end

r64 = rv2
r1.LH_GameStatsCleanup = rv2
r64 = r44.ConfigManager
r44.PendingFlags = r44.PendingFlags or {}
r65 = r32("WindUI/RideAPet/autosave-state.json", { enabled = true })
r66 = r32
r66 = r32("WindUI/RideAPet/autoload-state.json", { enabled = false, name = "" })
r69 = false
local r67 = r65.enabled ~= false
local r68 = true

r70 = (type(r64) == "table" or type(r64) == "userdata")
  and type(r64.CreateConfig) == "function"
  and r64:CreateConfig("__autosave") or nil

local r71 = function()
  r33("WindUI/RideAPet/autosave-state.json", { enabled = r67 })
end

local r72 = function(param1, param2)
  r66 = { enabled = param1 == true, name = param1 and tostring(param2 or "") or "" }
  r33("WindUI/RideAPet/autoload-state.json", r66)
end

local r73 = function()
  if not r67 or r68 then
    return
  end

  if r70 then
    if r44.PendingFlags then
      for key, value in pairs(r44.PendingFlags) do
        r70:Register(key, value)
      end
    end

    pcall(function()
      r70:Save()
    end)
  end

  if r44 and r44.GetFlags then
    local value, value1 = pcall(function()
      return r44:GetFlags()
    end)

    if value and type(value1) == "table" then
      local function fn(param, param1)
        if param1 > 8 then
          return nil
        end

        local value = typeof(param)

        if value == "EnumItem" then
          return param.Name
        end

        if value == "string" or value == "number" or value == "boolean" then
          return param
        end

        if value ~= "table" then
          return nil
        end

        local tbl = {}

        for key, value in pairs(param) do
          local value1 = fn(value, param1 + 1)

          if value1 ~= nil then
            tbl[key] = value1
          end
        end

        return tbl
      end

      r33("WindUI/RideAPet/autosave-flags.json", fn(value1, 0))
    end
  end
end

local r74 = function()
  if not r67 or r68 or r69 then
    return
  end

  r69 = true

  task.delay(0.5, function()
    r69 = false
    r73()
  end)
end

local r75 = function(param)
  local tbl = {}

  for key, value in pairs(param or {}) do
    tbl[key] = value
  end

  return tbl
end

local r76 = function(param1)
  if not param1 or param1.__LHConfigTracked then
    return param1
  end

  param1.__LHConfigTracked = true

  for _, item in ipairs{ "Toggle", "Dropdown", "Slider", "Input", "Colorpicker", "Keybind" } do
    local value = param1[item]

    if value then
      param1[item] = function(self, param1, ...)
        local value1 = type(param1) == "table" and r75(param1) or param1
        local value2 = type(value1) == "table" and value1.Callback or nil

        if type(value2) == "function" then
          function value1.Callback(param1, ...)
            if not r68 then
              r74()
            end

            local value = table.pack(value2(param1, ...))
            return table.unpack(value, 1, value.n)
          end
        end

        local value3 = value(self, value1, ...)

        if value3 and type(value1) == "table" and value1.Flag then
          r44.PendingFlags = r44.PendingFlags or {}
          r44.PendingFlags[value1.Flag] = value3

          if r70 then
            r70:Register(value1.Flag, value3)
          end
        end

        return value3
      end
    end
  end

  return param1
end

rv1 = function(param1)
  if not param1 or param1.__LHTabTracked then
    return
  end

  param1.__LHTabTracked = true
  local section = param1.Section

  if not section then
    return
  end

  function param1.Section(self, param1, ...)
    local value = section(self, param1, ...)
    return r76(value)
  end
end

local r79 = r49
rv1(r49)
r79 = r50
rv1(r50)
r79 = r51
rv1(r51)
r79 = r52
rv1(r52)
r79 = r54
rv1(r54)
local r80 = { Title = "Configuration", Icon = "file-text" }
local r81 = true
r80.Box = r81
r80.BoxBorder = r81
r80.Opened = r81
r79 = r54
local r78 = r54:Section(r80)
r79 = ""
r80 = ""
r81 = nil
local r82 = nil

local r84 = function()
  local tbl = {}

  if r64 and type(r64.AllConfigs) == "function" then
    local value, value1 = pcall(function()
      return r64:AllConfigs()
    end)

    if value and type(value1) == "table" then
      for _, item in ipairs(value1) do
        if item ~= "__autosave" and not table.find(tbl, item) then
          table.insert(tbl, item)
        end
      end
    end
  end

  if r19("WindUI/RideAPet/config") and type(listfiles) == "function" then
    local value, value1 = pcall(listfiles, "WindUI/RideAPet/config")

    if value and type(value1) == "table" then
      for _, item in ipairs(value1) do
        local value = item:match("([^\\/]+)%.json$")

        if value and value ~= "__autosave" and not table.find(tbl, value) then
          table.insert(tbl, value)
        end
      end
    end
  end

  table.sort(tbl)
  return tbl
end

local r85 = function()
  if not r81 then
    return
  end

  local value = r84()

  if #value == 0 then
    value = { "No config found" }
  end

  pcall(function()
    r81:Refresh(value)
  end)
end

local r88 = { Title = "Config Name", Placeholder = "Enter name..." }

rv2 = function(param1)
  r79 = param1 or ""
end

local r89 = rv2
r88.Callback = rv2
r78:Input(r88)
local r86 = r84()

if #r86 == 0 then
  r86 = { "No config found" }
end

r89 = { Title = "Select Config", Values = r86, Value = r66.name ~= "" and r66.name or r86[1] }

rv2 = function(param1)
  if param1 and param1 ~= "No config found" then
    r80 = param1
    r79 = param1

    if r66.enabled then
      r72(true, param1)
    end
  end
end

local r90 = rv2
r89.Callback = rv2
r81 = r78:Dropdown(r89)
r89 = { Title = "Save Config", Icon = "save" }

rv2 = function()
  local value = r79 ~= "" and r79 or r80 ~= "" and r80 ~= "No config found" and r80

  if not value or value == "" or not r64 then
    r41("Config", "Enter or select a config name first", "triangle-alert", 3)
    return
  end

  local value1 = r64:CreateConfig(value)

  if value1 then
    if r44.PendingFlags then
      for key, value in pairs(r44.PendingFlags) do
        value1:Register(key, value)
      end
    end

    value1:Save()
    r80 = value
    r85()
    r41("Config", "Config saved: " .. value, "check", 3)
  end
end

r90 = rv2
r89.Callback = rv2
r78:Button(r89)
r89 = { Title = "Load Config", Icon = "folder-up" }

rv2 = function()
  local value = r80 ~= "" and r80 ~= "No config found" and r80 or r79 ~= "" and r79

  if not value or value == "" or not r64 then
    r41("Config", "Select a config to load first", "triangle-alert", 3)
    return
  end

  local value1 = r64:CreateConfig(value)

  if value1 then
    r68 = true

    if r44.PendingFlags then
      for key, value in pairs(r44.PendingFlags) do
        value1:Register(key, value)
      end
    end

    local value2, value3 = pcall(function()
      value1:Load()
    end)

    task.delay(0.5, function()
      r68 = false
      r74()
    end)

    if value2 then
      r41("Config", "Config loaded: " .. value, "check", 3)
    else
      r41("Config", "Failed to load config: " .. tostring(value3 or value), "triangle-alert", 3)
    end
  end
end

r90 = rv2
r89.Callback = rv2
r78:Button(r89)
r89 = { Title = "Delete Config", Icon = "trash-2" }

rv2 = function()
  local value = r80 ~= "" and r80 ~= "No config found" and r80 or r79 ~= "" and r79

  if not value or value == "" or not r64 then
    r41("Config", "Select a config to delete first", "triangle-alert", 3)
    return
  end

  local value1 = r64:CreateConfig(value)

  if value1 then
    pcall(function()
      value1:Delete()
    end)

    if value == r80 then
      r80 = ""
    end

    if value == r79 then
      r79 = ""
    end

    r85()
    r41("Config", "Config deleted: " .. value, "check", 3)
  end
end

r90 = rv2
r89.Callback = rv2
r78:Button(r89)
r89 = { Title = "Refresh Config List", Icon = "rotate-cw" }

rv1 = function()
  r85()
  r41("Config", "Config list refreshed", "check", 2)
end

r90 = rv1
r89.Callback = rv1
r78:Button(r89)
r89 = { Title = "Auto Load Config" }
local r92 = true
r89.Value = r66.enabled == true

rv2 = function(param1)
  local value = r80 ~= "" and r80 ~= "No config found" and r80 or r79

  if param1 and (value == "" or value == "No config found") then
    r72(false, "")

    task.defer(function()
      if r82 and r82.Set then
        r82:Set(false)
      end
    end)

    if not r68 then
      r41("Config", "Select a config before enabling Auto Load", "triangle-alert", 3)
    end

    return
  end

  r72(param1, value)

  if not r68 then
    r41("Config", param1 and "Auto Load set: " .. value or "Auto Load disabled", "check", 3)
  end
end

r90 = rv2
r89.Callback = rv2
r82 = r78:Toggle(r89)
r89 = { Title = "Auto Save Config", Value = r67 }

rv2 = function(param1)
  r67 = param1
  r71()

  if r67 and not r68 then
    r73()
  end

  if not r68 then
    r41("Config", r67 and "Auto Save enabled" or "Auto Save disabled", "check", 2)
  end
end

r90 = rv2
r89.Callback = rv2
local r87 = r78:Toggle(r89)
task.wait(0.08)
r89 = { Title = "Interface", Icon = "layout" }
r90 = true
r89.Box = r90
r89.BoxBorder = r90
r89.Opened = r90
r87 = r54:Section(r89)
r90 = { Title = "UI Scale", Step = 0.05 }
r92 = { Min = 0.65, Max = 1.15, Default = 0.9 }
local r91 = r92
r90.Value = r92

rv2 = function(param1)
  r44:SetUIScale(param1)
end

r91 = rv2
r90.Callback = rv2
r89 = r87
r87:Slider(r90)
r90 = { Title = "Notifications", Value = r40 }

rv2 = function(param1)
  r40 = param1
end

r91 = rv2
r90.Callback = rv2
r89 = r87
r87:Toggle(r90)
task.wait(0.08)
r90 = { Title = "Appearance", Icon = "palette" }
r91 = true
r90.Box = r91
r90.BoxBorder = r91
r90.Opened = r91
r89 = r54
r88 = r54:Section(r90)
r91 = { Title = "Theme" }
local r93 = {}
r93[1], r93[2], r93[3], r93[4], r93[5], r93[6], r93[7], r93[8] = "Beeswarm", "Beeswarm Dark", "Mid Summer", "Lunar Moon", "Winter Frost", "Elegant Night", "Lunar Abyss", "Lunar Eclipse"
r92 = r93
r91.Values = r93
r91.Value = r36

rv2 = function(param1)
  r36 = param1
  r35.Theme = param1
  r33("Linkhive_RideAPet/WindowPrefs.json", r35)
  r44:SetTheme(param1)
end

r92 = rv2
r91.Callback = rv2
r90 = r88
r88:Dropdown(r91)
r91 = { Title = "Background Transparency", Step = 0.05 }
r93 = { Min = 0, Max = 1, Default = r38 }
r92 = r93
r91.Value = r93

rv2 = function(param1)
  r38 = param1
  r35.Transparency = param1
  r33("Linkhive_RideAPet/WindowPrefs.json", r35)
end

r92 = rv2
r91.Callback = rv2
r90 = r88
r88:Slider(r91)
task.wait(0.08)

r89 = function()
  local character = r15.Character

  if not character then
    return nil, nil, nil
  end

  return character, character:FindFirstChild("HumanoidRootPart"), character:FindFirstChildOfClass("Humanoid")
end

r90 = function(param)
  local value = tonumber(param) or 0
  local num = math.abs(value)

  for _, item in ipairs({
    { 1e33, "Dc" },
    { 1e30, "No" },
    { 1e27, "Oc" },
    { 1e24, "Sp" },
    { 1e21, "Sx" },
    { 1000000000000000000, "Qi" },
    { 1000000000000000, "Qa" },
    { 1000000000000, "T" },
    { 1000000000, "B" },
    { 1000000, "M" },
    { 1000, "K" },
  }) do
    if num >= item[1] then
      return string.format("%.2f", value / item[1]):gsub("%.?0+$", "") .. item[2]
    end
  end

  return tostring(math.floor(value))
end

r91 = function(param)
  if type(param) == "number" then
    return param
  end

  if type(param) ~= "string" then
    return 0
  end

  local value = param:gsub(",", ""):gsub("%$", ""):gsub("%s+", ""):upper()
  local value1, value2 = value:match("^([%d%.]+)%s*([A-Z]*)$")
  local value3 = tonumber(value1) or 0

  local tbl = {
    K = 1000,
    M = 1000000,
    B = 1000000000,
    T = 1000000000000,
    QA = 1000000000000000,
    QI = 1000000000000000000,
    SX = 1e21,
    SP = 1e24,
    OC = 1e27,
    NO = 1e30,
    DC = 1e33,
  }

  if value2 and tbl[value2] then
    return value3 * tbl[value2]
  end

  return tonumber(value) or 0
end

r92 = function()
  local plots = r4:FindFirstChild("Plots")

  if not plots then
    return nil
  end

  for _, item in ipairs(plots:GetChildren()) do
    local data = item:FindFirstChild("Data")
    local value = data and data:FindFirstChild("Owner")

    if value and value.Value == r15 then
      return item
    end
  end

  return nil
end

r93 = function()
  local value = r5:FindFirstChild("Remotes")
    and r5.Remotes:FindFirstChild("Game")
    and r5.Remotes.Game:FindFirstChild("TeleportToPlot")

  if value then
    pcall(function()
      value:FireServer()
    end)

    return true
  end

  local basket = r15:FindFirstChild("Basket")

  if basket and #basket:GetChildren() > 0 then
    return false
  end

  local value1 = r92()

  if not value1 then
    return false
  end

  local baseplate = value1:FindFirstChild("Baseplate")
  local value2, value3, value4 = r89()

  if value3 and baseplate then
    value3.AssemblyLinearVelocity = Vector3.zero
    value3.AssemblyAngularVelocity = Vector3.zero
    value3.CFrame = CFrame.new(baseplate.Position + Vector3.new(0, 3.5, 0))

    if value4 then
      value4.Sit = false
    end

    return true
  end

  return false
end

rv2 = function()
  local plots = r4:FindFirstChild("Plots")
  local tbl = {}

  if not plots then
    return tbl
  end

  for _, item in ipairs(plots:GetChildren()) do
    local data = item:FindFirstChild("Data")
    local value = data and data:FindFirstChild("Owner")

    if value and value.Value ~= nil and value.Value ~= r15 then
      table.insert(tbl, item)
    end
  end

  return tbl
end

rv1 = function()
  local tbl = {}

  for _, item in ipairs(r3:GetPlayers()) do
    if item ~= r15 then
      table.insert(tbl, item.Name)
    end
  end

  return tbl
end

local r97 = {}
local r99 = "Common"
local r100 = "Rare"
local r101 = "Epic"
local r102 = "Legendary"
local r104 = "Divine"
local r105 = "Ethereal"
r97[1], r97[2], r97[3], r97[4], r97[5], r97[6], r97[7], r97[8] = "All Rarities", r99, r100, r101, r102, "Mythic", r104, r105
local r96 = r97
local r98 = {}
r98[1], r98[2], r98[3], r98[4], r98[5], r98[6], r98[7] = r99, r100, r101, r102, "Mythic", r104, r105
r97 = r98
r98 = {}

for r102, r103 in ipairs(r96) do
  if r103 ~= "All Rarities" then
    r98[r103] = r102
    r105 = r103
    r104 = string.lower(r103)
    r98[r104] = r102
  end
end

r99 = {}
r100 = {}
r101 = { "All Eggs" }
r102 = {}

rv1 = function(...)
  local s7, s8, s9
  local s1 = {}
  local s2 = {}
  local s3 = pcall

  s3(function(...)
    local t7, t8, t9, t10, t11, t12
    local t1 = r5:FindFirstChild("GameData") or r5:WaitForChild("GameData", 5)
    local t2 = t1 and (t1:FindFirstChild("Eggs") or t1:WaitForChild("Eggs", 5))
    local t3 = t2 and require(t2)

    if type(t3) == "table" then
      for t7, t8 in pairs(t3) do
        if type(t7) == "string" and type(t8) == "table" then
          t9 = type(t8.Rarity) == "string" and t8.Rarity or "Common"
          t10 = r99
          t10[t7] = t9

          if not r98[t9] then
            t11 = r96
            table.insert(t11, t9)
            t10 = #t11
            t11 = r98
            t11[t9] = t10
            t12 = string.lower(t9)
            t11[t12] = t10
          end

          t10 = tonumber(t8.Luck)
          t11 = r100
          t11[t7] = t10 or 0
          t11 = s2
          t11[t7] = true

          table.insert(s1, {
            name = t7,
            rRank = r98[t9] or 99,
            premium = t8.Premium == true,
            luck = t10 or math.huge,
          })
        end
      end
    end
  end)

  s3(function(...)
    local t7, t8, t9, t10
    local t1 = r5:FindFirstChild("Assets")
    local t2 = t1 and t1:FindFirstChild("Eggs")

    if t2 then
      for t6, t7 in ipairs(t2:GetChildren()) do
        if not s2[t7.Name] then
          t8 = s2
          t9 = t7.Name
          t8[t9] = true
          t8 = r99[t7.Name] or "Common"
          t9 = r99
          t10 = t7.Name
          t9[t10] = t8

          table.insert(s1, {
            name = t7.Name,
            rRank = r98[t8] or 99,
            premium = false,
            luck = r100[t7.Name] or math.huge,
          })
        end
      end
    end
  end)

  table.sort(s1, function(t1, t2)
    if t1.rRank ~= t2.rRank then
      return t1.rRank < t2.rRank
    end

    if t1.premium ~= t2.premium then
      return not t1.premium
    end

    if t1.luck ~= t2.luck then
      return t1.luck < t2.luck
    end

    return t1.name < t2.name
  end)

  table.clear(r101)
  table.clear(r102)
  table.insert(r101, "All Eggs")

  for s6, s7 in ipairs(s1) do
    table.insert(r101, s7.name)
    s8 = r102
    s9 = s7.name
    s8[s9] = #r101
  end
end

r104 = rv1
rv1()
r104 = {}
r105 = {}
local r106 = {}

rv2 = function(...)
  local s6, s7, s5

  for s5, s6 in pairs((require(r5.GameData.Pets))) do
    if type(s6) == "table" then
      if s6.Rarity then
        s7 = r104
        s7[s5] = s6.Rarity
      end

      if s6.Speed then
        s7 = r105
        s7[s5] = s6.Speed
      end

      if s6.SampleSize then
        s7 = r106
        s7[s5] = s6.SampleSize
      end
    end
  end
end

local r108 = rv2
pcall(rv2)

local r107 = function()
  local num = 0.05

  local value, value1 = pcall(function()
    if r15 and r15.GetNetworkPing then
      return r15:GetNetworkPing()
    end

    local Stats = game:GetService("Stats")
    local value = Stats and Stats:FindFirstChild("Network")
    local value1 = value and value:FindFirstChild("ServerStatsItem")
    local value2 = value1 and value1:FindFirstChild("Data Ping")

    if value2 then
      return value2:GetValue() / 1000
    end

    return nil
  end)

  if value and type(value1) == "number" and value1 > 0 then
    num = value1
  end

  return num
end

r108 = function(param1)
  if not param1 then
    return 0
  end

  local value = type(param1) == "string" and param1 or param1.Name
  local value1 = type(param1) ~= "string" and param1:GetAttribute("Rarity") or r99[value]

  if not value1 and type(param1) ~= "string" then
    local rarity = param1:FindFirstChild("Rarity")

    if rarity then
      value1 = rarity:IsA("ValueBase") and rarity.Value or rarity.Name
    end
  end

  local value2 = r102[value] or 0

  if type(value1) == "number" then
    return value1 * 100 + value2
  end

  if type(value1) == "string" then
    local num = tonumber(value1)

    if num then
      return num * 100 + value2
    end

    local value = r98[value1] or r98[string.lower(value1)]

    if value then
      return value * 100 + value2
    end
  end

  return value2
end

local r110 = { WalkSpeed = 20, JumpPower = 73, FlyEnabled = false, FlySpeed = 100 }
local r111 = false
r110.NoclipEnabled = r111
r110.InfiniteJump = r111
r110.FlyVelocity = nil
r110.FlyGyro = nil
r110.FlyHumanoid = nil
r111 = false
r110.PreviousPlatformStand = r111
r110.Closed = r111
r110.InstantPrompt = r111
local r112 = {}
local r113 = 0
r112.Forward = r113
r112.Back = r113
r112.Left = r113
r112.Right = r113
r112.Up = r113
r112.Down = r113
r111 = r112
r110.Input = r112
r110.PetTrack = nil
r110.PetTrackName = nil
r110.PetInstance = nil
local r109 = r110

r110 = function()
  local character = r15.Character
  local value = character and character:FindFirstChild("HumanoidRootPart")
  local value1 = value and value:FindFirstChild("PetMountJoint")

  if value1 and value1:IsA("Motor6D") and value1.Part1 then
    return value1.Part1.Parent
  end

  return nil
end

r111 = function()
  if r109.PetTrack then
    pcall(function()
      r109.PetTrack:Stop(0.2)
      r109.PetTrack:Destroy()
    end)

    r109.PetTrack = nil
    r109.PetTrackName = nil
    r109.PetInstance = nil
  end
end

r112 = function(param1, param2, param3)
  if not param1 or not param1.Parent then
    r111()
    return
  end

  local animationController = param1:FindFirstChildOfClass("AnimationController")
  local value = animationController and animationController:FindFirstChildOfClass("Animator")

  if not value then
    r111()
    return
  end

  if not param2 then
    if r109.PetTrack and r109.PetTrack.IsPlaying then
      r109.PetTrack:Stop(0.2)
    end

    return
  end

  local animations = param1:FindFirstChild("Animations")

  local value1 = animations and (animations:FindFirstChild("Fly")
    or animations:FindFirstChild("Run")
    or animations:FindFirstChild("Walk"))

  if not value1 then
    r111()
    return
  end

  if r109.PetInstance ~= param1 or r109.PetTrackName ~= value1.Name or not r109.PetTrack then
    r111()

    local value2, value3 = pcall(function()
      return value:LoadAnimation(value1)
    end)

    if value2 and value3 then
      value3.Priority = Enum.AnimationPriority.Action4
      value3.Looped = true
      r109.PetTrack = value3
      r109.PetTrackName = value1.Name
      r109.PetInstance = param1
    end
  end

  if r109.PetTrack then
    if not r109.PetTrack.IsPlaying then
      r109.PetTrack:Play(0.15)
    end

    local num = math.clamp(param3 / 60, 0.8, 3.5)
    r109.PetTrack:AdjustSpeed(num)
  end
end

r113 = function(param1)
  if r109.FlyVelocity then
    pcall(function()
      r109.FlyVelocity:Destroy()
    end)
  end

  if r109.FlyGyro then
    pcall(function()
      r109.FlyGyro:Destroy()
    end)
  end

  r111()

  if param1 and r109.FlyHumanoid and r109.FlyHumanoid.Parent then
    if r15:GetAttribute("IsRiding") == true then
      r109.FlyHumanoid.PlatformStand = false

      pcall(function()
        r109.FlyHumanoid:ChangeState(Enum.HumanoidStateType.Running)
      end)
    else
      r109.FlyHumanoid.PlatformStand = r109.PreviousPlatformStand == true

      if not r109.FlyHumanoid.PlatformStand then
        pcall(function()
          r109.FlyHumanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)
      end
    end
  end

  r109.FlyVelocity = nil
  r109.FlyGyro = nil
  r109.FlyHumanoid = nil
end

local r114 = function(param1, param2)
  if r109.FlyHumanoid ~= param2
    or not r109.FlyVelocity
    or r109.FlyVelocity.Parent ~= param1
    or not r109.FlyGyro
    or r109.FlyGyro.Parent ~= param1 then
    r113(true)
    r109.FlyHumanoid = param2
    r109.PreviousPlatformStand = param2.PlatformStand
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "LhFlyVelocity"
    bodyVelocity.MaxForce = Vector3.new(9000000000, 9000000000, 9000000000)
    bodyVelocity.P = 1250
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = param1
    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "LhFlyGyro"
    bodyGyro.MaxTorque = Vector3.new(9000000000, 9000000000, 9000000000)
    bodyGyro.P = 1000
    bodyGyro.D = 50
    bodyGyro.CFrame = param1.CFrame
    bodyGyro.Parent = param1
    r109.FlyVelocity = bodyVelocity
    r109.FlyGyro = bodyGyro
  end

  if r15:GetAttribute("IsRiding") == true then
    param2.PlatformStand = false
    param2.Sit = false

    if param2:GetState() ~= Enum.HumanoidStateType.Running then
      pcall(function()
        param2:ChangeState(Enum.HumanoidStateType.Running)
      end)
    end
  else
    param2.Sit = false
    param2.PlatformStand = true
  end

  return r109.FlyVelocity, r109.FlyGyro
end

local r115 = function(param1, param2)
  local value = param2 and 1 or 0

  if param1 == Enum.KeyCode.W then
    r109.Input.Forward = value
  elseif param1 == Enum.KeyCode.S then
    r109.Input.Back = value
  elseif param1 == Enum.KeyCode.A then
    r109.Input.Left = value
  elseif param1 == Enum.KeyCode.D then
    r109.Input.Right = value
  elseif param1 == Enum.KeyCode.Space then
    r109.Input.Up = value
  elseif param1 == Enum.KeyCode.LeftControl or param1 == Enum.KeyCode.RightControl then
    r109.Input.Down = value
  end
end

local r116 = r7.InputBegan

rv2 = function(param1, param2)
  if not param2 then
    r115(param1.KeyCode, true)
  end
end

local r118 = rv2
r109.InputBegan = r116:Connect(rv2)
r116 = r7.InputEnded

rv2 = function(param1)
  r115(param1.KeyCode, false)
end

r118 = rv2
r109.InputEnded = r116:Connect(rv2)
r116 = r6.RenderStepped

rv1 = function(param1)
  if r109.Closed then
    return
  end

  local value, value1, value2 = r89()

  if not value1 or not value2 then
    r113(false)
    return
  end

  local value3 = r1.LH_AutoPickup or r1.LH_AutoSteal

  if type(value3) == "table" and (value3.ActiveTween ~= nil or value3.Busy or value3.SingleCycleRunning) then
    r113(true)
    return
  end

  if r109.FlyEnabled then
    local value, value3 = r114(value1, value2)
    local currentCamera = r4.CurrentCamera

    if not currentCamera then
      return
    end

    local input = r109.Input
    local value4 = input.Forward ~= 0 or input.Back ~= 0 or input.Left ~= 0 or input.Right ~= 0
    local value5, value6, value7

    if value4 then
      value5 = input.Forward - input.Back
      value6 = input.Right - input.Left
      value7 = input.Up - input.Down
    else
      local moveDirection = value2.MoveDirection
      value7 = input.Up - input.Down

      if moveDirection.Magnitude > 0.05 then
        local lookVector = currentCamera.CFrame.LookVector
        local rightVector = currentCamera.CFrame.RightVector
        local vector3 = Vector3.new(lookVector.X, 0, lookVector.Z)
        vector3 = vector3.Magnitude > 0.001 and vector3.Unit or Vector3.zAxis
        local vector31 = Vector3.new(rightVector.X, 0, rightVector.Z)
        vector31 = vector31.Magnitude > 0.001 and vector31.Unit or Vector3.xAxis
        value5 = moveDirection:Dot(vector3)
        value6 = moveDirection:Dot(vector31)
      else
        value5 = 0
        value6 = 0
      end
    end

    local num = currentCamera.CFrame.LookVector * value5
      + currentCamera.CFrame.RightVector * value6
      + Vector3.yAxis * value7

    local flag = num.Magnitude > 0.05
    value.Velocity = flag and num.Unit * r109.FlySpeed or Vector3.zero

    value3.CFrame = CFrame.lookAt(
      value1.Position,
      value1.Position + currentCamera.CFrame.LookVector
    )

    local value8 = r110()

    if value8 then
      r112(value8, flag, r109.FlySpeed)
    else
      r111()
    end

    return
  end

  r111()
  r113(true)
  local flag = r15:GetAttribute("IsRiding") == true

  if r109.WalkSpeed
    and r109.WalkSpeed > 20
    and (not flag or r109.WalkSpeed > value2.WalkSpeed)
    and value2.WalkSpeed ~= r109.WalkSpeed then
    value2.WalkSpeed = r109.WalkSpeed
  end

  if r109.JumpPower and r109.JumpPower ~= 73 and not flag and value2.JumpPower ~= r109.JumpPower then
    value2.UseJumpPower = true
    value2.JumpPower = r109.JumpPower
  end
end

r118 = rv1
r109.StepConnection = r116:Connect(rv1)
r116 = r6.Stepped

rv1 = function()
  if r109.Closed or not r109.NoclipEnabled then
    return
  end

  local character = r15.Character

  if character then
    for _, item in ipairs(character:GetDescendants()) do
      if item:IsA("BasePart") and item.CanCollide then
        item.CanCollide = false
      end
    end
  end

  local value = r110()

  if value then
    for _, item in ipairs(value:GetDescendants()) do
      if item:IsA("BasePart") and item.CanCollide then
        item.CanCollide = false
      end
    end
  end
end

r118 = rv1
r109.NoclipConnection = r116:Connect(rv1)
r116 = r7.JumpRequest

rv2 = function()
  if r109.InfiniteJump and not r109.Closed then
    local value, value1, value2 = r89()

    if value2 then
      value2:ChangeState(Enum.HumanoidStateType.Jumping)
    end
  end
end

r118 = rv2
r109.JumpRequestConnection = r116:Connect(rv2)
r116 = r15.CharacterAdded

rv2 = function(param1)
  local humanoid = param1:WaitForChild("Humanoid", 5)

  if humanoid then
    task.wait(0.1)

    if r109.WalkSpeed and r109.WalkSpeed > 20 then
      humanoid.WalkSpeed = r109.WalkSpeed
    end

    if r109.JumpPower and r109.JumpPower ~= 73 then
      humanoid.UseJumpPower = true
      humanoid.JumpPower = r109.JumpPower
    end
  end
end

r118 = rv2
r116 = r116:Connect(rv2)
local r117 = r4.DescendantAdded

rv2 = function(param1)
  if r109.InstantPrompt and param1:IsA("ProximityPrompt") then
    param1.HoldDuration = 0
  end
end

local r119 = rv2
r117 = r117:Connect(rv2)
local r120 = { Title = "Movement", Icon = "move-3d" }
local r121 = true
r120.Box = r121
r120.BoxBorder = r121
r120.Opened = r121
r119 = r52
r118 = r52:Section(r120)
r121 = { Title = "WalkSpeed", Flag = "Move_WalkSpeed", Step = 1 }
local r123 = { Min = 16, Max = 800, Default = 20 }
local r122 = r123
r121.Value = r123

rv1 = function(param1)
  r109.WalkSpeed = param1

  if param1 == 20 and not r109.WalkSpeedModified then
    return
  end

  r109.WalkSpeedModified = param1 ~= 20
  local value, value1, value2 = r89()
  local flag = r15:GetAttribute("IsRiding") == true

  if value2 and (not flag or param1 > value2.WalkSpeed) then
    value2.WalkSpeed = param1
  end
end

r122 = rv1
r121.Callback = rv1
r120 = r118
r118:Slider(r121)
r121 = { Title = "Jump Power", Flag = "Move_JumpPower", Step = 1 }
r123 = { Min = 50, Max = 500, Default = 73 }
r122 = r123
r121.Value = r123

rv1 = function(param1)
  r109.JumpPower = param1

  if param1 == 73 and not r109.JumpPowerModified then
    return
  end

  r109.JumpPowerModified = param1 ~= 73
  local value, value1, value2 = r89()

  if value2 then
    value2.UseJumpPower = true
    value2.JumpPower = param1
  end
end

r122 = rv1
r121.Callback = rv1
r120 = r118
r118:Slider(r121)
r121 = { Title = "Fly Speed", Flag = "Move_FlySpeed", Step = 1 }
r123 = { Min = 10, Max = 500, Default = 100 }
r122 = r123
r121.Value = r123

rv2 = function(param1)
  r109.FlySpeed = param1
end

r122 = rv2
r121.Callback = rv2
r120 = r118
r118:Slider(r121)
r121 = { Title = "Fly", Flag = "Move_Fly", Value = false }

rv2 = function(param1)
  r109.FlyEnabled = param1

  if not param1 then
    r113(true)
  end
end

r122 = rv2
r121.Callback = rv2
r120 = r118
r118:Toggle(r121)

r121 = {
  Title = "Noclip",
  Desc = "Walk through walls and obstacles",
  Flag = "Move_Noclip",
  Value = false,
}

rv2 = function(param1)
  r109.NoclipEnabled = param1
end

r122 = rv2
r121.Callback = rv2
r120 = r118
r118:Toggle(r121)

r121 = {
  Title = "Infinite Jump",
  Desc = "Jump continuously in the air",
  Flag = "Move_InfiniteJump",
  Value = false,
}

rv2 = function(param1)
  r109.InfiniteJump = param1
end

r122 = rv2
r121.Callback = rv2
r120 = r118
r118:Toggle(r121)
r121 = { Title = "Instant Proximity Prompt", Flag = "Move_InstantPrompt", Value = false }

rv2 = function(param1)
  r109.InstantPrompt = param1

  if param1 then
    for _, item in ipairs(r4:GetDescendants()) do
      if item:IsA("ProximityPrompt") then
        item.HoldDuration = 0
      end
    end
  end
end

r122 = rv2
r121.Callback = rv2
r120 = r118
r118:Toggle(r121)
r1.LH_LocalMovement = r109

rv2 = function()
  r109.Closed = true
  r109.FlyEnabled = false
  r109.NoclipEnabled = false
  r109.InfiniteJump = false

  if r109.StepConnection then
    pcall(function()
      r109.StepConnection:Disconnect()
    end)
  end

  if r109.NoclipConnection then
    pcall(function()
      r109.NoclipConnection:Disconnect()
    end)
  end

  if r109.JumpRequestConnection then
    pcall(function()
      r109.JumpRequestConnection:Disconnect()
    end)
  end

  if r109.InputBegan then
    pcall(function()
      r109.InputBegan:Disconnect()
    end)
  end

  if r109.InputEnded then
    pcall(function()
      r109.InputEnded:Disconnect()
    end)
  end

  if r116 then
    pcall(function()
      r116:Disconnect()
    end)
  end

  if r117 then
    pcall(function()
      r117:Disconnect()
    end)
  end

  r113(true)
  local value, value1, value2 = r89()
  local flag = r15:GetAttribute("IsRiding") == true

  if value2 and not flag then
    pcall(function()
      if r109.WalkSpeedModified then
        value2.WalkSpeed = 20
      end

      if r109.JumpPowerModified then
        value2.JumpPower = 73
      end
    end)
  end

  if r1.LH_LocalMovement == r109 then
    r1.LH_LocalMovement = nil
  end
end

r119 = rv2
r1.LH_LocalMovementCleanup = rv2
task.wait(0.08)
r110 = {}
r111 = false
r110.Closed = r111
r110.Eggs = r111
r110.UsedEggs = r111
r112 = {}
r113 = true
r112["All Eggs"] = r113
r111 = r112
r110.EggFilter = r112
r112 = {}
r112["All Eggs"] = r113
r111 = r112
r110.UsedEggFilter = r112
r111 = false
r110.OwnEggs = r111
r110.Players = r111
r110.Container = nil
r112 = {}
r111 = r112
r110.Cache = r112
r109 = r110
r110 = Instance.new("Folder")
r110.Name = "LinkhiveESP"

rv1 = function(...)
  local s1 = r110
  s1.Parent = r9
end

r112 = rv1
pcall(rv1)

if not r110.Parent then
  r110.Parent = r4
end

r109.Container = r110

r111 = function(param1)
  local value = r109.Cache[param1]

  if value then
    pcall(function()
      value:Destroy()
    end)

    r109.Cache[param1] = nil
  end
end

r112 = function(param1, param2, param3)
  local value = param1:FindFirstChild("Handle") or param1:FindFirstChildWhichIsA("BasePart")

  if not value then
    return
  end

  local str = "Egg_" .. tostring(param1:GetAttribute("EggKey") or pcall(function()
    return param1:GetDebugId()
  end) and param1:GetDebugId() or tostring(param1))

  if r109.Cache[str] and r109.Cache[str].Parent == r109.Container then
    return
  end

  r111(str)
  local billboardGui = Instance.new("BillboardGui")
  billboardGui.Name = str
  billboardGui.Adornee = value
  billboardGui.AlwaysOnTop = true
  billboardGui.Size = UDim2.new(0, 140, 0, 40)
  billboardGui.StudsOffset = Vector3.new(0, 2.5, 0)
  local textLabel = Instance.new("TextLabel")
  textLabel.Size = UDim2.new(1, 0, 0.5, 0)
  textLabel.BackgroundTransparency = 1
  textLabel.TextSize = 13
  textLabel.Font = Enum.Font.GothamBold
  textLabel.TextColor3 = param2 and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 200, 50)
  textLabel.TextStrokeTransparency = 0.2

  if param2 then
    textLabel.Text = param1.Name .. " [Own]"
  elseif param3 and param3 ~= "" and param3 ~= "Unknown" then
    textLabel.Text = param1.Name .. " [" .. param3 .. "]"
  else
    textLabel.Text = param1.Name
  end

  textLabel.Parent = billboardGui
  local textLabel1 = Instance.new("TextLabel")
  textLabel1.Size = UDim2.new(1, 0, 0.5, 0)
  textLabel1.Position = UDim2.new(0, 0, 0.5, 0)
  textLabel1.BackgroundTransparency = 1
  textLabel1.TextSize = 11
  textLabel1.Font = Enum.Font.Gotham
  textLabel1.TextColor3 = Color3.fromRGB(255, 255, 255)
  textLabel1.TextStrokeTransparency = 0.3
  textLabel1.Text = "..."
  textLabel1.Parent = billboardGui
  local highlight = Instance.new("Highlight")
  highlight.Adornee = param1
  highlight.FillColor = param2 and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(255, 180, 20)
  highlight.FillTransparency = 0.6
  highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
  highlight.OutlineTransparency = 0.2
  highlight.Parent = billboardGui
  billboardGui.Parent = r109.Container
  r109.Cache[str] = billboardGui

  task.spawn(function()
    while billboardGui.Parent == r109.Container and param1.Parent and not r109.Closed do
      local value1, value2 = r89()

      if value2 and value.Parent then
        local num = math.floor((value.Position - value2.Position).Magnitude)
        textLabel1.Text = tostring(num) .. " studs"
      end

      task.wait(0.5)
    end

    r111(str)
  end)
end

r113 = function(param1)
  if param1 == r15 then
    return
  end

  local str = "Plr_" .. param1.Name
  r111(str)
  local character = param1.Character
  local value = character and character:FindFirstChild("HumanoidRootPart")

  if not value then
    return
  end

  local billboardGui = Instance.new("BillboardGui")
  billboardGui.Name = str
  billboardGui.Adornee = value
  billboardGui.AlwaysOnTop = true
  billboardGui.Size = UDim2.new(0, 140, 0, 30)
  billboardGui.StudsOffset = Vector3.new(0, 3, 0)
  local textLabel = Instance.new("TextLabel")
  textLabel.Size = UDim2.new(1, 0, 1, 0)
  textLabel.BackgroundTransparency = 1
  textLabel.TextSize = 12
  textLabel.Font = Enum.Font.GothamBold
  textLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
  textLabel.TextStrokeTransparency = 0.2
  textLabel.Text = param1.Name
  textLabel.Parent = billboardGui
  local highlight = Instance.new("Highlight")
  highlight.Adornee = character
  highlight.FillColor = Color3.fromRGB(255, 50, 50)
  highlight.FillTransparency = 0.7
  highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
  highlight.OutlineTransparency = 0.3
  highlight.Parent = billboardGui
  billboardGui.Parent = r109.Container
  r109.Cache[str] = billboardGui

  task.spawn(function()
    while billboardGui.Parent == r109.Container
      and param1.Parent
      and character.Parent
      and not r109.Closed do
      local value1, value2 = r89()

      if value2 and value.Parent then
        local num = math.floor((value.Position - value2.Position).Magnitude)
        textLabel.Text = param1.Name .. " (" .. tostring(num) .. "m)"
      end

      task.wait(0.4)
    end

    r111(str)
  end)
end

r114 = function(param1)
  local value = r109.EggFilter or r109.UsedEggFilter

  if not value or next(value) == nil or value["All Eggs"] then
    return true
  end

  return value[param1] == true
end

r115 = r114

r116 = function()
  if r109.Closed then
    return
  end

  local value = r109.Eggs or r109.UsedEggs
  local plots = r4:FindFirstChild("Plots")

  if plots then
    for _, item in ipairs(plots:GetChildren()) do
      local data = item:FindFirstChild("Data")
      local value1 = data and data:FindFirstChild("Owner")
      local value2 = value1 and value1.Value == r15
      local value3 = value1 and value1.Value and value1.Value.Name or "Unknown"
      local eggs = item:FindFirstChild("Eggs")

      if eggs then
        for _, item in ipairs(eggs:GetChildren()) do
          local str = "Egg_" .. tostring(item:GetAttribute("EggKey") or pcall(function()
            return item:GetDebugId()
          end) and item:GetDebugId() or tostring(item))

          if value2 and r109.OwnEggs then
            r112(item, true, value3)
          elseif value and r114(item.Name) then
            r112(item, value2, value3)
          else
            r111(str)
          end
        end
      end
    end
  end

  local renderedEggs = r4:FindFirstChild("RenderedEggs")

  if renderedEggs then
    for _, item in ipairs(renderedEggs:GetChildren()) do
      local str = "Egg_" .. tostring(item:GetAttribute("EggKey") or pcall(function()
        return item:GetDebugId()
      end) and item:GetDebugId() or tostring(item))

      if value and r114(item.Name) then
        r112(item, false, nil)
      else
        r111(str)
      end
    end
  end

  local eggs = r4:FindFirstChild("Eggs")

  if eggs then
    for _, item in ipairs(eggs:GetChildren()) do
      local str = "Egg_" .. tostring(item:GetAttribute("EggKey") or pcall(function()
        return item:GetDebugId()
      end) and item:GetDebugId() or tostring(item))

      if value and r114(item.Name) then
        r112(item, false, nil)
      else
        r111(str)
      end
    end
  end

  for _, item in ipairs{ "AsteroidEgg", "AdminEgg" } do
    local value1 = r4:FindFirstChild(item)

    if value1
      and value1:IsA("Model")
      and (value1:FindFirstChild("Handle") or value1:FindFirstChildWhichIsA("BasePart")) then
      local str = "Egg_" .. tostring(value1:GetAttribute("EggKey") or pcall(function()
        return value1:GetDebugId()
      end) and value1:GetDebugId() or value1.Name)

      if value and r114(value1.Name) then
        r112(value1, false, nil)
      else
        r111(str)
      end
    end
  end

  if r109.Players then
    for _, item in ipairs(r3:GetPlayers()) do
      r113(item)
    end
  else
    for _, item in ipairs(r3:GetPlayers()) do
      r111("Plr_" .. item.Name)
    end
  end
end

r117 = task.spawn

rv2 = function()
  while not r109.Closed do
    if r109.Eggs or r109.UsedEggs or r109.OwnEggs or r109.Players then
      pcall(r116)
    end

    task.wait(2)
  end
end

r118 = rv2
r117(rv2)
r119 = { Title = "ESP Visuals", Icon = "eye" }
r120 = true
r119.Box = r120
r119.BoxBorder = r120
r119.Opened = r120
r118 = r52
r117 = r52:Section(r119)
r120 = { Title = "Eggs ESP", Flag = "ESP_Eggs", Value = false }

rv2 = function(param1)
  r109.Eggs = param1
  r109.UsedEggs = param1

  if not param1 then
    for key in pairs(r109.Cache) do
      if key:find("^Egg_") and not r109.OwnEggs then
        r111(key)
      end
    end
  end

  pcall(r116)
end

r121 = rv2
r120.Callback = rv2
r119 = r117
r117:Toggle(r120)
r120 = { Title = "Eggs Filter", Flag = "ESP_EggFilter", Values = r101 }
r122 = { "All Eggs" }
r121 = r122
r120.Value = r122
r121 = true
r120.Multi = r121
r120.AllowNone = r121

rv1 = function(param1)
  local tbl = {}

  if type(param1) == "table" then
    for _, item in ipairs(param1) do
      tbl[item] = true
    end
  elseif type(param1) == "string" and param1 ~= "" then
    tbl[param1] = true
  end

  if next(tbl) == nil then
    tbl["All Eggs"] = true
  end

  r109.EggFilter = tbl
  r109.UsedEggFilter = tbl
  pcall(r116)
end

r121 = rv1
r120.Callback = rv1
r119 = r117
r117:Dropdown(r120)
r120 = { Title = "Own Eggs ESP", Flag = "ESP_OwnEggs", Value = false }

rv1 = function(param1)
  r109.OwnEggs = param1

  if not param1 then
    for key in pairs(r109.Cache) do
      if key:find("^Egg_") and not (r109.Eggs or r109.UsedEggs) then
        r111(key)
      end
    end
  end

  pcall(r116)
end

r121 = rv1
r120.Callback = rv1
r119 = r117
r117:Toggle(r120)
r120 = { Title = "Player ESP", Flag = "ESP_Players", Value = false }

rv1 = function(param1)
  r109.Players = param1

  if not param1 then
    for key in pairs(r109.Cache) do
      if key:find("^Plr_") then
        r111(key)
      end
    end
  else
    pcall(r116)
  end
end

r121 = rv1
r120.Callback = rv1
r119 = r117
r117:Toggle(r120)
r1.LH_ESP = r109

rv1 = function()
  r109.Closed = true

  for key in pairs(r109.Cache) do
    r111(key)
  end

  if r109.Container then
    pcall(function()
      r109.Container:Destroy()
    end)
  end

  if r1.LH_ESP == r109 then
    r1.LH_ESP = nil
  end
end

r118 = rv1
r1.LH_ESPCleanup = rv1
task.wait(0.08)
r110 = {}
r111 = false
r110.Closed = r111
r110.AntiTrap = r111
r110.AntiRagdoll = r111
r112 = {}
r111 = r112
r110.Connections = r112
r109 = r110

r110 = function()
  local __DEBRIS = r4:FindFirstChild("__DEBRIS")

  if __DEBRIS then
    for _, item in ipairs(__DEBRIS:GetChildren()) do
      if item.Name:lower():find("trap") then
        local hitbox = item:FindFirstChild("Hitbox")

        if hitbox then
          pcall(function()
            hitbox:Destroy()
          end)
        end
      end
    end
  end
end

r111 = function()
  local value, value1, value2 = r89()

  if not value1 or not value2 then
    return
  end

  local state = value2:GetState()

  if state == Enum.HumanoidStateType.FallingDown
    or state == Enum.HumanoidStateType.Ragdoll
    or state == Enum.HumanoidStateType.Physics then
    value2.Sit = false
    value2.PlatformStand = false
    value1.AssemblyLinearVelocity = Vector3.zero
    value1.AssemblyAngularVelocity = Vector3.zero

    pcall(function()
      value2:ChangeState(Enum.HumanoidStateType.GettingUp)
    end)

    pcall(function()
      value2:ChangeState(Enum.HumanoidStateType.Running)
    end)
  end
end

r112 = table.insert
r113 = r109.Connections
r114 = r6.Heartbeat

rv1 = function()
  if r109.Closed then
    return
  end

  if r109.AntiRagdoll then
    r111()
  end
end

r116 = rv1
r112(r113, r114:Connect(rv1))
r112 = table.insert
r113 = r109.Connections
r114 = r4.DescendantAdded

rv1 = function(param1)
  if r109.Closed or not r109.AntiTrap then
    return
  end

  if param1.Name == "Hitbox" and param1.Parent and param1.Parent.Name:lower():find("trap") then
    task.defer(function()
      pcall(function()
        param1:Destroy()
      end)
    end)
  end
end

r116 = rv1
r112(r113, r114:Connect(rv1))
r1.LH_Anti = r109

rv2 = function()
  r109.Closed = true

  for _, item in ipairs(r109.Connections) do
    pcall(function()
      item:Disconnect()
    end)
  end

  table.clear(r109.Connections)

  if r1.LH_Anti == r109 then
    r1.LH_Anti = nil
  end
end

r112 = rv2
r1.LH_AntiCleanup = rv2
task.wait(0.08)
r110 = { Closed = false }
r111 = true
r110.AntiAfkEnabled = r111
r110.AutoRejoinEnabled = r111
r110.RejoinDelay = 5
r110.AutoExecuteEnabled = true
r112 = {}
r111 = r112
r110.Connections = r112
r109 = r110

r110 = function(...)
  r27()

  if not pcall(function(...)
    local t4 = game
    r13:TeleportToPlaceInstance(t4.PlaceId, t4.JobId, r15)
  end) then
    pcall(function(...)
      r13:Teleport(game.PlaceId, r15)
    end)
  end
end

r111 = function(...)
  r27()
  local s2 = game
  local s1 = s2.PlaceId
  local s3 = s2
  s2 = s2.JobId

  s3 = string.format(
    "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100",
    tostring(s1)
  )

  local s4 = {}

  pcall(function(...)
    local t2, t7
    local t1 = nil

    if r24 then
      t2 = r24({ Url = s3, Method = "GET" })

      if t2 and t2.Body then
        t1 = t2.Body
      end
    else
      if type(httpget) == "function" then
        t1 = httpget(game, s3)
      else
        if game.HttpGet then
          t1 = game:HttpGet(s3)
        end
      end
    end

    if t1 then
      t2 = r8:JSONDecode(t1)

      if t2 and t2.data then
        for t6, t7 in ipairs(t2.data) do
          if t7.id ~= s2 and t7.playing and t7.maxPlayers and t7.playing < t7.maxPlayers then
            table.insert(s4, t7.id)
          end
        end
      end
    end
  end)

  if #s4 > 0 then
    r13:TeleportToPlaceInstance(s1, s4[math.random(1, #s4)], r15)
  else
    r13:Teleport(s1, r15)
  end
end

r112 = function(param1)
  local value = type(getconnections) == "function" and getconnections or (type(get_signal_cons) == "function" and get_signal_cons or nil)

  if not value then
    return
  end

  pcall(function()
    for _, item in ipairs(value(r15.Idled)) do
      if param1 then
        if item.Disable then
          item:Disable()
        end
      else
        if item.Enable then
          item:Enable()
        end
      end
    end
  end)
end

r112(r109.AntiAfkEnabled)
r113 = false

r114 = function()
  if r113 or not r109.AutoRejoinEnabled or r109.Closed then
    return
  end

  local str = ""

  pcall(function()
    str = r14:GetErrorMessage()
  end)

  if type(str) == "string" and #str == 0 then
    return
  end

  r113 = true

  r41(
    "Auto Rejoin",
    string.format("Disconnected/Kicked. Rejoining in %d seconds...", r109.RejoinDelay),
    "rotate-cw",
    r109.RejoinDelay
  )

  task.wait(r109.RejoinDelay)

  if not r109.Closed then
    r110()
  end
end

r115 = r14.ErrorMessageChanged

rv1 = function()
  task.defer(r114)
end

r117 = rv1
r115 = r115:Connect(rv1)
r118 = r115
table.insert(r109.Connections, r115)

rv1 = function(...)
  local s1 = r9:FindFirstChild("RobloxPromptGui") and r9.RobloxPromptGui:FindFirstChild("promptOverlay")

  if s1 then
    table.insert(r109.Connections, (s1.ChildAdded:Connect((function(param1)
      if param1.Name == "ErrorPrompt" then
        task.defer(r114)
      end
    end))))
  end
end

r117 = rv1
pcall(rv1)
r116 = r15.OnTeleport

rv2 = function(param1)
  if param1 == Enum.TeleportState.Started then
    r27()
  elseif param1 == Enum.TeleportState.Failed then
    r28()
  end
end

r118 = rv2
r116 = r116:Connect(rv2)
r119 = r116
table.insert(r109.Connections, r116)
r119 = { Title = "Miscellaneous", Icon = "wrench" }
r120 = true
r119.Box = r120
r119.BoxBorder = r120
r119.Opened = r120
r118 = r51
r117 = r51:Section(r119)

r120 = {
  Title = "Anti AFK",
  Desc = "Prevents 20-minute idle disconnection",
  Flag = "Misc_AntiAFK",
  Value = true,
}

rv2 = function(param1)
  r109.AntiAfkEnabled = param1
  r112(param1)
end

r121 = rv2
r120.Callback = rv2
r119 = r117
r117:Toggle(r120)

r120 = {
  Title = "Auto Rejoin When Kicked",
  Desc = "Automatically reconnects if kicked or disconnected",
  Flag = "Misc_AutoRejoin",
  Value = true,
}

rv1 = function(param1)
  r109.AutoRejoinEnabled = param1
end

r121 = rv1
r120.Callback = rv1
r119 = r117
r117:Toggle(r120)
r120 = { Title = "Rejoin Delay (s)", Flag = "Misc_RejoinDelay" }
r121 = 1
r120.Step = r121
r122 = {}
r123 = r121
r122.Min = r121
r122.Max = 30
r122.Default = 5
r121 = r122
r120.Value = r122

rv1 = function(param1)
  r109.RejoinDelay = param1
end

r121 = rv1
r120.Callback = rv1
r119 = r117
r117:Slider(r120)

r120 = {
  Title = "Auto Execute On Teleport",
  Desc = "Executes script again after teleport",
  Flag = "Misc_AutoExecute",
  Value = true,
}

rv2 = function(param1)
  r109.AutoExecuteEnabled = param1
  r25 = param1
end

r121 = rv2
r120.Callback = rv2
r119 = r117
r117:Toggle(r120)
r120 = { Title = "Rejoin Current Server", Icon = "rotate-cw" }

rv2 = function()
  r41("Rejoin", "Rejoining current server...", "rotate-cw", 3)
  task.spawn(r110)
end

r121 = rv2
r120.Callback = rv2
r119 = r117
r117:Button(r120)
r120 = { Title = "Server Hop (Random)", Icon = "shuffle" }

rv1 = function()
  r41("Server Hop", "Finding public server...", "shuffle", 3)
  task.spawn(r111)
end

r121 = rv1
r120.Callback = rv1
r119 = r117
r117:Button(r120)
r120 = { Title = "Copy Server Join Script", Icon = "clipboard" }

rv1 = function()
  local str = string.format(
    'game:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s", game.Players.LocalPlayer)',
    tostring(game.PlaceId),
    tostring(game.JobId)
  )

  pcall(r22, str)
  r41("Clipboard", "Copied join code to clipboard.", "clipboard", 3)
end

r121 = rv1
r120.Callback = rv1
r119 = r117
r117:Button(r120)
r120 = { Title = "Copy Place & Job ID", Icon = "copy" }

rv2 = function()
  local str = string.format("PlaceId: %s | JobId: %s", tostring(game.PlaceId), tostring(game.JobId))
  pcall(r22, str)
  r41("Clipboard", "Copied server info to clipboard.", "copy", 3)
end

r121 = rv2
r120.Callback = rv2
r119 = r117
r117:Button(r120)
r1.LH_Misc = r109

rv1 = function()
  r109.Closed = true
  r112(false)

  for _, item in ipairs(r109.Connections) do
    pcall(function()
      item:Disconnect()
    end)
  end

  if r1.LH_Misc == r109 then
    r1.LH_Misc = nil
  end
end

r118 = rv1
r1.LH_MiscCleanup = rv1
task.wait(0.08)
r110 = {}
r111 = false
r110.Closed = r111
r110.NoTextures = r111
r110.NoFx = r111
r110.NoLights = r111
r110.HidePets = r111
r110.HideMapDetail = r111
r110.HidePlayers = r111
r110.NoAccessories = r111
r110.LowLighting = r111
r110.LowWater = r111
r110.LowQuality = r111
r110.MuteSounds = r111
r110.FpsCap = 0
r109 = r110
r111 = {}
r112 = true
r111.ClientRenderedAssets = r112
r111.PlacedEggRenders = r112
r111.PetRenders = r112
r110 = r111
r112 = {}
r113 = true
r112.Plots = r113
r112.__OBJECTS = r113
r112.__DEBRIS = r113
r112.AreaEggSlotsClient = r113
r112.Terrain = r113
r112.Camera = r113
r112.LinkhiveESP = r113
r111 = r112

r112 = function(param)
  return param:find("Sakura") ~= nil
    or param:find("Bloomed") ~= nil
    or param:find("Crystals") ~= nil
    or param:find("FXHost") ~= nil
end

r113 = function(param1)
  local value = param1

  while value and value ~= r4 do
    if value.Name == "LinkhiveESP" then
      return true
    end

    value = value.Parent
  end

  return false
end

r114 = function()
  return { Hidden = {}, Props = {}, Connections = {} }
end

r115 = function(param, param1)
  if not param1 or param.Hidden[param1] ~= nil then
    return
  end

  local parent = param1.Parent

  if not parent then
    return
  end

  param.Hidden[param1] = parent

  pcall(function()
    param1.Parent = nil
  end)
end

r116 = function(param, param1, param2, param3)
  if not param1 then
    return
  end

  local value, value1 = pcall(function()
    return param1[param2]
  end)

  if not value then
    return
  end

  local value2 = param.Props[param1]

  if not value2 then
    value2 = {}
    param.Props[param1] = value2
  end

  if value2[param2] == nil then
    value2[param2] = value1
  end

  pcall(function()
    param1[param2] = param3
  end)
end

r117 = function(param)
  for _, item in ipairs(param.Connections) do
    pcall(function()
      item:Disconnect()
    end)
  end

  table.clear(param.Connections)

  for key, value in pairs(param.Hidden) do
    pcall(function()
      key.Parent = value
    end)
  end

  table.clear(param.Hidden)

  for key, value in pairs(param.Props) do
    for key1, value in pairs(value) do
      pcall(function()
        key[key1] = value
      end)
    end
  end

  table.clear(param.Props)
end

r118 = function(param, param1, param2, param3)
  param2 = param2 or 150
  local count = #param

  for i = 1, count, param2 do
    if param3 and param3() then
      break
    end

    for i = i, math.min(i + param2 - 1, count) do
      param1(param[i])
    end

    task.wait()
  end
end

r120 = {}
r121 = r114
r120.Textures = r114()
r121 = r114
r120.Fx = r114()
r121 = r114
r120.Lights = r114()
r121 = r114
r120.Pets = r114()
r121 = r114
r120.MapDetail = r114()
r121 = r114
r120.Players = r114()
r121 = r114
r120.Accessories = r114()
r121 = r114
r120.Lighting = r114()
r121 = r114
r120.Water = r114()
r121 = r114
r120.Quality = r114()
r121 = r114
r120.Sounds = r114()
r119 = r120

r120 = function(param1)
  if r113(param1) then
    return
  end

  if param1:IsA("Decal") or param1:IsA("Texture") then
    r116(r119.Textures, param1, "Transparency", 1)
  elseif param1:IsA("SurfaceAppearance") then
    r115(r119.Textures, param1)
  elseif param1:IsA("MeshPart") then
    if param1.TextureID ~= "" then
      r116(r119.Textures, param1, "TextureID", "")
    end

    r116(r119.Textures, param1, "Material", Enum.Material.SmoothPlastic)
  elseif param1:IsA("BasePart") then
    r116(r119.Textures, param1, "Material", Enum.Material.SmoothPlastic)
    r116(r119.Textures, param1, "Reflectance", 0)
  end
end

r121 = function(param1)
  r109.NoTextures = param1 == true

  if not r109.NoTextures then
    r117(r119.Textures)
    return
  end

  task.spawn(function()
    r118(r4:GetDescendants(), r120, 150, function()
      return r109.Closed or not r109.NoTextures
    end)
  end)

  table.insert(r119.Textures.Connections, r4.DescendantAdded:Connect(function(param1)
    if r109.Closed or not r109.NoTextures then
      return
    end

    task.defer(function()
      if r109.NoTextures and param1.Parent then
        r120(param1)
      end
    end)
  end))
end

r122 = function(param)
  return param:IsA("ParticleEmitter")
    or param:IsA("Trail")
    or param:IsA("Beam")
    or param:IsA("Smoke")
    or param:IsA("Fire")
    or param:IsA("Sparkles")
end

r123 = function(param1)
  if r113(param1) then
    return
  end

  if r122(param1) then
    r116(r119.Fx, param1, "Enabled", false)
  end
end

local r124 = function(param1)
  r109.NoFx = param1 == true

  if not r109.NoFx then
    r117(r119.Fx)
    return
  end

  task.spawn(function()
    r118(r4:GetDescendants(), r123, 150, function()
      return r109.Closed or not r109.NoFx
    end)

    if r109.NoFx and not r109.Closed then
      r118(r10:GetDescendants(), r123, 150, function()
        return r109.Closed or not r109.NoFx
      end)
    end
  end)

  table.insert(r119.Fx.Connections, r4.DescendantAdded:Connect(function(param1)
    if r109.Closed or not r109.NoFx then
      return
    end

    task.defer(function()
      if r109.NoFx and param1.Parent then
        r123(param1)
      end
    end)
  end))
end

local r125 = function(param1)
  if r113(param1) then
    return
  end

  if param1:IsA("Light") then
    r116(r119.Lights, param1, "Enabled", false)
  end
end

local r126 = function(param1)
  r109.NoLights = param1 == true

  if not r109.NoLights then
    r117(r119.Lights)
    return
  end

  task.spawn(function()
    r118(r4:GetDescendants(), r125, 150, function()
      return r109.Closed or not r109.NoLights
    end)
  end)

  table.insert(r119.Lights.Connections, r4.DescendantAdded:Connect(function(param1)
    if r109.Closed or not r109.NoLights then
      return
    end

    task.defer(function()
      if r109.NoLights and param1.Parent then
        r125(param1)
      end
    end)
  end))
end

local r127 = function(param1, param2, param3)
  local value

  if param3 then
    local character = r15.Character
    local value1 = character and character:FindFirstChild("HumanoidRootPart")
    local value2 = value1 and value1:FindFirstChild("PetMountJoint")
    value = value2 and value2.Part1 and value2.Part1.Parent
  end

  for _, item in ipairs(param2:GetDescendants()) do
    if not (value and item:IsDescendantOf(value)) then
      if item:IsA("BasePart") then
        r116(param1, item, "LocalTransparencyModifier", 1)
      elseif item:IsA("Decal") or item:IsA("Texture") then
        r116(param1, item, "Transparency", 1)
      end
    end
  end
end

local r128 = function(param1)
  r109.HidePets = param1 == true

  if not r109.HidePets then
    r117(r119.Pets)
    return
  end

  for _, item in ipairs(r4:GetChildren()) do
    if r110[item.Name] then
      r127(r119.Pets, item, true)

      table.insert(r119.Pets.Connections, item.DescendantAdded:Connect(function(param1)
        if r109.Closed or not r109.HidePets then
          return
        end

        local character = r15.Character
        local value = character and character:FindFirstChild("HumanoidRootPart")
        local value1 = value and value:FindFirstChild("PetMountJoint")
        local value2 = value1 and value1.Part1 and value1.Part1.Parent

        if value2 and param1:IsDescendantOf(value2) then
          return
        end

        if param1:IsA("BasePart") then
          r116(r119.Pets, param1, "LocalTransparencyModifier", 1)
        elseif param1:IsA("Decal") or param1:IsA("Texture") then
          r116(r119.Pets, param1, "Transparency", 1)
        end
      end))
    end
  end
end

local r129 = function(param1)
  r109.HideMapDetail = param1 == true

  if not r109.HideMapDetail then
    r117(r119.MapDetail)
    return
  end

  for _, item in ipairs(r4:GetChildren()) do
    if not r111[item.Name] and r112(item.Name) then
      r127(r119.MapDetail, item, false)
    end
  end

  local __OBJECTS = r4:FindFirstChild("__OBJECTS")

  if __OBJECTS then
    for _, item in ipairs(__OBJECTS:GetChildren()) do
      if r112(item.Name) then
        r127(r119.MapDetail, item, false)
      end
    end
  end
end

local r130 = function(param1)
  local playerFromCharacter = r3:GetPlayerFromCharacter(param1)
  return playerFromCharacter ~= nil and playerFromCharacter ~= r15
end

local r131 = function(param1)
  if not param1 then
    return
  end

  for _, item in ipairs(param1:GetDescendants()) do
    if item:IsA("BasePart") then
      r116(r119.Players, item, "LocalTransparencyModifier", 1)
    elseif item:IsA("Decal") then
      r116(r119.Players, item, "Transparency", 1)
    elseif item:IsA("BillboardGui") then
      r116(r119.Players, item, "Enabled", false)
    end
  end
end

local r132 = function(param1)
  r109.HidePlayers = param1 == true

  if not r109.HidePlayers then
    r117(r119.Players)
    return
  end

  for _, item in ipairs(r3:GetPlayers()) do
    if item ~= r15 then
      r131(item.Character)

      table.insert(r119.Players.Connections, item.CharacterAdded:Connect(function(param1)
        if r109.Closed or not r109.HidePlayers then
          return
        end

        task.wait(0.5)

        if r109.HidePlayers then
          r131(param1)
        end
      end))
    end
  end

  table.insert(r119.Players.Connections, r3.PlayerAdded:Connect(function(param1)
    if r109.Closed or not r109.HidePlayers then
      return
    end

    table.insert(r119.Players.Connections, param1.CharacterAdded:Connect(function(param1)
      if r109.Closed or not r109.HidePlayers then
        return
      end

      task.wait(0.5)

      if r109.HidePlayers then
        r131(param1)
      end
    end))
  end))

  task.spawn(function()
    while not r109.Closed and r109.HidePlayers do
      for _, item in ipairs(r3:GetPlayers()) do
        if item ~= r15 then
          r131(item.Character)
        end
      end

      task.wait(3)
    end
  end)
end

local r133 = function(param1)
  if not param1 then
    return
  end

  for _, item in ipairs(param1:GetChildren()) do
    if item:IsA("Accessory") or item:IsA("Hat") then
      r115(r119.Accessories, item)
    end
  end
end

local r134 = function(param1)
  r109.NoAccessories = param1 == true

  if not r109.NoAccessories then
    r117(r119.Accessories)
    return
  end

  for _, item in ipairs(r3:GetPlayers()) do
    if item ~= r15 then
      r133(item.Character)
    end
  end

  table.insert(r119.Accessories.Connections, r4.ChildAdded:Connect(function(param1)
    if r109.Closed or not r109.NoAccessories then
      return
    end

    task.defer(function()
      if r109.NoAccessories and r130(param1) then
        task.wait(0.5)
        r133(param1)
      end
    end)
  end))
end

local r135 = function(param1)
  r109.LowLighting = param1 == true

  if not r109.LowLighting then
    r117(r119.Lighting)
    return
  end

  r116(r119.Lighting, r10, "GlobalShadows", false)
  r116(r119.Lighting, r10, "Brightness", 1)
  r116(r119.Lighting, r10, "EnvironmentDiffuseScale", 0)
  r116(r119.Lighting, r10, "EnvironmentSpecularScale", 0)

  for _, item in ipairs(r10:GetChildren()) do
    if item:IsA("PostEffect") then
      r116(r119.Lighting, item, "Enabled", false)
    elseif item:IsA("Atmosphere") then
      r115(r119.Lighting, item)
    end
  end
end

local r136 = function(param1)
  r109.LowWater = param1 == true

  if not r109.LowWater then
    r117(r119.Water)
    return
  end

  local terrain = r4.Terrain
  r116(r119.Water, terrain, "WaterWaveSize", 0)
  r116(r119.Water, terrain, "WaterWaveSpeed", 0)
  r116(r119.Water, terrain, "WaterReflectance", 0)
  r116(r119.Water, terrain, "WaterTransparency", 0)
end

local r137 = function(param1)
  r109.LowQuality = param1 == true

  if not r109.LowQuality then
    r117(r119.Quality)
    return
  end

  pcall(function()
    r116(r119.Quality, settings().Rendering, "QualityLevel", Enum.QualityLevel.Level01)
  end)
end

local r138 = function(param1)
  if param1:IsA("Sound") then
    r116(r119.Sounds, param1, "Volume", 0)
  end
end

local r139 = function(param1)
  r109.MuteSounds = param1 == true

  if not r109.MuteSounds then
    r117(r119.Sounds)
    return
  end

  task.spawn(function()
    r118(r4:GetDescendants(), r138, 150, function()
      return r109.Closed or not r109.MuteSounds
    end)

    if r109.MuteSounds and not r109.Closed then
      r118(r11:GetDescendants(), r138, 150, function()
        return r109.Closed or not r109.MuteSounds
      end)
    end
  end)

  table.insert(r119.Sounds.Connections, r4.DescendantAdded:Connect(function(param1)
    if r109.Closed or not r109.MuteSounds then
      return
    end

    task.defer(function()
      if r109.MuteSounds and param1.Parent then
        r138(param1)
      end
    end)
  end))
end

local r140 = nil

local r141 = function(param1)
  local num = math.floor(tonumber(param1) or 0)
  r109.FpsCap = num

  if type(setfpscap) ~= "function" then
    return
  end

  if r140 == nil and type(getfpscap) == "function" then
    local value, value1 = pcall(getfpscap)
    r140 = value and tonumber(value1) or 60
  end

  pcall(setfpscap, num <= 0 and (r140 or 60) or num)
end

local r144 = { Title = "Performance / Reduce Lag", Icon = "gauge" }
local r145 = true
r144.Box = r145
r144.BoxBorder = r145
r144.Opened = r145
local r143 = r51
local r142 = r51:Section(r144)
r144 = r142

r143 = r142:Paragraph({
  Title = "FPS Monitor",
  Desc = "Measuring...",
  Image = "activity",
  ImageSize = 26,
})

r144 = nil
r145 = nil
local r146 = nil
local r147 = nil
local r148 = nil
local r149 = nil
local r150 = nil
local r151 = nil
local r152 = nil
local r153 = nil
local r154 = false

local r155 = function(param, param1)
  if not param then
    return
  end

  pcall(function()
    param:Set(param1)
  end)
end

r142:Toggle({
  Title = "Boost FPS (All Optimizations)",
  Desc = "Turns on every render optimization below at once.",
  Flag = "Misc_PerfBoost",
  Value = false,
  Callback = function(param1)
    if r154 then
      return
    end

    r154 = true
    local flag = param1 == true

    task.spawn(function()
      r155(r144, flag)
      task.wait(0.06)
      r155(r145, flag)
      task.wait(0.06)
      r155(r146, flag)
      task.wait(0.06)
      r155(r147, flag)
      task.wait(0.06)
      r155(r148, flag)
      task.wait(0.06)
      r155(r150, flag)
      task.wait(0.06)
      r155(r151, flag)
      task.wait(0.06)
      r155(r152, flag)
      task.wait(0.06)
      r155(r153, flag)
      r154 = false
    end)
  end,
})

r142:Divider()

r144 = r142:Toggle({
  Title = "Remove Textures & Decals",
  Desc = "Clears MeshPart textures, decals and surface appearances.",
  Flag = "Misc_PerfNoTextures",
  Value = false,
  Callback = r121,
})

r145 = r142:Toggle({
  Title = "Disable Particles & Trails",
  Flag = "Misc_PerfNoFx",
  Value = false,
  Callback = r124,
})

r146 = r142:Toggle({
  Title = "Disable Dynamic Lights",
  Flag = "Misc_PerfNoLights",
  Value = false,
  Callback = r126,
})

r147 = r142:Toggle({
  Title = "Hide Pet / Egg Renders",
  Desc = "Hides pet and placed-egg render folders (client visuals only).",
  Flag = "Misc_PerfHidePets",
  Value = false,
  Callback = r128,
})

r148 = r142:Toggle({
  Title = "Hide Map Decoration",
  Desc = "Hides trees, crystals and other cosmetic map props.",
  Flag = "Misc_PerfHideMapDetail",
  Value = false,
  Callback = r129,
})

r149 = r142:Toggle({
  Title = "Hide Other Players",
  Flag = "Misc_PerfHidePlayers",
  Value = false,
  Callback = r132,
})

r150 = r142:Toggle({
  Title = "Remove Player Accessories",
  Flag = "Misc_PerfNoAccessories",
  Value = false,
  Callback = r134,
})

r142:Divider()

r151 = r142:Toggle({
  Title = "No Shadows / No Post FX",
  Flag = "Misc_PerfLowLighting",
  Value = false,
  Callback = r135,
})

r152 = r142:Toggle({
  Title = "Flat Water",
  Flag = "Misc_PerfLowWater",
  Value = false,
  Callback = r136,
})

r153 = r142:Toggle({
  Title = "Lowest Graphics Quality",
  Flag = "Misc_PerfLowQuality",
  Value = false,
  Callback = r137,
})

r142:Toggle({
  Title = "Mute Game Sounds",
  Flag = "Misc_PerfMuteSounds",
  Value = false,
  Callback = r139,
})

r142:Slider({
  Title = "FPS Cap (0 = executor default)",
  Flag = "Misc_PerfFpsCap",
  Step = 5,
  Value = { Min = 0, Max = 360, Default = 0 },
  Callback = r141,
})

r142:Button({
  Title = "Restore Everything",
  Icon = "rotate-ccw",
  Callback = function()
    r155(r144, false)
    r155(r145, false)
    r155(r146, false)
    r155(r147, false)
    r155(r148, false)
    r155(r149, false)
    r155(r150, false)
    r155(r151, false)
    r155(r152, false)
    r155(r153, false)

    for _, value in pairs(r119) do
      r117(value)
    end

    r141(0)
    r41("Performance", "All render tweaks reverted.", "rotate-ccw", 4)
  end,
})

local r156 = nil

task.spawn((function()
  local num = 0

  r156 = r6.RenderStepped:Connect(function()
    num += 1
  end)

  while not r109.Closed do
    local value = os.clock()
    num = 0
    task.wait(1)
    local num1 = math.max(os.clock() - value, 0.001)
    local num2 = math.floor(num / num1 + 0.5)
    local tbl = {}

    if r109.NoTextures then
      table.insert(tbl, "textures")
    end

    if r109.NoFx then
      table.insert(tbl, "fx")
    end

    if r109.NoLights then
      table.insert(tbl, "lights")
    end

    if r109.HidePets then
      table.insert(tbl, "pets")
    end

    if r109.HideMapDetail then
      table.insert(tbl, "map")
    end

    if r109.HidePlayers then
      table.insert(tbl, "players")
    end

    if r109.NoAccessories then
      table.insert(tbl, "accessories")
    end

    if r109.LowLighting then
      table.insert(tbl, "shadows")
    end

    if r109.LowWater then
      table.insert(tbl, "water")
    end

    if r109.LowQuality then
      table.insert(tbl, "quality")
    end

    if r109.MuteSounds then
      table.insert(tbl, "sounds")
    end

    pcall(function()
      r143:SetDesc(string.format(
        "FPS: %d | Cap: %s\nOptimizations: %s",
        num2,
        r109.FpsCap > 0 and tostring(r109.FpsCap) or "default",
        #tbl > 0 and table.concat(tbl, ", ") or "none"
      ))
    end)
  end

  pcall(function()
    if r156 then
      r156:Disconnect()
    end
  end)
end))

r1.LH_Performance = r109

r1.LH_PerformanceCleanup = function()
  r109.Closed = true

  pcall(function()
    if r156 then
      r156:Disconnect()
    end
  end)

  for _, value in pairs(r119) do
    r117(value)
  end

  if r140 ~= nil and type(setfpscap) == "function" then
    pcall(setfpscap, r140)
  end

  if r1.LH_Performance == r109 then
    r1.LH_Performance = nil
  end
end

task.wait(0.08)

r109 = function(param1)
  if not param1 then
    return false
  end

  local attribute = param1:GetAttribute("PrivateTo")

  if attribute and attribute ~= r15.UserId then
    return false
  end

  if param1:GetAttribute("AdminSpawn") == true then
    local attribute = param1:GetAttribute("AdminEggId")
    local attribute1 = r15:GetAttribute("CollectedAdminEggs")

    if type(attribute) == "string" and type(attribute1) == "string" then
      if string.find(attribute1, "," .. attribute .. ",", 1, true) ~= nil then
        return false
      end
    end

    return true
  end

  local attribute1 = param1:GetAttribute("Egg")
  local num = tonumber(param1:GetAttribute("Cycle"))

  if attribute1 and num then
    local attribute = r15:GetAttribute("CollectedEggCycles")

    if type(attribute) == "string" and #attribute > 0 then
      local value, value1 = pcall(r8.JSONDecode, r8, attribute)

      if value and type(value1) == "table" then
        local num1 = tonumber(value1[attribute1])

        if num1 and num <= num1 then
          return false
        end
      end
    end
  end

  local attribute2 = r15:GetAttribute("CollectedEggs")

  if type(attribute2) == "string" and #attribute2 > 0 and attribute1 then
    for value in string.gmatch(attribute2, "([^,]+)") do
      if value == attribute1 then
        return false
      end
    end
  end

  return true
end

r111 = {}
r112 = false
r111.Enabled = r112
r111.Busy = r112
r111.Closed = r112
r111.CycleDelay = 0.5
r113 = {}
r114 = true
r113["All Rarities"] = r114
r112 = r113
r111.TargetEggRarities = r113
r113 = {}
r113["All Eggs"] = r114
r112 = r113
r111.TargetEggTypes = r113
r111.MovementMode = "Instant Teleport"
r111.TweenSpeed = 240
r112 = r114
r111.AutoMountPet = r114
r111.ActiveTween = nil
r111.SingleCycleRunning = false
r111.Status = "Idle"
r111.StatusLabel = nil
r111.EggsPickedUp = 0
r111.SortOrder = "Rarest First"
r111.WeightCondition = "Any Weight"
r111.TargetWeight = 1
r111.ReturningToRanch = false
r110 = r111
r111 = nil
r112 = nil
r113 = nil
r114 = {}
r116 = {}
r117 = 20
r116.Common = r117
r116.Rare = r117
r116.Epic = r117
r116.Legendary = r117
r116.Mythic = r117
r116.Mythical = r117
r116.Divine = r117
r116.Ethereal = 38
r117 = 20
r116.Secret = r117
r116.Robux = r117
r116["Volcanic Egg"] = r117
r115 = r116
r116 = pcall

rv1 = function(...)
  local s2
  local s1 = r5:FindFirstChild("GameServices")

  if s1 and s1:FindFirstChild("PetAging") then
    s2 = require(s1.PetAging)
  end
end

r117 = rv1
r116(rv1)

rv1 = function(...)
  local s2, s7, s8, s6
  local s1 = r5:FindFirstChild("GameData")

  if s1 and s1:FindFirstChild("Mutations") then
    s2 = require(s1.Mutations)
  end

  s2 = s1 and s1:FindFirstChild("General") and require(s1.General)

  if type(s2) == "table" and type(s2.EggBreakTimer) == "table" then
    for s6, s7 in pairs(s2.EggBreakTimer) do
      if type(s7) == "number" then
        s8 = r115
        s8[s6] = s7
      end
    end
  end
end

r117 = rv1
r116(rv1)
r116 = false

r117 = function(...)
  if r116 then
    return
  end

  local s1 = pcall

  s1(function(...)
    local t3
    local t1 = r5:FindFirstChild("GameServices")
    local t2 = t1

    if t1 then
      t3 = t1
      t2 = t1:FindFirstChild("RideCollisionGuard")
    end

    t3 = t2 and require(t2)

    if type(t3) == "table" then
      if type(isreadonly) == "function" and type(setreadonly) == "function" and isreadonly(t3) then
        pcall(setreadonly, t3, false)
      end

      if type(t3.Attach) == "function" then
        if not t3._lhOrigAttach then
          t3._lhOrigAttach = t3.Attach
        end

        t3.Attach = function(...)
          local u1 = r1.LH_AutoPickup

          if u1 and not u1.Closed and (u1.Enabled or u1.Busy or u1.SingleCycleRunning) then
            return { Disconnect = function() end }
          end

          return t3._lhOrigAttach(...)
        end
      end

      if type(t3.RemoveIntoSurface) == "function" then
        if not t3._lhOrigRemoveIntoSurface then
          t3._lhOrigRemoveIntoSurface = t3.RemoveIntoSurface
        end

        t3.RemoveIntoSurface = function(...)
          local u1 = r1.LH_AutoPickup

          if u1 and not u1.Closed and (u1.Enabled or u1.Busy or u1.SingleCycleRunning) then
            return
          end

          return t3._lhOrigRemoveIntoSurface(...)
        end
      end
    end
  end)

  s1(function(...)
    local t3
    local t1 = r5:FindFirstChild("GameServices")
    local t2 = t1

    if t1 then
      t3 = t1
      t2 = t1:FindFirstChild("EggDeliveryRules")
    end

    t3 = t2 and require(t2)

    if type(t3) == "table" and type(t3.Contains) == "function" then
      if type(isreadonly) == "function" and type(setreadonly) == "function" and isreadonly(t3) then
        pcall(setreadonly, t3, false)
      end

      if not t3._lhOrigContains then
        t3._lhOrigContains = t3.Contains
      end

      t3.Contains = function(u1, u2, ...)
        local u3 = r1.LH_AutoPickup

        if u3 and not u3.Closed and u3.ReturningToRanch then
          return false
        end

        return t3._lhOrigContains(u1, u2)
      end
    end
  end)
end

r117()

r118 = function(param1)
  if type(param1) == "string" and type(r112) == "table" then
    local value = r112[param1]

    if type(value) == "table" then
      return tonumber(value.SpeedMultiplier or value.Multiplier) or 1
    end
  end

  return 1
end

r119 = function(param1)
  if not param1 or not param1:IsA("Tool") then
    return 0
  end

  local flag = false

  pcall(function()
    flag = param1:HasTag("Pet")
  end)

  if not flag and not param1:GetAttribute("PetKey") then
    return 0
  end

  local value = tonumber(r105[param1:GetAttribute("PetName")
    or param1.Name:match("^(.-)%s*%[")
    or param1.Name]) or 0

  local value1 = tonumber(param1:GetAttribute("Weight")) or 10
  local value2 = r118(param1:GetAttribute("Mutation"))

  if r111 and type(r111.RealSpeedFor) == "function" then
    local value3, value4 = pcall(r111.RealSpeedFor, value, value1, value2)

    if value3 and type(value4) == "number" and value4 > 0 then
      return value4
    end
  end

  return value
end

r120 = function()
  local value
  local num = 0
  local value1

  local function fn(param1)
    if not param1 then
      return
    end

    for _, item in ipairs(param1:GetChildren()) do
      if item:IsA("Tool") then
        local value2 = r119(item)

        if value2 > num then
          num = value2
          value = item
          value1 = item:GetAttribute("PetKey")
        end
      end
    end
  end

  fn(r15.Character)
  fn(r15:FindFirstChild("Backpack"))
  return value, num, value1
end

r121 = false

r122 = function()
  if not r110.AutoMountPet then
    return
  end

  r117()
  local value, value1, value2 = r89()

  if not value or not value1 or not value2 then
    return
  end

  local value3, value4, value5 = r120()

  if not value3 or value4 <= 20 then
    return
  end

  local value6 = r5:FindFirstChild("Remotes") and r5.Remotes:FindFirstChild("Game")
  local value7 = value6 and value6:FindFirstChild("Mounting")
  local value8 = value6 and value6:FindFirstChild("PetDismount")

  if not value7 then
    return
  end

  local flag = r15:GetAttribute("IsRiding") == true
  local petMountJoint = value1:FindFirstChild("PetMountJoint")
  local value9 = petMountJoint and petMountJoint.Part1 and petMountJoint.Part1.Parent
  local value10 = value9 and value9:GetAttribute("PetKey")

  if flag and not r121 and value8 then
    r121 = true

    pcall(function()
      value8:FireServer()
    end)

    local value = os.clock()

    while r15:GetAttribute("IsRiding") == true and os.clock() - value < 1 do
      task.wait(0.05)
    end

    flag = r15:GetAttribute("IsRiding") == true
  elseif flag
    and value5
    and value10
    and value10 ~= value5
    and value2.WalkSpeed + 10 < value4
    and value8 then
    pcall(function()
      value8:FireServer()
    end)

    local value = os.clock()

    while r15:GetAttribute("IsRiding") == true and os.clock() - value < 1 do
      task.wait(0.05)
    end

    flag = r15:GetAttribute("IsRiding") == true
  end

  if not flag or value2.WalkSpeed <= 25 then
    for _ = 1, 4 do
      if r110.Closed or not r110.Enabled and not r110.SingleCycleRunning then
        break
      end

      value, value1, value2 = r89()

      if not value or not value2 then
        break
      end

      if value3.Parent ~= value then
        pcall(function()
          value2:EquipTool(value3)
        end)

        task.wait(0.1)
      end

      r121 = true

      pcall(function()
        value7:FireServer()
      end)

      local value4 = os.clock()

      while (r15:GetAttribute("IsRiding") ~= true or value2.WalkSpeed <= 25) and os.clock() - value4 < 0.65 do
        task.wait(0.05)
      end

      if r15:GetAttribute("IsRiding") == true and value2.WalkSpeed > 25 then
        break
      end
    end
  end
end

r123 = function()
  return r15:FindFirstChild("Basket")
end

r124 = function()
  local value = r123()
  return value and #value:GetChildren() or 0
end

r125 = function(param1, param2)
  r122()
  local value, value1, value2 = r89()

  if not value1 or not value2 then
    return false
  end

  local value3 = tonumber(param2) or 6.5
  local value4

  function value4:Cancel()
    self.Cancelled = true
  end

  r110.ActiveTween = value4
  local magnitude = ((param1 - value1.Position) * Vector3.new(1, 0, 1)).Magnitude
  local num = math.max(value2.WalkSpeed or 20, 20)
  local num1 = math.clamp(magnitude / math.max(num * 0.5, 18) + 5, 6, 35)
  local value5 = os.clock()
  local value6 = value5
  local position = value1.Position
  local value7 = magnitude
  local value8 = value5
  local flag = false

  while not value4.Cancelled and not r110.Closed and (r110.Enabled or r110.SingleCycleRunning) do
    value, value1, value2 = r89()

    if not value1 or not value2 or value2.Health <= 0 then
      break
    end

    local value4 = os.clock()

    if value4 - value5 > num1 then
      break
    end

    local position1 = value1.Position
    local magnitude = Vector3.new(param1.X - position1.X, 0, param1.Z - position1.Z).Magnitude
    local num = math.abs(param1.Y - position1.Y)

    if magnitude <= value3 and num <= 18 then
      flag = true
      break
    end

    if magnitude < value7 - 1.5 then
      value7 = magnitude
      value8 = value4
    elseif value4 - value8 > 2.4 then
      break
    end

    if value4 - value6 >= 0.35 then
      if ((position1 - position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 and magnitude > value3 then
        value2.Jump = true
      end

      position = position1
      value6 = value4
    end

    value2:MoveTo(param1)
    task.wait(0.05)
  end

  if value2 and value2.Parent then
    pcall(function()
      value2:Move(Vector3.zero, false)
    end)
  end

  if r110.ActiveTween == value4 then
    r110.ActiveTween = nil
  end

  return flag
end

r126 = function(param1, param2, param3)
  r122()
  local value, value1, value2 = r89()

  if not value1 or not value2 or value2.Health <= 0 then
    return false
  end

  local value3 = tonumber(param3) or 6.5
  local num = param1 + Vector3.new(0, 3, 0)
  local position = value1.Position
  local magnitude = (num - position).Magnitude

  if magnitude <= value3 then
    return true
  end

  local num1 = math.max(
    magnitude / math.clamp(tonumber(param2) or tonumber(r110.TweenSpeed) or 240, 40, 500),
    0.1
  )

  local value4

  function value4:Cancel()
    self.Cancelled = true
  end

  r110.ActiveTween = value4

  local connection = r6.Stepped:Connect(function()
    local character = r15.Character

    if character then
      for _, item in ipairs(character:GetDescendants()) do
        if item:IsA("BasePart") and item.CanCollide then
          item.CanCollide = false
        end
      end
    end
  end)

  local value5 = os.clock()
  local flag = false

  while not value4.Cancelled and not r110.Closed and (r110.Enabled or r110.SingleCycleRunning) do
    value, value1, value2 = r89()

    if not value1 or not value2 or value2.Health <= 0 then
      break
    end

    local num2 = math.clamp((os.clock() - value5) / num1, 0, 1)
    local value4 = position:Lerp(num, num2)
    local petMountJoint = value1:FindFirstChild("PetMountJoint")
    local value6 = petMountJoint and petMountJoint.Part1
    local value7 = value6 and value6.Parent
    local value8 = value7 and value7:FindFirstChild("RootPart")

    if value8 then
      value8.CFrame = value8.CFrame + (value4 - value1.Position)

      pcall(function()
        value8.AssemblyLinearVelocity = Vector3.zero
        value8.AssemblyAngularVelocity = Vector3.zero
      end)
    else
      value1.CFrame = CFrame.new(value4)

      pcall(function()
        value1.AssemblyLinearVelocity = Vector3.zero
        value1.AssemblyAngularVelocity = Vector3.zero
      end)
    end

    if (value1.Position - num).Magnitude <= value3 or num2 >= 1 then
      flag = true
      break
    end

    r6.Heartbeat:Wait()
  end

  if connection then
    connection:Disconnect()
  end

  if value1 then
    pcall(function()
      value1.AssemblyLinearVelocity = Vector3.zero
      value1.AssemblyAngularVelocity = Vector3.zero
    end)
  end

  if r110.ActiveTween == value4 then
    r110.ActiveTween = nil
  end

  return flag
end

r127 = function(param1, param2)
  r122()
  local value, value1, value2 = r89()

  if not value1 or not value2 or value2.Health <= 0 then
    return false
  end

  local value3 = tonumber(param2) or 6.5
  local num = param1 + Vector3.new(0, 3, 0)
  local petMountJoint = value1:FindFirstChild("PetMountJoint")
  local value4 = petMountJoint and petMountJoint.Part1
  local value5 = value4 and value4.Parent
  local value6 = value5 and value5:FindFirstChild("RootPart")

  if value6 then
    value6.CFrame = value6.CFrame + (num - value1.Position)

    pcall(function()
      value6.AssemblyLinearVelocity = Vector3.zero
      value6.AssemblyAngularVelocity = Vector3.zero
    end)
  else
    value1.CFrame = CFrame.new(num)

    pcall(function()
      value1.AssemblyLinearVelocity = Vector3.zero
      value1.AssemblyAngularVelocity = Vector3.zero
    end)
  end

  task.wait(0.4)
  value, value1, value2 = r89()

  if value1 then
    pcall(function()
      value1.AssemblyLinearVelocity = Vector3.zero
      value1.AssemblyAngularVelocity = Vector3.zero
    end)

    return (value1.Position - num).Magnitude <= math.max(value3, 14)
  end

  return false
end

r128 = function(param1, param2)
  local value = r110.MovementMode or "Tween"

  if value == "Instant Teleport" then
    return r127(param1, param2)
  elseif value == "Tween" then
    return r126(param1, r110.TweenSpeed, param2)
  else
    return r125(param1, param2)
  end
end

r129 = function(param)
  if not param then
    return false
  end

  local str = string.lower(tostring(param))
  return str:find("volcan", 1, true) ~= nil or str:find("volkaris", 1, true) ~= nil
end

r130 = function()
  local volcano = r4:FindFirstChild("Volcano")
  local value = volcano and volcano:FindFirstChild("VolcanoEntrance")
  local value1 = volcano and volcano:FindFirstChild("VolcanoValidate")
  return value, value1
end

r131 = function()
  local value, value1 = r130()
  local value2 = value and value.CFrame or CFrame.new(-4939.836, 41284.703, -3679.983)
  local value3 = value1 and value1.CFrame or CFrame.new(-4966.714, 41282.77, -3656.444)

  return {
    value2 * CFrame.new(0, 0, -20),
    value2 * CFrame.new(0, 0, -5),
    value2 * CFrame.new(0, 0, 5),
    value2 * CFrame.new(0, 0, 15),
    value3 * CFrame.new(0, 0, -5),
    value3 * CFrame.new(0, 0, 5),
    value3 * CFrame.new(0, 0, 20),
  }
end

r132 = function()
  local value, value1 = r130()
  local value2 = value and value.CFrame or CFrame.new(-4939.836, 41284.703, -3679.983)
  local value3 = value1 and value1.CFrame or CFrame.new(-4966.714, 41282.77, -3656.444)

  return {
    value3 * CFrame.new(0, 0, 20),
    value3 * CFrame.new(0, 0, 5),
    value3 * CFrame.new(0, 0, -5),
    value2 * CFrame.new(0, 0, 15),
    value2 * CFrame.new(0, 0, 5),
    value2 * CFrame.new(0, 0, -5),
    value2 * CFrame.new(0, 0, -20),
  }
end

r133 = function(param1, param2)
  local value, value1 = r89()

  if not value1 then
    return false
  end

  r122()
  value, value1 = r89()

  for _, item in ipairs(param1) do
    if r110.Closed or not r110.Enabled and not r110.SingleCycleRunning then
      return false
    end

    local petMountJoint = value1:FindFirstChild("PetMountJoint")
    local value = petMountJoint and petMountJoint.Part1
    local value2 = value and value.Parent
    local value3 = value2 and value2:FindFirstChild("RootPart")

    if value3 then
      value3.CFrame = value3.CFrame + (item.Position - value1.Position)

      pcall(function()
        value3.AssemblyLinearVelocity = item.LookVector * (param2 and -18 or 18)
        value3.AssemblyAngularVelocity = Vector3.zero
      end)
    else
      value1.CFrame = item

      pcall(function()
        value1.AssemblyLinearVelocity = item.LookVector * (param2 and -18 or 18)
        value1.AssemblyAngularVelocity = Vector3.zero
      end)
    end

    task.wait(0.25)
  end

  if value1 then
    pcall(function()
      value1.AssemblyLinearVelocity = Vector3.zero
      value1.AssemblyAngularVelocity = Vector3.zero
    end)
  end

  if param2 then
    local num = os.clock() + 3

    while os.clock() < num and not r110.Closed and (r110.Enabled or r110.SingleCycleRunning) do
      if r15:GetAttribute("InVolcano") == true or r15:GetAttribute("VolcanoValidated") == true then
        return true
      end

      task.wait(0.1)
    end

    return r15:GetAttribute("InVolcano") == true or r15:GetAttribute("VolcanoValidated") == true
  end

  return true
end

r134 = function()
  local num = 0.1

  pcall(function()
    local Stats = game:GetService("Stats")

    local value = Stats
      and Stats.Network
      and Stats.Network.ServerStatsItem
      and Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")

    if value then
      num = value:GetValue() / 1000
    end
  end)

  return math.clamp(num + 0.2, 0.35, 1.2)
end

r135 = function(param)
  if typeof(param) == "Vector3" then
    return param
  end

  if type(param) ~= "string" then
    return nil
  end

  local str = string.split(param, ",")

  if #str == 3 then
    local num = tonumber(str[1])
    local num1 = tonumber(str[2])
    local num2 = tonumber(str[3])

    if num and num1 and num2 then
      return Vector3.new(num, num1, num2)
    end
  end

  local value, value1, value2 = param:match("([^,]+),%s*([^,]+),%s*([^,]+)")

  if value and value1 and value2 then
    return Vector3.new(tonumber(value), tonumber(value1), tonumber(value2))
  end

  return nil
end

rv1 = function(param1, param2)
  local value = r5:FindFirstChild("ServerData") and r5.ServerData:FindFirstChild("ActiveEggs")

  if not value or not param2 then
    return nil, 1
  end

  local huge = math.huge
  local value1
  local num = 1
  local value2 = os.clock()
  local position = param2.Position

  for _, item in ipairs(value:GetChildren()) do
    local value = r114[item.Name]

    if not value or value2 >= value then
      if item:GetAttribute("Egg") == param1.Name and r109(item) then
        local value = r135(item:GetAttribute("Position"))

        if value then
          local magnitude = (position - value).Magnitude

          if magnitude < huge then
            huge = magnitude
            value1 = item
            num = tonumber(item:GetAttribute("Weight")) or 1

            if magnitude <= 2 then
              break
            end
          end
        end
      end
    end
  end

  if huge <= 25 then
    return value1, num
  end

  return nil, 1
end

r137 = function(param1, param2, param3, param4, param5)
  if r110.TargetEggRarities
    and next(r110.TargetEggRarities) ~= nil
    and not r110.TargetEggRarities["All Rarities"] then
    local value = r99[param1]

    if not value or not r110.TargetEggRarities[value] then
      return false
    end
  end

  if r110.TargetEggTypes
    and next(r110.TargetEggTypes) ~= nil
    and not r110.TargetEggTypes["All Eggs"] then
    if not r110.TargetEggTypes[param1] then
      return false
    end
  end

  if r110.WeightCondition and r110.WeightCondition ~= "Any Weight" and param2 and param3 then
    local value = param5 or 1
    local value1 = tonumber(r110.TargetWeight) or 1

    if r110.WeightCondition == "At least (>=)" then
      if value < value1 - 0.01 then
        return false
      end
    elseif r110.WeightCondition == "At most (<=)" then
      if value > value1 + 0.01 then
        return false
      end
    end
  end

  return true
end

r138 = function(param, param1)
  if not param then
    return Vector3.zero
  end

  local value = param.CFrame:PointToObjectSpace(param1)
  local num = math.max(param.Size.X / 2 - 4, 2)
  local num1 = math.max(param.Size.Z / 2 - 4, 2)
  local num2 = math.clamp(value.X, -num, num)
  local num3 = math.clamp(value.Z, -num1, num1)
  local value1 = param.CFrame:PointToWorldSpace(Vector3.new(num2, 0, num3))
  return Vector3.new(value1.X, param.Position.Y + 3, value1.Z)
end

r139 = function(param1, param2, param3, param4)
  if not param3 or not param2 then
    return true
  end

  local value = r129(param1)
  local num = param2.Y - param3.Position.Y

  if value then
    if num > 1500 or num < -200 then
      return false
    end
  else
    if num > 250 or num < -100 then
      return false
    end
  end

  local value1 = r99[param1] or "Common"
  local value2 = r115[param1] or value and 20 or r115[value1] or 20
  local magnitude = ((param2 - r138(param3, param2)) * Vector3.new(1, 0, 1)).Magnitude
  local value3

  if param4 then
    value3 = param4
  else
    local value, value1, value2 = r89()
    local value4 = value2 and value2.WalkSpeed or 20
    local value5, value6 = r120()
    value3 = math.max(value4, r110.AutoMountPet and value6 or 20, 20)
  end

  local value4 = r110.MovementMode or "Tween"
  local value5

  if value4 == "Instant Teleport" then
    value5 = 500
  elseif value4 == "Tween" then
    local num = math.max(r110.TweenSpeed or 240, value3)
    value5 = value and math.max(num, 450) or num
  else
    value5 = value3 * 0.88
  end

  return magnitude / math.max(value5, 18) <= value2 - 1.5
end

r140 = function(param1)
  local renderedEggs = r4:FindFirstChild("RenderedEggs")

  if not renderedEggs then
    return nil, nil, nil
  end

  local children = renderedEggs:GetChildren()

  if #children == 0 then
    return nil, nil, nil
  end

  local value, value1, value2 = r89()
  local tbl = {}
  local value3 = r5:FindFirstChild("ServerData") and r5.ServerData:FindFirstChild("ActiveEggs")
  local value4 = os.clock()
  local value5, value6 = r120()
  local num = math.max(value2 and value2.WalkSpeed or 20, r110.AutoMountPet and value6 or 20, 20)
  local value7

  if value3 then
    value7 = {}

    for _, item in ipairs(value3:GetChildren()) do
      local value = r114[item.Name]

      if not value or value4 >= value then
        if r109(item) then
          local attribute = item:GetAttribute("Egg")

          if attribute then
            local value = r135(item:GetAttribute("Position"))

            if value then
              local value1 = value7[attribute]

              if not value1 then
                value1 = {}
                value7[attribute] = value1
              end

              table.insert(value1, {
                active = item,
                pos = value,
                weight = tonumber(item:GetAttribute("Weight")) or 1,
              })
            end
          end
        end
      end
    end
  end

  for _, item in ipairs(children) do
    local value = r114[item]

    if not value or value4 >= value then
      local value = item:FindFirstChild("Handle")
        or item:FindFirstChild("Sphere.002")
        or item:FindFirstChild("EggBase")
        or item:FindFirstChildWhichIsA("BasePart")

      if value then
        local name = item.Name
        local value1
        local num1 = 1
        local position = value.Position

        if value7 then
          local value2 = value7[name]

          if value2 then
            local huge = math.huge
            local position1 = value.Position

            for _, item in ipairs(value2) do
              local magnitude = (position1 - item.pos).Magnitude

              if magnitude < huge then
                huge = magnitude
                value1 = item.active
                num1 = item.weight
                position = item.pos

                if magnitude <= 2 then
                  break
                end
              end
            end

            if huge > 25 then
              value1 = nil
              position = value.Position
            end
          end
        end

        if (not value3 or value1 ~= nil) and r137(name, value, item, value1, num1) then
          if r139(name, position, param1, num) then
            table.insert(tbl, {
              egg = item,
              part = value,
              active = value1,
              pos = position,
              rank = r108(item),
            })
          end
        end
      end
    end
  end

  if #tbl > 0 then
    table.sort(tbl, function(param1, param2)
      if r110.SortOrder == "Closest Distance" then
        if value1 then
          return (param1.pos - value1.Position).Magnitude < (param2.pos - value1.Position).Magnitude
        end

        return false
      end

      if param1.rank ~= param2.rank then
        return param1.rank > param2.rank
      end

      if value1 then
        return (param1.pos - value1.Position).Magnitude < (param2.pos - value1.Position).Magnitude
      end

      return false
    end)

    return tbl[1].egg, tbl[1].part, tbl[1].active
  end

  return nil, nil, nil
end

r141 = function()
  local tbl = {}

  local function fn(param)
    if not param then
      return
    end

    for _, item in ipairs(param:GetChildren()) do
      if item:IsA("Tool") then
        local attribute = item:GetAttribute("EggInventoryId")

        if attribute then
          tbl[attribute] = item
        end
      end
    end
  end

  fn(r15:FindFirstChild("Backpack"))
  fn(r15.Character)
  return tbl
end

r142 = function(param1, param2)
  local function fn(param)
    if not param then
      return nil
    end

    for _, item in ipairs(param:GetChildren()) do
      if item:IsA("Tool") then
        local attribute = item:GetAttribute("EggInventoryId")

        if attribute and not param1[attribute] then
          return item
        end
      end
    end

    return nil
  end

  return fn(r15:FindFirstChild("Backpack")) or fn(r15.Character)
end

r143 = function(param1)
  if r110.Busy or r110.Closed then
    return
  end

  if not r110.Enabled and not param1 then
    return
  end

  r110.Busy = true

  if param1 then
    r110.SingleCycleRunning = true
  end

  local value = r92()

  if not value then
    r110.Status = "Error: Own plot not found"

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
    end

    r110.Busy = false
    r110.SingleCycleRunning = false
    return
  end

  local baseplate = value:FindFirstChild("Baseplate")

  if not baseplate then
    r110.Status = "Error: Own plot baseplate not found"

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
    end

    r110.Busy = false
    r110.SingleCycleRunning = false
    return
  end

  if r15:GetAttribute("BACInvalidated") == true then
    r110.Status = "Session flagged by server anti-cheat (rejoin server)"

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
    end

    task.wait(1.5)
    r110.Busy = false
    r110.SingleCycleRunning = false
    return
  end

  r122()
  local value1 = r5:FindFirstChild("Remotes") and r5.Remotes:FindFirstChild("Game")
  local value2 = value1 and value1:FindFirstChild("EggArrivalClaim")
  local value3 = value1 and value1:FindFirstChild("EggPickup")
  local value4 = r5:FindFirstChild("Remotes") and r5.Remotes:FindFirstChild("Reusable")
  local value5 = value4 and value4:FindFirstChild("GameMessage")
  local value6

  if r124() == 0 then
    r110.Status = "Searching for world eggs..."

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
    end

    local value, value1, value2 = r140(baseplate)

    if not value or not value1 then
      r110.Status = "No matching eggs found"

      if r110.StatusLabel then
        r110.StatusLabel:SetTitle("Status: " .. r110.Status)
      end

      task.wait(1)
      r110.Busy = false
      r110.SingleCycleRunning = false
      return
    end

    local name = value.Name
    value6 = name
    local value4 = r129(name)
    local value5 = value2 and r135(value2:GetAttribute("Position")) or value1.Position
    local value7

    if value4 then
      r110.Status = "Mimicking volcanic entrance..."

      if r110.StatusLabel then
        r110.StatusLabel:SetTitle("Status: " .. r110.Status)
      end

      local value = r133(r131(), true) or r133(r131(), true)
      r110.Status = "Moving to egg: " .. name

      if r110.StatusLabel then
        r110.StatusLabel:SetTitle("Status: " .. r110.Status)
      end

      value7 = r128(value5, 6.5)
      task.wait(r134())
    else
      r110.Status = "Moving to egg: " .. name

      if r110.StatusLabel then
        r110.StatusLabel:SetTitle("Status: " .. r110.Status)
      end

      value7 = r128(value5, 6.5)
    end

    if not value7 then
      if value2 then
        r114[value2.Name] = os.clock() + 45
      end

      r114[value] = os.clock() + 45
      r110.Status = "Egg unreachable, skipping..."

      if r110.StatusLabel then
        r110.StatusLabel:SetTitle("Status: " .. r110.Status)
      end

      r110.Busy = false
      r110.SingleCycleRunning = false
      return
    end

    if r110.Closed or not r110.Enabled and not param1 then
      r110.Busy = false
      r110.SingleCycleRunning = false
      return
    end

    if value2 then
      local value = tonumber(value2:GetAttribute("DropEndsAt")) or 0
      local value1 = os.clock()

      while value > r4:GetServerTimeNow() and os.clock() - value1 < 2.5 and not r110.Closed do
        task.wait(0.05)
      end
    end

    task.wait(0.35)
    r110.Status = "Picking up: " .. name

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
    end

    local flag = false
    local value8
    local num = 0
    local value9

    if value3 then
      value9 = value3.OnClientEvent:Connect(function(param, param1)
        if param == "PickedUp" or param == "BasketFull" then
          flag = true
        elseif param == "Refused" then
          local value = tostring(param1 or ""):lower()

          if value:find("hold", 1, true) or value:find("wait", 1, true) then
            num = os.clock() + 1.1
          elseif value:find("gone", 1, true)
            or value:find("claimed", 1, true)
            or value:find("far", 1, true) then
            value8 = tostring(param1)
          end
        end
      end)
    end

    local num1 = os.clock() + 4

    while os.clock() < num1 and not r110.Closed and (r110.Enabled or param1) do
      if flag or r124() > 0 then
        flag = true
        break
      end

      if value8 or value2 and value2.Parent == nil or value.Parent == nil then
        if r124() > 0 then
          flag = true
        end

        break
      end

      if os.clock() >= num then
        if value3 and value2 and value2.Parent then
          local value1, value4 = r89()
          local value6 = value4 and ((value5 - value4.Position) * Vector3.new(1, 0, 1)).Magnitude or 999

          if value6 > 14 then
            r128(value5, 6)
            value1, value4 = r89()
            value6 = value4 and ((value5 - value4.Position) * Vector3.new(1, 0, 1)).Magnitude or 999
          end

          local value7 = tonumber(value2:GetAttribute("DropEndsAt")) or 0

          if value6 <= 14 and r4:GetServerTimeNow() >= value7 then
            local value1 = value and value:FindFirstChildOfClass("ProximityPrompt", true)

            if value1 and type(r21) == "function" then
              pcall(r21, value1)
            end

            pcall(function()
              value3:FireServer(value2.Name)
            end)
          end
        end

        num = os.clock() + 0.5
      end

      task.wait(0.08)
    end

    if value9 then
      value9:Disconnect()
    end

    if not flag and r124() > 0 then
      flag = true
    end

    if not flag then
      if value2 then
        r114[value2.Name] = os.clock() + 30
      end

      r114[value] = os.clock() + 30
      r110.Status = "Failed to take " .. name

      if r110.StatusLabel then
        r110.StatusLabel:SetTitle("Status: " .. r110.Status)
      end

      task.wait(0.3)
      r110.Busy = false
      r110.SingleCycleRunning = false
      return
    end
  end

  if r110.Closed or not r110.Enabled and not param1 then
    r110.Busy = false
    r110.SingleCycleRunning = false
    return
  end

  local value7 = r123()
  local value8 = value7 and value7:GetChildren()[1]
  local value9 = value8 and value8:GetAttribute("Egg") or "Egg"
  local value10 = r141()
  local flag = false
  local flag1 = false
  local value11

  if value3 then
    value11 = value3.OnClientEvent:Connect(function(param)
      if param == "Deposited" then
        flag = true
      end
    end)
  end

  local value12

  if value5 then
    value12 = value5.OnClientEvent:Connect(function(param)
      if tostring(param or ""):lower():find("returned", 1, true) then
        flag1 = true
      end
    end)
  end

  local value13 = r129(value9) or r129(value6)

  if value13 then
    r110.Status = "Mimicking volcanic exit door..."

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
    end

    r133(r132(), false)
  end

  r110.Status = "Returning to ranch..."

  if r110.StatusLabel then
    r110.StatusLabel:SetTitle("Status: " .. r110.Status)
  end

  local value14 = baseplate.CFrame:PointToWorldSpace(Vector3.new(0, 0, 0))
  local vector3 = Vector3.new(value14.X, baseplate.Position.Y + 3, value14.Z)
  r110.ReturningToRanch = true
  local value15 = value13 and math.max(r110.TweenSpeed or 240, 450) or r110.TweenSpeed

  if not (r110.MovementMode == "Tween" and r126(vector3, value15, 3.5) or r128(vector3, 3.5))
    or r110.Closed
    or not r110.Enabled and not param1 then
    r110.ReturningToRanch = false

    if value11 then
      value11:Disconnect()
    end

    if value12 then
      value12:Disconnect()
    end

    r110.Busy = false
    r110.SingleCycleRunning = false
    return
  end

  task.wait(0.35)
  r110.ReturningToRanch = false
  r110.Status = "Claiming egg from basket..."

  if r110.StatusLabel then
    r110.StatusLabel:SetTitle("Status: " .. r110.Status)
  end

  local value16
  local num = os.clock() + 6
  local num1 = os.clock() - 0.4
  local num2 = 0

  while os.clock() < num and not r110.Closed and (r110.Enabled or param1) do
    value16 = r142(value10, value9)

    if value16 or flag then
      break
    end

    if flag1 then
      break
    end

    local value = r123()
    local value1 = value and value:GetChildren() or {}

    if #value1 == 0 then
      task.wait(0.2)
      value16 = r142(value10, value9)
      break
    end

    if value2 and os.clock() - num1 >= 1 then
      local value, value3 = r89()

      if value3 then
        if (Vector3.new(value3.Position.X, vector3.Y, value3.Position.Z) - vector3).Magnitude > 4.5 and os.clock() - num2 > 1 then
          num2 = os.clock()
          r128(vector3, 3.5)
          task.wait(0.2)
          value, value3 = r89()
        end

        if value3 and (not r113 or r113(baseplate, value3.Position)) then
          local tbl = {}

          for _, item in ipairs(value1) do
            if not item:GetAttribute("Delivering") then
              table.insert(tbl, item.Name)
            end
          end

          if #tbl > 0 then
            num1 = os.clock()

            pcall(function()
              value2:FireServer(r4:GetServerTimeNow(), value3.Position, tbl)
            end)
          end
        end
      end
    end

    task.wait(0.1)
  end

  if value11 then
    value11:Disconnect()
  end

  if value12 then
    value12:Disconnect()
  end

  if (value16 or flag or r124() == 0 and not flag1) and not r110.Closed and (r110.Enabled or param1) then
    r110.EggsPickedUp = r110.EggsPickedUp + 1
    r110.Status = "Delivered " .. value9 .. "!"

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
      r110.StatusLabel:SetDesc("Eggs Picked Up: " .. tostring(r110.EggsPickedUp))
    end
  elseif flag1 then
    r110.Status = "Server returned " .. value9

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
    end
  else
    r110.Status = "Claim failed / egg not found"

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
    end
  end

  task.wait(r110.CycleDelay)
  r110.Busy = false
  r110.SingleCycleRunning = false
end

r144 = task.spawn

rv2 = function()
  while not r110.Closed do
    if r110.Enabled and not r110.Busy then
      pcall(function()
        r143(false)
      end)
    end

    task.wait(0.1)
  end
end

r145 = rv2
r144(rv2)
r146 = { Title = "Auto Pick Up Egg", Icon = "egg" }
r147 = true
r146.Box = r147
r146.BoxBorder = r147
r146.Opened = r147
r145 = r49
r144 = r49:Section(r146)
r146 = r144

r110.StatusLabel = r144:Paragraph({
  Title = "Status: Idle",
  Desc = "Eggs Picked Up: 0",
  Image = "activity",
  ImageSize = 28,
})

r147 = { Title = "Auto Pick Up Eggs", Flag = "Pickup_AutoPickup", Value = false }

rv1 = function(param1)
  r110.Enabled = param1

  if not param1 then
    r110.Status = "Stopped"

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: Stopped")
    end

    if r110.ActiveTween then
      pcall(function()
        r110.ActiveTween:Cancel()
      end)

      r110.ActiveTween = nil
    end
  end
end

r148 = rv1
r147.Callback = rv1
r146 = r144
r144:Toggle(r147)

r147 = {
  Title = "Auto Mount Best Pet",
  Desc = "Mounts your fastest pet automatically for safe anti-teleport speed",
  Flag = "Pickup_AutoMountPet",
  Value = true,
}

rv1 = function(param1)
  r110.AutoMountPet = param1
end

r148 = rv1
r147.Callback = rv1
r146 = r144
r144:Toggle(r147)
r147 = { Title = "Target Egg Rarity", Flag = "Pickup_TargetEggRarity", Values = r96 }
r149 = { "All Rarities" }
r148 = r149
r147.Value = r149
r148 = true
r147.Multi = r148
r147.AllowNone = r148

rv1 = function(param1)
  local tbl = {}

  if type(param1) == "table" then
    for _, item in ipairs(param1) do
      tbl[item] = true
    end
  elseif type(param1) == "string" and param1 ~= "" then
    tbl[param1] = true
  end

  if next(tbl) == nil then
    tbl["All Rarities"] = true
  end

  r110.TargetEggRarities = tbl
end

r148 = rv1
r147.Callback = rv1
r146 = r144
r144:Dropdown(r147)
r147 = { Title = "Target Egg Type", Flag = "Pickup_TargetEggType", Values = r101 }
r149 = { "All Eggs" }
r148 = r149
r147.Value = r149
r148 = true
r147.Multi = r148
r147.AllowNone = r148

rv1 = function(param1)
  local tbl = {}

  if type(param1) == "table" then
    for _, item in ipairs(param1) do
      tbl[item] = true
    end
  elseif type(param1) == "string" and param1 ~= "" then
    tbl[param1] = true
  end

  if next(tbl) == nil then
    tbl["All Eggs"] = true
  end

  r110.TargetEggTypes = tbl
end

r148 = rv1
r147.Callback = rv1
r146 = r144
r144:Dropdown(r147)
r147 = { Title = "Egg Weight Condition", Flag = "Pickup_WeightCondition" }
r149 = {}
r150 = "Any Weight"
r149[1], r149[2], r149[3] = r150, "At least (>=)", "At most (<=)"
r148 = r149
r147.Values = r149
r148 = r150
r147.Value = r150

rv2 = function(param1)
  r110.WeightCondition = param1
end

r148 = rv2
r147.Callback = rv2
r146 = r144
r144:Dropdown(r147)
r147 = { Title = "Target Egg Weight", Flag = "Pickup_TargetWeight", Step = 0.05 }
r149 = { Min = 0.5, Max = 3, Default = 1 }
r148 = r149
r147.Value = r149

rv1 = function(param1)
  r110.TargetWeight = tonumber(param1) or 1
end

r148 = rv1
r147.Callback = rv1
r146 = r144
r144:Slider(r147)
r147 = { Title = "Priority Mode", Flag = "Pickup_PriorityMode" }
r149 = {}
r150 = "Rarest First"
r149[1], r149[2] = r150, "Closest Distance"
r148 = r149
r147.Values = r149
r148 = r150
r147.Value = r150

rv2 = function(param1)
  r110.SortOrder = param1
end

r148 = rv2
r147.Callback = rv2
r146 = r144
r144:Dropdown(r147)
r147 = { Title = "Movement Method", Flag = "Pickup_MovementMethod" }
r149 = {}
r150 = "Instant Teleport"
r149[1], r149[2] = r150, "Tween"
r148 = r149
r147.Values = r149
r148 = r150
r147.Value = r150

rv2 = function(param1)
  r110.MovementMode = param1
end

r148 = rv2
r147.Callback = rv2
r146 = r144
r144:Dropdown(r147)
r147 = { Title = "Tween Speed", Flag = "Pickup_TweenSpeed", Step = 10 }
r149 = { Min = 80, Max = 400, Default = 240 }
r148 = r149
r147.Value = r149

rv1 = function(param1)
  r110.TweenSpeed = param1
end

r148 = rv1
r147.Callback = rv1
r146 = r144
r144:Slider(r147)
r147 = { Title = "Cycle Delay", Flag = "Pickup_CycleDelay" }
r148 = 0.1
r147.Step = r148
r149 = {}
r150 = r148
r149.Min = r148
r149.Max = 3
r149.Default = 0.5
r148 = r149
r147.Value = r149

rv2 = function(param1)
  r110.CycleDelay = param1
end

r148 = rv2
r147.Callback = rv2
r146 = r144
r144:Slider(r147)
r147 = { Title = "Pick Up Once Now", Icon = "crosshair" }

rv2 = function()
  if r110.Busy then
    r41("Auto Pickup", "Pickup cycle already in progress", "triangle-alert", 2)
    return
  end

  task.spawn(function()
    r143(true)
  end)
end

r148 = rv2
r147.Callback = rv2
r146 = r144
r144:Button(r147)
r1.LH_AutoPickup = r110
r1.LH_AutoSteal = r110

rv2 = function()
  r110.Closed = true
  r110.Enabled = false

  if r110.ActiveTween then
    pcall(function()
      r110.ActiveTween:Cancel()
    end)

    r110.ActiveTween = nil
  end

  if r1.LH_AutoPickup == r110 then
    r1.LH_AutoPickup = nil
  end

  if r1.LH_AutoSteal == r110 then
    r1.LH_AutoSteal = nil
  end
end

r145 = rv2
r1.LH_AutoPickupCleanup = rv2
r1.LH_AutoStealCleanup = r1.LH_AutoPickupCleanup
task.wait(0.08)
r111 = {}
r112 = false
r111.Enabled = r112
r111.Closed = r112
r111.Busy = r112
r111.ScanDelay = 6
r111.WaitForPickup = true
r111.Status = "Idle"
r111.StatusLabel = nil
r110 = r111
r111 = r109

r112 = function()
  local tbl = {}
  local tbl1 = {}
  local renderedEggs = r4:FindFirstChild("RenderedEggs")

  if renderedEggs then
    for _, item in ipairs(renderedEggs:GetChildren()) do
      tbl1[item.Name] = (tbl1[item.Name] or 0) + 1
    end
  end

  local serverData = r5:FindFirstChild("ServerData")
  local value = serverData and serverData:FindFirstChild("ActiveEggs")

  if value then
    for _, item in ipairs(value:GetChildren()) do
      if r111(item) then
        local attribute = item:GetAttribute("Egg")
        local value = tonumber(item:GetAttribute("Weight")) or 1

        if attribute and tbl1[attribute] and tbl1[attribute] > 0 then
          tbl1[attribute] = tbl1[attribute] - 1

          table.insert(
            tbl,
            { Name = attribute, Rarity = r99[attribute] or "Common", Weight = value }
          )
        end
      end
    end
  end

  if #tbl == 0 and renderedEggs and not value then
    for _, item in ipairs(renderedEggs:GetChildren()) do
      local name = item.Name
      table.insert(tbl, { Name = name, Rarity = r99[name] or "Common", Weight = 1 })
    end
  end

  return tbl
end

r113 = function()
  local value = r112()
  local tbl = {}
  local lH_AutoPickup = r1.LH_AutoPickup
  local value1 = lH_AutoPickup and lH_AutoPickup.TargetEggRarities or { ["All Rarities"] = true }
  local value2 = lH_AutoPickup and lH_AutoPickup.TargetEggTypes or { ["All Eggs"] = true }
  local value3 = lH_AutoPickup and lH_AutoPickup.WeightCondition or "Any Weight"
  local value4 = lH_AutoPickup and tonumber(lH_AutoPickup.TargetWeight) or 1

  for _, item in ipairs(value) do
    local value = not value1 or value1["All Rarities"] or value1[item.Rarity]
    local value5 = not value2 or value2["All Eggs"] or value2[item.Name]
    local flag = true

    if value3 == "At least (>=)" then
      flag = item.Weight >= value4 - 0.01
    elseif value3 == "At most (<=)" then
      flag = item.Weight <= value4 + 0.01
    end

    if value and value5 and flag then
      table.insert(tbl, item)
    end
  end

  return tbl
end

r114 = function()
  if r110.Busy then
    return
  end

  r110.Busy = true
  r110.Status = "Finding server..."

  if r110.StatusLabel then
    r110.StatusLabel:SetTitle("Status: " .. r110.Status)
  end

  r27()
  local placeId = game.PlaceId
  local jobId = game.JobId

  local str = string.format(
    "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100",
    tostring(placeId)
  )

  local tbl = {}

  pcall(function()
    local value

    if r24 then
      local value1 = r24{ Url = str, Method = "GET" }

      if value1 and value1.Body then
        value = value1.Body
      end
    elseif type(httpget) == "function" then
      value = httpget(game, str)
    elseif game.HttpGet then
      value = game:HttpGet(str)
    end

    if value then
      local value1 = r8:JSONDecode(value)

      if value1 and value1.data then
        for _, item in ipairs(value1.data) do
          if item.id ~= jobId
            and item.playing
            and item.maxPlayers
            and item.playing < item.maxPlayers then
            table.insert(tbl, item.id)
          end
        end
      end
    end
  end)

  if #tbl > 0 then
    local value = tbl[math.random(1, #tbl)]
    r110.Status = "Teleporting to " .. tostring(value):sub(1, 8) .. "..."

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
    end

    r13:TeleportToPlaceInstance(placeId, value, r15)
  else
    r110.Status = "Teleporting (fallback)..."

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
    end

    r13:Teleport(placeId, r15)
  end

  task.delay(10, function()
    r110.Busy = false
  end)
end

r115 = task.spawn

rv1 = function()
  task.wait(r110.ScanDelay)

  while not r110.Closed do
    if r110.Enabled and not r110.Busy then
      local value = r113()

      if #value > 0 then
        local name = value[1].Name
        local rarity = value[1].Rarity
        r110.Status = string.format("Found %d target egg(s)! (%s - %s)", #value, name, rarity)

        if r110.StatusLabel then
          r110.StatusLabel:SetTitle("Status: " .. r110.Status)
          r110.StatusLabel:SetDesc("Target eggs present in server. Staying.")
        end

        if r110.WaitForPickup and r1.LH_AutoPickup and r1.LH_AutoPickup.Enabled then
          local value = os.clock()
          local num = 0

          while r110.Enabled and not r110.Closed do
            task.wait(2)
            local value1 = r113()

            if #value1 == 0 then
              r110.Status = "Target eggs collected! Preparing to hop..."

              if r110.StatusLabel then
                r110.StatusLabel:SetTitle("Status: " .. r110.Status)
              end

              task.wait(2)
              r114()
              break
            end

            if r1.LH_AutoPickup.Status == "No matching eggs found" then
              num = num + 1

              if num >= 3 then
                r110.Status = "No collectable eggs remaining. Hopping..."

                if r110.StatusLabel then
                  r110.StatusLabel:SetTitle("Status: " .. r110.Status)
                end

                task.wait(1.5)
                r114()
                break
              end
            else
              num = 0
            end

            if os.clock() - value > 45 then
              r110.Status = "Wait timeout (45s). Hopping..."

              if r110.StatusLabel then
                r110.StatusLabel:SetTitle("Status: " .. r110.Status)
              end

              task.wait(1.5)
              r114()
              break
            end
          end
        end
      else
        r110.Status = "No target eggs found. Hopping..."

        if r110.StatusLabel then
          r110.StatusLabel:SetTitle("Status: " .. r110.Status)
          r110.StatusLabel:SetDesc("Initiating server hop...")
        end

        task.wait(1.5)

        if r110.Enabled and not r110.Closed then
          r114()
        end
      end
    end

    task.wait(3)
  end
end

r116 = rv1
r115(rv1)
r117 = { Title = "Server hop until egg", Icon = "globe" }
r118 = true
r117.Box = r118
r117.BoxBorder = r118
r117.Opened = r118
r116 = r49
r115 = r49:Section(r117)
r117 = r115

r110.StatusLabel = r115:Paragraph({
  Title = "Status: Idle",
  Desc = "Waiting for configuration...",
  Image = "globe",
  ImageSize = 28,
})

r118 = {
  Title = "Server Hop Until Egg",
  Desc = "Hops servers until a desired egg is found in the server",
  Flag = "Hop_Enabled",
  Value = false,
}

rv1 = function(param1)
  r110.Enabled = param1

  if not param1 then
    r110.Status = "Stopped"

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: Stopped")
      r110.StatusLabel:SetDesc("Hopping disabled.")
    end
  else
    r110.Status = "Scanning server..."

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
      r110.StatusLabel:SetDesc("Scanning Eggs...")
    end
  end
end

r119 = rv1
r118.Callback = rv1
r117 = r115
r115:Toggle(r118)
r117 = r115

r115:Paragraph({
  Title = "Targets Follow Auto Pickup",
  Desc = "Server Hop automatically scans for the Egg Rarities, Types, and Weights configured in Auto Pick Up Egg.",
  Image = "layers",
  ImageSize = 26,
})

r118 = {
  Title = "Initial Scan Delay (s)",
  Desc = "Wait time after joining for eggs to replicate",
  Flag = "Hop_ScanDelay",
  Step = 1,
}

r120 = { Min = 2, Max = 20, Default = 6 }
r119 = r120
r118.Value = r120

rv1 = function(param1)
  r110.ScanDelay = param1
end

r119 = rv1
r118.Callback = rv1
r117 = r115
r115:Slider(r118)

r118 = {
  Title = "Wait For Auto Pickup Before Hopping",
  Desc = "If target eggs are found, wait until picked up before hopping again",
  Flag = "Hop_WaitForPickup",
  Value = true,
}

rv2 = function(param1)
  r110.WaitForPickup = param1
end

r119 = rv2
r118.Callback = rv2
r117 = r115
r115:Toggle(r118)
r118 = { Title = "Hop Server Now", Icon = "shuffle" }

rv1 = function()
  r41("Server Hop", "Hopping to another server...", "shuffle", 3)
  task.spawn(r114)
end

r119 = rv1
r118.Callback = rv1
r117 = r115
r115:Button(r118)
r118 = { Title = "Check Server Eggs Now", Icon = "search" }

rv2 = function()
  local value = r113()

  if #value > 0 then
    r41("Egg Check", string.format("Found %d matching egg(s) in this server!", #value), "check", 4)
  else
    r41("Egg Check", "No matching eggs found in this server.", "triangle-alert", 3)
  end
end

r119 = rv2
r118.Callback = rv2
r117 = r115
r115:Button(r118)
r1.LH_ServerHop = r110

rv1 = function()
  r110.Closed = true
  r110.Enabled = false

  if r1.LH_ServerHop == r110 then
    r1.LH_ServerHop = nil
  end
end

r116 = rv1
r1.LH_ServerHopCleanup = rv1
task.wait(0.08)
r111 = {}
r112 = false
r111.Enabled = r112
r111.Closed = r112
r111.HatchedCount = 0
r110 = r111

r111 = function()
  local value = r92()

  if not value then
    return
  end

  local eggs = value:FindFirstChild("Eggs")

  if not eggs then
    return
  end

  for _, item in ipairs(eggs:GetChildren()) do
    local handle = item:FindFirstChild("Handle")

    if handle then
      local hatch = handle:FindFirstChild("Hatch")

      if hatch and hatch:IsA("ProximityPrompt") then
        pcall(r21, hatch)

        pcall(function()
          local value = r5:FindFirstChild("Remotes") and r5.Remotes:FindFirstChild("Game")

          if value and value:FindFirstChild("Hatch") then
            value.Hatch:FireServer(item:GetAttribute("EggKey"))
          end
        end)

        r110.HatchedCount = r110.HatchedCount + 1
        task.wait(0.15)
      end
    end
  end
end

r112 = task.spawn

rv2 = function()
  while not r110.Closed do
    if r110.Enabled then
      pcall(r111)
    end

    task.wait(2)
  end
end

r113 = rv2
r112(rv2)
r114 = { Title = "Hatch", Icon = "sparkles" }
r115 = true
r114.Box = r115
r114.BoxBorder = r115
r114.Opened = r115
r113 = r49
r112 = r49:Section(r114)
r115 = { Title = "Auto Hatch Ready Eggs", Flag = "Hatch_AutoHatch", Value = false }

rv1 = function(param1)
  r110.Enabled = param1
end

r116 = rv1
r115.Callback = rv1
r114 = r112
r112:Toggle(r115)
r115 = { Title = "Hatch All Ready Eggs Now", Icon = "egg" }

rv2 = function()
  task.spawn(r111)
  r41("Hatch", "Attempted to hatch all ready eggs.", "sparkles", 3)
end

r116 = rv2
r115.Callback = rv2
r114 = r112
r112:Button(r115)
r1.LH_AutoHatch = r110

rv1 = function()
  r110.Closed = true
  r110.Enabled = false

  if r1.LH_AutoHatch == r110 then
    r1.LH_AutoHatch = nil
  end
end

r113 = rv1
r1.LH_AutoHatchCleanup = rv1
task.wait(0.08)
r111 = {}
r112 = false
r111.Enabled = r112
r111.Closed = r112
r111.Busy = r112
r111.Interval = 2
r111.CustomMaxCapacity = 10
r113 = {}
r114 = true
r113["All Rarities"] = r114
r112 = r113
r111.TargetEggRarities = r113
r113 = {}
r113["All Eggs"] = r114
r112 = r113
r111.TargetEggTypes = r113
r111.WeightCondition = "Any Weight"
r111.TargetWeight = 1
r111.SortOrder = "Rarest First"
r111.EggsPlaced = 0
r111.Status = "Idle"
r111.StatusLabel = nil
r110 = r111

r111 = function()
  local character = r15.Character
  local value = character and character:FindFirstChildOfClass("Tool")
  local tbl = {}

  local function fn(param1)
    if not (param1:IsA("Tool") and param1:GetAttribute("EggInventoryId")) then
      return
    end

    local value1 = param1:GetAttribute("EggName") or param1.Name
    H = (value1:match("^(.-)%s*%[") or value1):gsub("%s*Egg$", "") .. " Egg"
    local value2 = r99 and r99[H] or "Common"

    if r110.TargetEggRarities
      and not r110.TargetEggRarities["All Rarities"]
      and not r110.TargetEggRarities[value2] then
      return
    end

    if r110.TargetEggTypes
      and not r110.TargetEggTypes["All Eggs"]
      and not r110.TargetEggTypes[H]
      and not r110.TargetEggTypes[value1] then
      return
    end

    local value3 = tonumber(param1:GetAttribute("Weight")) or 1

    if r110.WeightCondition == "At least (>=)" and value3 < r110.TargetWeight then
      return
    elseif r110.WeightCondition == "At most (<=)" and value3 > r110.TargetWeight then
      return
    end

    table.insert(tbl, {
      tool = param1,
      rank = r98 and r98[value2] or 1,
      weight = value3,
      name = H,
      equipped = param1 == value,
    })
  end

  if value then
    fn(value)
  end

  local backpack = r15:FindFirstChild("Backpack")

  if backpack then
    for _, item in ipairs(backpack:GetChildren()) do
      fn(item)
    end
  end

  if #tbl == 0 then
    return nil
  end

  local sortOrder = r110.SortOrder

  table.sort(tbl, function(param, param1)
    if param.equipped ~= param1.equipped then
      return param.equipped
    end

    if sortOrder == "Lightest First" then
      return param.weight < param1.weight
    elseif sortOrder == "Heaviest First" then
      return param.weight > param1.weight
    else
      if param.rank ~= param1.rank then
        return param.rank > param1.rank
      end

      return param.weight > param1.weight
    end
  end)

  return tbl[1].tool
end

r112 = function()
  if r110.Busy or r110.Closed then
    return
  end

  r110.Busy = true
  local value = r92()

  if not value then
    r110.Status = "Error: Ranch not found"

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
    end

    r110.Busy = false
    return
  end

  local baseplate = value:FindFirstChild("Baseplate")

  if not baseplate then
    r110.Status = "Error: Ranch baseplate not found"

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
    end

    r110.Busy = false
    return
  end

  local savedData = r15:FindFirstChild("SavedData")
  local value1 = savedData and savedData:FindFirstChild("Rebirths")
  local num = math.max(5, ((value1 and tonumber(value1.Value) or 0) + 1) * 5)
  local fence = value:FindFirstChild("Fence")
  local value2 = fence and fence:GetAttribute("FenceTier")

  local tbl = {
    Wood = 5,
    Gold = 10,
    Diamond = 15,
    Ruby = 20,
    Crystal = 25,
    Sakura = 30,
    Draconic = 35,
  }

  if value2 and tbl[value2] then
    num = math.max(num, tbl[value2])
  end

  local nests = value:FindFirstChild("Nests")

  if nests then
    local num1 = 0

    for _, item in ipairs(nests:GetChildren()) do
      if item.Name == "1" or item:GetAttribute("Unlocked") == true then
        num1 = num1 + 1
      end
    end

    num = math.max(num, num1)
  end

  if r110.CustomMaxCapacity and r110.CustomMaxCapacity > 0 then
    num = math.max(num, r110.CustomMaxCapacity)
  end

  local eggs = value:FindFirstChild("Eggs")
  local value3 = eggs and #eggs:GetChildren() or 0

  if value3 >= num then
    r110.Status = string.format("Ranch capacity full (%d/%d)", value3, num)

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
    end

    r110.Busy = false
    return
  end

  local value4 = r111()

  if not value4 then
    r110.Status = "No matching egg in hand/inventory"

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: " .. r110.Status)
    end

    r110.Busy = false
    return
  end

  local value5, value6, value7 = r89()

  if not value5 or not value7 then
    r110.Busy = false
    return
  end

  if value4.Parent ~= value5 then
    value7:EquipTool(value4)
    task.wait(0.2)
  end

  local name = value4.Name
  r110.Status = "Placing " .. name .. "..."

  if r110.StatusLabel then
    r110.StatusLabel:SetTitle("Status: " .. r110.Status)
  end

  local value8 = eggs and #eggs:GetChildren() or 0
  local value9 = r5:FindFirstChild("Remotes") and r5.Remotes:FindFirstChild("Game")
  local value10 = value9 and value9:FindFirstChild("EggPlaced")

  if value10 then
    value10:FireServer{ PlantPosition = baseplate.Position + Vector3.new(0, 2, 0) }
    task.wait(0.35)
    local value = eggs and #eggs:GetChildren() or value8

    if value > value8 then
      r110.EggsPlaced = r110.EggsPlaced + (value - value8)
      r110.Status = "Placed: " .. name

      if r110.StatusLabel then
        r110.StatusLabel:SetTitle("Status: " .. r110.Status)
        r110.StatusLabel:SetDesc("Eggs Placed: " .. tostring(r110.EggsPlaced))
      end
    else
      r110.Status = string.format("Ranch capacity full (%d/%d)", value, math.max(num, value))

      if r110.StatusLabel then
        r110.StatusLabel:SetTitle("Status: " .. r110.Status)
      end
    end
  end

  r110.Busy = false
end

r113 = task.spawn

rv1 = function()
  while not r110.Closed do
    if r110.Enabled and not r110.Busy then
      pcall(r112)
    end

    task.wait(r110.Interval)
  end
end

r114 = rv1
r113(rv1)
r115 = { Title = "Auto Place Egg", Icon = "egg" }
r116 = true
r115.Box = r116
r115.BoxBorder = r116
r115.Opened = r116
r114 = r49
r113 = r49:Section(r115)
r115 = r113

r110.StatusLabel = r113:Paragraph({
  Title = "Status: Idle",
  Desc = "Eggs Placed: 0",
  Image = "activity",
  ImageSize = 28,
})

r116 = { Title = "Auto Place Eggs to Ranch", Flag = "Place_AutoPlace", Value = false }

rv1 = function(param1)
  r110.Enabled = param1

  if not param1 then
    r110.Status = "Stopped"

    if r110.StatusLabel then
      r110.StatusLabel:SetTitle("Status: Stopped")
    end
  end
end

r117 = rv1
r116.Callback = rv1
r115 = r113
r113:Toggle(r116)
r116 = { Title = "Target Egg Rarity", Flag = "Place_TargetEggRarity", Values = r96 }
r118 = { "All Rarities" }
r117 = r118
r116.Value = r118
r117 = true
r116.Multi = r117
r116.AllowNone = r117

rv2 = function(param1)
  local tbl = {}

  if type(param1) == "table" then
    for _, item in ipairs(param1) do
      tbl[item] = true
    end
  elseif type(param1) == "string" and param1 ~= "" then
    tbl[param1] = true
  end

  if next(tbl) == nil then
    tbl["All Rarities"] = true
  end

  r110.TargetEggRarities = tbl
end

r117 = rv2
r116.Callback = rv2
r115 = r113
r113:Dropdown(r116)
r116 = { Title = "Target Egg Type", Flag = "Place_TargetEggType", Values = r101 }
r118 = { "All Eggs" }
r117 = r118
r116.Value = r118
r117 = true
r116.Multi = r117
r116.AllowNone = r117

rv1 = function(param1)
  local tbl = {}

  if type(param1) == "table" then
    for _, item in ipairs(param1) do
      tbl[item] = true
    end
  elseif type(param1) == "string" and param1 ~= "" then
    tbl[param1] = true
  end

  if next(tbl) == nil then
    tbl["All Eggs"] = true
  end

  r110.TargetEggTypes = tbl
end

r117 = rv1
r116.Callback = rv1
r115 = r113
r113:Dropdown(r116)
r116 = { Title = "Egg Weight Condition", Flag = "Place_WeightCondition" }
r118 = {}
r119 = "Any Weight"
r118[1], r118[2], r118[3] = r119, "At least (>=)", "At most (<=)"
r117 = r118
r116.Values = r118
r117 = r119
r116.Value = r119

rv2 = function(param1)
  r110.WeightCondition = param1
end

r117 = rv2
r116.Callback = rv2
r115 = r113
r113:Dropdown(r116)
r116 = { Title = "Target Egg Weight", Flag = "Place_TargetWeight", Step = 0.05 }
r118 = { Min = 0.5, Max = 3, Default = 1 }
r117 = r118
r116.Value = r118

rv1 = function(param1)
  r110.TargetWeight = tonumber(param1) or 1
end

r117 = rv1
r116.Callback = rv1
r115 = r113
r113:Slider(r116)
r116 = { Title = "Priority Mode", Flag = "Place_PriorityMode" }
r118 = {}
r119 = "Rarest First"
r118[1], r118[2], r118[3] = r119, "Lightest First", "Heaviest First"
r117 = r118
r116.Values = r118
r117 = r119
r116.Value = r119

rv1 = function(param1)
  r110.SortOrder = param1
end

r117 = rv1
r116.Callback = rv1
r115 = r113
r113:Dropdown(r116)
r116 = { Title = "Max Ranch Capacity", Flag = "Place_MaxEggCapacity", Step = 1 }
r118 = { Min = 5, Max = 50, Default = 10 }
r117 = r118
r116.Value = r118

rv1 = function(param1)
  r110.CustomMaxCapacity = tonumber(param1) or 10
end

r117 = rv1
r116.Callback = rv1
r115 = r113
r113:Slider(r116)
r116 = { Title = "Check Interval (s)", Flag = "Place_Interval" }
r117 = 0.5
r116.Step = r117
r118 = {}
r119 = r117
r118.Min = r117
r118.Max = 10
r118.Default = 2
r117 = r118
r116.Value = r118

rv1 = function(param1)
  r110.Interval = param1
end

r117 = rv1
r116.Callback = rv1
r115 = r113
r113:Slider(r116)
r116 = { Title = "Place Egg Once Now", Icon = "egg" }

rv1 = function()
  task.spawn(r112)
  r41("Place Egg", "Attempted to place matching egg to ranch.", "sparkles", 3)
end

r117 = rv1
r116.Callback = rv1
r115 = r113
r113:Button(r116)
r1.LH_AutoPlaceEgg = r110

rv2 = function()
  r110.Closed = true
  r110.Enabled = false

  if r1.LH_AutoPlaceEgg == r110 then
    r1.LH_AutoPlaceEgg = nil
  end
end

r114 = rv2
r1.LH_AutoPlaceEggCleanup = rv2
task.wait(0.08)
r111 = {}
r112 = false
r111.Enabled = r112
r111.AutoOffline = r112
r111.AutoIndex = r112
r111.Closed = r112
r110 = r111

r111 = function(...)
  local s4, s5, s6, s12, s11
  local s1 = r92()

  if not s1 then
    return
  end

  local s3 = s1
  local s2 = s1:FindFirstChild("Pets")
  s3 = r5:FindFirstChild("Remotes") and r5.Remotes:FindFirstChild("Game")

  if not s3 then
    return
  end

  if r110.Enabled
    and r15:GetAttribute("AutoCollectCash") ~= true
    and s3:FindFirstChild("PetCollect")
    and s2 then
    s4, s5 = r89()
    s6 = s1:FindFirstChild("Baseplate")

    if s5 and s6 and (s5.Position - s6.Position).Magnitude <= 80 then
      for s10, s11 in ipairs(s2:GetChildren()) do
        s12 = s11:GetAttribute("PetKey")

        if type(s12) == "string" and #s12 > 0 then
          pcall(function(...)
            s3.PetCollect:FireServer(s12)
          end)

          task.wait(0.05)
        end
      end
    end
  end

  if r110.AutoOffline and s3:FindFirstChild("OfflineEarnings") then
    pcall(function(...)
      s3.OfflineEarnings:FireServer()
    end)
  end

  if r110.AutoIndex and s3:FindFirstChild("ClaimIndexReward") then
    pcall(function(...)
      s3.ClaimIndexReward:FireServer()
    end)
  end
end

r112 = task.spawn

rv1 = function()
  while not r110.Closed do
    if r110.Enabled or r110.AutoOffline or r110.AutoIndex then
      pcall(r111)
    end

    task.wait(3)
  end
end

r113 = rv1
r112(rv1)
r114 = { Title = "Collection & Earnings", Icon = "coins" }
r115 = true
r114.Box = r115
r114.BoxBorder = r115
r114.Opened = r115
r113 = r49
r112 = r49:Section(r114)
r115 = { Title = "Auto Collect Pet Earnings", Flag = "Collect_AutoPetEarnings", Value = false }

rv2 = function(param1)
  r110.Enabled = param1
end

r116 = rv2
r115.Callback = rv2
r114 = r112
r112:Toggle(r115)
r115 = { Title = "Auto Offline Earnings", Flag = "Collect_AutoOffline", Value = false }

rv1 = function(param1)
  r110.AutoOffline = param1
end

r116 = rv1
r115.Callback = rv1
r114 = r112
r112:Toggle(r115)
r115 = { Title = "Auto Claim Index Rewards", Flag = "Collect_AutoIndexRewards", Value = false }

rv1 = function(param1)
  r110.AutoIndex = param1
end

r116 = rv1
r115.Callback = rv1
r114 = r112
r112:Toggle(r115)
r1.LH_AutoCollect = r110

rv2 = function()
  r110.Closed = true
  r110.Enabled = false
  r110.AutoOffline = false
  r110.AutoIndex = false

  if r1.LH_AutoCollect == r110 then
    r1.LH_AutoCollect = nil
  end
end

r113 = rv2
r1.LH_AutoCollectCleanup = rv2
task.wait(0.08)
r111 = {}
r112 = false
r111.Closed = r112
r111.RebirthEnabled = r112
r111.RebirthInterval = 1
r111.RebirthStatusLabel = nil
r111.EquipBestEnabled = false
r111.EquipBestInterval = 1
r111.UpgradeHatchLuckEnabled = false
r111.UpgradeHatchLuckInterval = 1
r111.SellEnabled = false
r111.SellInterval = 1
r111.SellMode = "Specific Rarities"
r113 = {}
r114 = true
r113.Common = r114
r113.Rare = r114
r112 = r113
r111.SellRarities = r113
r111.SellThresholdType = "Speed"
r111.SellCondition = "Less Than (<)"
r111.SellThresholdValue = 500
r112 = r114
r111.KeepRebirthPets = r114
r112 = r114
r111.KeepEquipped = r114
r111.PetsSold = 0
r111.SellStatus = "Idle"
r111.SellStatusLabel = nil
r111.SingleSellRunning = false
r110 = r111
r112 = {}
r113 = r114
r112.Horse = r114
r113 = r114
r112.Fox = r114
r113 = r114
r112.Unicorn = r114
r113 = r114
r112.Phoenix = r114
r113 = r114
r112.Kitsune = r114
r113 = r114
r112.Dragon = r114
r111 = r112

r112 = function(s1, ...)
  local s8, s10, s11, s12, s14, s13

  if not s1 or s1 == "" then
    return false
  end

  local s2 = s1:lower()
  local s3 = r15:FindFirstChild("SavedData")
  local s4 = s3 and s3:FindFirstChild("OwnedPets")

  if s4 and type(s4.Value) == "string" then
    for s8 in string.gmatch(s4.Value, "[^,]+") do
      if s8:lower() == s2 then
        return true
      end
    end
  end

  local s5 = r15:FindFirstChild("Backpack")

  if s5 then
    for s9, s10 in ipairs(s5:GetChildren()) do
      if s10:IsA("Tool") then
        s11 = s10:GetAttribute("PetName") or s10.Name

        if (s11:match("^(.-)%s*%[") or s11):lower() == s2 then
          return true
        end
      end
    end
  end

  local s6 = r15.Character

  if s6 then
    for s10, s11 in ipairs(s6:GetChildren()) do
      if s11:IsA("Tool") then
        s12 = s11:GetAttribute("PetName") or s11.Name

        if (s12:match("^(.-)%s*%[") or s12):lower() == s2 then
          return true
        end
      end
    end
  end

  local s7 = r92()
  s8 = s7 and s7:FindFirstChild("Pets")

  if s8 then
    for s12, s13 in ipairs(s8:GetChildren()) do
      s14 = s13:GetAttribute("PetName") or s13.Name

      if (s14:match("^(.-)%s*%[") or s14):lower() == s2 then
        return true
      end
    end
  end

  return false
end

r113 = function(...)
  local s1 = r15:FindFirstChild("SavedData")
  local s2 = s1 and s1:FindFirstChild("Rebirths")
  local s3 = s1 and s1:FindFirstChild("Cash")
  local s4 = s2 and tonumber(s2.Value) or 0
  local s5 = s3 and tonumber(s3.Value) or 0
  local s6 = nil
  local s7 = nil
  local s8 = pcall

  s8(function(...)
    local t1 = require(r5.GameData.Rebirths)
  end)

  s8(function(...)
    local t1 = require(r5.GameData.General)
  end)

  s8 = s6 and s6.Cap or 6

  if s4 >= s8 then
    return {
      Maxed = true,
      CurrentRebirths = s4,
      Cap = s8,
      Eligible = false,
      StatusText = string.format("Rebirths: %d/%d (MAX REACHED)", s4, s8),
    }
  end

  local s9 = 1000000

  if s6 then
    if type(s6.GetCost) == "function" then
      s9 = s6.GetCost(s4)
    else
      if s6.RiggedCost and s6.RiggedCost[s4 + 1] then
        s9 = s6.RiggedCost[s4 + 1]
      end
    end
  end

  local s10 = nil

  if s7 and s7.RebirthRequirements then
    s10 = s7.RebirthRequirements[s4 + 1]
  end

  local s11 = s10 and r112(s10) or false
  local s12 = s5 >= s9

  return {
    Maxed = false,
    CurrentRebirths = s4,
    NextRebirth = s4 + 1,
    Cap = s8,
    Cost = s9,
    Cash = s5,
    RequiredPet = s10,
    HasPet = s11,
    HasCash = s12,
    Eligible = s12 and s11,
    StatusText = string.format([[Rebirth: %d/%d
Next Cost: $%s (Cash: $%s)
Required Pet: %s (%s)]], s4, s8, (r90(s9)), (r90(s5)), tostring(s10 or "None"), s11 and "Owned" or "Missing"),
  }
end

r114 = function(...)
  local s1 = r113()

  if r110.RebirthStatusLabel then
    r110.RebirthStatusLabel:SetDesc(s1.StatusText)
  end

  if s1.Maxed or not s1.Eligible then
    return false, s1.StatusText
  end

  local s2 = r5:FindFirstChild("Remotes")
    and r5.Remotes:FindFirstChild("Game")
    and r5.Remotes.Game:FindFirstChild("Rebirth")

  if s2 then
    s2:FireServer()
    return true, "Rebirth triggered!"
  end

  return false, "Rebirth remote not found"
end

r115 = task.spawn

rv2 = function()
  while not r110.Closed do
    local value = r113()

    if r110.RebirthStatusLabel then
      r110.RebirthStatusLabel:SetDesc(value.StatusText)
    end

    if r110.RebirthEnabled and value.Eligible and not value.Maxed then
      local value, value1 = pcall(r114)

      if value and value1 then
        r41("Auto Rebirth", "Rebirth performed successfully!", "sparkles", 3)
      end
    end

    task.wait(r110.RebirthInterval)
  end
end

r116 = rv2
r115(rv2)

r115 = function(s1, s2, ...)
  local s5, s6, s7, s8

  if not s1 then
    return 0
  end

  local s3 = s1:GetAttribute("PetName") or s1.Name
  local s4 = s3:match("^(.-)%s*%[") or s3

  if s2 == "Speed" then
    s5 = s1:GetAttribute("Speed")

    if s5 then
      return tonumber(s5) or 0
    end

    s6 = s1:FindFirstChild("Speed")

    if s6 and (s6:IsA("NumberValue") or s6:IsA("IntValue")) then
      return s6.Value
    end

    s7 = s1.Name
    s8 = s7:match("(%d+)%s*M/s") or s7:match("(%d+)%s*m/s")

    if s8 then
      return tonumber(s8) or 0
    end

    if r105 and r105[s4] then
      return tonumber(r105[s4]) or 0
    end

    return 0
  end

  if s2 == "Rarity" then
    s5 = s1:GetAttribute("Rarity")

    if s5 then
      return tonumber(s5) or 0
    end

    s6 = s1:FindFirstChild("Rarity")

    if s6 and (s6:IsA("NumberValue") or s6:IsA("IntValue")) then
      return s6.Value
    end

    s8 = s1.Name:match("1%s*in%s*(%d+)")

    if s8 then
      return tonumber(s8) or 0
    end

    if r106 and r106[s4] then
      return tonumber(r106[s4]) or 0
    end

    return 0
  end

  return 0
end

r116 = function(s1, s2, s3)
  if s3 == "Less Than (<)" then
    return s1 < s2
  end

  if s3 == "Less or Equal (<=)" then
    return s1 <= s2
  end

  if s3 == "Greater Than (>)" then
    return s1 > s2
  end

  if s3 == "Greater or Equal (>=)" then
    return s1 >= s2
  end

  return s1 < s2
end

r117 = function(...)
  local s7, s8, s10, s9, s11, s12, s13, s14, s19
  local s1 = {}
  local s2 = r15:FindFirstChild("Backpack")

  if s2 then
    for s6, s7 in ipairs(s2:GetChildren()) do
      if s7:IsA("Tool") and s7:GetAttribute("PetKey") and not s7:GetAttribute("EggInventoryId") then
        table.insert(s1, s7)
      end
    end
  end

  local s3 = r15.Character

  if s3 and not r110.KeepEquipped then
    for s7, s8 in ipairs(s3:GetChildren()) do
      if s8:IsA("Tool") and s8:GetAttribute("PetKey") and not s8:GetAttribute("EggInventoryId") then
        table.insert(s1, s8)
      end
    end
  end

  local s4 = {}

  for s8, s9 in ipairs(s1) do
    s10 = s9:GetAttribute("Favorited")

    if not (s10 == true or tostring(s10) == "true") then
      s11 = s9:GetAttribute("PetName") or s9.Name
      s12 = s11:match("^(.-)%s*%[") or s11

      if not (r110.KeepRebirthPets and r111[s12]) then
        s13 = s9:GetAttribute("Rarity")

        if not s13 or type(s13) == "number" then
          s13 = r104[s12]
        end

        s14 = false

        if r110.SellMode == "Sell All Pets" then
          s14 = true
        else
          if r110.SellMode == "Specific Rarities" then
            if s13 and r110.SellRarities and r110.SellRarities[s13] then
              s14 = true
            end
          else
            if r110.SellMode == "Stat Threshold" then
              s19 = r110

              if r116(r115(s9, r110.SellThresholdType), s19.SellThresholdValue, s19.SellCondition) then
                s14 = true
              end
            end
          end
        end

        if s14 then
          table.insert(s4, {
            Tool = s9,
            Key = s9:GetAttribute("PetKey"),
            Name = s12,
            FullName = s9.Name,
            Rarity = s13 or "Unknown",
            Value = r115(s9, "Speed"),
          })
        end
      end
    end
  end

  return s4
end

r118 = function()
  local lH_AutoPickup = r1.LH_AutoPickup
  local basket = r15:FindFirstChild("Basket")

  if lH_AutoPickup and (lH_AutoPickup.Busy or lH_AutoPickup.SingleCycleRunning) or basket and #basket:GetChildren() > 0 then
    return
  end

  local value = r4:FindFirstChild("Stalls")
    and r4.Stalls:FindFirstChild("Sell")
    and r4.Stalls.Sell:FindFirstChild("Richie")

  local value1 = value and value:FindFirstChild("HumanoidRootPart")
  local value2 = value1 and value1:FindFirstChildWhichIsA("ProximityPrompt")

  if not value2 or not value1 then
    return
  end

  local value3 = r5:FindFirstChild("Dialogue")
    and r5.Dialogue:FindFirstChild("Remotes")
    and r5.Dialogue.Remotes:FindFirstChild("DialogueSelect")

  if not value3 then
    return
  end

  local value4, value5 = r89()
  local value6 = value5 and value5.CFrame or nil

  local function fn()
    local value, value2 = r89()

    if value1 and value2 and (value2.Position - value1.Position).Magnitude > 12 then
      pcall(function()
        value2.AssemblyLinearVelocity = Vector3.zero
        value2.AssemblyAngularVelocity = Vector3.zero
        value2.CFrame = value1.CFrame + value1.CFrame.LookVector * 4 + Vector3.new(0, 2, 0)
      end)

      task.wait(0.3)
    end
  end

  if r110.SellMode == "Sell All Pets" then
    fn()
    value2.HoldDuration = 0

    if type(r21) == "function" then
      pcall(r21, value2)
    end

    task.wait(r107() + 0.5)
    value3:FireServer(value, "I would like to sell my pets")
    task.wait(0.4)
    r110.SellStatus = "Sold all inventory pets"

    if r110.SellStatusLabel then
      r110.SellStatusLabel:SetTitle("Status: " .. r110.SellStatus)
    end

    task.wait(2)
  else
    local value1 = r117()

    if #value1 == 0 then
      return
    end

    fn()

    for _, item in ipairs(value1) do
      if not r110.SellEnabled and not r110.SingleSellRunning then
        break
      end

      local tool = item.Tool

      if tool and tool.Parent then
        local character = r15.Character
        local value1 = character and character:FindFirstChild("Humanoid")

        if value1 and tool.Parent ~= character then
          value1:EquipTool(tool)
          task.wait(0.25)
        end

        value2.HoldDuration = 0

        if type(r21) == "function" then
          pcall(r21, value2)
        end

        task.wait(r107() + 0.5)
        value3:FireServer(value, "I would like to sell this")
        task.wait(1)
        r110.PetsSold = r110.PetsSold + 1
        r110.SellStatus = "Sold: " .. item.Name .. " [" .. tostring(item.Rarity) .. "]"

        if r110.SellStatusLabel then
          r110.SellStatusLabel:SetTitle("Status: " .. r110.SellStatus)
          r110.SellStatusLabel:SetDesc("Pets Sold: " .. tostring(r110.PetsSold))
        end

        task.wait(2)
      end
    end
  end

  if value6 then
    local value, value2 = r89()

    if value2 and value1 and (value2.Position - value1.Position).Magnitude <= 25 then
      pcall(function()
        value2.AssemblyLinearVelocity = Vector3.zero
        value2.AssemblyAngularVelocity = Vector3.zero
        value2.CFrame = value6
      end)
    end
  end
end

r119 = function(...)
  local s5, s6, s14
  local s1 = r1.LH_AutoPickup
  local s2 = r15:FindFirstChild("Basket")

  if r15:GetAttribute("IsRiding") == true
    or s1 and (s1.Enabled or s1.Busy or s1.SingleCycleRunning)
    or s2 and #s2:GetChildren() > 0 then
    return false
  end

  local s3 = r92()
  local s4 = s3 and s3:FindFirstChild("Baseplate")
  s5, s6 = r89()

  if not s4 or not s6 or (s6.Position - s4.Position).Magnitude > 60 then
    return false
  end

  local s7 = r15:FindFirstChild("PlayerGui")
    and r15.PlayerGui:FindFirstChild("Main")
    and r15.PlayerGui.Main:FindFirstChild("PetsTracker")

  local s8 = s7 and s7:FindFirstChild("PlaceBest")

  if s8 then
    if type(firesignal) == "function" then
      pcall(firesignal, s8.Activated)
    else
      for s13, s14 in ipairs(((getconnections or get_signal_cons)(s8.Activated))) do
        pcall(function(...)
          s14:Fire()
        end)
      end
    end

    return true
  end

  return false
end

r120 = function(...)
  local s11, s12, s18
  local s1 = r92()

  if not s1 then
    return false
  end

  local s2 = s1:FindFirstChild("HatchUpgrade")
  local s3 = s2 and s2:FindFirstChild("MaxUpgrade")
  local s4 = s2 and s2:FindFirstChild("Screen")
  local s5 = r15:FindFirstChild("PlayerGui")

  if not s5 then
    return false
  end

  local s6 = false

  for s10, s11 in ipairs(s5:GetChildren()) do
    if s11:IsA("SurfaceGui") and (s11.Adornee == s3 or s11.Adornee == s4) then
      s12 = s11:FindFirstChild("Purchase", true) or s11:FindFirstChild("UpgradeLuck", true)

      if s12 then
        if type(firesignal) == "function" then
          pcall(firesignal, s12.Activated)
          s6 = true
        else
          for s17, s18 in ipairs(((getconnections or get_signal_cons)(s12.Activated))) do
            pcall(function(...)
              s18:Fire()
            end)

            s6 = true
          end
        end
      end
    end
  end

  return s6
end

r121 = task.spawn

rv2 = function()
  while not r110.Closed do
    if r110.SellEnabled then
      pcall(r118)
    end

    task.wait(r110.SellInterval)
  end
end

r122 = rv2
r121(rv2)
r121 = task.spawn

rv2 = function()
  while not r110.Closed do
    if r110.EquipBestEnabled then
      pcall(r119)
    end

    task.wait(r110.EquipBestInterval)
  end
end

r122 = rv2
r121(rv2)
r121 = task.spawn

rv1 = function()
  while not r110.Closed do
    if r110.UpgradeHatchLuckEnabled then
      pcall(r120)
    end

    task.wait(r110.UpgradeHatchLuckInterval)
  end
end

r122 = rv1
r121(rv1)
r123 = { Title = "Auto Equip Best Pet", Icon = "paw-print" }
r124 = true
r123.Box = r124
r123.BoxBorder = r124
r123.Opened = r124
r122 = r50
r121 = r50:Section(r123)
r124 = { Title = "Auto Equip Best Pet on Ranch", Flag = "Auto_EquipBestPet", Value = false }

rv1 = function(param1)
  r110.EquipBestEnabled = param1
end

r125 = rv1
r124.Callback = rv1
r123 = r121
r121:Toggle(r124)
r124 = { Title = "Check Interval (s)", Flag = "Auto_EquipBestInterval" }
r125 = 1
r124.Step = r125
r126 = {}
r127 = r125
r126.Min = r125
r126.Max = 15
r126.Default = 5
r125 = r126
r124.Value = r126

rv1 = function(param1)
  r110.EquipBestInterval = param1
end

r125 = rv1
r124.Callback = rv1
r123 = r121
r121:Slider(r124)
r124 = { Title = "Equip Best Pets Now", Icon = "paw-print" }

rv1 = function()
  local value = r119()

  r41(
    "Equip Best",
    value and "Triggered Place Best pets." or "Place Best button not found.",
    value and "check" or "triangle-alert",
    3
  )
end

r125 = rv1
r124.Callback = rv1
r123 = r121
r121:Button(r124)
task.wait(0.08)
r124 = { Title = "Auto Upgrade Hatch Luck", Icon = "clover" }
r125 = true
r124.Box = r125
r124.BoxBorder = r125
r124.Opened = r125
r123 = r50
r122 = r50:Section(r124)
r125 = { Title = "Auto Upgrade Hatch Luck", Flag = "Auto_UpgradeHatchLuck", Value = false }

rv1 = function(param1)
  r110.UpgradeHatchLuckEnabled = param1
end

r126 = rv1
r125.Callback = rv1
r124 = r122
r122:Toggle(r125)
r125 = { Title = "Check Interval (s)", Flag = "Auto_UpgradeHatchLuckInterval", Step = 0.5 }
r127 = { Min = 1, Max = 10, Default = 3 }
r126 = r127
r125.Value = r127

rv1 = function(param1)
  r110.UpgradeHatchLuckInterval = param1
end

r126 = rv1
r125.Callback = rv1
r124 = r122
r122:Slider(r125)
r125 = { Title = "Upgrade Hatch Luck Now", Icon = "sparkles" }

rv1 = function()
  local value = r120()

  r41(
    "Hatch Luck",
    value and "Attempted hatch luck upgrade." or "Hatch upgrade station not found.",
    value and "check" or "triangle-alert",
    3
  )
end

r126 = rv1
r125.Callback = rv1
r124 = r122
r122:Button(r125)
task.wait(0.08)
r125 = { Title = "Auto Sell Pets", Icon = "badge-dollar-sign" }
r126 = true
r125.Box = r126
r125.BoxBorder = r126
r125.Opened = r126
r124 = r50
r123 = r50:Section(r125)
r125 = r123

r110.SellStatusLabel = r123:Paragraph({
  Title = "Status: Idle",
  Desc = "Pets Sold: 0",
  Image = "badge-dollar-sign",
  ImageSize = 28,
})

r126 = { Title = "Auto Sell Pets", Flag = "Auto_SellPets", Value = false }

rv1 = function(param1)
  r110.SellEnabled = param1

  if not param1 then
    r110.SellStatus = "Stopped"

    if r110.SellStatusLabel then
      r110.SellStatusLabel:SetTitle("Status: Stopped")
    end
  end
end

r127 = rv1
r126.Callback = rv1
r125 = r123
r123:Toggle(r126)
r126 = { Title = "Sell Mode", Flag = "Auto_SellMode" }
r128 = {}
r129 = "Specific Rarities"
r128[1], r128[2], r128[3] = r129, "Sell All Pets", "Stat Threshold"
r127 = r128
r126.Values = r128
r127 = r129
r126.Value = r129

rv2 = function(param1)
  r110.SellMode = param1
end

r127 = rv2
r126.Callback = rv2
r125 = r123
r123:Dropdown(r126)
r126 = { Title = "Target Pet Rarities", Flag = "Auto_SellTargetRarities", Values = r97 }
r128 = {}
r128[1], r128[2] = "Common", "Rare"
r127 = r128
r126.Value = r128
r127 = true
r126.Multi = r127
r126.AllowNone = r127

rv2 = function(param1)
  local tbl = {}

  if type(param1) == "table" then
    for _, item in ipairs(param1) do
      tbl[item] = true
    end
  elseif type(param1) == "string" and param1 ~= "" then
    tbl[param1] = true
  end

  r110.SellRarities = tbl
end

r127 = rv2
r126.Callback = rv2
r125 = r123
r123:Dropdown(r126)
r126 = { Title = "Threshold Type", Flag = "Auto_SellThresholdType" }
r128 = {}
r129 = "Speed"
r128[1], r128[2] = r129, "Rarity"
r127 = r128
r126.Values = r128
r127 = r129
r126.Value = r129

rv1 = function(param1)
  r110.SellThresholdType = param1
end

r127 = rv1
r126.Callback = rv1
r125 = r123
r123:Dropdown(r126)
r126 = { Title = "Comparison Condition", Flag = "Auto_SellCondition" }
r128 = {}
r129 = "Less Than (<)"
r128[1], r128[2], r128[3], r128[4] = r129, "Less or Equal (<=)", "Greater Than (>)", "Greater or Equal (>=)"
r127 = r128
r126.Values = r128
r127 = r129
r126.Value = r129

rv1 = function(param1)
  r110.SellCondition = param1
end

r127 = rv1
r126.Callback = rv1
r125 = r123
r123:Dropdown(r126)

r126 = {
  Title = "Threshold Value",
  Placeholder = "Enter numeric value (e.g. 500, 1M, 5B)",
  Value = "500",
}

rv1 = function(param1)
  local value = r91(param1)

  if value then
    r110.SellThresholdValue = value
  end
end

r127 = rv1
r126.Callback = rv1
r125 = r123
r123:Input(r126)

r126 = {
  Title = "Keep Rebirth Pets",
  Flag = "Auto_SellKeepRebirthPets",
  Desc = "Protects Horse, Fox, Unicorn, Phoenix, Kitsune, Dragon from being sold",
  Value = true,
}

rv2 = function(param1)
  r110.KeepRebirthPets = param1
end

r127 = rv2
r126.Callback = rv2
r125 = r123
r123:Toggle(r126)
r126 = { Title = "Keep Equipped / Riding Pet", Flag = "Auto_SellKeepEquipped", Value = true }

rv2 = function(param1)
  r110.KeepEquipped = param1
end

r127 = rv2
r126.Callback = rv2
r125 = r123
r123:Toggle(r126)
r126 = { Title = "Sell Interval (s)", Flag = "Auto_SellInterval", Step = 0.5 }
r128 = { Min = 1, Max = 15, Default = 3 }
r127 = r128
r126.Value = r128

rv2 = function(param1)
  r110.SellInterval = param1
end

r127 = rv2
r126.Callback = rv2
r125 = r123
r123:Slider(r126)
r126 = { Title = "Sell Matching Pets Now", Icon = "trash-2" }

rv2 = function()
  r110.SingleSellRunning = true

  task.spawn(function()
    r118()
    r110.SingleSellRunning = false
    r41("Auto Sell", "Completed manual pet sell cycle.", "check", 3)
  end)
end

r127 = rv2
r126.Callback = rv2
r125 = r123
r123:Button(r126)
task.wait(0.08)
r126 = { Title = "Auto Rebirth", Icon = "repeat" }
r127 = true
r126.Box = r127
r126.BoxBorder = r127
r126.Opened = r127
r125 = r50
r124 = r50:Section(r126)
r126 = r124

r110.RebirthStatusLabel = r124:Paragraph({
  Title = "Rebirth Requirements",
  Desc = "Loading requirements...",
  Image = "repeat",
  ImageSize = 28,
})

r127 = { Title = "Auto Rebirth", Flag = "Auto_Rebirth", Value = false }

rv1 = function(param1)
  r110.RebirthEnabled = param1
end

r128 = rv1
r127.Callback = rv1
r126 = r124
r124:Toggle(r127)
r127 = { Title = "Check Interval (s)", Flag = "Auto_RebirthInterval", Step = 0.5 }
r129 = { Min = 1, Max = 10, Default = 2 }
r128 = r129
r127.Value = r129

rv1 = function(param1)
  r110.RebirthInterval = param1
end

r128 = rv1
r127.Callback = rv1
r126 = r124
r124:Slider(r127)
r127 = { Title = "Rebirth Now", Icon = "zap" }

rv2 = function()
  local value, value1 = r114()

  r41(
    "Rebirth",
    value1 or (value and "Rebirth initiated" or "Conditions not met"),
    value and "check" or "triangle-alert",
    3
  )
end

r128 = rv2
r127.Callback = rv2
r126 = r124
r124:Button(r127)
r1.LH_AutoRebirth = r110
r1.LH_AutoSell = r110
r1.LH_AutoPlot = r110

rv1 = function()
  r110.Closed = true
  r110.RebirthEnabled = false
  r110.SellEnabled = false
  r110.EquipBestEnabled = false
  r110.UpgradeHatchLuckEnabled = false

  if r1.LH_AutoRebirth == r110 then
    r1.LH_AutoRebirth = nil
  end

  if r1.LH_AutoSell == r110 then
    r1.LH_AutoSell = nil
  end

  if r1.LH_AutoPlot == r110 then
    r1.LH_AutoPlot = nil
  end
end

r125 = rv1
r1.LH_AutoRebirthCleanup = rv1
r1.LH_AutoSellCleanup = r1.LH_AutoRebirthCleanup
r1.LH_AutoPlotCleanup = r1.LH_AutoRebirthCleanup
task.wait(0.08)
r111 = {}
r111["Advanced Radar"] = 50
r111["Jewel Radar"] = 3000
r111["Royal Radar"] = 20000
r111["Magic Radar"] = 300000
r111["Angelic Radar"] = 7000000
r111["Eternal Radar"] = 30000000
r110 = r111
r112 = {}
r112[1], r112[2], r112[3], r112[4], r112[5], r112[6] = "Advanced Radar", "Jewel Radar", "Royal Radar", "Magic Radar", "Angelic Radar", "Eternal Radar"
r111 = r112
r113 = { Grass = 10, Bone = 1500, Meat = 30000 }
r113["Magic Apple"] = 700000
r113.Dragonfruit = 30000000
r112 = r113
r114 = {}
r114[1], r114[2], r114[3], r114[4], r114[5] = "Grass", "Bone", "Meat", "Magic Apple", "Dragonfruit"
r113 = r114
r115 = {}
r116 = false
r115.Closed = r116
r115.BuyGearsEnabled = r116
r115.BuyFoodsEnabled = r116
r117 = {}
r116 = r117
r115.SelectedGears = r117
r117 = {}
r116 = r117
r115.SelectedFoods = r117
r115.ReserveCash = 0
r115.CheckInterval = 2
r115.ItemsBought = 0
r115.Status = "Idle"
r115.StatusLabel = nil
r114 = r115
r116 = {}
r118 = {}
r117 = r118
r116.Gears = r118
r118 = {}
r117 = r118
r116.Food = r118
r115 = r116
r116 = nil

rv1 = function(...)
  local s3
  local s1 = r5:FindFirstChild("Remotes") and r5.Remotes:FindFirstChild("Game")
  local s2 = s1 and s1:FindFirstChild("Restock")

  if s2 then
    s3 = s2.OnClientEvent:Connect((function(param1)
      if type(param1) == "table" then
        if param1.Gears then
          r115.Gears = param1.Gears
        end

        if param1.Food then
          r115.Food = param1.Food
        end
      end
    end))
  end

  s3 = s1 and s1:FindFirstChild("ShopStock")

  if s3 then
    s3:FireServer()
  end
end

r118 = rv1
pcall(rv1)

r117 = function(...)
  local s1 = r15:FindFirstChild("SavedData")
  local s2 = s1 and s1:FindFirstChild("Cash")
  return s2 and tonumber(s2.Value) or 0
end

r118 = function(s1, s2, s3, ...)
  local s10

  if r117() < s3 + r114.ReserveCash then
    return false, "Insufficient cash"
  end

  local s5 = r115[s1]
  local s6 = s5 and s5[s2]
  local s7 = type(s6) == "table" and tonumber(s6.Amount) or 0

  if not s7 or s7 <= 0 then
    return false, "Out of stock"
  end

  local s8 = r5:FindFirstChild("Remotes") and r5.Remotes:FindFirstChild("Game")
  local s9 = s8 and s8:FindFirstChild("BuyWithCash")

  if s9 then
    s9:FireServer(s1, s2)
    s10 = r114
    s10.ItemsBought = s10.ItemsBought + 1

    if s5 and s5[s2] and s5[s2].Amount then
      s10 = s5[s2]
      s10.Amount = s5[s2].Amount - 1
    end

    return true, "Purchased " .. s2
  end

  return false, "Buy remote not found"
end

r119 = function(...)
  local s6, s7, s5, s9, s10, s13
  local s1 = r117()

  if r114.BuyGearsEnabled then
    for s5, s6 in pairs(r114.SelectedGears) do
      if s6 then
        s7 = r110[s5] or 999999999

        if s1 >= s7 + r114.ReserveCash then
          if r118("Gears", s5, s7) then
            s9 = r114
            s9.Status = "Bought " .. s5

            if s9.StatusLabel then
              s10 = r114
              s13 = s10
              s10.StatusLabel:SetTitle("Status: " .. s10.Status)

              s13.StatusLabel:SetDesc(string.format(
                "Total Bought: %d | Cash: $%s",
                s13.ItemsBought,
                r90((r117()))
              ))
            end

            s1 = r117()
            task.wait(0.15)
          end
        end
      end
    end
  end

  if r114.BuyFoodsEnabled then
    for s5, s6 in pairs(r114.SelectedFoods) do
      if s6 then
        s7 = r112[s5] or 999999999

        if s1 >= s7 + r114.ReserveCash then
          if r118("Food", s5, s7) then
            s9 = r114
            s9.Status = "Bought " .. s5

            if s9.StatusLabel then
              s10 = r114
              s13 = s10
              s10.StatusLabel:SetTitle("Status: " .. s10.Status)

              s13.StatusLabel:SetDesc(string.format(
                "Total Bought: %d | Cash: $%s",
                s13.ItemsBought,
                r90((r117()))
              ))
            end

            s1 = r117()
            task.wait(0.15)
          end
        end
      end
    end
  end
end

r120 = task.spawn

rv1 = function()
  while not r114.Closed do
    if r114.BuyGearsEnabled or r114.BuyFoodsEnabled then
      pcall(r119)
    end

    task.wait(r114.CheckInterval)
  end
end

r121 = rv1
r120(rv1)
r122 = { Title = "Auto Buy Gears & Foods", Icon = "shopping-cart" }
r123 = true
r122.Box = r123
r122.BoxBorder = r123
r122.Opened = r123
r121 = r50
r120 = r50:Section(r122)
r122 = r120

r114.StatusLabel = r120:Paragraph({
  Title = "Status: Idle",
  Desc = "Total Bought: 0",
  Image = "shopping-cart",
  ImageSize = 28,
})

r123 = { Title = "Auto Buy Gears", Flag = "Auto_BuyGears", Value = false }

rv2 = function(param1)
  r114.BuyGearsEnabled = param1

  if not param1 and not r114.BuyFoodsEnabled then
    r114.Status = "Stopped"

    if r114.StatusLabel then
      r114.StatusLabel:SetTitle("Status: Stopped")
    end
  end
end

r124 = rv2
r123.Callback = rv2
r122 = r120
r120:Toggle(r123)
r123 = { Title = "Select Gears to Buy", Flag = "Auto_SelectedGears", Values = r111 }
r125 = {}
r124 = r125
r123.Value = r125
r124 = true
r123.Multi = r124
r123.AllowNone = r124

rv2 = function(param1)
  local tbl = {}

  if type(param1) == "table" then
    for _, item in ipairs(param1) do
      tbl[item] = true
    end
  elseif type(param1) == "string" and param1 ~= "" then
    tbl[param1] = true
  end

  r114.SelectedGears = tbl
end

r124 = rv2
r123.Callback = rv2
r122 = r120
r120:Dropdown(r123)
r123 = { Title = "Auto Buy Foods", Flag = "Auto_BuyFoods", Value = false }

rv2 = function(param1)
  r114.BuyFoodsEnabled = param1

  if not param1 and not r114.BuyGearsEnabled then
    r114.Status = "Stopped"

    if r114.StatusLabel then
      r114.StatusLabel:SetTitle("Status: Stopped")
    end
  end
end

r124 = rv2
r123.Callback = rv2
r122 = r120
r120:Toggle(r123)
r123 = { Title = "Select Foods to Buy", Flag = "Auto_SelectedFoods", Values = r113 }
r125 = {}
r124 = r125
r123.Value = r125
r124 = true
r123.Multi = r124
r123.AllowNone = r124

rv2 = function(param1)
  local tbl = {}

  if type(param1) == "table" then
    for _, item in ipairs(param1) do
      tbl[item] = true
    end
  elseif type(param1) == "string" and param1 ~= "" then
    tbl[param1] = true
  end

  r114.SelectedFoods = tbl
end

r124 = rv2
r123.Callback = rv2
r122 = r120
r120:Dropdown(r123)

r123 = {
  Title = "Reserve Cash ($)",
  Desc = "Minimum cash balance to preserve (supports K, M, B, T like 500K, 2.5M)",
  Placeholder = "0 (e.g. 500K, 2M)",
  Value = "0",
}

rv1 = function(param1)
  r114.ReserveCash = r91(param1)
end

r124 = rv1
r123.Callback = rv1
r122 = r120
r120:Input(r123)
r123 = { Title = "Check Interval (s)", Flag = "Auto_BuyCheckInterval", Step = 0.5 }
r125 = { Min = 1, Max = 15, Default = 2 }
r124 = r125
r123.Value = r125

rv1 = function(param1)
  r114.CheckInterval = param1
end

r124 = rv1
r123.Callback = rv1
r122 = r120
r120:Slider(r123)
r123 = { Title = "Buy Selected Items Now", Icon = "shopping-bag" }

rv1 = function()
  task.spawn(function()
    r119()
    r41("Auto Buy", "Completed purchase check.", "check", 3)
  end)
end

r124 = rv1
r123.Callback = rv1
r122 = r120
r120:Button(r123)
r1.LH_AutoShop = r114

rv2 = function()
  r114.Closed = true
  r114.BuyGearsEnabled = false
  r114.BuyFoodsEnabled = false

  if r116 then
    pcall(function()
      r116:Disconnect()
    end)
  end

  if r1.LH_AutoShop == r114 then
    r1.LH_AutoShop = nil
  end
end

r121 = rv2
r1.LH_AutoShopCleanup = rv2
task.wait(0.08)
r110 = {}

rv1 = function(...)
  local s2
  local s1 = r5:FindFirstChild("GameData") and r5.GameData:FindFirstChild("Foods")

  if s1 then
    s2 = require(s1)
  end
end

r112 = rv1
pcall(rv1)
r112 = {}
r113 = false
r112.Closed = r113
r112.Enabled = r113
r112.TargetMode = "All Plot Pets"
r114 = {}
r114["All Foods"] = true
r113 = r114
r112.AllowedFoods = r114
r112.FeedInterval = 1
r112.PetsFed = 0
r112.SingleFeedRunning = false
r112.Status = "Idle"
r112.StatusLabel = nil
r111 = r112

r112 = function()
  local tbl = {}
  local backpack = r15:FindFirstChild("Backpack")

  if backpack then
    for _, item in ipairs(backpack:GetChildren()) do
      if item:IsA("Tool") and (item:HasTag("Food") or r110[item.Name]) then
        if r111.AllowedFoods["All Foods"] or r111.AllowedFoods[item.Name] then
          table.insert(tbl, item)
        end
      end
    end
  end

  local character = r15.Character

  if character then
    for _, item in ipairs(character:GetChildren()) do
      if item:IsA("Tool") and (item:HasTag("Food") or r110[item.Name]) then
        if r111.AllowedFoods["All Foods"] or r111.AllowedFoods[item.Name] then
          table.insert(tbl, item)
        end
      end
    end
  end

  return tbl
end

r113 = function()
  local tbl = {}
  local value = r92()

  if r111.TargetMode ~= "Equipped / Riding Pet Only" and value and value:FindFirstChild("Pets") then
    for _, item in ipairs(value.Pets:GetChildren()) do
      local attribute = item:GetAttribute("PetKey")

      if attribute then
        table.insert(tbl, { Key = attribute, Name = item.Name, Mounted = false })
      end
    end
  end

  if r111.TargetMode ~= "All Plot Pets" then
    local character = r15.Character
    local value = character and character:FindFirstChild("HumanoidRootPart")
    local value1 = value and value:FindFirstChild("PetMountJoint")
    local value2 = value1 and value1.Part1 and value1.Part1.Parent
    local value3 = value2 and value2:GetAttribute("PetKey")

    if value3 then
      table.insert(tbl, { Key = value3, Name = value2.Name, Mounted = true })
    end
  end

  return tbl
end

r114 = function()
  local lH_AutoPickup = r1.LH_AutoPickup
  local basket = r15:FindFirstChild("Basket")

  if lH_AutoPickup and (lH_AutoPickup.Busy or lH_AutoPickup.SingleCycleRunning) or basket and #basket:GetChildren() > 0 then
    return false, "AutoPickup busy"
  end

  local value = r112()

  if #value == 0 then
    r111.Status = "No foods in inventory"

    if r111.StatusLabel then
      r111.StatusLabel:SetTitle("Status: " .. r111.Status)
      r111.StatusLabel:SetDesc("Waiting for food in inventory...")
    end

    return false, "No foods"
  end

  local value1 = r5:FindFirstChild("Remotes") and r5.Remotes:FindFirstChild("Game")
  local value2 = value1 and value1:FindFirstChild("FeedPet")

  if not value2 then
    return false, "Feed remote not found"
  end

  local value3 = r92()

  if not value3 then
    return false, "Ranch not found"
  end

  local baseplate = value3:FindFirstChild("Baseplate")
  local value4, value5 = r89()

  if baseplate and value5 then
    if (value5.Position - baseplate.Position).Magnitude > 45 then
      r111.Status = "Teleporting to ranch..."

      if r111.StatusLabel then
        r111.StatusLabel:SetTitle("Status: " .. r111.Status)
      end

      r93()
      task.wait(0.25)
    end
  end

  local value6 = r113()

  if #value6 == 0 then
    r111.Status = "No target pets found"

    if r111.StatusLabel then
      r111.StatusLabel:SetTitle("Status: " .. r111.Status)
    end

    return false, "No target pets"
  end

  local num = 0
  local num1 = 1
  local count = #value

  for _, item in ipairs(value6) do
    if r111.Closed or not r111.Enabled and not r111.SingleFeedRunning then
      break
    end

    if num1 > count then
      break
    end

    local value1 = value[num1]

    if not (value1 and value1.Parent) then
      value = r112()
      count = #value
      num1 = 1
      value1 = value[1]

      if not value1 then
        break
      end
    end

    if item.Mounted then
      value2:FireServer(item.Key, value1.Name, true)
    else
      value2:FireServer(item.Key, value1.Name)
    end

    num1 = num1 + 1
    r111.PetsFed = r111.PetsFed + 1
    num = num + 1
    task.wait(0.08)
  end

  r111.Status = string.format("Fed %d pets", num)

  if r111.StatusLabel then
    r111.StatusLabel:SetTitle("Status: " .. r111.Status)

    r111.StatusLabel:SetDesc(string.format(
      "Total Fed: %d | Remaining Foods: %d",
      r111.PetsFed,
      math.max(0, count - num)
    ))
  end

  return true, string.format("Fed %d pets", num)
end

r115 = task.spawn

rv2 = function()
  while not r111.Closed do
    if r111.Enabled then
      pcall(r114)
    end

    task.wait(r111.FeedInterval)
  end
end

r116 = rv2
r115(rv2)
r117 = { Title = "Auto Feed Pets", Icon = "utensils" }
r118 = true
r117.Box = r118
r117.BoxBorder = r118
r117.Opened = r118
r116 = r50
r115 = r50:Section(r117)
r117 = r115

r111.StatusLabel = r115:Paragraph({
  Title = "Status: Idle",
  Desc = "Total Pets Fed: 0",
  Image = "utensils",
  ImageSize = 28,
})

r118 = {
  Title = "Auto Feed Pets",
  Desc = "Automatically feeds pets with food from player's inventory",
  Flag = "Auto_FeedPets",
  Value = false,
}

rv2 = function(param1)
  r111.Enabled = param1

  if not param1 then
    r111.Status = "Stopped"

    if r111.StatusLabel then
      r111.StatusLabel:SetTitle("Status: Stopped")
    end
  else
    r111.Status = "Feeding..."

    if r111.StatusLabel then
      r111.StatusLabel:SetTitle("Status: Feeding...")
    end
  end
end

r119 = rv2
r118.Callback = rv2
r117 = r115
r115:Toggle(r118)
r118 = { Title = "Target Pets", Flag = "Auto_FeedTargetMode" }
r120 = {}
r121 = "All Plot Pets"
r120[1], r120[2], r120[3] = r121, "Equipped / Riding Pet Only", "All Pets (Plot + Riding)"
r119 = r120
r118.Values = r120
r119 = r121
r118.Value = r121

rv1 = function(param1)
  r111.TargetMode = param1
end

r119 = rv1
r118.Callback = rv1
r117 = r115
r115:Dropdown(r118)
r118 = { Title = "Allowed Foods", Flag = "Auto_FeedAllowedFoods" }
r120 = {}
r121 = "All Foods"
r120[1], r120[2], r120[3], r120[4], r120[5], r120[6] = r121, "Grass", "Bone", "Meat", "Magic Apple", "Dragonfruit"
r119 = r120
r118.Values = r120
r120 = { r121 }
r119 = r120
r118.Value = r120
r119 = true
r118.Multi = r119
r118.AllowNone = r119

rv2 = function(param1)
  local tbl = {}

  if type(param1) == "table" then
    for _, item in ipairs(param1) do
      tbl[item] = true
    end
  elseif type(param1) == "string" and param1 ~= "" then
    tbl[param1] = true
  end

  if next(tbl) == nil then
    tbl["All Foods"] = true
  end

  r111.AllowedFoods = tbl
end

r119 = rv2
r118.Callback = rv2
r117 = r115
r115:Dropdown(r118)
r118 = { Title = "Feed Interval (s)", Flag = "Auto_FeedInterval" }
r119 = 0.5
r118.Step = r119
r120 = {}
r121 = r119
r120.Min = r119
r120.Max = 10
r120.Default = 1
r119 = r120
r118.Value = r120

rv2 = function(param1)
  r111.FeedInterval = param1
end

r119 = rv2
r118.Callback = rv2
r117 = r115
r115:Slider(r118)
r118 = { Title = "Feed Pets Once Now", Icon = "utensils" }

rv2 = function()
  r111.SingleFeedRunning = true

  task.spawn(function()
    local value, value1 = r114()
    r111.SingleFeedRunning = false

    r41(
      "Auto Feed",
      value and tostring(value1) or "Could not feed pets.",
      value and "check" or "triangle-alert",
      3
    )
  end)
end

r119 = rv2
r118.Callback = rv2
r117 = r115
r115:Button(r118)
r1.LH_AutoFeed = r111

rv2 = function()
  r111.Closed = true
  r111.Enabled = false

  if r1.LH_AutoFeed == r111 then
    r1.LH_AutoFeed = nil
  end
end

r116 = rv2
r1.LH_AutoFeedCleanup = rv2
task.wait(0.08)
r111 = { Enabled = false }
r112 = ""
r111.Url = r112
r111.UserId = r112
r111.PingMode = "None"
r112 = true
r111.NotifyEggs = r112
r111.NotifyRadars = r112
r111.NotifyFoods = r112
r111.NotifyTools = r112
r113 = {}
r114 = r112
r113["All Eggs"] = r112
r112 = r113
r111.SelectedEggs = r113
r113 = {}
r113["All Rarities"] = r114
r112 = r113
r111.SelectedEggRarities = r113
r113 = {}
r113["All Radars"] = r114
r112 = r113
r111.SelectedRadars = r113
r113 = {}
r113["All Foods"] = r114
r112 = r113
r111.SelectedFoods = r113
r111.MinEggWeight = 0
r110 = r111
r111 = r32
r111 = r32("Linkhive_RideAPet/WebhookConfig.json", nil)
r113 = r111

if type(r111) == "table" then
  r113 = r111

  for r115, r116 in pairs(r111) do
    r110[r115] = r116
  end
end

r112 = function()
  r33("Linkhive_RideAPet/WebhookConfig.json", r110)
end

r114 = {}
r114[1], r114[2], r114[3], r114[4], r114[5], r114[6], r114[7] = "All Radars", "Advanced Radar", "Jewel Radar", "Royal Radar", "Magic Radar", "Angelic Radar", "Eternal Radar"
r113 = r114
r115 = {}
r115[1], r115[2], r115[3], r115[4], r115[5], r115[6] = "All Foods", "Grass", "Bone", "Meat", "Magic Apple", "Dragonfruit"
r114 = r115

r115 = function(param1)
  local str = string.gsub(r110.Url or "", "^%s*(.-)%s*$", "%1")

  if str == "" then
    return false, "Webhook URL is empty"
  end

  if not (str:find("^https://.*discord.*%.com/api/webhooks/") or str:find("^https://discordapp%.com/api/webhooks/")) then
    return false, "Invalid Discord webhook URL"
  end

  if not r24 then
    return false, "HTTP request function unavailable"
  end

  local value, value1 = pcall(r8.JSONEncode, r8, param1)

  if not value or not value1 then
    return false, "JSON encode failed"
  end

  local value2, value3 = pcall(r24, {
    Url = str,
    Method = "POST",
    Headers = { ["Content-Type"] = "application/json" },
    Body = value1,
  })

  if not value2 then
    return false, "Request error: " .. tostring(value3)
  end

  local value4 = value3 and (value3.StatusCode or value3.Status)

  if value4 and value4 >= 200 and value4 < 300 then
    return true, "Success"
  else
    return false, "Discord returned code " .. tostring(value4)
  end
end

r116 = function(param1)
  local value

  if r110.PingMode == "User ID" and r110.UserId and r110.UserId ~= "" then
    value = string.format("<@%s>", r110.UserId)
  elseif r110.PingMode == "@here" then
    value = "@here"
  elseif r110.PingMode == "@everyone" then
    value = "@everyone"
  end

  local list = {
    { name = "Item Name", value = string.format("`%s`", param1.name or "Unknown"), inline = true },
    { name = "Category", value = string.format("`%s`", param1.category or "Item"), inline = true },
  }

  if param1.rarity then
    table.insert(list, {
      name = "Rarity",
      value = string.format("`%s`", tostring(param1.rarity)),
      inline = true,
    })
  end

  if param1.weight then
    table.insert(list, {
      name = "Weight",
      value = string.format("`%.2f`", tonumber(param1.weight) or 1),
      inline = true,
    })
  end

  local value1 = r15 and r15.Name or "Unknown"

  table.insert(list, {
    name = "Player",
    value = string.format("%s (`%s`)", r15 and r15.DisplayName or value1, value1),
    inline = false,
  })

  local tbl = {
    username = "Linkhive - Ride A Pet",
    avatar_url = "https://raw.githubusercontent.com/afkar-gg/sc/refs/heads/main/Linkhive/icon.png",
    embeds = {
      {
        title = "Item Acquired!",
        description = string.format("Acquired **%s** (%s)", param1.name or "Item", param1.category or "Item"),
        color = 16429844,
        fields = list,
        footer = { text = "Linkhive Ride A Pet Automation" },
        timestamp = DateTime.now():ToIsoDate(),
      },
    },
  }

  if value then
    tbl.content = value
  end

  return tbl
end

r117 = function(param1)
  if not r110.Enabled then
    return
  end

  local value = r116(param1)

  task.spawn(function()
    r115(value)
  end)
end

r118 = setmetatable({}, { __mode = "k" })
r119 = true

r120 = function(param1)
  if not (param1 and param1:IsA("Tool")) then
    return nil
  end

  local value = param1.Name or ""
  local attribute = param1:GetAttribute("EggInventoryId")
  local attribute1 = param1:GetAttribute("EggName")

  if attribute or attribute1 or value:find("Egg", 1, true) then
    local value1 = attribute1 or value
    A = (value1:match("^(.-)%s*%[") or value1):gsub("%s*Egg$", "") .. " Egg"

    return {
      category = "Egg",
      name = A,
      rawName = value,
      rarity = r99 and (r99[A] or r99[value1]) or "Common",
      weight = tonumber(param1:GetAttribute("Weight")) or 1,
    }
  end

  for _, item in ipairs(r113) do
    if item ~= "All Radars" and (value == item or value:find(item, 1, true)) then
      return { category = "Radar", name = value }
    end
  end

  if value:find("Radar", 1, true) then
    return { category = "Radar", name = value }
  end

  for _, item in ipairs(r114) do
    if item ~= "All Foods" and (value == item or value:find(item, 1, true)) then
      return { category = "Food", name = value }
    end
  end

  if param1:HasTag("Food") or FoodsData and FoodsData[value] then
    return { category = "Food", name = value }
  end

  return { category = "Tool", name = value }
end

r121 = function(param1)
  if not (param1 and param1:IsA("Tool")) then
    return
  end

  if r118[param1] then
    return
  end

  r118[param1] = true

  if r119 then
    return
  end

  local value = r120(param1)

  if not value then
    return
  end

  if value.category == "Egg" then
    if not r110.NotifyEggs then
      return
    end

    if not r110.SelectedEggs["All Eggs"]
      and not r110.SelectedEggs[value.name]
      and not r110.SelectedEggs[value.rawName] then
      return
    end

    if not r110.SelectedEggRarities["All Rarities"] and not r110.SelectedEggRarities[value.rarity] then
      return
    end

    if (r110.MinEggWeight or 0) > 0 and (value.weight or 0) < r110.MinEggWeight then
      return
    end

    r117(value)
  elseif value.category == "Radar" then
    if not r110.NotifyRadars then
      return
    end

    if not r110.SelectedRadars["All Radars"] and not r110.SelectedRadars[value.name] then
      return
    end

    r117(value)
  elseif value.category == "Food" then
    if not r110.NotifyFoods then
      return
    end

    if not r110.SelectedFoods["All Foods"] and not r110.SelectedFoods[value.name] then
      return
    end

    r117(value)
  elseif value.category == "Tool" then
    if not r110.NotifyTools then
      return
    end

    r117(value)
  end
end

r122 = {}

r123 = function(param1)
  if not param1 then
    return
  end

  for _, item in ipairs(param1:GetChildren()) do
    if item:IsA("Tool") then
      r118[item] = true
    end
  end

  local connection = param1.ChildAdded:Connect(function(param1)
    task.defer(function()
      r121(param1)
    end)
  end)

  table.insert(r122, connection)
end

rv1 = function()
  for _, item in ipairs(r122) do
    pcall(function()
      item:Disconnect()
    end)
  end

  table.clear(r122)
  local backpack = r15:FindFirstChild("Backpack")

  if backpack then
    r123(backpack)
  end

  if r15.Character then
    r123(r15.Character)
  end

  local connection = r15.CharacterAdded:Connect(function(param1)
    task.wait(0.2)
    r123(param1)
    local backpack = r15:FindFirstChild("Backpack")

    if backpack then
      r123(backpack)
    end
  end)

  table.insert(r122, connection)
end

r124 = rv1
r125 = rv1
rv1()
r125 = task.delay

rv1 = function()
  r119 = false
end

r127 = rv1
r125(1.5, rv1)
r127 = { Title = "Discord Webhook Settings", Icon = "settings" }
r128 = true
r127.Box = r128
r127.BoxBorder = r128
r127.Opened = r128
r126 = r53
r125 = r53:Section(r127)

r128 = {
  Title = "Webhook URL",
  Placeholder = "https://discord.com/api/webhooks/...",
  Value = r110.Url or "",
}

rv1 = function(param1)
  r110.Url = param1 or ""
  r112()
end

r129 = rv1
r128.Callback = rv1
r127 = r125
r125:Input(r128)
r128 = { Title = "Ping Mode" }
r130 = {}
r130[1], r130[2], r130[3], r130[4] = "None", "User ID", "@here", "@everyone"
r129 = r130
r128.Values = r130
r128.Value = r110.PingMode or "None"

rv2 = function(param1)
  r110.PingMode = param1 or "None"
  r112()
end

r129 = rv2
r128.Callback = rv2
r127 = r125
r125:Dropdown(r128)

r128 = {
  Title = "Discord User ID (Optional Ping)",
  Placeholder = "Enter Discord User ID for <@id>",
  Value = r110.UserId or "",
}

rv2 = function(param1)
  r110.UserId = param1 or ""
  r112()
end

r129 = rv2
r128.Callback = rv2
r127 = r125
r125:Input(r128)
r128 = { Title = "Enable Notifications", Value = r110.Enabled or false }

rv2 = function(param1)
  r110.Enabled = param1
  r112()
end

r129 = rv2
r128.Callback = rv2
r127 = r125
r125:Toggle(r128)
r128 = { Title = "Test Webhook", Icon = "send" }

rv1 = function()
  local value = r116({
    category = "Test",
    name = "Test Notification",
    rarity = "Legendary",
    weight = 13.37,
  })

  task.spawn(function()
    local value1, value2 = r115(value)

    if value1 then
      r41("Webhook", "Test webhook sent successfully!", "check", 4)
    else
      r41("Webhook", "Failed: " .. tostring(value2), "triangle-alert", 5)
    end
  end)
end

r129 = rv1
r128.Callback = rv1
r127 = r125
r125:Button(r128)
task.wait(0.08)
r128 = { Title = "Item Filters", Icon = "filter" }
r129 = true
r128.Box = r129
r128.BoxBorder = r129
r128.Opened = r129
r127 = r53
r126 = r53:Section(r128)
r129 = { Title = "Notify on Eggs", Value = r110.NotifyEggs }

rv1 = function(param1)
  r110.NotifyEggs = param1
  r112()
end

r130 = rv1
r129.Callback = rv1
r128 = r126
r126:Toggle(r129)
r127 = {}

for r131, r132 in pairs(r110.SelectedEggs or {}) do
  if r132 then
    r134 = r127
    r135 = r131
    table.insert(r127, r131)
  end
end

if #r127 == 0 then
  r127 = { "All Eggs" }
end

r130 = { Title = "Egg Types Filter", Values = r101, Value = r127 }
r131 = true
r130.Multi = r131
r130.AllowNone = r131

rv2 = function(param1)
  local tbl = {}

  if type(param1) == "table" then
    for _, item in ipairs(param1) do
      tbl[item] = true
    end
  elseif type(param1) == "string" and param1 ~= "" then
    tbl[param1] = true
  end

  if next(tbl) == nil then
    tbl["All Eggs"] = true
  end

  r110.SelectedEggs = tbl
  r112()
end

r131 = rv2
r130.Callback = rv2
r129 = r126
r126:Dropdown(r130)
r128 = {}

for r132, r133 in pairs(r110.SelectedEggRarities or {}) do
  if r133 then
    r135 = r128
    table.insert(r128, r132)
  end
end

if #r128 == 0 then
  r128 = { "All Rarities" }
end

r131 = { Title = "Egg Rarities Filter", Values = r96, Value = r128 }
r132 = true
r131.Multi = r132
r131.AllowNone = r132

rv1 = function(param1)
  local tbl = {}

  if type(param1) == "table" then
    for _, item in ipairs(param1) do
      tbl[item] = true
    end
  elseif type(param1) == "string" and param1 ~= "" then
    tbl[param1] = true
  end

  if next(tbl) == nil then
    tbl["All Rarities"] = true
  end

  r110.SelectedEggRarities = tbl
  r112()
end

r132 = rv1
r131.Callback = rv1
r130 = r126
r126:Dropdown(r131)
r131 = { Title = "Min Egg Weight", Step = 1 }
r133 = { Min = 0, Max = 100, Default = tonumber(r110.MinEggWeight) or 0 }
r132 = r133
r131.Value = r133

rv2 = function(param1)
  r110.MinEggWeight = tonumber(param1) or 0
  r112()
end

r132 = rv2
r131.Callback = rv2
r130 = r126
r126:Slider(r131)
r131 = { Title = "Notify on Radars", Value = r110.NotifyRadars }

rv1 = function(param1)
  r110.NotifyRadars = param1
  r112()
end

r132 = rv1
r131.Callback = rv1
r130 = r126
r126:Toggle(r131)
r129 = {}

for r133, r134 in pairs(r110.SelectedRadars or {}) do
  if r134 then
    r137 = r133
    table.insert(r129, r133)
  end
end

if #r129 == 0 then
  r129 = { "All Radars" }
end

r132 = { Title = "Radar Filter", Values = r113, Value = r129 }
r133 = true
r132.Multi = r133
r132.AllowNone = r133

rv1 = function(param1)
  local tbl = {}

  if type(param1) == "table" then
    for _, item in ipairs(param1) do
      tbl[item] = true
    end
  elseif type(param1) == "string" and param1 ~= "" then
    tbl[param1] = true
  end

  if next(tbl) == nil then
    tbl["All Radars"] = true
  end

  r110.SelectedRadars = tbl
  r112()
end

r133 = rv1
r132.Callback = rv1
r131 = r126
r126:Dropdown(r132)
r132 = { Title = "Notify on Foods", Value = r110.NotifyFoods }

rv1 = function(param1)
  r110.NotifyFoods = param1
  r112()
end

r133 = rv1
r132.Callback = rv1
r131 = r126
r126:Toggle(r132)
r130 = {}

for r134, r135 in pairs(r110.SelectedFoods or {}) do
  if r135 then
    r137 = r130
    r138 = r134
    table.insert(r130, r134)
  end
end

if #r130 == 0 then
  r130 = { "All Foods" }
end

r133 = { Title = "Food Filter", Values = r114, Value = r130 }
r134 = true
r133.Multi = r134
r133.AllowNone = r134

rv2 = function(param1)
  local tbl = {}

  if type(param1) == "table" then
    for _, item in ipairs(param1) do
      tbl[item] = true
    end
  elseif type(param1) == "string" and param1 ~= "" then
    tbl[param1] = true
  end

  if next(tbl) == nil then
    tbl["All Foods"] = true
  end

  r110.SelectedFoods = tbl
  r112()
end

r134 = rv2
r133.Callback = rv2
r132 = r126
r126:Dropdown(r133)
r133 = { Title = "Notify on Other Tools", Value = r110.NotifyTools }

rv2 = function(param1)
  r110.NotifyTools = param1
  r112()
end

r134 = rv2
r133.Callback = rv2
r132 = r126
r126:Toggle(r133)

rv1 = function()
  for _, item in ipairs(r122) do
    pcall(function()
      item:Disconnect()
    end)
  end

  table.clear(r122)
  table.clear(r118)
end

r131 = rv1
r1.LH_WebhookCleanup = rv1
task.wait(0.08)

rv2 = function()
  pcall(function()
    r44:Destroy()
  end)

  r1.LH_Loading = false
end

r110 = rv2
r1.LH_WindowCleanup = rv2
r110 = task.spawn

rv2 = function()
  task.wait(0.6)
  r68 = true
  local flag = false

  if r44.PendingFlags and r70 then
    for key, value in pairs(r44.PendingFlags) do
      r70:Register(key, value)
    end
  end

  if r67 and r70 and r16 and r70.Path and r16(r70.Path) then
    local ok = pcall(function()
      r70:Load()
    end)

    flag = ok

    if ok then
      r41("Config", "Auto save restored", "check", 3)
    end
  end

  if not flag and r64 and r66.enabled and r66.name and r66.name ~= "" then
    r80 = r66.name
    r79 = r66.name

    if pcall(function()
      local value = r64:CreateConfig(r66.name)

      if r44.PendingFlags then
        for key, value1 in pairs(r44.PendingFlags) do
          value:Register(key, value1)
        end
      end

      value:Load()
    end) then
      r41("Config", "Auto-loaded config: " .. r66.name, "check", 3)
    end
  end

  task.delay(0.5, function()
    r68 = false
    r73()
  end)
end

r111 = rv2
r110(rv2)
r110 = r41
r41("Linkhive", "Script loaded successfully!", "check", 4)
r1.LH_Loading = false
r1.LH_Loaded = true
]==], "=RideAPet")(...)
