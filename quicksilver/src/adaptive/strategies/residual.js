// Shapes the engine recognises but has no way to take apart. They are reported as what is left, with the evidence, so that the output is
// never mistaken for a full recovery; an observer here is where a strategy for the shape would later plug in.

import { walk } from '../../core/walk.js';
import { strip, lineOf } from '../util.js';
import { isFetch } from './classic.js';

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

/**
 * `loadstring(game:HttpGet(url))()`: the program runs code that is fetched when it runs. That is what the script does, not a disguise on it,
 * so it adds nothing to the opacity score; it is listed because the code it loads is not in this file and nothing here can read it.
 */
export const remote = {
  id: 'remote.loader',
  title: 'Recognise code that is fetched at run time',
  order: 92,
  observeOnly: true,
  observe(ast) {
    const out = [];
    walk(ast, (n) => {
      if (n.type !== 'Call' || strip(n.fn).type !== 'Name' || !['loadstring', 'load'].includes(strip(n.fn).name) || !n.args[0] || !isFetch(n.args[0])) return;
      let url = null;
      walk(n.args[0], (m) => { if (!url && m.type === 'String' && /^https?:\/\//.test(m.value)) url = m.value; });
      out.push({
        kind: 'remote-loader',
        line: lineOf(n),
        label: url ? `the script loads and runs code fetched from ${url}${url.length < 60 ? '' : '…'}` : 'the script loads and runs code fetched over the network',
        evidence: ['loadstring is given the result of a network request'],
        confidence: 0.95,
        weight: 0,
        residual: 'The code this loads is fetched when the script runs; it is not in this file.',
      });
    });
    return out;
  },
};
