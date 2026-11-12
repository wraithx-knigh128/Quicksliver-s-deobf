--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local xHvKEpMRBuM,jgqTeQsBpB,ArfoPVZM,cDGcFkDJOk,AemCUlrTcKk,IyWVnEfbt
xHvKEpMRBuM=ipairs;jgqTeQsBpB=pairs;ArfoPVZM=print;cDGcFkDJOk=string.format;AemCUlrTcKk=table.concat;IyWVnEfbt=table.sort
-- s03: string-heavy program. Used to test string decoding and constant folding.
local wPdZwiguCp = "Hello, QuickSilver!"
local yinXFpSjudBm = "--------------------"
local zxWmdlERE = { "alpha", "bravo", "charlie", "delta", "echo", "foxtrot" }
local IIMfMjZurC = "[%02d] %s (%d chars)"

ArfoPVZM(wPdZwiguCp)
ArfoPVZM(yinXFpSjudBm)

for index, word in xHvKEpMRBuM(zxWmdlERE) do
  ArfoPVZM(cDGcFkDJOk(IIMfMjZurC, index, word:upper(), #word))
end

ArfoPVZM(yinXFpSjudBm)

local kweuqlPhf = "the quick brown fox jumps over the lazy dog"
local gIOyIDrVQe = {}
for letter in kweuqlPhf:gmatch("%a") do
  gIOyIDrVQe[letter] = (gIOyIDrVQe[letter] or 0) + 1
end

local ycbhbXasaqVk = {}
for letter in jgqTeQsBpB(gIOyIDrVQe) do
  ycbhbXasaqVk[#ycbhbXasaqVk + 1] = letter
end
IyWVnEfbt(ycbhbXasaqVk)

local JxEmbDXKy = {}
for _, letter in xHvKEpMRBuM(ycbhbXasaqVk) do
  JxEmbDXKy[#JxEmbDXKy + 1] = letter .. "=" .. gIOyIDrVQe[letter]
end
ArfoPVZM(AemCUlrTcKk(JxEmbDXKy, " "))
ArfoPVZM(kweuqlPhf:reverse())
ArfoPVZM((kweuqlPhf:gsub("o", "0")))
ArfoPVZM(("ab"):rep(3))
ArfoPVZM(kweuqlPhf:sub(5, 9) .. "|" .. kweuqlPhf:find("fox", 1, true))
