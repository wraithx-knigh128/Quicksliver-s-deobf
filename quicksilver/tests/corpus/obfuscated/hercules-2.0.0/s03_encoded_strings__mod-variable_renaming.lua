--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local xHvKEpMRBuM,jgqTeQsBpB,ArfoPVZM,cDGcFkDJOk,AemCUlrTcKk,IyWVnEfbt
xHvKEpMRBuM=ipairs;jgqTeQsBpB=pairs;ArfoPVZM=print;cDGcFkDJOk=string.format;AemCUlrTcKk=table.concat;IyWVnEfbt=table.sort;
-- s03: string-heavy program. Used to test string decoding and constant folding.
local kweuqlPhf = "Hello, QuickSilver!"
local wPdZwiguCp = "--------------------"
local yinXFpSjudBm = { "alpha", "bravo", "charlie", "delta", "echo", "foxtrot" }
local IIMfMjZurC = "[%02d] %s (%d chars)"

ArfoPVZM(kweuqlPhf)
ArfoPVZM(wPdZwiguCp)

for index, word in xHvKEpMRBuM(yinXFpSjudBm) do
  ArfoPVZM(string.format(IIMfMjZurC, index, word:upper(), #word))
end

ArfoPVZM(wPdZwiguCp)

local gIOyIDrVQe = "the quick brown fox jumps over the lazy dog"
local zxWmdlERE = {}
for letter in gIOyIDrVQe:gmatch("%a") do
  zxWmdlERE[letter] = (zxWmdlERE[letter] or 0) + 1
end

local JxEmbDXKy = {}
for letter in jgqTeQsBpB(zxWmdlERE) do
  JxEmbDXKy[#JxEmbDXKy + 1] = letter
end
table.sort(JxEmbDXKy)

local ycbhbXasaqVk = {}
for _, letter in xHvKEpMRBuM(JxEmbDXKy) do
  ycbhbXasaqVk[#ycbhbXasaqVk + 1] = letter .. "=" .. zxWmdlERE[letter]
end
ArfoPVZM(table.concat(ycbhbXasaqVk, " "))
ArfoPVZM(gIOyIDrVQe:reverse())
ArfoPVZM((gIOyIDrVQe:gsub("o", "0")))
ArfoPVZM(("ab"):rep(3))
ArfoPVZM(gIOyIDrVQe:sub(5, 9) .. "|" .. gIOyIDrVQe:find("fox", 1, true))
