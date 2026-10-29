-- Unit tests of game_dev/classic_wind.lua (the old hub's menu calls on WindUI) against a STUB of the WindUI adapter and a hand-driven scheduler: no Roblox world, so every
-- ordering below is exact. What this proves: the objects the hub holds (toggle handles, label "Text", button row "Visible") work before the real control exists and are applied to
-- it afterwards; the starting callbacks fire like in the old menu; the tab on screen is built first; an options drawer is built ahead of the queue; Clear drops what was queued;
-- one control that fails does not stop the rest. The real WindUI is exercised by tests/classic_tests.lua. Run: python3 tests/run_tsb.py shim (needs real Luau).
local failures, passes = {}, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures[#failures + 1] = msg end end

if not math.clamp then math.clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end end
Color3 = {fromRGB = function(r, g, b) return {R = r / 255, G = g / 255, B = b / 255} end}

-- a scheduler the test drives by hand: task.spawn runs at once up to the first wait, frame() resumes every waiting thread once
local threads = {}
local function resumeThread(co)
    local ok, err = coroutine.resume(co)
    if not ok then error(err, 0) end
    if coroutine.status(co) ~= "dead" then threads[#threads + 1] = co end
end
task = {
    spawn = function(f, ...)
        local args = table.pack(...)
        local co = coroutine.create(function() f(table.unpack(args, 1, args.n)) end)
        resumeThread(co)
        return co
    end,
    wait = function() coroutine.yield() end,
}
local function frame(n)
    for _ = 1, n or 1 do
        local list = threads
        threads = {}
        for _, co in ipairs(list) do resumeThread(co) end
    end
end

-- the stub adapter: hosts (tabs and groups) that log what is built into them
local created, notes
local function newHost(name)
    local h = {name = name, items = {}}
    local function add(kind, o, e)
        e = e or {}
        e.kind, e.o, e.visible = kind, o, true
        e.title = o.Title
        created[#created + 1] = name .. ":" .. kind .. ":" .. tostring(o.Title)
        if o.Title == "boom" then error("this control cannot be built") end
        function e:SetVisible(v) e.visible = v end
        function e:Destroy() e.destroyed = true end
        h.items[#h.items + 1] = e
        return e
    end
    function h:Toggle(o) local e = add("Toggle", o, {value = o.Default}); function e:Set(v, silent) e.value, e.silent = v, silent end return e end
    function h:Slider(o) local e = add("Slider", o, {value = o.Default}); function e:Set(v, silent) e.value, e.silent = v, silent end return e end
    function h:Dropdown(o) local e = add("Dropdown", o, {value = o.Default}); function e:Set(v, silent) e.value, e.silent = v, silent end return e end
    function h:Input(o) local e = add("Input", o, {value = o.Default}); function e:Set(v, silent) e.value, e.silent = v, silent end return e end
    function h:Button(o) return add("Button", o) end
    function h:Paragraph(o) return add("Paragraph", o) end
    function h:Label(text)
        local e = add("Label", {Title = text}, {value = text})
        function e:Set(v) e.value = v end
        return e
    end
    function h:Group(o)
        local g = newHost(name .. "/" .. tostring(o.Title))
        g.o, g.Opened, g.kind, g.title = o, o.Opened, "Group", o.Title
        created[#created + 1] = name .. ":Group:" .. tostring(o.Title)
        function g:Open() g.Opened = true; created[#created + 1] = g.name .. ":Open" end
        function g:Close() g.Opened = false; created[#created + 1] = g.name .. ":Close" end
        function g:Clear() for _, it in ipairs(g.items) do it.destroyed = true end g.items = {}; g.cleared = (g.cleared or 0) + 1 end
        h.items[#h.items + 1] = g
        return g
    end
    return h
end

local function newMenu(opts)
    created, notes = {}, {}
    threads = {}
    local win = {Tabs = {}, Window = {CurrentTab = 1}, Main = {Visible = true}, tags = {}}
    function win:Tab(name, icon, side) local h = newHost(name); h.icon, h.side = icon, side and side.title; win.Tabs[#win.Tabs + 1] = h; return h end
    function win:SideSection(title) return {title = title} end
    function win:SelectTab(i) win.Window.CurrentTab = i end
    function win:Tag(o)
        local t = {title = o.Title, color = o.Color, sets = 0}
        function t:Set(title, color) t.sets = t.sets + 1; if title ~= nil then t.title = title end if color then t.color = color end end
        win.tags[#win.tags + 1] = t
        return t
    end
    function win:Notify(o) notes[#notes + 1] = o end
    function win:SetVisible(v) win.Main.Visible = v end
    function win:Destroy() win.destroyed = true end
    local errors = {}
    local ClassicWind = loadstring(SHIM_SOURCE)()
    local B = ClassicWind.new{Adapter = {new = function() return win end}, WindUI = {}, UILib = {}, cfg = {}, perFrame = (opts or {}).perFrame or 1000, cards = (opts or {}).cards == true,
        onError = function(where, err) errors[#errors + 1] = where .. ": " .. tostring(err) end}
    return B, win, errors
end
local function settle(B) for _ = 1, 400 do if B.pending() == 0 then return true end frame() end return false end
local function index(list, text) for i, v in ipairs(list) do if v == text then return i end end end

------------------------------------------------------------------------------------------------ tabs and what the hub holds
do
    local B, win, errors = newMenu()
    B.sideHeader("MENU")
    local main = B.createTab("Main", "#")
    B.sideHeader("CHARACTERS")
    local saitama = B.createTab("Saitama", "S")
    check(#win.Tabs == 2 and win.Tabs[1].name == "Main" and win.Tabs[2].name == "Saitama", "a tab is made at once, in the order the hub asks")
    check(win.Tabs[1].icon == "layout-dashboard" and win.Tabs[2].icon == "user", "known tabs get their own icon, a character gets the person icon")
    check(win.Tabs[1].side == "MENU" and win.Tabs[2].side == "CHARACTERS", "...inside the sidebar group asked for before it")

    -- a toggle: the callback hears the starting value at once (like the old menu), the control comes later
    local heard = {}
    local toggle = main:Toggle("Auto", true, function(v) heard[#heard + 1] = v end, nil, "a subtitle")
    check(#heard == 1 and heard[1] == true, "the starting value is reported once, at once")
    check(toggle:Get() == true and #created == 0, "the handle works before the real control exists")
    frame()
    check(#created == 1 and created[1] == "Main:Toggle:Auto", "the next frame builds it: " .. tostring(created[1]))
    local real = win.Tabs[1].items[1]
    check(real.o.Default == true and real.o.NoInitialCallback == true and real.o.Desc == "a subtitle", "...with the starting value, no second starting callback, and its subtitle")
    toggle:Set(false)
    check(#heard == 2 and heard[2] == false and real.value == false and real.silent == true, "Set calls the callback once and changes the control without it calling back")
    toggle:Set(false)
    check(#heard == 2, "setting the same value again is quiet")
    real.o.Callback(true)                                           -- a tap in the real menu
    check(toggle:Get() == true and #heard == 3 and heard[3] == true and real.value == false, "a tap in the menu reaches the hub (the control already shows it)")
    real.o.Callback(true)
    check(#heard == 3, "...once")
    local early = main:Toggle("Early", false, function() end)       -- Set before the control exists
    early:Set(true)
    frame()
    check(win.Tabs[1].items[2].o.Default == true, "a value set before the control exists is what it is built with")

    -- a label: "Text" is read and written like the old menu's TextLabel; other fields are ignored
    local label = main:Label("hello")
    check(label.Text == "hello", "a label reads back its text")
    label.Text = "bye"
    label.TextSize, label.TextColor3 = 13, {}
    frame()
    local lreal = win.Tabs[1].items[3]
    check(lreal.value == "bye", "text written before the control exists is what it shows")
    label.Text = "again"
    check(lreal.value == "again" and label.Text == "again", "...and a later change reaches the control")

    -- a button's row: only "Visible" is used
    local pressed = 0
    local row = main:Button("Forget", function() pressed = pressed + 1 end)
    row.Visible = false
    frame()
    local breal = win.Tabs[1].items[4]
    check(breal.visible == false, "a row hidden before the control exists is built hidden")
    row.Visible = true
    check(breal.visible == true and row.Visible == true, "...and shown again later")
    breal.o.Callback()
    check(pressed == 1, "pressing it runs the hub's function")

    -- a slider snaps like the old one and reports the snapped starting value
    local vals = {}
    local slider = main:Slider("Gap", 0, 1, 0.33, 0.1, function(v) vals[#vals + 1] = v end)
    check(vals[1] == 0.3, "the starting value is snapped: " .. tostring(vals[1]))
    slider:Set(0.74)
    check(vals[2] == 0.7, "Set snaps and reports: " .. tostring(vals[2]))
    slider:Set(7)
    check(vals[3] == 1, "...and clamps")
    check(not pcall(function() main:Slider("Bad", 1, 1, 1, 1, function() end) end), "a slider with max <= min is refused like before")

    -- a dropdown: an unknown start is the first option; Set refuses an unknown one
    local picks = {}
    local dd = main:Dropdown("Side", {"Behind", "Toward"}, "Nope", function(v) picks[#picks + 1] = v end)
    check(picks[1] == "Behind", "an unknown default becomes the first option")
    dd:Set("Toward"); dd:Set("Nowhere")
    check(#picks == 2 and picks[2] == "Toward", "Set takes a known option only")

    -- an input: the text is kept, Set does not call back
    local typed = {}
    local input = main:Input("Link", "hint", "abc", function(t) typed[#typed + 1] = t end)
    check(input:Get() == "abc", "an input reads back its text")
    input:Set("def")
    check(input:Get() == "def" and #typed == 0, "Set changes the text without calling back")
    settle(B)
    local ireal = win.Tabs[1].items[#win.Tabs[1].items]
    ireal.o.Callback("typed in the box")
    check(input:Get() == "typed in the box" and typed[1] == "typed in the box", "typing in the box reaches the hub")
    check(#errors == 0, "no errors: " .. table.concat(errors, " | "))
    check(B.elements["Main/Auto"] ~= nil and B.elements["Main/Gap"] ~= nil, "every control is findable by its path")
end

------------------------------------------------------------------------------------------------ the queue: the tab on screen first, a drawer ahead of everything
do
    local B, win = newMenu({perFrame = 1})
    local a, b = B.createTab("A"), B.createTab("B")
    a:Label("a1"); a:Label("a2"); b:Label("b1"); b:Label("b2")
    check(B.pending() == 4, "nothing is built yet: " .. B.pending())
    win.Window.CurrentTab = 2                                        -- the user is looking at B
    frame(); frame()
    check(created[1] == "B:Label:b1" and created[2] == "B:Label:b2", "the tab on screen is built first: " .. table.concat(created, ","))
    settle(B)
    check(created[3] == "A:Label:a1" and created[4] == "A:Label:a2" and B.pending() == 0, "then the others, in order")

    -- one control that cannot be built does not stop the rest
    local B2, win2, errors2 = newMenu({perFrame = 1})
    local t = B2.createTab("T")
    t:Label("first"); t:Toggle("boom", false, function() end); t:Label("last")
    settle(B2)
    check(#errors2 == 1 and errors2[1]:find("menu build", 1, true), "the failure is reported: " .. tostring(errors2[1]))
    check(index(created, "T:Label:last") ~= nil, "the control after it is still built")
end

------------------------------------------------------------------------------------------------ sections, cards, drawers
do
    local B, win, errors = newMenu({perFrame = 1})
    local t = B.createTab("Garou")
    local sec = t:Section("Garou kyoto", true)
    local fromHub = {}
    sec:Toggle("Tech on", false, function(v) fromHub[#fromHub + 1] = v end, "sub")
    t:Button("Reset", function() end, sec.Body)                      -- a tab call with the section as parent
    sec:Info("Which moves", "details")
    settle(B)
    local group = win.Tabs[1].items[1]
    check(group.o.Title == "Garou kyoto" and group.o.Opened == false, "a collapsed section is a folded group")
    check(#group.items == 3 and group.items[1].kind == "Toggle" and group.items[2].kind == "Button" and group.items[3].kind == "Paragraph", "its controls go into the group, wherever the call came from")

    -- a card
    local log = {}
    local drawerOptions = 0
    local handle = sec:Button("Kyoto Core", "the steps", function() log[#log + 1] = "run" end, {
        conf = "high",
        pin = {default = true, onChange = function(v) log[#log + 1] = "pin " .. tostring(v) end},
        assist = {onChange = function(v) log[#log + 1] = "assist " .. tostring(v) end},
        options = function(drawer)
            drawerOptions = drawerOptions + 1
            t:Slider("Speed", 0.5, 2, 1, 0.05, function() end, drawer)
            t:Button("Reset this combo", function() end, drawer)
        end,
    })
    check(log[1] == "pin true", "a card switched on at the start tells the hub: " .. tostring(log[1]))
    settle(B)
    local card = group.items[#group.items]
    check(card.o.Title == "Kyoto Core" and card.o.Box == true and card.o.Desc == "[high]  the steps", "a card is a boxed group: title, confidence and steps")
    local kinds = {}
    for _, it in ipairs(card.items) do kinds[#kinds + 1] = it.kind .. ":" .. tostring(it.title) end
    check(table.concat(kinds, ",") == "Button:Run,Toggle:On screen,Toggle:Assist,Toggle:Show options,Group:Options",
        "with Run, On screen, Assist, Show options and the (empty) drawer: " .. table.concat(kinds, ","))
    local run, pin, assist, opt = card.items[1], card.items[2], card.items[3], card.items[4]
    check(pin.o.Default == true, "the On screen switch starts on")
    run.o.Callback()
    check(log[#log] == "run", "Run runs the combo")
    assist.o.Callback(true)
    check(log[#log] == "assist true", "the Assist switch tells the hub")
    handle:SetPinned(false)                                          -- the hub switches them from its own code (a pin removed, a combo disarmed)
    handle:SetArmed(false)
    check(pin.value == false and pin.silent == true and assist.value == false and assist.silent == true and log[#log] == "assist true", "SetPinned / SetArmed change the switches without telling the hub")
    check(drawerOptions == 0, "the options are not built until the drawer is opened")
    -- open the drawer while other work is still queued: its controls come first
    for i = 1, 3 do t:Label("later " .. i) end
    created = {}
    opt.o.Callback(true)
    check(drawerOptions == 1, "opening the drawer builds the options once")
    frame()
    check(created[1] == "Garou/Garou kyoto/Kyoto Core/Options:Slider:Speed", "the drawer's controls jump the queue: " .. tostring(created[1]))
    settle(B)
    local drawer = card.items[5]
    check(#drawer.items == 2 and drawer.Opened == true, "the drawer holds them and is open")
    opt.o.Callback(false)
    frame()
    check(drawer.Opened == false, "switching Options off folds it")
    opt.o.Callback(true)
    settle(B)
    check(drawerOptions == 1 and drawer.Opened == true, "opening it again does not build the options again")

    -- a plain row (no extras) is just a button
    sec:Button("Dasher", "@dasher", function() end)
    settle(B)
    check(group.items[#group.items].kind == "Button" and group.items[#group.items].o.Desc == "@dasher", "a card without extras is a plain button row")

    -- Clear: the group is emptied and what was queued before is dropped
    local before = #group.items
    sec:Button("Old 1", "x", function() end); sec:Button("Old 2", "x", function() end)
    sec:Clear()
    sec:Button("New", "x", function() end)
    settle(B)
    local names = {}
    for _, it in ipairs(group.items) do names[#names + 1] = tostring(it.title) end
    check(group.cleared == 1 and #group.items == 1 and group.items[1].title == "New", "Clear empties the group and drops what was waiting: " .. table.concat(names, ","))
    check(index(created, "Garou/Garou kyoto:Button:Old 1") == nil and index(created, "Garou/Garou kyoto:Button:Old 2") == nil, "...the controls that were still waiting are never built at all")
    check(#errors == 0, "no errors: " .. table.concat(errors, " | "))
    check(B.elements["Garou/Garou kyoto/Kyoto Core/Run"] ~= nil, "a card's controls are findable by path")
end

------------------------------------------------------------------------------------------------ the card that opens each tab
do
    local B, win, errors = newMenu({cards = true})
    local main, saitama = B.createTab("Main"), B.createTab("Saitama")
    main:Label("after the card")
    settle(B)
    check(win.Tabs[1].items[1].kind == "Paragraph" and win.Tabs[1].items[1].o.Title == "Main" and win.Tabs[1].items[1].o.Desc:find("Start techs", 1, true), "a tab opens with a card: its name and what is in it")
    check(win.Tabs[1].items[2].kind == "Label", "...before everything else on it")
    check(win.Tabs[2].items[1].o.Desc:find("Combo cards for Saitama", 1, true), "a character's tab gets the generic card with the name in it")
    check(B.elements["Saitama/Saitama"] ~= nil and #errors == 0, "...findable by path")
    local B2, win2 = newMenu()
    B2.createTab("Main")
    settle(B2)
    check(#win2.Tabs[1].items == 0, "(cards = false leaves them out)")
end

------------------------------------------------------------------------------------------------ the title bar, the window
do
    local B, win = newMenu()
    local pill = B.pingPill("-- ms", "#9be8c4")
    local tag = win.tags[1]
    check(tag.title == "-- ms" and tag.color == "#9be8c4", "the ping tag starts as asked")
    pill.Text = "64 ms"
    pill.TextColor3 = Color3.fromRGB(255, 120, 120)
    check(tag.title == "64 ms" and tag.color == "#ff7878", "its text and colour follow what the hub writes: " .. tostring(tag.title) .. " " .. tostring(tag.color))
    local sets = tag.sets
    pill.Text = "64 ms"
    pill.TextColor3 = Color3.fromRGB(255, 120, 120)
    check(tag.sets == sets, "writing the same thing again does nothing (the hub writes four times a second)")
    B.toast("hello")
    check(notes[1] and notes[1].Content == "hello" and notes[1].Title == "Wraith Hub v1.5", "a toast is a WindUI notification")
    B.setMenu(false)
    check(B.isOpen() == false and win.Main.Visible == false, "the menu can be hidden")
    B.setMenu(true)
    check(B.isOpen() == true, "...and shown")
    local t = B.createTab("T")
    t:Label("one")
    B.destroy()
    frame(3)
    check(win.destroyed and #created == 0, "destroying the menu removes the window and stops the building")
end

print(string.format("%d checks passed, %d failed", passes, #failures))
for _, f in ipairs(failures) do print("FAIL  " .. f) end
if #failures > 0 then error("classic_wind tests failed") end
