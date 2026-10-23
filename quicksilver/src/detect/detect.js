// Obfuscator and dialect detection.
//
// Rules come in three kinds, and the kind decides how much weight they can carry:
//   banner     a header string the tool is known (from public material) to leave in its output
//   structure  an AST pattern that the tool's own source code is known to generate
//   heuristic  a statistical or generic indicator that merely suggests a style
//
// A family's confidence is the noisy-OR of its rule weights, capped by what is actually known about the
// family (detect/families.js): a tool whose source was never read cannot be reported with near certainty
// from structure alone.

import { parse, LuaSyntaxError } from '../core/parser.js';
import { analyze } from '../core/scope.js';
import { walk } from '../core/walk.js';
import { looksObfuscated, isShortName } from '../passes/rename.js';
import { FAMILIES, TRAITS } from './families.js';
import { detectDialect } from './dialect.js';

// ---- facts -----------------------------------------------------------------------------------------

const calleePath = (e) => {
  if (e.type === 'Name') return e.name;
  if (e.type === 'Index' && e.key.type === 'String') { const o = calleePath(e.obj); return o ? `${o}.${e.key.value}` : null; }
  return null;
};

/** Depth of nested `if v <op> N` chains testing one variable against numbers (a binary-search dispatcher). */
function dispatchDepth(stmt, varName) {
  if (stmt.type !== 'If') return 0;
  const test = (c) => c.type === 'Binary' && ['<', '>', '<=', '>=', '=='].includes(c.op)
    && ((c.left.type === 'Name' && c.left.name === varName && c.right.type === 'Number')
      || (c.right.type === 'Name' && c.right.name === varName && c.left.type === 'Number'));
  if (!test(stmt.clauses[0].cond)) return 0;
  let best = 0;
  for (const c of stmt.clauses) for (const s of c.body) best = Math.max(best, dispatchDepth(s, varName));
  if (stmt.orelse) for (const s of stmt.orelse) best = Math.max(best, dispatchDepth(s, varName));
  return best + 1;
}

const isConstArith = (e) => {
  switch (e.type) {
    case 'Number': return true;
    case 'Paren': return isConstArith(e.expr);
    case 'Unary': return (e.op === '-' || e.op === 'not') && isConstArith(e.arg);
    case 'Binary': return ['+', '-', '*', '/', '%', '==', '~=', '<', '<=', '>', '>='].includes(e.op) && isConstArith(e.left) && isConstArith(e.right);
    default: return false;
  }
};

function collectFacts(ast, src) {
  const info = analyze(ast);
  const f = {
    numbers: new Set(),
    strings: [],
    calls: new Map(),
    junkLocals: 0,
    opaqueConditions: 0,
    dispatchers: 0,
    maxDispatchDepth: 0,
    wrapperCalls: 0,
    metaProxies: 0,
    rotateLoops: 0,
    names: info.vars.map((v) => v.name),
    globals: new Set(info.globals.keys()),
    nodeCount: 0,
    antiTamperBlocks: 0,
    splitHelpers: 0,
    localAliasBlock: 0,
    maxFuncParams: 0,
  };
  walk(ast, (n) => {
    f.nodeCount++;
    switch (n.type) {
      case 'Number': f.numbers.add(n.value); break;
      case 'String': f.strings.push(n.value); break;
      case 'Call': {
        const p = calleePath(n.fn);
        if (p) f.calls.set(p, (f.calls.get(p) || 0) + 1);
        // setmetatable({ X = v }, { __add = ..., __index = ... }) : Prometheus ProxifyLocals
        if (n.args.length === 2 && n.args[0].type === 'Table' && n.args[0].fields.length === 1
          && n.args[1].type === 'Table' && n.args[1].fields.length >= 2
          && n.args[1].fields.every((x) => x.kind === 'named' && x.key.startsWith('__'))) f.metaProxies++;
        break;
      }
      case 'Local':
        if (n.ids.length === 1 && n.ids[0].name === '_' && n.values.length === 1 && n.values[0].type === 'Number') f.junkLocals++;
        break;
      case 'If': case 'While':
        if (n.type === 'If' ? n.clauses.some((c) => isConstArith(c.cond) && c.cond.type !== 'Number') : (isConstArith(n.cond) && n.cond.type !== 'Number')) f.opaqueConditions++;
        break;
      case 'GenFor':
        // ipairs({{1, N}, {1, K}, {K + 1, N}}) feeding a swap loop: Prometheus ConstantArray rotation
        if (n.exprs.length === 1 && n.exprs[0].type === 'Call' && calleePath(n.exprs[0].fn) === 'ipairs'
          && n.exprs[0].args[0] && n.exprs[0].args[0].type === 'Table'
          && n.exprs[0].args[0].fields.length >= 2 && n.exprs[0].args[0].fields.every((x) => x.value.type === 'Table' && x.value.fields.length === 2)
          && n.body.some((s) => s.type === 'While')) f.rotateLoops++;
        break;
      case 'Func': f.maxFuncParams = Math.max(f.maxFuncParams, n.params.length); break;
      default: break;
    }
    if (n.type === 'While' && n.cond.type === 'Name') {
      const d = n.body.reduce((m, s) => Math.max(m, dispatchDepth(s, n.cond.name)), 0);
      if (d >= 3) { f.dispatchers++; f.maxDispatchDepth = Math.max(f.maxDispatchDepth, d); }
    }
    return undefined;
  });

  // `return (function(sel, env, ...) ... end)(select, getfenv and getfenv() or _ENV, ...)`, possibly nested
  // inside a WrapInFunction wrapper, hence the full walk.
  walk(ast, (n) => {
    if (n.type !== 'Return' || n.values.length !== 1) return;
    const call = n.values[0];
    if (call.type !== 'Call' || call.fn.type !== 'Paren' || call.fn.expr.type !== 'Func') return;
    const names = call.args.map((a) => (a.type === 'Name' ? a.name : a.type === 'Binary' ? a.op : a.type === 'Table' ? '{}' : '?')).join(',');
    if (call.args.length >= 7 && names.includes('select') && names.includes('getmetatable') && names.includes('setmetatable') && names.includes('newproxy')) f.wrapperCalls++;
  });

  // Prometheus SplitStrings helper: function(t) local L, g = t[#t], "" for i = 1, #L do g = g .. L[t[i]] end return g end
  walk(ast, (n) => {
    if (n.type !== 'Func' || n.params.length !== 1 || n.body.length !== 3) return;
    const [decl, loop, ret] = n.body;
    if (decl.type !== 'Local' || decl.ids.length !== 2 || decl.values.length !== 2) return;
    if (decl.values[1].type !== 'String' || decl.values[1].value !== '') return;
    if (loop.type !== 'NumFor' || ret.type !== 'Return') return;
    f.splitHelpers++;
  });

  const prelude = ast.body.slice(0, 6);
  for (const s of prelude) {
    if (s.type === 'Local' && s.values.length >= 4 && s.values.every((v) => v.type === 'Index' || v.type === 'Name')) f.localAliasBlock++;
  }

  // Prometheus AntiTamper: do local X = "..." for i = 0, N do ... "Tamper Detected!" ... end
  walk(ast, (n) => {
    if (n.type !== 'Do' || n.body.length < 3) return;
    const first = n.body[0];
    if (first.type !== 'Local' || first.values.length !== 1 || first.values[0].type !== 'String') return;
    if (!n.body.slice(1, 3).some((s) => s.type === 'NumFor')) return;
    let tamper = false;
    walk(n, (m) => { if (m.type === 'String' && m.value === 'Tamper Detected!') tamper = true; });
    if (tamper) f.antiTamperBlocks++;
  });

  // textual statistics
  const lines = src.split('\n');
  f.lineCount = lines.length;
  f.maxLineLength = lines.reduce((m, l) => Math.max(m, l.length), 0);
  f.avgLineLength = src.length / Math.max(1, lines.length);
  f.escapeDensity = ((src.match(/\\\d{1,3}/g) || []).length * 3) / Math.max(1, src.length);
  f.longestString = f.strings.reduce((m, s) => Math.max(m, s.length), 0);
  f.commentCount = (src.match(/--/g) || []).length;
  return f;
}

// ---- rules -------------------------------------------------------------------------------------------------------

const rule = (id, kind, weight, test) => ({ id, kind, weight, test });

const RULES = {
  prometheus: [
    rule('watermark', 'banner', 0.97, (c) => c.src.includes('Part of the Prometheus Obfuscator') && 'Prometheus watermark text'),
    rule('anti-tamper', 'structure', 0.97, (c) => c.facts && c.facts.antiTamperBlocks > 0 && 'AntiTamper block (checks line numbers of error messages; message "Tamper Detected!")'),
    rule('vmify-wrapper', 'structure', 0.9, (c) => c.facts && c.facts.wrapperCalls > 0 && 'VM wrapper call: (select, getfenv and getfenv() or _ENV, getmetatable, {...}, newproxy, unpack or table.unpack, setmetatable)'),
    rule('encrypt-strings', 'structure', 0.9, (c) => c.facts && c.facts.numbers.has(35184372088832) && c.facts.numbers.has(4294967296) && 'EncryptStrings PRNG constants (2^45 modulus, 2^32 scaling)'),
    rule('constant-array', 'structure', 0.8, (c) => c.facts && c.facts.rotateLoops > 0 && 'ConstantArray rotation (ipairs over {{1,N},{1,K},{K+1,N}} with a swap loop)'),
    rule('split-strings', 'structure', 0.85, (c) => c.facts && c.facts.splitHelpers > 0 && 'SplitStrings joiner: function(t) local L, g = t[#t], "" for i = 1, #L do g = g .. L[t[i]] end return g end'),
    rule('proxify-locals', 'structure', 0.75, (c) => c.facts && c.facts.metaProxies >= 3 && `${c.facts.metaProxies} locals wrapped in metatable proxies (ProxifyLocals)`),
    rule('dispatcher', 'heuristic', 0.25, (c) => c.facts && c.facts.dispatchers > 0 && c.facts.wrapperCalls > 0 && 'binary-search dispatcher inside the VM wrapper'),
  ],
  hercules: [
    rule('watermark', 'banner', 0.97, (c) => { const m = /Obfuscated by Hercules v?([0-9][0-9.]*)/.exec(c.src); return m ? { text: `Hercules watermark (v${m[1]})`, version: m[1] } : false; }),
    rule('control-flow', 'structure', 0.9, (c) => c.facts && c.src.search(/\bthing2\b/) >= 0 && c.src.includes('counter') && /while\s+\w+\s*==\s*\w+\s+and\s+counter\s*<\s*1\s+do/.test(c.src) && 'control-flow wrapper (a loop that provably runs once, with a spoof branch)'),
    rule('function-table', 'structure', 0.85, (c) => /\["table\.concat"\]\s*=\s*table\.concat/.test(c.src) && 'anti-tamper function table ({["table.concat"]=table.concat, ...})'),
    rule('bytecode-wrapper', 'structure', 0.85, (c) => /local\s+\w+\s*,\s*\w+\s*,\s*\w+\s*=\s*"[0-9A-F]{40,}"\s*,\s*\d+\s*,\s*\{\}/.test(c.src) && 'hex + offset bytecode wrapper around load()'),
    rule('caesar-decoder', 'structure', 0.75, (c) => c.facts && c.facts.numbers.has(26) && c.facts.numbers.has(65) && c.facts.numbers.has(97) && c.facts.numbers.has(122) && c.facts.numbers.has(48) && c.facts.numbers.has(57) && /%\s*26\)?\s*\+\s*(65|97)/.test(c.src.replace(/\s+/g, ' ')) && 'Caesar-cipher string decoder (letters mod 26, digits mod 10)'),
    rule('chars-table', 'structure', 0.7, (c) => /local\s+chars\s*=\s*\{\s*\[\d+\]\s*=\s*"/.test(c.src) && 'string-to-expression table (local chars = {[104]="h", ...})'),
    rule('junk', 'structure', 0.55, (c) => c.facts && c.facts.junkLocals >= 3 && `${c.facts.junkLocals} no-effect statements of the form local _ = N`),
    rule('opaque', 'heuristic', 0.35, (c) => c.facts && c.facts.opaqueConditions >= 3 && `${c.facts.opaqueConditions} conditions made of constant arithmetic`),
  ],
  luraph: [
    rule('banner', 'banner', 0.97, (c) => { const m = /This file was (?:protected|generated) using Luraph Obfuscator v?([0-9][0-9.]*)/i.exec(c.src); return m ? { text: `Luraph banner (v${m[1]})`, version: m[1] } : false; }),
    rule('mention', 'banner', 0.5, (c) => /lura\.ph/i.test(c.src) && 'mentions lura.ph'),
  ],
  moonsec_v3: [
    rule('banner', 'banner', 0.97, (c) => { const m = /This file was protected with MoonSec V(\d)/i.exec(c.src); return m ? { text: `MoonSec banner (V${m[1]})`, version: `V${m[1]}` } : false; }),
    rule('mention', 'banner', 0.4, (c) => /MoonSec/i.test(c.src) && 'mentions MoonSec'),
  ],
  moonveil: [
    rule('banner', 'banner', 0.95, (c) => { const m = /MoonVeil Obfuscator v?([0-9][0-9.]*)/i.exec(c.src); return m ? { text: `MoonVeil banner (v${m[1]})`, version: m[1] } : false; }),
    rule('mention', 'banner', 0.5, (c) => /MoonVeil/i.test(c.src) && 'mentions MoonVeil'),
  ],
  fuscator77: [
    rule('banner', 'banner', 0.95, (c) => { const m = /77fuscator\s+v?([0-9][0-9.]*)/i.exec(c.src); return m ? { text: `77fuscator banner (${m[1]})`, version: m[1] } : false; }),
  ],
  ironbrew2: [
    rule('banner', 'banner', 0.6, (c) => /Iron\s?Brew/i.test(c.src) && 'mentions IronBrew'),
    rule('vm-shape', 'heuristic', 0.4, (c) => c.facts && c.vm.score >= 5 && 'VM-shaped script: deserializer, opcode dispatcher and encoded payload (generic; not specific to IronBrew)'),
  ],
  luaobfuscator: [
    rule('mention', 'banner', 0.6, (c) => /luaobfuscator\.com/i.test(c.src) && 'mentions luaobfuscator.com'),
  ],
  psu: [rule('mention', 'banner', 0.45, (c) => /\bPSU\b\s*(?:Obfuscat|Protect|v\d)/i.test(c.src) && 'mentions PSU obfuscation')],
  ironveil: [rule('mention', 'banner', 0.5, (c) => /Iron\s?Veil/i.test(c.src) && 'mentions IronVeil')],
  goofyscator: [rule('mention', 'banner', 0.5, (c) => /Goofyscator/i.test(c.src) && 'mentions Goofyscator')],
  clyde: [rule('mention', 'banner', 0.5, (c) => /Clyde\s*Protection/i.test(c.src) && 'mentions Clyde Protection')],
  xhider: [rule('mention', 'banner', 0.5, (c) => /X\s?Hider/i.test(c.src) && 'mentions XHider')],
  synapse_xen: [rule('mention', 'banner', 0.5, (c) => /Synapse\s*Xen/i.test(c.src) && 'mentions Synapse Xen')],
  wearedevs: [rule('mention', 'banner', 0.5, (c) => /wearedevs\.net|WeAreDevs/i.test(c.src) && 'mentions WeAreDevs')],
};

/** How VM-like is the script? Used as generic, non-family-specific evidence. */
function vmShape(facts, ast) {
  let score = 0;
  const reasons = [];
  if (!facts) return { score, reasons };
  const top = ast.body[ast.body.length - 1];
  if (top && top.type === 'Return' && top.values.length === 1 && top.values[0].type === 'Call' && top.values[0].fn.type === 'Paren' && top.values[0].fn.expr.type === 'Func') { score++; reasons.push('whole script wrapped in return (function(...) ... end)(...)'); }
  const need = ['string.byte', 'string.char', 'string.sub', 'table.concat', 'select', 'setmetatable'];
  if (need.filter((k) => facts.calls.has(k) || facts.globals.has(k.split('.')[0])).length >= 4) { score++; reasons.push('uses the deserialiser toolkit (string.byte/char/sub, table.concat, select, setmetatable)'); }
  if (facts.dispatchers > 0) { score += 2; reasons.push(`opcode/state dispatcher (nested comparison depth ${facts.maxDispatchDepth})`); }
  if (facts.longestString > 4000) { score++; reasons.push(`encoded payload string of ${facts.longestString} characters`); }
  if (facts.escapeDensity > 0.15) { score++; reasons.push('string data written as numeric escapes'); }
  return { score, reasons };
}

// ---- driver --------------------------------------------------------------------------------------------------------

/** Mentions of the PUC / LuaJIT bytecode header in the source or in a string constant. */
function bytecodeInfo(src, strings) {
  const find = (s) => {
    if (s.charCodeAt(0) !== 27) return null;
    if (s.startsWith('\x1bLua')) {
      const v = s.charCodeAt(4);
      return { format: 'PUC Lua', version: v === 0x51 ? '5.1' : v === 0x52 ? '5.2' : v === 0x53 ? '5.3' : v === 0x54 ? '5.4' : `0x${v.toString(16)}` };
    }
    if (s.startsWith('\x1bLJ')) return { format: 'LuaJIT', version: String(s.charCodeAt(3)) };
    return null;
  };
  const whole = find(src);
  if (whole) return { ...whole, wholeFile: true };
  for (const s of strings) { const b = find(s); if (b) return { ...b, wholeFile: false, size: s.length }; }
  return null;
}

/**
 * @param {string} source binary string
 * @param {object} [knownAst] an AST of `source` if the caller already has one (it is not modified)
 * @returns {object} detection report
 */
export function detect(source, knownAst = null) {
  const result = {
    parsed: false,
    parseError: null,
    dialect: null,
    families: [],
    traits: [],
    bytecode: null,
    metrics: {},
  };

  let ast = knownAst;
  let facts = null;
  if (ast) result.parsed = true;
  else {
    try {
      ast = parse(source);
      result.parsed = true;
    } catch (e) {
      if (!(e instanceof LuaSyntaxError)) throw e;
      result.parseError = { message: e.message, line: e.line, col: e.col };
    }
  }
  if (ast) facts = collectFacts(ast, source);

  const ctx = { src: source, facts, vm: vmShape(facts, ast || { body: [] }) };

  // families
  for (const [id, rules] of Object.entries(RULES)) {
    const fam = FAMILIES[id];
    const evidence = [];
    let miss = 1;
    let version = null;
    for (const r of rules) {
      let hit;
      try { hit = r.test(ctx); } catch { hit = false; }
      if (!hit) continue;
      const text = typeof hit === 'string' ? hit : hit.text;
      if (typeof hit === 'object' && hit.version) version = hit.version;
      evidence.push({ rule: r.id, kind: r.kind, text, weight: r.weight });
      miss *= 1 - r.weight;
    }
    if (!evidence.length) continue;
    const confidence = Math.min(fam.maxConfidence, 1 - miss);
    result.families.push({ id, name: fam.name, confidence, version, evidence, evidenceLevel: fam.evidence });
  }
  result.families.sort((a, b) => b.confidence - a.confidence);

  // generic traits
  const traits = new Set();
  if (facts) {
    if (facts.avgLineLength > 300 || (facts.lineCount < 5 && source.length > 400)) traits.add('minified');
    const mangled = facts.names.filter((n) => looksObfuscated(n) || isShortName(n)).length;
    result.metrics.mangledRatio = facts.names.length ? mangled / facts.names.length : 0;
    if (facts.names.length >= 8 && result.metrics.mangledRatio > 0.6) traits.add('mangled-names');
    if (facts.escapeDensity > 0.2) traits.add('escape-encoded-strings');
    if ((facts.calls.get('loadstring') || 0) + (facts.calls.get('load') || 0) > 0) traits.add('loadstring-layer');
    if (facts.dispatchers > 0) traits.add('state-machine');
    if (facts.rotateLoops > 0) traits.add('string-table');
    if (facts.opaqueConditions >= 3) traits.add('opaque-predicates');
    if (facts.junkLocals >= 3) traits.add('junk-code');
    result.dialect = detectDialect(ast.features, facts.globals, source);
    result.metrics.nodes = facts.nodeCount;
    result.metrics.lines = facts.lineCount;
    result.metrics.longestString = facts.longestString;
    result.metrics.vm = ctx.vm;
  } else {
    result.dialect = detectDialect(new Set(), new Set(), source);
    if (source.length / Math.max(1, source.split('\n').length) > 300) traits.add('minified');
  }
  const strings = facts ? facts.strings : [];
  const bc = bytecodeInfo(source, strings);
  if (bc) { result.bytecode = bc; traits.add('bytecode-blob'); }
  result.traits = [...traits].map((id) => ({ id, text: TRAITS[id] }));
  result.metrics.bytes = source.length;
  return result;
}
