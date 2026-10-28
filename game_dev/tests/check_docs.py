"""The README must describe every Tech Lab tech (from game_dev/):  python3 tests/check_docs.py
Titles come from tech_lab.lua (DEFS), so adding a tech without documenting it fails here."""
import re, sys
lab = open("tech_lab.lua", encoding="utf-8").read()
readme = open("README.md", encoding="utf-8").read()
titles = re.findall(r'^\s*\{id = "[a-z0-9]+", group = "[^"]+", title = "([^"]+)"', lab, re.M)
missing = [t for t in titles if t.split(" (")[0] not in readme]
print("%d techs, %d missing from README: %s" % (len(titles), len(missing), missing))
assert len(titles) >= 20, "could not read the tech titles from tech_lab.lua"
sys.exit(1 if missing else 0)
