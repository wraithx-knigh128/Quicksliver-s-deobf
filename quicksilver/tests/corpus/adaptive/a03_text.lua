-- String processing.
local function split(s, sep)
  local out = {}
  local from = 1
  while true do
    local i, j = s:find(sep, from, true)
    if not i then
      out[#out + 1] = s:sub(from)
      break
    end
    out[#out + 1] = s:sub(from, i - 1)
    from = j + 1
  end
  return out
end

local function caesar(s, shift)
  return (s:gsub("%a", function(ch)
    local base = ch:match("%l") and 97 or 65
    return string.char((ch:byte() - base + shift) % 26 + base)
  end))
end

local function wordFrequency(text)
  local counts, order = {}, {}
  for word in text:lower():gmatch("%a+") do
    if not counts[word] then
      counts[word] = 0
      order[#order + 1] = word
    end
    counts[word] = counts[word] + 1
  end
  table.sort(order, function(a, b)
    if counts[a] ~= counts[b] then return counts[a] > counts[b] end
    return a < b
  end)
  local parts = {}
  for _, w in ipairs(order) do parts[#parts + 1] = w .. "=" .. counts[w] end
  return table.concat(parts, " ")
end

local function isPalindrome(s)
  s = s:lower():gsub("[^%a]", "")
  return s == s:reverse()
end

local function titleCase(s)
  return (s:gsub("(%a)([%w_']*)", function(first, rest) return first:upper() .. rest:lower() end))
end

local text = "the quick brown fox jumps over the lazy dog the end"
print(table.concat(split("a,b,,c", ","), "|"))
print(caesar("Hello, World", 3), caesar(caesar("Hello, World", 3), -3))
print(wordFrequency(text))
print(isPalindrome("A man, a plan, a canal: Panama"), isPalindrome("not one"))
print(titleCase("hello wORLD of lua"))
print(string.format("%5.2f|%-6s|%03d|%x", 3.14159, "ab", 7, 255))
print(("ab"):rep(3), #"hello", ("x"):byte())
