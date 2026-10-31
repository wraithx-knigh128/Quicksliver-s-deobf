"""Render pose dumps (tools/pose_dump.luau) to a contact sheet PNG.

Orthographic projection from the in-game camera: the fighter faces screen-right and
is turned 25 degrees toward the camera, exactly like the 2.5D fight camera.
"""
import json, sys, math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon

data = json.load(open("/tmp/poses.json"))
out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/poses.png"
yaw = math.radians(25)
# direction from the rig toward the camera, in rig space (+X right side, -Z forward)
cam = np.array([math.cos(yaw), 0.18, -math.sin(yaw)])
cam /= np.linalg.norm(cam)
up = np.array([0, 1, 0])
view = -cam
right = np.cross(view, up); right /= np.linalg.norm(right)
upv = np.cross(right, view)

palette = {"Head": "#e8c39e", "UpperTorso": "#3a5bbf", "LowerTorso": "#24306a"}
n = len(data)
cols = 6
rows = math.ceil(n / cols)
fig, axes = plt.subplots(rows, cols, figsize=(cols * 2.4, rows * 2.9))
axes = np.atleast_1d(axes).ravel()
faces_idx = [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]
for ax in axes:
    ax.set_axis_off()
for i, item in enumerate(data):
    ax = axes[i]
    polys = []
    for b in item["bones"]:
        c = b["cf"]
        pos = np.array(c[0:3]); R = np.array(c[3:12]).reshape(3, 3)
        sx, sy, sz = b["size"]
        corners = np.array([pos + R @ np.array([dx * sx, dy * sy, dz * sz]) for dx in (-.5, .5) for dy in (-.5, .5) for dz in (-.5, .5)])
        name = b["name"]
        col = palette.get(name, "#c0392b" if name.startswith("Right") else "#27ae60")
        for f in faces_idx:
            pts = corners[f]
            centre = pts.mean(axis=0)
            normal = np.cross(pts[1] - pts[0], pts[2] - pts[0])
            depth = centre @ cam
            shade = 0.55 + 0.45 * abs(normal @ cam) / (np.linalg.norm(normal) + 1e-9)
            p2 = [(p @ right, p @ upv) for p in pts]
            polys.append((depth, p2, col, shade))
    polys.sort(key=lambda t: t[0])
    for depth, p2, col, shade in polys:
        rgb = np.array(matplotlib.colors.to_rgb(col)) * shade
        ax.add_patch(Polygon(p2, closed=True, facecolor=np.clip(rgb, 0, 1), edgecolor="black", linewidth=0.25))
    ax.plot([-3.5, 3.5], [0, 0], color="gray", lw=0.6)
    ax.set_xlim(-3.5, 3.5); ax.set_ylim(-0.6, 6.0); ax.set_aspect("equal")
    ax.set_title(item["label"], fontsize=8)
plt.tight_layout()
plt.savefig(out, dpi=72)
print("saved", out)
