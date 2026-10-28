"""Tech Lab checks (from game_dev/):
  python3 tests/run_tsb.py lab     the Tech Lab played in a simulated Strongest Battlegrounds arena (tests/tsb_sim.lua) -> tests/tsb_lab_tests.lua
Needs real Luau (the fake Roblox world is shared with the MM2 tests): set LUAU=/path/to/luau, or put `luau` on PATH.
Regenerate the strict API tables after using new Roblox members:  sh tools/gen_tsb_types.sh"""
import os, re, shutil, subprocess, sys, tempfile
mode = sys.argv[1] if len(sys.argv) > 1 else "lab"
if mode != "lab":
    sys.exit(__doc__)
read = lambda p: open(p, encoding="utf-8").read()
luau = os.environ.get("LUAU") or shutil.which("luau") or ("/tmp/claude-0/luau_bin/luau" if os.path.exists("/tmp/claude-0/luau_bin/luau") else None)

def long_string(text):
    assert "]====]" not in text
    return "[====[%s]====]" % text

modules = ["tech_math.lua", "tech_data.lua", "tech_options.lua", "tech_lab.lua"]
# TSB_LAB=/path/to/mutant.lua swaps the engine for a deliberately broken copy (mutation checks: every test must be able to fail)
prelude = "TECH_SOURCES = {%s}\nPROP_TYPES_SOURCE = %s\n" % (",".join('["%s"]=%s' % (m, long_string(read(os.environ.get("TSB_LAB", m) if m == "tech_lab.lua" else m))) for m in modules), long_string(read("tests/prop_types_tsb.lua")))
src = prelude + read("tests/mm2_env.lua") + "\n" + read("tests/tsb_sim.lua") + "\n" + read(os.environ.get("TSB_TESTS", "tests/tsb_lab_tests.lua"))
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
