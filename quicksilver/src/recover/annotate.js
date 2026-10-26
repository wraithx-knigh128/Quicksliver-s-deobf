// The recovery report that travels with the recovered code.
//
// A result that is saved, copied or sent on loses the panel next to it, and a file that still holds a virtual machine looks, without a word, like
// any other file. When the recovery is not complete the output therefore begins with a short comment saying what it is, what was done, and what
// is left. It is made only from what the run measured (the detection, the steps with their outcomes, the confidence reasons and the adaptive
// engine's residuals), never from a guess about the original; and it is left off when nothing is left to say.
//
// The block is plain `--` comments between two fixed marker lines, so that running the result through QuickSilver again replaces it instead of
// stacking another one on top.

const START = '-- QuickSilver recovery report';
const END = '-- (end of report)';
const WIDTH = 108;

const LABEL = {
  high: 'RECOVERED',
  medium: 'MOSTLY RECOVERED, NOT FULLY VERIFIED',
  low: 'PARTIAL: obfuscation infrastructure remains',
  minimal: 'PARTIAL: obfuscation infrastructure remains',
  none: 'NOT RECOVERED',
};

/** Wrap one sentence to the comment width, continuation lines indented. */
function wrap(text, first, rest) {
  const words = String(text).replace(/\s+/g, ' ').trim().split(' ');
  const lines = [];
  let cur = first;
  for (const w of words) {
    if (cur.length + w.length + 1 > WIDTH && cur.trim().length > first.trim().length) { lines.push(cur); cur = rest; }
    cur += (cur.endsWith(' ') ? '' : ' ') + w;
  }
  lines.push(cur);
  return lines;
}

const plural = (n, one, many = `${one}s`) => `${n} ${n === 1 ? one : many}`;

/**
 * @param {{detection: object, steps: object[], confidence: object, adaptive: object|null}} run
 * @returns {{show: boolean, label: string, level: string, lines: string[], unresolved: object[], applied: object[], notApplied: object[]}}
 */
export function buildReport({ detection, steps, confidence, adaptive }) {
  const level = confidence.level || 'none';
  const unresolved = [];
  for (const r of confidence.reasons || []) if (r.effect < 0) unresolved.push({ source: 'confidence', text: r.text });
  if (adaptive && adaptive.residual) {
    // A program that another reader rebuilt (the VM lifter) was only looked at by the structure reader, and what it lists there is what the
    // program does (it loads code, it has a condition that is always false), not obfuscation left over. Only a leftover interpreter or payload counts.
    const leftovers = adaptive.observeOnly ? new Set(['interpreter', 'payload']) : null;
    const seen = new Map();
    for (const x of adaptive.residual) {
      if (!(x.weight > 0) || (leftovers && !leftovers.has(x.kind))) continue;
      const text = `${x.label ? `${x.label}: ` : ''}${x.reason}`;
      const key = `${x.kind}|${text}`;
      if (seen.has(key)) { seen.get(key).count++; continue; }
      const item = { source: 'structure', kind: x.kind, line: x.line, text, count: 1 };
      seen.set(key, item);
      unresolved.push(item);
    }
    for (const u of unresolved) if (u.count > 1) u.text += ` (${u.count} places, first at line ${u.line})`;
  }
  const remote = adaptive && adaptive.residual ? adaptive.residual.filter((x) => x.kind === 'remote-loader') : [];
  const checks = (confidence.reasons || []).filter((r) => r.effect === 0).map((r) => r.text);

  const applied = steps.filter((s) => s.status === 'applied' && s.changed > 0).map((s) => ({ id: s.id, label: s.label, changed: s.changed }));
  const notApplied = steps
    .filter((s) => s.status === 'skipped' || s.status === 'failed')
    .map((s) => ({ id: s.id, label: s.label, status: s.status, why: s.detail && typeof s.detail === 'string' ? s.detail : s.error || '' }));

  const show = level !== 'high' || unresolved.length > 0;
  const families = (detection.families || []).filter((f) => f.confidence >= 0.5);

  const lines = [START];
  lines.push(...wrap(`Result: ${LABEL[level] || LABEL.none} (confidence ${level}, ${Number(confidence.score || 0).toFixed(2)}). This is a reconstruction, not the original source: names, comments and layout are not recovered.`, '-- ', '--   '));
  if (families.length) {
    lines.push(...wrap(`Recognised from the structure of the code (a header comment is not taken as proof): ${families.map((f) => `${f.name}${f.version ? ` ${f.version}` : ''}`).join(', ')}.`, '-- ', '--   '));
  }
  if (applied.length) {
    lines.push(...wrap(`Done: ${applied.slice(0, 8).map((s) => `${s.id} (${s.changed})`).join(', ')}${applied.length > 8 ? `, and ${applied.length - 8} more` : ''}.`, '-- ', '--   '));
  }
  if (notApplied.length) {
    lines.push(...wrap(`Not done: ${notApplied.slice(0, 5).map((s) => `${s.id}${s.why ? ` (${String(s.why).slice(0, 80)})` : ''}`).join('; ')}.`, '-- ', '--   '));
  }
  if (unresolved.length) {
    lines.push('-- Left unresolved:');
    for (const u of unresolved.slice(0, 6)) lines.push(...wrap(`* ${u.text}`, '--   ', '--     '));
    if (unresolved.length > 6) lines.push(`--   * and ${plural(unresolved.length - 6, 'more item')}.`);
  }
  if (remote.length) {
    lines.push(...wrap(`Fetched when the script runs, so not in this file: ${plural(remote.length, 'loadstring of a network request', 'loadstrings of network requests')}.`, '-- ', '--   '));
  }
  for (const c of checks.slice(0, 3)) lines.push(...wrap(`Check: ${c}`, '-- ', '--   '));
  lines.push(END);

  return { show, label: LABEL[level] || LABEL.none, level, lines, unresolved, applied, notApplied };
}

/** The output with the report in front of it (or as it was, when there is nothing to report). */
export function annotate(output, report) {
  return report.show ? `${report.lines.join('\n')}\n\n${output}` : output;
}

/** A report an earlier run put in front of the text, taken off so that it is replaced and not repeated. */
export function stripReport(text) {
  if (!text.startsWith(START)) return text;
  const end = text.indexOf(`\n${END}`);
  if (end < 0) return text;
  return text.slice(end + END.length + 1).replace(/^\n+/, '');
}
