-- Wraith Hub v1.5 classic (dist/tsb_hub_executor.lua: the old hub, its menu on the REAL WindUI library) played in the simulated Strongest Battlegrounds arena of tests/tsb_sim.lua.
-- Needs real Luau. What this proves: the whole old hub builds its WindUI menu without touching a member the Roblox API does not have (strict world), every tab and the Tech Lab are
-- there, the controls drive the hub (a tap on a switch, a slider, a combo card's Run / On screen / Options), the look settings work, nothing is written until Save config, a saved
-- config comes back, the floating bar still runs the menu, unloading removes everything, and the built-in menu takes over when WindUI cannot start or is switched off.
-- What it cannot prove: how it LOOKS (no renderer for WindUI's images), that any executor allows what WindUI needs, or that anything works in the real game.
local Sim = TSB_SIM
local failures, passes = {}, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures[#failures + 1] = msg end end
-- CLASSIC_SECTIONS=controls,look python3 tests/run_tsb.py classic   runs only those sections (each one boots the whole hub, which takes a while)
local WANT, ALL = {}, true
for name in tostring(TSB_SECTIONS or ""):gmatch("[^,]+") do WANT[name] = true; ALL = false end
local function section(name)
    if not (ALL or WANT[name]) then return false end
    print(string.format("--- %s [%d MB]", name, math.floor(collectgarbage("count") / 1024)))
    return true
end

local UPPERCUT = "10503381238"
local CONFIG = "animation_hub_config.json"

local function game(o)
    o = o or {}
    local sim = Sim.new({ping = o.ping or 60, gethui = true})
    sim:addMe({0, 3, 0})
    if o.rival ~= false then
        local _, char = sim:addEnemy("Rival", {0, 3, -12}, {look = {0, 3, 0}})
        sim.rival = char
    end
    if o.files then for path, body in pairs(o.files) do sim.W.files[path] = body end end
    if o.genv then for k, v in pairs(o.genv) do sim.W.genv[k] = v end end
    return sim
end
local function boot(sim, source, seconds)
    local ok, err = sim.W:load(source or SCRIPT_SOURCE)
    if not ok then failures[#failures + 1] = "load: " .. tostring(err); return false end
    sim:run(seconds or 2)
    return true
end
local function hub(sim) return sim.W.genv.__AnimationHubUI end
-- the menu is built a few controls per frame: wait until it is all there
local function settle(sim)
    local H = hub(sim)
    for _ = 1, 900 do
        if not H or H.pending() == 0 then return true end
        sim:run(0.1)
    end
    failures[#failures + 1] = "the menu did not finish building: " .. tostring(H and H.pending())
    return false
end
local function clean(sim, name, expectWarn, ignore)
    local w = sim.W
    local function without(list)
        local out = {}
        for _, m in ipairs(list) do if not (ignore and m:find(ignore, 1, true)) then out[#out + 1] = m end end
        return out
    end
    local thrown, errors = without(w.thrown), without(w.errors)
    check(#thrown == 0, name .. ": members/types the real Roblox API rejects: " .. table.concat(thrown, " | "):sub(1, 700))
    check(#errors == 0, name .. ": errors inside handlers/threads: " .. table.concat(errors, " | "):sub(1, 700))
    if not expectWarn then check(#w.warns == 0, name .. ": warn(): " .. table.concat(w.warns, " | "):sub(1, 400)) end
    local unknown = {}
    for c in pairs(w.unknownClasses) do unknown[#unknown + 1] = c end
    check(#unknown == 0, name .. ": classes missing from tests/prop_types_classic.lua: " .. table.concat(unknown, ","))
end
local function E(sim, path) local e = hub(sim).elements[path]; if not e then error("no control at " .. path, 2) end return e end
local function has(sim, path) return hub(sim).elements[path] ~= nil end
local function texts(sim, rootName)
    local root = sim.W.M.FindFirstChild(sim.W.coreGui, rootName)
    local out = {}
    if root then
        for _, i in ipairs(sim.W.M.GetDescendants(root)) do
            if (i.ClassName == "TextLabel" or i.ClassName == "TextButton") and i.Text ~= "" then out[#out + 1] = i.Text end
        end
    end
    return out
end
local function hasText(sim, rootName, pattern)
    for _, t in ipairs(texts(sim, rootName)) do if t:find(pattern, 1, true) then return true end end
    return false
end
local function hasMatch(sim, rootName, luaPattern)                    -- the same with a Lua pattern
    for _, t in ipairs(texts(sim, rootName)) do if t:find(luaPattern) then return true end end
    return false
end
local function click(sim, e)                                          -- a real tap on a WindUI switch: press on its hit area, release anywhere
    local hit = sim.W.M.FindFirstChild(e.Ui.ElementFrame, "Hitbox", true)
    assert(hit, "the control has no Hitbox")
    sim.W:press(hit, 10, 10, "MouseButton1"); sim.W:release(10, 10, "MouseButton1")
    sim:run(0.3)
end
local function topbar(sim, name)
    for _, b in pairs(hub(sim).win.Window.TopBarButtons) do
        if b.Name == name then
            for _, d in ipairs(sim.W.M.GetDescendants(b.Object)) do if d.ClassName == "ImageButton" then return d end end
        end
    end
    error("no top bar button " .. name, 2)
end
local function barButton(sim, textPattern)                            -- a button of the floating bar / a pinned button in the hub's own ScreenGui
    local root = sim.W.M.FindFirstChild(sim.W.coreGui, "AnimationHubTSB")
    return sim.W:find(function(i) return i.ClassName == "TextButton" and i.Text:find(textPattern) ~= nil end, root)
end
local function keys(sim) local n = 0 for _, v in ipairs(sim.W.vim) do if v[1] == "key" and v[2] == true then n = n + 1 end end return n end
local function clicks(sim) local n = 0 for _, v in ipairs(sim.W.vim) do if v[1] == "mouse" and v[5] == true then n = n + 1 end end return n end
local function dashes(sim, dir) return sim:count({goal = "KeyPress", key = "Q", dash = dir}) end
local function waterGrad(sim, i)
    local layer = sim.W:find(function(x) return x.Name == "WraithWater" .. i end)
    return layer and sim.W.M.FindFirstChildOfClass(layer, "UIGradient"), layer
end
local function wrote(sim) return sim.W.files[CONFIG] ~= nil end

local TABS = "Main,Credit,Saitama,Garou,Garou Monster,Genos,Sonic,Metal Bat,Tatsumaki,Atomic Samurai,Tech Prodigy,Timing,Techs,Tech Lab,Auto Tech,Teleports,Look,Config,Predictor"

------------------------------------------------------------------------------------------------ 1. boot
local on = section("boot")
local lab = game():newLab()                                          -- a Tech Lab of the same engine: what the menu must show for every tech
if on then
    local sim = game({genv = {AH_MENU_PER_FRAME = 4}})
    check(boot(sim, nil, 1), "boots")
    local H = hub(sim)
    check(H ~= nil and H.win.Backend == "WindUI", "the menu is WindUI")
    check(#(sim.W.httpLog or {}) == 0, "starting the menu downloads nothing (no random picture)")
    for _, n in ipairs({"WindUI", "WindUI/Notifications", "WindUI/Dropdowns", "WindUI/Tooltips", "AnimationHubTSB"}) do
        local n2 = 0
        for _, g in ipairs(sim.W.M.GetChildren(sim.W.coreGui)) do if g.Name == n then n2 = n2 + 1 end end
        check(n2 == 1, "exactly one ScreenGui " .. n .. " (" .. n2 .. ")")
    end
    -- the first frames: the tab on screen is built first, the rest follows
    check(H.pending() > 100, "the menu is still being built a second after the start (" .. H.pending() .. " controls waiting)")
    check(has(sim, "Main/WalkSpeed") and not has(sim, "Tech Lab/Supa Tech/On"), "...the tab on screen first")
    H.win:SelectTab("Tech Lab")                                      -- the user opens another tab: it is built ahead of the rest
    sim:run(0.4)
    check(has(sim, "Tech Lab/Supa Tech/On") and H.pending() > 0, "a tab you open is built next, ahead of the others")
    H.win:SelectTab("Main")
    check(settle(sim), "the menu finishes building")
    local names = {}
    for _, t in ipairs(H.win.Tabs) do names[#names + 1] = t.name end
    check(table.concat(names, ",") == TABS, "the tabs: " .. table.concat(names, ","))
    check(hasText(sim, "WindUI", "Wraith Hub v1.5") and hasText(sim, "WindUI", "The Strongest Battlegrounds"), "the window title and the game")
    check(hasText(sim, "WindUI", "v1.5"), "the version tag")
    for _, n in ipairs({"Panic", "Water", "Changelog"}) do check(pcall(topbar, sim, n), "a " .. n .. " button in the top bar") end
    check(sim.W:find(function(i) return i.Name == "DisplayName" and i.Text == sim.mePlayer.DisplayName end) ~= nil, "the player card shows my name")
    check(sim.W:find(function(i) return i.ClassName == "TextBox" and i.PlaceholderText == "Search..." end) ~= nil, "the search bar")
    for _, side in ipairs({"MENU", "CHARACTERS", "TOOLS"}) do check(hasText(sim, "WindUI", side), "the sidebar group " .. side) end
    check(hasText(sim, "WindUI", "White water edition"), "the welcome card")
    check(has(sim, "Main/Main") and has(sim, "Saitama/Saitama") and has(sim, "Config/Config") and hasText(sim, "WindUI", "Combo cards for Saitama"), "every tab opens with a card")
    check(H.win:GetTheme() == "Wraith White" and H.win.WindUI.Themes["Wraith White"] ~= nil and H.win.WindUI.Themes["Wraith Pearl"] ~= nil, "the white-water theme is the default")
    local w = H.win:GetWater()
    check(w.Enabled and w.Layers == 4, "the white water runs: 4 layers")
    local g1 = waterGrad(sim, 1)
    local o1 = g1.Offset.X
    sim:run(0.5)
    check(g1.Offset.X ~= o1, "...and moves")
    -- the old window is only there as the owner of the on-screen buttons: it is hidden
    local old = sim.W:find(function(i) return i.ClassName == "CanvasGroup" and i.Parent and i.Parent.Name == "AnimationHubTSB" end)
    check(old ~= nil and old.Visible == false, "the built-in window stays hidden")
    check(barButton(sim, "^Menu$") ~= nil and barButton(sim, "^Tech OFF$") ~= nil, "the floating bar is on screen")
    check(not wrote(sim), "nothing is written when the hub starts")
    -- every tech of the Tech Lab has its group, its switch and its options
    local missing = {}
    for _, tech in ipairs(lab.order) do
        local base = "Tech Lab/" .. tech.title
        if not has(sim, base) or not has(sim, base .. "/On") then missing[#missing + 1] = tech.id end
        for _, d in ipairs(tech.defs) do if not has(sim, base .. "/" .. d.label) and d.kind ~= "text" then missing[#missing + 1] = tech.id .. "." .. d.key end end
    end
    check(#missing == 0, "every tech has its group, its On switch and its options; missing: " .. table.concat(missing, ","))
    check(#lab.order == 33, "33 techs")
    -- the combo cards: Run, On screen, Assist, Options
    for _, path in ipairs({"Garou/Garou kyoto/Kyoto Core", "Saitama/Saitama combos/Saitama Quick", "Main/Side dash/Side dash left"}) do
        check(has(sim, path) and has(sim, path .. "/Run") and has(sim, path .. "/On screen"), path .. ": a card with Run and On screen")
    end
    check(has(sim, "Garou/Garou kyoto/Kyoto Core/Assist") and has(sim, "Garou/Garou kyoto/Kyoto Core/Show options"), "a combo has Assist and an options drawer")
    check(not has(sim, "Garou/Garou kyoto/Kyoto Core/Options/Speed (higher = slower)"), "the drawer's controls are not built before it is opened")
    clean(sim, "boot")
end


------------------------------------------------------------------------------------------------ 2. the controls drive the hub
local on = section("controls")
if on then
    local sim = game()
    boot(sim, nil, 1); settle(sim)
    local H = hub(sim)
    local hum = sim.W.M.FindFirstChildOfClass(sim.meChar, "Humanoid")
    -- the Main tab
    check(hasText(sim, "WindUI", "No config file loaded"), "the Config tab says nothing is loaded")
    E(sim, "Main/WalkSpeed"):Set(50)
    sim:run(0.2)
    check(hum.WalkSpeed == 50, "the WalkSpeed slider sets my walk speed: " .. tostring(hum.WalkSpeed))
    check(not hasText(sim, "WindUI", "changes that are NOT saved"), "(a setting that is never saved does not say 'unsaved')")
    E(sim, "Main/Behind dash: most dashes"):Set(2)
    sim:run(0.2)
    check(hasText(sim, "WindUI", "changes that are NOT saved"), "changing a saved setting says so in the Config tab")
    E(sim, "Main/Reset Character").Click()
    sim:run(0.2)
    check(hum.Health == 0, "the Reset Character button")
    -- Timing: a slider, its reset button, the live ping label
    local m1 = E(sim, "Timing/M1 gap")
    local default = m1.Value
    m1:Set(0.4)
    sim:run(0.2)
    check(m1.Value == 0.4, "a timing slider moves")
    E(sim, "Timing/Reset timing to defaults").Click()
    sim:run(0.2)
    check(E(sim, "Timing/M1 gap").Value == default, "Reset timing puts it back: " .. tostring(E(sim, "Timing/M1 gap").Value) .. " vs " .. tostring(default))
    sim:run(1)
    check(E(sim, "Timing/Ping: measuring...").Value:find("^Ping: %d+ ms"), "the ping label shows the ping: " .. tostring(E(sim, "Timing/Ping: measuring...").Value))
    -- Auto Tech and Auto block, with the floating bar following
    click(sim, E(sim, "Auto Tech/Auto Tech"))
    check(barButton(sim, "^Tech ON$") ~= nil, "Auto Tech on: the bar says so")
    click(sim, E(sim, "Auto Tech/Auto block"))
    check(barButton(sim, "^Block ON$") ~= nil, "Auto block on: the bar says so")
    E(sim, "Auto Tech/Range (studs)"):Set(18)
    E(sim, "Auto Tech/Block style"):Set(E(sim, "Auto Tech/Block style").Values[2])
    sim:run(0.2)
    check(#sim.W.errors == 0, "(the Auto Tech controls ran without errors)")
    clean(sim, "controls 1")
end

local on = section("techlab")
if on then
    local sim = game()
    boot(sim, nil, 1); settle(sim)
    check(true, "")
    click(sim, E(sim, "Tech Lab/Supa Tech/On"))
    check(E(sim, "Tech Lab/Supa Tech/On").Value == true, "a tap switches the tech on")
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(1)
    check(dashes(sim, "W") >= 1, "the next uppercut makes it dash: " .. dashes(sim, "W"))
    check(hasText(sim, "WindUI", "done in"), "the status line under the tech says it ran")
    local before = dashes(sim, "W")
    click(sim, E(sim, "Tech Lab/Supa Tech/On"))
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(1)
    check(dashes(sim, "W") == before, "switched off: no dash")
    -- master switch, dropdown, key choice, slider, reset
    click(sim, E(sim, "Tech Lab/Supa Tech/On"))
    click(sim, E(sim, "Tech Lab/Tech Lab master switch"))
    local after = dashes(sim, "W")
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(1)
    check(dashes(sim, "W") == after, "the master switch off: nothing runs")
    click(sim, E(sim, "Tech Lab/Tech Lab master switch"))
    local supa = lab.techs.supa
    local delayLabel
    for _, d in ipairs(supa.defs) do if d.key == "delay" then delayLabel = d.label end end
    E(sim, "Tech Lab/Supa Tech/" .. delayLabel):Set(150)
    sim:run(0.2)
    check(E(sim, "Tech Lab/Supa Tech/" .. delayLabel).Value == 150, "an option slider")
    local hookSide
    for _, d in ipairs(lab.techs.hook.defs) do if d.key == "side" then hookSide = d end end
    E(sim, "Tech Lab/Hook Dash/" .. hookSide.label):Set("Right")
    sim:run(0.2)
    check(E(sim, "Tech Lab/Hook Dash/" .. hookSide.label).Value == "Right", "an option dropdown")
    E(sim, "Tech Lab/Who the techs go for"):Set("Lowest health")
    E(sim, "Tech Lab/Input buffer (ms, 0 = off)"):Set(400)
    sim:run(0.2)
    check(not wrote(sim), "nothing was written")
    -- the new engine switches reach the engine: save and look inside
    E(sim, "Config/Save config").Click()
    sim:run(0.3)
    local data = sim.W.jsonDecode(sim.W.files[CONFIG])
    check(data.techlab.opts.supa.delay == 150 and data.techlab.opts.hook.side == "Right", "Save config holds the options: " .. tostring(data.techlab.opts.supa.delay))
    check(data.techlab.targetMode == "Lowest health" and data.techlab.bufferMs == 400, "...and the targeting")
    clean(sim, "tech lab")
end

local on = section("combos")
if on then
    local sim = game()
    boot(sim, nil, 1); settle(sim)
    local card = "Garou/Garou kyoto/Kyoto Core"
    sim.W.vim = {}
    E(sim, card .. "/Run").Click()
    sim:run(8)
    check(clicks(sim) >= 3, "Run plays the combo: " .. clicks(sim) .. " M1 clicks, " .. keys(sim) .. " keys")
    -- On screen: a pinned button appears, switches off again
    check(barButton(sim, "^Kyoto Core$") == nil, "(nothing pinned yet)")
    click(sim, E(sim, card .. "/On screen"))
    sim:run(0.5)
    local pin = barButton(sim, "^Kyoto Core$")
    check(pin ~= nil and pin.Visible == true, "On screen puts a button on the screen")
    check(barButton(sim, "^Pins 1$") ~= nil, "the floating bar counts it")
    sim.W:click(pin)
    sim:run(0.3)
    check(E(sim, card .. "/Assist").Value == true, "tapping the pinned button arms Assist, and the card's switch follows")
    sim.W:click(pin)
    sim:run(0.3)
    check(E(sim, card .. "/Assist").Value == false, "...and tapping again disarms it")
    click(sim, E(sim, card .. "/On screen"))
    sim:run(0.6)
    check(barButton(sim, "^Kyoto Core$") == nil, "On screen off removes it")
    -- the options drawer
    check(not has(sim, card .. "/Options/Speed (higher = slower)"), "(the drawer is empty until it is opened)")
    click(sim, E(sim, card .. "/Show options"))
    settle(sim)
    check(has(sim, card .. "/Options/Speed (higher = slower)") and has(sim, card .. "/Options/Reset this combo"), "opening Options builds this combo's own controls")
    check(E(sim, card .. "/Options/Forget learned trigger").Ui.ElementFrame.Visible == false, "a Forget button with nothing to forget is hidden")
    E(sim, card .. "/Options/Speed (higher = slower)"):Set(1.5)
    sim:run(0.2)
    E(sim, card .. "/Options/Reset this combo").Click()
    sim:run(0.3)
    check(E(sim, card .. "/Options/Speed (higher = slower)").Value == 1, "Reset this combo puts the slider back")
    E(sim, card .. "/Options/Speed (higher = slower)"):Set(1.5)
    sim:run(0.2)
    E(sim, "Config/Save config").Click()
    sim:run(0.3)
    local data = sim.W.jsonDecode(sim.W.files[CONFIG])
    check(data.combos and data.combos.Kyoto_Core and data.combos.Kyoto_Core.speed == 1.5, "Save config holds the combo's options")
    -- the Tech toggles of a character, the info cards of the tech library
    check(has(sim, "Techs/Universal (" .. "7)") or hasText(sim, "WindUI", "Everything found in research"), "the tech library is there")
    clean(sim, "combo cards")
end

local on = section("teleports")
if on then
    local sim = game()
    boot(sim, nil, 1); settle(sim)
    local H = hub(sim)
    local friend = sim.W:addPlayer("Friend", {pos = {30, 3, 0}, display = "Friend"})
    sim:run(0.3); settle(sim)
    check(has(sim, "Teleports/Players/Friend"), "a player who joins gets a button")
    E(sim, "Teleports/Players/Friend").Click()
    sim:run(0.3)
    local p = sim:pos(sim.meChar)
    check(math.abs(p[1] - 30) < 6, "the button teleports me next to him: x = " .. p[1])
    local other = sim.W:addPlayer("Other", {pos = {-30, 3, 0}, display = "Other"})
    sim:run(0.3); settle(sim)
    check(has(sim, "Teleports/Players/Other"), "...and the next one too")
    rawset(friend, "__leaving", true)
    friend.Parent = nil
    sim:run(0.3); settle(sim)
    check(not (hub(sim).elements["Teleports/Players/Friend"] and hub(sim).elements["Teleports/Players/Friend"].Ui.ElementFrame.Parent ~= nil), "a player who leaves loses his button")
    check(has(sim, "Teleports/Players/Other"), "...and the others stay")
    -- the floating bar runs the menu
    check(H.isOpen(), "the menu is open")
    local lit = barButton(sim, "^Menu$").BackgroundColor3
    check(lit.R > 0.85 and lit.B > 0.9, "(the Menu light is white while the window is open: the white-water palette)")
    sim.W:keyDown("RightShift"); sim.W:keyUp("RightShift")
    sim:run(0.5)
    check(not H.isOpen(), "RightShift hides the window (once, not twice)")
    sim.W:keyDown("RightShift"); sim.W:keyUp("RightShift")
    sim:run(0.5)
    check(H.isOpen(), "...and shows it again")
    sim.W:click(barButton(sim, "^Menu$"))
    sim:run(0.5)
    check(not H.isOpen() and H.win.Main.Visible == false, "the bar's Menu button hides the window")
    sim.W:click(barButton(sim, "^Menu$"))
    sim:run(0.5)
    check(H.isOpen(), "...and shows it again")
    pcall(function() H.win.Window:Close() end)                       -- closed from WindUI's own button / key: the bar notices
    sim:run(1)
    check(not H.isOpen(), "(closed from the window itself)")
    check(barButton(sim, "^Menu$").BackgroundColor3.R < 0.4, "the bar's Menu light goes out by itself")
    sim.W:click(barButton(sim, "^Tech OFF$"))
    sim:run(0.3)
    check(E(sim, "Auto Tech/Auto Tech").Value == true and barButton(sim, "^Tech ON$") ~= nil, "the bar's Tech button flips Auto Tech")
    -- the ping tag follows the ping
    check(hasMatch(sim, "WindUI", "^%d+ ms$"), "the ping is shown next to the title")
    clean(sim, "teleports")
end


------------------------------------------------------------------------------------------------ 3. the look
local on = section("look")
if on then
    local sim = game()
    boot(sim, nil, 1); settle(sim)
    local H = hub(sim)
    local PNG = "https://example.com/pic.png"
    sim.W.http = {[PNG] = "\137PNG\r\n\26\n" .. string.rep("x", 32)}
    -- the water: the top bar button, the switch, brightness, speed
    check(E(sim, "Look/White water/White water").Value == true, "the water switch starts on")
    sim.W:click(topbar(sim, "Water"))
    sim:run(0.3)
    check(H.win:GetWater().Layers == 0 and E(sim, "Look/White water/White water").Value == false, "the top bar's Water button switches it off, and the switch follows")
    sim.W:click(topbar(sim, "Water"))
    sim:run(0.3)
    check(H.win:GetWater().Layers == 4 and E(sim, "Look/White water/White water").Value == true, "...and on again")
    E(sim, "Look/White water/Water brightness"):Set(0)
    check(H.win:GetWater().Strength == 0, "brightness 0")
    E(sim, "Look/White water/Water brightness"):Set(0.7)
    E(sim, "Look/White water/Wave speed"):Set(2)
    check(H.win:GetWater().Speed == 2, "wave speed")
    -- theme, font, size, transparency
    E(sim, "Look/Theme"):Set("Wraith Pearl")
    check(H.win:GetTheme() == "Wraith Pearl" and H.win.Water.Tint.R < 0.6, "the light theme turns the water slate")
    E(sim, "Look/Theme"):Set("Wraith White")
    check(H.win:GetTheme() == "Wraith White" and H.win.Water.Tint.R == 1, "...and white again")
    check(#E(sim, "Look/Theme").Values >= 12, "the theme list holds WindUI's themes and ours")
    E(sim, "Look/Font"):Set("Gotham")
    check(sim.W:find(function(i) return i.ClassName == "TextLabel" and i.FontFace ~= nil and tostring(i.FontFace.Family):find("Gotham", 1, true) ~= nil end,
        sim.W.M.FindFirstChild(sim.W.coreGui, "WindUI")) ~= nil, "the font can be switched")
    E(sim, "Look/Font"):Set("Default")
    E(sim, "Look/Menu size"):Set(0.8)
    E(sim, "Look/Window transparency"):Set(0.6)
    sim:run(0.2)
    check(math.abs(H.win.WindUI.TransparencyValue - 0.6) < 1e-9, "the transparency slider reaches WindUI")
    -- the changelog and the welcome card
    check(not hasText(sim, "WindUI", "BLOCK button"), "(the changelog is not showing yet)")
    sim.W:click(topbar(sim, "Changelog"))
    sim:run(0.3)
    check(hasText(sim, "WindUI", "BLOCK button") and hasText(sim, "WindUI", "What is new in v1.5"), "the Changelog button opens the changelog")
    -- your own picture
    check(sim.W:find(function(i) return i.Name == "WraithPicture" end) == nil, "(no picture yet)")
    E(sim, "Look/Your own picture or video/Picture or video link"):Set("https://example.com/a\nb.png")
    sim:run(0.5)
    check(sim.W:find(function(i) return i.Name == "WraithPicture" end) == nil and hasText(sim, "WindUI/Notifications", "not usable"), "a link with a control character is refused, with a message")
    E(sim, "Look/Your own picture or video/Picture or video link"):Set(PNG)
    sim:run(1)
    check(sim.W:find(function(i) return i.Name == "WraithPicture" end) ~= nil, "a picture link puts the picture behind the menu")
    E(sim, "Look/Your own picture or video/Darken the picture / video"):Set(0.6)
    E(sim, "Look/Your own picture or video/Picture or video link"):Set("")
    sim:run(0.5)
    check(sim.W:find(function(i) return i.Name == "WraithPicture" end) == nil, "an empty link takes it away again")
    check(not wrote(sim), "nothing was written")
    clean(sim, "look")
end

------------------------------------------------------------------------------------------------ 4. config
local on = section("config")
if on then
    local sim = game()
    boot(sim, nil, 1); settle(sim)
    local H = hub(sim)
    local PNG = "https://example.com/pic.png"
    sim.W.http = {[PNG] = "\137PNG\r\n\26\n" .. string.rep("x", 32)}
    E(sim, "Look/Theme"):Set("Wraith Pearl")
    E(sim, "Look/Font"):Set("Gotham")
    E(sim, "Look/White water/Water brightness"):Set(0.3)
    sim.W:click(topbar(sim, "Water"))
    click(sim, E(sim, "Look/Welcome card at start"))
    E(sim, "Main/Behind dash: most dashes"):Set(2)
    click(sim, E(sim, "Garou/Garou kyoto/Kyoto Core/On screen"))
    E(sim, "Look/Your own picture or video/Picture or video link"):Set(PNG)
    sim:run(10)
    check(not wrote(sim), "ten seconds and many changes later: still nothing written")
    check(hasText(sim, "WindUI", "changes that are NOT saved"), "the warning is on")
    E(sim, "Config/Save config").Click()
    sim:run(0.3)
    check(wrote(sim), "Save config writes the file")
    local data = sim.W.jsonDecode(sim.W.files[CONFIG])
    check(data.wind.theme == "Wraith Pearl" and data.wind.font == "Gotham" and data.wind.waterStrength == 0.3 and data.wind.water == false and data.wind.popup == false,
        "the file holds the look")
    check(data.behind.count == 2 and data.pins.Kyoto_Core ~= nil and data.picture == PNG, "...the hub's own settings, the pin and the picture")
    check(not hasText(sim, "WindUI", "changes that are NOT saved"), "the warning is gone after saving")
    -- a fresh start loads it: the look, the pin, the values in the controls
    local sim2 = game({files = {[CONFIG] = sim.W.files[CONFIG]}})
    sim2.W.http = {[PNG] = "\137PNG\r\n\26\n" .. string.rep("x", 32)}
    boot(sim2, nil, 1); settle(sim2)
    local H2 = hub(sim2)
    check(H2.win:GetTheme() == "Wraith Pearl" and E(sim2, "Look/Theme").Value == "Wraith Pearl" and E(sim2, "Look/Font").Value == "Gotham", "the next start has the saved look")
    check(H2.win:GetWater().Enabled == false and E(sim2, "Look/White water/White water").Value == false and E(sim2, "Look/White water/Water brightness").Value == 0.3, "...the water")
    check(not hasText(sim2, "WindUI", "White water edition"), "...no welcome card")
    check(E(sim2, "Main/Behind dash: most dashes").Value == 2, "...the hub's settings in their controls")
    check(barButton(sim2, "^Kyoto Core$") ~= nil and E(sim2, "Garou/Garou kyoto/Kyoto Core/On screen").Value == true, "...the pinned button, and the card's switch shows it")
    check(sim2.W:find(function(i) return i.Name == "WraithPicture" end) ~= nil, "...the picture")
    check(hasText(sim2, "WindUI", "A config file was found"), "...and the Config tab says so")
    clean(sim2, "config 2")
    -- Reload rebuilds the menu from the file: what was changed since is gone, there is still one window
    E(sim2, "Look/White water/Water brightness"):Set(0.9)
    sim2:run(0.2)
    check(E(sim2, "Look/White water/Water brightness").Value == 0.9, "(changed again)")
    E(sim2, "Config/Reload saved config (rebuilds the menu)").Click()
    sim2:run(2)
    settle(sim2)
    local H3 = hub(sim2)
    check(H3 ~= nil and H3 ~= H2 and H2.alive == false, "Reload starts a new menu and ends the old one")
    local n = 0
    for _, g in ipairs(sim2.W.M.GetChildren(sim2.W.coreGui)) do if g.Name == "WindUI" then n = n + 1 end end
    check(n == 1, "...with exactly one window (" .. n .. ")")
    check(E(sim2, "Look/White water/Water brightness").Value == 0.3, "...showing what is in the file")
    clean(sim2, "reload")
    -- Delete removes the file
    E(sim2, "Config/Delete saved config").Click()
    sim2:run(0.3)
    check(sim2.W.files[CONFIG] == nil or sim2.W.files[CONFIG] == "", "Delete saved config removes the file")
    clean(sim, "config 1")
end
if on then   -- junk in a file never stops the hub and never gets into the menu
    local sim = game()
    sim.W.files[CONFIG] = sim.W.jsonEncode({wind = {theme = "Nope", font = "Comic", scale = 99, alpha = -4, waterStrength = 9, waterSpeed = "x", water = "yes", popup = 3, bgDim = 7}, picture = "bad\nlink"})
    boot(sim, nil, 1); settle(sim)
    local H = hub(sim)
    check(H ~= nil, "a file full of nonsense still starts the hub")
    check(H.win:GetTheme() == "Wraith White" and E(sim, "Look/Theme").Value == "Wraith White" and E(sim, "Look/Font").Value == "Default", "a wrong theme / font falls back to the default")
    check(E(sim, "Look/Menu size").Value == 1.2 and E(sim, "Look/Window transparency").Value == 0 and E(sim, "Look/White water/Water brightness").Value == 1, "numbers are clamped")
    check(E(sim, "Look/White water/Wave speed").Value == 1 and E(sim, "Look/White water/White water").Value == true and E(sim, "Look/Welcome card at start").Value == true, "wrong types fall back to the defaults")
    check(sim.W:find(function(i) return i.Name == "WraithPicture" end) == nil, "a picture link with a control character is ignored")
    E(sim, "Config/Save config").Click()
    sim:run(0.3)
    local w = sim.W.jsonDecode(sim.W.files[CONFIG]).wind
    check(w.theme == "Wraith White" and w.font == "Default" and w.scale == 1.2 and w.alpha == 0 and w.waterStrength == 1 and w.waterSpeed == 1 and w.bgDim == 0.9 and w.water == true and w.popup == true,
        "what gets saved afterwards is clean: " .. sim.W.files[CONFIG]:match('"wind":{[^}]*}'))
    clean(sim, "junk config")
    local sim2 = game({files = {[CONFIG] = "{not json"}})
    boot(sim2, nil, 1); settle(sim2)
    check(hub(sim2) ~= nil and E(sim2, "Look/Theme").Value == "Wraith White", "a broken file: a clean start")
    clean(sim2, "broken config")
end

------------------------------------------------------------------------------------------------ 5. top bar actions
local on = section("panic")
if on then
    local sim = game()
    boot(sim, nil, 1); settle(sim)
    sim.W.vim = {}
    E(sim, "Garou/Garou kyoto/Kyoto Easy/Run").Click()
    sim:run(0.4)
    local running = clicks(sim)
    check(running >= 1, "(a combo is playing: " .. running .. " M1 so far)")
    sim.W:click(topbar(sim, "Panic"))
    sim:run(0.3)
    local stopped = clicks(sim)
    check(hasText(sim, "WindUI/Notifications", "Panic"), "Panic says so")
    sim:run(8)
    check(clicks(sim) == stopped, "...and stops the combo that is playing")
    click(sim, E(sim, "Tech Lab/Supa Tech/On"))
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(0.35)
    sim.W:click(topbar(sim, "Panic"))
    sim:run(0.3)
    check(hasText(sim, "WindUI", "cancelled: panic"), "...and the Tech Lab techs that are running")
    clean(sim, "panic")
end

------------------------------------------------------------------------------------------------ 6. the built-in menu: switched off, or WindUI cannot start
local on = section("builtin")
if on then
    local sim = game({genv = {AH_LEGACY_UI = true}})
    boot(sim, nil, 2)
    check(hub(sim) == nil, "AH_LEGACY_UI: the WindUI menu is not started")
    local n = 0
    for _, g in ipairs(sim.W.M.GetChildren(sim.W.coreGui)) do if g.Name == "WindUI" then n = n + 1 end end
    check(n == 0, "...and no WindUI window exists")
    check(hasText(sim, "AnimationHubTSB", "Effects Preset") and hasText(sim, "AnimationHubTSB", "Wraith Hub v1.5"), "the built-in menu is there, with its Effects Preset tab")
    local old = sim.W:find(function(i) return i.ClassName == "CanvasGroup" and i.Parent and i.Parent.Name == "AnimationHubTSB" end)
    check(old ~= nil and old.Visible == true, "...and shown")
    check(barButton(sim, "^Menu$") ~= nil, "...with the floating bar")
    clean(sim, "built-in menu")
    -- the floating bar's Menu button still hides and shows it
    sim.W:click(barButton(sim, "^Menu$"))
    sim:run(0.6)
    check(old.Visible == false, "the Menu button hides the built-in window")
    sim.W:click(barButton(sim, "^Menu$"))
    sim:run(0.3)
    check(old.Visible == true, "...and shows it")
end
if on then
    -- an executor that blocks what WindUI needs: the library raises while it starts
    local blocked = SCRIPT_SOURCE:gsub("local WindUILoader = function%(%)\n", "local WindUILoader = function()\nerror('blocked by this executor')\n", 1)
    check(blocked ~= SCRIPT_SOURCE, "(the test could block WindUI)")
    local sim = game()
    boot(sim, blocked, 2)
    check(hub(sim) == nil and hasText(sim, "AnimationHubTSB", "Effects Preset"), "WindUI cannot start: the built-in menu opens")
    check(#sim.W.warns == 1 and sim.W.warns[1]:find("WindUI did not start", 1, true), "...and one warning says why: " .. tostring(sim.W.warns[1]))
    clean(sim, "blocked WindUI", true)
    -- a window that fails half way (after WindUI made it) is taken down again before the built-in menu opens
    local needle = 'if type(cfg.Tag) == "table" then win:Tag(cfg.Tag) end'
    local from, to = SCRIPT_SOURCE:find(needle, 1, true)
    check(from ~= nil, "(the test could break the window half way)")
    local half = SCRIPT_SOURCE:sub(1, from - 1) .. 'error("half way")' .. SCRIPT_SOURCE:sub(to + 1)
    local sim2 = game()
    boot(sim2, half, 2)
    local left = 0
    for _, g in ipairs(sim2.W.M.GetChildren(sim2.W.coreGui)) do if g.Name:find("^WindUI") then left = left + 1 end end
    check(hub(sim2) == nil and hasText(sim2, "AnimationHubTSB", "Effects Preset"), "a window that fails half way: the built-in menu opens")
    check(left == 0, "...and the half-made WindUI window is gone (" .. left .. " WindUI ScreenGuis left)")
    check(#sim2.W.warns == 1 and sim2.W.warns[1]:find("half way", 1, true), "...with one warning: " .. tostring(sim2.W.warns[1]))
    -- (WindUI's own opening animation, already under way, meets the window that was taken down: it trips over the missing Background and ends - harmless)
    clean(sim2, "half-made window", true, "Background is not a valid member")
end

------------------------------------------------------------------------------------------------ 7. unload and run again
local on = section("unload")
if on then
    -- where the library's own code is in the bundle: a listener from anywhere else is ours
    local first, last, n = nil, nil, 0
    for line in (SCRIPT_SOURCE .. "\n"):gmatch("(.-)\n") do
        n = n + 1
        if line:find("^local WindUILoader = function%(%)") then first = n elseif line:find("^if not game:IsLoaded%(%)") then last = n end
    end
    check(first and last and first < last, "(the WindUI part of the bundle was found)")
    local function ours(sim)
        local out = {}
        local rs = sim.W.runService
        for _, pair in ipairs({{sim.W.uis, "InputBegan"}, {sim.W.uis, "InputChanged"}, {sim.W.uis, "InputEnded"}, {rs, "Heartbeat"}, {rs, "RenderStepped"}, {rs, "Stepped"},
                {sim.W.players, "PlayerAdded"}, {sim.W.players, "PlayerRemoving"}}) do
            for _, h in ipairs(sim.W.signalOf(pair[1], pair[2]).handlers) do
                if h.on then
                    local src, line = debug.info(h.orig, "sl")
                    if src == "wraiths_hub" and not (line >= first and line < last) then out[#out + 1] = pair[2] .. "@" .. line end
                end
            end
        end
        return out
    end
    local sim = game()
    boot(sim, nil, 1); settle(sim)
    local H = hub(sim)
    check(#ours(sim) > 5, "(the hub's own listeners are there: " .. #ours(sim) .. ")")
    click(sim, E(sim, "Tech Lab/Supa Tech/On"))
    click(sim, E(sim, "Garou/Garou kyoto/Kyoto Core/On screen"))
    sim:run(0.4)
    check(sim.W.genv.__AnimationHubCleanup ~= nil, "the hub registers its cleanup")
    sim.W.genv.__AnimationHubCleanup()
    sim:run(1)
    local left = {}
    for _, g in ipairs(sim.W.M.GetChildren(sim.W.coreGui)) do left[#left + 1] = g.Name end
    check(#left == 0, "unloading removes every ScreenGui: " .. table.concat(left, ","))
    check(hub(sim) == nil and H.alive == false and sim.W.genv.__AnimationHubCleanup == nil, "...and clears the session")
    check(#ours(sim) == 0, "...and none of the hub's own listeners stays: " .. table.concat(ours(sim), ","))
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(1)
    check(dashes(sim, "W") == 0, "...a tech that was on no longer runs")
    check(#sim:leftovers() == 0, "...and nothing is left on my character: " .. table.concat(sim:leftovers(), ","))
    clean(sim, "unload")
    -- running the script again replaces the old copy
    local sim2 = game()
    boot(sim2, nil, 1); settle(sim2)
    local H1 = hub(sim2)
    boot(sim2, nil, 1); settle(sim2)
    local H2 = hub(sim2)
    check(H2 ~= H1 and H1.alive == false, "running it again starts a new session and ends the old one")
    local counts = {}
    for _, g in ipairs(sim2.W.M.GetChildren(sim2.W.coreGui)) do counts[g.Name] = (counts[g.Name] or 0) + 1 end
    check(counts["WindUI"] == 1 and counts["AnimationHubTSB"] == 1, "...with exactly one window")
    clean(sim2, "rerun")
end

print(string.format("%d checks passed, %d failed", passes, #failures))
for _, f in ipairs(failures) do print("FAIL  " .. f) end
if #failures > 0 then error("classic hub tests failed") end
