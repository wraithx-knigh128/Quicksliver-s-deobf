// Differential self-check for lifts that go through the decompiler: the decoded Lua 5.1 chunk is exact (the VM's own program), the
// decompiled source is a reconstruction. Both are run in the sandbox (never on the host), with the same limits, and compared on what
// they print and whether they finish. A reconstruction that behaves differently from the chunk it was made from is not reported as
// recovered. When the sandbox cannot run the program (a library it does not model, a limit), nothing is claimed either way.

import { createMachine, classify, runSource } from '../sandbox/sandbox.js';
import { loadBytecode } from '../sandbox/bytecode.js';
import { callValue } from '../sandbox/interp.js';

const LIMITS = { fuel: 20_000_000, timeMs: 4_000, maxDepth: 300 };

function runChunk(bytes, dialect) {
  const m = createMachine({ ...LIMITS, dialect });
  m.chunkName = 'sample';
  let result;
  try {
    const fn = loadBytecode(m, bytes, m.globals);
    callValue(m, fn, [], '');
    result = { ok: true };
  } catch (e) {
    try { result = classify(e); } catch { result = { ok: false, kind: 'internal', error: String(e && e.message) }; }
  }
  return { ...result, output: m.output.join('') };
}

/** { checked, same, reason } */
export function checkAgainstChunk(bytes, source, { dialect = 'lua51' } = {}) {
  let a; let b;
  try { a = runChunk(bytes, dialect); } catch (e) { return { checked: false, reason: `the chunk could not be run: ${e.message}` }; }
  try { b = runSource(source, { ...LIMITS, dialect, chunkName: 'sample' }); } catch (e) { return { checked: false, reason: `the source could not be run: ${e.message}` }; }
  if (a.kind === 'limit' || b.kind === 'limit' || a.kind === 'unsupported' || b.kind === 'unsupported' || a.kind === 'internal') {
    return { checked: false, reason: `the sandbox could not finish both runs (${a.kind || 'ok'} / ${b.kind || 'ok'})` };
  }
  // error texts name variables differently (a register in the chunk, a local in the source): what is compared is output and outcome
  const same = a.ok === b.ok && a.output === b.output;
  if (!same) return { checked: true, same: false, reason: a.output !== b.output ? 'the reconstruction prints something else than the decoded program' : 'one run finishes and the other fails' };
  return { checked: true, same: true, output: a.output.length };
}
