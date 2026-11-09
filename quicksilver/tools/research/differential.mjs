// Differential testing: for each (original, protected) pair, does the reconstruction of the protected file behave like the original?
//
// "Behave" is decided by running both on a reference runtime (tools/runtime/oracle.mjs) and comparing what they print. Static facts about the
// reconstruction (does it parse, how close is it to the original's text) are reported next to that, in a separate field, and never decide the
// verdict. Without a reference runtime the verdict is `no-reference-runtime`: QuickSilver's own interpreter is shown, but it cannot make a pair "verified".
//
//   node tools/research/differential.mjs <package.json> [--out data/research/differential/<name>.json]
//
// A verdict per pair:
//   runtime-identical     original and reconstruction printed the same thing, and ended the same way, on every reference runtime asked
//   runtime-different     they differed on some runtime (a defect, or the reconstruction is wrong)
//   inconclusive          the original printed nothing, failed, or hit a limit: nothing can be compared
//   recovery-failed       the engine produced no reconstruction
//   no-reference-runtime  no reference runtime is installed

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import crypto from 'node:crypto';
import { recoverSource } from '../../src/api.js';
import { compareBehaviour, observeBehaviour, referenceRuntimes } from '../lab/behaviour.mjs';
import { observe, opacity } from '../../src/research/signature.js';
import { fidelity } from '../../src/core/fidelity.js';
import { stopOracle } from '../runtime/oracle.mjs';
import { validatePackage } from '../../src/research/samples.js';
import { wilson } from '../../src/research/judge.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const sha = (s) => crypto.createHash('sha256').update(s, 'latin1').digest('hex');

/**
 * @param {{pairs: Array<{id: string, original: string, protected: string}>}} pkg
 * @param {{runtimes?: string[], recover?: (src: string) => ({ok: boolean, output?: string})}} [opts]
 */
export async function differential(pkg, opts = {}) {
  const runtimes = opts.runtimes || (await referenceRuntimes());
  const recover = opts.recover || ((src) => recoverSource(src, { nexus: true }));
  const rows = [];
  for (const p of pkg.pairs) {
    const row = { id: p.id, originalSha256: sha(p.original), protectedSha256: sha(p.protected), static: {}, runtime: {} };
    let rec;
    try { rec = recover(p.protected); } catch (e) { rec = { ok: false, error: String(e.message || e) }; }
    if (!rec || !rec.ok || typeof rec.output !== 'string') { rows.push({ ...row, verdict: 'recovery-failed', note: (rec && rec.error && (rec.error.message || rec.error)) || 'no output' }); continue; }
    row.reconstructionSha256 = sha(rec.output);
    // static facts, kept apart from the verdict
    try {
      row.static = {
        parses: true,
        fidelityBefore: round(fidelity(p.original, p.protected).score), fidelityAfter: round(fidelity(p.original, rec.output).score),
        opacityBefore: opacity(observe(p.protected).tokens), opacityAfter: opacity(observe(rec.output).tokens),
      };
    } catch (e) { row.static = { parses: false, error: String(e.message || e) }; }
    // a pair may name the runtimes its original is known to run on (a tool that targets Lua 5.2 or LuaJIT is not asked to run on 5.1)
    const rts = p.runtimes && p.runtimes.length ? p.runtimes : runtimes;
    if (!rts.length) { rows.push({ ...row, verdict: 'no-reference-runtime', note: 'No reference runtime is installed (tools/runtime/setup.sh).' }); continue; }
    const orig = await observeBehaviour(p.original, rts);
    const got = await observeBehaviour(rec.output, rts);
    const cmp = compareBehaviour(orig, got);
    row.runtime = { runtimes: rts, source: cmp.source, per: cmp.per, disagreementWithSandbox: cmp.disagreement, difference: cmp.difference };
    rows.push({ ...row, verdict: cmp.verdict === 'identical' ? 'runtime-identical' : cmp.verdict === 'different' ? 'runtime-different' : 'inconclusive' });
  }
  const n = rows.filter((r) => r.verdict === 'runtime-identical' || r.verdict === 'runtime-different').length;
  const ok = rows.filter((r) => r.verdict === 'runtime-identical').length;
  const w = wilson(ok, n);
  return {
    runtimes,
    results: { pairs: rows.length, runtimeVerified: n, runtimeSuccess: ok, runtimeDifferent: n - ok, inconclusive: rows.filter((r) => r.verdict === 'inconclusive').length, recoveryFailed: rows.filter((r) => r.verdict === 'recovery-failed').length, noReference: rows.filter((r) => r.verdict === 'no-reference-runtime').length, interval: [round(w.lo), round(w.hi)] },
    rows,
  };
}
const round = (x) => (typeof x === 'number' ? Math.round(x * 1000) / 1000 : x);

async function main() {
  const file = process.argv[2];
  if (!file) { console.error('usage: node tools/research/differential.mjs <package.json> [--out file]'); process.exit(2); }
  const pkg = JSON.parse(fs.readFileSync(file, 'utf8'));
  const v = await validatePackage(pkg);
  if (!v.ok) { console.error('package refused:\n  ' + v.problems.join('\n  ')); process.exit(1); }
  const out = await differential(pkg);
  const i = process.argv.indexOf('--out');
  const target = i > 0 ? process.argv[i + 1] : path.join(here, '..', '..', 'data', 'research', 'differential', `${pkg.system}-${pkg.claimedVersion || 'unversioned'}.json`.replace(/[^a-z0-9._-]/gi, '_'));
  fs.mkdirSync(path.dirname(target), { recursive: true });
  // the record keeps hashes and verdicts, not the supplier's files
  fs.writeFileSync(target, JSON.stringify({ schema: 1, system: pkg.system, claimedVersion: pkg.claimedVersion, supplier: pkg.supplier, attestation: pkg.attestation, at: new Date().toISOString(), ...out }, null, 2) + '\n');
  console.log(JSON.stringify(out.results), '->', path.relative(process.cwd(), target));
  await stopOracle();
}
if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) main();
