--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local chars = {[124]="|",[32]=" ",[97]="a",[98]="b",[99]="c",[100]="d",[101]="e",[40]="(",[103]="g",[102]="f",[105]="i",[44]=",",[45]="-",[108]="l",[109]="m",[48]="0",[50]="2",[112]="p",[51]="3",[52]="4",[115]="s",[54]="6",[46]=".",[56]="8",[53]="5",[58]=":",[37]="%",[41]=")",[61]="=",[114]="r"}
-- s01: arithmetic and string utilities. Used for minification / formatting tests.
local function clamp(value, low, high)
  if value < low then
    return low
  elseif value > high then
    return high
  end
  return value
end

local function gcd(a, b)
  while b ~= 0 do
    a, b = b, a % b
  end
  return a
end

local function isPrime(n)
  if n < 2 then
    return false
  end
  for i = 2, math.floor(math.sqrt(n)) do
    if n % i == 0 then
      return false
    end
  end
  return true
end

local function join(list, separator)
  local parts = {}
  for index = 1, #list do
    parts[#parts + 1] = tostring(list[index])
  end
  return table.concat(parts, separator)
end

local primes = {}
for candidate = 1, 50 do
  if isPrime(candidate) then
    primes[#primes + 1] = candidate
  end
end

print((chars[-235 + 347]..chars[-404 + 518]..chars[-58 + 163]..chars[859 - (750)]..chars[714 - (613)]..chars[749 - (634)]..chars[376 - (318)]..chars[256 - (224)]) .. join(primes, (chars[573 - (529)])))
print((chars[-724 + 827]..chars[-461 + 560]..chars[999 - (899)]..chars[130 - (90)]..chars[-768 + 824]..chars[940 - (888)]..chars[853 - (809)]..chars[451 - (419)]..chars[720 - (669)]..chars[482 - (428)]..chars[-470 + 511]..chars[917 - (885)]..chars[443 - (382)]..chars[-482 + 514]) .. gcd(84, 36))
print((chars[421 - (322)]..chars[-425 + 533]..chars[-155 + 252]..chars[-655 + 764]..chars[997 - (885)]..chars[229 - (171)]..chars[-825 + 857]) .. clamp(15, 0, 10) .. (chars[-450 + 482]) .. clamp(-3, 0, 10) .. (chars[-772 + 804]) .. clamp(7, 0, 10))
print(string.format((chars[-558 + 595]..chars[-409 + 462]..chars[-299 + 345]..chars[-858 + 908]..chars[-790 + 892]..chars[326 - (202)]..chars[245 - (208)]..chars[-929 + 974]..chars[-840 + 894]..chars[205 - (90)]..chars[-358 + 482]..chars[-391 + 428]..chars[-698 + 746]..chars[896 - (845)]..chars[-783 + 883]), 3.14159, (chars[378 - (281)]..chars[-827 + 925]), 7))
