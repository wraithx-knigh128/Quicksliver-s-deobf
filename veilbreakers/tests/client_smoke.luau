-- Headless client smoke test: runs the real client modules (UI, rigs, stages, VFX,
-- FightView, cutscenes, every menu screen) inside the mock Roblox runtime and fails on
-- any error, invalid property, bad enum or handler exception.
-- Run from the project root:  lune run tests/client_smoke

local roblox = require("@lune/roblox")
local task = require("@lune/task")
local process = require("@lune/process")
local Loader = require("./loader")
local Mock = require("./mock_roblox")

local shared = Loader.root("src/shared")
local client = Loader.root("src/client")
local env = Mock.build(shared)
Loader.addGlobals(env)

local failures = {}
local function fail(msg)
	table.insert(failures, msg)
	print("  FAIL: " .. msg)
end
local function step(name, fn)
	local ok, err = pcall(fn)
	if ok then
		print("  ok  " .. name)
	else
		fail(name .. ": " .. tostring(err))
	end
end

print("[1] Require every client module")
local mods = {}
for _, path in {
	{ "Core", "Input" },
	{ "Core", "Audio" },
	{ "UI", "Theme" },
	{ "UI", "Portrait" },
	{ "UI", "HUD" },
	{ "UI", "Subtitles" },
	{ "UI", "MobileControls" },
	{ "UI", "Screens" },
	{ "Render", "RigMath" },
	{ "Render", "Poses" },
	{ "Render", "Looks" },
	{ "Render", "Rig" },
	{ "Render", "AnimSpring" },
	{ "Render", "StageLife" },
	{ "Render", "StageBuilder" },
	{ "Render", "VFX" },
	{ "Render", "FightCamera" },
	{ "Render", "FightView" },
	{ "Render", "Cutscene" },
} do
	step("require " .. path[1] .. "." .. path[2], function()
		mods[path[2]] = Loader.require(client[path[1]][path[2]])
	end)
end
local Theme, Subtitles, StageBuilder, FightView, Screens, Cutscene, Input, VFX =
	mods.Theme, mods.Subtitles, mods.StageBuilder, mods.FightView, mods.Screens, mods.Cutscene, mods.Input, mods.VFX
local Fighters = Loader.require(shared.Data.Fighters)
local Stages = Loader.require(shared.Data.Stages)
local Story = Loader.require(shared.Data.Story)

-- exercise the audio-atlas playback path with placeholder ids
local Assets = Loader.require(shared.Assets)
Assets.AudioAtlas.sfx = "1000001"
Assets.AudioAtlas.ambience = "1000002"
Assets.AudioAtlas.music_a = "1000003"
Assets.AudioAtlas.music_b = "1000004"

local gui = roblox.Instance.new("ScreenGui")
gui.Parent = Mock.playerGui
local root = Theme.root(gui)
Subtitles.mount(root)

local function pump(n)
	for _ = 1, n do
		Mock.frame(1 / 60)
	end
	task.wait()
end

local only = process.args[1]
if only ~= "flow" then
print("[1b] Animation layer: springs, personality idles, victory poses")
local Poses, AnimSpring = mods.Poses, mods.AnimSpring
local function finitePose(pose, label)
	for k, v in pose do
		if type(v) == "table" then
			for i, x in v do
				assert(type(x) == "number" and x == x and math.abs(x) < 1e5, label .. ": bad value at " .. tostring(k) .. "[" .. i .. "]")
			end
		end
	end
end
step("spring converges to the target and stays within its lag bound", function()
	local sp = AnimSpring.new()
	local a = Poses.stance("blade")
	local b = Poses.Attacks.lunge_slash.hit
	sp:reset(a)
	local worst = 0
	for _ = 1, 30 do
		local out = sp:step(b, 1 / 60, 1)
		for _, k in AnimSpring.KEYS do
			if b[k] and k ~= "root" then
				for i = 1, 3 do
					local d = math.abs(((b[k][i] or 0) - out[k][i] + 180) % 360 - 180)
					worst = math.max(worst, d)
				end
			end
		end
	end
	assert(worst <= 48.001, "lag bound exceeded: " .. worst)
	local out
	for _ = 1, 120 do
		out = sp:step(b, 1 / 60, 0)
	end
	for _, k in AnimSpring.KEYS do
		if b[k] and k ~= "root" then
			for i = 1, 3 do
				local d = math.abs(((b[k][i] or 0) - out[k][i] + 180) % 360 - 180)
				assert(d < 0.5, "did not settle on " .. k .. ": " .. d)
			end
		end
	end
	-- impulse produces motion that decays back
	sp:kick("H", 1, 520)
	local peak = 0
	for _ = 1, 20 do
		out = sp:step(b, 1 / 60, 0)
		peak = math.max(peak, math.abs(out.H[1] - (b.H and b.H[1] or 0)))
	end
	assert(peak > 5, "head kick too weak: " .. peak)
	for _ = 1, 120 do
		out = sp:step(b, 1 / 60, 0)
	end
	assert(math.abs(out.H[1] - (b.H and b.H[1] or 0)) < 0.5, "head kick did not settle")
	-- paused frames (dt = 0) leave the pose untouched
	local h1 = out.H[1]
	out = sp:step(b, 0, 0)
	assert(out.H[1] == h1, "dt=0 moved the pose")
end)
step("crossfading out of a 360 spin takes the short way round", function()
	local spun = table.clone(Poses.stance("dual"))
	spun.root = { 0, 0, 0, 0, 360, 0 }
	local mid = Poses.lerp(spun, Poses.stance("dual"), 0.5)
	assert(math.abs(((mid.root[5] or 0) + 180) % 360 - 180) < 1, "unwound through a full turn: " .. tostring(mid.root[5]))
end)
for _, def in Fighters.list do
	step("idle + victory poses: " .. def.id .. " (" .. tostring(def.personality) .. ")", function()
		assert(def.personality, "no personality")
		local style = Poses.STYLE_OF[def.stance] or "unarmed"
		for k = 0, 40 do
			finitePose(Poses.idleFor(style, def.personality, k * 0.137), def.id .. " idle")
			finitePose(Poses.victoryFor(def.id, style, k * 0.137), def.id .. " victory")
			finitePose(Poses.walk(style, k * 0.4, 1), def.id .. " walk")
		end
		assert(Poses.Victory[def.id], "no signature victory pose")
	end)
end
step("controls: Q block, mouse light/heavy, WASD, notation glyphs", function()
	local prevMode = Input.mode
	Input.mode = "keyboard"
	assert(Input.glyph("B") == "Q", "block glyph " .. tostring(Input.glyph("B")))
	assert(Input.glyph("L") == "LMB" and Input.glyph("H") == "RMB", "mouse glyphs")
	local txt = Input.formatNotation("L, L, H")
	assert(string.find(txt, "LMB") and string.find(txt, "RMB"), "notation: " .. txt)
	-- drive the real UserInputService handlers
	local UIS = Mock.uis
	local Enum = roblox.Enum
	local function key(code, down)
		local io = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = code }
		if down then
			UIS.InputBegan:Fire(io, false)
		else
			UIS.InputEnded:Fire(io, false)
		end
	end
	local function mouse(kind, down, processed)
		local io = { UserInputType = kind }
		if down then
			UIS.InputBegan:Fire(io, processed == true)
		else
			UIS.InputEnded:Fire(io, false)
		end
	end
	local function settle()
		task.wait()
		task.wait()
	end
	key(Enum.KeyCode.Q, true)
	key(Enum.KeyCode.A, true)
	key(Enum.KeyCode.W, true)
	mouse(Enum.UserInputType.MouseButton1, true)
	mouse(Enum.UserInputType.MouseButton2, true)
	settle()
	local st = Input.fightState()
	assert(st.B, "Q did not block")
	assert(st.left and st.up, "A / W did not move / jump")
	assert(st.L, "left click did not light attack")
	assert(st.H, "right click did not heavy attack")
	key(Enum.KeyCode.Q, false)
	key(Enum.KeyCode.A, false)
	key(Enum.KeyCode.W, false)
	mouse(Enum.UserInputType.MouseButton1, false)
	mouse(Enum.UserInputType.MouseButton2, false)
	key(Enum.KeyCode.D, true)
	key(Enum.KeyCode.S, true)
	settle()
	st = Input.fightState()
	assert(st.right and st.down and not st.B and not st.L and not st.H, "release / D / S state wrong")
	key(Enum.KeyCode.D, false)
	key(Enum.KeyCode.S, false)
	-- clicks that land on GUI buttons must not become attacks
	mouse(Enum.UserInputType.MouseButton1, true, true)
	settle()
	assert(not Input.fightState().L, "a GUI click became an attack")
	mouse(Enum.UserInputType.MouseButton1, false)
	-- losing window focus releases everything
	key(Enum.KeyCode.Q, true)
	settle()
	UIS.WindowFocusReleased:Fire()
	settle()
	assert(not Input.fightState().B, "input stuck after focus loss")
	settle()
	Input.mode = prevMode
end)
step("power hotbar: 4 slots, cooldown sweep, keys 1-4 reach the engine", function()
	local HUD = mods.HUD
	local Engine = Loader.require(shared.Combat.Engine)
	local def = Fighters.get("noob")
	local powers = {}
	for slot, id in { "SN", "SF", "SB", "SD" } do
		table.insert(powers, { id = id, name = def.moves[id].name, key = tostring(slot), color = roblox.Color3.new(1, 1, 1) })
	end
	local hud = HUD.new(root, def, Loader.require(shared.Data.Echoes).get("grandpa"), Fighters.get("admin"), Loader.require(shared.Data.Echoes).get("dana"), { powers = powers })
	assert(hud.hotbar and #hud.hotbar.slots == 4, "hotbar missing")
	local fake = { powerCD = { SF = 48 }, powerCDMax = { SF = 96 } }
	hud:updateHotbar(fake)
	local sl = hud.hotbar.slots[2]
	assert(math.abs(sl.cover.Size.Y.Scale - 0.5) < 0.01, "cooldown sweep wrong: " .. sl.cover.Size.Y.Scale)
	assert(sl.secs.Text == "0.8", "cooldown seconds wrong: " .. sl.secs.Text)
	fake.powerCD.SF = 0
	hud:updateHotbar(fake)
	assert(sl.secs.Text == "" and sl.cover.Size.Y.Scale == 0, "slot did not come back up")
	hud:destroy()
	-- keyboard 1-4 -> P1..P4 in the fight state
	local UIS = Mock.uis
	local Enum = roblox.Enum
	for i, code in { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four } do
		UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = code }, false)
		task.wait()
		task.wait()
		assert(Input.fightState()["P" .. i], "key " .. i .. " did not press power " .. i)
		UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = code }, false)
		task.wait()
		task.wait()
		assert(not Input.fightState()["P" .. i], "power " .. i .. " stuck")
	end
	local _ = Engine
end)
-- Full, unskipped playback of story scenes: acting, coverage cuts, freeze frames,
-- impact frames, pop captions, walks, attacks, slow motion.
local function playScene(label: string, beat)
	local done, res, err = false, nil, nil
	task.spawn(function()
		local ok, e = pcall(function()
			res = mods.Cutscene.play(beat, root)
		end)
		if not ok then
			err = e
		end
		done = true
	end)
	local frames = 0
	local t0 = os.clock()
	while not done and os.clock() - t0 < 120 do
		Mock.frame(1 / 60)
		frames += 1
		task.wait()
	end
	if err then
		fail(label .. ": " .. tostring(err))
	elseif not done then
		fail(label .. " did not finish")
	elseif res ~= "done" then
		fail(label .. " returned " .. tostring(res))
	else
		print(string.format("  ok  %s (%d frames, played to the end)", label, frames))
	end
	StageBuilder.clear()
end
if only == "cine" or only == nil then
	print("[1c] Cinematics: autoGesture, full scene playback")
	step("autoGesture reads the line", function()
		local g = mods.Cutscene.autoGesture
		assert(g("WHO. DARES. ENTER. MY. UNFINISHED. MAP.", "studzilla") == "shout", "caps -> shout")
		assert(g("How are you even here?", "noob") == "shrug", "question -> shrug")
		assert(g("Hey Admin. ;unadmin.", "noob") == "wave", "hey -> wave")
		assert(g("...see you in Chapter 2.", "guest") == "sad", "ellipsis -> sad")
		assert(g("Noob, NOW!", "bacon") == "point", "exclamation -> point")
		assert(g("Guest 666 has joined the game.", "system") == nil, "system has no body")
	end)
	local beats = Story.chapters[1].beats
	playScene("scene 1 (freeze, impact, crash, pops, coverage)", beats[1])
	playScene("final scene (impact x4, flash, to-be-continued freeze)", beats[#beats])
	-- every cinematic effect leaves nothing behind in Lighting
	local Lighting = Mock.game:GetService("Lighting")
	for _, c in Lighting:GetChildren() do
		assert(c.Name ~= "CineFXGrade" and c.Name ~= "CineFXBlur", "CineFX left " .. c.Name .. " in Lighting")
	end
end
if only == "cine" then
	for _, e in Mock.errors do
		fail("handler error: " .. e)
	end
	print(#failures == 0 and "\n0 failures" or ("\n" .. #failures .. " failures"))
	process.exit(#failures == 0 and 0 or 1)
end
if only == "anim" then
	for _, e in Mock.errors do
		fail("handler error: " .. e)
	end
	print(#failures == 0 and "\n0 failures" or ("\n" .. #failures .. " failures"))
	process.exit(#failures == 0 and 0 or 1)
end

print("[2] Build every stage")
for _, s in Stages.list do
	step("stage " .. s.id, function()
		local cur = StageBuilder.build(s.id)
		assert(#cur.model:GetChildren() > 10, "stage too empty")
		assert(cur.life and #cur.life.fighterLights == 2, "fighter lighting rig missing")
		-- run the arena through ~25 s of life: crowd, chatter, flickers, lightning, eruptions
		local fighters = { { x = -4, y = 0 }, { x = 4, y = 0 } }
		for k = 1, 1500 do
			StageBuilder.update(k / 60, 3, 1 / 60, fighters)
		end
		for _, kind in { "round", "heavy", "super", "ko" } do
			StageBuilder.react(kind)
			StageBuilder.update(26, 3, 1 / 60, fighters)
		end
		for _, n in cur.life.crowd do
			for _, p in n.parts do
				local pos = p.CFrame.Position
				assert(pos.Y > -1 and pos.Y < 40, "crowd part out of bounds: " .. tostring(pos))
			end
		end
	end)
end
StageBuilder.clear()

print("[3] Every projectile visual")
for _, kind in {
	"lightning_bolt", "halo_disc", "thorns", "shadow_orb", "ice_shard", "ice_wall", "chakram", "bolt", "hook", "trap",
	"light_pillar", "fang_spikes", "soulfire", "seal", "wolf", "lantern_bomb", "ravens", "raven_dive",
} do
	step("projectile " .. kind, function()
		local v = VFX.projectile(kind, "fire")
		for i = 1, 5 do
			v:set(roblox.Vector3.new(i, 3, 0), 1, i / 60, roblox.Vector3.new(0, 3, 0))
		end
		v:destroy(roblox.Vector3.new(1, 1, 0))
	end)
end

print("[4] Full CPU-vs-CPU matches through FightView (HUD, VFX, supers, finishers)")
local function runFight(label, opts, maxFrames)
	local ended, result = false, nil
	opts.root = root
	opts.onEnd = function(r)
		ended = true
		result = r
	end
	opts.onPause = function() end
	local view
	step(label .. " (construct)", function()
		view = FightView.new(opts)
	end)
	if not view then
		return
	end
	local evCounts = {}
	local origOnEvent = view.onEvent
	view.onEvent = function(self, ev)
		evCounts[ev.type] = (evCounts[ev.type] or 0) + 1
		return origOnEvent(self, ev)
	end
	local frames = 0
	while not view.ended and frames < maxFrames do
		Mock.frame(1 / 60)
		frames += 1
		if frames % 30 == 0 then
			task.wait()
		end
	end
	local t0 = os.clock()
	while not ended and os.clock() - t0 < 6 do
		task.wait(0.05)
		Mock.frame(1 / 60)
	end
	step(label .. " (destroy)", function()
		view:destroy()
	end)
	local summary = {}
	for _, k in { "hit", "block", "super_hit", "echo_summon", "projectile_spawn", "finisher_start", "finisher_hit", "ko", "throw", "parry", "breaker" } do
		table.insert(summary, k .. "=" .. tostring(evCounts[k] or 0))
	end
	print(string.format("      %s: %d frames, ended=%s winner=%s  %s", label, frames, tostring(ended), tostring(result and result.winner), table.concat(summary, " ")))
	if opts.training then
		return evCounts
	end
	if not ended then
		fail(label .. " did not reach onEnd")
	end
	return evCounts
end

local totals = {}
local function add(c)
	for k, v in c or {} do
		totals[k] = (totals[k] or 0) + v
	end
end
add(runFight("noob vs admin @ emberthrone", { p1 = { fighter = "noob", echo = "grandpa", cpu = true, difficulty = 4 }, p2 = { fighter = "admin", echo = "nightguard", cpu = true, difficulty = 4 }, stage = "emberthrone", boss = true, seed = 11 }, 60 * 60 * 8))
add(runFight("bacon vs guest @ cathedral (touch UI)", { p1 = { fighter = "bacon", echo = "dana", cpu = true, difficulty = 4 }, p2 = { fighter = "guest", echo = "pigeon", cpu = true, difficulty = 4 }, stage = "cathedral", seed = 12, forceTouch = true }, 60 * 60 * 8))
add(runFight("studzilla vs emote @ hollowroot", { p1 = { fighter = "studzilla", echo = "nightguard", cpu = true, difficulty = 4 }, p2 = { fighter = "emote", echo = "grandpa", cpu = true, difficulty = 4 }, stage = "hollowroot", seed = 13 }, 60 * 60 * 8))
add(runFight("frosty vs camper @ skyreach", { p1 = { fighter = "frosty", echo = "pigeon", cpu = true, difficulty = 4 }, p2 = { fighter = "camper", echo = "dana", cpu = true, difficulty = 4 }, stage = "skyreach", seed = 14 }, 60 * 60 * 8))
runFight("practice @ proving", { p1 = { fighter = "guest", echo = "grandpa" }, p2 = { fighter = "noob", echo = "grandpa" }, stage = "proving", training = true, dummy = "stand", seed = 15 }, 60 * 10)
for _, k in { "hit", "block", "super_hit", "echo_summon", "projectile_spawn", "finisher_hit" } do
	if (totals[k] or 0) == 0 then
		fail("no '" .. k .. "' events rendered across the matches")
	end
end

print("[5] Menu screens")
local function drive(label, fn, actions, timeout)
	local done, res = false, nil
	task.spawn(function()
		local ok, err = pcall(function()
			res = fn()
		end)
		if not ok then
			fail(label .. ": " .. tostring(err))
		end
		done = true
	end)
	for _, a in actions do
		task.wait(a.wait or 0.25)
		pump(2)
		if a.nav then
			Input.nav:Fire(a.nav)
		elseif a.any then
			Input.anyPressed:Fire()
		end
	end
	local t0 = os.clock()
	while not done and os.clock() - t0 < (timeout or 10) do
		task.wait(0.05)
		pump(1)
	end
	if done then
		print("  ok  " .. label .. " -> " .. tostring(type(res) == "table" and "table" or res))
	else
		fail(label .. " did not finish")
	end
	return res
end

drive("title", function()
	return Screens.title(root)
end, { { wait = 2.0, any = true } }, 6)
drive("main menu", function()
	return Screens.mainMenu(root, { wins = 3, ascents = 1, storyDone = false })
end, { { nav = "down" }, { nav = "down" }, { nav = "up" }, { nav = "confirm" } })
local sel = drive("character select (+echo +opponent)", function()
	return Screens.characterSelect(root, { pickOpponent = true })
end, { { nav = "right" }, { nav = "right" }, { nav = "confirm" }, { wait = 0.6, nav = "right" }, { nav = "confirm" }, { wait = 0.4, nav = "left" }, { nav = "confirm" } }, 12)
if type(sel) ~= "table" or not sel.fighter or not sel.echo or not sel.opp then
	fail("character select returned an incomplete selection")
end
drive("stage select", function()
	return Screens.stageSelect(root, 2)
end, { { nav = "right" }, { nav = "tabR" }, { nav = "confirm" } })
drive("versus splash", function()
	local cover = Screens.versus(root, { fighter = "noob", echo = "grandpa" }, { fighter = "guest", echo = "pigeon" }, "skyreach")
	Screens.fadeFromBlack(cover)
	return "ok"
end, {}, 8)
drive("ascent ladder", function()
	return Screens.ladder(root, { { fighter = "guest" }, { fighter = "emote" }, { fighter = "admin", boss = true } }, 2, "noob")
end, { { nav = "confirm" } })
drive("chapter card", function()
	return Screens.card(root, "CHAPTER I", "THE SUNDERED VEIL", "Synopsis text.")
end, { { wait = 1.5, nav = "confirm" } }, 8)
drive("results", function()
	return Screens.results(root, {
		winner = 1,
		p1 = { fighter = "noob", echo = "grandpa" },
		p2 = { fighter = "guest", echo = "pigeon" },
		stats = { { damage = 900, hits = 30, maxCombo = 6 }, { damage = 500, hits = 20, maxCombo = 4 } },
	})
end, { { nav = "down" }, { nav = "confirm" } })
drive("pause", function()
	return Screens.pause(root, {})
end, { { nav = "down" }, { nav = "back" } })
drive("move list", function()
	return Screens.moveList(root, "frosty")
end, { { nav = "right" }, { nav = "down" }, { nav = "left" }, { nav = "back" } })
local settings = { music = 0.6, sfx = 0.8, voice = 0.8, subtitles = true, shake = true, difficulty = 2, touch = "auto" }
drive("settings", function()
	return Screens.settings(root, settings)
end, { { nav = "right" }, { nav = "down" }, { nav = "left" }, { nav = "confirm" }, { nav = "back" } })
drive("ending", function()
	return Screens.ending(root, "emote")
end, { { wait = 1.6, nav = "confirm" }, { wait = 1.8, nav = "confirm" }, { wait = 1.8, nav = "confirm" } }, 14)

print("[6] Story cutscenes")
for i, beat in Story.chapters[1].beats do
	if beat.type == "scene" then
		drive("cutscene beat " .. i .. " @ " .. beat.stage, function()
			return Cutscene.play(beat, root)
		end, {
			{ wait = 0.5, nav = "confirm" },
			{ wait = 0.3, nav = "confirm" },
			{ wait = 0.3, nav = "confirm" },
			{ wait = 0.3, nav = "confirm" },
			{ wait = 0.3, nav = "back" },
		}, 12)
		StageBuilder.clear()
	end
end

end

if only == nil or only == "online" then
	print("[9] Online: the client replays a server-run match; online screens")
	local function odrive(label, fn, actions, timeout)
		local finished, res = false, nil
		task.spawn(function()
			local ok, err = pcall(function()
				res = fn()
			end)
			if not ok then
				fail(label .. ": " .. tostring(err))
			end
			finished = true
		end)
		for _, act in actions do
			task.wait(act.wait or 0.25)
			pump(2)
			if act.nav then
				Input.nav:Fire(act.nav)
			end
		end
		local t0 = os.clock()
		while not finished and os.clock() - t0 < (timeout or 10) do
			task.wait(0.05)
			pump(1)
		end
		if finished then
			print("  ok  " .. label .. " -> " .. tostring(res))
		else
			fail(label .. " did not finish")
		end
		return res
	end
	local serverRoot = Loader.root("src/server")
	local OnlineMatch = Loader.require(serverRoot.OnlineMatch)
	local SInv = Loader.require(serverRoot.Inventory)
	local SProfiles = Loader.require(serverRoot.Profiles)
	local AI = Loader.require(shared.Combat.AI)
	local NetInput = Loader.require(shared.Combat.NetInput)
	local Rng = Loader.require(shared.Combat.Rng)
	local Net = Loader.require(client.Net.Net)
	local OnlineScreens = Loader.require(client.UI.OnlineScreens)
	local A = { UserId = 1, DisplayName = "Tester", Name = "Tester", Parent = true }
	local B = { UserId = 2, DisplayName = "Rival", Name = "Rival", Parent = true }
	local profiles = { [A] = SProfiles.sanitize(nil), [B] = SProfiles.sanitize(nil) }
	local skin = SInv.addWeapon(profiles[A].inv, 1, "katana_neon", "rainbow")
	SInv.equip(profiles[A].inv, "noob", skin.uid)
	local skin2 = SInv.addWeapon(profiles[B].inv, 2, "daggers_666", "glitched")
	SInv.equip(profiles[B].inv, "guest", skin2.uid)
	local inbox = { [A] = {}, [B] = {} }
	local clock = 0
	local r = Rng.new(9)
	local svc = OnlineMatch.new({
		getProfile = function(p)
			return profiles[p]
		end,
		send = function(p, m)
			table.insert(inbox[p], m)
		end,
		save = function() end,
		now = function()
			return clock
		end,
		rand = function()
			return r:next()
		end,
	})
	svc:queuePlayer(A, { fighter = "noob", echo = "grandpa", stage = "baseplate" })
	svc:queuePlayer(B, { fighter = "guest", echo = "pigeon", stage = "baseplate" })
	local startMsg
	for _, m in inbox[A] do
		if m.op == "start" then
			startMsg = m
		end
	end
	local spec = startMsg.spec
	svc:setReady(A, spec.id)
	svc:setReady(B, spec.id)
	local sm = svc.byPlayer[A]
	local ai1, ai2 = AI.new(sm.engine, 1, 3, 5), AI.new(sm.engine, 2, 3, 6)
	local guard = 0
	while svc.byPlayer[A] and guard < 20000 do
		local i1, i2 = ai1:getInput(), ai2:getInput()
		svc:input(A, NetInput.encode(i1), NetInput.encode(i1))
		svc:input(B, NetInput.encode(i2), NetInput.encode(i2))
		clock += 1 / 60
		svc:tick(1 / 60)
		guard += 1
	end
	local serverWinner = sm.engine.winner
	-- the client, fed the same packets through a stand-in network
	local fakeNet = { onOnline = roblox.Instance.new("BindableEvent"), sendInput = function() end }
	local done, result = false, nil
	local view
	step("online FightView builds (cosmetics on both rigs)", function()
		view = FightView.new({
			root = root,
			p1 = { fighter = spec.p1.fighter, echo = spec.p1.echo, cosmetic = spec.p1.cosmetic },
			p2 = { fighter = spec.p2.fighter, echo = spec.p2.echo, cosmetic = spec.p2.cosmetic },
			stage = spec.stage,
			variant = spec.variant,
			seed = spec.seed,
			online = { side = 1, spec = spec, net = fakeNet },
			onEnd = function(res)
				result = res
				done = true
			end,
		})
		assert(view.rigs[1].cosmetic and view.rigs[2].cosmetic, "cosmetics not applied")
	end)
	if view then
		local idx = 1
		local t0 = os.clock()
		while not done and os.clock() - t0 < 240 do
			for _ = 1, 3 do
				local m = inbox[A][idx]
				if m then
					idx += 1
					if m.op ~= "start" and m.op ~= "queued" then
						fakeNet.onOnline:Fire(m)
					end
				end
			end
			Mock.frame(1 / 60)
			task.wait()
		end
		step("online replay reaches the server's result", function()
			assert(done and result, "the online fight never ended")
			assert(result.online and result.winner == serverWinner, "winner differs: client " .. tostring(result and result.winner) .. " server " .. tostring(serverWinner))
			assert(view.match.frame == sm.engine.frame, "frame count differs")
			assert(result.corrections == 0, "the client drifted and needed " .. tostring(result.corrections) .. " corrections")
			assert(result.rewarded ~= nil, "server verdict missing from the result")
		end)
		view:destroy()
		StageBuilder.clear()
	end
	-- screens
	Net.inv = {
		res = { studs = 120, scrap = 40, glitch = 5, relic = 2 },
		weapons = { { uid = "w1-1", item = "katana_neon", ench = "blazing" }, { uid = "w1-2", item = "hammer_ban" } },
		equipped = { noob = "w1-1" },
	}
	odrive("online hub", function()
		return OnlineScreens.hub(root, { pending = 2 })
	end, { { wait = 0.6, nav = "down" }, { nav = "back" } })
	odrive("inventory (options, back)", function()
		OnlineScreens.inventory(root)
		return "closed"
	end, { { wait = 0.8, nav = "confirm" }, { wait = 0.6, nav = "back" }, { wait = 0.6, nav = "back" } }, 12)
	odrive("trade window (ready toggle, server closes it)", function()
		task.spawn(function()
			task.wait(1.2)
			Net.onTrade:Fire({ op = "closed", reason = "Rival cancelled" })
		end)
		return OnlineScreens.trade(root, { with = 2, name = "Rival" })
	end, {
		{ wait = 0.5, nav = "confirm" },
		{ wait = 0.3, nav = "confirm" },
	}, 6)
	-- feed server trade messages into the open window
	odrive("trade window reacts to the server", function()
		task.spawn(function()
			task.wait(0.4)
			Net.onTrade:Fire({ op = "state", mine = { weapons = { { uid = "w1-2", item = "hammer_ban" } }, res = { studs = 10 } }, theirs = { weapons = {}, res = { relic = 1 } }, readyMe = true, readyThem = true, countdown = 2.2 })
			task.wait(0.4)
			Net.onTrade:Fire({ op = "done", inv = Net.inv })
		end)
		return OnlineScreens.trade(root, { with = 2, name = "Rival" })
	end, {}, 6)
	odrive("online results", function()
		OnlineScreens.results(root, { side = 1, winner = 1, rounds = { 2, 1 }, rewards = { studs = 30, relic = 1 }, weapon = { uid = "x", item = "bow_vip" }, rewarded = true })
		return "ok"
	end, { { wait = 0.6, nav = "confirm" } })
	if only == "online" then
		for _, e in Mock.errors do
			fail("handler error: " .. e)
		end
		print(#failures == 0 and "\n0 failures" or ("\n" .. #failures .. " failures"))
		process.exit(#failures == 0 and 0 or 1)
	end
end

print("[8] Full game flow through Main.client (title -> practice -> pause/quit -> versus -> results)")
do
	-- fresh UI so Main builds its own; forget the menu cursor from section [5]
	gui:Destroy()
	Screens.lastMain = nil
	local mainDone = false
	task.spawn(function()
		local ok, err = pcall(function()
			Loader.require(client["Main.client"])
		end)
		if not ok then
			fail("Main.client: " .. tostring(err))
		end
		mainDone = true
	end)
	local function nav(a, waitT)
		task.wait(waitT or 0.3)
		pump(2)
		Input.nav:Fire(a)
	end
	local function findScreen(name)
		local pg = Mock.playerGui
		local ui = pg:FindFirstChild("VeilUI")
		local r = ui and ui:FindFirstChild("Root")
		return r and r:FindFirstChild(name)
	end
	local function waitFor(name, timeout)
		local t0 = os.clock()
		while os.clock() - t0 < (timeout or 10) do
			if findScreen(name) then
				return true
			end
			task.wait(0.05)
			pump(1)
		end
		fail("timed out waiting for screen " .. name)
		return false
	end
	waitFor("Title", 5)
	task.wait(2.0)
	Input.anyPressed:Fire()
	waitFor("MainMenu", 6)
	-- ONLINE without a server explains itself and returns to the menu
	nav("down")
	nav("down")
	nav("down")
	nav("confirm")
	waitFor("Card", 6)
	nav("confirm", 1.8)
	if waitFor("MainMenu", 6) then
		print("  ok  online without a server shows the explanation")
	end
	-- practice: menu index 5
	nav("down")
	nav("confirm")
	waitFor("Select", 6)
	nav("confirm")
	waitFor("EchoSelect", 6)
	nav("confirm", 0.6)
	waitFor("Select", 6)
	nav("confirm", 0.6)
	waitFor("HUD", 8)
	print("  ok  practice fight started from the menu")
	for _ = 1, 10 do
		pump(30)
	end
	nav("start")
	waitFor("Pause", 4)
	nav("down")
	nav("down")
	nav("down")
	nav("down")
	nav("confirm")
	waitFor("MainMenu", 8)
	print("  ok  pause -> quit returned to the main menu")
	-- versus: menu index 3
	nav("up")
	nav("up")
	nav("confirm")
	waitFor("Select", 6)
	nav("confirm")
	waitFor("EchoSelect", 6)
	nav("confirm", 0.6)
	waitFor("Select", 6)
	nav("confirm", 0.6)
	waitFor("StageSelect", 6)
	nav("tabL")
	nav("confirm")
	waitFor("Versus", 6)
	waitFor("HUD", 10)
	print("  ok  versus fight started (P1 idle vs CPU)")
	local t0 = os.clock()
	while not findScreen("Results") and os.clock() - t0 < 240 do
		pump(60)
	end
	if findScreen("Results") then
		print("  ok  fight ended and results screen shown")
		nav("down")
		nav("down")
		nav("confirm")
		waitFor("MainMenu", 8)
		print("  ok  results -> main menu")
	else
		fail("versus fight never reached the results screen")
	end
	local _ = mainDone
end

-- drain any deferred work
for _ = 1, 20 do
	pump(1)
	task.wait(0.02)
end

print("\n[7] Errors raised inside event handlers / warn()")
local seen = {}
for _, e in Mock.errors do
	if not seen[e] then
		seen[e] = true
		print("  " .. e)
	end
end
if #Mock.errors > 0 then
	fail(#Mock.errors .. " handler errors")
end

print(string.format("\n%d failures", #failures))
if #failures > 0 then
	process.exit(1)
end
process.exit(0)
