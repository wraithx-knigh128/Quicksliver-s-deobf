"""The menu must stay bright AND readable. Parses the theme table out of tsb_animation_hub.lua and checks, for every theme at the
default brightness and at the Brightness slider's maximum:
  * white text on the Item / Panel surfaces and the soft sub-text on the Panel reach WCAG contrast 4.5 : 1 (3 : 1 at max brightness),
  * the window is not dark again (mean window colour luminance >= 0.12; it was ~0.03 when people called it dull and dark).
Usage (from game_dev/):  python3 tests/check_palette.py [path to tsb_animation_hub.lua]"""
import re, sys
src = open(sys.argv[1] if len(sys.argv) > 1 else "../tsb_animation_hub.lua", encoding="utf-8").read()
TEXT, SUB = (255, 255, 255), (236, 226, 248)
def lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def lum(rgb): return 0.2126 * lin(rgb[0]) + 0.7152 * lin(rgb[1]) + 0.0722 * lin(rgb[2])
def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)
themes = {}
for m in re.finditer(r'\["([A-Za-z ]+)"\] = \{Back = (\{[^}]*\}), Panel = (\{[^}]*\}), Item = (\{[^}]*\}), Hover = (\{[^}]*\}),\s*'
                     r'Accent = \{[^}]*\}, Accent2 = \{[^}]*\}, Gold = \{[^}]*\}, WinA = (\{[^}]*\}), WinB = (\{[^}]*\})\}', src):
    name = m.group(1)
    vals = [tuple(int(x) for x in g.strip("{}").split(",")) for g in m.groups()[1:]]
    themes[name] = dict(zip(["Back", "Panel", "Item", "Hover", "WinA", "WinB"], vals))
assert len(themes) == 5, "expected 5 themes in the source, found %d" % len(themes)
def shade(c, b): return tuple(min(255, int(x * b + 0.5)) for x in c)
bad = []
for name, th in themes.items():
    for bright, need, need_sub in ((1.0, 4.5, 4.5), (1.2, 3.0, 3.0)):
        t = {k: shade(v, bright) for k, v in th.items()}
        win = tuple((t["WinA"][i] + t["WinB"][i]) / 2 * 0.8 + t["Back"][i] * 0.2 for i in range(3))
        item, panel = contrast(TEXT, t["Item"]), contrast(TEXT, t["Panel"])
        sub = contrast(SUB, t["Panel"])
        print("%-10s brightness %.1f: window L=%.3f  text/item %.1f  text/panel %.1f  sub/panel %.1f" % (name, bright, lum(win), item, panel, sub))
        if item < need or panel < need or sub < need_sub: bad.append("%s @%.1f contrast" % (name, bright))
        if lum(win) < 0.12 and bright >= 1.0: bad.append("%s @%.1f window too dark (L=%.3f)" % (name, bright, lum(win)))
if bad:
    print("PROBLEMS:", *bad, sep="\n  "); sys.exit(1)
print("palette ok: all themes are bright and readable")
