// The reconstruction report as Markdown: what was run, what came out, what was checked, and what that does and does not show.
// Built from the service's result and the compatibility registry only, so it contains no claim the page did not show.

import { VERSIONS, versionFor, parseBanner } from './engines.js';
import { versionStatus } from './status.js';

const esc = (s) => String(s).replace(/\|/g, '\\|').replace(/\r?\n/g, ' ');
const KIND_TEXT = {
  devirtualized: 'Lifted from the virtual machine (the program was rebuilt from the VM, including branches that did not run).',
  'trace-assisted': 'Built from a behaviour trace after the lift was refused or incomplete (what one run did).',
  trace: 'Behaviour trace only (what one run did, in order; branches that did not run are absent).',
  none: 'No output.',
};
const VERIFY_TEXT = {
  identical: 'Compared with the original you supplied on a real Luau runtime: same output and return values.',
  different: 'Compared with the original on a real Luau runtime: the behaviour DIFFERS.',
  inconclusive: 'Could not be compared with the original.',
  'not-run': 'Not compared with an original. Readable output is not the same as a verified reconstruction.',
};

export function buildReconstructionReport({ name = 'script.lua', result, registry = null, generatedAt = new Date().toISOString() }) {
  const out = [];
  const eng = result.engine || {};
  out.push(`# Reconstruction report: ${name}`, '', `Generated ${generatedAt} by QuickSilver.`, '');
  out.push('| | |', '|---|---|');
  if (result.identification) out.push(`| Input | ${result.identification.bytes} bytes, SHA-256 ${result.identification.sha256} |`);
  const b = result.identification && result.identification.banner;
  out.push(`| Banner | ${b ? esc(`${b.text} (a claim made by the file; anyone can write or remove one)`) : 'none'} |`);
  out.push(`| Engine | ${esc(eng.label || 'none')}${eng.nearest ? ' (the nearest engine to the version named: experimental)' : ''}${eng.mode === 'trace' ? ', trace mode' : ''} |`);
  out.push(`| Output | ${esc(KIND_TEXT[result.kind] || result.kind)} |`);
  out.push(`| Verification | **${esc(result.verification ? result.verification.status : 'not-run')}**: ${esc(VERIFY_TEXT[result.verification ? result.verification.status : 'not-run'] || '')} |`);
  if (result.seconds !== undefined) out.push(`| Time | ${result.seconds} s |`);
  out.push('');
  if (eng.attempts && eng.attempts.length) {
    out.push('## Attempts', '', '| Engine | Mode | Outcome | Seconds |', '|---|---|---|---|');
    for (const a of eng.attempts) out.push(`| ${esc(a.engine)}${a.nearest ? ' (nearest)' : ''} | ${a.mode} | ${a.outcome} | ${a.seconds} |`);
    out.push('');
  }
  if (result.quality) {
    const q = result.quality;
    out.push('## Quality', '', `${q.lines} lines, ${q.functions} functions. Unresolved markers: ${q.unresolvedTotal} (grade: ${q.grade}).`, '');
    const u = Object.entries(q.unresolved || {}).filter(([, n]) => n > 0);
    if (u.length) out.push(...u.map(([k, n]) => `- ${k}: ${n}`), '');
    if (result.checks && result.checks.syntax) out.push(`Syntax: ${result.checks.syntax.ok ? 'valid Luau' : result.checks.syntax.ok === false ? 'NOT valid: ' + esc((result.checks.syntax.errors || []).join('; ')) : 'not checked'}.`, '');
  }
  if (result.verification && result.verification.status === 'different') {
    out.push('### Where they differ', '', '```', `original:       ${result.verification.original}`, `reconstruction: ${result.verification.reconstruction}`, '```', '');
  }
  if (result.diagnostics && result.diagnostics.length) {
    out.push('## Diagnostics', '');
    for (const d of result.diagnostics) out.push(`- **${d.severity}** \`${d.code}\`: ${esc(d.message)} ${esc(d.hint || '')}${d.evidence ? ` _(evidence: ${esc(d.evidence)})_` : ''}`);
    out.push('');
  }
  if (registry) {
    const row = versionFor(b ? parseBanner(b.text) : null);
    out.push('## Compatibility of what the file claims to be', '');
    if (row) {
      const s = versionStatus(row, registry);
      out.push(`${row.label}: **${s.status}**. ${s.reasons.join('; ')}.`, '');
    } else out.push('The input names no version this project tracks.', '');
    out.push('| Version | Status | Basis |', '|---|---|---|');
    for (const v of VERSIONS) { const s = versionStatus(v, registry); out.push(`| ${esc(v.label)} | ${s.status} | ${esc(s.reasons.join('; '))} |`); }
    out.push('');
  }
  out.push('## What this does not show', '', '- Original names, comments and layout are not recoverable; names are inferred from use.', '- A lifted program includes branches that never ran; a trace does not.', '- "Identical" means the same output and return values on one runtime for the inputs it was run with, and only for scripts that run on plain Luau. It is not proof of equivalence.', '- The engine runs the protected script in an emulated Roblox environment; behaviour that depends on the real game is not observed.', '');
  return out.join('\n');
}
