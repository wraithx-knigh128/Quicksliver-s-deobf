#!/bin/sh
Q=$(cd "$(dirname "$0")/../../.." && pwd); S=$1
mkdir -p $S/pmf-out
while IFS="$(printf '\t')" read -r obf orig set cfg; do
  id=$(echo "$obf" | tr '/' '_')
  t0=$(date +%s%N)
  $Q/tools/isolate/run.sh $S/tools/prometheus $Q/$obf $S/pmf-out/$id.out 60 -- node --max-old-space-size=2048 bin/pdeobf.js {in} -o {out} -q --force > /dev/null 2> $S/pmf-out/$id.err
  st=$?
  t1=$(date +%s%N)
  printf '%s\t%s\t%s\n' "$obf" "$st" "$(( (t1 - t0) / 1000000 ))"
done < $S/pm-pairs.tsv > $S/pmf-runs.tsv
node $S/tool-eval.mjs $Q $S pmf-runs.tsv pmf-out > $S/pmf-results.jsonl 2> $S/pmf-eval.err
echo finished > $S/pmf.done
