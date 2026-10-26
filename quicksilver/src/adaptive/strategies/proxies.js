// Call proxies: small local functions that only stand in for an operation.
//
//     local function add(a, b) return a + b end
//     local function call(f, ...) return f(...) end          -- (forwarding forms with `...` are left alone)
//     local function key() return "name" end
//
// Wrapping every operator and library call in such a function hides what a program does behind names that mean nothing. A call of one is
// replaced by its body with the arguments put in place of the parameters, when that cannot change what the program does:
//
//   * the function is a local that is never assigned again, and its body is one `return <expression>`;
//   * the expression uses only its parameters, literals and global names that nothing in the script declares as a local;
//   * the call has exactly as many arguments as there are parameters, none of them a call that could return several values;
//   * either every argument is simple (a literal, or a variable that is never reassigned), or each parameter is used exactly once,
//     unconditionally, in the order the arguments were written, so the arguments are evaluated in the same order.

import { walk, clone, transform } from '../../core/walk.js';
import { strip, lineOf, sizeOf } from '../util.js';

const MAX_BODY = 40;

/** Is the expression something that can be evaluated twice or out of order without anyone noticing? */
function simple(e, info) {
  e = strip(e);
  switch (e.type) {
    case 'Number': case 'String': case 'True': case 'False': case 'Nil': return true;
    case 'Name': { const v = info.varOf.get(e); return !!v && !v.isGlobal && v.writes.length === 0; }
    case 'Unary': return (e.op === '-' || e.op === 'not') && simple(e.arg, info);
    case 'Binary': return !['..', '/', '%', '^', '//'].includes(e.op) && simple(e.left, info) && simple(e.right, info);
    default: return false;
  }
}

/** Description of a function that qualifies as a proxy, or null. */
function proxyBody(fn, name, an) {
  const { info } = an;
  if (fn.vararg || fn.isMethod || fn.body.length !== 1 || fn.body[0].type !== 'Return') return null;
  const ret = fn.body[0];
  if (ret.values.length !== 1) return null;
  const expr = ret.values[0];
  if (sizeOf(expr) > MAX_BODY) return null;
  const params = fn.params.map((p) => info.varOf.get(p));
  if (params.some((p) => !p)) return null;
  // global names are fine when nothing in the script declares a local of the same name (so they mean the same at every call site)
  const uses = new Map();
  let order = [];
  let conditional = false;
  let ok = true;
  let calls = null;
  const visit = (n, cond, depth = 0) => {
    if (!ok || !n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach((x) => visit(x, cond, depth)); return; }
    switch (n.type) {
      case 'Func': case 'Vararg': case 'Interp': ok = false; return;
      case 'Name': {
        const v = info.varOf.get(n);
        if (!v) { ok = false; return; }
        const k = params.indexOf(v);
        if (k >= 0) { uses.set(k, (uses.get(k) || 0) + 1); order.push(k); if (cond) conditional = true; }
        else if (v.isGlobal) { if (an.shadowed.has(n.name)) ok = false; }
        // a local of the chunk's top level that is never assigned and whose name is used for nothing else means the same at every call
        else if (v.funcDepth !== 0 || v.writes.length || (an.nameCount.get(n.name) || 0) !== 1) ok = false;
        return;
      }
      case 'Binary':
        visit(n.left, cond, depth);
        visit(n.right, cond || n.op === 'and' || n.op === 'or', depth);
        return;
      case 'IfExpr': visit(n.cond, cond, depth); visit(n.then, true, depth); visit(n.orelse, true, depth); return;
      case 'Index': visit(n.obj, cond, depth); if (!(n.key.type === 'String' && n.dot)) visit(n.key, cond, depth); return;
      case 'Call': if (depth > 0) calls = 'inner'; visit(n.fn, cond, depth + 1); visit(n.args, cond, depth + 1); return;
      case 'MethodCall': if (depth > 0) calls = 'inner'; visit(n.obj, cond, depth + 1); visit(n.args, cond, depth + 1); return;
      case 'Unary': visit(n.arg, cond, depth); return;
      case 'Paren': visit(n.expr, cond, depth); return;
      case 'Table': for (const f of n.fields) { if (f.kind === 'keyed') visit(f.key, cond, depth); visit(f.value, cond, depth); } return;
      case 'Number': case 'String': case 'True': case 'False': case 'Nil': return;
      default: ok = false;
    }
  };
  visit(expr, false);
  if (!ok) return null;
  const once = params.every((_, k) => uses.get(k) === 1);
  const inOrder = order.every((k, i) => k === i) && order.length === params.length;
  return { expr, params, once, inOrder, conditional, rootCallOnly: calls === null, unused: params.map((_, k) => !uses.has(k)), name };
}

/** Local functions that qualify, with every place they are called. */
export function findProxies(ast, an) {
  const { info } = an;
  const found = new Map();
  for (const v of info.vars) {
    if ((v.kind !== 'localfunc' && v.kind !== 'local') || !v.init || strip(v.init).type !== 'Func' || v.writes.length) continue;
    const b = proxyBody(strip(v.init), v.name, an);
    if (b) found.set(v, { ...b, v, sites: [], escapes: 0 });
  }
  if (!found.size) return [];
  const parents = new WeakMap();
  walk(ast, (n, parent) => { if (parent) parents.set(n, parent); });
  for (const [v, p] of found) {
    for (const r of v.reads) {
      const parent = parents.get(r);
      if (parent && parent.type === 'Call' && parent.fn === r && callable(parent, p, info)) p.sites.push(parent);
      else p.escapes++;
    }
  }
  const withSites = [...found.values()].filter((p) => p.sites.length);
  // Names say what a person meant. A script that hides many of its operations behind tiny functions has no such person to respect: four or
  // more proxies, each called three times or more, are a disguise whatever they are called.
  const bulk = withSites.filter((p) => p.sites.length >= 3).length >= 4;
  return withSites.filter((p) => bulk || an.machine(p.name));
}

function callable(call, p, info) {
  if (call.args.length !== p.params.length) return false;
  const last = call.args[call.args.length - 1];
  if (last && ['Call', 'MethodCall', 'Vararg'].includes(strip(last).type) && last.type !== 'Paren') return false;
  const allSimple = call.args.every((a) => simple(a, info));
  if (allSimple) return true;
  // otherwise the arguments keep their order only if each parameter is used once, unconditionally and in order, and the body does nothing
  // but compute until its outermost call (so every argument is evaluated before anything happens, as it was)
  return p.once && p.inOrder && !p.conditional && p.rootCallOnly;
}

export const proxies = {
  id: 'proxies.inline',
  title: 'Inline call proxies',
  order: 20,

  observe(ast, an) {
    return findProxies(ast, an).map((p) => ({
      kind: 'call-proxy',
      line: lineOf(p.v.init),
      label: `\`${p.name}\` only stands in for ${p.expr.type === 'Call' ? 'a call' : p.expr.type === 'Binary' ? `\`${p.expr.op}\`` : 'an expression'} (${p.sites.length} call${p.sites.length === 1 ? '' : 's'})`,
      evidence: [`its body is a single return of an expression over its parameters`, `${p.sites.length} call site(s) can take the body in place`],
      confidence: 0.9,
      weight: 0.4 * p.sites.length,
    }));
  },

  run(ast, ctx) {
    let changed = 0;
    const inlined = [];
    for (let round = 0; round < 6; round++) {
      const an = ctx.analyse(round > 0);
      const list = findProxies(ast, an);
      if (!list.length) break;
      const bySite = new Map();
      for (const p of list) for (const c of p.sites) bySite.set(c, p);
      let did = 0;
      // a call that is a statement of its own: replaced by a call it stays one, replaced by a value there is nothing left to do
      const alone = new Set();
      walk(ast, (n) => { if (n.type === 'CallStmt') alone.add(n.call); return undefined; });
      const bodyOf = (e, p, an) => {
        const args = e.args;
        const sub = (n) => {
          if (!n || typeof n !== 'object') return n;
          if (Array.isArray(n)) return n.map(sub);
          if (n.type === 'Name') {
            const v = an.info.varOf.get(n);
            const k = v ? p.params.indexOf(v) : -1;
            if (k >= 0) return clone(args[k]);
            return { ...n };
          }
          const copy = { ...n };
          for (const key of Object.keys(copy)) if (key !== 'line' && key !== 'pos' && copy[key] && typeof copy[key] === 'object') copy[key] = sub(copy[key]);
          return copy;
        };
        return sub(p.expr);
      };
      transform(ast, {
        expr(e) {
          const p = e.type === 'Call' ? bySite.get(e) : null;
          if (!p) return undefined;
          // an unused parameter's argument would no longer be evaluated: it must have nothing to do
          if (p.unused.some((u, k) => u && !simple(e.args[k], an.info))) return undefined;
          const body = bodyOf(e, p, an);
          if (alone.has(e) && body.type !== 'Call' && body.type !== 'MethodCall') return undefined;
          did++;
          inlined.push({ name: p.name, line: e.line || 0 });
          return body;
        },
        stmt(st) {
          // `K()` on its own computed nothing but a value: with simple arguments the statement is dead
          if (st.type !== 'CallStmt' || !bySite.has(st.call)) return undefined;
          const p = bySite.get(st.call);
          if (!st.call.args.every((a) => simple(a, an.info))) return undefined;
          did++;
          inlined.push({ name: p.name, line: st.call.line || 0 });
          return null;
        },
      });
      changed += did;
      if (!did) break;
    }
    return { changed, inlined: inlined.length };
  },
};
