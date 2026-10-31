-- Dumps bone boxes for a set of poses as JSON (consumed by tools/pose_preview.py).
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local process = require("@lune/process")
local Loader = require("../tests/loader")
Loader.addGlobals({ CFrame = roblox.CFrame, Vector3 = roblox.Vector3 })
local client = Loader.root("src/client")
local RigMath = Loader.require(client.Render.RigMath)
local Poses = Loader.require(client.Render.Poses)

local sk = RigMath.skeleton(1, 1)
local list = {}
local function add(label, pose)
	local out = RigMath.solve(sk, roblox.CFrame.identity, pose)
	local bones = {}
	for _, name in sk.order do
		local cf = out[name]
		local c = { cf:GetComponents() }
		local sz = sk.bones[name].size
		table.insert(bones, { name = name, cf = c, size = { sz.X, sz.Y, sz.Z } })
	end
	table.insert(list, { label = label, bones = bones })
end

local which = process.args[1] or "states"
if which == "states" then
	for _, st in { "unarmed", "blade", "pole", "heavy", "dual", "ranged" } do
		add("stance_" .. st, Poses.stance(st))
	end
	add("walk0", Poses.walk("unarmed", 0.0, 1))
	add("walk90", Poses.walk("unarmed", math.pi / 2, 1))
	add("block", Poses.States.block("unarmed"))
	add("crouch", Poses.States.crouch("unarmed"))
	add("crouch_block", Poses.States.crouch_block("unarmed"))
	add("jump", Poses.States.jump("unarmed"))
	add("hit_high", Poses.States.hit_high())
	add("hit_mid", Poses.States.hit_mid())
	add("juggle", Poses.States.juggle())
	add("lie", Poses.States.lie())
	add("dazed", Poses.States.dazed())
	add("kneel", Poses.States.kneel())
	add("win_blade", Poses.WIN.blade)
	add("win_heavy", Poses.WIN.heavy)
else
	local names = {}
	for k in Poses.Attacks do table.insert(names, k) end
	table.sort(names)
	local from = tonumber(process.args[2]) or 1
	local to = math.min(#names, from + 17)
	for i = from, to do
		local n = names[i]
		local def = Poses.Attacks[n]
		add(n .. ":wind", def.wind)
		add(n .. ":hit", def.hit)
	end
end
fs.writeFile("/tmp/poses.json", serde.encode("json", list))
print("wrote", #list)
