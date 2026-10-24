// Style signals: does this read like code an assistant wrote, and does it read like code several people wrote?
//
// Everything here is an indicator, never proof. Each signal is measured, shown with its value and the reason it counts,
// and combined with fixed, visible weights, so the person reading the report can disagree with any single line of it. The
// weights were set by hand and checked against a small number of human-written and assistant-written Lua files (see
// tests/origin.test.mjs); they have NOT been validated on a large labelled data set, and short scripts carry little
// signal at all. Nothing here searches the internet: authorship cannot be read off a search result. What can be searched
// for is whether the same lines already exist elsewhere (see src/origin/lines.js and api/origin.js).

import { tokenize } from '../core/lexer.js';

const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
const pct = (x) => `${Math.round(x * 100)}%`;

/** Split an identifier into lowercase words: fooBar_baz2 -> foo bar baz. */
const wordsOfName = (name) => name.replace(/([a-z0-9])([A-Z])/g, '$1 $2').replace(/_+/g, ' ').toLowerCase().split(/\s+/).filter((w) => /[a-z]/.test(w));
const contentWords = (text) => new Set(wordsOfName(text.replace(/[^A-Za-z0-9_ ]/g, ' ')).filter((w) => w.length >= 3));

// ---- source model -------------------------------------------------------------------------------------------------------

function model(source) {
  const rows = source.split(/\r?\n/);
  let tokens = [];
  let comments = [];
  try { ({ tokens, comments } = tokenize(source)); } catch { /* an unparseable script still has lines */ }

  const commentLineSet = new Set();
  for (const c of comments) for (let l = c.line; l <= c.endLine; l++) commentLineSet.add(l);
  const codeLineSet = new Set();
  for (const t of tokens) { codeLineSet.add(t.line); }
  const nonEmpty = rows.filter((r) => r.trim()).length;
  const lineComments = comments.filter((c) => c.kind === 'line');

  // names declared with `local` and function parameters
  const locals = [];
  const funcs = [];
  for (let i = 0; i < tokens.length; i++) {
    const t = tokens[i];
    if (t.t === 'keyword' && t.v === 'local') {
      let j = i + 1;
      if (tokens[j] && tokens[j].v === 'function' && tokens[j + 1] && tokens[j + 1].t === 'name') { funcs.push({ name: tokens[j + 1].v, line: tokens[j + 1].line }); continue; }
      while (tokens[j] && tokens[j].t === 'name') {
        locals.push(tokens[j].v);
        j++;
        if (tokens[j] && tokens[j].v === ',') j++; else break;
      }
    } else if (t.t === 'keyword' && t.v === 'function') {
      let j = i + 1;
      const parts = [];
      while (tokens[j] && (tokens[j].t === 'name' || tokens[j].v === '.' || tokens[j].v === ':')) { parts.push(tokens[j].v); j++; }
      if (parts.length) funcs.push({ name: parts.join(''), line: t.line });
      if (tokens[j] && tokens[j].v === '(') {
        j++;
        while (tokens[j] && tokens[j].v !== ')') { if (tokens[j].t === 'name') locals.push(tokens[j].v); j++; }
      }
    }
  }
  return {
    rows, tokens, comments, lineComments, locals, funcs, nonEmpty,
    commentLines: commentLineSet.size,
    codeLines: codeLineSet.size,
  };
}

// ---- AI-style signals ---------------------------------------------------------------------------------------------------

/** Each returns { id, label, value, strength (-1 human .. +1 assistant), weight, why } or null when there is nothing to measure. */
const AI_SIGNALS = [
  function commentDensity(m) {
    if (m.nonEmpty < 20) return null;
    const r = m.commentLines / m.nonEmpty;
    const s = r >= 0.25 ? 1 : r >= 0.15 ? 0.6 : r >= 0.08 ? 0.2 : r >= 0.03 ? -0.2 : -0.8;
    return { id: 'comment-density', label: 'Comment density', value: `${pct(r)} of lines are comments`, strength: s, weight: 1.0,
      why: 'Assistants comment generously and evenly; scripts written by hand are usually sparse or erratic.' };
  },

  function restatingComments(m) {
    const pairs = [];
    for (const c of m.lineComments) {
      const words = contentWords(c.text);
      if (words.size < 2) continue;
      const next = m.rows.slice(c.line, c.line + 2).join(' ');
      if (!next.trim() || next.trim().startsWith('--')) continue;
      pairs.push([words, contentWords(next)]);
    }
    if (pairs.length < 6) return null;
    const restating = pairs.filter(([a, b]) => [...a].filter((w) => b.has(w)).length >= 2).length;
    const f = restating / pairs.length;
    const s = f >= 0.5 ? 1 : f >= 0.3 ? 0.5 : f >= 0.15 ? 0 : -0.3;
    return { id: 'restating-comments', label: 'Comments that restate the next line', value: `${restating} of ${pairs.length} (${pct(f)})`, strength: s, weight: 1.2,
      why: '"-- Get the Players service" above `local Players = game:GetService("Players")` is typical of generated code; people comment the why, not the what.' };
  },

  function docAnnotations(m, source) {
    const ann = (source.match(/^\s*---\s*@(param|return|class|field|type|alias)\b/gm) || []).length;
    const funcs = Math.max(1, m.funcs.length);
    if (ann < 3) return ann ? null : null;
    const r = ann / funcs;
    return { id: 'doc-annotations', label: 'Doc annotations', value: `${ann} @param/@return lines for ${m.funcs.length} functions`, strength: r >= 0.8 ? 1 : 0.4, weight: 0.8,
      why: 'Full EmmyLua-style documentation on every function is common in generated code and rare in quick scripts.' };
  },

  function headerBlock(m) {
    const first = m.comments.find((c) => c.line <= 6);
    if (!first) return null;
    const text = first.text;
    const hits = (text.match(/\b(author|version|description|usage|features?|license|changelog|requirements?)\b/gi) || []).length;
    if (hits < 2 || (first.endLine - first.line) < 3) return null;
    return { id: 'header-block', label: 'Documentation header', value: `${hits} headings (${(text.match(/\b(author|version|description|usage|features?|license)\b/gi) || []).slice(0, 4).join(', ')})`, strength: 0.6, weight: 0.5,
      why: 'A structured header (Description, Features, Usage) at the top is a habit of generated files.' };
  },

  function descriptiveNames(m) {
    const names = [...new Set(m.locals.filter((n) => n.length > 1 && n !== '_'))];
    if (names.length < 6) return null;
    const multi = names.filter((n) => wordsOfName(n).length >= 2).length / names.length;
    const avg = names.reduce((a, n) => a + n.length, 0) / names.length;
    const s = (multi >= 0.7 ? 0.8 : multi >= 0.5 ? 0.3 : multi >= 0.25 ? -0.2 : -0.7) + (avg >= 9 ? 0.2 : avg <= 5 ? -0.2 : 0);
    return { id: 'descriptive-names', label: 'Descriptive names', value: `${pct(multi)} of local names are two or more words, average length ${avg.toFixed(1)}`, strength: clamp(s, -1, 1), weight: 1.0,
      why: 'Long multi-word names (playerCharacterHumanoid) are how assistants name things; hand-written scripts lean on short ones.' };
  },

  function consistentNaming(m) {
    const multi = [...new Set(m.locals)].filter((n) => wordsOfName(n).length >= 2);
    if (multi.length < 8) return null;
    const snake = multi.filter((n) => n.includes('_')).length;
    const dominant = Math.max(snake, multi.length - snake) / multi.length;
    const s = dominant >= 0.97 ? 0.4 : dominant < 0.8 ? -0.6 : 0;
    return { id: 'naming-consistency', label: 'One naming convention throughout', value: `${pct(dominant)} follow the same convention`, strength: s, weight: 0.8,
      why: 'Perfectly uniform naming is typical of one author in one sitting; mixed conventions suggest edits by hand or several authors.' };
  },

  function defensiveCode(m, source) {
    if (m.codeLines < 30) return null;
    const count = (re) => (source.match(re) || []).length;
    const n = count(/\bpcall\s*\(/g) + count(/\bwarn\s*\(/g) + count(/\bassert\s*\(/g) + count(/\bif\s+not\s+[\w.:()]+\s+then\s+return\b/g) + count(/\btype(of)?\s*\([^)]*\)\s*~=\s*["']/g);
    const d = (n / m.codeLines) * 100;
    const s = d >= 6 ? 1 : d >= 3 ? 0.5 : d >= 1 ? 0 : -0.3;
    return { id: 'defensive-code', label: 'Defensive checks', value: `${n} pcall / warn / assert / guard clauses (${d.toFixed(1)} per 100 lines)`, strength: s, weight: 0.9,
      why: 'Guard clauses, type checks and pcall around everything are common in generated code; quick scripts rarely bother.' };
  },

  function moduleTemplate(m, source) {
    const tables = [...source.matchAll(/^local\s+([A-Z]\w*)\s*=\s*\{\s*\}/gm)].map((x) => x[1]);
    const hit = tables.filter((t) => new RegExp(`\\bfunction\\s+${t}[.:]\\w+`).test(source) && new RegExp(`return\\s+${t}\\b`).test(source));
    if (!hit.length || m.funcs.length < 3) return null;
    return { id: 'module-template', label: 'Module template', value: `local ${hit[0]} = {} ... function ${hit[0]}.x ... return ${hit[0]}`, strength: 0.5, weight: 0.5,
      why: 'The table-of-functions module layout with a trailing return is a standard shape for generated Luau.' };
  },

  function emoji(m, source) {
    const matches = source.match(/\xF0\x9F[\x80-\xBF]{2}|\xE2\x9C[\x85\x94\x93]|\xE2\x9D[\x8C\x8E]|\xE2\x9A[\xA0\xA1]|\xE2\x9E[\xA1]|\xE2\xAD\x90/g) || [];
    if (!matches.length) return null;
    return { id: 'emoji', label: 'Emoji in messages or comments', value: `${matches.length} found`, strength: matches.length >= 3 ? 1 : 0.8, weight: 1.1,
      why: 'Check marks and rockets in print() messages are a strong habit of generated code.' };
  },

  function tidyEnglish(m) {
    const cs = m.lineComments.map((c) => c.text.trim()).filter((t) => t.split(/\s+/).length >= 3);
    if (cs.length < 6) return null;
    const tidy = cs.filter((t) => /^[A-Z]/.test(t) && /[.:]$/.test(t)).length / cs.length;
    const s = tidy >= 0.6 ? 0.6 : tidy >= 0.3 ? 0.2 : tidy < 0.1 ? -0.5 : 0;
    return { id: 'tidy-english', label: 'Comments as full sentences', value: `${pct(tidy)} start with a capital and end with a full stop`, strength: s, weight: 0.7,
      why: 'People write comment fragments in lower case; assistants write complete sentences.' };
  },

  function exampleUsage(m, source) {
    const n = (source.match(/^\s*--+\s*(example usage|usage|example)\s*:?/gim) || []).length;
    if (!n) return null;
    return { id: 'example-usage', label: '"Example usage" block', value: `${n} found`, strength: 0.6, weight: 0.5,
      why: 'Generated files often end with a commented example of how to call what they define.' };
  },

  function prefixedLogging(m, source) {
    const n = (source.match(/\b(print|warn)\s*\(\s*["']\[\w[\w ]*\]/g) || []).length;
    if (n < 3) return null;
    return { id: 'prefixed-logging', label: 'Tagged log messages', value: `${n} print/warn calls start with [Tag]`, strength: 0.5, weight: 0.5,
      why: 'print("[Module] ...") on every message is a pattern assistants repeat.' };
  },

  function humanNoise(m, source) {
    const out = [];
    let strength = 0;
    const commentedCode = m.lineComments.filter((c) => /^\s*(local\s+\w+\s*=|\w+(\.\w+)*\s*\(.*\)\s*$|end\b|if\s.+\sthen\b|for\s.+\sdo\b)/.test(c.text) && !/[A-Za-z]{4,}\s+[A-Za-z]{4,}\s+[A-Za-z]{4,}/.test(c.text)).length;
    if (commentedCode >= 3) { strength -= 0.8; out.push(`${commentedCode} commented-out code lines`); } else if (commentedCode >= 1) { strength -= 0.3; out.push(`${commentedCode} commented-out code line(s)`); }
    const trailing = m.rows.filter((r) => /[ \t]+$/.test(r) && r.trim()).length / Math.max(1, m.nonEmpty);
    if (trailing >= 0.05) { strength -= 0.4; out.push(`trailing spaces on ${pct(trailing)} of lines`); }
    const tabs = m.rows.filter((r) => /^\t/.test(r)).length;
    const spaces = m.rows.filter((r) => /^ {2,}\S/.test(r)).length;
    if (tabs >= 3 && spaces >= 3) { strength -= 0.5; out.push('tabs and spaces both used for indentation'); }
    const tight = (source.match(/\w=\w/g) || []).length;
    const loose = (source.match(/\w = \w/g) || []).length;
    if (tight >= 3 && loose >= 3) { strength -= 0.4; out.push('assignments written both `a=b` and `a = b`'); }
    const debug = (source.match(/\bprint\s*\(\s*(["'](here|test|hi|wtf|works?|1|2|3|ok|a|b|asd\w*)["']|\d+)\s*\)/gi) || []).length;
    if (debug) { strength -= 0.6; out.push(`${debug} leftover debug print(s)`); }
    if (m.codeLines < 15 && !out.length) return null;
    if (!out.length) return { id: 'human-noise', label: 'Signs of editing by hand', value: 'none found', strength: 0.3, weight: 1.0, why: 'Commented-out code, mixed indentation, stray debug prints: the mess of editing by hand. None here.' };
    return { id: 'human-noise', label: 'Signs of editing by hand', value: out.join('; '), strength: clamp(strength, -1, 0), weight: 1.0,
      why: 'Commented-out code, mixed indentation and leftover debug prints are the mess of editing by hand; assistants rarely leave them.' };
  },
];

const sigmoid = (x) => 1 / (1 + Math.exp(-x));

export function aiStyle(m, source) {
  const signals = AI_SIGNALS.map((f) => f(m, source)).filter(Boolean);
  const z = signals.reduce((a, s) => a + s.strength * s.weight, 0);
  // A neutral script (z around 0) scores about a third; five or six assistant-style tells push it past three quarters.
  let p = sigmoid(0.95 * (z - 0.8));
  const measured = signals.length;
  // few measurable signals: pull towards "cannot tell"
  if (measured < 4) p = 0.5 + (p - 0.5) * (measured / 4);
  p = clamp(p, 0.04, 0.92);
  return { score: p, signals, measured };
}

export const aiLabel = (p, measured) => {
  if (measured < 2) return 'Not enough to judge';
  if (p < 0.2) return 'Looks hand-written';
  if (p < 0.4) return 'Probably hand-written';
  if (p < 0.6) return 'Unclear';
  if (p < 0.8) return 'Likely AI-assisted';
  return 'Very likely AI-written';
};

// ---- other-author hints -------------------------------------------------------------------------------------------------

const LIBRARIES = [
  { name: 'Rayfield', re: /\bRayfield\b/ },
  { name: 'Orion Library', re: /\bOrion(Lib|Library| Library)\b/ },
  { name: 'Kavo UI', re: /\bKavo(Lib|Library| UI)?\b/ },
  { name: 'Fluent', re: /\bFluent\b[\s\S]{0,400}(SaveManager|InterfaceManager|CreateWindow)/ },
  { name: 'Linoria', re: /\bLinoria\b|\bLibrary:CreateWindow\b[\s\S]{0,300}\bToggles\b/ },
  { name: 'Venyx', re: /\bVenyx\b/ },
  { name: 'Infinite Yield', re: /\bInfinite ?Yield\b/i },
  { name: 'Dex Explorer', re: /\b(Dark ?Dex|Dex ?Explorer)\b/i },
  { name: 'SimpleSpy', re: /\bSimple ?Spy\b/i },
  { name: 'Hydroxide', re: /\bHydroxide\b/ },
];

const PROVENANCE = [
  { kind: 'credit', re: /\b(credits?(?: to)?|made by|created by|script by|written by|developed by|originally by|original (?:script|author)|ported (?:by|from)|skid(?:ded)? from|copied from)\b[^\n]{0,80}/i },
  { kind: 'invite', re: /\b(discord\.gg\/[A-Za-z0-9-]+|discord(?:app)?\.com\/invite\/[A-Za-z0-9-]+)/i },
  { kind: 'community', re: /\b(v3rmillion|vermillion|wearedevs|rbxscripts|scriptblox|rscripts|robloxscripts)\b/i },
  { kind: 'link', re: /\b(github\.com|gist\.github\.com|pastebin\.com|rentry\.co|paste\.ee|raw\.githubusercontent\.com)\/[^\s"')]+/i },
];

/** Windows of code compared for style: do the dominant habits change partway through? */
function patchwork(m) {
  const code = m.rows.filter((r) => r.trim() && !/^\s*--/.test(r));
  const size = 12;
  if (code.length < 60) return null;
  const windows = [];
  for (let at = 0; at + size <= code.length; at += size) windows.push(code.slice(at, at + size));
  const dims = {
    // tabs, or the usual step between one indentation level and the next
    indent: (w) => {
      const tabs = w.filter((r) => /^\t/.test(r)).length;
      if (tabs > w.length / 3) return 'tab';
      const steps = new Map();
      let prev = 0;
      for (const r of w) {
        const n = (r.match(/^ */) || [''])[0].length;
        if (n > prev) steps.set(n - prev, (steps.get(n - prev) || 0) + 1);
        prev = n;
      }
      if (!steps.size) return 'none';
      const [unit, count] = [...steps].sort((a, b) => b[1] - a[1])[0];
      return count >= 2 ? `space${unit}` : 'none';
    },
    quotes: (w) => { const t = w.join('\n'); const d = (t.match(/"/g) || []).length; const q = (t.match(/'/g) || []).length; return d + q < 4 ? 'none' : d >= q ? 'double' : 'single'; },
    naming: (w) => { const t = w.join('\n'); const sn = (t.match(/\blocal\s+[a-z]+_[a-z_]+/g) || []).length; const cm = (t.match(/\blocal\s+[a-z]+[A-Z]\w*/g) || []).length; return sn + cm < 2 ? 'none' : sn > cm ? 'snake' : 'camel'; },
    spacing: (w) => { const t = w.join('\n'); const tight = (t.match(/\w=\w/g) || []).length; const loose = (t.match(/\w = \w/g) || []).length; return tight + loose < 3 ? 'none' : tight > loose ? 'tight' : 'loose'; },
  };
  // how far a dimension has to disagree between windows before it counts as a change of hands
  const needs = { indent: 0.3, naming: 0.45, quotes: 0.45, spacing: 0.4 };
  let strongest = 0;
  const details = [];
  for (const [name, f] of Object.entries(dims)) {
    const vals = windows.map(f).filter((v) => v !== 'none');
    if (vals.length < (name === 'indent' ? 3 : 5)) continue;
    const counts = new Map();
    vals.forEach((v) => counts.set(v, (counts.get(v) || 0) + 1));
    const d = 1 - Math.max(...counts.values()) / vals.length;
    if (d >= needs[name]) { details.push(`${name}: ${[...counts].map(([k, v]) => `${k} ×${v}`).join(', ')}`); strongest = Math.max(strongest, d); }
  }
  if (!details.length) return null;
  return { score: strongest, details, windows: windows.length };
}

export function skidHints(m, source) {
  const signals = [];
  const found = [];
  for (const p of PROVENANCE) {
    for (let i = 0; i < m.rows.length; i++) {
      const hit = m.rows[i].match(p.re);
      if (!hit) continue;
      if (p.kind === 'link' && /loadstring|HttpGet/.test(m.rows[i])) continue;       // loading a library is not a credit
      found.push({ kind: p.kind, line: i + 1, text: hit[0].trim().slice(0, 120) });
      if (found.length > 40) break;
    }
  }
  if (found.length) {
    const kinds = [...new Set(found.map((f) => f.kind))];
    signals.push({ id: 'provenance', label: 'Names, invites and links left in the text', value: `${found.length} (${kinds.join(', ')})`, strength: clamp(0.3 + 0.1 * (found.length - 1), 0.3, 0.6),
      why: 'Credit lines, Discord invites and links to other people\'s pages mean other authors are involved. They do not say how much was copied.', items: found.slice(0, 8) });
  }
  const libs = LIBRARIES.filter((l) => l.re.test(source)).map((l) => l.name);
  if (libs.length) signals.push({ id: 'libraries', label: 'Public libraries used or embedded', value: libs.join(', '), strength: 0.15,
    why: 'Using a public UI library or tool is normal. It only matters if the library itself is passed off as new work.' });
  const pw = patchwork(m);
  if (pw && pw.score >= 0.3) signals.push({ id: 'patchwork', label: 'Style changes partway through', value: pw.details.join('; ') || `${pct(pw.score)} disagreement`, strength: clamp(pw.score, 0.2, 0.6),
    why: 'Indentation, quotes and naming that switch between parts of a file are what pasting together code from different people looks like.' });
  const hint = 1 - signals.reduce((a, s) => a * (1 - s.strength), 1);
  return { score: hint, signals, libraries: libs, markers: found };
}
export { model };
