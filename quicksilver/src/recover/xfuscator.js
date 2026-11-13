// XFuscator's "step 2": the program as an array of scaled character codes.
//
// XFuscator (efrederickson, 2013; "Version 2.0 b1", no licence stated) ends a protected script in
//
//     local ___ = ____[5]                                    -- math.random(1, 1100), a scale picked at build time
//     local _ = function(x) return string.char(x / ___) end
//     local __ = { _(99900), _(102675), ... }                -- one entry per character of the program
//     return ____[11](assert(#(____[8](__)) == 1862 and ... , 'Tampering detected'), ____[#____])()       -- loadstring(table.concat(__))()
//
// The scale is a random number that the script re-draws from a seeded generator, so it is not computed here: the array itself says what it is. Every
// entry is a character code times the same whole number, and the right scale is the one for which every entry divides and the text that comes out
// is a Lua program. The search is bounded by the largest entry and a candidate is accepted only when the text parses, so a wrong scale is not mistaken
// for a right one. The script around the array (the table of globals, the tamper check, the clock-seeded generator) is what XFuscator adds; the
// program is what the array spells, and replaces the chunk. What the program is made of (the constants pool XFuscator extracts, its own layers) is
// left to the other passes.

import { parse } from '../core/parser.js';
import { analyze } from '../core/scope.js';

/** `function(x) return string.char(x / K) end`: the divisor (a Name or a Number node), or null. */
function scaledChar(fn) {
  if (!fn || fn.type !== 'Func' || fn.params.length !== 1 || fn.body.length !== 1 || fn.body[0].type !== 'Return' || fn.body[0].values.length !== 1) return null;
  const call = fn.body[0].values[0];
  if (call.type !== 'Call' || call.fn.type !== 'Index' || call.fn.obj.type !== 'Name' || call.fn.obj.name !== 'string'
      || call.fn.key.type !== 'String' || call.fn.key.value !== 'char' || call.args.length !== 1) return null;
  const a = call.args[0];
  if (a.type !== 'Binary' || a.op !== '/' || a.left.type !== 'Name' || a.left.name !== fn.params[0].name) return null;
  return a.right.type === 'Name' || a.right.type === 'Number' ? a.right : null;
}

export function unwrapXFuscator(chunk) {
  const info = analyze(chunk);
  const body = chunk.body;
  let decoder = null; let divisor = null;
  for (const s of body) {
    if (s.type !== 'Local' || s.ids.length !== 1 || s.values.length !== 1) continue;
    const d = scaledChar(s.values[0]);
    if (d) { decoder = info.varOf.get(s.ids[0]); divisor = d; break; }
  }
  if (!decoder) return { changed: 0 };
  let array = null; let nums = null;
  for (const s of body) {
    if (s.type !== 'Local' || s.ids.length !== 1 || s.values.length !== 1 || s.values[0].type !== 'Table') continue;
    const fields = s.values[0].fields;
    if (fields.length < 8) continue;
    const ok = fields.every((f) => f.kind === 'item' && f.value.type === 'Call' && f.value.fn.type === 'Name' && info.varOf.get(f.value.fn) === decoder
      && f.value.args.length === 1 && f.value.args[0].type === 'Number' && Number.isInteger(f.value.args[0].value) && f.value.args[0].value >= 0);
    if (ok) { array = info.varOf.get(s.ids[0]); nums = fields.map((f) => f.value.args[0].value); break; }
  }
  if (!array) return { changed: 0 };
  // the array is what the script runs: the last statement reads it
  const last = body[body.length - 1];
  let reads = false;
  const visit = (n) => {
    if (!n || typeof n !== 'object' || reads) return;
    if (Array.isArray(n)) { n.forEach(visit); return; }
    if (n.type === 'Name' && info.varOf.get(n) === array) { reads = true; return; }
    for (const k of Object.keys(n)) if (k !== 'line' && k !== 'comments' && k !== 'trailing' && n[k] && typeof n[k] === 'object') visit(n[k]);
  };
  visit(last);
  if (!reads) return { changed: 0 };

  const max = Math.max(...nums);
  const candidates = divisor.type === 'Number' ? [divisor.value] : Array.from({ length: Math.max(max, 1) }, (_, i) => i + 1);
  for (const k of candidates) {
    if (!(k > 0) || !nums.every((n) => n % k === 0 && n / k < 256)) continue;
    const text = String.fromCharCode(...nums.map((n) => n / k));
    if (!/[\n\t\x20-\x7e]/.test(text) || /[\x00-\x08\x0e-\x1f]/.test(text)) continue;
    let ast;
    try { ast = parse(text); } catch { continue; }
    chunk.body = ast.body;
    chunk.features = new Set([...(chunk.features || []), ...(ast.features || [])]);
    return { changed: 1, scale: k, characters: nums.length };
  }
  return { changed: 0, skipped: 'no scale makes the array a Lua program' };
}
