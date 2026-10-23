"""Generate *real* Hercules output for the original corpus samples.

Hercules (https://github.com/zeusssz/hercules-obfuscator) is an open-source Lua obfuscator.
This script drives the unmodified Hercules pipeline the same way its CLI does (manifest presets,
`apply_method_selection`, `Pipeline.process`) on a real Lua 5.4 interpreter via lupa.

The Hercules checkout is not part of this repository; point --src at its `src/` folder.

  python -I gen_hercules.py --src /path/to/hercules-obfuscator/src --out ../obfuscated/hercules
"""
import argparse
import hashlib
import json
import os
import sys

SEED = 1337

PRESETS = {
    "light": "variable_renaming,compressor",
    "balanced": "variable_renaming,control_flow,string_encoding,opaque_predicates,compressor",
    "heavy": "variable_renaming,control_flow,string_encoding,string_to_expressions,opaque_predicates,"
             "garbage_code,function_inlining,wrap_in_function,antitamper,dynamic_code,compressor",
    "maximum": "virtual_machine,antitamper,control_flow,string_to_expressions,string_encoding,wrap_in_function,"
               "variable_renaming,garbage_code,opaque_predicates,function_inlining,dynamic_code,"
               "bytecode_encoding,compressor",
}
SINGLE = ["virtual_machine", "antitamper", "control_flow", "string_to_expressions", "string_encoding",
          "wrap_in_function", "variable_renaming", "garbage_code", "opaque_predicates",
          "function_inlining", "dynamic_code", "bytecode_encoding", "compressor"]

LUA_DRIVER = r'''
local src_dir, code, selected, target, seed = ...
-- same polyfills hercules.lua installs for Lua 5.3+ (math.ldexp / math.frexp were removed)
if not math.ldexp then math.ldexp = function(x, n) return x * 2 ^ n end end
if not math.frexp then
  math.frexp = function(x)
    if x == 0 then return 0, 0 end
    local exp = math.floor(math.log(math.abs(x)) / math.log(2)) + 1
    return x / 2 ^ exp, exp
  end
end
package.path = src_dir .. "/?.lua;" .. package.path
local manifest = require("manifest")
local config = require("config")
local Pipeline = require("pipeline")
config.target = target
local sel = {}
for key in selected:gmatch("[^,]+") do sel[key] = true end
for _, m in ipairs(manifest.modules) do config.settings[m.config_key].enabled = (sel[m.key] == true) end
math.randomseed(seed)
return Pipeline.process(code)
'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--originals", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "originals"))
    ap.add_argument("--commit", default="unknown")
    ap.add_argument("--max-bytes", type=int, default=800_000,
                    help="outputs larger than this are not stored (the `maximum` preset can emit multi-MB files)")
    args = ap.parse_args()

    import lupa.lua54 as L

    manifest = {"tool": "Hercules", "version": "2.0.1", "source": "https://github.com/zeusssz/hercules-obfuscator",
                "sourceRevision": args.commit, "runtime": "PUC Lua 5.4 via lupa", "seed": SEED, "entries": []}
    os.makedirs(args.out, exist_ok=True)
    jobs = [(k, v) for k, v in PRESETS.items()] + [("mod-" + m, m) for m in SINGLE]

    for sample in sorted(f for f in os.listdir(args.originals) if f.endswith(".lua")):
        original = open(os.path.join(args.originals, sample), "rb").read()
        for label, methods in jobs:
            rt = L.LuaRuntime(encoding=None, register_eval=False, register_builtins=False)
            driver = rt.eval(b"function(...) " + LUA_DRIVER.encode() + b" end")
            fname = f"{sample[:-4]}__{label}.lua"
            entry = {"file": fname, "sample": sample, "config": label, "modules": methods.split(","),
                     "sampleSha256": hashlib.sha256(original).hexdigest()}
            try:
                out = driver(args.src.encode(), original, methods.encode(), b"lua", SEED)
                if isinstance(out, str):
                    out = out.encode("latin-1")
                if len(out) > args.max_bytes:
                    entry.update(status="omitted-large", bytes=len(out))
                else:
                    open(os.path.join(args.out, fname), "wb").write(out)
                    entry.update(status="ok", bytes=len(out))
            except Exception as exc:
                entry.update(status="tool-error", error=str(exc)[:300])
            manifest["entries"].append(entry)
            print(f"{fname:58s} {entry['status']:10s} {entry.get('bytes', entry.get('error', ''))}")
    json.dump(manifest, open(os.path.join(args.out, "manifest.json"), "w"), indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
