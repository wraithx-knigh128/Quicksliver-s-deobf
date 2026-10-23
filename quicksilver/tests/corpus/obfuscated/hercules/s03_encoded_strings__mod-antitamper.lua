--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,Pa,GM,RG={["math.abs"]=math.abs,["math.atan"]=math.atan,["string.find"]=string.find,["string.lower"]=string.lower,["string.byte"]=string.byte,["debug.setupvalue"]=debug.setupvalue,["string.sub"]=string.sub,["string.upper"]=string.upper,["debug.sethook"]=debug.sethook,["xpcall"]=xpcall,["debug.traceback"]=debug.traceback,["error"]=error,["rawequal"]=rawequal,["table.sort"]=table.sort,["table.concat"]=table.concat,["debug.getupvalue"]=debug.getupvalue,["string.gsub"]=string.gsub,["string.gmatch"]=string.gmatch,["string.char"]=string.char,["debug.getlocal"]=debug.getlocal,["debug.getinfo"]=debug.getinfo,["os.exit"]=os.exit,["string.dump"]=string.dump,["os.time"]=os.time,["next"]=next,["load"]=load,["os.date"]=os.date,["collectgarbage"]=collectgarbage,["os.difftime"]=os.difftime,["os.clock"]=os.clock,["setmetatable"]=setmetatable,["type"]=type,["assert"]=assert,["math.sqrt"]=math.sqrt,["math.min"]=math.min,["math.sin"]=math.sin,["math.acos"]=math.acos,["string.len"]=string.len,["select"]=select,["pcall"]=pcall,["math.rad"]=math.rad,["dofile"]=dofile,["getmetatable"]=getmetatable,["table.insert"]=table.insert,["math.fmod"]=math.fmod,["string.rep"]=string.rep,["string.reverse"]=string.reverse,["tostring"]=tostring,["math.exp"]=math.exp,["string.format"]=string.format,["rawget"]=rawget,["math.asin"]=math.asin,["math.deg"]=math.deg,["math.cos"]=math.cos,["math.ceil"]=math.ceil,["math.floor"]=math.floor,["math.tan"]=math.tan,["tonumber"]=tonumber,["math.max"]=math.max,["table.remove"]=table.remove,["string.match"]=string.match,["rawset"]=rawset,["math.modf"]=math.modf,["loadfile"]=loadfile},{},type,error,pairs,getmetatable,rawget
    local DG={table=table,string=string,math=math,os=os}
    local function check()
        for n,ref in Pa(_BFR) do
            if ref==nil then
                E("Tamper Detected! Reason: Critical function removed: "..n)
                return
            end
            if T(ref)~="function" then
                E("Tamper Detected! Reason: Critical function type changed: "..n.." (was function, now "..T(ref)..")")
                return
            end
        end
        for tname in Pa(_MFR) do
            local parts={}
            for p in tname:gmatch("[^.]+") do parts[#parts+1]=p end
            local t=DG[(parts[1])]
            if t then
                local mt=GM(t)
                if mt then
                    local mf=RG(mt,parts[2])
                    if mf then
                        local expected=_MFR[tname]
                        if T(mf)~=expected then
                            E("Tamper Detected! Reason: Metamethod tampered: "..tname)
                            return
                        end
                    end
                end
            end
        end
        local d=debug
        if T(d)=="table" then
            local _DK={"getinfo","getlocal","getupvalue","traceback","sethook","setupvalue"}
            for _,k in Pa(_DK) do
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
