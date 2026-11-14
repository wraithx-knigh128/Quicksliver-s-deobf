// Repairs a script in which the generator's renamer replaced a Lua keyword with a generated name.
//
// Hercules 1.6's default preset renames every `if` of its own VM template to the same random identifier (`dlmxhxTEDxVX a == b then`), so the
// script it ships does not parse. The damage is mechanical and leaves a fingerprint that is checked, not assumed:
//   * there are more `then` tokens than `if` and `elseif` tokens together (every `then` belongs to one of them),
//   * exactly one name is never declared, assigned, used as a field or called as a function value, and starts a statement as often as `if` is missing,
//   * with that name written as `if` again the script parses.
// Only then is the source changed; the count and the name are reported so the step is visible.
import { tokenize, KEYWORDS } from '../core/lexer.js';
import { parse } from '../core/parser.js';

const parses = (src) => { try { parse(src); return true; } catch { return false; } };

export function repairRenamedKeyword(src) {
  let toks;
  try { toks = tokenize(src).tokens; } catch { return { source: src, count: 0 }; }
  if (!Array.isArray(toks)) return { source: src, count: 0 };
  const isKw = (t, v) => t && t.t === 'keyword' && t.v === v;
  const thens = toks.filter((t) => isKw(t, 'then')).length;
  const ifs = toks.filter((t) => isKw(t, 'if') || isKw(t, 'elseif')).length;
  const missing = thens - ifs;
  if (missing <= 0) return { source: src, count: 0 };

  // where each name occurs, and whether any occurrence is one a keyword could not be in
  const uses = new Map();
  for (let i = 0; i < toks.length; i++) {
    const t = toks[i];
    if (t.t !== 'name' || KEYWORDS.has(t.v)) continue;
    const u = uses.get(t.v) || { at: [], ruled: false };
    const prev = toks[i - 1];
    const next = toks[i + 1];
    // declared, assigned, a field, a parameter or a method: an identifier, not a keyword
    if (prev && ((prev.t === 'keyword' && (prev.v === 'local' || prev.v === 'function' || prev.v === 'for')) || (prev.t === 'op' && (prev.v === '.' || prev.v === ':' || prev.v === ',')))) u.ruled = true;
    if (next && next.t === 'op' && (next.v === '=' || next.v === ',' || next.v === '.' || next.v === ':' || next.v === '[')) u.ruled = true;
    u.at.push(i);
    uses.set(t.v, u);
  }
  // a renamed `if` is followed by a condition and, somewhere later on the same nesting level, by `then`
  const thenFollows = (i) => {
    let depth = 0;
    for (let j = i + 1; j < toks.length && j < i + 4000; j++) {
      const t = toks[j];
      if (t.t === 'op' && (t.v === '(' || t.v === '[' || t.v === '{')) depth++;
      else if (t.t === 'op' && (t.v === ')' || t.v === ']' || t.v === '}')) depth--;
      else if (depth === 0 && t.t === 'keyword') {
        if (t.v === 'then') return true;
        if (t.v !== 'and' && t.v !== 'or' && t.v !== 'not' && t.v !== 'nil' && t.v !== 'true' && t.v !== 'false' && t.v !== 'function') return false;
      }
      if (depth < 0) return false;
    }
    return false;
  };
  const candidates = [...uses].filter(([, u]) => !u.ruled && u.at.length === missing && u.at.every(thenFollows)).map(([name, u]) => ({ name, u }));
  if (candidates.length !== 1) return { source: src, count: 0 };
  const { name, u } = candidates[0];
  let out = '';
  let last = 0;
  for (const i of u.at) { out += src.slice(last, toks[i].start) + 'if'; last = toks[i].end; }
  out += src.slice(last);
  if (!parses(out)) return { source: src, count: 0 };
  return { source: out, count: u.at.length, keyword: 'if', name };
}
