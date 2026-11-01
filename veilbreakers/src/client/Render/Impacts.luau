--!nonstrict
-- Battlegrounds-style impact effects (original implementations of common Roblox
-- VFX techniques):
--
--   crater        ring of rock chunks that bursts up around an impact and sinks away
--   debris        rock chunks thrown along bezier arcs that tumble and land
--   afterimage    fading glass copies of a fighter's body (dashes, teleports, supers)
--   impactLines   anime-style streaks bursting out of a big hit
--   forkLightning a jagged bolt with side branches
--   dome          an expanding force-field shell for supers and finishers
--
-- Parts come from a small pool and every moving piece is driven by one Heartbeat
-- loop (no physics, no per-effect connections), with hard caps on live pieces.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Impacts = {}

local V = Vector3.new
local C = CFrame.new
local A = CFrame.Angles
local rad = math.rad

local MAX_DEBRIS = 60
local MAX_ROCKS = 90

local folder = nil
local function container(): Instance
	if folder and folder.Parent then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = "VeilImpacts"
	folder.Parent = workspace
	return folder
end

-------------------------------------------------------------------------------
-- Part pool
-------------------------------------------------------------------------------

local pool = {}
local live = { rocks = 0, debris = 0 }

local function getPart(): BasePart
	local p = table.remove(pool)
	if not p or not p.Parent then
		p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Name = "Rock"
	end
	p.Transparency = 0
	p.CastShadow = true
	p.Parent = container()
	return p
end

local function releasePart(p: BasePart)
	p.CFrame = C(0, -500, 0)
	if #pool < 160 then
		table.insert(pool, p)
	else
		p:Destroy()
	end
end

-------------------------------------------------------------------------------
-- One loop drives every moving piece
-------------------------------------------------------------------------------

local movers = {}
local loop = nil

local function ensureLoop()
	if loop then
		return
	end
	loop = RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for i = #movers, 1, -1 do
			local mv = movers[i]
			local k = (now - mv.t0) / mv.dur
			if k >= 1 then
				local keep = mv.finish and mv.finish(mv)
				if not keep then
					table.remove(movers, i)
				end
			else
				mv.step(mv, k, dt)
			end
		end
		if #movers == 0 then
			loop:Disconnect()
			loop = nil
		end
	end)
end

local function addMover(mv)
	mv.t0 = os.clock()
	table.insert(movers, mv)
	ensureLoop()
end

-------------------------------------------------------------------------------
-- Crater
-------------------------------------------------------------------------------

-- pos on the floor; radius in studs; colour / material of the ground
function Impacts.crater(pos: Vector3, radius: number, color: Color3, material: Enum.Material?, count: number?)
	local n = math.min(count or math.floor(8 + radius * 2.4), MAX_ROCKS - live.rocks)
	if n <= 0 then
		return
	end
	local base = V(pos.X, 0, pos.Z)
	for i = 1, n do
		local ang = (i / n) * math.pi * 2 + (math.random() - 0.5) * 0.35
		local r = radius * (0.85 + math.random() * 0.3)
		local s = (0.55 + math.random() * 0.9) * math.max(0.7, radius / 3.5)
		local p = getPart()
		p.Size = V(s * (1 + math.random() * 0.6), s * (0.6 + math.random() * 0.6), s * (0.8 + math.random() * 0.5))
		p.Color = color:Lerp(Color3.new(0, 0, 0), math.random() * 0.25)
		p.Material = material or Enum.Material.Slate
		local out = V(math.cos(ang), 0, math.sin(ang))
		-- tilted outward like the floor was punched open
		local tilt = rad(28 + math.random() * 30)
		local spot = base + out * r
		local final = CFrame.lookAt(spot, spot + out) * A(-tilt, 0, rad((math.random() - 0.5) * 40)) * C(0, s * 0.15, 0)
		local below = final * C(0, -s * 1.2, 0)
		live.rocks += 1
		addMover({
			dur = 1.9 + math.random() * 0.4,
			step = function(_, k)
				if k < 0.06 then
					p.CFrame = below:Lerp(final, k / 0.06)
				elseif k > 0.78 then
					local f = (k - 0.78) / 0.22
					p.CFrame = final:Lerp(below, f)
					p.Transparency = f * 0.6
				else
					p.CFrame = final
				end
			end,
			finish = function()
				live.rocks -= 1
				releasePart(p)
			end,
		})
	end
	-- a dark scorch in the middle
	local scorch = Instance.new("Part")
	scorch.Anchored = true
	scorch.CanCollide = false
	scorch.CanQuery = false
	scorch.CanTouch = false
	scorch.CastShadow = false
	scorch.Shape = Enum.PartType.Cylinder
	scorch.Material = Enum.Material.Slate
	scorch.Color = color:Lerp(Color3.new(0, 0, 0), 0.6)
	scorch.Size = V(0.05, radius * 1.7, radius * 1.7)
	scorch.CFrame = C(base + V(0, 0.03, 0)) * A(0, 0, rad(90))
	scorch.Transparency = 0.15
	scorch.Parent = container()
	TweenService:Create(scorch, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	Debris:AddItem(scorch, 2.3)
end

-------------------------------------------------------------------------------
-- Bezier debris
-------------------------------------------------------------------------------

local function bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: number): Vector3
	local u = 1 - t
	return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
end

-- dir: +1 / -1 bias along X (the way the blow travelled), or 0 for a radial burst
function Impacts.debris(pos: Vector3, count: number, color: Color3, material: Enum.Material?, dir: number?)
	local n = math.min(count, MAX_DEBRIS - live.debris)
	for _ = 1, n do
		local p = getPart()
		local s = 0.25 + math.random() * 0.55
		p.Size = V(s, s * (0.6 + math.random() * 0.6), s)
		p.Color = color:Lerp(Color3.new(0, 0, 0), math.random() * 0.3)
		p.Material = material or Enum.Material.Slate
		p.CastShadow = false
		local ang = math.random() * math.pi * 2
		local reach = 2.5 + math.random() * 5
		local bias = (dir or 0) * (1.5 + math.random() * 2.5)
		local start = V(pos.X, math.max(0.2, pos.Y), pos.Z)
		local land = V(pos.X + math.cos(ang) * reach + bias, s * 0.4, pos.Z + math.sin(ang) * reach * 0.6)
		local apex = (start + land) / 2 + V(0, 2.5 + math.random() * 4, 0)
		local spin = V(math.random() * 14 - 7, math.random() * 14 - 7, math.random() * 14 - 7)
		local landed = false
		live.debris += 1
		addMover({
			dur = 0.55 + math.random() * 0.35,
			step = function(_, k)
				local at = bezier(start, apex, land, k)
				p.CFrame = C(at) * A(spin.X * k, spin.Y * k, spin.Z * k)
			end,
			finish = function(mv)
				if not landed then
					-- rest on the floor a moment, then fade
					landed = true
					mv.t0 = os.clock()
					mv.dur = 0.9
					local rest = p.CFrame
					mv.step = function(_, k)
						p.CFrame = rest
						if k > 0.5 then
							p.Transparency = (k - 0.5) * 2
						end
					end
					return true
				end
				live.debris -= 1
				releasePart(p)
				return false
			end,
		})
	end
end

-------------------------------------------------------------------------------
-- Afterimage
-------------------------------------------------------------------------------

local BODY = { "Head", "UpperTorso", "LowerTorso", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" }

function Impacts.afterimage(rig, color: Color3, life: number?)
	local t = life or 0.32
	local holder = Instance.new("Model")
	holder.Name = "Afterimage"
	for _, name in BODY do
		local src = rig.parts and rig.parts[name]
		if src then
			local g = Instance.new("Part")
			g.Anchored = true
			g.CanCollide = false
			g.CanQuery = false
			g.CanTouch = false
			g.CastShadow = false
			g.Material = Enum.Material.Glass
			g.Color = color
			g.Size = src.Size * 1.02
			g.CFrame = src.CFrame
			g.Transparency = 0.45
			g.Parent = holder
			TweenService:Create(g, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1, Size = src.Size * 1.12 }):Play()
		end
	end
	holder.Parent = container()
	Debris:AddItem(holder, t + 0.05)
end

-------------------------------------------------------------------------------
-- Impact lines, forked lightning, dome
-------------------------------------------------------------------------------

local function neon(size: Vector3, cf: CFrame, color: Color3, life: number, goal)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = container()
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, life + 0.05)
	return p
end

-- Streaks bursting outward in the screen plane from a big hit.
function Impacts.impactLines(pos: Vector3, color: Color3, count: number?, length: number?)
	local n = count or 10
	local len = length or 5
	for i = 1, n do
		local ang = (i / n) * math.pi * 2 + (math.random() - 0.5) * 0.4
		local dir = V(math.cos(ang), math.sin(ang), 0)
		local l = len * (0.6 + math.random() * 0.6)
		local mid = pos + dir * (0.8 + l * 0.5) + V(0, 0, 0.9)
		local cf = CFrame.lookAt(mid, mid + dir) * A(0, rad(90), 0)
		neon(V(l * 0.3, 0.09, 0.09), cf, color, 0.18, { Size = V(l, 0.02, 0.02), Transparency = 1, CFrame = cf + dir * (l * 0.4) })
	end
end

-- Jagged bolt with two side branches (a -> b).
function Impacts.forkLightning(a: Vector3, b: Vector3, color: Color3, life: number?)
	local t = life or 0.16
	local function bolt(p0: Vector3, p1: Vector3, segs: number, jitter: number, width: number)
		local prev = p0
		local points = {}
		for i = 1, segs do
			local k = i / segs
			local p = p0:Lerp(p1, k)
			if i < segs then
				p += V((math.random() - 0.5) * jitter, (math.random() - 0.5) * jitter, (math.random() - 0.5) * jitter * 0.3)
			end
			local mid = (prev + p) / 2
			local len = (p - prev).Magnitude
			neon(V(width, width, len), CFrame.lookAt(mid, p), color, t, { Transparency = 1 })
			table.insert(points, p)
			prev = p
		end
		return points
	end
	local main = bolt(a, b, 7, 1.1, 0.14)
	for k = 1, 2 do
		local from = main[math.clamp(2 + k * 2, 1, #main)]
		if from then
			local off = V((math.random() - 0.5) * 3, -1 - math.random() * 2, 0)
			bolt(from, from + off, 3, 0.6, 0.07)
		end
	end
end

-- Expanding force-field shell + neon ring (supers, finishers).
function Impacts.dome(pos: Vector3, color: Color3, size: number?)
	local s = size or 16
	local shell = Instance.new("Part")
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CastShadow = false
	shell.Shape = Enum.PartType.Ball
	shell.Material = Enum.Material.ForceField
	shell.Color = color
	shell.Size = V(1, 1, 1)
	shell.CFrame = C(pos)
	shell.Transparency = 0
	shell.Parent = container()
	TweenService:Create(shell, TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = V(s, s, s), Transparency = 1 }):Play()
	Debris:AddItem(shell, 0.6)
	local ringCF = C(V(pos.X, 0.12, pos.Z)) * A(0, 0, rad(90))
	neon(V(0.06, 1, 1), ringCF, color, 0.5, { Size = V(0.04, s * 1.4, s * 1.4), Transparency = 1 })
end

-- Tear everything down (stage change / fight end).
function Impacts.clear()
	table.clear(movers)
	live.rocks, live.debris = 0, 0
	if loop then
		loop:Disconnect()
		loop = nil
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(pool)
end

function Impacts.stats()
	return { rocks = live.rocks, debris = live.debris, pooled = #pool, movers = #movers }
end

return Impacts
