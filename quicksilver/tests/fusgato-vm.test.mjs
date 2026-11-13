// Prompt XII: FusGato's virtual machine lifted back to source. The program is a string of bits whose instruction words carry no opcode; the interpreter is `if pc == n then <handler>`,
// so each instruction is told by the text of its handler and its operands by the decoded bits. Only the four fixtures the generator produced a working file for exist (the other
// twelve runs ended in the generator's own errors, see the manifest); the handlers recognised are the ones those programs use, and nothing is guessed for an operation not seen.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { fidelity } from '../src/core/fidelity.js';
import { structureScore, residualIndicators } from '../src/core/metrics.js';
import { recover } from '../src/recover/pipeline.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const dir = path.join(here, 'corpus', 'obfuscated', 'fusgato');
const read = (p) => bytesToBinary(fs.readFileSync(p));
after(() => oracle.stopOracle?.());
const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));
const files = manifest.entries.filter((e) => e.status === 'ok').map((e) => e.file);
const original = (f) => read(path.join(here, 'corpus', 'originals', `${f.split('__')[0]}.lua`));

test('fusgato: every fixture the generator produced is lifted, structured and complete', () => {
  assert.equal(files.length, 4);
  for (const f of files) {
    const r = recover(read(path.join(dir, f)), {});
    const step = r.steps.find((s) => s.id === 'fusgato.vm');
    assert.ok(step && step.status === 'applied', `${f}: ${step && (step.detail || step.error)}`);
    assert.deepEqual(residualIndicators(r.output), [], f);
    assert.equal(r.report.unresolved.length, 0, f);
    assert.equal(r.confidence.level, 'high', f);
    assert.match(r.output.replace(/\n--\s+/g, ' '), /Virtual machine \(FusGato\), lifted back to source/);
    const orig = original(f);
    assert.ok(structureScore(orig, r.output) >= 0.9, `${f}: structure`);
    assert.ok(fidelity(orig, r.output).score >= 0.9, `${f}: fidelity`);
  }
});

test('fusgato: the lifted program behaves like the ORIGINAL program, including where the generator\'s own output does not (its comparison handlers ignore the A field)', async () => {
  const behaviour = new Map(manifest.entries.map((e) => [e.file, e.behavior]));
  assert.ok(files.some((f) => behaviour.get(f) === 'diverged'), 'the tool\'s own output of these programs does not run like them');
  if (!oracle.available) return;
  for (const f of files) {
    const r = recover(read(path.join(dir, f)), {});
    const want = await oracle.runLua(original(f), 'lua51');
    const got = await oracle.runLua(r.output, 'lua51');
    assert.ok(want.ok && got.ok, `${f}: ${got.error}`);
    assert.equal(got.stdout, want.stdout, f);
  }
});

test('fusgato: a handler no rule recognises is reported with its text, not guessed at', () => {
  const src = read(path.join(dir, files[0]));
  const broken = src.replace(/(elseif [a-z]==2 then )(n\[)/, '$1print(1) $2');
  assert.notEqual(broken, src);
  const r = recover(broken, {});
  const step = r.steps.find((s) => s.id === 'fusgato.vm');
  assert.equal(step.status, 'skipped');
  assert.match(step.detail, /not one this reader recognises/);
});
