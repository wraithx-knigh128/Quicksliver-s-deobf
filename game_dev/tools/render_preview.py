"""Paints a draw list produced by tests/mm2_layout.lua (World:previewJson) into a PNG.
It is NOT Roblox's renderer: fonts are Inter (Gotham stand-in), gradients are approximated, nothing is blurred. It exists so the layout
(sizes, spacing, wrapping, overlap) and the look of the hub can be eyeballed against reference screenshots.
  python3 tools/render_preview.py scene.json out.png [scale]"""
import json, math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONTS = {"regular": "/usr/share/fonts/opentype/inter/Inter-Regular.otf", "medium": "/usr/share/fonts/opentype/inter/Inter-Medium.otf",
         "bold": "/usr/share/fonts/opentype/inter/Inter-Bold.otf"}
_font_cache = {}
def font(kind, px):
    key = (kind, px)
    if key not in _font_cache:
        try: _font_cache[key] = ImageFont.truetype(FONTS[kind], px)
        except OSError: _font_cache[key] = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if kind == "bold" else ""), px)
    return _font_cache[key]

def scene_background(w, h):
    """a stand-in for the game behind the menu: wall, floor, a crate, so transparency and contrast can be judged"""
    img = Image.new("RGBA", (w, h))
    px = np.zeros((h, w, 4), dtype=np.uint8)
    ys = np.linspace(0, 1, h)[:, None]
    wall = np.array([214, 204, 186]) * (1 - ys * 0.15)
    px[..., :3] = wall[:, None, :] if wall.ndim == 2 else wall
    px[..., 3] = 255
    img = Image.fromarray(px, "RGBA")
    d = ImageDraw.Draw(img)
    d.polygon([(0, int(h * 0.72)), (w, int(h * 0.66)), (w, h), (0, h)], fill=(150, 112, 78, 255))
    d.rectangle((int(w * 0.04), int(h * 0.3), int(w * 0.16), int(h * 0.72)), fill=(190, 150, 100, 255))
    d.rectangle((int(w * 0.84), int(h * 0.12), int(w * 1.0), int(h * 0.7)), fill=(70, 74, 82, 255))
    return img

def rounded_mask(w, h, radius, scale):
    m = Image.new("L", (max(1, int(w)), max(1, int(h))), 0)
    r = max(0, min(radius or 0, min(w, h) / 2))
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), radius=r, fill=255)
    return m

def gradient_layer(op, w, h):
    g = op["grad"]
    th = math.radians(g.get("rotation", 0))
    dx, dy = math.cos(th), math.sin(th)
    ys, xs = np.mgrid[0:h, 0:w]
    ext = abs(w * dx) + abs(h * dy) or 1
    t = ((xs - w / 2) * dx + (ys - h / 2) * dy) / ext + 0.5
    ox, oy = g.get("offset", [0, 0])
    t = t - (ox * dx * w + oy * dy * h) / ext
    t = np.clip(t, 0, 1)
    ks = sorted(g["color"], key=lambda k: k[0]) or [[0, [255, 255, 255]], [1, [255, 255, 255]]]
    tp = [k[0] for k in ks]
    rgb = np.stack([np.interp(t, tp, [k[1][c] for k in ks]) for c in range(3)], axis=-1)
    tr = sorted(g["transparency"], key=lambda k: k[0]) or [[0, 0], [1, 0]]
    a = 1 - np.interp(t, [k[0] for k in tr], [k[1] for k in tr])
    return rgb, a

def render(data, out, scale=2):
    W, H = int(data["w"]), int(data["h"])
    S = scale
    canvas = scene_background(W * S, H * S)
    for op in data["ops"]:
        x, y, w, h = op["x"], op["y"], op["w"], op["h"]
        clip = op.get("clip")
        pad = 3
        bx0, by0 = int((x - pad) * S), int((y - pad) * S)
        bx1, by1 = int((x + w + pad) * S), int((y + h + pad) * S)
        if op["t"] == "text":
            bx0, by0, bx1, by1 = int(x * S) - 4, int(y * S) - 4, int((x + w) * S) + 4, int((y + h) * S) + 4
        if op.get("rot"):
            r = max(w, h) * 0.75
            bx0, by0, bx1, by1 = int((x + w / 2 - r) * S), int((y + h / 2 - r) * S), int((x + w / 2 + r) * S), int((y + h / 2 + r) * S)
        lw, lh = bx1 - bx0, by1 - by0
        if lw <= 0 or lh <= 0 or lw > 6000 or lh > 6000: continue
        layer = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
        ox, oy = x * S - bx0, y * S - by0
        wpx, hpx = max(1, int(round(w * S))), max(1, int(round(h * S)))
        rad = (op.get("radius") or 0) * S
        if op["t"] == "rect":
            col = op["color"]
            alpha = op.get("alpha", 1)
            piece = Image.new("RGBA", (wpx, hpx), tuple(col) + (int(255 * alpha),))
            if op.get("grad"):
                rgb, a = gradient_layer(op, wpx, hpx)
                rgb = rgb * (np.array(col) / 255.0)                    # Roblox multiplies the gradient's colour with the frame's own colour
                arr = np.zeros((hpx, wpx, 4), dtype=np.uint8)
                arr[..., :3] = rgb.astype(np.uint8)
                arr[..., 3] = np.clip(a * alpha * 255, 0, 255).astype(np.uint8)
                piece = Image.fromarray(arr, "RGBA")
            mask = rounded_mask(wpx, hpx, rad, S)
            a = np.minimum(np.array(piece.split()[3]), np.array(mask))
            piece.putalpha(Image.fromarray(a.astype(np.uint8), "L"))
            layer.paste(piece, (int(round(ox)), int(round(oy))))
        elif op["t"] == "stroke":
            th = max(1, int(round(op["thickness"] * S)))
            d = ImageDraw.Draw(layer)
            r = max(0, min(rad, min(wpx, hpx) / 2))
            d.rounded_rectangle((ox, oy, ox + wpx - 1, oy + hpx - 1), radius=r, outline=tuple(op["color"]) + (int(255 * op.get("alpha", 1)),), width=th)
        elif op["t"] == "image":
            d = ImageDraw.Draw(layer)
            d.rounded_rectangle((ox, oy, ox + wpx - 1, oy + hpx - 1), radius=min(wpx, hpx) / 2 if rad else 0, fill=(70, 70, 86, 255))
            cx, cy = ox + wpx / 2, oy + hpx / 2
            d.ellipse((cx - wpx * 0.17, cy - hpx * 0.30, cx + wpx * 0.17, cy + hpx * 0.04), fill=(215, 215, 225, 255))
            d.ellipse((cx - wpx * 0.30, cy + hpx * 0.08, cx + wpx * 0.30, cy + hpx * 0.62), fill=(215, 215, 225, 255))
        elif op["t"] == "text":
            kind = "bold" if op.get("bold") else "medium" if op.get("medium") else "regular"
            size = max(6, int(round(op["size"] * S * 0.92)))
            f = font(kind, size)
            d = ImageDraw.Draw(layer)
            color = tuple(op["color"]) + (int(255 * op.get("alpha", 1) * (0.55 if op.get("placeholder") else 1)),)
            lines = op["lines"]
            lh_px = op["size"] * 1.16 * S
            total = lh_px * len(lines)
            ty = oy + (hpx - total) / 2 if op["ya"] == "Center" else oy if op["ya"] == "Top" else oy + hpx - total
            for i, line in enumerate(lines):
                tw = d.textlength(line, font=f)
                tx = ox if op["xa"] == "Left" else ox + wpx - tw if op["xa"] == "Right" else ox + (wpx - tw) / 2
                d.text((tx, ty + i * lh_px + (lh_px - size) / 2 - size * 0.08), line, fill=color, font=f)
        if op.get("rot"):
            layer = layer.rotate(-op["rot"], resample=Image.BICUBIC, center=(ox + wpx / 2, oy + hpx / 2))
        if clip:
            cx0, cy0 = int(clip[0] * S) - bx0, int(clip[1] * S) - by0
            cx1, cy1 = cx0 + int(clip[2] * S), cy0 + int(clip[3] * S)
            if clip[2] <= 0 or clip[3] <= 0 or min(lw, cx1) <= max(0, cx0) or min(lh, cy1) <= max(0, cy0): continue
            m = Image.new("L", (lw, lh), 0)
            if len(clip) > 4 and clip[4]:
                ImageDraw.Draw(m).rounded_rectangle((cx0, cy0, cx1 - 1, cy1 - 1), radius=min(clip[4] * S, min(clip[2], clip[3]) * S / 2), fill=255)
            else:
                ImageDraw.Draw(m).rectangle((max(0, cx0), max(0, cy0), min(lw, cx1) - 1, min(lh, cy1) - 1), fill=255)
            a = np.minimum(np.array(layer.split()[3]), np.array(m))
            layer.putalpha(Image.fromarray(a.astype(np.uint8), "L"))
        canvas.alpha_composite(layer, (max(0, bx0), max(0, by0)) if bx0 >= 0 and by0 >= 0 else (0, 0)) if (bx0 >= 0 and by0 >= 0 and bx1 <= canvas.width and by1 <= canvas.height) else paste_clipped(canvas, layer, bx0, by0)
    canvas.convert("RGB").save(out)

def paste_clipped(canvas, layer, bx0, by0):
    x0, y0 = max(0, bx0), max(0, by0)
    x1, y1 = min(canvas.width, bx0 + layer.width), min(canvas.height, by0 + layer.height)
    if x1 <= x0 or y1 <= y0: return
    crop = layer.crop((x0 - bx0, y0 - by0, x1 - bx0, y1 - by0))
    canvas.alpha_composite(crop, (x0, y0))

if __name__ == "__main__":
    data = json.load(open(sys.argv[1]))
    render(data, sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 2)
    for p in data.get("problems", []): print("PROBLEM", p)
