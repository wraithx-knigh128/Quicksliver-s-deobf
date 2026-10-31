--!nonstrict
-- Helpers for authoring move data compactly. Every move ends up as a plain table
-- the combat engine reads directly (no Roblox types, so it runs headless in tests).

export type Box = { x: number, y: number, w: number, h: number }

export type Projectile = {
	kind: string, -- visual id used by the renderer
	spawnFrame: number?, -- frame of the move that spawns it (defaults to startup)
	offset: { x: number, y: number }?,
	vx: number,
	vy: number?,
	gravity: number?,
	life: number,
	box: { w: number, h: number },
	damage: number,
	guard: string?,
	onHit: number?,
	onBlock: number?,
	launch: { vx: number, vy: number }?,
	knockdown: boolean?,
	hits: number?,
	hitEvery: number?,
	returns: boolean?, -- boomerang: reverses after half its life
	ground: boolean?, -- travels along the floor
	stationary: boolean?,
	pull: number?, -- pulls the victim toward the owner on hit
	absorbs: boolean?, -- destroys enemy projectiles it touches
	strength: string?,
	element: string?,
	spawnAt: string?, -- "self" | "opponent" | "ahead"
	ahead: number?,
	delay: number?,
}

export type Move = {
	id: string,
	name: string,
	input: string,
	kind: string,
	anim: string,
	startup: number,
	active: number,
	recovery: number,
	damage: number,
	guard: string,
	onHit: number,
	onBlock: number,
	push: number,
	blockPush: number,
	box: Box?,
	strength: string,
	launch: { vx: number, vy: number }?,
	knockdown: boolean?,
	hits: number?,
	hitEvery: number?,
	chain: { [string]: string }?,
	chainFrom: number?, -- earliest frame (from move start) a chain input is accepted
	specialCancel: boolean?,
	meter: number?,
	motion: { { from: number, to: number, vx: number, vy: number? } }?,
	invuln: { number }?,
	armor: { number }?,
	projectile: Projectile?,
	teleport: { frame: number, mode: string, dist: number? }?,
	grab: boolean?,
	parry: { from: number, to: number, counter: string }?,
	air: boolean?,
	landRecovery: number?,
	cost: number?,
	sfx: string?,
	hitSfx: string?,
	vfx: string?,
	element: string?,
	trail: boolean?,
	jumpArc: { vx: number, vy: number, frame: number }?,
	hitsBehind: boolean?,
	lowProfile: boolean?,
	crouching: boolean?,
	cinematic: string?,
	frameData: string?,
	desc: string?,
}

local MoveKit = {}

local STRENGTH_BY_KIND = {
	normal = "medium",
	special = "special",
	super = "super",
	throw = "heavy",
	air = "medium",
}

-- Fill defaults so the engine never has to nil-check common fields.
function MoveKit.move(t: { [string]: any }): Move
	local m: { [string]: any } = table.clone(t)
	m.kind = m.kind or "normal"
	m.name = m.name or m.id
	m.input = m.input or ""
	m.anim = m.anim or "jab"
	m.startup = m.startup or 8
	m.active = m.active or 3
	m.recovery = m.recovery or 12
	m.damage = m.damage or 40
	m.guard = m.guard or "mid"
	m.onHit = m.onHit or 2
	m.onBlock = m.onBlock or -2
	m.push = m.push or 0.22
	m.blockPush = m.blockPush or (m.push * 1.15)
	if not m.strength then
		if m.kind == "normal" or m.kind == "air" then
			if m.damage < 36 then
				m.strength = "light"
			elseif m.damage < 58 then
				m.strength = "medium"
			else
				m.strength = "heavy"
			end
		else
			m.strength = STRENGTH_BY_KIND[m.kind] or "medium"
		end
	end
	if m.kind == "air" then
		m.air = true
		m.landRecovery = m.landRecovery or 3
	end
	return (m :: any) :: Move
end

-- Readable frame-data summary for the move list screen.
function MoveKit.describe(m: Move): string
	local function signed(n: number): string
		if n > 0 then
			return "+" .. tostring(n)
		end
		return tostring(n)
	end
	local guard = string.upper(m.guard)
	if m.grab then
		guard = "GRAB"
	end
	local hitAdv = signed(m.onHit)
	if m.launch then
		hitAdv = "LAUNCH"
	elseif m.knockdown then
		hitAdv = "KD"
	end
	return string.format(
		"%s  |  DMG %d  |  START %d  |  ON HIT %s  |  ON BLOCK %s",
		guard,
		m.damage,
		m.startup,
		hitAdv,
		signed(m.onBlock)
	)
end

return MoveKit
