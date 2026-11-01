--!nonstrict
-- Online menus: the hub, matchmaking, challenges, inventory & loadout, the Enchant
-- Altar, the Forge, the trade window and online results. Everything that changes
-- an inventory goes through the server (Net.request / Net.trade); these screens only
-- display the server's answers.

local Players = game:GetService("Players")

local Veil = game:GetService("ReplicatedStorage"):WaitForChild("Veil")
local Items = require(Veil.Data.Items)
local Fighters = require(Veil.Data.Fighters)
local Stages = require(Veil.Data.Stages)

local Client = script.Parent.Parent
local Theme = require(script.Parent.Theme)
local Screens = require(script.Parent.Screens)
local Toast = require(script.Parent.Toast)
local Audio = require(Client.Core.Audio)
local Input = require(Client.Core.Input)
local Net = require(Client.Net.Net)

local C = Theme.Colors
local F = Theme.Fonts
local new = Theme.new
local H = Screens._h

local OnlineScreens = {}

local function rarityColor(r: string): Color3
	return Color3.fromHex((Items.RARITY[r] or Items.RARITY.common).color)
end

local function weaponDef(rec)
	return Items.WeaponById[rec.item]
end

-- Fighters whose weapon a skin fits.
local function fightersFor(weaponType: string)
	local out = {}
	for _, f in Fighters.list do
		if f.look.weapon == weaponType then
			table.insert(out, f)
		end
	end
	return out
end

local function equippedOn(uid: string): string?
	for fid, e in Net.inv.equipped or {} do
		if e == uid then
			local f = Fighters.byId[fid]
			return f and f.name or fid
		end
	end
	return nil
end

local function resourceLine(): string
	local parts = {}
	for _, r in Items.Resources do
		table.insert(parts, string.upper(r.name) .. " " .. tostring((Net.inv.res or {})[r.id] or 0))
	end
	return table.concat(parts, "   \u{00B7}   ")
end

local function strip(parent: Instance, y: number)
	local l = Theme.label(parent, resourceLine(), {
		Size = UDim2.new(1, -80, 0, 26),
		Position = UDim2.new(0, 40, 0, y),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.labelBold,
		TextSize = 15,
		TextColor3 = C.gold,
		ZIndex = 16,
	})
	local conn = Net.onInventory.Event:Connect(function()
		l.Text = resourceLine()
	end)
	l.Destroying:Connect(function()
		conn:Disconnect()
	end)
	return l
end

local function costText(cost): string
	local parts = {}
	for id, n in cost do
		local r = Items.ResourceById[id]
		table.insert(parts, n .. " " .. (r and r.name or id))
	end
	table.sort(parts)
	return table.concat(parts, " + ")
end

-------------------------------------------------------------------------------
-- Generic vertical choice list with descriptions
-------------------------------------------------------------------------------

-- entries: { { id, text, desc?, color? } }. Returns id or nil.
local function choose(root: Instance, name: string, heading: string, sub: string?, entries, opts)
	opts = opts or {}
	local f = H.screenFrame(root, name)
	H.backdrop(f, 0.82)
	H.title(f, heading, sub)
	if opts.strip ~= false then
		strip(f, 150)
	end
	local list = Theme.frame(f, { Size = UDim2.fromOffset(900, 560), Position = UDim2.new(0.5, -380, 0, 196), ZIndex = 15 })
	local items = {}
	local spacing = opts.spacing or 58
	for i, e in entries do
		local it = H.menuItem(list, e.text, (i - 1) * spacing, opts.size or 34)
		it.button.Size = UDim2.fromOffset(900, (opts.size or 34) + 14)
		if e.tag then
			Theme.label(it.button, e.tag, {
				Size = UDim2.fromOffset(240, 30),
				Position = UDim2.new(1, -250, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				TextXAlignment = Enum.TextXAlignment.Right,
				FontFace = F.labelBold,
				TextSize = 15,
				TextColor3 = e.tagColor or C.gold,
				ZIndex = 17,
			})
		end
		items[i] = it
	end
	local desc = Theme.label(f, "", {
		Size = UDim2.fromOffset(900, 54),
		Position = UDim2.new(0.5, -380, 1, -104),
		FontFace = F.serif,
		TextSize = 20,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = C.text,
		ZIndex = 16,
	})
	H.hintBar(f, opts.hints or { { "confirm", "SELECT" }, { "back", "BACK" } })
	H.fadeIn(f)
	if #entries == 0 then
		desc.Text = opts.emptyText or "Nothing here yet."
		local w = H.waiter()
		local conn = Input.nav.Event:Connect(function(a)
			if a == "back" or a == "confirm" then
				w.resolve(nil)
			end
		end)
		w.wait()
		conn:Disconnect()
		f:Destroy()
		return nil
	end
	local r = H.runList(items, {
		start = opts.start,
		onSelect = function(i)
			desc.Text = entries[i].desc or ""
		end,
		onAction = opts.onAction,
	})
	f:Destroy()
	return r and entries[r].id or nil, r
end
OnlineScreens.choose = choose

-------------------------------------------------------------------------------
-- Hub
-------------------------------------------------------------------------------

function OnlineScreens.hub(root: Instance, info)
	local pending = info and info.pending or 0
	local entries = {
		{ id = "quick", text = "QUICK MATCH", desc = "Get paired with the next player in this server who's looking for a fight. Server-run, no CPU." },
		{ id = "challenge", text = "CHALLENGE A PLAYER", desc = "Pick someone in this server and send them a 1v1 invite." },
		{ id = "requests", text = "REQUESTS", tag = pending > 0 and (pending .. " WAITING") or nil, tagColor = C.crimsonBright, desc = "Challenges and trade offers other players sent you." },
		{ id = "trade", text = "TRADE", desc = "Swap weapons, enchantments and resources with another player. Both sides must press READY." },
		{ id = "inventory", text = "INVENTORY & LOADOUT", desc = "Your weapon skins and resources. Equip a skin on the fighter who uses that weapon." },
		{ id = "altar", text = "ENCHANT ALTAR", desc = "Offer " .. costText(Items.EnchantCost) .. " to roll an enchantment on a weapon. Cosmetic only: no stat changes." },
		{ id = "forge", text = "FORGE", desc = "Spend " .. costText(Items.ForgeCost) .. " to forge a random skin for a weapon type." },
	}
	return choose(root, "OnlineHub", "ONLINE", "PLAYERS IN THIS SERVER: " .. #Players:GetPlayers(), entries, { start = info and info.start })
end

-------------------------------------------------------------------------------
-- Waiting (matchmaking, challenges, trade requests)
-------------------------------------------------------------------------------

-- Waits for one of `ops` on the online channel or `tradeOps` on the trade channel.
-- Returns (op, msg) or ("cancel").
function OnlineScreens.wait(root: Instance, heading: string, sub: string?, opts)
	opts = opts or {}
	local f = H.screenFrame(root, "OnlineWait")
	H.backdrop(f, 0.85)
	H.title(f, heading, sub)
	local dots = Theme.label(f, "", {
		Size = UDim2.fromOffset(600, 60),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.display,
		TextSize = 54,
		TextColor3 = C.goldBright,
		ZIndex = 16,
	})
	H.hintBar(f, { { "back", "CANCEL" } })
	H.fadeIn(f)
	local w = H.waiter()
	local conns = H.connections()
	conns.add(Net.onOnline.Event:Connect(function(msg)
		if opts.ops and opts.ops[msg.op] then
			w.resolve({ msg.op, msg })
		end
	end))
	conns.add(Net.onTrade.Event:Connect(function(msg)
		if opts.tradeOps and opts.tradeOps[msg.op] then
			w.resolve({ msg.op, msg })
		end
	end))
	conns.add(Input.nav.Event:Connect(function(a)
		if a == "back" then
			w.resolve({ "cancel" })
		end
	end))
	task.spawn(function()
		local t = 0
		while not w.done() do
			t += 1
			dots.Text = string.rep("\u{25C6} ", (t % 4) + 1)
			task.wait(0.35)
			if opts.timeout and t * 0.35 > opts.timeout then
				w.resolve({ "timeout" })
			end
		end
	end)
	local r = w.wait()
	conns.clear()
	f:Destroy()
	if r[1] == "cancel" and opts.onCancel then
		opts.onCancel()
	end
	return r[1], r[2]
end

function OnlineScreens.pickPlayer(root: Instance, heading: string)
	local entries = {}
	for _, p in Net.others() do
		table.insert(entries, { id = p.UserId, text = string.upper(p.DisplayName), desc = "@" .. p.Name })
	end
	local id = choose(root, "PickPlayer", heading, nil, entries, {
		emptyText = "Nobody else is in this server yet. Invite a friend, or use Quick Match. (Studio: Test > Clients and Servers > 2 players.)",
	})
	return id and Players:GetPlayerByUserId(id) or nil
end

-- list: { { kind = "challenge"|"trade", from, name, stageName? } }
function OnlineScreens.requests(root: Instance, list)
	local entries = {}
	for i, r in list do
		if r.kind == "challenge" then
			table.insert(entries, { id = i, text = "1V1 FROM " .. string.upper(r.name), tag = r.stageName and string.upper(r.stageName) or nil, desc = "Accept, pick your fighter and map, and the fight starts." })
		else
			table.insert(entries, { id = i, text = "TRADE FROM " .. string.upper(r.name), desc = "Accept to open the trade window." })
		end
	end
	local id = choose(root, "Requests", "REQUESTS", nil, entries, { emptyText = "No requests right now." })
	return id and list[id] or nil
end

-------------------------------------------------------------------------------
-- Inventory & loadout
-------------------------------------------------------------------------------

local function weaponEntries(filterType: string?)
	local entries = {}
	local list = table.clone(Net.inv.weapons or {})
	table.sort(list, function(a, b)
		local da, db = weaponDef(a), weaponDef(b)
		local ra, rb = Items.RARITY[da.rarity].order, Items.RARITY[db.rarity].order
		if ra ~= rb then
			return ra > rb
		end
		return da.name < db.name
	end)
	for _, rec in list do
		local def = weaponDef(rec)
		if def and (not filterType or def.type == filterType) then
			local e = rec.ench and Items.EnchantById[rec.ench]
			local on = equippedOn(rec.uid)
			local fitNames = {}
			for _, fd in fightersFor(def.type) do
				table.insert(fitNames, fd.name)
			end
			table.insert(entries, {
				id = rec.uid,
				rec = rec,
				text = string.upper(Items.weaponLabel(rec)),
				tag = Items.RARITY[def.rarity].name .. (e and ("  \u{00B7}  " .. Items.RARITY[e.rarity].name .. " ENCHANT") or ""),
				tagColor = rarityColor(def.rarity),
				desc = (Items.WeaponTypeById[def.type] and Items.WeaponTypeById[def.type].name or def.type)
					.. " skin for " .. table.concat(fitNames, ", ")
					.. (e and (".  " .. e.name .. ": " .. e.desc) or ".  No enchantment.")
					.. (on and ("  EQUIPPED ON " .. string.upper(on) .. ".") or ""),
			})
		end
	end
	return entries
end

function OnlineScreens.pickWeapon(root: Instance, heading: string, sub: string?)
	local entries = weaponEntries(nil)
	if #entries > 9 then
		-- long lists: show the best first; the hub's inventory pages through all
		for i = #entries, 10, -1 do
			table.remove(entries, i)
		end
	end
	return choose(root, "PickWeapon", heading, sub, entries, { emptyText = "No weapons yet. Win online fights or forge one." })
end

function OnlineScreens.inventory(root: Instance)
	Net.request("get")
	local page = 1
	local PER = 9
	while true do
		local all = weaponEntries(nil)
		local pages = math.max(1, math.ceil(#all / PER))
		page = math.clamp(page, 1, pages)
		local entries = {}
		for i = (page - 1) * PER + 1, math.min(#all, page * PER) do
			table.insert(entries, all[i])
		end
		local turned = nil
		local uid = choose(root, "Inventory", "INVENTORY & LOADOUT", string.format("%d WEAPONS  \u{00B7}  PAGE %d / %d", #all, page, pages), entries, {
			emptyText = "No weapons yet. Win online fights or visit the Forge.",
			hints = { { "left", "" }, { "right", "PAGE" }, { "confirm", "OPTIONS" }, { "back", "BACK" } },
			onAction = function(a)
				if a == "left" and page > 1 then
					turned = -1
					Input.nav:Fire("back")
				elseif a == "right" and page < pages then
					turned = 1
					Input.nav:Fire("back")
				end
			end,
		})
		if turned then
			page += turned
			continue
		end
		if not uid then
			return
		end
		local rec = nil
		for _, w in Net.inv.weapons do
			if w.uid == uid then
				rec = w
			end
		end
		if rec then
			local def = weaponDef(rec)
			local actions = {}
			for _, fd in fightersFor(def.type) do
				table.insert(actions, { id = "equip:" .. fd.id, text = "EQUIP ON " .. fd.name, desc = "Shows in every fight you play as " .. fd.name .. ", online and offline." })
			end
			if equippedOn(uid) then
				table.insert(actions, { id = "unequip", text = "UNEQUIP", desc = "Back to the default look." })
			end
			table.insert(actions, { id = "enchant", text = "ENCHANT", desc = "Roll a new enchantment at the altar (" .. costText(Items.EnchantCost) .. ")." })
			local act = choose(root, "WeaponActions", string.upper(Items.weaponLabel(rec)), Items.RARITY[def.rarity].name, actions)
			if act and string.sub(act, 1, 6) == "equip:" then
				local res = Net.request("equip", { fighter = string.sub(act, 7), uid = uid })
				Toast.show(res.ok and "EQUIPPED" or "COULDN'T EQUIP", res.err, res.ok and C.goldBright or C.crimsonBright)
			elseif act == "unequip" then
				for fid, e in Net.inv.equipped do
					if e == uid then
						Net.request("equip", { fighter = fid })
					end
				end
			elseif act == "enchant" then
				OnlineScreens.altar(root, uid)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Enchant Altar
-------------------------------------------------------------------------------

local function reveal(root: Instance, heading: string, name: string, sub: string, color: Color3, spinNames)
	local f = H.screenFrame(root, "Reveal")
	H.backdrop(f, 0.9)
	H.title(f, heading)
	local big = Theme.label(f, "", {
		Size = UDim2.fromOffset(1100, 110),
		Position = UDim2.new(0.5, 0, 0.45, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = F.display,
		TextSize = 84,
		TextColor3 = C.ivory,
		ZIndex = 16,
	})
	Theme.textStroke(big, 3, 0.2)
	local small = Theme.label(f, "", {
		Size = UDim2.fromOffset(1100, 80),
		Position = UDim2.new(0.5, 0, 0.45, 80),
		AnchorPoint = Vector2.new(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		FontFace = F.serif,
		TextSize = 24,
		TextColor3 = C.text,
		ZIndex = 16,
	})
	H.hintBar(f, { { "confirm", "CONTINUE" } })
	-- spin through the possibilities, slowing down, then land on the result
	if spinNames and #spinNames > 0 then
		local delay = 0.04
		local i = 1
		while delay < 0.28 do
			local e = spinNames[i]
			big.Text = e.name
			big.TextColor3 = e.color
			Audio.ui("ui_move")
			task.wait(delay)
			delay *= 1.12
			i = i % #spinNames + 1
		end
	end
	big.Text = name
	big.TextColor3 = color
	small.Text = sub
	Audio.ui("ui_lock")
	local sc = Instance.new("UIScale")
	sc.Scale = 1.4
	sc.Parent = big
	Theme.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	local w = H.waiter()
	local conn = Input.nav.Event:Connect(function(a)
		if a == "confirm" or a == "back" then
			w.resolve(true)
		end
	end)
	w.wait()
	conn:Disconnect()
	f:Destroy()
end

function OnlineScreens.altar(root: Instance, uid: string?)
	while true do
		local target = uid or OnlineScreens.pickWeapon(root, "ENCHANT ALTAR", "COST: " .. string.upper(costText(Items.EnchantCost)) .. "  \u{00B7}  COSMETIC ONLY")
		if not target then
			return
		end
		local res = Net.request("enchant", target)
		if not res.ok then
			Toast.show("THE ALTAR REFUSES", res.err, C.crimsonBright)
			return
		end
		local e = Items.EnchantById[res.ench]
		local spin = {}
		for _, x in Items.Enchantments do
			table.insert(spin, { name = string.upper(x.name), color = rarityColor(x.rarity) })
		end
		reveal(root, "ENCHANT ALTAR", string.upper(e.name), Items.RARITY[e.rarity].name .. "  \u{00B7}  " .. e.desc .. "  (Cosmetic: no stat changes.)", rarityColor(e.rarity), spin)
		if uid then
			return
		end
	end
end

-------------------------------------------------------------------------------
-- Forge
-------------------------------------------------------------------------------

function OnlineScreens.forge(root: Instance)
	while true do
		local entries = {}
		for _, t in Items.WeaponTypes do
			local names = {}
			for _, fd in fightersFor(t.id) do
				table.insert(names, fd.name)
			end
			table.insert(entries, { id = t.id, text = string.upper(t.name), tag = #Items.weaponsOfType(t.id) .. " SKINS", desc = "Used by " .. table.concat(names, ", ") .. ".  Cost: " .. costText(Items.ForgeCost) .. "." })
		end
		local wtype = choose(root, "Forge", "FORGE", "PICK A WEAPON TYPE", entries)
		if not wtype then
			return
		end
		local res = Net.request("forge", wtype)
		if not res.ok then
			Toast.show("THE FORGE IS COLD", res.err, C.crimsonBright)
		else
			local def = Items.WeaponById[res.weapon.item]
			local spin = {}
			for _, w in Items.weaponsOfType(wtype) do
				table.insert(spin, { name = string.upper(w.name), color = rarityColor(w.rarity) })
			end
			reveal(root, "FORGE", string.upper(def.name), Items.RARITY[def.rarity].name .. " " .. string.upper(Items.WeaponTypeById[def.type].name) .. " SKIN", rarityColor(def.rarity), spin)
		end
	end
end

-------------------------------------------------------------------------------
-- Trade window
-------------------------------------------------------------------------------

local function offerLines(offer)
	local lines = {}
	for _, w in offer.weapons or {} do
		local def = Items.WeaponById[w.item]
		table.insert(lines, { text = Items.weaponLabel(w), color = def and rarityColor(def.rarity) or C.text })
	end
	for _, r in Items.Resources do
		local n = offer.res and offer.res[r.id]
		if n and n > 0 then
			table.insert(lines, { text = n .. "  \u{00D7}  " .. r.name, color = rarityColor(r.rarity) })
		end
	end
	return lines
end

-- Returns "done" | "closed".
function OnlineScreens.trade(root: Instance, info)
	local f = H.screenFrame(root, "Trade")
	f.ZIndex = 80
	H.backdrop(f, 0.9)
	H.title(f, "TRADING WITH " .. string.upper(info.name or "PLAYER"), "BOTH PLAYERS PRESS READY. ANY CHANGE RESETS READY.")
	local function panel(x: number, heading: string)
		local p = Theme.panel(f, { Size = UDim2.fromOffset(560, 290), Position = UDim2.new(0.5, x, 0, 160), ZIndex = 15 })
		Theme.label(p, heading, { Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 8), FontFace = F.labelBold, TextSize = 18, TextColor3 = C.goldBright, ZIndex = 16 })
		local rows = {}
		for i = 1, 10 do
			rows[i] = Theme.label(p, "", { Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 40 + (i - 1) * 24), FontFace = F.label, TextSize = 16, TextColor3 = C.text, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 16 })
		end
		local status = Theme.label(p, "", { Size = UDim2.new(1, -24, 0, 26), Position = UDim2.new(0, 12, 1, -34), FontFace = F.labelBold, TextSize = 16, TextColor3 = C.textDim, ZIndex = 16 })
		return { panel = p, rows = rows, status = status }
	end
	local mine = panel(-580, "YOUR OFFER")
	local theirs = panel(20, string.upper(info.name or "THEIR") .. "'S OFFER")
	local function fill(pn, offer)
		local lines = offerLines(offer)
		for i, row in pn.rows do
			local l = lines[i]
			row.Text = l and l.text or (i == 1 and "(nothing yet)" or "")
			row.TextColor3 = l and l.color or C.textDim
		end
	end
	-- your inventory: weapons (click to add/remove) + resource steppers
	local invPanel = Theme.panel(f, { Size = UDim2.fromOffset(1160, 300), Position = UDim2.new(0.5, -580, 0, 470), ZIndex = 15 })
	local scroll = new("ScrollingFrame", {
		Size = UDim2.new(0, 640, 1, -20),
		Position = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ZIndex = 16,
	}, invPanel)
	local offer = { weapons = {}, res = {} }
	local conns = H.connections()
	local sendPending = false
	local function pushOffer()
		if sendPending then
			return
		end
		sendPending = true
		task.delay(0.15, function()
			sendPending = false
			Net.trade({ op = "offer", offer = offer })
		end)
	end
	local weaponButtons = {}
	local function rebuildWeapons()
		for _, b in weaponButtons do
			b:Destroy()
		end
		table.clear(weaponButtons)
		local n = 0
		for _, rec in Net.inv.weapons or {} do
			local def = Items.WeaponById[rec.item]
			if def then
				n += 1
				local b = new("TextButton", {
					Size = UDim2.fromOffset(200, 50),
					Position = UDim2.fromOffset(((n - 1) % 3) * 208, ((n - 1) // 3) * 58),
					Text = Items.weaponLabel(rec),
					TextWrapped = true,
					FontFace = F.labelBold,
					TextSize = 13,
					TextColor3 = C.ivory,
					AutoButtonColor = false,
					BackgroundColor3 = Color3.fromHex("#14151A"),
					ZIndex = 17,
				}, scroll)
				Theme.corner(b, 6)
				local st = Theme.stroke(b, rarityColor(def.rarity), 1.5)
				local function refresh()
					local inOffer = table.find(offer.weapons, rec.uid) ~= nil
					b.BackgroundColor3 = inOffer and rarityColor(def.rarity):Lerp(Color3.new(0, 0, 0), 0.55) or Color3.fromHex("#14151A")
					st.Thickness = inOffer and 3 or 1.5
				end
				refresh()
				conns.add(b.Activated:Connect(function()
					local i = table.find(offer.weapons, rec.uid)
					if i then
						table.remove(offer.weapons, i)
					elseif #offer.weapons < Items.TradeMaxWeapons then
						table.insert(offer.weapons, rec.uid)
					else
						Toast.show("OFFER FULL", "Up to " .. Items.TradeMaxWeapons .. " weapons per trade.", C.crimsonBright)
					end
					Audio.ui("ui_move")
					refresh()
					pushOffer()
				end))
				table.insert(weaponButtons, b)
			end
		end
		scroll.CanvasSize = UDim2.fromOffset(0, math.ceil(n / 3) * 58)
	end
	rebuildWeapons()
	-- resource steppers
	local resLabels = {}
	for i, r in Items.Resources do
		local y = 12 + (i - 1) * 46
		local l = Theme.label(invPanel, "", { Size = UDim2.fromOffset(280, 36), Position = UDim2.fromOffset(664, y), FontFace = F.labelBold, TextSize = 15, TextColor3 = rarityColor(r.rarity), ZIndex = 16 })
		resLabels[r.id] = l
		for k, step in { -10, -1, 1, 10 } do
			local b = new("TextButton", {
				Text = (step > 0 and "+" or "") .. step,
				FontFace = F.labelBold,
				TextSize = 15,
				TextColor3 = C.ivory,
				AutoButtonColor = true,
				BackgroundColor3 = Color3.fromHex("#1A1B20"),
				Size = UDim2.fromOffset(48, 34),
				Position = UDim2.fromOffset(940 + (k - 1) * 54, y),
				ZIndex = 17,
			}, invPanel)
			Theme.corner(b, 6)
			conns.add(b.Activated:Connect(function()
				local have = (Net.inv.res or {})[r.id] or 0
				local n = math.clamp((offer.res[r.id] or 0) + step, 0, have)
				offer.res[r.id] = n > 0 and n or nil
				Audio.ui("ui_move")
				l.Text = string.upper(r.name) .. ":  " .. (offer.res[r.id] or 0) .. " / " .. have
				pushOffer()
			end))
		end
		l.Text = string.upper(r.name) .. ":  0 / " .. ((Net.inv.res or {})[r.id] or 0)
	end
	-- ready / cancel
	local readyBtn = new("TextButton", {
		Text = "READY",
		FontFace = F.display,
		TextSize = 34,
		TextColor3 = C.ivory,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromHex("#1F3A1F"),
		Size = UDim2.fromOffset(260, 60),
		Position = UDim2.new(0.5, -270, 1, -122),
		ZIndex = 17,
	}, f)
	Theme.corner(readyBtn, 8)
	local readyStroke = Theme.stroke(readyBtn, C.gold, 2)
	local cancelBtn = new("TextButton", {
		Text = "CANCEL",
		FontFace = F.display,
		TextSize = 34,
		TextColor3 = C.ivory,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromHex("#3A1414"),
		Size = UDim2.fromOffset(260, 60),
		Position = UDim2.new(0.5, 10, 1, -122),
		ZIndex = 17,
	}, f)
	Theme.corner(cancelBtn, 8)
	H.hintBar(f, { { "confirm", "READY" }, { "back", "CANCEL" } })
	local readyMe = false
	local function toggleReady()
		readyMe = not readyMe
		Net.trade({ op = "ready", on = readyMe })
		Audio.ui(readyMe and "ui_lock" or "ui_back")
	end
	local w = H.waiter()
	conns.add(readyBtn.Activated:Connect(toggleReady))
	conns.add(cancelBtn.Activated:Connect(function()
		Net.trade({ op = "cancel" })
	end))
	conns.add(Input.nav.Event:Connect(function(a)
		if a == "confirm" then
			toggleReady()
		elseif a == "back" then
			Net.trade({ op = "cancel" })
		end
	end))
	conns.add(Net.onTrade.Event:Connect(function(msg)
		if msg.op == "state" then
			fill(mine, msg.mine)
			fill(theirs, msg.theirs)
			readyMe = msg.readyMe == true
			readyBtn.Text = readyMe and "UNREADY" or "READY"
			readyStroke.Color = readyMe and Color3.fromHex("#5BD15B") or C.gold
			mine.status.Text = msg.readyMe and "READY" or "NOT READY"
			mine.status.TextColor3 = msg.readyMe and Color3.fromHex("#5BD15B") or C.textDim
			theirs.status.Text = msg.readyThem and "READY" or "NOT READY"
			theirs.status.TextColor3 = msg.readyThem and Color3.fromHex("#5BD15B") or C.textDim
			if msg.countdown then
				mine.status.Text = "TRADING IN " .. math.ceil(msg.countdown) .. "..."
			end
		elseif msg.op == "done" then
			Toast.show("TRADE COMPLETE", "Items are in your inventory.", Color3.fromHex("#5BD15B"))
			w.resolve("done")
		elseif msg.op == "closed" then
			Toast.show("TRADE CLOSED", msg.reason, C.crimsonBright)
			w.resolve("closed")
		elseif msg.op == "error" then
			Toast.show("TRADE", msg.err, C.crimsonBright)
		end
	end))
	conns.add(Net.onInventory.Event:Connect(function()
		rebuildWeapons()
	end))
	fill(mine, offer)
	fill(theirs, { weapons = {}, res = {} })
	local r = w.wait()
	conns.clear()
	f:Destroy()
	return r
end

-------------------------------------------------------------------------------
-- Online results
-------------------------------------------------------------------------------

function OnlineScreens.results(root: Instance, result)
	local won = result.winner == result.side
	local f = H.screenFrame(root, "OnlineResults")
	H.backdrop(f, 0.85, won and nil or Color3.fromHex("#A08080"))
	local why = result.reason == "disconnect" and "YOUR RIVAL DISCONNECTED" or (result.reason == "forfeit" and "FORFEIT" or nil)
	H.title(f, won and "YOU WIN" or "YOU LOSE", why)
	local lines = {}
	if result.rounds then
		table.insert(lines, string.format("ROUNDS  %d \u{2013} %d", result.rounds[result.side] or 0, result.rounds[3 - result.side] or 0))
	end
	if result.rewarded == false then
		table.insert(lines, "No rewards this match (rematch limit or an early forfeit).")
	elseif result.rewards then
		for _, r in Items.Resources do
			local n = result.rewards[r.id]
			if n and n > 0 then
				table.insert(lines, "+" .. n .. "  " .. r.name)
			end
		end
	end
	if result.weapon then
		local def = Items.WeaponById[result.weapon.item]
		if def then
			table.insert(lines, "NEW WEAPON:  " .. def.name .. "  (" .. Items.RARITY[def.rarity].name .. ")")
		end
	end
	for i, text in lines do
		Theme.label(f, text, {
			Size = UDim2.fromOffset(900, 36),
			Position = UDim2.new(0.5, 0, 0, 220 + (i - 1) * 42),
			AnchorPoint = Vector2.new(0.5, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = i == 1 and F.display or F.labelBold,
			TextSize = i == 1 and 34 or 22,
			TextColor3 = (string.sub(text, 1, 3) == "NEW") and Color3.fromHex("#FFB02E") or C.ivory,
			ZIndex = 16,
		})
	end
	H.hintBar(f, { { "confirm", "CONTINUE" } })
	H.fadeIn(f)
	local w = H.waiter()
	local conn = Input.nav.Event:Connect(function(a)
		if a == "confirm" or a == "back" then
			w.resolve(true)
		end
	end)
	w.wait()
	conn:Disconnect()
	f:Destroy()
end

local _ = Stages
return OnlineScreens
