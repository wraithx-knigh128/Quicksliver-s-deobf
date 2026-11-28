-- Prompt XXXI (MoonSec V3 08010afe main/35/0/0, reduced): an inner for loop's break is sent by Lua's code generator through the outer
-- loop's break that follows it (luaK_jump chains the pending jump into the next JMP), past the inner loop's exit. Prompt XXX's decompiler
-- left the function undecompiled on Lua 5.1 ("unstructured jump"). Expected: decompiled, and the same output.
local out = {}
for i = 1, 4 do
  for j = 1, 4 do
    if j > i then break end
    out[#out + 1] = i * 10 + j
  end
  if i == 3 then break end
end
for _, row in ipairs({ { 1, 2 }, { 3, 4, 5 } }) do
  for k, v in ipairs(row) do
    if v == 4 then break end
    out[#out + 1] = v
  end
  break
end
print(table.concat(out, ","))
