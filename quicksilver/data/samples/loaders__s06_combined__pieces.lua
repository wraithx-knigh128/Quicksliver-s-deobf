(loadstring or load)("-- s06: metatables, inheritance, queu" ..
  "es and text processing in one program" ..
  ".\n-- Used to test combined transforma" ..
  "tions end to end.\nlocal Shape = {}\nSh" ..
  "ape.__index = Shape\n\nfunction Shape.n" ..
  "ew(name)\n  return setmetatable({ name" ..
  " = name }, Shape)\nend\n\nfunction Shape" ..
  ':describe()\n  return self.name .. " w' ..
  'ith area " .. string.format("%.2f", s' ..
  "elf:area())\nend\n\nfunction Shape:area(" ..
  ")\n  return 0\nend\n\nlocal Circle = setm" ..
  "etatable({}, { __index = Shape })\nCir" ..
  "cle.__index = Circle\n\nfunction Circle" ..
  ".new(radius)\n  local self = Shape.new" ..
  '("circle")\n  self.radius = radius\n  r' ..
  "eturn setmetatable(self, Circle)\nend\n" ..
  "\nfunction Circle:area()\n  return math" ..
  ".pi * self.radius ^ 2\nend\n\nlocal Rect" ..
  " = setmetatable({}, { __index = Shape" ..
  " })\nRect.__index = Rect\n\nfunction Rec" ..
  "t.new(width, height)\n  local self = S" ..
  'hape.new("rect")\n  self.width, self.h' ..
  "eight = width, height\n  return setmet" ..
  "atable(self, Rect)\nend\n\nfunction Rect" ..
  ":area()\n  return self.width * self.he" ..
  "ight\nend\n\nlocal Queue = {}\nQueue.__in" ..
  "dex = Queue\nQueue.__len = nil\n\nfuncti" ..
  "on Queue.new()\n  return setmetatable(" ..
  "{ first = 1, last = 0, items = {} }, " ..
  "Queue)\nend\n\nfunction Queue:push(value" ..
  ")\n  self.last = self.last + 1\n  self." ..
  "items[self.last] = value\nend\n\nfunctio" ..
  "n Queue:pop()\n  if self.first > self." ..
  "last then\n    return nil\n  end\n  loca" ..
  "l value = self.items[self.first]\n  se" ..
  "lf.items[self.first] = nil\n  self.fir" ..
  "st = self.first + 1\n  return value\nen" ..
  "d\n\nfunction Queue:size()\n  return sel" ..
  "f.last - self.first + 1\nend\n\nlocal qu" ..
  "eue = Queue.new()\nqueue:push(Circle.n" ..
  "ew(2))\nqueue:push(Rect.new(3, 4))\nque" ..
  'ue:push(Shape.new("blob"))\n\nwhile que' ..
  "ue:size() > 0 do\n  print(queue:pop():" ..
  "describe())\nend\n\nlocal function wordF" ..
  "requency(text)\n  local freq = {}\n  fo" ..
  'r word in text:lower():gmatch("%a+") ' ..
  "do\n    freq[word] = (freq[word] or 0)" ..
  " + 1\n  end\n  local keys = {}\n  for wo" ..
  "rd in pairs(freq) do\n    keys[#keys +" ..
  " 1] = word\n  end\n  table.sort(keys, f" ..
  "unction(a, b)\n    if freq[a] ~= freq[" ..
  "b] then\n      return freq[a] > freq[b" ..
  "]\n    end\n    return a < b\n  end)\n  l" ..
  "ocal lines = {}\n  for i = 1, math.min" ..
  "(3, #keys) do\n    lines[#lines + 1] =" ..
  ' keys[i] .. ":" .. freq[keys[i]]\n  en' ..
  'd\n  return table.concat(lines, ", ")\n' ..
  'end\n\nprint(wordFrequency("To be, or n' ..
  "ot to be, that is the question: to be" ..
  ' wise is to be"))\n')()
