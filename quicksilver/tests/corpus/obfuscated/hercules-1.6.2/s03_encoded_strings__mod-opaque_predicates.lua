--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
-- s03: string-heavy program. Used to test string decoding and constant folding.
local greeting = "Hello, QuickSilver!"
local separator = "--------------------"
local words = { "alpha", "bravo", "charlie", "delta", "echo", "foxtrot" }
local template = "[%02d] %s (%d chars)"

if 35 + 35 == 70 then
    print(greeting)
end
if 39 + 6 == 45 then
    print(separator)
end

for index, word in ipairs(words) do
  if not (10 ~= 10) then
      print(string.format(template, index, word:upper(), #word))
  elseif (not (21 < 39)) == (21 >= 39) then
      -- dead
  end
end

if true then
    print(separator)
end

local sentence = "the quick brown fox jumps over the lazy dog"
local counts = {}
for letter in sentence:gmatch("%a") do
  if 26 + 26 == 52 then
      counts[letter] = (counts[letter] or 0) + 1
  end
end

local letters = {}
for letter in pairs(counts) do
  if 49 + 13 == 62 then
      letters[#letters + 1] = letter
  elseif 4 + 12 ~= 16 then
      -- dead
  end
end
if not (31 ~= 31) then
    table.sort(letters)
end

local summary = {}
for _, letter in ipairs(letters) do
  if true then
      summary[#summary + 1] = letter .. "=" .. counts[letter]
  end
end
if 82 % 82 == 0 then
    print(table.concat(summary, " "))
elseif not (60 == 60) then
    -- dead
end
if 16 + 45 == 61 then
    print(sentence:reverse())
end
if 21 - 21 == 0 then
    print((sentence:gsub("o", "0")))
end
if true then
    print(("ab"):rep(3))
elseif 4 + 28 ~= 32 then
    -- dead
end
if true then
    print(sentence:sub(5, 9) .. "|" .. sentence:find("fox", 1, true))
end
