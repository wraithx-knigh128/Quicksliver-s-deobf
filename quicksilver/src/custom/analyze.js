// Custom-format analysis: what an unfamiliar script was made into, what can be done about it, what was done, and what is left and why.
//
// This is not a lookup of tool names. It is four things in sequence, each of which can be read and checked:
//
//   1. PROBE      the structure of the script is measured (src/custom/probes.js): which transformations it shows, with the evidence for each;
//   2. PLAN       each transformation is mapped to the capabilities of the engine that address it, in the order the pipeline will use them, and the readers of
//                 virtual-machine formats are TRIED against the script one by one, each returning what it found or why it refused;
//   3. RECOVER    the pipeline runs (the sandbox only when the caller allows it);
//   4. EXPLAIN    the output is probed again. A transformation that is gone is resolved, one that is weaker is reduced, one that is still there is unresolved and is explained
//                 with the refusals of the capabilities that were tried. What the validated examples show for scripts shaped like this one is added as context, never as a verdict.
//
// The collection of validated examples (data/research/custom-examples.json, written by tools/research/build-custom-examples.mjs) grows when new samples are verified; the
// analysis reads it to say what happened to the closest scripts, and tools/research/build-custom-examples.mjs measures how well that prediction does on held-out samples.

import { parse } from '../core/parser.js';
import { recover } from '../recover/pipeline.js';
import { probe, TRANSFORMATIONS } from './probes.js';
import { liftZarthaVm } from '../recover/zartha-vm.js';
import { liftFusgatoVm } from '../recover/fusgato-vm.js';
import { liftIronbrikkedVm } from '../recover/ironbrikked-vm.js';
import { readHerculesVm } from '../recover/hercules-vm.js';
import { recoverIronBrew } from '../recover/ironbrew.js';

export const IDS = Object.keys(TRANSFORMATIONS);

/** Which steps of the pipeline address which transformation, in the order they run. A step that did not apply is reported with its reason. */
export const CAPABILITIES = {
  'bytecode-vm': [
    { step: 'zartha.vm', when: (t) => t.shape === 'per-instruction', what: 'per-instruction code written from templates (Zartha)' },
    { step: 'fusgato.vm', when: (t) => t.shape === 'per-instruction', what: 'per-instruction handlers over a bit-string program (FusGato)' },
    { step: 'ironbrew2', when: (t) => t.shape === 'opcode-tree', what: 'IronBrew 2 opcode tree' },
    { step: 'ironbrikked.vm', when: (t) => t.shape === 'opcode-tree', what: 'opcode tree over compressed bytes (LuaXen IronBrikked)' },
    { step: 'obscura.vm', when: (t) => t.shape === 'opcode-switch', what: 'handler chain with per-build opcode bytes (Obscura)' },
    { step: 'hercules.vm', when: (t) => t.shape === 'opcode-switch', what: 'Lua 5.1 bytecode in a text (Hercules)' },
    { step: 'moonveil.vm', when: () => true, what: 'MoonVeil bytecode VM' },
  ],
  'control-flow-flattening': [{ step: 'adaptive', what: 're-raising of flattened and lowered control flow' }, { step: 'moonveil.cff', what: 'MoonVeil flattening' }],
  'string-encryption': [{ step: 'evaluate', what: 'running the decoder on its constant arguments (needs the sandbox)' }, { step: 'strtable.inline', what: 'string tables' }, { step: 'prometheus.orphans', what: 'decryption machinery nothing reads' }],
  'constant-table': [{ step: 'constants.inline', what: 'a table of constants that is only read' }, { step: 'strtable.inline', what: 'self-decrypting string tables' }],
  'compressed-payload': [{ step: 'layers', what: 'unwrapping a computed payload (needs the sandbox)' }, { step: 'hercules.vm', what: 'bytecode text' }],
  'identifier-mangling': [{ step: 'rename', what: 'names guessed from how variables are used' }],
  'numeric-obfuscation': [{ step: 'fold', what: 'constant folding' }, { step: 'evaluate', what: 'evaluation' }],
  'metamethod-arithmetic': [{ step: 'metaarith', what: 'arithmetic through metamethods' }],
  wrapper: [{ step: 'unwrap', what: 'a wrapper function' }, { step: 'layers', what: 'loaded text' }],
  'dead-code': [{ step: 'simplify', what: 'dead branches' }, { step: 'tidy', what: 'known conditions' }],
  'environment-probe': [{ step: 'prometheus.antitamper', what: 'anti-tamper blocks' }, { step: 'zartha.guards', what: 'generator guards' }, { step: 'colisseum.guard', what: 'tamper guards' }],
  'minified-layout': [{ step: 'format', what: 'layout' }],
};

/** The readers of virtual-machine formats, tried on the script itself: each says what it found or why it refused. Nothing is run. */
export function tryReaders(source) {
  let ast;
  try { ast = parse(source); } catch (e) { return [{ reader: 'all', ok: false, reason: `the script does not parse: ${e.message}` }]; }
  const attempts = [
    ['Zartha (per-instruction templates)', () => liftZarthaVm(ast)],
    ['FusGato (per-instruction handlers, bit string)', () => liftFusgatoVm(ast)],
    ['LuaXen IronBrikked (opcode tree, compressed bytes)', () => liftIronbrikkedVm(ast)],
    ['IronBrew 2 (opcode tree)', () => recoverIronBrew(ast)],
    ['Hercules (bytecode text)', () => readHerculesVm(ast)],
  ];
  return attempts.map(([reader, run]) => {
    try {
      const r = run();
      if (r === null) return { reader, ok: false, reason: 'no call of this format was found' };
      return { reader, ok: true, detail: r.stats || r.stats === undefined ? 'the program was read' : 'the program was read' };
    } catch (e) {
      return { reader, ok: false, reason: String(e.message || e).slice(0, 200) };
    }
  });
}

const vec = (ts) => IDS.map((id) => { const t = ts.find((x) => x.id === id); return t ? t.confidence : 0; });
const cosine = (a, b) => { let d = 0; let na = 0; let nb = 0; for (let i = 0; i < a.length; i++) { d += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]; } return na && nb ? d / Math.sqrt(na * nb) : 0; };

/** The closest validated examples, by the transformations they show; with what happened to them. */
export function neighbours(transformations, examples, k = 3, skip = null) {
  if (!examples || !examples.examples) return [];
  const v = vec(transformations);
  return examples.examples.filter((e) => e.id !== skip).map((e) => ({ e, s: cosine(v, e.vector) })).sort((a, b) => b.s - a.s).slice(0, k)
    .map(({ e, s }) => ({ id: e.id, similarity: +s.toFixed(2), transformations: e.transformations, outcome: e.outcome }));
}

/**
 * @param {string} source binary string
 * @param {{sandbox?: object, examples?: object, recoverOptions?: object}} [options]
 */
export function analyzeCustom(source, options = {}) {
  const t0 = Date.now();
  const input = probe(source);
  if (!input.ok) return { ok: false, stage: 'probe', error: input.error, input };
  const strong = input.transformations.filter((t) => t.confidence >= 0.5);
  // PLAN
  const plan = strong.map((t) => ({
    transformation: t.id,
    description: t.description,
    confidence: t.confidence,
    capabilities: (CAPABILITIES[t.id] || []).filter((c) => !c.when || c.when(t)).map((c) => ({ step: c.step, what: c.what })),
  }));
  const hasVm = strong.some((t) => t.id === 'bytecode-vm');
  const readers = hasVm || strong.some((t) => t.id === 'compressed-payload') ? tryReaders(source) : [];
  // RECOVER
  const r = recover(source, { ...(options.recoverOptions || {}), sandbox: { enabled: !!(options.sandbox && options.sandbox.enabled), ...(options.sandbox || {}) } });
  const applied = (r.steps || []).filter((s) => s.status === 'applied').map((s) => ({ id: s.id, changed: s.changed }));
  const skipped = (r.steps || []).filter((s) => s.status === 'skipped' || s.status === 'failed').map((s) => ({ id: s.id, reason: String(s.detail || s.error || '').slice(0, 220), status: s.status }));
  // EXPLAIN
  const output = r.output || '';
  const after = r.ok && output ? probe(output) : { ok: false, transformations: [] };
  const explanation = strong.map((t) => {
    const was = after.transformations.find((x) => x.id === t.id);
    const addressed = (CAPABILITIES[t.id] || []).filter((c) => !c.when || c.when(t));
    const appliedHere = addressed.filter((c) => applied.some((a) => a.id === c.step));
    const refused = addressed.map((c) => skipped.find((s) => s.id === c.step)).filter(Boolean);
    let status;
    if (!was || was.confidence < 0.5) status = 'resolved';
    else if (was.confidence < t.confidence - 0.1) status = 'reduced';
    else status = 'unresolved';
    const lines = [];
    if (status === 'resolved') lines.push(appliedHere.length ? `Addressed by ${appliedHere.map((c) => c.what).join('; ')}.` : 'No longer visible in the result.');
    else {
      if (appliedHere.length) lines.push(`${appliedHere.map((c) => c.what).join('; ')} ran and changed the script, but ${was.evidence[0]} is still there.`);
      for (const s of refused) lines.push(`${s.id}: ${s.reason || 'did not apply'}`);
      if (t.id === 'bytecode-vm') for (const x of readers.filter((y) => !y.ok)) lines.push(`${x.reader}: ${x.reason}`);
      if (t.id === 'string-encryption' && !(options.sandbox && options.sandbox.enabled)) lines.push('The decoder was not run: the sandbox is off, and a decoder cannot be read without running it.');
      if (!lines.length) lines.push('No capability of the engine addresses this shape; the evidence above says where it is.');
    }
    return { transformation: t.id, status, evidence: t.evidence, remaining: was ? was.evidence : [], notes: lines };
  });
  // anything the recovery INTRODUCED (a transformation visible in the output and not in the input)
  const introduced = after.transformations.filter((t) => t.confidence >= 0.6 && !strong.some((s) => s.id === t.id)).map((t) => ({ transformation: t.id, evidence: t.evidence }));
  const neighbors = neighbours(input.transformations, options.examples, 3);
  return {
    ok: true,
    input: { transformations: input.transformations, structure: input.structure },
    plan,
    readers,
    result: { ok: r.ok, level: r.confidence ? r.confidence.level : null, score: r.confidence ? r.confidence.score : null, applied, skipped, bytes: output.length, output: r.ok ? output : null, error: r.ok ? null : (r.error || (r.warnings && r.warnings[0]) || 'the recovery did not produce a parsable program') },
    after: after.transformations,
    explanation,
    introduced,
    neighbors,
    summary: {
      transformations: strong.length,
      resolved: explanation.filter((e) => e.status === 'resolved').length,
      reduced: explanation.filter((e) => e.status === 'reduced').length,
      unresolved: explanation.filter((e) => e.status === 'unresolved').length,
    },
    ms: Date.now() - t0,
  };
}
