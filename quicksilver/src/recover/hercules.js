// Recovery modules for Hercules (https://github.com/zeusssz/hercules-obfuscator).
//
// Patterns come from the Hercules source (src/modules/*.lua) and were checked against its real output
// in tests/corpus/obfuscated/hercules.

import { transform, walk } from '../core/walk.js';
import { STDLIB_GLOBALS as STD } from '../core/scope.js';

/**
 * modules/antitamper.lua prepends
 *   do local _BFR, _MFR, T, E, Pa, GM, RG = {...}, {...}, type, error, pairs, getmetatable, rawget
 *      ... local function check() ... error("Tamper Detected! Reason: ...") ... end  check() end
 * The block only verifies that standard functions are intact; it contributes nothing to the program.
 */
function isAntiTamperBlock(stmt) {
  if (stmt.type !== 'Do') return false;
  let hasTable = false;
  let marker = false;
  walk(stmt, (n) => {
    if (n.type === 'Id' && n.name === '_BFR') hasTable = true;
    // a second Hercules pass over the script renamed the block's locals: the table of standard functions is then recognised by its keys
    if (n.type === 'String' && n.value === 'debug.getinfo') hasTable = true;
    if (n.type === 'String' && n.value.startsWith('Tamper Detected! Reason:')) marker = true;
  });
  return hasTable && marker;
}

export function removeHerculesAntiTamper(chunk) {
  let removed = 0;
  transform(chunk, {
    block(stmts) {
      if (!stmts.some(isAntiTamperBlock)) return undefined;
      const out = stmts.filter((s) => !isAntiTamperBlock(s));
      removed += stmts.length - out.length;
      return out;
    },
  });
  return { changed: removed };
}

/**
 * modules/variable_renamer.lua works on text: it renames `self` wherever it is written, and a method declared with `:` never writes it
 * as a parameter. The method bodies then read a global that nothing ever sets, and the script fails at the first method call
 * ("attempt to index global 'FLeORjwr' (a nil value)"). The name is put back when the evidence leaves no other reading:
 *
 *   the name is a global that is never assigned and is not a standard one, it looks like the renamer's names (random letters: few vowels, or four
 *   consonants in a row), every use of it is inside a method (`function a:b()`), and none of those methods uses `self`.
 *
 * @returns {{changed: number, inferred?: string}}
 */
export function restoreMethodSelf(chunk, info) {
  const methodOf = new Map();                         // Name node -> innermost enclosing method Func (or null)
  const usesSelf = new Set();
  const stack = [];
  const visit = (n) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(visit); return; }
    const isFunc = n.type === 'Func';
    if (isFunc) stack.push(n);
    if (n.type === 'Name') {
      let m = null;
      for (let i = stack.length - 1; i >= 0 && !m; i--) if (stack[i].isMethod) m = stack[i];
      methodOf.set(n, m);
      if (n.name === 'self' && m) usesSelf.add(m);
    }
    for (const [k, v] of Object.entries(n)) if (k !== 'comments' && v && typeof v === 'object') visit(v);
    if (isFunc) stack.pop();
  };
  visit(chunk.body);
  let changed = 0;
  const names = [];
  for (const [name, v] of info.globals) {
    if (v.writes.length || !v.reads.length || STD.has(name) || name === 'self') continue;
    // the renamer's names are random letters; a real global a method reads (game, workspace, Config) is a word: it has vowels where
    // words have them. Random letters are one fifth vowels and run consonants together.
    if (!/^[A-Za-z]{5,}$/.test(name)) continue;
    const vowels = (name.match(/[aeiou]/gi) || []).length / name.length;
    const run = Math.max(...name.split(/[aeiou]/i).map((p) => p.length));
    if (!(vowels < 0.25 || run >= 4)) continue;
    const methods = v.reads.map((r) => methodOf.get(r));
    if (methods.some((m) => !m) || methods.some((m) => usesSelf.has(m))) continue;
    for (const r of v.reads) { r.name = 'self'; changed++; }
    names.push(name);
  }
  return changed ? { changed, inferred: `the global ${names.map((n) => `'${n}'`).join(', ')} that the methods read and nothing sets was read as their \`self\` (the renaming module renames it and a method does not declare it)` } : { changed: 0 };
}

/**
 * The same anti-tamper block after it went through a compiler (the VM module, or the bytecode layer, compiles the script with the block in
 * it, and decompiling gives the block back without its `do ... end` and without its names):
 *
 *   local t, m, ty, err, pa, gm, rg = { ["table.concat"] = table.concat, ... }, {}, type, error, pairs, getmetatable, rawget
 *   local libs = { table = table, string = string, math = math, os = os }
 *   local function check() ... error("Tamper Detected! Reason: ...") ... end
 *   check()
 *
 * The function is recognised by its messages and by being called once, with no arguments, as a statement; it and the call go, and so do the
 * declarations only it read (their values are tables of standard functions and standard functions: building them has no effect).
 */
export function removeHerculesAntiTamperFunction(chunk) {
  let removed = 0;
  const marker = (fn) => { let hit = false; walk(fn, (n) => { if (n.type === 'String' && n.value.startsWith('Tamper Detected! Reason:')) hit = true; }); return hit; };
  const inert = (e) => {
    if (!e) return true;
    if (['Name', 'String', 'Number', 'Nil', 'True', 'False'].includes(e.type)) return true;
    if (e.type === 'Index') return inert(e.obj) && inert(e.key);
    if (e.type === 'Table') return e.fields.every((f) => (f.kind !== 'keyed' || inert(f.key)) && inert(f.value));
    return false;
  };
  const visit = (stmts) => {
    for (let i = 0; i < stmts.length; i++) {
      const s = stmts[i];
      const name = s.type === 'LocalFunction' ? s.id.name : s.type === 'Local' && s.ids.length === 1 && s.values.length === 1 && s.values[0].type === 'Func' ? s.ids[0].name : null;
      const fn = s.type === 'LocalFunction' ? s.func : name ? s.values[0] : null;
      if (!fn || fn.params.length || !marker(fn)) continue;
      // called once, as a statement of this block, and named nowhere else
      const calls = [];
      let others = 0;
      for (const t of stmts) {
        if (t === s) continue;
        if (t.type === 'CallStmt' && t.call.type === 'Call' && t.call.fn.type === 'Name' && t.call.fn.name === name && !t.call.args.length) { calls.push(t); continue; }
        walk(t, (n) => { if (n.type === 'Name' && n.name === name) others++; });
      }
      if (calls.length !== 1 || others) continue;
      const read = new Set();
      walk(fn, (n) => { if (n.type === 'Name') read.add(n.name); });
      stmts.splice(stmts.indexOf(calls[0]), 1);
      stmts.splice(stmts.indexOf(s), 1);
      removed += 2;
      // what only the check read
      for (let again = true; again;) {
        again = false;
        for (let j = stmts.length - 1; j >= 0; j--) {
          const t = stmts[j];
          if (t.type !== 'Local' || !t.values.every(inert) || !t.ids.some((id) => read.has(id.name))) continue;
          const usedElsewhere = t.ids.some((id) => { let n = 0; for (const u of stmts) if (u !== t) walk(u, (x) => { if (x.type === 'Name' && x.name === id.name) n++; }); return n > 0; });
          if (usedElsewhere) continue;
          walk(t.values, (n) => { if (n.type === 'Name') read.add(n.name); });
          stmts.splice(j, 1); removed++; again = true;
        }
      }
      i = -1;                                 // the block changed: look again from its start
    }
  };
  visit(chunk.body);
  // one level down as well: the block can sit inside the wrapper the control-flow module puts around the script
  walk(chunk, (n) => { if (n !== chunk && Array.isArray(n.body) && n.type !== 'Func') visit(n.body); if (n.type === 'If') { n.clauses.forEach((c) => visit(c.body)); if (n.orelse) visit(n.orelse); } });
  return { changed: removed };
}

/**
 * control_flow_obfuscator.lua of Hercules 1.5 to 1.6 prepends one guard, written the same way every time:
 *
 *   local executed = false while not executed do if math.random(0, 1) == 0 then local _ = <n> else executed = true end end
 *
 * It repeats until a coin comes up the right way and does nothing else: the only other branch holds a junk local. The program after it is
 * the script. (The coin flips advance the random generator, so a script that draws random numbers without seeding them draws other numbers
 * once the guard is gone; such a script has no fixed output to preserve.)
 */
export function removeHerculesCoinGuard(chunk) {
  let removed = 0;
  const isJunk = (body) => body.length === 0 || (body.length === 1 && body[0].type === 'Local' && body[0].ids.length === 1 && body[0].values.length === 1 && body[0].values[0].type === 'Number');
  const sets = (body, name) => body.length === 1 && body[0].type === 'Assign' && body[0].targets.length === 1 && body[0].targets[0].type === 'Name' && body[0].targets[0].name === name
    && body[0].values.length === 1 && body[0].values[0].type === 'True';
  const coin = (e) => e.type === 'Binary' && (e.op === '==' || e.op === '~=') && e.left.type === 'Call' && e.left.fn.type === 'Index' && e.left.fn.obj.type === 'Name'
    && e.left.fn.obj.name === 'math' && e.left.fn.key.type === 'String' && e.left.fn.key.value === 'random' && e.left.args.length === 2 && e.left.args.every((a) => a.type === 'Number')
    && e.right.type === 'Number';
  transform(chunk, {
    block(stmts) {
      for (let i = 0; i + 1 < stmts.length; i++) {
        const a = stmts[i];
        const w = stmts[i + 1];
        if (a.type !== 'Local' || a.ids.length !== 1 || a.values.length !== 1 || a.values[0].type !== 'False') continue;
        const name = a.ids[0].name;
        if (w.type !== 'While' || w.cond.type !== 'Unary' || w.cond.op !== 'not' || w.cond.arg.type !== 'Name' || w.cond.arg.name !== name) continue;
        if (w.body.length !== 1 || w.body[0].type !== 'If' || w.body[0].clauses.length !== 1) continue;
        const iff = w.body[0];
        const c = iff.clauses[0];
        if (!coin(c.cond) || !iff.orelse) continue;
        if (!((isJunk(c.body) && sets(iff.orelse, name)) || (sets(c.body, name) && isJunk(iff.orelse)))) continue;
        const out = stmts.slice();
        // a comment written before the guard belongs to what follows
        const next = out[i + 2];
        if (next && a.comments && a.comments.length) next.comments = [...a.comments, ...(next.comments || [])];
        out.splice(i, 2);
        removed++;
        return out;
      }
      return undefined;
    },
  });
  return { changed: removed };
}
