"""Runs run_tests.lua with lupa when no `lua` binary is installed.
Usage (from game_dev/):  python3 tests/run_tests.py     (pip install lupa)"""
import sys
from lupa import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
local real_exit = os.exit
os.exit = function(code) EXIT_CODE = code end
""")
lua.execute(open("tests/run_tests.lua").read())
sys.exit(int(lua.globals().EXIT_CODE or 0))
