-- controlled: closures that only read upvalues (no parameters, no assignment to upvalues)
local base = 40
local name = "answer"
local function show()
  print(name, base + 2)
end
show()
local function twice()
  local a = base * 2
  return a
end
local r = twice()
print("twice", r)
