--[[
    mini_executor.lua - a tiny local script runner that stands in for Roblox/an executor
    so scripts can be tested outside the engine.

    Executor.new() gives you:
      :run(source, chunkName)   run Lua source inside a sandboxed env (no os/io/debug)
      :require(path)            load a file as a module inside the same sandbox
      .clock                    virtual time (task.wait advances it, nothing really sleeps)
      .keys                     recorded VirtualInputManager:SendKeyEvent calls
      .log                      captured print() output
    It mocks only what the scripts here need: task, os.clock, game:GetService,
    Enum.KeyCode, VirtualInputManager.
]]

local Executor = {}
Executor.__index = Executor

local function readFile(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("a")
    f:close()
    return s
end

function Executor.new(root)
    local self = setmetatable({clock = 0, keys = {}, log = {}, root = root or ".", loaded = {}}, Executor)

    local keyCode = setmetatable({}, {__index = function(_, k) return "KeyCode." .. k end})
    local vim = {
        SendKeyEvent = function(_, down, key, _, _)
            self.keys[#self.keys + 1] = {down = down, key = key, t = self.clock}
        end,
    }
    local services = {VirtualInputManager = vim}

    self.env = {
        pairs = pairs, ipairs = ipairs, next = next, type = type, tostring = tostring, tonumber = tonumber,
        select = select, assert = assert, error = error, pcall = pcall, setmetatable = setmetatable,
        getmetatable = getmetatable, rawget = rawget, rawset = rawset, unpack = table.unpack,
        math = math, string = string, table = table,
        os = {clock = function() return self.clock end, time = function() return math.floor(self.clock) end},
        print = function(...)
            local t = {}
            for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
            self.log[#self.log + 1] = table.concat(t, "\t")
        end,
        task = {
            wait  = function(s) s = s or 0.03; self.clock = self.clock + s; return s end,
            spawn = function(fn, ...) return fn(...) end,
        },
        game = {GetService = function(_, name) return services[name] end},
        Enum = {KeyCode = keyCode},
    }
    self.env._G = self.env
    self.env.require = function(path) return self:require(path) end
    return self
end

function Executor:run(source, chunkName)
    local fn, err = load(source, chunkName or "=script", "t", self.env)
    if not fn then return false, err end
    return pcall(fn)
end

function Executor:require(path)
    if self.loaded[path] ~= nil then return self.loaded[path] end
    local ok, res = self:run(readFile(self.root .. "/" .. path), "@" .. path)
    if not ok then error(res, 0) end
    self.loaded[path] = res
    return res
end

return Executor
