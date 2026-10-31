-- A headless Roblox client runtime for Lune.
--
-- Uses @lune/roblox's real Instance implementation (so every property name, type and
-- enum is validated against Roblox's reflection database) and fills in what Lune does
-- not emulate: events/signals, services (RunService, TweenService, UserInputService,
-- Debris...), a LocalPlayer, BulkMoveTo, ParticleEmitter:Emit, Sound playback.
-- Any error raised inside an event handler is recorded so tests can fail on it.

local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Instance = roblox.Instance

local Mock = {}
Mock.errors = {}

local function recordError(where, err)
	table.insert(Mock.errors, string.format("[%s] %s", where, tostring(err)))
end
Mock.recordError = recordError

-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

local IMMEDIATE = { RenderStepped = true, Heartbeat = true, Stepped = true }

function Signal.new(name, immediate)
	return setmetatable({ handlers = {}, waiting = {}, name = name or "signal", immediate = immediate }, Signal)
end

function Signal:Connect(fn)
	local entry = { fn = fn, dead = false }
	local conn = { Connected = true }
	function conn:Disconnect()
		self.Connected = false
		entry.dead = true
	end
	table.insert(self.handlers, entry)
	return conn
end

function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Wait()
	local th = coroutine.running()
	table.insert(self.waiting, th)
	return coroutine.yield()
end

function Signal:Fire(...)
	local list = self.handlers
	local alive = {}
	for _, h in list do
		if not h.dead then
			table.insert(alive, h)
		end
	end
	self.handlers = alive
	local name = self.name
	-- Roblox's default SignalBehavior is Deferred: handlers and :Wait() resumptions run
	-- after the firing thread yields. RunService signals are driven immediately.
	local runner = self.immediate and task.spawn or task.defer
	for _, h in alive do
		if not h.dead then
			runner(function(...)
				if h.dead then
					return
				end
				local ok, err = pcall(h.fn, ...)
				if not ok then
					recordError(name, err)
				end
			end, ...)
		end
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, th in waiting do
		runner(th, ...)
	end
end
Mock.Signal = Signal

-------------------------------------------------------------------------------
-- Per-instance event storage
-------------------------------------------------------------------------------

local signals = setmetatable({}, { __mode = "k" })
local function signalFor(inst, name)
	local t = signals[inst]
	if not t then
		t = {}
		signals[inst] = t
	end
	local s = t[name]
	if not s then
		s = Signal.new(inst.ClassName .. "." .. name, IMMEDIATE[name])
		t[name] = s
	end
	return s
end
Mock.signalFor = signalFor

local EVENTS = {
	"Destroying",
	"Changed",
	"ChildAdded",
	"ChildRemoved",
	"AncestryChanged",
	"Activated",
	"MouseEnter",
	"MouseLeave",
	"MouseButton1Click",
	"MouseButton1Down",
	"InputBegan",
	"InputEnded",
	"InputChanged",
	"Event",
	"Completed",
	"RenderStepped",
	"Heartbeat",
	"Stepped",
	"PreSimulation",
	"PostSimulation",
	"TouchStarted",
	"TouchMoved",
	"TouchEnded",
	"Loaded",
	"PlayerAdded",
	"PlayerRemoving",
	"OnClientEvent",
	"WindowFocusReleased",
	"WindowFocused",
	"TextBoxFocused",
}
for _, ev in EVENTS do
	roblox.implementProperty("Instance", ev, function(inst)
		return signalFor(inst, ev)
	end)
end

-------------------------------------------------------------------------------
-- Methods Lune doesn't implement
-------------------------------------------------------------------------------

Mock.waitForChildOverrides = {}

roblox.implementMethod("Instance", "WaitForChild", function(inst, name, _timeout)
	local o = Mock.waitForChildOverrides[name]
	if o ~= nil and (inst.ClassName == "ReplicatedStorage") then
		if o == false then
			return nil
		end
		return o
	end
	local c = inst:FindFirstChild(name)
	if c then
		return c
	end
	if _timeout then
		return nil
	end
	error("WaitForChild would yield forever: " .. inst:GetFullName() .. "." .. name)
end)

roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(inst, prop)
	return signalFor(inst, "prop:" .. prop)
end)

roblox.implementMethod("Model", "GetPivot", function(inst)
	local pp = inst.PrimaryPart
	if pp then
		return pp.CFrame
	end
	local first = inst:FindFirstChildWhichIsA("BasePart", true)
	return first and first.CFrame or roblox.CFrame.identity
end)

local function bulkMove(_self, parts, cframes, _mode)
	for i, p in parts do
		p.CFrame = cframes[i]
	end
end
roblox.implementMethod("Workspace", "BulkMoveTo", bulkMove)
roblox.implementMethod("WorldModel", "BulkMoveTo", bulkMove)

roblox.implementMethod("ParticleEmitter", "Emit", function(_inst, n)
	assert(type(n) == "number", "Emit expects a number")
end)
for _, m in { "Play", "Stop", "Pause", "Resume" } do
	roblox.implementMethod("Sound", m, function() end)
end
roblox.implementMethod("BindableEvent", "Fire", function(inst, ...)
	signalFor(inst, "Event"):Fire(...)
end)
roblox.implementMethod("RunService", "IsStudio", function()
	return true
end)
roblox.implementMethod("RunService", "IsClient", function()
	return true
end)
roblox.implementMethod("StarterGui", "SetCoreGuiEnabled", function() end)
roblox.implementMethod("DataModel", "IsLoaded", function()
	return true
end)
roblox.implementMethod("Debris", "AddItem", function(_self, inst, life)
	task.delay(life or 0, function()
		pcall(function()
			inst:Destroy()
		end)
	end)
end)
roblox.implementMethod("TweenService", "Create", function(_self, inst, info, props)
	assert(type(info) == "table" and info.__tweeninfo, "TweenService:Create expects TweenInfo")
	-- validate every property up-front, exactly like Roblox would
	for k, v in props do
		local cur = inst[k]
		if typeof(cur) ~= typeof(v) and not (type(cur) == "number" and type(v) == "number") then
			error(string.format("Tween property %s type mismatch: %s vs %s", k, typeof(cur), typeof(v)))
		end
	end
	local completed = Signal.new("Tween.Completed")
	local tween = { Completed = completed }
	function tween:Play()
		for k, v in props do
			inst[k] = v
		end
		task.defer(function()
			completed:Fire(roblox.Enum.PlaybackState.Completed)
		end)
	end
	function tween:Cancel() end
	function tween:Pause() end
	return tween
end)

roblox.implementProperty("UserInputService", "TouchEnabled", function()
	return Mock.touch == true
end)
roblox.implementProperty("UserInputService", "KeyboardEnabled", function()
	return Mock.touch ~= true
end)
roblox.implementProperty("UserInputService", "GamepadEnabled", function()
	return false
end)

local TweenInfo = {
	new = function(time, style, dir, rep, rev, delay)
		return { __tweeninfo = true, Time = time or 1, EasingStyle = style, EasingDirection = dir, RepeatCount = rep, Reverses = rev, DelayTime = delay }
	end,
}

-------------------------------------------------------------------------------
-- World
-------------------------------------------------------------------------------

function Mock.build(sharedNode)
	local game = Instance.new("DataModel")
	local workspace = game:GetService("Workspace")
	local camera = Instance.new("Camera")
	camera.ViewportSize = roblox.Vector2.new(1600, 900)
	camera.Parent = workspace
	workspace.CurrentCamera = camera
	local players = game:GetService("Players")
	local player = Instance.new("Player")
	player.Name = "Tester"
	local pg = Instance.new("PlayerGui")
	pg.Parent = player
	player.Parent = players
	roblox.implementProperty("Players", "LocalPlayer", function()
		return player
	end)
	pcall(function()
		players.LocalPlayer = player
	end)
	for _, s in { "RunService", "TweenService", "UserInputService", "Debris", "StarterGui", "SoundService", "Lighting", "ReplicatedStorage", "ContextActionService", "GuiService" } do
		game:GetService(s)
	end
	Mock.waitForChildOverrides.Veil = sharedNode
	Mock.waitForChildOverrides.VeilRemotes = false
	Mock.game = game
	Mock.workspace = workspace
	Mock.player = player
	Mock.playerGui = pg
	Mock.runService = game:GetService("RunService")
	Mock.uis = game:GetService("UserInputService")
	Mock.uis.TouchEnabled = Mock.touch == true
	Mock.uis.KeyboardEnabled = Mock.touch ~= true
	Mock.uis.GamepadEnabled = false

	local env = {
		game = game,
		workspace = workspace,
		Instance = Instance,
		Enum = roblox.Enum,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		Font = roblox.Font,
		Rect = roblox.Rect,
		BrickColor = roblox.BrickColor,
		TweenInfo = TweenInfo,
		task = task,
		warn = function(...)
			recordError("warn", table.concat({ ... }, " "))
		end,
	}
	return env
end

-- Drive one rendered frame.
function Mock.frame(dt)
	local rs = Mock.runService
	signalFor(rs, "RenderStepped"):Fire(dt)
	signalFor(rs, "Heartbeat"):Fire(dt)
end

return Mock
