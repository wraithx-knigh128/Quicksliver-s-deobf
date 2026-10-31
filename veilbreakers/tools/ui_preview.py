"""Rasterise a UI layout dump (tools/ui_dump.luau) into a PNG mock-up."""
import json, sys
from PIL import Image, ImageDraw, ImageFont

data = json.load(open("/tmp/ui.json"))
out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ui.png"
W, H = int(data["w"]), int(data["h"])
img = Image.new("RGB", (W, H), (34, 38, 44))
draw = ImageDraw.Draw(img, "RGBA")


def font(size, serif):
    names = ["DejaVuSerif.ttf" if serif else "DejaVuSans.ttf"]
    for n in names:
        for base in ("/usr/share/fonts/truetype/dejavu/", ""):
            try:
                return ImageFont.truetype(base + n, max(6, int(size)))
            except OSError:
                pass
    return ImageFont.load_default()


def rgba(c, t):
    return (int(c[0] * 255), int(c[1] * 255), int(c[2] * 255), int(255 * (1 - t)))


for e in data["items"]:
    x, y, w, h = e["x"], e["y"], e["w"], e["h"]
    box = [x, y, x + max(1, w), y + max(1, h)]
    if e.get("image") is not None:
        t = e.get("imageT", 0)
        if e["image"]:
            draw.rectangle(box, fill=(70, 60, 50, int(255 * (1 - t) * 0.85)))
            draw.line([x, y, x + w, y + h], fill=(110, 95, 70, 120))
            draw.line([x, y + h, x + w, y], fill=(110, 95, 70, 120))
    if e["bgT"] < 0.99 and w > 0 and h > 0:
        col = e["grad"][0] if e.get("grad") else e["bg"]
        fill = rgba(col, e["bgT"])
        r = e.get("corner") or 0
        if e.get("grad") and e["gradRot"] in (90, -90) and h > 4:
            c0, c1 = e["grad"]
            steps = 12
            for i in range(steps):
                k = i / (steps - 1)
                c = [c0[j] + (c1[j] - c0[j]) * k for j in range(3)]
                y0 = y + h * i / steps
                draw.rectangle([x, y0, x + w, y0 + h / steps + 1], fill=rgba(c, e["bgT"]))
        elif r > 0:
            draw.rounded_rectangle(box, radius=min(r, w / 2, h / 2), fill=fill)
        else:
            draw.rectangle(box, fill=fill)
    if e.get("stroke"):
        s = e["stroke"]
        r = e.get("corner") or 0
        col = rgba(s[:3], s[4])
        if r > 0:
            draw.rounded_rectangle(box, radius=min(r, w / 2, h / 2), outline=col, width=max(1, int(s[3])))
        else:
            draw.rectangle(box, outline=col, width=max(1, int(s[3])))
    if e.get("viewport"):
        draw.rectangle(box, outline=(90, 90, 110, 90))
        parts = sorted(e.get("parts", []), key=lambda p: -p[6])
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        for p in parts:
            sx, sy, size, r_, g_, b_, _, neon = p
            rr = max(1, size * 0.4)
            col = (int(r_ * 255), int(g_ * 255), int(b_ * 255), 255)
            ld.rectangle([sx - rr, sy - rr, sx + rr, sy + rr], fill=col)
        mask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(mask).rectangle(box, fill=255)
        img.paste(layer, (0, 0), Image.composite(layer.split()[3], mask, mask))
        draw = ImageDraw.Draw(img, "RGBA")
    if e.get("text") and e.get("textT", 0) < 0.95:
        f = font(e["textSize"] * 0.95, e.get("serif"))
        txt = e["text"]
        try:
            bb = draw.textbbox((0, 0), txt, font=f)
        except Exception:
            bb = (0, 0, len(txt) * e["textSize"] * 0.5, e["textSize"])
        tw, th = bb[2] - bb[0], bb[3] - bb[1]
        if e["xAlign"] == "Center":
            tx = x + (w - tw) / 2
        elif e["xAlign"] == "Right":
            tx = x + w - tw
        else:
            tx = x
        if e["yAlign"] == "Top":
            ty = y
        elif e["yAlign"] == "Bottom":
            ty = y + h - th
        else:
            ty = y + (h - th) / 2
        if e.get("wrap") and tw > w and w > 20:
            words = txt.split(" ")
            lines, cur = [], ""
            for wd in words:
                t2 = (cur + " " + wd).strip()
                if draw.textbbox((0, 0), t2, font=f)[2] > w and cur:
                    lines.append(cur)
                    cur = wd
                else:
                    cur = t2
            lines.append(cur)
            ty = y
            for ln in lines:
                lw = draw.textbbox((0, 0), ln, font=f)[2]
                lx = x + (w - lw) / 2 if e["xAlign"] == "Center" else x
                draw.text((lx, ty), ln, font=f, fill=rgba(e["textColor"], e["textT"]))
                ty += e["textSize"] * 1.15
        else:
            draw.text((tx + 1, ty + 1), txt, font=f, fill=(0, 0, 0, int(160 * (1 - e["textT"]))))
            draw.text((tx, ty), txt, font=f, fill=rgba(e["textColor"], e["textT"]))
img.save(out)
print("saved", out)
