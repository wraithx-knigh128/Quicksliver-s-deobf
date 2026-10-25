(loadstring or load)("-- s04: branching and looping. Used t" ..
  "o test control-flow recovery.\nlocal f" ..
  "unction collatzSteps(n)\n  local steps" ..
  " = 0\n  while n ~= 1 do\n    if n % 2 =" ..
  "= 0 then\n      n = n / 2\n    else\n   " ..
  "   n = 3 * n + 1\n    end\n    steps = " ..
  "steps + 1\n  end\n  return steps\nend\n\nl" ..
  "ocal function classify(n)\n  if n < 0 " ..
  'then\n    return "negative"\n  elseif n' ..
  ' == 0 then\n    return "zero"\n  elseif' ..
  ' n < 10 then\n    return "small"\n  els' ..
  'eif n < 100 then\n    return "medium"\n' ..
  '  else\n    return "large"\n  end\nend\n\n' ..
  "local function firstDivisor(n)\n  loca" ..
  "l found\n  for d = 2, n do\n    if n % " ..
  "d == 0 then\n      found = d\n      bre" ..
  "ak\n    end\n  end\n  return found\nend\n\n" ..
  "local function digitSum(n)\n  local to" ..
  "tal = 0\n  repeat\n    total = total + " ..
  "n % 10\n    n = math.floor(n / 10)\n  u" ..
  "ntil n == 0\n  return total\nend\n\nlocal" ..
  " function stateMachine(input)\n  local" ..
  ' state = "start"\n  local trace = {}\n ' ..
  " for i = 1, #input do\n    local ch = " ..
  'input:sub(i, i)\n    if state == "star' ..
  't" then\n      if ch == "a" then state' ..
  ' = "seenA" end\n    elseif state == "s' ..
  'eenA" then\n      if ch == "b" then\n  ' ..
  '      state = "seenAB"\n      elseif c' ..
  'h ~= "a" then\n        state = "start"' ..
  '\n      end\n    elseif state == "seenA' ..
  'B" then\n      state = (ch == "c") and' ..
  ' "accept" or "start"\n    end\n    trac' ..
  "e[#trace + 1] = state\n  end\n  return " ..
  'state, table.concat(trace, ">")\nend\n\n' ..
  "for _, n in ipairs({ 6, 7, 27 }) do\n " ..
  ' print("collatz(" .. n .. ") = " .. c' ..
  "ollatzSteps(n))\nend\nfor _, n in ipair" ..
  "s({ -5, 0, 7, 42, 1000 }) do\n  print(" ..
  'n .. " is " .. classify(n))\nend\nprint' ..
  "(firstDivisor(91), firstDivisor(97), " ..
  'digitSum(98765))\nprint(stateMachine("' ..
  'xxabcab"))\nprint(stateMachine("aabx")' ..
  ")\n")()
