--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
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

local function zxWmdlERE(gIOyIDrVQe)
    return (gIOyIDrVQe >= 48 and gIOyIDrVQe <= 57) or (gIOyIDrVQe >= 65 and gIOyIDrVQe <= 90) or (gIOyIDrVQe >= 97 and gIOyIDrVQe <= 122)
end

-- s03: string-heavy program. Used to test string decoding and constant folding.
local greeting = IIMfMjZurC("Ebiil, NrfzhPfisbo!", 23)
local separator = IIMfMjZurC("--------------------", 8)
local words = { IIMfMjZurC("fqumf", 5), IIMfMjZurC("sirmf", 17), IIMfMjZurC("kpiztqm", 8), IIMfMjZurC("zahpw", 22), IIMfMjZurC("gejq", 2), IIMfMjZurC("ktcywty", 5) }
local template = IIMfMjZurC("[%24z] %o (%z ydwno)", 22)

print(greeting)
print(separator)

for index, word in ipairs(words) do
  print(string.format(template, index, word:upper(), #word))
end

print(separator)

local sentence = IIMfMjZurC("ftq cguow ndaiz raj vgybe ahqd ftq xmlk pas", 12)
local counts = {}
for letter in sentence:gmatch(IIMfMjZurC("%h", 7)) do
  counts[letter] = (counts[letter] or 0) + 1
end

local letters = {}
for letter in pairs(counts) do
  letters[#letters + 1] = letter
end
table.sort(letters)

local summary = {}
for _, letter in ipairs(letters) do
  summary[#summary + 1] = letter .. IIMfMjZurC("=", 5) .. counts[letter]
end
print(table.concat(summary, IIMfMjZurC(" ", 7)))
print(sentence:reverse())
print((sentence:gsub(IIMfMjZurC("c", 14), IIMfMjZurC("5", 5))))
print((IIMfMjZurC("qr", 16)):rep(3))
print(sentence:sub(5, 9) .. IIMfMjZurC("|", 6) .. sentence:find(IIMfMjZurC("oxg", 9), 1, true))
