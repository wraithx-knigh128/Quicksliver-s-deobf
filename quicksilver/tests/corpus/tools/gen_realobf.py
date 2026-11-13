"""Generate real output of RealObfuscator (https://github.com/linkoro57/RealObfuscator, Rust, GPL-3.0-only) for the corpus samples.

The tool is third-party code. Nothing of it is run on the host: its sources are read as text, its crates are DOWNLOADED (not built) with `cargo vendor`, and the
build and every run happen in sandbox_run.py (no network, no host files, every capability dropped):

  1. cargo vendor --locked ../vendor                         (host: downloads crate sources, runs nothing of theirs)
  2. sandbox_run.py --tool <dir with src/ and vendor/> --work <dir> --ro <rustup toolchain>:/mnt/rust --env CARGO_HOME=/mnt/work/cargo-home ...
        -- /mnt/rust/bin/cargo build --release --offline --manifest-path /mnt/tool/src/Cargo.toml        (a config.toml in CARGO_HOME points crates-io at /mnt/tool/vendor)
  3. python -I gen_realobf.py --binary <target/release/realobfuscator> --repo <clone> --out ../obfuscated-local

The output goes to obfuscated-local/ (git-ignored): the tool is GPL-3.0 and its output carries its watermark, and a fixture committed to this repository would not be
reproducible without the same build. Configurations are the tool's own modes; the seed is fixed.
"""
import argparse, hashlib, json, os, shutil, subprocess, sys, tempfile
import importlib.util

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("sandbox_run", os.path.join(HERE, "sandbox_run.py"))
sb = importlib.util.module_from_spec(spec); spec.loader.exec_module(sb)

SEED = 1337
CONFIGS = {
    "rename": ["--mode", "rename"],
    "lightweight": ["--mode", "lightweight"],
    "native": ["--mode", "native"],
    "vm": ["--mode", "vm"],
    "vm-max": ["--mode", "vm", "--vm-hardening", "max", "--vm-rolling", "--vm-packed"],
    "vm-cached": ["--mode", "vm", "--vm-cached", "--vm-unpacked"],
}
SAMPLES = ["s01_minify_basic", "s02_renamed_vars", "s03_encoded_strings", "s04_control_flow", "s05_nested_functions", "s06_combined", "s07_roblox_style"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--binary", required=True)
    ap.add_argument("--repo", required=True, help="the clone the binary was built from (for the revision and version)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--originals", default=os.path.join(HERE, "..", "originals"))
    ap.add_argument("--max-bytes", type=int, default=700_000)
    ap.add_argument("--timeout", type=int, default=120)
    args = ap.parse_args()
    if not sb.available():
        print("no namespaces here: nothing was run", file=sys.stderr)
        return 3
    rev = subprocess.run(["git", "-C", args.repo, "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
    date = subprocess.run(["git", "-C", args.repo, "log", "-1", "--format=%ad", "--date=short"], capture_output=True, text=True, check=True).stdout.strip()
    version = "unknown"
    for line in open(os.path.join(args.repo, "Cargo.toml")):
        if line.startswith("version"):
            version = line.split('"')[1]
            break
    out_dir = os.path.join(args.out, "realobfuscator-" + version)
    os.makedirs(out_dir, exist_ok=True)
    manifest = {"tool": "RealObfuscator", "version": version, "source": "https://github.com/linkoro57/RealObfuscator", "licence": "GPL-3.0-only", "sourceRevision": rev, "revisionDate": date,
                "runtime": "Rust binary built offline in tests/corpus/tools/sandbox_run.py and run there; the output is Luau", "seed": SEED, "entries": []}
    with tempfile.TemporaryDirectory() as tmp:
        tool = os.path.join(tmp, "tool")
        os.makedirs(tool)
        shutil.copy(args.binary, os.path.join(tool, "realobfuscator"))
        os.chmod(os.path.join(tool, "realobfuscator"), 0o755)
        for sample in SAMPLES:
            original = open(os.path.join(args.originals, sample + ".lua"), "rb").read()
            for label, flags in CONFIGS.items():
                fname = f"{sample}__{label}.lua"
                entry = {"file": fname, "sample": sample + ".lua", "config": label, "flags": flags, "sampleSha256": hashlib.sha256(original).hexdigest()}
                work = os.path.join(tmp, "work")
                os.makedirs(work, exist_ok=True)
                for f in os.listdir(work):
                    os.remove(os.path.join(work, f))
                open(os.path.join(work, "in.lua"), "wb").write(original)
                try:
                    r = sb.run(tool, work, ["/mnt/tool/realobfuscator", "/mnt/work/in.lua", "-o", "/mnt/work/out.lua", "--seed", str(SEED), "--quiet"] + flags, timeout=args.timeout)
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
                print(f"{fname:50s} {entry['status']:12s} {entry.get('bytes', entry.get('error', ''))}")
    json.dump(manifest, open(os.path.join(out_dir, "manifest.json"), "w"), indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
