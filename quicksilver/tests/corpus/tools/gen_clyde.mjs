// Generate output of Clyde (sfr-development/Lua-Obfuscator-Clyde-Protection, MIT, TypeScript) for the corpus, never through its own command line or server.
//
// The checkout is compiled with `tsc` (a compiler, nothing of Clyde runs) and this script imports the compiled library and makes the calls src/cli/obfuscate.ts
// makes, with the same options. It is run under Node's permission model, which denies network, child processes, workers and every file outside the folders named:
//
//   node --permission --allow-fs-read=<tools dir> --allow-fs-read=<compiled dist> --allow-fs-read=<originals> --allow-fs-write=<out> \
//        gen_clyde.mjs <dist> <originals> <out> <commit>

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { pathToFileURL } from 'node:url';

const [dist, originals, outDir, commit = 'unknown'] = process.argv.slice(2);
const load = (rel) => import(pathToFileURL(path.join(dist, rel)).href);
const { lex } = await load('lexer/Lexer.js');
const { parse } = await load('parser/Parser.js');
const { obfuscate } = await load('obfuscator/Obfuscator.js');
const { encodeStrings } = await load('obfuscator/StringEncoder.js');
const { scrambleControlFlow } = await load('obfuscator/ControlFlowScrambler.js');
const { printChunk } = await load('obfuscator/Printer.js');
const { compile } = await load('vm/Compiler.js');
const { generateVM } = await load('vm/vm-gen.js');

const CONFIGS = {
  'rename': (ast) => printChunk(obfuscate(ast, { renameLocals: true, preserveGlobals: true })),
  'strings-flow': (ast) => printChunk(obfuscate(scrambleControlFlow(encodeStrings(ast, { enabled: true }), { enabled: true }), { renameLocals: true, preserveGlobals: true })),
  'vm': (ast) => generateVM(compile(obfuscate(ast, { renameLocals: true, preserveGlobals: true })), { level: 'normal', executorGlobals: true, noCompression: false }),
  'vm-max': (ast) => generateVM(compile(obfuscate(ast, { renameLocals: true, preserveGlobals: true })), { level: 'max', executorGlobals: true, noCompression: false }),
};

fs.mkdirSync(outDir, { recursive: true });
const manifest = { tool: 'Clyde (Luau obfuscator)', source: 'https://github.com/sfr-development/Lua-Obfuscator-Clyde-Protection', licence: 'MIT', sourceRevision: commit, seed: null,
  runner: 'tests/corpus/tools/gen_clyde.mjs under node --permission (no network, no child processes), compiled with tsc', entries: [] };
for (const sample of fs.readdirSync(originals).filter((f) => f.endsWith('.lua')).sort()) {
  const source = fs.readFileSync(path.join(originals, sample), 'utf8');
  for (const [config, build] of Object.entries(CONFIGS)) {
    const file = `${sample.replace(/\.lua$/, '')}__${config}.lua`;
    const entry = { file, sample, config, runtime: 'luau', sampleSha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(originals, sample))).digest('hex') };
    try {
      const { tokens, errors } = lex(source);
      if (errors.length) throw new Error(`lexer: ${JSON.stringify(errors).slice(0, 100)}`);
      const text = build(parse(tokens));
      fs.writeFileSync(path.join(outDir, file), text, 'utf8');
      Object.assign(entry, { status: 'ok', bytes: Buffer.byteLength(text), seconds: 0 });
    } catch (e) { Object.assign(entry, { status: 'error', error: String(e && e.message || e).slice(0, 200) }); }
    manifest.entries.push(entry);
    console.log(file.padEnd(50), entry.status, entry.bytes || entry.error);
  }
}
fs.writeFileSync(path.join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
