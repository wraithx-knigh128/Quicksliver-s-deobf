"""Original VFX textures for OOF COMBAT (white on transparent, tinted in-engine).

speedlines.png  radial anime speed lines with a clear centre (impact frames, supers)
slash.png       crescent sword-slash arc with a bright leading edge and fading tail
hitburst.png    comic-book star burst for hit flashes
shockwave.png   soft ring for ground shockwaves
"""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "art", "vfx")
rng = np.random.default_rng(1337)


def save(img, name):
    img.save(os.path.join(OUT, name), optimize=True)
    print(name, img.size, os.path.getsize(os.path.join(OUT, name)))


def speedlines(n=1024):
    img = Image.new("L", (n * 2, n * 2), 0)
    d = ImageDraw.Draw(img)
    c = n
    count = 150
    for i in range(count):
        a = (i / count) * 2 * math.pi + rng.uniform(-0.015, 0.015)
        inner = n * rng.uniform(0.42, 0.78)
        outer = n * 1.5
        w = rng.uniform(0.004, 0.018)  # half-angle width at the outer end
        p0 = (c + math.cos(a) * inner, c + math.sin(a) * inner)
        p1 = (c + math.cos(a - w) * outer, c + math.sin(a - w) * outer)
        p2 = (c + math.cos(a + w) * outer, c + math.sin(a + w) * outer)
        d.polygon([p0, p1, p2], fill=int(rng.uniform(180, 255)))
    img = img.resize((n, n), Image.LANCZOS)
    rgba = Image.merge("RGBA", (Image.new("L", (n, n), 255),) * 3 + (img,))
    return rgba


def slash(w=1024, h=512):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = w * 0.5, h * 1.25
    r = np.hypot(xx - cx, yy - cy)
    ang = np.arctan2(yy - cy, xx - cx)  # -pi..0 across the top
    a0, a1 = -math.pi * 0.82, -math.pi * 0.18
    t = np.clip((ang - a0) / (a1 - a0), 0, 1)  # 0 = tail, 1 = head
    R = h * 1.12
    thick = np.maximum(np.clip(np.sin(t * math.pi), 0, 1) ** 0.7 * h * 0.34, 1.0)  # crescent: fat middle, sharp tips
    u = (R - r) / thick  # 0 at the outer (leading) edge, 1 at the inner edge
    inside = (u >= 0) & (u <= 1) & (t > 0) & (t < 1)
    uc = np.clip(u, 0, 1)
    body = (1 - uc) ** 1.35
    tail = np.clip(t, 0, 1) ** 0.6  # fades out toward the tail
    edge = np.exp(-(uc ** 2) / (2 * 0.06 ** 2))  # hot leading edge
    a = np.where(inside, np.clip(body * 0.75 * tail + edge * tail, 0, 1), 0.0)
    alpha = Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))
    return Image.merge("RGBA", (Image.new("L", (w, h), 255),) * 3 + (alpha,))


def hitburst(n=512):
    img = Image.new("L", (n * 2, n * 2), 0)
    d = ImageDraw.Draw(img)
    c = n
    spikes = 14
    pts = []
    for i in range(spikes * 2):
        a = i / (spikes * 2) * 2 * math.pi + rng.uniform(-0.06, 0.06)
        rad = n * (rng.uniform(0.78, 0.98) if i % 2 == 0 else rng.uniform(0.34, 0.46))
        pts.append((c + math.cos(a) * rad, c + math.sin(a) * rad))
    d.polygon(pts, fill=255)
    img = img.resize((n, n), Image.LANCZOS)
    # hollow-ish core so tints read as a flash, not a sticker
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xx - n / 2, yy - n / 2) / (n / 2)
    core = np.clip(0.55 + 0.45 * r, 0, 1)
    a = np.asarray(img, dtype=np.float32) / 255 * core
    alpha = Image.fromarray((a * 255).astype(np.uint8))
    return Image.merge("RGBA", (Image.new("L", (n, n), 255),) * 3 + (alpha,))


def shockwave(n=512):
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xx - n / 2, yy - n / 2) / (n / 2)
    ring = np.exp(-((r - 0.82) ** 2) / (2 * 0.045 ** 2))
    inner = np.clip((r - 0.35) / 0.47, 0, 1) ** 3 * 0.35
    a = np.clip(ring + inner * (r < 0.82), 0, 1) * (r < 1)
    alpha = Image.fromarray((a * 255).astype(np.uint8))
    return Image.merge("RGBA", (Image.new("L", (n, n), 255),) * 3 + (alpha,))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save(speedlines(), "speedlines.png")
    save(slash(), "slash.png")
    save(hitburst(), "hitburst.png")
    save(shockwave(), "shockwave.png")
