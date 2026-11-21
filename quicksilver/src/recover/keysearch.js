// Recovering strings that were masked with a small key the file does not contain.
//
// Some generators mask every string constant with its own one-byte key drawn from a small range and never write the key down (Zartha's
// constant protection: `bxor(byte, math.random(2, 30))`, with a decryptor that was left as a stub). The text is then not *in* the file, but it is
// not lost either: each string has only as many readings as there are keys, and the program itself says a great deal about which reading is
// right. This module ranks the readings of one masked string by the evidence for each:
//
//   1. what the program does with the string: a name it reads or writes as a global, or calls as a method, must be an identifier;
//   2. whether a reading is a name the runtime defines (the Lua standard library, the Roblox globals and common API members): such a
//      reading is decided by that alone, because a random key landing on one of them by chance is vanishingly rare;
//   3. otherwise how much a reading looks like words: a word in the common-English list (SCOWL sizes 10 and 20, src/recover/wordlist.js) is
//      cheap, any other word is priced by a character trigram model of English (src/recover/charmodel.js, built from this repository's own
//      documentation), identifiers are split at case changes and underscores, and characters text rarely holds are expensive.
//
// A reading is only *decided* when it is a known name or when it is cheaper than every other reading by a clear margin; otherwise the
// string is reported as ambiguous with its best readings, and the caller keeps it as unrecovered. Nothing here is guessed silently.

import { TRIGRAM } from './charmodel.js';
import { COMMON_WORDS } from './wordlist.js';

const N = 27;
const IDENT = /^[A-Za-z_][A-Za-z0-9_]*$/;

/** Names a Lua 5.1 / Luau / Roblox runtime defines: globals, library members, services and frequently used API members. */
export const KNOWN_NAMES = new Set([
  // Lua 5.1 and Luau globals and library tables
  'assert', 'collectgarbage', 'error', 'getmetatable', 'ipairs', 'load', 'loadstring', 'next', 'pairs', 'pcall', 'print', 'rawequal', 'rawget',
  'rawset', 'rawlen', 'select', 'setmetatable', 'tonumber', 'tostring', 'type', 'unpack', 'xpcall', 'getfenv', 'setfenv', 'newproxy', 'gcinfo',
  'require', 'string', 'table', 'math', 'os', 'io', 'debug', 'coroutine', 'bit', 'bit32', 'utf8', 'buffer', 'package', '_G', '_VERSION', '_ENV',
  // library members
  'byte', 'char', 'find', 'format', 'gmatch', 'gsub', 'len', 'lower', 'upper', 'match', 'rep', 'reverse', 'sub', 'split', 'pack', 'packsize',
  'concat', 'insert', 'remove', 'sort', 'maxn', 'foreach', 'foreachi', 'getn', 'create', 'clear', 'clone', 'freeze', 'isfrozen', 'move',
  'abs', 'ceil', 'floor', 'max', 'min', 'random', 'randomseed', 'sqrt', 'sin', 'cos', 'tan', 'huge', 'pi', 'fmod', 'modf', 'exp', 'log',
  'log10', 'pow', 'clamp', 'sign', 'round', 'noise', 'atan', 'atan2', 'asin', 'acos', 'rad', 'deg',
  'resume', 'yield', 'status', 'wrap', 'running', 'isyieldable', 'close', 'time', 'clock', 'date', 'difftime', 'traceback', 'getinfo',
  'band', 'bor', 'bxor', 'bnot', 'lshift', 'rshift', 'arshift', 'extract', 'replace', 'countlz', 'countrz', 'btest', 'lrotate', 'rrotate',
  // Roblox globals and data types
  'game', 'workspace', 'Workspace', 'script', 'plugin', 'shared', 'Instance', 'Enum', 'task', 'typeof', 'tick', 'wait', 'spawn', 'delay',
  'warn', 'elapsedTime', 'settings', 'UserSettings', 'version', 'Vector3', 'Vector2', 'Vector3int16', 'Vector2int16', 'CFrame', 'Color3',
  'ColorSequence', 'ColorSequenceKeypoint', 'NumberSequence', 'NumberSequenceKeypoint', 'NumberRange', 'UDim', 'UDim2', 'Rect', 'Ray',
  'Region3', 'TweenInfo', 'RaycastParams', 'OverlapParams', 'BrickColor', 'Random', 'DateTime', 'PhysicalProperties', 'Font', 'Axes', 'Faces',
  'new', 'fromRGB', 'fromHSV', 'fromHex', 'fromOffset', 'fromScale', 'lookAt', 'Angles', 'fromEulerAnglesXYZ', 'fromMatrix', 'defer',
  // services
  'Players', 'RunService', 'ReplicatedStorage', 'ReplicatedFirst', 'ServerStorage', 'ServerScriptService', 'StarterGui', 'StarterPack',
  'StarterPlayer', 'Lighting', 'SoundService', 'UserInputService', 'ContextActionService', 'TweenService', 'HttpService', 'TeleportService',
  'MarketplaceService', 'DataStoreService', 'CollectionService', 'Debris', 'PathfindingService', 'TextService', 'GuiService', 'CoreGui',
  'Teams', 'Chat', 'TextChatService', 'BadgeService', 'MessagingService', 'PhysicsService', 'VirtualInputManager', 'VirtualUser',
  'ProximityPromptService', 'SocialService', 'LocalizationService', 'InsertService', 'AssetService', 'GroupService', 'PolicyService',
  // members seen in most scripts
  'GetService', 'FindService', 'WaitForChild', 'FindFirstChild', 'FindFirstChildOfClass', 'FindFirstChildWhichIsA', 'FindFirstAncestor',
  'FindFirstAncestorOfClass', 'FindFirstAncestorWhichIsA', 'GetChildren', 'GetDescendants', 'IsA', 'IsDescendantOf', 'Clone', 'Destroy',
  'ClearAllChildren', 'GetAttribute', 'SetAttribute', 'GetAttributes', 'GetPropertyChangedSignal', 'GetAttributeChangedSignal',
  'Connect', 'Disconnect', 'Once', 'Wait', 'Fire', 'FireServer', 'FireClient', 'FireAllClients', 'InvokeServer', 'InvokeClient',
  'OnServerEvent', 'OnClientEvent', 'OnServerInvoke', 'OnClientInvoke', 'Event', 'Invoke', 'OnInvoke',
  'Parent', 'Name', 'ClassName', 'Changed', 'ChildAdded', 'ChildRemoved', 'DescendantAdded', 'DescendantRemoving', 'AncestryChanged',
  'LocalPlayer', 'Character', 'CharacterAdded', 'CharacterRemoving', 'PlayerAdded', 'PlayerRemoving', 'GetPlayers', 'GetPlayerFromCharacter',
  'UserId', 'DisplayName', 'Team', 'TeamColor', 'Backpack', 'PlayerGui', 'PlayerScripts', 'Kick', 'GetMouse', 'Mouse',
  'Humanoid', 'HumanoidRootPart', 'Head', 'Torso', 'UpperTorso', 'LowerTorso', 'Health', 'MaxHealth', 'WalkSpeed', 'JumpPower', 'JumpHeight',
  'Jump', 'Sit', 'Died', 'MoveTo', 'MoveDirection', 'TakeDamage', 'ChangeState', 'GetState', 'StateChanged', 'LoadAnimation', 'Animator',
  'Heartbeat', 'RenderStepped', 'Stepped', 'PreRender', 'PreSimulation', 'PostSimulation', 'BindToRenderStep', 'UnbindFromRenderStep',
  'IsClient', 'IsServer', 'IsStudio', 'InputBegan', 'InputEnded', 'InputChanged', 'IsKeyDown', 'KeyCode', 'UserInputType', 'MouseButton1Click',
  'MouseButton1Down', 'Activated', 'Touched', 'TouchEnded', 'Position', 'Size', 'CFrame', 'Orientation', 'Rotation', 'Velocity',
  'AssemblyLinearVelocity', 'Anchored', 'CanCollide', 'Transparency', 'Color', 'Material', 'Shape', 'Text', 'TextColor3', 'TextSize',
  'BackgroundColor3', 'BackgroundTransparency', 'Visible', 'Enabled', 'Value', 'Image', 'Font', 'ZIndex', 'AnchorPoint', 'Adornee',
  'Create', 'Play', 'Stop', 'Pause', 'Completed', 'Camera', 'CurrentCamera', 'Lookvector', 'LookVector', 'Magnitude', 'Unit', 'X', 'Y', 'Z',
  'HttpGet', 'GetAsync', 'PostAsync', 'RequestAsync', 'JSONEncode', 'JSONDecode', 'GenerateGUID', 'Teleport', 'TeleportToPlaceInstance',
  'Raycast', 'Instance', 'Part', 'Model', 'Folder', 'RemoteEvent', 'RemoteFunction', 'BindableEvent', 'BindableFunction', 'ScreenGui',
  'Frame', 'TextLabel', 'TextButton', 'TextBox', 'ImageLabel', 'ImageButton', 'UICorner', 'UIStroke', 'UIListLayout', 'Sound', 'Tool',
  'Highlight', 'BillboardGui', 'SurfaceGui', 'Attachment', 'Weld', 'WeldConstraint', 'Motor6D', 'BodyVelocity', 'BodyGyro', 'Script',
  'LocalScript', 'ModuleScript', 'StringValue', 'IntValue', 'NumberValue', 'BoolValue', 'ObjectValue', 'Remote', 'Remotes',
  // metamethods and common field names
  '__index', '__newindex', '__call', '__tostring', '__metatable', '__len', '__eq', '__lt', '__le', '__add', '__sub', '__mul', '__div', '__mod',
  '__pow', '__unm', '__concat', '__mode', '__gc', '__namecall', '__iter',
]);

// characters by how often written text and identifiers contain them (cost in bits, before the word model)
const PUNCT_COMMON = new Set([' ', '.', ',', ':', ';', '!', '?', '-', "'", '"', '(', ')', '/', '%', '=', '+', '*', '#', '_', '\n', '\t', '&', '<', '>', '$']);
const PUNCT_RARE = new Set(['@', '[', ']', '\\', '^', '`', '{', '|', '}', '~', '\r']);

/** Cost in bits of one lower-case word under the trigram model (with word boundaries). */
export function wordCost(w) {
  let cost = 0;
  let a = 26; let b = 26;
  for (let i = 0; i <= w.length; i++) {
    const c = i < w.length ? w.charCodeAt(i) - 97 : 26;
    if (c < 0 || c > 26) return Infinity;
    cost += TRIGRAM[(a * N + b) * N + c] / 4;
    a = b; b = c;
  }
  return cost;
}

/**
 * Cost in bits of a candidate text: words priced by the model, identifiers split at case changes, other characters by how rare they are in
 * text. Lower is more plausible. Invalid text (control characters) is Infinity.
 */
export function textCost(s) {
  if (s.length <= 12 && /^-?[0-9]+(?:\.[0-9]+)?$/.test(s) && !/^(.)\1{3,}$/.test(s)) return s.length;   // a number written as text
  // a run of one punctuation character is a separator line ("----", "===="); a run of one digit or letter is not text
  const run = /^(.)\1{3,}$/.exec(s);
  if (run) return PUNCT_COMMON.has(run[1]) && run[1] !== ' ' ? 3 + 0.25 * s.length : 3 * s.length;
  let cost = 0;
  // an opening without its closing (or the reverse) is how a wrong key reads, rarely how text is written
  for (const [o, c] of [['(', ')'], ['[', ']'], ['{', '}']]) if (s.split(o).length !== s.split(c).length) cost += 5;
  for (const q of ['"', "'"]) if ((s.split(q).length - 1) % 2) cost += 5;
  // symbols back to back ("?/#;", "$!>") are how a wrong key reads; text puts a space or a letter between them (a repeated one, "..", "--", is fine)
  for (let i = 1; i < s.length; i++) {
    const a = s[i - 1]; const b = s[i];
    if (a !== b && /[^A-Za-z0-9\s]/.test(a) && /[^A-Za-z0-9\s]/.test(b) && !/^(?:\(\)|\[\]|\{\}|\)[.,:;]|["'][,:;)\]]|[.,:;!?]["')])$/.test(a + b)) cost += 4;
  }
  // camelCase / PascalCase / ACRONYMWord / snake_case / digits
  const parts = s.match(/[A-Z]{2,}(?=[A-Z][a-z]|[^A-Za-z]|$)|[A-Z]?[a-z]+|[A-Z]+|[0-9]+|[^A-Za-z0-9]/g) || [];
  if (parts.join('') !== s) return Infinity;
  for (const p of parts) {
    if (/^[A-Za-z]+$/.test(p)) {
      if (p.length === 1) { cost += 6; continue; }                       // a lone letter between other material is how random strings look
      const w = p.toLowerCase();
      cost += COMMON_WORDS.has(w) ? Math.min(wordCost(w), 3 + 0.75 * w.length) : wordCost(w);
      if (/^[A-Z]{2,}$/.test(p) && p.length > 4) cost += 2 * (p.length - 4);  // long all-capitals runs are rare outside acronyms
    } else if (/^[0-9]+$/.test(p)) cost += 2 * p.length;
    else if (PUNCT_COMMON.has(p)) cost += p === ' ' ? 1 : 3;
    else if (PUNCT_RARE.has(p)) cost += 14;
    else {
      const code = p.charCodeAt(0);
      if (code < 32 || code === 127) return Infinity;
      cost += code >= 128 ? 8 : 10;
    }
  }
  return cost;
}

/** Cost of a candidate Lua pattern: character classes and magic characters are what patterns are made of; the rest is text. */
export function patternCost(s) {
  let cost = 0;
  const rest = s.replace(/%[acdglpsuwxACDGLPSUWX]|%[^A-Za-z0-9]|[\^$()[\].*+\-?]/g, () => { cost += 2; return ' '; });
  const t = rest.trim() ? textCost(rest.replace(/ +/g, ' ').trim()) : 0;
  return Number.isFinite(t) ? cost + t : Infinity;
}

/** Cost of a candidate format string (string.format): conversion specifiers are what it is made of; the rest is text. */
export function formatCost(s) {
  let cost = 0;
  const rest = s.replace(/%[-+ #0]*\d*(?:\.\d+)?[cdiouxXeEfgGqs%]/g, () => { cost += 1.5; return ' '; });
  if (rest === s) return Infinity;                                       // a format string has at least one specifier
  const t = rest.trim() ? textCost(rest.replace(/ +/g, ' ').trim()) : 0;
  return Number.isFinite(t) ? cost + t : Infinity;
}

const xorByte = (s, k) => { let o = ''; for (let i = 0; i < s.length; i++) o += String.fromCharCode(s.charCodeAt(i) ^ k); return o; };

/**
 * Rank the readings of one masked string.
 * @param {string} masked the string as the file holds it (one byte per character)
 * @param {{keys?: number[], role?: 'global'|'method'|'field'|'pattern'|'format'|'select'|'value', decode?: (s: string, k: number) => string, margin?: number}} [opts]
 * @returns {{text: string|null, key: number|null, decided: boolean, why: string, ranked: Array<{key: number, text: string, cost: number, known: boolean}>}}
 */
export function rankReadings(masked, opts = {}) {
  // key 0 is the string as the file holds it: a build that masks some strings leaves others plain, and the plain reading competes on the same evidence
  const keys = opts.keys || [0, ...range(2, 30)];
  const decode = opts.decode || xorByte;
  const role = opts.role || 'value';
  const margin = opts.margin ?? (role === 'pattern' || role === 'format' ? 3 : 8);
  const ranked = [];
  for (const k of keys) {
    const text = decode(masked, k);
    if (/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(text)) continue;
    const ident = IDENT.test(text);
    if ((role === 'global' || role === 'method') && !ident) continue;
    const known = KNOWN_NAMES.has(text);
    if (role === 'select' && !(text === '#' || /^-?[0-9]+$/.test(text))) continue;   // select() takes '#' or a number, nothing else
    let cost = role === 'pattern' ? Math.min(patternCost(text), textCost(text) + 4)
      : role === 'format' ? Math.min(formatCost(text), textCost(text) + 6)
        : role === 'select' ? (text === '#' ? 0 : 8)
          : Math.min(textCost(text), formatCost(text) + 3, patternCost(text) + 5);   // a string may be a format or a pattern whatever it is passed to
    if (!Number.isFinite(cost)) continue;
    if (role === 'field' && !ident) cost += 6;   // a constant key is usually a name
    ranked.push({ key: k, text, cost, known });
  }
  ranked.sort((a, b) => (b.known - a.known) || (a.cost - b.cost));
  if (!masked.length) return { text: '', key: null, decided: true, why: 'empty string', ranked };
  if (!ranked.length) return { text: null, key: null, decided: false, why: 'no key gives a readable string', ranked };
  const knownOnes = ranked.filter((r) => r.known);
  if (knownOnes.length === 1) return { text: knownOnes[0].text, key: knownOnes[0].key, decided: true, why: 'the only reading that is a name the runtime defines', ranked };
  if (knownOnes.length > 1) return { text: null, key: null, decided: false, why: `${knownOnes.length} readings are names the runtime defines`, ranked };
  const [best, second] = ranked;
  const perChar = best.cost / (masked.length + 1);   // the word model also prices the boundary after the last letter
  if (role === 'select' && best.text === '#' && (!second || second.cost - best.cost >= margin)) return { text: '#', key: best.key, decided: true, why: 'select() is called with it, and \'#\' is the only string select() accepts', ranked };
  // decided by the word model alone: short strings need a wider margin, because a few letters fit many keys (measured on the Zartha builds:
  // every wrong decision at a margin of 8 bits was a string of 3 to 7 characters)
  if (masked.length < 3) return { text: null, key: null, decided: false, why: 'too short to tell the readings apart', ranked };
  // a pattern's or a format's shape is its own evidence, not word statistics — but only when the reading has that shape (`%d+`); a plain word handed
  // to find() is decided like any other word
  const byShape = (role === 'pattern' && /%[A-Za-z%.]|[\^$*+?\[\]]/.test(best.text)) || (role === 'format' && /%[-+ #0-9.]*[a-zA-Z%]/.test(best.text));
  const need = byShape ? margin : masked.length <= 4 ? Math.max(margin, 16) : masked.length <= 8 ? Math.max(margin, 13) : margin;
  const clear = second ? second.cost - best.cost : Infinity;
  if (perChar > 5.5 && !(clear >= 24 && perChar <= 7.5)) return { text: null, key: null, decided: false, why: `no reading looks like text (best ${perChar.toFixed(1)} bits a character)`, ranked };
  if (second && second.cost - best.cost < need) return { text: null, key: null, decided: false, why: `two readings are about as plausible (“${best.text}” and “${second.text}”)`, ranked };
  return { text: best.text, key: best.key, decided: true, why: second ? `cheaper than every other reading by ${(second.cost - best.cost).toFixed(0)} bits` : 'the only readable reading', ranked };
}

function range(a, b) { const out = []; for (let i = a; i <= b; i++) out.push(i); return out; }
