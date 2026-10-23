// Scope analysis: binds every identifier use to its declaration.
//
// Results live in side tables so that the AST stays plain data (cloneable, JSON-serialisable):
//   info.varOf   WeakMap  Id | Name node -> Var
//   info.vars    every declared local Var, in declaration order
//   info.globals Map      name -> Var for free identifiers (shared per name)
//   info.selfOf  WeakMap  method Func node -> the Var of its implicit `self` parameter
//
// A Var records how it is used so that passes can decide what is safe:
//   reads / writes   Name nodes that read / assign it
//   init             the initialiser expression of `local x = e` when there is exactly one, else null
//   captured         true if it is accessed from a nested function
//   scope            the declaring Scope; scope.used is the set of Vars referenced anywhere inside it,
//                    which is what a renamer must check to avoid capturing an outer variable

let nextId = 1;

export class Var {
  constructor(name, kind, decl, funcDepth) {
    this.id = nextId++;
    this.name = name;
    this.kind = kind;          // 'local' | 'param' | 'for' | 'localfunc' | 'global'
    this.decl = decl;          // the Id node (null for globals)
    this.funcDepth = funcDepth;
    this.reads = [];
    this.writes = [];
    this.init = null;
    this.declStmt = null;
    this.captured = false;
    this.hasInit = false;      // declared together with a value (as opposed to `local x`)
    this.scope = null;
  }
  get isGlobal() { return this.kind === 'global'; }
}

class Scope {
  constructor(parent) { this.parent = parent; this.names = new Map(); this.used = new Set(); }
}

export function analyze(chunk) {
  const info = { varOf: new WeakMap(), vars: [], globals: new Map(), funcs: [], selfOf: new WeakMap() };
  let scope = new Scope(null);
  let depth = 0;

  const declare = (id, kind, declStmt) => {
    const v = new Var(id.name, kind, id, depth);
    v.declStmt = declStmt;
    v.scope = scope;
    scope.names.set(id.name, v);
    info.varOf.set(id, v);
    info.vars.push(v);
    return v;
  };

  const lookup = (name) => {
    for (let s = scope; s; s = s.parent) {
      const v = s.names.get(name);
      if (v) return v;
    }
    let g = info.globals.get(name);
    if (!g) { g = new Var(name, 'global', null, 0); info.globals.set(name, g); }
    return g;
  };

  const use = (node, isWrite) => {
    const v = lookup(node.name);
    info.varOf.set(node, v);
    (isWrite ? v.writes : v.reads).push(node);
    if (!v.isGlobal && depth > v.funcDepth) v.captured = true;
    for (let sc = scope; sc; sc = sc.parent) {
      sc.used.add(v);
      if (sc === v.scope) break;
    }
    return v;
  };

  const withScope = (fn) => {
    const saved = scope;
    scope = new Scope(saved);
    fn();
    scope = saved;
  };

  const block = (stmts, fresh = true) => {
    if (fresh) withScope(() => stmts.forEach(stmt));
    else stmts.forEach(stmt);
  };

  const func = (f, selfParam) => {
    depth++;
    withScope(() => {
      if (selfParam) info.selfOf.set(f, declare({ type: 'Id', name: 'self' }, 'param', null));
      for (const p of f.params) declare(p, 'param', null);
      block(f.body, false);
    });
    depth--;
    info.funcs.push(f);
  };

  function stmt(s) {
    switch (s.type) {
      case 'Local': {
        s.values.forEach(expr);
        const n = s.values.length;
        const last = s.values[n - 1];
        // `local a, b = f()` : f's results are spread over both names, so neither has a known initialiser.
        const spread = n > 0 && s.ids.length > n && (last.type === 'Call' || last.type === 'MethodCall' || last.type === 'Vararg');
        s.ids.forEach((id, i) => {
          const v = declare(id, 'local', s);
          if (i < n && !(spread && i === n - 1)) { v.init = s.values[i]; v.hasInit = true; }
          else if (i >= n && !spread) { v.init = { type: 'Nil' }; }
          v.hasInit = v.hasInit || i < n || spread;
        });
        break;
      }
      case 'LocalFunction': {
        const v = declare(s.id, 'localfunc', s);
        v.hasInit = true;
        v.init = s.func;
        func(s.func, false);
        break;
      }
      case 'Function': {
        if (s.target.type === 'Name') use(s.target, true);
        else expr(s.target);
        func(s.func, s.method !== null);
        break;
      }
      case 'Assign':
        s.values.forEach(expr);
        for (const t of s.targets) {
          if (t.type === 'Name') use(t, true); else expr(t);
        }
        break;
      case 'CompoundAssign':
        expr(s.value);
        if (s.target.type === 'Name') { const v = use(s.target, false); v.writes.push(s.target); }
        else expr(s.target);
        break;
      case 'CallStmt': expr(s.call); break;
      case 'Do': block(s.body); break;
      case 'While': expr(s.cond); block(s.body); break;
      case 'Repeat':
        // the condition of repeat-until can see the body's locals
        withScope(() => { s.body.forEach(stmt); expr(s.cond); });
        break;
      case 'If':
        for (const c of s.clauses) { expr(c.cond); block(c.body); }
        if (s.orelse) block(s.orelse);
        break;
      case 'NumFor':
        expr(s.start); expr(s.stop); if (s.step) expr(s.step);
        withScope(() => { declare(s.id, 'for', s); block(s.body, false); });
        break;
      case 'GenFor':
        s.exprs.forEach(expr);
        withScope(() => { s.ids.forEach((id) => declare(id, 'for', s)); block(s.body, false); });
        break;
      case 'Return': s.values.forEach(expr); break;
      default: break;
    }
  }

  function expr(e) {
    switch (e.type) {
      case 'Name': use(e, false); break;
      case 'Index': expr(e.obj); if (!(e.key.type === 'String' && e.dot)) expr(e.key); break;
      case 'Call': expr(e.fn); e.args.forEach(expr); break;
      case 'MethodCall': expr(e.obj); e.args.forEach(expr); break;
      case 'Func': func(e, e.isMethod); break;
      case 'Table':
        for (const f of e.fields) { if (f.kind === 'keyed') expr(f.key); expr(f.value); }
        break;
      case 'Binary': expr(e.left); expr(e.right); break;
      case 'Unary': expr(e.arg); break;
      case 'Paren': expr(e.expr); break;
      case 'IfExpr': expr(e.cond); expr(e.then); expr(e.orelse); break;
      case 'TypeAssert': expr(e.expr); break;
      case 'Interp': e.parts.forEach((p) => { if (typeof p !== 'string') expr(p); }); break;
      default: break;
    }
  }

  block(chunk.body, false);
  return info;
}

/** Is `name` a conventional Lua standard-library global? */
export const STDLIB_GLOBALS = new Set([
  'assert', 'collectgarbage', 'error', 'getmetatable', 'ipairs', 'load', 'loadstring', 'next', 'pairs',
  'pcall', 'print', 'rawequal', 'rawget', 'rawset', 'select', 'setmetatable', 'tonumber', 'tostring',
  'type', 'unpack', 'xpcall', 'getfenv', 'setfenv', 'newproxy', 'gcinfo', 'dofile', 'loadfile', 'require',
  'string', 'table', 'math', 'os', 'io', 'debug', 'coroutine', 'bit', 'bit32', 'utf8', 'package', '_G', '_VERSION', '_ENV',
]);
