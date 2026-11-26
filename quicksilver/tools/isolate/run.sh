#!/bin/sh
# Run a third-party tool with no way out (Prompt XXIX). Used to measure the supplied deobfuscators and by the server adapters that call one.
#
#   tools/isolate/run.sh <tool-dir> <input-file> <out-file> <timeout-s> -- <command…>
#
# The command runs with the tool's files copied into a private work directory and sees:
#   * no network: a new, empty network namespace (only a downed loopback);
#   * an empty /home, /root and /tmp (fresh tmpfs mounts in a private mount namespace), so nothing of this checkout, the scratch area or other
#     jobs is readable; the work directory is under /opt/qs-iso (mode 0711: a job cannot list the others);
#   * the unprivileged user `nobody`, no supplementary groups, no new privileges;
#   * limits: CPU seconds = timeout, 4 GiB address space, 64 MiB per written file, 256 open files, 64 processes, and a wall-clock kill.
# In the command, {in} is the input's path and {out} the path the tool should write; only {out} (at most 64 MiB) is copied back.
# Needs root (to create the namespaces) and unshare/setpriv/prlimit (util-linux). Exit status: the tool's, or 124 on timeout.
set -eu
[ "$(id -u)" = 0 ] || { echo "run.sh: needs root to create the namespaces" >&2; exit 2; }
TOOL=$1; IN=$2; OUT=$3; T=$4; shift 4; [ "$1" = "--" ] && shift
mkdir -p /opt/qs-iso && chmod 0711 /opt/qs-iso
ID=$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')
JOB=/opt/qs-iso/$ID
mkdir -m 0700 "$JOB"
trap 'rm -rf "$JOB"' EXIT INT TERM
mkdir "$JOB/work"
cp -R "$TOOL"/. "$JOB/work/"
cp "$IN" "$JOB/work/.qs-input"
chown -R 65534:65534 "$JOB/work"
chmod 0711 "$JOB"
# the command line, with {in} and {out} replaced (kept as separate words)
CMD=""
for a in "$@"; do
  a=$(printf '%s' "$a" | sed "s#{in}#$JOB/work/.qs-input#g; s#{out}#$JOB/work/.qs-output#g")
  CMD="$CMD '$(printf '%s' "$a" | sed "s/'/'\\\\''/g")'"
done
set +e
timeout -s KILL "$((T + 5))" unshare --net --mount --propagation private sh -c "
  mount -t tmpfs -o size=64m,mode=0755 none /tmp &&
  mount -t tmpfs -o size=1m,mode=0755 none /home &&
  mount -t tmpfs -o size=1m,mode=0700 none /root &&
  cd '$JOB/work' &&
  exec setpriv --reuid=65534 --regid=65534 --clear-groups --no-new-privs --inh-caps=-all --bounding-set=-all \
    prlimit --cpu=$T --as=4294967296 --fsize=67108864 --nofile=256 --nproc=64 -- env -i PATH=/usr/local/bin:/usr/bin:/bin:/opt/node22/bin HOME=/tmp $CMD
"
STATUS=$?
set -e
[ $STATUS = 137 ] && STATUS=124
if [ -f "$JOB/work/.qs-output" ]; then head -c 67108864 "$JOB/work/.qs-output" > "$OUT"; fi
exit $STATUS
