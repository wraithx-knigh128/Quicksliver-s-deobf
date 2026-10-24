#!/usr/bin/env python3
# Local stand-in for PUC Lua 5.1's luac: compile a file to a bytecode chunk (debug info kept), report syntax errors on stderr.
import sys
from lupa.lua51 import LuaRuntime
args = sys.argv[1:]
out = 'luac.out'
files = []
i = 0
while i < len(args):
    a = args[i]
    if a == '-o': out = args[i + 1]; i += 2; continue
    if a in ('-s', '-p', '-l', '-v', '--'): i += 1; continue
    files.append(a); i += 1
lua = LuaRuntime(encoding=None, unpack_returned_tuples=True)
dump = lua.eval('function(src, name) local f, err = loadstring(src, name) if not f then return nil, err end return string.dump(f) end')
src = open(files[0], 'rb').read()
res = dump(src, b'@' + files[0].encode())
if isinstance(res, tuple) and res[0] is None:
    sys.stderr.write('luac: ' + res[1].decode('latin1') + '\n'); sys.exit(1)
open(out, 'wb').write(res)
