#!/usr/bin/env node
// Prompt XXVII: how often does a rebuilt program carry generic names where the original had a meaningful one?
//
// For every fixture in tests/corpus/obfuscated/<tool>/ whose original is in tests/corpus/originals/, the pipeline runs and the output's
// locals and parameters are classed:
//   generic    names the rebuilder invented with no evidence: _r0_3, a1, up2, value, param, L_12, p1, v7 ...
//   evidence   any other name (from the program's own expressions, a debug name, or a name the obfuscator kept)
// and the original's "anchored" names are checked: a local whose initialiser is a GetService call, a constant field read (x.LocalPlayer),
// Instance.new or WaitForChild has a name the program itself states; the share of those that come back is `anchoredRecovered`.
//
//   node tools/audit/names.mjs [--filter text] [--vm-only] [--out file.json]

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { recoverSource } from '../../src/api.js';
import { parse } from '../../src/core/parser.js';
import { analyze } from '../../src/core/scope.js';

const repo = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const args = process.argv.slice(2);
const opt = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };

export const GENERIC = /^(?:_r\d+(?:_\d+)*(?:_c\d+)?|a\d+|up\d+|value\d*|param\d*|L_?\d+_?|p\d+|v\d+|var\d+|arg\d+|tbl\d*|fn\d*|obj\d*|num\d*|str\d*|flag\d*|unk\d*|_\d+)$/;

/** Locals and parameters of a parsed chunk, with how each is declared. */
export function declaredNames(ast) {
  const info = analyze(ast);
  return info.vars.filter((v) => !v.isGlobal && v.name !== 'self' && v.name !== '_' && v.name !== '...');
}

/** The names the original program states through its own expressions (see header). */
export function anchoredNames(src) {
  const out = new Set();
  const re = /local\s+([A-Za-z_]\w*)\s*=\s*(?:game:GetService\(\s*"(\w+)"\s*\)|[A-Za-z_][\w.]*\.(\w+)\s*$|Instance\.new\(|[\w.]+:WaitForChild\()/gm;
  let m;
  while ((m = re.exec(src))) out.add(m[1]);
  return out;
}

export function measure(output) {
  let ast;
  try { ast = parse(output); } catch { return null; }
  const vars = declaredNames(ast);
  const generic = vars.filter((v) => GENERIC.test(v.name));
  const params = vars.filter((v) => v.kind === 'param');
  return {
    locals: vars.length, generic: generic.length, params: params.length, genericParams: params.filter((v) => GENERIC.test(v.name)).length,
    names: new Set(vars.map((v) => v.name)),
  };
}

async function main() {
  const filter = opt('--filter', '');
  const vmOnly = args.includes('--vm-only');
  const root = path.join(repo, 'tests', 'corpus', 'obfuscated');
  const originals = path.join(repo, 'tests', 'corpus', 'originals');
  const rows = [];
  for (const tool of fs.readdirSync(root).sort()) {
    const dir = path.join(root, tool);
    if (!fs.statSync(dir).isDirectory()) continue;
    for (const f of fs.readdirSync(dir).sort()) {
      if (!f.endsWith('.lua')) continue;
      const id = `${tool}/${f}`;
      if (filter && !id.includes(filter)) continue;
      const sample = f.split('__')[0];
      const origPath = path.join(originals, `${sample}.lua`);
      if (!fs.existsSync(origPath)) continue;
      const input = fs.readFileSync(path.join(dir, f), 'utf8');
      let r;
      const t0 = Date.now();
      try { r = recoverSource(input, { sandbox: { enabled: true } }); } catch (e) { rows.push({ id, crash: String(e.message || e).slice(0, 200) }); continue; }
      const vmLifted = !!(r.vm && r.vm.lifted);
      if (vmOnly && !vmLifted) continue;
      const m = r.output ? measure(r.output) : null;
      const anchors = anchoredNames(fs.readFileSync(origPath, 'utf8'));
      const back = m ? [...anchors].filter((n) => m.names.has(n)) : [];
      rows.push({ id, vmLifted, ms: Date.now() - t0, outcome: r.outcome && r.outcome.outcome, locals: m && m.locals, generic: m && m.generic, params: m && m.params, genericParams: m && m.genericParams, anchors: anchors.size, anchoredRecovered: back.length, missing: m ? [...anchors].filter((n) => !m.names.has(n)) : [...anchors] });
      process.stderr.write('.');
    }
  }
  process.stderr.write('\n');
  const sum = (k, list) => list.reduce((a, r) => a + (r[k] || 0), 0);
  const groups = {};
  for (const r of rows) { const k = r.vmLifted ? 'vmLifted' : 'other'; (groups[k] ||= []).push(r); }
  const totals = Object.fromEntries(Object.entries(groups).map(([k, list]) => [k, {
    files: list.length, locals: sum('locals', list), generic: sum('generic', list), genericShare: Math.round(1000 * sum('generic', list) / Math.max(1, sum('locals', list))) / 10,
    params: sum('params', list), genericParams: sum('genericParams', list), anchors: sum('anchors', list), anchoredRecovered: sum('anchoredRecovered', list),
  }]));
  const doc = { generated: new Date().toISOString(), totals, rows };
  const out = opt('--out', null);
  if (out) fs.writeFileSync(out, JSON.stringify(doc, null, 1) + '\n');
  console.log(JSON.stringify(totals, null, 1));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();
