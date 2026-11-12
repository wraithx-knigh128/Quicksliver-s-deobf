--[Obfuscated by Hercules v1.5 | discord.gg/Hx6RuYs8Ku]
-- s03: string-heavy program. Used to test string decoding and constant folding.
local greeting = string.char(-275 + 347)..string.char(-417 + 518)..string.char(-55 + 163)..string.char(859 - 751)..string.char(714 - 603)..string.char(749 - 705)..string.char(376 - 344)..string.char(256 - 175)..string.char(573 - 456)..string.char(-722 + 827)..string.char(-461 + 560)..string.char(999 - 892)..string.char(130 - 47)..string.char(-719 + 824)..string.char(940 - 832)..string.char(853 - 735)..string.char(451 - 350)..string.char(720 - 606)..string.char(482 - 449)
local separator = string.char(-466 + 511)..string.char(917 - 872)..string.char(443 - 398)..string.char(-469 + 514)..string.char(421 - 376)..string.char(-488 + 533)..string.char(-207 + 252)..string.char(-719 + 764)..string.char(997 - 952)..string.char(229 - 184)..string.char(-812 + 857)..string.char(-437 + 482)..string.char(-759 + 804)..string.char(-550 + 595)..string.char(-417 + 462)..string.char(-300 + 345)..string.char(-863 + 908)..string.char(-847 + 892)..string.char(326 - 281)..string.char(245 - 200)
local words = { string.char(-877 + 974)..string.char(-786 + 894)..string.char(205 - 93)..string.char(-378 + 482)..string.char(-331 + 428), string.char(-648 + 746)..string.char(896 - 782)..string.char(-786 + 883)..string.char(378 - 260)..string.char(-814 + 925), string.char(-640 + 739)..string.char(0 + 104)..string.char(372 - 275)..string.char(-411 + 525)..string.char(675 - 567)..string.char(489 - 384)..string.char(643 - 542), string.char(251 - 151)..string.char(-660 + 761)..string.char(962 - 854)..string.char(650 - 534)..string.char(411 - 314), string.char(-26 + 127)..string.char(-828 + 927)..string.char(-98 + 202)..string.char(472 - 361), string.char(-516 + 618)..string.char(-162 + 273)..string.char(-598 + 718)..string.char(246 - 130)..string.char(-717 + 831)..string.char(809 - 698)..string.char(-600 + 716) }
local template = string.char(693 - 602)..string.char(-894 + 931)..string.char(397 - 349)..string.char(-869 + 919)..string.char(353 - 253)..string.char(-113 + 206)..string.char(-481 + 513)..string.char(-65 + 102)..string.char(-208 + 323)..string.char(990 - 958)..string.char(536 - 496)..string.char(924 - 887)..string.char(-296 + 396)..string.char(-263 + 295)..string.char(-5 + 104)..string.char(-280 + 384)..string.char(431 - 334)..string.char(-628 + 742)..string.char(-789 + 904)..string.char(-868 + 909)

print(greeting)
print(separator)

for index, word in ipairs(words) do
  print(string.format(template, index, word:upper(), #word))
end

print(separator)

local sentence = string.char(-328 + 444)..string.char(-107 + 211)..string.char(497 - 396)..string.char(-649 + 681)..string.char(229 - 116)..string.char(505 - 388)..string.char(764 - 659)..string.char(-1 + 100)..string.char(-503 + 610)..string.char(907 - 875)..string.char(650 - 552)..string.char(901 - 787)..string.char(758 - 647)..string.char(-562 + 681)..string.char(663 - 553)..string.char(-252 + 284)..string.char(725 - 623)..string.char(888 - 777)..string.char(962 - 842)..string.char(-116 + 148)..string.char(913 - 807)..string.char(533 - 416)..string.char(-677 + 786)..string.char(485 - 373)..string.char(-552 + 667)..string.char(-187 + 219)..string.char(-387 + 498)..string.char(486 - 368)..string.char(-203 + 304)..string.char(-633 + 747)..string.char(-604 + 636)..string.char(-60 + 176)..string.char(-769 + 873)..string.char(-513 + 614)..string.char(-947 + 979)..string.char(-461 + 569)..string.char(-279 + 376)..string.char(-481 + 603)..string.char(-13 + 134)..string.char(-449 + 481)..string.char(-526 + 626)..string.char(-586 + 697)..string.char(966 - 863)
local counts = {}
for letter in sentence:gmatch(string.char(880 - 843)..string.char(332 - 235)) do
  counts[letter] = (counts[letter] or 0) + 1
end

local letters = {}
for letter in pairs(counts) do
  letters[#letters + 1] = letter
end
table.sort(letters)

local summary = {}
for _, letter in ipairs(letters) do
  summary[#summary + 1] = letter .. string.char(724 - 663) .. counts[letter]
end
print(table.concat(summary, string.char(112 - 80)))
print(sentence:reverse())
print((sentence:gsub(string.char(-445 + 556), string.char(-567 + 615))))
print((string.char(939 - 842)..string.char(-655 + 753)):rep(3))
print(sentence:sub(5, 9) .. string.char(346 - 222) .. sentence:find(string.char(247 - 145)..string.char(-679 + 790)..string.char(-746 + 866), 1, true))
