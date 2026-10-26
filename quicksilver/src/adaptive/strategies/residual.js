// Shapes the engine recognises but has no way to take apart. They are reported as what is left, with the evidence, so that the output is
// never mistaken for a full recovery; an observer here is where a strategy for the shape would later plug in.

import { walk } from '../../core/walk.js';
import { strip, lineOf } from '../util.js';

/** A loop that fetches an instruction from a table by a counter and selects on its opcode: a virtual machine inside the script. */
function interpreters(ast, an) {
  const { info } = an;
  const out = [];
  walk(ast, (n) => {
    if (n.type !== 'While' && n.type !== 'Repeat') return;
    // the opcode: a local read from a table with a computed key, tested against many constants
    const fetched = new Map();
    walk(n.body, (m) => {
      if (m.type === 'Local') {
        m.ids.forEach((id, i) => {
          const v = m.values[i] && strip(m.values[i]);
          if (v && v.type === 'Index' && !(v.key.type === 'String' && v.dot)) fetched.set(info.varOf.get(id), m.values[i]);
        });
      } else if (m.type === 'Assign') {
        m.targets.forEach((t, i) => {
          const v = m.values[i] && strip(m.values[i]);
          if (t.type === 'Name' && v && v.type === 'Index' && !(v.key.type === 'String' && v.dot)) fetched.set(info.varOf.get(t), m.values[i]);
        });
      }
    });
    if (!fetched.size) return;
    let best = 0;
    walk(n.body, (m) => {
      if (m.type !== 'If') return;
      let tests = 0;
      for (const c of m.clauses) {
        const cond = strip(c.cond);
        if (cond.type === 'Binary' && (cond.op === '==' || cond.op === '<' || cond.op === '<=' || cond.op === '>' || cond.op === '>=')) {
          const l = strip(cond.left);
          const r = strip(cond.right);
          const name = l.type === 'Name' ? l : r.type === 'Name' ? r : null;
          if (name && fetched.has(info.varOf.get(name))) tests++;
        }
      }
      best = Math.max(best, tests);
    });
    if (best >= 6) out.push({ line: lineOf(n), tests: best });
  });
  return out;
}

export const interpreter = {
  id: 'vm.shape',
  title: 'Recognise a virtual machine inside the script',
  order: 90,
  observeOnly: true,
  observe(ast, an) {
    return interpreters(ast, an).map((v) => ({
      kind: 'interpreter',
      line: v.line,
      label: `a loop fetches an instruction from a table and selects among ${v.tests}+ handlers by its opcode`,
      evidence: ['the opcode comes from a table read with a computed key', 'the handlers are chosen by comparing it with constants'],
      confidence: 0.8,
      weight: 12,
      residual: 'The program is data for an interpreter that ships with it. Without a reader for this interpreter the data cannot be turned back into source.',
    }));
  },
};

/** A very long string literal that is neither readable text nor short: a payload (encoded program or data). */
export const payload = {
  id: 'payload.blob',
  title: 'Recognise an encoded payload',
  order: 91,
  observeOnly: true,
  observe(ast) {
    const out = [];
    walk(ast, (n) => {
      if (n.type !== 'String' || n.value.length < 4000) return;
      const s = n.value;
      let printable = 0;
      let letters = 0;
      let spaces = 0;
      for (let i = 0; i < s.length; i++) {
        const c = s.charCodeAt(i);
        if (c >= 32 && c < 127) printable++;
        if ((c >= 65 && c <= 90) || (c >= 97 && c <= 122)) letters++;
        if (c === 32) spaces++;
      }
      // readable text has spaces between words; an encoded blob does not
      if (spaces / s.length > 0.08) return;
      out.push({
        kind: 'payload',
        line: lineOf(n),
        label: `a string of ${s.length} characters that does not read as text (${Math.round((100 * printable) / s.length)}% printable)`,
        evidence: ['no word spacing', `${Math.round((100 * letters) / s.length)}% letters`],
        confidence: 0.6,
        weight: 2,
        residual: 'An encoded blob is carried in the script. If a decoder for it exists in the script it can be evaluated in the sandbox; otherwise it is left as it is.',
      });
    });
    return out;
  },
};
