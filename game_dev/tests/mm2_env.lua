-- A fake Roblox world for the MM2 hub tests (plain Lua 5.x and Luau; no Roblox needed).
-- Real instance tree (parenting, ChildAdded / DescendantAdded, IsA with the real class hierarchy), real Vector3 / CFrame math, a coroutine scheduler
-- for task.wait / task.delay, RunService signals, remotes + an executor-style __namecall hook, and strict member checking:
-- reading a member that does not exist, assigning the wrong value type, or calling a missing method THROWS exactly like Roblox does
-- (the tables come from Roblox's API dump: tests/prop_types_mm2.lua). Every such error is also recorded in World.thrown, so errors that the
-- script swallows with pcall are still caught by the tests.
local loader = loadstring or load
local TYPES = loader(PROP_TYPES_SOURCE)()
local supers, classes = TYPES.supers, TYPES.classes

local World = {}
World.__index = World

local sqrt, floor, rad, tan = math.sqrt, math.floor, math.rad, math.tan

------------------------------------------------------------------------------------------------ data types
local function typeMT(name) return {__type = name} end

local V3 = typeMT("Vector3")
local function Vector3_new(x, y, z) return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, V3) end
V3.__index = function(v, k)
    if k == "Magnitude" then return sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
    if k == "Unit" then local m = sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z); if m == 0 then return v end return Vector3_new(v.X / m, v.Y / m, v.Z / m) end
    if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
    if k == "Cross" then return function(a, b) return Vector3_new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end end
    if k == "Lerp" then return function(a, b, t) return Vector3_new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end end
    error(tostring(k) .. " is not a valid member of Vector3", 2)
end
V3.__add = function(a, b) return Vector3_new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3_new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
    if type(a) == "number" then return Vector3_new(a * b.X, a * b.Y, a * b.Z) end
    if type(b) == "number" then return Vector3_new(a.X * b, a.Y * b, a.Z * b) end
    return Vector3_new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) if type(b) == "number" then return Vector3_new(a.X / b, a.Y / b, a.Z / b) end return Vector3_new(a.X / b.X, a.Y / b.Y, a.Z / b.Z) end
V3.__unm = function(a) return Vector3_new(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(v) return string.format("%g, %g, %g", v.X, v.Y, v.Z) end

local V2 = typeMT("Vector2")
local function Vector2_new(x, y) return setmetatable({X = x or 0, Y = y or 0}, V2) end
V2.__index = function(v, k)
    if k == "Magnitude" then return sqrt(v.X * v.X + v.Y * v.Y) end
    error(tostring(k) .. " is not a valid member of Vector2", 2)
end
V2.__add = function(a, b) return Vector2_new(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return Vector2_new(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b) if type(b) == "number" then return Vector2_new(a.X * b, a.Y * b) end if type(a) == "number" then return Vector2_new(a * b.X, a * b.Y) end return Vector2_new(a.X * b.X, a.Y * b.Y) end
V2.__div = function(a, b) if type(b) == "number" then return Vector2_new(a.X / b, a.Y / b) end return Vector2_new(a.X / b.X, a.Y / b.Y) end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
V2.__tostring = function(v) return string.format("%g, %g", v.X, v.Y) end

-- CFrame = position + rotation matrix columns (right, up, back)
local CF = typeMT("CFrame")
local function norm(x, y, z) local m = sqrt(x * x + y * y + z * z); if m == 0 then return 0, 0, 0 end return x / m, y / m, z / m end
local function cframe(px, py, pz, r) return setmetatable({p = {px, py, pz}, r = r or {1, 0, 0, 0, 1, 0, 0, 0, 1}}, CF) end   -- r = {Rx,Ry,Rz, Ux,Uy,Uz, Bx,By,Bz}
local function lookAt(at, target, up)
    up = up or Vector3_new(0, 1, 0)
    local lx, ly, lz = norm(target.X - at.X, target.Y - at.Y, target.Z - at.Z)
    if lx == 0 and ly == 0 and lz == 0 then return cframe(at.X, at.Y, at.Z) end
    local rx, ry, rz = norm(ly * up.Z - lz * up.Y, lz * up.X - lx * up.Z, lx * up.Y - ly * up.X)
    if rx == 0 and ry == 0 and rz == 0 then rx, ry, rz = 1, 0, 0 end                     -- looking straight up / down
    local ux, uy, uz = ry * lz - rz * ly, rz * lx - rx * lz, rx * ly - ry * lx
    return cframe(at.X, at.Y, at.Z, {rx, ry, rz, ux, uy, uz, -lx, -ly, -lz})
end
CF.__index = function(c, k)
    local p, r = c.p, c.r
    if k == "Position" then return Vector3_new(p[1], p[2], p[3]) end
    if k == "X" then return p[1] elseif k == "Y" then return p[2] elseif k == "Z" then return p[3] end
    if k == "LookVector" then return Vector3_new(-r[7], -r[8], -r[9]) end
    if k == "RightVector" then return Vector3_new(r[1], r[2], r[3]) end
    if k == "UpVector" then return Vector3_new(r[4], r[5], r[6]) end
    if k == "Lerp" then
        return function(a, b, t)
            local pos = Vector3_new(a.p[1] + (b.p[1] - a.p[1]) * t, a.p[2] + (b.p[2] - a.p[2]) * t, a.p[3] + (b.p[3] - a.p[3]) * t)
            local la, lb = a.LookVector, b.LookVector
            local l = Vector3_new(la.X + (lb.X - la.X) * t, la.Y + (lb.Y - la.Y) * t, la.Z + (lb.Z - la.Z) * t)
            return lookAt(pos, pos + l)
        end
    end
    error(tostring(k) .. " is not a valid member of CFrame", 2)
end
CF.__mul = function(a, b)
    if getmetatable(b) == V3 then
        local r, p = a.r, a.p
        return Vector3_new(p[1] + r[1] * b.X + r[4] * b.Y + r[7] * b.Z, p[2] + r[2] * b.X + r[5] * b.Y + r[8] * b.Z, p[3] + r[3] * b.X + r[6] * b.Y + r[9] * b.Z)
    end
    local pos = a * Vector3_new(b.p[1], b.p[2], b.p[3])
    local ar, br, out = a.r, b.r, {}
    for col = 0, 2 do                                                                    -- columns of b rotated by a
        local bx, by, bz = br[col * 3 + 1], br[col * 3 + 2], br[col * 3 + 3]
        out[col * 3 + 1] = ar[1] * bx + ar[4] * by + ar[7] * bz
        out[col * 3 + 2] = ar[2] * bx + ar[5] * by + ar[8] * bz
        out[col * 3 + 3] = ar[3] * bx + ar[6] * by + ar[9] * bz
    end
    return cframe(pos.X, pos.Y, pos.Z, out)
end
CF.__eq = function(a, b)
    for i = 1, 3 do if a.p[i] ~= b.p[i] then return false end end
    for i = 1, 9 do if a.r[i] ~= b.r[i] then return false end end
    return true
end
local CFrame_lib = {
    new = function(a, b, c)
        if type(a) == "number" then return cframe(a, b, c) end
        if a == nil then return cframe(0, 0, 0) end
        if b ~= nil then return lookAt(a, b) end
        return cframe(a.X, a.Y, a.Z)
    end,
    lookAt = lookAt,
}

local C3 = typeMT("Color3")
local function color3(r, g, b) return setmetatable({R = r, G = g, B = b}, C3) end
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
C3.__index = function(_, k) error(tostring(k) .. " is not a valid member of Color3", 2) end
local Color3_lib = {new = color3, fromRGB = function(r, g, b) return color3(r / 255, g / 255, b / 255) end}

local UD = typeMT("UDim")
local function udim(s, o) return setmetatable({Scale = s or 0, Offset = o or 0}, UD) end
UD.__eq = function(a, b) return a.Scale == b.Scale and a.Offset == b.Offset end
UD.__index = function(_, k) error(tostring(k) .. " is not a valid member of UDim", 2) end
local UD2 = typeMT("UDim2")
local function udim2(xs, xo, ys, yo)
    local t = {X = udim(xs, xo), Y = udim(ys, yo)}
    t.Width, t.Height = t.X, t.Y
    return setmetatable(t, UD2)
end
UD2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
UD2.__add = function(a, b) return udim2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset) end
UD2.__index = function(_, k) error(tostring(k) .. " is not a valid member of UDim2", 2) end
local UDim2_lib = {new = udim2, fromOffset = function(x, y) return udim2(0, x, 0, y) end, fromScale = function(x, y) return udim2(x, 0, y, 0) end}

local function plainType(name) return setmetatable({}, {__type = name}) end

local function kindOf(v)
    local t = type(v)
    if t ~= "table" then return t end
    local mt = getmetatable(v)
    return mt and mt.__type or "table"
end

------------------------------------------------------------------------------------------------ enums
local enumCounter = 0
local function makeEnums()
    return setmetatable({}, {__index = function(all, enumName)
        local e = setmetatable({}, {__type = "Enum", __index = function(items, itemName)
            enumCounter = enumCounter + 1
            local item = setmetatable({Name = itemName, EnumType = enumName, Value = enumCounter}, {__type = "EnumItem", __tostring = function() return "Enum." .. enumName .. "." .. itemName end})
            rawset(items, itemName, item)
            return item
        end})
        rawset(all, enumName, e)
        return e
    end})
end

------------------------------------------------------------------------------------------------ the world
local InstMT = {__type = "Instance"}
local READONLY = {AbsoluteSize = true, AbsolutePosition = true, ClassName = true, AbsoluteContentSize = true}
local DEFAULTS = {
    Visible = true, Enabled = true, CanCollide = true, Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, UseJumpPower = true,
    FieldOfView = 70, Active = true, Archivable = true, BorderSizePixel = 1, BackgroundTransparency = 0, TextSize = 14, Transparency = 0,
}

function World.new(opts)
    opts = opts or {}
    local W = setmetatable({}, World)
    W.opts = opts
    W.now = 1000
    W.thrown, W.errors, W.printed, W.coreNotes, W.sent, W.vim, W.calls, W.warns = {}, {}, {}, {}, {}, {}, {}, {}
    W.threads, W.renderSteps = {}, {}
    W.files = {}
    W.unknownClasses = {}
    W.Enum = makeEnums()
    W.genv = {}

    local function throw(msg, level)
        W.thrown[#W.thrown + 1] = msg
        error(msg, (level or 1) + 1)
    end
    W.throw = throw

    local function isInstance(v) return type(v) == "table" and getmetatable(v) == InstMT end
    W.isInstance = isInstance

    local function isA(class, target)
        local c = class
        while c do
            if c == target then return true end
            c = supers[c]
        end
        return target == "Instance"
    end
    local function classInfo(class)
        local ci = classes[class]
        if not ci then W.unknownClasses[class] = true end
        return ci
    end
    local function validMember(class, kind, name)
        local ci = classInfo(class)
        return ci and ci[kind][name] ~= nil
    end

    -------------------------------------------------------------------------------------------- signals
    local function newSignal(label)
        local sig = {handlers = {}, label = label}
        local mt = {__type = "RBXScriptSignal"}
        local function connect(_, fn)
            local h = {fn = fn, on = true}
            sig.handlers[#sig.handlers + 1] = h
            local conn = setmetatable({Connected = true}, {__type = "RBXScriptConnection", __index = {
                Disconnect = function(c) h.on = false; c.Connected = false end}})
            return conn
        end
        sig.Connect = connect
        sig.Once = function(_, fn)
            local conn
            conn = connect(_, function(...) conn:Disconnect(); return fn(...) end)
            return conn
        end
        sig.Wait = function() error("Signal:Wait is not supported by the test world", 2) end
        return setmetatable(sig, mt)
    end
    local function fire(sig, ...)
        if not sig then return end
        local list = {}
        for i, h in ipairs(sig.handlers) do list[i] = h end
        for _, h in ipairs(list) do
            if h.on then
                local ok, err = pcall(h.fn, ...)
                if not ok then W.errors[#W.errors + 1] = "handler of " .. tostring(sig.label) .. ": " .. tostring(err) end
            end
        end
    end
    W.newSignal, W.fire = newSignal, fire
    local function signalOf(self, name)
        local d = rawget(self, "__d")
        local s = d.signals[name]
        if not s then s = newSignal(d.class .. "." .. name); d.signals[name] = s end
        return s
    end
    W.signalOf = signalOf

    -------------------------------------------------------------------------------------------- instances
    local function newData(class, name) return {class = class, name = name or class, children = {}, props = {}, signals = {}, attrs = {}} end
    local function makeRaw(class, name)
        local self = setmetatable({}, InstMT)
        rawset(self, "__d", newData(class, name))
        return self
    end
    W.makeRaw = makeRaw

    local function propType(class, key)
        local ci = classInfo(class)
        return ci and ci.props[key]
    end

    local function defaultFor(self, d, key, ptype)
        if key == "DisplayName" then return d.name end
        if d.props[key] ~= nil then return d.props[key] end
        if DEFAULTS[key] ~= nil then return DEFAULTS[key] end
        if ptype == "bool" then return false end
        if ptype == "string" or ptype == "Content" or ptype == "ContentId" then return "" end
        if ptype == "int" or ptype == "float" or ptype == "double" or ptype == "int64" then return 0 end
        if ptype == "Vector3" then return Vector3_new(0, 0, 0) end
        if ptype == "Vector2" then return Vector2_new(0, 0) end
        if ptype == "CFrame" then return cframe(0, 0, 0) end
        if ptype == "Color3" then return color3(0, 0, 0) end
        if ptype == "UDim2" then return udim2(0, 0, 0, 0) end
        if ptype == "UDim" then return udim(0, 0) end
        return nil
    end

    local function allDescendants(self, out)
        for _, c in ipairs(rawget(self, "__d").children) do
            out[#out + 1] = c
            allDescendants(c, out)
        end
        return out
    end
    local function ancestorsOf(self)
        local out, p = {}, rawget(self, "__d").parent
        while p do out[#out + 1] = p; p = rawget(p, "__d").parent end
        return out
    end

    local function setParent(self, newParent)
        local d = rawget(self, "__d")
        if newParent ~= nil and not isInstance(newParent) then throw("Parent expects an Instance, got " .. kindOf(newParent), 2) end
        if newParent ~= nil and newParent == W.coreGui and W.opts.coreLocked then
            error("Cannot set Parent to CoreGui: lacking capability Plugin", 2)
        end
        if d.destroyed and newParent ~= nil then throw("The Parent property of " .. d.name .. " is locked, current parent: NULL, new parent " .. rawget(newParent, "__d").name, 2) end
        if newParent == d.parent then return end
        local old = d.parent
        if old then
            local od = rawget(old, "__d")
            if d.class == "Player" and od.class == "Players" then fire(od.signals.PlayerRemoving, self) end
            for _, a in ipairs({old, table.unpack(ancestorsOf(old))}) do
                for _, n in ipairs({self, table.unpack(allDescendants(self, {}))}) do fire(rawget(a, "__d").signals.DescendantRemoving, n) end
            end
            fire(od.signals.ChildRemoved, self)
            for i, c in ipairs(od.children) do if c == self then table.remove(od.children, i); break end end
        end
        d.parent = newParent
        if newParent then
            local nd = rawget(newParent, "__d")
            nd.children[#nd.children + 1] = self
            fire(nd.signals.ChildAdded, self)
            local chain = {newParent, table.unpack(ancestorsOf(newParent))}
            local subtree = {self, table.unpack(allDescendants(self, {}))}
            for _, a in ipairs(chain) do
                for _, n in ipairs(subtree) do fire(rawget(a, "__d").signals.DescendantAdded, n) end
            end
        end
        if newParent and d.class == "Player" and rawget(newParent, "__d").class == "Players" then fire(rawget(newParent, "__d").signals.PlayerAdded, self) end
        fire(d.signals.AncestryChanged, self, newParent)
        fire(d.signals["Changed:Parent"])
    end
    W.setParent = setParent

    local function destroy(self)
        local d = rawget(self, "__d")
        if d.destroyed then return end
        for _, c in ipairs({table.unpack(d.children)}) do destroy(c) end
        setParent(self, nil)
        d.destroyed = true
        fire(d.signals.Destroying)
        for _, s in pairs(d.signals) do for _, h in ipairs(s.handlers) do h.on = false end end
    end

    local function fullName(self)
        local parts, cur = {}, self
        while cur do
            local d = rawget(cur, "__d")
            if d.class == "DataModel" then break end
            table.insert(parts, 1, d.name)
            cur = d.parent
        end
        return table.concat(parts, ".")
    end

    local function findChild(self, name, recursive)
        for _, c in ipairs(rawget(self, "__d").children) do
            if rawget(c, "__d").name == name then return c end
        end
        if recursive then
            for _, c in ipairs(rawget(self, "__d").children) do
                local r = findChild(c, name, true)
                if r then return r end
            end
        end
    end

    local function projectToViewport(cam, pos)
        local d = rawget(cam, "__d")
        local cf = d.props.CFrame or cframe(0, 0, 0)
        local vp = d.props.ViewportSize or Vector2_new(1280, 720)
        local fov = rad(d.props.FieldOfView or 70)
        local rel = pos - cf.Position
        local look, right, up = cf.LookVector, cf.RightVector, cf.UpVector
        local z = rel:Dot(look)
        local x, y = rel:Dot(right), rel:Dot(up)
        local f = (vp.Y / 2) / tan(fov / 2)
        if z <= 0.0001 then return Vector3_new(vp.X / 2, vp.Y / 2, z), false end
        local sx, sy = vp.X / 2 + x / z * f, vp.Y / 2 - y / z * f
        return Vector3_new(sx, sy, z), sx >= 0 and sx <= vp.X and sy >= 0 and sy <= vp.Y
    end

    -- the real implementation of every instance method (what "old namecall" runs)
    local METHODS = {}
    METHODS.GetChildren = function(self) local out = {}; for i, c in ipairs(rawget(self, "__d").children) do out[i] = c end return out end
    METHODS.GetDescendants = function(self) return allDescendants(self, {}) end
    METHODS.FindFirstChild = function(self, name, recursive) return findChild(self, name, recursive) end
    METHODS.WaitForChild = function(self, name) return findChild(self, name, false) end
    METHODS.FindFirstChildOfClass = function(self, class)
        for _, c in ipairs(rawget(self, "__d").children) do if rawget(c, "__d").class == class then return c end end
    end
    METHODS.FindFirstChildWhichIsA = function(self, class)
        for _, c in ipairs(rawget(self, "__d").children) do if isA(rawget(c, "__d").class, class) then return c end end
    end
    METHODS.FindFirstAncestor = function(self, name)
        for _, a in ipairs(ancestorsOf(self)) do if rawget(a, "__d").name == name then return a end end
    end
    METHODS.FindFirstAncestorOfClass = function(self, class)
        for _, a in ipairs(ancestorsOf(self)) do if rawget(a, "__d").class == class then return a end end
    end
    METHODS.FindFirstAncestorWhichIsA = function(self, class)
        for _, a in ipairs(ancestorsOf(self)) do if isA(rawget(a, "__d").class, class) then return a end end
    end
    METHODS.IsA = function(self, class) return isA(rawget(self, "__d").class, class) end
    METHODS.IsDescendantOf = function(self, anc)
        for _, a in ipairs(ancestorsOf(self)) do if a == anc then return true end end
        return false
    end
    METHODS.IsAncestorOf = function(self, other) return METHODS.IsDescendantOf(other, self) end
    METHODS.Destroy = destroy
    METHODS.Remove = destroy
    METHODS.GetFullName = fullName
    METHODS.GetPropertyChangedSignal = function(self, prop) return signalOf(self, "Changed:" .. prop) end
    METHODS.GetPivot = function(self)
        local d = rawget(self, "__d")
        if d.props.CFrame then return d.props.CFrame end
        for _, c in ipairs(d.children) do
            local cd = rawget(c, "__d")
            if cd.props.CFrame then return cd.props.CFrame end
        end
        return cframe(0, 0, 0)
    end
    METHODS.GetPlayers = function(self)
        local out = {}
        for _, c in ipairs(rawget(self, "__d").children) do if rawget(c, "__d").class == "Player" then out[#out + 1] = c end end
        return out
    end
    METHODS.GetPlayerByUserId = function(self, id)
        for _, p in ipairs(METHODS.GetPlayers(self)) do if rawget(p, "__d").props.UserId == id then return p end end
    end
    METHODS.GetPlayerFromCharacter = function(self, char)
        for _, p in ipairs(METHODS.GetPlayers(self)) do if rawget(p, "__d").props.Character == char then return p end end
    end
    METHODS.GetUserThumbnailAsync = function(_, id) return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(id) end
    METHODS.EquipTool = function(self, tool)
        local char = rawget(self, "__d").parent
        if char and isInstance(tool) then setParent(tool, char) end
    end
    METHODS.ChangeState = function(self, state) W.calls[#W.calls + 1] = {"ChangeState", state} end
    METHODS.GetState = function() return W.Enum.HumanoidStateType.Running end
    METHODS.Activate = function(self) fire(signalOf(self, "Activated")) ; W.calls[#W.calls + 1] = {"Activate", self} end
    METHODS.WorldToViewportPoint = projectToViewport
    METHODS.Raycast = function(self, origin, dir, params)
        W.rays = (W.rays or 0) + 1
        if W.raycast then return W.raycast(origin, dir, params) end
        return nil
    end
    METHODS.GetService = function(self, name)
        local s = findChild(self, name, false)
        if s then return s end
        if not classes[name] then throw("'" .. tostring(name) .. "' is not a valid Service name", 2) end
        s = makeRaw(name, name)
        W.initService(s)
        setParent(s, self)
        return s
    end
    METHODS.BindToRenderStep = function(self, name, prio, fn) W.renderSteps[name] = {prio = prio, fn = fn} end
    METHODS.UnbindFromRenderStep = function(self, name) W.renderSteps[name] = nil end
    METHODS.GetMouseLocation = function() return W.mouse or Vector2_new(640, 360) end
    METHODS.SetCore = function(self, name, tbl) W.coreNotes[#W.coreNotes + 1] = {name = name, data = tbl} end
    METHODS.GetGuiInset = function() return Vector2_new(0, 36), Vector2_new(0, 0) end
    METHODS.SendKeyEvent = function(self, pressed, key) W.vim[#W.vim + 1] = {"key", pressed, key} end
    METHODS.SendMouseButtonEvent = function(self, x, y, button, pressed) W.vim[#W.vim + 1] = {"mouse", x, y, button, pressed} end
    METHODS.SendMouseMoveEvent = function(self, x, y) W.vim[#W.vim + 1] = {"move", x, y} end
    METHODS.CaptureController = function() W.calls[#W.calls + 1] = {"CaptureController"} end
    METHODS.ClickButton2 = function() W.calls[#W.calls + 1] = {"ClickButton2"} end
    METHODS.TeleportToPlaceInstance = function(_, place, job) W.calls[#W.calls + 1] = {"TeleportToPlaceInstance", place, job} end
    METHODS.FireServer = function(self, ...)
        W.sent[#W.sent + 1] = {remote = self, method = "FireServer", args = table.pack(...)}
        if W.serverHandler then W.serverHandler(self, "FireServer", table.pack(...)) end
    end
    METHODS.InvokeServer = function(self, ...)
        W.sent[#W.sent + 1] = {remote = self, method = "InvokeServer", args = table.pack(...)}
        local h = W.remoteFunctions and W.remoteFunctions[self]
        if h then return h(...) end
        if W.serverHandler then return W.serverHandler(self, "InvokeServer", table.pack(...)) end
    end
    METHODS.JSONEncode = function(_, v) return W.jsonEncode(v) end
    METHODS.JSONDecode = function(_, s) return W.jsonDecode(s) end
    METHODS.GenerateGUID = function() return "GUID" end
    METHODS.Create = function(_, inst, info, props)
        if not isInstance(inst) then throw("TweenService:Create expects an Instance", 2) end
        for k, v in pairs(props) do
            local pt = propType(rawget(inst, "__d").class, k)
            if not pt then throw("Tween: " .. k .. " is not a property of " .. rawget(inst, "__d").class, 2) end
            W.checkValue(rawget(inst, "__d").class, k, pt, v, "tween")
        end
        local tween = {Completed = newSignal("Tween.Completed")}
        tween.Play = function() for k, v in pairs(props) do inst[k] = v end end
        tween.Cancel = function() end
        W.tweens = (W.tweens or 0) + 1
        return tween
    end

    -- which classes have which extra (non-Instance) methods: checked against the API dump for validity
    local function callMethod(self, name, ...)
        if W.hook and not W.inHookDispatch then
            W.namecallMethod = name
            return W.hook(self, ...)
        end
        return METHODS[name](self, ...)
    end
    W.callMethod = callMethod
    W.M = METHODS
    W.realCall = function(self, ...) return METHODS[W.namecallMethod](self, ...) end

    -------------------------------------------------------------------------------------------- property checks
    local PRIM = {string = "string", ContentId = "string", Content = "string", int = "number", float = "number", double = "number", int64 = "number", bool = "boolean"}
    function W.checkValue(class, key, expected, v, what)
        local kind = kindOf(v)
        local ok
        if PRIM[expected] then ok = kind == PRIM[expected]
        elseif expected == "Instance" then ok = v == nil or isInstance(v)
        elseif expected:sub(1, 5) == "Enum:" then ok = kind == "EnumItem" and v.EnumType == expected:sub(6)
        else ok = kind == expected end
        if not ok then
            throw(string.format("%s %s.%s expects %s but got %s (%s)", what or "assign", class, key, expected, kind, tostring(v)), 3)
        end
    end

    InstMT.__index = function(self, k)
        local d = rawget(self, "__d")
        if k == "ClassName" then return d.class end
        if k == "Name" then return d.name end
        if k == "Parent" then return d.parent end
        if k == "HttpGet" and d.class == "DataModel" then
            return function(_, url)
                W.httpLog = W.httpLog or {}; W.httpLog[#W.httpLog + 1] = url
                if W.http and W.http[url] then return W.http[url] end
                error("HTTP 404 " .. tostring(url))
            end
        end
        if METHODS[k] and validMember(d.class, "fns", k) then
            return function(s, ...)
                if s ~= self then throw("Expected ':' not '.' calling member function " .. k, 2) end
                return callMethod(s, k, ...)
            end
        end
        if validMember(d.class, "evs", k) then return signalOf(self, k) end
        if validMember(d.class, "fns", k) then
            return function(s, ...) W.calls[#W.calls + 1] = {k, s, ...}; return nil end        -- a real method the test world does not simulate
        end
        local pt = propType(d.class, k)
        if pt then
            if isA(d.class, "BasePart") and k == "Position" then return (d.props.CFrame or cframe(0, 0, 0)).Position end
            if isA(d.class, "BasePart") and k == "AssemblyLinearVelocity" and d.props.AssemblyLinearVelocity == nil then return Vector3_new(0, 0, 0) end
            if k == "Size" and d.props.Size == nil and isA(d.class, "BasePart") then return Vector3_new(2, 1, 1) end
            return defaultFor(self, d, k, pt)
        end
        local c = findChild(self, k, false)
        if c then return c end
        throw(tostring(k) .. " is not a valid member of " .. d.class .. " \"" .. fullName(self) .. "\"", 2)
    end

    InstMT.__newindex = function(self, k, v)
        local d = rawget(self, "__d")
        if k == "Parent" then setParent(self, v); return end
        if k == "Name" then
            if type(v) ~= "string" then throw("Name expects string", 2) end
            d.name = v; fire(d.signals["Changed:Name"]); return
        end
        if READONLY[k] then throw(tostring(k) .. " is read-only on " .. d.class, 2) end
        local pt = propType(d.class, k)
        if not pt then throw(tostring(k) .. " is not a valid property of " .. d.class .. " (assign)", 2) end
        W.checkValue(d.class, k, pt, v)
        if isA(d.class, "BasePart") and k == "Position" then
            local cf = d.props.CFrame or cframe(0, 0, 0)
            d.props.CFrame = cframe(v.X, v.Y, v.Z, cf.r)
        else
            d.props[k] = v
        end
        if k == "Character" and d.class == "Player" then
            fire(d.signals.CharacterAdded, v)
        end
        fire(d.signals["Changed:" .. k])
    end
    InstMT.__tostring = function(self) return rawget(self, "__d").name end

    -------------------------------------------------------------------------------------------- services
    function W.initService(s)
        local d = rawget(s, "__d")
        if d.class == "RunService" then
            d.signals.Heartbeat = newSignal("Heartbeat"); d.signals.Stepped = newSignal("Stepped"); d.signals.RenderStepped = newSignal("RenderStepped")
        end
    end

    W.pingMs = opts.ping or 60
    local game = makeRaw("DataModel", "Game")
    W.game = game
    rawget(game, "__d").props.PlaceId = opts.placeId or 142823291
    rawget(game, "__d").props.JobId = "job-1"
    W.workspace = makeRaw("Workspace", "Workspace")
    setParent(W.workspace, game)
    local cam = makeRaw("Camera", "Camera")
    rawget(cam, "__d").props.CFrame = lookAt(Vector3_new(0, 10, 0), Vector3_new(0, 10, -10))
    rawget(cam, "__d").props.ViewportSize = Vector2_new(1280, 720)
    setParent(cam, W.workspace)
    rawget(W.workspace, "__d").props.CurrentCamera = cam
    W.camera = cam
    W.players = game:GetService("Players")
    W.coreGui = game:GetService("CoreGui")
    W.replicated = game:GetService("ReplicatedStorage")
    W.runService = game:GetService("RunService")
    W.uis = game:GetService("UserInputService")
    -- every service the script asks for must exist as a class
    for _, n in ipairs({"StarterGui", "HttpService", "VirtualInputManager", "VirtualUser", "TeleportService", "GuiService", "TweenService", "Stats"}) do game:GetService(n) end
    do   -- Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        local stats = game:GetService("Stats")
        local net = makeRaw("StatsItem", "Network"); setParent(net, stats)
        local item = makeRaw("StatsItem", "ServerStatsItem"); setParent(item, net)
        local ping = makeRaw("StatsItem", "Data Ping"); setParent(ping, item)
        METHODS.GetValue = function() return W.pingMs end
    end

    -------------------------------------------------------------------------------------------- the script's environment
    local env = setmetatable({}, {__index = _G})
    W.env = env
    env.game, env.workspace = game, W.workspace
    env.Vector3 = {new = Vector3_new, zero = Vector3_new(0, 0, 0), one = Vector3_new(1, 1, 1)}
    env.Vector2 = {new = Vector2_new}
    env.CFrame = CFrame_lib
    env.Color3 = Color3_lib
    env.UDim = {new = udim}
    env.UDim2 = UDim2_lib
    env.Enum = W.Enum
    env.TweenInfo = {new = function() return plainType("TweenInfo") end}
    env.RaycastParams = {new = function() return setmetatable({FilterDescendantsInstances = {}, IgnoreWater = false}, {__type = "RaycastParams"}) end}
    env.Instance = {new = function(class, parent)
        if not classes[class] then throw("Unable to create an Instance of type \"" .. tostring(class) .. "\"", 2) end
        local inst = makeRaw(class, class)
        if parent then setParent(inst, parent) end
        return inst
    end}
    env.typeof = function(v) local k = kindOf(v); return k == "number" and "number" or k end
    env.task = {
        spawn = function(f, ...) W:startThread(f, ...) end,
        defer = function(f, ...) W:startThread(f, ...) end,
        wait = function(t)
            if not coroutine.isyieldable() then throw("task.wait called outside a thread in the test world", 2) end
            local start = W.now
            coroutine.yield(t or 0.03)
            return W.now - start
        end,
        delay = function(t, f, ...)
            local co = coroutine.create(f)
            W.threads[#W.threads + 1] = {co = co, wake = W.now + (t or 0), args = table.pack(...), seq = #W.threads}
        end,
    }
    env.warn = function(...) local t = {...}; for i, v in ipairs(t) do t[i] = tostring(v) end W.warns[#W.warns + 1] = table.concat(t, " ") end
    env.print = function(...) local t = {...}; for i, v in ipairs(t) do t[i] = tostring(v) end W.printed[#W.printed + 1] = table.concat(t, " ") end
    env.os = setmetatable({clock = function() return W.now end}, {__index = os})
    env.tick = function() return W.now end
    env.getgenv = function() return W.genv end
    env._G = W.genv

    -- executor functions (each can be switched off with opts.no = {hook = true, ...})
    local no = opts.no or {}
    if not no.hook then
        env.hookmetamethod = function(obj, method, fn)
            if method ~= "__namecall" then error("only __namecall is simulated") end
            W.hook = fn
            return function(self, ...) return W.realCall(self, ...) end                    -- "old": runs whatever method name is CURRENT
        end
        env.getnamecallmethod = function() return W.namecallMethod end
        if not no.setnamecall then env.setnamecallmethod = function(m) W.namecallMethod = m end end
        if not no.newcclosure then env.newcclosure = function(f) return f end end
        env.checkcaller = function() return false end
    end
    if not no.files then
        env.writefile = function(p, c) W.files[p] = c end
        env.readfile = function(p) if W.files[p] == nil then error("no such file " .. p) end return W.files[p] end
        env.isfile = function(p) return W.files[p] ~= nil end
        env.delfile = function(p) W.files[p] = nil end
    end
    if not no.clipboard then env.setclipboard = function(s) W.clipboard = s end end
    if not no.mouseRel then env.mousemoverel = function(dx, dy) W.moves = W.moves or {}; W.moves[#W.moves + 1] = {dx, dy} end end
    if not no.mouseClick then env.mouse1click = function() W.clicks = (W.clicks or 0) + 1 end end
    if not no.drawing then
        env.Drawing = {new = function(kind)
            local o = {Kind = kind}
            o.Remove = function() o.removed = true end
            W.drawings = W.drawings or {}; W.drawings[#W.drawings + 1] = o
            return o
        end}
    end
    if opts.gethui then env.gethui = function() return W.coreGui end end
    return W
end

------------------------------------------------------------------------------------------------ scheduler
function World:startThread(f, ...)
    local co = coroutine.create(f)
    self:resume({co = co, args = table.pack(...)})
end
function World:resume(th)
    local ok, res = coroutine.resume(th.co, table.unpack(th.args or {n = 0}, 1, (th.args or {n = 0}).n))
    th.args = nil
    if not ok then
        self.errors[#self.errors + 1] = "thread: " .. tostring(res)
    elseif coroutine.status(th.co) == "suspended" then
        th.wake = self.now + (type(res) == "number" and res or 0)
        self.threads[#self.threads + 1] = th
    end
end
function World:step(dt)
    self.now = self.now + dt
    local due = {}
    local keep = {}
    for _, th in ipairs(self.threads) do
        if th.wake <= self.now then due[#due + 1] = th else keep[#keep + 1] = th end
    end
    self.threads = keep
    table.sort(due, function(a, b) if a.wake ~= b.wake then return a.wake < b.wake end return (a.seq or 0) < (b.seq or 0) end)
    for _, th in ipairs(due) do self:resume(th) end
    local rs = rawget(self.runService, "__d").signals
    self.fire(rs.RenderStepped, dt)
    local order = {}
    for name, s in pairs(self.renderSteps) do order[#order + 1] = {name = name, prio = s.prio, fn = s.fn} end
    table.sort(order, function(a, b) return a.prio < b.prio end)
    for _, s in ipairs(order) do
        local ok, err = pcall(s.fn, dt)
        if not ok then self.errors[#self.errors + 1] = "render step " .. s.name .. ": " .. tostring(err) end
    end
    self.fire(rs.Stepped, self.now, dt)
    self.fire(rs.Heartbeat, dt)
end
function World:run(seconds, dt)
    dt = dt or (1 / 60)
    for _ = 1, math.max(1, floor(seconds / dt + 0.5)) do self:step(dt) end
end

------------------------------------------------------------------------------------------------ JSON (just enough for the config file)
function World:installJson()
    local function enc(v)
        local t = type(v)
        if t == "table" then
            if #v > 0 or next(v) == nil then
                local out = {}
                for i, x in ipairs(v) do out[i] = enc(x) end
                return "[" .. table.concat(out, ",") .. "]"
            end
            local keys = {}
            for k in pairs(v) do keys[#keys + 1] = k end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            local out = {}
            for _, k in ipairs(keys) do out[#out + 1] = enc(tostring(k)) .. ":" .. enc(v[k]) end
            return "{" .. table.concat(out, ",") .. "}"
        elseif t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
        elseif t == "number" then return string.format("%.14g", v)
        elseif t == "boolean" then return tostring(v) end
        return "null"
    end
    local function dec(s)
        local pos = 1
        local function ws() pos = s:find("[^ \n\r\t]", pos) or #s + 1 end
        local value
        local function str()
            local out = {}
            if s:sub(pos, pos) ~= '"' then error("bad json: string expected at " .. pos) end
            pos = pos + 1
            while true do
                local c = s:sub(pos, pos)
                if c == "" then error("bad json: unterminated string") end
                if c == '"' then pos = pos + 1; break end
                if c == "\\" then
                    local n = s:sub(pos + 1, pos + 1)
                    if n == "u" then out[#out + 1] = string.char(tonumber(s:sub(pos + 2, pos + 5), 16)); pos = pos + 6
                    else out[#out + 1] = n; pos = pos + 2 end
                else out[#out + 1] = c; pos = pos + 1 end
            end
            return table.concat(out)
        end
        function value()
            ws()
            local c = s:sub(pos, pos)
            if c == "{" then
                local t = {}; pos = pos + 1; ws()
                if s:sub(pos, pos) == "}" then pos = pos + 1; return t end
                while true do
                    ws(); local k = str(); ws()
                    if s:sub(pos, pos) ~= ":" then error("bad json: ':' expected at " .. pos) end
                    pos = pos + 1
                    t[k] = value(); ws()
                    local d = s:sub(pos, pos); pos = pos + 1
                    if d == "}" then break end
                    if d ~= "," then error("bad json: ',' or '}' expected at " .. pos) end
                end
                return t
            elseif c == "[" then
                local t = {}; pos = pos + 1; ws()
                if s:sub(pos, pos) == "]" then pos = pos + 1; return t end
                while true do
                    t[#t + 1] = value(); ws()
                    local d = s:sub(pos, pos); pos = pos + 1
                    if d == "]" then break end
                    if d ~= "," then error("bad json: ',' or ']' expected at " .. pos) end
                end
                return t
            elseif c == '"' then return str()
            elseif s:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
            elseif s:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
            elseif s:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil end
            local num = s:match("^-?[%d%.eE+-]+", pos)
            if not num then error("bad json at " .. pos) end
            pos = pos + #num
            return tonumber(num)
        end
        return value()
    end
    self.jsonEncode, self.jsonDecode = enc, dec
end

------------------------------------------------------------------------------------------------ fixtures
function World:make(class, name, props, parent)
    local inst = self.makeRaw(class, name)
    local d = rawget(inst, "__d")
    for k, v in pairs(props or {}) do d.props[k] = v end
    if parent then self.setParent(inst, parent) end
    return inst
end
function World:V3(x, y, z) return self.env.Vector3.new(x, y, z) end

-- a fresh character for a player (also used for respawns)
function World:newCharacter(plr, o)
    o = o or {}
    local V3n = self.env.Vector3.new
    local name = rawget(plr, "__d").name
    local pos = o.pos or {0, 3, 0}
    local char = self:make("Model", name, {}, nil)
    local vel = o.vel or {0, 0, 0}
    local function part(partName, offY)
        return self:make("Part", partName, {CFrame = self.env.CFrame.new(pos[1], pos[2] + (offY or 0), pos[3]), Size = V3n(2, 2, 1),
            AssemblyLinearVelocity = V3n(vel[1], vel[2], vel[3])}, char)
    end
    part("HumanoidRootPart", 0); part("Head", 1.5); part("Torso", 0.3)
    self:make("Humanoid", "Humanoid", {Health = o.health or 100, MaxHealth = 100}, char)
    rawget(plr, "__d").props.Character = char
    self.setParent(char, self.workspace)
    return char
end

-- a player with a character at pos (a table), optionally moving with vel
function World:addPlayer(name, o)
    o = o or {}
    local plr = self:make("Player", name, {UserId = o.userId or (100 + #self.M.GetChildren(self.players)), DisplayName = o.display or name}, nil)
    self:make("Backpack", "Backpack", {}, plr)
    self:make("PlayerGui", "PlayerGui", {}, plr)
    local char = self:newCharacter(plr, o)
    self.setParent(plr, self.players)
    return plr, char
end
function World:giveTool(plr, toolName, o)
    o = o or {}
    local tool = self:make("Tool", toolName, {}, nil)
    self:make("Part", "Handle", {CFrame = self.env.CFrame.new(0, 0, 0)}, tool)
    for _, r in ipairs(o.remotes or {}) do
        local parent = tool
        if r.folder then parent = self:make("Folder", r.folder, {}, tool) end
        self:make(r.class or "RemoteEvent", r.name, {}, parent)
    end
    local where = o.held and rawget(plr, "__d").props.Character or self.M.FindFirstChildOfClass(plr, "Backpack")
    self.setParent(tool, where)
    return tool
end
function World:killPlayer(plr)
    local char = rawget(plr, "__d").props.Character
    local hum = char and self.M.FindFirstChildOfClass(char, "Humanoid")
    if hum then rawget(hum, "__d").props.Health = 0 end
end
function World:movePlayer(plr, pos, vel)
    local char = rawget(plr, "__d").props.Character
    for _, c in ipairs(self.M.GetChildren(char)) do
        if self.M.IsA(c, "BasePart") then
            local d = rawget(c, "__d")
            local off = c.Name == "Head" and 1.5 or c.Name == "Torso" and 0.3 or 0
            d.props.CFrame = self.env.CFrame.new(pos[1], pos[2] + off, pos[3])
            if vel then d.props.AssemblyLinearVelocity = self.env.Vector3.new(vel[1], vel[2], vel[3]) end
        end
    end
end
function World:dropGun(pos, name)
    return self:make("Part", name or "GunDrop", {CFrame = self.env.CFrame.new(pos[1], pos[2], pos[3])}, self.workspace)
end
function World:setLocal(plr)
    rawget(self.players, "__d").props.LocalPlayer = plr
    self.localPlayer = plr
    local char = rawget(plr, "__d").props.Character
    local root = self.M.FindFirstChild(char, "HumanoidRootPart")
    local look = self.env.CFrame.lookAt(root.Position + self.env.Vector3.new(0, 2, 0), root.Position + self.env.Vector3.new(0, 2, -10))
    rawget(self.camera, "__d").props.CFrame = look
end
function World:setCamera(from, to)
    rawget(self.camera, "__d").props.CFrame = self.env.CFrame.lookAt(self:V3(from[1], from[2], from[3]), self:V3(to[1], to[2], to[3]))
end

------------------------------------------------------------------------------------------------ input + UI helpers
function World:input(kind, keyName, processed)
    local E = self.env.Enum
    local input
    if kind == "key" then input = {UserInputType = E.UserInputType.Keyboard, KeyCode = E.KeyCode[keyName], Position = self:V3(0, 0, 0)}
    else input = {UserInputType = E.UserInputType[keyName], KeyCode = E.KeyCode.Unknown, Position = self:V3(0, 0, 0)} end
    return input
end
function World:keyDown(name, processed)
    self.fire(rawget(self.uis, "__d").signals.InputBegan, self:input("key", name), processed or false)
end
function World:keyUp(name)
    self.fire(rawget(self.uis, "__d").signals.InputEnded, self:input("key", name), false)
end
function World:mouseDown(button, processed)
    self.fire(rawget(self.uis, "__d").signals.InputBegan, self:input("mouse", button or "MouseButton1"), processed or false)
end
function World:mouseUp(button)
    self.fire(rawget(self.uis, "__d").signals.InputEnded, self:input("mouse", button or "MouseButton1"), false)
end
function World:mouseMove(x, y)
    local E = self.env.Enum
    self.fire(rawget(self.uis, "__d").signals.InputChanged, {UserInputType = E.UserInputType.MouseMovement, Position = self:V3(x, y or 50, 0)})
end
function World:jumpRequest() self.fire(rawget(self.uis, "__d").signals.JumpRequest) end

function World:find(pred, root)
    for _, i in ipairs(self.M.GetDescendants(root or self.coreGui)) do if pred(i) then return i end end
end
function World:findAll(pred, root)
    local out = {}
    for _, i in ipairs(self.M.GetDescendants(root or self.coreGui)) do if pred(i) then out[#out + 1] = i end end
    return out
end
function World:label(text)
    return self:find(function(i) return (i.ClassName == "TextLabel" or i.ClassName == "TextButton") and i.Text == text end)
end
function World:click(btn)
    if not btn then error("click(nil): button not found", 2) end
    self.fire(rawget(btn, "__d").signals.MouseButton1Click)
end
-- the row Frame holding a title label
function World:row(title)
    local lbl = self:label(title)
    if not lbl then error("no row titled " .. title, 2) end
    return lbl.Parent
end
function World:rowButton(title)                                   -- the full-row TextButton overlay (toggle / button / dropdown header)
    local row = self:row(title)
    for _, c in ipairs(self.M.GetChildren(row)) do if c.ClassName == "TextButton" then return c end end
    error("row " .. title .. " has no button", 2)
end
function World:toggle(title) self:click(self:rowButton(title)) end
function World:tab(name)
    local b = self:find(function(i) return i.ClassName == "TextButton" and i.Name == name and i.Text:find(name, 1, true) end)
    if not b then error("no tab " .. name, 2) end
    self:click(b)
end
function World:slide(title, fraction)                             -- drag the slider of the row `title` to a 0..1 position
    local row = self:row(title)
    local track, hit
    for _, c in ipairs(self.M.GetChildren(row)) do
        if c.ClassName == "Frame" and c.Size.Y.Offset == 6 then track = c end
        if c.ClassName == "TextButton" then hit = c end
    end
    local d = rawget(track, "__d")
    d.props.AbsoluteSize = self.env.Vector2.new(200, 6)
    d.props.AbsolutePosition = self.env.Vector2.new(100, 50)
    local x = 100 + 200 * fraction
    local pos = self:V3(x, 50, 0)
    local E = self.env.Enum
    self.fire(rawget(hit, "__d").signals.InputBegan, {UserInputType = E.UserInputType.MouseButton1, Position = pos})
    self.fire(rawget(self.uis, "__d").signals.InputEnded, {UserInputType = E.UserInputType.MouseButton1, Position = pos})
end
function World:typeInto(box, text)
    rawget(box, "__d").props.Text = text
    self.fire(rawget(box, "__d").signals["Changed:Text"])
end
-- run the script (in a thread, like Roblox does); returns the errors it produced while loading
function World:load(source, chunkname)
    local compile = (loadstring and setfenv) and function(src, name, env)
        local fn, err = loadstring(src, name); if not fn then return nil, err end
        setfenv(fn, env); return fn
    end or function(src, name, env) return load(src, name, "t", env) end
    local fn, err = compile(source, chunkname or "=mm2_hub", self.env)
    if not fn then return false, "SYNTAX ERROR: " .. tostring(err) end
    self:startThread(fn)
    return true
end

World.kindOf = kindOf
MM2_WORLD = World
