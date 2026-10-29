"""Mutation check of the WindUI hub tests (from game_dev/):  LUAU=/path/to/luau python3 tools/mutate_tsb_hub.py
Each entry breaks ../dist/tsb_lab.lua (the built bundle) in ONE deliberate way and runs tests/run_tsb.py hub on the broken copy; every mutant must make it fail."""
import os, subprocess, sys, tempfile
src = open("../dist/tsb_lab.lua", encoding="utf-8").read()
MUTANTS = {
 "unsaved changes written at once": ("    local function markDirty()\n        if not ready or dirty then return end\n        dirty = true",
                                     "    local function markDirty()\n        if not ready or dirty then return end\n        pcall(writefile, 'TSBLab/auto.json', '{}')\n        dirty = true"),
 "auto load ignores the flag": ("if index and index.autoload == true and type(index.name) == \"string\" then", "if index and type(index.name) == \"string\" then"),
 "config name not cleaned": ("        name = tostring(name or \"\"):gsub(\"[^%w_%- ]\", \"\"):gsub(\"^%s+\", \"\"):gsub(\"%s+$\", \"\")", "        name = tostring(name or \"\")"),
 "panic does nothing": ("                    lab:cancelAll(\"cancelled: panic\")\n                    return true", "                    return true"),
 "unload leaves the lab": ("    onCleanup(function() lab:destroy() end)", ""),
 "unload leaves the window": ("        if Hub.Win then pcall(function() Hub.Win:Destroy() end) end", ""),
 "old session kept on rerun": ("if type(genv.__TSBLab) == \"table\" and genv.__TSBLab.Destroy then pcall(genv.__TSBLab.Destroy) end", ""),
 "save forgets the techs": ("floats = floats, techlab = lab:export()}", "floats = floats}"),
 "load forgets the controls": ("                if tech and key == \"on\" then el:Set(tech.enabled, true)", "                if false then el:Set(tech.enabled, true)"),
 "invalid theme accepted": ("if type(saved.theme) == \"string\" then for _, t in ipairs(THEMES) do if t == saved.theme then S.theme = t end end end", "if type(saved.theme) == \"string\" then S.theme = saved.theme end"),
 "scale not clamped": ("S.uiScale = clampNum(saved.uiScale, 0.55, 1.2, S.uiScale)", "S.uiScale = saved.uiScale or S.uiScale"),
 "float buttons start visible": ("S.floats[d.id] = {x = -1, y = -1, visible = d.id == \"panic\"}", "S.floats[d.id] = {x = -1, y = -1, visible = true}"),
 "fallback missing": ("        local theme = \"Ocean\"\n        cfg.Theme = theme\n        return UILib.new(cfg)", "        error('no fallback')"),
 "techs start on": ("    if savedTech then lab:import(savedTech) end", "    if savedTech then lab:import(savedTech) end\n    lab:setEnabled('supa', true)"),
 # v1.5: the white water, the WindUI structure, the targeting controls
 "water never animates": ("    connect(game:GetService(\"RunService\").Heartbeat, function(dt) safe(\"water\", stepWater, dt) end)", ""),
 "water listener not tracked": ("    connect(game:GetService(\"RunService\").Heartbeat, function(dt) safe(\"water\", stepWater, dt) end)",
                                "    game:GetService(\"RunService\").Heartbeat:Connect(function(dt) safe(\"water\", stepWater, dt) end)"),
 "water animates while closed": ("if not water.On or #water.Layers == 0 or Window.Closed then return end", "if not water.On or #water.Layers == 0 then return end"),
 "water button does nothing": ("Callback = function() if toggleWater then toggleWater() end end}", "Callback = function() end}"),
 "water setting does not follow": ("        if waterToggle then waterToggle:Set(S.water, true) end\n", ""),
 "theme does not retint the water": ("Win:SetTheme(v); Win:SetWater{Tint = waterTint(v)}; markDirty()", "Win:SetTheme(v); markDirty()"),
 "water strength not clamped": ("S.waterStrength = clampNum(saved.waterStrength, 0, 1, S.waterStrength)", "S.waterStrength = saved.waterStrength or S.waterStrength"),
 "bad background link accepted": ("if type(saved.bgUrl) == \"string\" and #saved.bgUrl <= 300 and not saved.bgUrl:find(\"%c\") then", "if type(saved.bgUrl) == \"string\" then"),
 "welcome card ignores the setting": ("    if S.popup then\n        Win:Popup{", "    if true then\n        Win:Popup{"),
 "save forgets the water": ("                water = S.water, waterStrength = S.waterStrength,", "                waterStrength = S.waterStrength,"),
 "changelog button does nothing": ("Callback = function() if showChangelog then showChangelog() end end}", "Callback = function() end}"),
 "no tab cards": ("        tab:Paragraph{Title = t[1], Desc = table.concat(lines, \"\\n\"), Image = tabIcon(t[2], nil)}\n", ""),
 "targeting not wired": ("if lab.targetMode ~= v then lab:setTargetMode(v); markDirty() end", "markDirty()"),
 "load forgets the lab-wide controls": ("                elseif not id and LAB_FLAGS[flag] then el:Set(lab[flag], true) end", "                end"),
}
bad = 0
with tempfile.TemporaryDirectory() as tmp:
    only = os.environ.get("ONLY")                                     # ONLY="part of a name" runs just the matching mutants
    for name, (a, b) in MUTANTS.items():
        if only and only not in name: continue
        if src.count(a) != 1:
            print("NOT APPLICABLE (the hub changed):", name, src.count(a)); bad += 1; continue
        path = os.path.join(tmp, "mutant.lua")
        open(path, "w", encoding="utf-8").write(src.replace(a, b, 1))
        r = subprocess.run([sys.executable, "tests/run_tsb.py", "hub"], capture_output=True, text=True, env=dict(os.environ, TSB_HUB=path))
        caught = r.returncode != 0
        first = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith("FAIL")][:1]
        print("caught   " if caught else "SURVIVED ", name, first)
        if not caught: bad += 1
print("%d mutants, %d problems" % (len(MUTANTS), bad))
sys.exit(1 if bad else 0)
