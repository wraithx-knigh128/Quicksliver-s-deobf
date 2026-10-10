"""MM2 hub checks (from game_dev/):
  python3 tests/run_mm2.py logic            unit tests of mm2/logic.lua
  python3 tests/run_mm2.py smoke [script]   hub run against the fake Roblox world in tests/mm2_env.lua   (default: ../dist/wraiths_hub.lua)
Add LUAU=/path/to/luau to run the same thing on real Luau (what Roblox runs)."""
import os, subprocess, sys
mode = sys.argv[1] if len(sys.argv) > 1 else "logic"
read = lambda p: open(p, encoding="utf-8").read()
parts = {
    "logic": [("LOGIC_MODULE", "mm2/logic.lua", True)],
}
def long_string(name, text, is_module=False):
    assert "]====]" not in text
    if is_module:
        return "%s = (function()\n%s\nend)()\n" % (name, text)
    return "%s = [====[%s]====]\n" % (name, text)
if mode == "logic":
    prelude = long_string("LOGIC_MODULE", read("mm2/logic.lua"), True)
    body = read("tests/mm2_logic_tests.lua")
elif mode == "smoke":
    script = sys.argv[2] if len(sys.argv) > 2 else "../dist/wraiths_hub.lua"
    prelude = ("SCRIPT_SOURCE = [====[%s]====]\nPROP_TYPES_SOURCE = [====[%s]====]\nLOGIC_MODULE = (function()\n%s\nend)()\n"
               % (read(script), read("tests/prop_types_mm2.lua"), read("mm2/logic.lua")))
    body = read("tests/mm2_env.lua") + "\n" + read("tests/mm2_layout.lua") + "\n" + read(os.environ.get("MM2_SMOKE", "tests/mm2_smoke.lua"))
elif mode == "preview":
    script = sys.argv[2] if len(sys.argv) > 2 else "../dist/wraiths_hub.lua"
    outdir = os.path.join("..", "preview", "mm2")
    os.makedirs(outdir, exist_ok=True)
    prelude = ("SCRIPT_SOURCE = [====[%s]====]\nPROP_TYPES_SOURCE = [====[%s]====]\nPREVIEW_DIR = %r\nLOGIC_MODULE = (function()\n%s\nend)()\n"
               % (read(script), read("tests/prop_types_mm2.lua"), outdir, read("mm2/logic.lua")))
    body = read("tests/mm2_env.lua") + "\n" + read("tests/mm2_layout.lua") + "\n" + read("tests/mm2_preview.lua")
else:
    sys.exit(__doc__)
src = prelude + body
if os.environ.get("LUAU"):
    import tempfile
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False, encoding="utf-8") as f:
        f.write(src); path = f.name
    r = subprocess.run([os.environ["LUAU"], path], capture_output=True, text=True, timeout=300)
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
