"""Mutation check of the classic hub's menu layer (from game_dev/):  LUAU=/path/to/luau python3 tools/mutate_classic_wind.py
Each entry breaks classic_wind.lua in ONE deliberate way and runs tests/run_tsb.py shim on the broken copy (CLASSIC_SHIM=...); every mutant must make the unit tests fail.
ONLY="part of a name" runs just the matching mutants."""
import os, subprocess, sys, tempfile
src = open("classic_wind.lua", encoding="utf-8").read()
MUTANTS = {
 "the tab on screen is not built first": ("        local showing = tabs[win.Window.CurrentTab]                           -- (WindUI keeps the shown tab's index)", "        local showing = nil"),
 "urgent work waits its turn": ("        local fn = pop(urgentQ)\n        if fn then return fn end\n        local showing", "        local fn = nil\n        local showing"),
 "a drawer is built at the back": ("                    urgentMode = true                                      -- what the drawer builds comes before the rest of the queue: the click is waiting for it", "                    urgentMode = false"),
 "Clear keeps what was queued": ("            G.gen = G.gen + 1\n            job(G.rec, function() if G.real then G.real:Clear() end end)", "            job(G.rec, function() if G.real then G.real:Clear() end end)"),
 "Clear leaves the controls": ("            job(G.rec, function() if G.real then G.real:Clear() end end)", "            job(G.rec, function() end)"),
 "a label shows its first text, not the current one": ("        host:enqueue(function(h) st.real = h:Label(st.text); B.elements[host.path .. \"/\" .. text] = st.real end)", "        host:enqueue(function(h) st.real = h:Label(text); B.elements[host.path .. \"/\" .. text] = st.real end)"),
 "a label's later change is lost": ("                        st.text = v\n                        if st.real then st.real:Set(v) end", "                        st.text = v"),
 "a row's Visible is ignored": ("                    st.visible = v ~= false\n                    if st.real then st.real:SetVisible(st.visible) end", "                    st.visible = v ~= false"),
 "a row hidden early is built shown": ("            if not st.visible then st.real:SetVisible(false) end\n", ""),
 "a slider does not snap": ("        local snap = snapTo(min, max, step)", "        local snap = function(v) return v end"),
 "a dropdown takes unknown options": ("            if not table.find(options, v) then return end\n", ""),
 "no starting callback for a toggle": ("        if cb then task.spawn(cb, st.on) end                                -- like the old menu: the callback hears the starting value once\n        return api\n    end\n\n    local function mkSlider", "        return api\n    end\n\n    local function mkSlider"),
 "a card switched on at the start stays silent": ("        if st.on and spec.onChange then task.spawn(spec.onChange, true) end\n        return sw", "        return sw"),
 "SetPinned / SetArmed call the hub back": ("            if v == st.on then return end\n            st.on = v\n            if st.real then st.real:Set(v, true) end\n        end\n        host:enqueue(function(h)\n            st.real = h:Toggle{Title = text, Default = st.on, NoInitialCallback = true, Callback = function(v)\n                if v == st.on then return end\n                st.on = v\n                if spec.onChange",
                                            "            if v == st.on then return end\n            st.on = v\n            if spec.onChange then task.spawn(spec.onChange, v) end\n            if st.real then st.real:Set(v, true) end\n        end\n        host:enqueue(function(h)\n            st.real = h:Toggle{Title = text, Default = st.on, NoInitialCallback = true, Callback = function(v)\n                if v == st.on then return end\n                st.on = v\n                if spec.onChange"),
 "the options are built every time the drawer opens": ("                if on and not built then", "                if on then"),
 "the drawer is never opened": ("                drawer:enqueue(function(h) if on then h:Open() else h:Close() end end, true)", "                drawer:enqueue(function(h) h:Close() end, true)"),
 "a card without extras becomes a group": ("        if extra == nil then                                                -- a plain row (the player list)", "        if false then"),
 "the ping tag is rewritten every time": ("                if k == \"Text\" and v ~= lastText then lastText = v; tag:Set(v)", "                if k == \"Text\" then lastText = v; tag:Set(v)"),
 "the ping colour is rewritten every time": ("                    if hex ~= lastColor then lastColor = hex; tag:Set(nil, hex) end", "                    lastColor = hex; tag:Set(nil, hex)"),
 "destroying does not stop the building": ("    function B.destroy()\n        B.alive = false\n", "    function B.destroy()\n"),
 "one failing control stops the queue": ("                local ok, err = pcall(fn)\n                if not ok then onError(\"menu build\", err) end", "                fn()"),
 "sidebar groups are ignored": ("    function B.sideHeader(text) side = win:SideSection(text, true) end", "    function B.sideHeader(text) end"),
 "every tab gets the same icon": ("        local real = win:Tab(name, TAB_ICONS[name] or \"user\", side)", "        local real = win:Tab(name, \"user\", side)"),
 "tabs open without their card": ("        if cards then\n            local blurb", "        if false then\n            local blurb"),
 "a character's card has no name": ("string.format(CHARACTER_BLURB, name)", "string.format(CHARACTER_BLURB, \"\")"),
 "the pending count is wrong": ("    local function size(q) return q.last - q.first + 1 end", "    local function size(q) return 0 end"),
 "controls cannot be found by path": ("            st.real = h:Toggle{Title = text, Desc = subtitle, Default = st.on, NoInitialCallback = true, Callback = function(v)\n                if v == st.on then return end\n                st.on = v\n                if cb then task.spawn(cb, v) end\n            end}\n            B.elements[host.path .. \"/\" .. text] = st.real",
                                          "            st.real = h:Toggle{Title = text, Desc = subtitle, Default = st.on, NoInitialCallback = true, Callback = function(v)\n                if v == st.on then return end\n                st.on = v\n                if cb then task.spawn(cb, v) end\n            end}"),
}
bad = 0
with tempfile.TemporaryDirectory() as tmp:
    only = os.environ.get("ONLY")
    for name, (a, b) in MUTANTS.items():
        if only and only not in name: continue
        if src.count(a) != 1:
            print("NOT APPLICABLE (the layer changed):", name, src.count(a)); bad += 1; continue
        path = os.path.join(tmp, "mutant.lua")
        open(path, "w", encoding="utf-8").write(src.replace(a, b, 1))
        r = subprocess.run([sys.executable, "tests/run_tsb.py", "shim"], capture_output=True, text=True, env=dict(os.environ, CLASSIC_SHIM=path))
        caught = r.returncode != 0
        first = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith("FAIL")][:1]
        print("caught   " if caught else "SURVIVED ", name, first)
        if not caught: bad += 1
print("%d mutants, %d problems" % (len(MUTANTS) if not only else sum(1 for n in MUTANTS if only in n), bad))
sys.exit(1 if bad else 0)
