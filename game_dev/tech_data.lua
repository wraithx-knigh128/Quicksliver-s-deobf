--[[
    tech_data.lua - what the Tech Lab knows about the game, as plain data (no Roblox APIs, unit-tested).

    EVERY id, move name and remote layout in this file comes from the Strongest Battlegrounds script you uploaded (Dovi's Hub) - I read it, I did not run it in the
    game, and TSB is patched often, so an id can go stale. When a tech stops reacting, its trigger animation id is the first suspect: the Tech Lab tab can learn
    a new one ("Learn trigger") and every id below can be extended from the config.

      TechData.ANIM.<name>            lists of animation ids (digits only, as strings)
      TechData.set(list)              {[id] = true}
      TechData.idOf(animationId)      "rbxassetid://123" -> "123" (nil when there are no digits)
      TechData.dashKind(id)           "forward" | "side" | nil
      TechData.dashArgs(K, "W")       the Communicate remote's argument tables (K = Enum.KeyCode, so this file stays pure)
      TechData.clickArgs(down) / blockArgs(K, down) / moveArgs(tool)
      TechData.toolMatches(name, wanted)   tool names are compared by their letters only (case, spaces and punctuation ignored)
]]

local M = {}

M.ANIM = {
    uppercut        = {"10503381238", "13379003796"},          -- the uppercut: Supa / Loop Dash / Kiba start from it
    forwardDash     = {"10479335397", "13380255751"},          -- the forward dash (also what Dash Flip and Mouse Dash react to)
    sideRight       = {"10480793962"},                          -- side dash to the right
    sideLeft        = {"10480796021"},                          -- side dash to the left
    flowingWater    = {"12273188754"},                          -- Garou's Flowing Water (Kyoto starts from it)
    lethalWhirlwind = {"12296113986"},                          -- Lethal Whirlwind Stream (Lethal Dash / Lethal Dunk start from it)
    twisted         = {"13294471966"},                          -- the move Twisted starts from
    block           = {"10471478869"},                          -- somebody is blocking
    downslamWarning = {"10470389827"},                          -- the telegraph of the unblockable down slam
    surf            = {"12309835105"},                          -- Hunter's surf
    counterDash     = {"10479335397", "13380255751", "134775406437626"},     -- dashes Auto Counter answers
    counterM1       = {"10469493270", "10469630950", "10469639222", "10469643643"},   -- M1 swings Auto Counter answers
    counterMove     = {"12351854556", "15311685628", "78521642007560"},     -- the animations of the counter moves (Counter ESP; your script listed three more that are no valid ids)
    slam            = {"10469639222", "13532604085", "13295919399", "13378751717", "14001963401", "15240176873", "16515448089", "17889471098", "104895379416342"},
    m1 = {"10469493270", "10469630950", "10469639222", "10469643643", "13532562418", "13532600125", "13532604085", "13294471966", "13491635433", "13296577783",
          "13295919399", "13295936866", "13370310513", "13390230973", "13378751717", "13378708199", "14004222985", "13997092940", "14001963401", "14136436157",
          "15259161390", "15240216931", "15240176873", "15162694192", "16515503507", "16515520431", "16515448089", "16552234590", "17889458563", "17889461810",
          "17889471098", "17889290569", "123005629431309", "100059874351664", "104895379416342"},
}

M.TOOLS = {
    lethal = {"Lethal Whirlwind Stream"},
    counters = {"Prey's Peril", "Split Second Counter"},
    grasp = {"Hunter's Grasp", "Hunterzzzzz's Grasp"},
    shove = {"Shove"},
}

-- hotbar slots 1-4 are the four moves (Enum.KeyCode names)
M.HOTBAR = {"One", "Two", "Three", "Four"}

-- named highlight colours for the Awareness techs (0-255)
M.COLORS = {Red = {255, 60, 60}, Orange = {255, 150, 40}, Yellow = {255, 220, 60}, Green = {80, 220, 120}, Cyan = {60, 220, 255}, Blue = {70, 130, 255},
            Purple = {170, 100, 255}, White = {240, 240, 240}}
M.COLOR_NAMES = {"Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Purple", "White"}

-- dash cooldowns in seconds (from the script: forward 4.8; the side dash figure is the community number and unverified)
M.DASH_COOLDOWN = {forward = 4.8, side = 2.0}

function M.set(list)
    local out = {}
    for _, id in ipairs(list or {}) do out[tostring(id)] = true end
    return out
end

function M.idOf(animationId)
    if type(animationId) ~= "string" then return nil end
    return animationId:match("%d+")
end

local DASH = {}
for _, id in ipairs(M.ANIM.forwardDash) do DASH[id] = "forward" end
for _, id in ipairs(M.ANIM.sideRight) do DASH[id] = "side" end
for _, id in ipairs(M.ANIM.sideLeft) do DASH[id] = "side" end
function M.dashKind(id) return DASH[id] end

-- the Communicate remote (a RemoteEvent inside your character). K = Enum.KeyCode
function M.dashArgs(K, dir) return {Dash = K[dir], Key = K.Q, Goal = "KeyPress"} end
function M.clickArgs(down) return {Mobile = true, Goal = down and "LeftClick" or "LeftClickRelease"} end
function M.blockArgs(K, down) return {Goal = down and "KeyPress" or "KeyRelease", Key = K.F} end
function M.moveArgs(tool) return {Tool = tool, Goal = "Console Move"} end

local function letters(s) return (tostring(s or ""):lower():gsub("[^%a]", "")) end
function M.toolMatches(name, wanted) return letters(name) ~= "" and letters(name) == letters(wanted) end

return M
