--!nonstrict
-- In-fight HUD: health bars with damage trails, portraits, round pips, timer emblem,
-- meter bars, Echo gauge, combo counters, announcer, super/finisher banners and the
-- training readout.

local Veil = game:GetService("ReplicatedStorage"):WaitForChild("Veil")
local Config = require(Veil.Config)

local Theme = require(script.Parent.Theme)
local Portrait = require(script.Parent.Portrait)
local Input = require(script.Parent.Parent.Core.Input)
local Poses = require(script.Parent.Parent.Render.Poses)

local C = Theme.Colors
local F = Theme.Fonts
local new = Theme.new

local HUD = {}
HUD.__index = HUD

local BAR_W = 560
local BAR_H = 26

local function sideBlock(hud, root, side: number, fighter, echo)
	local left = side == 1
	local anchorX = left and 0 or 1
	local sx = left and 1 or -1
	local holder = Theme.frame(root, {
		Name = left and "P1" or "P2",
		Size = UDim2.fromOffset(BAR_W + 150, 140),
		Position = UDim2.new(anchorX, left and 34 or -34, 0, 22),
		AnchorPoint = Vector2.new(anchorX, 0),
	})

	-- portrait medallion
	local medal = Theme.frame(holder, {
		Size = UDim2.fromOffset(104, 104),
		Position = UDim2.new(left and 0 or 1, 0, 0, 0),
		AnchorPoint = Vector2.new(left and 0 or 1, 0),
		BackgroundColor3 = Color3.fromHex("#0C0D10"),
		BackgroundTransparency = 0.05,
	})
	Theme.corner(medal, 52)
	Theme.stroke(medal, C.gold, 2)
	local glow = new("UIGradient", {
		Color = ColorSequence.new(Color3.fromHex(fighter.accent):Lerp(Color3.new(0, 0, 0), 0.55), Color3.fromHex("#050506")),
		Rotation = 90,
	}, medal)
	local _ = glow
	local por = Portrait.create(medal, fighter.look, {
		framing = "head",
		style = Poses.STYLE_OF[fighter.stance] or "unarmed",
		facing = left and 1 or -1,
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3),
	})
	local mask = Theme.corner(por.frame, 50)
	local _m = mask

	-- health bar
	local barX = left and 120 or -120
	local barFrame = Theme.frame(holder, {
		Size = UDim2.fromOffset(BAR_W, BAR_H),
		Position = UDim2.new(left and 0 or 1, barX, 0, 18),
		AnchorPoint = Vector2.new(left and 0 or 1, 0),
		BackgroundColor3 = Color3.fromHex("#0A0A0C"),
		BackgroundTransparency = 0.1,
		ClipsDescendants = true,
	})
	Theme.stroke(barFrame, C.gold, 1.6)
	local trail = Theme.frame(barFrame, {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(left and 0 or 1, 0),
		AnchorPoint = Vector2.new(left and 0 or 1, 0),
		BackgroundColor3 = Color3.fromHex("#C8281E"),
		BackgroundTransparency = 0,
		ZIndex = 2,
	})
	local fill = Theme.frame(barFrame, {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(left and 0 or 1, 0),
		AnchorPoint = Vector2.new(left and 0 or 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		ZIndex = 3,
	})
	local fillGrad = Theme.gradient(fill, { Color3.fromHex("#F6EFDC"), Color3.fromHex("#C9A24A") }, left and 0 or 180)
	-- glossy highlight
	local gloss = Theme.frame(fill, {
		Size = UDim2.new(1, 0, 0.4, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
	})
	local _g = gloss
	-- notches every 10%
	for i = 1, 9 do
		Theme.frame(barFrame, {
			Size = UDim2.new(0, 1, 1, 0),
			Position = UDim2.fromScale(i / 10, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.55,
			ZIndex = 4,
		})
	end
	local hpText = Theme.label(barFrame, "1000", {
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		TextXAlignment = left and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
		FontFace = F.labelBold,
		TextSize = 15,
		TextColor3 = C.ivory,
		ZIndex = 5,
	})
	Theme.textStroke(hpText, 1.5, 0.15)

	-- name plates
	local name = Theme.label(holder, fighter.name, {
		Size = UDim2.fromOffset(BAR_W, 40),
		Position = UDim2.new(left and 0 or 1, barX, 0, 46),
		AnchorPoint = Vector2.new(left and 0 or 1, 0),
		FontFace = F.display,
		TextSize = 34,
		TextColor3 = C.ivory,
		TextXAlignment = left and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
	})
	Theme.textStroke(name, 2, 0.2)
	local echoName = Theme.label(holder, "\u{2726} " .. echo.name, {
		Size = UDim2.fromOffset(BAR_W, 22),
		Position = UDim2.new(left and 0 or 1, barX, 0, 84),
		AnchorPoint = Vector2.new(left and 0 or 1, 0),
		FontFace = F.label,
		TextSize = 15,
		TextColor3 = Color3.fromHex(echo.accent),
		TextXAlignment = left and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
	})
	Theme.textStroke(echoName, 1.5, 0.3)

	-- round pips (near the timer)
	local pips = {}
	for i = 1, 2 do
		local d = Theme.diamond(holder, 14, Color3.fromHex("#1A1A1E"), {
			Position = UDim2.new(left and 1 or 0, sx * (-16 - (i - 1) * 24), 0, 62),
			ZIndex = 3,
		})
		Theme.stroke(d, C.gold, 1.4)
		pips[i] = d
	end

	-- bottom: meter + echo
	local bottom = Theme.frame(root, {
		Size = UDim2.fromOffset(470, 60),
		Position = UDim2.new(anchorX, left and 40 or -40, 1, -26),
		AnchorPoint = Vector2.new(anchorX, 1),
	})
	local segs = {}
	for i = 1, 3 do
		local seg = Theme.frame(bottom, {
			Size = UDim2.fromOffset(110, 14),
			Position = UDim2.new(left and 0 or 1, sx * (82 + (i - 1) * 118), 0, 30),
			AnchorPoint = Vector2.new(left and 0 or 1, 0),
			BackgroundColor3 = Color3.fromHex("#0A0A0C"),
			BackgroundTransparency = 0.15,
			ClipsDescendants = true,
		})
		Theme.stroke(seg, C.goldDim, 1.2)
		local f = Theme.frame(seg, {
			Size = UDim2.fromScale(0, 1),
			Position = UDim2.fromScale(left and 0 or 1, 0),
			AnchorPoint = Vector2.new(left and 0 or 1, 0),
			BackgroundColor3 = C.meter,
			BackgroundTransparency = 0,
		})
		Theme.gradient(f, { Color3.fromHex("#FFE7A0"), Color3.fromHex("#D08A1A") }, 90)
		segs[i] = { frame = seg, fill = f }
	end
	local meterLabel = Theme.label(bottom, "RAGE  0", {
		Size = UDim2.fromOffset(340, 22),
		Position = UDim2.new(left and 0 or 1, sx * 82, 0, 4),
		AnchorPoint = Vector2.new(left and 0 or 1, 0),
		FontFace = F.labelBold,
		TextSize = 15,
		TextColor3 = C.goldBright,
		TextXAlignment = left and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
	})
	Theme.textStroke(meterLabel, 1.5, 0.3)
	-- echo gauge
	local echoBox = Theme.frame(bottom, {
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.new(left and 0 or 1, 0, 0, 0),
		AnchorPoint = Vector2.new(left and 0 or 1, 0),
		BackgroundColor3 = Color3.fromHex("#0A0A0C"),
		BackgroundTransparency = 0.1,
		ClipsDescendants = true,
	})
	Theme.corner(echoBox, 30)
	local echoStroke = Theme.stroke(echoBox, Color3.fromHex(echo.accent), 2)
	local echoFill = Theme.frame(echoBox, {
		Size = UDim2.fromScale(1, 0),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromHex(echo.accent),
		BackgroundTransparency = 0.35,
	})
	local echoLetter = Theme.label(echoBox, string.sub(echo.name, 1, 1), {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.display,
		TextSize = 30,
		TextColor3 = C.ivory,
		ZIndex = 3,
	})
	Theme.textStroke(echoLetter, 1.5, 0.2)

	-- combo counter
	local combo = Theme.frame(root, {
		Size = UDim2.fromOffset(300, 120),
		Position = UDim2.new(anchorX, left and 40 or -40, 0, 250),
		AnchorPoint = Vector2.new(anchorX, 0),
		Visible = false,
	})
	local comboHits = Theme.label(combo, "3 HITS", {
		Size = UDim2.new(1, 0, 0, 60),
		FontFace = F.display,
		TextSize = 56,
		TextColor3 = C.goldBright,
		TextXAlignment = left and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
	})
	Theme.textStroke(comboHits, 3, 0.1)
	local comboDmg = Theme.label(combo, "24%", {
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 58),
		FontFace = F.labelBold,
		TextSize = 26,
		TextColor3 = C.ivory,
		TextXAlignment = left and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
	})
	Theme.textStroke(comboDmg, 2, 0.2)

	-- player tag chip (P1 / P2 / CPU) at the far end of the name row
	local tagText = (hud.tags and hud.tags[side]) or (left and "P1" or "P2")
	local tag = Theme.frame(holder, {
		Name = "Tag",
		Size = UDim2.fromOffset(58, 24),
		Position = UDim2.new(left and 0 or 1, left and (barX + BAR_W - 58) or (barX - BAR_W + 58), 0, 54),
		AnchorPoint = Vector2.new(left and 0 or 1, 0),
		BackgroundColor3 = tagText == "CPU" and Color3.fromHex("#2A2B30") or Color3.fromHex(fighter.accent),
		BackgroundTransparency = 0.05,
	})
	Theme.corner(tag, 5)
	Theme.stroke(tag, C.goldDim, 1)
	Theme.label(tag, tagText, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.labelBold,
		TextSize = 15,
		TextColor3 = tagText == "CPU" and C.text or Color3.fromHex("#0A0A0C"),
	})

	return {
		holder = holder,
		bottom = bottom,
		tag = tag,
		holderPos = holder.Position,
		bottomPos = bottom.Position,
		portrait = por,
		fill = fill,
		fillGrad = fillGrad,
		trail = trail,
		hpText = hpText,
		pips = pips,
		segs = segs,
		meterLabel = meterLabel,
		echoFill = echoFill,
		echoStroke = echoStroke,
		echoBox = echoBox,
		combo = combo,
		comboHits = comboHits,
		comboDmg = comboDmg,
		trailValue = 1,
		trailDelay = 0,
		lastHp = 1,
		comboTimer = 0,
		echoAccent = Color3.fromHex(echo.accent),
		left = left,
	}
end

function HUD.new(parentRoot: Instance, p1Def, p1Echo, p2Def, p2Echo, opts)
	local self = setmetatable({}, HUD)
	opts = opts or {}
	local root = Theme.frame(parentRoot, { Name = "HUD", Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	self.root = root
	self.tags = opts.tags

	-- top vignette for legibility
	local vig = Theme.frame(root, {
		Size = UDim2.new(1, 0, 0, 190),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		ZIndex = 0,
	})
	Theme.gradient(vig, { Color3.new(0, 0, 0), Color3.new(0, 0, 0) }, 90, NumberSequence.new(0.35, 1))
	local vigB = Theme.frame(root, {
		Size = UDim2.new(1, 0, 0, 150),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		ZIndex = 0,
	})
	Theme.gradient(vigB, { Color3.new(0, 0, 0), Color3.new(0, 0, 0) }, 90, NumberSequence.new(1, 0.45))

	self.sides = {
		sideBlock(self, root, 1, p1Def, p1Echo),
		sideBlock(self, root, 2, p2Def, p2Echo),
	}

	-- timer emblem
	local timer = Theme.frame(root, {
		Size = UDim2.fromOffset(110, 110),
		Position = UDim2.new(0.5, 0, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0),
	})
	local plate = Theme.diamond(timer, 76, Color3.fromHex("#0C0D10"), { Position = UDim2.fromScale(0.5, 0.48) })
	plate.BackgroundTransparency = 0.05
	Theme.stroke(plate, C.gold, 2)
	local inner = Theme.diamond(timer, 64, Color3.fromHex("#14151A"), { Position = UDim2.fromScale(0.5, 0.48) })
	Theme.stroke(inner, C.goldDim, 1)
	local timerText = Theme.label(timer, "99", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, -6),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.numbers,
		TextSize = 50,
		TextColor3 = C.goldBright,
		ZIndex = 3,
	})
	Theme.textStroke(timerText, 2, 0.2)
	local roundText = Theme.label(timer, "ROUND 1", {
		Size = UDim2.new(1, 40, 0, 20),
		Position = UDim2.new(0, -20, 1, -8),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.labelBold,
		TextSize = 13,
		TextColor3 = C.gold,
	})
	Theme.textStroke(roundText, 1.5, 0.3)
	self.timerText = timerText
	self.roundText = roundText
	self.timerFrame = timer
	if opts.training then
		timerText.Text = "\u{221E}"
		roundText.Text = "PRACTICE"
	end

	-- announcer
	local ann = Theme.frame(root, { Size = UDim2.new(1, 0, 0, 240), Position = UDim2.fromScale(0, 0.36), AnchorPoint = Vector2.new(0, 0.5) })
	local band = Theme.frame(ann, {
		Size = UDim2.new(1, 0, 0, 150),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Visible = false,
	})
	Theme.gradient(band, { Color3.new(0, 0, 0), Color3.new(0, 0, 0) }, 0, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.3),
		NumberSequenceKeypoint.new(0.75, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	}))
	local annText = Theme.label(ann, "", {
		Size = UDim2.new(1, 0, 0, 130),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.display,
		TextSize = 120,
		TextColor3 = C.ivory,
		TextTransparency = 1,
		ZIndex = 5,
	})
	local annStroke = Theme.textStroke(annText, 4, 0.1)
	local annSub = Theme.label(ann, "", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromScale(0.5, 0.82),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.labelBold,
		TextSize = 26,
		TextColor3 = C.goldBright,
		TextTransparency = 1,
		ZIndex = 5,
	})
	Theme.textStroke(annSub, 2, 0.2)
	local ruleTop = Theme.rule(ann, { Size = UDim2.fromOffset(700, 1), Position = UDim2.new(0.5, 0, 0.5, -76), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
	local ruleBot = Theme.rule(ann, { Size = UDim2.fromOffset(700, 1), Position = UDim2.new(0.5, 0, 0.5, 76), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
	self.ann = { root = ann, band = band, text = annText, sub = annSub, stroke = annStroke, ruleTop = ruleTop, ruleBot = ruleBot, token = 0 }

	-- super banner
	local banner = Theme.frame(root, {
		Size = UDim2.new(1.4, 0, 0, 110),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -6,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		Visible = false,
		ZIndex = 6,
	})
	local bannerGrad = Theme.gradient(banner, { Color3.new(0, 0, 0), Color3.new(0, 0, 0) }, 0)
	local bannerText = Theme.label(banner, "", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.display,
		TextSize = 72,
		TextColor3 = C.ivory,
		ZIndex = 7,
	})
	Theme.textStroke(bannerText, 3, 0.1)
	local bannerEdgeT = Theme.frame(banner, { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = C.gold, BackgroundTransparency = 0, ZIndex = 7 })
	local bannerEdgeB = Theme.frame(banner, { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = C.gold, BackgroundTransparency = 0, ZIndex = 7 })
	self.banner = { frame = banner, text = bannerText, grad = bannerGrad, edgeT = bannerEdgeT, edgeB = bannerEdgeB }

	-- finisher prompt
	local fin = Theme.frame(root, {
		Size = UDim2.fromOffset(900, 150),
		Position = UDim2.fromScale(0.5, 0.2),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		ZIndex = 6,
	})
	local finText = Theme.label(fin, "DELETE THEM", {
		Size = UDim2.new(1, 0, 0, 90),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.display,
		TextSize = 78,
		TextColor3 = C.crimsonBright,
		ZIndex = 7,
	})
	Theme.textStroke(finText, 3, 0.05)
	local finHint = Theme.label(fin, "", {
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 92),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.labelBold,
		TextSize = 24,
		TextColor3 = C.ivory,
		ZIndex = 7,
	})
	Theme.textStroke(finHint, 2, 0.2)
	self.finisher = { frame = fin, text = finText, hint = finHint }

	-- screen flash
	self.flashFrame = Theme.frame(root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 20,
	})

	-- cinematic letterbox (intros, supers, victories)
	local barTop = Theme.frame(root, {
		Name = "LetterboxTop",
		Size = UDim2.new(1, 0, 0.12, 0),
		Position = UDim2.fromScale(0, -0.12),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		ZIndex = 18,
	})
	local barBot = Theme.frame(root, {
		Name = "LetterboxBottom",
		Size = UDim2.new(1, 0, 0.12, 0),
		Position = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		ZIndex = 18,
	})
	self.cinemaBars = { top = barTop, bottom = barBot, on = false }
	self.timerPos = timer.Position

	-- intro name cards (one per side, lower third)
	self.cards = {}
	for side = 1, 2 do
		local left = side == 1
		local card = Theme.frame(root, {
			Name = "NameCard" .. side,
			Size = UDim2.fromOffset(620, 150),
			Position = UDim2.new(left and -0.6 or 1.6, 0, 0.62, 0),
			AnchorPoint = Vector2.new(left and 0 or 1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.25,
			Visible = false,
			ZIndex = 19,
		})
		Theme.gradient(card, { Color3.new(0, 0, 0), Color3.new(0, 0, 0) }, left and 0 or 180, NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.7, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		}))
		local stripe = Theme.frame(card, {
			Size = UDim2.new(0, 8, 1, 0),
			Position = UDim2.fromScale(left and 0 or 1, 0),
			AnchorPoint = Vector2.new(left and 0 or 1, 0),
			BackgroundColor3 = C.gold,
			BackgroundTransparency = 0,
			ZIndex = 20,
		})
		local cname = Theme.label(card, "", {
			Size = UDim2.new(1, -60, 0, 70),
			Position = UDim2.new(left and 0 or 1, left and 36 or -36, 0, 10),
			AnchorPoint = Vector2.new(left and 0 or 1, 0),
			FontFace = F.display,
			TextSize = 66,
			TextColor3 = C.ivory,
			TextXAlignment = left and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
			ZIndex = 21,
		})
		Theme.textStroke(cname, 2.5, 0.1)
		local ctitle = Theme.label(card, "", {
			Size = UDim2.new(1, -60, 0, 30),
			Position = UDim2.new(left and 0 or 1, left and 38 or -38, 0, 80),
			AnchorPoint = Vector2.new(left and 0 or 1, 0),
			FontFace = F.labelBold,
			TextSize = 22,
			TextColor3 = C.goldBright,
			TextXAlignment = left and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
			ZIndex = 21,
		})
		Theme.textStroke(ctitle, 1.5, 0.3)
		local crealm = Theme.label(card, "", {
			Size = UDim2.new(1, -60, 0, 22),
			Position = UDim2.new(left and 0 or 1, left and 38 or -38, 0, 112),
			AnchorPoint = Vector2.new(left and 0 or 1, 0),
			FontFace = F.label,
			TextSize = 16,
			TextColor3 = C.text,
			TextXAlignment = left and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
			ZIndex = 21,
		})
		self.cards[side] = { frame = card, stripe = stripe, name = cname, title = ctitle, realm = crealm, token = 0 }
	end

	-- low health vignette
	self.lowVig = Theme.frame(root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.crimson,
		BackgroundTransparency = 1,
		ZIndex = 0,
	})
	Theme.gradient(self.lowVig, { C.crimson, C.crimson }, 0, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.18, 1),
		NumberSequenceKeypoint.new(0.82, 1),
		NumberSequenceKeypoint.new(1, 0.55),
	}))

	-- training readout
	if opts.training then
		local tr = Theme.panel(root, {
			Size = UDim2.fromOffset(330, 150),
			Position = UDim2.new(1, -36, 0, 190),
			AnchorPoint = Vector2.new(1, 0),
		})
		local lines = {}
		for i = 1, 5 do
			lines[i] = Theme.label(tr, "", {
				Size = UDim2.new(1, -24, 0, 24),
				Position = UDim2.fromOffset(12, 8 + (i - 1) * 27),
				FontFace = F.label,
				TextSize = 16,
				TextColor3 = i == 1 and C.goldBright or C.text,
			})
		end
		self.training = { frame = tr, lines = lines }
	end

	return self
end

-------------------------------------------------------------------------------

function HUD:flash(color: Color3?, strength: number?)
	local f = self.flashFrame
	f.BackgroundColor3 = color or Color3.new(1, 1, 1)
	f.BackgroundTransparency = 1 - (strength or 0.6)
	Theme.tween(f, 0.35, { BackgroundTransparency = 1 })
end

function HUD:announce(text: string, sub: string?, opts)
	opts = opts or {}
	local a = self.ann
	a.token += 1
	local token = a.token
	a.text.Text = text
	a.sub.Text = sub or ""
	a.text.TextColor3 = opts.color or C.ivory
	a.text.TextSize = opts.size or 120
	a.band.Visible = opts.band ~= false
	a.ruleTop.Visible = opts.band ~= false
	a.ruleBot.Visible = opts.band ~= false
	a.text.TextTransparency = 0
	a.sub.TextTransparency = sub and 0 or 1
	a.stroke.Transparency = 0.1
	local scale = a.text:FindFirstChildOfClass("UIScale") or new("UIScale", {}, a.text)
	scale.Scale = opts.punch and 1.6 or 1.15
	Theme.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	a.band.BackgroundTransparency = 0.35
	local hold = opts.hold or 1.2
	task.delay(hold, function()
		if a.token ~= token or self.destroyed then
			return
		end
		Theme.tween(a.text, 0.35, { TextTransparency = 1 })
		Theme.tween(a.sub, 0.35, { TextTransparency = 1 })
		Theme.tween(a.stroke, 0.35, { Transparency = 1 })
		Theme.tween(a.band, 0.35, { BackgroundTransparency = 1 })
		task.delay(0.36, function()
			if a.token == token and not self.destroyed then
				a.band.Visible = false
				a.ruleTop.Visible = false
				a.ruleBot.Visible = false
			end
		end)
	end)
end

function HUD:superBanner(text: string, side: number, color: Color3)
	local b = self.banner
	b.text.Text = text
	b.frame.Visible = true
	b.grad.Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.4), Color3.new(0, 0, 0))
	b.grad.Rotation = side == 1 and 0 or 180
	b.frame.Position = UDim2.fromScale(side == 1 and -0.4 or 1.4, 0.62)
	Theme.tween(b.frame, 0.28, { Position = UDim2.fromScale(0.5, 0.62) }, Enum.EasingStyle.Quart)
	task.delay(1.6, function()
		if self.destroyed then
			return
		end
		Theme.tween(b.frame, 0.25, { Position = UDim2.fromScale(side == 1 and 1.4 or -0.4, 0.62) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		task.delay(0.26, function()
			if not self.destroyed then
				b.frame.Visible = false
			end
		end)
	end)
end

function HUD:showFinisherPrompt(show: boolean)
	local f = self.finisher
	f.frame.Visible = show
	if show then
		f.hint.Text = "HOLD " .. Input.glyph("down") .. "  +  " .. Input.glyph("S")
		f.text.TextTransparency = 0
	end
end

function HUD:combo(side: number, hits: number, pct: number)
	local s = self.sides[side]
	if hits < 2 then
		return
	end
	s.combo.Visible = true
	s.comboHits.Text = tostring(hits) .. " HITS"
	s.comboDmg.Text = tostring(math.floor(pct + 0.5)) .. "%  DAMAGE"
	s.comboTimer = 1.3
	local sc = s.comboHits:FindFirstChildOfClass("UIScale") or new("UIScale", {}, s.comboHits)
	sc.Scale = 1.35
	Theme.tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	s.comboHits.TextTransparency = 0
	s.comboDmg.TextTransparency = 0
end

function HUD:setRoundPips(w1: number, w2: number)
	for side, w in { w1, w2 } do
		for i, d in self.sides[side].pips do
			d.BackgroundColor3 = (i <= w) and C.goldBright or Color3.fromHex("#1A1A1E")
		end
	end
end

-- Called every render frame with the live match.
function HUD:update(match, dt: number)
	for i, f in match.fighters do
		local s = self.sides[i]
		local hp = math.clamp(f.hp / f.maxHp, 0, 1)
		s.fill.Size = UDim2.fromScale(hp, 1)
		s.hpText.Text = tostring(math.max(0, math.floor(f.hp)))
		if hp < s.lastHp then
			s.trailDelay = 0.55
		end
		s.lastHp = hp
		if s.trailDelay > 0 then
			s.trailDelay -= dt
		else
			s.trailValue = math.max(hp, s.trailValue - dt * 0.55)
		end
		if s.trailValue < hp then
			s.trailValue = hp
		end
		s.trail.Size = UDim2.fromScale(s.trailValue, 1)
		if hp < 0.3 then
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * 8)
			s.fillGrad.Color = ColorSequence.new(Color3.fromHex("#FF8A6A"):Lerp(Color3.fromHex("#E04A3A"), pulse), Color3.fromHex("#8A1A12"))
		else
			s.fillGrad.Color = ColorSequence.new(Color3.fromHex("#F6EFDC"), Color3.fromHex("#C9A24A"))
		end
		-- meter
		local m = f.meter
		for k, seg in s.segs do
			local v = math.clamp((m - (k - 1) * Config.MeterBar) / Config.MeterBar, 0, 1)
			seg.fill.Size = UDim2.fromScale(v, 1)
			seg.frame:FindFirstChildOfClass("UIStroke").Color = (v >= 1) and C.goldBright or C.goldDim
		end
		s.meterLabel.Text = string.format("RAGE  %d", math.floor(m / Config.MeterBar))
		-- echo gauge
		local ready = f.echoCD <= 0
		local e = 1 - math.clamp(f.echoCD / Config.EchoCooldown, 0, 1)
		s.echoFill.Size = UDim2.fromScale(1, e)
		s.echoStroke.Transparency = ready and (0.2 * (0.5 + 0.5 * math.sin(os.clock() * 6))) or 0.6
		-- combo timeout
		if s.comboTimer > 0 then
			s.comboTimer -= dt
			if s.comboTimer <= 0.4 then
				local k = math.clamp(s.comboTimer / 0.4, 0, 1)
				s.comboHits.TextTransparency = 1 - k
				s.comboDmg.TextTransparency = 1 - k
			end
			if s.comboTimer <= 0 then
				s.combo.Visible = false
			end
		end
	end
	-- timer
	if not match.training then
		local secs = math.ceil(match.timer / Config.TickRate)
		self.timerText.Text = tostring(secs)
		self.timerText.TextColor3 = secs <= 10 and C.crimsonBright or C.goldBright
		self.roundText.Text = "ROUND " .. tostring(match.round)
	end
	self:setRoundPips(match.fighters[1].roundWins, match.fighters[2].roundWins)
	-- low health vignette for the human player
	local p1 = match.fighters[1]
	local low = (p1.hp / p1.maxHp) < 0.25 and match.phase == "fight"
	self.lowVig.BackgroundTransparency = low and (0.55 + 0.25 * math.sin(os.clock() * 5)) or 1
end

function HUD:trainingInfo(lines: { string })
	if not self.training then
		return
	end
	for i, l in self.training.lines do
		l.Text = lines[i] or ""
	end
end

-- Cinematic mode: letterbox bars slide in and the gameplay HUD slides out of frame.
function HUD:cinema(on: boolean, time: number?)
	local cb = self.cinemaBars
	if not cb or cb.on == on then
		return
	end
	cb.on = on
	local t = time or 0.45
	local style = Enum.EasingStyle.Quart
	Theme.tween(cb.top, t, { Position = UDim2.fromScale(0, on and 0 or -0.12) }, style)
	Theme.tween(cb.bottom, t, { Position = UDim2.fromScale(0, on and 0.88 or 1) }, style)
	for _, s in self.sides do
		local hp, bp = s.holderPos, s.bottomPos
		Theme.tween(s.holder, t, { Position = on and (hp + UDim2.fromOffset(0, -260)) or hp }, style)
		Theme.tween(s.bottom, t, { Position = on and (bp + UDim2.fromOffset(0, 200)) or bp }, style)
	end
	if self.timerFrame and self.timerPos then
		Theme.tween(self.timerFrame, t, { Position = on and (self.timerPos + UDim2.fromOffset(0, -260)) or self.timerPos }, style)
	end
end

-- Lower-third name card for a fighter's intro.
function HUD:nameCard(side: number, def, hold: number?)
	local c = self.cards and self.cards[side]
	if not c then
		return
	end
	local left = side == 1
	c.token += 1
	local token = c.token
	c.name.Text = def.name
	c.title.Text = string.upper(def.title or "")
	c.realm.Text = (def.realm or "") .. (def.archetype and ("   \u{2022}   " .. string.upper(def.archetype)) or "")
	c.stripe.BackgroundColor3 = Color3.fromHex(def.accent)
	c.frame.Visible = true
	c.frame.Position = UDim2.new(left and -0.6 or 1.6, 0, 0.62, 0)
	Theme.tween(c.frame, 0.35, { Position = UDim2.new(left and 0 or 1, 0, 0.62, 0) }, Enum.EasingStyle.Quart)
	task.delay(hold or 2.0, function()
		if c.token ~= token or self.destroyed then
			return
		end
		Theme.tween(c.frame, 0.3, { Position = UDim2.new(left and -0.6 or 1.6, 0, 0.62, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		task.delay(0.32, function()
			if c.token == token and not self.destroyed then
				c.frame.Visible = false
			end
		end)
	end)
end

function HUD:setVisible(v: boolean)
	self.root.Visible = v
end

function HUD:destroy()
	self.destroyed = true
	self.root:Destroy()
end

return HUD
