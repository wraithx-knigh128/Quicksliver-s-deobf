// Recovery modules for Prometheus (https://github.com/prometheus-lua/Prometheus, by levno-710).
//
// Every pattern handled here was read from the Prometheus source and checked against real output
// (tests/corpus/obfuscated/prometheus). Nothing is guessed from the look of the code.

import { transform, walk } from '../core/walk.js';
import { analyze } from '../core/scope.js';
import { constOf, makeConst } from '../passes/fold.js';
import { NOT_CONST } from '../passes/consteval.js';

// ---- AntiTamper ------------------------------------------------------------------------------------------
//
// steps/AntiTamper.lua prepends `do local X = "<random>" for i = 0, N do ... end ... end`. It raises
// "Tamper Detected!" when error-message line numbers disagree, i.e. when the source is reformatted.

function isAntiTamperBlock(stmt) {
  if (stmt.type !== 'Do' || stmt.body.length < 3) return false;
  const first = stmt.body[0];
  if (first.type !== 'Local' || first.values.length !== 1 || first.values[0].type !== 'String') return false;
  if (!stmt.body.slice(1, 3).some((s) => s.type === 'NumFor')) return false;
  let marker = false;
  walk(stmt, (n) => { if (n.type === 'String' && n.value === 'Tamper Detected!') marker = true; });
  return marker;
}

export function removeAntiTamper(chunk) {
  let removed = 0;
  transform(chunk, {
    block(stmts) {
      if (!stmts.some(isAntiTamperBlock)) return undefined;
      const out = stmts.filter((s) => !isAntiTamperBlock(s));
      removed += stmts.length - out.length;
      return out;
    },
  });
  return { changed: removed };
}

// ---- ProxifyLocals ------------------------------------------------------------------------------------
//
// steps/ProxifyLocals.lua turns each local into a table with a metatable:
//
//   local P = setmetatable({ K = init }, { <opA> = function(r, q) r.K = q end,
//                                          <opB> = function(r, q) return r.K end })
//
// A read of the local is `P <opB> literal`, an assignment is `P <opA> value`, and since an operator
// expression is not a statement it is passed to a dummy function: `(D <opB'> literal)(P <opA> value)`.

const OP_OF_META = {
  __add: '+', __sub: '-', __mul: '*', __div: '/', __mod: '%', __pow: '^', __concat: '..', __index: 'index',
};

const isGlobalCall = (call, name, info) => {
  if (call.fn.type !== 'Name' || call.fn.name !== name) return false;
  const v = info.varOf.get(call.fn);
  return v && v.isGlobal && v.writes.length === 0;
};

/** Is `f` `function(r, q) r.K = q end` (a setter) or `function(r, q) return r.K end` (a getter)? */
function proxyAccessor(f, key) {
  if (f.type !== 'Func' || f.params.length !== 2 || f.body.length !== 1) return null;
  const [r, q] = f.params.map((p) => p.name);
  const s = f.body[0];
  const isField = (e) => e.type === 'Index' && e.obj.type === 'Name' && e.obj.name === r && e.key.type === 'String' && e.key.value === key;
  if (s.type === 'Assign' && s.targets.length === 1 && s.values.length === 1 && isField(s.targets[0]) && s.values[0].type === 'Name' && s.values[0].name === q) return 'set';
  if (s.type === 'Return' && s.values.length === 1) {
    const v = s.values[0];
    if (isField(v)) return 'get';
    if (v.type === 'Call' && v.fn.type === 'Name' && v.fn.name === 'rawget' && v.args.length === 2
      && v.args[0].type === 'Name' && v.args[0].name === r && v.args[1].type === 'String' && v.args[1].value === key) return 'get';
  }
  return null;
}

export function undoProxifyLocals(chunk) {
  const info = analyze(chunk);
  const proxies = new Map(); // Var -> { key, get, set, declStmt, init }

  walk(chunk, (n) => {
    if (n.type !== 'Local' || n.ids.length !== 1 || n.values.length !== 1) return;
    const call = n.values[0];
    if (call.type !== 'Call' || call.args.length !== 2) return;
    // `setmetatable` may have been aliased to a local (local L = setmetatable); look through one alias.
    let isSet = isGlobalCall(call, 'setmetatable', info);
    if (!isSet && call.fn.type === 'Name') {
      const fv = info.varOf.get(call.fn);
      isSet = !!(fv && fv.init && fv.writes.length === 0 && fv.init.type === 'Name' && fv.init.name === 'setmetatable');
    }
    if (!isSet) return;
    const [data, meta] = call.args;
    if (data.type !== 'Table' || data.fields.length !== 1 || data.fields[0].kind !== 'named') return;
    if (meta.type !== 'Table' || meta.fields.length !== 2 || !meta.fields.every((f) => f.kind === 'named' && OP_OF_META[f.key])) return;
    const key = data.fields[0].key;
    const roles = meta.fields.map((f) => ({ meta: f.key, role: proxyAccessor(f.value, key) }));
    const set = roles.find((r) => r.role === 'set');
    const get = roles.find((r) => r.role === 'get');
    if (!set || !get) return;
    proxies.set(info.varOf.get(n.ids[0]), { key, get: OP_OF_META[get.meta], set: OP_OF_META[set.meta], declStmt: n, init: data.fields[0].value });
  });
  if (!proxies.size) return { changed: 0 };

  // A read `P <get> literal` becomes the bare name `P`. That name stands for the proxy's *value*, not the proxy,
  // so it must never be matched as a proxy again: `t[k] = v` after the rewrite of `(t .. "x")[k] = v` is an
  // ordinary index assignment, while `P[v]` in the original is the proxy's setter.
  const synthetic = new WeakSet();
  const proxyOf = (e) => (e.type === 'Name' && !synthetic.has(e) ? proxies.get(info.varOf.get(e)) : undefined);
  const readOf = (name) => { const n = { type: 'Name', name: name.name }; synthetic.add(n); info.varOf.set(n, info.varOf.get(name)); return n; };
  let reads = 0;
  let writes = 0;

  transform(chunk, {
    expr(e) {
      if (e.type === 'Binary') {
        const p = proxyOf(e.left);
        if (p && p.get === e.op) { reads++; return readOf(e.left); }
        if (p && p.set === e.op) return { type: '__Set', target: e.left, value: e.right };
      }
      if (e.type === 'Index') {
        const p = proxyOf(e.obj);
        // `function Shape.new() end` is emitted as `function proxy.<K>.new() end`: a direct read of the stored value
        if (p && e.key.type === 'String' && e.key.value === p.key) { reads++; return readOf(e.obj); }
        if (p && p.get === 'index') { reads++; return readOf(e.obj); }
        if (p && p.set === 'index') return { type: '__Set', target: e.obj, value: e.key };
      }
      return undefined;
    },
    stmt(s) {
      // (D <get> literal)(P <set> value) -> P = value
      if (s.type === 'CallStmt' && s.call.type === 'Call' && s.call.args.length === 1 && s.call.args[0].type === '__Set') {
        const set = s.call.args[0];
        writes++;
        return { type: 'Assign', targets: [{ type: 'Name', name: set.target.name }], values: [set.value], comments: s.comments, trailing: s.trailing, line: s.line, blankBefore: s.blankBefore };
      }
      if (s.type === 'Local' && s.ids.length === 1) {
        const p = proxies.get(info.varOf.get(s.ids[0]));
        if (p && p.declStmt === s) return { ...s, values: [p.init] };
      }
      return undefined;
    },
  });
  // Reads of the dummy callee must be plain names again; anything still wrapped in __Set is not a pattern we know.
  let leftover = 0;
  walk(chunk, (n) => { if (n.type === '__Set') leftover++; });
  return { changed: reads + writes, reads, writes, proxies: proxies.size, leftover };
}

export { makeConst, constOf, NOT_CONST };
