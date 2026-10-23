--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s03: string-heavy program. Used to test string decoding and constant folding.
local greeting = "Hello, QuickSilver!"
local separator = "--------------------"
local words = { "alpha", "bravo", "charlie", "delta", "echo", "foxtrot" }
local template = "[%02d] %s (%d chars)"

if 35 + 35 == 70 then
    print(greeting)
    print(separator)
end

for index, word in ipairs(words) do
  print(string.format(template, index, word:upper(), #word))
end

if 39 + 6 == 45 then
    print(separator)
end

local sentence = "the quick brown fox jumps over the lazy dog"
local counts = {}
for letter in sentence:gmatch("%a") do
  counts[letter] = (counts[letter] or 0) + 1
end

local letters = {}
for letter in pairs(counts) do
  letters[#letters + 1] = letter
end
if not (10 ~= 10) then
    table.sort(letters)
elseif (not (21 < 39)) == (21 >= 39) then
    -- dead
end

local summary = {}
for _, letter in ipairs(letters) do
  summary[#summary + 1] = letter .. "=" .. counts[letter]
end
if true then
    print(table.concat(summary, " "))
    print(sentence:reverse())
end
if 26 + 26 == 52 then
    print((sentence:gsub("o", "0")))
    print(("ab"):rep(3))
end
if 49 + 13 == 62 then
    print(sentence:sub(5, 9) .. "|" .. sentence:find("fox", 1, true))
elseif 4 + 12 ~= 16 then
    -- dead
end
