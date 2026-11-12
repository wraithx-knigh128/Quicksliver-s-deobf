// Recover one script and print one JSON line (used by corpus-eval.mjs, which runs it in a child process with a time limit).
import fs from 'node:fs';
import { bytesToBinary } from '../../src/core/bytes.js';
import { recover } from '../../src/recover/pipeline.js';

const t0 = Date.now();
try {
  const r = recover(bytesToBinary(fs.readFileSync(process.argv[2])), { sandbox: { enabled: false } });
  const left = r.confidence && r.confidence.reasons ? r.confidence.reasons.filter((x) => x.effect < 0).length : 0;
  console.log(JSON.stringify({ ok: r.ok, stage: r.stage || null, ms: Date.now() - t0, confidence: r.confidence ? r.confidence.score : null, level: r.confidence ? r.confidence.level : null,
    steps: (r.steps || []).filter((s) => s.status === 'applied').map((s) => s.id), failed: (r.steps || []).filter((s) => s.status === 'failed').map((s) => `${s.id}: ${String(s.error).slice(0, 80)}`),
    bytesIn: fs.statSync(process.argv[2]).size, bytesOut: r.output ? r.output.length : 0, deductions: left }));
} catch (e) { console.log(JSON.stringify({ ok: false, crash: String(e && e.stack || e).split('\n').slice(0, 2).join(' | ').slice(0, 200), ms: Date.now() - t0 })); }
