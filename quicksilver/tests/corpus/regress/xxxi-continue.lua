-- Prompt XXXI (MoonSec V3 ddc9c42c main/5 and c2f0c41b main/11, reduced), Lua 5.4: `goto continue` is how Lua 5.4 writes Luau's
-- `continue`, and compiles to the same jump to the loop's continue point. Prompt XXX left the function undecompiled (a shared tail too
-- large to duplicate). Decompiled as Luau it is written with `continue`; as Lua, it is still refused (no `continue` there).
local out = {}
local function emit(...) out[#out + 1] = table.concat({ ... }, ":") end
local i = 0
while i < 6 do
  i = i + 1
  if i % 2 == 0 then
    emit("even", i)
    if i == 4 then goto continue end
    emit("after", i)
  end
  emit("t0", i, i % 2)
  emit("t1", i, i % 3)
  emit("t2", i, i % 4)
  emit("t3", i, i % 5)
  emit("t4", i, i % 6)
  emit("t5", i, i % 7)
  emit("t6", i, i % 8)
  emit("t7", i, i % 9)
  emit("t8", i, i % 10)
  emit("t9", i, i % 11)
  emit("t10", i, i % 12)
  emit("t11", i, i % 13)
  emit("t12", i, i % 14)
  emit("t13", i, i % 15)
  emit("t14", i, i % 16)
  emit("t15", i, i % 17)
  emit("t16", i, i % 18)
  emit("t17", i, i % 19)
  emit("t18", i, i % 20)
  emit("t19", i, i % 21)
  emit("t20", i, i % 22)
  emit("t21", i, i % 23)
  emit("t22", i, i % 24)
  emit("t23", i, i % 25)
  emit("t24", i, i % 26)
  emit("t25", i, i % 27)
  emit("t26", i, i % 28)
  emit("t27", i, i % 29)
  emit("t28", i, i % 30)
  emit("t29", i, i % 31)
  ::continue::
end
local seen = {}
for idx, v in ipairs({ 3, 8, 0, 5, 12, 7 }) do
  if v > 4 and v < 10 then
    emit("mid", idx)
    if not seen[v % 3] then
      seen[v % 3] = true
      emit("first", v)
      goto cont
    end
  end
  emit("rest", idx, v)
  ::cont::
end
print(table.concat(out, " "))
