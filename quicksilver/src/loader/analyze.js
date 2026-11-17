// Loader Analysis: what a loader script fetches, from where, under which conditions, and whether that payload can be obtained legitimately.
//
// A loader is a short script whose real program is not in the file: it downloads code (or a compiled chunk) when it runs and executes it. This
// module reads the loader statically. It never runs the script and never fetches anything; it answers:
//
//   * which requests the script makes (the API used, the URL as far as it can be resolved without running anything, the host);
//   * which of them flow into an execution sink (loadstring/load) and whether a decoding step sits in between;
//   * which architectures the loader uses (direct remote, HTTP client, API-backed, key/token, encoded, multi-stage, dynamic, config-first,
//     runtime-constructed, bytecode-returning, cached, asset-module) with the evidence for each;
//   * which service family it belongs to when that is recognisable;
//   * which of the six accessibility cases applies, and for every request whether — and how — the payload can be retrieved through an
//     authorised route.
//
// Retrieval itself is a separate, explicit step taken by the person using the tool (the page's link fetcher, /api/fetch, which only reaches an
// allow-list of public hosts). Nothing here sends keys anywhere, pretends to be a game client, or works around a licensing service: a payload that
// a service only hands to its own authenticated client is reported as such, and the analysis continues on what the loader itself shows.
//
// Secrets the loader carries (a `script_key`, a token in a URL) are redacted in everything this returns.

import { parse } from '../core/parser.js';
import { walk } from '../core/walk.js';

/** Hosts the deployment's link fetcher (/api/fetch) will read from; kept equal to api/_lib/safe-fetch.js ALLOWED_HOSTS (a test checks it). */
export const FETCHABLE_HOSTS = new Set([
  'raw.githubusercontent.com', 'gist.githubusercontent.com', 'github.com', 'gist.github.com', 'pastebin.com', 'rentry.co', 'paste.ee',
  'cdn.discordapp.com', 'media.discordapp.net',
]);

/** The six accessibility cases of Prompt XVIII §II. */
export const CASES = {
  1: { id: 'in-file', label: 'The payload is in the loader', retrieval: 'Nothing to retrieve: the program is in this file and goes through the normal pipeline.' },
  2: { id: 'public', label: 'The payload is at a public address', retrieval: 'It can be retrieved without credentials. Use the link fetcher (on your action) or open the address yourself and paste the file in.' },
  3: { id: 'user-key', label: 'The payload needs a key you own', retrieval: 'Only the key holder may retrieve it, through the service’s own owner tools. OMEGA NEXUS does not send keys to the service or act as its client.' },
  4: { id: 'dynamic', label: 'The address is generated when the script runs', retrieval: 'The address depends on values that exist only at run time, so it cannot be named from the file. The analysis shows the parts that are fixed.' },
  5: { id: 'transformed', label: 'The payload is encrypted or transformed', retrieval: 'What is downloaded is decoded before it runs. Once you have the downloaded file, the decoding step shown here is applied by the pipeline where it is known.' },
  6: { id: 'no-interface', label: 'No authorised interface gives the payload out', retrieval: 'The service hands the payload only to its own client. There is no documented route for a third party, so it is not retrieved; the loader’s visible structure is analysed instead.' },
};

/**
 * Service families. Each entry says how the family is recognised and what its documented access model is. A family is only listed with a claim
 * about its access model where that is publicly documented or evident from the loader; otherwise `access` says it is not established.
 */
export const LOADER_FAMILIES = [
  {
    id: 'luarmor', name: 'Luarmor',
    test: (h) => /(^|\.)luarmor\.net$/.test(h.host),
    marker: (src) => /\bscript_key\b/.test(src) && /luarmor/i.test(src),
    service: 'licensing',
    access: 'Serves protected scripts to its own loader after a key check (the loader passes `script_key`; the bootstrap caches its init script with writefile). Owners manage scripts and keys in their dashboard; no documented interface hands a protected script to a third party.',
    case: 6,
  },
  {
    id: 'panda-keys', name: 'Panda Development key system',
    test: (h) => /(^|\.)pandadevelopment\.net$/.test(h.host),
    service: 'licensing',
    access: 'A key system: the script validates a user key against the service before it continues (third-party documentation of its client library describes a key link and a key-validation call). Whether and how the protected script itself is delivered is not established from public documentation.',
    case: 3,
  },
  { id: 'github', name: 'GitHub (raw / gist)', test: (h) => /^(raw|gist)\.githubusercontent\.com$|^(gist\.)?github\.com$/.test(h.host), service: 'public-host', access: 'Public files are readable without credentials; private repositories need the owner’s token.', case: 2 },
  { id: 'pastebin', name: 'Pastebin', test: (h) => h.host === 'pastebin.com', service: 'public-host', access: 'Public and unlisted pastes are readable through their /raw/ address; private pastes are not.', case: 2 },
  { id: 'rentry', name: 'rentry', test: (h) => h.host === 'rentry.co' || h.host === 'rentry.org', service: 'public-host', access: 'Public pages have a /raw address.', case: 2 },
  { id: 'paste-ee', name: 'paste.ee', test: (h) => h.host === 'paste.ee', service: 'public-host', access: 'Public pastes have an /r/ address.', case: 2 },
  { id: 'discord-cdn', name: 'Discord attachment', test: (h) => /^(cdn\.discordapp\.com|media\.discordapp\.net)$/.test(h.host), service: 'public-host', access: 'Attachment links are readable while they are valid (they expire).', case: 2 },
  {
    id: 'panda-vault', name: 'Panda (PandAuth) Kryptic Vault',
    test: (h) => /(^|\.)vss\.pandauth\.com$/.test(h.host),
    service: 'licensing',
    access: 'Scripts are stored server-side, obfuscated and (per the vendor) AES-encrypted, and handed to a one-line loader after a key/HWID check. The documented API (X-API-Key) manages keys; no documented endpoint returns the stored script.',
    case: 6,
  },
  {
    id: 'polsec', name: 'Polsec',
    test: (h) => /(^|\.)(polsec\.sh|getpolsec\.com|polsec\.net)$/.test(h.host),
    service: 'licensing',
    access: 'A whitelist / key / HWID service that obfuscates and serves scripts. Its sites advertise a REST API for keys, scripts and users, but no endpoint documentation could be found; no documented route returns a protected script.',
    case: 6,
  },
  { id: 'roblox-asset', name: 'Roblox asset (module / model)', test: (h) => h.kind === 'asset', service: 'platform', access: 'A `require(<id>)` module or a GetObjects model is delivered by the platform to a running game. Its owner can download it with Roblox Open Cloud Asset Delivery (an API key with the legacy-asset:manage scope), which this deployment does only when its operator configured that key.', case: 6 },
];

const NETWORK_METHODS = new Set(['HttpGet', 'HttpGetAsync', 'HttpPost', 'HttpPostAsync', 'GetAsync', 'PostAsync', 'RequestAsync', 'GetObjects']);
const REQUEST_FUNCS = new Set(['request', 'http_request', 'httprequest']);
const REQUEST_LIBS = new Set(['syn', 'http', 'fluxus', 'krnl']);
const SINKS = new Set(['loadstring', 'load']);
// A strong name is a key whatever it holds; a weak name (`key`, `token`) is common in ordinary code (`local key = Enum.KeyCode.E`), so it only
// counts when it is set globally (or in getgenv()/_G) to a string that looks like a credential.
const STRONG_KEY_NAME = /^(script_?key|licen[cs]e_?key|api_?key|access_?token|auth_?token|whitelist_?key|user_?key|loader_?key)$/i;
const WEAK_KEY_NAME = /^(key|token|license|licence|auth|pass(word)?)$/i;
const CREDENTIAL = /^[A-Za-z0-9_\-.]{12,}$/;
const KEY_PARAM = /([?&](?:key|script_key|token|access_token|auth|license|hwid|apikey|api_key)=)([^&#]*)/gi;
const HWID = /\b(gethwid|get_hwid|GetClientId|RbxAnalyticsService|identifyexecutor|getexecutorname)\b/;
const DECODERS = /^(base64|b64|decode|decrypt|decompress|inflate|unzip|unpack|deserialize|xor|crypt|lz4|lzw|zlib)/i;

const unparen = (e) => (e && e.type === 'Paren' ? unparen(e.expr) : e);
const nameOf = (e) => { const x = unparen(e); return x && x.type === 'Name' ? x.name : null; };
const redactValue = (v) => `<redacted ${String(v).length} chars>`;
const redactUrl = (u) => String(u).replace(KEY_PARAM, (m, k, v) => k + (v ? redactValue(v) : ''));

/** The dotted name of a callee (`syn.request`, `game.HttpGet`), or null. */
function calleeName(fn) {
  const x = unparen(fn);
  if (!x) return null;
  if (x.type === 'Name') return x.name;
  if (x.type === 'Index' && x.key && x.key.type === 'String') { const o = calleeName(x.obj); return o ? `${o}.${x.key.value}` : `?.${x.key.value}`; }
  return null;
}

/** Collect simple bindings: `local u = <expr>` and `u = <expr>` at any depth, first one wins (enough for loaders, which are short). */
function bindings(ast) {
  const env = new Map();
  walk(ast, (n) => {
    if (n.type === 'Local') n.ids.forEach((id, i) => { if (n.values[i] && !env.has(id.name)) env.set(id.name, n.values[i]); });
    if (n.type === 'Assign') n.targets.forEach((t, i) => { if (t.type === 'Name' && n.values[i] && !env.has(t.name)) env.set(t.name, n.values[i]); });
  });
  return env;
}

/**
 * Resolve an expression to a URL shape without running anything.
 * Returns { kind: 'literal'|'constructed'|'encoded'|'dynamic', value?, template, holes: [descriptions] }.
 */
export function resolveUrl(expr, env, depth = 0) {
  const holes = [];
  let encoded = false;
  const go = (e, d) => {
    const x = unparen(e);
    if (!x || d > 8) { holes.push('?'); return '{?}'; }
    switch (x.type) {
      case 'String': return x.value;
      case 'Number': return String(x.value);
      case 'Binary': if (x.op === '..') return go(x.left, d + 1) + go(x.right, d + 1); break;
      case 'Interp': return x.parts.map((p) => (typeof p === 'string' ? p : go(p, d + 1))).join('');
      case 'Name':
        if (env.has(x.name) && unparen(env.get(x.name)) !== x) return go(env.get(x.name), d + 1);
        holes.push(x.name); return `{${x.name}}`;
      case 'Call': case 'MethodCall': {
        const cn = x.type === 'MethodCall' ? x.name : calleeName(x.fn) || '';
        // string.format("https://%s/x", a) / ("..."):format(a)
        if (/(^|\.)format$/.test(cn)) {
          const fmt = x.type === 'MethodCall' ? unparen(x.obj) : unparen(x.args[0]);
          const rest = x.type === 'MethodCall' ? x.args : x.args.slice(1);
          if (fmt && fmt.type === 'String') { let i = 0; return fmt.value.replace(/%[sdq]/g, () => go(rest[i++], d + 1)); }
        }
        if (/(^|\.)concat$/.test(cn) && x.args[0] && unparen(x.args[0]).type === 'Table') return unparen(x.args[0]).fields.map((f) => go(f.value, d + 1)).join('');
        if (/(^|\.)char$/.test(cn) && x.args.every((a) => unparen(a).type === 'Number')) { encoded = true; return x.args.map((a) => String.fromCharCode(unparen(a).value)).join(''); }
        if (/(^|\.)(UrlEncode|urlencode|escape)$/.test(cn)) { holes.push('url-encoded value'); return '{urlencoded}'; }
        if (DECODERS.test(cn.split('.').pop())) { encoded = true; holes.push(`${cn}(…)`); return `{${cn}(…)}`; }
        holes.push(`${cn || 'call'}(…)`); return `{${cn || 'call'}(…)}`;
      }
      case 'Index': { const cn = calleeName(x); holes.push(cn || 'index'); return `{${cn || 'index'}}`; }
      default: break;
    }
    holes.push(x.type); return `{${x.type}}`;
  };
  const template = go(expr, depth);
  const kind = holes.length === 0 ? (encoded ? 'encoded' : 'literal') : encoded ? 'encoded' : /^https?:\/\/[^{/]+\//i.test(template) || /^https?:\/\/[^{]+$/i.test(template) ? 'constructed' : 'dynamic';
  return { kind, template, value: holes.length === 0 ? template : null, holes };
}

function hostOf(url) {
  const m = /^https?:\/\/([^/:?#{]+)/i.exec(url || '');
  return m ? m[1].toLowerCase() : null;
}

function familyFor(req) {
  return LOADER_FAMILIES.find((f) => f.test(req)) || null;
}

/** Find every network request in the AST and describe it. */
function findRequests(ast, env) {
  const out = [];
  walk(ast, (n) => {
    let api = null;
    let urlExpr = null;
    let kind = 'http';
    if (n.type === 'MethodCall' && NETWORK_METHODS.has(n.name)) {
      api = `${calleeName(n.obj) || (unparen(n.obj).type === 'Call' ? `${calleeName(unparen(n.obj).fn) || '…'}(…)` : '…')}:${n.name}`;
      urlExpr = n.name === 'RequestAsync' ? tableField(n.args[0], ['Url', 'url']) : n.args[0];
      if (n.name === 'GetObjects') kind = 'asset';
    } else if (n.type === 'Call') {
      const cn = calleeName(n.fn) || '';
      const last = cn.split('.').pop();
      if (REQUEST_FUNCS.has(cn) || (REQUEST_LIBS.has(cn.split('.')[0]) && last === 'request')) { api = cn; urlExpr = tableField(n.args[0], ['Url', 'url', 'URL']); }
      else if (/^(game|\?)\.(HttpGet|HttpGetAsync)$/.test(cn)) { api = cn; urlExpr = n.args[1]; }
      else if (cn === 'require' && n.args[0] && unparen(n.args[0]).type === 'Number') { api = 'require'; kind = 'asset'; urlExpr = n.args[0]; }
    }
    if (!api) return;
    const shape = urlExpr ? resolveUrl(urlExpr, env) : { kind: 'dynamic', template: '{?}', holes: ['no address argument'], value: null };
    if (kind === 'asset') {
      const id = shape.template.replace(/^rbxassetid:\/\//, '');
      shape.template = `rbxassetid://${id}`;
    }
    const headers = n.type === 'Call' ? tableField(n.args[0], ['Headers', 'headers']) : null;
    const authHeader = headers && unparen(headers).type === 'Table' && unparen(headers).fields.some((f) => f.kind === 'named' && /^(authorization|x-api-key|x-auth-token|cookie)$/i.test(f.key));
    out.push({ node: n, api, kind, line: n.line || null, shape, authHeader: !!authHeader });
  });
  return out;
}

function tableField(e, keys) {
  const t = unparen(e);
  if (!t || t.type !== 'Table') return null;
  const f = t.fields.find((x) => (x.kind === 'named' && keys.includes(x.key)) || (x.kind === 'keyed' && unparen(x.key).type === 'String' && keys.includes(unparen(x.key).value)));
  return f ? f.value : null;
}

/** For each request: does its result reach loadstring/load (directly, through a local, or through a decoding call first)? */
function sinkFlow(ast, requests, env) {
  const contains = (root, target) => { let hit = false; walk(root, (m) => { if (m === target) { hit = true; return false; } return !hit; }); return hit; };
  // names whose value is (or contains) a request result
  const carriers = new Map();
  for (const [name, val] of env) for (const r of requests) if (contains(val, r.node)) carriers.set(name, r);
  const sinks = [];
  walk(ast, (n) => {
    if (n.type !== 'Call' || !SINKS.has(nameOf(n.fn)) || !n.args[0]) return;
    const arg = n.args[0];
    for (const r of requests) {
      let via = null;
      if (contains(arg, r.node)) via = 'direct';
      else walk(arg, (m) => { if (!via && m.type === 'Name' && carriers.get(m.name) === r) via = `through ${m.name}`; });
      if (!via) continue;
      // something between the request and the sink that is not just the request: a decode / decrypt step
      let top = unparen(arg);
      // reading the body of a response (`r.Body`, `res.body`) is not a decoding step
      while (top && top.type === 'Index' && top.key && top.key.type === 'String' && /^(Body|body|Content|content|data|Data)$/.test(top.key.value)) top = unparen(top.obj);
      const wrapped = top !== r.node && !(top.type === 'Name' && carriers.get(top.name) === r && unparen(env.get(top.name)) === r.node) && !(top.type === 'Call' && /^(readfile)$/.test(calleeName(top.fn) || ''));
      const decoder = wrapped ? (top.type === 'Call' ? calleeName(top.fn) : top.type === 'MethodCall' ? `:${top.name}` : top.type) : null;
      sinks.push({ request: r, sink: nameOf(n.fn), line: n.line || null, via, decoder });
    }
  });
  return sinks;
}

/** Key / token / HWID markers, with values redacted. */
function authMarkers(ast, source, requests) {
  const markers = [];
  walk(ast, (n) => {
    const targets = n.type === 'Assign' ? n.targets : n.type === 'Local' ? n.ids : [];
    targets.forEach((t, i) => {
      const key = t.type === 'Name' || t.type === 'Id' ? t.name : t.type === 'Index' && t.key && t.key.type === 'String' ? t.key.value : null;
      if (!key) return;
      const v = unparen(n.values[i]);
      const global = n.type === 'Assign' && (t.type === 'Name' || (t.type === 'Index' && /^(getgenv|_G|shared|genv)$/.test(calleeName(t.obj) || (unparen(t.obj).type === 'Call' ? calleeName(unparen(t.obj).fn) : '') || '')));
      if (!STRONG_KEY_NAME.test(key) && !(WEAK_KEY_NAME.test(key) && global && v && v.type === 'String' && CREDENTIAL.test(v.value))) return;
      const where = t.type === 'Index' ? `${calleeName(t.obj) || '…'}.${key}` : key;
      markers.push({ kind: 'key-variable', name: where, line: n.line || null, value: v && v.type === 'String' ? redactValue(v.value) : v ? `<${v.type}>` : null, supplied: !!(v && v.type === 'String' && v.value.length) });
    });
  });
  for (const r of requests) {
    if (KEY_PARAM.test(r.shape.template)) markers.push({ kind: 'key-in-url', name: (r.shape.template.match(KEY_PARAM) || []).map((m) => m.split('=')[0].slice(1)).join(', '), line: r.line, value: null, supplied: false });
    KEY_PARAM.lastIndex = 0;
    if (r.authHeader) markers.push({ kind: 'auth-header', name: 'Authorization / API-key header', line: r.line, value: null, supplied: false });
  }
  const hw = source.match(HWID);
  if (hw) markers.push({ kind: 'device-binding', name: hw[1], line: null, value: null, supplied: false });
  return markers;
}

/** Does the file itself hold a program (rather than only fetching one)? */
function payloadInFile(ast, source, requests) {
  let bigString = 0;
  let numArray = 0;
  walk(ast, (n) => {
    if (n.type === 'String' && n.value.length > bigString) bigString = n.value.length;
    if (n.type === 'Table' && n.fields.length >= 64 && n.fields.every((f) => f.kind === 'item' && unparen(f.value).type === 'Number')) numArray = Math.max(numArray, n.fields.length);
  });
  const bytecode = /\x1bLua/.test(source);
  const statements = (ast.body || []).length;
  let nodes = 0;
  walk(ast, () => { nodes++; });
  const kinds = [];
  // a script that makes requests but also has a program of its own (it loads a UI library, say) is not "only a loader"
  const ownProgram = requests.length > 0 && (statements > 15 || nodes > 400);
  if (ownProgram) kinds.push(`its own program (${statements} top-level statements)`);
  if (bytecode) kinds.push('compiled chunk');
  if (bigString >= 2000) kinds.push(`string of ${bigString} characters`);
  if (numArray) kinds.push(`array of ${numArray} numbers`);
  return { present: kinds.length > 0 || (requests.length === 0 && statements > 0), ownProgram, kinds, bytes: source.length };
}

/**
 * Analyse a loader. `source` is the script (binary string). Returns plain data (structured-clone safe).
 * @param {string} source
 * @param {{ origin?: string, depth?: number }} [options] origin: where this text came from (for stages), depth: stage number
 */
export function analyzeLoader(source, options = {}) {
  let ast;
  try { ast = parse(source); } catch (e) {
    return { ok: true, parsed: false, isLoader: false, error: e.message, requests: [], architectures: [], families: [], auth: { required: false, markers: [] },
      payload: { present: true, kinds: ['text that does not parse'], bytes: source.length }, case: { n: 1, ...CASES[1] }, alsoApplies: [], explanation: ['The text does not parse as Lua, so it is not read as a loader; the normal pipeline handles it.'], stage: options.depth || 0 };
  }
  const env = bindings(ast);
  const found = findRequests(ast, env);
  const flows = sinkFlow(ast, found, env);
  const auth = authMarkers(ast, source, found);
  const payload = payloadInFile(ast, source, found);

  const requests = found.map((r, i) => {
    const host = r.kind === 'asset' ? null : hostOf(r.shape.template);
    const fam = familyFor({ host: host || '', kind: r.kind });
    const flow = flows.filter((f) => f.request === r);
    const executes = flow.length > 0;
    const decoder = flow.map((f) => f.decoder).find(Boolean) || null;
    const retrieval = retrievalFor({ shape: r.shape, host, family: fam, auth, kind: r.kind, providers: options.providers || [] });
    return {
      id: i, api: r.api, kind: r.kind, line: r.line,
      url: r.shape.value ? redactUrl(r.shape.value) : null,
      template: redactUrl(r.shape.template),
      urlKind: r.shape.kind, holes: r.shape.holes,
      host, family: fam ? fam.id : null, familyName: fam ? fam.name : null,
      executes, sink: flow[0] ? flow[0].sink : null, decoder,
      retrieval,
    };
  });

  // families: by host, plus marker-only recognition (a Luarmor bootstrap that names no host literally)
  const famIds = new Set(requests.map((r) => r.family).filter(Boolean));
  for (const f of LOADER_FAMILIES) if (f.marker && f.marker(source)) famIds.add(f.id);
  const families = [...famIds].map((id) => { const f = LOADER_FAMILIES.find((x) => x.id === id); return { id, name: f.name, service: f.service, access: f.access, case: f.case }; });

  const arch = architectures({ ast, source, requests, flows, auth, payload, env });
  const isLoader = requests.length > 0;
  const { primary, also, explanation } = decideCase({ requests, families, auth, payload, arch, isLoader });

  return {
    ok: true, parsed: true, isLoader, stage: options.depth || 0, origin: options.origin || null,
    requests, architectures: arch, families,
    auth: { required: auth.some((m) => m.kind !== 'device-binding') || families.some((f) => f.service === 'licensing'), deviceBound: auth.some((m) => m.kind === 'device-binding'), markers: auth },
    payload, case: { n: primary, ...CASES[primary] }, alsoApplies: also.map((n) => ({ n, ...CASES[n] })), explanation,
  };
}

function retrievalFor({ shape, host, family, auth, kind, providers = [] }) {
  if (kind === 'asset' && providers.includes('roblox-asset') && /^rbxassetid:\/\/\d+$/.test(shape.template)) {
    return { possible: true, route: 'provider:roblox-asset', reason: 'The operator of this deployment configured a Roblox Open Cloud key: the asset is downloaded with the owner\u2019s credential through the documented Asset Delivery API (only assets that key may access).' };
  }
  if (kind === 'asset') return { possible: false, route: 'none', reason: 'A platform asset is delivered to a running game, not to this tool.' };
  if (family && family.case === 6) return { possible: false, route: 'none', reason: `${family.name}: ${family.access}` };
  if (family && family.case === 3) return { possible: false, route: 'owner', reason: `${family.name}: only the key holder may obtain what it protects, through the service’s own tools.` };
  if (shape.kind === 'dynamic') return { possible: false, route: 'none', reason: `The address is only known at run time (it depends on ${shape.holes.slice(0, 3).join(', ')}).` };
  if (shape.kind === 'constructed') return { possible: false, route: 'manual', reason: `Part of the address is computed at run time (${shape.holes.slice(0, 3).join(', ')}). If you know the full address and may access it, fetch it yourself.` };
  const keyed = KEY_PARAM.test(shape.template); KEY_PARAM.lastIndex = 0;
  if (keyed || auth.some((m) => m.kind === 'auth-header')) return { possible: false, route: 'owner', reason: 'The request carries a key or token. Only its owner may use it, through the service’s own tools.' };
  if (!host) return { possible: false, route: 'none', reason: 'No host could be read from the address.' };
  if (FETCHABLE_HOSTS.has(host)) return { possible: true, route: 'link-fetcher', reason: `${host} is a public host the link fetcher reads from; it is fetched only when you ask.` };
  return { possible: false, route: 'manual', reason: `${host} is not on this deployment’s fetch list. If the address is public and you may access it, open it yourself and paste the file in.` };
}

function architectures({ source, requests, flows, auth, payload, env }) {
  const out = [];
  const add = (id, label, evidence) => out.push({ id, label, evidence: evidence.filter(Boolean).slice(0, 4) });
  const executed = requests.filter((r) => r.executes);
  if (executed.some((r) => r.urlKind === 'literal' && !r.decoder)) add('direct-remote', 'Direct remote loader', executed.filter((r) => r.urlKind === 'literal').map((r) => `line ${r.line}: ${r.sink}(${r.api}("${r.url}"))`));
  if (requests.some((r) => /request$/.test(r.api) || /:RequestAsync$/.test(r.api))) add('http-client', 'HTTP-client request', requests.filter((r) => /request$/i.test(r.api)).map((r) => `line ${r.line}: ${r.api}{ Url = ${r.template} }`));
  if (requests.some((r) => /\/api\/|\/v\d+\//i.test(r.template)) || /JSONDecode/.test(source)) add('api-backed', 'API-backed loader', [...requests.filter((r) => /\/api\/|\/v\d+\//i.test(r.template)).map((r) => `versioned/API path: ${r.template}`), /JSONDecode/.test(source) && 'decodes a JSON response']);
  if (auth.some((m) => m.kind !== 'device-binding')) add('token-auth', 'Key / token authenticated', auth.filter((m) => m.kind !== 'device-binding').map((m) => `${m.kind}: ${m.name}${m.value ? ` = ${m.value}` : ''}`));
  if (auth.some((m) => m.kind === 'device-binding')) add('device-bound', 'Bound to the device', auth.filter((m) => m.kind === 'device-binding').map((m) => `uses ${m.name}`));
  if (requests.some((r) => r.urlKind === 'encoded') || executed.some((r) => r.decoder)) add('encoded', 'Encoded / compressed transport', [...requests.filter((r) => r.urlKind === 'encoded').map((r) => `the address is encoded: ${r.template}`), ...executed.filter((r) => r.decoder).map((r) => `the download goes through ${r.decoder} before ${r.sink}`)]);
  if (executed.length > 1) add('multi-stage', 'Multi-stage', executed.map((r) => `stage fetched on line ${r.line}: ${r.template}`));
  if (requests.some((r) => r.urlKind === 'dynamic')) add('dynamic', 'Dynamic address', requests.filter((r) => r.urlKind === 'dynamic').map((r) => `${r.template} (depends on ${r.holes.slice(0, 3).join(', ')})`));
  if (requests.some((r) => r.urlKind === 'constructed')) add('runtime-constructed', 'Address built at run time', requests.filter((r) => r.urlKind === 'constructed').map((r) => `${r.template}`));
  const config = /getgenv\(\)\s*\.\s*\w+\s*=|_G\s*\.\s*\w+\s*=|getgenv\(\)\s*\[/.test(source);
  if (config && requests.length) add('config-first', 'Configuration first', ['sets getgenv()/_G values before it loads the payload']);
  if (/\bwritefile\b/.test(source) && /\breadfile\b|\bisfile\b/.test(source) && requests.length) add('cached', 'Cached on disk', ['keeps a downloaded copy with writefile and reads it back with readfile']);
  if (requests.some((r) => r.kind === 'asset')) add('asset-module', 'Platform asset module', requests.filter((r) => r.kind === 'asset').map((r) => `${r.api}(${r.template})`));
  if (/\\27Lua|\x1bLua/.test(source)) add('bytecode-returning', 'Compiled chunk', ['the file carries a compiled Lua chunk']);
  if (payload.present && requests.length === 0) add('payload-in-file', 'Payload in the file', payload.kinds.length ? payload.kinds : ['the code is in the file']);
  return out;
}

function decideCase({ requests, families, auth, payload, arch, isLoader }) {
  const explanation = [];
  const also = new Set();
  if (!isLoader) {
    explanation.push('The script makes no network request, so whatever it runs is in the file itself.');
    return { primary: 1, also: [], explanation };
  }
  const executed = requests.filter((r) => r.executes);
  const relevant = executed.length ? executed : requests;
  const licensing = families.find((f) => f.service === 'licensing');
  const keyed = arch.some((a) => a.id === 'token-auth');
  const dynamic = relevant.some((r) => r.urlKind === 'dynamic' || r.urlKind === 'constructed');
  const transformed = arch.some((a) => a.id === 'encoded') || payload.kinds.includes('compiled chunk');
  const asset = relevant.some((r) => r.kind === 'asset');
  if (keyed) also.add(3);
  if (dynamic) also.add(4);
  if (transformed) also.add(5);
  if (payload.kinds.length) also.add(1);
  if (payload.ownProgram) explanation.push('The file also carries a program of its own; its requests load libraries or further stages. That program goes through the normal pipeline.');
  let primary;
  if (licensing) { primary = licensing.case; explanation.push(`It is a ${licensing.name} loader. ${licensing.access}`); if (keyed) explanation.push('The loader expects a key; a key identifies its holder to the service and is not a licence for this tool to retrieve the script.'); }
  else if (asset && relevant.some((r) => r.kind === 'asset' && r.retrieval.possible)) { primary = 3; explanation.push('It loads a platform asset. This deployment has its operator\u2019s Roblox Open Cloud key, so the owner\u2019s assets can be downloaded through the documented Asset Delivery API.'); }
  else if (asset) { primary = 6; explanation.push('It loads a platform asset, which only a running game receives (or its owner, through Roblox Open Cloud with their own API key).'); }
  else if (keyed) { primary = 3; explanation.push('The request carries a key or token, so only its owner may retrieve the payload.'); }
  else if (relevant.some((r) => r.urlKind === 'dynamic')) { primary = 4; explanation.push('The address depends on values that exist only when the script runs.'); }
  else if (relevant.some((r) => r.urlKind === 'constructed')) { primary = 4; explanation.push('Part of the address is computed when the script runs.'); }
  else if (transformed) { primary = 5; explanation.push('The download is decoded before it runs; retrieving it gives the encoded form, which the pipeline then decodes where the encoding is known.'); }
  else { primary = 2; explanation.push('Every address it loads from is a fixed public address.'); }
  also.delete(primary);
  const fetchable = relevant.filter((r) => r.retrieval.possible);
  if (fetchable.length) explanation.push(`${fetchable.length} of its address${fetchable.length === 1 ? '' : 'es'} can be fetched with the link fetcher when you ask; each download is kept as a separate stage and analysed the same way.`);
  else explanation.push('Nothing it loads can be fetched by this tool; the analysis is of the loader’s visible structure.');
  return { primary, also: [...also].sort(), explanation };
}

/**
 * Classify a downloaded stage before it goes into the pipeline: is it Lua text, a compiled chunk, a web page, or another loader?
 * @param {string} text binary string of the downloaded bytes
 */
export function classifyStage(text) {
  if (text.charCodeAt(0) === 27) return { kind: 'bytecode', label: 'a compiled Lua chunk', next: 'decompile' };
  if (/^\s*<(!doctype|html)/i.test(text)) return { kind: 'html', label: 'a web page, not a script', next: 'none' };
  let ctrl = 0;
  const n = Math.min(text.length, 4096);
  for (let i = 0; i < n; i++) { const c = text.charCodeAt(i); if (c < 9 || (c > 13 && c < 32)) ctrl++; }
  if (n && ctrl / n > 0.05) return { kind: 'binary', label: 'binary data that is not Lua text', next: 'none' };
  const a = analyzeLoader(text);
  if (a.isLoader) return { kind: 'loader', label: 'another loader (a further stage)', next: 'loader', analysis: a };
  return { kind: 'script', label: a.parsed ? 'a Lua script' : 'text that does not parse as Lua', next: 'pipeline' };
}
