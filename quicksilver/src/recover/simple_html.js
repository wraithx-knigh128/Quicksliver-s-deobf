// The single-page Lua obfuscator (simple-lua-obfuscator's index.html, MIT; see docs/RESEARCH.md): reading its string decoder.
//
// The page writes this line in front of the script and turns every string into a call of it:
//
//   local function _D(t) local s="" for i=1,#t do local v=(t[i]-47) if v<0 then v=v+256 end s=s..string.char(v) end return s end
//   local x = (_D({(68+51),(7+141),...}))
//
// The decoder is a subtraction with wrap-around, so a call whose argument is a list of numbers is computed here, directly, without running
// anything: the text replaces the call. The function is only recognised in exactly this form, and is removed once nothing calls it.

import { transform, walk } from '../core/walk.js';

/** The key K if `stmt` is `local function _D(t) ... (t[i]-K) ... end` in the form the page writes it. */
function decoderKey(stmt) {
  if (!stmt || stmt.type !== 'LocalFunction' || stmt.id.name !== '_D') return null;
  const f = stmt.func;
  if (f.params.length !== 1 || f.vararg || f.body.length !== 3) return null;
  const [init, loop, ret] = f.body;
  if (init.type !== 'Local' || init.values.length !== 1 || init.values[0].type !== 'String' || init.values[0].value !== '') return null;
  if (loop.type !== 'NumFor' || loop.body.length !== 3) return null;
  if (ret.type !== 'Return' || ret.values.length !== 1 || ret.values[0].type !== 'Name') return null;
  const [v, wrap, cat] = loop.body;
  const sub = v.type === 'Local' && v.values.length === 1 && v.values[0].type === 'Paren' ? v.values[0].expr : v.type === 'Local' && v.values.length === 1 ? v.values[0] : null;
  if (!sub || sub.type !== 'Binary' || sub.op !== '-' || sub.left.type !== 'Index' || sub.right.type !== 'Number') return null;
  if (wrap.type !== 'If' || cat.type !== 'Assign') return null;
  return sub.right.value;
}

export function decodePageStrings(chunk) {
  let key = null;
  let at = -1;
  chunk.body.forEach((s, i) => { if (at < 0) { const k = decoderKey(s); if (k != null) { key = k; at = i; } } });
  if (at < 0) return { changed: 0 };

  let replaced = 0;
  transform(chunk, {
    expr(e) {
      if (e.type !== 'Call' || e.fn.type !== 'Name' || e.fn.name !== '_D' || e.args.length !== 1) return undefined;
      const t = e.args[0];
      if (t.type !== 'Table' || !t.fields.every((f) => f.kind === 'item' && f.value.type === 'Number' && Number.isInteger(f.value.value))) return undefined;
      let text = '';
      for (const f of t.fields) {
        let v = f.value.value - key;
        if (v < 0) v += 256;
        if (v < 0 || v > 255) return undefined;
        text += String.fromCharCode(v);
      }
      replaced++;
      return { type: 'String', value: text, raw: null };
    },
  });

  // no other use of the name: the function goes
  let uses = 0;
  walk(chunk, (n) => { if (n.type === 'Name' && n.name === '_D') uses++; });
  if (uses === 0) chunk.body.splice(at, 1);
  return { changed: replaced + (uses === 0 ? 1 : 0), strings: replaced, removed: uses === 0 };
}
