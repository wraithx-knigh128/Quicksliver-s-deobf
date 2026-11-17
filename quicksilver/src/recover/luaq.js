// LuaQ (obfuscator.cfd, closed and commercial): the layers that are in the file, decoded; what is not in it, said.
//
// Read on one v2.7 build supplied by the user (Prompt XVI, test 5), as text and in the JS sandbox only:
//
//   stage 1 (the file)  a loader that takes one long-string argument "LUAQ!<text>", decodes the text with a base-93 alphabet (pairs of characters
//                       give 13 or 14 bits), checks the "LQZ1" header (size, Adler-32) and inflates the raw DEFLATE stream behind it, then
//                       loadstring()s the result as "=LUAQ_VM". Everything here is plain data: decoded below without running anything.
//   stage 2 (606 kB)    the VM runtime (an interpreter, a deserializer and environment checks) and an encrypted loader program for it.
//   the program         not in the file: it is delivered to the script at run time from outside it. Recovering it is out of scope.

import { inflateRaw, adler32, InflateError } from '../core/inflate.js';

export class LuaqError extends Error {}
const fail = (m) => { throw new LuaqError(m); };

const BANNER = /Luaq Obfuscator v([0-9][0-9.]*)/i;

/** Is this a LuaQ build? The banner, or the stage-1 loader's own markers. */
export function looksLikeLuaq(src) {
  if (BANNER.test(src.slice(0, 400))) return true;
  return src.includes('LUAQ!') && src.includes("'LQZ1'") && src.includes('=LUAQ_VM');
}

/** The pieces of stage 1: the payload text, the alphabet and the two decoder constants, read from the loader itself. */
export function readStage1(src) {
  const m = /\(\[(=*)\[(LUAQ!)/.exec(src);
  if (!m) fail('the "LUAQ!" payload argument was not found');
  const open = m.index + 2 + m[1].length + 1;
  const close = src.indexOf(`]${m[1]}]`, open);
  if (close < 0) fail('the payload string is not closed');
  const payload = src.slice(open + 5, close);
  // the alphabet: a 93-character literal turned into a reverse map in `for A=1,93`
  const am = /local \w+="((?:[^"\\]|\\.){93,200})";local \w+=\{\};for \w+=1,93 do/.exec(src);
  if (!am) fail('the base-93 alphabet was not found');
  const alphabet = am[1].replace(/\\(.)/g, '$1');
  if (alphabet.length !== 93 || new Set(alphabet).size !== 93) fail('the base-93 alphabet does not have 93 distinct characters');
  const tm = /\w+%8192>(\d+) and 13 or 14/.exec(src);
  if (!tm) fail('the 13/14-bit threshold of the decoder was not found');
  return { payload, alphabet, threshold: +tm[1], version: (BANNER.exec(src.slice(0, 400)) || [])[1] || null };
}

/** The base-93 decoder of stage 1 (pairs of characters give 13 or 14 bits, low bits first). */
export function decodeBase93(text, alphabet, threshold) {
  const idx = new Map([...alphabet].map((c, i) => [c, i]));
  const out = [];
  let acc = 0;
  let n = 0;
  const p = text.length - (text.length % 2);
  for (let i = 0; i < p; i += 2) {
    const a = idx.get(text[i]);
    const b = idx.get(text[i + 1]);
    if (a === undefined || b === undefined) fail(`a character outside the alphabet at ${i}`);
    const q = a + b * 93;
    acc += q * 2 ** n;
    n += q % 8192 > threshold ? 13 : 14;
    if (n >= 16) { out.push(acc % 256, Math.floor(acc / 256) % 256); acc = Math.floor(acc / 65536); n -= 16; } else { out.push(acc % 256); acc = Math.floor(acc / 256); n -= 8; }
  }
  if (p < text.length) {
    const q = acc + idx.get(text[text.length - 1]) * 2 ** n;
    if (n === 0 || q > 255) fail('the last character does not fit');
    out.push(q);
  }
  return Uint8Array.from(out);
}

/** "LQZ1" + size (u32) + Adler-32 (u32) + raw DEFLATE. */
export function openLQZ1(bytes) {
  if (bytes.length < 12 || String.fromCharCode(...bytes.subarray(0, 4)) !== 'LQZ1') fail('the decoded payload does not start with LQZ1');
  const u32 = (o) => (bytes[o] | (bytes[o + 1] << 8) | (bytes[o + 2] << 16)) + bytes[o + 3] * 16777216;
  const size = u32(4);
  const sum = u32(8);
  let data;
  try { data = inflateRaw(bytes.subarray(12), Math.max(size, 1) + 16); } catch (e) { if (e instanceof InflateError) fail(`the DEFLATE stream does not inflate: ${e.message}`); throw e; }
  if (data.length !== size) fail(`the stream inflates to ${data.length} bytes, the header says ${size}`);
  if (adler32(data) !== sum) fail('the Adler-32 of the inflated stream does not match the header');
  return data;
}

/** What stage 2 says about itself without being run: the build id and the size of its own encrypted loader payload. */
export function describeStage2(text) {
  const build = /\("([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})"\)/.exec(text);
  const inner = /\[(=*)\[LUAQ!/.exec(text);
  let innerSize = null;
  if (inner) { const s = inner.index + inner[1].length + 2; const e = text.indexOf(`]${inner[1]}]`, s); innerSize = e > 0 ? e - s : null; }
  return {
    buildId: build ? build[1] : null,
    loaderPayloadChars: innerSize,
    environmentChecks: /Instance\.new/.test(text) && /InstanceHandle|Path2DControlPoint|FloatCurveKey/.test(text),
    ...analyzeVm(text),
  };
}

/**
 * The VM runtime's architecture, read off the decoded stage-2 source. These are reproducible counts, not a lift: the handlers are fused and
 * guarded, so recognising their shape is not the same as giving each a meaning.
 * @param {string} text the decoded stage-2 Luau source
 */
export function analyzeVm(text) {
  // the probes read the minified runtime, so spaces around operators are optional
  const S = (re) => new RegExp(re.replace(/ /g, ' ?')).test(text);
  // the interpreter dispatches on a masked opcode `v = D - s`, through a balanced binary search tree of `if v == N` / `if v <= N` nodes
  const handlers = (text.match(/(?:if|elseif) ?v ?== ?\d+ ?then/g) || []).length;
  const dispatchTree = S('v = \\w+ - \\w+') && S('if ?v <= \\d+ ?then');
  // instructions are decrypted from a feedback keystream (a running key updated with the ciphertext) and memoised per index
  const keystream = S('T\\(F\\(\\w+, \\w+\\), \\w+, \\w+\\)');
  const memoised = /\.G\[\w+\]/.test(text) && S('\\.G\\[\\w+\\] = ');
  // operands include zigzag-encoded signed values (`t % 2 == 0 and t / 2 or -(t + 1) / 2`)
  const zigzag = S('% 2 == 0 and \\w+ / 2 or -\\(\\w+ \\+ 1\\) / 2');
  // the deserializer reads a prototype table with these fields (bytecode body, constants, child protos, line info)
  const deserializer = S('m = \\w+\\(\\),') && S('c = \\w+\\(\\),');
  return { vm: { handlers, dispatchTree, keystream, memoised, zigzag, deserializer } };
}

/** Stage 1 decoded: the source of stage 2 (a binary string), and what was checked on the way. */
export function decodeLuaq(src) {
  const s1 = readStage1(src);
  const bytes = decodeBase93(s1.payload, s1.alphabet, s1.threshold);
  const data = openLQZ1(bytes);
  let text = '';
  for (let i = 0; i < data.length; i += 8192) text += String.fromCharCode(...data.subarray(i, i + 8192));
  return { stage2: text, version: s1.version, payloadChars: s1.payload.length, containerBytes: bytes.length, stage2Bytes: data.length, ...describeStage2(text) };
}
