-- Driver for kosuke14/RBXLuaObfuscator (no licence) inside run_isolated.py.
--
-- obfuscator.lua is a module that returns function(Script, customVarName, comment); the file is served to the isolated state byte for byte.
-- It draws identifiers with math.random, which the harness seeds before this runs.
local obfuscate = dofile("obfuscator.lua")
return obfuscate(INPUT, OPTIONS.name or "qs", OPTIONS.comment or "obfuscated")
