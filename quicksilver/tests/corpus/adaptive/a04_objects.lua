-- Classes with inheritance, a stack and a queue.
local Animal = {}
Animal.__index = Animal
function Animal.new(name, sound)
  local self = setmetatable({}, Animal)
  self.name = name
  self.sound = sound
  return self
end
function Animal:speak()
  return self.name .. " says " .. self.sound
end

local Dog = setmetatable({}, { __index = Animal })
Dog.__index = Dog
function Dog.new(name)
  local self = Animal.new(name, "woof")
  return setmetatable(self, Dog)
end
function Dog:fetch(item)
  return self.name .. " fetches the " .. item
end

local Stack = {}
Stack.__index = Stack
function Stack.new() return setmetatable({ items = {}, size = 0 }, Stack) end
function Stack:push(v) self.size = self.size + 1; self.items[self.size] = v end
function Stack:pop()
  if self.size == 0 then return nil end
  local v = self.items[self.size]
  self.items[self.size] = nil
  self.size = self.size - 1
  return v
end

local Queue = {}
Queue.__index = Queue
function Queue.new() return setmetatable({ first = 1, last = 0, items = {} }, Queue) end
function Queue:push(v) self.last = self.last + 1; self.items[self.last] = v end
function Queue:pop()
  if self.first > self.last then return nil end
  local v = self.items[self.first]
  self.items[self.first] = nil
  self.first = self.first + 1
  return v
end

local d = Dog.new("Rex")
print(d:speak(), d:fetch("ball"))
local s, q = Stack.new(), Queue.new()
for i = 1, 5 do s:push(i * i); q:push(i * 10) end
local out = {}
for _ = 1, 3 do out[#out + 1] = s:pop() .. "/" .. q:pop() end
print(table.concat(out, " "), s.size, q.last - q.first + 1)

local function balanced(str)
  local stack = Stack.new()
  local pairsOf = { [")"] = "(", ["]"] = "[", ["}"] = "{" }
  for ch in str:gmatch(".") do
    if ch == "(" or ch == "[" or ch == "{" then
      stack:push(ch)
    elseif pairsOf[ch] then
      if stack:pop() ~= pairsOf[ch] then return false end
    end
  end
  return stack.size == 0
end
print(balanced("{[()]}"), balanced("([)]"), balanced("(("))
