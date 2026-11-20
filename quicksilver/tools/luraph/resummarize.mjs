// Recompute the summary of data/research/luraph-compat.json from its stored records and the current version table (src/reconstruct/engines.js),
// without running any engine. Used when the version table changes but no evidence does (Prompt XXII: v15.1 and v15.2 rows split).
//   node tools/luraph/resummarize.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { engineStatus, versionStatus } from '../../src/reconstruct/status.js';
import { VERSIONS, ENGINES } from '../../src/reconstruct/engines.js';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const file = path.join(root, 'data', 'research', 'luraph-compat.json');
const registry = JSON.parse(fs.readFileSync(file, 'utf8'));
const records = registry.records;
registry.summary = {
  ...registry.summary,
  engines: Object.fromEntries(Object.keys(ENGINES).filter((e) => e !== 'generic').map((e) => [e, engineStatus(records.filter((r) => r.engine === e), { hasEngine: true })])),
  versions: Object.fromEntries(VERSIONS.map((v) => [v.id, versionStatus(v, registry)])),
};
fs.writeFileSync(file, JSON.stringify(registry, null, 1) + '\n');
for (const [id, s] of Object.entries(registry.summary.versions)) console.log(`  ${id.padEnd(18)} ${s.status.padEnd(17)} ${s.reasons.join('; ')}`);
