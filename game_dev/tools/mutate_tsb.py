"""Mutation check of the Tech Lab tests (from game_dev/):  LUAU=/path/to/luau python3 tools/mutate_tsb.py
Each entry breaks tech_lab.lua in ONE deliberate way (cleanup skipped, a guard removed, a restore forgotten ...) and runs tests/run_tsb.py on the broken copy:
a test suite that cannot fail proves nothing, so every mutant must make it fail.
Known equivalent mutants: "camera hold never unbound" - the render step also unbinds itself the next frame when the run is cancelled, so the suite cannot tell the two
apart; "new: existing death counter missed" - two code paths find a Death Counter that was there first, and they only differ when WaitForChild yields (real Roblox, not the fake world)."""
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
 "ping: no shift": ("return TM.shiftWait(sec, lab:lag(), lab.net.strength)", "return sec"),
 "ping: no lead": ("function c.lead() return pingOn(tech) and lab:lead() or 0 end", "function c.lead() return 0 end"),
 "ping: hook not scaled": ("prediction = ctx.scaled(o.prediction)", "prediction = o.prediction"),
 "ping: learner not fed": ("            lab.lagger:seen(\"dash\", now)\n", ""),
 "ping: dash clock ignores lag": ("lab.dashClock:seen(kind, now, lag, lab:jitterMs() / 1000)", "lab.dashClock:seen(kind, now)"),
 "ping: window from the animation": ("lab.lastOwn[kind] = now - lag", "lab.lastOwn[kind] = now"),
 "ping: per-tech switch ignored": ("local function pingOn(tech) return tech.opt.ping ~= false end", "local function pingOn(tech) return true end"),
 "new: walk released early": ("        if close then ctx.wait(math.max(0, o.holdTime - o.m1Delay) / 1000) end", ""),
 "new: noclip never restored": ("            cleanups[#cleanups + 1] = function() for _, part in ipairs(parts) do if part.Parent then part.CanCollide = true end end end", ""),
 "new: noclip not re-applied": ("local conn = listen(RunService.Stepped, apply)", "local conn = nil"),
 "new: master off keeps marks": ("        if not lab.master then lab:clearMarks() end", ""),
 "new: existing death counter missed": ("        if model:FindFirstChild(\"Death Counter\") then deathCounterOn(model) end\n    end\n    local function unwatch", "    end\n    local function unwatch"),
 "new: own counter marked": ("        if notMe(model) and tech.counterSet[id] then", "        if tech.counterSet[id] then"),
 "new: grasp spam gap ignored": ("            if i < o.count and not ctx.wait(o.gap / 1000) then return end", ""),
 "new: fast dash keeps animation": ("if ctx.alive() and safe(function() return track.IsPlaying end) then pcall(function() track:Stop() end) end", ""),
 "new: shove without tool check": ("        if not lab:findTool(names) then return ctx.abort(\"you do not have \" .. names[1]) end\n        ctx.commit()\n        ctx.useMove(names)", "        ctx.commit()\n        ctx.useMove(names)"),
 "new: catch ignores dash cooldown": ("if not close and not ctx.dashReady(\"forward\") then return ctx.abort(\"the forward dash is on cooldown\") end", ""),
 "new: marks outlive destroy": ("        stopEnemyWatch()\n        lab:clearMarks()", "        stopEnemyWatch()"),
 "moving techs overlap": ("                if other ~= tech and other.moves and other.running then", "                if false then"),
}
# the camera hold also unbinds itself the next frame; the Death Counter check at watch time is also done by setEnabled's loop in a world where WaitForChild never yields
EQUIVALENT = {"camera hold never unbound", "new: existing death counter missed"}
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
