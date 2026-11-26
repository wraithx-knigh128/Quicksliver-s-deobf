#!/bin/sh
# Prometheus-Deobfuscator-Fixed on QuickSilver's own Prometheus fixtures, each run isolated (tools/isolate/run.sh), then both tools scored
Q=$(cd "$(dirname "$0")/../../.." && pwd); S=$1
while IFS="$(printf '\t')" read -r obf orig set cfg; do
  id=$(echo "$obf" | tr '/' '_')
  t0=$(date +%s%N)
  $Q/tools/isolate/run.sh $S/tools/prometheus $Q/$obf $S/pm-out/$id.out 60 -- node --max-old-space-size=2048 bin/pdeobf.js {in} -o {out} -q > $S/pm-out/$id.stdout 2> $S/pm-out/$id.err
  st=$?
  t1=$(date +%s%N)
  printf '%s\t%s\t%s\n' "$obf" "$st" "$(( (t1 - t0) / 1000000 ))"
done < $S/pm-pairs.tsv > $S/pm-runs.tsv
node $S/pm-eval.mjs $Q $S > $S/pm-results.jsonl 2> $S/pm-eval.err
echo finished >> $S/pm-runs.tsv.done
