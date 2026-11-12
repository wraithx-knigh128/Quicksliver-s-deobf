--[Obfuscated by Hercules v1.5 | discord.gg/Hx6RuYs8Ku]
local function zxWm3dlEREu(Qg2IO5y71ID9)
    return (Qg2IO5y71ID9 >= 48 and Qg2IO5y71ID9 <= 57) or 
           (Qg2IO5y71ID9 >= 65 and Qg2IO5y71ID9 <= 90) or 
           (Qg2IO5y71ID9 >= 97 and Qg2IO5y71ID9 <= 122)
end

local function IIM4fM4j0urC(BmXJxEmbDXKy1, cbhbX2asaq)
    local inX8FpSju1 = {}
    for i = 1, #BmXJxEmbDXKy1 do
        local Qg2IO5y71ID9 = BmXJxEmbDXKy1:byte(i)
        if zxWm3dlEREu(Qg2IO5y71ID9) then
            local VQeA5wPd0wi            if Qg2IO5y71ID9 >= 48 and Qg2IO5y71ID9 <= 57 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 48 - cbhbX2asaq + 10) % 10) + 48
            elseif Qg2IO5y71ID9 >= 65 and Qg2IO5y71ID9 <= 90 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 65 - cbhbX2asaq + 26) % 26) + 65
            elseif Qg2IO5y71ID9 >= 97 and Qg2IO5y71ID9 <= 122 then
                VQeA5wPd0wi = ((Qg2IO5y71ID9 - 97 - cbhbX2asaq + 26) % 26) + 97
            end
            table.insert(inX8FpSju1, string.char(VQeA5wPd0wi))
        else
            table.insert(inX8FpSju1, string.char(Qg2IO5y71ID9))
        end
    end
    return table.concat(inX8FpSju1)
end

-- s03: string-heavy program. Used to test string decoding and constant folding.
local greeting = IIM4fM4j0urC("Nkrru, WaoiqYorbkx!", -319449722)
local separator = IIM4fM4j0urC("--------------------", -255556012)
local words = { IIM4fM4j0urC("doskd", 541087797), IIM4fM4j0urC("uktoh", -40125937), IIM4fM4j0urC("wbulfcy", -550623482), IIM4fM4j0urC("jkrzg", -1157038058), IIM4fM4j0urC("zxcj", 1536593495), IIM4fM4j0urC("ktcywty", 1457098297) }
local template = IIM4fM4j0urC("[%68l] %a (%l kpiza)", -952757174)

print(greeting)
print(separator)

for index, word in ipairs(words) do
  print(string.format(template, index, word:upper(), #word))
end

print(separator)

local sentence = IIM4fM4j0urC("esp bftnv mczhy qzi ufxad zgpc esp wlkj ozr", -232073857)
local counts = {}
for letter in sentence:gmatch(IIM4fM4j0urC("%c", -1590649578)) do
  counts[letter] = (counts[letter] or 0) + 1
end

local letters = {}
for letter in pairs(counts) do
  letters[#letters + 1] = letter
end
table.sort(letters)

local summary = {}
for _, letter in ipairs(letters) do
  summary[#summary + 1] = letter .. IIM4fM4j0urC("=", -36359420) .. counts[letter]
end
print(table.concat(summary, IIM4fM4j0urC(" ", 1353030996)))
print(sentence:reverse())
print((sentence:gsub(IIM4fM4j0urC("u", 1417633808), IIM4fM4j0urC("7", 30393867))))
print((IIM4fM4j0urC("no", -114656087)):rep(3))
print(sentence:sub(5, 9) .. IIM4fM4j0urC("|", -1116102668) .. sentence:find(IIM4fM4j0urC("ajs", 1036303679), 1, true))
