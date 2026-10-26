// Generate output of the browser-only obfuscator iamsopotatoe/simple-lua-obfuscator (MIT) for the corpus, without a browser and without trusting it.
//
//   node --permission --allow-fs-read=<this file's folder> --allow-fs-read=<checkout> --allow-fs-read=<originals> --allow-fs-write=<out> \
//        gen_html_obfuscator.mjs <checkout>/index.html <originals> <out> <commit>
//
// The tool is one HTML page whose script transforms text. Its functions are evaluated in a `vm` context that has no globals but a seeded Math.random and a
// two-element stand-in for `document`; the Node permission model (flags above) denies the process network, child processes, workers and every file outside
// the folders named. The page's own `obfuscate()` is called, so what is generated is what the page generates; nothing is modified.

import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';

const [htmlPath, originals, outDir, commit = 'unknown'] = process.argv.slice(2);
const html = fs.readFileSync(htmlPath, 'utf8');
const script = html.slice(html.lastIndexOf('<script>') + 8, html.lastIndexOf('</script>'));

function mulberry32(seed) { let a = seed >>> 0; return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

fs.mkdirSync(outDir, { recursive: true });
const manifest = { tool: 'simple-lua-obfuscator (iamsopotatoe, browser page)', source: 'https://github.com/iamsopotatoe-coder/simple-lua-obfuscator', licence: 'MIT', sourceRevision: commit, seed: 1337,
  runner: 'tests/corpus/tools/gen_html_obfuscator.mjs under node --permission (no network, no child processes)', entries: [] };

for (const sample of fs.readdirSync(originals).filter((f) => f.endsWith('.lua')).sort()) {
  const source = fs.readFileSync(path.join(originals, sample), 'latin1');
  const elements = { input: { value: source }, output: { value: '' }, fileInput: { addEventListener() {} } };
  const rnd = mulberry32(1337);
  const context = vm.createContext({
    document: { getElementById: (id) => elements[id] },
    Math: Object.assign(Object.create(Math), { random: rnd }),
    alert() {}, FileReader: class {}, Blob: class {}, URL: {},
  }, { codeGeneration: { strings: false, wasm: false } });
  vm.runInContext(script, context, { timeout: 20000 });
  vm.runInContext('obfuscate()', context, { timeout: 20000 });
  const text = elements.output.value;
  const file = `${sample.replace(/\.lua$/, '')}__default.lua`;
  fs.writeFileSync(path.join(outDir, file), text, 'latin1');
  manifest.entries.push({ file, sample, config: 'default', runtime: 'lua54', sampleSha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(originals, sample))).digest('hex'), status: 'ok', bytes: text.length, seconds: 0 });
  console.log(file.padEnd(48), 'ok', text.length);
}
fs.writeFileSync(path.join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
