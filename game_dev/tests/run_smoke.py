"""Runs tests/smoke_ui.lua via lupa. From game_dev/: python3 tests/run_smoke.py"""
import sys
from lupa import LuaRuntime
lua = LuaRuntime()
lua.execute("os.exit = function(c) EXIT = c; error('__exit__') end")
if len(sys.argv) > 1:
    lua.globals().SCRIPT_PATH = sys.argv[1]
lua.globals().PROP_TYPES_SOURCE = open("tests/prop_types.lua", encoding="utf-8").read()   # real Roblox property types (tools/gen_prop_types.py)
try:
    lua.execute(open("tests/smoke_ui.lua").read())
except Exception as e:
    if "__exit__" not in str(e):
        print("EXC", e); sys.exit(2)
sys.exit(int(lua.globals().EXIT or 0))
