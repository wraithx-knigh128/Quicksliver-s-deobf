// NEXUS · Transformation Recognition, layer 1: trivia (comments and layout).
//
// Some protectors do not touch the code at all. They scatter comments through it, cut a sentence into
// pieces of a few letters each and put one piece between every two tokens, so that the text is unreadable
// and large, and so that a reader (a person, or a program that reads the file) is shown a message in
// place of the program. Comments carry no behaviour: removing them cannot change what the script does,
// and that claim can be *checked* (see `sameProgram`), which is what makes this layer different from the
// guesses elsewhere.
//
// What this module decides, from the comments alone and without a list of known tools:
//   * is this documentation a person wrote, or fragments of a text split across the file?
//   * which comments are the fragments (the others are kept)?
//   * what does the text say when put back together, and is it addressed to a program that reads the
//     file (an "instruction" planted in a comment)? That text is reported as data. It is never acted on.

import { tokenize } from '../core/lexer.js';
import { structuralKey } from '../core/walk.js';
import { parse } from '../core/parser.js';

const median = (xs) => {
  if (!xs.length) return 0;
  const s = [...xs].sort((a, b) => a - b);
  const m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};
/** The file is a binary string (one char per byte); show UTF-8 text as text. */
function displayText(s) {
  try { return new TextDecoder('utf-8', { fatal: true }).decode(Uint8Array.from(s, (c) => c.charCodeAt(0) & 255)); } catch { return s; }
}

/** A sentence that is spread over the file again and again: the first full turn, and how many turns there are. */
function firstCycle(text) {
  const probe = text.slice(0, 24);
  if (probe.length < 24) return { unit: text, repeats: 1 };
  const next = text.indexOf(probe, 24);
  if (next === -1) return { unit: text, repeats: 1 };
  return { unit: text.slice(0, next).trim(), repeats: Math.round((text.length / next) * 10) / 10 };
}
const isAlnum = (ch) => /[A-Za-z0-9]/.test(ch || '');

/** Fragments of a sentence are short; a person's comment usually is not. */
export const FRAGMENT_MAX = 24;

const ADDRESSEES = /\b(?:ai\s+(?:assistants?|agents?|models?|tools?|systems?)|assistants?\s+and\s+agents?|language\s+models?|llms?|chat\s*bots?|chatgpt|claude|copilot|gemini|gpt-?\d?)\b/i;
const COMMANDS = /\b(?:refuse|ignore|disregard|decline|forget|do\s+not|don't|must\s+not|never|stop|report\s+(?:it|this|them|the\s+user)|reject)\b/i;

/**
 * @param {string} source binary string
 * @returns {{
 *   verdict: 'none'|'documentation'|'fragmented-message',
 *   comments: number, tokens: number,
 *   metrics: object, message: string|null,
 *   directives: Array<{text: string, reason: string}>,
 *   noise: Set<number>,   // start offsets of the comments that are fragments
 * }}
 */
export function analyzeTrivia(source) {
  const { tokens, comments } = tokenize(source);
  const result = {
    verdict: 'none', comments: comments.length, tokens: tokens.length,
    metrics: { nonEmpty: 0, empty: 0, medianLength: 0, straddleRate: 0, perToken: 0, proseRatio: 0 },
    message: null, directives: [], noise: new Set(),
  };
  if (!comments.length) return result;

  const body = (c) => c.text.replace(/\r/g, '');
  const nonEmpty = comments.filter((c) => body(c).trim().length > 0);
  const empty = comments.length - nonEmpty.length;
  const lengths = nonEmpty.map((c) => body(c).trim().length);

  // A sentence cut into pieces breaks inside words: one piece ends in a letter and the next begins with one.
  let straddles = 0;
  for (let i = 0; i + 1 < nonEmpty.length; i++) {
    const a = body(nonEmpty[i]);
    const b = body(nonEmpty[i + 1]);
    if (isAlnum(a[a.length - 1]) && isAlnum(b[0])) straddles++;
  }
  const straddleRate = nonEmpty.length > 1 ? straddles / (nonEmpty.length - 1) : 0;
  // spaces between words are often a fragment of their own, so they are part of the text even though they are not "content"
  const joined = displayText(comments.filter((c) => c.text.length > 0).map(body).join('').replace(/\s+/g, ' ').trim());
  const { unit: message, repeats } = firstCycle(joined);
  const proseChars = (message.match(/[A-Za-z .,;:'"!?()\-—]/g) || []).length;
  const proseRatio = message.length ? proseChars / message.length : 0;
  const m = { nonEmpty: nonEmpty.length, empty, medianLength: median(lengths), straddleRate, perToken: comments.length / Math.max(1, tokens.length), proseRatio };
  result.metrics = m;

  const fragmented = nonEmpty.length >= 12 && m.medianLength <= FRAGMENT_MAX && straddleRate >= 0.35 && m.perToken >= 0.02 && proseRatio >= 0.85;
  result.verdict = fragmented ? 'fragmented-message' : 'documentation';
  if (fragmented) {
    result.message = message;
    result.metrics.repeats = repeats;
    for (const c of comments) if (body(c).trim().length <= FRAGMENT_MAX) result.noise.add(c.start);
  }

  // Text addressed to a program that reads the file. Looked for in the reassembled message and in every comment on its own.
  const texts = [];
  if (fragmented) texts.push(message);
  for (const c of nonEmpty) if (body(c).trim().length > FRAGMENT_MAX) texts.push(body(c));
  const seen = new Set();
  for (const t of texts) {
    for (const sentence of t.split(/(?<=[.!?])\s+|\n+/)) {
      if (ADDRESSEES.test(sentence) && COMMANDS.test(sentence)) {
        const text = sentence.trim().slice(0, 200);
        if (!seen.has(text)) { seen.add(text); result.directives.push({ text, reason: 'a comment addresses AI tools and tells them to refuse, ignore or report' }); }
      }
    }
  }
  return result;
}

/** Remove the comments whose start offsets are in `starts` from a parsed program (in place). Returns how many were removed. */
export function stripComments(ast, starts) {
  let removed = 0;
  const keep = (list) => {
    if (!Array.isArray(list)) return list;
    const out = list.filter((c) => !starts.has(c.start));
    removed += list.length - out.length;
    return out;
  };
  const visit = (node) => {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) {
      if (node.endComments) { const k = keep(node.endComments); node.endComments = k; }
      for (const n of node) visit(n);
      return;
    }
    if (node.comments) { const k = keep(node.comments); node.comments = k.length ? k : undefined; }
    if (node.trailing && starts.has(node.trailing.start)) { node.trailing = undefined; removed++; }
    if (node.endComments) node.endComments = keep(node.endComments);
    for (const k of Object.keys(node)) {
      if (k === 'comments' || k === 'trailing' || k === 'endComments') continue;
      visit(node[k]);
    }
  };
  visit(ast);
  return removed;
}

/**
 * Do two texts hold the same program? True when their syntax trees are identical once layout and comments are ignored.
 * This is the check behind the claim "removing the comments changed nothing": it compares trees, not output text.
 */
export function sameProgram(a, b) {
  try { return structuralKey(parse(a)) === structuralKey(parse(b)); } catch { return false; }
}
