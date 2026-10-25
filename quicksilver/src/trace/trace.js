// Behavioural trace: run a script in the sandbox against a stand-in Roblox / executor environment and
// write down what it does.
//
// When the code cannot be read statically (a virtual machine, run-time decryption), what it does can often
// still be observed: which services it asks for, which objects it creates, which properties it sets, which
// URLs it requests, which chunks it loads. The tracer records exactly that and renders it as a short Lua
// listing. That listing is NOT the original source (names, structure and everything the script did not do
// during this run are gone); it is a verified description of one execution.
//
// Safety: this is the only part of QuickSilver that executes a script, and it does so only when asked. The
// script runs in QuickSilver's own interpreter (sandbox/), under fuel, time and output limits, and the only
// things it can reach are the mock objects built here. Nothing is fetched, written or evaluated by the host.

import { LuaTable, LuaUserdata, NativeFunction, LuaFunction, LuaError, SandboxLimit, isFunction, typeName } from '../sandbox/value.js';
import { createMachine, classify } from '../sandbox/sandbox.js';
import { compileSource, callValue } from '../sandbox/interp.js';
import { quoteString, formatNumber, isIdentifier } from '../core/printer.js';
import { LuaSyntaxError } from '../core/parser.js';
import { readsAsText } from '../sandbox/numeric.js';

const nf = (name, fn) => new NativeFunction(name, fn);

/** Roots that exist as objects: reading from them yields further mock objects. */
const OBJECT_ROOTS = ['game', 'workspace', 'script', 'Enum', 'shared', 'plugin'];
/** Constructors of value types: calling them yields an inline expression, not a variable. */
const VALUE_TYPES = ['Vector3', 'Vector2', 'Vector3int16', 'Vector2int16', 'CFrame', 'Color3', 'UDim2', 'UDim', 'BrickColor', 'TweenInfo', 'Rect',
  'Ray', 'NumberRange', 'NumberSequence', 'NumberSequenceKeypoint', 'ColorSequence', 'ColorSequenceKeypoint', 'Region3', 'Random', 'Font',
  'OverlapParams', 'RaycastParams', 'PhysicalProperties', 'DateTime', 'Axes', 'Faces'];
/** Namespaces supplied by Roblox or by script executors: tables whose members are recorded functions. */
const NAMESPACES = ['task', 'syn', 'fluxus', 'krnl', 'http', 'Drawing', 'debug_ext'];
/** Global functions supplied by Roblox, executors or the Lua base library. They are recorded, never performed. */
const CALLABLE_ROOTS = ['hookfunction', 'hookmetamethod', 'newcclosure', 'checkcaller', 'clonefunction',
  'cloneref', 'setclipboard', 'toclipboard', 'queue_on_teleport', 'queueonteleport', 'writefile', 'readfile', 'isfile', 'isfolder', 'makefolder',
  'delfile', 'delfolder', 'listfiles', 'appendfile', 'loadfile', 'dofile', 'getconnections', 'firesignal', 'fireclickdetector', 'firetouchinterest',
  'fireproximityprompt', 'getrawmetatable', 'setrawmetatable', 'setreadonly', 'isreadonly', 'make_writeable', 'make_readonly', 'decompile',
  'getscripts', 'getgc', 'getinstances', 'getnilinstances', 'getloadedmodules', 'getsenv', 'gethui', 'protect_gui', 'rconsoleprint',
  'rconsolewarn', 'rconsoleclear', 'rconsolecreate', 'printconsole', 'saveinstance', 'mouse1click', 'mouse1press', 'mouse1release', 'mousemoverel',
  'mousemoveabs', 'keypress', 'keyrelease', 'keyclick', 'iscclosure', 'islclosure', 'getthreadidentity', 'setthreadidentity', 'getcustomasset',
  'isrbxactive', 'replicatesignal', 'getcallingscript', 'getnamecallmethod', 'setnamecallmethod', 'getproperties', 'gethiddenproperty',
  'sethiddenproperty', 'isnetworkowner', 'setfpscap', 'getfpscap', 'messagebox', 'require', 'printidentity'];
/** Methods that look something up; their result is written inline (`a:WaitForChild("B")`) instead of being given a name. */
const LOOKUPS = new Set(['WaitForChild', 'FindFirstChild', 'FindFirstChildOfClass', 'FindFirstChildWhichIsA', 'FindFirstAncestor', 'FindFirstAncestorOfClass',
  'FindFirstAncestorWhichIsA', 'FindFirstDescendant', 'GetChildren_', 'GetAttribute', 'GetPropertyChangedSignal', 'GetAttributeChangedSignal', 'IsA', 'IsDescendantOf']);
const LIST_METHODS = new Set(['GetPlayers', 'GetChildren', 'GetDescendants', 'GetTouchingParts', 'GetPartBoundsInBox', 'GetPartBoundsInRadius', 'GetPartsInPart', 'GetAttributes', 'GetEnumItems']);
const HTTP_METHODS = new Set(['HttpGet', 'HttpGetAsync', 'GetAsync', 'HttpPost', 'HttpPostAsync', 'PostAsync', 'RequestAsync']);
const SPAWNERS = new Set(['spawn', 'delay', 'defer', 'Connect', 'connect', 'Once', 'CharacterAdded', 'ChildAdded', 'Activated', 'MouseButton1Click']);

const LIMITS = { fuel: 40_000_000, timeMs: 8_000, maxEvents: 4000, maxWaits: 400, handlerWaits: 40, maxHandlers: 60, maxLayers: 24 };
const KEYWORDS = new Set(['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while', 'continue']);

const SERVICE_NAME = /Service$|^(Players|Workspace|Lighting|RunService|Teams|StarterGui|StarterPack|ReplicatedStorage|ReplicatedFirst|ServerStorage|ServerScriptService|Debris|Chat|CoreGui|StarterPlayer|TestService|VirtualUser|UserInputService)$/;

class TraceStop extends SandboxLimit { constructor(why) { super('halt', why); this.why = why; } }

// ---- recorder ------------------------------------------------------------------------------------------------------------------

class Recorder {
  constructor(m, options) {
    this.m = m;
    this.opts = { ...LIMITS, ...options };
    this.stack = [[]];            // current event list (a handler body pushes its own)
    this.all = [];                // every event, flat, for statistics
    this.names = new Map();       // base name -> count
    this.handlers = [];           // { fn, label, events, params, done }
    this.fnIds = new Map();
    this.waits = 0;
    this.layers = [];
    this.undefinedGlobals = new Set();
    this.globalWrites = new Set();
    this.truncated = false;
    this.cache = new Map();
    this.shared = null;           // shared metatable of every mock
    this.clock = 1_000_000;
  }

  get events() { return this.stack[this.stack.length - 1]; }

  push(ev) {
    if (this.all.length >= this.opts.maxEvents) { this.truncated = true; throw new TraceStop('event limit'); }
    this.all.push(ev);
    this.events.push(ev);
    return ev;
  }

  uniqueName(base) {
    let b = String(base).replace(/[^A-Za-z0-9_]/g, '_').replace(/^[0-9]+/, '');
    if (!b) b = 'v';
    // services keep their conventional capitalised names; everything else reads as a local
    if (!SERVICE_NAME.test(b)) b = b[0].toLowerCase() + b.slice(1);
    if (KEYWORDS.has(b)) b += '_';
    const n = (this.names.get(b) || 0) + 1;
    this.names.set(b, n);
    return n === 1 ? b : `${b}${n}`;
  }

  fnId(fn) {
    if (!this.fnIds.has(fn)) this.fnIds.set(fn, this.fnIds.size + 1);
    return this.fnIds.get(fn);
  }

  // ---- values -> source text -----------------------------------------------------------------------------------------------

  repr(v, depth = 0) {
    if (v === undefined) return 'nil';
    if (typeof v === 'boolean') return v ? 'true' : 'false';
    if (typeof v === 'number') return Number.isFinite(v) ? formatNumber(v) : (Number.isNaN(v) ? '(0/0)' : v > 0 ? 'math.huge' : '-math.huge');
    if (typeof v === 'string') return this.str(v);
    if (v instanceof LuaUserdata) return v.expr !== undefined ? v.expr : 'userdata';
    if (v instanceof LuaTable) return this.table(v, depth);
    if (v instanceof LuaFunction) { this.noteHandler(v, 'function value'); return `@@fn:${this.fnId(v)}@@`; }
    if (v instanceof NativeFunction) return v.name || 'function';
    return String(v);
  }

  str(s) {
    const cut = s.length > 400;
    const q = quoteString(cut ? s.slice(0, 400) : s);
    return cut ? `${q} --[[+${s.length - 400} bytes]]` : q;
  }

  table(t, depth) {
    if (depth > 2) return '{ ... }';
    const parts = [];
    for (let i = 1; i <= t.arr.length && parts.length < 8; i++) parts.push(this.repr(t.arr[i - 1], depth + 1));
    let n = 0;
    if (t.hash) {
      for (const [k, v] of t.hash) {
        if (parts.length >= 8) { n++; continue; }
        parts.push((typeof k === 'string' && isIdentifier(k) ? k : `[${this.repr(k, depth + 1)}]`) + ' = ' + this.repr(v, depth + 1));
      }
    }
    const total = t.arr.length + (t.hash ? t.hash.size : 0);
    if (total > parts.length) parts.push(`--[[ +${total - parts.length} more ]]`);
    void n;
    return parts.length ? `{ ${parts.join(', ')} }` : '{}';
  }

  noteHandler(fn, label) {
    if (this.handlers.some((h) => h.fn === fn)) return;
    if (this.handlers.length >= this.opts.maxHandlers) return;
    this.handlers.push({ fn, label, events: [], done: false, id: this.fnId(fn), params: Math.max(0, fn.proto && fn.proto.nparams ? fn.proto.nparams : 0) });
  }

  // ---- mocks ------------------------------------------------------------------------------------------------------------------------

  mock(expr, props = {}) {
    const u = new LuaUserdata();
    u.meta = this.shared;
    u.expr = expr;
    u.parent = props.parent || null;
    u.key = props.key;
    u.cls = props.cls || 'Instance';
    u.kids = null;
    u.overrides = null;
    u.inline = !!props.inline;
    return u;
  }

  child(parent, key) {
    if (!parent.kids) parent.kids = new Map();
    let c = parent.kids.get(key);
    if (!c) {
      const expr = typeof key === 'string' && isIdentifier(key) ? `${parent.expr}.${key}` : `${parent.expr}[${this.repr(key)}]`;
      c = this.mock(expr, { parent, key, cls: parent.cls === 'Enum' ? 'EnumItem' : 'Instance' });
      parent.kids.set(key, c);
    }
    return c;
  }

  now() { this.clock += 0.0167; return this.clock; }
}

// ---- the stand-in environment ----------------------------------------------------------------------------------------------

function installEnvironment(rec) {
  const m = rec.m;
  const G = m.globals;
  const meta = new LuaTable();
  rec.shared = meta;

  const isMock = (v) => v instanceof LuaUserdata && v.meta === meta;

  meta.set('__index', nf('__index', ([self, key]) => {
    if (typeof key === 'number') return [undefined];
    if (self.overrides && self.overrides.has(key)) return [self.overrides.get(key)];
    return [rec.child(self, key)];
  }));

  meta.set('__newindex', nf('__newindex', ([self, key, value]) => {
    rec.push({ kind: 'set', text: `${rec.repr(self)}${typeof key === 'string' && isIdentifier(key) ? `.${key}` : `[${rec.repr(key)}]`} = ${rec.repr(value)}`, line: m.line });
    if (!self.overrides) self.overrides = new Map();
    self.overrides.set(key, value);
    if (value instanceof LuaFunction) rec.noteHandler(value, `${rec.repr(self)}.${key}`);
    return [];
  }));

  const arith = (op) => nf(`__${op}`, ([a, b]) => [rec.mock(`(${rec.repr(a)} ${op} ${rec.repr(b)})`, { inline: true, cls: 'number' })]);
  for (const [name, op] of [['__add', '+'], ['__sub', '-'], ['__mul', '*'], ['__div', '/'], ['__mod', '%'], ['__pow', '^'], ['__idiv', '//']]) meta.set(name, arith(op));
  meta.set('__unm', nf('__unm', ([a]) => [rec.mock(`(-${rec.repr(a)})`, { inline: true, cls: 'number' })]));
  meta.set('__concat', nf('__concat', ([a, b]) => [rec.mock(`${rec.repr(a)} .. ${rec.repr(b)}`, { inline: true, cls: 'string' })]));
  meta.set('__len', nf('__len', () => [0]));
  meta.set('__lt', nf('__lt', () => [false]));
  meta.set('__le', nf('__le', () => [false]));
  meta.set('__tostring', nf('__tostring', ([self]) => [self.expr]));

  meta.set('__call', nf('__call', (args) => {
    const [self, ...rest] = args;
    const method = self.parent && rest.length > 0 && rest[0] === self.parent;
    const callArgs = method ? rest.slice(1) : rest;
    return [recordCall(self, method, callArgs)];
  }));

  function recordCall(callee, method, callArgs) {
    const name = typeof callee.key === 'string' ? callee.key : null;
    const calleeText = method ? `${rec.repr(callee.parent)}:${name}` : callee.expr;
    const argText = callArgs.map((a) => rec.repr(a)).join(', ');
    const text = `${calleeText}(${argText})`;

    for (const a of callArgs) if (a instanceof LuaFunction) rec.noteHandler(a, text);

    // network: report the request, hand back a harmless chunk so `loadstring(...)()` carries on
    if (name && HTTP_METHODS.has(name)) {
      const url = typeof callArgs[0] === 'string' ? callArgs[0] : null;
      rec.push({ kind: 'call', text, line: m.line, request: url, net: true });
      return `-- QuickSilver: no network in the sandbox; ${name}(${url ? JSON.stringify(url) : '…'}) was not performed\n`;
    }
    if (name && LIST_METHODS.has(name)) {
      const v = rec.uniqueName(name.replace(/^Get/, '').replace(/^./, (c) => c.toLowerCase()));
      rec.push({ kind: 'call', text, line: m.line, result: v });
      const list = new LuaTable();
      list.set(1, rec.mock(`${v}[1]`, { cls: 'Instance' }));
      return list;
    }
    if (name === 'new' && callee.parent && callee.parent.expr === 'Instance') {
      const cls = typeof callArgs[0] === 'string' ? callArgs[0] : 'Instance';
      const v = rec.uniqueName(cls);
      rec.push({ kind: 'call', text, line: m.line, result: v });
      const o = rec.mock(v, { cls });
      if (callArgs[1] !== undefined && isMock(callArgs[1])) { o.overrides = new Map([['Parent', callArgs[1]]]); }
      return o;
    }
    if (name === 'GetService' && typeof callArgs[0] === 'string') {
      const key = `svc:${callArgs[0]}`;
      let svc = callee.parent && callee.parent.kids && callee.parent.kids.get(key);
      const first = !svc;
      if (!svc) {
        if (!callee.parent.kids) callee.parent.kids = new Map();
        svc = rec.mock(rec.uniqueName(callArgs[0]), { cls: callArgs[0] });
        callee.parent.kids.set(key, svc);
      }
      if (first) rec.push({ kind: 'call', text, line: m.line, result: svc.expr });
      return svc;
    }
    if (name === 'Wait' || name === 'wait') return rec.waitResult(callee, text);
    if (VALUE_TYPES.includes(rootName(callee)) || (name && LOOKUPS.has(name)) || callee.inline) {
      // inline expression; identical expressions evaluate to the same object so `==` behaves
      const parentForCache = method ? callee.parent : callee;
      if (!parentForCache.kids) parentForCache.kids = new Map();
      const ck = `call:${text}`;
      let r = parentForCache.kids.get(ck);
      if (!r) {
        r = rec.mock(text, { cls: VALUE_TYPES.includes(rootName(callee)) ? rootName(callee) : 'Instance', inline: true });
        parentForCache.kids.set(ck, r);
      }
      if (name && LOOKUPS.has(name) && !VALUE_TYPES.includes(rootName(callee))) { /* lookups are not events by themselves */ }
      else if (!VALUE_TYPES.includes(rootName(callee))) rec.push({ kind: 'call', text, line: m.line });
      return r;
    }
    const base = name || rootName(callee) || 'result';
    const v = rec.uniqueName(name ? base.replace(/^Get/, '').replace(/^./, (c) => c.toLowerCase()) : base);
    const ev = rec.push({ kind: 'call', text, line: m.line, result: v });
    void ev;
    return rec.mock(v, { cls: name === 'Connect' ? 'RBXScriptConnection' : 'Instance' });
  }

  function rootName(mock) {
    let x = mock;
    while (x.parent) x = x.parent;
    return x.expr;
  }

  rec.waitResult = (callee, text) => {
    rec.waits++;
    const budget = rec.waitBudget;
    if (rec.waits > budget) throw new TraceStop('wait budget');
    rec.push({ kind: 'call', text, line: m.line });
    return rec.now();
  };
  rec.waitBudget = rec.opts.maxWaits;

  // ---- roots ----
  const define = (name, value) => G.set(name, value);
  for (const n of OBJECT_ROOTS) define(n, rec.mock(n, { cls: n === 'game' ? 'DataModel' : n === 'workspace' ? 'Workspace' : n === 'script' ? 'LocalScript' : 'Instance' }));
  for (const n of VALUE_TYPES) define(n, rec.mock(n, { cls: n }));
  const instance = rec.mock('Instance', { cls: 'Instance' });
  define('Instance', instance);
  // A recorded function: it logs the call and answers with a stand-in object. Real functions (not userdata),
  // so scripts that test `type(hookfunction) == "function"` behave as they would under an executor.
  const recorded = (name) => nf(name, (a) => {
    const text = `${name}(${a.map((x) => rec.repr(x)).join(', ')})`;
    for (const x of a) if (x instanceof LuaFunction) rec.noteHandler(x, text);
    const v = rec.uniqueName(name.split('.').pop());
    rec.push({ kind: 'call', text, line: m.line, result: v });
    return [rec.mock(v)];
  });
  for (const n of CALLABLE_ROOTS) define(n, recorded(n));
  for (const n of NAMESPACES) {
    const t = new LuaTable();
    const nm = new LuaTable();
    nm.set('__index', nf('__index', ([self, key]) => {
      if (typeof key !== 'string') return [undefined];
      const f = recorded(`${n}.${key}`);
      self.set(key, f);
      return [f];
    }));
    t.meta = nm;
    define(n, t);
  }

  // global functions that return real values
  const waitArgs = (name) => nf(name, (a) => { rec.waits++; if (rec.waits > rec.waitBudget) throw new TraceStop('wait budget'); rec.push({ kind: 'call', text: `${name}(${a.map((x) => rec.repr(x)).join(', ')})`, line: m.line }); return [rec.now()]; });
  define('wait', waitArgs('wait'));
  define('tick', nf('tick', () => [rec.now()]));
  define('time', nf('time', () => [rec.now() - 1_000_000]));
  define('typeof', nf('typeof', ([v]) => [isMock(v) ? v.cls : typeName(v)]));
  define('warn', nf('warn', (a) => { rec.push({ kind: 'print', text: `warn(${a.map((x) => rec.repr(x)).join(', ')})`, line: m.line }); return []; }));
  const std = G.get('print');
  define('print', nf('print', (a, mm) => { rec.push({ kind: 'print', text: `print(${a.map((x) => rec.repr(x)).join(', ')})`, line: m.line }); return std.fn(a, mm); }));

  // executor helpers whose result matters for control flow
  define('getgenv', nf('getgenv', () => [G]));
  define('getrenv', nf('getrenv', () => [G]));
  define('identifyexecutor', nf('identifyexecutor', () => { rec.push({ kind: 'call', text: 'identifyexecutor()', line: m.line }); return ['QuickSilver', '1.0']; }));
  define('getexecutorname', G.get('identifyexecutor'));
  define('checkcaller', nf('checkcaller', () => [true]));
  define('newcclosure', nf('newcclosure', ([f]) => [f]));
  define('clonefunction', nf('clonefunction', ([f]) => [f]));
  define('cloneref', nf('cloneref', ([o]) => [o]));
  define('hookfunction', nf('hookfunction', ([f, g]) => { rec.push({ kind: 'call', text: `hookfunction(${rec.repr(f)}, ${rec.repr(g)})`, line: m.line }); return [f]; }));
  define('islclosure', nf('islclosure', ([f]) => [f instanceof LuaFunction]));
  define('iscclosure', nf('iscclosure', ([f]) => [f instanceof NativeFunction]));
  const reply = (extra) => {
    const t = new LuaTable();
    t.set('Success', true); t.set('StatusCode', 200); t.set('StatusMessage', 'OK'); t.set('Body', extra);
    return t;
  };
  for (const n of ['request', 'http_request']) {
    define(n, nf(n, ([opts]) => {
      const url = opts instanceof LuaTable ? opts.get('Url') || opts.get('url') : null;
      rec.push({ kind: 'call', text: `${n}(${rec.repr(opts)})`, line: m.line, request: typeof url === 'string' ? url : null, net: true });
      return [reply('-- QuickSilver: no network in the sandbox\n')];
    }));
  }
  for (const ns of [G.get('http'), G.get('syn')]) ns.set('request', G.get('request'));
  for (const n of ['setclipboard', 'toclipboard', 'writefile', 'appendfile', 'queue_on_teleport', 'queueonteleport', 'rconsoleprint', 'printconsole', 'saveinstance']) {
    define(n, nf(n, (a) => { rec.push({ kind: 'call', text: `${n}(${a.map((x) => rec.repr(x)).join(', ')})`, line: m.line }); return []; }));
  }
  define('readfile', nf('readfile', (a) => { rec.push({ kind: 'call', text: `readfile(${a.map((x) => rec.repr(x)).join(', ')})`, line: m.line }); return ['']; }));
  for (const n of ['isfile', 'isfolder']) define(n, nf(n, (a) => { rec.push({ kind: 'call', text: `${n}(${a.map((x) => rec.repr(x)).join(', ')})`, line: m.line }); return [false]; }));
  for (const n of ['spawn', 'delay']) define(n, nf(n, (a) => spawnCall(n, a)));
  const task = G.get('task');
  for (const n of ['spawn', 'defer', 'delay']) task.set(n, nf(`task.${n}`, (a) => spawnCall(`task.${n}`, a)));
  task.set('wait', nf('task.wait', (a) => { rec.waits++; if (rec.waits > rec.waitBudget) throw new TraceStop('wait budget'); rec.push({ kind: 'call', text: `task.wait(${a.map((x) => rec.repr(x)).join(', ')})`, line: m.line }); return [rec.now() - 1_000_000]; }));
  task.set('cancel', nf('task.cancel', () => []));

  function spawnCall(name, a) {
    const fnIndex = a.findIndex((v) => isFunction(v));
    const text = `${name}(${a.map((x) => rec.repr(x)).join(', ')})`;
    if (fnIndex >= 0 && a[fnIndex] instanceof LuaFunction) rec.noteHandler(a[fnIndex], text);
    rec.push({ kind: 'call', text, line: m.line, spawn: fnIndex >= 0 ? rec.fnId(a[fnIndex]) : null });
    return [rec.mock(rec.uniqueName('thread'), { cls: 'thread' })];
  }

  // undefined globals: note the read (once per name) and carry on with nil
  const gmeta = new LuaTable();
  gmeta.set('__index', nf('__index', ([, key]) => { if (typeof key === 'string') rec.undefinedGlobals.add(key); return [undefined]; }));
  gmeta.set('__newindex', nf('__newindex', ([t, key, value]) => {
    if (typeof key === 'string') rec.globalWrites.add(key);
    t.set(key, value);
    if (value instanceof LuaFunction) rec.noteHandler(value, `global ${String(key)}`);
    return [];
  }));
  G.meta = gmeta;
}

// ---- rendering ---------------------------------------------------------------------------------------------------------------

function renderEvents(rec, events, indent, lines) {
  const pad = '  '.repeat(indent);
  for (const ev of events) {
    const line = ev.result && ev.kind === 'call' ? `local ${ev.result} = ${ev.text}` : ev.text;
    // expand function placeholders into bodies
    const parts = line.split(/@@fn:(\d+)@@/);
    if (parts.length === 1) { lines.push({ pad, text: line, ev }); continue; }
    let acc = parts[0];
    const pending = [];
    for (let i = 1; i < parts.length; i += 2) {
      const h = rec.handlers.find((x) => x.id === Number(parts[i]));
      acc += 'function(...)';
      pending.push({ h, after: parts[i + 1] });
      // function bodies are emitted on following lines; text after the placeholder follows `end`
    }
    lines.push({ pad, text: acc, ev });
    for (const p of pending) {
      if (p.h && p.h.events.length) {
        lines.push({ pad: `${pad}  `, text: p.h.ran ? '-- (run once by the tracer with stand-in arguments)' : '', ev: null });
        renderEvents(rec, p.h.events, indent + 1, lines);
      } else lines.push({ pad: `${pad}  `, text: p.h && p.h.ran ? '-- (nothing observable happened when it was run)' : '-- (not run)', ev: null });
      lines.push({ pad, text: `end${p.after}`, ev: null });
    }
  }
}

function dropUnusedLocals(lines) {
  for (let i = 0; i < lines.length; i++) {
    const m = /^local ([A-Za-z_][\w]*) = (.*)$/.exec(lines[i].text);
    if (!m) continue;
    const re = new RegExp(`(^|[^\\w.])${m[1]}([^\\w]|$)`);
    let used = false;
    for (let k = i + 1; k < lines.length && !used; k++) used = re.test(lines[k].text);
    if (!used) lines[i].text = m[2];
  }
}

function renderScript(rec, status) {
  const lines = [];
  const header = [
    '-- QuickSilver behavioural trace',
    '-- Produced by running the script in an instrumented sandbox with a stand-in Roblox environment.',
    '-- This lists what the script did during that run. It is not the original source: names, structure',
    '-- and any code path that did not run are not recoverable from a trace.',
    `-- Run ended: ${status}`,
    '',
  ];
  renderEvents(rec, rec.stack[0], 0, lines);
  dropUnusedLocals(lines);
  return `${header.join('\n')}${lines.map((l) => (l.text ? `${l.pad}${l.text}` : '')).join('\n')}\n`;
}

// ---- entry point -----------------------------------------------------------------------------------------------------------------

/**
 * @param {string} source binary string
 * @param {{fuel?: number, timeMs?: number, maxEvents?: number, maxWaits?: number, callHandlers?: boolean, dialect?: string, stopAfterLoads?: number}} [options]
 */
export function traceScript(source, options = {}) {
  // Run with the precision watch on. If arithmetic went past 2^53 the sandbox's doubles and Lua 5.4 integers disagree: run again
  // with integers and keep the run whose text reads as text (see sandbox/numeric.js).
  const first = traceOnce(source, { ...options, numMode: 'watch' });
  if (!first.precisionLoss) return first.result;
  const second = traceOnce(source, { ...options, numMode: 'int64' });
  const key = (t) => `${t.output}\u0000${t.events.map((e) => e.text).join('\u0000')}`;
  const readable = (t) => readsAsText(t.output) && t.events.every((e) => readsAsText(e.text));
  const a = first.result;
  const b = second.result;
  let pick = a;
  let note;
  if (key(a) === key(b) && a.status === b.status) note = null;
  else if (readable(b) && b.status === 'completed' && (!readable(a) || a.status !== 'completed')) { pick = b; note = 'Lua 5.4 integers (arithmetic went past 2^53, where they differ from the doubles of Lua 5.1 / Luau, and only this run produced readable text)'; }
  else if (readable(a) && !readable(b)) note = 'doubles (arithmetic went past 2^53; the Lua 5.4 integer run produced unreadable text)';
  else note = 'doubles (arithmetic went past 2^53, so the result depends on the Lua version; the Lua 5.4 integer run differs and neither reading is clearly text)';
  if (note) {
    pick = { ...pick, arithmetic: note };
    pick.script = `-- Arithmetic: ${note}\n${pick.script}`;
  }
  return pick;
}

function traceOnce(source, options) {
  const opts = { ...LIMITS, callHandlers: true, dialect: 'luau', ...options };
  const m = createMachine({ fuel: opts.fuel, timeMs: opts.timeMs, dialect: opts.dialect, numMode: opts.numMode });
  m.chunkName = 'trace';
  const rec = new Recorder(m, opts);
  installEnvironment(rec);

  m.hooks.onLoad = (src, chunkName) => {
    if (rec.layers.length >= opts.maxLayers) throw new TraceStop('too many loaded chunks');
    const index = rec.layers.length + 1;
    rec.layers.push({ index, chunkName: typeof chunkName === 'string' ? chunkName : null, source: src });
    rec.push({ kind: 'load', text: `-- loadstring: chunk ${index} (${src.length} bytes)`, line: m.line, layer: index });
    // a caller that only wants the first chunk (layer unwrapping) does not need the script to go on and run it
    if (opts.stopAfterLoads && rec.layers.length >= opts.stopAfterLoads) throw new TraceStop('chunk captured');
  };

  const startFuel = m.fuel;
  let result = { ok: true };
  let ended = 'completed';
  const run = (fn) => {
    try { fn(); } catch (e) {
      if (e instanceof TraceStop) { ended = `stopped (${e.why})`; return 'halt'; }
      if (e instanceof LuaSyntaxError) { result = { ok: false, kind: 'syntax', error: e.message }; ended = 'syntax error'; return 'syntax'; }
      const c = classify(e);
      if (c.halted) { ended = 'stopped'; return 'halt'; }
      if (!c.ok) { result = c; ended = c.kind === 'limit' ? `stopped (${c.limit} limit)` : `error: ${c.error}`; return c.kind === 'limit' ? 'limit' : 'error'; }
    }
    return null;
  };

  // `table.concat` is how many scripts assemble the text they are about to load; keep what it returns
  const concats = [];
  if (opts.captureConcat) {
    const tbl = m.globals.get('table');
    const orig = tbl instanceof LuaTable ? tbl.get('concat') : null;
    if (orig instanceof NativeFunction) {
      tbl.set('concat', nf('concat', (a) => {
        const r = orig.fn(a);
        if (typeof r[0] === 'string' && r[0].length >= 64 && concats.length < 40) concats.push({ index: concats.length + 1, source: r[0] });
        return r;
      }));
    }
  }

  let main = null;
  const outcome = run(() => { main = compileSource(m, source, m.chunkName, m.globals); callValue(m, main, [], ''); });

  // Handlers (event callbacks, spawned functions) run once, with stand-in arguments, after the main chunk.
  let handlersRun = 0;
  if (opts.callHandlers && !['limit', 'syntax'].includes(outcome || '') && result.kind !== 'limit') {
    for (let i = 0; i < rec.handlers.length && handlersRun < opts.maxHandlers; i++) {
      const h = rec.handlers[i];
      if (h.done || m.fuel < 100_000) continue;
      h.done = true; h.ran = true; handlersRun++;
      rec.stack.push(h.events);
      const savedBudget = rec.waitBudget;
      rec.waitBudget = rec.waits + opts.handlerWaits;
      const args = [1, 2, 3].map((n) => rec.mock(`arg${n}`));
      const r = run(() => callValue(m, h.fn, args, ''));
      rec.waitBudget = savedBudget;
      rec.stack.pop();
      if (r === 'limit') break;
      if (r === 'halt' && ended.startsWith('stopped (wait')) ended = 'completed';
      if (r === 'error') { h.error = result.error; result = { ok: true }; ended = 'completed'; }
    }
  }

  const status = outcome === 'syntax' ? 'syntax-error' : outcome === 'error' ? 'error' : outcome === 'limit' ? 'limit' : outcome === 'halt' ? 'halted' : 'completed';
  const calls = rec.all.filter((e) => e.kind === 'call');
  const result_ = {
    ok: outcome !== 'syntax',
    status,
    ended,
    error: outcome === 'error' || outcome === 'syntax' ? result.error : null,
    script: renderScript(rec, ended),
    events: rec.all.map((e) => ({ kind: e.kind, text: e.text.replace(/@@fn:\d+@@/g, 'function(...) end'), line: e.line, request: e.request || null })),
    layers: rec.layers,
    concats,
    requests: [...new Set(rec.all.filter((e) => e.request).map((e) => e.request))],
    undefinedGlobals: [...rec.undefinedGlobals].slice(0, 100),
    globalWrites: [...rec.globalWrites].slice(0, 100),
    output: m.output.join(''),
    stats: { events: rec.all.length, calls: calls.length, sets: rec.all.filter((e) => e.kind === 'set').length, loads: rec.layers.length, handlers: handlersRun, waits: rec.waits, fuelUsed: startFuel - m.fuel, truncated: rec.truncated },
  };
  return { result: result_, precisionLoss: m.precisionLoss };
}
