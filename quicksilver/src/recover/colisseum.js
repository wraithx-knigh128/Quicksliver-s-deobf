// Colisseum (AGPL-3.0; see docs/RESEARCH.md): removal of its tamper guard.
//
// Colisseum's medium, hard and full presets put one large `do ... end` first in the script. It measures the environment (a debug hook, executor
// globals, replaced standard functions, a changed string metatable, line numbers of error messages) and raises an error whose text is the
// Colisseum brand plus a four-digit code when the score is high enough. It does not change what the program computes, so the block can be
// removed once it has been recognised by the strings it cannot do without: the error brand, the name of its hook global and the key of its
// first check. Nothing is run to decide this.

const BRAND = 'Oh Noes!, An error ocurred: 0x';
const HOOK = '__COLISSEUM_TAMPER__';
const KEY = 'debug-hook';

/** Is this statement the guard? Only a `do` block at the top of the script can be. */
export function isColisseumGuard(s) {
  if (!s || s.type !== 'Do') return false;
  const seen = new Set();
  const visit = (n) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(visit); return; }
    if (n.type === 'String') {
      if (n.value.includes(BRAND)) seen.add('brand');
      else if (n.value === HOOK) seen.add('hook');
      else if (n.value === KEY) seen.add('key');
      return;
    }
    for (const k of Object.keys(n)) if (k !== 'line' && k !== 'pos' && typeof n[k] === 'object') visit(n[k]);
  };
  visit(s.body);
  return seen.size === 3;
}

export function removeColisseumGuard(chunk) {
  const keep = chunk.body.filter((s) => !isColisseumGuard(s));
  const removed = chunk.body.length - keep.length;
  if (removed) chunk.body = keep;
  return { changed: removed };
}
