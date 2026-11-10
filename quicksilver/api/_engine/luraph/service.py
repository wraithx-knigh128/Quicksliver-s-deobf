"""QuickSilver reconstruction service: runs the vendored Luraph / IronBrew engine for one upload.

Everything the website needs from the engine goes through `reconstruct()`: identify the input, choose an engine, run it
in a separate, limited process, fall back where that is honest, check what came out, and (when the person supplied the
original) compare behaviour on a real Luau runtime. The engine itself (deobf/) is unchanged except for the patches
listed in NOTICE.md; it is a dynamic analyser, so it RUNS the protected script, inside a fake Roblox environment, in a
Luau VM. That is why every run is a separate process with a wall clock, a CPU and a memory limit and, where the host
allows it, no network namespace.

Nothing here claims a reconstruction is correct. `kind` says how the text was produced (lifted from the VM, or a trace
of what one run did), `quality` counts what is visibly unresolved, and only `verification.status == "identical"` means
a reconstruction was compared with its original on a reference runtime and behaved the same.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEOBF = HERE / "deobf"
MAX_INPUT_BYTES = int(os.environ.get("QS_RECONSTRUCT_MAX_BYTES", 3 * 1024 * 1024))
MAX_TIMEOUT_S = int(os.environ.get("QS_RECONSTRUCT_MAX_SECONDS", 240))
DEFAULT_TIMEOUT_S = 90
ENGINE_MEM_MB = int(os.environ.get("QS_ENGINE_MEM_MB", 3072))

# engine id -> how to run it. `label` is what the page shows; `family` groups versions of one product.
ENGINES = {
    "luraph_v14_7": {"front": "cli", "args": ["--engine", "14.7"], "label": "Luraph v14.7", "family": "luraph", "version": "14.7"},
    "luraph_v14_8": {"front": "cli", "args": ["--engine", "14.8"], "label": "Luraph v14.8", "family": "luraph", "version": "14.8"},
    "luraph_v14_9": {"front": "cli", "args": ["--engine", "14.9"], "label": "Luraph v14.9", "family": "luraph", "version": "14.9"},
    "luraph_v15": {"front": "deob", "args": ["--obfuscator", "luraph_v15"], "label": "Luraph v15", "family": "luraph", "version": "15"},
    "ironbrew1": {"front": "deob", "args": ["--obfuscator", "ironbrew1"], "label": "IronBrew 1", "family": "ironbrew", "version": "1"},
    "generic": {"front": "deob", "args": ["--obfuscator", "generic"], "label": "Behaviour trace (no specific engine)", "family": "generic", "version": None},
}

BANNER = re.compile(r"This file was protected using Luraph Obfuscator v(\d+)(?:\.(\d+))?(?:\.(\d+))?")
IB1_HEADER = re.compile(r"--\s*this file was generated using ironbrew1\b", re.I)


# ---- the host ------------------------------------------------------------------------------------------------------------

_bins_cache: dict[str, str] = {}


def bin_dir() -> str:
    """A directory with executable copies of the Luau binaries. The deployed code directory may be read-only or may not keep the
    execute bit, so the binaries are copied once per process to a temporary directory and chmod'ed."""
    if "dir" in _bins_cache:
        return _bins_cache["dir"]
    override = os.environ.get("QS_LURAPH_BIN_DIR")
    if override:
        _bins_cache["dir"] = override
        return override
    src = DEOBF / "bin"
    h = hashlib.sha256()
    for n in ("luau", "luau-ast"):
        h.update(n.encode())
        h.update((src / n).read_bytes())
    dst = Path(tempfile.gettempdir()) / ("qs-luraph-bin-" + h.hexdigest()[:12])
    if not (dst / "luau").exists() or not (dst / "luau-ast").exists():
        tmp = Path(tempfile.mkdtemp(prefix="qs-bin-", dir=tempfile.gettempdir()))
        for n in ("luau", "luau-ast"):
            shutil.copy2(src / n, tmp / n)
            os.chmod(tmp / n, 0o755)
        try:
            os.rename(tmp, dst)
        except OSError:                 # another worker won the race
            shutil.rmtree(tmp, ignore_errors=True)
    _bins_cache["dir"] = str(dst)
    return str(dst)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


_isolation_cache: dict[str, list[str]] = {}


def isolation_prefix(timeout_s: int) -> list[str]:
    """Command prefix that limits a run: no network namespace (when the host allows it), address-space and CPU limits (when prlimit exists)."""
    key = "p"
    if key not in _isolation_cache:
        prefix: list[str] = []
        if shutil.which("unshare"):
            try:
                if subprocess.run(["unshare", "-rn", "true"], capture_output=True, timeout=5).returncode == 0:
                    prefix += ["unshare", "-rn"]
            except Exception:
                pass
        _isolation_cache[key] = prefix
    return list(_isolation_cache[key])


def _limits(timeout_s: int):
    """A preexec function that sets address-space and CPU limits in the child (Python's `resource`, so it needs no prlimit binary)."""
    def apply():
        try:
            import resource
            resource.setrlimit(resource.RLIMIT_AS, (ENGINE_MEM_MB << 20, ENGINE_MEM_MB << 20))
            resource.setrlimit(resource.RLIMIT_CPU, (timeout_s + 30, timeout_s + 40))
            resource.setrlimit(resource.RLIMIT_FSIZE, (256 << 20, 256 << 20))
        except Exception:
            pass
    return apply


def capabilities() -> dict:
    """What this host can do, measured now (the page and the self-test read this)."""
    info = {"python": sys.version.split()[0], "engines": {k: v["label"] for k, v in ENGINES.items()}, "limits": {
        "maxInputBytes": MAX_INPUT_BYTES, "maxSeconds": MAX_TIMEOUT_S, "defaultSeconds": DEFAULT_TIMEOUT_S, "memoryMB": ENGINE_MEM_MB}}
    try:
        d = bin_dir()
        luau = Path(d) / "luau"
        probe = Path(tempfile.gettempdir()) / "qs-luau-probe.lua"
        probe.write_text("print(_VERSION, 6 * 7, type(io), type(os.execute))")
        r = subprocess.run([str(luau), str(probe)], capture_output=True, timeout=20)
        info["luau"] = {"ok": r.returncode == 0, "output": r.stdout.decode("latin-1").strip(), "sha256": _sha256(luau), "binDir": d}
        info["luauAst"] = {"sha256": _sha256(Path(d) / "luau-ast")}
    except Exception as e:  # noqa: BLE001 - reported, not raised
        info["luau"] = {"ok": False, "error": str(e)}
    info["isolation"] = {"networkNamespace": "unshare" in isolation_prefix(10), "limits": "setrlimit (address space, cpu, file size)"}
    return info


# ---- identification ------------------------------------------------------------------------------------------------------

def _plugin_scores(text: str) -> dict[str, float]:
    """Each engine's own detector on the text."""
    if str(DEOBF) not in sys.path:
        sys.path.insert(0, str(DEOBF))
    out: dict[str, float] = {}
    try:
        from obfuscators import scores  # type: ignore
        for conf, p in scores(text):
            out[p.name] = float(conf)
    except Exception:
        pass
    for key, mod, cls in (("luraph_v14_7", "obfuscators.luraph_v14_7", "LuraphV147"), ("luraph_v14_8", "obfuscators.luraph_v14_8", "LuraphV148"),
                          ("luraph_v14_9", "obfuscators.luraph_v14_9", "LuraphV149")):
        try:
            m = __import__(mod, fromlist=[cls])
            out[key] = float(getattr(m, cls)().detect(text))
        except Exception:
            out[key] = 0.0
    return out


def identify(source: bytes) -> dict:
    """What the input is, from its banner and from each engine's own detector. Never executes anything."""
    text = source.decode("latin-1")
    head = text[:4096]
    m = BANNER.search(head)
    banner = None
    if m:
        banner = {"text": m.group(0), "version": ".".join(x for x in (m.group(1), m.group(2), m.group(3)) if x is not None),
                  "major": int(m.group(1)), "minor": int(m.group(2)) if m.group(2) is not None else None}
    sc = _plugin_scores(text)
    cands = []
    for eid in ("luraph_v15", "luraph_v14_9", "luraph_v14_8", "luraph_v14_7", "ironbrew1"):
        c = sc.get(eid, 0.0)
        if c > 0:
            cands.append({"engine": eid, "confidence": round(c, 2), "basis": "engine detector"})
    cands.sort(key=lambda c: -c["confidence"])
    notes = []
    if banner:
        notes.append("A banner comment names the version. It is text the file's owner controls: it says what the file claims.")
    if IB1_HEADER.search(head):
        notes.append("The header names IronBrew 1.")
    return {"banner": banner, "candidates": cands, "bytes": len(source), "sha256": hashlib.sha256(source).hexdigest(), "notes": notes}


def plan(ident: dict, requested: str = "auto", allow_fallback: bool = True) -> list[dict]:
    """The engines to try, in order, each with the reason and an honest label. First entry is the choice; the rest are fallbacks."""
    if requested and requested != "auto":
        if requested not in ENGINES:
            raise ValueError("unknown engine %r" % requested)
        steps = [{"engine": requested, "mode": "lift", "why": "chosen by you", "tested": None}]
        if requested != "generic":
            steps.append({"engine": requested, "mode": "trace", "why": "same engine, behaviour trace only", "tested": None})
        return steps
    b = ident.get("banner")
    top = ident["candidates"][0] if ident["candidates"] else None
    steps: list[dict] = []
    if b and b["major"] == 14:
        order = ["luraph_v14_%d" % n for n in (b["minor"],) if n in (7, 8, 9)]
        near = [e for e in ("luraph_v14_9", "luraph_v14_8", "luraph_v14_7") if e not in order]
        if order:
            steps.append({"engine": order[0], "mode": "lift", "why": "banner names v%s" % b["version"]})
            if allow_fallback:
                steps += [{"engine": e, "mode": "lift", "why": "neighbouring v14 engine (the three are close relatives; used only because %s produced no source)" % order[0], "nearest": True} for e in near]
        else:
            steps.append({"engine": near[0], "mode": "lift", "why": "banner names v%s, which has no engine; the nearest engine is tried and the result is experimental" % b["version"], "nearest": True})
            if allow_fallback:
                steps += [{"engine": e, "mode": "lift", "why": "neighbouring v14 engine", "nearest": True} for e in near[1:]]
        if allow_fallback:
            steps.append({"engine": steps[0]["engine"], "mode": "trace", "why": "behaviour trace of the first engine (what one run did, not the program)"})
    elif b and b["major"] == 15:
        steps.append({"engine": "luraph_v15", "mode": "lift", "why": "banner names v%s" % b["version"], "nearest": b["minor"] not in (None, 0)})
        if allow_fallback:
            steps.append({"engine": "luraph_v15", "mode": "trace", "why": "behaviour trace (what one run did, not the program)"})
    elif top and top["confidence"] >= 0.5:
        steps.append({"engine": top["engine"], "mode": "lift", "why": "the engine's own detector (%.2f), no usable banner" % top["confidence"]})
        if allow_fallback:
            steps.append({"engine": top["engine"], "mode": "trace", "why": "behaviour trace (what one run did, not the program)"})
    else:
        steps.append({"engine": "generic", "mode": "trace", "why": "no engine recognised the input; only a behaviour trace is possible"})
    return steps


# ---- running an engine ---------------------------------------------------------------------------------------------------

STAGE_ORDER = ["identify", "select", "run", "lift", "structure", "check", "verify", "report"]
STAGE_LABEL = {"identify": "Identify the input", "select": "Choose the engine", "run": "Run in the instrumented environment", "lift": "Lift the virtual machine",
               "structure": "Rebuild control flow and names", "check": "Check the output", "verify": "Compare with the original", "report": "Write the report"}

_LOG_STAGES = [
    (re.compile(r"tracing .*\(run (\d+)\)|tracing "), "run"),
    (re.compile(r"Path2D answers|constants decoded"), "run"),
    (re.compile(r"devirt round (\d+)"), "lift"),
    (re.compile(r"devirtualizing \(round"), "structure"),
    (re.compile(r"\[\+\] (result|wrote)"), "structure"),
]


class Run:
    def __init__(self, emit, cancelled=lambda: False):
        self.emit = emit
        self.cancelled = cancelled      # true once the client has gone: the engine process is killed instead of running to its time limit
        self.was_cancelled = False
        self.stage = None
        self.t0 = time.time()
        self.log: list[str] = []

    def stage_start(self, sid, detail=None):
        if self.stage == sid:
            if detail:
                self.emit({"t": "stage", "id": sid, "state": "running", "detail": detail})
            return
        if self.stage:
            self.emit({"t": "stage", "id": self.stage, "state": "done"})
        self.stage = sid
        self.emit({"t": "stage", "id": sid, "state": "running", "label": STAGE_LABEL[sid], "detail": detail})

    def stage_done(self, sid, state="done", detail=None):
        self.emit({"t": "stage", "id": sid, "state": state, "detail": detail})
        if self.stage == sid:
            self.stage = None

    def line(self, text):
        text = text.rstrip("\n")
        if not text:
            return
        if len(self.log) < 400:
            self.log.append(text[:300])
        self.emit({"t": "log", "line": text[:300]})
        for rx, sid in _LOG_STAGES:
            m = rx.search(text)
            if m:
                detail = text.split("] ", 1)[-1][:120]
                self.stage_start(sid, detail)
                break


def _run_process(cmd, cwd, env, deadline, run: Run):
    """Run `cmd`, stream its stderr into the run log, kill it at the deadline. Returns (returncode, timed_out, stdout)."""
    p = subprocess.Popen(cmd, cwd=cwd, env=env, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True, preexec_fn=_limits(max(10, int(deadline - time.time()))))
    out_chunks: list[bytes] = []

    def pump_err():
        for raw in iter(p.stderr.readline, b""):
            run.line(raw.decode("utf-8", "replace"))

    def pump_out():
        out_chunks.append(p.stdout.read() or b"")

    ts = [threading.Thread(target=pump_err, daemon=True), threading.Thread(target=pump_out, daemon=True)]
    for t in ts:
        t.start()
    timed_out = False
    while p.poll() is None:
        if run.cancelled():
            run.was_cancelled = True
            try:
                os.killpg(os.getpgid(p.pid), signal.SIGKILL)
            except Exception:
                p.kill()
            break
        if time.time() > deadline:
            timed_out = True
            try:
                os.killpg(os.getpgid(p.pid), signal.SIGKILL)
            except Exception:
                p.kill()
            break
        time.sleep(0.05)
    p.wait()
    for t in ts:
        t.join(timeout=2)
    return p.returncode, timed_out, b"".join(out_chunks)


_HEADER_LINES = re.compile(r"^(-- (Reconstructed by QuickSilver|Devirtualized with Luraph|Behaviour trace:|source: ).*\n)+", re.M)


def _attempt(step, input_path: Path, work: Path, deadline, run: Run) -> dict:
    spec = ENGINES[step["engine"]]
    out_path = work / ("out_%s_%s.lua" % (step["engine"], step["mode"]))
    remaining = max(5, int(deadline - time.time()))
    py = sys.executable or "python3"
    if spec["front"] == "cli":
        cmd = [py, "-I", "cli.py", str(input_path), "-o", str(out_path), "--timeout", str(min(120, remaining)), "--no-credit"] + spec["args"]
        if step["mode"] == "trace":
            cmd += ["--trace-fallback", "--no-devirt"]
    else:
        cmd = [py, "-I", "deob.py", str(input_path), "-o", str(out_path), "--timeout", str(min(120, remaining)), "--no-pypy"] + spec["args"]
        if step["mode"] == "trace":
            cmd += ["--no-devirt"]
    cmd = isolation_prefix(remaining) + cmd
    env = {"PATH": "/usr/local/bin:/usr/bin:/bin", "HOME": str(work), "TMPDIR": str(work), "PYTHONDONTWRITEBYTECODE": "1", "PYTHONHASHSEED": "0",
           "PYTHONIOENCODING": "utf-8", "LANG": "C.UTF-8", "DEOBF_BIN_DIR": bin_dir()}
    t0 = time.time()
    run.emit({"t": "attempt", "engine": step["engine"], "mode": step["mode"], "label": spec["label"], "why": step["why"]})
    rc, timed_out, _ = _run_process(cmd, str(DEOBF), env, deadline, run)
    secs = round(time.time() - t0, 1)
    text = None
    if out_path.exists():
        text = out_path.read_text(encoding="utf-8", errors="replace")
    res = {"engine": step["engine"], "mode": step["mode"], "seconds": secs, "returnCode": rc, "timedOut": timed_out, "produced": bool(text and text.strip()), "nearest": bool(step.get("nearest"))}
    if run.was_cancelled:
        res["outcome"] = "cancelled"
    elif timed_out:
        res["outcome"] = "timeout"
    elif text and text.strip():
        res["outcome"] = "output"
    else:
        res["outcome"] = "no-output"
    return {"result": res, "text": text}


# ---- what came out -------------------------------------------------------------------------------------------------------

_UNRESOLVED = {
    "upvalueNames": re.compile(r"\bupv\d+\b"),
    "undecodedConstants": re.compile(r"constant not decoded"),
    "nilCalls": re.compile(r"\(nil\)\("),
    "runtimeStubs": re.compile(r"luraph_runtime\d+"),
    "crashMacros": re.compile(r"LPH_CRASH\(\)"),
    "notLifted": re.compile(r"not lifted|unlifted|could not be lifted", re.I),
}


def _strip_header(text: str) -> str:
    return _HEADER_LINES.sub("", text, count=1).lstrip("\n")


def assess(text: str, kind_hint: str, log: list[str]) -> dict:
    lines = text.splitlines()
    counts = {k: len(rx.findall(text)) for k, rx in _UNRESOLVED.items()}
    functions = len(re.findall(r"\bfunction\b", text))
    total = sum(counts.values())
    grade = "clean" if total == 0 else "partial" if counts["upvalueNames"] + counts["nilCalls"] + counts["undecodedConstants"] < 25 else "poor"
    return {"lines": len(lines), "bytes": len(text.encode("utf-8")), "functions": functions, "unresolved": counts, "grade": grade, "unresolvedTotal": total}


def syntax_check(text: str, work: Path) -> dict:
    path = work / "check.lua"
    path.write_text(text, encoding="utf-8")
    try:
        r = subprocess.run([str(Path(bin_dir()) / "luau-ast"), str(path)], capture_output=True, timeout=60)
    except Exception as e:  # noqa: BLE001
        return {"ok": None, "error": "syntax checker failed: %s" % e}
    head = r.stdout[:400].decode("latin-1")
    if head.startswith("Parse errors were encountered"):
        errs = [l.strip() for l in r.stdout.decode("latin-1").splitlines()[1:8] if l.strip().startswith("(")]
        return {"ok": False, "errors": errs}
    return {"ok": True, "parser": "Luau (luau-ast)"}


_WRAP = """local __qs_r = table.pack(pcall(function(...)
%s
end, ...))
print("QS_OK", tostring(__qs_r[1]))
for i = 2, __qs_r.n do print("QS_RET", i - 1, typeof(__qs_r[i]), (typeof(__qs_r[i]) == "string" or typeof(__qs_r[i]) == "number" or typeof(__qs_r[i]) == "boolean") and tostring(__qs_r[i]) or "") end
"""


def _run_luau(code: str, work: Path, timeout_s: int) -> dict:
    path = work / "v.lua"
    path.write_text(_WRAP % code, encoding="utf-8")
    cmd = isolation_prefix(timeout_s) + [str(Path(bin_dir()) / "luau"), str(path)]
    try:
        r = subprocess.run(cmd, capture_output=True, timeout=timeout_s, cwd=str(work), env={"PATH": "/usr/bin:/bin"}, preexec_fn=_limits(timeout_s))
    except subprocess.TimeoutExpired:
        return {"ok": False, "timedOut": True, "stdout": "", "stderr": "timeout"}
    return {"ok": r.returncode == 0, "timedOut": False, "stdout": r.stdout.decode("utf-8", "replace"), "stderr": r.stderr.decode("utf-8", "replace")}


def _normalise(s: str) -> str:
    s = re.sub(r"v\.lua:\d+:", "", s)
    s = re.sub(r"\[string \"[^\"]*\"\]:\d+:", "", s)
    return s.strip()


def verify_against_original(original: bytes, reconstruction: str, work: Path, timeout_s: int = 20) -> dict:
    """Run the original and the reconstruction on the Luau runtime and compare what they print and return.

    Only plain Luau can be compared this way: a script that needs Roblox objects fails the same way in both and the
    verdict is `inconclusive`, never `identical`."""
    o = _run_luau(original.decode("utf-8", "replace"), work, timeout_s)
    r = _run_luau(reconstruction, work, timeout_s)
    ev = {"runtime": "Luau (patched 0.739 build, see NOTICE.md)", "original": {k: o[k] for k in ("ok", "timedOut")}, "reconstruction": {k: r[k] for k in ("ok", "timedOut")}}
    if o["timedOut"] or r["timedOut"]:
        return {"status": "inconclusive", "reason": "a run hit the time limit", **ev}
    so, sr = _normalise(o["stdout"]), _normalise(r["stdout"])
    if "QS_OK\tfalse" in o["stdout"] or not o["ok"]:
        return {"status": "inconclusive", "reason": "the original does not run to completion on plain Luau (it needs objects Roblox provides), so there is nothing to compare", "originalOutput": so[:400], **ev}
    has_effect = len(so.splitlines()) > 1 or "QS_RET" in so
    if not has_effect:
        return {"status": "inconclusive", "reason": "the original prints and returns nothing, so equal runs would show nothing", **ev}
    if so == sr:
        return {"status": "identical", "reason": "same output and same return values on this runtime", "observed": so[:600], **ev}
    return {"status": "different", "reason": "the reconstruction behaves differently from the original", "original": so[:600], "reconstruction": sr[:600], **ev}


# ---- diagnostics (rule-based: always on, no model involved) -------------------------------------------------------------

_DIAG_RULES = [
    (re.compile(r"devirtualization produced no source"), "lift-failed", "error", "The engine could not lift the virtual machine.",
     "The script ran, but the engine found no program it could rebuild. Try another engine version, or send the log to the research assistant."),
    (re.compile(r"refusing v14 static output|VM/bootstrap scaffolding|probe-only"), "scaffolding-root", "warning", "The part that was lifted is Luraph's own bootstrap or environment probe, not your script.",
     "A trace of what the script did may still be available. The engine is not sure which function is the script."),
    (re.compile(r"unresolved VM state|unlifted blocks?, [1-9]"), "partial-lift", "warning", "Some virtual-machine states could not be resolved, so parts of the program are missing or approximate.", "Read the output with that in mind; unresolved names appear as upvN."),
    (re.compile(r"anti-tamper (?:trigger|trap).*(giving up|fired again)"), "tamper-trap", "error", "An anti-tamper check kept firing.", "The emulated environment differs from Roblox in something this script checks."),
    (re.compile(r"attempt to call a nil value"), "env-api-missing", "error", "The script called something the emulated Roblox environment does not provide.", "This is usually an API missing from the emulation; the failing call is in the log."),
    (re.compile(r"run status: (?:script error|timed out|stopped)"), "run-failed", "warning", "The script did not run to its end in the emulated environment.", "Only what ran before the stop could be observed."),
    (re.compile(r"using compact trace-assisted payload reconstruction|trace fallback"), "trace-assisted", "info", "The output is built from a behaviour trace, not lifted from the virtual machine.", "It shows what one run did. It is not the program."),
]


def diagnose(log: list[str], attempts: list[dict], output_kind: str, quality: dict | None, syntax: dict | None) -> list[dict]:
    blob = "\n".join(log)
    out = []
    for rx, code, sev, msg, hint in _DIAG_RULES:
        m = rx.search(blob)
        if m:
            out.append({"code": code, "severity": sev, "message": msg, "hint": hint, "evidence": m.group(0)[:160]})
    if any(a["outcome"] == "timeout" for a in attempts):
        out.append({"code": "timeout", "severity": "error", "message": "An attempt hit the time limit.", "hint": "A longer limit (up to %d s) can be requested; very large scripts may need a self-hosted worker." % MAX_TIMEOUT_S})
    if output_kind == "trace":
        out.append({"code": "trace-only", "severity": "warning", "message": "The output is a behaviour trace: only what the script did in one run, in the order it did it.", "hint": "Branches that did not run are absent, and the program's own structure is not recovered."})
    if quality and quality["grade"] != "clean" and output_kind != "none":
        out.append({"code": "unresolved-markers", "severity": "warning", "message": "The output still contains %d unresolved marker(s)." % quality["unresolvedTotal"], "hint": "See the counts in the quality report."})
    if syntax and syntax.get("ok") is False:
        out.append({"code": "invalid-syntax", "severity": "error", "message": "The output is not valid Luau.", "hint": "; ".join(syntax.get("errors", [])[:2])})
    seen = set()
    uniq = []
    for d in out:
        if d["code"] not in seen:
            seen.add(d["code"])
            uniq.append(d)
    return uniq


# ---- the whole job -------------------------------------------------------------------------------------------------------

def reconstruct(source: bytes, engine: str = "auto", timeout_s: int = DEFAULT_TIMEOUT_S, original: bytes | None = None, allow_fallback: bool = True, emit=lambda e: None, cancelled=lambda: False) -> dict:
    """Run one reconstruction. `emit` receives progress events (dicts) as they happen; the return value is the final result."""
    timeout_s = max(10, min(int(timeout_s), MAX_TIMEOUT_S))
    run = Run(emit, cancelled)
    deadline = time.time() + timeout_s
    if len(source) > MAX_INPUT_BYTES:
        return {"ok": False, "error": {"code": "too_large", "message": "The input is %d bytes; the limit is %d." % (len(source), MAX_INPUT_BYTES)}}
    work = Path(tempfile.mkdtemp(prefix="qs-recon-"))
    try:
        run.stage_start("identify")
        ident = identify(source)
        run.stage_done("identify", detail=("banner v%s" % ident["banner"]["version"]) if ident["banner"] else "no banner")
        emit({"t": "identification", **ident})

        run.stage_start("select")
        steps = plan(ident, engine, allow_fallback)
        run.stage_done("select", detail="%s%s" % (ENGINES[steps[0]["engine"]]["label"], "" if steps[0]["mode"] == "lift" else " (trace)"))
        emit({"t": "plan", "steps": [{**s, "label": ENGINES[s["engine"]]["label"]} for s in steps]})

        input_path = work / "input.lua"
        input_path.write_bytes(source)
        attempts: list[dict] = []
        chosen = None
        for step in steps:
            if time.time() > deadline - 3:
                break
            if step["mode"] == "trace" and chosen is not None:
                break
            run.stage = None
            run.stage_start("run", "attempt: %s (%s)" % (ENGINES[step["engine"]]["label"], step["mode"]))
            a = _attempt(step, input_path, work, deadline, run)
            attempts.append(a["result"])
            if run.was_cancelled:
                return {"ok": False, "engine": {"requested": engine, "attempts": attempts}, "kind": "none", "log": run.log, "diagnostics": [], "seconds": round(time.time() - run.t0, 1),
                        "error": {"code": "cancelled", "message": "The client disconnected; the run was stopped."}}
            if a["result"]["produced"]:
                chosen = {"step": step, "text": a["text"]}
                if step["mode"] == "lift":
                    break
                break
            emit({"t": "fallback", "from": step["engine"], "mode": step["mode"], "outcome": a["result"]["outcome"]})
        if run.stage:
            run.stage_done(run.stage)

        if chosen is None:
            diags = diagnose(run.log, attempts, "none", None, None)
            diags.insert(0, {"code": "no-output", "severity": "error", "message": "No engine produced any output for this input.", "hint": "Check the diagnostics below and the engine log."})
            return {"ok": False, "engine": {"requested": engine, "attempts": attempts}, "identification": ident, "kind": "none", "diagnostics": diags, "log": run.log,
                    "seconds": round(time.time() - run.t0, 1), "error": {"code": "no_output", "message": "No engine produced any output."}}

        step = chosen["step"]
        text = _strip_header(chosen["text"])
        trace_markers = ("Behaviour trace:" in chosen["text"][:600]) or any("trace-assisted" in l or "trace fallback" in l for l in run.log)
        kind = "trace" if step["mode"] == "trace" else ("trace-assisted" if trace_markers else "devirtualized")
        spec = ENGINES[step["engine"]]
        run.stage_start("check")
        quality = assess(text, kind, run.log)
        syntax = syntax_check(text, work)
        run.stage_done("check", detail="%s, %d unresolved marker(s)" % ("valid Luau" if syntax.get("ok") else "syntax problem" if syntax.get("ok") is False else "syntax unchecked", quality["unresolvedTotal"]))

        if original is not None:
            run.stage_start("verify")
            verification = verify_against_original(original, text, work)
            run.stage_done("verify", detail=verification["status"])
        else:
            verification = {"status": "not-run", "reason": "No original was supplied. Readable output is not the same as a verified reconstruction."}
            emit({"t": "stage", "id": "verify", "state": "skipped", "label": STAGE_LABEL["verify"], "detail": "no original supplied"})

        run.stage_start("report")
        header = "-- Reconstructed by QuickSilver. Engine: %s (%s). %s\n" % (spec["label"], step["mode"], {"devirtualized": "Lifted from the virtual machine.", "trace-assisted": "Built from a behaviour trace.", "trace": "Behaviour trace: only what this run did."}[kind])
        header += "-- Verification: %s.\n\n" % verification["status"]
        result = {
            "ok": True,
            "engine": {"requested": engine, "used": step["engine"], "label": spec["label"], "mode": step["mode"], "nearest": bool(step.get("nearest")), "attempts": attempts},
            "identification": ident,
            "kind": kind,
            "output": header + text,
            "quality": quality,
            "checks": {"syntax": syntax},
            "verification": verification,
            "diagnostics": diagnose(run.log, attempts, kind, quality, syntax),
            "log": run.log,
            "seconds": round(time.time() - run.t0, 1),
        }
        run.stage_done("report")
        return result
    except Exception as e:  # noqa: BLE001 - the job must always answer
        return {"ok": False, "error": {"code": "internal", "message": "The reconstruction service failed: %s" % e.__class__.__name__}, "log": run.log}
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":      # python service.py <file> [engine] [--original FILE] [--no-fallback]   -> the result as JSON on stdout
    args = [a for a in sys.argv[1:]]
    orig = None
    fallback = True
    if "--original" in args:
        k = args.index("--original")
        orig = Path(args[k + 1]).read_bytes()
        del args[k:k + 2]
    if "--no-fallback" in args:
        args.remove("--no-fallback")
        fallback = False
    data = Path(args[0]).read_bytes()
    res = reconstruct(data, args[1] if len(args) > 1 else "auto", original=orig, allow_fallback=fallback)
    print(json.dumps(res))
