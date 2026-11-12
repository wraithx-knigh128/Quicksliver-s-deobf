--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,G,Pa,GM,RG={["debug.setupvalue"]="function",["math.fmod"]="function",["load"]="function",["setmetatable"]="function",["table.insert"]="function",["debug.sethook"]="function",["debug.getlocal"]="function",["collectgarbage"]="function",["debug.traceback"]="function",["debug.getupvalue"]="function",["debug.getinfo"]="function",["rawequal"]="function",["math.rad"]="function",["string.gmatch"]="function",["os.time"]="function",["tostring"]="function",["string.byte"]="function",["os.difftime"]="function",["os.date"]="function",["string.rep"]="function",["string.find"]="function",["math.min"]="function",["rawget"]="function",["math.modf"]="function",["os.clock"]="function",["string.match"]="function",["math.tan"]="function",["string.sub"]="function",["select"]="function",["assert"]="function",["math.acos"]="function",["next"]="function",["string.format"]="function",["dofile"]="function",["string.char"]="function",["math.sin"]="function",["math.max"]="function",["math.floor"]="function",["math.exp"]="function",["math.deg"]="function",["math.abs"]="function",["tonumber"]="function",["math.ceil"]="function",["math.cos"]="function",["type"]="function",["table.remove"]="function",["math.atan"]="function",["math.asin"]="function",["table.concat"]="function",["table.sort"]="function",["string.len"]="function",["string.gsub"]="function",["string.upper"]="function",["string.lower"]="function",["rawset"]="function",["loadfile"]="function",["string.dump"]="function",["pcall"]="function",["error"]="function",["string.reverse"]="function",["math.sqrt"]="function",["os.exit"]="function",["xpcall"]="function",["getmetatable"]="function"},{},type,error,_G,pairs,getmetatable,rawget
    local function check()
        for n,expectedType in Pa(_BFR) do
            local parts={}
            for p in n:gmatch("[^.]+") do parts[#parts+1]=p end
            local obj=G
            for i=1,#parts-1 do
                obj=obj[(parts[i])]
                if not obj then
                    E("Tamper Detected! Reason: Critical function removed: "..n)
                    return
                end
            end
            local cur=obj[(parts[#parts])]
            if cur==nil then
                E("Tamper Detected! Reason: Critical function removed: "..n)
                return
            end
            local curType=T(cur)
            if curType~=expectedType then
                E("Tamper Detected! Reason: Critical function type changed: "..n.." (was "..expectedType..", now "..curType..")")
                return
            end
        end
        for tname in Pa(_MFR) do
            local parts={}
            for p in tname:gmatch("[^.]+") do parts[#parts+1]=p end
            local t=G[(parts[1])]
            if t then
                local mt=GM(t)
                if mt then
                    local mf=RG(mt,parts[2])
                    if mf then
                        local expected=_MFR[tname]
                        if T(mf)~=T(expected) then
                            E("Tamper Detected! Reason: Metamethod tampered: "..tname)
                            return
                        end
                    end
                end
            end
        end
        local d=G.debug
        if T(d)=="table" then
            for _,k in Pa{"getinfo","getlocal","getupvalue","traceback","sethook","setupvalue"} do
                if T(d[k])~="function" then
                    E("Tamper Detected! Reason: Debug library incomplete")
                    return
                end
            end
        end
    end
    check()
end

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
