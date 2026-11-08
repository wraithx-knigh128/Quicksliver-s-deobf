// NEXUS · Semantic Relationship Mapper.
//
// The older renamer names a variable from the expression it was initialised with. That sees `local x = game:GetService("Players")`
// and nothing else: `local ok, result = pcall(...)`, `a, b, c = results[1], results[2], results[3]`, a table that is filled in a loop
// and read by position, a counter, a parameter of `function tbl.FormatDuration(n)` all come out as `value`, `value1`, `value2`.
//
// This module builds the relations the code itself states and derives names (roles) from them:
//
//   * what a variable is *assigned from*, including multi-assignment and the results of `pcall`;
//   * where it is *used*: methods called on it, fields read and written, how it is indexed, what it is passed to;
//   * how variables are *related*: a loop variable and the list it walks, a table that is stored into by loop index and later
//     read by constant positions, the URL a library was downloaded from;
//   * the functions the script defines, who calls whom, and what it depends on (URLs fetched, executor APIs, globals written).
//
// Every suggestion carries a rule, a confidence and the evidence it rests on. A role is an *inference about intent*, never a recovered
// original name; the report says so. The renamer decides whether a suggestion may be used (it never renames names a person chose).

import { analyze, STDLIB_GLOBALS } from '../core/scope.js';
import { forEachChild } from '../core/walk.js';
import { isIdentifier } from '../core/printer.js';
import { hintFromInit } from '../passes/rename.js';

const unparen = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const lowerFirst = (s) => (s ? s.charAt(0).toLowerCase() + s.slice(1) : s);
const upperFirst = (s) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : s);

function words(s) {
  return s.replace(/([a-z0-9])([A-Z])/g, '$1 $2').replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2').split(/[^A-Za-z0-9]+/).filter(Boolean);
}
const camel = (ws) => ws.map((w, i) => (i ? upperFirst(w.toLowerCase()) : w.toLowerCase())).join('');
const sane = (s) => {
  const t = (s || '').replace(/[^A-Za-z0-9_]/g, '');
  if (!t || /^\d/.test(t)) return null;
  return isIdentifier(t) ? (t.length > 28 ? t.slice(0, 28) : t) : null;
};

// ---- names from URLs ------------------------------------------------------------------------------------------------------------------
const GENERIC = new Set(['library', 'lib', 'loader', 'load', 'bootstrap', 'bootstrapper', 'init', 'main', 'index', 'script', 'scripts', 'source', 'raw', 'code', 'module',
  'modules', 'core', 'api', 'sdk', 'src', 'public', 'utilities', 'utils', 'master', 'refs', 'heads', 'latest', 'release', 'releases', 'download']);
const BORING_HOSTS = new Set(['githubusercontent', 'github', 'gist', 'pastebin', 'discordapp', 'discord', 'vercel', 'netlify', 'pages', 'cloudflare', 'workers', 'herokuapp', 'repl']);
const isGeneric = (ws) => ws.length > 0 && ws.every((w) => GENERIC.has(w.toLowerCase()) || /^v?\d+$/.test(w));

/** A name for what a URL serves: the file, else the folder, else the site. `null` when nothing in it says anything. */
export function nameFromUrl(url) {
  let u;
  try { u = new URL(url); } catch { return null; }
  const segs = u.pathname.split('/').filter(Boolean).map((s) => { try { return decodeURIComponent(s); } catch { return s; } });
  const file = (segs.pop() || '').replace(/\.(?:lua|luau|txt|json|html?|js)$/i, '');
  const fileWords = words(file);
  if (fileWords.length && !isGeneric(fileWords)) return sane(camel(fileWords));
  for (let i = segs.length - 1; i >= 0; i--) {
    const w = words(segs[i]);
    if (w.length && !isGeneric(w)) return sane(camel(w));
  }
  const labels = u.hostname.replace(/^www\./, '').split('.');
  const label = labels.length >= 2 ? labels[labels.length - 2] : labels[0];
  const hostWords = words(label).filter((w) => !GENERIC.has(w.toLowerCase()));
  if (hostWords.length && !BORING_HOSTS.has(label.toLowerCase())) {
    const stem = camel(hostWords.length > 1 ? [hostWords[hostWords.length - 1]] : hostWords);
    return sane(fileWords.length ? stem + upperFirst(camel(fileWords)) : stem);
  }
  return fileWords.length ? sane(camel(fileWords)) : null;
}

// ---- recognising shapes ---------------------------------------------------------------------------------------------------------------
/** Names and strings that belong to a licence-key check (`script_key`, `check_key`, `KEY_VALID`, `hwid`). */
const KEYISH = /^[A-Za-z_]*(?:script_?key|scriptkey|check_?key|validate_?key|verify_?key|resolve_?key|key_(?:valid|invalid|expired|banned|incorrect|hwid\w*)|licen[cs]e_?key|hwid)[A-Za-z_]*$/i;
const FETCH_METHODS = new Set(['HttpGet', 'HttpGetAsync']);

/** `game:HttpGet(U)` -> the argument U, else null. */
function fetchArg(e) {
  e = unparen(e);
  if (!e) return null;
  if (e.type === 'MethodCall' && FETCH_METHODS.has(e.name) && e.args.length) return e.args[0];
  if (e.type === 'Call' && e.fn.type === 'Name' && FETCH_METHODS.has(e.fn.name) && e.args.length) return e.args[0];
  return null;
}

/** `loadstring(game:HttpGet(U))()` -> U; `game:HttpGet(U)` -> U; else null. */
function loadedUrlExpr(e) {
  e = unparen(e);
  if (!e) return null;
  if (e.type === 'Call') {
    const inner = unparen(e.fn);
    if (inner && inner.type === 'Call' && inner.fn.type === 'Name' && (inner.fn.name === 'loadstring' || inner.fn.name === 'load') && inner.args.length) {
      return fetchArg(inner.args[0]);
    }
  }
  return fetchArg(e);
}

const VERBS = /^(?:Get|Fetch|Load|Resolve|Parse|Build|Create|Make|Find|Read|Format|Compute|Calc(?:ulate)?|Query|Lookup|Detect|Identify)(?=[A-Z])/;
const PREDICATE = /^(?:Is|Has|Can|Should|Check|Validate|Verify|Supersede|Needs?)/;

/** `GetGameInfo` -> `gameInfo`; `FormatDuration` -> `duration`; a predicate gives null. */
function nounOf(fnName) {
  if (!fnName || PREDICATE.test(fnName)) return null;
  const m = VERBS.exec(fnName);
  return m ? sane(lowerFirst(fnName.slice(m[0].length))) : null;
}

const ENV_CALLS = { getgenv: 'genv', getfenv: 'env', getrenv: 'robloxEnv', getrawmetatable: 'rawMetatable', identifyexecutor: 'executorName', tick: 'startTime' };
const EXECUTOR_APIS = new Set(['getgenv', 'getfenv', 'setfenv', 'getrenv', 'identifyexecutor', 'getexecutorname', 'setclipboard', 'toclipboard', 'hookfunction', 'hookmetamethod', 'newcclosure', 'getrawmetatable',
  'setrawmetatable', 'setreadonly', 'make_writeable', 'syn', 'fluxus', 'request', 'http_request', 'queue_on_teleport', 'getgc', 'getconnections', 'checkcaller', 'readfile', 'writefile', 'isfile',
  'fireclickdetector', 'firesignal', 'fireproximityprompt', 'getcustomasset', 'gethui', 'cloneref', 'decompile', 'getscriptbytecode', 'loadstring']);

/** The callee of a call as text (`os.clock`, `tbl.Fn`, `obj:Method`), or null when it is not a plain chain of names. */
function describe(e) {
  e = unparen(e);
  if (!e) return null;
  if (e.type === 'Name') return e.name;
  if (e.type === 'Index' && e.key.type === 'String') { const o = describe(e.obj); return o ? `${o}.${e.key.value}` : null; }
  if (e.type === 'MethodCall') { const o = describe(e.obj); return o ? `${o}:${e.name}` : null; }
  return null;
}

// ---- the relation graph ---------------------------------------------------------------------------------------------------------------
/**
 * @param {object} chunk parsed program
 * @returns relations: { info, facts, constLists, suggestions, dependencies, functions, calls, globalsWritten, executorApis }
 */
export function mapRelations(chunk) {
  const info = analyze(chunk);
  const facts = new Map();
  const F = (v) => {
    let f = facts.get(v);
    if (!f) { f = { methods: new Set(), fields: new Set(), fieldWrites: new Map(), numericIndex: new Set(), dynamicIndex: false, dynamicStores: [], assigns: [], compound: 0, plainWrites: 0, called: 0, passedTo: [], iteratedBy: [] }; facts.set(v, f); }
    return f;
  };
  const varOfName = (n) => (n && n.type === 'Name' ? info.varOf.get(n) : null);

  const functions = [];                       // { id, line, params, node }
  const calls = new Map();                    // `${from}->${to}` -> { from, to, count }
  const dependencies = [];                    // { url, via, loaded, line, certain }
  const globalsWritten = new Map();           // key -> line
  const constLists = new Map();               // Var -> string[]
  const loopOver = new Map();                 // Var of a constant list -> [{ index: Var|null, element: Var|null }]
  const storeByIndex = new Map();             // Var of a table -> list Var it is stored into by loop index
  const urlExprs = [];                        // { node, list: Var|null }
  const keyEvidence = new Set();              // names and strings that say the script checks a key

  const note = (from, to) => {
    const k = `${from}->${to}`;
    const e = calls.get(k);
    if (e) e.count++; else calls.set(k, { from, to, count: 1 });
  };

  // pass 1: constant lists and the loops over them
  const lists = (stmt) => {
    if (stmt.type === 'Local') {
      stmt.ids.forEach((id, i) => {
        const val = stmt.values[i] && unparen(stmt.values[i]);
        if (val && val.type === 'Table' && val.fields.length >= 1 && val.fields.every((f) => f.kind === 'item' && f.value.type === 'String')
          && (val.fields.length >= 2 || /^https?:\/\//i.test(val.fields[0].value.value))) {
          const v = info.varOf.get(id);
          if (v && v.writes.length === 0) constLists.set(v, val.fields.map((f) => f.value.value));
        }
      });
    }
  };
  const scan = (node, fn) => { fn(node); forEachChild(node, (c) => scan(c, fn)); };
  scan(chunk, lists);

  const listVarOf = (e) => {
    e = unparen(e);
    if (e && e.type === 'Name') { const v = varOfName(e); return v && constLists.has(v) ? v : null; }
    if (e && e.type === 'Call' && e.fn.type === 'Name' && (e.fn.name === 'ipairs' || e.fn.name === 'pairs') && e.args.length === 1) return listVarOf(e.args[0]);
    return null;
  };
  scan(chunk, (n) => {
    if (n.type !== 'GenFor') return;
    const L = listVarOf(n.exprs[0]);
    if (!L) return;
    const idxVar = n.ids[0] ? info.varOf.get(n.ids[0]) : null;
    const elVar = n.ids[1] ? info.varOf.get(n.ids[1]) : null;
    const rec = { index: idxVar, element: elVar, stmt: n };
    if (!loopOver.has(L)) loopOver.set(L, []);
    loopOver.get(L).push(rec);
    // inside the loop: `T[index] = value` ties T to the list by position
    scan({ type: 'Do', body: n.body }, (m) => {
      if (m.type === 'Assign') {
        m.targets.forEach((t) => {
          if (t.type === 'Index' && !t.dot && t.key.type === 'Name' && idxVar && varOfName(t.key) === idxVar) {
            const T = varOfName(t.obj);
            if (T) storeByIndex.set(T, L);
          }
        });
      }
    });
  });

  // pass 2: facts, function definitions, calls, dependencies
  const defName = (stmt) => {
    if (stmt.type === 'LocalFunction') return stmt.id.name;
    if (stmt.type === 'Function') { const t = describe(stmt.target); return t ? (stmt.method ? `${t}:${stmt.method}` : t) : null; }
    return null;
  };
  const visit = (node, owner) => {
    switch (node.type) {
      case 'Function': case 'LocalFunction': {
        const id = defName(node);
        if (id) functions.push({ id, line: node.line, params: node.func.params.map((p) => p.name), node, func: node.func });
        // `function tbl.Name() ... end` stores a function in tbl just as `tbl.Name = function() ... end` does
        if (node.type === 'Function' && node.target.type === 'Index' && node.target.key.type === 'String') {
          const ov = varOfName(unparen(node.target.obj));
          if (ov) { const f = F(ov); f.fieldWrites.set(node.target.key.value, 'Func'); f.fieldFunctions = (f.fieldFunctions || 0) + 1; }
        }
        const inner = id || owner;
        // the function's own body is attributed to it
        forEachChild(node.func, (c) => visit(c, inner));
        if (node.type === 'Function' && node.target.type === 'Index') visit(node.target.obj, owner);
        return;
      }
      case 'Assign': {
        node.targets.forEach((t, i) => {
          const val = node.values[i];
          if (t.type === 'Index') {
            const o = unparen(t.obj);
            const ov = varOfName(o);
            const key = t.key.type === 'String' ? t.key.value : null;
            if (ov) {
              const f = F(ov);
              if (key !== null) f.fieldWrites.set(key, val ? unparen(val).type : 'unknown');
              else f.dynamicStores.push({ key: t.key, value: val });
            }
            // getgenv().X = ... or genv.X = ...
            const viaCall = o && o.type === 'Call' && o.fn.type === 'Name' && o.fn.name === 'getgenv';
            const viaVar = ov && ov.init && unparen(ov.init).type === 'Call' && unparen(ov.init).fn.type === 'Name' && unparen(ov.init).fn.name === 'getgenv';
            if ((viaCall || viaVar) && key !== null) globalsWritten.set(key, node.line);
            if ((viaCall || viaVar) && key === null) globalsWritten.set('<computed key>', node.line);
            if (key !== null && val && unparen(val).type === 'Func' && ov) F(ov).fieldFunctions = (F(ov).fieldFunctions || 0) + 1;
            if (key !== null && val && unparen(val).type === 'Func') {
              const d = describe(t);
              if (d) functions.push({ id: d, line: node.line, params: unparen(val).params.map((p) => p.name), node, func: unparen(val) });
            }
          } else if (t.type === 'Name') {
            const v = varOfName(t);
            if (v) {
              const bump = val && unparen(val).type === 'Binary' && unparen(val).op === '+' && varOfName(unparen(unparen(val).left)) === v && unparen(unparen(val).right).type === 'Number';
              if (bump) F(v).compound++; else { F(v).plainWrites++; if (val) F(v).assigns.push(val); }
            }
          }
        });
        break;
      }
      case 'CompoundAssign': if (node.target.type === 'Name') { const v = varOfName(node.target); if (v) F(v).compound++; } break;
      case 'MethodCall': {
        const o = unparen(node.obj);
        const v = varOfName(o);
        if (v) F(v).methods.add(node.name);
        const d = describe(node);
        if (d) note(owner || '<main>', d);
        break;
      }
      case 'String': if (KEYISH.test(node.value) && node.value.length < 32) keyEvidence.add(node.value); break;
      case 'Index': {
        if (node.key.type === 'String' && KEYISH.test(node.key.value)) keyEvidence.add(node.key.value);
        const v = varOfName(unparen(node.obj));
        if (v) {
          const f = F(v);
          if (node.key.type === 'String') f.fields.add(node.key.value);
          else if (node.key.type === 'Number') f.numericIndex.add(node.key.value);
          else f.dynamicIndex = true;
        }
        break;
      }
      case 'Call': {
        const d = describe(node.fn);
        if (d) note(owner || '<main>', d);
        const fv = varOfName(unparen(node.fn));
        if (fv) F(fv).called++;
        node.args.forEach((a, i) => { const av = varOfName(unparen(a)); if (av) F(av).passedTo.push({ callee: d, index: i }); });
        break;
      }
      case 'GenFor': {
        const L = listVarOf(node.exprs[0]);
        if (!L) {
          const iter = unparen(node.exprs[0]);
          const v = iter && iter.type === 'Name' ? varOfName(iter) : null;
          if (v) F(v).iteratedBy.push(node);
        }
        break;
      }
      default: break;
    }
    // dependencies: anything fetched
    const arg = fetchArg(node);
    if (arg) {
      const loaded = !!loadedUrlExpr(node);
      urlExprs.push({ node, arg, loaded, line: node.line });
    }
    forEachChild(node, (c) => visit(c, owner));
  };
  visit(chunk, null);

  // resolve fetched URLs: a literal, or a loop variable that walks a constant list of literals
  for (const u of urlExprs) {
    const a = unparen(u.arg);
    if (a.type === 'String') dependencies.push({ url: a.value, via: 'HttpGet', loadsCode: u.loaded, line: u.line, certain: true });
    else if (a.type === 'Name') {
      const v = varOfName(a);
      let hit = false;
      for (const [L, recs] of loopOver) {
        if (recs.some((r) => r.element === v)) {
          for (const url of constLists.get(L)) dependencies.push({ url, via: 'HttpGet', loadsCode: u.loaded, line: u.line, certain: true, list: true });
          hit = true;
        }
      }
      if (!hit) dependencies.push({ url: null, via: 'HttpGet', loadsCode: u.loaded, line: u.line, certain: false, expr: describe(a) || a.type });
    } else dependencies.push({ url: null, via: 'HttpGet', loadsCode: u.loaded, line: u.line, certain: false, expr: a.type });
  }
  // a fetch is reported once per source line and URL
  const seenDep = new Set();
  const deps = dependencies.filter((d) => { const k = `${d.url}|${d.line}|${d.via}`; if (seenDep.has(k)) return false; seenDep.add(k); return true; });

  const executorApis = [...info.globals.keys()].filter((k) => EXECUTOR_APIS.has(k)).sort();
  const freeGlobals = [...info.globals.keys()].filter((k) => !STDLIB_GLOBALS.has(k)).sort();

  for (const f of functions) if (KEYISH.test(f.id.split(/[.:]/).pop())) keyEvidence.add(f.id);
  for (const g of info.globals.keys()) if (KEYISH.test(g)) keyEvidence.add(g);
  const rel = { info, facts, constLists, loopOver, storeByIndex, keyEvidence: [...keyEvidence].sort(), dependencies: deps, functions: dedupe(functions), calls: [...calls.values()], globalsWritten, executorApis, freeGlobals };
  rel.suggestions = suggest(chunk, rel);
  return rel;
}

function dedupe(fns) {
  const seen = new Set();
  return fns.filter((f) => { if (seen.has(f.id)) return false; seen.add(f.id); return true; });
}

// ---- names from relations -------------------------------------------------------------------------------------------------------------
function suggest(chunk, rel) {
  const { info, facts, constLists, loopOver, storeByIndex } = rel;
  const best = new Map();   // Var -> suggestion
  const add = (v, name, confidence, rule, evidence) => {
    if (!v || v.isGlobal || !v.decl) return;
    const n = sane(name);
    if (!n) return;
    const cur = best.get(v);
    if (!cur || confidence > cur.confidence) best.set(v, { name: n, confidence, rule, evidence });
  };
  const varOfName = (n) => (n && n.type === 'Name' ? info.varOf.get(n) : null);
  const urlsLookLikeUrls = (L) => constLists.get(L).every((s) => /^https?:\/\//i.test(s));

  // constant lists, and what walks them
  for (const [L, recs] of loopOver) {
    const urls = urlsLookLikeUrls(L);
    add(L, urls ? 'urls' : 'items', 0.8, 'constant-list', [`a list of ${constLists.get(L).length} ${urls ? 'URLs' : 'strings'} that nothing writes to`]);
    for (const r of recs) {
      add(r.index, 'index', 0.6, 'list-walk', ['position in a constant list']);
      add(r.element, urls ? 'url' : 'item', 0.8, 'list-walk', [`one element of a list of ${urls ? 'URLs' : 'strings'}`]);
    }
  }
  for (const [T, L] of storeByIndex) {
    add(T, 'results', 0.55, 'stored-by-position', [`filled as T[i] = ... while walking a constant list, so T[n] belongs to element n`]);
    void L;
  }

  const visitStmt = (n) => {
    // ---- locals and assignments with several targets -----------------------------------------------------------------------------
    if (n.type === 'Local' || n.type === 'Assign') {
      const targets = n.type === 'Local' ? n.ids.map((id) => info.varOf.get(id)) : n.targets.map((t) => (t.type === 'Name' ? varOfName(t) : null));
      const values = n.values;
      const last = values[values.length - 1] && unparen(values[values.length - 1]);
      const spread = !!last && targets.length > values.length && (last.type === 'Call' || last.type === 'MethodCall');

      // a library downloaded from a URL is named for what the URL says
      targets.forEach((v, i) => {
        if (!v || i >= values.length || (spread && i === values.length - 1)) return;
        const val = unparen(values[i]);
        const ue = loadedUrlExpr(val);
        if (ue && unparen(ue).type === 'String') {
          const nm = nameFromUrl(unparen(ue).value);
          if (nm) add(v, nm, 0.9, 'downloaded-from', [`loadstring(game:HttpGet("${unparen(ue).value}"))()`]);
        }
        // a copy of a table slot filled from a constant list: `a, b, c = results[1], results[2], results[3]`
        if (val && val.type === 'Index' && !val.dot && val.key.type === 'Number') {
          const T = varOfName(unparen(val.obj));
          const L = T ? storeByIndex.get(T) : null;
          const list = L ? constLists.get(L) : null;
          const url = list && list[val.key.value - 1];
          const nm = url ? nameFromUrl(url) : null;
          if (nm) add(v, nm, 0.85, 'position-in-download-list', [`element ${val.key.value} of the list that was downloaded: ${url}`]);
        }
        // a call that is named for what it returns
        if (val && (val.type === 'Call' || val.type === 'MethodCall') && !(spread && i === values.length - 1)) {
          const callee = val.type === 'MethodCall' ? val.name : (unparen(val.fn).type === 'Index' && unparen(val.fn).key.type === 'String' ? unparen(val.fn).key.value : unparen(val.fn).name);
          const noun = nounOf(callee);
          if (noun) add(v, noun, 0.65, 'result-of-call', [`result of ${callee}()`]);
          if (val.type === 'Call' && unparen(val.fn).type === 'Name' && ENV_CALLS[unparen(val.fn).name]) add(v, ENV_CALLS[unparen(val.fn).name], 0.8, 'environment-call', [`${unparen(val.fn).name}()`]);
          if (val.type === 'Call') {
            const d = describe(val.fn);
            if (d === 'os.clock' || d === 'os.time' || d === 'tick') add(v, 'startTime', 0.7, 'clock', [`${d}() recorded once`]);
            if (d === 'task.spawn' || d === 'task.defer' || d === 'task.delay' || d === 'coroutine.create') add(v, 'thread', 0.7, 'thread-handle', [`${d}() returns the thread it started`]);
          }
        }
        // `uiLib.LastStep or startTime`: the field is what the value is
        if (val && val.type === 'Binary' && val.op === 'or') {
          const l = unparen(val.left);
          if (l && l.type === 'Index' && l.key.type === 'String') add(v, lowerFirst(l.key.value), 0.6, 'field-with-default', [`${l.key.value} or a default`]);
        }
        // `getfenv and getfenv(0) or {}` and similar defaults: judged by the first operand's call
        if (val && val.type === 'Binary' && val.op === 'or') {
          const l = unparen(val.left);
          const c = l && l.type === 'Binary' && l.op === 'and' ? unparen(l.right) : l;
          if (c && c.type === 'Call' && unparen(c.fn).type === 'Name' && ENV_CALLS[unparen(c.fn).name]) add(v, ENV_CALLS[unparen(c.fn).name], 0.7, 'environment-call', [`${unparen(c.fn).name}(...) or default`]);
        }
      });

      // a call that returns several values and is given as many string names: `local d, e = b:Get('MarketplaceService', 'Players')`
      if (spread && last && n.type === 'Local') {
        const strs = last.args.map((a) => unparen(a));
        const pascal = strs.every((a) => a.type === 'String' && /^[A-Z][A-Za-z0-9]+$/.test(a.value));
        const start = values.length - 1;
        if (pascal && strs.length === targets.length - start && start === 0) {
          targets.forEach((v, i) => add(v, lowerFirst(strs[i].value), 0.85, 'named-by-arguments', [`each result is requested by name: ${strs.map((s) => `"${s.value}"`).join(', ')}`]));
        }
      }

      // pcall: the first result says whether it worked, the second is what it returned
      if (spread && last && last.type === 'Call' && last.fn.type === 'Name' && (last.fn.name === 'pcall' || last.fn.name === 'xpcall') && targets.length >= 2) {
        add(targets[0], 'ok', 0.9, 'pcall-status', ['first result of pcall']);
        const f = last.args[0] && unparen(last.args[0]);
        let nm = null;
        let ev = 'second result of pcall';
        if (f && f.type === 'Func') {
          const ret = f.body.length === 1 && f.body[0].type === 'Return' && f.body[0].values.length === 1 ? unparen(f.body[0].values[0]) : null;
          if (ret) {
            if (loadedUrlExpr(ret) && !(ret.type === 'MethodCall')) { nm = 'loaded'; ev = 'what the protected function returned: a downloaded chunk run'; }
            else if (ret.type === 'MethodCall' && FETCH_METHODS.has(ret.name)) { nm = 'response'; ev = 'the protected function returns an HTTP response body'; }
            else if (ret.type === 'MethodCall' && /Decode$/.test(ret.name)) { nm = 'decoded'; ev = `the protected function returns ${ret.name}(...)`; }
            else { nm = hintFromInit(ret); ev = 'what the protected function returns'; }
          }
        } else if (f) {
          const d = describe(f);
          const last2 = d ? d.split(/[.:]/).pop() : null;
          nm = nounOf(last2) || (last2 ? lowerFirst(words(last2).length ? camel(words(last2)) : last2) + 'Result' : null);
          ev = d ? `second result of pcall(${d}, ...)` : ev;
        }
        add(targets[1], nm || 'result', nm ? 0.7 : 0.6, 'pcall-result', [ev]);
      }
    }

    // ---- a loop that walks a variable that is not a constant list --------------------------------------------------------------
    if (n.type === 'GenFor' && n.ids.length === 2) {
      const ex = unparen(n.exprs[0]);
      if (ex && ex.type === 'Name') {
        add(info.varOf.get(n.ids[0]), 'key', 0.4, 'generic-for', ['first value of a generalised for']);
        add(info.varOf.get(n.ids[1]), 'value', 0.4, 'generic-for', ['second value of a generalised for']);
      }
    }
    // a function declared as `tbl.VerbNoun(p)` takes the noun
    if ((n.type === 'Function' || n.type === 'LocalFunction')) {
      const target = n.type === 'Function' ? n.target : null;
      const fname = target ? (target.type === 'Index' && target.key.type === 'String' ? target.key.value : target.name) : n.id.name;
      const noun = nounOf(fname);
      const params = n.func.params;
      if (noun && params.length === 1) add(info.varOf.get(params[0]), noun, 0.55, 'parameter-of-named-function', [`parameter of ${fname}`]);
      const checkNoun = /^(?:Check|Validate|Verify)([A-Z].*)$/.exec(fname || '');
      if (checkNoun && params.length >= 1) add(info.varOf.get(params[0]), lowerFirst(checkNoun[1]), 0.55, 'parameter-of-named-function', [`parameter of ${fname}`]);
    }
  };
  const scan = (node) => { visitStmt(node); forEachChild(node, scan); };
  scan(chunk);

  // the same function reached through a table field: `tbl.F = function(p) ... end`
  // (statement form handled above; the assignment form gets the same treatment)
  const assignFns = (node) => {
    if (node.type === 'Assign') {
      node.targets.forEach((t, i) => {
        const val = node.values[i] && unparen(node.values[i]);
        if (t.type === 'Index' && t.key.type === 'String' && val && val.type === 'Func' && val.params.length === 1) {
          const noun = nounOf(t.key.value);
          if (noun) add(info.varOf.get(val.params[0]), noun, 0.55, 'parameter-of-named-function', [`parameter of ${t.key.value}`]);
        }
      });
    }
    forEachChild(node, assignFns);
  };
  assignFns(chunk);

  // ---- shapes of tables and counters, judged by how the whole script uses them ----------------------------------------------------------
  for (const v of info.vars) {
    if (best.has(v) && best.get(v).confidence >= 0.7) continue;
    const f = facts.get(v) || null;
    const init = v.init && unparen(v.init);
    if (!f && !init) continue;
    if (init && init.type === 'Number' && f && f.compound > 0 && f.plainWrites === 0 && v.kind === 'local') {
      add(v, 'count', 0.7, 'counter', ['starts at a number and is only ever incremented']);
      continue;
    }
    if (init && init.type === 'Table' && f) {
      const named = init.fields.length > 0 && init.fields.every((x) => x.kind === 'named' && ['Number', 'String', 'True', 'False'].includes(unparen(x.value).type));
      if (named && f.fieldWrites.size === 0) { add(v, 'config', 0.6, 'table-of-settings', [`a table of ${init.fields.length} constant fields that is only read`]); continue; }
      if (init.fields.length === 0 && f.fieldFunctions >= 1) {
        const upperConst = [...f.fieldWrites.keys()].filter((k) => /^[A-Z][A-Z0-9_]+$/.test(k)).length;
        if (upperConst >= 2 && upperConst === f.fieldWrites.size) add(v, 'handlers', 0.6, 'table-of-handlers', [`functions stored under constant-style keys: ${[...f.fieldWrites.keys()].slice(0, 4).join(', ')}`]);
        else add(v, 'helpers', 0.6, 'table-of-functions', [`${f.fieldFunctions} functions are stored in it`]);
        continue;
      }
      if (init.fields.length === 0 && f.fieldWrites.size > 0 && !f.fieldFunctions && !f.dynamicIndex && f.numericIndex.size === 0 && f.dynamicStores.length === 0) {
        add(v, 'state', 0.45, 'table-of-state', [`only named fields are written and read: ${[...f.fieldWrites.keys()].slice(0, 4).join(', ')}`]);
      }
    }
  }

  // ---- more shapes -----------------------------------------------------------------------------------------------------------------------
  const plural = (nm) => (/s$/.test(nm) ? nm : nm + 's');
  const singular = (nm) => (/ies$/.test(nm) ? nm.slice(0, -3) + 'y' : /s$/.test(nm) && !/ss$/.test(nm) ? nm.slice(0, -1) : null);
  for (const v of info.vars) {
    const init = v.init && unparen(v.init);
    // a list of records that share their field names: named for the first field
    if (init && init.type === 'Table' && init.fields.length >= 2 && init.fields.every((x) => x.kind === 'item' && unparen(x.value).type === 'Table')) {
      const keys = (t) => unparen(t.value).fields.map((x) => (x.kind === 'named' ? x.key : '')).join('|');
      const first = keys(init.fields[0]);
      if (first && init.fields.every((x) => keys(x) === first)) add(v, plural(first.split('|')[0]), 0.45, 'list-of-records', [`every element has the fields ${first.split('|').join(', ')}`]);
    }
  }
  // text built with table.insert(T, ...) and joined with table.concat(T, sep)
  const inserts = new Map();
  const concats = new Map();
  const collect = (n) => {
    if (n.type === 'Call') {
      const d = describe(n.fn);
      const a0 = n.args[0] && varOfName(unparen(n.args[0]));
      if (d === 'table.insert' && a0) inserts.set(a0, (inserts.get(a0) || 0) + 1);
      if (d === 'table.concat' && a0) { const sep = n.args[1] && unparen(n.args[1]); concats.set(a0, sep && sep.type === 'String' ? sep.value : ''); }
    }
    forEachChild(n, collect);
  };
  collect(chunk);
  for (const [v, sep] of concats) if (inserts.has(v)) add(v, sep === '\n' ? 'lines' : 'parts', 0.5, 'joined-pieces', [`pieces are added with table.insert and joined with table.concat(..., ${JSON.stringify(sep)})`]);
  // a value stored under a field of another table is named for the field: `genv.ZekeHubLoadToken = tbl`
  const stores = (n) => {
    if (n.type === 'Assign') {
      n.targets.forEach((t, i) => {
        const val = n.values[i] && unparen(n.values[i]);
        const vv = val && val.type === 'Name' ? varOfName(val) : null;
        if (vv && t.type === 'Index' && t.key.type === 'String' && t.key.value.length >= 4 && !vv.isGlobal) add(vv, lowerFirst(t.key.value), 0.55, 'stored-under-name', [`stored as ${t.key.value}`]);
      });
    }
    forEachChild(n, stores);
  };
  stores(chunk);
  // a local function called once, last, at the top level is what the script runs
  const lastStmt = chunk.body[chunk.body.length - 1];
  if (lastStmt && lastStmt.type === 'CallStmt' && lastStmt.call.type === 'Call' && lastStmt.call.fn.type === 'Name' && lastStmt.call.args.length === 0) {
    const v = varOfName(lastStmt.call.fn);
    if (v && v.kind === 'localfunc' && v.reads.length === 1) add(v, 'main', 0.5, 'entry-point', ['a local function that the script calls once, as its last statement']);
  }

  // ---- what a name says once the others are known ---------------------------------------------------------------------------------------
  const isBool = (e) => {
    e = unparen(e);
    if (!e) return false;
    if (e.type === 'True' || e.type === 'False') return true;
    if (e.type === 'Unary' && e.op === 'not') return true;
    if (e.type === 'Binary') return ['==', '~=', '<', '>', '<=', '>='].includes(e.op) || (e.op === 'and' && isBool(e.right)) || (e.op === 'or' && isBool(e.right) && isBool(e.left));
    return false;
  };
  const returnsOf = (func) => {
    const out = [];
    const go = (n) => { if (n.type === 'Func') return; if (n.type === 'Return') out.push(n); forEachChild(n, go); };
    func.body.forEach(go);
    return out;
  };
  const byId = new Map(rel.functions.map((f) => [f.id, f]));
  const fromReturns = (callee, i) => {
    const fn = byId.get(callee);
    if (!fn || !fn.func) return null;
    const rets = returnsOf(fn.func).filter((r) => r.values.length > 0);
    if (!rets.length) return null;
    const exprs = rets.map((r) => (r.values[i] ? unparen(r.values[i]) : { type: 'Nil' }));
    const present = exprs.filter((e) => e.type !== 'Nil');
    if (!present.length) return null;
    if (present.every(isBool) && exprs.every((e) => e.type === 'Nil' || isBool(e))) return { name: i === 0 ? 'success' : 'flag', why: 'every return gives a boolean here' };
    const names = present.map((e) => (e.type === 'Name' && varOfName(e) && best.get(varOfName(e)) ? best.get(varOfName(e)).name : null));
    if (names.every((x) => x && x === names[0])) return { name: names[0], why: `the function returns ${names[0]} here` };
    const texty = (e) => e.type === 'Call' || (e.type === 'Binary' && e.op === '..') || (e.type === 'Index' && e.key.type === 'String' && /err|message|reason/i.test(e.key.value)) || e.type === 'String';
    if (present.every(texty) && exprs.some((e) => e.type === 'Nil')) return { name: 'err', why: 'text or nil here, the shape of an error message' };
    return null;
  };
  const second = (n) => {
    if (n.type === 'Local' || n.type === 'Assign') {
      const targets = n.type === 'Local' ? n.ids.map((id) => info.varOf.get(id)) : n.targets.map((t) => (t.type === 'Name' ? varOfName(t) : null));
      const last = n.values[n.values.length - 1] && unparen(n.values[n.values.length - 1]);
      if (last && (last.type === 'Call' || last.type === 'MethodCall') && targets.length > 1 && n.values.length === 1) {
        const callee = last.type === 'Call' ? describe(last.fn) : describe(last);
        if (callee && !(last.fn && last.fn.type === 'Name' && /^[xp]?pcall$/.test(last.fn.name))) {
          targets.forEach((v, i) => {
            if (!v || best.has(v)) return;
            const r = fromReturns(callee, i);
            if (r) add(v, r.name, 0.6, 'returned-by', [`${callee}(): ${r.why}`]);
          });
        }
      }
      // `handler = handlers[code]`: one element of a table whose name is a plural
      n.values.forEach((val, i) => {
        const e = unparen(val);
        if (e && e.type === 'Index' && !e.dot && e.key.type !== 'Number' && targets[i]) {
          const T = varOfName(unparen(e.obj));
          const tb = T && best.get(T);
          const one = tb ? singular(tb.name) : null;
          if (one) add(targets[i], one, 0.55, 'element-of', [`looked up in ${tb.name}`]);
        }
      });
    }
    forEachChild(n, second);
  };
  second(chunk);

  // ---- results out of the map -----------------------------------------------------------------------------------------------------------------
  const out = new Map();
  for (const [v, s] of best) out.set(v.decl, { ...s, original: v.name });
  return out;
}

/** The map the renamer takes: declaration node -> { name, confidence, rule, evidence }. */
export function roleHints(chunk) {
  return mapRelations(chunk).suggestions;
}
