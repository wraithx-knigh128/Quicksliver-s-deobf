// Prompt XIII: custom-format analysis. The probes measure transformations on the syntax tree; the analysis plans, tries the readers, recovers and explains what is left.
// Nothing here relies on the name of a tool: the unfamiliar VM below is written for this test and matches no reader.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { probe } from '../src/custom/probes.js';
import { analyzeCustom, neighbours, IDS } from '../src/custom/analyze.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, 'corpus');
const read = (p) => bytesToBinary(fs.readFileSync(path.join(corpus, p)));
const examples = JSON.parse(fs.readFileSync(path.join(here, '..', 'data/research/custom-examples.json'), 'utf8'));
const has = (r, id) => r.transformations.some((t) => t.id === id && t.confidence >= 0.5);

test('probes: the shape of the interpreter is read, not its name (per-instruction code, opcode tree, opcode chain, flattening predicates)', () => {
  const shape = (f) => probe(read(f)).transformations.find((t) => t.id === 'bytecode-vm');
  assert.equal(shape('obfuscated/zartha/s03_encoded_strings__default.lua').shape, 'per-instruction');
  assert.equal(shape('obfuscated/zartha/s03_encoded_strings__flatten.lua').shape, 'per-instruction');      // the counter hides behind arithmetic predicates
  assert.equal(shape('obfuscated/fusgato/s03_encoded_strings__default.lua').shape, 'per-instruction');
  assert.equal(shape('obfuscated/ironbrew2/s03_encoded_strings__default.lua').shape, 'opcode-tree');
  assert.equal(shape('obfuscated/luaxen/s03_encoded_strings__ironbrikked.lua').shape, 'opcode-tree');
  assert.equal(shape('obfuscated/obscura-1.1.0/s03_encoded_strings__vm.lua').shape, 'opcode-switch');
  assert.ok(shape('obfuscated/hercules-1.6.2/s03_encoded_strings__mod-VirtualMachine.lua'));
});

test('probes: the other transformations carry their evidence, and a plain program shows none', () => {
  assert.ok(has(probe(read('obfuscated/luaxen/s03_encoded_strings__ast.lua')), 'metamethod-arithmetic'));
  assert.ok(has(probe(read('obfuscated/prometheus/s03_encoded_strings__Strong.lua')), 'numeric-obfuscation'));
  const z = probe(read('obfuscated/zartha/s03_encoded_strings__default.lua')).transformations.find((t) => t.id === 'bytecode-vm');
  assert.ok(z.evidence.length >= 2 && /dispatches on/.test(z.evidence[0]));
  assert.ok(Object.keys(z.profile).length >= 6, 'the handlers cover the operations of a register machine');
  for (const f of fs.readdirSync(path.join(corpus, 'originals')).filter((x) => x.endsWith('.lua'))) {
    const r = probe(read(`originals/${f}`));
    assert.deepEqual(r.transformations.filter((t) => t.confidence >= 0.5).map((t) => t.id), [], f);
  }
});

// a virtual machine written for this test: a register machine over a table of instructions, nothing like any tool's
const UNFAMILIAR = `
local K = {"hello", "world", 7}
local P = { {1, 1, 1}, {1, 2, 2}, {5, 3, 1, 2}, {6, 3}, {1, 4, 3}, {7, 4, 4, 4}, {2, 0} }
local R, pc = {}, 1
while true do
  local i = P[pc]
  local op = i[1]
  if op == 1 then R[i[2]] = K[i[3]]
  elseif op == 2 then return
  elseif op == 3 then R[i[2]] = R[i[3]] + R[i[4]]
  elseif op == 4 then R[i[2]] = R[i[3]] - R[i[4]]
  elseif op == 5 then R[i[2]] = R[i[3]] .. R[i[4]]
  elseif op == 6 then print(R[i[2]])
  elseif op == 7 then R[i[2]] = R[i[3]] * R[i[4]]
  elseif op == 8 then if R[i[2]] == R[i[3]] then pc = pc + 1 end
  elseif op == 9 then pc = pc + i[2]
  elseif op == 10 then R[i[2]] = #R[i[3]]
  elseif op == 11 then R[i[2]] = {}
  elseif op == 12 then R[i[2]][R[i[3]]] = R[i[4]]
  end
  pc = pc + 1
end
`;

test('an unfamiliar VM is recognised by what its handlers do, and the explanation says every reader refused and why', () => {
  const r = analyzeCustom(UNFAMILIAR, { examples });
  assert.ok(r.ok);
  const vm = r.input.transformations.find((t) => t.id === 'bytecode-vm');
  assert.ok(vm && vm.confidence >= 0.5, 'found');
  assert.equal(vm.shape, 'opcode-switch');
  assert.ok(vm.handlers >= 10);
  assert.ok(r.readers.length >= 4 && r.readers.every((x) => !x.ok && x.reason), 'each reader says why it refused');
  const e = r.explanation.find((x) => x.transformation === 'bytecode-vm');
  assert.equal(e.status, 'unresolved');
  assert.ok(e.notes.some((n) => /Zartha/.test(n)) && e.notes.length >= 3);
  assert.ok(r.neighbors.length === 3 && r.neighbors.every((n) => n.similarity >= 0));
});

test('a build one of the readers reads is resolved, and the reader that read it is named', () => {
  const r = analyzeCustom(read('obfuscated/zartha/s05_nested_functions__flatten.lua'), { examples });
  assert.ok(r.ok);
  const e = r.explanation.find((x) => x.transformation === 'bytecode-vm');
  assert.equal(e.status, 'resolved');
  assert.match(e.notes.join(' '), /Zartha/);
  assert.ok(r.readers.find((x) => /Zartha/.test(x.reader)).ok);
  assert.ok(r.result.ok && r.result.level === 'high');
  assert.equal(r.summary.unresolved, 0);
});

test('a layered chain shows its layers and the analysis says which are gone', () => {
  const r = analyzeCustom(read('obfuscated/mixed/s01_minify_basic__hercules-heavy+light.lua'), { sandbox: { enabled: true }, examples });
  assert.ok(r.ok);
  assert.ok(r.input.transformations.length >= 2);
  assert.ok(r.explanation.every((x) => ['resolved', 'reduced', 'unresolved'].includes(x.status) && x.notes.length >= 1));
});

test('a script that does not parse is reported with its position, not analysed', () => {
  const r = analyzeCustom('local x = = 1');
  assert.equal(r.ok, false);
  assert.equal(r.stage, 'probe');
  assert.ok(r.error.line >= 1);
});

test('the examples: schema, counts, and an evaluation that says what the nearest example is worth', () => {
  assert.equal(examples.schema, 'quicksilver/custom-examples@1');
  assert.deepEqual(examples.ids, IDS);
  assert.ok(examples.counts.examples >= 300 && examples.counts.tools >= 15);
  const e = examples.evaluation;
  // the numbers are measured, and they are shown next to every prediction: the nearest example must at least beat always saying "yes", also for a tool it has never seen
  assert.ok(e.leaveOneOut.accuracy > e.baseRate, `${e.leaveOneOut.accuracy} vs ${e.baseRate}`);
  assert.ok(e.leaveOneToolOut.accuracy > e.baseRate, `${e.leaveOneToolOut.accuracy} vs ${e.baseRate}`);
  assert.ok(examples.examples.every((x) => x.vector.length === IDS.length && x.outcome && typeof x.tool === 'string'));
});

test('neighbours: the closest examples share the transformations of the script, whatever tool made them (nothing says which family)', () => {
  const target = examples.examples.find((x) => x.tool === 'zartha' && x.config === 'flatten');
  const near = neighbours(target.transformations.map((id) => ({ id, confidence: target.vector[IDS.indexOf(id)] })), examples, 3, target.id);
  assert.equal(near.length, 3);
  const jaccard = (a, b) => { const A = new Set(a); const B = new Set(b); const i = [...A].filter((x) => B.has(x)).length; return i / (A.size + B.size - i || 1); };
  for (const n of near) assert.ok(n.similarity > 0.8 && jaccard(n.transformations, target.transformations) >= 0.5, `${n.id} ${n.similarity}`);
});
