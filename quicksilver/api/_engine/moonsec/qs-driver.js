'use strict';
// QuickSilver driver (Prompt XXIX) for the vendored MoonSec V3 deobfuscator (GPL-3.0, see LICENSE and NOTICE.md).
// It runs only the tool's own analysis — parse the wrapper, decode its constants, solve its control flow, deserialize and devirtualize
// the VM program — and writes the rebuilt Lua 5.1 bytecode. Decompiling that bytecode is QuickSilver's own decompiler, in the page;
// no external decompiler binary is used, and nothing here reads or writes any file but the two named on the command line.
// It is always started through api/_lib/isolate.js (tools/isolate/run.sh where the host allows namespaces), never in-process.
//   node qs-driver.js <input.lua> <output.luac>   (exit 0: bytecode written; 1: the tool could not rebuild the program)
const fs = require('fs');
const { Deobfuscator } = require('./src/deobf/deobfuscator.js');
const { Serializer } = require('./src/deobf/bytecode/serializer.js');

const [input, output] = process.argv.slice(2);
try {
    const fn = new Deobfuscator().deobfuscate(fs.readFileSync(input, 'latin1'));
    fs.writeFileSync(output, Buffer.from(new Serializer().serialize(fn)));
} catch (error) {
    process.stderr.write(`moonsec: ${String((error && error.message) || error).slice(0, 300)}\n`);
    process.exit(1);
}
