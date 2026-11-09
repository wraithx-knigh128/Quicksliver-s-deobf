// Runtime verification: run Lua on real runtimes and report what happened.
//
// This is deliberately separate from static analysis. Static checks (does it parse, does it print back, do the trees match) say nothing about what a
// program does; a run on a reference runtime does. A result from here always names the runtime that produced it, and a runtime that is not installed is
// reported as unavailable. It is never approximated by another one.
//
// Runtimes (through `lupa`, which bundles the reference implementations):
//   lua51, lua52, lua53, lua54   PUC-Rio Lua
//   luajit                        LuaJIT 2.1
//   luau                          Roblox's Luau 0.739: QS_LUAU_BIN, else the build vendored with the reconstruction engine (api/_engine/luraph/deobf/bin/luau).
//
// Safety, per run: the program gets a mock environment and no I/O (io, os.execute, package, require, loadfile and dofile are removed), an instruction
// budget, a memory cap on the runner process (QS_ORACLE_MEM_MB), and a wall-clock timeout after which the runner is killed and restarted. The
// instruction budget is a hook the program itself could remove (`debug` is left in because real obfuscator output calls it), so the wall-clock kill and
// the memory cap are the guards that do not depend on the program's cooperation. Third-party scripts should not be run at all unless their owner supplied
// them for this purpose.

import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import readline from 'node:readline';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..', '..');
const runner = path.join(root, 'tests', 'corpus', 'tools', 'run_lua.py');

export const RUNTIMES = Object.freeze({
  lua51: { label: 'PUC Lua 5.1', family: 'lua5.1', via: 'lupa' },
  lua52: { label: 'PUC Lua 5.2', family: 'lua5.2', via: 'lupa' },
  lua53: { label: 'PUC Lua 5.3', family: 'lua5.3+', via: 'lupa' },
  lua54: { label: 'PUC Lua 5.4', family: 'lua5.3+', via: 'lupa' },
  luajit: { label: 'LuaJIT 2.1', family: 'lua5.1', via: 'lupa' },
  luau: { label: 'Luau', family: 'luau', via: 'external binary (QS_LUAU_BIN)' },
});

/** The Python that has lupa: QS_LUA_PYTHON, else the project's own virtual environment (tools/runtime/setup.sh makes it). */
export function findPython() {
  if (process.env.QS_LUA_PYTHON) return process.env.QS_LUA_PYTHON;
  const local = path.join(root, '.runtime', 'venv', 'bin', 'python');
  return fs.existsSync(local) ? local : null;
}

/** QS_LUAU_BIN, else the Luau 0.739 build vendored with the reconstruction engine (api/_engine/luraph/NOTICE.md). */
export function findLuau() {
  const bin = process.env.QS_LUAU_BIN;
  if (bin && fs.existsSync(bin)) return bin;
  const vendored = path.join(root, 'api', '_engine', 'luraph', 'deobf', 'bin', 'luau');
  return fs.existsSync(vendored) ? vendored : null;
}

export class Oracle {
  constructor({ python = findPython(), luau = findLuau(), timeoutMs = 30_000 } = {}) {
    this.python = python;
    this.luau = luau;
    this.timeoutMs = timeoutMs;
    this.child = null;
    this.nextId = 1;
    this.waiting = new Map();
    this.versions = null;
  }

  #start() {
    if (this.child) return;
    const child = spawn(this.python, ['-I', runner, '--serve'], { stdio: ['pipe', 'pipe', 'ignore'] });
    this.child = child;
    const rl = readline.createInterface({ input: child.stdout });
    rl.on('line', (line) => {
      let msg;
      try { msg = JSON.parse(line); } catch { return; }
      const w = this.waiting.get(msg.id);
      if (w) { this.waiting.delete(msg.id); w.cb(msg); }
    });
    child.on('exit', () => {
      if (this.child === child) this.child = null;
      // only the runs that were waiting on THIS process: a killed runner's exit arrives after the next run has already been sent to its replacement
      for (const [id, w] of this.waiting) if (w.child === child) { this.waiting.delete(id); w.cb({ ok: false, stdout: '', error: 'the runner process exited', crashed: true }); }
    });
  }

  /** Kill the runner (it is started again by the next run). */
  #kill() { if (this.child) { this.child.kill('SIGKILL'); this.child = null; } }

  #viaPython(runtime, code, timeoutMs, budget) {
    if (!this.python) return Promise.resolve({ ok: false, stdout: '', error: 'no Python with lupa: run tools/runtime/setup.sh, or set QS_LUA_PYTHON', unavailable: true });
    this.#start();
    const id = this.nextId++;
    const child = this.child;
    return new Promise((resolve) => {
      const timer = setTimeout(() => {
        this.waiting.delete(id);
        this.#kill();
        resolve({ ok: false, stdout: '', error: `wall-clock timeout after ${timeoutMs} ms (the runner was killed)`, timedOut: true });
      }, timeoutMs);
      this.waiting.set(id, { child, cb: (msg) => { clearTimeout(timer); resolve(msg); } });
      child.stdin.write(JSON.stringify({ id, runtime, code, budget }) + '\n');
    });
  }

  #viaLuau(code, timeoutMs) {
    if (!this.luau) return Promise.resolve({ ok: false, stdout: '', error: 'Luau is not installed (set QS_LUAU_BIN to a built luau binary)', unavailable: true });
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'qs-luau-'));
    const file = path.join(dir, 'sample.lua');
    fs.writeFileSync(file, Buffer.from(code, 'latin1'));
    const mb = Number(process.env.QS_ORACLE_MEM_MB || 3072);
    const prlimit = spawnSync('prlimit', ['--version'], { stdio: 'ignore' }).status === 0;
    const [cmd, args] = prlimit ? ['prlimit', [`--as=${mb << 20}`, this.luau, file]] : [this.luau, [file]];
    return new Promise((resolve) => {
      const child = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'], cwd: dir, env: { PATH: process.env.PATH } });
      const out = [];
      const err = [];
      let timedOut = false;
      const timer = setTimeout(() => { timedOut = true; child.kill('SIGKILL'); }, timeoutMs);
      child.stdout.on('data', (d) => out.push(d));
      child.stderr.on('data', (d) => err.push(d));
      child.on('close', (status) => {
        clearTimeout(timer);
        fs.rmSync(dir, { recursive: true, force: true });
        const stdout = Buffer.concat(out).toString('latin1');
        if (timedOut) return resolve({ ok: false, stdout, error: `wall-clock timeout after ${timeoutMs} ms (the process was killed)`, timedOut: true });
        const stderr = Buffer.concat(err).toString('latin1').trim();
        resolve({ ok: status === 0, stdout, error: status === 0 ? null : (stderr || `exit status ${status}`) });
      });
    });
  }

  /**
   * Run a Lua program (a binary string) on a named runtime.
   * @returns {Promise<{ok: boolean, stdout: string, error: string|null, runtime: string, ms: number, unavailable?: boolean, timedOut?: boolean}>}
   */
  async run(runtime, code, { timeoutMs = this.timeoutMs, budget = 50_000_000 } = {}) {
    if (!RUNTIMES[runtime]) throw new Error(`unknown runtime "${runtime}"`);
    const t0 = performance.now();
    const r = runtime === 'luau' ? await this.#viaLuau(code, timeoutMs) : await this.#viaPython(runtime, code, timeoutMs, budget);
    return { ...r, runtime, ms: Math.round(performance.now() - t0) };
  }

  /** Which runtimes can run, with the version each reports. A runtime that cannot run says why. */
  async detect() {
    if (this.versions) return this.versions;
    const out = [];
    for (const [id, info] of Object.entries(RUNTIMES)) {
      const r = await this.run(id, id === 'luau' ? 'print("ok")' : 'print(_VERSION .. (jit and (" " .. jit.version) or ""))', { timeoutMs: 15_000 });
      out.push({ id, ...info, available: r.ok, version: r.ok ? r.stdout.trim() : null, why: r.ok ? null : r.error });
    }
    this.versions = out;
    return out;
  }

  stop() { this.#kill(); }
}

let shared = null;
/** One shared oracle per process. */
export const oracle = () => (shared ||= new Oracle());
export const stopOracle = () => { if (shared) { shared.stop(); shared = null; } };
