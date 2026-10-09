"""Draws a ROUGH flat preview of the menu themes (window gradient, sidebar, cards, toggle) straight from the theme table in
tsb_animation_hub.lua, next to the old dark palette. It is NOT Roblox's renderer (no blur / gloss / rounded image), just the colours.
  pip install pillow ;  python3 tools/render_palette_preview.py [old hub source] > preview/menu_palettes.png"""
import re, sys
from PIL import Image, ImageDraw, ImageFont
def parse(src):
    th = {}
    for m in re.finditer(r'\["([A-Za-z ]+)"\] = \{Back = (\{[^}]*\}), Panel = (\{[^}]*\}), Item = (\{[^}]*\}), Hover = (\{[^}]*\}),\s*Accent = (\{[^}]*\}), '
                         r'Accent2 = (\{[^}]*\}), Gold = (\{[^}]*\}), WinA = (\{[^}]*\}), WinB = (\{[^}]*\})\}', src):
        vals = [tuple(int(x) for x in g.strip("{}").split(",")) for g in m.groups()[1:]]
        th[m.group(1)] = dict(zip(["Back", "Panel", "Item", "Hover", "Accent", "Accent2", "Gold", "WinA", "WinB"], vals))
    return th
new = parse(open("../tsb_animation_hub.lua", encoding="utf-8").read())
old = parse(open(sys.argv[1], encoding="utf-8").read()) if len(sys.argv) > 1 else {}
F = lambda s, b=False: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if b else ""), s)
def mix(a, b, t): return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))
def tile(th, glass, title, W=520, H=300):
    im = Image.new("RGB", (W, H)); px = im.load()
    for y in range(H):
        for x in range(W):
            t = min(1, max(0, (x * 0.5 + y * 0.87) / (W * 0.5 + H * 0.87)))
            px[x, y] = mix(mix(th["WinA"], th["WinB"], t), th["Back"], 1 - glass)
    d = ImageDraw.Draw(im, "RGBA")
    d.rounded_rectangle((2, 2, W - 3, H - 3), 18, outline=th["Gold"] + (220,), width=2)
    d.text((16, 12), "Animation Hub", fill=(255, 255, 255), font=F(15, True)); d.text((190, 16), title, fill=th["Gold"], font=F(11))
    d.rounded_rectangle((10, 44, 120, H - 14), 12, fill=th["Panel"] + (150,))
    for i, t in enumerate(["Main", "Auto Tech", "Garou", "Config"]):
        act = i == 1
        d.rounded_rectangle((16, 54 + i * 34, 114, 80 + i * 34), 9, fill=(th["Accent"] + (255,)) if act else (th["Item"] + (170,)))
        d.text((28, 60 + i * 34), t, fill=(36, 14, 48) if act else (255, 255, 255), font=F(12, True))
    rows = [("Auto block", "Blocks every hit aimed at you", True), ("Block style", "Safe", None), ("Range (studs)", "16", None),
            ("Dash behind the closest player", "Round button, no teleport", None)]
    for i, (a, b, on) in enumerate(rows):
        y = 48 + i * 56
        d.rounded_rectangle((132, y, W - 14, y + 48), 12, fill=th["Item"] + (175,))
        d.text((146, y + 7), a, fill=(255, 255, 255), font=F(12, True)); d.text((146, y + 26), b, fill=(236, 226, 248), font=F(10))
        if on is not None:
            d.rounded_rectangle((W - 62, y + 14, W - 26, y + 34), 10, fill=th["Accent"] + (255,)); d.ellipse((W - 44, y + 16, W - 28, y + 32), fill=(255, 255, 255))
    return im
tiles = ([tile(old["Rose Gold"], 0.72, "BEFORE (Rose Gold)")] if "Rose Gold" in old else []) + [tile(new[n], 0.82, "NOW: " + n) for n in new]
W, H = tiles[0].size
rows = (len(tiles) + 1) // 2
sheet = Image.new("RGB", (W * 2 + 30, H * rows + 10 + 10 * rows), (18, 14, 24))
for i, t in enumerate(tiles): sheet.paste(t, (10 + (i % 2) * (W + 10), 10 + (i // 2) * (H + 10)))
sheet.save(sys.stdout.buffer, "PNG")
