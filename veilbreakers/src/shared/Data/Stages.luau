--!strict
-- Arena metadata. Geometry, props, lighting and particles are built by the client's
-- StageBuilder from the `theme` id; everything tunable lives here.

export type Stage = {
	id: string,
	name: string,
	realm: string,
	desc: string,
	theme: string,
	music: string,
	ambience: string,
	backdrop: string,
	accent: string,
	fogColor: string,
	ambient: string,
	clockTime: number,
	floorColor: string,
	floorMaterial: string,
	selectable: boolean,
}

local list: { Stage } = {
	{
		id = "hollowroot",
		name = "HOLLOWROOT MIRE",
		realm = "The Mire",
		desc = "A drowned primeval forest where spirit-fire drifts between dead giants.",
		theme = "forest",
		music = "music_battle_b",
		ambience = "amb_forest",
		backdrop = "Backdrop_hollowroot",
		accent = "#5BFF6A",
		fogColor = "#1C2A22",
		ambient = "#2A3A30",
		clockTime = 0.3,
		floorColor = "#2A2620",
		floorMaterial = "Mud",
		selectable = true,
	},
	{
		id = "skyreach",
		name = "SKYREACH MONASTERY",
		realm = "Skyreach",
		desc = "A cliffside temple courtyard above a sea of clouds, at the last light of dusk.",
		theme = "monastery",
		music = "music_battle_a",
		ambience = "amb_wind",
		backdrop = "Backdrop_skyreach",
		accent = "#FFB25A",
		fogColor = "#6A5A6E",
		ambient = "#4A3E48",
		clockTime = 17.9,
		floorColor = "#D8D4CE",
		floorMaterial = "Snow",
		selectable = true,
	},
	{
		id = "cathedral",
		name = "THE DROWNED CATHEDRAL",
		realm = "Moon-Lake",
		desc = "A sunken gothic nave flooded by a moonlit lake. The choir still sings below.",
		theme = "cathedral",
		music = "music_battle_b",
		ambience = "amb_cathedral",
		backdrop = "Backdrop_cathedral",
		accent = "#A86BFF",
		fogColor = "#151A2A",
		ambient = "#2A2A44",
		clockTime = 0.0,
		floorColor = "#2A2C33",
		floorMaterial = "Slate",
		selectable = true,
	},
	{
		id = "emberthrone",
		name = "THE EMBER THRONE",
		realm = "Ember Throne",
		desc = "The obsidian seat of the Hollow King, ringed by rivers of molten stone.",
		theme = "volcano",
		music = "music_boss",
		ambience = "amb_lava",
		backdrop = "Backdrop_emberthrone",
		accent = "#FF5A2E",
		fogColor = "#2A0E08",
		ambient = "#4A2418",
		clockTime = 0.0,
		floorColor = "#1C1714",
		floorMaterial = "Basalt",
		selectable = true,
	},
	{
		id = "proving",
		name = "THE PROVING GROUNDS",
		realm = "Between Realms",
		desc = "A quiet practice hall suspended in the space between the realms.",
		theme = "proving",
		music = "music_select",
		ambience = "",
		backdrop = "Backdrop_proving",
		accent = "#C9A24A",
		fogColor = "#101114",
		ambient = "#3A3A40",
		clockTime = 0.0,
		floorColor = "#1A1B1F",
		floorMaterial = "Slate",
		selectable = false,
	},
}

local Stages = {}
Stages.list = list
Stages.byId = {} :: { [string]: Stage }
Stages.selectable = {} :: { string }
for _, s in list do
	Stages.byId[s.id] = s
	if s.selectable then
		table.insert(Stages.selectable, s.id)
	end
end

function Stages.get(id: string): Stage
	local s = Stages.byId[id]
	assert(s, "unknown stage " .. tostring(id))
	return s
end

return Stages
