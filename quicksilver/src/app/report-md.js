// The detailed analysis report as Markdown: one file that says what the input is, what was done, what was checked, and what the evidence behind the
// chosen plan is. It is built from the result objects only, so it contains no claim the page did not show.

const esc = (s) => String(s).replace(/\|/g, '\\|').replace(/\r?\n/g, ' ');
const pct = (x) => `${Math.round(x * 100)}%`;
const fence = (s) => `\`\`\`\n${String(s).replace(/```/g, "'''")}\n\`\`\``;

/**
 * @param {{name?: string, bytes?: number, sha256?: string, detection?: object, recovered?: object, advice?: object, observed?: object, identification?: object, engine?: string, generatedAt?: string}} r
 */
export function buildMarkdownReport(r) {
  const out = [];
  const rec = r.recovered || null;
  const nx = rec && rec.nexus && !rec.nexus.fallback ? rec.nexus : null;
  out.push(`# Analysis report: ${r.name || 'untitled'}`, '');
  out.push(`Generated ${r.generatedAt || new Date().toISOString()} by QuickSilver ${r.engine || ''}${nx ? ` with NEXUS ${nx.version}` : ''}.`, '');
  out.push('| | |', '|---|---|', `| Input size | ${r.bytes != null ? `${r.bytes} bytes` : '—'} |`, `| SHA-256 | ${r.sha256 || '—'} |`);
  if (r.detection) out.push(`| Dialect | ${esc(r.detection.dialect.label)} (${pct(r.detection.dialect.confidence)}) |`, `| Obfuscators recognised | ${esc(r.detection.families.filter((f) => f.confidence >= 0.5).map((f) => f.name).join(', ') || 'none')} |`);
  if (rec && rec.confidence) out.push(`| Confidence | ${rec.confidence.level} (${rec.confidence.score}) |`);
  out.push('');

  if (r.identification && r.identification.systems.length) {
    out.push('## System and version', '');
    for (const sys of r.identification.systems) {
      out.push(`### ${esc(sys.name)} (${pct(sys.confidence)}, by ${sys.basis})`, '');
      for (const e of sys.evidence) out.push(`- ${esc(e)}`);
      if (sys.version) {
        out.push(`- Version: ${esc(sys.version.claimed ? `${sys.version.claimed} claimed` : sys.version.candidates && sys.version.candidates.length ? `one of ${sys.version.candidates.join(', ')}` : 'not estimated')}${sys.version.generation ? `, generation ${esc(sys.version.generation)}` : ''} (confidence ${pct(sys.version.confidence)}, ${sys.version.basis})`);
        for (const c of sys.version.caveats) out.push(`  - ${esc(c)}`);
      }
      if (sys.profile) {
        out.push(`- What may be claimed: **${sys.profile.claim.claim}**. ${esc(sys.profile.claim.why)} (profile status: ${sys.profile.status})`);
        for (const l of sys.profile.limitations) out.push(`  - Limit: ${esc(l)}`);
      }
      out.push('');
    }
    out.push('Recognising a system is not reconstructing it: a reconstruction is only called verified for a system when the engine\'s output was checked to behave like the original on a reference Lua runtime.', '');
  }

  if (r.advice) {
    out.push('## Plan chosen and the evidence for it', '');
    out.push(`${r.advice.reason}`, '');
    if (r.observed && r.observed.tokens.length) out.push(`What the input shows: ${r.observed.tokens.map((t) => `\`${t}\``).join(', ')}`, '');
    if (r.advice.alternatives && r.advice.alternatives.length) {
      out.push('| Plan | Trials | Verified | 95% interval | Mean closeness to original | Worse or failed |', '|---|---|---|---|---|---|');
      for (const a of r.advice.alternatives) out.push(`| ${esc(a.label)} | ${a.n} | ${a.success}/${a.n} | ${pct(a.lo)}–${pct(a.hi)} | ${a.fidelityAfter == null ? '—' : a.fidelityAfter.toFixed(2)} | ${a.worse + a.failed} |`);
      out.push('');
    }
    out.push('The experiments are on generated programs, with behaviour decided on the runtime the Research tab names (a reference Lua when one was installed, this project\'s own interpreter otherwise). They are evidence about kinds of input, not a guarantee about this one.', '');
  }

  if (nx) {
    const s = nx.ledger.summary;
    out.push('## Verification', '', `${s.verified} verified, ${s.inferred} inferred, ${s.unresolved} unresolved, ${s.inconsistent} failed.`, '');
    for (const c of nx.ledger.claims.filter((x) => x.state !== 'inferred')) out.push(`- **${c.state}**: ${esc(c.statement)}${c.check ? ` _(checked by: ${esc(c.check)})_` : ''}`);
    out.push('');
    if (nx.transformations.length) {
      out.push('## What was done to the text', '');
      for (const t of nx.transformations) out.push(`- ${esc(t.label)} (${pct(t.confidence)}, ${t.category}): ${esc(t.technique)}`);
      out.push('');
    }
    if (nx.trivia && nx.trivia.message) {
      out.push('## Text found in the comments', '', 'Shown as data. It is part of the file and was not acted on.', '', fence(nx.trivia.message), '');
    }
    if (nx.roles && nx.roles.applied.length) {
      out.push('## Names chosen from use (inferred, not original)', '', '| From | To | Rule | Evidence |', '|---|---|---|---|');
      for (const a of nx.roles.applied) out.push(`| \`${esc(a.from)}\` | \`${esc(a.to)}\` | ${esc(a.rule)} ${pct(a.confidence)} | ${esc(a.evidence.slice(0, 2).join('; '))} |`);
      out.push('');
    }
    if (nx.relations && nx.relations.dependencies.length) {
      out.push('## Dependencies', '');
      for (const url of new Set(nx.relations.dependencies.map((d) => d.url).filter(Boolean))) out.push(`- ${esc(url)}`);
      if (nx.relations.executorApis.length) out.push(`- Executor APIs: ${nx.relations.executorApis.join(', ')}`);
      out.push('');
    }
    if (nx.needs.length) { out.push('## Would help', ''); for (const n of nx.needs) out.push(`- **${n.need}**: ${esc(n.why)}`); out.push(''); }
    out.push('## Stages', '', '| Stage | Time |', '|---|---|');
    for (const st of nx.stages) out.push(`| ${esc(st.title)} | ${st.ms} ms |`);
    out.push('');
  } else if (rec) {
    out.push('## Passes', '');
    for (const st of rec.steps || []) out.push(`- ${esc(st.label)}: ${st.status}${st.changed ? ` ×${st.changed}` : ''}`);
    out.push('');
  }
  out.push('## Limits', '', '- Names are inferred from use; the original names are not recoverable.', '- Static analysis alone does not reach certainty; the confidence level is derived from what is still visible in the result.', '- Fetched or generated code that is not in the file is not analysed.', '');
  return out.join('\n');
}
