// Luarmor loader analysis (src/loader/luarmor.js): variants, the five operations kept apart, local logic recovered, data opaque,
// remote parts named and never fetched, keys redacted, obfuscated loaders routed to the pipeline.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { analyzeLuarmor } from '../src/loader/luarmor.js';
import { loaderSource } from '../src/api.js';
import { parse } from '../src/core/parser.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
// the structure of a Luarmor bootstrap (data table + cache-or-download of the init script) with invented values
const BOOTSTRAP = `-- Do not save this file
_bsdata0={123456789,987654321,"\\1\\2\\3\\200\\201\\202\\203\\204\\205\\206","${'ab'.repeat(32)}","TOKEN_ABC-123.xyz",42};
local f,b,a="static_content_1","0000-demo";pcall(function()a=readfile(f.."/init-"..b..".lua")end) if a and #a>2000 then a=loadstring(a) else a=nil; end;
if a then return a() else pcall(makefolder,f) a=game:HttpGet("https://cdn.luarmor.net/v4_init_demo.lua") writefile(f.."/init-"..b..".lua", a);
pcall(function() for i,v in pairs(listfiles('./'..f)) do local m=v:match('(init[%w%-]*).lua$') if m and m~=('init-'..b) then pcall(delfile, f..'/'..m..'.lua') end end; end); return loadstring(a)() end
`;

test('bootstrap: local logic recovered in full, the data table opaque, the init runtime named and not fetched', () => {
  const r = analyzeLuarmor(BOOTSTRAP);
  assert.deepEqual(r.variants, ['bootstrap']);
  assert.equal(r.local.recoverable, 'full');
  assert.doesNotThrow(() => parse(r.local.code), 'the recovered loader logic parses');
  assert.ok(!r.local.code.includes('_bsdata0'), 'the data table is reported separately, not mixed into the logic');
  assert.match(r.local.describes[0], /cached copy.*downloads it, caches it.*deletes older cached copies/);
  assert.equal(r.data.length, 1);
  assert.deepEqual([r.data[0].entries, r.data[0].numbers], [6, 3]);
  assert.deepEqual(r.data[0].strings.map((s) => s.form), ['binary bytes', 'hex digits', 'token']);
  assert.equal(r.data[0].recoverable, 'opaque');
  assert.equal(r.remote[0].role, 'init runtime');
  assert.equal(r.remote[0].retrieved, false);
  assert.deepEqual(r.operations.map((o) => o.status), ['done', 'partial', 'not-available', 'needs-input', 'needs-input']);
});

test('SDK loader (the user’s own MainLoader.lua): key flow and status codes read, protected script named as not present', () => {
  const src = fs.readFileSync(path.join(root, 'tests', 'corpus', 'user-local', 'MainLoader.lua'), 'latin1');
  const r = analyzeLuarmor(src);
  assert.ok(r.variants.includes('sdk'));
  assert.deepEqual(r.statuses, ['KEY_BANNED', 'KEY_EXPIRED', 'KEY_HWID_LOCKED', 'KEY_INCORRECT', 'KEY_VALID']);
  assert.equal(r.key.set, true);
  assert.ok(r.remote.some((x) => x.role === 'protected script' && !x.retrieved));
  assert.equal(r.operations[2].status, 'not-available');
  assert.match(r.answer, /none of the protected script is present/);
});

test('loader-url with a literal key: the key is redacted everywhere; key-link scripts are told apart from loaders', () => {
  const r = analyzeLuarmor('script_key = "SECRETKEY1234567890"\nloadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/0123456789abcdef0123456789abcdef.lua"))()\n');
  assert.deepEqual(r.variants, ['loader-url']);
  assert.ok(!JSON.stringify(r).includes('SECRETKEY1234567890'));
  assert.match(r.key.sources[0], /literal \(19 characters, redacted\)/);
  const k = analyzeLuarmor('setclipboard("https://ads.luarmor.net/get_key?for=Demo-abc")\nprint("copied")\n');
  assert.deepEqual(k.variants, ['key-link']);
  assert.equal(k.remote.length, 0);
});

test('unrelated scripts are not Luarmor; a mention alone is not a loader', () => {
  assert.equal(analyzeLuarmor('print("hello")'), null);
  assert.equal(analyzeLuarmor('-- inspired by luarmor\nprint(1)'), null);
});

test('an obfuscated Luarmor loader is routed to the Deobfuscator instead of being called recovered', { skip: fs.existsSync(path.join(root, 'local', 'corpus', 'Luraph', 'Unknown', '0fd9546376a67403.lua')) ? false : 'local corpus not present' }, () => {
  const r = analyzeLuarmor(fs.readFileSync(path.join(root, 'local', 'corpus', 'Luraph', 'Unknown', '0fd9546376a67403.lua'), 'latin1'));
  assert.equal(r.local.recoverable, 'needs-deobfuscation');
  assert.equal(r.local.code, null);
  assert.equal(r.operations[1].status, 'via-pipeline');
});

test('the Loader op carries the Luarmor analysis', () => {
  const r = loaderSource(BOOTSTRAP);
  assert.ok(r.luarmor && r.luarmor.variants.includes('bootstrap'));
});

// ---- Test 7 (Prompt XXI): a hub loader that chooses its Luarmor loader id at run time ------------------------------------------------------
// The structure of a real hub loader (PlaceId table, a function returning an id per game and executor, a key UI, a cached key), with invented
// ids and place ids. Defects it exposed: E1 the ids were not resolved and the bare address prefix was reported as a loader address; E2 a plain
// loader was classed "partially reconstructed"; E3 the description said "load_script" for a loader that never calls it; E4 status codes other
// than KEY_* and the key's origin were not named.
const HUB = `local ids = { ["111"] = "${'a'.repeat(32)}" }
local idA = ids[tostring(game.PlaceId)]
if idA then
  pcall(function() loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/" .. idA .. ".lua"))() end)
  return
end
local function exec() return (identifyexecutor or function() return "x" end)():lower() end
local function pick()
  local p = tostring(game.PlaceId)
  if p == "222" or p == "333" then
    if exec() == "lite" then return "${'b'.repeat(32)}" end
    return "${'c'.repeat(32)}"
  end
  if p == "444" then return "${'d'.repeat(32)}" end
  return nil
end
local id = pick()
if not id then return end
local api = loadstring(game:HttpGet("https://sdkapi-public.luarmor.net/library.lua"))()
local function check(k) api.script_id = id local r = api.check_key(k) if r.code == "KEY_VALID" then return true elseif r.code == "SECURITY_ERROR" then return false end return false end
local saved = readfile("hub_key.txt")
if saved and check(saved) then
  getgenv().script_key = saved
  loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/" .. id .. ".lua"))()
  return
end
local box = Instance.new("TextBox")
local typed = box.Text:gsub("%s+", "")
if check(typed) then writefile("hub_key.txt", typed) getgenv().script_key = typed loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/" .. id .. ".lua"))() end
`;

test('Test 7 E1: loader ids chosen at run time are resolved statically, with the conditions they sit under and whether a key is set on their path', () => {
  const r = analyzeLuarmor(HUB);
  assert.deepEqual(r.loaderIds.map((x) => x.id), ['a', 'b', 'c', 'd'].map((c) => c.repeat(32)));
  const [a, b, c, d] = r.loaderIds;
  assert.match(a.when.join(' '), /tostring\(game\.PlaceId\) is "111"/);
  assert.equal(a.keyed, false, 'the PlaceId-table path loads without setting a script_key');
  assert.match(b.when.join(' '), /"222" or "333".*exec\(\) is "lite"/);
  assert.match(c.when.join(' '), /"222" or "333"/);
  assert.match(d.when.join(' '), /"444"/);
  assert.ok([b, c, d].every((x) => x.keyed), 'both key paths set script_key before the loader runs');
  // the bare prefix is not reported as a loader address; each built address is named with its hole
  assert.ok(!r.remote.some((x) => x.address === 'https://api.luarmor.net/files/v4/loaders/'));
  assert.ok(r.remote.some((x) => /\{pick\(\)\}\.lua$/.test(x.address || '')));
  assert.equal(r.operations[2].status, 'not-available', 'resolving the ids retrieves nothing');
});

test('Test 7 E3/E4: the description follows the code (no load_script), every compared status code and the key’s origins are named', () => {
  const r = analyzeLuarmor(HUB);
  const sdk = r.local.describes.find((x) => /loads the SDK/.test(x));
  assert.doesNotMatch(sdk, /load_script/);
  assert.match(sdk, /runs the Luarmor loader for the script id/);
  assert.deepEqual(r.statuses, ['KEY_VALID', 'SECURITY_ERROR']);
  assert.deepEqual(r.key.sources, ['the local saved: a file it saved earlier (hub_key.txt)', 'the local typed: what the user typed into a text box']);
  assert.ok(!r.remote.some((x) => /load_script/.test(x.what) && x.role === 'protected script'), 'no "delivered by load_script" entry for a loader without load_script');
});

test('Test 7 E2: a plain loader is never "partially reconstructed": its code is not obfuscated, its program is not in the file, its remote parts are named', async () => {
  const { recoverSource } = await import('../src/api.js');
  const hub = recoverSource(HUB, { sandbox: { enabled: true } }).outcome;
  assert.equal(hub.outcome, 'payload-unavailable', 'the detector reads this as a script that only downloads its program');
  assert.ok(hub.met.some((m) => /not obfuscated/.test(m)));
  assert.match(hub.notes.join(' '), /Not in this file: \d+ part\(s\)/);
  const one = recoverSource('loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/' + 'e'.repeat(32) + '.lua"))()\n', { sandbox: { enabled: true } }).outcome;
  assert.equal(one.outcome, 'payload-unavailable');
  // a loader whose code is computed in the file (not fetched) is still obfuscation, not a remote part
  const computed = recoverSource('local s = "pr" .. "int(1)" loadstring(s)()\n', { sandbox: { enabled: false } }).outcome;
  assert.notEqual(computed.outcome, 'payload-unavailable');
});

const SPARK = path.join(root, 'tests', 'corpus', 'user-local', 'SparkHub_Loader.lua');
test('Test 7 on the supplied loader (local only): six loader ids, one keyless path, nothing retrieved', { skip: !fs.existsSync(SPARK) && 'the supplied loader is kept locally only' }, () => {
  const r = analyzeLuarmor(fs.readFileSync(SPARK, 'latin1'));
  assert.equal(r.loaderIds.length, 6);
  assert.equal(r.loaderIds.filter((x) => !x.keyed).length, 1);
  assert.equal(r.statuses.length, 9);
  assert.equal(r.local.recoverable, 'full');
});

test('Test 7 on the supplied loader (local only): its own program (the key UI) is plain code, never "partially reconstructed"', { skip: !fs.existsSync(SPARK) && 'the supplied loader is kept locally only' }, async () => {
  const { recoverSource } = await import('../src/api.js');
  const o = recoverSource(fs.readFileSync(SPARK, 'latin1'), { sandbox: { enabled: true } }).outcome;
  assert.equal(o.outcome, 'syntax-valid-unverified');
  assert.ok(o.met.some((m) => /not obfuscated/.test(m)));
  assert.match(o.notes.join(' '), /4 part\(s\).*lines 31, 83, 173, 866/);
});
