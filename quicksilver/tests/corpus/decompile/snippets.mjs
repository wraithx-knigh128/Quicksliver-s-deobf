// Programs used to test the bytecode decompiler. Each prints enough that a wrong reconstruction shows up as a
// different output on the reference interpreter. They cover the shapes the Lua compiler produces: locals,
// upvalues, closures, varargs, every loop and branch form, short-circuit conditions, method calls, table
// constructors, string building, multiple assignment and returns.
export const SNIPPETS = {
  straight: `
    local a = 1
    local b = a + 2
    print(a, b, a * b, b / a, b % 2, 2 ^ 3, -a, #"abc", not a)
    local s = "x" .. a .. "y" .. b
    print(s)
  `,
  tables: `
    local t = { 1, 2, 3, x = 10, ["y z"] = 20, [5] = 50 }
    t.w = t.x + t["y z"]
    t[#t + 1] = 99
    print(#t, t.x, t["y z"], t[5], t.w, t[4])
    local nested = { a = { b = { c = 7 } }, list = { { 1 }, { 2 } } }
    print(nested.a.b.c, nested.list[2][1])
    local big = {} for i = 1, 120 do big[i] = i * 2 end print(#big, big[60], big[120])
  `,
  branches: `
    local function sign(n)
      if n < 0 then return "neg" elseif n == 0 then return "zero" else return "pos" end
    end
    print(sign(-5), sign(0), sign(7))
    local function grade(s)
      local g
      if s >= 90 then g = "A" elseif s >= 80 then g = "B" elseif s >= 70 then g = "C" else g = "F" end
      return g
    end
    print(grade(95), grade(85), grade(75), grade(10))
    local x = 5
    if x > 3 then print("gt3") end
    if x > 10 then print("gt10") else print("le10") end
    if not (x == 5) then print("ne") else print("eq") end
  `,
  logic: `
    local function f(a, b, c)
      if a and b then return 1 end
      if a or b then return 2 end
      if (a and b) or c then return 3 end
      if not a and not b and c then return 4 end
      return 5
    end
    print(f(true, true, false), f(true, false, false), f(false, false, true), f(nil, nil, nil), f(false, false, 1))
    local v1 = nil or "default"
    local v2 = false and 1 or 2
    local function pick(a, b) return a and b or "none" end
    print(v1, v2, pick(1, 2), pick(nil, 2), pick(1, nil))
    local n = 0
    local function bump() n = n + 1 return n end
    local r = bump() > 0 and bump() > 1 and bump()
    print(r, n)
  `,
  loops: `
    local s = 0
    for i = 1, 10 do s = s + i end print(s)
    for i = 10, 1, -3 do s = s + i end print(s)
    for i = 1, 3 do for j = 1, 3 do s = s + i * j end end print(s)
    local i = 0
    while i < 5 do i = i + 1 if i == 3 then break end end print(i)
    local k = 0
    repeat k = k + 2 until k >= 7 print(k)
    local t = { "a", "b", "c" }
    for idx, v in ipairs(t) do print(idx, v) end
    local keys = {} for key in pairs({ x = 1, y = 2, z = 3 }) do keys[#keys + 1] = key end table.sort(keys) print(table.concat(keys, ","))
    while true do k = k - 1 if k < 0 then break end end print(k)
    local c = 0
    for n = 1, 20 do
      if n % 2 == 0 then
        c = c + 1
      elseif n % 3 == 0 then
        c = c + 10
      end
    end
    print(c)
  `,
  closures: `
    local function counter() local n = 0 return function() n = n + 1 return n end end
    local c1, c2 = counter(), counter()
    print(c1(), c1(), c2())
    local fns = {}
    for i = 1, 3 do fns[i] = function() return i * 10 end end
    print(fns[1](), fns[2](), fns[3]())
    local function fib(n) if n < 2 then return n end return fib(n - 1) + fib(n - 2) end
    print(fib(15))
    local function compose(f, g) return function(...) return f(g(...)) end end
    local inc = function(x) return x + 1 end
    local dbl = function(x) return x * 2 end
    print(compose(inc, dbl)(5), compose(dbl, inc)(5))
    local acc = {}
    local function add(v) acc[#acc + 1] = v return #acc end
    add(1) add(2) print(#acc)
  `,
  capturedVarargTable: `
    local function compose(...)
      local fns = { ... }
      return function(x)
        for i = #fns, 1, -1 do x = fns[i](x) end
        return x
      end
    end
    print(compose(function(a) return a + 1 end, function(a) return a * 2 end)(5))
    local function counter(start, ...)
      local state = { start, ... }
      return function() state[1] = state[1] + 1 return #state, state[1] end
    end
    local c = counter(10, 20, 30)
    print(c()) print(c())
  `,
  varargs: `
    local function va(...) local t = { ... } return select('#', ...), #t, ... end
    print(va(1, 2, 3))
    print(va())
    local function first(a, ...) return a, select('#', ...) end
    print(first(1, 2, 3, 4))
    local function sum(...) local s = 0 for _, v in ipairs({ ... }) do s = s + v end return s end
    print(sum(1, 2, 3, 4, 5))
    print((va(1, 2)))
  `,
  methods: `
    local Account = {}
    Account.__index = Account
    function Account.new(b) return setmetatable({ balance = b }, Account) end
    function Account:deposit(v) self.balance = self.balance + v return self end
    function Account:get() return self.balance end
    local a = Account.new(10)
    a:deposit(5):deposit(10)
    print(a:get(), a.balance)
    local s = "hello"
    print(s:upper(), s:sub(2, 3), ("x"):rep(3), #s:rep(2))
    local obj = { name = "o", greet = function(self, who) return self.name .. " greets " .. who end }
    print(obj:greet("you"))
  `,
  multiassign: `
    local a, b, c = 1, 2, 3
    a, b = b, a
    print(a, b, c)
    local function two() return 10, 20 end
    local x, y = two()
    local p, q, r = two()
    print(x, y, p, q, r)
    local t = { two() }
    local u = { two(), 5 }
    print(#t, #u, u[1], u[2])
    print(two(), two())
    print((two()))
    local m = { n = 0 }
    m.n, m.k = 5, 6
    print(m.n, m.k)
  `,
  strings: `
    local parts = {}
    for w in string.gmatch("the quick brown fox", "%a+") do parts[#parts + 1] = w:upper() end
    print(table.concat(parts, "-"))
    print(string.format("%d %s %5.2f %x", 42, "str", 3.14159, 255))
    local s = "a,b,,c"
    local out = {}
    for field in (s .. ","):gmatch("([^,]*),") do out[#out + 1] = "[" .. field .. "]" end
    print(table.concat(out))
    print(("abc"):byte(1, -1))
    print(string.char(72, 105), #"\\n\\t\\0", "a\\\\b", 'quote"s')
  `,
  globals: `
    counter = 0
    function bump(n) counter = counter + (n or 1) return counter end
    bump() bump(5)
    print(counter, type(bump), _G.counter)
    local env = { v = 1 }
    local function setv(x) env.v = x end
    setv(9) print(env.v)
    gtable = { f = function() return "gf" end }
    print(gtable.f())
  `,
  numeric: `
    print(1 + 2 * 3 - 4 / 2, (2 + 3) * 4, 10 % 3, -7 % 3, 2 ^ 0.5 > 1.41)
    print(1e3, 0x10, 255 == 0xff, 3 == 3.0, math.floor(-3.5), math.max(1, 5, 3))
    local big = 123456789 * 1000
    print(big, big + 0.5)
  `,
  nestedfuncs: `
    local function outer(a)
      local b = a * 2
      local function mid(c)
        local d = b + c
        local function inner(e) return a + b + c + d + e end
        return inner
      end
      return mid
    end
    print(outer(1)(2)(3))
    local function map(t, f) local r = {} for i = 1, #t do r[i] = f(t[i]) end return r end
    local sq = map({ 1, 2, 3 }, function(x) return x * x end)
    print(table.concat(sq, " "))
    local function memo(f) local c = {} return function(n) local v = c[n] if v == nil then v = f(n) c[n] = v end return v end end
    local slow = function(n) return n * n end
    local fast = memo(slow)
    print(fast(4), fast(4), fast(5))
  `,
  earlyreturn: `
    local function find(t, x)
      for i = 1, #t do if t[i] == x then return i end end
      return nil
    end
    print(find({ 5, 6, 7 }, 7), find({ 5, 6, 7 }, 9))
    local function classify(n)
      if n < 0 then return "negative" end
      if n == 0 then return "zero" end
      for i = 2, n - 1 do if n % i == 0 then return "composite" end end
      return "prime-or-one"
    end
    print(classify(-1), classify(0), classify(7), classify(9))
    local function noret() local x = 1 end
    print(noret())
  `,
  // Prompt XXX: shapes found in MoonSec V3 programs that the decompiler abandoned or got wrong (each reduced from a real function)
  loopIfBreakElse: `
    local function walk(l)
      local out = {}
      while l do
        if l.x then out[#out + 1] = "hit" .. l.x break else out[#out + 1] = "miss" l = l.nxt end
      end
      return table.concat(out, ",")
    end
    print(walk({ nxt = { nxt = { x = 3 } } }), walk(nil), walk({ x = 1 }))
  `,
  nestedForBreak: `
    local function find(list, bp, ch)
      local found
      for _, item in pairs(bp) do
        for _, name in ipairs(list) do
          if name == item.Name then found = item.Name break
          else
            for _, child in ipairs(ch) do if child.Name == name then found = "child:" .. child.Name break end end
          end
        end
      end
      return found
    end
    print(find({ "a", "b" }, { { Name = "b" } }, {}), find({ "z" }, { { Name = "q" } }, { { Name = "z" } }), find({}, {}, {}))
    local function pairsBreak(l, b) local n = 0 for _, i in ipairs(b) do for _, v in ipairs(l) do if v == i then n = n + 1 break end end end return n end
    print(pairsBreak({ 1, 2, 3 }, { 2, 3, 4 }))
  `,
  orderedEffects: `
    local log = {}
    local svc = { Players = { LocalPlayer = { Name = "p" } } }
    local game = { GetService = function(self, n) log[#log + 1] = "get " .. n ; return svc[n] or { JSONEncode = function(_, t) log[#log + 1] = "encode" ; return t.embeds[1].description end } end }
    local function http_request(r) log[#log + 1] = "send " .. r.Body end
    local data = { content = "", embeds = { { description = game:GetService("Players").LocalPlayer.Name .. " used it", title = "T" } } }
    http_request({ Url = "u", Method = "POST", Body = game:GetService("HttpService"):JSONEncode(data) })
    print(table.concat(log, ";"))
  `,
  valueExpressions: `
    local function v(n, a, b, c)
      return n == 0 or a and n or "s", n == 0 or a and n, a ~= b and c and c.x > 0, c and c:F("H") and c.x > 0,
        n > 0 or "s" and n and n < 1 or n and n or a, (n == 0) and a or b
    end
    local C = { x = 2, F = function(self, h) return h .. self.x end }
    for _, args in ipairs({ { 0, false, true, C }, { 2, true, false, nil }, { 5, 1, 1, C }, { -1, nil, 2, { x = -1, F = function() return false end } } }) do
      print(v(args[1], args[2], args[3], args[4]))
    end
    local function w(n, a) local r = n > 1 and n < 9 and a or n return r, (n == 1 or n == 2) and "few" or "many" end
    print(w(3, "x"), w(1, false), w(10, nil))
  `,
  conditionAfterCall: `
    local function req(t) return { StatusCode = t.code, Body = t.body } end
    local function get(code, body)
      local r = req({ code = code, body = body })
      if r.StatusCode ~= 200 then return "fail " .. r.StatusCode end
      return r.Body
    end
    print(get(200, "ok"), get(404, "x"))
    local q
    local function queue(s)
      if writefile then pcall(function() return s end)
      elseif (syn and syn.queue_on_teleport) or q then
        local f = (syn and syn.queue_on_teleport) or q
        pcall(function() f(s) end)
      end
    end
    q = function(s) print("queued", s) end
    queue("a")
  `,
  ifThenWhileSameExit: `
    local on, a, b = false, 1, 2
    local n = 0
    local function toggle()
      on = not on
      if on then
        while on do
          local args = { "Transfer", a, b }
          n = n + #args
          if n > 6 then on = false end
        end
      end
    end
    toggle()
    print(n, on)
    toggle() toggle()
    print(n, on)
  `,
  innerLoopThenBreak: `
    local cfg = { n = 0, title = { Text = "(0/0)" } }
    local s = { autofarm = true, oldfarm = false, log = {} }
    function s.retry() s.log[#s.log + 1] = "retry" cfg.n = cfg.n + 1 if cfg.n > 2 then cfg.title.Text = "STARTING" end end
    local function tick() return cfg.n < 10 end
    local function run()
      while tick() do
        if string.find(cfg.title.Text, "(0/0)", 1, true) then
          if s.autofarm or s.oldfarm then s.retry() end
          while not string.find(cfg.title.Text, "STARTING", 1, true) do
            s.log[#s.log + 1] = "wait"
            if s.autofarm or s.oldfarm then s.retry() end
          end
          break
        end
      end
    end
    run()
    print(table.concat(s.log, ","), cfg.n, cfg.title.Text)
  `,
  conditionWithTable: `
    local S = { WallCheck = true }
    local function obscuring(t, extra) return #t > 1 and t or {} end
    local function pick(list)
      local out = {}
      for _, v in pairs(list) do
        if S.WallCheck and #obscuring({ v.a, v.b }, v.c) > 0 then
        else
          out[#out + 1] = v.name
        end
      end
      table.sort(out)
      return table.concat(out, ",")
    end
    local L = { { name = "x", a = 1, b = 2 }, { name = "y", a = 1 }, { name = "z" } }
    print(pick(L)) S.WallCheck = false print(pick(L))
  `,
};

/** Constructs that only exist from Lua 5.3: integer division, bitwise operators, integer/float distinction. */
export const SNIPPETS_54 = {
  integers: `
    print(7 // 2, 7.0 // 2, 7 % 3, 2 ^ 3, 10 / 2, 3 | 4, 6 & 3, 5 ~ 1, 1 << 4, 256 >> 4, ~0)
    local n = 10
    print(n // 3, n % 3, n / 4, -n // 3, n * 1.0, 1e2, 0x7fffffff + 1)
    for i = 3, 1, -1 do print(i, i * 2) end
    for f = 1.0, 2 do print(f) end
  `,
};

/**
 * Prompt XXX: shapes that Lua 5.1 compiles in a way the decompiler now reads; Lua 5.4 compiles them differently. (`local ok = …` with a
 * field comparison, a local's value delivered by TESTSET and a method call, then `if ok`: Lua 5.4 with debug information is still not
 * decompiled — docs/KNOWN-ISSUES.md.)
 */
export const SNIPPETS_51 = {
  valueThenTest: `
    local Mode = { Value = "Boss" }
    local D = { GetAttribute = function(self, k) return self[k] end, Dungeon = true }
    local function pick(list)
      local best, bestD = nil, math.huge
      for _, e in pairs(list) do
        if e.part and not e.dead then
          local scale = e.scale
          local isBoss = scale and scale > 1.5
          local isMini = scale and scale <= 1.5
          local ok = Mode.Value == "All" or Mode.Value == "Boss" and isBoss or Mode.Value == "Mini Boss" and isMini or (Mode.Value ~= "Boss" and Mode.Value ~= "Mini Boss") and D:GetAttribute("Dungeon") == true
          if ok then
            if e.d < bestD then bestD = e.d best = e end
          end
        end
      end
      return best and best.name, bestD
    end
    local L = { { part = true, scale = 2, d = 5, name = "a" }, { part = true, scale = 1, d = 3, name = "b" }, { part = true, dead = true, scale = 3, d = 1, name = "c" }, { part = false, d = 0, name = "d" } }
    for _, m in ipairs({ "All", "Boss", "Mini Boss", "Other" }) do Mode.Value = m print(m, pick(L)) end
    D.Dungeon = false Mode.Value = "Other" print(pick(L))
  `,
};
