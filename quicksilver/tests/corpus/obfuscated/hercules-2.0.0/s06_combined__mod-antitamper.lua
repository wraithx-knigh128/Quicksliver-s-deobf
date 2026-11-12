--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,Pa,GM,RG={["type"]=type,["rawset"]=rawset,["setmetatable"]=setmetatable,["string.reverse"]=string.reverse,["debug.setupvalue"]=debug.setupvalue,["table.sort"]=table.sort,["math.modf"]=math.modf,["tostring"]=tostring,["debug.sethook"]=debug.sethook,["debug.traceback"]=debug.traceback,["math.rad"]=math.rad,["string.gmatch"]=string.gmatch,["os.clock"]=os.clock,["string.dump"]=string.dump,["getmetatable"]=getmetatable,["rawget"]=rawget,["debug.getlocal"]=debug.getlocal,["next"]=next,["math.asin"]=math.asin,["string.len"]=string.len,["math.sqrt"]=math.sqrt,["table.remove"]=table.remove,["pcall"]=pcall,["os.exit"]=os.exit,["error"]=error,["os.time"]=os.time,["string.format"]=string.format,["os.difftime"]=os.difftime,["table.concat"]=table.concat,["string.match"]=string.match,["os.date"]=os.date,["loadfile"]=loadfile,["debug.getupvalue"]=debug.getupvalue,["math.tan"]=math.tan,["math.sin"]=math.sin,["math.min"]=math.min,["math.max"]=math.max,["debug.getinfo"]=debug.getinfo,["select"]=select,["math.ceil"]=math.ceil,["math.deg"]=math.deg,["math.atan"]=math.atan,["math.exp"]=math.exp,["string.rep"]=string.rep,["dofile"]=dofile,["math.cos"]=math.cos,["collectgarbage"]=collectgarbage,["string.lower"]=string.lower,["math.acos"]=math.acos,["string.upper"]=string.upper,["math.abs"]=math.abs,["table.insert"]=table.insert,["math.fmod"]=math.fmod,["string.find"]=string.find,["rawequal"]=rawequal,["math.floor"]=math.floor,["string.sub"]=string.sub,["xpcall"]=xpcall,["string.char"]=string.char,["tonumber"]=tonumber,["load"]=load,["string.gsub"]=string.gsub,["string.byte"]=string.byte,["assert"]=assert},{},type,error,pairs,getmetatable,rawget
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

-- s06: metatables, inheritance, queues and text processing in one program.
-- Used to test combined transformations end to end.
local Shape = {}
Shape.__index = Shape

function Shape.new(name)
  return setmetatable({ name = name }, Shape)
end

function Shape:describe()
  return self.name .. " with area " .. string.format("%.2f", self:area())
end

function Shape:area()
  return 0
end

local Circle = setmetatable({}, { __index = Shape })
Circle.__index = Circle

function Circle.new(radius)
  local self = Shape.new("circle")
  self.radius = radius
  return setmetatable(self, Circle)
end

function Circle:area()
  return math.pi * self.radius ^ 2
end

local Rect = setmetatable({}, { __index = Shape })
Rect.__index = Rect

function Rect.new(width, height)
  local self = Shape.new("rect")
  self.width, self.height = width, height
  return setmetatable(self, Rect)
end

function Rect:area()
  return self.width * self.height
end

local Queue = {}
Queue.__index = Queue
Queue.__len = nil

function Queue.new()
  return setmetatable({ first = 1, last = 0, items = {} }, Queue)
end

function Queue:push(value)
  self.last = self.last + 1
  self.items[self.last] = value
end

function Queue:pop()
  if self.first > self.last then
    return nil
  end
  local value = self.items[self.first]
  self.items[self.first] = nil
  self.first = self.first + 1
  return value
end

function Queue:size()
  return self.last - self.first + 1
end

local queue = Queue.new()
queue:push(Circle.new(2))
queue:push(Rect.new(3, 4))
queue:push(Shape.new("blob"))

while queue:size() > 0 do
  print(queue:pop():describe())
end

local function wordFrequency(text)
  local freq = {}
  for word in text:lower():gmatch("%a+") do
    freq[word] = (freq[word] or 0) + 1
  end
  local keys = {}
  for word in pairs(freq) do
    keys[#keys + 1] = word
  end
  table.sort(keys, function(a, b)
    if freq[a] ~= freq[b] then
      return freq[a] > freq[b]
    end
    return a < b
  end)
  local lines = {}
  for i = 1, math.min(3, #keys) do
    lines[#lines + 1] = keys[i] .. ":" .. freq[keys[i]]
  end
  return table.concat(lines, ", ")
end

print(wordFrequency("To be, or not to be, that is the question: to be wise is to be"))
