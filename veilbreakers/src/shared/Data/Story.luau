--!nonstrict
-- Story Mode: "Chapter I - The Great Server Reset".
-- A chapter is a list of beats: cinematic scenes (in-engine, letterboxed, subtitled)
-- and fights. Camera shots are authored as presets relative to the actors so the
-- CutscenePlayer can frame them on any stage.

-- Lines may also carry editing beats (Cutscene.luau): gesture, cam / a / b (cut to
-- a specific angle), whip, crash, impact, pop (+ popX / popY), freeze
-- (+ freezeName / freezeSub), holdGesture.
export type Line = { speaker: string, text: string, voice: string?, [string]: any }

export type Shot = {
	cam: string, -- wide | two | close | over | sky | low | crash | dutch | orbit | dolly | track
	auto: boolean?, -- false disables automatic dialogue coverage cuts
	whip: boolean?, -- whip-pan into this shot
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
		name = "THE GREAT SERVER RESET",
		synopsis = "The Admin has typed ;shutdown. Every tycoon, every obby, every 400-Robux pair of wings is about to be deleted. Only a Noob stands in his way. This is fine.",
		beats = {
			{
				type = "scene",
				stage = "skyreach",
				actors = {
					{ id = "noob", x = -2.5, facing = 1, anim = "stance" },
					{ id = "bacon", x = 2.5, facing = -1, anim = "stance" },
					{ id = "guest", x = 0, facing = -1, anim = "stance", hidden = true },
				},
				shots = {
					{
						cam = "sky",
						duration = 4.5,
						caption = "ANIME DOJO SIMULATOR  \u{2014}  SERVER UPTIME: 847 DAYS",
					},
					{
						cam = "two",
						a = 1,
						b = 2,
						events = {
							{ t = 0.3, type = "act", actor = 2, anim = "thrust", time = 0.8 },
							{ t = 1.4, type = "act", actor = 1, anim = "slash_diag", time = 0.7 },
						},
						lines = {
							{ speaker = "bacon", text = "Your guard drops every time you check your phone, Noob." },
							{ speaker = "noob", text = "I'm not checking my phone. I'm AFK. I fight better AFK.", gesture = "cross", pop = "SKILL ISSUE?", popX = 0.72, popY = 0.32 },
							{ speaker = "bacon", text = "The chat's been weird all day. People keep typing 'it's happening'.", gesture = "think" },
							{ speaker = "noob", text = "Probably another free Robux scam. ...Probably.", gesture = "nervous" },
						},
					},
					{
						cam = "sky",
						duration = 3.4,
						whip = true,
						events = {
							{ t = 0.4, type = "vfx", kind = "rift" },
							{ t = 0.4, type = "sfx", key = "lightning_crack" },
							{ t = 0.4, type = "boom" },
							{ t = 1.5, type = "pop", text = "ERROR 277", x = 0.5, y = 0.3, color = "#FF4A4A" },
						},
						lines = { { speaker = "bacon", text = "Uh. Why is the sky... buffering?" } },
					},
					{
						cam = "wide",
						events = {
							{ t = 0.2, type = "show", actor = 3 },
							{ t = 0.2, type = "vfx", kind = "teleport", actor = 3 },
							{ t = 0.2, type = "sfx", key = "teleport" },
							{ t = 0.25, type = "impact", count = 2 },
							{ t = 0.6, type = "act", actor = 1, anim = "parry_stance", time = 0.9 },
							{ t = 0.6, type = "jump", actor = 2 },
							{ t = 0.9, type = "cam", cam = "dolly", a = 3 },
							{ t = 1.3, type = "freeze", actor = 3 },
						},
						lines = { { speaker = "system", text = "Guest 666 has joined the game." } },
					},
					{
						cam = "close",
						a = 1,
						lines = { { speaker = "noob", text = "Guests were removed years ago. How are you even here?", pop = "???", popX = 0.3, popY = 0.3 } },
					},
					{
						cam = "dutch",
						a = 3,
						lines = {
							{ speaker = "guest", text = "The Admin sends his regards. He's shutting the server down. And he wants your sword.", gesture = "point" },
						},
					},
					{
						cam = "over",
						a = 1,
						b = 3,
						lines = {
							{ speaker = "noob", text = "It's a free gear. He can literally just get one.", gesture = "shrug" },
							{ speaker = "guest", text = "He wants YOURS.", cam = "crash", a = 3, crash = true, impact = true, gesture = "point" },
						},
					},
				},
			},
			{
				type = "fight",
				title = "THE NOOB  VS  GUEST 666",
				stage = "skyreach",
				player = "noob",
				playerEcho = "grandpa",
				opponent = "guest",
				opponentEcho = "pigeon",
				difficulty = 1,
			},
			{
				type = "scene",
				stage = "skyreach",
				actors = {
					{ id = "noob", x = -2.2, facing = 1, anim = "stance" },
					{ id = "guest", x = 2.2, facing = -1, anim = "dazed" },
					{ id = "bacon", x = -5.5, facing = 1, anim = "stance" },
				},
				shots = {
					{
						cam = "close",
						a = 2,
						lines = { { speaker = "system", text = "Guest 666 has left the game." } },
						events = {
							{ t = 1.6, type = "vfx", kind = "teleport", actor = 2 },
							{ t = 1.6, type = "hide", actor = 2 },
							{ t = 1.6, type = "sfx", key = "teleport" },
						},
						duration = 3.0,
					},
					{
						cam = "two",
						a = 3,
						b = 1,
						events = { { t = 0.2, type = "walk", actor = 3, to = -4.4, time = 1.1 } },
						lines = {
							{ speaker = "bacon", text = "It glitched into the forest map. The one nobody finished building." },
							{ speaker = "bacon", text = "If the Admin shuts the server down, I lose my wings. My four hundred Robux wings.", gesture = "sad", pop = "-400 ROBUX", popX = 0.3, popY = 0.3 },
							{ speaker = "noob", text = "Then we stop him before the timer hits zero. Let's go.", gesture = "fist", cam = "dolly", a = 2 },
						},
					},
				},
			},
			{
				type = "scene",
				stage = "hollowroot",
				actors = {
					{ id = "bacon", x = -9.4, facing = 1, anim = "stance" },
					{ id = "noob", x = -12.2, facing = 1, anim = "stance" },
					{ id = "studzilla", x = 3.0, facing = -1, anim = "stance", hidden = true },
				},
				shots = {
					{ cam = "sky", duration = 4.2, caption = "THE SPOOKY OBBY FOREST  \u{2014}  COLLISIONS: OFF" },
					{
						cam = "track",
						a = 1,
						duration = 2.8,
						events = {
							{ t = 0, type = "walk", actor = 1, to = -2.4, time = 2.6 },
							{ t = 0, type = "walk", actor = 2, to = -5.2, time = 2.7 },
						},
					},
					{
						cam = "wide",
						events = {
							{ t = 0.3, type = "show", actor = 3 },
							{ t = 0.3, type = "vfx", kind = "roots", actor = 3 },
							{ t = 0.3, type = "sfx", key = "ground_slam" },
							{ t = 0.35, type = "impact", count = 3 },
							{ t = 0.4, type = "shake", amount = 0.6 },
						},
						lines = {
							{ speaker = "studzilla", text = "WHO. DARES. ENTER. MY. UNFINISHED. MAP.", cam = "low", a = 3, crash = true, freeze = true },
						},
					},
					{
						cam = "close",
						a = 1,
						lines = { { speaker = "bacon", text = "Whoa, big guy! We're not here to grief your build!", gesture = "nervous" } },
					},
					{
						cam = "low",
						a = 3,
						events = {
							{ t = 1.6, type = "act", actor = 3, anim = "ground_pound", time = 0.9 },
							{ t = 2.05, type = "vfx", kind = "slam", actor = 3 },
							{ t = 2.05, type = "boom" },
							{ t = 2.05, type = "speedlines", time = 0.5 },
						},
						lines = { { speaker = "studzilla", text = "EVERYONE. SAYS. THAT. THEN. THEY. DELETE. MY. BRICKS." } },
					},
					{
						cam = "two",
						a = 2,
						b = 1,
						events = { { t = 2.2, type = "walk", actor = 1, to = -0.8, time = 0.8 } },
						lines = {
							{ speaker = "bacon", text = "Stand back, Noob. I speak fluent block.", gesture = "cross" },
						},
					},
				},
			},
			{
				type = "fight",
				title = "BACON HAIR  VS  STUDZILLA",
				stage = "hollowroot",
				player = "bacon",
				playerEcho = "dana",
				opponent = "studzilla",
				opponentEcho = "nightguard",
				difficulty = 2,
			},
			{
				type = "scene",
				stage = "hollowroot",
				actors = {
					{ id = "bacon", x = -2.4, facing = 1, anim = "stance" },
					{ id = "studzilla", x = 2.6, facing = -1, anim = "kneel" },
					{ id = "noob", x = -5.2, facing = 1, anim = "stance" },
				},
				shots = {
					{
						cam = "close",
						a = 2,
						lines = {
							{ speaker = "studzilla", text = "...YOU. DID. NOT. DELETE. ME. RESPECT.", gesture = "fist", pop = "+RESPECT", popX = 0.7, popY = 0.32 },
							{ speaker = "studzilla", text = "THE ADMIN. ANCHORED. MY FRIENDS. THEN. HE. DELETED. THEM. ALL." },
						},
					},
					{
						cam = "two",
						a = 1,
						b = 2,
						events = {
							{ t = 2.6, type = "anim", actor = 2, anim = "stance" },
							{ t = 2.6, type = "jump", actor = 2 },
							{ t = 3.1, type = "boom", amount = 0.4 },
						},
						lines = {
							{ speaker = "bacon", text = "That monster. Who deletes builds?!", gesture = "facepalm" },
							{ speaker = "studzilla", text = "PATH. TO. ADMIN. THROUGH. FLOOD. MAP. I. COME. WITH. YOU.", gesture = "flex" },
						},
					},
				},
			},
			{
				type = "scene",
				stage = "cathedral",
				actors = {
					{ id = "studzilla", x = -9.6, facing = 1, anim = "stance" },
					{ id = "camper", x = 3.2, facing = -1, anim = "stance", hidden = true },
					{ id = "noob", x = -12.0, facing = 1, anim = "stance" },
				},
				shots = {
					{ cam = "sky", duration = 4.2, caption = "FLOODED CHURCH ESCAPE  \u{2014}  THE WATER IS RISING (AGAIN)" },
					{
						cam = "track",
						a = 1,
						duration = 3.0,
						events = {
							{ t = 0, type = "walk", actor = 1, to = -2.6, time = 2.9 },
							{ t = 0, type = "walk", actor = 3, to = -6.0, time = 2.8 },
						},
					},
					{
						cam = "wide",
						events = {
							{ t = 0.5, type = "sfx", key = "crossbow" },
							{ t = 0.7, type = "vfx", kind = "bolt_impact", actor = 1 },
							{ t = 0.7, type = "slowmo", scale = 0.25, time = 0.6 },
							{ t = 0.9, type = "show", actor = 2 },
							{ t = 0.9, type = "vfx", kind = "smoke", actor = 2 },
							{ t = 1.1, type = "pop", text = "SUS", x = 0.72, y = 0.42 },
							{ t = 1.6, type = "freeze", actor = 2 },
						},
						lines = {
							{ speaker = "camper", text = "Don't mind me. Just a bush. A completely normal bush with a crossbow." },
						},
					},
					{
						cam = "close",
						a = 2,
						lines = { { speaker = "camper", text = "The Admin promised me VIP if I camp this spot. I've been here six days.", gesture = "think" } },
					},
					{
						cam = "low",
						a = 1,
						events = {
							{ t = 0.6, type = "face", actor = 3, facing = -1 },
							{ t = 0.6, type = "walk", actor = 3, to = -14, time = 2.2 },
						},
						lines = { { speaker = "studzilla", text = "NOOB. GO. AHEAD. I. WILL. UN-BUSH. HER.", crash = true } },
					},
				},
			},
			{
				type = "fight",
				title = "STUDZILLA  VS  THE CAMPER",
				stage = "cathedral",
				player = "studzilla",
				playerEcho = "nightguard",
				opponent = "camper",
				opponentEcho = "pigeon",
				difficulty = 2,
			},
			{
				type = "scene",
				stage = "cathedral",
				actors = {
					{ id = "studzilla", x = -2.4, facing = 1, anim = "stance" },
					{ id = "camper", x = 2.6, facing = -1, anim = "kneel" },
				},
				shots = {
					{
						cam = "close",
						a = 2,
						lines = {
							{ speaker = "camper", text = "...Okay, okay. The VIP was fake anyway. He literally said 'trust me bro'.", pop = "TRUST ME BRO", popX = 0.68, popY = 0.3 },
							{ speaker = "camper", text = "His throne's past the lava. The floor is lava. He typed it. Like, actually.", gesture = "point" },
						},
					},
					{
						cam = "two",
						a = 1,
						b = 2,
						events = { { t = 1.2, type = "anim", actor = 2, anim = "stance" }, { t = 1.2, type = "jump", actor = 2 } },
						lines = { { speaker = "studzilla", text = "WE. CAMP. TOGETHER. NOW. FRIEND.", gesture = "flex" } },
					},
				},
			},
			{
				type = "scene",
				stage = "emberthrone",
				actors = {
					{ id = "noob", x = -10.4, facing = 1, anim = "stance" },
					{ id = "admin", x = 3.6, facing = -1, anim = "cross" },
				},
				shots = {
					{ cam = "sky", duration = 4.4, caption = "THE ADMIN'S LAVA THRONE  \u{2014}  SERVER SHUTDOWN IN 99 SECONDS" },
					{
						cam = "track",
						a = 1,
						duration = 3.0,
						events = { { t = 0, type = "walk", actor = 1, to = -3.4, time = 2.8 } },
					},
					{
						cam = "low",
						a = 2,
						lines = {
							{
								speaker = "admin",
								text = "A Noob. A Bacon Hair. A bush. And... is that a pile of bricks? I've seen better lobbies on a Tuesday.",
								gesture = "laugh",
								freeze = true,
							},
						},
					},
					{
						cam = "close",
						a = 1,
						lines = { { speaker = "noob", text = "Cancel the shutdown. Some of us have tycoons running.", gesture = "point" } },
					},
					{
						cam = "over",
						a = 1,
						b = 2,
						lines = {
							{ speaker = "admin", text = "I have admin. You have a default avatar. Do the math.", gesture = "think" },
							{ speaker = "noob", text = "Never been good at math. Pretty good at this though.", gesture = "fist", cam = "crash", a = 1, impact = true },
						},
					},
				},
			},
			{
				type = "fight",
				title = "THE NOOB  VS  THE ADMIN",
				stage = "emberthrone",
				player = "noob",
				playerEcho = "grandpa",
				opponent = "admin",
				opponentEcho = "nightguard",
				difficulty = 3,
				boss = true,
			},
			{
				type = "scene",
				stage = "emberthrone",
				actors = {
					{ id = "noob", x = -2.4, facing = 1, anim = "stance" },
					{ id = "admin", x = 2.4, facing = -1, anim = "kneel" },
					{ id = "bacon", x = -6.0, facing = 1, anim = "stance" },
					{ id = "guest", x = 6.5, facing = -1, anim = "stance", hidden = true },
				},
				shots = {
					{
						cam = "close",
						a = 2,
						lines = { { speaker = "admin", text = "No... my commands... why isn't ;kill WORKING?!", gesture = "nervous" } },
						events = { { t = 0.5, type = "vfx", kind = "souls", actor = 2 } },
					},
					{
						cam = "two",
						a = 3,
						b = 1,
						lines = {
							{ speaker = "bacon", text = "His admin's expiring! It was a free trial! Noob, NOW!", gesture = "point", crash = true },
							{ speaker = "noob", text = "Hey Admin. ;unadmin.", gesture = "wave", pop = ";unadmin", popX = 0.5, popY = 0.3 },
						},
					},
					{
						cam = "sky",
						duration = 4.0,
						events = {
							{ t = 0.3, type = "impact", count = 4 },
							{ t = 0.4, type = "vfx", kind = "flash" },
							{ t = 0.4, type = "sfx", key = "lightning_crack" },
							{ t = 0.4, type = "shake", amount = 1.0 },
							{ t = 0.6, type = "hide", actor = 2 },
						},
						caption = "SHUTDOWN CANCELLED.  SERVER SAVED.  FOR NOW.",
					},
					{
						cam = "wide",
						duration = 5.0,
						events = {
							{ t = 0, type = "anim", actor = 1, anim = "win" },
							{ t = 0, type = "anim", actor = 3, anim = "win" },
							{ t = 0.3, type = "show", actor = 4 },
							{ t = 0.3, type = "vfx", kind = "teleport", actor = 4 },
							{ t = 0.3, type = "sfx", key = "teleport" },
							{ t = 0.5, type = "face", actor = 1, facing = 1 },
						},
						lines = {
							{ speaker = "system", text = "Guest 666 has joined the game." },
							{
								speaker = "guest",
								text = "...see you in Chapter 2.",
								cam = "dolly",
								a = 4,
								freeze = true,
								freezeName = "TO BE CONTINUED...",
								freezeSub = "Guest 666 will return",
							},
						},
					},
				},
			},
		},
	},
}

Story.speakerNames = {
	noob = "THE NOOB",
	bacon = "BACON HAIR",
	studzilla = "STUDZILLA",
	guest = "GUEST 666",
	frosty = "FROSTY",
	emote = "EMOTE QUEEN",
	camper = "THE CAMPER",
	admin = "THE ADMIN",
	grandpa = "GRANDPA STUDS",
	dana = "DOG WALKER DANA",
	nightguard = "THE NIGHT GUARD",
	pigeon = "PIGEON LADY",
	system = "[SYSTEM]",
}

-- Seconds a subtitle stays on screen.
function Story.lineDuration(text: string): number
	return math.clamp(1.4 + #text * 0.055, 2.2, 7.5)
end

return Story
