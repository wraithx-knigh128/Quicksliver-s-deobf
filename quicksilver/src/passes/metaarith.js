// Numbers hidden behind metamethod arithmetic.
//
// LuaXen's AST stage writes a number as an operation on two throw-away values whose metamethod does the arithmetic:
//
//     setmetatable({}, { __div = function(_, a) local x, y, z = a[1], a[2], a[3] return x * x - y * y + z end }) / { 21792, 57683, 2852437225 }
//
// The metatable belongs to a table nothing else holds, the right operand is a table of numbers, and the function is a few locals read from that table
// and one arithmetic expression: nothing else can reach it, so the expression is evaluated here (numbers only, nothing run) and is the number. The shape
// is general, not LuaXen's: any binary metamethod (`__add`, `__sub`, `__mul`, `__div`, `__mod`, `__pow`, `__concat`), any function of that form. A function that
// reads its first parameter (the table the operator was applied to), calls anything or has another statement is left alone.
//
// LuaXen writes strings the same way with a loop in the function (`str = str .. str.char(x * x - y * y + z)` for every triple of the right operand), and
// any function could. Those are run, not read: when the sandbox is switched on, an operation of this shape whose functions touch nothing but the
// standard libraries (checked on the syntax tree: every name is declared inside the expression or is a standard global that is not assigned) is
// evaluated in the sandbox and replaced by the string or number it gives.

import { transform } from '../core/walk.js';
import { analyze } from '../core/scope.js';
import { makeConst } from './fold.js';
import { createMachine } from '../sandbox/sandbox.js';
import { compileAst, callValue } from '../sandbox/interp.js';

const META = { '+': '__add', '-': '__sub', '*': '__mul', '/': '__div', '%': '__mod', '^': '__pow', '..': '__concat' };
const unparen = (e) => (e && e.type === 'Paren' ? unparen(e.expr) : e);
const NOPE = Symbol('not a number expression');

/** The numbers of a table constructor of numeric literals (positional), or null. */
function numbersOf(t) {
  if (!t || t.type !== 'Table' || !t.fields.length) return null;
  const out = [];
  for (const f of t.fields) {
    const v = unparen(f.value);
    if (f.kind !== 'item') return null;
    if (v.type === 'Number') out.push(v.value);
    else if (v.type === 'Unary' && v.op === '-' && unparen(v.arg).type === 'Number') out.push(-unparen(v.arg).value);
    else return null;
  }
  return out;
}

/** Evaluate an expression over numbers: `env` maps a local name to a number, `tables` maps a name to the array it holds. */
function evaluate(e, env, tables) {
  e = unparen(e);
  switch (e.type) {
    case 'Number': return e.value;
    case 'Name': return env.has(e.name) ? env.get(e.name) : NOPE;
    case 'Index': {
      const o = unparen(e.obj);
      const k = unparen(e.key);
      if (o.type !== 'Name' || !tables.has(o.name) || k.type !== 'Number') return NOPE;
      const v = tables.get(o.name)[k.value - 1];
      return typeof v === 'number' ? v : NOPE;
    }
    case 'Unary': { const a = evaluate(e.arg, env, tables); return e.op === '-' && a !== NOPE ? -a : NOPE; }
    case 'Binary': {
      const a = evaluate(e.left, env, tables);
      const b = evaluate(e.right, env, tables);
      if (a === NOPE || b === NOPE) return NOPE;
      switch (e.op) {
        case '+': return a + b;
        case '-': return a - b;
        case '*': return a * b;
        case '/': return a / b;
        case '%': return b === 0 ? NOPE : a - Math.floor(a / b) * b;
        case '^': return a ** b;
        default: return NOPE;
      }
    }
    default: return NOPE;
  }
}

/** Globals a self-contained arithmetic function may use. */
const SAFE_GLOBALS = new Set(['string', 'math', 'table', 'tostring', 'tonumber', 'type', 'select', 'ipairs', 'pairs', 'next', 'unpack', 'setmetatable', 'getmetatable', 'rawget', 'rawset', 'rawequal', 'rawlen']);

/** Is the expression a fresh `setmetatable({}, { <one metamethod> })` operation whose every name is declared inside it or is a standard global nobody assigns? */
function selfContained(e, info) {
  let ok = true;
  const declared = new Set();
  const visit = (n, f) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach((x) => visit(x, f)); return; }
    f(n);
    for (const k of Object.keys(n)) if (k !== 'line' && k !== 'comments' && k !== 'trailing' && n[k] && typeof n[k] === 'object') visit(n[k], f);
  };
  visit(e, (n) => { if (n.type === 'Id') { const v = info.varOf.get(n); if (v) declared.add(v); } });
  visit(e, (n) => {
    if (!ok) return;
    if (n.type === 'Vararg') ok = false;
    else if (n.type === 'Name') {
      const v = info.varOf.get(n);
      if (!v) ok = false;
      else if (declared.has(v)) { /* declared inside */ } else if (!(v.isGlobal && v.writes.length === 0 && SAFE_GLOBALS.has(n.name))) ok = false;
    }
  });
  return ok;
}

function runExpression(expr, sandbox) {
  const chunk = { type: 'Chunk', body: [{ type: 'Return', values: [expr] }], endComments: [], features: new Set() };
  const m = createMachine({ fuel: sandbox.fuel ?? 5_000_000, timeMs: Math.min(sandbox.timeMs ?? 2_000, 2_000), dialect: sandbox.dialect || 'luau' });
  const r = callValue(m, compileAst(m, chunk, 'meta', m.globals), [], '')[0];
  return typeof r === 'string' || (typeof r === 'number' && Number.isFinite(r)) ? r : NOPE;
}

export function foldMetaArithmetic(chunk, ctx = {}) {
  const info = analyze(chunk);
  let changed = 0;
  let ran = 0;
  transform(chunk, {
    expr(e) {
      if (e.type !== 'Binary' || !META[e.op]) return undefined;
      const left = unparen(e.left);
      const rightExpr = unparen(e.right);
      if (left.type !== 'Call' || left.fn.type !== 'Name' || left.fn.name !== 'setmetatable' || left.args.length !== 2) return undefined;
      const sv = info.varOf.get(left.fn);
      if (!sv || !sv.isGlobal || sv.writes.length) return undefined;
      const [obj, meta] = left.args.map(unparen);
      if (obj.type !== 'Table' || obj.fields.length || meta.type !== 'Table' || meta.fields.length !== 1 || rightExpr.type !== 'Table') return undefined;
      const f = meta.fields[0];
      const key = f.kind === 'named' ? f.key : f.kind === 'keyed' && unparen(f.key).type === 'String' ? unparen(f.key).value : null;
      const fn = unparen(f.value);
      if (key !== META[e.op] || fn.type !== 'Func' || fn.params.length !== 2 || fn.vararg || !fn.body.length) return undefined;

      // 1. read it: locals from the table and one arithmetic expression
      const nums = numbersOf(rightExpr);
      const [, arg] = fn.params;
      const last = fn.body[fn.body.length - 1];
      if (nums && last.type === 'Return' && last.values.length === 1) {
        const env = new Map();
        const tables = new Map([[arg.name, nums]]);
        let readable = true;
        for (const st of fn.body.slice(0, -1)) {
          if (st.type !== 'Local' || st.values.length !== st.ids.length) { readable = false; break; }
          const vals = st.values.map((v) => evaluate(v, env, tables));
          if (vals.some((v) => v === NOPE)) { readable = false; break; }
          st.ids.forEach((id, i) => env.set(id.name, vals[i]));
        }
        if (readable) {
          const r = evaluate(last.values[0], env, tables);
          if (r !== NOPE && Number.isFinite(r)) { changed++; return makeConst(r); }
        }
      }
      // 2. run it, when it is self-contained and the sandbox is on
      if (!ctx.sandbox || !ctx.sandbox.enabled || !selfContained(e, info)) return undefined;
      try {
        const r = runExpression(e, ctx.sandbox);
        if (r === NOPE) return undefined;
        ran++; changed++;
        return makeConst(r);
      } catch { return undefined; }
    },
  });
  return { changed, ran };
}
