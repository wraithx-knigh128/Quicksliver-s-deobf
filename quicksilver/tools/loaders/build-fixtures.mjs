// Build tests/corpus/remote-loaders: loader scripts plus the responses a mock service gives for each address.
//
// The payloads are fixtures already in this repository (originals and obfuscated outputs with measured behaviour); this only wraps them
// in the transport forms real services use (gzip, base64, hex, JSON fields, Roblox models, error pages). Written for this project; no
// real service is contacted. Run: node tools/loaders/build-fixtures.mjs
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'tests', 'corpus');
const out = path.join(root, 'remote-loaders');
const bodies = path.join(out, 'bodies');
fs.mkdirSync(bodies, { recursive: true });
const read = (p) => fs.readFileSync(path.join(root, p));
const PLAIN = read('originals/s01_minify_basic.lua');
const IB2 = read('obfuscated/ironbrew2/s01_minify_basic__default.lua');
const PROM = read('obfuscated/prometheus/s06_combined__Weak.lua');
const ZEN = read('obfuscated/zenfus/s01_minify_basic__default.lua');
const MODEL_BIN = read('models/default-inserted-modulescript/binary.rbxm');
const rbxmx = (name, src) => Buffer.from(`<roblox version="4"><Item class="ModuleScript" referent="RBX1"><Properties><string name="Name">${name}</string><ProtectedString name="Source"><![CDATA[${src.toString('latin1')}]]></ProtectedString></Properties></Item></roblox>`, 'latin1');

const files = {};
const body = (name, buf) => { fs.writeFileSync(path.join(bodies, name), buf); files[name] = buf.length; return name; };
const R = (url, spec) => [url, spec];
const loader = (url) => `loadstring(game:HttpGet("${url}"))()\n`;

const cases = [
  { id: 'direct-plain', category: 'direct source', loader: loader('https://raw.githubusercontent.com/qs-fixtures/demo/main/plain.lua'),
    service: [R('https://raw.githubusercontent.com/qs-fixtures/demo/main/plain.lua', { file: body('plain.lua', PLAIN), type: 'text/plain' })], expect: ['retrieved-plain'] },
  { id: 'public-ironbrew2', category: 'public endpoint, obfuscated', loader: loader('https://pastebin.com/raw/Ib2Demo01'),
    service: [R('https://pastebin.com/raw/Ib2Demo01', { file: body('ib2.lua', IB2), type: 'text/plain' })], expect: ['retrieved-reconstructed'] },
  { id: 'public-prometheus', category: 'public endpoint, obfuscated', loader: loader('https://gist.githubusercontent.com/qs/abc123/raw'),
    service: [R('https://gist.githubusercontent.com/qs/abc123/raw', { file: body('prom.lua', PROM), type: 'text/plain' })], expect: ['retrieved-reconstructed'] },
  { id: 'encoded-base64-gzip', category: 'encoded response', loader: loader('https://rentry.co/ib2gz/raw'),
    service: [R('https://rentry.co/ib2gz/raw', { file: body('ib2.b64gz.txt', Buffer.from(zlib.gzipSync(IB2).toString('base64'))), type: 'text/plain' })], expect: ['retrieved-reconstructed'] },
  { id: 'encoded-json-field', category: 'encoded response', loader: loader('https://paste.ee/r/JsonCode'),
    service: [R('https://paste.ee/r/JsonCode', { file: body('plain.json', Buffer.from(JSON.stringify({ success: true, code: PLAIN.toString('latin1') }))), type: 'application/json' })], expect: ['retrieved-plain'] },
  { id: 'encoded-hex-zlib', category: 'encoded response', loader: loader('https://cdn.discordapp.com/attachments/1/2/payload.txt'),
    service: [R('https://cdn.discordapp.com/attachments/1/2/payload.txt', { file: body('plain.zlib.hex', Buffer.from(zlib.deflateSync(PLAIN).toString('hex'))), type: 'text/plain' })], expect: ['retrieved-plain'] },
  { id: 'multi-stage', category: 'multi-stage', loader: loader('https://raw.githubusercontent.com/qs-fixtures/demo/main/stage1.lua'),
    service: [R('https://raw.githubusercontent.com/qs-fixtures/demo/main/stage1.lua', { file: body('stage1.lua', Buffer.from('-- stage 1: fetch the real script\nloadstring(game:HttpGet("https://paste.ee/r/Stage2Ib2"))()\n')), type: 'text/plain' }),
      R('https://paste.ee/r/Stage2Ib2', { file: 'ib2.lua', type: 'text/plain' })], expect: ['nested-loader', 'retrieved-reconstructed'] },
  { id: 'invalid-endpoint', category: 'invalid endpoint', loader: loader('https://raw.githubusercontent.com/qs-fixtures/demo/main/missing.lua'),
    service: [R('https://raw.githubusercontent.com/qs-fixtures/demo/main/missing.lua', { status: 404, file: body('404.txt', Buffer.from('404: Not Found')), type: 'text/plain' })], expect: ['transport-failed'] },
  { id: 'auth-failure', category: 'authentication failure', loader: loader('https://pastebin.com/raw/Private01'),
    service: [R('https://pastebin.com/raw/Private01', { status: 403, file: body('403.json', Buffer.from('{"error":"This paste is private"}')), type: 'application/json' })], expect: ['transport-failed'] },
  { id: 'service-unavailable', category: 'unavailable service', loader: loader('https://rentry.co/down/raw'),
    service: [R('https://rentry.co/down/raw', { fail: 'network' })], expect: ['transport-failed'] },
  { id: 'html-instead-of-script', category: 'malformed response', loader: loader('https://raw.githubusercontent.com/qs-fixtures/demo/main/page.lua'),
    service: [R('https://raw.githubusercontent.com/qs-fixtures/demo/main/page.lua', { file: body('page.html', Buffer.from('<!DOCTYPE html><html><body>Get a key to continue</body></html>')), type: 'text/html' })], expect: ['transport-failed'], note: 'the fetcher refuses web pages (415) before they reach the decoder' },
  { id: 'html-as-text', category: 'malformed response', loader: loader('https://paste.ee/r/HtmlText'),
    service: [R('https://paste.ee/r/HtmlText', { file: 'page.html', type: 'text/plain' })], expect: ['not-code'], note: 'a page served as text/plain passes the fetcher; the payload stage recognises it' },
  { id: 'truncated-gzip', category: 'malformed response', loader: loader('https://paste.ee/r/Truncated'),
    service: [R('https://paste.ee/r/Truncated', { file: body('truncated.gz', zlib.gzipSync(PLAIN).subarray(0, 40)), type: 'application/octet-stream' })], expect: ['invalid-payload'] },
  { id: 'json-error-200', category: 'malformed response', loader: loader('https://rentry.co/keyerr/raw'),
    service: [R('https://rentry.co/keyerr/raw', { file: body('keyerr.json', Buffer.from('{"success":false,"message":"Invalid key"}')), type: 'application/json' })], expect: ['not-code'] },
  { id: 'empty-200', category: 'malformed response', loader: loader('https://paste.ee/r/Empty01'),
    service: [R('https://paste.ee/r/Empty01', { file: body('empty.txt', Buffer.alloc(0)), type: 'text/plain' })], expect: ['transport-failed'], note: 'the fetcher answers 422 for an empty file' },
  { id: 'retrieved-unrecoverable', category: 'retrieved but unrecoverable', loader: loader('https://pastebin.com/raw/Zenfus01'),
    service: [R('https://pastebin.com/raw/Zenfus01', { file: body('zenfus.lua', ZEN), type: 'text/plain' })], expect: ['retrieved-unrecoverable'] },
  { id: 'luarmor', category: 'service with no authorised retrieval', loader: 'script_key = "ABCDEFGHIJ1234567890"\nloadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/0123456789abcdef0123456789abcdef.lua"))()\n',
    service: [], expect: ['not-retrievable'] },
  { id: 'keyed-url', category: 'requires an owner key', loader: loader('https://raw.githubusercontent.com/qs-fixtures/demo/main/x.lua?token=SECRET123'),
    service: [], expect: ['not-retrievable'] },
  { id: 'dynamic-url', category: 'generated dynamically', loader: 'local id = game.PlaceId\nloadstring(game:HttpGet("https://raw.githubusercontent.com/qs-fixtures/demo/main/" .. id .. ".lua"))()\n',
    service: [], expect: ['not-retrievable'] },
  { id: 'owner-roblox-model-obfuscated', category: 'authorised authenticated retrieval', loader: 'local M = require(4242424242)\nM.start()\n', providers: ['roblox-asset'],
    service: [R('provider:roblox-asset:4242424242', { file: body('asset-4242.rbxmx.gz', zlib.gzipSync(rbxmx('MainModule', IB2))), type: 'application/octet-stream' })], expect: ['retrieved-reconstructed'] },
  { id: 'owner-roblox-model-binary', category: 'authorised authenticated retrieval', loader: 'require(1111111111)\n', providers: ['roblox-asset'],
    service: [R('provider:roblox-asset:1111111111', { file: body('asset-1111.rbxm', MODEL_BIN), type: 'application/octet-stream' })], expect: ['retrieved-plain'] },
  { id: 'owner-provider-not-configured', category: 'authorised authenticated retrieval', loader: 'require(4242424242)\n',
    service: [], expect: ['not-retrievable'] },
  // Prompt XXI: payload validation and transport integrity
  { id: 'truncated-lua', category: 'truncated source', loader: loader('https://pastebin.com/raw/Cutoff01'),
    service: [R('https://pastebin.com/raw/Cutoff01', { file: body('cutoff.lua', PLAIN.subarray(0, Math.floor(PLAIN.length * 0.6))), type: 'text/plain' })], expect: ['invalid-payload'], note: 'Lua text that stops in the middle: reported as cut off, never passed to the pipeline' },
  { id: 'key-required-text', category: 'malformed response', loader: loader('https://rentry.co/needkey/raw'),
    service: [R('https://rentry.co/needkey/raw', { file: body('needkey.txt', Buffer.from('Key required. Get your key from our Discord, then run the loader again.')), type: 'text/plain' })], expect: ['not-code'], note: 'a message served with HTTP 200 is not a payload' },
  { id: 'short-transfer', category: 'truncated source', loader: loader('https://paste.ee/r/Short01'),
    service: [R('https://paste.ee/r/Short01', { file: 'plain.lua', type: 'text/plain', declared: PLAIN.length + 500 })], expect: ['transport-failed'], note: 'the server declared more bytes than it sent: the transfer is rejected as cut off' },
  { id: 'luau-bytecode', category: 'unsupported format', loader: loader('https://cdn.discordapp.com/attachments/1/2/chunk.bin'),
    service: [R('https://cdn.discordapp.com/attachments/1/2/chunk.bin', { file: body('chunk.luau', Buffer.from([5, 3, 2, 0, 1, 0, 0, 0, 7, 0x80, 0x81, 0x10, 0x11, 0x12, 0x13, 0, 0, 0, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a])), type: 'application/octet-stream' })], expect: ['unsupported-payload'] },
];
// The outcome class each stage must reach (src/validate/outcome.js), decided independently of the classifier and checked by tests/xix-loader-intel.test.mjs.
// null: a stage that is another loader (its program is analysed as the next stage, not classified on its own).
const RESULTS = {
  'direct-plain': ['validated'], 'public-ironbrew2': ['validated'], 'public-prometheus': ['validated'], 'encoded-base64-gzip': ['validated'],
  'encoded-json-field': ['validated'], 'encoded-hex-zlib': ['validated'], 'multi-stage': [null, 'validated'], 'invalid-endpoint': ['payload-unavailable'],
  'auth-failure': ['authorization-unavailable'], 'service-unavailable': ['payload-unavailable'], 'html-instead-of-script': ['payload-unavailable'],
  'html-as-text': ['payload-unavailable'], 'truncated-gzip': ['invalid-input'], 'json-error-200': ['payload-unavailable'], 'empty-200': ['payload-unavailable'],
  'retrieved-unrecoverable': ['not-deobfuscated'], luarmor: ['payload-unavailable'], 'keyed-url': ['authorization-unavailable'], 'dynamic-url': ['payload-unavailable'],
  'owner-roblox-model-obfuscated': ['validated'],
  // the model's only script is `local module = {} return module`: it does nothing a run can observe, so its behaviour cannot be validated
  'owner-roblox-model-binary': ['syntax-valid-unverified'],
  'owner-provider-not-configured': ['authorization-unavailable'],
  'truncated-lua': ['invalid-input'], 'key-required-text': ['payload-unavailable'], 'short-transfer': ['payload-unavailable'], 'luau-bytecode': ['unsupported-format'],
};
for (const c of cases) c.result = RESULTS[c.id];
fs.writeFileSync(path.join(out, 'manifest.json'), JSON.stringify({
  description: 'Loader fixtures: each case is a loader script and the responses a mock service gives for its addresses. Payloads are fixtures of this repository (originals, IronBrew 2, Prometheus, ZenFus outputs; a Roblox Studio model from rojo-rbx/rbx-test-files, MIT) wrapped in transport forms. Generated by tools/loaders/build-fixtures.mjs; no real service involved.',
  cases: cases.map((c) => ({ ...c, service: Object.fromEntries(c.service) })),
}, null, 1));
console.log(`${cases.length} cases, ${Object.keys(files).length} bodies`);
