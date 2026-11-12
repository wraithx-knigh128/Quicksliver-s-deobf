--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
local function ccgxfg(xjturx) local _ = 90 end if true then local _ = 49 end if true then local _ = 96 end if true then local _ = 65 end local function aqpkkg(vciyyu) local _ = 99 end local wiguvp = 7 if true then local _ = 23 end local xbvepg = 56 local ugkujg = 17 if false then local _ = 52 end local function cacyku(vydikd) local _ = 91 end local function jcyqpn(fbtvyr) local _ = 1 end -- s03: string-heavy program. Used to test string decoding and constant folding.
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
 if true then local _ = 70 end while false do local _ = 21 break end if true then local _ = 49 end local function nzkrxo(gbhxwx) local _ = 7 end local function vmmmho(ymifac) local _ = 41 end local function vguexs(cemxmo) local _ = 97 end local function rmixqr(miwdih) local _ = 40 end local function nswtbd(sxsduv) local _ = 41 end local kfriyu = 26 if false then local _ = 29 end local ykbkic = 99 local function gyrmgx(prgpmi) local _ = 67 end local function vxxxwb(rbwjkr) local _ = 88 end if true then local _ = 44 end