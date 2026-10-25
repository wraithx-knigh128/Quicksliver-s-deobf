(loadstring or load)("-- s05: closures, varargs, recursion," ..
  " higher-order functions. Used to test" ..
  " nested-function handling.\nlocal func" ..
  "tion counter(start, step)\n  local val" ..
  "ue = start\n  return function()\n    va" ..
  "lue = value + step\n    return value\n " ..
  " end\nend\n\nlocal function memoize(fn)\n" ..
  "  local cache = {}\n  return function(" ..
  "n)\n    local hit = cache[n]\n    if hi" ..
  "t == nil then\n      hit = fn(n)\n     " ..
  " cache[n] = hit\n    end\n    return hi" ..
  "t\n  end\nend\n\nlocal fib\nfib = memoize(" ..
  "function(n)\n  if n < 2 then\n    retur" ..
  "n n\n  end\n  return fib(n - 1) + fib(n" ..
  " - 2)\nend)\n\nlocal function compose(.." ..
  ".)\n  local fns = { ... }\n  return fun" ..
  "ction(x)\n    for i = #fns, 1, -1 do\n " ..
  "     x = fns[i](x)\n    end\n    return" ..
  " x\n  end\nend\n\nlocal function map(list" ..
  ", fn)\n  local out = {}\n  for i, v in " ..
  "ipairs(list) do\n    out[i] = fn(v, i)" ..
  "\n  end\n  return out\nend\n\nlocal functi" ..
  "on sum(...)\n  local total = 0\n  for i" ..
  ' = 1, select("#", ...) do\n    total =' ..
  " total + (select(i, ...))\n  end\n  ret" ..
  "urn total\nend\n\nlocal next5 = counter(" ..
  "10, 5)\nprint(next5(), next5(), next5(" ..
  "))\nprint(fib(30), fib(40))\n\nlocal inc" ..
  " = function(x) return x + 1 end\nlocal" ..
  " dbl = function(x) return x * 2 end\np" ..
  "rint(compose(inc, dbl)(5), compose(db" ..
  "l, inc)(5))\nprint(table.concat(map({ " ..
  "1, 2, 3, 4 }, function(v, i) return v" ..
  ' * i end), ","))\nprint(sum(1, 2, 3, 4' ..
  ", 5), sum())\n\nlocal function outer(a)" ..
  "\n  local function middle(b)\n    local" ..
  " function inner(c)\n      return a * 1" ..
  "00 + b * 10 + c\n    end\n    return in" ..
  "ner\n  end\n  return middle\nend\nprint(o" ..
  "uter(1)(2)(3))\n")()
