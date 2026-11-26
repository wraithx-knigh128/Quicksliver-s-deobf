#!/bin/sh
# Prompt XXX: reproduce the Luraph v15.2 research lifter's "devirtualization failed: YieldSig" with its own traceback switch.
# Observe only: the repository's pipeline, unmodified, on its own sample, inside tools/isolate/run.sh (no network, nobody, limits).
#
#   tools/engines/xxx/v152-traceback.sh <checkout of pro628713-arch/luraph-v15.2-deobf> <work dir>
#
# The traceback ends in Stepper.__init__ -> _stack_pointer_candidates -> _fresh_scopes -> exec_block(inner_body[:first_inner]) ->
# raise YieldSig: the model takes a top-level `if` as a mode branch only when a dispatch `while` is its first statement, and this build's
# branch starts with a state assignment (`if M then W,Q,Wh,mh=m,J,Z,E;while true do ...`), so the branch is run as prologue.
set -e
REPO=$1; W=$2
mkdir -p "$W/tool"
cp -r "$REPO/deobf" "$W/tool/deobf"
cat > "$W/tool/run.sh" <<'IN'
#!/bin/sh
mkdir -p in out && cp "$1" in/sample.luau
cd in
DEVIRT_TB=1 python3 -E -s ../deobf/deob.py sample.luau --debug --timeout 150 --no-pypy > ../out/stdout.txt 2> ../out/stderr.txt
echo "exit $?" >> ../out/stdout.txt
cp -r output ../out/ 2>/dev/null
cd .. && tar czf "$2" out
IN
HERE=$(cd "$(dirname "$0")/../../.." && pwd)
"$HERE/tools/isolate/run.sh" "$W/tool" "$REPO/sample.luau" "$W/out.tgz" 400 -- sh run.sh {in} {out}
mkdir -p "$W/out" && tar xzf "$W/out.tgz" -C "$W/out"
awk 'length($0) < 400' "$W/out/out/stderr.txt" | grep -E 'File "|raise|devirtualization|run status'
