// The script's own functions that the VM calls natively (the interpreter holds them as factories that take the variables they close over).
// A factory is cleaned up on its own the way a recovered function is, and `instantiate` writes it out for one set of captured variables:
// `param[i][3]`, the i-th captured variable, is replaced by whatever expression stands for that variable where the function is made.

import { clone, walk } from '../../core/walk.js';
import { foldPass } from '../../passes/fold.js';
import { simplifyPass } from '../../passes/simplify.js';
import { dataflowPass } from '../../passes/dataflow.js';
import { regionPass } from '../../passes/regions.js';
import { renamePass } from '../../passes/rename.js';
import { removeUnusedVararg, tidyIfs } from '../../passes/structure.js';
import { booleanResults, orientComparisons, shortCircuits, tableConstructors, methodCalls, bareNils, functionForms, multiResults, numericLoops, loopForms, unsetLocals } from '../../passes/idioms.js';

const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const isParam = (e, p) => { e = strip(e); return e && e.type === 'Name' && e.name === p; };

/** The text a recovered function would have: literals and call forms as the printer writes them, then the usual clean-up passes and readable names. */
export function tidyFactory(fn) {
  const chunk = { type: 'Chunk', body: [{ type: 'Return', values: [clone(fn)] }], endComments: [], features: new Set() };
  walk(chunk, (n) => {
    if (n.type === 'Number' || n.type === 'String') n.raw = null;
    if ((n.type === 'Call' || n.type === 'MethodCall') && n.sugar === 'string') n.sugar = null;
  });
  const unused = new WeakSet();
  for (let round = 0; round < 8; round++) {
    let total = 0;
    total += multiResults(chunk).changed || 0;
    total += booleanResults(chunk).changed || 0;
    total += shortCircuits(chunk).changed || 0;
    total += tableConstructors(chunk).changed || 0;
    total += methodCalls(chunk).changed || 0;
    total += unsetLocals(chunk).changed || 0;
    total += bareNils(chunk).changed || 0;
    total += orientComparisons(chunk).changed || 0;
    total += foldPass(chunk, { foldCalls: 'obfuscation' }).changed || 0;
    total += simplifyPass(chunk, { unusedAtStart: unused }).changed || 0;
    total += regionPass(chunk).changed || 0;
    total += dataflowPass(chunk).changed || 0;
    total += numericLoops(chunk).changed || 0;
    total += loopForms(chunk).changed || 0;
    total += tidyIfs(chunk).changed || 0;
    if (!total) break;
  }
  removeUnusedVararg(chunk);
  renamePass(chunk, { mode: 'all' });
  functionForms(chunk);
  return chunk.body[0].values[0];
}

export function createNatives(factories) {
  const tidy = new Map();
  const factory = (name) => {
    if (!tidy.has(name)) tidy.set(name, tidyFactory(factories.get(name)));
    return tidy.get(name);
  };
  const stats = { inlined: 0, leftover: 0, unknown: 0 };
  /** The function factory `name` makes when it is given `caps` (one expression per captured variable) as `param[1]`, `param[2]`, ... */
  function instantiate(name, caps, seen = []) {
    if (!factories.has(name) || seen.length > 12) { stats.unknown++; return null; }
    const outer = clone(factory(name));
    if (outer.type !== 'Func' || !outer.params || outer.params.length !== 2) { stats.unknown++; return null; }
    const [self, param] = outer.params.map((p) => p.name);
    const sub = (n) => {
      if (!n || typeof n !== 'object') return n;
      if (Array.isArray(n)) return n.map(sub);
      // param[i][3]: the i-th captured variable
      if (n.type === 'Index' && n.key.type === 'Number' && n.key.value === 3) {
        const o = strip(n.obj);
        if (o.type === 'Index' && isParam(o.obj, param) && o.key.type === 'Number' && caps[o.key.value - 1]) return clone(caps[o.key.value - 1]);
      }
      // _:Name{ cells }: another closure of the program, made from the factory of that name
      if (n.type === 'MethodCall' && isParam(n.obj, self) && factories.has(n.name) && n.args.length === 1 && strip(n.args[0]).type === 'Table') {
        const cells = strip(n.args[0]).fields.map((f) => sub(f.value));
        const inner = cells.map((c) => {
          const x = strip(c);
          if (x.type === 'Index' && isParam(x.obj, param) && x.key.type === 'Number') return caps[x.key.value - 1] || null;
          return x.type === 'Name' ? x : null;
        });
        if (inner.every(Boolean)) { const f = instantiate(n.name, inner, [...seen, name]); if (f) return f; }
      }
      const c = { ...n };
      for (const key of Object.keys(c)) if (key !== 'line' && c[key] && typeof c[key] === 'object') c[key] = sub(c[key]);
      return c;
    };
    const body = sub(outer.body);
    let uses = 0;
    (function w(n) { if (!n || typeof n !== 'object') return; if (Array.isArray(n)) return n.forEach(w); if (n.type === 'Name' && (n.name === param || n.name === self)) uses++; for (const key of Object.keys(n)) if (key !== 'line' && typeof n[key] === 'object') w(n[key]); })(body);
    stats.inlined++;
    if (uses) stats.leftover++;
    // the factory returns the function; with set-up code before it, the function is made by calling the factory body
    if (body.length === 1 && body[0].type === 'Return' && body[0].values.length === 1 && strip(body[0].values[0]).type === 'Func') return strip(body[0].values[0]);
    return { type: 'Call', fn: { type: 'Paren', expr: { type: 'Func', params: [], vararg: false, body, isMethod: false, generics: null, returnType: null } }, args: [], sugar: null };
  }
  return { instantiate, stats, factory };
}
