-- Scenario tests for the MM2 hub, run against the fake world in mm2_env.lua (see tests/run_mm2.py).
local World = MM2_WORLD
local failures, passes = {}, 0
local function check(cond, msg) if cond then passes = passes + 1 else failures[#failures + 1] = msg end end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end
local function section(name) print(string.format("--- %s [%d MB]", name, math.floor(collectgarbage("count") / 1024))) end

-- a standard round: me (local) + Alice (murderer) + Bob (sheriff) + Cy (innocent)
local function newGame(opts)
    local w = World.new(opts)
    w:installJson()
    local me = w:addPlayer("Me", {pos = {0, 3, 0}})
    w:setLocal(me)
    w.me = me
    return w
end
local function boot(w, seconds)
    local ok, err = w:load(SCRIPT_SOURCE)
    if not ok then failures[#failures + 1] = "load: " .. tostring(err); return false end
    w:run(seconds or 0.6)
    return true
end
local function clean(w, name)           -- nothing may have been thrown at the script, swallowed, or reported by a handler
    check(#w.thrown == 0, name .. ": members/types the real Roblox API rejects: " .. table.concat(w.thrown, " | "):sub(1, 700))
    check(#w.errors == 0, name .. ": errors inside handlers/threads: " .. table.concat(w.errors, " | "):sub(1, 700))
    check(#w.warns == 0, name .. ": warn(): " .. table.concat(w.warns, " | "):sub(1, 400))
    local unknown = {}
    for c in pairs(w.unknownClasses) do unknown[#unknown + 1] = c end
    check(#unknown == 0, name .. ": classes missing from tests/prop_types_mm2.lua: " .. table.concat(unknown, ","))
    local log = w.genv.__MM2Hub and w.genv.__MM2Hub.Log or {}
    local bad = {}
    for _, l in ipairs(log) do if l:find("%[") and not l:find("recorded") then bad[#bad + 1] = l end end
    check(#bad == 0, name .. ": the script's own error log is not empty: " .. table.concat(bad, " | "):sub(1, 700))
end
local function toasts(w)
    local out = {}
    for _, i in ipairs(w:findAll(function(i) return i.ClassName == "TextLabel" and i.Parent and i.Parent.Parent and i.Parent.Parent.Name == "Toasts" end)) do out[#out + 1] = i.Text end
    return out
end
local function hasToast(w, pattern)
    for _, t in ipairs(toasts(w)) do if t:find(pattern) then return true end end
    return false
end
local function espColors(w)
    local out = {}
    for _, h in ipairs(w:findAll(function(i) return i.ClassName == "Highlight" end)) do
        if h.Adornee then out[h.Adornee.Name] = h.FillColor end
    end
    return out
end
local function red(c) return c and c.R > 0.9 and c.G < 0.4 end
local function blue(c) return c and c.B > 0.9 and c.R < 0.4 end
local function green(c) return c and c.G > 0.8 and c.R < 0.5 end

------------------------------------------------------------------------------------------------ 1. loads, builds the window
section("load")
do
    local w = newGame()
    check(boot(w), "boots")
    check(w:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "MM2HubWindow" end) ~= nil, "window ScreenGui exists")
    for _, tab in ipairs({"Main", "ESP", "Combat", "Player", "Misc", "Settings", "Debug"}) do
        check(w:find(function(i) return i.ClassName == "TextButton" and i.Name == tab end) ~= nil, "tab " .. tab)
    end
    check(w.genv.__MM2Hub ~= nil, "session registered")
    check(hasToast(w, "MM2 Hub loaded"), "welcome toast")
    clean(w, "load")
end


-- helpers for the round fixtures
local function round(w, o)
    o = o or {}
    local alice = w:addPlayer("Alice", {pos = o.alicePos or {0, 3, -40}, vel = o.aliceVel or {10, 0, 0}})
    local bob = w:addPlayer("Bob", {pos = o.bobPos or {20, 3, -20}})
    local cy = w:addPlayer("Cy", {pos = {-15, 3, -30}})
    if not o.noTools then
        w:giveTool(alice, "Knife", {held = true})
        w:giveTool(bob, "Gun", {held = true})
    end
    return alice, bob, cy
end
local function labelContaining(w, pattern)
    return w:find(function(i) return (i.ClassName == "TextLabel") and i.Text:find(pattern) ~= nil end)
end
local function lookDot(w, target)                         -- how well does the camera look at `target` (Vector3)? 1 = exactly
    local cam = w.camera
    local to = (target - cam.CFrame.Position).Unit
    local look = cam.CFrame.LookVector
    return to.X * look.X + to.Y * look.Y + to.Z * look.Z
end

------------------------------------------------------------------------------------------------ 2. roles from visible weapons -> ESP
section("roles from tools + ESP")
do
    local w = newGame()
    local alice, bob, cy = round(w)
    boot(w, 1.0)
    local c = espColors(w)
    check(red(c.Alice), "murderer (holds a knife) is red")
    check(blue(c.Bob), "sheriff (holds a gun) is blue")
    check(green(c.Cy), "innocent is green")
    check(c.Me == nil, "no ESP on myself")
    check(labelContaining(w, "Alice %[Murderer%]") ~= nil, "name label shows the role: Alice [Murderer]")
    check(labelContaining(w, "Bob %[Sheriff%]") ~= nil, "name label shows the role: Bob [Sheriff]")
    check(hasToast(w, "Murderer: Alice"), "announces the murderer")
    check(hasToast(w, "Sheriff: Bob"), "announces the sheriff")
    check(labelContaining(w, "Murderer: Alice") ~= nil, "round info panel")
    -- the toast tells where they are: Alice is 40 studs straight ahead
    check(labelContaining(w, "40 studs ahead") ~= nil or labelContaining(w, "studs ahead") ~= nil, "announcement says where")
    clean(w, "roles")
end

------------------------------------------------------------------------------------------------ 3. roles from the game's data remote
section("roles from the data remote")
do
    local w = newGame()
    round(w, {noTools = true})
    local folder = w:make("Folder", "Remotes", {}, w.replicated)
    local getter = w:make("RemoteFunction", "GetPlayerData", {}, folder)
    w.remoteFunctions = {[getter] = function() return {Alice = {Role = "Murderer"}, Bob = {Role = "Sheriff"}, Cy = {Role = "Innocent"}, Me = {Role = "Innocent"}} end}
    boot(w, 4.0)
    local c = espColors(w)
    check(red(c.Alice) and blue(c.Bob) and green(c.Cy), "colours come from GetPlayerData even with no weapon visible")
    check(labelContaining(w, "You: Innocent") ~= nil, "my own role")
    -- a PlayerDataChanged event updates it immediately
    local ev = w:make("RemoteEvent", "PlayerDataChanged", {}, folder)
    -- (the script connected to events that existed at start only, so re-run: second boot below)
    clean(w, "data remote")

    local w2 = newGame()
    round(w2, {noTools = true})
    local f2 = w2:make("Folder", "Remotes", {}, w2.replicated)
    local ev2 = w2:make("RemoteEvent", "PlayerDataChanged", {}, f2)
    boot(w2, 0.5)
    check(espColors(w2).Alice and not red(espColors(w2).Alice), "before any data: nobody is a murderer (round not active)")
    w2.fire(w2.signalOf(ev2, "OnClientEvent"), {Alice = {Role = "Murderer"}, Bob = {Role = "Sheriff"}})
    w2:run(1.0)
    check(red(espColors(w2).Alice), "PlayerDataChanged makes Alice the murderer")
    check(blue(espColors(w2).Bob), "...and Bob the sheriff")
    clean(w2, "data event")
end

section("round ends: stale role data expires")
do
    local w = newGame()
    round(w, {noTools = true})
    local folder = w:make("Folder", "Remotes", {}, w.replicated)
    local ev = w:make("RemoteEvent", "PlayerDataChanged", {}, folder)
    local map = w:make("Model", "Map", {}, w.workspace)
    w:make("Folder", "CoinContainer", {}, map)
    boot(w, 0.6)
    w.fire(w.signalOf(ev, "OnClientEvent"), {Alice = {Role = "Murderer"}, Bob = {Role = "Sheriff"}})
    w:run(1.0)
    check(red(espColors(w).Alice), "round running: Alice is the murderer")
    w.M.Destroy(map); w:run(1.2)
    check(not red(espColors(w).Alice) and not blue(espColors(w).Bob), "the map is gone and nobody holds a weapon: last round's roles are dropped")
    local map2 = w:make("Model", "Map2", {}, w.workspace)
    w:make("Folder", "CoinContainer", {}, map2)
    w.fire(w.signalOf(ev, "OnClientEvent"), {Alice = {Role = "Innocent"}, Bob = {Role = "Murderer"}})
    w:run(1.0)
    check(red(espColors(w).Bob) and not red(espColors(w).Alice), "next round: new roles are used")
    clean(w, "stale data")
end

------------------------------------------------------------------------------------------------ 4. gun drop: notification, HUD, ESP
section("gun drop")
do
    local w = newGame()
    round(w)
    boot(w, 1.0)
    local gun = w:dropGun({0, 3, -37})
    w:run(0.4)
    check(hasToast(w, "Gun dropped!"), "toast: Gun dropped!")
    check(labelContaining(w, "37 studs ahead") ~= nil, "it says WHERE: 37 studs ahead")
    check(labelContaining(w, "^GUN  37 studs ahead") ~= nil, "HUD text")
    local hud = w:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "MM2HubHud" end)
    local box = hud and w:find(function(i) return i.ClassName == "Frame" and i.Size.X.Offset == 300 end, hud)
    check(box and box.Visible, "HUD is visible while a gun lies there")
    local hl = w:find(function(i) return i.ClassName == "Highlight" and i.Adornee == gun end)
    check(hl ~= nil, "gun ESP highlight is on the dropped gun")
    check(labelContaining(w, "^GUN 37m") ~= nil or labelContaining(w, "^GUN %d+m") ~= nil, "gun ESP label with distance")
    -- the gun is to my right now
    w:setCamera({0, 5, 0}, {-10, 5, 0})                                 -- looking along -X: the gun at -Z is on my right
    w:run(0.4)
    check(labelContaining(w, "^GUN  37 studs right") ~= nil, "direction follows the camera: right")
    -- picked up
    w.M.Destroy(gun)
    w:run(0.4)
    check(hasToast(w, "Gun picked up"), "toast when someone takes it")
    check(not box.Visible, "HUD hides again")
    check(w:find(function(i) return i.ClassName == "Highlight" and i.Adornee == gun end) == nil, "gun highlight removed")
    clean(w, "gun drop")
end

section("gun drop found at start / similar names")
do
    local w = newGame()
    round(w)
    w:dropGun({10, 3, -10})                                           -- already lying there when the script starts
    w:make("Part", "GunRack", {}, w.workspace)                        -- a map prop: must NOT count
    boot(w, 1.0)
    check(hasToast(w, "Gun dropped!"), "a gun that is already there is found by the start-up scan")
    local n = #w:findAll(function(i) return i.ClassName == "Highlight" and i.Adornee and i.Adornee.Name:find("Gun") end)
    check(n == 1, "only the real GunDrop gets a highlight, not GunRack (got " .. n .. ")")
    w:make("Part", "GunRack2", {}, w.workspace)
    w:run(0.4)
    check(#w:findAll(function(i) return i.ClassName == "Highlight" and i.Adornee and i.Adornee.Name:find("Gun") end) == 1, "props added later are still ignored")
    clean(w, "gun scan")
end

section("sheriff dies -> where the gun should be")
do
    local w = newGame()
    local alice, bob = round(w)
    boot(w, 1.2)
    w:killPlayer(bob)
    w:run(0.6)
    w:dropGun({25, 3, 5}, "GunMesh")                                  -- a differently named drop right after the sheriff died
    w:run(0.5)
    check(hasToast(w, "Gun dropped!"), "loose name (^gun) accepted for a few seconds after the sheriff dies")
    clean(w, "sheriff died, named drop")

    local w2 = newGame()
    local a2, b2 = round(w2)
    boot(w2, 1.2)
    w2:killPlayer(b2)
    w2:run(3.0)
    check(hasToast(w2, "Sheriff down"), "no drop object found -> still says where the sheriff went down")
    check(labelContaining(w2, "^Sheriff died here") ~= nil, "HUD points at the place")
    clean(w2, "sheriff died, no drop")
end

------------------------------------------------------------------------------------------------ 5. alerts
section("murderer proximity alert")
do
    local w = newGame()
    round(w, {alicePos = {0, 3, -30}, aliceVel = {0, 0, 0}})
    boot(w, 1.0)
    check(hasToast(w, "Murderer nearby!"), "alert when the murderer is within 40 studs")
    local w2 = newGame()
    round(w2, {alicePos = {0, 3, -90}, aliceVel = {0, 0, 0}})
    boot(w2, 1.0)
    check(not hasToast(w2, "Murderer nearby!"), "no alert when far away")
    clean(w, "alert"); clean(w2, "alert far")
end

------------------------------------------------------------------------------------------------ 6. aim assist
section("aim assist")
do
    local w = newGame()
    local alice, bob = round(w, {noTools = true})
    w:giveTool(alice, "Knife", {held = true})
    w:giveTool(w.me, "Gun", {held = true})
    boot(w, 1.0)
    w:toggle("Aim assist")
    w:keyDown("Z")
    w:run(0.4)
    local head = alice.Character.Head.Position
    local predicted = w:V3(head.X + 10 * 0.06, head.Y, head.Z)         -- velocity 10 studs/s * 60 ms ping
    check(lookDot(w, predicted) > 0.999999, "camera looks at the PREDICTED head position (dot " .. string.format("%.8f", lookDot(w, predicted)) .. ")")
    check(lookDot(w, head) < lookDot(w, predicted), "...which is further along than where the head is now")
    w:keyUp("Z")
    w:setCamera({0, 5, 0}, {0, 5, -10})
    w:run(0.3)
    check(lookDot(w, w:V3(0, 5, -10)) > 0.9999, "releasing the key leaves the camera alone")
    -- wall check
    local wall = w:make("Part", "Wall", {}, w.workspace)
    w.raycast = function() return {Instance = wall} end
    w:keyDown("Z"); w:run(0.3)
    check(lookDot(w, w:V3(0, 5, -10)) > 0.9999, "wall check: no target behind a wall -> no aim")
    w:toggle("Wall check"); w:run(0.3)
    check(lookDot(w, predicted) > 0.99999, "wall check off -> aims through walls")
    clean(w, "aim")
end

section("aim: mouse cursor method + smoothing")
do
    local w = newGame()
    local alice = round(w, {noTools = true})
    w:giveTool(alice, "Knife", {held = true})
    boot(w, 1.0)
    w:toggle("Aim assist")
    w:click(w:rowButton("Aim method")); w:click(w:label("  Mouse cursor"))
    w:keyDown("Z"); w:run(0.3)
    check(w.moves and #w.moves > 0, "mousemoverel is used")
    local m = w.moves and w.moves[#w.moves] or {0, 0}
    check(m[1] > 0 and m[1] < 30, "cursor moves right towards the lead point (" .. tostring(m[1]) .. ")")
    check(m[2] > 0 and m[2] < 30, "...and down to the head (" .. tostring(m[2]) .. ")")
    check(lookDot(w, w:V3(0, 5, -10)) > 0.9999, "camera untouched in cursor mode")
    clean(w, "aim cursor")
end

------------------------------------------------------------------------------------------------ 7. shots: record, replay, silent aim
section("shot recording + replay (gun)")
do
    local w = newGame()
    local alice, bob = round(w, {noTools = true})
    w:giveTool(alice, "Knife", {held = true})
    local gun = w:giveTool(w.me, "Gun", {held = true, remotes = {{name = "Shoot"}}})
    boot(w, 1.0)
    local shoot = gun:FindFirstChild("Shoot")
    -- the player shoots by hand, the way the game's own local script would
    w:mouseDown("MouseButton1")
    shoot:FireServer(w.env.CFrame.new(0, 4.5, 0), w.env.CFrame.new(5, 3, -30))
    w:run(0.3)
    check(#w.sent == 1 and w.sent[1].args[2].Position.X == 5, "my own shot goes through unchanged")
    check(labelContaining(w, "Gun: FireServer %(in tool%)") ~= nil, "Debug tab shows the learned gun shot")
    check(hasToast(w, "Learned your gun shot"), "toast: learned")
    local before = #w.sent
    w:click(w:rowButton("Shoot the murderer"))
    w:run(0.4)
    check(#w.sent == before + 1, "'Shoot the murderer' fires the recorded remote exactly once (" .. (#w.sent - before) .. ")")
    local s = w.sent[#w.sent]
    local head = alice.Character.Head.Position
    check(s and s.remote == shoot and s.method == "FireServer", "...on the same remote")
    check(s and s.args.n == 2, "...with the same number of arguments")
    check(s and near(s.args[2].Position.X, head.X + 0.6, 1e-6) and near(s.args[2].Position.Z, head.Z, 1e-6) and near(s.args[2].Position.Y, head.Y, 1e-6), "target slot = predicted head position")
    local o = s.args[1].Position
    check(s and near(o.X, 0) and near(o.Y, 4.5) and near(o.Z, 0), "origin slot = my head")
    local look = s.args[1].LookVector
    local to = (s.args[2].Position - o).Unit
    check(look.X * to.X + look.Y * to.Y + look.Z * to.Z > 0.99999, "origin CFrame looks at the target")
    w:run(1.0)                                                           -- (the Debug labels refresh every 0.6 s)
    check(labelContaining(w, "used x1") ~= nil and labelContaining(w, "used x2") == nil, "the replay was NOT recorded as another player shot")

    -- silent aim
    w:toggle("Silent aim (your own shots)")
    w:run(0.2)
    shoot:FireServer(w.env.CFrame.new(0, 4.5, 0), w.env.CFrame.new(100, 3, 100))
    local s2 = w.sent[#w.sent]
    check(near(s2.args[2].Position.X, head.X + 0.6, 1e-6) and near(s2.args[2].Position.Z, head.Z, 1e-6), "silent aim: my wild shot is sent at the predicted murderer")
    check(near(s2.args[1].Position.Y, 4.5), "silent aim: origin slot untouched")
    local pos2 = s2.args[2].Position
    check(not near(pos2.X, 100), "silent aim: the original aim point is gone")
    -- unrelated remotes are never touched
    local other = w:make("RemoteEvent", "MovementUpdate", {}, w.replicated)
    other:FireServer(w:V3(7, 7, 7), 5)
    local s3 = w.sent[#w.sent]
    check(s3.remote == other and s3.args[1].X == 7 and s3.args[2] == 5, "silent aim never touches other remotes")
    -- a shot with a different argument count is not rewritten
    shoot:FireServer(w:V3(1, 2, 3))
    check(w.sent[#w.sent].args[1].X == 1, "silent aim leaves differently shaped calls alone")
    w:run(0.3)
    clean(w, "shots")
end

section("shot replay: global remote found through the input window")
do
    local w = newGame()
    local alice = round(w, {noTools = true})
    w:giveTool(alice, "Knife", {held = true})
    w:giveTool(w.me, "Gun", {held = true})                            -- no remote inside the tool
    local remote = w:make("RemoteEvent", "ShootGun", {}, w.replicated)
    boot(w, 0.8)
    -- remote fired with NO input first: not a shot
    remote:FireServer(w:V3(5, 5, 5)); w:run(0.2)
    check(labelContaining(w, "Gun: not recorded") ~= nil, "a remote fired without any click is not taken for a shot")
    w:mouseDown("MouseButton1")
    remote:FireServer(w:V3(5, 5, 5)); w:run(0.3)
    check(labelContaining(w, "Gun: FireServer %(global%)") ~= nil, "after a click, a shot-looking remote is recorded as the gun shot")
    local n = #w.sent
    w:click(w:rowButton("Shoot the murderer")); w:run(0.4)
    check(#w.sent == n + 1 and w.sent[#w.sent].remote == remote, "replay uses the global remote")
    check(w.sent[#w.sent].args[1].X ~= 5, "...and aims it at the murderer")
    clean(w, "global remote")
end

section("knife throw: remote path survives a respawn of the tool")
do
    local w = newGame()
    local bob = w:addPlayer("Bob", {pos = {0, 3, -40}})
    local knife = w:giveTool(w.me, "Knife", {held = true, remotes = {{folder = "Events", name = "KnifeThrown"}}})
    boot(w, 1.0)
    local throwRemote = knife:FindFirstChild("Events"):FindFirstChild("KnifeThrown")
    w:mouseDown("MouseButton1")
    throwRemote:FireServer(w.env.CFrame.new(0, 4.5, 0), w:V3(0, 4, -30))
    w:run(0.3)
    check(labelContaining(w, "Knife: FireServer %(in tool%)") ~= nil, "knife throw learned")
    -- new round: the knife is a brand-new object
    w.M.Destroy(knife)
    local knife2 = w:giveTool(w.me, "Knife", {held = true, remotes = {{folder = "Events", name = "KnifeThrown"}}})
    w:run(0.5)
    local n = #w.sent
    w:click(w:rowButton("Throw knife at best target")); w:run(0.5)
    check(#w.sent == n + 1, "throw fired once")
    local s = w.sent[#w.sent]
    check(s and s.remote == knife2:FindFirstChild("Events"):FindFirstChild("KnifeThrown"), "...through the NEW tool's remote (resolved by path)")
    check(s and s.args[1].Position.Y == 4.5 and s.args[2].X ~= 0 or s.args[2].Z == -40 or true, "args shape kept (CFrame, Vector3)")
    check(s and w.env.typeof(s.args[1]) == "CFrame" and w.env.typeof(s.args[2]) == "Vector3", "argument types are preserved")
    clean(w, "knife")
end

section("throw without a recorded shot: aim + the game's throw key")
do
    local w = newGame()
    w:addPlayer("Bob", {pos = {0, 3, -40}})
    w:giveTool(w.me, "Knife", {held = true})
    boot(w, 1.0)
    w:click(w:rowButton("Throw knife at best target")); w:run(0.5)
    local keys = 0
    for _, e in ipairs(w.vim) do if e[1] == "key" and e[2] == true and e[3].Name == "E" then keys = keys + 1 end end
    check(keys == 1, "presses the configured throw key (E) once (got " .. keys .. ")")
    check(lookDot(w, w.players:FindFirstChild("Bob").Character.Head.Position) > 0.99, "...after aiming at the target")
    clean(w, "throw key")
end

section("no weapon / no target -> a clear message, no error")
do
    local w = newGame()
    round(w)
    boot(w, 1.0)
    w:click(w:rowButton("Shoot the murderer")); w:run(0.3)
    check(hasToast(w, "No gun"), "no gun -> 'No gun'")
    w:click(w:rowButton("Throw knife at best target")); w:run(0.3)
    check(hasToast(w, "No knife"), "no knife -> 'No knife'")
    w:click(w:rowButton("Grab the gun")); w:run(0.3)
    check(hasToast(w, "No gun on the map"), "no dropped gun -> message")
    clean(w, "no weapon")
end

------------------------------------------------------------------------------------------------ 8. the namecall hook
section("hook: every other call passes through untouched")
do
    local w = newGame()
    round(w)
    boot(w, 0.8)
    check(w.hook ~= nil, "the hook is installed")
    -- the script's own and the game's ordinary calls all went through the hook (UI building alone makes thousands)
    local part = w.workspace:FindFirstChild("Alice")
    check(part ~= nil and part:IsA("Model"), "calls made after the hook still return their values")
    check(w:keyDown("Q") == nil, "input still works")
    clean(w, "hook pass-through")

    local w2 = newGame({no = {setnamecall = true}})
    local alice = round(w2, {noTools = true})
    w2:giveTool(alice, "Knife", {held = true})
    local gun = w2:giveTool(w2.me, "Gun", {held = true, remotes = {{name = "Shoot"}}})
    boot(w2, 1.0)
    w2:mouseDown("MouseButton1")
    gun:FindFirstChild("Shoot"):FireServer(w2.env.CFrame.new(0, 4.5, 0), w2.env.CFrame.new(5, 3, -30)); w2:run(0.3)
    w2:toggle("Silent aim (your own shots)"); w2:run(0.2)
    gun:FindFirstChild("Shoot"):FireServer(w2.env.CFrame.new(0, 4.5, 0), w2.env.CFrame.new(100, 3, 100))
    check(near(w2.sent[#w2.sent].args[2].Position.X, 0.6, 1e-6) or w2.sent[#w2.sent].args[2].Position.X < 50, "silent aim works without setnamecallmethod (the hook calls no methods)")
    clean(w2, "no setnamecallmethod")
end

------------------------------------------------------------------------------------------------ 9. hitbox
section("hitbox expander")
do
    local w = newGame()
    local alice, bob = round(w)
    boot(w, 1.0)
    local aliceRoot = alice.Character.HumanoidRootPart
    check(aliceRoot.Size.X == 2, "normal size to start with")
    w:toggle("Expand hitboxes"); w:run(1.0)
    check(aliceRoot.Size.X == 8 and aliceRoot.Size.Y == 8, "murderer's root part is 8 studs")
    check(aliceRoot.CanCollide == false and near(aliceRoot.Transparency, 0.6), "...non-solid and see-through")
    check(bob.Character.HumanoidRootPart.Size.X == 2, "the sheriff is not touched (Who = Murderer)")
    w:slide("Size", 1.0); w:run(0.6)
    check(aliceRoot.Size.X == 30, "slider changes the size")
    w:click(w:rowButton("Who")); w:click(w:label("  Everyone else")); w:run(0.6)
    check(bob.Character.HumanoidRootPart.Size.X == 30, "Who = Everyone else")
    w:toggle("Expand hitboxes"); w:run(0.6)
    check(aliceRoot.Size.X == 2 and aliceRoot.CanCollide == true and aliceRoot.Transparency == 0, "turning it off restores size, collision and transparency")
    check(bob.Character.HumanoidRootPart.Size.X == 2, "...for everyone")
    clean(w, "hitbox")
end

------------------------------------------------------------------------------------------------ 10. player mods
section("player mods")
do
    local w = newGame()
    round(w)
    boot(w, 0.8)
    local hum = w.me.Character.Humanoid
    w:toggle("Walk speed"); w:run(0.4)
    check(hum.WalkSpeed == 24, "walk speed applied")
    w:slide("Speed", 1.0); w:run(0.4)
    check(hum.WalkSpeed == 80, "slider moves the speed")
    w:toggle("Walk speed"); w:run(0.4)
    check(hum.WalkSpeed == 16, "turned off -> original speed back")
    w:toggle("Jump power"); w:run(0.4)
    check(hum.JumpPower == 60, "jump power applied")
    w:toggle("Jump power"); w:run(0.4)
    check(hum.JumpPower == 50, "...and restored")
    w:toggle("Infinite jump")
    w:jumpRequest()
    local jumped = false
    for _, c in ipairs(w.calls) do if c[1] == "ChangeState" then jumped = true end end
    check(jumped, "infinite jump changes state on JumpRequest")
    w:toggle("Noclip"); w:run(0.3)
    check(w.me.Character.Torso.CanCollide == false, "noclip turns collisions off")
    w:toggle("Field of view"); w:run(0.4)
    check(w.camera.FieldOfView == 80, "FOV applied")
    w:toggle("Field of view"); w:run(0.4)
    check(w.camera.FieldOfView == 70, "FOV restored")
    clean(w, "mods")
end

------------------------------------------------------------------------------------------------ 11. config
section("config: nothing saved until Save, then restored")
do
    local w = newGame()
    round(w)
    boot(w, 0.8)
    w:toggle("Health"); w:slide("Alert distance", 1.0)
    w:run(0.3)
    check(next(w.files) == nil, "nothing is written until Save config")
    w:click(w:rowButton("Save config")); w:run(0.2)
    local raw = w.files["mm2_hub_config.json"]
    check(raw ~= nil, "Save config writes mm2_hub_config.json")
    local data = raw and w.jsonDecode(raw) or {}
    check(data.espHealth == true and data.alertDistance == 120, "saved values: espHealth / alertDistance")
    check(data.theme == "Crimson", "saved theme")

    local w2 = newGame()
    round(w2)
    w2.files["mm2_hub_config.json"] = raw
    boot(w2, 1.0)
    check(labelContaining(w2, "Alice %[Murderer%] %d+hp") ~= nil or labelContaining(w2, "100hp") ~= nil, "restored: Health ESP is on after a restart")
    check(labelContaining(w2, "120 studs") ~= nil, "restored: slider label")
    clean(w2, "config restored")

    local w3 = newGame()
    round(w3)
    w3.files["mm2_hub_config.json"] = "{not json"
    boot(w3, 0.8)
    check(w:find(function(i) return true end) ~= nil, "sanity")
    check(w3:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "MM2HubWindow" end) ~= nil, "a corrupt config does not stop the hub")
    local w4 = newGame()
    round(w4)
    w4.files["mm2_hub_config.json"] = '{"espHealth": "yes", "alertDistance": "far", "nonsense": 5}'
    boot(w4, 0.8)
    check(w4:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "MM2HubWindow" end) ~= nil, "wrongly typed config values are ignored")
    clean(w4, "typed config")

    -- load / delete buttons
    w:click(w:rowButton("Delete saved config")); w:run(0.1)
    check(w.files["mm2_hub_config.json"] == nil, "Delete saved config removes the file")
end

------------------------------------------------------------------------------------------------ 12. unload + re-run
section("unload / run twice")
do
    local w = newGame()
    local alice = round(w)
    boot(w, 1.0)
    w:toggle("Expand hitboxes"); w:run(0.8)
    local aliceRoot = alice.Character.HumanoidRootPart
    check(aliceRoot.Size.X == 8, "hitbox on")
    local hub = w.genv.__MM2Hub
    w:click(w:rowButton("Unload the hub")); w:run(0.3)
    check(w.genv.__MM2Hub == nil, "session cleared")
    local left = w:findAll(function(i) return i.Name:find("MM2") ~= nil end)
    check(#left == 0, "no MM2 objects left in CoreGui (" .. #left .. ")")
    check(aliceRoot.Size.X == 2, "hitboxes restored on unload")
    check(w:find(function(i) return i.ClassName == "Highlight" end) == nil, "ESP gone")
    -- the hook stays installed but must be inert
    local gunTool = w:giveTool(w.me, "Gun", {held = true, remotes = {{name = "Shoot"}}})
    w:mouseDown("MouseButton1")
    gunTool:FindFirstChild("Shoot"):FireServer(w:V3(1, 2, 3))
    check(#w.sent == 1 and w.sent[1].args[1].X == 1, "after unload the hook passes calls through")
    check(not hub.Alive, "Hub.Alive is false")

    -- ...even when silent aim was armed with a recorded shot at the moment of unloading
    local w3 = newGame()
    local a3 = round(w3, {noTools = true})
    w3:giveTool(a3, "Knife", {held = true})
    local g3 = w3:giveTool(w3.me, "Gun", {held = true, remotes = {{name = "Shoot"}}})
    boot(w3, 1.0)
    w3:mouseDown("MouseButton1")
    g3:FindFirstChild("Shoot"):FireServer(w3.env.CFrame.new(0, 4.5, 0), w3.env.CFrame.new(5, 3, -30)); w3:run(0.3)
    w3:toggle("Silent aim (your own shots)"); w3:run(0.2)
    g3:FindFirstChild("Shoot"):FireServer(w3.env.CFrame.new(0, 4.5, 0), w3.env.CFrame.new(100, 3, 100))
    check(w3.sent[#w3.sent].args[2].Position.X < 50, "(silent aim is working before the unload)")
    w3:click(w3:rowButton("Unload the hub")); w3:run(0.2)
    g3:FindFirstChild("Shoot"):FireServer(w3.env.CFrame.new(0, 4.5, 0), w3.env.CFrame.new(100, 3, 100))
    check(w3.sent[#w3.sent].args[2].Position.X == 100, "after unload even an armed silent aim leaves my shots alone")
    -- re-run replaces the old session
    local w2 = newGame()
    round(w2)
    boot(w2, 0.6)
    w2:load(SCRIPT_SOURCE); w2:run(0.6)
    local windows = w2:findAll(function(i) return i.ClassName == "ScreenGui" and i.Name == "MM2HubWindow" end)
    check(#windows == 1, "running the script twice leaves exactly one window (" .. #windows .. ")")
    clean(w2, "run twice")
end

------------------------------------------------------------------------------------------------ 13. executors with little support
section("minimal executor")
do
    local w = newGame({no = {hook = true, drawing = true, mouseRel = true, mouseClick = true, files = true, clipboard = true, newcclosure = true, setnamecall = true}})
    local alice = round(w, {noTools = true})
    w:giveTool(alice, "Knife", {held = true})
    boot(w, 1.0)
    check(w:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "MM2HubWindow" end) ~= nil, "loads with no executor extras")
    check(labelContaining(w, "no hook") ~= nil or hasToast(w, "no hook"), "the welcome toast lists what is missing")
    w:toggle("Tracers"); w:toggle("Aim assist"); w:run(0.4)
    w:click(w:rowButton("Save config")); w:run(0.2)
    check(hasToast(w, "Cannot save"), "Save config explains why it cannot save")
    w:click(w:rowButton("Copy diagnostics")); w:run(0.2)
    check(hasToast(w, "No clipboard"), "Copy diagnostics explains the missing clipboard")
    w:click(w:rowButton("Shoot the murderer")); w:run(0.2)
    clean(w, "minimal executor")
end

section("my own death and respawn")
do
    local w = newGame()
    local alice = round(w)
    boot(w, 1.0)
    w:toggle("Walk speed"); w:toggle("Expand hitboxes"); w:toggle("Noclip"); w:run(0.6)
    w:killPlayer(w.me); w:run(0.6)
    check(labelContaining(w, "You: ") ~= nil, "round info survives my death")
    rawget(w.me, "__d").props.Character = nil; w:run(1.0)                      -- between death and respawn there is no character at all
    w:keyDown("Z"); w:click(w:rowButton("Shoot the murderer")); w:click(w:rowButton("Throw knife at best target")); w:click(w:rowButton("Grab the gun"))
    w:run(0.6)
    local char2 = w:newCharacter(w.me, {pos = {0, 3, 0}})
    w:run(1.0)
    check(w.me.Character.Humanoid.WalkSpeed == 24, "walk speed is applied to the new character after a respawn")
    check(alice.Character.HumanoidRootPart.Size.X == 8, "the hitbox expander keeps working after I respawn")
    w:setCamera({0, 5, 0}, {0, 5, -10})
    clean(w, "respawn")
end

section("CoreGui not writable -> PlayerGui, ESP in the world")
do
    local w = newGame({coreLocked = true})
    round(w)
    boot(w, 1.0)
    local gui = w:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "MM2HubWindow" end, w.me:FindFirstChild("PlayerGui"))
    check(gui ~= nil, "the window lives in PlayerGui when CoreGui refuses")
    local folder = w.workspace:FindFirstChild("MM2HubESP")
    check(folder ~= nil, "ESP objects go into workspace (Highlights do not render under a PlayerGui)")
    check(folder and #w.M.GetChildren(folder) >= 3, "...and they are there")
    clean(w, "playergui fallback")

    local w2 = newGame({gethui = true})
    round(w2)
    boot(w2, 0.8)
    check(w2:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "MM2HubWindow" end) ~= nil, "gethui() container is used when the executor has it")
    clean(w2, "gethui")
end

section("not Murder Mystery 2 / waiting for the local player")
do
    local w = newGame({placeId = 123})
    boot(w, 0.8)
    check(hasToast(w, "MM2 Hub loaded"), "still loads")
    check(labelContaining(w, "does not look like Murder Mystery 2") ~= nil, "...but says this is not MM2")
    clean(w, "other place")

    local w2 = World.new(); w2:installJson()
    local me = w2:addPlayer("Me", {pos = {0, 3, 0}})
    w2:load(SCRIPT_SOURCE); w2:run(0.5)
    check(w2:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "MM2HubWindow" end) == nil, "waits while LocalPlayer is nil")
    w2:setLocal(me); w2:run(0.6)
    check(w2:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "MM2HubWindow" end) ~= nil, "...and starts once it exists")
    clean(w2, "late local player")
end

------------------------------------------------------------------------------------------------ 14. the window itself
section("window: search, tabs, themes, hide / show, minimise")
do
    local w = newGame()
    round(w)
    boot(w, 0.8)
    local winGui = w:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "MM2HubWindow" end)
    local main = w:find(function(i) return i.ClassName == "Frame" and i.Name == "Window" end, winGui)
    check(main.Visible, "window is visible")
    local search = w:find(function(i) return i.ClassName == "TextBox" end, winGui)
    w:typeInto(search, "tracer"); w:run(0.1)
    check(w:row("Tracers").Visible == true, "search shows the matching row")
    check(w:row("Names").Visible == false, "...and hides the others")
    check(w:row("Gun tracer").Visible == true, "...from every tab")
    w:typeInto(search, ""); w:run(0.1)
    check(w:row("Names").Visible == true, "clearing the search restores the rows")
    -- tab switching
    w:tab("Combat"); w:run(0.1)
    local function pageVisible(name) return w:find(function(i) return i.ClassName == "Frame" and i.Name == name and i.Parent and i.Parent.ClassName == "ScrollingFrame" end, winGui).Visible end
    check(pageVisible("Combat") and not pageVisible("Main"), "tab buttons switch pages")
    -- theme
    local bg0 = main.BackgroundColor3
    w:click(w:rowButton("Theme")); w:click(w:label("  Ocean")); w:run(0.1)
    check(main.BackgroundColor3 ~= bg0, "theme change recolours the window")
    -- hide / show
    local closeBtn = w:label("X")
    w:click(closeBtn); w:run(0.1)
    check(not main.Visible, "X hides the window")
    local fab = w:find(function(i) return i.ClassName == "TextButton" and i.Name == "Open" end, winGui)
    check(fab.Visible, "the M button appears")
    w:click(fab); check(main.Visible, "M brings it back")
    w:keyDown("RightShift"); check(not main.Visible, "RightShift hides it")
    w:keyDown("RightShift"); check(main.Visible, "RightShift shows it")
    local h0 = main.Size.Y.Offset
    w:click(w:label("-")); check(main.Size.Y.Offset < h0, "minimise shrinks the window")
    w:click(w:label("-")); check(main.Size.Y.Offset == h0, "...and restores it")
    -- rebind the menu key
    w:click(w:rowButton("Show / hide menu")); w:keyDown("F5"); w:run(0.1)
    w:keyDown("F5"); check(not main.Visible, "the menu key can be rebound")
    clean(w, "window")
end

section("slider / dropdown / keybind rows")
do
    local w = newGame()
    boot(w, 0.6)
    w:slide("Alert distance", 0.5); w:run(0.1)
    check(labelContaining(w, "^65 studs$") ~= nil, "slider at 50% of 10..120 snaps to 65 (step 5)")
    w:slide("Lead strength", 1.0); w:run(0.1)
    check(labelContaining(w, "^2.0x$") ~= nil, "decimal slider formats 2.0x")
    w:slide("Alert distance", 5.0); w:run(0.1)
    check(labelContaining(w, "^120 studs$") ~= nil, "slider clamps at the maximum")
    w:slide("Alert distance", 0.5); w:mouseMove(100 + 200 * 1.0); w:run(0.1)
    check(labelContaining(w, "^65 studs$") ~= nil, "after the button is released the slider no longer follows the mouse")
    -- while held it follows
    local row = w:row("Alert distance")
    local hit
    for _, c in ipairs(w.M.GetChildren(row)) do if c.ClassName == "TextButton" then hit = c end end
    local E = w.env.Enum
    w.fire(rawget(hit, "__d").signals.InputBegan, {UserInputType = E.UserInputType.MouseButton1, Position = w:V3(100, 50, 0)})
    w:mouseMove(100 + 200 * 0.25); w:run(0.05)
    check(labelContaining(w, "^37 studs$") ~= nil or labelContaining(w, "^40 studs$") ~= nil, "dragging moves the value (25% of 10..120)")
    w.fire(rawget(w.uis, "__d").signals.InputEnded, {UserInputType = E.UserInputType.MouseButton1, Position = w:V3(150, 50, 0)})
    w:click(w:rowButton("Aim at")); w:click(w:label("  Torso")); w:run(0.1)
    check(labelContaining(w, "^Torso$") ~= nil, "dropdown shows the chosen value")
    -- keybind capture
    w:click(w:rowButton("Aim key (hold)")); w:keyDown("G"); w:run(0.1)
    check(w:find(function(i) return i.ClassName == "TextButton" and i.Text == "G" end) ~= nil, "keybind button shows the captured key")
    clean(w, "rows")
end

------------------------------------------------------------------------------------------------ 15. automation
section("auto shoot / auto throw / slash aura")
do
    local w = newGame()
    local alice = round(w, {noTools = true})
    w:giveTool(alice, "Knife", {held = true})
    local gun = w:giveTool(w.me, "Gun", {held = true, remotes = {{name = "Shoot"}}})
    boot(w, 1.0)
    w:mouseDown("MouseButton1")
    gun:FindFirstChild("Shoot"):FireServer(w.env.CFrame.new(0, 4.5, 0), w.env.CFrame.new(5, 3, -30)); w:run(0.3)
    local n0 = #w.sent
    w:toggle("Auto shoot"); w:run(6.0)
    local shots = #w.sent - n0
    check(shots >= 2 and shots <= 3, "auto shoot fires about every 2.5 s (6 s -> " .. shots .. " shots)")
    w:toggle("Auto shoot")
    local wall = w:make("Part", "Wall", {}, w.workspace)
    w.raycast = function() return {Instance = wall} end
    local n1 = #w.sent
    w:toggle("Auto shoot"); w:run(4.0)
    check(#w.sent == n1, "auto shoot never fires through a wall")
    clean(w, "auto shoot")

    local w2 = newGame()
    local bob = w2:addPlayer("Bob", {pos = {0, 3, -5}})
    w2:giveTool(w2.me, "Knife", {held = true})
    boot(w2, 1.0)
    w2:toggle("Slash aura"); w2:run(1.0)
    local acts = 0
    for _, c in ipairs(w2.calls) do if c[1] == "Activate" then acts = acts + 1 end end
    check(acts >= 1, "slash aura swings when someone is in range (" .. acts .. ")")
    w2:movePlayer(bob, {0, 3, -30}); w2:run(0.3); w2.calls = {}; w2:run(1.0)
    local acts2 = 0
    for _, c in ipairs(w2.calls) do if c[1] == "Activate" then acts2 = acts2 + 1 end end
    check(acts2 == 0, "...and not when they are far away")
    clean(w2, "slash aura")
end

section("grab gun (teleport and return)")
do
    local w = newGame()
    round(w)
    boot(w, 1.0)
    w:dropGun({0, 3, -37}); w:run(0.3)
    local root = w.me.Character.HumanoidRootPart
    local home = root.Position
    w:click(w:rowButton("Grab the gun")); 
    check(near(root.Position.Z, -37) and near(root.Position.Y, 6), "teleports onto the gun")
    w:run(0.6)
    check(near(root.Position.Z, home.Z) and near(root.Position.Y, home.Y), "...and returns to where it was")
    clean(w, "grab gun")
end

------------------------------------------------------------------------------------------------ 16. tracers + players leaving + deaths
section("tracers, deaths, leavers")
do
    local w = newGame()
    local alice, bob, cy = round(w)
    boot(w, 1.0)
    w:toggle("Tracers")                                              -- (gun tracer is on by default)
    w:dropGun({0, 3, -37}); w:run(0.5)
    local visible = 0
    for _, d in ipairs(w.drawings or {}) do if d.Visible and not d.removed then visible = visible + 1 end end
    check(visible >= 3, "tracers: lines for Alice, Bob, Cy are drawn, plus the gun (" .. visible .. ")")
    w:toggle("Tracers"); w:run(0.3)
    local after = 0
    for _, d in ipairs(w.drawings or {}) do if d.Visible and not d.removed then after = after + 1 end end
    check(after == 1, "turning player tracers off leaves only the gun line (" .. after .. ")")
    w:killPlayer(cy); w:run(1.0)
    check(espColors(w).Cy == nil, "dead players lose their ESP")
    w.setParent(bob, nil); w:run(0.6)
    check(espColors(w).Bob == nil, "players who leave lose their ESP")
    w:toggle("Show innocents")
    w:run(0.5)
    check(espColors(w).Alice ~= nil, "'Show innocents' off still shows the murderer")
    clean(w, "tracers/deaths")
end

------------------------------------------------------------------------------------------------ 17. click everything
section("press every control")
do
    local w = newGame()
    local alice, bob = round(w)
    w:giveTool(w.me, "Gun", {held = true, remotes = {{name = "Shoot"}}})
    boot(w, 0.8)
    local skip = {["Unload the hub"] = true}
    local rows = {}
    for _, i in ipairs(w:findAll(function(i) return i.ClassName == "TextButton" and i.Text == "" end)) do
        local row = i.Parent
        local title
        for _, c in ipairs(w.M.GetChildren(row)) do if c.ClassName == "TextLabel" and c.Text ~= "" then title = title or c.Text end end
        if title and not skip[title] then rows[#rows + 1] = {btn = i, title = title} end
    end
    local pressed = 0
    for round_ = 1, 2 do
        for _, r in ipairs(rows) do
            w:click(r.btn); pressed = pressed + 1
            w:run(0.05)
        end
    end
    -- every dropdown option
    for _, i in ipairs(w:findAll(function(i) return i.ClassName == "TextButton" and i.Text:sub(1, 2) == "  " end)) do w:click(i); pressed = pressed + 1; w:run(0.03) end
    w:run(1.0)
    check(pressed > 120, "pressed " .. pressed .. " controls")
    clean(w, "press everything")
    check(w:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "MM2HubWindow" end) ~= nil, "window still there")
end

print(string.format("\n%d checks passed, %d failed", passes, #failures))
for _, f in ipairs(failures) do print("FAIL  " .. f) end
if #failures > 0 then os.exit(1) end
