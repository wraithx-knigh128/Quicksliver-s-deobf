// Run the reconstruction service on every fixture and write what happened to data/research/luraph-compat.json.
//
//   node tools/luraph/verify.mjs [--only id,id]
//
// The registry is evidence, not opinion: for each run it records the fixture's SHA-256, the engine that was asked and the engine that answered, what kind of
// output came out (lifted, trace-assisted, trace), the syntax check, the quality counts, and the behaviour comparison with the original when there is one. Statuses
// are NOT stored here: src/reconstruct/status.js derives them from these records, so editing a status by hand is not possible without editing a record.
// Runs are repeated three times; a result that differs between runs is recorded as unstable.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { engineStatus, versionStatus } from '../../src/reconstruct/status.js';
import { VERSIONS, ENGINES } from '../../src/reconstruct/engines.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const sha = (buf) => crypto.createHash('sha256').update(buf).digest('hex');
const engineDir = path.join(root, 'api', '_engine', 'luraph');

function engineRevision() {
  const h = crypto.createHash('sha256');
  const walk = (d) => { for (const e of fs.readdirSync(d, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) { const p = path.join(d, e.name); if (e.isDirectory()) { if (e.name !== 'fixtures' && e.name !== 'bin' && e.name !== '__pycache__') walk(p); } else if (/\.(py|luau)$/.test(e.name)) { h.update(path.relative(engineDir, p)); h.update(fs.readFileSync(p)); } } };
  walk(engineDir);
  return h.digest('hex').slice(0, 16);
}

export function runService(file, { engine = 'auto', original = null, fallback = true } = {}) {
  const args = ['-I', path.join(engineDir, 'service.py'), file, engine];
  if (original) args.push('--original', original);
  if (!fallback) args.push('--no-fallback');
  const r = spawnSync('python3', args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, timeout: 300_000 });
  if (r.status !== 0) throw new Error(`service failed: ${(r.stderr || '').slice(-400)}`);
  return JSON.parse(r.stdout);
}

export function recordFor(fx, result, runs) {
  const used = result.engine && result.engine.used;
  return {
    id: fx.id, sha256: result.identification ? result.identification.sha256 : null, claimed: fx.claimed, versionRow: fx.versionRow, requested: fx.engine, engine: fx.engine,
    answeredBy: used || null, mode: result.engine ? result.engine.mode : null, ok: !!result.ok, kind: result.kind,
    attempts: ((result.engine && result.engine.attempts) || []).map((a) => ({ engine: a.engine, mode: a.mode, outcome: a.outcome, seconds: a.seconds })),
    quality: result.quality ? { lines: result.quality.lines, functions: result.quality.functions, grade: result.quality.grade, unresolved: result.quality.unresolvedTotal } : null,
    syntax: result.checks && result.checks.syntax ? result.checks.syntax.ok : null,
    verification: { status: (result.verification && result.verification.status) || 'not-run', reason: result.verification && result.verification.reason },
    hasOriginal: !!fx.original, diagnostics: (result.diagnostics || []).map((d) => d.code), seconds: result.seconds, stable: runs.every((x) => x === runs[0]), outputSha256: result.output ? sha(result.output) : null,
    provenance: fx.provenance,
  };
}

function main() {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'tools', 'luraph', 'fixtures.json'), 'utf8'));
  const only = process.argv.includes('--only') ? process.argv[process.argv.indexOf('--only') + 1].split(',') : null;
  const luau = path.join(engineDir, 'deobf', 'bin', 'luau');
  const records = [];
  const skipped = [];
  for (const fx of manifest.fixtures) {
    if (only && !only.includes(fx.id)) continue;
    const file = path.join(root, fx.file);
    if (!fs.existsSync(file)) { skipped.push({ id: fx.id, reason: `${fx.file} is not present in this checkout` }); continue; }
    const original = fx.original ? path.join(root, fx.original) : null;
    const results = [];
    for (let i = 0; i < 3; i++) results.push(runService(file, { engine: fx.engine, original }));
    const sig = results.map((r) => `${r.kind}|${r.engine && r.engine.used}|${r.verification && r.verification.status}|${r.output ? sha(r.output) : ''}`);
    const rec = recordFor(fx, results[0], sig);
    records.push(rec);
    console.log(`${fx.id.padEnd(28)} ${String(rec.kind).padEnd(15)} by ${String(rec.answeredBy).padEnd(13)} verification ${rec.verification.status}${rec.stable ? '' : '  (UNSTABLE across 3 runs)'}`);
  }
  const registry = {
    schema: 1, generatedAt: new Date().toISOString(),
    host: { luauSha256: fs.existsSync(luau) ? sha(fs.readFileSync(luau)) : null, luauNote: 'Luau 0.739 built with the one-line vector-metatable patch of build_luau.py, static, portable (see api/_engine/luraph/NOTICE.md)', engineRevision: engineRevision() },
    records, skipped,
  };
  registry.summary = {
    engines: Object.fromEntries(Object.keys(ENGINES).filter((e) => e !== 'generic').map((e) => [e, engineStatus(records.filter((r) => r.engine === e), { hasEngine: true })])),
    versions: Object.fromEntries(VERSIONS.map((v) => [v.id, versionStatus(v, registry)])),
  };
  if (!only) fs.writeFileSync(path.join(root, 'data', 'research', 'luraph-compat.json'), JSON.stringify(registry, null, 1) + '\n');
  for (const [id, s] of Object.entries(registry.summary.versions)) console.log(`  ${id.padEnd(18)} ${s.status.padEnd(17)} ${s.reasons.join('; ')}`);
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
