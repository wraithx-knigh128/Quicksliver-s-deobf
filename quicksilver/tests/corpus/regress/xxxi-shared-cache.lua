-- Prompt XXXI, KNOWN-ISSUES #118, second form: two memoising decoders share one cache. The table they decode with is filled inside the
-- loop that also calls them, so in the decoder evaluation's sandbox the first call of d fails half-way and leaves its placeholder "" in
-- the cache; e, a different function, then returns that placeholder for the same key. A rule that distrusts only the failed decoder's own
-- later results accepts e's "" (Prompt XXX's pass replaced six calls here by ""). Expected output: the original's.
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
local function e(s, k)
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
    print(d("tubsu", 1), e("tubsu", 1), e("tubsu", 1), d("ceegrv", 2), d("vhhq", 3))
    print(e("ceegrv", 2), d("vhhq", 3), e("vhhq", 3), d("ceegrv", 2))
    st = nil
  end
end
