"""POST /api/reconstruct: run the reconstruction service (api/_engine/luraph/service.py) for one upload.

  GET  /api/reconstruct?check=1   what this host can do, measured now (Luau runs, engine list, limits, isolation) and a self-test
                                  on a bundled fixture. Safe to call: it runs nothing the caller supplied.
  POST /api/reconstruct           JSON body:
        { "source_b64": "...",          the protected script, base64 (required)
          "engine": "auto",             auto | luraph_v14_7 | luraph_v14_8 | luraph_v14_9 | luraph_v15 | ironbrew1 | generic
          "original_b64": "...",        optional: the unprotected original, for a behaviour comparison
          "timeout_s": 90,              clamped to the host's maximum
          "fallback": true,             allow the fallback engines and the behaviour trace
          "attest": true }              required: "I own this script or am authorised to analyse it"

The answer is a stream of JSON lines (application/x-ndjson): `stage`, `log`, `identification`, `plan`, `attempt`, `fallback`, and a last line
`{"t":"result", ...}`. A client that cannot stream gets the same lines when the request ends.

The engine RUNS the script (in a fake Roblox environment, in a separate process with a wall clock, CPU and memory limit, and without a network
namespace where the host allows it). So the endpoint is rate limited per client, refuses inputs over the size limit, requires the attestation, and
can be switched off or put behind a token:

  QS_RECONSTRUCT_MODE   open (default) | token | off
  QS_RECONSTRUCT_TOKEN  required in the `x-reconstruct-token` header when the mode is `token`
  QS_RECONSTRUCT_RPM    requests per minute per client per instance (default 6)
  QS_RECONSTRUCT_MAX_BYTES, QS_RECONSTRUCT_MAX_SECONDS, QS_ENGINE_MEM_MB   limits (see api/_engine/luraph/service.py)

Run it locally:  python3 api/reconstruct.py --serve 8788
"""
from __future__ import annotations

import base64
import hmac
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENGINE = Path(__file__).resolve().parent / "_engine" / "luraph"      # under api/_*: deployed with the function, never served as a static file
sys.path.insert(0, str(ENGINE))
import service  # noqa: E402

_hits: dict[str, list[float]] = {}
_active = {"n": 0}
MAX_BODY = int(service.MAX_INPUT_BYTES * 2.8) + 200_000      # base64 of source + base64 of original + JSON


def _client(headers, addr) -> str:
    fwd = headers.get("x-forwarded-for") or headers.get("x-real-ip") or ""
    return (fwd.split(",")[0].strip() or (addr[0] if addr else "?"))[:64]


def _limited(client: str) -> bool:
    rpm = int(os.environ.get("QS_RECONSTRUCT_RPM", 6))
    now = time.time()
    hits = [t for t in _hits.get(client, []) if now - t < 60]
    if len(hits) >= rpm:
        _hits[client] = hits
        return True
    hits.append(now)
    _hits[client] = hits
    if len(_hits) > 2000:
        for k in list(_hits)[:1000]:
            _hits.pop(k, None)
    return False


class handler(BaseHTTPRequestHandler):          # noqa: N801 - the name the Vercel Python runtime looks for
    protocol_version = "HTTP/1.0"                # the body ends when the connection closes, so streaming needs no chunk framing
    server_version = "QuickSilver"

    def log_message(self, *a):                   # no request lines in the function logs (they could carry client addresses)
        pass

    # ---- helpers
    def _send_json(self, status, obj, extra=None):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _error(self, status, code, message, extra=None):
        self._send_json(status, {"ok": False, "error": {"code": code, "message": message}}, extra)

    def _authorised(self) -> bool:
        mode = os.environ.get("QS_RECONSTRUCT_MODE", "open")
        if mode == "off":
            self._error(503, "disabled", "Reconstruction is switched off on this deployment (QS_RECONSTRUCT_MODE=off).")
            return False
        if mode == "token":
            want = os.environ.get("QS_RECONSTRUCT_TOKEN", "")
            got = self.headers.get("x-reconstruct-token", "")
            if not want or not hmac.compare_digest(want.encode(), got.encode()):
                self._error(401, "unauthorized", "This deployment requires an x-reconstruct-token.")
                return False
        return True

    # ---- GET: capabilities and self-test
    def do_GET(self):  # noqa: N802
        if not self._authorised():
            return
        if "check=1" not in (self.path or ""):
            return self._error(405, "method", "POST a reconstruction request, or GET ?check=1.")
        caps = service.capabilities()
        fixture = ENGINE / "fixtures" / "001_vm_like_dispatch-ib1.lua"
        selftest = {"ran": False}
        if caps.get("luau", {}).get("ok") and fixture.exists():
            t = time.time()
            r = service.reconstruct(fixture.read_bytes(), "ironbrew1", timeout_s=60, allow_fallback=False)
            out = r.get("output") or ""
            selftest = {"ran": True, "fixture": fixture.name, "ok": bool(r.get("ok")) and r.get("kind") == "devirtualized" and "assert(n == 1 and tbl2[1] == 34)" in out,
                        "kind": r.get("kind"), "seconds": round(time.time() - t, 1), "engine": (r.get("engine") or {}).get("used"),
                        "attempts": (r.get("engine") or {}).get("attempts"), "diagnostics": [d["code"] for d in r.get("diagnostics", [])],
                        "log": (r.get("log") or [])[-25:]}       # the engine's own progress lines for a bundled fixture: no user input in them
        self._send_json(200, {"ok": True, "capabilities": caps, "selfTest": selftest, "mode": os.environ.get("QS_RECONSTRUCT_MODE", "open")})

    # ---- POST: a reconstruction
    def do_POST(self):  # noqa: N802
        if not self._authorised():
            return
        client = _client(self.headers, self.client_address)
        if _limited(client):
            return self._error(429, "rate_limited", "Too many requests from this client; try again in a minute.", {"Retry-After": "30"})
        try:
            n = int(self.headers.get("content-length") or 0)
        except ValueError:
            n = 0
        if n <= 0 or n > MAX_BODY:
            return self._error(413 if n > MAX_BODY else 400, "bad_size", "The request body is empty or larger than %d bytes." % MAX_BODY)
        try:
            body = json.loads(self.rfile.read(n).decode("utf-8"))
            source = base64.b64decode(body["source_b64"], validate=True)
            original = base64.b64decode(body["original_b64"], validate=True) if body.get("original_b64") else None
        except Exception:
            return self._error(400, "bad_request", "The body must be JSON with a base64 `source_b64` (and optionally `original_b64`).")
        if body.get("attest") is not True:
            return self._error(400, "attestation_required", "Confirm that you own this script or are authorised to analyse it (attest: true). The engine runs the script.")
        if not source.strip():
            return self._error(400, "empty", "The script is empty.")
        if len(source) > service.MAX_INPUT_BYTES or (original is not None and len(original) > service.MAX_INPUT_BYTES):
            return self._error(413, "too_large", "Inputs may be at most %d bytes." % service.MAX_INPUT_BYTES)
        engine = body.get("engine") or "auto"
        if engine != "auto" and engine not in service.ENGINES:
            return self._error(400, "bad_engine", "Unknown engine. Known: auto, %s." % ", ".join(service.ENGINES))
        try:
            timeout_s = int(body.get("timeout_s") or service.DEFAULT_TIMEOUT_S)
        except (TypeError, ValueError):
            timeout_s = service.DEFAULT_TIMEOUT_S
        if _active["n"] >= int(os.environ.get("QS_RECONSTRUCT_CONCURRENCY", 2)):
            return self._error(503, "busy", "The service is busy; try again shortly.", {"Retry-After": "15"})

        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Accel-Buffering", "no")
        self.end_headers()

        def emit(event):
            try:
                self.wfile.write((json.dumps(event, separators=(",", ":")) + "\n").encode("utf-8"))
                self.wfile.flush()
            except Exception:       # the client went away: the job still finishes and cleans up
                pass

        _active["n"] += 1
        try:
            result = service.reconstruct(source, engine, timeout_s, original, bool(body.get("fallback", True)), emit)
        finally:
            _active["n"] -= 1
        result["t"] = "result"
        emit(result)


if __name__ == "__main__":
    port = 8788
    if "--serve" in sys.argv:
        i = sys.argv.index("--serve")
        port = int(sys.argv[i + 1]) if i + 1 < len(sys.argv) else port
    srv = ThreadingHTTPServer(("127.0.0.1", port), handler)
    print("reconstruct service on http://127.0.0.1:%d" % port, file=sys.stderr, flush=True)
    srv.serve_forever()
