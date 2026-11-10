// System health report: what works, what does not, and what to do about it.
//
//   node tools/doctor.mjs [--online] [--url https://deployment.example]
//
// Every line is a check that was actually run now. FAIL means a component the page advertises cannot work; WARN means it works with a stated limitation or is switched
// off by configuration; INFO is context. The exit status is 1 when anything FAILs, so this can gate a deploy. --online also checks live research connectivity;
// --url also asks a deployed site's /api/reconstruct?check=1 (which runs the engine self-test on that host).

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const engine = path.join(root, 'api', '_engine', 'luraph');
const rows = [];
const add = (level, area, what, action = '') => rows.push({ level, area, what, action });
const sha = (f) => crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const run = (cmd, args, opts = {}) => spawnSync(cmd, args, { encoding: 'utf8', timeout: 120_000, ...opts });
const json = (f) => JSON.parse(fs.readFileSync(path.join(root, f), 'utf8'));

// ---- toolchain
const nodeMajor = Number(process.versions.node.split('.')[0]);
add(nodeMajor >= 20 ? 'OK' : 'FAIL', 'toolchain', `node ${process.version}`, 'package.json requires node >= 20');
const py = run('python3', ['-c', 'import sys; print(sys.version.split()[0]); sys.exit(0 if sys.version_info >= (3, 9) else 1)']);
add(py.status === 0 ? 'OK' : 'FAIL', 'toolchain', `python3 ${py.stdout.trim() || 'not found'}`, 'the reconstruction service needs Python >= 3.9 (Vercel runs 3.12)');
const sdk = fs.existsSync(path.join(root, 'node_modules', '@anthropic-ai', 'sdk'));
add(sdk ? 'OK' : 'WARN', 'dependencies', `@anthropic-ai/sdk ${sdk ? 'installed' : 'missing'}`, 'run `npm ci` in quicksilver/ (the research and assistant model steps need it; everything else works without)');
const audit = run('npm', ['audit', '--omit=dev', '--json'], { cwd: root });
try { const a = JSON.parse(audit.stdout).metadata.vulnerabilities; const n = Object.values(a).reduce((x, y) => x + y, 0); add(n === 0 ? 'OK' : 'WARN', 'dependencies', `npm audit: ${n} known vulnerabilities`, 'run `npm audit` and update the listed packages'); } catch { add('INFO', 'dependencies', 'npm audit could not run (offline?)'); }

// ---- the engine and its binaries
const notice = fs.readFileSync(path.join(engine, 'NOTICE.md'), 'utf8');
for (const b of ['luau', 'luau-ast']) {
  const f = path.join(engine, 'deobf', 'bin', b);
  if (!fs.existsSync(f)) { add('FAIL', 'engine', `${b} binary is missing`, 'restore api/_engine/luraph/deobf/bin (see NOTICE.md for how it was built)'); continue; }
  const mode = fs.statSync(f).mode & 0o111;
  add(mode ? 'OK' : 'FAIL', 'engine', `${b} is ${mode ? '' : 'NOT '}executable`, 'chmod +x it, and make sure git keeps mode 100755');
  add(notice.includes(sha(f)) ? 'OK' : 'FAIL', 'engine', `${b} SHA-256 ${notice.includes(sha(f)) ? 'matches' : 'does NOT match'} NOTICE.md`, 'the binary was replaced: rebuild it as NOTICE.md describes or update NOTICE.md after review');
}
const t = path.join(root, 'local', '.doctor.lua');
fs.mkdirSync(path.dirname(t), { recursive: true });
fs.writeFileSync(t, 'print(_VERSION, 6 * 7, type(io), type(os.execute), type(getfenv))');
const lu = run(path.join(engine, 'deobf', 'bin', 'luau'), [t]);
add(lu.status === 0 && /^Luau\t42\tnil\tnil/.test(lu.stdout) ? 'OK' : 'FAIL', 'engine', `luau runs and has no io/os.execute (${lu.stdout.trim() || lu.stderr.trim().slice(0, 80)})`, 'the binary does not execute on this machine (architecture or libc): rebuild it for this platform');
fs.writeFileSync(t, 'local x = = 1');
const ast = run(path.join(engine, 'deobf', 'bin', 'luau-ast'), [t]);
add(ast.status !== 0 && /^Parse errors were encountered/.test(ast.stderr) ? 'OK' : 'FAIL', 'engine', 'luau-ast reports a syntax error (stderr, non-zero exit)', 'the output check and the vmmap parser depend on that contract');
fs.rmSync(t, { force: true });

// ---- each engine executes (the bundled fixtures)
const svc = path.join(engine, 'service.py');
for (const [label, file, expectEngine, original] of [['Luraph v15', 'fixtures/001_vm_like_dispatch-obfuscated.lua', 'luraph_v15', 'fixtures/001_vm_like_dispatch.lua'], ['IronBrew 1', 'fixtures/001_vm_like_dispatch-ib1.lua', 'ironbrew1', 'fixtures/001_vm_like_dispatch.lua']]) {
  const r = run('python3', ['-I', svc, path.join(engine, file), 'auto', '--original', path.join(engine, original)]);
  let res = null; try { res = JSON.parse(r.stdout); } catch { /* reported below */ }
  const ok = res && res.ok && res.engine.used === expectEngine && res.kind === 'devirtualized' && res.verification.status === 'identical';
  add(ok ? 'OK' : 'FAIL', 'engine', `${label}: ${res ? `${res.kind} by ${res.engine && res.engine.used}, verification ${res.verification && res.verification.status}` : 'the service did not answer: ' + (r.stderr || '').slice(-120)}`, 'run `node tools/luraph/verify.mjs` and read the diagnostics of the failing record');
}

// ---- Luau and Lua reference runtimes (Phase V oracle)
try {
  const { oracle, stopOracle } = await import(pathToFileURL(path.join(root, 'tools', 'runtime', 'oracle.mjs')).href);
  for (const r of await oracle().detect()) add(r.available ? 'OK' : (r.id === 'luau' ? 'FAIL' : 'WARN'), 'runtimes', `${r.id}: ${r.available ? r.version : r.why}`, r.id === 'luau' ? 'the vendored Luau build should always be found' : 'run `npm run runtime:setup` (needs Python and network once) to install lupa');
  await stopOracle();
} catch (e) { add('FAIL', 'runtimes', `the oracle could not load: ${e.message}`); }

// ---- the data the page shows must be what the code derives
try {
  const registry = json('data/research/luraph-compat.json');
  const { VERSIONS } = await import(pathToFileURL(path.join(root, 'src', 'reconstruct', 'engines.js')).href);
  const { versionStatus } = await import(pathToFileURL(path.join(root, 'src', 'reconstruct', 'status.js')).href);
  const bad = VERSIONS.filter((v) => registry.summary.versions[v.id].status !== versionStatus(v, registry).status);
  add(bad.length ? 'FAIL' : 'OK', 'data', `compatibility registry ${bad.length ? 'summary disagrees with its records for ' + bad.map((v) => v.id).join(', ') : 'is consistent with its records'}`, 'run `npm run luraph:verify`');
  const unstable = registry.records.filter((r) => !r.stable);
  add(unstable.length ? 'WARN' : 'OK', 'data', unstable.length ? `unstable results: ${unstable.map((r) => r.id).join(', ')}` : 'every recorded result was identical across three runs', 'a result that changes between runs cannot be trusted; run it again and diff the outputs');
  const { buildProfiles } = await import(pathToFileURL(path.join(root, 'tools', 'research', 'profiles-build.mjs')).href);
  const built = JSON.parse(JSON.stringify(buildProfiles())); const shipped = json('data/research/profiles.json'); built.generatedAt = shipped.generatedAt = 0;
  add(JSON.stringify(built) === JSON.stringify(shipped) ? 'OK' : 'FAIL', 'data', `profiles.json ${JSON.stringify(built) === JSON.stringify(shipped) ? 'is what the build derives' : 'is STALE or hand-edited'}`, 'run `npm run research`');
  const { validateLedger } = await import(pathToFileURL(path.join(root, 'src', 'research', 'discoveries.js')).href);
  const ledger = validateLedger(json('data/research/discoveries.json'), registry);
  add(ledger.ok ? 'OK' : 'FAIL', 'data', ledger.ok ? 'discoveries ledger is valid (verified entries cite records and commands)' : `ledger: ${ledger.problems[0]}`, 'a verified entry needs a reproducing command and registry records');
  const caps = json('data/research/capabilities.json').capabilities;
  const off = caps.filter((c) => !c.enabled);
  add(off.length ? 'WARN' : 'OK', 'data', `${caps.length - off.length} of ${caps.length} verified capabilities enabled${off.length ? '; disabled: ' + off.map((c) => c.id).join(', ') : ''}`, 'a disabled capability failed its own verifier or its fixtures are not here: see its checks in capabilities.json');
} catch (e) { add('FAIL', 'data', `data check failed: ${e.message}`); }
const fixtures = json('tools/luraph/fixtures.json').fixtures;
const missing = fixtures.filter((f) => !fs.existsSync(path.join(root, f.file)));
add(missing.length ? 'INFO' : 'OK', 'data', missing.length ? `fixtures not in this checkout (recorded by hash only): ${missing.map((f) => f.id).join(', ')}` : 'all registry fixtures present');

// ---- configuration
const env = process.env;
add('INFO', 'config', `reconstruction: QS_RECONSTRUCT_MODE=${env.QS_RECONSTRUCT_MODE || 'open (default)'}`);
add(env.ANTHROPIC_API_KEY ? 'OK' : 'WARN', 'config', `research and assistant model steps: ANTHROPIC_API_KEY ${env.ANTHROPIC_API_KEY ? 'set' : 'not set'}; research endpoint ${env.QS_RESEARCH_TOKEN ? 'enabled' : 'off (QS_RESEARCH_TOKEN unset)'}; assistant ${env.QS_ASSISTANT_MODE || 'off'}`, 'set them in the deployment environment only if you want those features; they have never been run against the real API');

// ---- deployment configuration
const vj = json('vercel.json');
const fn = vj.functions && vj.functions['api/reconstruct.py'];
add(fn && fn.maxDuration >= 60 && /api\/_engine/.test(fn.includeFiles || '') ? 'OK' : 'FAIL', 'deploy', `vercel.json: reconstruct function ${fn ? `maxDuration ${fn.maxDuration}, includes ${fn.includeFiles}` : 'missing'}`, 'the Python function must include api/_engine/** and have a long enough time limit');
const vi = fs.existsSync(path.join(root, '.vercelignore')) ? fs.readFileSync(path.join(root, '.vercelignore'), 'utf8') : '';
add(/\/?api\/_engine|^\/api\b/m.test(vi) ? 'FAIL' : 'OK', 'deploy', '.vercelignore does not exclude the engine', 'an excluded engine cannot be bundled into the function');
const gi = run('git', ['ls-files', '-s', 'api/_engine/luraph/deobf/bin'], { cwd: root });
add(gi.stdout.split('\n').filter(Boolean).every((l) => l.startsWith('100755')) && gi.stdout.trim() ? 'OK' : 'FAIL', 'deploy', 'binaries are tracked with the execute bit (100755)', 'git update-index --chmod=+x on both binaries');

// ---- optional: live
if (process.argv.includes('--online')) {
  const r = await fetch('https://raw.githubusercontent.com/Luraph/macrosdk/main/README.md').then((x) => x.status).catch((e) => e.cause && e.cause.code || e.message);
  add(r === 200 ? 'OK' : 'WARN', 'research', `live fetch of a permitted source: ${r}`, 'node needs NODE_USE_ENV_PROXY=1 behind an egress proxy; otherwise the research collector cannot read sources');
}
if (process.argv.includes('--url')) {
  const base = process.argv[process.argv.indexOf('--url') + 1].replace(/\/$/, '');
  const r = await fetch(`${base}/api/reconstruct?check=1`).then((x) => x.json()).catch((e) => ({ error: e.message }));
  add(r.selfTest && r.selfTest.ok ? 'OK' : 'FAIL', 'deploy', `${base}: ${r.selfTest ? `engine self-test ${r.selfTest.ok ? 'passed' : 'FAILED'} (${r.selfTest.kind}); luau ${r.capabilities && r.capabilities.luau.ok ? 'runs' : 'does not run'}; python ${r.capabilities && r.capabilities.python}` : r.error || 'no self-test in the answer'}`, 'open the deployment logs; `selfTest.log` in the answer is the engine\'s own output');
}

// ---- report
const order = { FAIL: 0, WARN: 1, INFO: 2, OK: 3 };
const width = Math.max(...rows.map((r) => r.area.length));
for (const r of [...rows].sort((a, b) => order[a.level] - order[b.level])) console.log(`${r.level.padEnd(4)}  ${r.area.padEnd(width)}  ${r.what}${r.level === 'FAIL' || r.level === 'WARN' ? `\n      -> ${r.action}` : ''}`);
const count = (l) => rows.filter((r) => r.level === l).length;
console.log(`\n${count('OK')} ok, ${count('WARN')} warnings, ${count('FAIL')} failures, ${count('INFO')} notes`);
process.exit(count('FAIL') ? 1 : 0);
