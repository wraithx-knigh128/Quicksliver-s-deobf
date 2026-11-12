--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s03: string-heavy program. Used to test string decoding and constant folding.
local greeting = "Hello, QuickSilver!"
local separator = "--------------------"
local words = { "alpha", "bravo", "charlie", "delta", "echo", "foxtrot" }
local template = "[%02d] %s (%d chars)"

do (function() print(greeting) end)() end
do (function() print(separator) end)() end

for index, word in ipairs(words) do
  do (function() print(string.format(template, index, word:upper(), #word)) end)() end
end

do (function() print(separator) end)() end

local sentence = "the quick brown fox jumps over the lazy dog"
local counts = {}
for letter in sentence:gmatch("%a") do
  do (function() counts[letter] = (counts[letter] or 0) + 1 end)() end
end

local letters = {}
for letter in pairs(counts) do
  do (function() letters[#letters + 1] = letter end)() end
end
do (function() table.sort(letters) end)() end

local summary = {}
for _, letter in ipairs(letters) do
  do (function() summary[#summary + 1] = letter .. "=" .. counts[letter] end)() end
end
do (function() print(table.concat(summary, " ")) end)() end
do (function() print(sentence:reverse()) end)() end
do (function() print((sentence:gsub("o", "0"))) end)() end
do (function() print(("ab"):rep(3)) end)() end
do (function() print(sentence:sub(5, 9) .. "|" .. sentence:find("fox", 1, true)) end)() end
