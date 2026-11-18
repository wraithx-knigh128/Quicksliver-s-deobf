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
export function analyzeLuarmor(source) {
  const mentions = /luarmor/i.test(source) || /\b_bsdata\d+\b/.test(source);
  if (!mentions && !/\bscript_key\b/.test(source)) return null;
  let ast = null;
  try { ast = parse(source); } catch (e) {
    return { recognised: mentions, parsed: false, error: e.message, variants: [], note: 'The file does not parse; run the Deobfuscator first if it is wrapped in another layer.' };
  }
  const urls = [];
  walk(ast, (n) => { if (n.type === 'String' && /luarmor\.net/i.test(n.value)) urls.push({ value: n.value, line: n.line || null }); return undefined; });
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
  const loaderUrls = urls.filter((u) => /api\.luarmor\.net\/files\/v\d+\/loaders\//i.test(u.value));
  const constructedLoader = /api\.luarmor\.net\/files\/v\d+\/loaders\/["']?\s*\.\./i.test(source) || /files\/v\d+\/loaders\/"\s*\.\./.test(source);
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
      key.sources.push(v && v.type === 'String' ? `a literal (${v.value.length} characters, redacted)` : v && v.type === 'Call' ? 'the result of a call (user input, a file or a request)' : v ? `a ${v.type.toLowerCase()} expression` : 'nothing (declared)');
    });
    return undefined;
  });
  const statuses = [...new Set((source.match(/KEY_[A-Z_]{3,}/g) || []).filter((s) => STATUS.test(s)))].sort();
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
    ...(sdk ? [{ role: 'protected script', what: 'delivered by load_script after check_key accepts the key', address: null, retrieved: false, why: 'no documented interface returns a protected script; the owner already holds the source they uploaded' }] : []),
    ...loaderUrls.map((u) => ({ role: 'protected script loader', what: 'served by the service after the key check', address: u.value, retrieved: false, why: 'no documented interface returns a protected script' })),
    ...(constructedLoader && !loaderUrls.length ? [{ role: 'protected script loader', what: 'address built at run time from a script id', address: null, retrieved: false, why: 'no documented interface returns a protected script' }] : []),
  ];
  const localBytes = logic.length;
  return {
    recognised: true, parsed: true, variants,
    local: {
      bytes: localBytes, recoverable: obfuscated ? 'needs-deobfuscation' : 'full', obfuscatedBy: obfuscators, code: obfuscated ? null : logic,
      describes: [
        variants.includes('bootstrap') ? `runs a cached copy of the init script if present${cache.reads ? ' (readfile)' : ''}, otherwise downloads it${cache.writes ? ', caches it (writefile)' : ''}${cache.cleansOld ? ' and deletes older cached copies' : ''}, then runs it` : null,
        sdk ? `loads the SDK, ${key.set ? 'sets the key, ' : ''}checks it${statuses.length ? ` and handles ${statuses.length} status code${statuses.length === 1 ? '' : 's'} (${statuses.join(', ')})` : ''}, then calls load_script` : null,
        ui ? 'builds its own user interface (key entry / status)' : null,
        redactedKeys ? `the script_key literal is replaced by a placeholder in the recovered code (${redactedKeys} place${redactedKeys === 1 ? '' : 's'})` : null,
        keyLinks.length ? `points the user to a key page (${keyLinks.length} link${keyLinks.length === 1 ? '' : 's'} to ads.luarmor.net/get_key)` : null,
        obfuscated ? `the loader’s own code is obfuscated${obfuscators.length ? ` (${obfuscators.join(', ')})` : ''}: run the Deobfuscator to recover it` : null,
      ].filter(Boolean),
    },
    data: dataTables.map((d) => ({ ...d, recoverable: 'opaque', why: 'its only consumer is the init runtime, which is not in this file; what the values mean cannot be determined from the loader' })),
    remote,
    key,
    statuses,
    cache,
    operations: [
      { n: 1, name: 'Analyse the loader', status: 'done', detail: `variant${variants.length === 1 ? '' : 's'}: ${variants.join(', ')}` },
      { n: 2, name: 'Recover code present in the loader', status: obfuscated ? 'via-pipeline' : dataTables.length ? 'partial' : 'done', detail: `${obfuscated ? 'the loader’s own code is obfuscated; the Deobfuscator recovers it (its result is measured there, not assumed here)' : `the loader’s own logic (${localBytes} bytes) is recovered in full`}${dataTables.length ? `; ${dataTables.length} data table${dataTables.length === 1 ? '' : 's'} (${dataBytes} bytes of values) stay opaque` : ''}` },
      { n: 3, name: 'Retrieve the separately delivered payload', status: 'not-available', detail: 'Luarmor documents no interface that returns a protected script (its API manages keys, users and script uploads)' },
      { n: 4, name: 'Deobfuscate the retrieved payload', status: 'needs-input', detail: 'nothing was retrieved; if you own the script, paste the source you uploaded (or a build of it) into the Deobfuscator' },
      { n: 5, name: 'Validate behaviour', status: 'needs-input', detail: 'needs the original script; the loader alone does not contain it' },
    ],
    answer: `From this file: the loader’s own logic ${obfuscated ? 'is obfuscated and goes through the Deobfuscator' : 'is recovered in full'}${dataTables.length ? ', the bootstrap data is opaque' : ''}, and none of the protected script is present${variants.includes('sdk') || variants.includes('loader-url') ? ' (it is delivered by the service after a key check)' : ''}. To reconstruct the protected script, its owner has to provide it; no authorised route retrieves it from the service.`,
  };
}
