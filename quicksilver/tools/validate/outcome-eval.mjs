// How accurate is the outcome classification (src/validate/outcome.js) on every real-tool fixture, and does it ever report a false success?
//
//   QS_LUA_PYTHON=/path/to/python-with-lupa node tools/validate/outcome-eval.mjs [--filter text] [--write]
//
// For each fixture: recover (sandbox on) → classify → behaviour comparison of the output with the submitted (obfuscated) program on a real
// Lua runtime → classify again. Independently of the classifier, the output is also run next to the authorised ORIGINAL program, which
// the classifier never sees. A "validated" result whose output does not behave like the original — where the original is a valid reference,
// i.e. the obfuscator itself preserved the original's behaviour — is a false success. Outputs that print memory addresses are compared with
// the addresses masked.
//
// Writes data/research/outcome-eval.json and prints the confusion table.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../../src/core/bytes.js';
import { recoverSource, outcomeWithBehaviour } from '../../src/api.js';
import * as oracle from '../../tests/helpers/lua-oracle.mjs';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const corpus = path.join(root, 'tests', 'corpus');
const args = process.argv.slice(2);
const filter = args.includes('--filter') ? args[args.indexOf('--filter') + 1] : '';
if (!oracle.available) { console.error('QS_LUA_PYTHON is not set: the behaviour comparison needs the real-Lua oracle.'); process.exit(2); }

const dirs = [];
for (const base of ['obfuscated', 'obfuscated-local']) {
  const b = path.join(corpus, base);
  if (!fs.existsSync(b)) continue;
  for (const d of fs.readdirSync(b).sort()) if (fs.existsSync(path.join(b, d, 'manifest.json'))) dirs.push(`${base}/${d}`);
}
const read = (p) => bytesToBinary(fs.readFileSync(p));
const mask = (s) => String(s || '').replace(/\b(table|function|userdata|thread): (0x)?[0-9a-fA-F]+/g, '$1: <addr>');

async function run(code, rt) {
  const r = await oracle.runLua(code, rt);
  return { ok: r.ok, out: mask(r.stdout), error: r.error };
}

const rows = [];
for (const dir of dirs) {
  const manifest = JSON.parse(fs.readFileSync(path.join(corpus, dir, 'manifest.json'), 'utf8'));
  for (const e of manifest.entries || []) {
    if (e.status !== 'ok' || !e.sample || !`${dir}/${e.file}`.includes(filter)) continue;
    const origPath = path.join(corpus, 'originals', e.sample);
    if (!fs.existsSync(origPath) || !fs.existsSync(path.join(corpus, dir, e.file))) continue;
    const input = read(path.join(corpus, dir, e.file));
    const row = { fixture: `${dir}/${e.file}`, toolBehavior: e.behavior || null };
    let r;
    try { r = recoverSource(input, { sandbox: { enabled: true } }); } catch (err) { row.crash = String(err.message || err); rows.push(row); continue; }
    row.level = r.confidence ? r.confidence.level : null;
    row.before = r.outcome.outcome;
    const rt = Object.entries(e.behaviors || {}).find(([, v]) => v !== 'errored')?.[0] || 'lua51';
    row.runtime = rt;
    let behaviour = null;
    if (r.output != null && r.outcome.evidence.recovery && r.outcome.evidence.recovery.parses) {
      const [a, b] = [await run(input, rt), await run(r.output, rt)];
      // the reference must have run and done something observable; otherwise the comparison cannot settle it
      behaviour = !a.ok || !a.out.trim() ? { verdict: 'inconclusive', against: 'input', note: !a.ok ? 'the submitted program itself fails on this runtime' : 'the submitted program printed nothing' }
        : !b.ok ? { verdict: 'different', against: 'input', note: `the output fails: ${String(b.error).slice(0, 80)}` }
        : { verdict: a.out === b.out ? 'identical' : 'different', against: 'input' };
      // independent truth: the original, which the classifier never sees
      const o = await run(read(origPath), rt);
      row.truth = !o.ok || e.behavior !== 'equivalent' ? 'no-valid-reference' : b.ok && b.out === o.out ? 'matches-original' : 'differs-from-original';
    }
    row.behaviour = behaviour && behaviour.verdict;
    const after = behaviour ? outcomeWithBehaviour('', { evidence: r.outcome.evidence, behaviour }) : r.outcome;
    row.outcome = after.outcome;
    row.falseSuccess = after.outcome === 'validated' && row.truth === 'differs-from-original';
    rows.push(row);
    if (rows.length % 50 === 0) process.stderr.write(`${rows.length}…\n`);
  }
}
oracle.stopOracle?.();

const by = (k) => rows.reduce((m, r) => { m[r[k]] = (m[r[k]] || 0) + 1; return m; }, {});
const validated = rows.filter((r) => r.outcome === 'validated');
const summary = {
  fixtures: rows.length,
  crashes: rows.filter((r) => r.crash).length,
  outcomesBeforeBehaviour: by('before'),
  outcomes: by('outcome'),
  validated: validated.length,
  validatedCheckedAgainstOriginal: validated.filter((r) => r.truth !== 'no-valid-reference').length,
  falseSuccesses: rows.filter((r) => r.falseSuccess).length,
  highConfidenceNotValidated: rows.filter((r) => r.level === 'high' && r.outcome !== 'validated').length,
};
console.log(JSON.stringify(summary, null, 1));
for (const r of rows.filter((x) => x.falseSuccess)) console.log('FALSE SUCCESS', r.fixture);
if (args.includes('--write')) {
  fs.writeFileSync(path.join(root, 'data', 'research', 'outcome-eval.json'), JSON.stringify({ generatedAt: new Date().toISOString(), method: 'tools/validate/outcome-eval.mjs', summary, rows }, null, 1));
  console.log('wrote data/research/outcome-eval.json');
}
