-- Driver for CloudHub111/Simple-Lua-Obfuscator ("Roblox Script", no licence) inside run_isolated.py.
--
-- The script is a template: it expects a global called `script` holding the program's source text and prints the protected program.
-- The file is served to the isolated state byte for byte as tool.lua; printing is captured by the harness. Nothing is modified.
script = INPUT
dofile("tool.lua")
local text = table.concat(QS_STDOUT)
return (text:gsub("\n$", ""))
