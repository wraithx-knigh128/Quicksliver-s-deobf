-- Table utilities and a serializer with sorted keys.
local function deepCopy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[deepCopy(k)] = deepCopy(x) end
  return out
end

local function merge(a, b)
  local out = deepCopy(a)
  for k, v in pairs(b) do
    if type(v) == "table" and type(out[k]) == "table" then
      out[k] = merge(out[k], v)
    else
      out[k] = deepCopy(v)
    end
  end
  return out
end

local function serialize(v, indent)
  indent = indent or ""
  if type(v) == "string" then return string.format("%q", v) end
  if type(v) ~= "table" then return tostring(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) == "number"
  end)
  local parts = {}
  for _, k in ipairs(keys) do
    local name = type(k) == "number" and "[" .. k .. "]" or k
    parts[#parts + 1] = indent .. "  " .. name .. " = " .. serialize(v[k], indent .. "  ")
  end
  return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
end

local function filter(list, pred)
  local out = {}
  for _, v in ipairs(list) do if pred(v) then out[#out + 1] = v end end
  return out
end

local function reduce(list, fn, init)
  local acc = init
  for _, v in ipairs(list) do acc = fn(acc, v) end
  return acc
end

local defaults = { name = "unit", stats = { hp = 10, mp = 5 }, tags = { "a", "b" } }
local custom = { stats = { hp = 25 }, level = 3 }
local merged = merge(defaults, custom)
print(serialize(merged))
local nums = {}
for i = 1, 12 do nums[i] = i * 3 % 7 end
print(table.concat(nums, " "))
print(table.concat(filter(nums, function(n) return n % 2 == 0 end), " "))
print(reduce(nums, function(a, b) return a + b end, 0), reduce(nums, math.max, 0))
