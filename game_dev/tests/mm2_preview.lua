-- Builds a few screens of the hub in the fake world, lays them out and writes JSON draw lists for tools/render_preview.py.
-- python3 tests/run_mm2.py preview ../dist/wraiths_hub.lua   (writes ../preview/mm2/<scene>.json and renders PNGs)
local World = MM2_WORLD
local problemsTotal = {}
local function scene(name, vp, setup)
    local w = World.new(); w:installJson()
    rawget(w.camera, "__d").props.ViewportSize = w.env.Vector2.new(vp[1], vp[2])
    local me = w:addPlayer("Me", {pos = {0, 3, 0}}); w:setLocal(me); w.me = me
    local alice = w:addPlayer("Alice", {pos = {0, 3, -40}, vel = {10, 0, 0}})
    local bob = w:addPlayer("Bob", {pos = {20, 3, -20}})
    w:addPlayer("Cy", {pos = {-15, 3, -30}})
    w:giveTool(alice, "Knife", {held = true}); w:giveTool(bob, "Gun", {held = true})
    w.alice, w.bob = alice, bob
    rawget(w.camera, "__d").props.ViewportSize = w.env.Vector2.new(vp[1], vp[2])
    assert(w:load(SCRIPT_SOURCE))
    w:run(1.0)
    if setup then setup(w) end
    w:run(0.6)
    local data = w:previewAll(w.env.Vector2.new(vp[1], vp[2]))
    local json = w.jsonEncode(data)
    if PREVIEW_DIR then
        local f = assert(io.open(PREVIEW_DIR .. "/" .. name .. ".json", "w"))
        f:write(json); f:close()
    end
    for _, p in ipairs(data.problems) do problemsTotal[#problemsTotal + 1] = name .. ": " .. p end
    print(string.format("%-22s %dx%d  %d draw ops, %d layout problems", name, vp[1], vp[2], #data.ops, #data.problems))
    return w
end
local PHONE, DESK = {844, 390}, {1280, 720}
for _, spec in ipairs(PREVIEW_SCENES or {"phone_main", "phone_combat", "phone_buttons", "phone_hidden", "phone_play", "desktop_main", "phone_search", "phone_gundrop"}) do
    if spec == "phone_main" then scene(spec, PHONE)
    elseif spec == "phone_combat" then scene(spec, PHONE, function(w) w:tab("Combat") end)
    elseif spec == "phone_hidden" then scene(spec, PHONE, function(w) w:click(w:button("Close")) end)
    elseif spec == "desktop_main" then scene(spec, DESK)
    elseif spec == "phone_buttons" then scene(spec, PHONE, function(w) w:tab("Buttons") end)
    elseif spec == "phone_play" then scene(spec, PHONE, function(w)
        w:giveTool(w.me, "Gun", {held = true}); w:toggle("Show Speed toggle"); w:toggle("Show Jump toggle"); w:toggle("Show Grab Gun")
        w:toggle("Walk speed"); w:click(w:button("Close")); w:dropGun({30, 3, -20}); w:run(1.0)
    end)
    elseif spec == "phone_search" then scene(spec, PHONE, function(w) w:typeInto(w:find(function(i) return i.ClassName == "TextBox" end), "shoot") end)
    elseif spec == "phone_gundrop" then scene(spec, PHONE, function(w) w:dropGun({0, 3, -37}) end)
    end
end
for _, p in ipairs(problemsTotal) do print("LAYOUT " .. p) end
print(string.format("\n%d layout problems", #problemsTotal))
