// Roblox model files (src/loader/rbx.js): scripts read out of real Studio output, both encodings agreeing, LZ4 against the reference library.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { extractScripts, lz4Block, modelKind, RbxError } from '../src/loader/rbx.js';

const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), 'corpus', 'models');
const read = (...p) => new Uint8Array(fs.readFileSync(path.join(dir, ...p)));

test('LZ4 block decoding equals the reference implementation on its own compressed vectors', () => {
  const { cases } = JSON.parse(fs.readFileSync(path.join(dir, 'lz4-vectors.json'), 'utf8'));
  assert.ok(cases.length >= 20);
  for (const c of cases) assert.equal(Buffer.from(lz4Block(Buffer.from(c.c, 'hex'), c.n)).toString('hex'), c.d, `n=${c.n}`);
  assert.throws(() => lz4Block(Uint8Array.from([0x10, 0x41, 0x05, 0x00]), 10), RbxError, 'a match offset before the start is refused');
});

test('the ModuleScript source comes out of a binary model and equals the XML model of the same instance', () => {
  const b = extractScripts(read('default-inserted-modulescript', 'binary.rbxm'));
  const x = extractScripts(read('default-inserted-modulescript', 'xml.rbxmx'));
  assert.equal(b.kind, 'rbxm');
  assert.equal(x.kind, 'rbxmx');
  assert.deepEqual(b.scripts, [{ className: 'ModuleScript', name: 'ModuleScript', path: 'ModuleScript', source: 'local module = {}\n\nreturn module\n' }]);
  assert.deepEqual(x.scripts, b.scripts);
});

test('the parent chain gives each instance its path, the same in both encodings', () => {
  const b = extractScripts(read('three-nested-folders', 'binary.rbxm'));
  const x = extractScripts(read('three-nested-folders', 'xml.rbxmx'));
  assert.deepEqual(b.paths, ['Grandparent.Parent.Child:Folder', 'Grandparent.Parent:Folder', 'Grandparent:Folder']);
  assert.deepEqual(x.paths, b.paths);
  assert.equal(b.scripts.length, 0);
});

test('anything else is not taken for a model', () => {
  assert.equal(modelKind(new TextEncoder().encode('print("hi")')), null);
  assert.equal(modelKind(new TextEncoder().encode('<roblox version="4"><Item class="Script"></Item></roblox>')), 'rbxmx');
  assert.throws(() => extractScripts(new TextEncoder().encode('local x = 1')), RbxError);
  const truncated = read('default-inserted-modulescript', 'binary.rbxm').subarray(0, 60);
  assert.throws(() => extractScripts(truncated), RbxError, 'a cut file is an error, not a crash');
});
