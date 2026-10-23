#!/usr/bin/env node
// Create the licence signing key pair.
//
//   node tools/license/keygen.mjs
//
// Writes the PRIVATE key to license/keys/private.pem (mode 600, git-ignored) and the PUBLIC key into
// src/license/config.js. Run it once, on a machine you trust, and back the private key up somewhere safe:
// losing it means no new licences can be issued; leaking it means anyone can issue them.

import { generateKeyPairSync } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = process.env.QS_LICENSE_ROOT
  ? path.resolve(process.env.QS_LICENSE_ROOT)
  : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const keyDir = path.join(root, 'license', 'keys');
const privatePath = path.join(keyDir, 'private.pem');
const configPath = path.join(root, 'src', 'license', 'config.js');

if (fs.existsSync(privatePath) && !process.argv.includes('--force')) {
  console.error(`A private key already exists at ${path.relative(root, privatePath)}.\nRefusing to overwrite it (every issued licence would stop verifying). Use --force if you really mean it.`);
  process.exit(1);
}

const { publicKey, privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
fs.mkdirSync(keyDir, { recursive: true });
fs.writeFileSync(privatePath, privateKey.export({ type: 'pkcs8', format: 'pem' }), { mode: 0o600 });

const jwk = publicKey.export({ format: 'jwk' });
const config = fs.readFileSync(configPath, 'utf8');
const updated = config.replace(/export const PUBLIC_KEY = [\s\S]*?;\n/, `export const PUBLIC_KEY = ${JSON.stringify({ kty: jwk.kty, crv: jwk.crv, x: jwk.x, y: jwk.y })};\n`);
fs.writeFileSync(configPath, updated);

console.log(`Private key : ${path.relative(root, privatePath)}  (keep secret, back it up, never commit it)`);
console.log(`Public key  : written to ${path.relative(root, configPath)}`);
console.log('Licence checking is now active in the app. Issue keys with tools/license/issue.mjs.');
