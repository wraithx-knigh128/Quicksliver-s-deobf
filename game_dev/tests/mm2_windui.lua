-- The hub on the REAL WindUI library (vendored, embedded in the bundle), run inside the fake Roblox world. Needs real Luau (see tests/run_mm2.py).
-- What this proves: the library builds the whole menu without touching a member the Roblox API does not have, the hub's settings follow what a user does in
-- WindUI's own controls (real clicks on its toggle, its dropdown options, key presses), and the background / fallback / unload paths behave.
-- What it cannot prove: how it LOOKS (no renderer for WindUI's 9-slice images), or that any particular executor allows what WindUI needs.
local World = MM2_WORLD
local failures, passes = {}, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures[#failures + 1] = msg end end
local function section(name) print(string.format("--- %s [%d MB]", name, math.floor(collectgarbage("count") / 1024))) end

local PAGE = "https://pixabay.com/videos/lake-sunset-trees-leaves-japan-91562/"
local function newGame(opts, config)
    local w = World.new(opts or {gethui = true}); w:installJson()
    local me = w:addPlayer("Me", {pos = {0, 3, 0}}); w:setLocal(me); w.me = me
    if config then w.files["wraiths_hub_config.json"] = w.jsonEncode(config) else w.genv.WraithsHubUI = "WindUI" end
    return w
end
local function boot(w, seconds)
    local ok, err = w:load(SCRIPT_SOURCE)
    if not ok then failures[#failures + 1] = "load: " .. tostring(err); return false end
    w:run(seconds or 1.5)
    return true
end
local function clean(w, name, expectThrown)
    if not expectThrown then check(#w.thrown == 0, name .. ": members/types the real Roblox API rejects: " .. table.concat(w.thrown, " | "):sub(1, 700)) end
    check(#w.errors == 0, name .. ": errors inside handlers/threads: " .. table.concat(w.errors, " | "):sub(1, 700))
    check(#w.warns == 0, name .. ": warn(): " .. table.concat(w.warns, " | "):sub(1, 400))
    local unknown = {}
    for c in pairs(w.unknownClasses) do unknown[#unknown + 1] = c end
    check(#unknown == 0, name .. ": classes missing from tests/prop_types_mm2.lua: " .. table.concat(unknown, ","))
end
local function win(w) return w.genv.__WraithsHub and w.genv.__WraithsHub.Win end
local function el(w, title) for _, e in ipairs(win(w).Elements) do if e.Title == title then return e end end error("no element titled " .. title, 2) end
local function texts(w, rootName)                                        -- every text on screen under a ScreenGui
    local root = w.M.FindFirstChild(w.coreGui, rootName)
    local out = {}
    if root then
        for _, i in ipairs(w.M.GetDescendants(root)) do
            if (i.ClassName == "TextLabel" or i.ClassName == "TextButton") and i.Text ~= "" then out[#out + 1] = i.Text end
        end
    end
    return out
end
local function hasText(w, rootName, pattern)
    for _, t in ipairs(texts(w, rootName)) do if t:find(pattern, 1, true) then return true end end
    return false
end
local function click(w, e)                                               -- a real tap on a WindUI toggle: press on its hit area, release anywhere
    local hit = w.M.FindFirstChild(e.Ui.ElementFrame, "Hitbox", true)
    assert(hit, "toggle has no Hitbox")
    w:press(hit, 10, 10, "MouseButton1"); w:release(10, 10, "MouseButton1")
    w:run(0.3)
end
local function pickOption(w, dropdown, value)                            -- a click on one entry of a WindUI dropdown menu
    local menu = dropdown.Ui.UIElements.Menu
    local lbl = w:find(function(i) return i.ClassName == "TextLabel" and i.Text == value and i.Parent and i.Parent.Name == "Title" end, menu)
    assert(lbl, "no option " .. value)
    local item = lbl.Parent.Parent.Parent                              -- TextLabel > Title > Frame > the clickable item
    w.fire(rawget(item, "__d").signals.MouseButton1Click)
    w:run(0.3)
end
local function guiNames(w)
    local out = {}
    for _, g in ipairs(w.M.GetChildren(w.coreGui)) do out[#out + 1] = g.Name end
    return out
end
local function count(w, name) local n = 0 for _, g in ipairs(w.M.GetChildren(w.coreGui)) do if g.Name == name then n = n + 1 end end return n end

------------------------------------------------------------------------------------------------ 1. boot
section("boots on WindUI")
do
    local w = newGame()
    check(boot(w), "boots")
    local Win = win(w)
    check(Win and Win.Backend == "WindUI", "the WindUI backend is in use")
    for _, n in ipairs({"WindUI", "WindUI/Notifications", "WindUI/Dropdowns", "WindUI/Tooltips", "WraithsHubWindow_Buttons"}) do
        check(count(w, n) == 1, "exactly one ScreenGui " .. n)
    end
    check(hasText(w, "WindUI", "Wraith's Hub"), "the window title says Wraith's Hub")
    check(hasText(w, "WindUI", "Murder Mystery 2"), "the window subtitle names the game")
    for _, tab in ipairs({"Main", "ESP", "Combat", "Player", "Misc"}) do check(hasText(w, "WindUI", tab), "tab " .. tab) end
    check(hasText(w, "WindUI", "Perfect shoot"), "Quick actions are there")
    check(hasText(w, "WindUI/Notifications", "Wraith's Hub loaded"), "welcome toast (a WindUI notification)")
    check(w.genv.__WraithsHub ~= nil, "session registered")
    local function hasImage(id) return w:find(function(i) return i.ClassName == "ImageLabel" and i.Image == id end) ~= nil end
    check(hasImage(LUCIDE_IDS["layout-grid"]) and hasImage(LUCIDE_IDS["crosshair"]) and hasImage(LUCIDE_IDS["settings"]), "the tab icons come from the built-in Lucide set (no icon download)")
    local fetched = {}
    for _, u in ipairs(w.httpLog or {}) do fetched[#fetched + 1] = u end
    check(#fetched == 0, "starting the menu fetches nothing from the web (" .. table.concat(fetched, ", ") .. ")")
    check(#Win.Tabs == 5, "a short sidebar: five tabs, got " .. #Win.Tabs)
    -- clean and small, like the reference menu
    local topbar = {}
    for _, b in pairs(Win.Window.TopBarButtons) do topbar[b.Name] = b.Object.Visible end
    check(topbar.Close ~= true and topbar.Minimize ~= true and topbar.Fullscreen ~= true, "none of WindUI's own top bar buttons are shown (ours replaces Close - see 'close button' below)")
    check(Win.Window.User.Enabled == false and Win.Window.HideSearchBar == true, "no user card, no search bar")
    check(not hasText(w, "WindUI", "v" .. tostring(Win.WindUI.Version)), "no version tag")
    check(Win.Window.UIElements.Main.Size.X.Offset <= 560 and Win.Window.UIElements.Main.Size.Y.Offset <= 380, "the window is compact (" .. tostring(Win.Window.UIElements.Main.Size.X.Offset) .. " x " .. tostring(Win.Window.UIElements.Main.Size.Y.Offset) .. ")")
    check(Win.WindUI.Creator.Font == w.env.Font.fromEnum(w.env.Enum.Font.Code).Family, "the menu uses a monospace face")
    check(Win.WindUI.Themes.Dark.ElementBackgroundTransparency >= 0.4, "cards are frosted (translucent)")
    local toggleCard = el(w, "Show Grab Gun").Ui.ElementFrame
    check(w.M.FindFirstChild(toggleCard, "WraithFade") ~= nil, "every card fades out to the right")
    check(Win.Main.Visible == true, "the window is open")
    check(w:find(function(i) return i.Name == "Float_shoot" end) ~= nil and w:find(function(i) return i.Name == "Float_throw" end) ~= nil, "Perfect Shoot / Throw floating buttons exist")
    local shoot = w:find(function(i) return i.Name == "Float_shoot" end)
    check(shoot.Visible == true and w.M.FindFirstChild(shoot, "Outline") ~= nil and w.M.FindFirstChild(shoot, "Waves") == nil, "the SHOOT button is visible: transparent inside, a flowing outline")
    check(Win.Tabs[1].ui.ContainerFrame.Visible == true and Win.Tabs[1].ui.Selected == true and Win.Tabs[5].ui.ContainerFrame.Visible == false, "the Main tab is open at start (WindUI would show none)")
    check(win(w).Flags.espPlayers ~= nil and win(w).Flags.aimKey ~= nil and win(w).Flags.waves ~= nil, "flags are registered")
    clean(w, "boot")
end

-- the menu is built a few controls per frame, so loading never freezes the game for a moment
section("smooth load")
do
    local w = newGame()
    w.writes = 0
    w:load(SCRIPT_SOURCE)
    local Win0 = win(w)
    check(w:find(function(i) return i.Name == "Float_shoot" end) ~= nil, "the SHOOT / THROW buttons are there before the menu is finished")
    local first = w.writes
    w:step(1 / 60); w:step(1 / 60); w:step(1 / 60)
    local early = #win(w).Elements
    w:run(1.5)
    local total = #win(w).Elements
    check(early > 0 and early < total / 2 and total > 60, "the menu fills up over several frames (" .. early .. " controls after 3 frames, " .. total .. " in the end)")
    local worst, frames = 0, 0
    local w2 = newGame(); w2.writes = 0; w2:load(SCRIPT_SOURCE)
    for _ = 1, 60 do
        local before = w2.writes
        w2:step(1 / 60)
        worst = math.max(worst, w2.writes - before)
    end
    check(worst < 25000, "no frame of the build does more than ~25k property writes (worst: " .. worst .. ")")
    local roles = 0
    w2:run(0.5)
    local before = w2.writes
    w2:run(1.0)
    check((w2.writes - before) / 60 < 25, "at rest the hub writes about " .. string.format("%.1f", (w2.writes - before) / 60) .. " properties a frame (< 25)")
    clean(w, "smooth load")
end

------------------------------------------------------------------------------------------------ 2. the controls follow WindUI's own widgets
section("real clicks on WindUI controls")
do
    local w = newGame(); boot(w)
    local Win = win(w)
    local grab = w:find(function(i) return i.Name == "Float_grab" end)
    check(grab.Visible == false, "GRAB GUN starts hidden")
    local toggle = el(w, "Show Grab Gun")
    click(w, toggle)
    check(toggle.Value == true and grab.Visible == true, "a real tap on the toggle turns the setting on and shows the button")
    click(w, toggle)
    check(toggle.Value == false and grab.Visible == false, "and off again")
    toggle:Set(true, true)
    check(toggle.Value == true and grab.Visible == false, "Set(v, silent) changes the switch without firing the hub's callback")
    toggle:Set(false)
    check(toggle.Value == false, "Set(false)")
    toggle:Set(true)
    check(grab.Visible == true, "Set(v) from the hub does fire the callback exactly like a tap")

    local size = el(w, "Button size")
    local shoot = w:find(function(i) return i.Name == "Float_shoot" end)
    size.Ui:Set(100); w:run(0.2)
    check(size.Value == 100 and shoot.Size.X.Offset == 100, "dragging WindUI's slider resizes the floating buttons (" .. tostring(shoot.Size.X.Offset) .. ")")
    size:Set(60)
    check(shoot.Size.X.Offset == 60, "slider Set() from the hub")
    size:Set(500)
    check(size.Value == 120, "values are clamped to the slider's range (" .. tostring(size.Value) .. ")")

    local save = el(w, "Save config")
    check(w.M.FindFirstChild(save.Ui.ElementFrame, "Outline") ~= nil, "WindUI's own buttons carry the flowing outline too")
    local waves = el(w, "Button waves")
    check(Win.WaveMode == "High", "waves start High")
    pickOption(w, waves, "Off")
    check(waves.Value == "Off" and Win.WaveMode == "Off", "choosing 'Off' in WindUI's dropdown switches the waves off")
    local og = w.M.FindFirstChildOfClass(w.M.FindFirstChild(save.Ui.ElementFrame, "Outline"), "UIGradient")
    local still = og.Rotation; w:run(0.5)
    check(og.Rotation == still, "...and stops the water on WindUI's buttons")
    waves:Set("Low")
    check(Win.WaveMode == "Low", "dropdown Set()")
    waves:Set("High", true)
    check(Win.WaveMode == "Low" and waves.Value == "High", "silent Set does not fire the callback")

    local theme = el(w, "Theme")
    check(Win.WindUI:GetCurrentTheme() == "Dark" and Win:GetTheme() == "Dark", "default theme is WindUI's Dark")
    pickOption(w, theme, "Crimson")
    check(Win.WindUI:GetCurrentTheme() == "Crimson" and Win:GetTheme() == "Crimson", "choosing a theme changes WindUI's theme")
    clean(w, "controls")
end

------------------------------------------------------------------------------------------------ 3. keys
section("keybinds")
do
    local w = newGame(); boot(w)
    local Win = win(w)
    local aim = Win.Flags.aimKey
    check(aim.Value == "Z" and aim.Down == false, "aim key starts as Z, not held")
    w:keyDown("Z"); check(aim.Down == true, "holding Z is seen")
    w:keyUp("Z"); check(aim.Down == false, "releasing Z is seen")
    aim:Set("Q")
    w:keyDown("Z"); check(aim.Down == false, "after Set('Q') the old key does nothing")
    w:keyDown("Q"); check(aim.Down == true, "...and Q is the key")
    w:keyUp("Q")
    -- the user picks a new key in WindUI: it writes the key name into the key button's label
    local label = aim.Ui.UIElements.Keybind.Frame.Frame.TextLabel
    label.Text = "..."
    check(aim.Value == "Q", "'...' (waiting for a key) is not a key")
    label.Text = "F"
    check(aim.Value == "F", "a key picked in WindUI becomes the setting")
    w:keyDown("F"); check(aim.Down == true, "and it is the held key")
    w:keyUp("F")
    check(Win.ToggleKey ~= nil and Win.ToggleKey.Name == "RightShift", "the menu key starts as RightShift")
    Win.ToggleKey = w.env.Enum.KeyCode.F5
    check(Win.ToggleKey.Name == "F5" and Win.Window.ToggleKey.Name == "F5", "changing win.ToggleKey reaches WindUI")
    w:keyDown("F5"); w:run(1.0)
    check(Win.Main.Visible == false, "F5 closes the window")
    check(w:find(function(i) return i.Name == "Float_shoot" end).Visible == true, "...and the floating buttons stay")
    w:keyDown("F5"); w:run(1.0)
    check(Win.Main.Visible == true, "F5 opens it again")
    clean(w, "keys")
end

-- WindUI's own topbar "x" opens a "you will not be able to open it again" dialog and, if confirmed, permanently destroys the window: not what tapping a
-- close button should do. We replace it with our own dot that hides the window the same reversible way the toggle key does.
section("close button: hides, never destroys")
do
    local w = newGame(); boot(w)
    local Win = win(w)
    for _, name in ipairs({"Close", "Minimize", "Fullscreen"}) do
        local native = w:find(function(i) return i.ClassName == "TextButton" and i.Name == name end)
        check(native == nil or native.Visible == false, "WindUI's own " .. name .. " button is not shown")
    end
    local dot = w:find(function(i) return i.ClassName == "TextButton" and i.Name == "WraithClose" end)
    check(dot ~= nil and dot.Visible ~= false, "our own close dot is there instead")
    check(Win.Main.Visible == true, "the window starts open")
    w:click(dot); w:run(0.3)
    check(Win.Main.Visible == false, "tapping it hides the window")
    check(Win.Window.UIElements ~= nil and Win.Window.UIElements.Main ~= nil, "...WITHOUT destroying it (no 'you will not be able to open it again')")
    check(w.genv.__WraithsHub ~= nil and w.genv.__WraithsHub.Alive == true, "the hub itself is still running")
    check(w:find(function(i) return i.Name == "Float_shoot" end).Visible == true, "...and the floating buttons stay up")
    w:click(Win.Window.OpenButtonMain.Button.TextButton); w:run(0.3)
    check(Win.Main.Visible == true, "WindUI's own open button brings it straight back")
    clean(w, "close button")
end

------------------------------------------------------------------------------------------------ 4. config, labels
section("config and live labels")
do
    local w = newGame(); boot(w)
    local Win = win(w)
    check(w.files["wraiths_hub_config.json"] == nil, "nothing is saved until Save config is pressed")
    el(w, "Show Grab Gun"):Set(true)
    el(w, "Button size"):Set(90)
    el(w, "Save config").Click()
    check(w.files["wraiths_hub_config.json"] ~= nil, "Save config writes the file")
    local saved = w.jsonDecode(w.files["wraiths_hub_config.json"] or "{}")
    check(saved.btnGrab == true and saved.btnSize == 90 and saved.theme == "Dark", "the file holds the settings (btnGrab " .. tostring(saved.btnGrab) .. ", btnSize " .. tostring(saved.btnSize) .. ")")
    el(w, "Show Grab Gun"):Set(false); el(w, "Button size"):Set(70)
    el(w, "Load config").Click()
    check(el(w, "Show Grab Gun").Value == true and el(w, "Button size").Value == 90, "Load config restores them")
    check(hasText(w, "WindUI", "Murderer:"), "the round info label shows the murderer line")
    clean(w, "config")
end

------------------------------------------------------------------------------------------------ 5. background video / picture
section("window background")
do
    local MEDIUM = "https://cdn.pixabay.com/video/2021/05/04/91562-548000000_medium.mp4"
    local TINY = "https://cdn.pixabay.com/video/2021/05/04/91562-548000000_tiny.mp4"
    -- the inside is transparent; the grey water flows only round OUTLINES: the window's border and the borders of the buttons
    local wt = newGame(); boot(wt, 1.0)
    check(wt:find(function(i) return i.Name == "WraithTexture" or i.Name == "Water" or i.Name == "Sky" or i.Name == "Collage" end) == nil, "no texture is drawn inside the window")
    local Wt = win(wt)
    check(Wt.Window.Transparent == true and Wt.WindUI.TransparencyValue == 0.5, "the window is see-through (0.5)")
    local frame = wt:find(function(i) return i.Name == "WraithOutline" end)
    check(frame ~= nil and frame.Parent == Wt.Window.UIElements.Main and frame.BackgroundTransparency == 1, "the window outline is a transparent frame with only a border")
    local strokes = wt:findAll(function(i) return i.ClassName == "UIStroke" and i.Parent == frame end)
    check(#strokes == 2 and strokes[1].Name == "Outline" and strokes[2].Name == "Glow", "...a crisp line and a soft glow")
    local grad = wt.M.FindFirstChildOfClass(strokes[1], "UIGradient")
    check(grad ~= nil and #grad.Color.keys == 20, "...carrying the grey water gradient")
    for _, k in ipairs(grad.Color.keys) do check(math.abs(k.v.R - k.v.B) < 0.1, "window outline colours are grey / white") end
    local r0, travel = grad.Rotation, 0
    for _ = 1, 12 do wt:run(0.25); travel = math.max(travel, math.abs(grad.Rotation - r0)) end
    check(travel > 20, "the water runs round the window border (" .. string.format("%.0f", travel) .. " deg)")
    Wt.Window:Close(); wt:run(0.8)
    local before = grad.Rotation
    wt:run(0.6)
    check(grad.Rotation == before, "nothing moves while the window is closed")
    Wt.Window:Open(); wt:run(0.8)
    Wt:SetWaveMode("Off"); wt:run(0.2)
    local still = grad.Rotation; wt:run(0.5)
    check(grad.Rotation == still, "Off: the border stands still")
    Wt:SetWaveMode("High")
    -- the buttons: only their borders flow, and only while their tab is open
    Wt.Window:SelectTab(5); wt:run(0.5)
    local save = el(wt, "Save config")
    local card = save.Ui.ElementFrame
    local ost = wt.M.FindFirstChild(card, "Outline")
    local og = ost and wt.M.FindFirstChildOfClass(ost, "UIGradient")
    check(ost ~= nil and ost.Thickness == 1.5 and og ~= nil and wt.M.FindFirstChild(card, "Glow") == nil, "WindUI buttons get a thin flowing outline")
    check(wt.M.FindFirstChild(card, "Waves") == nil, "...and nothing inside")
    local o0, otravel = og.Rotation, 0
    for _ = 1, 12 do wt:run(0.25); otravel = math.max(otravel, math.abs(og.Rotation - o0)) end
    check(otravel > 20, "the button outline flows while its tab is open")
    Wt.Window:SelectTab(1); wt:run(0.5)
    local o1 = og.Rotation; wt:run(0.5)
    check(og.Rotation == o1, "...and stands still on a tab that is not open")
    Wt:SetBackgroundTransparency(0.8)
    check(Wt.WindUI.TransparencyValue == 0.8, "the 'Window see-through' slider reaches WindUI")
    local dim = wt:find(function(i) return i.Name == "WraithDim" end)
    check(dim ~= nil and dim.Visible == false, "the dim layer is only there while a picture / video is")
    check(wt:find(function(i) return i.Name == "WraithVideo" or i.Name == "WraithPicture" end) == nil, "no picture by default (nothing is downloaded at start)")
    clean(wt, "outlines")

    -- a) the Pixabay page: its page names the files, the medium one is downloaded once and kept in the workspace folder
    local w = newGame(nil, {bgOn = true}); w.http = {[PAGE] = '<video src="' .. TINY .. '"></video><script>{"medium":"' .. MEDIUM .. '"}</script>', [MEDIUM] = "FAKE-MP4-BYTES"}
    boot(w, 1.0)
    local Win = win(w)
    local file
    for path in pairs(w.files) do if path:find("^WraithsHub/assets/bg_%x+%.mp4$") then file = path end end
    check(file ~= nil and w.files[file] == "FAKE-MP4-BYTES", "the video is downloaded into WraithsHub/assets (" .. tostring(file) .. ")")
    local video = w:find(function(i) return i.Name == "WraithVideo" end)
    check(video ~= nil and video.ClassName == "VideoFrame", "a VideoFrame sits in the window")
    check(video and video.Video == "rbxasset://" .. tostring(file), "it plays the saved file")
    check(video and video.Looped == true and video.Volume == 0, "looped and muted")
    local played = false
    for _, c in ipairs(w.calls) do if c[1] == "Play" then played = true end end
    check(played, "Play() was called")
    local dim2 = w:find(function(i) return i.Name == "WraithDim" end)
    check(video and video.Parent == dim2.Parent and video.Parent.Name == "Background", "the video and the dim layer live in WindUI's window background layer")
    check(dim2.Visible == true and math.abs(dim2.BackgroundTransparency - 0.65) < 1e-9, "the dim layer appears with the picture (0.35 -> transparency 0.65)")
    Win:SetBackgroundDim(0.9)
    check(math.abs(dim2.BackgroundTransparency - 0.1) < 1e-9, "the dim slider's value reaches the layer")
    local downloads = #w.httpLog
    el(w, "Video / picture behind it"):Set(false)
    check(w:find(function(i) return i.Name == "WraithVideo" end) == nil, "turning it off removes the video")
    check(w:find(function(i) return i.Name == "WraithDim" end).Visible == false, "...and the dim layer goes with it")
    el(w, "Video / picture behind it"):Set(true); w:run(0.3)
    check(w:find(function(i) return i.Name == "WraithVideo" end) ~= nil, "...and on again")
    local fetches = 0
    for i = downloads + 1, #w.httpLog do if w.httpLog[i] == MEDIUM then fetches = fetches + 1 end end
    check(fetches == 0, "the saved file is reused: no second download of the video (" .. fetches .. ")")
    -- a picture link
    w.http["https://example.com/art.png"] = "PNGBYTES"
    el(w, "Video or picture link"):Set("https://example.com/art.png")
    el(w, "Load this link now").Click(); w:run(0.3)
    local pic = w:find(function(i) return i.Name == "WraithPicture" end)
    check(pic ~= nil and pic.ClassName == "ImageLabel" and w:find(function(i) return i.Name == "WraithVideo" end) == nil, "a .png link shows a picture instead of the video")
    -- a link that cannot work says so
    el(w, "Video or picture link"):Set("https://example.com/readme")
    el(w, "Load this link now").Click(); w:run(0.3)
    check(hasText(w, "WindUI/Notifications", "Background not loaded"), "an unsupported link raises a 'Background not loaded' notification")
    clean(w, "background")

    -- b) the page names no file / the web is not reachable: the menu works anyway and says so
    local w2 = newGame(nil, {bgOn = true}); w2.http = {[PAGE] = "<html>captcha</html>"}
    boot(w2, 1.0)
    check(w2:find(function(i) return i.Name == "WraithVideo" end) == nil, "no video without a file link")
    check(hasText(w2, "WindUI/Notifications", "Background not loaded"), "the failure is reported")
    check(win(w2).Backend == "WindUI" and w2:find(function(i) return i.Name == "Float_shoot" end) ~= nil, "the rest of the hub is unaffected")
    check(w2:find(function(i) return i.Name == "WraithOutline" end) ~= nil, "...and the outline is still there")
    clean(w2, "background fails")

    -- b2. an executor with request(): it is used first, with browser-like headers; when the site refuses (403) HttpGet gets a turn
    local w4 = newGame({gethui = true, request = true}, {bgOn = true}); w4.http = {[PAGE] = '<source src="' .. MEDIUM .. '">', [MEDIUM] = "BYTES"}
    boot(w4, 1.0)
    check(w4.requests and #w4.requests >= 2 and w4.requests[1].Url == PAGE, "request() fetched the page first")
    check(w4.requests and w4.requests[1].Headers and tostring(w4.requests[1].Headers["User-Agent"]):find("Mozilla", 1, true) ~= nil and w4.requests[1].Headers["Referer"] == "https://pixabay.com/", "...with browser-like headers")
    check(w4:find(function(i) return i.Name == "WraithVideo" end) ~= nil, "and the video was loaded through it")
    local w5 = newGame({gethui = true, request = true}, {bgOn = true}); w5.http = {[PAGE] = '<source src="' .. MEDIUM .. '">', [MEDIUM] = "BYTES"}
    local realRequest = w5.env.request
    w5.env.request = function(o) realRequest(o); return {Success = false, StatusCode = 403, Body = ""} end         -- the site turns request() away
    boot(w5, 1.0)
    check(w5:find(function(i) return i.Name == "WraithVideo" end) ~= nil, "a refused request() falls back to HttpGet")
    clean(w4, "request path"); clean(w5, "request refused")

    -- c. an executor without file functions
    local w3 = newGame({gethui = true, no = {files = true}}, {bgOn = true}); w3.http = {[PAGE] = '<source src="' .. MEDIUM .. '">', [MEDIUM] = "x"}
    boot(w3, 1.0)
    check(w3:find(function(i) return i.Name == "WraithVideo" end) == nil, "no files, no video")
    check(win(w3) and win(w3).Backend == "WindUI", "the menu still runs on WindUI")
end

------------------------------------------------------------------------------------------------ 6. fallback, config choice, unload
section("fallback, menu style, unload")
do
    -- a. WindUI fails to start, or fails half way through building its window: the hub switches to the classic menu and cleans up after the attempt
    for _, case in ipairs({{"loading the library", "json"}, {"building the window", "ImageButton"}}) do
        local w = newGame()
        if case[2] == "json" then w.denyJsonDecode = true else w.denyClass = {[case[2]] = true} end
        boot(w, 1.2)
        local name = "fallback while " .. case[1]
        check(win(w) ~= nil and win(w).Backend ~= "WindUI", name .. ": the classic menu took over")
        check(w:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "WraithsHubWindow" end) ~= nil, name .. ": the classic window exists")
        for _, n in ipairs({"WindUI", "WindUI/Notifications", "WindUI/Dropdowns", "WindUI/Tooltips"}) do check(count(w, n) == 0, name .. ": no " .. n .. " left behind") end
        check(w:find(function(i) return i.Name == "Float_shoot" end) ~= nil, name .. ": the floating buttons exist")
        check(w:find(function(i) return i.ClassName == "TextLabel" and (i.Text or ""):find("WindUI could not start", 1, true) end) ~= nil, name .. ": a toast says WindUI could not start")
        local found
        for _, l in ipairs(w.genv.__WraithsHub.Log) do if l:find("WindUI", 1, true) then found = true end end
        check(found, name .. ": the reason is in the log (Debug tab)")
        check(#w.errors == 0, name .. ": no error escaped a handler: " .. table.concat(w.errors, " | "):sub(1, 300))
        check(#w.warns == 0, name .. ": no warn(): " .. table.concat(w.warns, " | "):sub(1, 300))
    end

    -- b. the saved menu style
    local w2 = newGame({gethui = true}, {ui = "Classic"})
    boot(w2, 1.0)
    check(win(w2) ~= nil and win(w2).Backend ~= "WindUI" and count(w2, "WindUI") == 0, "ui = Classic in the saved config starts the classic menu")
    clean(w2, "classic by config")

    -- c. unload removes everything; running the script twice leaves one menu
    local w3 = newGame(); boot(w3, 1.0)
    w3.genv.__WraithsHub = w3.genv.__WraithsHub
    boot(w3, 1.0)
    check(count(w3, "WindUI") == 1 and count(w3, "WraithsHubWindow_Buttons") == 1, "a second run replaces the first menu instead of stacking")
    el(w3, "Unload the hub").Click(); w3:run(0.5)
    local left = {}
    for _, n in ipairs(guiNames(w3)) do if n:find("WindUI") or n:find("WraithsHub") then left[#left + 1] = n end end
    check(#left == 0, "unloading removes every GUI of the hub: " .. table.concat(left, ","))
    check(w3.genv.__WraithsHub == nil, "and the session")
    clean(w3, "unload")
end

-- the whole thing on the WindUI menu, in the simulated round (tests/mm2_sim.lua): the hub finds the murderer and the SHOOT button kills a runner
section("played end to end on WindUI (simulated round)")
do
    local Sim = MM2_SIM
    local sim = Sim.new{ping = 100, gethui = true, world = {gethui = true}}
    sim:spawn("Me", {pos = {0, 3, 0}})
    sim:spawn("Alice", {pos = {30, 3, -40}, move = {kind = "line", speed = 15, dx = 0, dz = -1}})
    sim:spawn("Cy", {pos = {-30, 3, -20}})
    sim:startRound{murderer = "Alice", sheriff = "Me"}
    boot(sim.w, 1.5)
    sim.w:run(0.5)
    check(win(sim.w) and win(sim.w).Backend == "WindUI", "the menu is WindUI")
    sim:look(sim.v3(30, 3, -40)); sim:run(0.2)
    sim.w:tap(sim.w:button("Float_shoot"), 1050, 160); sim:run(2.0)
    check(sim:dead("Alice"), "SHOOT on the WindUI build kills the running murderer")
    check(sim.stats.friendly == 0 and not sim:dead("Me"), "...and nobody else")
    clean(sim.w, "wind game")

    local sim2 = Sim.new{ping = 100, knifeSpeed = 80, world = {gethui = true}}
    sim2:spawn("Me", {pos = {0, 3, 0}}); sim2:spawn("Bob", {pos = {0, 3, -35}}); sim2:spawn("Cy", {pos = {50, 3, 50}})
    sim2:preset({knifeSpeed = 80})
    sim2:startRound{murderer = "Me", sheriff = "Cy"}
    boot(sim2.w, 1.5)
    sim2:look(sim2.v3(0, 3, -35)); sim2:run(0.2)
    sim2.w:tap(sim2.w:button("Float_throw"), 1050, 260); sim2:run(2.0)
    check(sim2:dead("Bob"), "THROW on the WindUI build kills a standing target")
    clean(sim2.w, "wind game knife")
end

print(string.format("\n%d checks passed, %d failed", passes, #failures))
for _, f in ipairs(failures) do print("FAIL  " .. f) end
if #failures > 0 then os.exit(1) end
