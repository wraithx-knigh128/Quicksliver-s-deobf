// The Prompt XX evidence collection: one authorised sample per situation, each measured the same way.
//
//   detection        is the obfuscator named correctly — and for an unfamiliar format, is NO wrong tool claimed?
//   stages           the anatomy's hypotheses and how many survived their test; the pipeline steps that applied
//   completeness     the transformations the custom analysis found, and how many are resolved after recovery
//   syntax           does the output parse?
//   behaviour        on the reference Lua: output vs the original, where an original exists (and vs the obfuscated file)
//   confidence       the pipeline's own level
//   limitations      what is left unresolved, from the explanation
//
// A readable output is never counted as success on its own: behaviour is only claimed where it was run and compared.
//   QS_LUA_PYTHON=… node tools/custom/collection.mjs [--write]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { analyzeCustom } from '../../src/custom/analyze.js';
import { detect } from '../../src/detect/detect.js';
import { parse } from '../../src/core/parser.js';
import { analyzeLuarmor } from '../../src/loader/luarmor.js';
import { analyzeLoader } from '../../src/loader/analyze.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const write = process.argv.includes('--write');
const oracle = process.env.QS_LUA_PYTHON ? await import('../../tests/helpers/lua-oracle.mjs') : null;
const rules = JSON.parse(fs.readFileSync(path.join(root, 'data', 'research', 'learned-rules.json'), 'utf8'));
const C = (p) => path.join(root, 'tests', 'corpus', p);
const L = (p) => path.join(root, 'local', 'corpus', p);
const orig = (s) => C(`originals/${s}.lua`);

// [category, label, file, expected family id (null: no tool should be claimed), original]
const SAMPLES = [
  ['previously supported', 'IronBrew 2 (default)', C('obfuscated/ironbrew2/s01_minify_basic__default.lua'), 'ironbrew2', orig('s01_minify_basic')],
  ['previously supported', 'Prometheus Weak', C('obfuscated/prometheus/s06_combined__Weak.lua'), 'prometheus', orig('s06_combined')],
  ['previously supported', 'Hercules balanced', C('obfuscated/hercules/s02_renamed_vars__balanced.lua'), 'hercules', orig('s02_renamed_vars')],
  ['VM-based', 'Zartha (default)', C('obfuscated/zartha/s01_minify_basic__default.lua'), 'zartha', orig('s01_minify_basic')],
  ['VM-based', 'Obscura 1.1.0 VM', C('obfuscated/obscura-1.1.0/s01_minify_basic__vm.lua'), 'obscura', orig('s01_minify_basic')],
  ['VM-based', 'Clyde VM', C('obfuscated/clyde/s01_minify_basic__vm.lua'), 'clyde', orig('s01_minify_basic')],
  ['unknown custom (no signature)', 'project packer: base64 + loadstring', C('obfuscated/loaders/s01_minify_basic__base64.lua'), null, orig('s01_minify_basic')],
  ['unknown custom (no signature)', 'project packer: character codes', C('obfuscated/loaders/s01_minify_basic__charcodes.lua'), null, orig('s01_minify_basic')],
  ['unknown custom (no signature)', 'project packer: layered', C('obfuscated/loaders/s01_minify_basic__layered.lua'), null, orig('s01_minify_basic')],
  ['multi-layer', 'Hercules VM + base64 + Hercules light', C('obfuscated/mixed/s01_minify_basic__base64+hercules-vm+hercules-light.lua'), 'hercules', orig('s01_minify_basic')],
  ['multi-layer', 'Hercules balanced + XOR', C('obfuscated/mixed/s01_minify_basic__hercules-balanced+xor.lua'), 'hercules', orig('s01_minify_basic')],
  ['unsupported / partial', 'ZenFus VM', C('obfuscated/zenfus/s01_minify_basic__default.lua'), 'zenfus', orig('s01_minify_basic')],
  ['unsupported / partial', 'AzureVM AzureGodUltra', C('obfuscated/azurevm/s01_minify_basic__AzureGodUltra.lua'), 'azurevm', orig('s01_minify_basic')],
  ['unknown custom (real, no original)', 'third-party VM script', L('Unknown/0030800e284c9cb8.lua'), null, null],
  ['unknown custom (real, no original)', 'third-party VM script', L('Unknown/0444eb6189c02bee.lua'), null, null],
];
const LOADERS = [
  ['loader with remote reference', 'Luarmor bootstrap (real)', L('Unknown/00aded388ac6544c.lua')],
  ['loader with remote reference', 'Luarmor SDK loader (user-supplied)', C('user-local/MainLoader.lua')],
  ['locally encoded loader', 'project packer: hex', C('obfuscated/loaders/s01_minify_basic__hex.lua')],
];
const MALFORMED = [
  ['incomplete / malformed', 'IronBrew 2 file cut at 60%', () => fs.readFileSync(C('obfuscated/ironbrew2/s01_minify_basic__default.lua'), 'latin1').slice(0, 10000)],
  ['incomplete / malformed', 'loader with a syntax error', () => 'loadstring(game:HttpGet("https://raw.githubusercontent.com/a/b/main/x.lua")\n'],
];

const rows = [];
// the runtime a tool targets: the first on which both the original and the obfuscated program run (the scorecard does the same per tool)
const RUNTIMES = ['lua51', 'lua52', 'lua54', 'lua51b', 'luajit'];
async function behaviour(original, output, obfuscated) {
  if (!oracle || !original || output == null) return { vsOriginal: null, vsObfuscated: null };
  const origSrc = fs.readFileSync(original, 'latin1');
  let rt = RUNTIMES[0];
  for (const r of RUNTIMES) {
    const [o, x] = await Promise.all([oracle.runLua(origSrc, r), oracle.runLua(obfuscated, r)]);
    if (o.ok && x.ok) { rt = r; break; }
  }
  const [o, b, x] = await Promise.all([oracle.runLua(origSrc, rt), oracle.runLua(output, rt), oracle.runLua(obfuscated, rt)]);
  const cmp = (a, c) => (!a.ok ? 'reference does not run' : !c.ok ? 'output errors' : a.stdout === c.stdout ? 'same' : 'different');
  return { runtime: rt, vsOriginal: cmp(o, b), vsObfuscated: cmp(x, b) };
}

for (const [category, label, file, expected, original] of SAMPLES) {
  if (!fs.existsSync(file)) { rows.push({ category, label, skipped: 'sample not present (local corpus)' }); continue; }
  const src = fs.readFileSync(file, 'latin1');
  const det = detect(src);
  const claimed = det.families.filter((f) => f.confidence >= 0.5).map((f) => f.id);
  const a = analyzeCustom(src, { sandbox: { enabled: true }, rules });
  // a tool hidden under an outer layer is identified when the pipeline step that removes it ran (e.g. `hercules.vm` after the XOR layer came off)
  const peeled = expected && a.ok && (a.result.applied.some((x) => x.id.split('.')[0] === expected) || (a.identifiedAfterPeeling || []).includes(expected));
  const detection = expected ? (claimed.includes(expected) ? 'correct' : peeled ? 'correct after peeling (an outer layer hid it)' : claimed.length ? `wrong (${claimed.join(', ')})` : 'missed') : (claimed.length ? `false claim (${claimed.join(', ')})` : 'correct (no tool claimed)');
  const out = a.ok && a.result.ok ? a.result.output : null;
  let parses = false;
  if (out != null) { try { parse(out); parses = true; } catch { parses = false; } }
  const hyp = a.anatomy && a.anatomy.ok ? a.anatomy.hypotheses : [];
  const b = await behaviour(original, out, src);
  rows.push({
    category, label, file: path.relative(root, file), detection, claimed,
    architecture: a.anatomy && a.anatomy.ok ? a.anatomy.summary.architecture : null,
    stages: { hypotheses: hyp.length, confirmed: hyp.filter((h) => h.test.status === 'confirmed').length, refuted: hyp.filter((h) => h.test.status === 'refuted').length, inconclusive: hyp.filter((h) => h.test.status === 'inconclusive').length, learned: hyp.filter((h) => h.evidence.some((e) => /learned rule/.test(e))).length, applied: a.ok ? a.result.applied.map((x) => x.id) : [] },
    completeness: a.ok ? { transformations: a.summary.transformations, resolved: a.summary.resolved, reduced: a.summary.reduced, unresolved: a.summary.unresolved } : null,
    syntax: out == null ? 'no output' : parses ? 'parses' : 'does not parse',
    behaviour: original ? b : { vsOriginal: 'no original available', vsObfuscated: null },
    confidence: a.ok ? a.result.level : null,
    limitations: a.ok ? a.explanation.filter((e) => e.status !== 'resolved').map((e) => `${e.transformation}: ${e.notes[0] || ''}`.slice(0, 180)) : [a.error || 'analysis failed'],
  });
}
for (const [category, label, file] of LOADERS) {
  if (!fs.existsSync(file)) { rows.push({ category, label, skipped: 'sample not present (local corpus)' }); continue; }
  const src = fs.readFileSync(file, 'latin1');
  const la = analyzeLoader(src);
  const lu = analyzeLuarmor(src);
  rows.push({
    category, label, file: path.relative(root, file), loader: { case: la.case ? `${la.case.n}: ${la.case.label}` : null, architectures: (la.architectures || []).map((x) => x.id), requests: (la.requests || []).length },
    luarmor: lu ? { variants: lu.variants, operations: lu.operations.map((o) => `${o.n}:${o.status}`), localRecoverable: lu.local.recoverable, opaqueData: lu.data.length } : null,
    syntax: la.parsed === false ? 'does not parse' : 'parses',
    limitations: lu ? lu.remote.map((x) => `${x.role}: not in the file`) : (la.requests || []).filter((r) => !r.retrieval.possible).map((r) => `${r.template}: ${r.retrieval.route}`),
  });
}
for (const [category, label, get] of MALFORMED) {
  const src = get();
  const a = analyzeCustom(src, { sandbox: { enabled: true }, rules });
  rows.push({ category, label, detection: '—', syntax: a.ok ? (a.result.ok ? 'parses' : 'no output') : 'input does not parse', confidence: a.ok ? a.result.level : null, limitations: [a.ok ? (a.result.error || 'output produced') : `reported, not crashed: ${(a.error && a.error.message) || a.stage}`] });
}
if (oracle) oracle.stopOracle();

const measured = rows.filter((r) => !r.skipped && r.detection && r.detection !== '—');
const summary = {
  samples: rows.length,
  skipped: rows.filter((r) => r.skipped).length,
  detectionCorrect: measured.filter((r) => /^correct/.test(r.detection)).length,
  detectionMeasured: measured.length,
  falseClaims: measured.filter((r) => /false claim|wrong/.test(r.detection)).length,
  parses: rows.filter((r) => r.syntax === 'parses').length,
  behaviourSameAsOriginal: rows.filter((r) => r.behaviour && r.behaviour.vsOriginal === 'same').length,
  behaviourChecked: rows.filter((r) => r.behaviour && ['same', 'different', 'output errors'].includes(r.behaviour.vsOriginal)).length,
  hypothesesConfirmed: rows.reduce((a, r) => a + (r.stages ? r.stages.confirmed : 0), 0),
  hypothesesRefuted: rows.reduce((a, r) => a + (r.stages ? r.stages.refuted : 0), 0),
};
const cell = (x) => String(x ?? '—').replace(/\|/g, '/');
const md = ['# Evidence collection (Prompt XX)', '', 'Generated by `node tools/custom/collection.mjs --write` with the reference Lua oracle. Every sample is measured the same way; behaviour is claimed only where the output was run and compared with the original (and with the obfuscated file, which shows where the obfuscator itself changed the program). A readable output is not counted as success.', '',
  '| Measure | Value |', '|---|---|',
  `| samples (skipped: local-only, absent) | ${summary.samples} (${summary.skipped}) |`,
  `| detection correct / measured | ${summary.detectionCorrect} / ${summary.detectionMeasured} |`,
  `| false or wrong tool claims | ${summary.falseClaims} |`,
  `| outputs that parse | ${summary.parses} |`,
  `| behaviour = original / checked | ${summary.behaviourSameAsOriginal} / ${summary.behaviourChecked} |`,
  `| hypotheses confirmed / refuted by their tests | ${summary.hypothesesConfirmed} / ${summary.hypothesesRefuted} |`, '',
  '| Category | Sample | Detection | Architecture | Hypotheses (confirmed/refuted/inconclusive) | Completeness (resolved/found) | Syntax | Behaviour vs original (vs obfuscated) | Confidence | Remaining |', '|---|---|---|---|---|---|---|---|---|---|',
  ...rows.map((r) => r.skipped ? `| ${cell(r.category)} | ${cell(r.label)} | — | — | — | — | — | — | — | ${cell(r.skipped)} |`
    : r.loader || r.luarmor ? `| ${cell(r.category)} | ${cell(r.label)} | — | loader: case ${cell(r.loader.case)} | ${r.luarmor ? cell(`Luarmor ${r.luarmor.variants.join('+')}; operations ${r.luarmor.operations.join(' ')}`) : cell(r.loader.architectures.join(', '))} | ${r.luarmor ? cell(`local logic: ${r.luarmor.localRecoverable}; opaque data tables: ${r.luarmor.opaqueData}`) : '—'} | ${cell(r.syntax)} | — | — | ${cell(r.limitations.join('; ') || 'none')} |`
    : `| ${cell(r.category)} | ${cell(r.label)} | ${cell(r.detection)} | ${cell(r.architecture)} | ${r.stages ? `${r.stages.confirmed}/${r.stages.refuted}/${r.stages.inconclusive} of ${r.stages.hypotheses}${r.stages.learned ? ` (${r.stages.learned} via learned rules)` : ''}` : '—'} | ${r.completeness ? `${r.completeness.resolved}/${r.completeness.transformations}` : '—'} | ${cell(r.syntax)} | ${r.behaviour ? `${cell(r.behaviour.vsOriginal)}${r.behaviour.vsObfuscated ? ` (${cell(r.behaviour.vsObfuscated)})` : ''}${r.behaviour.runtime ? ` [${r.behaviour.runtime}]` : ''}` : '—'} | ${cell(r.confidence)} | ${cell((r.limitations || []).join('; ') || 'none')} |`), ''].join('\n');
if (write) {
  fs.writeFileSync(path.join(root, 'docs', 'COLLECTION.md'), md);
  fs.writeFileSync(path.join(root, 'data', 'research', 'collection-results.json'), JSON.stringify({ summary, rows }, null, 1));
}
console.log(summary);
for (const r of rows) console.log(r.category.padEnd(34), (r.label || '').padEnd(40), r.skipped || r.detection || '', r.confidence || '', r.syntax || '', r.behaviour ? r.behaviour.vsOriginal : '');
