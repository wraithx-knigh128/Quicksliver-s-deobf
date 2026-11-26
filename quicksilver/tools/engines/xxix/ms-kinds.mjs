const [Q, dir] = process.argv.slice(2);
const fs = await import('node:fs');
const { parseChunk } = await import(Q + '/src/sandbox/bytecode.js');
const { decompile } = await import(Q + '/src/decompile/decompile.js');
const { print } = await import(Q + '/src/core/printer.js');
const EXEC = /\b(?:hookmetamethod|hookfunction|getgenv|getrenv|getrawmetatable|setreadonly|make_?readonly|syn\.request|http_request|fireclickdetector|firetouchinterest|fireproximityprompt|getconnections|setclipboard|identifyexecutor|getexecutorname|writefile|readfile|isfile|Drawing\.new|getnamecallmethod|checkcaller|newcclosure|request\s*\()/;
const LOADER = /HttpGet\w*\s*\(|loadstring\s*\(/;
let n = 0, exec = 0, loader = 0, either = 0;
for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.luac'))) {
  let t; try { t = print(decompile(parseChunk(fs.readFileSync(`${dir}/${f}`, 'latin1'))).ast); } catch { continue; }
  n++; const e = EXEC.test(t), l = LOADER.test(t); if (e) exec++; if (l) loader++; if (e || l) either++;
}
console.log(JSON.stringify({ programs: n, executorApi: exec, httpGetOrLoadstring: loader, either }));
