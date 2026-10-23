// Fallback formatter for code that does not parse (a partial paste, a truncated file, syntax the parser
// rejects). It works on the token stream, so strings and comments are never altered, and it only inserts
// whitespace: re-tokenising its output always gives exactly the tokens it was given. It cannot know that
// the code is well formed, which is why the API reports it as a separate mode ("tokens").

import { tokenize, LuaSyntaxError } from './lexer.js';

const BREAK_BEFORE = new Set(['local', 'if', 'for', 'while', 'repeat', 'return', 'break', 'goto', 'end', 'else', 'elseif', 'until']);
const NO_SPACE_BEFORE = new Set([',', ';', ')', ']', '}', '.', ':', '::', '?']);
const NO_SPACE_AFTER = new Set(['(', '[', '{', '.', ':', '#', '::', '@']);
const CLOSERS = new Set([')', ']', '}']);
const VALUE_WORDS = new Set(['end', 'true', 'false', 'nil', '...']);

/** Does this token finish an expression or a block (so that a following name starts a new statement)? */
const endsValue = (t) => !!t && (t.t === 'name' || t.t === 'number' || t.t === 'string' || t.t === 'interp'
  || (t.t === 'op' && CLOSERS.has(t.v)) || (t.t === 'keyword' && VALUE_WORDS.has(t.v)));

/**
 * @param {string} src binary string
 * @returns {string | null} formatted source, or null when even the lexer cannot read it
 */
export function formatTokens(src, { indent = '  ' } = {}) {
  let tokens;
  try {
    ({ tokens } = tokenize(src));
  } catch (e) {
    if (e instanceof LuaSyntaxError) return null;
    throw e;
  }

  let out = '';
  let depth = 0;
  let lineStart = true;
  let prev = null;
  let prevUnaryMinus = false;
  let parens = 0;
  const newline = () => { if (!out.endsWith('\n')) out += '\n'; lineStart = true; };

  for (const t of tokens) {
    if (t.t === 'eof') break;

    for (const c of t.comments || []) {
      if (!lineStart) newline();
      out += indent.repeat(depth) + (c.kind === 'line' ? `--${c.text}` : `--[${'='.repeat(c.level)}[${c.text}]${'='.repeat(c.level)}]`);
      newline();
    }

    const text = t.t === 'string' || t.t === 'number' || t.t === 'interp' ? t.raw : t.v;
    const isWord = t.t === 'keyword';
    const prevContinues = prev && !endsValue(prev) && !(prev.t === 'op' && prev.v === ';');

    // new statement: a statement keyword, or a name directly after something that ended a value
    if (!lineStart) {
      if (isWord && BREAK_BEFORE.has(text) && !(prevContinues && !['end', 'else', 'elseif', 'until'].includes(text))) newline();
      else if (isWord && text === 'function' && prev && !prevContinues && prev.v !== 'local') newline();
      else if (t.t === 'name' && endsValue(prev) && !(prev.t === 'name' && (prev.v === 'type' || prev.v === 'export'))) newline();
    }

    if (isWord && (text === 'end' || text === 'until' || text === 'else' || text === 'elseif')) depth = Math.max(0, depth - 1);

    if (lineStart) {
      out += indent.repeat(depth);
      lineStart = false;
    } else if (prev) {
      let space = true;
      if (t.t === 'op' && NO_SPACE_BEFORE.has(text)) space = false;
      else if (prev.t === 'op' && NO_SPACE_AFTER.has(prev.v)) space = false;
      else if (prevUnaryMinus) space = false;
      else if (t.t === 'op' && (text === '(' || text === '[') && (prev.t === 'name' || prev.t === 'string' || (prev.t === 'op' && CLOSERS.has(prev.v)))) space = false;
      if (space) out += ' ';
    }
    out += text;

    prevUnaryMinus = t.t === 'op' && (text === '-' || text === '~') && !endsValue(prev);
    if (t.t === 'op' && text === '(') parens++;
    if (t.t === 'op' && text === ')') parens = Math.max(0, parens - 1);

    if (isWord && (text === 'then' || text === 'do' || text === 'repeat')) { depth++; newline(); }
    else if (isWord && text === 'else') { depth++; newline(); }
    else if (isWord && text === 'function') depth++;
    else if (t.t === 'op' && text === ';' && parens === 0) newline();
    else if (t.t === 'op' && text === ')' && parens === 0 && closesFunctionHeader(tokens, t)) newline();
    prev = t;
  }
  return out.replace(/\n{3,}/g, '\n\n').replace(/[ \t]+\n/g, '\n').trimEnd() + '\n';
}

/** Is this `)` the end of a `function [name] (...)` parameter list? */
function closesFunctionHeader(tokens, close) {
  const at = tokens.indexOf(close);
  let depth = 0;
  for (let i = at; i >= 0; i--) {
    const t = tokens[i];
    if (t.t === 'op' && t.v === ')') depth++;
    if (t.t === 'op' && t.v === '(' && --depth === 0) {
      for (let k = i - 1; k >= Math.max(0, i - 8); k--) {
        const q = tokens[k];
        if (q.t === 'keyword' && q.v === 'function') return true;
        if (!(q.t === 'name' || (q.t === 'op' && (q.v === '.' || q.v === ':')))) return false;
      }
      return false;
    }
  }
  return false;
}
