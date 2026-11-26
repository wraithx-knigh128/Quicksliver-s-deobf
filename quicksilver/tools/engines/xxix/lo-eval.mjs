const [Q, f, out, st, ms, errf] = process.argv.slice(2);
const fs = await import('node:fs');
const r = { file: f, status: Number(st), ms: Number(ms) };
const err = fs.existsSync(errf) ? fs.readFileSync(errf, 'utf8') : '';
r.warnings = (err.match(/^warning:/gm) || []).length;
if (!fs.existsSync(out)) { r.stage = 'tool'; r.error = err.trim().split('\n').slice(-1)[0].slice(0, 160); console.log(JSON.stringify(r)); process.exit(0); }
const { parse } = await import(Q + '/src/core/parser.js');
const text = fs.readFileSync(out, 'latin1');
r.lines = text.split('\n').length;
try { parse(text); r.parses = true; } catch (e) { r.parses = false; }
// the LuaObfuscator VM's packed program ("LOL!" + hex) or its deserializer still present = the program was not lifted
r.vmLeft = /"LOL!/.test(text) || /string\.byte[\s\S]{0,400}bit32|v3\.bxor/.test(text) && /"LOL!|\\076\\079\\076\\033/.test(text);
r.stage = 'done';
console.log(JSON.stringify(r));
