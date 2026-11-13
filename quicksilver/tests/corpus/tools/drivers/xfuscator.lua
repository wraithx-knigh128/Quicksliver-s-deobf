-- Driver for efrederickson/XFuscator (2013, "Version 2.0 b1", no licence stated) inside run_isolated.py.
--
-- XFuscator's own XFuscator.lua is a command line: it reads and writes files, and prints. The library underneath it is one call,
-- XFuscator.XFuscate(code, level, maxLevel, loadstring, fluff, comments, step2, uglify, encryptConstants, tamperDetection), which is what this
-- calls with the options the command line would have set. Nothing of the tool is modified. Its random numbers come from the clock, so the clock
-- is fixed to make a build repeatable.
local fixed = 1700000000 + (OPTIONS.seed or 1337)
os.time = function() return fixed end

-- Lua 5.1 has no bit library; XFuscator asks for `bit` (LuaJIT's). A plain-arithmetic 32-bit stand-in with the same functions, defined only when the
-- runtime has none: it computes what the library computes, so the tool's output does not depend on it.
if not bit and not bit32 then
  local M = 4294967296
  local function norm(x) x = x % M if x >= 2147483648 then x = x - M end return x end
  local function u(x) return x % M end
  local function bitwise(op, a, b)
    a, b = u(a), u(b)
    local r, p = 0, 1
    for _ = 1, 32 do
      local x, y = a % 2, b % 2
      if op(x, y) then r = r + p end
      a, b, p = (a - x) / 2, (b - y) / 2, p * 2
    end
    return norm(r)
  end
  local B = {}
  function B.band(a, b, ...) local r = bitwise(function(x, y) return x == 1 and y == 1 end, a, b) if ... then return B.band(r, ...) end return r end
  function B.bor(a, b, ...) local r = bitwise(function(x, y) return x == 1 or y == 1 end, a, b) if ... then return B.bor(r, ...) end return r end
  function B.bxor(a, b, ...) local r = bitwise(function(x, y) return x ~= y end, a, b) if ... then return B.bxor(r, ...) end return r end
  function B.bnot(a) return norm(M - 1 - u(a)) end
  function B.lshift(a, n) return norm(u(a) * 2 ^ (n % 32)) end
  function B.rshift(a, n) return norm(math.floor(u(a) / 2 ^ (n % 32))) end
  function B.arshift(a, n) a = norm(a) n = n % 32 return norm(math.floor(a / 2 ^ n)) end
  function B.rol(a, n) n = n % 32 a = u(a) return norm(a * 2 ^ n % M + math.floor(a / 2 ^ (32 - n))) end
  function B.ror(a, n) return B.rol(a, 32 - (n % 32)) end
  B.rrotate, B.lrotate, B.tobit, B.tohex = B.ror, B.rol, norm, function(a) return string.format("%08x", u(a)) end
  package.preload["bit"] = function() return B end
end
require("XFuscator.init")

local o = OPTIONS
local function opt(name, default) if o[name] == nil then return default end return o[name] end
local result, why = XFuscator.XFuscate(INPUT, opt("level", 1), opt("max", 1), opt("loadstring", true), opt("fluff", true), opt("comments", false),
  opt("step2", true), opt("uglify", false), opt("encrypt", false), opt("tamper", true))
if not result then error("XFuscator failed: " .. tostring(why)) end
return result
