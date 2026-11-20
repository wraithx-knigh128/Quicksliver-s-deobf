// The files of a sample collection with the labels its folders give them (obfuscator / version or preset). Labels are claims of whoever
// filed the sample; the inventory checks them against the detector.
import fs from 'node:fs';
import path from 'node:path';

export function walkCollection(root) {
  const out = [];
  const visit = (dir) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      if (e.name === '.git') continue;
      const p = path.join(dir, e.name);
      if (e.isDirectory()) visit(p);
      else if (e.isFile() && /\.(lua|luau|txt)$/i.test(e.name)) {
        const rel = path.relative(root, p).split(path.sep).join('/');
        const parts = rel.split('/');
        out.push({ file: p, label: { rel, family: parts.length > 1 ? parts[0] : null, sub: parts.length > 2 ? parts.slice(1, -1).join('/') : null } });
      }
    }
  };
  visit(root);
  return out.sort((a, b) => a.label.rel.localeCompare(b.label.rel));
}
