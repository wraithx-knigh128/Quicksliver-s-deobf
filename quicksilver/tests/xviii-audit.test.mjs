// Prompt XVIII audit: failures reproduced by driving every engine operation with edge-case inputs, kept as regression tests.
import test from 'node:test';
import assert from 'node:assert/strict';
import * as api from '../src/api.js';

test('verifySource without a recovered program answers with a reason instead of throwing', () => {
  // before: TypeError "Cannot read properties of undefined (reading 'length')" for every input
  const r = api.verifySource('print(1)', {});
  assert.equal(r.ok, false);
  assert.match(r.error, /recover/);
});

test('every engine operation returns (does not throw) on edge-case inputs', () => {
  const inputs = ['', '   \n', '\xEF\xBB\xBFprint("hi")', '#!/usr/bin/lua\nprint(1)', 'local a = 1\r\nprint(a)\r\n', 'local = = 3 end (', 'print("abc', '--[==[ x',
    'return ' + '('.repeat(3000) + '1' + ')'.repeat(3000), 'local x: number = 1\nx += 2', '\x1bLua\x51\x00', '\x00\x01\x02\x03'.repeat(50), 'print("a\x00b")'];
  const ops = ['inspectInput', 'detectScript', 'beautifyScript', 'analyzeSource', 'recoverSource', 'identifySource', 'customAnalyzeSource', 'luast', 'renameScript', 'originCheck'];
  for (const src of inputs) for (const op of ops) assert.doesNotThrow(() => api[op](src, { sandbox: { enabled: false } }), `${op} on ${JSON.stringify(src.slice(0, 20))}`);
});
