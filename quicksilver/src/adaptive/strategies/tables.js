// Constant tables read through computed keys.
//
//     local T = { "print", "Hello", "world", ... }
//     T[3]            T[i - 7]            T[#T]
//
// A table that is filled once with constants and never written to or handed to anything else holds the same values wherever it is read, so
// each read whose key can be computed is replaced by the value. Tables that are rotated or filled in later (a shuffle loop after the
// constructor) are not constant and are left to the decoder evaluation, which runs the code that shuffles them.
//
// Only tables read the way a string table is read are touched: a list (keys 1..n), three entries or more, and at least three reads with a
// number key. A table with named fields (`cfg.speed`) is the program's own data and stays as written.

import { walk, transform } from '../../core/walk.js';
import { ConstTable, NOT_CONST } from '../concrete.js';
import { makeConst } from '../../passes/fold.js';
import { lineOf } from '../util.js';

/** A table of the form `{ a, b, c }`: keys 1..n and nothing else. Tables with named fields are the program's data. */
const isList = (t) => t.map.size > 0 && t.length() === t.map.size;

/** Reads of read-only constant tables: [{ node, table: Var, value }]. */
export function findTableReads(ast, an) {
  const { info } = an;
  const out = [];
  const stored = new WeakSet();
  walk(ast, (n) => {
    if (n.type === 'Assign') for (const t of n.targets) if (t.type === 'Index') stored.add(t);
    return undefined;
  });
  const perTable = new Map();
  walk(ast, (n) => {
    if (n.type !== 'Index' || n.obj.type !== 'Name' || stored.has(n)) return;
    if (n.key.type === 'String' && n.dot) return;
    const v = info.varOf.get(n.obj);
    if (!v || !an.machine(v.name)) return;
    const t = an.constant(v);
    if (!(t instanceof ConstTable) || !isList(t)) return;
    const key = an.evalExpr(n.key);
    if (key === NOT_CONST || typeof key !== 'number') return;
    const value = t.get(key);
    if (value instanceof ConstTable) return;
    if (!perTable.has(v)) perTable.set(v, []);
    perTable.get(v).push({ node: n, table: v, value, key });
  });
  for (const [v, reads] of perTable) {
    const t = an.constant(v);
    if (t.map.size < 3 || reads.length < 3) continue;
    out.push(...reads);
  }
  return out;
}

export const tables = {
  id: 'tables.resolve',
  title: 'Read constant tables',
  order: 25,

  observe(ast, an) {
    const reads = findTableReads(ast, an);
    const by = new Map();
    for (const r of reads) { if (!by.has(r.table)) by.set(r.table, []); by.get(r.table).push(r); }
    return [...by].map(([v, list]) => ({
      kind: 'constant-table',
      line: lineOf(v.init),
      label: `\`${v.name}\` is a table of constants read ${list.length} time${list.length === 1 ? '' : 's'} through computed keys`,
      evidence: [`${an.constant(v).map.size} entries, never written to or passed on`, `${list.length} reads whose key can be computed`],
      confidence: 0.95,
      weight: 0.4 * list.length,
    }));
  },

  run(ast, ctx) {
    const an = ctx.analyse();
    const reads = findTableReads(ast, an);
    const byNode = new Map(reads.map((r) => [r.node, r]));
    let changed = 0;
    transform(ast, {
      expr(e) {
        const r = e.type === 'Index' ? byNode.get(e) : null;
        if (!r) return undefined;
        changed++;
        return makeConst(r.value);
      },
    });
    return { changed };
  },
};
