"""MM2 hub checks (from game_dev/):
  python3 tests/run_mm2.py logic              unit tests of mm2/logic.lua
  python3 tests/run_mm2.py smoke [script]     hub run against the fake Roblox world in tests/mm2_env.lua   (default: ../dist/wraiths_hub.lua)
  python3 tests/run_mm2.py windui [script]    the same hub with the REAL WindUI library inside the fake world (tests/mm2_windui.lua)
  python3 tests/run_mm2.py preview [script]   layout of the classic menu -> ../preview/mm2/*.json (render with tools/render_preview.py)
Everything but `logic` needs real Luau (the bundled WindUI uses Luau syntax): set LUAU=/path/to/luau, or put `luau` on PATH.
MM2_UI=Classic|WindUI picks the menu the `smoke` / `preview` runs use (default Classic: the checks there address the classic menu's rows)."""
import os, shutil, subprocess, sys, tempfile
mode = sys.argv[1] if len(sys.argv) > 1 else "logic"
read = lambda p: open(p, encoding="utf-8").read()
luau = os.environ.get("LUAU") or shutil.which("luau") or ("/tmp/claude-0/luau_bin/luau" if os.path.exists("/tmp/claude-0/luau_bin/luau") else None)

def long_string(name, text, is_module=False):
    assert "]====]" not in text
    if is_module:
        return "%s = (function()\n%s\nend)()\n" % (name, text)
    return "%s = [====[%s]====]\n" % (name, text)

outdir = os.path.join("..", "preview", "mm2")
ui = os.environ.get("MM2_UI", "Classic")
if mode == "logic":
    prelude = long_string("LOGIC_MODULE", read("mm2/logic.lua"), True)
    body = read("tests/mm2_logic_tests.lua")
    luau = None                                                     # plain Lua is enough
elif mode in ("smoke", "windui", "preview"):
    script = sys.argv[2] if len(sys.argv) > 2 else "../dist/wraiths_hub.lua"
    if len(sys.argv) <= 2:                                          # the default script is the built bundle: rebuild it when a source is newer
        srcs = ["mm2/wraiths_hub.lua", "mm2/logic.lua", "mm2/ui_lib.lua", "mm2/windui_ui.lua", "mm2/build_mm2.py", "mm2/vendor/windui.lua", "mm2/vendor/patch_windui.py"]
        if not os.path.exists(script) or max(os.path.getmtime(x) for x in srcs) > os.path.getmtime(script):
            subprocess.run([sys.executable, "mm2/build_mm2.py"], check=True, stdout=subprocess.DEVNULL)
    prelude = ("SCRIPT_SOURCE = [====[%s]====]\nPROP_TYPES_SOURCE = [====[%s]====]\nMM2_UI = %r\nLOGIC_MODULE = (function()\n%s\nend)()\n"
               % (read(script), read("tests/prop_types_mm2.lua"), ui, read("mm2/logic.lua")))
    if mode == "windui":
        prelude = "MM2_UI = 'WindUI'\n" + prelude.replace("MM2_UI = %r\n" % ui, "", 1)
    test = {"smoke": os.environ.get("MM2_SMOKE", "tests/mm2_smoke.lua"), "windui": "tests/mm2_windui.lua", "preview": "tests/mm2_preview.lua"}[mode]
    body = read("tests/mm2_env.lua") + "\n" + read("tests/mm2_layout.lua") + "\n" + read(test)
    if mode == "preview":
        os.makedirs(outdir, exist_ok=True)
        prelude += "PREVIEW_DIR = %r\n" % outdir
else:
    sys.exit(__doc__)
src = prelude + body
if luau:
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False, encoding="utf-8") as f:
        f.write(src); path = f.name
    r = subprocess.run([luau, path], capture_output=True, text=True, timeout=900)
    out = r.stdout
    # Luau has no io library: the preview prints its files between markers and they are written here
    import re
    for m in re.finditer(r"@@FILE (\S+)\n(.*?)\n@@END", out, re.S):
        open(os.path.join(outdir, m.group(1)), "w").write(m.group(2))
    out = re.sub(r"@@FILE (\S+)\n(.*?)\n@@END\n?", "", out, flags=re.S)
    print(out.strip()); print(r.stderr.strip()[:3000]); sys.exit(r.returncode)
from lupa import LuaRuntime
lua = LuaRuntime()
lua.execute("os.exit = function(c) EXIT = c; error('__exit__') end")
try:
    lua.execute(src)
except Exception as e:
    if "__exit__" not in str(e):
        print("EXC", e); sys.exit(2)
sys.exit(int(lua.globals().EXIT or 0))
