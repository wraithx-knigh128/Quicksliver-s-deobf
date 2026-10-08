"""Checks every Roblox class/property/enum/service the UI script uses against Roblox's real API dump.
  1. luau-ast tsb_animation_hub.lua > ast.json        (luau-ast from github.com/luau-lang/luau/releases)
  2. curl -L -o API-Dump.json https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json
  3. python3 validate_api.py ast.json API-Dump.json
Assignments to fields of our own tables (x, y, locked, speed ...) are reported as 'not a property' - expected."""
import json, sys, collections
dump = json.load(open(sys.argv[2] if len(sys.argv) > 2 else 'API-Dump.json'))
classes = {c['Name']: c for c in dump['Classes']}
enums = {e['Name']: {i['Name'] for i in e['Items']} for e in dump['Enums']}

def members(cls, kind):
    out = {}
    while cls:
        c = classes.get(cls)
        if not c: break
        for m in c['Members']:
            if m['MemberType'] == kind: out.setdefault(m['Name'], m)
        cls = c.get('Superclass')
    return out
all_props = collections.defaultdict(list); all_methods = set(); all_events = set()
for name, c in classes.items():
    for m in c['Members']:
        if m['MemberType'] == 'Property': all_props[m['Name']].append(name)
        elif m['MemberType'] == 'Function': all_methods.add(m['Name'])
        elif m['MemberType'] == 'Event': all_events.add(m['Name'])

raw = open(sys.argv[1], 'rb').read().decode('utf-8', 'replace')
ast = json.loads(raw, strict=False)
problems, seen = [], collections.Counter()

def loc(n): return n.get('location', '?').split(' ')[0]
def walk(n, fn):
    if isinstance(n, dict):
        fn(n)
        for v in n.values(): walk(v, fn)
    elif isinstance(n, list):
        for v in n: walk(v, fn)

def const(n): return n.get('value') if isinstance(n, dict) and n.get('type') == 'AstExprConstantString' else None

def visit(n):
    t = n.get('type')
    # new("Class", {props}, children)
    if t == 'AstExprCall':
        f = n['func']
        name = f.get('local', {}).get('name') if f.get('type') == 'AstExprLocal' else None
        if name == 'new' and n['args'] and const(n['args'][0]):
            cls = const(n['args'][0])
            if cls not in classes:
                problems.append(f"{loc(n)}: unknown class {cls}")
            elif len(n['args']) > 1 and n['args'][1].get('type') == 'AstExprTable':
                props = members(cls, 'Property')
                for it in n['args'][1]['items']:
                    k = const(it.get('key'))
                    if k is None: continue
                    seen[(cls, k)] += 1
                    p = props.get(k)
                    if not p: problems.append(f"{loc(n)}: {cls} has no property '{k}'")
                    else:
                        sec = p.get('Security', {})
                        w = sec.get('Write') if isinstance(sec, dict) else sec
                        if w not in (None, 'None'): problems.append(f"{loc(n)}: {cls}.{k} write security {w}")
                        tags = p.get('Tags', [])
                        if 'ReadOnly' in tags or 'NotScriptable' in tags: problems.append(f"{loc(n)}: {cls}.{k} is {tags}")
        # event hookups: something.Event:Connect(fn) -> Event must exist on some Roblox class
        if f.get('type') == 'AstExprIndexName' and f.get('op') == ':' and f['index'] == 'Connect' and f['expr'].get('type') == 'AstExprIndexName':
            ev = f['expr']['index']
            seen[('event', ev)] += 1
            if ev not in all_events:
                problems.append(f"{loc(n)}: '{ev}' is not an event of any Roblox class")
        if f.get('type') == 'AstExprIndexName' and f.get('op') == ':':
            m = f['index']
            seen[('method', m)] += 1
            if m == 'GetService' and n['args'] and const(n['args'][0]):
                svc = const(n['args'][0])
                if svc not in classes: problems.append(f"{loc(n)}: unknown service {svc}")
    # Enum.A.B
    if t == 'AstExprIndexName' and n['expr'].get('type') == 'AstExprIndexName':
        e = n['expr']
        if e['expr'].get('type') == 'AstExprGlobal' and e['expr'].get('global') == 'Enum':
            en, item = e['index'], n['index']
            seen[('enum', en, item)] += 1
            if en not in enums: problems.append(f"{loc(n)}: unknown Enum.{en}")
            elif item not in enums[en]: problems.append(f"{loc(n)}: Enum.{en}.{item} does not exist")
    # obj.Prop = value  (assignment targets)
    if t == 'AstStatAssign':
        for v in n['vars']:
            if v.get('type') == 'AstExprIndexName':
                p = v['index']; seen[('assign', p)] += 1
                if p not in all_props and not p.startswith('__'):
                    problems.append(f"{loc(v)}: assignment to '.{p}' - not a property of any Roblox class (ok only for our own tables)")
walk(ast, visit)

print("classes/props checked:", sum(1 for k in seen if len(k) == 2 and k[0] != 'method'))
print("enum references checked:", sum(1 for k in seen if k[0] == 'enum'))
print("events hooked up:", sorted({k[1] for k in seen if k[0] == 'event'}))
print("distinct methods called with ':':", sorted({k[1] for k in seen if k[0] == 'method'}))
print("distinct assignment targets (.X =):", sorted({k[1] for k in seen if k[0] == 'assign'}))
print()
if problems:
    print("PROBLEMS (%d):" % len(problems))
    for p in sorted(set(problems), key=lambda s: int(s.split(':')[0]) if s.split(':')[0].isdigit() else 0): print("  " + p)
else:
    print("no problems found")
