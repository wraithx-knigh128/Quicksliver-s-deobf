"""Tech Lab checks (from game_dev/):
  python3 tests/run_tsb.py lab     the Tech Lab played in a simulated Strongest Battlegrounds arena (tests/tsb_sim.lua) -> tests/tsb_lab_tests.lua
  python3 tests/run_tsb.py hub     Wraith's TSB Lab (dist/tsb_lab.lua, on the REAL WindUI) played in the same arena -> tests/tsb_hub_tests.lua
Needs real Luau (the fake Roblox world is shared with the MM2 tests): set LUAU=/path/to/luau, or put `luau` on PATH.
Regenerate the strict API tables after using new Roblox members:  sh tools/gen_tsb_types.sh"""
import os, re, shutil, subprocess, sys, tempfile
mode = sys.argv[1] if len(sys.argv) > 1 else "lab"
if mode not in ("lab", "hub"):
    sys.exit(__doc__)
read = lambda p: open(p, encoding="utf-8").read()
luau = os.environ.get("LUAU") or shutil.which("luau") or ("/tmp/claude-0/luau_bin/luau" if os.path.exists("/tmp/claude-0/luau_bin/luau") else None)

def long_string(text):
    assert "]====]" not in text
    return "[====[%s]====]" % text

modules = ["tech_math.lua", "tech_data.lua", "tech_options.lua", "tech_lab.lua"]
sources = ",".join('["%s"]=%s' % (m, long_string(read(os.environ.get("TSB_LAB", m) if m == "tech_lab.lua" else m))) for m in modules)
if mode == "lab":
    # TSB_LAB=/path/to/mutant.lua swaps the engine for a deliberately broken copy (mutation checks: every test must be able to fail)
    prelude = "TECH_SOURCES = {%s}\nPROP_TYPES_SOURCE = %s\n" % (sources, long_string(read("tests/prop_types_tsb.lua")))
    test = os.environ.get("TSB_TESTS", "tests/tsb_lab_tests.lua")
else:
    import json, subprocess
    script = os.environ.get("TSB_HUB", "../dist/tsb_lab.lua")
    srcs = ["tsb/lab_hub.lua", "tsb/build_tsb_lab.py", "tech_lab.lua", "tech_math.lua", "tech_data.lua", "tech_options.lua", "ping_model.lua", "mm2/ui_lib.lua", "mm2/windui_ui.lua",
            "mm2/vendor/windui.lua", "mm2/vendor/patch_windui.py"]
    if script == "../dist/tsb_lab.lua" and (not os.path.exists(script) or max(os.path.getmtime(x) for x in srcs) > os.path.getmtime(script)):
        subprocess.run([sys.executable, "tsb/build_tsb_lab.py"], check=True, stdout=subprocess.DEVNULL)      # the default script is the built bundle: rebuild it when a source is newer
    prelude = ("TECH_SOURCES = {%s}\nSCRIPT_SOURCE = %s\nPROP_TYPES_SOURCE = %s\nLUCIDE_IDS = {%s}\n"
               % (sources, long_string(read(script)), long_string(read("tests/prop_types_tsb_hub.lua")),
                  ",".join('["%s"]="%s"' % kv for kv in json.load(open("mm2/vendor/lucide_subset.json")).items())))
    test = os.environ.get("TSB_TESTS", "tests/tsb_hub_tests.lua")
src = prelude + read("tests/mm2_env.lua") + "\n" + read("tests/tsb_sim.lua") + "\n" + read(test)
if luau:
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False, encoding="utf-8") as f:
        f.write(src); path = f.name
    r = subprocess.run([luau, path], capture_output=True, text=True, timeout=900)
    print(r.stdout.strip()); print(r.stderr.strip()[:3000]); sys.exit(r.returncode)
from lupa import LuaRuntime
lua = LuaRuntime()
lua.execute("os.exit = function(c) EXIT = c; error('__exit__') end")
try:
    lua.execute(src)
except Exception as e:
    if "__exit__" not in str(e):
        print("EXC", e); sys.exit(2)
sys.exit(int(lua.globals().EXIT or 0))
