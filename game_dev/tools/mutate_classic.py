"""Mutation check of the classic hub's WindUI menu tests (from game_dev/):  LUAU=/path/to/luau python3 tools/mutate_classic.py
Each entry breaks ../dist/tsb_hub_executor.lua (the built bundle) in ONE deliberate way and runs tests/run_tsb.py classic on the broken copy, only the sections of the test that are
meant to notice it (CLASSIC_SECTIONS); every mutant must make them fail. ONLY="part of a name" runs just the matching mutants."""
import os, subprocess, sys, tempfile
src = open("../dist/tsb_hub_executor.lua", encoding="utf-8").read()
# name: (old, new, the test sections that must notice it)
MUTANTS = {
 "AH_LEGACY_UI is ignored": ("genv.AH_LEGACY_UI ~= true", "true", "builtin"),
 "no fallback when WindUI fails": ("if ok then Backend = res else backendProblem = res end", "if ok then Backend = res else error(res) end", "builtin"),
 "a half-made window leaves its ScreenGuis": ("        pcall(function() win.Alive = true; win:Destroy() end)\n        for _, key in ipairs({\"ScreenGui\", \"NotificationGui\", \"DropdownGui\", \"TooltipGui\"}) do\n            local g = WindUI[key]\n            if g then pcall(function() g:Destroy() end) end\n        end\n        error(err, 0)",
                                                "        pcall(function() win.Alive = true; win:Destroy() end)\n        error(err, 0)", "builtin"),
 "the built-in window stays visible next to WindUI": ("        Main.Visible = false\n        menuOpen = Backend.isOpen()", "        menuOpen = Backend.isOpen()", "boot"),
 "RightShift toggles the window twice": ("if not gp and not Backend and i.KeyCode == Enum.KeyCode.RightShift then toggleMenu() end", "if not gp and i.KeyCode == Enum.KeyCode.RightShift then toggleMenu() end", "teleports"),
 "the bar does not count the pins": ("        markDirty()\n        if renderFab then renderFab() end                       -- (the bar counts the pins)\n    end", "        markDirty()\n    end", "combos"),
 "Save config forgets the look": ("            wind = WindPrefs,\n", "", "config"),
 "a wrong look value is not clamped": ("        WindPrefs.waterStrength = num(w.waterStrength, 0, 1, WindPrefs.waterStrength)", "        WindPrefs.waterStrength = w.waterStrength or WindPrefs.waterStrength", "config"),
 "a wrong theme name is accepted": ("        for _, name in ipairs(WindAdapter.ThemeNames) do if name == w.theme then WindPrefs.theme = name end end", "        if type(w.theme) == \"string\" then WindPrefs.theme = w.theme end", "config"),
 "the theme does not retint the water": ("win:SetTheme(v); win:SetWater{Tint = WindAdapter.waterTint(v)}; markDirty()", "win:SetTheme(v); markDirty()", "look"),
 "the top bar's Water button does nothing": ("{Name = \"Water\", Icon = \"sparkles\", Callback = function() if windActions.toggleWater then windActions.toggleWater() end end},", "{Name = \"Water\", Icon = \"sparkles\", Callback = function() end},", "look"),
 "a picture link with a control character is accepted": ("            if #text > 300 or text:find(\"%c\") then toast(\"That link is not usable\") return end\n            if Picture.source == text", "            if Picture.source == text", "look"),
 "Panic leaves the combo playing": ("            if stopMacro then stopMacro() end\n            if techLab then", "            if techLab then", "panic"),
 "Panic leaves the Tech Lab running": ("            if techLab then techLab:cancelAll(\"cancelled: panic\") end\n            toast(\"Panic: everything stopped\")", "            toast(\"Panic: everything stopped\")", "panic"),
 "the bar's Menu light does not follow the window": ("                if open ~= menuOpen then menuOpen = open; if renderFab then renderFab() end end", "", "teleports"),
 "the on-screen buttons keep the old palette": ("            Theme[key] = rgb(c)\n        end\n        Theme.Ink,", "            local _ = rgb(c)\n        end\n        Theme.Ink,", "teleports"),
 "unloading leaves the WindUI window": ("onCleanup[#onCleanup + 1] = function() Backend.destroy(); if genv.__AnimationHubUI == Backend then genv.__AnimationHubUI = nil end end", "onCleanup[#onCleanup + 1] = function() end", "unload"),
 "the welcome card ignores its setting": ("    if Backend and WindPrefs.popup then", "    if Backend then", "config"),
 "Reset this combo does nothing": ("                    for key, sl in pairs(sliders) do sl:Set(ComboOptions.DEFAULTS[key]) end\n                    for key, dd in pairs(pickers)", "                    for key, dd in pairs(pickers)", "combos"),
 "the options drawer never builds": ("                if on and not built then", "                if false then", "combos"),
 "a row hidden by the hub stays visible": ("            function el:SetVisible(v) pcall(function() el.Ui.ElementFrame.Visible = v ~= false end) end", "            function el:SetVisible(v) end", "combos"),
 "Clear leaves the buttons": ("                    if it.Clear then it:Clear() end\n                    if it.Destroy then it:Destroy() end", "                    if it.Clear then it:Clear() end", "teleports"),
 "sidebar groups are not made": ("        local ui = Window:Section{Title = title, Opened = opened ~= false}\n        return {title = title, ui = ui}", "        return {title = title, ui = Window}", "boot"),
 "a tab you open is not built first": ("        local showing = tabs[win.Window.CurrentTab]                           -- (WindUI keeps the shown tab's index)", "        local showing = nil", "boot"),
 "tabs open without their card": ("        if cards then\n            local blurb", "        if false then\n            local blurb", "boot"),
 "the ping is never shown": ("        pingPill = Backend.pingPill(\"-- ms\", \"#9be8c4\")", "        pingPill = {}", "teleports"),
}
bad = 0
ran = 0
with tempfile.TemporaryDirectory() as tmp:
    only = os.environ.get("ONLY")
    for name, (a, b, sections) in MUTANTS.items():
        if only and only not in name: continue
        if src.count(a) != 1:
            print("NOT APPLICABLE (the hub changed):", name, src.count(a)); bad += 1; continue
        ran += 1
        path = os.path.join(tmp, "mutant.lua")
        open(path, "w", encoding="utf-8").write(src.replace(a, b, 1))
        r = subprocess.run([sys.executable, "tests/run_tsb.py", "classic"], capture_output=True, text=True, env=dict(os.environ, CLASSIC_HUB=path, CLASSIC_SECTIONS=sections))
        caught = r.returncode != 0
        first = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith("FAIL")][:1]
        print("caught   " if caught else "SURVIVED ", name, first, flush=True)
        if not caught: bad += 1
print("%d mutants, %d problems" % (ran, bad))
sys.exit(1 if bad else 0)
