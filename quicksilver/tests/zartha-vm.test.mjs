// Prompt XII: Zartha's virtual machine lifted back to source. Its functions are chains of per-instruction code written from templates; each piece is read as the Lua 5.1 instruction it
// stands for, nothing is a table of opcode numbers, and nothing of the program runs.
//
// The committed MIT fixtures (tests/corpus/obfuscated/zartha, generated in isolation from the upstream revision named in the manifest) are the evidence. Three things are kept apart:
//
//   * what was lifted (every fixture);
//   * whether the lifted program behaves like the ORIGINAL program (not like the tool's output: the generator's own SETGLOBAL, LOADBOOL and constant-protection templates are
//     defective, so for many builds the tool's output does not behave like the original, and the manifest says which);
//   * what cannot be recovered: strings masked by the unfinished constant-protection option, whose key the generator never writes anywhere. Those are reported, not promoted.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from '../src/core/parser.js';
import { bytesToBinary } from '../src/core/bytes.js';
import { fidelity } from '../src/core/fidelity.js';
import { structureScore, residualIndicators } from '../src/core/metrics.js';
import { recover } from '../src/recover/pipeline.js';
import { liftZarthaVm, looksLikeZartha, repairZarthaSource } from '../src/recover/zartha-vm.js';
import * as oracle from './helpers/lua-oracle.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const dir = path.join(here, 'corpus', 'obfuscated', 'zartha');
const read = (p) => bytesToBinary(fs.readFileSync(p));
after(() => oracle.stopOracle?.());
const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));
const files = fs.readdirSync(dir).filter((f) => f.endsWith('.lua')).sort();
const original = (f) => read(path.join(here, 'corpus', 'originals', `${f.split('__')[0]}.lua`));
const behaviour = new Map(manifest.entries.map((e) => [e.file, e.behavior]));
const masked = (f) => /__(constants|all)\.lua$/.test(f);

test('zartha: the shape is recognised without the watermark, and only for a Zartha build', () => {
  assert.equal(files.length, 54);
  for (const f of files) {
    const src = read(path.join(dir, f)).replace('File generated using [Zartha]', 'x');
    const fixed = repairZarthaSource(src).source;
    assert.ok(looksLikeZartha(parse(fixed)), f);
  }
  assert.equal(looksLikeZartha(parse('local a = 1 while true do a = a + 1 if a > 3 then break end end')), false);
});

test('zartha: every build — plain, minified, control-flow flattened, strings encrypted, anti-tamper, constant-protected — is lifted and structured', () => {
  for (const f of files) {
    const r = recover(read(path.join(dir, f)), {});
    assert.ok(r.ok, `${f}: ${r.warnings && r.warnings[0]}`);
    const step = r.steps.find((s) => s.id === 'zartha.vm');
    assert.ok(step && step.status === 'applied', `${f}: ${step && (step.detail || step.error)}`);
    assert.deepEqual(residualIndicators(r.output), [], `${f}: nothing of the VM is left`);
  }
});

test('zartha: builds whose strings are readable are recovered in full, and the program behaves like the original — including where the generator\'s own output does not', async () => {
  let checked = 0; let tool = 0;
  for (const f of files.filter((x) => !masked(x))) {
    const r = recover(read(path.join(dir, f)), {});
    assert.equal(r.report.unresolved.length, 0, f);
    assert.equal(r.confidence.level, 'high', f);
    const orig = original(f);
    assert.ok(structureScore(orig, r.output) >= 0.85, `${f}: structure ${structureScore(orig, r.output)}`);
    assert.ok(fidelity(orig, r.output).score >= 0.55, `${f}: fidelity ${fidelity(orig, r.output).score}`);
    assert.doesNotMatch(r.output, /_OBFUSCATED|_CRASH|Tamper detected/, `${f}: the marker and the anti-tamper block are gone`);
    if (!oracle.available) continue;
    const want = await oracle.runLua(orig, 'lua51');
    const got = await oracle.runLua(r.output, 'lua51');
    assert.ok(want.ok && got.ok, `${f}: ${got.error}`);
    assert.equal(got.stdout, want.stdout, f);
    checked++;
    if (behaviour.get(f) === 'equivalent') tool++;
  }
  if (oracle.available) {
    assert.equal(checked, 39);
    assert.equal(tool, 16, 'the builds the tool itself gets right are among them');
  }
});

test('zartha: the generator\'s defective templates are read as what they were made from (SETGLOBAL keeps the value\'s register, LOADBOOL the boolean, `_CRASH()` is a call)', () => {
  const f = 's01_minify_basic__antitamper.lua';
  const src = read(path.join(dir, f));
  const r = liftZarthaVm(parse(src));
  assert.ok(r.stats.functions >= 5 && r.stats.instructions >= 100);
  assert.equal(behaviour.get('s01_minify_basic__default.lua'), 'diverged', 'the tool\'s own output of this program does not run like the program');
  const out = recover(src, {}).output;
  assert.match(out, /print\("primes: "/);
});

test('zartha: strings masked with a per-constant key the generator never stores are reported as not recovered, and the confidence says so', () => {
  let seen = 0;
  for (const f of files.filter(masked)) {
    const r = recover(read(path.join(dir, f)), {});
    const step = r.steps.find((s) => s.id === 'zartha.vm');
    assert.ok(step.detail.masked > 0, `${f}: masked ${step.detail.masked}`);
    assert.notEqual(r.confidence.level, 'high', f);
    assert.ok(r.report.unresolved.some((u) => /masked with a key per constant/.test(u.text)), f);
    seen++;
  }
  assert.equal(seen, 15);
});

test('zartha: a build the generator wrote as invalid Lua (its LOADBOOL template) is mended where the damage is, and the report says so', () => {
  const f = path.join(dir, 's06_combined__default.lua');
  const src = read(f);
  assert.throws(() => parse(src));
  const r = recover(src, {});
  const step = r.steps.find((s) => s.id === 'zartha.repair');
  assert.ok(step && step.status === 'applied' && step.changed >= 1);
  assert.ok(r.ok);
  // only that text is mended: a script that merely carries the same words in a string is not touched
  assert.equal(repairZarthaSource('local s = "\\n\\tpointer = pointer + 1"').count, 0);
});

test('zartha: an instruction no template recognises is reported with its text and the program is not guessed at', () => {
  const src = read(path.join(dir, 's05_nested_functions__default.lua'));
  const broken = src.replace(/(\bif pointer == 1 then[^\n]*\n)/, '$1 Stack[0] = Stack[0] .. Stack[1] ');
  assert.notEqual(broken, src);
  const r = recover(broken, {});
  const step = r.steps.find((s) => s.id === 'zartha.vm');
  assert.equal(step.status, 'skipped');
  assert.match(step.detail, /not one this reader recognises|nothing is written/);
});

test('zartha: the report says what was done, and recovering the result again is unchanged in kind', () => {
  const r = recover(read(path.join(dir, 's05_nested_functions__flatten.lua')), {});
  assert.match(r.output.replace(/\n--\s+/g, ' '), /Virtual machine \(Zartha\), lifted back to source from its bytecode \(16 functions, 205 instructions, 17 constants\)/);
  const again = recover(r.output, {});
  assert.ok(again.ok);
  assert.equal(again.steps.find((s) => s.id === 'zartha.vm'), undefined);
});
