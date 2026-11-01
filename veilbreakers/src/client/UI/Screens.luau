--!nonstrict
-- Menu screens. Each screen function builds its UI, yields until the player decides,
-- cleans up and returns the result, so the game flow reads top-to-bottom.
-- All screens work with keyboard, gamepad, mouse and touch.

local RunService = game:GetService("RunService")

local Veil = game:GetService("ReplicatedStorage"):WaitForChild("Veil")
local Config = require(Veil.Config)
local Assets = require(Veil.Assets)
local Fighters = require(Veil.Data.Fighters)
local Echoes = require(Veil.Data.Echoes)
local Stages = require(Veil.Data.Stages)
local MoveKit = require(Veil.Data.MoveKit)
local Engine = require(Veil.Combat.Engine)

local Client = script.Parent.Parent
local Theme = require(script.Parent.Theme)
local Portrait = require(script.Parent.Portrait)
local Input = require(Client.Core.Input)
local Audio = require(Client.Core.Audio)
local Poses = require(Client.Render.Poses)

local C = Theme.Colors
local F = Theme.Fonts
local new = Theme.new

local Screens = {}

-------------------------------------------------------------------------------
-- helpers
-------------------------------------------------------------------------------

local function waiter()
	local ev = Instance.new("BindableEvent")
	local done = false
	local value = nil
	return {
		resolve = function(v)
			if done then
				return
			end
			done = true
			value = v
			ev:Fire()
		end,
		wait = function()
			if not done then
				ev.Event:Wait()
			end
			ev:Destroy()
			return value
		end,
		done = function()
			return done
		end,
	}
end

local function connections()
	local list = {}
	return {
		add = function(c)
			table.insert(list, c)
			return c
		end,
		clear = function()
			for _, c in list do
				c:Disconnect()
			end
			table.clear(list)
		end,
	}
end

local function screenFrame(root: Instance, name: string)
	return Theme.frame(root, { Name = name, Size = UDim2.fromScale(1, 1), ZIndex = 10 })
end

-- Full-screen key art background with a darkening gradient and drifting embers.
local function backdrop(parent: Instance, darkness: number?, tint: Color3?)
	local bg = Theme.frame(parent, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BackgroundTransparency = 0, ZIndex = 10 })
	local art = Theme.image(bg, Assets.image("KeyArt"), {
		Size = UDim2.fromScale(1.08, 1.08),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageTransparency = darkness or 0.35,
		ZIndex = 10,
	})
	if tint then
		art.ImageColor3 = tint
	end
	Theme.tween(art, 30, { Size = UDim2.fromScale(1.16, 1.16) }, Enum.EasingStyle.Linear)
	local shade = Theme.frame(bg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 11 })
	Theme.gradient(shade, { Color3.new(0, 0, 0), Color3.new(0, 0, 0) }, 0, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.45, 0.55),
		NumberSequenceKeypoint.new(1, 0.25),
	}))
	-- embers
	local embers = Theme.frame(bg, { Size = UDim2.fromScale(1, 1), ZIndex = 12, ClipsDescendants = true })
	local alive = true
	local function present(): boolean
		local ok, parent = pcall(function()
			return embers.Parent
		end)
		return ok and parent ~= nil
	end
	task.spawn(function()
		while alive and present() do
			local e = Theme.frame(embers, {
				Size = UDim2.fromOffset(math.random(2, 5), math.random(2, 5)),
				Position = UDim2.new(math.random(), 0, 1, 10),
				BackgroundColor3 = math.random() < 0.7 and Color3.fromHex("#FFB04A") or Color3.fromHex("#7DFF8C"),
				BackgroundTransparency = 0.1,
				ZIndex = 12,
			})
			Theme.corner(e, 3)
			local life = 5 + math.random() * 5
			Theme.tween(e, life, {
				Position = UDim2.new(e.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, -0.05, 0),
				BackgroundTransparency = 1,
			}, Enum.EasingStyle.Sine)
			task.delay(life, function()
				e:Destroy()
			end)
			task.wait(0.12)
		end
	end)
	bg.Destroying:Connect(function()
		alive = false
	end)
	return bg, art
end

local function title(parent: Instance, text: string, sub: string?, props)
	local holder = Theme.frame(parent, {
		Size = UDim2.new(1, 0, 0, 120),
		Position = UDim2.new(0, 0, 0, 34),
		ZIndex = 15,
	})
	if props then
		for k, v in props do
			(holder :: any)[k] = v
		end
	end
	local t = Theme.label(holder, text, {
		Size = UDim2.new(1, 0, 0, 70),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.display,
		TextSize = 62,
		TextColor3 = C.ivory,
		ZIndex = 16,
	})
	Theme.textStroke(t, 2, 0.3)
	Theme.rule(holder, { Size = UDim2.fromOffset(620, 1), Position = UDim2.new(0.5, 0, 0, 78), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 16 })
	Theme.diamond(holder, 9, C.gold, { Position = UDim2.new(0.5, 0, 0, 78), ZIndex = 17 })
	if sub then
		Theme.label(holder, sub, {
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, 88),
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = F.label,
			TextSize = 18,
			TextColor3 = C.gold,
			ZIndex = 16,
		})
	end
	return holder, t
end

local function hintBar(parent: Instance, hints: { { string } })
	local bar = Theme.frame(parent, {
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		ZIndex = 18,
	})
	local function refresh()
		for _, ch in bar:GetChildren() do
			if ch:IsA("TextLabel") then
				ch:Destroy()
			end
		end
		local parts = {}
		local pending = ""
		for _, h in hints do
			-- an empty label groups this key with the next hint: "[A] [D]  BROWSE"
			pending ..= "[" .. Input.glyph(h[1]) .. "] "
			if h[2] ~= "" then
				table.insert(parts, pending .. " " .. h[2])
				pending = ""
			end
		end
		Theme.label(bar, table.concat(parts, "        "), {
			Size = UDim2.new(1, -60, 1, 0),
			Position = UDim2.fromOffset(30, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			FontFace = F.label,
			TextSize = 16,
			TextColor3 = C.textDim,
			ZIndex = 19,
		})
	end
	refresh()
	local conn = Input.modeChanged.Event:Connect(refresh)
	bar.Destroying:Connect(function()
		conn:Disconnect()
	end)
	return bar
end

-- A big serif text button used in vertical menus.
local function menuItem(parent: Instance, text: string, y: number, size: number?)
	local b = new("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromOffset(520, (size or 46) + 14),
		Position = UDim2.fromOffset(0, y),
		ZIndex = 16,
	}, parent)
	local marker = Theme.diamond(b, 12, C.gold, { Position = UDim2.new(0, 10, 0.5, 0), Visible = false, ZIndex = 17 })
	local l = Theme.label(b, text, {
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.fromOffset(34, 0),
		FontFace = F.display,
		TextSize = size or 46,
		TextColor3 = C.textDim,
		ZIndex = 17,
	})
	Theme.textStroke(l, 1.5, 0.4)
	local line = Theme.rule(b, { Size = UDim2.fromOffset(360, 1), Position = UDim2.new(0, 34, 1, -4), Visible = false, ZIndex = 17 })
	return { button = b, label = l, marker = marker, line = line }
end

local function setItemSelected(item, sel: boolean)
	item.marker.Visible = sel
	item.line.Visible = sel
	Theme.tween(item.label, 0.15, { TextColor3 = sel and C.goldBright or C.textDim })
	Theme.tween(item.label, 0.15, { Position = UDim2.fromOffset(sel and 44 or 34, 0) })
end

-- Generic vertical list navigation. Returns index or nil on back.
local function runList(items, opts)
	opts = opts or {}
	local w = waiter()
	local conns = connections()
	local sel = opts.start or 1
	local function choose(i: number, silent: boolean?)
		if items[sel] then
			setItemSelected(items[sel], false)
		end
		sel = ((i - 1) % #items) + 1
		setItemSelected(items[sel], true)
		if not silent then
			Audio.ui("ui_move")
		end
		if opts.onSelect then
			opts.onSelect(sel)
		end
	end
	choose(sel, true)
	for i, it in items do
		conns.add(it.button.MouseEnter:Connect(function()
			if sel ~= i then
				choose(i)
			end
		end))
		conns.add(it.button.Activated:Connect(function()
			choose(i, true)
			Audio.ui("ui_confirm")
			w.resolve(i)
		end))
	end
	conns.add(Input.nav.Event:Connect(function(action)
		if w.done() then
			return
		end
		if action == "up" then
			choose(sel - 1)
		elseif action == "down" then
			choose(sel + 1)
		elseif action == "confirm" then
			Audio.ui("ui_confirm")
			w.resolve(sel)
		elseif action == "back" and opts.allowBack ~= false then
			Audio.ui("ui_back")
			w.resolve(nil)
		elseif opts.onAction then
			opts.onAction(action, sel)
		end
	end))
	local r = w.wait()
	conns.clear()
	return r
end

local function fadeIn(frame: Instance)
	local cover = Theme.frame(frame, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 60 })
	Theme.tween(cover, 0.45, { BackgroundTransparency = 1 })
	task.delay(0.5, function()
		cover:Destroy()
	end)
end

-- Screen transition: a slanted black panel with a gold leading edge wipes across,
-- covers the cut, then carries on off the other side (see fadeFromBlack).
function Screens.fadeToBlack(root: Instance, time: number?)
	local t = time or 0.4
	local cover = Theme.frame(root, {
		Name = "Fade",
		Size = UDim2.fromScale(1.5, 1),
		Position = UDim2.fromScale(-1.9, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		ZIndex = 90,
	})
	-- slanted edges so the wipe reads as a diagonal cut
	for _, side in { 0, 1 } do
		local edge = Theme.frame(cover, {
			Name = side == 1 and "LeadEdge" or "TailEdge",
			Size = UDim2.new(0, 260, 1.5, 0),
			Position = UDim2.new(side, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0,
			Rotation = 14,
			ZIndex = 90,
		})
		Theme.frame(edge, {
			Name = "Stripe",
			Size = UDim2.new(0, 10, 1, 0),
			Position = UDim2.new(side, side == 1 and 0 or -10, 0, 0),
			BackgroundColor3 = Theme.Colors.gold,
			BackgroundTransparency = 0,
			ZIndex = 91,
		})
	end
	Theme.tween(cover, t, { Position = UDim2.fromScale(-0.25, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	task.wait(t)
	return cover
end

function Screens.fadeFromBlack(cover: Instance?, time: number?)
	if not cover then
		return
	end
	local t = time or 0.5
	Theme.tween(cover, t, { Position = UDim2.fromScale(1.5, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	task.delay(t + 0.05, function()
		cover:Destroy()
	end)
end

function Screens.loading(root: Instance, text: string?)
	local f = screenFrame(root, "Loading")
	f.ZIndex = 80
	local bg = Theme.frame(f, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 80 })
	local _ = bg
	local emblem = Theme.image(f, Assets.image("Emblem"), {
		Size = UDim2.fromOffset(120, 120),
		Position = UDim2.new(1, -110, 1, -110),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 81,
	})
	local spin = RunService.RenderStepped:Connect(function(dt)
		emblem.Rotation += dt * 60
	end)
	Theme.label(f, text or "JOINING SERVER...", {
		Size = UDim2.fromOffset(600, 40),
		Position = UDim2.new(1, -190, 1, -110),
		AnchorPoint = Vector2.new(1, 0.5),
		TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = F.display,
		TextSize = 30,
		TextColor3 = C.gold,
		ZIndex = 81,
	})
	return function()
		spin:Disconnect()
		Theme.tween(bg, 0.4, { BackgroundTransparency = 1 })
		task.delay(0.42, function()
			f:Destroy()
		end)
	end
end

-------------------------------------------------------------------------------
-- Title
-------------------------------------------------------------------------------

function Screens.title(root: Instance)
	local f = screenFrame(root, "Title")
	backdrop(f, 0.05)
	Audio.music("music_menu")
	local emblem = Theme.image(f, Assets.image("Emblem"), {
		Size = UDim2.fromOffset(230, 230),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ScaleType = Enum.ScaleType.Fit,
		ImageTransparency = 1,
		ZIndex = 20,
	})
	local logo = Theme.label(f, Config.GameTitle, {
		Size = UDim2.new(1, 0, 0, 140),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.display,
		TextSize = 150,
		TextColor3 = C.ivory,
		TextTransparency = 1,
		ZIndex = 20,
	})
	local logoStroke = Theme.textStroke(logo, 3, 1)
	Theme.gradient(logo, { Color3.fromHex("#FFF6DE"), Color3.fromHex("#C9A24A") }, 90)
	local sub = Theme.label(f, Config.GameSubtitle, {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0.5, 0, 0.5, 92),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.labelBold,
		TextSize = 24,
		TextColor3 = C.gold,
		TextTransparency = 1,
		ZIndex = 20,
	})
	local rule = Theme.rule(f, { Size = UDim2.fromOffset(0, 1), Position = UDim2.new(0.5, 0, 0.5, 66), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 20 })
	local press = Theme.label(f, "", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0.5, 0, 0.82, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.labelBold,
		TextSize = 24,
		TextColor3 = C.ivory,
		TextTransparency = 1,
		ZIndex = 20,
	})
	Theme.textStroke(press, 2, 0.3)
	press.Text = Input.mode == "touch" and "TAP TO JOIN (WE'LL WAIT)" or (Input.mode == "gamepad" and "PRESS ANY BUTTON (WE'LL WAIT)" or "PRESS ANY KEY (WE'LL WAIT)")
	Theme.label(f, "v" .. Config.Version .. "   \u{00B7}   A Roblox fighting game parody", {
		Size = UDim2.fromOffset(600, 24),
		Position = UDim2.new(0, 24, 1, -16),
		AnchorPoint = Vector2.new(0, 1),
		FontFace = F.label,
		TextSize = 14,
		TextColor3 = C.textDim,
		ZIndex = 20,
	})
	fadeIn(f)
	task.delay(0.3, function()
		Theme.tween(emblem, 1.4, { ImageTransparency = 0 })
		Theme.tween(rule, 1.2, { Size = UDim2.fromOffset(760, 1) })
	end)
	task.delay(0.8, function()
		Theme.tween(logo, 1.2, { TextTransparency = 0 })
		Theme.tween(logoStroke, 1.2, { Transparency = 0.2 })
	end)
	task.delay(1.4, function()
		Theme.tween(sub, 1.0, { TextTransparency = 0 })
	end)
	local pulse = 0
	local conn = RunService.RenderStepped:Connect(function(dt)
		pulse += dt
		if pulse > 2 then
			press.TextTransparency = 0.25 + 0.6 * (0.5 + 0.5 * math.sin(pulse * 3))
		end
		emblem.Rotation = math.sin(pulse * 0.4) * 3
	end)
	task.wait(1.6)
	local w = waiter()
	local c1 = Input.anyPressed.Event:Connect(function()
		w.resolve(true)
	end)
	local c2 = Input.nav.Event:Connect(function()
		w.resolve(true)
	end)
	w.wait()
	c1:Disconnect()
	c2:Disconnect()
	conn:Disconnect()
	Audio.ui("ui_confirm")
	Theme.tween(press, 0.1, { TextTransparency = 0 })
	local cover = Screens.fadeToBlack(root, 0.5)
	f:Destroy()
	Screens.fadeFromBlack(cover, 0.5)
end

-------------------------------------------------------------------------------
-- Main menu
-------------------------------------------------------------------------------

local MAIN_ITEMS = {
	{ id = "story", text = "STORY", desc = "Chapter I \u{2014} The Great Server Reset. The Admin typed ;shutdown. Only a Noob can stop him." },
	{ id = "ascent", text = "TOWER", desc = "Climb a tower of seven tryhards and dethrone the Admin. Every fighter gets an ending. Most of them are dumb." },
	{ id = "versus", text = "VERSUS", desc = "Pick a fighter, a friend, a server and a victim. The CPU has been practicing." },
	{ id = "online", text = "ONLINE", desc = "1v1 real players, trade weapons and resources, enchant at the altar, forge new skins." },
	{ id = "practice", text = "PRACTICE", desc = "Beat up a dummy that can't fight back. Or can it? (It can. Press F.)" },
	{ id = "movelist", text = "MOVE LIST", desc = "Every combo, special, super and finisher. Reading is a skill too." },
	{ id = "settings", text = "SETTINGS", desc = "Volume, subtitles, camera shake, screen flashes, CPU difficulty and touch controls." },
}

function Screens.mainMenu(root: Instance, profile)
	local f = screenFrame(root, "MainMenu")
	backdrop(f, 0.45)
	Audio.music("music_menu")
	-- right-hand 3D showcase
	local show = Theme.frame(f, {
		Size = UDim2.fromOffset(700, 860),
		Position = UDim2.new(1, -40, 1, -20),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 14,
	})
	local showcase = nil
	local idx = math.random(1, #Fighters.list)
	local function showFighter()
		if showcase then
			local old = showcase
			Theme.tween(old.frame, 0.4, { ImageTransparency = 1 })
			task.delay(0.42, function()
				old:destroy()
			end)
		end
		local def = Fighters.list[idx]
		local style = Poses.STYLE_OF[def.stance] or "unarmed"
		showcase = Portrait.create(show, def.look, {
			framing = "full",
			style = style,
			pose = Poses.WIN[style],
			facing = -1,
			yaw = 40,
			fov = 34,
			camSide = 0.2,
			ZIndex = 14,
		})
		showcase.frame.ImageTransparency = 1
		Theme.tween(showcase.frame, 0.6, { ImageTransparency = 0 })
		showcase.name = def.name
	end
	showFighter()
	local showName = Theme.label(f, "", {
		Size = UDim2.fromOffset(720, 40),
		Position = UDim2.new(1, -60, 1, -60),
		AnchorPoint = Vector2.new(1, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextScaled = true,
		FontFace = F.display,
		TextSize = 30,
		TextColor3 = C.goldBright,
		ZIndex = 16,
	})
	Theme.textStroke(showName, 2, 0.3)
	showName.Text = Fighters.list[idx].name .. "  \u{2014}  " .. string.upper(Fighters.list[idx].title)
	local rotT = 0
	local rot = RunService.RenderStepped:Connect(function(dt)
		rotT += dt
		if rotT > 7 then
			rotT = 0
			idx = idx % #Fighters.list + 1
			showFighter()
			showName.Text = Fighters.list[idx].name .. "  \u{2014}  " .. string.upper(Fighters.list[idx].title)
		end
		if showcase then
			local style = showcase.style
			local p = table.clone(Poses.WIN[style] or Poses.WIN.unarmed)
			local b = math.sin(os.clock() * 2) * 2
			p.UT = { (p.UT and p.UT[1] or 0) + b, p.UT and p.UT[2] or 0, 0 }
			showcase:setPose(p, os.clock())
		end
	end)

	-- logo
	local logo = Theme.label(f, Config.GameTitle, {
		Size = UDim2.fromOffset(740, 90),
		Position = UDim2.fromOffset(90, 70),
		FontFace = F.display,
		TextSize = 74,
		TextColor3 = C.ivory,
		ZIndex = 16,
	})
	Theme.gradient(logo, { Color3.fromHex("#FFF6DE"), Color3.fromHex("#C9A24A") }, 90)
	Theme.textStroke(logo, 2, 0.3)
	Theme.rule(f, { Size = UDim2.fromOffset(520, 1), Position = UDim2.fromOffset(90, 162), ZIndex = 16 })
	Theme.image(f, Assets.image("Emblem"), {
		Size = UDim2.fromOffset(70, 70),
		Position = UDim2.fromOffset(16, 82),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 16,
	})

	local list = Theme.frame(f, { Size = UDim2.fromOffset(560, 520), Position = UDim2.fromOffset(80, 210), ZIndex = 15 })
	local items = {}
	for i, it in MAIN_ITEMS do
		items[i] = menuItem(list, it.text, (i - 1) * 62, 44)
	end
	local desc = Theme.label(f, "", {
		Size = UDim2.fromOffset(640, 60),
		Position = UDim2.fromOffset(110, 708),
		FontFace = F.serif,
		TextSize = 24,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = C.text,
		ZIndex = 16,
	})
	if profile then
		Theme.label(f, string.format("WINS %d    \u{00B7}    TOWERS %d    \u{00B7}    STORY %s", profile.wins or 0, profile.ascents or 0, profile.storyDone and "COMPLETE" or "IN PROGRESS"), {
			Size = UDim2.fromOffset(640, 24),
			Position = UDim2.fromOffset(110, 790),
			FontFace = F.label,
			TextSize = 15,
			TextColor3 = C.gold,
			ZIndex = 16,
		})
	end
	hintBar(f, { { "confirm", "SELECT" } })
	fadeIn(f)
	local r = runList(items, {
		start = Screens.lastMain or 1,
		allowBack = false,
		onSelect = function(i)
			desc.Text = MAIN_ITEMS[i].desc
		end,
	})
	Screens.lastMain = r
	rot:Disconnect()
	f:Destroy()
	return MAIN_ITEMS[r].id
end

-------------------------------------------------------------------------------
-- Character select (+ Echo select)
-------------------------------------------------------------------------------

-- opts: { title, step = "fighter"|"echo", side = 1|2, preview = {fighter, echo}?, excludeRandom }
local function fighterPicker(root: Instance, opts)
	local f = screenFrame(root, "Select")
	local bg = backdrop(f, 0.75)
	local _ = bg
	title(f, opts.title or "CHOOSE YOUR FIGHTER", opts.subtitle)
	local list = Fighters.list
	local count = #list + 1 -- + random
	local tiles = {}
	local grid = Theme.frame(f, {
		Size = UDim2.fromOffset(count * 118, 140),
		Position = UDim2.new(0.5, 0, 1, -64),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 15,
	})
	for i = 1, count do
		local def = list[i]
		local tile = new("TextButton", {
			AutoButtonColor = false,
			Text = "",
			Size = UDim2.fromOffset(108, 128),
			Position = UDim2.fromOffset((i - 1) * 118, 0),
			BackgroundColor3 = Color3.fromHex("#0C0D10"),
			BackgroundTransparency = 0.1,
			ZIndex = 16,
		}, grid)
		local stroke = Theme.stroke(tile, C.goldDim, 1.5)
		Theme.gradient(tile, { def and Color3.fromHex(def.accent):Lerp(Color3.new(0, 0, 0), 0.7) or Color3.fromHex("#222222"), Color3.fromHex("#050506") }, 90)
		if def then
			Portrait.create(tile, def.look, {
				framing = "head",
				style = Poses.STYLE_OF[def.stance] or "unarmed",
				Size = UDim2.new(1, -4, 1, -26),
				Position = UDim2.fromOffset(2, 2),
				ZIndex = 17,
			})
		else
			Theme.label(tile, "?", {
				Size = UDim2.new(1, 0, 1, -24),
				TextXAlignment = Enum.TextXAlignment.Center,
				FontFace = F.display,
				TextSize = 70,
				TextColor3 = C.gold,
				ZIndex = 17,
			})
		end
		Theme.label(tile, def and def.short or "RANDOM", {
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.new(0, 0, 1, -22),
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = F.labelBold,
			TextSize = 13,
			TextColor3 = C.text,
			BackgroundTransparency = 0.3,
			BackgroundColor3 = Color3.new(0, 0, 0),
			ZIndex = 18,
		})
		tiles[i] = { button = tile, stroke = stroke, def = def }
	end

	-- big preview
	local side = opts.side or 1
	local pv = Theme.frame(f, {
		Size = UDim2.fromOffset(620, 640),
		Position = side == 1 and UDim2.new(0, 40, 0, 120) or UDim2.new(1, -40, 0, 120),
		AnchorPoint = Vector2.new(side == 1 and 0 or 1, 0),
		ZIndex = 14,
	})
	local nameL = Theme.label(f, "", {
		Size = UDim2.fromOffset(700, 70),
		Position = side == 1 and UDim2.new(0, 70, 0, 560) or UDim2.new(1, -70, 0, 560),
		AnchorPoint = Vector2.new(side == 1 and 0 or 1, 0),
		TextXAlignment = side == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
		FontFace = F.display,
		TextSize = 64,
		TextColor3 = C.ivory,
		ZIndex = 16,
	})
	Theme.textStroke(nameL, 2, 0.2)
	local titleL = Theme.label(f, "", {
		Size = UDim2.fromOffset(700, 30),
		Position = side == 1 and UDim2.new(0, 72, 0, 628) or UDim2.new(1, -72, 0, 628),
		AnchorPoint = Vector2.new(side == 1 and 0 or 1, 0),
		TextXAlignment = side == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
		FontFace = F.labelBold,
		TextSize = 18,
		TextColor3 = C.gold,
		ZIndex = 16,
	})
	-- info panel opposite the preview
	local info = Theme.panel(f, {
		Size = UDim2.fromOffset(520, 300),
		Position = side == 1 and UDim2.new(1, -50, 0, 170) or UDim2.new(0, 50, 0, 170),
		AnchorPoint = Vector2.new(side == 1 and 1 or 0, 0),
		ZIndex = 15,
	})
	local infoText = Theme.label(info, "", {
		Size = UDim2.new(1, -40, 1, -30),
		Position = UDim2.fromOffset(20, 15),
		FontFace = F.serif,
		TextSize = 22,
		TextWrapped = true,
		RichText = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = C.text,
		ZIndex = 16,
	})

	-- the other side's locked-in pick
	if opts.other then
		local od = Fighters.get(opts.other.fighter)
		local ostyle = Poses.STYLE_OF[od.stance] or "unarmed"
		local opv = Portrait.create(f, od.look, {
			framing = "full",
			style = ostyle,
			pose = Poses.WIN[ostyle],
			facing = side == 1 and -1 or 1,
			yaw = 35,
			Size = UDim2.fromOffset(420, 520),
			Position = side == 1 and UDim2.new(1, -60, 0, 120) or UDim2.new(0, 60, 0, 120),
			AnchorPoint = Vector2.new(side == 1 and 1 or 0, 0),
			ZIndex = 13,
		})
		opv.frame.ImageTransparency = 0.35
		info.Position = side == 1 and UDim2.new(1, -50, 0, 640) or UDim2.new(0, 50, 0, 640)
		info.Size = UDim2.fromOffset(520, 100)
		infoText.TextSize = 18
	end

	local preview = nil
	local sel = opts.start or 1
	local function updatePreview()
		for i, t in tiles do
			t.stroke.Color = (i == sel) and C.goldBright or C.goldDim
			t.stroke.Thickness = (i == sel) and 3 or 1.5
			t.button.Size = (i == sel) and UDim2.fromOffset(108, 136) or UDim2.fromOffset(108, 128)
			t.button.Position = UDim2.fromOffset((i - 1) * 118, (i == sel) and -8 or 0)
		end
		local def = tiles[sel].def
		if preview then
			preview:destroy()
			preview = nil
		end
		if def then
			local style = Poses.STYLE_OF[def.stance] or "unarmed"
			preview = Portrait.create(pv, def.look, {
				framing = "full",
				style = style,
				facing = side == 1 and 1 or -1,
				yaw = 35,
				fov = 32,
				ZIndex = 14,
			})
			preview.def = def
			nameL.Text = def.name
			titleL.Text = string.upper(def.title) .. "   \u{00B7}   " .. string.upper(def.archetype)
			if opts.other then
				infoText.Text = def.bio
			else
				infoText.Text = string.format(
					"<font color='#C9A24A'>REALM</font>  %s\n<font color='#C9A24A'>SUPER</font>  %s\n<font color='#C9A24A'>FINISHER</font>  %s\n\n%s",
					def.realm,
					def.superName,
					def.finisher.name,
					def.bio
				)
			end
		else
			nameL.Text = "RANDOM"
			titleL.Text = "LET THE ALGORITHM DECIDE"
			infoText.Text = "A random fighter will be chosen."
		end
	end
	updatePreview()
	local spinConn = RunService.RenderStepped:Connect(function()
		if preview then
			local p = Poses.idle(preview.style, os.clock())
			preview:setPose(p, os.clock())
		end
	end)
	hintBar(f, { { "left", "" }, { "right", "BROWSE" }, { "confirm", "SELECT" }, { "back", "BACK" } })
	fadeIn(f)

	local w = waiter()
	local conns = connections()
	local function move(d: number)
		sel = ((sel - 1 + d) % count) + 1
		Audio.ui("ui_move")
		updatePreview()
	end
	for i, t in tiles do
		conns.add(t.button.MouseEnter:Connect(function()
			if Input.mode ~= "touch" and sel ~= i then
				sel = i
				Audio.ui("ui_move")
				updatePreview()
			end
		end))
		conns.add(t.button.Activated:Connect(function()
			if sel == i then
				w.resolve(i)
			else
				sel = i
				Audio.ui("ui_move")
				updatePreview()
			end
		end))
	end
	conns.add(Input.nav.Event:Connect(function(a)
		if a == "left" or a == "up" then
			move(-1)
		elseif a == "right" or a == "down" then
			move(1)
		elseif a == "confirm" then
			w.resolve(sel)
		elseif a == "back" then
			w.resolve(nil)
		end
	end))
	local r = w.wait()
	conns.clear()
	spinConn:Disconnect()
	if r then
		Audio.ui("ui_lock")
		local def = tiles[r].def
		if not def then
			def = list[math.random(1, #list)]
		end
		nameL.Text = def.name
		Theme.tween(nameL, 0.1, { TextColor3 = C.goldBright })
		task.wait(0.35)
		f:Destroy()
		return def.id
	end
	Audio.ui("ui_back")
	f:Destroy()
	return nil
end

local function echoPicker(root: Instance, fighterId: string, side: number?)
	local f = screenFrame(root, "EchoSelect")
	backdrop(f, 0.78)
	title(f, "CALL A FRIEND", "YOUR ONE (1) FRIEND WHO SHOWS UP MID-FIGHT")
	local def = Fighters.get(fighterId)
	local style = Poses.STYLE_OF[def.stance] or "unarmed"
	Portrait.create(f, def.look, {
		framing = "full",
		style = style,
		pose = Poses.stance(style),
		facing = 1,
		yaw = 35,
		Size = UDim2.fromOffset(420, 560),
		Position = UDim2.new(0, 30, 0, 150),
		ZIndex = 13,
	})
	local row = Theme.frame(f, {
		Size = UDim2.fromOffset(4 * 230, 360),
		Position = UDim2.new(0.5, 120, 0, 190),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 15,
	})
	local items = {}
	for i, e in Echoes.list do
		local card = new("TextButton", {
			AutoButtonColor = false,
			Text = "",
			Size = UDim2.fromOffset(210, 340),
			Position = UDim2.fromOffset((i - 1) * 230, 0),
			BackgroundColor3 = Color3.fromHex("#0C0D10"),
			BackgroundTransparency = 0.15,
			ZIndex = 16,
		}, row)
		local stroke = Theme.stroke(card, C.goldDim, 1.5)
		Theme.gradient(card, { Color3.fromHex(e.accent):Lerp(Color3.new(0, 0, 0), 0.75), Color3.fromHex("#050506") }, 90)
		Portrait.create(card, e.look, {
			framing = "bust",
			style = "unarmed",
			spectral = Color3.fromHex(e.accent),
			Size = UDim2.new(1, 0, 0, 220),
			ZIndex = 17,
		})
		Theme.label(card, e.name, {
			Size = UDim2.new(1, -16, 0, 50),
			Position = UDim2.fromOffset(8, 222),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			FontFace = F.display,
			TextSize = 24,
			TextColor3 = C.ivory,
			ZIndex = 17,
		})
		Theme.label(card, string.upper(e.title), {
			Size = UDim2.new(1, -16, 0, 24),
			Position = UDim2.fromOffset(8, 274),
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = F.labelBold,
			TextSize = 12,
			TextColor3 = Color3.fromHex(e.accent),
			ZIndex = 17,
		})
		items[i] = { button = card, stroke = stroke, echo = e }
	end
	local info = Theme.panel(f, {
		Size = UDim2.fromOffset(920, 150),
		Position = UDim2.new(0.5, 120, 0, 580),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 15,
	})
	local infoText = Theme.label(info, "", {
		Size = UDim2.new(1, -40, 1, -24),
		Position = UDim2.fromOffset(20, 12),
		FontFace = F.serif,
		TextSize = 21,
		RichText = true,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 16,
	})
	local sel = 1
	local function refresh()
		for i, it in items do
			it.stroke.Color = i == sel and C.goldBright or C.goldDim
			it.stroke.Thickness = i == sel and 3 or 1.5
			it.button.Position = UDim2.fromOffset((i - 1) * 230, i == sel and -10 or 0)
		end
		local e = items[sel].echo
		infoText.Text = string.format(
			"%s\n<font color='#C9A24A'>%s</font>  %s      <font color='#C9A24A'>%s</font>  %s",
			e.bio,
			"[" .. Input.glyph("E") .. "]",
			e.neutral.name,
			"[" .. Input.glyph("down") .. " + " .. Input.glyph("E") .. "]",
			e.down.name
		)
	end
	refresh()
	hintBar(f, { { "left", "" }, { "right", "BROWSE" }, { "confirm", "BRING THEM" }, { "back", "BACK" } })
	fadeIn(f)
	local w = waiter()
	local conns = connections()
	for i, it in items do
		conns.add(it.button.MouseEnter:Connect(function()
			if Input.mode ~= "touch" and sel ~= i then
				sel = i
				Audio.ui("ui_move")
				refresh()
			end
		end))
		conns.add(it.button.Activated:Connect(function()
			if sel == i then
				w.resolve(i)
			else
				sel = i
				refresh()
			end
		end))
	end
	conns.add(Input.nav.Event:Connect(function(a)
		if a == "left" or a == "up" then
			sel = (sel - 2) % #items + 1
			Audio.ui("ui_move")
			refresh()
		elseif a == "right" or a == "down" then
			sel = sel % #items + 1
			Audio.ui("ui_move")
			refresh()
		elseif a == "confirm" then
			w.resolve(sel)
		elseif a == "back" then
			w.resolve(nil)
		end
	end))
	local r = w.wait()
	conns.clear()
	local _ = side
	f:Destroy()
	if r then
		Audio.ui("ui_lock")
		Audio.play("echo_summon", { group = "ui", volume = 0.6 })
		return items[r].echo.id
	end
	Audio.ui("ui_back")
	return nil
end

-- Full selection flow: fighter -> echo (-> opponent). Returns { fighter, echo, opp, oppEcho } or nil.
function Screens.characterSelect(root: Instance, opts)
	opts = opts or {}
	Audio.music("music_select")
	local step = 1
	local result = {}
	while true do
		if step == 1 then
			local id = fighterPicker(root, { title = opts.title or "CHOOSE YOUR FIGHTER", subtitle = opts.subtitle, side = 1, start = opts.startIndex })
			if not id then
				return nil
			end
			result.fighter = id
			step = 2
		elseif step == 2 then
			local e = echoPicker(root, result.fighter, 1)
			if not e then
				step = 1
			else
				result.echo = e
				step = opts.pickOpponent and 3 or 4
			end
		elseif step == 3 then
			local id = fighterPicker(root, {
				title = "CHOOSE YOUR OPPONENT",
				subtitle = "THE CPU WILL FIGHT AS THIS CHALLENGER",
				side = 2,
				other = { fighter = result.fighter },
			})
			if not id then
				step = 2
			else
				result.opp = id
				local echoes = Echoes.list
				result.oppEcho = echoes[math.random(1, #echoes)].id
				step = 4
			end
		else
			return result
		end
	end
end

-------------------------------------------------------------------------------
-- Stage + difficulty select
-------------------------------------------------------------------------------

-- opts.online: no CPU difficulty; the title explains the map coin flip
function Screens.stageSelect(root: Instance, defaultDifficulty: number?, opts)
	opts = opts or {}
	local f = screenFrame(root, "StageSelect")
	backdrop(f, 0.85)
	title(f, opts.online and "PICK YOUR MAP" or "PICK A SERVER", opts.online and "YOUR RIVAL PICKS ONE TOO. IF THEY DIFFER, THE SERVER FLIPS A COIN." or nil)
	local stages = {}
	for _, id in Stages.selectable do
		table.insert(stages, Stages.get(id))
	end
	local hero = Theme.frame(f, {
		Size = UDim2.fromOffset(1000, 470),
		Position = UDim2.new(0.5, 0, 0, 160),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromHex("#050506"),
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		ZIndex = 14,
	})
	Theme.stroke(hero, C.gold, 2)
	local heroImg = Theme.image(hero, "", { Size = UDim2.fromScale(1, 1), ZIndex = 14 })
	local heroShade = Theme.frame(hero, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 15 })
	Theme.gradient(heroShade, { Color3.new(0, 0, 0), Color3.new(0, 0, 0) }, 90, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.55, 0.8),
		NumberSequenceKeypoint.new(1, 0.1),
	}))
	local heroName = Theme.label(hero, "", {
		Size = UDim2.new(1, -60, 0, 70),
		Position = UDim2.new(0, 30, 1, -120),
		FontFace = F.display,
		TextSize = 60,
		TextColor3 = C.ivory,
		ZIndex = 16,
	})
	Theme.textStroke(heroName, 2, 0.2)
	local heroDesc = Theme.label(hero, "", {
		Size = UDim2.new(1, -60, 0, 40),
		Position = UDim2.new(0, 32, 1, -52),
		FontFace = F.serif,
		TextSize = 22,
		TextColor3 = C.text,
		ZIndex = 16,
	})
	local strip = Theme.frame(f, {
		Size = UDim2.fromOffset((#stages + 1) * 196, 110),
		Position = UDim2.new(0.5, 0, 0, 650),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 15,
	})
	local cards = {}
	for i = 1, #stages + 1 do
		local s = stages[i]
		local card = new("TextButton", {
			AutoButtonColor = false,
			Text = "",
			Size = UDim2.fromOffset(184, 104),
			Position = UDim2.fromOffset((i - 1) * 196, 0),
			BackgroundColor3 = Color3.fromHex("#0C0D10"),
			BackgroundTransparency = 0,
			ClipsDescendants = true,
			ZIndex = 16,
		}, strip)
		local stroke = Theme.stroke(card, C.goldDim, 1.5)
		if s then
			local img = Assets.image(s.backdrop)
			if img ~= "" then
				Theme.image(card, img, { Size = UDim2.fromScale(1, 1), ZIndex = 16 })
			else
				Theme.gradient(card, { Color3.fromHex(s.accent):Lerp(Color3.new(0, 0, 0), 0.5), Color3.fromHex("#050506") }, 90)
			end
		end
		Theme.label(card, s and s.name or "RANDOM", {
			Size = UDim2.new(1, -8, 0, 24),
			Position = UDim2.new(0, 4, 1, -24),
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = F.labelBold,
			TextSize = 12,
			TextScaled = false,
			TextColor3 = C.ivory,
			BackgroundTransparency = 0.25,
			BackgroundColor3 = Color3.new(0, 0, 0),
			ZIndex = 17,
		})
		cards[i] = { button = card, stroke = stroke, stage = s }
	end
	-- difficulty selector
	local diff = defaultDifficulty or 2
	local diffL = Theme.label(f, "", {
		Size = UDim2.fromOffset(700, 34),
		Position = UDim2.new(0.5, 0, 0, 772),
		AnchorPoint = Vector2.new(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.labelBold,
		TextSize = 22,
		TextColor3 = C.goldBright,
		ZIndex = 16,
	})
	local diffLeft = new("TextButton", { Text = "\u{25C0}", FontFace = F.labelBold, TextSize = 24, TextColor3 = C.gold, BackgroundTransparency = 1, Size = UDim2.fromOffset(50, 34), Position = UDim2.new(0.5, -300, 0, 772), ZIndex = 17 }, f)
	local diffRight = new("TextButton", { Text = "\u{25B6}", FontFace = F.labelBold, TextSize = 24, TextColor3 = C.gold, BackgroundTransparency = 1, Size = UDim2.fromOffset(50, 34), Position = UDim2.new(0.5, 250, 0, 772), ZIndex = 17 }, f)
	local function refreshDiff()
		diffL.Text = "CPU DIFFICULTY:  " .. Config.Difficulty[diff].name .. "   [" .. Input.glyph("tabL") .. " / " .. Input.glyph("tabR") .. "]"
	end
	if opts.online then
		diffL.Visible = false
		diffLeft.Visible = false
		diffRight.Visible = false
	end
	refreshDiff()
	local sel = 1
	local function refresh()
		for i, c in cards do
			c.stroke.Color = i == sel and C.goldBright or C.goldDim
			c.stroke.Thickness = i == sel and 3 or 1.5
		end
		local s = cards[sel].stage
		if s then
			heroImg.Image = Assets.image(s.backdrop)
			heroImg.BackgroundColor3 = Color3.fromHex(s.fogColor)
			heroImg.BackgroundTransparency = heroImg.Image == "" and 0 or 1
			heroName.Text = s.name
			heroDesc.Text = s.desc
		else
			heroImg.Image = Assets.image("KeyArt")
			heroImg.BackgroundTransparency = 1
			heroName.Text = "RANDOM SERVER"
			heroDesc.Text = "Server hopping. The noble way."
		end
	end
	refresh()
	hintBar(f, { { "left", "" }, { "right", "BROWSE" }, { "tabL", "" }, { "tabR", "DIFFICULTY" }, { "confirm", "FIGHT" }, { "back", "BACK" } })
	fadeIn(f)
	local w = waiter()
	local conns = connections()
	for i, c in cards do
		conns.add(c.button.Activated:Connect(function()
			if sel == i then
				w.resolve(i)
			else
				sel = i
				Audio.ui("ui_move")
				refresh()
			end
		end))
		conns.add(c.button.MouseEnter:Connect(function()
			if Input.mode ~= "touch" and sel ~= i then
				sel = i
				Audio.ui("ui_move")
				refresh()
			end
		end))
	end
	conns.add(diffLeft.Activated:Connect(function()
		diff = math.max(1, diff - 1)
		Audio.ui("ui_move")
		refreshDiff()
	end))
	conns.add(diffRight.Activated:Connect(function()
		diff = math.min(#Config.Difficulty, diff + 1)
		Audio.ui("ui_move")
		refreshDiff()
	end))
	conns.add(Input.nav.Event:Connect(function(a)
		if a == "left" or a == "up" then
			sel = (sel - 2) % #cards + 1
			Audio.ui("ui_move")
			refresh()
		elseif a == "right" or a == "down" then
			sel = sel % #cards + 1
			Audio.ui("ui_move")
			refresh()
		elseif a == "tabL" then
			diff = math.max(1, diff - 1)
			Audio.ui("ui_move")
			refreshDiff()
		elseif a == "tabR" then
			diff = math.min(#Config.Difficulty, diff + 1)
			Audio.ui("ui_move")
			refreshDiff()
		elseif a == "confirm" then
			w.resolve(sel)
		elseif a == "back" then
			w.resolve(nil)
		end
	end))
	local r = w.wait()
	conns.clear()
	f:Destroy()
	if not r then
		Audio.ui("ui_back")
		return nil
	end
	Audio.ui("ui_lock")
	local s = cards[r].stage
	if not s then
		s = stages[math.random(1, #stages)]
	end
	return s.id, diff
end

-------------------------------------------------------------------------------
-- Versus splash
-------------------------------------------------------------------------------

function Screens.versus(root: Instance, p1, p2, stageId: string, subtitle: string?)
	local f = screenFrame(root, "Versus")
	local d1 = Fighters.get(p1.fighter)
	local d2 = Fighters.get(p2.fighter)
	local e1 = Echoes.get(p1.echo)
	local e2 = Echoes.get(p2.echo)
	local bg = Theme.frame(f, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BackgroundTransparency = 0, ZIndex = 10 })
	local _ = bg
	for side, def in { d1, d2 } do
		local half = Theme.frame(f, {
			Size = UDim2.fromScale(0.62, 1.4),
			Position = UDim2.fromScale(side == 1 and -0.12 or 1.12, 0.5),
			AnchorPoint = Vector2.new(side == 1 and 0 or 1, 0.5),
			Rotation = 8,
			BackgroundColor3 = Color3.fromHex(def.accent),
			BackgroundTransparency = 0,
			ClipsDescendants = true,
			ZIndex = 11,
		})
		Theme.gradient(half, { Color3.fromHex(def.accent):Lerp(Color3.new(0, 0, 0), 0.55), Color3.new(0, 0, 0) }, side == 1 and 0 or 180)
		Theme.tween(half, 0.5, { Position = UDim2.fromScale(side == 1 and -0.08 or 1.08, 0.5) }, Enum.EasingStyle.Quart)
		local style = Poses.STYLE_OF[def.stance] or "unarmed"
		local por = Portrait.create(f, def.look, {
			framing = "full",
			style = style,
			pose = Poses.WIN[style],
			facing = side == 1 and 1 or -1,
			yaw = 30,
			fov = 30,
			Size = UDim2.fromOffset(620, 860),
			Position = side == 1 and UDim2.new(0, -20, 1, 0) or UDim2.new(1, 20, 1, 0),
			AnchorPoint = Vector2.new(side == 1 and 0 or 1, 1),
			ZIndex = 12,
		})
		por.frame.Position = side == 1 and UDim2.new(0, -320, 1, 0) or UDim2.new(1, 320, 1, 0)
		Theme.tween(por.frame, 0.6, { Position = side == 1 and UDim2.new(0, -20, 1, 0) or UDim2.new(1, 20, 1, 0) }, Enum.EasingStyle.Quart)
		local nm = Theme.label(f, def.name, {
			Size = UDim2.fromOffset(700, 80),
			Position = side == 1 and UDim2.new(0, 60, 1, -170) or UDim2.new(1, -60, 1, -170),
			AnchorPoint = Vector2.new(side == 1 and 0 or 1, 0),
			TextXAlignment = side == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
			FontFace = F.display,
			TextSize = 76,
			TextColor3 = C.ivory,
			ZIndex = 14,
		})
		Theme.textStroke(nm, 3, 0.1)
		Theme.label(f, "\u{2726} " .. (side == 1 and e1 or e2).name, {
			Size = UDim2.fromOffset(700, 30),
			Position = side == 1 and UDim2.new(0, 64, 1, -92) or UDim2.new(1, -64, 1, -92),
			AnchorPoint = Vector2.new(side == 1 and 0 or 1, 0),
			TextXAlignment = side == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
			FontFace = F.labelBold,
			TextSize = 20,
			TextColor3 = Color3.fromHex((side == 1 and e1 or e2).accent),
			ZIndex = 14,
		})
	end
	local vs = Theme.label(f, "VS", {
		Size = UDim2.fromOffset(400, 220),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.display,
		TextSize = 210,
		TextColor3 = C.goldBright,
		TextTransparency = 1,
		ZIndex = 15,
	})
	Theme.gradient(vs, { Color3.fromHex("#FFF6DE"), Color3.fromHex("#B07A1A") }, 90)
	Theme.textStroke(vs, 4, 0.1)
	local sc = new("UIScale", { Scale = 2.4 }, vs)
	task.delay(0.35, function()
		Theme.tween(vs, 0.2, { TextTransparency = 0 })
		Theme.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		Audio.play("ui_versus", { group = "ui", volume = 0.9 })
	end)
	local st = Stages.get(stageId)
	Theme.label(f, string.upper(subtitle or st.name), {
		Size = UDim2.fromOffset(800, 30),
		Position = UDim2.new(0.5, 0, 0, 40),
		AnchorPoint = Vector2.new(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.labelBold,
		TextSize = 22,
		TextColor3 = C.gold,
		ZIndex = 15,
	})
	task.wait(3.0)
	local cover = Screens.fadeToBlack(root, 0.35)
	f:Destroy()
	return cover
end

-------------------------------------------------------------------------------
-- Ascent ladder / chapter card / ending
-------------------------------------------------------------------------------

function Screens.ladder(root: Instance, ladder, index: number, playerId: string)
	local f = screenFrame(root, "Ladder")
	backdrop(f, 0.8)
	title(f, "THE TOWER", string.format("TRYHARD %d OF %d", index, #ladder))
	local tower = Theme.frame(f, {
		Size = UDim2.fromOffset(300, #ladder * 98),
		Position = UDim2.new(0.5, 280, 0.55, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 15,
	})
	for i = #ladder, 1, -1 do
		local def = Fighters.get(ladder[i].fighter)
		local y = (#ladder - i) * 98
		local cell = Theme.frame(tower, {
			Size = UDim2.fromOffset(300, 88),
			Position = UDim2.fromOffset(0, y),
			BackgroundColor3 = Color3.fromHex("#0C0D10"),
			BackgroundTransparency = i < index and 0.6 or 0.15,
			ZIndex = 16,
		})
		Theme.stroke(cell, i == index and C.goldBright or C.goldDim, i == index and 3 or 1.2)
		Portrait.create(cell, def.look, {
			framing = "head",
			style = Poses.STYLE_OF[def.stance] or "unarmed",
			Size = UDim2.fromOffset(84, 84),
			Position = UDim2.fromOffset(2, 2),
			ZIndex = 17,
		})
		Theme.label(cell, def.name, {
			Size = UDim2.new(1, -100, 1, 0),
			Position = UDim2.fromOffset(96, 0),
			FontFace = F.display,
			TextSize = i == #ladder and 26 or 28,
			TextColor3 = i < index and C.textDim or (i == index and C.goldBright or C.ivory),
			ZIndex = 17,
		})
		if i < index then
			Theme.label(cell, "\u{2715}", {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Right,
				FontFace = F.display,
				TextSize = 50,
				TextColor3 = C.crimson,
				ZIndex = 18,
			})
		end
	end
	local pdef = Fighters.get(playerId)
	local style = Poses.STYLE_OF[pdef.stance] or "unarmed"
	Portrait.create(f, pdef.look, {
		framing = "full",
		style = style,
		pose = Poses.stance(style),
		facing = 1,
		yaw = 30,
		Size = UDim2.fromOffset(520, 700),
		Position = UDim2.new(0.5, -250, 1, -30),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 14,
	})
	hintBar(f, { { "confirm", "BEGIN" }, { "back", "ABANDON" } })
	fadeIn(f)
	local w = waiter()
	local c = Input.nav.Event:Connect(function(a)
		if a == "confirm" then
			w.resolve("go")
		elseif a == "back" then
			w.resolve("quit")
		end
	end)
	local c2 = Input.anyPressed.Event:Connect(function()
		if Input.mode == "touch" then
			w.resolve("go")
		end
	end)
	local auto = task.delay(6, function()
		w.resolve("go")
	end)
	local r = w.wait()
	c:Disconnect()
	c2:Disconnect()
	pcall(task.cancel, auto)
	Audio.ui(r == "go" and "ui_confirm" or "ui_back")
	f:Destroy()
	return r
end

function Screens.card(root: Instance, heading: string, name: string, body: string, opts)
	opts = opts or {}
	local f = screenFrame(root, "Card")
	backdrop(f, opts.darkness or 0.6)
	local h = Theme.label(f, heading, {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.labelBold,
		TextSize = 26,
		TextColor3 = C.gold,
		TextTransparency = 1,
		ZIndex = 16,
	})
	local n = Theme.label(f, name, {
		Size = UDim2.new(1, 0, 0, 100),
		Position = UDim2.new(0.5, 0, 0.3, 64),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.display,
		TextSize = 92,
		TextColor3 = C.ivory,
		TextTransparency = 1,
		ZIndex = 16,
	})
	Theme.textStroke(n, 2, 0.3)
	Theme.rule(f, { Size = UDim2.fromOffset(700, 1), Position = UDim2.new(0.5, 0, 0.3, 122), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 16 })
	local b = Theme.label(f, body, {
		Size = UDim2.fromOffset(1100, 300),
		Position = UDim2.new(0.5, 0, 0.3, 150),
		AnchorPoint = Vector2.new(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		FontFace = F.serif,
		TextSize = 30,
		TextColor3 = C.text,
		TextTransparency = 1,
		ZIndex = 16,
	})
	Theme.textStroke(b, 1.5, 0.4)
	hintBar(f, { { "confirm", opts.confirmText or "CONTINUE" } })
	fadeIn(f)
	Theme.tween(h, 1, { TextTransparency = 0 })
	task.delay(0.4, function()
		Theme.tween(n, 1.2, { TextTransparency = 0 })
	end)
	task.delay(1.0, function()
		Theme.tween(b, 1.2, { TextTransparency = 0 })
	end)
	task.wait(1.2)
	local w = waiter()
	local c = Input.nav.Event:Connect(function(a)
		if a == "confirm" or a == "back" then
			w.resolve(a)
		end
	end)
	local c2 = Input.anyPressed.Event:Connect(function()
		if Input.mode == "touch" then
			w.resolve("confirm")
		end
	end)
	local r = w.wait()
	c:Disconnect()
	c2:Disconnect()
	Audio.ui("ui_confirm")
	local cover = Screens.fadeToBlack(root, 0.4)
	f:Destroy()
	Screens.fadeFromBlack(cover, 0.4)
	return r
end

function Screens.ending(root: Instance, fighterId: string)
	local def = Fighters.get(fighterId)
	Audio.music("music_victory")
	for i, para in def.ending do
		Screens.card(root, i == 1 and "TOWER CLEARED" or "", i == 1 and def.name or "", para, { darkness = 0.7 })
	end
end

-------------------------------------------------------------------------------
-- Pause
-------------------------------------------------------------------------------

function Screens.pause(root: Instance, opts)
	opts = opts or {}
	local f = screenFrame(root, "Pause")
	f.ZIndex = 70
	local dim = Theme.frame(f, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, ZIndex = 70 })
	local _ = dim
	local panel = Theme.panel(f, {
		Size = UDim2.fromOffset(560, 560),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 71,
	})
	panel.ZIndex = 71
	Theme.label(panel, "PAUSED", {
		Size = UDim2.new(1, 0, 0, 80),
		Position = UDim2.fromOffset(0, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.display,
		TextSize = 60,
		TextColor3 = C.ivory,
		ZIndex = 72,
	})
	Theme.rule(panel, { Size = UDim2.fromOffset(400, 1), Position = UDim2.new(0.5, 0, 0, 100), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 72 })
	local entries = { { "resume", "RESUME" }, { "restart", "RESTART MATCH" }, { "movelist", "MOVE LIST" }, { "settings", "SETTINGS" }, { "quit", opts.quitText or "QUIT TO MENU" } }
	if opts.noRestart then
		table.remove(entries, 2)
	end
	local list = Theme.frame(panel, { Size = UDim2.fromOffset(500, 400), Position = UDim2.fromOffset(40, 120), ZIndex = 72 })
	local items = {}
	for i, e in entries do
		local it = menuItem(list, e[2], (i - 1) * 66, 38)
		it.button.ZIndex = 73
		it.label.ZIndex = 74
		items[i] = it
	end
	local r = runList(items, { allowBack = true })
	f:Destroy()
	if not r then
		return "resume"
	end
	return entries[r][1]
end

-------------------------------------------------------------------------------
-- Results
-------------------------------------------------------------------------------

function Screens.results(root: Instance, result, opts)
	opts = opts or {}
	local f = screenFrame(root, "Results")
	backdrop(f, 0.8)
	local wDef = Fighters.get(result.winner == 1 and result.p1.fighter or result.p2.fighter)
	local won = result.winner == 1
	local style = Poses.STYLE_OF[wDef.stance] or "unarmed"
	Portrait.create(f, wDef.look, {
		framing = "full",
		style = style,
		pose = Poses.WIN[style],
		facing = 1,
		yaw = 30,
		Size = UDim2.fromOffset(560, 780),
		Position = UDim2.new(0, 20, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		ZIndex = 13,
	})
	local head = Theme.label(f, won and "BIG W" or "TAKE THE L", {
		Size = UDim2.fromOffset(800, 110),
		Position = UDim2.new(0, 600, 0, 60),
		FontFace = F.display,
		TextSize = 110,
		TextColor3 = won and C.goldBright or C.crimsonBright,
		ZIndex = 16,
	})
	Theme.textStroke(head, 3, 0.2)
	Theme.label(f, wDef.name .. " WINS", {
		Size = UDim2.fromOffset(800, 40),
		Position = UDim2.new(0, 606, 0, 168),
		FontFace = F.labelBold,
		TextSize = 26,
		TextColor3 = C.ivory,
		ZIndex = 16,
	})
	local quote = wDef.victory[1]
	Theme.label(f, "\u{201C}" .. quote .. "\u{201D}", {
		Size = UDim2.fromOffset(820, 40),
		Position = UDim2.new(0, 606, 0, 210),
		FontFace = F.serif,
		TextSize = 26,
		TextColor3 = C.text,
		ZIndex = 16,
	})
	-- stats table
	local stats = Theme.panel(f, { Size = UDim2.fromOffset(820, 340), Position = UDim2.new(0, 600, 0, 270), ZIndex = 15 })
	local rows = {
		{ "DAMAGE DEALT", "damage" },
		{ "HITS LANDED", "hits" },
		{ "BEST COMBO", "maxCombo" },
		{ "SPECIALS", "specials" },
		{ "SUPERS", "supers" },
		{ "ECHO SUMMONS", "echoes" },
		{ "THROWS", "throws" },
		{ "BLOCKS", "blocks" },
	}
	local d1 = Fighters.get(result.p1.fighter)
	local d2 = Fighters.get(result.p2.fighter)
	Theme.label(stats, d1.short, { Size = UDim2.fromOffset(200, 34), Position = UDim2.fromOffset(380, 10), TextXAlignment = Enum.TextXAlignment.Center, FontFace = F.labelBold, TextSize = 18, TextColor3 = Color3.fromHex(d1.accent), ZIndex = 16 })
	Theme.label(stats, d2.short, { Size = UDim2.fromOffset(200, 34), Position = UDim2.fromOffset(600, 10), TextXAlignment = Enum.TextXAlignment.Center, FontFace = F.labelBold, TextSize = 18, TextColor3 = Color3.fromHex(d2.accent), ZIndex = 16 })
	for i, row in rows do
		local y = 44 + (i - 1) * 35
		Theme.label(stats, row[1], { Size = UDim2.fromOffset(340, 30), Position = UDim2.fromOffset(30, y), FontFace = F.label, TextSize = 17, TextColor3 = C.textDim, ZIndex = 16 })
		for side = 1, 2 do
			local v = result.stats[side][row[2]] or 0
			Theme.label(stats, tostring(math.floor(v)), {
				Size = UDim2.fromOffset(200, 30),
				Position = UDim2.fromOffset(side == 1 and 380 or 600, y),
				TextXAlignment = Enum.TextXAlignment.Center,
				FontFace = F.labelBold,
				TextSize = 19,
				TextColor3 = C.ivory,
				ZIndex = 16,
			})
		end
	end
	local entries = opts.entries or { { "rematch", "REMATCH" }, { "select", "CHARACTER SELECT" }, { "menu", "MAIN MENU" } }
	local list = Theme.frame(f, { Size = UDim2.fromOffset(600, 230), Position = UDim2.new(0, 600, 0, 630), ZIndex = 15 })
	local items = {}
	for i, e in entries do
		items[i] = menuItem(list, e[2], (i - 1) * 58, 36)
	end
	fadeIn(f)
	local r = runList(items, { allowBack = false })
	f:Destroy()
	return entries[r][1]
end

-------------------------------------------------------------------------------
-- Move list
-------------------------------------------------------------------------------

function Screens.moveList(root: Instance, startFighter: string?)
	local f = screenFrame(root, "MoveList")
	f.ZIndex = 75
	backdrop(f, 0.88)
	local idx = 1
	if startFighter then
		for i, d in Fighters.list do
			if d.id == startFighter then
				idx = i
			end
		end
	end
	local header = Theme.label(f, "", {
		Size = UDim2.new(1, 0, 0, 70),
		Position = UDim2.fromOffset(0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.display,
		TextSize = 60,
		TextColor3 = C.ivory,
		ZIndex = 16,
	})
	local sub = Theme.label(f, "", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 100),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.labelBold,
		TextSize = 18,
		TextColor3 = C.gold,
		ZIndex = 16,
	})
	local scroll = new("ScrollingFrame", {
		Size = UDim2.fromOffset(1300, 640),
		Position = UDim2.new(0.5, 0, 0, 150),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromHex("#08090C"),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.gold,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 16,
	}, f)
	Theme.stroke(scroll, C.goldDim, 1.2)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	new("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingTop = UDim.new(0, 12) }, scroll)
	local function section(text: string, order: number)
		Theme.label(scroll, text, {
			Size = UDim2.new(1, 0, 0, 42),
			FontFace = F.display,
			TextSize = 30,
			TextColor3 = C.goldBright,
			LayoutOrder = order,
			ZIndex = 17,
		})
	end
	local function row(name: string, input: string, desc: string, order: number)
		local r = Theme.frame(scroll, { Size = UDim2.new(1, 0, 0, 52), LayoutOrder = order, ZIndex = 17, BackgroundColor3 = Color3.fromHex("#14151A"), BackgroundTransparency = 0.4 })
		Theme.label(r, name, { Size = UDim2.fromOffset(360, 28), Position = UDim2.fromOffset(12, 2), FontFace = F.serif, TextSize = 24, TextColor3 = C.ivory, ZIndex = 18 })
		Theme.label(r, input, { Size = UDim2.fromOffset(300, 28), Position = UDim2.fromOffset(380, 2), FontFace = F.labelBold, TextSize = 18, TextColor3 = C.gold, ZIndex = 18 })
		Theme.label(r, desc, { Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 28), FontFace = F.label, TextSize = 14, TextColor3 = C.textDim, ZIndex = 18 })
	end
	local function build()
		for _, ch in scroll:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		local def = Fighters.list[idx]
		header.Text = def.name
		sub.Text = string.upper(def.title) .. "   \u{00B7}   " .. string.upper(def.archetype)
		local order = 0
		local function nextOrder()
			order += 1
			return order
		end
		section("POWERS  \u{00B7}  KEYS 1-4 OR MOTION + " .. Input.glyph("S"), nextOrder())
		local slots = def.powers or Config.PowerSlots
		for _, id in { "SN", "SF", "SB", "SD", "SA" } do
			local m = def.moves[id]
			if m then
				local slot = table.find(slots, id)
				local keys = Input.formatNotation(m.input)
				local desc = MoveKit.describe(m)
				if slot then
					keys = "[" .. Input.glyph("P" .. slot) .. "]   or   " .. keys
					if Config.PowerCooldowns then
						local cd = Engine.powerCooldownFor(m)
						desc = desc .. "  \u{00B7}  Cooldown " .. string.format("%.1f", cd / 60) .. "s"
					end
				end
				row(m.name, keys, desc, nextOrder())
			end
		end
		section("SUPER  \u{00B7}  2 RAGE BARS", nextOrder())
		row(def.superName, Input.glyph("X") .. "  (2 RAGE BARS)", "Cinematic super. Invulnerable on startup. " .. MoveKit.describe(def.moves.SUPER), nextOrder())
		section("FINISHER", nextOrder())
		row(def.finisher.name, "HOLD " .. Input.glyph("down") .. " + " .. Input.glyph("S") .. " at DELETE THEM", def.finisher.desc, nextOrder())
		section("STRINGS & NORMALS", nextOrder())
		for _, id in { "L", "L2", "L3", "H", "H2", "K", "K2", "FH", "BK", "DL", "DH", "DK", "JL", "JH", "JK", "THROW" } do
			local m = def.moves[id]
			if m then
				row(m.name, Input.formatNotation(m.input), MoveKit.describe(m), nextOrder())
			end
		end
		section("SYSTEM", nextOrder())
		row("Call a Friend", Input.glyph("E") .. "  /  " .. Input.glyph("down") .. " + " .. Input.glyph("E"), "Your friend runs in and helps. Cooldown " .. tostring(math.floor(Config.EchoCooldown / 60)) .. "s.", nextOrder())
		row("Rage Quit", Input.glyph("X") .. " while being comboed", "Costs 1 Rage bar. Bursts you out of a combo.", nextOrder())
		row("Dash / Backdash", "\u{2192}\u{2192}  /  \u{2190}\u{2190}", "Double-tap a direction. Backdash is briefly invulnerable.", nextOrder())
		row("Throw", Input.glyph("THROW") .. "  (or " .. Input.glyph("B") .. " + " .. Input.glyph("L") .. ")", "Grab a blocking opponent. Throws beat block.", nextOrder())
		row("Throw Escape", Input.glyph("THROW") .. " when grabbed", "Break a throw on reaction.", nextOrder())
		row("Block", "HOLD " .. Input.glyph("B") .. "  (+ " .. Input.glyph("down") .. " for lows)", "Highs and mids standing, lows crouching, overheads standing.", nextOrder())
		scroll.CanvasPosition = Vector2.zero
	end
	build()
	hintBar(f, { { "left", "" }, { "right", "FIGHTER" }, { "up", "" }, { "down", "SCROLL" }, { "back", "BACK" } })
	local w = waiter()
	local conns = connections()
	conns.add(Input.nav.Event:Connect(function(a)
		if a == "left" or a == "tabL" then
			idx = (idx - 2) % #Fighters.list + 1
			Audio.ui("ui_move")
			build()
		elseif a == "right" or a == "tabR" then
			idx = idx % #Fighters.list + 1
			Audio.ui("ui_move")
			build()
		elseif a == "down" then
			scroll.CanvasPosition += Vector2.new(0, 120)
		elseif a == "up" then
			scroll.CanvasPosition = Vector2.new(0, math.max(0, scroll.CanvasPosition.Y - 120))
		elseif a == "back" or a == "confirm" then
			w.resolve(true)
		end
	end))
	-- touch arrows / back
	local prev = new("TextButton", { Text = "\u{25C0}", FontFace = F.labelBold, TextSize = 40, TextColor3 = C.gold, BackgroundTransparency = 1, Size = UDim2.fromOffset(80, 80), Position = UDim2.new(0.5, -480, 0, 30), ZIndex = 17 }, f)
	local nxt = new("TextButton", { Text = "\u{25B6}", FontFace = F.labelBold, TextSize = 40, TextColor3 = C.gold, BackgroundTransparency = 1, Size = UDim2.fromOffset(80, 80), Position = UDim2.new(0.5, 400, 0, 30), ZIndex = 17 }, f)
	local back = new("TextButton", { Text = "BACK", FontFace = F.labelBold, TextSize = 22, TextColor3 = C.ivory, BackgroundColor3 = Color3.fromHex("#14151A"), BackgroundTransparency = 0.2, Size = UDim2.fromOffset(140, 50), Position = UDim2.fromOffset(30, 30), ZIndex = 17 }, f)
	Theme.stroke(back, C.goldDim, 1.5)
	conns.add(prev.Activated:Connect(function()
		idx = (idx - 2) % #Fighters.list + 1
		build()
	end))
	conns.add(nxt.Activated:Connect(function()
		idx = idx % #Fighters.list + 1
		build()
	end))
	conns.add(back.Activated:Connect(function()
		w.resolve(true)
	end))
	fadeIn(f)
	w.wait()
	conns.clear()
	Audio.ui("ui_back")
	f:Destroy()
end

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

function Screens.settings(root: Instance, settings)
	local f = screenFrame(root, "Settings")
	f.ZIndex = 75
	backdrop(f, 0.85)
	title(f, "SETTINGS")
	local defs = {
		{ key = "music", label = "MUSIC VOLUME", kind = "slider" },
		{ key = "sfx", label = "EFFECTS VOLUME", kind = "slider" },
		{ key = "voice", label = "VOICE VOLUME", kind = "slider" },
		{ key = "subtitles", label = "SUBTITLES", kind = "toggle" },
		{ key = "shake", label = "CAMERA SHAKE", kind = "toggle" },
		{ key = "flashes", label = "SCREEN FLASHES / IMPACT FRAMES", kind = "toggle" },
		{ key = "tts", label = "VOICED LINES (TEXT-TO-SPEECH)", kind = "toggle" },
		{ key = "difficulty", label = "DEFAULT CPU DIFFICULTY", kind = "choice", choices = { 1, 2, 3, 4 } },
		{ key = "touch", label = "TOUCH CONTROLS", kind = "choice", choices = { "auto", "on", "off" } },
	}
	local list = Theme.frame(f, { Size = UDim2.fromOffset(1000, 600), Position = UDim2.new(0.5, 0, 0, 180), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 15 })
	local items = {}
	local function valueText(d)
		local v = settings[d.key]
		if d.kind == "slider" then
			local n = math.floor((v or 0) * 10 + 0.5)
			return string.rep("\u{25A0}", n) .. string.rep("\u{25A1}", 10 - n)
		elseif d.kind == "toggle" then
			return v and "ON" or "OFF"
		elseif d.key == "difficulty" then
			return Config.Difficulty[v or 2].name
		end
		return string.upper(tostring(v))
	end
	local valueLabels = {}
	for i, d in defs do
		local it = menuItem(list, d.label, (i - 1) * 66, 32)
		it.button.Size = UDim2.fromOffset(1000, 60)
		valueLabels[i] = Theme.label(it.button, valueText(d), {
			Size = UDim2.fromOffset(360, 60),
			Position = UDim2.new(1, -360, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			FontFace = F.labelBold,
			TextSize = 22,
			TextColor3 = C.goldBright,
			ZIndex = 17,
		})
		items[i] = it
	end
	local function change(i: number, dir: number)
		local d = defs[i]
		if d.kind == "slider" then
			settings[d.key] = math.clamp((settings[d.key] or 0.5) + dir * 0.1, 0, 1)
		elseif d.kind == "toggle" then
			settings[d.key] = not settings[d.key]
		else
			local idx = table.find(d.choices, settings[d.key]) or 1
			idx = (idx - 1 + dir) % #d.choices + 1
			settings[d.key] = d.choices[idx]
		end
		valueLabels[i].Text = valueText(d)
		Audio.setVolumes(settings)
		Audio.ui("ui_move")
	end
	hintBar(f, { { "left", "" }, { "right", "ADJUST" }, { "back", "SAVE & BACK" } })
	fadeIn(f)
	local lastSel = 1
	while true do
		local r = runList(items, {
			start = lastSel,
			allowBack = true,
			onAction = function(action, sel)
				if action == "left" then
					change(sel, -1)
				elseif action == "right" then
					change(sel, 1)
				end
			end,
		})
		if not r then
			break
		end
		lastSel = r
		change(r, 1)
	end
	f:Destroy()
	return settings
end

-- Shared building blocks for other screen modules (OnlineScreens).
Screens._h = {
	waiter = waiter,
	connections = connections,
	screenFrame = screenFrame,
	backdrop = backdrop,
	title = title,
	hintBar = hintBar,
	menuItem = menuItem,
	setItemSelected = setItemSelected,
	runList = runList,
	fadeIn = fadeIn,
}

return Screens
