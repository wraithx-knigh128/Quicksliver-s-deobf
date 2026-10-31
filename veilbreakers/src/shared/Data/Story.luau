--!strict
-- Story Mode: "Chapter I - The Sundered Veil".
-- A chapter is a list of beats: cinematic scenes (in-engine, letterboxed, subtitled)
-- and fights. Camera shots are authored as presets relative to the actors so the
-- CutscenePlayer can frame them on any stage.

export type Line = { speaker: string, text: string, voice: string? }

export type Shot = {
	cam: string, -- wide | two | close | over | sky | low | pan
	a: number?,
	b: number?,
	duration: number?,
	lines: { Line }?,
	caption: string?,
	events: { { [string]: any } }?,
}

export type Scene = {
	type: string, -- "scene" | "fight"
	stage: string,
	actors: { { id: string, x: number, facing: number, anim: string?, hidden: boolean? } }?,
	shots: { Shot }?,
	-- fight fields
	player: string?,
	playerEcho: string?,
	opponent: string?,
	opponentEcho: string?,
	difficulty: number?,
	boss: boolean?,
	title: string?,
}

local Story = {}

Story.chapters = {
	{
		id = "ch1",
		number = "CHAPTER I",
		name = "THE SUNDERED VEIL",
		synopsis = "The sky over Skyreach tears open on the night of the autumn festival. Something has been waiting on the other side.",
		beats = {
			{
				type = "scene",
				stage = "skyreach",
				actors = {
					{ id = "raiken", x = -2.5, facing = 1, anim = "stance" },
					{ id = "seraphine", x = 2.5, facing = -1, anim = "stance" },
					{ id = "nyx", x = 0, facing = -1, anim = "stance", hidden = true },
				},
				shots = {
					{
						cam = "sky",
						duration = 4.5,
						caption = "SKYREACH MONASTERY  \u{2014}  THE LAST NIGHT OF THE AUTUMN FESTIVAL",
					},
					{
						cam = "two",
						a = 1,
						b = 2,
						lines = {
							{ speaker = "seraphine", text = "Your guard drops every time you breathe, Raiken." },
							{ speaker = "raiken", text = "Then I'll stop breathing." },
							{ speaker = "seraphine", text = "The abbot says the storm spirits have been restless all day." },
							{
								speaker = "raiken",
								text = "They've been restless for a month. Something is pressing against the Veil.",
							},
						},
					},
					{
						cam = "sky",
						duration = 3.4,
						events = { { t = 0.4, type = "vfx", kind = "rift" }, { t = 0.4, type = "sfx", key = "lightning_crack" } },
						lines = { { speaker = "seraphine", text = "Spirits preserve us... the sky is splitting open." } },
					},
					{
						cam = "wide",
						events = {
							{ t = 0.2, type = "show", actor = 3 },
							{ t = 0.2, type = "vfx", kind = "teleport", actor = 3 },
							{ t = 0.2, type = "sfx", key = "teleport" },
							{ t = 0.3, type = "anim", actor = 1, anim = "stance" },
						},
						lines = { { speaker = "nyx", text = "Shhh. The King is listening." } },
					},
					{
						cam = "close",
						a = 1,
						lines = { { speaker = "raiken", text = "Who sent you?" } },
					},
					{
						cam = "close",
						a = 3,
						lines = {
							{
								speaker = "nyx",
								text = "The one who wears the Ember Crown. He wants your monastery's seals... and your storm, little ronin.",
							},
						},
					},
					{
						cam = "over",
						a = 1,
						b = 3,
						lines = {
							{ speaker = "raiken", text = "Then he can come and take it himself." },
							{ speaker = "nyx", text = "He did. He sent me." },
						},
					},
				},
			},
			{
				type = "fight",
				title = "RAIKEN  VS  NYX",
				stage = "skyreach",
				player = "raiken",
				playerEcho = "okoro",
				opponent = "nyx",
				opponentEcho = "talon",
				difficulty = 1,
			},
			{
				type = "scene",
				stage = "skyreach",
				actors = {
					{ id = "raiken", x = -2.2, facing = 1, anim = "stance" },
					{ id = "nyx", x = 2.2, facing = -1, anim = "dazed" },
					{ id = "seraphine", x = -5.5, facing = 1, anim = "stance" },
				},
				shots = {
					{
						cam = "close",
						a = 2,
						lines = { { speaker = "nyx", text = "...The choir will remember your voice, ronin." } },
						events = {
							{ t = 2.6, type = "vfx", kind = "teleport", actor = 2 },
							{ t = 2.6, type = "hide", actor = 2 },
							{ t = 2.6, type = "sfx", key = "teleport" },
						},
						duration = 3.4,
					},
					{
						cam = "two",
						a = 3,
						b = 1,
						lines = {
							{ speaker = "seraphine", text = "She fled into the rift. It leads down into the Hollowroot Mire." },
							{
								speaker = "seraphine",
								text = "If something comes through there, the Warden will think we sent it.",
							},
							{ speaker = "raiken", text = "Then we go before it closes." },
						},
					},
				},
			},
			{
				type = "scene",
				stage = "hollowroot",
				actors = {
					{ id = "seraphine", x = -2.4, facing = 1, anim = "stance" },
					{ id = "raiken", x = -5.2, facing = 1, anim = "stance" },
					{ id = "morrgath", x = 3.0, facing = -1, anim = "stance", hidden = true },
				},
				shots = {
					{ cam = "sky", duration = 4.2, caption = "HOLLOWROOT MIRE  \u{2014}  WHERE THE OLD GIANTS SLEEP" },
					{
						cam = "wide",
						events = {
							{ t = 0.3, type = "show", actor = 3 },
							{ t = 0.3, type = "vfx", kind = "roots", actor = 3 },
							{ t = 0.3, type = "sfx", key = "roots" },
							{ t = 0.4, type = "shake", amount = 0.6 },
						},
						lines = { { speaker = "morrgath", text = "Outsiders. The sky tore open... and you crawled out of the wound." } },
					},
					{
						cam = "close",
						a = 1,
						lines = { { speaker = "seraphine", text = "Warden, wait! We are hunting the one who opened it!" } },
					},
					{
						cam = "low",
						a = 3,
						lines = { { speaker = "morrgath", text = "Every thief says so. The Mire will judge you." } },
					},
					{
						cam = "two",
						a = 2,
						b = 1,
						lines = {
							{ speaker = "seraphine", text = "Stand back, Raiken. I'll speak to him in a language he respects." },
						},
					},
				},
			},
			{
				type = "fight",
				title = "SERAPHINE  VS  MORRGATH",
				stage = "hollowroot",
				player = "seraphine",
				playerEcho = "ilsa",
				opponent = "morrgath",
				opponentEcho = "warden",
				difficulty = 2,
			},
			{
				type = "scene",
				stage = "hollowroot",
				actors = {
					{ id = "seraphine", x = -2.4, facing = 1, anim = "stance" },
					{ id = "morrgath", x = 2.6, facing = -1, anim = "kneel" },
					{ id = "raiken", x = -5.2, facing = 1, anim = "stance" },
				},
				shots = {
					{
						cam = "close",
						a = 2,
						lines = {
							{ speaker = "morrgath", text = "...You fight without hatred. Thieves fight with nothing else." },
							{
								speaker = "morrgath",
								text = "The one you seek is Aurel Mor. The Hollow King. He burned a kingdom to feed the fire in his crown.",
							},
						},
					},
					{
						cam = "two",
						a = 1,
						b = 2,
						lines = {
							{ speaker = "seraphine", text = "Then the fall of my order... it was him." },
							{
								speaker = "morrgath",
								text = "His road runs through the Drowned Cathedral. I will walk it with you.",
							},
						},
					},
				},
			},
			{
				type = "scene",
				stage = "cathedral",
				actors = {
					{ id = "morrgath", x = -2.6, facing = 1, anim = "stance" },
					{ id = "vesper", x = 3.2, facing = -1, anim = "stance", hidden = true },
					{ id = "raiken", x = -6.0, facing = 1, anim = "stance" },
				},
				shots = {
					{ cam = "sky", duration = 4.2, caption = "THE DROWNED CATHEDRAL  \u{2014}  BENEATH THE MOON-LAKE" },
					{
						cam = "wide",
						events = {
							{ t = 0.5, type = "sfx", key = "crossbow" },
							{ t = 0.7, type = "vfx", kind = "bolt_impact", actor = 1 },
							{ t = 0.9, type = "show", actor = 2 },
							{ t = 0.9, type = "vfx", kind = "smoke", actor = 2 },
						},
						lines = {
							{ speaker = "vesper", text = "That's far enough. The King paid for you, Warden. In advance." },
						},
					},
					{
						cam = "close",
						a = 2,
						lines = { { speaker = "vesper", text = "Nothing personal. I just never refund." } },
					},
					{
						cam = "low",
						a = 1,
						lines = { { speaker = "morrgath", text = "Go on ahead, ronin. The hunter is mine." } },
					},
				},
			},
			{
				type = "fight",
				title = "MORRGATH  VS  VESPER",
				stage = "cathedral",
				player = "morrgath",
				playerEcho = "warden",
				opponent = "vesper",
				opponentEcho = "talon",
				difficulty = 2,
			},
			{
				type = "scene",
				stage = "cathedral",
				actors = {
					{ id = "morrgath", x = -2.4, facing = 1, anim = "stance" },
					{ id = "vesper", x = 2.6, facing = -1, anim = "kneel" },
				},
				shots = {
					{
						cam = "close",
						a = 2,
						lines = {
							{
								speaker = "vesper",
								text = "...Fine. Contract's void. He never mentioned you hit like a landslide.",
							},
							{
								speaker = "vesper",
								text = "His throne lies past the ember gate. You'll want a guide. I'll take my fee in his crown.",
							},
						},
					},
					{
						cam = "two",
						a = 1,
						b = 2,
						lines = { { speaker = "morrgath", text = "Then we hunt together, little hunter." } },
					},
				},
			},
			{
				type = "scene",
				stage = "emberthrone",
				actors = {
					{ id = "raiken", x = -3.4, facing = 1, anim = "stance" },
					{ id = "hollowking", x = 3.6, facing = -1, anim = "stance" },
				},
				shots = {
					{ cam = "sky", duration = 4.4, caption = "THE EMBER THRONE  \u{2014}  SEAT OF THE HOLLOW KING" },
					{
						cam = "low",
						a = 2,
						lines = {
							{
								speaker = "hollowking",
								text = "Storm-bearer. Lancer. Warden. Hunter. You have brought me quite a feast.",
							},
						},
					},
					{
						cam = "close",
						a = 1,
						lines = { { speaker = "raiken", text = "We came to close the Veil. Through you, if we must." } },
					},
					{
						cam = "over",
						a = 1,
						b = 2,
						lines = {
							{
								speaker = "hollowking",
								text = "We are a kingdom of a thousand souls. You are a single candle in the wind.",
							},
							{ speaker = "raiken", text = "Then let's see how your kingdom handles a storm." },
						},
					},
				},
			},
			{
				type = "fight",
				title = "RAIKEN  VS  THE HOLLOW KING",
				stage = "emberthrone",
				player = "raiken",
				playerEcho = "okoro",
				opponent = "hollowking",
				opponentEcho = "warden",
				difficulty = 3,
				boss = true,
			},
			{
				type = "scene",
				stage = "emberthrone",
				actors = {
					{ id = "raiken", x = -2.4, facing = 1, anim = "stance" },
					{ id = "hollowking", x = 2.4, facing = -1, anim = "kneel" },
					{ id = "seraphine", x = -6.0, facing = 1, anim = "stance" },
				},
				shots = {
					{
						cam = "close",
						a = 2,
						lines = { { speaker = "hollowking", text = "Impossible... the souls... they are leaving me..." } },
						events = { { t = 0.5, type = "vfx", kind = "souls", actor = 2 } },
					},
					{
						cam = "two",
						a = 3,
						b = 1,
						lines = {
							{ speaker = "seraphine", text = "The rift is collapsing! Raiken, the seal, now!" },
							{ speaker = "raiken", text = "Storm, hear me. Close the door." },
						},
					},
					{
						cam = "sky",
						duration = 4.0,
						events = {
							{ t = 0.4, type = "vfx", kind = "flash" },
							{ t = 0.4, type = "sfx", key = "lightning_crack" },
							{ t = 0.4, type = "shake", amount = 1.0 },
							{ t = 0.6, type = "hide", actor = 2 },
						},
						caption = "THE VEIL HOLDS.  FOR NOW.",
					},
					{
						cam = "wide",
						duration = 5.0,
						lines = {
							{
								speaker = "nyx",
								text = "...The King was only one voice, ronin. The choir is so much larger.",
							},
						},
					},
				},
			},
		},
	},
}

Story.speakerNames = {
	raiken = "RAIKEN",
	seraphine = "SERAPHINE",
	morrgath = "MORRGATH",
	nyx = "NYX",
	torvald = "TORVALD",
	zhura = "ZHURA",
	vesper = "VESPER",
	hollowking = "THE HOLLOW KING",
	okoro = "BROTHER OKORO",
	ilsa = "ILSA",
	warden = "THE LANTERN WARDEN",
	talon = "GRIM TALON",
}

-- Seconds a subtitle stays on screen.
function Story.lineDuration(text: string): number
	return math.clamp(1.4 + #text * 0.055, 2.2, 7.5)
end

return Story
