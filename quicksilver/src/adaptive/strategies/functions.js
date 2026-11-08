// Functions kept in a table and reached only through it.
//
//     local T = {}
//     T.a = function(x) ... T.b(x) ... end
//     function T.b(x) ... end
//     print(T.a(1))
//
// A table that exists to hold functions, whose every other use is a call or read of one of them by name, is an indirection and not a data structure:
// each field is the same function wherever it is read. The fields become local functions (declared together first when one refers to another that
// is defined later), and every `T.a` becomes `a`.
//
// The table's name decides whether it is a tool's doing; the field names only become local names. What it will not touch: a table with a human-looking name (`Utils.format` is how a module is written, and the author's own); a table that is
// passed on, iterated, indexed with a computed key, assigned, given a method or a metatable; a field that is written twice or read but never
// defined; a field name that is already a name in use anywhere in the script (it would capture or be captured).

import { walk, transform } from '../../core/walk.js';
import { isIdentifier } from '../../core/printer.js';
import { lineOf, strip } from '../util.js';

/** Every table the strategy can lift: [{ v, decl, block, fields: Map(name -> def), uses: [Index], order }]. */
export function findFunctionTables(ast, an) {
  const { info } = an;
  const found = [];
  const blocks = [];
  const collect = (list) => blocks.push(list);
  collect(ast.body);
  walk(ast, (n) => {
    for (const k of ['body', 'orelse']) if (Array.isArray(n[k])) collect(n[k]);
    if (n.clauses) for (const c of n.clauses) collect(c.body);
    return undefined;
  });

  for (const block of blocks) {
    block.forEach((stmt, index) => {
      if (stmt.type !== 'Local' || stmt.ids.length !== 1 || stmt.values.length !== 1) return;
      const init = strip(stmt.values[0]);
      if (!init || init.type !== 'Table' || init.fields.length) return;
      const v = info.varOf.get(stmt.ids[0]);
      if (!v || v.writes.length || !an.machine(v.name)) return;

      const fields = new Map();         // name -> { stmt, func, index }
      const defTargets = new Set();     // Index nodes that are the target of a definition
      const bad = new Set();
      block.forEach((s, i) => {
        if (s.type === 'Assign' && s.targets.length === 1 && s.values.length === 1) {
          const t = s.targets[0];
          const f = strip(s.values[0]);
          if (t.type === 'Index' && t.dot && t.key.type === 'String' && t.obj.type === 'Name' && info.varOf.get(t.obj) === v && f && f.type === 'Func' && !f.isMethod) {
            if (fields.has(t.key.value)) bad.add(t.key.value);
            fields.set(t.key.value, { stmt: s, func: f, index: i });
            defTargets.add(t);
          }
        } else if (s.type === 'Function' && s.method === null && s.target.type === 'Index' && s.target.dot && s.target.key.type === 'String' && s.target.obj.type === 'Name' && info.varOf.get(s.target.obj) === v) {
          if (fields.has(s.target.key.value)) bad.add(s.target.key.value);
          fields.set(s.target.key.value, { stmt: s, func: s.func, index: i });
          defTargets.add(s.target);
        }
      });
      if (fields.size < 1 || bad.size) return;

      // every other mention of the table must be `T.name` for a defined name
      const uses = [];
      let ok = true;
      walk(ast, (n, parent) => {
        if (!ok || n.type !== 'Name' || info.varOf.get(n) !== v || n === stmt.ids[0]) return;
        if (!parent || parent.type !== 'Index' || parent.obj !== n || parent.key.type !== 'String' || !parent.dot || !fields.has(parent.key.value)) { ok = false; return; }
        if (!defTargets.has(parent)) uses.push(parent);
      });
      if (!ok || !uses.length) return;
      for (const nm of fields.keys()) {
        if (!isIdentifier(nm) || an.names.has(nm)) return;
      }
      found.push({ v, decl: stmt, block, index, fields, uses, defTargets });
    });
  }
  return found;
}

/** Can every field become `local function` in place? Only if nothing is used before its definition (a function that calls a later one needs forward declarations). */
function inOrder(t) {
  const owner = (node) => {
    let at = -1;
    t.block.forEach((s, i) => { if (at === -1) walk(s, (n) => { if (n === node) at = i; return at === -1 ? undefined : false; }); });
    return at;
  };
  for (const use of t.uses) {
    const at = owner(use);
    const def = t.fields.get(use.key.value);
    if (at < def.index) return false;
  }
  return true;
}

export const functions = {
  id: 'functions.lift',
  title: 'Lift functions out of a table',
  order: 27,

  observe(ast, an) {
    return findFunctionTables(ast, an).map((t) => ({
      kind: 'function-table',
      line: lineOf(t.decl),
      label: `\`${t.v.name}\` holds ${t.fields.size} functions and is only used to call them`,
      evidence: [`fields: ${[...t.fields.keys()].slice(0, 5).join(', ')}`, `${t.uses.length} call${t.uses.length === 1 ? '' : 's'} through the table`, 'the table is never passed on, iterated or indexed with a computed key'],
      confidence: 0.9,
      weight: 0.5 * t.fields.size,
    }));
  },

  run(ast, ctx) {
    const an = ctx.analyse();
    const tables = findFunctionTables(ast, an);
    if (!tables.length) return { changed: 0 };
    const useName = new Map();
    const stmtSwap = new Map();
    let changed = 0;
    for (const t of tables) {
      const direct = inOrder(t);
      for (const u of t.uses) useName.set(u, u.key.value);
      for (const [name, def] of t.fields) {
        const isFn = def.stmt.type === 'Function';
        const ids = { type: 'Id', name };
        stmtSwap.set(def.stmt, direct
          ? { type: 'LocalFunction', id: ids, func: def.func }
          : { type: 'Function', target: { type: 'Name', name }, method: null, func: def.func });
        void isFn;
      }
      // the declaration: gone when the functions are declared where they are defined, else a list of the names to be defined later
      stmtSwap.set(t.decl, direct ? null : { type: 'Local', ids: [...t.fields.keys()].map((n) => ({ type: 'Id', name: n })), values: [] });
      changed += t.fields.size;
    }
    transform(ast, {
      expr(e) { return e.type === 'Index' && useName.has(e) ? { type: 'Name', name: useName.get(e) } : undefined; },
      stmt(s) { return stmtSwap.has(s) ? stmtSwap.get(s) : undefined; },
    });
    return { changed };
  },
};
