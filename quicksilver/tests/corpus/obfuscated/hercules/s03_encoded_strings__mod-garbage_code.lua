--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local ccgxfg = 10
if false then local _ = 18 end
local function xzzxqm(wdlluy) local _ = 73 end
local function breyuy(cbhbrv) local _ = 65 end
local aqpkkg = 99
while false do local _ = 25 break end
local ucrpke = 27
if true then local _ = 23 end
local function vpgwxz(kweuql) local _ = 42 end
local function hfvxbv(epgvxl) local _ = 28 end
local function gkujgq(nekspf) local _ = 86 end
local uvydik = 68
local emolrn = 3
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

local function ghjgnb(jszfqt) local _ = 40 end
while false do local _ = 21 break end
local function mhoymi(facipk) local _ = 86 end
local function exscem(xmoaiv) local _ = 71 end
local rmixqr = 13
if true then local _ = 31 end
if false then local _ = 72 end
local nswtbd = 51
local xsduvi = 13
local cbxqna = 94
local function kjdtkf(zlkfri) local _ = 85 end
local cgyrmg = 24
local function prgpmi(cvcvxx) local _ = 56 end