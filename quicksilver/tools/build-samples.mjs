// Copies a curated set of test scripts into data/samples/ for the interface's Samples menu.
//
//   node tools/build-samples.mjs
//
// The obfuscated files are the real output of Prometheus, Hercules, IronBrew 2 and Zenfus (tests/corpus/obfuscated), generated
// from the original programs in tests/corpus/originals; see the manifests there for seeds and revisions.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const corpus = path.join(root, 'tests/corpus');
const out = path.join(root, 'data/samples');
fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });

// what the offline scorecard measured for each fixture (tests/tools-scorecard.mjs --write); shown in the Examples tab
const scorecard = JSON.parse(fs.readFileSync(path.join(root, 'tests/results/scorecard.json'), 'utf8'));
const measuredFor = (tool, config, sample) => {
  const r = scorecard.results.find((x) => x.tool === tool && x.config === config && x.sample === sample.replace(/\.lua$/, ''));
  if (!r) return null;
  const same = r.behaviorOriginal === 'same';
  return {
    before: r.fidelityBefore ?? null, after: r.fidelityAfter ?? null, ms: r.ms ?? null,
    // 'same' / 'differs' / 'tool-broken' (the obfuscator's own output already misbehaves, so the comparison says nothing about recovery)
    behaviour: r.behaviorOriginal == null ? null : r.toolBehavior !== 'equivalent' ? 'tool-broken' : same ? 'same' : 'differs',
  };
};

const SAMPLE = 's06_combined';
const groups = [];
const copy = (src, name) => {
  const data = fs.readFileSync(src);
  fs.writeFileSync(path.join(out, name), data);
  return { bytes: data.length, sha256: crypto.createHash('sha256').update(data).digest('hex') };
};
const sizeLabel = (n) => (n < 1024 ? `${n} B` : `${(n / 1024).toFixed(1)} KiB`);

// 1. the originals
{
  const items = [];
  for (const [file, label, note] of [
    ['s06_combined.lua', 'Combined program', 'Original source: closures, string work, tables, control flow. Every obfuscated sample below was made from this file.'],
    ['s03_encoded_strings.lua', 'String handling', 'Original source, not obfuscated.'],
    ['s07_roblox_style.lua', 'Roblox-style script', 'Original source using game / Instance style calls (not run).'],
    ['s08_ironbrew_macros.lua', 'IronBrew 2 macros', 'Original source written for IronBrew 2: IB_MAX_CFLOW_* and IB_INLINING_START are no-ops here and are acted on by the tool.'],
  ]) {
    const name = `original__${file}`;
    const m = copy(path.join(corpus, 'originals', file), name);
    items.push({ file: name, label, sub: sizeLabel(m.bytes), note, bytes: m.bytes, sha256: m.sha256 });
  }
  groups.push({ label: 'Original programs (not obfuscated)', plain: true, items });
}

// 1b. readable scripts for the AI check (constructed for this project, see tests/corpus/origin/README.md)
{
  const items = [];
  for (const [file, label, note] of [
    ['assistant_inventory.lua', 'Written like an AI assistant', 'Constructed example imitating how a code assistant writes Luau: header comments, doc annotations, defensive checks. Press AI check.'],
    ['scrappy_autofarm.lua', 'Quick hand-written script', 'Constructed example imitating a quick hand-written script: short names, leftovers, debug prints. Press AI check.'],
    ['scrappy_esp.lua', 'Hand-written, with a library', 'Constructed example imitating a hand-written script that pulls in a public library. Press AI check.'],
    ['patchwork_credited.lua', 'Pieced together (credit lines)', 'Constructed example with a credit line, an invite link and two differently styled halves: the shape of a script assembled from other people\u2019s pieces. Press AI check.'],
  ]) {
    const name = `origin__${file}`;
    const m = copy(path.join(corpus, 'origin', file), name);
    items.push({ file: name, label, sub: sizeLabel(m.bytes), note, bytes: m.bytes, sha256: m.sha256 });
  }
  groups.push({ label: 'AI check examples (not obfuscated)', note: 'written for this project, not real authors', plain: true, items });
}

const tools = [
  {
    dir: 'prometheus', label: 'Prometheus (real tool output)', note: 'levno-710/Prometheus, seed 1337',
    picks: [['Minify', 'Minify preset'], ['step-EncryptStrings', 'EncryptStrings'], ['step-SplitStrings', 'SplitStrings'], ['step-NumbersToExpressions', 'NumbersToExpressions'], ['step-ConstantArray', 'ConstantArray'], ['step-ProxifyLocals', 'ProxifyLocals'], ['step-AntiTamper', 'AntiTamper'], ['step-Vmify', 'Vmify (flattened VM)'], ['Weak', 'Weak preset (Vmify + constants)'], ['Medium', 'Medium preset (strings + anti-tamper + Vmify)'], ['Strong', 'Strong preset (two Vmify layers)']],
  },
  {
    dir: 'hercules', label: 'Hercules (real tool output)', note: 'zeusssz/hercules-obfuscator',
    picks: [['light', 'light preset'], ['balanced', 'balanced preset'], ['mod-control_flow', 'control flow'], ['mod-string_encoding', 'string encoding'], ['mod-string_to_expressions', 'string to expressions'], ['mod-garbage_code', 'garbage code'], ['mod-opaque_predicates', 'opaque predicates'], ['mod-antitamper', 'anti-tamper'], ['mod-wrap_in_function', 'wrap in function'], ['mod-bytecode_encoding', 'bytecode encoding (compiled chunk; needs the sandbox)'], ['mod-virtual_machine', 'virtual machine (not recoverable)']],
  },
  {
    dir: 'ironbrew2', label: 'IronBrew 2 (real tool output)', note: 'Trollicus/ironbrew-2, built from source',
    picks: [['plain', 'VM only'], ['default', 'default settings'], ['mutate', 'opcode mutation'], ['super', 'super operators'], ['flow', 'control flow (the tool\'s output is broken)'], ['strings', 'string encryption'], ['lineinfo', 'with line info']],
    extra: [['s08_ironbrew_macros', 'default', 'IB_* macros, default settings']],
  },
  {
    // MIT licence, so the output can be shipped. Zenfus's own output misbehaves for six of the eight programs; the labels in the Examples tab say which.
    dir: 'zenfus', label: 'Zenfus (real tool output, VM; not recovered statically)', note: 'Zaenalos/Zenfus, MIT; run Trace to see what the script does',
    picks: [['default', 'default settings']],
    extra: [['s01_minify_basic', 'default', 'smallest program (behaves like its original)'], ['s03_encoded_strings', 'default', 'string program (behaves like its original)']],
  },
];
for (const t of tools) {
  const manifest = JSON.parse(fs.readFileSync(path.join(corpus, 'obfuscated', t.dir, 'manifest.json'), 'utf8'));
  const items = [];
  for (const [config, label] of t.picks) {
    const e = manifest.entries.find((x) => x.sample === `${SAMPLE}.lua` && x.config === config);
    if (!e || e.status !== 'ok') continue;
    const name = `${t.dir}__${SAMPLE}__${config.replace(/^(step|mod)-/, '')}.lua`;
    const m = copy(path.join(corpus, 'obfuscated', t.dir, e.file), name);
    items.push({
      file: name, label, sub: sizeLabel(m.bytes), bytes: m.bytes, sha256: m.sha256, measured: measuredFor(t.dir, config, e.sample),
      note: `Generated by ${manifest.tool} (${config}) from original__${SAMPLE}.lua. Its output ${e.behavior === 'equivalent' ? 'behaves like the original' : `does not match the original's behaviour (${e.behavior})`} on the reference Lua.`,
    });
  }
  for (const [sample, config, label] of t.extra || []) {
    const e = manifest.entries.find((x) => x.sample === `${sample}.lua` && x.config === config);
    if (!e || e.status !== 'ok') continue;
    const name = `${t.dir}__${sample}__${config}.lua`;
    const m = copy(path.join(corpus, 'obfuscated', t.dir, e.file), name);
    items.push({
      file: name, label, sub: sizeLabel(m.bytes), bytes: m.bytes, sha256: m.sha256, measured: measuredFor(t.dir, config, `${sample}.lua`),
      note: `Generated by ${manifest.tool} (${config}) from original__${sample}.lua. Its output ${e.behavior === 'equivalent' ? 'behaves like the original' : `does not match the original's behaviour (${e.behavior})`} on the reference Lua.`,
    });
  }
  groups.push({ label: t.label, note: t.note, items });
}

// loader-style packers written for this project (tests/corpus/tools/gen_loaders.mjs): not the output of any real tool
{
  const manifest = JSON.parse(fs.readFileSync(path.join(corpus, 'obfuscated/loaders/manifest.json'), 'utf8'));
  const labels = {
    reverse: 'Reversed text', escapes: 'Decimal escapes', charcodes: 'string.char(...)', pieces: 'Split pieces', ascii: 'ASCII codes', hex: 'Hexadecimal',
    binary: 'Binary groups', url: 'URL escapes', base64: 'Base64', xor: 'XOR cipher', layered: 'Two layers (base64 around hex)',
  };
  const items = [];
  for (const e of manifest.entries.filter((x) => x.sample === `${SAMPLE}.lua`)) {
    const name = `loaders__${SAMPLE}__${e.config}.lua`;
    const m = copy(path.join(corpus, 'obfuscated/loaders', e.file), name);
    items.push({
      file: name, label: labels[e.config] || e.config, sub: sizeLabel(m.bytes), bytes: m.bytes, sha256: m.sha256, measured: measuredFor('loaders', e.config, e.sample),
      note: `Written for this project (not the output of any real obfuscator): ${e.note}. ${e.needsSandbox ? 'The payload is computed by the script, so the sandbox has to be on to read it.' : 'The payload is known without running anything.'}`,
    });
  }
  groups.push({ label: 'Loadstring packers (written for this project)', note: 'not a real tool: generic encodings put in front of loadstring', items });
}

fs.writeFileSync(path.join(out, 'index.json'), `${JSON.stringify({ generated: new Date().toISOString(), groups }, null, 1)}\n`);
console.log(`data/samples: ${groups.reduce((n, g) => n + g.items.length, 0)} files`);
