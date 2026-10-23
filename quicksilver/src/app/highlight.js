// A tolerant, line-oriented Lua/Luau highlighter for the read-only viewers. It never throws and never
// needs the code to parse; it only has to colour what it can recognise. The only state carried from one
// line to the next is "inside a long string / long comment of level N".

const KEYWORDS = new Set(['and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while', 'continue']);
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
      push(after === '.' || after === ':' ? '' : KEYWORDS.has(word) ? 't-kw' : GLOBALS.has(word) ? 't-glob' : '', i, j);
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
