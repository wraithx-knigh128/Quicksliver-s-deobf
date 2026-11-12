--[Obfuscated by Hercules v1.6.2 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
do
    local _BFR,_MFR,T,E,G,Pa,GM,RG={["table.sort"]="function",["math.atan"]="function",["string.byte"]="function",["math.exp"]="function",["debug.sethook"]="function",["debug.traceback"]="function",["type"]="function",["math.ceil"]="function",["debug.getlocal"]="function",["rawset"]="function",["math.rad"]="function",["string.format"]="function",["debug.getupvalue"]="function",["os.clock"]="function",["os.exit"]="function",["math.cos"]="function",["string.sub"]="function",["pcall"]="function",["os.difftime"]="function",["math.deg"]="function",["math.sin"]="function",["debug.getinfo"]="function",["rawequal"]="function",["math.tan"]="function",["math.sqrt"]="function",["os.date"]="function",["math.modf"]="function",["math.min"]="function",["tonumber"]="function",["math.abs"]="function",["math.fmod"]="function",["rawget"]="function",["math.max"]="function",["select"]="function",["math.floor"]="function",["tostring"]="function",["string.find"]="function",["string.len"]="function",["string.lower"]="function",["debug.setupvalue"]="function",["table.insert"]="function",["os.time"]="function",["collectgarbage"]="function",["math.asin"]="function",["math.acos"]="function",["load"]="function",["string.char"]="function",["table.concat"]="function",["string.upper"]="function",["next"]="function",["table.remove"]="function",["string.rep"]="function",["string.dump"]="function",["getmetatable"]="function",["loadfile"]="function",["xpcall"]="function",["assert"]="function",["string.reverse"]="function",["string.gsub"]="function",["setmetatable"]="function",["error"]="function",["string.gmatch"]="function",["string.match"]="function",["dofile"]="function"},{},type,error,_G,pairs,getmetatable,rawget
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
