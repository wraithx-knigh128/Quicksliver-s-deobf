// The sandbox that runs third-party obfuscators (tests/corpus/tools/sandbox_run.py): a probe that tries to reach what must not be reachable is run inside it.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const tools = path.join(path.dirname(fileURLToPath(import.meta.url)), 'corpus', 'tools');
const probe = spawnSync('python3', ['-I', '-c', `import sys; sys.path.insert(0, ${JSON.stringify(tools)}); import sandbox_run; print(int(sandbox_run.available()))`], { encoding: 'utf8' });
const skip = probe.stdout.trim() === '1' ? false : 'user, mount and network namespaces are not available on this host (nothing is ever run without them)';

test('sandbox: no network, no host files, no host environment, a read-only tool, no way to mount or regain privileges', { skip }, () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'qs-sb-'));
  fs.mkdirSync(path.join(tmp, 'work'));
  const r = spawnSync('python3', ['-I', path.join(tools, 'sandbox_run.py'), '--tool', tools, '--work', path.join(tmp, 'work'), '--timeout', '30', '--', 'python3', '/mnt/tool/sandbox_probe.py'], { encoding: 'utf8', env: { ...process.env, HTTPS_PROXY: 'http://127.0.0.1:9', API_TOKEN: 'secret' } });
  assert.equal(r.status, 0, r.stderr);
  const out = JSON.parse(r.stdout);
  assert.equal(out.returncode, 0, out.stderr);
  const lines = out.stdout.split('\n');
  const res = JSON.parse(lines[lines.length - 2] || lines[lines.length - 1]);
  assert.equal(res.network[0], 'denied', 'a TCP connection to the internet');
  assert.equal(res.dns[0], 'denied', 'a name lookup');
  assert.equal(res['host repo'][0], 'denied', 'the host checkout is not there');
  for (const d of ['list /home', 'list /root', 'list /tmp']) assert.equal(res[d][1], '[]', `${d} is an empty folder`);
  assert.equal(res['write tool dir'][0], 'denied', 'the tool is read-only');
  assert.equal(res['write work dir'][0], 'ALLOWED', 'the work folder is writable');
  assert.equal(res['read proxy env'][0], 'denied', 'no proxy in the environment');
  assert.ok(!res['env keys'][1].includes('API_TOKEN'));
  assert.doesNotMatch(res.mount[1], /rc=0/, 'mount is refused');
  assert.match(res['host pid 1 cmdline'][1], /probe/, 'pid 1 is the sandbox’s own process');
  assert.equal(fs.readFileSync(path.join(tmp, 'work/ok.txt'), 'utf8'), 'x');
  fs.rmSync(tmp, { recursive: true, force: true });
});

test('sandbox: a runaway process is killed at its wall-clock limit', { skip }, () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'qs-sb-'));
  fs.mkdirSync(path.join(tmp, 'work'));
  const t0 = Date.now();
  const r = spawnSync('python3', ['-I', path.join(tools, 'sandbox_run.py'), '--tool', tools, '--work', path.join(tmp, 'work'), '--timeout', '3', '--', 'python3', '-c', 'while True: pass'], { encoding: 'utf8' });
  const out = JSON.parse(r.stdout);
  assert.equal(out.timedOut, true);
  assert.ok(Date.now() - t0 < 20_000);
  fs.rmSync(tmp, { recursive: true, force: true });
});
