local a = "Hello, QuickSilver!"
local b = "--------------------"
local c = {"alpha", "bravo", "charlie", "delta", "echo", "foxtrot"}
local d = "[%02d] %s (%d chars)"
print(a)
print(b)
for e, f in ipairs(c) do
  print(string.format(d, e, f:upper(), #f))
end
print(b)
local g = "the quick brown fox jumps over the lazy dog"
local h = {}
for i in g:gmatch("%a") do
  h[i] = (((h[i] or 0)) + 1)
end
local j = {}
for k in pairs(h) do
  j[(#j + 1)] = k
end
table.sort(j)
local l = {}
for m, n in ipairs(j) do
  l[(#l + 1)] = (n .. ("=" .. h[n]))
end
print(table.concat(l, " "))
print(g:reverse())
print((g:gsub("o", "0")))
print(("ab"):rep(3))
print((g:sub(5, 9) .. ("|" .. g:find("fox", 1, true))))