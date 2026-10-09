--[[
    combo_options.lua - per-combo settings (every tech can have its own timing / side / auto-timing mode).
    Pure Lua, no Roblox APIs, unit-tested in tests/run_tests.lua.

    A combo's options table:
      auto      "global" | "on" | "off"   follow the global Auto-timing toggle, or force it for this combo
      speed     0.5..2     multiplies every gap of this combo
      m1/dash/move/jump  0..max   gap override in seconds, 0 = use the global gap from the Timing tab
      offsetMs  -100..100  fine-tune added (in auto mode) to gaps that wait for a visible cue
      side      "Closest" | "Left" | "Right"   which way a SIDEDASH step goes: toward the nearest player (no teleport -
                                  it just picks the A or D key), or always left / right
      trigger   0..64      Assist mode: after WHICH step (1-based) the script takes over; 0 = after your first move
      pinMode   "assist" | "run"   what the on-screen button does: arm / disarm Assist, or run the whole combo
      trigAnim  string     animation id learned for the trigger move (lets Assist work with on-screen touch buttons)
]]

local M = {}

M.DEFAULTS = {auto = "global", speed = 1, m1 = 0, dash = 0, move = 0, jump = 0, offsetMs = 0, side = "Closest",
    trigger = 0, pinMode = "assist", trigAnim = ""}

local RANGES = {
    speed = {0.5, 2}, m1 = {0, 0.6}, dash = {0, 0.8}, move = {0, 1.2}, jump = {0, 0.6}, offsetMs = {-100, 100},
}
M.RANGES = RANGES

local AUTO = {global = true, on = true, off = true}
local SIDE = {Closest = true, Left = true, Right = true}
local PINMODE = {assist = true, run = true}

local function clamp(v, lo, hi, default)
    if type(v) ~= "number" or v ~= v then return default end      -- not a number / NaN
    return math.min(math.max(v, lo), hi)
end

-- Always returns a complete, valid options table, whatever garbage (e.g. a hand-edited save file) goes in.
function M.sanitize(src)
    src = type(src) == "table" and src or {}
    local o = {}
    for key, range in pairs(RANGES) do
        o[key] = clamp(src[key], range[1], range[2], M.DEFAULTS[key])
    end
    o.auto = AUTO[src.auto] and src.auto or M.DEFAULTS.auto
    o.side = SIDE[src.side] and src.side or M.DEFAULTS.side
    o.pinMode = PINMODE[src.pinMode] and src.pinMode or M.DEFAULTS.pinMode
    o.trigger = math.floor(clamp(src.trigger, 0, 64, M.DEFAULTS.trigger))
    -- an animation id is plain text like "rbxassetid://123"; anything odd or huge is thrown away
    local anim = src.trigAnim
    if type(anim) == "string" and #anim <= 120 and not anim:find("[%c]") then o.trigAnim = anim else o.trigAnim = M.DEFAULTS.trigAnim end
    return o
end

function M.new() return M.sanitize(nil) end

function M.isDefault(o)
    for key, def in pairs(M.DEFAULTS) do
        if o[key] ~= def then return false end
    end
    return true
end

-- is auto (ping) timing active for this combo?
function M.autoOn(globalOn, o)
    if o.auto == "on" then return true end
    if o.auto == "off" then return false end
    return globalOn and true or false
end

-- gap in seconds for a step kind ("m1"|"dash"|"move"|"jump") before the ping adjustment:
-- the combo's own override if set, else the global gap; then global speed x combo speed
function M.gap(kind, timing, o, globalSpeed)
    local own = o[kind]
    local base = (type(own) == "number" and own > 0) and own or timing[kind]
    return base * (globalSpeed or 1) * o.speed
end

return M
