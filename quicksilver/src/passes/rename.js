// Identifier recovery.
//
// Obfuscators discard names; nothing can bring the original ones back. What can be done is to give
// every local a name that reflects how the program uses it, and to leave names that were already
// meaningful alone. All suggestions come from the code itself:
//
//   local x = game:GetService("Players")   ->  Players
//   local x = Instance.new("Part")         ->  part
//   local x = parent:WaitForChild("Gun")   ->  gun
//   for _, v in ipairs(list)               ->  index / item
//   local x = function() ... end           ->  fn
//
// A name is only ever chosen if it cannot capture an outer variable (see Var.scope.used in scope.js).

import { analyze, STDLIB_GLOBALS } from '../core/scope.js';
import { walk } from '../core/walk.js';
import { isIdentifier } from '../core/printer.js';

const CONVENTIONAL = new Set(['self', 'i', 'j', 'k', 'n', 'm', 'x', 'y', 'z', '_', 'v', 'dt', 'id', 'ok', 'err', 'fn', 'args']);

const ACRONYMS = new Set([
  'ID', 'HWID', 'JSON', 'URL', 'HTTP', 'HTTPS', 'API', 'UI', 'GUI', 'ESP', 'FPS', 'UUID', 'XML', 'HTML', 'CSS', 'SQL',
  'FOV', 'HP', 'XP', 'NPC', 'AI', 'CF', 'UTC', 'OS', 'IO', 'UDP', 'TCP', 'IP', 'RGB', 'HSV', 'XYZ', 'UV', 'VR', 'PC',
  'PVP', 'PVE', 'HUD', 'CPU', 'GPU', 'RNG', 'LOD', 'SDK', 'GUID', 'ASCII', 'UTF', 'HRP', 'MS', 'AFK', 'FFA', 'VM', 'GC',
]);
const ABBREVIATIONS = new Set(['http', 'https', 'json', 'url', 'xml', 'html', 'css', 'sql', 'rpc', 'tcp', 'udp', 'nth', 'btn', 'cfg', 'tbl', 'str', 'num', 'idx', 'obj', 'arr', 'vec', 'pos', 'dir', 'msg', 'ctx', 'cb', 'ev', 'fn', 'src', 'dst', 'tmp', 'val', 'ref', 'rng', 'prn', 'mgr', 'ctrl', 'cmd', 'plr', 'hrp', 'hum', 'gui', 'lbl', 'img', 'frm', 'cls', 'ptr']);

const hasVowel = (s) => /[aeiou]/i.test(s);
/** Longest run of consonants, counting y as one: real words have vowels often enough to keep this short. */
const consonantRun = (s) => Math.max(0, ...(s.toLowerCase().match(/[^aeiou]+/g) || []).map((r) => r.length));
const SHORT_WORDS = new Set(['To', 'Is', 'In', 'Of', 'By', 'On', 'As', 'Or', 'Id', 'Ui', 'Ok', 'At', 'If', 'No', 'Up', 'Do', 'Go', 'So', 'Be', 'We', 'Me', 'My', 'It', 'Ai', 'Hp', 'Xp', 'Fx', 'Tp', 'Cf', 'Ip', 'Os', 'Vm', 'Ex', 'Ev']);

/** Is every part of the identifier plausibly a word, an abbreviation or an acronym? */
function readableIdentifier(name) {
  const parts = name.split('_').filter(Boolean);
  if (!parts.length) return false;
  let chunks = 0;
  for (const part of parts) {
    const found = part.match(/[A-Z]+(?![a-z])|[A-Z]?[a-z]+|\d+/g) || [];
    if (found.join('') !== part) return false;
    found.forEach((c, i) => {
      chunks++;
      if (/^\d+$/.test(c)) return;
      if (/^[a-z]+$/.test(c)) {
        if (c.length <= 3 || (hasVowel(c) && consonantRun(c) <= 5)) return;
        throw new Error('no');
      }
      if (/^[A-Z][a-z]+$/.test(c)) {
        if (c.length === 2 && !SHORT_WORDS.has(c)) throw new Error('no');
        if ((hasVowel(c) && consonantRun(c) <= 5) || ABBREVIATIONS.has(c.toLowerCase())) return;
        throw new Error('no');
      }
      if (/^[A-Z]+$/.test(c)) {
        // a single capital at the very end (`...jQ`) is how random strings end; acronyms have two or more letters
        if (c.length === 1 && i === found.length - 1 && name.length >= 6 && found.length > 1) throw new Error('no');
        if (c.length === 1 || ACRONYMS.has(c)) return;
        throw new Error('no');
      }
      throw new Error('no');
    });
  }
  return chunks <= 6;
}

/** One or two characters: the kind of name a minifier hands out. Only meaningful in bulk. */
export function isShortName(name) {
  return !!name && name.length <= 2 && !CONVENTIONAL.has(name) && name !== '_';
}

/**
 * Names a human would not have chosen: random strings, il-lookalikes, one/two-letter minifier names.
 * Passes that would otherwise erase code the author wrote (inlining constants, deleting unused locals)
 * only act on variables whose names pass this test.
 */
export function isMachineName(name) {
  return name === '_' || looksObfuscated(name) || isShortName(name);
}

/** Does this identifier look machine-generated? (Strong evidence only; see isShortName for the weak one.) */
export function looksObfuscated(name) {
  if (!name || name === '_') return false;
  if (/^_+$/.test(name)) return true;
  if (/^[Il1O0_]{3,}$/.test(name)) return true;                        // lIIlIlIl, O0O0OO
  if (/^_*0x[0-9a-fA-F]+$/.test(name)) return true;                    // _0x1a2b
  if (/^_*(?:v|var|local|L|l|a|f|func|fn|u|t|tmp|temp|loc|lv|r)?_*\d+(?:_+\d+)*_*$/.test(name) && /[a-zA-Z_]/.test(name)) return true;   // v12, L_3_, local4, _12, _r0_2 (decompiled)
  if (/prometheus/i.test(name) && name.startsWith('__')) return true;
  if (name.length <= 2) return false;
  if (name.length < 5) return false;
  try { return !readableIdentifier(name); } catch { return true; }
}

// Names the runtime may bind implicitly: Lua 5.1 gives every function declared with `...` a local `arg`
// (LUA_COMPAT_VARARG), so a generated name `arg` would capture an outer variable inside such a function.
const RESERVED_NAMES = new Set(['arg', '_ENV', 'self']);

const lowerFirst = (s) => s.charAt(0).toLowerCase() + s.slice(1);

function sanitize(s) {
  const t = s.replace(/[^A-Za-z0-9_]/g, '');
  if (!t || /^\d/.test(t)) return null;
  return t.length > 24 ? t.slice(0, 24) : t;
}

/** A readable base name for a variable, judged from its initialiser, or null. */
function hintFromInit(init) {
  if (!init) return null;
  const strArg = (call, i = 0) => (call.args[i] && call.args[i].type === 'String' ? sanitize(call.args[i].value) : null);
  switch (init.type) {
    case 'Func': return 'fn';
    case 'Table': return init.fields.length && init.fields.every((f) => f.kind === 'item') ? 'list' : 'tbl';
    case 'String': return 'str';
    case 'Number': return 'num';
    case 'True': case 'False': return 'flag';
    case 'Paren': return hintFromInit(init.expr);
    case 'Binary':
      if (init.op === '..') return 'str';
      if (['+', '-', '*', '/', '%', '^'].includes(init.op)) return 'num';
      if (['==', '~=', '<', '>', '<=', '>='].includes(init.op)) return 'flag';
      return null;
    case 'Unary': return init.op === '#' ? 'count' : init.op === 'not' ? 'flag' : 'num';
    case 'Index':
      if (init.key.type === 'String') { const s = sanitize(init.key.value); return s ? lowerFirst(s) : null; }
      return null;
    case 'MethodCall': {
      if (['GetService', 'WaitForChild', 'FindFirstChild', 'FindFirstChildOfClass', 'FindFirstDescendant', 'FindFirstChildWhichIsA'].includes(init.name)) {
        const s = strArg(init);
        if (s) return init.name === 'GetService' ? s : lowerFirst(s);
      }
      if (/^Get[A-Z]/.test(init.name)) return lowerFirst(init.name.slice(3));
      if (init.name === 'Clone') return 'clone';
      if (init.name === 'Connect') return 'connection';
      return null;
    }
    case 'Call': {
      const f = init.fn;
      if (f.type === 'Index' && f.key.type === 'String') {
        const root = f.obj.type === 'Name' ? f.obj.name : '';
        if (root === 'Instance' && f.key.value === 'new') { const s = strArg(init); return s ? lowerFirst(s) : 'instance'; }
        if (root === 'string') return 'str';
        if (root === 'table' && f.key.value === 'concat') return 'str';
        if (root === 'math') return f.key.value === 'random' ? 'rnd' : 'num';
        if (/^(?:Vector3|CFrame|Color3|UDim2|Vector2|Enum)$/.test(root)) return lowerFirst(root);
        const s = sanitize(f.key.value);
        if (s && /^(new|create|make)/i.test(s) && root) return lowerFirst(sanitize(root) || 'obj');
      }
      if (f.type === 'Name') {
        if (f.name === 'require') return init.args[0] && init.args[0].type === 'Index' && init.args[0].key.type === 'String' ? lowerFirst(sanitize(init.args[0].key.value) || 'module') : 'module';
        if (f.name === 'tostring') return 'str';
        if (f.name === 'tonumber') return 'num';
        if (f.name === 'setmetatable') return 'obj';
        if (f.name === 'type') return 'kind';
        if (f.name === 'pcall') return 'ok';
        if (f.name === 'ipairs' || f.name === 'pairs') return 'iter';
      }
      return null;
    }
    case 'Name': return null;
    default: return null;
  }
}

function forInHints(stmt) {
  const call = stmt.exprs[0];
  const f = call && call.type === 'Call' && call.fn.type === 'Name' ? call.fn.name : null;
  if (f === 'ipairs') return ['index', 'item'];
  if (f === 'pairs') return ['key', 'value'];
  if (f === 'next') return ['key', 'value'];
  return [];
}

/**
 * Rename obfuscated locals in place.
 * @param {object} chunk
 * @param {{mode?: 'smart'|'all'}} [options]
 * @returns {{renamed: number}}
 */
export function renamePass(chunk, options = {}) {
  const mode = options.mode || 'smart';
  const info = analyze(chunk);
  const vars = info.vars;
  if (!vars.length) return { changed: 0, renamed: 0 };

  // Decide what counts as mangled in this script: rename everything if most names are machine-made.
  const mangled = vars.filter((v) => looksObfuscated(v.name) || isShortName(v.name)).length;
  const wholesale = mode === 'all' || mangled / vars.length > 0.5;
  // When most names are machine made even `i` or `x` carries no information; `self` and `_` always stay.
  const eligible = (v) => (wholesale ? v.name !== 'self' && v.name !== '_' : looksObfuscated(v.name));

  // Names that must not be introduced: every global used anywhere, plus the standard library.
  const usedFree = new Set([...info.globals.keys(), ...STDLIB_GLOBALS]);
  const taken = new Map();   // Var -> final name once decided
  const inScope = new Map(); // Scope -> names already given to variables declared directly in it
  const claim = (v, name) => {
    taken.set(v, name);
    if (!inScope.has(v.scope)) inScope.set(v.scope, new Set());
    inScope.get(v.scope).add(name);
  };
  for (const v of vars) if (!eligible(v)) claim(v, v.name);
  let renamed = 0;

  // Hints for loop variables.
  const loopHint = new Map();
  walk(chunk, (n) => {
    if (n.type === 'GenFor') forInHints(n).forEach((h, i) => { if (n.ids[i]) loopHint.set(n.ids[i], h); });
    if (n.type === 'NumFor') loopHint.set(n.id, 'i');
  });

  const conflicts = (v, candidate) => {
    if (usedFree.has(candidate) || RESERVED_NAMES.has(candidate)) return true;
    const sibling = inScope.get(v.scope);
    if (sibling && sibling.has(candidate)) return true;
    for (const w of v.scope.used) {
      if (w === v) continue;
      const name = taken.get(w);
      if (name === candidate) return true;
      if (name === undefined && w.isGlobal && w.name === candidate) return true;
    }
    // an eligible, not-yet-renamed variable keeps its old name until its turn
    for (const w of v.scope.used) if (w !== v && !taken.has(w) && w.name === candidate) return true;
    // declared deeper inside v's scope with the same final name would shadow it when used there
    return false;
  };

  const pick = (v) => {
    let base = null;
    if (v.kind === 'for') base = loopHint.get(v.decl) || null;
    if (!base && v.init) base = hintFromInit(v.init);
    if (!base && v.kind === 'param') base = 'param';
    if (!base && v.kind === 'localfunc') base = 'fn';
    if (!base) base = 'value';
    if (!isIdentifier(base)) base = 'value';
    // a numeric suffix is added only when the plain name would clash
    let candidate = base;
    for (let n = 1; conflicts(v, candidate); n++) candidate = base + n;
    return candidate;
  };

  for (const v of vars) {
    if (taken.has(v)) continue;
    const name = pick(v);
    claim(v, name);
    if (name !== v.name) {
      renamed++;
      v.decl.name = name;
      for (const r of v.reads) r.name = name;
      for (const w of v.writes) w.name = name;
    }
  }
  // `self` of methods is implicit, nothing to rename; declarations through Local ids were updated above.
  return { changed: renamed, renamed };
}
