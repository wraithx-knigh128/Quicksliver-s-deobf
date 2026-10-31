--!nonstrict
-- OOF FIGHTERS 1 client entry point: builds the UI root and runs the game flow
-- (title -> main menu -> Story / Ascent / Versus / Practice / Move List / Settings).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Veil = ReplicatedStorage:WaitForChild("Veil")
local Fighters = require(Veil.Data.Fighters)
local Echoes = require(Veil.Data.Echoes)
local Story = require(Veil.Data.Story)
local Config = require(Veil.Config)

local Client = script.Parent
local Theme = require(Client.UI.Theme)
local Screens = require(Client.UI.Screens)
local Subtitles = require(Client.UI.Subtitles)
local Audio = require(Client.Core.Audio)
local Input = require(Client.Core.Input)
local FightView = require(Client.Render.FightView)
local Cutscene = require(Client.Render.Cutscene)
local StageBuilder = require(Client.Render.StageBuilder)
local FightCamera = require(Client.Render.FightCamera)

-------------------------------------------------------------------------------
-- Boot
-------------------------------------------------------------------------------

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- hide default Roblox HUD elements we don't use (keep the system menu & chat)
for _, t in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.EmotesMenu } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(t, false)
	end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "VeilUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")
local root = Theme.root(gui)
Subtitles.mount(root)

-- a quiet backdrop behind menus
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.new(0, 6, 22) * CFrame.Angles(math.rad(-6), 0, 0)
Lighting.ClockTime = 0.5

-------------------------------------------------------------------------------
-- Profile & settings
-------------------------------------------------------------------------------

local profile = {
	settings = { music = 0.6, sfx = 0.8, voice = 0.85, subtitles = true, shake = true, difficulty = 2, touch = "auto" },
	stats = { wins = 0, losses = 0, ascents = 0, finishers = 0, storyDone = false },
}
local remotes = ReplicatedStorage:WaitForChild("VeilRemotes", 10)

task.spawn(function()
	if not remotes then
		return
	end
	local fn = remotes:FindFirstChild("GetProfile")
	if not fn then
		return
	end
	local ok, data = pcall(function()
		return fn:InvokeServer()
	end)
	if ok and type(data) == "table" then
		if type(data.settings) == "table" then
			for k, v in data.settings do
				profile.settings[k] = v
			end
		end
		if type(data.stats) == "table" then
			for k, v in data.stats do
				profile.stats[k] = v
			end
		end
		Audio.setVolumes(profile.settings)
		Subtitles.enabled = profile.settings.subtitles ~= false
	end
end)

local function applySettings()
	Audio.setVolumes(profile.settings)
	Subtitles.enabled = profile.settings.subtitles ~= false
	FightCamera.setShakeScale(profile.settings.shake == false and 0 or 1)
end
applySettings()

local function saveProfile(delta)
	if delta then
		for k, v in delta do
			if type(v) == "number" then
				profile.stats[k] = (profile.stats[k] or 0) + v
			elseif v == true then
				profile.stats[k] = true
			end
		end
	end
	if not remotes then
		return
	end
	local ev = remotes:FindFirstChild("SaveProfile")
	if ev then
		ev:FireServer({ settings = profile.settings, delta = delta })
	end
end

local function profileSummary()
	return {
		wins = profile.stats.wins,
		ascents = profile.stats.ascents,
		storyDone = profile.stats.storyDone,
	}
end

-------------------------------------------------------------------------------
-- Fight runner (handles pause / restart / quit)
-------------------------------------------------------------------------------

-- Returns outcome { kind = "end" | "restart" | "quit", result? }, plus a black cover frame.
local function runFight(opts, cover)
	cover = cover or Screens.fadeToBlack(root, 0.3)
	local finished = Instance.new("BindableEvent")
	local outcome = nil
	local view = nil
	local pausing = false

	local function finish(o)
		if outcome then
			return
		end
		outcome = o
		finished:Fire()
	end

	local fightOpts = table.clone(opts)
	fightOpts.root = root
	fightOpts.settings = profile.settings
	fightOpts.forceTouch = profile.settings.touch == "on"
	fightOpts.noTouch = profile.settings.touch == "off"
	fightOpts.onEnd = function(result)
		finish({ kind = "end", result = result })
	end
	fightOpts.onPause = function()
		if pausing or outcome then
			return
		end
		pausing = true
		task.spawn(function()
			view:setPaused(true)
			Audio.ui("ui_back")
			local r = Screens.pause(root, { noRestart = opts.noRestart })
			while r == "movelist" or r == "settings" do
				if r == "movelist" then
					Screens.moveList(root, opts.p1.fighter)
				else
					Screens.settings(root, profile.settings)
					applySettings()
					saveProfile(nil)
				end
				r = Screens.pause(root, { noRestart = opts.noRestart })
			end
			pausing = false
			if r == "resume" then
				view:setPaused(false)
			elseif r == "restart" then
				finish({ kind = "restart" })
			elseif r == "quit" then
				finish({ kind = "quit" })
			end
		end)
	end

	view = FightView.new(fightOpts)
	Screens.fadeFromBlack(cover, 0.7)
	if not outcome then
		finished.Event:Wait()
	end
	finished:Destroy()
	local out = Screens.fadeToBlack(root, 0.45)
	view:destroy()
	StageBuilder.clear()
	return outcome, out
end

local function recordResult(result)
	if not result then
		return
	end
	local delta = {}
	if result.winner == 1 then
		delta.wins = 1
		if result.finisher then
			delta.finishers = 1
		end
	else
		delta.losses = 1
	end
	saveProfile(delta)
end

-------------------------------------------------------------------------------
-- Modes
-------------------------------------------------------------------------------

local function randomEcho()
	return Echoes.list[math.random(1, #Echoes.list)].id
end

local function runVersus()
	while true do
		local sel = Screens.characterSelect(root, { pickOpponent = true })
		if not sel then
			return
		end
		local stageId, diff = Screens.stageSelect(root, profile.settings.difficulty)
		if stageId then
			local p1 = { fighter = sel.fighter, echo = sel.echo }
			local p2 = { fighter = sel.opp, echo = sel.oppEcho, cpu = true, difficulty = diff }
			while true do
				local cover = Screens.versus(root, p1, p2, stageId)
				local outcome, out = runFight({ p1 = p1, p2 = p2, stage = stageId }, cover)
				if outcome.kind == "restart" then
					Screens.fadeFromBlack(out, 0.1)
				elseif outcome.kind == "quit" then
					Screens.fadeFromBlack(out, 0.4)
					return
				else
					recordResult(outcome.result)
					Screens.fadeFromBlack(out, 0.4)
					local r = Screens.results(root, outcome.result)
					if r == "menu" then
						return
					elseif r == "select" then
						break
					end
					-- rematch: new random echo for the CPU keeps it fresh
					p2.echo = randomEcho()
				end
			end
		end
	end
end

local function runPractice()
	local sel = Screens.characterSelect(root, { pickOpponent = true, title = "PRACTICE: CHOOSE YOUR FIGHTER" })
	if not sel then
		return
	end
	while true do
		local p1 = { fighter = sel.fighter, echo = sel.echo }
		local p2 = { fighter = sel.opp, echo = sel.oppEcho, cpu = false }
		local cover = Screens.fadeToBlack(root, 0.3)
		local outcome, out = runFight({ p1 = p1, p2 = p2, stage = "proving", training = true, dummy = "stand" }, cover)
		Screens.fadeFromBlack(out, 0.3)
		if outcome.kind ~= "restart" then
			return
		end
	end
end

local function buildLadder(playerId: string)
	local pool = {}
	for _, f in Fighters.list do
		if f.id ~= playerId and f.id ~= "admin" then
			table.insert(pool, f.id)
		end
	end
	-- shuffle
	for i = #pool, 2, -1 do
		local j = math.random(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local ladder = {}
	for i = 1, math.min(6, #pool) do
		table.insert(ladder, { fighter = pool[i], echo = randomEcho() })
	end
	if playerId ~= "admin" then
		table.insert(ladder, { fighter = "admin", echo = "nightguard", boss = true })
	else
		table.insert(ladder, { fighter = "noob", echo = "grandpa", boss = true })
	end
	return ladder
end

local function runAscent()
	local sel = Screens.characterSelect(root, { title = "THE TOWER: CHOOSE YOUR FIGHTER", subtitle = "SEVEN TRYHARDS STAND BETWEEN YOU AND THE ADMIN" })
	if not sel then
		return
	end
	local ladder = buildLadder(sel.fighter)
	local base = profile.settings.difficulty or 2
	local i = 1
	while i <= #ladder do
		if Screens.ladder(root, ladder, i, sel.fighter) == "quit" then
			return
		end
		local opp = ladder[i]
		local diff = math.clamp(base + (i <= 2 and -1 or (i >= 6 and 1 or 0)), 1, #Config.Difficulty)
		local stageId
		if opp.boss then
			stageId = "emberthrone"
		else
			local options = { "hollowroot", "skyreach", "cathedral", "baseplate" }
			stageId = options[(i % #options) + 1]
		end
		local p1 = { fighter = sel.fighter, echo = sel.echo }
		local p2 = { fighter = opp.fighter, echo = opp.echo, cpu = true, difficulty = diff }
		local cover = Screens.versus(root, p1, p2, stageId, string.format("THE TOWER  \u{00B7}  TRYHARD %d OF %d", i, #ladder))
		local outcome, out = runFight({ p1 = p1, p2 = p2, stage = stageId, boss = opp.boss }, cover)
		Screens.fadeFromBlack(out, 0.4)
		if outcome.kind == "quit" then
			return
		elseif outcome.kind == "end" then
			recordResult(outcome.result)
			if outcome.result.winner == 1 then
				i += 1
			else
				local r = Screens.results(root, outcome.result, { entries = { { "retry", "TRY AGAIN" }, { "menu", "ABANDON ASCENT" } } })
				if r == "menu" then
					return
				end
			end
		end
	end
	saveProfile({ ascents = 1 })
	Screens.ending(root, sel.fighter)
end

local function runStory()
	local chapter = Story.chapters[1]
	if Screens.card(root, chapter.number, chapter.name, chapter.synopsis, { confirmText = "BEGIN", darkness = 0.55 }) == "back" then
		return
	end
	for _, beat in chapter.beats do
		if beat.type == "scene" then
			Cutscene.play(beat, root)
			StageBuilder.clear()
		else
			while true do
				local p1 = { fighter = beat.player, echo = beat.playerEcho }
				local p2 = { fighter = beat.opponent, echo = beat.opponentEcho, cpu = true, difficulty = beat.difficulty or 2 }
				local cover = Screens.versus(root, p1, p2, beat.stage, beat.title)
				local outcome, out = runFight({ p1 = p1, p2 = p2, stage = beat.stage, boss = beat.boss }, cover)
				Screens.fadeFromBlack(out, 0.4)
				if outcome.kind == "quit" then
					return
				elseif outcome.kind == "end" then
					recordResult(outcome.result)
					if outcome.result.winner == 1 then
						break
					end
					local r = Screens.results(root, outcome.result, { entries = { { "retry", "RETRY FIGHT" }, { "menu", "QUIT STORY" } } })
					if r == "menu" then
						return
					end
				end
			end
		end
	end
	saveProfile({ storyDone = true })
	Screens.card(root, "CHAPTER I COMPLETE", "TO BE CONTINUED", "The server is safe. For now. But deep in the Deleted Accounts folder, a guest is typing... and it just found out what ;admin does.", { darkness = 0.7 })
end

-------------------------------------------------------------------------------
-- Main loop
-------------------------------------------------------------------------------

Screens.title(root)
while true do
	local ok, err = pcall(function()
		local choice = Screens.mainMenu(root, profileSummary())
		if choice == "versus" then
			runVersus()
		elseif choice == "story" then
			runStory()
		elseif choice == "ascent" then
			runAscent()
		elseif choice == "practice" then
			runPractice()
		elseif choice == "movelist" then
			Screens.moveList(root)
		elseif choice == "settings" then
			Screens.settings(root, profile.settings)
			applySettings()
			saveProfile(nil)
		end
	end)
	if not ok then
		-- never leave the player stuck: log, clean up the world and return to the menu
		warn("[OofFighters] recovered from error: " .. tostring(err))
		StageBuilder.clear()
		FightCamera.disable()
		for _, ch in root:GetChildren() do
			if ch:IsA("GuiObject") and ch.Name ~= "Subtitles" then
				ch:Destroy()
			end
		end
		for _, name in { "VeilFight", "VeilCutscene", "VeilVFX" } do
			local inst = workspace:FindFirstChild(name)
			if inst then
				inst:Destroy()
			end
		end
		task.wait(0.5)
	end
	Input.fightEnabled = false
end
