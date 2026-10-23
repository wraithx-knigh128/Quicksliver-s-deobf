"""Verify that every obfuscated fixture still behaves like its original sample.

For each entry in <dir>/manifest.json the obfuscated file and the original sample are run
on the reference runtime (see run_lua.py) and their captured output is compared. The result is
written back into the manifest as `behavior`: "equivalent" | "diverged" | "errored".

  python -I verify_fixtures.py --dir ../obfuscated/prometheus [--runtimes lua51,luajit,lua54,lua54c]

Each fixture is run on every requested runtime against the original run on that same runtime.
`behavior` is "equivalent" if it matches on at least one runtime, else "diverged" (ran, different
output) or "errored" (did not run). Per-runtime results are kept in `behaviors`.
"""
import argparse
import importlib.util
import json
import os
import sys


def load_runner():
    here = os.path.dirname(os.path.abspath(__file__))
    spec = importlib.util.spec_from_file_location("run_lua", os.path.join(here, "run_lua.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--runtimes", default="lua51,luajit,lua54,lua54c")
    ap.add_argument("--originals", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "originals"))
    ap.add_argument("--budget", type=int, default=200_000_000)
    args = ap.parse_args()
    runner = load_runner()

    runtimes = args.runtimes.split(",")
    path = os.path.join(args.dir, "manifest.json")
    manifest = json.load(open(path))
    baseline = {}
    counts = {"equivalent": 0, "diverged": 0, "errored": 0, "skipped": 0}

    def run_file(fp, rt):
        with open(fp, "rb") as fh:
            return runner.run(fh.read().decode("latin-1"), rt, args.budget)

    for entry in manifest["entries"]:
        if entry.get("status") != "ok":
            entry["behavior"] = "skipped"
            counts["skipped"] += 1
            continue
        sample = entry["sample"]
        results, errors = {}, {}
        for rt in runtimes:
            if (sample, rt) not in baseline:
                baseline[(sample, rt)] = run_file(os.path.join(args.originals, sample), rt)
            got = run_file(os.path.join(args.dir, entry["file"]), rt)
            if not got["ok"]:
                results[rt] = "errored"
                errors[rt] = (got["error"] or "")[:160]
            elif got["stdout"] == baseline[(sample, rt)]["stdout"]:
                results[rt] = "equivalent"
            else:
                results[rt] = "diverged"
        entry["behaviors"] = results
        if "equivalent" in results.values():
            entry["behavior"] = "equivalent"
        elif "diverged" in results.values():
            entry["behavior"] = "diverged"
        else:
            entry["behavior"] = "errored"
            entry["behaviorError"] = next(iter(errors.values()), "")
        counts[entry["behavior"]] += 1
        flag = "" if entry["behavior"] == "equivalent" else "   <-- " + entry.get("behaviorError", str(results))
        print(f"{entry['file']:58s} {entry['behavior']}{flag}")
    json.dump(manifest, open(path, "w"), indent=2)
    print(counts)
    return 0 if counts["diverged"] == 0 and counts["errored"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
