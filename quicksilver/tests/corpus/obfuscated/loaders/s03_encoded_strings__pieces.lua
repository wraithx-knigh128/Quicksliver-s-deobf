(loadstring or load)("-- s03: string-heavy program. Used to" ..
  " test string decoding and constant fo" ..
  'lding.\nlocal greeting = "Hello, Quick' ..
  'Silver!"\nlocal separator = "---------' ..
  '-----------"\nlocal words = { "alpha",' ..
  ' "bravo", "charlie", "delta", "echo",' ..
  ' "foxtrot" }\nlocal template = "[%02d]' ..
  ' %s (%d chars)"\n\nprint(greeting)\nprin' ..
  "t(separator)\n\nfor index, word in ipai" ..
  "rs(words) do\n  print(string.format(te" ..
  "mplate, index, word:upper(), #word))\n" ..
  "end\n\nprint(separator)\n\nlocal sentence" ..
  ' = "the quick brown fox jumps over th' ..
  'e lazy dog"\nlocal counts = {}\nfor let' ..
  'ter in sentence:gmatch("%a") do\n  cou' ..
  "nts[letter] = (counts[letter] or 0) +" ..
  " 1\nend\n\nlocal letters = {}\nfor letter" ..
  " in pairs(counts) do\n  letters[#lette" ..
  "rs + 1] = letter\nend\ntable.sort(lette" ..
  "rs)\n\nlocal summary = {}\nfor _, letter" ..
  " in ipairs(letters) do\n  summary[#sum" ..
  'mary + 1] = letter .. "=" .. counts[l' ..
  "etter]\nend\nprint(table.concat(summary" ..
  ', " "))\nprint(sentence:reverse())\npri' ..
  'nt((sentence:gsub("o", "0")))\nprint((' ..
  '"ab"):rep(3))\nprint(sentence:sub(5, 9' ..
  ') .. "|" .. sentence:find("fox", 1, t' ..
  "rue))\n")()
