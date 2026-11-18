// Anatomy of an unfamiliar script: what its parts are, where they are, how they connect, and which hypotheses about them survive a test.
//
// The probes (probes.js) say WHICH transformations a script shows. This says WHERE and HOW, without needing a tool's name:
//
//   functions   every function, with the role its code suggests — string decoder, base-N decoder, decompressor, byte/varint/float
//               deserializer, keyed XOR, interpreter, environment manipulation, anti-analysis — and the evidence for each role;
//   regions     the encoded data: long or dense string literals and numeric arrays, their charset and entropy, the share of the file
//               they take, and the function that consumes each of them (data flow, not proximity);
//   stages      the transformation boundaries: text compiled at run time (load/loadstring), an interpreter entered with data, a wrapper;
//   vm          for an interpreter: instruction encoding (tables or packed numbers and their bit fields), register or stack machine,
//               constant pool, closures, varargs, jumps — measured on the dispatch and its handlers;
//   hypotheses  a statement, a confidence, the evidence, and a TEST where one exists: a decoder hypothesis is tested by running the
//               evaluator (the sandbox, under its limits, only on the decoder's slice) and counting the call sites it resolved; a VM
//               hypothesis by the readers of known VM formats; a stage hypothesis by whether the layer could be unwrapped.
//
// Learned rules (rules.js) are fingerprints of functions whose role was confirmed on authorised samples. An exact fingerprint match raises
// a hypothesis but never replaces its test; a near match is reported as "resembles" and never treated as the same format.
//
// Nothing here runs the script. Tests that need the sandbox run only when the caller enables it.

import { parse } from '../core/parser.js';
import { walk } from '../core/walk.js';
import { loopsWithDispatch, interpreterFinding, entropy } from './probes.js';
import { fingerprint, matchRules } from './rules.js';

const unparen = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const lineOf = (n) => (n && (n.line || (n.key && n.key.line))) || null;
const calleeName = (fn) => {
  const x = unparen(fn);
  if (!x) return '';
  if (x.type === 'Name') return x.name;
  if (x.type === 'Index' && x.key && x.key.type === 'String') { const o = calleeName(x.obj); return o ? `${o}.${x.key.value}` : `?.${x.key.value}`; }
  return '';
};

/** Walk a function's own body: nested functions are their own entries. */
function ownWalk(body, fn) {
  walk(body, (n) => { if (n.type === 'Func') return false; return fn(n); });
}

// ---- functions and their roles ----------------------------------------------------------------------------------------------------

function inventory(ast) {
  const fns = [];
  const byNode = new Map();
  const add = (func, name, line) => {
    if (byNode.has(func)) return;
    const e = { id: fns.length, name: name || null, line: line || lineOf(func) || (func.body && func.body[0] && func.body[0].line) || null, func, params: (func.params || []).length, vararg: !!func.vararg || (func.params || []).some((p) => p.type === 'Vararg') };
    fns.push(e);
    byNode.set(func, e);
  };
  walk(ast, (n) => {
    if (n.type === 'LocalFunction') add(n.func, n.id.name, n.line);
    else if (n.type === 'Function') add(n.func, calleeName(n.target) || null, n.line);
    else if ((n.type === 'Local' || n.type === 'Assign') && n.values) {
      const targets = n.type === 'Local' ? n.ids : n.targets;
      n.values.forEach((v, i) => { if (v && v.type === 'Func' && targets[i]) add(v, targets[i].name || calleeName(targets[i]) || null, n.line); });
    } else if (n.type === 'Func') add(n, null, n.line);
  });
  return { fns, byNode };
}

function features(func, alphabets = new Map()) {
  const f = { size: 0, loops: 0, std: new Set(), stringOps: 0, byteRead: 0, charBuild: 0, concat: 0, tableConcat: 0, bitXor: 0, bitOps: 0, mod: 0, pow2: [], mul256: 0, ldexp: 0, floatBias: 0, varint: 0, posInc: 0, returns: 0, alphabet: null, dict255: 0, env: 0, anti: [], closures: 0, calls: 0, indexByKeyMod: 0 };
  walk(func.body, (n) => {
    f.size++;
    switch (n.type) {
      case 'Func': f.closures++; return false;
      case 'NumFor': case 'GenFor': case 'While': case 'Repeat': f.loops++;
        if (n.type === 'NumFor' && unparen(n.stop) && unparen(n.stop).type === 'Number' && unparen(n.stop).value === 255) f.dict255++;
        break;
      case 'Return': f.returns++; break;
      case 'Call': case 'MethodCall': {
        f.calls++;
        const c = n.type === 'MethodCall' ? `:${n.name}` : calleeName(n.fn);
        if (/^(string\.|:)(byte|sub|char|gsub|find|gmatch|rep|reverse|format|len|upper|lower)$/.test(c)) f.stringOps++;
        if (/(^string\.|^:)byte$/.test(c)) f.byteRead++;
        if (/(^string\.|^:)char$/.test(c) || /^(char|chr)$/.test(c)) f.charBuild++;
        if (/^table\.concat$/.test(c)) f.tableConcat++;
        if (/(^|\.)bxor$/.test(c)) f.bitXor++;
        if (/^bit32?\.|^bit\./.test(c)) f.bitOps++;
        if (/^math\.ldexp$/.test(c)) f.ldexp++;
        if (/^(getfenv|setfenv|setmetatable|getmetatable|rawset|rawget)$/.test(c)) f.env++;
        if (/^(debug\.\w+|string\.dump|os\.clock|tick|collectgarbage|newproxy)$/.test(c)) f.anti.push(c);
        const d = c.split('.')[0];
        if (['string', 'table', 'math', 'bit32', 'bit', 'debug', 'os', 'coroutine', 'utf8'].includes(d)) f.std.add(c);
        break;
      }
      case 'Binary':
        if (n.op === '..') f.concat++;
        if (n.op === '%') {
          f.mod++;
          const r = unparen(n.right);
          if (r && r.type === 'Unary' && r.op === '#') f.indexByKeyMod++;
          if (r && r.type === 'Number' && r.value === 128) f.varint++;
        }
        if (n.op === '*' || n.op === '/') { for (const s of [unparen(n.left), unparen(n.right)]) if (s && s.type === 'Number' && [256, 65536, 16777216].includes(s.value)) f.mul256++; }
        if (n.op === '^') { const l = unparen(n.left); const r = unparen(n.right); if (l && l.type === 'Number' && l.value === 2 && r && r.type === 'Number') { f.pow2.push(r.value); if (r.value === 52 || r.value === -1074 || r.value === 1023) f.floatBias++; } }
        if (['>=', '<'].includes(n.op)) { const r = unparen(n.right); if (r && r.type === 'Number' && r.value === 128) f.varint++; }
        break;
      case 'Number': if (n.value === 1023 || n.value === 4503599627370496) f.floatBias++; break;
      case 'String': {
        const v = n.value;
        if (v.length >= 32 && v.length <= 128 && new Set(v).size === v.length) f.alphabet = { length: v.length, sample: v.slice(0, 12) };
        if (/:%d\+:/.test(v) || /^:%d/.test(v)) f.anti.push('error-line pattern');
        break;
      }
      case 'Assign':
        for (const [i, t] of n.targets.entries()) {
          const v = unparen(n.values[i]);
          if (t.type === 'Name' && v && v.type === 'Binary' && v.op === '+' && unparen(v.left).type === 'Name' && unparen(v.left).name === t.name && unparen(v.right).type === 'Number') f.posInc++;
        }
        break;
      case 'Name':
        if (n.name === '_ENV' || n.name === 'getfenv' || n.name === 'setfenv') f.env++;
        if (!f.alphabet && alphabets.has(n.name)) f.alphabet = alphabets.get(n.name);
        break;
      default: break;
    }
    return undefined;
  });
  return f;
}

const ROLE_LABEL = {
  'string-decoder': 'string decoder',
  'base-n-decoder': 'base-N text decoder',
  'lzw-decompressor': 'LZW-style decompressor',
  deserializer: 'byte deserializer',
  'xor-cipher': 'keyed XOR',
  interpreter: 'virtual-machine interpreter',
  'env-manipulation': 'environment manipulation',
  'anti-analysis': 'anti-analysis / integrity check',
  'vm-closure-factory': 'VM closure factory',
};

function roles(entry, f, ctx) {
  const out = [];
  const add = (role, confidence, evidence) => out.push({ role, label: ROLE_LABEL[role], confidence: +Math.min(0.97, confidence).toFixed(2), evidence });
  const sites = ctx.constSites.get(entry.name) || 0;
  if (ctx.interpreters.has(entry.func)) {
    const d = ctx.interpreters.get(entry.func);
    add('interpreter', 0.55 + Math.min(0.4, d.tests / 120), [`a loop dispatches on \`${d.variable}\` with ${d.tests} tests`]);
  }
  if (f.alphabet && (f.byteRead || f.stringOps >= 2) && f.loops && (f.charBuild || f.tableConcat || f.concat)) add('base-n-decoder', 0.6 + (sites ? 0.15 : 0) + ([64, 85, 91, 93].includes(f.alphabet.length) ? 0.15 : 0), [`an alphabet of ${f.alphabet.length} distinct characters ("${f.alphabet.sample}…")`, 'reads characters in a loop and builds text']);
  if (f.dict255 && (f.charBuild || f.concat) && f.loops >= 2) add('lzw-decompressor', 0.7, ['a dictionary filled with the 256 single characters (a loop to 255 with string.char)', 'entries built by concatenation']);
  if (f.bitXor || (f.indexByKeyMod && f.byteRead && f.charBuild)) add('xor-cipher', 0.55 + (f.indexByKeyMod ? 0.2 : 0) + (sites ? 0.1 : 0), [f.bitXor ? 'calls bxor' : 'combines bytes arithmetically', f.indexByKeyMod ? 'cycles through a key (`% #key`)' : null].filter(Boolean));
  if (f.byteRead && f.posInc && (f.mul256 || f.varint || f.floatBias || f.ldexp)) {
    const kinds = [f.mul256 ? 'multi-byte integers' : null, f.varint ? 'variable-length integers' : null, f.floatBias || f.ldexp ? 'IEEE floats' : null].filter(Boolean);
    add('deserializer', 0.6 + kinds.length * 0.1, [`reads bytes at an advancing position: ${kinds.join(', ')}`]);
  }
  if (!out.some((r) => ['base-n-decoder', 'lzw-decompressor', 'deserializer'].includes(r.role)) && (f.byteRead || f.stringOps >= 2) && f.loops && (f.charBuild || f.tableConcat || f.concat) && f.returns) {
    add('string-decoder', 0.45 + Math.min(0.45, sites / 30), [`reads characters in a loop and builds text${sites ? `; called with constant arguments at ${sites} sites` : ''}`]);
  }
  if (f.env >= 2 || (f.env && ctx.envNames.has(entry.func))) add('env-manipulation', 0.6, ['reads or replaces the function environment (getfenv/setfenv/_ENV/metatables)']);
  if (f.anti.length) add('anti-analysis', 0.5 + Math.min(0.4, f.anti.length * 0.1), [`uses ${[...new Set(f.anti)].join(', ')}`]);
  if (!ctx.interpreters.has(entry.func) && f.closures && f.vararg !== undefined && ctx.callsInterpreter.has(entry.func)) add('vm-closure-factory', 0.6, ['returns a function that re-enters the interpreter with its arguments']);
  return out;
}

// ---- encoded regions ------------------------------------------------------------------------------------------------------------------

function charset(v) {
  if (/^[0-9a-fA-F]+$/.test(v) && v.length % 2 === 0) return 'hex';
  if (/^[A-Za-z0-9+/]+={0,2}$/.test(v) && v.length % 4 === 0) return 'base64';
  if (/^[\d]+([,;|. ]\d+)+$/.test(v)) return 'number list';
  // eslint-disable-next-line no-control-regex
  if (/[\x00-\x08\x0e-\x1f\x7f-\xff]/.test(v)) return 'binary';
  if (/^[\x21-\x7e]+$/.test(v)) return 'printable, no spaces (a custom alphabet)';
  return 'text';
}

function regions(ast, source, byNode) {
  const out = [];
  const consumers = new Map();
  // the function that receives a literal: as an argument of a call to a named function, or through one local
  const env = new Map();
  walk(ast, (n) => { if (n.type === 'Local') n.ids.forEach((id, i) => { if (n.values[i]) env.set(n.values[i], id.name); }); });
  walk(ast, (n) => {
    if (n.type !== 'Call') return;
    const callee = calleeName(n.fn) || (n.fn.type === 'Func' ? '(inline function)' : '');
    for (const a of n.args) consumers.set(unparen(a), callee);
  });
  const readers = new Map();
  walk(ast, (n) => {
    if (n.type !== 'Call') return;
    const callee = calleeName(n.fn);
    for (const a of n.args) { const x = unparen(a); if (x && x.type === 'Name') { if (!readers.has(x.name)) readers.set(x.name, new Set()); readers.get(x.name).add(callee); } }
  });
  const total = source.length || 1;
  let curLine = null;
  walk(ast, (n) => {
    if (n.line) curLine = n.line;
    if (n.type === 'String' && n.value.length >= 64) {
      const e = entropy(n.value);
      if (e.bits < 4.2 && charset(n.value) === 'text') return;   // prose and code, not data
      const local = env.get(n);
      const consumer = consumers.get(n) || (local && readers.has(local) ? [...readers.get(local)].filter(Boolean).join(', ') : null);
      out.push({ kind: 'string', line: lineOf(n) || curLine, bytes: n.value.length, share: +(n.value.length / total).toFixed(3), charset: charset(n.value), bitsPerChar: +e.bits.toFixed(2), alphabet: e.alphabet, local: local || null, consumer: consumer || null });
    } else if (n.type === 'Table' && n.fields.length >= 32 && n.fields.every((f) => f.kind === 'item' && ['Number', 'String'].includes(unparen(f.value).type))) {
      const nums = n.fields.filter((f) => unparen(f.value).type === 'Number').length;
      const local = env.get(n);
      out.push({ kind: nums === n.fields.length ? 'number array' : 'constant array', line: lineOf(n) || curLine, items: n.fields.length, share: null, local: local || null, consumer: consumers.get(n) || (local && readers.has(local) ? [...readers.get(local)].filter(Boolean).join(', ') : null) });
      return false;
    }
    return undefined;
  });
  out.sort((a, b) => (b.bytes || b.items || 0) - (a.bytes || a.items || 0));
  return out.slice(0, 24);
}

// ---- stage boundaries ------------------------------------------------------------------------------------------------------------------

function stages(ast, fnsByName, interpreterNames) {
  const out = [];
  walk(ast, (n) => {
    if (n.type !== 'Call') return;
    let c = calleeName(n.fn);
    // `(loadstring or load)(text)`
    const fx = unparen(n.fn);
    if (!c && fx && fx.type === 'Binary' && fx.op === 'or' && [unparen(fx.left), unparen(fx.right)].some((x) => x.type === 'Name' && /^(loadstring|load)$/.test(x.name))) c = 'loadstring';
    if (/^(loadstring|load)$/.test(c) && n.args[0]) {
      const a = unparen(n.args[0]);
      const what = a.type === 'String' ? 'a constant text' : a.type === 'Call' ? `the result of ${calleeName(a.fn) || 'a call'}(…)` : a.type === 'Name' ? `the value of \`${a.name}\`` : 'a computed text';
      out.push({ kind: 'runtime-compile', line: lineOf(n), statement: `${c}(${what})`, input: a.type === 'Call' ? calleeName(a.fn) : null });
    } else if (interpreterNames.has(c)) {
      const prev = out.find((x) => x.kind === 'vm-entry' && x.callee === c);
      if (prev) prev.sites++;
      else out.push({ kind: 'vm-entry', line: lineOf(n), callee: c, sites: 1, statement: `${c}(…) enters the interpreter` });
    }
  });
  for (const x of out) if (x.kind === 'vm-entry' && x.sites > 1) x.statement = `${x.callee}(…) enters the interpreter (${x.sites} call sites: one per function the VM runs)`;
  const body = ast.body || [];
  const last = body[body.length - 1];
  if (body.length <= 3 && last && (last.type === 'Return' || last.type === 'CallStmt')) {
    const call = last.type === 'Return' ? unparen(last.values[0]) : last.call;
    if (call && call.type === 'Call' && unparen(call.fn).type === 'Func') out.push({ kind: 'wrapper', line: lineOf(last), statement: 'the program is a function called at once' });
  }
  return out;
}

// ---- VM anatomy ------------------------------------------------------------------------------------------------------------------------

function vmAnatomy(ast, finding) {
  if (!finding) return null;
  const loops = loopsWithDispatch(ast).sort((a, b) => b.tests - a.tests);
  const d = loops[0];
  if (!d) return null;
  const body = d.loop.body;
  const a = { dispatchVariable: d.variable, tests: d.tests, depth: d.depth, handlers: finding.handlers, shape: finding.shape, profile: finding.profile, line: lineOf(d.loop) };
  // instruction fetch: `local inst = code[pc]` then fields `inst[1]`, `inst.A`; or a packed number taken apart with % / floor(/) / bit32
  const fieldKeys = new Map();
  const bitWidths = new Set();
  let packed = 0;
  walk(body, (n) => {
    if (n.type === 'Index' && unparen(n.obj).type === 'Name') {
      const k = unparen(n.key);
      if (k.type === 'Number' && k.value >= 1 && k.value <= 8) fieldKeys.set(`[${k.value}]`, (fieldKeys.get(`[${k.value}]`) || 0) + 1);
      if (k.type === 'String' && /^[A-Za-z]{1,3}$/.test(k.value)) fieldKeys.set(`.${k.value}`, (fieldKeys.get(`.${k.value}`) || 0) + 1);
    }
    if (n.type === 'Binary' && n.op === '%') { const r = unparen(n.right); if (r && r.type === 'Binary' && r.op === '^' && unparen(r.left).type === 'Number' && unparen(r.left).value === 2 && unparen(r.right).type === 'Number') { packed++; bitWidths.add(unparen(r.right).value); } }
    if (n.type === 'Call' && /bit32?\.(rshift|band|extract)$/.test(calleeName(n.fn))) { packed++; const w = n.args.map(unparen).find((x) => x.type === 'Number'); if (w && /extract/.test(calleeName(n.fn)) && n.args[2]) { const z = unparen(n.args[2]); if (z.type === 'Number') bitWidths.add(z.value); } }
    return undefined;
  });
  const fields = [...fieldKeys].filter(([, c]) => c >= 3).sort((x, y) => y[1] - x[1]).map(([k]) => k);
  a.instructionEncoding = packed >= 4 ? { kind: 'packed numbers', note: `operands taken apart with modulo / shifts${bitWidths.size ? `; field widths ${[...bitWidths].sort((x, y) => x - y).join(', ')} bits` : ''}` }
    : fields.length ? { kind: 'tables', note: `operands read as ${fields.slice(0, 6).join(', ')}` } : { kind: 'not determined', note: 'no instruction fetch was recognised' };
  // register vs stack: a table indexed by operand fields and written, vs a top-of-stack counter moved by ±1 around writes
  let regWrites = 0;
  let stackMoves = 0;
  walk(body, (n) => {
    if (n.type === 'Assign') {
      for (const t of n.targets) {
        if (t.type === 'Index' && unparen(t.key).type === 'Index') regWrites++;
        if (t.type === 'Name') { const v = unparen(n.values[0]); if (v && v.type === 'Binary' && ['+', '-'].includes(v.op) && unparen(v.left).type === 'Name' && unparen(v.left).name === t.name && unparen(v.right).type === 'Number' && unparen(v.right).value === 1 && t.name !== d.variable) stackMoves++; }
      }
    }
    return undefined;
  });
  a.machine = regWrites >= 3 && regWrites >= stackMoves ? 'register machine (registers indexed by instruction operands)' : stackMoves >= 6 ? 'stack machine (a top-of-stack counter moves by one)' : 'not determined';
  const p = finding.profile || {};
  a.features = [p.closure ? 'creates closures in handlers' : null, p.vararg ? 'handles varargs' : null, p.jump ? 'jumps by writing the instruction counter' : null, p.call ? 'calls' : null, p['return'] ? 'returns' : null].filter(Boolean);
  return a;
}

// ---- the analysis -----------------------------------------------------------------------------------------------------------------------

/**
 * @param {string} source binary string
 * @param {{ rules?: object, test?: (hyp) => object }} [options] rules: learned-rules data; test: hypothesis tests (see testHypotheses)
 */
export function anatomy(source, options = {}) {
  let ast;
  try { ast = parse(source); } catch (e) { return { ok: false, error: e.message }; }
  const { fns, byNode } = inventory(ast);
  // interpreters: the functions that contain a dispatch loop
  const interpreters = new Map();
  for (const d of loopsWithDispatch(ast)) {
    // the function whose own code holds the dispatch chain (walk visits outer functions first, so the last match is the innermost)
    let owner = null;
    walk(ast, (n) => { if (n.type === 'Func' && n.body && containsNode(n.body, d.chain)) owner = n; return undefined; });
    if (owner && d.tests >= 12) { const cur = interpreters.get(owner); if (!cur || d.tests > cur.tests) interpreters.set(owner, d); }
  }
  const interpreterNames = new Set([...interpreters.keys()].map((f) => byNode.get(f) && byNode.get(f).name).filter(Boolean));
  const callsInterpreter = new Set();
  for (const e of fns) { let hit = false; ownWalk(e.func.body, (n) => { if (n.type === 'Call' && interpreterNames.has(calleeName(n.fn))) hit = true; return hit ? false : undefined; }); if (hit) callsInterpreter.add(e.func); }
  // call sites with constant arguments, per function name
  const constSites = new Map();
  walk(ast, (n) => { if (n.type === 'Call' && unparen(n.fn).type === 'Name' && n.args.length && n.args.every((x) => ['String', 'Number'].includes(unparen(x).type))) constSites.set(unparen(n.fn).name, (constSites.get(unparen(n.fn).name) || 0) + 1); });
  const envNames = new Set();
  const ctx = { constSites, interpreters, callsInterpreter, envNames };
  // locals holding an alphabet (distinct characters, 32..128 of them): a base-N decoder may read it as an upvalue
  const alphabets = new Map();
  walk(ast, (n) => { if (n.type === 'Local') n.ids.forEach((id, i) => { const v = unparen(n.values[i]); if (v && v.type === 'String' && v.value.length >= 32 && v.value.length <= 128 && new Set(v.value).size === v.value.length) alphabets.set(id.name, { length: v.value.length, sample: v.value.slice(0, 12) }); }); return undefined; });
  const functions = [];
  for (const e of fns) {
    const f = features(e.func, alphabets);
    const rs = roles(e, f, ctx);
    if (!rs.length) continue;
    const fp = fingerprint(e.func);
    const learned = options.rules ? matchRules(fp, options.rules) : null;
    functions.push({ id: e.id, name: e.name, line: e.line, size: f.size, params: e.params, roles: rs, fingerprint: fp.hash, learned, constSites: e.name ? constSites.get(e.name) || 0 : 0 });
  }
  const regionsFound = regions(ast, source, byNode);
  const st = stages(ast, fns, interpreterNames);
  const { vm: finding } = interpreterFinding(ast);
  const vm = vmAnatomy(ast, finding);
  const hyps = hypotheses({ functions, regions: regionsFound, stages: st, vm });
  const encodedBytes = regionsFound.filter((r) => r.kind === 'string').reduce((a, r) => a + r.bytes, 0);
  return {
    ok: true,
    summary: {
      functions: fns.length,
      withRoles: functions.length,
      encodedShare: +(encodedBytes / (source.length || 1)).toFixed(3),
      architecture: vm ? 'virtual machine' : st.some((s) => s.kind === 'runtime-compile') ? 'runtime-generated code' : functions.some((f) => f.roles.some((r) => /decoder|cipher|decompressor/.test(r.role))) ? 'conventional Lua with decoded constants' : 'conventional Lua',
    },
    functions, regions: regionsFound, stages: st, vm, hypotheses: hyps,
  };
}

function containsNode(root, target) {
  let hit = false;
  walk(root, (n) => { if (hit) return false; if (n === target) { hit = true; return false; } return undefined; });
  return hit;
}

function hypotheses({ functions, regions: rg, stages: st, vm }) {
  const out = [];
  const add = (id, statement, confidence, evidence, extra = {}) => out.push({ id, statement, confidence: +Math.min(0.97, confidence).toFixed(2), evidence: evidence.filter(Boolean), test: { status: 'not-run' }, ...extra });
  for (const f of functions) {
    for (const r of f.roles) {
      const learnedNote = f.learned && f.learned.exact ? `matches a learned rule (${f.learned.exact.role}, confirmed on ${f.learned.exact.confirmed} sample${f.learned.exact.confirmed === 1 ? '' : 's'})` : f.learned && f.learned.near ? `resembles a learned rule (${f.learned.near.role}, similarity ${f.learned.near.similarity}); not treated as the same format` : null;
      const boost = f.learned && f.learned.exact && f.learned.exact.role === r.role ? 0.1 : 0;
      add(`fn${f.id}:${r.role}`, `\`${f.name || `function at line ${f.line}`}\` is ${/^[aeiou]/i.test(r.label) ? 'an' : 'a'} ${r.label}`, r.confidence + boost, [...r.evidence, learnedNote], { function: f.name, role: r.role, line: f.line });
    }
  }
  for (const r of rg.slice(0, 6)) {
    add(`region@${r.line}`, `the ${r.kind === 'string' ? `${r.bytes}-byte ${r.charset} string` : `${r.items}-item ${r.kind}`} at line ${r.line} is encoded data${r.consumer ? ` consumed by \`${r.consumer}\`` : ''}`,
      Math.min(0.95, 0.45 + (r.consumer ? 0.2 : 0) + (r.kind !== 'string' || r.bitsPerChar >= 5 || ['hex', 'base64', 'binary'].includes(r.charset) ? 0.2 : 0) + ((r.bytes || 0) > 1000 || (r.items || 0) > 100 ? 0.1 : 0)), [r.kind === 'string' ? `${r.bitsPerChar} bits per character over ${r.alphabet} symbols` : null, r.consumer ? `passed to ${r.consumer}` : 'its consumer was not traced'], { region: r.line, consumer: r.consumer });
  }
  for (const s of st) add(`stage@${s.line}:${s.kind}`, `line ${s.line}: ${s.statement}`, s.kind === 'runtime-compile' ? 0.9 : s.kind === 'vm-entry' ? 0.8 : 0.7, [s.kind === 'runtime-compile' ? 'code is compiled from text at run time: a stage boundary' : s.kind === 'vm-entry' ? 'the interpreter is entered here' : 'a wrapper around the program'], { stage: s.kind, line: s.line });
  if (vm) add('vm', `the program is run by ${vm.machine === 'not determined' ? 'an interpreter' : `a ${vm.machine.split(' (')[0]}`}${vm.handlers ? ` with ${vm.handlers} distinct handlers` : ''} (instructions: ${vm.instructionEncoding.kind})`, 0.6 + Math.min(0.3, vm.handlers / 150), [`dispatch on \`${vm.dispatchVariable}\` (${vm.shape}, ${vm.tests} tests)`, vm.instructionEncoding.note, vm.features.join(', ') || null], { vm: true });
  return out;
}

/**
 * Test the hypotheses that can be tested. `deps.evaluate(ast)` runs the evaluator on a fresh tree and returns its decoders;
 * `deps.readers(source)` tries the known VM readers; `deps.layers` says whether a layer was unwrapped. Each hypothesis keeps its own result.
 */
export function testHypotheses(report, source, deps) {
  if (!report.ok) return report;
  let evalResult = null;
  const needsEval = report.hypotheses.some((h) => ['string-decoder', 'xor-cipher', 'base-n-decoder', 'lzw-decompressor'].includes(h.role));
  const callCounts = (ast) => { const m = new Map(); walk(ast, (n) => { if (n.type === 'Call' && unparen(n.fn).type === 'Name') m.set(unparen(n.fn).name, (m.get(unparen(n.fn).name) || 0) + 1); return undefined; }); return m; };
  let before = null;
  let after = null;
  if (needsEval && deps.evaluate) {
    try {
      const ast = parse(source);
      before = callCounts(parse(source));
      evalResult = deps.evaluate(ast);
      after = callCounts(ast);
    } catch (e) { evalResult = { error: String(e.message || e) }; }
  }
  let readers = null;
  if (report.vm && deps.readers) { try { readers = deps.readers(source); } catch { readers = null; } }
  for (const h of report.hypotheses) {
    if (['string-decoder', 'xor-cipher', 'base-n-decoder', 'lzw-decompressor'].includes(h.role)) {
      // a decoder whose result is compiled at run time is confirmed when that layer was unwrapped
      const feedsLayer = report.stages.some((st) => st.kind === 'runtime-compile' && st.input === h.function);
      if (feedsLayer && deps.layersApplied) { h.test = { status: 'confirmed', method: 'layer unwrapping', detail: `its output is compiled at run time, and that layer was unwrapped by the pipeline` }; h.confidence = +Math.min(0.99, h.confidence + 0.1).toFixed(2); continue; }
      if (!evalResult) { h.test = { status: 'not-run', method: 'evaluator', detail: 'the sandbox is off' }; continue; }
      if (evalResult.error || evalResult.skipped) { h.test = { status: 'inconclusive', method: 'evaluator', detail: evalResult.error || `the evaluator skipped: ${evalResult.skipped}` }; continue; }
      // confirmed only by call sites that were actually replaced by their values (a site the evaluator rejected does not count)
      const resolved = before && after ? (before.get(h.function) || 0) - (after.get(h.function) || 0) : 0;
      const d = resolved > 0 ? { sites: resolved } : null;
      h.test = d ? { status: 'confirmed', method: 'evaluator', detail: `ran on the decoder's slice in the sandbox: ${d.sites} call site${d.sites === 1 ? '' : 's'} resolved to constants` }
        : { status: 'refuted', method: 'evaluator', detail: 'the evaluator did not resolve any call of this function (not a pure decoder, or its arguments are not constant)' };
      if (h.test.status === 'confirmed') h.confidence = +Math.min(0.99, h.confidence + 0.2).toFixed(2);
      else h.confidence = +Math.max(0.1, h.confidence - 0.25).toFixed(2);
    } else if (h.vm) {
      const ok = readers && readers.find((r) => r.ok);
      // the interpreter functions share the VM's verdict: a reader that reads the program confirms the interpreter it runs on
      if (ok) for (const x of report.hypotheses) if (x.role === 'interpreter') x.test = { status: 'confirmed', method: 'VM readers', detail: `its VM was read by ${ok.reader}` };
      h.test = readers ? (ok ? { status: 'confirmed', method: 'VM readers', detail: `read by ${ok.reader}` } : { status: 'inconclusive', method: 'VM readers', detail: `no known VM reader accepts it (${readers.length} tried); the anatomy above is what is established` }) : { status: 'not-run' };
    } else if (h.region != null) {
      const decoders = report.hypotheses.filter((x) => x.test.status === 'confirmed' && x.function && h.consumer && h.consumer.split(', ').includes(x.function));
      if (decoders.length) h.test = { status: 'confirmed', method: 'consumer', detail: `its consumer \`${decoders[0].function}\` was confirmed as a decoder` };
      else if (deps.layersApplied && h.consumer) h.test = { status: 'confirmed', method: 'layer unwrapping', detail: 'the layer it feeds was unwrapped by the pipeline' };
    } else if (h.stage === 'runtime-compile' && deps.layersApplied != null) {
      h.test = deps.layersApplied ? { status: 'confirmed', method: 'layer unwrapping', detail: 'the layer was unwrapped by the pipeline' } : { status: 'inconclusive', method: 'layer unwrapping', detail: 'the layer was not unwrapped (its text is computed by code the sandbox would have to run, or the sandbox is off)' };
    }
  }
  return report;
}
