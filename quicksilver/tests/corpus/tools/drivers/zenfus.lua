-- Driver for Zenfus (https://github.com/Zaenalos/Zenfus, MIT) inside run_isolated.py.
--
-- Zenfus's own cli.lua compiles with an external `luac -s`, writes temp files and seeds from /dev/urandom. None of that is available (or wanted)
-- here, so this does what the CLI does in memory: compile with this Lua's own string.dump (stripped, like `luac -s`), then call the same three
-- stages the CLI calls: Deserializer, Obfuscator, Generator. Nothing of Zenfus is modified. The seed is fixed so the build can be reproduced.
local seed = OPTIONS.seed or 1337
math.randomseed(seed)

local Deserializer = require("Lua54.BYTECODE.TOOLS.Deserializer")
local Obfuscator   = require("Lua54.OBFUSCATOR.Obfuscator")
local Generator    = require("Lua54.VM.Generator")

local fn, why = load(INPUT, "=input", "t")
if not fn then error("the input does not compile: " .. tostring(why)) end
local contents = string.dump(fn, true)

local chunk = Deserializer:deserialize(contents)
Obfuscator(chunk)
local _, vm = Generator(chunk)
return vm
