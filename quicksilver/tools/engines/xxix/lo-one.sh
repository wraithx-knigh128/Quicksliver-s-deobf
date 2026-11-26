#!/bin/sh
Q=$(cd "$(dirname "$0")/../../.." && pwd); S=$1; f=$2
id=$(echo "$f" | tr '/' '_'); out=$S/lo-out/$id.lua; rm -f $out
t0=$(date +%s%N)
$Q/tools/isolate/run.sh $S/tools/luaobf $Q/$f $out 60 -- python3 -E -s cli.py {in} {out} > /dev/null 2> $S/lo-out/$id.err
st=$?; t1=$(date +%s%N)
node $S/lo-eval.mjs $Q "$f" "$out" $st $(( (t1 - t0) / 1000000 )) $S/lo-out/$id.err
