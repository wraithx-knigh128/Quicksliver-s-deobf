"""Generate *real* Prometheus output for the original corpus samples.

Prometheus (https://github.com/prometheus-lua/Prometheus, by levno-710) is an open-source
Lua obfuscator written in Lua. This script runs the unmodified Prometheus pipeline on a
real Lua 5.1 interpreter (via lupa) and stores the output as test fixtures.

The Prometheus checkout is NOT part of this repository (its licence asks forks and
derivative works to say so); point --src at a local copy of its `src/` folder.
Obfuscated output does not carry the Prometheus licence (see its README).

  python -I gen_prometheus.py --src /path/to/Prometheus/src --out ../obfuscated/prometheus
"""
import argparse
import hashlib
import json
import os
import sys

SEED = 1337

PRESETS = ["Minify", "Weak", "Medium", "Strong"]

# Each isolated step is generated on its own so test results can be attributed to one transform.
STEPS = {
    "step-EncryptStrings": '{ Name = "EncryptStrings", Settings = {} }',
    "step-ConstantArray": '{ Name = "ConstantArray", Settings = { Threshold = 1, StringsOnly = true, Shuffle = true, Rotate = true, LocalWrapperThreshold = 0 } }',
    "step-SplitStrings": '{ Name = "SplitStrings", Settings = {} }',
    "step-NumbersToExpressions": '{ Name = "NumbersToExpressions", Settings = {} }',
    "step-ProxifyLocals": '{ Name = "ProxifyLocals", Settings = {} }',
    "step-WrapInFunction": '{ Name = "WrapInFunction", Settings = {} }',
    "step-AddVararg": '{ Name = "AddVararg", Settings = {} }',
    "step-AntiTamper": '{ Name = "AntiTamper", Settings = { UseDebug = false } }',
    "step-Vmify": '{ Name = "Vmify", Settings = {} }',
}

LUA_DRIVER = r'''
local src_dir, code, mode, name, steps_lua, seed = ...
package.path = src_dir .. "/?.lua;" .. package.path
rawset(_G, "arg", {})  -- Lua 5.1 compat: a vararg fn has an implicit local `arg`, so write the global explicitly
local Prometheus = require("prometheus")
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Error
local cfg
if mode == "preset" then
  cfg = {}
  for k, v in pairs(Prometheus.Presets[name]) do cfg[k] = v end
else
  cfg = { LuaVersion = "Lua51", VarNamePrefix = "", NameGenerator = "MangledShuffled",
          PrettyPrint = false, Steps = assert((loadstring or load)("return { " .. steps_lua .. " }"))() }
end
cfg.Seed = seed
local pipeline = Prometheus.Pipeline:fromConfig(cfg)
return pipeline:apply(code, "sample")
'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, help="path to Prometheus `src` directory")
    ap.add_argument("--out", required=True)
    ap.add_argument("--originals", default=os.path.join(os.path.dirname(__file__), "..", "originals"))
    ap.add_argument("--commit", default="unknown", help="Prometheus commit/branch the --src copy came from")
    args = ap.parse_args()

    import lupa.lua51 as L

    manifest = {"tool": "Prometheus", "author": "levno-710", "source": "https://github.com/prometheus-lua/Prometheus",
                "sourceRevision": args.commit, "runtime": "PUC Lua 5.1 via lupa", "seed": SEED, "entries": []}
    os.makedirs(args.out, exist_ok=True)

    samples = sorted(f for f in os.listdir(args.originals) if f.endswith(".lua"))
    jobs = [("preset", p, p, "") for p in PRESETS] + [("steps", n, n, s) for n, s in STEPS.items()]
    for sample in samples:
        with open(os.path.join(args.originals, sample), "rb") as fh:
            original = fh.read()
        for mode, label, name, steps_lua in jobs:
            rt = L.LuaRuntime(encoding=None, register_eval=False, register_builtins=False)
            driver = rt.eval(b"function(...) " + LUA_DRIVER.encode() + b" end")
            fname = f"{sample[:-4]}__{label}.lua"
            entry = {"file": fname, "sample": sample, "config": label,
                     "sampleSha256": hashlib.sha256(original).hexdigest()}
            try:
                out = driver(args.src.encode(), original, mode.encode(), name.encode(), steps_lua.encode(), SEED)
                if isinstance(out, str):
                    out = out.encode("latin-1")
                with open(os.path.join(args.out, fname), "wb") as fh:
                    fh.write(out)
                entry["bytes"] = len(out)
                entry["status"] = "ok"
            except Exception as exc:  # keep going; record what the tool itself could not do
                entry["status"] = "tool-error"
                entry["error"] = str(exc)[:300]
            manifest["entries"].append(entry)
            print(f"{fname:56s} {entry['status']:10s} {entry.get('bytes', '')}")
    with open(os.path.join(args.out, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
