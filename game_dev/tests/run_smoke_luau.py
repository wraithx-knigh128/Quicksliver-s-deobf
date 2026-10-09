"""Run tests/smoke_ui.lua on REAL Luau (what Roblox runs). Needs the `luau` CLI from
https://github.com/luau-lang/luau/releases  (set LUAU=/path/to/luau).
Usage (from game_dev/):  LUAU=/path/to/luau python3 tests/run_smoke_luau.py [script]"""
import os, subprocess, sys, tempfile
script = sys.argv[1] if len(sys.argv) > 1 else "../dist/tsb_hub_executor.lua"
src = open(script, encoding="utf-8").read()
assert "]====]" not in src
smoke = open("tests/smoke_ui.lua", encoding="utf-8").read()
with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False, encoding="utf-8") as f:
    types = open("tests/prop_types.lua", encoding="utf-8").read()
    assert "]====]" not in types
    f.write("SCRIPT_SOURCE = [====[" + src + "]====]\nPROP_TYPES_SOURCE = [====[" + types + "]====]\n" + smoke)
    path = f.name
r = subprocess.run([os.environ.get("LUAU", "luau"), path], capture_output=True, text=True, timeout=300)
print(r.stdout.strip()); print(r.stderr.strip()[:2000])
sys.exit(r.returncode)
