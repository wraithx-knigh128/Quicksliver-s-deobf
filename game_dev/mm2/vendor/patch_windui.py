"""The vendored WindUI release (windui.lua, MIT, (c) Footages) is embedded UNCHANGED apart from the three exact-string patches below.
They are applied when the hub is built (build_mm2.py) and when the tests load the library; every patch must match exactly once, so a new
WindUI release that changes these lines fails loudly instead of being half-patched.

Why: outside Roblox Studio the library fetches its icon packs over HTTP when it loads. If that fails (no HttpGet, github blocked, a changed URL) it
throws, and its built-in fallback (module b) waits forever for a server remote called "GetIcons" - which an executor game never has. With these
patches a failed download leaves the menu working with blank icons instead of hanging or crashing."""
PATCHES = [
    # 1. module b (the Studio icon module) must not wait for a server remote that does not exist
    ('local d=b(game:GetService"ReplicatedStorage":WaitForChild("GetIcons",99999):InvokeServer())',
     'local d={Icons={}}'),
    # 2. ...and it returns a blank icon for anything that looks like an icon name (the window asks for "x", "expand", "search" ... by name)
    ('''return nil
end

function d.GetIcon(f,g)''',
     '''if type(f)=="string"and not f:find"^rbx"and not f:find"^http"and tostring(m):match"^[%a][%w%-_]*$"then
return{"",{ImageRectSize=Vector2.new(0,0),ImageRectPosition=Vector2.new(0,0)}}
end
return nil
end

function d.GetIcon(f,g)'''),
    # 3. a failed icon download falls back to module b instead of throwing
    ('''m=loadstring(
game.HttpGet and game:HttpGet(l)or h:GetAsync(l)
)()''',
     '''do
local okI,iconSet=pcall(function()
return loadstring(game.HttpGet and game:HttpGet(l)or h:GetAsync(l))()
end)
m=okI and type(iconSet)=="table"and iconSet or a.load'b'
end'''),
]

def apply(src):
    for old, new in PATCHES:
        n = src.count(old)
        if n != 1:
            raise SystemExit("WindUI patch does not match exactly once (%d matches): %r" % (n, old[:60]))
        src = src.replace(old, new)
    return src
