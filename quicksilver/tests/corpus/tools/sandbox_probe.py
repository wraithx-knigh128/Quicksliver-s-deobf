# a harmless probe: it only tries to reach what a sandbox must not allow, and reports what happened
import os, socket, sys, json
r = {}
def t(name, fn):
    try: r[name] = ("ALLOWED", str(fn())[:80])
    except Exception as e: r[name] = ("denied", type(e).__name__ + ": " + str(e)[:60])
t("network", lambda: socket.create_connection(("1.1.1.1", 53), timeout=3))
t("dns", lambda: socket.getaddrinfo("example.com", 80))
t("list /home", lambda: os.listdir("/home"))
t("list /root", lambda: os.listdir("/root"))
t("list /tmp", lambda: os.listdir("/tmp"))
t("host repo", lambda: os.listdir("/home/user/Quicksliver-s-deobf"))
t("write tool dir", lambda: open("/mnt/tool/x", "w").write("x"))
t("write work dir", lambda: open("/mnt/work/ok.txt", "w").write("x"))
t("read proxy env", lambda: os.environ["HTTPS_PROXY"])
t("env keys", lambda: sorted(os.environ))
import subprocess
t("mount", lambda: "rc=%d" % subprocess.run(["mount", "-t", "tmpfs", "tmpfs", "/mnt/work"], capture_output=True).returncode)
t("host pid 1 cmdline", lambda: open("/proc/1/cmdline").read()[:40])
print(json.dumps(r))
