// Generic AST traversal.
//
//   walk(node, fn)        read-only depth-first visit, fn(node, parent) -> false skips the subtree
//   transform(chunk, v)   bottom-up rewrite; v.expr(e) / v.stmt(s) may return a replacement
//   structuralKey(node)   canonical string ignoring layout, used to compare ASTs
//
// transform() visitor hooks: expr(e), stmt(s) and block(stmts) -> new statement array (all optional).
// transform() semantics for statements: undefined keeps the node, null deletes it, an array splices
// several statements in its place, and any other value replaces it.

/** Visit every AST node below `node` in source order. */
export function walk(node, fn, parent = null) {
  if (!node || typeof node !== 'object') return;
  if (Array.isArray(node)) { for (const n of node) walk(n, fn, parent); return; }
  if (fn(node, parent) === false) return;
  const w = (c) => walk(c, fn, node);
  switch (node.type) {
    case 'Chunk': w(node.body); break;
    case 'Local': w(node.ids); w(node.values); break;
    case 'Assign': w(node.targets); w(node.values); break;
    case 'CompoundAssign': w(node.target); w(node.value); break;
    case 'CallStmt': w(node.call); break;
    case 'Do': w(node.body); break;
    case 'While': w(node.cond); w(node.body); break;
    case 'Repeat': w(node.body); w(node.cond); break;
    case 'If':
      for (const c of node.clauses) { w(c.cond); w(c.body); }
      if (node.orelse) w(node.orelse);
      break;
    case 'NumFor': w(node.id); w(node.start); w(node.stop); if (node.step) w(node.step); w(node.body); break;
    case 'GenFor': w(node.ids); w(node.exprs); w(node.body); break;
    case 'Function': w(node.target); w(node.func); break;
    case 'LocalFunction': w(node.id); w(node.func); break;
    case 'Return': w(node.values); break;
    case 'Func': w(node.params); w(node.body); break;
    case 'Index': w(node.obj); w(node.key); break;
    case 'Call': w(node.fn); w(node.args); break;
    case 'MethodCall': w(node.obj); w(node.args); break;
    case 'Table':
      for (const f of node.fields) { if (f.kind === 'keyed') w(f.key); w(f.value); }
      break;
    case 'Binary': w(node.left); w(node.right); break;
    case 'Unary': w(node.arg); break;
    case 'Paren': w(node.expr); break;
    case 'IfExpr': w(node.cond); w(node.then); w(node.orelse); break;
    case 'TypeAssert': w(node.expr); break;
    case 'Interp': for (const p of node.parts) if (typeof p !== 'string') w(p); break;
    default: break; // leaves: Id, Name, Number, String, Nil, True, False, Vararg, Break, Goto, ...
  }
}

class Transformer {
  constructor(visitor) { this.v = visitor; }

  block(stmts) {
    const out = [];
    for (const s of stmts) {
      const r = this.stmt(s);
      if (r === undefined) out.push(s);
      else if (r === null) continue;
      else if (Array.isArray(r)) out.push(...r);
      else out.push(r);
    }
    if (stmts.endComments) out.endComments = stmts.endComments;
    // Block-level hook: sees the finished statement list, so it can look at siblings.
    if (this.v.block) {
      const r = this.v.block(out);
      if (r !== undefined) { if (stmts.endComments && !r.endComments) r.endComments = stmts.endComments; return r; }
    }
    return out;
  }

  exprs(list) { return list.map((e) => this.expr(e)); }

  stmt(s) {
    switch (s.type) {
      case 'Local': s.values = this.exprs(s.values); break;
      case 'Assign': s.targets = this.exprs(s.targets); s.values = this.exprs(s.values); break;
      case 'CompoundAssign': s.target = this.expr(s.target); s.value = this.expr(s.value); break;
      case 'CallStmt': s.call = this.expr(s.call); break;
      case 'Do': s.body = this.block(s.body); break;
      case 'While': s.cond = this.expr(s.cond); s.body = this.block(s.body); break;
      case 'Repeat': s.body = this.block(s.body); s.cond = this.expr(s.cond); break;
      case 'If':
        for (const c of s.clauses) { c.cond = this.expr(c.cond); c.body = this.block(c.body); }
        if (s.orelse) s.orelse = this.block(s.orelse);
        break;
      case 'NumFor':
        s.start = this.expr(s.start); s.stop = this.expr(s.stop);
        if (s.step) s.step = this.expr(s.step);
        s.body = this.block(s.body);
        break;
      case 'GenFor': s.exprs = this.exprs(s.exprs); s.body = this.block(s.body); break;
      case 'Function': s.target = this.expr(s.target); s.func = this.expr(s.func); break;
      case 'LocalFunction': s.func = this.expr(s.func); break;
      case 'Return': s.values = this.exprs(s.values); break;
      default: break;
    }
    return this.v.stmt ? this.v.stmt(s) : undefined;
  }

  expr(e) {
    switch (e.type) {
      case 'Func': e.body = this.block(e.body); break;
      case 'Index': e.obj = this.expr(e.obj); if (!(e.key.type === 'String' && e.dot)) e.key = this.expr(e.key); break;
      case 'Call': e.fn = this.expr(e.fn); e.args = this.exprs(e.args); break;
      case 'MethodCall': e.obj = this.expr(e.obj); e.args = this.exprs(e.args); break;
      case 'Table':
        for (const f of e.fields) { if (f.kind === 'keyed') f.key = this.expr(f.key); f.value = this.expr(f.value); }
        break;
      case 'Binary': e.left = this.expr(e.left); e.right = this.expr(e.right); break;
      case 'Unary': e.arg = this.expr(e.arg); break;
      case 'Paren': e.expr = this.expr(e.expr); break;
      case 'IfExpr': e.cond = this.expr(e.cond); e.then = this.expr(e.then); e.orelse = this.expr(e.orelse); break;
      case 'TypeAssert': e.expr = this.expr(e.expr); break;
      case 'Interp': e.parts = e.parts.map((p) => (typeof p === 'string' ? p : this.expr(p))); break;
      default: break;
    }
    if (!this.v.expr) return e;
    const r = this.v.expr(e);
    return r === undefined ? e : r;
  }
}

/** Rewrite `chunk` in place (and return it). Children are transformed before their parents. */
export function transform(chunk, visitor) {
  const t = new Transformer(visitor);
  chunk.body = t.block(chunk.body);
  return chunk;
}

/** Transform a standalone block (array of statements); returns the new array. */
export function transformBlock(stmts, visitor) {
  return new Transformer(visitor).block(stmts);
}

/** Transform a single expression; returns the (possibly replaced) expression. */
export function transformExpr(expr, visitor) {
  return new Transformer(visitor).expr(expr);
}

const LAYOUT_KEYS = new Set([
  'line', 'pos', 'endPos', 'endLine', 'blankBefore', 'comments', 'trailing', 'endComments',
  'raw', 'sugar', 'dot', 'long', 'quote', 'features', 'semicolon', 'attributes',
]);

/** Canonical JSON of the semantic content of a tree (layout metadata is ignored). */
export function structuralKey(node) {
  return JSON.stringify(node, (key, value) => {
    if (LAYOUT_KEYS.has(key)) return undefined;
    // `{ a = 1 }` and `{ ["a"] = 1 }` are the same table constructor.
    if (value && value.kind === 'named') return { kind: 'keyed', key: { type: 'String', value: value.key }, value: value.value };
    if (typeof value === 'number' && !Number.isFinite(value)) return String(value);
    if (Object.is(value, -0)) return '-0';
    return value;
  });
}

/** Deep copy of an AST subtree (keeps comment arrays by reference; they are never mutated). */
export function clone(node) {
  if (Array.isArray(node)) {
    const out = node.map(clone);
    if (node.endComments) out.endComments = node.endComments;
    return out;
  }
  if (node && typeof node === 'object') {
    if (node instanceof Set) return new Set(node);
    const out = {};
    for (const k of Object.keys(node)) out[k] = (k === 'comments' || k === 'trailing' || k === 'endComments') ? node[k] : clone(node[k]);
    return out;
  }
  return node;
}
