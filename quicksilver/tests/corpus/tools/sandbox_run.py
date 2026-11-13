"""Run third-party code in an isolated, no-network sandbox, without trusting it.

Used to generate real output of obfuscators whose own implementation is Python or Rust (Obscura, RealObfuscator, zynaa/LuaObfuscator): their sources are
read first, and then run here instead of on the host. What the code can reach:

  * no network: a new network namespace with nothing in it (not even loopback up);
  * no host files: /home, /root, /tmp, /var/tmp and /run are replaced by empty tmpfs mounts; the tool itself is bind-mounted READ-ONLY at /mnt/tool and a work folder
    read-write at /mnt/work (the only place it can write besides those tmpfs mounts, which vanish with the sandbox); optional extra read-only mounts (a toolchain);
  * no privileges: after the mounts are made every capability is dropped and no_new_privs is set, so nothing inside can mount, ptrace outside its pid namespace,
    open raw sockets or regain root;
  * a new pid namespace (it cannot see or signal the host's processes), a scrubbed environment (no proxy, tokens or cookies), resource limits (CPU seconds, address
    space, file size, process count, core size) and a wall-clock kill of the whole process group.

  python -I sandbox_run.py --tool DIR --work DIR [--ro SRC:DST ...] [--timeout 120] [--mem-mb 2048] [--env K=V ...] -- COMMAND ...
  -> JSON on stdout: {"returncode": int, "timedOut": bool, "stdout": str, "stderr": str}

Self-test (tests/sandbox.test.mjs) runs code that tries each of the above and checks that it fails.
"""
import argparse
import json
import os
import resource
import shlex
import shutil
import signal
import subprocess
import sys

BASE_ENV = {"PATH": "/usr/local/bin:/usr/bin:/bin", "HOME": "/mnt/work", "TMPDIR": "/tmp", "LANG": "C.UTF-8", "PYTHONDONTWRITEBYTECODE": "1", "PYTHONHASHSEED": "0",
            "PYTHONIOENCODING": "utf-8"}


def available():
    if not shutil.which("unshare") or not shutil.which("setpriv"):
        return False
    try:
        return subprocess.run(["unshare", "-rnmpf", "--mount-proc", "true"], capture_output=True, timeout=10).returncode == 0
    except Exception:
        return False


def build_script(tool, work, ro, cmd, env):
    q = shlex.quote
    lines = [
        "set -e",
        "mount -t tmpfs tmpfs /mnt",
        "mkdir -p /mnt/tool /mnt/work",
        f"mount --bind {q(tool)} /mnt/tool",
        "mount -o remount,ro,bind /mnt/tool",
        f"mount --bind {q(work)} /mnt/work",
    ]
    for src, dst in ro:
        lines += [f"mkdir -p {q(dst)}", f"mount --bind {q(src)} {q(dst)}", f"mount -o remount,ro,bind {q(dst)}"]
    # the host's folders disappear behind empty memory-backed ones (after the binds above, which already hold their own references)
    for d in ("/home", "/root", "/tmp", "/var/tmp", "/run", "/srv", "/opt"):
        lines.append(f"[ -d {d} ] && mount -t tmpfs tmpfs {d} || true")
    lines.append("chmod 1777 /tmp")
    envs = " ".join(f"{q(k)}={q(v)}" for k, v in env.items())
    # every capability dropped, no_new_privs: the code runs as an unprivileged process of its own user namespace
    lines.append(f"cd /mnt/work && exec env -i {envs} setpriv --no-new-privs --bounding-set=-all --inh-caps=-all --ambient-caps=-all -- {' '.join(q(c) for c in cmd)}")
    return "\n".join(lines)


def run(tool, work, cmd, ro=(), timeout=120, mem_mb=2048, cpu=None, extra_env=None, input_bytes=None):
    env = dict(BASE_ENV)
    env.update(extra_env or {})
    script = build_script(os.path.abspath(tool), os.path.abspath(work), list(ro), cmd, env)
    limits = (cpu or timeout + 10, mem_mb)

    def preexec():
        os.setsid()
        resource.setrlimit(resource.RLIMIT_CPU, (limits[0], limits[0] + 5))
        resource.setrlimit(resource.RLIMIT_AS, (limits[1] << 20, limits[1] << 20))
        resource.setrlimit(resource.RLIMIT_FSIZE, (256 << 20, 256 << 20))
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        resource.setrlimit(resource.RLIMIT_NPROC, (512, 512))
    p = subprocess.Popen(["unshare", "-rnmpf", "--mount-proc", "sh", "-c", script], stdin=subprocess.PIPE if input_bytes is not None else subprocess.DEVNULL,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, preexec_fn=preexec, env={"PATH": BASE_ENV["PATH"]})
    timed_out = False
    try:
        out, err = p.communicate(input_bytes, timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        try:
            os.killpg(os.getpgid(p.pid), signal.SIGKILL)
        except Exception:
            p.kill()
        out, err = p.communicate()
    return {"returncode": p.returncode, "timedOut": timed_out, "stdout": out.decode("utf-8", "replace"), "stderr": err.decode("utf-8", "replace")}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tool", required=True)
    ap.add_argument("--work", required=True)
    ap.add_argument("--ro", action="append", default=[], help="SRC:DST extra read-only mount")
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--mem-mb", type=int, default=2048)
    ap.add_argument("--env", action="append", default=[])
    ap.add_argument("cmd", nargs=argparse.REMAINDER)
    a = ap.parse_args()
    cmd = a.cmd[1:] if a.cmd and a.cmd[0] == "--" else a.cmd
    if not available():
        print(json.dumps({"returncode": -1, "timedOut": False, "stdout": "", "stderr": "no user/mount/net namespaces on this host: nothing was run"}))
        return 3
    res = run(a.tool, a.work, cmd, [tuple(x.split(":", 1)) for x in a.ro], a.timeout, a.mem_mb, None, dict(x.split("=", 1) for x in a.env))
    print(json.dumps(res))
    return 0


if __name__ == "__main__":
    sys.exit(main())
