// Prompt XXVII Part V/VIII: the Luraph engine's server (api/reconstruct.py) enforces the Premium licence itself, with the same token and
// policy as the Node functions (api/_lib/entitlement.js). Tokens are signed here with a throw-away key; the Python side verifies them.

import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const hasCrypto = spawnSync('python3', ['-c', 'import cryptography'], { encoding: 'utf8' }).status === 0;

function pyCheck(token, env) {
  const code = 'import sys, json; sys.path.insert(0, "api"); import reconstruct as r; print(json.dumps(r.licence_check(sys.argv[1], "reconstruct")))';
  const out = spawnSync('python3', ['-c', code, token], { cwd: root, encoding: 'utf8', env: { PATH: process.env.PATH, ...env } });
  if (out.status !== 0) throw new Error(out.stderr);
  return JSON.parse(out.stdout.trim().split('\n').pop());
}

async function keyPair() {
  const kp = await crypto.webcrypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const jwk = await crypto.webcrypto.subtle.exportKey('jwk', kp.publicKey);
  const sign = async (payload) => {
    const p = Buffer.from(JSON.stringify(payload)).toString('base64url');
    const sig = await crypto.webcrypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, kp.privateKey, new TextEncoder().encode(`QS1.${p}`));
    return `QS1.${p}.${Buffer.from(sig).toString('base64url')}`;
  };
  return { jwk: { kty: 'EC', crv: 'P-256', x: jwk.x, y: jwk.y }, sign };
}

test('reconstruct.py: no licence key configured → served and says so; required without a key → refused', { skip: !hasCrypto && 'python cryptography not installed' }, () => {
  assert.deepEqual(pyCheck('', {}).slice(0, 3), [true, 200, 'open']);
  assert.deepEqual(pyCheck('', { QS_REQUIRE_LICENSE: '1' }).slice(0, 3), [false, 503, 'licensing_unavailable']);
});

test('reconstruct.py: with a key configured, only a valid Premium (or reconstruct-feature) licence is served', { skip: !hasCrypto && 'python cryptography not installed' }, async () => {
  const { jwk, sign } = await keyPair();
  const env = { QS_LICENSE_PUBLIC_KEY: JSON.stringify(jwk) };
  const now = Math.floor(Date.now() / 1000);
  assert.equal(pyCheck('', env)[2], 'licence_required');
  assert.equal(pyCheck('QS1.abc.def', env)[2], 'licence_invalid');
  assert.equal(pyCheck(await sign({ v: 1, id: 'QS-B-1', plan: 'basic', features: ['recover'], exp: now + 600 }), env)[2], 'premium_required');
  assert.equal(pyCheck(await sign({ v: 1, id: 'QS-E-1', plan: 'premium', exp: now - 86400 }), env)[2], 'licence_expired');
  assert.deepEqual(pyCheck(await sign({ v: 1, id: 'QS-P-1', plan: 'premium', exp: now + 600 }), env).slice(0, 3), [true, 200, 'licensed']);
  assert.deepEqual(pyCheck(await sign({ v: 1, id: 'QS-F-1', plan: 'team', features: ['reconstruct'], exp: now + 600 }), env).slice(0, 3), [true, 200, 'licensed']);
  assert.equal(pyCheck(await sign({ v: 1, id: 'QS-P-1', plan: 'premium', exp: now + 600 }), { ...env, QS_REVOKED_IDS: 'QS-P-1' })[2], 'licence_revoked');
  const other = await keyPair();
  assert.equal(pyCheck(await other.sign({ v: 1, id: 'QS-X-1', plan: 'premium', exp: now + 600 }), env)[2], 'licence_invalid');
});
