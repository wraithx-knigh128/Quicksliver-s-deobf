// Research: how a file in a public repository changed over time, as structured data.
//
//   node tools/research/file-history.mjs <repo-dir> <file> <regex> <out.json> [--source <url>]
//
// Reads the repository's git history (text only; nothing in it is executed) and, for every commit that touched <file>, lists the distinct matches of
// <regex> in the file as it was then, with the commit, date and subject, and what was added or removed since the previous commit. Used to date the
// appearance of named features (for example the macros in a protector vendor's own SDK repository) from a primary source.

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import crypto from 'node:crypto';

export function fileHistory({ dir, file, pattern, source = null }) {
  const git = (...args) => execFileSync('git', ['-C', dir, ...args], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  const log = git('log', '--reverse', '--format=%H%x1f%ad%x1f%s', '--date=short', '--', file).split('\n').filter(Boolean).map((l) => l.split('\x1f'));
  const re = new RegExp(pattern, 'g');
  let previous = new Set();
  const commits = [];
  for (const [hash, date, subject] of log) {
    let text = '';
    try { text = git('show', `${hash}:${file}`); } catch { /* the file was deleted in this commit */ }
    const names = new Set(text.match(re) || []);
    commits.push({
      commit: hash.slice(0, 10), date, subject, fileSha256: crypto.createHash('sha256').update(text).digest('hex').slice(0, 16), count: names.size,
      names: [...names].sort(), added: [...names].filter((n) => !previous.has(n)).sort(), removed: [...previous].filter((n) => !names.has(n)).sort(),
    });
    previous = names;
  }
  return { schema: 1, file, pattern, source, commits, note: 'Derived from the repository\'s git history; the file contents are not stored here.' };
}

if (process.argv[1] && fs.realpathSync(process.argv[1]) === fs.realpathSync(new URL(import.meta.url).pathname)) {
  const [dir, file, pattern, out] = process.argv.slice(2);
  const source = process.argv.includes('--source') ? process.argv[process.argv.indexOf('--source') + 1] : null;
  const h = fileHistory({ dir, file, pattern, source });
  fs.mkdirSync(new URL('../../data/research/histories/', import.meta.url).pathname, { recursive: true });
  fs.writeFileSync(out, JSON.stringify(h, null, 1) + '\n');
  for (const c of h.commits) console.log(c.date, c.commit, String(c.count).padStart(2), c.subject.slice(0, 50).padEnd(50), c.added.length ? '+' + c.added.join(',') : '', c.removed.length ? '-' + c.removed.join(',') : '');
}
