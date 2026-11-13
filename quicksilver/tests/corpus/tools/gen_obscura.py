"""Generate real Obscura output (https://github.com/vo3pal/obscura, MIT) for the corpus samples, for each revision that can still be run.

Obscura is a Luau obfuscator written in Python. The repository has no tags; its version is what main.py says (`--version`), so the revisions below are the commits
that mark a state of the tool. The tool is third-party code: it is run only through sandbox_run.py (no network, no host files, a read-only copy of the revision from
`git archive`, every capability dropped), never directly.

  python -I gen_obscura.py --repo /path/to/obscura --site /path/with/click --out ../obfuscated [--only 1.1.0]

Configurations (the same names across revisions where the interface allows):
  level-1 / level-2 / level-3   protection levels (identifiers, strings, numbers / + control-flow flattening, predicates, dead code / + indirection, anti-tamper)
  lightweight                   renames, minifies, decodes strings at start-up
  vm / vm-max                   the virtual-machine pipeline (basic profile / max profile)
  rename, native, vm-cached     1.1.0 only
"""
import argparse, hashlib, importlib.util, io, json, os, subprocess, sys, tarfile, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("sandbox_run", os.path.join(HERE, "sandbox_run.py"))
sb = importlib.util.module_from_spec(spec); spec.loader.exec_module(sb)

SEED = 1337
REVISIONS = {
    "1.0.0": ("1439a3d", "the state before the VM hardening release (2026-04-29): VM with an encrypted constant pool, --level 1-4, --vm"),
    "1.0.1": ("abd77f0", "v1.0.1 (2026-04-30): VM hardening (lazy constants, split keys, integrity checks), --vm-hardening"),
    "1.1.0": ("5657a73", "v1.1.0 (2026-10-08): --mode lightweight/rename/native/vm, rolling bytecode reads by default"),
}
CONFIGS = {
    "1.0.0": {"level-1": ["--level", "1"], "level-2": ["--level", "2"], "level-3": ["--level", "3"], "lightweight": ["--lightweight"], "vm": ["--vm"]},
    "1.0.1": {"level-1": ["--level", "1"], "level-2": ["--level", "2"], "level-3": ["--level", "3"], "lightweight": ["--lightweight"], "vm": ["--vm", "--vm-hardening", "basic"], "vm-max": ["--vm", "--vm-hardening", "max"]},
    "1.1.0": {"level-1": ["--level", "1"], "level-2": ["--level", "2"], "level-3": ["--level", "3"], "lightweight": ["--mode", "lightweight"], "rename": ["--mode", "rename"], "native": ["--mode", "native"],
              "vm": ["--vm"], "vm-max": ["--mode", "vm"], "vm-cached": ["--mode", "vm", "--vm-cached"]},
}
SAMPLES = ["s01_minify_basic", "s02_renamed_vars", "s03_encoded_strings", "s04_control_flow", "s05_nested_functions", "s06_combined", "s07_roblox_style"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--site", required=True, help="a folder holding the `click` package (pip install --target)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--originals", default=os.path.join(HERE, "..", "originals"))
    ap.add_argument("--only", default="")
    ap.add_argument("--max-bytes", type=int, default=500_000)
    ap.add_argument("--timeout", type=int, default=120)
    args = ap.parse_args()
    if not sb.available():
        print("no namespaces here: nothing was run", file=sys.stderr)
        return 3
    for version, (rev, note) in REVISIONS.items():
        if args.only and version != args.only:
            continue
        full = subprocess.run(["git", "-C", args.repo, "rev-parse", rev], capture_output=True, text=True, check=True).stdout.strip()
        date = subprocess.run(["git", "-C", args.repo, "log", "-1", "--format=%ad", "--date=short", rev], capture_output=True, text=True, check=True).stdout.strip()
        with tempfile.TemporaryDirectory() as tmp:
            tool = os.path.join(tmp, "tool")
            os.makedirs(tool)
            tarfile.open(fileobj=io.BytesIO(subprocess.run(["git", "-C", args.repo, "archive", rev], capture_output=True, check=True).stdout)).extractall(tool, filter="data")
            out_dir = os.path.join(args.out, "obscura-" + version)
            os.makedirs(out_dir, exist_ok=True)
            manifest = {"tool": "Obscura", "version": version, "source": "https://github.com/vo3pal/obscura", "sourceRevision": full, "revisionDate": date, "note": note,
                        "runtime": "Python 3 + click, run in tests/corpus/tools/sandbox_run.py; the output is Luau", "seed": SEED, "entries": []}
            for sample in SAMPLES:
                original = open(os.path.join(args.originals, sample + ".lua"), "rb").read()
                for label, flags in CONFIGS[version].items():
                    fname = f"{sample}__{label}.lua"
                    entry = {"file": fname, "sample": sample + ".lua", "config": label, "flags": flags, "sampleSha256": hashlib.sha256(original).hexdigest()}
                    work = os.path.join(tmp, "work")
                    os.makedirs(work, exist_ok=True)
                    for f in os.listdir(work):
                        os.remove(os.path.join(work, f))
                    open(os.path.join(work, "in.lua"), "wb").write(original)
                    try:
                        r = sb.run(tool, work, ["python3", "-s", "-B", "/mnt/tool/main.py", "-i", "/mnt/work/in.lua", "-o", "/mnt/work/out.lua", "--seed", str(SEED), "-q"] + flags,
                                   ro=[(os.path.abspath(args.site), "/mnt/site")], timeout=args.timeout, extra_env={"PYTHONPATH": "/mnt/site"})
                        dst = os.path.join(work, "out.lua")
                        if r["timedOut"] or r["returncode"] != 0 or not os.path.exists(dst):
                            raise RuntimeError(("timed out" if r["timedOut"] else (r["stderr"] or r["stdout"]))[-240:])
                        out = open(dst, "rb").read()
                        if len(out) > args.max_bytes:
                            entry.update(status="omitted-large", bytes=len(out))
                        else:
                            open(os.path.join(out_dir, fname), "wb").write(out)
                            entry.update(status="ok", bytes=len(out))
                    except Exception as exc:
                        entry.update(status="tool-error", error=str(exc)[:240].replace("\n", " "))
                    manifest["entries"].append(entry)
                    print(f"{version:6s} {fname:50s} {entry['status']:12s} {entry.get('bytes', entry.get('error', ''))}")
            json.dump(manifest, open(os.path.join(out_dir, "manifest.json"), "w"), indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
