"""Bundle Wraith's TSB Lab into ONE executor script (they cannot require local files).
Usage (repo root):  python3 game_dev/tsb/build_tsb_lab.py   ->  dist/tsb_lab.lua, dist/tsb_lab.txt, dist/tsb_lab.min.txt
The window library is the vendored WindUI (MIT) exactly as the MM2 hub embeds it (game_dev/mm2/vendor, three small patches); the floating buttons and the
Wraith UI core come from game_dev/mm2/ui_lib.lua, the WindUI adapter from game_dev/mm2/windui_ui.lua."""
import os, re, sys
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(here, ".."))
from bundle_util import strip_comments
root = os.path.dirname(os.path.dirname(here))
rd = lambda p: open(os.path.join(root, p), encoding="utf-8").read()

def as_module(name, src):
    src = re.sub(r"--\[\[.*?\]\]", "", src, count=1, flags=re.S)   # drop header comment
    return f"local {name} = (function()\n{src}\nend)()\n"

sys.path.insert(0, os.path.join(root, "game_dev", "mm2", "vendor"))
import patch_windui

def windui_loader():
    src = patch_windui.apply(rd("game_dev/mm2/vendor/windui.lua"))
    assert "]====]" not in src
    lic = rd("game_dev/mm2/vendor/WINDUI_LICENSE").strip().splitlines()
    head = "-- WindUI by Footagesus (https://github.com/Footagesus/WindUI), MIT License. " + lic[2].strip() + ". Unchanged apart from three small patches (mm2/vendor/patch_windui.py).\n"
    return head + "local WindUILoader = function()\n" + src + "\nend\n"

hub = rd("game_dev/tsb/lab_hub.lua")
marker = "-- @@MODULES@@"
assert hub.count(marker) == 1
PLACEHOLDER = "local __WINDUI_HERE__ = nil\n"
modules = (as_module("PingModel", rd("game_dev/ping_model.lua")) + as_module("TechMath", rd("game_dev/tech_math.lua")) + as_module("TechData", rd("game_dev/tech_data.lua"))
           + as_module("TechOptions", rd("game_dev/tech_options.lua")) + as_module("TechLab", rd("game_dev/tech_lab.lua"))
           + as_module("UILib", rd("game_dev/mm2/ui_lib.lua")) + as_module("WindAdapter", rd("game_dev/mm2/windui_ui.lua")) + PLACEHOLDER)
template = hub.replace(marker, modules)
windui = windui_loader()
out = template.replace(PLACEHOLDER, windui)
assert not re.search(r"[^\x00-\x7F]", out), "non-ASCII character in bundle"
os.makedirs(os.path.join(root, "dist"), exist_ok=True)
for name in ("tsb_lab.lua", "tsb_lab.txt"):
    open(os.path.join(root, "dist", name), "w", encoding="ascii").write(out)
mini = strip_comments(template).replace(PLACEHOLDER, windui)      # only OUR code is minified; WindUI is inserted untouched
open(os.path.join(root, "dist", "tsb_lab.min.txt"), "w", encoding="ascii").write(mini)
print("dist/tsb_lab.lua", len(out.splitlines()), "lines;", "min:", len(mini.splitlines()), "lines,", len(mini), "bytes")
