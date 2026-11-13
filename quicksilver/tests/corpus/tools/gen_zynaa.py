"""Generate real output of zynaa/LuaObfuscator (https://github.com/zynaa/LuaObfuscator, Python, no licence stated; "Beta 1.0.3") for the corpus samples.

Written for Garry's Mod in 2016 and published in 2018; it has two commits, so both are run. Third-party code: it is run only through sandbox_run.py
(no network, no host files, a read-only copy from `git archive`, every capability dropped). Its own command line copies the result to the clipboard and picks the
XOR key of its string cipher with `random`; here the clipboard is switched off (`--dontcopy`) and `random` is seeded, so a build can be repeated.

  python -I gen_zynaa.py --repo /path/to/LuaObfuscator --out ../obfuscated-local [--only 2018-08]

Levels 0 to 3 are the tool's own (`--level`): 0 plain strings, 1 small, 2 recommended, 3 invisible strings. The identifiers it writes are U+202A characters.
Output goes to obfuscated-local/: the repository states no licence.
"""
import argparse, hashlib, importlib.util, io, json, os, subprocess, sys, tarfile, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("sandbox_run", os.path.join(HERE, "sandbox_run.py"))
sb = importlib.util.module_from_spec(spec); spec.loader.exec_module(sb)

SEED = 1337
REVISIONS = {
    "2016-06": ("3d168a6", "the first commit (2016-06-09)"),
    "2018-08": ("b0ff84e", "`Removed recursion from dot_to_index` (2018-08-15), the current revision"),
}
LEVELS = ["0", "1", "2", "3"]
SAMPLES = ["s01_minify_basic", "s02_renamed_vars", "s03_encoded_strings", "s04_control_flow", "s05_nested_functions", "s06_combined", "s07_roblox_style"]
RUNNER = ("import random, sys, runpy; random.seed(%d); sys.path.insert(0, '/mnt/tool'); sys.argv = ['__main__.py', '--input', '/mnt/work/in.lua', "
          "'--output', '/mnt/work/out.lua', '--level', '%s', '--dontcopy']; runpy.run_path('/mnt/tool/__main__.py', run_name='__main__')")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
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
            out_dir = os.path.join(args.out, "zynaa-" + version)
            os.makedirs(out_dir, exist_ok=True)
            manifest = {"tool": "zynaa/LuaObfuscator", "version": version, "source": "https://github.com/zynaa/LuaObfuscator", "licence": "none stated", "sourceRevision": full,
                        "revisionDate": date, "note": note, "runtime": "Python 3, run in tests/corpus/tools/sandbox_run.py; the output is Lua (Garry's Mod flavoured)", "seed": SEED, "entries": []}
            for sample in SAMPLES:
                original = open(os.path.join(args.originals, sample + ".lua"), "rb").read()
                for level in LEVELS:
                    label = "level-" + level
                    fname = f"{sample}__{label}.lua"
                    entry = {"file": fname, "sample": sample + ".lua", "config": label, "sampleSha256": hashlib.sha256(original).hexdigest()}
                    work = os.path.join(tmp, "work")
                    os.makedirs(work, exist_ok=True)
                    for f in os.listdir(work):
                        os.remove(os.path.join(work, f))
                    open(os.path.join(work, "in.lua"), "wb").write(original)
                    try:
                        # the tool reads globals.json and the __decrypt files by relative path, from its own folder
                        r = sb.run(tool, work, ["sh", "-c", "cd /mnt/tool && exec python3 -s -B -c \"" + (RUNNER % (SEED, level)).replace('"', '\\"') + "\""],
                                   timeout=args.timeout)
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
                    print(f"{version:8s} {fname:50s} {entry['status']:12s} {entry.get('bytes', entry.get('error', ''))}")
            json.dump(manifest, open(os.path.join(out_dir, "manifest.json"), "w"), indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
