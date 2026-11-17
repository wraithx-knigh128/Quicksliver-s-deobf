// Prometheus (current mainline) presets after Prompt XVIII: the generic-for lowering of Vmify is raised back, conservatively, and the
// recovered program behaves exactly like the obfuscated one — including where Prometheus itself changed the program.
import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { raiseLoops } from '../src/passes/loopraise.js';
import { recover } from '../src/recover/pipeline.js';
import { available, runLua, stopOracle } from './helpers/lua-oracle.mjs';

after(() => stopOracle());
const root = path.join(path.dirname(fileURLToPath(import.meta.url)), 'corpus');

const raise = (src) => { const a = parse(src); const n = raiseLoops(a); return { n, out: print(a) }; };

test('the Vmify generic-for lowering is written as a for loop again', () => {
  const r = raise('local L = { ipairs(list) }\nlocal c = L[3]\nlocal s = L[2]\nlocal f = L[1]\nlocal v\nwhile true do\n  c, v = f(s, c)\n  if not c then break end\n  print(c, v)\nend\n');
  assert.equal(r.n.generic, 1);
  assert.match(r.out, /^for c, v in ipairs\(list\) do\n  print\(c, v\)\nend/);
  const g = raise('local gmatch = str.gmatch\nlocal L = { gmatch(str, "%a") }\nlocal s = L[2]\nlocal f = L[1]\nlocal c = L[3]\nwhile true do\n  c = f(s, c)\n  if not c then break end\n  t[c] = 1\nend\n');
  assert.match(g.out, /for c in gmatch\(str, "%a"\) do/, 'a local alias of gmatch is recognised');
});

test('it stays a while loop when that would change behaviour or lose information', () => {
  // `not c` also stops on a false key, which pairs can return; a for loop would not stop there
  assert.equal(raise('local L = { pairs(t) }\nlocal f = L[1]\nlocal c = L[3]\nlocal s = L[2]\nwhile true do\n  c = f(s, c)\n  if not c then break end\n  print(c)\nend\n').n.changed, 0);
  // the same loop with an exact nil test is raised
  assert.equal(raise('local L = { pairs(t) }\nlocal f = L[1]\nlocal c = L[3]\nlocal s = L[2]\nwhile true do\n  c = f(s, c)\n  if c == nil then break end\n  print(c)\nend\n').n.generic, 1);
  // the control value read after the loop
  assert.equal(raise('local L = { ipairs(t) }\nlocal f = L[1]\nlocal c = L[3]\nlocal s = L[2]\nwhile true do\n  c = f(s, c)\n  if not c then break end\nend\nprint(c)\n').n.changed, 0);
  // the loop variable assigned in the body
  assert.equal(raise('local L = { ipairs(t) }\nlocal f = L[1]\nlocal c = L[3]\nlocal s = L[2]\nwhile true do\n  c = f(s, c)\n  if not c then break end\n  c = 2\nend\n').n.changed, 0);
});

test('current Prometheus presets: the recovered program prints exactly what the obfuscated one prints (21 builds)', { skip: available ? false : 'QS_LUA_PYTHON not set', timeout: 600_000 }, async () => {
  const dir = path.join(root, 'obfuscated', 'prometheus');
  let fors = 0;
  for (const f of fs.readdirSync(dir).filter((x) => /__(Weak|Medium|Strong)\.lua$/.test(x))) {
    const obf = fs.readFileSync(path.join(dir, f), 'latin1');
    const r = recover(obf, { sandbox: { enabled: true } });
    const [a, b] = await Promise.all([runLua(obf), runLua(r.output)]);
    assert.equal(a.ok, true, `${f}: ${a.error}`);
    assert.equal(b.ok, true, `${f} recovered: ${b.error}`);
    assert.equal(b.stdout, a.stdout, f);
    fors += (r.output.match(/\bfor\b[^\n]*\bin\b/g) || []).length;
  }
  assert.ok(fors >= 16, `generic for loops raised: ${fors}`);
});

test('s03: Prometheus Vmify drops the parentheses that truncate a call to one value; the recovery keeps what the obfuscated program does', { skip: available ? false : 'QS_LUA_PYTHON not set' }, async () => {
  const orig = fs.readFileSync(path.join(root, 'originals', 's03_encoded_strings.lua'), 'latin1');
  const obf = fs.readFileSync(path.join(root, 'obfuscated', 'prometheus', 's03_encoded_strings__step-Vmify.lua'), 'latin1');
  const [o, a] = await Promise.all([runLua(orig), runLua(obf)]);
  assert.match(o.stdout, /d0g\n/);
  assert.match(a.stdout, /d0g\t4\n/, 'the obfuscated program prints the gsub count too: a defect of the obfuscator, not of the recovery');
});
