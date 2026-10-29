"""Bundle everything into ONE file for executors (they cannot require local files).
Usage (repo root):  python3 game_dev/build_executor.py   ->  dist/tsb_hub_executor.lua, .txt, .min.txt
The menu is WindUI (the vendored MIT library, exactly as the other hubs embed it: game_dev/mm2/vendor, three small patches) behind game_dev/classic_wind.lua, with the
built-in menu of tsb_animation_hub.lua as the fallback. Only our own code is minified: WindUI is inserted untouched."""
import os, re, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rd = lambda p: open(os.path.join(root, p), encoding="utf-8").read()
sys.path.insert(0, os.path.join(root, "game_dev", "mm2", "vendor"))
import patch_windui

def windui_loader():
    src = patch_windui.apply(rd("game_dev/mm2/vendor/windui.lua"))
    assert "]====]" not in src
    lic = rd("game_dev/mm2/vendor/WINDUI_LICENSE").strip().splitlines()
    head = "-- WindUI by Footagesus (https://github.com/Footagesus/WindUI), MIT License. " + lic[2].strip() + ". Unchanged apart from three small patches (mm2/vendor/patch_windui.py).\n"
    return head + "local WindUILoader = function()\n" + src + "\nend\n"

def as_module(name, src):
    src = re.sub(r"--\[\[.*?\]\]", "", src, count=1, flags=re.S)   # drop header comment
    return f"local {name} = (function()\n{src}\nend)()\n"

PLACEHOLDER = "local __WINDUI_HERE__ = nil\n"
ui = rd("tsb_animation_hub.lua")
marker = "if not game:IsLoaded()"
i = ui.index(marker)
out = (ui[:i]
       + as_module("DragTracker", rd("game_dev/drag_tracker.lua"))
       + as_module("PingModel", rd("game_dev/ping_model.lua"))
       + as_module("ComboOptions", rd("game_dev/combo_options.lua"))
       + as_module("Assist", rd("game_dev/assist.lua"))
       + as_module("CombatMath", rd("game_dev/combat_math.lua"))
       + as_module("BlockState", rd("game_dev/block_state.lua"))
       + as_module("BlockPredict", rd("game_dev/block_predict.lua"))
       + as_module("BlockInfo", rd("game_dev/block_info.lua"))
       + as_module("KyotoPlan", rd("game_dev/kyoto_plan.lua"))
       + as_module("BlockSense", rd("game_dev/block_sense.lua"))
       + as_module("TechMath", rd("game_dev/tech_math.lua"))
       + as_module("TechData", rd("game_dev/tech_data.lua"))
       + as_module("TechOptions", rd("game_dev/tech_options.lua"))
       + as_module("TechLab", rd("game_dev/tech_lab.lua"))
       + as_module("Data", rd("game_dev/tsb_data.lua"))
       + as_module("Engine", rd("game_dev/combo_engine.lua"))
       + as_module("UILib", rd("game_dev/mm2/ui_lib.lua"))
       + as_module("WindAdapter", rd("game_dev/mm2/windui_ui.lua"))
       + as_module("ClassicWind", rd("game_dev/classic_wind.lua"))
       + PLACEHOLDER
       + "\n" + ui[i:])
template = out
windui = windui_loader()
out = template.replace(PLACEHOLDER, windui)
assert not re.search(r"[^\x00-\x7F]", out), "non-ASCII character in bundle"
from bundle_util import strip_comments

os.makedirs(os.path.join(root, "dist"), exist_ok=True)
path = os.path.join(root, "dist", "tsb_hub_executor.lua")
open(path, "w", encoding="ascii").write(out)
# phone-friendly copies: .txt opens in any app; the .min version is smaller and easier to paste
open(os.path.join(root, "dist", "tsb_hub_executor.txt"), "w", encoding="ascii").write(out)
mini = strip_comments(template).replace(PLACEHOLDER, windui)      # only OUR code is minified; WindUI is inserted untouched
open(os.path.join(root, "dist", "tsb_hub_executor.min.txt"), "w", encoding="ascii").write(mini)
print(path, len(out.splitlines()), "lines;", "min:", len(mini.splitlines()), "lines,", len(mini), "bytes")
