// Bridge to the reference Lua runner (tests/corpus/tools/run_lua.py).
//
// The oracle runs code on real PUC Lua 5.1 / LuaJIT / Lua 5.4 through `lupa`, so tests can assert on
// observable behaviour instead of only comparing text. It needs a Python with `lupa` installed; point
// QS_LUA_PYTHON at it. When it is not configured the helpers report `available === false` and the
// behavioural tests are skipped (never silently passed).

import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import readline from 'node:readline';

const here = path.dirname(fileURLToPath(import.meta.url));
const runner = path.join(here, '..', 'corpus', 'tools', 'run_lua.py');

export const available = Boolean(process.env.QS_LUA_PYTHON);

let child = null;
let rl = null;
let nextId = 1;
const waiting = new Map();

function start() {
  if (child) return;
  child = spawn(process.env.QS_LUA_PYTHON, ['-I', runner, '--serve'], { stdio: ['pipe', 'pipe', 'inherit'] });
  rl = readline.createInterface({ input: child.stdout });
  rl.on('line', (line) => {
    const msg = JSON.parse(line);
    const cb = waiting.get(msg.id);
    if (cb) { waiting.delete(msg.id); cb(msg); }
  });
  child.on('exit', () => {
    for (const cb of waiting.values()) cb({ ok: false, stdout: '', error: 'oracle process exited' });
    waiting.clear();
    child = null;
  });
}

/**
 * Run `code` (a binary string) on the reference runtime.
 * @returns {Promise<{ok:boolean, stdout:string, error:string|null}>}
 */
export function runLua(code, runtime = 'lua51', budget = 50_000_000) {
  if (!available) throw new Error('QS_LUA_PYTHON is not set');
  start();
  const id = nextId++;
  return new Promise((resolve) => {
    waiting.set(id, resolve);
    child.stdin.write(JSON.stringify({ id, runtime, code, budget }) + '\n');
  });
}

export function stopOracle() {
  if (child) { child.stdin.end(); child = null; }
}
