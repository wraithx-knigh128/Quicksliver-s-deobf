local Players = game:GetService("Players")
local greeting = "hello, " .. "world"
_G["odd\29name"] = 7
local function count(list)
  local total = 0
  for i = 1, #list do
    if list[i] > 2 then total = total + list[i] end
  end
  return total
end
print(greeting, count({1, 2, 3, 4}), _G["odd\29name"])
return Players
