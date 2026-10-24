// Lines as evidence of copying.
//
// A line is "significant" when it says something specific: long enough, made of more than punctuation, and not one of the
// lines every Roblox script starts with. Significant lines are what get searched for online and what coverage is counted
// over. They are compared after whitespace normalisation, and by a short hash so that a candidate file can be reduced
// to numbers before it reaches the page (the page never needs the other file's text, and the server never needs the user's).
//
// This file is shared by the browser and the serverless function; keep it free of imports.

export const normalizeLine = (s) => s.replace(/\s+/g, ' ').trim();

/** FNV-1a, 32 bit, as 8 hex digits. */
export function hashLine(s) {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i) & 0xff;
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h.toString(16).padStart(8, '0');
}

/** Lines that appear in countless scripts and prove nothing about any one of them. */
const COMMON = [
  /^local \w+ = game:GetService\(["']\w+["']\)$/,
  /^local \w+ = game\.\w+$/,
  /^local \w+ = (Players|game\.Players)\.LocalPlayer$/,
  /^local \w+ = require\(.*\)$/,
  /^if not game:IsLoaded\(\) then/,
  /^repeat task\.wait\(\) until game:IsLoaded\(\)/,
  /^game\.Loaded:Wait\(\)/,
  /^return \w+$/,
  /^local \w+ = \{\}$/,
  /^local function \w+\([\w, ]*\)$/,
  /^(end|else|do|then|repeat|break|return)\)?,?$/,
  /^--\s*[-=#*_~]{3,}\s*$/,
  /^loadstring\(game:HttpGet\(/,
];

/** Words in a line, ignoring punctuation. */
const wordsOf = (s) => (s.match(/[A-Za-z_][A-Za-z0-9_]*|\d+/g) || []);

/**
 * @param {string} source
 * @returns {{text: string, line: number, comment: boolean}[]}
 */
export function significantLines(source) {
  const out = [];
  const seen = new Set();
  const rows = source.split(/\r?\n/);
  for (let i = 0; i < rows.length; i++) {
    const text = normalizeLine(rows[i]);
    if (text.length < 16 || text.length > 400) continue;
    const comment = text.startsWith('--');
    const body = comment ? text.replace(/^--+\s*(\[=*\[)?\s*/, '') : text;
    const words = wordsOf(body);
    if (words.length < (comment ? 5 : 3)) continue;
    if (COMMON.some((re) => re.test(text))) continue;
    if (seen.has(text)) continue;
    seen.add(text);
    out.push({ text, line: i + 1, comment });
  }
  return out;
}

/**
 * How much of `lines` also appears in the candidate (a set of line hashes)?
 * @returns {{matched: number, total: number, share: number}}
 */
export function coverage(lines, candidateHashes) {
  const set = candidateHashes instanceof Set ? candidateHashes : new Set(candidateHashes);
  let matched = 0;
  for (const l of lines) if (set.has(hashLine(l.text))) matched++;
  return { matched, total: lines.length, share: lines.length ? matched / lines.length : 0 };
}

/**
 * Pick up to `count` lines worth searching for: distinctive (rare words, string literals, numbers, comments with real
 * sentences), spread over the whole file so one pasted block cannot be the only evidence.
 */
export function pickFingerprints(lines, count = 8) {
  if (!lines.length) return [];
  const score = (l) => {
    let s = Math.min(l.text.length, 120) / 120;
    const strings = l.text.match(/"[^"]{10,}"|'[^']{10,}'/g);
    if (strings) s += 1.2;
    if (l.comment) s += 0.8;
    const ids = l.text.match(/[A-Za-z_][A-Za-z0-9_]{7,}/g);
    if (ids) s += Math.min(ids.length, 3) * 0.25;
    if (/\d{3,}/.test(l.text)) s += 0.3;
    return s;
  };
  const bucketCount = Math.min(count, lines.length);
  const size = lines.length / bucketCount;
  const picked = [];
  for (let b = 0; b < bucketCount; b++) {
    const slice = lines.slice(Math.floor(b * size), Math.floor((b + 1) * size) || undefined);
    let best = null;
    for (const l of slice) if (!best || score(l) > score(best)) best = l;
    if (best) picked.push(best);
  }
  return picked;
}

/** A phrase a code search can match: the longest string literal in the line, or the line itself, without quotes. */
export function queryFor(text) {
  const strings = text.match(/"([^"]{12,})"|'([^']{12,})'/g);
  let q = text;
  if (strings) q = strings.map((s) => s.slice(1, -1)).sort((a, b) => b.length - a.length)[0];
  else if (text.startsWith('--')) q = text.replace(/^--+\s*/, '');
  return q.replace(/["\\]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 140);
}
