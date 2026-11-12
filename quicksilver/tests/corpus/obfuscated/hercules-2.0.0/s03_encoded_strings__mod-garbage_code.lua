--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
if false then local _ = 99 end
local function luyinr(pmjuud) local _ = 28 end
local yyucrp = 5
if false then local _ = 23 end
local function xbvepg(vxlugk) local _ = 10 end
local nekspf = 86
local rfojpt = 24
if true then local _ = 30 end
local cykuvy = 36
local kdemol = 18
if true then local _ = 37 end
if true then local _ = 35 end
-- s03: string-heavy program. Used to test string decoding and constant folding.
local greeting = "Hello, QuickSilver!"
local separator = "--------------------"
local words = { "alpha", "bravo", "charlie", "delta", "echo", "foxtrot" }
local template = "[%02d] %s (%d chars)"

print(greeting)
print(separator)

for index, word in ipairs(words) do
  print(string.format(template, index, word:upper(), #word))
end

print(separator)

local sentence = "the quick brown fox jumps over the lazy dog"
local counts = {}
for letter in sentence:gmatch("%a") do
  counts[letter] = (counts[letter] or 0) + 1
end

local letters = {}
for letter in pairs(counts) do
  letters[#letters + 1] = letter
end
table.sort(letters)

local summary = {}
for _, letter in ipairs(letters) do
  summary[#summary + 1] = letter .. "=" .. counts[letter]
end
print(table.concat(summary, " "))
print(sentence:reverse())
print((sentence:gsub("o", "0")))
print(("ab"):rep(3))
print(sentence:sub(5, 9) .. "|" .. sentence:find("fox", 1, true))

local qpnfbt = 22
local ramghj = 39
local rujpqn = 58
if false then local _ = 50 end
local mifaci = 43
while false do local _ = 35 break end
local vgcrmi = 18
local function ihhcns(wtbdsx) local _ = 4 end
while false do local _ = 41 break end
while false do local _ = 35 break end
local function kfzlkf(riyuzg) local _ = 26 end
while false do local _ = 56 break end