"""Generate MIXED (layered) obfuscation fixtures: real Hercules output stacked with packers and with the laboratory's transformations,
in both orders, across Hercules versions.

Real-world scripts are rarely one tool's output: they are packed after obfuscation, obfuscated twice, or run through a home-made step first.
Each chain below is applied to every original sample; the outermost layer is what an analyst sees first. A chain is written as a list of stages:

    ("hercules", "<version>", "<module,module>")     real Hercules (gen_hercules_versions.py REVISIONS, or "head" for the current revision)
    ("loader", "<technique>")                        a packer of gen_loaders.mjs (written for this project)
    ("lab", "<id>")                                  a transformation of tools/lab/transforms.mjs

  python -I gen_mixed.py --repo /path/to/hercules-obfuscator --out ../obfuscated/mixed
"""
import argparse, hashlib, importlib.util, io, json, os, subprocess, sys, tarfile, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
spec = importlib.util.spec_from_file_location("ghv", os.path.join(HERE, "gen_hercules_versions.py"))
ghv = importlib.util.module_from_spec(spec); spec.loader.exec_module(ghv)

CHAINS = {
    # real obfuscator, then a packer
    "hercules-light+base64": [("hercules", "head", "variable_renaming,compressor"), ("loader", "base64")],
    "hercules-balanced+xor": [("hercules", "head", "variable_renaming,control_flow,string_encoding,opaque_predicates,compressor"), ("loader", "xor")],
    "hercules-vm+base64": [("hercules", "head", "virtual_machine"), ("loader", "base64")],
    # a packer, then a real obfuscator over the packed script
    "xor+hercules-strings": [("loader", "xor"), ("hercules", "head", "string_encoding,compressor")],
    "base64+hercules-renaming": [("loader", "base64"), ("hercules", "head", "variable_renaming,wrap_in_function")],
    # the same tool twice, and across versions
    "hercules-heavy+light": [("hercules", "head", "variable_renaming,control_flow,string_encoding,string_to_expressions,opaque_predicates,garbage_code,function_inlining,wrap_in_function,antitamper,dynamic_code,compressor"), ("hercules", "head", "variable_renaming,compressor")],
    "hercules-1.6.2+head": [("hercules", "1.6.2", "variable_renaming,control_flow,string_encoding,compressor"), ("hercules", "head", "variable_renaming,string_to_expressions,compressor")],
    "hercules-1.5+head-inlining": [("hercules", "1.5", "variable_renaming,string_encoding,compressor"), ("hercules", "head", "function_inlining,variable_renaming")],
    # a home-made step (the laboratory's catalogue) before or after a real tool
    "lab-rename-strings+hercules": [("lab", "stack-rename-strings"), ("hercules", "head", "variable_renaming,control_flow,compressor")],
    "hercules-s2e+lab-flatten": [("hercules", "head", "string_to_expressions,variable_renaming"), ("lab", "flatten-chain")],
    "lab-tabledispatch+hercules-inlining": [("lab", "tabledispatch"), ("hercules", "head", "function_inlining,variable_renaming,compressor")],
    "lab-xorpack-loadwrap+layered": [("lab", "stack-xorpack-loadwrap"), ("loader", "layered")],
    "lab-flatten-opaque+hercules": [("lab", "stack-flatten-opaque"), ("hercules", "head", "variable_renaming,string_encoding,garbage_code,compressor")],
    # three layers
    "lab+hercules+base64": [("lab", "stack-rename-strings"), ("hercules", "head", "control_flow,string_encoding,compressor"), ("loader", "base64")],
    "base64+hercules-vm+hercules-light": [("loader", "base64"), ("hercules", "head", "virtual_machine"), ("hercules", "head", "variable_renaming,compressor")],
}
SAMPLES = ["s01_minify_basic", "s02_renamed_vars", "s03_encoded_strings", "s04_control_flow", "s05_nested_functions", "s06_combined", "s07_roblox_style"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--originals", default=os.path.join(HERE, "..", "originals"))
    ap.add_argument("--max-bytes", type=int, default=600_000)
    args = ap.parse_args()
    import lupa.lua54 as L

    revs = {v: r for v, (r, _) in ghv.REVISIONS.items()}
    revs["head"] = "HEAD"
    srcs = {}
    tmp = tempfile.TemporaryDirectory()
    for v, rev in revs.items():
        tar = subprocess.run(["git", "-C", args.repo, "archive", rev, "src"], capture_output=True, check=True).stdout
        d = os.path.join(tmp.name, v)
        os.makedirs(d)
        tarfile.open(fileobj=io.BytesIO(tar)).extractall(d, filter="data")
        srcs[v] = os.path.join(d, "src")
    head_rev = subprocess.run(["git", "-C", args.repo, "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()

    def stage(code, st, seed):
        if st[0] == "hercules":
            _, ver, modules = st
            # a configuration with exactly these modules on
            driver = "local src_dir, code, mods, seed = ...\n" + ghv.LUA_DRIVER.split("local src_dir, code, mode, only, seed = ...")[1].split("local names = {}")[0] + r'''
local sel = {}
for k in mods:gmatch("[^,]+") do sel[k] = true end
-- modules are named by their config key (older revisions) or by manifest key (2.x); accept both
local keys = {}
for key, value in pairs(config.settings) do if type(value) == "table" and value.enabled ~= nil then keys[#keys + 1] = key end end
local alias = { virtual_machine = "VirtualMachine", string_to_expressions = "StringToExpressions", wrap_in_function = "WrapInFunction", antitamper = "anti_tamper" }
for _, key in ipairs(keys) do
  local on = false
  for m in pairs(sel) do if m == key or alias[m] == key or (m == "antitamper" and key == "antitamper") then on = true end end
  config.settings[key].enabled = on
end
if config.settings.final_print ~= nil then config.settings.final_print = false end
math.randomseed(seed)
return Pipeline.process(code)
'''
            rt = L.LuaRuntime(encoding=None, register_eval=False, register_builtins=False)
            fn = rt.eval(b"function(...) " + driver.encode() + b" end")
            out = fn(srcs[ver].encode(), code, modules.encode(), ghv.SEED + seed)
            return out.encode("latin-1") if isinstance(out, str) else out
        p = subprocess.run(["node", os.path.join(ROOT, "tools", "formats", "stage.mjs"), st[0], st[1], str(seed)], input=code, capture_output=True, cwd=ROOT)
        if p.returncode:
            raise RuntimeError(p.stderr.decode("latin-1")[-200:])
        return p.stdout

    os.makedirs(args.out, exist_ok=True)
    manifest = {"tool": "Mixed (layered) obfuscation", "synthetic": False,
                "source": "real Hercules output (https://github.com/zeusssz/hercules-obfuscator, revision %s and the older revisions in gen_hercules_versions.py) stacked with this project's packers (gen_loaders.mjs) and laboratory transformations (tools/lab/transforms.mjs)" % head_rev,
                "chains": {k: [list(s) for s in v] for k, v in CHAINS.items()}, "entries": []}
    for sample in SAMPLES:
        original = open(os.path.join(args.originals, sample + ".lua"), "rb").read()
        for cid, chain in CHAINS.items():
            fname = f"{sample}__{cid}.lua"
            entry = {"file": fname, "sample": sample + ".lua", "config": cid, "layers": len(chain), "sampleSha256": hashlib.sha256(original).hexdigest()}
            try:
                code = original
                for i, st in enumerate(chain):
                    code = stage(code, st, i + 1)
                    if code is None:
                        raise RuntimeError("stage %d returned nothing" % (i + 1))
                if len(code) > args.max_bytes:
                    entry.update(status="omitted-large", bytes=len(code))
                else:
                    open(os.path.join(args.out, fname), "wb").write(code)
                    entry.update(status="ok", bytes=len(code))
            except Exception as exc:
                entry.update(status="tool-error", error=str(exc)[:240])
            manifest["entries"].append(entry)
            print(f"{fname:70s} {entry['status']:12s} {entry.get('bytes', entry.get('error', ''))}")
    json.dump(manifest, open(os.path.join(args.out, "manifest.json"), "w"), indent=1)


if __name__ == "__main__":
    sys.exit(main())
