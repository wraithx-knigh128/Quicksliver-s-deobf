// Public API of the sandbox: run a Lua chunk with hard limits and report what happened.
//
//   runSource(src, options) -> { ok, kind, error, output, loads, returned, halted, fuelUsed }
//
// Nothing in here is ever started implicitly: callers decide to run a script, and the UI only does so
// after the user has explicitly allowed sandboxed execution.

import { Machine, compileSource, callValue } from './interp.js';
import { installStdlib } from './stdlib.js';
import { LuaError, SandboxLimit, SandboxUnsupported, LuaTable } from './value.js';
import { LuaSyntaxError } from '../core/parser.js';

export const DEFAULT_LIMITS = Object.freeze({ fuel: 20_000_000, timeMs: 5_000, maxDepth: 400 });

export function createMachine(options = {}) {
  const m = new Machine({ ...DEFAULT_LIMITS, ...options });
  installStdlib(m, options);
  return m;
}

/** Turn whatever the run threw into a stable description. */
export function classify(e) {
  if (e instanceof SandboxLimit) return e.kind === 'halt' ? { ok: true, halted: true } : { ok: false, kind: 'limit', error: e.message, limit: e.kind };
  if (e instanceof SandboxUnsupported) return { ok: false, kind: 'unsupported', error: e.message };
  if (e instanceof LuaSyntaxError) return { ok: false, kind: 'syntax', error: e.message };
  if (e instanceof LuaError) return { ok: false, kind: 'lua', error: typeof e.value === 'string' ? e.value : `(error object: ${typeof e.value})` };
  if (e instanceof RangeError) return { ok: false, kind: 'limit', error: 'JS stack exhausted', limit: 'depth' };
  throw e; // an interpreter bug: do not disguise it as a script failure
}

/**
 * @param {string} source binary string
 * @param {object} [options]
 *   fuel, timeMs, maxDepth        resource limits
 *   dialect                       'luau' | 'lua51' | 'luajit'
 *   haltOnLoad                    stop as soon as the script calls load/loadstring (payload is recorded)
 *   setup(machine)                add globals before the script runs
 *   chunkName                     name used in error messages
 */
export function runSource(source, options = {}) {
  const m = createMachine(options);
  m.chunkName = options.chunkName || 'sample';
  if (options.haltOnLoad) m.hooks.onLoad = () => { throw new SandboxLimit('halt', 'load'); };
  if (options.setup) options.setup(m);
  const startFuel = m.fuel;
  let result;
  let returned;
  try {
    const fn = compileSource(m, source, m.chunkName, m.globals);
    returned = callValue(m, fn, options.args || [], '');
    result = { ok: true };
  } catch (e) {
    result = classify(e);
  }
  return {
    ...result,
    output: m.output.join(''),
    loads: m.loads,
    returned,
    fuelUsed: startFuel - m.fuel,
    machine: m,
  };
}

export { LuaTable };
