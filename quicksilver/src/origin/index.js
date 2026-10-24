// Origin check: how much does this script look like assistant-written code, and how much of it exists elsewhere?
//
//   originAnalysis(source)       local only: style signals, hints of other authors, the lines worth searching for
//   mergeOnline(analysis, hits)  fold in the result of the online search (api/origin.js) into one verdict
//
// Read src/origin/style.js first for what the percentages mean and what they do not.

import { model, aiStyle, aiLabel, skidHints } from './style.js';
import { significantLines, pickFingerprints, queryFor, coverage } from './lines.js';

/** Minified or obfuscated text carries no style: names are one letter and lines are enormous. */
function looksUnreadable(m, source) {
  if (!source.trim()) return { yes: true, why: 'There is no text.' };
  const longLines = m.rows.filter((r) => r.length > 600).length;
  if (m.rows.length < 6 && source.length > 1500) return { yes: true, why: 'The script is a few enormous lines, which is what minified or obfuscated code looks like.' };
  if (longLines / Math.max(1, m.rows.length) > 0.3) return { yes: true, why: 'Most lines are hundreds of characters long: minified or obfuscated.' };
  const names = [...new Set(m.locals)];
  if (names.length >= 10) {
    // short names alone are how plenty of people write; machine-made names are not
    const machine = names.filter((n) => /^[Il1O0_]{4,}$/.test(n) || /^_*0x[0-9a-f]+$/i.test(n) || /^_r\d/.test(n)).length / names.length;
    if (machine > 0.7) return { yes: true, why: 'Nearly every local has a machine-made name.' };
    const code = m.rows.filter((r) => r.trim());
    const avg = code.reduce((a, r) => a + r.length, 0) / Math.max(1, code.length);
    const tiny = names.filter((n) => n.length <= 2).length / names.length;
    if (tiny > 0.7 && avg > 140) return { yes: true, why: 'One- and two-letter names on very long lines: minified or obfuscated.' };
  }
  return { yes: false };
}

const confidenceOf = (codeLines) => (codeLines < 40 ? 'low' : codeLines < 250 ? 'medium' : 'high');

/**
 * @param {string} source binary string
 */
export function originAnalysis(source) {
  const m = model(source);
  const unreadable = looksUnreadable(m, source);
  const lines = significantLines(source);
  const fingerprints = pickFingerprints(lines, 8).map((l) => ({ line: l.line, text: l.text, query: queryFor(l.text) }));
  const base = { lines: m.rows.length, codeLines: m.codeLines, confidence: confidenceOf(m.codeLines), significantLines: lines.length, fingerprints };
  if (unreadable.yes) {
    return { ...base, assessable: false, reason: unreadable.why, ai: null, skid: null };
  }
  const ai = aiStyle(m, source);
  const skid = skidHints(m, source);
  return {
    ...base,
    assessable: true,
    ai: { score: ai.score, label: aiLabel(ai.score, ai.measured), signals: ai.signals, measured: ai.measured },
    skid: { hint: skid.score, signals: skid.signals, libraries: skid.libraries, markers: skid.markers },
  };
}

/**
 * Combine the local analysis with what the online search found.
 * @param {object} analysis result of originAnalysis
 * @param {string} source
 * @param {{configured: boolean, provider?: string, matches?: {repo: string, path: string, url: string, hits: number[], lineHashes?: string[]}[], note?: string, error?: string}} online
 */
export function mergeOnline(analysis, source, online) {
  const lines = significantLines(source);
  const out = { searched: !!(online && online.configured && !online.error), provider: online && online.provider, note: online && (online.error || online.note) || null, matches: [] };
  if (online && online.matches) {
    for (const m of online.matches) {
      const cov = m.lineHashes ? coverage(lines, m.lineHashes) : null;
      out.matches.push({ repo: m.repo, path: m.path, url: m.url, fingerprintHits: m.hits.length, coverage: cov });
    }
    out.matches.sort((a, b) => (b.coverage ? b.coverage.share : 0) - (a.coverage ? a.coverage.share : 0) || b.fingerprintHits - a.fingerprintHits);
  }
  const best = out.matches[0];
  out.fingerprintsFound = online && online.matches ? new Set(online.matches.flatMap((x) => x.hits)).size : 0;
  out.fingerprintsSearched = online && online.queried || analysis.fingerprints.length;
  out.share = best && best.coverage ? best.coverage.share : null;
  out.label = !out.searched ? 'Not searched'
    : out.share === null && !out.matches.length ? 'No match found'
    : out.share !== null && out.share >= 0.7 ? 'Almost certainly copied from a public file'
    : out.share !== null && out.share >= 0.4 ? 'Large parts match a public file'
    : out.share !== null && out.share >= 0.15 ? 'Some parts match public files'
    : out.matches.length ? 'Only isolated lines match' : 'No match found';
  return out;
}
