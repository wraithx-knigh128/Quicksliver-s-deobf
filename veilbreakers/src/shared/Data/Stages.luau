--!nonstrict
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
		name = "THE SPOOKY OBBY FOREST",
		realm = "Horror Game Lobby",
		desc = "A haunted forest from a horror game that never got finished. The trees have glowing eyes. Nobody added collisions.",
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
		name = "ANIME DOJO SIMULATOR",
		realm = "Anime Fighting Sim",
		desc = "A snowy mountain dojo where everyone shouts their attack names. Rebirth required to enter.",
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
		name = "FLOODED CHURCH ESCAPE",
		realm = "Flood Escape Map",
		desc = "The water is rising, the choir is still singing, and nobody pressed the button.",
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
		name = "THE ADMIN'S LAVA THRONE",
		realm = "The Floor Is Lava",
		desc = "The Admin's private throne room. The floor is lava. He typed that in on purpose.",
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
		id = "baseplate",
		name = "THE BASEPLATE",
		realm = "Every Game Ever (At First)",
		desc = "Gray. Flat. Infinite. Where every great game began, and where most of them were abandoned.",
		theme = "baseplate",
		music = "music_battle_a",
		ambience = "amb_wind",
		backdrop = "Backdrop_baseplate",
		accent = "#A3A2A5",
		fogColor = "#B9D7F2",
		ambient = "#8A8C92",
		clockTime = 14.0,
		floorColor = "#A3A2A5",
		floorMaterial = "SmoothPlastic",
		selectable = true,
	},
	{
		id = "proving",
		name = "THE TRAINING ROOM",
		realm = "Studio Test Mode",
		desc = "A quiet practice room that only exists when you press Play Solo.",
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
