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

import { classify } from './classify.js';
import { parse, LuaSyntaxError } from '../core/parser.js';
import { analyze } from '../core/scope.js';
import { walk } from '../core/walk.js';
import { looksObfuscated, isShortName } from '../passes/rename.js';
import { FAMILIES, TRAITS } from './families.js';
import { detectDialect } from './dialect.js';
import { isColisseumGuard } from '../recover/colisseum.js';
import { moonveilShape } from '../recover/moonveil.js';
import { findCharListLoader } from '../passes/charlist.js';

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
    colisseumNames: 0,
    vmRunCalls: 0,
    kirusEntries: 0,
    snowGetter: 0,
    z85Blob: 0,
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
      case 'MethodCall': {
        // setmetatable({ ... }, {}):name(bit32, string, table, math, type, error, pcall, getfenv or ..., setfenv or ..., tonumber): the entry of Kirus' VM
        if (n.args.length === 10 && n.obj.type === 'Call' && n.obj.fn.type === 'Name' && n.obj.fn.name === 'setmetatable'
          && ['bit32', 'string', 'table', 'math', 'type', 'error', 'pcall'].every((g, i) => n.args[i].type === 'Name' && n.args[i].name === g)
          && n.args[7].type === 'Binary' && n.args[8].type === 'Binary' && n.args[9].type === 'Name' && n.args[9].name === 'tonumber') f.kirusEntries++;
        break;
      }
      case 'Call': {
        // SnowVeil's builtin getter: `local au = function(lib, member) ... end` called as au("string", "char"), au("Vector3", "new"), au("bit32", "bxor"): one local
        // function asked for library members by name, so that no builtin is written as `string.char` in the script
        if (n.fn.type === 'Name' && n.args.length === 2 && n.args[0].type === 'String' && n.args[1].type === 'String'
          && ['string', 'table', 'math', 'bit32', 'Vector3', 'CFrame'].includes(n.args[0].value)) {
          if (!f.snowGetters) f.snowGetters = new Map();
          const set = f.snowGetters.get(n.fn.name) || new Set();
          set.add(n.args[0].value);
          f.snowGetters.set(n.fn.name, set);
          f.snowGetter = Math.max(f.snowGetter, set.size);
        }
        const p = calleePath(n.fn);
        if (p) f.calls.set(p, (f.calls.get(p) || 0) + 1);
        // setmetatable({ X = v }, { __add = ..., __index = ... }) : Prometheus ProxifyLocals
        if (n.args.length === 2 && n.args[0].type === 'Table' && n.args[0].fields.length === 1
          && n.args[1].type === 'Table' && n.args[1].fields.length >= 2
          && n.args[1].fields.every((x) => x.kind === 'named' && x.key.startsWith('__'))) f.metaProxies++;
        // X.run(proto, { environment = E, anchor = A, ... }): the entry call of Colisseum's two VM presets
        if (n.args.length >= 2) {
          const last = n.args[n.args.length - 1];
          if (last.type === 'Table' && ['environment', 'anchor'].every((k) => last.fields.some((x) => x.kind === 'named' && x.key === k))) f.vmRunCalls++;
        }
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

  f.z85Blob = f.strings.reduce((m, x) => (x.length > 5000 && /^[0-9A-Za-z!#$%&()*+\-;<=>?@^_`{|}~]+$/.test(x) ? Math.max(m, x.length) : m), 0);
  f.colisseumNames = f.names.filter((x) => /^coli_[jLl]{3,}$/.test(x) || /^coli_\w{4,}$/.test(x)).length;

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

/** `unrecoverable`: if this still matches after recovery, the program has not been recovered (VM, bytecode). */
const rule = (id, kind, weight, test, unrecoverable = false) => ({ id, kind, weight, test, unrecoverable });

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
    rule('bytecode-wrapper', 'structure', 0.85, (c) => /local\s+\w+\s*,\s*\w+\s*,\s*\w+\s*=\s*"[0-9A-F]{40,}"\s*,\s*\d+\s*,\s*\{\}/.test(c.src) && 'hex + offset bytecode wrapper around load()', true),
    rule('vm-protected', 'structure', 0.95, (c) => c.facts && c.facts.strings.some((x) => x.startsWith('Protected By Hercules')) && 'Hercules virtual machine: a Lua bytecode interpreter with the program embedded as bytecode', true),
    rule('caesar-decoder', 'structure', 0.75, (c) => c.facts && c.facts.numbers.has(26) && c.facts.numbers.has(65) && c.facts.numbers.has(97) && c.facts.numbers.has(122) && c.facts.numbers.has(48) && c.facts.numbers.has(57) && /%\s*26\)?\s*\+\s*(65|97)/.test(c.src.replace(/\s+/g, ' ')) && 'Caesar-cipher string decoder (letters mod 26, digits mod 10)'),
    rule('chars-table', 'structure', 0.7, (c) => /local\s+chars\s*=\s*\{\s*\[\d+\]\s*=\s*"/.test(c.src) && 'string-to-expression table (local chars = {[104]="h", ...})'),
    rule('junk', 'structure', 0.55, (c) => c.facts && c.facts.junkLocals >= 3 && `${c.facts.junkLocals} no-effect statements of the form local _ = N`),
    rule('opaque', 'heuristic', 0.35, (c) => c.facts && c.facts.opaqueConditions >= 3 && `${c.facts.opaqueConditions} conditions made of constant arithmetic`),
  ],
  luraph: [
    rule('banner', 'banner', 0.97, (c) => { const m = /This file was (?:protected|generated) using Luraph Obfuscator v?([0-9][0-9.]*)/i.exec(c.src); return m ? { text: `Luraph banner (v${m[1]})`, version: m[1] } : false; }),
    rule('mention', 'banner', 0.5, (c) => /lura\.ph/i.test(c.src) && 'mentions lura.ph'),
    // the macro names Luraph defines for its own build flags (read on files of the public collection that carry no banner)
    rule('macros', 'structure', 0.85, (c) => /\bLPH_(?:NO_VIRTUALIZE|OBFUSCATED|JIT|ENCSTR|CRASH|NO_UPVALUES|SKIP)\b/.test(c.src) && 'the build-flag macros Luraph defines (LPH_NO_VIRTUALIZE, LPH_OBFUSCATED, ...)'),
    // the shape of a Luraph 14.x script without its banner: one `return({ name = function(...) ... })` table of VM handlers, and number literals spelled with capital 0X / 0B prefixes and underscores
    rule('handler-table', 'structure', 0.8, (c) => c.src.length > 20000 && /^(?:\s*--[^\n]*\n|\s)*return\s*\(\s*\{\s*[A-Za-z_][A-Za-z0-9_]{0,3}\s*=/.test(c.src.slice(0, 600)) && (c.src.slice(0, 40000).match(/\b0[XB][0-9A-Fa-f_]+/g) || []).length >= 20 && 'a returned table of short-named handler functions with number literals spelled 0X.. / 0B.. (the shape of a Luraph 14.x VM)', true),
  ],
  moonsec_v3: [
    rule('banner', 'banner', 0.97, (c) => { const m = /This file was protected with MoonSec V(\d)/i.exec(c.src); return m ? { text: `MoonSec banner (V${m[1]}): a VM loader (all 24 scripts of the public collection were)`, version: `V${m[1]}` } : false; }, true),
    rule('mention', 'banner', 0.4, (c) => /MoonSec/i.test(c.src) && 'mentions MoonSec'),
  ],
  moonveil: [
    rule('banner', 'banner', 0.97, (c) => { const m = /(?:MoonVeil Obfuscator v?|generated using MoonVeil\s+v?)([0-9][0-9.]*)/i.exec(c.src); return m ? { text: `MoonVeil banner (${m[1]})`, version: m[1] } : false; }),
    rule('mention', 'banner', 0.5, (c) => /MoonVeil/i.test(c.src) && 'mentions MoonVeil'),
    rule('table-script', 'structure', 0.9, (c) => c.ast && moonveilShape(c.ast) && 'every function lifted into one table, helpers named by a permutation list, called as ({...}):builder({ names }, entry, ...)'),
    rule('vm-blob', 'structure', 0.5, (c) => c.facts && c.facts.z85Blob > 0 && ((c.ast && moonveilShape(c.ast)) || /MoonVeil/i.test(c.src)) && `an encoded program of ${c.facts.z85Blob} characters (RFC 1924 alphabet): a function compiled to MoonVeil's VM`, true),
  ],
  fuscator77: [
    rule('banner', 'banner', 0.95, (c) => { const m = /77fuscator\s+v?([0-9][0-9.]*)/i.exec(c.src); return m ? { text: `77fuscator banner (${m[1]})`, version: m[1] } : false; }),
  ],
  ironbrew2: [
    // (FusGato prints the same watermark in front of its own credit line; that is a copy, and the credit line decides)
    rule('watermark', 'banner', 0.97, (c) => { const m = /IronBrew:tm: obfuscation; Version ([0-9][0-9.]*)/.exec(c.src); return m && !/\blocal FusGato = "discord\.gg\//.test(c.src.slice(0, 600)) ? { text: `IronBrew 2 watermark (version ${m[1]})`, version: m[1] } : false; }),
    rule('prelude', 'structure', 0.92, (c) => c.ast && isIronBrewPrelude(c.ast) && 'the eleven library locals every IronBrew 2 VM starts with (string.byte, string.char, string.sub, table.concat, table.insert, math.ldexp, getfenv, setmetatable, select, unpack, tonumber)'),
    rule('mention', 'banner', 0.3, (c) => /Iron\s?Brew/i.test(c.src) && 'mentions IronBrew'),
    rule('vm-shape', 'heuristic', 0.3, (c) => c.facts && c.vm.score >= 5 && 'VM-shaped script: deserializer, opcode dispatcher and encoded payload (generic; not specific to IronBrew)'),
  ],
  luaobfuscator: [
    rule('mention', 'banner', 0.6, (c) => /luaobfuscator\.com/i.test(c.src) && 'mentions luaobfuscator.com'),
    // the banner of the service's free tier: an ASCII-art header and the credit line (read on 24 real scripts of the public collection)
    rule('art', 'banner', 0.9, (c) => /\.____\s+________ ___\.[\s\S]{0,1200}Obfuscator\.com/.test(c.src.slice(0, 3000)) && 'the ASCII-art header of the free tier'),
    // the prelude of the service's string-XOR output: local v0=string.char; v1=string.byte; v2=string.sub; v3=bit32 or bit; ... then v4=v3.bxor, v5=table.concat, v6=table.insert
    rule('prelude', 'structure', 0.85, (c) => /^(?:--[^\n]*\n)*\s*local v0=string\.char;\s*local v1=string\.byte;\s*local v2=string\.sub;\s*local v3=bit32 or bit\s*;/.test(c.src.slice(0, 800)) && 'starts with local v0=string.char; local v1=string.byte; local v2=string.sub; local v3=bit32 or bit; (numbered names, XOR string decoder)'),
    rule('credit', 'banner', 0.95, (c) => { const m = /Obfuscator\.com\s+\(Alpha\s*([0-9][0-9.]*)\)[\s\S]{0,40}Much Love, Ferib/.exec(c.src.slice(0, 4000)); return m ? { text: `LuaObfuscator.com credit line (Alpha ${m[1]})`, version: `Alpha ${m[1]}` } : false; }),
  ],
  psu: [
    rule('mention', 'banner', 0.45, (c) => /\bPSU\b\s*(?:Obfuscat|Protect|v\d)/i.test(c.src) && 'mentions PSU obfuscation'),
    // the string every PSU 4.x script keeps as a local (found in all 11 scripts of the public collection, 4.0.A and 4.5.A)
    rule('banner', 'banner', 0.97, (c) => { const m = /obfuscated using PSU Obfuscator ([0-9][0-9.A-Za-z]*)/.exec(c.src.slice(0, 20000)); return m ? { text: `PSU banner string (${m[1]}): a VM-protected script (all 11 scripts of the public collection were)`, version: m[1] } : false; }, true),
  ],
  ironbrew1: [
    rule('header', 'banner', 0.97, (c) => /^\s*--\s*this file was generated using ironbrew1\b/i.test(c.src.slice(0, 600)) && 'IronBrew 1 header comment'),
    rule('wrapper', 'structure', 0.6, (c) => /^[^\n]*\n*return\(function\((?:[a-z]{1,2},){8,}[a-z]{1,2}\)local (?:[a-z]{1,2},){12,}/.test(c.src.slice(0, 1200)) && 'one wrapper function with thirty-odd one- and two-letter parameters (duplicates allowed) and a long run of locals, then decimal-escaped data', true),
  ],
  moonsec_v2: [
    rule('banner', 'banner', 0.97, (c) => { const m = /Protected_by_MoonSecV2/.exec(c.src.slice(0, 4000)); return m ? { text: 'MoonSec V2 banner variable (Protected_by_MoonSecV2)', version: 'V2' } : false; }),
    rule('global', 'structure', 0.85, (c) => /\(function\(\)\s*_msec=\(function\(/.test(c.src.slice(0, 4000)) && 'the loader assigns its VM to the global _msec', true),
  ],
  wynfuscate: [
    rule('banner', 'banner', 0.97, (c) => { const m = /Protected by wYnFuscate/i.exec(c.src.slice(0, 600)); return m ? { text: 'wYnFuscate header comment' } : false; }),
    rule('getfenv-name', 'structure', 0.7, (c) => c.src.slice(0, 3000).includes('string.char(103,101,116,102,101,110,118)') && 'the name getfenv written as string.char(103,101,116,102,101,110,118) inside a (vE,vZ,vu,...) wrapper', true),
  ],
  boronide: [
    rule('banner', 'banner', 0.97, (c) => { const m = /Boronide[^\n]{0,40}?,\s*v([0-9][0-9.]*)/.exec(c.src.slice(0, 600)); return m ? { text: `Boronide header comment (v${m[1]})`, version: m[1] } : false; }),
    rule('gsub-loader', 'structure', 0.8, (c) => /\(\[\[Boronide[^\]]*\]\]\):gsub\('\(\.\*\)',function\(/.test(c.src.slice(0, 2000)) && 'a credit string run through :gsub(\'(.*)\', function(d) ...) whose body is a state loop that decides what the loader does', true),
  ],
  ironveil: [rule('mention', 'banner', 0.5, (c) => /Iron\s?Veil/i.test(c.src) && 'mentions IronVeil')],
  goofyscator: [rule('mention', 'banner', 0.5, (c) => /Goofyscator/i.test(c.src) && 'mentions Goofyscator')],
  xhider: [rule('mention', 'banner', 0.5, (c) => /X\s?Hider/i.test(c.src) && 'mentions XHider')],
  synapse_xen: [rule('mention', 'banner', 0.5, (c) => /Synapse\s*Xen/i.test(c.src) && 'mentions Synapse Xen')],
  colisseum: [
    rule('credit', 'banner', 0.9, (c) => { const m = /This file was obfuscated using Colisseum(?: Obfuscator)?(?: v([0-9][0-9.]*))?/.exec(c.src); return m ? { text: `Colisseum credit line${m[1] ? ` (v${m[1]})` : ''}`, version: m[1] || null } : false; }),
    rule('brand', 'structure', 0.9, (c) => c.src.includes('Oh Noes!, An error ocurred: 0x') && 'tamper error text "... Oh Noes!, An error ocurred: 0x<code>" (the Colisseum brand)'),
    rule('names', 'structure', 0.7, (c) => c.facts && c.facts.colisseumNames >= 6 && `${c.facts.colisseumNames} identifiers of the form coli_jLjLj (the default name generator)`),
    rule('tamper-guard', 'structure', 0.97, (c) => c.ast && c.ast.body.some(isColisseumGuard) && 'tamper guard block (environment checks that raise coded errors, hook global __COLISSEUM_TAMPER__)'),
    rule('vm', 'structure', 0.85, (c) => c.facts && c.facts.vmRunCalls > 0 && 'virtual machine entry call run(proto, { environment, anchor })', true),
  ],
  zenfus: [
    rule('wrapper', 'structure', 0.9, (c) => /function\(pack,move,unpack,env,pCall,Err\)/.test(c.src.replace(/\s+/g, '')) && 'wrapper (function(pack, move, unpack, env, pCall, Err) ... end)(table.pack, table.move, table.unpack, _ENV, pcall, error)'),
    rule('vm', 'structure', 0.95, (c) => c.facts && ['lua_wrap_state', 'run_vm', 'hexToString'].every((n) => c.facts.names.includes(n)) && 'Zenfus VM: lua_wrap_state / run_vm / hexToString around a hex-encoded Lua 5.4 instruction stream', true),
  ],
  simple_lua: [
    rule('template', 'structure', 0.95, (c) => ['_0x38ndf', '_0x93mdw', '_0x47fjs', '_0x62tdg', '_0x29dke'].every((n) => c.src.includes(n)) && 'the fixed helper names of Simple-Lua-Obfuscator (_0x38ndf piece table, _0x93mdw base64 decoder, _0x47fjs splitter)'),
  ],
  aztupbrew: [
    rule('banner', 'banner', 0.97, (c) => { const m = /AztupBrew\s*\(Fork of IronBrew2\)\s*:\s*obfuscation;\s*Version\s*([0-9][0-9.]*)/.exec(c.src); return m ? { text: `AztupBrew banner (version ${m[1]})`, version: m[1] } : false; }),
    rule('prelude', 'structure', 0.9, (c) => c.ast && isAztupPrelude(c.ast) && 'the eight library locals an AztupBrew VM starts with (string.char, string.sub, table.concat, math.ldexp, getfenv, select, unpack, tonumber)', true),
  ],
  joker: [rule('mention', 'banner', 0.5, (c) => /jokerobfuscator\.com|Joker\s*Obfuscator/i.test(c.src) && 'mentions Joker Obfuscator')],
  zerolua: [rule('mention', 'banner', 0.5, (c) => /zerolua\.pages\.dev|Zero\s*Lua\s*(?:Roblox\s*)?Obfuscator/i.test(c.src) && 'mentions Zero Lua')],
  fivem_strong: [rule('mention', 'banner', 0.5, (c) => /dsc\.gg\/revuex|Strong\s+FiveM\s+Lua\s+Obfuscator|fivem-strong-obfuscator/i.test(c.src) && 'mentions the Strong FiveM Lua Obfuscator')],
  neuroforge: [rule('mention', 'banner', 0.5, (c) => /NeuroForge/i.test(c.src) && 'mentions NeuroForge VM')],
  kirus: [
    rule('banner', 'banner', 0.97, (c) => { const m = /protected by Kirus obfuscator v?([0-9][0-9.]*)/i.exec(c.src); return m ? { text: `Kirus banner (v${m[1]})`, version: m[1] } : false; }),
    rule('vm-entry', 'structure', 0.9, (c) => c.facts && c.facts.kirusEntries > 0 && 'VM entry call setmetatable({...}, {}):name(bit32, string, table, math, type, error, pcall, getfenv, setfenv, tonumber)', true),
  ],
  obscura: [
    // the two header lines and the credit line every Obscura output starts with; the bracket holds the seed (a number) or "development"
    rule('banner', 'banner', 0.97, (c) => { const m = /^--!nocheck\r?\n--!nolint\r?\n-- Obscura( VM)? \[([^\]\n]{1,24})\]/.exec(c.src.slice(0, 200)); return m ? { text: `Obscura header${m[1] ? ' (VM build)' : ''}, build ${m[2]}` } : false; }),
    // the XOR fallback its VM and its string decoder carry, written the same way in every revision read
    rule('bxor-fallback', 'structure', 0.8, (c) => c.src.includes('(bit32 and bit32.bxor) or (bit and bit.bxor) or (function() local function _x(a,b) local r,p=0,1 for _=1,8 do local ab,bb=a%2,b%2') && 'the bit32.bxor / bit.bxor / arithmetic fallback chain written on one line'),
    // the string cipher of levels 1 to 3 and of the lightweight mode: text rebuilt with string.char(bit32.bxor(...)) by a decoder the sandbox has to run
    rule('encrypt-strings', 'structure', 0.5, (c) => /^--!nocheck\r?\n--!nolint\r?\n-- Obscura \[/.test(c.src.slice(0, 200)) && /string\.char\(bit32\.bxor\(/.test(c.src) && 'strings rebuilt with string.char(bit32.bxor(...)) by a decoder function'),
    rule('vm', 'structure', 0.9, (c) => /^--!nocheck\r?\n--!nolint\r?\n-- Obscura VM \[/.test(c.src.slice(0, 200)) && 'the VM build header: the program is bytecode for an interpreter generated into the script', true),
  ],
  realobfuscator: [
    // the header every output starts with (two Luau directives, then the credit line with the build and the repository)
    rule('banner', 'banner', 0.97, (c) => { const m = /^--!nocheck\r?\n--!nolint\r?\n-- RealObfuscator \[([^\]\n]{1,24})\](?: \| (https:\/\/github\.com\/linkoro57\/RealObfuscator))?/.exec(c.src.slice(0, 240)); return m ? { text: `RealObfuscator header, build ${m[1]}` } : false; }),
    rule('vm-pool', 'structure', 0.8, (c) => /--!nocheck\r?\n--!nolint\r?\n-- RealObfuscator /.test(c.src.slice(0, 120)) && c.src.length > 20000 && (c.src.match(/\]=\{/g) || []).length >= 40 && 'a pool of dozens of `[id]={encoded, k, k, k, k}` records in a build of this tool (a lightweight or native build of a short program has a handful): the encoded register bytecode of its VM mode', true),
  ],
  zynaa: [
    // every identifier and field name is a run of U+202A (left-to-right embedding): invisible, so the file reads as blank where names are
    rule('invisible-names', 'structure', 0.9, (c) => /(?:\u202A|\xE2\x80\xAA){4,}/.test(c.src.slice(0, 3000)) && 'identifiers made of runs of the invisible character U+202A'),
    rule('string-table-lookup', 'structure', 0.6, (c) => /(?:\u202A|\xE2\x80\xAA)+\s*=\s*_G\b/.test(c.src.slice(0, 600)) && 'the first local is _G under an invisible name'),
  ],
  luarmor: [
    // the header every Luarmor-protected bootstrap starts with and the data array it carries
    rule('header', 'banner', 0.9, (c) => /^\s*--\s*Do not save this file\s*\r?\n--\s*Always use the loadstring/i.test(c.src.slice(0, 200)) && 'the comment "Do not save this file / Always use the loadstring"'),
    rule('bsdata', 'structure', 0.6, (c) => /\b_bsdata\d+\s*=\s*\{/.test(c.src.slice(0, 600)) && 'a data array named _bsdata0'),
    rule('cdn', 'banner', 0.9, (c) => /cdn\.luarmor\.net\/v\d+_init/.test(c.src) && 'it downloads its init script from cdn.luarmor.net', true),
  ],
  xfuscator: [
    // the step-2 array: one `string.char(x / scale)` closure and a table of its calls, one entry per character of the program
    rule('char-array', 'structure', 0.9, (c) => /function\(x\)\s*return string\.char\(x\s*\/\s*_*\w*\)\s*end[\s\S]{0,400}?\{\s*_*\w*\(\d{3,}\)\s*,\s*_*\w*\(\d{3,}\)/.test(c.src.slice(0, 20000)) && 'a closure string.char(x / scale) and a table of its calls with scaled character codes (XFuscator step 2)'),
    // the string its tamper check plants, spelled in decimal escapes ("XFU5K470R R00LZ")
    rule('tamper-string', 'banner', 0.97, (c) => c.src.slice(0, 6000).includes('\\88\\70\\85\\53\\75\\52\\55\\48\\82\\32\\82\\48\\48\\76\\90') && 'the decimal-escaped string "XFU5K470R R00LZ" of XFuscator\u2019s tamper check'),
    rule('loadstring-escapes', 'structure', 0.45, (c) => /^\s*(?:math\.randomseed\([0-9.]+\)\s*)?return loadstring\('(?:\\\d{2,3}){60,}/.test(c.src.slice(0, 400)) && 'return loadstring of one string written entirely in decimal escapes (XFuscator without step 2; other tools write the same)'),
  ],
  zartha: [
    // the watermark setting's default; the author can change it, so it is evidence and not proof
    rule('watermark', 'banner', 0.9, (c) => /File generated using \[Zartha\]/.test(c.src.slice(0, 600)) && 'the default watermark string "File generated using [Zartha]"'),
    // the wrapper every build has, whatever the options do to the inside (encrypted keys, minified names): a watermark expression `and` an immediately called function that returns the VM function of four parameters
    rule('vm-wrapper', 'structure', 0.8, (c) => /^\s*return\s*\(\s*\(?"[^"\n]{0,80}"\)?\s*and\s*\(\s*function\s*\(\s*\)\s*return\s*\(\s*function\s*\(\s*\w+\s*,\s*\w+\s*,\s*\w+\s*,\s*\w+\s*\)/.test(c.src.slice(0, 400)) && 'a watermark string `and (function() return (function(a, b, c, d)` wrapped around the VM function', true),
    rule('vm-prelude', 'structure', 0.8, (c) => /^\s*return\s*\(\s*\(?"[^"\n]{0,80}"\)?\s*and\s*\(function\(\)\s*return\s*\(function\(\w+,\w+,\w+,\w+\)[\s\S]{0,200}?\w+\["string"\]\["char"\],\w+\["string"\]\["byte"\],\w+\["string"\]\["sub"\],\w+\["tostring"\],\w+\["pcall"\]/.test(c.src.slice(0, 1500)) && 'a watermark string `and (function() return (function(Env, Constants, shiftKey, decrypt)` whose locals are read out of Env["string"]["char"], ["byte"], ["sub"], ["tostring"], ["pcall"]', true),
  ],
  fusgato: [
    // the IronBrew watermark it copies, then its own credit line
    // (the tool only ever writes an interpreter and its encoded program: what this marks is a VM that was not rebuilt)
    rule('credit', 'banner', 0.97, (c) => /^\s*--\[\[\s*IronBrew:tm: obfuscation; Version [0-9.]+\s*\]\]\s*local FusGato = "discord\.gg\/\w+";/.test(c.src.slice(0, 400)) && 'the IronBrew watermark followed by `local FusGato = "discord.gg/..."`', true),
    rule('mention', 'banner', 0.7, (c) => /\blocal FusGato\b/.test(c.src.slice(0, 600)) && 'a local named FusGato'),
  ],
  luaxen: [
    // IronBrikked, the VM stage: ten library locals read from _ENV, getfenv, string, table, math, select, tonumber, setmetatable, pcall, error
    rule('ironbrikked-prelude', 'structure', 0.9, (c) => /^\s*local \w,\w,\w,\w,\w,\w,\w,\w,\w,\w\s*=\s*_ENV,\s*getfenv,\s*string,\s*table,\s*math,\s*select,\s*tonumber,\s*setmetatable,\s*pcall,\s*error\b/.test(c.src.slice(0, 400)) && 'ten locals bound to _ENV, getfenv, string, table, math, select, tonumber, setmetatable, pcall, error (LuaXen IronBrikked)', true),
    // the AST stage hides a number as `setmetatable({}, {__div = function(_, a) local x, y, z = a[1], a[2], a[3] return x*x - y*y + z end}) / {x, y, z}`
    rule('metamethod-number', 'structure', 0.85, (c) => /setmetatable\(\{\},\{\["__(?:div|mul|add|sub|mod|pow|concat)"\]=function\(_,a\)local x,y,z=a\[1\],a\[2\],a\[3\]return x\*x-y\*y\+z end\}\)\s*[-+*\/%^.]{1,2}\s*\{[-\d]+,[-\d]+,[-\d]+\}/.test(c.src.slice(0, 40000)) && 'numbers hidden as setmetatable({}, {__op = function(_, a) local x, y, z = a[1], a[2], a[3] return x*x - y*y + z end}) <op> {x, y, z} (any of __div, __mul, __add, __sub, __mod, __pow, __concat)'),
    // ... and strings as the same trick with a loop that builds them from triples
    rule('metamethod-string', 'structure', 0.85, (c) => /\["__(?:div|mul|add|sub|mod|pow|concat)"\]=function\(_,a\)local str=""local i=1 while a\[i\]do local x,y,z=a\[i\]\[1\],a\[i\]\[2\],a\[i\]\[3\]str=str\.\.str\.char\(x\*x-y\*y\+z\)/.test(c.src.slice(0, 40000)) && 'strings built from triples (x*x - y*y + z) by a metamethod with a loop'),
    // the AST stage's control flow: a state variable called `state` and a loop whose condition is a fractional literal
    rule('state-loop', 'structure', 0.7, (c) => /local state=\d{4,}[\s\S]{0,200}?while 0\.\d{6,} do if state==\d+ then/.test(c.src.slice(0, 40000)) && 'a local named state and a while loop on a fractional literal that selects by `state ==`'),
  ],
  rbxlua: [
    rule('embedded-compiler', 'structure', 0.9, (c) => { const f = c.ast && findCharListLoader(c.ast); return f ? `the program is a list of ${f.items} one-character strings run by a Lua compiler the script carries (${f.keywords} of Lua's keywords in its lexer): no loadstring is called` : false; }),
  ],
  snowveil: [
    rule('banner', 'banner', 0.97, (c) => { const m = /generated using SnowVeil\s+v?([0-9][0-9.]*)/i.exec(c.src); return m ? { text: `SnowVeil banner (v${m[1]})`, version: m[1] } : false; }),
    rule('mention', 'banner', 0.5, (c) => /SnowVeil/i.test(c.src) && 'mentions SnowVeil'),
    rule('builtin-getter', 'structure', 0.75, (c) => c.facts && c.facts.snowGetter >= 4 && `one local function asked for ${c.facts.snowGetter} different libraries' members by name (string, table, math, bit32, Vector3, CFrame): builtins are never written as \`lib.member\``, true),
  ],
  stealthx: [
    rule('banner', 'banner', 0.97, (c) => { const m = /secured by StealthxProtect(?: Gen([0-9][0-9.]*))?/i.exec(c.src); return m ? { text: `Stealth-X header${m[1] ? ` (Gen${m[1]})` : ''}`, version: m[1] ? `Gen${m[1]}` : null } : false; }),
    rule('mention', 'banner', 0.5, (c) => /getstealthx\.site|Stealth-?X\s+Obfuscator/i.test(c.src) && 'mentions Stealth-X'),
    rule('payload', 'structure', 0.8, (c) => /"STX@\d+:/.test(c.src) && 'a program string tagged "STX@" (the VM presets)', true),
    rule('handlers', 'structure', 0.55, (c) => (c.src.match(/\[(?:0x[0-9A-Fa-f]{6,8}|\d{8,10})\]=function\(\w+,\w+,\w+,\w+,\w+\)/g) || []).length >= 20 && 'a VM handler table keyed by 32-bit numbers, each handler taking five arguments', true),
  ],
  azurevm: [
    rule('banner', 'banner', 0.95, (c) => { const m = /-- Generated by AzureVM(?: \(template mode (\d+)\))?/.exec(c.src); return m ? { text: `AzureVM header${m[1] ? ` (template mode ${m[1]})` : ''}`, version: m[1] || null } : false; }),
    rule('watermark', 'banner', 0.95, (c) => /-- AzureXPino \| v[0-9.]+ \| Protected/.test(c.src) && 'AzureXPino watermark (the Prometheus-based presets of AzureVM)'),
    rule('prelude', 'structure', 0.85, (c) => c.src.includes('string.byte,string.sub,string.char,string.gsub,string.rep,setmetatable,pcall,type,tostring,assert,loadstring,unpack or table.unpack') && 'the library locals its VM starts with (string.byte, string.sub, string.char, string.gsub, string.rep, setmetatable, pcall, type, tostring, assert, loadstring, unpack)', true),
    rule('retry-wrapper', 'structure', 0.9, (c) => (c.src.match(/__az_retry_/g) || []).length >= 4 && 'SafeRetryWrapper locals (__az_retry_*)', true),
    rule('payload', 'structure', 0.5, (c) => c.src.includes('[=[LPH') && c.src.includes('">I4"') && 'a base-85 payload tagged "LPH" read with string.unpack(">I4") (the tag is Luraph\u2019s; AzureVM\u2019s README says it is not Luraph)', true),
  ],
  simple_html: [
    rule('decoder', 'structure', 0.95, (c) => /local function _D\(t\) local s="" for i=1,#t do local v=\(t\[i\]-\d+\) if v<0 then v=v\+256 end s=s\.\.string\.char\(v\) end return s end/.test(c.src) && 'the _D string decoder this page puts in front of the script: local function _D(t) ... (t[i]-KEY) ... string.char(v)'),
    rule('calls', 'structure', 0.4, (c) => (c.src.match(/\(_D\(\{[\d,]+\}\)\)/g) || []).length >= 2 && 'strings written as (_D({codes}))'),
  ],
  clyde: [
    rule('banner', 'banner', 0.92, (c) => /clydeprotection[a-z]*\.cloud|clyde-v3\.(?:fun|pro)/i.test(c.src) && 'Clyde header (ASCII-art title with its site and a build id)'),
    // in the fixtures the header appears on the VM modes only (vm, vm-max); rename and string modes carry none
    rule('vm-header', 'structure', 0.85, (c) => /clydeprotection[a-z]*\.cloud/i.test(c.src) && /\bbuild [0-9A-F]{8}\b/.test(c.src) && 'the header the VM modes put first (site name and build id): the program is inside a stack or register VM', true),
    rule('char-escape', 'structure', 0.55, (c) => /local\s+\w+\s*=\s*\(\s*""\s*\)\s*\[\s*\(?\s*"\\0?99\\1?04\\0?97\\1?14"\s*\)?\s*\]/.test(c.src) && 'string.char fetched as ("")["\\99\\104\\97\\114"]'),
    rule('xor-decoder', 'structure', 0.5, (c) => /string\.char\(bit32\.bxor\(\w+\[\w+\],\s*\w+\)\)/.test(c.src) && /\(\(1\s*\+\s*1\)\s*==\s*2\)\s*and/.test(c.src) && 'XOR string decoder with a cache and an always-true test: if (((1 + 1) == 2) and cache[key]) then'),
    rule('mention', 'banner', 0.45, (c) => /Clyde\s*Protection/i.test(c.src) && 'mentions Clyde Protection'),
  ],
  wearedevs: [rule('mention', 'banner', 0.5, (c) => /wearedevs\.net|WeAreDevs/i.test(c.src) && 'mentions WeAreDevs')],
};

/** The tool a header comment claims made the script: "-- Protected by Mnx Obfuscator | Public Enemy", "--// PROTECTED BY DELTA V3 //--", "-- File protected by void [..]". Null when there is none. */
export function vendorBanner(source) {
  const head = source.slice(0, 600);
  const m = /^\s*(?:--\[\[|--\/\/|--)[ \t]*(?:this (?:file|script) was )?(?:file )?(?:protected|obfuscated|generated|secured|encrypted)\s+(?:by|with|using)\s+([^\n|\[\]\/]{2,48}?)\s*(?:[|\[\n\/\]]|$)/im.exec(head);
  return m ? m[1].trim() : null;
}

/** The fixed run of `local x = <library function>` statements IronBrew 2's generator writes before anything else. */
const IB2_PRELUDE = ['string.byte', 'string.char', 'string.sub', 'table.concat', 'table.insert', 'math.ldexp', 'getfenv|_ENV', 'setmetatable', 'select', 'unpack|table.unpack', 'tonumber'];
function isIronBrewPrelude(ast) {
  if (ast.body.length < 14) return false;
  const path = (e) => (e.type === 'Name' ? e.name : e.type === 'Index' && e.key.type === 'String' && e.obj.type === 'Name' ? `${e.obj.name}.${e.key.value}` : null);
  for (let i = 0; i < IB2_PRELUDE.length; i++) {
    const s = ast.body[i];
    if (!s || s.type !== 'Local' || s.ids.length !== 1 || s.values.length !== 1) return false;
    const v = s.values[0];
    const want = IB2_PRELUDE[i];
    if (want.includes('|')) {
      const [a, b] = want.split('|');
      if (v.type !== 'Binary' || v.op !== 'or' || path(v.left) !== a) return false;
      if (b === '_ENV' ? v.right.type !== 'Func' : path(v.right) !== b) return false;
    } else if (path(v) !== want) return false;
  }
  return true;
}

/** The run of `local x = <library function>` statements AztupBrew's generator writes first (inside its `return (function(...) ... end)` wrapper). */
const AZTUP_PRELUDE = ['string.char', 'string.sub', 'table.concat', 'math.ldexp', 'getfenv|_ENV', 'select', 'unpack|table.unpack', 'tonumber'];
function isAztupPrelude(ast) {
  const ret = ast.body[ast.body.length - 1];
  if (!ret || ret.type !== 'Return' || ret.values.length !== 1) return false;
  const call = ret.values[0];
  if (call.type !== 'Call' || call.fn.type !== 'Paren' || call.fn.expr.type !== 'Func') return false;
  const body = call.fn.expr.body;
  const path = (e) => (e.type === 'Name' ? e.name : e.type === 'Index' && e.key.type === 'String' && e.obj.type === 'Name' ? `${e.obj.name}.${e.key.value}` : null);
  for (let i = 0; i < AZTUP_PRELUDE.length; i++) {
    const s = body[i];
    if (!s || s.type !== 'Local' || s.ids.length !== 1 || s.values.length !== 1) return false;
    const v = s.values[0];
    const want = AZTUP_PRELUDE[i];
    if (want.includes('|')) {
      const [a, b] = want.split('|');
      if (v.type !== 'Binary' || v.op !== 'or' || path(v.left) !== a) return false;
      if (b === '_ENV' ? v.right.type !== 'Func' : path(v.right) !== b) return false;
    } else if (path(v) !== want) return false;
  }
  return true;
}

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

  const ctx = { src: source, facts, ast, vm: vmShape(facts, ast || { body: [] }) };

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
      evidence.push({ rule: r.id, kind: r.kind, text, weight: r.weight, unrecoverable: r.unrecoverable });
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
    if (/EncodingService/.test(source) && /DecompressBuffer/.test(source)) traits.add('compressed-payload');
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
  // A header comment that names a tool no rule above knows is still worth saying: custom and unfamiliar obfuscators usually sign their output.
  const banner = vendorBanner(source);
  if (banner) {
    result.vendorBanner = banner;
    const known = result.families.some((f) => f.confidence >= 0.5 && f.evidence.some((e) => e.kind === 'banner'));
    if (!known) result.traits.push({ id: 'vendor-banner', text: `The header comment names a tool: "${banner}". No rule knows it, so the script is analysed by what it is made of.` });
  }
  result.metrics.bytes = source.length;
  // a class is an addition to the verdict: if classifying a strange tree fails, the detection stands without it
  try { result.classes = classify(source, ast, result); } catch { result.classes = []; }
  return result;
}
