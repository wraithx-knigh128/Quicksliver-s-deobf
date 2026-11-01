-- Builds UI screens with the real client code inside the mock runtime and dumps the
-- resolved layout (absolute rects, colours, text) as JSON for tools/ui_preview.py.
--   lune run tools/ui_dump <hud|menu|select|stage|results|versus|pause|movelist>
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local process = require("@lune/process")
local Loader = require("../tests/loader")
local Mock = require("../tests/mock_roblox")

local which = process.args[1] or "hud"
local touch = process.args[2] == "touch"
local shared = Loader.root("src/shared")
local client = Loader.root("src/client")
local env = Mock.build(shared)
Loader.addGlobals(env)
local Theme = Loader.require(client.UI.Theme)
local Input = Loader.require(client.Core.Input)

local gui = roblox.Instance.new("ScreenGui")
gui.Parent = Mock.playerGui
local root = Theme.root(gui)

local function pump(n)
	for _ = 1, n do
		Mock.frame(1 / 60)
	end
	task.wait()
end

if which == "hub" or which == "trade" or which == "inv" then
	local Net = Loader.require(client.Net.Net)
	local OnlineScreens = Loader.require(client.UI.OnlineScreens)
	Net.inv = {
		res = { studs = 120, scrap = 40, glitch = 5, relic = 2, token = 1 },
		weapons = { { uid = "w1-1", item = "katana_neon", ench = "blazing", lvl = 4 }, { uid = "w1-2", item = "hammer_ban", ench = "rainbow", lvl = 10 }, { uid = "w1-3", item = "great_cosmic", lvl = 1 }, { uid = "w1-4", item = "bow_camo", ench = "toxic", lvl = 2 } },
		equipped = { noob = "w1-1" },
	}
	task.spawn(function()
		if which == "hub" then
			OnlineScreens.hub(root, { pending = 2 })
		elseif which == "inv" then
			OnlineScreens.inventory(root)
		else
			OnlineScreens.trade(root, { with = 2, name = "Rival" })
		end
	end)
	pump(20)
	task.wait(0.6)
	if which == "trade" then
		Net.onTrade:Fire({ op = "state", mine = { weapons = { { uid = "w1-2", item = "hammer_ban", ench = "rainbow" } }, res = { studs = 25 } }, theirs = { weapons = { { uid = "w2-9", item = "daggers_666", ench = "glitched" } }, res = { relic = 1 } }, readyMe = true, readyThem = false })
		task.wait(0.2)
	end
	pump(5)
elseif which == "freeze" then
	-- cutscene editing overlays: freeze-frame name card + pop caption + letterbox
	local CineFX = Loader.require(client.Render.CineFX)
	local fx = CineFX.new(root, 40)
	Theme.frame(root, { Size = roblox.UDim2.new(1, 0, 0, 96), BackgroundColor3 = roblox.Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 50 })
	Theme.frame(root, { Size = roblox.UDim2.new(1, 0, 0, 96), Position = roblox.UDim2.new(0, 0, 1, -96), BackgroundColor3 = roblox.Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 50 })
	task.spawn(function()
		fx:freezeFrame("GUEST 666", "The Account That Should Not Exist", roblox.Color3.fromHex("#B03AFF"), 2, 30)
	end)
	fx:pop("SUS", roblox.Vector2.new(0.3, 0.3), nil, nil, 30)
	pump(40)
	task.wait(0.4)
	pump(5)
elseif which == "intro" then
	-- round 1 intro: letterbox, P1 name card
	local FightView = Loader.require(client.Render.FightView)
	local view = FightView.new({
		root = root,
		p1 = { fighter = "studzilla", echo = "grandpa" },
		p2 = { fighter = "guest", echo = "nightguard", cpu = true, difficulty = 3 },
		stage = "cathedral",
		seed = 5,
	})
	for _ = 1, 60 do
		pump(5)
		if view.hud.cards[1].frame.Visible then
			break
		end
	end
	pump(40)
elseif which == "hud" then
	if touch then
		Input.mode = "touch"
	end
	local FightView = Loader.require(client.Render.FightView)
	local view = FightView.new({
		root = root,
		p1 = { fighter = "noob", echo = "grandpa", cpu = true, difficulty = 4 },
		p2 = { fighter = "admin", echo = "nightguard", cpu = true, difficulty = 4 },
		stage = "emberthrone",
		seed = 3,
		shortIntro = true,
		forceTouch = touch,
		showPowers = true,
	})
	for _ = 1, 40 do
		pump(30)
		if view.match.phase == "fight" and view.match.frame > 900 then
			break
		end
	end
	view.hud:combo(1, 5, 23)
	view.hud:announce("ROUND 2", nil, { hold = 10 })
	pump(2)
else
	local Screens = Loader.require(client.UI.Screens)
	task.spawn(function()
		if which == "menu" then
			Screens.mainMenu(root, { wins = 12, ascents = 2, storyDone = true })
		elseif which == "select" then
			Screens.characterSelect(root, { pickOpponent = true })
		elseif which == "echo" then
			Screens.characterSelect(root, { pickOpponent = true })
		elseif which == "stage" then
			Screens.stageSelect(root, 2)
		elseif which == "results" then
			Screens.results(root, {
				winner = 1,
				p1 = { fighter = "emote", echo = "dana" },
				p2 = { fighter = "frosty", echo = "pigeon" },
				stats = { { damage = 1012, hits = 41, maxCombo = 7, specials = 9, supers = 1, echoes = 3, throws = 2, blocks = 14 }, { damage = 640, hits = 22, maxCombo = 4, specials = 6, supers = 0, echoes = 2, throws = 1, blocks = 20 } },
			})
		elseif which == "versus" then
			Screens.versus(root, { fighter = "bacon", echo = "dana" }, { fighter = "studzilla", echo = "nightguard" }, "hollowroot")
		elseif which == "pause" then
			Screens.pause(root, {})
		elseif which == "movelist" then
			Screens.moveList(root, "guest")
		elseif which == "title" then
			Screens.title(root)
		end
	end)
	for _ = 1, 30 do
		pump(4)
		task.wait(0.05)
	end
	if which == "echo" then
		Input.nav:Fire("confirm")
		for _ = 1, 30 do
			pump(4)
			task.wait(0.05)
		end
	end
	task.wait(1.0)
	pump(4)
end

-- resolve layout
local out = {}
local function resolve(inst, px, py, pw, ph, scale, depth)
	if not inst:IsA("GuiObject") then
		return
	end
	if not inst.Visible then
		return
	end
	local s = inst.Size
	local p = inst.Position
	local a = inst.AnchorPoint
	local w = s.X.Scale * pw + s.X.Offset * scale
	local h = s.Y.Scale * ph + s.Y.Offset * scale
	local x = px + p.X.Scale * pw + p.X.Offset * scale - a.X * w
	local y = py + p.Y.Scale * ph + p.Y.Offset * scale - a.Y * h
	local localScale = scale
	local us = inst:FindFirstChildOfClass("UIScale")
	if us then
		localScale = scale * us.Scale
		w = w * us.Scale
		h = h * us.Scale
	end
	local e = {
		class = inst.ClassName,
		name = inst.Name,
		x = x,
		y = y,
		w = w,
		h = h,
		z = inst.ZIndex,
		depth = depth,
		rot = inst.Rotation,
		bg = { inst.BackgroundColor3.R, inst.BackgroundColor3.G, inst.BackgroundColor3.B },
		bgT = inst.BackgroundTransparency,
	}
	local grad = inst:FindFirstChildOfClass("UIGradient")
	if grad then
		local kp = grad.Color.Keypoints
		e.grad = { { kp[1].Value.R, kp[1].Value.G, kp[1].Value.B }, { kp[#kp].Value.R, kp[#kp].Value.G, kp[#kp].Value.B } }
		e.gradRot = grad.Rotation
	end
	local stroke = inst:FindFirstChildOfClass("UIStroke")
	if stroke and stroke.ApplyStrokeMode == roblox.Enum.ApplyStrokeMode.Border then
		e.stroke = { stroke.Color.R, stroke.Color.G, stroke.Color.B, stroke.Thickness * scale, stroke.Transparency }
	end
	local corner = inst:FindFirstChildOfClass("UICorner")
	if corner then
		e.corner = corner.CornerRadius.Offset * scale + corner.CornerRadius.Scale * math.min(w, h)
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") then
		e.text = inst.Text
		e.textColor = { inst.TextColor3.R, inst.TextColor3.G, inst.TextColor3.B }
		e.textSize = inst.TextSize * localScale
		e.textT = inst.TextTransparency
		e.xAlign = inst.TextXAlignment.Name
		e.yAlign = inst.TextYAlignment.Name
		e.wrap = inst.TextWrapped
		local fam = inst.FontFace.Family
		e.serif = string.find(fam, "Accanthis") ~= nil or string.find(fam, "Merriweather") ~= nil or string.find(fam, "Guru") ~= nil
	end
	if inst:IsA("ImageLabel") then
		e.image = inst.Image
		e.imageT = inst.ImageTransparency
	end
	if inst:IsA("ViewportFrame") then
		e.viewport = true
		local wm = inst:FindFirstChildOfClass("WorldModel")
		local cam = inst:FindFirstChildOfClass("Camera")
		if wm and cam then
			-- project the rig parts with the viewport camera for a silhouette preview
			local parts = {}
			local camCF = cam.CFrame
			local fov = math.rad(cam.FieldOfView)
			for _, d in wm:GetDescendants() do
				if d:IsA("BasePart") and d.Transparency < 0.95 then
					local rel = camCF:PointToObjectSpace(d.CFrame.Position)
					if rel.Z < 0 then
						local k = (h / 2) / math.tan(fov / 2)
						local sx = x + w / 2 + rel.X / -rel.Z * k
						local sy = y + h / 2 - rel.Y / -rel.Z * k
						local size = math.max(d.Size.X, d.Size.Y, d.Size.Z) / -rel.Z * k
						table.insert(parts, { sx, sy, size, d.Color.R, d.Color.G, d.Color.B, -rel.Z, d.Material.Name == "Neon" })
					end
				end
			end
			e.parts = parts
		end
	end
	table.insert(out, e)
	local kids = inst:GetChildren()
	local order = {}
	for i, k in kids do
		order[k] = i
	end
	table.sort(kids, function(a2, b2)
		local za = a2:IsA("GuiObject") and a2.ZIndex or 0
		local zb = b2:IsA("GuiObject") and b2.ZIndex or 0
		if za == zb then
			return order[a2] < order[b2]
		end
		return za < zb
	end)
	for _, c in kids do
		resolve(c, x, y, w, h, localScale, depth + 1)
	end
end

local vp = Mock.workspace.CurrentCamera.ViewportSize
local rs = root:FindFirstChildOfClass("UIScale").Scale
local rw = root.Size.X.Offset * rs
local rh = root.Size.Y.Offset * rs
for _, c in root:GetChildren() do
	resolve(c, (vp.X - rw) / 2, (vp.Y - rh) / 2, rw, rh, rs, 1)
end
fs.writeFile("/tmp/ui.json", serde.encode("json", { w = vp.X, h = vp.Y, items = out }))
print("ui items", #out)
process.exit(0)
