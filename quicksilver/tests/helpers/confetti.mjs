// Test helper: protect a program the way a "comment confetti" protector does. A sentence is cut into short pieces and one piece is put
// in a block comment after every token, so that the text is unreadable and the file shows a message in place of the program.
// The program itself is not touched: removing the comments gives the original back token for token.

import { tokenize } from '../../src/core/lexer.js';

export const SENTENCE = 'This file is protected by its owner and may not be read by you or by any program that reads it. ';

export function confetti(code, sentence = SENTENCE) {
  const { tokens } = tokenize(code);
  const lens = [3, 5, 2, 6, 4, 7, 3, 1, 5];
  let k = 0;
  let pos = 0;
  const next = () => {
    const L = lens[k++ % lens.length];
    const piece = sentence.slice(pos, pos + L);
    pos = pos + L >= sentence.length ? 0 : pos + L;
    return piece;
  };
  let out = '';
  for (const t of tokens) {
    if (t.end <= t.start) continue;
    out += `${code.slice(t.start, t.end)} --[[${next()}]] `;
    if (/^(?:end|then|do|else)$/.test(t.v)) out += '\n';
  }
  return out;
}
