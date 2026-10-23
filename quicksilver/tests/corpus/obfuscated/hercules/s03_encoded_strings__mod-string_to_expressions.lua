--[Obfuscated by Hercules v2.0.0 | hercules-obfuscator.xyz/discord | hercules-obfuscator.xyz/source]
local chars = {[72]="H",[81]="Q",[83]="S",[124]="|",[111]="o",[103]="g",[91]="[",[113]="q",[93]="]",[107]="k",[32]=" ",[33]="!",[97]="a",[98]="b",[99]="c",[100]="d",[101]="e",[102]="f",[40]="(",[41]=")",[105]="i",[106]="j",[44]=",",[45]="-",[109]="m",[110]="n",[48]="0",[112]="p",[50]="2",[114]="r",[115]="s",[116]="t",[117]="u",[118]="v",[119]="w",[120]="x",[121]="y",[122]="z",[37]="%",[61]="=",[108]="l",[104]="h"}
-- s03: string-heavy program. Used to test string decoding and constant folding.
local greeting = (chars[-275 + 347]..chars[-417 + 518]..chars[-55 + 163]..chars[859 - (751)]..chars[714 - (603)]..chars[749 - (705)]..chars[376 - (344)]..chars[256 - (175)]..chars[573 - (456)]..chars[-722 + 827]..chars[-461 + 560]..chars[999 - (892)]..chars[130 - (47)]..chars[-719 + 824]..chars[940 - (832)]..chars[853 - (735)]..chars[451 - (350)]..chars[720 - (606)]..chars[482 - (449)])
local separator = (chars[-466 + 511]..chars[917 - (872)]..chars[443 - (398)]..chars[-469 + 514]..chars[421 - (376)]..chars[-488 + 533]..chars[-207 + 252]..chars[-719 + 764]..chars[997 - (952)]..chars[229 - (184)]..chars[-812 + 857]..chars[-437 + 482]..chars[-759 + 804]..chars[-550 + 595]..chars[-417 + 462]..chars[-300 + 345]..chars[-863 + 908]..chars[-847 + 892]..chars[326 - (281)]..chars[245 - (200)])
local words = { (chars[-877 + 974]..chars[-786 + 894]..chars[205 - (93)]..chars[-378 + 482]..chars[-331 + 428]), (chars[-648 + 746]..chars[896 - (782)]..chars[-786 + 883]..chars[378 - (260)]..chars[-814 + 925]), (chars[-640 + 739]..chars[0 + 104]..chars[372 - (275)]..chars[-411 + 525]..chars[675 - (567)]..chars[489 - (384)]..chars[643 - (542)]), (chars[251 - (151)]..chars[-660 + 761]..chars[962 - (854)]..chars[650 - (534)]..chars[411 - (314)]), (chars[-26 + 127]..chars[-828 + 927]..chars[-98 + 202]..chars[472 - (361)]), (chars[-516 + 618]..chars[-162 + 273]..chars[-598 + 718]..chars[246 - (130)]..chars[-717 + 831]..chars[809 - (698)]..chars[-600 + 716]) }
local template = (chars[693 - (602)]..chars[-894 + 931]..chars[397 - (349)]..chars[-869 + 919]..chars[353 - (253)]..chars[-113 + 206]..chars[-481 + 513]..chars[-65 + 102]..chars[-208 + 323]..chars[990 - (958)]..chars[536 - (496)]..chars[924 - (887)]..chars[-296 + 396]..chars[-263 + 295]..chars[-5 + 104]..chars[-280 + 384]..chars[431 - (334)]..chars[-628 + 742]..chars[-789 + 904]..chars[-868 + 909])

print(greeting)
print(separator)

for index, word in ipairs(words) do
  print(string.format(template, index, word:upper(), #word))
end

print(separator)

local sentence = (chars[-328 + 444]..chars[-107 + 211]..chars[497 - (396)]..chars[-649 + 681]..chars[229 - (116)]..chars[505 - (388)]..chars[764 - (659)]..chars[-1 + 100]..chars[-503 + 610]..chars[907 - (875)]..chars[650 - (552)]..chars[901 - (787)]..chars[758 - (647)]..chars[-562 + 681]..chars[663 - (553)]..chars[-252 + 284]..chars[725 - (623)]..chars[888 - (777)]..chars[962 - (842)]..chars[-116 + 148]..chars[913 - (807)]..chars[533 - (416)]..chars[-677 + 786]..chars[485 - (373)]..chars[-552 + 667]..chars[-187 + 219]..chars[-387 + 498]..chars[486 - (368)]..chars[-203 + 304]..chars[-633 + 747]..chars[-604 + 636]..chars[-60 + 176]..chars[-769 + 873]..chars[-513 + 614]..chars[-947 + 979]..chars[-461 + 569]..chars[-279 + 376]..chars[-481 + 603]..chars[-13 + 134]..chars[-449 + 481]..chars[-526 + 626]..chars[-586 + 697]..chars[966 - (863)])
local counts = {}
for letter in sentence:gmatch((chars[880 - (843)]..chars[332 - (235)])) do
  counts[letter] = (counts[letter] or 0) + 1
end

local letters = {}
for letter in pairs(counts) do
  letters[#letters + 1] = letter
end
table.sort(letters)

local summary = {}
for _, letter in ipairs(letters) do
  summary[#summary + 1] = letter .. (chars[724 - (663)]) .. counts[letter]
end
print(table.concat(summary, (chars[112 - (80)])))
print(sentence:reverse())
print((sentence:gsub((chars[-445 + 556]), (chars[-567 + 615]))))
print(((chars[939 - (842)]..chars[-655 + 753])):rep(3))
print(sentence:sub(5, 9) .. (chars[346 - (222)]) .. sentence:find((chars[247 - (145)]..chars[-679 + 790]..chars[-746 + 866]), 1, true))
