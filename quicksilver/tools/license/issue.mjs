#!/usr/bin/env node
// Issue a licence key.
//
//   node tools/license/issue.mjs --name "Alice" [--plan pro] [--days 365 | --never]
//        [--features recover,sandbox,export,compare] [--max-bytes 5000000] [--id QS-...]
//
// Prints the key and appends a record to license/issued.jsonl (git-ignored) so that a key can be revoked later
// by adding its id to the QS_REVOKED_IDS environment variable of the deployment.

import { createPrivateKey, sign, randomBytes } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = process.env.QS_LICENSE_ROOT
  ? path.resolve(process.env.QS_LICENSE_ROOT)
  : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const args = process.argv.slice(2);
const arg = (name, fallback) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : fallback; };

const name = arg('name');
if (!name) { console.error('usage: issue.mjs --name "Licensee" [--plan pro] [--days 365 | --never] [--features a,b] [--max-bytes N] [--id QS-...]'); process.exit(2); }

const privatePath = path.join(root, 'license', 'keys', 'private.pem');
if (!fs.existsSync(privatePath)) { console.error('No private key. Run tools/license/keygen.mjs first.'); process.exit(1); }

const now = Math.floor(Date.now() / 1000);
const id = arg('id', `QS-${new Date().getUTCFullYear()}-${randomBytes(4).toString('hex').toUpperCase()}`);
const payload = {
  v: 1,
  id,
  name,
  plan: arg('plan', 'pro'),
  features: arg('features', 'recover,sandbox,export,compare').split(',').map((s) => s.trim()).filter(Boolean),
  iat: now,
  exp: args.includes('--never') ? null : now + Number(arg('days', '365')) * 86400,
};
if (arg('max-bytes')) payload.maxBytes = Number(arg('max-bytes'));

const b64u = (buf) => Buffer.from(buf).toString('base64url');
const body = b64u(JSON.stringify(payload));
const signature = sign('sha256', Buffer.from(`QS1.${body}`), { key: createPrivateKey(fs.readFileSync(privatePath)), dsaEncoding: 'ieee-p1363' });
const token = `QS1.${body}.${b64u(signature)}`;

fs.appendFileSync(path.join(root, 'license', 'issued.jsonl'), JSON.stringify({ ...payload, issuedAt: new Date().toISOString() }) + '\n');
console.log(token);
console.error(`\nissued ${id} to ${name}, plan ${payload.plan}, ${payload.exp ? 'expires ' + new Date(payload.exp * 1000).toISOString().slice(0, 10) : 'does not expire'}`);
