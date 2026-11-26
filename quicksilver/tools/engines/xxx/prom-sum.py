# compare XXIX's integrated Prometheus run with XXX's, row by row (same 131 fixtures, same scoring as integ-sum.py)
import json, collections, sys
A = {json.loads(l)['f']: json.loads(l) for l in open(sys.argv[1])}
B = {json.loads(l)['f']: json.loads(l) for l in open(sys.argv[2])}
def vm(r): return any(k in (r['cfg'] or '') for k in ('Vmify', 'Weak', 'Medium', 'Strong'))
def cls(t):
    if not t: return 'no output'
    if t['verdict'] == 'identical' and not t['left']: return 'right, nothing left'
    if t['verdict'] == 'identical': return 'right, protection left'
    if t['verdict'] == 'different': return 'WRONG'
    return 'inconclusive'
for name, R in (('XXIX', A), ('XXX', B)):
    c = collections.Counter(cls(r['truth']) for r in R.values()); o = collections.Counter(str(r['outcome']) for r in R.values())
    v = collections.Counter(cls(r['truth']) for r in R.values() if vm(r))
    eng = sum(1 for r in R.values() if r['engine']); used = sum(1 for r in R.values() if r['engine'] and (r['engine'].get('gate') or {}).get('used'))
    bad = [f for f, r in R.items() if r['outcome'] == 'validated' and (not r['truth'] or r['truth']['verdict'] != 'identical' or r['truth']['left'])]
    print(name, 'all:', dict(c)); print('   VM builds:', dict(v)); print('   outcomes:', dict(o)); print('   engine asked', eng, '| validated but not clean:', bad)
ch = [(f, cls(A[f]['truth']), cls(B[f]['truth']), A[f]['outcome'], B[f]['outcome']) for f in A if f in B and (cls(A[f]['truth']) != cls(B[f]['truth']) or A[f]['outcome'] != B[f]['outcome'])]
print('changed rows:', len(ch))
for x in ch: print('  ', *x)
