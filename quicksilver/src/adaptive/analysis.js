// Whole-chunk facts the strategies share: what is constant, which tables are never written, which names a local hides.

import { walk } from '../core/walk.js';
import { analyze } from '../core/scope.js';
import { evaluate, NOT_CONST, ConstTable } from './concrete.js';
import { strip } from './util.js';
import { isMachineName } from '../passes/rename.js';

/**
 * Scope analysis plus the constants of the chunk.
 *   info        core/scope.js result
 *   shadowed    names some local is called (so `string` etc. may not be the library)
 *   names       every name in use, locals and globals, to make up fresh ones from
 *   constant(v) the value of a local that is declared with a constant and never assigned again (a ConstTable for a table nothing writes to)
 *   machine(n)  does the name look machine-made (or is the whole script machine-named)? Strategies that would rewrite code a person may have
 *               written, small helpers and lookup tables, act on those only
 */
export function analyse(chunk) {
  const info = analyze(chunk);
  const shadowed = new Set(info.vars.map((v) => v.name));
  const names = new Set([...shadowed, ...info.globals.keys()]);
  const nameCount = new Map();
  for (const v of info.vars) nameCount.set(v.name, (nameCount.get(v.name) || 0) + 1);
  const readOnly = readOnlyTables(chunk, info);
  // Code the author wrote is left as written. A name decides it: machine-made names mark what a tool made, and when most of a script's
  // names are machine-made so is the script, and a readable-looking helper in it is part of the disguise.
  const locals = info.vars.filter((v) => v.kind !== 'global');
  const mangled = locals.length >= 8 && locals.filter((v) => isMachineName(v.name)).length / locals.length > 0.6;
  // `P__12`, `v_3`: a stem, underscores and a counter are how tools number what they make
  const machine = (nm) => mangled || isMachineName(nm) || /^[A-Za-z]{1,2}_{1,3}\d+$/.test(nm) || /__\d+$/.test(nm);
  const cache = new Map();
  /** The value of an expression made of constants (names resolved through their declarations), or NOT_CONST; `extra` maps Vars to values. */
  const evalExpr = (e, extra = null) => {
    const env = new Map();
    let ok = true;
    walk(e, (n) => {
      if (!ok || n.type !== 'Name') return;
      const v = info.varOf.get(n);
      if (v && v.isGlobal) return;           // a global is the library (`tonumber`, `string`) or unknown: the evaluator decides
      const k = extra && extra.has(v) ? extra.get(v) : v ? constant(v) : NOT_CONST;
      if (k === NOT_CONST) ok = false; else env.set(n.name, k);
    });
    return ok ? evaluate(e, (nm) => (env.has(nm) ? env.get(nm) : NOT_CONST), { shadowed }) : NOT_CONST;
  };
  const constant = (v) => {
    if (!v || v.isGlobal) return NOT_CONST;
    if (cache.has(v)) return cache.get(v);
    cache.set(v, NOT_CONST);
    let out = NOT_CONST;
    if (v.kind === 'local' && v.writes.length === 0 && v.hasInit && v.init) {
      const init = strip(v.init);
      if (init.type === 'Table') {
        if (readOnly.has(v)) {
          const t = ConstTable.fromNode(init, (e) => evalExpr(e));
          if (t) out = t;
        }
      } else {
        const value = evalExpr(init);
        if (value !== NOT_CONST) out = value;
      }
    }
    cache.set(v, out);
    return out;
  };
  return { info, shadowed, names, nameCount, readOnly, constant, evalExpr, machine, mangled };
}

/** Locals that hold a table constructor and are only ever indexed for reading (`t[k]`, `t.k`, `#t`): nothing stores into them or lets them out. */
export function readOnlyTables(chunk, info) {
  const stored = new WeakSet();     // Index nodes that are assignment targets
  walk(chunk, (n) => {
    if (n.type === 'Assign') for (const t of n.targets) { if (t.type === 'Index') stored.add(t); }
    else if (n.type === 'CompoundAssign' && n.target.type === 'Index') stored.add(n.target);
    else if (n.type === 'Function' && n.target.type === 'Index') stored.add(n.target);
    return undefined;
  });
  const candidates = new Set(info.vars.filter((v) => v.init && strip(v.init).type === 'Table' && v.writes.length === 0));
  const bad = new Set();
  walk(chunk, (n, parent) => {
    if (n.type !== 'Name') return;
    const v = info.varOf.get(n);
    if (!v || !candidates.has(v)) return;
    if (v.decl === n) return;
    const read = parent && ((parent.type === 'Index' && parent.obj === n && !stored.has(parent)) || (parent.type === 'Unary' && parent.op === '#' && parent.arg === n));
    if (!read) bad.add(v);
  });
  return new Set([...candidates].filter((v) => !bad.has(v)));
}
