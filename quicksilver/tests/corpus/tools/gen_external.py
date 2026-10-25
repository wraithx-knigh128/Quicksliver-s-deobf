"""Generate output of third-party pure-Lua obfuscators for the corpus, through run_isolated.py (never through their own command lines).

  python -I gen_external.py --tool colisseum --root /path/to/colisseum --out ../obfuscated-local/colisseum --commit <git sha>
  python -I gen_external.py --tool zenfus    --root /path/to/Zenfus    --out ../obfuscated/zenfus --commit <git sha>
  python -I gen_external.py --tool simple_lua --root /path/to/dir-with-tool.lua --out ../obfuscated-local/simple_lua --commit <git sha>

Writes <out>/manifest.json in the format verify_fixtures.py reads (run it afterwards to fill in `behaviors`).
Output is committed to the repository only for tools whose licence allows it (Zenfus, MIT); the rest go to the git-ignored obfuscated-local/.
"""
import argparse
import hashlib
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = {
    "colisseum": {
        "name": "Colisseum", "source": "https://github.com/de-TourLLC/colisseum", "licence": "AGPL-3.0", "driver": "drivers/colisseum.lua",
        # (config label, options, runtime the obfuscator itself runs on). total and fortress need bit operations the 5.4 build does not have.
        "configs": [("easy", {"preset": "easy"}, "lua54"), ("medium", {"preset": "medium"}, "lua54"), ("hard", {"preset": "hard"}, "lua54"),
                    ("full", {"preset": "full"}, "lua54"), ("total", {"preset": "total"}, "luajit"), ("fortress", {"preset": "fortress"}, "luajit")],
    },
    "zenfus": {
        "name": "Zenfus", "source": "https://github.com/Zaenalos/Zenfus", "licence": "MIT", "driver": "drivers/zenfus.lua",
        "configs": [("default", {}, "lua54")],
    },
    "simple_lua": {
        "name": "Simple-Lua-Obfuscator", "source": "https://github.com/CloudHub111/Simple-Lua-Obfuscator", "licence": "none stated", "driver": "drivers/simple_lua.lua",
        "configs": [("default", {}, "lua54")],
    },
}


def load_isolated():
    spec = importlib.util.spec_from_file_location("run_isolated", os.path.join(HERE, "run_isolated.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tool", required=True, choices=sorted(TOOLS))
    ap.add_argument("--root", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--commit", default="unknown")
    ap.add_argument("--seed", type=int, default=1337)
    ap.add_argument("--configs", default="")
    ap.add_argument("--originals", default=os.path.join(HERE, "..", "originals"))
    ap.add_argument("--seconds", type=int, default=300)
    args = ap.parse_args()
    t = TOOLS[args.tool]
    iso = load_isolated()
    wanted = set(args.configs.split(",")) if args.configs else None
    os.makedirs(args.out, exist_ok=True)
    manifest = {"tool": t["name"], "source": t["source"], "licence": t["licence"], "sourceRevision": args.commit, "seed": args.seed,
                "runner": "tests/corpus/tools/run_isolated.py (virtual files, no host access)", "entries": []}
    for sample in sorted(f for f in os.listdir(args.originals) if f.endswith(".lua")):
        original = open(os.path.join(args.originals, sample), "rb").read()
        for label, opts, runtime in t["configs"]:
            if wanted and label not in wanted:
                continue
            fname = f"{sample[:-4]}__{label}.lua"
            entry = {"file": fname, "sample": sample, "config": label, "runtime": runtime, "sampleSha256": hashlib.sha256(original).hexdigest()}
            res = iso.run(args.root, os.path.join(HERE, t["driver"]), original, runtime, dict(opts, seed=args.seed), seconds=args.seconds)
            if res["ok"] and res["result"]:
                out = res["result"].encode("latin-1")
                open(os.path.join(args.out, fname), "wb").write(out)
                entry.update(status="ok", bytes=len(out), seconds=res["seconds"])
            else:
                entry.update(status="tool-error", error=(res["error"] or "no output")[:300])
            manifest["entries"].append(entry)
            print(f"{fname:52s} {entry['status']:10s} {entry.get('bytes', entry.get('error', ''))}")
    json.dump(manifest, open(os.path.join(args.out, "manifest.json"), "w"), indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
