// Prompt XXII — version identification for Luraph 15.x and LuaQ: a newer version never inherits what was established for an older one.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseBanner, versionFor, VERSIONS } from '../src/reconstruct/engines.js';
import { versionStatus } from '../src/reconstruct/status.js';
import { generationForVersion } from '../src/research/identify.js';
import { recoverSource } from '../src/api.js';
import { spawnSync } from 'node:child_process';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const banner = (v) => `-- This file was protected using Luraph Obfuscator v${v} [https://lura.ph/]`;

test('Luraph banners: 15.0 has the engine, 15.1 has its own row (nearest engine, experimental), 15.2 and later are version-uncertain', () => {
  for (const [v, id] of [['15.0', 'luraph-15.0'], ['15.0.3', 'luraph-15.0'], ['15', 'luraph-15.0'], ['15.1', 'luraph-15.1'], ['15.1.2', 'luraph-15.1'], ['15.2', 'luraph-15.2'], ['15.2.0', 'luraph-15.2'], ['15.10', 'luraph-15.2']]) {
    assert.equal(versionFor(parseBanner(banner(v))).id, id, v);
  }
  const v151 = VERSIONS.find((v) => v.id === 'luraph-15.1');
  assert.equal(v151.engine, null);
  assert.equal(v151.nearest, 'luraph_v15');
  assert.match(v151.note, /LPH_ASSUME and LPH_OPAQUE/);
  const v152 = VERSIONS.find((v) => v.id === 'luraph-15.2');
  assert.equal(v152.uncertain, true);
  assert.equal(versionStatus(v152, { records: [] }).status, 'version-uncertain');
  assert.match(versionStatus(v152, { records: [] }).reasons[0], /No source confirms/);
});

test('the registry on disk carries the split rows (15.1 unsupported with a nearest engine; 15.2 version-uncertain)', () => {
  const reg = JSON.parse(fs.readFileSync(path.join(root, 'data', 'research', 'luraph-compat.json'), 'utf8'));
  assert.equal(reg.summary.versions['luraph-15.1'].status, 'unsupported');
  assert.equal(reg.summary.versions['luraph-15.1'].nearest, 'luraph_v15');
  assert.equal(reg.summary.versions['luraph-15.2'].status, 'version-uncertain');
});

test('generations: v15.1 is profiled from the vendor SDK; v15.2 is not, so it inherits nothing from v15.1', () => {
  assert.equal(generationForVersion(15, 0), 'v15');
  assert.equal(generationForVersion(15, 1), 'v15.1');
  assert.equal(generationForVersion(15, 2), null);
  assert.equal(generationForVersion(15, 9), null);
});

const luaq = path.join(root, 'local', 'luaq', 'v2.7_sample.lua');
test('LuaQ v2.7: the outer layers decode, and the result is "payload unavailable" (the program is delivered by the service)', { skip: !fs.existsSync(luaq) && 'the LuaQ sample is kept locally only', timeout: 600_000 }, () => {
  const r = recoverSource(fs.readFileSync(luaq, 'latin1'), { sandbox: { enabled: true } });
  const st = r.steps.find((s) => s.id === 'luaq.layers');
  assert.equal(st.status, 'applied');
  assert.equal(st.detail.version, '2.7');
  assert.equal(st.detail.versionVerified, true);
  assert.equal(st.detail.programInFile, false);
  assert.equal(r.outcome.outcome, 'payload-unavailable');
  assert.match(r.outcome.reasons.join(' '), /delivered from outside the file/);
});

// L1 (Prompt XXII): each engine attempt was capped at 120 s, so a large v15 lift was cut off even when the job had 240 s; two of the eight
// local v15.0 scripts produced nothing until the attempt was given the job's remaining time.
const engineDir = path.join(root, 'api', '_engine', 'luraph');
const hasPython = spawnSync('python3', ['-V']).status === 0;
test('engine service: an attempt may use the job’s remaining time, less a reserve for a following step, and never more than is left', { skip: !hasPython && 'python3 is not available' }, () => {
  const r = spawnSync('python3', ['-I', '-c', `
import sys, json
sys.path.insert(0, ${JSON.stringify(engineDir)})
import service
print(json.dumps([service.attempt_budget(*a) for a in [(240, 0), (240, 30), (200, 30), (80, 30), (30, 0), (5, 0)]]))
`], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  const [full, reserved, mid, small, short, tiny] = JSON.parse(r.stdout);
  assert.equal(full, 240, 'the whole 240 s job (was 120)');
  assert.equal(reserved, 210, 'room is kept for the fallback step');
  assert.equal(mid, 170);
  assert.ok(small <= 80 && short <= 30 && tiny <= 5, 'never more than what is left');
});
