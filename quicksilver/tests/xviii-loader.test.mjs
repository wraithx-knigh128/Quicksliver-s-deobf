// Loader Analysis (Prompt XVIII §II): architecture classes, the six accessibility cases, retrieval routes, redaction of secrets, stages.
import test from 'node:test';
import assert from 'node:assert/strict';
import { analyzeLoader, classifyStage, resolveUrl, FETCHABLE_HOSTS, CASES } from '../src/loader/analyze.js';
import { ALLOWED_HOSTS } from '../api/_lib/safe-fetch.js';
import { loaderSource } from '../src/api.js';

const arch = (a) => a.architectures.map((x) => x.id);

test('the page-side host list is the server fetcher’s list', () => {
  assert.deepEqual([...FETCHABLE_HOSTS].sort(), [...ALLOWED_HOSTS].sort());
});

test('case 1: a script with no request holds its own payload', () => {
  const a = analyzeLoader('local x = 1\nprint(x)');
  assert.equal(a.isLoader, false);
  assert.equal(a.case.id, 'in-file');
  assert.ok(arch(a).includes('payload-in-file'));
});

test('case 2: a direct remote loader from a public host is retrievable through the link fetcher only', () => {
  const a = analyzeLoader('loadstring(game:HttpGet("https://raw.githubusercontent.com/u/r/main/x.lua"))()');
  assert.equal(a.case.id, 'public');
  assert.deepEqual(arch(a), ['direct-remote']);
  const [r] = a.requests;
  assert.equal(r.urlKind, 'literal');
  assert.equal(r.executes, true);
  assert.equal(r.family, 'github');
  assert.deepEqual([r.retrieval.possible, r.retrieval.route], [true, 'link-fetcher']);
});

test('a public host outside the fetch list is reported as manual, not fetched', () => {
  const [r] = analyzeLoader('loadstring(game:HttpGet("https://cdn.example.org/init.lua"))()').requests;
  assert.deepEqual([r.retrieval.possible, r.retrieval.route], [false, 'manual']);
});

test('case 3: a key or token in the request means only its owner may retrieve it — and the secret is redacted everywhere', () => {
  const src = 'local r = request({Url = "https://api.example.com/v1/script?key=SECRET-VALUE-123", Headers = {Authorization = "Bearer TOPSECRET-TOKEN"}})\nloadstring(r.Body)()';
  const a = analyzeLoader(src);
  assert.equal(a.case.id, 'user-key');
  assert.ok(arch(a).includes('token-auth') && arch(a).includes('http-client') && arch(a).includes('api-backed'));
  assert.equal(a.requests[0].retrieval.route, 'owner');
  assert.equal(a.requests[0].decoder, null, 'reading r.Body is not a decoding step');
  const out = JSON.stringify(a);
  assert.ok(!out.includes('SECRET-VALUE-123') && !out.includes('TOPSECRET-TOKEN'), 'no secret value appears in the result');
});

test('case 6: a Luarmor loader is recognised, its script_key redacted, and nothing is retrieved', () => {
  const src = 'script_key = "ABCDEFGHIJ1234567890"\nloadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/0123456789abcdef.lua"))()';
  const a = analyzeLoader(src);
  assert.equal(a.case.id, 'no-interface');
  assert.ok(a.alsoApplies.some((c) => c.id === 'user-key'));
  assert.deepEqual(a.families.map((f) => f.id), ['luarmor']);
  assert.equal(a.requests[0].retrieval.possible, false);
  assert.ok(!JSON.stringify(a).includes('ABCDEFGHIJ1234567890'));
  assert.equal(a.auth.markers[0].value, '<redacted 20 chars>');
});

test('case 4: an address built from run-time values is dynamic; the fixed parts are still shown', () => {
  const a = analyzeLoader('local id = game.PlaceId\nloadstring(game:HttpGet("https://example.com/scripts/" .. id .. ".lua"))()');
  assert.equal(a.case.id, 'dynamic');
  assert.equal(a.requests[0].template, 'https://example.com/scripts/{game.PlaceId}.lua');
  assert.ok(arch(a).includes('runtime-constructed'));
  assert.equal(analyzeLoader('loadstring(game:HttpGet(getUrl()))()').requests[0].urlKind, 'dynamic');
});

test('case 5: a download decoded before it runs is "transformed"; an address spelled with string.char is decoded statically', () => {
  const a = analyzeLoader('local d = game:HttpGet("https://pastebin.com/raw/AbCd1234")\nloadstring(base64decode(d))()');
  assert.equal(a.case.id, 'transformed');
  assert.equal(a.requests[0].decoder, 'base64decode');
  const chars = 'https://paste.ee/r/a'.split('').map((c) => c.charCodeAt(0)).join(',');
  const b = analyzeLoader(`loadstring(game:HttpGet(string.char(${chars})))()`);
  assert.equal(b.requests[0].url, 'https://paste.ee/r/a');
  assert.equal(b.requests[0].urlKind, 'encoded');
});

test('config-first, cached, multi-stage, asset and device-bound loaders are named', () => {
  assert.ok(arch(analyzeLoader('getgenv().Settings = { Speed = 16 }\nloadstring(game:HttpGet("https://rentry.co/abc/raw"))()')).includes('config-first'));
  const cached = analyzeLoader('if isfile("c") then loadstring(readfile("c"))() else local s = game:HttpGet("https://cdn.example.org/i.lua"); writefile("c", s); loadstring(s)() end');
  assert.ok(arch(cached).includes('cached'));
  assert.ok(arch(analyzeLoader('loadstring(game:HttpGet("https://a.example/1"))()\nloadstring(game:HttpGet("https://a.example/2"))()')).includes('multi-stage'));
  const asset = analyzeLoader('require(1234567).load("x")');
  assert.equal(asset.case.id, 'no-interface');
  assert.equal(asset.requests[0].template, 'rbxassetid://1234567');
  assert.ok(arch(analyzeLoader('local h = gethwid()\nloadstring(game:HttpGet("https://a.example/x?hwid=" .. h))()')).includes('device-bound'));
});

test('an ordinary `local key = ...` is not a credential', () => {
  const a = analyzeLoader('local key = Enum.KeyCode.E\nlocal token = "abc"\nloadstring(game:HttpGet("https://raw.githubusercontent.com/u/r/main/x.lua"))()');
  assert.equal(a.auth.markers.length, 0);
  assert.equal(a.case.id, 'public');
});

test('resolveUrl follows locals, string.format, table.concat and Luau interpolation', () => {
  const shape = (src) => { const a = analyzeLoader(src); return a.requests[0]; };
  assert.equal(shape('local b = "https://raw.githubusercontent.com/"\nlocal u = b .. "u/r/main/x.lua"\nloadstring(game:HttpGet(u))()').url, 'https://raw.githubusercontent.com/u/r/main/x.lua');
  assert.equal(shape('loadstring(game:HttpGet(string.format("https://%s/x.lua", "a.example")))()').url, 'https://a.example/x.lua');
  assert.equal(shape('loadstring(game:HttpGet(table.concat({"https://", "a.example", "/y"})))()').url, 'https://a.example/y');
  assert.equal(shape('local n = 3\nloadstring(game:HttpGet(`https://a.example/{n}`))()').url, 'https://a.example/3');
  assert.equal(resolveUrl({ type: 'String', value: 'https://x.example/' }, new Map()).kind, 'literal');
});

test('stages: a downloaded file is classified before it goes into the pipeline', () => {
  assert.equal(classifyStage('\x1bLua\x51\x00').kind, 'bytecode');
  assert.equal(classifyStage('<!DOCTYPE html><html>').kind, 'html');
  assert.equal(classifyStage('loadstring(game:HttpGet("https://a.example/next"))()').kind, 'loader');
  assert.equal(classifyStage('print("payload")').kind, 'script');
});

test('the API op analyses the recovered text too and prefers whichever names more addresses', () => {
  const r = loaderSource('local _ = 1', { recovered: 'loadstring(game:HttpGet("https://raw.githubusercontent.com/u/r/main/x.lua"))()' });
  assert.equal(r.best, 'recovered');
  assert.equal(r.recovered.case.id, 'public');
  assert.equal(Object.keys(CASES).length, 6);
});

test('text that does not parse is not treated as a loader', () => {
  const a = analyzeLoader('local = = (');
  assert.equal(a.parsed, false);
  assert.equal(a.isLoader, false);
});
