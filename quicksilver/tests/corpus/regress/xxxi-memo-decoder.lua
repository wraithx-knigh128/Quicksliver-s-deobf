-- Prompt XXXI, KNOWN-ISSUES #118 reduced: a decoder that memoises by key and writes a placeholder before it decodes, and a character
-- table that is filled inside the same statement that calls the decoder (as a flattened program's main loop does). The sandbox cannot
-- run that statement before the calls, so the first call fails part-way and leaves the placeholder behind.
local K = {}
local C = {}
local function d(s, k)
  if K[k] then return K[k] end
  K[k] = ""
  local o = ""
  for i = 1, #s do o = o .. C[(s:byte(i) - k) % 256 + 1] end
  K[k] = o
  return o
end
local st = 1
while st do
  if st == 1 then
    for i = 1, 256 do C[i] = string.char(i - 1) end
    st = 2
  else
    print(d("tubsu", 1), d("tubsu", 1))
    print(d("ceegrv", 2), d("vhhq", 3), d("vhhq", 3))
    st = nil
  end
end
