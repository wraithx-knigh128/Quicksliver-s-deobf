-- Prompt XXXI (MoonSec V3 ce3faecf main/1 and 6aaee086 main/7/14/3, reduced): `if a == b or a == (c and c.Name) then <long chain> end`.
-- The value `c and c.Name` splits the condition, its second test jumps straight to the function's final `return`, and the chain looked
-- like a tail both branches share, too large to duplicate. A jump to a `return` of nothing is that return. Expected: decompiled, same output.
local log, count = {}, 0
local function onChat(msg, owner, helper)
  local speaker = msg.FromSpeaker
  local text = msg.Message or ""
  if speaker == owner.Name or speaker == (helper and helper.Name) then
  if text == "" then
    log[#log + 1] = "empty"
  elseif text:lower() == "!c1" then
    log[#log + 1] = speaker .. ":c1:" .. tostring(helper and helper.Name)
    count = count + 1
  elseif text:lower() == "!c2" then
    log[#log + 1] = speaker .. ":c2:" .. tostring(helper and helper.Name)
    count = count + 2
  elseif text:lower() == "!c3" then
    log[#log + 1] = speaker .. ":c3:" .. tostring(helper and helper.Name)
    count = count + 3
  elseif text:lower() == "!c4" then
    log[#log + 1] = speaker .. ":c4:" .. tostring(helper and helper.Name)
    count = count + 4
  elseif text:lower() == "!c5" then
    log[#log + 1] = speaker .. ":c5:" .. tostring(helper and helper.Name)
    count = count + 5
  elseif text:lower() == "!c6" then
    log[#log + 1] = speaker .. ":c6:" .. tostring(helper and helper.Name)
    count = count + 6
  elseif text:lower() == "!c7" then
    log[#log + 1] = speaker .. ":c7:" .. tostring(helper and helper.Name)
    count = count + 7
  elseif text:lower() == "!c8" then
    log[#log + 1] = speaker .. ":c8:" .. tostring(helper and helper.Name)
    count = count + 8
  elseif text:lower() == "!c9" then
    log[#log + 1] = speaker .. ":c9:" .. tostring(helper and helper.Name)
    count = count + 9
  elseif text:lower() == "!c10" then
    log[#log + 1] = speaker .. ":c10:" .. tostring(helper and helper.Name)
    count = count + 10
  elseif text:lower() == "!c11" then
    log[#log + 1] = speaker .. ":c11:" .. tostring(helper and helper.Name)
    count = count + 11
  elseif text:lower() == "!c12" then
    log[#log + 1] = speaker .. ":c12:" .. tostring(helper and helper.Name)
    count = count + 12
  elseif text:lower() == "!c13" then
    log[#log + 1] = speaker .. ":c13:" .. tostring(helper and helper.Name)
    count = count + 13
  elseif text:lower() == "!c14" then
    log[#log + 1] = speaker .. ":c14:" .. tostring(helper and helper.Name)
    count = count + 14
  elseif text:lower() == "!c15" then
    log[#log + 1] = speaker .. ":c15:" .. tostring(helper and helper.Name)
    count = count + 15
  elseif text:lower() == "!c16" then
    log[#log + 1] = speaker .. ":c16:" .. tostring(helper and helper.Name)
    count = count + 16
  elseif text:lower() == "!c17" then
    log[#log + 1] = speaker .. ":c17:" .. tostring(helper and helper.Name)
    count = count + 17
  elseif text:lower() == "!c18" then
    log[#log + 1] = speaker .. ":c18:" .. tostring(helper and helper.Name)
    count = count + 18
  elseif text:lower() == "!c19" then
    log[#log + 1] = speaker .. ":c19:" .. tostring(helper and helper.Name)
    count = count + 19
  elseif text:lower() == "!c20" then
    log[#log + 1] = speaker .. ":c20:" .. tostring(helper and helper.Name)
    count = count + 20
  elseif text:lower() == "!c21" then
    log[#log + 1] = speaker .. ":c21:" .. tostring(helper and helper.Name)
    count = count + 21
  elseif text:lower() == "!c22" then
    log[#log + 1] = speaker .. ":c22:" .. tostring(helper and helper.Name)
    count = count + 22
  elseif text:lower() == "!c23" then
    log[#log + 1] = speaker .. ":c23:" .. tostring(helper and helper.Name)
    count = count + 23
  elseif text:lower() == "!c24" then
    log[#log + 1] = speaker .. ":c24:" .. tostring(helper and helper.Name)
    count = count + 24
  end
  end
end
local owner, helper = { Name = "own" }, { Name = "help" }
for _, m in ipairs({ { FromSpeaker = "own", Message = "!c3" }, { FromSpeaker = "x", Message = "!c4" }, { FromSpeaker = "help", Message = "!c20" }, { FromSpeaker = "help" }, { FromSpeaker = "own", Message = "!zz" } }) do
  onChat(m, owner, helper)
  onChat(m, owner, nil)
end
print(table.concat(log, ";"), count)
