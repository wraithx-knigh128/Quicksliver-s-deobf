// AzureVM (github.com/LionHub-Pino/AzureVM, MIT): its Lua 5.1 bytecode VM lifted back to source (Prompt XVI). The 48 committed builds
// were generated in the isolated Lua runner; every one has an original to compare with.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { parse } from '../src/core/parser.js';
import { recover } from '../src/recover/pipeline.js';
import { liftAzureVM } from '../src/recover/azurevm.js';
import { checkAgainstChunk } from '../src/recover/bytecode-check.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const dir = path.join(corpus, 'obfuscated/azurevm');
const read = (p) => bytesToBinary(fs.readFileSync(p));
const run = (src) => recover(src, { sandbox: { enabled: true } });
const noOracle = !oracle.available && 'no Lua oracle (QS_LUA_PYTHON)';
after(() => oracle.stopOracle?.());
const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));

test('azurevm: the decoded program is the original chunk (it runs like the original on the reference Lua 5.1)', { skip: noOracle }, async () => {
  for (const f of ['s01_minify_basic__Fast.lua', 's05_nested_functions__Luraph14.lua', 's06_combined__AzureGod15.lua']) {
    const r = liftAzureVM(parse(read(path.join(dir, f))));
    const esc = [...r.bytes].map((c) => `\\${c.charCodeAt(0)}`).join('');
    const got = await oracle.runLua(`local f, e = loadstring("${esc}") if not f then error(e) end return f(...)`, 'lua51');
    const want = await oracle.runLua(fs.readFileSync(path.join(corpus, 'originals', f.split('__')[0] + '.lua'), 'latin1'), 'lua51');
    assert.ok(got.ok, `${f}: ${got.error}`);
    assert.equal(got.stdout, want.stdout, f);
  }
});

test('azurevm: the 38 handlers are read off their templates, decoys are left aside', () => {
  const r = liftAzureVM(parse(read(path.join(dir, 's01_minify_basic__AzureGod15.lua'))));
  assert.ok(r.stats.decoyHandlers > 0);
  assert.ok(r.stats.functions >= 1 && r.stats.instructions > 0);
});

test('azurevm: a reconstruction that behaves differently from its decoded chunk is refused (the sandbox self-check)', () => {
  const r = liftAzureVM(parse(read(path.join(dir, 's01_minify_basic__Fast.lua'))));
  assert.equal(checkAgainstChunk(r.bytes, 'print("something else")').same, false);
});

test('azurevm: every build either runs like the original (or like the tool where the tool diverges), or keeps its VM and says so', { skip: noOracle }, async () => {
  const bad = [];
  for (const e of manifest.entries.filter((x) => x.status === 'ok')) {
    const src = read(path.join(dir, e.file));
    const r = run(src);
    const want = await oracle.runLua(fs.readFileSync(path.join(corpus, 'originals', e.sample), 'latin1'), 'lua51');
    const got = await oracle.runLua(r.output, 'lua51');
    const st = r.steps.find((x) => x.id === 'azurevm.vm');
    const lifted = st && st.status === 'applied';
    if (got.ok && got.stdout === want.stdout) {
      if (!lifted && e.config !== 'Balanced' && r.confidence.level === 'high') bad.push(`${e.file}: VM kept but rated high`);
      continue;
    }
    const tool = await oracle.runLua(src, 'lua51');
    if (tool.ok === got.ok && tool.stdout === got.stdout) continue;
    bad.push(`${e.file}: ${got.error || 'output differs'} (${r.confidence.level})`);
  }
  assert.deepEqual(bad, []);
});

test('azurevm (Prompt XXX): after the clean-up passes, every lifted program still behaves like the VM’s decoded bytecode', () => {
  // the pipeline checks each step after a verified lift against the decoded chunk and undoes one that changes what the program does
  // (s04_control_flow__AzureGodUltra: one round of the decoder evaluation read a `pool[decode(...)]` site as "")
  const bad = [];
  let lifted = 0;
  for (const e of manifest.entries.filter((x) => x.status === 'ok')) {
    const src = read(path.join(dir, e.file));
    const r = run(src);
    const st = r.steps.find((x) => x.id === 'azurevm.vm');
    if (!st || st.status !== 'applied') continue;
    lifted++;
    const c = checkAgainstChunk(liftAzureVM(parse(src)).bytes, r.output);
    if (c.checked && !c.same) bad.push(`${e.file}: ${c.reason}`);
  }
  assert.ok(lifted > 0);
  assert.deepEqual(bad, []);
});
