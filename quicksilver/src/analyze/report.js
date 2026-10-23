// Static analysis report: what is in this script, without running any of it.
//
// Everything is derived from the AST and the literals in it. The "indicators" are observations about
// which APIs and literals appear (a URL, a call to loadstring, a Discord webhook); they say what the code
// can do, not what it does, and are phrased that way.

import { parse } from '../core/parser.js';
import { analyze as analyzeScopes } from '../core/scope.js';
import { forEachChild } from '../core/walk.js';
import { detect } from '../detect/detect.js';
import { printableRatio } from '../core/bytes.js';

const API_GROUPS = [
  { id: 'dynamic-code', label: 'Dynamic code', names: ['loadstring', 'load', 'dofile', 'loadfile', 'require', 'getfenv', 'setfenv', 'getrenv', 'getgenv', 'getsenv'] },
  { id: 'network', label: 'Network', names: ['HttpGet', 'HttpGetAsync', 'HttpPost', 'HttpPostAsync', 'request', 'http_request', 'http', 'syn', 'WebSocket', 'RequestAsync', 'GetAsync', 'PostAsync', 'HttpService'] },
  { id: 'executor', label: 'Executor / environment', names: ['hookfunction', 'hookmetamethod', 'newcclosure', 'checkcaller', 'getrawmetatable', 'setreadonly', 'identifyexecutor', 'getexecutorname', 'setclipboard', 'writefile', 'readfile', 'isfile', 'listfiles', 'queue_on_teleport', 'firesignal', 'fireclickdetector', 'fireproximityprompt', 'firetouchinterest', 'getconnections', 'decompile', 'getscripts', 'getinstances', 'getnilinstances', 'cloneref', 'gethui', 'Drawing'] },
  { id: 'debug', label: 'Debug library', names: ['debug'] },
  { id: 'roblox', label: 'Roblox API', names: ['game', 'workspace', 'script', 'Instance', 'Enum', 'task', 'Vector3', 'CFrame', 'Color3', 'UDim2', 'Vector2', 'TweenInfo', 'RaycastParams', 'tick', 'wait', 'spawn', 'delay', 'warn', 'typeof'] },
  { id: 'bytecode', label: 'Bytecode', names: ['string.dump', 'bit32', 'bit'] },
];

const URL_RE = /\bhttps?:\/\/[^\s"'<>\\)\]}]{4,}/gi;
const IP_RE = /\b(?:\d{1,3}\.){3}\d{1,3}(?::\d{2,5})?\b/g;
const WEBHOOK_RE = /discord(?:app)?\.com\/api\/webhooks\/\d+\/[\w-]+/i;
const KEYISH_RE = /^[A-Za-z0-9+/_-]{32,}={0,2}$/;

const callName = (e) => {
  if (e.type === 'Name') return e.name;
  if (e.type === 'Index' && e.key.type === 'String') { const o = callName(e.obj); return o ? `${o}.${e.key.value}` : null; }
  if (e.type === 'MethodCall') return `:${e.name}`;
  return null;
};

export function analyzeScript(source, options = {}) {
  let ast;
  try {
    ast = parse(source);
  } catch (e) {
    return { ok: false, error: { message: e.message, line: e.line, col: e.col }, detection: detect(source) };
  }
  const info = analyzeScopes(ast);
  const detection = detect(source, ast);

  const strings = [];
  const calls = new Map();
  const methods = new Map();
  const functions = [];
  let maxDepth = 0;
  let nodes = 0;
  const NESTING = new Set(['If', 'While', 'Repeat', 'NumFor', 'GenFor', 'Func', 'Do']);
  const visit = (node, depth) => {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) { node.forEach((n) => visit(n, depth)); return; }
    nodes++;
    const d = NESTING.has(node.type) ? depth + 1 : depth;
    maxDepth = Math.max(maxDepth, d);
    if (node.type === 'String') strings.push(node.value);
    if (node.type === 'Call') { const n = callName(node.fn); if (n) calls.set(n, (calls.get(n) || 0) + 1); }
    if (node.type === 'MethodCall') methods.set(node.name, (methods.get(node.name) || 0) + 1);
    if (node.type === 'Func') functions.push({ params: node.params.length, vararg: !!node.vararg, line: node.line || 0, statements: node.body.length });
    forEachChild(node, (child) => visit(child, d));
  };
  visit(ast, 0);

  // ---- literals worth a look
  const urls = new Set();
  const ips = new Set();
  const webhooks = new Set();
  const notable = [];
  for (const s of strings) {
    if (s.length < 4 || printableRatio(s) < 0.9) continue;
    for (const m of s.match(URL_RE) || []) urls.add(m);
    for (const m of s.match(IP_RE) || []) if (m.split('.').slice(0, 4).every((p) => Number(p) <= 255)) ips.add(m);
    if (WEBHOOK_RE.test(s)) webhooks.add(s);
    if (s.length >= 4 && s.length <= 200 && /[A-Za-z]{3}/.test(s)) notable.push(s);
  }
  const keyish = strings.filter((s) => KEYISH_RE.test(s)).length;
  const uniqueStrings = [...new Set(notable)];

  // ---- API use
  const globalsUsed = [...info.globals.values()].map((v) => ({ name: v.name, reads: v.reads.length, writes: v.writes.length }));
  const apiUse = [];
  for (const g of API_GROUPS) {
    const hits = g.names.filter((n) => info.globals.has(n.split('.')[0]) && (!n.includes('.') ? true : calls.has(n)));
    const present = hits.filter((n) => (n.includes('.') ? true : info.globals.has(n)));
    if (present.length) apiUse.push({ id: g.id, label: g.label, names: present });
  }
  for (const m of ['HttpGet', 'HttpGetAsync', 'HttpPost', 'GetAsync', 'PostAsync', 'RequestAsync', 'FireServer', 'InvokeServer', 'Kick', 'Teleport', 'TeleportToPlaceInstance']) {
    if (methods.has(m)) {
      let grp = apiUse.find((x) => x.id === (m.startsWith('Http') || m.endsWith('Async') ? 'network' : 'roblox'));
      if (!grp) { grp = { id: m.startsWith('Http') || m.endsWith('Async') ? 'network' : 'roblox', label: m.startsWith('Http') || m.endsWith('Async') ? 'Network' : 'Roblox API', names: [] }; apiUse.push(grp); }
      grp.names.push(`:${m}`);
    }
  }

  // ---- indicators
  const indicators = [];
  const has = (n) => info.globals.has(n) || methods.has(n);
  if ((has('loadstring') || has('load')) && (has('HttpGet') || has('HttpGetAsync') || urls.size)) {
    indicators.push({ severity: 'high', id: 'remote-code', text: 'Fetches text from a URL and may pass it to load/loadstring: the code that runs is not in this file.' });
  } else if (has('loadstring') || has('load')) {
    indicators.push({ severity: 'medium', id: 'dynamic-code', text: 'Builds code at run time and passes it to load/loadstring.' });
  }
  if (webhooks.size) indicators.push({ severity: 'high', id: 'webhook', text: `Contains ${webhooks.size} Discord webhook URL(s); a script can post data to them.` });
  if (urls.size) indicators.push({ severity: 'info', id: 'urls', text: `Contains ${urls.size} URL(s).` });
  if (has('getfenv') || has('setfenv')) indicators.push({ severity: 'info', id: 'env', text: 'Reads or replaces function environments (getfenv/setfenv).' });
  if (info.globals.has('debug')) indicators.push({ severity: 'info', id: 'debug', text: 'Uses the debug library (common in anti-tamper and anti-debug checks).' });
  if (detection.bytecode) indicators.push({ severity: 'medium', id: 'bytecode', text: `Embeds a compiled ${detection.bytecode.format} ${detection.bytecode.version} chunk that cannot be read as source.` });
  if (keyish > 5) indicators.push({ severity: 'info', id: 'blobs', text: `${keyish} long string(s) that look like encoded data.` });
  for (const f of detection.families.filter((x) => x.confidence >= 0.5)) {
    indicators.push({ severity: 'info', id: `family-${f.id}`, text: `Looks like ${f.name} output (${Math.round(f.confidence * 100)}%).` });
  }

  const topCalls = [...calls.entries()].sort((a, b) => b[1] - a[1]).slice(0, 25).map(([name, count]) => ({ name, count }));
  const lines = source.split('\n').length;
  return {
    ok: true,
    summary: {
      bytes: source.length,
      lines,
      nodes,
      functions: functions.length,
      locals: info.vars.length,
      globals: info.globals.size,
      maxNesting: maxDepth,
      strings: strings.length,
      dialect: detection.dialect.label,
    },
    detection,
    urls: [...urls].slice(0, 100),
    ips: [...ips].slice(0, 50),
    webhooks: [...webhooks].slice(0, 20),
    strings: uniqueStrings.slice(0, 200),
    apiUse,
    globals: globalsUsed.sort((a, b) => b.reads - a.reads).slice(0, 60),
    functions: functions.slice(0, 100),
    calls: topCalls,
    indicators,
  };
}
