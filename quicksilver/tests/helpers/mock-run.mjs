// Run a script in the sandbox interpreter with the same mock environment the real-Lua oracle uses
// (tests/corpus/tools/mock_env.lua), so the two can be compared output-for-output.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createMachine, classify } from '../../src/sandbox/sandbox.js';
import { compileSource, callValue } from '../../src/sandbox/interp.js';
import { bytesToBinary } from '../../src/core/bytes.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const MOCK = bytesToBinary(fs.readFileSync(path.join(here, '..', 'corpus', 'tools', 'mock_env.lua')));

/** @returns {{ok:boolean, stdout:string, error:string|null, kind?:string, fuelUsed:number}} */
export function runInSandbox(source, options = {}) {
  const m = createMachine({ fuel: 200_000_000, timeMs: 20_000, ...options });
  const start = m.fuel;
  try {
    callValue(m, compileSource(m, MOCK, 'mock', m.globals), [], '');
    m.chunkName = 'sample';
    callValue(m, compileSource(m, source, 'sample', m.globals), [], '');
    callValue(m, m.globals.get('QS_PUMP'), [], '');
    const out = m.globals.get('QS_OUT');
    const n = m.globals.get('QS_N');
    let stdout = '';
    for (let i = 1; i <= n; i++) stdout += out.get(i);
    return { ok: true, stdout, error: null, fuelUsed: start - m.fuel };
  } catch (e) {
    const c = classify(e);
    return { ok: false, stdout: '', error: c.error, kind: c.kind, fuelUsed: start - m.fuel };
  }
}
