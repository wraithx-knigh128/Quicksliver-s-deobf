#!/bin/sh
Q=$(cd "$(dirname "$0")/../../.." && pwd); S=$1
sort -u $S/ms-verify-list.txt $S/ms-noparse.txt | while read f; do
  id=$(echo "$f" | tr '/' '_')
  $Q/tools/isolate/run.sh $S/tools/moonsec $Q/$f $S/keys/$id.json 60 -- node --max-old-space-size=2048 qs-keys.js {in} {out} >/dev/null 2>&1
  printf '%s\t%s\n' "$f" "$(cat $S/keys/$id.json 2>/dev/null || echo null)"
done > $S/keys.tsv
echo finished >> $S/keys.tsv.done
