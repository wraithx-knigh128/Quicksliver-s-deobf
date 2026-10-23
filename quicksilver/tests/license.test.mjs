import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { webcrypto } from 'node:crypto';
import { verifyToken, entitlements, checkRevocation } from '../src/license/license.js';
import { POLICY } from '../src/license/config.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const tools = path.join(here, '..', 'tools', 'license');
const subtle = webcrypto.subtle;

// A throw-away project root so the real src/license/config.js is never modified by tests.
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'qs-license-'));
fs.mkdirSync(path.join(root, 'src', 'license'), { recursive: true });
fs.copyFileSync(path.join(here, '..', 'src', 'license', 'config.js'), path.join(root, 'src', 'license', 'config.js'));
const env = { ...process.env, QS_LICENSE_ROOT: root };
const run = (script, ...args) => execFileSync('node', [path.join(tools, script), ...args], { env, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });

const keyOut = run('keygen.mjs');
const configText = fs.readFileSync(path.join(root, 'src', 'license', 'config.js'), 'utf8');
const jwk = JSON.parse(/PUBLIC_KEY = (\{.*\});/.exec(configText)[1]);
const issue = (...a) => run('issue.mjs', ...a).trim();
const now = Math.floor(Date.now() / 1000);

test('keygen writes a private key outside git and a public JWK into the config', () => {
  assert.match(keyOut, /Private key/);
  assert.equal(jwk.kty, 'EC');
  assert.equal(jwk.crv, 'P-256');
  assert.equal(fs.statSync(path.join(root, 'license', 'keys', 'private.pem')).mode & 0o077, 0, 'private key must not be group/world readable');
  assert.throws(() => run('keygen.mjs'), /Refusing to overwrite/);
});

test('a freshly issued key verifies and carries its claims', async () => {
  const token = issue('--name', 'Test User', '--days', '30', '--features', 'recover,export');
  const r = await verifyToken(token, jwk, { subtle });
  assert.equal(r.status, 'valid');
  assert.equal(r.payload.name, 'Test User');
  assert.deepEqual(r.payload.features, ['recover', 'export']);
  const ent = entitlements(r, POLICY);
  assert.equal(ent.recover, true);
  assert.equal(ent.export, true);
  assert.equal(ent.sandbox, false, 'a feature that was not granted must not be available');
});

test('altering the payload invalidates the signature', async () => {
  const token = issue('--name', 'Test User', '--days', '30');
  const [p, body, sig] = token.split('.');
  const forged = JSON.parse(Buffer.from(body, 'base64url').toString());
  forged.exp = now + 10 * 365 * 86400;
  forged.features = ['recover', 'sandbox', 'export', 'compare'];
  const bad = [p, Buffer.from(JSON.stringify(forged)).toString('base64url'), sig].join('.');
  assert.equal((await verifyToken(bad, jwk, { subtle })).status, 'invalid');
});

test('a key signed by someone else is rejected', async () => {
  const other = fs.mkdtempSync(path.join(os.tmpdir(), 'qs-license-other-'));
  fs.mkdirSync(path.join(other, 'src', 'license'), { recursive: true });
  fs.copyFileSync(path.join(here, '..', 'src', 'license', 'config.js'), path.join(other, 'src', 'license', 'config.js'));
  const otherEnv = { ...process.env, QS_LICENSE_ROOT: other };
  execFileSync('node', [path.join(tools, 'keygen.mjs')], { env: otherEnv, stdio: 'ignore' });
  const token = execFileSync('node', [path.join(tools, 'issue.mjs'), '--name', 'Mallory'], { env: otherEnv, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  assert.equal((await verifyToken(token, jwk, { subtle })).status, 'invalid');
});

test('expiry and not-before are enforced, with a small clock-skew allowance', async () => {
  const token = issue('--name', 'Short', '--days', '1');
  assert.equal((await verifyToken(token, jwk, { subtle, now })).status, 'valid');
  assert.equal((await verifyToken(token, jwk, { subtle, now: now + 2 * 86400 })).status, 'expired');
  assert.equal((await verifyToken(token, jwk, { subtle, now: now + 86400 + 60 })).status, 'valid', 'one minute of drift is tolerated');
  const never = issue('--name', 'Forever', '--never');
  assert.equal((await verifyToken(never, jwk, { subtle, now: now + 50 * 365 * 86400 })).status, 'valid');
});

test('malformed input never throws and is classified', async () => {
  for (const bad of ['', 'garbage', 'QS1.only.two', 'QS1.@@@.@@@', 'QS2.abc.def', `QS1.${Buffer.from('{}').toString('base64url')}.${Buffer.alloc(64).toString('base64url')}`]) {
    const r = await verifyToken(bad, jwk, { subtle });
    assert.ok(['invalid', 'missing'].includes(r.status), `${bad} -> ${r.status}`);
  }
});

test('without a configured public key nothing is restricted, with one the evaluation policy applies', async () => {
  const open = await verifyToken('', null, { subtle });
  assert.equal(open.status, 'unconfigured');
  assert.equal(entitlements(open, POLICY).level, 'open');
  const missing = await verifyToken('', jwk, { subtle });
  const ent = entitlements(missing, POLICY);
  assert.equal(ent.level, 'evaluation');
  assert.equal(ent.sandbox, false);
  assert.equal(ent.export, false);
  assert.ok(ent.maxBytes > 0);
});

test('revocation lookup fails open when the endpoint is unreachable', async () => {
  assert.deepEqual(await checkRevocation('QS-2026-AAAA', null), { revoked: false, checked: false });
  const down = await checkRevocation('QS-2026-AAAA', '/api/license', async () => { throw new Error('offline'); });
  assert.deepEqual(down, { revoked: false, checked: false });
  const yes = await checkRevocation('QS-2026-AAAA', '/api/license', async () => ({ ok: true, json: async () => ({ revoked: true }) }));
  assert.deepEqual(yes, { revoked: true, checked: true });
});

test('the revocation function validates ids and reads the environment', async () => {
  const { default: handler } = await import('../api/license.js');
  const call = (id, revoked) => {
    process.env.QS_REVOKED_IDS = revoked;
    const out = { headers: {} };
    handler({ query: { id } }, {
      setHeader: (k, v) => { out.headers[k] = v; },
      status(code) { out.code = code; return this; },
      send(body) { out.body = JSON.parse(body); },
    });
    return out;
  };
  assert.equal(call('x; drop table', '').code, 400);
  assert.deepEqual(call('QS-2026-AAAA', 'QS-2026-AAAA, QS-2026-BBBB').body.revoked, true);
  assert.deepEqual(call('QS-2026-CCCC', 'QS-2026-AAAA').body.revoked, false);
  assert.equal(call('QS-2026-CCCC', '').headers['Cache-Control'], 'no-store');
});
