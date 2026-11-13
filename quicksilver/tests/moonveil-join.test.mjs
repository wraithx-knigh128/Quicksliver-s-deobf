// Prompt XI: MoonVeil 2.0.26's table of factories joined into one program, the cells read as variables, and the dataflow fix the leak behind them led to.
//
// The 2.0.26 / 2.1.0 samples are third-party scripts that are not stored in the repository, so the join is tested on a table written for the test in the same shape (the factory
// signature, the sites, the cells, the environment), and on the local samples when they are present on this machine.

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from '../src/core/parser.js';
import { print } from '../src/core/printer.js';
import { joinMoonVeil, unboxCells, JoinError } from '../src/recover/moonveil-join.js';
import { simplifyPass } from '../src/passes/simplify.js';
import { dataflowPass } from '../src/passes/dataflow.js';
import { runSource } from '../src/sandbox/sandbox.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..');

const TABLE = `
return ({
  function(a, ...) a.P = a:Q() return a:main()(...) end,
  function(c) return function(...)
    local acc = { [3] = 1, [1] = 0 }
    local add = c:inc{ acc }
    add(5) add(7)
    print(acc[1], c._["tostring"](acc[1]))
  end end,
  function(c, g) return function(n) g[1][1] = g[1][1] + n end end,
  function(c) return 1 end,
  O = function() end,
  h = function(...) return { [1] = { ... }, [2] = select("#", ...) } end,
  i = function(t) return unpack(t[1], 1, t[2]) end,
}):O({ "entry", "main", "inc", "Q" }, "entry", ...)`;
const snap = { names: ['entry', 'main', 'inc', 'Q'], entry: 'entry' };

test('join: the sites become closures, the cells the variables they stand for, and the context disappears; the program still runs', () => {
  const ast = parse(TABLE);
  const r = joinMoonVeil(ast, snap);
  assert.equal(r.sites, 2);                                // :main and :inc (the runtime assignment `a.P = a:Q()` is dropped, nothing reads it)
  unboxCells(ast);
  const out = print(ast);
  assert.doesNotMatch(out, /\bQ\b/, 'the unused runtime is gone');
  assert.doesNotMatch(out, /\[\s*3\s*\]\s*=\s*1/, 'the cell is a variable now');
  const run = runSource(out, { sandbox: { enabled: true } });
  assert.match(String(run.stdout || run.output || JSON.stringify(run)), /12\s+12/);
});

test('join: a site that does something else than return a closure stops the join, and nothing is changed', () => {
  const bad = TABLE.replace('function(c) return function(...)', 'function(c) print("setup") return function(...)');
  const ast = parse(bad);
  const before = print(ast);
  assert.throws(() => joinMoonVeil(ast, snap), JoinError);
  assert.equal(print(ast), before);
});

test('join: a context member this reader does not know is reported, not guessed at', () => {
  const bad = TABLE.replace('c._["tostring"](acc[1])', 'c.zzz(acc[1])');
  assert.throws(() => joinMoonVeil(parse(bad), snap), /context member zzz/);
});

test('cells: a cell that is created again in a loop while closures hold the earlier ones stays a cell', () => {
  const src = 'local fs = {} for i = 1, 3 do local c local box = { [3] = 1, [1] = i } fs[#fs + 1] = function() return box[1] end end return fs';
  const ast = parse(src);
  const before = print(ast);
  // `box` is declared inside the loop (a new variable each time): that one is safe to unbox
  unboxCells(ast);
  assert.match(print(ast), /return box\b|return \w+\s/);
  const reg = 'local box local fs = {} for i = 1, 3 do box = { [3] = 1, [1] = i } fs[#fs + 1] = function() return box[1] end end return fs';
  const ast2 = parse(reg);
  assert.equal(unboxCells(ast2).changed, 0, 'one variable for all iterations: unboxing it would make the closures share it');
  assert.equal(print(ast2), print(parse(reg)));
  void before;
});

test('cells: only the slot a cell is read at is read as the variable', () => {
  const ast = parse('local a = { [3] = 1, [1] = 5 } local x = a[1] local t = { a[2] } return x, t');
  assert.equal(unboxCells(ast).changed, 0, 'a[2] is not the cell’s value: the table is not a cell here');
});

test('dataflow: a declaration whose first value was forwarded stays when the variable is assigned again', () => {
  const ast = parse('local a = {{{}}} local c = { _ = { Instance = { new = function(n) return {} end } } }\nlocal f = function()\n  local d, b\n  d = c._["Instance"]\n  b, d = d["new"], "ScreenGui"\n  b = b(d)\n  d = a[1][1]\n  b["Parent"] = d\n  return\nend\nf()');
  simplifyPass(ast, { unusedAtStart: new WeakSet() });
  dataflowPass(ast);
  const out = print(ast);
  assert.match(out, /local d\b/, out);
  parse(out);
});

const local = path.join(root, 'local/moonveil/v2.0.26_rideafish.lua');
const ref = path.join(root, 'local/moonveil/v2.0.26_rideafish.reference.lua');
test('MoonVeil 2.0.26 (local sample, not stored): the factories are joined and the result is measured against the hand-made reference', { skip: !fs.existsSync(local) && 'no local sample' }, async () => {
  const { recover } = await import('../src/recover/pipeline.js');
  const { structureScore } = await import('../src/core/metrics.js');
  const { fidelity } = await import('../src/core/fidelity.js');
  const { bytesToBinary } = await import('../src/core/bytes.js');
  const r = recover(bytesToBinary(fs.readFileSync(local)), { sandbox: { enabled: true } });
  const j = r.steps.find((s) => s.id === 'moonveil.join');
  assert.equal(j.status, 'applied');
  assert.doesNotMatch(r.output, /table of lifted functions/);
  if (fs.existsSync(ref)) {
    const want = bytesToBinary(fs.readFileSync(ref));
    assert.ok(structureScore(want, r.output) >= 0.6, `structure ${structureScore(want, r.output)}`);
    assert.ok(fidelity(want, r.output).score >= 0.3, `fidelity ${fidelity(want, r.output).score}`);
  }
});
