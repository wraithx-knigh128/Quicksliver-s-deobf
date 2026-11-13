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

# lua52 is here for its bit32, which Luau scripts (Clyde's output, for one) expect and Lua 5.1 / LuaJIT / 5.4 do not have
RUNTIMES = {"luau": None, "lua51": "lupa.lua51", "lua51b": "lupa.lua51", "lua52": "lupa.lua52", "lua53": "lupa.lua53", "luajit": "lupa.luajit21", "lua54": "lupa.lua54", "lua54c": "lupa.lua54"}

# "lua51b" = Lua 5.1 + a pure-Lua bit32 (Roblox's Lua 5.1 dialect has one; plain 5.1 does not). Output of tools that ask for `bit or bit32` needs it.
POLYFILL_51B = r'''
if not bit32 then
  local M = 4294967296
  local function bw(op, a, b)
    a, b = a % M, b % M
    local r, p = 0, 1
    for _ = 1, 32 do
      local x, y = a % 2, b % 2
      if op(x, y) then r = r + p end
      a, b, p = (a - x) / 2, (b - y) / 2, p * 2
    end
    return r
  end
  local function fold(op, ...)
    local t = { ... }
    local r = t[1] or 0
    for i = 2, #t do r = bw(op, r, t[i]) end
    return r
  end
  bit32 = {
    bxor = function(...) return fold(function(x, y) return x ~= y end, ...) end,
    band = function(...) return fold(function(x, y) return x == 1 and y == 1 end, ...) end,
    bor = function(...) return fold(function(x, y) return x == 1 or y == 1 end, ...) end,
    bnot = function(x) return M - 1 - (x % M) end,
    lshift = function(x, n) if n < 0 or n >= 32 then return 0 end return ((x % M) * 2 ^ n) % M end,
    rshift = function(x, n) if n < 0 or n >= 32 then return 0 end return math.floor((x % M) / 2 ^ n) end,
  }
end
'''

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
io = nil; package = nil; require = nil
if os then os.execute = nil; os.remove = nil; os.rename = nil; os.getenv = nil; os.tmpname = nil end
-- Present but inert: an integrity check that only asks whether `os.exit`, `dofile` or `loadfile` are functions (Hercules' anti-tamper block does) must find them, while a call can do nothing.
local function disabled(name) return function() error(name .. ' is disabled in the isolated runner', 2) end end
dofile = disabled('dofile'); loadfile = disabled('loadfile')
if os then os.exit = disabled('os.exit') end
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


LUAU_BIN = os.environ.get("QS_LUAU_BIN") or os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "api", "_engine", "luraph", "deobf", "bin", "luau"))


def to_bytes(text):
    """The bytes of a source text. A binary string (every code point below 256) is its own bytes; a text that holds real Unicode (a recovered
    file whose report comment says "doesn\u2019t") is what the file would hold when saved, which is UTF-8. Never an exception: the oracle is a
    long-lived server and one such file must not take the later requests down with it."""
    try:
        return text.encode("latin-1")
    except UnicodeEncodeError:
        return text.encode("utf-8", "replace")


def run_luau(code, budget=0):
    """Luau (Roblox's dialect) through the vendored standalone `luau` binary: the same mock environment and print capture as the lupa runtimes, the script loaded with
    loadstring so that its own `return`, `...` and local count are its own. Wall-clock limited; the binary is run without a network namespace only where the host allows it."""
    import subprocess, tempfile
    if not os.path.exists(LUAU_BIN):
        return {"ok": False, "stdout": "", "error": "harness: no luau binary at " + LUAU_BIN}
    def quote(text):
        level = 0
        while ("]" + "=" * level + "]") in text:
            level += 1
        q = "=" * level
        return "[" + q + "[\n" + text + "]" + q + "]"
    mock = HARNESS.replace("\r\n", "\n")
    strip = ""
    # Luau's standalone binary freezes the globals: the mock environment and the script run in a table of their own that falls back to the real ones
    prog = ("local __rawprint = print\nlocal __real = getfenv()\nlocal __blocked = { io = true, package = true, require = true, dofile = true, loadfile = true, debug = true, getfenv = true, setfenv = true }\n"
            "local __os = { clock = os.clock, time = os.time, date = os.date, difftime = os.difftime }\n"
            "local __env = setmetatable({ os = __os }, { __index = function(_, k) if __blocked[k] then return nil end return __real[k] end })\n__env._G = __env\n"
            "local __h = loadstring(" + quote(mock + "\n" + strip) + ", '=mock')\nsetfenv(__h, __env)\n__h()\n"
            "local __f, __e = loadstring(" + quote(code) + ", '=sample')\n"
            "if not __f then __rawprint('QSERR syntax: ' .. tostring(__e)) return end\nsetfenv(__f, __env)\n"
            "local __ok, __err = xpcall(function() __f() __env.QS_PUMP() end, function(m) return tostring(m) end)\n"
            "__rawprint(table.concat(__env.QS_OUT))\nif not __ok then __rawprint('QSERR ' .. tostring(__err)) end\n")
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "run.lua")
        with open(path, "wb") as fh:
            fh.write(to_bytes(prog))
        try:
            p = subprocess.run([LUAU_BIN, path], capture_output=True, timeout=int(os.environ.get("QS_LUAU_TIMEOUT", "60")))
        except subprocess.TimeoutExpired:
            return {"ok": False, "stdout": "", "error": "no result after the time limit"}
    out = p.stdout.decode("latin-1")
    err = None
    i = out.rfind("QSERR ")
    if i >= 0 and (i == 0 or out[i - 1] == "\n"):
        err = out[i + 6:].strip()
        out = out[:i]
    if out.endswith("\n\n"):
        out = out[:-1]                      # the captured text ends in a newline and the binary's own print added another
    elif out == "\n":
        out = ""
    if p.returncode != 0 and err is None:
        err = p.stderr.decode("latin-1")[-300:] or "exit %d" % p.returncode
    return {"ok": err is None, "stdout": out, "error": err}


def _runtime(name):
    mod = __import__(RUNTIMES[name], fromlist=["LuaRuntime"])
    # encoding=None: Lua strings stay raw bytes in both directions (Lua strings are byte strings).
    return mod.LuaRuntime(encoding=None, register_eval=False, register_builtins=False, unpack_returned_tuples=True)


def run(code, runtime="lua51", budget=20_000_000):
    """`code` is a str whose code points are bytes (latin-1 view of the Lua source)."""
    if runtime == "luau":
        return run_luau(code, budget)
    rt = _runtime(runtime)
    try:
        rt.execute(HARNESS.encode("latin-1"))
        if runtime == "lua54c":
            rt.execute(POLYFILL_54C.encode("latin-1"))
        if runtime == "lua51b":
            rt.execute(POLYFILL_51B.encode("latin-1"))
        rt.execute(STRIP.encode("latin-1"))
        runner = rt.eval(RUNNER)
        ok, err = runner(to_bytes(code), budget)
        out, n = rt.eval(b"QS_OUT"), rt.eval(b"QS_N")
        stdout = b"".join(out[i] for i in range(1, int(n) + 1)).decode("latin-1")
        return {"ok": bool(ok), "stdout": stdout,
                "error": None if ok else (err.decode("latin-1") if isinstance(err, bytes) else str(err))}
    except Exception as exc:  # harness-level failure
        return {"ok": False, "stdout": "", "error": "harness: " + repr(exc)}


def limit_memory():
    """Cap the address space (QS_ORACLE_MEM_MB, default 3072). A Lua string.rep or table that tries to eat the machine dies with a memory error
    inside the run instead; the instruction budget cannot see C-level allocation."""
    try:
        import resource
        mb = int(os.environ.get("QS_ORACLE_MEM_MB", "3072"))
        if mb > 0:
            resource.setrlimit(resource.RLIMIT_AS, (mb << 20, mb << 20))
    except Exception:
        pass  # a platform without RLIMIT_AS: the caller's wall-clock kill is the remaining guard


def main(argv):
    limit_memory()
    if "--serve" in argv:
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            req = json.loads(line)
            try:
                res = run(req["code"], req.get("runtime", "lua51"), req.get("budget", 20_000_000))
            except Exception as exc:  # a request that breaks the harness is answered, not fatal to the server
                res = {"ok": False, "stdout": "", "error": "harness: " + repr(exc)[:300]}
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
