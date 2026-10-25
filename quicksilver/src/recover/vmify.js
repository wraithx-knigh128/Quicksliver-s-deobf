// Prometheus "Vmify": taking the flattened virtual machine apart again.
//
// Vmify compiles a whole script into blocks of ordinary Lua statements and runs them through one dispatcher:
//
//     local regs...                                 -- every register of every function is one of these locals
//     while pos do
//       if pos < 7419915 then ... elseif ... end    -- a binary search over random block ids
//     end
//
// Each block ends by writing the next block id into `pos` (a constant, `c and A or B`, or a read of a missing global to
// stop). Functions are blocks too: a closure is `create(blockId, {upvalue cells})`. Upvalues are numbered cells in a shared
// table, written with `cells[id] = v` and counted so the VM can emulate collection.
//
// None of that is secret once the generator is known (it is open source, MIT-licensed obfuscator output carries no
// licence), so the inverse is mechanical:
//
//   1. find the dispatcher, the helper functions and the entry block                               locate()
//   2. evaluate the search tree for every block id that is jumped to, which gives its statements   blockOf()
//   3. read the next-block expression symbolically: constant, branch, or return                   analyseBlock()
//   4. give each register's independent live ranges names of their own                            webs()
//   5. turn cells into captured locals, `args[i]` into parameters, `env[k]` into globals          translate()
//   6. structure the block graph (src/decompile/cfg.js)                                            structure()
//
// Every step either understands the shape it is looking at or throws VmifyError; nothing is guessed. The caller keeps the
// original tree when it throws.

import { analyze } from '../core/scope.js';
import { walk, clone } from '../core/walk.js';
import { structure as structureCfg, CfgError } from '../decompile/cfg.js';
import { placeDeclarations } from './decls.js';
import { VmifyError, fail, stripParens, isName, num, nameNode, varOf } from './vmify-util.js';
import { locateLoose, declaredIn, lastReason } from './vmify-locate.js';

export { VmifyError };

// ---- 1. locate -----------------------------------------------------------------------------------------------------

/**
 * Find the pieces of a Vmify script. Returns null if the chunk is not one.
 */
export function locate(chunk, info = analyze(chunk)) {
  // the script ends with `return (function(...) <machinery> end)(...)`; what comes before it (the string decryptor EncryptStrings
  // puts in front of a Vmify script) is not part of it
  const last = chunk.body[chunk.body.length - 1];
  if (!last || last.type !== 'Return' || last.values.length !== 1) return null;
  const call = stripParens(last.values[0]);
  if (!call || call.type !== 'Call') return null;
  const outer = stripParens(call.fn);
  if (!outer || outer.type !== 'Func') return null;
  const body = outer.body;
  if (body.length !== 2 || body[0].type !== 'Assign' || body[1].type !== 'Return') return null;

  const assign = body[0];
  if (assign.targets.length !== assign.values.length) return null;
  const defs = new Map();             // Var -> value expression of the preamble assignment
  assign.targets.forEach((t, i) => { const v = varOf(info, t); if (v) defs.set(v, assign.values[i]); });

  // the final `create(startId, {...})(unpack(args))`
  const ret = stripParens(body[1].values[0]);
  if (!ret || ret.type !== 'Call') return null;
  const first = stripParens(ret.fn);
  if (!first || first.type !== 'Call' || first.args.length !== 2 || first.args[0].type !== 'Number' || first.args[1].type !== 'Table') return null;
  const createVararg = varOf(info, first.fn);
  if (!createVararg) return null;
  const startId = first.args[0].value;
  const upvalueEntries = first.args[1].fields.map((f) => f.value);

  // roles of the leading parameters, from the arguments they receive
  const roles = {};
  outer.params.forEach((p, i) => {
    const a = call.args[i];
    const v = info.varOf.get(p);
    if (!a || !v) return;
    const e = stripParens(a);
    if (e.type === 'Name' && ['newproxy', 'setmetatable', 'getmetatable', 'select'].includes(e.name)) roles[e.name] = v;
    else if (e.type === 'Table' && e.fields.length === 1 && stripParens(e.fields[0].value).type === 'Vararg') roles.argTable = v;
    else if (e.type === 'Binary' && e.op === 'or') {
      const l = stripParens(e.left);
      const r = stripParens(e.right);
      if (l.type === 'Binary' && l.op === 'and') roles.env = v;
      else if (l.type === 'Name' && l.name === 'unpack' && r.type === 'Index') roles.unpack = v;
    }
  });
  if (!roles.env || !roles.unpack) return null;

  // classify the helper functions
  const out = { outer, chunkCall: call, prefix: chunk.body.slice(0, -1), defs, createVararg, startId, upvalueEntries, roles, creators: new Set([createVararg]) };
  for (const [v, value] of defs) {
    const f = stripParens(value);
    if (!f || f.type !== 'Func') continue;
    if (isContainer(f, info)) { out.container = f; out.containerVar = v; continue; }
    const kind = helperKind(f, info);
    if (kind === 'creator') out.creators.add(v);
    else if (kind === 'alloc') { out.alloc = v; out.counts = allocCounts(f, info); }
    else if (kind === 'free') { out.free = v; Object.assign(out, freeTables(f, info)); }
  }
  if (!out.container || !out.alloc || !out.free) return null;
  return out;
}

function isContainer(f, info) {
  if (f.params.length !== 4) return false;
  const loop = f.body.find((s) => s.type === 'While');
  if (!loop) return false;
  const c = stripParens(loop.cond);
  return c.type === 'Name' && info.varOf.get(c) === info.varOf.get(f.params[0]);
}

/** creator: `function(pos, upvals) local proxy = ... local f = function(...) return container(pos, {...}, upvals, proxy) end return f end` */
function helperKind(f, info) {
  const b = f.body;
  if (f.params.length === 2 && b.length === 3 && b[0].type === 'Local' && b[1].type === 'Local' && b[2].type === 'Return') {
    const inner = b[1].values[0];
    if (inner && inner.type === 'Func' && inner.body.length === 1 && inner.body[0].type === 'Return') {
      const c = inner.body[0].values[0];
      if (c && c.type === 'Call' && c.args.length === 4 && c.args[1].type === 'Table') return 'creator';
    }
  }
  if (f.params.length === 0 && b.length === 3 && b[0].type === 'Assign' && b[1].type === 'Assign' && b[2].type === 'Return') {
    const t = b[1].targets[0];
    if (t && t.type === 'Index' && b[1].values[0].type === 'Number' && b[1].values[0].value === 1) return 'alloc';
  }
  if (f.params.length === 1 && b.length === 2 && b[0].type === 'Assign' && b[1].type === 'If') return 'free';
  return null;
}

function allocCounts(f, info) {
  const t = f.body[1].targets[0];
  return varOf(info, t.obj);
}

function freeTables(f, info) {
  const inner = f.body[1].clauses[0].body[0];
  if (!inner || inner.type !== 'Assign' || inner.targets.length !== 2) return {};
  return { counts: varOf(info, inner.targets[0].obj), cells: varOf(info, inner.targets[1].obj) };
}

// ---- 2. the dispatcher --------------------------------------------------------------------------------------------

/** Evaluate `pos OP number` for a concrete pos, or undefined if the condition is not that shape. */
function testPos(cond, posVar, id, info) {
  const c = stripParens(cond);
  if (!c || c.type !== 'Binary') return undefined;
  const l = stripParens(c.left);
  const r = stripParens(c.right);
  let a;
  let b;
  if (isName(l, posVar, info) && r.type === 'Number') { a = id; b = r.value; }
  else if (isName(r, posVar, info) && l.type === 'Number') { a = l.value; b = id; }
  else return undefined;
  switch (c.op) {
    case '<': return a < b;
    case '>': return a > b;
    case '<=': return a <= b;
    case '>=': return a >= b;
    case '==': return a === b;
    case '~=': return a !== b;
    default: return undefined;
  }
}

/**
 * The leaf (statement list) the dispatcher runs when pos == id.
 *
 * The search tree is `if pos < N then ... else ... end` nested down to one block per leaf. When it has been through a
 * register machine the conditions arrive as temporaries (`local t = pos < N` and then `if t`), possibly computed twice or not
 * used at all; those belong to the tree, not to the leaf, and are evaluated here as they are met.
 */
function blockOf(tree, posVar, id, info) {
  let body = tree;
  const temps = new Map();
  const evalCond = (cond) => {
    const c = stripParens(cond);
    if (!c) return undefined;
    if (c.type === 'Name') { const v = info.varOf.get(c); return v && temps.has(v) ? temps.get(v) : undefined; }
    if (c.type === 'Unary' && c.op === 'not') { const r = evalCond(c.arg); return r === undefined ? undefined : !r; }
    return testPos(c, posVar, id, info);
  };
  for (let guard = 0; guard < 64; guard++) {
    let i = 0;
    let chosen = null;
    for (; i < body.length; i++) {
      const s = body[i];
      const single = (s.type === 'Local' && s.ids.length === 1 && s.values.length === 1) ? [s.ids[0], s.values[0]]
        : (s.type === 'Assign' && s.targets.length === 1 && s.values.length === 1 && s.targets[0].type === 'Name') ? [s.targets[0], s.values[0]] : null;
      if (single) {
        const r = evalCond(single[1]);
        if (r !== undefined) { const v = info.varOf.get(single[0]); if (v) temps.set(v, r); continue; }
      }
      if (s.type === 'If') {
        if (evalCond(s.clauses[0].cond) === undefined) break;          // an `if` of the leaf's own
        for (const c of s.clauses) {
          const t = evalCond(c.cond);
          if (t === undefined) fail('a dispatcher condition that is not a comparison of the position');
          if (t) { chosen = c.body; break; }
        }
        if (!chosen) chosen = s.orelse;
        if (!chosen) fail(`block ${id} falls off the dispatcher`);
      }
      break;
    }
    if (chosen === null) return body.slice(i);
    body = chosen;
  }
  return fail('dispatcher tree too deep');
}

// ---- 3. one block --------------------------------------------------------------------------------------------------

/**
 * Symbolic values of the position register. A block ends by computing the next block id, and the compiler only ever
 * writes it with a few shapes (a number, `c and A or B`, `c and A` then `pos or B`, or a read of a global that does not
 * exist). Evaluating those over these forms recovers the successor(s) without running anything.
 *
 *   { k: 'num', v }             a block id (or any truthy number)
 *   { k: 'nil' }                nil / false: the dispatcher stops
 *   { k: 'exit' }               the deliberate read of a missing global that ends the function
 *   { k: 'unk', expr }          a value computed at run time
 *   { k: 'cond', c, t, f }      `t` when the snapshot c is truthy, else `f`
 *   { k: 'falsy', c }           whatever falsy value snapshot c had
 */
class Block {
  constructor(id) { this.id = id; this.stmts = []; this.term = null; }
}

const successorsOf = (term) => (term.kind === 'goto' ? [term.to] : term.kind === 'branch' ? [term.t, term.f] : []);


/** Does the expression contain a number, nil or false: something a jump can be made of? */
function hasJumpConstant(e) {
  let found = false;
  walk(e, (n) => { if (n.type === 'Number' || n.type === 'Nil' || n.type === 'False') found = true; return !found; });
  return found;
}

/**
 * A block that came out of another register machine declares its temporaries with `local`. They are registers like the rest,
 * so a declaration becomes the assignment of its initial values (nil for a bare `local x`).
 */
function normalise(s, ctx) {
  if (s.type === 'Assign' || s.type === 'CallStmt') return [s];
  if (s.type === 'If' && isGuard(s)) return [s];
  if (s.type === 'Local') {
    const targets = s.ids.map((id) => { const n = nameNode(id.name); const v = ctx.info.varOf.get(id); if (v) ctx.info.varOf.set(n, v); return n; });
    const values = s.values.length ? s.values : targets.map(() => ({ type: 'Nil' }));
    return [{ type: 'Assign', targets, values }];
  }
  return fail(`a block contains a ${s.type}`);
}

/**
 * A register machine that reads one of the VM's tables copies it into a register first (`local t = cells; t[k]`). Within a
 * block those copies are followed to the table itself and dropped, so the translation only ever sees the tables by name. A
 * copy that is still used in some other block is reported when it is met there.
 */
function dealias(stmts, ctx) {
  const { info } = ctx;
  const alias = new Map();                                       // register Var -> machinery Var
  const lit = new Map();                                         // register Var -> { expr, deps }: a block id or an upvalue list it holds
  const out = [];
  const rewrite = (node) => {
    walk(node, (n) => {
      if (n.type === 'Name') {
        const v = info.varOf.get(n);
        const a = v && alias.get(v);
        if (a) { info.varOf.set(n, a); n.name = a.name; }
        return undefined;
      }
      // `create(id, upvalues)` with the arguments held in registers: put them back
      if (n.type === 'Call' && n.args.length === 2) {
        const f = stripParens(n.fn);
        if (f.type === 'Name' && ctx.creators.has(alias.get(info.varOf.get(f)) || info.varOf.get(f))) {
          n.args = n.args.map((x) => { const a = stripParens(x); const v = a.type === 'Name' ? info.varOf.get(a) : null; return v && lit.has(v) ? copyLiteral(lit.get(v).expr) : x; });
        }
      }
      return undefined;
    });
  };
  const copyLiteral = (e) => {
    if (e.type === 'Number') return { ...e };
    return { type: 'Table', fields: e.fields.map((f) => { const inner = stripParens(f.value); const n = { type: 'Name', name: inner.name }; info.varOf.set(n, info.varOf.get(inner)); return { kind: 'item', value: n }; }) };
  };
  const assigned = (v) => {
    alias.delete(v);
    lit.delete(v);
    for (const [k, e] of lit) if (e.deps.includes(v)) lit.delete(k);
  };
  const isFree = (e) => {
    const c = stripParens(e);
    if (!c || c.type !== 'Call' || c.args.length !== 1) return false;
    const f = stripParens(c.fn);
    const v = f.type === 'Name' ? info.varOf.get(f) : null;
    return !!v && (v === ctx.free || alias.get(v) === ctx.free);
  };
  for (let s of stmts) {
    if (s.type === 'CallStmt') { rewrite(s.call); out.push(s); continue; }
    // `a, R = f(a), free(R)`: releasing a cell is a statement of its own, so take it out of the parallel assignment
    if (s.targets.length > 1 && s.targets.length === s.values.length && s.values.some(isFree)) {
      const keep = s.values.map((v, i) => i).filter((i) => !isFree(s.values[i]));
      if (!keep.length) continue;
      s = { ...s, targets: keep.map((i) => s.targets[i]), values: keep.map((i) => s.values[i]) };
    }
    s.values.forEach(rewrite);
    s.targets.forEach((t) => { if (t.type !== 'Name') rewrite(t); });
    if (s.targets.length === 1 && s.values.length === 1 && s.targets[0].type === 'Name') {
      const t = info.varOf.get(s.targets[0]);
      const val = stripParens(s.values[0]);
      const rv = val.type === 'Name' ? info.varOf.get(val) : null;
      if (t && ctx.isRegister(t) && rv && ctx.roleVars.has(rv)) { alias.set(t, rv); ctx.droppedAliases.add(t); continue; }
    }
    for (const t of s.targets) if (t.type === 'Name') assigned(info.varOf.get(t));
    if (s.targets.length === 1 && s.values.length === 1 && s.targets[0].type === 'Name') {
      const t = info.varOf.get(s.targets[0]);
      const val = stripParens(s.values[0]);
      if (t && val.type === 'Number') lit.set(t, { expr: val, deps: [] });
      else if (t && val.type === 'Table' && val.fields.every((x) => x.kind === 'item' && stripParens(x.value).type === 'Name')) {
        lit.set(t, { expr: val, deps: val.fields.map((x) => info.varOf.get(stripParens(x.value))).filter(Boolean) });
      }
    }
    out.push(s);
  }
  return out;
}

/** `if c then v = e end`: the shape a register machine gives `v = c and e` (or, with `not c`, `v = c or e`). */
function isGuard(s) {
  if (s.clauses.length !== 1 || s.orelse || s.clauses[0].body.length !== 1) return false;
  const body = s.clauses[0].body[0];
  if (body.type !== 'Assign' || body.targets.length !== 1 || body.values.length !== 1 || body.targets[0].type !== 'Name') return false;
  const c = stripParens(s.clauses[0].cond);
  const name = c.type === 'Unary' && c.op === 'not' ? stripParens(c.arg) : c;
  return name.type === 'Name';
}

/**
 * Put such a guard back into an expression when the variable it assigns was set from the variable it tests, with neither
 * touched in between: `v = c ... if c then v = e end` becomes `v = c and e` at the place of the `if`.
 */
function foldGuards(stmts, ctx) {
  const { info } = ctx;
  const writes = (st, v) => st.type === 'Assign' && st.targets.some((t) => t.type === 'Name' && info.varOf.get(t) === v);
  const out = [];
  for (const st of stmts) {
    if (st.type !== 'If') { out.push(st); continue; }
    const cond = stripParens(st.clauses[0].cond);
    const negated = cond.type === 'Unary' && cond.op === 'not';
    const cName = negated ? stripParens(cond.arg) : cond;
    const c = info.varOf.get(cName);
    const body = st.clauses[0].body[0];
    const v = info.varOf.get(body.targets[0]);
    let at = -1;
    for (let i = out.length - 1; i >= 0 && at < 0; i--) {
      const p = out[i];
      if (p.type === 'Assign' && p.targets.length === 1 && p.values.length === 1 && p.targets[0].type === 'Name' && info.varOf.get(p.targets[0]) === v
        && stripParens(p.values[0]).type === 'Name' && info.varOf.get(stripParens(p.values[0])) === c) { at = i; break; }
      if (writes(p, v) || writes(p, c)) break;
    }
    if (at < 0 || !c || !v) return fail('a conditional inside a block that is not a short-circuit');
    out.push({ type: 'Assign', targets: [body.targets[0]], values: [{ type: 'Binary', op: negated ? 'or' : 'and', left: cName, right: body.values[0] }] });
  }
  return out;
}

function analyseBlock(id, leaf, ctx) {
  const { info, posVar, retVar } = ctx;
  const blk = new Block(id);
  const stmts = dealias(foldGuards(leaf.flatMap((s) => normalise(s, ctx)).flatMap((s) => (s.type === 'Assign' ? splitAssign(s.targets, s.values, true) : [s])), ctx), ctx);
  const readsPos = (e) => { let hit = false; walk(e, (n) => { if (n.type === 'Name' && info.varOf.get(n) === posVar) hit = true; return !hit; }); return hit; };

  // every assignment to the position register: [statement index, pair index]
  const writes = [];
  stmts.forEach((s, i) => {
    if (s.type !== 'Assign') return;
    s.targets.forEach((t, k) => { if (t.type === 'Name' && info.varOf.get(t) === posVar) writes.push([i, k]); });
  });
  if (!writes.length) fail(`block ${id} never sets the position`);

  // the chain that computes the jump: the last write, plus earlier writes while the later one reads the position
  let c = writes.length - 1;
  while (c > 0) {
    const [i, k] = writes[c];
    if (!readsPos(stmts[i].values[k])) break;
    c--;
  }
  const chain = new Set();
  for (let q = c; q < writes.length; q++) chain.add(`${writes[q][0]}:${writes[q][1]}`);

  const out = [];                 // statements of the block, rewritten
  const consts = new Map();       // Var -> number, registers that hold a known number right now
  const defs = new Map();         // Var -> { expr, stamp }: the expression it was last set to in this block
  const version = new Map();      // Var -> how many times it has been written in this block
  const resolving = new Set();
  const readCount = new Map();    // Var -> how many times the block reads it
  {
    const count = (node) => walk(node, (n) => { if (n.type === 'Name') { const w = info.varOf.get(n); if (w) readCount.set(w, (readCount.get(w) || 0) + 1); } });
    for (const st of stmts) {
      if (st.type === 'CallStmt') count(st.call);
      else { st.values.forEach(count); st.targets.forEach((t) => { if (t.type !== 'Name') count(t); }); }
    }
  }
  let posForm = { k: 'unk', expr: null };

  const evalForm = (e, pre) => {
    e = stripParens(e);
    switch (e.type) {
      case 'Number': return { k: 'num', v: e.value };
      case 'Nil': case 'False': return { k: 'nil' };
      case 'Name': {
        const v = info.varOf.get(e);
        if (v === posVar) return posForm;
        if (v && consts.has(v)) return { k: 'num', v: consts.get(v) };
        // a register set earlier in the block to something that settles the jump on its own (a block id, nil, the missing global)
        if (v && defs.has(v) && !resolving.has(v)) {
          const d = defs.get(v);
          // only while nothing the definition read has been overwritten since
          if ([...d.stamp].every(([w, n]) => (version.get(w) || 0) === n)) {
            resolving.add(v);
            const extra = [];
            const f = evalForm(d.expr, extra);
            resolving.delete(v);
            // only a settled jump, or a single two-way test, stands for the register; anything bigger is a value it computes
            const simple = f.k === 'num' || f.k === 'nil' || f.k === 'exit'
              || (f.k === 'cond' && f.t.k === 'num' && (f.f.k === 'num' || f.f.k === 'falsy'));
            if (simple) { pre.push(...extra); return f; }
          }
        }
        return { k: 'unk', expr: e };
      }
      case 'Index': {
        let o = stripParens(e.obj);
        for (let hop = 0; hop < 4 && o.type === 'Name' && defs.has(info.varOf.get(o)) && stripParens(defs.get(info.varOf.get(o)).expr).type === 'Name'; hop++) o = stripParens(defs.get(info.varOf.get(o)).expr);
        if (o.type === 'Name' && info.varOf.get(o) === ctx.roles.env) {
          // the read of a global that does not exist. Read through a register, it has to be that register's only use: a
          // global that is also passed on or tested (`getfenv and getfenv()`) is an ordinary lookup
          const via = [...resolving].pop();
          if (via === undefined || (readCount.get(via) || 0) <= 1) return { k: 'exit' };
        }
        return { k: 'unk', expr: e };
        return { k: 'unk', expr: e };
      }
      case 'Binary': {
        // an operand with no block id or nil in it is a condition to be tested as a whole, however it is built
        const part = (x) => (stripParens(x).type === 'Name' || hasJumpConstant(x) ? evalForm(x, pre) : { k: 'unk', expr: x });
        if (e.op === 'and') return andForm(part(e.left), part(e.right), pre);
        if (e.op === 'or') return orForm(part(e.left), part(e.right));
        return { k: 'unk', expr: e };
      }
      default: return { k: 'unk', expr: e };
    }
  };
  const andForm = (a, b, pre) => {
    switch (a.k) {
      case 'num': return b;
      case 'nil': case 'falsy': case 'exit': return a;
      case 'unk': {
        const v = ctx.syntheticVar(`cond${id}_${ctx.nextSynthetic++}`);
        pre.push({ v, expr: a.expr });
        return { k: 'cond', c: v, t: b, f: { k: 'falsy', c: v } };
      }
      case 'cond': return { k: 'cond', c: a.c, t: andForm(a.t, b, pre), f: andForm(a.f, b, pre) };
      default: return fail('unexpected form in an and');
    }
  };
  const orForm = (a, b) => {
    switch (a.k) {
      case 'num': return a;
      case 'nil': case 'falsy': case 'exit': return b;
      case 'cond': return { k: 'cond', c: a.c, t: orForm(a.t, b), f: orForm(a.f, b) };
      case 'unk': return { k: 'unk', expr: null };
      default: return fail('unexpected form in an or');
    }
  };
  const jumpLike = (f) => f.k === 'num' || f.k === 'exit' || f.k === 'nil' || f.k === 'cond';

  for (let i = 0; i < stmts.length; i++) {
    const s = stmts[i];
    if (s.type !== 'Assign') {
      if (s.type !== 'CallStmt') fail(`block ${id}: unexpected ${s.type}`);
      out.push(s);
      continue;
    }
    const keep = [];
    const keepVals = [];
    const pre = [];
    const effects = [];
    s.targets.forEach((t, k) => {
      const value = s.values[k];
      const isPos = t.type === 'Name' && info.varOf.get(t) === posVar;
      if (isPos && chain.has(`${i}:${k}`)) {
        const f = evalForm(value, pre);
        posForm = f;
        if (jumpLike(f)) { consts.delete(posVar); return; }          // part of the jump: dropped
      } else if (isPos) posForm = { k: 'unk', expr: null };
      keep.push(t);
      if (value !== undefined) keepVals.push(value);
      if (t.type === 'Name') {
        const tv = info.varOf.get(t);
        const vv = value && value.type === 'Number' ? value.value
          : (value && value.type === 'Name' && consts.has(info.varOf.get(value)) ? consts.get(info.varOf.get(value)) : undefined);
        effects.push([tv, vv]);
      }
    });
    // the value a jump condition tests is captured just before the statement that tests it
    for (const p of pre) out.push({ type: 'Assign', targets: [ctx.nameOf(p.v)], values: [p.expr] });
    if (s.values.length > s.targets.length) keepVals.push(...s.values.slice(s.targets.length));
    if (keep.length) out.push(keep.length === s.targets.length && keepVals.length === s.values.length ? s : { type: 'Assign', targets: keep, values: keepVals });
    for (const [tv, vv] of effects) { if (tv) { if (vv === undefined) consts.delete(tv); else consts.set(tv, vv); } }
    s.targets.forEach((t, k) => {
      if (t.type !== 'Name') return;
      const tv = info.varOf.get(t);
      if (!tv) return;
      version.set(tv, (version.get(tv) || 0) + 1);
      if (tv === posVar) return;
      if (s.values[k] !== undefined && s.targets.length === s.values.length) {
        const stamp = new Map();
        walk(s.values[k], (n) => { if (n.type === 'Name') { const w = info.varOf.get(n); if (w) stamp.set(w, version.get(w) || 0); } });
        defs.set(tv, { expr: s.values[k], stamp });
      } else defs.delete(tv);
    });
  }

  // how the block ends
  const f = posForm;
  if (f.k === 'num') blk.term = { kind: 'goto', to: f.v };
  else if (f.k === 'cond') {
    if (f.t.k === 'num' && f.f.k === 'num') blk.term = { kind: 'branch', cond: ctx.nameOf(f.c), t: f.t.v, f: f.f.v };
    else fail(`block ${id}: a branch whose arm is not a block`);
  } else if (f.k === 'exit' || f.k === 'nil') {
    // `ret = { values }` right before the exit is the function's return statement
    let values = null;
    for (let q = out.length - 1; q >= 0; q--) {
      const st = out[q];
      if (st.type !== 'Assign') continue;
      const at = st.targets.findIndex((t) => t.type === 'Name' && info.varOf.get(t) === retVar);
      if (at < 0) continue;
      let val = st.values[at];
      // `ret = t` where t is a table built earlier in the block, from values that have not changed since
      const named = val && stripParens(val).type === 'Name' ? defs.get(info.varOf.get(stripParens(val))) : null;
      if (named && stripParens(named.expr).type === 'Table' && [...named.stamp].every(([w, n]) => (version.get(w) || 0) === n)) val = stripParens(named.expr);
      if (val && val.type === 'Table' && val.fields.every((x) => x.kind === 'item')) {
        values = val.fields.map((x) => x.value);
        if (st.targets.length === 1) out.splice(q, 1);
        else out[q] = { type: 'Assign', targets: st.targets.filter((_, j) => j !== at), values: st.values.filter((_, j) => j !== at) };
      }
      break;
    }
    blk.term = { kind: 'return', values };
  } else fail(`block ${id}: cannot tell where it jumps`);
  blk.stmts = out.flatMap((st) => (st.type === 'Assign' ? splitAssign(st.targets, st.values, true) : [st]));
  return blk;
}


function collectBlocks(entryId, ctx) {
  const blocks = new Map();
  const stack = [entryId];
  while (stack.length) {
    const id = stack.pop();
    if (blocks.has(id)) continue;
    let b = ctx.blockCache.get(id);
    if (!b) {
      b = analyseBlock(id, blockOf(ctx.treeBody, ctx.posVar, id, ctx.info), ctx);
      ctx.blockCache.set(id, b);
    }
    blocks.set(id, b);
    for (const s of successorsOf(b.term)) stack.push(s);
  }
  return blocks;
}

function reachableFrom(blocks, start) {
  const seen = new Set();
  const stack = [start];
  while (stack.length) {
    const id = stack.pop();
    if (seen.has(id) || !blocks.has(id)) continue;
    seen.add(id);
    for (const n of successorsOf(blocks.get(id).term)) stack.push(n);
  }
  return seen;
}

/** The creator calls in a block's statements: [{ id, call, stmt }] */
function creatorCalls(stmts, ctx) {
  const found = [];
  for (const st of stmts) {
    walk(st, (n) => {
      if (n.type === 'Call' && n.args.length === 2 && n.args[0].type === 'Number' && n.args[1].type === 'Table') {
        const f = stripParens(n.fn);
        if (f.type === 'Name' && ctx.creators.has(ctx.info.varOf.get(f))) found.push({ id: n.args[0].value, call: n, stmt: st });
      }
    });
  }
  return found;
}

/** Ids of the functions the script defines whose own text carries `text`. */
function functionsWithString(ctx, text) {
  const result = new Set();
  const ids = new Set();
  for (const b of ctx.blockCache.values()) void b;
  walk(ctx.treeBody, (n) => {
    if (n.type === 'Call' && n.args.length === 2 && n.args[0].type === 'Number') {
      const f = stripParens(n.fn);
      if (f.type === 'Name' && ctx.creators.has(ctx.info.varOf.get(f))) ids.add(n.args[0].value);
    }
  });
  for (const id of ids) {
    let blocks;
    try { blocks = collectBlocks(id, ctx); } catch (e) { if (e instanceof VmifyError) continue; throw e; }
    // the closure that raises the error is a couple of blocks; a function with the text somewhere in a large body is a script that carries one
    if (blocks.size > 6) continue;
    let hit = false;
    for (const b of blocks.values()) for (const st of b.stmts) walk(st, (n) => { if (n.type === 'String' && n.value === text) hit = true; return !hit; });
    if (hit) result.add(id);
  }
  return result;
}

/**
 * The AntiTamper step puts `do ... repeat until valid end` first in the script. It compares line numbers of error messages,
 * so it fails on any copy that was reformatted, and it has nothing to do with what the script computes. Vmify compiles it
 * into the same blocks as the program, with the statements of both shuffled together where the check ends.
 *
 * The check's way of failing is calling the closure that raises "Tamper Detected!". The branch in front of that call is the
 * gate; the program starts at its other arm. What of the gate's side still hangs around (releasing the check's cells,
 * the hook installed afterwards) reads registers only the check has written, which the data-flow of the blocks after the
 * gate shows: those statements, and whatever depends on them, go.
 */
function dropAntiTamper(blocks, entry, ctx) {
  if (!ctx.hasTamperMarker) return entry;
  const tamperFns = functionsWithString(ctx, 'Tamper Detected!');
  if (!tamperFns.size) return entry;
  const webs = computeWebs(blocks, entry, { ...ctx, fid: 0 });

  // the cell the failure closure is kept in
  let holder = null;
  for (const b of blocks.values()) {
    const made = new Map();                  // register Var -> creator id of the value it holds
    for (const st of b.stmts) {
      if (st.type !== 'Assign') continue;
      st.targets.forEach((t, k) => {
        const val = st.values[k] && stripParens(st.values[k]);
        if (t.type === 'Name') {
          const v = ctx.info.varOf.get(t);
          const c = val && val.type === 'Call' && val.args.length === 2 && val.args[0].type === 'Number' && isCreator(val.fn, ctx) ? val.args[0].value : null;
          if (c !== null) made.set(v, c); else made.delete(v);
        } else if (t.type === 'Index' && isName(stripParens(t.obj), ctx.cellsVar, ctx.info) && stripParens(t.key).type === 'Name' && val && val.type === 'Name') {
          const c = made.get(ctx.info.varOf.get(val));
          if (c !== undefined && tamperFns.has(c) && holder === null) holder = webs.rootOf(stripParens(t.key));
        }
      });
    }
  }
  if (holder === null) return entry;

  // the block that calls a closure over that cell and ends the function
  let handler = null;
  for (const [id, b] of blocks) {
    if (b.term.kind !== 'return') continue;
    for (const c of creatorCalls(b.stmts, ctx)) {
      const items = c.call.args[1].fields.map((f) => stripParens(f.value));
      if (items.some((x) => x.type === 'Name' && webs.rootOf(x) === holder)) handler = id;
    }
    if (handler !== null) break;
  }
  if (handler === null) return entry;

  const preds = new Map([...blocks.keys()].map((k) => [k, []]));
  for (const [id, b] of blocks) for (const n of successorsOf(b.term)) preds.get(n).push(id);
  let at = handler;
  let gate = null;
  while (gate === null) {
    const ps = preds.get(at);
    if (ps.length !== 1) return entry;
    const p = blocks.get(ps[0]);
    if (p.term.kind === 'branch') { gate = ps[0]; break; }
    if (p.stmts.length) return entry;
    at = ps[0];
  }
  const g = blocks.get(gate).term;
  const start = g.t === at ? g.f : g.t;

  // keep only what the program side reaches, and take out what only the check can have written
  const keep = reachableFrom(blocks, start);
  if (keep.has(handler)) return entry;
  const kept = new Map();
  // the function's own set-up (binding the arguments to registers) is the first thing its entry block does; it belongs to
  // the program whatever order the compiler shuffled the entry block's statements into
  const reads = (st, v) => { let hit = false; walk(st, (n) => { if (n.type === 'Name' && ctx.info.varOf.get(n) === v) hit = true; return !hit; }); return hit; };
  const prologue = blocks.get(entry).stmts.filter((st) => st.type === 'Assign' && (reads(st, ctx.argsVar) || reads(st, ctx.upvalsVar)));
  let from = start;
  if (prologue.length) {
    const head = new Block('prologue');
    head.stmts = prologue;
    head.term = { kind: 'goto', to: start };
    kept.set('prologue', head);
    from = 'prologue';
  }
  for (const id of keep) kept.set(id, blocks.get(id));
  const w = computeWebs(kept, from, { ...ctx, fid: 0 });

  const tainted = new Set();                   // web roots
  const dead = new Set();                      // statements
  for (const [id, b] of kept) for (const st of b.stmts) {
    const { uses } = w.stmtOps.get(st);
    if (uses.some((u) => w.entryOnly(u.node))) { dead.add(st); for (const d of w.stmtOps.get(st).defs) tainted.add(w.rootOf(d.node)); }
  }
  for (let again = true; again;) {
    again = false;
    for (const [id, b] of kept) for (const st of b.stmts) {
      if (dead.has(st)) continue;
      const { uses, defs } = w.stmtOps.get(st);
      if (uses.some((u) => tainted.has(w.rootOf(u.node)))) {
        dead.add(st);
        for (const d of defs) tainted.add(w.rootOf(d.node));
        again = true;
      }
    }
  }
  const result = new Map();
  for (const [id, b] of kept) {
    const nb = new Block(id);
    nb.stmts = b.stmts.filter((st) => !dead.has(st));
    nb.term = b.term;
    const t = b.term;
    const reads = w.termOps.get(id) || [];
    if (t.kind === 'branch' && reads.some((u) => w.entryOnly(u.node) || tainted.has(w.rootOf(u.node)))) {
      // the check's own loop (`repeat until valid`): the way on is the arm that does not come back
      if (t.t === id) nb.term = { kind: 'goto', to: t.f };
      else if (t.f === id) nb.term = { kind: 'goto', to: t.t };
      else throw new VmifyError('the anti-tamper check has a branch this tool cannot settle');
    } else if (reads.some((u) => w.entryOnly(u.node) || tainted.has(w.rootOf(u.node)))) {
      throw new VmifyError(`the program reads a value only the anti-tamper check sets (block ${id}: ${reads.filter((u) => w.entryOnly(u.node) || tainted.has(w.rootOf(u.node))).map((u) => u.node.name).join(',')})`);
    }
    result.set(id, nb);
  }
  blocks.clear();
  for (const [id, b] of result) blocks.set(id, b);
  ctx.droppedAntiTamper = true;
  return from;
}

function isCreator(fn, ctx) {
  const f = stripParens(fn);
  return f.type === 'Name' && ctx.creators.has(ctx.info.varOf.get(f));
}

// ---- 4. register webs ----------------------------------------------------------------------------------------------

/**
 * The compiler hands registers out one after another and reuses them, so one register is several unrelated variables over
 * the life of a function. Splitting a register into its webs (the definitions that can reach a common use) gives each of
 * them a name of its own, which is also what makes the later clean-up passes effective.
 */
function computeWebs(blocks, entry, ctx) {
  const { info } = ctx;
  const isReg = (n) => { const v = n.type === 'Name' ? info.varOf.get(n) : null; return v && ctx.isRegister(v) ? v : null; };

  // operations of each block in execution order
  const ops = new Map();
  const stmtOps = new Map();       // statement -> { uses, defs }
  const termOps = new Map();       // block id -> uses of its branch condition / returned values
  const cellDefs = new Map();      // def Name node -> { kind: 'alloc' } | { kind: 'upval', k }
  const copies = [];               // register-to-register copies: { def, src }
  let defCount = 0;
  const defIdOf = new Map();       // def Name node -> id
  const regOfDef = [];
  const collectUses = (e, list) => walk(e, (n) => { const v = isReg(n); if (v) list.push({ use: true, node: n, reg: v }); });
  for (const [id, b] of blocks) {
    const list = [];
    for (const s of b.stmts) {
      const uses = [];
      const defs = [];
      if (s.type === 'CallStmt') collectUses(s.call, uses);
      else {
        s.values.forEach((e) => collectUses(e, uses));
        s.targets.forEach((t, k) => {
          if (t.type === 'Name') {
            const v = isReg(t);
            if (v) {
              defs.push({ use: false, node: t, reg: v });
              if (s.targets.length === s.values.length) {
                const val = stripParens(s.values[k]);
                if (val.type === 'Call' && isName(stripParens(val.fn), ctx.alloc, info)) cellDefs.set(t, { kind: 'alloc' });
                else if (val.type === 'Index' && isName(stripParens(val.obj), ctx.upvalsVar, info) && val.key.type === 'Number') cellDefs.set(t, { kind: 'upval', k: val.key.value });
                else if (val.type === 'Name' && isReg(val)) copies.push({ def: t, src: val });
              }
            }
          } else if (t.type === 'Index') { collectUses(t.obj, uses); if (!(t.key.type === 'String' && t.dot)) collectUses(t.key, uses); }
        });
      }
      stmtOps.set(s, { uses, defs });
      list.push(...uses, ...defs);
    }
    // the end of the block reads the branch condition or the returned values
    const before = list.length;
    if (b.term.kind === 'branch') collectUses(b.term.cond, list);
    else if (b.term.kind === 'return' && b.term.values) b.term.values.forEach((e) => collectUses(e, list));
    termOps.set(id, list.slice(before));
    for (const o of list) if (!o.use) { o.def = defCount; defIdOf.set(o.node, defCount); regOfDef.push(o.reg); defCount++; }
    ops.set(id, list);
  }
  // one extra definition per register stands for "not assigned yet"
  const entryDef = new Map();
  const firstEntryDef = defCount;
  for (const v of ctx.registerList()) { entryDef.set(v, defCount); regOfDef.push(v); defCount++; }

  const parent = Array.from({ length: defCount }, (_, i) => i);
  const find = (x) => { while (parent[x] !== x) { parent[x] = parent[parent[x]]; x = parent[x]; } return x; };
  const union = (a, b) => { a = find(a); b = find(b); if (a !== b) parent[b] = a; };

  // reaching definitions over the block graph
  const preds = new Map([...blocks.keys()].map((k) => [k, []]));
  for (const [id, b] of blocks) for (const s of successorsOf(b.term)) preds.get(s).push(id);
  const inSets = new Map();
  const outSets = new Map();
  const transfer = (id, input) => {
    const cur = new Map(input);
    for (const o of ops.get(id)) if (!o.use) cur.set(o.reg, new Set([o.def]));
    return cur;
  };
  const initial = new Map([...entryDef].map(([v, d]) => [v, new Set([d])]));
  const order = [...blocks.keys()];
  for (const id of order) { inSets.set(id, new Map()); outSets.set(id, new Map()); }
  for (let changed = true; changed;) {
    changed = false;
    for (const id of order) {
      const merged = id === entry ? new Map(initial) : new Map();
      for (const p of preds.get(id)) for (const [reg, set] of outSets.get(p)) {
        const into = merged.get(reg) || new Set();
        for (const d of set) into.add(d);
        merged.set(reg, into);
      }
      inSets.set(id, merged);
      const out = transfer(id, merged);
      const prev = outSets.get(id);
      let same = prev.size === out.size;
      if (same) for (const [reg, set] of out) { const q = prev.get(reg); if (!q || q.size !== set.size || [...set].some((d) => !q.has(d))) { same = false; break; } }
      if (!same) { outSets.set(id, out); changed = true; }
    }
  }

  // link every use to the definitions that reach it
  const useDef = new Map();
  const entryOnlyUses = new Set();
  for (const id of order) {
    const cur = new Map(inSets.get(id));
    for (const o of ops.get(id)) {
      if (o.use) {
        const set = cur.get(o.reg);
        if (set && set.size) {
          const first = [...set][0];
          for (const d of set) union(first, d);
          useDef.set(o.node, first);
          if ([...set].every((d) => d >= firstEntryDef)) entryOnlyUses.add(o.node);
        } else { useDef.set(o.node, entryDef.get(o.reg)); entryOnlyUses.add(o.node); }
      } else cur.set(o.reg, new Set([o.def]));
    }
  }

  // A register that holds a cell (a captured variable, or one of the enclosing function's) and the registers it is copied to
  // are the same variable, so they share a web. Cell-ness spreads along the copies until nothing changes.
  const cellRootsNow = () => new Set([...cellDefs.keys()].map((n) => find(defIdOf.get(n))));
  for (let changed = true; changed;) {
    changed = false;
    const roots = cellRootsNow();
    for (const { def, src } of copies) {
      const from = useDef.get(src);
      if (from === undefined) continue;
      if (roots.has(find(from)) && find(defIdOf.get(def)) !== find(from)) { union(from, defIdOf.get(def)); changed = true; }
    }
  }
  const rootInfo = new Map();                                      // root -> { alloc, upvals: Set }
  for (const [n, d] of cellDefs) {
    const root = find(defIdOf.get(n));
    if (!rootInfo.has(root)) rootInfo.set(root, { alloc: false, upvals: new Set() });
    const r = rootInfo.get(root);
    if (d.kind === 'alloc') r.alloc = true; else r.upvals.add(d.k);
  }

  const names = new Map();
  const counter = { n: 0 };
  const nameOfRoot = (root) => {
    if (!names.has(root)) names.set(root, `_r${ctx.fid}_${++counter.n}`);
    return names.get(root);
  };
  const webId = new Map();
  for (const [node, d] of defIdOf) webId.set(node, d);
  for (const [node, d] of useDef) webId.set(node, d);
  const rootOf = (node) => { const d = webId.get(node); return d === undefined ? undefined : find(d); };
  const cellOf = (node) => { const root = rootOf(node); return root === undefined ? null : rootInfo.get(root) || null; };
  return {
    stmtOps, termOps,
    rootOf: (node) => { const r = rootOf(node); return r === undefined ? null : r; },
    entryOnly: (node) => entryOnlyUses.has(node),
    webName: (node) => { const root = rootOf(node); return root === undefined ? null : nameOfRoot(root); },
    isCell: (node) => cellOf(node) !== null,
    /** The index of the enclosing function's upvalue this register holds, or null if it is a variable of its own. */
    upvalIndex: (node) => {
      const c = cellOf(node);
      if (!c) return null;
      if (c.alloc) return c.upvals.size ? fail('a cell register that is both a local variable and an upvalue') : null;
      if (c.upvals.size !== 1) return fail('a cell register that holds different upvalues');
      return [...c.upvals][0];
    },
    usedNames: () => [...names.entries()].filter(([root]) => !rootInfo.has(root)).map(([, n]) => n),
  };
}


/**
 * `a, b = x, y` is two statements unless one of them reads a variable an earlier one writes (or calls out, in which case
 * the order of the writes is observable, unless the targets are registers, which no callee can see). The compiler packs unrelated copies into one statement to save a token; undoing
 * that is what lets the clean-up passes see single definitions.
 */
function splitAssign(targets, values, registersOnly = false) {
  if (targets.length < 2 || targets.length !== values.length || !targets.every((t) => t.type === 'Name')) return [{ type: 'Assign', targets, values }];
  const written = new Set();
  for (let i = 0; i < values.length; i++) {
    let bad = false;
    walk(values[i], (n) => { if (n.type === 'Name' && written.has(n.name)) bad = true; if (!registersOnly && (n.type === 'Call' || n.type === 'Func')) bad = bad || written.size > 0; return !bad; });
    if (bad) return [{ type: 'Assign', targets, values }];
    written.add(targets[i].name);
  }
  return targets.map((t, i) => ({ type: 'Assign', targets: [t], values: [values[i]] }));
}

// ---- 5. translation ---------------------------------------------------------------------------------------------------

const KEEP_NAMES = new Set(['select', 'unpack']);

function recoverFunction(entryIdIn, upvalNames, ctx) {
  let entryId = entryIdIn;
  const { info } = ctx;
  ctx.count++;
  const fid = `${ctx.layer}_${ctx.count}`;

  // 1. the blocks of this function
  const blocks = collectBlocks(entryId, ctx);

  // Prometheus AntiTamper compiled into the VM: everything up to its `repeat until valid` is the check, not the program
  if (entryId === ctx.startId) entryId = dropAntiTamper(blocks, entryId, ctx);

  // 2. webs
  const webs = computeWebs(blocks, entryId, { ...ctx, fid });
  const fn = { maxArg: 0, vararg: false, fixed: 0, whole: false };

  const cellVar = (node) => {
    const k = webs.upvalIndex(node);
    if (k !== null) {
      const up = upvalNames[k - 1];
      if (!up) fail('an upvalue the closure was not given');
      return up;
    }
    const n = webs.webName(node);
    if (!n) fail('a cell register without a web');
    return n;
  };

  // 3. expressions
  const txCellKey = (key) => {
    const k = stripParens(key);
    if (k.type === 'Name' && ctx.isRegister(info.varOf.get(k)) && webs.isCell(k)) return nameNode(cellVar(k));
    if (k.type === 'Index' && stripParens(k.obj).type === 'Name' && isName(stripParens(k.obj), ctx.upvalsVar, info) && k.key.type === 'Number') {
      const n = upvalNames[k.key.value - 1];
      if (!n) fail('an upvalue the closure was not given');
      return nameNode(n);
    }
    return fail('a cell access this tool does not understand');
  };
  const entryOf = (e) => {
    e = stripParens(e);
    if (e.type === 'Name' && ctx.isRegister(info.varOf.get(e)) && webs.isCell(e)) return cellVar(e);
    if (e.type === 'Index' && isName(stripParens(e.obj), ctx.upvalsVar, info) && e.key.type === 'Number') {
      const n = upvalNames[e.key.value - 1];
      if (!n) fail('an upvalue the closure was not given');
      return n;
    }
    return fail(`a closure upvalue that is not a variable of the enclosing function (${e.name || e.type})`);
  };

  const tx = (e) => {
    switch (e.type) {
      case 'Name': {
        const v = info.varOf.get(e);
        if (v && ctx.isRegister(v)) {
          // read before anything was assigned on any path to it: nil
          if (webs.entryOnly(e)) return { type: 'Nil' };
          const n = webs.webName(e);
          if (!n) fail(`register ${e.name} has no web`);
          return nameNode(n);
        }
        if (v === ctx.roles.env) return nameNode('__env');
        if (v === ctx.roles.unpack) return nameNode('unpack');
        if (v === ctx.roles.select) return nameNode('select');
        if (v === ctx.argsVar) return fail('the argument table is used as a value');
        if (v && ctx.droppedAliases.has(v)) return fail('a copy of one of the VM tables is used in a block other than the one that made it');
        // a variable of the script around the VM (the string table a decryptor keeps) is still in scope where the program runs
        if (v && !v.isGlobal && !ctx.insideOuter.has(v)) return nameNode(e.name);
        if (v && v.isGlobal) return nameNode(e.name);
        return fail(`a name this tool does not understand: ${e.name}`);
      }
      case 'Index': {
        const o = stripParens(e.obj);
        if (o.type === 'Name') {
          const v = info.varOf.get(o);
          if (v === ctx.cellsVar) return txCellKey(e.key);
          if (v === ctx.argsVar && e.key.type === 'Number') { fn.maxArg = Math.max(fn.maxArg, e.key.value); return nameNode(`_a${fid}_${e.key.value}`); }
        }
        const copy = { type: 'Index', obj: tx(e.obj), key: e.key.type === 'String' && e.dot ? e.key : tx(e.key), dot: e.dot };
        return copy;
      }
      case 'Call': {
        const f = stripParens(e.fn);
        if (f.type === 'Name') {
          const v = info.varOf.get(f);
          if (ctx.creators.has(v)) return makeClosure(e);
          if (v === ctx.alloc || v === ctx.free) return fail(`a cell function used inside an expression`);
          // `unpack(args)` hands on everything the function was called with
          if (v === ctx.roles.unpack && e.args.length === 1 && isName(stripParens(e.args[0]), ctx.argsVar, info)) { fn.vararg = true; fn.whole = true; return { type: 'Vararg' }; }
        }
        return { type: 'Call', fn: tx(e.fn), args: e.args.map(tx), sugar: e.sugar };
      }
      case 'Table': {
        // `{ select(n, unpack(args)) }` is the vararg list of a function that takes n - 1 fixed arguments
        if (e.fields.length === 1 && e.fields[0].kind === 'item') {
          const c = stripParens(e.fields[0].value);
          if (c.type === 'Call' && c.args.length === 2 && isName(stripParens(c.fn), ctx.roles.select, info) && c.args[0].type === 'Number') {
            const u = stripParens(c.args[1]);
            if (u.type === 'Call' && isName(stripParens(u.fn), ctx.roles.unpack, info) && u.args.length === 1 && isName(stripParens(u.args[0]), ctx.argsVar, info)) {
              fn.vararg = true;
              fn.fixed = c.args[0].value - 1;
              return { type: 'Table', fields: [{ kind: 'item', value: { type: 'Vararg' } }] };
            }
          }
        }
        return { type: 'Table', fields: e.fields.map((f) => (f.kind === 'keyed' ? { kind: 'keyed', key: tx(f.key), value: tx(f.value) } : f.kind === 'named' ? { kind: 'named', key: f.key, value: tx(f.value) } : { kind: 'item', value: tx(f.value) })) };
      }
      case 'Binary': return { type: 'Binary', op: e.op, left: tx(e.left), right: tx(e.right) };
      case 'Unary': return { type: 'Unary', op: e.op, arg: tx(e.arg) };
      case 'Paren': return { type: 'Paren', expr: tx(e.expr) };
      case 'Number': case 'String': case 'Nil': case 'True': case 'False': return clone(e);
      default: return fail(`an expression this tool does not understand: ${e.type}`);
    }
  };

  const makeClosure = (call) => {
    if (call.args.length !== 2 || call.args[0].type !== 'Number' || call.args[1].type !== 'Table') fail(`a closure creation with an unexpected shape`);
    const names = call.args[1].fields.map((f) => entryOf(f.value));
    return recoverFunction(call.args[0].value, names, ctx);
  };

  // 4. statements
  const out = new Map();
  for (const [id, b] of blocks) {
    const list = [];
    for (const s of b.stmts) {
      if (s.type === 'CallStmt') {
        // `free(cell)` on its own: the variable simply goes out of scope
        const c = stripParens(s.call);
        if (c.type === 'Call' && isName(stripParens(c.fn), ctx.free, info)) continue;
        list.push({ type: 'CallStmt', call: tx(s.call) });
        continue;
      }
      // `R = alloc()` declares a captured variable; `R = free(R)` ends its scope
      if (s.targets.length === 1 && s.values.length === 1 && s.targets[0].type === 'Name') {
        const v = stripParens(s.values[0]);
        // `R = upvals[k]` and `R2 = R` only move a cell around: R is the variable itself
        if (webs.isCell(s.targets[0]) && ((v.type === 'Index' && isName(stripParens(v.obj), ctx.upvalsVar, info) && v.key.type === 'Number') || (v.type === 'Name' && ctx.isRegister(info.varOf.get(v)) && webs.isCell(v)))) continue;
        if (v.type === 'Call' && isName(stripParens(v.fn), ctx.alloc, info)) {
          if (!webs.isCell(s.targets[0])) fail('an upvalue allocation that is not a cell');
          list.push({ type: 'Local', ids: [{ type: 'Id', name: cellVar(s.targets[0]) }], values: [] });
          continue;
        }
        if (v.type === 'Call' && isName(stripParens(v.fn), ctx.free, info)) continue;
      }
      const targets = [];
      const values = [];
      let cellStore = false;
      s.targets.forEach((t) => {
        if (t.type === 'Index' && isName(stripParens(t.obj), ctx.cellsVar, info)) { targets.push(txCellKey(t.key)); cellStore = true; }
        else if (t.type === 'Name') {
          const v = info.varOf.get(t);
          if (!(v && ctx.isRegister(v))) fail('an assignment to something that is not a register');
          targets.push(nameNode(webs.webName(t)));
        } else if (t.type === 'Index') targets.push({ type: 'Index', obj: tx(t.obj), key: t.key.type === 'String' && t.dot ? t.key : tx(t.key), dot: t.dot });
        else fail('an assignment target this tool does not understand');
      });
      void cellStore;
      // `reg = args` in the main chunk is the vararg list
      s.values.forEach((e) => {
        const x = stripParens(e);
        if (x.type === 'Name' && x.name !== undefined && isName(x, ctx.argsVar, info)) { fn.vararg = true; values.push({ type: 'Table', fields: [{ kind: 'item', value: { type: 'Vararg' } }] }); }
        else values.push(tx(e));
      });
      for (const piece of splitAssign(targets, values)) list.push({ ...piece, computed: true });
    }
    const t = b.term;
    let term;
    if (t.kind === 'goto') term = { kind: 'goto', to: t.to };
    else if (t.kind === 'branch') term = { kind: 'branch', cond: tx(t.cond), t: t.t, f: t.f };
    else term = { kind: 'return', values: t.values && t.values.length ? t.values.map(tx) : null };
    out.set(id, { stmts: list, term });
  }

  // 5. structure
  let body;
  try {
    body = structureCfg(out, entryId, {
      negate: (c) => (c.type === 'Unary' && c.op === 'not' ? c.arg : { type: 'Unary', op: 'not', arg: c.type === 'Binary' ? { type: 'Paren', expr: c } : c }),
      makeReturn: (values) => ({ type: 'Return', values: values || [] }),
    });
  } catch (e) {
    if (e instanceof CfgError) fail(`function at block ${entryId}: ${e.message}`);
    throw e;
  }
  const last = body[body.length - 1];
  if (last && last.type === 'Return' && !last.values.length) body.pop();

  if (fn.whole && fn.maxArg > 0) fail('a function that reads its arguments both singly and as a whole');
  const declared = webs.usedNames();
  const params = [];
  for (let i = 1; i <= Math.max(fn.maxArg, fn.fixed); i++) params.push({ type: 'Id', name: `_a${fid}_${i}` });
  placeDeclarations(body, declared);
  return { type: 'Func', params, vararg: fn.vararg, body, isMethod: false, generics: null, returnType: null };
}

// ---- 6. the whole script ----------------------------------------------------------------------------------------------

/**
 * Replace a Vmify script by the program it runs. Returns { changed, functions, blocks }; throws VmifyError when the
 * script is not one or something about it is not understood (the caller keeps the original then).
 */
/** What the exact locator found, in the same terms the loose one reports. */
function describeExact(L, info) {
  const f = L.container;
  const loop = f.body.find((s) => s.type === 'While');
  const declaration = f.body.find((s) => s.type === 'Local' && s.values.length === 0);
  const tables = f.body.filter((s) => s.type === 'Local' && s.values.length === 1 && s.ids.length === 1 && s.values[0].type === 'Table' && !s.values[0].fields.length);
  if (!declaration || f.body.some((s) => s.type === 'Local' && s.values.length && !tables.includes(s))) fail('the register declarations have an unexpected shape');
  const regs = new Set(declaration.ids.map((id) => info.varOf.get(id)));
  const posVar = info.varOf.get(f.params[0]);
  regs.add(posVar);
  const lastStmt = f.body[f.body.length - 1];
  if (lastStmt.type !== 'Return' || lastStmt.values.length !== 1) fail('the container does not end the way Vmify containers do');
  const retCall = stripParens(lastStmt.values[0]);
  const retVar = retCall.type === 'Call' ? varOf(info, stripParens(retCall.args[0])) : null;
  if (!retVar) fail('cannot find the return register');
  regs.add(retVar);
  return {
    ...L, loose: false, loop, tree: loop.body, posVar, retVar, regs,
    argsVar: info.varOf.get(f.params[1]), upvalsVar: info.varOf.get(f.params[2]), proxyVar: info.varOf.get(f.params[3]),
    insideOuter: declaredIn(L.outer, info),
    splice: (target, body) => target.body.splice(target.body.length - 1, 1, ...body),
  };
}

/** `a, b = x, y` as separate statements wherever that cannot change what runs, so every variable has visible definitions. */
function splitMultiAssign(chunk) {
  const visit = (stmts) => {
    for (let i = 0; i < stmts.length; i++) {
      const st = stmts[i];
      if (st.type === 'Assign' && st.targets.length > 1) {
        const parts = splitAssign(st.targets, st.values);
        if (parts.length > 1) { stmts.splice(i, 1, ...parts); i += parts.length - 1; }
      }
      const blocks = st.type === 'If' ? [...st.clauses.map((c) => c.body), ...(st.orelse ? [st.orelse] : [])]
        : st.type === 'While' || st.type === 'Repeat' || st.type === 'NumFor' || st.type === 'GenFor' || st.type === 'Do' ? [st.body] : [];
      for (const b of blocks) visit(b);
      walk(st, (n) => { if (n !== st && n.type === 'Func') { visit(n.body); return false; } return undefined; });
    }
  };
  visit(chunk.body);
}

export function unflattenVmify(original, options = {}) {
  // everything below works on a copy: the registers held in the overflow table are rewritten in place, and a script that
  // turns out not to be understood has to come back untouched
  const chunk = clone(original);
  splitMultiAssign(chunk);
  const info = analyze(chunk);
  const exact = locate(chunk, info);
  const L = exact ? describeExact(exact, info) : locateLoose(chunk, info);
  if (!L) return { changed: 0, skipped: lastReason ? `not a Vmify script (${lastReason})` : 'not a Vmify script' };
  const f = L.container;
  const regs = new Set(L.regs);

  // past 99 registers the compiler keeps the rest in one table: `local T = {}` ahead of the declarations
  const tables = f.body.filter((s) => s.type === 'Local' && s.values.length === 1 && s.ids.length === 1 && s.values[0].type === 'Table' && !s.values[0].fields.length);
  if (tables.length > 1) fail('more than one register table');
  if (tables.length) {
    const overflow = info.varOf.get(tables[0].ids[0]);
    regs.delete(overflow);
    const slots = new Map();
    walk(L.tree, (n) => {
      if (n.type === 'Index' && n.obj.type === 'Name' && info.varOf.get(n.obj) === overflow && n.key.type === 'Number') {
        let v = slots.get(n.key.value);
        if (!v) { v = { name: `slot${n.key.value}`, isGlobal: false, synthetic: true, reads: [], writes: [] }; slots.set(n.key.value, v); regs.add(v); }
        const name = v.name;
        for (const k of Object.keys(n)) delete n[k];
        n.type = 'Name';
        n.name = name;
        info.varOf.set(n, v);
        return false;
      }
      return undefined;
    });
  }

  const ctx = {
    info, roles: L.roles, posVar: L.posVar, retVar: L.retVar,
    argsVar: L.argsVar, upvalsVar: L.upvalsVar, proxyVar: L.proxyVar,
    cellsVar: L.cells, alloc: L.alloc, free: L.free, creators: L.creators,
    treeBody: L.tree,
    insideOuter: L.insideOuter,
    hasTamperMarker: containsString(L.tree, 'Tamper Detected!'),
    blockCache: new Map(),
    droppedAliases: new Set(),
    roleVars: new Set([L.roles.env, L.roles.unpack, L.roles.select, L.upvalsVar, L.proxyVar, L.cells, L.alloc, L.free, ...L.creators].filter(Boolean)),
    startId: L.startId,
    layer: options.layer || 1, count: 0, nextSynthetic: 0,
    isRegister: (v) => regs.has(v),
    registerList: () => [...regs],
    syntheticVar(name) { const v = { name: `${name}`, isGlobal: false, synthetic: true, reads: [], writes: [] }; regs.add(v); return v; },
    nameOf(v) { const n = nameNode(v.name); info.varOf.set(n, v); return n; },
  };
  const main = recoverFunction(L.startId, [], ctx);
  // the script is the body of its main function; its vararg is the script's own, and so are the arguments it reads
  const body = main.body;
  if (main.params.length) body.unshift({ type: 'Local', ids: main.params, values: [{ type: 'Vararg' }] });
  L.splice(original, body);
  return { changed: ctx.count, functions: ctx.count };
}

function containsString(node, text) {
  let found = false;
  walk(node, (n) => { if (n.type === 'String' && n.value === text) found = true; return !found; });
  return found;
}

const RESERVED = new Set(['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while', 'continue']);

/**
 * The environment is a parameter of the VM, so every global access of the original reads `__env["name"]`. Writing them
 * as plain globals again is the inverse; whatever cannot be (a computed key) keeps the environment, which is then
 * declared once at the top.
 */
export function envToGlobals(chunk, declare = false) {
  let left = false;
  let changed = 0;
  walk(chunk, (n) => {
    if (n.type === 'Index' && n.obj.type === 'Name' && n.obj.name === '__env' && n.key.type === 'String' && /^[A-Za-z_][A-Za-z0-9_]*$/.test(n.key.value) && !RESERVED.has(n.key.value)) {
      const name = n.key.value;
      for (const k of Object.keys(n)) delete n[k];
      n.type = 'Name';
      n.name = name;
      changed++;
    } else if (n.type === 'Name' && n.name === '__env') left = true;
  });
  if (left && declare) chunk.body.unshift({ type: 'Local', ids: [{ type: 'Id', name: '__env' }], values: [{ type: 'Binary', op: 'or', left: { type: 'Binary', op: 'and', left: nameNode('getfenv'), right: { type: 'Call', fn: nameNode('getfenv'), args: [], sugar: false } }, right: nameNode('_ENV') }] });
  return { changed: changed + (left && declare ? 1 : 0) };
}

export { CfgError, num, blockOf, analyseBlock };
