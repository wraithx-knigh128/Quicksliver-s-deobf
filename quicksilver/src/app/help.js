// The help dialog: written for someone who has an obfuscated script and wants it readable, not for someone who knows
// what an AST is. It lists what every button does and, just as plainly, what it cannot do.

import { h, modal } from './dom.js';

const row = (name, text) => h('tr', h('th', { scope: 'row' }, name), h('td', text));

export function showHelp() {
  return modal({
    title: 'How to use QuickSilver',
    body: h('div.help', [
      h('h3', '1. Put your script in'),
      h('p', 'Paste it on the left, press Open File, drop a .lua / .luau / .txt file on the page, or use From link (raw GitHub, Pastebin, rentry, a Discord attachment). It stays in your browser. Nothing is run.'),
      h('h3', '2. Press Deobfuscate'),
      h('p', 'QuickSilver works out what protects the script and writes the readable version on the right. The strip under the two boxes says what it found and how sure it is.'),
      h('h3', '3. Check and save'),
      h('p', 'Compare puts the two versions side by side. Export saves the result, a report or a zip with everything.'),
      h('h3', 'If you already know the obfuscator'),
      h('table.help-table', h('tbody', [
        row('IronBrew', 'IronBrew 2: the original program is rebuilt from the virtual machine. IronBrew 1 is not supported.'),
        row('Luraph', 'Luraph v14 / v15 turns a script into a private virtual machine and nobody can turn that back into the source automatically. This button runs the script in QuickSilver’s own sandbox (it asks first), captures the text the script builds and loads, and lists what it does. Heavy scripts can run out of budget and give a partial result.'),
        row('MoonVeil', 'Identified and handled like Luraph: dumped in the sandbox, not rebuilt.'),
      ])),
      h('h3', 'Tools'),
      h('table.help-table', h('tbody', [
        row('Detect', 'Names the obfuscator and the language dialect.'),
        row('Beautify', 'Only re-indents the code. Nothing is decoded.'),
        row('Rename', 'Gives machine-made variable names readable ones.'),
        row('Dump', 'Runs the script in the sandbox (it asks first) and captures what it loads or joins with table.concat.'),
        row('Origin check', 'Estimates how much the code reads like AI-written code and how much of it looks copied. It is a guess from style and, if you allow it, from a search for the same lines on GitHub. It is never proof.'),
      ])),
      h('p.note.warn', 'Use QuickSilver only on scripts you own or are allowed to analyse.'),
    ]),
  });
}
