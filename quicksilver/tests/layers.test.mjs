// Loader layers: `loadstring(<text>)()` where the text is a literal, folds to one, or is computed by a decoder in the script.
//
// The examples are tests/corpus/obfuscated/loaders (tests/corpus/tools/gen_loaders.mjs): packers written for this project, not the output of
// any real obfuscator. The measure is behavioural: the recovered program must print what the original program printed, on real Lua 5.1.
// Hercules' bytecode-encoding module is the real-tool case: its payload is a compiled Lua 5.4 chunk.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { recover } from '../src/recover/pipeline.js';
import { unwrapLayers } from '../src/passes/layers.js';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { fidelity } from '../src/core/fidelity.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';
after(() => oracle.stopOracle());
const read = (p) => fs.readFileSync(p).toString('latin1');

const loaders = JSON.parse(fs.readFileSync(path.join(corpus, 'obfuscated/loaders/manifest.json'), 'utf8'));

for (const e of loaders.entries) {
  test(`loaders/${e.file}: ${e.config} layer is unwrapped${e.needsSandbox ? ' with the sandbox' : ' statically'} and the program is unchanged`, { skip }, async () => {
    const original = read(path.join(corpus, 'originals', e.sample));
    const packed = read(path.join(corpus, 'obfuscated/loaders', e.file));
    const want = await oracle.runLua(original, 'lua51');
    assert.ok(want.ok, want.error);
    const packedRun = await oracle.runLua(packed, 'lua51');
    assert.ok(packedRun.ok, `the packed script does not run: ${packedRun.error}`);
    assert.equal(packedRun.stdout, want.stdout, 'the packer changed the program');

    const r = recover(packed, { sandbox: { enabled: true } });
    assert.equal(r.ok, true, JSON.stringify(r.warnings));
    const step = r.steps.find((s) => s.id === 'layers');
    assert.ok(step && step.status === 'applied', `the layers step did not apply: ${step ? JSON.stringify(step.detail) : 'missing'}`);
    assert.doesNotMatch(r.output, /\bloadstring\b|\bload\s*\(/, 'a loader call is left in the output');
    const got = await oracle.runLua(r.output, 'lua51');
    assert.ok(got.ok, `${got.error}\n${r.output.slice(0, 300)}`);
    assert.equal(got.stdout, want.stdout, 'the recovered program prints something else');
    assert.ok(fidelity(original, r.output).score >= 0.6, `fidelity ${fidelity(original, r.output).score.toFixed(2)}`);

    const without = recover(packed, { sandbox: { enabled: false } });
    const unwrapped = !/\bloadstring\b|\bload\s*\(/.test(without.output);
    assert.equal(unwrapped, !e.needsSandbox, e.needsSandbox ? 'a computed payload was read without the sandbox' : 'a literal payload needed the sandbox');
  });
}

// the real tool: Hercules' bytecode encoding hides a compiled Lua 5.4 chunk behind a hex string and an offset
const hercules = JSON.parse(fs.readFileSync(path.join(corpus, 'obfuscated/hercules/manifest.json'), 'utf8'));
for (const e of hercules.entries.filter((x) => x.status === 'ok' && x.config === 'mod-bytecode_encoding')) {
  test(`hercules/${e.file}: the compiled chunk is read back and decompiled`, { skip }, async () => {
    const src = read(path.join(corpus, 'obfuscated/hercules', e.file));
    const runtime = Object.entries(e.behaviors || {}).find(([, v]) => v !== 'errored')?.[0] || 'lua54';
    const want = await oracle.runLua(src, runtime);
    assert.ok(want.ok, want.error);
    const r = recover(src, { sandbox: { enabled: true } });
    assert.equal(r.ok, true, JSON.stringify(r.warnings));
    const step = r.steps.find((s) => s.id === 'layers');
    assert.ok(step && step.status === 'applied' && step.detail.bytecode === 1, step ? JSON.stringify(step.detail) : 'missing');
    assert.doesNotMatch(r.output, /\bload\s*\(|tonumber\(e:sub/);
    const got = await oracle.runLua(r.output, runtime);
    assert.ok(got.ok, `${got.error}\n${r.output.slice(0, 300)}`);
    assert.equal(got.stdout, want.stdout);
  });
}

// ---- the pieces ----------------------------------------------------------------------------------------------------------------------

const run = (src, sandbox = false) => {
  const ast = parse(src);
  const result = unwrapLayers(ast, { sandbox: { enabled: sandbox, fuel: 5_000_000, timeMs: 2_000, dialect: 'luau' } });
  return { result, text: print(ast).trim() };
};

test('a literal payload is put in place of the call, wherever the call is', () => {
  const { result, text } = run('print("before")\nif x then\n  loadstring("print(1)")()\nend\n(load or loadstring)("local y = 2 print(y)")()');
  assert.equal(result.inlined, 2);
  assert.doesNotMatch(text, /loadstring|load\b/);
  assert.match(text, /print\(1\)/);
  assert.match(text, /print\(y\)/);
});

test('a payload that returns a value or reads `...` is not inlined', () => {
  assert.equal(run('loadstring("return 5")()').result.inlined, 0);
  assert.equal(run('loadstring("print(...)")()').result.inlined, 0);
  assert.equal(run('loadstring("print(1")()').result.inlined, 0, 'a payload that does not parse is left alone');
});

test('a computed payload is never read without the sandbox', () => {
  const { result, text } = run('local s = ("pr"):rep(1) .. "int(1)"\nloadstring(s)()');
  assert.equal(result.changed, 0);
  assert.match(String(result.skipped), /sandboxed evaluation/);
  assert.match(text, /loadstring/);
});

test('with the sandbox, a decoder feeding the loader is run and the script becomes the payload', () => {
  const { result, text } = run('local s = ("pr"):rep(1) .. "int(1)"\nloadstring(s)()', true);
  assert.equal(result.replaced, 1);
  assert.equal(text, 'print(1)');
});

test('a script that does more than load is not replaced wholesale', () => {
  const { result, text } = run('game:GetService("Players")\nlocal s = "pr" .. "int(1)"\nloadstring(s)()', true);
  assert.equal(result.changed, 0);
  assert.match(String(result.skipped), /uses the global 'game'/);
  assert.match(text, /GetService/);
  const writes = run('flag = true\nlocal s = "pr" .. "int(1)"\nloadstring(s)()', true);
  assert.match(String(writes.result.skipped), /writes to a global/);
});

test('a loader that never hands text to load leaves the script alone', () => {
  const { result } = run('local f = loadstring or load\nlocal g = f and (function() return 1 end)\nloadstring(nil)()', true);
  assert.equal(result.changed, 0);
});
