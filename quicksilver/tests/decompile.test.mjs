// The bytecode decompiler is tested by behaviour: real Lua compiles a program, QuickSilver decompiles the chunk,
// and the decompiled source must print exactly what the original did, on the same interpreter.
// Needs the reference runtime (QS_LUA_PYTHON); skipped otherwise.

import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { bytesToBinary } from '../src/core/bytes.js';
import { quoteString, print } from '../src/core/printer.js';
import { parse } from '../src/core/parser.js';
import { parseChunk, dumpChunk51 } from '../src/sandbox/bytecode.js';
import { decompile } from '../src/decompile/decompile.js';
import * as oracle from './helpers/lua-oracle.mjs';
import { SNIPPETS, SNIPPETS_54 } from './corpus/decompile/snippets.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
after(() => oracle.stopOracle());
const skip = oracle.available ? false : 'QS_LUA_PYTHON is not set (reference Lua unavailable)';
const hexToBin = (hex) => hex.replace(/../g, (h) => String.fromCharCode(parseInt(h, 16)));

async function compile(src, runtime) {
  const loader = runtime === 'lua51' ? 'loadstring' : 'load';
  const code = `local f = assert(${loader}(${quoteString(src)}))\nlocal d = string.dump(f)\nprint((d:gsub('.', function(c) return string.format('%02x', c:byte()) end)))`;
  const r = await oracle.runLua(code, runtime);
  assert.ok(r.ok, r.error);
  return hexToBin(r.stdout.trim());
}

async function roundTrip(src, runtime, strip = false) {
  let bin = await compile(src, runtime);
  if (strip && runtime === 'lua51') {
    // Lua 5.1's string.dump ignores its `strip` argument, so the debug information is removed here
    bin = dumpChunk51(parseChunk(bin), { strip: true });
  } else if (strip) {
    const code = `local f = assert(load(${quoteString(src)}))\nlocal d = string.dump(f, true)\nprint((d:gsub('.', function(c) return string.format('%02x', c:byte()) end)))`;
    const r = await oracle.runLua(code, runtime);
    assert.ok(r.ok, r.error);
    bin = hexToBin(r.stdout.trim());
  }
  const { ast, failures } = decompile(parseChunk(bin));
  const text = print(ast, {});
  return { text, failures };
}

for (const runtime of ['lua51', 'lua54']) {
  for (const [name, src] of Object.entries(runtime === 'lua54' ? { ...SNIPPETS, ...SNIPPETS_54 } : SNIPPETS)) {
    for (const strip of [false, true]) {
      test(`${runtime}${strip ? ' stripped' : ''}: ${name} decompiles to equivalent code`, { skip }, async () => {
        const expected = await oracle.runLua(src, runtime);
        assert.ok(expected.ok, `reference run failed: ${expected.error}`);
        const { text, failures } = await roundTrip(src, runtime, strip);
        assert.deepEqual(failures, [], `could not decompile:\n${text}`);
        assert.doesNotThrow(() => parse(text), `output does not parse:\n${text}`);
        const got = await oracle.runLua(text, runtime);
        assert.ok(got.ok, `decompiled code failed (${got.error}):\n${text}`);
        assert.equal(got.stdout, expected.stdout, `behaviour differs:\n${text}`);
      });
    }
  }
}
void here; void fs; void bytesToBinary;
