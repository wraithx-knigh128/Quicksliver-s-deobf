#!/bin/sh
Q=$(cd "$(dirname "$0")/../../.." && pwd); S=$1
while IFS="$(printf '\t')" read -r obf orig set cfg; do
  id=$(echo "$obf" | tr '/' '_')
  t0=$(date +%s%N)
  $Q/tools/isolate/run.sh $S/tools/unprom $Q/$obf $S/up-out/$id.out 60 -- /usr/local/bin/python3 -I unprom.py {in} -o {out} > $S/up-out/$id.stdout 2> $S/up-out/$id.err
  st=$?
  t1=$(date +%s%N)
  printf '%s\t%s\t%s\n' "$obf" "$st" "$(( (t1 - t0) / 1000000 ))"
done < $S/pm-pairs.tsv > $S/up-runs.tsv
node $S/tool-eval.mjs $Q $S up-runs.tsv up-out > $S/up-results.jsonl 2> $S/up-eval.err
echo finished >> $S/up-runs.tsv.done
