// Lua 5.1 - 5.4 and Luau lexer.
//
// Works on a binary string (see bytes.js). Comments are not discarded: they are attached to the
// token that follows them (`token.comments`) so the formatter can keep them. The lexer accepts the
// union of the dialects; deciding what is legal for a given dialect is the parser's / validator's job.

import { encodeCodePoint } from './bytes.js';

export class LuaSyntaxError extends Error {
  constructor(message, pos, line, col) {
    super(`${line}:${col}: ${message}`);
    this.name = 'LuaSyntaxError';
    this.pos = pos;
    this.line = line;
    this.col = col;
  }
}

export const KEYWORDS = new Set([
  'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in',
  'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while',
]);

// Longest operators first so that greedy matching works by simple prefix tests.
const OPERATORS = [
  '...', '..=', '//=',
  '..', '==', '~=', '<=', '>=', '//', '::', '<<', '>>', '->', '+=', '-=', '*=', '/=', '%=', '^=',
  '+', '-', '*', '/', '%', '^', '#', '&', '~', '|', '<', '>', '=', '(', ')', '{', '}', '[', ']',
  ';', ':', ',', '.', '?', '@',
];

const isDigit = (c) => c >= 48 && c <= 57;
const isHex = (c) => isDigit(c) || (c >= 97 && c <= 102) || (c >= 65 && c <= 70);
const isIdentStart = (c) => (c >= 97 && c <= 122) || (c >= 65 && c <= 90) || c === 95 || c >= 128;
const isIdentPart = (c) => isIdentStart(c) || isDigit(c);
const isSpace = (c) => c === 32 || (c >= 9 && c <= 13);

/**
 * @param {string} src binary string
 * @returns {{tokens: Array, comments: Array}}
 */
export function tokenize(src) {
  const tokens = [];
  const comments = [];
  const n = src.length;
  let i = 0;
  let line = 1;
  let lineStart = 0;
  let pending = [];

  const fail = (msg, at = i) => {
    throw new LuaSyntaxError(msg, at, line, at - lineStart + 1);
  };
  const newline = (at) => {
    line++;
    lineStart = at + 1;
  };

  // "[==[" at position p -> level (number of '='), or -1 if not a long-bracket opener.
  const longBracketLevel = (p) => {
    if (src.charCodeAt(p) !== 91) return -1;
    let q = p + 1;
    while (src.charCodeAt(q) === 61) q++;
    return src.charCodeAt(q) === 91 ? q - p - 1 : -1;
  };

  const readLongBody = (level, bodyStart, what) => {
    const close = ']' + '='.repeat(level) + ']';
    const end = src.indexOf(close, bodyStart);
    if (end === -1) fail(`unfinished long ${what}`, bodyStart);
    for (let k = bodyStart; k < end; k++) if (src.charCodeAt(k) === 10) newline(k);
    return { body: src.slice(bodyStart, end), next: end + close.length };
  };

  const push = (tok) => {
    tok.comments = pending.length ? pending : null;
    tok.endLine = line;
    pending = [];
    tokens.push(tok);
  };

  // Shebang line.
  if (src.charCodeAt(0) === 35 && src.charCodeAt(1) === 33) {
    while (i < n && src.charCodeAt(i) !== 10) i++;
  }

  while (i < n) {
    const c = src.charCodeAt(i);

    if (c === 10) { newline(i); i++; continue; }
    if (isSpace(c)) { i++; continue; }

    // Comments
    if (c === 45 && src.charCodeAt(i + 1) === 45) {
      const start = i;
      const startLine = line;
      i += 2;
      const level = longBracketLevel(i);
      let text;
      let kind;
      if (level >= 0) {
        const { body, next } = readLongBody(level, i + level + 2, 'comment');
        text = body;
        kind = 'block';
        i = next;
      } else {
        const e = src.indexOf('\n', i);
        const stop = e === -1 ? n : e;
        text = src.slice(i, stop);
        kind = 'line';
        i = stop;
      }
      const cm = { kind, text, level: Math.max(level, 0), start, end: i, line: startLine, endLine: line };
      comments.push(cm);
      pending.push(cm);
      continue;
    }

    const start = i;
    const startLine = line;
    const col = i - lineStart + 1;

    // Names and keywords
    if (isIdentStart(c)) {
      i++;
      while (i < n && isIdentPart(src.charCodeAt(i))) i++;
      const word = src.slice(start, i);
      push({ t: KEYWORDS.has(word) ? 'keyword' : 'name', v: word, start, end: i, line: startLine, col });
      continue;
    }

    // Numbers (decimal, hex incl. hex floats, Luau binary and _ separators)
    if (isDigit(c) || (c === 46 && isDigit(src.charCodeAt(i + 1)))) {
      let value;
      const c1 = src.charCodeAt(i + 1);
      if (c === 48 && (c1 === 120 || c1 === 88)) {
        i += 2;
        let mant = 0;
        let exp = 0;
        let seenDot = false;
        let digits = 0;
        while (i < n) {
          const d = src.charCodeAt(i);
          if (isHex(d)) { mant = mant * 16 + parseInt(src[i], 16); if (seenDot) exp -= 4; digits++; i++; }
          else if (d === 95) i++;
          else if (d === 46 && !seenDot) { seenDot = true; i++; }
          else break;
        }
        if (digits === 0) fail('malformed number', start);
        const p = src.charCodeAt(i);
        if (p === 112 || p === 80) {
          i++;
          let sign = 1;
          if (src.charCodeAt(i) === 43) i++;
          else if (src.charCodeAt(i) === 45) { sign = -1; i++; }
          let e = 0;
          if (!isDigit(src.charCodeAt(i))) fail('malformed number', start);
          while (isDigit(src.charCodeAt(i))) { e = e * 10 + (src.charCodeAt(i) - 48); i++; }
          exp += sign * e;
        }
        value = mant * Math.pow(2, exp);
      } else if (c === 48 && (c1 === 98 || c1 === 66)) {
        i += 2;
        let v = 0;
        let digits = 0;
        while (src.charCodeAt(i) === 48 || src.charCodeAt(i) === 49 || src.charCodeAt(i) === 95) {
          if (src.charCodeAt(i) !== 95) { v = v * 2 + (src.charCodeAt(i) - 48); digits++; }
          i++;
        }
        if (digits === 0) fail('malformed number', start);
        value = v;
      } else {
        while (i < n && (isDigit(src.charCodeAt(i)) || src.charCodeAt(i) === 95)) i++;
        if (src.charCodeAt(i) === 46 && src.charCodeAt(i + 1) !== 46) {
          i++;
          while (i < n && (isDigit(src.charCodeAt(i)) || src.charCodeAt(i) === 95)) i++;
        }
        const e = src.charCodeAt(i);
        if (e === 101 || e === 69) {
          let j = i + 1;
          if (src.charCodeAt(j) === 43 || src.charCodeAt(j) === 45) j++;
          if (isDigit(src.charCodeAt(j))) {
            while (isDigit(src.charCodeAt(j))) j++;
            i = j;
          }
        }
        value = Number(src.slice(start, i).replace(/_/g, ''));
      }
      if (i < n && isIdentStart(src.charCodeAt(i))) fail('malformed number', start);
      push({ t: 'number', v: value, raw: src.slice(start, i), start, end: i, line: startLine, col });
      continue;
    }

    // Short strings
    if (c === 34 || c === 39) {
      const quote = c;
      i++;
      let out = '';
      for (;;) {
        if (i >= n) fail('unfinished string', start);
        const d = src.charCodeAt(i);
        if (d === quote) { i++; break; }
        if (d === 10) fail('unfinished string', start);
        if (d !== 92) { out += src[i]; i++; continue; }
        i++;
        const e = src.charCodeAt(i);
        switch (e) {
          case 110: out += '\n'; i++; break;
          case 116: out += '\t'; i++; break;
          case 114: out += '\r'; i++; break;
          case 97: out += '\x07'; i++; break;
          case 98: out += '\b'; i++; break;
          case 102: out += '\f'; i++; break;
          case 118: out += '\v'; i++; break;
          case 92: out += '\\'; i++; break;
          case 34: out += '"'; i++; break;
          case 39: out += "'"; i++; break;
          case 10: out += '\n'; newline(i); i++; break;
          case 13: out += '\n'; i++; if (src.charCodeAt(i) === 10) { newline(i); i++; } break;
          case 120: { // \xXX
            if (!isHex(src.charCodeAt(i + 1)) || !isHex(src.charCodeAt(i + 2))) fail('invalid \\x escape', i);
            out += String.fromCharCode(parseInt(src.substr(i + 1, 2), 16));
            i += 3;
            break;
          }
          case 122: { // \z skips following whitespace
            i++;
            while (i < n && isSpace(src.charCodeAt(i))) { if (src.charCodeAt(i) === 10) newline(i); i++; }
            break;
          }
          case 117: { // \u{XXX}
            if (src.charCodeAt(i + 1) !== 123) fail('invalid \\u escape', i);
            let j = i + 2;
            let cp = 0;
            let digits = 0;
            while (isHex(src.charCodeAt(j))) { cp = cp * 16 + parseInt(src[j], 16); j++; digits++; }
            if (digits === 0 || src.charCodeAt(j) !== 125 || cp > 0x7fffffff) fail('invalid \\u escape', i);
            out += encodeCodePoint(cp);
            i = j + 1;
            break;
          }
          default:
            if (isDigit(e)) {
              let j = i;
              let v = 0;
              while (j < i + 3 && isDigit(src.charCodeAt(j))) { v = v * 10 + (src.charCodeAt(j) - 48); j++; }
              if (v > 255) fail('decimal escape too large', i);
              out += String.fromCharCode(v);
              i = j;
            } else if (Number.isNaN(e)) {
              fail('unfinished string', start);
            } else {
              out += src[i]; // Lua 5.1 treats an unknown escape as the character itself
              i++;
            }
        }
      }
      push({ t: 'string', v: out, raw: src.slice(start, i), long: false, quote: String.fromCharCode(quote), start, end: i, line: startLine, col });
      continue;
    }

    // Long strings
    if (c === 91) {
      const level = longBracketLevel(i);
      if (level >= 0) {
        let bodyStart = i + level + 2;
        if (src.charCodeAt(bodyStart) === 13) { bodyStart++; if (src.charCodeAt(bodyStart) === 10) bodyStart++; }
        else if (src.charCodeAt(bodyStart) === 10) bodyStart++;
        const skippedNewline = bodyStart - (i + level + 2);
        if (skippedNewline) line++;
        const { body, next } = readLongBody(level, bodyStart, 'string');
        i = next;
        push({ t: 'string', v: body.replace(/\r\n?/g, '\n'), raw: src.slice(start, i), long: true, level, start, end: i, line: startLine, col });
        continue;
      }
    }

    // Luau interpolated string: `text {expr} text`
    if (c === 96) {
      i++;
      const parts = [];
      let text = '';
      for (;;) {
        if (i >= n) fail('unfinished interpolated string', start);
        const d = src.charCodeAt(i);
        if (d === 96) { i++; break; }
        if (d === 92) {
          const e = src[i + 1];
          const map = { n: '\n', t: '\t', r: '\r', '`': '`', '{': '{', '\\': '\\', "'": "'", '"': '"' };
          text += e in map ? map[e] : e;
          i += 2;
          continue;
        }
        if (d === 123) {
          let depth = 1;
          let j = i + 1;
          while (j < n && depth > 0) {
            const x = src.charCodeAt(j);
            if (x === 123) depth++;
            else if (x === 125) depth--;
            else if (x === 10) newline(j);
            j++;
          }
          if (depth !== 0) fail('unfinished interpolation', i);
          if (text) parts.push({ text });
          text = '';
          parts.push({ source: src.slice(i + 1, j - 1), offset: i + 1 });
          i = j;
          continue;
        }
        if (d === 10) newline(i);
        text += src[i];
        i++;
      }
      if (text) parts.push({ text });
      push({ t: 'interp', parts, raw: src.slice(start, i), start, end: i, line: startLine, col });
      continue;
    }

    // Operators and punctuation
    let matched = null;
    for (const op of OPERATORS) {
      if (src.startsWith(op, i)) { matched = op; break; }
    }
    if (!matched) fail(`unexpected character '${src[i]}' (0x${c.toString(16)})`);
    i += matched.length;
    push({ t: 'op', v: matched, start, end: i, line: startLine, col });
  }

  push({ t: 'eof', v: '<eof>', start: n, end: n, line, col: i - lineStart + 1 });
  return { tokens, comments };
}
