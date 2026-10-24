"""Generate *real* IronBrew 2 output for the original corpus samples.

IronBrew 2 (https://github.com/Trollicus/ironbrew-2, MIT) is a C# program. This script builds it from its own
source and runs it, unmodified, through `ironbrew2/Ib2Driver.cs`, which only exposes `ObfuscationSettings`
as command-line flags.

What it needs (none of it is part of this repository):

  * a .NET Core 3.1 *runtime* (the tool targets netcoreapp3.1; the runtime inside the PyPI wheel
    `dotnetcore2==3.1.23` is enough, unpack it with `python -I -m zipfile -e`),
  * the Roslyn C# compiler (`csc.dll` from the NuGet package Microsoft.Net.Compilers.Toolset),
  * OpenSSL 1.1 shared libraries on LD_LIBRARY_PATH (the 3.1 runtime does not load OpenSSL 3),
  * a checkout of the IronBrew 2 sources,
  * `luac` (PUC Lua 5.1) and `luajit` on /usr/bin: IronBrew 2 shells out to both by that path.
    `ironbrew2/luac_shim.py` and `ironbrew2/luajit_shim.py` are lupa-based stand-ins; symlink or copy them there.

  python -I gen_ironbrew2.py --dotnet-root DIR --csc csc.dll --src IRONBREW2_CHECKOUT --work WORKDIR \
         --out ../obfuscated/ironbrew2 [--commit SHA]

IronBrew 2 seeds its random generators from the clock, so every run produces different output. The files in
../obfuscated/ironbrew2 are therefore frozen artefacts; manifest.json records the settings of each one.
Verify them afterwards with verify_fixtures.py.
"""
import argparse
import glob
import hashlib
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

VARIANTS = {
    "default": [],
    "plain": ["--no-flow", "--no-mutate", "--no-super"],
    "mutate": ["--no-flow", "--no-super"],
    "super": ["--no-flow", "--no-mutate"],
    "flow": ["--no-mutate", "--no-super"],
    "strings": ["--strings"],
    "lineinfo": ["--lineinfo"],
    "nocompress": ["--no-compress"],
}


def build(args, env, dn):
    fw = glob.glob(os.path.join(args.dotnet_root, "shared", "Microsoft.NETCore.App", "*"))[0]
    refs = [f"-r:{p}" for p in sorted(glob.glob(os.path.join(fw, "*.dll")))
            if os.path.basename(p).split(".")[0] in ("System", "Microsoft", "mscorlib", "netstandard", "WindowsBase")]
    lib = os.path.join(args.work, "lib")
    run = os.path.join(args.work, "run", "cli")
    os.makedirs(lib, exist_ok=True)
    os.makedirs(run, exist_ok=True)
    sources = []
    for root, _dirs, files in os.walk(os.path.join(args.src, "IronBrew2")):
        if os.sep + "obj" in root or os.sep + "bin" in root:
            continue
        sources += [os.path.join(root, f) for f in files if f.endswith(".cs")]
    rsp = os.path.join(args.work, "lib.rsp")
    with open(rsp, "w") as fh:
        fh.write("\n".join(f'"{s}"' for s in sorted(sources)))
    nowarn = "-nowarn:CS8632,CS0168,CS0219,CS0649,CS0169,CS0414"
    subprocess.run([dn, args.csc, "-nologo", "-target:library", f"-out:{lib}/IronBrew2.dll", "-langversion:latest", nowarn, *refs, f"@{rsp}"], check=True, env=env)
    shutil.copy(os.path.join(lib, "IronBrew2.dll"), run)
    subprocess.run([dn, args.csc, "-nologo", "-target:exe", f"-out:{run}/Ib2Driver.dll", "-langversion:8", *refs, f"-r:{lib}/IronBrew2.dll",
                    os.path.join(HERE, "ironbrew2", "Ib2Driver.cs")], check=True, env=env)
    with open(os.path.join(run, "Ib2Driver.runtimeconfig.json"), "w") as fh:
        json.dump({"runtimeOptions": {"tfm": "netcoreapp3.1", "framework": {"name": "Microsoft.NETCore.App", "version": "3.1.0"}}}, fh)
    # IronBrew 2 runs luasrcdiet from ../Lua/Minifier relative to its working directory
    dest = os.path.join(args.work, "run", "Lua")
    if os.path.exists(dest):
        shutil.rmtree(dest)
    shutil.copytree(os.path.join(args.src, "Lua"), dest)
    return run


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dotnet-root", required=True)
    ap.add_argument("--csc", required=True)
    ap.add_argument("--src", required=True)
    ap.add_argument("--work", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--openssl-dir", default="")
    ap.add_argument("--originals", default=os.path.join(HERE, "..", "originals"))
    ap.add_argument("--commit", default="unknown")
    ap.add_argument("--only", default="", help="comma separated variant labels")
    ap.add_argument("--samples", default="", help="comma separated sample file names; the entries of the other samples in an existing manifest are kept")
    args = ap.parse_args()

    env = dict(os.environ, DOTNET_ROOT=args.dotnet_root, DOTNET_SYSTEM_GLOBALIZATION_INVARIANT="1", DOTNET_CLI_TELEMETRY_OPTOUT="1")
    if args.openssl_dir:
        env["LD_LIBRARY_PATH"] = args.openssl_dir
    dn = os.path.join(args.dotnet_root, "dotnet")
    for tool in ("/usr/bin/luac", "/usr/bin/luajit"):
        if not os.path.exists(tool):
            print(f"missing {tool}: see the docstring (ironbrew2/*_shim.py)", file=sys.stderr)
            return 2
    run = build(args, env, dn)

    os.makedirs(args.out, exist_ok=True)
    manifest = {"tool": "IronBrew 2", "version": "2.7.0", "source": "https://github.com/Trollicus/ironbrew-2",
                "sourceRevision": args.commit, "runtime": "built from source: .NET Core 3.1.23 runtime, Roslyn csc, luac/luajit via lupa shims",
                "seed": None, "entries": []}
    wanted = [v for v in args.only.split(",") if v] or list(VARIANTS)
    only_samples = [x for x in args.samples.split(",") if x]
    kept = []
    mpath = os.path.join(args.out, "manifest.json")
    if only_samples and os.path.exists(mpath):
        kept = [e for e in json.load(open(mpath))["entries"] if e["sample"] not in only_samples]
    manifest["entries"] = kept
    for sample in sorted(f for f in os.listdir(args.originals) if f.endswith(".lua") and (not only_samples or f in only_samples)):
        original = open(os.path.join(args.originals, sample), "rb").read()
        for label in wanted:
            flags = VARIANTS[label]
            fname = f"{sample[:-4]}__{label}.lua"
            outp = os.path.abspath(os.path.join(args.out, fname))
            entry = {"file": fname, "sample": sample, "config": label, "flags": flags, "sampleSha256": hashlib.sha256(original).hexdigest()}
            proc = subprocess.run([dn, "Ib2Driver.dll", os.path.abspath(os.path.join(args.originals, sample)), outp, *flags],
                                  cwd=run, env=env, capture_output=True, text=True)
            if proc.returncode != 0 or not os.path.exists(outp):
                entry.update(status="tool-error", error=(proc.stderr or proc.stdout)[-300:])
            else:
                entry.update(status="ok", bytes=os.path.getsize(outp))
            manifest["entries"].append(entry)
            print(f"{fname:52s} {entry['status']:10s} {entry.get('bytes', entry.get('error', ''))}")
    json.dump(manifest, open(os.path.join(args.out, "manifest.json"), "w"), indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
