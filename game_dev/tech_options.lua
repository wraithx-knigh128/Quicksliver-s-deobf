--[[
    tech_options.lua - the options of every Tech Lab tech: definitions -> always-valid values. Pure Lua (no Roblox APIs), unit-tested.

      A definition list is  {{key = "delay", label = "Delay (ms)", kind = "number", min = 0, max = 500, step = 5, default = 250},
                             {key = "behind", label = "Teleport behind", kind = "bool", default = true},
                             {key = "side", label = "Side", kind = "choice", choices = {"Closest", "Left", "Right"}, default = "Closest"}}

      TechOptions.defaults(defs)        {key = default}
      TechOptions.clean(defs, saved)    a complete valid table: numbers clamped (and snapped to step), bools / choices checked, anything unknown dropped
      TechOptions.isDefault(defs, o)    nothing differs from the defaults (used to keep the config file small)
      TechOptions.diff(defs, o)         only the keys that differ from the defaults
]]

local M = {}

local function isnum(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

local function cleanOne(def, v)
    local kind = def.kind or "number"
    if kind == "bool" then
        if type(v) == "boolean" then return v end
        return def.default == true
    elseif kind == "choice" then
        for _, c in ipairs(def.choices or {}) do if v == c then return v end end
        return def.default
    elseif kind == "string" then
        if type(v) == "string" and #v <= 60 and not v:find("%c") then return v end
        return def.default or ""
    end
    if not isnum(v) then return def.default end
    local lo, hi = def.min or -math.huge, def.max or math.huge
    v = math.max(lo, math.min(hi, v))
    local step = def.step
    if isnum(step) and step > 0 then
        v = math.floor((v - (isnum(def.min) and def.min or 0)) / step + 0.5) * step + (isnum(def.min) and def.min or 0)
        v = math.max(lo, math.min(hi, v))
        v = tonumber(string.format("%.6g", v))
    end
    return v
end

function M.defaults(defs)
    local out = {}
    for _, d in ipairs(defs or {}) do out[d.key] = d.default end
    return out
end

function M.clean(defs, saved)
    local out = {}
    saved = type(saved) == "table" and saved or {}
    for _, d in ipairs(defs or {}) do
        local v = saved[d.key]
        if v == nil then out[d.key] = d.default else out[d.key] = cleanOne(d, v) end
    end
    return out
end

function M.isDefault(defs, o)
    o = o or {}
    for _, d in ipairs(defs or {}) do
        if o[d.key] ~= nil and o[d.key] ~= d.default then return false end
    end
    return true
end

function M.diff(defs, o)
    local out = {}
    o = o or {}
    for _, d in ipairs(defs or {}) do
        if o[d.key] ~= nil and o[d.key] ~= d.default then out[d.key] = o[d.key] end
    end
    return out
end

return M
