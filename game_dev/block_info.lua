--[[
    block_info.lua - what the guides say about which moves a block can / cannot stop. Pure data + a name matcher (no Roblox APIs).

      local kind, entry = BlockInfo.classify("Flowing Water")   -> "unblockable", {...}     (nil when the name is not listed)

    kinds:
      "unblockable"  ignores block completely (grabs, downslam, charged / unblockable moves)
      "guardbreak"   breaks / punishes a block - holding F is the wrong answer
      "chip"         damages through a block but does not break it
      "blockable"    a normal attack: F stops it
      "disputed"     guides contradict each other - treated like blockable (never skipped)

    Sources are fan guides and a fan wiki (TSB is patched often, some pages are machine translated). Every entry
    carries a confidence ("medium" = at least two guides or the wiki, "low" = one guide). Nothing here is read from
    the game; the hub also LEARNS which attacks ignore your block from the hits you actually take.
    Matching is by the animation's name (letters only, case ignored), longest entry first.
]]

local M = {}

-- {name, kind, who, confidence}
M.entries = {
    -- universal
    {"Downslam", "unblockable", "Universal", "medium"},               -- aerial M1 finisher bypasses block
    {"Ragdoll Cancel", "unblockable", "Universal", "medium"},          -- the direct hit, ~20%, no cooldown, large range
    {"Shove", "unblockable", "Universal", "medium"},                   -- wiki: breaks through block
    {"Uppercut", "unblockable", "Universal", "medium"},                -- wiki: breaks through block
    -- The Strongest Hero (Saitama)
    {"Normal Punch", "unblockable", "The Strongest Hero", "medium"},   -- unblockable on a direct hit / up close
    {"Consecutive Punches", "blockable", "The Strongest Hero", "low"},
    -- Hero Hunter (Garou)
    {"Flowing Water", "guardbreak", "Hero Hunter", "medium"},          -- guardbreak / unblockable advancing rush
    {"Hunter's Grasp", "unblockable", "Hero Hunter", "medium"},        -- armoured grab
    {"Lethal Whirlwind Stream", "disputed", "Hero Hunter", "low"},     -- guides contradict (unblockable AoE vs guardable)
    {"Crushed Rock", "unblockable", "Hero Hunter", "medium"},          -- rampage move, advancing grab
    -- Brutal Demon (Metal Bat): the block-breakers
    {"Homerun", "guardbreak", "Brutal Demon", "medium"},
    {"Grand Slam", "guardbreak", "Brutal Demon", "medium"},
    {"Foul Ball", "guardbreak", "Brutal Demon", "medium"},
    -- Blade Master (Atomic Samurai)
    {"Pinpoint Cut", "blockable", "Blade Master", "medium"},
    -- Destructive Cyborg (Genos): most base moves are blockable, chip damage still gets through
    {"Machine Gun Blows", "chip", "Destructive Cyborg", "low"},
    {"Blitz Shot", "blockable", "Destructive Cyborg", "low"},
    -- Martial Artist (Suiryu)
    {"Vanishing Kick", "unblockable", "Martial Artist", "medium"},
    {"Head First", "unblockable", "Martial Artist", "medium"},         -- damage only reduced by blocking
    {"Grand Fissure", "unblockable", "Martial Artist", "medium"},
    {"Twin Fangs", "unblockable", "Martial Artist", "medium"},
    {"Earth Splitting Strike", "unblockable", "Martial Artist", "medium"},
    {"Last Breath", "unblockable", "Martial Artist", "medium"},
    {"Whirlwind Drop", "chip", "Martial Artist", "medium"},            -- hits through guard without breaking it
    -- event characters
    {"Grave Maker", "unblockable", "Undying Hero", "low"},
    {"Pincer Barrage", "unblockable", "Crab Boss", "low"},
}

local function normalize(s)
    if type(s) ~= "string" then return nil end
    local n = s:lower():gsub("[^a-z]", "")
    return n ~= "" and n or nil
end
M.normalize = normalize

-- longest key first, so "ragdoll cancel" is not shadowed by a shorter one
local index
local function build()
    index = {}
    for _, e in ipairs(M.entries) do
        local key = normalize(e[1])
        if key then index[#index + 1] = {key = key, entry = {name = e[1], kind = e[2], who = e[3], confidence = e[4]}} end
    end
    table.sort(index, function(a, b)
        if #a.key ~= #b.key then return #a.key > #b.key end
        return a.key < b.key
    end)
end

function M.classify(label)
    local n = normalize(label)
    if not n then return nil end
    if not index then build() end
    for _, it in ipairs(index) do
        if n:find(it.key, 1, true) then return it.entry.kind, it.entry end
    end
    return nil
end

-- kinds that make holding F pointless (or worse)
function M.ignoresBlock(kind) return kind == "unblockable" or kind == "guardbreak" end

return M
