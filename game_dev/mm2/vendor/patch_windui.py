"""The vendored WindUI release (windui.lua, MIT, (c) Footages) is embedded UNCHANGED apart from the three exact-string patches below.
They are applied when the hub is built (build_mm2.py) and when the tests load the library; every patch must match exactly once, so a new
WindUI release that changes these lines fails loudly instead of being half-patched.

Why: outside Roblox Studio the library fetches six icon packs over HTTP when it loads (several seconds and a big compile on a phone, and a hard
failure if a download fails); its built-in fallback (module b) waits forever for a server remote called "GetIcons", which an executor game never
has. With these patches the library always uses module b with a small built-in set of Lucide icons (lucide_subset.json: icon name -> Roblox asset
id, as published by Footagesus/Icons), so nothing is downloaded; any other icon name simply draws blank instead of failing."""
import json, os

_SUBSET = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "lucide_subset.json")))
_LUA_SUBSET = "{" + ",".join('["%s"]="%s"' % (k, v) for k, v in sorted(_SUBSET.items())) + "}"

PATCHES = [
    # 1. module b (the Studio icon module): start with the built-in icons instead of asking a server remote that does not exist
    ('local d=b(game:GetService"ReplicatedStorage":WaitForChild("GetIcons",99999):InvokeServer())',
     'local d={Icons={lucide=' + _LUA_SUBSET + '}}'),
    # 2. ...and it returns a blank icon for any other name that looks like an icon name
    ('''return nil
end

function d.GetIcon(f,g)''',
     '''if type(f)=="string"and not f:find"^rbx"and not f:find"^http"and tostring(m):match"^[%a][%w%-_]*$"then
return{"",{ImageRectSize=Vector2.new(0,0),ImageRectPosition=Vector2.new(0,0)}}
end
return nil
end

function d.GetIcon(f,g)'''),
    # 3. no icon download: module b (with the built-in set) is always the icon module
    ('''m=loadstring(
game.HttpGet and game:HttpGet(l)or h:GetAsync(l)
)()''',
     "m=a.load'b'"),
]


def apply(src):
    for old, new in PATCHES:
        n = src.count(old)
        if n != 1:
            raise SystemExit("WindUI patch does not match exactly once (%d matches): %r" % (n, old[:60]))
        src = src.replace(old, new)
    return src
