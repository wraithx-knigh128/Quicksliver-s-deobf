--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s03: string-heavy program. Used to test string decoding and constant folding.
local greeting = "Hello, QuickSilver!"
local separator = "--------------------"
local words = { "alpha", "bravo", "charlie", "delta", "echo", "foxtrot" }
local template = "[%02d] %s (%d chars)"

;(function() print(greeting) end)()
;(function() print(separator) end)()

for index, word in ipairs(words) do
  ;(function() print(string.format(template, index, word:upper(), #word)) end)()
end

;(function() print(separator) end)()

local sentence = "the quick brown fox jumps over the lazy dog"
local counts = {}
for letter in sentence:gmatch("%a") do
  ;(function() counts[letter] = (counts[letter] or 0) + 1 end)()
end

local letters = {}
for letter in pairs(counts) do
  ;(function() letters[#letters + 1] = letter end)()
end
;(function() table.sort(letters) end)()

local summary = {}
for _, letter in ipairs(letters) do
  ;(function() summary[#summary + 1] = letter .. "=" .. counts[letter] end)()
end
;(function() print(table.concat(summary, " ")) end)()
;(function() print(sentence:reverse()) end)()
;(function() print((sentence:gsub("o", "0"))) end)()
;(function() print(("ab"):rep(3)) end)()
;(function() print(sentence:sub(5, 9) .. "|" .. sentence:find("fox", 1, true)) end)()
