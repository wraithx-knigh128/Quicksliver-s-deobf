--!nonstrict
-- Subtitles for story scenes, intros and victory quotes.

local Theme = require(script.Parent.Theme)

local C = Theme.Colors
local F = Theme.Fonts

local Subtitles = {}
Subtitles.enabled = true

local holder, speakerLabel, lineLabel, token = nil, nil, nil, 0

function Subtitles.mount(root: Instance)
	holder = Theme.frame(root, {
		Name = "Subtitles",
		Size = UDim2.new(0, 1200, 0, 110),
		Position = UDim2.new(0.5, 0, 1, -40),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 40,
		Visible = false,
	})
	speakerLabel = Theme.label(holder, "", {
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.labelBold,
		TextSize = 22,
		TextColor3 = C.goldBright,
		ZIndex = 41,
	})
	Theme.textStroke(speakerLabel, 2, 0.15)
	lineLabel = Theme.label(holder, "", {
		Size = UDim2.new(1, 0, 0, 76),
		Position = UDim2.fromOffset(0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		FontFace = F.serif,
		TextSize = 32,
		TextWrapped = true,
		TextColor3 = C.ivory,
		ZIndex = 41,
	})
	Theme.textStroke(lineLabel, 2.5, 0.1)
end

function Subtitles.show(speaker: string?, text: string, duration: number, color: Color3?)
	if not holder or not Subtitles.enabled then
		return
	end
	token += 1
	local my = token
	holder.Visible = true
	speakerLabel.Text = speaker or ""
	speakerLabel.TextColor3 = color or C.goldBright
	lineLabel.Text = text
	speakerLabel.TextTransparency = 1
	lineLabel.TextTransparency = 1
	Theme.tween(speakerLabel, 0.2, { TextTransparency = 0 })
	Theme.tween(lineLabel, 0.2, { TextTransparency = 0 })
	task.delay(duration, function()
		if token == my then
			Theme.tween(speakerLabel, 0.25, { TextTransparency = 1 })
			Theme.tween(lineLabel, 0.25, { TextTransparency = 1 })
			task.delay(0.26, function()
				if token == my then
					holder.Visible = false
				end
			end)
		end
	end)
end

function Subtitles.hide()
	token += 1
	if holder then
		holder.Visible = false
	end
end

return Subtitles
