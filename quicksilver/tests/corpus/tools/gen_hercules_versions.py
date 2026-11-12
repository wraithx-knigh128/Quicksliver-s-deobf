"""Generate real Hercules output for the corpus samples from EVERY version of the tool that can still be run.

Hercules (https://github.com/zeusssz/hercules-obfuscator, Apache-2.0) has no release tags; a version is what the watermark its
source writes says. The revisions below are the last commit that carries each watermark (and, for 1.5, also the first, because the
tool changed a great deal while it still said 1.5). gen_hercules.py keeps generating the current revision into ../obfuscated/hercules;
this script covers the older ones, each into ../obfuscated/hercules-<version>.

Every version is driven the same way, through what all of them have in common: `config.settings.<module>.enabled` and
`Pipeline.process(code)`. For each sample it writes

    default        the configuration the revision ships with
    all            every module switched on
    mod-<module>   that module alone

The clock the modules seed their random numbers from is fixed, so a run can be repeated.

  python -I gen_hercules_versions.py --repo /path/to/hercules-obfuscator --out ../obfuscated [--only 1.6.2]

The checkout is read with `git archive` into a temporary folder: nothing in it is modified.
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys
import tarfile
import tempfile
import io

SEED = 1337

# version label -> (revision, what is known about it)
REVISIONS = {
    "1.5-early": ("9384974", "first commit whose watermark says v1.5 (2024-09-22): text modules only, no virtual machine"),
    "1.5": ("1723b42", "last commit whose watermark says v1.5 (2024-11-03): first virtual machine (Compiler/c.lua), StringToExpressions, WrapInFunction, compressor"),
    "1.6": ("f8e5d38", "last commit whose watermark says v1.6 (2025-01-25): anti_tamper added"),
    "1.6.2": ("1b20510", "last commit whose watermark says v1.6.2 (2026-04-30)"),
    "2.0.0": ("c4baf05", "last commit whose watermark says v2.0.0 (2026-06-16): manifest.lua, presets, rewritten compiler (Compiler/*.lua)"),
}

LUA_DRIVER = r'''
local src_dir, code, mode, only, seed = ...
if not math.ldexp then math.ldexp = function(x, n) return x * 2 ^ n end end
if not math.frexp then
  math.frexp = function(x)
    if x == 0 then return 0, 0 end
    local exp = math.floor(math.log(math.abs(x)) / math.log(2)) + 1
    return x / 2 ^ exp, exp
  end
end
if not unpack then unpack = table.unpack end
if not loadstring then loadstring = load end
-- the modules seed from the clock when they are loaded and again while they run
local fixed = 1700000000
os.time = function() return fixed end
package.path = src_dir .. "/?.lua;" .. package.path
local config = require("config")
local Pipeline = require("pipeline")
local names = {}
for key, value in pairs(config.settings) do
  if type(value) == "table" and value.enabled ~= nil then names[#names + 1] = key end
end
table.sort(names)
if mode == "list" then return table.concat(names, ",") end
if mode ~= "default" then
  for _, key in ipairs(names) do
    config.settings[key].enabled = (mode == "all") or (key == only)
  end
end
if config.settings.final_print ~= nil then config.settings.final_print = false end
math.randomseed(seed)
return Pipeline.process(code)
'''


def run(L, src, code, mode, only=b""):
    rt = L.LuaRuntime(encoding=None, register_eval=False, register_builtins=False)
    driver = rt.eval(b"function(...) " + LUA_DRIVER.encode() + b" end")
    out = driver(src.encode(), code, mode.encode(), only, SEED)
    return out.encode("latin-1") if isinstance(out, str) else out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True, help="a clone of the Hercules repository with its history")
    ap.add_argument("--out", required=True, help="the obfuscated/ corpus folder")
    ap.add_argument("--originals", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "originals"))
    ap.add_argument("--only", default="")
    ap.add_argument("--max-bytes", type=int, default=400_000)
    args = ap.parse_args()

    import lupa.lua54 as L

    samples = sorted(f for f in os.listdir(args.originals) if f.endswith(".lua") and not f.startswith("s08"))
    for version, (rev, note) in REVISIONS.items():
        if args.only and version != args.only:
            continue
        full = subprocess.run(["git", "-C", args.repo, "rev-parse", rev], capture_output=True, text=True, check=True).stdout.strip()
        date = subprocess.run(["git", "-C", args.repo, "log", "-1", "--format=%ad", "--date=short", rev], capture_output=True, text=True, check=True).stdout.strip()
        with tempfile.TemporaryDirectory() as tmp:
            tar = subprocess.run(["git", "-C", args.repo, "archive", rev, "src"], capture_output=True, check=True).stdout
            tarfile.open(fileobj=io.BytesIO(tar)).extractall(tmp, filter="data")
            src = os.path.join(tmp, "src")
            modules = run(L, src, b"", "list").decode().split(",")
            out_dir = os.path.join(args.out, "hercules-" + version)
            os.makedirs(out_dir, exist_ok=True)
            manifest = {"tool": "Hercules", "version": version, "source": "https://github.com/zeusssz/hercules-obfuscator",
                        "sourceRevision": full, "revisionDate": date, "note": note, "runtime": "PUC Lua 5.4 via lupa", "seed": SEED,
                        "modules": modules, "entries": []}
            jobs = [("default", "default", b""), ("all", "all", b"")] + [("mod-" + m, "one", m.encode()) for m in modules]
            for sample in samples:
                original = open(os.path.join(args.originals, sample), "rb").read()
                for label, mode, only in jobs:
                    fname = f"{sample[:-4]}__{label}.lua"
                    entry = {"file": fname, "sample": sample, "config": label, "sampleSha256": hashlib.sha256(original).hexdigest()}
                    try:
                        out = run(L, src, original, mode, only)
                        if out is None:
                            raise RuntimeError("the pipeline returned nothing")
                        if len(out) > args.max_bytes:
                            entry.update(status="omitted-large", bytes=len(out))
                        else:
                            open(os.path.join(out_dir, fname), "wb").write(out)
                            entry.update(status="ok", bytes=len(out))
                    except Exception as exc:  # the tool failed on this input: recorded, not hidden
                        entry.update(status="tool-error", error=str(exc)[:300])
                    manifest["entries"].append(entry)
                    print(f"{version:10s} {fname:52s} {entry['status']:14s} {entry.get('bytes', entry.get('error', ''))}")
            json.dump(manifest, open(os.path.join(out_dir, "manifest.json"), "w"), indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
