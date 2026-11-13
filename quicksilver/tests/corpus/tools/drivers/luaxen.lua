-- Driver for luauminati/LuaXen (MIT) inside run_isolated.py: the call its own examples/obfuscator-example.lua makes.
--
-- IronBrikked is its virtual-machine obfuscator; ASTObfuscator is the optional second stage the example shows. Output is the token printer's text.
-- Nothing of the tool is modified; the example's package.path line is what lets `require("api")` find src/ in the virtual file set.
package.path = "src/?.lua;src/?/init.lua;" .. package.path
-- the tool reads its own templates by paths relative to src/ (it expects to be run from there): the same as having src/ as the working directory
local open = io.open
io.open = function(path, mode, ...)
  local h, why, code = open(path, mode, ...)
  if h == nil and (mode or "r"):find("^r") then
    local h2 = open("src/" .. tostring(path):gsub("^%./", ""), mode, ...)
    if h2 then return h2 end
  end
  return h, why, code
end
local luaAPI = require("api")
local mode = OPTIONS.mode or "ironbrikked"
local script = INPUT
local out
if mode == "ast" then
  out = luaAPI.Obfuscator.ASTObfuscator.ObfuscateScript(script)
elseif mode == "both" then
  out = luaAPI.Obfuscator.ASTObfuscator.ObfuscateScript(luaAPI.Obfuscator.IronBrikked.ObfuscateScript(script))
else
  out = luaAPI.Obfuscator.IronBrikked.ObfuscateScript(script)
end
if type(out) == "string" then return out end
return luaAPI.Printer.TokenPrinter.PrintScriptTokens(out)
