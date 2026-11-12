--[Obfuscated by Hercules v1.6 | github.com/zeusssz/hercules-obfuscator]
local xHvKEpMRBuM, jgqTeQsBpB, ArfoPVZM, cDGcFkDJOk, AemCUlrTcKk, IyWVnEfbt, ramgNjMn
xHvKEpMRBuM = ipairs; jgqTeQsBpB = pairs; ArfoPVZM = print; cDGcFkDJOk = sort; AemCUlrTcKk = string.format; IyWVnEfbt = table.concat; ramgNjMn = table.sort;
-- s03: string-heavy program. Used to test string decoding and constant folding.
local IIMfMjZurC = "Hello, QuickSilver!"
local zxWmdlERE = "--------------------"
local yinXFpSjudBm = { "alpha", "bravo", "charlie", "delta", "echo", "foxtrot" }
local JxEmbDXKy = "[%02d] %s (%d chars)"

ArfoPVZM(IIMfMjZurC)
ArfoPVZM(zxWmdlERE)

for index, word in xHvKEpMRBuM(yinXFpSjudBm) do
  ArfoPVZM(AemCUlrTcKk(JxEmbDXKy, index, word:upper(), #word))
end

ArfoPVZM(zxWmdlERE)

local ycbhbXasaqVk = "the quick brown fox jumps over the lazy dog"
local gIOyIDrVQe = {}
for letter in ycbhbXasaqVk:gmatch("%a") do
  gIOyIDrVQe[letter] = (gIOyIDrVQe[letter] or 0) + 1
end

local wPdZwiguCp = {}
for letter in jgqTeQsBpB(gIOyIDrVQe) do
  wPdZwiguCp[#wPdZwiguCp + 1] = letter
end
table.cDGcFkDJOk(wPdZwiguCp)

local kweuqlPhf = {}
for _, letter in xHvKEpMRBuM(wPdZwiguCp) do
  kweuqlPhf[#kweuqlPhf + 1] = letter .. "=" .. gIOyIDrVQe[letter]
end
ArfoPVZM(IyWVnEfbt(kweuqlPhf, " "))
ArfoPVZM(ycbhbXasaqVk:reverse())
ArfoPVZM((ycbhbXasaqVk:gsub("o", "0")))
ArfoPVZM(("ab"):rep(3))
ArfoPVZM(ycbhbXasaqVk:sub(5, 9) .. "|" .. ycbhbXasaqVk:find("fox", 1, true))
