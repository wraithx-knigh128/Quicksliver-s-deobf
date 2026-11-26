#!/bin/sh
# one MoonSec sample: isolated tool -> bytecode -> QuickSilver decompile; prints one JSON line
Q=$(cd "$(dirname "$0")/../../.." && pwd); S=$1; f=$2
id=$(echo "$f" | tr '/' '_')
out=$S/ms-bc/$id.luac; err=$S/ms-bc/$id.err
t0=$(date +%s%N)
$Q/tools/isolate/run.sh $S/tools/moonsec $Q/$f $out 60 -- node --max-old-space-size=2048 qs-driver.js {in} {out} > /dev/null 2> $err
st=$?
t1=$(date +%s%N)
node $S/ms-eval.mjs $Q "$f" "$out" $st $(( (t1 - t0) / 1000000 )) "$err"
