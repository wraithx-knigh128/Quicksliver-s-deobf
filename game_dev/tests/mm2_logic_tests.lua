-- Unit tests for mm2/logic.lua (plain Lua / Luau, no Roblox). Run: python3 tests/run_mm2.py logic
local Logic = LOGIC_MODULE
local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print("PASS  " .. name) else failed = failed + 1; print("FAIL  " .. name .. "\n      " .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2) end end
local function near(a, b, eps, msg) if math.abs(a - b) > (eps or 1e-6) then error((msg or "") .. " expected " .. b .. " got " .. a, 2) end end

test("roles: names and synonyms", function()
    eq(Logic.normalizeRole("Murderer"), "Murderer"); eq(Logic.normalizeRole(" sheriff "), "Sheriff")
    eq(Logic.normalizeRole("HERO"), "Hero"); eq(Logic.normalizeRole("Innocent"), "Innocent")
    eq(Logic.normalizeRole("banana"), nil); eq(Logic.normalizeRole(5), nil); eq(Logic.normalizeRole(nil), nil)
end)
test("roles: tool names", function()
    eq(Logic.toolRole("Knife"), "Murderer"); eq(Logic.toolRole("Golden Knife"), "Murderer"); eq(Logic.toolRole("knife"), "Murderer")
    eq(Logic.toolRole("Gun"), "Sheriff"); eq(Logic.toolRole("gun"), "Sheriff"); eq(Logic.toolRole("Revolver"), "Sheriff"); eq(Logic.toolRole("Gun Skin"), "Sheriff")
    eq(Logic.toolRole("Gunk"), nil); eq(Logic.toolRole("Sunglasses"), nil); eq(Logic.toolRole("Emote"), nil); eq(Logic.toolRole(nil), nil)
    eq(Logic.weaponOf("Knife"), "Knife"); eq(Logic.weaponOf("Gun"), "Gun"); eq(Logic.weaponOf("Coin"), nil)
end)
test("roles: parseRoles handles the common shapes", function()
    local function find(list, key) for _, e in ipairs(list) do if e.key == key then return e end end end
    local a = Logic.parseRoles({Bob = {Role = "Murderer", Killed = false}, Amy = {Role = "Sheriff", Dead = true}, Cy = {Role = "Innocent"}})
    eq(find(a, "Bob").role, "Murderer"); eq(find(a, "Amy").role, "Sheriff"); eq(find(a, "Amy").dead, true); eq(find(a, "Bob").dead, false); eq(#a, 3)
    local b = Logic.parseRoles({Bob = "Murderer", Amy = "sheriff"}); eq(find(b, "Bob").role, "Murderer"); eq(find(b, "Amy").role, "Sheriff")
    local c = Logic.parseRoles({Murderer = "Bob", Sheriff = "Amy"}); eq(find(c, "Bob").role, "Murderer"); eq(find(c, "Amy").role, "Sheriff")
    local d = Logic.parseRoles({Players = {Bob = {Role = "Hero"}}}); eq(find(d, "Bob").role, "Hero")
    local e = Logic.parseRoles({[1234] = {role = "Murderer"}}); eq(find(e, 1234).role, "Murderer")
    eq(#Logic.parseRoles(nil), 0); eq(#Logic.parseRoles(5), 0); eq(#Logic.parseRoles({x = {y = {z = {w = {Role = "Murderer"}}}}}), 0, "too deep")
    eq(#Logic.parseRoles({Bob = {Role = "Spectator"}}), 0)
end)

test("lead: stationary target is not moved", function()
    local x, y, z = Logic.lead(10, 5, 10, 0, 0, 0, 0, 0, 0, {speed = 100, latency = 0.1})
    near(x, 10); near(y, 5); near(z, 10)
end)
test("lead: instant projectile only leads by latency", function()
    local x, _, z, t = Logic.lead(0, 0, 0, 10, 0, 0, 0, 0, 50, {speed = 0, latency = 0.1})
    near(x, 1, 1e-9); near(z, 0); near(t, 0.1)
end)
test("lead: finite projectile speed leads by flight time (solves the intercept)", function()
    -- target 100 studs away moving sideways at 20 studs/s, bullet 200 studs/s: the shot meets it where |p - s| / 200 = x / 20
    local px, _, pz, t = Logic.lead(100, 0, 0, 0, 0, 20, 0, 0, 0, {speed = 200, latency = 0, maxLead = 5})
    local flight = math.sqrt(px * px + pz * pz) / 200
    near(flight, t, 1e-3, "flight time"); near(pz, 20 * t, 1e-6)
end)
test("lead: strength 0 disables it, maxLead clamps it, vertical scales it", function()
    local x = Logic.lead(0, 0, 0, 50, 0, 0, 0, 0, 0, {speed = 10, latency = 1, strength = 0}); near(x, 0)
    local x2, _, _, t2 = Logic.lead(0, 0, 0, 10, 0, 0, 0, 0, 0, {latency = 5, maxLead = 0.5}); near(t2, 0.5); near(x2, 5)
    local _, y3 = Logic.lead(0, 0, 0, 0, 10, 0, 0, 0, 0, {latency = 1, vertical = 0}); near(y3, 0)
    local _, y4 = Logic.lead(0, 0, 0, 0, 10, 0, 0, 0, 0, {latency = 1, vertical = 1, maxLead = 2}); near(y4, 10)
end)

test("direction: 8 sectors relative to where I look", function()
    -- looking down -Z (Roblox default): ahead = -Z, right = +X
    eq((Logic.direction(0, -10, 0, -1)), "ahead"); eq((Logic.direction(10, 0, 0, -1)), "right")
    eq((Logic.direction(0, 10, 0, -1)), "behind"); eq((Logic.direction(-10, 0, 0, -1)), "left")
    eq((Logic.direction(10, -10, 0, -1)), "ahead-right"); eq((Logic.direction(-10, -10, 0, -1)), "ahead-left")
    eq((Logic.direction(10, 10, 0, -1)), "behind-right"); eq((Logic.direction(-10, 10, 0, -1)), "behind-left")
    -- looking down +X: ahead = +X, right = +Z
    eq((Logic.direction(10, 0, 1, 0)), "ahead"); eq((Logic.direction(0, 10, 1, 0)), "right"); eq((Logic.direction(0, -10, 1, 0)), "left")
    eq((Logic.direction(5, 0, 0, 0)), "right", "zero look vector falls back to -Z")
end)
test("describe: distance, side and height", function()
    eq(Logic.describe(0, 0, -37, 0, -1), "37 studs ahead")
    eq(Logic.describe(-30, 10, -30, 0, -1), "44 studs ahead-left, 10 higher")
    eq(Logic.describe(0, -9, 0.5, 0, -1), "9 studs right here, 9 lower")
end)

test("pickTarget: nearest, murderer, sheriff, crosshair, visibility, range", function()
    local c = {{id = "a", dist = 50, role = "Innocent"}, {id = "b", dist = 30, role = "Murderer"}, {id = "c", dist = 10, role = "Sheriff"}, {id = "d", dist = 5, role = "Innocent", alive = false}}
    eq(Logic.pickTarget(c, {mode = "Nearest"}), "c", "dead players are skipped")
    eq(Logic.pickTarget(c, {mode = "Murderer"}), "b"); eq(Logic.pickTarget(c, {mode = "Sheriff"}), "c")
    eq(Logic.pickTarget(c, {mode = "Murderer", maxDist = 20}), nil)
    local v = {{id = "a", dist = 10, visible = false, screen = 10}, {id = "b", dist = 40, visible = true, screen = 200}}
    eq(Logic.pickTarget(v, {mode = "Nearest"}), "a"); eq(Logic.pickTarget(v, {mode = "Nearest", needVisible = true}), "b")
    eq(Logic.pickTarget(v, {mode = "Closest to crosshair", fov = 150}), "a"); eq(Logic.pickTarget(v, {mode = "Closest to crosshair", fov = 5}), nil)
    eq(Logic.pickTarget(v, {mode = "Closest to crosshair", fov = 500, needVisible = true}), "b")
    eq(Logic.pickTarget({}, {mode = "Nearest"}), nil)
end)

test("planShot: which argument is the aim point", function()
    local function d(kind, x, y, z) return {kind = kind, x = x, y = y, z = z} end
    -- (origin CFrame near my head, target CFrame far away)
    local p = Logic.planShot({d("cf", 1, 5, 1), d("cf", 80, 3, -40)}, 0, 5, 0)
    eq(p[1], "origin"); eq(p[2], "target")
    -- order does not matter
    p = Logic.planShot({d("cf", 80, 3, -40), d("cf", 1, 5, 1)}, 0, 5, 0); eq(p[1], "target"); eq(p[2], "origin")
    -- a single position is the aim point, even if it is close to me
    p = Logic.planShot({d("vec", 2, 5, 0)}, 0, 5, 0); eq(p[1], "target")
    -- non-position arguments are left alone
    p = Logic.planShot({d("vec", 90, 0, 0), d("other"), d("inst"), d("vec", 1, 5, 0)}, 0, 5, 0); eq(p[1], "target"); eq(p[2], nil); eq(p[3], nil); eq(p[4], "origin")
    -- nothing close to my head: all are aim points
    p = Logic.planShot({d("vec", 90, 0, 0), d("vec", 100, 0, 0)}, 0, 5, 0); eq(p[1], "target"); eq(p[2], "target")
    eq(next(Logic.planShot({d("other"), d("inst")}, 0, 0, 0)), nil)
end)
test("looksLikeShotRemote", function()
    eq(Logic.looksLikeShotRemote("Shoot"), true); eq(Logic.looksLikeShotRemote("KnifeThrown"), true); eq(Logic.looksLikeShotRemote("MovementUpdate"), false)
    eq(Logic.looksLikeShotRemote(nil), false)
end)
test("mergeFlags: only known keys with the right type", function()
    local m = Logic.mergeFlags({a = true, b = 5, c = "x"}, {a = false, b = "no", c = "y", z = 1})
    eq(m.a, false); eq(m.b, 5); eq(m.c, "y"); eq(m.z, nil)
    eq(Logic.mergeFlags({a = 1}, 5).a, 1); eq(Logic.mergeFlags({a = 1}, nil).a, 1)
end)
test("clamp", function() eq(Logic.clamp(5, 0, 3), 3); eq(Logic.clamp(-1, 0, 3), 0); eq(Logic.clamp(2, 0, 3), 2) end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then error("logic tests failed") end
