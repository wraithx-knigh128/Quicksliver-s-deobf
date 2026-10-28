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
}
bad = 0
with tempfile.TemporaryDirectory() as tmp:
    for name, (a, b) in MUTANTS.items():
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
