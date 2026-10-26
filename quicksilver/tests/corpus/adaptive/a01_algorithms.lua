-- Plain algorithms: number theory, sorting, searching, recursion. The programs here are the inputs the adaptive tests obfuscate.
local function gcd(a, b)
  while b ~= 0 do
    a, b = b, a % b
  end
  return a
end

local function isPrime(n)
  if n < 2 then return false end
  for d = 2, math.floor(math.sqrt(n)) do
    if n % d == 0 then return false end
  end
  return true
end

local function primesUpTo(limit)
  local out = {}
  for n = 2, limit do
    if isPrime(n) then out[#out + 1] = n end
  end
  return out
end

local function fib(n, memo)
  memo = memo or {}
  if n <= 2 then return 1 end
  if memo[n] then return memo[n] end
  local v = fib(n - 1, memo) + fib(n - 2, memo)
  memo[n] = v
  return v
end

local function bubbleSort(list)
  local n = #list
  local swapped = true
  while swapped do
    swapped = false
    for i = 1, n - 1 do
      if list[i] > list[i + 1] then
        list[i], list[i + 1] = list[i + 1], list[i]
        swapped = true
      end
    end
    n = n - 1
  end
  return list
end

local function binarySearch(list, target)
  local lo, hi = 1, #list
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    if list[mid] == target then
      return mid
    elseif list[mid] < target then
      lo = mid + 1
    else
      hi = mid - 1
    end
  end
  return nil
end

local function power(base, exp)
  if exp == 0 then return 1 end
  local half = power(base, math.floor(exp / 2))
  if exp % 2 == 0 then return half * half end
  return half * half * base
end

local primes = primesUpTo(60)
print("primes: " .. table.concat(primes, ","))
print("gcd", gcd(84, 36), gcd(17, 5), gcd(1071, 462))
print("fib", fib(10), fib(25))
local sorted = bubbleSort({ 29, 3, 17, 8, 41, 5, 12, 33 })
print("sorted: " .. table.concat(sorted, " "))
print("found at", binarySearch(sorted, 17), binarySearch(sorted, 40))
print("power", power(2, 10), power(3, 7))
local total = 0
for i = 1, 100 do
  if i % 3 == 0 or i % 5 == 0 then total = total + i end
end
print("multiples", total)
