// A tolerant, line-oriented Lua/Luau highlighter for the viewers and the input editor. It never throws and
// never needs the code to parse; it only has to colour what it can recognise. The only state carried from
// one line to the next is "inside a long string / long comment of level N".

// declarations, constants and word operators (t-kw) versus control flow (t-ctl)
const KEYWORDS = new Set(['and', 'false', 'function', 'local', 'nil', 'not', 'or', 'true']);
const CONTROL = new Set(['break', 'do', 'else', 'elseif', 'end', 'for', 'goto', 'if', 'in', 'repeat', 'return', 'then', 'until', 'while', 'continue']);
const GLOBALS = new Set(['print', 'pairs', 'ipairs', 'next', 'select', 'type', 'typeof', 'tostring', 'tonumber', 'error', 'assert', 'pcall', 'xpcall', 'require', 'loadstring', 'load', 'setmetatable', 'getmetatable', 'rawget', 'rawset', 'rawequal', 'rawlen', 'unpack', 'string', 'table', 'math', 'bit32', 'bit', 'os', 'io', 'debug', 'coroutine', 'utf8', 'game', 'workspace', 'script', 'Instance', 'getfenv', 'setfenv', 'task', 'wait', 'spawn', 'delay', 'warn', 'tick', '_G', '_ENV', 'newproxy', 'collectgarbage']);

const longOpen = /^\[(=*)\[/;

/** Start state of every line: -1 = ordinary code, n >= 0 = inside a long bracket of level n. */
export function lineStates(lines) {
  const states = new Int8Array(lines.length);
  let st = -1;
  let isComment = false;
  const kind = new Uint8Array(lines.length); // 1 = long comment, 2 = long string
  for (let i = 0; i < lines.length; i++) {
    states[i] = st;
    kind[i] = st >= 0 ? (isComment ? 1 : 2) : 0;
    const r = scan(lines[i], st, isComment, null);
    st = r.state;
    isComment = r.comment;
  }
  return { states, kind };
}

/**
 * Tokenise one line. With `out` null it only advances the state (cheap pass); otherwise pushes [class, text].
 * @returns {{state: number, comment: boolean}}
 */
export function scan(line, state, comment, out) {
  let i = 0;
  const n = line.length;
  const push = (cls, a, b) => { if (out && b > a) out.push([cls, line.slice(a, b)]); };
  if (state >= 0) {
    const close = `]${'='.repeat(state)}]`;
    const at = line.indexOf(close);
    if (at < 0) { push(comment ? 't-com' : 't-str', 0, n); return { state, comment }; }
    push(comment ? 't-com' : 't-str', 0, at + close.length);
    i = at + close.length;
    state = -1;
    comment = false;
  }
  while (i < n) {
    const c = line.charCodeAt(i);
    const ch = line[i];
    if (ch === '-' && line[i + 1] === '-') {
      const m = longOpen.exec(line.slice(i + 2));
      if (m) {
        const level = m[1].length;
        const close = `]${'='.repeat(level)}]`;
        const at = line.indexOf(close, i + 4 + level);
        if (at < 0) { push('t-com', i, n); return { state: level, comment: true }; }
        push('t-com', i, at + close.length);
        i = at + close.length;
        continue;
      }
      push('t-com', i, n);
      return { state: -1, comment: false };
    }
    if (ch === '"' || ch === "'" || ch === '`') {
      let j = i + 1;
      while (j < n && line[j] !== ch) j += line[j] === '\\' ? 2 : 1;
      push('t-str', i, Math.min(n, j + 1));
      i = Math.min(n, j + 1);
      continue;
    }
    if (ch === '[') {
      const m = longOpen.exec(line.slice(i));
      if (m) {
        const level = m[1].length;
        const close = `]${'='.repeat(level)}]`;
        const at = line.indexOf(close, i + 2 + level);
        if (at < 0) { push('t-str', i, n); return { state: level, comment: false }; }
        push('t-str', i, at + close.length);
        i = at + close.length;
        continue;
      }
    }
    if ((c >= 48 && c <= 57) || (ch === '.' && line.charCodeAt(i + 1) >= 48 && line.charCodeAt(i + 1) <= 57)) {
      let j = i + 1;
      while (j < n && /[0-9a-fA-FxXpP_.]/.test(line[j])) {
        if ((line[j] === 'e' || line[j] === 'E' || line[j] === 'p' || line[j] === 'P') && (line[j + 1] === '+' || line[j + 1] === '-') && !/^0[xX]/.test(line.slice(i, i + 2))) j++;
        j++;
      }
      push('t-num', i, j);
      i = j;
      continue;
    }
    if (/[A-Za-z_]/.test(ch)) {
      let j = i + 1;
      while (j < n && /[A-Za-z0-9_]/.test(line[j])) j++;
      const word = line.slice(i, j);
      const after = line[i - 1];
      const member = after === '.' || after === ':';
      let k = j;
      while (k < n && (line[k] === ' ' || line[k] === '\t')) k++;
      const called = line[k] === '(';
      push(member ? (called ? 't-fn' : '') : KEYWORDS.has(word) ? 't-kw' : CONTROL.has(word) ? 't-ctl' : called ? 't-fn' : GLOBALS.has(word) ? 't-glob' : '', i, j);
      i = j;
      continue;
    }
    let j = i + 1;
    if (/[+\-*/%^#=~<>.:,;(){}[\]&|]/.test(ch)) {
      while (j < n && /[=.]/.test(line[j]) && /[=.<>~:/]/.test(ch)) j++;
      push('t-op', i, j);
      i = j;
      continue;
    }
    while (j < n && !/[A-Za-z0-9_"'`[\-+*/%^#=~<>.:,;(){}\]&|]/.test(line[j])) j++;
    push('', i, j);
    i = j;
  }
  return { state: -1, comment: false };
}

/** Build the spans for one line. Lines longer than `cap` are cut so a minified one-liner cannot freeze the page. */
export function lineNodes(line, state, kind, cap = 3000) {
  const frag = document.createDocumentFragment();
  let text = line;
  let more = 0;
  if (text.length > cap) { more = text.length - cap; text = text.slice(0, cap); }
  const out = [];
  scan(text, state, kind === 1, out);
  for (const [cls, t] of out) {
    if (!cls) { frag.append(document.createTextNode(t)); continue; }
    const s = document.createElement('span');
    s.className = cls;
    s.textContent = t;
    frag.append(s);
  }
  if (more) {
    const s = document.createElement('span');
    s.className = 't-com';
    s.textContent = ` … ${more} more characters`;
    frag.append(s);
  }
  return frag;
}

/** Longest line the editor overlay will tokenise; beyond this only the visible columns are drawn, uncoloured. */
const TOKENISE_MAX = 250_000;

/**
 * Spans for the columns [from, to) of one very long line, preceded by a spacer so they sit where the text is.
 * The input editor draws these under a transparent textarea, so unlike lineNodes nothing may be shortened or added.
 */
export function windowNodes(line, state, kind, from, to, charPx) {
  const frag = document.createDocumentFragment();
  const end = Math.min(line.length, to);
  if (from >= end) return frag;
  if (from > 0) {
    const gap = document.createElement('span');
    gap.className = 'gap';
    gap.style.width = `${from * charPx}px`;
    frag.append(gap);
  }
  if (end > TOKENISE_MAX) { frag.append(document.createTextNode(line.slice(from, end))); return frag; }
  const out = [];
  scan(line.slice(0, end), state, kind === 1, out);
  let at = 0;
  for (const [cls, t] of out) {
    const next = at + t.length;
    if (next > from) {
      const piece = at < from ? t.slice(from - at) : t;
      if (!cls) frag.append(document.createTextNode(piece));
      else { const s = document.createElement('span'); s.className = cls; s.textContent = piece; frag.append(s); }
    }
    at = next;
  }
  return frag;
}

/** The whole line as spans, uncapped (the editor's rows are never longer than the window logic allows). */
export function fullNodes(line, state, kind) {
  const frag = document.createDocumentFragment();
  const out = [];
  scan(line, state, kind === 1, out);
  for (const [cls, t] of out) {
    if (!cls) { frag.append(document.createTextNode(t)); continue; }
    const s = document.createElement('span');
    s.className = cls;
    s.textContent = t;
    frag.append(s);
  }
  return frag;
}
