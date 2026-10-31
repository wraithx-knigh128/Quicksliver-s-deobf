"""Render full fighter rigs (tools/rig_dump.luau) with their real colours."""
import json, sys, math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon

data = json.load(open("/tmp/rigs.json"))
out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/rigs.png"
cols = int(sys.argv[2]) if len(sys.argv) > 2 else 4
yaw = math.radians(25)
cam = np.array([math.cos(yaw), 0.15, -math.sin(yaw)]); cam /= np.linalg.norm(cam)
view = -cam
right = np.cross(view, [0, 1, 0]); right /= np.linalg.norm(right)
upv = np.cross(right, view)
light = np.array([0.4, 0.8, -0.45]); light /= np.linalg.norm(light)
faces_idx = [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]
rows = math.ceil(len(data) / cols)
fig, axes = plt.subplots(rows, cols, figsize=(cols * 3.2, rows * 4.0), facecolor="#15161a")
axes = np.atleast_1d(axes).ravel()
for ax in axes:
    ax.set_axis_off(); ax.set_facecolor("#15161a")
for i, item in enumerate(data):
    ax = axes[i]
    polys = []
    for p in item["parts"]:
        if p["t"] >= 0.95:
            continue
        c = p["cf"]; pos = np.array(c[0:3]); R = np.array(c[3:12]).reshape(3, 3)
        sx, sy, sz = p["size"]
        if p["shape"] in ("Ball",):
            sx = sy = sz = min(sx, sy, sz) * 0.9
        corners = np.array([pos + R @ np.array([dx * sx, dy * sy, dz * sz]) for dx in (-.5, .5) for dy in (-.5, .5) for dz in (-.5, .5)])
        col = np.array(p["color"])
        neon = p["mat"] == "Neon"
        for f in faces_idx:
            pts = corners[f]
            n = np.cross(pts[1] - pts[0], pts[2] - pts[0]); n /= (np.linalg.norm(n) + 1e-9)
            if n @ cam < 0:
                n = -n
            shade = 1.0 if neon else 0.35 + 0.65 * max(0, n @ light)
            depth = pts.mean(axis=0) @ cam
            polys.append((depth, [(q @ right, q @ upv) for q in pts], np.clip(col * shade * (1.25 if neon else 1), 0, 1), neon, p["t"]))
    polys.sort(key=lambda t: t[0])
    for depth, pts2, col, neon, t in polys:
        ax.add_patch(Polygon(pts2, closed=True, facecolor=col, edgecolor=(0, 0, 0, 0.25), linewidth=0.2, alpha=1 - t * 0.8))
    ax.plot([-4, 4], [0, 0], color="#444", lw=0.6)
    ax.set_xlim(-4, 4); ax.set_ylim(-0.5, 7.5); ax.set_aspect("equal")
    ax.set_title(f'{item["label"]} ({item["count"]} parts)', fontsize=9, color="#ddd")
plt.tight_layout()
plt.savefig(out, dpi=80, facecolor="#15161a")
print("saved", out)
