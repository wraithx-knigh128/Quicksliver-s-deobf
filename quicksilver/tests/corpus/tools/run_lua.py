"""Reference Lua runner used by the QuickSilver test-suite.

Runs *our own corpus samples* (and tool-generated obfuscations of them) on a
real Lua implementation (PUC Lua 5.1 / LuaJIT 2.1 / PUC Lua 5.4 through `lupa`)
so recovered code can be compared against the original by observable behaviour.

Safety properties:
  * a mock Roblox-style environment is provided, no real I/O libraries are:
    `io`, `os.execute`, `os.remove`, `os.rename`, `os.exit`, `os.getenv`,
    `package`, `require`, `dofile`, `loadfile` and `debug` are removed
    after the harness has installed its instruction-count hook;
  * every run is limited by an instruction budget (debug.sethook count hook);
  * prints are captured, never written to the real stdout.

Usage:
  python -I run_lua.py --runtime lua51 FILE.lua          # one file -> JSON on stdout
  python -I run_lua.py --serve                           # JSON-lines server on stdin/stdout
      request : {"id": 1, "runtime": "lua51", "code": "print(1)"}
      response: {"id": 1, "ok": true, "stdout": "1\n", "error": null}
"""
import json
import os
import sys

RUNTIMES = {"lua51": "lupa.lua51", "luajit": "lupa.luajit21", "lua54": "lupa.lua54", "lua54c": "lupa.lua54"}

# "lua54c" = Lua 5.4 + the math.ldexp / math.frexp polyfills that Hercules' own CLI installs
# (Lua 5.3+ dropped them unless built with LUA_COMPAT_MATHLIB). Some Hercules VM output needs them.
POLYFILL_54C = r'''
math.ldexp = function(x, n) return x * 2 ^ n end
math.frexp = function(x)
  if x == 0 then return 0, 0 end
  local exp = math.floor(math.log(math.abs(x)) / math.log(2)) + 1
  return x / 2 ^ exp, exp
end
'''

HARNESS = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "mock_env.lua"), "rb").read().decode("utf-8")

STRIP = r'''
io = nil; package = nil; require = nil; dofile = nil; loadfile = nil
if os then os.execute = nil; os.remove = nil; os.rename = nil; os.exit = nil; os.getenv = nil; os.tmpname = nil end
'''


RUNNER = b"""function(src, limit)
  local fn, err = (loadstring or load)(src, '=sample')
  if not fn then return false, 'syntax: ' .. tostring(err) end
  local ok, e = xpcall(function()
    debug.sethook(function() error('instruction budget exceeded', 0) end, '', limit)
    fn()
    QS_PUMP()
  end, function(m) return tostring(m) end)
  debug.sethook()
  return ok, (not ok) and e or nil
end"""


def _runtime(name):
    mod = __import__(RUNTIMES[name], fromlist=["LuaRuntime"])
    # encoding=None: Lua strings stay raw bytes in both directions (Lua strings are byte strings).
    return mod.LuaRuntime(encoding=None, register_eval=False, register_builtins=False, unpack_returned_tuples=True)


def run(code, runtime="lua51", budget=20_000_000):
    """`code` is a str whose code points are bytes (latin-1 view of the Lua source)."""
    rt = _runtime(runtime)
    try:
        rt.execute(HARNESS.encode("latin-1"))
        if runtime == "lua54c":
            rt.execute(POLYFILL_54C.encode("latin-1"))
        rt.execute(STRIP.encode("latin-1"))
        runner = rt.eval(RUNNER)
        ok, err = runner(code.encode("latin-1"), budget)
        out, n = rt.eval(b"QS_OUT"), rt.eval(b"QS_N")
        stdout = b"".join(out[i] for i in range(1, int(n) + 1)).decode("latin-1")
        return {"ok": bool(ok), "stdout": stdout,
                "error": None if ok else (err.decode("latin-1") if isinstance(err, bytes) else str(err))}
    except Exception as exc:  # harness-level failure
        return {"ok": False, "stdout": "", "error": "harness: " + repr(exc)}


def main(argv):
    if "--serve" in argv:
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            req = json.loads(line)
            res = run(req["code"], req.get("runtime", "lua51"), req.get("budget", 20_000_000))
            res["id"] = req.get("id")
            sys.stdout.write(json.dumps(res) + "\n")
            sys.stdout.flush()
        return 0
    runtime = "lua51"
    if "--runtime" in argv:
        runtime = argv[argv.index("--runtime") + 1]
    path = argv[-1]
    with open(path, "rb") as fh:
        code = fh.read().decode("latin-1")
    print(json.dumps(run(code, runtime)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
