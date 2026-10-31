-- Builds every fighter / echo rig through the real Rig module (Lune Instances) and
-- dumps part boxes + colours for tools/rig_preview.py.
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local process = require("@lune/process")
local Loader = require("../tests/loader")
Loader.addGlobals({
	CFrame = roblox.CFrame,
	Vector3 = roblox.Vector3,
	Color3 = roblox.Color3,
	Instance = roblox.Instance,
	Enum = roblox.Enum,
	ColorSequence = roblox.ColorSequence,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	UDim2 = roblox.UDim2,
	Font = roblox.Font,
	workspace = roblox.Instance.new("Model"),
})
local shared = Loader.root("src/shared")
local client = Loader.root("src/client")
local Fighters = Loader.require(shared.Data.Fighters)
local Echoes = Loader.require(shared.Data.Echoes)
local Rig = Loader.require(client.Render.Rig)
local Poses = Loader.require(client.Render.Poses)

local which = process.args[1] or "stance"
local list = {}
local function dumpRig(label, look, pose)
	local rig = Rig.build(look, { world = roblox.Instance.new("Model") })
	Rig.apply(rig, roblox.CFrame.identity, pose, { time = 0.3, vx = 0, vy = 0 })
	local parts = {}
	for _, p in rig.allParts do
		local c = { p.CFrame:GetComponents() }
		local col = p.Color
		local shape = "Block"
		if p:IsA("Part") then
			shape = p.Shape.Name
		end
		if p:FindFirstChildOfClass("SpecialMesh") then
			shape = "Head"
		end
		table.insert(parts, {
			cf = c,
			size = { p.Size.X, p.Size.Y, p.Size.Z },
			color = { col.R, col.G, col.B },
			mat = p.Material.Name,
			shape = shape,
			wedge = p.ClassName == "WedgePart",
			t = p.Transparency,
		})
	end
	table.insert(list, { label = label, parts = parts, count = #rig.allParts })
end
for _, f in Fighters.list do
	local style = Poses.STYLE_OF[f.stance] or "unarmed"
	local pose = Poses.stance(style)
	if which == "win" then
		pose = Poses.WIN[style]
	elseif which == "attack" then
		local m = f.moves.H
		pose = Poses.attack(m.anim, style, m.startup + 1, m.startup, m.active, m.recovery)
	end
	dumpRig(f.name, f.look, pose)
end
if which == "stance" then
	for _, e in Echoes.list do
		dumpRig(e.name, e.look, Poses.stance("unarmed"))
	end
end
fs.writeFile("/tmp/rigs.json", serde.encode("json", list))
print("rigs", #list)
