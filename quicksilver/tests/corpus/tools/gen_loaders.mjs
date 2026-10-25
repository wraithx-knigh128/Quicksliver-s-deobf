// Loader-style packers, written for this project.
//
//   node tests/corpus/tools/gen_loaders.mjs
//
// These are NOT the output of any real obfuscator. They are small packers that put a program behind the encodings the open-source
// Lua packers document (ASCII codes, hex, binary, URL escapes, base64, a XOR cipher, reversed text, split string pieces, a layer in
// a layer) so that the loader-unwrapping pass can be tested on every one of them, and measured, without running anyone else's code.
// Every example is deterministic. The loaders below are written from scratch; they share only the idea with the tools that inspired them.
//
// `needsSandbox` says whether the payload can be read without running anything: literal text and constant folding need no sandbox,
// a decoder loop does.

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { quoteString } from '../../../src/core/printer.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const corpus = path.join(here, '..');
const out = path.join(corpus, 'obfuscated', 'loaders');
const SAMPLES = ['s01_minify_basic', 's02_renamed_vars', 's03_encoded_strings', 's04_control_flow', 's05_nested_functions', 's06_combined'];

const bytes = (text) => [...text].map((c) => c.charCodeAt(0) & 255);
const LOAD = '(loadstring or load)';
// the loader that follows decoder code is written `local run = <load>(text)` + `run()`: a line that starts with a parenthesis is read by Lua 5.1 as a call of the line before it

const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
function base64(text) {
  const b = bytes(text);
  let s = '';
  for (let i = 0; i < b.length; i += 3) {
    const n = (b[i] << 16) | ((b[i + 1] ?? 0) << 8) | (b[i + 2] ?? 0);
    s += B64[(n >> 18) & 63] + B64[(n >> 12) & 63] + (i + 1 < b.length ? B64[(n >> 6) & 63] : '=') + (i + 2 < b.length ? B64[n & 63] : '=');
  }
  return s;
}

// ---- the packers: each takes the program text and returns the packed script ------------------------------------------------------

const PACKERS = {
  ascii: {
    note: 'decimal character codes separated by commas, decoded with gmatch + string.char',
    needsSandbox: true,
    pack: (src) => `local codes = ${quoteString(bytes(src).join(','))}\nlocal parts = {}\nfor n in codes:gmatch("%d+") do\n  parts[#parts + 1] = string.char(tonumber(n))\nend\nlocal run = ${LOAD}(table.concat(parts))\nrun()\n`,
  },
  hex: {
    note: 'hexadecimal digits, decoded with gsub',
    needsSandbox: true,
    pack: (src) => `local digits = ${quoteString(bytes(src).map((c) => c.toString(16).padStart(2, '0')).join(''))}\nlocal text = digits:gsub("%x%x", function(h)\n  return string.char(tonumber(h, 16))\nend)\nlocal run = ${LOAD}(text)\nrun()\n`,
  },
  binary: {
    note: 'eight-digit binary groups, decoded with gmatch and tonumber(x, 2)',
    needsSandbox: true,
    pack: (src) => `local bits = ${quoteString(bytes(src).map((c) => c.toString(2).padStart(8, '0')).join(' '))}\nlocal parts = {}\nfor group in bits:gmatch("[01]+") do\n  parts[#parts + 1] = string.char(tonumber(group, 2))\nend\nlocal run = ${LOAD}(table.concat(parts))\nrun()\n`,
  },
  url: {
    note: 'percent-escapes for every byte, decoded with gsub',
    needsSandbox: true,
    pack: (src) => `local encoded = ${quoteString(bytes(src).map((c) => `%${c.toString(16).padStart(2, '0')}`).join(''))}\nlocal text = encoded:gsub("%%(%x%x)", function(h)\n  return string.char(tonumber(h, 16))\nend)\nlocal run = ${LOAD}(text)\nrun()\n`,
  },
  base64: {
    note: 'base64 text with a decoder written in plain Lua 5.1 arithmetic',
    needsSandbox: true,
    pack: (src) => `local alphabet = "${B64}"
local function decode(text)
  local out, acc, bits = {}, 0, 0
  for i = 1, #text do
    local ch = text:sub(i, i)
    local v = alphabet:find(ch, 1, true)
    if v then
      acc = acc * 64 + (v - 1)
      bits = bits + 6
      if bits >= 8 then
        bits = bits - 8
        local div = 2 ^ bits
        out[#out + 1] = string.char(math.floor(acc / div))
        acc = acc % div
      end
    end
  end
  return table.concat(out)
end
local run = ${LOAD}(decode(${quoteString(base64(src))}))
run()
`,
  },
  xor: {
    note: 'a repeating-key XOR cipher, the key kept next to the cipher text, xor done with arithmetic',
    needsSandbox: true,
    pack: (src) => {
      const key = 'qs-key-17';
      const k = bytes(key);
      const cipher = bytes(src).map((c, i) => c ^ k[i % k.length]);
      return `local key = "${key}"
local data = {${cipher.join(',')}}
local function xor(a, b)
  local r, p = 0, 1
  while a > 0 or b > 0 do
    local x, y = a % 2, b % 2
    if x ~= y then r = r + p end
    a, b, p = (a - x) / 2, (b - y) / 2, p * 2
  end
  return r
end
local out = {}
for i = 1, #data do
  out[i] = string.char(xor(data[i], key:byte((i - 1) % #key + 1)))
end
local run = ${LOAD}(table.concat(out))
run()
`;
    },
  },
  reverse: {
    note: 'the program text reversed, put right with string.reverse',
    needsSandbox: false,
    pack: (src) => `${LOAD}((${quoteString([...src].reverse().join(''))}):reverse())()\n`,
  },
  escapes: {
    note: 'the program as one string literal of decimal escapes',
    needsSandbox: false,
    pack: (src) => `${LOAD}("${bytes(src).map((c) => `\\${String(c).padStart(3, '0')}`).join('')}")()\n`,
  },
  charcodes: {
    note: 'string.char(...) with every code spelled out',
    needsSandbox: false,
    pack: (src) => {
      // Lua 5.1 refuses calls with hundreds of arguments, so the codes go in groups
      const b = bytes(src);
      const groups = [];
      for (let i = 0; i < b.length; i += 90) groups.push(`string.char(${b.slice(i, i + 90).join(', ')})`);
      return `${LOAD}(${groups.join(' ..\n  ')})()\n`;
    },
  },
  pieces: {
    note: 'the program cut into pieces and joined with the concatenation operator',
    needsSandbox: false,
    pack: (src) => {
      const parts = [];
      for (let i = 0; i < src.length; i += 37) parts.push(quoteString(src.slice(i, i + 37)));
      return `${LOAD}(${parts.join(' ..\n  ')})()\n`;
    },
  },
  layered: {
    note: 'two layers: base64 around the hexadecimal packer around the program',
    needsSandbox: true,
    pack: (src) => PACKERS.base64.pack(PACKERS.hex.pack(src)),
  },
};

export const TECHNIQUES = Object.keys(PACKERS);

export function generate() {
  fs.rmSync(out, { recursive: true, force: true });
  fs.mkdirSync(out, { recursive: true });
  const entries = [];
  for (const sample of SAMPLES) {
    const original = fs.readFileSync(path.join(corpus, 'originals', `${sample}.lua`)).toString('latin1');
    for (const [config, p] of Object.entries(PACKERS)) {
      const text = p.pack(original);
      const file = `${sample}__${config}.lua`;
      fs.writeFileSync(path.join(out, file), Buffer.from(text, 'latin1'));
      entries.push({
        file, sample: `${sample}.lua`, config, status: 'ok', bytes: text.length, needsSandbox: p.needsSandbox, note: p.note,
        // checked by tests/layers.test.mjs on every run: the packed script prints what the original prints
        behavior: 'equivalent', behaviors: { lua51: 'equivalent' },
        sampleSha256: crypto.createHash('sha256').update(original, 'latin1').digest('hex'),
      });
    }
  }
  const manifest = {
    tool: 'Loader packers (synthetic)',
    synthetic: true,
    source: 'tests/corpus/tools/gen_loaders.mjs: written for this project from the documented encodings; not the output of any real obfuscator',
    entries,
  };
  fs.writeFileSync(path.join(out, 'manifest.json'), `${JSON.stringify(manifest, null, 1)}\n`);
  return entries.length;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) console.log(`wrote ${generate()} loader examples to ${path.relative(process.cwd(), out)}`);
