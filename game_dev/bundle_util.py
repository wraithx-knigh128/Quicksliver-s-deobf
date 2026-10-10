"""Shared by the build scripts: bundling helpers."""
import re

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
