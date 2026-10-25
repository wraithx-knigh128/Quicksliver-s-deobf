// Finding a Vmify script that is no longer in the shape Vmify wrote it.
//
// A script that was compiled by a second Vmify (Prometheus' Strong preset does that) comes back out of the first
// unflattening as ordinary Lua, but ordinary Lua of a particular kind: the first VM's machinery, written the way a register
// machine writes it. Registers are locals, the helper functions are local functions, the preamble that handed them out is a
// run of separate assignments. Nothing there is a fixed layout any more, so this module identifies each part by what it does
// instead of where it sits:
//
//   container    a function of four parameters whose body is a loop over the first one (directly, or through a local copy)
//   creators     what the container calls with (block id, table)
//   alloc / free what it calls with no argument / with one register, and the tables those two touch
//   env          the remaining table the container indexes with registers
//   start        the creator call outside the container, with the entry block id
//
// It returns the same description the exact locator in vmify.js returns, or null.

import { walk } from '../core/walk.js';
import { stripParens, varOf } from './vmify-util.js';

/** Vars declared anywhere inside `node` (parameters, locals, loop variables). */
export function declaredIn(node, info) {
  const set = new Set();
  const add = (id) => { const v = info.varOf.get(id); if (v) set.add(v); };
  walk(node, (n) => {
    switch (n.type) {
      case 'Func': n.params.forEach(add); break;
      case 'Local': n.ids.forEach(add); break;
      case 'LocalFunction': add(n.id); break;
      case 'NumFor': add(n.id); break;
      case 'GenFor': n.ids.forEach(add); break;
      default: break;
    }
  });
  return set;
}

/** Follow `local a = b` copies (of variables never reassigned) to the variable they stand for. */
export function canonical(v, info) {
  for (let guard = 0; v && guard < 6; guard++) {
    if (!(v.hasInit && v.writes.length === 0 && v.init)) break;
    const init = stripParens(v.init);
    if (init.type !== 'Name') break;
    const w = info.varOf.get(init);
    if (!w || w.isGlobal) break;
    v = w;
  }
  return v;
}

/** Every function ever assigned to the variable, following copies (`f = g`). */
function funcsAssigned(v, scope, info, depth = 0) {
  const out = [];
  const take = (e) => {
    e = stripParens(e);
    if (!e) return;
    if (e.type === 'Func') out.push(e);
    else if (e.type === 'Name' && depth < 4) { const w = info.varOf.get(e); if (w && w !== v) out.push(...funcsAssigned(w, scope, info, depth + 1)); }
  };
  walk(scope, (n) => {
    if (n.type === 'LocalFunction' && info.varOf.get(n.id) === v) out.push(n.func);
    else if (n.type === 'Function' && n.target.type === 'Name' && info.varOf.get(n.target) === v) out.push(n.func);
    else if (n.type === 'Local') n.ids.forEach((id, i) => { if (info.varOf.get(id) === v) take(n.values[i]); });
    else if (n.type === 'Assign') n.targets.forEach((t, i) => { if (t.type === 'Name' && info.varOf.get(t) === v) take(n.values[i]); });
  });
  return out;
}

/** `loop` and `tree` of a container, and the variable holding the block id. */
function dispatcherOf(f, info) {
  const loop = f.body.find((s) => s.type === 'While');
  if (!loop) return null;
  const p0 = info.varOf.get(f.params[0]);
  const c = stripParens(loop.cond);
  if (c.type === 'Name') {
    // `while pos do`, with pos the parameter itself or a local that started as a copy of it
    const pv = info.varOf.get(c);
    if (pv === p0) return { loop, tree: loop.body, posVar: p0 };
    if (pv && pv.hasInit && pv.init && stripParens(pv.init).type === 'Name' && info.varOf.get(stripParens(pv.init)) === p0) return { loop, tree: loop.body, posVar: pv };
  }
  if (c.type === 'True') {
    // `while pos do` written as `while true do if not pos then break end ...` with pos a copy of the parameter
    const first = loop.body[0];
    if (first && first.type === 'If' && first.clauses.length === 1 && !first.orelse && first.clauses[0].body.length === 1 && first.clauses[0].body[0].type === 'Break') {
      const cond = stripParens(first.clauses[0].cond);
      if (cond.type === 'Unary' && cond.op === 'not') {
        const x = stripParens(cond.arg);
        const v = x.type === 'Name' ? info.varOf.get(x) : null;
        if (v && v.hasInit && v.init && stripParens(v.init).type === 'Name' && info.varOf.get(stripParens(v.init)) === p0) return { loop, tree: loop.body.slice(1), posVar: v };
      }
    }
  }
  return null;
}

/** Nearest enclosing function of every function. */
function enclosingFunctions(chunk) {
  const parent = new Map();
  const go = (node, fn) => {
    walk(node, (n) => {
      if (n !== node && n.type === 'Func') { parent.set(n, fn); go(n, n); return false; }
      return undefined;
    });
  };
  go(chunk, null);
  return parent;
}

/** The statement(s) of the chunk that start the script: `return F(...)` or `local r = { F(...) } return unpack(r)`. */
function callSite(chunk, outer, info) {
  const bound = new Set();
  walk(chunk, (n) => {
    if (n.type === 'LocalFunction' && n.func === outer) bound.add(info.varOf.get(n.id));
    else if (n.type === 'Local') n.ids.forEach((id, i) => { if (n.values[i] && stripParens(n.values[i]) === outer) bound.add(info.varOf.get(id)); });
    else if (n.type === 'Assign') n.targets.forEach((t, i) => { if (t.type === 'Name' && n.values[i] && stripParens(n.values[i]) === outer) bound.add(info.varOf.get(t)); });
  });
  const isOuter = (e) => {
    const call = stripParens(e);
    if (!call || call.type !== 'Call') return false;
    const f = stripParens(call.fn);
    return f === outer || (f.type === 'Name' && bound.has(info.varOf.get(f)));
  };
  const body = chunk.body;
  for (let i = 0; i < body.length; i++) {
    const s = body[i];
    if (s.type === 'Return' && s.values.length === 1) {
      const v = stripParens(s.values[0]);
      if (isOuter(v)) return { index: i, count: 1 };
      // return unpack({ F(...) })
      if (v.type === 'Call' && v.args.length === 1) {
        const t = stripParens(v.args[0]);
        if (t.type === 'Table' && t.fields.length === 1 && isOuter(t.fields[0].value)) return { index: i, count: 1 };
      }
    }
    const holder = (s.type === 'Local' && s.ids.length === 1 && s.values.length === 1) ? [s.ids[0], s.values[0]]
      : (s.type === 'Assign' && s.targets.length === 1 && s.values.length === 1 && s.targets[0].type === 'Name') ? [s.targets[0], s.values[0]] : null;
    if (holder) {
      const t = stripParens(holder[1]);
      if (t.type === 'Table' && t.fields.length === 1 && t.fields[0].kind === 'item' && isOuter(t.fields[0].value)) {
        const next = body[i + 1];
        if (next && next.type === 'Return' && next.values.length === 1) {
          const r = stripParens(next.values[0]);
          if (r.type === 'Call' && r.args.length === 1 && stripParens(r.args[0]).type === 'Name' && info.varOf.get(stripParens(r.args[0])) === info.varOf.get(holder[0])) return { index: i, count: 2 };
        }
      }
    }
  }
  return null;
}

/** `nil`, or a local that was declared without a value and never assigned. */
const isNil = (e, info) => {
  e = stripParens(e);
  if (!e) return false;
  if (e.type === 'Nil') return true;
  const v = e.type === 'Name' ? info.varOf.get(e) : null;
  return !!(v && !v.isGlobal && !v.hasInit && v.writes.length === 0 && v.init && v.init.type === 'Nil');
};

/** Every value assigned to each variable in `scope`, from declarations and assignments with one value per name. */
function assignedValues(scope, info) {
  const map = new Map();
  const put = (v, e) => { if (!v || e === undefined) return; if (!map.has(v)) map.set(v, []); map.get(v).push(e); };
  walk(scope, (n) => {
    if (n.type === 'Local') n.ids.forEach((id, i) => put(info.varOf.get(id), n.values.length === n.ids.length ? n.values[i] : (i < n.values.length - 1 ? n.values[i] : undefined)));
    else if (n.type === 'Assign' && n.targets.length === n.values.length) n.targets.forEach((t, i) => { if (t.type === 'Name') put(info.varOf.get(t), n.values[i]); });
    else if (n.type === 'Assign') n.targets.forEach((t) => { if (t.type === 'Name') put(info.varOf.get(t), null); });
  });
  return map;
}

/** The one value a variable ever holds (declared with it, or assigned once), or null. */
const singleValue = (v, info, assigned) => {
  if (!v || v.isGlobal) return null;
  if (v.hasInit && v.writes.length === 0 && v.init) return v.init;
  if (!v.hasInit) {
    const list = assigned && assigned.get(v);
    if (list && list.length === 1 && list[0] && v.writes.length === 1) return list[0];
  }
  return null;
};

const constNumber = (e, info, assigned) => {
  e = stripParens(e);
  if (!e) return null;
  if (e.type === 'Number') return e.value;
  if (e.type === 'Name') {
    const v = canonical(info.varOf.get(e), info);
    const init = singleValue(v, info, assigned);
    if (init && stripParens(init).type === 'Number') return stripParens(init).value;
  }
  return null;
};

/** Why the last candidate was turned down, for the report of a script that was not recognised. */
export let lastReason = '';
const no = (why) => { lastReason = why; return null; };

export function locateLoose(chunk, info) {
  lastReason = 'no function of four parameters runs a dispatcher loop';
  const parents = enclosingFunctions(chunk);
  for (const [f, outer] of parents) {
    if (f.params.length !== 4) continue;
    const d = dispatcherOf(f, info);
    if (!d) continue;
    const found = describe(chunk, info, f, outer, d);
    if (found) return found;
  }
  return null;
}

function describe(chunk, info, f, outer, d) {
  if (!outer) return no('the dispatcher is not inside a function');
  const declared = declaredIn(f, info);
  let nested = false;
  walk(f.body, (n) => { if (n.type === 'Func') nested = true; return !nested; });
  if (nested) return no('the dispatcher function contains functions');
  const [, argsP, upvalsP, proxyP] = f.params;
  const argsVar = info.varOf.get(argsP);
  const upvalsVar = info.varOf.get(upvalsP);
  const proxyVar = info.varOf.get(proxyP);

  // variables of the VM's own machinery: declared in the function that wraps the dispatcher, not inside it. What lives outside
  // that function (the string table a decryptor keeps) is the program's business and is left alone.
  const machinery = declaredIn(outer, info);
  const assigned = assignedValues(outer, info);
  // inside the dispatcher, a copy of a machinery variable (`local e = env`) stands for the variable itself
  walk(f.body, (n) => {
    if (n.type !== 'Name') return;
    const v = info.varOf.get(n);
    if (v && !v.isGlobal && !declared.has(v) && machinery.has(v)) { const c = canonical(v, info); if (c !== v) info.varOf.set(n, c); }
  });
  const canon = (v) => (v ? canonical(v, info) : v);
  const free = (n) => {
    const v = varOf(info, n);
    if (!v || v.isGlobal) return null;
    const c = canon(v);
    return !declared.has(c) && machinery.has(c) ? c : null;
  };

  // the container ends by returning the register that holds the results
  const last = f.body[f.body.length - 1];
  if (!last || last.type !== 'Return' || last.values.length !== 1) return no('the dispatcher function does not end in a return of the results');
  let retVar = null;
  let unpackVar = null;
  walk(last.values[0], (n) => {
    if (n.type === 'Call' && n.args.length === 1) {
      const a = stripParens(n.args[0]);
      const v = a.type === 'Name' ? info.varOf.get(a) : null;
      if (v && declared.has(v) && !v.isGlobal) { retVar = v; unpackVar = free(stripParens(n.fn)); }
    }
  });
  if (!retVar || !unpackVar) return no('cannot tell which register holds the results');

  const isTable = (e) => {
    e = stripParens(e);
    if (e.type === 'Table') return true;
    if (e.type === 'Name') { const init = singleValue(canonical(info.varOf.get(e), info), info, assigned); return !!(init && stripParens(init).type === 'Table'); }
    return false;
  };
  const creators = new Set();
  let alloc = null;
  let freeFn = null;
  let selectVar = null;
  const indexed = new Set();
  const isRegisterVar = (v) => v && declared.has(v) && v !== argsVar && v !== upvalsVar && v !== proxyVar;
  walk(f.body, (n) => {
    if (n.type === 'Call') {
      const fv = free(stripParens(n.fn));
      if (fv && fv !== unpackVar) {
        if (n.args.length === 2 && constNumber(n.args[0], info, assigned) !== null && isTable(n.args[1])) creators.add(fv);
        else if (n.args.length === 0) alloc = alloc || fv;
        else if (n.args.length === 2 && stripParens(n.args[0]).type === 'Number' && stripParens(n.args[1]).type === 'Call') selectVar = fv;
        else if (n.args.length === 1 && stripParens(n.args[0]).type === 'Name' && isRegisterVar(info.varOf.get(stripParens(n.args[0])))) freeFn = freeFn || fv;
      }
    } else if (n.type === 'Index') {
      const o = stripParens(n.obj);
      const fv = o.type === 'Name' ? free(o) : null;
      if (fv) indexed.add(fv);
    }
    return undefined;
  });

  // the tables behind alloc and free: alloc counts, free clears the count and the cell
  let counts = null;
  let cells = null;
  if (alloc && freeFn) {
    const scope = outer;
    for (const fn of funcsAssigned(alloc, scope, info)) {
      if (fn.params.length !== 0) continue;
      walk(fn.body, (n) => {
        if (n.type === 'Assign') n.targets.forEach((t, i) => { if (t.type === 'Index' && stripParens(n.values[i]).type === 'Number' && stripParens(n.values[i]).value === 1) counts = canonical(varOf(info, stripParens(t.obj)), info); });
      });
    }
    const cleared = new Set();
    for (const fn of funcsAssigned(freeFn, scope, info)) {
      if (fn.params.length !== 1) continue;
      walk(fn.body, (n) => {
        if (n.type === 'Assign') n.targets.forEach((t, i) => { if (t.type === 'Index' && isNil(n.values[i], info)) cleared.add(canonical(varOf(info, stripParens(t.obj)), info)); });
      });
    }
    for (const c of cleared) if (c && c !== counts) cells = c;
  }
  const envCandidates = [...indexed].filter((v) => v !== counts && v !== cells);
  if (envCandidates.length !== 1) return no(`${envCandidates.length} candidates for the environment table`);

  // the entry block: the one call of a creator made outside the container, `create(blockId, {})`
  let startId = null;
  walk(outer.body, (n) => {
    if (n === f) return false;
    if (n.type === 'Call' && n.args.length === 2 && isTable(n.args[1])) {
      const fv = canonical(varOf(info, stripParens(n.fn)), info);
      if (fv && machinery.has(fv)) { const id = constNumber(n.args[0], info, assigned); if (id !== null) startId = id; }
    }
    return undefined;
  });
  if (startId === null) return no('no entry block id outside the dispatcher');

  const site = callSite(chunk, outer, info);
  if (!site) return no('cannot find where the script is started');

  // registers: everything the container declared except its own parameters
  const regs = new Set([...declared].filter((v) => isRegisterVar(v)));
  regs.add(d.posVar);

  return {
    loose: true,
    container: f, outer, loop: d.loop, tree: d.tree,
    posVar: d.posVar, argsVar, upvalsVar, proxyVar, retVar,
    roles: { env: envCandidates[0], unpack: unpackVar, select: selectVar },
    creators, alloc, free: freeFn, cells, counts,
    startId, regs,
    insideOuter: machinery,
    splice: (target, body) => target.body.splice(site.index, site.count, ...body),
  };
}
