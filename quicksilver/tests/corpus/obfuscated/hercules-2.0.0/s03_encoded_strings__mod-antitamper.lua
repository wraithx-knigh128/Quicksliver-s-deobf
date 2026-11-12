--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,Pa,GM,RG={["debug.getinfo"]=debug.getinfo,["math.sqrt"]=math.sqrt,["debug.traceback"]=debug.traceback,["tonumber"]=tonumber,["os.time"]=os.time,["type"]=type,["table.insert"]=table.insert,["string.rep"]=string.rep,["next"]=next,["math.tan"]=math.tan,["debug.setupvalue"]=debug.setupvalue,["debug.getupvalue"]=debug.getupvalue,["rawget"]=rawget,["string.format"]=string.format,["os.exit"]=os.exit,["table.sort"]=table.sort,["math.deg"]=math.deg,["string.find"]=string.find,["os.difftime"]=os.difftime,["math.max"]=math.max,["string.len"]=string.len,["os.date"]=os.date,["math.rad"]=math.rad,["rawequal"]=rawequal,["loadfile"]=loadfile,["math.cos"]=math.cos,["pcall"]=pcall,["rawset"]=rawset,["error"]=error,["os.clock"]=os.clock,["math.acos"]=math.acos,["tostring"]=tostring,["string.byte"]=string.byte,["assert"]=assert,["string.sub"]=string.sub,["math.min"]=math.min,["setmetatable"]=setmetatable,["math.modf"]=math.modf,["string.upper"]=string.upper,["math.fmod"]=math.fmod,["math.floor"]=math.floor,["math.exp"]=math.exp,["math.ceil"]=math.ceil,["math.atan"]=math.atan,["math.asin"]=math.asin,["math.abs"]=math.abs,["table.concat"]=table.concat,["table.remove"]=table.remove,["string.gsub"]=string.gsub,["debug.sethook"]=debug.sethook,["select"]=select,["string.dump"]=string.dump,["xpcall"]=xpcall,["getmetatable"]=getmetatable,["debug.getlocal"]=debug.getlocal,["string.lower"]=string.lower,["dofile"]=dofile,["string.gmatch"]=string.gmatch,["math.sin"]=math.sin,["string.match"]=string.match,["string.char"]=string.char,["collectgarbage"]=collectgarbage,["string.reverse"]=string.reverse,["load"]=load},{},type,error,pairs,getmetatable,rawget
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
