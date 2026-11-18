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
