#!/usr/bin/env python3
# Local stand-in for the luajit command line: run a script file with an arg table.
import sys
from lupa.luajit21 import LuaRuntime
script = sys.argv[1]
lua = LuaRuntime(encoding=None, unpack_returned_tuples=True)
argt = lua.table_from({0: script.encode()})
for n, a in enumerate(sys.argv[2:], 1): argt[n] = a.encode()
lua.globals()['arg'] = argt
code = open(script, 'rb').read()
fn = lua.eval('function(src, name, ...) local f, err = loadstring(src, name) if not f then error(err) end return f(...) end')
try:
    fn(code, b'@' + script.encode(), *[a.encode() for a in sys.argv[2:]])
except Exception as e:
    sys.stderr.write(str(e) + '\n'); sys.exit(1)
