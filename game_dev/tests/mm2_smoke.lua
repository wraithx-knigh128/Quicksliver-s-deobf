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
    local log = w.genv.__WraithsHub and w.genv.__WraithsHub.Log or {}
    local bad = {}
    for _, l in ipairs(log) do if l:find("%[") and not l:find("recorded") then bad[#bad + 1] = l end end
    check(#bad == 0, name .. ": the script's own error log is not empty: " .. table.concat(bad, " | "):sub(1, 700))
end
local function toasts(w)                                    -- the texts of every toast on screen (title and content labels)
    local out = {}
    for _, i in ipairs(w:findAll(function(i)
        if i.ClassName ~= "TextLabel" then return false end
        local p = i.Parent
        for _ = 1, 4 do
            if not p then return false end
            if p.Name == "Toasts" then return true end
            p = p.Parent
        end
        return false
    end)) do out[#out + 1] = i.Text end
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
    check(w:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "WraithsHubWindow" end) ~= nil, "window ScreenGui exists")
    for _, tab in ipairs({"Main", "ESP", "Combat", "Buttons", "Player", "Settings", "Debug"}) do
        check(w:find(function(i) return i.ClassName == "TextButton" and i.Name == tab end) ~= nil, "tab " .. tab)
    end
    check(w.genv.__WraithsHub ~= nil, "session registered")
    check(hasToast(w, "Hub loaded"), "welcome toast")
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
    local hud = w:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "WraithsHubHud" end)
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
    round(w, {noTools = true})                                        -- (no roles known: no other toasts push the gun toast out - at most 3 show at once)
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
    local predicted = w:V3(head.X + 10 * 0.11, head.Y, head.Z)         -- velocity 10 studs/s * (60 ms ping + 50 ms render delay)
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
    w:click(w:rowButton("Aim method")); w:click(w:option("Mouse cursor"))
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
    w:click(w:rowButton("Perfect shoot"))
    w:run(0.4)
    check(#w.sent == before + 1, "'Shoot the murderer' fires the recorded remote exactly once (" .. (#w.sent - before) .. ")")
    local s = w.sent[#w.sent]
    local head = alice.Character.Head.Position
    check(s and s.remote == shoot and s.method == "FireServer", "...on the same remote")
    check(s and s.args.n == 2, "...with the same number of arguments")
    check(s and near(s.args[2].Position.X, head.X + 1.1, 1e-6) and near(s.args[2].Position.Z, head.Z, 1e-6) and near(s.args[2].Position.Y, head.Y, 1e-6), "target slot = predicted head position")
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
    check(near(s2.args[2].Position.X, head.X + 1.1, 1e-6) and near(s2.args[2].Position.Z, head.Z, 1e-6), "silent aim: my wild shot is sent at the predicted murderer")
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
    w:click(w:rowButton("Perfect shoot")); w:run(0.4)
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
    w:click(w:rowButton("Perfect throw")); w:run(0.5)
    check(#w.sent == n + 1, "throw fired once")
    local s = w.sent[#w.sent]
    check(s and s.remote == knife2:FindFirstChild("Events"):FindFirstChild("KnifeThrown"), "...through the NEW tool's remote (resolved by path)")
    check(s and w.env.typeof(s.args[1]) == "CFrame" and w.env.typeof(s.args[2]) == "Vector3", "argument types are preserved")
    clean(w, "knife")
end

section("throw without a recorded shot: aim + the game's throw key")
do
    local w = newGame()
    w:addPlayer("Bob", {pos = {0, 3, -40}})
    w:giveTool(w.me, "Knife", {held = true})
    boot(w, 1.0)
    w:click(w:rowButton("Perfect throw")); w:run(0.5)
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
    w:click(w:rowButton("Perfect shoot")); w:run(0.3)
    check(hasToast(w, "No gun"), "no gun -> 'No gun'")
    w:click(w:rowButton("Perfect throw")); w:run(0.3)
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
    w:click(w:rowButton("Who")); w:click(w:option("Everyone else")); w:run(0.6)
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
    local raw = w.files["wraiths_hub_config.json"]
    check(raw ~= nil, "Save config writes wraiths_hub_config.json")
    local data = raw and w.jsonDecode(raw) or {}
    check(data.espHealth == true and data.alertDistance == 120, "saved values: espHealth / alertDistance")
    check(data.theme == "Crimson", "saved theme")

    local w2 = newGame()
    round(w2)
    w2.files["wraiths_hub_config.json"] = raw
    boot(w2, 1.0)
    check(labelContaining(w2, "Alice %[Murderer%] %d+hp") ~= nil or labelContaining(w2, "100hp") ~= nil, "restored: Health ESP is on after a restart")
    check(labelContaining(w2, "120 studs") ~= nil, "restored: slider label")
    clean(w2, "config restored")

    local w3 = newGame()
    round(w3)
    w3.files["wraiths_hub_config.json"] = "{not json"
    boot(w3, 0.8)
    check(w:find(function(i) return true end) ~= nil, "sanity")
    check(w3:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "WraithsHubWindow" end) ~= nil, "a corrupt config does not stop the hub")
    local w4 = newGame()
    round(w4)
    w4.files["wraiths_hub_config.json"] = '{"espHealth": "yes", "alertDistance": "far", "nonsense": 5}'
    boot(w4, 0.8)
    check(w4:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "WraithsHubWindow" end) ~= nil, "wrongly typed config values are ignored")
    clean(w4, "typed config")

    -- load / delete buttons
    w:click(w:rowButton("Delete saved config")); w:run(0.1)
    check(w.files["wraiths_hub_config.json"] == nil, "Delete saved config removes the file")
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
    local hub = w.genv.__WraithsHub
    w:click(w:rowButton("Unload the hub")); w:run(0.3)
    check(w.genv.__WraithsHub == nil, "session cleared")
    local left = w:findAll(function(i) return i.Name:find("Wraith") ~= nil end)
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
    local windows = w2:findAll(function(i) return i.ClassName == "ScreenGui" and i.Name == "WraithsHubWindow" end)
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
    check(w:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "WraithsHubWindow" end) ~= nil, "loads with no executor extras")
    check(labelContaining(w, "no hook") ~= nil or hasToast(w, "no hook"), "the welcome toast lists what is missing")
    w:toggle("Tracers"); w:toggle("Aim assist"); w:run(0.4)
    w:click(w:rowButton("Save config")); w:run(0.2)
    check(hasToast(w, "Cannot save"), "Save config explains why it cannot save")
    w:click(w:rowButton("Copy diagnostics")); w:run(0.2)
    check(hasToast(w, "No clipboard"), "Copy diagnostics explains the missing clipboard")
    w:click(w:rowButton("Perfect shoot")); w:run(0.2)
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
    w:keyDown("Z"); w:click(w:rowButton("Perfect shoot")); w:click(w:rowButton("Perfect throw")); w:click(w:rowButton("Grab the gun"))
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
    local gui = w:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "WraithsHubWindow" end, w.me:FindFirstChild("PlayerGui"))
    check(gui ~= nil, "the window lives in PlayerGui when CoreGui refuses")
    local folder = w.workspace:FindFirstChild("WraithsHubESP")
    check(folder ~= nil, "ESP objects go into workspace (Highlights do not render under a PlayerGui)")
    check(folder and #w.M.GetChildren(folder) >= 3, "...and they are there")
    clean(w, "playergui fallback")

    local w2 = newGame({gethui = true})
    round(w2)
    boot(w2, 0.8)
    check(w2:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "WraithsHubWindow" end) ~= nil, "gethui() container is used when the executor has it")
    clean(w2, "gethui")
end

section("not Murder Mystery 2 / waiting for the local player")
do
    local w = newGame({placeId = 123})
    boot(w, 0.8)
    check(hasToast(w, "Hub loaded"), "still loads")
    check(labelContaining(w, "does not look like Murder Mystery 2") ~= nil, "...but says this is not MM2")
    clean(w, "other place")

    local w2 = World.new(); w2:installJson()
    local me = w2:addPlayer("Me", {pos = {0, 3, 0}})
    w2:load(SCRIPT_SOURCE); w2:run(0.5)
    check(w2:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "WraithsHubWindow" end) == nil, "waits while LocalPlayer is nil")
    w2:setLocal(me); w2:run(0.6)
    check(w2:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "WraithsHubWindow" end) ~= nil, "...and starts once it exists")
    clean(w2, "late local player")
end

------------------------------------------------------------------------------------------------ 14. the window itself
section("window: search, tabs, themes, hide / show, minimise")
do
    local w = newGame()
    round(w)
    boot(w, 0.8)
    local winGui = w:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "WraithsHubWindow" end)
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
    w:click(w:rowButton("Theme")); w:click(w:option("Ocean")); w:run(0.1)
    check(main.BackgroundColor3 ~= bg0, "theme change recolours the window")
    -- hide / show
    w:click(w:button("Close")); w:run(0.1)
    check(not main.Visible, "the close glyph hides the window")
    local pill = w:find(function(i) return i.ClassName == "Frame" and i.Name == "Pill" end, winGui)
    check(pill.Visible, "the floating hub pill appears while the window is hidden")
    check(hasToast(w, "Menu hidden"), "...and a toast says how to bring it back")
    w:click(w:button("OpenButton")); check(main.Visible and not pill.Visible, "tapping the pill brings the window back (and the pill goes away)")
    w:keyDown("RightShift"); check(not main.Visible, "RightShift hides it")
    w:keyDown("RightShift"); check(main.Visible, "RightShift shows it")
    local h0, w0 = main.Size.Y.Offset, main.Size.X.Offset
    w:click(w:button("Minimize")); check(main.Size.Y.Offset < h0, "minimise shrinks the window to its header")
    w:click(w:button("Minimize")); check(main.Size.Y.Offset == h0, "...and restores it")
    w:click(w:button("Maximize")); check(main.Size.X.Offset > w0 and main.Size.Y.Offset > h0, "maximise makes it bigger")
    w:click(w:button("Maximize")); check(main.Size.X.Offset == w0 and main.Size.Y.Offset == h0, "...and back to normal")
    -- the tab group folds
    local tabsFrame = w:find(function(i) return i.ClassName == "ScrollingFrame" and i.Name == "Tabs" end, winGui)
    w:click(w:button("Group")); check(not tabsFrame.Visible, "the tab group header folds the tab list")
    w:click(w:button("Group")); check(tabsFrame.Visible, "...and opens it again")
    -- dragging the header moves the window; dragging the pill's handle moves the pill
    local header = w:find(function(i) return i.ClassName == "Frame" and i.Name == "Header" end, winGui)
    local x0 = main.Position.X.Offset
    local E = w.env.Enum
    w.fire(rawget(header, "__d").signals.InputBegan, {UserInputType = E.UserInputType.MouseButton1, Position = w:V3(400, 40, 0)})
    w:mouseMove(450, 60)
    w.fire(rawget(w.uis, "__d").signals.InputEnded, {UserInputType = E.UserInputType.MouseButton1, Position = w:V3(450, 60, 0)})
    check(main.Position.X.Offset == x0 + 50, "dragging the header moves the window by the mouse delta")
    w:click(w:button("Close"))
    local handle = w:find(function(i) return i.ClassName == "Frame" and i.Name == "Handle" end, winGui)
    local px0 = pill.Position.X.Offset
    w.fire(rawget(handle, "__d").signals.InputBegan, {UserInputType = E.UserInputType.Touch, Position = w:V3(100, 20, 0)})
    w:mouseMove(130, 20)
    w.fire(rawget(w.uis, "__d").signals.InputEnded, {UserInputType = E.UserInputType.Touch, Position = w:V3(130, 20, 0)})
    check(near(pill.Position.X.Offset, px0 + 30, 1e-6), "dragging the pill's handle moves the pill by the finger's movement")
    w:click(w:button("OpenButton"))
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
    w:click(w:rowButton("Aim at")); w:click(w:option("Torso")); w:run(0.1)
    check(labelContaining(w, "^Torso$") ~= nil, "dropdown shows the chosen value")
    -- keybind capture
    w:click(w:rowButton("Aim key (hold)")); w:keyDown("G"); w:run(0.1)
    check(w:find(function(i) return i.ClassName == "TextLabel" and i.Text == "G" and i.Parent and i.Parent.Name == "Key" end) ~= nil, "keybind button shows the captured key")
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
    for _, i in ipairs(w:findAll(function(i) return i.ClassName == "TextButton" and (i.Name == "Hit" or i.Name == "Key") end)) do
        local row = i.Parent
        local title
        for _, c in ipairs(w.M.GetDescendants(row)) do
            if c.ClassName == "TextLabel" and c.Name == "Title" and c.Text ~= "" then title = title or c.Text end
        end
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
    for _, i in ipairs(w:findAll(function(i) return i.ClassName == "TextButton" and i.Name == "Option" end)) do w:click(i); pressed = pressed + 1; w:run(0.03) end
    w:run(1.0)
    check(pressed > 120, "pressed " .. pressed .. " controls")
    clean(w, "press everything")
    check(w:find(function(i) return i.ClassName == "ScreenGui" and i.Name == "WraithsHubWindow" end) ~= nil, "window still there")
end


------------------------------------------------------------------------------------------------ floating buttons
local function ring(w, btn) return w.M.FindFirstChildOfClass(btn, "UIStroke") end
local function goodColor(c) return c and c.G > 0.7 and c.R < 0.5 end
local function badColor(c) return c and c.R > 0.8 and c.G < 0.45 end
local function setupShooter(opts)
    opts = opts or {}
    local w = newGame(opts.world)
    local alice = round(w, {noTools = true})
    w:giveTool(alice, "Knife", {held = true})
    local gun = opts.noGun and nil or w:giveTool(w.me, "Gun", {held = true, remotes = {{name = "Shoot"}}})
    boot(w, 1.0)
    if gun then
        w:mouseDown("MouseButton1")
        gun:FindFirstChild("Shoot"):FireServer(w.env.CFrame.new(0, 4.5, 0), w.env.CFrame.new(5, 3, -30)); w:run(0.3)
    end
    return w, alice, gun
end

section("floating buttons: perfect shoot / perfect throw")
do
    local w, alice, gun = setupShooter()
    local shoot, throw, grab = w:button("Float_shoot"), w:button("Float_throw"), w:button("Float_grab")
    check(shoot.Visible and throw.Visible and not grab.Visible, "SHOOT and THROW are on screen, GRAB GUN is off by default")
    check(shoot.Size.X.Offset == 80 and shoot.Size.Y.Offset == 80, "default size 80 px")
    check(w:find(function(i) return i.ClassName == "TextLabel" and i.Text == "SHOOT" and i.Parent == shoot end) ~= nil, "the SHOOT button says SHOOT")
    check(w:find(function(i) return i.ClassName == "TextLabel" and i.Text == "THROW" and i.Parent == throw end) ~= nil, "the THROW button says THROW")
    local remote = gun:FindFirstChild("Shoot")
    local head = alice.Character.Head.Position
    local n = #w.sent
    w:tap(shoot, 1050, 160); w:run(0.1)
    check(#w.sent == n + 1 and w.sent[#w.sent].remote == remote, "a tap on SHOOT fires the recorded gun remote exactly once (" .. (#w.sent - n) .. ")")
    check(w.sent[#w.sent] and near(w.sent[#w.sent].args[2].Position.X, head.X + 1.1, 1e-6), "...at the murderer's position led by ping + render delay")
    check(goodColor(ring(w, shoot).Color), "the ring flashes green when the shot went out")
    check(hasToast(w, "Shot fired"), "a toast says who was shot at")
    check(labelContaining(w, "Alice  %d+m  lead 110 ms") ~= nil, "...with the distance and the ping lead (110 ms = 60 ping + 50 render delay)")
    w:run(0.8)
    check(not goodColor(ring(w, shoot).Color), "the flash fades")
    local before2 = #w.sent
    w:tap(shoot, 1050, 160); w:tap(shoot, 1050, 160); w:run(0.6)
    check(#w.sent == before2 + 1, "two taps in the same instant fire once: the second is ignored while the first is still in flight (" .. (#w.sent - before2) .. ")")

    -- THROW: the murderer's button (I only have the gun, so it says so and flashes red)
    w:tap(throw, 1050, 340); w:run(0.1)
    check(hasToast(w, "No knife"), "THROW without a knife says 'No knife'")
    check(badColor(ring(w, throw).Color), "...and flashes red")
    clean(w, "floating buttons")
end

section("floating buttons: throw")
do
    local w = newGame()
    local bob = w:addPlayer("Bob", {pos = {0, 3, -40}})
    local knife = w:giveTool(w.me, "Knife", {held = true, remotes = {{folder = "Events", name = "KnifeThrown"}}})
    boot(w, 1.0)
    w:mouseDown("MouseButton1")
    knife:FindFirstChild("Events"):FindFirstChild("KnifeThrown"):FireServer(w.env.CFrame.new(0, 4.5, 0), w:V3(0, 4, -30)); w:run(0.3)
    local n = #w.sent
    w:tap(w:button("Float_throw"), 1050, 340); w:run(0.15)
    check(#w.sent == n + 1, "a tap on THROW throws once")
    check(goodColor(ring(w, w:button("Float_throw")).Color), "THROW flashes green")
    check(hasToast(w, "Knife thrown"), "toast: Knife thrown")
    local aimed = w.sent[#w.sent].args[2]
    check(near(aimed.X, 0, 1e-6) and near(aimed.Y, 4.5, 1e-6) and near(aimed.Z, -40, 1e-6), "the throw is aimed at Bob's head (a standing target is not led)")
    w:tap(w:button("Float_shoot"), 1050, 160); w:run(0.1)
    check(hasToast(w, "No gun") and badColor(ring(w, w:button("Float_shoot")).Color), "SHOOT without a gun says 'No gun' and flashes red")
    clean(w, "float throw")
end

section("floating buttons: drag, lock, size, show/hide, save")
do
    local w, alice, gun = setupShooter()
    local shoot = w:button("Float_shoot")
    local n = #w.sent
    local x0, y0 = shoot.Position.X.Offset, shoot.Position.Y.Offset
    check(near(x0, 1280 - 12 - 80, 1e-6) and near(y0, 0.18 * 720, 1e-6), "default place: down the right edge (12 px from it), 18% from the top")
    w:drag(shoot, 1050, 160, 850, 260)
    check(near(shoot.Position.X.Offset, x0 - 200, 1e-6) and near(shoot.Position.Y.Offset, y0 + 100, 1e-6), "dragging moves the button by the finger's movement")
    w:run(0.3)
    check(#w.sent == n, "a drag never fires the shot")
    w:drag(shoot, 850, 260, -400, 2000)
    check(shoot.Position.X.Offset >= 0 and shoot.Position.Y.Offset >= 0 and shoot.Position.X.Offset <= 1280 - 80 and shoot.Position.Y.Offset <= 720 - 80, "it can never be dragged off the screen")
    w:drag(shoot, 0, 0, 3, 4); w:run(0.3)
    check(#w.sent == n + 1, "a wobble of a few pixels is still a tap (" .. (#w.sent - n) .. ")")
    -- put it somewhere known, save, reload
    w:slide("Button size", 1.0); w:run(0.1)
    check(shoot.Size.X.Offset == 120 and w:button("Float_throw").Size.X.Offset == 120, "the size slider resizes every button (120 px max)")
    check(shoot.Position.X.Offset <= 1280 - 120 and shoot.Position.Y.Offset <= 720 - 120, "...and keeps them inside the screen")
    w:slide("Button size", 0.0); w:run(0.1)
    check(shoot.Size.X.Offset == 56, "...down to 56 px")
    w:slide("Button size", 0.375); w:run(0.1)                          -- 56 + 0.375 * 64 = 80
    check(shoot.Size.X.Offset == 80, "back to 80")
    w:setCamera({0, 5, 0}, {0, 5, -10})
    -- lock
    w:toggle("Lock button positions")
    local px, py = shoot.Position.X.Offset, shoot.Position.Y.Offset
    local sent0 = #w.sent
    w:drag(shoot, px + 10, py + 10, px + 210, py + 110); w:run(0.3)
    check(shoot.Position.X.Offset == px and shoot.Position.Y.Offset == py, "locked: the button does not move")
    check(#w.sent == sent0, "locked: a long swipe is not a tap")
    w:drag(shoot, px + 10, py + 10, px + 14, py + 13); w:run(0.3)
    check(#w.sent == sent0 + 1, "locked: a real tap still fires")
    w:toggle("Lock button positions")
    -- show / hide
    w:toggle("Show Perfect Shoot"); check(not shoot.Visible, "'Show Perfect Shoot' off hides SHOOT")
    w:toggle("Show Perfect Shoot"); check(shoot.Visible, "...and on shows it again")
    w:toggle("Show Grab Gun"); check(w:button("Float_grab").Visible, "'Show Grab Gun' shows the third button")
    w:toggle("Show Grab Gun")
    -- save / load positions
    w:drag(shoot, px + 10, py + 10, 500, 300)
    local fx, fy = shoot.Position.X.Offset / 1280, shoot.Position.Y.Offset / 720
    w:click(w:rowButton("Save config")); w:run(0.1)
    local saved = w.jsonDecode(w.files["wraiths_hub_config.json"])
    check(near(saved.shootX, fx, 1e-9) and near(saved.shootY, fy, 1e-9), "Save config keeps where you put SHOOT")
    check(saved.btnShoot == true and saved.btnThrow == true and saved.btnGrab == false and saved.btnSize == 80 and saved.waves == "High", "...and which buttons are shown, their size and the wave mode")
    local w2 = newGame()
    local a2 = round(w2, {noTools = true})
    w2.files["wraiths_hub_config.json"] = w.files["wraiths_hub_config.json"]
    boot(w2, 0.8)
    check(near(w2:button("Float_shoot").Position.X.Offset, fx * 1280, 1e-6), "a new session puts SHOOT back where it was")
    w2:click(w2:rowButton("Reset button positions")); w2:run(0.1)
    check(near(w2:button("Float_shoot").Position.X.Offset, 1280 - 12 - 80, 1e-6), "Reset button positions puts it back")
    clean(w, "float drag"); clean(w2, "float restore")
end

section("floating buttons: dimmed without the weapon")
do
    local w = newGame()
    local alice = round(w, {noTools = true})
    w:giveTool(alice, "Knife", {held = true})
    boot(w, 1.0)
    local function dim(id) return w.M.FindFirstChildOfClass(w:button("Float_" .. id), "CanvasGroup") end
    local function iconBox(id) return w:find(function(i) return i.ClassName == "CanvasGroup" and i.Parent == w:button("Float_" .. id) end) end
    check(iconBox("shoot").GroupTransparency > 0.4, "no gun: SHOOT's icon is dimmed")
    check(iconBox("throw").GroupTransparency > 0.4, "no knife either: THROW is dimmed")
    w:giveTool(w.me, "Gun", {held = true}); w:run(0.8)
    check(iconBox("shoot").GroupTransparency == 0, "with the gun in hand SHOOT lights up")
    check(iconBox("throw").GroupTransparency > 0.4, "THROW stays dimmed")
    clean(w, "float dim")
end

section("floating SPEED / JUMP toggles")
do
    local w = newGame()
    round(w)
    boot(w, 0.8)
    local speed, jump = w:button("Float_speed"), w:button("Float_jump")
    check(not speed.Visible and not jump.Visible, "SPEED and JUMP are hidden until you ask for them")
    w:toggle("Show Speed toggle"); w:toggle("Show Jump toggle")
    check(speed.Visible and jump.Visible, "'Show Speed toggle' / 'Show Jump toggle' show them")
    local function labelOf(btn) return w:find(function(i) return i.ClassName == "TextLabel" and i.Name == "Label" and i.Parent == btn end).Text end
    local hum = w.me.Character.Humanoid
    check(labelOf(speed) == "SPEED OFF" and labelOf(jump) == "JUMP OFF", "they start as SPEED OFF / JUMP OFF")
    local x0 = speed.Position.X.Offset
    w:tap(speed, x0 + 10, 150)
    check(ring(w, speed).Thickness == 2, "a toggle does not flash like a shot does (the ring keeps its thickness)")
    w:run(0.4)
    check(hum.WalkSpeed == 24 and labelOf(speed) == "SPEED ON", "a tap turns walk speed on (24) and says SPEED ON")
    check(ring(w, speed).Color.G > 0.7 and ring(w, speed).Color.R < 0.4, "the ring turns teal while it is on")
    w:tap(speed, x0 + 10, 150); w:run(0.4)
    check(hum.WalkSpeed == 16 and labelOf(speed) == "SPEED OFF", "a second tap turns it off again")
    check(ring(w, speed).Color.R > 0.5 and ring(w, speed).Color.G < 0.7, "the ring is grey while it is off")
    -- the Player tab switch and the button stay in step
    w:toggle("Walk speed"); w:run(0.4)
    check(labelOf(speed) == "SPEED ON" and hum.WalkSpeed == 24, "switching it in the Player tab updates the button")
    w:tap(speed, x0 + 10, 150); w:run(0.4)
    check(hum.WalkSpeed == 16 and labelOf(speed) == "SPEED OFF", "...and the button switches the Player tab's setting off")
    -- jump
    w:tap(jump, jump.Position.X.Offset + 10, jump.Position.Y.Offset + 10); w:run(0.4)
    check(hum.JumpPower == 60 and labelOf(jump) == "JUMP ON", "JUMP turns jump power on (60)")
    w:tap(jump, jump.Position.X.Offset + 10, jump.Position.Y.Offset + 10); w:run(0.4)
    check(hum.JumpPower == 50 and labelOf(jump) == "JUMP OFF", "...and off (back to 50)")
    -- they drag like the others and keep their place
    local jx0 = jump.Position.X.Offset
    w:drag(jump, jx0 + 10, jump.Position.Y.Offset + 10, jx0 - 190, jump.Position.Y.Offset + 10)
    check(near(jump.Position.X.Offset, jx0 - 200, 1e-6) and hum.JumpPower == 50, "dragging JUMP moves it without toggling")
    w:click(w:rowButton("Save config")); w:run(0.1)
    local saved = w.jsonDecode(w.files["wraiths_hub_config.json"])
    check(saved.btnSpeed == true and saved.btnJump == true and near(saved.jumpX, (jx0 - 200) / 1280, 1e-9) and saved.speedX == -1, "saved: shown, where JUMP was put, and 'auto' for the one never moved")
    clean(w, "speed jump")
end

------------------------------------------------------------------------------------------------ water waves
section("water waves on every button")
do
    local w, alice, gun = setupShooter()
    local function waves(btn) return w:find(function(i) return i.ClassName == "Frame" and i.Name == "Waves" and i.Parent == btn end) end
    local function layers(wv) local out = {} for _, c in ipairs(w.M.GetChildren(wv)) do if c.Name:match("^Wave%d$") then out[#out + 1] = c end end return out end
    local function offsetOf(layer) return w.M.FindFirstChildOfClass(layer, "UIGradient").Offset end
    -- every kind of button has the skin
    local named = {"Close", "Maximize", "Minimize", "Group", "Float_shoot", "Float_throw", "Float_grab"}
    for _, tab in ipairs({"Main", "ESP", "Combat", "Buttons", "Player", "Settings", "Debug"}) do named[#named + 1] = tab end
    for _, name in ipairs(named) do
        local b = w:find(function(i) return i.ClassName == "TextButton" and i.Name == name end)
        local wv = b and waves(b)
        check(wv ~= nil and #layers(wv) == 3, name .. " button wears the wave skin (3 layers)")
    end
    local pill = w:find(function(i) return i.ClassName == "Frame" and i.Name == "Pill" end)
    check(waves(pill) ~= nil, "the hub pill wears it")
    check(waves(w:row("Perfect shoot")) ~= nil, "action rows wear it (Perfect shoot)")
    check(waves(w:rowButton("Aim key (hold)")) ~= nil, "keybind buttons wear it")
    w:click(w:rowButton("Aim at"))
    check(waves(w:option("Torso")) ~= nil, "dropdown options wear it")
    local runPill = w:find(function(i) return i.Name == "RunPill" end)
    check(waves(runPill) ~= nil, "the Run / Fire pills wear it")

    -- the gradients are real grey-white wave patterns
    local fl = waves(w:button("Float_shoot"))
    local g1 = w.M.FindFirstChildOfClass(layers(fl)[1], "UIGradient")
    check(#g1.Color.keys == 20 and #g1.Transparency.keys == 20, "each layer is a 20-keypoint wave")
    local brightest, darkest = 0, 1
    for _, k in ipairs(g1.Color.keys) do
        local lum = (k.v.R + k.v.G + k.v.B) / 3
        brightest, darkest = math.max(brightest, lum), math.min(darkest, lum)
        check(math.abs(k.v.R - k.v.B) < 0.1, "wave colours are grey / white (no tint)")
    end
    check(brightest > 0.85 and darkest > 0.5, "from mid-grey to near white (" .. string.format("%.2f..%.2f", darkest, brightest) .. ")")
    local rots = {}
    for _, l in ipairs(layers(fl)) do rots[#rots + 1] = w.M.FindFirstChildOfClass(l, "UIGradient").Rotation end
    check(rots[1] ~= rots[2] and rots[2] ~= rots[3] and rots[1] ~= rots[3], "the three layers run at different angles (interference reads as water)")

    -- they move
    local travel, lastX = {0, 0, 0}, {}
    for i, l in ipairs(layers(fl)) do lastX[i] = offsetOf(l).X end
    for _ = 1, 30 do
        w:run(0.1)
        for i, l in ipairs(layers(fl)) do
            local x = offsetOf(l).X
            travel[i] = travel[i] + math.abs(x - lastX[i]); lastX[i] = x
            check(math.abs(x) <= 0.4, "layer " .. i .. " stays inside its range")
        end
    end
    local moved = 0
    for i = 1, 3 do if travel[i] > 0.15 then moved = moved + 1 end end
    check(moved == 3, "all three layers of the floating button move (travel " .. string.format("%.2f %.2f %.2f", travel[1], travel[2], travel[3]) .. ")")
    local first = offsetOf(layers(fl)[1]).X
    w:run(1.7)
    check(math.abs(offsetOf(layers(fl)[1]).X - first) > 0.01, "...and keep moving")

    -- tabs only move while the window is shown
    local tabWaves = layers(waves(w:find(function(i) return i.ClassName == "TextButton" and i.Name == "ESP" end)))
    local t0 = offsetOf(tabWaves[1]).X
    w:run(0.5)
    check(math.abs(offsetOf(tabWaves[1]).X - t0) > 0.01, "menu buttons move while the window is open")
    w:click(w:button("Close")); w:run(0.1)
    local t1 = offsetOf(tabWaves[1]).X
    w:run(0.6)
    check(offsetOf(tabWaves[1]).X == t1, "...and stand still (no work) while it is hidden")
    local f1 = offsetOf(layers(fl)[1]).X
    w:run(0.6)
    check(offsetOf(layers(fl)[1]).X ~= f1, "the floating buttons keep moving with the window hidden")
    w:click(w:button("OpenButton")); w:run(0.1)

    -- modes
    w:tab("Buttons")
    w:click(w:rowButton("Button waves")); w:click(w:option("Low", "Button waves")); w:run(0.3)
    local vis = 0
    for _, l in ipairs(layers(fl)) do if l.Visible then vis = vis + 1 end end
    check(vis == 1, "Low: one layer per button (" .. vis .. ")")
    w:click(w:rowButton("Button waves")); w:click(w:option("Off", "Button waves")); w:run(0.3)
    check(fl.Visible == false, "Off: the wave holder is hidden")
    local f2 = offsetOf(layers(fl)[1]).X
    w:run(0.5)
    check(offsetOf(layers(fl)[1]).X == f2, "Off: nothing is animated")
    w:click(w:rowButton("Button waves")); w:click(w:option("High", "Button waves")); w:run(0.3)
    local vis2 = 0
    for _, l in ipairs(layers(fl)) do if l.Visible then vis2 = vis2 + 1 end end
    check(fl.Visible and vis2 == 3, "High: all three layers again")

    -- a press spreads a ripple that goes away
    local shoot = w:button("Float_shoot")
    w:press(shoot, 1060, 170); w:release(1060, 170)
    check(w:find(function(i) return i.Name == "Ripple" end, shoot) ~= nil, "a press starts a ripple on the button")
    w:run(0.9)
    check(w:find(function(i) return i.Name == "Ripple" end, shoot) == nil, "...which disappears again")
    clean(w, "waves")
end

section("waves: saved and restored")
do
    local w = newGame()
    round(w)
    boot(w, 0.6)
    w:tab("Buttons"); w:click(w:rowButton("Button waves")); w:click(w:option("Low", "Button waves")); w:run(0.1)
    w:click(w:rowButton("Save config")); w:run(0.1)
    local w2 = newGame()
    round(w2)
    w2.files["wraiths_hub_config.json"] = w.files["wraiths_hub_config.json"]
    boot(w2, 0.6)
    local fl = w2:find(function(i) return i.ClassName == "Frame" and i.Name == "Waves" and i.Parent == w2:button("Float_shoot") end)
    local vis = 0
    for _, c in ipairs(w2.M.GetChildren(fl)) do if c.Name:match("^Wave%d$") and c.Visible then vis = vis + 1 end end
    check(vis == 1, "a saved 'Low' wave mode is applied at start (" .. vis .. " layer)")
    clean(w2, "waves restored")
end

------------------------------------------------------------------------------------------------ ping-based lead
section("shots lead the target by the measured ping")
do
    -- Alice runs sideways at 10 studs/s; the aim point sits (ping + render delay) * 10 studs ahead of her head
    local function aimOffset(setup)
        local w = newGame()
        local alice = round(w, {noTools = true})
        w:giveTool(alice, "Knife", {held = true})
        local gun = w:giveTool(w.me, "Gun", {held = true, remotes = {{name = "Shoot"}}})
        if setup then setup(w) end
        boot(w, 2.0)
        w:mouseDown("MouseButton1")
        gun:FindFirstChild("Shoot"):FireServer(w.env.CFrame.new(0, 4.5, 0), w.env.CFrame.new(5, 3, -30)); w:run(0.3)
        local n = #w.sent
        w:click(w:rowButton("Perfect shoot")); w:run(0.4)
        local s = w.sent[#w.sent]
        local ok = #w.sent == n + 1
        return ok and (s.args[2].Position.X - alice.Character.Head.Position.X) or nil, w
    end
    local lead60 = aimOffset()
    check(lead60 and near(lead60, 1.1, 1e-6), "60 ms ping + 50 ms render delay -> 1.1 studs ahead at 10 studs/s (got " .. tostring(lead60) .. ")")
    local lead200 = aimOffset(function(w) w.pingMs = 200 end)
    check(lead200 and near(lead200, 2.5, 1e-6), "200 ms ping -> 2.5 studs ahead (got " .. tostring(lead200) .. ")")
    local lead20 = aimOffset(function(w) w.pingMs = 20 end)
    check(lead20 and near(lead20, 0.7, 1e-6), "20 ms ping -> 0.7 studs ahead (got " .. tostring(lead20) .. ")")
    check(lead200 and lead60 and lead20 and lead200 > lead60 and lead60 > lead20, "the worse the ping, the further ahead")

    -- ping compensation / render delay / extra lead sliders
    local w = newGame()
    local alice = round(w, {noTools = true})
    w:giveTool(alice, "Knife", {held = true})
    local gun = w:giveTool(w.me, "Gun", {held = true, remotes = {{name = "Shoot"}}})
    boot(w, 2.0)
    w:mouseDown("MouseButton1")
    gun:FindFirstChild("Shoot"):FireServer(w.env.CFrame.new(0, 4.5, 0), w.env.CFrame.new(5, 3, -30)); w:run(0.3)
    local function shootOffset()
        w:run(1.3)                                                    -- (past the shot gap; the reticle label settles)
        local n = #w.sent
        w:click(w:rowButton("Perfect shoot")); w:run(0.4)
        if #w.sent ~= n + 1 then return nil end
        return w.sent[#w.sent].args[2].Position.X - alice.Character.Head.Position.X
    end
    w:tab("Combat")
    w:slide("Ping compensation", 0.0); check(near(shootOffset() or -1, 0.5, 1e-6), "compensation 0 -> only the 50 ms render delay (0.5 studs)")
    w:slide("Ping compensation", 1.0 / 1.5 * 0.5); check(near(shootOffset() or -1, 0.8, 1e-6), "compensation 0.5 -> half the ping + render delay (0.8 studs)")
    w:slide("Ping compensation", 1.0 / 1.5)
    w:slide("Render delay (others)", 0.0); check(near(shootOffset() or -1, 0.6, 1e-6), "render delay 0 -> only the 60 ms ping (0.6 studs)")
    w:slide("Render delay (others)", 0.25)                             -- 50 ms
    w:slide("Extra lead (trim)", 1.0); check(near(shootOffset() or -1, 3.1, 1e-6), "extra lead +200 ms -> 3.1 studs")
    w:slide("Extra lead (trim)", 0.0); check(near(shootOffset() or -1, 0.1, 1e-6), "extra lead -100 ms -> 0.1 studs (never negative)")
    w:slide("Extra lead (trim)", 1 / 3)                                -- back to 0
    w:toggle("Lead by my ping"); check(near(shootOffset() or -1, 0.5, 1e-6), "'Lead by my ping' off -> only the render delay")
    w:toggle("Lead by my ping")
    w:toggle("Lead moving targets"); check(near(shootOffset() or -1, 0, 1e-6), "'Lead moving targets' off -> aims at where they are")
    w:toggle("Lead moving targets")
    check(labelContaining(w, "^Ping 60 ms %(smoothed%)  %->  aim 110 ms ahead of what you see$") ~= nil, "the live label shows the ping and the lead (" .. tostring((labelContaining(w, "^Ping") or {}).Text) .. ")")
    clean(w, "ping sliders")
end

section("ping: spikes are ignored, real changes follow")
do
    local w = newGame()
    local alice = round(w, {noTools = true})
    w:giveTool(alice, "Knife", {held = true})
    local gun = w:giveTool(w.me, "Gun", {held = true, remotes = {{name = "Shoot"}}})
    boot(w, 2.0)
    w:mouseDown("MouseButton1")
    gun:FindFirstChild("Shoot"):FireServer(w.env.CFrame.new(0, 4.5, 0), w.env.CFrame.new(5, 3, -30)); w:run(0.3)
    w.pingMs = 900; w:run(0.3); w.pingMs = 60                         -- one or two samples of a lag blip
    w:run(1.5)
    w:tab("Combat"); w:run(0.8)
    check(labelContaining(w, "^Ping 60 ms") ~= nil, "a lag spike does not move the smoothed ping (label: " .. tostring((labelContaining(w, "^Ping") or {}).Text) .. ")")
    w.pingMs = 140; w:run(4.0)
    check(labelContaining(w, "^Ping 140 ms") ~= nil, "a real change in ping is followed (" .. tostring((labelContaining(w, "^Ping") or {}).Text) .. ")")
    check(labelContaining(w, "aim 190 ms ahead") ~= nil, "...and the lead follows it (140 + 50 ms)")
    clean(w, "ping spike")
end

section("velocity from position history when the engine reports none")
do
    local w = newGame()
    local alice = round(w, {noTools = true, aliceVel = {0, 0, 0}})
    w:giveTool(alice, "Knife", {held = true})
    local gun = w:giveTool(w.me, "Gun", {held = true, remotes = {{name = "Shoot"}}})
    boot(w, 1.5)
    w:mouseDown("MouseButton1")
    gun:FindFirstChild("Shoot"):FireServer(w.env.CFrame.new(0, 4.5, 0), w.env.CFrame.new(5, 3, -30)); w:run(0.3)
    -- Alice slides along x at 10 studs/s but her physics velocity stays 0
    local x = 0
    for _ = 1, 30 do x = x + 10 / 60; w:movePlayer(alice, {x, 3, -40}); w:step(1 / 60) end
    local n = #w.sent
    local xClick = x
    w:click(w:rowButton("Perfect shoot"))
    for _ = 1, 24 do x = x + 10 / 60; w:movePlayer(alice, {x, 3, -40}); w:step(1 / 60) end
    check(#w.sent == n + 1, "the shot went out")
    local aimX = w.sent[#w.sent].args[2].Position.X
    check(aimX - xClick > 1.0 and aimX - xClick < 1.9, "history velocity leads her too: aim point " .. string.format("%.2f", aimX - xClick) .. " studs ahead of where she was at the press (0.3 walked before the shot + 1.1 lead)")
    clean(w, "history velocity")
end

section("the aim is refreshed after the weapon is equipped (the target keeps moving)")
do
    local w = newGame()
    local alice = round(w, {noTools = true, aliceVel = {10, 0, 0}})
    w:giveTool(alice, "Knife", {held = true})
    local gun = w:giveTool(w.me, "Gun", {held = true, remotes = {{name = "Shoot"}}})
    boot(w, 2.0)
    w:mouseDown("MouseButton1")
    gun:FindFirstChild("Shoot"):FireServer(w.env.CFrame.new(0, 4.5, 0), w.env.CFrame.new(5, 3, -30)); w:run(0.3)
    w.M.GetChildren(w.me)                                              -- (the tool goes back into the backpack: not equipped any more)
    w.setParent(gun, w.M.FindFirstChildOfClass(w.me, "Backpack")); w:run(0.3)
    -- Alice runs 10 studs/s in x (physics velocity + real movement); I press with the gun NOT in my hand
    local x = alice.Character.Head.Position.X
    local pressX
    local n = #w.sent
    w:click(w:rowButton("Perfect shoot"))
    pressX = x
    local sentAt
    for _ = 1, 30 do
        x = x + 10 / 60
        w:movePlayer(alice, {x, 3, -40}, {10, 0, 0}); w:step(1 / 60)
        if not sentAt and #w.sent == n + 1 then sentAt = x end
    end
    check(#w.sent == n + 1 and sentAt ~= nil, "the gun was equipped and fired")
    local aim = w.sent[#w.sent].args[2].Position.X
    check(aim - sentAt > 0.9 and aim - sentAt < 1.4, "the aim uses the position at the moment of the shot (1.1 ahead), not the position at the tap: " .. string.format("%.2f studs ahead of where she was when it left", aim - sentAt))
    check(sentAt > pressX + 0.5, "(she really did keep running while the gun was being equipped)")
    clean(w, "fresh aim")
end

------------------------------------------------------------------------------------------------ the moving aim reticle
section("moving aim reticle")
do
    local w = newGame()
    local alice = round(w, {noTools = true})
    w:giveTool(alice, "Knife", {held = true})
    local gun = w:giveTool(w.me, "Gun", {held = true})
    boot(w, 1.0)
    local reticle = w:find(function(i) return i.ClassName == "Frame" and i.Name == "AimReticle" end)
    local tag = w:find(function(i) return i.ClassName == "TextLabel" and i.Name == "Tag" and i.Parent == reticle end)
    local spin = w:find(function(i) return i.ClassName == "Frame" and i.Name == "Spin" and i.Parent == reticle end)
    check(reticle.Visible, "the reticle shows while I hold a weapon and the murderer is known")
    local function projected(pos) local v = w.M.WorldToViewportPoint(w.camera, pos) return v.X, v.Y end
    local head = alice.Character.Head.Position
    local px, py = projected(w:V3(head.X + 1.1, head.Y, head.Z))
    check(math.abs(reticle.Position.X.Offset - px) < 0.5 and math.abs(reticle.Position.Y.Offset - py) < 0.5, "it sits on the predicted point (" .. string.format("%.1f,%.1f vs %.1f,%.1f", reticle.Position.X.Offset, reticle.Position.Y.Offset, px, py) .. ")")
    check(tag.Text:find("^Alice  4%d m  lead 110ms") ~= nil or tag.Text:find("^Alice  %d+m  lead 110ms") ~= nil, "its label: name, distance, lead (" .. tag.Text .. ")")
    local r0 = spin.Rotation
    w:run(0.2)
    check(spin.Rotation ~= r0, "the ticks spin")

    -- the target jumps 10 studs sideways: the reticle GLIDES there instead of snapping
    w:movePlayer(alice, {10, 3, -40}, {0, 0, 0})
    w:step(1 / 60)
    local tx = projected(w:V3(10 + 0.0, 4.5, -40))
    local x1 = reticle.Position.X.Offset
    check(x1 > px + 0.5 and x1 < tx - 20, "one frame later it has started moving but is not there yet (" .. string.format("%.1f in %.1f..%.1f", x1, px, tx) .. ")")
    local last = x1
    local mono = true
    for _ = 1, 20 do
        w:step(1 / 60)
        local x = reticle.Position.X.Offset
        if x < last - 1e-9 then mono = false end
        last = x
    end
    check(mono, "it moves one way, without jitter")
    w:run(0.6)
    check(math.abs(reticle.Position.X.Offset - tx) < 3, "and arrives (" .. string.format("%.1f vs %.1f", reticle.Position.X.Offset, tx) .. ")")

    -- aim assist held: the ring turns green
    w:toggle("Aim assist"); w:keyDown("Z"); w:run(0.2)
    local stroke = w.M.FindFirstChildOfClass(w:find(function(i) return i.ClassName == "Frame" and i.Name == "Ring" and i.Parent == reticle end), "UIStroke")
    check(stroke.Color.G > 0.8 and stroke.Color.R < 0.5, "held aim key: the ring is green (locked)")
    w:keyUp("Z"); w:run(0.2)
    check(stroke.Color.R > 0.9 and stroke.Color.G > 0.9, "released: white again")

    -- modes
    w:tab("Combat")
    w:click(w:rowButton("Aim reticle")); w:click(w:option("Off", "Aim reticle")); w:run(0.3)
    check(not reticle.Visible, "Off hides it")
    w:click(w:rowButton("Aim reticle")); w:click(w:option("Always", "Aim reticle")); w:run(0.3)
    check(reticle.Visible, "Always shows it")
    w.M.Destroy(w.me.Character:FindFirstChild("Gun"))
    w:click(w:rowButton("Aim reticle")); w:click(w:option("Weapon in hand", "Aim reticle")); w:run(0.5)
    check(not reticle.Visible, "'Weapon in hand': hidden when I hold nothing")
    check(labelContaining(w, "^Weapon in hand$") ~= nil, "(the dropdown shows its value)")
    clean(w, "reticle")
end

section("reticle: nothing to aim at")
do
    local w = newGame()
    round(w, {noTools = true})                                        -- nobody holds a weapon: no round, no roles
    boot(w, 1.0)
    local reticle = w:find(function(i) return i.ClassName == "Frame" and i.Name == "AimReticle" end)
    w:click(w:rowButton("Aim reticle")); w:click(w:option("Always", "Aim reticle")); w:run(0.3)
    check(not reticle.Visible, "no round -> no reticle, even on 'Always'")
    local w2 = newGame()
    local alice, bob = round(w2)
    w2:giveTool(w2.me, "Gun", {held = true})
    boot(w2, 1.0)
    local r2 = w2:find(function(i) return i.ClassName == "Frame" and i.Name == "AimReticle" end)
    check(r2.Visible, "with a murderer in sight it shows")
    w2:setCamera({0, 5, 0}, {0, 5, 10})                               -- looking away: the target is behind me
    w2:run(0.4)
    check(not r2.Visible, "target off screen -> hidden")
    clean(w, "reticle idle"); clean(w2, "reticle behind")
end

------------------------------------------------------------------------------------------------ layout: does it fit, at every size?
section("layout at phone and desktop sizes")
do
    local sizes = {{"phone 844x390", 844, 390}, {"small phone 740x360", 740, 360}, {"tiny 640x360", 640, 360}, {"tablet 1024x768", 1024, 768}, {"desktop 1920x1080", 1920, 1080}}
    for _, sz in ipairs(sizes) do
        local w = World.new(); w:installJson()
        rawget(w.camera, "__d").props.ViewportSize = w.env.Vector2.new(sz[2], sz[3])
        local me = w:addPlayer("Me", {pos = {0, 3, 0}}); w:setLocal(me); w.me = me
        local alice = w:addPlayer("Alice", {pos = {0, 3, -40}, vel = {10, 0, 0}}); local bob = w:addPlayer("Bob", {pos = {20, 3, -20}})
        w:giveTool(alice, "Knife", {held = true}); w:giveTool(bob, "Gun", {held = true})
        rawget(w.camera, "__d").props.ViewportSize = w.env.Vector2.new(sz[2], sz[3])
        boot(w, 1.0)
        local vp = w.env.Vector2.new(sz[2], sz[3])
        for _, tab in ipairs({"Main", "ESP", "Combat", "Buttons", "Player", "Settings", "Debug"}) do
            w:tab(tab); w:run(0.1)
            local data = w:previewAll(vp)
            check(#data.problems == 0, sz[1] .. " / " .. tab .. ": layout problems: " .. table.concat(data.problems, " | "):sub(1, 600))
        end
        local win = w:find(function(i) return i.ClassName == "Frame" and i.Name == "Window" end)
        local ax, ay, aw, ah = win.AbsolutePosition.X, win.AbsolutePosition.Y, win.AbsoluteSize.X, win.AbsoluteSize.Y
        check(ax >= 0 and ay >= 0 and ax + aw <= sz[2] and ay + ah <= sz[3], sz[1] .. ": the window is inside the screen (" .. string.format("%.0f,%.0f %.0fx%.0f", ax, ay, aw, ah) .. ")")
        check(aw >= 380 or aw >= sz[2] * 0.5, sz[1] .. ": the window is not tiny")
        -- header: title, subtitle and the three controls do not overlap
        local function box(name) local i = w:find(function(i) return i.Name == name and (i.ClassName == "TextButton" or i.ClassName == "TextLabel") end) return {x = i.AbsolutePosition.X, y = i.AbsolutePosition.Y, w = i.AbsoluteSize.X, h = i.AbsoluteSize.Y} end
        local function overlap(a, b) return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h end
        local c, m, n = box("Close"), box("Maximize"), box("Minimize")
        check(not overlap(c, m) and not overlap(m, n) and not overlap(c, n), sz[1] .. ": the three window controls do not overlap")
        local title = box("Title")
        check(not overlap(title, n), sz[1] .. ": the title does not run under the controls")
        check(c.w >= 28 and c.h >= 28, sz[1] .. ": controls are big enough to tap (" .. c.w .. "x" .. c.h .. ")")
        -- floating buttons: inside the screen, apart from each other, not on top of the open window
        w:toggle("Show Grab Gun"); w:toggle("Show Speed toggle"); w:toggle("Show Jump toggle"); w:run(0.1)
        w:previewAll(vp)                                              -- (lay the newly shown buttons out)
        local ids, boxes = {"shoot", "throw", "grab", "speed", "jump"}, {}
        for i, id in ipairs(ids) do
            local b = w:button("Float_" .. id)
            boxes[i] = {x = b.AbsolutePosition.X, y = b.AbsolutePosition.Y, w = b.AbsoluteSize.X, h = b.AbsoluteSize.Y}
            check(boxes[i].w == 80 and boxes[i].h == 80, sz[1] .. ": Float_" .. id .. " has been laid out (80x80)")
            check(boxes[i].x >= 0 and boxes[i].y >= 0 and boxes[i].x + boxes[i].w <= sz[2] and boxes[i].y + boxes[i].h <= sz[3], sz[1] .. ": Float_" .. id .. " is on screen")
        end
        for i = 1, #ids do for j = i + 1, #ids do
            check(not overlap(boxes[i], boxes[j]), sz[1] .. ": " .. ids[i] .. " and " .. ids[j] .. " buttons do not overlap")
        end end
        local fs, ft = w:button("Float_shoot"), w:button("Float_throw")
        local bs = {x = fs.AbsolutePosition.X, y = fs.AbsolutePosition.Y, w = fs.AbsoluteSize.X, h = fs.AbsoluteSize.Y}
        local bt = {x = ft.AbsolutePosition.X, y = ft.AbsolutePosition.Y, w = ft.AbsoluteSize.X, h = ft.AbsoluteSize.Y}
        check(bs.x >= 0 and bs.y >= 0 and bs.x + bs.w <= sz[2] and bs.y + bs.h <= sz[3] and bt.x + bt.w <= sz[2] and bt.y + bt.h <= sz[3], sz[1] .. ": SHOOT and THROW are on screen")
        check(not overlap(bs, bt), sz[1] .. ": SHOOT and THROW do not overlap each other")
        local wb = {x = ax, y = ay, w = aw, h = ah}
        check(not overlap(bs, wb) and not overlap(bt, wb), sz[1] .. ": ...nor the open window")
        -- every row keeps the text readable: no text wider than its label (also in problems), and rows fill the page
        local page = w:find(function(i) return i.ClassName == "Frame" and i.Name == "Debug" and i.Parent.ClassName == "ScrollingFrame" end)
        check(page.AbsoluteSize.X > 200, sz[1] .. ": the content column is wide enough (" .. page.AbsoluteSize.X .. "px)")
        clean(w, "layout " .. sz[1])
    end
end

section("everything says Wraith's Hub")
do
    local w = newGame()
    round(w, {noTools = true})
    boot(w, 0.8)
    check(w:find(function(i) return i.ClassName == "TextLabel" and i.Name == "Title" and i.Text == "Wraith's Hub" end) ~= nil, "the window title is Wraith's Hub")
    check(w:find(function(i) return i.ClassName == "TextLabel" and i.Name == "PillTitle" and i.Text == "Wraith's Hub" end) ~= nil, "the pill says Wraith's Hub")
    check(w:find(function(i) return i.ClassName == "TextLabel" and i.Name == "GroupName" and i.Text == "Wraith's Hub" end) ~= nil, "the tab group is called Wraith's Hub")
    check(hasToast(w, "Wraith's Hub loaded"), "the welcome toast says Wraith's Hub loaded")
    local stale = w:findAll(function(i) return (i.ClassName == "TextLabel" or i.ClassName == "TextButton") and (i.Text:find("MM2 Hub") or i.Text:find("Label$") and i.Text == "Label") end)
    check(#stale == 0, "no leftover 'MM2 Hub' / default 'Label' text")
    check(w.genv.__WraithsHub ~= nil and w.genv.__MM2Hub == nil, "the session is registered as __WraithsHub")
    w:click(w:rowButton("Save config")); w:run(0.1)
    check(w.files["wraiths_hub_config.json"] ~= nil and w.files["mm2_hub_config.json"] == nil, "the config file is wraiths_hub_config.json")
    clean(w, "naming")
end

print(string.format("\n%d checks passed, %d failed", passes, #failures))
for _, f in ipairs(failures) do print("FAIL  " .. f) end
if #failures > 0 then os.exit(1) end
