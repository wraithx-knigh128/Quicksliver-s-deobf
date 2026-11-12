// Take a reproducible sample of a labelled public collection of obfuscated scripts, for measuring detection and recovery against real data.
//
//   node tools/formats/corpus-sample.mjs --src /path/to/obfuscator-samples [--per 12] [--max-bytes 300000]
//
// The collection (github.com/vyxonq-dev/obfuscator-samples at the commit named in the index) is a directory per obfuscator, sometimes with a directory per version
// inside it; the file names are hashes. For every bucket (obfuscator, or obfuscator + version) this keeps the `per` files with the smallest SHA-256 that are not larger than
// `max-bytes`, copies them to local/corpus/<bucket>/ (git-ignored: the scripts are third parties' and carry no licence) and writes data/research/corpus-index.json: the
// bucket, the file's SHA-256 and its size. Anyone with the collection at that commit gets the same files.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const arg = (n, d) => (process.argv.includes(n) ? process.argv[process.argv.indexOf(n) + 1] : d);
const src = arg('--src');
if (!src) { console.error('--src <collection>'); process.exit(2); }
const per = Number(arg('--per', 12));
const maxBytes = Number(arg('--max-bytes', 300000));
const commit = spawnSync('git', ['-C', src, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).stdout.trim();

const buckets = new Map();
const walk = (dir, rel) => {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === '.git') continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, [...rel, e.name]);
    else if (/\.(lua|luau|txt)$/i.test(e.name) && rel.length) {
      const size = fs.statSync(p).size;
      if (size > maxBytes || size < 40) continue;
      const bucket = rel.join('/');
      if (!buckets.has(bucket)) buckets.set(bucket, []);
      buckets.get(bucket).push(p);
    }
  }
};
walk(src, []);
const out = path.join(root, 'local/corpus');
fs.rmSync(out, { recursive: true, force: true });
const index = [];
for (const [bucket, files] of [...buckets].sort()) {
  const scored = files.map((f) => { const b = fs.readFileSync(f); return { f, b, sha: crypto.createHash('sha256').update(b).digest('hex') }; }).sort((a, b) => (a.sha < b.sha ? -1 : 1)).slice(0, per);
  fs.mkdirSync(path.join(out, bucket), { recursive: true });
  for (const s of scored) {
    fs.writeFileSync(path.join(out, bucket, `${s.sha.slice(0, 16)}.lua`), s.b);
    index.push({ bucket, sha256: s.sha, bytes: s.b.length });
  }
}
fs.writeFileSync(path.join(root, 'data/research/corpus-index.json'), `${JSON.stringify({ source: 'https://github.com/vyxonq-dev/obfuscator-samples', commit, per, maxBytes, files: index.length, buckets: [...buckets].map(([k, v]) => ({ bucket: k, available: v.length, taken: Math.min(per, v.length) })), index }, null, 0)}\n`);
console.log(`${index.length} files from ${buckets.size} buckets -> local/corpus (commit ${commit.slice(0, 10)})`);
