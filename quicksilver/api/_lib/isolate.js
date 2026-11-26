// Running a third-party engine on an uploaded script (Prompt XXIX). Each run gets a fresh directory, the engine's own files and the
// npm packages it names, and nothing else; the engine never runs inside this server process.
//
// Two strengths, chosen by what the host allows, and reported with every result:
//   namespaces  tools/isolate/run.sh: no network namespace, a private mount namespace with empty /home, /root and /tmp, the user `nobody`,
//               CPU/memory/file/process limits and a wall-clock kill (needs root and util-linux; a self-hosted server or a container)
//   process     a separate Node process with a memory cap, a wall-clock kill, an empty environment and a private working directory. Weaker:
//               the engine could reach what this server's user can reach. Used only for engines whose code was read and whose every path to
//               the host was removed (api/_engine/moonsec/NOTICE.md lists what was removed); Vercel functions run this way.

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const RUN_SH = path.join(root, 'tools', 'isolate', 'run.sh');
const MAX_OUT = 64 * 1024 * 1024;

/** Which isolation this host gives: namespaces where we are root and util-linux is present, otherwise a plain process. */
export function isolationMode() {
  try {
    if (process.platform !== 'linux' || typeof process.getuid !== 'function' || process.getuid() !== 0) return 'process';
    for (const b of ['unshare', 'setpriv', 'prlimit', 'timeout']) if (!['/usr/bin', '/bin'].some((d) => fs.existsSync(path.join(d, b)))) return 'process';
    return fs.existsSync(RUN_SH) ? 'namespaces' : 'process';
  } catch { return 'process'; }
}

const staged = new Map();
/** The engine's directory plus its npm packages, copied once per server process into a directory of its own. */
function stage(engineDir, modules) {
  const key = `${engineDir}|${modules.join(',')}`;
  if (staged.has(key) && fs.existsSync(staged.get(key))) return staged.get(key);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'qs-stage-'));
  fs.cpSync(engineDir, dir, { recursive: true });
  for (const m of modules) fs.cpSync(path.join(root, 'node_modules', m), path.join(dir, 'node_modules', m), { recursive: true });
  staged.set(key, dir);
  return dir;
}

/**
 * Run `node <driver> {in} {out}` for one input.
 * @param {{engineDir: string, driver: string, modules: string[], input: Buffer, timeoutS: number, memoryMb?: number}} o
 * @returns {Promise<{status: number|null, timedOut: boolean, output: Buffer|null, stderr: string, ms: number, isolation: string}>}
 */
export async function runEngine({ engineDir, driver, modules = [], input, timeoutS = 60, memoryMb = 1024 }) {
  const isolation = isolationMode();
  const work = fs.mkdtempSync(path.join(os.tmpdir(), 'qs-job-'));
  const inFile = path.join(work, 'input.lua');
  const outFile = path.join(work, 'output.bin');
  fs.writeFileSync(inFile, input);
  const t0 = Date.now();
  try {
    const dir = stage(engineDir, modules);
    const nodeArgs = [`--max-old-space-size=${memoryMb}`, driver];
    const [cmd, args, cwd] = isolation === 'namespaces'
      ? ['sh', [RUN_SH, dir, inFile, outFile, String(timeoutS), '--', 'node', ...nodeArgs, '{in}', '{out}'], work]
      : [process.execPath, [...nodeArgs.slice(0, 1), path.join(dir, driver), inFile, outFile], work];
    const r = await new Promise((resolve) => {
      const child = spawn(cmd, args, { cwd, env: isolation === 'namespaces' ? { PATH: '/usr/sbin:/usr/bin:/sbin:/bin' } : {}, stdio: ['ignore', 'ignore', 'pipe'] });
      let stderr = '';
      child.stderr.on('data', (c) => { if (stderr.length < 8192) stderr += c; });
      const timer = setTimeout(() => { try { child.kill('SIGKILL'); } catch { /* gone */ } }, (timeoutS + 10) * 1000);
      child.on('close', (status, signal) => { clearTimeout(timer); resolve({ status, signal, stderr }); });
      child.on('error', (e) => { clearTimeout(timer); resolve({ status: null, signal: null, stderr: String(e.message || e) }); });
    });
    const timedOut = r.status === 124 || r.signal === 'SIGKILL';
    let output = null;
    if (r.status === 0 && fs.existsSync(outFile)) {
      const st = fs.statSync(outFile);
      if (st.size > 0 && st.size <= MAX_OUT) output = fs.readFileSync(outFile);
    }
    return { status: r.status, timedOut, output, stderr: r.stderr.slice(0, 2000), ms: Date.now() - t0, isolation };
  } finally {
    fs.rmSync(work, { recursive: true, force: true });
  }
}
