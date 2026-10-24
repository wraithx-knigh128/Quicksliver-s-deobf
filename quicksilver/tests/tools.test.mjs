// The engine operations behind the tool buttons: rename and dump.

import test from 'node:test';
import assert from 'node:assert/strict';
import { renameScript, dumpSource, originCheck } from '../src/api.js';

test('rename gives machine-made names readable ones and leaves chosen names alone', () => {
  const r = renameScript('local a, b = 1, 2\nlocal function c(d) return d + a end\nprint(c(b))\n');
  assert.equal(r.ok, true);
  assert.ok(r.renamed >= 3);
  assert.match(r.output, /local function fn\(param\)/);

  const kept = renameScript('local playerCount = 3\nlocal function addPlayer(name)\n  playerCount = playerCount + 1\n  return name\nend\nprint(addPlayer("x"))\n');
  assert.equal(kept.renamed, 0);
  assert.match(kept.output, /playerCount/);
  assert.match(kept.output, /addPlayer/);
});

test('rename reports a script that does not parse instead of throwing', () => {
  const r = renameScript('local = = 1');
  assert.equal(r.ok, false);
  assert.ok(r.error.line >= 1);
});

const payload = `local t = {}\n${Array.from({ length: 12 }, (_, i) => `t[${i + 1}] = "value number ${i}"`).join('\n')}\nprint(#t)\n`;

test('dump keeps what a script loads and picks the chunk that parses', () => {
  const src = `local pieces = {}\nlocal s = ${JSON.stringify(payload)}\nfor line in s:gmatch("[^\\n]+") do pieces[#pieces + 1] = line end\nloadstring(table.concat(pieces, "\\n"))()\n`;
  const r = dumpSource(src);
  assert.equal(r.status, 'completed');
  assert.ok(r.candidates.some((c) => c.kind === 'chunk' && c.parses));
  const best = r.candidates.find((c) => c.id === r.best);
  assert.equal(best.kind, 'chunk');
  assert.equal(best.source, payload.replace(/\n$/, ''));
});

test('dump finds text joined with table.concat even if the script never loads it', () => {
  const src = `local out = {}\nfor i = 1, 30 do out[#out + 1] = "segment " .. i .. " of the hidden text" end\nlocal text = table.concat(out, "\\n")\n`;
  const r = dumpSource(src);
  assert.equal(r.candidates.length, 1);
  assert.equal(r.candidates[0].kind, 'concat');
  assert.match(r.candidates[0].source, /segment 30 of the hidden text/);
  assert.equal(r.best, 0);
});

test('dump says so when nothing was built, and still returns when the run hits its limit', () => {
  const none = dumpSource('local x = 1\nprint(x)\n');
  assert.equal(none.candidates.length, 0);
  assert.equal(none.best, null);
  const loop = dumpSource('local parts = {}\nfor i = 1, 5 do parts[#parts+1] = string.rep("a", 20) end\nlocal s = table.concat(parts)\nwhile true do end', { fuel: 300_000, timeMs: 5000 });
  assert.equal(loop.status, 'limit');
  assert.equal(loop.candidates.length, 1, 'what was captured before the limit is kept');
});

test('origin check runs through the engine API', () => {
  const r = originCheck('local x = 1\nprint(x)\n');
  assert.equal(r.ok, true);
  assert.equal(typeof r.codeLines, 'number');
});
