--!nonstrict
-- Arena life: everything that makes a stage feel inhabited and lit like a set.
--
--   * Fighter lighting rig: a warm key light and a coloured rim light that follow each
--     fighter, so characters read against any background.
--   * Light shafts: soft volumetric-style beams (sun through trees, moonlight through
--     church windows, studio spots in the training room).
--   * Background crowd: blocky Roblox players with classic faces and bubble chat who
--     idle, grind, wave, hop between obby platforms, and react to the fight.
--   * Stage events: lightning over the flooded church, eruptions behind the lava
--     throne, rising floodwater, flickering candles and kill bricks.
--   * Grade pulses: the colour grade reacts to supers, heavy hits and KOs.
--
-- Built by StageBuilder after the lighting preset, updated every frame, and fully
-- cleaned up with the stage (everything lives in the stage model or `made`).

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Veil = game:GetService("ReplicatedStorage"):WaitForChild("Veil")
local Assets = require(Veil.Assets)
local Rng = require(Veil.Combat.Rng)

local Audio = require(script.Parent.Parent.Core.Audio)

local StageLife = {}

local V = Vector3.new
local C = CFrame.new
local A = CFrame.Angles
local PI = math.pi

-- Deterministic random source with the Random-style calls used below.
local function newRandom(seed: number)
	local r = Rng.new(seed)
	return {
		NextNumber = function(_, a: number?, b: number?)
			if a == nil or b == nil then
				return r:next()
			end
			return r:range(a, b)
		end,
		NextInteger = function(_, a: number, b: number)
			return r:int(a, b)
		end,
	}
end

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local function block(parent: Instance, size: Vector3, cf: CFrame, color: string, material: Enum.Material?, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = hex(color)
	p.Material = material or Enum.Material.SmoothPlastic
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

-------------------------------------------------------------------------------
-- Per-theme look
-------------------------------------------------------------------------------

local THEME = {
	forest = { key = "#CFE8D8", keyB = 0.9, rim = "#7DFF8C", rimB = 2.2, rays = "#C8FFD0", rayAlpha = 0.9 },
	monastery = { key = "#FFE6CC", keyB = 1.0, rim = "#FFB070", rimB = 2.4, rays = "#FFD9A0", rayAlpha = 0.86 },
	cathedral = { key = "#DCD8FF", keyB = 0.8, rim = "#8AA4FF", rimB = 2.6, rays = "#B8C8FF", rayAlpha = 0.86 },
	volcano = { key = "#FFD8C8", keyB = 0.8, rim = "#FF6A1A", rimB = 3.0 },
	baseplate = { key = "#FFFFFF", keyB = 0.5, rim = "#E8F4FF", rimB = 1.2, rays = "#FFFFFF", rayAlpha = 0.93 },
	proving = { key = "#F2EEE6", keyB = 0.9, rim = "#E8C66A", rimB = 2.0, rays = "#FFE7A8", rayAlpha = 0.9 },
}

-------------------------------------------------------------------------------
-- Fighter key + rim lights
-------------------------------------------------------------------------------

local function fighterLights(model: Instance, look)
	local rigs = {}
	for i = 1, 2 do
		local key = block(model, V(0.2, 0.2, 0.2), C(0, 7, 5), "#FFFFFF", nil, { Transparency = 1, CastShadow = false, Name = "KeyLight" .. i })
		local kl = Instance.new("PointLight")
		kl.Color = hex(look.key)
		kl.Brightness = look.keyB
		kl.Range = 13
		kl.Shadows = false
		kl.Parent = key
		local rim = block(model, V(0.2, 0.2, 0.2), C(0, 6, -3), "#FFFFFF", nil, { Transparency = 1, CastShadow = false, Name = "RimLight" .. i })
		local rl = Instance.new("PointLight")
		rl.Color = hex(look.rim)
		rl.Brightness = look.rimB
		rl.Range = 9
		rl.Shadows = false
		rl.Parent = rim
		rigs[i] = { key = key, rim = rim, keyLight = kl, rimLight = rl }
	end
	return rigs
end

-------------------------------------------------------------------------------
-- Light shafts (Beams between attachments high above and down in the set)
-------------------------------------------------------------------------------

local function shaft(model: Instance, from: Vector3, to: Vector3, width0: number, width1: number, color: string, alpha: number)
	local holder = block(model, V(0.2, 0.2, 0.2), C(from), "#FFFFFF", nil, { Transparency = 1, CastShadow = false, Name = "Shaft" })
	local a0 = Instance.new("Attachment")
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Position = to - from
	a1.Parent = holder
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = width0
	b.Width1 = width1
	b.FaceCamera = true
	b.Segments = 8
	b.Texture = Assets.Particles.Smoke
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.TextureSpeed = 0.04
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Color = ColorSequence.new(hex(color))
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.18, alpha),
		NumberSequenceKeypoint.new(0.75, math.min(1, alpha + 0.04)),
		NumberSequenceKeypoint.new(1, 1),
	})
	b.Parent = holder
	return b
end

local SHAFTS = {
	forest = {
		{ V(-22, 40, -30), V(-12, 0, -8), 3, 9 },
		{ V(4, 42, -36), V(10, 0, -10), 2.5, 8 },
		{ V(26, 40, -30), V(30, 0, -6), 3, 10 },
	},
	monastery = {
		{ V(-40, 34, -40), V(-14, 0, -6), 4, 12 },
		{ V(-20, 36, -44), V(6, 0, -8), 3, 10 },
	},
	cathedral = {
		{ V(-24, 34, -30), V(-14, 0, -4), 2.5, 7 },
		{ V(0, 36, -32), V(4, 0, -6), 3, 8 },
		{ V(24, 34, -30), V(18, 0, -4), 2.5, 7 },
	},
	baseplate = {
		{ V(-30, 44, -40), V(-10, 0, -8), 5, 14 },
	},
	proving = {
		{ V(-12, 26, -6), V(-12, 0, -2), 1.5, 6 },
		{ V(12, 26, -6), V(12, 0, -2), 1.5, 6 },
	},
}

-------------------------------------------------------------------------------
-- Background crowd: blocky players with classic faces and bubble chat
-------------------------------------------------------------------------------

local OUTFITS = {
	{ skin = "#F5CD30", shirt = "#0D69AC", pants = "#A4BD47" }, -- the classic
	{ skin = "#EAB892", shirt = "#C4281C", pants = "#1B2A35" },
	{ skin = "#7C5C46", shirt = "#4B974B", pants = "#27467A" },
	{ skin = "#CC8E69", shirt = "#6B327C", pants = "#1B1B1F" },
	{ skin = "#F5CD30", shirt = "#E29B40", pants = "#3A3A3A" },
	{ skin = "#F2F3F3", shirt = "#1B1B1F", pants = "#1B1B1F" },
	{ skin = "#EAB892", shirt = "#F2F3F3", pants = "#0D69AC" },
}

local function bubble(head: BasePart)
	local g = Instance.new("BillboardGui")
	g.Name = "Chat"
	g.Size = UDim2.new(7, 0, 1.3, 0)
	g.StudsOffset = V(0, 1.9, 0)
	g.LightInfluence = 0
	g.MaxDistance = 140
	g.Enabled = false
	g.Parent = head
	local bg = Instance.new("Frame")
	bg.AnchorPoint = Vector2.new(0.5, 1)
	bg.Position = UDim2.fromScale(0.5, 1)
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.BackgroundTransparency = 0.04
	bg.Parent = g
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.45, 0)
	corner.Parent = bg
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.78)
	label.Position = UDim2.fromScale(0.05, 0.11)
	label.TextScaled = true
	label.TextColor3 = hex("#1B1B1F")
	label.FontFace = Font.fromEnum(Enum.Font.SourceSansBold)
	label.Text = ""
	label.Parent = bg
	return g, label
end

-- kind: idle | grind | wave | hop | cheer
local function npc(model: Instance, life, pos: Vector3, yaw: number, kind: string, outfit, scale: number?)
	local s = scale or 1
	local folder = Instance.new("Model")
	folder.Name = "Player"
	folder.Parent = model
	local o = outfit
	local torso = block(folder, V(2, 2, 1) * s, C(pos), o.shirt)
	local head = block(folder, V(2, 1, 1) * s, C(pos), o.skin, nil, { Name = "Head" })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = V(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Texture = Assets.Face
	face.Face = Enum.NormalId.Front
	face.Parent = head
	local la = block(folder, V(1, 2, 1) * s, C(pos), o.skin)
	local ra = block(folder, V(1, 2, 1) * s, C(pos), o.skin)
	local ll = block(folder, V(1, 2, 1) * s, C(pos), o.pants)
	local rl = block(folder, V(1, 2, 1) * s, C(pos), o.pants)
	local g, label = bubble(head)
	local n = {
		idx = #life.moveParts + 1,
		parts = { torso, head, la, ra, ll, rl },
		base = C(pos) * A(0, yaw, 0),
		scale = s,
		kind = kind,
		phase = life.rng:NextNumber(0, PI * 2),
		jumpT = -1,
		chat = g,
		chatLabel = label,
		chatUntil = 0,
		nextChat = life.rng:NextNumber(1.5, 7),
	}
	for _, p in n.parts do
		table.insert(life.moveParts, p)
		table.insert(life.moveCFrames, p.CFrame)
	end
	table.insert(life.crowd, n)
	return n
end

local function say(n, text: string, t: number, hold: number?)
	n.chatLabel.Text = text
	n.chat.Enabled = true
	n.chatUntil = t + (hold or 2.6)
end

local function jump(n, t: number)
	if n.jumpT < 0 or t - n.jumpT > 0.55 then
		n.jumpT = t
	end
end

-- Write the six part CFrames for one NPC into the bulk-move buffer.
local function poseNpc(life, n, t: number, baseOffset: CFrame?)
	local idx = n.idx
	local s = n.scale
	local ph = n.phase
	local y = 0
	local armL, armR = math.sin(t * 1.4 + ph) * 0.08, -math.sin(t * 1.4 + ph) * 0.08
	local legL, legR = 0, 0
	local rollR = 0
	local headYaw = math.sin(t * 0.4 + ph) * 0.35
	if n.jumpT >= 0 then
		local k = (t - n.jumpT) / 0.55
		if k >= 0 and k < 1 then
			y = 4 * k * (1 - k) * 2.6
			armL, armR = PI * 0.95, PI * 0.95
			legL, legR = -0.25, 0.25
		end
	end
	if y == 0 then
		if n.kind == "grind" then
			-- simulator grinding: alternating punches at a training log
			local c = t * 7 + ph
			armR = PI * 0.5 * math.max(0, math.sin(c))
			armL = PI * 0.5 * math.max(0, -math.sin(c))
		elseif n.kind == "wave" then
			armR = PI * 0.85
			rollR = math.sin(t * 7 + ph) * 0.35
		elseif n.kind == "cheer" then
			local c = math.abs(math.sin(t * 5 + ph))
			armL, armR = PI * 0.6 + c * 0.4, PI * 0.6 + c * 0.4
		end
	end
	local root = n.base
	if baseOffset then
		root = baseOffset * root
	end
	root = root * C(0, y * s, 0)
	local cfs = life.moveCFrames
	cfs[idx] = root * C(0, 3 * s, 0)
	cfs[idx + 1] = root * C(0, 4.5 * s, 0) * A(0, headYaw, 0)
	cfs[idx + 2] = root * C(-1.5 * s, 3.9 * s, 0) * A(armL, 0, 0) * C(0, -0.9 * s, 0)
	cfs[idx + 3] = root * C(1.5 * s, 3.9 * s, 0) * A(armR, 0, 0) * A(0, 0, rollR) * C(0, -0.9 * s, 0)
	cfs[idx + 4] = root * C(-0.5 * s, 2 * s, 0) * A(legL, 0, 0) * C(0, -1 * s, 0)
	cfs[idx + 5] = root * C(0.5 * s, 2 * s, 0) * A(legR, 0, 0) * C(0, -1 * s, 0)
end

-- Ambient chatter per arena (all original parody lines).
local CHAT = {
	baseplate = { "1v1 me", "who made this game", "lag", "can i have robux", "noob", "W", "ez", "this baseplate goes hard", "brb", "gg already" },
	monastery = { "+1 STRENGTH", "rebirth when?", "afk grinding", "sensei pls", "my power level is 9k", "dont talk im training" },
	forest = { "how do u do this jump", "skip stage pls", "checkpoint??", "i fell again", "kill brick moved", "obby is rigged" },
	cathedral = { "WATER RISING", "wheres the exit", "this game is broken", "swim!!", "i cant swim in roblox" },
	volcano = { "unban me pls", "i said ONE word", "admin abuse!!!", "who has keys", "i was AFK", "free me" },
	proving = { "frame data?", "lab time", "practice mode W" },
}
local REACT_HEAVY = { "OHHH", "sheesh", "oof", "combo!!", "THAT HURT", "no way" }
local REACT_KO = { "GG", "OOF", "gg no re", "F", "ez", "W", "clip it" }

-------------------------------------------------------------------------------
-- Build
-------------------------------------------------------------------------------

function StageLife.build(cur)
	local model = cur.model
	local theme = cur.stage.theme
	local look = THEME[theme] or THEME.proving
	local life = {
		theme = theme,
		rng = newRandom(#theme * 7919),
		crowd = {},
		moveParts = {},
		moveCFrames = {},
		bobbers = {},
		flickers = {},
		popups = {},
		eruptions = nil,
		lightning = nil,
		water = nil,
		grade = cur.fx and cur.fx.grade,
		gradeBase = nil,
		baseBrightness = Lighting.Brightness,
		baseAmbient = Lighting.Ambient,
		clock = 0,
	}
	cur.life = life
	if life.grade then
		life.gradeBase = { Brightness = life.grade.Brightness, Saturation = life.grade.Saturation, Contrast = life.grade.Contrast, TintColor = life.grade.TintColor }
	end
	pcall(function()
		Lighting.ShadowSoftness = 0.22
	end)

	life.fighterLights = fighterLights(model, look)
	for _, sdef in SHAFTS[theme] or {} do
		shaft(model, sdef[1], sdef[2], sdef[3], sdef[4], look.rays or "#FFFFFF", look.rayAlpha or 0.9)
	end

	local rng = life.rng
	local function outfit(i: number)
		return OUTFITS[(i - 1) % #OUTFITS + 1]
	end

	if theme == "baseplate" then
		-- spectators who joined to watch
		local spots = { { -22, -13 }, { -15, -16 }, { -8, -19 }, { 9, -18 }, { 17, -15 }, { 24, -12 }, { 2, -24 } }
		for i, sp in spots do
			local kind = i % 3 == 0 and "cheer" or (i == 5 and "wave" or "idle")
			npc(model, life, V(sp[1], 0, sp[2]), PI + rng:NextNumber(-0.4, 0.4), kind, outfit(i))
		end
	elseif theme == "monastery" then
		-- simulator grinders punching training logs, with +1 STRENGTH popups
		local spots = { { -26, -16 }, { -16, -20 }, { 18, -19 }, { 28, -15 } }
		for i, sp in spots do
			local n = npc(model, life, V(sp[1], 0, sp[2]), PI * 0.5 * (sp[1] < 0 and 1 or -1), "grind", outfit(i + 1))
			local logX = sp[1] + (sp[1] < 0 and -2.2 or 2.2)
			block(model, V(1.4, 5, 1.4), C(logX, 2.5, sp[2]), "#6B4A2A", Enum.Material.Wood)
			local pop = block(model, V(0.2, 0.2, 0.2), C(sp[1], 5.5, sp[2]), "#FFFFFF", nil, { Transparency = 1, CastShadow = false })
			local g = Instance.new("BillboardGui")
			g.Size = UDim2.new(5, 0, 1, 0)
			g.LightInfluence = 0
			g.Parent = pop
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(1, 1)
			l.TextScaled = true
			l.Text = "+1 STRENGTH"
			l.TextColor3 = hex("#FFE14A")
			l.TextStrokeTransparency = 0.2
			l.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
			l.Parent = g
			table.insert(life.popups, { gui = g, label = l, phase = i * 0.37 })
			n.chatSilent = true
		end
		local petals = block(model, V(90, 1, 30), C(0, 24, -12), "#FFFFFF", nil, { Transparency = 1, CastShadow = false, Name = "Petals" })
		local e = Instance.new("ParticleEmitter")
		e.Texture = Assets.Particles.Spark
		e.Rate = 10
		e.Lifetime = NumberRange.new(8, 12)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(40, 40)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Acceleration = V(1.2, -1.6, 0)
		e.Size = NumberSequence.new(0.3, 0.2)
		e.Color = ColorSequence.new(hex("#FFC2D6"), hex("#FF8FB4"))
		e.LightEmission = 0.3
		e.RotSpeed = NumberRange.new(-120, 120)
		e.Rotation = NumberRange.new(0, 360)
		e.Parent = petals
	elseif theme == "forest" then
		-- floating obby platforms with players hopping on them, flickering kill bricks
		local pads = { { -30, 5, -26, "#FF4FD8" }, { -18, 7, -32, "#4FD8FF" }, { 16, 6, -30, "#A4FF4F" }, { 30, 8, -26, "#FFD84F" } }
		for i, pd in pads do
			local pad = block(model, V(5, 0.8, 5), C(pd[1], pd[2], pd[3]), pd[4], Enum.Material.Neon)
			local entry = { part = pad, base = pad.CFrame, amp = 0.6, speed = 0.9 + i * 0.13, phase = i * 1.7 }
			table.insert(life.bobbers, entry)
			table.insert(life.moveParts, pad)
			table.insert(life.moveCFrames, pad.CFrame)
			entry.idx = #life.moveParts
			if i % 2 == 1 then
				local n = npc(model, life, V(pd[1], pd[2] + 0.4, pd[3]), PI + rng:NextNumber(-0.6, 0.6), "hop", outfit(i))
				n.ride = entry
			end
		end
		for i = 1, 3 do
			local kb = block(model, V(6, 0.6, 1.4), C(-20 + i * 12, 3 + i, -36), "#FF2020", Enum.Material.Neon, { CastShadow = false, Name = "KillBrick" })
			table.insert(life.flickers, { part = kb, phase = i * 2.1, speed = 3 + i })
		end
		local leaves = block(model, V(100, 1, 30), C(0, 26, -12), "#FFFFFF", nil, { Transparency = 1, CastShadow = false, Name = "Leaves" })
		local e = Instance.new("ParticleEmitter")
		e.Texture = Assets.Particles.Spark
		e.Rate = 6
		e.Lifetime = NumberRange.new(9, 13)
		e.Speed = NumberRange.new(0.4, 1)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Acceleration = V(0.6, -1.4, 0)
		e.Size = NumberSequence.new(0.35, 0.25)
		e.Color = ColorSequence.new(hex("#C88A3A"), hex("#6A8A3A"))
		e.LightEmission = 0
		e.LightInfluence = 1
		e.RotSpeed = NumberRange.new(-90, 90)
		e.Rotation = NumberRange.new(0, 360)
		e.Parent = leaves
	elseif theme == "cathedral" then
		-- stranded players on the balcony, flickering candles, lightning, rising water
		block(model, V(26, 1, 5), C(0, 9, -27), "#2A2C34", Enum.Material.Slate)
		block(model, V(26, 1.6, 0.4), C(0, 10.3, -24.6), "#3A3C46", Enum.Material.Slate)
		for i, x in { -8, 0, 8 } do
			npc(model, life, V(x, 9.5, -27), PI + rng:NextNumber(-0.3, 0.3), i == 2 and "wave" or "idle", outfit(i + 3))
		end
		for i = 1, 8 do
			local x = -32 + i * 8
			local candle = block(model, V(0.4, 1.4, 0.4), C(x, 0.7, -8.5 - (i % 2) * 2), "#EDE6D2")
			local flame = block(model, V(0.25, 0.4, 0.25), C(x, 1.6, -8.5 - (i % 2) * 2), "#FFB84A", Enum.Material.Neon, { CastShadow = false })
			local l = Instance.new("PointLight")
			l.Color = hex("#FFB066")
			l.Brightness = 1.4
			l.Range = 9
			l.Parent = flame
			table.insert(life.flickers, { light = l, base = 1.4, phase = i * 1.9, speed = 11 + i })
			local _ = candle
		end
		local water = cur.model:FindFirstChild("Water")
		if water then
			life.water = { part = water, base = water.CFrame }
		end
		life.lightning = { next = 4 + rng:NextNumber(0, 5), t = -1 }
	elseif theme == "volcano" then
		-- banned players in a cage, eruptions, falling ash
		local cx, cz = 22, -24
		block(model, V(10, 0.6, 6), C(cx, 0.3, cz), "#1A1A1E", Enum.Material.DiamondPlate)
		block(model, V(10, 0.6, 6), C(cx, 7.3, cz), "#1A1A1E", Enum.Material.DiamondPlate)
		for b = 0, 10 do
			block(model, V(0.2, 7, 0.2), C(cx - 5 + b, 3.8, cz + 3), "#FF3A3A", Enum.Material.Neon, { CastShadow = false })
		end
		local sign = block(model, V(8, 1.6, 0.3), C(cx, 9, cz + 3), "#120606")
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Back
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.LightInfluence = 0
		sg.Parent = sign
		local st = Instance.new("TextLabel")
		st.Size = UDim2.fromScale(1, 1)
		st.BackgroundTransparency = 1
		st.Text = "BANNED (FOREVER)"
		st.TextColor3 = hex("#FF4A3A")
		st.TextScaled = true
		st.FontFace = Font.fromEnum(Enum.Font.Arcade)
		st.Parent = sg
		for i, x in { -3, 0, 3 } do
			npc(model, life, V(cx + x, 0.6, cz), PI + rng:NextNumber(-0.3, 0.3), i == 2 and "wave" or "idle", outfit(i + 4))
		end
		local glow = block(model, V(0.2, 0.2, 0.2), C(-26, 10, -48), "#FFFFFF", nil, { Transparency = 1, CastShadow = false })
		local gl = Instance.new("PointLight")
		gl.Color = hex("#FF7A2A")
		gl.Brightness = 0
		gl.Range = 60
		gl.Parent = glow
		local embers = Instance.new("ParticleEmitter")
		embers.Texture = Assets.Particles.FireSparks
		embers.Rate = 0
		embers.Lifetime = NumberRange.new(1.5, 3)
		embers.Speed = NumberRange.new(14, 26)
		embers.SpreadAngle = Vector2.new(25, 25)
		embers.Acceleration = V(0, -14, 0)
		embers.Size = NumberSequence.new(0.6, 0)
		embers.Color = ColorSequence.new(hex("#FFD27A"), hex("#FF3A0A"))
		embers.LightEmission = 1
		embers.Parent = glow
		life.eruptions = { light = gl, embers = embers, next = 5 + rng:NextNumber(0, 4), level = 0 }
		local ash = block(model, V(100, 1, 30), C(0, 26, -12), "#FFFFFF", nil, { Transparency = 1, CastShadow = false, Name = "Ash" })
		local e = Instance.new("ParticleEmitter")
		e.Texture = Assets.Particles.Spark
		e.Rate = 14
		e.Lifetime = NumberRange.new(8, 12)
		e.Speed = NumberRange.new(0.3, 0.8)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Acceleration = V(0.4, -1.2, 0)
		e.Size = NumberSequence.new(0.16, 0.1)
		e.Color = ColorSequence.new(hex("#8A8480"))
		e.LightEmission = 0
		e.LightInfluence = 1
		e.Parent = ash
	elseif theme == "proving" then
		for i, x in { -24, 24 } do
			npc(model, life, V(x, 0, -14), PI + (x < 0 and -0.5 or 0.5), "idle", { skin = "#9A9A9A", shirt = "#6A6A6A", pants = "#4A4A4A" })
			local _ = i
		end
	end
	return life
end

-------------------------------------------------------------------------------
-- Reactions & grade pulses
-------------------------------------------------------------------------------

-- Tween the stage grade to `target`, hold, then back to `restore` (only the
-- properties named, so cinematic grades on other properties are left alone).
local function gradePulse(life, target, inTime: number, hold: number, outTime: number, restore)
	local g = life.grade
	if not g or not life.gradeBase then
		return
	end
	life.gradeToken = (life.gradeToken or 0) + 1
	local token = life.gradeToken
	TweenService:Create(g, TweenInfo.new(inTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), target):Play()
	task.delay(inTime + hold, function()
		if life.gradeToken ~= token or not g.Parent then
			return
		end
		TweenService:Create(g, TweenInfo.new(outTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), restore):Play()
	end)
end

-- kind: heavy | super | ko | round
function StageLife.react(life, kind: string)
	if not life then
		return
	end
	local t = life.clock
	local rng = life.rng
	local base = life.gradeBase
	if kind == "heavy" then
		if #life.crowd > 0 then
			local n = life.crowd[rng:NextInteger(1, #life.crowd)]
			jump(n, t)
			if not n.chatSilent and rng:NextNumber() < 0.6 then
				say(n, REACT_HEAVY[rng:NextInteger(1, #REACT_HEAVY)], t, 1.6)
			end
		end
		if base then
			gradePulse(life, { Contrast = base.Contrast + 0.1 }, 0.03, 0.04, 0.18, { Contrast = base.Contrast })
		end
	elseif kind == "super" then
		-- (the super cinematic owns the colour grade; the crowd just loses it)
		for _, n in life.crowd do
			if not n.chatSilent and rng:NextNumber() < 0.5 then
				say(n, "!!!", t, 1.4)
			end
		end
	elseif kind == "ko" then
		if base then
			gradePulse(life, { Saturation = -0.75, Contrast = base.Contrast + 0.2 }, 0.08, 1.6, 1.6, { Saturation = base.Saturation, Contrast = base.Contrast })
		end
		for i, n in life.crowd do
			task.delay(i * 0.07, function()
				jump(n, life.clock)
			end)
			if not n.chatSilent then
				say(n, REACT_KO[rng:NextInteger(1, #REACT_KO)], t + i * 0.1, 3)
			end
		end
	elseif kind == "round" then
		for _, n in life.crowd do
			if rng:NextNumber() < 0.4 then
				jump(n, t + rng:NextNumber(0, 0.4))
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Per-frame update
-------------------------------------------------------------------------------

function StageLife.update(life, t: number, dt: number, fighters)
	if not life then
		return
	end
	life.clock = t
	local rng = life.rng

	-- fighter lighting rig follows the fighters (key front-high, rim behind on the far side)
	if fighters then
		for i, lr in life.fighterLights do
			local f = fighters[i]
			if f then
				local other = fighters[3 - i]
				local away = (other and f.x < other.x) and -1 or 1
				lr.key.CFrame = C(f.x + away * 1.5, f.y + 7, 6)
				lr.rim.CFrame = C(f.x + away * 2.6, f.y + 5.5, -2.6)
			end
		end
	end

	-- bobbing platforms
	for _, b in life.bobbers do
		local cf = b.base * C(0, math.sin(t * b.speed + b.phase) * b.amp, 0)
		b.current = cf
		life.moveCFrames[b.idx] = cf
	end

	-- crowd
	for _, n in life.crowd do
		-- ambient chatter
		if n.chat.Enabled and t > n.chatUntil then
			n.chat.Enabled = false
		end
		if not n.chatSilent and t > n.nextChat then
			local lines = CHAT[life.theme] or CHAT.baseplate
			say(n, lines[rng:NextInteger(1, #lines)], t)
			n.nextChat = t + rng:NextNumber(6, 14)
		end
		if n.kind == "hop" and (n.jumpT < 0 or t - n.jumpT > 1.6 + (n.phase % 1)) then
			jump(n, t)
		end
		local offset = nil
		if n.ride and n.ride.current then
			offset = C(0, n.ride.current.Y - n.ride.base.Y, 0)
		end
		poseNpc(life, n, t, offset)
	end
	if #life.moveParts > 0 then
		workspace:BulkMoveTo(life.moveParts, life.moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	-- simulator popups rise and fade once a second
	for _, p in life.popups do
		local k = ((t + p.phase) % 1.1) / 1.1
		p.gui.StudsOffset = V(0, k * 2.4, 0)
		p.label.TextTransparency = k * k
		p.label.TextStrokeTransparency = 0.2 + k * 0.8
	end

	-- flickers (candles, kill bricks)
	for _, f in life.flickers do
		if f.light then
			f.light.Brightness = f.base * (0.8 + 0.2 * math.sin(t * f.speed + f.phase) + 0.1 * math.sin(t * f.speed * 2.7))
		elseif f.part then
			f.part.Transparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(t * f.speed + f.phase))
		end
	end

	-- floodwater slowly rising and falling
	if life.water then
		life.water.part.CFrame = life.water.base * C(0, math.sin(t * 0.35) * 0.12, 0)
	end

	-- lightning over the flooded church: double flash, then thunder
	local lt = life.lightning
	if lt then
		if lt.t < 0 and t >= lt.next then
			lt.t = t
			Audio.play("lightning_crack", { volume = 0.35, pitch = 0.7, pitchVar = 0.1 })
		end
		if lt.t >= 0 then
			local e = t - lt.t
			local flash = 0
			if e < 0.08 then
				flash = 1
			elseif e < 0.16 then
				flash = 0.2
			elseif e < 0.24 then
				flash = 0.8
			elseif e < 0.6 then
				flash = 0.8 * (1 - (e - 0.24) / 0.36)
			else
				lt.t = -1
				lt.next = t + 7 + rng:NextNumber(0, 8)
			end
			Lighting.Brightness = life.baseBrightness + flash * 2.4
			Lighting.Ambient = life.baseAmbient:Lerp(hex("#B8C8FF"), flash * 0.5)
		end
	end

	-- eruptions behind the throne
	local er = life.eruptions
	if er then
		if t >= er.next then
			er.level = 1
			er.next = t + 6 + rng:NextNumber(0, 6)
			er.embers:Emit(45)
			Audio.play("ground_slam", { volume = 0.3, pitch = 0.6 })
		end
		er.level = math.max(0, er.level - dt * 0.9)
		er.light.Brightness = er.level * er.level * 9
	end
	local _ = dt
end

-- Restore global lighting touched by stage events.
function StageLife.clear(life)
	if not life then
		return
	end
	if life.lightning then
		Lighting.Brightness = life.baseBrightness
		Lighting.Ambient = life.baseAmbient
	end
	life.gradeToken = (life.gradeToken or 0) + 1
end

return StageLife
