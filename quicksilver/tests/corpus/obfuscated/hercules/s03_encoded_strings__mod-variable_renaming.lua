--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local xHvKEpMRBuM,jgqTeQsBpB,ArfoPVZM,cDGcFkDJOk,AemCUlrTcKk,IyWVnEfbt
xHvKEpMRBuM=ipairs;jgqTeQsBpB=pairs;ArfoPVZM=print;cDGcFkDJOk=string.format;AemCUlrTcKk=table.concat;IyWVnEfbt=table.sort;
-- s03: string-heavy program. Used to test string decoding and constant folding.
local JxEmbDXKy = "Hello, QuickSilver!"
local ycbhbXasaqVk = "--------------------"
local kweuqlPhf = { "alpha", "bravo", "charlie", "delta", "echo", "foxtrot" }
local gIOyIDrVQe = "[%02d] %s (%d chars)"

ArfoPVZM(JxEmbDXKy)
ArfoPVZM(ycbhbXasaqVk)

for index, word in xHvKEpMRBuM(kweuqlPhf) do
  ArfoPVZM(string.format(gIOyIDrVQe, index, word:upper(), #word))
end

ArfoPVZM(ycbhbXasaqVk)

local yinXFpSjudBm = "the quick brown fox jumps over the lazy dog"
local wPdZwiguCp = {}
for letter in yinXFpSjudBm:gmatch("%a") do
  wPdZwiguCp[letter] = (wPdZwiguCp[letter] or 0) + 1
end

local zxWmdlERE = {}
for letter in jgqTeQsBpB(wPdZwiguCp) do
  zxWmdlERE[#zxWmdlERE + 1] = letter
end
table.sort(zxWmdlERE)

local IIMfMjZurC = {}
for _, letter in xHvKEpMRBuM(zxWmdlERE) do
  IIMfMjZurC[#IIMfMjZurC + 1] = letter .. "=" .. wPdZwiguCp[letter]
end
ArfoPVZM(table.concat(IIMfMjZurC, " "))
ArfoPVZM(yinXFpSjudBm:reverse())
ArfoPVZM((yinXFpSjudBm:gsub("o", "0")))
ArfoPVZM(("ab"):rep(3))
ArfoPVZM(yinXFpSjudBm:sub(5, 9) .. "|" .. yinXFpSjudBm:find("fox", 1, true))
