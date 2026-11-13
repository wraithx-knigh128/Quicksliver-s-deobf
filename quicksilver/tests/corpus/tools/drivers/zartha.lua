-- Driver for TimOdemchuk/Zartha-Obfuscator (MIT, Lua 5.1) inside run_isolated.py.
--
-- Zartha's Main.lua is a command line and its Pipeline.lua shells out to `luac` and rewrites the input file in place. This does what Pipeline.lua
-- does in memory, in the same order: the AddToInput template in front of the program (and AntiTamper when asked), compile (this Lua's own
-- string.dump, which is the Lua 5.1 bytecode `luac` writes), BytecodeParser, TreeGenerator, the EnvLog template, optional luasrcdiet. The helper
-- globals Main.lua defines (readFile, display, Random, table.find and a bit32 for Lua 5.1) are defined here with the same meaning. The settings are
-- the flags Main.lua turns into settings. Nothing of Zartha is modified. The clock is fixed so that a build can be repeated.
local fixed = 1700000000 + (OPTIONS.seed or 1337)
os.time = function() return fixed end
math.randomseed(fixed)

_G.readFile = function(file) local h = io.open(file, "rb") if not h then error("cannot read " .. tostring(file)) end local d = h:read("*a") h:close() return d end
_G.display = function() end
_G.Random = function(a, b) return math.random(a, b) end
_G.table.find = function(t, value) for i, v in ipairs(t) do if v == value then return i end end return nil end
if not bit32 then
  local M = 4294967296
  local function bitwise(op, a, b)
    a, b = a % M, b % M
    local r, p = 0, 1
    for _ = 1, 32 do
      local x, y = a % 2, b % 2
      if op(x, y) then r = r + p end
      a, b, p = (a - x) / 2, (b - y) / 2, p * 2
    end
    return r
  end
  local function fold(op, ...)
    local args = { ... }
    local r = args[1] or 0
    for i = 2, #args do r = bitwise(op, r, args[i]) end
    return r
  end
  _G.bit32 = {
    bxor = function(...) return fold(function(x, y) return x ~= y end, ...) end,
    band = function(...) return fold(function(x, y) return x == 1 and y == 1 end, ...) end,
    bor = function(...) return fold(function(x, y) return x == 1 or y == 1 end, ...) end,
    bnot = function(x) return M - 1 - (x % M) end,
    lshift = function(x, n) if n < 0 or n >= 32 then return 0 end return ((x % M) * 2 ^ n) % M end,
    rshift = function(x, n) if n < 0 or n >= 32 then return 0 end return math.floor((x % M) / 2 ^ n) end,
  }
end

local o = OPTIONS
local settings = require("Input.Settings")
settings.ConstantProtection = o.constants and true or false
settings.Minify = o.minify and true or false
settings.AntiTamper = o.antitamper and true or false
settings.EncryptStrings = o.encryptstrings and true or false
settings.ControlFlowFlattening = o.flatten and true or false

local parser = require("Bytecode.BytecodeParser")
local treeGenerator = require("Vm.TreeGenerator")
local antiEnvLogger = require("Vm.Resources.Templates.EnvLogDetection")
local antitamper = require("Vm.Resources.Templates.AntiTamper")
local luasrcdiet = require("luasrcdiet.init")

local source = _G.readFile("Vm/Resources/Templates/AddToInput.lua") .. "\n" .. INPUT
if settings.AntiTamper then source = antitamper .. " \n " .. source end
local fn, why = (loadstring or load)(source, "=input")
if not fn then error("the input does not compile: " .. tostring(why)) end
local bytecode = string.dump(fn)

local tree = treeGenerator(parser(bytecode))
tree = tree:gsub(":INSERTENVLOG:", antiEnvLogger)
if settings.Minify then tree = luasrcdiet.optimize(luasrcdiet.MAXIMUM_OPTS, tree) end
return tree
