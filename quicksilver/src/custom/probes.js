// What a script has been made into, read from its structure alone.
//
// A tool's name is not needed for this. A transformation is a way of changing a program, and it leaves a shape behind that can be measured on the syntax tree: a loop that picks
// code by a counter, a function that turns constant strings into other strings, a table of constants that the program only ever indexes with numbers. Every probe here returns the
// evidence it found (what, how many, where) so that a reader can check it, and a confidence that says how well the evidence fits the transformation, not how sure anything is
// about a name.
//
// Nothing is run. A script that does not parse gets the one finding `invalid-syntax` with the position the parser gave.

import { parse, LuaSyntaxError } from '../core/parser.js';
import { forEachChild } from '../core/walk.js';
import { analyze } from '../core/scope.js';
import { isMachineName } from '../passes/rename.js';
import { evalExpr, partial, find } from '../recover/zartha-vm.js';

const unparen = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const lineOf = (n) => (n && (n.line || (n.key && n.key.line) || (n.cond && n.cond.line))) || null;
const clip = (s, n = 70) => (s.length > n ? `${s.slice(0, n - 1)}…` : s);

import { readContainer21 } from '../recover/moonveil-vm/container21.js';

export const TRANSFORMATIONS = {
  'bytecode-vm': 'The program is data run by a generated interpreter',
  'control-flow-flattening': 'Control flow goes through a state variable that a dispatcher loop switches on',
  'string-encryption': 'Strings are produced at run time by a decoder from constant arguments',
  'constant-table': 'Constants are kept in one table and read by number',
  'compressed-payload': 'A long text that is not source carries the program',
  'identifier-mangling': 'Names carry no meaning',
  'numeric-obfuscation': 'Arithmetic on constants stands where a constant was',
  'metamethod-arithmetic': 'Arithmetic is routed through metamethods of tables',
  'wrapper': 'The program is inside a function that is called at once, or loaded from computed text',
  'dead-code': 'Branches whose condition is known, and code that cannot run',
  'environment-probe': 'The script inspects its own environment (anti-tamper, executor checks)',
  'minified-layout': 'Layout was removed',
};


const COMPARE = new Set(['==', '<=', '<', '>', '>=', '~=']);

/**
 * The one variable a test depends on when the test is a comparison (or an and/or of comparisons) of arithmetic on that variable with numbers: `pc == 7`, `op <= 20`,
 * `(pc * pc) + 8 * pc == 20`, `op == 3 or op == 9`. Anything that reads a table, calls a function or mentions a second name is not a dispatch test.
 */
function conditionVariable(cond) {
  const names = new Set();
  let ok = true;
  let tests = 0;
  const arith = (e) => {
    e = unparen(e);
    if (e.type === 'Number') return;
    if (e.type === 'Name') { names.add(e.name); return; }
    if (e.type === 'Unary' && e.op === '-') { arith(e.arg); return; }
    if (e.type === 'Binary' && ['+', '-', '*', '/', '%'].includes(e.op)) { arith(e.left); arith(e.right); return; }
    ok = false;
  };
  const walkCond = (e) => {
    e = unparen(e);
    if (e.type === 'Binary' && (e.op === 'and' || e.op === 'or')) { walkCond(e.left); walkCond(e.right); return; }
    if (e.type === 'Unary' && e.op === 'not') { walkCond(e.arg); return; }
    if (e.type === 'Binary' && COMPARE.has(e.op)) { tests++; arith(e.left); arith(e.right); return; }
    ok = false;
  };
  walkCond(cond);
  return ok && tests >= 1 && names.size === 1 ? [...names][0] : null;
}

// ---- loops that dispatch ------------------------------------------------------------------------------------------------------------

function loopsWithDispatch(ast) {
  const out = [];
  // a dispatch sits in a loop, or in a function a loop calls once per instruction (`while #stack > 0 do step(frame) end`, Vault-Obf): the step function's body is the
  // interpreter's body. Only the function's own statements are looked at, not the functions inside it
  find(ast, (n) => n.type === 'While' || n.type === 'Repeat' || n.type === 'NumFor' || n.type === 'Func').forEach((loop) => {
    // the first test of the dispatch: an If whose clauses compare one name with numbers
    const chains = find(loop.body, (n) => n.type === 'If' && n.clauses.length >= 1);
    for (const chain of chains) {
      const names = new Map();
      let numeric = 0;
      let depth = 0;
      const scan = (stmt, d) => {
        if (stmt.type !== 'If') return;
        depth = Math.max(depth, d);
        for (const c of stmt.clauses) {
          const nm = conditionVariable(c.cond);
          if (nm) { names.set(nm, (names.get(nm) || 0) + 1); numeric++; }
          // a handler is code; only a body that is itself one test is another level of the dispatch
          if (c.body.length === 1 && c.body[0].type === 'If') scan(c.body[0], d + 1);
        }
        if (stmt.orelse && stmt.orelse.length === 1 && stmt.orelse[0].type === 'If') scan(stmt.orelse[0], d + 1);
      };
      scan(chain, 1);
      const top = [...names].sort((a, b) => b[1] - a[1])[0];
      if (top && numeric >= 6 && top[1] >= Math.max(5, numeric * 0.6)) out.push({ loop, chain, variable: top[0], tests: numeric, depth });
    }
  });
  // one per loop: the biggest chain
  const best = new Map();
  for (const d of out) { const cur = best.get(d.loop); if (!cur || d.tests > cur.tests) best.set(d.loop, d); }
  return [...best.values()];
}

/** The numbers a dispatch compares its variable with, which is where its handlers are. */
function dispatchValues(d) {
  const vals = new Set();
  find(d.chain, (n) => n.type === 'Binary' && ['==', '<=', '<', '>', '>=', '~='].includes(n.op) && unparen(n.left).type === 'Name' && unparen(n.left).name === d.variable && unparen(n.right).type === 'Number')
    .forEach((n) => { const v = unparen(n.right).value; vals.add(v); vals.add(v + 1); vals.add(v - 1); });
  return [...vals].filter((v) => Number.isInteger(v) && v >= -1 && v < 100000).sort((a, b) => a - b);
}

/** What a handler does, in the classes of Lua's own operations, read from the shape of its code. */
const CLASSES = {
  'move-load': (h) => h.assignsIndexFromIndex || h.assignsName,
  'table-read': (h) => h.indexReads >= 1,
  'table-write': (h) => h.indexWrites >= 1,
  'table-new': (h) => h.tables >= 1,
  arithmetic: (h) => h.arith >= 1,
  concat: (h) => h.concat >= 1,
  length: (h) => h.len >= 1,
  unary: (h) => h.unary >= 1,
  compare: (h) => h.compare >= 1,
  jump: (h) => h.assignsCounter,
  call: (h) => h.calls >= 1,
  'return': (h) => h.returns >= 1,
  closure: (h) => h.funcs >= 1,
  vararg: (h) => h.varargs >= 1,
  loop: (h) => h.loops >= 1,
};

function describeHandler(stmts, counter) {
  const h = { indexReads: 0, indexWrites: 0, tables: 0, arith: 0, concat: 0, len: 0, unary: 0, compare: 0, calls: 0, returns: 0, funcs: 0, varargs: 0, loops: 0, assignsCounter: false, assignsName: false, assignsIndexFromIndex: false };
  const visit = (n, parent) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach((x) => visit(x, parent)); return; }
    switch (n.type) {
      case 'Assign':
        for (const t of n.targets) {
          if (t.type === 'Index') h.indexWrites++;
          if (t.type === 'Name' && t.name === counter) h.assignsCounter = true;
          if (t.type === 'Name') h.assignsName = true;
        }
        if (n.targets.some((t) => t.type === 'Index') && n.values.some((v) => unparen(v).type === 'Index')) h.assignsIndexFromIndex = true;
        break;
      case 'Index': h.indexReads++; break;
      case 'Table': h.tables++; break;
      case 'Binary':
        if (['+', '-', '*', '/', '%', '^'].includes(n.op)) h.arith++;
        else if (n.op === '..') h.concat++;
        else if (['==', '~=', '<', '<=', '>', '>='].includes(n.op)) h.compare++;
        break;
      case 'Unary': if (n.op === '#') h.len++; else h.unary++; break;
      case 'Call': case 'MethodCall': h.calls++; break;
      case 'Return': h.returns++; break;
      case 'Func': h.funcs++; return;
      case 'Vararg': h.varargs++; break;
      case 'NumFor': case 'GenFor': case 'While': case 'Repeat': h.loops++; break;
      default: break;
    }
    forEachChild(n, (c) => visit(c, n));
  };
  visit(stmts, null);
  // an Index that is only a write target is not a read
  h.indexReads = Math.max(0, h.indexReads - h.indexWrites);
  return h;
}

function interpreterFinding(ast) {
  const loops = loopsWithDispatch(ast);
  if (!loops.length) return { vm: null, flatten: null };
  // the biggest dispatch is the interpreter or the flattened state machine; the rest are noise
  loops.sort((a, b) => b.tests - a.tests);
  const d = loops[0];
  const counterAdvanced = find(d.loop.body, (n) => n.type === 'Assign' && n.targets.length === 1 && n.targets[0].type === 'Name' && n.targets[0].name === d.variable
    && n.values.length === 1 && unparen(n.values[0]).type === 'Binary' && ['+', '-'].includes(unparen(n.values[0]).op) && unparen(unparen(n.values[0]).left).type === 'Name' && unparen(unparen(n.values[0]).left).name === d.variable).length;
  const setToConstant = find(d.loop.body, (n) => n.type === 'Assign' && n.targets.length === 1 && n.targets[0].type === 'Name' && n.targets[0].name === d.variable && n.values.length === 1 && unparen(n.values[0]).type === 'Number').length;
  const ops = find(d.chain, (n) => n.type === 'Binary' && n.op === '<=' && unparen(n.left).type === 'Name' && unparen(n.left).name === d.variable).length;
  const eq = find(d.chain, (n) => n.type === 'Binary' && n.op === '==' && unparen(n.left).type === 'Name' && unparen(n.left).name === d.variable).length;
  const fetched = find(d.loop.body, (n) => (n.type === 'Local' || n.type === 'Assign') && (n.values || []).some((v) => unparen(v).type === 'Index' && unparen(unparen(v).key).type === 'Number'));
  // handlers: evaluate the dispatch for every number it compares with
  const handlers = new Map();
  const wholeChain = [d.chain];
  for (const v of dispatchValues(d)) {
    let leaf;
    try { leaf = partial(wholeChain, d.variable, v); } catch { continue; }
    if (!leaf.length) continue;
    const key = JSON.stringify(leaf, (k, x) => (k === 'line' || k === 'pos' || k === 'endPos' || k === 'endLine' || k === 'blankBefore' || k === 'comments' ? undefined : x));
    if (!handlers.has(key)) handlers.set(key, { value: v, stmts: leaf });
  }
  const profile = {};
  const unclassified = [];
  for (const { value, stmts } of handlers.values()) {
    const h = describeHandler(stmts, d.variable);
    const classes = Object.entries(CLASSES).filter(([, f]) => f(h)).map(([c]) => c);
    if (!classes.length) { unclassified.push(value); continue; }
    for (const c of classes) profile[c] = (profile[c] || 0) + 1;
  }
  // a flattened state machine writes its own variable in its branches (`i = 7`, `i = c and i + 3 or 12 - i`) and seldom reads a table by number; an interpreter
  // fetches its operands from the instruction (`inst[2]`) far more often than it writes the variable it dispatches on
  const writesState = find(d.loop.body, (n) => n.type === 'Assign' && n.targets.some((t) => t.type === 'Name' && t.name === d.variable)).length;
  const selfWritten = !(counterAdvanced && eq >= ops) && writesState >= d.tests * 0.5 && fetched.length * 5 < writesState;
  const shape = counterAdvanced && eq >= ops ? 'per-instruction' : selfWritten ? 'state-machine' : ops > eq && ops >= 6 ? 'opcode-tree' : fetched.length ? 'opcode-switch' : setToConstant >= d.tests * 0.5 ? 'state-machine' : 'opcode-switch';
  const instructionLike = Object.keys(profile).filter((c) => ['table-read', 'table-write', 'arithmetic', 'compare', 'jump', 'call', 'return', 'closure', 'concat', 'length'].includes(c)).length;
  const base = { variable: d.variable, tests: d.tests, depth: d.depth, handlers: handlers.size, shape, profile, unclassified: unclassified.length, line: lineOf(d.loop) };
  // a state machine that sets its variable to constants in its branches is control-flow flattening; a dispatch whose handlers cover the operations of a register machine is a VM
  // a register machine for Lua has some forty to ninety operations; hundreds of distinct branches that write the state themselves are a program's own blocks, flattened
  if (shape === 'state-machine' && (instructionLike < 5 || (selfWritten && handlers.size > 120))) {
    return { vm: null, flatten: { ...base, confidence: Math.min(0.95, 0.5 + setToConstant / Math.max(1, d.tests)) } };
  }
  const coverage = instructionLike / 10;
  return { vm: { ...base, confidence: Math.min(0.98, 0.45 + coverage * 0.5 + Math.min(0.2, handlers.size / 200)), instructionClasses: instructionLike }, flatten: null };
}

// ---- an interpreter whose handlers are functions in a table: `H[op](...)`, `H[perm[op + 1]](...)` (Vault-Obf's table and indirect dispatch) -----------------

function handlerTableFinding(ast) {
  const tables = new Map();                              // name -> { fns: Func[], line }
  const add = (name, fn, line) => { if (!tables.has(name)) tables.set(name, { fns: [], line }); tables.get(name).fns.push(fn); };
  find(ast, (n) => n.type === 'Assign').forEach((n) => n.targets.forEach((t, i) => {
    const v = n.values[i] && unparen(n.values[i]);
    if (t.type === 'Index' && t.obj.type === 'Name' && unparen(t.key).type === 'Number' && v && v.type === 'Func') add(t.obj.name, v, n.line);
  }));
  find(ast, (n) => n.type === 'Local' && n.values.length === 1 && n.values[0].type === 'Table').forEach((n) => {
    const fns = n.values[0].fields.filter((f) => f.value && f.value.type === 'Func' && (f.kind === 'keyed' ? unparen(f.key).type === 'Number' : true)).map((f) => f.value);
    for (const fn of fns) add(n.ids[0].name, fn, n.line);
  });
  let best = null;
  for (const [name, { fns, line }] of tables) {
    if (fns.length < 8) continue;
    // read with a key that is computed: the dispatch
    const computed = find(ast, (n) => n.type === 'Index' && n.obj.type === 'Name' && n.obj.name === name && !['Number', 'String'].includes(unparen(n.key).type)).length;
    if (!computed) continue;
    const profile = {};
    for (const fn of fns) {
      const h = describeHandler(fn.body, null);
      for (const [c, f] of Object.entries(CLASSES)) if (f(h)) profile[c] = (profile[c] || 0) + 1;
    }
    const instructionLike = Object.keys(profile).filter((c) => ['table-read', 'table-write', 'arithmetic', 'compare', 'jump', 'call', 'return', 'closure', 'concat', 'length'].includes(c)).length;
    if (!best || fns.length > best.handlers) best = { variable: name, handlers: fns.length, profile, instructionClasses: instructionLike, line };
  }
  return best && best.instructionClasses >= 5 ? best : null;
}

// ---- a program shipped as data through a chain of calls ----------------------------------------------------------------------------------------------------

function stagedContainer(ast) {
  let best = null;
  const callee = (c) => (c.fn.type === 'Index' && c.fn.key.type === 'String' ? c.fn.key.value : c.fn.type === 'Name' ? c.fn.name : '?');
  find(ast, (n) => n.type === 'Call').forEach((outer) => {
    const names = [];
    let c = outer;
    while (c && c.type === 'Call') {
      names.push(callee(c));
      const a = c.args[0] && unparen(c.args[0]);
      if (a && a.type === 'String') {
        if (names.length >= 3 && a.value.length >= 100 && (!best || a.value.length > best.data.length)) best = { data: a.value, depth: names.length, names, line: outer.line };
        return;
      }
      c = a;
    }
  });
  if (!best) return null;
  try {
    const c = readContainer21(best.data);
    best.stages = [
      `stage 1: base 85 (RFC 1924 digits), ${best.data.length} characters to ${c.packedBytes} bytes`,
      `stage 2: LZSS (flag bytes, 2048-byte window), ${c.packedBytes} to ${c.programBytes} bytes`,
      `stage 3: a table of ${c.strings.length} string(s) and a function of ${c.main.instructions} instruction(s), the layout MoonVeil 2.1.0 uses`,
    ];
  } catch { best.stages = null; }
  return best;
}

// ---- other transformations ---------------------------------------------------------------------------------------------------------------------------------

function stringDecoders(ast) {
  const decoders = new Map();
  const fns = [];
  find(ast, (n) => n.type === 'LocalFunction' || (n.type === 'Local' && n.values.length === 1 && n.values[0].type === 'Func') || n.type === 'Function').forEach((n) => {
    const fn = n.type === 'LocalFunction' ? n.func : n.type === 'Local' ? n.values[0] : n.body ? n : null;
    const body = fn && (fn.body || (n.func && n.func.body));
    if (!body) return;
    const name = n.type === 'LocalFunction' ? n.id.name : n.type === 'Local' ? n.ids[0].name : n.target && n.target.type === 'Name' ? n.target.name : null;
    if (!name) return;
    const calls = find(body, (m) => m.type === 'Call' && m.fn.type === 'Index' && m.fn.obj.type === 'Name' && m.fn.obj.name === 'string').map((m) => m.fn.key.value || m.fn.key.name);
    const byteReader = calls.some((c) => c === 'byte' || c === 'char') || find(body, (m) => m.type === 'MethodCall' && ['byte', 'sub'].includes(m.name)).length > 0;
    const loops = find(body, (m) => m.type === 'NumFor' || m.type === 'GenFor' || m.type === 'While').length;
    const buildsText = calls.includes('char') || find(body, (m) => m.type === 'Binary' && m.op === '..').length > 0 || calls.includes('concat');
    if (byteReader && loops && buildsText) fns.push(name);
  });
  const names = new Set(fns);
  if (!names.size) return null;
  let sites = 0;
  find(ast, (n) => n.type === 'Call' && n.fn.type === 'Name' && names.has(n.fn.name) && n.args.length >= 1 && unparen(n.args[0]).type === 'String').forEach((n) => { sites++; decoders.set(n.fn.name, (decoders.get(n.fn.name) || 0) + 1); });
  return sites >= 3 ? { functions: [...names].length, sites, confidence: Math.min(0.97, 0.5 + sites / 40) } : null;
}

function entropy(s) {
  const f = new Map();
  for (const c of s) f.set(c, (f.get(c) || 0) + 1);
  let e = 0;
  for (const v of f.values()) { const p = v / s.length; e -= p * Math.log2(p); }
  return { bits: e, alphabet: f.size };
}

function payloads(ast) {
  let best = null;
  find(ast, (n) => n.type === 'String' && n.value.length >= 300).forEach((n) => {
    const e = entropy(n.value);
    const text = /^[\x20-\x7e\n\t]*$/.test(n.value);
    if (!best || n.value.length > best.length) best = { length: n.value.length, bits: +e.bits.toFixed(2), alphabet: e.alphabet, printable: text, line: lineOf(n) };
  });
  if (!best) return null;
  // prose has 4 bits per character and an alphabet of 40 or so; encoded or compressed data is above 5 bits, or has an alphabet that is a clean power of two or a base
  const dense = best.bits >= 4.8 || best.alphabet >= 60;
  return dense || !best.printable ? { ...best, confidence: dense ? 0.85 : 0.6 } : null;
}

function constantTables(ast) {
  const info = analyze(ast);
  let best = null;
  for (const v of info.vars) {
    if (v.kind !== 'local' || !v.init || v.init.type !== 'Table' || v.init.fields.length < 8) continue;
    const f = v.init.fields;
    if (!f.every((x) => ['String', 'Number', 'True', 'False', 'Nil'].includes(unparen(x.value).type) || (unparen(x.value).type === 'Unary'))) continue;
    if (v.writes.length) continue;
    let constantReads = 0; let other = 0;
    for (const r of v.reads) {
      // reads are Name nodes; whether their parent indexes with a number is found below
      constantReads++;
    }
    void other;
    if (!best || f.length > best.entries) best = { entries: f.length, reads: constantReads, name: v.name, machineNamed: isMachineName(v.name), confidence: Math.min(0.95, 0.4 + Math.min(0.4, constantReads / 60) + (f.length >= 20 ? 0.1 : 0)) };
  }
  return best;
}

function foldableArithmetic(ast) {
  let total = 0; let foldable = 0;
  find(ast, (n) => n.type === 'Binary' && ['+', '-', '*', '/', '%', '^'].includes(n.op)).forEach((n) => {
    total++;
    const num = (e) => { const x = unparen(e); return x.type === 'Number' || (x.type === 'Unary' && x.op === '-' && unparen(x.arg).type === 'Number') || (x.type === 'Binary' && ['+', '-', '*', '/', '%', '^'].includes(x.op) && num(x.left) && num(x.right)); };
    if (num(n.left) && num(n.right)) foldable++;
  });
  return total >= 8 && foldable / total >= 0.15 ? { arithmetic: total, foldable, confidence: Math.min(0.95, 0.4 + foldable / total) } : null;
}

function metamethodArithmetic(ast) {
  const n = find(ast, (x) => x.type === 'Call' && x.fn.type === 'Name' && x.fn.name === 'setmetatable' && x.args[1] && unparen(x.args[1]).type === 'Table'
    && unparen(x.args[1]).fields.some((f) => /^__(add|sub|mul|div|mod|pow|concat|unm|idiv)$/.test(f.key && (f.key.value || f.key) || ''))).length;
  return n >= 2 ? { tables: n, confidence: Math.min(0.95, 0.5 + n / 30) } : null;
}

function wrappers(ast) {
  const body = ast.body;
  if (body.length === 1) {
    const s = body[0];
    const call = s.type === 'Return' && s.values.length === 1 ? unparen(s.values[0]) : s.type === 'CallStmt' ? s.call : null;
    const fn = call && call.type === 'Call' ? unparen(call.fn) : null;
    if (fn && fn.type === 'Func') return { kind: 'immediately-called function', confidence: 0.8 };
  }
  const loaders = find(ast, (n) => n.type === 'Call' && n.fn.type === 'Name' && /^(loadstring|load)$/.test(n.fn.name));
  if (loaders.length) return { kind: 'text compiled at run time', loads: loaders.length, confidence: 0.7 };
  return null;
}

function deadCode(ast) {
  let known = 0; let total = 0;
  find(ast, (n) => n.type === 'If').forEach((n) => { total++; if (n.clauses.some((c) => evalExpr(c.cond, '\u0000', 0) !== undefined)) known++; });
  return known >= 3 ? { branches: total, known, confidence: Math.min(0.9, 0.4 + known / 20) } : null;
}

function environmentProbes(ast) {
  const names = new Set(['getfenv', 'setfenv', 'debug', 'newproxy', 'getgenv', 'syn', 'identifyexecutor', 'checkcaller', 'hookfunction', 'getrenv']);
  const hit = new Set();
  find(ast, (n) => n.type === 'Name' && names.has(n.name)).forEach((n) => hit.add(n.name));
  const pcalls = find(ast, (n) => n.type === 'Call' && n.fn.type === 'Name' && (n.fn.name === 'pcall' || n.fn.name === 'xpcall')).length;
  return hit.size >= 2 || (hit.size >= 1 && pcalls >= 3) ? { names: [...hit], pcalls, confidence: Math.min(0.9, 0.3 + hit.size * 0.15 + pcalls * 0.03) } : null;
}

/**
 * @param {string} source binary string
 * @returns {{ok: boolean, error?: object, transformations: object[], structure: object}}
 */
export function probe(source) {
  let ast;
  try { ast = parse(source); } catch (e) {
    if (e instanceof LuaSyntaxError) return { ok: false, error: { message: e.message, line: e.line, col: e.col }, transformations: [{ id: 'invalid-syntax', confidence: 1, evidence: [`${e.message}`] }], structure: {} };
    throw e;
  }
  const out = [];
  const add = (id, confidence, evidence, extra = {}) => out.push({ ...extra, id, confidence: +confidence.toFixed(2), description: TRANSFORMATIONS[id], evidence });
  const { vm, flatten } = interpreterFinding(ast);
  if (vm && vm.confidence >= 0.5) {
    const kind = { 'per-instruction': 'one piece of code per instruction, picked by the instruction counter', 'opcode-tree': 'a binary search over the opcode', 'opcode-switch': 'a chain of tests on the opcode' }[vm.shape] || vm.shape;
    add('bytecode-vm', vm.confidence, [
      `a loop at line ${vm.line || '?'} dispatches on \`${vm.variable}\` with ${vm.tests} tests (${kind})`,
      `${vm.handlers} distinct handlers; ${vm.instructionClasses} of the 10 operation classes of a register machine appear (${Object.keys(vm.profile).join(', ')})`,
      ...(vm.unclassified ? [`${vm.unclassified} handler(s) fit no operation class`] : []),
    ], { shape: vm.shape, handlers: vm.handlers, profile: vm.profile, variable: vm.variable, line: vm.line });
  }
  const ht = !(vm && vm.confidence >= 0.5) ? handlerTableFinding(ast) : null;
  if (ht) {
    add('bytecode-vm', Math.min(0.95, 0.45 + ht.instructionClasses / 20 + Math.min(0.2, ht.handlers / 200)), [
      `a table \`${ht.variable}\` holds ${ht.handlers} functions under numbers and is read with a computed key: an interpreter whose handlers are functions (dispatch without comparisons)`,
      `${ht.instructionClasses} of the 10 operation classes of a register machine appear in them (${Object.keys(ht.profile).join(', ')})`,
    ], { shape: 'handler-table', handlers: ht.handlers, profile: ht.profile, variable: ht.variable, line: ht.line });
  }
  // a program shipped as data: a long string passed through a chain of calls (decode, unpack, run). Each stage that a known reader can take is evidence of its own;
  // the stages are what the analysis reports as identified, the program they hold is not claimed
  const chain = stagedContainer(ast);
  if (chain && !(vm && vm.confidence >= 0.5)) {
    const evidence = [`the ${chain.data.length}-character string at the end of a chain of ${chain.depth} calls (${chain.names.join(' \u2190 ')}) is data the script decodes and runs`];
    let conf = 0.55;
    if (chain.stages) { evidence.push(...chain.stages); conf = 0.85; }
    add('bytecode-vm', conf, evidence, { shape: 'staged-container', stages: chain.stages ? chain.stages.length : 0, line: chain.line });
  }
  if (flatten) add('control-flow-flattening', flatten.confidence, [`a loop at line ${flatten.line || '?'} switches on \`${flatten.variable}\` with ${flatten.tests} tests and sets it to constants in its branches`], { line: flatten.line, variable: flatten.variable });
  const dec = stringDecoders(ast);
  if (dec) add('string-encryption', dec.confidence, [`${dec.functions} function(s) read bytes in a loop and build text, called with a constant string ${dec.sites} times`], dec);
  const pay = payloads(ast);
  if (pay) add('compressed-payload', pay.confidence, [`a ${pay.length}-character string at line ${pay.line || '?'} with ${pay.bits} bits per character over ${pay.alphabet} symbols${pay.printable ? '' : ' (not printable)'}`], pay);
  const ct = constantTables(ast);
  if (ct) add('constant-table', ct.confidence, [`a table of ${ct.entries} constants read ${ct.reads} times${ct.machineNamed ? ' under a machine-made name' : ''}`], ct);
  const mm = metamethodArithmetic(ast);
  if (mm) add('metamethod-arithmetic', mm.confidence, [`${mm.tables} tables get arithmetic metamethods`], mm);
  const na = foldableArithmetic(ast);
  if (na) add('numeric-obfuscation', na.confidence, [`${na.foldable} of ${na.arithmetic} arithmetic expressions are on constants only`], na);
  const w = wrappers(ast);
  if (w) add('wrapper', w.confidence, [w.kind], w);
  const dc = deadCode(ast);
  if (dc) add('dead-code', dc.confidence, [`${dc.known} of ${dc.branches} tests have a value that is known`], dc);
  const ep = environmentProbes(ast);
  if (ep) add('environment-probe', ep.confidence, [`reads ${ep.names.join(', ')}; ${ep.pcalls} protected calls`], ep);
  // names and layout
  const info = analyze(ast);
  const locals = info.vars.filter((v) => v.decl && v.name !== 'self');
  const mangled = locals.length >= 6 ? locals.filter((v) => isMachineName(v.name)).length / locals.length : 0;
  if (mangled >= 0.6) add('identifier-mangling', Math.min(0.97, mangled), [`${Math.round(mangled * 100)}% of ${locals.length} local names are machine-made`], { ratio: +mangled.toFixed(2) });
  const lines = source.split('\n');
  const longest = lines.reduce((a, l) => Math.max(a, l.length), 0);
  if (longest > 300 || source.length / Math.max(1, lines.length) > 120) add('minified-layout', 0.9, [`${lines.length} lines, the longest ${longest} characters`]);
  out.sort((a, b) => b.confidence - a.confidence);
  return { ok: true, transformations: out, structure: { bytes: source.length, lines: lines.length, locals: locals.length, mangledRatio: +mangled.toFixed(2) } };
}
