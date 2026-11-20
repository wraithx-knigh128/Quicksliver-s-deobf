// Voltfuscator (Voltils) — dedicated reader. Prompt XXII.
//
// Evidence: the vendor's own paired sample, published with the tool (github.com/usernamethisorthat/Voltils-Voltfuscator, "Voltfuscator 8.1":
// example.source.lua and its Normal and Ultra outputs), kept git-ignored in local/volt/. Read as text; run only in this project's sandbox.
//
// What a v8.1 output is (read, see docs/targets/VOLT.md):
//
//   -- Presets: <Normal|Ultra> / -- Source: <file> / -- Runtime: <runtime>          header comments
//   ([[File protected by Voltfuscator v8.1]]):gsub(".+", function(v) __voltfuscator_<id> = v end)
//   return ({ EK = entry, Ed = runtime, ER = environment, EM = constant decoder, EI = index, Ei = data }):EK()
//
//   EI   an index: base-42 varint pairs (key → offset/length in Ei), with a size, a count, a total and a checksum
//   Ei   the constants, base-85 text; each key's slice is deciphered by a keyed byte stream seeded with (key + c + Fq) and carries a length
//        and a checksum, so a wrong key or a wrong Fq raises "Voltfuscator: C052" instead of returning garbage
//   Fq   0 while the environment check in EK runs; afterwards the value EK passes when the check succeeded — the runtime's constants decode
//        only with it
//
// The constants are decoded here by calling the file's own EM in the sandbox (the per-build numbers stay where they are), and every value is
// accepted only if the file's own checksum accepted it. The runtime (Ed) is a control-flow-flattened interpreter whose program is
// ChaCha20-enciphered data; reading that program is a separate step (see docs/targets/VOLT.md for what is and is not done).

import { walk, transform } from '../core/walk.js';
import { createMachine } from '../sandbox/sandbox.js';
import { compileAst, callValue, index } from '../sandbox/interp.js';

export class VoltError extends Error {}

/** Header facts of a Voltfuscator output, from its first lines: version, preset, runtime. */
export function voltHeader(source) {
  const head = String(source).slice(0, 600);
  const banner = /File protected by Voltfuscator v([0-9][0-9.]*)/i.exec(head);
  if (!banner && !/__voltfuscator_[A-Za-z]+/.test(head)) return null;
  const preset = /^--\s*Presets?:\s*([^\r\n]+)/m.exec(head);
  const runtime = /^--\s*Runtime:\s*([^\r\n]+)/m.exec(head);
  const file = /^--\s*Source:\s*([^\r\n]+)/m.exec(head);
  return { version: banner ? banner[1] : null, preset: preset ? preset[1].trim() : null, runtime: runtime ? runtime[1].trim() : null, sourceName: file ? file[1].trim() : null };
}

export const looksLikeVolt = (source) => !!voltHeader(source);

const unparen = (e) => { while (e && e.type === 'Paren') e = e.expr; return e; };

/** The method table the file runs: `return ({ ... }):<entry>()`. */
export function voltTable(ast) {
  const last = ast.body[ast.body.length - 1];
  const call = last && last.type === 'Return' && last.values.length === 1 ? last.values[0] : null;
  if (!call || call.type !== 'MethodCall' || call.args.length) return null;
  const tbl = unparen(call.obj);
  if (!tbl || tbl.type !== 'Table') return null;
  const fields = new Map();
  for (const f of tbl.fields) if (f.kind === 'named') fields.set(f.key, f.value);
  return { table: tbl, entry: call.name, fields };
}

/**
 * Decode the constant pool through the file's own decoder, in the sandbox, and put each decoded constant in place of its call.
 * @returns {{ changed: number, keys: number, decoded: number, fq: object, binary: number, entry: string, decoder: string }}
 */
export function decodeVoltConstants(ast, { sandbox = {} } = {}) {
  if (!sandbox.enabled) return { skipped: 'the constants are decoded by running the file’s own decoder, which needs sandboxed evaluation' };
  const vt = voltTable(ast);
  if (!vt) throw new VoltError('the method table `return ({ ... }):entry()` was not found');
  // the decoder method: the one that returns a function and a setter and reads both data fields (EM in 8.1); found by shape, not by name
  const strs = [...vt.fields].filter(([, v]) => v.type === 'String').map(([k]) => k);
  const decoderName = [...vt.fields].find(([, v]) => {
    if (v.type !== 'Func') return false;
    let reads = 0;
    walk(v.body, (n) => { if (n.type === 'Index' && n.key && n.key.type === 'String' && strs.includes(n.key.value)) reads++; return undefined; });
    return reads >= 1 && strs.length >= 2;
  });
  if (!decoderName) throw new VoltError('no method reads the data fields: not the 8.1 layout');
  const m = createMachine({ fuel: sandbox.fuel ?? 400_000_000, timeMs: sandbox.timeMs ?? 60_000, dialect: 'luau' });
  let T;
  let decoder;
  let setFq;
  try {
    T = callValue(m, compileAst(m, { type: 'Chunk', body: [{ type: 'Return', values: [vt.table] }] }, 'volt', m.globals), [], '')[0];
    [decoder, setFq] = callValue(m, index(m, T, decoderName[0]), [T], '');
  } catch (e) {
    throw new VoltError(`the decoder could not be set up in the sandbox: ${String(e.message || e).slice(0, 160)}`);
  }
  if (!decoder || !setFq) throw new VoltError('the decoder method did not return a decoder and a setter');
  // keys: integer literals passed alone to a call (the decoder is passed on under other names); candidates for Fq: 0 and the entry's literals
  const keys = new Set();
  walk(ast, (n) => { if (n.type === 'Call' && n.args.length === 1 && n.args[0].type === 'Number' && Number.isInteger(n.args[0].value) && n.args[0].value > 0xffff) keys.add(n.args[0].value); return undefined; });
  const entry = vt.fields.get(vt.entry);
  const fqs = [0];
  if (entry) walk(entry, (n) => { if (n.type === 'Number' && Number.isInteger(n.value) && n.value > 0 && n.value < 1e7 && !fqs.includes(n.value)) fqs.push(n.value); return undefined; });
  const value = new Map();
  const fq = {};
  for (const k of keys) {
    for (const F of fqs) {
      try {
        callValue(m, setFq, [F], '');
        const v = callValue(m, decoder, [k], '')[0];
        if (typeof v !== 'string') break;
        value.set(k, v);
        fq[F] = (fq[F] || 0) + 1;
        break;
      } catch { /* the file's checksum refused this key under this Fq: try the next, or it is not a constant key */ }
    }
  }
  // put text constants in place; binary ones (key material, tables) stay as calls, so nothing unprintable is invented in the source
  let changed = 0;
  let binary = 0;
  const printable = (s) => /^[\x09\x0a\x0d\x20-\x7e]*$/.test(s);
  transform(ast, {
    expr(e) {
      if (e.type !== 'Call' || e.args.length !== 1 || e.args[0].type !== 'Number' || !value.has(e.args[0].value)) return undefined;
      const v = value.get(e.args[0].value);
      if (!printable(v) || v.length > 4096) { binary++; return undefined; }
      changed++;
      return { type: 'String', value: v };
    },
  });
  return { changed, keys: keys.size, decoded: value.size, fq, binary, entry: vt.entry, decoder: decoderName[0] };
}
