--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local function zxWmdlERE(gIOyIDrVQe)
    return (gIOyIDrVQe >= 48 and gIOyIDrVQe <= 57) or (gIOyIDrVQe >= 65 and gIOyIDrVQe <= 90) or (gIOyIDrVQe >= 97 and gIOyIDrVQe <= 122)
end

local function IIMfMjZurC(JxEmbDXKy, ycbhbXasaqVk)
    local yinXFpSjudBm = {}
    for i = 1, #JxEmbDXKy do
        local gIOyIDrVQe = JxEmbDXKy:byte(i)
        if zxWmdlERE(gIOyIDrVQe) then
            local wPdZwiguCp            if gIOyIDrVQe >= 48 and gIOyIDrVQe <= 57 then
                wPdZwiguCp = ((gIOyIDrVQe - 48 - ycbhbXasaqVk + 10) % 10) + 48
            elseif gIOyIDrVQe >= 65 and gIOyIDrVQe <= 90 then
                wPdZwiguCp = ((gIOyIDrVQe - 65 - ycbhbXasaqVk + 26) % 26) + 65
            elseif gIOyIDrVQe >= 97 and gIOyIDrVQe <= 122 then
                wPdZwiguCp = ((gIOyIDrVQe - 97 - ycbhbXasaqVk + 26) % 26) + 97
            end
            table.insert(yinXFpSjudBm, string.char(wPdZwiguCp))
        else
            table.insert(yinXFpSjudBm, string.char(gIOyIDrVQe))
        end
    end
    return table.concat(yinXFpSjudBm)
end

-- s03: string-heavy program. Used to test string decoding and constant folding.
local greeting = IIMfMjZurC("Fcjjm, OsgaiQgjtcp!", 24)
local separator = IIMfMjZurC("--------------------", 1)
local words = { IIMfMjZurC("whldw", 22), IIMfMjZurC("zpytm", 24), IIMfMjZurC("xcvmgdz", 21), IIMfMjZurC("zahpw", 22), IIMfMjZurC("wuzg", 18), IIMfMjZurC("dmvrpmr", 24) }
local template = IIMfMjZurC("[%57c] %r (%c bgzqr)", 25)

print(greeting)
print(separator)

for index, word in ipairs(words) do
  print(string.format(template, index, word:upper(), #word))
end

print(separator)

local sentence = IIMfMjZurC("sgd pthbj aqnvm enw itlor nudq sgd kzyx cnf", 25)
local counts = {}
for letter in sentence:gmatch(IIMfMjZurC("%r", 17)) do
  counts[letter] = (counts[letter] or 0) + 1
end

local letters = {}
for letter in pairs(counts) do
  letters[#letters + 1] = letter
end
table.sort(letters)

local summary = {}
for _, letter in ipairs(letters) do
  summary[#summary + 1] = letter .. IIMfMjZurC("=", 1) .. counts[letter]
end
print(table.concat(summary, IIMfMjZurC(" ", 1)))
print(sentence:reverse())
print((sentence:gsub(IIMfMjZurC("i", 20), IIMfMjZurC("1", 1))))
print((IIMfMjZurC("za", 25)):rep(3))
print(sentence:sub(5, 9) .. IIMfMjZurC("|", 1) .. sentence:find(IIMfMjZurC("ajs", 21), 1, true))
