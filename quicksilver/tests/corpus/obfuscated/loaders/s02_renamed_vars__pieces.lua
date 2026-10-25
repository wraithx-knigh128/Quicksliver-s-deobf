(loadstring or load)("-- s02: descriptive identifiers. Used" ..
  " to test identifier renaming / readab" ..
  "ility recovery.\nlocal inventory = {}\n" ..
  "local totalWeight = 0\nlocal maxCarryW" ..
  "eight = 40\n\nlocal function addItem(na" ..
  "me, weight, quantity)\n  local entry =" ..
  " inventory[name]\n  local added = weig" ..
  "ht * quantity\n  if totalWeight + adde" ..
  "d > maxCarryWeight then\n    return fa" ..
  'lse, "too heavy: " .. name\n  end\n  if' ..
  " entry == nil then\n    entry = { weig" ..
  "ht = weight, quantity = 0 }\n    inven" ..
  "tory[name] = entry\n  end\n  entry.quan" ..
  "tity = entry.quantity + quantity\n  to" ..
  "talWeight = totalWeight + added\n  ret" ..
  "urn true\nend\n\nlocal function removeIt" ..
  "em(name, quantity)\n  local entry = in" ..
  "ventory[name]\n  if entry == nil or en" ..
  "try.quantity < quantity then\n    retu" ..
  'rn false, "not enough " .. name\n  end' ..
  "\n  entry.quantity = entry.quantity - " ..
  "quantity\n  totalWeight = totalWeight " ..
  "- entry.weight * quantity\n  if entry." ..
  "quantity == 0 then\n    inventory[name" ..
  "] = nil\n  end\n  return true\nend\n\nloca" ..
  "l function report()\n  local names = {" ..
  "}\n  for itemName in pairs(inventory) " ..
  "do\n    names[#names + 1] = itemName\n " ..
  " end\n  table.sort(names)\n  for _, ite" ..
  "mName in ipairs(names) do\n    local e" ..
  "ntry = inventory[itemName]\n    print(" ..
  'itemName .. " x" .. entry.quantity ..' ..
  ' " (" .. entry.weight * entry.quantit' ..
  'y .. "kg)")\n  end\n  print("total weig' ..
  'ht: " .. totalWeight)\nend\n\nprint(addI' ..
  'tem("rope", 3, 2))\nprint(addItem("lan' ..
  'tern", 5, 1))\nprint(addItem("anvil", ' ..
  '30, 2))\nprint(removeItem("rope", 1))\n' ..
  'print(removeItem("sword", 1))\nreport(' ..
  ")\n")()
