'use strict';
// QuickSilver driver (Prompt XXIX) for the vendored Prometheus deobfuscator (MIT, see LICENSE and NOTICE.md).
// It runs the tool's own pipeline on the script (its parser, its static passes, its VM lifter and the small Lua interpreter it uses to
// fold expressions — a pure library with no os, io or require) and writes the Lua source it produces. Detection is QuickSilver's: the
// server sends only what QuickSilver recognised as a Prometheus VM build, so the tool's own identification is skipped.
// It is always started through api/_lib/isolate.js (tools/isolate/run.sh where the host allows namespaces), never in-process.
//   node qs-driver.js <input.lua> <output.lua>   (exit 0: source written; 1: the tool could not rebuild the program)
const fs = require('fs');
const { deobfuscate } = require('./src/index.js');

const [input, output] = process.argv.slice(2);
try {
    const r = deobfuscate(fs.readFileSync(input, 'latin1'), { detect: false, name: 'input' });
    if (!r || typeof r.code !== 'string' || !r.code.trim()) throw new Error('no program came out');
    fs.writeFileSync(output, Buffer.from(r.code, 'latin1'));
} catch (error) {
    process.stderr.write(`prometheus: ${String((error && error.message) || error).slice(0, 300)}\n`);
    process.exit(1);
}
