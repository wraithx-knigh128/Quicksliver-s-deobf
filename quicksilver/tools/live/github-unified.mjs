#!/usr/bin/env node
// Prompt XXVIII live check: real GitHub, the real /api/github handler (api/github.js), and the one Deobfuscate pipeline
// (src/pipeline/unified.js) with the real engine — the same path the page takes, minus the browser. Every input is a public repository the
// person running it may read; nothing retrieved is executed.
//
//   NODE_USE_ENV_PROXY=1 node tools/live/github-unified.mjs <input> [<input> ...] [--out file.json]
// An input is a GitHub link (file, raw, API, gist, repository) or a loadstring line. Prints each run's stages and result.

import http from 'node:http';
import fs from 'node:fs';
import { createHandler } from '../../api/github.js';
import { deobfuscate } from '../../src/pipeline/unified.js';
import { analyzeLoader } from '../../src/loader/analyze.js';
import { decodePayload } from '../../src/loader/payload.js';
import { detect } from '../../src/detect/detect.js';
import { recoverSource } from '../../src/api.js';

const args = process.argv.slice(2);
const outAt = args.indexOf('--out');
const out = outAt >= 0 ? args.splice(outAt, 2)[1] : null;
if (!args.length) { console.error('usage: node tools/live/github-unified.mjs <github link or loadstring> ... [--out file.json]'); process.exit(2); }

const handler = createHandler({ env: { ...process.env, QS_LICENSE_PUBLIC_KEY: '', QS_REQUIRE_LICENSE: '' } });
const server = http.createServer((req, res) => {
  if (req.url !== '/api/github') { res.writeHead(404); res.end(); return; }
  let body = '';
  req.on('data', (c) => { body += c; });
  req.on('end', () => { req.body = JSON.parse(body || '{}'); handler(req, res); });
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}`;

// what the page's githubRequest does (src/app/github-ui.js): POST the link, decode the file
async function github(url, { mode }) {
  const res = await fetch(`${base}/api/github`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Sec-Fetch-Site': 'same-origin' }, body: JSON.stringify({ url, mode }) });
  const j = await res.json();
  if (j.ok && j.file && j.file.base64) j.file.bytes = Uint8Array.from(Buffer.from(j.file.base64, 'base64'));
  return j;
}

const runs = [];
for (const input of args) {
  const t0 = Date.now();
  const R = await deobfuscate({ text: input, name: 'input.lua' }, {
    github, analyze: (s, o) => analyzeLoader(s, o), decode: (b, m) => decodePayload(b, m), detect: (t) => detect(t), recover: (t) => recoverSource(t, { nexus: true }),
    choose: async () => null,
  });
  const row = {
    input, ms: Date.now() - t0, verdict: R.verdict && R.verdict.outcome, source: R.source && R.source.class, sourceMessage: R.source && R.source.message,
    delivered: R.final ? { name: R.final.name, isPayload: R.final.isPayload, lines: R.final.output.split('\n').length, bytes: R.final.output.length, extras: (R.final.dependencies || []).map((d) => d.name) } : null,
    chain: R.chain.map((n) => ({ depth: n.depth, name: n.name, address: n.address, role: n.role, bytes: n.bytes, sha256: n.sha256 })),
    stages: R.stages.map((s) => ({ n: s.n, id: s.id, status: s.status, detail: s.detail })),
  };
  runs.push(row);
  console.log(`\n== ${input}\n   verdict ${row.verdict} · source ${row.source} · ${row.delivered ? `delivered ${row.delivered.name} (${row.delivered.lines} lines${row.delivered.isPayload ? '' : ', LOADER ONLY'})` : 'nothing delivered'} · ${row.ms} ms`);
  for (const s of row.stages) console.log(`   ${String(s.n).padStart(2)} ${s.status.padEnd(7)} ${s.id.padEnd(9)} ${String(s.detail).slice(0, 170)}`);
}
server.close();
if (out) fs.writeFileSync(out, JSON.stringify({ measured: new Date().toISOString().slice(0, 10), tool: 'tools/live/github-unified.mjs', runs }, null, 1) + '\n');
