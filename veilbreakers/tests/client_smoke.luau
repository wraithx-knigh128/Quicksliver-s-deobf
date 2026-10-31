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
print("[2] Build every stage")
for _, s in Stages.list do
	step("stage " .. s.id, function()
		local cur = StageBuilder.build(s.id)
		assert(#cur.model:GetChildren() > 10, "stage too empty")
		StageBuilder.update(1.0, 3)
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
add(runFight("raiken vs hollowking @ emberthrone", { p1 = { fighter = "raiken", echo = "okoro", cpu = true, difficulty = 4 }, p2 = { fighter = "hollowking", echo = "warden", cpu = true, difficulty = 4 }, stage = "emberthrone", boss = true, seed = 11 }, 60 * 60 * 8))
add(runFight("seraphine vs nyx @ cathedral (touch UI)", { p1 = { fighter = "seraphine", echo = "ilsa", cpu = true, difficulty = 4 }, p2 = { fighter = "nyx", echo = "talon", cpu = true, difficulty = 4 }, stage = "cathedral", seed = 12, forceTouch = true }, 60 * 60 * 8))
add(runFight("morrgath vs zhura @ hollowroot", { p1 = { fighter = "morrgath", echo = "warden", cpu = true, difficulty = 4 }, p2 = { fighter = "zhura", echo = "okoro", cpu = true, difficulty = 4 }, stage = "hollowroot", seed = 13 }, 60 * 60 * 8))
add(runFight("torvald vs vesper @ skyreach", { p1 = { fighter = "torvald", echo = "talon", cpu = true, difficulty = 4 }, p2 = { fighter = "vesper", echo = "ilsa", cpu = true, difficulty = 4 }, stage = "skyreach", seed = 14 }, 60 * 60 * 8))
runFight("practice @ proving", { p1 = { fighter = "nyx", echo = "okoro" }, p2 = { fighter = "raiken", echo = "okoro" }, stage = "proving", training = true, dummy = "stand", seed = 15 }, 60 * 10)
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
	local cover = Screens.versus(root, { fighter = "raiken", echo = "okoro" }, { fighter = "nyx", echo = "talon" }, "skyreach")
	Screens.fadeFromBlack(cover)
	return "ok"
end, {}, 8)
drive("ascent ladder", function()
	return Screens.ladder(root, { { fighter = "nyx" }, { fighter = "zhura" }, { fighter = "hollowking", boss = true } }, 2, "raiken")
end, { { nav = "confirm" } })
drive("chapter card", function()
	return Screens.card(root, "CHAPTER I", "THE SUNDERED VEIL", "Synopsis text.")
end, { { wait = 1.5, nav = "confirm" } }, 8)
drive("results", function()
	return Screens.results(root, {
		winner = 1,
		p1 = { fighter = "raiken", echo = "okoro" },
		p2 = { fighter = "nyx", echo = "talon" },
		stats = { { damage = 900, hits = 30, maxCombo = 6 }, { damage = 500, hits = 20, maxCombo = 4 } },
	})
end, { { nav = "down" }, { nav = "confirm" } })
drive("pause", function()
	return Screens.pause(root, {})
end, { { nav = "down" }, { nav = "back" } })
drive("move list", function()
	return Screens.moveList(root, "torvald")
end, { { nav = "right" }, { nav = "down" }, { nav = "left" }, { nav = "back" } })
local settings = { music = 0.6, sfx = 0.8, voice = 0.8, subtitles = true, shake = true, difficulty = 2, touch = "auto" }
drive("settings", function()
	return Screens.settings(root, settings)
end, { { nav = "right" }, { nav = "down" }, { nav = "left" }, { nav = "confirm" }, { nav = "back" } })
drive("ending", function()
	return Screens.ending(root, "zhura")
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
	nav("down")
	nav("down")
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
