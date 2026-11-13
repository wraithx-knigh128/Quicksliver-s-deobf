-- Driver for adzwang/fusgato-v1 ("FusGato v1", MIT) inside run_isolated.py.
--
-- The tool is a Luvit program: its main.lua compiles with an external `luac`, requires Luvit's `fs`, and writes nomin.lua / output.lua. Here the
-- compile is this Lua's own string.dump (the same Lua 5.1 bytecode `luac` writes), `fs` is a stand-in that reads and writes in memory, and the
-- relative `require("./x/y.lua")` names Luvit accepts are answered from the virtual file set. obfuscator.lua itself is not modified: it is called
-- the way main.lua calls it, with the options main.lua gives it. The clock is fixed so that a build can be repeated.
local fixed = 1700000000 + (OPTIONS.seed or 1337)
os.time = function() return fixed end

-- Lua 5.1 has no bit library; this tool asks for `bit` (LuaJIT's). A plain-arithmetic 32-bit stand-in with the same functions, defined only when the
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
  bit = B
end

local store = {}
package.preload["fs"] = function()
  return {
    readFileSync = function(p) p = tostring(p):gsub("^%./", ""); local h = io.open(p, "rb"); if not h then error("ENOENT: " .. p) end local d = h:read("*a"); h:close(); return d end,
    writeFileSync = function(p, d) store[p] = d end,
    existsSync = function(p) p = tostring(p):gsub("^%./", ""); local h = io.open(p, "rb"); if h then h:close() return true end return false end,
  }
end

-- `ffi` is LuaJIT's; the tool only asks it whether the machine is little-endian
package.preload["ffi"] = function() return { abi = function(what) return what == "le" end } end

-- `json` is Luvit's; the tool uses json.decode on its own strings.json (an object of string lists)
package.preload["json"] = function()
  local function decode(text)
    local pos = 1
    local function ws() pos = text:find("[^ \t\r\n]", pos) or #text + 1 end
    local value
    local function str()
      local out, i = {}, pos + 1
      while true do
        local c = text:sub(i, i)
        if c == "" then error("unterminated string") end
        if c == '"' then pos = i + 1 return table.concat(out) end
        if c == "\\" then
          local n = text:sub(i + 1, i + 1)
          local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ["/"] = "/", ["\\"] = "\\", ['"'] = '"' }
          if n == "u" then out[#out + 1] = string.char(tonumber(text:sub(i + 2, i + 5), 16) % 256) i = i + 6
          else out[#out + 1] = map[n] or n i = i + 2 end
        else out[#out + 1] = c i = i + 1 end
      end
    end
    function value()
      ws()
      local c = text:sub(pos, pos)
      if c == '"' then return str() end
      if c == "{" then
        local t = {}
        pos = pos + 1 ws()
        if text:sub(pos, pos) == "}" then pos = pos + 1 return t end
        while true do
          ws() local k = str() ws()
          pos = pos + 1 -- the colon
          t[k] = value() ws()
          local d = text:sub(pos, pos) pos = pos + 1
          if d == "}" then return t end
        end
      end
      if c == "[" then
        local t = {}
        pos = pos + 1 ws()
        if text:sub(pos, pos) == "]" then pos = pos + 1 return t end
        while true do
          t[#t + 1] = value() ws()
          local d = text:sub(pos, pos) pos = pos + 1
          if d == "]" then return t end
        end
      end
      local lit = text:match("^[%w%.%+%-]+", pos)
      pos = pos + #lit
      if lit == "true" then return true elseif lit == "false" then return false elseif lit == "null" then return nil end
      return tonumber(lit)
    end
    return value()
  end
  return { decode = decode }
end

local plain_require = require
local cache = {}
local function dirname(path) return (path:match("^(.*)/[^/]*$")) or "" end
local function resolve(base, rel)
  local parts = {}
  for seg in ((base ~= "" and (base .. "/") or "") .. rel):gmatch("[^/]+") do
    if seg == ".." then parts[#parts] = nil elseif seg ~= "." then parts[#parts + 1] = seg end
  end
  return table.concat(parts, "/")
end
-- Luvit resolves "./x" and "../x" against the directory of the file that asks. The harness says where a chunk came from, but a `return require(...)`
-- is a tail call and its caller's frame is gone, so a name that does not resolve from the asking file is tried against the directory of every
-- module loaded so far (the first that holds the file wins).
local dirs = { [""] = true }
local function exists(path) local h = io.open(path, "rb") if h then h:close() return true end return false end
function require(name)
  if type(name) == "string" and (name:sub(1, 2) == "./" or name:sub(1, 3) == "../") then
    local src = debug.getinfo(2, "S").source or "@"
    local candidates = { resolve(dirname((src:gsub("^@", ""))), name) }
    for d in pairs(dirs) do candidates[#candidates + 1] = resolve(d, name) end
    local p
    for _, c in ipairs(candidates) do
      if cache[c] ~= nil then return cache[c] end
      if exists(c) or exists(c .. ".lua") or exists(c .. "/init.lua") then p = c break end
    end
    if not p then error("module '" .. name .. "' not found in the virtual file set", 2) end
    local file = p
    if not exists(p) then file = exists(p .. ".lua") and (p .. ".lua") or (p .. "/init.lua") end
    local fn, why = loadfile(file)
    if not fn then error(why, 2) end
    dirs[dirname(file)] = true
    cache[p] = true
    local v = fn(name, file)
    if v ~= nil then cache[p] = v end
    return cache[p]
  end
  return plain_require(name)
end

local fn, why = (loadstring or load)(INPUT, "=input")
if not fn then error("the input does not compile: " .. tostring(why)) end
-- obfuscator.lua takes the PATH of the compiled chunk (main.lua writes it to ./input/luac.out); the virtual file set holds what is written
local h = io.open("input/luac.out", "wb")
h:write(string.dump(fn))
h:close()

local obfuscator = require("./obfuscator.lua")
local opts = {
  compression = false, premium = false, loud = false, memes = "sigma",
  constant_encryption = OPTIONS.constants ~= false, platform_lock = 0,
}
return obfuscator("./input/luac.out", opts)
