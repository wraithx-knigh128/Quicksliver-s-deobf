"""Bundle everything into ONE file for executors (they cannot require local files).
Usage (repo root):  python3 game_dev/build_executor.py   ->  dist/tsb_hub_executor.lua"""
import os, re
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rd = lambda p: open(os.path.join(root, p), encoding="utf-8").read()

def as_module(name, src):
    src = re.sub(r"--\[\[.*?\]\]", "", src, count=1, flags=re.S)   # drop header comment
    return f"local {name} = (function()\n{src}\nend)()\n"

ui = rd("tsb_animation_hub.lua")
marker = "if not game:IsLoaded()"
i = ui.index(marker)
out = (ui[:i]
       + as_module("Data", rd("game_dev/tsb_data.lua"))
       + as_module("Engine", rd("game_dev/combo_engine.lua"))
       + "\n" + ui[i:])
assert not re.search(r"[^\x00-\x7F]", out), "non-ASCII character in bundle"
os.makedirs(os.path.join(root, "dist"), exist_ok=True)
path = os.path.join(root, "dist", "tsb_hub_executor.lua")
open(path, "w", encoding="ascii").write(out)
print(path, len(out.splitlines()), "lines")
