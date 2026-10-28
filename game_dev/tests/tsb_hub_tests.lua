-- Wraith's TSB Lab (dist/tsb_lab.lua) on the REAL WindUI library, played in the simulated Strongest Battlegrounds arena of tests/tsb_sim.lua. Needs real Luau.
-- What this proves: the library builds the whole menu without touching a member the Roblox API does not have; the controls drive the Tech Lab (a click on a toggle
-- switches a tech on and the next uppercut makes it dash); nothing is written to disk until Save config; a saved config comes back; the on-screen buttons work;
-- unloading removes everything. What it cannot prove: how it LOOKS (no renderer for WindUI's 9-slice images), that any executor allows what WindUI needs, or that any
-- tech works in the real game.
local Sim = TSB_SIM
local failures, passes = {}, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures[#failures + 1] = msg end end
local function section(name) print(string.format("--- %s [%d MB]", name, math.floor(collectgarbage("count") / 1024))) end

local UPPERCUT, FORWARD = "10503381238", "10479335397"

local function game(o)
    o = o or {}
    local sim = Sim.new({ping = o.ping or 60, gethui = true, animMode = o.animMode})
    sim:addMe({0, 3, 0})
    if o.rival ~= false then
        local _, char = sim:addEnemy("Rival", {0, 3, -12}, {look = {0, 3, 0}})
        sim.rival = char
    end
    if o.files then for path, body in pairs(o.files) do sim.W.files[path] = body end end
    return sim
end
local function boot(sim, source, seconds)
    local ok, err = sim.W:load(source or SCRIPT_SOURCE)
    if not ok then failures[#failures + 1] = "load: " .. tostring(err); return false end
    sim:run(seconds or 4)
    return true
end
local function clean(sim, name)
    local w = sim.W
    check(#w.thrown == 0, name .. ": members/types the real Roblox API rejects: " .. table.concat(w.thrown, " | "):sub(1, 700))
    check(#w.errors == 0, name .. ": errors inside handlers/threads: " .. table.concat(w.errors, " | "):sub(1, 700))
    check(#w.warns == 0, name .. ": warn(): " .. table.concat(w.warns, " | "):sub(1, 400))
    local unknown = {}
    for c in pairs(w.unknownClasses) do unknown[#unknown + 1] = c end
    check(#unknown == 0, name .. ": classes missing from tests/prop_types_tsb_hub.lua: " .. table.concat(unknown, ","))
end
local function hub(sim) return sim.W.genv.__TSBLab end
local function el(sim, flag) local e = hub(sim).Win.Flags[flag]; if not e then error("no element with the flag " .. flag, 2) end return e end
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
local function click(sim, e)                                          -- a real tap on a WindUI toggle: press on its hit area, release anywhere
    local hit = sim.W.M.FindFirstChild(e.Ui.ElementFrame, "Hitbox", true)
    assert(hit, "toggle has no Hitbox")
    sim.W:press(hit, 10, 10, "MouseButton1"); sim.W:release(10, 10, "MouseButton1")
    sim:run(0.3)
end
local function wroteTSB(sim) for path in pairs(sim.W.files) do if path:find("^TSBLab/") then return true end end return false end
local function dashes(sim, dir) return sim:count({goal = "KeyPress", key = "Q", dash = dir}) end

------------------------------------------------------------------------------------------------ 1. boot
section("boots on WindUI")
do
    local sim = game()
    check(boot(sim), "boots")
    local H = hub(sim)
    check(H ~= nil and H.Win and H.Win.Backend == "WindUI", "the WindUI backend is in use")
    check(H and H.Lab ~= nil, "the Tech Lab engine is running")
    for _, n in ipairs({"WindUI", "WindUI/Notifications", "WindUI/Dropdowns", "WindUI/Tooltips", "WraithsTSBLab_Buttons"}) do
        local n2 = 0
        for _, g in ipairs(sim.W.M.GetChildren(sim.W.coreGui)) do if g.Name == n then n2 = n2 + 1 end end
        check(n2 == 1, "exactly one ScreenGui " .. n .. " (" .. n2 .. ")")
    end
    check(hasText(sim, "WindUI", "Wraith's TSB Lab"), "the window title")
    check(hasText(sim, "WindUI", "The Strongest Battlegrounds"), "the window subtitle names the game")
    check(hasText(sim, "WindUI/Notifications", "Wraith's TSB Lab loaded"), "welcome toast")
    -- one tab per tech family, laid out like the tech hub it came from
    local names = {}
    for _, t in ipairs(H.Win.Tabs) do names[#names + 1] = t.name end
    check(table.concat(names, ",") == "Overview,Supa,Hook Dash,Loop Dash,Kiba / Kitty,Kyoto Combo,Lethal Dash,Twisted,M1 Reset,Cancels,Auto Counter,Tech Helper,Awareness,Settings",
        "the tabs: " .. table.concat(names, ","))
    -- every tech sits in exactly one tab and has its switch
    local seen = {}
    for _, t in ipairs(H.Tabs) do for _, id in ipairs(t[4]) do seen[id] = (seen[id] or 0) + 1 end end
    local missing, twice = {}, {}
    for _, tech in ipairs(H.Lab.order) do
        if not seen[tech.id] then missing[#missing + 1] = tech.id elseif seen[tech.id] > 1 then twice[#twice + 1] = tech.id end
        check(H.Win.Flags[tech.id .. ".on"] ~= nil, tech.id .. ": has an Enable switch")
        for _, d in ipairs(tech.defs) do check(H.Win.Flags[tech.id .. "." .. d.key] ~= nil, tech.id .. "." .. d.key .. ": has a control") end
    end
    check(#missing == 0 and #twice == 0, "every tech in exactly one tab; missing: " .. table.concat(missing, ",") .. " twice: " .. table.concat(twice, ","))
    check(#H.Lab.order == 33, "33 techs")
    local function hasImage(id) return sim.W:find(function(i) return i.ClassName == "ImageLabel" and i.Image == id end) ~= nil end
    check(hasImage(LUCIDE_IDS["sword"]) and hasImage(LUCIDE_IDS["wrench"]) and hasImage(LUCIDE_IDS["settings"]), "the tab icons come from the built-in Lucide set")
    check(#(sim.W.httpLog or {}) == 0, "starting the menu fetches nothing from the web")
    check(H.Win:GetTheme() == "Frost" and H.Win.WindUI.Themes.Frost ~= nil and H.Win.WindUI.Themes.Ember ~= nil and H.Win.WindUI.Themes.Mint ~= nil, "its own colours are registered and Frost is the default")
    check(H.Win.WindUI.Themes.Frost.Toggle.B > 0.9 and H.Win.WindUI.Themes.Frost.ElementBackgroundTransparency >= 0.4, "(a cyan accent, frosted cards)")
    check(el(sim, "theme").Values[1] ~= nil and #el(sim, "theme").Values >= 13, "the theme list holds WindUI's themes and ours")
    el(sim, "theme"):Set("Ember")
    check(H.Win:GetTheme() == "Ember" and H.S.theme == "Ember", "a theme can be switched")
    el(sim, "theme"):Set("Frost")
    check(H.Win.Main.Visible == true, "the window is open")
    check(H.Win.Tabs[1].ui.Selected == true, "the Overview tab is selected")
    -- everything is off until the user switches it on
    local on = {}
    for _, tech in ipairs(H.Lab.order) do if tech.enabled then on[#on + 1] = tech.id end end
    check(#on == 0, "all techs start off: " .. table.concat(on, ","))
    check(not wroteTSB(sim), "nothing is written when the hub starts")
    -- the PANIC button is there, the rest are hidden until asked for
    local panic = sim.W:find(function(i) return i.Name == "Float_panic" end)
    check(panic and panic.Visible == true, "the PANIC button is visible")
    local hook = sim.W:find(function(i) return i.Name == "Float_hook" end)
    check(hook and hook.Visible == false, "the HOOK button is hidden until it is switched on")
    clean(sim, "boot")
end

local function button(sim, title)
    for _, e in ipairs(hub(sim).Win.Elements) do if e.Title == title then return e end end
    error("no button titled " .. title, 2)
end
local function tapFloat(sim, id) sim.W:tap(sim.W:button("Float_" .. id), 100, 100); sim:run(0.2) end
local function statusOf(sim, id) return hub(sim).Lab.techs[id].status end

------------------------------------------------------------------------------------------------ 2. the controls drive the techs
section("controls")
do
    local sim = game()
    boot(sim)
    local H = hub(sim)
    click(sim, el(sim, "supa.on"))
    check(H.Lab.techs.supa.enabled == true, "a real click on 'Enable Supa Tech' switches the tech on")
    check(hasText(sim, "WindUI", "NOT saved"), "...and the config status warns about unsaved changes")
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(0.2)
    check(dashes(sim, "W") == 0, "(it waits its 320 ms)")
    sim:run(1)
    check(dashes(sim, "W") >= 1, "the uppercut makes the hub's Supa dash")
    check(statusOf(sim, "supa"):find("done") and hasText(sim, "WindUI", "Status: done"), "the status label in the menu follows the tech: " .. statusOf(sim, "supa"))
    -- sliders, dropdowns, switches, text boxes and key binds change the options
    el(sim, "supa.delay"):Set(100)
    check(H.Lab.techs.supa.opt.delay == 100, "a slider sets an option")
    el(sim, "hook.side"):Set("Left")
    check(H.Lab.techs.hook.opt.side == "Left", "a dropdown sets an option")
    el(sim, "loop2.jump"):Set(false)
    check(H.Lab.techs.loop2.opt.jump == false, "a switch sets an option")
    el(sim, "kyoto.moveName"):Set("Some Move")
    check(H.Lab.techs.kyoto.opt.moveName == "Some Move", "a text box sets an option")
    el(sim, "m1reset.key"):Set("Y")
    check(H.Lab.techs.m1reset.opt.key == "Y", "a key bind sets the key")
    el(sim, "m1reset.on"):Set(true)
    sim:place(sim.meChar, {0, 3, 0})                                   -- (Supa left me facing the other way)
    local x0 = sim:pos(sim.meChar)[1]
    sim.W:keyDown("Y")
    sim:run(0.6)
    check(sim:pos(sim.meChar)[1] - x0 > 20, "...and the new key runs M1 Reset: " .. (sim:pos(sim.meChar)[1] - x0))
    el(sim, "m1reset.key"):Set("not a key!")
    check(H.Lab.techs.m1reset.opt.key == "Y", "a key name that is no key name is refused")
    -- Reset puts a tech back
    button(sim, "Reset Supa Tech to its defaults").Click()
    check(H.Lab.techs.supa.opt.delay == 320 and el(sim, "supa.delay").Value == 320, "the reset button restores the options and moves the slider")
    -- learn trigger
    button(sim, "Learn trigger: play the move that should start Supa Tech").Click()
    sim:anim(sim.meChar, "999777", 0.3)
    check(H.Lab.techs.supa.ids["999777"] == true, "Learn trigger takes the next animation")
    button(sim, "Forget the triggers I taught Supa Tech").Click()
    check(not H.Lab.techs.supa.ids["999777"], "...and forgets it")
    -- the master switch and the panic button
    el(sim, "master"):Set(false)
    check(H.Lab.master == false, "the master switch")
    el(sim, "master"):Set(true)
    el(sim, "input"):Set("Keys")
    check(H.Lab.input == "Keys", "the input mode")
    el(sim, "input"):Set("Auto")
    el(sim, "net.strength"):Set(0.5); el(sim, "net.manual"):Set(120); el(sim, "net.interp"):Set(100); el(sim, "net.ref"):Set(80); el(sim, "net.learn"):Set(false)
    local n = H.Lab.net
    check(n.strength == 0.5 and n.manual == 120 and n.interp == 100 and n.ref == 80 and n.learn == false, "the ping settings reach the engine")
    sim:run(0.6)
    check(hasText(sim, "WindUI", "Ping 120 ms"), "the ping panel shows the typed ping")
    check(not wroteTSB(sim), "nothing was written to disk by any of this")
    clean(sim, "controls")
end

------------------------------------------------------------------------------------------------ 3. config
section("config")
do
    local sim = game()
    boot(sim)
    local H = hub(sim)
    check(hasText(sim, "WindUI", "No config loaded"), "the status line says nothing is loaded")
    el(sim, "supa.on"):Set(true)
    el(sim, "supa.delay"):Set(150)
    el(sim, "hook.side"):Set("Right")
    el(sim, "m1reset.key"):Set("Y")
    H.Lab:learnTrigger("supa"); sim:anim(sim.meChar, "424242", 0.3)
    el(sim, "theme"):Set("Violet")
    sim:run(10)
    check(not wroteTSB(sim), "ten seconds and many changes later: still nothing written")
    check(hasText(sim, "WindUI", "NOT saved"), "the warning is on")
    button(sim, "Save config").Click()
    sim:run(0.3)
    check(sim.W.files["TSBLab/default.json"] ~= nil and sim.W.files["TSBLab/index.json"] ~= nil, "Save config writes the config and the index")
    local data = sim.W.jsonDecode(sim.W.files["TSBLab/default.json"])
    check(data.techlab.enabled.supa == true and data.techlab.opts.supa.delay == 150 and data.techlab.opts.hook.side == "Right" and data.techlab.opts.m1reset.key == "Y",
        "the file holds the switches and options")
    check(data.techlab.triggers.supa[1] == "424242", "...and the learned trigger")
    check(data.ui.theme == "Violet", "...and the menu theme")
    check(sim.W.jsonDecode(sim.W.files["TSBLab/index.json"]).autoload == false, "Auto load was off when it was saved")
    check(not hasText(sim, "WindUI", "NOT saved") and hasText(sim, "WindUI", "'default' is loaded"), "the status line is clean after saving")
    check(hasText(sim, "WindUI/Notifications", "Config saved"), "a toast says so")
    -- a fresh start does NOT load it (Auto load was off) - and the session registry is clean
    local sim2 = game({files = {["TSBLab/default.json"] = sim.W.files["TSBLab/default.json"], ["TSBLab/index.json"] = sim.W.files["TSBLab/index.json"]}})
    boot(sim2)
    check(hub(sim2).Lab.techs.supa.enabled == false and hub(sim2).Lab.techs.supa.opt.delay == 320, "Auto load off: a new start is clean even though the file exists")
    -- ...the Load button applies it live
    button(sim2, "Load config (rebuilds nothing - applies live)").Click()
    sim2:run(0.3)
    local L2 = hub(sim2).Lab
    check(L2.techs.supa.enabled and L2.techs.supa.opt.delay == 150 and L2.techs.hook.opt.side == "Right" and L2.techs.m1reset.opt.key == "Y" and L2.techs.supa.ids["424242"], "Load applies the file")
    check(el(sim2, "supa.on").Value == true and el(sim2, "supa.delay").Value == 150 and el(sim2, "hook.side").Value == "Right" and el(sim2, "m1reset.key").Value == "Y",
        "...and the controls follow")
    check(hub(sim2).Win:GetTheme() == "Violet", "...and the theme")
    -- Auto load on when saving: the next start loads it
    el(sim2, "autoLoad"):Set(true)
    button(sim2, "Save config").Click()
    sim2:run(0.3)
    check(sim2.W.jsonDecode(sim2.W.files["TSBLab/index.json"]).autoload == true, "Auto load on: the index says so")
    local sim3 = game({files = {["TSBLab/default.json"] = sim2.W.files["TSBLab/default.json"], ["TSBLab/index.json"] = sim2.W.files["TSBLab/index.json"]}})
    boot(sim3)
    local L3 = hub(sim3).Lab
    check(L3.techs.supa.enabled and L3.techs.supa.opt.delay == 150 and el(sim3, "supa.on").Value == true, "the next start loads it by itself")
    check(hasText(sim3, "WindUI", "'default' is loaded"), "...and says so")
    sim3:anim(sim3.meChar, UPPERCUT, 0.5)
    sim3:run(1)
    check(dashes(sim3, "W") >= 1, "the loaded Supa works")
    -- names are cleaned, delete removes the file
    el(sim3, "configName"):Set("../my evil/cfg!")
    check(hub(sim3).S.configName == "my evilcfg", "a config name can not climb out of the folder: " .. hub(sim3).S.configName)
    button(sim3, "Save config").Click()
    sim3:run(0.2)
    check(sim3.W.files["TSBLab/my evilcfg.json"] ~= nil, "saved under the cleaned name")
    button(sim3, "Delete config").Click()
    check(sim3.W.files["TSBLab/my evilcfg.json"] == nil, "Delete removes the file")
    clean(sim, "config"); clean(sim2, "config 2"); clean(sim3, "config 3")
end
do   -- broken files never stop the hub
    local sim = game({files = {["TSBLab/index.json"] = "{not json", ["TSBLab/default.json"] = "[[["}})
    boot(sim)
    check(hub(sim) ~= nil and hub(sim).Lab.techs.supa.enabled == false, "a broken index: clean start")
    local junk = '{"ui":{"theme":"Nope","uiScale":99,"uiKey":"bad key!","waves":"Maybe","btnSize":-5},"floats":{"panic":{"x":"a","y":7,"visible":"yes"},"ghost":{"x":1}},'
        .. '"techlab":{"enabled":{"ghost":true,"supa":"yes"},"opts":{"supa":{"delay":-5,"radius":"x"}},"net":{"manual":1e9},"triggers":{"supa":["12","bad"]}}}'
    local sim2 = game({files = {["TSBLab/index.json"] = '{"autoload":true,"name":"junk"}', ["TSBLab/junk.json"] = junk}})
    boot(sim2)
    local H = hub(sim2)
    check(H ~= nil and H.S.theme == "Frost" and H.S.uiScale == 1.2 and H.S.uiKey == "RightShift" and H.S.waves == "High" and H.S.btnSize == 56, "invalid menu values fall back or are clamped: "
        .. tostring(H and H.S.theme) .. " " .. tostring(H and H.S.uiScale))
    check(H and H.Lab.techs.supa.enabled == false and H.Lab.techs.supa.opt.delay == 0 and H.Lab.net.manual == 1000 and H.Lab.techs.supa.ids["12"] and not H.Lab.techs.supa.ids["bad"], "invalid tech values are cleaned")
    clean(sim, "broken config"); clean(sim2, "junk config")
end

------------------------------------------------------------------------------------------------ 4. the on-screen buttons
section("on-screen buttons")
do
    local sim = game({rival = false})
    sim:addEnemy("Rival", {6, 3, -20}, {look = {0, 3, 0}})
    boot(sim)
    local H = hub(sim)
    el(sim, "hook.on"):Set(true)
    el(sim, "float.hook"):Set(true)
    local f = sim.W:button("Float_hook")
    check(f.Visible == true, "switching the button on shows it")
    sim.mouseHit = sim.W.env.CFrame.new(5, 3, -19)
    sim.W:keyDown("V")
    check(H.Lab:hookTarget() ~= nil, "V picks the target")
    local x0 = sim:pos(sim.meChar)[1]
    tapFloat(sim, "hook")
    sim:run(1.2)
    check(H.Lab.techs.hook.stats.runs == 1 and dashes(sim, "D") == 1, "tapping the HOOK button runs the hook dash")
    check(sim:pos(sim.meChar)[1] - x0 > 4, "...and it moved me")
    H.Lab:hookClear()
    -- PANIC cancels a running tech
    sim:give(sim.mePlayer, "Lethal Whirlwind Stream")
    el(sim, "kyoto.on"):Set(true)
    sim:anim(sim.meChar, "12273188754", 0.5)
    sim:run(0.5)
    check(H.Lab.techs.kyoto.running, "(Kyoto is waiting)")
    tapFloat(sim, "panic")
    check(not H.Lab.techs.kyoto.running and statusOf(sim, "kyoto"):find("panic"), "the PANIC button cancels it: " .. statusOf(sim, "kyoto"))
    sim:run(2)
    check(sim:count({goal = "Console Move"}) == 0, "...for good")
    -- a button can be dragged and keeps its place in the config
    sim.W:drag(sim.W:button("Float_hook"), 100, 100, 300, 200)
    sim:run(0.2)
    local px = H.S.floats.hook.x
    check(px >= 0 and px <= 1, "the new position is remembered in the settings: " .. tostring(px))
    button(sim, "Save config").Click()
    sim:run(0.2)
    local saved = sim.W.jsonDecode(sim.W.files["TSBLab/default.json"])
    check(saved.floats.hook.visible == true and saved.floats.hook.x >= 0 and saved.floats.panic.visible == true, "the config keeps which buttons are on and where")
    el(sim, "btnLock"):Set(true)
    check(sim.W:button("Float_panic") ~= nil, "(buttons still there)")
    el(sim, "btnSize"):Set(100)
    check(H.S.btnSize == 100, "the size slider")
    clean(sim, "buttons")
end

------------------------------------------------------------------------------------------------ the ping model inside the hub
section("ping in the hub")
do
    local sim = game({ping = 160, animMode = "server"})
    boot(sim)
    local H = hub(sim)
    for _ = 1, 3 do                                                     -- three dashes: the hub learns how late the server-played animations arrive
        sim.dashReadyAt = {}
        H.Lab:dash("W")
        sim:run(0.5)
    end
    H.Lab.dashClock:reset(); sim.dashReadyAt = {}; sim:clearLog()
    check(H.Lab:netInfo().lag and math.abs(H.Lab:netInfo().lag - 0.16) < 0.02, "the hub measured the animation lag: " .. tostring(H.Lab:netInfo().lag))
    sim:run(0.5)
    check(hasText(sim, "WindUI", "arrive 160 ms after my input") or hasText(sim, "WindUI", "arrive 16"), "the Overview shows it")
    check(hasText(sim, "WindUI", "Ping 160 ms"), "...and the ping")
    el(sim, "supa.on"):Set(true)
    local _, S0 = sim:press(UPPERCUT, 0.5)
    sim:run(1.2)
    local first
    for _, r in ipairs(sim.log) do if r.goal == "KeyPress" and r.key == "Q" and r.dash == "W" then first = r; break end end
    check(first and math.abs((first.arrive - S0) - 0.32) < 0.03, "Supa reaches the server 320 ms after the uppercut did, at ping 160 (" .. tostring(first and first.arrive - S0) .. ")")
    el(sim, "net.strength"):Set(0)
    sim.dashReadyAt = {}; H.Lab.dashClock:reset(); H.Lab.techs.supa.cooldownUntil = 0; sim:clearLog()
    local _, S1 = sim:press(UPPERCUT, 0.5)
    sim:run(1.2)
    local second
    for _, r in ipairs(sim.log) do if r.goal == "KeyPress" and r.key == "Q" and r.dash == "W" then second = r; break end end
    check(second and math.abs((second.arrive - S1) - 0.48) < 0.03, "with the compensation slider at 0 it is a whole ping late (" .. tostring(second and second.arrive - S1) .. ")")
    clean(sim, "ping in the hub")
end

------------------------------------------------------------------------------------------------ 5. unload, rerun, fallback
section("unload")
do
    local sim = game()
    boot(sim)
    local H = hub(sim)
    el(sim, "supa.on"):Set(true)
    local function guis() local n = 0 for _, g in ipairs(sim.W.M.GetChildren(sim.W.coreGui)) do n = n + 1 end return n end
    check(guis() >= 5, "(several ScreenGuis exist: " .. guis() .. ")")
    boot(sim, nil, 4)                                                  -- running the script again replaces the old copy
    check(hub(sim) ~= H, "running it again starts a new session")
    check(H.Alive == false, "...and the old one is over")
    local H2 = hub(sim)
    local counts = {}
    for _, g in ipairs(sim.W.M.GetChildren(sim.W.coreGui)) do counts[g.Name] = (counts[g.Name] or 0) + 1 end
    check(counts["WindUI"] == 1 and counts["WraithsTSBLab_Buttons"] == 1, "...with exactly one window")
    el(sim, "counteresp.on"):Set(true)
    sim:anim(sim.rival, "12351854556", 6)                              -- somebody counters: he is highlighted
    sim:run(0.2)
    check(#sim:leftovers() == 1 and sim:leftovers()[1] == "Highlight:TechLabMark", "(a highlight is on him)")
    button(sim, "Unload the script").Click()
    sim:run(0.5)
    check(#sim:leftovers() == 0, "Unload removes the highlights too")
    check(hub(sim) == nil, "Unload clears the session")
    check(guis() == 0, "...removes every ScreenGui (" .. guis() .. " left)")
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(1)
    check(dashes(sim, "W") == 0, "...and every tech: an uppercut no longer dashes")
    check(H2.Alive == false, "the session says it is over")
    -- WindUI keeps a few input listeners of its own after its window is destroyed (library behaviour; they act on destroyed instances only): ours are all gone
    local left = sim:connected(sim.W.signalOf(sim.W.uis, "InputBegan")) + sim:connected(sim.W.signalOf(sim.W.uis, "InputChanged")) + sim:connected(sim.W.signalOf(sim.W.uis, "InputEnded"))
    check(left <= 40, "after unloading (twice) only the library's own listeners remain (" .. left .. ")")
    check(sim:connected(sim.W.signalOf(sim.W.runService, "Heartbeat")) == 0 and sim:connected(sim.W.signalOf(sim.mePlayer, "CharacterAdded")) == 0, "no Heartbeat / CharacterAdded listener of ours is left")
    clean(sim, "unload")
end
do   -- WindUI cannot start: the small built-in menu takes over and the techs still work
    local source = SCRIPT_SOURCE:gsub("local WindUILoader = function%(%)", "local WindUILoader = function() error('blocked by the executor') end\nlocal __unused = function()", 1)
    local sim = game()
    boot(sim, source)
    local H = hub(sim)
    check(H and H.Win and H.Win.Backend ~= "WindUI", "the classic menu is used when WindUI fails")
    check(H and #H.Win.Tabs == 14, "...with the same tabs: " .. tostring(H and #H.Win.Tabs))
    check(hasText(sim, "WraithsTSBLab", "Overview"), "the classic window shows them")
    el(sim, "supa.on"):Set(true)
    sim:anim(sim.meChar, UPPERCUT, 0.5)
    sim:run(1)
    check(dashes(sim, "W") >= 1, "the techs work there too")
    clean(sim, "fallback")
end

------------------------------------------------------------------------------------------------ done
print(string.format("\n%d checks passed, %d failed", passes, #failures))
for _, f in ipairs(failures) do print("FAIL  " .. f) end
if #failures > 0 then os.exit(1) end
