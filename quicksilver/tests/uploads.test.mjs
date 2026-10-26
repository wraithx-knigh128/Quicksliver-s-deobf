// Two scripts a user supplied for analysis: RideAPet.lua, a wrapper around a zstd-compressed MoonVeil 2.0.25 script, and Tech-hub.lua, a Kirus 1.5
// bytecode VM. Everything here is static: nothing from either script is executed.
//
// The scripts are not part of the repository or of the site: they are looked up in tests/corpus/user-local/ (git-ignored), and the tests that need them are
// skipped, with a reason, when they are absent. The tests that do not need them build their inputs here.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';
import { recover } from '../src/recover/pipeline.js';
import { detect } from '../src/detect/detect.js';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { unwrapLayers } from '../src/passes/layers.js';
import { z85Decode, xorDecrypt, moonveilShape, decodeMoonVeilConstants } from '../src/recover/moonveil.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const localPath = (name) => path.join(here, 'corpus/user-local', name);
const read = (name) => fs.readFileSync(localPath(name)).toString('latin1');
const missing = (...names) => (names.every((n) => fs.existsSync(localPath(n))) ? false : `tests/corpus/user-local/${names.join(', ')} is not present (scripts supplied for analysis are not stored in the repository)`);
const family = (d, id) => d.families.find((f) => f.id === id);

// ---- the wrapper: EncodingService + zstd ------------------------------------------------------------------------------------------------

const wrapper = (text, algorithm = 'Zstd', tail = '(...)') => {
  const b64 = zlib.zstdCompressSync(Buffer.from(text, 'latin1')).toString('base64');
  return `task.spawn(function() print("hub loading") end)\nreturn loadstring(buffer.tostring(game:GetService'EncodingService':DecompressBuffer(buffer.fromstring(base64.decode'${b64}'),Enum.CompressionAlgorithm.${algorithm})))${tail}\n`;
};

test('layers: an EncodingService zstd payload is read without running anything and takes the place of the loader call', () => {
  const program = 'local greeting = "hello"\nlocal function shout(s)\n  return s:upper()\nend\nprint(shout(greeting))\nreturn greeting\n';
  const r = recover(wrapper(program), {});
  assert.equal(r.ok, true);
  assert.match(r.output, /task\.spawn\(function\(\)\s+print\("hub loading"\)\s+end\)/, 'the statements around the loader are kept');
  assert.match(r.output, /local function shout\(/);
  assert.doesNotMatch(r.output, /EncodingService|base64|DecompressBuffer/);
  const layers = r.steps.find((s) => s.id === 'layers');
  assert.equal(layers.status, 'applied');
  assert.equal(layers.detail.compressed, 1);
});

test('layers: the payload becomes a function called with the same arguments when the loader is not the last statement or a local could capture a name', () => {
  const inner = 'print(...)\nreturn counter\n';
  const out = recover(wrapper(inner, 'Zstd', '(1, 2)'), {}).output;
  assert.match(out, /return \(function\(\.\.\.\)/);
  assert.match(out, /print\(\.\.\.\)/);
  assert.match(out, /end\)\(1, 2\)/);
  // a local declared before the loader would capture a global the payload reads, so the payload is not spliced in
  const shadow = `local counter = 5\n${wrapper(inner)}`;
  assert.match(recover(shadow, {}).output, /return \(function\(\.\.\.\)/);
});

test('layers: another compression algorithm is reported, not guessed at', () => {
  const ast = parse(wrapper('print(1)', 'Deflate'));
  const r = unwrapLayers(ast, {});
  assert.equal(r.compressed, 0);
  assert.ok(r.notes.some((n) => /Deflate/.test(n)), JSON.stringify(r.notes));
  assert.match(print(ast), /DecompressBuffer/);
});

test('detect: the compressed-payload trait names the wrapper before anything is unwrapped', () => {
  const d = detect(wrapper('print(1)'));
  assert.ok(d.traits.some((t) => t.id === 'compressed-payload'));
});

// ---- MoonVeil building blocks -------------------------------------------------------------------------------------------------------------

const Z85 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~';
function z85Encode(bytes) {
  const pad = (4 - (bytes.length % 4)) % 4;
  const b = [...bytes, ...Array(pad).fill(0)];
  let out = '';
  for (let i = 0; i < b.length; i += 4) {
    let v = ((b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3]) >>> 0;
    const digits = [];
    for (let k = 0; k < 5; k++) { digits.unshift(Z85[v % 85]); v = Math.floor(v / 85); }
    out += digits.join('');
  }
  return out.slice(0, out.length - pad);
}

test('moonveil: the Z85 text and the XOR cipher are read the way the script reads them', () => {
  for (const text of ['', 'a', 'ab', 'abc', 'abcd', 'abcde', 'Parent', '<I2', 'Linkhive_RideAPet/WindowPrefs.json']) {
    const bytes = [...Buffer.from(text, 'latin1')];
    assert.equal(z85Decode(z85Encode(bytes)), text, `round trip of ${JSON.stringify(text)}`);
  }
  const key = 'k3y';
  const cipher = [...'secret text'].map((c, i) => String.fromCharCode(c.charCodeAt(0) ^ key.charCodeAt(i % key.length))).join('');
  assert.equal(xorDecrypt(cipher, key), 'secret text');
});

test('moonveil: scripts that are not MoonVeil tables are left alone', () => {
  assert.equal(moonveilShape(parse('return ({ function() end }):go({ "a" }, "a", ...)')), false, 'the permutation is not there');
  assert.equal(moonveilShape(parse('print(1)')), false);
  const ast = parse('print(1)');
  assert.deepEqual({ ...decodeMoonVeilConstants(ast), strings: undefined }, { changed: 0, numbers: 0, undecoded: 0, strings: undefined });
  if (!missing('Tech-hub.lua')) assert.equal(moonveilShape(parse(read('Tech-hub.lua'))), false);
});

// ---- RideAPet.lua ------------------------------------------------------------------------------------------------------------------------------

test('RideAPet: the whole chain is unwrapped statically, the MoonVeil script is named, and what is left is reported as such', { skip: missing('RideAPet.lua') }, () => {
  const src = read('RideAPet.lua');
  const before = detect(src);
  assert.equal(before.families.length, 0, 'the wrapper alone shows no obfuscator');
  assert.ok(before.traits.some((t) => t.id === 'compressed-payload'));

  const t0 = Date.now();
  const r = recover(src, { sandbox: { enabled: false } });
  const ms = Date.now() - t0;
  assert.equal(r.ok, true, JSON.stringify(r.warnings));
  assert.ok(ms < 60_000, `recovery took ${ms} ms`);

  const mv = family(r.detection, 'moonveil');
  assert.ok(mv && mv.confidence >= 0.95 && mv.version === '2.0.25', JSON.stringify(mv && [mv.confidence, mv.version]));
  assert.ok(mv.evidence.some((e) => e.rule === 'table-script'));
  assert.ok(mv.evidence.some((e) => e.rule === 'vm-blob' && e.unrecoverable), 'the VM-compiled part is flagged');
  assert.equal(r.detection.layers, 1);

  // the wrapper's own statements are still there, including the remote fetch it makes
  assert.match(r.output, /loadstring\(game:HttpGet\(\s*"https:\/\/[^"]+"/);
  // constants the script hid are in the open: strings and numbers
  const mvStep = r.steps.find((s) => s.id === 'moonveil.constants');
  assert.ok(mvStep && mvStep.status === 'applied' && mvStep.changed >= 700, JSON.stringify(mvStep));
  assert.ok(mvStep.detail.strings.includes('<I2') && mvStep.detail.numbers > 700);
  assert.equal(mvStep.detail.undecoded, 0);
  assert.doesNotMatch(r.output, /\.(Ye|jf|ef|qf)\[-?\d+\] or /, 'a call site of a constant wrapper is left');
  // the cell variables read as fields
  assert.ok(r.steps.find((s) => s.id === 'moonveil.cells').changed > 2000);
  assert.doesNotMatch(r.output, /\[1\]\[2\]\[\w+\[1\]\[1\]\]/);
  // readable behaviour of the script itself
  assert.match(r.output, /\.json/);
  assert.match(r.output, /games\.roblox\.com\/v1\/games\//);
  assert.match(r.output, /:FireServer\(/);

  // the program inside the VM is read back from the VM's own data: nothing of the interpreter is left, and the report says it was not run
  const vmStep = r.steps.find((s) => s.id === 'moonveil.vm');
  assert.ok(vmStep && vmStep.status === 'applied', JSON.stringify(vmStep));
  assert.equal(vmStep.detail.notStructured, 0);
  assert.ok(vmStep.detail.protos >= 50 && vmStep.detail.natives > 100, JSON.stringify(vmStep.detail));
  assert.doesNotMatch(r.output, /\bCHILDREN\b|\bVARARGS\b|\bvm_[a-z0-9_]+\(/);
  assert.ok(r.confidence.score > 0.5 && !r.confidence.hints.includes('trace'), `the program was rebuilt (${r.confidence.score})`);
  assert.ok(r.confidence.reasons.some((x) => /without running anything/.test(x.text)), 'the report says nothing was run');
});

test('RideAPet: the general passes still work when the VM reader is switched off, and say the program is still inside the VM', { skip: missing('RideAPet.lua') }, () => {
  const r = recover(read('RideAPet.lua'), { sandbox: { enabled: false }, moonveilVm: false });
  assert.equal(r.ok, true);
  assert.ok(!r.steps.some((s) => s.id === 'moonveil.vm'));
  assert.ok(r.confidence.score <= 0.2 && r.confidence.hints.includes('trace'), `a VM-compiled part is still present (${r.confidence.score})`);
});

// ---- Tech-hub.lua ------------------------------------------------------------------------------------------------------------------------------

test('Tech-hub: a Kirus VM is named from its banner and its entry call, and is not claimed to be recovered', { skip: missing('Tech-hub.lua') }, () => {
  const src = read('Tech-hub.lua');
  const d = detect(src);
  const k = family(d, 'kirus');
  assert.ok(k && k.confidence >= 0.95 && k.version === '1.5', JSON.stringify(k && [k.confidence, k.version]));
  assert.ok(k.evidence.some((e) => e.rule === 'vm-entry' && e.unrecoverable));
  assert.equal(d.families.filter((f) => f.confidence >= 0.5).length, 1);

  const stripped = src.replace(/^--[^\n]*\n/, '');
  assert.ok(family(detect(stripped), 'kirus').evidence.some((e) => e.rule === 'vm-entry'), 'the entry call is recognised without the banner');

  const t0 = Date.now();
  const r = recover(src, { sandbox: { enabled: false } });
  assert.equal(r.ok, true);
  assert.ok(Date.now() - t0 < 60_000);
  assert.ok(r.confidence.score <= 0.4, `confidence ${r.confidence.score}`);
  assert.ok(r.confidence.hints.includes('trace'));
  assert.match(r.output, /bit32/, 'the VM is still there');
});

test('Tech-hub: the identifier strings the runtime builds from XOR pairs read as the APIs it touches (static arithmetic on literals)', { skip: missing('Tech-hub.lua') }, () => {
  const ast = parse(read('Tech-hub.lua'));
  const names = [];
  const visit = (n) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(visit); return; }
    if (n.type === 'Local' && n.values.length === 1) {
      const v = n.values[0];
      if (v.type === 'Call' && v.fn.type === 'Name' && v.args.length === 1 && v.args[0].type === 'Table' && v.args[0].fields.length > 2
        && v.args[0].fields.every((f) => f.value.type === 'Call' && f.value.args.length === 1 && f.value.args[0].type === 'Call' && f.value.args[0].args.length === 2 && f.value.args[0].args.every((a) => a.type === 'Number'))) {
        names.push(v.args[0].fields.map((f) => String.fromCharCode(f.value.args[0].args[0].value ^ f.value.args[0].args[1].value)).join(''));
      }
    }
    for (const k of Object.keys(n)) if (typeof n[k] === 'object') visit(n[k]);
  };
  visit(ast);
  for (const want of ['loadstring', 'getgenv', 'setfenv', 'collectgarbage', 'RobloxScript', 'getrawmetatable', 'setnamecallmethod', '__namecall', 'Solara', 'Xeno']) {
    assert.ok(names.includes(want), `${want} not among ${names.length} decoded names`);
  }
});
