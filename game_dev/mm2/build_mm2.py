"""Bundle the MM2 hub into ONE executor script (they cannot require local files).
Usage (repo root):  python3 game_dev/mm2/build_mm2.py   ->  dist/wraiths_hub.lua, dist/wraiths_hub.txt, dist/wraiths_hub.min.txt"""
import os, re, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from bundle_util import strip_comments
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
rd = lambda p: open(os.path.join(root, p), encoding="utf-8").read()

def as_module(name, src):
    src = re.sub(r"--\[\[.*?\]\]", "", src, count=1, flags=re.S)   # drop header comment
    return f"local {name} = (function()\n{src}\nend)()\n"

sys.path.insert(0, os.path.join(root, "game_dev", "mm2", "vendor"))
import patch_windui                                                  # the three exact-string patches applied to the vendored WindUI release

def windui_loader():
    """WindUI (MIT, (c) Footages) is embedded as a function that the hub only calls when it wants the WindUI menu, inside a protected call: if the library
    fails to start the hub falls back to the classic menu instead of dying. The text is NOT minified (it is third-party code and keeps its licence header)."""
    src = patch_windui.apply(rd("game_dev/mm2/vendor/windui.lua"))
    assert "]====]" not in src
    lic = rd("game_dev/mm2/vendor/WINDUI_LICENSE").strip().splitlines()
    head = "-- WindUI by Footagesus (https://github.com/Footagesus/WindUI), MIT License. " + lic[2].strip() + ". Unchanged apart from three small patches (vendor/patch_windui.py).\n"
    return head + "local WindUILoader = function()\n" + src + "\nend\n"

hub = rd("game_dev/mm2/wraiths_hub.lua")
marker = "-- @@MODULES@@"
assert hub.count(marker) == 1
PLACEHOLDER = "local __WINDUI_HERE__ = nil\n"
template = hub.replace(marker, as_module("Logic", rd("game_dev/mm2/logic.lua")) + as_module("UILib", rd("game_dev/mm2/ui_lib.lua")) + as_module("WindAdapter", rd("game_dev/mm2/windui_ui.lua")) + PLACEHOLDER)
windui = windui_loader()
out = template.replace(PLACEHOLDER, windui)
assert not re.search(r"[^\x00-\x7F]", out), "non-ASCII character in bundle"
os.makedirs(os.path.join(root, "dist"), exist_ok=True)
for name in ("wraiths_hub.lua", "wraiths_hub.txt"):
    open(os.path.join(root, "dist", name), "w", encoding="ascii").write(out)
mini = strip_comments(template).replace(PLACEHOLDER, windui)      # only OUR code is minified; WindUI is inserted untouched
open(os.path.join(root, "dist", "wraiths_hub.min.txt"), "w", encoding="ascii").write(mini)
print("dist/wraiths_hub.lua", len(out.splitlines()), "lines;", "min:", len(mini.splitlines()), "lines,", len(mini), "bytes")
