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
       + as_module("Data", rd("game_dev/tsb_data.lua"))
       + as_module("Engine", rd("game_dev/combo_engine.lua"))
       + "\n" + ui[i:])
assert not re.search(r"[^\x00-\x7F]", out), "non-ASCII character in bundle"
def strip_comments(src):
    """Remove Lua comments and indentation without touching strings (handles '..', "..", [[..]], --[[..]])."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i)
                i = n if j < 0 else j + len(close)
            else:
                j = src.find("\n", i)
                i = n if j < 0 else j
            continue
        if c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            out.append(src[i:j + 1]); i = j + 1
            continue
        m = re.match(r"\[(=*)\[", src[i:]) if c == "[" else None
        if m:
            close = "]" + m.group(1) + "]"
            j = src.find(close, i)
            j = n if j < 0 else j + len(close)
            out.append(src[i:j]); i = j
            continue
        out.append(c); i += 1
    lines = ("".join(out)).split("\n")
    return "\n".join(l.strip() for l in lines if l.strip()) + "\n"

os.makedirs(os.path.join(root, "dist"), exist_ok=True)
path = os.path.join(root, "dist", "tsb_hub_executor.lua")
open(path, "w", encoding="ascii").write(out)
# phone-friendly copies: .txt opens in any app; the .min version is smaller and easier to paste
open(os.path.join(root, "dist", "tsb_hub_executor.txt"), "w", encoding="ascii").write(out)
mini = strip_comments(out)
open(os.path.join(root, "dist", "tsb_hub_executor.min.txt"), "w", encoding="ascii").write(mini)
print(path, len(out.splitlines()), "lines;", "min:", len(mini.splitlines()), "lines,", len(mini), "bytes")
