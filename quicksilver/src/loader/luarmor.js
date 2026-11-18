// Luarmor loader analysis: what a Luarmor-related loader contains, what of it is recoverable from the file, and what is not in it.
//
// Three loader variants are recognised from what the file itself shows (each observed in real loaders; see docs/targets/LUARMOR.md):
//
//   bootstrap   a global data table (`_bsdata0 = {…}`) and a few lines that run a cached copy of an "init" script or download it from
//               cdn.luarmor.net, cache it with writefile and run it. The init script is the service's own client runtime, and the data
//               table is read only by it.
//   sdk         a script (often a hub's own loader with a key-entry UI) that downloads Luarmor's SDK library, sets `script_key`, calls
//               `check_key`, handles the status codes it returns (KEY_VALID, KEY_HWID_LOCKED, …) and calls `load_script`.
//   loader-url  `loadstring(game:HttpGet("https://api.luarmor.net/files/v3|v4/loaders/<id>.lua"))()` with `script_key` set first.
//
// The five operations Prompt XX distinguishes are answered separately:
//   1 analyse the loader                 — done here, statically;
//   2 recover code present in the loader — the loader's own logic (UI, key flow, cache handling) is plain Lua or is recovered by the
//                                          pipeline; the bootstrap data table is opaque (its only consumer is not in the file);
//   3 retrieve the delivered payload     — no documented interface returns a protected script (docs/API-CATALOGUE.md); not attempted;
//   4 deobfuscate a retrieved payload    — only if the owner supplies it (they hold the script they uploaded): it then goes through the
//                                          normal pipeline like any script;
//   5 validate behaviour                 — needs the original; not possible for the protected part from the loader alone.
//
// Boundaries: the service's client runtime (the init script, the SDK library) is not fetched or analysed, and the data table is not
// decoded: interpreting them would mean working on the protection itself, which is not what an owner needs to recover their code.
// Key values are redacted.

import { parse } from '../core/parser.js';
import { print } from '../core/printer.js';
import { walk } from '../core/walk.js';
import { analyze } from '../core/scope.js';
import { detect } from '../detect/detect.js';

const unparen = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const STATUS = /^KEY_[A-Z_]+$/;

function strInfo(v) {
  if (/^[0-9a-f]+$/i.test(v)) return { form: 'hex digits', bytes: v.length, note: v.length % 2 === 0 ? `${v.length / 2} bytes as hex${[32, 40, 64, 128].includes(v.length) ? ` (the length of a ${({ 32: '128', 40: '160', 64: '256', 128: '512' })[v.length]}-bit value)` : ''}` : 'hex digits' };
  // eslint-disable-next-line no-control-regex
  if (/[\x00-\x1f\x7f-\xff]/.test(v)) return { form: 'binary bytes', bytes: v.length, note: `${v.length} raw bytes` };
  if (/^[\x21-\x7e]+$/.test(v)) return { form: 'token', bytes: v.length, note: `${v.length} printable characters, alphabet of ${new Set(v).size}` };
  return { form: 'text', bytes: v.length, note: `${v.length} characters` };
}

/**
 * @param {string} source binary string
 * @returns {null | object} null when nothing Luarmor-related is present
 */
// ---- loader ids chosen at run time (Prompt XXI, Test 7) ---------------------------------------------------------------------------------
//
// A hub loader often builds the loader address as `".../loaders/" .. id .. ".lua"`, with `id` taken from a table keyed by PlaceId or returned
// by a function that tests PlaceId and the executor. The ids are literals in the file; they are found statically — never by running anything —
// together with the literal conditions each one sits under, so the report can say which id serves which game.

const LOADER_PREFIX = /files\/v\d+\/loaders\/$/i;
const exprText = (e, info, depth = 0) => {
  e = unparen(e);
  if (!e) return '?';
  if (e.type === 'String') return JSON.stringify(e.value);
  if (e.type === 'Number') return String(e.value);
  if (e.type === 'Name') {
    const v = info.varOf.get(e);
    return v && !v.isGlobal && !v.writes.length && v.init && depth < 3 && v.init.type !== 'Func' ? exprText(v.init, info, depth + 1) : e.name;
  }
  if (e.type === 'Index') {
    if (e.key && e.key.type === 'String' && /^[A-Za-z_]\w*$/.test(e.key.value)) return `${exprText(e.obj, info, depth)}.${e.key.value}`;
    return `${unparen(e.obj).type === 'Table' ? '{…}' : exprText(e.obj, info, depth)}[${exprText(e.key, info, depth + 1)}]`;
  }
  if (e.type === 'Table') return '{…}';
  if (e.type === 'Call') return `${exprText(e.fn, info, depth)}(${e.args.map((a) => exprText(a, info, depth + 1)).join(', ')})`;
  if (e.type === 'MethodCall') return `${exprText(e.obj, info, depth)}:${e.name}(…)`;
  return e.type.toLowerCase();
};

/** The literal comparisons in a condition, as text: `v == "1" or v == "2"` → `tostring(game.PlaceId) is "1" or "2"`. */
function condText(cond, info) {
  const pairs = [];
  walk(cond, (n) => {
    if (n.type !== 'Binary' || (n.op !== '==' && n.op !== '~=')) return undefined;
    const [lit, other] = unparen(n.right).type === 'String' ? [unparen(n.right), n.left] : unparen(n.left).type === 'String' ? [unparen(n.left), n.right] : [null, null];
    if (lit) pairs.push({ what: exprText(other, info), value: lit.value, neg: n.op === '~=' });
    return false;
  });
  if (!pairs.length) return null;
  const by = new Map();
  for (const p of pairs) { const k = `${p.what}${p.neg ? ' is not' : ' is'}`; if (!by.has(k)) by.set(k, []); by.get(k).push(JSON.stringify(p.value)); }
  return [...by].map(([k, vs]) => `${k} ${vs.join(' or ')}`).join('; ');
}

/** Candidate string values of an expression, statically. Returns { values: [{ value, line, when[] }], complete } or null when nothing is known. */
function candidates(e, info, depth = 0, when = []) {
  e = unparen(e);
  if (!e || depth > 6) return null;
  if (e.type === 'String') return { values: [{ value: e.value, line: e.line || null, when }], complete: true };
  if (e.type === 'Name') {
    const v = info.varOf.get(e);
    if (!v || v.isGlobal || v.writes.length || !v.init) return null;
    return candidates(v.init, info, depth + 1, when);
  }
  if (e.type === 'Index') {
    let t = unparen(e.obj);
    // a table bound once to a local (`local ids = {...}; ids[k]`) is the same table as one written in place
    if (t.type === 'Name') { const tv = info.varOf.get(t); t = tv && !tv.isGlobal && !tv.writes.length && tv.init ? unparen(tv.init) : t; }
    if (t.type !== 'Table') return null;
    const out = [];
    let complete = true;
    for (const f of t.fields) {
      const val = unparen(f.value);
      const key = f.kind === 'named' ? f.key : f.kind === 'keyed' && unparen(f.key).type === 'String' ? unparen(f.key).value : f.kind === 'keyed' && unparen(f.key).type === 'Number' ? unparen(f.key).value : null;
      if (val.type !== 'String') { complete = false; continue; }
      out.push({ value: val.value, line: val.line || null, when: [...when, key != null ? `${exprText(e.key, info)} is ${JSON.stringify(String(key))}` : 'a table entry'] });
    }
    return out.length ? { values: out, complete } : null;
  }
  if (e.type === 'Call' && unparen(e.fn).type === 'Name') {
    const v = info.varOf.get(unparen(e.fn));
    const fn = v && !v.isGlobal && !v.writes.length && v.init && v.init.type === 'Func' ? v.init : null;
    if (!fn) return null;
    const out = [];
    let complete = true;
    const visit = (body, conds) => {
      for (const st of body || []) {
        if (st.type === 'Return') {
          const r0 = st.values && st.values[0] ? unparen(st.values[0]) : { type: 'Nil' };
          if (r0.type === 'Nil') continue;              // "no id for this case": not a candidate
          const c = candidates(r0, info, depth + 1, [...when, ...conds]);
          if (c) { out.push(...c.values); if (!c.complete) complete = false; } else complete = false;
        } else if (st.type === 'If') {
          st.clauses.forEach((cl) => visit(cl.body, [...conds, condText(cl.cond, info) || 'a condition']));
          if (st.orelse) visit(st.orelse, [...conds, 'otherwise']);
        } else if (st.type === 'Do' || st.type === 'While' || st.type === 'Repeat' || st.type === 'NumFor' || st.type === 'GenFor') visit(st.body, conds);
      }
    };
    visit(fn.body, []);
    return out.length ? { values: out, complete } : null;
  }
  return null;
}

/** Every `".../files/vN/loaders/" .. id .. ".lua"` in the file, with the ids it can take and whether a script_key is set before it on its path. */
function constructedLoaders(ast, info) {
  const found = [];
  const seen = new WeakSet();
  const flatten = (e, out = []) => { e = unparen(e); if (e && e.type === 'Binary' && e.op === '..') { flatten(e.left, out); flatten(e.right, out); } else out.push(e); return out; };
  // a block's statements in order; a key assigned earlier in the block (or in an enclosing one) holds for what follows, nested blocks included
  const block = (body, keyAlready) => {
    let keySet = keyAlready;
    for (const st of body || []) {
      walk(st, (n) => {
        if (n.type === 'Func') return false;                  // function bodies are visited as blocks of their own (innerBlocks)
        if (n !== st && STATEMENTS.has(n.type)) return false;  // so are nested blocks, in order, after what precedes them
        if (n.type !== 'Binary' || n.op !== '..' || seen.has(n)) return undefined;
        const parts = flatten(n);
        const i = parts.findIndex((x) => x && x.type === 'String' && /luarmor\.net\//i.test(x.value) && LOADER_PREFIX.test(x.value));
        if (i < 0 || !parts[i + 1]) return undefined;
        walk(n, (m) => { if (m.type === 'Binary') seen.add(m); return undefined; });
        const c = candidates(parts[i + 1], info);
        found.push({ line: n.line || st.line || null, prefix: parts[i].value, hole: exprText(parts[i + 1], info), ids: c ? c.values.filter((x) => /^[0-9a-f]{32}$/i.test(x.value)) : [], complete: !!(c && c.complete), keySet });
        return false;
      });
      if (isKeyAssign(st)) keySet = true;
      for (const inner of innerBlocks(st)) block(inner, keySet);
    }
  };
  block(ast.body, false);
  return found.sort((a, b) => (a.line || 0) - (b.line || 0));
}

const STATEMENTS = new Set(['Local', 'Assign', 'CallStmt', 'If', 'Do', 'While', 'Repeat', 'NumFor', 'GenFor', 'Return', 'Function', 'LocalFunction', 'Break', 'Goto', 'Label']);
const isKeyAssign = (st) => (st.type === 'Assign' || st.type === 'Local') && (st.type === 'Assign' ? st.targets : st.ids).some((t) => {
  const name = t.type === 'Name' || t.type === 'Id' ? t.name : t.type === 'Index' && t.key && t.key.type === 'String' ? t.key.value : null;
  return name && /^script_?key$/i.test(name);
});
function innerBlocks(st) {
  const out = [];
  const add = (b) => { if (Array.isArray(b)) out.push(b); };
  if (st.type === 'If') { st.clauses.forEach((c) => add(c.body)); add(st.orelse); }
  else if (['Do', 'While', 'Repeat', 'NumFor', 'GenFor'].includes(st.type)) add(st.body);
  // function bodies (callbacks, pcall(function() ... end)) anywhere in the statement
  walk(st, (n) => { if (n.type === 'Func') { add(n.body); return false; } return undefined; });
  return out;
}

/** Where a value assigned to script_key comes from, in words (never the value). */
function keySource(v, info) {
  v = unparen(v);
  if (!v) return 'nothing (declared)';
  if (v.type === 'String') return `a literal (${v.value.length} characters, redacted)`;
  const text = (e) => {
    let hit = null;
    walk(e, (n) => {
      if (hit) return false;
      if (n.type === 'Call' && unparen(n.fn).type === 'Name' && unparen(n.fn).name === 'readfile') { const a = n.args[0] && unparen(n.args[0]); hit = `a file it saved earlier${a && a.type === 'String' ? ` (${a.value})` : ''}`; }
      if (n.type === 'Index' && n.key && n.key.type === 'String' && n.key.value === 'Text') hit = 'what the user typed into a text box';
      return undefined;
    });
    return hit;
  };
  if (v.type === 'Name') {
    const x = info.varOf.get(v);
    if (x && !x.isGlobal && x.init) {
      const init = unparen(x.init);
      const direct = text(init);
      if (direct) return `the local ${v.name}: ${direct}`;
      if (init.type === 'Call' && unparen(init.fn).type === 'Name') {
        const f = info.varOf.get(unparen(init.fn));
        const body = f && f.init && f.init.type === 'Func' ? f.init : null;
        const inner = body && text(body);
        if (inner) return `the local ${v.name}: ${inner}`;
      }
      if (init.type === 'MethodCall' || init.type === 'Call') { const t2 = text(init); if (t2) return `the local ${v.name}: ${t2}`; }
    }
    return `the variable ${v.name}`;
  }
  return v.type === 'Call' ? 'the result of a call (user input, a file or a request)' : `a ${v.type.toLowerCase()} expression`;
}

export function analyzeLuarmor(source) {
  const mentions = /luarmor/i.test(source) || /\b_bsdata\d+\b/.test(source);
  if (!mentions && !/\bscript_key\b/.test(source)) return null;
  let ast = null;
  try { ast = parse(source); } catch (e) {
    return { recognised: mentions, parsed: false, error: e.message, variants: [], note: 'The file does not parse; run the Deobfuscator first if it is wrapped in another layer.' };
  }
  const urls = [];
  walk(ast, (n) => { if (n.type === 'String' && /luarmor\.net/i.test(n.value)) urls.push({ value: n.value, line: n.line || null }); return undefined; });
  const info = analyze(ast);
  const constructed = constructedLoaders(ast, info);
  const has = (re) => urls.some((u) => re.test(u.value)) || re.test(source);
  const variants = [];
  const dataTables = [];
  // bootstrap data tables: a global assignment of a table literal to _bsdataN
  walk(ast, (n) => {
    if (n.type !== 'Assign') return undefined;
    n.targets.forEach((t, i) => {
      const v = unparen(n.values[i]);
      if (t.type === 'Name' && /^_bsdata\d+$/.test(t.name) && v && v.type === 'Table') {
        const items = v.fields.map((f) => unparen(f.value));
        const nums = items.filter((x) => x.type === 'Number');
        const strs = items.filter((x) => x.type === 'String');
        dataTables.push({
          name: t.name, line: n.line || null, entries: items.length,
          numbers: nums.length, numberRange: nums.length ? [Math.min(...nums.map((x) => x.value)), Math.max(...nums.map((x) => x.value))] : null,
          strings: strs.map((x) => strInfo(x.value)),
          other: items.length - nums.length - strs.length,
        });
      }
    });
    return undefined;
  });
  const cdnInit = urls.find((u) => /cdn\.luarmor\.net\/v\d+_init/i.test(u.value));
  if (dataTables.length || cdnInit) variants.push('bootstrap');
  const sdk = has(/sdkapi-public\.luarmor\.net/i) || /\bcheck_key\b/.test(source) && /\bload_script\b/.test(source);
  if (sdk) variants.push('sdk');
  // a full loader address in one literal; a literal that ends at ".../loaders/" is only the start of an address built at run time
  const loaderUrls = urls.filter((u) => /api\.luarmor\.net\/files\/v\d+\/loaders\//i.test(u.value) && !LOADER_PREFIX.test(u.value));
  const constructedLoader = constructed.length > 0 || /api\.luarmor\.net\/files\/v\d+\/loaders\/["']?\s*\.\./i.test(source) || /files\/v\d+\/loaders\/"\s*\.\./.test(source);
  if (loaderUrls.length || constructedLoader) variants.push('loader-url');
  const keyLinks = urls.filter((u) => /ads\.luarmor\.net\/get_key/i.test(u.value));
  if (keyLinks.length) variants.push('key-link');
  if (!variants.length) return null;
  // is the loader's own code obfuscated? then it is recovered by the pipeline, not read off the file
  let det = null;
  try { det = detect(source, ast); } catch { det = null; }
  const obfuscators = det ? det.families.filter((f) => f.confidence >= 0.5 && f.id !== 'luarmor').map((f) => f.name) : [];
  const vmTrait = det ? (det.traits || []).some((t) => ['vm', 'state-machine', 'string-table'].includes(t.id)) : false;
  const obfuscated = obfuscators.length > 0 || vmTrait;

  // key handling (values redacted) and status handling
  const key = { set: false, sources: [] };
  walk(ast, (n) => {
    const targets = n.type === 'Assign' ? n.targets : n.type === 'Local' ? n.ids : [];
    targets.forEach((t, i) => {
      const name = t.type === 'Name' || t.type === 'Id' ? t.name : t.type === 'Index' && t.key && t.key.type === 'String' ? t.key.value : null;
      if (!name || !/^script_?key$/i.test(name)) return;
      key.set = true;
      const v = unparen(n.values[i]);
      key.sources.push(keySource(v, info));
    });
    return undefined;
  });
  // status codes: the KEY_* names, and every literal the loader compares with a `.code` field (INVALID_EXECUTOR, SECURITY_ERROR, ...)
  const compared = [];
  walk(ast, (n) => {
    if (n.type !== 'Binary' || (n.op !== '==' && n.op !== '~=')) return undefined;
    const [a, b] = [unparen(n.left), unparen(n.right)];
    const lit = a.type === 'String' ? a : b.type === 'String' ? b : null;
    const other = lit === a ? b : a;
    if (lit && other && other.type === 'Index' && other.key && other.key.type === 'String' && other.key.value === 'code' && /^[A-Z][A-Z0-9_]{2,}$/.test(lit.value)) compared.push(lit.value);
    return undefined;
  });
  const statuses = [...new Set([...(source.match(/KEY_[A-Z_]{3,}/g) || []).filter((s) => STATUS.test(s)), ...compared])].sort();
  // the loader ids the file chooses between at run time, each with the conditions it sits under
  const ids = new Map();
  for (const c of constructed) for (const x of c.ids) {
    const id = x.value.toLowerCase();
    if (!ids.has(id)) ids.set(id, { id, line: x.line, when: x.when.filter(Boolean), requests: [], keyed: false });
    const e = ids.get(id);
    e.requests.push(c.line);
    if (c.keySet) e.keyed = true;
  }
  const loaderIds = [...ids.values()];
  const cache = { reads: /\breadfile\b/.test(source), writes: /\bwritefile\b/.test(source), cleansOld: /\bdelfile\b/.test(source) && /\blistfiles\b/.test(source) };

  // the loader's own logic: everything but the data tables; recoverable when it parses as plain Lua
  const logicAst = { ...ast, body: (ast.body || []).filter((s) => !(s.type === 'Assign' && s.targets.every((t) => t.type === 'Name' && /^_bsdata\d+$/.test(t.name)))) };
  // the key's value is replaced by a placeholder in the recovered logic (the original file, with the key, stays where the user has it)
  let redactedKeys = 0;
  walk(logicAst, (n) => {
    const targets = n.type === 'Assign' ? n.targets : n.type === 'Local' ? n.ids : [];
    targets.forEach((t, i) => {
      const name = t.type === 'Name' || t.type === 'Id' ? t.name : t.type === 'Index' && t.key && t.key.type === 'String' ? t.key.value : null;
      const v = n.values && unparen(n.values[i]);
      if (name && /^script_?key$/i.test(name) && v && v.type === 'String') { n.values[i] = { type: 'String', value: '<your script_key>', raw: null }; redactedKeys++; }
    });
    return undefined;
  });
  const logic = print(logicAst);
  const dataBytes = dataTables.reduce((a, d) => a + d.strings.reduce((b, x) => b + x.bytes, 0) + d.numbers * 8, 0);
  const ui = /\bInstance\.new\b|ScreenGui|TextBox|TextButton/.test(source);
  const remote = [
    ...(cdnInit ? [{ role: 'init runtime', what: 'the service’s client runtime the bootstrap downloads and caches; it reads the data table', address: cdnInit.value, retrieved: false, why: 'the service’s own client code, not the user’s script; not fetched' }] : []),
    ...(sdk ? [{ role: 'SDK library', what: 'Luarmor’s key-check library (check_key, load_script)', address: (urls.find((u) => /sdkapi-public/i.test(u.value)) || {}).value || null, retrieved: false, why: 'the service’s client code; not fetched' }] : []),
    ...(sdk && (/\bload_script\b/.test(source) || !(loaderUrls.length || constructed.length)) ? [{ role: 'protected script', what: 'delivered by load_script after check_key accepts the key', address: null, retrieved: false, why: 'no documented interface returns a protected script; the owner already holds the source they uploaded' }] : []),
    ...loaderUrls.map((u) => ({ role: 'protected script loader', what: 'served by the service after the key check', address: u.value, retrieved: false, why: 'no documented interface returns a protected script' })),
    ...constructed.map((c) => ({ role: 'protected script loader', what: `address built at run time from ${c.hole}${c.ids.length ? `: one of ${c.ids.length} loader id${c.ids.length === 1 ? '' : 's'} in the file${c.complete ? '' : ' (and possibly others the file does not fix)'}` : ' (the id is not fixed by the file)'}${c.keySet ? '' : '; no script_key is set on this path'}`, address: `${c.prefix}{${c.hole}}.lua`, line: c.line, retrieved: false, why: 'no documented interface returns a protected script' })),
    ...(constructedLoader && !constructed.length && !loaderUrls.length ? [{ role: 'protected script loader', what: 'address built at run time from a script id', address: null, retrieved: false, why: 'no documented interface returns a protected script' }] : []),
  ];
  const localBytes = logic.length;
  return {
    recognised: true, parsed: true, variants,
    local: {
      bytes: localBytes, recoverable: obfuscated ? 'needs-deobfuscation' : 'full', obfuscatedBy: obfuscators, code: obfuscated ? null : logic,
      describes: [
        variants.includes('bootstrap') ? `runs a cached copy of the init script if present${cache.reads ? ' (readfile)' : ''}, otherwise downloads it${cache.writes ? ', caches it (writefile)' : ''}${cache.cleansOld ? ' and deletes older cached copies' : ''}, then runs it` : null,
        sdk ? `loads the SDK, checks the key${statuses.length ? ` and handles ${statuses.length} status code${statuses.length === 1 ? '' : 's'} (${statuses.join(', ')})` : ''}, then ${/\bload_script\b/.test(source) ? 'calls load_script' : constructedLoader || loaderUrls.length ? `${key.set ? 'sets script_key and ' : ''}runs the Luarmor loader for the script id` : 'continues'}` : null,
        loaderIds.length ? `chooses between ${loaderIds.length} loader id${loaderIds.length === 1 ? '' : 's'} at run time${loaderIds.some((x) => x.when.length) ? ' by the conditions listed with each id' : ''}${loaderIds.some((x) => !x.keyed) ? `; ${loaderIds.filter((x) => !x.keyed).length} of them ${loaderIds.filter((x) => !x.keyed).length === 1 ? 'is' : 'are'} loaded without setting a script_key (a keyless script)` : ''}` : null,
        cache.reads && cache.writes && !variants.includes('bootstrap') ? 'remembers the key in a file (writefile) and tries it first on the next run (readfile)' : null,
        ui ? 'builds its own user interface (key entry / status)' : null,
        redactedKeys ? `the script_key literal is replaced by a placeholder in the recovered code (${redactedKeys} place${redactedKeys === 1 ? '' : 's'})` : null,
        keyLinks.length ? `points the user to a key page (${keyLinks.length} link${keyLinks.length === 1 ? '' : 's'} to ads.luarmor.net/get_key)` : null,
        obfuscated ? `the loader’s own code is obfuscated${obfuscators.length ? ` (${obfuscators.join(', ')})` : ''}: run the Deobfuscator to recover it` : null,
      ].filter(Boolean),
    },
    data: dataTables.map((d) => ({ ...d, recoverable: 'opaque', why: 'its only consumer is the init runtime, which is not in this file; what the values mean cannot be determined from the loader' })),
    remote,
    loaderIds,
    key,
    statuses,
    cache,
    operations: [
      { n: 1, name: 'Analyse the loader', status: 'done', detail: `variant${variants.length === 1 ? '' : 's'}: ${variants.join(', ')}` },
      { n: 2, name: 'Recover code present in the loader', status: obfuscated ? 'via-pipeline' : dataTables.length ? 'partial' : 'done', detail: `${obfuscated ? 'the loader’s own code is obfuscated; the Deobfuscator recovers it (its result is measured there, not assumed here)' : `the loader’s own logic (${localBytes} bytes) is recovered in full`}${dataTables.length ? `; ${dataTables.length} data table${dataTables.length === 1 ? '' : 's'} (${dataBytes} bytes of values) stay opaque` : ''}` },
      { n: 3, name: 'Retrieve the separately delivered payload', status: 'not-available', detail: 'Luarmor documents no interface that returns a protected script: its v3 API manages keys and users, lists scripts as metadata and uploads scripts (from whitelisted IPs only). The owner can confirm the script is theirs with "Check ownership" (metadata only)' },
      { n: 4, name: 'Deobfuscate the retrieved payload', status: 'needs-input', detail: 'nothing is retrieved; if you own the script, use "Supply the payload" below: the file you hold goes through validation, identification and deobfuscation' },
      { n: 5, name: 'Validate behaviour', status: 'needs-input', detail: 'done on the supplied payload: its reconstruction is run next to it in the sandbox; the loader alone contains no program to compare' },
    ],
    answer: `From this file: the loader’s own logic ${obfuscated ? 'is obfuscated and goes through the Deobfuscator' : 'is recovered in full'}${dataTables.length ? ', the bootstrap data is opaque' : ''}, and none of the protected script is present${variants.includes('sdk') || variants.includes('loader-url') ? ' (it is delivered by the service after a key check)' : ''}. To reconstruct the protected script, its owner has to provide it; no authorised route retrieves it from the service.`,
  };
}
