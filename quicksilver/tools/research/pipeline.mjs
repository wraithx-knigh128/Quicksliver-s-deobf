// Print and store where every system/version stands in the research pipeline, from the evidence on file.
//   node tools/research/pipeline.mjs [--write]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { pipelineReport, STAGES } from '../../src/research/pipeline.js';

const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'data', 'research');
const profiles = JSON.parse(fs.readFileSync(path.join(dir, 'profiles.json'), 'utf8'));
const caps = fs.existsSync(path.join(dir, 'capabilities.json')) ? JSON.parse(fs.readFileSync(path.join(dir, 'capabilities.json'), 'utf8')).capabilities : [];
const report = pipelineReport(profiles, caps);
for (const r of report) {
  const first = r.stages.find((s) => !s.reached);
  console.log(`${r.system}@${r.version}`.padEnd(32), (r.reached || 'none').padEnd(24), `identify:${r.integration.identify ? 'yes' : 'no '} rebuild:${r.integration.reconstruct ? 'yes' : 'no '}`, first ? `next: ${first.stage} — ${first.missing[0]}` : 'all stages');
}
if (process.argv.includes('--write')) fs.writeFileSync(path.join(dir, 'pipeline.json'), JSON.stringify({ schema: 1, stages: STAGES, generatedAt: new Date().toISOString(), report }, null, 2) + '\n');
