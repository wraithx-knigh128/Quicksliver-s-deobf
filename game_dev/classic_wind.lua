--[[ Wraith Hub v1.5 (the classic hub) on the WindUI window library: the old hub's menu calls - win tabs with Label / Toggle / Slider / Dropdown / Button / Input / Banner /
  Section (cards with an On screen / Assist switch and an options drawer) - answered by the WindUI adapter (mm2/windui_ui.lua), so the hub's own code does not change when
  its menu does. The old menu stays in tsb_animation_hub.lua as the fallback for an executor that cannot run WindUI.
  Controls are built from a queue a few at a time (the tab on screen first), so opening the hub does not freeze a phone. What the hub holds - a toggle's :Get / :Set, a label's
  "Text", a button row's "Visible" - works at once and is applied to the real control when it exists.
  Bundled into the executor script by game_dev/build_executor.py. ]]
local M = {}

-- Lucide icon of each tab (the characters' tabs all get "user")
local TAB_ICONS = {Main = "layout-dashboard", Credit = "heart", Timing = "timer", Techs = "list", ["Tech Lab"] = "wrench", ["Auto Tech"] = "shield",
    Teleports = "map-pin", Look = "palette", ["Effects Preset"] = "palette", Config = "settings", Predictor = "target"}

-- the card that opens each tab, the way the other Wraith Hub v1.5 does (a character's tab gets the generic one)
local TAB_BLURBS = {
    Main = "Start techs with your M1, utilities (WalkSpeed, Anti AFK), the universal combos and the side dash cards.",
    Credit = "Who made what, and how to open and close this menu.",
    Timing = "How long the hub waits between the steps of a combo, and how your ping changes that.",
    Techs = "Every tech found in research, with how well sourced it is.",
    ["Tech Lab"] = "Small, cancellable tech sequences: each has its own switch, options and status line.",
    ["Auto Tech"] = "Recover when you are knocked down, and Auto block.",
    Teleports = "Go next to a player, or to the spawn.",
    Look = "The look of this menu: theme, font, size, the white water, your own picture or video.",
    Config = "The only way anything is remembered: save, reload or delete your config.",
    Predictor = "Guesses which combo you are doing from your inputs.",
}
local CHARACTER_BLURB = "Combo cards for %s: Run plays the whole combo, On screen puts a button on your screen, Assist plays what follows the move you cast, Show options tunes one combo."

local function hexOf(c)
    local function byte(v) return math.max(0, math.min(255, math.floor(v * 255 + 0.5))) end
    return string.format("#%02x%02x%02x", byte(c.R), byte(c.G), byte(c.B))
end

-- d = {Adapter, WindUI, UILib, cfg = the adapter's window options, onError = fn(where, err), budget = seconds of building per frame, perFrame = most controls per frame,
--      cards = false leaves out the card that opens each tab}
-- Raises when the window cannot be made: the hub then keeps its own menu.
function M.new(d)
    local win = d.Adapter.new(d.WindUI, d.UILib, d.cfg)
    local B = {win = win, alive = true, elements = {}}                       -- B.elements["Tech Lab/Supa Tech/On"] = the real control (the tests click them)
    local onError = d.onError or function() end
    local budget, perFrame = d.budget or 0.012, d.perFrame or math.huge
    local cards = d.cards ~= false
    local tabs, order = {}, {}                                              -- our records, by the tab's index in the window / in creation order
    local side                                                              -- the sidebar group new tabs go into

    ---------------------------------------------------------------------------------------------- the build queue
    -- queues with explicit ends (a table whose first entries were taken out has no reliable #)
    local function newQueue() return {first = 1, last = 0} end
    local function push(q, fn) q.last = q.last + 1; q[q.last] = fn end
    local function pop(q)
        if q.first > q.last then return nil end
        local fn = q[q.first]
        q[q.first] = nil
        q.first = q.first + 1
        return fn
    end
    local function size(q) return q.last - q.first + 1 end
    local urgentQ = newQueue()                                              -- what a click just asked for (an options drawer): before everything else
    local urgentMode = false
    local function job(rec, fn, urgent)
        push((urgent or urgentMode) and urgentQ or rec.queue, fn)
    end
    function B.pending()
        local n = size(urgentQ)
        for _, rec in ipairs(order) do n = n + size(rec.queue) end
        return n
    end
    local function nextJob()
        local fn = pop(urgentQ)
        if fn then return fn end
        local showing = tabs[win.Window.CurrentTab]                           -- (WindUI keeps the shown tab's index)
        if showing then
            fn = pop(showing.queue)
            if fn then return fn end
        end
        for _, rec in ipairs(order) do
            fn = pop(rec.queue)
            if fn then return fn end
        end
        return nil
    end
    task.spawn(function()
        while B.alive do
            local t0, did, count = os.clock(), false, 0
            while B.alive and count < perFrame and (os.clock() - t0 < budget or count == 0) do
                local fn = nextJob()
                if not fn then break end
                did, count = true, count + 1
                local ok, err = pcall(fn)
                if not ok then onError("menu build", err) end
            end
            task.wait(did and 0 or 0.1)
        end
    end)

    ---------------------------------------------------------------------------------------------- hosts: a tab or a group, as the hub's code addresses them
    -- host:enqueue(fn) runs fn(realHost) once the real WindUI host exists (a group's jobs from before a :clear() are dropped)
    local function tabHost(rec)
        local host = {rec = rec, path = rec.name}
        function host:enqueue(fn, urgent) job(rec, function() fn(rec.real) end, urgent) end
        return host
    end
    local function newGroup(parent, o)
        local G = {rec = parent.rec, gen = 0, path = parent.path .. "/" .. tostring(o.Title)}
        function G:enqueue(fn, urgent)
            local g = G.gen
            job(G.rec, function() if G.real and g == G.gen then fn(G.real) end end, urgent)
        end
        function G:clear()
            G.gen = G.gen + 1
            job(G.rec, function() if G.real then G.real:Clear() end end)
        end
        parent:enqueue(function(h) G.real = h:Group(o); B.elements[G.path] = G.real end)
        return G
    end
    local function hostFor(T, parent)                                       -- `parent` is what the hub passes as its last argument (nil = the tab itself)
        if type(parent) == "table" and parent.enqueue then return parent end
        return T.__host
    end

    ---------------------------------------------------------------------------------------------- controls
    local function snapTo(min, max, step)
        return function(v)
            v = math.floor((v - min) / step + 0.5) * step + min
            return math.clamp(tonumber(string.format("%.4f", v)), min, max)
        end
    end

    local function mkToggle(host, text, default, cb, subtitle)
        local st = {on = default and true or false}
        local api = {}
        function api:Get() return st.on end
        function api:Set(v)
            v = v and true or false
            if v == st.on then return end
            st.on = v
            if st.real then st.real:Set(v, true) end
            if cb then task.spawn(cb, v) end
        end
        host:enqueue(function(h)
            st.real = h:Toggle{Title = text, Desc = subtitle, Default = st.on, NoInitialCallback = true, Callback = function(v)
                if v == st.on then return end
                st.on = v
                if cb then task.spawn(cb, v) end
            end}
            B.elements[host.path .. "/" .. text] = st.real
        end)
        if cb then task.spawn(cb, st.on) end                                -- like the old menu: the callback hears the starting value once
        return api
    end

    local function mkSlider(host, text, min, max, default, step, cb)
        assert(max > min and step > 0, "Slider: need max > min and step > 0")
        local snap = snapTo(min, max, step)
        local st = {value = snap(math.clamp(default, min, max))}
        local api = {}
        function api:Set(v)
            if type(v) ~= "number" then return end
            st.value = snap(math.clamp(v, min, max))
            if st.real then st.real:Set(st.value, true) end
            if cb then task.spawn(cb, st.value) end
        end
        host:enqueue(function(h)
            st.real = h:Slider{Title = text, Min = min, Max = max, Step = step, Default = st.value, Callback = function(v)
                if v == st.value then return end
                st.value = v
                if cb then task.spawn(cb, v) end
            end}
            B.elements[host.path .. "/" .. text] = st.real
        end)
        if cb then task.spawn(cb, st.value) end
        return api
    end

    local function mkDropdown(host, text, options, default, cb)
        local st = {value = table.find(options, default) and default or options[1]}
        local api = {}
        function api:Set(v)
            if not table.find(options, v) then return end
            st.value = v
            if st.real then st.real:Set(v, true) end
            if cb then task.spawn(cb, v) end
        end
        host:enqueue(function(h)
            st.real = h:Dropdown{Title = text, Values = options, Default = st.value, Search = #options > 8, Callback = function(v)
                if v == st.value then return end
                st.value = v
                if cb then task.spawn(cb, v) end
            end}
            B.elements[host.path .. "/" .. text] = st.real
        end)
        if cb then task.spawn(cb, st.value) end
        return api
    end

    -- the button's row: the hub only ever shows / hides it (a "Forget" button that has nothing to forget)
    local function mkButton(host, text, cb, desc)
        local st = {visible = true}
        local row = setmetatable({}, {
            __index = function(_, k) if k == "Visible" then return st.visible end end,
            __newindex = function(_, k, v)
                if k == "Visible" then
                    st.visible = v ~= false
                    if st.real then st.real:SetVisible(st.visible) end
                end
            end,
        })
        host:enqueue(function(h)
            st.real = h:Button{Title = text, Desc = desc, Outline = false, Callback = function() if cb then task.spawn(cb) end end}
            B.elements[host.path .. "/" .. text] = st.real
            if not st.visible then st.real:SetVisible(false) end
        end)
        return row
    end

    local function mkInput(host, text, placeholder, default, cb)
        local st = {text = tostring(default or "")}
        local api = {}
        function api:Get() return st.text end
        function api:Set(v)
            st.text = tostring(v)
            if st.real then st.real:Set(st.text, true) end
        end
        host:enqueue(function(h)
            st.real = h:Input{Title = text, Default = st.text, Placeholder = placeholder or "", Callback = function(v)
                st.text = v
                if cb then task.spawn(cb, v, true) end
            end}
            B.elements[host.path .. "/" .. text] = st.real
        end)
        return api
    end

    -- body text: the hub reads / writes `.Text`; other fields (TextSize, TextColor3) do not apply to a WindUI label
    local function mkLabel(host, text)
        local st = {text = tostring(text or "")}
        local label = setmetatable({}, {
            __index = function(_, k) if k == "Text" then return st.text end end,
            __newindex = function(_, k, v)
                if k == "Text" then
                    v = tostring(v)
                    if v ~= st.text then
                        st.text = v
                        if st.real then st.real:Set(v) end
                    end
                end
            end,
        })
        host:enqueue(function(h) st.real = h:Label(st.text); B.elements[host.path .. "/" .. text] = st.real end)
        return label
    end

    -- a switch on a card: spec = {default, onChange}; :set(v) changes it without calling onChange
    local function mkSwitch(host, text, spec)
        local st = {on = spec.default and true or false}
        local sw = {}
        function sw:set(v)
            v = v and true or false
            if v == st.on then return end
            st.on = v
            if st.real then st.real:Set(v, true) end
        end
        host:enqueue(function(h)
            st.real = h:Toggle{Title = text, Default = st.on, NoInitialCallback = true, Callback = function(v)
                if v == st.on then return end
                st.on = v
                if spec.onChange then task.spawn(spec.onChange, v) end
            end}
            B.elements[host.path .. "/" .. text] = st.real
        end)
        if st.on and spec.onChange then task.spawn(spec.onChange, true) end
        return sw
    end

    -- the combo card: a folding group with Run, the On screen / Assist switches and the options drawer (built when it is first opened)
    -- extra = {conf, options = function(drawer), pin = {default, onChange}, assist = {default, onChange}}; the result has :SetPinned / :SetArmed (they never call onChange)
    local function mkCard(host, name, desc, cb, extra)
        local handle = {}
        function handle:SetPinned() end
        function handle:SetArmed() end
        if extra == nil then                                                -- a plain row (the player list)
            mkButton(host, name, cb, desc)
            return handle
        end
        local card = newGroup(host, {Title = name, Desc = (extra.conf and ("[" .. extra.conf .. "]  ") or "") .. (desc or ""), Box = true, Opened = false})
        mkButton(card, "Run", cb)
        if extra.pin then
            local sw = mkSwitch(card, "On screen", extra.pin)
            function handle:SetPinned(v) sw:set(v) end
        end
        if extra.assist then
            local sw = mkSwitch(card, "Assist", extra.assist)
            function handle:SetArmed(v) sw:set(v) end
        end
        if extra.options then
            local drawer
            local built = false
            mkSwitch(card, "Show options", {default = false, onChange = function(on)
                if on and not built then
                    built = true
                    urgentMode = true                                      -- what the drawer builds comes before the rest of the queue: the click is waiting for it
                    local ok, err = pcall(extra.options, drawer)
                    urgentMode = false
                    if not ok then onError("options drawer", err) end
                end
                drawer:enqueue(function(h) if on then h:Open() else h:Close() end end, true)
            end})
            drawer = newGroup(card, {Title = "Options", Opened = false})               -- (below its switch)
        end
        return handle
    end

    ---------------------------------------------------------------------------------------------- tabs
    function B.sideHeader(text) side = win:SideSection(text, true) end

    function B.createTab(name, glyph)
        local real = win:Tab(name, TAB_ICONS[name] or "user", side)
        local rec = {name = name, real = real, queue = newQueue(), index = #win.Tabs}
        tabs[rec.index] = rec
        order[#order + 1] = rec
        local T = {__host = tabHost(rec), __rec = rec}
        if cards then
            local blurb = TAB_BLURBS[name] or string.format(CHARACTER_BLURB, name)
            T.__host:enqueue(function(h) B.elements[rec.name .. "/" .. name] = h:Paragraph{Title = name, Desc = blurb, Image = TAB_ICONS[name] or "user"} end)
        end
        function T:Select() win:SelectTab(rec.index) end
        function T:Hide() end
        function T:Label(text, parent) return mkLabel(hostFor(T, parent), text) end
        function T:Toggle(text, default, cb, parent, subtitle) return mkToggle(hostFor(T, parent), text, default, cb, subtitle) end
        function T:Slider(text, min, max, default, step, cb, parent) return mkSlider(hostFor(T, parent), text, min, max, default, step, cb) end
        function T:Dropdown(text, options, default, cb, parent) return mkDropdown(hostFor(T, parent), text, options, default, cb) end
        function T:Button(text, cb, parent) return mkButton(hostFor(T, parent), text, cb) end
        function T:Input(text, placeholder, default, cb, parent) return mkInput(hostFor(T, parent), text, placeholder, default, cb) end
        function T:Banner(title, subtitle, tag)
            T.__host:enqueue(function(h) B.elements[T.__host.path .. "/" .. title] = h:Paragraph{Title = tag and (title .. "   [" .. tag .. "]") or title, Desc = subtitle, Image = "sparkles"} end)
        end
        function T:Section(title, collapsed)
            local G = newGroup(T.__host, {Title = title, Opened = not collapsed})
            local sec = {Body = G}
            function sec:Button(bname, bdesc, bcb, extra) return mkCard(G, bname, bdesc, bcb, extra) end
            function sec:Info(iname, idesc) G:enqueue(function(h) B.elements[G.path .. "/" .. iname] = h:Paragraph{Title = iname, Desc = idesc} end) end
            function sec:Toggle(tname, default, tcb, subtitle) return mkToggle(G, tname, default, tcb, subtitle) end
            function sec:Slider(sname, min, max, default, step, scb) return mkSlider(G, sname, min, max, default, step, scb) end
            function sec:Dropdown(dname, options, default, dcb) return mkDropdown(G, dname, options, default, dcb) end
            function sec:Label(ltext) return mkLabel(G, ltext) end
            function sec:Clear() G:clear() end
            return sec
        end
        return T
    end

    ---------------------------------------------------------------------------------------------- window level
    -- the live ping next to the title: pill.Text / pill.TextColor3 are written like the old menu's ping pill
    function B.pingPill(title, color)
        local tag = win:Tag{Title = title, Color = color}
        local lastText, lastColor
        return setmetatable({}, {
            __newindex = function(_, k, v)
                if k == "Text" and v ~= lastText then lastText = v; tag:Set(v)
                elseif k == "TextColor3" then
                    local hex = hexOf(v)
                    if hex ~= lastColor then lastColor = hex; tag:Set(nil, hex) end
                end
            end,
        })
    end
    function B.toast(text, title) win:Notify{Title = title or "Wraith Hub v1.5", Content = tostring(text), Duration = 3, Type = "info"} end
    function B.setMenu(v) win:SetVisible(v and true or false) end
    function B.isOpen() return win.Main.Visible == true end
    function B.destroy()
        B.alive = false
        win:Destroy()
    end

    return B
end

return M
