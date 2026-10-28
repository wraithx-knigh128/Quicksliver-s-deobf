"""Mutation check of the Tech Lab tests (from game_dev/):  LUAU=/path/to/luau python3 tools/mutate_tsb.py
Each entry breaks tech_lab.lua in ONE deliberate way (cleanup skipped, a guard removed, a restore forgotten ...) and runs tests/run_tsb.py on the broken copy:
a test suite that cannot fail proves nothing, so every mutant must make it fail.
Known equivalent mutant: "camera hold never unbound" - the render step also unbinds itself the next frame when the run is cancelled, so the suite cannot tell the two apart."""
import os, subprocess, sys, tempfile
src = open("tech_lab.lua", encoding="utf-8").read()
MUTANTS = {
 "no cleanup": ("            ctx.finish()\n            if tech.token ~= token then return end", "            if tech.token ~= token then return end"),
 "dash guard off": ("if tech.needsDash and lab.dashGuard and not lab.dashClock:ready", "if false and not lab.dashClock:ready"),
 "cancel does nothing": ("tech.token == token and char.Parent ~= nil and healthy(hum)", "char.Parent ~= nil and healthy(hum)"),
 "own tracks count": ("        if ownTracks[track] then return end\n", ""),
 "no cooldown": ("if ok and ctx.committed then tech.cooldownUntil = clock() + (tech.opt.cooldown or 0) end", ""),
 "hook fixed time constant": ("local left = math.max(o.duration - (clock() - t0), 1 / 60)", "local left = o.duration"),
 "busy ignored": ("if not info.manual and env.busy and env.busy() then return false, \"busy\" end", ""),
 "master ignored": ("if not info.manual and not (lab.master and tech.enabled) then return false, \"off\" end", "if not info.manual and not tech.enabled then return false, \"off\" end"),
 "respawn not hooked": ("hookCharacter(char) end)\n    return lab", "end)\n    return lab"),
 "death not cancelling": ("listen(hum.Died, function() lab:cancelAll(\"cancelled: you died\") end)", "nil"),
 "destroy leaves listeners": ("        for _, c in ipairs(lab.conns) do pcall(function() c:Disconnect() end) end\n", ""),
 "counter ignores distance": ("        if d > o.distance then return end\n", ""),
 "counter ignores facing": ("            if TM.dot(TM.unit(TM.flat(vec(eroot.CFrame.LookVector))), to) < -0.2 then return end\n", ""),
 "supa wrong behind": ("targetLook = vec(entry.root.CFrame.LookVector)}", "targetLook = nil}"),
 "import unclean": ("tech.opt = TO.clean(tech.defs, type(saved.opts) == \"table\" and saved.opts[tech.id] or nil)", "tech.opt = (type(saved.opts) == \"table\" and saved.opts[tech.id]) or tech.opt"),
 "side m1 not restored": ("if ctx.root.Parent then ctx.root.CFrame = ctx.root.CFrame * CFrame.Angles(0, -ang, 0) end", ""),
 "rotation not restored": ("conn:Disconnect(); if hum.Parent then hum.AutoRotate = prev end", "conn:Disconnect()"),
 "camera hold never unbound": ("c.onFinish(unbind)\n", ""),
 "moving techs overlap": ("                if other ~= tech and other.moves and other.running then", "                if false then"),
}
EQUIVALENT = {"camera hold never unbound"}
bad = 0
with tempfile.TemporaryDirectory() as tmp:
    for name, (a, b) in MUTANTS.items():
        if a not in src:
            print("NOT APPLICABLE (the engine changed):", name); bad += 1; continue
        path = os.path.join(tmp, "mutant.lua")
        open(path, "w", encoding="utf-8").write(src.replace(a, b, 1))
        r = subprocess.run([sys.executable, "tests/run_tsb.py", "lab"], capture_output=True, text=True, env=dict(os.environ, TSB_LAB=path))
        caught = r.returncode != 0
        first = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith("FAIL")][:1]
        print("caught   " if caught else ("equivalent" if name in EQUIVALENT else "SURVIVED "), name, first)
        if not caught and name not in EQUIVALENT: bad += 1
print("%d mutants, %d problems" % (len(MUTANTS), bad))
sys.exit(1 if bad else 0)
