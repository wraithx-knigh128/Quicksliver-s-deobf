#!/bin/sh
# Install the reference Lua runtimes for runtime verification (PUC Lua 5.1-5.4 and LuaJIT 2.1, through `lupa`) into quicksilver/.runtime.
# Needs Python 3 and access to PyPI. Nothing is installed outside this folder.
#
#   sh tools/runtime/setup.sh
#   QS_LUA_PYTHON=$PWD/.runtime/venv/bin/python npm test        # the behavioural tests and the lab's reference oracle then run
#
# Luau (Roblox's dialect) is NOT installed by this script: it has to be built from source (https://github.com/Roblox/luau, `make config=release luau`)
# and its binary named in QS_LUAU_BIN. Until then the oracle reports Luau as unavailable and nothing is verified for Luau-only syntax.
set -e
cd "$(dirname "$0")/../.."
python3 -m venv .runtime/venv
.runtime/venv/bin/pip install --quiet --upgrade lupa
.runtime/venv/bin/python - <<'PY'
import importlib
for m in ("lupa.lua51", "lupa.lua52", "lupa.lua53", "lupa.lua54", "lupa.luajit21"):
    print(m, importlib.import_module(m).LuaRuntime().eval("_VERSION"))
PY
