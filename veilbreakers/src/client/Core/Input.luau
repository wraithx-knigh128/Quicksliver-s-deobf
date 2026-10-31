--!nonstrict
-- Unified input: keyboard, gamepad and touch feed one fight-input table and one stream
-- of menu navigation events. Remembers the last device used for button prompts.

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Input = {}

Input.mode = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and "touch" or "keyboard"
Input.modeChanged = Instance.new("BindableEvent")
Input.nav = Instance.new("BindableEvent") -- (action: string)
Input.anyPressed = Instance.new("BindableEvent")

local KEY_FIGHT = {
	[Enum.KeyCode.A] = "left",
	[Enum.KeyCode.Left] = "left",
	[Enum.KeyCode.D] = "right",
	[Enum.KeyCode.Right] = "right",
	[Enum.KeyCode.W] = "up",
	[Enum.KeyCode.Up] = "up",
	[Enum.KeyCode.Space] = "up",
	[Enum.KeyCode.S] = "down",
	[Enum.KeyCode.Down] = "down",
	[Enum.KeyCode.J] = "L",
	[Enum.KeyCode.K] = "H",
	[Enum.KeyCode.L] = "K",
	[Enum.KeyCode.I] = "S",
	[Enum.KeyCode.U] = "B",
	[Enum.KeyCode.LeftShift] = "B",
	[Enum.KeyCode.O] = "E",
	[Enum.KeyCode.P] = "X",
	[Enum.KeyCode.Semicolon] = "X",
	[Enum.KeyCode.H] = "THROW",
}

local PAD_FIGHT = {
	[Enum.KeyCode.DPadLeft] = "left",
	[Enum.KeyCode.DPadRight] = "right",
	[Enum.KeyCode.DPadUp] = "up",
	[Enum.KeyCode.DPadDown] = "down",
	[Enum.KeyCode.ButtonX] = "L",
	[Enum.KeyCode.ButtonY] = "H",
	[Enum.KeyCode.ButtonA] = "K",
	[Enum.KeyCode.ButtonB] = "S",
	[Enum.KeyCode.ButtonR1] = "B",
	[Enum.KeyCode.ButtonL1] = "E",
	[Enum.KeyCode.ButtonR2] = "X",
	[Enum.KeyCode.ButtonL2] = "THROW",
}

local KEY_NAV = {
	[Enum.KeyCode.Up] = "up",
	[Enum.KeyCode.W] = "up",
	[Enum.KeyCode.Down] = "down",
	[Enum.KeyCode.S] = "down",
	[Enum.KeyCode.Left] = "left",
	[Enum.KeyCode.A] = "left",
	[Enum.KeyCode.Right] = "right",
	[Enum.KeyCode.D] = "right",
	[Enum.KeyCode.Return] = "confirm",
	[Enum.KeyCode.KeypadEnter] = "confirm",
	[Enum.KeyCode.Space] = "confirm",
	[Enum.KeyCode.J] = "confirm",
	[Enum.KeyCode.Backspace] = "back",
	[Enum.KeyCode.K] = "back",
	[Enum.KeyCode.Q] = "tabL",
	[Enum.KeyCode.E] = "tabR",
	[Enum.KeyCode.Tab] = "start",
	[Enum.KeyCode.F] = "alt",
}

local PAD_NAV = {
	[Enum.KeyCode.DPadUp] = "up",
	[Enum.KeyCode.DPadDown] = "down",
	[Enum.KeyCode.DPadLeft] = "left",
	[Enum.KeyCode.DPadRight] = "right",
	[Enum.KeyCode.ButtonA] = "confirm",
	[Enum.KeyCode.ButtonB] = "back",
	[Enum.KeyCode.ButtonL1] = "tabL",
	[Enum.KeyCode.ButtonR1] = "tabR",
	[Enum.KeyCode.ButtonStart] = "start",
	[Enum.KeyCode.ButtonSelect] = "start",
	[Enum.KeyCode.ButtonY] = "alt",
}

local held = {}
local touchHeld = {}
local stick = Vector2.zero
local padStick = Vector2.zero
Input.fightEnabled = false

local function setMode(m: string)
	if Input.mode ~= m then
		Input.mode = m
		Input.modeChanged:Fire(m)
	end
end

-- menu key repeat
local repeatState = { action = nil, t = 0, next = 0 }
local function navFire(action: string)
	Input.nav:Fire(action)
	if action == "up" or action == "down" or action == "left" or action == "right" then
		repeatState.action = action
		repeatState.t = 0
		repeatState.next = 0.38
	end
end

UserInputService.InputBegan:Connect(function(io, processed)
	if io.UserInputType == Enum.UserInputType.Keyboard then
		if processed and io.KeyCode ~= Enum.KeyCode.Return then
			return
		end
		setMode("keyboard")
		local f = KEY_FIGHT[io.KeyCode]
		if f then
			held[f] = true
		end
		local n = KEY_NAV[io.KeyCode]
		if n then
			navFire(n)
		end
		Input.anyPressed:Fire()
	elseif io.UserInputType.Name:find("Gamepad") then
		setMode("gamepad")
		local f = PAD_FIGHT[io.KeyCode]
		if f then
			held[f] = true
		end
		local n = PAD_NAV[io.KeyCode]
		if n then
			navFire(n)
		end
		Input.anyPressed:Fire()
	elseif io.UserInputType == Enum.UserInputType.Touch then
		setMode("touch")
		if not processed then
			Input.anyPressed:Fire()
		end
	elseif io.UserInputType == Enum.UserInputType.MouseButton1 then
		if not processed then
			Input.anyPressed:Fire()
		end
	end
end)

UserInputService.InputEnded:Connect(function(io)
	if io.UserInputType == Enum.UserInputType.Keyboard then
		local f = KEY_FIGHT[io.KeyCode]
		if f then
			held[f] = false
		end
		local n = KEY_NAV[io.KeyCode]
		if n and repeatState.action == n then
			repeatState.action = nil
		end
	elseif io.UserInputType.Name:find("Gamepad") then
		local f = PAD_FIGHT[io.KeyCode]
		if f then
			held[f] = false
		end
		local n = PAD_NAV[io.KeyCode]
		if n and repeatState.action == n then
			repeatState.action = nil
		end
	end
end)

-- analog stick
local lastStickDir = nil
UserInputService.InputChanged:Connect(function(io)
	if io.KeyCode == Enum.KeyCode.Thumbstick1 then
		local p = io.Position
		padStick = Vector2.new(p.X, p.Y)
		if padStick.Magnitude > 0.5 then
			setMode("gamepad")
		end
		local dir = nil
		if math.abs(padStick.X) > math.abs(padStick.Y) then
			if padStick.X > 0.6 then
				dir = "right"
			elseif padStick.X < -0.6 then
				dir = "left"
			end
		else
			if padStick.Y > 0.6 then
				dir = "up"
			elseif padStick.Y < -0.6 then
				dir = "down"
			end
		end
		if dir ~= lastStickDir then
			if dir then
				navFire(dir)
			elseif repeatState.action == lastStickDir then
				repeatState.action = nil
			end
			lastStickDir = dir
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if repeatState.action then
		repeatState.t += dt
		if repeatState.t >= repeatState.next then
			repeatState.next = repeatState.t + 0.09
			Input.nav:Fire(repeatState.action)
		end
	end
end)

-- Touch API (used by MobileControls)
function Input.setTouch(button: string, down: boolean)
	touchHeld[button] = down
	if down then
		setMode("touch")
	end
end

function Input.setStick(v: Vector2)
	stick = v
end

function Input.clearTouch()
	table.clear(touchHeld)
	stick = Vector2.zero
end

-- Current fight input (held state)
function Input.fightState()
	local s = {
		left = false,
		right = false,
		up = false,
		down = false,
		L = false,
		H = false,
		K = false,
		S = false,
		B = false,
		E = false,
		X = false,
	}
	for k in s do
		if held[k] or touchHeld[k] then
			s[k] = true
		end
	end
	-- analog sticks
	local function applyStick(v: Vector2, invertY: boolean)
		local y = invertY and -v.Y or v.Y
		if v.X < -0.45 then
			s.left = true
		elseif v.X > 0.45 then
			s.right = true
		end
		if y < -0.55 then
			s.up = true
		elseif y > 0.55 then
			s.down = true
		end
	end
	if padStick.Magnitude > 0.3 then
		applyStick(padStick, true)
	end
	if stick.Magnitude > 0.3 then
		applyStick(stick, false)
	end
	-- throw macro = block + light
	if held.THROW or touchHeld.THROW then
		s.B = true
		s.L = true
	end
	return s
end

-- Button glyphs for prompts
local GLYPHS = {
	keyboard = { L = "J", H = "K", K = "L", S = "I", B = "U", E = "O", X = "P", THROW = "H", down = "S", up = "W", left = "A", right = "D", confirm = "ENTER", back = "BKSP", start = "TAB", tabL = "Q", tabR = "E", alt = "F" },
	gamepad = { L = "X", H = "Y", K = "A", S = "B", B = "RB", E = "LB", X = "RT", THROW = "LT", down = "\u{2193}", up = "\u{2191}", left = "\u{2190}", right = "\u{2192}", confirm = "A", back = "B", start = "START", tabL = "LB", tabR = "RB", alt = "Y" },
	touch = { L = "LIGHT", H = "HEAVY", K = "KICK", S = "SPECIAL", B = "BLOCK", E = "ECHO", X = "SUPER", THROW = "THROW", down = "\u{2193}", up = "\u{2191}", left = "\u{2190}", right = "\u{2192}", confirm = "TAP", back = "BACK", start = "II", tabL = "\u{25C0}", tabR = "\u{25B6}", alt = "" },
}
function Input.glyph(action: string): string
	local set = GLYPHS[Input.mode] or GLYPHS.keyboard
	return set[action] or action
end

return Input
