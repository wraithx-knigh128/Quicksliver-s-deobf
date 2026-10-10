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

hub = rd("game_dev/mm2/wraiths_hub.lua")
marker = "-- @@MODULES@@"
assert hub.count(marker) == 1
out = hub.replace(marker, as_module("Logic", rd("game_dev/mm2/logic.lua")) + as_module("UILib", rd("game_dev/mm2/ui_lib.lua")))
assert not re.search(r"[^\x00-\x7F]", out), "non-ASCII character in bundle"
os.makedirs(os.path.join(root, "dist"), exist_ok=True)
for name in ("wraiths_hub.lua", "wraiths_hub.txt"):
    open(os.path.join(root, "dist", name), "w", encoding="ascii").write(out)
mini = strip_comments(out)
open(os.path.join(root, "dist", "wraiths_hub.min.txt"), "w", encoding="ascii").write(mini)
print("dist/wraiths_hub.lua", len(out.splitlines()), "lines;", "min:", len(mini.splitlines()), "lines,", len(mini), "bytes")
