"""Run a third-party pure-Lua tool inside a Lua state that has no way out.

Used to generate real output of open-source Lua obfuscators WITHOUT running their own command-line front ends (which read and write the
real file system, shell out, and in one case update themselves from the network).

What the tool's Lua code can reach:

  * a read-only virtual file set: only `.lua` / `.luau` / `.json` files under --root, read here and handed in as a table. `require`, `loadfile`,
    `dofile` and `io.open(path, "r")` are answered from it, nothing else;
  * `io.open(path, "w")` writes into memory; the files written are returned to the caller and never touch the disk;
  * stdout / stderr are captured;
  * `os.clock`, `os.time`, `os.date`, `os.difftime` only. No `os.execute`, `os.getenv`, `os.remove`, `os.rename`, `os.exit`, no `io.popen`,
    no `package.loadlib`, no `debug.sethook`, no Python bridge (lupa is started without `eval` and without Python builtins);
  * an instruction budget and a CPU-time limit.

A tool is driven by a small driver script of ours (tests/corpus/tools/drivers/*.lua) which gets the global INPUT (the program to protect, bytes)
and OPTIONS (a table) and returns the protected text. Nothing from the tool is ever executed outside this state.

  python -I run_isolated.py --root /path/to/checkout --driver drivers/zenfus.lua --input prog.lua --runtime lua54 [--opt key=value ...] [--budget N]
  -> JSON on stdout: {"ok": bool, "result": str (latin-1 view of the bytes), "stdout": str, "stderr": str, "writes": {path: str}, "error": str|null}
"""
import json
import os
import sys
import time

RUNTIMES = {"lua51": "lupa.lua51", "luajit": "lupa.luajit21", "lua54": "lupa.lua54"}
ALLOWED_SUFFIXES = (".lua", ".luau", ".json")
SKIP_DIRS = {".git", "node_modules", "vendor", "Output", "Temp", "Inputs", "tests", "benchmarks", "docs"}
MAX_FILE = 2_000_000
MAX_TOTAL = 24_000_000

HARNESS = rb'''
local files, writes, out, err = QS_FILES, {}, {}, {}
QS_WRITES, QS_STDOUT, QS_STDERR = writes, out, err
local CAP = 8 * 1024 * 1024

local function norm(p)
  p = tostring(p):gsub("\\", "/")
  p = p:gsub("/+", "/")
  local parts = {}
  for seg in p:gmatch("[^/]+") do
    if seg == ".." then if #parts > 0 then parts[#parts] = nil end
    elseif seg ~= "." then parts[#parts + 1] = seg end
  end
  return table.concat(parts, "/")
end

local function emit(sink, ...)
  for i = 1, select("#", ...) do
    local s = tostring((select(i, ...)))
    sink.n = (sink.n or 0) + #s
    if sink.n <= CAP then sink[#sink + 1] = s end
  end
end

local function reader(data)
  local pos = 1
  local h = {}
  local function one(fmt)
    if type(fmt) == "number" then
      if pos > #data then return nil end
      local s = data:sub(pos, pos + fmt - 1)
      pos = pos + #s
      return s
    end
    fmt = tostring(fmt):gsub("^%*", ""):sub(1, 1)
    if fmt == "a" then local s = data:sub(pos); pos = #data + 1; return s end
    if fmt == "l" or fmt == "L" then
      if pos > #data then return nil end
      local e = data:find("\n", pos, true)
      local s = data:sub(pos, (e and (fmt == "L" and e or e - 1)) or #data)
      pos = (e or #data) + 1
      return s
    end
    if fmt == "n" then
      local s = data:match("^%s*([%+%-]?%d+%.?%d*)", pos)
      if not s then return nil end
      pos = pos + #data:match("^%s*[%+%-]?%d+%.?%d*", pos)
      return tonumber(s)
    end
    error("bad argument #1 to 'read' (invalid format)", 2)
  end
  function h:read(...)
    local n = select("#", ...)
    if n == 0 then return one("l") end
    local res = {}
    for i = 1, n do res[i] = one((select(i, ...))) end
    return table.unpack and table.unpack(res, 1, n) or unpack(res, 1, n)
  end
  function h:lines() return function() return one("l") end end
  function h:seek(whence, off)
    whence, off = whence or "cur", off or 0
    if whence == "set" then pos = off + 1 elseif whence == "cur" then pos = pos + off else pos = #data + off + 1 end
    return pos - 1
  end
  function h:close() return true end
  function h:flush() return h end
  function h:setvbuf() return true end
  function h:write() return nil, "file not open for writing" end
  return h
end

local function writer(path)
  local buf, closed = {}, false
  local h = {}
  function h:write(...)
    for i = 1, select("#", ...) do buf[#buf + 1] = tostring((select(i, ...))) end
    return h
  end
  function h:close() if not closed then closed = true; writes[path] = table.concat(buf) end return true end
  function h:flush() return h end
  function h:setvbuf() return true end
  function h:seek() return 0 end
  function h:read() return nil, "file not open for reading" end
  h.__gc = h.close
  return h
end

local virtual_io = {}
function virtual_io.open(path, mode)
  path, mode = norm(path), mode or "r"
  if mode:find("[wa]") then return writer(path) end
  local data = writes[path] or files[path]
  if data == nil then return nil, path .. ": No such file or directory", 2 end
  return reader(data)
end
function virtual_io.lines(path)
  local h, why = virtual_io.open(path, "r")
  if not h then error(why, 2) end
  return h:lines()
end
function virtual_io.write(...) emit(out, ...) return virtual_io end
function virtual_io.read() return nil end
virtual_io.stdout = { write = function(self, ...) emit(out, ...) return self end, flush = function(self) return self end, setvbuf = function() return true end, close = function() return true end }
virtual_io.stderr = { write = function(self, ...) emit(err, ...) return self end, flush = function(self) return self end, setvbuf = function() return true end, close = function() return true end }
virtual_io.stdin = reader("")
function virtual_io.type(x) return type(x) == "table" and "file" or nil end
local print_real = print
print = function(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
  emit(out, table.concat(t, "\t"), "\n")
end
io = virtual_io

local clock, time, date, difftime = os.clock, os.time, os.date, os.difftime
os = { clock = clock, time = time, date = date, difftime = difftime }
function os.getenv() return nil end
function os.exit(code) error("os.exit(" .. tostring(code) .. ") called by the tool", 0) end
function os.execute() return nil, "exit", 1 end
os.remove = function() return nil, "not permitted" end
os.rename = os.remove
os.tmpname = function() return "/virtual/tmp" end
io.popen = nil

local loaded = {}
local function find(name)
  local base = tostring(name):gsub("%.", "/")
  -- the templates a tool puts in package.path, resolved against the virtual file set only
  for template in tostring(package.path):gmatch("[^;]+") do
    local p = norm((template:gsub("%?", (base:gsub("%%", "%%%%")))))
    if files[p] ~= nil then return p end
  end
  for _, p in ipairs({ base .. ".lua", base .. "/init.lua", base .. ".luau" }) do
    if files[p] ~= nil then return p end
  end
end
package = {
  loaded = loaded, preload = {}, path = "./?.lua;./?/init.lua", cpath = "", config = "/\n;\n?\n!\n-",
  searchers = {},
}
loaded._G = _G
loaded.string, loaded.table, loaded.math, loaded.os, loaded.io, loaded.coroutine = string, table, math, os, io, coroutine
if utf8 then loaded.utf8 = utf8 end
if bit32 then loaded.bit32 = bit32 end
if bit then loaded.bit = bit end
local compile = loadstring or load
function require(name)
  if loaded[name] ~= nil then return loaded[name] end
  if package.preload[name] then
    local v = package.preload[name](name)
    loaded[name] = v == nil and true or v
    return loaded[name]
  end
  local path = find(name)
  if not path then error("module '" .. tostring(name) .. "' not found in the virtual file set", 2) end
  local chunk, why
  if _VERSION == "Lua 5.1" then chunk, why = compile(files[path], "@" .. path) else chunk, why = load(files[path], "@" .. path, "t") end
  if not chunk then error(why, 2) end
  loaded[name] = true -- guards against cycles
  local v = chunk(name, path)
  if v ~= nil then loaded[name] = v end
  return loaded[name]
end
function loadfile(path)
  path = norm(path)
  if files[path] == nil then return nil, path .. ": cannot open file" end
  return compile(files[path], "@" .. path)
end
function dofile(path)
  local f, why = loadfile(path)
  if not f then error(why, 2) end
  return f()
end

package.loadlib = nil

-- the budget: instructions (counted in steps of one million) and CPU seconds
local deadline = os.clock() + QS_SECONDS
local count_left = QS_BUDGET
local tick = 1000000
debug.sethook(function()
  count_left = count_left - tick
  if count_left <= 0 then error("instruction budget exceeded", 0) end
  if os.clock() > deadline then error("CPU time limit exceeded", 0) end
end, "", tick)
local clear = debug.sethook
local real_getinfo = debug.getinfo
-- only where a chunk was loaded from (tools find their own directory this way) and which line: no functions, locals, upvalues or hooks
local function getinfo(level, what)
  local i = real_getinfo(type(level) == "number" and level + 1 or level, "Sl")
  if not i then return nil end
  return { source = i.source, short_src = i.short_src, currentline = i.currentline, linedefined = i.linedefined, what = i.what }
end
debug = { traceback = function(m) return tostring(m) end, getinfo = getinfo, gethook = function() return nil end }
QS_CLEAR_HOOK = function() clear() end
'''

RUNNER = rb'''function(driver)
  local fn, e = (loadstring or load)(driver, "=driver")
  if not fn then return false, "driver: " .. tostring(e) end
  local ok, res = xpcall(fn, function(m) return tostring(m) end)
  QS_CLEAR_HOOK()
  return ok, res
end'''


def collect(root):
    files, total = {}, 0
    root = os.path.abspath(root)
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if not name.endswith(ALLOWED_SUFFIXES):
                continue
            full = os.path.join(dirpath, name)
            if os.path.islink(full):
                continue
            size = os.path.getsize(full)
            if size > MAX_FILE or total + size > MAX_TOTAL:
                continue
            with open(full, "rb") as fh:
                files[os.path.relpath(full, root).replace(os.sep, "/")] = fh.read()
            total += size
    return files


def run(root, driver_path, program, runtime="lua54", options=None, budget=4_000_000_000, seconds=240):
    mod = __import__(RUNTIMES[runtime], fromlist=["LuaRuntime"])
    rt = mod.LuaRuntime(encoding=None, register_eval=False, register_builtins=False, unpack_returned_tuples=True)
    files = collect(root)
    g = rt.globals()
    g.QS_FILES = rt.table_from({k.encode(): v for k, v in files.items()})
    g.QS_BUDGET = budget
    g.QS_SECONDS = seconds
    with open(driver_path, "rb") as fh:
        driver = fh.read()
    t0 = time.time()
    try:
        rt.execute(HARNESS)
        g.INPUT = program
        g.OPTIONS = rt.table_from({k.encode(): (v.encode() if isinstance(v, str) else v) for k, v in (options or {}).items()})
        ok, res = rt.eval(RUNNER)(driver)
        out = b"".join(rt.eval(b"QS_STDOUT")[i] for i in range(1, len(rt.eval(b"QS_STDOUT")) + 1))
        err = b"".join(rt.eval(b"QS_STDERR")[i] for i in range(1, len(rt.eval(b"QS_STDERR")) + 1))
        writes = rt.eval(b"QS_WRITES")
        wr = {k.decode("latin-1"): writes[k].decode("latin-1") for k in writes.keys()}
        return {
            "ok": bool(ok),
            "result": res.decode("latin-1") if ok and isinstance(res, bytes) else None,
            "stdout": out.decode("latin-1"), "stderr": err.decode("latin-1"), "writes": wr,
            "error": None if ok else (res.decode("latin-1") if isinstance(res, bytes) else str(res)),
            "seconds": round(time.time() - t0, 2), "files": len(files),
        }
    except Exception as exc:  # harness-level failure
        return {"ok": False, "result": None, "stdout": "", "stderr": "", "writes": {}, "error": "harness: " + repr(exc), "seconds": round(time.time() - t0, 2), "files": len(files)}


def main(argv):
    def arg(name, default=None):
        return argv[argv.index(name) + 1] if name in argv else default
    root, driver, inp = arg("--root"), arg("--driver"), arg("--input")
    if not (root and driver and inp):
        sys.stderr.write(__doc__)
        return 2
    options = {}
    for i, a in enumerate(argv):
        if a == "--opt":
            k, _, v = argv[i + 1].partition("=")
            options[k] = int(v) if v.lstrip("-").isdigit() else (True if v == "true" else False if v == "false" else v)
    with open(inp, "rb") as fh:
        program = fh.read()
    res = run(root, driver, program, arg("--runtime", "lua54"), options, int(arg("--budget", 4_000_000_000)), int(arg("--seconds", 240)))
    print(json.dumps(res))
    return 0 if res["ok"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
