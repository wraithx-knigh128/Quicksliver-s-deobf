"""Run one Lua file on a reference runtime WITHOUT the instruction-count hook, for outputs whose anti-tamper treats a debug hook as an attack.

Colisseum's `total` and `fortress` presets abort when they see a hook, which is exactly what run_lua.py uses to bound a run. This runner is the same
environment (mock Roblox surface, io / os.execute / package / require / dofile / loadfile removed, no Python bridge) minus the hook, so it has no
budget: the caller must run it in a subprocess with a timeout (verify_fixtures.py --nohook does).

  python -I run_lua_nohook.py FILE.lua --runtime luajit   -> JSON {"ok", "stdout", "error"}
"""
import importlib.util
import json
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("run_lua", os.path.join(here, "run_lua.py"))
run_lua = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run_lua)

RUNNER = b"""function(src)
  local fn, err = (loadstring or load)(src, '=sample')
  if not fn then return false, 'syntax: ' .. tostring(err) end
  local ok, e = pcall(fn)
  if ok then ok, e = pcall(QS_PUMP) end
  return ok, (not ok) and tostring(e) or nil
end"""


def main(argv):
    runtime = argv[argv.index("--runtime") + 1] if "--runtime" in argv else "lua51"
    with open(argv[0], "rb") as fh:
        code = fh.read()
    rt = run_lua._runtime(runtime)
    rt.execute(run_lua.HARNESS.encode("latin-1"))
    rt.execute(run_lua.STRIP.encode("latin-1"))
    ok, err = rt.eval(RUNNER)(code)
    out, n = rt.eval(b"QS_OUT"), rt.eval(b"QS_N")
    stdout = b"".join(out[i] for i in range(1, int(n) + 1)).decode("latin-1")
    print(json.dumps({"ok": bool(ok), "stdout": stdout, "error": None if ok else (err.decode("latin-1") if isinstance(err, bytes) else str(err))}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
