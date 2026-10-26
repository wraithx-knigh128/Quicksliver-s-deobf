// The instruction that starts a generic `for`, written out the way it reads.
import { walk } from '../../core/walk.js';

const strip = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };
const N = (name) => ({ type: 'Name', name });
const regNum = (n) => { const m = /^r(\d+)$/.exec(n); return m ? Number(m[1]) : null; };

/**
 * The instruction that starts a generic `for`: normalise the iterator (a table is walked with pairs, a value with __iter by its metatable),
 * call the iterator once, and leave the loop when the first value is nil. The lifted handler is thirty lines of type tests; what it does is
 *     rA, rA+1, rA+2 = forgprep(rA, rA+1, rA+2)
 *     rA+3, ... rA+2+n = rA(rA+1, rA+2)
 *     rA+2 = rA+3
 *     if rA+2 == nil then <leave the loop> else <the body>
 * Recognised by the metatable lookup of the iterator. Returns undefined for any other instruction, null when it is this instruction but the
 * handler is not in a shape that can be written this way, and the replacement graph otherwise.
 */
export function canonicalForPrep(r) {
  let A = null;
  let nvars = 0;
  let sawIter = false;
  for (const b of r.blocks.values()) {
    for (const st of b.stmts) {
      walk(st, (x) => {
        if (x.type === 'Index' && x.key.type === 'String' && x.key.value === '__iter') sawIter = true;
        if (x.type === 'Call' && strip(x.fn).type === 'Name' && strip(x.fn).name === 'getmetatable' && x.args[0] && strip(x.args[0]).type === 'Name' && regNum(strip(x.args[0]).name) !== null && A === null) A = regNum(strip(x.args[0]).name);
      });
    }
  }
  if (!sawIter) return undefined;
  if (A === null) return null;
  // how many loop variables: the widest run of registers from A+3 that one assignment writes
  for (const b of r.blocks.values()) for (const st of b.stmts) {
    if (st.type !== 'Assign' || !st.targets.length) continue;
    const nums = st.targets.map((t) => (t.type === 'Name' ? regNum(t.name) : null));
    if (nums[0] === A + 3 && nums.every((x, i) => x === A + 3 + i)) nvars = Math.max(nvars, nums.length);
  }
  if (!nvars) return null;
  // which way the first value being nil goes is read off the lifted handler: follow the test on rA+2 to the exit it reaches
  const follow = (id) => { for (let i = 0; i < 64; i++) { const b = r.blocks.get(id); if (!b) return null; if (b.term.kind === 'exit') return r.exits.get(id).get('o'); if (b.term.kind === 'goto') id = b.term.to; else return null; } return null; };
  let nilTo = null;
  let valueTo = null;
  for (const b of r.blocks.values()) {
    if (b.term.kind !== 'branch') continue;
    const c = strip(b.term.cond);
    if (c.type === 'Binary' && c.op === '==' && strip(c.left).type === 'Name' && regNum(strip(c.left).name) === A + 2 && strip(c.right).type === 'Nil') { nilTo = follow(b.term.t); valueTo = follow(b.term.f); break; }
  }
  if (typeof nilTo !== 'number' || typeof valueTo !== 'number' || nilTo === valueTo) return null;
  const reg = (k) => N(`r${k}`);
  const vars = Array.from({ length: nvars }, (_, i) => reg(A + 3 + i));
  const blocks = new Map();
  blocks.set('S', {
    stmts: [
      { type: 'Assign', targets: [reg(A), reg(A + 1), reg(A + 2)], values: [{ type: 'Call', fn: N('forgprep'), args: [reg(A), reg(A + 1), reg(A + 2)], sugar: null }] },
      { type: 'Assign', targets: vars, values: [{ type: 'Call', fn: reg(A), args: [reg(A + 1), reg(A + 2)], sugar: null }] },
      { type: 'Assign', targets: [reg(A + 2)], values: [reg(A + 3)] },
    ],
    term: { kind: 'branch', cond: { type: 'Binary', op: '==', left: reg(A + 2), right: { type: 'Nil' } }, t: 'LEAVE', f: 'BODY' },
  });
  blocks.set('LEAVE', { stmts: [], term: { kind: 'exit' } });
  blocks.set('BODY', { stmts: [], term: { kind: 'exit' } });
  return { blocks, entry: 'S', exits: new Map([['LEAVE', new Map([['o', nilTo]])], ['BODY', new Map([['o', valueTo]])]]), forgprep: { A, nvars } };
}
